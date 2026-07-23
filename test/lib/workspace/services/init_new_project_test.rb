# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/init_new_project"

class InitNewProjectTest < Minitest::Test
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

  def write_manifest(root, installation_id:)
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

    File.write(File.join(config_dir, "project.yml"), YAML.dump(manifest))
  end
end
