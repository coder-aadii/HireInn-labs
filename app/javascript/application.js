import "@hotwired/turbo-rails"
import "controllers"
import { initializePublicCursor, teardownPublicCursor } from "cursor"

let aiPreviewLoadingStart = null
const flashDismissTimers = new WeakMap()
const scrollSequenceHandlers = new WeakMap()

const dismissFlashNotice = (notice) => {
  if (!(notice instanceof HTMLElement)) return
  const existingTimer = flashDismissTimers.get(notice)
  if (existingTimer) {
    window.clearTimeout(existingTimer)
    flashDismissTimers.delete(notice)
  }
  notice.remove()
}

const initializeFlashNotices = () => {
  document.querySelectorAll("#flash .notice").forEach((notice) => {
    if (flashDismissTimers.has(notice)) return

    const timer = window.setTimeout(() => {
      dismissFlashNotice(notice)
    }, 5000)

    flashDismissTimers.set(notice, timer)
  })
}

const teardownScrollSequences = () => {
  document.querySelectorAll("[data-scroll-sequence='true']").forEach((section) => {
    const teardown = scrollSequenceHandlers.get(section)
    if (typeof teardown === "function") teardown()
    scrollSequenceHandlers.delete(section)
  })
}

const initializeScrollSequences = () => {
  teardownScrollSequences()

  document.querySelectorAll("[data-scroll-sequence='true']").forEach((section) => {
    if (!(section instanceof HTMLElement)) return

    const image = section.querySelector("[data-scroll-sequence-image='true']")
    if (!(image instanceof HTMLImageElement)) return
    const leftRail = section.querySelector(".landing-scroll-sequence__rail--left")
    const rightRail = section.querySelector(".landing-scroll-sequence__rail--right")

    let frames = []

    try {
      frames = JSON.parse(section.dataset.scrollFrames || "[]")
    } catch (_error) {
      frames = []
    }

    if (!frames.length) return

    const preloadCount = Math.min(frames.length, 12)
    frames.slice(0, preloadCount).forEach((src) => {
      const preloadImage = new Image()
      preloadImage.src = src
    })

    let frameIndex = -1

    const updateFrame = () => {
      if (window.innerWidth <= 768) {
        if (frameIndex !== 0) {
          image.src = frames[0]
          frameIndex = 0
        }
        image.style.transform = "scale(1)"
        if (leftRail instanceof HTMLElement) leftRail.style.transform = "translateY(0)"
        if (rightRail instanceof HTMLElement) rightRail.style.transform = "translateY(0)"
        return
      }

      const rect = section.getBoundingClientRect()
      const maxTravel = Math.max(section.offsetHeight - window.innerHeight, 1)
      const pixelsScrolled = Math.min(Math.max(-rect.top, 0), maxTravel)
      const progress = pixelsScrolled / maxTravel

      const nextFrameIndex = Math.min(
        frames.length - 1,
        Math.round(progress * (frames.length - 1))
      )

      if (nextFrameIndex !== frameIndex) {
        image.src = frames[nextFrameIndex]
        frameIndex = nextFrameIndex
      }

      // const scale = 1 + progress * 0.6
      // image.style.transform = `scale(${scale})`

      // 🔥 Better easing (smooth start + smooth end)
      const easeInOut = (t) =>
        t < 0.5
          ? 4 * t * t * t
          : 1 - Math.pow(-2 * t + 2, 3) / 2

      const eased = easeInOut(progress)

      // 🔥 Controlled zoom
      const scale = 1.2 + eased * 0.2

      // 🔥 Subtle horizontal drift (adds realism)
      const driftX = (progress - 0.5) * 40

      image.style.transform = `scale(${scale}) translateX(${driftX}px)`

      const translateY = progress * 80

      // 🔥 Parallax depth (different speeds)
      if (leftRail instanceof HTMLElement) {
        leftRail.style.transform = `translateY(${translateY * 0.5}px)`
      }

      if (rightRail instanceof HTMLElement) {
        rightRail.style.transform = `translateY(${translateY * 0.7}px)`
      }
    }

    let ticking = false
    const onScroll = () => {
      if (ticking) return
      ticking = true
      window.requestAnimationFrame(() => {
        updateFrame()
        ticking = false
      })
    }

    updateFrame()
    window.addEventListener("scroll", onScroll, { passive: true })
    window.addEventListener("resize", onScroll)

    scrollSequenceHandlers.set(section, () => {
      window.removeEventListener("scroll", onScroll)
      window.removeEventListener("resize", onScroll)
    })
  })
}

const isGenerateAiRequest = (event) => {
  const form = event.target instanceof HTMLFormElement ? event.target : null
  if (!form || !form.matches(".job-entry-form")) return false

  const body = event.detail?.fetchOptions?.body
  if (body instanceof FormData) return body.has("generate_ai")
  if (body instanceof URLSearchParams) return body.has("generate_ai")
  if (typeof body === "string") return body.includes("generate_ai")

  return false
}

const clearAiPreviewLoader = () => {
  if (aiPreviewLoadingStart === null) return

  const elapsed = Date.now() - aiPreviewLoadingStart
  const delay = Math.max(0, 400 - elapsed)

  window.setTimeout(() => {
    document.getElementById("job_ai_preview_wrapper")?.classList.remove("is-loading")
    aiPreviewLoadingStart = null
  }, delay)
}

document.addEventListener("turbo:before-fetch-request", (event) => {
  if (!isGenerateAiRequest(event)) return

  aiPreviewLoadingStart = Date.now()
  const wrapper = document.getElementById("job_ai_preview_wrapper")
  wrapper?.classList.add("is-loading")
  wrapper?.scrollIntoView({ behavior: "smooth", block: "start" })
})

document.addEventListener("turbo:frame-load", (event) => {
  if (event.target.id !== "job_ai_preview") return
  clearAiPreviewLoader()
})

document.addEventListener("turbo:submit-end", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || !form.matches(".job-entry-form")) return
  clearAiPreviewLoader()
})

document.addEventListener("turbo:load", () => {
  initializeFlashNotices()
  initializePublicCursor()
  initializeScrollSequences()

  const reveals = document.querySelectorAll(".reveal")
  if (!reveals.length) return

  const observer = new IntersectionObserver(
    (entries, obs) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        entry.target.classList.add("is-visible")
        obs.unobserve(entry.target)
      })
    },
    { threshold: 0.15 }
  )

  reveals.forEach((el) => observer.observe(el))
})

document.addEventListener("turbo:before-cache", () => {
  teardownScrollSequences()
  teardownPublicCursor()
})

const updateResumeFileLabels = () => {
  document.querySelectorAll("input[type='file'][data-file-label-target]").forEach((input) => {
    if (!(input instanceof HTMLInputElement)) return

    const targetId = input.dataset.fileLabelTarget
    const label = targetId ? document.getElementById(targetId) : null
    if (!label) return

    const names = Array.from(input.files || [])
      .map((file) => file.name)
      .filter(Boolean)

    label.textContent = names.length ? names.join(", ") : "Choose resumes (PDF, DOC, DOCX)"
  })
}

const updateResumeMatchState = () => {
  document.querySelectorAll("form[data-resume-match-form='true']").forEach((form) => {
    if (!(form instanceof HTMLFormElement)) return

    const submit = form.querySelector("[data-resume-match-submit='true']")
    const selectAll = form.querySelector("[data-select-all-resumes='true']")
    const rowChecks = form.querySelectorAll("input[name='resume_ids[]']")
    const anySelected = Array.from(rowChecks).some((checkbox) => checkbox.checked)
    const enabled = anySelected || (selectAll instanceof HTMLInputElement && selectAll.checked)

    if (submit instanceof HTMLButtonElement || submit instanceof HTMLInputElement) {
      submit.disabled = !enabled
    }
  })
}

const getDialogBackdrop = () => document.querySelector(".dialog-backdrop")

const showDialog = (dialog) => {
  if (!dialog) return
  dialog.classList.add("is-open")
  dialog.removeAttribute("aria-hidden")
  document.body.classList.add("dialog-open")

  if (!getDialogBackdrop()) {
    const backdrop = document.createElement("div")
    backdrop.className = "dialog-backdrop"
    document.body.appendChild(backdrop)
    backdrop.addEventListener("click", () => hideDialog(dialog))
  }
}

const hideDialog = (dialog) => {
  if (!dialog) return
  dialog.classList.remove("is-open")
  dialog.setAttribute("aria-hidden", "true")
  const backdrop = getDialogBackdrop()
  if (backdrop) backdrop.remove()
  document.body.classList.remove("dialog-open")
}

document.addEventListener("click", (event) => {
  const downloadMatchPdf = event.target.closest("[data-download-match-pdf='true']")
  if (downloadMatchPdf) {
    event.preventDefault()
    const surface = downloadMatchPdf.closest("[data-match-details-surface='true']")
    if (!surface) return

    const candidateName = surface.dataset.candidateName || "candidate"
    const printWindow = window.open("", "_blank", "width=960,height=1200")
    if (!printWindow) return

    printWindow.document.write(`
      <html>
        <head>
          <title>${candidateName} Match Details</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 24px; color: #111; }
            .match-details-footer, .match-details-close { display: none !important; }
            .match-details-surface { border: 0; box-shadow: none; max-height: none; }
            .match-details-header { margin-bottom: 20px; }
            .match-details-meta { display: flex; gap: 12px; align-items: center; margin-top: 8px; color: #444; }
            .match-score { display: inline-block; padding: 4px 10px; border: 1px solid #b88912; border-radius: 999px; font-weight: 700; color: #b88912; }
            .match-section { padding: 14px 0; border-top: 1px solid #ddd; }
            .match-section:first-of-type { border-top: none; }
            .match-section h6 { margin: 0 0 8px; font-size: 12px; text-transform: uppercase; letter-spacing: 1.2px; color: #666; }
            .match-section p { margin: 0; line-height: 1.6; white-space: pre-wrap; }
          </style>
        </head>
        <body>${surface.outerHTML}</body>
      </html>
    `)
    printWindow.document.close()
    printWindow.focus()
    printWindow.print()
    return
  }

  const dialogTrigger = event.target.closest("[data-ui-toggle='dialog']")
  if (dialogTrigger) {
    event.preventDefault()
    const target = dialogTrigger.getAttribute("data-ui-target")
    const dialog = document.querySelector(target)
    showDialog(dialog)
    return
  }

  const dialogDismiss = event.target.closest("[data-ui-dismiss='dialog']")
  if (dialogDismiss) {
    event.preventDefault()
    const dialog = dialogDismiss.closest(".dialog")
    hideDialog(dialog)
    return
  }

  const noticeDismiss = event.target.closest("[data-ui-dismiss='notice']")
  if (noticeDismiss) {
    event.preventDefault()
    const notice = noticeDismiss.closest(".notice")
    dismissFlashNotice(notice)
  }
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return
  const dialog = document.querySelector(".dialog.is-open")
  if (dialog) hideDialog(dialog)
})

document.addEventListener("click", (event) => {
  const dateInput = event.target.closest("input[type='date'][data-open-picker='true']")
  if (dateInput && typeof dateInput.showPicker === "function") {
    dateInput.showPicker()
    return
  }

  const tabTrigger = event.target.closest("[data-ui-tab-target]")
  if (!tabTrigger) return
  event.preventDefault()

  const target = tabTrigger.getAttribute("data-ui-tab-target")
  const tabPanel = document.querySelector(target)
  if (!tabPanel) return

  const tabList = tabTrigger.closest(".tabs")
  tabList?.querySelectorAll(".tab").forEach((tab) => tab.classList.remove("is-active"))
  tabTrigger.classList.add("is-active")

  const container = tabPanel.closest(".tab-panels")
  container?.querySelectorAll(".tab-panel").forEach((pane) => {
    pane.classList.remove("is-active")
  })
  tabPanel.classList.add("is-active")
})

document.addEventListener("change", (event) => {
  const fileInput = event.target.closest("input[type='file'][data-file-label-target]")
  if (fileInput) {
    updateResumeFileLabels()
    return
  }

  const selectAll = event.target.closest("[data-select-all-resumes='true']")
  if (selectAll instanceof HTMLInputElement) {
    const form = selectAll.closest("form[data-resume-match-form='true']")
    form?.querySelectorAll("input[name='resume_ids[]']").forEach((checkbox) => {
      checkbox.checked = selectAll.checked
    })
    updateResumeMatchState()
    return
  }

  const rowCheck = event.target.closest("input[name='resume_ids[]']")
  if (rowCheck instanceof HTMLInputElement) {
    const form = rowCheck.closest("form[data-resume-match-form='true']")
    const selectAllInput = form?.querySelector("[data-select-all-resumes='true']")

    if (selectAllInput instanceof HTMLInputElement) {
      const rowChecks = Array.from(form.querySelectorAll("input[name='resume_ids[]']"))
      selectAllInput.checked = rowChecks.length > 0 && rowChecks.every((checkbox) => checkbox.checked)
    }

    updateResumeMatchState()
  }
})

document.addEventListener("submit", (event) => {
  const form = event.target.closest("form[data-resume-match-form='true']")
  if (!(form instanceof HTMLFormElement)) return

  const selectAll = form.querySelector("[data-select-all-resumes='true']")
  const anySelected = Array.from(form.querySelectorAll("input[name='resume_ids[]']")).some((checkbox) => checkbox.checked)
  const selectAllChecked = selectAll instanceof HTMLInputElement && selectAll.checked

  if (anySelected || selectAllChecked) return

  event.preventDefault()
  window.alert("Select at least one resume before running AI match.")
})

document.addEventListener("turbo:load", () => {
  updateResumeFileLabels()
  updateResumeMatchState()
})

let phoneInputInstance = null

const initializePhoneInput = () => {
  const input = document.querySelector("#phone_input")
  const hiddenInput = document.querySelector("#full_phone")
  if (!(input instanceof HTMLInputElement) || !(hiddenInput instanceof HTMLInputElement)) return
  if (typeof window.intlTelInput !== "function") return

  if (phoneInputInstance?.destroy) {
    phoneInputInstance.destroy()
    phoneInputInstance = null
  }

  phoneInputInstance = window.intlTelInput(input, {
    initialCountry: "in"
  })

  const syncFullPhone = () => {
    if (!phoneInputInstance) return
    hiddenInput.value = phoneInputInstance.getNumber()
  }

  input.addEventListener("blur", syncFullPhone)
  input.form?.addEventListener("submit", syncFullPhone)
}

document.addEventListener("turbo:load", initializePhoneInput)
