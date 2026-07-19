# frozen_string_literal: true

require "optparse"
require "tty-prompt"
require_relative "../../../workspace"
require_relative "../../project_manifest/loader"
require_relative "../../secrets/resolver"
require_relative "../../services/infra/credentials"
require_relative "../../infrastructure/digitalocean/client"
require_relative "../../infrastructure/digitalocean/resource_inventory"
require_relative "../../infrastructure/digitalocean/resource_purger"
require_relative "../../infrastructure/digitalocean/spaces_client"

module Workspace
  module Commands
    class Infra
      # Destructive command that deletes matched resources after explicit confirmation.
      class DigitaloceanPurgeCommand
        # No-op Spaces adapter used when Spaces is disabled for the environment.
        class NullSpacesClient
          def bucket_exists?(_name)
            false
          end

          def delete_bucket(_name); end
        end

        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr, prompt: nil)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
          @prompt = prompt || TTY::Prompt.new(input: stdin, output: stdout)
        end

        def call
          options = parse_options(argv)
          return options.fetch(:exit_code) if options.key?(:exit_code)

          return 1 unless export_digitalocean_token!

          environment = options.fetch(:environment)
          inventory = build_inventory(environment: environment).call

          print_summary(inventory)

          expected_project_name = inventory.fetch(:project).fetch("name")
          confirmation = options.fetch(:confirm_project, nil)
          confirmation ||= prompt.ask("Type #{expected_project_name.inspect} to delete these resources:") if interactive_input?

          unless confirmation == expected_project_name
            Workspace.info("DigitalOcean purge cancelled.")
            return 1
          end

          build_purger(environment: environment, inventory: inventory).call
          Workspace.ok("DigitalOcean resources deleted.")

          report_remaining(environment: environment)
          0
        rescue Workspace::ProjectManifest::InvalidManifest => e
          Workspace.fail_with_help("Invalid project manifest.", details: e.message)
          1
        rescue Workspace::Infrastructure::DigitalOcean::Error, Aws::S3::Errors::ServiceError => e
          if project_not_found_error?(e)
            Workspace.info(e.message)
            return 0
          end

          Workspace.fail_with_help("DigitalOcean purge failed.", details: e.message)
          1
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr, :prompt

        def parse_options(arguments)
          options = { environment: "production" }

          parser = OptionParser.new do |opts|
            opts.on("--environment=NAME", "Environment name (default: production)") do |value|
              options[:environment] = value.to_s.strip
            end
            opts.on("--confirm-project=NAME", "Non-interactive confirmation token") do |value|
              options[:confirm_project] = value.to_s.strip
            end
          end

          parser.parse!(arguments)
          options
        rescue OptionParser::InvalidOption => e
          stderr.puts(e.message)
          stderr.puts("Usage: bin/workspace infra digitalocean purge [--environment=production] [--confirm-project=my-super-app]")
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

        def build_purger(environment:, inventory:)
          Workspace::Infrastructure::DigitalOcean::ResourcePurger.new(
            client: Workspace::Infrastructure::DigitalOcean::Client.new,
            spaces_client: spaces_client_for(environment: environment),
            inventory: inventory
          )
        end

        def report_remaining(environment:)
          account_inventory = build_inventory(environment: environment).account_inventory
          remaining = account_inventory.fetch(:matching_resources).values.flatten

          Workspace.section("Remaining Matching Account Resources")
          if remaining.empty?
            Workspace.info("None")
            return
          end

          remaining.each do |resource|
            Workspace.warn([resource.type, resource.name, resource.id, resource.region].compact.join(" | "))
          end
        rescue Workspace::Infrastructure::DigitalOcean::Error => e
          Workspace.warn("Could not run post-purge inventory: #{e.message}")
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

        def spaces_client(environment:)
          infrastructure = infrastructure_for(environment)
          region = infrastructure.fetch("region", "nyc3")

          access_key_id = resolver.spaces_access_key_id(interactive: interactive_input?).to_s.strip
          secret_access_key = resolver.spaces_secret_access_key(interactive: interactive_input?).to_s.strip

          if access_key_id.empty? || secret_access_key.empty?
            raise Workspace::Infrastructure::DigitalOcean::Error,
                  "Spaces credentials are required to purge the Spaces bucket. Run: bin/workspace credentials init"
          end

          Workspace::Infrastructure::DigitalOcean::SpacesClient.new(
            region: region,
            access_key_id: access_key_id,
            secret_access_key: secret_access_key
          )
        end

        def spaces_client_for(environment:)
          return NullSpacesClient.new unless spaces_enabled?(environment: environment)

          spaces_client(environment: environment)
        end

        def spaces_enabled?(environment:)
          infrastructure = infrastructure_for(environment)
          infrastructure.fetch("components", {}).fetch("spaces", {}).fetch("enabled", true)
        end

        def print_summary(inventory)
          resources = inventory.fetch(:project_resources) + inventory.fetch(:matching_resources).values.flatten

          Workspace.section("Resources To Delete")

          resources
            .uniq { |resource| [resource.type, resource.id] }
            .each do |resource|
              Workspace.warn("#{resource.type}: #{resource.name || resource.id}")
            end

          Workspace.warn("Spaces bucket: #{inventory.fetch(:spaces_bucket_name)}")
          Workspace.warn("Project: #{inventory.fetch(:project).fetch('name')}")
        end

        def interactive_input?
          stdin.respond_to?(:tty?) && stdin.tty?
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
