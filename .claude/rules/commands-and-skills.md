<!-- Rule: Command & skill authoring — loaded when creating or editing commands/skills -->

<important if="the task involves creating, editing, or debugging slash commands or skills in this repo">

## Command Authoring Rules

- All commands need YAML frontmatter with at minimum `description`
- Skill `description` is a TRIGGER, not a summary — write it as "When the user asks to X, activate this"
- No hardcoded emails, paths, or DON IDs — use dynamic discovery
- Use kebab-case filenames: `create-issue.md`, not `createIssue.md`
- Don't railroad skills with prescriptive step-by-step — give goals and constraints, let Claude decide how
- Every skill should have a Gotchas section with real failure points
- Include scripts and reference docs so Claude composes rather than reconstructs boilerplate
- After adding a command, run `./install.sh` to create the symlink

</important>
