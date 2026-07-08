# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/resource_availability"

class InfraResourceAvailabilityTest < Minitest::Test
  def test_blob_store_enabled_reads_infra_components_spaces
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      { "components" => { "spaces" => true } }
    )

    assert_equal true, availability.blob_store_enabled?
  end

  def test_blob_store_enabled_defaults_false_when_spaces_component_missing
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config({})

    assert_equal false, availability.blob_store_enabled?
  end

  def test_blob_store_enabled_can_be_overridden
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      { "components" => { "spaces" => false } },
      overrides: { blob_store_enabled: true }
    )

    assert_equal true, availability.blob_store_enabled?
  end

  def test_blob_store_provider_reads_spaces_provider_from_config
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => true },
        "spaces_provider" => "aws_s3"
      }
    )

    assert_equal "aws_s3", availability.blob_store_provider
  end

  def test_blob_store_provider_reads_blob_store_provider_from_config
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => true },
        "blob_store_provider" => "aws_s3"
      }
    )

    assert_equal "aws_s3", availability.blob_store_provider
  end

  def test_blob_store_provider_returns_nil_when_disabled
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => false },
        "spaces_provider" => "digitalocean_spaces"
      }
    )

    assert_nil availability.blob_store_provider
  end

  def test_blob_store_provider_can_be_overridden
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => true },
        "spaces_provider" => "digitalocean_spaces"
      },
      overrides: {
        blob_store_provider: "aws_s3"
      }
    )

    assert_equal "aws_s3", availability.blob_store_provider
  end

  def test_blob_store_provider_override_accepts_spaces_provider_alias
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => true },
        "spaces_provider" => "digitalocean_spaces"
      },
      overrides: {
        spaces_provider: "aws_s3"
      }
    )

    assert_equal "aws_s3", availability.blob_store_provider
  end

  def test_managed_digitalocean_blob_store_enabled_when_enabled_and_provider_matches
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => true },
        "spaces_provider" => "digitalocean_spaces"
      }
    )

    assert_equal true, availability.managed_digitalocean_blob_store_enabled?
  end

  def test_managed_digitalocean_blob_store_disabled_when_provider_does_not_match
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => true },
        "spaces_provider" => "aws_s3"
      }
    )

    assert_equal false, availability.managed_digitalocean_blob_store_enabled?
  end

  def test_managed_digitalocean_blob_store_disabled_when_blob_store_disabled
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => false },
        "spaces_provider" => "digitalocean_spaces"
      }
    )

    assert_equal false, availability.managed_digitalocean_blob_store_enabled?
  end

  def test_overrides_with_string_keys_are_supported
    availability = Workspace::Commands::Infra::ResourceAvailability.from_infra_config(
      {
        "components" => { "spaces" => false },
        "spaces_provider" => "digitalocean_spaces"
      },
      overrides: {
        "blob_store_enabled" => true,
        "blob_store_provider" => "aws_s3"
      }
    )

    assert_equal true, availability.blob_store_enabled?
    assert_equal "aws_s3", availability.blob_store_provider
  end
end
