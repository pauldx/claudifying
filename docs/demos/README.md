# Demo Recordings

Animated terminal GIFs embedded in the top-level `README.md`. Recordings are
deterministic — generated from scripted transcripts via
[charmbracelet/vhs](https://github.com/charmbracelet/vhs) so they look the
same on every machine and never hit a live API.

## Layout

```
docs/demos/
├── scripts/   Scripted transcript files (one per demo)
├── tapes/     vhs tape files (one per demo, references a script)
├── gifs/      Rendered GIFs (committed; embedded in README.md)
└── lib/
    └── cf-sim.sh   Transcript player used inside the tapes
```

`cf-sim.sh` reads a transcript line-by-line and replays it with typing,
spinner, and color cadence. Tape files just `Type` the command that runs the
sim against a chosen script. This means:

- No API calls, no flaky network.
- Output is identical across re-renders.
- Cheap to keep up to date — edit the script text, re-render the tape.

## Regenerate one demo

```bash
brew install charmbracelet/tap/vhs        # one-time
vhs docs/demos/tapes/02-code-review.tape  # rewrites gifs/02-code-review.gif
```

## Regenerate all demos

```bash
for tape in docs/demos/tapes/*.tape; do
  vhs "$tape"
done
```

## Edit content

1. Edit the transcript: `docs/demos/scripts/02-code-review.txt`
2. (Optional) tweak the tape's `Height` or final `Sleep` if the script got
   longer/shorter: `docs/demos/tapes/02-code-review.tape`
3. Re-render: `vhs docs/demos/tapes/02-code-review.tape`

## Transcript directives

| Directive | Effect |
|-----------|--------|
| `#HEADER text` | Bold title line |
| `#PROMPT` | Print Claude-style `❯ ` prompt (no newline) |
| `#USER text` | Type `text` with typing animation |
| `#THINK ms` | Animated "thinking..." spinner for `ms` milliseconds |
| `#SAY text` | Plain response line |
| `#CODE text` | Muted/dim line (code, paths, stats) |
| `#OK text` | Green ✓ line |
| `#WARN text` | Yellow ⚠ line |
| `#ERR text` | Red ✗ line |
| `#SLEEP ms` | Silent pause |
| `#DIVIDER` | Horizontal rule |
| `#CLEAR` | Clear the screen |

Lines that don't start with `#` are printed verbatim.

## Adding a new demo

1. Drop a transcript in `scripts/NN-name.txt`.
2. Copy any existing tape (e.g. `tapes/05-bootstrap.tape`), change the
   `Output` path and the script path in the `Type` line.
3. Run `vhs docs/demos/tapes/NN-name.tape`.
4. Embed the GIF in the top-level `README.md`.
