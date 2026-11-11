module ProductOnboarding
  # One file attached to a product (an image, a video or a verification document).
  # `key` identifies the file: with real storage it is the Active Storage signed blob id.
  MediaFile = Data.define(:kind, :key, :filename, :content_type, :byte_size) do
    def initialize(kind:, key:, filename: nil, content_type: nil, byte_size: nil)
      super(kind: kind.to_s, key: key, filename: filename, content_type: content_type, byte_size: byte_size)
    end
  end
end
