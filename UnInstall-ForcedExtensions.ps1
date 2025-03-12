#### ========================
#### UnInstall Forced Extentions
#### ------------------------
function Remove-ChromeExtensions
{
	Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Recurse
}
function Remove-EdgeExtensions
{
	Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" -Recurse
}
function Remove-ChromeuBlockv3
{
	Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" -Recurse
}
function Remove-FirefoxuBlock {
	del "c:\Program Files\Mozilla Firefox\distribution\policies.json"
	del "c:\Program Files (x86)\Mozilla Firefox\distribution\policies.json"
}
function Remove-OperauBlock {
	Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist" -Recurse
}
function Remove-BraveuBlock {
	Remove-Item -Force -Path "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" -Recurse
}
Remove-ChromeExtensions
Remove-EdgeExtensions
Remove-ChromeuBlockv3
Remove-FirefoxuBlock
Remove-OperauBlock
Remove-BraveuBlock
#### ========================
