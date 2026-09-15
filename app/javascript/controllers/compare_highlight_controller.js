import { Controller } from "@hotwired/stimulus"

// Pointing at one CPU anywhere on the page dims every other CPU, so a single
// chip can be followed across all of the charts and the specification table.
export default class extends Controller {
  static targets = ["item"]
  static classes = ["dimmed"]

  highlight(event) {
    const slug = event.currentTarget.dataset.cpuSlug
    if (!slug) return

    this.itemTargets.forEach((item) => {
      item.classList.toggle(this.dimmedClass, item.dataset.cpuSlug !== slug)
    })
  }

  clear() {
    this.itemTargets.forEach((item) => item.classList.remove(this.dimmedClass))
  }

  get dimmedClass() {
    return this.hasDimmedClass ? this.dimmedClasses[0] : "opacity-50"
  }
}
