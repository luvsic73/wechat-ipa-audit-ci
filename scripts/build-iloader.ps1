param(
    [Parameter(Mandatory = $true)]
    [string]$BaseIpa,
    [Parameter(Mandatory = $true)]
    [string]$OutputIpa
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$env:PYTHONPATH = Join-Path $projectRoot "src"
$modules = Join-Path $projectRoot "data\modules.json"

py -3 -m wechat_ipa_audit.cli package $BaseIpa $OutputIpa --modules $modules
if ($LASTEXITCODE -ne 0) {
    throw "Packaging failed"
}
py -3 -m wechat_ipa_audit.cli verify $OutputIpa
if ($LASTEXITCODE -ne 0) {
    throw "Verification failed"
}
