# dotfiles

Managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level directory is a stow package.

## Packages

| Package | Target | Contents |
|---------|--------|----------|
| `hypr` | `~/.config/hypr/` | Hyprland compositor config |
| `mako` | `~/.config/mako/` | Notification daemon |
| `rofi` | `~/.config/rofi/` | App launcher |
| `waybar` | `~/.config/waybar/` | Status bar + scripts |
| `nvim` | `~/.config/nvim/` | Neovim config |
| `zed` | `~/.config/zed/` | Zed editor (settings + keymap; Claude agent via ACP) |
| `qt6ct` | `~/.config/qt6ct/` | Qt6 dark theme (Fusion + darker palette) |
| `mime` | `~/.config/` | Default application associations |
| `scripts` | `~/.config/menu-scripts/` | Rofi script runner (Super+D) |
| `ags` | `~/.config/ags/` | AGS sidebar (display, sound, menus) |
| `secrets` | `~/.config/secrets/` | Env files with tokens (real `.env` is gitignored) |
| `sddm` | — | SDDM login theme (manual install, see below) |

## Usage

```bash
cd ~/.dots

# Link a package
stow <package>

# Unlink a package
stow -D <package>

# Re-link (unlink + link) after restructuring
stow -R <package>
```

### Sudo Password Feedback

To show `*` characters while entering a sudo password and allow up to five
attempts, open a dedicated sudoers fragment:

```bash
sudo visudo -f /etc/sudoers.d/10-password-feedback
```

Add this line, then save and exit:

```sudoers
Defaults pwfeedback, passwd_tries=5
```

Validate the complete sudoers configuration and test with a fresh prompt:

```bash
sudo visudo -c
sudo -k
sudo true
```

### AGS Display Menu

The brightness control uses `ddcutil` which requires the `i2c-dev` kernel module. To load it permanently:

```bash
sudo modprobe i2c-dev
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf
```

Optional dependencies (features are hidden automatically if not installed):
- `ddcutil` — external monitor brightness via DDC/CI
- `hyprshade` — blue light filter

### Hyprland Plugin: split-monitor-workspaces

Provides awesomewm-style per-monitor workspaces (each monitor gets its own 1–10). Hyprland loads the package directly from Lua; its configuration is in `hypr/.config/hypr/lua/workspaces.lua`.

After cloning these dotfiles, initialize the pinned package submodule:

```bash
git submodule update --init --recursive
```

The old HyprPM C++ plugin is no longer loaded. If it was previously installed, it can be disabled after restarting into the Lua configuration:

```bash
hyprpm disable split-monitor-workspaces
```

When Hyprland moves to a new minor release, update the submodule to the package tag matching that Hyprland release. If `monitor_priority` references connector names that no longer exist (e.g. DP-3/DP-2 renumbered after a driver change), update the list — first entry gets workspaces 1–10, second gets 11–20.

### Local Scripts

`~/.dots/localscripts/` is added to `$PATH` in `config.fish`, `.zshrc`, and `.bashrc` directly (no stow). Drop any executable in there and it's instantly callable from fish, zsh, and bash — no relink step.

```bash
chmod +x ~/.dots/localscripts/<new-script>
```

To serve the current folder on localhost and print links to every HTML page:

```bash
serve-html
serve-html --open
serve-html ./some-folder --port 8080
```

### Local AI

The `local-ai` helper runs [Ollama](https://ollama.com/) on demand with its
Vulkan backend. It binds only to `127.0.0.1:11434`; it is not enabled as a
system service and does not start at login.

One-time setup on CachyOS:

```bash
sudo pacman -S --needed ollama ollama-vulkan
local-ai start
local-ai pull qwen3.5:9b-q4_K_M
local-ai pull dolphin3:8b-llama3.1-q8_0
local-ai chat
```

The Qwen model is about 6.6 GB and the higher-precision Dolphin 3 model is
about 8.5 GB. Models remain in Ollama's user-local model store between runs.
Use `/bye` or Ctrl+D to leave a terminal chat; the server keeps running until
explicitly stopped:

```bash
local-ai status
local-ai logs
local-ai logs -f
local-ai stop
```

For read-only analysis of local text, source files, folders, and PDFs:

```bash
local-ai summarize README.md
local-ai summarize docs/ src/
local-ai ask "Which TODOs are still actionable?" .
local-ai ask --model qwen3.5:2b-q4_K_M \
  "How do these configurations differ?" config-a.toml config-b.toml
```

These commands start the managed Ollama service automatically when necessary
and use `qwen3.5:9b-q4_K_M` by default. Set `LOCAL_AI_TASK_MODEL` or pass
`--model` to choose another installed model. The model unloads five minutes
after the last request; the lightweight Ollama server remains available until
`local-ai stop`.

Folder traversal includes hidden files, honors ignore rules, and skips `.git`,
directory symlinks, binaries, unreadable files, and likely credential/private
key files. The commands use Python 3 and ripgrep; PDFs additionally require
Poppler's `pdftotext`. Large inputs are summarized in multiple passes. Progress
and omission warnings go to stderr, while the final Markdown answer goes to
stdout and can be redirected to a file.

`Super+A` opens a centered two-pane local AI workspace: model-selectable chat
on the left and FLUX.2 Klein image generation on the right. The model dropdown
lists models installed in Ollama plus the Qwen3.6 TurboQuant backend. Selecting
a Dolphin model enables its
uncensored educational-test system preprompt and starts a new conversation.
The services have independent switches and remain off until enabled. Switching
either service off terminates its backend and releases its VRAM. While Ollama
remains enabled, the active chat model unloads after two minutes without a
request.

The image backend is the Vulkan build of `stable-diffusion.cpp`. Its server and
model are stored outside the dotfiles at
`~/.local/share/local-image-ai/{bin,models}` and bind only to
`127.0.0.1:1234`. `local-image-ai` provides terminal controls:

```bash
local-image-ai start
local-image-ai status
local-image-ai stop
```

The image pane generates PNG files from text or an optional reference image
using FLUX.2 Klein's native image-editing input. Its format presets are
Default/1:1 (1024×1024), Landscape/16:9 (1024×576), and Phone/9:16
(576×1024). Save-folder selection is remembered in user-local state. Saved
names use `flux2-klein-4b,DD-MM-YYYY-NNN.png`, incrementing `NNN` within the
chosen folder.

After sending at least one chat message, `local-ai status` must report
`100% GPU`. A CPU-only or mixed CPU/GPU allocation is reported as a failed GPU
check.

While the server is running, requests can also be sent to Ollama's local API:

```bash
curl http://127.0.0.1:11434/api/chat \
  -d '{
    "model": "qwen3.5:9b-q4_K_M",
    "messages": [{"role": "user", "content": "Hello from the terminal"}],
    "stream": false
  }'
```

#### Qwen3.6 35B TurboQuant server

`run-qwen.sh` adds a separate, OpenAI-compatible Qwen3.6 server on
`127.0.0.1:8080`. It does not replace the Ollama models or change the default
Dolphin selection on port 11434. In the AGS chat window, select
`Qwen3.6-35B-A3B-Q4_K_M.gguf` while the service is off, then enable `Service`.
The switch starts and stops the guarded server automatically. Switching between
Qwen and an Ollama model stops the previous backend before starting the next.

The local build is [llama-cpp-turboquant](https://github.com/TheTom/llama-cpp-turboquant)
tag `tqp-v0.3.0` (`30d6881`), built for the RX 6700 XT with Vulkan, native CPU
instructions, and LTO. RADV/Mesa 26.1.5 detects it as `Vulkan0: AMD Radeon RX
6700 XT (RADV NAVI22)`. Vulkan and the fork expose `q8_0` plus `turbo2`,
`turbo3`, and `turbo4` K/V cache types. The existing system graphics packages
were not modified; private Vulkan/SPIR-V headers are below
`~/.local/share/local-qwen`.

The reproducible build command is:

```bash
qwen_data="${HOME}/.local/share/local-qwen"
cmake -S "${qwen_data}/llama-cpp-turboquant" \
  -B "${qwen_data}/llama-cpp-turboquant/build-rx6700xt-vulkan" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DGGML_VULKAN=ON \
  -DGGML_NATIVE=ON \
  -DGGML_LTO=ON \
  -DGGML_CCACHE=OFF \
  -DLLAMA_CURL=OFF \
  -DVulkan_INCLUDE_DIR="${qwen_data}/Vulkan-Headers-1.4.350/include" \
  -DVulkan_LIBRARY=/usr/lib/libvulkan.so \
  -DCMAKE_PREFIX_PATH="${qwen_data}/vulkan-sdk-1.4.350" \
  -DCMAKE_CXX_FLAGS="-I${qwen_data}/vulkan-sdk-1.4.350/include"
cmake --build "${qwen_data}/llama-cpp-turboquant/build-rx6700xt-vulkan" \
  --target llama-server llama-bench llama-cli -j 6
```

The model is `Qwen3.6-35B-A3B-Q4_K_M.gguf` from the
[ggml-org conversion](https://huggingface.co/ggml-org/Qwen3.6-35B-A3B-GGUF),
20,419,565,568 bytes, SHA-256
`671e47e0ec53c665d048b98c3ecbfd5236b5ca9c3e02ed19fc8f81f7b85140c7`.

The measured daily configuration is 32K context, `-ngl all -ncmoe 28`, q8_0 K
cache, turbo3 V cache, Flash Attention on, one slot, and six CPU threads. The
launcher also disables unused context checkpoints and prompt caching. It runs
inside a `MemorySwapMax=0` user scope, refuses a low-headroom start, and stops
the server if total free VRAM falls below 1,536 MiB:

```bash
run-qwen.sh
run-qwen.sh status
run-qwen.sh stop

curl http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "Qwen3.6-35B-A3B-Q4_K_M.gguf",
    "messages": [{"role": "user", "content": "Hello"}],
    "stream": false
  }'
```

Final measurements used a normal running desktop at about 2.7 GiB baseline
VRAM. Values are MiB; RAM is the server RSS at model-ready, while system RAM is
total non-available RAM at peak. Every completed output passed the marker and
arithmetic sanity check.

| Case | ctx / ncmoe / K/V / FA | Result | load / peak VRAM | free VRAM | model RSS | system RAM | pp / gen tok/s |
|---|---|---:|---:|---:|---:|---:|---:|
| A | 32K / 30 / q8/q8 / on | safe | 9,695 / 9,739 | 2,532 | 14,524 | 8,833 | 282.98 / 19.10 |
| B | 32K / 28 / q8/q8 / on | marginal | 10,560 / 10,570 | 1,701 | 13,590 | 8,805 | 299.48 / 20.05 |
| C | 32K / 26 / q8/q8 / on | guard stop | - / 11,421 | 850 | - | 8,758 | - |
| E | 32K / 30 / q8/turbo3 / on | lowest workload VRAM | 9,344 / 9,347 | 2,924 | 14,524 | 9,249 | 283.36 / 18.65 |
| I | 32K / 28 / q8/turbo3 / on | daily + fastest gen | 10,208 / 10,211 | 2,060 | 13,590 | 9,112 | 291.48 / 20.18 |
| F | 64K / 30 / q8/turbo3 / on | safe 64K | 9,847 / 9,857 | 2,414 | 14,527 | 8,954 | 280.81 / 18.80 |
| J | 64K / 28 / q8/turbo3 / on | guard stop | 10,712 / 10,736 | 1,535 | 13,591 | 9,051 | - |
| G | 32K / 30 / q8/f16 / off | safe, slower | 10,521 / 10,521 | 1,750 | 14,523 | 10,028 | 240.69 / 16.85 |
| H | 32K / 30 / q8/f16 / on | safe | 9,840 / 9,850 | 2,421 | 14,524 | 8,844 | 288.57 / 19.37 |

`ncmoe 24` was skipped after 26 crossed the guard. The 64K/turbo3 test at
`ncmoe 28` also crossed the floor at 1,535 MiB and hung during Vulkan cleanup;
the harness force-stopped only that process. There were no GPU allocation
failures, model-cgroup swap remained exactly zero, outputs were sane, desktop
processes stayed active, and the kernel logged no AMD GPU fault or reset. The
FA-off test emitted one Vulkan compute-buffer-size warning and was about 13%
slower in generation. Quantized V cache requires FA in this build, so q8_0 or
turbo3 V with `-fa off` is not a valid comparison; f16 V was used for G/H.

`--no-mmap` was rejected: its first load caused enough duplicate RAM/page-cache
pressure to increase system zram before the model became ready. Explicit mmap
is used instead. `--mlock` is not used because this account's memlock limit is
only 8 MiB; the no-swap cgroup enforces the important invariant without changing
system limits.

To use 64K safely:

```bash
QWEN_CONTEXT=65536 QWEN_NCMOE=30 run-qwen.sh
```

If a new desktop application consumes more VRAM, stop the server, raise
`QWEN_NCMOE` by two (start with 30), and rerun `benchmark-qwen.sh matrix`. Do not
lower the 1,536 MiB guard. The launcher uses a conservative startup estimate;
close GPU-heavy applications if it refuses to start rather than bypassing it.
Raw benchmark TSVs, commands, logs, samples, and responses are retained below
`~/.local/state/local-qwen/benchmarks/`.

### Secrets

The `secrets` package ships `*.env.example` templates only. After `stow secrets`, copy the example and fill in real values:

```bash
cp ~/.config/secrets/forgejo.env.example ~/.config/secrets/forgejo.env
chmod 600 ~/.config/secrets/forgejo.env
# edit and fill in FORGEJO_TOKEN etc.
```

The real `*.env` files live in the repo but are gitignored.

### SDDM Install

The `sddm` theme cannot be managed with stow (requires root). Install it manually after cloning:

```bash
sudo cp -r ~/.dots/sddm /usr/share/sddm/themes/dots
sudo sed -i 's/Current=.*/Current=dots/' /etc/sddm.conf
```

To preview without logging out:

```bash
sddm-greeter-qt6 --test-mode --theme /usr/share/sddm/themes/dots
```

### RX 6700 XT Blank Screen on Boot

The RX 6700 XT (RDNA2) can get stuck in a low power state after shutdown, causing no video output on next boot. Fix by disabling GPU runtime power management:

```bash
sudo vim /etc/default/grub
```

Add `amdgpu.runpm=0` to `GRUB_CMDLINE_LINUX_DEFAULT`: 
GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES zswap.enabled=0 splash loglevel=3 amdgpu.runpm=0'

then regenerate GRUB config:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

BIOS — `Settings → Advanced → Power Management Setup`:
- `ErP Ready` → Enabled
- `Settings → Advanced → Wake Up Event Setup` → all wake sources Disabled
