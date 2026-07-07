# frozen_string_literal: true

require_relative "base"

module Workspace
  module Secrets
    module Adapters
      class Env < Base
        def read(key)
          ENV[key]
        end

        def available?
          true
        end

        def writable?
          false
        end

        def name
          "environment variable"
        end
      end
    end
  end
end