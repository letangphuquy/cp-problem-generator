@echo off
:: Phase: Generate Inputs
:: Reads script.txt and produces a .inp file for every requested test.
:: Uses intelligent caching: skips regeneration if gen.cpp and args haven't changed.
::
:: Usage: scripts\phase_generate.bat [--tests <spec>] [--clean]
::
:: Options:
::   --tests <spec>  Which tests to generate (default: all).
::                   Formats: all  01  01,03  01-05  01-03,07
::   --clean         Delete existing .inp files before regenerating.
setlocal EnableDelayedExpansion

SET "TESTS_SPEC=all"
SET "CLEAN="

:: Navigate to the project root (parent of the scripts\ directory).
CD /D "%~dp0.."

:: ---- Parse arguments ----
:PARSE_ARGS
IF "%~1"=="" GOTO ARGS_DONE
IF /I "%~1"=="--tests" ( SET "TESTS_SPEC=%~2" & SHIFT & SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--clean" ( SET "CLEAN=--clean" & SHIFT & GOTO PARSE_ARGS )
IF "%~1"=="/?" GOTO SHOW_HELP
IF /I "%~1"=="--help" GOTO SHOW_HELP
ECHO [ERR ] Unknown option: %~1 >&2
EXIT /B 1
:ARGS_DONE

echo --- Phase: Generate Inputs ---
echo.

:: Call Python utility for intelligent testdata generation with caching
python generate_testdata.py --tests "%TESTS_SPEC%" %CLEAN%
IF ERRORLEVEL 1 (
    ECHO.
    ECHO [ERR ] Generate phase failed >&2
    EXIT /B 1
)

echo.
echo --- Generate phase complete ---
echo.
EXIT /B 0

:SHOW_HELP
ECHO Usage: scripts\phase_generate.bat [--tests ^<spec^>] [--clean]
ECHO.
ECHO Options:
ECHO   --tests ^<spec^>  Tests to generate (default: all)
ECHO                   Formats: all  01  01,03  01-05  01-03,07
ECHO   --clean         Delete existing .inp files before regenerating
GOTO :EOF
