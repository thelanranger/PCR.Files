mkdir C:\PCR
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo Disable Windows 11 Automatic Update Restart........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\disable-win11-auto-restart.ps1" >> C:\PCR\UpdateLog.txt