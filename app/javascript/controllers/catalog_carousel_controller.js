import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "controls"]

  connect() {
    if (this.hasTrackTarget) this.controlsTarget.hidden = false
  }

  previous() { this.scroll(-1) }
  next() { this.scroll(1) }

  scroll(direction) {
    this.trackTarget.scrollBy({
      left: direction * this.trackTarget.clientWidth,
      behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "instant" : "smooth"
    })
  }
}
