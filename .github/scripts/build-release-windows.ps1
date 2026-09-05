param(
    [Parameter(Mandatory = $true)] [string] $Target,
    [Parameter(Mandatory = $true)] [string] $ZigUrl,
    [Parameter(Mandatory = $true)] [string] $ZigSha256,
    [Parameter(Mandatory = $true)] [string] $ZigDirectory
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

function Get-PeMachine([string] $Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -lt 64 -or $bytes[0] -ne 0x4d -or $bytes[1] -ne 0x5a) {
        throw "not a PE executable: $Path"
    }
    $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
    if ($peOffset -lt 0 -or $peOffset + 6 -gt $bytes.Length -or
        $bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45) {
        throw "invalid PE header: $Path"
    }
    return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
}

$osArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$zigTarget = switch ($Target) {
    "windows-arm64" {
        if ($osArchitecture -ne "Arm64") {
            throw "expected a native Windows ARM64 runner, got $osArchitecture"
        }
        "aarch64-windows"
    }
    "windows-x64" {
        if ($osArchitecture -ne "X64") {
            throw "expected a native Windows X64 runner, got $osArchitecture"
        }
        "x86_64-windows"
    }
    default { throw "unsupported Windows release target: $Target" }
}
$expectedMachine = if ($Target -eq "windows-arm64") { 0xaa64 } else { 0x8664 }

$zigArchive = Join-Path $env:RUNNER_TEMP "zig.zip"
Invoke-WebRequest $ZigUrl -OutFile $zigArchive
$actualZigHash = (Get-FileHash $zigArchive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualZigHash -ne $ZigSha256) {
    throw "Zig archive checksum mismatch"
}
Expand-Archive $zigArchive -DestinationPath $env:RUNNER_TEMP
$env:PATH = "$(Join-Path $env:RUNNER_TEMP $ZigDirectory);$env:PATH"

$buildPrefix = Join-Path $env:RUNNER_TEMP "silex-prefix"
zig build "-Dtarget=$zigTarget" -Doptimize=ReleaseFast -Dcpu=baseline `
    --prefix $buildPrefix `
    --build-file Toolchain/build.zig

$root = Join-Path $env:RUNNER_TEMP "silex-$Target"
$bin = Join-Path $root "bin"
New-Item -ItemType Directory -Force $bin | Out-Null
Copy-Item (Join-Path $buildPrefix "bin/silex.exe") $bin
Copy-Item LICENSE, NOTICE, README.md $root

$builtSilex = Join-Path $bin "silex.exe"
$builtMachine = Get-PeMachine $builtSilex
if ($builtMachine -ne $expectedMachine) {
    throw "expected PE machine 0x$($expectedMachine.ToString('x4')), got 0x$($builtMachine.ToString('x4'))"
}

$releaseFile = "silex-$Target.zip"
Compress-Archive -Path $root -DestinationPath $releaseFile
$releaseHash = (Get-FileHash $releaseFile -Algorithm SHA256).Hash.ToLowerInvariant()
"$releaseHash  $releaseFile" | Set-Content -NoNewline "$releaseFile.sha256"

& (Join-Path $PSScriptRoot "smoke-release-windows.ps1") -Target $Target
