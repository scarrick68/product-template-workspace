# frozen_string_literal: true

require "json"
require "open3"
require "pty"
require "securerandom"
require "shellwords"
require "tty-prompt"
require "English"
require_relative "../../../../workspace"
require_relative "../../../../workspace/secrets/workspace_credentials_store"

module Workspace
  module Services
    module Infra
      module Digitalocean
        # Bootstraps the first production admin account after a successful deploy.
        class AdminBootstrap
          class Error < StandardError; end

          COMPONENT_NAME = "api"
          ADMIN_PATH = "/admin/tools"
          RESULT_PREFIX = "ADMIN_BOOTSTRAP_RESULT="

          def initialize(terraform_workspace:, stdin:, stdout:, prompt: nil, workspace: Workspace, credentials_store: nil)
            @terraform_workspace = terraform_workspace
            @stdin = stdin
            @stdout = stdout
            @prompt = prompt || TTY::Prompt.new(input: stdin, output: stdout)
            @workspace = workspace
            @credentials_store = credentials_store || Workspace::Secrets::WorkspaceCredentialsStore.new
          end

          def call(environment:)
            ensure_credentials_available!

            app_id = terraform_output!("rails_app_id")
            app_url = terraform_output!("rails_app_url")
            admin = load_or_create_admin(environment)

            workspace.info("Creating initial admin account...")
            result = bootstrap_admin(app_id:, email: admin.fetch("email"), password: admin.fetch("password"))

            report_result(result, admin:, admin_url: "#{app_url.delete_suffix('/')}#{ADMIN_PATH}")
            true
          rescue Error => e
            workspace.fail_with_help(
              e.message,
              fixes: [
                "Verify the Rails app is deployed and healthy.",
                "Verify doctl is authenticated.",
                "Re-run the infrastructure apply command."
              ]
            )
            false
          end

          private

          attr_reader :terraform_workspace, :stdin, :stdout, :prompt, :workspace, :credentials_store

          def ensure_credentials_available!
            credentials_store.require_available!(
              message: "Workspace credentials must be initialized before creating the admin account."
            )
          rescue Workspace::Secrets::WorkspaceCredentialsStore::Error => e
            raise Error, e.message
          end

          def load_or_create_admin(environment)
            key = admin_credentials_key(environment)
            stored = credentials_store.read_hash(key)
            return stored if valid_admin_credentials?(stored)

            admin = {
              "email" => prompt_admin_email,
              "password" => generate_password
            }

            credentials_store.write_hash!(
              key,
              admin,
              message: "Could not save the generated admin credentials."
            )

            admin
          rescue Workspace::Secrets::WorkspaceCredentialsStore::Error => e
            raise Error, e.message
          end

          def valid_admin_credentials?(value)
            value.is_a?(Hash) && value["email"].to_s.strip != "" && value["password"].to_s.strip != ""
          end

          def prompt_admin_email
            raise Error, "An admin email is required when running non-interactively." unless interactive_input?

            prompt.ask("Initial admin email", required: true).to_s.strip
          end

          def terraform_output!(name)
            output, status = Open3.capture2e(
              "terraform",
              "-chdir=#{terraform_workspace.directory}",
              "output",
              "-raw",
              name
            )

            value = output.to_s.strip
            return value if status.success? && !value.empty?

            raise Error, "Could not read Terraform output #{name.inspect}."
          end

          def bootstrap_admin(app_id:, email:, password:)
            command = [
              "doctl",
              "apps",
              "console",
              app_id,
              COMPONENT_NAME
            ]

            script = <<~SH
              export ADMIN_EMAIL=#{Shellwords.escape(email)}
              export ADMIN_PASSWORD=#{Shellwords.escape(password)}

              for dir in "$PWD" /workspace /app /rails /home/rails; do
                if [ -x "$dir/bin/rails" ]; then
                  cd "$dir"
                  break
                fi
              done

              if [ ! -x bin/rails ]; then
                echo "bootstrap_error: bin/rails not found in expected directories"
                exit 127
              fi

              if bin/rails app:bootstrap_admin; then
                true
              elif bin/rails runner 'exit(1) unless defined?(Admins::Bootstrap); result = Admins::Bootstrap.call(email: ENV.fetch("ADMIN_EMAIL"), password: ENV.fetch("ADMIN_PASSWORD")); puts "#{RESULT_PREFIX}" + JSON.generate(result)'; then
                true
              else
                bin/rails runner 'email = ENV.fetch("ADMIN_EMAIL"); password = ENV.fetch("ADMIN_PASSWORD"); existing = Admin.first; if existing.nil?; admin = Admin.new(email: email, password: password, password_confirmation: password); admin.save!; puts "#{RESULT_PREFIX}" + JSON.generate({"status" => "created"}); elsif existing.email == email; puts "#{RESULT_PREFIX}" + JSON.generate({"status" => "already_exists"}); else; abort("An administrator already exists with a different email. This command only bootstraps the first admin."); end'
              fi
              exit
            SH

            output = run_in_pty(command, input: script, secrets: [email, password])

            parse_result(output)
          end

          def run_in_pty(command, input:, secrets:)
            output = +""
            status = nil

            PTY.spawn(*command, chdir: Workspace::ROOT) do |reader, writer, process_id|
              writer.write(input)
              writer.close

              begin
                loop do
                  output << reader.readpartial(4096)
                end
              rescue EOFError, Errno::EIO
                # Normal PTY shutdown.
              ensure
                Process.wait(process_id)
                status = $CHILD_STATUS
              end
            end

            return output if status&.success?

            raise Error, "The remote admin bootstrap command failed:\n#{tail(redact(output, secrets: secrets))}"
          rescue PTY::ChildExited
            raise Error, "The remote admin bootstrap command failed:\n#{tail(redact(output, secrets: secrets))}"
          end

          def parse_result(output)
            line = output.lines.find { |candidate| candidate.start_with?(RESULT_PREFIX) }
            raise Error, "Admin bootstrap returned no result." unless line

            JSON.parse(line.delete_prefix(RESULT_PREFIX))
          rescue JSON::ParserError
            raise Error, "Admin bootstrap returned invalid JSON."
          end

          def report_result(result, admin:, admin_url:)
            case result.fetch("status")
            when "created"
              workspace.ok("Initial admin account created.")
              workspace.info("Admin URL: #{admin_url}")
              workspace.info("Admin email: #{admin.fetch('email')}")
              workspace.info("Initial password: #{admin.fetch('password')}")
              workspace.warn("Change the password after signing in.")
            when "already_exists"
              workspace.ok("Initial admin account already exists.")
              workspace.info("Admin URL: #{admin_url}")
              workspace.info("This bootstrap step only initializes the first admin account.")
              workspace.warn("Provision additional admin accounts through your standard application admin provisioning flow.")
            else
              raise Error, "Unexpected admin bootstrap status: #{result['status'].inspect}"
            end
          end

          def interactive_input?
            stdin.respond_to?(:tty?) && stdin.tty?
          end

          def admin_credentials_key(environment)
            "environments.#{environment}.application.admin"
          end

          def tail(output, lines: 8)
            output.to_s.lines.last(lines).join.strip
          end

          def redact(output, secrets:)
            secrets.reduce(output.to_s) do |text, secret|
              next text if secret.to_s.empty?

              text.gsub(secret.to_s, "[REDACTED]")
            end
          end

          def generate_password
            SecureRandom.urlsafe_base64(24, false)
          end
        end
      end
    end
  end
end