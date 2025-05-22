@echo off
mkdir C:\PCR
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Begin Install, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Copy Installer........ >> C:\PCR\UpdateLog.txt
xcopy "%~dp0*.*" C:\PCR\ /e /i /y /exclude:"%~dp0exclude.txt"

echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo Install Basic Apps........ >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id Google.Chrome.EXE --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Google.Chrome.EXE --source winget" >> C:\PCR\UpdateLog.txt

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id Adobe.Acrobat.Reader.64-bit --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id Adobe.Acrobat.Reader.64-bit --source winget" >> C:\PCR\UpdateLog.txt

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id VideoLAN.VLC --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id VideoLAN.VLC --source winget" >> C:\PCR\UpdateLog.txt

Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget show --id 7zip.7zip --source winget" >> C:\PCR\UpdateLog.txt
Powershell -ExecutionPolicy "bypass" -NoProfile -Command "winget install -e --id 7zip.7zip --source winget" >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt
echo End Install Basic Apps, %date%, %time% >> C:\PCR\UpdateLog.txt
echo ----------------------------------------------------------------------------------------------------- >> C:\PCR\UpdateLog.txt

