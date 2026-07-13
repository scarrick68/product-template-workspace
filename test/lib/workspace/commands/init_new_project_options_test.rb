# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/init_new_project_options"

class InitNewProjectOptionsTest < Minitest::Test
  def test_parses_defaults_for_valid_slug
    options = Workspace::Commands::InitNewProjectOptions.parse(["my-super-app"], stdout: StringIO.new)

    assert options.valid?
    assert_equal "my-super-app", options.product_slug
    assert_equal false, options.no_dev?
    assert_equal false, options.skip_setup_tools?
    assert_equal false, options.assume_repos_ready?
    assert_equal false, options.create_remotes?
    assert_equal true, options.push_after_setup?
  end

  def test_reports_invalid_when_slug_missing
    options = Workspace::Commands::InitNewProjectOptions.parse([], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Missing or invalid product slug.", options.failure_summary
  end

  def test_reports_invalid_for_conflicting_visibility_flags
    options = Workspace::Commands::InitNewProjectOptions.parse(["my-super-app", "--public", "--private"], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Conflicting visibility flags.", options.failure_summary
  end

  def test_reports_invalid_for_multiple_positional_args
    options = Workspace::Commands::InitNewProjectOptions.parse(["my-super-app", "extra"], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Too many positional arguments.", options.failure_summary
  end

  def test_help_requested_prints_usage_and_is_not_valid
    output = StringIO.new
    options = Workspace::Commands::InitNewProjectOptions.parse(["--help"], stdout: output)

    assert_equal true, options.help_requested?
    assert_equal false, options.valid?
    assert_includes output.string, "Usage:"
  end
end