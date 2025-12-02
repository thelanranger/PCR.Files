@echo off
fsutil dirty query %systemdrive% >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as Administrator.
    echo Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)
if not exist "C:\PCR" mkdir "C:\PCR"
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install WinGet if not present........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile \"$env:TEMP\winget-latest.msixbundle\" -UseBasicParsing; ^
     Add-AppxPackage -Path \"$env:TEMP\winget-latest.msixbundle\" -ForceApplicationShutdown"
winget --version >> C:\PCR\UpdateLog.txt

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id Google.Chrome.EXE --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Google.Chrome.EXE -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id Adobe.Acrobat.Reader.64-bit --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Adobe.Acrobat.Reader.64-bit -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"
rem Powershell -ExecutionPolicy "bypass" -NoProfile -Command "Winget upgrade --id Adobe.Acrobat.Reader.64-bit -h --accept-source-agreements --disable-interactivity --verbose --force --uninstall-previous" >> C:\PCR\UpdateLog.txt

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id VideoLAN.VLC --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id VideoLAN.VLC -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id 7zip.7zip --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id 7zip.7zip -h --accept-source-agreements --disable-interactivity --verbose --force --source winget"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Install Basic Apps, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

