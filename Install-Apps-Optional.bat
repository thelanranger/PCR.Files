@echo off
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)
mkdir C:\PCR
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
rem xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget settings --enable InstallerHashOverride"
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id Microsoft.Office --source winget" >> C:\PCR\UpdateLog.txt

echo --- Install non-elevated do to issues, UAC Prompt may occur ---
Powershell -Command "Start-Process powershell '-NoProfile -ExecutionPolicy Bypass -Command \"winget install -e --id Microsoft.Office --ignore-security-hash -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"' -Verb RunAsUser"



rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Microsoft.Office -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Install Basic Apps, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

