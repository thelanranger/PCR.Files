@echo off
net session >nul 2>&1
if %errorlevel% equ 0 (
    echo This script should NOT be run as Administrator.
    echo Please run this as a regular user (double-click normally).
    pause
    exit /b 1
)
if not exist "C:\PCR" mkdir "C:\PCR"
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:"%~dp0exclude.txt"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps ignoring security hash........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\InstallChrome.ps1" >> C:\PCR\UpdateLog.txt
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\InstallAdobe.ps1" >> C:\PCR\UpdateLog.txt
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\InstallVLC.ps1" >> C:\PCR\UpdateLog.txt
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\Install7zip.ps1" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Microsoft.Office --ignore-security-hash -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Install Basic Apps, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt