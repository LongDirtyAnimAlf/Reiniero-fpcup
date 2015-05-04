@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM             cross compile script.
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux arm hardfloat
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="default" --lazURL="default" --ostarget="linux" --cputarget="arm" --fpcOPT="-dFPC_ARMHF" --crossOPT="-CpARMV7A -CfVFPV3 -OoFASTMATH -CaEABIHF" --only="FPCCleanOnly,FPCBuildOnly" --skip="FPCGetOnly,lazbuild,bigide,useride"
)

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for linux arm ready
ECHO ==============================================
ECHO.
PAUSE