mkdir C:\PCR
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "%~dp0UnInstall-ForcedExtensions.ps1"
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "%~dp0UnInstall-ForcedExtensions.ps1"