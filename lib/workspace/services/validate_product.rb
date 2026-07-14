#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../workspace"
require_relative "../context"
require_relative "../../product_templates/validator"

module Workspace
  module Services
    # Validates a renamed product workspace by delegating to the product validator workflow.
    class ValidateProduct
      def initialize(argv, context: Workspace::Context.new(root: Workspace::ROOT))
        @argv = argv
        @context = context
      end

      def call
        product_slug = argv.first.to_s.strip
        return usage unless product_slug && !product_slug.empty?

        ProductTemplates::Validator.new(
          product_slug,
          workspace_root: context.root,
          repositories: Workspace.repositories(context: context)
        ).call
      end

      private

      attr_reader :argv, :context

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
