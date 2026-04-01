import type { SubmenuId } from "../lib/types"

const tiles = [
  { id: "sound-menu" as SubmenuId, icon: "󰕾", label: "Sound", disabled: false },
  { id: "display-menu" as SubmenuId, icon: "󰍹", label: "Display", disabled: false },
  { id: "main-menu" as SubmenuId, icon: "󰍶", label: "Focus", disabled: true },
]

export default function MainMenu({
  onNavigate,
}: {
  onNavigate: (id: SubmenuId) => void
}) {
  return (
    <box cssClasses={["main-menu"]} orientation={1}>
      <label cssClasses={["menu-title"]} label="Control Panel" />
      <box cssClasses={["tile-grid"]} homogeneous>
        {tiles.map((tile) => (
          <button
            cssClasses={tile.disabled ? ["tile", "tile-disabled"] : ["tile"]}
            sensitive={!tile.disabled}
            onClicked={() => onNavigate(tile.id)}
          >
            <box orientation={1} halign={3}>
              <label cssClasses={["tile-icon"]} label={tile.icon} />
              <label cssClasses={["tile-label"]} label={tile.label} />
            </box>
          </button>
        ))}
      </box>
    </box>
  )
}
