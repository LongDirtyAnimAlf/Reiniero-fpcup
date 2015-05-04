@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM             cross compile script.
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux arm
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="trunk" --lazURL="default" --ostarget="default" --cputarget="arm" --crossOPT="-CpARMV6 -CfVFPV2" --only="FPCCleanOnly,FPCBuildOnly" --skip="FPCGetOnly,lazbuild,bigide,useride"
)

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux arm ready
ECHO ==============================================
ECHO.
PAUSE