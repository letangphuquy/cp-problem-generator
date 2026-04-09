#!/bin/bash
# Phase: Compile
# Compiles gen, validator (val), and sol/model from source.
#
# Usage: ./scripts/phase_compile.sh

source "$(dirname "$0")/common.sh"
cd "$ROOT_DIR" || exit 1

echo -e "${CYAN}--- Phase: Compile ---${NC}"

compile_binary() {
    local src="$1"
    local out="$2"
    echo -e "  Compiling ${src}..."
    if g++ -O3 -std=c++17 "$src" -o "$out"; then
        log_success "Compiled ${src} → ${out}"
    else
        log_error "Failed to compile ${src}"
        exit 1
    fi
}

compile_binary "gen.cpp"       "gen"
compile_binary "validator.cpp" "val"
compile_binary "sol/model.cpp" "sol/model"

echo -e "${GREEN}--- Compile phase complete ---${NC}\n"
