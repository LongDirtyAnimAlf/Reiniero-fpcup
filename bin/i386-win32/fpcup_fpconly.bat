@ECHO OFF
REM #####################################################
REM               fpcup for windows
REM #####################################################

ECHO.
ECHO ====================================================
ECHO   Fpcup with trunk and defaults; fpc only
ECHO ====================================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="trunk" --lazURL="trunk" --only="fpc,FPCCrossWin32-64"--verbose
)

ECHO.
ECHO ====================================================
ECHO   Fpcup with trunk and defaults ready; fpc only
ECHO ====================================================
ECHO.