# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../services/validate_product"

module Workspace
  module Commands
    class Repository
      class Verify
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr, context: Workspace::Context.new(root: Workspace::ROOT))
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
          @context = context
        end

        def call
          Workspace::Services::ValidateProduct.new(argv, context: context, stdin: stdin, stdout: stdout).call
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr, :context
      end
    end
  end
end
