# frozen_string_literal: true

require "stringio"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/digital_ocean/github_app_authorization"

class InfraGithubAppAuthorizationTest < Minitest::Test
  def test_returns_true_when_user_completes_flow
    prompt = mock("prompt")
    prompt.expects(:yes?).with("Open DigitalOcean GitHub authorization?", default: true).returns(true)
    prompt.expects(:yes?).with("Did you grant DigitalOcean access to all listed repositories?", default: true).returns(true)

    stdin = StringIO.new("\n")
    stdout = StringIO.new

    service = Workspace::Services::Infra::Digitalocean::GithubAppAuthorization.new(
      prompt: prompt,
      stdin: stdin,
      stdout: stdout
    )
    service.expects(:open_authorization_url).returns(true)

    result = service.call(repositories: ["org/api", "org/web"])

    assert_equal true, result
    assert_includes stdout.string, "Configuring DigitalOcean App Platform source access"
    assert_includes stdout.string, "org/api"
    assert_includes stdout.string, "org/web"
  end

  def test_returns_false_when_user_skips_opening_authorization
    prompt = mock("prompt")
    prompt.expects(:yes?).with("Open DigitalOcean GitHub authorization?", default: true).returns(false)

    stdin = StringIO.new
    stdout = StringIO.new

    result = Workspace::Services::Infra::Digitalocean::GithubAppAuthorization.new(
      prompt: prompt,
      stdin: stdin,
      stdout: stdout
    ).call(repositories: ["org/api", "org/web"])

    assert_equal false, result
  end

  def test_prints_manual_url_when_open_fails
    prompt = mock("prompt")
    prompt.expects(:yes?).with("Open DigitalOcean GitHub authorization?", default: true).returns(true)
    prompt.expects(:yes?).with("Did you grant DigitalOcean access to all listed repositories?", default: true).returns(true)

    stdin = StringIO.new("\n")
    stdout = StringIO.new

    service = Workspace::Services::Infra::Digitalocean::GithubAppAuthorization.new(
      prompt: prompt,
      stdin: stdin,
      stdout: stdout
    )
    service.expects(:open_authorization_url).returns(false)

    result = service.call(repositories: ["org/api", "org/web"])

    assert_equal true, result
    assert_includes stdout.string, "Open this page manually:"
    assert_includes stdout.string, Workspace::Services::Infra::Digitalocean::GithubAppAuthorization::AUTHORIZATION_URL
  end
end
