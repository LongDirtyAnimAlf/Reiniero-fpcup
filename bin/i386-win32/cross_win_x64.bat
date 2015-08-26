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

if '%1'=='noconfirm' (
SET wait=--noconfirm
)

if EXIST .\fpcup.exe (
fpcup.exe --fpcURL="default" --lazURL="default" --only="crosswin32-64" %wait%
)

ECHO.
ECHO ==============================================
ECHO   Build cross compiler for windows 64 bit ready
ECHO ==============================================
ECHO.
PAUSE