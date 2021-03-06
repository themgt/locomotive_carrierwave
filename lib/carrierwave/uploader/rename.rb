# encoding: utf-8

module CarrierWave
  module Uploader
    module Rename
      extend ActiveSupport::Concern

      include CarrierWave::Uploader::Callbacks

      included do
        after :rename, :recreate_versions!
      end

      ##
      # Override this method in your uploader to check if the model has been updated.
      #
      # Some comments about not working for sequel and datamapper, maybe...
      # === Returns
      #
      # [NilClass, Boolean] true if the model has been changed, false otherwise
      #
      def stale_model?
        self.model.persisted? && self.model.send("#{self.mounted_as}_changed?") rescue false
      end

      def rename?
        @rename || false
      end

      ##
      # Renames the file
      #
      def rename!
        return true if !self.rename?

        with_callbacks(:rename) do
          @file = storage.rename!(@original_file)
          @original_file = nil
          @rename = false
        end
      end

      private

      def check_stale_model!
        # the conditions below means: already an existing file, with model, model has been modified and not changing the file currently.
        @rename = self.file && self.model && self.stale_model? && @cache_id.nil?

        if self.rename?
          @original_file = self.file.clone
          @filename = self.model.send(:_mounter, self.mounted_as).identifier # default filename has to be the one from the model
        end
      end

    end # Rename
  end # Uploader
end # CarrierWave
