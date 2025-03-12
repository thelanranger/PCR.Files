rem InstallOnce.bat
rem Identify the USB drive by checking all removable drives
for %%d in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do (
    if exist %%d:\PCR.Files\ (
        set USBDRIVE=%%d
    )
)

:: Verify that the USB drive is identified
if "%USBDRIVE%"=="" (
    echo No USB drive detected. Exiting.
    exit /b 1
)


rem Copy Files and Install Apps
@echo off
mkdir C:\PCR
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\InstallChrome.ps1" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\InstallAdobe.ps1" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\InstallVLC.ps1" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "C:\PCR\RemoteApps\Install7zip.ps1" >> C:\PCR\UpdateLog.txt

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps Complete........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

exit /b 0
