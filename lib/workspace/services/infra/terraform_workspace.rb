# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      # Encapsulates Terraform/OpenTofu directory and file naming conventions.
      class TerraformWorkspace
        DEFAULT_DIRECTORY = File.join(Workspace::ROOT, "infra", "digitalocean_v2")
        DEFAULT_VAR_FILE = "terraform.tfvars.json"
        DEFAULT_PLAN_FILE = "tfplan"

        def initialize(directory: DEFAULT_DIRECTORY)
          @directory = directory
        end

        attr_reader :directory

        def var_file_name
          value = ENV.fetch("INFRA_VAR_FILE", DEFAULT_VAR_FILE).strip
          value.empty? ? DEFAULT_VAR_FILE : value
        end

        def var_file_path
          File.join(directory, var_file_name)
        end

        def plan_file_name
          value = ENV.fetch("INFRA_PLAN_FILE", DEFAULT_PLAN_FILE).strip
          value.empty? ? DEFAULT_PLAN_FILE : value
        end
      end
    end
  end
end
