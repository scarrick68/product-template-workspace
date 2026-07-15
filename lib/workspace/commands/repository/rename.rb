# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../services/rename_product_command"

module Workspace
  module Commands
    class Repository
      class Rename
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr, context: Workspace::Context.new(root: Workspace::ROOT))
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
          @context = context
        end

        def call
          Workspace::Services::RenameProductCommand.new(argv, context: context).call
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr, :context
      end
    end
  end
end
