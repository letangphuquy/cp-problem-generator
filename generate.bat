@echo off
setlocal EnableDelayedExpansion

echo ==========================================
echo    TOOL SINH TEST TUDONG (WINDOWS)
echo ==========================================
echo.

:: 1. Compile gen.cpp
echo [1/3] Dang bien dich gen.cpp...
g++ -O3 -std=c++17 gen.cpp -o gen.exe
if errorlevel 1 (
    echo [Loi] Bien dich gen.cpp that bai! Kiem tra lai code.
    pause
    exit /b 1
)
echo - Bien dich thanh cong!
echo.

:: 2. Chuẩn bị thư mục tests
echo [2/3] Don dep thu muc 'tests'...
if not exist tests mkdir tests
del /Q tests\*
echo - Thu muc da san sang.
echo.

:: 3. Đọc script.txt và sinh test
echo [3/3] Bat dau sinh test tu script.txt...
set test_idx=1

:: Đọc từng dòng, bỏ qua dòng trống và dòng bắt đầu bằng # (comment)
for /f "usebackq eol=# tokens=*" %%A in ("script.txt") do (
    set "line=%%A"
    
    :: Pad số 0 cho đẹp (VD: 01, 02, ..., 10)
    set "padded=0!test_idx!"
    set "padded=!padded:~-2!"
    
    set "inp_file=tests\test!padded!.inp"
    set "out_file=tests\test!padded!.out"
    
    :: Chạy gen.exe và điều hướng stdout -> .inp, stderr -> .out
    gen.exe !line! > "!inp_file!" 2> "!out_file!"
    
    if !errorlevel! equ 0 (
        echo [OK] Tao test!padded!: gen.exe !line!
    ) else (
        echo [FAIL] That bai tai test!padded!: gen.exe !line!
    )
    
    set /a test_idx+=1
)

set /a total=test_idx-1
echo.
echo HOAN TAT! Da sinh ra %total% tests trong thu muc 'tests\'.
echo ==========================================
pause