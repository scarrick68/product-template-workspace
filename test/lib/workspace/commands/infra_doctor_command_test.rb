# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/doctor_command"

class InfraDoctorCommandTest < Minitest::Test
  def test_returns_zero_when_all_checks_pass
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("git").returns(true)

    Workspace.stubs(:capture).with("doctl account get").returns(["", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
      { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
    ])

    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/api-template")).returns(true)
    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/web-template")).returns(true)

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
        "spaces" => false
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
      "enable_spaces" => false,
      "spaces_provider" => "digitalocean_spaces",
      "github_owner" => "org",
      "api_repo" => "api",
      "web_repo" => "web",
      "branch" => "main"
    }.to_json)

    resolver = mock("secrets_resolver")
    resolver.expects(:digitalocean_token).with(interactive: false).returns("token")

    command = Workspace::Commands::Infra::DoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json",
      secrets_resolver: resolver,
      stdin: StringIO.new,
      stdout: StringIO.new
    )

    assert_equal 0, command.call
  end

  def test_returns_one_when_spaces_credentials_missing_for_managed_spaces
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("git").returns(true)

    Workspace.stubs(:capture).with("doctl account get").returns(["", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
      { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
    ])

    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/api-template")).returns(true)
    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/web-template")).returns(true)

    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(true)
    File.stubs(:read).with(config_file).returns({
      "components" => { "spaces" => true },
      "spaces_provider" => "digitalocean_spaces"
    }.to_yaml)

    File.stubs(:exist?).with(tfvars_file).returns(true)
    File.stubs(:read).with(tfvars_file).returns({
      "spaces_create_bucket" => true,
      "spaces_create_key" => true,
      "spaces_access_key_id" => nil,
      "spaces_secret_access_key" => nil
    }.to_json)

    resolver = mock("secrets_resolver")
    resolver.expects(:digitalocean_token).with(interactive: false).returns("token")

    command = Workspace::Commands::Infra::DoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json",
      secrets_resolver: resolver,
      stdin: StringIO.new,
      stdout: StringIO.new
    )

    assert_equal 1, command.call
  end

  def test_returns_one_when_digitalocean_token_missing
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("git").returns(true)

    Workspace.stubs(:capture).with("doctl account get").returns(["", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
      { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
    ])

    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/api-template")).returns(true)
    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/web-template")).returns(true)

    config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    tfvars_file = File.join(Workspace::ROOT, "infra", "digitalocean", "terraform.tfvars.json")

    File.stubs(:exist?).with(config_file).returns(false)
    File.stubs(:exist?).with(tfvars_file).returns(false)

    resolver = mock("secrets_resolver")
    resolver.expects(:digitalocean_token).with(interactive: false).returns(nil)

    command = Workspace::Commands::Infra::DoctorCommand.new(
      config_file: config_file,
      terraform_var_file_path: tfvars_file,
      terraform_var_file_name: "terraform.tfvars.json",
      secrets_resolver: resolver,
      stdin: StringIO.new,
      stdout: StringIO.new
    )

    assert_equal 1, command.call
  end
end
