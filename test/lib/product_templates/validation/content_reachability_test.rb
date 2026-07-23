# frozen_string_literal: true

require "stringio"
require "tmpdir"

require_relative "../../../test_helper"
require_relative "../../../../lib/product_templates/validation/content_reachability"

class ContentReachabilityTest < Minitest::Test
  def test_ignores_eperm_when_terminating_process_group
    Dir.mktmpdir do |tmpdir|
      stdout = StringIO.new
      stderr = StringIO.new

      service = ProductTemplates::Validation::ContentReachability.new(
        root: tmpdir,
        target: :vike,
        stdout: stdout,
        stderr: stderr
      )

      service.expects(:ensure_vike_port_available).returns(true)
      service.expects(:spawn).with(
        "npm", "run", "dev", "--", "--host", "127.0.0.1", "--port", "3000",
        chdir: tmpdir, pgroup: true, out: kind_of(Tempfile), err: kind_of(Tempfile)
      ).returns(1234)

      reachability = mock("vike_reachability")
      reachability.expects(:call).with(process_alive: kind_of(Proc), process_failure: kind_of(Proc)).returns(true)
      service.stubs(:vike_reachability).returns(reachability)

      Process.expects(:kill).with("TERM", -1234).raises(Errno::EPERM)
      Process.expects(:wait).with(1234).raises(Errno::ECHILD)

      assert_equal true, service.call
    end
  end

  def test_returns_false_when_vike_port_conflict_is_not_resolved
    Dir.mktmpdir do |tmpdir|
      service = ProductTemplates::Validation::ContentReachability.new(root: tmpdir, target: :vike)

      service.expects(:ensure_vike_port_available).returns(false)
      service.expects(:spawn).never

      assert_equal false, service.call
    end
  end
end
