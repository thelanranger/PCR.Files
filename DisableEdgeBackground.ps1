# Script to stop Edge from running perpetually in the background

# Stop all current Edge processes
Get-Process -Name "msedge" -ErrorAction SilentlyContinue | Stop-Process -Force

# Add a registry key to disable background mode
$RegPath = "HKCU:\Software\Policies\Microsoft\Edge"
If (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
New-ItemProperty -Path $RegPath -Name "BackgroundModeEnabled" -Value 0 -Type DWORD -Force | Out-Null

# Add registry keys to disable Startup Boost and the Sidebar
New-ItemProperty -Path $RegPath -Name "StartupBoostEnabled" -Value 0 -Type DWORD -Force | Out-Null
New-ItemProperty -Path $RegPath -Name "StandaloneHubsSidebarEnabled" -Value 0 -Type DWORD -Force | Out-Null

Write-Host "Microsoft Edge background running and startup boost disabled. Restart Edge for changes to take effect."

# Disable Microsoft Edge Update Task Machine Core
Schtasks.exe /Change /TN "\Microsoft\EdgeUpdate\msedgeupdateTaskMachineCore" /Disable

# Disable Microsoft Edge Update Task Machine UA
Schtasks.exe /Change /TN "\Microsoft\EdgeUpdate\msedgeupdateTaskMachineUA" /Disable

Write-Host "Microsoft Edge scheduled tasks disabled."
