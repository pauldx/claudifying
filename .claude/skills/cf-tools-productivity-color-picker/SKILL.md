---
name: cf-tools-productivity-color-picker
description: "Preview a hex or rgb color as a terminal swatch and show the nearest named CSS color. Trigger: /cf-tools-productivity-color-picker"
trigger: /cf-tools-productivity-color-picker
version: 1.0.0
---

# /cf-tools-productivity-color-picker

Given a hex (`#ff8800`) or rgb (`rgb(255,136,0)`) input, print an ANSI 24-bit terminal swatch plus the closest named CSS color and useful conversions (RGB, HSL, hex short form).

## Usage

```
/cf-tools-productivity-color-picker "#ff8800"
/cf-tools-productivity-color-picker "rgb(255, 136, 0)"
/cf-tools-productivity-color-picker "ff8800"
```

Arguments:
1. `color` (required) — hex (3 or 6 digits, optional `#`) or `rgb(r, g, b)`

## What You Must Do When Invoked

### Step 1 — Normalize input to (r, g, b)

```bash
COLOR_IN="$1"

python3 - "$COLOR_IN" <<'PY'
import sys, re

raw = sys.argv[1].strip()

# rgb(r, g, b)
m = re.match(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)', raw, re.I)
if m:
    r, g, b = [int(x) for x in m.groups()]
else:
    # hex
    s = raw.lstrip('#')
    if len(s) == 3:
        s = ''.join(c*2 for c in s)
    if len(s) != 6 or not re.fullmatch(r'[0-9a-fA-F]{6}', s):
        print("ERROR: not a valid color")
        sys.exit(1)
    r, g, b = int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)

for v in (r, g, b):
    if v < 0 or v > 255:
        print("ERROR: channel out of range 0..255")
        sys.exit(1)

# HSL conversion
def rgb_to_hsl(r, g, b):
    r, g, b = r/255, g/255, b/255
    mx, mn = max(r, g, b), min(r, g, b)
    l = (mx + mn) / 2
    if mx == mn:
        h = s = 0
    else:
        d = mx - mn
        s = d / (2 - mx - mn) if l > 0.5 else d / (mx + mn)
        if mx == r:   h = (g - b) / d + (6 if g < b else 0)
        elif mx == g: h = (b - r) / d + 2
        else:         h = (r - g) / d + 4
        h *= 60
    return int(round(h)), int(round(s*100)), int(round(l*100))

# Tiny CSS named color table (subset — good enough for "nearest")
NAMES = {
 'black':(0,0,0),'white':(255,255,255),'red':(255,0,0),'lime':(0,255,0),
 'blue':(0,0,255),'yellow':(255,255,0),'cyan':(0,255,255),'magenta':(255,0,255),
 'silver':(192,192,192),'gray':(128,128,128),'maroon':(128,0,0),'olive':(128,128,0),
 'green':(0,128,0),'purple':(128,0,128),'teal':(0,128,128),'navy':(0,0,128),
 'orange':(255,165,0),'pink':(255,192,203),'gold':(255,215,0),'tomato':(255,99,71),
 'salmon':(250,128,114),'coral':(255,127,80),'crimson':(220,20,60),'indigo':(75,0,130),
 'turquoise':(64,224,208),'violet':(238,130,238),'khaki':(240,230,140),
 'beige':(245,245,220),'chocolate':(210,105,30),'tan':(210,180,140),
 'plum':(221,160,221),'orchid':(218,112,214),'lavender':(230,230,250),
 'mint':(189,252,201),'skyblue':(135,206,235),'steelblue':(70,130,180),
}
def dist(a, b):
    return sum((x-y)**2 for x, y in zip(a, b))
nearest = min(NAMES.items(), key=lambda kv: dist(kv[1], (r, g, b)))

hex_full = f"#{r:02x}{g:02x}{b:02x}"
short = hex_full
if hex_full[1] == hex_full[2] and hex_full[3] == hex_full[4] and hex_full[5] == hex_full[6]:
    short = f"#{hex_full[1]}{hex_full[3]}{hex_full[5]}"
h, s, l = rgb_to_hsl(r, g, b)

# ANSI 24-bit swatch — 6 rows × 30 cols of background
swatch = ""
for _ in range(3):
    swatch += f"\x1b[48;2;{r};{g};{b}m" + " " * 30 + "\x1b[0m\n"

print(swatch, end="")
print(f"hex:      {hex_full}  ({short})")
print(f"rgb:      rgb({r}, {g}, {b})")
print(f"hsl:      hsl({h}, {s}%, {l}%)")
print(f"nearest:  {nearest[0]} (Δ²={dist(nearest[1], (r, g, b))})")
PY
```

### Step 2 — Detect color terminal

```bash
# If $TERM lacks 24-bit, warn — swatch will show as plain blocks
case "$COLORTERM" in
  truecolor|24bit) : ;;
  *) echo "[note] \$COLORTERM=$COLORTERM; swatch may render as approximate 256-color in older terminals" ;;
esac
```

## Output Contract

```
## Color preview

  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓    (24-bit swatch — 3 rows)

**hex:**      #ff8800 (#f80)
**rgb:**      rgb(255, 136, 0)
**hsl:**      hsl(32, 100%, 50%)
**nearest:**  orange (Δ²=841)
```

## Gotchas

- **Tmux strips truecolor by default**: set `terminal-features ",xterm-256color:RGB"` in `.tmux.conf`.
- **CI logs render swatch as gibberish**: ANSI escapes are noise without a TTY. Add `--no-color` flag if you adopt one — for now, the skill prints both swatch and text values, so the text portion is always readable.
- **3-digit hex**: `#fc0` expands to `#ffcc00`. Don't strip leading `#` and then mis-parse.
- **rgb() with %**: e.g. `rgb(100%, 50%, 0%)` — current parser assumes integers. Document this; user should convert manually.
- **Nearest-named is approximate**: table has ~35 CSS colors — good for sanity check, not a full match. Suggest a richer table only if a user asks.

## Cross-Platform Notes

- **macOS Terminal.app**: supports 24-bit since 2017. iTerm2: yes. Apple Terminal pre-Big Sur: 256-color only.
- **Linux**: most modern terminals support truecolor; check with `printf '\x1b[48;2;255;0;0m  \x1b[0m\n'`.
- **Windows Terminal**: yes. cmd.exe legacy: no — recommend Windows Terminal or WSL.
