# MOCK DATA: in-memory store for UserOnboarding and CreditAssessment until the database lands.
# Seeded from db/mock/user_onboardings.yml; a restart (or reset!) brings the seed back.
# Each Ruby process has its own copy. Swap this module for ActiveRecord later; callers only use
# find / save / all / assessments / latest_assessment / add_assessment. See ai/knowledge/mock-data.md.
module OnboardingStore
  SEED = Rails.root.join("db/mock/user_onboardings.yml")
  LOCK = Mutex.new

  class << self
    # Returns a copy; change it and call save to keep the change.
    def find(user_id)
      LOCK.synchronize do
        stored = onboardings[user_id.to_i]
        stored ? copy(stored) : UserOnboarding.new(user_id: user_id.to_i)
      end
    end

    def all
      LOCK.synchronize { onboardings.values.map { |o| copy(o) } }
    end

    # Validates, enforces one national ID per account, then stores a copy. Returns true/false.
    def save(onboarding)
      return false unless onboarding.valid?

      LOCK.synchronize do
        if national_id_taken?(onboarding)
          onboarding.errors.add(:national_id, :taken)
          return false
        end
        onboardings[onboarding.user_id] = copy(onboarding)
      end
      true
    end

    def assessments(user_id)
      LOCK.synchronize { (assessment_log[user_id.to_i] || []).dup.freeze }
    end

    def latest_assessment(user_id) = assessments(user_id).last

    def add_assessment(assessment)
      LOCK.synchronize { (assessment_log[assessment.user_id] ||= []) << assessment }
      assessment
    end

    def reset!
      LOCK.synchronize { @onboardings = @assessment_log = nil }
    end

    private

    def onboardings = (load_seed; @onboardings)
    def assessment_log = (load_seed; @assessment_log)

    def load_seed
      return if @onboardings

      rows = YAML.load_file(SEED, permitted_classes: [ Time ])
      @onboardings = rows.to_h do |row|
        attrs = row.except("assessment")
        [ attrs["user_id"], UserOnboarding.new(attrs) ]
      end
      @assessment_log = rows.select { |row| row["assessment"] }.to_h do |row|
        a = row["assessment"]
        assessment = CreditAssessment.new(
          user_id: row["user_id"], score: a["score"], grade: a["grade"], score_version: a["score_version"],
          inputs: a["inputs"].freeze, reasons: a["reasons"].freeze, created_at: Time.zone.parse(a["created_at"].to_s)
        )
        [ row["user_id"], [ assessment ] ]
      end
    end

    def national_id_taken?(onboarding)
      return false if onboarding.national_id.blank?

      wanted = ThaiNationalId.normalize(onboarding.national_id)
      onboardings.any? do |user_id, other|
        user_id != onboarding.user_id && other.national_id.present? &&
          ThaiNationalId.normalize(other.national_id) == wanted
      end
    end

    def copy(onboarding) = UserOnboarding.new(onboarding.attributes)
  end
end
