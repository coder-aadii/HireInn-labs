const TRAIL_INTERVAL_MS = 40
const MAX_TRAIL_NODES = 14
const LERP_FACTOR = 0.2
const INTERACTIVE_SELECTOR = [
  "a",
  "button",
  "input",
  "textarea",
  "select",
  "summary",
  "label",
  "[role='button']",
  "[contenteditable='true']"
].join(",")

let activeCursor = null

class PublicCursor {
  constructor(root, imagePath) {
    this.root = root
    this.imagePath = imagePath
    this.cursor = null
    this.rafId = null
    this.trails = []
    this.lastTrailAt = 0
    this.targetX = 0
    this.targetY = 0
    this.currentX = 0
    this.currentY = 0
    this.hasPointer = false
    this.isSuppressed = false

    this.handlePointerMove = this.handlePointerMove.bind(this)
    this.handlePointerLeave = this.handlePointerLeave.bind(this)
    this.handlePointerEnter = this.handlePointerEnter.bind(this)
    this.handleMouseOver = this.handleMouseOver.bind(this)
    this.handleMouseOut = this.handleMouseOut.bind(this)
    this.tick = this.tick.bind(this)
  }

  mount() {
    this.cursor = document.createElement("img")
    this.cursor.src = this.imagePath
    this.cursor.alt = ""
    this.cursor.className = "cursor-logo"
    this.cursor.draggable = false
    this.cursor.addEventListener("error", () => this.destroy(), { once: true })
    this.root.replaceChildren(this.cursor)
    document.body.classList.add("cursor-active")

    window.addEventListener("pointermove", this.handlePointerMove, { passive: true })
    document.addEventListener("pointerleave", this.handlePointerLeave)
    document.addEventListener("pointerenter", this.handlePointerEnter)
    document.addEventListener("mouseover", this.handleMouseOver)
    document.addEventListener("mouseout", this.handleMouseOut)

    this.rafId = window.requestAnimationFrame(this.tick)
  }

  destroy() {
    document.body.classList.remove("cursor-active")

    window.removeEventListener("pointermove", this.handlePointerMove)
    document.removeEventListener("pointerleave", this.handlePointerLeave)
    document.removeEventListener("pointerenter", this.handlePointerEnter)
    document.removeEventListener("mouseover", this.handleMouseOver)
    document.removeEventListener("mouseout", this.handleMouseOut)

    if (this.rafId) {
      window.cancelAnimationFrame(this.rafId)
      this.rafId = null
    }

    this.trails.forEach((trail) => trail.remove())
    this.trails = []
    this.root.replaceChildren()
  }

  handlePointerMove(event) {
    if (event.pointerType && event.pointerType !== "mouse") return

    this.targetX = event.clientX
    this.targetY = event.clientY

    if (!this.hasPointer) {
      this.currentX = event.clientX
      this.currentY = event.clientY
    }

    this.hasPointer = true

    this.setCursorVisibility(true)

    const now = performance.now()
    if (now - this.lastTrailAt >= TRAIL_INTERVAL_MS) {
      this.spawnTrail(this.currentX, this.currentY)
      this.lastTrailAt = now
    }
  }

  handlePointerLeave() {
    this.setCursorVisibility(false)
  }

  handlePointerEnter() {
    if (this.hasPointer) {
      this.setCursorVisibility(true)
    }
  }

  handleMouseOver(event) {
    const el = event.target.closest(INTERACTIVE_SELECTOR)
    if (!el) return

    // Optional: slight scale for premium feel
    this.cursor.style.transform += " scale(1.1)"
  }

  handleMouseOut(event) {
    const el = event.relatedTarget?.closest(INTERACTIVE_SELECTOR)
    if (el) return

    // reset scale
    this.cursor.style.transform = this.cursor.style.transform.replace(" scale(1.1)", "")
  }

  setCursorVisibility(visible) {
    if (!this.cursor) return
    this.cursor.classList.toggle("is-visible", visible)
    this.cursor.classList.toggle("is-hidden", !visible)
  }

  spawnTrail(x, y) {
    const trail = document.createElement("img")
    trail.src = this.imagePath
    trail.alt = ""
    trail.className = "cursor-trail"
    trail.draggable = false

    const size = 32

    trail.style.setProperty('--x', `${x - size / 2}px`)
    trail.style.setProperty('--y', `${y - size / 2}px`)

    trail.addEventListener("animationend", () => {
      trail.remove()
      this.trails = this.trails.filter((node) => node !== trail)
    }, { once: true })

    this.root.appendChild(trail)
    this.trails.push(trail)

    if (this.trails.length > MAX_TRAIL_NODES) {
      const staleTrail = this.trails.shift()
      staleTrail?.remove()
    }
  }

  tick() {
    if (this.hasPointer && this.cursor) {
      this.currentX += (this.targetX - this.currentX) * LERP_FACTOR
      this.currentY += (this.targetY - this.currentY) * LERP_FACTOR

      this.cursor.style.transform = `translate3d(${this.currentX - 16}px, ${this.currentY - 16}px, 0)`
    }

    this.rafId = window.requestAnimationFrame(this.tick)
  }
}

const shouldEnablePublicCursor = () => {
  if (!document.body.classList.contains("public-cursor")) return false
  if (window.matchMedia("(hover: none), (pointer: coarse)").matches) return false
  if (navigator.maxTouchPoints > 0) return false
  return true
}

export const initializePublicCursor = () => {
  if (activeCursor) {
    activeCursor.destroy()
    activeCursor = null
  }

  if (!shouldEnablePublicCursor()) return

  const root = document.getElementById("cursor-root")
  if (!root) return
  const imagePath = root.dataset.cursorImage
  if (!imagePath) return

  activeCursor = new PublicCursor(root, imagePath)
  activeCursor.mount()
}

export const teardownPublicCursor = () => {
  if (!activeCursor) return
  activeCursor.destroy()
  activeCursor = null
}