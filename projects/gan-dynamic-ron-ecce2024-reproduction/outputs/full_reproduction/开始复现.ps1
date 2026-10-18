[CmdletBinding()]
param(
    [ValidateSet('All','Simulink','LTspice','Open','Check')][string]$Mode='All',
    [string]$MatlabPath='E:\MATLABR2022b\bin\matlab.exe',
    [string]$LTspicePath='D:\LTspice\LTspice.exe'
)
$ErrorActionPreference='Stop'
$taskBase=$PSScriptRoot
$taskLogs=Join-Path $taskBase 'run_logs'
New-Item -ItemType Directory -Path $taskLogs -Force | Out-Null
$taskStamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$taskModels=Get-ChildItem -LiteralPath $taskBase -Recurse -Filter '*.slx' -File
if($taskModels.Count -ne 11){throw 'Expected exactly 11 native SLX models.'}
foreach($taskEntry in @('run_all.m','open_models.m','simulink\build_and_run_simulink.m','tec\build_run_tec.m')){
    if(-not(Test-Path -LiteralPath (Join-Path $taskBase $taskEntry))){throw "Missing entry: $taskEntry"}
}
if($Mode -in @('All','Simulink','Open','Check')){
    if(-not(Test-Path -LiteralPath $MatlabPath)){throw "MATLAB was not found: $MatlabPath. Set -MatlabPath."}
}
if($Mode -in @('All','LTspice','Check')){
    if(-not(Test-Path -LiteralPath $LTspicePath)){throw "LTspice was not found: $LTspicePath. Set -LTspicePath."}
}
if($Mode -eq 'Check'){
    Write-Output 'PASS: 11 native models, entry scripts, MATLAB and LTspice paths are present.'
    return
}

function Invoke-TaskProcess([string]$Exe,[string[]]$Arguments,[string]$Directory,[int]$TimeoutSeconds){
    $taskStarted=Get-Date
    $taskProcess=Start-Process -FilePath $Exe -ArgumentList $Arguments -WorkingDirectory $Directory -WindowStyle Hidden -PassThru
    if(-not $taskProcess.WaitForExit($TimeoutSeconds*1000)){
        # Only this exact process created by this invocation is stopped.
        Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
        throw "Task-owned process timed out: PID=$($taskProcess.Id), $Exe"
    }
    $taskProcess.Refresh()
    if($taskProcess.ExitCode -ne 0){throw "Native process failed with exit $($taskProcess.ExitCode): $Exe"}
    return [pscustomobject]@{pid=$taskProcess.Id;exit_code=$taskProcess.ExitCode;started=$taskStarted.ToString('o');finished=(Get-Date).ToString('o')}
}

if($Mode -in @('All','LTspice')){
    $taskRecords=@()
    $taskSpiceFiles=@(Get-ChildItem -LiteralPath (Join-Path $taskBase 'clamp') -File -Filter '*.cir' | Sort-Object Name)
    $taskSpiceFiles+=Get-Item -LiteralPath (Join-Path $taskBase 'scrc\scrc_parallel.cir')
    $taskSpiceFiles+=@(Get-ChildItem -LiteralPath (Join-Path $taskBase 'clamp') -File -Filter '*.asc' | Sort-Object Name)
    $taskOldBridge=Join-Path (Split-Path $taskBase -Parent) 'reproduction\ltspice'
    foreach($taskName in @('conventional.asc','proposed.asc')){$taskSpiceFiles+=Get-Item -LiteralPath (Join-Path $taskOldBridge $taskName)}
    foreach($taskFile in $taskSpiceFiles){
        Write-Output "LTspice: $($taskFile.Name)"
        $taskInput=$taskFile.FullName
        $taskConvert=$null
        if($taskFile.Extension -eq '.asc'){
            $taskConvert=Invoke-TaskProcess $LTspicePath @('-netlist',('"'+$taskInput+'"')) $taskFile.DirectoryName 45
            $taskInput=[IO.Path]::ChangeExtension($taskInput,'.net')
            if(-not(Test-Path -LiteralPath $taskInput)){throw "Netlist not generated: $taskInput"}
        }
        $taskStart=Get-Date
        $taskRun=Invoke-TaskProcess $LTspicePath @('-ascii','-b',('"'+$taskInput+'"')) $taskFile.DirectoryName 120
        $taskRaw=[IO.Path]::ChangeExtension($taskInput,'.raw')
        $taskLog=[IO.Path]::ChangeExtension($taskInput,'.log')
        foreach($taskOutput in @($taskRaw,$taskLog)){
            $taskInfo=Get-Item -LiteralPath $taskOutput
            if($taskInfo.Length -le 0 -or $taskInfo.LastWriteTime -lt $taskStart.AddSeconds(-2)){throw "Missing or stale output: $taskOutput"}
        }
        $taskText=Get-Content -LiteralPath $taskLog -Raw
        if($taskText -match 'Fatal Error|Analysis failed|Time step too small|Unknown subcircuit'){throw "Native error: $taskLog"}
        $taskRecords += [pscustomobject]@{input=$taskFile.FullName;conversion=$taskConvert;run=$taskRun;raw_bytes=(Get-Item -LiteralPath $taskRaw).Length;raw_sha256=(Get-FileHash -LiteralPath $taskRaw -Algorithm SHA256).Hash.ToLower()}
        $taskRecords | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskLogs ($taskStamp+'_ltspice.json')) -Encoding utf8
    }
    Write-Output "PASS: $($taskRecords.Count) native LTspice jobs, run serially."
}

if($Mode -in @('All','Simulink','Open')){
    $taskEscaped=$taskBase.Replace("'","''")
    if($Mode -eq 'Open'){
        $taskCommand="addpath('$taskEscaped');open_models"
        # This mode is an explicit user request to open interactive model windows.
        Start-Process -FilePath $MatlabPath -ArgumentList @('-r',('"'+$taskCommand+'"')) -WorkingDirectory $taskBase | Out-Null
        return
    }
    $taskCommand="addpath('$taskEscaped');run_all"
    $taskLog=Join-Path $taskLogs ($taskStamp+'_matlab.log')
    Write-Output "MATLAB: rebuilding and running all native models. Log: $taskLog"
    $taskRun=Invoke-TaskProcess $MatlabPath @('-batch',('"'+$taskCommand+'"'),'-logfile',('"'+$taskLog+'"')) $taskBase 3600
    $taskStatus=Get-Content -LiteralPath (Join-Path $taskBase 'unified_run_status.json') -Raw | ConvertFrom-Json
    if(-not $taskStatus.complete){throw 'MATLAB did not record a complete run.'}
    $taskRun | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $taskLogs ($taskStamp+'_matlab_process.json')) -Encoding utf8
    Write-Output 'PASS: all native MATLAB / Simulink stages completed.'
}
