# Agent Teams & Worktree Patterns

Run multiple Claude agents in parallel on the same codebase using git worktrees.

## Quick Start

```bash
# Create parallel worktrees from main
git worktree add ../myrepo-review   main
git worktree add ../myrepo-tests    main
git worktree add ../myrepo-refactor main

# Launch agents in separate terminals (or tmux panes)
# --dangerously-skip-permissions: bypass approval prompts in spawned panes (read-only agents only)
cd ../myrepo-review   && claude --dangerously-skip-permissions --agent cf-code-reviewer
cd ../myrepo-tests    && claude --dangerously-skip-permissions --agent cf-test-writer
cd ../myrepo-refactor && claude --dangerously-skip-permissions --agent cf-devops-sre
```

## Team Configurations

### Deep Review Team
Best for: pre-merge quality gate on large PRs.

| Agent | Role | Worktree |
|-------|------|----------|
| cf-code-reviewer | Correctness + maintainability | worktree-1 |
| cf-security-auditor | OWASP + secrets + dependencies | worktree-2 |
| cf-test-writer | Coverage assessment + gap analysis | worktree-3 |

### Feature Build Team
Best for: building features in parallel — one agent per concern.

| Agent | Role | Worktree |
|-------|------|----------|
| Main session | Feature implementation | main repo |
| cf-test-writer | Write tests as code lands | worktree-1 |
| cf-code-reviewer | Continuous review of changes | worktree-2 |

### Incident Response Team
Best for: investigating and fixing production issues.

| Agent | Role | Worktree |
|-------|------|----------|
| Main session | Root cause analysis + fix | main repo |
| cf-devops-sre | Check infra, logs, deployment | worktree-1 |
| cf-security-auditor | Check if exploit/breach involved | worktree-2 |

## tmux Setup

```bash
#!/usr/bin/env bash
# Launch a 3-agent review team in tmux
SESSION="review-team"
REPO=$(pwd)

CLAUDE_FLAGS="--dangerously-skip-permissions"

tmux new-session -d -s "$SESSION" -n "coordinator"
tmux send-keys -t "$SESSION:coordinator" "cd $REPO && claude $CLAUDE_FLAGS" C-m

tmux new-window -t "$SESSION" -n "security"
tmux send-keys -t "$SESSION:security" "cd $REPO && claude $CLAUDE_FLAGS --agent cf-security-auditor" C-m

tmux new-window -t "$SESSION" -n "tests"
tmux send-keys -t "$SESSION:tests" "cd $REPO && claude $CLAUDE_FLAGS --agent cf-test-writer" C-m

tmux attach -t "$SESSION"
```

## Worktree Best Practices

- **Symlink node_modules**: Avoid downloading deps per worktree
  ```json
  // .claude/settings.json
  { "worktree": { "symlinkDirectories": ["node_modules", ".cache"] } }
  ```
- **Clean up**: `git worktree remove ../myrepo-review` when done
- **Isolation**: Each worktree has its own branch — no merge conflicts between agents
- **Naming**: Use `../reponame-purpose` convention for worktree directories
