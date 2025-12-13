# Resume_Collect.ps1
# RukiTech Diagnostic Tool - Auto Resume Logic

$ProgramDataDir = "$env:ProgramData\RukiTech\Collect"
$LastRunFile = Join-Path $ProgramDataDir "last_run.json"

try {
    if (-not (Test-Path $LastRunFile)) {
        Write-Warning "Last run state not found at $LastRunFile. Nothing to resume."
        exit
    }

    $LastRunInfo = Get-Content $LastRunFile | ConvertFrom-Json
    $StatePath = $LastRunInfo.state_path
    $CollectScript = Join-Path $PSScriptRoot "Collect_Main.ps1"

    if (-not (Test-Path $StatePath)) {
        Write-Error "State file missing at $StatePath. Cannot resume."
        exit
    }

    if (-not (Test-Path $CollectScript)) {
        # Fallback to current directory if script root fails (e.g. if run from a weird context)
        # But $PSScriptRoot should work if this script is in the same folder.
        Write-Error "Collect script missing at $CollectScript."
        exit
    }

    # Resume Collection
    # Note: ExecutionPolicy Bypass is specified in the task action, but good to be explicit if we spawn new process.
    # We call Collect_Main.ps1 with -Resume flag.
    
    $Process = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$CollectScript`" -Resume -StatePath `"$StatePath`"" -PassThru -Wait

    if ($Process.ExitCode -eq 0) {
        Write-Host "Resume completed successfully."
    } else {
        Write-Error "Resume failed with exit code $($Process.ExitCode)."
    }

} catch {
    Write-Error "An error occurred during resume attempt: $_"
    $_ | Out-File "$env:TEMP\RukiTech_Resume_Error.txt" -Append
}
