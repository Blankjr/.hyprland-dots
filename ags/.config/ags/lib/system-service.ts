import { createState } from "ags"
import { runShell } from "./shell"

const [currentTime, setCurrentTime] = createState("")
const [uptime, setUptime] = createState("")
const [cpuUsage, setCpuUsage] = createState(0)
const [ramUsage, setRamUsage] = createState(0)
const [diskUsage, setDiskUsage] = createState(0)

let timeInterval: ReturnType<typeof setInterval> | null = null
let resourceInterval: ReturnType<typeof setInterval> | null = null

let prevIdle = 0
let prevTotal = 0

function pollTime() {
  const now = new Date()
  const hh = String(now.getHours()).padStart(2, "0")
  const mm = String(now.getMinutes()).padStart(2, "0")
  setCurrentTime(`${hh}:${mm}`)
}

async function pollUptime() {
  const out = await runShell("cat /proc/uptime")
  const seconds = Math.floor(parseFloat(out.split(" ")[0]))
  const hours = Math.floor(seconds / 3600)
  const minutes = Math.floor((seconds % 3600) / 60)
  setUptime(`${hours}:${String(minutes).padStart(2, "0")}`)
}

async function pollCpu() {
  const out = await runShell("head -1 /proc/stat")
  const parts = out.trim().split(/\s+/).slice(1).map(Number)
  const idle = parts[3] + (parts[4] || 0) // idle + iowait
  const total = parts.reduce((a, b) => a + b, 0)

  if (prevTotal > 0) {
    const deltaTotal = total - prevTotal
    const deltaIdle = idle - prevIdle
    const usage = deltaTotal > 0 ? ((deltaTotal - deltaIdle) / deltaTotal) * 100 : 0
    setCpuUsage(Math.round(usage))
  }

  prevIdle = idle
  prevTotal = total
}

async function pollRam() {
  const out = await runShell("free | awk '/Mem:/ {printf \"%.0f\", $3/$2*100}'")
  const value = parseInt(out.trim())
  if (!isNaN(value)) setRamUsage(value)
}

async function pollDisk() {
  const out = await runShell("df / | awk 'NR==2 {print $5}' | tr -d '%'")
  const value = parseInt(out.trim())
  if (!isNaN(value)) setDiskUsage(value)
}

async function pollResources() {
  await Promise.all([pollUptime(), pollCpu(), pollRam(), pollDisk()])
}

export function startPolling() {
  pollTime()
  pollResources()
  if (!timeInterval) {
    timeInterval = setInterval(pollTime, 1000)
  }
  if (!resourceInterval) {
    resourceInterval = setInterval(() => pollResources(), 3000)
  }
}

export function stopPolling() {
  if (timeInterval) {
    clearInterval(timeInterval)
    timeInterval = null
  }
  if (resourceInterval) {
    clearInterval(resourceInterval)
    resourceInterval = null
  }
}

export function initSystemService() {
  // no-op at boot — polling starts when left panel opens
}

export { currentTime, uptime, cpuUsage, ramUsage, diskUsage }
