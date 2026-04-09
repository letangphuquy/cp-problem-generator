#!/bin/bash
# Phase: Solve (Generate Outputs)
# Runs sol/model on every requested .inp file and writes the corresponding
# .out file.
#
# Usage: ./scripts/phase_solve.sh [--tests <spec>]
#
# Options:
#   --tests <spec>  Which tests to solve (default: all).
#                   Formats: 'all', '01', '01,03', '01-05', '01-03,07'

source "$(dirname "$0")/common.sh"
cd "$ROOT_DIR" || exit 1

TESTS_SPEC="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tests) TESTS_SPEC="$2"; shift 2 ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
            exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${CYAN}--- Phase: Solve (Generate Outputs) ---${NC}"

TOTAL=$(count_script_tests)
mapfile -t REQUESTED < <(parse_test_spec "$TESTS_SPEC" "$TOTAL")

if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    log_warn "No tests matched spec: $TESTS_SPEC"
    exit 0
fi

FAILED=0
for padded in "${REQUESTED[@]}"; do
    inp_file="tests/test${padded}.inp"
    out_file="tests/test${padded}.out"

    if [[ ! -f "$inp_file" ]]; then
        log_warn "test${padded}.inp not found — skipping"
        continue
    fi

    if ./sol/model < "$inp_file" > "$out_file"; then
        log_success "test${padded}.out"
        log_entry "test${padded}" "solve" "ok"
    else
        log_error "test${padded}: model solution exited with code $?"
        log_entry "test${padded}" "solve" "fail"
        rm -f "$out_file"
        ((FAILED++))
    fi
done

if [[ $FAILED -gt 0 ]]; then
    log_error "Solve phase: $FAILED test(s) failed."
    exit 1
fi

echo -e "${GREEN}--- Solve phase complete (${#REQUESTED[@]} tests) ---${NC}\n"
