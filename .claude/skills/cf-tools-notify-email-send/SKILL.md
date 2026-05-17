---
name: cf-tools-notify-email-send
description: "Send email via local mail CLI or SMTP (python smtplib). Trigger: /cf-tools-notify-email-send"
trigger: /cf-tools-notify-email-send
version: 1.0.0
---

# /cf-tools-notify-email-send

Send an email from the shell. Two backends:

1. **mail CLI** (default if `mail` is on PATH and no SMTP env is set) — uses the system MTA. Zero config but unreliable for outbound from a laptop.
2. **SMTP via python smtplib** — reliable. Reads creds from env vars.

## Usage

```
/cf-tools-notify-email-send --to alice@example.com --subject "CI green" --body "All checks passed"
/cf-tools-notify-email-send --to a@x.com,b@y.com --subject "Weekly" --body-file report.md
/cf-tools-notify-email-send --to ops@x.com --subject "Alert" --html alert.html
/cf-tools-notify-email-send --to a@x.com --from noreply@x.com --subject "Test" --body "Hi"
```

Arguments:
1. `--to <addrs>` (required) — comma-separated recipients
2. `--from <addr>` — sender (required for SMTP; mail CLI uses `$USER@$(hostname)`)
3. `--subject <text>` (required)
4. `--body <text>` OR `--body-file <path>` OR `--html <path>` (one required)
5. `--cc <addrs>`, `--bcc <addrs>` — optional
6. `--attach <path>` — file attachment (repeatable; SMTP backend only)
7. `--reply-to <addr>` — Reply-To header

## Credentials (SMTP — env vars only)

```bash
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"            # 587 = STARTTLS, 465 = SSL, 25 = plain
export SMTP_USER="me@gmail.com"
export SMTP_PASS="app-specific-password"   # NOT your account password
export SMTP_TLS="starttls"        # starttls | ssl | none (default: starttls)
```

> Never accept `SMTP_PASS` as a positional arg. Bash history leak risk.
> Gmail: generate an App Password at <https://myaccount.google.com/apppasswords> — regular login is blocked.

## What You Must Do When Invoked

### Step 1 — Pick backend

```bash
set +x  # NEVER xtrace — SMTP_PASS leaks otherwise

if [ -n "$SMTP_HOST" ] && [ -n "$SMTP_USER" ] && [ -n "$SMTP_PASS" ]; then
  BACKEND="smtp"
elif command -v mail >/dev/null 2>&1; then
  BACKEND="mail"
else
  echo "ERROR: configure SMTP_HOST/USER/PASS or install BSD mail"
  exit 1
fi
echo "Backend: $BACKEND"
```

### Step 2a — mail CLI path

```bash
if [ "$BACKEND" = "mail" ]; then
  BODY=""
  [ -n "$BODY_TEXT" ]    && BODY="$BODY_TEXT"
  [ -n "$BODY_FILE" ]    && BODY=$(cat "$BODY_FILE")
  [ -n "$HTML_FILE" ] && {
    echo "WARN: --html requires SMTP backend. Sending as plain text."
    BODY=$(cat "$HTML_FILE")
  }

  HEADERS=()
  [ -n "$CC" ]       && HEADERS+=(-c "$CC")
  [ -n "$BCC" ]      && HEADERS+=(-b "$BCC")
  [ -n "$REPLY_TO" ] && HEADERS+=(-S "replyto=$REPLY_TO")
  [ -n "$FROM" ]     && HEADERS+=(-r "$FROM")

  echo "$BODY" | mail -s "$SUBJECT" "${HEADERS[@]}" "$TO"
  echo "✅ Queued via local MTA. Check /var/log/mail.log for delivery."
fi
```

### Step 2b — SMTP path

```bash
if [ "$BACKEND" = "smtp" ]; then
  python3 - <<'PY'
import os, sys, ssl, smtplib
from email.message import EmailMessage
from email.utils import make_msgid
from pathlib import Path

msg = EmailMessage()
msg["From"]    = os.environ.get("FROM") or os.environ["SMTP_USER"]
msg["To"]      = os.environ["TO"]
msg["Subject"] = os.environ["SUBJECT"]
for h in ("CC", "REPLY_TO"):
    if os.environ.get(h):
        msg[h.replace("_","-").title()] = os.environ[h]

if os.environ.get("HTML_FILE"):
    html = Path(os.environ["HTML_FILE"]).read_text()
    msg.set_content("HTML email — view in HTML client.")
    msg.add_alternative(html, subtype="html")
elif os.environ.get("BODY_FILE"):
    msg.set_content(Path(os.environ["BODY_FILE"]).read_text())
else:
    msg.set_content(os.environ.get("BODY_TEXT", ""))

for path in os.environ.get("ATTACH", "").split(":"):
    if not path: continue
    p = Path(path)
    msg.add_attachment(p.read_bytes(),
                       maintype="application", subtype="octet-stream",
                       filename=p.name)

host = os.environ["SMTP_HOST"]
port = int(os.environ.get("SMTP_PORT", "587"))
mode = os.environ.get("SMTP_TLS", "starttls").lower()

if mode == "ssl":
    s = smtplib.SMTP_SSL(host, port, context=ssl.create_default_context())
else:
    s = smtplib.SMTP(host, port)
    if mode == "starttls":
        s.starttls(context=ssl.create_default_context())
s.login(os.environ["SMTP_USER"], os.environ["SMTP_PASS"])
# BCC handled by passing rcpt list directly
rcpts = [r.strip() for r in os.environ["TO"].split(",")]
if os.environ.get("CC"):  rcpts += [r.strip() for r in os.environ["CC"].split(",")]
if os.environ.get("BCC"): rcpts += [r.strip() for r in os.environ["BCC"].split(",")]
s.send_message(msg, to_addrs=rcpts)
s.quit()
print("✅ Sent via SMTP")
PY
fi
```

## Output Contract

```
## Email send

**Backend:**   mail | smtp
**From:**      <addr>
**To:**        <addr,addr,...>
**Subject:**   <subject>
**Attach:**    <count>
**Status:**    ✅ accepted by <host> | ❌ <error>
```

## Gotchas

- **Local `mail` to Gmail/Outlook drops to spam or bounces**: receiving servers reject mail from residential IPs. Use SMTP backend with a real auth.
- **Gmail "less secure apps" rejected**: must use App Password (2FA required).
- **Office 365 requires modern auth**: smtplib login may fail — use OAuth XOAUTH2 (out of scope) or a relay like SendGrid.
- **Port 25 outbound blocked by most ISPs**: use 587 (STARTTLS) or 465 (SSL).
- **SPF / DKIM**: `--from` lying about a domain you don't control = spam or rejection.
- **HTML email**: must be valid HTML. No external CSS — inline styles only. Many clients strip `<style>` blocks.
- **Attachments over ~25MB rejected** by most providers — link to cloud storage instead.
- **Secrets in logs**: never `set -x`. SMTP_PASS in xtrace output = compromised account.

## Cross-Platform Notes

- macOS: `mail` is BSD mailx. SMTP works identically via python3 (preinstalled).
- Linux: `apt install bsd-mailx` or use `msmtp` as a sendmail replacement.
- Windows: skip the `mail` backend — use SMTP via python.
