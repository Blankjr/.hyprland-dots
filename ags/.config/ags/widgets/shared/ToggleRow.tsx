export default function ToggleRow({
  icon,
  label,
  active,
  onToggled,
}: {
  icon: () => string
  label: string
  active: () => boolean
  onToggled: () => void
}) {
  return (
    <box cssClasses={["toggle-row"]}>
      <label cssClasses={["row-icon"]} label={icon()} />
      <label cssClasses={["row-label"]} label={label} hexpand />
      <switch
        active={active()}
        onStateSet={() => {
          onToggled()
          return true
        }}
      />
    </box>
  )
}
