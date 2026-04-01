export type SubmenuId = "main-menu" | "sound-menu" | "display-menu"

export interface AudioOutput {
  id: number
  name: string
  volume: number
  muted: boolean
  isDefault: boolean
}

export interface AudioState {
  sinks: AudioOutput[]
  defaultSinkId: number
  sinkVolume: number
  sinkMuted: boolean
  sourceVolume: number
  sourceMuted: boolean
}

export interface DisplayState {
  brightness: number
  brightnessAvailable: boolean
  blueLight: boolean
  blueLightAvailable: boolean
  darkMode: boolean
}

export interface CategoryTile {
  id: SubmenuId
  icon: string
  label: string
  disabled: boolean
}
