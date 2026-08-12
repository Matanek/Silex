$ErrorActionPreference = "Stop"

if ($env:SILEX_UPDATE_PID) {
    $updateProcessId = 0
    if (-not [int]::TryParse($env:SILEX_UPDATE_PID, [ref]$updateProcessId)) {
        throw "silex: invalid updater process id"
    }
    Wait-Process -Id $updateProcessId -ErrorAction SilentlyContinue
}

$silexRepository = "Matanek/Silex"
$architecture = $env:PROCESSOR_ARCHITECTURE
if ($architecture -ne "AMD64" -and $env:PROCESSOR_ARCHITEW6432 -ne "AMD64") {
    throw "silex: the published Windows installer currently supports x64"
}

if ($env:SILEX_INSTALL_DIR) {
    $installDirectory = $env:SILEX_INSTALL_DIR
} elseif ($env:LOCALAPPDATA) {
    $installDirectory = Join-Path $env:LOCALAPPDATA "Silex\bin"
} elseif ($env:USERPROFILE) {
    $installDirectory = Join-Path $env:USERPROFILE ".local\bin"
} else {
    throw "silex: no user directory is available; set SILEX_INSTALL_DIR explicitly"
}

$release = if ($env:SILEX_VERSION) { $env:SILEX_VERSION } else { "latest" }
$asset = "silex-windows-x64.zip"
$checksum = "$asset.sha256"
if ($release -eq "latest") {
    $releaseUrl = "https://github.com/$silexRepository/releases/latest/download"
} else {
    $tag = if ($release.StartsWith("v")) { $release } else { "v$release" }
    $releaseUrl = "https://github.com/$silexRepository/releases/download/$tag"
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("silex-install-" + [guid]::NewGuid())
$staged = Join-Path $installDirectory ".silex-install-$PID.exe"
New-Item -ItemType Directory -Force $temporary | Out-Null

try {
    $archivePath = Join-Path $temporary $asset
    $checksumPath = Join-Path $temporary $checksum
    Invoke-WebRequest "$releaseUrl/$asset" -OutFile $archivePath
    Invoke-WebRequest "$releaseUrl/$checksum" -OutFile $checksumPath

    $expected = ((Get-Content $checksumPath -Raw).Trim() -split '\s+')[0].ToLowerInvariant()
    $actual = (Get-FileHash $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "silex: archive checksum mismatch"
    }

    Expand-Archive -LiteralPath $archivePath -DestinationPath $temporary
    $source = Join-Path $temporary "silex-windows-x64\bin\silex.exe"
    New-Item -ItemType Directory -Force $installDirectory | Out-Null
    Copy-Item -LiteralPath $source -Destination $staged
    Move-Item -LiteralPath $staged -Destination (Join-Path $installDirectory "silex.exe") -Force
} finally {
    if (Test-Path -LiteralPath $staged) {
        Remove-Item -LiteralPath $staged -Force
    }
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}

Write-Host "silex: installed $(Join-Path $installDirectory 'silex.exe')"
$pathEntries = $env:PATH -split ';'
if ($pathEntries -notcontains $installDirectory) {
    Write-Host "silex: add $installDirectory to PATH before invoking silex"
}
Write-Host "silex: run 'silex setup' before compiling HLSL shaders"
if ($env:SILEX_UPDATE_SCRIPT -and $PSCommandPath) {
    $updateScript = [System.IO.Path]::GetFullPath($env:SILEX_UPDATE_SCRIPT)
    if ($updateScript -eq [System.IO.Path]::GetFullPath($PSCommandPath)) {
        Remove-Item -LiteralPath $updateScript -Force -ErrorAction SilentlyContinue
    }
}
