# frozen_string_literal: true

require "stringio"

require_relative "../../../test_helper"
require_relative "../../../../lib/workspace/secrets/factory"
require_relative "../../../../lib/workspace/secrets/store"
require_relative "../../../../lib/workspace/secrets/resolver"

class SecretsResolverTest < Minitest::Test
  class FakeEnvAdapter
    def initialize(value = nil)
      @value = value
    end

    def read(_key)
      @value
    end

    def name
      "environment variable"
    end
  end

  class FakeWritableKeychainAdapter
    attr_reader :written

    def initialize(value = nil)
      @value = value
      @written = nil
    end

    def available?
      true
    end

    def writable?
      true
    end

    def read(_key)
      @value
    end

    def write(key, value)
      @written = [key, value]
      true
    end

    def name
      "Apple Keychain"
    end
  end

  class FakeUnsupportedKeychainAdapter
    def initialize(value = nil)
      @value = value
    end

    def available?
      true
    end

    def writable?
      false
    end

    def read(_key)
      @value
    end

    def name
      "unsupported OS keychain"
    end

    def warning
      "Persistent OS keychain storage is not yet supported on this platform."
    end
  end

  class TtyInput < StringIO
    def tty?
      true
    end

    def noecho
      yield self
    end
  end

  def test_returns_env_token_first
    store = build_store(env_value: "env-token", keychain_adapter: FakeWritableKeychainAdapter.new("kc-token"))
    resolver = Workspace::Secrets::Resolver.new(io: StringIO.new, input: TtyInput.new, store: store)

    assert_equal "env-token", resolver.digitalocean_token(interactive: true)
  end

  def test_returns_keychain_token_when_env_missing
    store = build_store(env_value: nil, keychain_adapter: FakeWritableKeychainAdapter.new("kc-token"))
    resolver = Workspace::Secrets::Resolver.new(io: StringIO.new, input: TtyInput.new, store: store)

    assert_equal "kc-token", resolver.digitalocean_token(interactive: true)
  end

  def test_prompts_when_env_and_keychain_missing
    io = StringIO.new
    input = TtyInput.new("1\nrun-only-token\n")
    store = build_store(env_value: nil, keychain_adapter: FakeWritableKeychainAdapter.new(nil))
    resolver = Workspace::Secrets::Resolver.new(io: io, input: input, store: store)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "run-only-token", token
    assert_includes io.string, "DigitalOcean access token not found."
  end

  def test_prints_env_instructions_when_option_two_selected
    io = StringIO.new
    input = TtyInput.new("2\n")
    store = build_store(env_value: nil, keychain_adapter: FakeWritableKeychainAdapter.new(nil))
    resolver = Workspace::Secrets::Resolver.new(io: io, input: input, store: store)

    token = resolver.digitalocean_token(interactive: true)

    assert_nil token
    assert_includes io.string, "Run:"
    assert_includes io.string, "export DIGITALOCEAN_ACCESS_TOKEN=your_token_here"
  end

  def test_writes_token_when_writable_adapter_selected
    io = StringIO.new
    input = TtyInput.new("3\nstored-token\n")
    keychain = FakeWritableKeychainAdapter.new(nil)
    store = build_store(env_value: nil, keychain_adapter: keychain)
    resolver = Workspace::Secrets::Resolver.new(io: io, input: input, store: store)

    token = resolver.digitalocean_token(interactive: true)

    assert_equal "stored-token", token
    assert_equal ["DIGITALOCEAN_ACCESS_TOKEN", "stored-token"], keychain.written
    assert_includes io.string, "Saved DIGITALOCEAN_ACCESS_TOKEN to Apple Keychain."
  end

  def test_does_not_offer_write_option_for_unsupported_adapter
    io = StringIO.new
    input = TtyInput.new("1\nrun-token\n")
    keychain = FakeUnsupportedKeychainAdapter.new(nil)
    store = build_store(env_value: nil, keychain_adapter: keychain)
    resolver = Workspace::Secrets::Resolver.new(io: io, input: input, store: store)

    resolver.digitalocean_token(interactive: true)

    refute_includes io.string, "3. Store token"
  end

  def test_warns_on_unsupported_os_adapter
    io = StringIO.new
    input = TtyInput.new("1\nrun-token\n")
    keychain = FakeUnsupportedKeychainAdapter.new(nil)
    store = build_store(env_value: nil, keychain_adapter: keychain)
    resolver = Workspace::Secrets::Resolver.new(io: io, input: input, store: store)

    resolver.digitalocean_token(interactive: true)

    assert_includes io.string, "Persistent OS keychain storage is not yet supported on this platform."
  end

  def test_factory_returns_macos_adapter_on_darwin
    adapter = Workspace::Secrets::Factory.keychain_adapter(platform: "darwin22")

    assert_instance_of Workspace::Secrets::Adapters::MacosKeychain, adapter
  end

  def test_factory_returns_unsupported_adapter_elsewhere
    adapter = Workspace::Secrets::Factory.keychain_adapter(platform: "linux-gnu")

    assert_instance_of Workspace::Secrets::Adapters::UnsupportedKeychain, adapter
  end

  private

  def build_store(env_value:, keychain_adapter:)
    Workspace::Secrets::Store.new(
      env_adapter: FakeEnvAdapter.new(env_value),
      keychain_adapter: keychain_adapter
    )
  end
end
