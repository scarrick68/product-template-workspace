# frozen_string_literal: true

require_relative "client"

module Workspace
  module Infrastructure
    module DigitalOcean
      # Builds project-assigned and account-wide resource views for cleanup decisions.
      class ResourceInventory
        Resource = Data.define(
          :type,
          :id,
          :name,
          :region,
          :urn,
          :metadata
        )

        def initialize(client:, project_name:, expected_names:, spaces_bucket_name:)
          @client = client
          @project_name = project_name
          @expected_names = expected_names.compact.uniq
          @spaces_bucket_name = spaces_bucket_name
        end

        def call
          {
            account: account,
            project: project,
            project_resources: project_resources,
            matching_resources: matching_resources,
            spaces_bucket_name: spaces_bucket_name
          }
        end

        def account_inventory
          {
            account: account,
            matching_resources: matching_resources,
            spaces_bucket_name: spaces_bucket_name
          }
        end

        private

        attr_reader :client, :project_name, :expected_names, :spaces_bucket_name

        def account
          @account ||= normalize_account_payload(client.json("account", "get"))
        end

        def project
          @project ||= begin
            matches = client
              .json("projects", "list")
              .select { |candidate| candidate.fetch("name") == project_name }

            raise Error, "DigitalOcean project not found: #{project_name}" if matches.empty?
            raise Error, "Multiple DigitalOcean projects found: #{project_name}" if matches.size > 1

            matches.first
          end
        end

        def project_resources
          project_id = project.fetch("id")

          client
            .json("projects", "resources", "list", project_id)
            .map { |resource| normalize_project_resource(resource) }
        end

        def matching_resources
          {
            apps: matching_apps,
            databases: matching_databases
          }
        end

        def matching_apps
          client
            .json("apps", "list")
            .filter_map do |app|
              name = app.dig("spec", "name")
              next unless expected_name?(name)

              Resource.new(
                type: :app,
                id: app.fetch("id"),
                name: name,
                region: app.dig("region", "slug"),
                urn: "do:app:#{app.fetch('id')}",
                metadata: {
                  live_url: app["live_url"],
                  active_deployment_id: app["active_deployment_id"]
                }
              )
            end
        end

        def matching_databases
          client
            .json("databases", "list")
            .filter_map do |database|
              name = database["name"]
              next unless expected_name?(name)

              Resource.new(
                type: :database,
                id: database.fetch("id"),
                name: name,
                region: database["region"],
                urn: "do:dbaas:#{database.fetch('id')}",
                metadata: {
                  engine: database["engine"],
                  status: database["status"]
                }
              )
            end
        end

        def normalize_project_resource(resource)
          urn = resource.fetch("urn")
          type, id = parse_urn(urn)

          Resource.new(
            type: type,
            id: id,
            name: nil,
            region: nil,
            urn: urn,
            metadata: {
              status: resource["status"],
              assigned_at: resource["assigned_at"]
            }
          )
        end

        def parse_urn(urn)
          _, raw_type, id = urn.split(":", 3)

          type = {
            "app" => :app,
            "dbaas" => :database,
            "space" => :spaces_bucket,
            "spaces" => :spaces_bucket
          }.fetch(raw_type, raw_type.to_sym)

          [type, id]
        end

        def expected_name?(name)
          expected_names.include?(name)
        end

        def normalize_account_payload(payload)
          return payload.first if payload.is_a?(Array)
          return payload if payload.is_a?(Hash)

          raise Error, "Unexpected account payload returned by doctl."
        end
      end
    end
  end
end
