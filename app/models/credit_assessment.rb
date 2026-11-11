# One credit score calculation for a buyer (docs/decision/user-onboarding.md).
# Immutable and append-only: a recalculation adds a new assessment, it never edits one.
# MOCK DATA: kept in OnboardingStore (memory) until the database lands.
CreditAssessment = Data.define(:user_id, :score, :grade, :score_version, :inputs, :reasons, :created_at)
