# encoding: utf-8
begin
  require 'fog'
rescue LoadError
  raise "You don't have the 'fog' gem installed. The 'aws', 'aws-s3' and 'right_aws' gems are no longer supported."
end

module CarrierWave
  module Storage

    ##
    # Uploads things to Amazon S3 using the "fog" gem.
    # You'll need to specify the access_key_id, secret_access_key and bucket.
    #
    #     CarrierWave.configure do |config|
    #       config.s3_access_key_id = "xxxxxx"
    #       config.s3_secret_access_key = "xxxxxx"
    #       config.s3_bucket = "my_bucket_name"
    #     end
    #
    # You can set the access policy for the uploaded files:
    #
    #     CarrierWave.configure do |config|
    #       config.s3_access_policy = :public_read
    #     end
    #
    # The default is :public_read. For more options see:
    #
    # http://docs.amazonwebservices.com/AmazonS3/latest/RESTAccessPolicy.html#RESTCannedAccessPolicies
    #
    # The following access policies are available:
    #
    # [:private]              No one else has any access rights.
    # [:public_read]          The anonymous principal is granted READ access.
    #                         If this policy is used on an object, it can be read from a
    #                         browser with no authentication.
    # [:public_read_write]    The anonymous principal is granted READ and WRITE access.
    # [:authenticated_read]   Any principal authenticated as a registered Amazon S3 user
    #                         is granted READ access.
    #
    # You can change the generated url to a cnamed domain by setting the cname config:
    #
    #     CarrierWave.configure do |config|
    #       config.s3_cname = 'bucketname.domain.tld'
    #       config.s3_bucket = 'bucketname' # only used when storing / deleting files
    #     end
    #
    # Now the resulting url will be
    #
    #     http://bucketname.domain.tld/path/to/file
    #
    # instead of
    #
    #     http://bucketname.domain.tld.s3.amazonaws.com/path/to/file
    #
    class S3 < Abstract

      class File

        def initialize(uploader, base, path)
          @uploader = uploader
          @path = path
          @base = base
        end

        ##
        # Returns the current path of the file on S3
        #
        # === Returns
        #
        # [String] A path
        #
        def path
          @path
        end

        ##
        # Reads the contents of the file from S3
        #
        # === Returns
        #
        # [String] contents of the file
        #
        def read
          result = connection.get_object(bucket, @path)
          @headers = result.headers
          result.body
        end

        ##
        # Remove the file from Amazon S3
        #
        def delete
          connection.delete_object(bucket, @path)
        end

        def rename(new_path)
          file = connection.put_object(bucket, new_path, read,
            {
              'x-amz-acl' => access_policy.to_s.gsub('_', '-'),
              'Content-Type' => content_type
            }.merge(@uploader.s3_headers)
          )
          delete
          file
        end

        ##
        # Returns the url on Amazon's S3 service
        #
        # === Returns
        #
        # [String] file's url
        #
        def url
          if access_policy == :authenticated_read
            authenticated_url
          else
            public_url
          end
        end

        def public_url
          if cnamed?
            ["http://#{cname}", path].compact.join('/')
          else
            ["http://#{bucket}.s3.amazonaws.com", path].compact.join('/')
          end
        end

        def authenticated_url
          connection.get_object_url(bucket, path, Time.now + 60 * 10)
        end

        def store(file)
          content_type ||= file.content_type # this might cause problems if content type changes between read and upload (unlikely)
          connection.put_object(bucket, path, file.read,
            {
              'x-amz-acl' => access_policy.to_s.gsub('_', '-'),
              'Content-Type' => content_type,
            }.merge(@uploader.s3_headers)
          )
        end

        def content_type
          headers["Content-Type"]
        end

        def content_type=(type)
          headers["Content-Type"] = type
        end

        def size
           headers['Content-Length'].to_i
        end

        # Headers returned from file retrieval
        def headers
          @headers ||= begin
            connection.head_object(bucket, @path).headers
          rescue Excon::Errors::NotFound # Don't die, just return no headers
            {}
          end
        end

      private

        def cname
          @uploader.s3_cname
        end

        def cnamed?
          !@uploader.s3_cname.nil?
        end

        def access_policy
          @uploader.s3_access_policy
        end

        def bucket
          @uploader.s3_bucket
        end

        def connection
          @base.connection
        end

      end

      ##
      # Store the file on S3
      #
      # === Parameters
      #
      # [file (CarrierWave::SanitizedFile)] the file to store
      #
      # === Returns
      #
      # [CarrierWave::Storage::S3::File] the stored file
      #
      def store!(file)
        f = CarrierWave::Storage::S3::File.new(uploader, self, uploader.store_path)
        f.store(file)
        f
      end

      # Do something to retrieve the file
      #
      # @param [String] identifier uniquely identifies the file
      #
      # [identifier (String)] uniquely identifies the file
      #
      # === Returns
      #
      # [CarrierWave::Storage::S3::File] the stored file
      #
      def retrieve!(identifier)
        CarrierWave::Storage::S3::File.new(uploader, self, uploader.store_path(identifier))
      end

      ##
      # Rename a file on S3
      #
      # === Parameters
      #
      # [file (CarrierWave::Storage::S3::File)] the file to rename
      #
      # === Returns
      #
      # [CarrierWave::Storage::S3::File] the renamed file
      #
      def rename!(file)
        path = uploader.store_path
        file.rename(path)
        CarrierWave::Storage::S3::File.new(uploader, self, path)
      end

      def connection
        @connection ||= Fog::AWS::Storage.new(
          :aws_access_key_id => uploader.s3_access_key_id,
          :aws_secret_access_key => uploader.s3_secret_access_key
        )
      end

    end # S3
  end # Storage
end # CarrierWave

# module CarrierWave; module Storage; class S3 < Abstract; def connection; @connection ||= Fog::AWS::Storage.new(:aws_access_key_id => uploader.s3_access_key_id, :aws_secret_access_key => uploader.s3_secret_access_key, :host => uploader.s3_cnamed ? uploader.s3_bucket : nil); end; end; end; end
