require "test_helper"

class AuctionParticipantTest < ActiveSupport::TestCase
  # Grades come from user onboarding's mock (db/mock/user_onboardings.yml): 21 A, 22 B,
  # 23 C, 24 D, 25 E, 26 not started. Proof of income: db/mock/bidding_income_proofs.yml (21).
  ADMIN = MockData.user(1)
  A_OK = MockData.user(21)
  B = MockData.user(22)
  C = MockData.user(23)
  D = MockData.user(24)
  E = MockData.user(25)
  NOT_ONBOARDED = MockData.user(26)
  SELLER = MockData.user(11)

  setup do
    OnboardingStore.reset!
    BuyerStanding.reset!
  end

  teardown { BuyerStanding.reset! }

  def auction(type: "sealed_first_price", schedule: true)
    a = Auction.create!(title: "งาน", auction_type: type, starts_at: 1.day.from_now, ends_at: 2.days.from_now, created_by_id: 1)
    busy = AuctionLot.where(status: AuctionLot::OPEN_STATUSES).pluck(:item_id)
    pool = MockData.approved_items.reject { |i| busy.include?(i.id) }
    item = type == "english" ? pool.max_by(&:min_price_cents) : pool.min_by(&:min_price_cents)
    a.add_item!(item, bid_increment_cents: (type == "english" ? 20_000_000 : nil))
    a.schedule! if schedule
    a
  end

  def assert_code(code, &)
    e = assert_raises(AuctionParticipant::Error, &)
    assert_equal code, e.code
    e
  end

  # --- sealed: grade A–D may register ---------------------------------------------------

  test "sealed: grades A–D register, with or without proof of income" do
    a = auction
    [ A_OK, B, C, D ].each do |u|
      p = AuctionParticipant.register!(auction: a, user: u)
      assert p.registered?
      assert p.can_bid?
      assert_equal BuyerStanding.grade(u), p.grade_at_entry
    end
  end

  test "sealed: grade E, not onboarded, seller and admin are refused" do
    a = auction
    assert_code("grade_not_allowed") { AuctionParticipant.register!(auction: a, user: E) }
    assert_code("onboarding_required") { AuctionParticipant.register!(auction: a, user: NOT_ONBOARDED) }
    assert_code("buyer_only") { AuctionParticipant.register!(auction: a, user: SELLER) }
    assert_code("buyer_only") { AuctionParticipant.register!(auction: a, user: ADMIN) }
    assert_equal 0, a.participants.count
  end

  test "sealed: registering twice returns the same row" do
    a = auction
    first = AuctionParticipant.register!(auction: a, user: C)
    assert_equal first, AuctionParticipant.register!(auction: a, user: C)
    assert_equal 1, a.participants.count
  end

  test "sealed: draft, cancelled or ended auctions are closed" do
    assert_code("registration_closed") { AuctionParticipant.register!(auction: auction(schedule: false), user: C) }
    a = auction
    assert_code("registration_closed") { AuctionParticipant.register!(auction: a, user: C, now: a.ends_at) }
    a.cancel!(reason: "ทดสอบ")
    assert_code("registration_closed") { AuctionParticipant.register!(auction: a.reload, user: C) }
  end

  test "sealed: a revoked buyer can't re-register" do
    a = auction
    AuctionParticipant.register!(auction: a, user: C).revoke!(admin: ADMIN)
    assert_code("registration_revoked") { AuctionParticipant.register!(auction: a, user: C) }
  end

  test "grade comes from user onboarding: a recalculated grade counts at the next registration" do
    a = auction
    OnboardingStore.add_assessment(CreditAssessment.new(user_id: E.id, score: 60, grade: "C", score_version: 1,
      inputs: {}.freeze, reasons: {}.freeze, created_at: Time.current))
    assert_equal "C", AuctionParticipant.register!(auction: a, user: E).grade_at_entry
  end

  test "english auctions can't be self-registered" do
    assert_code("not_sealed") { AuctionParticipant.register!(auction: auction(type: "english"), user: A_OK) }
  end

  # --- english: only grade A with approved proof can be invited --------------------------

  test "english: grade A with approved proof is invited, accepts, can bid" do
    a = auction(type: "english")
    inv = AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN)
    assert inv.invited?
    assert_not inv.can_bid?
    inv.accept!(user: A_OK)
    assert inv.reload.accepted?
    assert inv.can_bid?
  end

  test "english: proof pending, lower grades, not onboarded, sellers are refused" do
    a = auction(type: "english")
    BuyerStanding.revoke_income_proof!(A_OK.id)
    assert_code("income_proof_required") { AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN) }
    assert_code("grade_not_allowed") { AuctionParticipant.invite!(auction: a, user: B, admin: ADMIN) }
    assert_code("grade_not_allowed") { AuctionParticipant.invite!(auction: a, user: D, admin: ADMIN) }
    assert_code("grade_not_allowed") { AuctionParticipant.invite!(auction: a, user: E, admin: ADMIN) }
    assert_code("onboarding_required") { AuctionParticipant.invite!(auction: a, user: NOT_ONBOARDED, admin: ADMIN) }
    assert_code("buyer_only") { AuctionParticipant.invite!(auction: a, user: SELLER, admin: ADMIN) }
    assert_equal 0, a.participants.count
  end

  test "english: invite works on a draft, not after the start" do
    assert AuctionParticipant.invite!(auction: auction(type: "english", schedule: false), user: A_OK, admin: ADMIN)
    a = auction(type: "english")
    assert_code("auction_started") { AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN, now: a.starts_at) }
  end

  test "english: invitable list shows only grade A with approved proof, not yet invited" do
    a = auction(type: "english")
    assert_equal [ 21 ], AuctionParticipant.invitable_users(a).map(&:id)
    BuyerStanding.revoke_income_proof!(21)
    assert_empty AuctionParticipant.invitable_users(a)
    BuyerStanding.approve_income_proof!(21)
    AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN)
    assert_empty AuctionParticipant.invitable_users(a)
  end

  test "english: only the invited buyer can accept, and not after revoke" do
    a = auction(type: "english")
    inv = AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN)
    assert_code("not_found") { inv.accept!(user: B) }
    inv.revoke!(admin: ADMIN)
    assert_code("invitation_revoked") { inv.accept!(user: A_OK) }
  end

  test "english: revoked buyer can be re-invited" do
    a = auction(type: "english")
    inv = AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN)
    inv.revoke!(admin: ADMIN)
    again = AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN)
    assert again.invited?
    assert_equal 1, a.participants.count
  end

  test "revoke is refused once the auction has started" do
    a = auction
    p = AuctionParticipant.register!(auction: a, user: C)
    assert_code("auction_started") { p.revoke!(admin: ADMIN, now: a.starts_at + 1.minute) }
  end

  test "database keeps status consistent with source and one row per user" do
    a = auction
    p = AuctionParticipant.register!(auction: a, user: C)
    assert_raises(ActiveRecord::StatementInvalid) { p.update_columns(status: "accepted") }
    dup = AuctionParticipant.new(auction: a, user_id: C.id, source: "registered", status: "registered", grade_at_entry: "C")
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "visibility: english is hidden from people who aren't invited" do
    a = auction(type: "english")
    assert_not a.visible_to?(nil)
    assert_not a.visible_to?(A_OK)
    assert a.visible_to?(ADMIN)
    AuctionParticipant.invite!(auction: a, user: A_OK, admin: ADMIN)
    assert a.visible_to?(A_OK)
    assert auction.visible_to?(nil)
    assert_not auction(schedule: false).visible_to?(C)
  end
end
