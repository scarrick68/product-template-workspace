# frozen_string_literal: true

require "tmpdir"

require_relative "../../test_helper"

class WorkspaceContextTest < Minitest::Test
  def test_repositories_reflect_manifest_updates_within_same_process
    Dir.mktmpdir("workspace-context") do |tmpdir|
      config_dir = File.join(tmpdir, "config")
      FileUtils.mkdir_p(config_dir)

      manifest_path = File.join(config_dir, "project.yml")
      File.write(manifest_path, manifest_yaml(api_name: "api-template", web_name: "web-template"))

      context = Workspace::Context.new(root: tmpdir)
      first_repositories = context.repositories

      assert_equal %w[api-template web-template], first_repositories.values.map { |repo| repo.fetch("name") }.sort

      File.write(manifest_path, manifest_yaml(api_name: "my-super-app-api", web_name: "my-super-app-web"))

      updated_repositories = context.repositories
      assert_equal %w[my-super-app-api my-super-app-web], updated_repositories.values.map { |repo| repo.fetch("name") }.sort
    end
  end

  private

  def manifest_yaml(api_name:, web_name:)
    <<~YAML
      project:
        name: Product Template Workspace
        slug: product-template-workspace
        default_environment: production

      repositories:
        api:
          purpose: backend-api
          name: #{api_name}
          path: repos/#{api_name}
          github: example-org/#{api_name}
        web:
          purpose: frontend-web-client
          name: #{web_name}
          path: repos/#{web_name}
          github: example-org/#{web_name}

      services:
        api:
          repository: api
          port: 5001
        web:
          repository: web
          port: 3000

      environments:
        production:
          infrastructure:
            provider: digitalocean
    YAML
  end
end
