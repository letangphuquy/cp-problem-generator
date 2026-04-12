#!/bin/bash
# Phase: Compile
# Compiles gen, validator (val), and sol/model from source.
# Uses compile.py utility with smart file hash caching.
#
# Usage: ./scripts/phase_compile.sh

source "$(dirname "$0")/common.sh"
cd "$ROOT_DIR" || exit 1

echo -e "${CYAN}--- Phase: Compile ---${NC}"
echo

python3 compile.py gen.cpp validator.cpp sol/model.cpp
if [ $? -ne 0 ]; then
    echo
    log_error "Compilation failed"
    exit 1
fi

echo
echo -e "${GREEN}--- Compile phase complete ---${NC}\n"
