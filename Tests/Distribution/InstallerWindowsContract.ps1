$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$installer = Join-Path $repositoryRoot "install.ps1"
$temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("silex-installer-contract-" + [guid]::NewGuid())
$originalProcessArchitecture = $env:PROCESSOR_ARCHITECTURE
$originalNativeArchitecture = $env:PROCESSOR_ARCHITEW6432
New-Item -ItemType Directory -Force $temporary | Out-Null

function Test-HostTarget(
    [string] $ProcessArchitecture,
    [string] $NativeArchitecture,
    [string] $ExpectedTarget
) {
    $capture = Join-Path $temporary "capture.txt"
    $env:PROCESSOR_ARCHITECTURE = $ProcessArchitecture
    $env:PROCESSOR_ARCHITEW6432 = $NativeArchitecture
    $env:SILEX_INSTALL_DIR = Join-Path $temporary "bin"
    $env:SILEX_INSTALLER_CAPTURE = $capture

    try {
        & {
            function Invoke-WebRequest {
                param([string] $Uri, [string] $OutFile)
                Set-Content -LiteralPath $env:SILEX_INSTALLER_CAPTURE -Value $Uri
                throw "installer target captured"
            }
            . $installer
        }
        throw "installer did not attempt a download"
    } catch {
        if ($_.Exception.Message -ne "installer target captured") {
            throw
        }
    }

    $uri = (Get-Content -LiteralPath $capture -Raw).Trim()
    if (-not $uri.EndsWith("/silex-$ExpectedTarget.zip")) {
        throw "expected $ExpectedTarget, installer requested $uri"
    }
}

try {
    Test-HostTarget "AMD64" "" "windows-x64"
    Test-HostTarget "ARM64" "" "windows-arm64"
    Test-HostTarget "AMD64" "ARM64" "windows-arm64"
    Write-Output "Windows installer target contract passed"
} finally {
    $env:PROCESSOR_ARCHITECTURE = $originalProcessArchitecture
    $env:PROCESSOR_ARCHITEW6432 = $originalNativeArchitecture
    Remove-Item Env:SILEX_INSTALLER_CAPTURE -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temporary -Recurse -Force -ErrorAction SilentlyContinue
}
