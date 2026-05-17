---
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, AskUserQuestion
description: Triage and resolve automated code review comments on a PR
user-invocable: true
argument: <owner>/<repo>#<pr_number> (e.g. initech/tps-report-generator#42)
---

# Triage PR Review

Process and respond to automated code review comments (e.g., GitHub Copilot reviews) on a pull request.

**Argument:** `$ARGUMENTS` -- the PR reference in `<owner>/<repo>#<pr_number>` format.

If no argument is provided, ask the user for the PR. You can also detect the PR from the current branch:

```bash
gh pr view --json number,headRepository --jq '{number, owner: .headRepository.owner.login, repo: .headRepository.name}'
```

## Workflow

### 1. Fetch All Unresolved PR Conversations

Use GraphQL to get all review threads. Include `pageInfo` to handle pagination if there are 100+ threads:

```bash
gh api graphql -f query='
{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {pr_number}) {
      reviewThreads(first: 100) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          comments(first: 10) {
            nodes {
              id
              body
              author { login }
            }
          }
        }
      }
    }
  }
}' --jq '.data.repository.pullRequest.reviewThreads'
```

If `pageInfo.hasNextPage` is `true`, fetch additional pages using the cursor:

```bash
gh api graphql -f query='
{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {pr_number}) {
      reviewThreads(first: 100, after: "{endCursor}") {
        pageInfo { hasNextPage endCursor }
        nodes { id isResolved isOutdated path line comments(first: 10) { nodes { id body author { login } } } }
      }
    }
  }
}'
```

Repeat until `hasNextPage` is `false`. Combine all nodes, then filter for unresolved: `select(.isResolved == false)`

If there are no unresolved threads, report that and stop.

### 2. Auto-Resolve Outdated Threads

Threads where `isOutdated: true` indicate the code has changed since the review comment was made. Resolve these with a brief note:

```bash
# For each outdated thread
gh api graphql -f query='mutation($tid: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $tid, body: $body }) { comment { id } }
}' -f tid="{thread_id}" -f body="Outdated - the code referenced in this comment has changed."

gh api graphql -f query='mutation($tid: ID!) {
  resolveReviewThread(input: { threadId: $tid }) { thread { isResolved } }
}' -f tid="{thread_id}"
```

### 3. Read Affected Code

Before triaging current threads, read the files and lines referenced in each conversation to understand the context.

### 4. Triage Each Current Thread

For each non-outdated, unresolved conversation, present a summary to the user and triage into one of three categories:

| Category      | Action                               | Response Template                                                |
| ------------- | ------------------------------------ | ---------------------------------------------------------------- |
| **Obsolete**  | Already fixed in a prior commit      | "This has been addressed in commit `{sha}` which {description}." |
| **Non-issue** | Not a real problem or not applicable | "Not applicable - {reason}."                                     |
| **Needs fix** | Valid issue requiring code change    | Fix it, then respond: "Fixed in commit `{sha}`."                 |

### 5. Fix Issues

For issues needing fixes:

- Stop and make the code change
- Allow user to review/test
- Commit the fix **before** moving to the next conversation (isolated commits)
- Then respond to the conversation

### 6. Post Response and Resolve Thread

Use GraphQL to reply and resolve (thread IDs are `PRRT_...` format):

```bash
# Reply to a review thread
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId,
      body: $body
    }) { comment { id } }
  }' -f threadId="{thread_id}" -f body="Fixed in commit \`abc1234\`."

# Resolve the thread
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }' -f threadId="{thread_id}"
```

### 7. Verify All Threads Resolved

After processing, re-fetch and confirm zero unresolved threads remain:

```bash
gh api graphql -f query='{
  repository(owner: "{owner}", name: "{repo}") {
    pullRequest(number: {pr_number}) {
      reviewThreads(first: 100) { nodes { isResolved } }
    }
  }
}' --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
# Should output: 0
```

## Important Rules

- Do **NOT** push as part of this workflow. Let the user decide when to push, since each push can trigger new review cycles.
- **Batch similar issues** -- threads with the same issue type (e.g., multiple "log injection" warnings) can share a single fix commit and receive the same response.
- Process conversations in file order to batch related fixes.
- Reference specific commit SHAs in responses for traceability.
- Keep responses concise but informative.
