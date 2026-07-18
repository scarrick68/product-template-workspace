# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Digitalocean
        # Guides the one-time DigitalOcean GitHub App authorization detour.
        # This does not create an app; Terraform remains the app provisioning path.
        class GithubAppAuthorization
          AUTHORIZATION_URL = "https://cloud.digitalocean.com/apps/github/install"
          OPEN_COMMAND = ["open", AUTHORIZATION_URL].freeze

          def initialize(prompt:, stdin:, stdout:)
            @prompt = prompt
            @stdin = stdin
            @stdout = stdout
          end

          def call(repositories:)
            print_instructions(repositories)

            return false unless prompt.yes?("Open DigitalOcean GitHub authorization?", default: true)

            opened = open_authorization_url
            unless opened
              stdout.puts("Open this page manually:")
              stdout.puts(AUTHORIZATION_URL)
            end

            stdout.puts
            stdout.puts("Press Enter after granting repository access.")
            stdin.gets

            prompt.yes?("Did you grant DigitalOcean access to all listed repositories?", default: true)
          end

          private

          attr_reader :prompt, :stdin, :stdout

          def print_instructions(repositories)
            stdout.puts
            stdout.puts("Configuring DigitalOcean App Platform source access...")
            stdout.puts
            stdout.puts("DigitalOcean needs permission to read these private repositories:")
            stdout.puts
            repositories.each do |repository|
              stdout.puts("  - #{repository}")
            end
            stdout.puts
            stdout.puts("A browser will open to install or update the DigitalOcean GitHub App.")
            stdout.puts
            stdout.puts("In the browser:")
            stdout.puts("  1. Select the GitHub account or organization.")
            stdout.puts("  2. Grant access to the repositories listed above.")
            stdout.puts("  3. When DigitalOcean opens the Create App screen, stop there.")
            stdout.puts("  4. Return to this terminal. The app will be created by Terraform.")
            stdout.puts
          end

          def open_authorization_url
            system(*OPEN_COMMAND)
          end
        end
      end
    end
  end
end
