param(
    [string]$PluginRepository = (Join-Path (Split-Path $PSScriptRoot) 'TrafficMonitorPlugins'),
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\TrafficMonitor'),
    [ValidateSet('Standard', 'Lite')][string]$Edition = 'Standard',
    [switch]$ApplyPreferredSettings,
    [switch]$SkipBuild,
    [switch]$SkipStart,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
try {
    $PluginRepository = [IO.Path]::GetFullPath($PluginRepository)
    $InstallDirectory = [IO.Path]::GetFullPath($InstallDirectory)
    $pluginProject = Join-Path $PluginRepository 'Plugins\CodexUsage\CodexUsage.vcxproj'
    $solution = Join-Path $PSScriptRoot 'TrafficMonitor.sln'
    $configuration = 'Release'
    if ($Edition -eq 'Lite') {
        $solution = Join-Path $PSScriptRoot 'TrafficMonitor_Lite.sln'
        $configuration = 'Release (lite)'
    }
    $hostOutput = Join-Path $PSScriptRoot "Bin\x64\$configuration"
    $pluginOutput = Join-Path $PluginRepository 'bin\x64\Release\CodexUsage.dll'
    $preset = Join-Path $PSScriptRoot 'config-presets\preferred'
    foreach ($path in @($solution, $pluginProject, (Join-Path $preset 'config.ini'), (Join-Path $preset 'global_cfg.ini'))) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required source file is missing: $path" }
    }
    # Keep installed binaries separate from source and build directories.
    foreach ($sourceRoot in @($PSScriptRoot, $PluginRepository)) {
        $sourcePrefix = [IO.Path]::GetFullPath($sourceRoot).TrimEnd('\') + '\'
        if ($InstallDirectory.TrimEnd('\') -eq $sourcePrefix.TrimEnd('\') -or
            $InstallDirectory.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Use an installation directory outside both source repositories.'
        }
    }
    $msbuild = $null
    if (-not $SkipBuild) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (-not (Test-Path -LiteralPath $vswhere)) { throw 'Install Visual Studio 2022 C++ desktop tools, v143 MFC, and a Windows SDK first.' }
        $candidates = @(& $vswhere -latest -version '[17.0,18.0)' -products '*' -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -find 'MSBuild\**\Bin\MSBuild.exe')
        $msbuild = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        if (-not $msbuild) { throw 'No Visual Studio 2022 MSBuild installation with C++ was found.' }
        $visualStudio = & $vswhere -latest -version '[17.0,18.0)' -products '*' -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        $mfcHeaders = @(Get-ChildItem -Path (Join-Path $visualStudio 'VC\Tools\MSVC\*\atlmfc\include\afxwin.h') -ErrorAction SilentlyContinue)
        if (-not $mfcHeaders.Count) { throw 'Install C++ MFC for the v143 x86/x64 toolset in Visual Studio Installer.' }
    }
    Write-Host "Host repository:   $PSScriptRoot"
    Write-Host "Plugin repository: $PluginRepository"
    Write-Host "Install directory: $InstallDirectory"
    Write-Host "Edition:           $Edition (x64)"
    if ($ValidateOnly) {
        Write-Host 'Validation passed. No build, copy, process shutdown, or startup was performed.'
        exit 0
    }

    # Build before touching the installed copy. Do not reset or pull repositories here.
    if (-not $SkipBuild) {
        & $msbuild $solution /t:TrafficMonitor "/p:Configuration=$configuration" /p:Platform=x64 /v:minimal /nologo
        if ($LASTEXITCODE -ne 0) { throw 'Host build failed; installation was not changed.' }
        & $msbuild $pluginProject /p:Configuration=Release /p:Platform=x64 "/p:SolutionDir=$($PluginRepository.TrimEnd('\'))\" /v:minimal /nologo
        if ($LASTEXITCODE -ne 0) { throw 'Codex plugin build failed; installation was not changed.' }
    }
    foreach ($path in @((Join-Path $hostOutput 'TrafficMonitor.exe'), $pluginOutput)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Build output is missing: $path" }
    }
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class TrafficMonitorInstallWindow {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wp, IntPtr lp);
}
'@
    $window = [TrafficMonitorInstallWindow]::FindWindow('TrafficMonitor_r7XZaS4p', $null)
    if ($window -ne [IntPtr]::Zero) {
        [uint32]$monitorProcessId = 0
        [void][TrafficMonitorInstallWindow]::GetWindowThreadProcessId($window, [ref]$monitorProcessId)
        $running = Get-Process -Id $monitorProcessId -ErrorAction SilentlyContinue
        if ($running) {
            if (-not [TrafficMonitorInstallWindow]::PostMessage($window, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)) {
                throw 'Could not close TrafficMonitor. Run this installer as administrator if the host is elevated.'
            }
            if (-not $running.WaitForExit(15000)) { throw 'TrafficMonitor did not exit. Close open dialogs and retry as administrator.' }
        }
    }
    if (Get-Process -Name TrafficMonitor -ErrorAction SilentlyContinue) { throw 'Exit all TrafficMonitor processes before installing.' }

    if (Test-Path -LiteralPath $InstallDirectory) {
        $backupRoot = Join-Path $env:LOCALAPPDATA 'TrafficMonitor-install-backups'
        $backup = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        foreach ($item in Get-ChildItem -LiteralPath $InstallDirectory -Force) {
            Copy-Item -LiteralPath $item.FullName -Destination $backup -Recurse -Force
        }
        Write-Host "Previous installation backup: $backup"
    }
    New-Item -ItemType Directory -Path $InstallDirectory -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $hostOutput 'TrafficMonitor.exe') -Destination $InstallDirectory -Force
    foreach ($file in Get-ChildItem -LiteralPath $hostOutput -Filter '*.dll' -File) {
        Copy-Item -LiteralPath $file.FullName -Destination $InstallDirectory -Force
    }
    if ($Edition -eq 'Standard') {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'OpenHardwareMonitorApi\LibreHardwareMonitorLib.dll') -Destination $InstallDirectory -Force
    }
    foreach ($folder in @('language', 'skins')) {
        $destination = Join-Path $InstallDirectory $folder
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        foreach ($item in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot "TrafficMonitor\$folder") -Force) {
            Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force
        }
    }
    $pluginsDirectory = Join-Path $InstallDirectory 'plugins'
    New-Item -ItemType Directory -Path $pluginsDirectory -Force | Out-Null
    $installedPlugin = Join-Path $pluginsDirectory 'CodexUsage.dll'
    Copy-Item -LiteralPath $pluginOutput -Destination $installedPlugin -Force
    if ((Get-FileHash -LiteralPath $pluginOutput).Hash -ne (Get-FileHash -LiteralPath $installedPlugin).Hash) { throw 'Installed plugin hash does not match the independent build.' }
    # New installs get the preferred configuration. Upgrades preserve existing choices by default.
    $newSettings = -not (Test-Path -LiteralPath (Join-Path $InstallDirectory 'config.ini')) -and
        -not (Test-Path -LiteralPath (Join-Path $InstallDirectory 'global_cfg.ini'))
    if ($ApplyPreferredSettings -or $newSettings) {
        foreach ($name in @('config.ini', 'global_cfg.ini')) {
            Copy-Item -LiteralPath (Join-Path $preset $name) -Destination (Join-Path $InstallDirectory $name) -Force
        }
    }
    Write-Host "Installed host and independent Codex plugin at: $InstallDirectory"
    Write-Host "Plugin SHA256: $((Get-FileHash -LiteralPath $installedPlugin).Hash)"
    if (-not $SkipStart) {
        Start-Process -FilePath (Join-Path $InstallDirectory 'TrafficMonitor.exe') -WorkingDirectory $InstallDirectory | Out-Null
    }
    exit 0
}
catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
