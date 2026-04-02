import { createMemo } from "ags"

export default function SegmentToggle({
  leftLabel,
  rightLabel,
  active,
  onToggled,
}: {
  leftLabel: string
  rightLabel: string
  active: () => boolean
  onToggled: () => void
}) {
  const leftClasses = createMemo(
    () => active() ? ["segment-btn"] : ["segment-btn", "segment-active"],
    { equals: () => false },
  )

  const rightClasses = createMemo(
    () => active() ? ["segment-btn", "segment-active"] : ["segment-btn"],
    { equals: () => false },
  )

  return (
    <box cssClasses={["segment-toggle"]} homogeneous>
      <button cssClasses={leftClasses} onClicked={() => { if (active()) onToggled() }}>
        <label label={leftLabel} />
      </button>
      <button cssClasses={rightClasses} onClicked={() => { if (!active()) onToggled() }}>
        <label label={rightLabel} />
      </button>
    </box>
  )
}
