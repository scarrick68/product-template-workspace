# frozen_string_literal: true

require_relative "../../../../../test_helper"
require_relative "../../../../../../lib/workspace/services/infra/doctor/repository_check"

class DoctorRepositoryCheckTest < Minitest::Test
  def test_label_and_call_returns_true_when_expected_repositories_exist
    repositories = [
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
      { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
    ]

    check = Workspace::Services::Infra::Doctor::RepositoryCheck.new(
      root: "/workspace",
      repositories_provider: -> { repositories }
    )

    Dir.expects(:exist?).with("/workspace/repos/api-template").returns(true)
    Dir.expects(:exist?).with("/workspace/repos/web-template").returns(true)
    Workspace.expects(:ok).with("repo api-template: found")
    Workspace.expects(:ok).with("repo web-template: found")

    assert_equal "expected repositories", check.label
    assert_equal true, check.call
  end

  def test_call_returns_false_when_expected_repository_is_missing
    repositories = [
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" }
    ]

    check = Workspace::Services::Infra::Doctor::RepositoryCheck.new(
      root: "/workspace",
      repositories_provider: -> { repositories }
    )

    Dir.expects(:exist?).with("/workspace/repos/api-template").returns(true)
    Workspace.expects(:ok).with("repo api-template: found")
    Workspace.expects(:fail).with("repo web-template: missing")

    assert_equal false, check.call
  end
end
