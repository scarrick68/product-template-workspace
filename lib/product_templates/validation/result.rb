# frozen_string_literal: true

module ProductTemplates
  module Validation
    Result = Data.define(:name, :passed, :note) do
      alias_method :passed?, :passed
    end
  end
end
