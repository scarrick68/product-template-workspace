# frozen_string_literal: true

require_relative "../../test_helper"

class WorkspaceRepositoriesTest < Minitest::Test
  REPOSITORIES = {
    "api" => { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
    "web" => { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
  }.freeze

  def test_context_manifest_repository_hash_is_normalized_to_repository_list
    Dir.mktmpdir("workspace-repositories") do |tmpdir|
      context = mock("context")
      context.stubs(:root).returns(tmpdir)
      context.stubs(:repositories).returns(REPOSITORIES)

      repositories = Workspace.repositories(context: context)

      assert_equal 2, repositories.length
      assert_equal %w[api-template web-template], repositories.map { |repo| repo["name"] }.sort
    end
  end

  def test_context_repositories_fail_fast_when_manifest_repositories_missing
    context = mock("context")
    context.stubs(:root).returns("/tmp/missing-manifest-repos")
    context.stubs(:repositories).returns({})

    Workspace.stubs(:fail_with_help)

    assert_raises(SystemExit) do
      Workspace.repositories(context: context)
    end
  end

  def test_repository_for_purpose_and_repo_root_for_purpose_helpers_cover_all_repo_types
    Dir.mktmpdir("workspace-repositories") do |tmpdir|
      context = mock("context")
      context.stubs(:root).returns(tmpdir)
      context.stubs(:repositories).returns(REPOSITORIES)

      backend_repo = Workspace.repository_for_purpose("backend-api", context: context)
      backend_root = Workspace.repo_root_for_purpose("backend-api", context: context)
      frontend_repo = Workspace.repository_for_purpose("frontend-web-client", context: context)
      frontend_root = Workspace.repo_root_for_purpose("frontend-web-client", context: context)

      assert_equal "api-template", backend_repo["name"]
      assert_equal File.join(tmpdir, "repos/api-template"), backend_root
      assert_equal "web-template", frontend_repo["name"]
      assert_equal File.join(tmpdir, "repos/web-template"), frontend_root
    end
  end

  def test_repo_root_for_purpose_returns_nil_for_missing_repository
    context = mock("context")
    context.stubs(:root).returns("/tmp/missing-purpose")
    context.stubs(:repositories).returns(REPOSITORIES)

    assert_nil Workspace.repo_root_for_purpose("unknown-purpose", context: context)
  end

  def test_repository_for_purpose_returns_nil_for_missing_repository
    context = mock("context")
    context.stubs(:root).returns("/tmp/missing-purpose")
    context.stubs(:repositories).returns(REPOSITORIES)

    assert_nil Workspace.repository_for_purpose("unknown-purpose", context: context)
  end

  def test_repo_root_for_purpose_bang_returns_roots_for_all_repo_types
    Dir.mktmpdir("workspace-repositories") do |tmpdir|
      context = mock("context")
      context.stubs(:root).returns(tmpdir)
      context.stubs(:repositories).returns(REPOSITORIES)

      assert_equal File.join(tmpdir, "repos/api-template"),
                   Workspace.repo_root_for_purpose!("backend-api", context: context)
      assert_equal File.join(tmpdir, "repos/web-template"),
                   Workspace.repo_root_for_purpose!("frontend-web-client", context: context)
    end
  end

  def test_repo_root_for_purpose_bang_raises_for_missing_repository
    context = mock("context")
    context.stubs(:root).returns("/tmp/missing-purpose")
    context.stubs(:repositories).returns(
      {
        "api" => { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" }
      }
    )

    error = assert_raises(ArgumentError) do
      Workspace.repo_root_for_purpose!("frontend-web-client", context: context)
    end

    assert_equal "Could not locate repository (purpose: frontend-web-client) in config/project.yml", error.message
  end
end
