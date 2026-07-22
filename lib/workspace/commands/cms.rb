# frozen_string_literal: true

require "optparse"
require_relative "../../workspace"
require_relative "../context"
require_relative "../services/cms/installer"
require_relative "../services/cms/options"

module Workspace
  module Commands
    class Cms
      def initialize(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
        @argv = argv.dup
        @stdin = stdin
        @stdout = stdout
        @stderr = stderr
      end

      def call
        subcommand_name = argv.shift

        case subcommand_name
        when "add"
          add
        else
          usage
        end
      end

      private

      attr_reader :argv, :stdin, :stdout, :stderr

      def add
        options = parse_add_options
        return 1 unless options

        if options[:provider] == Workspace::Services::Cms::Options::DEFAULT_PROVIDER
          Workspace.fail_with_help(
            "No CMS provider selected for add.",
            details: "--provider=#{Workspace::Services::Cms::Options::DEFAULT_PROVIDER} does not install any CMS feature.",
            fixes: [
              "Use: bin/workspace cms add",
              "Or specify provider explicitly: --provider=#{Workspace::Services::Cms::Options::WITH_CMS_PROVIDER}"
            ]
          )
          return 1
        end

        cms_installer.call(provider: options[:provider])
      end

      def parse_add_options
        options = {
          provider: Workspace::Services::Cms::Options::WITH_CMS_PROVIDER
        }

        parser = OptionParser.new do |opts|
          provider_usage = Workspace::Services::Cms::Options::SUPPORTED_PROVIDERS.join("|")
          opts.banner = "Usage: bin/workspace cms add [--provider=#{provider_usage}|--with-cms]"

          opts.on("--provider=PROVIDER", "Enable optional local CMS provider (#{provider_usage})") do |provider|
            options[:provider] = provider.to_s.strip.downcase
          end

          opts.on("--with-cms", "Alias for --provider=#{Workspace::Services::Cms::Options::WITH_CMS_PROVIDER}") do
            options[:provider] = Workspace::Services::Cms::Options::WITH_CMS_PROVIDER
          end

          opts.on("-h", "--help", "Show usage") do
            stdout.puts(opts)
            return nil
          end
        end

        parser.parse!(argv)

        if argv.any?
          Workspace.fail_with_help(
            "Unexpected arguments for cms add.",
            details: "Unexpected: #{argv.join(' ')}",
            fixes: ["Run: bin/workspace cms add --help"]
          )
          return nil
        end

        options
      rescue OptionParser::ParseError => e
        Workspace.fail_with_help(
          "Invalid cms add options.",
          details: e.message,
          fixes: ["Run: bin/workspace cms add --help"]
        )
        nil
      end

      def usage
        stderr.puts("Usage: bin/workspace cms <add> [options]")
        1
      end

      def cms_installer
        @cms_installer ||= Workspace::Services::Cms::Installer.new(
          context: Workspace::Context.new(root: Workspace::ROOT),
          stdin: stdin,
          stdout: stdout
        )
      end
    end
  end
end