#!/usr/bin/env ruby
# frozen_string_literal: true

module Workspace
  module CLI
    class UserPrompt
      TRUE_VALUES = %w[y yes true 1].freeze
      FALSE_VALUES = %w[n no false 0].freeze

      def initialize(input: $stdin, output: $stdout)
        @input = input
        @output = output
      end

      def for_value(prompt_message, default: nil, hint: nil)
        print_hint(hint)
        output.print("#{prompt_message}#{default_suffix(default)}: ")

        entered = input.gets&.strip
        entered.nil? || entered.empty? ? default : entered
      end

      def yes_no(question, default: false, hint: nil)
        print_hint(hint)

        indicator = default ? "Y/n" : "y/N"
        output.print("#{question} [#{indicator}]: ")

        normalize_bool(input.gets, default:)
      end

      private

      attr_reader :input, :output

      def normalize_bool(value, default:)
        normalized = value.to_s.strip.downcase

        return default if normalized.empty?
        return true if TRUE_VALUES.include?(normalized)
        return false if FALSE_VALUES.include?(normalized)

        default
      end

      def print_hint(hint)
        output.puts("  Hint: #{hint}") unless hint.to_s.empty?
      end

      def default_suffix(default)
        default.to_s.empty? ? "" : " [#{default}]"
      end
    end
  end
end