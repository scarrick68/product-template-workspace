# frozen_string_literal: true

require_relative "base"

module Workspace
  module Secrets
    module Adapters
      # Stub adapter for platforms without implemented keychain integration.
      class UnsupportedKeychain < Base
        def available?
          true
        end

        def name
          "unsupported OS keychain"
        end

        def warning
          "Persistent OS keychain storage is not yet supported on this platform. You can set DIGITALOCEAN_ACCESS_TOKEN or use the token for this script run only."
        end
      end
    end
  end
end