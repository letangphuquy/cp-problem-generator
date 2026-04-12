@echo off
REM Universal C++ compilation utility wrapper for Windows
REM Usage: compile.bat <source1.cpp> [source2.cpp] ...
REM Calls compile.py which handles smart hash-based caching

python compile.py %*
exit /b %errorlevel%
