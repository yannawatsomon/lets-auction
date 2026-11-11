# Demo auctions for trying the bidding pages (#36 follow-up, MOCK_BIDDING demo).
#   bin/rails bidding:demo_seed
# Runs only in development, or in production while the bidding demo is on (MOCK_BIDDING=true with
# a demo password). Replaces earlier demo auctions (titles starting "ตัวอย่าง:"); touches nothing
# else. Uses bidding's YAML demo products and mock users only.
namespace :bidding do
  desc "Create demo auctions (sealed open, English live, closed awaiting results, draft)"
  task demo_seed: :environment do
    allowed = Rails.env.development? || (Rails.env.production? && Rails.configuration.x.mock_bidding)
    abort "bidding:demo_seed runs only in development or with the MOCK_BIDDING demo on" unless allowed

    BiddingDemoSeed.run
  end
end

module BiddingDemoSeed
  module_function

  def make(title, type, lots, inc: nil)
    a = Auction.create!(title:, auction_type: type, starts_at: 1.hour.from_now, ends_at: 2.hours.from_now,
      created_by_id: 1, description: "ข้อมูลตัวอย่างสำหรับดูหน้าเว็บ (เดโม)")
    lots.each { |i| a.add_item!(i, bid_increment_cents: inc) }
    a.schedule!
    a
  end

  def go_live(a, now, ends_in)
    a.update_columns(starts_at: now - 10.minutes, ends_at: now + ends_in, status: "live")
    a.lots.update_all(status: "live")
  end

  # Test cleanup-style deletes are fine here: only demo auctions are removed, never real bids.
  def run
    now = Time.current
    admin = MockData.user(1)
    items = MockData.approved_items.sort_by(&:min_price_cents)
    small = items.select { |i| i.min_price_cents < 100_000_000 }
    big = items.select { |i| i.min_price_cents >= 100_000_000 }
    Auction.where("title LIKE ?", "ตัวอย่าง:%").find_each do |a|
      a.lots.each { |l| l.update_columns(leader_bid_id: nil) }
      Bid.where(lot_id: a.lots.select(:id)).delete_all
      AuctionParticipant.where(auction_id: a.id).delete_all
      AuctionLot.where(auction_id: a.id).delete_all
      a.delete
    end

    # 1. Sealed, open now: buyers 22 and 23 have bid; 21 (grade A) registered but hasn't bid.
    s = make("ตัวอย่าง: งานยื่นซอง (เปิดรับอยู่)", "sealed_first_price", small.first(2))
    [ 21, 22, 23 ].each { |id| AuctionParticipant.register!(auction: s, user: MockData.user(id)) }
    go_live(s, now, 2.days)
    lot = s.lots.first
    { 22 => "18,500", 23 => "17,250.50" }.each do |id, amt|
      Bidding::PlaceSealedBid.call(lot:, user: MockData.user(id), amount_text: amt, idempotency_key: "demo-s-#{id}", now:)
    end

    # 2. English, live now: 21 invited+accepted (grade A). 26 is added straight as accepted so two
    #    people can outbid each other in the demo (in production only approved grade A can be invited).
    e = make("ตัวอย่าง: English ประมูลสด", "english", big.first(1), inc: 50_000_000)
    AuctionParticipant.invite!(auction: e, user: MockData.user(21), admin:).accept!(user: MockData.user(21))
    AuctionParticipant.create!(auction: e, user_id: 26, source: "invited", status: "accepted", invited_by_id: 1, grade_at_entry: "A", accepted_at: now)
    go_live(e, now, 3.hours)
    el = e.lots.first
    Bidding::PlaceEnglishBid.call(lot: el, user: MockData.user(26), amount_text: Baht.format(el.min_price_cents), idempotency_key: "demo-e-1", now:)

    # 3. Sealed, already closed and waiting for the admin to approve results (A3 page).
    c = make("ตัวอย่าง: งานที่ปิดแล้ว รอประกาศผล", "sealed_first_price", small.last(1))
    [ 21, 22, 23 ].each { |id| AuctionParticipant.register!(auction: c, user: MockData.user(id)) }
    c.update_columns(starts_at: now - 2.days, ends_at: now - 1.hour, status: "live")
    c.lots.update_all(status: "live")
    cl = c.lots.first
    { 21 => 25_000, 22 => 23_000, 23 => 23_000 }.each_with_index do |(id, extra), i|
      Bid.create!(lot: cl, user_id: id, amount: cl.min_price_cents + extra * 100, idempotency_key: "demo-c-#{id}", created_at: now - 1.day + i)
    end
    Bidding::CloseAuction.call(auction: c, now:)

    # 4. A draft to show the admin build screen.
    d = Auction.create!(title: "ตัวอย่าง: งานร่าง (ยังไม่เผยแพร่)", auction_type: "sealed_first_price",
      starts_at: 3.days.from_now, ends_at: 5.days.from_now, created_by_id: 1)

    puts({ sealed_open: s.id, sealed_lot: lot.id, english: e.id, english_lot: el.id, closed: c.id, closed_lot: cl.id, draft: d.id }.to_json)
  end
end
