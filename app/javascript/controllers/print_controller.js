import { Controller } from "@hotwired/stimulus"

// Opens the browser's print dialog (the buyer can "Save as PDF" there).
export default class extends Controller {
  print() {
    window.print()
  }
}
