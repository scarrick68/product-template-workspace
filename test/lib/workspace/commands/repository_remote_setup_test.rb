# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/repository_remote_setup"

class RepositoryRemoteSetupTest < Minitest::Test
  SetupResult = Data.define(
    :create_remotes,
    :push_after_setup,
    :targets
  ) do
    def create_remotes?
      create_remotes
    end

    def push_after_setup?
      push_after_setup
    end
  end

  def setup
    @root = Dir.mktmpdir("repository-remote-setup-")
    @context = Workspace::Context.new(root: @root)
    @service = Workspace::Services::RepositoryRemoteSetup.new(context: @context)

    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:ok)
  end

  def teardown
    FileUtils.remove_entry(@root) if @root && Dir.exist?(@root)
  end

  def test_configures_github_origins_without_pushing_when_push_is_disabled
    backend = create_git_repository("repos/my-super-app-api")
    frontend = create_git_repository("repos/my-super-app-web")

    expect_origin_not_configured(backend)
    expect_origin_not_configured(frontend)

    expect_github_origin_added(
      backend,
      "example-org/my-super-app-api"
    )
    expect_github_origin_added(
      frontend,
      "example-org/my-super-app-web"
    )

    Workspace.expects(:warn).with(
      "Push step skipped (--no-push). Repositories are ready for manual push."
    )

    Workspace.expects(:run)
      .with("git push -u origin HEAD", anything)
      .never

    result = setup_result(
      push_after_setup: false,
      targets: [
        repository_target(
          label: "backend",
          local_path: "repos/my-super-app-api",
          github_ref: "example-org/my-super-app-api"
        ),
        repository_target(
          label: "frontend",
          local_path: "repos/my-super-app-web",
          github_ref: "example-org/my-super-app-web"
        )
      ]
    )

    assert @service.call(result)
  end

  def test_pushes_current_branch_after_configuring_github_origin
    repository = create_git_repository("repos/my-super-app-api")

    expect_origin_not_configured(repository)
    expect_github_origin_added(
      repository,
      "example-org/my-super-app-api"
    )
    expect_active_branch(repository, "main")

    Workspace.expects(:run).with(
      "git push -u origin HEAD",
      has_entries(
        chdir: repository,
        allow_failure: true
      )
    ).returns(true)

    result = setup_result(
      targets: [
        repository_target(
          label: "backend",
          local_path: "repos/my-super-app-api",
          github_ref: "example-org/my-super-app-api"
        )
      ]
    )

    assert @service.call(result)
  end

  def test_skips_push_when_repository_has_no_active_branch
    repository = create_git_repository("repos/my-super-app-api")

    expect_origin_not_configured(repository)
    expect_github_origin_added(
      repository,
      "example-org/my-super-app-api"
    )
    expect_no_active_branch(repository)

    Workspace.expects(:warn).with(
      "Skipping push for backend: repository has no active branch yet."
    )

    Workspace.expects(:run)
      .with("git push -u origin HEAD", anything)
      .never

    result = setup_result(
      targets: [
        repository_target(
          label: "backend",
          local_path: "repos/my-super-app-api",
          github_ref: "example-org/my-super-app-api"
        )
      ]
    )

    assert @service.call(result)
  end

  def test_removes_inherited_origins_when_github_repository_creation_is_skipped
    workspace_repository = create_git_repository(".")
    backend_repository = create_git_repository("repos/my-super-app-api")

    Workspace.stubs(:repositories)
      .with(context: @context)
      .returns(
        [
          {
            "name" => "my-super-app-api",
            "path" => "repos/my-super-app-api",
            "github" => "example-org/my-super-app-api"
          }
        ]
      )

    expect_origin_configured(workspace_repository)
    expect_origin_configured(backend_repository)

    expect_origin_removed(workspace_repository)
    expect_origin_removed(backend_repository)

    result = setup_result(
      create_remotes: false,
      push_after_setup: false,
      targets: []
    )

    assert @service.call(result)
  end

  private

  def setup_result(
    create_remotes: true,
    push_after_setup: true,
    targets: []
  )
    SetupResult.new(
      create_remotes: create_remotes,
      push_after_setup: push_after_setup,
      targets: targets
    )
  end

  def repository_target(label:, local_path:, github_ref:)
    {
      label: label,
      local_path: local_path,
      github_ref: github_ref
    }
  end

  def create_git_repository(relative_path)
    repository_path = File.expand_path(relative_path, @root)

    FileUtils.mkdir_p(File.join(repository_path, ".git"))

    repository_path
  end

  def expect_origin_not_configured(repository_path)
    Workspace.expects(:capture).with(
      "git remote get-url origin",
      chdir: repository_path
    ).returns(["", false])
  end

  def expect_origin_configured(repository_path)
    Workspace.expects(:capture).with(
      "git remote get-url origin",
      chdir: repository_path
    ).returns(["git@github.com:template/repository.git", true])
  end

  def expect_github_origin_added(repository_path, github_ref)
    Workspace.expects(:run).with(
      "git remote add origin git@github.com:#{github_ref}.git",
      chdir: repository_path
    ).returns(true)
  end

  def expect_origin_removed(repository_path)
    Workspace.expects(:run).with(
      "git remote remove origin",
      chdir: repository_path,
      allow_failure: true
    ).returns(true)
  end

  def expect_active_branch(repository_path, branch)
    Workspace.expects(:capture).with(
      "git symbolic-ref --quiet --short HEAD",
      chdir: repository_path
    ).returns([branch, true])
  end

  def expect_no_active_branch(repository_path)
    Workspace.expects(:capture).with(
      "git symbolic-ref --quiet --short HEAD",
      chdir: repository_path
    ).returns(["", false])
  end
end
