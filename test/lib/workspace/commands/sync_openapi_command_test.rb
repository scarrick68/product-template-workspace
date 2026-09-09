# frozen_string_literal: true

require "json"

require_relative "../../../test_helper"

class SyncOpenapiCommandContractTest < Minitest::Test
  def test_happy_path_copies_openapi_targets_without_touching_real_files
    service = Workspace::Services::SyncOpenapi.new
    source = File.join(api_repo, "docs", "openapi.yml")
    contracts_target = File.join(Workspace::ROOT, "contracts", "openapi", "openapi.yml")
    web_target = File.join(web_repo, "openapi", "openapi.yml")
    mobile_target = File.join(mobile_repo, "openapi", "openapi.yml")
    package_json = File.join(web_repo, "package.json")
    mobile_package_json = File.join(mobile_repo, "package.json")

    Workspace.stubs(:repositories).returns(repositories)
    Workspace.expects(:ok).with("synced OpenAPI to contracts/openapi/openapi.yml")
    Workspace.expects(:ok).with("synced OpenAPI to repos/my-super-app-web/openapi/openapi.yml")
    Workspace.expects(:ok).with("synced OpenAPI to repos/my-super-app-mobile/openapi/openapi.yml")
    Workspace.stubs(:warn)
    Workspace.stubs(:info)
    Workspace.stubs(:run)
    Workspace.stubs(:fail_with_help)
    service.stubs(:repository_present?).returns(true)

    File.expects(:exist?).with(source).returns(true)
    File.expects(:exist?).with(package_json).returns(false)
    File.expects(:exist?).with(mobile_package_json).returns(false)

    FileUtils.expects(:mkdir_p).with(File.dirname(contracts_target))
    FileUtils.expects(:cp).with(source, contracts_target)
    FileUtils.expects(:mkdir_p).with(File.dirname(web_target))
    FileUtils.expects(:cp).with(source, web_target)
    FileUtils.expects(:mkdir_p).with(File.dirname(mobile_target))
    FileUtils.expects(:cp).with(source, mobile_target)

    assert_equal 0, service.call
  end

  def test_uses_repositories_configuration_for_source_and_web_targets
    service = Workspace::Services::SyncOpenapi.new
    source = File.join(api_repo, "docs", "openapi.yml")
    contracts_target = File.join(Workspace::ROOT, "contracts", "openapi", "openapi.yml")
    web_target = File.join(web_repo, "openapi", "openapi.yml")
    mobile_target = File.join(mobile_repo, "openapi", "openapi.yml")
    package_json = File.join(web_repo, "package.json")
    mobile_package_json = File.join(mobile_repo, "package.json")

    Workspace.expects(:repositories).at_least_once.returns(repositories)
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.stubs(:info)
    Workspace.stubs(:run)
    Workspace.stubs(:fail_with_help)
    service.stubs(:repository_present?).returns(true)

    File.expects(:exist?).with(source).returns(true)
    File.expects(:exist?).with(package_json).returns(false)
    File.expects(:exist?).with(mobile_package_json).returns(false)
    FileUtils.stubs(:mkdir_p)
    FileUtils.expects(:cp).with(source, contracts_target)
    FileUtils.expects(:cp).with(source, web_target)
    FileUtils.expects(:cp).with(source, mobile_target)

    assert_equal 0, service.call
  end

  def test_runs_gen_api_script_when_present
    service = Workspace::Services::SyncOpenapi.new
    source = File.join(api_repo, "docs", "openapi.yml")
    package_json = File.join(web_repo, "package.json")
    mobile_package_json = File.join(mobile_repo, "package.json")

    Workspace.stubs(:repositories).returns(repositories)
    Workspace.stubs(:ok)
    Workspace.stubs(:warn)
    Workspace.expects(:info).with("regenerating web types via npm run gen:api")
    Workspace.expects(:run).with("npm run gen:api", chdir: web_repo, allow_failure: true).returns(true)
    Workspace.stubs(:fail_with_help)
    service.stubs(:repository_present?).returns(true)

    File.expects(:exist?).with(source).returns(true)
    File.expects(:exist?).with(package_json).returns(true)
    File.expects(:exist?).with(mobile_package_json).returns(false)
    File.expects(:read).with(package_json).returns(JSON.dump({ "scripts" => { "gen:api" => "orval" } }))
    FileUtils.stubs(:mkdir_p)
    FileUtils.stubs(:cp)

    assert_equal 0, service.call
  end

    def test_calls_type_generation_when_repo_has_api_generate_script
      service = Workspace::Services::SyncOpenapi.new

      repo = File.join(Workspace::ROOT, "tmp", "sync-openapi-api-generate")
      package_json = File.join(repo, "package.json")

      service.stubs(:repository_present?).returns(true)
      service.stubs(:web_repo).returns(repo)
      service.stubs(:mobile_repo).returns(repo)

      File.stubs(:exist?).with(package_json).returns(true)
      File.expects(:read).with(package_json).returns(JSON.dump({ "scripts" => { "api:generate" => "orval" } })).twice

      Workspace.expects(:info).with("regenerating web types via npm run api:generate")
      Workspace.expects(:info).with("regenerating mobile types via npm run api:generate")
      Workspace.expects(:run).with("npm run api:generate", chdir: repo, allow_failure: true).twice.returns(true)

      assert_equal 0, service.send(:regenerate_types_if_configured)
    end
  private

  def api_repo
    File.join(Workspace::ROOT, "repos", "my-super-app-api")
  end

  def web_repo
    File.join(Workspace::ROOT, "repos", "my-super-app-web")
  end

  def mobile_repo
    File.join(Workspace::ROOT, "repos", "my-super-app-mobile")
  end

  def repositories
    [
      {
        "purpose" => "backend-api",
        "name" => "my-super-app-api",
        "path" => "repos/my-super-app-api"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "my-super-app-web",
        "path" => "repos/my-super-app-web"
      },
      {
        "purpose" => "frontend-mobile-client",
        "name" => "my-super-app-mobile",
        "path" => "repos/my-super-app-mobile"
      }
    ]
  end
end
