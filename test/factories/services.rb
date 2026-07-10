# frozen_string_literal: true

FactoryBot.define do
  factory :service_hash, class: Hash do
    skip_create

    transient do
      repository { "api" }
      port { 5001 }
    end

    initialize_with do
      {
        "repository" => repository,
        "port" => port
      }
    end
  end
end
