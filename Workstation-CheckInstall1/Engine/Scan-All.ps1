#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [object[]]$MockInstalledApps,
    [string]$Template
)

$ErrorActionPreference = 'Stop'

Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot 'Common.psm1')

$manifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'AppManifest.psd1')
$apps = Get-InstalledApplications -MockInstalledApps $MockInstalledApps

$selFile = Join-Path $PackageRoot 'Output\template.txt'
if (-not $Template -and (Test-Path $selFile)) {
    $Template = (Get-Content $selFile -Raw).Trim()
}

$appList      = @($manifest.Apps)
$templateName = 'All applications'
if ($Template) {
    $tPath = Join-Path $PackageRoot "Templates\$Template.psd1"
    if (-not (Test-Path $tPath)) { throw "Template not found: $tPath" }
    $tpl = Import-PowerShellDataFile $tPath
    $appList = @(foreach ($id in $tpl.Apps) {
        $found = $manifest.Apps | Where-Object { $_.Id -eq $id }
        if (-not $found) { throw "Template '$Template' references unknown app ID '$id'" }
        $found
    })
    $templateName = $tpl.Name
}

$records = foreach ($appDef in $appList) {
    Get-AppScanRecord -App $appDef -InstalledApps $apps
}

$failCount = @($records | Where-Object { $_.status -ne 'PASS' }).Count

$payload = [PSCustomObject]@{
    template      = $templateName
    computerName  = $env:COMPUTERNAME
    scannedAt     = (Get-Date).ToString('s')
    overallStatus = if ($failCount -eq 0) { 'PASS - WORKSTATION READY' } else { 'FAIL - WORKSTATION NOT READY' }
    results       = @($records)
}

$outputPath = Join-Path $PackageRoot 'Output\status.json'
Write-JsonAtomic -Data $payload -Path $outputPath

$payload | ConvertTo-Json -Depth 8