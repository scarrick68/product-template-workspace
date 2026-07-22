# frozen_string_literal: true

require "fileutils"

require_relative "install_error"

module Workspace
  module Services
    module Cms
      # Copies defined scaffold templates into the frontend and workspace repositories for CMS installation
      class Scaffold
        TEMPLATE_ROOT = File.expand_path("templates", __dir__)

        def initialize(context:)
          @context = context
        end

        def copy_templates(frontend_root:, mappings:, executable_destinations: [])
          mappings.each do |mapping|
            source = File.join(TEMPLATE_ROOT, mapping.fetch(:source))
            destination = resolve_destination(frontend_root, mapping)

            next if File.exist?(destination)

            FileUtils.mkdir_p(File.dirname(destination))
            FileUtils.cp(source, destination)
          end

          executable_destinations.each do |relative_path|
            destination = File.join(frontend_root, relative_path)
            next unless File.exist?(destination)

            File.chmod(0o755, destination)
          end
        rescue KeyError => e
          raise InstallError.new("CMS scaffolding failed.", details: "Missing scaffold mapping key: #{e.message}")
        rescue Errno::ENOENT => e
          raise InstallError.new("CMS scaffolding failed.", details: e.message)
        end

        private

        attr_reader :context

        def resolve_destination(frontend_root, mapping)
          destination = mapping.fetch(:destination)
          case mapping.fetch(:scope)
          when :frontend
            File.join(frontend_root, destination)
          when :workspace
            context.path(destination)
          else
            raise InstallError.new("CMS scaffolding failed.", details: "Unsupported scaffold scope: #{mapping[:scope].inspect}")
          end
        end
      end
    end
  end
end
