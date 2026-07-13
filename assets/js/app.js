// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/plataforma"
import ToastHook from "./toast-hook"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const Hooks = {...colocatedHooks}
Hooks.ToastHook = ToastHook

window.__toastHook = null

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

const setupAvatarForm = () => {
  const form = document.querySelector("[data-avatar-form]")
  if (!form || form.dataset.avatarBound === "true") return

  form.dataset.avatarBound = "true"
  const input = form.querySelector("#avatar-input")
  const preview = document.querySelector("#avatar-preview")
  const submit = form.querySelector("#avatar-submit")
  const error = form.querySelector("#avatar-client-error")
  let previewUrl

  input.addEventListener("change", () => {
    const file = input.files[0]
    error.classList.add("hidden")
    error.textContent = ""

    if (!file) return

    if (file.size > 5 * 1024 * 1024) {
      input.value = ""
      error.textContent = "A imagem deve ter no máximo 5 MB."
      error.classList.remove("hidden")
      return
    }

    if (previewUrl) URL.revokeObjectURL(previewUrl)
    previewUrl = URL.createObjectURL(file)
    preview.src = previewUrl
  })

  form.addEventListener("submit", () => {
    if (submit.disabled) return
    submit.disabled = true
    submit.textContent = submit.dataset.loadingLabel
  })
}

document.addEventListener("DOMContentLoaded", setupAvatarForm)
window.addEventListener("phx:page-loading-stop", setupAvatarForm)

const setupNotificationsMenu = () => {
  const toggle = document.querySelector("[data-notifications-toggle]")
  const menu = document.querySelector("[data-notifications-menu]")
  if (!toggle || !menu || toggle.dataset.notificationsBound === "true") return

  toggle.dataset.notificationsBound = "true"

  const close = (restoreFocus = false) => {
    menu.classList.add("hidden")
    toggle.setAttribute("aria-expanded", "false")
    if (restoreFocus) toggle.focus()
  }

  const open = () => {
    const userMenu = document.getElementById("header-user-menu")
    const userToggle = document.getElementById("header-user-menu-toggle")
    userMenu?.classList.add("hidden")
    userToggle?.setAttribute("aria-expanded", "false")
    menu.classList.remove("hidden")
    toggle.setAttribute("aria-expanded", "true")
  }

  toggle.addEventListener("click", event => {
    event.stopPropagation()
    menu.classList.contains("hidden") ? open() : close()
  })

  menu.addEventListener("click", event => event.stopPropagation())
  document.addEventListener("click", () => close())
  document.addEventListener("keydown", event => {
    if (event.key === "Escape" && !menu.classList.contains("hidden")) close(true)
  })
}

document.addEventListener("DOMContentLoaded", setupNotificationsMenu)
window.addEventListener("phx:page-loading-stop", setupNotificationsMenu)

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
