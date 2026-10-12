@echo off
rem Removes the .qrep association that the portable Quds Report Studio
rem registers for the current user on its first run. Delete the folder after.
reg delete "HKCU\Software\Classes\QudsReportStudio.qrep" /f >nul 2>&1
reg delete "HKCU\Software\Classes\.qrep" /f >nul 2>&1
echo .qrep files are no longer associated with Quds Report Studio.
pause
