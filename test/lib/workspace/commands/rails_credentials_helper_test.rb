# frozen_string_literal: true

require "tmpdir"
require "active_support/encrypted_file"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/bootstrap/rails_credentials_helper"

class RailsCredentialsHelperTest < Minitest::Test
  def test_returns_false_when_repo_is_not_rails
    Dir.mktmpdir("workspace-creds-helper") do |repo_dir|
      Workspace.expects(:fail_with_help).once

      helper = Workspace::Commands::Bootstrap::RailsCredentialsHelper.new(
        repository_name: "non-rails",
        repository_path: repo_dir
      )

      assert_equal false, helper.call
    end
  end

  def test_validates_existing_credentials_without_reinitializing
    with_rails_repo do |repo_dir|
      write_all_credentials(repo_dir)

      stub_successful_decryption

      Workspace.expects(:run).never
      Workspace.expects(:fail).never
      Workspace.expects(:fail_with_help).never
      Workspace.expects(:ok).times(4)
      Workspace.stubs(:info)
      Workspace.stubs(:warn)

      assert Workspace::Commands::Bootstrap::RailsCredentialsHelper.new(
        repository_name: "api-template",
        repository_path: repo_dir
      ).call
    end
  end

  private

  def with_rails_repo
    Dir.mktmpdir("workspace-creds-helper") do |repo_dir|
      FileUtils.mkdir_p(File.join(repo_dir, "config"))
      File.write(File.join(repo_dir, "config", "application.rb"), "# rails app\n")
      File.write(File.join(repo_dir, "config", "environment.rb"), "# rails env\n")

      yield repo_dir
    end
  end

  def write_all_credentials(repo_dir)
    FileUtils.mkdir_p(File.join(repo_dir, "config", "credentials"))

    write_credential_pair(
      content_path: File.join(repo_dir, "config", "credentials.yml.enc"),
      key_path: File.join(repo_dir, "config", "master.key")
    )

    %w[development test production].each do |environment|
      write_credential_pair(
        content_path: File.join(repo_dir, "config", "credentials", "#{environment}.yml.enc"),
        key_path: File.join(repo_dir, "config", "credentials", "#{environment}.key")
      )
    end
  end

  def write_credential_pair(content_path:, key_path:)
    File.write(content_path, "encrypted-content\n")
    File.write(key_path, "matching-key\n")
  end

  def stub_successful_decryption
    encrypted_file = mock("ActiveSupport::EncryptedFile")
    encrypted_file.expects(:read).times(4).returns("decrypted")

    ActiveSupport::EncryptedFile
      .expects(:new)
      .times(4)
      .returns(encrypted_file)
  end
end
