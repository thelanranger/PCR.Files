@echo off
mkdir C:\PCR
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:"%~dp0exclude.txt"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Disable Chrome Notifications........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\DisableChromeNotifications.ps1" >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Disable Chrome Notifications, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

