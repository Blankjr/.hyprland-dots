import Gtk from "gi://Gtk?version=4.0"
import BackButton from "./shared/BackButton"
import SliderRow from "./shared/SliderRow"
import ToggleRow from "./shared/ToggleRow"
import {
  sinks,
  sinkVolume,
  sinkMuted,
  sourceMuted,
  setVolume,
  toggleSinkMute,
  toggleSourceMute,
  setDefaultSink,
} from "../lib/audio-service"

export default function SoundMenu({ onBack, name }: { onBack: () => void; name?: string }) {
  return (
    <box cssClasses={["submenu"]} orientation={1} name={name ?? ""}>
      <BackButton onBack={onBack} label="Sound" />

      <SliderRow
        icon={() => (sinkMuted() ? "󰝟" : "󰕾")}
        label={() => `${Math.round(sinkVolume() * 100)}%`}
        value={sinkVolume}
        onChanged={setVolume}
        cssClass={() => (sinkMuted() ? "muted" : "")}
      />

      <ToggleRow
        icon={() => (sinkMuted() ? "󰝟" : "󰓃")}
        label="Speaker"
        active={() => !sinkMuted()}
        onToggled={toggleSinkMute}
      />

      <ToggleRow
        icon={() => (sourceMuted() ? "󰍭" : "󰍬")}
        label="Microphone"
        active={() => !sourceMuted()}
        onToggled={toggleSourceMute}
      />

      <Gtk.Separator />

      <label cssClasses={["section-label"]} label="OUTPUT DEVICE" />

      {sinks().map((sink) => (
        <button
          cssClasses={sink.isDefault ? ["output-row", "active"] : ["output-row"]}
          onClicked={() => setDefaultSink(sink.id)}
        >
          <box>
            <label
              cssClasses={["output-check"]}
              label={sink.isDefault ? "󰄬" : "󰄱"}
            />
            <label cssClasses={["output-name"]} label={sink.name} />
          </box>
        </button>
      ))}
    </box>
  )
}
