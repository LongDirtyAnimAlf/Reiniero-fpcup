@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM             cross compile script.
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux 64 bit
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="trunk" --lazURL="trunk" --ostarget="linux" --cputarget="x86_64" --only="FPCCleanOnly,FPCBuildOnly" --skip="FPCGetOnly,lazbuild,bigide,useride"
)

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux 64 bit ready
ECHO ==============================================
ECHO.