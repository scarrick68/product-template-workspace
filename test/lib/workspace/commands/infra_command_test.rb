# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/provision_infra_command"

class InfraCommandTest < Minitest::Test
  def test_returns_usage_when_action_missing
    Workspace.expects(:info).with("Usage: bin/infra [doctor|configure|plan|apply] [environment]")
    Workspace.expects(:info).with("Examples: bin/infra doctor | bin/infra configure production | bin/infra plan production")

    result = Workspace::Commands::Infra::ProvisionInfraCommand.new([]).call

    assert_equal 1, result
  end

  def test_returns_one_when_action_is_unsupported
    Workspace.expects(:fail_with_help).with(
      "Unsupported infra action 'destroy'.",
      has_entry(details: "Supported actions: doctor, configure, plan, apply")
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
end
