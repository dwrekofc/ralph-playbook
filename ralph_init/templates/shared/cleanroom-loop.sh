#!/bin/bash
# cleanroom-loop.sh — Ralph cleanroom research runner
#
# Usage:
#   ./cleanroom-loop.sh [--agent=codex|claude|auto] [max_iterations]
#
# Reads PROMPT_cleanroom.md (or harnesses/codex/PROMPT_cleanroom.md when
# --agent=codex), runs it in a headless loop, and writes neutral behavior
# notes to docs/cleanroom/research/.
#
# Defaults to codex because cleanroom research is reading-heavy and benefits
# from gpt-5.5 with high reasoning. Logs go to logs/cleanroom/ to keep them
# separate from regular build logs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMAT_STREAM="${SCRIPT_DIR}/format-stream.sh"
[ ! -f "$FORMAT_STREAM" ] && FORMAT_STREAM="./format-stream.sh"
FORMAT_CODEX="${SCRIPT_DIR}/format-codex-stream.sh"
[ ! -f "$FORMAT_CODEX" ] && FORMAT_CODEX="./format-codex-stream.sh"

AGENT="codex"
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --agent=*) AGENT="${arg#--agent=}" ;;
        *) ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

if [ "$AGENT" = "auto" ]; then
    if command -v codex &>/dev/null; then
        AGENT="codex"
    elif command -v claude &>/dev/null; then
        AGENT="claude"
    else
        echo "Error: neither codex nor claude CLI is installed."
        exit 1
    fi
fi

if [ "$AGENT" != "codex" ] && [ "$AGENT" != "claude" ]; then
    echo "Error: unknown agent '$AGENT'. Expected: codex, claude, auto"
    exit 1
fi

MAX_ITERATIONS="${1:-1}"
if [ "$MAX_ITERATIONS" = "help" ]; then
    echo "cleanroom-loop.sh — Ralph cleanroom research runner"
    echo ""
    echo "Usage: ./cleanroom-loop.sh [--agent=codex|claude|auto] [max_iterations]"
    echo "Agent: $AGENT (default: codex)"
    echo ""
    echo "Reads PROMPT_cleanroom.md and writes behavior notes to docs/cleanroom/research/."
    echo "Logs go to logs/cleanroom/."
    echo ""
    echo "Examples:"
    echo "  ./cleanroom-loop.sh                  # one iteration with codex"
    echo "  ./cleanroom-loop.sh 3                # three iterations with codex"
    echo "  ./cleanroom-loop.sh --agent=claude 1 # one iteration with claude"
    exit 0
fi

if [ "$AGENT" = "codex" ]; then
    if ! command -v codex &>/dev/null; then
        echo "Error: codex CLI is required for --agent=codex."
        exit 1
    fi
    PROMPT_FILE="harnesses/codex/PROMPT_cleanroom.md"
    [ ! -f "$PROMPT_FILE" ] && PROMPT_FILE="${SCRIPT_DIR}/harnesses/codex/PROMPT_cleanroom.md"
else
    if ! command -v claude &>/dev/null; then
        echo "Error: claude CLI is required for --agent=claude."
        exit 1
    fi
    PROMPT_FILE="PROMPT_cleanroom.md"
    [ ! -f "$PROMPT_FILE" ] && PROMPT_FILE="${SCRIPT_DIR}/PROMPT_cleanroom.md"
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: PROMPT_cleanroom.md not found"
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: brew install jq"
    exit 1
fi

LOG_DIR="logs/cleanroom"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
mkdir -p "$LOG_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ralph — Cleanroom Research"
echo "Agent:  $AGENT"
echo "Prompt: $PROMPT_FILE"
echo "Logs:   $LOG_DIR/"
echo "Max:    $MAX_ITERATIONS iterations"
echo "Branch: $CURRENT_BRANCH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ITERATION=0
while true; do
    if [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_DIR}/${AGENT}_research_${ITERATION}_${TIMESTAMP}.jsonl"

    echo
    echo "--- Cleanroom iteration $ITERATION started at $(date) ---"
    echo "Log: $LOG_FILE"

    if [ "$AGENT" = "codex" ]; then
        if [ ! -x "$FORMAT_CODEX" ]; then
            echo "Error: format-codex-stream.sh not found or not executable."
            exit 1
        fi
        codex exec \
            --json \
            --model gpt-5.5 \
            --config model_reasoning_effort=high \
            --dangerously-bypass-approvals-and-sandbox \
            - < "$PROMPT_FILE" \
            | tee "$LOG_FILE" \
            | "$FORMAT_CODEX"
    else
        claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose < "$PROMPT_FILE" \
            | tee "$LOG_FILE" \
            | "$FORMAT_STREAM"
    fi

    echo "--- Cleanroom iteration $ITERATION finished at $(date) ---"

    # Push after each iteration so research notes are durable
    git push origin "$CURRENT_BRANCH" 2>/dev/null || \
        git push -u origin "$CURRENT_BRANCH" 2>/dev/null || \
        echo "  (git push skipped — no remote or not a git repo)"

    ITERATION=$((ITERATION + 1))
done

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Cleanroom research complete."
echo "Notes written to: docs/cleanroom/research/"
echo "Review them, then run: /ralph-reqs → /ralph-spec → ./loop.sh auto"
echo "(or use the fast path: /ralph-rapid-prototype → ./loop.sh auto)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
