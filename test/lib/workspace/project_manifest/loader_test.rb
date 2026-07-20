# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "yaml"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/project_manifest/errors"
require_relative "../../../../lib/workspace/project_manifest/schema"
require_relative "../../../../lib/workspace/project_manifest/loader"

class ProjectManifestLoaderTest < Minitest::Test
  def test_load_returns_nil_when_manifest_missing
    Dir.mktmpdir do |root|
      loader = Workspace::ProjectManifest::Loader.new(root: root)

      assert_nil loader.load
    end
  end

  def test_load_returns_manifest_when_valid
    Dir.mktmpdir do |root|
      write_project_yaml(root, build(:project_manifest_hash))

      manifest = Workspace::ProjectManifest::Loader.new(root: root).load

      assert_equal "Product Template Workspace", manifest["project"]["name"]
      assert_equal 5001, manifest["services"]["api"]["port"]
    end
  end

  def test_load_raises_invalid_manifest_when_yaml_invalid
    Dir.mktmpdir do |root|
      write_project_yaml_text(
        root,
        <<~INVALID_YAML
          project:
            name: ok
          repositories:
            - bad
            :
        INVALID_YAML
      )

      error = assert_raises(Workspace::ProjectManifest::InvalidManifest) do
        Workspace::ProjectManifest::Loader.new(root: root).load
      end

      assert_includes error.message, project_manifest_path(root)
      assert_includes error.message, "invalid YAML"
    end
  end

  def test_load_raises_invalid_manifest_when_schema_invalid
    Dir.mktmpdir do |root|
      manifest = build(:project_manifest_hash)
      manifest["services"]["api"]["port"] = "bad"

      write_project_yaml(root, manifest)

      error = assert_raises(Workspace::ProjectManifest::InvalidManifest) do
        Workspace::ProjectManifest::Loader.new(root: root).load
      end

      assert_includes error.message, project_manifest_path(root)
      assert_includes error.message, "services.api.port must be an integer"
    end
  end

  def test_load_rejects_installation_id_placeholder
    Dir.mktmpdir do |root|
      manifest = build(:project_manifest_hash)
      manifest["project"]["installation_id"] = "__INSTALLATION_ID__"

      write_project_yaml(root, manifest)

      error = assert_raises(Workspace::ProjectManifest::InvalidManifest) do
        Workspace::ProjectManifest::Loader.new(root: root).load
      end

      assert_includes error.message, "project.installation_id must be six lowercase hexadecimal characters"
    end
  end

  private

  def write_project_yaml(root, data)
    path = project_manifest_path(root)

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, YAML.dump(data))
  end

  def write_project_yaml_text(root, contents)
    path = project_manifest_path(root)

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end

  def project_manifest_path(root)
    File.join(root, "config", "project.yml")
  end
end