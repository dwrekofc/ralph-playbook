---
name: ralph-this
description: Create an approved, isolated Ralph build thread for a specific outcome. Use when the user wants to turn a focused project goal into a custom generator/evaluator loop, runner-backed workflow, recovery lane, bulk lane, branch/worktree-isolated thread, or other runnable build thread.
user-invocable: true
argument-hint: <outcome-oriented build goal>
---

# ralph-this: Outcome Build Thread

Turn one outcome-oriented goal into an approved, isolated, runnable build thread. Works in any project, Ralph or not.

The output is a project-local lane under `.ralph/threads/<thread-slug>/` with its own brief, prompts, runner, status, failure digest, and handoff template.

## Non-Negotiables

- Explore before asking questions.
- Ask for approval before writing files, creating branches, creating worktrees, or running the thread.
- Always create a handoff template.
- Default stop condition is iteration limit unless the user specifies otherwise.
- Offer Git isolation options for every thread.
- Offer optional enhancements; do not force the same package every time.
- Keep the thread isolated to the stated outcome. Do not expand scope.

## Phase 0: Read-Only Project Orientation

Before asking the user anything, inspect the project enough to understand:

- What the project does
- Existing build/test/lint commands
- Existing agent docs such as `AGENTS.md`, `CLAUDE.md`, `CONSTRAINTS.md`, `PRODUCT_SPEC.md`, `specs/`, or `.ralph.json`
- Current Git state, current branch, and whether worktrees are already in use
- Existing loop scripts, runner scripts, dashboards, status docs, handoff docs, or eval reports

Use read-only commands only in this phase. Do not mutate tracked files.

## Phase 1: Clarify The Outcome

If the user's goal is missing important intent, ask concise questions with `request_user_input`. Ask only for choices that materially change the thread.

Lock these fields:

- Outcome: the concrete thing that should be true when done
- Business value: why this thread matters
- In scope: what the thread may touch
- Out of scope: what it must not touch
- Proof of done: what evidence proves success
- Iteration limit: default to 5 if the user does not specify one
- Stop condition: default to iteration limit unless user chooses pass-based, failure-based, or human-decision-based stopping

## Phase 2: Propose Thread Shape

Choose the smallest thread shape that can prove the outcome:

- **Simple Feature Loop**: generator -> evaluator -> handoff
- **Checkpoint/State Loop**: advances a living checkpoint document and evaluates against it
- **Runner-Proven Loop**: generator -> runner command -> failure digest -> generator retry
- **Recovery/Debug Loop**: isolates unstable behavior and loops on failing proof until promoted or quarantined
- **Bulk/Production Lane**: monitors and advances a long-running operational lane with explicit completion rules
- **Multi-Lane Orchestrator**: proposes several coordinated lanes only when the goal clearly requires parallel or independent tracks

If more than one shape fits, recommend one and explain the tradeoff in one sentence.

## Phase 3: Offer Git Isolation

Always offer Git isolation before creating the lane:

- **Current branch**: tiny, low-risk work in the existing working tree
- **New branch**: one isolated thread in the same working directory
- **Git worktree**: recommended for parallel threads, long-running loops, or work likely to conflict with active edits
- **No Git isolation**: only if there is no Git repo or the user explicitly declines

Recommend worktrees for multi-lane, bulk, recovery, or risky runner-backed work. Do not create or switch branches/worktrees until the user approves.

## Phase 4: Offer Enhancements

Ask which optional enhancements to include with `request_user_input`. Useful options:

- **Progress Snapshot**: compact status file with iteration, latest result, blocker, and next action
- **Decision Ledger**: records owner/agent decisions and "do not revisit" calls
- **Failure Digest**: business-readable summary of proof failures and the next retry target
- **Thread Handoff Pack**: final summary of changes, evidence, risks, and next thread
- **Visibility Dashboard**: lightweight status surface for longer threads
- **Master Orchestrator**: coordinates multiple lanes and aggregates status

Brief and handoff are mandatory. Everything else is user-selected.

## Phase 5: Approval Brief

Before writing anything, present the Thread Brief and ask for approval with `request_user_input`.

The brief must include:

- Thread name and slug
- Outcome
- Business value
- In scope / out of scope
- Proof of done
- Thread shape
- Iteration limit and stop condition
- Git isolation recommendation and selected option
- Selected enhancements
- Files/directories the lane will create
- Commands the user will run after creation

If the user rejects or revises the brief, update the brief and ask again. Do not mutate until approved.

## Phase 6: Create The Runnable Lane

After approval, create `.ralph/threads/<thread-slug>/` with:

- `THREAD_BRIEF.md`
- `PROMPT_generate.md`
- `PROMPT_eval.md`
- `run-thread.sh`
- `STATUS.md`
- `HANDOFF.md`
- `FAILURE_DIGEST.md`
- `DECISIONS.md` if selected
- `dashboard/` if selected
- `orchestrator/` if selected

Make `run-thread.sh` executable. It should:

- Accept an optional max iteration argument, defaulting to the approved iteration limit
- Run the selected generator/evaluator/proof sequence
- Write logs under `.ralph/threads/<thread-slug>/logs/`
- Update status artifacts after each iteration
- Stop at the approved stop condition
- Use Codex headless execution when it calls Codex: `codex exec --json --model gpt-5.5 --config model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox -`
- Preserve raw JSONL logs and provide readable summaries when a formatter exists

For runner-proven, recovery, bulk, or orchestrated lanes, include the proof command(s) in the brief and runner. If the proof command is unknown, create a placeholder section in the brief and ask the user before running the lane.

## Phase 7: Git Isolation Setup

If approved:

- Current branch: record the current branch in `THREAD_BRIEF.md`
- New branch: create a branch named `ralph/<thread-slug>` unless the user chose another name
- Worktree: create a sibling worktree named `<repo>-ralph-<thread-slug>` on branch `ralph/<thread-slug>` unless the user chose another path/name
- No Git isolation: record why isolation was skipped

Never discard, reset, or overwrite existing user changes. If dirty files conflict with the requested isolation, pause and ask.

## Phase 8: Final Response

After creating the lane, report:

- Created thread path
- Selected Git isolation
- How to run it
- What it will do first
- Where to read status and handoff

Do not run the lane unless the user explicitly approved running it too.
