#!/bin/bash

# Bảng màu hiển thị log cho trực quan
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 1. Compile gen.cpp
echo -e "${YELLOW}[1/3] Đang biên dịch gen.cpp...${NC}"
g++ -O3 -std=c++17 gen.cpp -o gen
if [ $? -ne 0 ]; then
    echo -e "${RED}LỖI: Biên dịch gen.cpp thất bại! Hãy kiểm tra lại code.${NC}"
    exit 1
fi
echo -e "${GREEN}Biên dịch thành công!${NC}\n"

# 2. Chuẩn bị thư mục tests
echo -e "${YELLOW}[2/3] Dọn dẹp thư mục 'tests'...${NC}"
mkdir -p tests
rm -f tests/*
echo -e "${GREEN}Thư mục đã sẵn sàng.${NC}\n"

# 3. Đọc script và sinh test
echo -e "${YELLOW}[3/3] Bắt đầu sinh test từ script.txt...${NC}"
test_idx=1

# Đọc từng dòng trong script.txt
while IFS= read -r line || [ -n "$line" ]; do
    # Xóa khoảng trắng thừa ở hai đầu
    line=$(echo "$line" | xargs)

    # Bỏ qua dòng trống và dòng comment (bắt đầu bằng #)
    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi

    # Định dạng số thứ tự test (VD: 01, 02, ..., 10)
    padded_idx=$(printf "%02d" $test_idx)
    
    inp_file="tests/test${padded_idx}.inp"
    out_file="tests/test${padded_idx}.out"

    # Chạy gen với tham số lấy từ script, điều hướng stdout -> .inp, stderr -> .out
    ./gen $line > "$inp_file" 2> "$out_file"

    if [ $? -eq 0 ]; then
        echo -e "Tạo thành công ${CYAN}test${padded_idx}${NC}: ./gen $line"
    else
        echo -e "${RED}Thất bại tại test${padded_idx}${NC}: ./gen $line"
    fi

    ((test_idx++))

done < script.txt

echo -e "\n${GREEN}HOÀN TẤT! Đã sinh ra $((test_idx - 1)) tests trong thư mục 'tests/'.${NC}"