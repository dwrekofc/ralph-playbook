<!-- description: Read-only gap analysis — compare specs against code, update plan -->
0a. Study `specs/*` with up to 250 parallel Sonnet subagents to learn the application specifications.

0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.

0c. Discover the project's source layout. Check for common structures: `src/` (JS/TS/Python), `lib/` (Python/Node), `packages/` (monorepo), `crates/` and `apps/` (Rust workspace), or a top-level Python package directory. Use whatever exists. Study shared utilities and library code (e.g., `src/lib/`, `src/utils/`, `lib/`, `packages/shared/`, or equivalent) with up to 250 parallel Sonnet subagents.
0d. For reference, the application source code is in whichever directories were discovered in 0c.

1. Study @IMPLEMENTATION_PLAN.md (if present; it may be incorrect) and use up to 500 Sonnet subagents to study existing source code (in whichever directories were discovered in 0c) and compare it against `specs/*`. Use an Opus subagent to analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted in priority of items yet to be implemented. Ultrathink. Consider searching for TODO, minimal implementations, placeholders, skipped/flaky tests, and inconsistent patterns. Study @IMPLEMENTATION_PLAN.md to determine starting point for research and keep it up to date with items considered complete/incomplete using subagents.

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first. Identify the project's shared-code location (e.g., `src/lib/` for JS/TS, a shared package or module for Python, dedicated library crates for Rust) and treat it as the standard library for shared utilities and components. Prefer consolidated, idiomatic implementations there over ad-hoc copies.

ULTIMATE GOAL: We want to achieve [project-specific goal]. Consider missing elements and plan accordingly. If an element is missing, search first to confirm it doesn't exist, then if needed author the specification at specs/FILENAME.md. If you create a new element then document the plan to implement it in @IMPLEMENTATION_PLAN.md using a subagent.
