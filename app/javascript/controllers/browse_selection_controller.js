import { Controller } from "@hotwired/stimulus"

// Adds a processor to the comparison set without leaving Browse. The link href
// already carries the updated cpus query param; Turbo swaps the page in place.
export default class extends Controller {
  add(event) {
    event.preventDefault()
    Turbo.visit(event.currentTarget.href, { action: "advance" })
  }
}
