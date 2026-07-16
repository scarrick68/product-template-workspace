# frozen_string_literal: true

require "stringio"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/configuration_prompt"

class ConfigurationPromptTest < Minitest::Test
  def test_call_returns_normalized_configuration_hash
    prompt = mock("tty-prompt")
    output = StringIO.new

    prompt.expects(:ask).with("app_name", default: "my-app").returns("my-app")
    prompt.expects(:ask).with("region", default: "nyc").returns("sfo")
    prompt.expects(:ask).with("do_region", default: "nyc3").returns("sfo3")
    prompt.expects(:ask).with("github.owner", default: "acme").returns("acme")
    prompt.expects(:ask).with("github.api_repo", default: "api-repo").returns("api-repo")
    prompt.expects(:ask).with("github.web_repo", default: "web-repo").returns("web-repo")
    prompt.expects(:ask).with("github.branch", default: "main").returns("main")
    prompt.expects(:yes?).with("components.postgres", default: true).returns(true)
    prompt.expects(:yes?).with("components.opensearch", default: false).returns(false)
    prompt.expects(:yes?).with("components.spaces", default: true).returns(true)
    prompt.expects(:ask).with("blob_store_provider (digitalocean_spaces|aws_s3)", default: "digitalocean_spaces").returns("digitalocean_spaces")

    Workspace.stubs(:info)

    defaults = {
      "app_name" => "my-app",
      "region" => "nyc",
      "do_region" => "nyc3",
      "github" => {
        "owner" => "acme",
        "api_repo" => "api-repo",
        "web_repo" => "web-repo",
        "branch" => "main"
      },
      "components" => {
        "postgres" => true,
        "opensearch" => false,
        "spaces" => true
      },
      "sizes" => {
        "api" => "basic-xs",
        "worker" => "basic-s",
        "web" => "basic-m",
        "postgres" => "db-s-2vcpu-4gb",
        "opensearch" => "db-s-1vcpu-2gb"
      },
      "blob_store_provider" => "digitalocean_spaces"
    }

    config = Workspace::Services::Infra::ConfigurationPrompt.new(prompt: prompt, output: output).call(
      environment: "production",
      defaults: defaults
    )

    assert_equal "my-app", config.fetch("app_name")
    assert_equal "production", config.fetch("environment")
    assert_equal "sfo", config.fetch("region")
    assert_equal "sfo3", config.fetch("do_region")

    github = config.fetch("github")
    assert_equal "acme", github.fetch("owner")
    assert_equal "api-repo", github.fetch("api_repo")
    assert_equal "web-repo", github.fetch("web_repo")
    assert_equal "main", github.fetch("branch")
    assert_equal true, github.fetch("auto_deploy")

    components = config.fetch("components")
    assert_equal true, components.fetch("api")
    assert_equal true, components.fetch("worker")
    assert_equal true, components.fetch("web")
    assert_equal true, components.fetch("postgres")
    assert_equal false, components.fetch("opensearch")
    assert_equal true, components.fetch("spaces")

    sizes = config.fetch("sizes")
    assert_equal "basic-xs", sizes.fetch("api")
    assert_equal "basic-s", sizes.fetch("worker")
    assert_equal "basic-m", sizes.fetch("web")
    assert_equal "db-s-2vcpu-4gb", sizes.fetch("postgres")
    assert_equal "db-s-1vcpu-2gb", sizes.fetch("opensearch")

    assert_equal "digitalocean_spaces", config.fetch("blob_store_provider")
  end

  def test_call_uses_repository_and_app_defaults_when_missing
    prompt = mock("tty-prompt")
    output = StringIO.new

    Workspace.stubs(:info)
    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "api-template",
        "github" => "example-org/api-template"
      },
      {
        "purpose" => "frontend-web-client",
        "name" => "web-template",
        "github" => "example-org/web-template"
      }
    ])

    prompt.expects(:ask).with("app_name", default: "product-template").returns("product-template")
    prompt.expects(:ask).with("region", default: "nyc").returns("nyc")
    prompt.expects(:ask).with("do_region", default: "nyc3").returns("nyc3")
    prompt.expects(:ask).with("github.owner", default: "example-org").returns("example-org")
    prompt.expects(:ask).with("github.api_repo", default: "api-template").returns("api-template")
    prompt.expects(:ask).with("github.web_repo", default: "web-template").returns("web-template")
    prompt.expects(:ask).with("github.branch", default: "main").returns("main")
    prompt.expects(:yes?).with("components.postgres", default: true).returns(true)
    prompt.expects(:yes?).with("components.opensearch", default: true).returns(true)
    prompt.expects(:yes?).with("components.spaces", default: true).returns(true)
    prompt.expects(:ask).with("blob_store_provider (digitalocean_spaces|aws_s3)", default: "digitalocean_spaces").returns("digitalocean_spaces")

    config = Workspace::Services::Infra::ConfigurationPrompt.new(prompt: prompt, output: output).call(
      environment: "production",
      defaults: {}
    )

    assert_equal "product-template", config.fetch("app_name")
    assert_equal "example-org", config.fetch("github").fetch("owner")
    assert_equal "api-template", config.fetch("github").fetch("api_repo")
    assert_equal "web-template", config.fetch("github").fetch("web_repo")
  end

  def test_call_prints_aws_hint_when_spaces_enabled_and_provider_is_aws_s3
    prompt = mock("tty-prompt")
    output = StringIO.new

    Workspace.stubs(:repositories).returns([
      {
        "purpose" => "backend-api",
        "name" => "api-template",
        "github" => "example-org/api-template"
      }
    ])

    Workspace.stubs(:info)
    Workspace.expects(:info).with("Hint: run 'bin/infra doctor' after configure to verify AWS CLI and auth readiness.")

    prompt.expects(:ask).with("app_name", default: "product-template").returns("product-template")
    prompt.expects(:ask).with("region", default: "nyc").returns("nyc")
    prompt.expects(:ask).with("do_region", default: "nyc3").returns("nyc3")
    prompt.expects(:ask).with("github.owner", default: "example-org").returns("example-org")
    prompt.expects(:ask).with("github.api_repo", default: "api-template").returns("api-template")
    prompt.expects(:ask).with("github.web_repo", default: "web-template").returns("web-template")
    prompt.expects(:ask).with("github.branch", default: "main").returns("main")
    prompt.expects(:yes?).with("components.postgres", default: true).returns(true)
    prompt.expects(:yes?).with("components.opensearch", default: true).returns(true)
    prompt.expects(:yes?).with("components.spaces", default: true).returns(true)
    prompt.expects(:ask).with("blob_store_provider (digitalocean_spaces|aws_s3)", default: "digitalocean_spaces").returns("aws_s3")

    Workspace::Services::Infra::ConfigurationPrompt.new(prompt: prompt, output: output).call(
      environment: "production",
      defaults: {}
    )
  end
end
