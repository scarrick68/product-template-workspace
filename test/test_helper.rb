# frozen_string_literal: true

require "minitest/autorun"
require "mocha/minitest"
require "fileutils"
require "tmpdir"

require_relative "../lib/workspace"
require_relative "../lib/workspace/commands/bootstrap_command"
require_relative "../lib/workspace/commands/preinstall_command"
require_relative "../lib/workspace/commands/doctor_command"
require_relative "../lib/workspace/commands/pull_command"
require_relative "../lib/workspace/commands/status_command"
require_relative "../lib/workspace/commands/dev_command"
require_relative "../lib/workspace/commands/start_day_command"
require_relative "../lib/workspace/commands/init_new_project_command"
require_relative "../lib/workspace/commands/sync_openapi_command"
require_relative "../lib/product_templates/renamer"
require_relative "../lib/product_templates/validator"
