@echo off
:: Phase: Compile
:: Compiles gen.exe, val.exe, and sol\model.exe from source.
:: Uses compile.py utility with smart file hash caching.
::
:: Usage: scripts\phase_compile.bat
setlocal EnableDelayedExpansion

:: Navigate to the project root (parent of the scripts\ directory).
CD /D "%~dp0.."

echo --- Phase: Compile ---
echo.
python compile.py gen.cpp validator.cpp sol\model.cpp
IF ERRORLEVEL 1 (
    echo.
    echo [ERR ] Compilation failed >&2
    EXIT /B 1
)

echo.
echo --- Compile phase complete ---
echo.
EXIT /B 0
