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

    command = Workspace::Services::Dev.new
    command.send(:build_services)

    services = command.send(:services)

    assert_equal 2, services.size
    assert_equal File.join(Workspace::ROOT, "repos", "my-super-app-api"), services[0][:chdir]
    assert_equal "bin/dev", services[0][:command]
    assert_equal File.join(Workspace::ROOT, "repos", "my-super-app-web"), services[1][:chdir]
    assert_equal "npm run dev -- --port 3000", services[1][:command]
  end

  def test_stops_conflicting_docker_container_on_opensearch_port
    command = Workspace::Services::Dev.new

    Workspace.stubs(:command_exists?).with("docker").returns(true)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail_with_help)

    sequence = sequence("docker-port-conflict")
    Workspace.expects(:capture)
             .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
             .in_sequence(sequence)
             .returns(["abc123|api-template-opensearch\n", true])

    Workspace.expects(:run)
             .with(
               "docker stop abc123",
               has_entry(allow_failure: true)
             )
             .in_sequence(sequence)
             .returns(true)

    Workspace.expects(:capture)
             .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
             .in_sequence(sequence)
             .returns(["", true])

    result = command.send(:ensure_opensearch_port_available, File.join(Workspace::ROOT, "repos", "my-super-app-api"))

    assert_equal true, result
  end

  def test_reuses_expected_opensearch_container_when_port_is_already_occupied
    command = Workspace::Services::Dev.new
    api_repo = File.join(Workspace::ROOT, "repos", "my-super-app-api")

    Workspace.stubs(:command_exists?).with("docker").returns(true)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail_with_help)
    Workspace.expects(:ok).with("OpenSearch port 9200 is already held by this project's container (my-super-app-api-opensearch); reusing it.")

    sequence = sequence("reuse-existing-opensearch")
    Workspace.expects(:capture)
             .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
             .in_sequence(sequence)
             .returns(["abc123|my-super-app-api-opensearch\n", true])

    Workspace.expects(:capture)
             .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
             .in_sequence(sequence)
             .returns(["abc123|my-super-app-api-opensearch\n", true])

    result = command.send(:ensure_opensearch_port_available, api_repo)

    assert_equal true, result
  end
end
