#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot),
    [object[]]$MockInstalledApps
)

$ErrorActionPreference = 'Stop'

Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot 'Common.psm1')

$manifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'AppManifest.psd1')
$apps = Get-InstalledApplications -MockInstalledApps $MockInstalledApps

$records = foreach ($appDef in $manifest.Apps) {
    Get-AppScanRecord -App $appDef -InstalledApps $apps
}

$failCount = @($records | Where-Object { $_.status -ne 'PASS' }).Count

$payload = [PSCustomObject]@{
    computerName  = $env:COMPUTERNAME
    scannedAt     = (Get-Date).ToString('s')
    overallStatus = if ($failCount -eq 0) { 'PASS - WORKSTATION READY' } else { 'FAIL - WORKSTATION NOT READY' }
    results       = @($records)
}

$outputPath = Join-Path $PackageRoot 'Output\status.json'
Write-JsonAtomic -Data $payload -Path $outputPath

$payload | ConvertTo-Json -Depth 8