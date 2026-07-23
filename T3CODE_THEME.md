# T3 Code Dark-Mode Text Contrast

T3 Code does not currently expose a supported font-size or contrast setting.
Use `Ctrl++`, `Ctrl+-`, and `Ctrl+0` for zoom. Do not use Chromium
`--force-high-contrast`; it changes borders and native focus styling enough to
make the UI look broken.

This tweak only changes dark-mode text tokens:

- Main dark text: `neutral-100` -> `neutral-200` so it is not pure bright white.
- Muted dark text: `#818181` / `90% neutral-500 mix` -> brighter muted text.
- Borders, inputs, backgrounds, and component layout stay unchanged.

## Reset Bad Launcher Flags

If a local launcher override exists from earlier testing, make sure it launches
plain `t3code`:

```bash
mkdir -p ~/.local/share/applications
if [ ! -f ~/.local/share/applications/t3code.desktop ]; then
  cp /usr/share/applications/t3code.desktop ~/.local/share/applications/t3code.desktop
fi
sed -i 's|^Exec=.*|Exec=t3code %U|' ~/.local/share/applications/t3code.desktop
desktop-file-validate ~/.local/share/applications/t3code.desktop
```

Also remove any forced font or stale zoom settings from the Chromium profile:

```bash
tmp="$(mktemp)"
jq '
  del(.webkit.webprefs)
  | if (.webkit // {}) == {} then del(.webkit) else . end
  | del(.partition.per_host_zoom_levels)
  | if (.partition // {}) == {} then del(.partition) else . end
' ~/.config/t3code/Preferences > "$tmp" &&
mv "$tmp" ~/.config/t3code/Preferences
```

Quit T3 Code completely before patching:

```bash
pkill -f '/opt/t3code-bin/t3code' || true
```

## Option A: User Cache Patch

This does not need sudo. It is fragile because Chromium can refresh the cache,
but it is easy and safe to repeat.

```bash
node <<'NODE'
const fs = require("fs");
const os = require("os");
const path = require("path");

const cacheDir = path.join(os.homedir(), ".config/t3code/Cache/Cache_Data");
const replacements = [
  ["var(--color-neutral-100)", "var(--color-neutral-200)"],
  ["--muted-foreground:#818181", "--muted-foreground:#a3a3a3"],
  [
    "--muted-foreground:color-mix(in srgb, var(--color-neutral-500) 90%, var(--color-white))",
    "--muted-foreground:color-mix(in srgb, var(--color-neutral-500) 70%, var(--color-white))",
  ],
];

let patchedFiles = 0;

for (const name of fs.readdirSync(cacheDir)) {
  const file = path.join(cacheDir, name);
  if (!fs.statSync(file).isFile()) continue;

  const data = fs.readFileSync(file);
  if (!data.includes(Buffer.from("/assets/index-"))) continue;
  if (!data.includes(Buffer.from("--foreground:var(--color-neutral-100)"))) continue;

  for (const [fromText, toText] of replacements) {
    const from = Buffer.from(fromText);
    const to = Buffer.from(toText);
    if (from.length !== to.length) throw new Error(`replacement length mismatch: ${fromText}`);

    let offset = 0;
    let count = 0;
    while ((offset = data.indexOf(from, offset)) !== -1) {
      to.copy(data, offset);
      offset += to.length;
      count += 1;
    }
    if (count > 0) console.log(`${file}: ${count} x ${fromText}`);
  }

  fs.writeFileSync(file, data);
  patchedFiles += 1;
}

if (patchedFiles === 0) {
  throw new Error("No cached T3 Code CSS asset found. Start T3 Code once, quit it, then rerun this.");
}
NODE
```

Restart T3 Code after this.

## Option B: Sudo ASAR Patch

This is more persistent than the cache patch and should survive cache refreshes,
but package updates will replace `/opt/t3code-bin/resources/app.asar`. The script
updates the ASAR integrity metadata after patching.

Back up the ASAR first:

```bash
sudo cp -a /opt/t3code-bin/resources/app.asar \
  "/opt/t3code-bin/resources/app.asar.bak.$(date +%Y%m%d%H%M%S)"
```

Patch it:

```bash
sudo node <<'NODE'
const crypto = require("crypto");
const fs = require("fs");

const asarPath = "/opt/t3code-bin/resources/app.asar";
const cssPath = "apps/server/dist/client/assets/index-DAnjtfN8.css";
const replacements = [
  ["var(--color-neutral-100)", "var(--color-neutral-200)"],
  ["--muted-foreground:#818181", "--muted-foreground:#a3a3a3"],
  [
    "--muted-foreground:color-mix(in srgb, var(--color-neutral-500) 90%, var(--color-white))",
    "--muted-foreground:color-mix(in srgb, var(--color-neutral-500) 70%, var(--color-white))",
  ],
];

function nodeFor(header, filePath) {
  return filePath
    .split("/")
    .filter(Boolean)
    .reduce((node, part) => node && node.files && node.files[part], header);
}

function sha256(buffer) {
  return crypto.createHash("sha256").update(buffer).digest("hex");
}

const fd = fs.openSync(asarPath, "r+");
try {
  const prelude = Buffer.alloc(16);
  fs.readSync(fd, prelude, 0, prelude.length, 0);

  const headerSize = prelude.readUInt32LE(4);
  const headerJsonLength = prelude.readUInt32LE(12);
  const headerOffset = 16;
  const dataOffset = 8 + headerSize;

  const headerBuffer = Buffer.alloc(headerJsonLength);
  fs.readSync(fd, headerBuffer, 0, headerJsonLength, headerOffset);
  const header = JSON.parse(headerBuffer.toString("utf8"));

  const cssNode = nodeFor(header, cssPath);
  if (!cssNode || typeof cssNode.offset !== "string") {
    throw new Error(`Could not find ${cssPath} in ${asarPath}`);
  }

  const cssOffset = dataOffset + Number(cssNode.offset);
  const cssBuffer = Buffer.alloc(cssNode.size);
  fs.readSync(fd, cssBuffer, 0, cssBuffer.length, cssOffset);

  for (const [fromText, toText] of replacements) {
    const from = Buffer.from(fromText);
    const to = Buffer.from(toText);
    if (from.length !== to.length) throw new Error(`replacement length mismatch: ${fromText}`);

    let offset = 0;
    let count = 0;
    while ((offset = cssBuffer.indexOf(from, offset)) !== -1) {
      to.copy(cssBuffer, offset);
      offset += to.length;
      count += 1;
    }
    if (count === 0) throw new Error(`missing pattern: ${fromText}`);
    console.log(`${count} x ${fromText}`);
  }

  const blockSize = cssNode.integrity?.blockSize ?? 4194304;
  const blocks = [];
  for (let i = 0; i < cssBuffer.length; i += blockSize) {
    blocks.push(sha256(cssBuffer.subarray(i, Math.min(i + blockSize, cssBuffer.length))));
  }
  cssNode.integrity = {
    algorithm: "SHA256",
    hash: sha256(cssBuffer),
    blockSize,
    blocks,
  };

  const nextHeader = Buffer.from(JSON.stringify(header), "utf8");
  if (nextHeader.length !== headerJsonLength) {
    throw new Error("ASAR header length changed; aborting without writing.");
  }

  fs.writeSync(fd, nextHeader, 0, nextHeader.length, headerOffset);
  fs.writeSync(fd, cssBuffer, 0, cssBuffer.length, cssOffset);
} finally {
  fs.closeSync(fd);
}
NODE
```

Restart T3 Code after this.

## Restore

For the cache patch, clear T3 Code's Chromium cache:

```bash
rm -rf ~/.config/t3code/Cache ~/.config/t3code/'Code Cache'
```

For the ASAR patch, restore the backup you created:

```bash
sudo cp -a /opt/t3code-bin/resources/app.asar.bak.YYYYMMDDHHMMSS \
  /opt/t3code-bin/resources/app.asar
```
