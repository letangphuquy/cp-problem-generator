@echo off
setlocal EnableDelayedExpansion

echo ==========================================
echo    AUTOMATED TEST GENERATOR + VALIDATOR
echo ==========================================
echo.

:: 1. Compile Generator and Validator source code
echo [1/3] Compiling source code...
g++ -O3 -std=c++17 gen.cpp -o gen.exe
if errorlevel 1 (
    echo [Error] Compilation of gen.cpp failed!
    pause
    exit /b 1
)

g++ -O3 -std=c++17 validator.cpp -o val.exe
if errorlevel 1 (
    echo [Error] Compilation of validator.cpp failed! Please check testlib.h.
    pause
    exit /b 1
)
echo - Compilation successful!
echo.

:: 2. Prepare the output directory
echo [2/3] Cleaning up the 'tests' directory...
if not exist tests mkdir tests
del /Q tests\*
echo - Directory is ready.
echo.

:: 3. Generate tests and run validation
echo [3/3] Starting test generation and validation...
set test_idx=1

for /f "usebackq eol=# tokens=*" %%A in ("script.txt") do (
    set "line=%%A"
    
    :: Zero-pad the test index (e.g., 01, 02, ..., 10)
    set "padded=0!test_idx!"
    set "padded=!padded:~-2!"
    set "inp_file=tests\test!padded!.inp"
    set "out_file=tests\test!padded!.out"
    
    :: Step A: Generate the test case
    gen.exe !line! > "!inp_file!" 2> "!out_file!"
    
    :: Step B: Run the Validator to ensure input correctness
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
echo DONE! Successfully generated and validated %total% tests. 
echo 100%% format compliance achieved!
echo ==========================================
pause