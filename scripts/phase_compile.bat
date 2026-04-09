@echo off
:: Phase: Compile
:: Compiles gen.exe, val.exe, and sol\model.exe from source.
::
:: Usage: scripts\phase_compile.bat
setlocal EnableDelayedExpansion

:: Navigate to the project root (parent of the scripts\ directory).
CD /D "%~dp0.."

echo --- Phase: Compile ---

echo   Compiling gen.cpp...
g++ -O3 -std=c++17 gen.cpp -o gen.exe
IF ERRORLEVEL 1 (
    echo [ERR ] Failed to compile gen.cpp >&2
    EXIT /B 1
)
echo  [ OK ] Compiled gen.cpp -^> gen.exe

echo   Compiling validator.cpp...
g++ -O3 -std=c++17 validator.cpp -o val.exe
IF ERRORLEVEL 1 (
    echo [ERR ] Failed to compile validator.cpp >&2
    EXIT /B 1
)
echo  [ OK ] Compiled validator.cpp -^> val.exe

echo   Compiling sol\model.cpp...
g++ -O3 -std=c++17 sol\model.cpp -o sol\model.exe
IF ERRORLEVEL 1 (
    echo [ERR ] Failed to compile sol\model.cpp >&2
    EXIT /B 1
)
echo  [ OK ] Compiled sol\model.cpp -^> sol\model.exe

echo --- Compile phase complete ---
echo.
EXIT /B 0
