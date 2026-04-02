import { createState } from "ags"
import { run, runShell, checkAvailable } from "./shell"

const [brightness, setBrightnessState] = createState(100)
const [brightnessAvailable, setBrightnessAvailable] = createState(false)
const [blueLight, setBlueLightState] = createState(false)
const [blueLightAvailable, setBlueLightAvailable] = createState(false)
const [darkMode, setDarkModeState] = createState(false)

let brightnessTimeout: ReturnType<typeof setTimeout> | null = null
let pollInterval: ReturnType<typeof setInterval> | null = null
let displayBuses: string[] = []

function parseBrightness(output: string): number {
  const match = output.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/)
  if (!match) return -1
  const current = parseInt(match[1])
  const max = parseInt(match[2])
  return Math.round((current / max) * 100)
}

async function detectDisplays() {
  const out = await runShell("ddcutil detect --brief 2>/dev/null | grep 'I2C bus:' | awk '{print $3}' | sed 's|/dev/i2c-||'")
  displayBuses = out.trim().split("\n").filter(b => b.length > 0)
}

async function pollBrightness() {
  if (!brightnessAvailable() || displayBuses.length === 0) return
  const out = await run(["ddcutil", "getvcp", "10", "--brief", "--bus", displayBuses[0]])
  const value = parseBrightness(out)
  if (value >= 0) {
    setBrightnessState(value)
  }
}

async function pollBlueLight() {
  if (!blueLightAvailable()) return
  const out = await runShell("hyprshade current")
  setBlueLightState(out.trim().length > 0)
}

async function pollDarkMode() {
  const out = await runShell(
    "gsettings get org.gnome.desktop.interface color-scheme",
  )
  setDarkModeState(out.includes("prefer-dark"))
}

async function poll() {
  await Promise.all([pollBrightness(), pollBlueLight(), pollDarkMode()])
}

export function startPolling() {
  poll()
  if (!pollInterval) {
    pollInterval = setInterval(() => poll(), 5000)
  }
}

export function stopPolling() {
  if (pollInterval) {
    clearInterval(pollInterval)
    pollInterval = null
  }
}

export function setBrightness(value: number) {
  setBrightnessState(value)

  if (brightnessTimeout) clearTimeout(brightnessTimeout)
  brightnessTimeout = setTimeout(async () => {
    await Promise.all(
      displayBuses.map(bus =>
        run(["ddcutil", "setvcp", "10", value.toString(), "--bus", bus])
      ),
    )
  }, 300)
}

export async function toggleBlueLight() {
  if (!blueLightAvailable()) return

  if (blueLight()) {
    await runShell("hyprshade off")
  } else {
    await runShell("hyprshade on blue-light-filter")
  }
  await pollBlueLight()
}

export async function toggleDarkMode() {
  const newDark = !darkMode()
  const scheme = newDark ? "prefer-dark" : "prefer-light"
  await runShell(
    `gsettings set org.gnome.desktop.interface color-scheme '${scheme}'`,
  )
  setDarkModeState(newDark)
}

export async function initDisplayService() {
  const [hasDdcutil, hasHyprshade] = await Promise.all([
    checkAvailable("ddcutil"),
    checkAvailable("hyprshade"),
  ])

  setBrightnessAvailable(hasDdcutil)
  setBlueLightAvailable(hasHyprshade)

  if (hasDdcutil) await detectDisplays()
}

export {
  brightness,
  brightnessAvailable,
  blueLight,
  blueLightAvailable,
  darkMode,
}
