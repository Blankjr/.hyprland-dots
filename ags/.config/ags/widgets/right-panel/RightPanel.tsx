import { Astal } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import app from "ags/gtk4/app"
import type { SubmenuId } from "../../lib/types"
import MainMenu from "./MainMenu"
import SoundMenu from "./SoundMenu"
import DisplayMenu from "./DisplayMenu"
import { startPolling as startAudio, stopPolling as stopAudio } from "../../lib/audio-service"
import { startPolling as startDisplay, stopPolling as stopDisplay } from "../../lib/display-service"

let stack: Gtk.Stack | null = null

function stopAllPolling() {
  stopAudio()
  stopDisplay()
}

function navigate(id: SubmenuId) {
  stopAllPolling()
  if (id === "sound-menu") startAudio()
  if (id === "display-menu") startDisplay()
  if (stack) stack.visibleChildName = id
}

export function resetMenu() {
  if (stack) stack.visibleChildName = "main-menu"
}

export default function RightPanel() {
  stack = new Gtk.Stack({
    transitionType: Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
    transitionDuration: 200,
  })
  stack.add_named(MainMenu({ onNavigate: navigate }) as Gtk.Widget, "main-menu")
  stack.add_named(SoundMenu({ onBack: () => navigate("main-menu") }) as Gtk.Widget, "sound-menu")
  stack.add_named(DisplayMenu({ onBack: () => navigate("main-menu") }) as Gtk.Widget, "display-menu")
  stack.visibleChildName = "main-menu"

  const container = new Gtk.Box({ orientation: Gtk.Orientation.VERTICAL })
  container.cssClasses = ["panel-container"]
  container.append(stack)

  const win = (
    <window
      visible={false}
      name="control-panel"
      namespace="control-panel"
      application={app}
      exclusivity={Astal.Exclusivity.NORMAL}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.RIGHT |
        Astal.WindowAnchor.BOTTOM
      }
      marginTop={140}
      marginBottom={140}
      marginRight={8}
      onNotifyVisible={(self: { visible: boolean }) => {
        if (!self.visible) {
          stopAllPolling()
          resetMenu()
        }
      }}
    >
      {container}
    </window>
  ) as Gtk.Window

  const keyCtrl = new Gtk.EventControllerKey()
  keyCtrl.connect("key-pressed", (_ctrl: unknown, keyval: number) => {
    if (keyval === Gdk.KEY_Escape) {
      app.get_window("control-panel")!.visible = false
      app.get_window("left-panel")!.visible = false
    }
    return false
  })
  win.add_controller(keyCtrl)

  return win
}
