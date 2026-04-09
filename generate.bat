@echo off
:: Orchestrator: Automated Test Generator + Validator
::
:: Usage: generate.bat [options]
::
:: Options:
::   --phases <list>       Comma-separated phases to execute.
::                         Valid phases: compile, generate, validate, solve
::                         Default: compile,generate,validate,solve
::   --tests <spec>        Which tests to process (applies to every phase
::                         except compile).
::                         Formats: all  01  01,03  01-05  01-03,07
::                         Default: all
::   --retry               Re-run only tests that failed in the previous run.
::                         Reads tests\run.log; skips compile unless it is
::                         explicitly listed in --phases.
::   --continue-on-error   Do not abort on the first validation failure;
::                         log all failures and continue.
::   --clean               Remove .inp files for selected tests before
::                         regenerating them.
::   /?  --help            Show this help message.
::
:: Examples:
::   generate.bat
::       Full run: compile everything, generate all tests, validate, solve.
::
::   generate.bat --phases generate,validate,solve --tests 01-10
::       Skip compile; (re)generate tests 01-10 only.
::
::   generate.bat --retry
::       Re-run generate->validate->solve for every test that failed last time.
::
::   generate.bat --phases validate --tests 03,07
::       Re-validate only tests 03 and 07 (binaries already compiled).
::
::   generate.bat --phases compile
::       Recompile all binaries without touching the tests directory.
setlocal EnableDelayedExpansion

SET "SCRIPTS_DIR=%~dp0scripts\"
SET "PHASES=compile,generate,validate,solve"
SET "TESTS_SPEC=all"
SET "RETRY=0"
SET "CONTINUE_ON_ERR=0"
SET "CLEAN=0"

:: ---- Parse arguments ----
:PARSE_ARGS
IF "%~1"=="" GOTO ARGS_DONE
IF /I "%~1"=="--phases"            ( SET "PHASES=%~2"      & SHIFT & SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--tests"             ( SET "TESTS_SPEC=%~2"  & SHIFT & SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--retry"             ( SET "RETRY=1"          & SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--continue-on-error" ( SET "CONTINUE_ON_ERR=1"& SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--clean"             ( SET "CLEAN=1"          & SHIFT & GOTO PARSE_ARGS )
IF    "%~1"=="/?"                    GOTO SHOW_HELP
IF /I "%~1"=="--help"                GOTO SHOW_HELP
ECHO [ERR ] Unknown option: %~1 >&2
ECHO Run 'generate.bat /?' for usage. >&2
EXIT /B 1
:ARGS_DONE

:: ---- Handle --retry ----
IF "!RETRY!"=="1" (
    CALL "!SCRIPTS_DIR!common.bat" :GET_FAILED_TESTS
    SET "FAILED_SPEC="
    FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_failed.tmp") DO (
        IF "!FAILED_SPEC!"=="" (
            SET "FAILED_SPEC=%%N"
        ) ELSE (
            SET "FAILED_SPEC=!FAILED_SPEC!,%%N"
        )
    )
    IF "!FAILED_SPEC!"=="" (
        ECHO No failed tests in log. Nothing to retry.
        EXIT /B 0
    )
    SET "TESTS_SPEC=!FAILED_SPEC!"
    ECHO [INFO] Retrying failed test^(s^): !TESTS_SPEC!
    :: Skip compile unless the caller explicitly asked for it.
    IF "!PHASES!"=="compile,generate,validate,solve" SET "PHASES=generate,validate,solve"
)

:: ---- Banner ----
ECHO ==========================================
ECHO    AUTOMATED TEST GENERATOR + VALIDATOR
ECHO ==========================================
ECHO   Phases : !PHASES!
ECHO   Tests  : !TESTS_SPEC!
IF "!RETRY!"=="1" ECHO   Mode   : retry ^(failed tests only^)
ECHO.

:: ---- Execute requested phases ----
:: Replace commas with spaces so FOR can iterate each phase token.
SET "PHASES2=!PHASES:,= !"
FOR %%P IN (!PHASES2!) DO (
    SET "_PHASE=%%P"
    SET "_PHASE_RAN=0"

    IF /I "!_PHASE!"=="compile" (
        SET "_PHASE_RAN=1"
        CALL "!SCRIPTS_DIR!phase_compile.bat"
    )
    IF /I "!_PHASE!"=="generate" (
        SET "_PHASE_RAN=1"
        IF "!CLEAN!"=="1" (
            CALL "!SCRIPTS_DIR!phase_generate.bat" --tests "!TESTS_SPEC!" --clean
        ) ELSE (
            CALL "!SCRIPTS_DIR!phase_generate.bat" --tests "!TESTS_SPEC!"
        )
    )
    IF /I "!_PHASE!"=="validate" (
        SET "_PHASE_RAN=1"
        IF "!CONTINUE_ON_ERR!"=="1" (
            CALL "!SCRIPTS_DIR!phase_validate.bat" --tests "!TESTS_SPEC!" --continue-on-error
        ) ELSE (
            CALL "!SCRIPTS_DIR!phase_validate.bat" --tests "!TESTS_SPEC!"
        )
    )
    IF /I "!_PHASE!"=="solve" (
        SET "_PHASE_RAN=1"
        CALL "!SCRIPTS_DIR!phase_solve.bat" --tests "!TESTS_SPEC!"
    )

    IF "!_PHASE_RAN!"=="0" (
        ECHO [ERR ] Unknown phase: '!_PHASE!'. >&2
        ECHO Valid phases: compile, generate, validate, solve >&2
        EXIT /B 1
    )
    IF ERRORLEVEL 1 EXIT /B 1
)

:: ---- Summary ----
CALL "!SCRIPTS_DIR!common.bat" :COUNT_SCRIPT_TESTS
CALL "!SCRIPTS_DIR!common.bat" :PARSE_TEST_SPEC "!TESTS_SPEC!" !_COUNT!
SET /A _PROCESSED=0
FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_tests.tmp") DO SET /A _PROCESSED+=1
ECHO DONE! Successfully processed !_PROCESSED! test^(s^).
GOTO :EOF


:SHOW_HELP
ECHO Usage: generate.bat [options]
ECHO.
ECHO Options:
ECHO   --phases ^<list^>       Phases to run (default: compile,generate,validate,solve)
ECHO   --tests ^<spec^>        Tests to process (default: all)
ECHO                         Formats: all  01  01,03  01-05  01-03,07
ECHO   --retry               Re-run only tests that failed last time
ECHO   --continue-on-error   Don't abort on first validation failure
ECHO   --clean               Delete .inp files before regenerating
ECHO   /?  --help            Show this message
ECHO.
ECHO Examples:
ECHO   generate.bat
ECHO       Full run: compile, generate all tests, validate, solve.
ECHO.
ECHO   generate.bat --phases generate,validate,solve --tests 01-10
ECHO       Skip compile; regenerate tests 01-10 only.
ECHO.
ECHO   generate.bat --retry
ECHO       Re-run generate-validate-solve for previously failed tests.
ECHO.
ECHO   generate.bat --phases validate --tests 03,07
ECHO       Re-validate only tests 03 and 07.
ECHO.
ECHO   generate.bat --phases compile
ECHO       Recompile all binaries without touching tests/.
GOTO :EOF
