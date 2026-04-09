@echo off
:: Phase: Validate Inputs
:: Runs val.exe against every requested .inp file.
::
:: Usage: scripts\phase_validate.bat [--tests <spec>] [--continue-on-error]
::
:: Options:
::   --tests <spec>       Which tests to validate (default: all).
::                        Formats: all  01  01,03  01-05  01-03,07
::   --continue-on-error  Log failures but keep going instead of aborting on
::                        the first invalid input.
setlocal EnableDelayedExpansion

SET "SCRIPTS_DIR=%~dp0"
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

ECHO --- Phase: Validate Inputs ---

:: Count total runnable tests.
CALL "%SCRIPTS_DIR%common.bat" :COUNT_SCRIPT_TESTS

:: Build list of requested test numbers.
CALL "%SCRIPTS_DIR%common.bat" :PARSE_TEST_SPEC "!TESTS_SPEC!" !_COUNT!

SET /A _REQ=0
FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_tests.tmp") DO SET /A _REQ+=1
IF !_REQ! EQU 0 (
    ECHO [WARN] No tests matched spec: !TESTS_SPEC!
    EXIT /B 0
)

SET /A _FAILED=0
FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_tests.tmp") DO (
    SET "_PADDED=%%N"
    SET "INP_FILE=tests\test!_PADDED!.inp"

    IF NOT EXIST "!INP_FILE!" (
        ECHO [WARN] test!_PADDED!.inp not found - skipping
    ) ELSE (
        val.exe < "!INP_FILE!" > NUL 2>&1
        IF ERRORLEVEL 1 (
            ECHO [ERR ] test!_PADDED!.inp  [INVALID] >&2
            CALL "%SCRIPTS_DIR%common.bat" :LOG_ENTRY "test!_PADDED!" validate fail
            SET /A _FAILED+=1
            IF "!CONTINUE_ON_ERR!"=="0" (
                ECHO [ERR ] Stopping on first validation failure. Use --continue-on-error to continue. >&2
                EXIT /B 1
            )
        ) ELSE (
            ECHO  [ OK ] test!_PADDED!.inp  [valid]
            CALL "%SCRIPTS_DIR%common.bat" :LOG_ENTRY "test!_PADDED!" validate ok
        )
    )
)

IF !_FAILED! GTR 0 (
    ECHO [ERR ] Validate phase: !_FAILED! test^(s^) failed. >&2
    EXIT /B 1
)

ECHO --- Validate phase complete ^(!_REQ! tests^) ---
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
