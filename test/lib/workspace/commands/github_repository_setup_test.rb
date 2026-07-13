# frozen_string_literal: true

require_relative "../../../test_helper"

class GithubRepositorySetupTest < Minitest::Test
  TestOptions = Struct.new(
    :create_remotes_explicit,
    :create_remotes,
    :visibility,
    :push_explicit,
    :push_after_setup,
    :assume_repos_ready,
    keyword_init: true
  ) do
    def create_remotes_explicit?
      create_remotes_explicit
    end

    def create_remotes?
      create_remotes
    end

    def push_explicit?
      push_explicit
    end

    def push_after_setup?
      push_after_setup
    end

    def assume_repos_ready?
      assume_repos_ready
    end
  end

  def setup
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:ok)
    Workspace.stubs(:fail_with_help)
    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "my-super-app-api",
        "path" => "repos/my-super-app-api",
        "github" => "example-org/template-api"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "my-super-app-web",
        "path" => "repos/my-super-app-web",
        "github" => "example-org/template-web"
      }
    ])
  end

  def test_explicit_remote_creation_creates_only_missing_repositories
    options = TestOptions.new(
      create_remotes_explicit: true,
      create_remotes: true,
      visibility: "private",
      push_explicit: true,
      push_after_setup: false,
      assume_repos_ready: false
    )

    Workspace::Services::Auth::GithubAuth.any_instance.stubs(:call).returns(0)
    Workspace.expects(:capture).with("gh repo view example-org/my-super-app-api").returns(["", false])
    Workspace.expects(:capture).with("gh repo view example-org/my-super-app-web").returns(["", true])
    Workspace.expects(:run).with(
      "gh repo create example-org/my-super-app-api --private --confirm",
      chdir: Workspace::ROOT,
      allow_failure: true,
      summary: "Failed to create backend repository example-org/my-super-app-api.",
      details: "Your account may not have permission to create repositories for this owner.",
      fixes: includes("Verify owner access in GitHub for example-org.")
    ).returns(true)

    result = Workspace::Services::GithubRepositorySetup.new.call(options: options, product_slug: "my-super-app")

    assert result.success?
    assert result.create_remotes?
    refute result.push_after_setup?
    assert_equal "private", result.visibility
    assert_equal ["example-org/my-super-app-api", "example-org/my-super-app-web"], result.targets.map { |target| target[:github_ref] }
  end

  def test_manual_mode_requires_confirmation_when_not_assumed_ready
    options = TestOptions.new(
      create_remotes_explicit: true,
      create_remotes: false,
      visibility: nil,
      push_explicit: false,
      push_after_setup: true,
      assume_repos_ready: false
    )

    TTY::Prompt.any_instance.expects(:yes?)
      .with("Have you created this repo or confirmed it already exists?", default: false)
      .twice
      .returns(true)

    result = Workspace::Services::GithubRepositorySetup.new.call(options: options, product_slug: "my-super-app")

    assert result.success?
    refute result.create_remotes?
    assert result.push_after_setup?
  end

  def test_failed_auth_falls_back_to_manual_when_assume_repos_ready
    options = TestOptions.new(
      create_remotes_explicit: true,
      create_remotes: true,
      visibility: "private",
      push_explicit: true,
      push_after_setup: true,
      assume_repos_ready: true
    )

    Workspace::Services::Auth::GithubAuth.any_instance.stubs(:call).returns(1)
    TTY::Prompt.any_instance.expects(:yes?).never

    result = Workspace::Services::GithubRepositorySetup.new.call(options: options, product_slug: "my-super-app")

    assert result.success?
    refute result.create_remotes?
    assert result.push_after_setup?
    assert_nil result.visibility
  end
end
