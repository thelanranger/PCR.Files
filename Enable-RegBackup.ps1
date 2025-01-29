#### ========================
#### Enable Registry Backup (Disabled post 10 1803)
#### ------------------------
	reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Configuration Manager" /v EnablePeriodicBackup /t REG_DWORD /d 00000001 /f
#### ========================