<!-- Rule: Git workflow — loaded when working with git operations -->

<important if="the task involves git commits, branches, PRs, or pushing code">

## Git Workflow Rules

- Branch naming: `<prefix>/<description>` — use kebab-case, e.g., `jane/add-feature-x`, `john/fix-auth-bug`
- Commit messages: `<type>: <description>` — types: feat, fix, docs, refactor, test, chore
- Keep PRs small and focused — one feature/fix per PR
- Squash merge PRs for clean linear history
- Never commit .env files, credentials, or personal configs
- Always create new commits rather than amending — amending destroys previous work if a hook fails
- Run tests before pushing — verify the build passes

</important>
