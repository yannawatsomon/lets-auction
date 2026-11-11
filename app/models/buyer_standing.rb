# What bidding needs to know about a buyer's onboarding (issue #29): finished or not, the
# credit grade, and whether an admin approved their proof of income.
#
# Onboarding status and grade come from user onboarding's `OnboardingStore` (the same data
# their pages write). Proof of income (#66) has no store yet, so bidding keeps a tiny mock:
# `db/mock/bidding_income_proofs.yml` lists buyer ids whose proof is approved. When #66 lands,
# only `income_proof_approved?` changes. See ai/knowledge/mock-data.md.
module BuyerStanding
  PROOFS_SEED = Rails.root.join("db/mock/bidding_income_proofs.yml")
  LOCK = Mutex.new

  module_function

  def onboarded?(user) = user.present? && OnboardingStore.find(user.id).completed?

  def grade(user) = user && OnboardingStore.latest_assessment(user.id)&.grade

  def income_proof_approved?(user) = user.present? && approved_proof_ids.include?(user.id)

  # Rules from docs/decision/user-onboarding.md: A–D → sealed, A → English (with approved proof).
  def sealed_grade?(user) = onboarded?(user) && %w[A B C D].include?(grade(user))

  def english_grade?(user) = onboarded?(user) && grade(user) == "A"

  # MOCK writers, used by tests (and later replaced by #66's admin review).
  def approve_income_proof!(user_id) = LOCK.synchronize { approved_proof_ids_unlocked << user_id.to_i }

  def revoke_income_proof!(user_id) = LOCK.synchronize { approved_proof_ids_unlocked.delete(user_id.to_i) }

  def reset! = LOCK.synchronize { @approved = nil }

  def approved_proof_ids = LOCK.synchronize { approved_proof_ids_unlocked.dup }

  def approved_proof_ids_unlocked
    @approved ||= Array(YAML.load_file(PROOFS_SEED)).map(&:to_i).to_set
  end
end
