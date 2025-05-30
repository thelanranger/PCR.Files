#main.ps1






function DisableChromeNotifications {
    # Disable notifications for all Chrome profiles on a Windows computer

    # Define the path to Chrome's user data directory
    $chromeUserDataPath = "$env:LOCALAPPDATA\Google\Chrome\User Data"

    # Function to process a single preferences file
    function Disable-NotificationsInProfile {
        param (
            [string]$prefsFile
        )
    
        try {
            # Check if preferences file exists
            if (Test-Path $prefsFile) {
                # Read the JSON content
                $jsonContent = Get-Content $prefsFile -Raw | ConvertFrom-Json
            
                # Ensure notifications section exists
                if (-not $jsonContent.profile) {
                    $jsonContent | Add-Member -MemberType NoteProperty -Name "profile" -Value @{}
                }
            
                # Set notifications to disabled (2 = blocked)
                $jsonContent.profile | Add-Member -MemberType NoteProperty -Name "content_settings" -Value @{ 
                    "exceptions" = @{
                        "notifications" = @{}
                    }
                } -Force
                $jsonContent.profile.content_settings.exceptions.notifications = @{
                    "*" = @{
                        "setting" = 2
                    }
                }
            
                # Write back the modified JSON
                $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $prefsFile
                Write-Host "Updated notifications settings in $prefsFile"
            }
        }
        catch {
            Write-Warning "Error processing $prefsFile : $_"
        }
    }

    # Check if Chrome user data directory exists
    if (-not (Test-Path $chromeUserDataPath)) {
        Write-Warning "Chrome user data directory not found at $chromeUserDataPath"
        exit
    }

    # Get all profile directories (Default and Profile *)
    $profiles = Get-ChildItem -Path $chromeUserDataPath -Directory | 
        Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }

    # Process each profile
    foreach ($profile in $profiles) {
        $prefsFile = Join-Path $profile.FullName "Preferences"
        Disable-NotificationsInProfile -prefsFile $prefsFile
    }

    Write-Host "Completed processing all Chrome profiles"

    "Disable Notifications Chrome, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}


function DisableEdgeNotifications {
    # Disable notifications for all Microsoft Edge profiles on a Windows computer

    # Define the path to Edge's user data directory
    $edgeUserDataPath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"

    # Function to process a single preferences file
    function Disable-NotificationsInProfile {
        param (
            [string]$prefsFile
        )
    
        try {
            # Check if preferences file exists
            if (Test-Path $prefsFile) {
                # Read the JSON content
                $jsonContent = Get-Content $prefsFile -Raw | ConvertFrom-Json
            
                # Ensure notifications section exists
                if (-not $jsonContent.profile) {
                    $jsonContent | Add-Member -MemberType NoteProperty -Name "profile" -Value @{}
                }
            
                # Set notifications to disabled (2 = blocked)
                $jsonContent.profile | Add-Member -MemberType NoteProperty -Name "content_settings" -Value @{ 
                    "exceptions" = @{
                        "notifications" = @{}
                    }
                } -Force
                $jsonContent.profile.content_settings.exceptions.notifications = @{
                    "*" = @{
                        "setting" = 2
                    }
                }
            
                # Write back the modified JSON
                $jsonContent | ConvertTo-Json -Depth 100 | Set-Content $prefsFile
                Write-Host "Updated notifications settings in $prefsFile"
            }
        }
        catch {
            Write-Warning "Error processing $prefsFile : $_"
        }
    }

    # Check if Edge user data directory exists
    if (-not (Test-Path $edgeUserDataPath)) {
        Write-Warning "Edge user data directory not found at $edgeUserDataPath"
        exit
    }

    # Get all profile directories (Default and Profile *)
    $profiles = Get-ChildItem -Path $edgeUserDataPath -Directory | 
        Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }

    # Process each profile
    foreach ($profile in $profiles) {
        $prefsFile = Join-Path $profile.FullName "Preferences"
        Disable-NotificationsInProfile -prefsFile $prefsFile
    }

    Write-Host "Completed processing all Edge profiles"

    "Disable Notifications Edge, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}


function EnableRegBackup {
    #### ========================
    #### Enable Registry Backup (Disabled post 10 1803)
    #### ------------------------
	    reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Configuration Manager" /v EnablePeriodicBackup /t REG_DWORD /d 00000001 /f
    #### ========================
    
    "Enable Registry Backup, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}


function InstallAppsWinget {
    #### ========================
    #### Install Basic apps in Windows 10/11 via WinGet.
    #### ------------------------

    winget show --id Google.Chrome.EXE --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget install -e --id Google.Chrome.EXE --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget show --id Adobe.Acrobat.Reader.64-bit --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget install -e --id Adobe.Acrobat.Reader.64-bit --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget show --id VideoLAN.VLC --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget install -e --id VideoLAN.VLC --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget show --id 7zip.7zip --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    winget install -e --id 7zip.7zip --source winget | Out-File -Filepath "C:\PCR\UpdateLog.txt" -Append
    
    "End Install Basic Apps, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}

function VSS-Create {
    #### ========================
    #### Enable Volume Shadow Copy for local Disks and create schedule tasks
    #### NOTE: There must be a VSS-Task-Disk task for partition (drive letter) on your system! Modify accordingly!
    #### *Add variables for disks*
    #### ------------------------
	cmd /c "sc config vss start= auto"
	cmd /c "sc start vss"

	Register-ScheduledTask -TaskName "VSS-Task-Daily" -Trigger (New-ScheduledTaskTrigger -At 10:00pm -Daily) -User "NT AUTHORITY\SYSTEM" -Action (New-ScheduledTaskAction -Execute "$env:windir\System32\wbem\WMIC.exe" -Argument "/Namespace:\\root\default Path SystemRestore Call CreateRestorePoint ""SystemRestore-%Date%"", 100, 7") -RunLevel Highest -Force
	Register-ScheduledTask -TaskName "VSS-Task-Daily-C" -Trigger (New-ScheduledTaskTrigger -At 10:05pm -Daily) -User "NT AUTHORITY\SYSTEM" -Action (New-ScheduledTaskAction -Execute "$env:windir\System32\wbem\WMIC.exe" -Argument "shadowcopy call create Volume=""C:\""" ) -RunLevel Highest -Force
	#### Register-ScheduledTask -TaskName "VSS-Task-Daily-D" -Trigger (New-ScheduledTaskTrigger -At 10:05pm -Daily) -User "NT AUTHORITY\SYSTEM" -Action (New-ScheduledTaskAction -Execute "$env:windir\System32\wbem\WMIC.exe" -Argument "shadowcopy call create Volume=""D:\""" ) -RunLevel Highest -Force

	Start-ScheduledTask "VSS-Task-Daily"
	Start-ScheduledTask "VSS-Task-Daily-C"
	#### Start-ScheduledTask "VSS-Task-Daily-D"
    #### ========================

    "Create Shadow Copy Scheduled Tasks, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}

function Install-uBlock {
    #### ========================
    #### Install uBlock Plugin
    #### ------------------------
    function Install-ChromeuBlock
    {

	    New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
	    New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist\" -Name "1" -Value "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
    }
    function Install-EdgeuBlock
    {

	    New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
	    New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist\" -Name "1" -Value "odfafepnkmbhccpbejgmiehpchacaeak;https://edge.microsoft.com/extensionwebstorebase/v1/crx"
    }
    function Install-ChromeuBlockv3
    {
	    New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
	    New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist\" -Name "1" -Value "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"
    }
    function Install-FirefoxuBlock {
	    md "c:\Program Files\Mozilla Firefox\distribution\"
	    md "c:\Program Files (x86)\Mozilla Firefox\distribution\"
	    copy "c:\PCR\policies.json" "c:\Program Files\Mozilla Firefox\distribution\"
	    copy "c:\PCR\policies.json" "c:\Program Files (x86)\Mozilla Firefox\distribution\"
    }
    function Install-OperauBlock {
	    New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist"
	    New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist" -Name "1" -Value "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
    }
    function Install-BraveuBlock {
	    New-Item -Force -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
	    New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" -Name "1" -Value "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
    }
    Install-ChromeuBlock
    Install-EdgeuBlock
    Install-ChromeuBlockv3
    Install-FirefoxuBlock
    Install-OperauBlock
    Install-BraveuBlock
    #### ========================
    
    "Install uBlock Origin All around, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}

function Uninstall-uBlock{
    #### ========================
    #### UnInstall Forced Extentions
    #### ------------------------
    function Remove-ChromeExtensions
    {
	    Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Recurse
    }
    function Remove-EdgeExtensions
    {
	    Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" -Recurse
    }
    function Remove-ChromeuBlockv3
    {
	    Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Recurse
    }
    function Remove-FirefoxuBlock {
	    del "c:\Program Files\Mozilla Firefox\distribution\policies.json"
	    del "c:\Program Files (x86)\Mozilla Firefox\distribution\policies.json"
    }
    function Remove-OperauBlock {
	    Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist" -Recurse
    }
    function Remove-BraveuBlock {
	    Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" -Recurse
    }
    Remove-ChromeExtensions
    Remove-EdgeExtensions
    Remove-ChromeuBlockv3
    Remove-FirefoxuBlock
    Remove-OperauBlock
    Remove-BraveuBlock
    #### ========================
    
    "Remove Forced uBlock Install, $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}


function Win10-CustomCU {
    #### ========================
    #### Customize Windows 10 begin (User Based Keys)
    #### ------------------------
    #### Shrink Search box to button: 0 = Hidden, 1 = Show search or Cortana icon, 2 = Show search box
    reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /v SearchboxTaskbarMode /t REG_DWORD /d 00000001 /f
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowCortanaButton /t REG_DWORD /d 00000000 /f
    #### Combine Taskbar Buttons: 0 = Always combine, hide labels, 1 = Combine when taskbar is full, 2 = Never combine
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarGlomLevel /t REG_DWORD /d 00000002 /f
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v MMTaskbarGlomLevel /t REG_DWORD /d 00000002 /f
    #### Always show all icons in notification area: 0 = Show all, 1 = Show none
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer" /v EnableAutoTray /t REG_DWORD /d 00000000 /f
    #### Display Full Path in Title Bar area: 0 = Off, 1 = On
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 00000001 /f
    #### Display Filename Extensions: 0 = Show, 1 = Off
    reg add "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced " /v HideFileExt /t REG_DWORD /d 00000000 /f
    #### Expand Ribbon in Explorer: 0 = Open, 1 = Close
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon" /v MinimizedStateTabletModeOff /t REG_DWORD /d 00000000 /f
    #### Expand Copy Window to Full: 0 = Closed, 1 = Open
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" /v EnthusiastMode /t REG_DWORD /d 00000001 /f
    #### "Get tips, tricks, and suggestions as you use Windows": 0 = Off, 1 = On
    reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 00000000 /f
    #### App Suggestions on Start: 0 = Off, 1 = On
    reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SystemPaneSuggestionsEnabled /t REG_DWORD /d 00000000 /f
    #### Hide People button from Taskbar: 0 = Off, 1 = On
    reg add "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v People /t REG_DWORD /d 00000000 /f
    #### ========================

    "Customize Windows 10 (User Based Keys), $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}

function Win10-CustomLM {
    #### ========================
    #### Customize Windows 10 begin (Local Machine Keys)
    #### ------------------------
    #### Change updates to Semi Annual Channel: 16 = Semi-Annual Channel (Targeted), 32 = Semi-Annual Channel, Absent or other = All
    #### *Note: Based upon documentation and the internet, I suspect that starting at 10 you are on targeted and the higher the number the more frequent the updates.
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" /v BranchReadinessLevel /t REG_DWORD /d 00000010 /f

    #### Data Collection (This is enterprise level settings!):
    #### Disable Feedback and Diagnostics: Creates 'AllowTelemetry'. 0 = Security (Enterprise and Education editions only), 1 = Basic, 2 = Enhanced, 3 = Full (Recommended)
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 00000000 /f
    #### Disable Connected User Experience and Telemetry Service:
    cmd /c "sc stop diagtrack"
    cmd /c "sc config diagtrack start= disabled"

    #### Set Time Zone to EST
    tzutil /s "Eastern Standard Time"
    #### Set power settings to 'High Performance'
    POWERCFG -SETACTIVE 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    POWERCFG -X -disk-timeout-ac 0
    POWERCFG -X -disk-timeout-dc 0
    POWERCFG -H OFF
    #### ========================
        
    #### ========================
    #### Customize Windows 10 begin (Local Machine Keys)
    #### ------------------------
    #### Disable Google Chrome Software Reporter Tool!
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\software_reporter_tool.exe" /v Debugger /t REG_SZ /d "systray.exe" /f
    #### ========================

    "Customize Windows 10 (Local Machine Keys), $(Get-Date -Format 'MM/dd/yyyy'), $(Get-Date -Format 'HH:mm:ss')" | Out-File -FilePath "C:\PCR\UpdateLog.txt" -Append
}