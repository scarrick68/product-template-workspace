# frozen_string_literal: true

require_relative "../../../workspace"
require_relative "../../context"

module Workspace
  module Services
    module Frontend
      # Coordinates frontend repository setup lifecycle.
      class Bootstrap
        def initialize(context:, failures:)
          @context = context
          @failures = failures
        end

        def call(repo:)
          name = Workspace.repo_name(repo)
          path = Workspace.repo_path(repo, context: context)

          run_repository_bootstrap_script(name, path)
          install_ruby_dependencies(name, path)
          install_node_dependencies(name, path)
        end

        private

        attr_reader :context, :failures

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
      end
    end
  end
end