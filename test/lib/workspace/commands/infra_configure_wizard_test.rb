# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/commands/infra/configure_wizard"

class InfraConfigureWizardTest < Minitest::Test
  def test_prompt_value_returns_default_for_blank_input
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    value = wizard.send(:prompt_value, "app_name", default: "default-app")

    assert_equal "default-app", value
  end

  def test_prompt_value_returns_explicit_input
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("custom-app\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    value = wizard.send(:prompt_value, "app_name", default: "default-app")

    assert_equal "custom-app", value
  end

  def test_prompt_bool_returns_default_for_blank_input
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    value = wizard.send(:prompt_bool, "components.spaces", default: false)

    assert_equal false, value
  end

  def test_prompt_bool_recognizes_true_values
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("yes\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    value = wizard.send(:prompt_bool, "components.spaces", default: false)

    assert_equal true, value
  end

  def test_prompt_bool_reprompts_on_unrecognized_input_and_accepts_valid_value
    output = StringIO.new
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("nope\nn\n"),
      stdout: output,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    value = wizard.send(:prompt_bool, "components.spaces", default: true)

    assert_equal false, value
    assert_includes output.string, "Invalid input 'nope'"
    assert_includes output.string, "Accepted values"
  end

  def test_collect_blob_store_provider_reprompts_on_invalid_value
    output = StringIO.new
    Workspace.stubs(:info)

    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("bad_provider\naws_s3\n"),
      stdout: output,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    provider = wizard.send(:collect_blob_store_provider, {}, spaces_enabled: true)

    assert_equal "aws_s3", provider
    assert_includes output.string, "Invalid input 'bad_provider'"
    assert_includes output.string, "Valid values: digitalocean_spaces, aws_s3"
  end

  def test_collect_app_name_uses_existing_default_when_input_blank
    Workspace.stubs(:info)

    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    app_name = wizard.send(:collect_app_name, { "app_name" => "existing-app" })

    assert_equal "existing-app", app_name
  end

  def test_collect_regions_returns_prompted_values
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("sfo\nsfo3\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    region, do_region = wizard.send(:collect_regions, {})

    assert_equal "sfo", region
    assert_equal "sfo3", do_region
  end

  def test_collect_github_data_uses_repository_defaults
    Workspace.stubs(:info)
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
        "path" => "repos/web-template"
      }
    ])

    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("\n\n\n\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    github = wizard.send(:collect_github_data, {})

    assert_equal "example-org", github["owner"]
    assert_equal "api-template", github["api_repo"]
    assert_equal "web-template", github["web_repo"]
    assert_equal "main", github["branch"]
    assert_equal true, github["auto_deploy"]
  end

  def test_collect_infra_component_toggles_respects_yes_no_input
    Workspace.stubs(:info)

    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("n\ny\nn\n"),
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    components = wizard.send(:collect_infra_component_toggles, {})

    assert_equal false, components["postgres"]
    assert_equal true, components["opensearch"]
    assert_equal false, components["spaces"]
  end

  def test_collect_blob_store_provider_prints_hint_for_aws_s3_when_spaces_enabled
    output = StringIO.new
    Workspace.stubs(:info)

    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new("aws_s3\n"),
      stdout: output,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    provider = wizard.send(:collect_blob_store_provider, {}, spaces_enabled: true)

    assert_equal "aws_s3", provider
    assert_includes output.string, "spaces_provider (digitalocean_spaces|aws_s3)"
  end

  def test_collect_sizes_uses_defaults_when_missing
    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: StringIO.new,
      stdout: StringIO.new,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    sizes = wizard.send(:collect_sizes, {})

    assert_equal "basic-xxs", sizes["api"]
    assert_equal "basic-xxs", sizes["worker"]
    assert_equal "basic-xxs", sizes["web"]
    assert_equal "db-s-1vcpu-1gb", sizes["postgres"]
    assert_equal "db-s-1vcpu-2gb", sizes["opensearch"]
  end

  def test_collect_returns_config_with_defaults_and_user_input
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
        "path" => "repos/web-template"
      }
    ])
    Workspace.stubs(:info)

    input = StringIO.new("my-product\nnyc\nnyc3\nexample-org\nmy-product-api\nmy-product-web\nmain\ny\nn\ny\naws_s3\n")
    output = StringIO.new

    wizard = Workspace::Commands::Infra::ConfigureWizard.new(
      stdin: input,
      stdout: output,
      default_opensearch_size: "db-s-1vcpu-2gb"
    )

    config = wizard.collect(environment: "production", existing: {})

    assert_equal "my-product", config["app_name"]
    assert_equal "production", config["environment"]
    assert_equal "nyc", config["region"]
    assert_equal "nyc3", config["do_region"]
    assert_equal "example-org", config.dig("github", "owner")
    assert_equal "my-product-api", config.dig("github", "api_repo")
    assert_equal "my-product-web", config.dig("github", "web_repo")
    assert_equal true, config.dig("components", "postgres")
    assert_equal false, config.dig("components", "opensearch")
    assert_equal true, config.dig("components", "spaces")
    assert_equal "aws_s3", config["spaces_provider"]
    assert_equal "db-s-1vcpu-2gb", config.dig("sizes", "opensearch")
  end
end
