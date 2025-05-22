@echo off
mkdir C:\PCR 
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Execute Install-Apps-winget........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
call C:\PCR\Install-Apps-winget.bat
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Execute Install-AllCustom........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
call C:\PCR\Install-AllCustom.bat
call C:\PCR\DisableChromeNotifications.bat
call C:\PCR\DisableEdgeNotifications.bat
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Complete! %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
