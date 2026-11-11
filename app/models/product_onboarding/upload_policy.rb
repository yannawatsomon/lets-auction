module ProductOnboarding
  # What a seller may upload (docs/decision/product-onboarding.md, proposed). Pure Ruby, so it
  # needs no storage: the same check runs before an upload target is issued and again on what
  # actually arrives, because the declared type and size are only a claim.
  module UploadPolicy
    class Rejected < StandardError; end

    LIMITS = {
      "image" => { types: %w[image/jpeg image/png image/webp], types_label: "JPEG, PNG, WebP", max_bytes: 10.megabytes },
      "video" => { types: %w[video/mp4], types_label: "MP4", max_bytes: 200.megabytes },
      "document" => { types: %w[application/pdf image/jpeg image/png], types_label: "PDF, JPEG, PNG", max_bytes: 20.megabytes }
    }.freeze

    def self.max_label(kind) = "#{LIMITS.fetch(kind)[:max_bytes] / 1.megabyte} MB"

    def self.check!(kind:, content_type:, size:)
      rule = LIMITS[kind] if kind.is_a?(String)
      raise Rejected, "Unknown file kind" unless rule
      raise Rejected, "#{kind.capitalize} files must be #{rule[:types_label]}" unless rule[:types].include?(content_type.to_s.strip.downcase)
      raise Rejected, "File size must be a whole number of bytes above 0" unless size.is_a?(Integer) && size.positive?
      raise Rejected, "#{kind.capitalize} files can be at most #{max_label(kind)}" if size > rule[:max_bytes]
    end
  end
end
