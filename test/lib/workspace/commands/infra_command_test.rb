# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/services/infra/provision_infra"
require_relative "../../../../lib/workspace/services/infra/terraform_workspace"
require_relative "../../../../lib/workspace/services/infra/terraform_variables"

class InfraCommandTest < Minitest::Test
  def test_returns_usage_when_action_missing
    Workspace.expects(:info).with("Usage: bin/infra [doctor|configure|plan|apply|safe_destroy|total_destruction] [environment]")
    Workspace.expects(:info).with("Examples: bin/infra doctor | bin/infra configure production | bin/infra plan production | bin/infra safe_destroy production")

    result = Workspace::Services::Infra::ProvisionInfra.new([]).call

    assert_equal 1, result
  end

  def test_returns_one_when_action_is_unsupported
    Workspace.expects(:fail_with_help).with(
      "Unsupported infra action 'nuke'.",
      has_entry(details: "Supported actions: doctor, configure, plan, apply, safe_destroy, total_destruction")
    )

    result = Workspace::Services::Infra::ProvisionInfra.new(["nuke"]).call

    assert_equal 1, result
  end

  def test_configure_writes_project_manifest_and_tfvars
    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "api-template",
        "path" => "repos/api-template",
        "github" => "example-org/api-template"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "web-template",
        "path" => "repos/web-template",
        "github" => "example-org/web-template"
      }
    ])
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    File.stubs(:exist?).returns(false)
    File.stubs(:exist?).with(Workspace::Services::Infra::ProvisionInfra::PROJECT_MANIFEST_FILE).returns(false)

    File.expects(:write).with(Workspace::Services::Infra::ProvisionInfra::PROJECT_MANIFEST_FILE, includes("infrastructure:"))
    File.expects(:write).with(
      File.join(Workspace::Services::Infra::TerraformWorkspace::DEFAULT_DIRECTORY, "terraform.tfvars.json"),
      includes("\"project_name\": \"my-product\"")
    )

    input = StringIO.new("my-product\nnyc\nnyc3\nexample-org\nmy-product-api\nmy-product-web\nmain\ny\nn\ny\naws_s3\n")
    output = StringIO.new

    result = Workspace::Services::Infra::ProvisionInfra.new(["configure", "production"], stdin: input, stdout: output).call

    assert_equal 0, result
  end

  def test_abort_when_var_file_is_missing
    Workspace.stubs(:command_exists?).returns(true)
    Workspace.stubs(:run).returns(true)
    Workspace.stubs(:info)
    Workspace.stubs(:ok)
    Dir.stubs(:exist?).returns(true)
    File.stubs(:exist?).returns(false)

    Workspace.expects(:abort_with_help).with(
      "Missing Terraform var-file.",
      has_entry(details: "Expected file: #{File.join(Workspace::Services::Infra::TerraformWorkspace::DEFAULT_DIRECTORY, 'terraform.tfvars.json')}")
    ).raises(SystemExit.new(1))

    assert_raises(SystemExit) do
      Workspace::Services::Infra::ProvisionInfra.new(["plan"]).call
    end
  end

  def test_plan_runs_init_then_plan_with_default_var_file
    Workspace.stubs(:info)
    Workspace.stubs(:ok)
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Dir.stubs(:exist?).returns(true)
    File.stubs(:exist?).returns(true)

    sequence = sequence("infra-plan-sequence")
    terraform_dir = Workspace::Services::Infra::TerraformWorkspace::DEFAULT_DIRECTORY

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} init",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} plan -var-file=terraform.tfvars.json -out=tfplan",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    command = Workspace::Services::Infra::ProvisionInfra.new(["plan"], stdin: StringIO.new, stdout: StringIO.new)
    blob_storage_manager = mock("blob_storage_manager")
    blob_storage_manager.expects(:ensure_spaces_credentials_for_provisioning).with(environment: "production", interactive: true).returns(true)
    command.instance_variable_set(:@blob_storage_manager, blob_storage_manager)
    credentials = mock("credentials")
    credentials.expects(:export_terraform_environment!).with(interactive: true).returns(true)
    command.instance_variable_set(:@credentials, credentials)

    result = command.call

    assert_equal 0, result
  end

  def test_safe_destroy_runs_init_then_targeted_destroy
    Workspace.stubs(:info)
    Workspace.stubs(:ok)
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Dir.stubs(:exist?).returns(true)
    File.stubs(:exist?).returns(true)

    sequence = sequence("infra-safe-destroy-sequence")
    terraform_dir = Workspace::Services::Infra::TerraformWorkspace::DEFAULT_DIRECTORY

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} init",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} destroy -var-file=terraform.tfvars.json -target=digitalocean_app.rails -target=digitalocean_app.frontend",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    command = Workspace::Services::Infra::ProvisionInfra.new(["safe_destroy"], stdin: StringIO.new, stdout: StringIO.new)
    blob_storage_manager = mock("blob_storage_manager")
    blob_storage_manager.expects(:ensure_spaces_credentials_for_provisioning).with(environment: "production", interactive: true).returns(true)
    command.instance_variable_set(:@blob_storage_manager, blob_storage_manager)
    credentials = mock("credentials")
    credentials.expects(:export_terraform_environment!).with(interactive: true).returns(true)
    command.instance_variable_set(:@credentials, credentials)

    result = command.call

    assert_equal 0, result
  end

  def test_total_destruction_runs_init_then_full_destroy
    Workspace.stubs(:info)
    Workspace.stubs(:ok)
    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Dir.stubs(:exist?).returns(true)
    File.stubs(:exist?).returns(true)

    sequence = sequence("infra-total-destruction-sequence")
    terraform_dir = Workspace::Services::Infra::TerraformWorkspace::DEFAULT_DIRECTORY

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} init",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    Workspace.expects(:run).with(
      "terraform -chdir=#{terraform_dir} destroy -var-file=terraform.tfvars.json",
      chdir: Workspace::ROOT
    ).in_sequence(sequence).returns(true)

    command = Workspace::Services::Infra::ProvisionInfra.new(["total_destruction"], stdin: StringIO.new, stdout: StringIO.new)
    blob_storage_manager = mock("blob_storage_manager")
    blob_storage_manager.expects(:ensure_spaces_credentials_for_provisioning).with(environment: "production", interactive: true).returns(true)
    command.instance_variable_set(:@blob_storage_manager, blob_storage_manager)
    credentials = mock("credentials")
    credentials.expects(:export_terraform_environment!).with(interactive: true).returns(true)
    command.instance_variable_set(:@credentials, credentials)

    result = command.call

    assert_equal 0, result
  end

  def test_doctor_returns_zero_when_all_checks_pass
    Workspace.stubs(:ok)
    Workspace.stubs(:info)
    Workspace.stubs(:warn)
    Workspace.stubs(:fail)

    Workspace.stubs(:command_exists?).with("terraform").returns(true)
    Workspace.stubs(:command_exists?).with("tofu").returns(false)
    Workspace.stubs(:command_exists?).with("doctl").returns(true)
    Workspace.stubs(:command_exists?).with("gh").returns(true)
    Workspace.stubs(:command_exists?).with("git").returns(true)

    Workspace.stubs(:repositories).returns([
      { "purpose" => "backend-api", "name" => "api-template", "path" => "repos/api-template" },
      { "purpose" => "frontend-web-client", "name" => "web-template", "path" => "repos/web-template" }
    ])

    command = Workspace::Services::Infra::ProvisionInfra.new(["doctor"], stdin: StringIO.new, stdout: StringIO.new)
    resolver = mock("secrets_resolver")
    command.instance_variable_set(:@secrets_resolver, resolver)
    credentials = mock("credentials")
    credentials.expects(:digitalocean_token_env_key).returns("DIGITALOCEAN_ACCESS_TOKEN")
    credentials.expects(:digitalocean_token_available?).returns(true)
    credentials.expects(:export_terraform_environment!).with(interactive: false).returns(true)
    command.instance_variable_set(:@credentials, credentials)

    Workspace.stubs(:capture).with("doctl account get").returns(["", true])
    Workspace.stubs(:capture).with("gh auth status").returns(["", true])

    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/api-template")).returns(true)
    Dir.stubs(:exist?).with(File.join(Workspace::ROOT, "repos/web-template")).returns(true)

    File.stubs(:exist?).with(Workspace::Services::Infra::ProvisionInfra::PROJECT_MANIFEST_FILE).returns(false)

    assert_equal 0, command.call
  end

  def test_generated_tfvars_are_declared_by_root_module
    config = {
      "app_name" => "my-product",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "github" => {
        "owner" => "example-org",
        "api_repo" => "my-product-api",
        "web_repo" => "my-product-web",
        "branch" => "main"
      },
      "sizes" => {
        "api" => "basic-xxs",
        "worker" => "basic-xxs",
        "web" => "basic-xxs",
        "postgres" => "db-s-1vcpu-1gb",
        "opensearch" => "db-s-1vcpu-2gb"
      }
    }

    generated_keys = Workspace::Services::Infra::TerraformVariables.new(config).to_h.keys.sort
    declared_keys = terraform_declared_variable_names
    undeclared = generated_keys - declared_keys

    assert_empty undeclared, "Generated undeclared Terraform variables: #{undeclared.join(', ')}"
  end

  def test_tfvars_do_not_contain_credentials
    config = {
      "app_name" => "my-product",
      "environment" => "production",
      "region" => "nyc",
      "do_region" => "nyc3",
      "github" => {
        "owner" => "example-org",
        "api_repo" => "my-product-api",
        "web_repo" => "my-product-web",
        "branch" => "main"
      },
      "sizes" => {
        "opensearch" => "db-s-1vcpu-2gb"
      }
    }

    generated_keys = Workspace::Services::Infra::TerraformVariables.new(config).to_h.keys
    sensitive_keys = %w[digitalocean_access_token spaces_access_key_id spaces_secret_access_key aws_access_key_id aws_secret_access_key]

    assert_empty generated_keys & sensitive_keys
  end

  private

  def terraform_declared_variable_names
    variables_path = File.join(Workspace::Services::Infra::TerraformWorkspace::DEFAULT_DIRECTORY, "variables.tf")
    File.read(variables_path).scan(/^variable\s+"([^"]+)"/).flatten.sort
  end
end
