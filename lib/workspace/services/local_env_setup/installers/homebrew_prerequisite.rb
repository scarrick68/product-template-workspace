# frozen_string_literal: true

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        module HomebrewPrerequisite
          private

          def ensure_homebrew_available(for_tool:)
            return true if Workspace.command_exists?("brew")

            Workspace.fail_with_help(
              "Homebrew is required before installing #{for_tool}.",
              details: "brew command not found in PATH.",
              fixes: [
                "Install Homebrew first: https://brew.sh/",
                "Then rerun: bin/install_local_dev_tools"
              ]
            )
            false
          end
        end
      end
    end
  end
end
