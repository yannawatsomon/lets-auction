require "test_helper"

class ProductOnboardingUploadPolicyTest < ActiveSupport::TestCase
  Policy = ProductOnboarding::UploadPolicy

  def check(kind: "image", content_type: "image/jpeg", size: 1_000)
    Policy.check!(kind: kind, content_type: content_type, size: size)
  end

  test "accepts each kind at exactly its size limit" do
    check(kind: "image", content_type: "image/webp", size: 10.megabytes)
    check(kind: "video", content_type: "video/mp4", size: 200.megabytes)
    check(kind: "document", content_type: "application/pdf", size: 20.megabytes)
  end

  test "rejects one byte over the limit and names the limit" do
    { "image" => [ "image/jpeg", "10 MB" ], "video" => [ "video/mp4", "200 MB" ],
      "document" => [ "application/pdf", "20 MB" ] }.each do |kind, (type, label)|
      error = assert_raises(Policy::Rejected, kind) { check(kind: kind, content_type: type, size: Policy::LIMITS.fetch(kind)[:max_bytes] + 1) }
      assert_match label, error.message
    end
  end

  test "rejects types that are not allowed for the kind" do
    [ [ "image", "image/svg+xml" ], [ "image", "text/html" ], [ "video", "video/quicktime" ],
      [ "document", "application/msword" ] ].each do |kind, type|
      assert_raises(Policy::Rejected, "#{kind} #{type}") { check(kind: kind, content_type: type) }
    end
  end

  test "rejects a bad kind, content type or size" do
    [ { kind: "audio" }, { kind: nil }, { content_type: nil }, { size: 0 }, { size: -5 }, { size: 1.5 }, { size: "100" } ].each do |bad|
      assert_raises(Policy::Rejected, bad.inspect) { check(**bad) }
    end
  end
end
