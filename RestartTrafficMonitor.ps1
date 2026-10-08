param(
    [switch]$Elevated,
    [switch]$ValidateOnly,
    [switch]$ImportSToolsSettings,
    [switch]$UseRepositorySettings
)

$ErrorActionPreference = 'Stop'
try {
    Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
    $targetExe = Join-Path $PSScriptRoot 'TrafficMonitor.exe'
    $pluginDll = Join-Path $PSScriptRoot 'plugins\CodexUsage.dll'
    $pluginBuild = Join-Path (Split-Path $PSScriptRoot) 'TrafficMonitorPlugins\bin\x64\Release\CodexUsage.dll'
    foreach ($file in @($targetExe)) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Required file is missing: $file"
        }
    }
    if (-not (Test-Path -LiteralPath $pluginBuild -PathType Leaf) -and
        -not (Test-Path -LiteralPath $pluginDll -PathType Leaf)) {
        throw "Build the independent Codex plugin first, or install its DLL at: $pluginDll"
    }
    $settingsSource = 'D:\STools\TrafficMonitor'
    $settingsFiles = @('config.ini', 'global_cfg.ini', 'history_traffic.dat', 'history_traffic.dat.bak')
    $resourceFolders = @('skins', 'language', 'Logo')
    if ($ImportSToolsSettings -and $UseRepositorySettings) {
        throw 'Choose either STools settings or repository settings.'
    }
    if ($UseRepositorySettings) {
        $settingsSource = Join-Path $PSScriptRoot 'config-presets\preferred'
        $settingsFiles = @('config.ini', 'global_cfg.ini')
        $resourceFolders = @()
    }
    if ($ImportSToolsSettings -or $UseRepositorySettings) {
        foreach ($name in @('config.ini', 'global_cfg.ini')) {
            if (-not (Test-Path -LiteralPath (Join-Path $settingsSource $name) -PathType Leaf)) {
                throw "Settings are missing: $(Join-Path $settingsSource $name)"
            }
        }
        $globalSettings = Get-Content -LiteralPath (Join-Path $settingsSource 'global_cfg.ini') -Raw
        if ($globalSettings -notmatch '(?im)^\s*portable_mode\s*=\s*true\s*$') {
            throw 'The settings source is not in portable mode; its actual settings directory must be checked first.'
        }
    }
    if ($ValidateOnly) {
        Write-Host "Host:   $targetExe"
        Write-Host "Plugin: $pluginDll"
        if (Test-Path -LiteralPath $pluginBuild -PathType Leaf) { Write-Host "Plugin build: $pluginBuild" }
        if ($ImportSToolsSettings -or $UseRepositorySettings) { Write-Host "Import source: $settingsSource (portable mode)" }
        Write-Host 'Validation passed; no running process was changed.'
        exit 0
    }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if ($Elevated) { throw 'Administrator access was not granted.' }
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Elevated' -f $PSCommandPath
        if ($ImportSToolsSettings) { $arguments += ' -ImportSToolsSettings' }
        if ($UseRepositorySettings) { $arguments += ' -UseRepositorySettings' }
        $child = Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait -PassThru
        exit $child.ExitCode
    }

    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TrafficMonitorRestartWindow {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr FindWindow(string className, string title);
    public static IntPtr FindMainWindow() { return FindWindow("TrafficMonitor_r7XZaS4p", null); }
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);
    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool PostMessage(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
}
'@
    $window = [TrafficMonitorRestartWindow]::FindMainWindow()
    if ($window -ne [IntPtr]::Zero) {
        [uint32]$monitorProcessId = 0
        [void][TrafficMonitorRestartWindow]::GetWindowThreadProcessId($window, [ref]$monitorProcessId)
        $running = Get-Process -Id $monitorProcessId -ErrorAction SilentlyContinue
        if ($running) {
            Write-Host "Closing TrafficMonitor (PID $monitorProcessId), allowing it to save settings and history..."
            if (-not [TrafficMonitorRestartWindow]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)) {
                throw 'Could not request TrafficMonitor to exit.'
            }
            if (-not $running.WaitForExit(15000)) {
                throw 'TrafficMonitor did not exit within 15 seconds. Close any open dialogs and try again.'
            }
        }
    }
    if (Get-Process -Name TrafficMonitor -ErrorAction SilentlyContinue) {
        throw 'A TrafficMonitor process is still running. Exit it from the tray and try again.'
    }

    # Only the independent plugin repository builds CodexUsage.dll.
    if (Test-Path -LiteralPath $pluginBuild -PathType Leaf) {
        $updatePlugin = -not (Test-Path -LiteralPath $pluginDll -PathType Leaf)
        if (-not $updatePlugin) {
            $updatePlugin = (Get-FileHash -LiteralPath $pluginBuild).Hash -ne (Get-FileHash -LiteralPath $pluginDll).Hash
        }
        if ($updatePlugin) {
            if (Test-Path -LiteralPath $pluginDll -PathType Leaf) {
                $pluginBackup = Join-Path 'D:\Codex' ('TrafficMonitor-plugin-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
                New-Item -ItemType Directory -Path $pluginBackup | Out-Null
                Copy-Item -LiteralPath $pluginDll -Destination $pluginBackup
            }
            New-Item -ItemType Directory -Path (Split-Path $pluginDll) -Force | Out-Null
            Copy-Item -LiteralPath $pluginBuild -Destination $pluginDll -Force
            if ((Get-FileHash -LiteralPath $pluginBuild).Hash -ne (Get-FileHash -LiteralPath $pluginDll).Hash) {
                throw 'Installed Codex plugin does not match the independent build.'
            }
            Write-Host "Installed independent plugin: $pluginBuild"
        }
        $calendarSource = Join-Path (Split-Path $pluginBuild) 'calendar'
        if (Test-Path -LiteralPath $calendarSource -PathType Container) {
            $calendarDestination = Join-Path (Split-Path $pluginDll) 'calendar'
            New-Item -ItemType Directory -Path $calendarDestination -Force | Out-Null
            foreach ($file in Get-ChildItem -LiteralPath $calendarSource -Filter '*.txt' -File) {
                $target = Join-Path $calendarDestination $file.Name
                if (-not (Test-Path -LiteralPath $target)) {
                    Copy-Item -LiteralPath $file.FullName -Destination $target
                }
            }
        }
    }

    if ($ImportSToolsSettings -or $UseRepositorySettings) {
        $destination = Split-Path $targetExe
        $backup = Join-Path 'D:\Codex' ('TrafficMonitor-settings-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
        New-Item -ItemType Directory -Path $backup | Out-Null
        # Preserve the destination's previous settings before overwriting anything.
        foreach ($name in ($settingsFiles + $resourceFolders)) {
            $existing = Join-Path $destination $name
            if (Test-Path -LiteralPath $existing) {
                Copy-Item -LiteralPath $existing -Destination $backup -Recurse -Force
            }
        }
        foreach ($name in $settingsFiles) {
            $sourceFile = Join-Path $settingsSource $name
            if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
                $destinationFile = Join-Path $destination $name
                Copy-Item -LiteralPath $sourceFile -Destination $destinationFile -Force
                if ((Get-FileHash -LiteralPath $sourceFile).Hash -ne (Get-FileHash -LiteralPath $destinationFile).Hash) {
                    throw "Copied settings did not match: $name (backup: $backup)"
                }
            }
        }
        foreach ($name in $resourceFolders) {
            $sourceFolder = Join-Path $settingsSource $name
            if (Test-Path -LiteralPath $sourceFolder -PathType Container) {
                $destinationFolder = Join-Path $destination $name
                New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
                foreach ($item in Get-ChildItem -LiteralPath $sourceFolder -Force) {
                    Copy-Item -LiteralPath $item.FullName -Destination $destinationFolder -Recurse -Force
                }
            }
        }
        Write-Host "Imported settings from $settingsSource. Previous destination data: $backup"
    }

    $started = Start-Process -FilePath $targetExe -WorkingDirectory (Split-Path $targetExe) -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 2
    $started.Refresh()
    if ($started.HasExited) { throw 'The new TrafficMonitor process exited immediately.' }
    Write-Host "Started $targetExe (PID $($started.Id))."
    exit 0
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($Elevated) { [void](Read-Host 'Press Enter to close') }
    exit 1
}
