mkdir C:\PCR
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo UnInstall uBlock........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\UnInstall-ForcedExtensions.ps1"