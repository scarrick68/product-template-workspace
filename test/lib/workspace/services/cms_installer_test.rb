# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "stringio"
require "tmpdir"
require "yaml"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/cms/installer"

class CmsInstallerTest < Minitest::Test
  def test_returns_success_for_default_no_cms_provider
    Dir.mktmpdir("cms-installer") do |root|
      Workspace.expects(:fail_with_help).never

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 0, installer.call(provider: "none")
    end
  end

  def test_returns_failure_for_unsupported_provider
    Dir.mktmpdir("cms-installer") do |root|
      Workspace.expects(:fail_with_help).with(
        "Unsupported CMS provider 'sanity'.",
        has_entry(details: "Supported CMS providers: none, keystatic")
      )

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 1, installer.call(provider: "sanity")
    end
  end

  def test_keystatic_records_cms_feature_in_project_manifest
    Dir.mktmpdir("cms-installer") do |root|
      write_manifest(root)
      write_frontend_package(root)

      Workspace.expects(:ok).with("CMS feature recorded in project manifest (provider: keystatic).")
      Workspace.expects(:info).with("Keystatic local authoring scaffolding has been added to the frontend repository.")
      Workspace.expects(:info).with("Installer auto-commits CMS scaffolding with [SYSTEM][INSTALLER] so rollback remains a simple git revert.")

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 0, installer.call(provider: "keystatic")

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      cms = manifest.fetch("features").fetch("cms")

      assert_equal true, cms.fetch("enabled")
      assert_equal "keystatic", cms.fetch("provider")
      assert_equal "local", cms.fetch("authoring")
      assert_equal "git", cms.fetch("publishing")

      package = JSON.parse(File.read(File.join(root, "repos", "web-template", "package.json")))
      assert_equal "^5.0.0", package.fetch("dependencies").fetch("@keystatic/core")
      assert_equal "tsx src/content/validate-content.ts", package.fetch("scripts").fetch("content:check")

      assert File.exist?(File.join(root, "repos", "web-template", "keystatic.config.ts"))
      assert File.exist?(File.join(root, "repos", "web-template", "src", "content", "validate-content.ts"))
      assert File.exist?(File.join(root, "repos", "web-template", "bin", "content"))
      assert File.exist?(File.join(root, "repos", "web-template", "bin", "content-check"))
      assert File.exist?(File.join(root, "repos", "web-template", "content", "articles", "hello-world", "index.yaml"))
      assert File.exist?(File.join(root, "repos", "web-template", "content", "articles", "hello-world", "body.mdoc"))
      assert File.exist?(File.join(root, "docs", "content-authoring.md"))
    end
  end

  def test_keystatic_is_idempotent_when_already_enabled
    Dir.mktmpdir("cms-installer") do |root|
      write_frontend_package(root)
      write_manifest(root, cms: {
        "enabled" => true,
        "provider" => "keystatic",
        "authoring" => "local",
        "publishing" => "git"
      })

      Workspace.expects(:info).with("CMS provider 'keystatic' is already enabled; skipping install.")
      Workspace.expects(:ok).never
      Workspace.expects(:warn).never

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 0, installer.call(provider: "keystatic")
    end
  end

  def test_keystatic_refuses_provider_replacement
    Dir.mktmpdir("cms-installer") do |root|
      write_frontend_package(root)
      write_manifest(root, cms: {
        "enabled" => true,
        "provider" => "sanity"
      })

      Workspace.expects(:fail_with_help).with(
        "CMS provider replacement is not supported.",
        has_entry(details: "Current provider in config/project.yml is 'sanity'. Requested provider is 'keystatic'.")
      )

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 1, installer.call(provider: "keystatic")
    end
  end

  def test_keystatic_fails_prerequisites_before_manifest_mutation_when_package_json_missing
    Dir.mktmpdir("cms-installer") do |root|
      write_manifest(root)
      FileUtils.mkdir_p(File.join(root, "repos", "web-template"))

      Workspace.expects(:fail_with_help).with(
        "CMS install prerequisites failed.",
        has_entry(details: "Missing frontend package.json at #{File.join(root, 'repos', 'web-template', 'package.json')}.")
      )

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 1, installer.call(provider: "keystatic")

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      refute manifest.key?("features")
    end
  end

  def test_keystatic_fails_prerequisites_when_cms_script_keys_already_exist
    Dir.mktmpdir("cms-installer") do |root|
      write_manifest(root)
      write_frontend_package(root, scripts: {
        "dev" => "vike dev",
        "content" => "custom-content-command"
      })

      Workspace.expects(:fail_with_help).with(
        "CMS install prerequisites failed.",
        has_entry(details: includes("scripts.content"))
      )

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 1, installer.call(provider: "keystatic")

      manifest = YAML.safe_load_file(File.join(root, "config", "project.yml"), permitted_classes: [], aliases: false)
      refute manifest.key?("features")
    end
  end

  def test_keystatic_creates_system_installer_commit_when_repo_is_git
    Dir.mktmpdir("cms-installer") do |root|
      write_manifest(root)
      write_frontend_package(root)
      initialize_git_repo(root)

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 0, installer.call(provider: "keystatic")

      subject = read_git_stdout(root, "log", "-1", "--pretty=%s")
      assert_equal "[SYSTEM][INSTALLER] Enable CMS scaffolding (keystatic)", subject
    end
  end

  def test_keystatic_creates_preinstall_checkpoint_commit_for_unrelated_existing_changes
    Dir.mktmpdir("cms-installer") do |root|
      write_manifest(root)
      write_frontend_package(root)
      initialize_git_repo(root)

      File.write(File.join(root, "README.md"), "pre-existing change\n")

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 0, installer.call(provider: "keystatic")

      commit_subjects = read_git_stdout(root, "log", "-2", "--pretty=%s").split("\n")
      assert_equal "[SYSTEM][INSTALLER] Enable CMS scaffolding (keystatic)", commit_subjects[0]
      assert_equal "[SYSTEM][INSTALLER] CMS pre-install checkpoint commit. CMS will be installed in a single commit after this.", commit_subjects[1]

      committed_paths = read_git_stdout(root, "show", "--pretty=", "--name-only", "HEAD").split("\n")

      assert_includes committed_paths, "config/project.yml"
      assert_includes committed_paths, "repos/web-template/keystatic.config.ts"
      assert_includes committed_paths, "repos/web-template/content/articles/hello-world/index.yaml"
      assert_includes committed_paths, "repos/web-template/content/articles/hello-world/body.mdoc"
      refute_includes committed_paths, "README.md"

      checkpoint_paths = read_git_stdout(root, "show", "--pretty=", "--name-only", "HEAD~1").split("\n")
      assert_includes checkpoint_paths, "README.md"

      status = read_git_stdout(root, "status", "--short")
      assert_equal "", status
    end
  end

  def test_keystatic_creates_missing_package_sections_when_safe
    Dir.mktmpdir("cms-installer") do |root|
      write_manifest(root)
      write_frontend_package(root, include_dependencies: false, include_dev_dependencies: false)

      installer = Workspace::Services::Cms::Installer.new(
        context: Workspace::Context.new(root: root),
        stdin: StringIO.new,
        stdout: StringIO.new
      )

      assert_equal 0, installer.call(provider: "keystatic")

      package = JSON.parse(File.read(File.join(root, "repos", "web-template", "package.json")))
      assert_equal "^5.0.0", package.fetch("dependencies").fetch("@keystatic/core")
      assert_equal "^4.20.5", package.fetch("devDependencies").fetch("tsx")
      assert_equal "vike dev", package.fetch("scripts").fetch("content")
      assert_equal "tsx src/content/validate-content.ts", package.fetch("scripts").fetch("content:check")
    end
  end

  private

  def write_manifest(root, cms: nil)
    config_dir = File.join(root, "config")
    FileUtils.mkdir_p(config_dir)

    manifest = {
      "project" => {
        "name" => "Product Template Workspace",
        "slug" => "product-template-workspace",
        "installation_id" => "a91d7c",
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

    manifest["features"] = { "cms" => cms } if cms

    File.write(File.join(config_dir, "project.yml"), YAML.dump(manifest))
  end

  def write_frontend_package(
    root,
    scripts: nil,
    dependencies: nil,
    dev_dependencies: nil,
    include_dependencies: true,
    include_dev_dependencies: true
  )
    web_root = File.join(root, "repos", "web-template")
    FileUtils.mkdir_p(web_root)

    package = {
      "name" => "web-template",
      "scripts" => scripts || {
        "dev" => "vike dev"
      }
    }

    if include_dependencies
      package["dependencies"] = dependencies || {
        "react" => "^19.2.7"
      }
    end

    if include_dev_dependencies
      package["devDependencies"] = dev_dependencies || {
        "typescript" => "^6.0.3"
      }
    end

    File.write(File.join(web_root, "package.json"), JSON.pretty_generate(package) + "\n")
  end

  def initialize_git_repo(root)
    run_git(root, "init")
    run_git(root, "config", "user.name", "Local Test User")
    run_git(root, "config", "user.email", "local-test@example.com")
    run_git(root, "add", ".")
    run_git(root, "commit", "-m", "Initial commit")
  end

  def run_git(root, *args)
    read_git_stdout(root, *args)
  end

  def read_git_stdout(root, *args)
    output, status = Open3.capture2e("git", *args, chdir: root)
    raise "git #{args.join(' ')} failed: #{output}" unless status.success?

    output.strip
  end
end