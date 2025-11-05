@echo off
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin All Custom, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
mkdir C:\PCR
xcopy "%~dp0*.*" C:\PCR\ /e /i /y
rem  /exclude:"%~dp0exclude.txt"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install uBlock........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\Install-uBlock.ps1" >> C:\PCR\UpdateLog.txt
echo Install Win10 Custom, Per User Policies........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\Win11-Custom-CU.ps1" >> C:\PCR\UpdateLog.txt
echo Install Win10 Custom, Per Device Policies........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\Win10-Custom-LM.ps1" >> C:\PCR\UpdateLog.txt
echo VSS Create........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\VSS-Create.ps1" >> C:\PCR\UpdateLog.txt
echo Enable Registry Backup........ >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\Enable-RegBackup.ps1" >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo All-Custom Complete, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt