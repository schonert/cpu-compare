import { Controller } from "@hotwired/stimulus"

// Positions a citation tooltip in the viewport so table overflow and card
// clipping cannot hide it. Shown on hover and keyboard focus; a short hide
// delay lets the pointer cross the gap onto a source link inside the panel.
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundReposition = this.reposition.bind(this)
  }

  disconnect() {
    this.cancelHide()
    this.unlisten()
  }

  show() {
    this.cancelHide()
    const panel = this.panelTarget
    panel.hidden = false
    panel.style.visibility = "hidden"
    this.reposition()
    panel.style.visibility = "visible"
    window.addEventListener("scroll", this.boundReposition, true)
    window.addEventListener("resize", this.boundReposition)
  }

  hide(event) {
    if (this.element.contains(event.relatedTarget)) return

    this.cancelHide()
    this.hideTimer = setTimeout(() => this.close(), 180)
  }

  close() {
    this.panelTarget.hidden = true
    this.panelTarget.style.visibility = ""
    this.unlisten()
  }

  cancelHide() {
    clearTimeout(this.hideTimer)
  }

  unlisten() {
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
