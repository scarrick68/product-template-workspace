# frozen_string_literal: true

require_relative "../../../../workspace"
require_relative "homebrew_prerequisite"

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        class InstallGh
          include HomebrewPrerequisite

          def call
            return unless ensure_homebrew_available(for_tool: "GitHub CLI")

            Workspace.info("Installing GitHub CLI")
            ok = Workspace.run(
              "brew install gh",
              allow_failure: true,
              summary: "GitHub CLI installation failed.",
              details: "brew install gh did not complete successfully.",
              fixes: [
                "Run brew doctor and resolve reported issues.",
                "Retry the install with bin/install_local_dev_tools."
              ]
            )

            Workspace.ok("GitHub CLI installation completed.") if ok
          end
        end
      end
    end
  end
end
