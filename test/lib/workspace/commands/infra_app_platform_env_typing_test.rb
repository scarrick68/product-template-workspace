# frozen_string_literal: true

require_relative "../../../test_helper"

class InfraAppPlatformEnvTypingTest < Minitest::Test
  APP_PLATFORM_MAIN_TF = File.join(
    Workspace::ROOT,
    "infra",
    "digitalocean",
    "modules",
    "app_platform",
    "main.tf"
  ).freeze

  def test_sensitive_runtime_urls_are_declared_as_secret_keys
    keys_block = extract_block(terraform_content, "secret_env_keys = toset([", "])\n\n\toptional_api_env")

    assert_includes(keys_block, '"DATABASE_URL"')
    assert_includes(keys_block, '"OPENSEARCH_URL"')
  end

  def test_sensitive_runtime_urls_are_part_of_optional_runtime_env
    env_block = extract_block(terraform_content, "optional_api_env = {", "}\n\n\tfiltered_optional_api_env")

    assert_includes(env_block, "DATABASE_URL           = var.database_url")
    assert_includes(env_block, "OPENSEARCH_URL         = var.opensearch_url")
  end

  def test_runtime_env_entries_use_secret_classification_logic_in_all_runtime_components
    lines = terraform_content.lines.select { |line| line.include?("type  = contains(local.secret_env_keys, env.key)") }
    assert_equal(3, lines.size, "expected secret classification in api, worker, and migrate runtime env blocks")
  end

  private

  def terraform_content
    @terraform_content ||= File.read(APP_PLATFORM_MAIN_TF)
  end

  def extract_block(content, start_marker, end_marker)
    start_index = content.index(start_marker)
    refute_nil(start_index, "missing start marker: #{start_marker}")

    end_index = content.index(end_marker, start_index)
    refute_nil(end_index, "missing end marker: #{end_marker}")

    content[start_index...end_index]
  end
end
