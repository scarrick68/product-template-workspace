# frozen_string_literal: true

require_relative "../../../test_helper"

class BootstrapCommandSmokeTest < Minitest::Test
  def test_happy_path_returns_zero
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      File.write(File.join(repo_dir, "Gemfile"), "source 'https://rubygems.org'\n")
      File.write(File.join(repo_dir, "package.json"), "{}")
      FileUtils.mkdir_p(File.join(repo_dir, "config"))
      File.write(File.join(repo_dir, "config", "application.rb"), "# rails app\n")
      File.write(File.join(repo_dir, "config", "database.yml"), "test: {}\n")
      FileUtils.mkdir_p(File.join(repo_dir, "bin"))
      File.write(File.join(repo_dir, "bin", "rails"), "#!/usr/bin/env ruby\n")
      FileUtils.chmod("u+x", File.join(repo_dir, "bin", "rails"))

      repos = [{ "name" => "api-template", "path" => repo_dir }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("api-template")
      Workspace.stubs(:repo_path).with(repos.first).returns(repo_dir)
      Workspace.stubs(:run).returns(true)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).with("preinstall").returns("bin/preinstall")

      helper = mock("rails_credentials_helper")
      helper.expects(:call).returns(true)
      Workspace::Commands::Bootstrap::RailsCredentialsHelper
        .expects(:new)
        .with(repository_name: "api-template", repository_path: repo_dir)
        .returns(helper)

      command = Workspace::Commands::BootstrapCommand.new
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end

  def test_skips_credentials_helper_for_non_rails_repo
    Dir.mktmpdir("workspace-bootstrap") do |repo_dir|
      File.write(File.join(repo_dir, "package.json"), "{}")

      repos = [{ "name" => "web-template", "path" => repo_dir, "purpose" => "frontend-web-client" }]

      Workspace.stubs(:repositories).returns(repos)
      Workspace.stubs(:existing_repositories).returns(repos)
      Workspace.stubs(:repo_name).with(repos.first).returns("web-template")
      Workspace.stubs(:repo_path).with(repos.first).returns(repo_dir)
      Workspace.stubs(:run).returns(true)
      Workspace.stubs(:ok)
      Workspace.stubs(:warn)
      Workspace.stubs(:fail_with_help)
      Workspace.stubs(:abort_with_help).raises("abort_with_help called unexpectedly")
      Workspace.stubs(:script_path).with("preinstall").returns("bin/preinstall")

      Workspace::Commands::Bootstrap::RailsCredentialsHelper.expects(:new).never

      command = Workspace::Commands::BootstrapCommand.new
      command.stubs(:system).returns(true)

      result = command.call
      assert_equal 0, result
    end
  end
end
