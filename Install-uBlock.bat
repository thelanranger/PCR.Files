mkdir C:\PCR
xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:%~dp0\exclude.txt

echo Install uBlock........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\Install-uBlock.ps1" >> C:\PCR\UpdateLog.txt