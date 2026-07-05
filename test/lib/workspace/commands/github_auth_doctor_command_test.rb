# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/auth/github_auth_command"

class GithubAuthDoctorCommandTest < Minitest::Test
  def test_returns_zero_when_all_checks_pass
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail)
    Workspace.stubs(:repositories).returns([
      { "github" => "example-org/api-template" }
    ])

    Workspace.stubs(:command_exists?).with("git").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)

    Workspace.stubs(:capture).with("gh auth status").returns(["ok", true])
    Workspace.stubs(:capture).with("gh auth status -t").returns(["repo", true])
    Workspace.stubs(:capture).with("gh api user").returns(["{\"login\":\"example-user\"}", true])
    Workspace.stubs(:capture).with("gh api orgs/example-org").returns(["{}", true])
    Workspace.stubs(:capture).with("gh api orgs/example-org/memberships/example-user").returns(["{\"state\":\"active\",\"role\":\"member\"}", true])

    result = Workspace::Commands::Auth::GithubAuthCommand.new.call

    assert_equal 0, result
  end

  def test_returns_one_when_gh_missing
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("git").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(false)

    result = Workspace::Commands::Auth::GithubAuthCommand.new.call

    assert_equal 1, result
  end

  def test_returns_one_when_gh_auth_invalid
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("git").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)

    Workspace.stubs(:capture).with("gh auth status").returns(["", false])

    result = Workspace::Commands::Auth::GithubAuthCommand.new.call

    assert_equal 1, result
  end
end
