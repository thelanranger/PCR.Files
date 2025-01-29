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