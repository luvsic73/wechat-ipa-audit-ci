param(
    [Parameter(Mandatory = $true)]
    [string]$BaseIpa,
    [Parameter(Mandatory = $true)]
    [string]$OutputIpa,
    [string]$Loader,
    [string]$BundleId = "com.luvsic73.wechatmods",
    [string]$DisplayName,
    [string]$SchemePrefix = "wechatmods",
    [string]$Report
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$env:PYTHONPATH = Join-Path $projectRoot "src"
if (-not $DisplayName) {
    $DisplayName = ([char]0x5FAE).ToString() +
        ([char]0x4FE1).ToString() + " Glass"
}
if (-not $Loader) {
    $Loader = Join-Path $projectRoot "dist\WeChatMods.dylib"
}
$outputPath = [IO.Path]::GetFullPath($OutputIpa)
$temporaryIpa = Join-Path ([IO.Path]::GetDirectoryName($outputPath)) (
    ".wechatmods.{0}.replacement.ipa" -f [guid]::NewGuid().ToString("N")
)

try {
    & (Join-Path $PSScriptRoot "build-iloader.ps1") `
        -BaseIpa $BaseIpa `
        -OutputIpa $temporaryIpa `
        -Loader $Loader
    if ($LASTEXITCODE -ne 0) {
        throw "Base package build failed"
    }
    $arguments = @(
        "-3", "-m", "wechat_ipa_audit.cli", "coexist",
        $temporaryIpa, $outputPath,
        "--bundle-id", $BundleId,
        "--display-name", $DisplayName,
        "--scheme-prefix", $SchemePrefix
    )
    if ($Report) {
        $arguments += @("--report", [IO.Path]::GetFullPath($Report))
    }
    & py @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Coexist rewrite failed"
    }
    py -3 -m wechat_ipa_audit.cli verify $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Coexist package verification failed"
    }
}
finally {
    Remove-Item -LiteralPath $temporaryIpa -Force -ErrorAction SilentlyContinue
}
