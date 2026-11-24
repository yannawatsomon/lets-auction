# MOCK QR payment flow for #55 (MockQrPaymentStore). No gateway: the "simulate" action stands in
# for the gateway webhook so the team can see every state of the QR and receipt modals.
class PaymentQrsController < ApplicationController
  before_action :set_order
  before_action :set_payment

  # The QR itself is made by PaymentsController#preview when the buyer picks QR.
  def show
    return redirect_to(payment_qr_receipt_path(@payment.reference)) if @payment.paid?

    @quote = @order.quote(delivery_method: @payment.delivery_method)
  end

  # Polled by the QR modal every few seconds, in case the webhook result is missed.
  def status
    render json: status_payload
  end

  def simulate
    if params[:outcome] == "expire"
      @payment = MockQrPaymentStore.expire_now!(@payment.reference)
    elsif MockQrPaymentStore::OUTCOMES.include?(params[:outcome])
      amount = params[:outcome] == "amount_mismatch" ? @payment.amount_satang - 100 : @payment.amount_satang
      @payment = MockQrPaymentStore.apply_event!(@payment.reference,
        event_id: params[:event_id].presence || SecureRandom.uuid,
        outcome: params[:outcome], amount_satang: amount)
    else
      return render(json: { error: "invalid_outcome", message: "ไม่รู้จักผลลัพธ์นี้" }, status: :unprocessable_entity)
    end

    render json: status_payload
  end

  # "Generate new QR" after expiry or a failed payment: a new single-use QR, same order.
  def renew
    return redirect_to(payment_qr_path(@payment.reference)) if @payment.pending? || @payment.paid?

    payment = create_payment(@payment.delivery_method, @payment.email)
    redirect_to payment_qr_path(payment.reference)
  end

  def receipt
    return redirect_to(payment_qr_path(@payment.reference)) unless @payment.paid?

    @quote = @order.quote(delivery_method: @payment.delivery_method)
  end

  private

  def set_order
    @order = MockPaymentOrder.demo
  end

  def set_payment
    reference = params[:reference].to_s
    @payment = MockQrPaymentStore.find(reference) if reference.match?(MockQrPaymentStore::REFERENCE_FORMAT)
    return if @payment

    respond_to do |f|
      f.html { redirect_to payment_path, alert: "ไม่พบ QR นี้ หรือ QR หมดอายุจากระบบแล้ว กรุณาเริ่มใหม่" }
      f.json { render json: { error: "qr_not_found", message: "ไม่พบ QR นี้" }, status: :not_found }
    end
  end

  def create_payment(delivery_method, email)
    MockQrPaymentStore.create!(amount_satang: @order.quote(delivery_method:).total_satang,
      delivery_method:, email:)
  end

  def status_payload
    {
      reference: @payment.reference,
      status: @payment.status,
      seconds_left: @payment.seconds_left,
      message: @payment.failure,
      receipt_url: (payment_qr_receipt_path(@payment.reference) if @payment.paid?)
    }
  end
end
