# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../services/infra/provision_infra"

module Workspace
  module Commands
    class Infra
      class SafeDestroy
        def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
          @argv = argv.dup
          @stdin = stdin
          @stdout = stdout
          @stderr = stderr
        end

        def call
          Workspace::Services::Infra::ProvisionInfra.new(["safe_destroy"] + argv, stdin: stdin, stdout: stdout).call
        end

        private

        attr_reader :argv, :stdin, :stdout, :stderr
      end
    end
  end
end
