@ECHO OFF
REM #####################################################
REM               fpcup for windows
REM #####################################################

ECHO.
ECHO ====================================================
ECHO   Fpcup with trunk and defaults; Lazarus only
ECHO ====================================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="trunk" --lazURL="trunk" --skip="fpc,FPCCrossWin32-64" --verbose
)

ECHO.
ECHO ====================================================
ECHO   Fpcup with trunk and defaults ready; Lazarus only
ECHO ====================================================
ECHO.