require 'nobrainer'
require 'digest/sha2'
require_relative 'timestamps'

module Condo
  module Backend

    #
    # The following data needs to be stored in any backend
    # => provider_namespace (for handling multiple upload controllers, defaults to global)
    # => provider_name        (amazon, rackspace, google, azure etc)
    # => provider_location    (US West (Oregon) Region, Asia Pacific (Singapore) Region etc)
    # => user_id            (the identifier for the current user as a string)
    # => file_name            (the original upload file name)
    # => file_size            (the file size as indicated by the client)
    # => file_id            (some sort of identifying hash provided by the client)
    # => bucket_name        (the name of the users bucket)
    # => object_key            (the path to the object in the bucket)
    # => object_options        (custom options that were applied to this object - public/private etc)
    # => resumable_id        (the id of the chunked upload)
    # => resumable            (true if a resumable upload - must be set)
    # => date_created        (the date the upload was started)
    #
    # => Each backend should have an ID that uniquely identifies an entry - id or upload_id
    #
    #
    #
    # Backends should inherit this class, set themselves as the backend and define the following:
    #
    # Class Methods:
    # => check_exists        ({user_id, upload_id})                            returns nil or an entry where all fields match
    #         check_exists    ({user_id, file_name, file_size, file_id})        so same logic for this
    # => add_entry ({user_id, file_name, file_size, file_id, provider_name, provider_location, bucket_name, object_key})
    #
    #
    #
    # Instance Methods:
    # => update_entry ({upload_id, resumable_id})
    # => remove_entry (upload_id)
    #
    class RethinkDB
      include NoBrainer::Document
      include Condo::Backend::Timestamps

      table_config name: 'engine_uploads'

      # the identifier for the current user as a string
      field :user_id,            type: String
      # the original upload file name
      field :file_name,          type: String
      # the file size as indicated by the client
      field :file_size,          type: Integer
      # some sort of identifying hash provided by the client
      field :file_id,            type: String
      # for handling multiple upload controllers, defaults to global
      field :provider_namespace, type: String
      # one of amazon, rackspace, google, azure
      field :provider_name,      type: String
      # US West (Oregon) Region, Asia Pacific (Singapore) Region etc
      field :provider_location,  type: String
      # the name of the users bucket
      field :bucket_name,        type: String
      # the path to the object in the bucket
      field :object_key,         type: String
      # custom options that were applied to this object - public/private etc
      field :object_options,     type: Hash
      # the id of the chunked upload
      field :resumable_id,       type: String
      # true if a resumable upload - must be set
      field :resumable,          type: String
      # the original path of the file (if a folder is dragged and dropped)
      field :file_path,          type: String
      # A list of part IDs that make up the final upload
      field :part_list,          type: Array
      # details of the current part being uploaded (MD5, size, path etc)
      field :part_data,          type: Hash

      # Checks for an exact match in the database given a set of parameters
      # returns nil or an entry where all fields match
      def self.check_exists(params)
        upload_id = params.delete(:upload_id)
        upload_id ||= "upld-#{params[:user_id]}-#{Digest::SHA256.hexdigest("#{params[:file_id]}-#{params[:file_name]}-#{params[:file_size]}")}"
        self.find?(upload_id)
      end

      # Adds a new upload entry into the database
      def self.add_entry(params)
        model = self.new
        [:user_id, :file_name, :file_size, :file_id,
        :provider_namespace, :provider_name, :provider_location, :bucket_name,
        :object_key, :object_options, :resumable_id, :resumable, :file_path,
        :part_list, :part_data].each { |key| model.__send__("#{key}=", params[key]) if params[key] }
        model.save!
        model
      end

      def self.older_than(time)
        old_upload = time.to_i
        uploads = []
        self.all_uploads.each do |upload|
          uploads << upload if upload.created_at < old_upload
        end
        uploads
      end

      def self.all_uploads
        self.all
      end

      # Updates self with the passed in parameters
      def update_entry(params)
        self.assign_attributes(params)
        result = self.save
        raise ActiveResource::ResourceInvalid if result == false
        self
      end

      # Deletes references to the upload
      def remove_entry
        self.destroy
      end

      # Attribute accessors to comply with the backend spec
      def upload_id
        self.id
      end

      def date_created
        @date_created ||= Time.at(self.created_at)
      end

      # Provide a clean up function that uses the condo strata to delete itself
      # NOTE:: this won't work with completely dynamic providers so is really just here
      #  as a helper if you have pre-defined storage providers
      def cleanup
        options = {}
        options[:namespace] = self.provider_namespace if self.provider_namespace
        options[:location] = self.provider_location if self.provider_location
        residence = ::Condo::Configuration.get_residence(self.provider_name, options)

        if residence
          residence.destroy(self)
          self.remove_entry
        else
          raise NotImplementedError, 'unable to find static residence'
        end
      end

      protected

      before_create :generate_id
      def generate_id
        self.id = "upld-#{self.user_id}-#{Digest::SHA256.hexdigest("#{self.file_id}-#{self.file_name}-#{self.file_size}")}"
      end
    end
  end
end
