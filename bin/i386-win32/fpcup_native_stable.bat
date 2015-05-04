@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Fpcup stable and defaults
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="stable" --lazURL="stable" --verbose
)

ECHO.
ECHO ==============================================
ECHO   Fpcup stable and defaults ready
ECHO ==============================================
ECHO.
PAUSE