#!/usr/bin/env ruby
# frozen_string_literal: true
# Command object for workspace repository bootstrap and dependency setup.

require "fileutils"
require_relative "../../workspace"
require_relative "../context"
require_relative "backend/bootstrap"
require_relative "dsml/bootstrap"
require_relative "frontend/bootstrap"

module Workspace
  module Services
    class Bootstrap
      BACKEND_PURPOSE = "backend-api"
      DSML_PURPOSE = "data-science-ml"
      FRONTEND_PURPOSE = "frontend-web-client"
      BOOTSTRAPPERS = {
        BACKEND_PURPOSE => Workspace::Services::Backend::Bootstrap,
        FRONTEND_PURPOSE => Workspace::Services::Frontend::Bootstrap,
        DSML_PURPOSE => Workspace::Services::Dsml::Bootstrap
      }.freeze
      BOOTSTRAP_ORDER = [
        BACKEND_PURPOSE,
        FRONTEND_PURPOSE,
        DSML_PURPOSE
      ].freeze

      def initialize(context: Workspace::Context.new(root: Workspace::ROOT))
        @context = context
        @failures = []
      end

      def call
        Workspace.section("Bootstrap: Repository Setup")
        run_preinstall_or_abort

        Workspace.section("Bootstrap: Ensure Repositories", color: :magenta, divider_char: "-")
        ensure_repositories_present

        Workspace.section("Bootstrap: Install Dependencies", color: :magenta, divider_char: "-")
        install_repository_dependencies
        finalize
      end

      private

      attr_reader :context, :failures

      def run_preinstall_or_abort
        return if system(Workspace.script_path("preinstall_checks", context: context), chdir: context.root)

        Workspace.abort_with_help(
          "Bootstrap halted because pre-installation checks did not pass.",
          details: "The preinstall_checks step failed, so dependency installation was skipped.",
          assumptions: [
            "Bootstrap assumes a compatible Ruby and authenticated GitHub CLI are already available.",
            "Dependency and repository commands are likely to fail until preinstall_checks issues are fixed."
          ],
          fixes: [
            "Run bin/preinstall_checks and resolve every failure it reports.",
            "After preinstall_checks passes, run bin/bootstrap again."
          ]
        )
      end

      def ensure_repositories_present
        Workspace.repositories(context: context).each do |repo|
          ensure_repository_present(repo)
        end
      end

      def ensure_repository_present(repo)
        name = Workspace.repo_name(repo)
        path = Workspace.repo_path(repo, context: context)
        github_slug = repo["github"]

        return Workspace.ok("#{name} present") if Dir.exist?(path)
        return clone_repository(name, path, github_slug) if github_slug
        return Workspace.warn("#{name} missing (optional)") if repo["optional"]

        Workspace.fail_with_help(
          "Required repository #{name} is missing.",
          details: "No local directory was found at #{path}, and no github slug is configured for auto-clone.",
          assumptions: [
            "Bootstrap assumes each required repository has either a local checkout or github clone metadata.",
            "Without repository source metadata, automation cannot fetch missing code."
          ],
          fixes: [
            "Add github: owner/repo for #{name} in config/project.yml.repositories.",
            "Verify GitHub CLI authentication with: gh auth status.",
            "Or manually clone the repository into #{path}.",
            "If this repository should be optional, set optional: true in config/project.yml.repositories."
          ]
        )
        failures << name
      end

      def clone_repository(name, path, github_slug)
        clone_command = "gh repo clone #{github_slug} #{path}"

        Workspace.warn("#{name} missing, cloning #{github_slug}")
        FileUtils.mkdir_p(File.dirname(path))
        
        return if Workspace.run(
          clone_command,
          allow_failure: true,
          summary: "Repository clone failed for #{name}.",
          details: "Could not clone #{github_slug} into #{path}.",
          assumptions: [
            "GitHub CLI authentication is valid when cloning with gh repo clone.",
            "The repository reference and your access permissions are correct."
          ],
          fixes: [
            "Check authentication status with: gh auth status",
            "Confirm repository access in GitHub and validate config/project.yml repository values.",
            "Retry clone manually from the same directory to inspect tool output."
          ]
        )

        Workspace.fail_with_help(
          "Repository clone failed for #{name}.",
          details: "Could not clone #{github_slug} into #{path}.",
          assumptions: [
            "The configured repository reference is valid and reachable.",
            "Your GitHub account has permission to read this repository."
          ],
          fixes: [
            "Verify network access and that the repository URL is correct in config/project.yml.",
            "Ensure you have access rights to the repository (SSH key or token).",
            "Try cloning manually with the configured command: #{clone_command}"
          ]
        )
        failures << name
      end

      def install_repository_dependencies
        repositories = Workspace.existing_repositories(context: context)
        run_ordered_bootstraps(repositories)
        run_default_bootstraps(repositories)
      end

      def run_ordered_bootstraps(repositories)
        BOOTSTRAP_ORDER.each do |purpose|
          repo = repositories.find { |candidate| candidate["purpose"].to_s == purpose }
          next unless repo

          bootstrapper_for(purpose).call(repo: repo)
        end
      end

      def run_default_bootstraps(repositories)
        repositories.each do |repo|
          next if BOOTSTRAPPERS.key?(repo["purpose"].to_s)

          install_default_dependencies_for_repository(repo)
        end
      end

      def install_default_dependencies_for_repository(repo)
        name = Workspace.repo_name(repo)
        path = Workspace.repo_path(repo, context: context)

        run_repository_bootstrap_script(name, path)
        install_ruby_dependencies(name, path)
        install_node_dependencies(name, path)
      end

      def bootstrapper_for(purpose)
        @bootstrappers ||= {}
        @bootstrappers[purpose] ||= BOOTSTRAPPERS.fetch(purpose).new(
          context: context,
          failures: failures
        )
      end

      def run_repository_bootstrap_script(name, path)
        bootstrap_script = File.join(path, "bin", "bootstrap")
        return unless File.executable?(bootstrap_script)

        Workspace.warn("running repository bootstrap in #{name}")
        ok = Workspace.run(
          "bin/bootstrap",
          chdir: path,
          allow_failure: true,
          summary: "Repository bootstrap failed for #{name}.",
          details: "bin/bootstrap returned a non-zero status in #{path}.",
          fixes: [
            "Run bin/bootstrap manually in #{path} to inspect the first error.",
            "Resolve runtime/dependency tool errors, then retry workspace bootstrap.",
            "If #{name} does not require custom bootstrap, remove or fix bin/bootstrap."
          ]
        )
        failures << "#{name}:bootstrap" unless ok
      end

      def install_ruby_dependencies(name, path)
        return unless File.exist?(File.join(path, "Gemfile"))

        Workspace.warn("installing Ruby dependencies in #{name}")
        ok = Workspace.run(
          "bundle install",
          chdir: path,
          allow_failure: true,
          summary: "Ruby dependency installation failed for #{name}.",
          details: "Bundler could not install gems in #{path}.",
          assumptions: [
            "A compatible Ruby and Bundler are installed.",
            "Gem sources are reachable from your network and credentials are valid for private gems."
          ],
          fixes: [
            "Verify Ruby and Bundler versions: ruby --version && bundle --version.",
            "Run bundle install manually in #{path} to inspect the first gem error.",
            "If a private source is used, configure credentials and retry."
          ]
        )
        failures << "#{name}:bundle" unless ok
      end

      def install_node_dependencies(name, path)
        return unless File.exist?(File.join(path, "package.json"))

        Workspace.warn("installing Node dependencies in #{name}")
        ok = Workspace.run(
          "npm install",
          chdir: path,
          allow_failure: true,
          summary: "Node dependency installation failed for #{name}.",
          details: "npm could not install packages in #{path}.",
          assumptions: [
            "Node and npm are installed and in PATH.",
            "The lockfile and registry configuration are valid for this repository."
          ],
          fixes: [
            "Check tool versions: node --version && npm --version.",
            "Run npm install manually in #{path} to inspect the root error.",
            "If registry access fails, verify npm auth and network/proxy settings."
          ]
        )
        failures << "#{name}:npm" unless ok
      end

      def finalize
        return success if failures.empty?

        Workspace.fail_with_help(
          "Bootstrap completed with one or more failures.",
          details: "Failed steps: #{failures.join(', ')}",
          assumptions: [
            "Bootstrap assumes dependency managers, credentials, and local services are ready before install steps.",
            "A single failed step can cause subsequent setup tasks to fail or be skipped."
          ],
          fixes: [
            "Scroll up to the first failure block for the exact cause and command.",
            "Resolve each failed dependency/setup step and re-run bin/bootstrap.",
            "Use bin/doctor first if failures appear environment-related."
          ]
        )
        1
      end

      def success
        Workspace.ok("bootstrap complete")
        0
      end

    end
  end
end
