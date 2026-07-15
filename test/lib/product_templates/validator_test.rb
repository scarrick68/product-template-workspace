# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../lib/product_templates/validator"

class ProductTemplatesValidatorTest < Minitest::Test
  def test_happy_path_uses_purpose_paths_for_validation
    Dir.mktmpdir do |tmpdir|
      api_dir = File.join(tmpdir, "repos", "my-super-app-api")
      web_dir = File.join(tmpdir, "repos", "my-super-app-web")
      FileUtils.mkdir_p(api_dir)
      FileUtils.mkdir_p(web_dir)

      fake_repos = [
        {
          "purpose" => "backend-api",
          "name" => "my-super-app-api",
          "path" => "repos/my-super-app-api",
          "github" => "example-org/my-super-app-api"
        },
        {
          "purpose" => "frontend-web-client",
          "name" => "my-super-app-web",
          "path" => "repos/my-super-app-web",
          "github" => "example-org/my-super-app-web"
        }
      ]

      Workspace.stubs(:repositories).returns(fake_repos)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)

      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).returns(true)
      Workspace.expects(:run).with(
        "bin/status",
        chdir: tmpdir,
        allow_failure: true
      ).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end

  def test_starts_backend_opensearch_compose_before_running_api_ci
    Dir.mktmpdir do |tmpdir|
      api_dir = File.join(tmpdir, "repos", "my-super-app-api")
      web_dir = File.join(tmpdir, "repos", "my-super-app-web")
      FileUtils.mkdir_p(api_dir)
      FileUtils.mkdir_p(web_dir)
      FileUtils.mkdir_p(File.join(tmpdir, "config"))

      File.write(File.join(api_dir, "compose.yml"), "services:\n  opensearch:\n")
      File.write(
        File.join(tmpdir, "config", "project.yml"),
        <<~YAML
          project:
            name: Product Template Workspace
            slug: product-template-workspace
            default_environment: production

          repositories:
            api:
              purpose: backend-api
              name: my-super-app-api
              path: repos/my-super-app-api
            web:
              purpose: frontend-web-client
              name: my-super-app-web
              path: repos/my-super-app-web

          services:
            opensearch:
              port: 9200

          environments:
            production:
              infrastructure:
                provider: digitalocean
        YAML
      )

      fake_repos = [
        {
          "purpose" => "backend-api",
          "name" => "my-super-app-api",
          "path" => "repos/my-super-app-api"
        },
        {
          "purpose" => "frontend-web-client",
          "name" => "my-super-app-web",
          "path" => "repos/my-super-app-web"
        }
      ]

      Workspace.stubs(:repositories).returns(fake_repos)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:info)
      Workspace.stubs(:command_exists?).with("docker").returns(true)

      sequence = sequence("validator-compose-sequence")

      Workspace.expects(:capture)
               .with("lsof -tiTCP:9200 -sTCP:LISTEN")
               .in_sequence(sequence)
               .returns(["", false])
      Workspace.expects(:capture)
               .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:run)
               .with(
                 "docker compose up -d opensearch",
                 has_entries(
                   chdir: api_dir,
                   allow_failure: true,
                   summary: "Could not start backend OpenSearch infrastructure for CI."
                 )
               )
               .in_sequence(sequence)
               .returns(true)
      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("bin/status", chdir: tmpdir, allow_failure: true).in_sequence(sequence).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end
end
