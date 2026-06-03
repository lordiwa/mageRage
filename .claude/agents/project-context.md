---
project_name: mage-rage
project_type: other
generated_at: 2026-06-03T02:43:24.908Z
schema_version: 1
---

## Stack
- (none specified)

## Testing conventions
Use the testing tool that fits this stack — the project standard is to keep a fast unit suite runnable via the project's default test command, and to write a failing test before any new behavior lands. Tests live next to the code they exercise (or under a top-level tests/ tree, whichever already exists in this repo); follow the local convention rather than introducing a new one.

## Linting and formatting
Run the project's linter and formatter before every commit. If the repo ships a config (e.g., .eslintrc, ruff.toml, .prettierrc, gofmt defaults), defer to it without arguing; if no config exists yet, use the ecosystem-standard tool and add a minimal config rather than reformatting the whole tree in a drive-by change.

## Type-specific guidance
- No project-type-specific assumptions apply — default to conservative, generic engineering practice until the stack reveals itself.
- Stack details were left unspecified at intake; ask the human (or update PROJECT.md) before making non-trivial architectural decisions.
- Prefer the simplest tool that solves the problem; do not import a framework when a 20-line helper would do.
- When in doubt, write the test first — the unspecified domain is exactly the case where tests pin down intent fastest.
