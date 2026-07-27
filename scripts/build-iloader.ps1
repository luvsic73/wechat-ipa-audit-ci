param(
    [Parameter(Mandatory = $true)]
    [string]$BaseIpa,
    [Parameter(Mandatory = $true)]
    [string]$OutputIpa,
    [string]$Loader
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$env:PYTHONPATH = Join-Path $projectRoot "src"
$modules = Join-Path $projectRoot "data\modules.json"
if (-not $Loader) {
    $Loader = Join-Path $projectRoot "dist\WeChatMods.dylib"
}
$outputPath = [IO.Path]::GetFullPath($OutputIpa)
$stagedIpa = Join-Path ([IO.Path]::GetDirectoryName($outputPath)) (
    ".wechatmods.{0}.staged.ipa" -f [guid]::NewGuid().ToString("N")
)

try {
    py -3 -m wechat_ipa_audit.cli package $BaseIpa $stagedIpa --modules $modules
    if ($LASTEXITCODE -ne 0) {
        throw "Packaging failed"
    }
    py -3 -m wechat_ipa_audit.cli inject $stagedIpa $Loader $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Loader injection failed"
    }
    py -3 -m wechat_ipa_audit.cli verify $outputPath
    if ($LASTEXITCODE -ne 0) {
        throw "Verification failed"
    }
}
finally {
    Remove-Item -LiteralPath $stagedIpa -Force -ErrorAction SilentlyContinue
}
