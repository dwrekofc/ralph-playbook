#!/bin/bash
# v2-loop.sh — Ralph v2 Beta loop runner
#
# Usage:
#   ./v2-loop.sh [--agent=claude|codex|auto] generate [max]       Build from PRODUCT_SPEC.md
#   ./v2-loop.sh eval [max]           Adversarial evaluation
#   ./v2-loop.sh product [max]        Generate product spec from CONSTRAINTS.md
#   ./v2-loop.sh auto [cycles]        Alternating generate→eval (default: 3 cycles)
#   ./v2-loop.sh bench [cycles]       Benchmark all eval strategies
#   ./v2-loop.sh help                 List available modes
#
# Eval strategy flags (for auto/bench modes):
#   --eval=prompt    Dedicated eval prompt (default)
#   --eval=codex     Codex cross-review
#   --eval=teams     File-based generator/evaluator handoff
#   --eval=all       Run all strategies (benchmark mode)
#
# Requires: jq and the selected agent CLI

set -euo pipefail

# ─── Defaults ───────────────────────────────────────────────────────

V2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
FORMAT_STREAM="${V2_DIR}/../format-stream.sh"
[ ! -f "$FORMAT_STREAM" ] && FORMAT_STREAM="./format-stream.sh"

LOG_DIR="logs"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
EVAL_STRATEGY="prompt"
RETRY_ONLY="false"
AGENT="claude"

# Read v2 config from .ralph.json
FAIL_THRESHOLD=50
if [ -f ".ralph.json" ] && command -v jq &>/dev/null; then
    _threshold=$(jq -r '.v2.fail_threshold // empty' .ralph.json 2>/dev/null)
    [ -n "$_threshold" ] && FAIL_THRESHOLD="$_threshold"
    _eval=$(jq -r '.v2.eval_strategy // empty' .ralph.json 2>/dev/null)
    [ -n "$_eval" ] && EVAL_STRATEGY="$_eval"
fi

# ─── Parse arguments ────────────────────────────────────────────────

MODE=""
MAX_ITERATIONS=0
CYCLES=3

# Extract flags from any position
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --eval=*) EVAL_STRATEGY="${arg#--eval=}" ;;
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
    echo "v2-loop.sh — Ralph v2 Beta loop runner"
    echo ""
    echo "Usage: ./v2-loop.sh [--agent=claude|codex|auto] <mode> [max]"
    echo "Agent: $AGENT"
    echo ""
    echo "Modes:"
    echo "  generate [max]    Build from PRODUCT_SPEC.md (default)"
    echo "  eval [max]        Adversarial evaluation pass"
    echo "  product [max]     Generate product spec from CONSTRAINTS.md"
    echo "  auto [cycles]     Alternating generate→eval (default: 3 cycles)"
    echo "  bench [cycles]    Benchmark all eval strategies"
    echo "  help              Show this help"
    echo ""
    echo "Eval strategies (--eval=<strategy>):"
    echo "  prompt            Dedicated eval prompt (default)"
    echo "  codex             Codex cross-review via codex exec"
    echo "  teams             File-based generator/evaluator handoff"
    echo "  all               Run all strategies (benchmark)"
    echo ""
    echo "Examples:"
    echo "  ./v2-loop.sh generate 5"
    echo "  ./v2-loop.sh --agent=codex generate 5"
    echo "  ./v2-loop.sh auto 3 --eval=codex"
    echo "  ./v2-loop.sh bench 2"
    echo ""
    echo "Config (.ralph.json v2 section):"
    echo "  eval_strategy     Default eval strategy"
    echo "  fail_threshold    Pass rate threshold (default: 50)"
    exit 0
else
    MODE="$1"
    shift
    if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
        if [ "$MODE" = "auto" ] || [ "$MODE" = "bench" ]; then
            CYCLES="$1"
        else
            MAX_ITERATIONS="$1"
        fi
        shift
    fi
fi

mkdir -p "$LOG_DIR"

# ─── Helpers ────────────────────────────────────────────────────────

run_prompt() {
    local prompt_file="$1"
    local iteration="$2"
    local env_vars="${3:-}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOG_DIR}/v2_${AGENT}_${MODE}_${iteration}_${timestamp}.jsonl"

    echo -e "\n--- v2 iteration $iteration started at $(date) ---"
    echo "Prompt: $prompt_file"
    echo "Log: $log_file"

    local prompt_content
    prompt_content=$(cat "$prompt_file")

    # Prepend env vars as context if provided
    if [ -n "$env_vars" ]; then
        prompt_content="${env_vars}

${prompt_content}"
    fi

    # Auto-inject concatenated specs/* as context for generate/eval modes
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

    if [ "$AGENT" = "codex" ]; then
        local codex_format="${V2_DIR}/../format-codex-stream.sh"
        [ ! -f "$codex_format" ] && codex_format="./format-codex-stream.sh"
        if [ ! -x "$codex_format" ]; then
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
            | "$codex_format"
    else
        echo "$prompt_content" | claude -p \
            --dangerously-skip-permissions \
            --output-format=stream-json \
            --model opus \
            --verbose \
            | tee "$log_file" \
            | "$FORMAT_STREAM"
    fi

    echo -e "\n--- v2 iteration $iteration finished at $(date) ---"

    # Push changes
    git push origin "$CURRENT_BRANCH" 2>/dev/null || \
        git push -u origin "$CURRENT_BRANCH" 2>/dev/null || \
        echo "  (git push skipped — no remote or not a git repo)"
}

get_pass_rate() {
    # Parse pass_rate from EVAL_REPORT.md
    if [ -f "EVAL_REPORT.md" ]; then
        local rate
        rate=$(grep -oP 'pass_rate:\s*\K[0-9]+' EVAL_REPORT.md 2>/dev/null || echo "0")
        echo "$rate"
    else
        echo "0"
    fi
}

resolve_prompt() {
    local name="$1"
    if [ "$AGENT" = "codex" ]; then
        if [ -f "harnesses/codex/v2/PROMPT_${name}.md" ]; then
            echo "harnesses/codex/v2/PROMPT_${name}.md"
        elif [ -f "${V2_DIR}/../harnesses/codex/v2/PROMPT_${name}.md" ]; then
            echo "${V2_DIR}/../harnesses/codex/v2/PROMPT_${name}.md"
        elif [ -f "${PROJECT_DIR}/harnesses/codex/v2/PROMPT_${name}.md" ]; then
            echo "${PROJECT_DIR}/harnesses/codex/v2/PROMPT_${name}.md"
        else
            echo ""
        fi
    elif [ -f "${V2_DIR}/PROMPT_${name}.md" ]; then
        echo "${V2_DIR}/PROMPT_${name}.md"
    elif [ -f "v2/PROMPT_${name}.md" ]; then
        echo "v2/PROMPT_${name}.md"
    elif [ -f "PROMPT_${name}.md" ]; then
        echo "PROMPT_${name}.md"
    else
        echo ""
    fi
}

run_eval_codex() {
    local iteration="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOG_DIR}/v2_eval_codex_${iteration}_${timestamp}.jsonl"

    echo -e "\n--- v2 codex eval $iteration started at $(date) ---"
    echo "Log: $log_file"

    # Use the codex review helper if available
    local codex_script="${V2_DIR}/v2-codex-review.sh"
    [ ! -f "$codex_script" ] && codex_script="v2/v2-codex-review.sh"

    if [ -f "$codex_script" ]; then
        bash "$codex_script" 2>&1 | tee "$log_file"
    else
        # Fallback: run eval prompt with codex instruction prepended
        local eval_prompt
        eval_prompt=$(resolve_prompt "eval")
        if [ -n "$eval_prompt" ]; then
            run_prompt "$eval_prompt" "$iteration" "EVAL_MODE=codex
You are performing a Codex-style cross-review. Focus on code quality, architecture, and correctness."
        else
            echo "Error: No eval prompt found and no codex review script."
        fi
    fi

    echo -e "\n--- v2 codex eval $iteration finished at $(date) ---"
}

run_eval_teams() {
    local iteration="$1"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOG_DIR}/v2_eval_teams_${iteration}_${timestamp}.jsonl"

    echo -e "\n--- v2 teams eval $iteration started at $(date) ---"
    echo "Log: $log_file"

    # File-based teams: run generate then eval sequentially with handoff files
    local gen_prompt
    gen_prompt=$(resolve_prompt "generate")
    local eval_prompt
    eval_prompt=$(resolve_prompt "eval")

    if [ -n "$gen_prompt" ] && [ -n "$eval_prompt" ]; then
        # Generator writes HANDOFF.md
        run_prompt "$gen_prompt" "${iteration}_gen" "TEAMS_MODE=true
After completing your work, write a HANDOFF.md file summarizing what you built and what to test."

        # Evaluator reads HANDOFF.md
        run_prompt "$eval_prompt" "${iteration}_eval" "TEAMS_MODE=true
Read HANDOFF.md for context on what was just built before beginning evaluation."
    else
        echo "Error: Missing generate or eval prompt for teams mode."
    fi

    echo -e "\n--- v2 teams eval $iteration finished at $(date) ---"
}

# ─── Mode: single prompt ───────────────────────────────────────────

run_single_mode() {
    local prompt_file
    prompt_file=$(resolve_prompt "$MODE")

    if [ -z "$prompt_file" ]; then
        echo "Error: No prompt found for mode '$MODE'"
        if [ "$AGENT" = "codex" ]; then
            echo "Looked in: harnesses/codex/v2/PROMPT_${MODE}.md"
        else
            echo "Looked in: ${V2_DIR}/PROMPT_${MODE}.md, v2/PROMPT_${MODE}.md, PROMPT_${MODE}.md"
        fi
        exit 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ralph v2 Beta"
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
        echo -e "\n======================== V2 LOOP $iteration ========================\n"
    done
}

# ─── Mode: auto (alternating generate→eval) ────────────────────────

run_auto_mode() {
    local gen_prompt
    gen_prompt=$(resolve_prompt "generate")
    local eval_prompt
    eval_prompt=$(resolve_prompt "eval")

    if [ -z "$gen_prompt" ]; then
        echo "Error: v2/PROMPT_generate.md not found"
        exit 1
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ralph v2 Beta — Auto Mode"
    echo "Agent:        $AGENT"
    echo "Cycles:       $CYCLES (generate→eval)"
    echo "Eval:         $EVAL_STRATEGY"
    echo "Threshold:    ${FAIL_THRESHOLD}%"
    echo "Branch:       $CURRENT_BRANCH"
    echo "Logs:         $LOG_DIR/"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for cycle in $(seq 1 "$CYCLES"); do
        echo -e "\n╔══════════════════════════════════════╗"
        echo "║  CYCLE $cycle / $CYCLES"
        echo "╚══════════════════════════════════════╝"

        # ── Generate ──
        echo -e "\n▶ GENERATE (cycle $cycle)"
        local env_vars=""
        if [ "$RETRY_ONLY" = "true" ]; then
            env_vars="RETRY_ONLY=true
Only fix features that FAILED in EVAL_REPORT.md. Do not touch passing features."
        fi
        run_prompt "$gen_prompt" "c${cycle}_gen" "$env_vars"

        # ── Evaluate ──
        echo -e "\n▶ EVALUATE (cycle $cycle) — strategy: $EVAL_STRATEGY"
        case "$EVAL_STRATEGY" in
            prompt)
                if [ -n "$eval_prompt" ]; then
                    run_prompt "$eval_prompt" "c${cycle}_eval"
                else
                    echo "Warning: No eval prompt found, skipping evaluation."
                fi
                ;;
            codex)
                run_eval_codex "c${cycle}"
                ;;
            teams)
                run_eval_teams "c${cycle}"
                ;;
            all)
                echo "  Running all 3 eval strategies..."
                if [ -n "$eval_prompt" ]; then
                    cp EVAL_REPORT.md EVAL_REPORT_pre.md 2>/dev/null || true
                    run_prompt "$eval_prompt" "c${cycle}_eval_prompt"
                    cp EVAL_REPORT.md EVAL_REPORT_prompt.md 2>/dev/null || true
                fi
                run_eval_codex "c${cycle}"
                cp EVAL_REPORT.md EVAL_REPORT_codex.md 2>/dev/null || true
                # Restore pre-eval state for teams
                cp EVAL_REPORT_pre.md EVAL_REPORT.md 2>/dev/null || true
                run_eval_teams "c${cycle}"
                cp EVAL_REPORT.md EVAL_REPORT_teams.md 2>/dev/null || true
                ;;
            *)
                echo "Error: Unknown eval strategy '$EVAL_STRATEGY'"
                exit 1
                ;;
        esac

        # ── Threshold check ──
        local pass_rate
        pass_rate=$(get_pass_rate)
        echo -e "\n  Pass rate: ${pass_rate}% (threshold: ${FAIL_THRESHOLD}%)"

        if [ "$pass_rate" -ge 100 ]; then
            echo "  All features passing! Stopping early."
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

# ─── Mode: bench (benchmark all strategies) ─────────────────────────

run_bench_mode() {
    local strategies=("prompt" "codex" "teams")
    local results_dir="benchmarks/results"
    mkdir -p "$results_dir"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local project_name
    project_name=$(basename "$(pwd)")

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Ralph v2 Beta — Benchmark Mode"
    echo "Project:      $project_name"
    echo "Strategies:   ${strategies[*]}"
    echo "Cycles each:  $CYCLES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    for strategy in "${strategies[@]}"; do
        echo -e "\n╔══════════════════════════════════════╗"
        echo "║  BENCHMARK: $strategy"
        echo "╚══════════════════════════════════════╝"

        local start_time
        start_time=$(date +%s)

        # Reset eval report
        rm -f EVAL_REPORT.md

        # Run auto mode with this strategy
        EVAL_STRATEGY="$strategy"
        RETRY_ONLY="false"
        run_auto_mode

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local pass_rate
        pass_rate=$(get_pass_rate)
        local iteration_count
        iteration_count=$(ls -1 "${LOG_DIR}"/v2_*_c*_*.jsonl 2>/dev/null | wc -l | tr -d ' ')
        local loc
        loc=$(find src -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
              -o -name "*.rs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" \
              2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        local test_count
        test_count=$(grep -r "test\|it(" src/ tests/ test/ 2>/dev/null | wc -l | tr -d ' ' || echo "0")

        # Write JSON result
        local result_file="${results_dir}/${project_name}_${strategy}_${timestamp}.json"
        cat > "$result_file" <<EOF
{
  "project": "$project_name",
  "strategy": "$strategy",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": $duration,
  "iterations": $iteration_count,
  "pass_rate": $pass_rate,
  "loc": $loc,
  "test_count": $test_count,
  "test_coverage_pct": null,
  "user_score": null,
  "cost_usd": null,
  "bugs_eval_found": null,
  "bugs_user_found": null
}
EOF
        echo "  Result saved: $result_file"

        # Save strategy-specific eval report
        cp EVAL_REPORT.md "EVAL_REPORT_${strategy}.md" 2>/dev/null || true
    done

    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Benchmark complete!"
    echo "Results in: $results_dir/"
    echo ""
    echo "Review each result and fill in:"
    echo "  - user_score (1-10)"
    echo "  - cost_usd (from Anthropic dashboard)"
    echo "  - bugs_user_found (bugs you find that eval missed)"
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
    bench)
        run_bench_mode
        ;;
    generate|eval|product)
        run_single_mode
        ;;
    *)
        echo "Error: Unknown mode '$MODE'"
        echo "Run './v2-loop.sh help' for usage."
        exit 1
        ;;
esac
