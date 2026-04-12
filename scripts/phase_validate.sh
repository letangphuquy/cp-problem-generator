#!/bin/bash
# Phase: Validate Inputs
# Runs cached validate phase (deterministic skip when input+validator unchanged).
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

ARGS=(validate --tests "$TESTS_SPEC")
if $CONTINUE_ON_ERROR; then
    ARGS+=(--continue-on-error)
fi

python3 run_phase_cached.py "${ARGS[@]}"
if [[ $? -ne 0 ]]; then
    exit 1
fi

echo
