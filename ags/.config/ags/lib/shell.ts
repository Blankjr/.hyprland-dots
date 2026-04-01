import { execAsync } from "ags/process"

export async function run(cmd: string[]): Promise<string> {
  try {
    return await execAsync(cmd)
  } catch (err) {
    console.error(`command failed: ${cmd.join(" ")}`, err)
    return ""
  }
}

export async function runShell(cmd: string): Promise<string> {
  return run(["bash", "-c", cmd])
}

export async function checkAvailable(binary: string): Promise<boolean> {
  const result = await run(["which", binary])
  return result.trim().length > 0
}
