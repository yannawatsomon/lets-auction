# MOCK PromptPay QR payments for the #55 mockup: in memory, like Bidding::OrderStore, because the
# team adds no new tables for now (docs/decision/bidding.md) and Milestone 1 has no payment
# gateway (docs/decision/scope.md). A restart forgets every QR and receipt.
#
# One payment = one single-use QR for an exact amount. It expires QR_LIFETIME after it is made.
# A gateway would confirm it by webhook; here the demo buttons call #apply_event! instead, with the
# same rules: an expired or finished QR cannot be paid, a wrong amount fails, and an event id that
# was already handled changes nothing (duplicate webhooks).
module MockQrPaymentStore
  QR_LIFETIME = 10.minutes
  MAX_PAYMENTS = 500 # /payment is public, so cap what anonymous visitors can keep in memory
  ACCOUNT_NAME = "บริษัท เล็ทส์ ออคชั่น จำกัด (ตัวอย่าง)".freeze
  STATUSES = %w[pending paid failed expired].freeze
  OUTCOMES = %w[paid amount_mismatch failed].freeze
  REFERENCE_FORMAT = /\AQR[A-Z0-9]{10}\z/
  LOCK = Monitor.new

  Payment = Struct.new(:reference, :amount_satang, :delivery_method, :email, :created_at,
    :expires_at, :status, :failure, :receipt_number, :paid_at, :event_ids, keyword_init: true) do
    def pending? = status == "pending"
    def paid? = status == "paid"
    def failed? = status == "failed"
    def expired? = status == "expired"
    def seconds_left(now = Time.current) = pending? ? [ (expires_at - now).ceil, 0 ].max : 0
  end

  module_function

  def synchronize(&) = LOCK.synchronize(&)

  def reset!
    synchronize do
      @payments = {}
      @receipt_count = 0
    end
  end

  def create!(amount_satang:, delivery_method:, email: nil, now: Time.current)
    raise ArgumentError, "amount must be positive" unless amount_satang.is_a?(Integer) && amount_satang.positive?

    synchronize do
      payments.shift while payments.size >= MAX_PAYMENTS
      reference = new_reference
      payments[reference] = Payment.new(reference:, amount_satang:, delivery_method:,
        email: email.presence, created_at: now, expires_at: now + QR_LIFETIME,
        status: "pending", event_ids: [])
      payments[reference].dup
    end
  end

  # Returns a copy with the status as of `now` (a pending QR past its time becomes expired).
  def find(reference, now: Time.current)
    synchronize do
      payment = payments[reference.to_s]
      next nil unless payment

      expire_if_due(payment, now)
      payment.dup
    end
  end

  # What a gateway webhook would do. Returns the payment after the event.
  def apply_event!(reference, event_id:, outcome:, amount_satang:, now: Time.current)
    raise ArgumentError, "unknown outcome" unless OUTCOMES.include?(outcome)

    synchronize do
      payment = payments[reference.to_s]
      next nil unless payment

      expire_if_due(payment, now)
      next payment.dup if payment.event_ids.include?(event_id) || !payment.pending?

      payment.event_ids << event_id
      if outcome == "failed"
        fail!(payment, "ธนาคารปฏิเสธรายการ กรุณาลองใหม่")
      elsif outcome == "amount_mismatch" || amount_satang != payment.amount_satang
        fail!(payment, "ยอดที่โอนไม่ตรงกับยอดชำระ กรุณาลองใหม่")
      else
        payment.status = "paid"
        payment.paid_at = now
        payment.receipt_number = next_receipt_number(now)
      end
      payment.dup
    end
  end

  # Demo shortcut: end the QR's time now instead of waiting QR_LIFETIME.
  def expire_now!(reference, now: Time.current)
    synchronize do
      payment = payments[reference.to_s]
      next nil unless payment

      payment.expires_at = now if payment.pending?
      expire_if_due(payment, now)
      payment.dup
    end
  end

  def payments = (@payments ||= {})

  def new_reference
    loop do
      reference = "QR#{SecureRandom.alphanumeric(10).upcase}"
      return reference unless payments.key?(reference)
    end
  end

  def expire_if_due(payment, now)
    payment.status = "expired" if payment.pending? && now >= payment.expires_at
  end

  def fail!(payment, message)
    payment.status = "failed"
    payment.failure = message
  end

  # Sequential and unique for the life of the process: RC-2026-000001, RC-2026-000002, ...
  def next_receipt_number(now)
    @receipt_count = (@receipt_count || 0) + 1
    format("RC-%<year>d-%<count>06d", year: now.year, count: @receipt_count)
  end
end
