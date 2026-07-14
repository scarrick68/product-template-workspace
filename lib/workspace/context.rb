# frozen_string_literal: true

require_relative "project_manifest/loader"

module Workspace
  class Context
    attr_reader :root

    # Normalize and store the workspace root for all path resolution.
    def initialize(root:)
      @root = File.expand_path(root)
    end

    # Build an absolute path under this workspace root.
    def path(*parts)
      File.join(root, *parts)
    end

    # Resolve a workspace bin script path by name.
    def script_path(name)
      path("bin", name)
    end

    # Load and memoize the project manifest from this workspace.
    def manifest
      @manifest ||= ProjectManifest::Loader.new(root: root).load || {}
    end

    # Return repository definitions declared in the manifest.
    def repositories
      manifest.fetch("repositories", [])
    end

    # Resolve a repository's absolute path from its manifest entry.
    def repo_path(repository)
      path(repository.fetch("path"))
    end
  end
end
