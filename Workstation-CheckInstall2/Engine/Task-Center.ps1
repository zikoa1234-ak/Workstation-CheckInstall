#Requires -RunAsAdministrator
param([ValidateSet('Scan','Install','Script')][string]$Mode='Scan',[string]$Id,[string]$PackageRoot=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$out=Join-Path $PackageRoot 'Output'
$logs=Join-Path $PackageRoot 'Logs'
New-Item -ItemType Directory -Force -Path $out,$logs | Out-Null
function Save($data,$path) { $tmp="$path.$PID.tmp"; $data | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $tmp -Encoding Unicode; Move-Item -LiteralPath $tmp -Destination $path -Force }
function Resolve($p) { $p=[Environment]::ExpandEnvironmentVariables([string]$p); if([IO.Path]::IsPathRooted($p)){return $p}; return (Join-Path $PackageRoot $p) }
function Tasks {
 $m=Import-PowerShellDataFile (Join-Path $PSScriptRoot 'ScriptManifest.psd1')
 $items=@($m.Scripts)
 $choice=Join-Path $out 'template.txt'
 if(Test-Path -LiteralPath $choice){$t=(Get-Content -LiteralPath $choice -Raw).Trim(); if($t){$tpl=Import-PowerShellDataFile (Join-Path $PackageRoot "Templates\$t.psd1"); if($tpl.ContainsKey('Scripts')){$ids=@($tpl.Scripts); $items=@($items | Where-Object {$_.Id -in $ids}); foreach($sid in $ids){if(-not @($items | Where-Object {$_.Id -eq $sid}).Count){throw "Unknown script ID in template: $sid"}}}}}
 return $items
}
function Check($task) {
 $c=$task.Check
 if(-not $c){return $false}
 $p=Resolve $c.Path
 switch($c.Type){
 'File' {return (Test-Path -LiteralPath $p -PathType Leaf)}
 'Folder' {return (Test-Path -LiteralPath $p -PathType Container)}
 'Log' {if(-not (Test-Path -LiteralPath $p -PathType Leaf)){return $false}; if([string]::IsNullOrEmpty([string]$c.Contains)){return $true}; return ([string](Get-Content -LiteralPath $p -Raw)).Contains([string]$c.Contains)}
 default {throw "Invalid check type for $($task.Id)"}
 }
}
function ScanTasks {
 $rows=@(foreach($task in @(Tasks)){
 if([string]$task.Id -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid script ID'}
 $done=Join-Path $logs "script-$($task.Id).done"
 $last=$null; if(Test-Path -LiteralPath $done){$last=Get-Content -LiteralPath $done -Raw | ConvertFrom-Json}
 $ok=Check $task
 $state='NOT EXECUTED'; $comment='Completion condition not satisfied'
 if($last -and $last.status -eq 'FAILED'){$state='FAILED'; $comment=$last.message}
 elseif($ok){$state='PASS'; $comment='Completion condition satisfied (not proof this tool ran it)'}
 elseif($last -and $last.status -eq 'PASS' -and -not $task.Check){$state='PASS'; $comment='Previous execution completed successfully'}
 elseif($last){$state='FAILED'; $comment='Completion condition no longer satisfied'}
 [pscustomobject]@{id=$task.Id;name=$task.Name;status=$state;comment=$comment;path=$task.Path}
 })
 Save ([pscustomobject]@{results=$rows;scannedAt=(Get-Date).ToString('s')}) (Join-Path $out 'scripts.json')
}
$mutex=New-Object Threading.Mutex($false,'Global\WorkstationCheckInstallTaskCenter')
$owned=$false
$busy=Join-Path $out 'busy.json'
$code=0
try {
 try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
 if(-not $owned){throw 'Another workstation operation is running. Wait for it to finish.'}
 Save ([pscustomobject]@{pid=$PID;mode=$Mode;id=$Id;startedAt=(Get-Date).ToString('s')}) $busy
 if($Mode -eq 'Scan'){
 & (Join-Path $PSScriptRoot 'Scan-All.ps1') -PackageRoot $PackageRoot | Out-Null
 ScanTasks
 }elseif($Mode -eq 'Install'){
 if($Id -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid application ID'}
 $args="-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'Install-App.ps1')`" -AppId `"$Id`" -PackageRoot `"$PackageRoot`""
 $p=Start-Process powershell.exe -ArgumentList $args -Wait -PassThru -WindowStyle Hidden
 if($p.ExitCode -ne 0){throw "Installer engine returned $($p.ExitCode). See the application log."}
 ScanTasks
 }else{
 if($Id -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid script ID'}
 $matches=@(Tasks | Where-Object {$_.Id -eq $Id}); if($matches.Count -ne 1){throw "Script not available in selected template: $Id"}
 $task=$matches[0]; $path=Resolve $task.Path
 $log=Join-Path $logs "script-$Id.log"; $done=Join-Path $logs "script-$Id.done"
 "Started $(Get-Date -Format s): $($task.Name)" | Set-Content -LiteralPath $log
 try{
 if(-not (Test-Path -LiteralPath $path -PathType Leaf)){throw "File not found: $path"}
 $a=[string]$task.Arguments; $ext=[IO.Path]::GetExtension($path).ToLowerInvariant()
 switch($ext){
 '.ps1' {$exe='powershell.exe';$a="-NoProfile -ExecutionPolicy Bypass -File `"$path`" $a"}
 '.bat' {$exe=$env:ComSpec;$a="/d /s /c `"`"$path`" $a`""}
 '.cmd' {$exe=$env:ComSpec;$a="/d /s /c `"`"$path`" $a`""}
 '.msi' {$exe='msiexec.exe';$a="/i `"$path`" $a /L*v `"$log.msi.log`""}
 '.exe' {$exe=$path}
 default {throw "Unsupported task file: $ext"}
 }
 $opts=@{FilePath=$exe;Wait=$true;PassThru=$true;WorkingDirectory=(Split-Path -Parent $path);RedirectStandardOutput="$log.stdout";RedirectStandardError="$log.stderr"}
 if($a){$opts.ArgumentList=$a}
 $p=Start-Process @opts
 foreach($capture in @("$log.stdout","$log.stderr")){if(Test-Path -LiteralPath $capture){Get-Content -LiteralPath $capture | Add-Content -LiteralPath $log}}
 $accepted=@(0); if($task.SuccessExitCodes){$accepted=@($task.SuccessExitCodes)}
 if($p.ExitCode -notin $accepted){throw "Exit code $($p.ExitCode)"}
 if($task.Check -and -not (Check $task)){throw 'Process ended but completion condition was not satisfied'}
 Save ([pscustomobject]@{status='PASS';exitCode=$p.ExitCode;rebootRequired=($p.ExitCode -in @(3010,1641));finishedAt=(Get-Date).ToString('s');message='Completed'}) $done
 'Completed successfully' | Add-Content -LiteralPath $log
 }catch{
 $_.Exception.Message | Add-Content -LiteralPath $log
 Save ([pscustomobject]@{status='FAILED';finishedAt=(Get-Date).ToString('s');message=$_.Exception.Message}) $done
 throw
 }finally{ScanTasks}
 }
}catch{$code=1; Write-Output $_.Exception.Message}
finally{if($owned){Remove-Item -LiteralPath $busy -Force -ErrorAction SilentlyContinue; $mutex.ReleaseMutex()};$mutex.Dispose()}
exit $code
