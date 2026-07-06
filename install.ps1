# STEAMTOOLS-ONLY installer -- trimmed down version.
# Installs Steamtools only. All Millennium / plugin / config.json logic removed.
#
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 # fix SSL/TSL Error
$Script:ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$null = chcp 65001
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ---------------------------------------------------------------------------
# Strings
# ---------------------------------------------------------------------------
$L = @{
    Title                 = "Steamtools installer"
    SteamRegNotFound      = "Steam registry key not found. Is Steam installed?"
    SteamKilling          = "Stopping Steam"
    SteamtoolsInstalling  = "Installing Steamtools"
    SteamtoolsInstalled   = "Steamtools installed"
    SteamtoolsFailed      = "Steamtools installation failed"
    StartingSteam         = "Starting Steam"

    ErrorTitle            = "Steamtools installer - ERROR"
    ErrorHeader           = "AN ERROR OCCURRED"
    ErrorBody             = "The installer encountered a problem and could not complete."
    ErrorExit             = "Press any key to exit."
}

# ---------------------------------------------------------------------------
# Global error trap
# ---------------------------------------------------------------------------
$Script:OriginalErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Stop"

trap {
    $errMsg = $_.Exception.Message
    $host.UI.RawUI.CursorPosition = @{ X=0; Y=0 }
    $host.UI.RawUI.WindowTitle = $L["ErrorTitle"]
    Clear-Host

    $width = $host.UI.RawUI.WindowSize.Width
    Write-Host ("=" * $width) -ForegroundColor Red
    Write-Host ""
    $pad = [Math]::Max(0, [int](($width - $L["ErrorHeader"].Length) / 2))
    Write-Host (" " * $pad) -NoNewline
    Write-Host $L["ErrorHeader"] -ForegroundColor Red -BackgroundColor Black
    Write-Host ""
    Write-Host $L["ErrorBody"] -ForegroundColor White
    Write-Host ""
    Write-Host ">>> " -NoNewline -ForegroundColor Yellow
    Write-Host $errMsg -ForegroundColor Gray
    Write-Host ""
    Write-Host ("=" * $width) -ForegroundColor Red
    Write-Host ""
    Write-Host $L["ErrorExit"] -ForegroundColor Yellow
    try { $null = [System.Console]::ReadKey($true) } catch {}

    $ErrorActionPreference = $Script:OriginalErrorAction
    break
}

# ---------------------------------------------------------------------------
# Console helpers
# ---------------------------------------------------------------------------
$Host.UI.RawUI.WindowTitle = $L["Title"]

$LogColors = @{ "OK"="Green"; "INFO"="Cyan"; "ERR"="Red"; "WARN"="Yellow" }

function Write-Log {
    param(
        [ValidateSet("OK","INFO","ERR","WARN")]
        [string]$Type,
        [string]$Message
    )
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] " -ForegroundColor Cyan -NoNewline
    Write-Host "[$Type] $Message" -ForegroundColor $LogColors[$Type]
}

# ---------------------------------------------------------------------------
# Steam path
# ---------------------------------------------------------------------------
function Get-SteamPath {
    $registries = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKCU:\SOFTWARE\Valve\Steam"
    )
    foreach ($reg in $registries) {
        if (!(Test-Path $reg)) { continue }
        $path = (Get-ItemProperty -Path $reg -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
        $potentialExe = Join-Path $path "steam.exe"
        if ((Test-Path $path) -and (Test-Path $potentialExe)) {
            return $path
        }
    }
    Write-Log -Type ERR -Message $L["SteamRegNotFound"]
}

# ---------------------------------------------------------------------------
# Steamtools
# ---------------------------------------------------------------------------
function Test-Steamtools {
    param([string]$SteamPath)
    foreach ($f in @("dwmapi.dll", "xinput1_4.dll")) {
        if (Test-Path -LiteralPath (Join-Path $SteamPath $f)) { return $true }
    }
    return $false
}

function Install-Steamtools {
    param([string]$SteamPath)

    Write-Log -Type INFO -Message $L["SteamtoolsInstalling"]

    $zipFile = Join-Path $SteamPath "ost.zip"
    Invoke-WebRequest -Uri "https://github.com/madoiscool/lt_api_links/releases/download/ost-148/ost.zip" -OutFile $zipFile -TimeoutSec 60 -UseBasicParsing
    if (-not (Test-Path -LiteralPath $zipFile)) { throw $L["SteamtoolsFailed"] }

    Get-Process -Name "steam", "steamwebhelper" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $zipFile -DestinationPath $SteamPath -Force
    Remove-Item -LiteralPath $zipFile -Force -ErrorAction SilentlyContinue

    $steamCfg = Join-Path $SteamPath "steam.cfg"
    $steamCfgBak = Join-Path $SteamPath "steam.cfg.bak"
    if (Test-Path -LiteralPath $steamCfg) {
        Move-Item -LiteralPath $steamCfg -Destination $steamCfgBak -Force -ErrorAction SilentlyContinue
    }

    if (Test-Steamtools $SteamPath) {
        Write-Log -Type OK -Message $L["SteamtoolsInstalled"]
        return
    }

    throw $L["SteamtoolsFailed"]
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Main {
    $steamPath = Get-SteamPath

    Write-Log -Type INFO -Message $L["SteamKilling"]
    while (Get-Process steam -ErrorAction SilentlyContinue) {
        Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Milliseconds 500
    }

    Install-Steamtools $steamPath

    Write-Log -Type INFO -Message $L["StartingSteam"]
    Start-Process (Join-Path $steamPath "steam.exe")

    $ErrorActionPreference = $Script:OriginalErrorAction
}

Main
