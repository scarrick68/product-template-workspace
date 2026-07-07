# frozen_string_literal: true

require_relative "../../../test_helper"

class InitNewProjectCommandTest < Minitest::Test
  def test_returns_usage_when_slug_missing
    Workspace.stubs(:fail_with_help)

    command = Workspace::Commands::InitNewProjectCommand.new([])

    assert_equal 1, command.call
  end

  def test_happy_path_without_dev_env_launch_returns_zero
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:capture).returns(["", false])
    Dir.stubs(:exist?).returns(true)

    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "my-super-app-api",
        "path" => "repos/my-super-app-api",
        "github" => "example-org/my-super-app-api"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "my-super-app-web",
        "path" => "repos/my-super-app-web",
        "github" => "example-org/my-super-app-web"
      }
    ])

    Workspace.stubs(:script_path).with("setup_tools").returns("bin/setup_tools")
    Workspace.stubs(:script_path).with("preinstall").returns("bin/preinstall")
    Workspace.stubs(:script_path).with("doctor").returns("bin/doctor")
    Workspace.stubs(:script_path).with("bootstrap").returns("bin/bootstrap")
    Workspace.stubs(:script_path).with("pull").returns("bin/pull")
    Workspace.stubs(:script_path).with("new_product").returns("bin/new_product")
    Workspace.stubs(:script_path).with("validate_product").returns("bin/validate_product")

    Workspace.stubs(:run).returns(true)

    command = Workspace::Commands::InitNewProjectCommand.new(
      ["my-super-app", "--no-dev", "--assume-repos-ready"],
      stdin: StringIO.new("n\n"),
      stdout: StringIO.new
    )

    assert_equal 0, command.call
  end

  def test_unsets_origin_remote_for_workspace_and_repositories_when_present
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)

    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "my-super-app-api",
        "path" => "repos/my-super-app-api",
        "github" => "example-org/my-super-app-api"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "my-super-app-web",
        "path" => "repos/my-super-app-web",
        "github" => "example-org/my-super-app-web"
      }
    ])

    Workspace.stubs(:script_path).with("setup_tools").returns("bin/setup_tools")
    Workspace.stubs(:script_path).with("preinstall").returns("bin/preinstall")
    Workspace.stubs(:script_path).with("doctor").returns("bin/doctor")
    Workspace.stubs(:script_path).with("bootstrap").returns("bin/bootstrap")
    Workspace.stubs(:script_path).with("pull").returns("bin/pull")
    Workspace.stubs(:script_path).with("new_product").returns("bin/new_product")
    Workspace.stubs(:script_path).with("validate_product").returns("bin/validate_product")

    Dir.stubs(:exist?).returns(true)

    Workspace.expects(:capture).with("git remote get-url origin", chdir: Workspace::ROOT).returns(["", true])
    Workspace.expects(:capture).with("git remote get-url origin", chdir: File.join(Workspace::ROOT, "repos/my-super-app-api")).returns(["", true])
    Workspace.expects(:capture).with("git remote get-url origin", chdir: File.join(Workspace::ROOT, "repos/my-super-app-web")).returns(["", true])

    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/setup_tools") && kwargs[:allow_failure] == true
    }.returns(true)
    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/preinstall") && kwargs[:allow_failure] == true
    }.returns(true)
    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/doctor") && kwargs[:allow_failure] == true
    }.returns(true)
    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/bootstrap") && kwargs[:allow_failure] == true
    }.returns(true)
    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/pull") && kwargs[:allow_failure] == true
    }.returns(true)
    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/new_product") && kwargs[:allow_failure] == true
    }.returns(true)
    Workspace.expects(:run).with { |command, kwargs|
      command.include?("bin/validate_product") && kwargs[:allow_failure] == true
    }.returns(true)

    Workspace.expects(:run).with("git remote remove origin", chdir: Workspace::ROOT, allow_failure: true).returns(true)
    Workspace.expects(:run).with(
      "git remote remove origin",
      chdir: File.join(Workspace::ROOT, "repos/my-super-app-api"),
      allow_failure: true
    ).returns(true)
    Workspace.expects(:run).with(
      "git remote remove origin",
      chdir: File.join(Workspace::ROOT, "repos/my-super-app-web"),
      allow_failure: true
    ).returns(true)

    command = Workspace::Commands::InitNewProjectCommand.new(
      ["my-super-app", "--no-dev", "--assume-repos-ready"],
      stdin: StringIO.new("n\n"),
      stdout: StringIO.new
    )

    assert_equal 0, command.call
  end

  def test_explicit_remote_args_do_not_prompt_and_use_automation
    stdin = mock("stdin")
    stdin.expects(:gets).never

    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)

    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "my-super-app-api",
        "path" => "repos/my-super-app-api",
        "github" => "example-org/my-super-app-api"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "my-super-app-web",
        "path" => "repos/my-super-app-web",
        "github" => "example-org/my-super-app-web"
      }
    ])

    Workspace::Commands::Auth::GithubAuthCommand.any_instance.stubs(:call).returns(0)

    Workspace.stubs(:script_path).with("setup_tools").returns("bin/setup_tools")
    Workspace.stubs(:script_path).with("preinstall").returns("bin/preinstall")
    Workspace.stubs(:script_path).with("doctor").returns("bin/doctor")
    Workspace.stubs(:script_path).with("bootstrap").returns("bin/bootstrap")
    Workspace.stubs(:script_path).with("pull").returns("bin/pull")
    Workspace.stubs(:script_path).with("new_product").returns("bin/new_product")
    Workspace.stubs(:script_path).with("validate_product").returns("bin/validate_product")

    Dir.stubs(:exist?).returns(true)
    Workspace.stubs(:capture).returns(["", false])
    Workspace.stubs(:run).returns(true)

    command = Workspace::Commands::InitNewProjectCommand.new(
      ["my-super-app", "--no-dev", "--assume-repos-ready", "--create-remotes", "--private", "--no-push"],
      stdin: stdin,
      stdout: StringIO.new
    )

    assert_equal 0, command.call
  end

  def test_prompted_auto_remote_falls_back_to_manual_when_auth_check_fails
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:capture).returns(["", false])
    Dir.stubs(:exist?).returns(true)

    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "my-super-app-api",
        "path" => "repos/my-super-app-api",
        "github" => "example-org/my-super-app-api"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "my-super-app-web",
        "path" => "repos/my-super-app-web",
        "github" => "example-org/my-super-app-web"
      }
    ])

    Workspace.stubs(:script_path).with("setup_tools").returns("bin/setup_tools")
    Workspace.stubs(:script_path).with("preinstall").returns("bin/preinstall")
    Workspace.stubs(:script_path).with("doctor").returns("bin/doctor")
    Workspace.stubs(:script_path).with("bootstrap").returns("bin/bootstrap")
    Workspace.stubs(:script_path).with("pull").returns("bin/pull")
    Workspace.stubs(:script_path).with("new_product").returns("bin/new_product")
    Workspace.stubs(:script_path).with("validate_product").returns("bin/validate_product")

    Workspace::Commands::Auth::GithubAuthCommand.any_instance.stubs(:call).returns(1)
    Workspace.stubs(:run).returns(true)

    # Prompts: auto-create=yes, public=no(private), push=yes(default/explicit yes)
    stdin = StringIO.new("y\nn\ny\n")
    command = Workspace::Commands::InitNewProjectCommand.new(
      ["my-super-app", "--no-dev", "--assume-repos-ready"],
      stdin: stdin,
      stdout: StringIO.new
    )

    assert_equal 0, command.call
  end
end
