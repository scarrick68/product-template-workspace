# frozen_string_literal: true

require_relative "../../../test_helper"

class SyncOpenapiCommandSmokeTest < Minitest::Test
  def test_happy_path_copies_openapi_targets
    Dir.mktmpdir("workspace-sync-openapi") do |root|
      original_root = Workspace::ROOT
      Workspace.send(:remove_const, :ROOT)
      Workspace.const_set(:ROOT, root)

      begin
        write_manifest(
          root,
          api_path: "repos/api-template",
          web_path: "repos/web-template"
        )

        source = File.join(root, "repos", "api-template", "docs")
        FileUtils.mkdir_p(source)
        File.write(File.join(source, "openapi.yml"), "openapi: 3.1.0\n")

        web_repo = File.join(root, "repos", "web-template")
        FileUtils.mkdir_p(web_repo)
        File.write(File.join(web_repo, "package.json"), "{\"scripts\":{}}")

        Workspace.stubs(:ok)
        Workspace.stubs(:warn)
        Workspace.stubs(:run).returns(true)
        Workspace.stubs(:fail_with_help)

        result = Workspace::Services::SyncOpenapi.new.call
        assert_equal 0, result

        assert File.exist?(File.join(root, "contracts", "openapi", "openapi.yml"))
        assert File.exist?(File.join(root, "repos", "web-template", "openapi", "openapi.yml"))
      ensure
        Workspace.send(:remove_const, :ROOT)
        Workspace.const_set(:ROOT, original_root)
      end
    end
  end

  def test_uses_repo_paths_from_config_when_template_names_are_renamed
    Dir.mktmpdir("workspace-sync-openapi-renamed") do |root|
      original_root = Workspace::ROOT
      Workspace.send(:remove_const, :ROOT)
      Workspace.const_set(:ROOT, root)

      begin
        write_manifest(
          root,
          api_path: "repos/my-super-app-api",
          web_path: "repos/my-super-app-web"
        )

        api_repo_path = File.join(root, "repos", "my-super-app-api", "docs")
        FileUtils.mkdir_p(api_repo_path)
        File.write(File.join(api_repo_path, "openapi.yml"), "openapi: 3.1.0\n")

        web_repo = File.join(root, "repos", "my-super-app-web")
        FileUtils.mkdir_p(web_repo)
        File.write(File.join(web_repo, "package.json"), "{\"scripts\":{}}")

        Workspace.stubs(:repositories).returns([
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
        ])

        Workspace.stubs(:ok)
        Workspace.stubs(:warn)
        Workspace.stubs(:run).returns(true)
        Workspace.stubs(:fail_with_help)

        result = Workspace::Services::SyncOpenapi.new.call
        assert_equal 0, result

        assert File.exist?(File.join(root, "contracts", "openapi", "openapi.yml"))
        assert File.exist?(File.join(root, "repos", "my-super-app-web", "openapi", "openapi.yml"))
      ensure
        Workspace.send(:remove_const, :ROOT)
        Workspace.const_set(:ROOT, original_root)
      end
    end
  end

  def test_runs_gen_api_script_for_web_type_generation_when_present
    Dir.mktmpdir("workspace-sync-openapi-gen-api") do |root|
      original_root = Workspace::ROOT
      Workspace.send(:remove_const, :ROOT)
      Workspace.const_set(:ROOT, root)

      begin
        write_manifest(
          root,
          api_path: "repos/api-template",
          web_path: "repos/web-template"
        )

        source = File.join(root, "repos", "api-template", "docs")
        FileUtils.mkdir_p(source)
        File.write(File.join(source, "openapi.yml"), "openapi: 3.1.0\n")

        web_repo = File.join(root, "repos", "web-template")
        FileUtils.mkdir_p(web_repo)
        File.write(
          File.join(web_repo, "package.json"),
          JSON.dump({ "scripts" => { "gen:api" => "orval --config ./orval.config.ts" } })
        )

        Workspace.stubs(:ok)
        Workspace.stubs(:warn)
        Workspace.stubs(:info)
        Workspace.expects(:run).with("npm run gen:api", chdir: web_repo, allow_failure: true).returns(true)
        Workspace.stubs(:fail_with_help)

        result = Workspace::Services::SyncOpenapi.new.call
        assert_equal 0, result
      ensure
        Workspace.send(:remove_const, :ROOT)
        Workspace.const_set(:ROOT, original_root)
      end
    end
  end

  private

  def write_manifest(root, api_path:, web_path:)
    config_dir = File.join(root, "config")
    FileUtils.mkdir_p(config_dir)
    File.write(
      File.join(config_dir, "project.yml"),
      <<~YAML
        project:
          name: Product Template Workspace
          slug: product-template-workspace
          default_environment: production

        repositories:
          api:
            purpose: backend-api
            name: #{File.basename(api_path)}
            path: #{api_path}
            github: example-org/#{File.basename(api_path)}
          web:
            purpose: frontend-web-client
            name: #{File.basename(web_path)}
            path: #{web_path}
            github: example-org/#{File.basename(web_path)}

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
    )
  end
end
