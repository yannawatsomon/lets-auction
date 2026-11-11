module ProductOnboarding
  # MOCK store for uploads: remembers each issued upload target in memory (no real files, no
  # storage service). With real storage, `issue!` becomes a signed direct-upload URL, `receive!`
  # the storage service's own check, and `purge_orphans!` a recurring job that purges
  # unattached blobs (see ai/knowledge/product-onboarding-integration-points.md).
  module UploadStore
    ORPHAN_AFTER = 48.hours
    LOCK = Monitor.new
    Upload = Data.define(:key, :seller_id, :kind, :filename, :content_type, :byte_size, :created_at, :uploaded, :attached)

    class << self
      def all = synchronize { uploads.values }

      def find(key) = synchronize { uploads[key.to_s] }

      # Checks the declared file against the policy, then issues a key the seller uploads to.
      def issue!(seller_id:, kind:, filename:, content_type:, size:)
        UploadPolicy.check!(kind: kind, content_type: content_type, size: size)
        upload = Upload.new(key: SecureRandom.urlsafe_base64(24), seller_id: seller_id, kind: kind,
                            filename: File.basename(filename.to_s).first(255), content_type: content_type.to_s.strip.downcase,
                            byte_size: size, created_at: Time.current, uploaded: false, attached: false)
        synchronize { uploads[upload.key] = upload }
      end

      # What really arrived must match what was declared and still pass the policy.
      def receive!(key, seller_id:, content_type:, byte_size:)
        synchronize do
          upload = find_owned!(key, seller_id)
          type = content_type.to_s.strip.downcase
          UploadPolicy.check!(kind: upload.kind, content_type: type, size: byte_size)
          raise UploadPolicy::Rejected, "The uploaded file does not match what was declared" unless type == upload.content_type && byte_size == upload.byte_size

          uploads[upload.key] = upload.with(uploaded: true)
        end
      end

      # All or nothing: used when a product is submitted with these files.
      def attach!(keys, seller_id:)
        synchronize do
          found = keys.map { |key| find_owned!(key, seller_id) }
          raise UploadPolicy::Rejected, "Some files have not finished uploading" unless found.all?(&:uploaded)

          found.each { |upload| uploads[upload.key] = upload.with(attached: true) }
        end
      end

      # Removes files never attached to a product after ORPHAN_AFTER. Returns how many.
      def purge_orphans!(now: Time.current)
        synchronize do
          expired = uploads.values.reject { |upload| upload.attached || upload.created_at > now - ORPHAN_AFTER }
          expired.each { |upload| uploads.delete(upload.key) }
          expired.size
        end
      end

      def reset! = synchronize { @uploads = {} }

      def synchronize(&) = LOCK.synchronize(&)

      private

      def uploads = @uploads ||= {}

      def find_owned!(key, seller_id)
        upload = uploads[key.to_s]
        raise NotFound, "No upload with that key" unless upload && upload.seller_id == seller_id.to_i

        upload
      end
    end
  end
end
