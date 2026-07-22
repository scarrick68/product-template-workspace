# frozen_string_literal: true

require_relative "install_error"
require_relative "manifest"
require_relative "options"
require_relative "prerequisites"
require_relative "providers/keystatic"
require_relative "../git/changes_committer"

module Workspace
  module Services
    module Cms
      class Installer
        AUTO_COMMIT_PREFIX = "[SYSTEM][INSTALLER]"
        PRE_CMS_CHECKPOINT_MESSAGE = "#{AUTO_COMMIT_PREFIX} CMS pre-install checkpoint commit. CMS will be installed in a single commit after this."

        def initialize(context:, stdin: $stdin, stdout: $stdout)
          @context = context
          @stdin = stdin
          @stdout = stdout
        end

        def call(provider:)
          provider = Options.normalize(provider)
          return 0 if Options.disabled?(provider)

          return 1 unless validate_supported_provider!(provider)

          Prerequisites.new(context: context).validate!

          manifest = Manifest.new(context: context)
          return already_enabled(provider) if manifest.enabled_with?(provider)
          return replacement_not_supported(manifest.provider, provider) if manifest.enabled?

          checkpoint_preexisting_changes
          marker = git_changes_committer.mark

          Providers::Keystatic.new(context: context).install
          manifest.enable!(provider: provider, authoring: "local", publishing: "git")
          commit_changes_since(marker, message: commit_message(provider))

          report_success(provider)
          0
        rescue InstallError => e
          report_failure(e)
          1
        end

        private

        attr_reader :context, :stdin, :stdout

        def validate_supported_provider!(provider)
          return true if Options.supported_provider?(provider)

          Workspace.fail_with_help(
            "Unsupported CMS provider '#{provider}'.",
            details: "Supported CMS providers: #{Options::SUPPORTED_PROVIDERS.join(', ')}",
            fixes: [
              "Use --cms=#{Options::DEFAULT_PROVIDER} for the default no-CMS setup.",
              "Use --cms=#{Options::WITH_CMS_PROVIDER} for local CMS installation."
            ]
          )
          false
        end

        def already_enabled(provider)
          Workspace.info("CMS provider '#{provider}' is already enabled; skipping install.")
          0
        end

        def replacement_not_supported(current_provider, requested_provider)
          Workspace.fail_with_help(
            "CMS provider replacement is not supported.",
            details: "Current provider in config/project.yml is '#{current_provider}'. Requested provider is '#{requested_provider}'.",
            fixes: [
              "Keep CMS installation in dedicated commit(s) so changes can be reverted safely.",
              "To change providers, revert CMS-related commit(s) and apply a fresh install path.",
              "Run smoke checks after revert/install: tests, production build, and local route verification."
            ]
          )
          1
        end

        def report_success(provider)
          Workspace.ok("CMS feature recorded in project manifest (provider: #{provider}).")
          Workspace.info("Keystatic local authoring scaffolding has been added to the frontend repository.")
          Workspace.info("Installer auto-commits CMS scaffolding with #{AUTO_COMMIT_PREFIX} so rollback remains a simple git revert.")
        end

        def report_failure(error)
          Workspace.fail_with_help(error.message, details: error.details, fixes: error.fixes)
        end

        def commit_message(provider)
          "#{AUTO_COMMIT_PREFIX} Enable CMS scaffolding (#{provider})"
        end

        def checkpoint_preexisting_changes
          committed = git_changes_committer.commit_changes(message: PRE_CMS_CHECKPOINT_MESSAGE)
          Workspace.info("Created installer commit: #{PRE_CMS_CHECKPOINT_MESSAGE}") if committed
        rescue Workspace::Services::Git::ChangesCommitter::OperationError => e
          Workspace.warn("CMS installer could not create pre-install checkpoint commit: #{e.details || e.message}")
        end

        def commit_changes_since(marker, message:)
          committed = git_changes_committer.commit_since(marker, message: message)
          Workspace.info("Created installer commit: #{message}") if committed
        rescue Workspace::Services::Git::ChangesCommitter::OperationError => e
          Workspace.warn("CMS installer could not auto-commit changes: #{e.details || e.message}")
        end

        def git_changes_committer
          @git_changes_committer ||= Workspace::Services::Git::ChangesCommitter.new(context: context)
        end
      end
    end
  end
end
