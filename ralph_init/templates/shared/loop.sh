#!/bin/bash
# Usage: ./loop.sh [--agent=claude|codex|auto] [mode] [max_iterations]
# Examples:
#   ./loop.sh              # Build mode, unlimited iterations
#   ./loop.sh 20           # Build mode, max 20 iterations
#   ./loop.sh plan         # Plan mode, unlimited iterations
#   ./loop.sh plan 5       # Plan mode, max 5 iterations
#   ./loop.sh audit 10     # Custom mode, max 10 iterations
#   ./loop.sh --agent=codex plan 5
#   ./loop.sh help         # List available modes
#
# Claude modes are auto-discovered from root PROMPT_<name>.md files.
# Codex modes are auto-discovered from harnesses/codex/PROMPT_<name>.md files.
# Readable streaming output + raw JSON logs.
# Requires: jq

# Defaults
AGENT="claude"

# Extract --agent flag from any position
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --agent=*) AGENT="${arg#--agent=}" ;;
        *) ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

if [ "$AGENT" = "auto" ]; then
    if command -v claude &> /dev/null; then
        AGENT="claude"
    elif command -v codex &> /dev/null; then
        AGENT="codex"
    else
        echo "Error: neither claude nor codex CLI is installed."
        exit 1
    fi
fi

if [ "$AGENT" != "claude" ] && [ "$AGENT" != "codex" ]; then
    echo "Error: unknown agent '$AGENT'. Expected: claude, codex, auto"
    exit 1
fi

prompt_file_for_mode() {
    local mode="$1"
    if [ "$AGENT" = "codex" ]; then
        echo "harnesses/codex/PROMPT_${mode}.md"
    else
        echo "PROMPT_${mode}.md"
    fi
}

list_modes() {
    local pattern
    if [ "$AGENT" = "codex" ]; then
        pattern="harnesses/codex/PROMPT_*.md"
    else
        pattern="PROMPT_*.md"
    fi

    for f in $pattern; do
        [ -f "$f" ] || continue
        name="${f##*/}"
        name="${name#PROMPT_}"
        name="${name%.md}"
        desc=$(head -1 "$f" | sed -n 's/^<!-- description: \(.*\) -->/\1/p')
        if [ -n "$desc" ]; then
            printf "  %-12s %s\n" "$name" "$desc"
        else
            printf "  %-12s\n" "$name"
        fi
    done
}

# Parse arguments
if [ -z "$1" ]; then
    MODE="build"
    PROMPT_FILE=$(prompt_file_for_mode "$MODE")
    MAX_ITERATIONS=0
elif [[ "$1" =~ ^[0-9]+$ ]]; then
    MODE="build"
    PROMPT_FILE=$(prompt_file_for_mode "$MODE")
    MAX_ITERATIONS=$1
elif [ "$1" = "help" ]; then
    echo "Usage: ./loop.sh [--agent=claude|codex|auto] [mode] [max_iterations]"
    echo ""
    echo "Agent: $AGENT"
    echo ""
    echo "Available modes:"
    list_modes
    echo ""
    echo "Default mode is 'build' when no mode is specified."
    exit 0
else
    MODE="$1"
    PROMPT_FILE=$(prompt_file_for_mode "$MODE")
    MAX_ITERATIONS=${2:-0}
fi

ITERATION=0
CURRENT_BRANCH=$(git branch --show-current)
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Agent:  $AGENT"
echo "Mode:   $MODE"
echo "Prompt: $PROMPT_FILE"
echo "Branch: $CURRENT_BRANCH"
echo "Logs:   $LOG_DIR/"
[ $MAX_ITERATIONS -gt 0 ] && echo "Max:    $MAX_ITERATIONS iterations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: $PROMPT_FILE not found"
    exit 1
fi

# Verify jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Install with: brew install jq"
    exit 1
fi

while true; do
    if [ $MAX_ITERATIONS -gt 0 ] && [ $ITERATION -ge $MAX_ITERATIONS ]; then
        echo "Reached max iterations: $MAX_ITERATIONS"
        break
    fi

    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    LOG_FILE="${LOG_DIR}/${AGENT}_${MODE}_${ITERATION}_${TIMESTAMP}.jsonl"

    echo -e "\n--- Iteration $ITERATION started at $(date) ---"
    echo "Log: $LOG_FILE"

    if [ "$AGENT" = "codex" ]; then
        if ! command -v codex &> /dev/null; then
            echo "Error: codex CLI is required for --agent=codex."
            exit 1
        fi
        if [ ! -x "./format-codex-stream.sh" ]; then
            echo "Error: format-codex-stream.sh not found or not executable."
            exit 1
        fi
        cat "$PROMPT_FILE" | codex exec \
            --json \
            --model gpt-5.5 \
            --config model_reasoning_effort=high \
            --sandbox danger-full-access \
            --ask-for-approval never \
            - \
            | tee "$LOG_FILE" \
            | ./format-codex-stream.sh
    else
        if ! command -v claude &> /dev/null; then
            echo "Error: claude CLI is required for --agent=claude."
            exit 1
        fi
        # Run Claude with stream-json, tee raw JSON to log, format for readable output.
        # format-stream.sh shows thinking, text, tool calls, and results with colors.
        cat "$PROMPT_FILE" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose \
            | tee "$LOG_FILE" \
            | ./format-stream.sh
    fi

    echo -e "\n--- Iteration $ITERATION finished at $(date) ---"

    # Push changes after each iteration
    git push origin "$CURRENT_BRANCH" || {
        echo "Failed to push. Creating remote branch..."
        git push -u origin "$CURRENT_BRANCH"
    }

    ITERATION=$((ITERATION + 1))
    echo -e "\n\n======================== LOOP $ITERATION ========================\n"
done
