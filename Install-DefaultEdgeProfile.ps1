#### ========================
#### Install DefaultEdge Profile
#### ------------------------
# Get the process ID of Microsoft Edge
$edge = Get-Process msedge
if ($edge) {
    # Terminate the process using its ID
    Stop-Process -Id $edge.Id -Force
    Write-Host "Microsoft Edge terminated successfully."
} else {
    Write-Host "Microsoft Edge is not running."
}

rename-item -Path "$env:localappdata\Microsoft\Edge\User Data" -NewName "$env:localappdata\Microsoft\Edge\User Data.old"
copy-item -Path "C:\PCR\DefaultEdgeProfile\User Data" -Destination "$env:localappdata\Microsoft\Edge\" -Recurse
copy-item -Path "$env:localappdata\Microsoft\Edge\User Data.old\Default\bookmarks" -Destination "$env:localappdata\Microsoft\Edge\User Data\Default"

#### ========================
