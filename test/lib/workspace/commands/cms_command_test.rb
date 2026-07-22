# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/cms"

class CmsCommandTest < Minitest::Test
  def test_add_uses_keystatic_provider_by_default
    installer = mock("cms_installer")
    installer.expects(:call).with(provider: "keystatic").returns(0)

    command = Workspace::Commands::Cms.new(["add"])
    command.stubs(:cms_installer).returns(installer)

    assert_equal 0, command.call
  end

  def test_add_rejects_default_none_provider
    Workspace.expects(:fail_with_help).with(
      "No CMS provider selected for add.",
      has_entry(details: "--provider=none does not install any CMS feature.")
    )

    command = Workspace::Commands::Cms.new(["add", "--provider=none"])

    assert_equal 1, command.call
  end

  def test_remove_subcommand_is_not_supported
    stderr = StringIO.new
    command = Workspace::Commands::Cms.new(["remove"], stderr: stderr)

    assert_equal 1, command.call
    assert_includes stderr.string, "Usage: bin/workspace cms <add> [options]"
  end
end