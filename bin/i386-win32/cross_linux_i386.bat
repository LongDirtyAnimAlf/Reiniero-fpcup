@ECHO OFF
REM #############################################
REM              fpcup for windows
REM            cross compile script.
REM #############################################

ECHO.
ECHO ============================================
ECHO   Build cross compiler for linux i386   
ECHO ============================================
ECHO.

if '%1'=='noconfirm' (
SET wait=--noconfirm
)

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="default" --ostarget="linux" --cputarget="i386" --only="FPCCleanOnly,FPCBuildOnly" --skip="FPCGetOnly,lazbuild,bigide,useride" %wait%
)

ECHO.
ECHO ============================================
ECHO   Build cross compiler for linux i386 ready
ECHO ============================================
ECHO.
PAUSE