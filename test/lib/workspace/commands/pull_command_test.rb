# frozen_string_literal: true

require_relative "../../../test_helper"

class PullCommandSmokeTest < Minitest::Test
  def test_happy_path_returns_zero
    Dir.mktmpdir("workspace-pull") do |repo_dir|
      FileUtils.mkdir_p(File.join(repo_dir, ".git"))

      repos = [{ "name" => "api-template", "path" => repo_dir }]

      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("api-template")
      Workspace.stubs(:repo_path).returns(repo_dir)
      Workspace.stubs(:capture).returns(["", true])
      Workspace.stubs(:capture).with("git branch --show-current", chdir: repo_dir).returns(["feature/auth\n", true])
      Workspace.stubs(:capture).with("git status --porcelain", chdir: repo_dir).returns(["", true])
      Workspace.stubs(:run).returns(true)
      Workspace.stubs(:warn)
      Workspace.stubs(:ok)
      Workspace.stubs(:fail_with_help)

      result = Workspace::Services::Pull.new.call
      assert_equal 0, result
    end
  end
end
