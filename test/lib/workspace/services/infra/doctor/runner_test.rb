# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/runner"

class DoctorRunnerTest < Minitest::Test
  def test_call_returns_zero_when_all_checks_pass
    check_1 = Struct.new(:label) { def call = true }.new("check-1")
    check_2 = Struct.new(:label) { def call = true }.new("check-2")

    Workspace.expects(:ok).with("infra doctor checks passed")
    Workspace.expects(:info).never
    Workspace.expects(:fail).never

    result = Workspace::Services::Infra::Doctor::Runner.new(checks: [check_1, check_2]).call

    assert_equal 0, result
  end

  def test_call_returns_one_and_reports_failed_labels
    passing = Struct.new(:label) { def call = true }.new("passing")
    failing = Struct.new(:label) { def call = false }.new("failing")

    Workspace.expects(:info).with("infra doctor failed checks: failing")
    Workspace.expects(:fail).with("infra doctor detected one or more issues")
    Workspace.expects(:ok).never

    result = Workspace::Services::Infra::Doctor::Runner.new(checks: [passing, failing]).call

    assert_equal 1, result
  end
end
