# frozen_string_literal: true

module Workspace
  module Secrets
    # Value object for secret lookup outcomes and source attribution.
    class Result
      attr_reader :value, :source

      def initialize(value:, source:)
        @value = value
        @source = source
      end

      def found?
        !@value.to_s.strip.empty?
      end
    end
  end
end