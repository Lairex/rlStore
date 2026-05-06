if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ProgressPreference = 'SilentlyContinue'

function Log {
    param ([string]$Type, [string]$Message)
    $Type = $Type.ToUpper()
    switch ($Type) {
        "OK"   { $fg = "Green" }
        "INFO" { $fg = "Cyan" }
        "ERR"  { $fg = "Red" }
        "WARN" { $fg = "Yellow" }
        default { $fg = "White" }
    }
    $date = Get-Date -Format "HH:mm:ss"
    Write-Host "[$date] " -ForegroundColor Cyan -NoNewline
    Write-Host "[$Type] $Message" -ForegroundColor $fg
}

function CheckSteamtools {
    foreach ($file in @("dwmapi.dll", "xinput1_4.dll")) {
        if (!(Test-Path (Join-Path $steam $file))) { return $false }
    }
    return $true
}

if (CheckSteamtools) {
    Log "INFO" "Steamtools already installed"
    Read-Host "Press Enter to exit"
    exit
}

Get-Process steam -ErrorAction SilentlyContinue | Stop-Process -Force
Log "INFO" "Steam closed"

Log "INFO" "Downloading Steamtools..."
$script = Invoke-RestMethod "https://steam.run"

$keptLines = @()
foreach ($line in $script -split "`n") {
    $skip = @(
        ($line -imatch "Start-Process" -and $line -imatch "steam"),
        ($line -imatch "steam\.exe"),
        ($line -imatch "Start-Sleep" -or $line -imatch "Write-Host"),
        ($line -imatch "cls" -or $line -imatch "exit"),
        ($line -imatch "Stop-Process" -and -not ($line -imatch "Get-Process"))
    )
    if (-not ($skip -contains $true)) { $keptLines += $line }
}

Log "WARN" "Installing Steamtools..."
Invoke-Expression ($keptLines -join "`n") *> $null

if (CheckSteamtools) {
    Log "OK" "Steamtools installed successfully!"
} else {
    Log "ERR" "Installation failed, try again."
}

Read-Host "Press Enter to exit"
