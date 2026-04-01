import app from "ags/gtk4/app"
import style from "./style.scss"
import ControlPanel from "./widgets/ControlPanel"
import { initAudioService } from "./lib/audio-service"
import { initDisplayService } from "./lib/display-service"

app.start({
  css: style,
  requestHandler(argv: string[], response: (msg: string) => void) {
    const [cmd] = argv

    if (cmd === "toggle-panel") {
      const win = app.get_window("control-panel")
      if (win) win.visible = !win.visible
      response("ok")
      return
    }

    if (cmd === "show-panel") {
      const win = app.get_window("control-panel")
      if (win) win.visible = true
      response("ok")
      return
    }

    if (cmd === "hide-panel") {
      const win = app.get_window("control-panel")
      if (win) win.visible = false
      response("ok")
      return
    }

    response("unknown command")
  },
  main() {
    initAudioService()
    initDisplayService()
    ControlPanel()
  },
})
