# frozen_string_literal: true

require "stringio"
require "tmpdir"
require "yaml"

require_relative "../../../test_helper"

class InstallLocalDevToolsCommandTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("setup-tools-test")
    @prefs_path = File.join(@tmpdir, "install_local_dev_tools.yml")
    Workspace::Services::InstallLocalDevTools.any_instance.stubs(:preferences_path).returns(@prefs_path)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_returns_zero_when_tools_installed_and_doctor_passes
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new(""), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_does_not_prompt_to_reuse_preferences_when_saved_file_has_no_choices
    File.write(@prefs_path, { "install_missing" => {}, "configure" => {} }.to_yaml)
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new(""), stdout: StringIO.new)
    command.expects(:prompt_yes_no).never

    assert_equal 0, command.call
  end

  def test_installs_missing_gh_when_user_confirms
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false, true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with(
      "brew install gh",
      has_entry(allow_failure: true)
    ).returns(true)

    # Prompt: Install GitHub CLI now? -> yes
    stdin = StringIO.new("y\n")
    command = Workspace::Services::InstallLocalDevTools.new(stdin: stdin, stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_does_not_install_missing_gh_without_explicit_confirmation
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).never

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("n\n"), stdout: StringIO.new)

    assert_equal 1, command.call
  end

  def test_missing_tool_prompt_defaults_to_no_on_enter
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).never

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("\n"), stdout: StringIO.new)

    assert_equal 1, command.call
  end

  def test_missing_tool_prompt_reads_confirmation_before_install_decision
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false, true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).returns(true)

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("y\n"), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_installs_uv_with_pipx_without_homebrew
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("uv").returns(false, true)
    Workspace.stubs(:command_exists?).with("pipx").returns(true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("pipx install uv", has_entry(allow_failure: true)).returns(true)
    Workspace.expects(:run).with(
      "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"",
      has_entry(allow_failure: true)
    ).never

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("y\n"), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_does_not_require_uv_when_dsml_is_not_configured
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("uv").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    workspace_root = File.join(@tmpdir, "no-dsml-workspace")
    FileUtils.mkdir_p(File.join(workspace_root, "config"))
    File.write(File.join(workspace_root, "config", "project.yml"), YAML.dump({
      "project" => {
        "name" => "Product Template Workspace",
        "slug" => "product-template-workspace",
        "installation_id" => "a91d7c",
        "default_environment" => "production"
      },
      "repositories" => {
        "api" => {
          "purpose" => "backend-api",
          "name" => "api-template",
          "path" => "repos/api-template"
        },
        "web" => {
          "purpose" => "frontend-web-client",
          "name" => "web-template",
          "path" => "repos/web-template"
        }
      },
      "services" => {
        "api" => {
          "repository" => "api",
          "port" => 5001
        }
      },
      "environments" => {
        "production" => {
          "infrastructure" => {}
        }
      }
    }))

    context = Workspace::Context.new(root: workspace_root)
    command = Workspace::Services::InstallLocalDevTools.new(
      stdin: StringIO.new(""),
      stdout: StringIO.new,
      context: context
    )

    assert_equal 0, command.call
  end

  def test_starts_docker_desktop_when_prompt_uses_default_yes
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)
    Workspace.stubs(:docker_daemon_running?).returns(false)
    Workspace.expects(:ensure_docker_daemon_running).with(
      has_entries(wait_attempts: 30, wait_interval: 1)
    ).returns(true)

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("\n"), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  def test_skips_homebrew_install_when_user_declines
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:command_exists?).with("brew").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"", has_entry(allow_failure: true)).never
    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).never

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("y\nn\n"), stdout: StringIO.new)

    assert_equal 1, command.call
  end

  def test_fails_when_missing_tool_prompt_cannot_read_input
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

    Workspace.expects(:run).with("brew install gh", has_entry(allow_failure: true)).never
    Workspace.expects(:fail_with_help).with(
      "Interactive confirmation is required to install missing tools.",
      has_entry(details: "No input was available to answer install prompt for GitHub CLI.")
    ).once

    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new(""), stdout: StringIO.new)

    assert_equal 1, command.call
  end

  def test_installs_homebrew_then_requested_tool_when_confirmed
    stub_tool_presence(all_installed: true)
    Workspace.stubs(:command_exists?).with("gh").returns(false, true)
    Workspace.stubs(:command_exists?).with("brew").returns(false, true)
    Workspace.stubs(:ruby_compatible?).returns(true)
    Workspace::Services::Doctor.any_instance.stubs(:call).returns(0)

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
    command = Workspace::Services::InstallLocalDevTools.new(stdin: StringIO.new("y\ny\n"), stdout: StringIO.new)

    assert_equal 0, command.call
  end

  private

  def stub_tool_presence(all_installed:)
    %w[ruby docker doctl gh terraform uv brew].each do |tool|
      Workspace.stubs(:command_exists?).with(tool).returns(all_installed)
    end

    Workspace.stubs(:capture).returns(["", true])
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:section)
  end
end
