#!/bin/bash
# Phase: Generate Inputs
# Reads script.txt and produces a .inp file for every requested test.
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
CLEAN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tests) TESTS_SPEC="$2"; shift 2 ;;
        --clean) CLEAN=true; shift ;;
        -h|--help)
            sed -n '/^# Usage:/,/^[^#]/{ /^#/s/^# \?//p }' "$0"
            exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

echo -e "${CYAN}--- Phase: Generate Inputs ---${NC}"

mkdir -p tests

TOTAL=$(count_script_tests)
if [[ "$TOTAL" -eq 0 ]]; then
    log_error "No test cases found in script.txt"
    exit 1
fi

# Build an indexed array of the runnable lines in script.txt.
mapfile -t SCRIPT_LINES < <(
    grep -v '^[[:space:]]*#' "$SCRIPT_FILE" | grep -v '^[[:space:]]*$'
)

mapfile -t REQUESTED < <(parse_test_spec "$TESTS_SPEC" "$TOTAL")

if [[ ${#REQUESTED[@]} -eq 0 ]]; then
    log_warn "No tests matched spec: $TESTS_SPEC"
    exit 0
fi

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
