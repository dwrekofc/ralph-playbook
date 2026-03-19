#!/usr/bin/env python3
"""ralph: AI development framework scaffolding and management."""

import json
import os
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from . import __version__

TEMPLATES_DIR = Path(__file__).resolve().parent / "templates"
VARIANTS = ("js", "rust", "blank", "fork", "sap")

# Variants that reuse another variant's templates
VARIANT_TEMPLATE = {"sap": "js", "fork": "blank"}

# GitHub host configurations
GITHUB_CONFIGS = {
    "default": {"host": "github.com", "owner": "dwrekofc", "private": False},
    "sap":     {"host": "github.tools.sap", "owner": "I852000", "private": True},
}

VARIANT_DIRS = {
    "js": ("specs", "src", "src/lib", ".planning"),
    "rust": ("specs", "crates", "apps", ".planning"),
    "blank": ("specs", "src", "src/lib", ".planning"),
    "fork": ("specs", ".planning"),
    "sap": ("specs", "src", "src/lib", ".planning"),
}

REGISTRY_DIR = Path.home() / ".ralph"
REGISTRY_FILE = REGISTRY_DIR / "registry.json"
PROJECT_CONFIG = ".ralph.json"

HELP_TEXT = f"""\
ralph v{__version__} — AI development framework scaffolding and management.

COMMANDS:
  ralph init <variant> [options]    Initialize current directory as a ralph project
  ralph update [options]            Update current project with latest ralph files
  ralph list                        List all registered ralph projects
  ralph sync                        Update ALL registered projects with latest ralph files

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RALPH INIT

  Scaffolds the current directory with ralph methodology files and registers
  the project in the central registry (~/.ralph/registry.json).

  Usage: ralph init <variant> [--desc "goal"] [--no-git] [--no-gh] [--private]

  Variants (required, exactly one):
    js        JS/TS stack — Bun, TypeScript, shadcn/ui, Tailwind CSS
    rust      Rust/GPUI stack — Cargo, GPUI (Zed), clippy, nextest
    blank     Bare ralph — empty AGENTS.md, no stack assumptions
    fork      Local-only — same as blank, no git init, no GitHub repo
    sap       SAP JS/TS — same as js, pushes to github.tools.sap (SAP GH Enterprise)

  Options:
    --desc "text"   Project goal string. Replaces [project-specific goal] in PROMPT_plan.md.
                    Optional. Can be added later by editing PROMPT_plan.md directly.
    --no-git        Skip git init and git commit. No .git directory created.
                    Implies --no-gh (can't push without git).
    --no-gh         Skip GitHub repo creation. Git is still initialized locally.
                    Automatic if 'origin' remote already exists.
    --private       Create a private GitHub repo (default is public).
                    SAP variant is always private regardless of this flag.

  What it does (in order):
    1. Copies shared ralph files: loop.sh, format-stream.sh, all PROMPT_*.md, IMPLEMENTATION_PLAN.md
    2. Builds .gitignore from shared base + variant-specific ignores
    3. Copies variant-specific files (AGENTS.md, config files). {{{{PROJECT_NAME}}}} is replaced with directory name.
    4. Replaces [project-specific goal] in PROMPT_plan.md if --desc provided
    5. Creates CLAUDE.md symlink -> AGENTS.md
    6. Installs .claude/commands/ slash commands (ralph-reqs, ralph-spec, ralph-manage, etc.)
    7. Creates project directories (specs/, src/, .planning/, etc. — varies by variant)
    8. Writes .ralph.json to project root (variant, timestamp, version)
    9. Registers project in ~/.ralph/registry.json
    10. Initializes git repo + initial commit (unless --no-git)
    11. Creates GitHub repo + pushes (unless --no-gh or fork variant)

  Smart defaults:
    - If .git/ already exists: skips git init, still commits new files
    - If 'origin' remote exists: skips GitHub repo creation
    - fork variant: forces --no-git --no-gh automatically

  Exit codes:
    0  Success
    1  Unknown variant, missing SAP credentials, or other error

  Examples:
    ralph init js --desc "A recipe sharing web app"
    ralph init rust --desc "A system monitor with GPUI"
    ralph init blank
    ralph init fork --desc "A private local-only experiment"
    ralph init sap --desc "An SAP Fiori companion tool"
    ralph init js --no-gh --private

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RALPH UPDATE

  Updates the current project with the latest ralph files from the installed
  version. Reads .ralph.json to auto-detect the variant — no variant argument needed.

  Usage: ralph update [--desc "goal"] [--variant <variant>]

  Options:
    --desc "text"       Update the project goal in PROMPT_plan.md.
    --variant <variant> Override or set the variant. Required only for projects
                        initialized before v0.4.0 that lack .ralph.json.
                        Valid values: js, rust, blank, fork, sap.

  What it does (in order):
    1. Reads .ralph.json from current directory to determine variant
    2. Copies shared ralph files (same as init step 1)
    3. Rebuilds .gitignore (same as init step 2)
    4. Copies variant-specific files (same as init step 3)
    5. Replaces project goal if --desc provided (same as init step 4)
    6. Recreates CLAUDE.md symlink (same as init step 5)
    7. Updates .claude/commands/ slash commands (same as init step 6)
    8. Updates .ralph.json with last_updated_at and current ralph version
    9. Updates registry entry in ~/.ralph/registry.json

  What it does NOT do:
    - Does NOT create directories (specs/, src/, etc.)
    - Does NOT touch git history or make commits
    - Does NOT create or modify GitHub repos

  Edge cases:
    - No .ralph.json found + no --variant flag: exits with error and message:
      "No .ralph.json found. This project may predate v0.4.0.
       Run: ralph update --variant <variant> to set it."
    - No .ralph.json found + --variant provided: creates .ralph.json, registers
      project, then runs update. One-time migration to the new system.
    - .ralph.json exists + --variant provided: updates the stored variant and
      applies that variant's files.

  Exit codes:
    0  Success
    1  No .ralph.json and no --variant provided, or unknown variant

  Examples:
    ralph update                        # auto-detects variant from .ralph.json
    ralph update --desc "Updated goal"  # also update project goal
    ralph update --variant js           # migrate pre-0.4.0 project

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RALPH LIST

  Prints all projects registered in ~/.ralph/registry.json.

  Usage: ralph list

  Output format (one line per project):
    <variant>  <ralph_version>  <last_updated>  <path>

  If a registered path no longer exists on disk, it is marked with [missing].
  No options or flags.

  Exit codes:
    0  Success (even if registry is empty or has missing paths)

  Examples:
    ralph list

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RALPH SYNC

  Updates ALL registered projects with the latest ralph files. Equivalent to
  running `ralph update` in every project directory listed in the registry.
  Run this after `brew upgrade ralph` to propagate changes everywhere.

  Usage: ralph sync

  What it does:
    1. Loads ~/.ralph/registry.json
    2. For each registered project:
       a. Checks path exists on disk (warns and skips if not)
       b. Checks .ralph.json exists (warns and skips if not)
       c. Changes to project directory and runs update logic
       d. Prints status: "Updated: <path> (<variant>)"
    3. Prints summary: "Updated N/M projects. S skipped."

  Edge cases:
    - Registry file missing: prints "No projects registered. Run ralph init first."
    - Path doesn't exist: prints "Skipped (not found): <path>" and continues
    - .ralph.json missing in project: prints "Skipped (no .ralph.json): <path>" and continues
    - All projects are skipped: exits 0 with summary showing 0 updated

  Exit codes:
    0  Always (individual project failures are warnings, not fatal)

  Examples:
    ralph sync

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FILES:
  .ralph.json              Per-project config (variant, timestamps, version). Created by ralph init.
                           Located in the project root. Added to .gitignore automatically.
  ~/.ralph/registry.json   Central registry of all ralph projects. Created automatically.

WORKFLOW:
  ralph init js --desc "goal"   ->  scaffold new project
  ralph update                  ->  update current project after brew upgrade
  ralph list                    ->  see all ralph projects
  ralph sync                    ->  update every project after brew upgrade
"""


# ─── Registry helpers ───────────────────────────────────────────────

def load_registry() -> dict:
    """Load the central registry. Returns empty structure if missing."""
    if REGISTRY_FILE.exists():
        return json.loads(REGISTRY_FILE.read_text())
    return {"projects": []}


def save_registry(registry: dict) -> None:
    """Save the central registry, creating ~/.ralph/ if needed."""
    REGISTRY_DIR.mkdir(parents=True, exist_ok=True)
    REGISTRY_FILE.write_text(json.dumps(registry, indent=2) + "\n")


def register_project(path: str, variant: str) -> None:
    """Add or update a project entry in the registry."""
    registry = load_registry()
    now = datetime.now(timezone.utc).isoformat()
    abs_path = str(Path(path).resolve())

    # Find existing entry by path
    for project in registry["projects"]:
        if project["path"] == abs_path:
            project["variant"] = variant
            project["last_updated_at"] = now
            project["ralph_version"] = __version__
            save_registry(registry)
            return

    # New entry
    registry["projects"].append({
        "path": abs_path,
        "variant": variant,
        "initialized_at": now,
        "last_updated_at": now,
        "ralph_version": __version__,
    })
    save_registry(registry)


# ─── Project config helpers ─────────────────────────────────────────

def read_project_config(dest: Path) -> dict | None:
    """Read .ralph.json from a project directory. Returns None if missing."""
    config_path = dest / PROJECT_CONFIG
    if config_path.exists():
        return json.loads(config_path.read_text())
    return None


def write_project_config(dest: Path, variant: str, is_init: bool = False) -> None:
    """Write or update .ralph.json in the project directory."""
    config_path = dest / PROJECT_CONFIG
    now = datetime.now(timezone.utc).isoformat()

    if config_path.exists() and not is_init:
        config = json.loads(config_path.read_text())
        config["variant"] = variant
        config["last_updated_at"] = now
        config["ralph_version"] = __version__
    else:
        config = {
            "variant": variant,
            "initialized_at": now,
            "ralph_version": __version__,
        }

    config_path.write_text(json.dumps(config, indent=2) + "\n")


# ─── File operations (unchanged from original) ─────────────────────

def check_sap_credentials() -> None:
    """Verify SAP SSH key and gh CLI auth before scaffolding."""
    ssh_key = Path.home() / ".ssh" / "id_ed25519_sap"
    if not ssh_key.exists():
        print("Error: SAP SSH key not found at ~/.ssh/id_ed25519_sap")
        print("Set up your SAP SSH key before running ralph init sap.")
        sys.exit(1)

    result = subprocess.run(
        ["gh", "auth", "status", "--hostname", "github.tools.sap"],
        capture_output=True,
    )
    if result.returncode != 0:
        print("Error: Not authenticated to github.tools.sap via gh CLI.")
        print("Run: gh auth login --hostname github.tools.sap")
        sys.exit(1)


def copy_shared_files(dest: Path) -> None:
    """Copy shared template files into dest directory."""
    shared = TEMPLATES_DIR / "shared"

    # Copy fixed files + all PROMPT_*.md files (auto-discovered)
    fixed_files = ["loop.sh", "format-stream.sh", "IMPLEMENTATION_PLAN.md"]
    prompt_files = sorted(f.name for f in shared.glob("PROMPT_*.md"))
    for name in fixed_files + prompt_files:
        src = shared / name
        if src.exists():
            shutil.copy2(src, dest / name)

    # Make scripts executable
    for script in ("loop.sh", "format-stream.sh"):
        script_path = dest / script
        if script_path.exists():
            script_path.chmod(script_path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)

    # Copy .claude/commands/ slash commands
    commands_src = shared / "claude-commands"
    if commands_src.is_dir():
        commands_dest = dest / ".claude" / "commands"
        commands_dest.mkdir(parents=True, exist_ok=True)
        for cmd_file in commands_src.iterdir():
            if cmd_file.is_file():
                shutil.copy2(cmd_file, commands_dest / cmd_file.name)


def build_gitignore(dest: Path, variant: str) -> None:
    """Build .gitignore from base + variant-specific ignores."""
    parts = []

    base = TEMPLATES_DIR / "shared" / "gitignore_base.md"
    if base.exists():
        parts.append(base.read_text())

    template_variant = VARIANT_TEMPLATE.get(variant, variant)
    variant_gi = TEMPLATES_DIR / template_variant / "gitignore.md"
    if variant_gi.exists():
        parts.append(variant_gi.read_text())

    (dest / ".gitignore").write_text("\n".join(parts))


def copy_variant_files(dest: Path, variant: str, project_name: str) -> None:
    """Copy variant-specific template files into dest directory."""
    template_variant = VARIANT_TEMPLATE.get(variant, variant)
    variant_dir = TEMPLATES_DIR / template_variant

    for src_file in variant_dir.iterdir():
        if not src_file.is_file():
            continue

        name = src_file.name

        # gitignore.md is handled separately
        if name == "gitignore.md":
            continue

        # Files that are genuinely .md and should keep their name
        KEEP_MD = ("AGENTS.md", "IMPLEMENTATION_PLAN.md")
        if name in KEEP_MD or (name.startswith("PROMPT_") and name.endswith(".md")):
            target_name = name
        # other .md files: strip the .md suffix (package.json.md -> package.json)
        elif name.endswith(".md"):
            target_name = name[:-3]  # strip .md
        else:
            target_name = name

        content = src_file.read_text()
        content = content.replace("{{PROJECT_NAME}}", project_name)
        (dest / target_name).write_text(content)


def replace_project_goal(dest: Path, desc: str) -> None:
    """Replace [project-specific goal] placeholder in PROMPT_plan.md."""
    prompt_plan = dest / "PROMPT_plan.md"
    if prompt_plan.exists():
        content = prompt_plan.read_text()
        content = content.replace("[project-specific goal]", desc)
        prompt_plan.write_text(content)


def create_symlink(dest: Path) -> None:
    """Create CLAUDE.md -> AGENTS.md symlink."""
    link = dest / "CLAUDE.md"
    if link.exists() or link.is_symlink():
        link.unlink()
    link.symlink_to("AGENTS.md")


def create_dirs(dest: Path, variant: str) -> None:
    """Create standard project directories for the given variant."""
    for d in VARIANT_DIRS.get(variant, ("specs", "src")):
        (dest / d).mkdir(parents=True, exist_ok=True)


def git_init(dest: Path, variant: str) -> None:
    """Initialize git repo and make initial commit."""
    subprocess.run(["git", "init"], cwd=dest, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=dest, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", f"init: ralph {variant}"],
        cwd=dest,
        check=True,
        capture_output=True,
    )


def github_create(dest: Path, project_name: str, variant: str, private_override: bool = False) -> None:
    """Create GitHub repo and push."""
    config = GITHUB_CONFIGS.get(variant, GITHUB_CONFIGS["default"])
    repo_name = f"{config['owner']}/{project_name}"
    is_private = private_override or config["private"]
    visibility = "--private" if is_private else "--public"

    env = os.environ.copy()
    if config["host"] != "github.com":
        env["GH_HOST"] = config["host"]

    subprocess.run(
        [
            "gh", "repo", "create", repo_name,
            visibility,
            "--source=.",
            "--remote=origin",
            "--push",
        ],
        cwd=dest,
        check=True,
        env=env,
    )


def has_git_remote(dest: Path, remote: str = "origin") -> bool:
    """Check if a git remote exists."""
    result = subprocess.run(
        ["git", "remote", "get-url", remote],
        cwd=dest,
        capture_output=True,
    )
    return result.returncode == 0


# ─── Shared update logic ───────────────────────────────────────────

def run_update(dest: Path, variant: str, desc: str | None = None) -> None:
    """Run the update steps (shared between update and sync)."""
    project_name = dest.name

    print("  Copying shared Ralph files...")
    copy_shared_files(dest)

    print("  Building .gitignore...")
    build_gitignore(dest, variant)

    print(f"  Copying {variant} variant files...")
    copy_variant_files(dest, variant, project_name)

    if desc:
        print("  Setting project goal in PROMPT_plan.md...")
        replace_project_goal(dest, desc)

    print("  Creating CLAUDE.md -> AGENTS.md symlink...")
    create_symlink(dest)

    print("  Updating .ralph.json...")
    write_project_config(dest, variant)

    print("  Updating registry...")
    register_project(str(dest), variant)


# ─── Subcommands ────────────────────────────────────────────────────

def cmd_init(args: list[str]) -> None:
    """Handle: ralph init <variant> [options]"""
    import argparse
    parser = argparse.ArgumentParser(prog="ralph init", add_help=False)
    parser.add_argument("variant", nargs="?", default=None)
    parser.add_argument("--desc", default=None)
    parser.add_argument("--no-git", action="store_true", dest="no_git")
    parser.add_argument("--no-gh", action="store_true", dest="no_gh")
    parser.add_argument("--private", action="store_true")
    parsed = parser.parse_args(args)

    if parsed.variant is None:
        print("Error: variant is required.")
        print(f"Valid variants: {', '.join(VARIANTS)}")
        print("\nRun 'ralph --help' for full usage.")
        sys.exit(1)

    variant = parsed.variant
    if variant not in VARIANTS:
        print(f"Error: unknown variant '{variant}'. Choose from: {', '.join(VARIANTS)}")
        print("\nRun 'ralph --help' for full usage.")
        sys.exit(1)

    # Pre-flight credential check for SAP
    if variant == "sap":
        check_sap_credentials()

    dest = Path.cwd()
    project_name = dest.name
    no_git = parsed.no_git
    no_gh = parsed.no_gh or no_git  # --no-git implies --no-gh

    # fork variant is an alias for blank --no-git --no-gh
    if variant == "fork":
        no_git = True
        no_gh = True

    print(f"Initializing Ralph ({variant}) in {dest}")
    print(f"Project name: {project_name}")
    print()

    # Steps 1-6: shared file operations
    print("  Copying shared Ralph files...")
    copy_shared_files(dest)

    print("  Building .gitignore...")
    build_gitignore(dest, variant)

    print(f"  Copying {variant} variant files...")
    copy_variant_files(dest, variant, project_name)

    if parsed.desc:
        print("  Setting project goal in PROMPT_plan.md...")
        replace_project_goal(dest, parsed.desc)

    print("  Creating CLAUDE.md -> AGENTS.md symlink...")
    create_symlink(dest)

    # Step 7: Create directories
    dirs = VARIANT_DIRS.get(variant, ("specs", "src"))
    print(f"  Creating {', '.join(d + '/' for d in dirs)}...")
    create_dirs(dest, variant)

    # Step 8-9: Write project config + register
    print("  Writing .ralph.json...")
    write_project_config(dest, variant, is_init=True)

    print("  Registering project...")
    register_project(str(dest), variant)

    # Step 10: Git init + commit
    if no_git:
        print("  Skipping git (--no-git)...")
    elif (dest / ".git").is_dir():
        print("  Git repo detected — committing Ralph files...")
        subprocess.run(["git", "add", "-A"], cwd=dest, check=True, capture_output=True)
        subprocess.run(
            ["git", "commit", "-m", f"init: ralph {variant}"],
            cwd=dest, check=True, capture_output=True,
        )
    else:
        print("  Initializing git repo...")
        git_init(dest, variant)

    # Step 11: GitHub repo creation
    if no_gh:
        print("  Skipping GitHub repo creation...")
    elif has_git_remote(dest):
        print("  Remote 'origin' detected — skipping GitHub repo creation...")
    else:
        gh_config = GITHUB_CONFIGS.get(variant, GITHUB_CONFIGS["default"])
        print(f"  Creating GitHub repo {gh_config['owner']}/{project_name} on {gh_config['host']}...")
        github_create(dest, project_name, variant, private_override=parsed.private)

    print()
    print(f"Done! Ralph v{__version__} ({variant}) is ready.")
    print()
    print("Next steps:")
    print("  1. Run /ralph-reqs in Claude Code to brainstorm and define requirements")
    print("  2. Run /ralph-spec to convert requirements into Ralph specs")
    print("     (or write specs manually in specs/)")
    print("  3. Run: ./loop.sh plan        (generate implementation plan)")
    print("  4. Run: ./loop.sh             (start building)")
    print("  5. Run: ./loop.sh help        (list all available loop modes)")
    print()
    print("Slash commands installed in .claude/commands/:")
    print("  /ralph-reqs    — Interactive requirements gathering & ideation")
    print("  /ralph-spec    — Convert planning docs into Ralph specs")
    print("  /ralph-manage  — Guided setup wizard (init, update, sync)")


def cmd_update(args: list[str]) -> None:
    """Handle: ralph update [options]"""
    import argparse
    parser = argparse.ArgumentParser(prog="ralph update", add_help=False)
    parser.add_argument("--desc", default=None)
    parser.add_argument("--variant", default=None)
    parsed = parser.parse_args(args)

    dest = Path.cwd()
    config = read_project_config(dest)

    if config is None and parsed.variant is None:
        print("Error: No .ralph.json found. This project may predate v0.4.0.")
        print(f"Run: ralph update --variant <variant> to set it.")
        print(f"Valid variants: {', '.join(VARIANTS)}")
        sys.exit(1)

    if parsed.variant:
        if parsed.variant not in VARIANTS:
            print(f"Error: unknown variant '{parsed.variant}'. Choose from: {', '.join(VARIANTS)}")
            sys.exit(1)
        variant = parsed.variant
    else:
        variant = config["variant"]

    print(f"Updating Ralph ({variant}) in {dest}")
    print()

    run_update(dest, variant, desc=parsed.desc)

    print()
    print(f"Done! Ralph v{__version__} ({variant}) files updated.")


def cmd_list(args: list[str]) -> None:
    """Handle: ralph list"""
    registry = load_registry()

    if not registry["projects"]:
        print("No projects registered. Run 'ralph init' first.")
        return

    for project in registry["projects"]:
        path = project["path"]
        variant = project.get("variant", "?")
        version = project.get("ralph_version", "?")
        updated = project.get("last_updated_at", project.get("initialized_at", "?"))
        # Truncate ISO timestamp to date
        if updated and "T" in updated:
            updated = updated.split("T")[0]

        exists = Path(path).is_dir()
        marker = "" if exists else " [missing]"
        print(f"  {variant:<8} {version:<8} {updated:<12} {path}{marker}")


def cmd_sync(args: list[str]) -> None:
    """Handle: ralph sync"""
    registry = load_registry()

    if not registry["projects"]:
        print("No projects registered. Run 'ralph init' first.")
        return

    total = len(registry["projects"])
    updated = 0
    skipped = 0

    for project in registry["projects"]:
        path = Path(project["path"])

        if not path.is_dir():
            print(f"Skipped (not found): {path}")
            skipped += 1
            continue

        config = read_project_config(path)
        if config is None:
            print(f"Skipped (no .ralph.json): {path}")
            skipped += 1
            continue

        variant = config["variant"]
        print(f"\n--- {path} ---")

        # Save and restore cwd
        original_cwd = Path.cwd()
        try:
            os.chdir(path)
            run_update(path, variant)
            updated += 1
            print(f"Updated: {path} ({variant})")
        except Exception as e:
            print(f"Error updating {path}: {e}")
            skipped += 1
        finally:
            os.chdir(original_cwd)

    print(f"\nUpdated {updated}/{total} projects. {skipped} skipped.")


GLOBAL_COMMANDS = ["ralph-manage.md"]


def cmd_install_commands(args: list[str]) -> None:
    """Install global Claude Code slash commands to ~/.claude/commands/."""
    dest = Path.home() / ".claude" / "commands"
    dest.mkdir(parents=True, exist_ok=True)

    commands_src = TEMPLATES_DIR / "shared" / "claude-commands"
    installed = []

    for name in GLOBAL_COMMANDS:
        src = commands_src / name
        if src.exists():
            shutil.copy2(src, dest / name)
            installed.append(name)

    if installed:
        for name in installed:
            print(f"  Installed: ~/.claude/commands/{name}")
    else:
        print("  No global commands to install.")


# ─── Main dispatch ──────────────────────────────────────────────────

def main() -> None:
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help", "help"):
        print(HELP_TEXT)
        sys.exit(0)

    command = sys.argv[1]
    rest = sys.argv[2:]

    # Auto-install global commands on any mutating command
    if command in ("init", "update", "sync", "install-commands"):
        try:
            cmd_install_commands([])
        except Exception:
            pass  # Don't fail the main command if global install fails

    if command == "init":
        cmd_init(rest)
    elif command == "update":
        cmd_update(rest)
    elif command == "list":
        cmd_list(rest)
    elif command == "sync":
        cmd_sync(rest)
    elif command == "install-commands":
        pass  # Already ran above
    else:
        print(f"Error: unknown command '{command}'.")
        print("Valid commands: init, update, list, sync, install-commands")
        print("\nRun 'ralph --help' for full usage.")
        sys.exit(1)
