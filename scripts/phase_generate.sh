#!/bin/bash
# Phase: Generate Inputs
# Reads script.txt and produces a .inp file for every requested test.
# Uses intelligent caching: skips regeneration if gen.cpp and args haven't changed.
#
# Usage: ./scripts/phase_generate.sh [--tests <spec>] [--clean]
#
# Options:
#   --tests <spec>  Which tests to generate (default: all).
#                   Formats: 'all', '01', '01,03', '01-05', '01-03,07'
#   --clean         Delete existing .inp files before regenerating.

source "$(dirname "$0")/common.sh"
cd "$ROOT_DIR" || exit 1

TESTS_SPEC="all"
CLEAN_FLAG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tests) TESTS_SPEC="$2"; shift 2 ;;
        --clean) CLEAN_FLAG="--clean"; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
            exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${CYAN}--- Phase: Generate Inputs ---${NC}"
echo

# Call Python utility for intelligent testdata generation with caching
python3 generate_testdata.py --tests "$TESTS_SPEC" $CLEAN_FLAG
if [ $? -ne 0 ]; then
    echo
    log_error "Generate phase failed"
    exit 1
fi

echo
echo -e "${GREEN}--- Generate phase complete ---${NC}\n"

FAILED=0
for padded in "${REQUESTED[@]}"; do
    idx=$((10#$padded - 1))  # convert to 0-based index
    if [[ $idx -lt 0 || $idx -ge ${#SCRIPT_LINES[@]} ]]; then
        log_warn "test${padded} is out of range (only $TOTAL tests in script.txt) — skipping"
        continue
    fi

    # Strip inline comment and trim whitespace.
    line="${SCRIPT_LINES[$idx]%%#*}"
    line="$(echo "$line" | xargs)"

    inp_file="tests/test${padded}.inp"

    $CLEAN && rm -f "$inp_file"

    # Reset log for this test before writing fresh entries.
    clear_log_entries "test${padded}"

    if ./gen $line > "$inp_file" 2>/dev/null; then
        log_success "test${padded}.inp  (gen $line)"
        log_entry "test${padded}" "generate" "ok"
    else
        log_error "test${padded}.inp — gen failed  (gen $line)"
        log_entry "test${padded}" "generate" "fail"
        ((FAILED++))
    fi
done

if [[ $FAILED -gt 0 ]]; then
    log_error "Generate phase: $FAILED test(s) failed."
    exit 1
fi

echo -e "${GREEN}--- Generate phase complete (${#REQUESTED[@]} tests) ---${NC}\n"
