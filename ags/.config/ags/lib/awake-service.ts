import { createState } from "ags"
import { execAsync } from "ags/process"

const [awakeEnabled, setAwakeEnabled] = createState(false)

async function killAwakeProcess() {
  try {
    await execAsync(["pkill", "-f", "systemd-inhibit.*AGS Awake"])
  } catch {
    // pkill exits non-zero when no process matches — expected
  }
}

export async function initAwakeService() {
  await killAwakeProcess()
}

export async function toggleAwake() {
  if (awakeEnabled()) {
    await killAwakeProcess()
    setAwakeEnabled(false)
  } else {
    execAsync(["bash", "-c",
      'systemd-inhibit --what=idle:sleep:handle-suspend-key --who="AGS Awake" --why="User requested stay awake" --mode=block sleep infinity &',
    ]).catch(() => {})
    setAwakeEnabled(true)
  }
}

export { awakeEnabled }
