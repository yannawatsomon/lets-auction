import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "cashHint", "delivery", "form", "invoiceField",
    "invoiceFields", "invoiceToggle", "method", "pickupDetails", "quoteError",
    "quoteErrorMessage",
    "shippingDetails", "shippingFee", "subtotal", "submit", "total", "vat"
  ]

  static values = { quoteUrl: String }

  connect() {
    this.submitting = false
    this.quotePending = false
    this.updateDeliveryDetails()
    this.updateInvoiceFields()
    this.updateSubmitButton()
  }

  disconnect() {
    this.quoteAbortController?.abort()
    this.quoteAbortController = null
  }

  validate() {
    this.updateSubmitButton()
  }

  change(event) {
    if (event.target === this.invoiceToggleTarget) {
      this.updateInvoiceFields()
    }

    if (this.deliveryTargets.includes(event.target)) {
      this.updateDeliveryDetails()
      this.refreshQuote()
    }

    this.updateSubmitButton()
  }

  submit(event) {
    if (!this.formTarget.checkValidity() || !this.quoteErrorTarget.hidden) {
      event.preventDefault()
      this.updateSubmitButton()
      return
    }

    if (this.submitting) {
      event.preventDefault()
      return
    }

    this.submitting = true
    this.submitTarget.disabled = true
    this.submitTarget.textContent = "กำลังดำเนินการ…"
  }

  updateDeliveryDetails() {
    const deliveryMethod = this.selectedDeliveryMethod()
    const shipping = deliveryMethod === "shipping"
    this.pickupDetailsTarget.hidden = shipping
    this.shippingDetailsTarget.hidden = !shipping
    this.cashHintTarget.hidden = !shipping
    const cashMethod = this.methodTargets.find((method) => method.value === "cash")
    cashMethod.disabled = shipping

    if (shipping && cashMethod.checked) {
      this.methodTargets.find((method) => method.value === "qr").checked = true
    }
  }

  updateInvoiceFields() {
    const required = this.invoiceToggleTarget.checked
    this.invoiceFieldsTarget.hidden = !required
    this.invoiceFieldTargets.forEach((field) => {
      field.disabled = !required
      field.required = required
    })
  }

  updateSubmitButton() {
    this.submitTarget.disabled = !this.formTarget.checkValidity()
      || this.submitting
      || this.quotePending
      || !this.quoteErrorTarget.hidden
  }

  async refreshQuote() {
    this.quoteAbortController?.abort()
    const abortController = new AbortController()
    this.quoteAbortController = abortController
    this.quotePending = true
    this.quoteErrorTarget.hidden = true
    this.updateSubmitButton()
    const deliveryMethod = this.selectedDeliveryMethod()
    const url = new URL(this.quoteUrlValue, window.location.origin)
    url.searchParams.set("delivery_method", deliveryMethod)

    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: abortController.signal
      })
      if (!response.ok) throw new Error(`Quote request failed (${response.status})`)

      const quote = await response.json()
      const amounts = [
        quote.subtotal_satang, quote.vat_satang, quote.shipping_fee_satang, quote.total_satang
      ]
      if (!amounts.every((amount) => Number.isSafeInteger(amount) && amount >= 0)) {
        throw new Error("Quote response contained invalid amounts")
      }

      this.shippingFeeTarget.textContent = this.formatBaht(quote.shipping_fee_satang)
      this.subtotalTarget.textContent = `ยอดก่อน VAT ${this.formatBaht(quote.subtotal_satang)}`
      this.vatTarget.textContent = this.formatBaht(quote.vat_satang)
      this.totalTarget.textContent = this.formatBaht(quote.total_satang)
    } catch (error) {
      if (error.name === "AbortError") return

      this.quoteErrorMessageTarget.textContent = "ไม่สามารถคำนวณยอดชำระได้ กรุณาลองอีกครั้ง"
      this.quoteErrorTarget.hidden = false
    } finally {
      if (this.quoteAbortController === abortController) {
        this.quoteAbortController = null
        this.quotePending = false
        this.updateSubmitButton()
      }
    }
  }

  selectedDeliveryMethod() {
    return this.deliveryTargets.find((input) => input.checked)?.value
  }

  formatBaht(satang) {
    const baht = (satang / 100).toLocaleString("en-US", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    })
    return `฿ ${baht}`
  }
}
