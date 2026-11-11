ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # An uploaded file as Active Storage sees it after a direct upload.
    def new_blob(content_type = "image/png", filename: "file.png")
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new("test-bytes"), filename: filename, content_type: content_type
      )
    end

    # Ordered media entries as the seller form submits them: signed blob ids by kind.
    def media_entries(images: 1, videos: 0, documents: 0)
      [
        *Array.new(images) { { kind: "image", signed_id: new_blob("image/png").signed_id } },
        *Array.new(videos) { { kind: "video", signed_id: new_blob("video/mp4", filename: "clip.mp4").signed_id } },
        *Array.new(documents) { { kind: "document", signed_id: new_blob("application/pdf", filename: "doc.pdf").signed_id } }
      ]
    end
  end
end
