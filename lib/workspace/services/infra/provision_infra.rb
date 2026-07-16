#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for infra utility scripts.
#
# Responsibilities:
# - Dispatch supported actions (`doctor`, `configure`, `plan`, `apply`) from a single entrypoint.
# - Validate local scaffold and required config before infra operations.
# - Generate config/project.yml environment infrastructure and terraform.tfvars.json from guided prompts.
# - Run `init` before `plan`/`apply` to keep provider/module state current.
# - Resolve Terraform/OpenTofu binary via INFRA_TERRAFORM_BIN or PATH.
# - Resolve var file via INFRA_VAR_FILE (default: terraform.tfvars.json).

require "shellwords"
require "json"
require "yaml"
require "tty-prompt"
require_relative "../../../workspace"
require_relative "../../../workspace/secrets/resolver"
require_relative "./command_line_options"
require_relative "./configuration_prompt"

module Workspace
  module Services
    module Infra
      class ProvisionInfra
        TERRAFORM_DIR = File.join(Workspace::ROOT, "infra", "digitalocean_v2")
        PROJECT_MANIFEST_FILE = File.join(Workspace::ROOT, "config", "project.yml")
        DEFAULT_VAR_FILE = "terraform.tfvars.json"
        DEFAULT_PLAN_FILE = "tfplan"
        DIGITALOCEAN_TOKEN_KEY = "DIGITALOCEAN_ACCESS_TOKEN"

        def initialize(argv, stdin: $stdin, stdout: $stdout)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @prompt = TTY::Prompt.new(input: @stdin, output: @stdout)
          @secrets_resolver = Workspace::Secrets::Resolver.new(io: @stdout, input: @stdin)
        end

        def call
          options = CommandLineOptions.parse(argv)
          return options.exit_code unless options.valid?

          case options.action
          when "doctor"
            run_doctor(options.environment)
          when "configure"
            run_configure(options.environment)
          else
            run_terraform_action(options.action)
          end
        end

        private

        attr_reader :argv, :stdin, :stdout, :prompt

        def run_doctor(environment)
          checks = [
            ["Terraform/OpenTofu CLI", -> { check_cli_available(["terraform", "tofu"], "Terraform/OpenTofu") }],
            ["doctl CLI", -> { check_cli_available(["doctl"], "doctl") }],
            ["GitHub CLI", -> { check_cli_available(["gh"], "GitHub CLI") }],
            ["git CLI", -> { check_cli_available(["git"], "git") }],
            [DIGITALOCEAN_TOKEN_KEY, -> { check_digitalocean_access_token }],
            ["doctl auth", -> { check_doctl_auth }],
            ["gh auth", -> { check_gh_auth }],
            ["expected repositories", -> { check_expected_repositories }],
            ["blob store readiness", -> { check_blob_store_readiness(environment) }]
          ]

          failed_checks = []
          checks.each do |label, check|
            failed_checks << label unless check.call
          end

          unless failed_checks.empty?
            Workspace.info("infra doctor failed checks: #{failed_checks.join(', ')}")
            Workspace.fail("infra doctor detected one or more issues")
            return 1
          end

          Workspace.ok("infra doctor checks passed")
          0
        end

        def run_configure(environment)
          base_config = existing_infra_config(environment)
          ensure_digitalocean_access_token(interactive: true)
          Workspace.info("Starting guided infra configure flow for #{environment}.")
          Workspace.info("Press Enter to accept defaults shown in [brackets].")
          config = ConfigurationPrompt.new(
            prompt: prompt,
            output: stdout
          ).call(environment: environment, defaults: base_config)

          write_project_manifest_infra_config!(environment, config)
          write_terraform_var_file!(terraform_variables_for(config))

          Workspace.ok("infra configure completed for #{environment}")
          Workspace.info("Generated: config/project.yml")
          Workspace.info("Generated: infra/digitalocean_v2/#{terraform_var_file_name}")
          0
        end

        def run_terraform_action(action)
          prepare_working_directory!
          ensure_digitalocean_access_token(interactive: true)
          run_init
          run_action(action)
          Workspace.ok("infra #{action} completed")
          0
        end

        def prepare_working_directory!
          ensure_terraform_directory_exists!
          ensure_var_file_exists!
        end

        def ensure_terraform_directory_exists!
          return if Dir.exist?(TERRAFORM_DIR)

          Workspace.abort_with_help(
            "Terraform directory is missing.",
            details: "Expected directory: #{TERRAFORM_DIR}",
            fixes: [
              "Ensure infra scaffold exists under infra/digitalocean_v2.",
              "Run this command from the product-template-workspace root."
            ]
          )
        end

        def ensure_var_file_exists!
          return if File.exist?(terraform_var_file_path)

          Workspace.abort_with_help(
            "Missing Terraform var-file.",
            details: "Expected file: #{terraform_var_file_path}",
            fixes: [
              "Create infra/digitalocean_v2/#{terraform_var_file_name} with environment values.",
              "Populate required keys listed in infra/digitalocean_v2/variables.tf."
            ]
          )
        end

        def run_init
          Workspace.info("Initializing infra working directory")
          Workspace.run(terraform_command("init"), chdir: Workspace::ROOT)
        end

        def run_action(action)
          Workspace.info("Running infra #{action}")

          action_flags = ["-var-file=#{Shellwords.escape(terraform_var_file_name)}"]
          action_flags << "-out=#{Shellwords.escape(terraform_plan_file_name)}" if action == "plan"

          Workspace.run(
            terraform_command(action, *action_flags),
            chdir: Workspace::ROOT
          )
        end

        def existing_infra_config(environment)
          manifest = load_project_manifest
          return {} if manifest.empty?

          infrastructure = dig_value(manifest, "environments", environment, "infrastructure") || {}

          {
            "app_name" => infrastructure["app_name"] || dig_value(manifest, "project", "slug") || default_app_name,
            "environment" => environment,
            "region" => infrastructure["app_region"] || "nyc",
            "do_region" => infrastructure["region"] || infrastructure["do_region"] || "nyc3",
            "github" => {
              "owner" => dig_value(infrastructure, "github", "owner") || default_github_owner,
              "api_repo" => repository_name_from_manifest(manifest, "api", default_repo_name("backend-api", "api-template")),
              "web_repo" => repository_name_from_manifest(manifest, "web", default_repo_name("frontend-web-client", "web-template")),
              "branch" => dig_value(infrastructure, "deployment", "branch") || "main",
              "auto_deploy" => dig_value(infrastructure, "deployment", "auto_deploy", fallback: true)
            },
            "components" => {
              "api" => dig_value(infrastructure, "components", "api", "enabled", fallback: true),
              "worker" => dig_value(infrastructure, "components", "worker", "enabled", fallback: true),
              "web" => dig_value(infrastructure, "components", "web", "enabled", fallback: true),
              "postgres" => dig_value(infrastructure, "components", "postgres", "enabled", fallback: true),
              "opensearch" => dig_value(infrastructure, "components", "opensearch", "enabled", fallback: true),
              "spaces" => dig_value(infrastructure, "components", "spaces", "enabled", fallback: true)
            },
            "sizes" => {
              "api" => dig_value(infrastructure, "components", "api", "size") || "basic-xxs",
              "worker" => dig_value(infrastructure, "components", "worker", "size") || "basic-xxs",
              "web" => dig_value(infrastructure, "components", "web", "size") || "basic-xxs",
              "postgres" => dig_value(infrastructure, "components", "postgres", "size") || "db-s-1vcpu-1gb",
              "opensearch" => dig_value(infrastructure, "components", "opensearch", "size")
            },
            "spaces_provider" => dig_value(infrastructure, "components", "spaces", "provider") || "digitalocean_spaces"
          }
        rescue Psych::SyntaxError
          {}
        end

        def write_project_manifest_infra_config!(environment, config)
          manifest = load_project_manifest

          manifest["project"] ||= {}
          manifest["environments"] ||= {}
          manifest["environments"][environment] ||= {}

          existing_infrastructure = manifest["environments"][environment]["infrastructure"] || {}

          manifest["environments"][environment]["infrastructure"] = existing_infrastructure.merge(
            "provider" => existing_infrastructure["provider"] || "digitalocean",
            "app_name" => config.fetch("app_name"),
            "region" => config.fetch("do_region"),
            "app_region" => config.fetch("region"),
            "github" => {
              "owner" => dig_value(config, "github", "owner").to_s
            },
            "deployment" => {
              "branch" => dig_value(config, "github", "branch") || "main",
              "auto_deploy" => true
            },
            "components" => {
              "api" => {
                "enabled" => dig_value(config, "components", "api", fallback: true),
                "service" => "api",
                "size" => dig_value(config, "sizes", "api") || "basic-xxs"
              },
              "worker" => {
                "enabled" => dig_value(config, "components", "worker", fallback: true),
                "service" => "api",
                "size" => dig_value(config, "sizes", "worker") || "basic-xxs"
              },
              "web" => {
                "enabled" => dig_value(config, "components", "web", fallback: true),
                "service" => "web",
                "size" => dig_value(config, "sizes", "web") || "basic-xxs"
              },
              "postgres" => {
                "enabled" => dig_value(config, "components", "postgres", fallback: true),
                "size" => dig_value(config, "sizes", "postgres") || "db-s-1vcpu-1gb"
              },
              "opensearch" => {
                "enabled" => dig_value(config, "components", "opensearch", fallback: true)
              },
              "spaces" => {
                "enabled" => dig_value(config, "components", "spaces", fallback: true),
                "provider" => config.fetch("spaces_provider", "digitalocean_spaces")
              }
            }
          )

          opensearch_size = dig_value(config, "sizes", "opensearch").to_s.strip
          unless opensearch_size.empty?
            manifest["environments"][environment]["infrastructure"]["components"]["opensearch"]["size"] = opensearch_size
          end

          File.write(PROJECT_MANIFEST_FILE, manifest.to_yaml)
        end

        def write_terraform_var_file!(tfvars)
          path = terraform_var_file_path
          File.write(path, JSON.pretty_generate(tfvars) + "\n")
        end

        def terraform_variables_for(config)
          app_name = config.fetch("app_name")
          do_region = config.fetch("do_region")
          sizes = config.fetch("sizes", {})
          github = config.fetch("github", {})
          github_owner = github["owner"].to_s.strip
          web_repo_name = github["web_repo"].to_s.strip
          frontend_repo = [github_owner, web_repo_name].reject(&:empty?).join("/")

          {
            "project_name" => app_name,
            "rails_app_name" => github.fetch("api_repo", "#{app_name}-api"),
            "app_region" => config.fetch("region"),
            "web_instance_size_slug" => sizes.fetch("api", "basic-xxs"),
            "worker_instance_size_slug" => sizes.fetch("worker", "basic-xxs"),
            "frontend_app_name" => github.fetch("web_repo", "#{app_name}-web"),
            "frontend_repo" => frontend_repo,
            "frontend_branch" => github.fetch("branch", "main"),
            "frontend_web_instance_size_slug" => sizes.fetch("web", "basic-xxs"),
            "postgres_name" => "#{app_name}-postgres",
            "postgres_region" => do_region,
            "postgres_size" => sizes.fetch("postgres", "db-s-1vcpu-1gb"),
            "opensearch_name" => "#{app_name}-opensearch",
            "opensearch_region" => do_region
          }.tap do |tfvars|
            opensearch_size = sizes["opensearch"].to_s.strip
            tfvars["opensearch_size"] = opensearch_size unless opensearch_size.empty?
          end
        end

        def check_cli_available(commands, label)
          found = commands.find { |name| Workspace.command_exists?(name) }
          if found
            Workspace.ok("#{label}: #{found}")
            return true
          end

          Workspace.fail("#{label}: missing (checked #{commands.join(', ')})")
          false
        end

        def check_digitalocean_access_token
          token = ensure_digitalocean_access_token(interactive: false)
          if token
            Workspace.ok("#{DIGITALOCEAN_TOKEN_KEY}: available")
            return true
          end

          Workspace.fail("#{DIGITALOCEAN_TOKEN_KEY}: missing")
          false
        end

        def check_doctl_auth
          return true unless Workspace.command_exists?("doctl")

          _out, success = Workspace.capture("doctl account get")
          if success
            Workspace.ok("doctl auth: valid")
            return true
          end

          Workspace.fail("doctl auth: invalid (run: doctl auth init)")
          false
        end

        def check_gh_auth
          return true unless Workspace.command_exists?("gh")

          _out, success = Workspace.capture("gh auth status")
          if success
            Workspace.ok("gh auth: valid")
            return true
          end

          Workspace.fail("gh auth: invalid (run: gh auth login)")
          false
        end

        def check_expected_repositories
          all_found = true
          targets = {
            "backend-api" => default_repo_name("backend-api", "api-template"),
            "frontend-web-client" => default_repo_name("frontend-web-client", "web-template")
          }

          targets.each do |purpose, name|
            repo = Workspace.repositories.find { |item| item["purpose"].to_s == purpose }
            path = repo && repo["path"]
            absolute_path = path && File.join(Workspace::ROOT, path)

            if absolute_path && Dir.exist?(absolute_path)
              Workspace.ok("repo #{name}: found")
            else
              Workspace.fail("repo #{name}: missing")
              all_found = false
            end
          end

          all_found
        end

        def check_blob_store_readiness(environment)
          config = existing_infra_config(environment)
          spaces_enabled = dig_value(config, "components", "spaces", fallback: true)
          return true unless spaces_enabled

          provider = config["spaces_provider"].to_s.strip
          return true if provider.empty?

          return check_aws_s3_readiness if provider == "aws_s3"

          Workspace.ok("blob storage provider '#{provider}': selected")
          true
        end

        def check_aws_s3_readiness
          Workspace.info("blob storage provider aws_s3: checking CLI/auth readiness")

          return false unless check_cli_available(["aws"], "AWS CLI")

          _out, success = Workspace.capture("aws sts get-caller-identity")
          if success
            Workspace.ok("AWS auth: valid")
            return true
          end

          Workspace.fail("AWS auth: invalid (run: aws configure, then aws sts get-caller-identity)")
          false
        end

        def load_project_manifest
          return {} unless File.exist?(PROJECT_MANIFEST_FILE)

          YAML.safe_load(File.read(PROJECT_MANIFEST_FILE), permitted_classes: [], aliases: false) || {}
        rescue Psych::SyntaxError
          {}
        end

        def repository_name_from_manifest(manifest, key, fallback)
          repos = manifest["repositories"]
          return fallback unless repos.is_a?(Hash)

          repo = repos[key]
          return fallback unless repo.is_a?(Hash)

          name = repo["name"].to_s.strip
          name.empty? ? fallback : name
        end

        def default_repo_name(purpose, fallback)
          repo = Workspace.repositories.find { |item| item["purpose"].to_s == purpose }
          return fallback unless repo

          repo["name"].to_s.empty? ? fallback : repo["name"].to_s
        end

        def default_github_owner
          backend = Workspace.repositories.find { |item| item["purpose"].to_s == "backend-api" }
          github = backend && backend["github"].to_s
          owner = github.split("/", 2).first
          return nil if owner.nil? || owner.empty?

          owner
        end

        def default_app_name
          File.basename(Workspace::ROOT).sub(/-workspace\z/, "")
        end

        def dig_value(hash, *keys, fallback: nil)
          value = keys.reduce(hash) do |memo, key|
            break nil unless memo.is_a?(Hash)

            memo[key]
          end
          value.nil? ? fallback : value
        end

        def ensure_digitalocean_access_token(interactive:)
          token = @secrets_resolver.digitalocean_token(interactive: interactive)
          return nil if token.nil? || token.empty?

          ENV[DIGITALOCEAN_TOKEN_KEY] = token
          token
        end

        def terraform_command(subcommand, *extra_flags)
          [
            Shellwords.escape(terraform_binary),
            "-chdir=#{Shellwords.escape(TERRAFORM_DIR)}",
            subcommand,
            *extra_flags
          ].join(" ")
        end

        def terraform_binary
          @terraform_binary ||= begin
            configured_binary = ENV.fetch("INFRA_TERRAFORM_BIN", "").strip
            return configured_binary unless configured_binary.empty?
            return "terraform" if Workspace.command_exists?("terraform")
            return "tofu" if Workspace.command_exists?("tofu")

            Workspace.abort_with_help(
              "Terraform/OpenTofu CLI not found.",
              details: "Install terraform/tofu or set INFRA_TERRAFORM_BIN.",
              fixes: [
                "Install Terraform: https://developer.hashicorp.com/terraform/install",
                "Install OpenTofu: https://opentofu.org/docs/intro/install/",
                "Export INFRA_TERRAFORM_BIN=/path/to/terraform"
              ]
            )
          end
        end

        def terraform_var_file_name
          ENV.fetch("INFRA_VAR_FILE", DEFAULT_VAR_FILE).strip
        end

        def terraform_var_file_path
          File.join(TERRAFORM_DIR, terraform_var_file_name)
        end

        def terraform_plan_file_name
          ENV.fetch("INFRA_PLAN_FILE", DEFAULT_PLAN_FILE).strip
        end
      end
    end
  end
end
