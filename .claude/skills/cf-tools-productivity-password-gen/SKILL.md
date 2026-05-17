---
name: cf-tools-productivity-password-gen
description: "Generate cryptographically secure passwords or diceware passphrases via Python secrets. Trigger: /cf-tools-productivity-password-gen"
trigger: /cf-tools-productivity-password-gen
version: 1.0.0
---

# /cf-tools-productivity-password-gen

Generate one or more secure passwords using Python's `secrets` module (NOT `random`). Two modes: character-based (default) and diceware-style passphrase.

## Usage

```
/cf-tools-productivity-password-gen                              # 1 password, 20 chars, default alphabet
/cf-tools-productivity-password-gen --length 32 --count 5
/cf-tools-productivity-password-gen --alphabet alnum --length 16
/cf-tools-productivity-password-gen --alphabet hex --length 64
/cf-tools-productivity-password-gen --passphrase --words 6
/cf-tools-productivity-password-gen --passphrase --words 5 --separator "-"
```

Arguments:
- `--length <N>` — character count (default 20). Min 8, max 256.
- `--count <N>` — number of passwords to emit (default 1, max 100)
- `--alphabet <name>` — `full` (letters+digits+symbols, default), `alnum`, `letters`, `digits`, `hex`, `urlsafe`
- `--no-ambiguous` — drop visually confusable chars (`0Oo1lI`)
- `--passphrase` — switch to diceware mode
- `--words <N>` — passphrase word count (default 5)
- `--separator <str>` — passphrase word separator (default `" "`)

## What You Must Do When Invoked

### Step 1 — Hard rule: use `secrets`, not `random`

```bash
python3 - "$@" <<'PY'
import sys, secrets, string

# ---- arg parsing ----
args = sys.argv[1:]
length = 20
count = 1
alphabet_name = "full"
no_ambig = False
passphrase = False
words = 5
sep = " "

i = 0
while i < len(args):
    a = args[i]
    if a == "--length":    length = int(args[i+1]); i += 2
    elif a == "--count":   count = int(args[i+1]); i += 2
    elif a == "--alphabet": alphabet_name = args[i+1]; i += 2
    elif a == "--no-ambiguous": no_ambig = True; i += 1
    elif a == "--passphrase":   passphrase = True; i += 1
    elif a == "--words":   words = int(args[i+1]); i += 2
    elif a == "--separator": sep = args[i+1]; i += 2
    else: i += 1

# ---- validation ----
if length < 8 or length > 256:
    print("ERROR: --length must be between 8 and 256"); sys.exit(1)
if count < 1 or count > 100:
    print("ERROR: --count must be between 1 and 100"); sys.exit(1)
if words < 3 or words > 12:
    print("ERROR: --words must be between 3 and 12"); sys.exit(1)

# ---- alphabets ----
ALPHABETS = {
    "full":    string.ascii_letters + string.digits + "!@#$%^&*()-_=+[]{};:,./?",
    "alnum":   string.ascii_letters + string.digits,
    "letters": string.ascii_letters,
    "digits":  string.digits,
    "hex":     "0123456789abcdef",
    "urlsafe": string.ascii_letters + string.digits + "-_",
}
if alphabet_name not in ALPHABETS:
    print(f"ERROR: unknown --alphabet {alphabet_name}; choose: {', '.join(ALPHABETS)}")
    sys.exit(1)
alphabet = ALPHABETS[alphabet_name]
if no_ambig:
    alphabet = "".join(c for c in alphabet if c not in "0Oo1lI")

# ---- diceware word list (built-in compact list ~256 common words) ----
DICE = (
"about above accept across active actor adapt adept admin admit adopt adult "
"after again agent agree ahead alarm album alert alien align alike alive "
"allow alone along alpha alter among angel anger angle ankle apple apply "
"april arena argue arise armor array arrow aside asset audio audit avoid "
"awake award aware bacon badge baker basic batch beach beard beast began "
"begin being below bench berry biome birch birth blade blame blank blast "
"bleed blend bless blind block blood bloom blunt blush board boast boldly "
"bonus boost booth borne brace brain brake brand brave bread break brick "
"bride brief bring brink broad broke broom brown brush build built bunch "
"burst cable cache cadet cargo carry catch cause cease chain chair chalk "
"champ chant chaos chart cheap check chess chest chief child chill choir "
"chose civic civil claim clamp clash clasp class clean clear clerk click "
"cliff climb cling clip clock close cloth cloud clown coach coast cobra "
"coral could count court cover craft crane crash crate crawl craze cream "
"creek crest crime crisp cross crowd crown crude cruel crumb crush crust "
"cycle daisy dance dared dared dazed debug decay decoy deeds defer delay "
"depth derby deter dever diary digit dimly diner diode disco ditch diver "
"dizzy dodge donor dough dozen draft drama drawn dream dress drift drink "
"drive drone drown druid drums duchy dwarf dwell eagle early earth easel"
).split()

# ---- generation ----
def gen_password():
    return "".join(secrets.choice(alphabet) for _ in range(length))

def gen_passphrase():
    return sep.join(secrets.choice(DICE) for _ in range(words))

import math
if passphrase:
    bits = math.log2(len(set(DICE))) * words
else:
    bits = math.log2(len(set(alphabet))) * length

print(f"# Entropy estimate: ~{bits:.1f} bits")
for _ in range(count):
    print(gen_passphrase() if passphrase else gen_password())
PY
```

### Step 2 — Reminder note

```bash
echo ""
echo "Source: Python secrets module (CSPRNG). Do not reuse on multiple sites."
```

## Output Contract

```
## Password generation
**Mode:**     password | passphrase
**Length:**   <N chars> | <N words>
**Alphabet:** full | alnum | letters | digits | hex | urlsafe
**Entropy:**  ~<X> bits

<password 1>
<password 2>
...
```

## Gotchas

- **NEVER swap in `random.choice`**: it's not cryptographically secure. `secrets` only.
- **Display in terminal scrollback**: anything echoed sits in `~/.zsh_history` if user copy-pastes. Mention piping to `pbcopy` and clearing scrollback.
- **Ambiguous chars**: `0/O`, `1/l/I` look identical in some fonts. `--no-ambiguous` removes them — entropy drops slightly; reflect that in the report.
- **Symbol set in `full`**: deliberately omits quotes (`'"\``) and backslash to avoid shell-escaping headaches. Don't extend without thinking.
- **Diceware list is compact (~250 words)**: 5 words ≈ 40 bits. For ~128-bit targets recommend the EFF long list (7776 words) — out of scope here, but mention it.
- **Length below 8**: refuse. Below 12 the skill should still work but warn (commented in code).

## Cross-Platform Notes

- Pure Python 3.6+. No deps, no network.
- `secrets` is in stdlib since 3.6 — should be available everywhere claudifying runs.
- For passphrase use, recommend pairing with a real EFF word list for production secrets.
