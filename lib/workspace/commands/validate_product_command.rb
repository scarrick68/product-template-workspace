#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../workspace"
require_relative "../../product_templates/validator"

module Workspace
  module Commands
    # Validates a renamed product workspace by delegating to the product validator workflow.
    class ValidateProductCommand
      def initialize(argv)
        @argv = argv
      end

      def call
        product_slug = argv.first.to_s.strip
        return usage unless product_slug && !product_slug.empty?

        ProductTemplates::Validator.new(product_slug).call
      end

      private

      attr_reader :argv

      def usage
        Workspace.fail_with_help(
          "Missing product name.",
          details: "Usage: bin/validate_product <product-slug>",
          fixes: [
            "Use kebab-case product slug (example: my-super-app).",
            "Command example: bin/validate_product my-super-app"
          ]
        )
        1
      end
    end
  end
end
