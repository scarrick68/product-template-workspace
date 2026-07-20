# frozen_string_literal: true

module Workspace
  module Services
    module Infra
      module Doctor
        class RepositoryCheck
          def initialize(root: Workspace::ROOT, repositories_provider: -> { Workspace.repositories })
            @root = root
            @repositories_provider = repositories_provider
          end

          def label
            "expected repositories"
          end

          def call
            repositories = repositories_provider.call
            all_found = true
            targets = {
              "backend-api" => default_repo_name(repositories, "backend-api", "api-template"),
              "frontend-web-client" => default_repo_name(repositories, "frontend-web-client", "web-template")
            }

            targets.each do |purpose, name|
              repo = repositories.find { |item| item["purpose"].to_s == purpose }
              path = repo && repo["path"]
              absolute_path = path && File.join(root, path)

              if absolute_path && Dir.exist?(absolute_path)
                Workspace.ok("repo #{name}: found")
              else
                Workspace.fail("repo #{name}: missing")
                all_found = false
              end
            end

            all_found
          end

          private

          attr_reader :root, :repositories_provider

          def default_repo_name(repositories, purpose, fallback)
            repo = repositories.find { |item| item["purpose"].to_s == purpose }
            return fallback unless repo

            repo["name"].to_s.empty? ? fallback : repo["name"].to_s
          end
        end
      end
    end
  end
end
