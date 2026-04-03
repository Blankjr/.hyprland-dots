import Gtk from "gi://Gtk?version=4.0"
import Pango from "gi://Pango"
import PangoCairo from "gi://PangoCairo"
import { cpuUsage, ramUsage, diskUsage } from "../../lib/system-service"

interface GaugeProps {
  value: () => number
  icon: string
  label: string
  color: [number, number, number]
}

function hexToRgb(hex: string): [number, number, number] {
  const n = parseInt(hex.replace("#", ""), 16)
  return [(n >> 16) / 255, ((n >> 8) & 0xff) / 255, (n & 0xff) / 255]
}

const CPU_COLOR = hexToRgb("#33ccff")
const RAM_COLOR = hexToRgb("#a6e3a1")
const DISK_COLOR = hexToRgb("#f9e2af")

function CircularGauge({ value, icon, label, color }: GaugeProps) {
  const CIRCLE = 110
  const LINE_WIDTH = 8
  const PAD = LINE_WIDTH / 2 + 2 // prevent stroke clipping
  const RADIUS = (CIRCLE - LINE_WIDTH) / 2
  const WIDTH = CIRCLE + PAD * 2
  const TOTAL_HEIGHT = CIRCLE + PAD * 2 + 28 // space for label below

  const area = new Gtk.DrawingArea()
  area.set_size_request(WIDTH, TOTAL_HEIGHT)
  area.cssClasses = ["gauge"]

  area.set_draw_func((_widget: Gtk.DrawingArea, cr: any, width: number) => {
    const cx = width / 2
    const cy = CIRCLE / 2 + PAD
    const pct = value() / 100
    const startAngle = -Math.PI / 2
    const endAngle = startAngle + 2 * Math.PI * pct

    // Background trough circle
    cr.setSourceRGBA(0.2, 0.2, 0.3, 0.5)
    cr.setLineWidth(LINE_WIDTH)
    cr.arc(cx, cy, RADIUS, 0, 2 * Math.PI)
    cr.stroke()

    // Progress arc
    if (pct > 0) {
      cr.setSourceRGBA(color[0], color[1], color[2], 1)
      cr.setLineWidth(LINE_WIDTH)
      cr.setLineCap(1) // ROUND
      cr.arc(cx, cy, RADIUS, startAngle, endAngle)
      cr.stroke()
    }

    // Percentage text centered in circle
    const pctLayout = PangoCairo.create_layout(cr)
    pctLayout.set_font_description(
      Pango.FontDescription.from_string("JetBrainsMono Nerd Font 13"),
    )
    pctLayout.set_text(`${Math.round(value())}%`, -1)
    pctLayout.set_alignment(Pango.Alignment.CENTER)
    const [, pctExt] = pctLayout.get_pixel_extents()
    cr.setSourceRGBA(0.8, 0.84, 0.96, 1) // --cp-text
    cr.moveTo(cx - pctExt.width / 2, cy - pctExt.height / 2)
    PangoCairo.show_layout(cr, pctLayout)

    // Label below circle
    const labelLayout = PangoCairo.create_layout(cr)
    labelLayout.set_font_description(
      Pango.FontDescription.from_string("JetBrainsMono Nerd Font 9"),
    )
    labelLayout.set_text(label, -1)
    labelLayout.set_alignment(Pango.Alignment.CENTER)
    const [, labelExt] = labelLayout.get_pixel_extents()
    cr.setSourceRGBA(0.345, 0.357, 0.439, 1) // --cp-text-dim
    cr.moveTo(cx - labelExt.width / 2, CIRCLE + PAD * 2 + 4)
    PangoCairo.show_layout(cr, labelLayout)
  })

  // Redraw when resource values update
  setInterval(() => area.queue_draw(), 3000)

  return area
}

export default function ResourceGauges() {
  return (
    <box cssClasses={["gauges-row"]} homogeneous halign={Gtk.Align.CENTER} spacing={16}>
      {CircularGauge({ value: cpuUsage, icon: "", label: "CPU", color: CPU_COLOR })}
      {CircularGauge({ value: ramUsage, icon: "", label: "RAM", color: RAM_COLOR })}
      {CircularGauge({ value: diskUsage, icon: "󰋊", label: "DISK", color: DISK_COLOR })}
    </box>
  )
}
