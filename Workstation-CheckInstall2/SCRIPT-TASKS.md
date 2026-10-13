# Script tasks and execution lock

The dashboard runs one operation at a time. Install, Upgrade, Execute, Rescan and template changes are disabled while it runs; View Log remains available. Task-Center.ps1 also uses a machine-wide mutex for dashboard operations. Existing Install-App.ps1 and Scan-All.ps1 remain unchanged. Directly launching those original files bypasses this wrapper.

Edit Engine/ScriptManifest.psd1 to add real scripts (none supplied by default):

```powershell
@{
 Scripts = @(
  @{
   Id = 'PFMConfig'
   Name = 'Apply PFM configuration'
   Path = 'Scripts\YourActualConfig.ps1'
   Arguments = ''
   SuccessExitCodes = @(0)
   Check = @{ Type = 'Folder'; Path = 'C:\YourActualConfigFolder' }
  }
 )
}
```

Paths are examples: replace them with your actual script and output. Relative paths start at the package folder; environment variables are expanded. Supported task files: PS1, BAT, CMD, EXE and MSI. Set appropriate arguments; MSI silent arguments typically /qn /norestart. Use SuccessExitCodes = @(0,3010,1641) only where applicable. Interactive tasks may need user input; do not use launch-and-exit scripts that leave work detached.

Checks: Folder checks a directory, File checks a file, Log checks a file and optionally literal Contains text. Without Check, completion uses the saved successful exit result. An existing path alone indicates the condition is satisfied, not proof of a new execution. After Execute, both exit code and configured condition must succeed. Logs live in Logs/script-<ID>.log with stdout/stderr captures and MSI logs where applicable.

Templates may add Scripts = @('PFMConfig'). Scripts = @() selects none. Without Scripts, all manifest scripts are shown for backward compatibility. Edit Scripts opens the manifest in Notepad; save then Rescan.

Windows runtime testing is required before production use. Mutex covers managed dashboard operations only. Original application readiness banner remains application-only; script statuses are shown separately.
