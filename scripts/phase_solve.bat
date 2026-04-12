@echo off
:: Phase: Solve (Generate Outputs)
:: Runs cached solve phase (skip when input+model unchanged and output hash matches).
::
:: Usage: scripts\phase_solve.bat [--tests <spec>]
::
:: Options:
::   --tests <spec>  Which tests to solve (default: all).
::                   Formats: all  01  01,03  01-05  01-03,07
setlocal EnableDelayedExpansion

SET "TESTS_SPEC=all"

:: Navigate to the project root (parent of the scripts\ directory).
CD /D "%~dp0.."

:: ---- Parse arguments ----
:PARSE_ARGS
IF "%~1"=="" GOTO ARGS_DONE
IF /I "%~1"=="--tests" ( SET "TESTS_SPEC=%~2" & SHIFT & SHIFT & GOTO PARSE_ARGS )
IF "%~1"=="/?" GOTO SHOW_HELP
IF /I "%~1"=="--help" GOTO SHOW_HELP
ECHO [ERR ] Unknown option: %~1 >&2
EXIT /B 1
:ARGS_DONE
python run_phase_cached.py solve --tests "!TESTS_SPEC!"
IF ERRORLEVEL 1 EXIT /B 1

ECHO.
EXIT /B 0

:SHOW_HELP
ECHO Usage: scripts\phase_solve.bat [--tests ^<spec^>]
ECHO.
ECHO Options:
ECHO   --tests ^<spec^>  Tests to solve (default: all)
ECHO                   Formats: all  01  01,03  01-05  01-03,07
GOTO :EOF
