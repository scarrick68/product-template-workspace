# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "../../../test_helper"

class SetupToolsCommandTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("setup-tools-test")
    @prefs_path = File.join(@tmpdir, "setup_tools.yml")
    Workspace::Commands::SetupToolsCommand.any_instance.stubs(:preferences_path).returns(@prefs_path)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_returns_zero_when_tools_installed_and_doctor_passes
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Commands::DoctorCommand.any_instance.stubs(:call).returns(0)

    command = Workspace::Commands::SetupToolsCommand.new(stdin: StringIO.new(""), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_installs_missing_gh_when_user_confirms
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false, true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Commands::DoctorCommand.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with(
      "brew install gh",
      has_entry(allow_failure: true)
    ).returns(true)

    # Prompt: Install GitHub CLI now? -> yes
    stdin = StringIO.new("y\n")
    command = Workspace::Commands::SetupToolsCommand.new(stdin: stdin, stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_does_not_install_missing_gh_without_explicit_confirmation
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Commands::DoctorCommand.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).never

    command = Workspace::Commands::SetupToolsCommand.new(stdin: StringIO.new("\n"), stdout: StringIO.new)

    assert_equal 1, command.call
  end

  def test_does_not_start_docker_desktop_without_explicit_confirmation
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Commands::DoctorCommand.any_instance.stubs(:call).returns(0)

    Workspace.stubs(:capture).with("docker info").returns(["", false])
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])
    Workspace.stubs(:capture).with("doctl auth list").returns(["", true])

    Workspace.expects(:run).with("open -a Docker", has_entry(allow_failure: true)).never

    command = Workspace::Commands::SetupToolsCommand.new(stdin: StringIO.new("\n"), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_skips_homebrew_install_when_user_declines
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:command_exists?).with("brew").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Commands::DoctorCommand.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"", has_entry(allow_failure: true)).never
    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).never

    command = Workspace::Commands::SetupToolsCommand.new(stdin: StringIO.new("y\n"), stdout: StringIO.new)

    assert_equal 1, command.call
  end

  def test_installs_homebrew_then_requested_tool_when_confirmed
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false, true)
    Workspace.stubs(:command_exists?).with("brew").returns(false, true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Commands::DoctorCommand.any_instance.stubs(:call).returns(0)

    sequence = sequence("brew-install-flow")
    Workspace.expects(:run)
             .with("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"", has_entry(allow_failure: true))
             .in_sequence(sequence)
             .returns(true)
    Workspace.expects(:run)
             .with("brew install gh", has_entry(allow_failure: true))
             .in_sequence(sequence)
             .returns(true)

    # Prompts:
    # 1) Install GitHub CLI now? -> yes
    # 2) Homebrew is missing. Install Homebrew now? -> yes
    command = Workspace::Commands::SetupToolsCommand.new(stdin: StringIO.new("y\ny\n"), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  private

  def stub_tool_presence(all_installed:)
    %w[ruby docker doctl gh terraform brew].each do |tool|
      Workspace.stubs(:command_exists?).with(tool).returns(all_installed)
    end

    Workspace.stubs(:capture).returns(["", true])
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:section)
  end
end
