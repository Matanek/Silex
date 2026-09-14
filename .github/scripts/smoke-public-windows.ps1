param(
    [Parameter(Mandatory = $true)] [string] $Target,
    [Parameter(Mandatory = $true)] [string] $Version
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$actualArchitecture = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
$expectedArchitecture = if ($Target -eq "windows-arm64") { "Arm64" } else { "X64" }
if ($actualArchitecture -ne $expectedArchitecture) {
    throw "installer smoke target $Target does not match host $actualArchitecture"
}

$env:USERPROFILE = Join-Path $env:RUNNER_TEMP "home"
$env:HOME = $env:USERPROFILE
$env:SILEX_INSTALL_DIR = Join-Path $env:RUNNER_TEMP "bin"
$env:SILEX_VERSION = $Version
New-Item -ItemType Directory -Force $env:USERPROFILE | Out-Null
Invoke-Expression (Invoke-RestMethod https://raw.githubusercontent.com/Matanek/Silex/main/install.ps1)

$silex = Join-Path $env:SILEX_INSTALL_DIR "silex.exe"
& $silex --version
$targets = @(& $silex targets)
if ($targets -notcontains "$Target (host)") {
    throw "$Target is not reported as the native host"
}
& $silex setup

$source = Join-Path $env:GITHUB_WORKSPACE "Tests/Native/DistributionSmoke.sx"
$compiled = Join-Path $env:RUNNER_TEMP "distribution-smoke.exe"
$trace = Join-Path $env:RUNNER_TEMP "distribution-default-trace.json"
$env:SILEX_COMPILATION_TRACE = $trace
& $silex compile $source --release -o $compiled
Remove-Item Env:SILEX_COMPILATION_TRACE
$tracePayload = Get-Content $trace -Raw | ConvertFrom-Json
if ($tracePayload.backend -ne "native") {
    throw "expected native as the default backend for $Target"
}
$compiledOutput = @(& $compiled)
if ($LASTEXITCODE -ne 0 -or $compiledOutput.Count -ne 1 -or
    $compiledOutput[0] -ne "silex distribution ready") {
    throw "compiled distribution smoke failed"
}
$runOutput = @(& $silex run $source --release)
if ($LASTEXITCODE -ne 0 -or $runOutput.Count -ne 1 -or
    $runOutput[0] -ne "silex distribution ready") {
    throw "run distribution smoke failed"
}
& $silex test $source

$native = Join-Path $env:RUNNER_TEMP "distribution-smoke-native.exe"
& $silex compile $source --backend native --release -o $native
$nativeOutput = @(& $native)
if ($LASTEXITCODE -ne 0 -or $nativeOutput.Count -ne 1 -or
    $nativeOutput[0] -ne "silex distribution ready") {
    throw "explicit native distribution smoke failed"
}
$nativeRunOutput = @(& $silex run $source --backend native --release)
if ($LASTEXITCODE -ne 0 -or $nativeRunOutput.Count -ne 1 -or
    $nativeRunOutput[0] -ne "silex distribution ready") {
    throw "explicit native run smoke failed"
}
& $silex test $source --backend native
