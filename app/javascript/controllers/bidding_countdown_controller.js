import { Controller } from "@hotwired/stimulus"

// Countdown to a deadline using the server's clock, not the browser's (bidding.md).
// The page passes server time; the browser only measures elapsed time from it.
export default class extends Controller {
  static values = { deadline: String, serverTime: String }

  connect() {
    this.offset = Date.parse(this.serverTimeValue) - Date.now()
    this.deadline = Date.parse(this.deadlineValue)
    this.tick()
    this.timer = setInterval(() => this.tick(), 1000)
  }

  disconnect() { clearInterval(this.timer) }

  tick() {
    const left = Math.max(0, this.deadline - (Date.now() + this.offset))
    const s = Math.floor(left / 1000)
    const d = Math.floor(s / 86400)
    const hms = [Math.floor(s % 86400 / 3600), Math.floor(s % 3600 / 60), s % 60].map(n => String(n).padStart(2, "0")).join(":")
    this.element.textContent = d > 0 ? `${d} วัน ${hms}` : hms
    if (left === 0) {
      clearInterval(this.timer)
      setTimeout(() => window.location.reload(), 1500)
    }
  }
}
