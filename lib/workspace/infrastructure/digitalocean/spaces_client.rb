# frozen_string_literal: true

require "aws-sdk-s3"

module Workspace
  module Infrastructure
    module DigitalOcean
      # S3-compatible client for managing DigitalOcean Spaces buckets and objects.
      class SpacesClient
        def initialize(region:, access_key_id:, secret_access_key:)
          @client = Aws::S3::Client.new(
            region: region,
            endpoint: "https://#{region}.digitaloceanspaces.com",
            force_path_style: false,
            credentials: Aws::Credentials.new(
              access_key_id,
              secret_access_key
            )
          )
        end

        def buckets
          client.list_buckets.buckets
        end

        def bucket_exists?(name)
          client.head_bucket(bucket: name)
          true
        rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
          false
        end

        def delete_bucket(name)
          empty_bucket(name)
          client.delete_bucket(bucket: name)
        end

        private

        attr_reader :client

        def empty_bucket(name)
          delete_current_objects(name)
          delete_versions(name)
        end

        def delete_current_objects(name)
          client
            .list_objects_v2(bucket: name)
            .each_page do |page|
              delete_objects(
                name,
                page.contents.map { |object| { key: object.key } }
              )
            end
        end

        def delete_versions(name)
          client
            .list_object_versions(bucket: name)
            .each_page do |page|
              objects =
                page.versions.map do |version|
                  {
                    key: version.key,
                    version_id: version.version_id
                  }
                end

              objects.concat(
                page.delete_markers.map do |marker|
                  {
                    key: marker.key,
                    version_id: marker.version_id
                  }
                end
              )

              delete_objects(name, objects)
            end
        end

        def delete_objects(bucket, objects)
          objects.each_slice(1000) do |batch|
            next if batch.empty?

            client.delete_objects(
              bucket: bucket,
              delete: {
                objects: batch,
                quiet: true
              }
            )
          end
        end
      end
    end
  end
end
