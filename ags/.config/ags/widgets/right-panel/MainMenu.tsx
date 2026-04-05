import { createMemo } from "ags"
import type { SubmenuId } from "../../lib/types"
import { dndEnabled, toggleDnd } from "../../lib/notification-service"
import { awakeEnabled, toggleAwake } from "../../lib/awake-service"

const navTiles = [
  { id: "sound-menu" as SubmenuId, icon: "󰕾", label: "Sound" },
  { id: "display-menu" as SubmenuId, icon: "󰍹", label: "Display" },
]

const focusClasses = createMemo(() =>
  dndEnabled() ? ["tile", "tile-active"] : ["tile"],
  { equals: () => false },
)

const focusIcon = createMemo(() =>
  dndEnabled() ? "󰍶" : "󰍷",
)

const awakeClasses = createMemo(() =>
  awakeEnabled() ? ["tile", "tile-awake-active"] : ["tile"],
  { equals: () => false },
)

const awakeIcon = createMemo(() =>
  awakeEnabled() ? "󰒳" : "󰒲",
)

export default function MainMenu({
  onNavigate,
  name,
}: {
  onNavigate: (id: SubmenuId) => void
  name?: string
}) {
  return (
    <box cssClasses={["main-menu"]} orientation={1} name={name ?? ""}>
      <label cssClasses={["menu-title"]} label="Control Panel" />
      <box cssClasses={["tile-grid"]} spacing={16} homogeneous>
        {navTiles.map((tile) => (
          <button
            cssClasses={["tile"]}
            onClicked={() => onNavigate(tile.id)}
          >
            <box orientation={1} halign={3}>
              <label cssClasses={["tile-icon"]} label={tile.icon} />
              <label cssClasses={["tile-label"]} label={tile.label} />
            </box>
          </button>
        ))}
        <button
          cssClasses={focusClasses}
          onClicked={() => toggleDnd()}
        >
          <box orientation={1} halign={3}>
            <label cssClasses={["tile-icon"]} label={focusIcon} />
            <label cssClasses={["tile-label"]} label="Focus" />
          </box>
        </button>
        <button
          cssClasses={awakeClasses}
          onClicked={() => toggleAwake()}
        >
          <box orientation={1} halign={3}>
            <label cssClasses={["tile-icon"]} label={awakeIcon} />
            <label cssClasses={["tile-label"]} label="Awake" />
          </box>
        </button>
      </box>
    </box>
  )
}
