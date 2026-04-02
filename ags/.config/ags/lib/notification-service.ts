import { createState } from "ags"
import { interval } from "ags/time"
import { runShell } from "./shell"

const [dndEnabled, setDndEnabled] = createState(false)

async function pollDnd() {
  const out = await runShell("makoctl mode")
  setDndEnabled(out.includes("hide"))
}

export async function toggleDnd() {
  if (dndEnabled()) {
    await runShell("makoctl mode -r hide")
  } else {
    await runShell("makoctl mode -s hide")
  }
  await pollDnd()
}

export async function initNotificationService() {
  await pollDnd()
  interval(2000, () => pollDnd())
}

export { dndEnabled }
