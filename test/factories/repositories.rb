# frozen_string_literal: true

FactoryBot.define do
  factory :repository_hash, class: Hash do
    skip_create

    transient do
      purpose { "backend-api" }
      name { "api-template" }
      path { "repos/api-template" }
      github { "example/api-template" }
    end

    initialize_with do
      {
        "purpose" => purpose,
        "name" => name,
        "path" => path,
        "github" => github
      }
    end
  end
end
