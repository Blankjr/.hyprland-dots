import { createState } from "ags"
import { Astal } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import app from "ags/gtk4/app"
import type { SubmenuId } from "../lib/types"
import MainMenu from "./MainMenu"
import SoundMenu from "./SoundMenu"
import DisplayMenu from "./DisplayMenu"
import { startPolling as startAudio, stopPolling as stopAudio } from "../lib/audio-service"
import { startPolling as startDisplay, stopPolling as stopDisplay } from "../lib/display-service"

const [activeMenu, setActiveMenu] = createState<SubmenuId>("main-menu")

function stopAllPolling() {
  stopAudio()
  stopDisplay()
}

function navigate(id: SubmenuId) {
  stopAllPolling()
  if (id === "sound-menu") startAudio()
  if (id === "display-menu") startDisplay()
  setActiveMenu(id)
}

export function resetMenu() {
  setActiveMenu("main-menu")
}

export default function ControlPanel() {
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
          setActiveMenu("main-menu")
        }
      }}
    >
      <box cssClasses={["panel-container"]} orientation={1}>
        <stack
          visibleChildName={activeMenu}
          transitionType={Gtk.StackTransitionType.SLIDE_LEFT_RIGHT}
          transitionDuration={200}
        >
          <MainMenu
            $type="named"
            name="main-menu"
            onNavigate={navigate}
          />
          <SoundMenu
            $type="named"
            name="sound-menu"
            onBack={() => navigate("main-menu")}
          />
          <DisplayMenu
            $type="named"
            name="display-menu"
            onBack={() => navigate("main-menu")}
          />
        </stack>
      </box>
    </window>
  ) as Gtk.Window

  const keyCtrl = new Gtk.EventControllerKey()
  keyCtrl.connect("key-pressed", (_ctrl: unknown, keyval: number) => {
    if (keyval === Gdk.KEY_Escape) {
      win.hide()
    }
    return false
  })
  win.add_controller(keyCtrl)

  return win
}
