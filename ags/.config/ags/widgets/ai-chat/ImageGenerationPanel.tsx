import { createMemo, createState } from "ags"
import app from "ags/gtk4/app"
import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import {
  cancelImageGeneration,
  copyGeneratedImage,
  generateImage,
  getImageOutputDirectory,
  imageGenerating,
  imageServiceDetail,
  imageServiceState,
  saveGeneratedImage,
  setImageOutputDirectory,
  setImageServiceEnabled,
} from "../../lib/image-service"

type ImageFormat = {
  id: "square" | "landscape" | "phone"
  label: string
  width: number
  height: number
}

const IMAGE_FORMATS: ImageFormat[] = [
  { id: "square", label: "Default / 1:1", width: 1024, height: 1024 },
  { id: "landscape", label: "Landscape / 16:9", width: 1024, height: 576 },
  { id: "phone", label: "Phone / 9:16", width: 576, height: 1024 },
]

function FormatButton({
  format,
  selected,
  sensitive,
  onSelected,
}: {
  format: ImageFormat
  selected: () => ImageFormat
  sensitive: () => boolean
  onSelected: (format: ImageFormat) => void
}) {
  const classes = createMemo(() => [
    "ai-format-button",
    selected().id === format.id ? "format-active" : "format-inactive",
  ])

  return (
    <button
      cssClasses={classes}
      sensitive={sensitive}
      tooltipText={`${format.width}×${format.height}`}
      onClicked={() => onSelected(format)}
    >
      <label label={format.label} />
    </button>
  )
}

function readableError(error: unknown): string {
  return String(error).replace(/^Error:\s*/, "").trim() || "Unknown error"
}

export default function ImageGenerationPanel() {
  const defaultOutput = GLib.build_filenamev([
    GLib.get_home_dir(),
    "Pictures",
    "AI Images",
  ])
  const [referencePath, setReferencePath] = createState<string | null>(null)
  const [resultPath, setResultPath] = createState<string | null>(null)
  const [imageFormat, setImageFormat] = createState<ImageFormat>(IMAGE_FORMATS[0])
  const [outputDirectory, setOutputDirectory] = createState(defaultOutput)
  const [message, setMessage] = createState(
    "Turn on the image service, then describe what you want to create.",
  )

  const promptBuffer = new Gtk.TextBuffer()
  const promptView = new Gtk.TextView({
    buffer: promptBuffer,
    acceptsTab: false,
    wrapMode: Gtk.WrapMode.WORD_CHAR,
    leftMargin: 12,
    rightMargin: 12,
    topMargin: 10,
    bottomMargin: 10,
    hexpand: true,
  })
  promptView.cssClasses = ["ai-input", "ai-image-prompt"]

  const picture = new Gtk.Picture({
    canShrink: true,
    contentFit: Gtk.ContentFit.CONTAIN,
    hexpand: true,
    vexpand: true,
  })
  picture.cssClasses = ["ai-generated-picture"]

  const placeholder = new Gtk.Label({
    label: "Your generated image will appear here",
    halign: Gtk.Align.CENTER,
    valign: Gtk.Align.CENTER,
    wrap: true,
  })
  placeholder.cssClasses = ["ai-image-placeholder"]

  const preview = new Gtk.Stack({
    heightRequest: 430,
    hexpand: true,
    vexpand: true,
    transitionType: Gtk.StackTransitionType.NONE,
  })
  preview.cssClasses = ["ai-image-preview"]
  preview.add_named(placeholder, "placeholder")
  preview.add_named(picture, "image")
  preview.set_visible_child_name("placeholder")

  function readPrompt(): string {
    const start = promptBuffer.get_start_iter()
    const end = promptBuffer.get_end_iter()
    return promptBuffer.get_text(start, end, false).trim()
  }

  function chooseReference(): void {
    const dialog = new Gtk.FileChooserNative({
      title: "Choose a reference image",
      action: Gtk.FileChooserAction.OPEN,
      acceptLabel: "Use image",
      cancelLabel: "Cancel",
    })
    const imageFilter = new Gtk.FileFilter()
    imageFilter.set_name("Images")
    imageFilter.add_mime_type("image/png")
    imageFilter.add_mime_type("image/jpeg")
    imageFilter.add_mime_type("image/webp")
    imageFilter.add_mime_type("image/bmp")
    dialog.add_filter(imageFilter)

    dialog.connect("response", (self, response: number) => {
      if (response === Gtk.ResponseType.ACCEPT) {
        const file = self.get_file()
        const path = file?.get_path()
        if (!path) {
          setMessage("The selected reference is not a local file.")
        } else if (!/\.(png|jpe?g|webp|bmp)$/i.test(path)) {
          setMessage("Choose a PNG, JPEG, WebP, or BMP reference image.")
        } else {
          setReferencePath(path)
          setMessage(`Reference ready · ${GLib.path_get_basename(path)}`)
        }
      }
      self.destroy()
    })
    dialog.show()
  }

  function chooseOutputDirectory(): void {
    const dialog = new Gtk.FileChooserNative({
      title: "Always save generated images here",
      action: Gtk.FileChooserAction.SELECT_FOLDER,
      acceptLabel: "Use this folder",
      cancelLabel: "Cancel",
    })

    dialog.connect("response", (self, response: number) => {
      if (response === Gtk.ResponseType.ACCEPT) {
        const folder = self.get_file()
        const path = folder?.get_path()
        if (!path) {
          setMessage("The selected folder is not local.")
        } else {
          void setImageOutputDirectory(path)
            .then((savedPath) => {
              setOutputDirectory(savedPath)
              setMessage(`Save folder · ${savedPath}`)
            })
            .catch((error) => setMessage(readableError(error)))
        }
      }
      self.destroy()
    })
    dialog.show()
  }

  function runGeneration(): void {
    const prompt = readPrompt()
    if (!prompt || imageServiceState() !== "on" || imageGenerating()) return
    const format = imageFormat()

    setMessage(referencePath()
      ? `Generating ${format.width}×${format.height} from prompt and reference…`
      : `Generating ${format.width}×${format.height} from prompt…`)

    const started = generateImage(
      prompt,
      referencePath(),
      format.width,
      format.height,
      (path) => {
        setResultPath(path)
        picture.set_filename(path)
        preview.set_visible_child_name("image")
        setMessage(`Finished · ${format.width}×${format.height} PNG is ready`)
      },
      (cancelled) => {
        if (cancelled) setMessage("Generation stopped.")
      },
      (error) => setMessage(`Generation failed · ${error}`),
    )

    if (!started) setMessage("Image service is unavailable or already busy.")
  }

  const promptKeyController = new Gtk.EventControllerKey()
  promptKeyController.connect(
    "key-pressed",
    (_controller, keyval: number, _keycode: number, state: Gdk.ModifierType) => {
      const isEnter = keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter
      const wantsNewline = Boolean(state & Gdk.ModifierType.SHIFT_MASK)

      if (isEnter && !wantsNewline) {
        runGeneration()
        return true
      }
      return false
    },
  )
  promptView.add_controller(promptKeyController)

  void getImageOutputDirectory()
    .then(setOutputDirectory)
    .catch(() => {})

  const serviceEnabled = createMemo(() => imageServiceState() === "on")
  const serviceSwitchClasses = createMemo(() => [
    "ai-service-switch",
    serviceEnabled() ? "service-on" : "service-off",
  ])
  const serviceToggleEnabled = createMemo(
    () => imageServiceState() !== "starting" && imageServiceState() !== "stopping",
  )
  const canGenerate = createMemo(
    () => imageServiceState() === "on" && !imageGenerating(),
  )
  const canChooseReference = createMemo(() => !imageGenerating())
  const hasResult = createMemo(() => Boolean(resultPath()) && !imageGenerating())
  const hasReference = createMemo(() => Boolean(referencePath()))
  const referenceName = createMemo(
    () => referencePath() ? GLib.path_get_basename(referencePath()!) : "No reference selected",
  )

  return (
    <box
      cssClasses={["ai-chat-window", "ai-image-window"]}
      orientation={Gtk.Orientation.VERTICAL}
      widthRequest={980}
      heightRequest={900}
    >
      <box cssClasses={["ai-header"]}>
        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
          <label
            cssClasses={["ai-title"]}
            label="Local Image"
            halign={Gtk.Align.START}
          />
          <label
            cssClasses={["ai-service-detail"]}
            label={imageServiceDetail}
            halign={Gtk.Align.START}
          />
        </box>
        <label cssClasses={["ai-service-label"]} label="Service" />
        <switch
          cssClasses={serviceSwitchClasses}
          active={serviceEnabled}
          sensitive={serviceToggleEnabled}
          onStateSet={(_self: Gtk.Switch, enabled: boolean) => {
            void setImageServiceEnabled(enabled)
            return true
          }}
        />
        <button
          cssClasses={["ai-close-button"]}
          tooltipText="Close"
          onClicked={() => {
            app.get_window("ai-chat")!.visible = false
          }}
        >
          <label label="󰅖" />
        </button>
      </box>

      <label
        cssClasses={["ai-section-label"]}
        label="IMAGE"
        halign={Gtk.Align.START}
      />
      {preview}

      <box cssClasses={["ai-image-result-row"]}>
        <label
          cssClasses={["ai-image-message"]}
          label={message}
          ellipsize={3}
          hexpand
          halign={Gtk.Align.START}
        />
        <button
          cssClasses={["ai-secondary-button"]}
          sensitive={hasResult}
          tooltipText="Copy PNG to clipboard"
          onClicked={() => {
            const path = resultPath()
            if (!path) return
            void copyGeneratedImage(path)
              .then(() => setMessage("Image copied to clipboard."))
              .catch((error) => setMessage(readableError(error)))
          }}
        >
          <label label="Copy" />
        </button>
        <button
          cssClasses={["ai-save-button"]}
          sensitive={hasResult}
          tooltipText={outputDirectory}
          onClicked={() => {
            const path = resultPath()
            if (!path) return
            void saveGeneratedImage(path, outputDirectory())
              .then((savedPath) => setMessage(`Saved · ${savedPath}`))
              .catch((error) => setMessage(readableError(error)))
          }}
        >
          <label label="Download to folder" />
        </button>
        <button
          cssClasses={["ai-save-location-button"]}
          tooltipText="Choose the folder always used by Save"
          onClicked={chooseOutputDirectory}
        >
          <label label="▾" />
        </button>
      </box>

      <box cssClasses={["ai-image-composer"]} orientation={Gtk.Orientation.VERTICAL}>
        <label
          cssClasses={["ai-section-label"]}
          label="PROMPT"
          halign={Gtk.Align.START}
        />
        <scrolledwindow
          cssClasses={["ai-input-scroll"]}
          heightRequest={104}
          propagateNaturalHeight={false}
          propagateNaturalWidth={false}
          overlayScrolling={false}
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
        >
          {promptView}
        </scrolledwindow>

        <box cssClasses={["ai-format-row"]}>
          <label
            cssClasses={["ai-format-label"]}
            label="FORMAT"
            halign={Gtk.Align.START}
          />
          {IMAGE_FORMATS.map((format) => (
            <FormatButton
              format={format}
              selected={imageFormat}
              sensitive={canChooseReference}
              onSelected={setImageFormat}
            />
          ))}
          <label
            cssClasses={["ai-format-size"]}
            label={createMemo(() => `${imageFormat().width}×${imageFormat().height}`)}
            halign={Gtk.Align.END}
            hexpand
          />
        </box>

        <box cssClasses={["ai-reference-row"]}>
          <button
            cssClasses={["ai-secondary-button", "ai-reference-button"]}
            sensitive={canChooseReference}
            onClicked={chooseReference}
          >
            <label label="Upload reference" />
          </button>
          <label
            cssClasses={["ai-reference-name"]}
            label={referenceName}
            ellipsize={3}
            hexpand
            halign={Gtk.Align.START}
          />
          <button
            cssClasses={["ai-reference-clear"]}
            visible={hasReference}
            sensitive={canChooseReference}
            tooltipText="Remove reference"
            onClicked={() => {
              setReferencePath(null)
              setMessage("Reference image removed.")
            }}
          >
            <label label="󰅖" />
          </button>
          <button
            cssClasses={["ai-secondary-button"]}
            sensitive={imageGenerating}
            onClicked={cancelImageGeneration}
          >
            <label label="Stop" />
          </button>
          <button
            cssClasses={["ai-send-button"]}
            sensitive={canGenerate}
            onClicked={runGeneration}
          >
            <label label="Generate 󰒊" />
          </button>
        </box>
      </box>
    </box>
  )
}
