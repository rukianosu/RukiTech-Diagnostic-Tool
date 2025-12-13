# Setup_Collect_Task.ps1
# RukiTech Diagnostic Tool - Collect Mode Auto-Resume Task Setup

$TaskName = "RukiTech_Collect_Resume"
$TaskDescription = "RukiTech Diagnostic Tool - Auto Resume Collection Step after Reboot"

function Register-CollectResumeTask {
    param (
        [string]$ResumeScriptPath
    )

    if (-not (Test-Path $ResumeScriptPath)) {
        Write-Error "Resume script not found: $ResumeScriptPath"
        return
    }

    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ResumeScriptPath`""
    $Trigger = New-ScheduledTaskTrigger -AtLogOn
    $Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    # Note: Using SYSTEM for stability, but strictly speaking AtLogOn usually targets the user. 
    # For diagnostics, running as SYSTEM is best for permissions.
    
    $CurrentPrincipal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Administrators" -RunLevel Highest

    # Setting compatibility to Win8 to ensure options work
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)

    try {
        # Check if exists
        $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($Existing) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        }

        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $CurrentPrincipal -Settings $Settings -Description $TaskDescription
        Write-Host "Task '$TaskName' registered successfully." -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to register task: $_"
    }
}

function Unregister-CollectResumeTask {
    try {
        $Existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($Existing) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Host "Task '$TaskName' unregistered successfully." -ForegroundColor Green
        }
    }
    catch {
        Write-Warning "Failed to unregister task (or not found): $_"
    }
}

# Allow independent execution for testing
if ($MyInvocation.ScriptName -eq $PSCommandPath) {
    # If run directly, just clean up
    Unregister-CollectResumeTask
}
