import { createMemo } from "ags"
import { Astal } from "ags/gtk4"
import app from "ags/gtk4/app"
import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib?version=2.0"
import Gtk from "gi://Gtk?version=4.0"
import {
  aiGenerating,
  aiModelDisplayName,
  aiModels,
  aiModelUsesQwenServer,
  aiModelUsesTestPrompt,
  aiSelectedModel,
  aiServiceDetail,
  aiServiceState,
  cancelAiResponse,
  refreshAiService,
  setAiModel,
  setAiServiceEnabled,
  streamAiResponse,
  type AiMessage,
} from "../../lib/ai-service"
import { refreshImageService } from "../../lib/image-service"
import ImageGenerationPanel from "./ImageGenerationPanel"

const INTRO = "This conversation stays in memory and is not saved."

let inputView: Gtk.TextView | null = null

export function focusAiInput(): void {
  GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
    inputView?.grab_focus()
    return GLib.SOURCE_REMOVE
  })
}

export default function AiChatWindow() {
  const messages: AiMessage[] = []
  let scrollSourceId = 0

  const transcriptBuffer = new Gtk.TextBuffer()
  const transcriptView = new Gtk.TextView({
    buffer: transcriptBuffer,
    editable: false,
    cursorVisible: false,
    wrapMode: Gtk.WrapMode.WORD_CHAR,
    leftMargin: 18,
    rightMargin: 18,
    topMargin: 16,
    bottomMargin: 16,
    hexpand: true,
    vexpand: true,
  })
  transcriptView.cssClasses = ["ai-transcript"]

  const inputBuffer = new Gtk.TextBuffer()
  inputView = new Gtk.TextView({
    buffer: inputBuffer,
    acceptsTab: false,
    wrapMode: Gtk.WrapMode.WORD_CHAR,
    leftMargin: 12,
    rightMargin: 12,
    topMargin: 10,
    bottomMargin: 10,
    hexpand: true,
  })
  inputView.cssClasses = ["ai-input"]

  const modelList = new Gtk.StringList()
  const modelDropdown = new Gtk.DropDown({
    model: modelList,
    hexpand: true,
  })
  modelDropdown.cssClasses = ["ai-model-dropdown"]
  modelDropdown.tooltipText = "Choose an Ollama model or Qwen3.6 TurboQuant"

  let syncingModelList = false

  function syncModelList(): void {
    const models = aiModels()
    syncingModelList = true
    modelList.splice(0, modelList.get_n_items(), models)
    const selectedIndex = models.indexOf(aiSelectedModel())
    modelDropdown.selected = selectedIndex >= 0
      ? selectedIndex
      : Gtk.INVALID_LIST_POSITION
    syncingModelList = false
  }

  modelDropdown.connect("notify::selected", () => {
    if (syncingModelList || modelDropdown.selected === Gtk.INVALID_LIST_POSITION) return

    const model = modelList.get_string(modelDropdown.selected)
    if (model && model !== aiSelectedModel() && setAiModel(model)) {
      clearConversation()
    }
  })

  const unsubscribeModels = aiModels.subscribe(syncModelList)
  syncModelList()

  function scheduleScrollToEnd(): void {
    if (scrollSourceId !== 0) return

    scrollSourceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
      scrollSourceId = 0
      const end = transcriptBuffer.get_end_iter()
      transcriptView.scroll_to_iter(end, 0, false, 0, 1)
      return GLib.SOURCE_REMOVE
    })
  }

  function setTranscript(text: string): void {
    transcriptBuffer.set_text(text, -1)
    scheduleScrollToEnd()
  }

  function appendTranscript(text: string): void {
    const end = transcriptBuffer.get_end_iter()
    transcriptBuffer.insert(end, text, -1)
    scheduleScrollToEnd()
  }

  function clearConversation(): void {
    if (aiGenerating()) return
    messages.splice(0, messages.length)
    setTranscript(INTRO)
    focusAiInput()
  }

  function readPrompt(): string {
    const start = inputBuffer.get_start_iter()
    const end = inputBuffer.get_end_iter()
    return inputBuffer.get_text(start, end, false).trim()
  }

  function sendPrompt(): void {
    const prompt = readPrompt()
    if (
      !prompt
      || aiServiceState() !== "on"
      || aiModels().length === 0
      || aiGenerating()
    ) return

    inputBuffer.set_text("", -1)
    const hasConversation = messages.length > 0
    messages.push({ role: "user", content: prompt })
    const requestMessages = messages.map((message) => ({ ...message }))
    const assistantIndex = messages.push({ role: "assistant", content: "" }) - 1

    if (!hasConversation) setTranscript("")
    appendTranscript(
      `${hasConversation ? "\n\n" : ""}You\n${prompt}\n\n${aiModelDisplayName()}\n`,
    )

    const started = streamAiResponse(
      requestMessages,
      (chunk) => {
        messages[assistantIndex].content += chunk
        appendTranscript(chunk)
      },
      (cancelled) => {
        if (cancelled) {
          const response = messages[assistantIndex]
          const marker = `${response.content ? "\n\n" : ""}[stopped]`
          response.content += marker
          appendTranscript(marker)
        }
        focusAiInput()
      },
      (message) => {
        const response = messages[assistantIndex]
        const error = `${response.content ? "\n\n" : ""}Error: ${message}`
        response.content += error
        appendTranscript(error)
        focusAiInput()
      },
    )

    if (!started) {
      const error = "Error: AI service is unavailable"
      messages[assistantIndex].content = error
      appendTranscript(error)
    }
  }

  setTranscript(INTRO)

  const inputKeyController = new Gtk.EventControllerKey()
  inputKeyController.connect(
    "key-pressed",
    (_controller, keyval: number, _keycode: number, state: Gdk.ModifierType) => {
      const isEnter = keyval === Gdk.KEY_Return || keyval === Gdk.KEY_KP_Enter
      const wantsNewline = Boolean(state & Gdk.ModifierType.SHIFT_MASK)

      if (isEnter && !wantsNewline) {
        sendPrompt()
        return true
      }
      return false
    },
  )
  inputView.add_controller(inputKeyController)

  const serviceEnabled = createMemo(() => aiServiceState() === "on")
  const serviceSwitchClasses = createMemo(() => [
    "ai-service-switch",
    serviceEnabled() ? "service-on" : "service-off",
  ])
  const serviceToggleEnabled = createMemo(
    () => aiServiceState() !== "starting" && aiServiceState() !== "stopping",
  )
  const canSend = createMemo(
    () => aiServiceState() === "on" && aiModels().length > 0 && !aiGenerating(),
  )
  const canChooseModel = createMemo(
    () => (
      aiServiceState() !== "starting"
      && aiServiceState() !== "stopping"
      && aiModels().length > 0
      && !aiGenerating()
    ),
  )

  const win = (
    <window
      visible={false}
      name="ai-chat"
      namespace="ai-chat"
      application={app}
      layer={Astal.Layer.OVERLAY}
      exclusivity={Astal.Exclusivity.NORMAL}
      keymode={Astal.Keymode.ON_DEMAND}
      onNotifyVisible={(self: { visible: boolean }) => {
        if (self.visible) {
          void refreshAiService()
          void refreshImageService()
          focusAiInput()
        }
      }}
    >
      <box cssClasses={["ai-workspace"]} spacing={18}>
        <box
          cssClasses={["ai-chat-window"]}
          orientation={Gtk.Orientation.VERTICAL}
          widthRequest={980}
          heightRequest={900}
        >
        <box cssClasses={["ai-header"]}>
          <box orientation={Gtk.Orientation.VERTICAL} hexpand>
            <label
              cssClasses={["ai-title"]}
              label="Local AI"
              halign={Gtk.Align.START}
            />
            <label
              cssClasses={["ai-service-detail"]}
              label={aiServiceDetail}
              halign={Gtk.Align.START}
            />
          </box>
          <label cssClasses={["ai-service-label"]} label="Service" />
          <switch
            cssClasses={serviceSwitchClasses}
            active={serviceEnabled}
            sensitive={serviceToggleEnabled}
            onStateSet={(_self: Gtk.Switch, enabled: boolean) => {
              void setAiServiceEnabled(enabled)
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

        <box
          cssClasses={["ai-model-row"]}
          orientation={Gtk.Orientation.VERTICAL}
        >
          <label
            cssClasses={["ai-section-label"]}
            label="MODEL"
            halign={Gtk.Align.START}
          />
          {modelDropdown}
          <label
            cssClasses={["ai-model-hint"]}
            label={createMemo(() => {
              if (aiServiceState() !== "on") {
                return aiModelUsesQwenServer(aiSelectedModel())
                  ? "TurboQuant Vulkan · 32K context · select, then enable Service"
                  : "Select a model, then enable Service"
              }
              if (aiModels().length === 0) {
                return "No models installed · use local-ai pull MODEL"
              }
              return aiModelUsesTestPrompt(aiSelectedModel())
                ? "Educational uncensored test preprompt enabled"
                : aiModelUsesQwenServer(aiSelectedModel())
                  ? "Qwen3.6 35B · TurboQuant Vulkan · 32K context"
                  : "Installed Ollama model"
            })}
            halign={Gtk.Align.START}
          />
        </box>

        <box cssClasses={["ai-output-section"]} orientation={Gtk.Orientation.VERTICAL}>
          <label
            cssClasses={["ai-section-label"]}
            label="CONVERSATION"
            halign={Gtk.Align.START}
          />
          <scrolledwindow
            cssClasses={["ai-transcript-scroll"]}
            heightRequest={540}
            hexpand
            vexpand
            propagateNaturalHeight={false}
            propagateNaturalWidth={false}
            overlayScrolling={false}
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
          >
            {transcriptView}
          </scrolledwindow>
        </box>

        <box cssClasses={["ai-composer"]} orientation={Gtk.Orientation.VERTICAL}>
          <label
            cssClasses={["ai-section-label"]}
            label="PROMPT"
            halign={Gtk.Align.START}
          />
          <scrolledwindow
            cssClasses={["ai-input-scroll"]}
            heightRequest={122}
            propagateNaturalHeight={false}
            propagateNaturalWidth={false}
            overlayScrolling={false}
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
          >
            {inputView}
          </scrolledwindow>
          <box cssClasses={["ai-actions"]}>
            <label
              cssClasses={["ai-input-hint"]}
              label="Enter to send · Shift+Enter for a new line"
              hexpand
              halign={Gtk.Align.START}
            />
            <button
              cssClasses={["ai-secondary-button"]}
              sensitive={canSend}
              onClicked={clearConversation}
            >
              <label label="New chat" />
            </button>
            <button
              cssClasses={["ai-secondary-button"]}
              sensitive={aiGenerating}
              onClicked={cancelAiResponse}
            >
              <label label="Stop" />
            </button>
            <button
              cssClasses={["ai-send-button"]}
              sensitive={canSend}
              onClicked={sendPrompt}
            >
              <label label="Send 󰒊" />
            </button>
          </box>
        </box>
        </box>
        <ImageGenerationPanel />
      </box>
    </window>
  ) as Gtk.Window

  modelDropdown.sensitive = canChooseModel()
  const unsubscribeModelSensitivity = canChooseModel.subscribe(() => {
    modelDropdown.sensitive = canChooseModel()
  })
  win.connect("destroy", () => {
    unsubscribeModels()
    unsubscribeModelSensitivity()
  })

  const windowKeyController = new Gtk.EventControllerKey()
  windowKeyController.connect("key-pressed", (_controller, keyval: number) => {
    if (keyval === Gdk.KEY_Escape) {
      win.visible = false
      return true
    }
    return false
  })
  win.add_controller(windowKeyController)

  return win
}
