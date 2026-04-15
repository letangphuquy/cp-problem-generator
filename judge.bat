@echo off
setlocal
python "%~dp0judge.py" %*
exit /b %errorlevel%
