# frozen_string_literal: true

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/command_line_options"

class InfraCommandLineOptionsTest < Minitest::Test
  def test_parse_apply_defaults_without_first_deploy_setup
    result = Workspace::Services::Infra::CommandLineOptions.parse(["apply"])

    assert result.valid?
    assert_equal "apply", result.action
    assert_equal "production", result.environment
    assert_equal false, result.first_deploy_setup
  end

  def test_parse_apply_with_first_deploy_setup_flag
    result = Workspace::Services::Infra::CommandLineOptions.parse(["apply", "production", "--first-deploy-setup"])

    assert result.valid?
    assert_equal "apply", result.action
    assert_equal "production", result.environment
    assert_equal true, result.first_deploy_setup
  end

  def test_parse_apply_with_only_first_deploy_setup_flag_uses_default_environment
    result = Workspace::Services::Infra::CommandLineOptions.parse(["apply", "--first-deploy-setup"])

    assert result.valid?
    assert_equal "apply", result.action
    assert_equal "production", result.environment
    assert_equal true, result.first_deploy_setup
  end

  def test_first_deploy_setup_flag_is_rejected_for_non_apply_actions
    result = Workspace::Services::Infra::CommandLineOptions.parse(["plan", "production", "--first-deploy-setup"])

    refute result.valid?
    assert_equal 1, result.exit_code
  end
end
