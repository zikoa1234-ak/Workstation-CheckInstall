# Workstation Check & Install Center

Windows 10/11 technician tool for post-reimage workstation validation
and application installation.

## Quick start

1. Extract the package to a local folder, for example:
   `C:\Tools\Workstation-CheckInstall`
2. Right-click `Launcher.cmd` and select **Run as administrator**,
   or double-click it and approve the UAC prompt.
3. The launcher completes an initial scan and then opens the HTA dashboard.
   Use **RESCAN ALL** whenever you need to refresh the results.
4. For each red (MISSING) or amber (WRONG_VERSION) row, click
   **INSTALL** or **UPGRADE**.
5. Wait for the row to turn green. If a **REBOOT REQUIRED** badge
   appears, reboot the workstation.
6. When every row is green and the banner says
   **PASS - WORKSTATION READY**, the workstation may be delivered.

## How it works

| Layer  | What it does |
|--------|-------------|
| `Workstation-Validator.hta` | Dashboard: reads `Output\status.json`, shows results, launches PowerShell scripts when buttons are clicked, polls every 2 seconds. No business logic. |
| `Engine\Scan-All.ps1`       | Scans the Windows registry (HKLM, WOW6432Node, HKCU Uninstall) for every application in the manifest and writes `Output\status.json`. |
| `Engine\Install-App.ps1`    | Installs one application by manifest ID. Runs the MSI or EXE silently, rescans the registry, and writes `Logs\<ID>.done`. |
| `Engine\AppManifest.psd1`   | Single source of truth: every application, its required version, registry detection patterns, installer path, and silent arguments. |
| `Engine\Common.psm1`        | Reusable functions: registry scan, pattern matching, version comparison, atomic file writes, logging. |

## Included applications

| ID  | Name             | Required version | Type          |
|-----|------------------|------------------|---------------|
| 1.1 | APCPrereq        | 1.0.1            | MSI           |
| 2.1 | APC CUTE         | 5.3.1.26         | MSI           |
| 3.1 | PaxLocate        | 5.9.1            | MSI           |
| 4.1 | PFM Data Agent   | 7.3.5.0          | MSI           |
| 4.2 | PFM Data Bridge  | 7.3.5.0          | MSI           |
| 7.1 | Cortex XDR Agent | 9.1.0.20483      | Manual        |
| 8.1 | TeamViewer       | Presence only    | Manual        |
| 9.1 | ManageEngine     | Presence only    | Manual        |

Nexthink is intentionally excluded from the checklist.

## Installer files

Copy the required MSI files into the `Installers\` folder:

- `MSI_PLT_SITA_XX_APCPREREQ_1_0_1.msi`
- `APC_CUTE_5_3_1_26.msi`
- `PaxLocate_5.9.1.x.msi`
- `PfmDataBridge 7.3.5.0.msi`
- `PfmDataAgent 7.3.5.0.msi`

Applications without an installer defined (Cortex XDR, TeamViewer,
ManageEngine) must be installed manually and will still be detected
by the registry scan.

## Install order

The manifest enforces these dependencies:

1. APCPrereq (1.1) — no dependencies
2. APC CUTE (2.1) — requires APCPrereq
3. PaxLocate (3.1) — requires APCPrereq
4. PFM Data Bridge (4.2) — requires APCPrereq
5. PFM Data Agent (4.1) — requires PFM Data Bridge

## Manual steps remaining (from cmn-script)

The following steps from the original manual installation kit
(`cmn-script`) are NOT automated by this package and remain
manual technician responsibilities:

- **MSMQ Windows features** — `Enable-WindowsOptionalFeature` commands
  in `1.Preq_1.bat` for MSMQ-ADIntegration, MSMQ-Triggers,
  MSMQ-Container, MSMQ-Server, MSMQ-HTTP must be enabled before
  APCPrereq installation.
- **Network share copies** — files from `\\57.236.113.39\cmn-t\hicham`
  and `\\57.236.113.44` must be copied locally before installation.
  These include `deskomsi\VCOM_Setup.exe`, `desko\*`, `hosts`,
  `5.av_5.exe`, `S_CeCdcVUC_118_6.exe`.
- **VCOM installation** — `VCOM_Setup.exe /passive /silence`
  (from `2.PC-Enregistrement.bat`).
- **File copies to C:\Windows** — `XCOPY c:\hicham\desko C:\windows`
  and `hosts` file replacement (from `2.All.bat`).
- **Antivirus** — `5.av_5.exe /q` (from `2.All.bat`).
- **S_CeCdcVUC** — `start S_CeCdcVUC_118_6.exe` is interactive;
  cannot be silently automated.
- **PFM configuration scripts** — `CMN_Add_PfmDataBridge_7.3.5.0_Config_Files.ps1`
  and `CMN_Add_PfmDataAgent_7.3.5.0_Config_File.ps1` (from
  `3.Paxlocate7.3.5.0.cmd`) must be run manually after MSI installation.
- **Group Policy update** — `gpupdate /force /sync` (from
  `5.GP-Update.bat`) must be run manually after all installations.

## Logs

Installation logs are written to `Logs\<ID>.log`.
Result files are written to `Logs\<ID>.done`.

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (built-in; no extra install required)
- Administrator rights (Launcher.cmd requests elevation)
- MSI installer files placed in `Installers\`
- No network, web server, or internet connection required
