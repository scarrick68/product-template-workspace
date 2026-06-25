# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../lib/product_templates/renamer"

class ProductTemplatesRenamerTest < Minitest::Test
  def test_happy_path_uses_purpose_paths_and_updates_config
    # This is a lightweight integration test: it validates repo moves + repos.yml updates,
    # while stubbing script executability so we do not need real template_rename files.
    Dir.mktmpdir do |tmpdir|
      FileUtils.mkdir_p(File.join(tmpdir, "repos", "api-template", "bin"))
      FileUtils.mkdir_p(File.join(tmpdir, "repos", "web-template", "bin"))
      FileUtils.mkdir_p(File.join(tmpdir, "config"))

      repos_config_path = File.join(tmpdir, "config", "repos.yml")
      File.write(
        repos_config_path,
        <<~YAML
          repositories:
            - purpose: backend-api
              name: api-template
              path: repos/api-template
              github: example-org/api-template
            - purpose: frontend-web-client
              name: web-template
              path: repos/web-template
              github: example-org/web-template
        YAML
      )

      fake_repos = [
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

      Workspace.stubs(:repositories).returns(fake_repos)
      Workspace.stubs(:run).returns(true)
      Workspace.stubs(:ok)
      Workspace.stubs(:info)
      Workspace.stubs(:warn)
      File.stubs(:executable?).returns(true)

      renamer = ProductTemplates::Renamer.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, renamer.call

      assert Dir.exist?(File.join(tmpdir, "repos", "my-super-app-api"))
      assert Dir.exist?(File.join(tmpdir, "repos", "my-super-app-web"))

      updated = YAML.safe_load(File.read(repos_config_path), permitted_classes: [], aliases: false)
      backend = updated.fetch("repositories").find { |r| r["purpose"] == "backend-api" }
      frontend = updated.fetch("repositories").find { |r| r["purpose"] == "frontend-web-client" }

      assert_equal "my-super-app-api", backend["name"]
      assert_equal "repos/my-super-app-api", backend["path"]
      assert_equal "example-org/my-super-app-api", backend["github"]

      assert_equal "my-super-app-web", frontend["name"]
      assert_equal "repos/my-super-app-web", frontend["path"]
      assert_equal "example-org/my-super-app-web", frontend["github"]
    end
  end
end
