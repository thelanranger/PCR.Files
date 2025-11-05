# Script to disable notifications for all Chrome profiles on a Windows computer

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