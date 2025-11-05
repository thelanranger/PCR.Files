@echo off
mkdir C:\PCR
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
rem xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id Microsoft.Office --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Microsoft.Office -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Install Basic Apps, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

