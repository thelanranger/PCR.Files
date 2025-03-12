#### ========================
#### Install uBlock Plugin
#### ------------------------
function Install-ChromeuBlock
{

	New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
	New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist\" -Name "1" -Value "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
}
function Install-EdgeuBlock
{

	New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
	New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist\" -Name "1" -Value "odfafepnkmbhccpbejgmiehpchacaeak;https://edge.microsoft.com/extensionwebstorebase/v1/crx"
}
function Install-ChromeuBlockv3
{
	New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
	New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist\" -Name "1" -Value "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx"
}
function Install-FirefoxuBlock {
	md "c:\Program Files\Mozilla Firefox\distribution\"
	md "c:\Program Files (x86)\Mozilla Firefox\distribution\"
	copy "c:\PCR\policies.json" "c:\Program Files\Mozilla Firefox\distribution\"
	copy "c:\PCR\policies.json" "c:\Program Files (x86)\Mozilla Firefox\distribution\"
}
function Install-OperauBlock {
	New-Item -Force -Path "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist"
	New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist" -Name "1" -Value "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
}
function Install-BraveuBlock {
	New-Item -Force -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
	New-ItemProperty -Force -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" -Name "1" -Value "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx"
}
Install-ChromeuBlock
Install-EdgeuBlock
Install-ChromeuBlockv3
Install-FirefoxuBlock
Install-OperauBlock
Install-BraveuBlock
#### ========================
