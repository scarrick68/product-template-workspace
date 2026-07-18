# frozen_string_literal: true

require "tmpdir"
require "json"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/cors_origin_synchronizer"

class CorsOriginSynchronizerTest < Minitest::Test
  WorkspaceDouble = Struct.new(:capture_output, :capture_success) do
    def info(_message); end

    def ok(_message); end

    def capture(_command)
      [capture_output, capture_success]
    end
  end

  def test_initial_apply_uses_configured_frontend_domain
    Dir.mktmpdir("cors-sync-test") do |dir|
      tfvars_path = File.join(dir, "terraform.tfvars.json")
      File.write(tfvars_path, JSON.pretty_generate({ "rails_cors_allowed_origins" => "", "frontend_app_name" => "my-app-web" }))

      manifest = mock("manifest")
      manifest.expects(:read).with(environment: "production").returns({ "frontend_domain" => "app.example.com" })

      workspace = WorkspaceDouble.new("[]", true)
      terraform_workspace = Struct.new(:var_file_path).new(tfvars_path)

      service = Workspace::Services::Infra::CorsOriginSynchronizer.new(
        manifest_configuration: manifest,
        terraform_workspace: terraform_workspace,
        workspace: workspace
      )

      service.ensure_backend_cors_origin_value_for_initial_apply!(environment: "production")

      updated = JSON.parse(File.read(tfvars_path))
      assert_equal "https://app.example.com", updated.fetch("rails_cors_allowed_origins")
    end
  end

  def test_post_apply_updates_cors_when_missing_and_frontend_url_exists
    Dir.mktmpdir("cors-sync-test") do |dir|
      tfvars_path = File.join(dir, "terraform.tfvars.json")
      File.write(tfvars_path, JSON.pretty_generate({ "rails_cors_allowed_origins" => "", "frontend_app_name" => "my-app-web" }))

      manifest = mock("manifest")
      workspace = WorkspaceDouble.new(
        JSON.pretty_generate([
          {
            "spec" => { "name" => "my-app-web" },
            "default_ingress" => "https://my-app-web-abc123.ondigitalocean.app"
          }
        ]),
        true
      )
      terraform_workspace = Struct.new(:var_file_path).new(tfvars_path)

      service = Workspace::Services::Infra::CorsOriginSynchronizer.new(
        manifest_configuration: manifest,
        terraform_workspace: terraform_workspace,
        workspace: workspace
      )

      changed = service.fill_backend_cors_origin_from_live_frontend_url_if_missing!

      assert_equal true, changed
      updated = JSON.parse(File.read(tfvars_path))
      assert_equal "https://my-app-web-abc123.ondigitalocean.app", updated.fetch("rails_cors_allowed_origins")
    end
  end

  def test_post_apply_does_not_update_when_cors_already_set
    Dir.mktmpdir("cors-sync-test") do |dir|
      tfvars_path = File.join(dir, "terraform.tfvars.json")
      File.write(tfvars_path, JSON.pretty_generate({ "rails_cors_allowed_origins" => "https://app.example.com", "frontend_app_name" => "my-app-web" }))

      manifest = mock("manifest")
      workspace = WorkspaceDouble.new("[]", true)
      terraform_workspace = Struct.new(:var_file_path).new(tfvars_path)

      service = Workspace::Services::Infra::CorsOriginSynchronizer.new(
        manifest_configuration: manifest,
        terraform_workspace: terraform_workspace,
        workspace: workspace
      )

      changed = service.fill_backend_cors_origin_from_live_frontend_url_if_missing!

      assert_equal false, changed
      updated = JSON.parse(File.read(tfvars_path))
      assert_equal "https://app.example.com", updated.fetch("rails_cors_allowed_origins")
    end
  end
end
