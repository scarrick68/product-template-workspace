# frozen_string_literal: true

require_relative "../../test_helper"

class WorkspaceRepositoriesTest < Minitest::Test
  def test_context_manifest_repository_hash_is_normalized_to_repository_list
    Dir.mktmpdir("workspace-repositories") do |tmpdir|
      context = mock("context")
      context.stubs(:root).returns(tmpdir)
      context.stubs(:repositories).returns(
        {
          "api" => { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
          "web" => { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
        }
      )

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
end
