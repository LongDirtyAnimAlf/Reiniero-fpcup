@ECHO OFF
REM #####################################################
REM               fpcup for windows
REM #####################################################

ECHO.
ECHO ====================================================
ECHO   Fpcup default; Lazarus only
ECHO ====================================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="default" --lazURL="default" --skip="fpc,FPCCrossWin32-64" --verbose
)

ECHO.
ECHO ====================================================
ECHO   Fpcup default ready; Lazarus only
ECHO ====================================================
ECHO.
PAUSE