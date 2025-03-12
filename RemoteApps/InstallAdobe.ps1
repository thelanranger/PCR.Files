# Define the URL for the latest Adobe Acrobat Reader offline installer (DC version)
$adobeInstallerUrl = "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2400520320/AcroRdrDC2400520320_en_US.exe"

# Define the path to download the Adobe Reader installer
$installerPath = "$env:TEMP\AdbeRdrInstaller.exe"

# Confirm Adobe Reader is installed by checking for the executable
if (Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") {
    Write-Output "Adobe Acrobat Reader already installed."
} else {
	# Download the Adobe Reader installer
	Invoke-WebRequest -Uri $adobeInstallerUrl -OutFile $installerPath
	
	# Install Adobe Reader silently
	Start-Process -FilePath $installerPath -ArgumentList "/sAll /msi /norestart /quiet" -Wait
	
	# Optionally, remove the installer after installation
	Remove-Item $installerPath
	
	# Confirm Adobe Reader is installed by checking for the executable
	if (Test-Path "C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe") {
		Write-Output "Adobe Acrobat Reader installed successfully."
	} else {
		Write-Output "Adobe Acrobat Reader installation failed."
	}
}


