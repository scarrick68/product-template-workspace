# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "open3"

require_relative "../test_helper"

# End-to-end workspace provisioning checks through the CLI command surface.
class ProjectProvisioningTest < Minitest::Test
  RUN_FLAG = "RUN_PROJECT_PROVISIONING_INTEGRATION"
  KEEP_ARTIFACTS_FLAG = "KEEP_INTEGRATION_ARTIFACTS"
  WORKSPACE_ROOT = File.expand_path("../..", __dir__)

  def setup
    skip_unless_enabled

    @tmp_root = Dir.mktmpdir("workspace-provisioning")
  end

  def teardown
    return if ENV[KEEP_ARTIFACTS_FLAG] == "1"

    FileUtils.rm_rf(@tmp_root) if @tmp_root && Dir.exist?(@tmp_root)
  end

  def test_full_stack_with_dsml
    provision_and_assert(slug: "acme", with_dsml: true)
  end

  def test_backend_frontend_without_dsml
    provision_and_assert(slug: "acme", with_dsml: false)
  end

  private

  attr_reader :tmp_root

  def provision_and_assert(slug:, with_dsml:)
    destination_root = File.join(tmp_root, with_dsml ? "full-stack" : "backend-frontend")
    exit_code, stdout, stderr = run_new_project_cli(
      destination_root: destination_root,
      slug: slug,
      with_dsml: with_dsml
    )

    assert_equal 0, exit_code, <<~MSG
      workspace new-project failed

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MSG

    assert_generated_structure(destination_root, slug: slug, include_dsml: with_dsml)
    assert_generated_projects_operational(
      destination_root,
      slug: slug,
      include_dsml: with_dsml
    )
  ensure
    cleanup_project_artifacts(destination_root)
  end

  def skip_unless_enabled
    return if ENV[RUN_FLAG] == "1"

    skip "Set #{RUN_FLAG}=1 to run provisioning integration tests"
  end

  def cleanup_project_artifacts(destination_root)
    return unless destination_root

    expanded_tmp_root = File.expand_path(tmp_root)
    expanded_destination_root = File.expand_path(destination_root)
    return unless expanded_destination_root.start_with?("#{expanded_tmp_root}/")

    FileUtils.rm_rf(expanded_destination_root)
  end

  def run_new_project_cli(destination_root:, slug:, with_dsml:)
    args = [
      File.join(WORKSPACE_ROOT, "bin", "workspace"),
      "new-project",
      "--destination", destination_root,
      slug
    ]
    args << "--with-dsml" if with_dsml
    args += [
      "--",
      "--no-dev"
    ]

    stdout, stderr, status = Open3.capture3(*args, chdir: WORKSPACE_ROOT)
    [status.exitstatus, stdout, stderr]
  end

  def assert_generated_structure(destination_root, slug:, include_dsml:)
    assert_file(File.join(destination_root, ".generated-project-workspace"))

    backend_root = File.join(destination_root, "repos", "#{slug}-api")
    frontend_root = File.join(destination_root, "repos", "#{slug}-web")
    dsml_root = File.join(destination_root, "repos", "#{slug}-dsml")

    assert_directory(backend_root)
    assert_directory(frontend_root)
    assert_file(File.join(backend_root, "Gemfile"))
    assert_file(File.join(frontend_root, "package.json"))

    if include_dsml
      assert_directory(dsml_root)
      assert_file(File.join(dsml_root, "pyproject.toml"))
    else
      assert_equal false, Dir.exist?(dsml_root), "Did not expect DSML directory: #{dsml_root}"
    end
  end

  def assert_generated_projects_operational(destination_root, slug:, include_dsml:)
    backend_root = File.join(destination_root, "repos", "#{slug}-api")
    frontend_root = File.join(destination_root, "repos", "#{slug}-web")
    dsml_root = File.join(destination_root, "repos", "#{slug}-dsml")

    assert_command("bin/ci", chdir: backend_root)
    assert_command("npm run test", chdir: frontend_root)
    assert_command("bin/check", chdir: dsml_root) if include_dsml
    assert_command("bin/status", chdir: destination_root)
    assert_command("bin/doctor", chdir: destination_root)
  end

  def assert_directory(path)
    assert Dir.exist?(path), "Expected directory to exist: #{path}"
  end

  def assert_file(path)
    assert File.exist?(path), "Expected file to exist: #{path}"
  end

  def assert_command(command, chdir:)
    stdout, stderr, status = Open3.capture3(command, chdir: chdir)

    assert status.success?, <<~MSG
      Command failed: #{command}
      Directory: #{chdir}

      stdout:
      #{stdout}

      stderr:
      #{stderr}
    MSG
  end
end