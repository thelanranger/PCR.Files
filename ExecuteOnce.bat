@echo off
mkdir C:\PCR 
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:%~dp0\exclude.txt

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Execute Install-Apps........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
call C:\PCR\Install-Apps.bat
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Execute Install-AllCustom........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
call C:\PCR\Install-AllCustom.bat
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Complete! %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

