import { Astal } from "ags/gtk4"
import Gtk from "gi://Gtk?version=4.0"
import Gdk from "gi://Gdk?version=4.0"
import app from "ags/gtk4/app"
import Clock from "./Clock"
import Calendar from "./Calendar"
import ResourceGauges from "./ResourceGauges"
import { startPolling, stopPolling } from "../../lib/system-service"

export default function LeftPanel() {
  const win = (
    <window
      visible={false}
      name="left-panel"
      namespace="left-panel"
      application={app}
      exclusivity={Astal.Exclusivity.NORMAL}
      keymode={Astal.Keymode.ON_DEMAND}
      anchor={
        Astal.WindowAnchor.TOP |
        Astal.WindowAnchor.LEFT |
        Astal.WindowAnchor.BOTTOM
      }
      marginTop={140}
      marginBottom={140}
      marginLeft={8}
      onNotifyVisible={(self: { visible: boolean }) => {
        if (self.visible) startPolling()
        else stopPolling()
      }}
    >
      <box cssClasses={["left-panel-container"]} orientation={1}>
        <Clock />
        <Calendar />
        <ResourceGauges />
      </box>
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
