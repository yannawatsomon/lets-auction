import { Controller } from "@hotwired/stimulus"

// MOCK QR modal (#55). The server owns the QR's status and expiry; this only counts down between
// polls, asks /status every POLL_MS (the fallback for a missed webhook) and sends the demo
// "simulate" buttons. When the payment is paid it goes to the receipt.
const POLL_MS = 4000

export default class extends Controller {
  static targets = ["demo", "error", "errorMessage", "frame", "heading", "overlay", "renew", "timer", "waiting"]
  static values = { statusUrl: String, simulateUrl: String, status: String, secondsLeft: Number }

  connect() {
    this.headingTarget.focus()
    this.deadline = Date.now() + this.secondsLeftValue * 1000
    if (this.statusValue !== "pending") return

    this.tick = setInterval(() => this.renderTimer(), 1000)
    this.poll = setInterval(() => this.refresh(), POLL_MS)
  }

  disconnect() {
    this.stop()
  }

  async refresh() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (response.ok) this.apply(await response.json())
    } catch {
      // Offline for a moment: the next poll tries again.
    }
  }

  async simulate(event) {
    const button = event.currentTarget
    button.disabled = true
    try {
      const response = await fetch(this.simulateUrlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        body: JSON.stringify({ outcome: button.dataset.outcome })
      })
      if (response.ok) this.apply(await response.json())
    } finally {
      button.disabled = false
    }
  }

  apply(payment) {
    this.deadline = Date.now() + payment.seconds_left * 1000
    if (payment.status === "pending") return this.renderTimer()

    this.stop()
    if (payment.status === "paid" && payment.receipt_url) {
      window.location.assign(payment.receipt_url)
      return
    }

    this.timerTarget.textContent = "00:00"
    this.frameTarget.classList.add("is-inactive")
    this.overlayTarget.textContent = payment.status === "failed" ? "ชำระไม่สำเร็จ" : "QR หมดอายุแล้ว"
    this.overlayTarget.hidden = false
    this.errorMessageTarget.textContent = payment.message || "QR นี้หมดอายุแล้ว กรุณาสร้าง QR ใหม่"
    this.errorTarget.hidden = false
    this.waitingTarget.hidden = true
    this.demoTarget.hidden = true
    this.renewTarget.hidden = false
  }

  renderTimer() {
    const seconds = Math.max(0, Math.ceil((this.deadline - Date.now()) / 1000))
    const mm = String(Math.floor(seconds / 60)).padStart(2, "0")
    const ss = String(seconds % 60).padStart(2, "0")
    this.timerTarget.textContent = `${mm}:${ss}`
    if (seconds === 0) this.refresh()
  }

  stop() {
    clearInterval(this.tick)
    clearInterval(this.poll)
  }
}
