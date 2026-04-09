@echo off
:: Common utilities shared by all Windows phase scripts.
::
:: Invoke as:
::   CALL scripts\common.bat :ROUTINE [arg1] [arg2] ...
::
:: Available routines:
::   :COUNT_SCRIPT_TESTS            -> sets _COUNT
::   :PARSE_TEST_SPEC "spec" total  -> writes %TEMP%\cp_gen_tests.tmp
::   :LOG_ENTRY test_id phase status
::   :CLEAR_LOG_ENTRIES test_id
::   :GET_FAILED_TESTS              -> writes %TEMP%\cp_gen_failed.tmp

IF "%~1"=="" GOTO :EOF
GOTO %~1


:: ============================================================
:COUNT_SCRIPT_TESTS
:: Counts non-blank, non-comment lines in script.txt.
:: Returns: _COUNT (in caller's scope via ENDLOCAL trick).
SETLOCAL ENABLEDELAYEDEXPANSION
SET /A _C=0
FOR /F "usebackq eol=# tokens=*" %%L IN ("script.txt") DO SET /A _C+=1
ENDLOCAL & SET _COUNT=%_C%
GOTO :EOF


:: ============================================================
:PARSE_TEST_SPEC
:: Parses a test-spec string and writes zero-padded (2-digit) test numbers
:: to %TEMP%\cp_gen_tests.tmp, one per line.
::
:: Supported formats:  all  05  01,03,07  01-05  01-03,07,10-12
::
:: Args: %~2 = spec string,  %~3 = total test count
SETLOCAL ENABLEDELAYEDEXPANSION
SET "SPEC=%~2"
SET /A TOTAL=%~3
> "%TEMP%\cp_gen_tests.tmp" (
    IF /I "!SPEC!"=="all" (
        FOR /L %%I IN (1,1,%TOTAL%) DO (
            SET "_N=0%%I"
            ECHO !_N:~-2!
        )
    ) ELSE (
        :: Replace commas with spaces so FOR iterates each token.
        SET "SPEC2=!SPEC:,= !"
        FOR %%T IN (!SPEC2!) DO (
            SET "_TOK=%%T"
            :: Detect range by checking if removing hyphens changes the string.
            SET "_NOHYPH=!_TOK:-=!"
            IF NOT "!_TOK!"=="!_NOHYPH!" (
                :: Range token (e.g. 01-05)
                FOR /F "tokens=1,2 delims=-" %%A IN ("!_TOK!") DO (
                    SET "_SA=%%A"
                    SET "_SB=%%B"
                    :: Strip leading zero to avoid octal misinterpretation.
                    IF "!_SA:~0,1!"=="0" SET "_SA=!_SA:~1!"
                    IF "!_SA!"=="" SET "_SA=0"
                    IF "!_SB:~0,1!"=="0" SET "_SB=!_SB:~1!"
                    IF "!_SB!"=="" SET "_SB=0"
                    SET /A "_S=!_SA!"
                    SET /A "_E=!_SB!"
                    FOR /L %%I IN (!_S!,1,!_E!) DO (
                        SET "_N=0%%I"
                        ECHO !_N:~-2!
                    )
                )
            ) ELSE (
                :: Single number token (e.g. 07)
                SET "_V=!_TOK!"
                IF "!_V:~0,1!"=="0" SET "_V=!_V:~1!"
                IF "!_V!"=="" SET "_V=0"
                SET /A "_NUM=!_V!"
                SET "_N=0!_NUM!"
                ECHO !_N:~-2!
            )
        )
    )
)
ENDLOCAL
GOTO :EOF


:: ============================================================
:LOG_ENTRY
:: Appends or replaces an entry in tests\run.log.
:: Format of each log line: "testNN phase ok|fail"
:: Args: %~2 = test_id (e.g. test01),  %~3 = phase,  %~4 = status (ok|fail)
SETLOCAL ENABLEDELAYEDEXPANSION
SET "_TID=%~2"
SET "_PH=%~3"
SET "_ST=%~4"
SET "LOG_FILE=tests\run.log"
IF NOT EXIST tests MD tests
IF NOT EXIST "!LOG_FILE!" COPY NUL "!LOG_FILE!" > NUL
SET "_TMP=!LOG_FILE!.tmp"
:: Rewrite log, replacing the old entry for this test+phase.
> "!_TMP!" (
    FOR /F "usebackq tokens=1,2,3" %%A IN ("!LOG_FILE!") DO (
        IF "%%A"=="!_TID!" (
            IF NOT "%%B"=="!_PH!" ECHO %%A %%B %%C
        ) ELSE (
            ECHO %%A %%B %%C
        )
    )
    ECHO !_TID! !_PH! !_ST!
)
MOVE /Y "!_TMP!" "!LOG_FILE!" > NUL
ENDLOCAL
GOTO :EOF


:: ============================================================
:CLEAR_LOG_ENTRIES
:: Removes all log entries for a given test id.
:: Args: %~2 = test_id (e.g. test01)
SETLOCAL ENABLEDELAYEDEXPANSION
SET "_TID=%~2"
SET "LOG_FILE=tests\run.log"
IF EXIST "!LOG_FILE!" (
    SET "_TMP=!LOG_FILE!.tmp"
    > "!_TMP!" (
        FOR /F "usebackq tokens=1,2,3" %%A IN ("!LOG_FILE!") DO (
            IF NOT "%%A"=="!_TID!" ECHO %%A %%B %%C
        )
    )
    MOVE /Y "!_TMP!" "!LOG_FILE!" > NUL
)
ENDLOCAL
GOTO :EOF


:: ============================================================
:GET_FAILED_TESTS
:: Reads tests\run.log and writes deduplicated, zero-padded failed test
:: numbers to %TEMP%\cp_gen_failed.tmp (one per line).
SETLOCAL ENABLEDELAYEDEXPANSION
SET "LOG_FILE=tests\run.log"
> "%TEMP%\cp_gen_failed.tmp" (
    IF EXIST "!LOG_FILE!" (
        FOR /F "usebackq tokens=1,3" %%A IN ("!LOG_FILE!") DO (
            IF "%%B"=="fail" (
                SET "_ID=%%A"
                SET "_NUM=!_ID:test=!"
                :: Strip leading zero to get decimal value.
                SET "_V=!_NUM!"
                IF "!_V:~0,1!"=="0" SET "_V=!_V:~1!"
                IF "!_V!"=="" SET "_V=0"
                SET /A "_DEC=!_V!"
                SET "_PAD=0!_DEC!"
                :: Only emit if not already seen (deduplication via _SEEN_NN flag).
                SET "_KEY=_SEEN_!_PAD:~-2!"
                IF NOT DEFINED !_KEY! (
                    SET "!_KEY!=1"
                    ECHO !_PAD:~-2!
                )
            )
        )
    )
)
ENDLOCAL
GOTO :EOF
