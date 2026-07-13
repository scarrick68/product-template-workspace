#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"

module Workspace
  module Commands
    class InitNewProjectOptions
      USAGE_TEXT = "bin/init_new_project <product-slug> [--no-dev] [--skip-setup-tools] [--assume-repos-ready] [--create-remotes] [--public|--private] [--push|--no-push]".freeze

      attr_reader :product_slug, :visibility, :failure_summary, :failure_details, :failure_fixes

      def self.parse(argv, stdout: $stdout)
        new(argv: argv, stdout: stdout).parse
      end

      def initialize(argv:, stdout:)
        @argv = argv.dup
        @stdout = stdout

        # Final parsed values exposed via readers/predicate methods.
        @product_slug = nil
        @no_dev = false
        @skip_setup_tools = false
        @assume_repos_ready = false
        @create_remotes = false
        @create_remotes_explicit = false
        @visibility = nil
        @push_after_setup = true
        @push_explicit = false
        @help_requested = false

        # Internal parse markers used to detect mutually exclusive flag combinations.
        @saw_public = false
        @saw_private = false
        @saw_push = false
        @saw_no_push = false

        # Validation failure payload consumed by the calling command for user-facing errors.
        @failure_summary = nil
        @failure_details = nil
        @failure_fixes = []
      end

      def parse
        parser = option_parser

        begin
          parser.parse!(argv)
        rescue OptionParser::ParseError => e
          set_failure(
            "Invalid arguments.",
            details: e.message,
            fixes: ["Run: bin/init_new_project --help"]
          )
          return self
        end

        return self if help_requested?

        return self unless assign_product_slug
        return self unless validate_option_combinations

        validate_slug
        self
      end

      def help_requested?
        @help_requested
      end

      def valid?
        !help_requested? && failure_summary.nil?
      end

      def no_dev?
        @no_dev
      end

      def skip_setup_tools?
        @skip_setup_tools
      end

      def assume_repos_ready?
        @assume_repos_ready
      end

      def create_remotes?
        @create_remotes
      end

      def create_remotes_explicit?
        @create_remotes_explicit
      end

      def push_after_setup?
        @push_after_setup
      end

      def push_explicit?
        @push_explicit
      end

      private

      attr_reader :argv, :stdout

      def option_parser
        OptionParser.new do |opts|
          opts.banner = "Usage: #{USAGE_TEXT}"

          opts.on("--no-dev", "Skip launching dev services after setup") { @no_dev = true }
          opts.on("--skip-setup-tools", "Skip guided installs/auth prompts") { @skip_setup_tools = true }
          opts.on("--assume-repos-ready", "Assume remote repositories already exist") { @assume_repos_ready = true }

          opts.on("--create-remotes", "Automatically create backend/frontend remotes") do
            @create_remotes = true
            @create_remotes_explicit = true
          end

          opts.on("--public", "Create remotes as public repositories") do
            @saw_public = true
            @create_remotes = true
            @create_remotes_explicit = true
            @visibility = "public"
          end

          opts.on("--private", "Create remotes as private repositories") do
            @saw_private = true
            @create_remotes = true
            @create_remotes_explicit = true
            @visibility = "private"
          end

          opts.on("--no-push", "Do not push repositories after remote setup") do
            @saw_no_push = true
            @push_after_setup = false
            @push_explicit = true
          end

          opts.on("--push", "Push repositories after remote setup") do
            @saw_push = true
            @push_after_setup = true
            @push_explicit = true
          end

          opts.on("-h", "--help", "Show help") do
            stdout.puts(opts)
            @help_requested = true
          end
        end
      end

      def assign_product_slug
        if argv.empty?
          set_failure(
            "Missing or invalid product slug.",
            details: "Usage: #{USAGE_TEXT}",
            fixes: common_slug_fixes
          )
          return false
        end

        if argv.length > 1
          set_failure(
            "Too many positional arguments.",
            details: "Expected exactly one <product-slug>, got: #{argv.join(' ')}",
            fixes: ["Run: #{USAGE_TEXT}"]
          )
          return false
        end

        @product_slug = argv.first
        true
      end

      def validate_option_combinations
        if @saw_public && @saw_private
          set_failure(
            "Conflicting visibility flags.",
            details: "Use either --public or --private, not both.",
            fixes: ["Choose one visibility option and rerun the command."]
          )
          return false
        end

        if @saw_push && @saw_no_push
          set_failure(
            "Conflicting push flags.",
            details: "Use either --push or --no-push, not both.",
            fixes: ["Choose one push option and rerun the command."]
          )
          return false
        end

        true
      end

      def validate_slug
        return if product_slug.to_s.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)

        set_failure(
          "Missing or invalid product slug.",
          details: "Usage: #{USAGE_TEXT}",
          fixes: common_slug_fixes
        )
      end

      def set_failure(summary, details:, fixes:)
        @failure_summary = summary
        @failure_details = details
        @failure_fixes = fixes
      end

      def common_slug_fixes
        [
          "Use kebab-case product slug (example: my-super-app).",
          "Run: bin/init_new_project my-super-app",
          "Use --no-dev if you want setup without launching long-running services.",
          "Use --skip-setup-tools if your machine is already configured and you want to skip guided installs/auth prompts.",
          "Use --assume-repos-ready if remote backend/frontend repos are already created.",
          "Use --create-remotes to create backend/frontend GitHub repositories automatically."
        ]
      end
    end
  end
end