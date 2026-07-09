# frozen_string_literal: true

module Workspace
  module Secrets
    module Adapters
      # Defines the adapter interface used by secret stores and resolvers.
      class Base
        def available?
          false
        end

        def read(_key)
          nil
        end

        def write(_key, _value)
          raise NotImplementedError
        end

        def writable?
          false
        end

        def name
          self.class.name
        end
      end
    end
  end
end