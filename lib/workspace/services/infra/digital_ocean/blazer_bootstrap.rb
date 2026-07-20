# frozen_string_literal: true

require "open3"
require "pty"
require "shellwords"
require "English"
require_relative "../../../../workspace"

module Workspace
  module Services
    module Infra
      module Digitalocean
        # Installs default Blazer content in the deployed API component after infra apply.
        class BlazerBootstrap
          class Error < StandardError; end

          COMPONENT_NAME = "api"

          def initialize(terraform_workspace:, stdin:, stdout:, workspace: Workspace)
            @terraform_workspace = terraform_workspace
            @stdin = stdin
            @stdout = stdout
            @workspace = workspace
          end

          def call(environment:)
            app_id = terraform_output!("rails_app_id")
            workspace.info("Installing default Blazer content in #{environment}...")
            bootstrap_blazer(app_id: app_id, rails_env: rails_env_for(environment))
            workspace.ok("Default Blazer content installation completed.")
            true
          rescue Error => e
            workspace.fail_with_help(
              e.message,
              fixes: [
                "Verify the Rails app is deployed and healthy.",
                "Verify doctl is authenticated.",
                "Re-run bin/workspace infra apply #{environment}."
              ]
            )
            false
          end

          private

          attr_reader :terraform_workspace, :stdin, :stdout, :workspace

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

          def bootstrap_blazer(app_id:, rails_env:)
            command = [
              "doctl",
              "apps",
              "console",
              app_id,
              COMPONENT_NAME
            ]

            script = build_bootstrap_script(rails_env: rails_env)

            run_in_pty(command, input: script)
          end

          def run_in_pty(command, input:)
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

            return if status&.success?

            raise Error, "The remote Blazer bootstrap command failed:\n#{tail(output)}"
          rescue PTY::ChildExited
            raise Error, "The remote Blazer bootstrap command failed:\n#{tail(output)}"
          end

          def tail(output, lines: 8)
            output.to_s.lines.last(lines).join.strip
          end

          def rails_env_for(environment)
            value = environment.to_s.strip
            return "production" if value.empty?

            value
          end

          def build_bootstrap_script(rails_env:)
            <<~SH
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

              RAILS_ENV=#{Shellwords.escape(rails_env)} bin/rails blazer:default_queries:install
              RAILS_ENV=#{Shellwords.escape(rails_env)} bin/rails blazer:install_dashboards
              exit
            SH
          end
        end
      end
    end
  end
end
