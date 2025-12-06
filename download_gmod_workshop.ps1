[CmdletBinding()]
param(
    [string]$SteamCmdPath = ".\steamcmd\steamcmd.exe",
    [string]$GmadPath = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\GarrysMod\\bin\\gmad.exe",
    [string[]]$WorkshopIds,
    [string]$ExtractRoot = ".\extracted"
)

$ErrorActionPreference = "Stop"
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location -Path $scriptRoot

try {
    $utf8 = [System.Text.Encoding]::UTF8
    if ($Host.Name -ne "ConsoleHost") {
        [Console]::OutputEncoding = $utf8
        [Console]::InputEncoding = $utf8
    }
    else {
        [Console]::OutputEncoding = $utf8
        [Console]::InputEncoding = $utf8
    }
}
catch {
    Write-Verbose "Unable to configure UTF-8 console: $($_.Exception.Message)"
}

function Resolve-SteamCmdTargetPath {
    param([string]$RequestedPath)

    $candidate = $RequestedPath
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        $candidate = ".\steamcmd\steamcmd.exe"
    }

    if (-not [System.IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $scriptRoot $candidate
    }

    $candidate = [System.IO.Path]::GetFullPath($candidate)
    $parent = Split-Path -Parent $candidate
    if (($parent -match '(?i)onedrive') -or ($parent -match '(?i)dropbox') -or ($parent -match '(?i)google drive')) {
        $fallbackDir = Join-Path $env:LOCALAPPDATA 'SteamCMD'
        Write-Host "Detected synced/cloud directory for SteamCMD. Switching to local path: $fallbackDir" -ForegroundColor Yellow
        $candidate = Join-Path $fallbackDir 'steamcmd.exe'
    }

    return $candidate
}

function Assert-FileExists {
    param (
        [string]$Path,
        [string]$FriendlyName
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "${FriendlyName} not found: $Path"
    }
}

function Ensure-SteamCmd {
    param([string]$ExePath)

    if (Test-Path -LiteralPath $ExePath) {
        return (Resolve-Path -LiteralPath $ExePath).Path
    }

    $steamCmdUrl = "https://steamcdn-a.akamaihd.net/client/installer/steamcmd.zip"
    $installDir = Split-Path -Parent $ExePath

    if (-not (Test-Path -LiteralPath $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    $tempZip = Join-Path ([System.IO.Path]::GetTempPath()) ("steamcmd_{0}.zip" -f ([System.Guid]::NewGuid()))
    $originalProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    [System.Net.ServicePointManager]::SecurityProtocol = $originalProtocol -bor [System.Net.SecurityProtocolType]::Tls12

    Write-Host "SteamCMD not found. Starting automatic download..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $steamCmdUrl -OutFile $tempZip -UseBasicParsing
        Expand-Archive -LiteralPath $tempZip -DestinationPath $installDir -Force
    }
    catch {
        throw "SteamCMD auto-install failed: $($_.Exception.Message)"
    }
    finally {
        [System.Net.ServicePointManager]::SecurityProtocol = $originalProtocol
        Remove-Item -LiteralPath $tempZip -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path -LiteralPath $ExePath)) {
        throw "SteamCMD download finished but the expected executable is missing: $ExePath"
    }
    Write-Host "SteamCMD downloaded and ready." -ForegroundColor Green
    return (Resolve-Path -LiteralPath $ExePath).Path
}

function Initialize-SteamCmd {
    param(
        [string]$ExePath,
        [string]$WorkingDirectory,
        [int]$MaxAttempts = 2,
        [int[]]$AcceptableExitCodes = @(0, 7)
    )

    $resolvedExe = (Resolve-Path -LiteralPath $ExePath).Path
    $installDir = $WorkingDirectory

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        Write-Host "Preparing SteamCMD (attempt $attempt/$MaxAttempts)..." -ForegroundColor DarkCyan
        $proc = Start-Process -FilePath $resolvedExe -ArgumentList "+login anonymous +quit" -WorkingDirectory $installDir -NoNewWindow -Wait -PassThru
        if ($AcceptableExitCodes -contains $proc.ExitCode) {
            if ($proc.ExitCode -ne 0) {
                Write-Host "SteamCMD exited with code $($proc.ExitCode) (treated as success)." -ForegroundColor DarkYellow
            }
            Write-Host "SteamCMD is up to date." -ForegroundColor Green
            return $resolvedExe
        }

        Write-Warning "SteamCMD self-update exited with code $($proc.ExitCode)."
        if ($attempt -lt $MaxAttempts) {
            Write-Host "Re-downloading SteamCMD package and retrying..." -ForegroundColor Yellow
            Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue
            $resolvedExe = Ensure-SteamCmd -ExePath $ExePath
            $installDir = Split-Path -Parent $resolvedExe
        }
    }

    throw "SteamCMD initialization failed after $MaxAttempts attempts. Check 'steamcmd\\logs\\stderr.txt' for details."
}

function Normalize-WorkshopIds {
    param([string[]]$RawIds)

    if (-not $RawIds) {
        return @()
    }

    $candidates = @()
    foreach ($entry in $RawIds) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        $tokens = $entry -split "[\s,;]+"
        foreach ($token in $tokens) {
            if ([string]::IsNullOrWhiteSpace($token)) { continue }
            $matches = [regex]::Matches($token, '\d{5,}')
            foreach ($match in $matches) {
                $candidates += $match.Value
            }
        }
    }

    return $candidates | Select-Object -Unique
}

function Get-WorkshopIds {
    param([string[]]$CliIds)

    $ids = Normalize-WorkshopIds -RawIds $CliIds
    if ($ids -and $ids.Count -gt 0) {
        return $ids
    }

    Write-Host "Enter the workshop IDs you want to download." -ForegroundColor Cyan
    Write-Host "Use commas, spaces, or paste full workshop URLs." -ForegroundColor Cyan

    $line = Read-Host "IDs"
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw "Please provide at least one workshop ID."
    }

    $ids = Normalize-WorkshopIds -RawIds @($line)
    if (-not $ids -or $ids.Count -eq 0) {
        throw "Please provide at least one numeric workshop ID."
    }

    return $ids
}

function Invoke-SteamCmdDownload {
    param(
        [string]$SteamCmd,
        [string]$WorkingDirectory,
        [string]$WorkshopId
    )

    $arguments = "+@sSteamCmdForcePlatformType windows +login anonymous +workshop_download_item 4000 $WorkshopId validate +quit"
    Write-Host "[STEAMCMD] Downloading #$WorkshopId..." -ForegroundColor Cyan
    $process = Start-Process -FilePath $SteamCmd -ArgumentList $arguments -WorkingDirectory $WorkingDirectory -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "SteamCMD download failed (ID: $WorkshopId). Exit code: $($process.ExitCode)"
    }
}

function Expand-GmaFiles {
    param(
        [string]$Gmad,
        [string]$WorkshopId,
        [System.IO.FileInfo[]]$GmaFiles,
        [string]$ExtractFolder
    )

    if (-not (Test-Path -LiteralPath $ExtractFolder)) {
        New-Item -ItemType Directory -Path $ExtractFolder -Force | Out-Null
    }

    foreach ($gma in $GmaFiles) {
        Write-Host "[GMAD] Extracting $($gma.Name)..." -ForegroundColor Yellow
        $args = @("extract", "-file", $gma.FullName, "-out", $ExtractFolder)
        $proc = Start-Process -FilePath $Gmad -ArgumentList $args -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            throw "GMAD extraction failed (ID: $WorkshopId, file: $($gma.Name))"
        }
    }
}

function Handle-LegacyBins {
    param(
        [System.IO.FileInfo[]]$BinFiles,
        [string]$TargetFolder
    )

    $convertedGmas = @()
    $zipExtracted = $false

    foreach ($bin in $BinFiles) {
        $extracted = $false
        try {
            if (-not (Test-Path -LiteralPath $TargetFolder)) {
                New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
            }
            Expand-Archive -LiteralPath $bin.FullName -DestinationPath $TargetFolder -Force -ErrorAction Stop
            $zipExtracted = $true
            $extracted = $true
            Write-Host "Unpacked legacy archive $($bin.Name) as ZIP." -ForegroundColor DarkYellow
        }
        catch {
            Write-Verbose "Legacy archive $($bin.Name) not a ZIP: $($_.Exception.Message)"
        }

        if ($extracted) { continue }

        $headerBytes = New-Object byte[] 4
        $stream = [System.IO.File]::Open($bin.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $bytesRead = $stream.Read($headerBytes, 0, 4)
        $stream.Dispose()
        if ($bytesRead -lt 4) { continue }

        $signature = [System.Text.Encoding]::ASCII.GetString($headerBytes)
        if ($signature -eq 'GMAD') {
            $newPath = [System.IO.Path]::ChangeExtension($bin.FullName, '.gma')
            Copy-Item -LiteralPath $bin.FullName -DestinationPath $newPath -Force
            $convertedGmas += Get-Item -LiteralPath $newPath
        }
    }

    return [pscustomobject]@{
        ConvertedGmas = $convertedGmas
        ZipExtracted  = $zipExtracted
    }
}

$SteamCmdPath = Resolve-SteamCmdTargetPath -RequestedPath $SteamCmdPath
$SteamCmdPath = Ensure-SteamCmd -ExePath $SteamCmdPath
$steamCmdDirectory = Split-Path -Parent (Resolve-Path -LiteralPath $SteamCmdPath)
$null = Initialize-SteamCmd -ExePath $SteamCmdPath -WorkingDirectory $steamCmdDirectory
Assert-FileExists -Path $SteamCmdPath -FriendlyName "SteamCMD"
Assert-FileExists -Path $GmadPath -FriendlyName "GMAD"

$steamRoot = $steamCmdDirectory
$workshopRoot = Join-Path $steamRoot "steamapps\\workshop\\content\\4000"
$ids = Get-WorkshopIds -CliIds $WorkshopIds
Write-Host "Queued workshop IDs: $($ids -join ', ')" -ForegroundColor Magenta

if (-not (Test-Path -LiteralPath $ExtractRoot)) {
    New-Item -ItemType Directory -Path $ExtractRoot -Force | Out-Null
}

foreach ($id in $ids) {
    try {
        Invoke-SteamCmdDownload -SteamCmd $SteamCmdPath -WorkingDirectory $steamCmdDirectory -WorkshopId $id
        $addonFolder = Join-Path $workshopRoot $id
        if (-not (Test-Path -LiteralPath $addonFolder)) {
            throw "SteamCMD did not produce files for $id. Missing folder: $addonFolder"
        }

        $targetFolder = Join-Path (Resolve-Path -LiteralPath $ExtractRoot) $id

        $gmaFiles = Get-ChildItem -Path $addonFolder -Filter '*.gma' -File -Recurse
        if (-not $gmaFiles -or $gmaFiles.Count -eq 0) {
            $legacyBins = Get-ChildItem -Path $addonFolder -Filter '*_legacy.bin' -File -Recurse
            if ($legacyBins -and $legacyBins.Count -gt 0) {
                Write-Host "No .gma files found, handling legacy .bin archive..." -ForegroundColor DarkYellow
                $legacyResult = Handle-LegacyBins -BinFiles $legacyBins -TargetFolder $targetFolder
                if ($legacyResult.ConvertedGmas -and $legacyResult.ConvertedGmas.Count -gt 0) {
                    $gmaFiles = $legacyResult.ConvertedGmas
                }
                elseif ($legacyResult.ZipExtracted) {
                    Write-Host "[OK] $id completed → $targetFolder (legacy .bin extracted)" -ForegroundColor Green
                    continue
                }
            }
        }

        if (-not $gmaFiles -or $gmaFiles.Count -eq 0) {
            throw "No .gma archive found for ID $id."
        }

        Expand-GmaFiles -Gmad $GmadPath -WorkshopId $id -GmaFiles $gmaFiles -ExtractFolder $targetFolder
        Write-Host "[OK] $id completed → $targetFolder" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] $id failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "All tasks finished." -ForegroundColor Green
