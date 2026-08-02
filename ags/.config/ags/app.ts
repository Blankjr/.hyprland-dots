import app from "ags/gtk4/app"
import style from "./style.scss"
import RightPanel from "./widgets/right-panel/RightPanel"
import LeftPanel from "./widgets/left-panel/LeftPanel"
import AiChatWindow from "./widgets/ai-chat/AiChatWindow"
import { initAudioService } from "./lib/audio-service"
import { initDisplayService } from "./lib/display-service"
import { initNotificationService } from "./lib/notification-service"
import { initSystemService } from "./lib/system-service"
import { initAwakeService } from "./lib/awake-service"

function allPanels() {
  return [
    app.get_window("control-panel"),
    app.get_window("left-panel"),
  ]
}

app.start({
  css: style,
  requestHandler(argv: string[], response: (msg: string) => void) {
    const [cmd] = argv

    if (cmd === "toggle-panel") {
      const panels = allPanels()
      const newVisible = !panels[0]?.visible
      const aiWindow = app.get_window("ai-chat")
      if (newVisible && aiWindow) aiWindow.visible = false
      panels.forEach((w) => { if (w) w.visible = newVisible })
      response("ok")
      return
    }

    if (cmd === "show-panel") {
      const aiWindow = app.get_window("ai-chat")
      if (aiWindow) aiWindow.visible = false
      allPanels().forEach((w) => { if (w) w.visible = true })
      response("ok")
      return
    }

    if (cmd === "hide-panel") {
      allPanels().forEach((w) => { if (w) w.visible = false })
      response("ok")
      return
    }

    if (cmd === "toggle-ai") {
      const aiWindow = app.get_window("ai-chat")
      if (!aiWindow) {
        response("ai window unavailable")
        return
      }
      const newVisible = !aiWindow.visible
      if (newVisible) {
        allPanels().forEach((w) => { if (w) w.visible = false })
      }
      aiWindow.visible = newVisible
      response("ok")
      return
    }

    if (cmd === "hide-ai") {
      const aiWindow = app.get_window("ai-chat")
      if (aiWindow) aiWindow.visible = false
      response("ok")
      return
    }

    response("unknown command")
  },
  main() {
    initAudioService()
    initDisplayService()
    initNotificationService()
    initSystemService()
    initAwakeService()
    RightPanel()
    LeftPanel()
    AiChatWindow()
  },
})
