#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AppId,

    [string]$PackageRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

Import-Module -Force -DisableNameChecking (Join-Path $PSScriptRoot 'Common.psm1')

$manifest    = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'AppManifest.psd1')
$logDir      = Join-Path $PackageRoot 'Logs'
$statusPath  = Join-Path $PackageRoot 'Output\status.json'
$logPath     = Join-Path $logDir "$AppId.log"
$donePath    = Join-Path $logDir "$AppId.done"

New-Item -ItemType Directory -Path $logDir -Force | Out-Null

$appDef = @($manifest.Apps | Where-Object { $_.Id -eq $AppId })
if ($appDef.Count -eq 0) {
    Write-Error "Unknown application ID: $AppId"
    exit 1
}
$appDef = $appDef[0]

Write-LogLine -Path $logPath -Message "=== Installation started for $($appDef.Name) (ID: $AppId) ==="

# --- Check installer file ---
if ([string]::IsNullOrWhiteSpace([string]$appDef.Installer)) {
    Write-LogLine -Path $logPath -Message "ERROR: No installer defined for $($appDef.Name). Manual installation is required."
    Write-Error "No installer is defined for $($appDef.Name). Manual installation is required."
    exit 1
}

$installerPath = Join-Path $PackageRoot ([string]$appDef.Installer)
if (-not (Test-Path -LiteralPath $installerPath)) {
    Write-LogLine -Path $logPath -Message "ERROR: Installer file not found: $installerPath"
    Write-Error "Installer file not found: $installerPath"
    exit 1
}

Write-LogLine -Path $logPath -Message "Installer path: $installerPath"

# --- Set status to INSTALLING so the UI shows it ---
try {
    if (Test-Path -LiteralPath $statusPath) {
        $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        $row = @($status.results | Where-Object { $_.id -eq $AppId })
        if ($row.Count -gt 0) {
            $row[0].status  = 'INSTALLING'
            $row[0].comment = 'Installation in progress'
            Write-JsonAtomic -Data $status -Path $statusPath
        }
    }
}
catch {
    # A display refresh must never prevent the actual installer from starting.
    Write-LogLine -Path $logPath -Message "WARNING: Could not set INSTALLING status: $_"
}

# --- Run installer ---
$installType = [string]$appDef.Type
$silentArgs  = [string]$appDef.SilentArgs

Write-LogLine -Path $logPath -Message "Type: $installType"
Write-LogLine -Path $logPath -Message "SilentArgs: $($silentArgs -replace '"','""')"
Write-LogLine -Path $logPath -Message "Starting installer..."

if ($installType -eq 'MSI') {
    $exePath    = 'msiexec.exe'
    $exeArgs    = "/i `"$installerPath`" $silentArgs"
} else {
    $exePath    = $installerPath
    $exeArgs    = $silentArgs
}

Write-LogLine -Path $logPath -Message "Command: $exePath $exeArgs"

$proc = Start-Process -FilePath $exePath -ArgumentList $exeArgs -Wait -PassThru -WindowStyle Hidden
$exitCode = $proc.ExitCode

Write-LogLine -Path $logPath -Message "Installer exit code: $exitCode"

# --- Determine result ---
$rebootRequired = $exitCode -in @(3010, 1641)
$ok             = $exitCode -in @(0, 3010, 1641)

# --- Re-scan the registry (fresh read) ---
Write-LogLine -Path $logPath -Message "Re-scanning registry..."

$scanScript = Join-Path $PSScriptRoot 'Scan-All.ps1'
$scanArgs   = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $scanScript,
    '-PackageRoot', $PackageRoot
)

try {
    & powershell.exe @scanArgs | Out-Null
    Write-LogLine -Path $logPath -Message "Re-scan completed."
} catch {
    Write-LogLine -Path $logPath -Message "WARNING: Re-scan failed: $_"
}

# --- Read fresh status for this app ---
$freshStatus = 'UNKNOWN'
if (Test-Path -LiteralPath $statusPath) {
    $fresh = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    $freshRow = @($fresh.results | Where-Object { $_.id -eq $AppId })
    if ($freshRow.Count -gt 0) {
        $freshStatus = if ($freshRow[0].status -eq 'PASS') {
            'PASS'
        } else {
            [string]$freshRow[0].status
        }
    }
}

if (-not $ok) {
    $finalStatus = 'FAILED'
} elseif ($freshStatus -eq 'PASS') {
    $finalStatus = 'PASS'
} else {
    $finalStatus = $freshStatus
}

# --- Write .done file ---
$doneData = [PSCustomObject]@{
    appId          = $AppId
    exitcode       = $exitCode
    status         = $finalStatus
    rebootRequired = $rebootRequired
}

$doneData | ConvertTo-Json -Compress | Set-Content -LiteralPath $donePath -Encoding UTF8
Write-LogLine -Path $logPath -Message "Result: $finalStatus | RebootRequired: $rebootRequired"
Write-LogLine -Path $logPath -Message "=== Installation finished ==="

if (-not $ok) {
    exit $exitCode
}
exit 0
