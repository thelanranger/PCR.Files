mkdir C:\PCR
xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:%~dp0\exclude.txt

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "%~dp0UnInstall-ForcedExtensions.ps1"
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "%~dp0UnInstall-ForcedExtensions.ps1"