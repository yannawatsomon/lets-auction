import { Controller } from "@hotwired/stimulus"

// Seller product wizard: 4 steps in one form. A file is uploaded as soon as it is picked: its
// type and size are sent to the uploads URL, then the file goes to the target that comes back.
// The form submits only the returned keys (upload_keys[]), in the order shown.
// The server checks everything again; the checks here are only fast feedback.
export default class extends Controller {
  static targets = ["step", "dot", "list", "input", "count", "error", "summary", "back", "next", "submit"]
  static values = { uploadsUrl: String, limits: Object, existing: Array }

  connect() {
    this.index = 0
    this.pending = 0
    this.existingValue.forEach((file) => this.addRow(file.kind, file.filename, file.key))
    this.show(0)
  }

  // --- steps ---

  next() {
    if (this.valid()) this.show(this.index + 1)
  }

  back() {
    this.show(this.index - 1)
  }

  show(index) {
    this.index = Math.max(0, Math.min(index, this.stepTargets.length - 1))
    this.stepTargets.forEach((step, i) => (step.hidden = i !== this.index))
    this.dotTargets.forEach((dot, i) => dot.setAttribute("aria-current", i === this.index ? "step" : "false"))
    this.backTarget.hidden = this.index === 0
    this.nextTarget.hidden = this.index === this.stepTargets.length - 1
    this.submitTarget.hidden = !this.nextTarget.hidden
    this.errorTarget.textContent = ""
    if (this.index === this.stepTargets.length - 1) this.buildSummary()
    this.refresh()
  }

  valid() {
    this.errorTarget.textContent = ""
    if (this.pending > 0) return this.fail("รอให้ไฟล์อัปโหลดเสร็จก่อน")
    if (this.index === 0 && this.rows("image").filter((row) => row.dataset.key).length === 0) {
      return this.fail("เพิ่มรูปภาพอย่างน้อย 1 รูป")
    }
    if (this.index === 2) {
      const invalid = [...this.stepTargets[2].querySelectorAll("input, select, textarea")].find((el) => !el.checkValidity())
      if (invalid) {
        invalid.reportValidity()
        return false
      }
    }
    return true
  }

  submit(event) {
    if (this.pending > 0 || this.rows("image").filter((row) => row.dataset.key).length === 0) {
      event.preventDefault()
      this.fail("ตรวจสอบรูปภาพและรอให้ไฟล์อัปโหลดเสร็จก่อนส่ง")
    }
  }

  // --- files ---

  pick(event) {
    const input = event.currentTarget
    ;[...input.files].forEach((file) => this.add(input.dataset.kind, file))
    input.value = ""
  }

  add(kind, file) {
    const limit = this.limitsValue[kind]
    if (this.rows(kind).length >= limit.max) return this.fail(`เพิ่มได้ไม่เกิน ${limit.max} ไฟล์`)
    if (!limit.types.includes(file.type)) return this.fail(`${file.name}: รองรับเฉพาะ ${limit.typesLabel}`)
    if (file.size === 0 || file.size > limit.maxBytes) return this.fail(`${file.name}: ไฟล์ต้องไม่ว่างและไม่เกิน ${limit.maxLabel}`)

    this.errorTarget.textContent = ""
    this.upload(this.addRow(kind, file.name), kind, file)
  }

  async upload(row, kind, file) {
    this.pending += 1
    row.retry.hidden = true
    this.state(row, "กำลังอัปโหลด…", "")
    this.refresh()
    try {
      const response = await this.send(this.uploadsUrlValue, "POST", JSON.stringify({
        kind, filename: file.name, content_type: file.type, size: file.size
      }), { "Content-Type": "application/json" })
      const issued = await response.json()
      await this.send(issued.direct_upload.url, issued.direct_upload.method, file, issued.direct_upload.headers)
      this.setKey(row, issued.key)
      this.state(row, "อัปโหลดแล้ว", "ok")
    } catch (error) {
      row.retry.onclick = () => this.upload(row, kind, file)
      row.retry.hidden = false
      this.state(row, error.message || "อัปโหลดไม่สำเร็จ", "bad")
    } finally {
      this.pending -= 1
      this.refresh()
    }
  }

  async send(url, method, body, headers = {}) {
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, { method, body, headers: { ...headers, "X-CSRF-Token": token, Accept: "application/json" } })
    if (response.ok) return response

    const reason = await response.json().then((json) => json.error).catch(() => null)
    throw new Error(reason || `อัปโหลดไม่สำเร็จ (${response.status})`)
  }

  addRow(kind, name, key = null) {
    const row = document.createElement("li")
    row.className = "file-row"
    row.dataset.kind = kind
    row.name = Object.assign(document.createElement("span"), { className: "name", textContent: name })
    row.status = Object.assign(document.createElement("span"), { className: "state" })
    row.retry = this.button("ลองอัปโหลดใหม่", () => {})
    row.retry.hidden = true
    const remove = this.button("ลบ", () => { row.remove(); this.refresh() })
    row.append(row.name, row.status, row.retry)
    if (kind === "image") row.append(this.button("ตั้งเป็นปก", () => { row.parentElement.prepend(row); this.refresh() }))
    row.append(remove)
    this.listTargets.find((list) => list.dataset.kind === kind).append(row)
    if (key) {
      this.setKey(row, key)
      this.state(row, "อัปโหลดแล้ว", "ok")
    }
    this.refresh()
    return row
  }

  button(text, onclick) {
    return Object.assign(document.createElement("button"), { type: "button", className: "btn link", textContent: text, onclick })
  }

  setKey(row, key) {
    row.dataset.key = key
    row.querySelector("input")?.remove()
    row.append(Object.assign(document.createElement("input"), { type: "hidden", name: "upload_keys[]", value: key }))
  }

  state(row, text, kind) {
    row.status.textContent = text
    row.status.className = `state ${kind}`
  }

  rows(kind) {
    return [...this.listTargets.find((list) => list.dataset.kind === kind).children]
  }

  refresh() {
    Object.entries(this.limitsValue).forEach(([kind, limit]) => {
      const rows = this.rows(kind)
      this.countTargets.find((el) => el.dataset.kind === kind).textContent = `${rows.length}/${limit.max}`
      this.inputTargets.find((el) => el.dataset.kind === kind).disabled = rows.length >= limit.max
      rows.forEach((row, i) => row.classList.toggle("cover", kind === "image" && i === 0))
    })
  }

  fail(message) {
    this.errorTarget.textContent = message
    return false
  }

  // --- summary (step 4), with a link back to each step ---

  buildSummary() {
    const value = (name) => this.element.querySelector(`[name="item[${name}]"]`)?.value || "—"
    const files = (kind) => this.rows(kind).map((row) => row.name.textContent).join(", ") || "—"
    const rows = [
      [0, "รูปภาพ", files("image")], [1, "วิดีโอ", files("video")], [2, "ชื่อสินค้า", value("title")],
      [2, "หมวด", value("category")], [2, "ราคาขั้นต่ำ (บาท)", value("price")], [2, "รายละเอียด", value("description")],
      [2, "เอกสาร", files("document")]
    ]
    this.summaryTarget.replaceChildren(...rows.map(([step, label, text]) => {
      const line = document.createElement("div")
      line.className = "summary-row"
      const edit = this.button("แก้ไข", () => this.show(step))
      line.append(Object.assign(document.createElement("strong"), { textContent: label }),
        Object.assign(document.createElement("span"), { textContent: text }), edit)
      return line
    }))
  }
}
