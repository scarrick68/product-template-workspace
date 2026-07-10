# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/project_manifest/schema"

class ProjectManifestSchemaTest < Minitest::Test
  def test_validate_passes_for_valid_manifest
    manifest = build(:project_manifest_hash)

    assert_equal manifest, Workspace::ProjectManifest::Schema.new(manifest: manifest).validate!
  end

  def test_validate_raises_when_top_level_section_missing
    manifest = build(:project_manifest_hash)
    manifest.delete("services")

    error = assert_raises(Workspace::ProjectManifest::Schema::ValidationError) do
      Workspace::ProjectManifest::Schema.new(manifest: manifest).validate!
    end

    assert_includes error.message, "config/project.yml is missing required sections: services"
  end

  def test_validate_raises_when_repository_path_missing
    manifest = build(:project_manifest_hash)
    manifest["repositories"]["api"].delete("path")

    error = assert_raises(Workspace::ProjectManifest::Schema::ValidationError) do
      Workspace::ProjectManifest::Schema.new(manifest: manifest).validate!
    end

    assert_includes error.message, "config/project.yml: repositories.api.path must be a non-empty string"
  end

  def test_validate_raises_when_service_port_is_not_integer
    manifest = build(:project_manifest_hash)
    manifest["services"]["api"]["port"] = "abc"

    error = assert_raises(Workspace::ProjectManifest::Schema::ValidationError) do
      Workspace::ProjectManifest::Schema.new(manifest: manifest).validate!
    end

    assert_includes error.message, "config/project.yml: services.api.port must be an integer"
  end

  def test_validate_raises_when_environment_infrastructure_missing
    manifest = build(:project_manifest_hash)
    manifest["environments"]["production"].delete("infrastructure")

    error = assert_raises(Workspace::ProjectManifest::Schema::ValidationError) do
      Workspace::ProjectManifest::Schema.new(manifest: manifest).validate!
    end

    assert_includes error.message, "config/project.yml: environments.production.infrastructure"
  end

  def test_valid_returns_true_for_valid_manifest
    manifest = build(:project_manifest_hash)

    assert_equal true, Workspace::ProjectManifest::Schema.new(manifest: manifest).valid?
  end

  def test_valid_returns_false_for_invalid_manifest
    manifest = build(:project_manifest_hash)
    manifest.delete("services")

    assert_raises(Workspace::ProjectManifest::Schema::ValidationError) do
      Workspace::ProjectManifest::Schema.new(manifest: manifest).valid?
    end
  end
end
