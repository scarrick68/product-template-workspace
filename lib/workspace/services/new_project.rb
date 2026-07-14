#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "../../workspace"
require_relative "../context"
require_relative "template_workspace_generator"
require_relative "init_new_project"

module Workspace
  module Services
    class NewProject
      def initialize(argv, stdin: $stdin, stdout: $stdout)
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
      end

      def call
        options = parse_options
        return 1 unless options

        slug = options[:product_slug]
        return usage unless valid_slug?(slug)

        source_context = Workspace::Context.new(root: Workspace::ROOT)
        source_root = source_context.root
        destination_root = File.expand_path(options[:destination] || default_destination_for(slug))

        return 1 unless validate_destination!(source_root, destination_root)

        Workspace.section("New Project: Copy And Initialize")
        Workspace.info("Source workspace: #{source_root}")
        Workspace.info("Destination workspace: #{destination_root}")

        generator = TemplateWorkspaceGenerator.new(
          source_root: source_root,
          destination_root: destination_root
        )
        generator.call

        # Call InitNewProject with the context of the new destination workspace
        # This ensures that the initialization is done in the new app instance and
        # not in the original template workspace.
        destination_context = Workspace::Context.new(root: destination_root)
        init_args = [slug] + options[:forwarded_args]

        InitNewProject.new(
          init_args,
          stdin: stdin,
          stdout: stdout,
          context: destination_context
        ).call
      end

      private

      attr_reader :argv, :stdin, :stdout

      def parse_options
        options = {
          destination: nil,
          forwarded_args: []
        }

        args = argv.dup

        parser = OptionParser.new do |opts|
          opts.on("--destination PATH", "--dest PATH", "Path for generated workspace copy") do |path|
            options[:destination] = path
          end

          opts.on("-h", "--help", "Show usage") do
            return nil
          end
        end

        parser.order!(args)

        options[:product_slug] = args.shift
        options[:forwarded_args] = args

        options
      rescue OptionParser::ParseError => e
        Workspace.fail_with_help(
          "Invalid new_project options.",
          details: e.message,
          fixes: [
            "Usage: bin/new_project [--destination PATH] <product-slug> -- [init_new_project flags...]",
            "Example: bin/new_project --destination ~/Code/my-super-app my-super-app -- --no-dev"
          ]
        )
        nil
      end

      def valid_slug?(value)
        value.to_s.match?(/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/)
      end

      def default_destination_for(slug)
        File.join(File.dirname(Workspace::ROOT), slug)
      end

      def validate_destination!(source_root, destination_root)
        if destination_root == source_root
          Workspace.fail_with_help(
            "Destination must be different from the original cloned template workspace.",
            details: "Source and destination are both #{source_root}",
            fixes: [
              "Choose a different destination path with --destination.",
              "Example: bin/new_project my-super-app --destination ~/Code/my-super-app"
            ]
          )
          return false
        end

        if destination_root.start_with?("#{source_root}/")
          Workspace.fail_with_help(
            "Destination cannot be nested inside the template workspace.",
            details: "Destination: #{destination_root}",
            fixes: [
              "Use a sibling or external destination path.",
              "Example: --destination ~/Code/my-super-app"
            ]
          )
          return false
        end

        return true unless File.exist?(destination_root)

        Workspace.fail_with_help(
          "Destination already exists.",
          details: "Refusing to overwrite existing path: #{destination_root}",
          fixes: [
            "Choose a new destination path.",
            "Remove the existing path only if you are sure it is safe."
          ]
        )
        false
      end

      def usage
        Workspace.fail_with_help(
          "Missing or invalid product slug.",
          details: "Usage: bin/new_project [--destination PATH] <product-slug> -- [init_new_project flags...]",
          fixes: [
            "Use kebab-case product slug (example: my-super-app).",
            "Run: bin/new_project my-super-app",
            "Optionally set destination: bin/new_project --destination ~/Code/my-super-app my-super-app",
            "Forward flags to init_new_project after --, for example: -- --no-dev"
          ]
        )
        1
      end
    end
  end
end
