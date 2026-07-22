# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/cli"

class WorkspaceCliTest < Minitest::Test
  def test_returns_usage_for_unknown_command
    stderr = StringIO.new

    exit_code = Workspace::CLI::Runner.new(["unknown"], stderr: stderr).call

    assert_equal 1, exit_code
    assert_includes stderr.string, "Usage: bin/workspace <command> [options]"
  end

  def test_suggests_kebab_case_when_user_passes_underscore_format
    stderr = StringIO.new

    exit_code = Workspace::CLI::Runner.new(["new_project"], stderr: stderr).call

    assert_equal 1, exit_code
    assert_includes stderr.string, "Unknown command: new_project"
    assert_includes stderr.string, "Did you mean: new-project?"
  end

  def test_suggests_prefix_match_for_near_command_name
    stderr = StringIO.new

    exit_code = Workspace::CLI::Runner.new(["cred"], stderr: stderr).call

    assert_equal 1, exit_code
    assert_includes stderr.string, "Unknown command: cred"
    assert_includes stderr.string, "Did you mean: credentials?"
  end

  def test_dispatches_to_new_project_command
    command = mock("new_project_command")
    Workspace::Commands::NewProject.expects(:new).with(
      ["my-super-app"],
      has_entries(stderr: kind_of(IO), stdout: kind_of(IO), stdin: kind_of(IO))
    ).returns(command)
    command.expects(:call).returns(0)

    exit_code = Workspace::CLI::Runner.new(["new-project", "my-super-app"]).call

    assert_equal 0, exit_code
  end

  def test_dispatches_to_repository_command_group
    command = mock("repository_command")
    Workspace::Commands::Repository.expects(:new).with(
      ["setup", "my-super-app"],
      has_entries(stderr: kind_of(IO), stdout: kind_of(IO), stdin: kind_of(IO))
    ).returns(command)
    command.expects(:call).returns(0)

    exit_code = Workspace::CLI::Runner.new(["repository", "setup", "my-super-app"]).call

    assert_equal 0, exit_code
  end

  def test_dispatches_to_cms_command_group
    command = mock("cms_command")
    Workspace::Commands::Cms.expects(:new).with(
      ["add"],
      has_entries(stderr: kind_of(IO), stdout: kind_of(IO), stdin: kind_of(IO))
    ).returns(command)
    command.expects(:call).returns(0)

    exit_code = Workspace::CLI::Runner.new(["cms", "add"]).call

    assert_equal 0, exit_code
  end

  def test_dispatches_to_prod_local_command
    command = mock("prod_local_command")
    Workspace::Commands::ProdLocal.expects(:new).with(
      [],
      has_entries(stderr: kind_of(IO), stdout: kind_of(IO), stdin: kind_of(IO))
    ).returns(command)
    command.expects(:call).returns(0)

    exit_code = Workspace::CLI::Runner.new(["prod-local"]).call

    assert_equal 0, exit_code
  end
end
