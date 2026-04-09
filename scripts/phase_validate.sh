#!/bin/bash
# Phase: Validate Inputs
# Runs the validator binary against every requested .inp file.
#
# Usage: ./scripts/phase_validate.sh [--tests <spec>] [--continue-on-error]
#
# Options:
#   --tests <spec>       Which tests to validate (default: all).
#                        Formats: 'all', '01', '01,03', '01-05', '01-03,07'
#   --continue-on-error  Log failures but keep going instead of aborting on
#                        the first invalid input.

source "$(dirname "$0")/common.sh"
cd "$ROOT_DIR" || exit 1

TESTS_SPEC="all"
CONTINUE_ON_ERROR=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tests)             TESTS_SPEC="$2"; shift 2 ;;
        --continue-on-error) CONTINUE_ON_ERROR=true; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
            exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${CYAN}--- Phase: Validate Inputs ---${NC}"

TOTAL=$(count_script_tests)
mapfile -t REQUESTED < <(parse_test_spec "$TESTS_SPEC" "$TOTAL")

if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    log_warn "No tests matched spec: $TESTS_SPEC"
    exit 0
fi

FAILED=0
for padded in "${REQUESTED[@]}"; do
    inp_file="tests/test${padded}.inp"

    if [[ ! -f "$inp_file" ]]; then
        log_warn "test${padded}.inp not found — skipping"
        continue
    fi

    if ./val < "$inp_file" > /dev/null 2>&1; then
        log_success "test${padded}.inp  [valid]"
        log_entry "test${padded}" "validate" "ok"
    else
        log_error "test${padded}.inp  [INVALID]"
        log_entry "test${padded}" "validate" "fail"
        ((FAILED++))
        if ! $CONTINUE_ON_ERROR; then
            log_error "Stopping on first validation failure. Use --continue-on-error to continue."
            exit 1
        fi
    fi
done

if [[ $FAILED -gt 0 ]]; then
    log_error "Validate phase: $FAILED test(s) failed."
    exit 1
fi

echo -e "${GREEN}--- Validate phase complete (${#REQUESTED[@]} tests) ---${NC}\n"
