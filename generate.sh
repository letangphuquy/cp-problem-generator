#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   AUTOMATED TEST GENERATOR + VALIDATOR   ${NC}"
echo -e "${CYAN}==========================================${NC}\n"

echo -e "${YELLOW}[1/3] Compiling infrastructure and solutions...${NC}"
g++ -O3 -std=c++17 gen.cpp -o gen || { echo -e "${RED}[Error] gen.cpp failed!${NC}"; exit 1; }
g++ -O3 -std=c++17 validator.cpp -o val || { echo -e "${RED}[Error] validator.cpp failed!${NC}"; exit 1; }
g++ -O3 -std=c++17 sol/model.cpp -o sol/model || { echo -e "${RED}[Error] sol/model.cpp failed!${NC}"; exit 1; }
echo -e "${GREEN}- Compilation successful!${NC}\n"

echo -e "${YELLOW}[2/3] Cleaning up the 'tests' directory...${NC}"
mkdir -p tests
rm -f tests/*
echo -e "${GREEN}- Directory is ready.${NC}\n"

echo -e "${YELLOW}[3/3] Starting test generation and validation...${NC}"
test_idx=1

while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | xargs)
    if [[ -z "$line" || "$line" == \#* ]]; then continue; fi

    padded=$(printf "%02d" $test_idx)
    inp_file="tests/test${padded}.inp"
    out_file="tests/test${padded}.out"

    # A: Sinh .inp (bỏ qua cerr rác vào /dev/null)
    ./gen $line > "$inp_file" 2> /dev/null
    
    # B: model.cpp sinh .out
    ./sol/model < "$inp_file" > "$out_file"
    
    # C: Validate
    ./val < "$inp_file"
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}[FATAL ERROR] Validator caught an error at test${padded}${NC}"
        exit 1
    fi

    echo -e "${GREEN}[OK]${NC} Generated and Validated ${CYAN}test${padded}${NC}: ./gen $line"
    ((test_idx++))
done < script.txt

total=$((test_idx - 1))
echo -e "\n${GREEN}DONE! Successfully generated ${total} tests using sol/model.cpp.${NC}"