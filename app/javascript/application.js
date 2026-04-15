import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement)) return
  const submitter = event.submitter
  if (submitter && submitter.name === "generate_ai") {
    const previewFrame = document.getElementById("job_ai_preview")
    if (previewFrame) previewFrame.classList.add("is-loading")
    const previewCard = document.querySelector(".ai-preview")
    if (previewCard) previewCard.classList.add("is-loading")
    submitter.disabled = true
  }
})

document.addEventListener("turbo:submit-end", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement)) return
  const previewFrame = document.getElementById("job_ai_preview")
  if (previewFrame) previewFrame.classList.remove("is-loading")
  const previewCard = document.querySelector(".ai-preview")
  if (previewCard) previewCard.classList.remove("is-loading")
  const submitter = event.detail.formSubmission?.submitter
  if (submitter && submitter.name === "generate_ai") {
    submitter.disabled = false
  }
})

document.addEventListener("turbo:load", () => {
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
    if (notice) notice.remove()
  }
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return
  const dialog = document.querySelector(".dialog.is-open")
  if (dialog) hideDialog(dialog)
})

document.addEventListener("click", (event) => {
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
