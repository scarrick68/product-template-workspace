# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/init_new_project"

class InitNewProjectTest < Minitest::Test
  # Verifies mobile and DSML repositories participate in the init summary and orchestration.
  def test_call_runs_full_init_flow_and_includes_mobile_and_dsml_repo_in_summary
    Dir.mktmpdir("init-new-project") do |root|
      write_manifest(root, installation_id: "a91d7c", include_dsml: true)
      context = Workspace::Context.new(root: root)

      service = Workspace::Services::InitNewProject.new(["my-super-app"], context: context)

      options = mock("options")
      options.stubs(:help_requested?).returns(false)
      options.stubs(:valid?).returns(true)
      options.stubs(:product_slug).returns("my-super-app")
      options.stubs(:skip_setup_tools?).returns(false)
      options.stubs(:cms_enabled?).returns(false)
      options.stubs(:cms_provider).returns("none")
      options.stubs(:with_dsml?).returns(true)
      options.stubs(:no_dev?).returns(true)
      Workspace::Services::InitNewProjectOptions.stubs(:parse).returns(options)

      step_runner = mock("step_runner")
      step_runner.expects(:shell).with("Guided tool installation and auth setup", "install_local_dev_tools").returns(true)
      step_runner.expects(:shell).with("Environment prechecks", "preinstall_checks").returns(true)
      step_runner.expects(:ruby).with("Environment diagnostics").yields.returns(true)
      step_runner.expects(:ruby).with("Repository bootstrap and dependency install").yields.returns(true)
      step_runner.expects(:ruby).with("Sync latest template changes").yields.returns(true)
      step_runner.expects(:ruby).with("Rename templates for new project").yields.returns(true)
      step_runner.expects(:ruby).with("Post-rename validation (tests/build checks)").yields.returns(true)
      service.stubs(:step_runner).returns(step_runner)

      Workspace::Services::Doctor.stubs(:new).returns(stub(call: 0))
      Workspace::Services::Bootstrap.stubs(:new).returns(stub(call: 0))
      Workspace::Services::Pull.stubs(:new).returns(stub(call: 0))
      Workspace::Services::RenameProductCommand.stubs(:new).returns(stub(call: 0))
      Workspace::Services::ValidateProduct.stubs(:new).returns(stub(call: 0))

      remote_setup = Workspace::Services::GithubRepositorySetup::Result.new(
        success: true,
        create_remotes: false,
        push_after_setup: false,
        visibility: nil,
        targets: []
      )
      github_setup = mock("github_setup")
      github_setup.expects(:call).with(options: options, product_slug: "my-super-app").returns(remote_setup)
      service.stubs(:github_repository_setup).returns(github_setup)

      remote_setup_service = mock("remote_setup_service")
      remote_setup_service.expects(:call).with(remote_setup).returns(true)
      service.stubs(:repository_remote_setup).returns(remote_setup_service)

      Workspace.stubs(:ok)
      Workspace.stubs(:info)
      Workspace.expects(:info).with("- repos/mobile-app-template").once
      Workspace.expects(:info).with("- repos/dsml-template").once

      assert_equal 0, service.call
    end
  end

  def test_call_omits_dsml_when_with_dsml_is_not_enabled
    Dir.mktmpdir("init-new-project") do |root|
      write_manifest(root, installation_id: "a91d7c", include_dsml: true)
      FileUtils.mkdir_p(File.join(root, "repos", "dsml-template"))
      context = Workspace::Context.new(root: root)

      service = Workspace::Services::InitNewProject.new(["my-super-app"], context: context)

      options = mock("options")
      options.stubs(:help_requested?).returns(false)
      options.stubs(:valid?).returns(true)
      options.stubs(:product_slug).returns("my-super-app")
      options.stubs(:skip_setup_tools?).returns(false)
      options.stubs(:cms_enabled?).returns(false)
      options.stubs(:cms_provider).returns("none")
      options.stubs(:with_dsml?).returns(false)
      options.stubs(:no_dev?).returns(true)
      Workspace::Services::InitNewProjectOptions.stubs(:parse).returns(options)

      step_runner = mock("step_runner")
      step_runner.expects(:shell).with("Guided tool installation and auth setup", "install_local_dev_tools").returns(true)
      step_runner.expects(:shell).with("Environment prechecks", "preinstall_checks").returns(true)
      step_runner.expects(:ruby).with("Environment diagnostics").yields.returns(true)
      step_runner.expects(:ruby).with("Repository bootstrap and dependency install").yields.returns(true)
      step_runner.expects(:ruby).with("Sync latest template changes").yields.returns(true)
      step_runner.expects(:ruby).with("Rename templates for new project").yields.returns(true)
      step_runner.expects(:ruby).with("Post-rename validation (tests/build checks)").yields.returns(true)
      service.stubs(:step_runner).returns(step_runner)

      Workspace::Services::Doctor.stubs(:new).returns(stub(call: 0))
      Workspace::Services::Bootstrap.stubs(:new).returns(stub(call: 0))
      Workspace::Services::Pull.stubs(:new).returns(stub(call: 0))
      Workspace::Services::RenameProductCommand.stubs(:new).returns(stub(call: 0))
      Workspace::Services::ValidateProduct.stubs(:new).returns(stub(call: 0))

      remote_setup = Workspace::Services::GithubRepositorySetup::Result.new(
        success: true,
        create_remotes: false,
        push_after_setup: false,
        visibility: nil,
        targets: []
      )
      github_setup = mock("github_setup")
      github_setup.expects(:call).with(options: options, product_slug: "my-super-app").returns(remote_setup)
      service.stubs(:github_repository_setup).returns(github_setup)

      remote_setup_service = mock("remote_setup_service")
      remote_setup_service.expects(:call).with(remote_setup).returns(true)
      service.stubs(:repository_remote_setup).returns(remote_setup_service)

      Workspace.stubs(:ok)
      Workspace.stubs(:info)
      Workspace.expects(:info).with("- repos/dsml-template").never

      assert_equal 0, service.call

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      dsml_present = manifest.fetch("repositories").values.any? { |repo| repo["purpose"] == "data-science-ml" }
      assert_equal false, dsml_present
      assert_equal false, Dir.exist?(File.join(root, "repos", "dsml-template"))
    end
  end

  def test_assigns_installation_id_when_template_sentinel_is_present
    Dir.mktmpdir("init-new-project") do |root|
      write_manifest(root, installation_id: "000000")
      context = Workspace::Context.new(root: root)

      service = Workspace::Services::InitNewProject.new(["my-super-app"], context: context)
      Workspace.stubs(:info)

      service.send(:assign_installation_id_if_needed)

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      installation_id = manifest.fetch("project").fetch("installation_id")

      assert_match(/\A[a-f0-9]{6}\z/, installation_id)
      refute_equal "000000", installation_id
    end
  end

  def test_keeps_existing_installation_id
    Dir.mktmpdir("init-new-project") do |root|
      write_manifest(root, installation_id: "a91d7c")
      context = Workspace::Context.new(root: root)

      service = Workspace::Services::InitNewProject.new(["my-super-app"], context: context)
      Workspace.stubs(:info)

      service.send(:assign_installation_id_if_needed)

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      assert_equal "a91d7c", manifest.fetch("project").fetch("installation_id")
    end
  end

  def test_skips_optional_cms_install_when_disabled
    options = Struct.new(:cms_enabled?, :cms_provider).new(false, "none")
    service = Workspace::Services::InitNewProject.new(["my-super-app"])

    step_runner = mock("step_runner")
    step_runner.expects(:ruby).never
    service.stubs(:step_runner).returns(step_runner)

    assert_equal true, service.send(:install_optional_cms_if_enabled, options)
  end

  def test_runs_optional_cms_install_step_when_enabled
    options = Struct.new(:cms_enabled?, :cms_provider).new(true, "keystatic")
    service = Workspace::Services::InitNewProject.new(["my-super-app"])

    installer = mock("cms_installer")
    installer.expects(:call).with(provider: "keystatic").returns(0)

    step_runner = mock("step_runner")
    step_runner.expects(:ruby).with("Install optional CMS feature (keystatic)").yields.returns(true)

    service.stubs(:cms_installer).returns(installer)
    service.stubs(:step_runner).returns(step_runner)

    assert_equal true, service.send(:install_optional_cms_if_enabled, options)
  end

  def test_skips_cms_frontend_dependency_install_when_disabled
    options = Struct.new(:cms_enabled?, :cms_provider, :product_slug).new(false, "none", "my-super-app")
    service = Workspace::Services::InitNewProject.new(["my-super-app"])

    step_runner = mock("step_runner")
    step_runner.expects(:ruby).never
    service.stubs(:step_runner).returns(step_runner)

    Workspace.expects(:run).never

    assert_equal true, service.send(:install_cms_frontend_dependencies_if_enabled, options)
  end

  def test_installs_cms_frontend_dependencies_when_enabled
    options = Struct.new(:cms_enabled?, :cms_provider, :product_slug).new(true, "keystatic", "my-super-app")

    Dir.mktmpdir("init-new-project") do |root|
      context = Workspace::Context.new(root: root)
      service = Workspace::Services::InitNewProject.new(["my-super-app"], context: context)

      repositories = [
        {
          "purpose" => "frontend-web-client",
          "path" => "repos/my-super-app-web"
        }
      ]
      Workspace.stubs(:repositories).returns(repositories)

      frontend_root = File.join(root, "repos", "my-super-app-web")
      FileUtils.mkdir_p(frontend_root)

      step_runner = mock("step_runner")
      step_runner.expects(:ruby).with("Install frontend dependencies for CMS feature").yields.returns(true)
      service.stubs(:step_runner).returns(step_runner)

      Workspace.expects(:run).with(
        "npm install",
        has_entries(
          chdir: frontend_root,
          allow_failure: true,
          summary: "Failed to install frontend dependencies for CMS feature."
        )
      ).returns(true)

      assert_equal true, service.send(:install_cms_frontend_dependencies_if_enabled, options)
    end
  end

  private

  def write_manifest(root, installation_id:, include_dsml: false)
    config_dir = File.join(root, "config")
    FileUtils.mkdir_p(config_dir)

    manifest = {
      "project" => {
        "name" => "Product Template Workspace",
        "slug" => "product-template-workspace",
        "installation_id" => installation_id,
        "default_environment" => "production"
      },
      "repositories" => {
        "api" => {
          "purpose" => "backend-api",
          "name" => "api-template",
          "path" => "repos/api-template"
        },
        "web" => {
          "purpose" => "frontend-web-client",
          "name" => "web-template",
          "path" => "repos/web-template"
        },
        "mobile" => {
          "purpose" => "frontend-mobile-client",
          "name" => "mobile-app-template",
          "path" => "repos/mobile-app-template"
        }
      },
      "services" => {
        "api" => {
          "repository" => "api",
          "port" => 5001
        }
      },
      "environments" => {
        "production" => {
          "infrastructure" => {}
        }
      }
    }

    if include_dsml
      manifest["repositories"]["dsml"] = {
        "purpose" => "data-science-ml",
        "name" => "dsml-template",
        "path" => "repos/dsml-template"
      }
    end

    File.write(File.join(config_dir, "project.yml"), YAML.dump(manifest))
  end
end
