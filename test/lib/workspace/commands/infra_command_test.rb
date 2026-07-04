# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra_command"

class InfraCommandTest < Minitest::Test
  def test_returns_usage_when_action_missing
    Workspace.expects(:info).with("Usage: bin/infra [plan|apply]")
    Workspace.expects(:info).with("Runs init first, then executes action in infra/digitalocean.")

    result = Workspace::Commands::InfraCommand.new([]).call

    assert_equal 1, result
  end

  def test_returns_one_when_action_is_unsupported
    Workspace.expects(:fail_with_help).with(
      "Unsupported infra action 'destroy'.",
      has_entry(details: "Supported actions: plan, apply")
    )

    result = Workspace::Commands::InfraCommand.new(["destroy"]).call

    assert_equal 1, result
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
      has_entry(details: "Expected file: #{File.join(Workspace::Commands::InfraCommand::TERRAFORM_DIR, 'terraform.tfvars.json')}")
    ).raises(SystemExit.new(1))

    assert_raises(SystemExit) do
      Workspace::Commands::InfraCommand.new(["plan"]).call
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
    terraform_dir = Workspace::Commands::InfraCommand::TERRAFORM_DIR

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} init",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} plan -var-file=terraform.tfvars.json",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    result = Workspace::Commands::InfraCommand.new(["plan"]).call

    assert_equal 0, result
  end
end
