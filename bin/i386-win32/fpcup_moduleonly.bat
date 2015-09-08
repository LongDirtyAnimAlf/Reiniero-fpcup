@ECHO OFF
REM #####################################################
REM               fpcup for windows
REM #####################################################

ECHO.
ECHO ====================================================
ECHO   Fpcup for modules only:
ECHO   install a single module (zeos) only
ECHO   or install multiple modules only
ECHO ====================================================
ECHO.

if EXIST .\fpcup.exe (
fpcup.exe --only="zeos" --verbose
)

REM fpcup.exe --only="lazpaint,bgracontrols,bgragames,ecc,indy,turbobird,notepas,uos,lazradio,treelistview" --verbose
ECHO.
ECHO ====================================================
ECHO   Fpcup for modules only
ECHO ====================================================
ECHO.
PAUSE