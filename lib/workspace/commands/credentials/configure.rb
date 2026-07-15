# frozen_string_literal: true

require_relative "../../../workspace"

module Workspace
  module Commands
    class Credentials
      class Configure
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
        end

        def call
          Workspace.fail_with_help(
            "Credentials configure is not implemented yet.",
            details: "Use credentials init for now.",
            fixes: ["Run: bin/workspace credentials init"]
          )
          1
        end
      end
    end
  end
end
