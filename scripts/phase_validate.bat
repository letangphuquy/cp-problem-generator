@echo off
:: Phase: Validate Inputs
:: Runs cached validate phase (deterministic skip when input+validator unchanged).
::
:: Usage: scripts\phase_validate.bat [--tests <spec>] [--continue-on-error]
::
:: Options:
::   --tests <spec>       Which tests to validate (default: all).
::                        Formats: all  01  01,03  01-05  01-03,07
::   --continue-on-error  Log failures but keep going instead of aborting on
::                        the first invalid input.
setlocal EnableDelayedExpansion

SET "TESTS_SPEC=all"
SET "CONTINUE_ON_ERR=0"

:: Navigate to the project root (parent of the scripts\ directory).
CD /D "%~dp0.."

:: ---- Parse arguments ----
:PARSE_ARGS
IF "%~1"=="" GOTO ARGS_DONE
IF /I "%~1"=="--tests"            ( SET "TESTS_SPEC=%~2" & SHIFT & SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--continue-on-error"( SET "CONTINUE_ON_ERR=1" & SHIFT & GOTO PARSE_ARGS )
IF "%~1"=="/?" GOTO SHOW_HELP
IF /I "%~1"=="--help" GOTO SHOW_HELP
ECHO [ERR ] Unknown option: %~1 >&2
EXIT /B 1
:ARGS_DONE
SET "CONT_FLAG="
IF "!CONTINUE_ON_ERR!"=="1" SET "CONT_FLAG=--continue-on-error"

python run_phase_cached.py validate --tests "!TESTS_SPEC!" !CONT_FLAG!
IF ERRORLEVEL 1 EXIT /B 1

ECHO.
EXIT /B 0

:SHOW_HELP
ECHO Usage: scripts\phase_validate.bat [--tests ^<spec^>] [--continue-on-error]
ECHO.
ECHO Options:
ECHO   --tests ^<spec^>       Tests to validate (default: all)
ECHO                        Formats: all  01  01,03  01-05  01-03,07
ECHO   --continue-on-error  Don't abort on first failure; log all failures
GOTO :EOF
