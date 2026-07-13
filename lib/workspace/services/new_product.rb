#!/usr/bin/env ruby
# frozen_string_literal: true
# Runs template-to-product rename flow for API and web repositories.

require_relative "../../workspace"
require_relative "../../product_templates/renamer"

module Workspace
  module Services
    class NewProduct
      def initialize(argv)
        @argv = argv
      end

      def call
        product_slug = argv.first.to_s.strip
        return usage unless product_slug && !product_slug.empty?

        # At the moment, this command is a thin wrapper around the product renamer workflow. 
        # In the future, we may add additional steps as needed.
        ProductTemplates::Renamer.new(product_slug).call
      end

      private

      attr_reader :argv

      def usage
        Workspace.fail_with_help(
          "Missing product name.",
          details: "Usage: bin/new_product <product-slug>",
          fixes: [
            "Use kebab-case product slug (example: my-super-app).",
            "Command example: bin/new_product my-super-app"
          ]
        )
        1
      end
    end
  end
end
