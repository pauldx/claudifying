---
name: test-writer
description: When the user asks to write tests, add test coverage, generate test cases, or says "this needs tests" — activate this skill to generate framework-matching tests
---

# Test Writer Skill

## Goal

Generate thorough, reliable tests that match the project's existing test framework and conventions. Tests should pass on the first run.

## Constraints

- **Match the project's style exactly** — file location, naming, imports, helpers. Find existing tests first.
- **Always run the tests** after writing them. If they fail, fix them before reporting done.
- Mock external dependencies (DB, network, filesystem) but never mock the code under test.
- Cover: happy path, edge cases (null, empty, boundary), and error cases (thrown exceptions, rejected promises).

## Key Principle

Discover, don't assume. Read the project's test setup before writing a single test. The framework, directory structure, assertion library, and mock patterns are all discoverable from existing tests.

## Gotchas

- **Co-located vs `tests/` directory**: Some projects put tests next to source, others in a separate `tests/` tree. Get this wrong and the test runner won't find your tests.
- **Import paths**: Test files often need different import paths than source files. Check existing tests for the pattern.
- **Mock cleanup**: Forgetting to reset/restore mocks between tests causes cascading failures that look like real bugs.
- **Async tests**: Missing `await` on assertions is the #1 cause of tests that pass when they should fail.
- **Snapshot tests**: Don't generate snapshots unless the project already uses them — they create noisy diffs.
