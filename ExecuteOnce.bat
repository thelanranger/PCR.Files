@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)
if not exist "C:\PCR" mkdir "C:\PCR"
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Execute Install-Apps-winget........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
call C:\PCR\Install-Apps-winget.bat
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Execute Install-AllCustom........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
call C:\PCR\Install-AllCustom.bat
call C:\PCR\DisableChromeNotifications.bat
call C:\PCR\DisableEdgeNotifications.bat
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Complete! %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
