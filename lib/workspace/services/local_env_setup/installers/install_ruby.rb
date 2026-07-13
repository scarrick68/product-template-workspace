# frozen_string_literal: true

require_relative "../../../../workspace"
require_relative "homebrew_prerequisite"

module Workspace
  module Services
    module LocalEnvSetup
      module Installers
        class InstallRuby
          include HomebrewPrerequisite

          def call
            return unless ensure_homebrew_available(for_tool: "Ruby toolchain (mise)")

            required = Workspace.required_ruby_version
            Workspace.info("Installing mise")
            
            mise_ok = Workspace.run(
              "brew install mise",
              allow_failure: true,
              summary: "mise installation failed.",
              details: "brew install mise did not complete successfully.",
              fixes: [
                "Run brew doctor and resolve issues.",
                "Retry bin/install_local_dev_tools."
              ]
            )

            Workspace.info("Installing Ruby #{required} with mise")
            ruby_ok = Workspace.run(
              "mise install ruby@#{required}",
              allow_failure: true,
              summary: "Ruby installation with mise failed.",
              details: "Could not install ruby@#{required} via mise.",
              fixes: [
                "Ensure build dependencies are installed (Xcode CLT on macOS).",
                "Retry bin/install_local_dev_tools after resolving mise install errors."
              ]
            )

            Workspace.run(
              "mise use --global ruby@#{required}",
              allow_failure: true,
              summary: "Could not set global Ruby version with mise.",
              details: "mise use --global ruby@#{required} failed.",
              fixes: [
                "Check your shell profile for mise activation.",
                "Restart your shell and rerun bin/install_local_dev_tools."
              ]
            )

            Workspace.ok("Ruby toolchain installation completed.") if ruby_ok
          end
        end
      end
    end
  end
end
