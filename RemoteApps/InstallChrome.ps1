# Define the URL for the latest Google Chrome installer
$chromeInstallerUrl = "https://dl.google.com/chrome/install/latest/chrome_installer.exe"

# Define the path to download the Chrome installer
$installerPath = "$env:TEMP\chrome_installer.exe"

# Confirm Chrome is installed by checking for the executable
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
	Write-Output "Google Chrome already installed"
} else {
	# Download the Chrome installer
	Invoke-WebRequest -Uri $chromeInstallerUrl -OutFile $installerPath

	# Install Chrome silently
	Start-Process -FilePath $installerPath -ArgumentList "/silent /install" -Wait

	# Optionally, remove the installer after installation
	Remove-Item $installerPath
	
	# Confirm Chrome is installed by checking for the executable
	if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
		Write-Output "Google Chrome installed successfully."
	} else {
		Write-Output "Google Chrome installation failed."
	}
}

