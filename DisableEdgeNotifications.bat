@echo off
mkdir C:\PCR
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
rem echo Copy Installer........ >> C:\PCR\UpdateLog.txt
rem xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:"%~dp0exclude.txt"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Disable Edge Notifications........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\DisableEdgeNotifications.ps1" >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Disable Edge Notifications, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

