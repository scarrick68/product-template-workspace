# frozen_string_literal: true

require "stringio"

require_relative "../../test_helper"
require_relative "../../../lib/workspace/cli_prompt"

class CliPromptTest < Minitest::Test
  def test_value_returns_default_for_blank_input
    prompt = Workspace::CliPrompt.new(
      stdin: StringIO.new("\n"),
      stdout: StringIO.new
    )

    value = prompt.value("label", default: "default")

    assert_equal "default", value
  end

  def test_value_returns_input_when_provided
    prompt = Workspace::CliPrompt.new(
      stdin: StringIO.new("custom\n"),
      stdout: StringIO.new
    )

    value = prompt.value("label", default: "default")

    assert_equal "custom", value
  end

  def test_bool_returns_default_for_blank_input
    prompt = Workspace::CliPrompt.new(
      stdin: StringIO.new("\n"),
      stdout: StringIO.new
    )

    value = prompt.bool("enabled", default: true)

    assert_equal true, value
  end

  def test_bool_reprompts_until_valid
    output = StringIO.new
    prompt = Workspace::CliPrompt.new(
      stdin: StringIO.new("maybe\nno\n"),
      stdout: output
    )

    value = prompt.bool("enabled", default: true)

    assert_equal false, value
    assert_includes output.string, "Invalid input 'maybe'"
    assert_includes output.string, "Accepted values"
  end

  def test_enum_reprompts_until_valid
    output = StringIO.new
    prompt = Workspace::CliPrompt.new(
      stdin: StringIO.new("bogus\naws_s3\n"),
      stdout: output
    )

    value = prompt.enum(
      "provider",
      default: "digitalocean_spaces",
      hint: "pick one",
      valid_values: %w[digitalocean_spaces aws_s3]
    )

    assert_equal "aws_s3", value
    assert_includes output.string, "Invalid input 'bogus'"
    assert_includes output.string, "Valid values: digitalocean_spaces, aws_s3"
  end
end
