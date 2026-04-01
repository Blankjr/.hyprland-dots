import { createState } from "ags"
import { interval } from "ags/time"
import { run, runShell } from "./shell"
import type { AudioOutput } from "./types"

const [sinks, setSinks] = createState<AudioOutput[]>([])
const [defaultSinkId, setDefaultSinkId] = createState(-1)
const [sinkVolume, setSinkVolume] = createState(0)
const [sinkMuted, setSinkMuted] = createState(false)
const [sourceVolume, setSourceVolume] = createState(0)
const [sourceMuted, setSourceMuted] = createState(false)

function parseVolume(output: string): { volume: number; muted: boolean } {
  const match = output.match(/Volume:\s+([\d.]+)(\s+\[MUTED\])?/)
  if (!match) return { volume: 0, muted: false }
  return {
    volume: parseFloat(match[1]),
    muted: !!match[2],
  }
}

function parseSinks(output: string): AudioOutput[] {
  const results: AudioOutput[] = []
  const lines = output.split("\n")

  let inSinks = false
  for (const line of lines) {
    if (line.includes("Audio/Sink")) inSinks = true
    if (inSinks && line.trim() === "") break

    if (!inSinks) continue

    const match = line.match(
      /\s+(\*)?\s*(\d+)\.\s+(.+?)\s+\[vol:\s+([\d.]+)(\s+MUTED)?\]/,
    )
    if (match) {
      results.push({
        id: parseInt(match[2]),
        name: match[3].trim(),
        volume: parseFloat(match[4]),
        muted: !!match[5],
        isDefault: match[1] === "*",
      })
    }
  }

  return results
}

async function poll() {
  const [statusOut, sinkVol, srcVol] = await Promise.all([
    runShell("wpctl status"),
    run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]),
    run(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]),
  ])

  const parsed = parseSinks(statusOut)
  setSinks(parsed)

  const active = parsed.find((s) => s.isDefault)
  if (active) setDefaultSinkId(active.id)

  const sink = parseVolume(sinkVol)
  setSinkVolume(sink.volume)
  setSinkMuted(sink.muted)

  const source = parseVolume(srcVol)
  setSourceVolume(source.volume)
  setSourceMuted(source.muted)
}

export async function setVolume(value: number) {
  await run([
    "wpctl",
    "set-volume",
    "-l",
    "1",
    "@DEFAULT_AUDIO_SINK@",
    value.toFixed(2),
  ])
  await poll()
}

export async function toggleSinkMute() {
  await run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
  await poll()
}

export async function toggleSourceMute() {
  await run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
  await poll()
}

export async function setDefaultSink(id: number) {
  await run(["wpctl", "set-default", id.toString()])
  await poll()
}

export function initAudioService() {
  poll()
  interval(2000, () => poll())
}

export {
  sinks,
  defaultSinkId,
  sinkVolume,
  sinkMuted,
  sourceVolume,
  sourceMuted,
}
