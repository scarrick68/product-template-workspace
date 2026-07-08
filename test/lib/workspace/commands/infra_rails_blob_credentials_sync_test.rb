# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/rails_blob_credentials_sync"

class InfraRailsBlobCredentialsSyncTest < Minitest::Test
  def setup
    @sync = Workspace::Commands::Infra::RailsBlobCredentialsSync.new(workspace_root: Workspace::ROOT)
    @config_file = File.join(Workspace::ROOT, "config", "infra.yml")
    File.stubs(:exist?).with(@config_file).returns(false)
  end

  def test_sync_noops_when_spaces_are_disabled
    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "path" => "repos/api-template" }
    ])

    tfvars = {
      "enable_spaces" => false,
      "spaces_provider" => "digitalocean_spaces",
      "aws_access_key_id" => "id",
      "aws_secret_access_key" => "secret"
    }

    Workspace.expects(:capture).never
    Workspace.expects(:run).never

    @sync.sync!(tfvars: tfvars)
  end

  def test_sync_noops_when_credentials_are_missing
    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "path" => "repos/api-template" }
    ])

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "aws_access_key_id" => "",
      "aws_secret_access_key" => ""
    }

    Workspace.expects(:capture).never
    Workspace.expects(:run).never

    @sync.sync!(tfvars: tfvars)
  end

  def test_sync_updates_credentials_storage_and_production_config
    api_root = File.join(Workspace::ROOT, "repos", "api-template")

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "path" => "repos/api-template" }
    ])
    Dir.stubs(:exist?).with(api_root).returns(true)

    storage_path = File.join(api_root, "config", "storage.yml")
    production_path = File.join(api_root, "config", "environments", "production.rb")

    File.stubs(:exist?).with(storage_path).returns(true)
    File.stubs(:exist?).with(production_path).returns(true)
    File.stubs(:read).with(storage_path).returns("local:\n  service: Disk\n")
    File.stubs(:read).with(production_path).returns("config.active_storage.service = :local\n")

    Workspace.stubs(:capture).with("bin/rails credentials:show", chdir: api_root).returns([{}.to_yaml, true])

    File.expects(:write).with(storage_path, includes("Rails.application.credentials.dig(:aws, :access_key_id)"))
    File.expects(:write).with(
      production_path,
      includes("config.active_storage.service = ENV.fetch(\"ACTIVE_STORAGE_SERVICE\", \"amazon\").to_sym")
    )

    Dir.expects(:mktmpdir).with("infra-rails-creds").yields("/tmp/rails-sync")
    File.stubs(:write).with("/tmp/rails-sync/credentials.yml", kind_of(String))
    File.stubs(:write).with("/tmp/rails-sync/credentials.backup.yml", kind_of(String))
    File.stubs(:write).with("/tmp/rails-sync/editor.sh", kind_of(String))
    File.stubs(:chmod).with(0o600, "/tmp/rails-sync/credentials.backup.yml")
    File.stubs(:chmod).with(0o755, "/tmp/rails-sync/editor.sh")
    Workspace.expects(:run).with(
      "EDITOR=/tmp/rails-sync/editor.sh bin/rails credentials:edit",
      chdir: api_root
    )

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "aws_access_key_id" => "id",
      "aws_secret_access_key" => "secret",
      "s3_endpoint" => "https://nyc3.digitaloceanspaces.com",
      "do_region" => "nyc3",
      "data_artifact_bucket" => "app-prod-artifacts"
    }

    @sync.sync!(tfvars: tfvars)
  end

  def test_sync_runs_for_aws_provider
    api_root = File.join(Workspace::ROOT, "repos", "api-template")

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "path" => "repos/api-template" }
    ])
    Dir.stubs(:exist?).with(api_root).returns(true)

    storage_path = File.join(api_root, "config", "storage.yml")
    production_path = File.join(api_root, "config", "environments", "production.rb")

    File.stubs(:exist?).with(storage_path).returns(true)
    File.stubs(:exist?).with(production_path).returns(true)
    File.stubs(:read).with(storage_path).returns("local:\n  service: Disk\n")
    File.stubs(:read).with(production_path).returns("config.active_storage.service = :local\n")

    Workspace.expects(:capture).with("bin/rails credentials:show", chdir: api_root).returns([{}.to_yaml, true])

    File.stubs(:write).with(storage_path, kind_of(String))
    File.stubs(:write).with(production_path, kind_of(String))

    Dir.stubs(:mktmpdir).with("infra-rails-creds").yields("/tmp/rails-sync")
    File.stubs(:write).with("/tmp/rails-sync/credentials.yml", kind_of(String))
    File.stubs(:write).with("/tmp/rails-sync/credentials.backup.yml", kind_of(String))
    File.stubs(:write).with("/tmp/rails-sync/editor.sh", kind_of(String))
    File.stubs(:chmod).with(0o600, "/tmp/rails-sync/credentials.backup.yml")
    File.stubs(:chmod).with(0o755, "/tmp/rails-sync/editor.sh")
    Workspace.stubs(:run).with("EDITOR=/tmp/rails-sync/editor.sh bin/rails credentials:edit", chdir: api_root)

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "aws_s3",
      "aws_access_key_id" => "id",
      "aws_secret_access_key" => "secret",
      "s3_endpoint" => "https://s3.amazonaws.com",
      "do_region" => "us-east-1",
      "data_artifact_bucket" => "app-prod-artifacts"
    }

    @sync.sync!(tfvars: tfvars)
  end

  def test_sync_prefers_terraform_outputs_for_effective_runtime_values
    api_root = File.join(Workspace::ROOT, "repos", "api-template")

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "path" => "repos/api-template" }
    ])
    Dir.stubs(:exist?).with(api_root).returns(true)

    storage_path = File.join(api_root, "config", "storage.yml")
    production_path = File.join(api_root, "config", "environments", "production.rb")

    File.stubs(:exist?).with(storage_path).returns(true)
    File.stubs(:exist?).with(production_path).returns(true)
    File.stubs(:read).with(storage_path).returns("local:\n  service: Disk\n")
    File.stubs(:read).with(production_path).returns("config.active_storage.service = :local\n")

    Workspace.stubs(:capture).with("bin/rails credentials:show", chdir: api_root).returns([{}.to_yaml, true])

    File.stubs(:write).with(storage_path, kind_of(String))
    File.stubs(:write).with(production_path, kind_of(String))

    Dir.expects(:mktmpdir).with("infra-rails-creds").yields("/tmp/rails-sync")
    File.expects(:write).with do |path, content|
      next false unless path == "/tmp/rails-sync/credentials.yml"

      content.include?("access_key_id: output-id") &&
        content.include?("secret_access_key: output-secret") &&
        content.include?("endpoint: https://output-endpoint") &&
        content.include?("bucket: output-bucket")
    end
    File.stubs(:write).with("/tmp/rails-sync/credentials.backup.yml", kind_of(String))
    File.stubs(:write).with("/tmp/rails-sync/editor.sh", kind_of(String))
    File.stubs(:chmod).with(0o600, "/tmp/rails-sync/credentials.backup.yml")
    File.stubs(:chmod).with(0o755, "/tmp/rails-sync/editor.sh")
    Workspace.stubs(:run).with("EDITOR=/tmp/rails-sync/editor.sh bin/rails credentials:edit", chdir: api_root)

    tfvars = {
      "enable_spaces" => true,
      "spaces_provider" => "digitalocean_spaces",
      "aws_access_key_id" => "tfvars-id",
      "aws_secret_access_key" => "tfvars-secret",
      "s3_endpoint" => "https://tfvars-endpoint",
      "do_region" => "nyc3",
      "data_artifact_bucket" => "tfvars-bucket"
    }

    outputs = {
      "aws_access_key_id" => "output-id",
      "aws_secret_access_key" => "output-secret",
      "s3_endpoint" => "https://output-endpoint",
      "spaces_bucket" => "output-bucket"
    }

    @sync.sync!(tfvars: tfvars, terraform_outputs: outputs)
  end
end
