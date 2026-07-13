# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/cli/user_prompt"

class WorkspaceCliUserPromptTest < Minitest::Test
  def test_value_returns_entered_text
    input = StringIO.new("hello\n")
    output = StringIO.new
    prompt = Workspace::CLI::UserPrompt.new(input: input, output: output)

    assert_equal "hello", prompt.for_value("name")
  end

  def test_value_returns_default_for_blank_input
    input = StringIO.new("\n")
    output = StringIO.new
    prompt = Workspace::CLI::UserPrompt.new(input: input, output: output)

    assert_equal "fallback", prompt.for_value("name", default: "fallback")
  end

  def test_yes_no_normalizes_true_and_false_values
    prompt = Workspace::CLI::UserPrompt.new(input: StringIO.new, output: StringIO.new)

    assert_equal true, prompt.send(:normalize_bool, "yes", default: false)
    assert_equal true, prompt.send(:normalize_bool, "1", default: false)
    assert_equal false, prompt.send(:normalize_bool, "no", default: true)
    assert_equal false, prompt.send(:normalize_bool, "0", default: true)
  end

  def test_yes_no_returns_default_for_unknown_value
    prompt = Workspace::CLI::UserPrompt.new(input: StringIO.new, output: StringIO.new)

    assert_equal true, prompt.send(:normalize_bool, "maybe", default: true)
    assert_equal false, prompt.send(:normalize_bool, "maybe", default: false)
  end

  def test_yes_no_uses_default_on_blank_input
    input = StringIO.new("\n")
    output = StringIO.new
    prompt = Workspace::CLI::UserPrompt.new(input: input, output: output)

    assert_equal true, prompt.yes_no("Proceed?", default: true)
  end

  def test_yes_no_returns_false_when_no_is_entered
    input = StringIO.new("no\n")
    output = StringIO.new
    prompt = Workspace::CLI::UserPrompt.new(input: input, output: output)

    assert_equal false, prompt.yes_no("Proceed?", default: true)
  end

  def test_value_writes_hint_when_provided
    input = StringIO.new("\n")
    output = StringIO.new
    prompt = Workspace::CLI::UserPrompt.new(input: input, output: output)

    prompt.for_value("name", default: "fallback", hint: "Used for display")

    assert_includes output.string, "Hint: Used for display"
  end
end
