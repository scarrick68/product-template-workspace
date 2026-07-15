# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../services/init_workspace_credentials_files"

module Workspace
  module Commands
    class Credentials
      class Init
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
        end

        def call
          return usage unless argv.empty?

          Workspace::Services::InitWorkspaceCredentialsFiles.new.call
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr

        def usage
          stderr.puts("Usage: bin/workspace credentials init")
          1
        end
      end
    end
  end
end
