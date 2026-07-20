# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      # Ensures Terraform operations have the minimum local prerequisites.
      class TerraformPreflight
        def initialize(workspace:)
          @workspace = workspace
        end

        def check!
          ensure_terraform_directory_exists!
          ensure_var_file_exists!
        end

        private

        attr_reader :workspace

        def ensure_terraform_directory_exists!
          return if Dir.exist?(workspace.directory)

          Workspace.abort_with_help(
            "Terraform directory is missing.",
            details: "Expected directory: #{workspace.directory}",
            fixes: [
              "Ensure infra scaffold exists under infra/digitalocean_v2.",
              "Run this command from the product-template-workspace root."
            ]
          )
        end

        def ensure_var_file_exists!
          return if File.exist?(workspace.var_file_path)

          Workspace.abort_with_help(
            "Missing Terraform var-file.",
            details: "Expected file: #{workspace.var_file_path}",
            fixes: [
              "Create infra/digitalocean_v2/#{workspace.var_file_name} with environment values.",
              "Populate required keys listed in infra/digitalocean_v2/variables.tf."
            ]
          )
        end
      end
    end
  end
end
