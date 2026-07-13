# AutoConfigTool.ps1
# Self-contained GUI Task Launcher with live system-state scanning.
#
# HOW TO ADD A TASK:
#   1. Add Scan_{id}, Apply_{id}, and Revert_{id} functions below.
#   2. Add an entry to Get-TaskList.
#
# CHECKBOX MEANING (set automatically by startup scan):
#   Checked   = setting IS currently active / software IS installed
#   Unchecked = setting is NOT active / software NOT installed
#
# APPLY CHANGES compares checkbox to last scan:
#   Unchecked -> user checks   -> Apply_{id}   (enable / install)
#   Checked   -> user unchecks -> Revert_{id}  (disable / uninstall)
#   No delta                   -> skip
#
# SCAN  : return "applied" | "not-applied" | "error"
# APPLY / REVERT : Write-Host for output, return "success" | "error"

# ── DPI awareness ─────────────────────────────────────────────────────────────
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[DpiHelper]::SetProcessDPIAware() | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

# =============================================================================
# HELPERS
# =============================================================================
function Get-RegValue {
    param([string]$Path, [string]$Name)
    try { return Get-ItemPropertyValue -Path $Path -Name $Name -ErrorAction Stop }
    catch { return $null }
}

function Set-RegValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        return $true
    } catch { Write-Host "ERROR setting $Path\$Name : $($_.Exception.Message)"; return $false }
}

function Remove-RegValue {
    param([string]$Path, [string]$Name)
    try {
        if (Test-Path $Path) { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction SilentlyContinue }
        return $true
    } catch { Write-Host "ERROR removing $Path\$Name : $($_.Exception.Message)"; return $false }
}

function Get-WingetPath {
    # The diagnostic confirmed winget lives at:
    # C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\winget.exe
    # where.exe finds it but Test-Path on its output can fail due to trailing
    # whitespace/newlines. We now sanitise every candidate aggressively.

    function Test-WingetExe { param($p) return ($p -and (Test-Path ($p.Trim()) -PathType Leaf)) }

    # 1. WMI user - most direct, confirmed working on this machine
    $wmiUser = (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($wmiUser) {
        $uname = ($wmiUser -split "\\")[-1]
        $c = "C:\Users\$uname\AppData\Local\Microsoft\WindowsApps\winget.exe"
        if (Test-WingetExe $c) { return $c }
    }

    # 2. All user profiles
    Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin @("Public","Default","Default User","All Users") } |
        ForEach-Object {
            $c = "$($_.FullName)\AppData\Local\Microsoft\WindowsApps\winget.exe"
            if (Test-WingetExe $c) { return $c }
        }

    # 3. AppX package install location
    try {
        $pkg = Get-AppxPackage -Name "Microsoft.DesktopAppInstaller" -ErrorAction SilentlyContinue |
               Sort-Object Version | Select-Object -Last 1
        if ($pkg -and $pkg.InstallLocation) {
            $c = Join-Path $pkg.InstallLocation "winget.exe"
            if (Test-WingetExe $c) { return $c }
        }
    } catch {}

    # 4. where.exe (last resort - output can have CRLF issues)
    $w = & where.exe winget 2>$null
    if ($w) {
        foreach ($line in ($w -split "`r?`n")) {
            $line = $line.Trim()
            if ($line -and (Test-WingetExe $line)) { return $line }
        }
    }

    return $null
}

function Install-Winget {
    param([System.Windows.Forms.RichTextBox]$OutputBox)

    function Emit {
        param([string]$Line, [System.Drawing.Color]$Color)
        if ($OutputBox) {
            $OutputBox.SelectionColor = $Color
            $OutputBox.AppendText($Line + "`r`n")
            $OutputBox.SelectionStart = $OutputBox.TextLength
            $OutputBox.ScrollToCaret()
            # No DoEvents inside event callbacks - call only from main thread here
            [System.Windows.Forms.Application]::DoEvents()
        }
        Write-Host $Line
    }

    Emit "winget not found. Downloading App Installer from GitHub..." ([System.Drawing.Color]::Gold)

    $tempDir = "$env:TEMP\winget_bootstrap"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        Emit "Fetching latest release info from GitHub..." ([System.Drawing.Color]::Gray)
        [System.Windows.Forms.Application]::DoEvents()

        $release = Invoke-RestMethod `
            -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" `
            -ErrorAction Stop

        $bundle = $release.assets |
                  Where-Object { $_.name -match "\.msixbundle$" } |
                  Select-Object -First 1
        if (-not $bundle) {
            Emit "ERROR: No msixbundle found in latest release." ([System.Drawing.Color]::Salmon)
            return $false
        }

        # Simple synchronous download - avoids recursive DoEvents stack overflow
        function Download-File {
            param([string]$Url, [string]$Dest, [string]$Label)
            Emit "Downloading $Label (this may take a moment)..." ([System.Drawing.Color]::Gray)
            [System.Windows.Forms.Application]::DoEvents()
            $wc = New-Object System.Net.WebClient
            try {
                $wc.DownloadFile($Url, $Dest)
                Emit "  $Label`: done." ([System.Drawing.Color]::Gray)
            } finally {
                $wc.Dispose()
            }
        }

        $bundlePath = "$tempDir\$($bundle.name)"
        Download-File $bundle.browser_download_url $bundlePath $bundle.name

        $deps = @(
            @{ url="https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx";                                                                  name="VCLibs.x64" },
            @{ url="https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"; name="Microsoft.UI.Xaml.2.8" }
        )
        $depPaths = @()
        foreach ($dep in $deps) {
            $dest = "$tempDir\$($dep.name).appx"
            try {
                Download-File $dep.url $dest $dep.name
                $depPaths += $dest
            } catch {
                Emit "WARNING: Could not download $($dep.name) - continuing." ([System.Drawing.Color]::Gold)
            }
        }

        Emit "Installing dependencies..." ([System.Drawing.Color]::Gold)
        [System.Windows.Forms.Application]::DoEvents()
        foreach ($dep in $depPaths) {
            if (Test-Path $dep) {
                Emit "  Installing: $(Split-Path $dep -Leaf)" ([System.Drawing.Color]::Gray)
                [System.Windows.Forms.Application]::DoEvents()
                Add-AppxPackage -Path $dep -ErrorAction SilentlyContinue
            }
        }

        Emit "Installing App Installer bundle..." ([System.Drawing.Color]::Gold)
        [System.Windows.Forms.Application]::DoEvents()
        try {
            Add-AppxPackage -Path $bundlePath -ForceApplicationShutdown -ErrorAction Stop
            Emit "App Installer installed successfully." ([System.Drawing.Color]::FromArgb(80,200,130))
        } catch {
            Emit "Standard install failed ($($_.Exception.Message)), trying provisioned..." ([System.Drawing.Color]::Gold)
            [System.Windows.Forms.Application]::DoEvents()
            try {
                $pp = @{ Online=$true; PackagePath=$bundlePath; ErrorAction="Stop" }
                if ($depPaths) { $pp["DependencyPackagePath"] = $depPaths }
                Add-AppxProvisionedPackage @pp | Out-Null
                Emit "Provisioned install succeeded." ([System.Drawing.Color]::FromArgb(80,200,130))
            } catch {
                Emit "ERROR: $($_.Exception.Message)" ([System.Drawing.Color]::Salmon)
                Emit "Please install 'App Installer' from the Microsoft Store and retry." ([System.Drawing.Color]::Salmon)
                return $false
            }
        }

        # Refresh PATH so winget is visible in this session without a reboot
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
                    [System.Environment]::GetEnvironmentVariable("PATH","User")
        return $true

    } catch {
        Emit "ERROR: $($_.Exception.Message)" ([System.Drawing.Color]::Salmon)
        return $false
    } finally {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}


function Ensure-Winget {
    param([System.Windows.Forms.RichTextBox]$OutputBox)
    $wg = Get-WingetPath
    if ($wg) { return $wg }
    $ok = Install-Winget -OutputBox $OutputBox
    if (-not $ok) { return $null }
    Start-Sleep -Seconds 3
    $wg = Get-WingetPath
    if ($wg) { return $wg }
    if ($OutputBox) {
        $OutputBox.SelectionColor = [System.Drawing.Color]::Salmon
        $OutputBox.AppendText("ERROR: winget still not found after install. A reboot may be required.`r`n")
    }
    return $null
}

function Test-WingetPackage {
    param([string]$PackageId)
    try {
        $wg = Get-WingetPath
        if (-not $wg) { return $false }
        # Use Start-Process to avoid elevated-context output capture issues
        $outFile = "$env:TEMP\winget_scan_$([System.IO.Path]::GetRandomFileName()).txt"
        $proc = Start-Process -FilePath $wg `
            -ArgumentList @("list", "--id", $PackageId, "--exact", "--accept-source-agreements") `
            -Wait -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile `
            -RedirectStandardError  "$outFile.err" `
            -ErrorAction Stop
        $exitCode = $proc.ExitCode
        $output   = if (Test-Path $outFile) { Get-Content $outFile -Raw } else { "" }
        Remove-Item $outFile      -Force -ErrorAction SilentlyContinue
        Remove-Item "$outFile.err" -Force -ErrorAction SilentlyContinue
        if ($exitCode -ne 0) { return $false }
        # A real match has the package ID on a data row (not header/separator)
        $matched = ($output -split "`r?`n") | Where-Object {
            $_ -match [regex]::Escape($PackageId) -and
            $_ -notmatch "^[-\s]+$" -and
            $_ -notmatch "^\s*Name\s"
        }
        return ($matched.Count -gt 0)
    } catch { return $false }
}

function Invoke-WingetAction {
    param(
        [string]$Action,
        [string]$PackageId,
        [string]$DisplayName,
        [string[]]$ExtraArgs = @(),
        [System.Windows.Forms.RichTextBox]$OutputBox,
        [System.Windows.Forms.Label]$StatusLabel
    )

    $wg = Ensure-Winget -OutputBox $OutputBox
    if (-not $wg) { return "error" }

    function Emit {
        param([string]$Line, [System.Drawing.Color]$Color)
        if ($OutputBox) {
            $OutputBox.SelectionColor = $Color
            $OutputBox.AppendText($Line + "`r`n")
            $OutputBox.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
    }

    function Run-Winget {
        param([string[]]$WingetArgs)
        $outFile = "$env:TEMP\winget_out_$([System.IO.Path]::GetRandomFileName()).txt"
        $errFile = "$outFile.err"

        Emit "Running: winget $($WingetArgs -join ' ')" ([System.Drawing.Color]::FromArgb(130,140,170))

        $proc = Start-Process -FilePath $wg `
            -ArgumentList $WingetArgs `
            -Wait -NoNewWindow -PassThru `
            -RedirectStandardOutput $outFile `
            -RedirectStandardError  $errFile `
            -ErrorAction Stop

        if (Test-Path $outFile) {
            foreach ($line in (Get-Content $outFile)) {
                if ($line.Trim()) { Emit $line ([System.Drawing.Color]::FromArgb(220,225,240)) }
            }
        }
        if (Test-Path $errFile) {
            foreach ($line in (Get-Content $errFile)) {
                if ($line.Trim()) { Emit $line ([System.Drawing.Color]::Salmon) }
            }
        }
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue
        Remove-Item $errFile -Force -ErrorAction SilentlyContinue

        return $proc.ExitCode
    }

    # Run winget de-elevated under the interactive user session via schtasks.
    # Required for installers (e.g. Adobe Acrobat) that write per-user paths and
    # fail with exit 1603 when launched from an elevated process.
    function Run-Winget-AsUser {
        param([string[]]$WingetArgs)

        $taskName = "AutoConfigTool_Winget_$([System.IO.Path]::GetRandomFileName() -replace '\.','')"
        $outFile  = "$env:TEMP\winget_asuser_$([System.IO.Path]::GetRandomFileName()).txt"
        $exitFile = "$outFile.exit"
        $cmdArgs  = $WingetArgs -join ' '

        # Batch wrapper: run winget, write exit code to file so we can read it back
        $script = "@echo off`r`n`"$wg`" $cmdArgs > `"$outFile`" 2>&1`r`necho %ERRORLEVEL% > `"$exitFile`"`r`n"
        $batFile = "$env:TEMP\$taskName.bat"
        [System.IO.File]::WriteAllText($batFile, $script, [System.Text.Encoding]::ASCII)

        Emit "Installer requires user context - retrying de-elevated via Task Scheduler..." ([System.Drawing.Color]::Gold)
        Emit "Running as user: winget $cmdArgs" ([System.Drawing.Color]::FromArgb(130,140,170))

        try {
            # Register a one-shot task that runs as the interactive user (no elevation)
            $null = schtasks /Create /TN $taskName /TR "`"$batFile`"" /SC ONCE /ST 00:00 /RL LIMITED /F 2>&1
            $null = schtasks /Run /TN $taskName 2>&1

            # Poll until the exit code file appears (winget done) - max 10 minutes
            $deadline = (Get-Date).AddMinutes(10)
            while (-not (Test-Path $exitFile) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 500
                [System.Windows.Forms.Application]::DoEvents()
            }

            if (-not (Test-Path $exitFile)) {
                Emit "ERROR: Timed out waiting for de-elevated installer to finish." ([System.Drawing.Color]::Salmon)
                return -1
            }

            # Stream captured output into the GUI
            if (Test-Path $outFile) {
                foreach ($line in (Get-Content $outFile)) {
                    if ($line.Trim()) { Emit $line ([System.Drawing.Color]::FromArgb(220,225,240)) }
                }
            }

            $exitCode = [int]((Get-Content $exitFile -Raw).Trim())
            return $exitCode

        } finally {
            $null = schtasks /Delete /TN $taskName /F 2>&1
            Remove-Item $batFile  -Force -ErrorAction SilentlyContinue
            Remove-Item $outFile  -Force -ErrorAction SilentlyContinue
            Remove-Item $exitFile -Force -ErrorAction SilentlyContinue
        }
    }

    $argList  = @($Action, "--id", $PackageId, "--exact") + $ExtraArgs + @("--accept-source-agreements")
    $exitCode = Run-Winget $argList

    # Success: 0 = done, -1978335189 = already installed
    if ($exitCode -eq 0 -or $exitCode -eq -1978335189) { return "success" }

    # Exit 1603 (winget code -1978335226): installer rejected the elevated context.
    # Automatically retry de-elevated via Task Scheduler running as the interactive user.
    if ($exitCode -eq -1978335226) {
        $exitCode = Run-Winget-AsUser $argList
        if ($exitCode -eq 0 -or $exitCode -eq -1978335189) { return "success" }
        Emit "ERROR: De-elevated install also failed with exit code $exitCode" ([System.Drawing.Color]::Salmon)
        return "error"
    }

    # Retriable: stale/missing source cache or hash mismatch
    $retriableCodes = @(-1978335212, -1978334974, -1978335140)
    if ($exitCode -in $retriableCodes) {
        $reason = switch ($exitCode) {
            -1978335212 { "sources not initialised" }
            -1978334974 { "installer hash mismatch (stale cache)" }
            -1978335140 { "source update required" }
            default     { "retriable error $exitCode" }
        }
        Emit "winget $reason -- resetting sources and retrying..." ([System.Drawing.Color]::Gold)
        Run-Winget @("source","reset","--force") | Out-Null
        Run-Winget @("source","update")          | Out-Null

        $retryArgs = $argList
        if ($exitCode -eq -1978334974) { $retryArgs += "--ignore-security-hash" }

        Emit "Retrying: winget $($retryArgs -join ' ')" ([System.Drawing.Color]::Gold)
        $exitCode = Run-Winget $retryArgs
        if ($exitCode -eq 0 -or $exitCode -eq -1978335189) { return "success" }
    }

    Emit "ERROR: winget exited with code $exitCode" ([System.Drawing.Color]::Salmon)
    Emit "  Tip: try  winget $($argList -join ' ')  in a non-elevated PowerShell window." ([System.Drawing.Color]::Salmon)
    return "error"
}


function Install-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string[]]$ExtraArgs = @(),
        [System.Windows.Forms.RichTextBox]$OutputBox,
        [System.Windows.Forms.Label]$StatusLabel
    )
    Write-Host "Installing $DisplayName..."
    return Invoke-WingetAction "install" $PackageId $DisplayName (@("--silent","--accept-package-agreements") + $ExtraArgs) -OutputBox $OutputBox -StatusLabel $StatusLabel
}

function Uninstall-WingetPackage {
    param(
        [string]$PackageId,
        [string]$DisplayName,
        [string[]]$ExtraArgs = @(),
        [System.Windows.Forms.RichTextBox]$OutputBox,
        [System.Windows.Forms.Label]$StatusLabel
    )
    Write-Host "Uninstalling $DisplayName..."
    return Invoke-WingetAction "uninstall" $PackageId $DisplayName (@("--silent") + $ExtraArgs) -OutputBox $OutputBox -StatusLabel $StatusLabel
}

# =============================================================================
# TASK DEFINITIONS
# =============================================================================

# ── Install Google Chrome ─────────────────────────────────────────────────────
function Scan_install_chrome {
    if (Test-WingetPackage "Google.Chrome") { return "applied" } else { return "not-applied" }
}
function Apply_install_chrome  { return Install-WingetPackage "Google.Chrome" "Google Chrome" -OutputBox $txtOutput }
function Revert_install_chrome { return Uninstall-WingetPackage "Google.Chrome" "Google Chrome" -OutputBox $txtOutput }

# ── Install Adobe Acrobat Reader ──────────────────────────────────────────────
function Scan_install_acrobat {
    if (Test-WingetPackage "Adobe.Acrobat.Reader.64-bit") { return "applied" } else { return "not-applied" }
}
function Apply_install_acrobat  { return Install-WingetPackage "Adobe.Acrobat.Reader.64-bit" "Adobe Acrobat Reader" -OutputBox $txtOutput }
function Revert_install_acrobat { return Uninstall-WingetPackage "Adobe.Acrobat.Reader.64-bit" "Adobe Acrobat Reader" -OutputBox $txtOutput }

# ── Install VLC ───────────────────────────────────────────────────────────────
function Scan_install_vlc {
    if (Test-WingetPackage "VideoLAN.VLC") { return "applied" } else { return "not-applied" }
}
function Apply_install_vlc  { return Install-WingetPackage "VideoLAN.VLC" "VLC Media Player" -OutputBox $txtOutput }
function Revert_install_vlc { return Uninstall-WingetPackage "VideoLAN.VLC" "VLC Media Player" -OutputBox $txtOutput }

# ── Install 7-Zip ─────────────────────────────────────────────────────────────
function Scan_install_7zip {
    if (Test-WingetPackage "7zip.7zip") { return "applied" } else { return "not-applied" }
}
function Apply_install_7zip  { return Install-WingetPackage "7zip.7zip" "7-Zip" -OutputBox $txtOutput }
function Revert_install_7zip { return Uninstall-WingetPackage "7zip.7zip" "7-Zip" -OutputBox $txtOutput }

# ── Install Zoom ──────────────────────────────────────────────────────────────
function Scan_install_zoom {
    if (Test-WingetPackage "Zoom.Zoom") { return "applied" } else { return "not-applied" }
}
function Apply_install_zoom  { return Install-WingetPackage "Zoom.Zoom" "Zoom" -OutputBox $txtOutput }
function Revert_install_zoom { return Uninstall-WingetPackage "Zoom.Zoom" "Zoom" -OutputBox $txtOutput }

# ── Install Legacy Notepad ────────────────────────────────────────────────────
function Scan_install_notepad {
    if (Test-WingetPackage "Microsoft.Notepad") { return "applied" } else { return "not-applied" }
}
function Apply_install_notepad  { return Install-WingetPackage "Microsoft.Notepad" "Legacy Notepad" -OutputBox $txtOutput }
function Revert_install_notepad { return Uninstall-WingetPackage "Microsoft.Notepad" "Legacy Notepad" -OutputBox $txtOutput }

# ── Install Microsoft Office (no scan, off by default) ───────────────────────
function Scan_install_office { return "not-applied" }   # always shows unchecked; user must opt in
function Apply_install_office  { return Install-WingetPackage "Microsoft.Office" "Microsoft Office" -OutputBox $txtOutput }
function Revert_install_office { return Uninstall-WingetPackage "Microsoft.Office" "Microsoft Office" -OutputBox $txtOutput }

# ── Search Box: shrink to icon ────────────────────────────────────────────────
# 0=Hidden 1=Icon 2=Box  -- desired: 1 (icon)
function Scan_search_box_icon {
    $v = Get-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode"
    if ($v -eq 1) { return "applied" } else { return "not-applied" }
}
function Apply_search_box_icon {
    $ok  = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1
    $ok2 = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 0
    Write-Host "Search box set to icon; Cortana button hidden."
    if ($ok -and $ok2) { return "success" } else { return "error" }
}
function Revert_search_box_icon {
    $ok  = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 2
    $ok2 = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCortanaButton" 1
    Write-Host "Search box restored to full box; Cortana button shown."
    if ($ok -and $ok2) { return "success" } else { return "error" }
}

# ── Taskbar: Never Combine Buttons ───────────────────────────────────────────
# 0=Always combine 1=Combine when full 2=Never combine -- desired: 2
function Scan_taskbar_never_combine {
    $v1 = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel"
    $v2 = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MMTaskbarGlomLevel"
    if ($v1 -eq 2 -and $v2 -eq 2) { return "applied" } else { return "not-applied" }
}
function Apply_taskbar_never_combine {
    $ok1 = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 2
    $ok2 = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MMTaskbarGlomLevel" 2
    Write-Host "Taskbar buttons set to Never Combine."
    if ($ok1 -and $ok2) { return "success" } else { return "error" }
}
function Revert_taskbar_never_combine {
    $ok1 = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 0
    $ok2 = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MMTaskbarGlomLevel" 0
    Write-Host "Taskbar buttons restored to Always Combine."
    if ($ok1 -and $ok2) { return "success" } else { return "error" }
}

# ── Notification Area: Always Show All Icons ──────────────────────────────────
# EnableAutoTray: 0=Show all, 1=Show none -- desired: 0
function Scan_notif_show_all_icons {
    $v = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_notif_show_all_icons {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" 0
    Write-Host "Notification area set to show all icons."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_notif_show_all_icons {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" "EnableAutoTray" 1
    Write-Host "Notification area restored to auto-hide icons."
    if ($ok) { return "success" } else { return "error" }
}

# ── Explorer: Show Full Path in Title Bar ─────────────────────────────────────
# FullPath: 0=Off 1=On -- desired: 1
function Scan_explorer_full_path {
    $v = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" "FullPath"
    if ($v -eq 1) { return "applied" } else { return "not-applied" }
}
function Apply_explorer_full_path {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" "FullPath" 1
    Write-Host "Full path shown in Explorer title bar."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_explorer_full_path {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" "FullPath" 0
    Write-Host "Full path hidden from Explorer title bar."
    if ($ok) { return "success" } else { return "error" }
}

# ── Explorer: Show File Extensions ───────────────────────────────────────────
# HideFileExt: 0=Show 1=Hide -- desired: 0
function Scan_show_file_extensions {
    $v = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_show_file_extensions {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Host "File extensions enabled. Explorer restarted."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_show_file_extensions {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 1
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Write-Host "File extensions hidden. Explorer restarted."
    if ($ok) { return "success" } else { return "error" }
}

# ── Explorer: Expand Ribbon ───────────────────────────────────────────────────
# MinimizedStateTabletModeOff: 0=Open(expanded) 1=Closed -- desired: 0
function Scan_explorer_ribbon {
    $v = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon" "MinimizedStateTabletModeOff"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_explorer_ribbon {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon" "MinimizedStateTabletModeOff" 0
    Write-Host "Explorer ribbon expanded."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_explorer_ribbon {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Ribbon" "MinimizedStateTabletModeOff" 1
    Write-Host "Explorer ribbon minimized."
    if ($ok) { return "success" } else { return "error" }
}

# ── Explorer: Expand Copy Dialog ──────────────────────────────────────────────
# EnthusiastMode: 0=Closed 1=Open -- desired: 1
function Scan_explorer_copy_dialog {
    $v = Get-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" "EnthusiastMode"
    if ($v -eq 1) { return "applied" } else { return "not-applied" }
}
function Apply_explorer_copy_dialog {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" "EnthusiastMode" 1
    Write-Host "Copy dialog set to expanded view."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_explorer_copy_dialog {
    $ok = Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" "EnthusiastMode" 0
    Write-Host "Copy dialog restored to compact view."
    if ($ok) { return "success" } else { return "error" }
}

# ── Disable Windows Tips ──────────────────────────────────────────────────────
# SubscribedContent-338389Enabled: 0=Off 1=On -- desired: 0
function Scan_disable_win_tips {
    $v = Get-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_disable_win_tips {
    $ok = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
    Write-Host "Windows tips and suggestions disabled."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_win_tips {
    $ok = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 1
    Write-Host "Windows tips and suggestions re-enabled."
    if ($ok) { return "success" } else { return "error" }
}

# ── Disable App Suggestions on Start ─────────────────────────────────────────
# SystemPaneSuggestionsEnabled: 0=Off 1=On -- desired: 0
function Scan_disable_start_suggestions {
    $v = Get-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_disable_start_suggestions {
    $ok = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
    Write-Host "Start menu app suggestions disabled."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_start_suggestions {
    $ok = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 1
    Write-Host "Start menu app suggestions re-enabled."
    if ($ok) { return "success" } else { return "error" }
}

# ── Hide People Button from Taskbar ──────────────────────────────────────────
# People: 0=Hidden 1=Shown -- desired: 0
function Scan_hide_people_button {
    $v = Get-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "People"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_hide_people_button {
    $ok = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "People" 0
    Write-Host "People button hidden from taskbar."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_hide_people_button {
    $ok = Set-RegValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "People" 1
    Write-Host "People button restored to taskbar."
    if ($ok) { return "success" } else { return "error" }
}

# ── Windows Update: Semi-Annual Channel ──────────────────────────────────────
# BranchReadinessLevel: 16=SAC-T 32=SAC other=default -- desired: 16
function Scan_update_semi_annual {
    $v = Get-RegValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "BranchReadinessLevel"
    if ($v -eq 16) { return "applied" } else { return "not-applied" }
}
function Apply_update_semi_annual {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "BranchReadinessLevel" 16
    Write-Host "Windows Update set to Semi-Annual Channel (Targeted)."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_update_semi_annual {
    $ok = Remove-RegValue "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" "BranchReadinessLevel"
    Write-Host "Windows Update channel restored to default."
    if ($ok) { return "success" } else { return "error" }
}

# ── Disable Telemetry (AllowTelemetry + DiagTrack service) ───────────────────
function Scan_disable_telemetry {
    $v   = Get-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"
    $svc = Get-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    if ($v -eq 0 -and $svc -and $svc.StartType -eq "Disabled") { return "applied" } else { return "not-applied" }
}
function Apply_disable_telemetry {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Stop-Service -Name "DiagTrack" -Force -ErrorAction SilentlyContinue
    Set-Service  -Name "DiagTrack" -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "Telemetry policy set to 0; DiagTrack service disabled."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_telemetry {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 3
    Set-Service  -Name "DiagTrack" -StartupType Automatic -ErrorAction SilentlyContinue
    Start-Service -Name "DiagTrack" -ErrorAction SilentlyContinue
    Write-Host "Telemetry restored to Full; DiagTrack service re-enabled."
    if ($ok) { return "success" } else { return "error" }
}

# ── Set Time Zone to Eastern Standard Time ────────────────────────────────────
function Scan_set_timezone_est {
    try {
        $tz = (Get-TimeZone).Id
        if ($tz -eq "Eastern Standard Time") { return "applied" } else { return "not-applied" }
    } catch { return "error" }
}
function Apply_set_timezone_est {
    try {
        Set-TimeZone -Id "Eastern Standard Time" -ErrorAction Stop
        Write-Host "Time zone set to Eastern Standard Time."
        return "success"
    } catch { Write-Host "ERROR: $($_.Exception.Message)"; return "error" }
}
function Revert_set_timezone_est {
    Write-Host "NOTE: Time zone revert not automated. Please set manually via Settings > Time & Language."
    return "success"
}

# ── Power: High Performance + Disable Disk Timeout + Disable Hibernation ─────
function Scan_power_high_performance {
    try {
        $active = powercfg /getactivescheme
        $diskAC = (powercfg /query SCHEME_CURRENT SUB_DISK DISKIDLE | Select-String "AC Power Setting Index" | ForEach-Object { $_ -replace '.*0x','' }).Trim()
        $hibFile = "$env:SystemRoot\hiberfil.sys"
        if ($active -match "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -and $diskAC -eq "00000000" -and -not (Test-Path $hibFile)) {
            return "applied"
        }
        return "not-applied"
    } catch { return "not-applied" }
}
function Apply_power_high_performance {
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
    powercfg /X /disk-timeout-ac 0
    powercfg /X /disk-timeout-dc 0
    powercfg /H OFF
    Write-Host "High Performance plan active; disk timeout disabled; hibernation off."
    return "success"
}
function Revert_power_high_performance {
    powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e
    powercfg /X /disk-timeout-ac 20
    powercfg /X /disk-timeout-dc 10
    powercfg /H ON
    Write-Host "Balanced plan restored; disk timeout reset; hibernation re-enabled."
    return "success"
}

# ── Disable Chrome Software Reporter Tool ─────────────────────────────────────
function Scan_disable_chrome_reporter {
    $v = Get-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\software_reporter_tool.exe" "Debugger"
    if ($v -eq "systray.exe") { return "applied" } else { return "not-applied" }
}
function Apply_disable_chrome_reporter {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\software_reporter_tool.exe" "Debugger" "systray.exe" "String"
    Write-Host "Chrome Software Reporter Tool blocked."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_chrome_reporter {
    $ok = Remove-RegValue "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\software_reporter_tool.exe" "Debugger"
    Write-Host "Chrome Software Reporter Tool unblocked."
    if ($ok) { return "success" } else { return "error" }
}

# ── Force Install uBlock Origin (all browsers) ────────────────────────────────
function Scan_ublock_all_browsers {
    $chromeKey = Get-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" "1"
    $edgeKey   = Get-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" "1"
    if ($chromeKey -and $edgeKey) { return "applied" } else { return "not-applied" }
}
function Apply_ublock_all_browsers {
    # Chrome (MV2)
    Set-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" "1" "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" "String"
    # Chrome (MV3)
    Set-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist" "2" "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx" "String"
    # Edge
    Set-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist" "1" "odfafepnkmbhccpbejgmiehpchacaeak;https://edge.microsoft.com/extensionwebstorebase/v1/crx" "String"
    # Opera
    Set-RegValue "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist" "1" "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" "String"
    # Brave
    Set-RegValue "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist" "1" "cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx" "String"
    # Firefox
    $ffPaths = @("$env:ProgramFiles\Mozilla Firefox\distribution", "$env:ProgramFiles(x86)\Mozilla Firefox\distribution")
    $policies = '{"policies":{"ExtensionSettings":{"uBlock0@raymondhill.net":{"installation_mode":"force_installed","install_url":"https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"}}}}'
    foreach ($p in $ffPaths) {
        if (Test-Path (Split-Path $p -Parent)) {
            New-Item -Path $p -ItemType Directory -Force | Out-Null
            $policies | Set-Content "$p\policies.json" -Encoding UTF8
        }
    }
    Write-Host "uBlock Origin force-installed for Chrome, Edge, Opera, Brave, Firefox."
    return "success"
}
function Revert_ublock_all_browsers {
    $paths = @(
        "HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist",
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist",
        "HKLM:\SOFTWARE\Policies\Opera\Software\extension_install_forcelist",
        "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave\ExtensionInstallForcelist"
    )
    foreach ($p in $paths) { if (Test-Path $p) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue } }
    foreach ($ff in @("$env:ProgramFiles\Mozilla Firefox\distribution\policies.json","$env:ProgramFiles(x86)\Mozilla Firefox\distribution\policies.json")) {
        if (Test-Path $ff) { Remove-Item $ff -Force -ErrorAction SilentlyContinue }
    }
    Write-Host "uBlock Origin force-install policies removed."
    return "success"
}

# ── Disable Chrome Background Running ────────────────────────────────────────
function Scan_disable_chrome_background {
    $v = Get-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "BackgroundModeEnabled"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_disable_chrome_background {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "BackgroundModeEnabled" 0
    Write-Host "Chrome background mode disabled via policy."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_chrome_background {
    $ok = Remove-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "BackgroundModeEnabled"
    Write-Host "Chrome background mode policy removed (default restored)."
    if ($ok) { return "success" } else { return "error" }
}

# ── Disable Edge Background Running ──────────────────────────────────────────
function Scan_disable_edge_background {
    $v = Get-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled"
    if ($v -eq 0) { return "applied" } else { return "not-applied" }
}
function Apply_disable_edge_background {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled" 0
    Write-Host "Edge background mode disabled via policy."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_edge_background {
    $ok = Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "BackgroundModeEnabled"
    Write-Host "Edge background mode policy removed (default restored)."
    if ($ok) { return "success" } else { return "error" }
}

# ── Disable Chrome Notifications ──────────────────────────────────────────────
# DefaultNotificationsSetting: 1=Allow 2=Block
function Scan_disable_chrome_notifications {
    $v = Get-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "DefaultNotificationsSetting"
    if ($v -eq 2) { return "applied" } else { return "not-applied" }
}
function Apply_disable_chrome_notifications {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "DefaultNotificationsSetting" 2
    Write-Host "Chrome notifications blocked via policy."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_chrome_notifications {
    $ok = Remove-RegValue "HKLM:\SOFTWARE\Policies\Google\Chrome" "DefaultNotificationsSetting"
    Write-Host "Chrome notifications policy removed (default restored)."
    if ($ok) { return "success" } else { return "error" }
}

# ── Disable Edge Notifications ────────────────────────────────────────────────
function Scan_disable_edge_notifications {
    $v = Get-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "DefaultNotificationsSetting"
    if ($v -eq 2) { return "applied" } else { return "not-applied" }
}
function Apply_disable_edge_notifications {
    $ok = Set-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "DefaultNotificationsSetting" 2
    Write-Host "Edge notifications blocked via policy."
    if ($ok) { return "success" } else { return "error" }
}
function Revert_disable_edge_notifications {
    $ok = Remove-RegValue "HKLM:\SOFTWARE\Policies\Microsoft\Edge" "DefaultNotificationsSetting"
    Write-Host "Edge notifications policy removed (default restored)."
    if ($ok) { return "success" } else { return "error" }
}

# =============================================================================
# TASK LIST  --  order controls display order in UI
# defaultEnabled only matters for tasks where scan always returns "not-applied"
# (e.g. MS Office).  All others are set by the startup scan.
# =============================================================================
function Get-TaskList {
    return @(
        # ── Browser Policies ──────────────────────────────────────────────────
        [PSCustomObject]@{ id="ublock_all_browsers";        name="Force Install uBlock Origin";          description="Force-installs uBlock Origin in Chrome, Edge, Firefox, Opera, Brave"; group="Browser" },
        [PSCustomObject]@{ id="disable_chrome_reporter";    name="Block Chrome Software Reporter";       description="Prevents Chrome's software_reporter_tool.exe from running"; group="Browser" },
        [PSCustomObject]@{ id="disable_chrome_background";  name="Disable Chrome Background Mode";       description="Prevents Chrome from running in the background when closed"; group="Browser" },
        [PSCustomObject]@{ id="disable_edge_background";    name="Disable Edge Background Mode";         description="Prevents Edge from running in the background when closed";  group="Browser" },
        [PSCustomObject]@{ id="disable_chrome_notifications"; name="Disable Chrome Notifications";       description="Blocks Chrome from showing web push notifications";          group="Browser" },
        [PSCustomObject]@{ id="disable_edge_notifications";   name="Disable Edge Notifications";         description="Blocks Edge from showing web push notifications";            group="Browser" },
        # ── Software ──────────────────────────────────────────────────────────
        [PSCustomObject]@{ id="install_chrome";        name="Install Google Chrome";                   description="Installs Google Chrome via winget";                          group="Software" },
        [PSCustomObject]@{ id="install_acrobat";       name="Install Adobe Acrobat Reader";            description="Installs Adobe Acrobat Reader (64-bit) via winget";          group="Software" },
        [PSCustomObject]@{ id="install_vlc";           name="Install VLC Media Player";                description="Installs VLC via winget";                                    group="Software" },
        [PSCustomObject]@{ id="install_7zip";          name="Install 7-Zip";                           description="Installs 7-Zip via winget";                                  group="Software" },
        [PSCustomObject]@{ id="install_zoom";          name="Install Zoom";                            description="Installs Zoom via winget";                                   group="Software" },
        [PSCustomObject]@{ id="install_notepad";       name="Install Legacy Notepad";                  description="Installs the classic Windows Notepad via winget";            group="Software" },
        [PSCustomObject]@{ id="install_office";        name="Install Microsoft Office";                description="Installs Microsoft Office via winget (off by default)";      group="Software"; noScan=$true },
        # ── Taskbar & Explorer ────────────────────────────────────────────────
        [PSCustomObject]@{ id="search_box_icon";       name="Shrink Search Box to Icon";              description="Sets taskbar search to icon mode; hides Cortana button";     group="Taskbar" },
        [PSCustomObject]@{ id="taskbar_never_combine"; name="Never Combine Taskbar Buttons";          description="Shows separate buttons for each window on the taskbar";      group="Taskbar" },
        [PSCustomObject]@{ id="notif_show_all_icons";  name="Always Show All Tray Icons";             description="Disables auto-hide in the notification area";                group="Taskbar" },
        [PSCustomObject]@{ id="hide_people_button";    name="Hide People Button from Taskbar";        description="Removes the People button from the taskbar";                 group="Taskbar" },
        [PSCustomObject]@{ id="explorer_full_path";    name="Show Full Path in Title Bar";            description="Displays the full folder path in Explorer's title bar";      group="Explorer" },
        [PSCustomObject]@{ id="show_file_extensions";  name="Show File Extensions";                   description="Makes Explorer show extensions for all known file types";    group="Explorer" },
        [PSCustomObject]@{ id="explorer_ribbon";       name="Expand Explorer Ribbon";                 description="Keeps the Explorer ribbon expanded by default";              group="Explorer" },
        [PSCustomObject]@{ id="explorer_copy_dialog";  name="Expand Copy Dialog";                     description="Shows detailed progress in file copy/move dialogs";          group="Explorer" },
        # ── Privacy & Telemetry ───────────────────────────────────────────────
        [PSCustomObject]@{ id="disable_win_tips";           name="Disable Windows Tips & Suggestions";    description="Turns off Get tips, tricks and suggestions notifications"; group="Privacy" },
        [PSCustomObject]@{ id="disable_start_suggestions";  name="Disable Start Menu App Suggestions";   description="Removes suggested apps from the Start menu";               group="Privacy" },
        [PSCustomObject]@{ id="disable_telemetry";          name="Disable Telemetry & DiagTrack";        description="Sets AllowTelemetry=0 and disables the DiagTrack service"; group="Privacy" },
        [PSCustomObject]@{ id="update_semi_annual";         name="Updates: Semi-Annual Channel";         description="Sets Windows Update to Semi-Annual Channel (Targeted)";    group="Privacy" },
        # ── System ────────────────────────────────────────────────────────────
        [PSCustomObject]@{ id="set_timezone_est";           name="Set Time Zone to Eastern (EST)";       description="Sets system time zone to Eastern Standard Time";            group="System" },
        [PSCustomObject]@{ id="power_high_performance";     name="High Performance Power + No Hibernate"; description="High Perf plan, disk timeout=0, hibernation disabled";    group="System" }
    )
}

# =============================================================================
# PATHS & LOGGING
# =============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateFile = Join-Path $ScriptDir "task-state.json"
$LogFile   = Join-Path $ScriptDir "autoconfigtool.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$ts] [$Level] $Message"
}

# =============================================================================
# STATE
# =============================================================================
function Load-State {
    if (Test-Path $StateFile) {
        try { return Get-Content $StateFile -Raw | ConvertFrom-Json }
        catch { Write-Log "Could not parse state file, starting fresh." "WARN" }
    }
    return [PSCustomObject]@{}
}

function Save-State([PSCustomObject]$State) {
    $State | ConvertTo-Json -Depth 5 | Set-Content $StateFile -Encoding UTF8
}

function Update-State([PSCustomObject]$State, [string]$TaskId, [hashtable]$Fields) {
    $existing = [PSCustomObject]@{}
    $prop = $State.PSObject.Properties[$TaskId]
    if ($prop) { $existing = $prop.Value }
    foreach ($kv in $Fields.GetEnumerator()) {
        $existing | Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value -Force
    }
    $State | Add-Member -NotePropertyName $TaskId -NotePropertyValue $existing -Force
}

# =============================================================================
# SCAN / CHANGE DISPATCH
# =============================================================================
function Invoke-Scan {
    param([string]$TaskId, [bool]$NoScan = $false)
    if ($NoScan) { return "not-applied" }
    $fn = "Scan_$TaskId"
    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        Write-Log "No scan function: $fn" "WARN"; return "error"
    }
    try {
        $r = & $fn
        Write-Log "Scan [$TaskId]: $r"
        if ($r -in "applied","not-applied","error") { return $r }
        return "error"
    } catch {
        Write-Log "Scan [$TaskId] threw: $($_.Exception.Message)" "ERROR"
        return "error"
    }
}

function Invoke-Change {
    param(
        [string]$TaskId, [string]$TaskName, [string]$Action,
        [System.Windows.Forms.RichTextBox]$OutputBox,
        [System.Windows.Forms.Label]$StatusLabel
    )
    $prefix = if ($Action -eq "revert") { "Revert" } else { "Apply" }
    $fn     = "${prefix}_${TaskId}"
    $verb   = if ($Action -eq "revert") { "Reverting" } else { "Applying" }

    $OutputBox.SelectionColor = [System.Drawing.Color]::CornflowerBlue
    $OutputBox.AppendText("`r`n-- $verb`: $TaskName --`r`n")
    $OutputBox.SelectionColor = $clrText
    $StatusLabel.Text      = "$verb`: $TaskName..."
    $StatusLabel.ForeColor = $clrWarn
    [System.Windows.Forms.Application]::DoEvents()

    Write-Log "$verb`: $TaskId"

    if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
        $OutputBox.SelectionColor = $clrDanger
        $OutputBox.AppendText("No ${prefix}_ function found for: $TaskId`r`n")
        $OutputBox.SelectionColor = $clrText
        return "error"
    }
    try {
        $captured = & $fn *>&1
        $result   = "success"
        foreach ($line in $captured) {
            $lineStr = "$line"
            if ($lineStr -in "success","error") { $result = $lineStr; continue }
            $OutputBox.SelectionColor = if ($lineStr -match "^ERROR") { $clrDanger } else { $clrText }
            $OutputBox.AppendText($lineStr + "`r`n")
        }
        Write-Log "$verb [$TaskId]: $result"
        $OutputBox.ScrollToCaret()
        return $result
    } catch {
        $OutputBox.SelectionColor = $clrDanger
        $OutputBox.AppendText("ERROR: $($_.Exception.Message)`r`n")
        $OutputBox.SelectionColor = $clrText
        Write-Log "$verb [$TaskId] threw: $($_.Exception.Message)" "ERROR"
        return "error"
    }
}

# =============================================================================
# COLORS & FONTS
# =============================================================================
$clrBg      = [System.Drawing.Color]::FromArgb(18,  20,  30)
$clrPanel   = [System.Drawing.Color]::FromArgb(26,  30,  46)
$clrCard    = [System.Drawing.Color]::FromArgb(34,  39,  58)
$clrGroup   = [System.Drawing.Color]::FromArgb(22,  26,  40)
$clrBorder  = [System.Drawing.Color]::FromArgb(55,  65,  95)
$clrAccent  = [System.Drawing.Color]::FromArgb(80, 140, 255)
$clrText    = [System.Drawing.Color]::FromArgb(220, 225, 240)
$clrSubtext = [System.Drawing.Color]::FromArgb(130, 140, 170)
$clrSuccess = [System.Drawing.Color]::FromArgb( 80, 200, 130)
$clrWarn    = [System.Drawing.Color]::FromArgb(255, 195,  60)
$clrDanger  = [System.Drawing.Color]::FromArgb(255,  90,  90)
$clrUnknown = [System.Drawing.Color]::FromArgb( 90,  90, 120)

$fontMono   = New-Object System.Drawing.Font("Consolas", 9)
$fontLabel  = New-Object System.Drawing.Font("Segoe UI", 9)
$fontBold   = New-Object System.Drawing.Font("Segoe UI Semibold", 9)
$fontTitle  = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$fontSmall  = New-Object System.Drawing.Font("Segoe UI", 7.5)
$fontGroup  = New-Object System.Drawing.Font("Segoe UI", 7.5, [System.Drawing.FontStyle]::Bold)

# =============================================================================
# CARD UI HELPERS
# =============================================================================
$CardControls = @{}
$ScanResults  = @{}

function Get-ScanColor([string]$r) {
    switch ($r) {
        "applied"     { return $clrSuccess }
        "not-applied" { return $clrWarn    }
        "error"       { return $clrDanger  }
        default       { return $clrUnknown }
    }
}
function Get-ScanLabel([string]$r) {
    switch ($r) {
        "applied"     { return "Active on this system" }
        "not-applied" { return "Not active"            }
        "error"       { return "Scan error"            }
        default       { return "Not scanned yet"       }
    }
}
function Update-CardUI {
    param([string]$TaskId, [string]$ScanResult, [string]$LastChanged = "")
    $cc = $CardControls[$TaskId]
    if (-not $cc) { return }
    $color = Get-ScanColor $ScanResult
    $cc.Accent.BackColor      = $color
    $cc.StatusBadge.ForeColor = $color
    $cc.StatusBadge.Text      = Get-ScanLabel $ScanResult
    if ($LastChanged) {
        $cc.LastChanged.Text      = "Last changed: $LastChanged"
        $cc.LastChanged.ForeColor = $clrSubtext
    }
    if ($ScanResult -eq "applied")     { $cc.Checkbox.Checked = $true  }
    if ($ScanResult -eq "not-applied") { $cc.Checkbox.Checked = $false }
}

# =============================================================================
# LOAD DATA
# =============================================================================
$Tasks = Get-TaskList
$State = Load-State

# =============================================================================
# MAIN FORM
# =============================================================================
$Form = New-Object System.Windows.Forms.Form
$Form.Text            = "Auto Config Tool"
$Form.ClientSize      = New-Object System.Drawing.Size(960, 700)
$Form.MinimumSize     = New-Object System.Drawing.Size(820, 560)
$Form.BackColor       = $clrBg
$Form.ForeColor       = $clrText
$Form.Font            = $fontLabel
$Form.StartPosition   = "CenterScreen"
$Form.FormBorderStyle = "Sizable"

$root = New-Object System.Windows.Forms.TableLayoutPanel
$root.Dock        = "Fill"
$root.ColumnCount = 1
$root.RowCount    = 3
$root.BackColor   = $clrBg
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 60)))  | Out-Null
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$root.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))  | Out-Null
$root.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$Form.Controls.Add($root)

# ── Header ────────────────────────────────────────────────────────────────────
$pnlHeader = New-Object System.Windows.Forms.Panel
$pnlHeader.Dock      = "Fill"
$pnlHeader.BackColor = $clrPanel
$root.Controls.Add($pnlHeader, 0, 0)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "  Auto Config Tool"
$lblTitle.Font      = $fontTitle
$lblTitle.ForeColor = $clrText
$lblTitle.Dock      = "Fill"
$lblTitle.TextAlign = "MiddleLeft"
$pnlHeader.Controls.Add($lblTitle)

$lblSubtitle = New-Object System.Windows.Forms.Label
$lblSubtitle.Text      = "Checked = active on this system  "
$lblSubtitle.Font      = $fontSmall
$lblSubtitle.ForeColor = $clrSubtext
$lblSubtitle.Dock      = "Right"
$lblSubtitle.Width     = 220
$lblSubtitle.TextAlign = "MiddleRight"
$pnlHeader.Controls.Add($lblSubtitle)

# ── Body ──────────────────────────────────────────────────────────────────────
$split = New-Object System.Windows.Forms.SplitContainer
$split.Dock             = "Fill"
$split.Orientation      = "Vertical"
$split.SplitterDistance = 480
$split.BackColor        = $clrBorder
$split.Panel1.BackColor = $clrBg
$split.Panel2.BackColor = $clrBg
$root.Controls.Add($split, 0, 1)

# ── Status bar ────────────────────────────────────────────────────────────────
$pnlStatus = New-Object System.Windows.Forms.Panel
$pnlStatus.Dock      = "Fill"
$pnlStatus.BackColor = $clrPanel
$root.Controls.Add($pnlStatus, 0, 2)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text      = "Starting scan..."
$lblStatus.ForeColor = $clrSubtext
$lblStatus.Font      = $fontSmall
$lblStatus.Dock      = "Fill"
$lblStatus.TextAlign = "MiddleLeft"
$lblStatus.Padding   = New-Object System.Windows.Forms.Padding(8, 0, 0, 0)
$pnlStatus.Controls.Add($lblStatus)

# ── LEFT panel layout ─────────────────────────────────────────────────────────
$leftLayout = New-Object System.Windows.Forms.TableLayoutPanel
$leftLayout.Dock        = "Fill"
$leftLayout.ColumnCount = 1
$leftLayout.RowCount    = 3
$leftLayout.BackColor   = $clrBg
$leftLayout.Padding     = New-Object System.Windows.Forms.Padding(8, 6, 4, 6)
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22)))  | Out-Null
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$leftLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 38)))  | Out-Null
$leftLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$split.Panel1.Controls.Add($leftLayout)

$lblTasksHdr = New-Object System.Windows.Forms.Label
$lblTasksHdr.Text      = "TASKS  (checked = currently active)"
$lblTasksHdr.Font      = $fontGroup
$lblTasksHdr.ForeColor = $clrSubtext
$lblTasksHdr.Dock      = "Fill"
$lblTasksHdr.TextAlign = "BottomLeft"
$leftLayout.Controls.Add($lblTasksHdr, 0, 0)

$pnlScroll = New-Object System.Windows.Forms.Panel
$pnlScroll.Dock       = "Fill"
$pnlScroll.AutoScroll = $true
$pnlScroll.BackColor  = $clrBg
$leftLayout.Controls.Add($pnlScroll, 0, 1)

$pnlToolbar = New-Object System.Windows.Forms.Panel
$pnlToolbar.Dock      = "Fill"
$pnlToolbar.BackColor = $clrBg
$leftLayout.Controls.Add($pnlToolbar, 0, 2)

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text      = "Check All"
$btnSelectAll.FlatStyle = "Flat"
$btnSelectAll.FlatAppearance.BorderColor = $clrBorder
$btnSelectAll.BackColor = $clrCard
$btnSelectAll.ForeColor = $clrText
$btnSelectAll.Font      = $fontSmall
$btnSelectAll.Size      = New-Object System.Drawing.Size(80, 26)
$btnSelectAll.Location  = New-Object System.Drawing.Point(0, 5)
$pnlToolbar.Controls.Add($btnSelectAll)

$btnSelectNone = New-Object System.Windows.Forms.Button
$btnSelectNone.Text      = "Uncheck All"
$btnSelectNone.FlatStyle = "Flat"
$btnSelectNone.FlatAppearance.BorderColor = $clrBorder
$btnSelectNone.BackColor = $clrCard
$btnSelectNone.ForeColor = $clrText
$btnSelectNone.Font      = $fontSmall
$btnSelectNone.Size      = New-Object System.Drawing.Size(80, 26)
$btnSelectNone.Location  = New-Object System.Drawing.Point(86, 5)
$pnlToolbar.Controls.Add($btnSelectNone)

# ── RIGHT panel layout ────────────────────────────────────────────────────────
$rightLayout = New-Object System.Windows.Forms.TableLayoutPanel
$rightLayout.Dock        = "Fill"
$rightLayout.ColumnCount = 1
$rightLayout.RowCount    = 3
$rightLayout.BackColor   = $clrBg
$rightLayout.Padding     = New-Object System.Windows.Forms.Padding(4, 6, 8, 6)
$rightLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 22)))  | Out-Null
$rightLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$rightLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 46)))  | Out-Null
$rightLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$split.Panel2.Controls.Add($rightLayout)

$lblOutput = New-Object System.Windows.Forms.Label
$lblOutput.Text      = "OUTPUT"
$lblOutput.Font      = $fontGroup
$lblOutput.ForeColor = $clrSubtext
$lblOutput.Dock      = "Fill"
$lblOutput.TextAlign = "BottomLeft"
$rightLayout.Controls.Add($lblOutput, 0, 0)

$txtOutput = New-Object System.Windows.Forms.RichTextBox
$txtOutput.Dock        = "Fill"
$txtOutput.BackColor   = [System.Drawing.Color]::FromArgb(12, 14, 22)
$txtOutput.ForeColor   = $clrText
$txtOutput.Font        = $fontMono
$txtOutput.ReadOnly    = $true
$txtOutput.BorderStyle = "None"
$txtOutput.ScrollBars  = "Vertical"
$rightLayout.Controls.Add($txtOutput, 0, 1)

$pnlButtons = New-Object System.Windows.Forms.Panel
$pnlButtons.Dock      = "Fill"
$pnlButtons.BackColor = $clrBg
$rightLayout.Controls.Add($pnlButtons, 0, 2)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text      = "Scan System"
$btnScan.FlatStyle = "Flat"
$btnScan.FlatAppearance.BorderColor = $clrSuccess
$btnScan.BackColor = [System.Drawing.Color]::FromArgb(30, 70, 50)
$btnScan.ForeColor = $clrSuccess
$btnScan.Font      = $fontBold
$btnScan.Size      = New-Object System.Drawing.Size(120, 32)
$btnScan.Location  = New-Object System.Drawing.Point(0, 7)
$pnlButtons.Controls.Add($btnScan)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text      = "Apply Changes"
$btnApply.FlatStyle = "Flat"
$btnApply.FlatAppearance.BorderColor = $clrAccent
$btnApply.BackColor = $clrAccent
$btnApply.ForeColor = [System.Drawing.Color]::White
$btnApply.Font      = $fontBold
$btnApply.Size      = New-Object System.Drawing.Size(130, 32)
$btnApply.Location  = New-Object System.Drawing.Point(128, 7)
$pnlButtons.Controls.Add($btnApply)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text      = "Clear"
$btnClear.FlatStyle = "Flat"
$btnClear.FlatAppearance.BorderColor = $clrBorder
$btnClear.BackColor = $clrCard
$btnClear.ForeColor = $clrSubtext
$btnClear.Font      = $fontSmall
$btnClear.Size      = New-Object System.Drawing.Size(60, 32)
$btnClear.Location  = New-Object System.Drawing.Point(266, 7)
$pnlButtons.Controls.Add($btnClear)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text      = "Open Log"
$btnOpenLog.FlatStyle = "Flat"
$btnOpenLog.FlatAppearance.BorderColor = $clrBorder
$btnOpenLog.BackColor = $clrCard
$btnOpenLog.ForeColor = $clrSubtext
$btnOpenLog.Font      = $fontSmall
$btnOpenLog.Size      = New-Object System.Drawing.Size(75, 32)
$btnOpenLog.Location  = New-Object System.Drawing.Point(334, 7)
$pnlButtons.Controls.Add($btnOpenLog)

# =============================================================================
# BUILD TASK CARDS  (with group headers)
# =============================================================================
$CheckBoxes   = @{}
$cardY        = 4
$currentGroup = ""

foreach ($task in $Tasks) {
    # ── Group header label ────────────────────────────────────────────────────
    $grp = if ($task.PSObject.Properties["group"]) { $task.group } else { "" }
    if ($grp -and $grp -ne $currentGroup) {
        $currentGroup = $grp
        $lblGrp = New-Object System.Windows.Forms.Label
        $lblGrp.Text      = $grp.ToUpper()
        $lblGrp.Font      = $fontGroup
        $lblGrp.ForeColor = $clrAccent
        $lblGrp.BackColor = $clrBg
        $lblGrp.Size      = New-Object System.Drawing.Size(($pnlScroll.ClientSize.Width - 8), 20)
        $lblGrp.Location  = New-Object System.Drawing.Point(6, ($cardY + 4))
        $lblGrp.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
        $pnlScroll.Controls.Add($lblGrp)
        $cardY += 26
    }

    $prop        = $State.PSObject.Properties[$task.id]
    $lastChanged = if ($prop -and $prop.Value.LastChanged) { $prop.Value.LastChanged } else { "" }
    $noScan      = $task.PSObject.Properties["noScan"] -and $task.noScan

    $card = New-Object System.Windows.Forms.Panel
    $card.BackColor = $clrCard
    $card.Size      = New-Object System.Drawing.Size(($pnlScroll.ClientSize.Width - 8), 78)
    $card.Location  = New-Object System.Drawing.Point(2, $cardY)
    $card.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $card.Cursor    = "Hand"

    $accent = New-Object System.Windows.Forms.Panel
    $accent.BackColor = $clrUnknown
    $accent.Size      = New-Object System.Drawing.Size(4, 78)
    $accent.Location  = New-Object System.Drawing.Point(0, 0)
    $card.Controls.Add($accent)

    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Size      = New-Object System.Drawing.Size(20, 20)
    $cb.Location  = New-Object System.Drawing.Point(14, 29)
    $cb.BackColor = $clrCard
    $cb.Checked   = $false
    $card.Controls.Add($cb)
    $CheckBoxes[$task.id] = $cb

    $lblName = New-Object System.Windows.Forms.Label
    $lblName.Text      = $task.name
    $lblName.Font      = $fontBold
    $lblName.ForeColor = $clrText
    $lblName.Location  = New-Object System.Drawing.Point(40, 8)
    $lblName.AutoSize  = $true
    $card.Controls.Add($lblName)

    $lblDesc = New-Object System.Windows.Forms.Label
    $lblDesc.Text      = $task.description
    $lblDesc.Font      = $fontSmall
    $lblDesc.ForeColor = $clrSubtext
    $lblDesc.Location  = New-Object System.Drawing.Point(40, 27)
    $lblDesc.Size      = New-Object System.Drawing.Size(($card.Width - 48), 16)
    $lblDesc.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $card.Controls.Add($lblDesc)

    $lblBadge = New-Object System.Windows.Forms.Label
    $lblBadge.Text      = if ($noScan) { "Install only (no scan)" } else { "Scanning..." }
    $lblBadge.Font      = $fontSmall
    $lblBadge.ForeColor = if ($noScan) { $clrSubtext } else { $clrUnknown }
    $lblBadge.Location  = New-Object System.Drawing.Point(40, 45)
    $lblBadge.AutoSize  = $true
    $card.Controls.Add($lblBadge)

    $lblLast = New-Object System.Windows.Forms.Label
    $lblLast.Text      = if ($lastChanged) { "Last changed: $lastChanged" } else { "" }
    $lblLast.Font      = $fontSmall
    $lblLast.ForeColor = $clrSubtext
    $lblLast.Location  = New-Object System.Drawing.Point(40, 61)
    $lblLast.Size      = New-Object System.Drawing.Size(($card.Width - 48), 14)
    $card.Controls.Add($lblLast)

    $CardControls[$task.id] = @{
        Accent      = $accent
        StatusBadge = $lblBadge
        Checkbox    = $cb
        LastChanged = $lblLast
        NoScan      = $noScan
    }

    $cardClick = {
        param($s, $e)
        $target = if ($s -is [System.Windows.Forms.Panel]) { $s } else { $s.Parent }
        foreach ($ctrl in $target.Controls) {
            if ($ctrl -is [System.Windows.Forms.CheckBox]) { $ctrl.Checked = -not $ctrl.Checked; break }
        }
    }
    $card.Add_Click($cardClick)
    foreach ($ctrl in $card.Controls) {
        if ($ctrl -isnot [System.Windows.Forms.CheckBox]) { $ctrl.Add_Click($cardClick) }
    }

    $pnlScroll.Controls.Add($card)
    $cardY += 84
}

# =============================================================================
# SHARED: full scan pass
# =============================================================================
function Invoke-ScanAll {
    param([System.Windows.Forms.RichTextBox]$OutputBox, [bool]$Silent = $false)
    $applied = 0; $pending = 0; $errors = 0

    foreach ($task in $Tasks) {
        $noScan = $task.PSObject.Properties["noScan"] -and $task.noScan
        if ($noScan) { $ScanResults[$task.id] = "not-applied"; continue }

        if (-not $Silent) {
            $OutputBox.SelectionColor = $clrSubtext
            $OutputBox.AppendText("[$($task.name)] ")
            [System.Windows.Forms.Application]::DoEvents()
        }

        $result = Invoke-Scan -TaskId $task.id
        $ScanResults[$task.id] = $result
        Update-State $State $task.id @{ ScanResult = $result; LastScan = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") }

        $prop        = $State.PSObject.Properties[$task.id]
        $lastChanged = if ($prop -and $prop.Value.LastChanged) { $prop.Value.LastChanged } else { "" }
        Update-CardUI -TaskId $task.id -ScanResult $result -LastChanged $lastChanged

        if (-not $Silent) {
            $OutputBox.SelectionColor = Get-ScanColor $result
            $OutputBox.AppendText("$(Get-ScanLabel $result)`r`n")
        }
        switch ($result) {
            "applied"     { $applied++ }
            "not-applied" { $pending++ }
            default       { $errors++  }
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    Save-State $State
    return [PSCustomObject]@{ Applied = $applied; Pending = $pending; Errors = $errors }
}

# =============================================================================
# BUTTON EVENTS
# =============================================================================
$btnSelectAll.Add_Click({ foreach ($cb in $CheckBoxes.Values) { $cb.Checked = $true  } })
$btnSelectNone.Add_Click({ foreach ($cb in $CheckBoxes.Values) { $cb.Checked = $false } })
$btnClear.Add_Click({ $txtOutput.Clear() })
$btnOpenLog.Add_Click({
    if (Test-Path $LogFile) { Start-Process notepad.exe $LogFile }
    else { [System.Windows.Forms.MessageBox]::Show("No log file yet.", "Log", "OK", "Information") }
})

$btnScan.Add_Click({
    $btnScan.Enabled = $false; $btnApply.Enabled = $false; $btnScan.Text = "Scanning..."
    $txtOutput.Clear()
    $lblStatus.Text = "Scanning system state..."; $lblStatus.ForeColor = $clrWarn
    $txtOutput.SelectionColor = $clrSubtext
    $txtOutput.AppendText("Scanning $($Tasks.Count) tasks...`r`n`r`n")

    $counts  = Invoke-ScanAll -OutputBox $txtOutput -Silent $false
    $summary = "Scan complete: $($counts.Applied) active, $($counts.Pending) inactive"
    if ($counts.Errors -gt 0) { $summary += ", $($counts.Errors) errors" }
    $lblStatus.Text = $summary; $lblStatus.ForeColor = $clrSuccess
    $txtOutput.SelectionColor = $clrSubtext; $txtOutput.AppendText("`r`n$summary`r`n")
    Write-Log $summary
    $btnScan.Enabled = $true; $btnApply.Enabled = $true; $btnScan.Text = "Scan System"
})

$btnApply.Add_Click({
    $toApply  = [System.Collections.Generic.List[PSCustomObject]]::new()
    $toRevert = [System.Collections.Generic.List[PSCustomObject]]::new()
    $noChange = [System.Collections.Generic.List[string]]::new()

    foreach ($task in $Tasks) {
        $cbChecked  = $CheckBoxes[$task.id].Checked
        $scanResult = $ScanResults[$task.id]
        $noScan     = $task.PSObject.Properties["noScan"] -and $task.noScan

        if ($noScan) {
            # noScan tasks: checked = user wants to install, unchecked = skip
            if ($cbChecked) { $toApply.Add($task) } else { $noChange.Add($task.name) }
            continue
        }
        if ($scanResult -eq "error") { $noChange.Add("$($task.name) (scan error - skipped)"); continue }

        $isActive = ($scanResult -eq "applied")
        if     ($cbChecked -and -not $isActive) { $toApply.Add($task)  }
        elseif (-not $cbChecked -and $isActive) { $toRevert.Add($task) }
        else                                    { $noChange.Add($task.name) }
    }

    if ($toApply.Count -eq 0 -and $toRevert.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "No changes detected.`n`nCheckboxes match the current system state.`nToggle a checkbox then click Apply Changes.",
            "Nothing to Do", "OK", "Information")
        return
    }

    $btnApply.Enabled = $false; $btnScan.Enabled = $false
    $btnApply.Text = "Working..."; $btnApply.BackColor = [System.Drawing.Color]::FromArgb(50,90,180)
    $txtOutput.Clear()
    $successCount = 0; $failCount = 0

    foreach ($task in $toApply) {
        $result = Invoke-Change -TaskId $task.id -TaskName $task.name -Action "apply" -OutputBox $txtOutput -StatusLabel $lblStatus
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($result -eq "success") { Update-State $State $task.id @{ LastChanged=$ts; LastAction="applied" }; $successCount++ }
        else { $failCount++ }
    }
    foreach ($task in $toRevert) {
        $result = Invoke-Change -TaskId $task.id -TaskName $task.name -Action "revert" -OutputBox $txtOutput -StatusLabel $lblStatus
        $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        if ($result -eq "success") { Update-State $State $task.id @{ LastChanged=$ts; LastAction="reverted" }; $successCount++ }
        else { $failCount++ }
    }
    if ($noChange.Count -gt 0) {
        $txtOutput.SelectionColor = $clrSubtext
        $txtOutput.AppendText("`r`nSkipped (no change): $($noChange -join ', ')`r`n")
    }

    Save-State $State
    $summary = "Done: $successCount change(s) made"
    if ($failCount -gt 0) { $summary += ", $failCount failed" }
    $lblStatus.Text = $summary; $lblStatus.ForeColor = if ($failCount -gt 0) { $clrDanger } else { $clrSuccess }
    $txtOutput.SelectionColor = if ($failCount -gt 0) { $clrWarn } else { $clrSuccess }
    $txtOutput.AppendText("`r`n-----------------------------`r`n$summary`r`n")
    Write-Log $summary

    $txtOutput.SelectionColor = $clrSubtext; $txtOutput.AppendText("`r`nVerifying state...`r`n")
    [System.Windows.Forms.Application]::DoEvents()
    $counts = Invoke-ScanAll -OutputBox $txtOutput -Silent $true
    $verify = "Verified: $($counts.Applied) active, $($counts.Pending) inactive"
    if ($counts.Errors -gt 0) { $verify += ", $($counts.Errors) errors" }
    $txtOutput.SelectionColor = $clrSubtext; $txtOutput.AppendText("$verify`r`n")
    $lblStatus.Text = "$summary  |  $verify"; Write-Log $verify

    $btnApply.Enabled = $true; $btnScan.Enabled = $true
    $btnApply.Text = "Apply Changes"; $btnApply.BackColor = $clrAccent
})

# =============================================================================
# LAUNCH
# =============================================================================
Write-Log "AutoConfigTool opened."
$Form.Add_Shown({
    $Form.Activate()
    $split.SplitterDistance = [int]($split.Width / 2)
    $counts  = Invoke-ScanAll -OutputBox $txtOutput -Silent $true
    $summary = "Startup scan: $($counts.Applied) active, $($counts.Pending) inactive"
    if ($counts.Errors -gt 0) { $summary += ", $($counts.Errors) errors" }
    $lblStatus.Text = $summary; $lblStatus.ForeColor = $clrSuccess
    $txtOutput.SelectionColor = $clrSubtext
    $txtOutput.AppendText("$summary`r`nToggle checkboxes to make changes, then click Apply Changes.`r`n")
    Write-Log $summary
})
[void]$Form.ShowDialog()