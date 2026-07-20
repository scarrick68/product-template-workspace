# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/prod_local"

class ProdLocalCommandTest < Minitest::Test
  def test_delegates_to_prod_local_service
    service = mock("prod_local_service")
    Workspace::Services::ProdLocal.expects(:new).with([]).returns(service)
    service.expects(:call).returns(0)

    exit_code = Workspace::Commands::ProdLocal.new([]).call

    assert_equal 0, exit_code
  end
end
