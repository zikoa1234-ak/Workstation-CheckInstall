# Native dashboard rebuild

Launcher.cmd now starts Workstation-Validator.ps1 (Windows PowerShell 5.1, STA, Windows Forms), not mshta.exe. The legacy HTA is retained as a rollback file but is not required or launched. Do not run the legacy HTA to use the rebuilt UI.

Select a template, then Edit template. Use the separate Applications and Scripts checklists, then Save. The editor preserves other template data keys, makes a .bak backup and validates application dependencies. Saving rewrites formatting/comments. Scripts must first be defined in Engine/ScriptManifest.psd1 using Edit script definitions; save and Rescan. Existing templates without a Scripts key initially select all defined scripts; saving writes an explicit list (including an empty list for none).

Applications and scripts have separate tabs. Select an application row and Install / Upgrade selected, or select a script and Execute selected script. View selected log uses the active tab. Task-Center.ps1 remains the shared executor; installations and scripts cannot overlap through managed dashboard actions. Log viewing stays enabled. Closing during execution is blocked to avoid losing track of the operation.

The existing scan and installer engines are unchanged. No actual business scripts are supplied, and no antivirus policy or exclusion is changed. Removing HTA dependence does not guarantee Kaspersky acceptance. Obtain the exact detection report and use your organization's approved review/signing process if the rebuilt scripts are blocked.

Launcher uses RemoteSigned instead of a process-wide execution-policy bypass. Internet-marked unsigned files may be blocked. Follow approved signing/deployment procedures; do not disable antivirus. Existing backend policy behavior is unchanged. This rebuild has not been tested in a Windows runtime; validate on a test workstation before deployment.
