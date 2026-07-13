# frozen_string_literal: true

require_relative "../../../test_helper"

class StatusCommandSmokeTest < Minitest::Test
  def test_happy_path_returns_zero
    Dir.mktmpdir("workspace-status") do |repo_dir|
      FileUtils.mkdir_p(File.join(repo_dir, ".git"))

      repos = [{ "name" => "api-template", "path" => repo_dir }]

      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("api-template")
      Workspace.stubs(:repo_path).with(repos.first).returns(repo_dir)
      Workspace.stubs(:capture).returns(["## main\n", true])
      Workspace.stubs(:fail_with_help)

      result = Workspace::Services::Status.new.call
      assert_equal 0, result
    end
  end
end
