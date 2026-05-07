# Ralph

Ralph is an autonomous AI development framework. It scaffolds projects with structured prompts, a headless loop script, and a methodology that takes a project from idea to working code without manual shepherding.

## The Ralph Loop

The core concept is a **headless loop** that runs Claude CLI autonomously by default:

1. `loop.sh` pipes a root `PROMPT_<mode>.md` file to `claude -p` with `--dangerously-skip-permissions` and `--output-format=stream-json`
2. Each iteration: the agent reads specs, executes a unit of work, commits, and pushes
3. The loop repeats until max iterations or manual stop
4. Raw JSON logs are saved to `logs/`; `format-stream.sh` provides readable terminal output

Prompts follow a consistent structure:
- **Phase 0** (0a-0d): Orientation — load specs, plan, and source code via parallel subagents
- **Phases 1-N**: Core task instructions for the iteration
- **Guardrails** (99999-numbered): Standing rules for file-modifying prompts (escalating 9s = higher priority)

## Idea-to-Build Flow

```
/ralph-reqs  -->  /ralph-spec  -->  ./loop.sh plan  -->  ./loop.sh
 (brainstorm)     (write specs)     (gap analysis)       (build)
```

1. **`/ralph-reqs`** — Interactive brainstorming session. Produces `.planning/reqs-XXX.md` and `.planning/decisions-XXX.md`
2. **`/ralph-spec`** — Converts finalized reqs into `specs/*.md` files (one per topic of concern)
3. **`./loop.sh plan`** — Reads specs, compares against code, generates/updates `IMPLEMENTATION_PLAN.md`
4. **`./loop.sh`** — Build loop. Implements tasks from the plan, runs tests, commits, pushes each iteration

Codex CLI uses parallel harness assets instead of the Claude root prompts:

```
$ralph-reqs  -->  $ralph-spec  -->  ./loop.sh --agent=codex plan  -->  ./loop.sh --agent=codex
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
| `templates/shared/` | Files deployed to ALL projects (loop.sh, root Claude prompts, formatters, Codex harness assets) |
| `templates/shared/claude-commands/` | Slash commands deployed to `.claude/commands/` |
| `templates/shared/codex-skills/` | Codex skills deployed to `.agents/skills/` |
| `templates/shared/harnesses/codex/` | Codex-specific loop prompt variants |
| `templates/{js,rust,blank}/` | Variant-specific overrides (AGENTS.md, config files) |
| `files/` | Legacy reference copies — do not modify |

### Conventions

- Template files use `.md` extension for storage (e.g., `package.json.md`). The `.md` is stripped during deploy unless the file is genuinely markdown.
- Root `PROMPT_<name>.md` files are Claude-specific and auto-discovered by `./loop.sh <name>`.
- `harnesses/codex/PROMPT_<name>.md` files are Codex-specific and auto-discovered by `./loop.sh --agent=codex <name>`.
- `{{PROJECT_NAME}}` placeholder in templates is replaced with the project directory name during scaffolding
- Variant files override shared files when names collide (shared copies first, variant overlays second)
- `CLAUDE.md` in scaffolded projects is a symlink to `AGENTS.md`
