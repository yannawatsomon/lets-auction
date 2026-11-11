require "test_helper"

# Shared helpers for the product onboarding tests. Not a test file (no _test suffix).
module ProductOnboardingTestSupport
  CONTENT_TYPES = { "image" => "image/jpeg", "video" => "video/mp4", "document" => "application/pdf" }.freeze

  def self.included(base)
    base.setup { ProductOnboarding::Store.reset! }
  end

  def media_entry(kind = "image")
    @media_seq = (@media_seq || 0) + 1
    {
      kind: kind, key: "test-#{kind}-#{@media_seq}", filename: "#{kind}-#{@media_seq}",
      content_type: CONTENT_TYPES.fetch(kind, "application/octet-stream"), byte_size: 1_000
    }
  end

  def media_entries(images: 1, videos: 0, documents: 0)
    [
      *Array.new(images) { media_entry("image") },
      *Array.new(videos) { media_entry("video") },
      *Array.new(documents) { media_entry("document") }
    ]
  end

  # An unsaved item owned by mock seller 11 (see db/mock/users.yml).
  def build_item(**overrides)
    ProductOnboarding::Item.new(
      { seller_id: 11, category: "นาฬิกา", title: "Rare watch", description: "Boxed, 1970s",
        min_price_cents: 100_000 }.merge(overrides)
    )
  end
end
