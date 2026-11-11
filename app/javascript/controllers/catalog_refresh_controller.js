import { Controller } from "@hotwired/stimulus"
import { CatalogRefreshLoop } from "catalog_refresh_loop"

export default class extends Controller {
  static targets = ["results", "updatedAt", "error", "retry"]
  static values = { url: String, enabled: { type: Boolean, default: true } }

  connect() {
    if (!this.enabledValue) return
    this.loop = new CatalogRefreshLoop({
      canRefresh: () => this.canRefresh(),
      refresh: signal => this.load(signal),
      onFailure: () => this.showFailure()
    })
    this.visibilityHandler = () => {
      if (document.hidden) {
        this.loop.stop()
      } else {
        this.loop.start()
        void this.loop.run()
      }
    }
    document.addEventListener("visibilitychange", this.visibilityHandler)
    if (!document.hidden) this.loop.start()
  }

  disconnect() {
    this.loop?.stop()
    if (this.visibilityHandler) document.removeEventListener("visibilitychange", this.visibilityHandler)
  }

  canRefresh() {
    return this.element.isConnected && !document.hidden &&
      !this.element.querySelector("dialog[open]") && !this.resultsTarget.contains(document.activeElement)
  }

  retry() {
    void this.loop?.run()
  }

  async load(signal) {
    const url = new URL(this.urlValue, window.location.href)
    if (url.origin !== window.location.origin) throw new Error("Invalid catalog refresh origin")
    const response = await fetch(url, {
      headers: { Accept: "text/html" }, credentials: "same-origin", cache: "no-store", signal
    })
    if (!response.ok) throw new Error(`Catalog refresh HTTP ${response.status}`)
    const html = await response.text()
    if (signal.aborted || !this.canRefresh()) return
    const page = new DOMParser().parseFromString(html, "text/html")
    const results = page.querySelector("[data-catalog-refresh-target='results']")
    const updatedAt = page.querySelector("time[data-catalog-refresh-target='updatedAt']")
    if (!results || !updatedAt) throw new Error("Incomplete catalog refresh response")
    const scroll = { left: window.scrollX, top: window.scrollY }
    this.resultsTarget.replaceWith(document.importNode(results, true))
    this.updatedAtTarget.dateTime = updatedAt.dateTime
    this.updatedAtTarget.textContent = updatedAt.textContent
    this.errorTarget.hidden = true
    this.retryTarget.hidden = true
    // Results are now the first page, so a later reload must use the same state.
    history.replaceState(history.state, "", `${url.pathname}${url.search}${window.location.hash}`)
    window.scrollTo(scroll.left, scroll.top)
  }

  showFailure() {
    this.errorTarget.hidden = false
    this.retryTarget.hidden = false
  }
}
