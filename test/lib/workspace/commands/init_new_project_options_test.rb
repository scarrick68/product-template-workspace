# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/init_new_project_options"

class InitNewProjectOptionsTest < Minitest::Test
  def test_parses_defaults_for_valid_slug
    options = Workspace::Services::InitNewProjectOptions.parse(["my-super-app"], stdout: StringIO.new)

    assert options.valid?
    assert_equal "my-super-app", options.product_slug
    assert_equal false, options.no_dev?
    assert_equal false, options.skip_setup_tools?
    assert_equal false, options.assume_repos_ready?
    assert_equal false, options.create_remotes?
    assert_equal true, options.push_after_setup?
    assert_equal "none", options.cms_provider
    assert_equal false, options.cms_enabled?
  end

  def test_parses_keystatic_cms_provider
    options = Workspace::Services::InitNewProjectOptions.parse(["my-super-app", "--cms=keystatic"], stdout: StringIO.new)

    assert options.valid?
    assert_equal "keystatic", options.cms_provider
    assert_equal true, options.cms_enabled?
    assert_equal true, options.cms_provider_explicit?
  end

  def test_parses_with_cms_alias
    options = Workspace::Services::InitNewProjectOptions.parse(["my-super-app", "--with-cms"], stdout: StringIO.new)

    assert options.valid?
    assert_equal "keystatic", options.cms_provider
    assert_equal true, options.cms_enabled?
  end

  def test_reports_invalid_for_unsupported_cms_provider
    options = Workspace::Services::InitNewProjectOptions.parse(["my-super-app", "--cms=sanity"], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Unsupported CMS provider.", options.failure_summary
  end

  def test_reports_invalid_when_slug_missing
    options = Workspace::Services::InitNewProjectOptions.parse([], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Missing or invalid product slug.", options.failure_summary
  end

  def test_reports_invalid_for_conflicting_visibility_flags
    options = Workspace::Services::InitNewProjectOptions.parse(["my-super-app", "--public", "--private"], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Conflicting visibility flags.", options.failure_summary
  end

  def test_reports_invalid_for_multiple_positional_args
    options = Workspace::Services::InitNewProjectOptions.parse(["my-super-app", "extra"], stdout: StringIO.new)

    assert_equal false, options.valid?
    assert_equal "Too many positional arguments.", options.failure_summary
  end

  def test_help_requested_prints_usage_and_is_not_valid
    output = StringIO.new
    options = Workspace::Services::InitNewProjectOptions.parse(["--help"], stdout: output)

    assert_equal true, options.help_requested?
    assert_equal false, options.valid?
    assert_includes output.string, "Usage:"
  end
end