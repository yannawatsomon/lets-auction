import test from "node:test"
import assert from "node:assert/strict"
import { CatalogRefreshLoop } from "../../app/javascript/lib/catalog_refresh_loop.js"

function scheduler() {
  let sequence = 0
  const tasks = new Map()
  return {
    tasks,
    setTimeout(callback, delay) { const id = ++sequence; tasks.set(id, { callback, delay }); return id },
    clearTimeout(id) { tasks.delete(id) },
    async tick() { const [id, task] = tasks.entries().next().value; tasks.delete(id); await task.callback() }
  }
}

test("polls after 30 seconds and keeps scheduling while active", async () => {
  const clock = scheduler()
  let requests = 0
  const loop = new CatalogRefreshLoop({ canRefresh: () => true, refresh: async () => { requests++ }, onFailure: () => {}, scheduler: clock })
  loop.start()
  assert.equal(requests, 0)
  assert.equal([...clock.tasks.values()][0].delay, 30_000)
  await clock.tick()
  assert.equal(requests, 1)
  assert.equal(clock.tasks.size, 1)
  loop.stop()
  assert.equal(clock.tasks.size, 0)
})

test("defers refresh while visibility or interaction prevents replacement", async () => {
  const clock = scheduler()
  let allowed = false
  let requests = 0
  const loop = new CatalogRefreshLoop({ canRefresh: () => allowed, refresh: async () => { requests++ }, onFailure: () => {}, scheduler: clock })
  loop.start()
  await clock.tick()
  assert.equal(requests, 0)
  allowed = true
  await loop.run()
  assert.equal(requests, 1)
  loop.stop()
})

test("failure keeps loop retryable and success does not repeat the error", async () => {
  const clock = scheduler()
  let requests = 0
  let failures = 0
  const loop = new CatalogRefreshLoop({ canRefresh: () => true, refresh: async () => { if (++requests === 1) throw new Error("offline") }, onFailure: () => { failures++ }, scheduler: clock })
  loop.start()
  await clock.tick()
  assert.equal(failures, 1)
  assert.equal(clock.tasks.size, 1)
  await loop.run()
  assert.equal(requests, 2)
  assert.equal(failures, 1)
  loop.stop()
})

test("requests never overlap and a queued visible-tab refresh is retained", async () => {
  const clock = scheduler()
  let release
  let requests = 0
  let active = 0
  let peak = 0
  const loop = new CatalogRefreshLoop({ canRefresh: () => true, refresh: async () => {
    requests++; active++; peak = Math.max(peak, active)
    if (requests === 1) await new Promise(resolve => { release = resolve })
    active--
  }, onFailure: () => {}, scheduler: clock })
  loop.start()
  const pending = loop.run()
  await loop.run()
  assert.equal(requests, 1)
  release()
  await pending
  await Promise.resolve()
  assert.equal(requests, 2)
  assert.equal(peak, 1)
  loop.stop()
})

test("disconnect aborts the pending request without showing a failure", async () => {
  const clock = scheduler()
  let signal
  let failures = 0
  const loop = new CatalogRefreshLoop({ canRefresh: () => true, refresh: pendingSignal => {
    signal = pendingSignal
    return new Promise((_resolve, reject) => signal.addEventListener("abort", () => reject(new Error("aborted"))))
  }, onFailure: () => { failures++ }, scheduler: clock })
  loop.start()
  const pending = loop.run()
  loop.stop()
  await pending
  assert.equal(signal.aborted, true)
  assert.equal(failures, 0)
  assert.equal(clock.tasks.size, 0)
})
