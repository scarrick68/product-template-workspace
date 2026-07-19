# frozen_string_literal: true

require "optparse"
require_relative "../../../workspace"
require_relative "../../project_manifest/loader"
require_relative "../../secrets/resolver"
require_relative "../../services/infra/credentials"
require_relative "../../infrastructure/digitalocean/client"
require_relative "../../infrastructure/digitalocean/resource_inventory"

module Workspace
  module Commands
    class Infra
      # Read-only command that reports project and account-level DigitalOcean resources.
      class DigitaloceanResourcesCommand
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
        end

        def call
          options = parse_options(argv)
          return options.fetch(:exit_code) if options.key?(:exit_code)

          return 1 unless export_digitalocean_token!

          inventory = build_inventory(environment: options.fetch(:environment)).call

          print_account(inventory.fetch(:account))
          print_project(inventory.fetch(:project))
          print_resources("Resources assigned to project", inventory.fetch(:project_resources))

          inventory.fetch(:matching_resources).each do |type, resources|
            print_resources("Matching #{type.to_s.tr('_', ' ')}", resources)
          end

          Workspace.section("Expected Spaces Bucket")
          Workspace.info(inventory.fetch(:spaces_bucket_name))

          0
        rescue Workspace::ProjectManifest::InvalidManifest => e
          Workspace.fail_with_help("Invalid project manifest.", details: e.message)
          1
        rescue Workspace::Infrastructure::DigitalOcean::Error => e
          if project_not_found_error?(e)
            Workspace.info(e.message)
            return 0
          end

          Workspace.fail_with_help("DigitalOcean inventory failed.", details: e.message)
          1
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr

        def parse_options(arguments)
          options = { environment: "production" }

          parser = OptionParser.new do |opts|
            opts.on("--environment=NAME", "Environment name (default: production)") do |value|
              options[:environment] = value.to_s.strip
            end
          end

          parser.parse!(arguments)
          options
        rescue OptionParser::InvalidOption => e
          stderr.puts(e.message)
          stderr.puts("Usage: bin/workspace infra digitalocean resources [--environment=production]")
          { exit_code: 1 }
        end

        def export_digitalocean_token!
          return true if credentials.export_terraform_environment!(interactive: true)

          Workspace.fail_with_help(
            "Missing DigitalOcean access token.",
            fixes: [
              "Run: bin/workspace credentials init",
              "Provide DIGITALOCEAN_ACCESS_TOKEN when prompted.",
              "Re-run this command."
            ]
          )
          false
        end

        def manifest
          @manifest ||= Workspace::ProjectManifest::Loader.new(root: Workspace::ROOT).load || {}
        end

        def build_inventory(environment:)
          infrastructure = infrastructure_for(environment)
          app_name = resolved_app_name(infrastructure)

          Workspace::Infrastructure::DigitalOcean::ResourceInventory.new(
            client: Workspace::Infrastructure::DigitalOcean::Client.new,
            project_name: app_name,
            expected_names: expected_names(app_name: app_name),
            spaces_bucket_name: spaces_bucket_name(app_name: app_name, infrastructure: infrastructure)
          )
        end

        def infrastructure_for(environment)
          manifest
            .fetch("environments", {})
            .fetch(environment, {})
            .fetch("infrastructure", {})
        end

        def resolved_app_name(infrastructure)
          app_name = infrastructure.fetch("app_name", "").to_s.strip
          return app_name unless app_name.empty?

          manifest.fetch("project", {}).fetch("slug", "workspace").to_s
        end

        def expected_names(app_name:)
          [
            repository_name("api", "#{app_name}-api"),
            repository_name("web", "#{app_name}-web"),
            "#{app_name}-postgres",
            "#{app_name}-opensearch"
          ].uniq
        end

        def repository_name(key, fallback)
          repositories = manifest.fetch("repositories", {})
          repo = repositories[key]
          return fallback unless repo.is_a?(Hash)

          name = repo.fetch("name", "").to_s.strip
          name.empty? ? fallback : name
        end

        def spaces_bucket_name(app_name:, infrastructure:)
          configured = infrastructure.dig("components", "spaces", "bucket_name").to_s.strip
          return configured unless configured.empty?

          slug = manifest.fetch("project", {}).fetch("slug", app_name).to_s
          installation_id = manifest.fetch("project", {}).fetch("installation_id", "").to_s

          sanitized = slug.downcase.gsub(/[^a-z0-9-]/, "-").gsub(/-+/, "-").gsub(/\A-|-\z/, "")
          normalized = sanitized.empty? ? "workspace" : sanitized
          "#{normalized}-artifacts-#{installation_id}"
        end

        def print_account(account)
          Workspace.section("DigitalOcean Account")
          Workspace.info("Email: #{account['email']}")
          Workspace.info("Status: #{account['status']}")
        end

        def print_project(project)
          Workspace.section("Project")
          Workspace.info("#{project.fetch('name')} (#{project.fetch('id')})")
        end

        def print_resources(title, resources)
          Workspace.section(title)

          if resources.empty?
            Workspace.info("None")
            return
          end

          resources.each do |resource|
            Workspace.info(
              [resource.type, resource.name, resource.id, resource.region, resource.urn].compact.join(" | ")
            )
          end
        end

        def resolver
          @resolver ||= Workspace::Secrets::Resolver.new(stdout: stdout, stdin: stdin)
        end

        def credentials
          @credentials ||= Workspace::Services::Infra::Credentials.new(secrets_resolver: resolver)
        end

        def project_not_found_error?(error)
          error.message.start_with?("DigitalOcean project not found:")
        end
      end
    end
  end
end
