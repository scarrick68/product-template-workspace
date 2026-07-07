# frozen_string_literal: true

require_relative "../../../test_helper"

class DevCommandTest < Minitest::Test
  def test_uses_repositories_from_config_for_service_discovery
    Workspace.stubs(:ports).returns({ "api" => 5001, "web" => 3000 })
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

    File.stubs(:executable?).returns(false)
    File.stubs(:exist?).returns(false)

    File.stubs(:executable?).with(File.join(Workspace::ROOT, "repos", "my-super-app-api", "bin", "dev")).returns(true)
    File.stubs(:exist?).with(File.join(Workspace::ROOT, "repos", "my-super-app-web", "package.json")).returns(true)

    command = Workspace::Commands::DevCommand.new
    command.send(:build_services)

    services = command.send(:services)

    assert_equal 2, services.size
    assert_equal File.join(Workspace::ROOT, "repos", "my-super-app-api"), services[0][:chdir]
    assert_equal "bin/dev", services[0][:command]
    assert_equal File.join(Workspace::ROOT, "repos", "my-super-app-web"), services[1][:chdir]
    assert_equal "npm run dev -- --port 3000", services[1][:command]
  end
end
