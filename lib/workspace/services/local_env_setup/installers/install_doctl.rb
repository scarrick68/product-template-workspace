# frozen_string_literal: true

require_relative "../../../../workspace"
require_relative "homebrew_prerequisite"

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        class InstallDoctl
          include HomebrewPrerequisite

          def call
            return unless ensure_homebrew_available(for_tool: "doctl")

            Workspace.info("Installing DigitalOcean CLI")
            ok = Workspace.run(
              "brew install doctl",
              allow_failure: true,
              summary: "DigitalOcean CLI installation failed.",
              details: "brew install doctl did not complete successfully.",
              fixes: [
                "Run brew doctor and resolve reported issues.",
                "Retry the install with bin/install_local_dev_tools."
              ]
            )

            Workspace.ok("doctl installation completed.") if ok
          end
        end
      end
    end
  end
end
