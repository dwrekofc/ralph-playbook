# Ralph

Ralph is an autonomous AI development framework. It scaffolds projects with structured prompts, a headless loop script, and a methodology that takes a project from idea to working code without manual shepherding.

## The Ralph Loop

The core concept is a **headless loop** that runs an LLM CLI autonomously:

1. `loop.sh` pipes a root `PROMPT_<mode>.md` file to `claude -p` (or `codex exec`) with permissions bypassed and stream-JSON output
2. Each iteration: the agent reads specs, executes a unit of work, commits, and pushes
3. The loop repeats until max iterations or manual stop
4. Raw JSON logs are saved to `logs/`; `format-stream.sh` / `format-codex-stream.sh` provides readable terminal output

Prompts follow a consistent structure:
- **Phase 0** (0a-0d): Orientation — load specs, source code, and reports via parallel subagents
- **Phases 1-N**: Core task instructions for the iteration
- **Guardrails** (99999-numbered): Standing rules for file-modifying prompts (escalating 9s = higher priority)

## Idea-to-Build Flow

Two paths, picked based on how rigorous the spec phase should be:

**Standard path** (rigorous, JTBD-driven):
```
/ralph-reqs  →  /ralph-spec  →  ./loop.sh auto 3
 (brainstorm)   (write specs)   (build + eval)
```

**Fast path** (quick prototype):
```
/ralph-rapid-prototype  →  ./loop.sh auto 3
 (PRODUCT_SPEC.md + CONSTRAINTS.md)
```

**Cleanroom research** (optional pre-step, when working from existing code or external references):
```
put sources in src/ or refs/  →  ./cleanroom-loop.sh  →  review docs/cleanroom/research/  →  /ralph-reqs (or rapid-prototype)
```

In `auto` mode, the build agent is configurable (`--agent=claude|codex`), but the **evaluator is always Codex** with `gpt-5.5` and `model_reasoning_effort=high` — independent grader regardless of build agent.

Codex CLI uses parallel harness assets instead of the Claude root prompts:

```
$ralph-reqs  →  $ralph-spec  →  ./loop.sh --agent=codex auto 3
```

Codex prompts live under `harnesses/codex/` in scaffolded projects. Do not make Claude prompts generic when adding Codex support; create or update the Codex variant instead.

## This Repository

Ralph has two parts: the **scaffolding CLI** (`ralph-init`) and the **template files** it deploys.

### Key References

| Path | Description |
|------|-------------|
| `README.md` | Full Ralph Playbook documentation |
| `ROADMAP.md` | Product backlog (JTBDs and user stories) |
| `ralph_init/cli.py` | Scaffolding CLI entry point |
| `templates/shared/` | Files deployed to ALL projects (loop.sh, cleanroom-loop.sh, root prompts, templates, formatters) |
| `templates/shared/claude-commands/` | Slash commands deployed to `.claude/commands/` |
| `templates/shared/codex-skills/` | Codex skills deployed to `.agents/skills/` |
| `templates/shared/harnesses/codex/` | Codex-specific loop prompt variants |
| `templates/_archive/` | Archived templates (v1 prompts, ralph-v2-team, ralph-quickie) — kept for history, never deployed |
| `templates/{js,rust,blank}/` | Variant-specific overrides (AGENTS.md, config files) |
| `archive/` | Archived project artifacts (e.g., the old benchmarks/ harness) |
| `files/` | Legacy reference copies — do not modify |

### Conventions

- Template files use `.md` extension for storage (e.g., `package.json.md`). The `.md` is stripped during deploy unless the file is genuinely markdown.
- Root `PROMPT_<name>.md` files are Claude-specific and auto-discovered by `./loop.sh <name>`.
- `harnesses/codex/PROMPT_<name>.md` files are Codex-specific and auto-discovered by `./loop.sh --agent=codex <name>`.
- `{{PROJECT_NAME}}` placeholder in templates is replaced with the project directory name during scaffolding.
- Variant files override shared files when names collide (shared copies first, variant overlays second).
- `CLAUDE.md` in scaffolded projects is a symlink to `AGENTS.md`.
- The fork is intentionally diverged from upstream `ClaytonFarr/ralph-playbook`; do not auto-merge upstream changes.
