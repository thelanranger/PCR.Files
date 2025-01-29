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