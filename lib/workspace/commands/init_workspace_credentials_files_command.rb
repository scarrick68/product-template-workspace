#!/usr/bin/env ruby
# frozen_string_literal: true

require "active_support/encrypted_file"
require "fileutils"
require "tty-prompt"
require "yaml"

require_relative "../../workspace"

module Workspace
  module Commands
    class InitWorkspaceCredentialsFilesCommand
      def initialize(prompt: TTY::Prompt.new)
        @prompt = prompt
      end

      def call
        Workspace.info("Initializing workspace credentials files...")

        if credentials_files_exist?
          Workspace.info(existing_credentials_message)

          overwrite = @prompt.yes?(
            "Overwrite existing workspace credentials files? This will back up the existing files to #{backup_dir}.",
            default: false
          )

          unless overwrite
            Workspace.info(
              "Aborting. Existing workspace credentials files were not overwritten."
            )
            return 1
          end

          backup_existing_credentials
        end

        create_new_credentials_files
        0
      end

      private

      def existing_credentials_message
        key_exists = File.exist?(key_path)
        encrypted_exists = File.exist?(encrypted_path)

        if key_exists && encrypted_exists
          "Existing workspace credentials were found."
        elsif key_exists
          <<~MSG.chomp
            Found a workspace credentials key file without a matching encrypted credentials file.
            The key alone does not contain any credentials and cannot be used without the encrypted file.
          MSG
        else
          <<~MSG.chomp
            Found an encrypted workspace credentials file without its matching key file.
            The encrypted file cannot be decrypted or used without its key.
          MSG
        end
      end

      def create_new_credentials_files
        FileUtils.mkdir_p(File.dirname(key_path))
        FileUtils.mkdir_p(File.dirname(encrypted_path))

        File.write(key_path, ActiveSupport::EncryptedFile.generate_key)
        File.chmod(0o600, key_path)

        encrypted_file.write({}.to_yaml)
        File.chmod(0o600, encrypted_path)

        Workspace.info("Initialized workspace credentials files.")
        Workspace.info("Key file: #{key_path}")
        Workspace.info("Encrypted file: #{encrypted_path}")
      end

      def backup_existing_credentials
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")

        FileUtils.mkdir_p(backup_dir)

        backup_file(key_path, timestamp)
        backup_file(encrypted_path, timestamp)

        Workspace.info(
          "Backed up existing workspace credentials files to #{backup_dir}"
        )
      end

      def backup_file(path, timestamp)
        return unless File.exist?(path)

        destination = File.join(
          backup_dir,
          "#{File.basename(path)}.#{timestamp}"
        )

        FileUtils.cp(path, destination)
      end

      def encrypted_file
        @encrypted_file ||= ActiveSupport::EncryptedFile.new(
          content_path: encrypted_path,
          key_path: key_path,
          env_key: "UNUSED_WORKSPACE_CREDENTIALS_INITIALIZATION_KEY",
          raise_if_missing_key: true
        )
      end

      def credentials_files_exist?
        File.exist?(key_path) || File.exist?(encrypted_path)
      end

      def backup_dir
        @backup_dir ||= File.join(
          Workspace::ROOT,
          "config",
          "workspace_credentials_backups"
        )
      end

      def key_path
        @key_path ||= File.join(
          Workspace::ROOT,
          "config",
          "workspace_credentials.key"
        )
      end

      def encrypted_path
        @encrypted_path ||= File.join(
          Workspace::ROOT,
          "config",
          "workspace_credentials.yml.enc"
        )
      end
    end
  end
end
