#!/bin/bash
# Phase: Solve (Generate Outputs)
# Runs cached solve phase and skips rerun when input+model are unchanged
# and output hash is still valid.
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

python3 run_phase_cached.py solve --tests "$TESTS_SPEC"
if [[ $? -ne 0 ]]; then
    exit 1
fi

echo
