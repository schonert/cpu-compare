import { Controller } from "@hotwired/stimulus"

// Positions a citation tooltip in the viewport so table overflow and card
// clipping cannot hide it. Shown on hover and keyboard focus; stays open
// while the pointer or focus moves onto a source link inside the panel.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundReposition = this.reposition.bind(this)
  }

  disconnect() {
    window.removeEventListener("scroll", this.boundReposition, true)
    window.removeEventListener("resize", this.boundReposition)
  }

  show() {
    this.panelTarget.hidden = false
    this.reposition()
    window.addEventListener("scroll", this.boundReposition, true)
    window.addEventListener("resize", this.boundReposition)
  }

  hide(event) {
    if (this.element.contains(event.relatedTarget)) return

    this.panelTarget.hidden = true
    window.removeEventListener("scroll", this.boundReposition, true)
    window.removeEventListener("resize", this.boundReposition)
  }

  reposition() {
    const panel = this.panelTarget
    const rect = this.element.getBoundingClientRect()
    const gap = 6
    const width = panel.offsetWidth
    const height = panel.offsetHeight
    const left = Math.min(
      Math.max(8, rect.left),
      window.innerWidth - width - 8
    )
    const below = rect.bottom + gap
    const top = below + height > window.innerHeight - 8
      ? Math.max(8, rect.top - height - gap)
      : below

    panel.style.position = "fixed"
    panel.style.left = `${left}px`
    panel.style.top = `${top}px`
  }
}
