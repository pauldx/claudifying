---
name: cf-tools-productivity-qr-generate
description: "Generate QR code PNG/SVG from text or URL using qrencode. Trigger: /cf-tools-productivity-qr-generate"
trigger: /cf-tools-productivity-qr-generate
version: 1.0.0
---

# /cf-tools-productivity-qr-generate

Render any text, URL, or payload to a QR code image. Default output is PNG; SVG supported via `--to svg`. Uses the small, no-dependency `qrencode` CLI.

## Usage

```
/cf-tools-productivity-qr-generate "hello world"
/cf-tools-productivity-qr-generate "https://example.com" out.png
/cf-tools-productivity-qr-generate "wifi:..." --to svg out.svg
/cf-tools-productivity-qr-generate --size 12 --margin 2 "long payload"
```

Arguments:
1. `text` (required) — string to encode; quote it if it contains spaces/special chars
2. `output` (optional, default `qr.png` in cwd) — output path, extension implies format
3. `--to {png|svg}` (optional, default inferred from extension or `png`)
4. `--size <int>` (optional, default `8`) — pixel size per module
5. `--margin <int>` (optional, default `4`) — quiet-zone modules around code
6. `--level {L|M|Q|H}` (optional, default `M`) — error-correction level

## What You Must Do When Invoked

### Step 1 — Verify qrencode is installed

```bash
if ! command -v qrencode >/dev/null 2>&1; then
  echo "ERROR: qrencode not installed."
  echo "Install: brew install qrencode  (macOS)"
  echo "         sudo apt install qrencode  (Debian/Ubuntu)"
  exit 2
fi
qrencode --version | head -1
```

### Step 2 — Parse args, pick output format

```bash
TEXT="$1"
OUTPUT="${2:-qr.png}"
FORMAT=""   # parsed from --to or extension
SIZE=8
MARGIN=4
LEVEL=M

# Heuristic: derive FORMAT from extension if not explicit
case "$OUTPUT" in
  *.svg) FORMAT="SVG" ;;
  *.png|*) FORMAT="PNG" ;;
esac
```

### Step 3 — Generate

```bash
qrencode -t "$FORMAT" -s "$SIZE" -m "$MARGIN" -l "$LEVEL" -o "$OUTPUT" "$TEXT"

if [ ! -f "$OUTPUT" ]; then
  echo "ERROR: qrencode failed to write $OUTPUT"
  exit 1
fi
```

### Step 4 — Report

```bash
BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')
echo "✅ QR code written"
echo "   Payload chars: ${#TEXT}"
echo "   Format:        $FORMAT"
echo "   Module size:   ${SIZE}px"
echo "   ECC level:     $LEVEL"
echo "   Output:        $OUTPUT (${BYTES} bytes)"
```

## Output Contract

```
## QR generation
**Payload:**       "<text-preview>" (<N> chars)
**Output:**        <abs-path>
**Format:**        PNG | SVG
**Module size:**   <N>px
**Margin:**        <N>
**ECC level:**     L | M | Q | H
**File size:**     <bytes>
```

## Gotchas

- **`qrencode` not found**: exit code 2 with `brew install qrencode` hint. Do NOT silently fall back to network QR APIs — the user expects offline generation.
- **Payload too large for chosen ECC**: high ECC (`H`) + long string can exceed QR capacity. Catch the qrencode error and suggest dropping to `L`.
- **WiFi / vCard payloads**: must follow the exact spec (`WIFI:T:WPA;S:SSID;P:pass;;`). Don't reformat — pass through verbatim.
- **SVG output is plain B/W**: no embedded fonts. If the user wants a styled SVG, point them at a dedicated styling tool.
- **Shell quoting**: payloads with `$`, backticks, or `&` must be single-quoted by the user. Echo back the exact text encoded so they can verify.

## Cross-Platform Notes

- **macOS**: `brew install qrencode`
- **Linux**: `sudo apt install qrencode` / `sudo dnf install qrencode`
- **Windows / WSL**: `apt install qrencode` inside WSL; native Windows has no maintained build — recommend WSL.
- Verify with `qrencode "test" -o /tmp/qr.png && file /tmp/qr.png`.
