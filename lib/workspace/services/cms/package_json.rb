# frozen_string_literal: true

require "json"

require_relative "install_error"

module Workspace
  module Services
    module Cms
      # Wraps package.json edits for CMS install with a preflight-first workflow:
      # 1) validate/inspect sections and detect conflicts up front, then
      # 2) apply only explicit installer keys after the install path is verified.
      #
      # This keeps installation safe by preventing accidental overwrite of
      # existing dependency or script keys owned by the project.
      class PackageJson
        def initialize(path:)
          @path = path
          @data = nil
        end

        def parse!
          @data = JSON.parse(File.read(path))
          self
        rescue JSON::ParserError => e
          raise InstallError.new(
            "CMS install prerequisites failed.",
            details: "Invalid JSON in #{path}: #{e.message}",
            fixes: [
              "Fix package.json syntax in the frontend repository.",
              "Re-run the CMS install command after package.json is valid."
            ]
          )
        end

        def validate_sections!(*sections)
          sections.each { |name| section!(name) }
          self
        end

        def conflicting_keys(requirements:)
          conflicts = []

          requirements.each do |section_name, entries|
            section = section!(section_name)
            entries.each_key do |key|
              conflicts << "#{section_name}.#{key}" if section.key?(key)
            end
          end

          conflicts
        end

        def apply!(requirements:)
          requirements.each do |section_name, entries|
            section!(section_name).merge!(entries)
          end
        end

        def write!
          File.write(path, JSON.pretty_generate(data) + "\n")
        end

        private

        attr_reader :path, :data

        def section!(name)
          section = data[name]
          if section.nil?
            data[name] = {}
            return data[name]
          end

          return section if section.is_a?(Hash)

          raise InstallError.new(
            "CMS install prerequisites failed.",
            details: "Expected #{name} to be an object in #{path}.",
            fixes: [
              "Restore #{name} to a JSON object in package.json.",
              "Re-run the CMS install command after fixing package.json structure."
            ]
          )
        end
      end
    end
  end
end
