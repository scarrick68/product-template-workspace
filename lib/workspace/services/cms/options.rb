# frozen_string_literal: true

module Workspace
  module Services
    module Cms
      module Options
        SUPPORTED_PROVIDERS = %w[none keystatic].freeze
        DEFAULT_PROVIDER = "none"
        WITH_CMS_PROVIDER = "keystatic"

        module_function

        def normalize(provider)
          provider.to_s.strip.downcase
        end

        def disabled?(provider)
          normalize(provider) == DEFAULT_PROVIDER
        end

        def supported_provider?(provider)
          SUPPORTED_PROVIDERS.include?(normalize(provider))
        end
      end
    end
  end
end
