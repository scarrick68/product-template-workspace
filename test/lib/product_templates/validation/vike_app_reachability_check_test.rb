# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/product_templates/validation/vike_app_reachability_check"

class VikeAppReachabilityCheckTest < Minitest::Test
  def test_fails_fast_when_process_exits_before_reachability
    stdout = StringIO.new
    stderr = StringIO.new
    process_failure_called = false

    check = ProductTemplates::Validation::VikeAppReachabilityCheck.new(
      url: "http://127.0.0.1:3000",
      timeout_seconds: 5,
      poll_interval_seconds: 0,
      stdout: stdout,
      stderr: stderr
    )

    check.stubs(:http_ok?).returns(false)

    result = check.call(
      process_alive: -> { false },
      process_failure: -> { process_failure_called = true }
    )

    assert_equal false, result
    assert_equal true, process_failure_called
    assert_includes stdout.string, "Connecting to Vike web app: attempt 1"
    assert_equal "", stderr.string
  end

  def test_returns_true_when_http_becomes_reachable
    stdout = StringIO.new
    stderr = StringIO.new

    check = ProductTemplates::Validation::VikeAppReachabilityCheck.new(
      url: "http://127.0.0.1:3000",
      timeout_seconds: 1,
      poll_interval_seconds: 0,
      stdout: stdout,
      stderr: stderr
    )

    check.stubs(:http_ok?).returns(true)

    assert_equal true, check.call
    assert_includes stdout.string, "[ok] vike dev reachable: http://127.0.0.1:3000"
    assert_equal "", stderr.string
  end
end
