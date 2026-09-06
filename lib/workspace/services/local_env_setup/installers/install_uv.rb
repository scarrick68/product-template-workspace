# frozen_string_literal: true

require_relative "../../../../workspace"

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        class InstallUv
          UV_INSTALL_SCRIPT = "curl -LsSf https://astral.sh/uv/install.sh | sh"

          def call
            Workspace.info("Installing uv")

            if Workspace.command_exists?("pipx")
              Workspace.run(
                "pipx install uv",
                allow_failure: true,
                summary: "uv installation failed.",
                details: "pipx install uv did not complete successfully.",
                fixes: [
                  "Run pipx ensurepath, restart your shell, and retry.",
                  "Retry bin/install_local_dev_tools.",
                  "Use official install script if needed: #{UV_INSTALL_SCRIPT}"
                ]
              )
              return
            end

            Workspace.run(
              UV_INSTALL_SCRIPT,
              allow_failure: true,
              summary: "uv installation failed.",
              details: "The official uv install script did not complete successfully.",
              fixes: [
                "Install pipx and run: pipx install uv",
                "Review official docs: https://docs.astral.sh/uv/getting-started/installation/",
                "Retry bin/install_local_dev_tools."
              ]
            )
          end
        end
      end
    end
  end
end
