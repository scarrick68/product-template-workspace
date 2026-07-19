# frozen_string_literal: true

FactoryBot.define do
  factory :project_manifest_hash, class: Hash do
    skip_create

    transient do
      project_name { "Product Template Workspace" }
      slug { "product-template-workspace" }
      installation_id { "a91d7c" }
      default_environment { "production" }
      api_port { 5001 }
      web_port { 3000 }
    end

    initialize_with do
      {
        "project" => {
          "name" => project_name,
          "slug" => slug,
          "installation_id" => installation_id,
          "default_environment" => default_environment
        },
        "repositories" => {
          "api" => build(
            :repository_hash,
            purpose: "backend-api",
            name: "api-template",
            path: "repos/api-template"
          ),
          "web" => build(
            :repository_hash,
            purpose: "frontend-web-client",
            name: "web-template",
            path: "repos/web-template",
            github: "example/web-template"
          )
        },
        "services" => {
          "api" => build(:service_hash, repository: "api", port: api_port),
          "web" => build(:service_hash, repository: "web", port: web_port)
        },
        "environments" => {
          default_environment => build(:environment_config_hash)
        }
      }
    end

    trait :with_opensearch do
      after(:build) do |manifest|
        manifest["environments"]["production"]["infrastructure"]["components"] ||= {}
        manifest["environments"]["production"]["infrastructure"]["components"]["opensearch"] = {
          "enabled" => true,
          "size" => "db-s-1vcpu-1gb"
        }
      end
    end

    trait :without_spaces do
      after(:build) do |manifest|
        manifest["environments"]["production"]["infrastructure"]["components"] ||= {}
        manifest["environments"]["production"]["infrastructure"]["components"]["spaces"] = {
          "enabled" => false
        }
      end
    end
  end
end
