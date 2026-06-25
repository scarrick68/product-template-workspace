# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../lib/product_templates/validator"

class ProductTemplatesValidatorTest < Minitest::Test
  def test_happy_path_uses_purpose_paths_for_validation
    Dir.mktmpdir do |tmpdir|
      api_dir = File.join(tmpdir, "repos", "my-super-app-api")
      web_dir = File.join(tmpdir, "repos", "my-super-app-web")
      FileUtils.mkdir_p(api_dir)
      FileUtils.mkdir_p(web_dir)

      fake_repos = [
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
      ]

      Workspace.stubs(:repositories).returns(fake_repos)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)

      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with(
        "bin/status",
        chdir: tmpdir,
        allow_failure: true
      ).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end
end
