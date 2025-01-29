# Define the URL for the latest VLC Media Player installer (64-bit version)
$vlcInstallerUrl = "https://ftp.osuosl.org/pub/videolan/vlc/3.0.21/win64/vlc-3.0.21-win64.exe"

# Define the path to download the VLC installer
$installerPath = "$env:TEMP\vlc_installer.exe"

# Confirm VLC is already installed
if (Test-Path "C:\Program Files\VideoLAN\VLC\vlc.exe") {
	Write-Output "VLC Media Player already installed."
} else {
	# Download the VLC installer
	Invoke-WebRequest -Uri $vlcInstallerUrl -OutFile $installerPath

	# Install VLC silently
	Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait

	# Optionally, remove the installer after installation
	Remove-Item $installerPath
	
	# Confirm VLC is installed by checking for the executable
	if (Test-Path "C:\Program Files\VideoLAN\VLC\vlc.exe") {
		Write-Output "VLC Media Player installed successfully."
	} else {
		Write-Output "VLC Media Player installation failed."
	}
}