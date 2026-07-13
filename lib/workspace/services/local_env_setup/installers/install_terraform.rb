# frozen_string_literal: true

require_relative "../../../../workspace"
require_relative "homebrew_prerequisite"

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        class InstallTerraform
          include HomebrewPrerequisite

          def call
            return unless ensure_homebrew_available(for_tool: "Terraform")

            Workspace.info("Installing Terraform")
            Workspace.run(
              "brew tap hashicorp/tap",
              allow_failure: true,
              summary: "Terraform tap setup failed.",
              details: "Could not add hashicorp/tap Homebrew repository.",
              fixes: [
                "Check network connectivity and Homebrew configuration.",
                "Retry bin/install_local_dev_tools."
              ]
            )

            ok = Workspace.run(
              "brew install hashicorp/tap/terraform",
              allow_failure: true,
              summary: "Terraform installation failed.",
              details: "brew install hashicorp/tap/terraform did not complete successfully.",
              fixes: [
                "Run brew doctor and retry.",
                "Verify no conflicting terraform binaries are blocking install."
              ]
            )

            Workspace.ok("Terraform installation completed.") if ok
          end
        end
      end
    end
  end
end
