#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for running workspace tests with a single entrypoint.

require "fileutils"
require "open3"
require_relative "../../workspace"

module Workspace
  module Services
    class Test
      def initialize(argv)
        @argv = argv
      end

      def call
        test_files = resolve_test_files
        return 1 if test_files.empty?

        Workspace.ok("running #{test_files.length} test file(s)")
        run_with_log(test_files)
      end

      private

      attr_reader :argv

      def resolve_test_files
        files = if argv.empty?
                  Dir.glob(File.join(Workspace::ROOT, "test", "**", "*_test.rb")).sort
                else
                  argv.flat_map { |target| expand_target(target) }.uniq.sort
                end

        return files unless files.empty?

        Workspace.fail_with_help(
          "No test files were found.",
          details: "Searched for Ruby test files matching *_test.rb under test/.",
          assumptions: [
            "Tests follow the naming convention *_test.rb.",
            "Provided paths or patterns should resolve within the workspace."
          ],
          fixes: [
            "Run without arguments to discover all tests: bin/test",
            "Pass a specific file or folder under test/, for example: bin/test test/lib/workspace/services",
            "Ensure test files end with _test.rb."
          ]
        )

        []
      end

      def expand_target(target)
        absolute_target = absolute_path(target)

        return Dir.glob(File.join(absolute_target, "**", "*_test.rb")) if File.directory?(absolute_target)
        return [absolute_target] if File.file?(absolute_target)

        Dir.glob(absolute_path_glob(target))
      end

      def ruby_test_command(test_files)
        [
          "bundle",
          "exec",
          "ruby",
          "-Itest",
          "-e",
          "ARGV.each { |file| require File.expand_path(file) }",
          *relative_paths(test_files)
        ]
      end

      def run_with_log(test_files)
        FileUtils.mkdir_p(File.join(Workspace::ROOT, "tmp"))
        output, status = Open3.capture2e(*ruby_test_command(test_files), chdir: Workspace::ROOT)

        File.write(log_path, output)

        summary = extract_summary(output)
        if status.success?
          Workspace.ok(summary || "tests passed")
          return 0
        end

        Workspace.fail("tests failed")
        Workspace.info(summary) if summary
        Workspace.info("full log: #{relative_log_path}")
        excerpt = failure_excerpt(output)
        puts excerpt unless excerpt.empty?
        1
      end

      def extract_summary(output)
        output.lines.reverse_each do |line|
          clean = line.strip
          next unless clean.match?(/\A\d+ runs, \d+ assertions, \d+ failures, \d+ errors, \d+ skips\z/)

          return clean
        end

        nil
      end

      def failure_excerpt(output)
        lines = output.lines
        summary_index = lines.rindex { |line| line.include?("runs,") && line.include?("assertions,") }
        start_index = lines.rindex { |line| line.match?(/^\s*\d+\)\s+(Failure|Error):/) }

        return lines.last(40).join if start_index.nil?

        end_index = summary_index ? [summary_index + 1, lines.length].min : lines.length
        lines[start_index...end_index].join
      end

      def log_path
        File.join(Workspace::ROOT, relative_log_path)
      end

      def relative_log_path
        File.join("tmp", "test.log")
      end

      def relative_paths(paths)
        paths.map { |path| path.sub("#{Workspace::ROOT}/", "") }
      end

      def absolute_path(path)
        return path if path.start_with?("/")

        File.join(Workspace::ROOT, path)
      end

      def absolute_path_glob(pattern)
        return pattern if pattern.start_with?("/")

        File.join(Workspace::ROOT, pattern)
      end
    end
  end
end
