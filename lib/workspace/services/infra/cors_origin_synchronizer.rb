# frozen_string_literal: true

require "json"

module Workspace
	module Services
		module Infra
			# Synchronizes backend CORS origin values in terraform.tfvars.json.
			class CorsOriginSynchronizer
				def initialize(manifest_configuration:, terraform_workspace:, workspace: Workspace)
					@manifest_configuration = manifest_configuration
					@terraform_workspace = terraform_workspace
					@workspace = workspace
				end

				# Pre-apply setup:
				# - Use configured frontend_domain when present.
				# - Preserve existing backend CORS when already set.
				# - Otherwise keep backend CORS empty for first boot.
				def ensure_backend_cors_origin_value_for_initial_apply!(environment:)
					tfvars = load_tfvars
					configured_frontend_origin = configured_frontend_domain_origin(environment: environment)

					unless configured_frontend_origin.empty?
						tfvars["rails_cors_allowed_origins"] = configured_frontend_origin
						persist_tfvars(tfvars)
						workspace.info("Using configured frontend domain for backend CORS origin: #{configured_frontend_origin}")
						workspace.info("Ensure this domain is already provisioned and routed to the frontend app before apply.")
						return
					end

					current_backend_cors_origin = backend_cors_origin_from_tfvars(tfvars)
					unless current_backend_cors_origin.empty?
						workspace.info("Using existing backend CORS origin from tfvars: #{current_backend_cors_origin}")
						return
					end

					tfvars["rails_cors_allowed_origins"] = ""
					persist_tfvars(tfvars)
					workspace.info("No frontend_domain configured and no existing backend CORS origin; proceeding with empty CORS origin for first boot.")
				end

				# Post-apply cleanup:
				# - Only update when backend CORS is currently empty.
				# - Only update when frontend live URL exists.
				# - Returns true when tfvars changed, false otherwise.
				def fill_backend_cors_origin_from_live_frontend_url_if_missing!
					tfvars = load_tfvars
					return false if backend_cors_origin_present?(tfvars)

					frontend_live_url = frontend_live_url_from_tfvars(tfvars)
					unless frontend_live_url_present?(frontend_live_url)
						workspace.info("Post-apply CORS cleanup: frontend live URL not available yet; backend CORS remains empty.")
						return false
					end

					tfvars["rails_cors_allowed_origins"] = frontend_live_url
					persist_tfvars(tfvars)
					workspace.ok("Post-apply CORS cleanup updated rails_cors_allowed_origins to #{frontend_live_url}")
					true
				end

				private

				attr_reader :manifest_configuration, :terraform_workspace, :workspace

				def configured_frontend_domain_origin(environment:)
					raw_value = manifest_configuration.read(environment: environment).fetch("frontend_domain", "")
					normalize_origin(raw_value)
				end

				def backend_cors_origin_from_tfvars(tfvars)
					normalize_origin(tfvars["rails_cors_allowed_origins"])
				end

				def backend_cors_origin_present?(tfvars)
					!backend_cors_origin_from_tfvars(tfvars).empty?
				end

				def frontend_live_url_from_tfvars(tfvars)
					frontend_app_name = tfvars["frontend_app_name"].to_s.strip
					return "" if frontend_app_name.empty?

					output, success = workspace.capture("doctl apps list --output json")
					return "" unless success

					apps = JSON.parse(output)
					return "" unless apps.is_a?(Array)

					frontend_app = apps.find do |app|
						spec = app["spec"] || {}
						spec["name"].to_s == frontend_app_name
					end
					return "" unless frontend_app.is_a?(Hash)

					ingress = frontend_app["default_ingress"].to_s.strip
					normalize_origin(ingress)
				rescue JSON::ParserError
					""
				end

				def frontend_live_url_present?(frontend_live_url)
					!frontend_live_url.to_s.strip.empty?
				end

				def normalize_origin(value)
					candidate = value.to_s.strip
					return "" if candidate.empty?

					return candidate if candidate.start_with?("http://", "https://")

					"https://#{candidate}"
				end

				def load_tfvars
					path = terraform_workspace.var_file_path
					return {} unless File.exist?(path)

					raw = File.read(path)
					parsed = JSON.parse(raw)
					parsed.is_a?(Hash) ? parsed : {}
				rescue JSON::ParserError
					{}
				end

				def persist_tfvars(tfvars)
					path = terraform_workspace.var_file_path
					File.write(path, JSON.pretty_generate(tfvars) + "\n")
				end
			end
		end
	end
end
