import BackButton from "../shared/BackButton"
import SliderRow from "../shared/SliderRow"
import ToggleRow from "../shared/ToggleRow"
import SegmentToggle from "../shared/SegmentToggle"
import {
  brightness,
  brightnessAvailable,
  blueLight,
  blueLightAvailable,
  darkMode,
  setBrightness,
  toggleBlueLight,
  toggleDarkMode,
} from "../../lib/display-service"

export default function DisplayMenu({ onBack, name }: { onBack: () => void; name?: string }) {
  return (
    <box cssClasses={["submenu"]} orientation={1} name={name ?? ""}>
      <BackButton onBack={onBack} label="Display" />

      <revealer revealChild={brightnessAvailable}>
        <SliderRow
          icon={() => "󰃟"}
          label={() => `${brightness()}%`}
          value={() => brightness() / 100}
          onChanged={(v) => setBrightness(Math.round(v * 100))}
        />
      </revealer>

      <revealer revealChild={blueLightAvailable}>
        <ToggleRow
          icon={() => (blueLight() ? "󰖔" : "󰖕")}
          label="Blue Light Filter"
          active={blueLight}
          onToggled={toggleBlueLight}
        />
      </revealer>

      <SegmentToggle
        leftLabel="󰔏  Light"
        rightLabel="󰔎  Dark"
        active={darkMode}
        onToggled={toggleDarkMode}
      />
    </box>
  )
}
