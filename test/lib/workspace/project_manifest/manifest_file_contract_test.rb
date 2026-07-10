# frozen_string_literal: true

require "yaml"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/project_manifest/schema"

class ProjectManifestFileContractTest < Minitest::Test
  def test_project_manifest_exists_at_canonical_path
    assert File.exist?(manifest_path), "Expected manifest at #{manifest_path}"
  end

  def test_project_manifest_has_required_format_and_validates
    manifest = load_manifest

    validated = Workspace::ProjectManifest::Schema.new(manifest: manifest).validate!

    assert_equal manifest, validated
  end

  def test_project_manifest_round_trips_through_yaml_serialization
    manifest = load_manifest

    serialized = YAML.dump(manifest)
    reparsed = YAML.safe_load(serialized, permitted_classes: [], aliases: false)

    assert_equal manifest, reparsed
    assert_equal reparsed, Workspace::ProjectManifest::Schema.new(manifest: reparsed).validate!
  end

  private

  def manifest_path
    File.join(Workspace::ROOT, "config", "project.yml")
  end

  def load_manifest
    YAML.safe_load_file(manifest_path, permitted_classes: [], aliases: false)
  end
end
