@echo off
setlocal EnableDelayedExpansion

echo ==========================================
echo    AUTOMATED TEST GENERATOR + VALIDATOR
echo ==========================================
echo.

:: 1. Biên dịch toàn bộ công cụ và Thuật chuẩn
echo [1/3] Compiling infrastructure and solutions...
g++ -O3 -std=c++17 gen.cpp -o gen.exe
if errorlevel 1 ( echo [Error] gen.cpp failed! & pause & exit /b 1 )

g++ -O3 -std=c++17 validator.cpp -o val.exe
if errorlevel 1 ( echo [Error] validator.cpp failed! & pause & exit /b 1 )

g++ -O3 -std=c++17 sol\model.cpp -o sol\model.exe
if errorlevel 1 ( echo [Error] sol\model.cpp failed! & pause & exit /b 1 )

echo - Compilation successful!
echo.

:: 2. Dọn dẹp thư mục tests
echo [2/3] Cleaning up the 'tests' directory...
if not exist tests mkdir tests
del /Q tests\*
echo - Directory is ready.
echo.

:: 3. Sinh test
echo [3/3] Starting test generation and validation...
set test_idx=1

for /f "usebackq eol=# tokens=*" %%A in ("script.txt") do (
    set "line=%%A"
    
    set "padded=0!test_idx!"
    set "padded=!padded:~-2!"
    set "inp_file=tests\test!padded!.inp"
    set "out_file=tests\test!padded!.out"
    
    :: Bước A: gen.exe sinh ra .inp (Dấu 2> NUL để ẩn đi cerr nếu gen.cpp cũ chưa xóa)
    gen.exe !line! > "!inp_file!" 2> NUL
    
    :: Bước B: model.exe đọc .inp và giải ra .out chuẩn
    sol\model.exe < "!inp_file!" > "!out_file!"
    
    :: Bước C: Kiểm duyệt .inp
    val.exe < "!inp_file!"
    if !errorlevel! neq 0 (
        echo.
        echo ==========================================
        echo [FATAL ERROR] Validator caught an error at test!padded!
        echo Failing command: gen.exe !line!
        echo ==========================================
        pause
        exit /b 1
    )
    
    echo [OK] Generated and Validated test!padded!: gen.exe !line!
    set /a test_idx+=1
)

set /a total=test_idx-1
echo.
echo DONE! Successfully generated %total% tests using sol\model.cpp.
echo ==========================================
pause