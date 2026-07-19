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
