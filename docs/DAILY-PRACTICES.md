# Daily Practices

Best practices for getting the most out of Claude Code with Claudifying.

## Before Starting

1. **Update Claude Code** — run `claude update` or check for updates
2. **Check the changelog** — scan for new features: `claude changelog` or browse the [CHANGELOG](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
3. **Pull latest toolkit** — the SessionStart hook auto-syncs, but you can also `cd claudifying && git pull`

## Session Habits

- **Start with plan mode** for any non-trivial task — think before coding
- **Use `/compact` at ~50%** context — don't let Claude enter the "dumb zone"
- **Use `/clear`** when switching to a completely different task mid-session
- **Commit at least once per hour** — small atomic commits, easy to revert
- **Use `/rename`** on important sessions so you can `/resume` them later

## Leveraging the Toolkit

- **Use slash commands** for repetitive workflows: `/cf-bootstrap`, `/cf-review`, `/cf-test-all`
- **Use agents** for parallel work: spawn multiple agents on worktrees for deep review
- **Use skills** — they auto-trigger from natural language. Say "review this" and `cf-code-review` activates
- **Use hooks** — they auto-run: pre-commit secret scanning, post-tool formatting, session context

## Review & Quality

- **Keep PRs small** — easier to review, easier to revert if needed
- **Always squash merge** — clean linear history
- **Run `/cf-review`** before pushing — catches bugs, security issues, and missing tests
- **Run `/cf-security-audit`** before releases — OWASP check, secret detection, CVE deps

## Context Management

- **Use thinking mode** (`/config` → always on) — see Claude's reasoning
- **Use explanatory output style** — already set in settings.json
- **Use Opus for planning, Sonnet for coding** — `/model` to switch
- **Use "thinking" or "ultrathink"** keywords in prompts for high-effort reasoning on complex problems

## Monitoring

- **Status line** shows branch and working tree status
- **`/cf-document`** to keep README and API docs in sync
- **`/context`** to see how much context window remains
- **Log outputs** from hooks at `~/.claude/hooks.log`

## Team Collaboration

- **Agent teams with tmux** (see [AGENT-TEAMS.md](./AGENT-TEAMS.md)) for parallel development
- **Git worktrees** for isolated parallel branches (no conflicts between agents)
- **Cross-agent review** — spawn security + code reviewers in parallel
- **Shared tools** — one person contributes skill, entire team benefits

## Using Claudifying Effectively

1. **Explore available skills** — `ls ~/.claude/skills/ | grep cf-` to see what's available
2. **Read skill READMEs** — understand what each skill does before using
3. **Contribute back** — if you build a new pattern, add it as a skill
4. **Update regularly** — `cd claudifying && git pull` to get new extensions from team
