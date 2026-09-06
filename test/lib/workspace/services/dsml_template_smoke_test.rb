# frozen_string_literal: true

require "tmpdir"
require "fileutils"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/template_workspace_generator"

# Lightweight integration coverage for DSML template generation plus bootstrap/validation orchestration.
class DsmlTemplateSmokeTest < Minitest::Test
  # Exercises DSML template generation and the workspace bootstrap/validation commands that consume it.
  def test_generated_workspace_provisions_and_validates_dsml_repository
    Dir.mktmpdir("template-source-") do |source_root|
      Dir.mktmpdir("template-parent-") do |parent_dir|
        write_source_workspace(source_root)

        destination_root = File.join(parent_dir, "my-super-app")
        Workspace::Services::TemplateWorkspaceGenerator.new(
          source_root: source_root,
          destination_root: destination_root
        ).call

        dsml_dir = File.join(destination_root, "repos", "dsml-template")
        api_dir = File.join(destination_root, "repos", "api-template")
        web_dir = File.join(destination_root, "repos", "web-template")

        assert File.executable?(File.join(dsml_dir, "bin", "bootstrap"))
        assert File.executable?(File.join(dsml_dir, "bin", "check"))

        bootstrap_repos = [
          { "name" => "dsml-template", "path" => "repos/dsml-template" }
        ]

        Workspace.stubs(:repositories).returns(bootstrap_repos)
        Workspace.stubs(:existing_repositories).returns(bootstrap_repos)
        Workspace.stubs(:script_path).returns("bin/preinstall_checks")
        Workspace.stubs(:ok)
        Workspace.stubs(:warn)
        Workspace.stubs(:fail_with_help)
        Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")

        Workspace.expects(:run).with(
          "bin/bootstrap",
          has_entries(
            chdir: dsml_dir,
            allow_failure: true,
            summary: "Repository bootstrap failed for dsml-template."
          )
        ).returns(true)

        bootstrap = Workspace::Services::Bootstrap.new(context: Workspace::Context.new(root: destination_root))
        bootstrap.stubs(:system).returns(true)

        assert_equal 0, bootstrap.call

        validation_repos = [
          {
            "purpose" => "backend-api",
            "name" => "api-template",
            "path" => "repos/api-template"
          },
          {
            "purpose" => "frontend-web-client",
            "name" => "web-template",
            "path" => "repos/web-template"
          },
          {
            "purpose" => "data-science-ml",
            "name" => "dsml-template",
            "path" => "repos/dsml-template"
          }
        ]

        Workspace.stubs(:repositories).returns(validation_repos)

        Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).returns(true)
        Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).returns(true)
        Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).returns(true)
        Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).returns(true)
        Workspace.expects(:run).with("bin/check", chdir: dsml_dir, allow_failure: true).returns(true)
        Workspace.expects(:run).with("bin/status", chdir: destination_root, allow_failure: true).returns(true)

        validator = ProductTemplates::Validator.new("my-super-app", workspace_root: destination_root)
        assert_equal 0, validator.call
      end
    end
  end

  private

  def write_source_workspace(root)
    FileUtils.mkdir_p(File.join(root, "repos", "dsml-template", "bin"))
    FileUtils.mkdir_p(File.join(root, "repos", "api-template"))
    FileUtils.mkdir_p(File.join(root, "repos", "web-template"))

    File.write(File.join(root, "repos", "dsml-template", "bin", "bootstrap"), "#!/usr/bin/env bash\n")
    File.write(File.join(root, "repos", "dsml-template", "bin", "check"), "#!/usr/bin/env bash\n")
    FileUtils.chmod("u+x", File.join(root, "repos", "dsml-template", "bin", "bootstrap"))
    FileUtils.chmod("u+x", File.join(root, "repos", "dsml-template", "bin", "check"))
  end
end
