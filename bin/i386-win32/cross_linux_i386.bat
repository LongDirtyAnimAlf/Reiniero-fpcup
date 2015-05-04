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

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="default" --lazURL="default" --ostarget="linux" --cputarget="i386" --only="FPCCleanOnly,FPCBuildOnly" --skip="FPCGetOnly,lazbuild,bigide,useride"
)

ECHO.
ECHO ============================================
ECHO   Build cross compiler for linux i386 ready
ECHO ============================================
ECHO.
PAUSE