#Requires -Version 5.1
<#
.SYNOPSIS
    Starts the Rojo server for Cultivation Tycoon.
.DESCRIPTION
    Double-click start-rojo.bat, or run this directly:
        .\start-rojo.ps1
        .\start-rojo.ps1 -Port 34876      # different port
        .\start-rojo.ps1 -Build           # one-off build instead of serve
.NOTES
    Idempotent: if the port is already serving, it says so and exits cleanly.
#>
[CmdletBinding()]
param(
    [int]$Port = 34875,   # default.project.json servePort; Heavenly 34872, Gladiator 34873, Follows 34874
    [string]$ProjectFile = 'default.project.json',
    [switch]$Build,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

function Write-Step { param($m) Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok   { param($m) Write-Host "[ok] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "[!]  $m" -ForegroundColor Yellow }

# Resolve rojo: PATH first, then known winget install locations.
# (Old laptop installed to WinGet\Links; this one to WinGet\Packages.)
function Resolve-Rojo {
    $cmd = Get-Command rojo -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    $candidates = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Links\rojo.exe",
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Rojo.Rojo_*\rojo.exe",
        "$env:USERPROFILE\.aftman\bin\rojo.exe",
        "$env:USERPROFILE\.rokit\bin\rojo.exe",
        "$env:USERPROFILE\.cargo\bin\rojo.exe"
    )
    foreach ($p in $candidates) {
        $hit = Get-Item $p -ErrorAction SilentlyContinue |
               Sort-Object FullName -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

# Keep the local Studio plugin version-locked to the CLI. (2026-09-08: the
# marketplace plugin silently stopped auto-updating and broke sync.)
function Sync-RojoPlugin {
    param($RojoPath, $Version)
    $pluginDir  = Join-Path $env:LOCALAPPDATA 'Roblox\Plugins'
    $pluginFile = Join-Path $pluginDir 'RojoManagedPlugin.rbxm'
    $marker     = Join-Path $pluginDir 'RojoManagedPlugin.cli-version.txt'
    $installed = ''
    if (Test-Path -LiteralPath $marker) {
        $installed = (Get-Content -LiteralPath $marker -Raw).Trim()
    }
    if ($installed -eq $Version -and (Test-Path -LiteralPath $pluginFile)) {
        Write-Ok "Studio plugin matches CLI ($Version)"
        return
    }
    Write-Step "Studio plugin out of date - installing to match $Version"
    & $RojoPath plugin install
    if ($LASTEXITCODE -ne 0) { throw "rojo plugin install failed (exit $LASTEXITCODE)." }
    Set-Content -LiteralPath $marker -Value $Version -Encoding ascii
    Write-Ok "Plugin installed. If Studio is already open, restart it so the new plugin loads."
}

$exitCode = 0
try {
    # Anchor to the script's own folder, so the repo can live anywhere
    # (this laptop is C:\Users\Elidia, the old one was sa_matteo).
    $projectDir = $PSScriptRoot
    if (-not $projectDir) { $projectDir = (Get-Location).Path }

    $projectPath = Join-Path $projectDir $ProjectFile
    if (-not (Test-Path -LiteralPath $projectPath)) {
        throw "Project file not found: $projectPath"
    }

    $rojoPath = Resolve-Rojo
    if (-not $rojoPath) {
        throw "rojo.exe not found on PATH or in the usual install folders. Install it with:  winget install Rojo.Rojo"
    }

    $version = (& $rojoPath --version) -join ' '
    Write-Ok "$version  ($rojoPath)"
    Write-Ok "project: $projectPath"

    if ($Build) {
        $out = Join-Path $projectDir 'build\cultivation-tycoon.rbxlx'
        $outDir = Split-Path $out -Parent
        if (-not (Test-Path -LiteralPath $outDir)) {
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
        }
        Write-Step "Building -> $out"
        & $rojoPath build $projectPath --output $out
        if ($LASTEXITCODE -ne 0) { throw "rojo build failed (exit $LASTEXITCODE)." }
        Write-Ok "Build succeeded. NOTE: rojo build does NOT parse Luau - it is not a compile check."
        return
    }

    Sync-RojoPlugin -RojoPath $rojoPath -Version $version

    # The marketplace plugin duplicates (and can lag) the CLI-managed one.
    $cloud = Get-ChildItem "$env:LOCALAPPDATA\Roblox\*\InstalledPlugins\13916111004" -ErrorAction SilentlyContinue
    if ($cloud) {
        Write-Warn "Marketplace Rojo plugin is still installed - remove it in Studio (Manage Plugins) to avoid a duplicate/stale toolbar."
    }

    $listening = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    if ($listening) {
        $ownerPid = ($listening | Select-Object -First 1).OwningProcess
        $owner = (Get-Process -Id $ownerPid -ErrorAction SilentlyContinue).ProcessName
        Write-Warn "Port $Port is already in use by $owner (PID $ownerPid)."
        if ($owner -eq 'rojo') {
            Write-Ok "Rojo is already serving. Connect from the Studio plugin and carry on."
        } else {
            Write-Warn "That is not rojo. Re-run with a different port:  .\start-rojo.ps1 -Port 34876"
            $exitCode = 1
        }
        return
    }

    Write-Step "Serving on port $Port  -  press Ctrl+C to stop"
    Push-Location $projectDir
    try {
        & $rojoPath serve --port $Port $ProjectFile
        $exitCode = $LASTEXITCODE
    }
    finally {
        Pop-Location   # never leave the caller's shell in a moved directory
    }

    # Rojo does NOT sync while Studio is in Play mode - stop Play to see edits.
}
catch {
    Write-Host ""
    Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
    $exitCode = 1
}
finally {
    if (-not $NoPause -and $Host.Name -eq 'ConsoleHost') {
        Write-Host ""
        Write-Host "Press any key to close..." -ForegroundColor DarkGray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    exit $exitCode
}
