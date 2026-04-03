import Gtk from "gi://Gtk?version=4.0"
import { currentTime, uptime } from "../../lib/system-service"

export default function Clock() {
  const timeLabel = new Gtk.Label({ label: currentTime() })
  timeLabel.cssClasses = ["clock-time"]

  const uptimeLabel = new Gtk.Label({ label: `uptime: ${uptime()}` })
  uptimeLabel.cssClasses = ["clock-uptime"]

  setInterval(() => {
    timeLabel.label = currentTime()
    uptimeLabel.label = `uptime: ${uptime()}`
  }, 1000)

  return (
    <box cssClasses={["clock-section"]} orientation={1} halign={Gtk.Align.CENTER}>
      {timeLabel}
      {uptimeLabel}
    </box>
  )
}
