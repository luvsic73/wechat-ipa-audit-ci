param(
    [Parameter(Mandatory = $true)]
    [string]$BaseIpa,
    [Parameter(Mandatory = $true)]
    [string]$OutputIpa,
    [string]$ReportDirectory,
    [string]$DisplayName
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$env:PYTHONPATH = Join-Path $projectRoot "src"
$basePath = [IO.Path]::GetFullPath($BaseIpa)
$outputPath = [IO.Path]::GetFullPath($OutputIpa)
if (-not $ReportDirectory) {
    $ReportDirectory = Join-Path (
        [IO.Path]::GetDirectoryName($outputPath)
    ) "reports"
}
$reportPath = [IO.Path]::GetFullPath($ReportDirectory)
if (-not $DisplayName) {
    $DisplayName = ([char]0x5FAE).ToString() +
        ([char]0x4FE1).ToString() + " Glass"
}

$staging = Join-Path ([IO.Path]::GetTempPath()) (
    "wechat-reference-{0}" -f [guid]::NewGuid().ToString("N")
)
New-Item -ItemType Directory -Path $staging | Out-Null
New-Item -ItemType Directory -Force -Path $reportPath | Out-Null

try {
    $modules = Join-Path $staging "modules.json"
    [IO.File]::WriteAllText(
        $modules,
        '{"modules":[]}',
        [Text.UTF8Encoding]::new($false)
    )
    $manifestIpa = Join-Path $staging "01-manifest.ipa"
    $patchedLoader = Join-Path $staging "WeChatMods.dylib"
    $injectedIpa = Join-Path $staging "02-injected.ipa"
    $iconIpa = Join-Path $staging "03-icon.ipa"

    py -3 -m wechat_ipa_audit.cli package `
        $basePath $manifestIpa --modules $modules
    if ($LASTEXITCODE -ne 0) {
        throw "Reference manifest packaging failed"
    }

    py -3 -m wechat_ipa_audit.cli prepare-glass-loader `
        (Join-Path $projectRoot "dist\WeChatMods.dylib") `
        $patchedLoader `
        --report (Join-Path $reportPath "glass-loader-patch.json")
    if ($LASTEXITCODE -ne 0) {
        throw "Glass loader preparation failed"
    }

    py -3 -m wechat_ipa_audit.cli inject `
        $manifestIpa $patchedLoader $injectedIpa
    if ($LASTEXITCODE -ne 0) {
        throw "Reference loader injection failed"
    }

    py -3 -m wechat_ipa_audit.cli icon `
        $injectedIpa `
        (Join-Path $projectRoot "assets\app-icon-liquid-glass-1024.png") `
        (Join-Path $projectRoot "assets\AppIcon.icon") `
        $iconIpa `
        --report (Join-Path $reportPath "app-icon.json")
    if ($LASTEXITCODE -ne 0) {
        throw "Reference app icon replacement failed"
    }

    py -3 -m wechat_ipa_audit.cli coexist `
        $iconIpa $outputPath `
        --bundle-id "com.tencent.qy.xin" `
        --display-name $DisplayName `
        --scheme-prefix "wechatglass" `
        --report (Join-Path $reportPath "coexist-readiness.json")
    if ($LASTEXITCODE -ne 0) {
        throw "Reference coexist packaging failed"
    }

    py -3 -m wechat_ipa_audit.cli account-safety `
        $basePath $outputPath `
        --output (Join-Path $reportPath "candidate-delta.json")
    if ($LASTEXITCODE -ne 0) {
        throw "Reference candidate delta gate failed"
    }

    py -3 -m wechat_ipa_audit.cli audit `
        $outputPath `
        --output (Join-Path $reportPath "candidate-audit.json")
    if ($LASTEXITCODE -ne 0) {
        throw "Reference candidate audit failed"
    }

    py -3 -m wechat_ipa_audit.cli verify `
        $outputPath `
        --output (Join-Path $reportPath "candidate-verify.json")
    if ($LASTEXITCODE -ne 0) {
        throw "Reference candidate verification failed"
    }
}
finally {
    Remove-Item -LiteralPath $staging -Recurse -Force `
        -ErrorAction SilentlyContinue
}
