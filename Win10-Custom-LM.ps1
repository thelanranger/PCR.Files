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