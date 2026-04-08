@echo off
setlocal EnableDelayedExpansion

echo ==========================================
echo    AUTOMATED TEST GENERATOR (3-PHASE)
echo ==========================================
echo.

:: ======================================================================
:: KHOI TAO & BIEN DICH
:: ======================================================================
echo [0/4] Compiling infrastructure and solutions...
g++ -O3 -std=c++17 gen.cpp -o gen.exe
if errorlevel 1 ( echo [Error] gen.cpp failed! & exit /b 1 )

g++ -O3 -std=c++17 validator.cpp -o val.exe
if errorlevel 1 ( echo [Error] validator.cpp failed! & exit /b 1 )

g++ -O3 -std=c++17 sol\model.cpp -o sol\model.exe
if errorlevel 1 ( echo [Error] sol\model.cpp failed! & exit /b 1 )

echo - Compilation successful!
echo.

echo [1/4] Cleaning up 'tests' directory...
if not exist tests mkdir tests
del /Q tests\*
echo.

:: ======================================================================
:: PHASE 1: GENERATE ALL INPUTS
:: ======================================================================
echo [2/4] PHASE 1: Generating Inputs...
set test_idx=1

for /f "usebackq eol=# tokens=*" %%A in ("script.txt") do (
    set "line=%%A"
    set "padded=0!test_idx!"
    set "padded=!padded:~-2!"
    set "inp_file=tests\test!padded!.inp"
    
    gen.exe !line! > "!inp_file!" 2> NUL
    echo   [-] Generated test!padded!.inp ^(gen.exe !line!^)
    
    set /a test_idx+=1
)
echo.

:: ======================================================================
:: PHASE 2: VALIDATE ALL INPUTS
:: ======================================================================
echo [3/4] PHASE 2: Validating Inputs...
set val_count=0

for %%F in (tests\*.inp) do (
    val.exe < "%%F"
    if !errorlevel! neq 0 (
        echo.
        echo ==========================================
        echo [FATAL ERROR] Validator failed on file: %%F
        echo Halt execution!
        echo ==========================================
        pause
        exit /b 1
    )
    set /a val_count+=1
)
echo   [+] Successfully validated !val_count! input files.
echo.

:: ======================================================================
:: PHASE 3: GENERATE ALL OUTPUTS (MODEL SOLUTION)
:: ======================================================================
echo [4/4] PHASE 3: Generating Outputs (Model)...
set sol_count=0

for %%F in (tests\*.inp) do (
    set "inp_file=%%F"
    set "out_file=!inp_file:.inp=.out!"
    
    sol\model.exe < "!inp_file!" > "!out_file!"
    echo   [*] Solved !out_file!
    
    set /a sol_count+=1
)

echo.
echo ==========================================
echo DONE! Successfully processed !sol_count! tests.
echo ==========================================
pause