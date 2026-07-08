# frozen_string_literal: true

require_relative "../../../test_helper"

class InfraProjectGroupingTfTest < Minitest::Test
  def test_project_tf_declares_project_and_resource_assignment
    path = File.join(Workspace::ROOT, "infra", "digitalocean", "project.tf")
    content = File.read(path)

    assert_includes(content, 'resource "digitalocean_project" "this"')
    assert_includes(content, 'resource "digitalocean_project_resources" "this"')
    assert_includes(content, "module.app_platform.app_urn")
    assert_includes(content, "module.postgres[0].cluster_urn")
    assert_includes(content, "module.opensearch[0].cluster_urn")
    assert_includes(content, "module.spaces[0].bucket_urn")
  end
end
