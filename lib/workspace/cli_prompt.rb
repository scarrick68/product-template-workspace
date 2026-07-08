# frozen_string_literal: true

module Workspace
  class CliPrompt
    TRUE_VALUES = %w[y yes true 1].freeze
    FALSE_VALUES = %w[n no false 0].freeze

    def initialize(stdin: $stdin, stdout: $stdout)
      @stdin = stdin
      @stdout = stdout
    end

    def value(label, default: nil, hint: nil)
      print_hint(hint)
      print_prompt(label, default: default)

      input = stdin.gets&.strip
      return default if input.nil? || input.empty?

      input
    end

    def bool(label, default:, hint: nil, require_input: false, no_input_value: nil)
      validated(
        label,
        default: default,
        hint: hint,
        default_hint: default ? "Y/n" : "y/N",
        valid_values: TRUE_VALUES + FALSE_VALUES,
        invalid_message: "Use one of: #{(TRUE_VALUES + FALSE_VALUES).join(', ')}",
        require_input: require_input,
        no_input_value: no_input_value
      ) do |input|
        return true if TRUE_VALUES.include?(input)
        return false if FALSE_VALUES.include?(input)

        nil
      end
    end

    def enum(label, default:, hint:, valid_values:)
      validated(
        label,
        default: default,
        hint: hint,
        default_hint: nil,
        valid_values: valid_values,
        invalid_message: "Valid values: #{valid_values.join(', ')}",
        require_input: false,
        no_input_value: nil
      ) do |input|
        valid_values.include?(input) ? input : nil
      end
    end

    private

    attr_reader :stdin, :stdout

    def validated(label, default:, hint:, default_hint:, valid_values:, invalid_message:, require_input:, no_input_value:)
      loop do
        print_hint(hint)
        print_prompt(label, default: default, default_hint: default_hint)

        raw_input = stdin.gets
        return no_input_value if raw_input.nil? && require_input
        return default if raw_input.nil?

        input = raw_input.strip
        return default if input.empty?

        normalized = input.downcase
        value = yield(normalized)
        return value unless value.nil?

        stdout.puts("  Invalid input '#{input}'. #{invalid_message}")
        stdout.puts("  Accepted values: #{valid_values.join(', ')}")
      end
    end

    def print_hint(hint)
      stdout.puts("  Hint: #{hint}") unless hint.nil? || hint.empty?
    end

    def print_prompt(label, default:, default_hint: nil)
      default_text = default.nil? || default.to_s.empty? ? "" : " [#{default}]"
      suffix = default_hint.nil? || default_hint.empty? ? "" : " (#{default_hint})"
      stdout.puts
      stdout.puts("#{Workspace.styled_label('INPUT', color: :magenta)} User action required")
      stdout.print("#{label}#{suffix}#{default_text}: ")
    end
  end
end