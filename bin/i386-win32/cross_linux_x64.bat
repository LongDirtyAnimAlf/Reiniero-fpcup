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

if '%1'=='noconfirm' (
SET wait=--noconfirm
)

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="default" --lazURL="default" --ostarget="linux" --cputarget="x86_64" --only="FPCCleanOnly,FPCBuildOnly" --skip="FPCGetOnly,lazbuild,bigide,useride" %wait%
)

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux 64 bit ready
ECHO ==============================================
ECHO.
PAUSE