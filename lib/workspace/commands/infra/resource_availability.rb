#!/usr/bin/env ruby
# frozen_string_literal: true
# Helper class for read-only detection of infra resource availability.
# "Spaces" refers to DigitalOcean Spaces, generally we mean blob storage.

module Workspace
  module Commands
    module Infra
      class ResourceAvailability
        # Build from config/infra.yml-style data, with optional runtime overrides.
        # Precedence: explicit overrides -> infra config defaults.
        def self.from_infra_config(config, overrides: {})
          config = config || {}
          normalized_overrides = normalize_overrides(overrides)

          components = config["components"]
          config_enabled = components.is_a?(Hash) && components["spaces"] == true
          config_provider = config["blob_store_provider"] || config["spaces_provider"]

          blob_store_enabled = if normalized_overrides.key?(:blob_store_enabled)
                                 normalized_overrides[:blob_store_enabled] == true
                               else
                                 config_enabled
                               end

          blob_store_provider = if normalized_overrides.key?(:blob_store_provider)
                                  normalized_overrides[:blob_store_provider]
                                else
                                  config_provider
                                end

          new(
            blob_store_enabled: blob_store_enabled,
            blob_store_provider: blob_store_provider
          )
        end

        # Purpose: expose a single read-only view for blob-store availability
        # regardless of source document format (tfvars or infra.yml).
        # blob_store_enabled is an already-computed state flag from config
        # parsing, not an instruction that this class should enable Spaces.
        def initialize(blob_store_enabled:, blob_store_provider:)
          @blob_store_enabled = blob_store_enabled == true
          @resolved_blob_store_provider = normalize_provider(blob_store_provider)
        end

        # Returns true only when blob storage is explicitly enabled.
        # State is normalized by the source constructors.
        def blob_store_enabled?
          blob_store_enabled
        end

        # Returns configured blob provider from the current config, or nil when unset.
        # This method reports provider selection; it does not imply enablement.
        def blob_store_provider
          return nil unless blob_store_enabled?

          resolved_blob_store_provider
        end

        # Convenience predicate for DigitalOcean-managed blob storage usage.
        # Requires blob storage to be enabled and provider to be digitalocean_spaces.
        def managed_digitalocean_blob_store_enabled?
          provider = blob_store_provider
          blob_store_enabled? && provider == "digitalocean_spaces"
        end

        private

        def self.normalize_overrides(overrides)
          hash = overrides || {}
          provider_override = hash[:blob_store_provider]
          provider_override = hash["blob_store_provider"] if provider_override.nil?
          provider_override = hash[:spaces_provider] if provider_override.nil?
          provider_override = hash["spaces_provider"] if provider_override.nil?

          enabled_override = hash[:blob_store_enabled]
          enabled_override = hash["blob_store_enabled"] if enabled_override.nil?

          {
            blob_store_enabled: enabled_override,
            blob_store_provider: provider_override
          }.compact
        end

        def normalize_provider(value)
          provider = value.to_s.strip
          provider.empty? ? nil : provider
        end

        attr_reader :blob_store_enabled, :resolved_blob_store_provider
      end
    end
  end
end