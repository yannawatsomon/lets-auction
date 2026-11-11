import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "placeholder"]

  connect() {
    if (this.hasImageTarget && this.imageTarget.complete && this.imageTarget.naturalWidth === 0) {
      this.fallback()
    }
  }

  fallback() {
    if (this.hasImageTarget) this.imageTarget.hidden = true
    this.placeholderTarget.hidden = false
  }
}
