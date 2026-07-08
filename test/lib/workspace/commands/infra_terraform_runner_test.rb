# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/terraform_runner"

class InfraTerraformRunnerTest < Minitest::Test
  def test_init_uses_configured_binary_from_env
    Workspace.stubs(:info)

    Workspace.expects(:run).with(
      "custom-terraform -chdir=/tmp/infra init",
      chdir: "/tmp/workspace"
    ).returns(true)

    runner = Workspace::Commands::Infra::TerraformRunner.new(
      terraform_dir: "/tmp/infra",
      workspace_root: "/tmp/workspace",
      env: { "INFRA_TERRAFORM_BIN" => "custom-terraform" }
    )

    runner.init!
  end

  def test_run_action_uses_terraform_when_available
    Workspace.stubs(:info)
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)

    Workspace.expects(:run).with(
      "terraform -chdir=/tmp/infra plan -var-file=terraform.tfvars.json",
      chdir: "/tmp/workspace"
    ).returns(true)

    runner = Workspace::Commands::Infra::TerraformRunner.new(
      terraform_dir: "/tmp/infra",
      workspace_root: "/tmp/workspace",
      env: {}
    )

    runner.run_action!(action: "plan", var_file_name: "terraform.tfvars.json")
  end

  def test_run_action_uses_open_tofu_when_terraform_missing
    Workspace.stubs(:info)
    Workspace.stubs(:command_exists?).with("terraform").returns(false)
    Workspace.stubs(:command_exists?).with("tofu").returns(true)

    Workspace.expects(:run).with(
      "tofu -chdir=/tmp/infra apply -var-file=terraform.tfvars.json",
      chdir: "/tmp/workspace"
    ).returns(true)

    runner = Workspace::Commands::Infra::TerraformRunner.new(
      terraform_dir: "/tmp/infra",
      workspace_root: "/tmp/workspace",
      env: {}
    )

    runner.run_action!(action: "apply", var_file_name: "terraform.tfvars.json")
  end

  def test_init_aborts_when_no_binary_is_available
    Workspace.stubs(:info)
    Workspace.stubs(:command_exists?).with("terraform").returns(false)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)

    Workspace.expects(:abort_with_help).with(
      "Terraform/OpenTofu CLI not found.",
      has_entry(details: "Install terraform/tofu or set INFRA_TERRAFORM_BIN.")
    ).raises(SystemExit.new(1))

    runner = Workspace::Commands::Infra::TerraformRunner.new(
      terraform_dir: "/tmp/infra",
      workspace_root: "/tmp/workspace",
      env: {}
    )

    assert_raises(SystemExit) do
      runner.init!
    end
  end

  def test_output_values_reads_and_parses_terraform_output_json
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)

    Workspace.expects(:capture).with(
      "terraform -chdir=/tmp/infra output -json",
      chdir: "/tmp/workspace"
    ).returns([
      {
        "spaces_bucket" => { "value" => "bucket" },
        "aws_access_key_id" => { "value" => "access-id", "sensitive" => true }
      }.to_json,
      true
    ])

    runner = Workspace::Commands::Infra::TerraformRunner.new(
      terraform_dir: "/tmp/infra",
      workspace_root: "/tmp/workspace",
      env: {}
    )

    assert_equal(
      {
        "spaces_bucket" => "bucket",
        "aws_access_key_id" => "access-id"
      },
      runner.output_values!
    )
  end

  def test_output_values_aborts_when_output_command_fails
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)

    Workspace.expects(:capture).with(
      "terraform -chdir=/tmp/infra output -json",
      chdir: "/tmp/workspace"
    ).returns(["boom", false])

    Workspace.expects(:abort_with_help).with(
      "Unable to read Terraform outputs.",
      has_entry(details: "terraform output -json failed in /tmp/infra.")
    ).raises(SystemExit.new(1))

    runner = Workspace::Commands::Infra::TerraformRunner.new(
      terraform_dir: "/tmp/infra",
      workspace_root: "/tmp/workspace",
      env: {}
    )

    assert_raises(SystemExit) { runner.output_values! }
  end
end
