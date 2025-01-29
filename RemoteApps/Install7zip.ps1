# Define the URL for the latest 7-Zip installer (64-bit version)
$zipInstallerUrl = "https://www.7-zip.org/a/7z2301-x64.exe"

# Define the path to download the 7-Zip installer
$installerPath = "$env:TEMP\7zip_installer.exe"

# Confirm 7-Zip is installed by checking for the executable
if (Test-Path "C:\Program Files\7-Zip\7zFM.exe") {
	Write-Output "7-Zip already installed."
} else {
	# Download the 7-Zip installer
	Invoke-WebRequest -Uri $zipInstallerUrl -OutFile $installerPath
	
	# Install 7-Zip silently
	Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
	
	# Optionally, remove the installer after installation
	Remove-Item $installerPath
		
	# Confirm 7-Zip is installed by checking for the executable
	if (Test-Path "C:\Program Files\7-Zip\7zFM.exe") {
		Write-Output "7-Zip installed successfully."
	} else {
		Write-Output "7-Zip installation failed."
	}
}


