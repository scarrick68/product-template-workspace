# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../services/init_new_project"

module Workspace
  module Commands
    class Repository
      class Setup
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr, context: Workspace::Context.new(root: Workspace::ROOT))
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
          @context = context
        end

        def call
          Workspace::Services::InitNewProject.new(argv, stdin: stdin, stdout: stdout, context: context).call
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr, :context
      end
    end
  end
end
