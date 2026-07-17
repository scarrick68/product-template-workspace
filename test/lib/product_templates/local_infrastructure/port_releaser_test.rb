# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/product_templates/local_infrastructure/port_releaser"

class PortConflictResolverTest < Minitest::Test
  class TtyInput < StringIO
    def tty?
      true
    end
  end

  def test_stop_processes_skips_docker_managed_processes
    resolver = ProductTemplates::LocalInfrastructure::PortConflictResolver.new(
      input: StringIO.new,
      output: StringIO.new
    )

    Workspace.expects(:capture).with("ps -p 111 -o comm=").returns(["/Applications/Docker.app/Contents/MacOS/com.docker.backend\n", true])
    Workspace.expects(:capture).with("ps -p 222 -o comm=").returns(["/usr/sbin/nginx\n", true])
    Workspace.expects(:info).with("Skipping Docker-managed process 111 during port cleanup.")
    Process.expects(:kill).with("TERM", 222)

    resolver.send(:stop_processes, [111, 222])
  end

  def test_stop_processes_terminates_when_process_command_cannot_be_read
    resolver = ProductTemplates::LocalInfrastructure::PortConflictResolver.new(
      input: StringIO.new,
      output: StringIO.new
    )

    Workspace.expects(:capture).with("ps -p 333 -o comm=").returns(["", false])
    Process.expects(:kill).with("TERM", 333)

    resolver.send(:stop_processes, [333])
  end

  def test_resolve_rechecks_usage_after_container_stop_before_stopping_processes
    input = TtyInput.new
    prompt = mock("prompt")
    prompt.expects(:yes?).with("Stop these services and free port 9200?", default: true).returns(true)

    resolver = ProductTemplates::LocalInfrastructure::PortConflictResolver.new(
      input: input,
      output: StringIO.new,
      prompt: prompt
    )

    Workspace.expects(:capture).with("lsof -tiTCP:9200 -sTCP:LISTEN").returns(["100\n", true], ["", false], ["", false]).at_least_once
    Workspace.expects(:capture)
      .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
      .returns(["abc|my-super-app-api-opensearch\n", true], ["", true], ["", true]).at_least_once
    Workspace.expects(:warn).with("OpenSearch cannot start because port 9200 is in use.")
    Workspace.expects(:info).with("Blocking processes: 100 | containers: my-super-app-api-opensearch.")
    Workspace.expects(:run).with("docker stop abc", has_entry(allow_failure: true)).returns(true)
    Process.expects(:kill).never

    assert_equal true, resolver.resolve(9200, service_name: "OpenSearch")
  end

  def test_resolve_reports_when_docker_daemon_is_unavailable
    input = TtyInput.new
    prompt = mock("prompt")
    prompt.expects(:yes?).never

    resolver = ProductTemplates::LocalInfrastructure::PortConflictResolver.new(
      input: input,
      output: StringIO.new,
      prompt: prompt
    )

    Workspace.expects(:capture).with("lsof -tiTCP:9200 -sTCP:LISTEN").returns(["", false])
    Workspace.expects(:capture)
      .with("docker ps --format '{{.ID}}|{{.Names}}' --filter publish=9200")
      .returns(["", false])
    Workspace.expects(:fail_with_help).with(
      "Could not inspect Docker container port usage for OpenSearch.",
      has_entry(details: "Docker daemon is unavailable while resolving port conflicts.")
    )

    assert_equal false, resolver.resolve(9200, service_name: "OpenSearch")
  end
end
