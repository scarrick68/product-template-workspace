# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/project_structure_doctor_command"

class InfraProjectStructureDoctorCommandTest < Minitest::Test
  def test_returns_true_when_essential_config_and_tfvars_keys_are_present
    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(true)
    File.stubs(:exist?).with(tfvars_file).returns(true)

    File.stubs(:read).with(config_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project" => {
        "name" => "app-production",
        "environment" => "production",
        "purpose" => "Web Application"
      },
      "spaces_provider" => "digitalocean_spaces",
      "components" => {
        "api" => true,
        "worker" => true,
        "web" => true,
        "postgres" => true,
        "opensearch" => true,
        "spaces" => true
      },
      "github" => {
        "owner" => "org",
        "api_repo" => "api",
        "web_repo" => "web",
        "branch" => "main"
      }
    }.to_yaml)

    File.stubs(:read).with(tfvars_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project_name" => "app-production",
      "project_environment" => "production",
      "project_purpose" => "Web Application",
      "digitalocean_access_token" => "token",
      "rails_master_key" => "master-key",
      "enable_spaces" => true,
      "spaces_create_key" => true,
      "spaces_provider" => "digitalocean_spaces",
      "aws_access_key_id" => "<set-aws_access_key_id>",
      "aws_secret_access_key" => "<set-aws_secret_access_key>",
      "github_owner" => "org",
      "api_repo" => "api",
      "web_repo" => "web",
      "branch" => "main"
    }.to_json)

    Workspace.stubs(:ok)
    Workspace.stubs(:fail)

    command = Workspace::Commands::Infra::ProjectStructureDoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json"
    )

    assert_equal true, command.call
  end

  def test_returns_false_when_infra_config_missing_required_keys
    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(true)
    File.stubs(:exist?).with(tfvars_file).returns(true)

    File.stubs(:read).with(config_file).returns({
      "app_name" => "app",
      "components" => {
        "api" => true,
        "worker" => true,
        "web" => true,
        "postgres" => true,
        "opensearch" => true,
        "spaces" => true
      },
      "github" => {
        "owner" => "org",
        "api_repo" => "api",
        "web_repo" => "web",
        "branch" => "main"
      }
    }.to_yaml)

    File.stubs(:read).with(tfvars_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "digitalocean_access_token" => "token",
      "rails_master_key" => "master-key",
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "github_owner" => "org",
      "api_repo" => "api",
      "web_repo" => "web",
      "branch" => "main"
    }.to_json)

    Workspace.stubs(:ok)
    Workspace.stubs(:fail)

    command = Workspace::Commands::Infra::ProjectStructureDoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json"
    )

    assert_equal false, command.call
  end

  def test_returns_false_when_tfvars_missing_required_keys
    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(true)
    File.stubs(:exist?).with(tfvars_file).returns(true)

    File.stubs(:read).with(config_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project" => {
        "name" => "app-production",
        "environment" => "production",
        "purpose" => "Web Application"
      },
      "spaces_provider" => "digitalocean_spaces",
      "components" => {
        "api" => true,
        "worker" => true,
        "web" => true,
        "postgres" => true,
        "opensearch" => true,
        "spaces" => true
      },
      "github" => {
        "owner" => "org",
        "api_repo" => "api",
        "web_repo" => "web",
        "branch" => "main"
      }
    }.to_yaml)

    File.stubs(:read).with(tfvars_file).returns({
      "app_name" => "app",
      "enable_spaces" => true
    }.to_json)

    Workspace.stubs(:ok)
    Workspace.stubs(:fail)

    command = Workspace::Commands::Infra::ProjectStructureDoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json"
    )

    assert_equal false, command.call
  end

  def test_returns_false_when_infra_config_file_is_missing
    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(false)
    File.stubs(:exist?).with(tfvars_file).returns(true)
    File.stubs(:read).with(tfvars_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project_name" => "app-production",
      "project_environment" => "production",
      "project_purpose" => "Web Application",
      "digitalocean_access_token" => "token",
      "rails_master_key" => "master-key",
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "github_owner" => "org",
      "api_repo" => "api",
      "web_repo" => "web",
      "branch" => "main"
    }.to_json)

    Workspace.stubs(:ok)
    Workspace.stubs(:fail)

    command = Workspace::Commands::Infra::ProjectStructureDoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json"
    )

    assert_equal false, command.call
  end

  def test_returns_false_when_tfvars_json_is_invalid
    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(true)
    File.stubs(:exist?).with(tfvars_file).returns(true)

    File.stubs(:read).with(config_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project" => {
        "name" => "app-production",
        "environment" => "production",
        "purpose" => "Web Application"
      },
      "spaces_provider" => "digitalocean_spaces",
      "components" => {
        "api" => true,
        "worker" => true,
        "web" => true,
        "postgres" => true,
        "opensearch" => true,
        "spaces" => true
      },
      "github" => {
        "owner" => "org",
        "api_repo" => "api",
        "web_repo" => "web",
        "branch" => "main"
      }
    }.to_yaml)

    File.stubs(:read).with(tfvars_file).returns("{ bad json")

    Workspace.stubs(:ok)
    Workspace.stubs(:fail)

    command = Workspace::Commands::Infra::ProjectStructureDoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json"
    )

    assert_equal false, command.call
  end

  def test_returns_false_when_runtime_sensitive_secret_looks_like_placeholder
    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(true)
    File.stubs(:exist?).with(tfvars_file).returns(true)

    File.stubs(:read).with(config_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "spaces_provider" => "digitalocean_spaces",
      "components" => {
        "api" => true,
        "worker" => true,
        "web" => true,
        "postgres" => true,
        "opensearch" => true,
        "spaces" => true
      },
      "github" => {
        "owner" => "org",
        "api_repo" => "api",
        "web_repo" => "web",
        "branch" => "main"
      }
    }.to_yaml)

    File.stubs(:read).with(tfvars_file).returns({
      "app_name" => "app",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "project_name" => "app-production",
      "project_environment" => "production",
      "project_purpose" => "Web Application",
      "digitalocean_access_token" => "<set-digitalocean_access_token>",
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "github_owner" => "org",
      "api_repo" => "api",
      "web_repo" => "web",
      "branch" => "main"
    }.to_json)

    Workspace.stubs(:ok)
    Workspace.stubs(:fail)

    command = Workspace::Commands::Infra::ProjectStructureDoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json",
      phase: "runtime"
    )

    assert_equal false, command.call
  end
end
