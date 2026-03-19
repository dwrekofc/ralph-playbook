#!/usr/bin/env python3
"""ralph-init: Bootstrap projects with the Ralph Playbook methodology."""

import argparse
import os
import shutil
import stat
import subprocess
import sys
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

HELP_TEXT = """\
ralph-init — Bootstrap the current directory with the Ralph Playbook methodology.

USAGE:
    ralph-init <variant> [--desc "project goal"]
    ralph-init <variant> --update [--desc "project goal"]

VARIANTS:
    js        JS/TS stack: Bun runtime, TypeScript, shadcn/ui, Tailwind CSS
    rust      Rust/GPUI stack: Cargo, GPUI (Zed), clippy, nextest
    blank     Bare Ralph setup: empty AGENTS.md template, no stack assumptions
    fork      Private fork: same as blank, local git only (no GitHub repo)
    sap       SAP JS/TS stack: Same as js, pushes to github.tools.sap (SAP GH Enterprise)

OPTIONS:
    --desc    Project goal — replaces [project-specific goal] in PROMPT_plan.md
    --update  Update an existing repo with latest Ralph files (skips git init,
              directory creation, and GitHub repo creation)

EXAMPLES:
    cd my-web-app
    ralph-init js --desc "A recipe sharing web app"

    cd my-desktop-app
    ralph-init rust --desc "A system monitor with GPUI"

    cd my-project
    ralph-init blank

    cd my-private-project
    ralph-init fork --desc "A private local-only project"

    cd my-sap-app
    ralph-init sap --desc "An SAP Fiori companion tool"

    # Update an existing ralph project with latest files
    cd my-existing-project
    ralph-init rust --update

WHAT IT DOES:
    1. Copies Ralph files into the current directory:
       loop.sh, format-stream.sh, all PROMPT_*.md prompts, IMPLEMENTATION_PLAN.md
    2. Copies variant-specific files (AGENTS.md, config files, etc.)
    3. Installs .claude/commands/ with slash commands:
       /ralph-reqs, /ralph-spec, /ralph-plan, /ralph-build
    4. Creates CLAUDE.md symlink -> AGENTS.md
    5. Creates project directories (specs/, src/ or crates/, etc.)
    6. Initializes git repo with initial commit
    7. Creates GitHub repo and pushes (unless variant is 'fork'):
       - js/rust/blank: public repo on github.com (dwrekofc/<dir-name>)
       - sap: private repo on github.tools.sap (I852000/<dir-name>)
       - fork: local git only, no GitHub repo

    With --update, only steps 1-4 are performed. Existing project directories,
    git history, and GitHub repo are left untouched.

ALL CONTENT LIVES IN EDITABLE .md FILES:
    Templates are in the ralph fork at ralph_init/templates/<variant>/.
    Edit them in any text editor — no code changes needed.
"""


def check_sap_credentials() -> None:
    """Verify SAP SSH key and gh CLI auth before scaffolding."""
    ssh_key = Path.home() / ".ssh" / "id_ed25519_sap"
    if not ssh_key.exists():
        print("Error: SAP SSH key not found at ~/.ssh/id_ed25519_sap")
        print("Set up your SAP SSH key before running ralph-init sap.")
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


VARIANT_DIRS = {
    "js": ("specs", "src", "src/lib", ".planning"),
    "rust": ("specs", "crates", "apps", ".planning"),
    "blank": ("specs", "src", "src/lib", ".planning"),
    "fork": ("specs", ".planning"),
    "sap": ("specs", "src", "src/lib", ".planning"),
}


def create_dirs(dest: Path, variant: str) -> None:
    """Create standard project directories for the given variant."""
    for d in VARIANT_DIRS.get(variant, ("specs", "src")):
        (dest / d).mkdir(parents=True, exist_ok=True)


def git_init(dest: Path, variant: str) -> None:
    """Initialize git repo and make initial commit."""
    subprocess.run(["git", "init"], cwd=dest, check=True, capture_output=True)
    subprocess.run(["git", "add", "-A"], cwd=dest, check=True, capture_output=True)
    subprocess.run(
        ["git", "commit", "-m", f"init: ralph-init {variant}"],
        cwd=dest,
        check=True,
        capture_output=True,
    )


def github_create(dest: Path, project_name: str, variant: str) -> None:
    """Create GitHub repo and push."""
    config = GITHUB_CONFIGS.get(variant, GITHUB_CONFIGS["default"])
    repo_name = f"{config['owner']}/{project_name}"
    visibility = "--private" if config["private"] else "--public"

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


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="ralph-init",
        description="Bootstrap projects with the Ralph Playbook methodology.",
        add_help=False,
    )
    parser.add_argument("variant", nargs="?", default=None)
    parser.add_argument("--desc", default=None, help="Project goal description")
    parser.add_argument("--update", action="store_true", help="Update existing repo with latest Ralph files")
    parser.add_argument("-h", "--help", action="store_true")

    args = parser.parse_args()

    # Show help if no variant or help requested
    if args.help or args.variant is None or args.variant == "help":
        print(HELP_TEXT)
        sys.exit(0)

    variant = args.variant
    if variant not in VARIANTS:
        print(f"Error: unknown variant '{variant}'. Choose from: {', '.join(VARIANTS)}")
        print(f"\nRun 'ralph-init' for help.")
        sys.exit(1)

    # Pre-flight credential check for SAP
    if variant == "sap":
        check_sap_credentials()

    dest = Path.cwd()
    project_name = dest.name
    update_mode = args.update

    if update_mode:
        print(f"Updating Ralph ({variant}) in {dest}")
    else:
        print(f"Initializing Ralph ({variant}) in {dest}")
    print(f"Project name: {project_name}")
    print()

    # 1. Copy shared files
    print("  Copying shared Ralph files...")
    copy_shared_files(dest)

    # 2. Build .gitignore
    print("  Building .gitignore...")
    build_gitignore(dest, variant)

    # 3. Copy variant files
    print(f"  Copying {variant} variant files...")
    copy_variant_files(dest, variant, project_name)

    # 4. Replace project goal if --desc provided
    if args.desc:
        print(f"  Setting project goal in PROMPT_plan.md...")
        replace_project_goal(dest, args.desc)

    # 5. Create CLAUDE.md symlink
    print("  Creating CLAUDE.md -> AGENTS.md symlink...")
    create_symlink(dest)

    if not update_mode:
        # 6. Create directories
        dirs = VARIANT_DIRS.get(variant, ("specs", "src"))
        print(f"  Creating {', '.join(d + '/' for d in dirs)}...")
        create_dirs(dest, variant)

        # 7. Git init + commit
        print("  Initializing git repo...")
        git_init(dest, variant)

        # 8. GitHub repo creation (skip for fork variant)
        if variant == "fork":
            print("  Skipping GitHub repo (local-only fork)...")
        else:
            gh_config = GITHUB_CONFIGS.get(variant, GITHUB_CONFIGS["default"])
            print(f"  Creating GitHub repo {gh_config['owner']}/{project_name} on {gh_config['host']}...")
            github_create(dest, project_name, variant)

    print()
    if update_mode:
        print(f"Done! Ralph v{__version__} ({variant}) files updated.")
    else:
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
    print("  /ralph-reqs   — Interactive requirements gathering & ideation")
    print("  /ralph-spec   — Convert planning docs into Ralph specs")
    print("  /ralph-plan   — Run planning mode (gap analysis)")
    print("  /ralph-build  — Run build mode (implement next task)")


