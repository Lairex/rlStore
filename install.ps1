
Write-Host "Installing the plugin" -ForegroundColor Cyan

Get-Process -Name "steam" -ErrorAction SilentlyContinue | Stop-Process -Force

$steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name 'InstallPath' -ErrorAction SilentlyContinue).InstallPath
if (-not $steamPath) {
    $steamPath = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamPath' -ErrorAction SilentlyContinue).SteamPath
}

if (-not $steamPath) {
    Write-Host "Steam directory not found! Please make sure Steam is installed." -ForegroundColor Red
} else {
    $zipUrl = "https://github.com/madoiscool/BetterSteamTools/releases/download/v1.0.4/OpenSteamTool-v1.0.4-Release.zip"
    $tempZip = "$env:TEMP\BetterSteamTools.zip"
    $tempExtract = "$env:TEMP\BetterSteamTools_Extract"

    try {

        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing

        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
        Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force

        $oldFolder = Join-Path $steamPath "opensteamtool"
        if (Test-Path $oldFolder) { Remove-Item -Path $oldFolder -Recurse -Force }

        Copy-Item -Path "$tempExtract\*" -Destination $steamPath -Recurse -Force

        Write-Host "BetterSteamTools successfully installed to: $steamPath" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to install BetterSteamTools: $_" -ForegroundColor Red
    }
    finally {
        if (Test-Path $tempZip) { Remove-Item -Path $tempZip -Force }
        if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force }
    }
}
