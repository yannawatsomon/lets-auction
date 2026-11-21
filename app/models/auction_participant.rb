# Who may bid in an auction (issue #29, docs/decision/bidding.md + user-onboarding.md).
#
# Sealed: a buyer registers themself. Needs completed onboarding and grade A–D.
# English: an admin invites a buyer, the buyer accepts. Only grade A with approved proof of
# income can be invited. The grade is checked once here, never on each bid: #31/#32 only
# check that the participant is `registered` (sealed) or `accepted` (English).
class AuctionParticipant < ApplicationRecord
  # A rule the user broke. `code` goes into `{ error:, message: }`; the message is Thai.
  class Error < StandardError
    attr_reader :code, :http_status

    def initialize(code, message, http_status = :unprocessable_content)
      @code = code
      @http_status = http_status
      super(message)
    end
  end

  belongs_to :auction

  enum :source, { registered: "registered", invited: "invited" }, prefix: :via, validate: true
  enum :status, { registered: "registered", invited: "invited", accepted: "accepted", revoked: "revoked" }, validate: true

  validates :user_id, :grade_at_entry, presence: true
  validates :user_id, uniqueness: { scope: :auction_id }

  scope :active, -> { where(status: %w[registered accepted]) }

  def user = MockData.user(user_id)
  def invited_by = MockData.user(invited_by_id)

  # Can this participant bid right now (as far as participation goes)?
  def can_bid? = auction.english? ? accepted? : registered?

  class << self
    def register!(auction:, user:, now: Time.current)
      raise Error.new("not_sealed", "This auction is invite only; you can't register yourself.", :forbidden) unless auction.sealed_first_price?
      ensure_open!(auction, now)
      check_buyer!(auction, user)
      check_grade!(user, english: false)

      existing = find_by(auction:, user_id: user.id)
      return existing if existing&.registered?
      raise Error.new("registration_revoked", "Your access to this auction was revoked. Contact an admin.", :forbidden) if existing

      create!(auction:, user_id: user.id, source: "registered", status: "registered", grade_at_entry: BuyerStanding.grade(user))
    rescue ActiveRecord::RecordNotUnique
      find_by!(auction:, user_id: user.id) # a double click won the race; same result
    end

    def invite!(auction:, user:, admin:, now: Time.current)
      raise Error.new("not_english", "Only English auctions take invitations.", :unprocessable_content) unless auction.english?
      raise Error.new("auction_started", "You can invite only before the auction opens.", :conflict) unless auction.draft? || auction.scheduled?
      raise Error.new("auction_started", "You can invite only before the auction opens.", :conflict) unless now < auction.starts_at
      check_buyer!(auction, user)
      check_grade!(user, english: true)

      existing = find_by(auction:, user_id: user.id)
      if existing
        return existing unless existing.revoked?

        existing.update!(status: "invited", invited_by_id: admin.id, revoked_at: nil, revoked_by_id: nil,
          accepted_at: nil, grade_at_entry: BuyerStanding.grade(user))
        return existing
      end

      create!(auction:, user_id: user.id, source: "invited", status: "invited", invited_by_id: admin.id,
        grade_at_entry: BuyerStanding.grade(user))
    rescue ActiveRecord::RecordNotUnique
      find_by!(auction:, user_id: user.id)
    end

    # Buyers an admin may invite to this English auction (for the invite list).
    def invitable_users(auction)
      taken = where(auction:).where.not(status: "revoked").pluck(:user_id)
      sellers = auction.lots.filter_map { |l| l.item&.seller_id }
      MockData.users.select do |u|
        u.buyer? && BuyerStanding.english_grade?(u) && BuyerStanding.income_proof_approved?(u) && !taken.include?(u.id) && !sellers.include?(u.id)
      end
    end

    # Why `user` can't register for (sealed) or be invited to (English) `auction`, or nil.
    # Used to tell the buyer before they press anything (SPEC UX: "tell eligibility before the click").
    def ineligibility(auction:, user:)
      check_buyer!(auction, user)
      check_grade!(user, english: auction.english?)
      nil
    rescue Error => e
      e
    end

    private

    def ensure_open!(auction, now)
      open = (auction.scheduled? || auction.live?) && now < auction.ends_at
      raise Error.new("registration_closed", "Registration for this auction is closed.", :conflict) unless open
    end

    def check_buyer!(auction, user)
      raise Error.new("buyer_only", "Only buyer accounts can join auctions.", :forbidden) unless user&.buyer?
      if auction.lots.any? { |l| l.item&.seller_id == user.id }
        raise Error.new("own_item", "You can't join an auction that has your own item.", :forbidden)
      end
    end

    def check_grade!(user, english:)
      raise Error.new("onboarding_required", "Finish onboarding (identity and income) first.", :forbidden) unless BuyerStanding.onboarded?(user)

      if english
        raise Error.new("grade_not_allowed", "English auctions are open to grade A buyers only.", :forbidden) unless BuyerStanding.english_grade?(user)
        raise Error.new("income_proof_required", "The buyer needs approved proof of income first.", :forbidden) unless BuyerStanding.income_proof_approved?(user)
      else
        raise Error.new("grade_not_allowed", "Your credit grade can't join auctions yet.", :forbidden) unless BuyerStanding.sealed_grade?(user)
      end
    end
  end

  def accept!(user:, now: Time.current)
    raise Error.new("not_found", "Invitation not found.", :not_found) unless user_id == user&.id
    return self if accepted?
    raise Error.new("invitation_revoked", "This invitation was revoked.", :conflict) unless invited?

    open = (auction.scheduled? || auction.live?) && now < auction.ends_at
    raise Error.new("registration_closed", "This auction is closed.", :conflict) unless open

    self.class.send(:check_buyer!, auction, user)
    update!(status: "accepted", accepted_at: now)
  end

  def revoke!(admin:, now: Time.current)
    raise Error.new("auction_started", "You can revoke access only before the auction opens.", :conflict) unless (auction.draft? || auction.scheduled?) && now < auction.starts_at
    return self if revoked?

    update!(status: "revoked", revoked_at: now, revoked_by_id: admin.id)
  end
end
