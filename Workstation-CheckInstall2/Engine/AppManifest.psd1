@{
    Apps = @(
        @{
            Id              = '1.1'
            Name            = 'APCPrereq'
            RequiredVersion = '1.0.1'
            Patterns        = @('APCPrereq', 'APC Prereq')
            Installer       = 'Installers\MSI_PLT_SITA_XX_APCPREREQ_1_0_1.msi'
            Type            = 'MSI'
            SilentArgs      = '/qn /norestart'
            InstallAfter    = @()
            PresenceOnly    = $false
        },
        @{
            Id              = '2.1'
            Name            = 'APC CUTE'
            RequiredVersion = '5.3.1.26'
            Patterns        = @('APC CUTE', 'CUTE')
            Installer       = 'Installers\APC_CUTE_5_3_1_26.msi'
            Type            = 'MSI'
            SilentArgs      = '/qn /norestart'
            InstallAfter    = @('1.1')
            PresenceOnly    = $false
        },
        @{
            Id              = '3.1'
            Name            = 'PaxLocate'
            RequiredVersion = '5.9.1'
            Patterns        = @('PaxLocate')
            Installer       = 'Installers\PaxLocate_5.9.1.x.msi'
            Type            = 'MSI'
            SilentArgs      = '/qn /norestart SERVERIP=57.47.221.215 SECURITYMODE=Transport MSMQIP=57.47.221.217'
            InstallAfter    = @('1.1')
            PresenceOnly    = $false
        },
        @{
            Id              = '4.1'
            Name            = 'PFM Data Agent'
            RequiredVersion = '7.3.5.0'
            Patterns        = @('PFM Data Agent')
            Installer       = 'Installers\PfmDataAgent 7.3.5.0.msi'
            Type            = 'MSI'
            SilentArgs      = '/qn /norestart'
            InstallAfter    = @('4.2')
            PresenceOnly    = $false
        },
        @{
            Id              = '4.2'
            Name            = 'PFM Data Bridge'
            RequiredVersion = '7.3.5.0'
            Patterns        = @('PFM Data Bridge')
            Installer       = 'Installers\PfmDataBridge 7.3.5.0.msi'
            Type            = 'MSI'
            SilentArgs      = '/qn /norestart'
            InstallAfter    = @('1.1')
            PresenceOnly    = $false
        },
        @{
            Id              = '5.1'
            Name            = 'Cortex XDR Agent'
            RequiredVersion = '9.1.0.20483'
            Patterns        = @('Cortex XDR', 'Cortex XDR Agent', 'Palo Alto Networks Traps', 'Traps', 'Cyvera')
            Installer       = ''
            Type            = 'EXE'
            SilentArgs      = ''
            InstallAfter    = @()
            PresenceOnly    = $false
        },
        @{
            Id              = '6.1'
            Name            = 'TeamViewer'
            RequiredVersion = ''
            Patterns        = @('1E')
            Installer       = ''
            Type            = 'EXE'
            SilentArgs      = ''
            InstallAfter    = @()
            PresenceOnly    = $true
        },
        @{
            Id              = '7.1'
            Name            = 'ManageEngine'
            RequiredVersion = ''
            Patterns        = @('ManageEngine')
            Installer       = ''
            Type            = 'EXE'
            SilentArgs      = ''
            InstallAfter    = @()
            PresenceOnly    = $true
        }
    )
}