# frozen_string_literal: true

require "active_support/encrypted_file"
require "fileutils"
require "tmpdir"
require "yaml"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/init_workspace_credentials_files"

class InitWorkspaceCredentialsFilesCommandTest < Minitest::Test
  Command = Workspace::Services::InitWorkspaceCredentialsFiles

  def setup
    @root = Dir.mktmpdir("workspace-credentials-command")

    @key_path = File.join(
      @root,
      "config",
      "workspace.credentials.key"
    )

    @encrypted_path = File.join(
      @root,
      "config",
      "workspace.credentials.yml.enc"
    )

    @backup_dir = File.join(
      @root,
      "config",
      "workspace_credentials_backups"
    )

    @prompt = mock("prompt")

    Workspace.stubs(:info)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_initializes_decryptable_credentials_when_files_do_not_exist
    Workspace.expects(:info).with(
      "Initializing workspace credentials files..."
    )
    Workspace.expects(:info).with(
      "Initialized workspace credentials files."
    )
    Workspace.expects(:info).with(
      "Key file: #{@key_path}"
    )
    Workspace.expects(:info).with(
      "Encrypted file: #{@encrypted_path}"
    )

    @prompt.expects(:yes?).never

    assert_equal 0, command.call

    assert File.file?(@key_path)
    assert File.file?(@encrypted_path)
    assert_equal({}, decrypted_credentials)

    assert_equal 0o600, file_mode(@key_path)
    assert_equal 0o600, file_mode(@encrypted_path)
  end

  def test_aborts_when_credentials_files_exist_and_confirmation_is_no
    write_existing_credentials(
      key: "original-key",
      encrypted: "original-encrypted"
    )

    @prompt.expects(:yes?).with(
      "Overwrite existing workspace credentials files? This will back up the existing files to #{@backup_dir}.",
      default: false
    ).returns(false)

    Workspace.expects(:info).with(
      "Initializing workspace credentials files..."
    )
    Workspace.expects(:info).with(
      "Aborting. Existing workspace credentials files were not overwritten."
    )

    assert_equal 1, command.call

    assert_equal "original-key", File.read(@key_path)
    assert_equal "original-encrypted", File.read(@encrypted_path)
    refute Dir.exist?(@backup_dir)
  end

  def test_confirmation_accepts_yes_and_backs_up_existing_files
    write_existing_credentials(
      key: "original-key",
      encrypted: "original-encrypted"
    )

    @prompt.expects(:yes?).with(
      "Overwrite existing workspace credentials files? This will back up the existing files to #{@backup_dir}.",
      default: false
    ).returns(true)

    Workspace.expects(:info).with(
      "Backed up existing workspace credentials files to #{@backup_dir}"
    )

    assert_equal 0, command.call
    assert_equal({}, decrypted_credentials)

    assert_equal "original-key", File.read(backup_path_for(@key_path))
    assert_equal(
      "original-encrypted",
      File.read(backup_path_for(@encrypted_path))
    )
  end

  def test_treats_a_single_existing_file_as_an_existing_credentials_setup
    FileUtils.mkdir_p(File.dirname(@key_path))
    File.write(@key_path, "original-key")

    @prompt.expects(:yes?).with(
      "Overwrite existing workspace credentials files? This will back up the existing files to #{@backup_dir}.",
      default: false
    ).returns(false)

    assert_equal 1, command.call

    assert_equal "original-key", File.read(@key_path)
    refute File.exist?(@encrypted_path)
    refute Dir.exist?(@backup_dir)
  end

  def test_backs_up_only_files_that_exist
    FileUtils.mkdir_p(File.dirname(@key_path))
    File.write(@key_path, "original-key")

    @prompt.expects(:yes?).returns(true)

    assert_equal 0, command.call

    key_backups = backup_files_for(@key_path)
    encrypted_backups = backup_files_for(@encrypted_path)

    assert_equal 1, key_backups.length
    assert_empty encrypted_backups

    assert_equal "original-key", File.read(key_backups.fetch(0))
    assert_equal({}, decrypted_credentials)
  end

  private

  def command
    command = Command.new(prompt: @prompt)

    command.stubs(:key_path).returns(@key_path)
    command.stubs(:encrypted_path).returns(@encrypted_path)
    command.stubs(:backup_dir).returns(@backup_dir)

    command
  end

  def write_existing_credentials(key:, encrypted:)
    FileUtils.mkdir_p(File.dirname(@key_path))
    File.write(@key_path, key)
    File.write(@encrypted_path, encrypted)
  end

  def decrypted_credentials
    encrypted_file = ActiveSupport::EncryptedFile.new(
      content_path: @encrypted_path,
      key_path: @key_path,
      env_key: "UNUSED_TEST_WORKSPACE_CREDENTIALS_KEY",
      raise_if_missing_key: true
    )

    YAML.safe_load(
      encrypted_file.read,
      permitted_classes: [],
      aliases: false
    )
  end

  def backup_path_for(path)
    backups = backup_files_for(path)

    assert_equal 1, backups.length

    backups.fetch(0)
  end

  def backup_files_for(path)
    Dir.glob(
      File.join(
        @backup_dir,
        "#{File.basename(path)}.*"
      )
    )
  end

  def file_mode(path)
    File.stat(path).mode & 0o777
  end
end