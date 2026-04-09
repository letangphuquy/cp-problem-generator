#!/bin/bash
# Common utilities shared by all phase scripts.

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Absolute path to project root (parent of this scripts/ directory).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Where per-test run results are persisted.
LOG_FILE="${ROOT_DIR}/tests/run.log"

# Path to the test-case script.
SCRIPT_FILE="${ROOT_DIR}/script.txt"

log_info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[ OK ]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERR ]${NC} $*" >&2; }

# Count runnable (non-blank, non-comment) lines in script.txt.
count_script_tests() {
    grep -v '^[[:space:]]*#' "${SCRIPT_FILE}" \
        | grep -v '^[[:space:]]*$' \
        | wc -l \
        | tr -d ' '
}

# Parse a test-spec string into a newline-separated list of zero-padded
# 2-digit test numbers (e.g. "01", "02", ...).
#
# Supported formats:
#   all          → every test in script.txt
#   5            → test 05
#   01,03,07     → tests 01, 03, 07
#   01-05        → tests 01 through 05
#   01-03,07,10  → combination of ranges and individual numbers
#
# Usage: parse_test_spec <spec> [<total>]
parse_test_spec() {
    local spec="${1:-all}"
    local total="${2:-$(count_script_tests)}"

    if [[ "$spec" == "all" ]]; then
        seq 1 "$total" | awk '{ printf "%02d\n", $1 }'
        return
    fi

    local -a numbers=()
    IFS=',' read -ra parts <<< "$spec"
    for part in "${parts[@]}"; do
        part="${part// /}"  # trim whitespace
        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local s=$((10#${BASH_REMATCH[1]}))
            local e=$((10#${BASH_REMATCH[2]}))
            for ((i = s; i <= e; i++)); do numbers+=("$i"); done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            numbers+=($((10#$part)))
        fi
    done

    # Deduplicate, sort, and zero-pad.
    printf '%s\n' "${numbers[@]}" | sort -nu | awk '{ printf "%02d\n", $1 }'
}

# Append a result line to the log, replacing any existing entry for the
# same test-id / phase combination.
#
# Usage: log_entry <test_id> <phase> <status>
#   test_id : e.g. "test01"
#   phase   : generate | validate | solve
#   status  : ok | fail
log_entry() {
    local test_id="$1"
    local phase="$2"
    local status="$3"

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"

    # Remove any previous entry for this test + phase.
    grep -v "^${test_id} ${phase} " "$LOG_FILE" > "${LOG_FILE}.tmp" \
        && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    echo "${test_id} ${phase} ${status}" >> "$LOG_FILE"
}

# Remove ALL log entries for a given test (called before regenerating it).
clear_log_entries() {
    local test_id="$1"
    if [[ -f "$LOG_FILE" ]]; then
        grep -v "^${test_id} " "$LOG_FILE" > "${LOG_FILE}.tmp" \
            && mv "${LOG_FILE}.tmp" "$LOG_FILE"
    fi
}

# Print a newline-separated list of zero-padded test numbers that have at
# least one "fail" entry in the log.
get_failed_tests() {
    if [[ ! -f "$LOG_FILE" ]]; then return; fi
    grep ' fail$' "$LOG_FILE" \
        | awk '{print $1}' \
        | sed 's/^test//' \
        | sort -nu \
        | awk '{ printf "%02d\n", $1 }'
}
