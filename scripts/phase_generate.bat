@echo off
:: Phase: Generate Inputs
:: Reads script.txt and produces a .inp file for every requested test.
::
:: Usage: scripts\phase_generate.bat [--tests <spec>] [--clean]
::
:: Options:
::   --tests <spec>  Which tests to generate (default: all).
::                   Formats: all  01  01,03  01-05  01-03,07
::   --clean         Delete existing .inp files before regenerating.
setlocal EnableDelayedExpansion

SET "SCRIPTS_DIR=%~dp0"
SET "TESTS_SPEC=all"
SET "CLEAN=0"

:: Navigate to the project root (parent of the scripts\ directory).
CD /D "%~dp0.."

:: ---- Parse arguments ----
:PARSE_ARGS
IF "%~1"=="" GOTO ARGS_DONE
IF /I "%~1"=="--tests" ( SET "TESTS_SPEC=%~2" & SHIFT & SHIFT & GOTO PARSE_ARGS )
IF /I "%~1"=="--clean" ( SET "CLEAN=1" & SHIFT & GOTO PARSE_ARGS )
IF "%~1"=="/?" GOTO SHOW_HELP
IF /I "%~1"=="--help" GOTO SHOW_HELP
ECHO [ERR ] Unknown option: %~1 >&2
EXIT /B 1
:ARGS_DONE

echo --- Phase: Generate Inputs ---

IF NOT EXIST tests MD tests

:: Count total runnable tests in script.txt.
CALL "%SCRIPTS_DIR%common.bat" :COUNT_SCRIPT_TESTS
IF !_COUNT! EQU 0 (
    ECHO [ERR ] No test cases found in script.txt >&2
    EXIT /B 1
)

:: Build list of requested test numbers into temp file.
CALL "%SCRIPTS_DIR%common.bat" :PARSE_TEST_SPEC "!TESTS_SPEC!" !_COUNT!

:: Count requested tests.
SET /A _REQ=0
FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_tests.tmp") DO SET /A _REQ+=1
IF !_REQ! EQU 0 (
    ECHO [WARN] No tests matched spec: !TESTS_SPEC!
    EXIT /B 0
)

:: Build a "set" of requested test numbers for O(1) lookup: _REQ_01=1, etc.
FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_tests.tmp") DO SET "_REQ_%%N=1"

:: Read script.txt lines into indexed variables: _LINE_1, _LINE_2, ...
SET /A _LIDX=0
FOR /F "usebackq eol=# tokens=*" %%L IN ("script.txt") DO (
    SET /A _LIDX+=1
    SET "_LINE_!_LIDX!=%%L"
)

:: Iterate requested tests and generate each .inp file.
SET /A _FAILED=0
FOR /F "usebackq tokens=*" %%N IN ("%TEMP%\cp_gen_tests.tmp") DO (
    SET "_PADDED=%%N"

    :: Derive decimal index from zero-padded number.
    SET "_PIDX=!_PADDED!"
    IF "!_PIDX:~0,1!"=="0" SET "_PIDX=!_PIDX:~1!"
    IF "!_PIDX!"=="" SET "_PIDX=0"

    :: Check range.
    IF !_PIDX! GTR !_LIDX! (
        ECHO [WARN] test!_PADDED! is out of range ^(only !_LIDX! tests in script.txt^) - skipping
    ) ELSE (
        :: Retrieve the script line for this test (indirect variable lookup).
        SET "_VAR=_LINE_!_PIDX!"
        CALL SET "_LINE=%%!_VAR!%%"

        SET "INP_FILE=tests\test!_PADDED!.inp"

        :: Clean if requested.
        IF "!CLEAN!"=="1" IF EXIST "!INP_FILE!" DEL /F /Q "!INP_FILE!"

        :: Clear log entries before generating fresh ones.
        CALL "%SCRIPTS_DIR%common.bat" :CLEAR_LOG_ENTRIES "test!_PADDED!"

        :: Generate the .inp file.
        gen.exe !_LINE! > "!INP_FILE!" 2> NUL
        IF ERRORLEVEL 1 (
            ECHO [ERR ] test!_PADDED!.inp - gen failed  ^(gen.exe !_LINE!^) >&2
            CALL "%SCRIPTS_DIR%common.bat" :LOG_ENTRY "test!_PADDED!" generate fail
            SET /A _FAILED+=1
        ) ELSE (
            ECHO  [ OK ] test!_PADDED!.inp  ^(gen !_LINE!^)
            CALL "%SCRIPTS_DIR%common.bat" :LOG_ENTRY "test!_PADDED!" generate ok
        )
    )
)

IF !_FAILED! GTR 0 (
    ECHO [ERR ] Generate phase: !_FAILED! test^(s^) failed. >&2
    EXIT /B 1
)

ECHO --- Generate phase complete ^(!_REQ! tests^) ---
ECHO.
EXIT /B 0

:SHOW_HELP
ECHO Usage: scripts\phase_generate.bat [--tests ^<spec^>] [--clean]
ECHO.
ECHO Options:
ECHO   --tests ^<spec^>  Tests to generate (default: all)
ECHO                   Formats: all  01  01,03  01-05  01-03,07
ECHO   --clean         Delete existing .inp files before regenerating
GOTO :EOF
