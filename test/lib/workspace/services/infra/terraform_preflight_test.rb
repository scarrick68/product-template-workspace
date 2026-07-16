# frozen_string_literal: true

require "stringio"

require_relative "../../../../test_helper"
require_relative "../../../../../lib/workspace/services/infra/terraform_preflight"

class TerraformPreflightTest < Minitest::Test
  def test_check_passes_when_directory_and_var_file_exist
    workspace = stub_workspace

    Dir.expects(:exist?).with(workspace.directory).returns(true)
    File.expects(:exist?).with(workspace.var_file_path).returns(true)

    Workspace::Services::Infra::TerraformPreflight.new(workspace: workspace).check!
  end

  def test_check_aborts_when_terraform_directory_missing
    workspace = stub_workspace

    Dir.expects(:exist?).with(workspace.directory).returns(false)
    Workspace.expects(:abort_with_help).with(
      "Terraform directory is missing.",
      has_entry(details: "Expected directory: #{workspace.directory}")
    ).raises(SystemExit.new(1))

    assert_raises(SystemExit) do
      Workspace::Services::Infra::TerraformPreflight.new(workspace: workspace).check!
    end
  end

  def test_check_aborts_when_var_file_missing
    workspace = stub_workspace

    Dir.expects(:exist?).with(workspace.directory).returns(true)
    File.expects(:exist?).with(workspace.var_file_path).returns(false)

    Workspace.expects(:abort_with_help).with(
      "Missing Terraform var-file.",
      has_entry(details: "Expected file: #{workspace.var_file_path}")
    ).raises(SystemExit.new(1))

    assert_raises(SystemExit) do
      Workspace::Services::Infra::TerraformPreflight.new(workspace: workspace).check!
    end
  end

  private

  def stub_workspace
    Struct.new(:directory, :var_file_path, :var_file_name).new(
      "/tmp/infra/digitalocean_v2",
      "/tmp/infra/digitalocean_v2/terraform.tfvars.json",
      "terraform.tfvars.json"
    )
  end
end
