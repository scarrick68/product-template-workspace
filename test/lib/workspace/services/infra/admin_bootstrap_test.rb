# frozen_string_literal: true

require "stringio"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/digital_ocean/admin_bootstrap"

class AdminBootstrapServiceTest < Minitest::Test
  def test_load_or_create_admin_generates_password_when_missing
    credentials_store = mock("credentials_store")
    credentials_store.expects(:read_hash)
      .with("environments.production.application.admin")
      .returns(nil)
    credentials_store.expects(:write_hash!) do |key, value, **kwargs|
      assert_equal "environments.production.application.admin", key
      assert_equal "ops@example.com", value.fetch("email")
      assert_operator value.fetch("password").length, :>=, 20
      assert_match(/\A[A-Za-z0-9_-]+\z/, value.fetch("password"))
      assert_equal "Could not save the generated admin credentials.", kwargs.fetch(:message)
      true
    end

    prompt = mock("prompt")
    prompt.expects(:ask).with("Initial admin email", required: true).returns("ops@example.com")

    stdin = Struct.new(:tty?) do
      def tty? = true
    end.new

    service = Workspace::Services::Infra::Digitalocean::AdminBootstrap.new(
      terraform_workspace: Struct.new(:directory).new("/tmp"),
      stdin: stdin,
      stdout: StringIO.new,
      prompt: prompt,
      credentials_store: credentials_store
    )

    admin = service.send(:load_or_create_admin, "production")

    assert_equal "ops@example.com", admin.fetch("email")
    assert_operator admin.fetch("password").length, :>=, 20
  end

  def test_load_or_create_admin_reprompts_until_email_is_valid
    credentials_store = mock("credentials_store")
    credentials_store.expects(:read_hash)
      .with("environments.production.application.admin")
      .returns(nil)
    credentials_store.expects(:write_hash!) do |key, value, **kwargs|
      assert_equal "environments.production.application.admin", key
      assert_equal "ops@example.com", value.fetch("email")
      assert_operator value.fetch("password").length, :>=, 20
      assert_equal "Could not save the generated admin credentials.", kwargs.fetch(:message)
      true
    end

    prompt = mock("prompt")
    prompt.expects(:ask).with("Initial admin email", required: true).twice.returns("not-an-email", "ops@example.com")

    workspace = mock("workspace")
    workspace.expects(:error).with("Invalid admin email format: \"not-an-email\". Please enter a valid email address.")

    stdin = Struct.new(:tty?) do
      def tty? = true
    end.new

    service = Workspace::Services::Infra::Digitalocean::AdminBootstrap.new(
      terraform_workspace: Struct.new(:directory).new("/tmp"),
      stdin: stdin,
      stdout: StringIO.new,
      prompt: prompt,
      workspace: workspace,
      credentials_store: credentials_store
    )

    admin = service.send(:load_or_create_admin, "production")

    assert_equal "ops@example.com", admin.fetch("email")
  end

  def test_load_or_create_admin_ignores_invalid_stored_email_and_prompts_again
    credentials_store = mock("credentials_store")
    credentials_store.expects(:read_hash)
      .with("environments.production.application.admin")
      .returns({ "email" => "invalid", "password" => "existing-password" })
    credentials_store.expects(:write_hash!) do |key, value, **kwargs|
      assert_equal "environments.production.application.admin", key
      assert_equal "ops@example.com", value.fetch("email")
      assert_operator value.fetch("password").length, :>=, 20
      assert_equal "Could not save the generated admin credentials.", kwargs.fetch(:message)
      true
    end

    prompt = mock("prompt")
    prompt.expects(:ask).with("Initial admin email", required: true).returns("ops@example.com")

    stdin = Struct.new(:tty?) do
      def tty? = true
    end.new

    service = Workspace::Services::Infra::Digitalocean::AdminBootstrap.new(
      terraform_workspace: Struct.new(:directory).new("/tmp"),
      stdin: stdin,
      stdout: StringIO.new,
      prompt: prompt,
      credentials_store: credentials_store
    )

    admin = service.send(:load_or_create_admin, "production")

    assert_equal "ops@example.com", admin.fetch("email")
  end
end
