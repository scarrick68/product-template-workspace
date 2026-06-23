# frozen_string_literal: true

require_relative "../../../test_helper"

class SyncOpenapiCommandSmokeTest < Minitest::Test
  def test_happy_path_copies_openapi_targets
    Dir.mktmpdir("workspace-sync-openapi") do |root|
      original_root = Workspace::ROOT
      Workspace.send(:remove_const, :ROOT)
      Workspace.const_set(:ROOT, root)

      begin
        source = File.join(root, "repos", "api-template", "docs")
        FileUtils.mkdir_p(source)
        File.write(File.join(source, "openapi.yml"), "openapi: 3.1.0\n")

        web_repo = File.join(root, "repos", "web-template")
        FileUtils.mkdir_p(web_repo)
        File.write(File.join(web_repo, "package.json"), "{\"scripts\":{}}")

        Workspace.stubs(:ok)
        Workspace.stubs(:warn)
        Workspace.stubs(:run).returns(true)
        Workspace.stubs(:fail_with_help)

        result = Workspace::Commands::SyncOpenapiCommand.new.call
        assert_equal 0, result

        assert File.exist?(File.join(root, "contracts", "openapi", "openapi.yml"))
        assert File.exist?(File.join(root, "repos", "web-template", "openapi", "openapi.yml"))
      ensure
        Workspace.send(:remove_const, :ROOT)
        Workspace.const_set(:ROOT, original_root)
      end
    end
  end
end
