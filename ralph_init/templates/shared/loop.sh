#!/bin/bash
# loop.sh — Ralph loop runner
#
# Usage:
#   ./loop.sh [--agent=claude|codex|auto] generate [max]        Build from PRODUCT_SPEC.md / specs
#   ./loop.sh eval [max]               Adversarial evaluation pass
#   ./loop.sh rapid-prototype [max]    Generate product spec from CONSTRAINTS.md
#   ./loop.sh auto [cycles]            Alternating generate→eval (default: 3 cycles)
#   ./loop.sh help                     Show help
#
# Evaluator agent in `auto` mode is ALWAYS Codex (gpt-5.5, high reasoning),
# regardless of the --agent flag. The build agent follows --agent.
#
# Requires: jq, the selected build-agent CLI, and codex (for auto mode's evaluator)

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
FORMAT_STREAM="${SCRIPT_DIR}/format-stream.sh"
[ ! -f "$FORMAT_STREAM" ] && FORMAT_STREAM="./format-stream.sh"
FORMAT_CODEX="${SCRIPT_DIR}/format-codex-stream.sh"
[ ! -f "$FORMAT_CODEX" ] && FORMAT_CODEX="./format-codex-stream.sh"

LOG_DIR="logs"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
RETRY_ONLY="false"
AGENT="claude"

# Read config from .ralph.json (with v0.5.x .v2.* back-compat for fail_threshold)
FAIL_THRESHOLD=50
if [ -f ".ralph.json" ] && command -v jq &>/dev/null; then
    _threshold=$(jq -r '.fail_threshold // .v2.fail_threshold // empty' .ralph.json 2>/dev/null)
    [ -n "$_threshold" ] && FAIL_THRESHOLD="$_threshold"
fi

# ─── Parse arguments ────────────────────────────────────────────────

MODE=""
MAX_ITERATIONS=0
CYCLES=3

ARGS=()
for arg in "$@"; do
    case "$arg" in
        --agent=*) AGENT="${arg#--agent=}" ;;
        *) ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

if [ "$AGENT" = "auto" ]; then
    if command -v claude &>/dev/null; then
        AGENT="claude"
    elif command -v codex &>/dev/null; then
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

if [ $# -eq 0 ]; then
    MODE="generate"
elif [ "$1" = "help" ]; then
    echo "loop.sh — Ralph loop runner"
    echo ""
    echo "Usage: ./loop.sh [--agent=claude|codex|auto] <mode> [max]"
    echo "Agent: $AGENT  (note: auto mode's evaluator is always codex)"
    echo ""
    echo "Modes:"
    echo "  generate [max]          Build from PRODUCT_SPEC.md / specs (default)"
    echo "  eval [max]              Adversarial evaluation pass"
    echo "  rapid-prototype [max]   Generate product spec from CONSTRAINTS.md"
    echo "  auto [cycles]           Alternating generate→eval (default: 3 cycles)"
    echo "  help                    Show this help"
    echo ""
    echo "Examples:"
    echo "  ./loop.sh generate 5"
    echo "  ./loop.sh --agent=codex generate 5"
    echo "  ./loop.sh auto 3"
    echo ""
    echo "Config (.ralph.json top level):"
    echo "  fail_threshold    Pass rate threshold for retry-vs-rebuild (default: 50)"
    exit 0
else
    MODE="$1"
    shift
    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        if [ "$MODE" = "auto" ]; then
            CYCLES="$1"
        else
            MAX_ITERATIONS="$1"
        fi
        shift
    fi
fi

mkdir -p "$LOG_DIR"

# ─── Helpers ────────────────────────────────────────────────────────

# run_prompt <prompt_file> <iteration> [env_vars] [agent_override]
#
# agent_override (4th arg) lets callers force a specific agent for this
# invocation regardless of the global $AGENT. Used by auto mode to lock
# the evaluator to codex.
run_prompt() {
    local prompt_file="$1"
    local iteration="$2"
    local env_vars="${3:-}"
    local agent="${4:-$AGENT}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOG_DIR}/${agent}_${MODE}_${iteration}_${timestamp}.jsonl"

    echo -e "\n--- iteration $iteration started at $(date) ($agent) ---"
    echo "Prompt: $prompt_file"
    echo "Log: $log_file"

    local prompt_content
    prompt_content=$(cat "$prompt_file")

    if [ -n "$env_vars" ]; then
        prompt_content="${env_vars}

${prompt_content}"
    fi

    # Auto-inject concatenated specs/* as context for generate/eval/auto modes
    local specs_context=""
    if [[ "$MODE" == "generate" || "$MODE" == "auto" || "$MODE" == "eval" ]]; then
        if [ -d "specs" ] && ls specs/*.md &>/dev/null; then
            specs_context="
--- BEGIN CONCATENATED SPECS (from specs/*.md) ---
"
            for spec_file in specs/*.md; do
                specs_context="${specs_context}
=== $(basename "$spec_file") ===
$(cat "$spec_file")

"
            done
            specs_context="${specs_context}--- END CONCATENATED SPECS ---
"
            prompt_content="${specs_context}
${prompt_content}"
            echo "  Injected $(ls specs/*.md | wc -l | tr -d ' ') spec file(s) as context"
        fi
    fi

    if [ "$agent" = "codex" ]; then
        if [ ! -x "$FORMAT_CODEX" ]; then
            echo "Error: format-codex-stream.sh not found or not executable."
            exit 1
        fi
        echo "$prompt_content" | codex exec \
            --json \
            --model gpt-5.5 \
            --config model_reasoning_effort=high \
            --dangerously-bypass-approvals-and-sandbox \
            - \
            | tee "$log_file" \
            | "$FORMAT_CODEX"
    else
        echo "$prompt_content" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose \
            | tee "$log_file" \
            | "$FORMAT_STREAM"
    fi

    echo -e "\n--- iteration $iteration finished at $(date) ---"

    git push origin "$CURRENT_BRANCH" 2>/dev/null || \
        git push -u origin "$CURRENT_BRANCH" 2>/dev/null || \
        echo "  (git push skipped — no remote or not a git repo)"
}

get_pass_rate() {
    # Parse pass_rate from EVAL_REPORT.md (macOS-portable; sed instead of GNU grep -oP).
    if [ -f "EVAL_REPORT.md" ]; then
        local rate
        rate=$(sed -nE 's/^[[:space:]]*pass_rate:[[:space:]]*([0-9]+).*/\1/p' EVAL_REPORT.md 2>/dev/null | head -1)
        echo "${rate:-0}"
    else
        echo "0"
    fi
}

resolve_prompt() {
    local name="$1"
    local agent="${2:-$AGENT}"
    if [ "$agent" = "codex" ]; then
        if [ -f "harnesses/codex/PROMPT_${name}.md" ]; then
            echo "harnesses/codex/PROMPT_${name}.md"
        elif [ -f "${SCRIPT_DIR}/harnesses/codex/PROMPT_${name}.md" ]; then
            echo "${SCRIPT_DIR}/harnesses/codex/PROMPT_${name}.md"
        else
            echo ""
        fi
    elif [ -f "PROMPT_${name}.md" ]; then
        echo "PROMPT_${name}.md"
    elif [ -f "${SCRIPT_DIR}/PROMPT_${name}.md" ]; then
        echo "${SCRIPT_DIR}/PROMPT_${name}.md"
    else
        echo ""
    fi
}

# ─── Mode: single prompt (generate / eval / rapid-prototype) ────────

run_single_mode() {
    local prompt_file
    prompt_file=$(resolve_prompt "$MODE")

    if [ -z "$prompt_file" ]; then
        echo "Error: No prompt found for mode '$MODE'"
        if [ "$AGENT" = "codex" ]; then
            echo "Looked in: harnesses/codex/PROMPT_${MODE}.md, ${SCRIPT_DIR}/harnesses/codex/PROMPT_${MODE}.md"
        else
            echo "Looked in: PROMPT_${MODE}.md, ${SCRIPT_DIR}/PROMPT_${MODE}.md"
        fi
        exit 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ralph"
    echo "Agent:    $AGENT"
    echo "Mode:     $MODE"
    echo "Prompt:   $prompt_file"
    echo "Branch:   $CURRENT_BRANCH"
    echo "Logs:     $LOG_DIR/"
    [ "$MAX_ITERATIONS" -gt 0 ] && echo "Max:      $MAX_ITERATIONS iterations"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local iteration=0
    while true; do
        if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -ge "$MAX_ITERATIONS" ]; then
            echo "Reached max iterations: $MAX_ITERATIONS"
            break
        fi

        run_prompt "$prompt_file" "$iteration"
        iteration=$((iteration + 1))
        echo -e "\n======================== LOOP $iteration ========================\n"
    done
}

# ─── Mode: auto (alternating generate→eval, codex-locked evaluator) ─

run_auto_mode() {
    local gen_prompt
    gen_prompt=$(resolve_prompt "generate")
    local eval_prompt
    # Evaluator is always codex — resolve from harnesses/codex/ regardless of build agent.
    eval_prompt=$(resolve_prompt "eval" "codex")

    if [ -z "$gen_prompt" ]; then
        echo "Error: PROMPT_generate.md not found"
        exit 1
    fi
    if [ -z "$eval_prompt" ]; then
        echo "Error: harnesses/codex/PROMPT_eval.md not found (required for auto mode)"
        exit 1
    fi
    if ! command -v codex &>/dev/null; then
        echo "Error: codex CLI is required for auto mode (evaluator is always codex)."
        echo "Install codex, then retry."
        exit 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ralph — Auto Mode"
    echo "Build agent:  $AGENT"
    echo "Evaluator:    codex (locked, gpt-5.5, high reasoning)"
    echo "Cycles:       $CYCLES (generate→eval)"
    echo "Threshold:    ${FAIL_THRESHOLD}%"
    echo "Branch:       $CURRENT_BRANCH"
    echo "Logs:         $LOG_DIR/"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for cycle in $(seq 1 "$CYCLES"); do
        echo -e "\n╔══════════════════════════════════════╗"
        echo "║  CYCLE $cycle / $CYCLES"
        echo "╚══════════════════════════════════════╝"

        # ── Generate (uses --agent= choice) ──
        echo -e "\n▶ GENERATE (cycle $cycle, agent: $AGENT)"
        local env_vars=""
        if [ "$RETRY_ONLY" = "true" ]; then
            env_vars="RETRY_ONLY=true
Only fix features that FAILED in EVAL_REPORT.md. Do not touch passing features."
        fi
        run_prompt "$gen_prompt" "c${cycle}_gen" "$env_vars"

        # ── Evaluate (always codex) ──
        echo -e "\n▶ EVALUATE (cycle $cycle, agent: codex)"
        run_prompt "$eval_prompt" "c${cycle}_eval" "" "codex"

        # ── Threshold check ──
        local pass_rate
        pass_rate=$(get_pass_rate)
        echo -e "\n  Pass rate: ${pass_rate}% (threshold: ${FAIL_THRESHOLD}%)"

        if [ "$pass_rate" -ge 100 ]; then
            echo "  All features passing. Stopping early."
            break
        elif [ "$pass_rate" -ge "$FAIL_THRESHOLD" ]; then
            echo "  Above threshold — next cycle retries failed features only."
            RETRY_ONLY="true"
        else
            echo "  Below threshold — next cycle does full rebuild."
            RETRY_ONLY="false"
        fi
    done

    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Auto mode complete: $CYCLES cycles"
    echo "Final pass rate: $(get_pass_rate)%"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ─── Verify prerequisites ──────────────────────────────────────────

if ! command -v jq &>/dev/null; then
    echo "Error: jq is required. Install with: brew install jq"
    exit 1
fi

if [ "$AGENT" = "codex" ]; then
    if ! command -v codex &>/dev/null; then
        echo "Error: codex CLI is required for --agent=codex."
        exit 1
    fi
elif ! command -v claude &>/dev/null; then
    echo "Error: claude CLI is required for --agent=claude."
    exit 1
fi

# ─── Dispatch ──────────────────────────────────────────────────────

case "$MODE" in
    auto)
        run_auto_mode
        ;;
    generate|eval|rapid-prototype)
        run_single_mode
        ;;
    *)
        echo "Error: Unknown mode '$MODE'"
        echo "Run './loop.sh help' for usage."
        exit 1
        ;;
esac
