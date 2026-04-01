export default function BackButton({
  onBack,
  label,
}: {
  onBack: () => void
  label: string
}) {
  return (
    <button cssClasses={["back-button"]} onClicked={onBack}>
      <box>
        <label cssClasses={["back-icon"]} label="󰁍" />
        <label label={label} />
      </box>
    </button>
  )
}
