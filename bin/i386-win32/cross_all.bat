@ECHO OFF
REM ###############################################
REM               fpcup for windows
REM          run all cross compile scripts
REM ###############################################

ECHO.
ECHO ==============================================
ECHO   Build all cross compilers
ECHO ==============================================
ECHO.

if EXIST .\fpcup.exe (
start /wait cross_android_arm.bat noconfirm
start /wait cross_linux_arm.bat noconfirm
start /wait cross_linux_armhf.bat noconfirm
start /wait cross_linux_i386.bat noconfirm
start /wait cross_linux_x64.bat noconfirm
start /wait cross_win_x64.bat noconfirm
)

ECHO.
ECHO ==============================================
ECHO   Build all cross compilers ready
ECHO ==============================================
ECHO.
PAUSE