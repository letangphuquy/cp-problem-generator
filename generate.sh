#!/bin/bash

# Define colors for terminal output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   AUTOMATED TEST GENERATOR + VALIDATOR   ${NC}"
echo -e "${CYAN}==========================================${NC}\n"

# 1. Compile Generator and Validator source code
echo -e "${YELLOW}[1/3] Compiling source code...${NC}"

g++ -O3 -std=c++17 gen.cpp -o gen
if [ $? -ne 0 ]; then
    echo -e "${RED}[Error] Compilation of gen.cpp failed!${NC}"
    exit 1
fi

g++ -O3 -std=c++17 validator.cpp -o val
if [ $? -ne 0 ]; then
    echo -e "${RED}[Error] Compilation of validator.cpp failed! Please check testlib.h.${NC}"
    exit 1
fi

echo -e "${GREEN}- Compilation successful!${NC}\n"

# 2. Prepare the output directory
echo -e "${YELLOW}[2/3] Cleaning up the 'tests' directory...${NC}"
mkdir -p tests
rm -f tests/*
echo -e "${GREEN}- Directory is ready.${NC}\n"

# 3. Generate tests and run validation
echo -e "${YELLOW}[3/3] Starting test generation and validation...${NC}"
test_idx=1

# Read script.txt line by line
while IFS= read -r line || [ -n "$line" ]; do
    # Trim leading/trailing whitespace
    line=$(echo "$line" | xargs)

    # Skip empty lines and comments (starting with #)
    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi

    # Zero-pad the test index (e.g., 01, 02, ..., 10)
    padded=$(printf "%02d" $test_idx)
    
    inp_file="tests/test${padded}.inp"
    out_file="tests/test${padded}.out"

    # Step A: Generate the test case
    ./gen $line > "$inp_file" 2> "$out_file"
    
    # Step B: Run the Validator to ensure input correctness
    ./val < "$inp_file"
    
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}==========================================${NC}"
        echo -e "${RED}[FATAL ERROR] Validator caught an error at test${padded}${NC}"
        echo -e "${RED}Failing command:${NC} ./gen $line"
        echo -e "${RED}==========================================${NC}"
        exit 1
    fi

    echo -e "${GREEN}[OK]${NC} Generated and Validated ${CYAN}test${padded}${NC}: ./gen $line"
    ((test_idx++))

done < script.txt

total=$((test_idx - 1))
echo -e "\n${GREEN}DONE! Successfully generated and validated ${total} tests.${NC}"
echo -e "${