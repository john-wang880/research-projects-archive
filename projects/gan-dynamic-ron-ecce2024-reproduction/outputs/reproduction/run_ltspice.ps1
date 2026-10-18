param([string]$LtspiceExe='D:\LTspice\LTspice.exe')
$ErrorActionPreference='Stop'
$taskCircuitDir=Join-Path $PSScriptRoot 'ltspice'
$taskResults=@()
foreach($taskCase in @('conventional','proposed')) {
    $taskSchematic=Join-Path $taskCircuitDir ($taskCase+'.asc')
    # Explicitly convert the native schematic, then run the generated netlist.
    # LTspice 24 may interpret bare -b with an .asc as a web-sync operation.
    $taskConverter=Start-Process -FilePath $LtspiceExe -ArgumentList @('-netlist',('"'+$taskSchematic+'"')) -WorkingDirectory $taskCircuitDir -WindowStyle Hidden -PassThru
    if(-not $taskConverter.WaitForExit(20000)) { $taskConverter.Kill(); throw "Schematic conversion exceeded 20 s: $taskCase" }
    if($taskConverter.ExitCode -ne 0) {throw "Schematic conversion failed: $taskCase"}
    $taskInput=Join-Path $taskCircuitDir ($taskCase+'.net')
    if(-not (Test-Path -LiteralPath $taskInput)) {throw "Generated netlist missing: $taskCase"}
    $taskWatch=[Diagnostics.Stopwatch]::StartNew()
    $taskStart=Get-Date
    $taskProcess=Start-Process -FilePath $LtspiceExe -ArgumentList @('-ascii','-b',('"'+$taskInput+'"')) -WorkingDirectory $taskCircuitDir -WindowStyle Hidden -PassThru
    if(-not $taskProcess.WaitForExit(60000)) {
        # Only the exact batch process created above is eligible for termination.
        $taskProcess.Kill()
        throw "This batch exceeded 60 s: $taskCase. Existing LTspice sessions were untouched."
    }
    $taskProcess.Refresh()
    $taskLog=Join-Path $taskCircuitDir ($taskCase+'.log')
    $taskRaw=Join-Path $taskCircuitDir ($taskCase+'.raw')
    if($taskProcess.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $taskRaw) -or -not (Test-Path -LiteralPath $taskLog)) {throw "LTspice failed: $taskCase, exit=$($taskProcess.ExitCode)"}
    if((Get-Item -LiteralPath $taskRaw).LastWriteTime -lt $taskStart -or (Get-Item -LiteralPath $taskLog).LastWriteTime -lt $taskStart) {throw "Output freshness check failed: $taskCase"}
    $taskLogText=Get-Content -LiteralPath $taskLog -Raw
    if($taskLogText -match 'Fatal Error|Time step too small|Singular matrix|Convergence failed') {throw "Simulation error in $taskCase. Inspect $taskLog"}
    $taskResults += [pscustomobject]@{case=$taskCase;exit_code=$taskProcess.ExitCode;elapsed_s=$taskWatch.Elapsed.TotalSeconds;raw_bytes=(Get-Item -LiteralPath $taskRaw).Length}
}
$taskResults | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'ltspice_run_status.json') -Encoding utf8
$taskResults | ConvertTo-Json
