# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/secrets/factory"
require_relative "../../../../lib/workspace/secrets/resolver"

class SecretsResolverTest < Minitest::Test
  class FakeWorkspaceAdapter
    attr_reader :writes

    def initialize(values = {}, available: true, writable: true, write_success: true)
      @values = values.dup
      @available = available
      @writable = writable
      @write_success = write_success
      @writes = []
    end

    def available?
      @available
    end

    def writable?
      @writable
    end

    def read(key)
      @values[key]
    end

    def write(key, value)
      return false unless @write_success

      @writes << [key, value]
      @values[key] = value
      true
    end

    def name
      "workspace credentials"
    end
  end

  class TtyInput < StringIO
    def tty?
      true
    end
  end

  def test_returns_workspace_token_noninteractive
    adapter = FakeWorkspaceAdapter.new(
      { "DIGITALOCEAN_ACCESS_TOKEN" => "workspace-token" }
    )
    prompt = strict_prompt

    resolver = build_resolver(
      adapter: adapter,
      prompt: prompt,
      stdin: StringIO.new
    )

    assert_equal(
      "workspace-token",
      resolver.digitalocean_token(interactive: false)
    )
    assert_empty adapter.writes
  end

  def test_returns_nil_noninteractive_when_workspace_token_missing
    adapter = FakeWorkspaceAdapter.new
    prompt = strict_prompt

    resolver = build_resolver(
      adapter: adapter,
      prompt: prompt,
      stdin: StringIO.new
    )

    assert_nil resolver.digitalocean_token(interactive: false)
    assert_empty adapter.writes
  end

  def test_returns_existing_workspace_token_without_prompting
    adapter = FakeWorkspaceAdapter.new(
      { "DIGITALOCEAN_ACCESS_TOKEN" => "workspace-token" }
    )
    prompt = strict_prompt

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "workspace-token",
      resolver.digitalocean_token(interactive: true)
    )
    assert_empty adapter.writes
  end

  def test_prompts_for_token_when_missing_and_saves
    adapter = FakeWorkspaceAdapter.new
    prompt = mock("prompt")

    prompt.expects(:yes?).never

    prompt.expects(:mask)
      .with("DigitalOcean access token")
      .returns("new-token")

    prompt.expects(:say).with(
      "Saved DIGITALOCEAN_ACCESS_TOKEN to workspace credentials."
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "new-token",
      resolver.digitalocean_token(interactive: true)
    )

    assert_equal(
      [
        ["DIGITALOCEAN_ACCESS_TOKEN", "new-token"]
      ],
      adapter.writes
    )
  end

  def test_returns_nil_when_prompted_token_is_blank
    adapter = FakeWorkspaceAdapter.new
    prompt = mock("prompt")

    prompt.expects(:yes?).never

    prompt.expects(:mask)
      .with("DigitalOcean access token")
      .returns("  ")

    prompt.expects(:say).never

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_nil resolver.digitalocean_token(interactive: true)
    assert_empty adapter.writes
  end

  def test_reports_when_workspace_credentials_are_unavailable
    adapter = FakeWorkspaceAdapter.new(available: false)
    prompt = mock("prompt")

    prompt.expects(:yes?).never

    prompt.expects(:mask)
      .with("DigitalOcean access token")
      .returns("new-token")

    prompt.expects(:say).with(
      "Unable to save DIGITALOCEAN_ACCESS_TOKEN to workspace credentials. " \
      "Run: bin/workspace credentials init"
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "new-token",
      resolver.digitalocean_token(interactive: true)
    )
    assert_empty adapter.writes
  end

  def test_reports_when_workspace_credentials_are_not_writable
    adapter = FakeWorkspaceAdapter.new(writable: false)
    prompt = mock("prompt")

    prompt.expects(:mask)
      .with("DigitalOcean Spaces secret access key")
      .returns("spaces-secret")

    prompt.expects(:say).with(
      "Unable to save SPACES_SECRET_ACCESS_KEY to workspace credentials. " \
      "Run: bin/workspace credentials init"
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "spaces-secret",
      resolver.spaces_secret_access_key(interactive: true)
    )
    assert_empty adapter.writes
  end

  def test_reports_when_workspace_credentials_write_fails
    adapter = FakeWorkspaceAdapter.new(write_success: false)
    prompt = mock("prompt")

    prompt.expects(:ask)
      .with("DigitalOcean Spaces access key ID")
      .returns("spaces-id")

    prompt.expects(:say).with(
      "Unable to save SPACES_ACCESS_KEY_ID to workspace credentials. " \
      "Run: bin/workspace credentials init"
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "spaces-id",
      resolver.spaces_access_key_id(interactive: true)
    )
    assert_empty adapter.writes
  end

  def test_spaces_access_key_id_prefers_workspace_value
    adapter = FakeWorkspaceAdapter.new(
      { "SPACES_ACCESS_KEY_ID" => "spaces-id" }
    )
    prompt = strict_prompt

    resolver = build_resolver(
      adapter: adapter,
      prompt: prompt,
      stdin: StringIO.new
    )

    assert_equal(
      "spaces-id",
      resolver.spaces_access_key_id(interactive: false)
    )
    assert_empty adapter.writes
  end

  def test_spaces_access_key_id_returns_nil_noninteractive_when_missing
    adapter = FakeWorkspaceAdapter.new
    prompt = strict_prompt

    resolver = build_resolver(
      adapter: adapter,
      prompt: prompt,
      stdin: StringIO.new
    )

    assert_nil resolver.spaces_access_key_id(interactive: false)
    assert_empty adapter.writes
  end

  def test_spaces_access_key_id_prompts_and_persists_when_missing
    adapter = FakeWorkspaceAdapter.new
    prompt = mock("prompt")

    prompt.expects(:ask)
      .with("DigitalOcean Spaces access key ID")
      .returns("spaces-id")

    prompt.expects(:say).with(
      "Saved SPACES_ACCESS_KEY_ID to workspace credentials."
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "spaces-id",
      resolver.spaces_access_key_id(interactive: true)
    )

    assert_equal(
      [
        ["SPACES_ACCESS_KEY_ID", "spaces-id"]
      ],
      adapter.writes
    )
  end

  def test_spaces_secret_access_key_prefers_workspace_value
    adapter = FakeWorkspaceAdapter.new(
      { "SPACES_SECRET_ACCESS_KEY" => "spaces-secret" }
    )
    prompt = strict_prompt

    resolver = build_resolver(
      adapter: adapter,
      prompt: prompt,
      stdin: StringIO.new
    )

    assert_equal(
      "spaces-secret",
      resolver.spaces_secret_access_key(interactive: false)
    )
    assert_empty adapter.writes
  end

  def test_spaces_secret_access_key_does_not_use_environment
    adapter = FakeWorkspaceAdapter.new
    prompt = strict_prompt

    resolver = build_resolver(
      adapter: adapter,
      prompt: prompt,
      stdin: StringIO.new
    )

    original_value = ENV["SPACES_SECRET_ACCESS_KEY"]
    ENV["SPACES_SECRET_ACCESS_KEY"] = "environment-secret"

    assert_nil resolver.spaces_secret_access_key(interactive: false)
    assert_empty adapter.writes
  ensure
    if original_value
      ENV["SPACES_SECRET_ACCESS_KEY"] = original_value
    else
      ENV.delete("SPACES_SECRET_ACCESS_KEY")
    end
  end

  def test_spaces_secret_access_key_prompts_and_persists_when_missing
    adapter = FakeWorkspaceAdapter.new
    prompt = mock("prompt")

    prompt.expects(:mask)
      .with("DigitalOcean Spaces secret access key")
      .returns("spaces-secret")

    prompt.expects(:say).with(
      "Saved SPACES_SECRET_ACCESS_KEY to workspace credentials."
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert_equal(
      "spaces-secret",
      resolver.spaces_secret_access_key(interactive: true)
    )

    assert_equal(
      [
        ["SPACES_SECRET_ACCESS_KEY", "spaces-secret"]
      ],
      adapter.writes
    )
  end

  def test_persist_spaces_credentials_writes_both_values
    adapter = FakeWorkspaceAdapter.new
    prompt = mock("prompt")

    prompt.expects(:say).with(
      "Saved SPACES_ACCESS_KEY_ID to workspace credentials."
    )

    prompt.expects(:say).with(
      "Saved SPACES_SECRET_ACCESS_KEY to workspace credentials."
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    assert resolver.persist_spaces_credentials(
      access_key_id: "spaces-id",
      secret_access_key: "spaces-secret"
    )

    assert_equal(
      [
        ["SPACES_ACCESS_KEY_ID", "spaces-id"],
        ["SPACES_SECRET_ACCESS_KEY", "spaces-secret"]
      ],
      adapter.writes
    )
  end

  def test_persist_spaces_credentials_returns_false_when_a_write_fails
    adapter = FakeWorkspaceAdapter.new(write_success: false)
    prompt = mock("prompt")

    prompt.expects(:say).with(
      "Unable to save SPACES_ACCESS_KEY_ID to workspace credentials. " \
      "Run: bin/workspace credentials init"
    )

    prompt.expects(:say).with(
      "Unable to save SPACES_SECRET_ACCESS_KEY to workspace credentials. " \
      "Run: bin/workspace credentials init"
    )

    resolver = build_resolver(adapter: adapter, prompt: prompt)

    refute resolver.persist_spaces_credentials(
      access_key_id: "spaces-id",
      secret_access_key: "spaces-secret"
    )

    assert_empty adapter.writes
  end

  def test_factory_returns_macos_adapter_on_darwin
    adapter = Workspace::Secrets::Factory.keychain_adapter(
      platform: "darwin22"
    )

    assert_instance_of(
      Workspace::Secrets::Adapters::MacosKeychain,
      adapter
    )
  end

  def test_factory_returns_unsupported_adapter_elsewhere
    adapter = Workspace::Secrets::Factory.keychain_adapter(
      platform: "linux-gnu"
    )

    assert_instance_of(
      Workspace::Secrets::Adapters::UnsupportedKeychain,
      adapter
    )
  end

  def test_factory_returns_workspace_credentials_adapter
    adapter = Workspace::Secrets::Factory.workspace_credentials_adapter

    assert_instance_of(
      Workspace::Secrets::Adapters::WorkspaceCredentials,
      adapter
    )
  end

  private

  def build_resolver(adapter:, prompt:, stdin: TtyInput.new)
    Workspace::Secrets::Resolver.new(
      stdout: StringIO.new,
      stdin: stdin,
      workspace_adapter: adapter,
      prompt: prompt
    )
  end

  def strict_prompt
    prompt = mock("prompt")
    prompt.expects(:yes?).never
    prompt.expects(:ask).never
    prompt.expects(:mask).never
    prompt.expects(:say).never
    prompt
  end
end