@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Fpcup with trunk and defaults
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="trunk" --lazURL="trunk" --verbose
)

ECHO.
ECHO ==============================================
ECHO   Fpcup with trunk and defaults ready
ECHO ==============================================
ECHO.
PAUSE