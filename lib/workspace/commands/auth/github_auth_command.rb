#!/usr/bin/env ruby
# frozen_string_literal: true
# GitHub authentication and permission diagnostics for repository creation/push workflows.

require "json"
require_relative "../../../workspace"

module Workspace
  module Commands
    module Auth
      class GithubAuthCommand
      def call
        checks_failed = false

        checks_failed ||= !check_git_cli
        checks_failed ||= !check_gh_cli
        checks_failed ||= !check_gh_auth
        checks_failed ||= !check_gh_viewer
        checks_failed ||= !check_gh_repo_creation_scopes
        checks_failed ||= !check_owner_membership

        if checks_failed
          Workspace.fail("github auth doctor detected one or more permission/credential issues")
          return 1
        end

        Workspace.ok("github auth doctor checks passed")
        0
      end

      private

      def check_git_cli
        if Workspace.command_exists?("git")
          Workspace.ok("git: available")
          return true
        end

        Workspace.fail("git: missing")
        false
      end

      def check_gh_cli
        if Workspace.command_exists?("gh")
          Workspace.ok("gh: available")
          return true
        end

        Workspace.fail("gh: missing")
        false
      end

      def check_gh_auth
        _out, ok = Workspace.capture("gh auth status")
        if ok
          Workspace.ok("gh auth: valid")
          return true
        end

        Workspace.fail("gh auth: invalid (run: gh auth login)")
        false
      end

      def check_gh_viewer
        out, ok = Workspace.capture("gh api user")
        return Workspace.fail("gh api user: failed") && false unless ok

        login = JSON.parse(out).fetch("login", nil)
        if login.nil? || login.to_s.empty?
          Workspace.fail("gh viewer login: unavailable")
          return false
        end

        Workspace.ok("gh viewer: #{login}")
        true
      rescue JSON::ParserError
        Workspace.fail("gh viewer: unable to parse response")
        false
      end

      def check_gh_repo_creation_scopes
        out, ok = Workspace.capture("gh auth status -t")
        unless ok
          Workspace.warn("gh auth scopes: unable to inspect")
          return true
        end

        if out.match?(/\brepo\b/) || out.match?(/fine-grained/i)
          Workspace.ok("gh auth scopes: repo creation scope appears present")
          return true
        end

        Workspace.warn("gh auth scopes: repo scope not detected; repository creation may fail")
        Workspace.warn("If needed, run: gh auth refresh -s repo")
        true
      end

      def check_owner_membership
        owner = default_owner
        return Workspace.warn("github owner: not configured in config/repos.yml") && true if owner.nil?

        user_out, user_ok = Workspace.capture("gh api user")
        return Workspace.fail("github owner check: cannot resolve current user") && false unless user_ok

        login = JSON.parse(user_out).fetch("login", "")
        return Workspace.fail("github owner check: login missing") && false if login.empty?

        if owner.casecmp(login).zero?
          Workspace.ok("github owner '#{owner}': matches authenticated user")
          return true
        end

        _org_out, org_ok = Workspace.capture("gh api orgs/#{owner}")
        unless org_ok
          Workspace.fail("github owner '#{owner}': cannot access org details")
          Workspace.warn("Verify owner spelling and membership, or set config/repos.yml github owner correctly.")
          return false
        end

        membership_out, membership_ok = Workspace.capture("gh api orgs/#{owner}/memberships/#{login}")
        unless membership_ok
          Workspace.warn("github org membership for #{login} in #{owner}: cannot verify via API")
          Workspace.warn("Repository creation in org '#{owner}' may fail without org permissions.")
          return true
        end

        membership = JSON.parse(membership_out)
        state = membership.fetch("state", "unknown")
        role = membership.fetch("role", "unknown")
        if state == "active"
          Workspace.ok("github org membership: active (role: #{role})")
          return true
        end

        Workspace.fail("github org membership is not active (state: #{state})")
        false
      rescue JSON::ParserError
        Workspace.fail("github owner check: failed to parse API response")
        false
      end

      def default_owner
        repo = Workspace.repositories.find { |item| item["github"].to_s.include?("/") }
        return nil unless repo

        owner = repo["github"].to_s.split("/", 2).first
        owner.to_s.empty? ? nil : owner
      end
      end
    end
  end
end
