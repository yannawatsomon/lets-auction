class PaymentsController < ApplicationController
  before_action :set_order

  def show
    @delivery_method = params[:delivery_method].presence || "self_pickup"
    return render_invalid_delivery_method unless PaymentQuote::DELIVERY_METHODS.include?(@delivery_method)

    @payment_submission = PaymentSubmission.new(
      payment_method: "qr",
      delivery_method: @delivery_method
    )
    prepare_page
  end

  def quote
    @delivery_method = params[:delivery_method]
    @quote = @order.quote(delivery_method: @delivery_method)
    render json: quote_payload
  rescue ArgumentError
    render json: { error: "delivery_method is invalid" }, status: :unprocessable_entity
  end

  def preview
    attributes = params.permit(
      :payment_method, :delivery_method, :tax_invoice, :tax_id, :branch, :address, :email
    )
    @payment_submission = PaymentSubmission.new(attributes)
    @delivery_method = @payment_submission.delivery_method
    return render_invalid_delivery_method unless PaymentQuote::DELIVERY_METHODS.include?(@delivery_method)

    prepare_page
    if @payment_submission.valid?
      @demo_notice = "นี่เป็นหน้าทดลอง ยังไม่มีการเรียกเก็บเงินจริง"
      render :show
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_order
    @order = MockPaymentOrder.demo
  end

  def prepare_page
    @quote = @order.quote(delivery_method: @delivery_method)
  end

  def quote_payload
    {
      subtotal_satang: @quote.subtotal_satang,
      vat_satang: @quote.vat_satang,
      shipping_fee_satang: @delivery_method == "shipping" ? @order.shipping_fee_satang : 0,
      total_satang: @quote.total_satang
    }
  end

  def render_invalid_delivery_method
    render plain: "Invalid delivery method", status: :unprocessable_entity
  end
end
