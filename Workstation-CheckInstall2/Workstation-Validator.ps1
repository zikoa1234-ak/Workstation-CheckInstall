#Requires -Version 5.1
#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$script:root=$PSScriptRoot
$script:out=Join-Path $root 'Output'
$script:engine=Join-Path $root 'Engine'
New-Item -ItemType Directory -Force -Path $out,(Join-Path $root 'Logs') | Out-Null
$script:worker=$null
$script:errorText=''
function ReadJson($path){try{if(Test-Path -LiteralPath $path){return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json}}catch{};return $null}
function IsBusy {
 if($script:worker -and -not $script:worker.HasExited){return $true}
 $b=ReadJson (Join-Path $out 'busy.json')
 if($b){return [bool](Get-Process -Id $b.pid -ErrorAction SilentlyContinue)}
 return $false
}
function Notice($text){[Windows.Forms.MessageBox]::Show([string]$text,'Workstation Center') | Out-Null}
function StartTask($mode,$id){
 if(IsBusy){return}
 try{
 $script:errorText=''
 $a="-NoProfile -File `"$(Join-Path $engine 'Task-Center.ps1')`" -Mode $mode -PackageRoot `"$root`""
 if($id){if($id -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid ID'};$a+=" -Id `"$id`""}
 $script:worker=Start-Process powershell.exe -ArgumentList $a -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $out 'ui-task.stdout') -RedirectStandardError (Join-Path $out 'ui-task.stderr')
 UpdateLock
 }catch{Notice $_.Exception.Message}
}
function DataText($value){
 if($null -eq $value){return '$null'}
 if($value -is [bool]){if($value){return '$true'};return '$false'}
 if($value -is [System.Collections.IDictionary]){
 $parts=@(foreach($key in $value.Keys){"'"+([string]$key).Replace("'","''")+"' = "+(DataText $value[$key])})
 return '@{ '+($parts -join '; ')+' }'
 }
 if($value -is [array]){return '@('+(@(foreach($v in $value){DataText $v}) -join ', ')+')'}
 return "'"+([string]$value).Replace("'","''")+"'"
}
function EditTemplate {
 if(IsBusy){return}
 $name=[string]$combo.SelectedItem
 if($name -eq 'All applications'){Notice 'Select a named template first.';return}
 try{
 $path=Join-Path $root "Templates\$name.psd1"
 $tpl=Import-PowerShellDataFile $path
 $apps=@((Import-PowerShellDataFile (Join-Path $engine 'AppManifest.psd1')).Apps)
 $scripts=@((Import-PowerShellDataFile (Join-Path $engine 'ScriptManifest.psd1')).Scripts)
 $dlg=New-Object Windows.Forms.Form
 $dlg.Text="Edit template: $name";$dlg.Size=New-Object Drawing.Size(820,520);$dlg.StartPosition='CenterParent'
 $left=New-Object Windows.Forms.CheckedListBox;$left.SetBounds(15,40,375,360);$left.CheckOnClick=$true
 $right=New-Object Windows.Forms.CheckedListBox;$right.SetBounds(410,40,375,360);$right.CheckOnClick=$true
 $l=New-Object Windows.Forms.Label;$l.Text='Applications';$l.SetBounds(15,15,300,25)
 $r=New-Object Windows.Forms.Label;$r.Text='Scripts';$r.SetBounds(410,15,300,25)
 foreach($app in $apps){[void]$left.Items.Add("$($app.Id) - $($app.Name)",($app.Id -in @($tpl.Apps)))}
 foreach($task in $scripts){$checked= -not $tpl.ContainsKey('Scripts') -or $task.Id -in @($tpl.Scripts);[void]$right.Items.Add("$($task.Id) - $($task.Name)",$checked)}
 $save=New-Object Windows.Forms.Button;$save.Text='Save';$save.SetBounds(580,420,95,32);$save.DialogResult='OK'
 $cancel=New-Object Windows.Forms.Button;$cancel.Text='Cancel';$cancel.SetBounds(685,420,95,32);$cancel.DialogResult='Cancel'
 $dlg.Controls.AddRange(@($left,$right,$l,$r,$save,$cancel));$dlg.AcceptButton=$save;$dlg.CancelButton=$cancel
 if($dlg.ShowDialog($form) -eq 'OK'){
 $appIds=@(foreach($i in $left.CheckedIndices){[string]$apps[$i].Id})
 $scriptIds=@(foreach($i in $right.CheckedIndices){[string]$scripts[$i].Id})
 foreach($app in $apps){if($app.Id -in $appIds){foreach($dep in @($app.InstallAfter)){if($dep -notin $appIds){throw "Select dependency $dep required by $($app.Name), then save again."}}}}
 $tpl.Apps=$appIds;$tpl.Scripts=$scriptIds
 $tmp="$path.edit.tmp"
 DataText $tpl | Set-Content -LiteralPath $tmp -Encoding UTF8
 $null=Import-PowerShellDataFile -Path $tmp
 Copy-Item -LiteralPath $path -Destination "$path.bak" -Force
 Move-Item -LiteralPath $tmp -Destination $path -Force
 StartTask 'Scan' ''
 }
 $dlg.Dispose()
 }catch{Notice $_.Exception.Message}
}
$form=New-Object Windows.Forms.Form
$form.Text='Workstation Check & Install Center - Native Dashboard'
$form.Size=New-Object Drawing.Size(1250,800);$form.MinimumSize=New-Object Drawing.Size(950,600);$form.StartPosition='CenterScreen'
$bar=New-Object Windows.Forms.FlowLayoutPanel;$bar.Dock='Top';$bar.Height=50;$bar.Padding=New-Object Windows.Forms.Padding(8)
$combo=New-Object Windows.Forms.ComboBox;$combo.DropDownStyle='DropDownList';$combo.Width=200
[void]$combo.Items.Add('All applications')
Get-ChildItem -LiteralPath (Join-Path $root 'Templates') -Filter '*.psd1' | Sort-Object Name | ForEach-Object {[void]$combo.Items.Add($_.BaseName)}
$choice=Join-Path $out 'template.txt';$saved='';if(Test-Path -LiteralPath $choice){$saved=([string](Get-Content -LiteralPath $choice -Raw)).Trim()}
$combo.SelectedIndex=0;if($saved -and $combo.Items.Contains($saved)){$combo.SelectedItem=$saved}
$bar.Controls.Add($combo)
function AddButton($text,$handler){$b=New-Object Windows.Forms.Button;$b.Text=$text;$b.AutoSize=$true;$b.Height=30;$b.Add_Click($handler);$bar.Controls.Add($b);return $b}
$rescan=AddButton 'Rescan' {StartTask 'Scan' ''}
$edit=AddButton 'Edit template' {EditTemplate}
$manifestButton=AddButton 'Edit script definitions' {Start-Process notepad.exe -ArgumentList "`"$(Join-Path $engine 'ScriptManifest.psd1')`""}
$install=AddButton 'Install / Upgrade selected' {if($appGrid.SelectedRows.Count){$row=$appGrid.SelectedRows[0];$state=[string]$row.Cells['status'].Value;if($state -in @('MISSING','WRONG_VERSION')){StartTask 'Install' ([string]$row.Cells['id'].Value)}else{Notice 'Select a missing or wrong-version application.'}}}
$execute=AddButton 'Execute selected script' {if($scriptGrid.SelectedRows.Count){StartTask 'Script' ([string]$scriptGrid.SelectedRows[0].Cells['id'].Value)}}
$logButton=AddButton 'View selected log' {
 $isScript=$tabs.SelectedTab -eq $scriptTab;$grid=$appGrid;if($isScript){$grid=$scriptGrid}
 if($grid.SelectedRows.Count){$id=[string]$grid.SelectedRows[0].Cells['id'].Value;$prefix='';if($isScript){$prefix='script-'};$path=Join-Path $root "Logs\$prefix$id.log";if(Test-Path -LiteralPath $path){Start-Process notepad.exe -ArgumentList "`"$path`""}else{Notice 'No log exists yet.'}}
}
$summary=New-Object Windows.Forms.Label;$summary.Dock='Top';$summary.Height=65;$summary.Padding=New-Object Windows.Forms.Padding(10);$summary.Text='Loading...'
$tabs=New-Object Windows.Forms.TabControl;$tabs.Dock='Fill'
$appTab=New-Object Windows.Forms.TabPage;$appTab.Text='Applications'
$scriptTab=New-Object Windows.Forms.TabPage;$scriptTab.Text='Scripts'
$tabs.TabPages.AddRange(@($appTab,$scriptTab))
function Grid($parent,$columns){$g=New-Object Windows.Forms.DataGridView;$g.Dock='Fill';$g.ReadOnly=$true;$g.AllowUserToAddRows=$false;$g.AllowUserToDeleteRows=$false;$g.MultiSelect=$false;$g.SelectionMode='FullRowSelect';$g.AutoSizeColumnsMode='Fill';foreach($c in $columns){[void]$g.Columns.Add($c,$c)};$parent.Controls.Add($g);return $g}
$appGrid=Grid $appTab @('id','status','name','requiredVersion','installedVersion','comment','reboot')
$scriptGrid=Grid $scriptTab @('id','status','name','path','comment','reboot')
$form.Controls.Add($tabs);$form.Controls.Add($summary);$form.Controls.Add($bar)
function LoadRows {
 $data=ReadJson (Join-Path $out 'status.json');$appGrid.Rows.Clear()
 $records=@();if($data){$records=@($data.results)}
 foreach($r in $records){$d=ReadJson (Join-Path $root "Logs\$($r.id).done");$reboot='';if($d -and $d.rebootRequired){$reboot='REBOOT REQUIRED'};[void]$appGrid.Rows.Add([string]$r.id,[string]$r.status,[string]$r.name,[string]$r.requiredVersion,[string]$r.installedVersion,[string]$r.comment,$reboot)}
 $s=ReadJson (Join-Path $out 'scripts.json');$scriptGrid.Rows.Clear();$tasks=@();if($s){$tasks=@($s.results)}
 foreach($r in $tasks){$d=ReadJson (Join-Path $root "Logs\script-$($r.id).done");$reboot='';if($d -and $d.rebootRequired){$reboot='REBOOT REQUIRED'};[void]$scriptGrid.Rows.Add([string]$r.id,[string]$r.status,[string]$r.name,[string]$r.path,[string]$r.comment,$reboot)}
 $pass=@($records | Where-Object {$_.status -eq 'PASS'}).Count
 $spass=@($tasks | Where-Object {$_.status -eq 'PASS'}).Count
 $script:summaryText="Computer: $env:COMPUTERNAME | Template: $($combo.SelectedItem)`r`nApplications: $pass/$($records.Count) passing | Scripts: $spass/$($tasks.Count) passing"
 if(-not $tasks.Count){$script:summaryText+=' | No scripts selected/configured'}
}
function UpdateLock {
 $busy=IsBusy
 foreach($c in @($combo,$rescan,$edit,$manifestButton,$install,$execute)){$c.Enabled= -not $busy}
 $summary.Text=$script:summaryText
 if($busy){$summary.Text+="`r`nOperation running - all execution buttons locked"}elseif($script:errorText){$summary.Text+="`r`n$script:errorText"}
}
$combo.Add_SelectedIndexChanged({if(-not (IsBusy)){$v=[string]$combo.SelectedItem;if($v -eq 'All applications'){$v=''};Set-Content -LiteralPath $choice -Value $v -Encoding ASCII;StartTask 'Scan' ''}})
$form.Add_Shown({LoadRows;StartTask 'Scan' ''})
$timer=New-Object Windows.Forms.Timer;$timer.Interval=1000
$timer.Add_Tick({
 if($script:worker -and $script:worker.HasExited){
 $script:errorText='';if($script:worker.ExitCode -ne 0){$details=@();foreach($p in @('ui-task.stdout','ui-task.stderr')){if(Test-Path (Join-Path $out $p)){$details+=Get-Content (Join-Path $out $p) -Raw}};$script:errorText=($details -join ' ')}
 $script:worker.Dispose();$script:worker=$null;LoadRows
 }
 UpdateLock
})
$form.Add_FormClosing({param($sender,$e) if(IsBusy){$e.Cancel=$true;Notice 'Wait for the running operation to finish before closing.'}})
$timer.Start();[void]$form.ShowDialog();$timer.Stop();$timer.Dispose();$form.Dispose()
