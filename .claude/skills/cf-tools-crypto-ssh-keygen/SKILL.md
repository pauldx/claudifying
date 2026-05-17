---
name: cf-tools-crypto-ssh-keygen
description: "Generate an SSH keypair (ed25519 default, RSA-4096 opt-in) with optional ssh-agent add. Trigger: /cf-tools-crypto-ssh-keygen"
trigger: /cf-tools-crypto-ssh-keygen
version: 1.0.0
---

# /cf-tools-crypto-ssh-keygen

Generate a modern SSH keypair. Defaults to ed25519 (smaller, faster, safer than RSA). RSA-4096 available as an explicit opt-in for legacy systems that don't speak ed25519.

## Usage

```
/cf-tools-crypto-ssh-keygen
/cf-tools-crypto-ssh-keygen --output ~/.ssh/id_work --comment "work@laptop"
/cf-tools-crypto-ssh-keygen --type rsa
/cf-tools-crypto-ssh-keygen --type ed25519 --add-agent
```

Arguments:
1. `--type ed25519|rsa` (optional, default `ed25519`) — algorithm; rsa = 4096 bits
2. `--output PATH` (optional, default `~/.ssh/id_ed25519` or `~/.ssh/id_rsa`) — private key path
3. `--comment STRING` (optional, default `"$(whoami)@$(hostname)"`) — key comment
4. `--passphrase STRING` (optional, default empty) — passphrase for the private key
5. `--add-agent` (optional flag) — ssh-add the key after generation

## What You Must Do When Invoked

### Step 1 — Resolve args

```bash
TYPE="ed25519"
OUTPUT=""
COMMENT="$(whoami)@$(hostname)"
PASSPHRASE=""
ADD_AGENT=0
# parse flags...
[ -z "$OUTPUT" ] && OUTPUT="$HOME/.ssh/id_${TYPE}"

if [ -f "$OUTPUT" ]; then
  echo "ERROR: $OUTPUT already exists. Choose a different --output path."
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"
chmod 700 "$(dirname "$OUTPUT")"
```

### Step 2 — Generate keypair

```bash
if [ "$TYPE" = "rsa" ]; then
  ssh-keygen -t rsa -b 4096 -f "$OUTPUT" -C "$COMMENT" -N "$PASSPHRASE" -q
else
  ssh-keygen -t ed25519 -f "$OUTPUT" -C "$COMMENT" -N "$PASSPHRASE" -q
fi

chmod 600 "$OUTPUT"
chmod 644 "${OUTPUT}.pub"
```

### Step 3 — Optional: add to ssh-agent

```bash
if [ "$ADD_AGENT" = "1" ]; then
  eval "$(ssh-agent -s)" >/dev/null
  ssh-add "$OUTPUT" 2>&1
fi
```

### Step 4 — Report fingerprint + public key

```bash
FP=$(ssh-keygen -lf "${OUTPUT}.pub" | awk '{print $2}')
PUBKEY=$(cat "${OUTPUT}.pub")
```

## Output Contract

```
## SSH keypair generated

**Type:**         ed25519 | rsa-4096
**Private key:**  <path>   (chmod 600 — DO NOT SHARE)
**Public key:**   <path>.pub  (safe to share)
**Comment:**      <comment>
**Fingerprint:**  SHA256:<...>
**ssh-agent:**    added | not added

### Public key (paste into GitHub / GitLab / authorized_keys)

<contents of .pub file>

⚠️  Private key saved to <path>. NEVER share it, commit it, or paste it into chat.
```

NEVER print the private key contents in skill output.

## Gotchas

- **File already exists**: refuse to overwrite. The user can `rm` it first or pass `--output`.
- **No `~/.ssh` directory**: create it with `mkdir -p` and `chmod 700` — sshd refuses world-readable dirs.
- **Comment with spaces**: quote it in the CLI call. ssh-keygen accepts spaces in `-C`.
- **Passphrase empty**: fine for automation but the private key is unencrypted on disk — note it explicitly.
- **`--add-agent` outside a login shell**: spawning ssh-agent inside the skill only persists for the current process. Tell the user to `eval "$(ssh-agent -s)"` and `ssh-add` themselves for persistence.
- **GitHub still needs registration**: generating a key doesn't deploy it — the user must paste `.pub` into Settings → SSH keys.

## Cross-Platform Notes

- **macOS**: `~/.ssh/config` should include `UseKeychain yes` + `AddKeysToAgent yes` for passphrased keys.
- **Linux**: `ssh-agent` typically auto-starts via systemd user units. If `ssh-add` fails with "Could not open a connection", run `eval "$(ssh-agent -s)"`.
- **Windows / WSL**: ed25519 works in OpenSSH 6.5+. Older PuTTY needs RSA — pass `--type rsa`.
