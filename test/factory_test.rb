# frozen_string_literal: true

require_relative "test_helper"

class FactoryTest < Minitest::Test
  def test_all_factories_can_be_built
    FactoryBot.factories.each do |factory|
      build(factory.name)
    end
  end
end
