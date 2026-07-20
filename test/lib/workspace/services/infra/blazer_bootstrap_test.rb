# frozen_string_literal: true

require "stringio"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/digital_ocean/blazer_bootstrap"

class BlazerBootstrapServiceTest < Minitest::Test
  def test_uses_infra_environment_as_rails_env
    service = Workspace::Services::Infra::Digitalocean::BlazerBootstrap.new(
      terraform_workspace: Struct.new(:directory).new("/tmp"),
      stdin: StringIO.new,
      stdout: StringIO.new
    )

    script = service.send(:build_bootstrap_script, rails_env: service.send(:rails_env_for, "staging"))

    assert_includes script, "RAILS_ENV=staging bin/rails blazer:default_queries:install"
    assert_includes script, "RAILS_ENV=staging bin/rails blazer:install_dashboards"
  end

  def test_defaults_to_production_when_environment_blank
    service = Workspace::Services::Infra::Digitalocean::BlazerBootstrap.new(
      terraform_workspace: Struct.new(:directory).new("/tmp"),
      stdin: StringIO.new,
      stdout: StringIO.new
    )

    script = service.send(:build_bootstrap_script, rails_env: service.send(:rails_env_for, ""))

    assert_includes script, "RAILS_ENV=production bin/rails blazer:default_queries:install"
    assert_includes script, "RAILS_ENV=production bin/rails blazer:install_dashboards"
  end
end
