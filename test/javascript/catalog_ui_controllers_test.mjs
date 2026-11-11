import test from "node:test"
import assert from "node:assert/strict"
import { readFile } from "node:fs/promises"

// Exercise controller behavior without claiming browser layout or event-dispatch coverage.
async function controller(name) {
  const source = (await readFile(new URL(`../../app/javascript/controllers/${name}_controller.js`, import.meta.url), "utf8"))
    .replace('import { Controller } from "@hotwired/stimulus"', "class Controller {}")
  const module = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`)
  return new module.default()
}

test("carousel controls scroll a viewport in both directions and respect reduced motion", async () => {
  const carousel = await controller("catalog_carousel")
  const calls = []
  carousel.hasTrackTarget = true
  carousel.trackTarget = { clientWidth: 320, scrollBy: options => calls.push(options) }
  carousel.controlsTarget = { hidden: true }
  const original = globalThis.window
  try {
    globalThis.window = { matchMedia: () => ({ matches: false }) }
    carousel.connect()
    assert.equal(carousel.controlsTarget.hidden, false)
    carousel.next()
    carousel.previous()
    globalThis.window.matchMedia = () => ({ matches: true })
    carousel.next()
    assert.deepEqual(calls, [
      { left: 320, behavior: "smooth" }, { left: -320, behavior: "smooth" }, { left: 320, behavior: "instant" }
    ])
  } finally { globalThis.window = original }
})

test("empty carousel leaves controls hidden", async () => {
  const carousel = await controller("catalog_carousel")
  carousel.hasTrackTarget = false
  carousel.controlsTarget = { hidden: true }
  carousel.connect()
  assert.equal(carousel.controlsTarget.hidden, true)
})

test("cached broken images and later loading errors reveal their fallback", async () => {
  const image = await controller("catalog_image")
  image.hasImageTarget = true
  image.imageTarget = { complete: true, naturalWidth: 0, hidden: false }
  image.placeholderTarget = { hidden: true }
  image.connect()
  assert.equal(image.imageTarget.hidden, true)
  assert.equal(image.placeholderTarget.hidden, false)
  image.imageTarget = { complete: false, naturalWidth: 0, hidden: false }
  image.placeholderTarget.hidden = true
  image.connect()
  assert.equal(image.placeholderTarget.hidden, true)
  image.fallback()
  assert.equal(image.imageTarget.hidden, true)
  assert.equal(image.placeholderTarget.hidden, false)
})

test("detail dialog opens closes and only dismisses for backdrop clicks", async () => {
  const detail = await controller("catalog_detail")
  let open = false
  detail.dialogTarget = { showModal: () => { open = true }, close: () => { open = false } }
  detail.open()
  assert.equal(open, true)
  detail.dismiss({ target: {} })
  assert.equal(open, true)
  detail.dismiss({ target: detail.dialogTarget })
  assert.equal(open, false)
  detail.open()
  detail.close()
  assert.equal(open, false)
})
