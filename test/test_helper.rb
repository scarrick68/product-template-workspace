# frozen_string_literal: true

require "minitest/autorun"
require "mocha/minitest"
require "factory_bot"
require "fileutils"
require "tmpdir"

require_relative "../lib/workspace"
require_relative "../lib/workspace/services/bootstrap"
require_relative "../lib/workspace/services/preinstall_checks"
require_relative "../lib/workspace/services/doctor"
require_relative "../lib/workspace/services/pull"
require_relative "../lib/workspace/services/status"
require_relative "../lib/workspace/services/dev"
require_relative "../lib/workspace/services/install_local_dev_tools"
require_relative "../lib/workspace/services/start_day"
require_relative "../lib/workspace/services/init_new_project"
require_relative "../lib/workspace/services/new_project"
require_relative "../lib/workspace/services/sync_openapi"
require_relative "../lib/product_templates/renamer"
require_relative "../lib/product_templates/validator"

FactoryBot.definition_file_paths = [
	File.expand_path("factories", __dir__)
]
FactoryBot.find_definitions

class Minitest::Test
	include FactoryBot::Syntax::Methods
end
