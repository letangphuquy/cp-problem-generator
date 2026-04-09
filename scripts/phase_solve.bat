@echo off
:: Phase: Solve (Generate Outputs)
:: Runs sol\model.exe on every requested .inp file to produce .out files.
::
:: Usage: scripts\phase_solve.bat [--tests <spec>]
::
:: Options:
::   --tests <spec>  Which tests to solve (default: all).
::                   Formats: all  01  01,03  01-05  01-03,07
setlocal EnableDelayedExpansion

SET "SCRIPTS_DIR=%~dp0"
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

ECHO --- Phase: Solve (Generate Outputs) ---

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
    SET "OUT_FILE=tests\test!_PADDED!.out"

    IF NOT EXIST "!INP_FILE!" (
        ECHO [WARN] test!_PADDED!.inp not found - skipping
    ) ELSE (
        sol\model.exe < "!INP_FILE!" > "!OUT_FILE!"
        IF ERRORLEVEL 1 (
            ECHO [ERR ] test!_PADDED!: model solution failed >&2
            CALL "%SCRIPTS_DIR%common.bat" :LOG_ENTRY "test!_PADDED!" solve fail
            IF EXIST "!OUT_FILE!" DEL /F /Q "!OUT_FILE!"
            SET /A _FAILED+=1
        ) ELSE (
            ECHO  [ OK ] test!_PADDED!.out
            CALL "%SCRIPTS_DIR%common.bat" :LOG_ENTRY "test!_PADDED!" solve ok
        )
    )
)

IF !_FAILED! GTR 0 (
    ECHO [ERR ] Solve phase: !_FAILED! test^(s^) failed. >&2
    EXIT /B 1
)

ECHO --- Solve phase complete ^(!_REQ! tests^) ---
ECHO.
EXIT /B 0

:SHOW_HELP
ECHO Usage: scripts\phase_solve.bat [--tests ^<spec^>]
ECHO.
ECHO Options:
ECHO   --tests ^<spec^>  Tests to solve (default: all)
ECHO                   Formats: all  01  01,03  01-05  01-03,07
GOTO :EOF
