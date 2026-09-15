import { Controller } from "@hotwired/stimulus"

// Debounces the type-ahead so a burst of keystrokes results in one request.
export default class extends Controller {
  disconnect() {
    clearTimeout(this.timeout)
  }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 180)
  }
}
