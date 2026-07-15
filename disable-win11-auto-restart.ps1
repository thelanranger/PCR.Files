#Requires -RunAsAdministrator
# Completely disable Windows 11 automatic restarts (updates + active hours lock).
# Run this in an elevated PowerShell (right-click -> "Run as administrator").

$ErrorActionPreference = 'Stop'

Write-Host "=== Disabling Windows 11 auto-restart ===" -ForegroundColor Cyan

# 1. Disable Windows Update auto-restart (the main culprit)
#    No auto-restart with logged-on users; also block forced restart.
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
    -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
    -Name 'AUOptions' -Value 2 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
    -Name 'NoAutoUpdate' -Value 1 -PropertyType DWord -Force | Out-Null

# 2. Disable the "Restart required to finish installing updates" nagging
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' `
    -Name 'UxOption' -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' `
    -Name 'RestartNotificationsAllowed2' -Value 0 -PropertyType DWord -Force | Out-Null

# 3. Disable scheduled restart task inside Windows Update
$tasks = @(
    '\Microsoft\Windows\UpdateOrchestrator\Reboot',
    '\Microsoft\Windows\WindowsUpdate\Scheduled Start'
)
foreach ($t in $tasks) {
    if (Get-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue) {
        Disable-ScheduledTask -TaskPath (Split-Path $t) -TaskName (Split-Path $t -Leaf) | Out-Null
        Write-Host "  Disabled task: $t"
    }
}

# 4. Stop + disable the Windows Update medic service (which re-enables WU)
Stop-Service -Name WaaSMedicSvc -Force -ErrorAction SilentlyContinue
Set-Service  -Name WaaSMedicSvc -StartupType Disabled
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc' `
    -Name 'Start' -Value 4 -ErrorAction SilentlyContinue

# 5. Push active hours to the maximum (18h instead of the default 12h/18h cap)
#    So Windows thinks you are "always at the computer" and won't restart.
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' `
    -Name 'ActiveHoursStart' -Value 0  -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' `
    -Name 'ActiveHoursMax'   -Value 18 -PropertyType DWord -Force | Out-Null

# 6. Disable auto-restart on sign-out from a colleague / kiosk scenario
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' `
    -Name 'fNoRemoteRecursiveEvents' -Value 1 -PropertyType DWord -Force | Out-Null

# 7. OneDrive + system-initiated reboot suppression (rare but possible)
New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform' `
    -Name 'NoReboot' -Value 1 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null

# 8. Force a policy refresh + stop the Update Orchestrator service once
gpupdate /force | Out-Null
Stop-Service  -Name UsoSvc       -Force -ErrorAction SilentlyContinue
Stop-Service  -Name wuauserv     -Force -ErrorAction SilentlyContinue

Write-Host "`nDone. Automatic restarts are now blocked." -ForegroundColor Green
Write-Host "Tip: keep this script around. Windows 11 feature updates may reset"
Write-Host "     some of these policies - just re-run it after each big update." -ForegroundColor Yellow
