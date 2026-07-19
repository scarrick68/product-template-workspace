# frozen_string_literal: true

require_relative "client"

module Workspace
  module Infrastructure
    module DigitalOcean
      # Deletes matched DigitalOcean resources in dependency-safe order.
      class ResourcePurger
        DELETE_COMMANDS = {
          app: %w[apps delete],
          database: %w[databases delete]
        }.freeze

        DELETE_ORDER = %i[app database].freeze
        PROJECT_RESOURCE_TYPES = (DELETE_ORDER + [:spaces_bucket]).freeze

        def initialize(client:, spaces_client:, inventory:)
          @client = client
          @spaces_client = spaces_client
          @inventory = inventory
        end

        def call
          assert_only_supported_project_resources!

          resources = unique_resources

          DELETE_ORDER.each do |type|
            resources
              .select { |resource| resource.type == type }
              .each { |resource| delete_resource(resource) }
          end

          delete_spaces_bucket
          delete_project
        end

        private

        attr_reader :client, :spaces_client, :inventory

        def assert_only_supported_project_resources!
          unknown = inventory
            .fetch(:project_resources)
            .reject { |resource| PROJECT_RESOURCE_TYPES.include?(resource.type) }

          return if unknown.empty?

          details = unknown.map { |resource| resource.urn || resource.id }.join(", ")
          raise Error, "Unknown project resource types detected: #{details}"
        end

        def unique_resources
          resources =
            inventory.fetch(:matching_resources).values.flatten +
            inventory.fetch(:project_resources)

          resources
            .select { |resource| DELETE_ORDER.include?(resource.type) }
            .group_by { |resource| [resource.type, resource.id] }
            .values
            .map(&:first)
        end

        def delete_resource(resource)
          command = DELETE_COMMANDS.fetch(resource.type)
          label = resource.name || resource.id

          Workspace.info("Deleting #{resource.type}: #{label}")
          client.run(*command, resource.id, "--force")
        end

        def delete_spaces_bucket
          bucket_name = inventory.fetch(:spaces_bucket_name).to_s.strip
          return if bucket_name.empty?
          return unless spaces_client.bucket_exists?(bucket_name)

          Workspace.info("Deleting Spaces bucket: #{bucket_name}")
          spaces_client.delete_bucket(bucket_name)
        end

        def delete_project
          project = inventory.fetch(:project)

          Workspace.info("Deleting project: #{project.fetch('name')}")
          client.run("projects", "delete", project.fetch("id"), "--force")
        end
      end
    end
  end
end
