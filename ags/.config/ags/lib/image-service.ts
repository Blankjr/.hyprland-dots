import { createState } from "ags"
import { execAsync, subprocess, Process } from "ags/process"
import GLib from "gi://GLib?version=2.0"

export type ImageServiceState = "off" | "starting" | "on" | "stopping" | "error"

const API_URL = "http://127.0.0.1:1234"
const LOCAL_IMAGE_AI = `${GLib.get_home_dir()}/.dots/localscripts/local-image-ai`

const [imageServiceState, setImageServiceState] = createState<ImageServiceState>("off")
const [imageServiceDetail, setImageServiceDetail] = createState("Service is off")
const [imageGenerating, setImageGenerating] = createState(false)

let activeProcess: Process | null = null
let cancelRequested = false
let statusCheckId = 0

function errorMessage(error: unknown): string {
  return String(error).replace(/^Error:\s*/, "").trim() || "Unknown error"
}

export async function refreshImageService(): Promise<void> {
  if (imageServiceState() === "starting" || imageServiceState() === "stopping") return

  const checkId = ++statusCheckId

  try {
    await execAsync([
      "curl",
      "--fail",
      "--silent",
      "--max-time",
      "1",
      `${API_URL}/sdcpp/v1/capabilities`,
    ])
    if (checkId !== statusCheckId) return
    setImageServiceState("on")
    setImageServiceDetail(imageGenerating() ? "Generating…" : "Ready · FLUX.2 Klein · Vulkan")
  } catch {
    if (checkId !== statusCheckId) return
    setImageServiceState("off")
    setImageServiceDetail("Service is off")
  }
}

export async function startImageService(): Promise<boolean> {
  if (imageServiceState() === "on") return true
  if (imageServiceState() === "starting" || imageServiceState() === "stopping") return false

  statusCheckId += 1
  setImageServiceState("starting")
  setImageServiceDetail("Loading FLUX.2 Klein…")

  try {
    await execAsync([LOCAL_IMAGE_AI, "start"])
    setImageServiceState("on")
    setImageServiceDetail("Ready · FLUX.2 Klein · Vulkan")
    return true
  } catch (error) {
    setImageServiceState("error")
    setImageServiceDetail(errorMessage(error))
    return false
  }
}

export async function stopImageService(): Promise<boolean> {
  if (imageServiceState() === "off") return true
  if (imageServiceState() === "starting" || imageServiceState() === "stopping") return false

  statusCheckId += 1
  cancelRequested = imageGenerating()
  setImageServiceState("stopping")
  setImageServiceDetail("Stopping image service…")

  try {
    await execAsync([LOCAL_IMAGE_AI, "stop"])
    setImageServiceState("off")
    setImageServiceDetail("Service is off")
    return true
  } catch (error) {
    const message = errorMessage(error)
    setImageServiceState("error")
    await refreshImageService()
    setImageServiceDetail(message)
    return false
  }
}

export async function setImageServiceEnabled(enabled: boolean): Promise<boolean> {
  return enabled ? startImageService() : stopImageService()
}

export function cancelImageGeneration(): void {
  if (!activeProcess) return

  cancelRequested = true
  setImageServiceDetail("Stopping generation…")
  void execAsync([LOCAL_IMAGE_AI, "cancel"]).catch((error) => {
    setImageServiceDetail(errorMessage(error))
  })
}

export function generateImage(
  prompt: string,
  referencePath: string | null,
  width: number,
  height: number,
  onResult: (path: string) => void,
  onFinished: (cancelled: boolean) => void,
  onError: (message: string) => void,
): boolean {
  if (imageServiceState() !== "on" || activeProcess) return false

  cancelRequested = false
  let resultPath = ""
  let lastError = ""
  const command = [
    LOCAL_IMAGE_AI,
    "generate",
    "--size",
    `${width}x${height}`,
    prompt,
    ...(referencePath ? [referencePath] : []),
  ]

  setImageGenerating(true)
  setImageServiceDetail(referencePath ? "Preparing reference image…" : "Queuing image…")

  let proc: Process
  proc = subprocess(
    command,
    (line) => {
      if (line.startsWith("STATUS\t")) {
        setImageServiceDetail(line.slice("STATUS\t".length))
      } else if (line.startsWith("RESULT\t")) {
        resultPath = line.slice("RESULT\t".length)
      }
    },
    (line) => {
      lastError = line
    },
  )

  activeProcess = proc

  proc.connect("exit", (_self, code: number, signaled: boolean) => {
    if (activeProcess !== proc) return

    activeProcess = null
    setImageGenerating(false)

    if (imageServiceState() === "on") {
      setImageServiceDetail("Ready · FLUX.2 Klein · Vulkan")
    }

    if (cancelRequested || signaled || code === 130) {
      cancelRequested = false
      onFinished(true)
    } else if (code !== 0 || lastError) {
      onError(lastError || `Generation exited with status ${code}`)
    } else if (!resultPath) {
      onError("Image service returned no output")
    } else {
      onResult(resultPath)
      onFinished(false)
    }
  })

  return true
}

export async function copyGeneratedImage(path: string): Promise<void> {
  await execAsync([LOCAL_IMAGE_AI, "copy", path])
}

export async function getImageOutputDirectory(): Promise<string> {
  return (await execAsync([LOCAL_IMAGE_AI, "output-dir"])).trim()
}

export async function setImageOutputDirectory(path: string): Promise<string> {
  return (await execAsync([LOCAL_IMAGE_AI, "set-output-dir", path])).trim()
}

export async function saveGeneratedImage(path: string, directory: string): Promise<string> {
  return (await execAsync([LOCAL_IMAGE_AI, "save", path, directory])).trim()
}

export {
  imageServiceState,
  imageServiceDetail,
  imageGenerating,
}
