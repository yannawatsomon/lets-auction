# Mock sellers, an admin, categories and three products, one in each state a seller sees
# before approval is settled: pending_review, info_requested (with the admin's note), approved.
# Idempotent: records are found by email / name / title and only created when missing.

pixel_png = Base64.decode64(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
)

mock_media = lambda do |count|
  Array.new(count) do |i|
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(pixel_png), filename: "mock-#{i + 1}.png", content_type: "image/png"
    )
    { kind: "image", signed_id: blob.signed_id }
  end
end

seller = User.find_or_create_by!(email: "seller@lets-auction.test") { |u| u.role = "seller" }
admin = User.find_or_create_by!(email: "admin@lets-auction.test") { |u| u.role = "admin" }
User.find_or_create_by!(email: "buyer@lets-auction.test") { |u| u.role = "buyer" }

watches = Category.find_or_create_by!(name: "Watches")
Category.find_or_create_by!(name: "Jewellery")
Category.find_or_create_by!(name: "Art")

mock_items = [
  { title: "Vintage dress watch, 1972", category: watches, price_thb: 85_000, images: 3, state: :pending_review,
    description: "Steel case, original strap, running. Light scratches on the crystal." },
  { title: "Gold signet ring", category: Category.find_by!(name: "Jewellery"), price_thb: 24_000, images: 2,
    state: :info_requested, note: "Please add a photo of the hallmark.",
    description: "18k gold, size 54. Inherited, no box." },
  { title: "Oil painting, harbour at dusk", category: Category.find_by!(name: "Art"), price_thb: 150_000, images: 5,
    state: :approved, description: "Oil on canvas, 60 x 80 cm, signed lower right." }
]

mock_items.each do |attrs|
  next if Item.exists?(seller: seller, title: attrs[:title])

  Item.transaction do
    item = Item.create!(
      seller: seller, category: attrs[:category], title: attrs[:title],
      description: attrs[:description], min_price_cents: attrs[:price_thb] * 100
    )
    item.sync_media!(mock_media.call(attrs[:images]))

    case attrs[:state]
    when :info_requested
      ItemReview.create!(item: item, admin: admin, action: "request_info", note: attrs[:note])
      item.transition!(:info_requested)
    when :approved
      ItemReview.create!(item: item, admin: admin, action: "approve")
      item.transition!(:approved)
    end
  end
end
