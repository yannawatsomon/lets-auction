import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

// English live bid room (#34). Listens to Bidding::AuctionChannel and keeps the page in step:
// price, next minimum, bid count, masked leader, "you're leading" / "outbid", closed state,
// and the bid history list. Bids are still sent with the normal form (REST), never over the
// socket. On reconnect the channel sends `lot.state` again, so the page catches up by itself.
let consumer
const baht = (cents) => "฿ " + (Number(cents) / 100).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const typed = (cents) => (Number(cents) / 100).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 })

export default class extends Controller {
  static targets = ["price", "priceLabel", "nextMin", "count", "leader", "leading", "outbid", "closed", "form", "amount", "history", "status", "liveChip"]
  static values = { auctionId: Number, lotId: Number, myLabel: String, historyUrl: String, canBid: Boolean }

  connect() {
    consumer ||= createConsumer()
    this.subscription = consumer.subscriptions.create(
      { channel: "Bidding::AuctionChannel", auction_id: this.auctionIdValue },
      {
        connected: () => this.say(""),
        disconnected: () => this.say("การเชื่อมต่อสดหลุด กำลังเชื่อมต่อใหม่… ราคาที่แสดงอาจไม่ใช่ล่าสุด"),
        rejected: () => this.say("ดูราคาสดไม่ได้ (ต้องเป็นผู้ได้รับเชิญที่ตอบรับแล้ว) · รีเฟรชหน้าเพื่อดูราคาล่าสุด"),
        received: (msg) => this.receive(msg)
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  receive(msg) {
    switch (msg.type) {
      case "lot.state": {
        const lot = (msg.lots || []).find((l) => l.id === this.lotIdValue)
        if (lot) this.apply(lot)
        break
      }
      case "bid.accepted":
        if (msg.lot?.id === this.lotIdValue) {
          this.apply(msg.lot)
          this.refreshHistory()
        }
        break
      case "bid.outbid":
        if (msg.lot_id === this.lotIdValue) this.showOutbid()
        break
      case "lot.closed":
        if (msg.lot_id === this.lotIdValue) this.close()
        break
      case "auction.result_published":
        this.say("ประกาศผลแล้ว · กำลังโหลดหน้าใหม่")
        setTimeout(() => window.location.reload(), 1200)
        break
    }
  }

  apply(lot) {
    const hasBids = Number(lot.bid_count) > 0
    if (this.hasPriceTarget) this.priceTarget.textContent = baht(hasBids ? lot.current_price_cents : lot.min_price_cents)
    if (this.hasPriceLabelTarget) this.priceLabelTarget.textContent = hasBids ? "ราคาปัจจุบัน" : "ราคาเริ่มต้น"
    if (this.hasCountTarget) this.countTarget.textContent = lot.bid_count
    if (this.hasNextMinTarget) this.nextMinTarget.textContent = baht(lot.next_minimum_cents)
    if (this.hasLeaderTarget) this.leaderTarget.textContent = lot.leader ? `ผู้นำ: ${lot.leader}` : ""

    const mine = Boolean(lot.leader) && lot.leader === this.myLabelValue
    if (this.hasLeadingTarget) this.leadingTarget.hidden = !mine
    if (mine && this.hasOutbidTarget) this.outbidTarget.hidden = true
    if (this.hasFormTarget) this.formTarget.hidden = mine
    // Only move the amount forward if the buyer hasn't typed more than the new minimum.
    if (this.hasAmountTarget && !mine) {
      const typedCents = Math.round(parseFloat(this.amountTarget.value.replace(/,/g, "")) * 100)
      if (!(typedCents >= lot.next_minimum_cents)) this.amountTarget.value = typed(lot.next_minimum_cents)
    }
    if (lot.status === "closed" || lot.status === "sold" || lot.status === "unsold") this.close()
  }

  showOutbid() {
    if (this.hasOutbidTarget) this.outbidTarget.hidden = false
    if (this.hasLeadingTarget) this.leadingTarget.hidden = true
    if (this.hasFormTarget) this.formTarget.hidden = false
  }

  close() {
    if (this.hasFormTarget) this.formTarget.hidden = true
    if (this.hasClosedTarget) this.closedTarget.hidden = false
    if (this.hasLiveChipTarget) this.liveChipTarget.hidden = true
  }

  async refreshHistory() {
    if (!this.hasHistoryTarget) return
    try {
      const res = await fetch(this.historyUrlValue, { headers: { Accept: "text/html" }, credentials: "same-origin" })
      if (res.ok) this.historyTarget.innerHTML = await res.text()
    } catch (_) {
      this.say("โหลดประวัติการบิดไม่สำเร็จ · รีเฟรชหน้าเพื่อดูล่าสุด")
    }
  }

  say(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }
}
