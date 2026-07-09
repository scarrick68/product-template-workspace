# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/spaces_bootstrapper"

class InfraSpacesBootstrapperTest < Minitest::Test
  def setup
    @original_access_key = ENV["SPACES_ACCESS_KEY_ID"]
    @original_secret_key = ENV["SPACES_SECRET_ACCESS_KEY"]
    @config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    File.stubs(:exist?).with(@config_file).returns(false)
  end

  def teardown
    ENV["SPACES_ACCESS_KEY_ID"] = @original_access_key
    ENV["SPACES_SECRET_ACCESS_KEY"] = @original_secret_key
  end

  def test_bootstrap_skips_when_managed_spaces_disabled
    Workspace.stubs(:info)

    bootstrapper = Workspace::Commands::Infra::SpacesBootstrapper.new(
      terraform_var_file_name: "terraform.tfvars.json"
    )

    tfvars = {
      "enable_spaces" => false,
      "spaces_provider" => "digitalocean_spaces"
    }

    status = bootstrapper.bootstrap!(
      tfvars: tfvars,
      write_tfvars: ->(_values) { flunk("write_tfvars should not be called") }
    )

    assert_equal :skipped, status
  end

  def test_bootstrap_returns_already_present_when_credentials_exist
    Workspace.stubs(:ok)

    bootstrapper = Workspace::Commands::Infra::SpacesBootstrapper.new(
      terraform_var_file_name: "terraform.tfvars.json"
    )

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "spaces_access_key_id" => "existing-id",
      "spaces_secret_access_key" => "existing-secret"
    }

    status = bootstrapper.bootstrap!(
      tfvars: tfvars,
      write_tfvars: ->(_values) { flunk("write_tfvars should not be called") }
    )

    assert_equal :already_present, status
  end

  def test_bootstrap_creates_and_persists_credentials
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get").returns(["", true])

    expected_command = "doctl spaces keys create app-prod-artifacts-bootstrap-123 --grants permission\\=fullaccess -o json"
    json_output = [{ "access_key" => "new-id", "secret_key" => "new-secret" }].to_json
    Workspace.stubs(:capture).with(expected_command).returns([json_output, true])

    Time.stubs(:now).returns(Time.at(123))

    written = nil
    bootstrapper = Workspace::Commands::Infra::SpacesBootstrapper.new(
      terraform_var_file_name: "terraform.tfvars.json"
    )

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "app_name" => "app",
      "environment" => "prod",
      "do_region" => "nyc3"
    }

    status = bootstrapper.bootstrap!(
      tfvars: tfvars,
      write_tfvars: ->(values) { written = values.dup }
    )

    assert_equal :created, status
    assert_equal "new-id", ENV["SPACES_ACCESS_KEY_ID"]
    assert_equal "new-secret", ENV["SPACES_SECRET_ACCESS_KEY"]
    assert_equal "new-id", written["spaces_access_key_id"]
    assert_equal "new-secret", written["spaces_secret_access_key"]
    assert_equal "new-id", written["aws_access_key_id"]
    assert_equal "new-secret", written["aws_secret_access_key"]
    assert_equal "app-prod-artifacts", written["data_artifact_bucket"]
    assert_equal "https://nyc3.digitaloceanspaces.com", written["s3_endpoint"]
  end

  def test_bootstrap_redacts_secrets_in_failure_output
    Workspace.stubs(:info)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get").returns(["", true])

    fullaccess_command = "doctl spaces keys create app-prod-artifacts-bootstrap-123 --grants permission\\=fullaccess -o json"
    Workspace.stubs(:capture).with(fullaccess_command).returns([
      '{"access_key":"raw-id","secret_key":"raw-secret"}',
      false
    ])

    Time.stubs(:now).returns(Time.at(123))

    Workspace.expects(:abort_with_help).with(
      "Unable to create Spaces access key via doctl.",
      has_entry(details: includes("[REDACTED]"))
    ).raises(SystemExit.new(1))

    bootstrapper = Workspace::Commands::Infra::SpacesBootstrapper.new(
      terraform_var_file_name: "terraform.tfvars.json"
    )

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "app_name" => "app",
      "environment" => "prod",
      "do_region" => "nyc3"
    }

    assert_raises(SystemExit) do
      bootstrapper.bootstrap!(tfvars: tfvars, write_tfvars: ->(_values) { flunk("should not write") })
    end
  end

  def test_bootstrap_uses_explicit_doctl_access_token_when_provided
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get --access-token token").returns(["", true])

    expected_command = "doctl spaces keys create app-prod-artifacts-bootstrap-123 --grants permission\\=fullaccess -o json --access-token token"
    json_output = [{ "access_key" => "new-id", "secret_key" => "new-secret" }].to_json
    Workspace.stubs(:capture).with(expected_command).returns([json_output, true])

    Time.stubs(:now).returns(Time.at(123))

    written = nil
    bootstrapper = Workspace::Commands::Infra::SpacesBootstrapper.new(
      terraform_var_file_name: "terraform.tfvars.json"
    )

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "app_name" => "app",
      "environment" => "prod",
      "do_region" => "nyc3"
    }

    status = bootstrapper.bootstrap!(
      tfvars: tfvars,
      write_tfvars: ->(values) { written = values.dup },
      doctl_access_token: "token"
    )

    assert_equal :created, status
    assert_equal "new-id", written["spaces_access_key_id"]
    assert_equal "new-secret", written["spaces_secret_access_key"]
  end

  def test_bootstrap_uses_bucket_scoped_grant_when_bucket_is_not_managed
    Workspace.stubs(:ok)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:capture).with("doctl account get").returns(["", true])

    expected_command = "doctl spaces keys create app-prod-artifacts-bootstrap-123 --grants bucket\\=app-prod-artifacts\\;permission\\=readwrite -o json"
    json_output = [{ "access_key" => "new-id", "secret_key" => "new-secret" }].to_json
    Workspace.stubs(:capture).with(expected_command).returns([json_output, true])

    Time.stubs(:now).returns(Time.at(123))

    written = nil
    bootstrapper = Workspace::Commands::Infra::SpacesBootstrapper.new(
      terraform_var_file_name: "terraform.tfvars.json"
    )

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "spaces_create_bucket" => false,
      "app_name" => "app",
      "environment" => "prod",
      "do_region" => "nyc3"
    }

    status = bootstrapper.bootstrap!(
      tfvars: tfvars,
      write_tfvars: ->(values) { written = values.dup }
    )

    assert_equal :created, status
    assert_equal "new-id", written["spaces_access_key_id"]
    assert_equal "new-secret", written["spaces_secret_access_key"]
  end
end
