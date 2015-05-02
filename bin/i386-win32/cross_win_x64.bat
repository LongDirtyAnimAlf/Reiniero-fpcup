@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM             cross compile script.
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for windows 64 bit
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="trunk" --lazURL="trunk" --ostarget="win64" --cputarget="x86_64"
)

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for windows 64 bit ready
ECHO ==============================================
ECHO.