# frozen_string_literal: true

module ProductTemplates
  module Validation
    Check = Data.define(:name, :command, :directory, :directory_label)
  end
end
