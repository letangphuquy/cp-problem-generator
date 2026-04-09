#!/bin/bash
# Orchestrator: Automated Test Generator & Validator
#
# Usage: ./generate.sh [options]
#
# Options:
#   --phases <list>       Comma-separated phases to execute.
#                         Valid phases: compile, generate, validate, solve
#                         Default: compile,generate,validate,solve
#   --tests <spec>        Which tests to process (applies to every phase
#                         except compile).
#                         Formats: 'all', '01', '01,03', '01-05', '01-03,07'
#                         Default: all
#   --retry               Re-run only tests that failed in the previous run.
#                         Reads tests/run.log; skips compile unless it is
#                         explicitly listed in --phases.
#   --continue-on-error   Do not abort on the first validation failure;
#                         log all failures and continue.
#   --clean               Remove existing .inp files for the selected tests
#                         before regenerating them.
#   -h, --help            Show this help message.
#
# Examples:
#   ./generate.sh
#       Full run: compile everything, generate all tests, validate, solve.
#
#   ./generate.sh --phases generate,validate,solve --tests 01-10
#       Skip compile; (re)generate tests 01-10 only.
#
#   ./generate.sh --retry
#       Re-run generate -> validate -> solve for every test that failed last time.
#
#   ./generate.sh --phases validate --tests 03,07
#       Re-validate only tests 03 and 07 (binaries already compiled).
#
#   ./generate.sh --phases compile
#       Recompile all binaries without touching the tests directory.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"
cd "$ROOT_DIR" || exit 1

# ---- Defaults ----
PHASES="compile,generate,validate,solve"
TESTS_SPEC="all"
RETRY=false
CONTINUE_ON_ERROR=false
CLEAN=false

# ---- Parse arguments ----
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phases)            PHASES="$2"; shift 2 ;;
        --tests)             TESTS_SPEC="$2"; shift 2 ;;
        --retry)             RETRY=true; shift ;;
        --continue-on-error) CONTINUE_ON_ERROR=true; shift ;;
        --clean)             CLEAN=true; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
            exit 0 ;;
        *)
            echo -e "${RED}[ERR ] Unknown option: $1" >&2
            echo "Run './generate.sh --help' for usage." >&2
            exit 1 ;;
    esac
done

# ---- Handle --retry ----
if $RETRY; then
    mapfile -t FAILED_TESTS < <(get_failed_tests)
    if [[ ${#FAILED_TESTS[@]} -eq 0 ]]; then
        echo -e "${GREEN}No failed tests in log. Nothing to retry.${NC}"
        exit 0
    fi
    TESTS_SPEC="$(IFS=','; echo "${FAILED_TESTS[*]}")"
    log_info "Retrying ${#FAILED_TESTS[@]} failed test(s): $TESTS_SPEC"
    # Compile is not test-specific; skip it unless the caller asked for it.
    if [[ "$PHASES" == "compile,generate,validate,solve" ]]; then
        PHASES="generate,validate,solve"
    fi
fi

# ---- Banner ----
echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   AUTOMATED TEST GENERATOR + VALIDATOR   ${NC}"
echo -e "${CYAN}==========================================${NC}"
echo -e "  Phases : ${YELLOW}${PHASES}${NC}"
echo -e "  Tests  : ${YELLOW}${TESTS_SPEC}${NC}"
$RETRY && echo -e "  Mode   : ${YELLOW}retry (failed tests only)${NC}"
echo ""

# ---- Phase runners ----
run_compile() {
    bash "${SCRIPT_DIR}/scripts/phase_compile.sh"
}

run_generate() {
    local args=("--tests" "$TESTS_SPEC")
    $CLEAN && args+=("--clean")
    bash "${SCRIPT_DIR}/scripts/phase_generate.sh" "${args[@]}"
}

run_validate() {
    local args=("--tests" "$TESTS_SPEC")
    $CONTINUE_ON_ERROR && args+=("--continue-on-error")
    bash "${SCRIPT_DIR}/scripts/phase_validate.sh" "${args[@]}"
}

run_solve() {
    bash "${SCRIPT_DIR}/scripts/phase_solve.sh" "--tests" "$TESTS_SPEC"
}

# ---- Execute requested phases ----
IFS=',' read -ra PHASE_LIST <<< "$PHASES"
for phase in "${PHASE_LIST[@]}"; do
    phase="${phase// /}"  # trim any surrounding whitespace
    case "$phase" in
        compile)  run_compile  || exit $? ;;
        generate) run_generate || exit $? ;;
        validate) run_validate || exit $? ;;
        solve)    run_solve    || exit $? ;;
        *)
            echo -e "${RED}[ERR ] Unknown phase: '${phase}'." >&2
            echo "Valid phases: compile, generate, validate, solve" >&2
            exit 1 ;;
    esac
done

# ---- Summary ----
TOTAL=$(count_script_tests)
mapfile -t PROCESSED < <(parse_test_spec "$TESTS_SPEC" "$TOTAL")
echo -e "${GREEN}DONE! Successfully processed ${#PROCESSED[@]} test(s).${NC}"
