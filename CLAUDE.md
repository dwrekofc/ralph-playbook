# Ralph

Ralph is an autonomous AI development framework. It scaffolds projects with structured prompts, a headless loop script, and a methodology that takes a project from idea to working code without manual shepherding.

## The Ralph Loop

The core concept is a **headless loop** that runs Claude CLI autonomously:

1. `loop.sh` pipes a `PROMPT_<mode>.md` file to `claude -p` with `--dangerously-skip-permissions` and `--output-format=stream-json`
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

## This Repository

Ralph has two parts: the **scaffolding CLI** (`ralph-init`) and the **template files** it deploys.

### Key References

| Path | Description |
|------|-------------|
| `README.md` | Full Ralph Playbook documentation |
| `ROADMAP.md` | Product backlog (JTBDs and user stories) |
| `ralph_init/cli.py` | Scaffolding CLI entry point |
| `templates/shared/` | Files deployed to ALL projects (loop.sh, PROMPT_*.md, format-stream.sh) |
| `templates/shared/claude-commands/` | Slash commands deployed to `.claude/commands/` |
| `templates/{js,rust,blank}/` | Variant-specific overrides (AGENTS.md, config files) |
| `files/` | Legacy reference copies — do not modify |

### Conventions

- Template files use `.md` extension for storage (e.g., `package.json.md`). The `.md` is stripped during deploy unless the file is genuinely markdown.
- `PROMPT_<name>.md` naming enables auto-discovery by `loop.sh` — any prompt matching this pattern becomes a mode: `./loop.sh <name>`
- `{{PROJECT_NAME}}` placeholder in templates is replaced with the project directory name during scaffolding
- Variant files override shared files when names collide (shared copies first, variant overlays second)
- `CLAUDE.md` in scaffolded projects is a symlink to `AGENTS.md`
