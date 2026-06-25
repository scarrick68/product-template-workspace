# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../lib/product_templates/project_paths"

class ProductTemplatesProjectPathsTest < Minitest::Test
  def test_derives_backend_and_frontend_paths_from_purpose_entries
    Dir.mktmpdir do |tmpdir|
      paths = ProductTemplates::ProjectPaths.new(
        "my-super-app",
        workspace_root: tmpdir,
        repositories: sample_repositories
      )

      assert_equal "my-super-app-api", paths.backend_app_name
      assert_equal "my-super-app-web", paths.frontend_app_name

      assert_equal "repos/api-template", paths.backend_current_relative_path
      assert_equal "repos/web-template", paths.frontend_current_relative_path

      assert_equal File.join(tmpdir, "repos", "api-template"), paths.backend_current_path
      assert_equal File.join(tmpdir, "repos", "web-template"), paths.frontend_current_path

      assert_equal "repos/my-super-app-api", paths.backend_app_relative_path
      assert_equal "repos/my-super-app-web", paths.frontend_app_relative_path

      assert_equal File.join(tmpdir, "repos", "my-super-app-api"), paths.backend_app_path
      assert_equal File.join(tmpdir, "repos", "my-super-app-web"), paths.frontend_app_path

      assert_equal "repos/api-template/bin/template_rename", paths.backend_rename_script_relative
      assert_equal "repos/web-template/bin/template_rename", paths.frontend_rename_script_relative

      assert_equal File.join(tmpdir, "repos", "api-template", "bin", "template_rename"), paths.backend_rename_script_path
      assert_equal File.join(tmpdir, "repos", "web-template", "bin", "template_rename"), paths.frontend_rename_script_path
    end
  end

  def test_update_repo_entry_rewrites_backend_and_frontend_entries
    paths = ProductTemplates::ProjectPaths.new(
      "my-super-app",
      workspace_root: "/tmp/workspace",
      repositories: sample_repositories
    )

    backend = {
      "purpose" => "backend-api",
      "name" => "api-template",
      "path" => "repos/api-template",
      "github" => "example-org/api-template"
    }

    frontend = {
      "purpose" => "frontend-web-client",
      "name" => "web-template",
      "path" => "repos/web-template",
      "github" => "example-org/web-template"
    }

    paths.update_repo_entry!(backend)
    paths.update_repo_entry!(frontend)

    assert_equal "my-super-app-api", backend["name"]
    assert_equal "repos/my-super-app-api", backend["path"]
    assert_equal "example-org/my-super-app-api", backend["github"]

    assert_equal "my-super-app-web", frontend["name"]
    assert_equal "repos/my-super-app-web", frontend["path"]
    assert_equal "example-org/my-super-app-web", frontend["github"]
  end

  def test_update_repo_entry_ignores_unknown_purpose
    paths = ProductTemplates::ProjectPaths.new(
      "my-super-app",
      workspace_root: "/tmp/workspace",
      repositories: sample_repositories
    )

    repo = {
      "purpose" => "analytics",
      "name" => "analytics-template",
      "path" => "repos/analytics-template",
      "github" => "example-org/analytics-template"
    }

    original = repo.dup
    paths.update_repo_entry!(repo)

    assert_equal original, repo
  end

  def test_missing_required_purpose_aborts_with_help
    repositories = [
      {
        "purpose" => "frontend-web-client",
        "name" => "web-template",
        "path" => "repos/web-template",
        "github" => "example-org/web-template"
      }
    ]

    paths = ProductTemplates::ProjectPaths.new(
      "my-super-app",
      workspace_root: "/tmp/workspace",
      repositories: repositories
    )

    Workspace.stubs(:abort_with_help).raises(RuntimeError, "missing-purpose")

    error = assert_raises(RuntimeError) do
      paths.backend_current_relative_path
    end

    assert_equal "missing-purpose", error.message
  end

  private

  def sample_repositories
    [
      {
        "purpose" => "backend-api",
        "name" => "api-template",
        "path" => "repos/api-template",
        "github" => "example-org/api-template"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "web-template",
        "path" => "repos/web-template",
        "github" => "example-org/web-template"
      }
    ]
  end
end
