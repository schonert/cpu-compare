import { Controller } from "@hotwired/stimulus"

// Submits a filter form as the user changes it, debouncing free-text input.
export default class extends Controller {
  disconnect() {
    clearTimeout(this.timeout)
  }

  now() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  debounced() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 250)
  }
}
