Set-StrictMode -Version 2.0

function Get-InstalledApplications {
    [CmdletBinding()]
    param(
        [object[]]$MockInstalledApps
    )

    if ($null -ne $MockInstalledApps) {
        return @($MockInstalledApps)
    }

    $RegistryPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $results = foreach ($regPath in $RegistryPaths) {
        # Some uninstall registry keys are incomplete and have no DisplayName.
        # With strict mode enabled, direct property access would make one such
        # key abort the entire scan. Inspect the property collection instead.
        foreach ($entry in @(Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue)) {
            $displayNameProperty = $entry.PSObject.Properties['DisplayName']
            if ($null -eq $displayNameProperty) { continue }

            $displayName = [string]$displayNameProperty.Value
            if ([string]::IsNullOrWhiteSpace($displayName)) { continue }

            $displayVersionProperty = $entry.PSObject.Properties['DisplayVersion']
            $publisherProperty = $entry.PSObject.Properties['Publisher']

            [PSCustomObject]@{
                DisplayName    = $displayName
                DisplayVersion = if ($null -ne $displayVersionProperty) { [string]$displayVersionProperty.Value } else { '' }
                Publisher      = if ($null -ne $publisherProperty) { [string]$publisherProperty.Value } else { '' }
            }
        }
    }

    return @($results)
}

function Find-InstalledApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$InstalledApps,

        [Parameter(Mandatory = $true)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        $match = @($InstalledApps |
            Where-Object { [string]$_.DisplayName -match $pattern } |
            Sort-Object @{Expression = {
                try { return [version]$_.DisplayVersion }
                catch { return [version]'0.0' }
            }; Descending = $true} |
            Select-Object -First 1)

        if ($match.Count -gt 0) {
            return $match[0]
        }
    }

    return $null
}

function Test-Version {
    [CmdletBinding()]
    param(
        [string]$InstalledVersion,
        [string]$RequiredVersion
    )

    if ([string]::IsNullOrWhiteSpace($RequiredVersion)) { return $true }
    if ([string]::IsNullOrWhiteSpace($InstalledVersion))  { return $false }

    try {
        return ([version]$InstalledVersion -ge [version]$RequiredVersion)
    }
    catch {
        return ($InstalledVersion -like "*$RequiredVersion*")
    }
}

function Get-AppScanRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$App,

        [Parameter(Mandatory = $true)]
        [object[]]$InstalledApps
    )

    $found = Find-InstalledApplication -InstalledApps $InstalledApps -Patterns ([string[]]$App.Patterns)

    if ($null -eq $found) {
        return [PSCustomObject]@{
            id               = [string]$App.Id
            name             = [string]$App.Name
            requiredVersion  = [string]$App.RequiredVersion
            installedVersion = ''
            detectedName     = ''
            status           = 'MISSING'
            comment          = 'Not installed or not detected'
        }
    }

    $installedVersion = [string]$found.DisplayVersion

    if (Test-Version -InstalledVersion $installedVersion -RequiredVersion ([string]$App.RequiredVersion)) {
        $comment = if ([string]::IsNullOrWhiteSpace([string]$App.RequiredVersion)) {
            'Installed'
        } else {
            'Correct version installed'
        }
        return [PSCustomObject]@{
            id               = [string]$App.Id
            name             = [string]$App.Name
            requiredVersion  = [string]$App.RequiredVersion
            installedVersion = $installedVersion
            detectedName     = [string]$found.DisplayName
            status           = 'PASS'
            comment          = $comment
        }
    }

    return [PSCustomObject]@{
        id               = [string]$App.Id
        name             = [string]$App.Name
        requiredVersion  = [string]$App.RequiredVersion
        installedVersion = $installedVersion
        detectedName     = [string]$found.DisplayName
        status           = 'WRONG_VERSION'
        comment          = 'Wrong or older version installed'
    }
}

function Write-JsonAtomic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Data,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $tmp = "$Path.tmp"
    # The HTA reads status files with FileSystemObject's Unicode mode, which
    # expects UTF-16. Keep the producer and reader on the same encoding.
    $Data | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tmp -Encoding Unicode
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Write-LogLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Add-Content -LiteralPath $Path -Value "$timestamp $Message"
}

Export-ModuleMember -Function @(
    'Get-InstalledApplications',
    'Find-InstalledApplication',
    'Test-Version',
    'Get-AppScanRecord',
    'Write-JsonAtomic',
    'Write-LogLine'
)
