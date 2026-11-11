class PaymentSubmission
  include ActiveModel::Model
  include ActiveModel::Attributes

  PAYMENT_METHODS = %w[qr online_banking card cheque cash].freeze
  DELIVERY_METHODS = %w[self_pickup shipping].freeze

  attribute :payment_method, :string
  attribute :delivery_method, :string
  attribute :tax_invoice, :boolean, default: false
  attribute :tax_id, :string
  attribute :branch, :string
  attribute :address, :string
  attribute :email, :string

  validates :payment_method, inclusion: { in: PAYMENT_METHODS }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }
  validates :tax_id, format: { with: /\A\d{13}\z/ }, presence: true, if: :tax_invoice?
  validates :branch, presence: true, length: { maximum: 100 }, if: :tax_invoice?
  validates :address, presence: true, length: { maximum: 1_000 }, if: :tax_invoice?
  validates :email,
    format: { with: URI::MailTo::EMAIL_REGEXP },
    length: { maximum: 254 },
    presence: true,
    if: :tax_invoice?
  validate :cash_requires_self_pickup

  private

  def tax_invoice? = tax_invoice == true

  def cash_requires_self_pickup
    return unless payment_method == "cash" && delivery_method == "shipping"

    errors.add(:payment_method, "เงินสดใช้ได้เฉพาะการรับสินค้าเอง")
  end
end
