# frozen_string_literal: true

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/prod_local"

class ProdLocalTest < Minitest::Test
  def setup
    @service = Workspace::Services::ProdLocal.new([])
    @api_repo = File.join(Workspace::ROOT, "repos", "api-template")
  end

  def test_returns_usage_for_extra_arguments
    service = Workspace::Services::ProdLocal.new(["unexpected"])

    service.expects(:puts).with("Usage: bin/workspace prod-local")

    exit_code = service.call

    assert_equal 1, exit_code
  end

  def test_aborts_when_backend_repo_directory_is_missing
    Workspace.stubs(:section)
    Workspace.stubs(:repositories).returns([{ "purpose" => "backend-api", "path" => "repos/api-template" }])
    File.stubs(:directory?).returns(false)

    Workspace.expects(:fail_with_help).with(
      "Backend repository path is missing.",
      includes(:details, :fixes)
    )

    exit_code = @service.call

    assert_equal 1, exit_code
  end

  def test_delegates_to_api_template_bin_prod_local
    Workspace.stubs(:section)
    Workspace.stubs(:repositories).returns([{ "purpose" => "backend-api", "path" => "repos/api-template" }])
    File.stubs(:directory?).returns(true)
    File.stubs(:executable?).with(File.join(@api_repo, "bin", "prod-local")).returns(true)
    Workspace.expects(:info).with("Delegating to #{File.join(@api_repo, 'bin', 'prod-local')}")

    @service.expects(:exec).with("bin/prod-local", chdir: @api_repo)

    @service.call
  end
end
