# frozen_string_literal: true

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/credentials"

class InfraCredentialsTest < Minitest::Test
  def test_digitalocean_token_available_true_when_resolver_returns_token
    resolver = mock("resolver")
    resolver.expects(:digitalocean_token).with(interactive: false).returns("token")

    credentials = Workspace::Services::Infra::Credentials.new(secrets_resolver: resolver)

    assert_equal true, credentials.digitalocean_token_available?
  end

  def test_export_terraform_environment_sets_env_when_token_present
    resolver = mock("resolver")
    resolver.expects(:digitalocean_token).with(interactive: true).returns("token")

    credentials = Workspace::Services::Infra::Credentials.new(secrets_resolver: resolver)

    begin
      ENV.delete("DIGITALOCEAN_ACCESS_TOKEN")
      assert_equal true, credentials.export_terraform_environment!(interactive: true)
      assert_equal "token", ENV["DIGITALOCEAN_ACCESS_TOKEN"]
    ensure
      ENV.delete("DIGITALOCEAN_ACCESS_TOKEN")
    end
  end

  def test_export_terraform_environment_returns_false_when_token_missing
    resolver = mock("resolver")
    resolver.expects(:digitalocean_token).with(interactive: false).returns(nil)

    credentials = Workspace::Services::Infra::Credentials.new(secrets_resolver: resolver)

    assert_equal false, credentials.export_terraform_environment!(interactive: false)
  end
end
