# frozen_string_literal: true

require_relative "../../workspace"
require_relative "../services/new_project"

module Workspace
  module Commands
    class NewProject
      def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
      end

      def call
        Workspace::Services::NewProject.new(argv, stdin: stdin, stdout: stdout).call
      end

      private

      attr_reader :argv, :stdin, :stdout, :stderr
    end
  end
end
