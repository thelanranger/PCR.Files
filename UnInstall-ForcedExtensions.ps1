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
Remove-ChromeExtensions
Remove-EdgeExtensions
#### ========================
