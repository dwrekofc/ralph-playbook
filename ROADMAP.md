# Ralph Workflow Improvements — Goals & User Stories

## Vision
Evolve ralph-init and the loop workflow from a basic scaffolding tool into a comprehensive, multi-modal autonomous development framework that supports the full lifecycle: spec writing, planning, building, and auditing — with readable output, multiple tech stacks, and extensibility to other AI CLIs.

---

## JTBD 1: Readable Loop Output ✅ Done
**When** I run the Ralph loop headlessly, **I want** human-readable formatted output in my terminal with full JSON logs saved to disk, **so that** I can monitor progress in real time without parsing raw JSON.

### User Stories
- As a developer, I want `loop.sh` to pipe Claude's stream-json through a formatter that shows thinking, text, tool calls, and results with color coding, so I can follow what Ralph is doing at a glance.
- As a developer, I want every loop iteration to save the raw JSON stream to a timestamped log file in `logs/`, so I can replay or debug any iteration later.
- As a developer, I want `format-stream.sh` to be included in every `ralph-init` scaffold, so formatted output works out of the box without manual setup.
- As a developer, I want `logs/` to be gitignored by default, so log files don't pollute my repo.

### Reference Implementation
- `/Volumes/CORE/dev/projects/gpui-workbench/loop.sh` — working loop with tee + format-stream.sh
- `/Volumes/CORE/dev/projects/gpui-workbench/format-stream.sh` — working formatter
- https://www.ytyng.com/en/blog/claude-stream-json-jq/ — jq streaming technique

---

## JTBD 2: SAP Project Variant ✅ Done
**When** I start a new SAP project, **I want** to run `ralph-init sap` to scaffold a JS/Bun project that pushes to my SAP GitHub account using SAP-specific SSH credentials, **so that** I can bootstrap SAP projects as quickly as my personal ones.

### User Stories
- As a developer, I want `ralph-init sap` to immediately check for SAP SSH credentials on the machine before doing anything else, so I get a clear error instead of a half-scaffolded project if credentials are missing.
- As a developer, I want the SAP variant to use the same JS/Bun/TypeScript stack as the `js` variant, so I don't have to maintain two separate tech stack configs.
- As a developer, I want `ralph-init sap` to create the GitHub repo under my SAP account (using SAP SSH identity), so the remote is correctly configured from the start.

### Open Questions
- SAP GitHub account name: TBD
- SAP SSH host alias (from `~/.ssh/config`): TBD
- Are there any SAP-specific files (e.g., `.saprc`, deploy configs) that should be included?

---

## JTBD 3: Custom Loop Prompt Creator ✅ Done
**When** I need a new Ralph loop mode for a task that doesn't fit plan/build/spec/audit, **I want** a command that helps me create a well-structured loop prompt following Ralph conventions, **so that** I can extend the loop to any repeatable task without starting from scratch.

I also want this current working dir to have it's own .claude/ folder and a CLAUDE.md file that explains how to use this ralph project, what it's about, what the workflow is, etc. the custom prompt creator should be installed in THIS project's .claude folder as well so from this project I can create new prompts that can be deployed into the various ralph-init setups

### User Stories
- As a developer, I want a `/ralph-new-prompt` slash command that reads the existing loop prompts (plan, build) as examples and helps me write a new `PROMPT_<name>.md` for any task.
- As a developer, I want the command to explain what makes a good loop prompt (structure, guardrails, context loading, exit conditions) so the generated prompt follows Ralph best practices.
- As a developer, I want the new prompt to be automatically recognized by `loop.sh` (either via convention or by updating the mode parser).
- as a dev I can run this command in the source 'ralph' project to create a new loop prompt that gets deployed as a shared tempalte to other projects that get iitialized with ralph OR I can run it locally in an existing project that has been ralph-init already to create a new loop prompt as needed at a project level

### Examples of Custom Loop Prompts
- **Migration**: Read old API, read new API spec, migrate one module per iteration
- **Documentation**: Read code, write or update docs for one module per iteration
- **Testing**: Read specs + code, write missing tests for one component per iteration
- **Refactoring**: Read code smells list, refactor one area per iteration

---

## JTBD 4: Spec Writing Loop ✅ Done
**When** I have planning docs and want to generate or refine Ralph specs, **I want** a headless loop mode that iteratively writes, improves, and validates specs, **so that** I don't have to manually shepherd the spec creation process.

### User Stories
- As a developer, I want `./loop.sh spec` to run a loop that reads planning docs and creates initial spec drafts if none exist yet from the reqs.md file in .planning/.
- As a developer, I want subsequent spec loop iterations to refine existing specs — filling gaps, improving acceptance criteria, resolving inconsistencies between specs.
- As a developer, I want the spec loop to compare specs against any existing code (if the project isn't greenfield) and update specs to reflect reality where appropriate.
- As a developer, I want each spec loop iteration to commit its changes so I can review the diff and revert if a spec goes in the wrong direction.

### Relationship to Existing `PROMPT_spec.md`
- `PROMPT_spec.md` (interactive) = human-in-the-loop, requires topic approval → used via `/ralph-spec` slash command. when I run this command, I want it to identify the outstanding questions from the reqs.md and use 'askusertool' to gather the necessary clarity and help me make a decision so that it can write the best spec
- `PROMPT_spec_loop.md` (headless) = autonomous, iterates on existing specs → used via `./loop.sh spec`. 
- Both produce the same output format (`specs/<topic>.md`)

### Relationship to reqs.md
**this is relevant to both interactive AND headless modes** when I run the 'spec' prompt I want it to only look for active reqs.md & decisions.md docs in the .planning/ folder and not look for anything else. don't instruct it to read all docs, just the oldest reqs/decisions docs with the smallest increment. there may be multiple (reqs001, reqs002, etc.) and it should only look for the oldest one with the smallest increment. the prompt should explicitly state NOT to look in the archive folder.


---

## JTBD 5: Code Audit Loop
**When** the build loop has completed a set of tasks, **I want** an audit loop that systematically reviews the code against specs and acceptance criteria, **so that** I can verify completeness and correctness without manually reading every file.

### User Stories
- As a developer, I want `./loop.sh audit` to run a loop that picks one component/area per iteration, reads its spec, and verifies the implementation meets all requirements and acceptance criteria.
- As a developer, I want the audit loop to check for: missing functionality, placeholder/stub code, failing tests, spec-code mismatches, and undocumented deviations.
- As a developer, I want audit findings documented (either in `AUDIT_LOG.md` or `IMPLEMENTATION_PLAN.md`) so they can be addressed in subsequent build iterations.
- As a developer, I want the audit loop to commit its findings so I have a clear record of what was reviewed and what issues were found.

---

## JTBD 6: Extended Loop Modes in `loop.sh` ✅ Done
**When** I have multiple loop prompt types (plan, build, spec, audit, and custom), **I want** `loop.sh` to support all of them via simple mode arguments, **so that** I can switch between modes without editing scripts.

### User Stories
- As a developer, I want `./loop.sh <mode> [max_iterations]` to work for any mode: `plan`, `build` (default), `spec`, `audit`, and any custom `PROMPT_<name>.md`.
- As a developer, I want `./loop.sh help` to print all available modes with one-line descriptions.
- As a developer, I want `loop.sh` to auto-discover custom prompts: if `PROMPT_<name>.md` exists, `./loop.sh <name>` should work without code changes.

---

## JTBD 7: Rust Bootstrap from Live Project (Deferred)
**When** the gpui-workbench project matures through several build cycles, **I want** to backport its battle-tested prompts, AGENTS.md, and crate structure into the `ralph-init rust` template, **so that** future Rust projects start with proven patterns instead of minimal stubs.

### User Stories
- As a developer, I want the rust variant's PROMPT_build.md to include lessons learned from gpui-workbench (reference handling, adoption dispositions, acceptance criteria checks).
- As a developer, I want the rust variant's AGENTS.md to include real build/test/lint commands that work for a Cargo workspace with GPUI.
- As a developer, I want the rust variant to scaffold a proper workspace structure (crates/, apps/) with a working Cargo.toml.

**Status**: Deferred until gpui-workbench has completed several build cycles.

---

## JTBD 8: Multi-CLI Support (Deferred)
**When** I want to run the Ralph loop with Google Gemini CLI or OpenAI Codex CLI instead of Claude, **I want** the loop and formatter to support multiple AI CLI backends, **so that** I can use Ralph's methodology with any capable AI.

### User Stories
- As a developer, I want `loop.sh` to accept a `--cli` flag (or read from a config) to switch between `claude`, `gemini`, and `codex` backends.
- As a developer, I want `format-stream.sh` to handle different JSON stream formats from each CLI, or have per-CLI formatter scripts.
- As a developer, I want the loop prompts to work across CLIs with minimal modification (the prompts describe tasks, not Claude-specific features).

**Status**: Deferred until Gemini CLI and Codex CLI have stable headless streaming formats.

---

## JTBD 9: update PROMPT_spec.md & reqs workflow ✅ Done
when I run the PROMPT_spec.md prompt I want it to only look for active reqs.md & decisions.md docs in the .planning/ folder and not look for anything else. don't instruct it to read all docs, just the oldest reqs/decisions docs with the smallest increment. there may be multiple (reqs001, reqs002, etc.) and it should only look for the oldest one with the smallest increment. the prompt should explicitly state NOT to look in the archive folder.

---

# Ralph v2 Beta

Parallel evolution motivated by Anthropic's harness design findings: product-level planning beats micro-specs, separate evaluator agents improve quality, back-pressure keeps agents on track.

## JTBD 10: v2 Product-Level Planning ⏳ Beta
**When** I start a new project, **I want** to define product requirements and hard constraints in a single interactive session, **so that** the AI builds what I asked for without micro-detailed implementation plans.

### User Stories
- As a developer, I want `/ralph-v2-product` to walk me through a structured checklist (tech stack, DB, auth, deployment) and generate PRODUCT_SPEC.md + CONSTRAINTS.md.
- As a developer, I want the product spec to contain features, user stories, success criteria, and eval rubrics — NOT implementation details.
- As a developer, I want the agent to expand my input faithfully — no scope inflation, no bonus features.

---

## JTBD 11: Adversarial Evaluation System ⏳ Beta
**When** the generator builds features, **I want** a separate evaluator agent to test and grade the implementation, **so that** I get honest quality assessment instead of self-praise.

### User Stories
- As a developer, I want 3 eval strategies I can benchmark: dedicated eval prompt, Codex cross-review, and Claude Code agent teams.
- As a developer, I want `./v2-loop.sh auto N` to alternate between build and eval cycles with configurable pass thresholds.
- As a developer, I want `./v2-loop.sh auto N --eval=codex` to use Codex (GPT-5.4) as the evaluator for true model separation.
- As a developer, I want a ralph-v2-team skill that orchestrates generator + evaluator as Claude Code agent teammates.

---

## JTBD 12: Back-Pressure Scaffolding ⏳ Beta
**When** the loop runs, **I want** automated build/lint/test/typecheck checks after every feature, **so that** the agent catches and fixes issues immediately instead of accumulating tech debt.

### User Stories
- As a developer, I want back-pressure commands auto-generated per tech stack (JS: eslint+vitest+tsc, Rust: clippy+cargo test+cargo fmt, etc.).
- As a developer, I want the generator to enforce TDD: write tests first (red), implement (green), refactor.
- As a developer, I want the enhanced blank variant to infer tooling from CONSTRAINTS.md (supports C++, Python, Go, etc.).

---

## JTBD 13: Benchmark Suite ⏳ Beta
**When** I want to compare eval strategies, **I want** a benchmark runner with test projects and a dashboard, **so that** I can determine which approach produces the best results.

### User Stories
- As a developer, I want 3 benchmark projects: JS recipe app, Rust CSV tool, C++ snake game.
- As a developer, I want `./benchmarks/run-bench.sh all all 3` to run the full 3x3 matrix (9 runs).
- As a developer, I want an HTML dashboard that shows pass rate, time, cost, and quality scores with charts.
- As a developer, I want to track: cost, time, quality score, automated metrics, and bug discovery rate.

---

## JTBD 14: Agent Teams Skill ⏳ Beta
**When** I want generator and evaluator running in parallel, **I want** a skill that uses Claude Code's native agent teams feature, **so that** I can compare parallel execution against sequential loop iteration.
