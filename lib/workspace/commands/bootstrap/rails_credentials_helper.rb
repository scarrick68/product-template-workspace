#!/usr/bin/env ruby
# frozen_string_literal: true

require "shellwords"
require "active_support/encrypted_file"
require_relative "../../../workspace"

module Workspace
  module Commands
    module Bootstrap
      class RailsCredentialsHelper
        CREDENTIAL_ENVIRONMENTS = %w[development test production].freeze

        def initialize(repository_name:, repository_path:)
          @repository_name = repository_name
          @repository_path = repository_path
        end

        def call
          return fail_missing_rails_environment unless rails_app?

          detect_initial_default_creds_and_master_key_state
          ensure_default_credentials
          ensure_environment_credentials
          ensure_credentials_files_present
          ensure_credentials_decryptable
        end

        private

        attr_reader :repository_name, :repository_path

        def rails_app?
          File.file?(File.join(repository_path, "config", "application.rb"))
        end

        def fail_missing_rails_environment
          Workspace.fail_with_help(
            "#{repository_name}: Rails environment not found for credentials bootstrap.",
            details: "Expected config/application.rb under #{repository_path}.",
            fixes: [
              "Ensure this repository is a Rails app before running credentials bootstrap.",
              "If this repository should not run Rails credentials setup, skip invoking RailsCredentialsHelper for it.",
              "Verify bootstrap repo path configuration in config/repos.yml."
            ]
          )
          false
        end

        def detect_initial_default_creds_and_master_key_state
          default_enc = default_credentials_path
          default_key = default_key_path

          if File.exist?(default_enc) && !File.exist?(default_key)
            Workspace.info("#{repository_name}: template-state detected (credentials.yml.enc exists, master.key missing)")
            return
          end

          if File.exist?(default_enc) && File.exist?(default_key)
            Workspace.info("#{repository_name}: credentials already initialized. Skipping default credentials and master key creation")
            return
          end

          Workspace.info("#{repository_name}: credentials.yml.enc missing; bootstrap will initialize credentials")
        end

        def ensure_default_credentials
          return true if File.exist?(default_credentials_path) && File.exist?(default_key_path)

          Workspace.info("#{repository_name}: initializing default Rails credentials")
          run_credentials_edit
        end

        def ensure_environment_credentials
          CREDENTIAL_ENVIRONMENTS.each do |environment|
            next if File.exist?(credentials_path_for(environment)) && File.exist?(key_path_for(environment))

            Workspace.info("#{repository_name}: initializing #{environment} Rails credentials")
            return false unless run_credentials_edit(environment: environment)
          end

          true
        end

        def ensure_credentials_files_present
          targets = [
            ["default", default_credentials_path, default_key_path],
            *CREDENTIAL_ENVIRONMENTS.map do |environment|
              [environment, credentials_path_for(environment), key_path_for(environment)]
            end
          ]

          missing = targets.reject do |_label, content_path, key_path|
            File.exist?(content_path) && File.exist?(key_path)
          end

          return true if missing.empty?

          details = missing.map { |label, content_path, key_path| "#{label}: #{content_path} and/or #{key_path}" }.join(" | ")
          Workspace.fail_with_help(
            "#{repository_name}: credentials files are missing after initialization.",
            details: details,
            fixes: [
              "Run in repo: EDITOR=true bundle exec rails credentials:edit",
              "Run in repo: EDITOR=true bundle exec rails credentials:edit --environment development",
              "Run in repo: EDITOR=true bundle exec rails credentials:edit --environment test",
              "Run in repo: EDITOR=true bundle exec rails credentials:edit --environment production"
            ]
          )
          false
        end

        def ensure_credentials_decryptable
          targets = [
            ["default", default_credentials_path, default_key_path],
            *CREDENTIAL_ENVIRONMENTS.map do |environment|
              [environment, credentials_path_for(environment), key_path_for(environment)]
            end
          ]

          failed = targets.reject do |label, content_path, key_path|
            credentials_decryptable?(label: label, content_path: content_path, key_path: key_path)
          end

          return true if failed.empty?

          details = failed.map { |label, content_path, key_path| "#{label}: #{content_path} with #{key_path}" }.join(" | ")
          Workspace.fail_with_help(
            "#{repository_name}: credentials files could not be decrypted.",
            details: details,
            fixes: [
              "Ensure each credentials *.yml.enc file matches its corresponding *.key file.",
              "Recreate mismatched credentials with rails credentials:edit for the affected environment.",
              "Do not copy keys between repositories unless they are intended to match encrypted files."
            ]
          )
          false
        end

        def run_credentials_edit(environment: nil)
          command = "EDITOR=true bundle exec rails credentials:edit"
          command += " --environment #{Shellwords.escape(environment)}" if environment

          Workspace.run(
            command,
            chdir: repository_path,
            allow_failure: true,
            summary: "Rails credentials setup failed for #{repository_name}.",
            details: "Command failed: #{command}",
            assumptions: [
              "Bundler dependencies are installed for this repository.",
              "Rails boots in the default environment without interactive blockers."
            ],
            fixes: [
              "Run manually in #{repository_path}: #{command}",
              "Fix any Rails boot errors, then rerun bin/bootstrap."
            ]
          )
        end

        def credentials_decryptable?(label:, content_path:, key_path:)
          encrypted_file = ActiveSupport::EncryptedFile.new(
            content_path: content_path,
            key_path: key_path,
            env_key: "DO_NOT_USE_ENV_FOR_BOOTSTRAP_CREDENTIALS_CHECK",
            raise_if_missing_key: true
          )

          encrypted_file.read

          Workspace.ok("#{repository_name}: #{label} credentials decryptable")
          true
        rescue ActiveSupport::EncryptedFile::MissingContentError,
               ActiveSupport::EncryptedFile::MissingKeyError,
               ActiveSupport::MessageEncryptor::InvalidMessage => e
          Workspace.fail("#{repository_name}: #{label} credentials not decryptable: #{e.class}")
          false
        end

        def default_credentials_path
          File.join(repository_path, "config", "credentials.yml.enc")
        end

        def default_key_path
          File.join(repository_path, "config", "master.key")
        end

        def credentials_path_for(environment)
          File.join(repository_path, "config", "credentials", "#{environment}.yml.enc")
        end

        def key_path_for(environment)
          File.join(repository_path, "config", "credentials", "#{environment}.key")
        end
      end
    end
  end
end
