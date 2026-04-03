import Gtk from "gi://Gtk?version=4.0"

const MONTHS = [
  "january", "february", "march", "april", "may", "june",
  "july", "august", "september", "october", "november", "december",
]
const DAYS = ["mo", "tu", "we", "th", "fr", "sa", "su"]

export default function Calendar() {
  const now = new Date()
  let viewMonth = now.getMonth()
  let viewYear = now.getFullYear()

  const monthLabel = new Gtk.Label({ label: MONTHS[viewMonth] })
  monthLabel.cssClasses = ["cal-nav-label"]

  const yearLabel = new Gtk.Label({ label: String(viewYear) })
  yearLabel.cssClasses = ["cal-nav-label"]

  // Pre-create 42 day buttons (6 rows × 7 cols)
  const dayCells: Gtk.Label[] = []
  const dayRows: Gtk.Box[] = []

  for (let row = 0; row < 6; row++) {
    const rowBox = new Gtk.Box({ orientation: Gtk.Orientation.HORIZONTAL, homogeneous: true })
    rowBox.cssClasses = ["cal-row"]
    for (let col = 0; col < 7; col++) {
      const label = new Gtk.Label({ label: "" })
      label.cssClasses = ["cal-day"]
      dayCells.push(label)
      rowBox.append(label)
    }
    dayRows.push(rowBox)
  }

  function rebuild() {
    monthLabel.label = MONTHS[viewMonth]
    yearLabel.label = String(viewYear)

    const today = new Date()
    const firstDay = new Date(viewYear, viewMonth, 1)
    // Monday=0 offset
    let startDow = firstDay.getDay() - 1
    if (startDow < 0) startDow = 6

    const daysInMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
    const daysInPrev = new Date(viewYear, viewMonth, 0).getDate()

    for (let i = 0; i < 42; i++) {
      const cell = dayCells[i]
      let day: number
      let isOther = false

      if (i < startDow) {
        day = daysInPrev - startDow + i + 1
        isOther = true
      } else if (i - startDow >= daysInMonth) {
        day = i - startDow - daysInMonth + 1
        isOther = true
      } else {
        day = i - startDow + 1
      }

      cell.label = String(day)

      const isToday =
        !isOther &&
        day === today.getDate() &&
        viewMonth === today.getMonth() &&
        viewYear === today.getFullYear()

      if (isToday) {
        cell.cssClasses = ["cal-day", "cal-today"]
      } else if (isOther) {
        cell.cssClasses = ["cal-day", "cal-day-other"]
      } else {
        cell.cssClasses = ["cal-day"]
      }
    }
  }

  function changeMonth(delta: number) {
    viewMonth += delta
    if (viewMonth > 11) { viewMonth = 0; viewYear++ }
    if (viewMonth < 0) { viewMonth = 11; viewYear-- }
    rebuild()
  }

  function changeYear(delta: number) {
    viewYear += delta
    rebuild()
  }

  rebuild()

  return (
    <box cssClasses={["calendar"]} orientation={1}>
      <box cssClasses={["cal-nav"]}>
        <box cssClasses={["cal-nav-group"]}>
          <button cssClasses={["cal-nav-btn"]} onClicked={() => changeMonth(-1)}>
            <label label="󰁍" />
          </button>
          {monthLabel}
          <button cssClasses={["cal-nav-btn"]} onClicked={() => changeMonth(1)}>
            <label label="󰁔" />
          </button>
        </box>
        <box hexpand />
        <box cssClasses={["cal-nav-group"]}>
          <button cssClasses={["cal-nav-btn"]} onClicked={() => changeYear(-1)}>
            <label label="󰁍" />
          </button>
          {yearLabel}
          <button cssClasses={["cal-nav-btn"]} onClicked={() => changeYear(1)}>
            <label label="󰁔" />
          </button>
        </box>
      </box>
      <box cssClasses={["cal-header"]} homogeneous>
        {DAYS.map((d) => (
          <label cssClasses={["cal-header-day"]} label={d} />
        ))}
      </box>
      {dayRows.map((row) => row)}
    </box>
  )
}
