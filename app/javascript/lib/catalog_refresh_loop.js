// Scheduling and request lifecycle, independent of Stimulus/DOM rendering.
export class CatalogRefreshLoop {
  constructor({ canRefresh, refresh, onFailure, interval = 30_000, scheduler = globalThis }) {
    Object.assign(this, { canRefresh, refresh, onFailure, interval, scheduler })
    this.active = false
    this.running = false
    this.pending = false
  }

  start() {
    if (this.active) return
    this.active = true
    this.schedule()
  }

  stop() {
    this.active = false
    this.pending = false
    this.scheduler.clearTimeout(this.timer)
    this.controller?.abort()
  }

  schedule() {
    this.scheduler.clearTimeout(this.timer)
    if (this.active) this.timer = this.scheduler.setTimeout(() => this.run(), this.interval)
  }

  async run() {
    if (!this.active) return
    if (this.running) {
      this.pending = true
      return
    }
    this.scheduler.clearTimeout(this.timer)
    if (!this.canRefresh()) {
      this.schedule()
      return
    }
    this.running = true
    const controller = new AbortController()
    this.controller = controller
    try {
      await this.refresh(controller.signal)
    } catch (error) {
      if (this.active && !controller.signal.aborted) this.onFailure(error)
    } finally {
      this.running = false
      this.controller = null
      if (this.active && this.pending) {
        this.pending = false
        void this.run()
      } else {
        this.schedule()
      }
    }
  }
}
