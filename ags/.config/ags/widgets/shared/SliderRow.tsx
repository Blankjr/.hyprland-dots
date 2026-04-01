import Gtk from "gi://Gtk?version=4.0"

export default function SliderRow({
  icon,
  label,
  value,
  onChanged,
  cssClass,
}: {
  icon: () => string
  label: () => string
  value: () => number
  onChanged: (value: number) => void
  cssClass?: () => string
}) {
  let updating = false

  const adj = new Gtk.Adjustment({
    lower: 0,
    upper: 1,
    value: value(),
    stepIncrement: 0.05,
    pageIncrement: 0.1,
  })

  // Watch for external state changes
  const checkInterval = setInterval(() => {
    if (!updating) {
      const v = value()
      if (Math.abs(adj.value - v) > 0.01) {
        updating = true
        adj.value = v
        updating = false
      }
    }
  }, 100)

  return (
    <box cssClasses={(() => {
      const classes = ["slider-row"]
      const extra = cssClass?.()
      if (extra) classes.push(extra)
      return classes
    })()}>
      <label cssClasses={["row-icon"]} label={icon()} />
      <slider
        cssClasses={["row-slider"]}
        hexpand
        drawValue={false}
        adjustment={adj}
        onValueChanged={(self: { get_value: () => number }) => {
          if (!updating) {
            updating = true
            onChanged(self.get_value())
            updating = false
          }
        }}
      />
      <label cssClasses={["row-value"]} label={label()} widthChars={5} />
    </box>
  )
}
