# frozen_string_literal: true

require_relative "../../../../workspace"
require_relative "homebrew_prerequisite"

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        class InstallDocker
          include HomebrewPrerequisite

          def call
            return unless ensure_homebrew_available(for_tool: "Docker Desktop")

            Workspace.info("Installing Docker Desktop")
            ok = Workspace.run(
              "brew install --cask docker-desktop",
              allow_failure: true,
              summary: "Docker Desktop installation failed.",
              details: "brew install --cask docker-desktop did not complete successfully.",
              fixes: [
                "Close existing Docker installers and retry.",
                "Run brew doctor and resolve cask issues."
              ]
            )

            Workspace.ok("Docker installation completed.") if ok
          end
        end
      end
    end
  end
end
