#!/bin/bash
# run-bench.sh — Ralph v2 Benchmark Runner
#
# Runs benchmark tests across projects and eval strategies.
# Results saved as JSON to benchmarks/results/ for dashboard comparison.
#
# Usage:
#   ./benchmarks/run-bench.sh <project|all> <strategy|all> [cycles]
#
# Examples:
#   ./benchmarks/run-bench.sh js-recipe-app prompt 3
#   ./benchmarks/run-bench.sh rust-csv-tool codex 2
#   ./benchmarks/run-bench.sh all all 3        # full 3x3 matrix (9 runs)
#   ./benchmarks/run-bench.sh all prompt 5     # all projects, one strategy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RALPH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
RESULTS_DIR="$SCRIPT_DIR/results"
WORKSPACE="/tmp/ralph-bench"

ALL_PROJECTS=("js-recipe-app" "rust-csv-tool" "cpp-snake-game")
ALL_STRATEGIES=("prompt" "codex" "teams")

# ─── Parse arguments ────────────────────────────────────────────────

if [ $# -lt 2 ]; then
    echo "Usage: ./benchmarks/run-bench.sh <project|all> <strategy|all> [cycles]"
    echo ""
    echo "Projects:   ${ALL_PROJECTS[*]}"
    echo "Strategies: ${ALL_STRATEGIES[*]}"
    echo ""
    echo "Examples:"
    echo "  ./benchmarks/run-bench.sh js-recipe-app prompt 3"
    echo "  ./benchmarks/run-bench.sh all all 3"
    exit 1
fi

PROJECT_ARG="$1"
STRATEGY_ARG="$2"
CYCLES="${3:-3}"

# Resolve project list
if [ "$PROJECT_ARG" = "all" ]; then
    PROJECTS=("${ALL_PROJECTS[@]}")
else
    PROJECTS=("$PROJECT_ARG")
fi

# Resolve strategy list
if [ "$STRATEGY_ARG" = "all" ]; then
    STRATEGIES=("${ALL_STRATEGIES[@]}")
else
    STRATEGIES=("$STRATEGY_ARG")
fi

# Validate
for p in "${PROJECTS[@]}"; do
    if [ ! -d "$PROJECTS_DIR/$p" ]; then
        echo "Error: Project '$p' not found in $PROJECTS_DIR/"
        exit 1
    fi
done

for s in "${STRATEGIES[@]}"; do
    if [[ ! " ${ALL_STRATEGIES[*]} " =~ " $s " ]]; then
        echo "Error: Unknown strategy '$s'. Choose from: ${ALL_STRATEGIES[*]}"
        exit 1
    fi
done

mkdir -p "$RESULTS_DIR" "$WORKSPACE"

# ─── Check prerequisites ───────────────────────────────────────────

if ! command -v ralph &>/dev/null; then
    echo "Error: ralph CLI not found. Install with: pip install -e $RALPH_ROOT"
    exit 1
fi

if ! command -v claude &>/dev/null; then
    echo "Error: claude CLI not found."
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "Error: jq not found. Install with: brew install jq"
    exit 1
fi

# ─── Run benchmarks ────────────────────────────────────────────────

TOTAL_RUNS=$(( ${#PROJECTS[@]} * ${#STRATEGIES[@]} ))
CURRENT_RUN=0

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Ralph v2 Benchmark Suite"
echo "Projects:    ${PROJECTS[*]}"
echo "Strategies:  ${STRATEGIES[*]}"
echo "Cycles each: $CYCLES"
echo "Total runs:  $TOTAL_RUNS"
echo "Workspace:   $WORKSPACE"
echo "Results:     $RESULTS_DIR/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for project in "${PROJECTS[@]}"; do
    for strategy in "${STRATEGIES[@]}"; do
        CURRENT_RUN=$((CURRENT_RUN + 1))
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        RUN_ID="${project}_${strategy}_${TIMESTAMP}"
        RUN_DIR="${WORKSPACE}/${RUN_ID}"

        echo ""
        echo "╔══════════════════════════════════════════════╗"
        echo "║  Run $CURRENT_RUN/$TOTAL_RUNS: $project + $strategy"
        echo "╚══════════════════════════════════════════════╝"

        # 1. Create clean workspace
        mkdir -p "$RUN_DIR"
        cd "$RUN_DIR"

        # 2. Initialize ralph blank project
        echo "  Initializing ralph blank project..."
        ralph init blank --no-gh --no-git 2>&1 | sed 's/^/  /'

        # 3. Copy benchmark specs
        echo "  Copying benchmark PRODUCT_SPEC.md + CONSTRAINTS.md..."
        cp "$PROJECTS_DIR/$project/PRODUCT_SPEC.md" "$RUN_DIR/"
        cp "$PROJECTS_DIR/$project/CONSTRAINTS.md" "$RUN_DIR/"

        # 4. Initialize git
        git init -q
        git add -A
        git commit -q -m "bench: init $project"

        # 5. Record start
        START_TIME=$(date +%s)
        echo "  Started at: $(date)"

        # 6. Run v2 loop
        echo "  Running: ./v2-loop.sh auto $CYCLES --eval=$strategy"
        chmod +x v2/v2-loop.sh v2/v2-codex-review.sh 2>/dev/null || true
        cd "$RUN_DIR"

        # Run and capture exit code (don't fail the whole suite on one failure)
        set +e
        ./v2/v2-loop.sh auto "$CYCLES" --eval="$strategy" 2>&1 | tee "${RUN_DIR}/bench.log" | tail -20
        BENCH_EXIT=$?
        set -e

        if [ $BENCH_EXIT -ne 0 ]; then
            echo "  Warning: Benchmark run exited with code $BENCH_EXIT"
        fi

        # 7. Record end
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo "  Duration: ${DURATION}s"

        # 8. Parse results
        PASS_RATE=0
        if [ -f "EVAL_REPORT.md" ]; then
            PASS_RATE=$(grep -oP 'pass_rate:\s*\K[0-9]+' EVAL_REPORT.md 2>/dev/null || echo "0")
        fi

        ITERATION_COUNT=$(ls -1 logs/v2_*.jsonl 2>/dev/null | wc -l | tr -d ' ')
        [ -z "$ITERATION_COUNT" ] && ITERATION_COUNT=0

        LOC=0
        if [ -d "src" ]; then
            LOC=$(find src -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
                  -o -name "*.rs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.py" \) \
                  2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
        fi
        [ -z "$LOC" ] && LOC=0

        TEST_COUNT=0
        if [ -d "src" ] || [ -d "tests" ] || [ -d "test" ]; then
            TEST_COUNT=$(grep -r "test\|it(\|describe(\|#\[test\]" src/ tests/ test/ 2>/dev/null | wc -l | tr -d ' ')
        fi
        [ -z "$TEST_COUNT" ] && TEST_COUNT=0

        # 9. Write JSON result
        RESULT_FILE="${RESULTS_DIR}/${RUN_ID}.json"
        cat > "$RESULT_FILE" <<EOF
{
  "project": "$project",
  "strategy": "$strategy",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "duration_seconds": $DURATION,
  "iterations": $ITERATION_COUNT,
  "cycles": $CYCLES,
  "pass_rate": $PASS_RATE,
  "loc": $LOC,
  "test_count": $TEST_COUNT,
  "test_coverage_pct": null,
  "user_score": null,
  "cost_usd": null,
  "bugs_eval_found": null,
  "bugs_user_found": null,
  "exit_code": $BENCH_EXIT,
  "workspace": "$RUN_DIR"
}
EOF

        echo "  Result: $RESULT_FILE"
        echo "  Pass rate: ${PASS_RATE}%"
        echo "  LOC: $LOC"
        echo "  Tests: $TEST_COUNT"

        cd "$RALPH_ROOT"
    done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Benchmark suite complete!"
echo "  Runs: $TOTAL_RUNS"
echo "  Results: $RESULTS_DIR/"
echo ""
echo "Next steps:"
echo "  1. Review each workspace in $WORKSPACE/"
echo "  2. Fill in user_score, cost_usd, bugs_user_found in each JSON result"
echo "  3. Open benchmarks/dashboard/index.html to compare results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
