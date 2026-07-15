# frozen_string_literal: true

require "shellwords"
require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/init_step_runner"

class InitStepRunnerTest < Minitest::Test
  def test_shell_runs_script_with_context_root_and_escaped_args
    context = Workspace::Context.new(root: "/tmp/generated-workspace")
    runner = Workspace::Services::InitStepRunner.new(context: context)

    Workspace.stubs(:section)

    Workspace.expects(:script_path)
      .with("preinstall_checks", context: context)
      .returns("/tmp/generated-workspace/bin/preinstall_checks")

    expected_command = [
      Shellwords.escape("/tmp/generated-workspace/bin/preinstall_checks"),
      Shellwords.escape("--flag"),
      Shellwords.escape("value with space")
    ].join(" ")

    Workspace.expects(:run).with(
      expected_command,
      has_entries(chdir: "/tmp/generated-workspace", allow_failure: true)
    ).returns(true)

    assert runner.shell("Environment prechecks", "preinstall_checks", args: ["--flag", "value with space"])
  end

  def test_ruby_returns_true_when_block_returns_zero
    context = Workspace::Context.new(root: "/tmp/generated-workspace")
    runner = Workspace::Services::InitStepRunner.new(context: context)

    Workspace.stubs(:section)
    Workspace.expects(:fail_with_help).never

    assert runner.ruby("Environment diagnostics") { 0 }
  end

  def test_ruby_returns_false_and_reports_failure_when_block_returns_non_zero
    context = Workspace::Context.new(root: "/tmp/generated-workspace")
    runner = Workspace::Services::InitStepRunner.new(context: context)

    Workspace.stubs(:section)
    Workspace.expects(:fail_with_help).with(
      "Init workflow failed at step: Environment diagnostics.",
      has_entries(details: "Command object returned exit code 2.")
    )

    refute runner.ruby("Environment diagnostics") { 2 }
  end

  def test_ruby_handles_system_exit_status
    context = Workspace::Context.new(root: "/tmp/generated-workspace")
    runner = Workspace::Services::InitStepRunner.new(context: context)

    Workspace.stubs(:section)
    Workspace.expects(:fail_with_help).with(
      "Init workflow failed at step: Repository bootstrap.",
      has_entries(details: "Command object returned exit code 1.")
    )

    refute runner.ruby("Repository bootstrap") { raise SystemExit.new(1) }
  end
end
