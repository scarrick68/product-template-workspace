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
      Workspace.stubs(:capture).with("docker info").returns(["", true])

      sequence = sequence("validator-compose-sequence")

      Workspace.expects(:capture)
               .with("lsof -tiTCP:9200 -sTCP:LISTEN")
               .in_sequence(sequence)
               .returns(["", false])
      Workspace.expects(:capture)
               .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("bin/status", chdir: tmpdir, allow_failure: true).in_sequence(sequence).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end

  def test_fails_fast_when_docker_daemon_is_not_running_and_auto_start_is_unavailable
    Dir.mktmpdir do |tmpdir|
      api_dir = File.join(tmpdir, "repos", "my-super-app-api")
      web_dir = File.join(tmpdir, "repos", "my-super-app-web")
      FileUtils.mkdir_p(api_dir)
      FileUtils.mkdir_p(web_dir)

      File.write(File.join(api_dir, "compose.yml"), "services:\n  opensearch:\n")

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
      Workspace.stubs(:command_exists?).with("docker").returns(true)
      Workspace.stubs(:command_exists?).with("open").returns(false)
      Workspace.stubs(:capture).with("docker info").returns(["", false])

      Workspace.expects(:info).never
      Workspace.expects(:fail_with_help).with do |summary, options|
        summary == "Docker is installed but the daemon is not running." &&
          options[:details].include?("docker compose up -d opensearch")
      end
      Workspace.expects(:run).never

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 1, validator.call
    end
  end

  def test_attempts_to_start_docker_desktop_when_daemon_is_not_running
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
      Workspace.stubs(:command_exists?).with("open").returns(true)

      sequence = sequence("validator-start-docker-sequence")

      Workspace.expects(:capture)
               .with("docker info")
               .in_sequence(sequence)
               .returns(["", false])
      Workspace.expects(:capture)
           .with("pgrep -x Docker")
           .in_sequence(sequence)
           .returns(["", false])
      Workspace.expects(:info)
               .with("Docker daemon is not running. Attempting to start Docker Desktop in background.")
               .in_sequence(sequence)
      Workspace.expects(:run)
               .with(
                 "open -g -a Docker",
                 has_entries(
                   allow_failure: true,
                   summary: "Could not start Docker Desktop."
                 )
               )
               .in_sequence(sequence)
               .returns(true)
      Workspace.expects(:capture)
               .with("docker info")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:capture)
               .with("lsof -tiTCP:9200 -sTCP:LISTEN")
               .in_sequence(sequence)
               .returns(["", false])
      Workspace.expects(:capture)
               .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("bin/status", chdir: tmpdir, allow_failure: true).in_sequence(sequence).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end

  def test_recovers_when_docker_daemon_drops_before_compose
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
      Workspace.stubs(:command_exists?).with("open").returns(true)

      sequence = sequence("validator-daemon-drop-recovery-sequence")

      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", true])
      Workspace.expects(:capture).with("lsof -tiTCP:9200 -sTCP:LISTEN").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture)
               .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["Cannot connect to the Docker daemon", false])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:run)
               .with("open -g -a Docker", has_entry(allow_failure: true))
               .never

      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("bin/status", chdir: tmpdir, allow_failure: true).in_sequence(sequence).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end

  def test_waits_for_daemon_recovery_without_relaunching_docker_desktop
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
      Workspace.stubs(:command_exists?).with("open").returns(true)

      sequence = sequence("validator-single-docker-open-sequence")

      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture).with("pgrep -x Docker").in_sequence(sequence).returns(["", false])
      Workspace.expects(:run)
               .with(
                 "open -g -a Docker",
                 has_entries(
                   allow_failure: true,
                   summary: "Could not start Docker Desktop."
                 )
               )
               .in_sequence(sequence)
               .returns(true)
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", true])
      Workspace.expects(:capture).with("lsof -tiTCP:9200 -sTCP:LISTEN").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture)
               .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["Cannot connect to the Docker daemon", false])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["", true])

      Workspace.expects(:run).with("bin/ci", chdir: api_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run lint", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run test", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("npm run build", chdir: web_dir, allow_failure: true).in_sequence(sequence).returns(true)
      Workspace.expects(:run).with("bin/status", chdir: tmpdir, allow_failure: true).in_sequence(sequence).returns(true)

      validator = ProductTemplates::Validator.new("my-super-app", workspace_root: tmpdir)

      assert_equal 0, validator.call
    end
  end

  def test_does_not_reopen_docker_desktop_when_app_is_already_running
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
      Workspace.stubs(:command_exists?).with("open").returns(true)

      sequence = sequence("validator-no-reopen-docker-sequence")

      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture).with("pgrep -x Docker").in_sequence(sequence).returns(["12345\n", true])
      Workspace.expects(:capture).with("docker info").in_sequence(sequence).returns(["", true])
      Workspace.expects(:capture).with("lsof -tiTCP:9200 -sTCP:LISTEN").in_sequence(sequence).returns(["", false])
      Workspace.expects(:capture)
               .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:capture)
               .with("docker compose up -d opensearch", chdir: api_dir)
               .in_sequence(sequence)
               .returns(["", true])
      Workspace.expects(:run)
           .with("open -g -a Docker", has_entry(allow_failure: true))
           .never
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
