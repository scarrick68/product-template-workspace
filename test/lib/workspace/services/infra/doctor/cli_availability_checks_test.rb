# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/cli_availability_checks"

class DoctorCliAvailabilityChecksTest < Minitest::Test
  def test_to_a_builds_expected_labels
    checks = Workspace::Services::Infra::Doctor::CliAvailabilityChecks.new.to_a

    assert_equal [
      "Terraform/OpenTofu CLI",
      "doctl CLI",
      "GitHub CLI",
      "git CLI"
    ], checks.map(&:label)
  end

  def test_check_call_reports_available_command
    check = Workspace::Services::Infra::Doctor::CliAvailabilityChecks.new.to_a.first

    Workspace.expects(:command_exists?).with("terraform").returns(true)
    Workspace.expects(:ok).with("Terraform/OpenTofu: terraform")
    Workspace.expects(:fail).never

    assert_equal true, check.call
  end

  def test_check_call_reports_missing_commands
    check = Workspace::Services::Infra::Doctor::CliAvailabilityChecks.new.to_a.first

    Workspace.expects(:command_exists?).with("terraform").returns(false)
    Workspace.expects(:command_exists?).with("tofu").returns(false)
    Workspace.expects(:fail).with("Terraform/OpenTofu: missing (checked terraform, tofu)")
    Workspace.expects(:ok).never

    assert_equal false, check.call
  end
end
