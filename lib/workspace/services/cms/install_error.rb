# frozen_string_literal: true

module Workspace
  module Services
    module Cms
      class InstallError < StandardError
        attr_reader :details, :fixes

        def initialize(message, details: nil, fixes: [])
          super(message)
          @details = details
          @fixes = fixes
        end
      end
    end
  end
end
