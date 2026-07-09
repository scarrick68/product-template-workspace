# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/provision_infra_command"

class InfraCommandTest < Minitest::Test
  def setup
    File.stubs(:exist?).returns(false)
  end

  def test_returns_usage_when_action_missing
    Workspace.expects(:info).with("Usage: bin/infra [doctor|doctor-config|doctor-runtime|configure|plan|apply|bootstrap-spaces] [environment] [--phase=config|runtime]")
    Workspace.expects(:info).with("Examples: bin/infra doctor production --phase=config | bin/infra doctor-runtime production | bin/infra configure production | bin/infra plan production")

    result = Workspace::Commands::Infra::ProvisionInfraCommand.new([]).call

    assert_equal 1, result
  end

  def test_returns_one_when_action_is_unsupported
    Workspace.expects(:fail_with_help).with(
      "Unsupported infra action 'destroy'.",
      has_entry(details: "Supported actions: doctor, doctor-config, doctor-runtime, doctor:config, doctor:runtime, configure, plan, apply, bootstrap-spaces")
    )

    result = Workspace::Commands::Infra::ProvisionInfraCommand.new(["destroy"]).call

    assert_equal 1, result
  end

  def test_configure_writes_infra_yml_and_tfvars
    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "api-template",
        "path" => "repos/api-template",
        "github" => "example-org/api-template"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "web-template",
        "path" => "repos/web-template",
        "github" => "example-org/web-template"
      }
    ])
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    File.stubs(:exist?).with(Workspace::Commands::Infra::ProvisionInfraCommand::CONFIG_FILE).returns(false)

    File.expects(:write).with(Workspace::Commands::Infra::ProvisionInfraCommand::CONFIG_FILE, includes("app_name: my-product"))
    File.expects(:write).with(
      File.join(Workspace::Commands::Infra::ProvisionInfraCommand::TERRAFORM_DIR, "terraform.tfvars.json"),
      includes("\"app_name\": \"my-product\"")
    )

    input = StringIO.new("my-product\nnyc\nnyc3\nexample-org\nmy-product-api\nmy-product-web\nmain\ny\nn\ny\naws_s3\n")
    output = StringIO.new

    result = Workspace::Commands::Infra::ProvisionInfraCommand.new(["configure", "production"], stdin: input, stdout: output).call

    assert_equal 0, result
  end

  def test_abort_when_var_file_is_missing
    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:run).returns(true)
    Workspace.stubs(:info)
    Workspace.stubs(:ok)
    Dir.stubs(:exist?).returns(true)
    File.stubs(:exist?).returns(false)

    Workspace.expects(:abort_with_help).with(
      "Missing Terraform var-file.",
      has_entry(details: "Expected file: #{File.join(Workspace::Commands::Infra::ProvisionInfraCommand::TERRAFORM_DIR, 'terraform.tfvars.json')}")
    ).raises(SystemExit.new(1))

    assert_raises(SystemExit) do
      Workspace::Commands::Infra::ProvisionInfraCommand.new(["plan"]).call
    end
  end

  def test_plan_runs_init_then_plan_with_default_var_file
    Workspace.stubs(:info)
    Workspace.stubs(:ok)
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Dir.stubs(:exist?).returns(true)
    File.stubs(:exist?).returns(true)

    sequence = sequence("infra-plan-sequence")
    terraform_dir = Workspace::Commands::Infra::ProvisionInfraCommand::TERRAFORM_DIR

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} init",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} plan -var-file=terraform.tfvars.json",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    result = Workspace::Commands::Infra::ProvisionInfraCommand.new(["plan"], stdin: StringIO.new, stdout: StringIO.new).call

    assert_equal 0, result
  end

  def test_doctor_returns_zero_when_all_checks_pass
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("git").returns(true)

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
      { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
    ])

    command = Workspace::Commands::Infra::ProvisionInfraCommand.new(["doctor"], stdin: StringIO.new, stdout: StringIO.new)
    resolver = mock("secrets_resolver")
    resolver.expects(:digitalocean_token).with(interactive: false).returns("token")
    command.instance_variable_set(:@secrets_resolver, resolver)

    Workspace.stubs(:capture).with("doctl account get --access-token token").returns(["", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])

    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/api-template")).returns(true)
    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/web-template")).returns(true)

    config_file = Workspace::Commands::Infra::ProvisionInfraCommand::CONFIG_FILE
    tfvars_file = File.join(Workspace::Commands::Infra::ProvisionInfraCommand::TERRAFORM_DIR, "terraform.tfvars.json")

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

    assert_equal 0, command.call
  end

  def test_doctor_runtime_alias_runs_runtime_phase
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail)
    Workspace.stubs(:repositories).returns([])

    config_file = Workspace::Commands::Infra::ProvisionInfraCommand::CONFIG_FILE
    tfvars_file = File.join(Workspace::Commands::Infra::ProvisionInfraCommand::TERRAFORM_DIR, "terraform.tfvars.json")

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
        "postgres" => false,
        "opensearch" => false,
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
      "enable_postgres" => false,
      "enable_opensearch" => false,
      "enable_spaces" => false,
      "spaces_provider" => "digitalocean_spaces",
      "github_owner" => "org",
      "api_repo" => "api",
      "web_repo" => "web",
      "branch" => "main"
    }.to_json)

    resolver = mock("secrets_resolver")
    resolver.stubs(:digitalocean_token).returns("token")

    runner = mock("terraform_runner")
    runner.expects(:output_values!).returns({
      "app_id" => "app-id",
      "app_live_url" => "https://example.com",
      "project_id" => "project-id",
      "project_name" => "app-production"
    })

    command = Workspace::Commands::Infra::ProvisionInfraCommand.new(["doctor-runtime", "production"], stdin: StringIO.new, stdout: StringIO.new)
    command.instance_variable_set(:@secrets_resolver, resolver)
    command.instance_variable_set(:@terraform_runner, runner)

    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)

    assert_equal 0, command.call
  end
end
