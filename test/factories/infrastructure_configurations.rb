# frozen_string_literal: true

FactoryBot.define do
  factory :environment_config_hash, class: Hash do
    skip_create

    transient do
      provider { "digitalocean" }
      region { "nyc3" }
    end

    initialize_with do
      {
        "infrastructure" => {
          "provider" => provider,
          "region" => region
        }
      }
    end
  end
end
