import { createState } from "ags"
import { interval } from "ags/time"
import { run, runShell, checkAvailable } from "./shell"

const [brightness, setBrightnessState] = createState(100)
const [brightnessAvailable, setBrightnessAvailable] = createState(false)
const [blueLight, setBlueLightState] = createState(false)
const [blueLightAvailable, setBlueLightAvailable] = createState(false)
const [darkMode, setDarkModeState] = createState(false)

let brightnessTimeout: ReturnType<typeof setTimeout> | null = null

function parseBrightness(output: string): number {
  // ddcutil getvcp 10 --brief output: "VCP 10 C 75 100"
  const match = output.match(/VCP\s+10\s+C\s+(\d+)\s+(\d+)/)
  if (!match) return -1
  const current = parseInt(match[1])
  const max = parseInt(match[2])
  return Math.round((current / max) * 100)
}

async function pollBrightness() {
  if (!brightnessAvailable()) return
  const out = await run(["ddcutil", "getvcp", "10", "--brief"])
  const value = parseBrightness(out)
  if (value >= 0) setBrightnessState(value)
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
  await Promise.all([pollBrightness(), pollBlueLight()])
}

export function setBrightness(value: number) {
  // Update UI immediately
  setBrightnessState(value)

  // Debounce the actual ddcutil call (it's slow ~1-2s)
  if (brightnessTimeout) clearTimeout(brightnessTimeout)
  brightnessTimeout = setTimeout(async () => {
    await run(["ddcutil", "setvcp", "10", value.toString()])
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

  await Promise.all([pollBrightness(), pollBlueLight(), pollDarkMode()])

  interval(5000, () => poll())
}

export {
  brightness,
  brightnessAvailable,
  blueLight,
  blueLightAvailable,
  darkMode,
}
