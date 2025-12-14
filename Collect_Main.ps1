# Collect_Main.ps1
# RukiTech Diagnostic Tool - Collect Mode Core Logic
# Handles collection, state management, resuming, and reporting.

param (
    [string]$OutputDir = "$env:USERPROFILE\Desktop\PC_Diagnostic_Collect",
    [int]$Days = 14,
    [switch]$Opt_EventLogs,
    [switch]$Opt_SystemInfo,
    [switch]$Opt_DriverAppList,
    [switch]$Opt_Minidump,
    [switch]$Opt_MemoryDmp,
    [switch]$Opt_EnergyReport,
    [switch]$Opt_BatteryReport,
    [switch]$Opt_Zip,
    [switch]$Opt_AutoResume,
    
    # Resume Parameters
    [switch]$Resume,
    [string]$StatePath
)

# ---------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------

function Log-Message {
    param([string]$Msg, [string]$Level="INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogLine = "[$Timestamp][$Level] $Msg"
    Write-Host $LogLine -ForegroundColor ($Level -eq "ERROR" ? "Red" : "Gray")
    if ($Script:LogFile) {
        Add-Content -Path $Script:LogFile -Value $LogLine -Encoding UTF8
    }
}

function Save-State {
    if ($Script:State) {
        $Script:State | ConvertTo-Json -Depth 5 | Set-Content -Path $Script:StateFile -Encoding UTF8
    }
}

function Check-Step {
    param([string]$StepName)
    if ($Script:State.steps.$StepName -eq $true) {
        Log-Message "Step '$StepName' already completed. Skipping."
        return $true
    }
    return $false
}

function Mark-Step-Complete {
    param([string]$StepName)
    $Script:State.steps.$StepName = $true
    Save-State
    Log-Message "Step '$StepName' marked as complete." "SUCCESS"
}

# ---------------------------------------------------------
# Initialization
# ---------------------------------------------------------

$ErrorActionPreference = "Continue"

if ($Resume) {
    if (-not (Test-Path $StatePath)) {
        Write-Error "State file not found for resume: $StatePath"
        exit 1
    }
    $Script:StateFile = $StatePath
    try {
        $Script:State = Get-Content $StatePath | ConvertFrom-Json
    } catch {
        Write-Error "Failed to parse state file. Aborting."
        exit 1
    }
    
    $Script:CurrentOutputDir = $Script:State.output_dir
    $Script:LogFile = Join-Path $Script:CurrentOutputDir "run.log"
    
    Log-Message "------------------------------------------------"
    Log-Message "Resuming Collection Session (Resume Count: $($Script:State.resume_count))"
    
    $Script:State.resume_count++
    if ($Script:State.resume_count -gt 3) {
        Log-Message "Resume limit (3) reached. Aborting to prevent loop." "ERROR"
        exit 1
    }
    Save-State
}
else {
    # Fresh Start
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $DateStr = Get-Date -Format "yyyyMMdd_HHmmss"
    $RunID = "RukiCollect_$DateStr"
    $Script:CurrentOutputDir = Join-Path $OutputDir $RunID
    New-Item -ItemType Directory -Path $Script:CurrentOutputDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Script:CurrentOutputDir "raw") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Script:CurrentOutputDir "parsed") -Force | Out-Null
    
    $Script:LogFile = Join-Path $Script:CurrentOutputDir "run.log"
    
    # Initialize State
    $Script:State = [PSCustomObject]@{
        run_id = $RunID
        output_dir = $Script:CurrentOutputDir
        days = $Days
        options = @{
            event_logs = $Opt_EventLogs.IsPresent
            sys_info = $Opt_SystemInfo.IsPresent
            drivers = $Opt_DriverAppList.IsPresent
            minidump = $Opt_Minidump.IsPresent
            memory_dmp = $Opt_MemoryDmp.IsPresent
            energy = $Opt_EnergyReport.IsPresent
            battery = $Opt_BatteryReport.IsPresent
            zip = $Opt_Zip.IsPresent
            auto_resume = $Opt_AutoResume.IsPresent
        }
        resume_count = 0
        steps = [PSCustomObject]@{
            Init = $true
            SystemInfo = $false
            EventLogs = $false
            Dumps = $false
            Power = $false
            DriversApps = $false
            Report = $false
            Zip = $false
            Cleanup = $false
        }
    }
    $Script:StateFile = Join-Path $Script:CurrentOutputDir "state.json"
    Save-State
    
    # Setup Last Run for Auto-Resume
    $LastRunDir = "$env:ProgramData\RukiTech\Collect"
    if (-not (Test-Path $LastRunDir)) { New-Item -ItemType Directory -Path $LastRunDir -Force | Out-Null }
    
    $LastRunData = @{
        state_path = $Script:StateFile
        output_dir = $Script:CurrentOutputDir
        timestamp = (Get-Date).ToString("o")
    }
    $LastRunData | ConvertTo-Json | Set-Content -Path (Join-Path $LastRunDir "last_run.json") -Encoding UTF8
    
    Log-Message "Starting New Collection Session: $RunID"
    
    # Register Resume Task if needed
    if ($Opt_AutoResume) {
        & "$PSScriptRoot\Setup_Collect_Task.ps1"
        Register-CollectResumeTask -ResumeScriptPath (Join-Path $PSScriptRoot "Resume_Collect.ps1")
        Log-Message "Auto-resume task registered."
    }
}

# ---------------------------------------------------------
# Execution Steps
# ---------------------------------------------------------

# 1. System Info
if (-not (Check-Step "SystemInfo") -and $Script:State.options.sys_info) {
    Log-Message "Collecting System Information..."
    try {
        $RawPath = Join-Path $Script:CurrentOutputDir "raw"
        Get-ComputerInfo | Select-Object TsOs*, Os*, Cs*, Bios* | Export-Csv (Join-Path $RawPath "sysinfo_basic.csv") -NoTypeInformation -Encoding UTF8
        Get-CimInstance Win32_Processor | Export-Csv (Join-Path $RawPath "cpu.csv") -NoTypeInformation -Encoding UTF8
        Get-CimInstance Win32_PhysicalMemory | Export-Csv (Join-Path $RawPath "memory.csv") -NoTypeInformation -Encoding UTF8
        Get-CimInstance Win32_DiskDrive | Export-Csv (Join-Path $RawPath "disk.csv") -NoTypeInformation -Encoding UTF8
        Get-BitLockerVolume | Select-Object MountPoint, VolumeStatus, EncryptionMethod, ProtectionStatus | Export-Csv (Join-Path $RawPath "bitlocker.csv") -NoTypeInformation -Encoding UTF8
        
        Mark-Step-Complete "SystemInfo"
    } catch {
        Log-Message "Error collecting System Info: $_" "ERROR"
    }
}

# 2. Event Logs (Critical)
if (-not (Check-Step "EventLogs") -and $Script:State.options.event_logs) {
    Log-Message "Collecting Event Logs (Past $($Script:State.days) days)..."
    try {
        $StartTime = (Get-Date).AddDays(-$Script:State.days)
        $EventsToGrab = @(
            @{LogName='System'; ID=41}, # Kernel-Power
            @{LogName='System'; ID=1001}, # BugCheck
            @{LogName='System'; ID=6008}, # Unexpected Shutdown
            @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'},
            @{LogName='Application'; Level=1,2} # Error/Critical
        )
        
        $AllEvents = @()
        
        foreach ($Filter in $EventsToGrab) {
            $Hash = @{ StartTime=$StartTime } + $Filter
            try {
                $Evts = Get-WinEvent -FilterHashtable $Hash -ErrorAction SilentlyContinue
                if ($Evts) { $AllEvents += $Evts }
            } catch {}
        }
        
        $AllEvents | Sort-Object TimeCreated -Descending | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message | Export-Csv (Join-Path $Script:CurrentOutputDir "parsed\events_critical.csv") -NoTypeInformation -Encoding UTF8
        
        Mark-Step-Complete "EventLogs"
    } catch {
        Log-Message "Error collecting Event Logs: $_" "ERROR"
    }
}

# 3. Dumps
if (-not (Check-Step "Dumps")) {
    Log-Message "Checking for Crash Dumps..."
    try {
        if ($Script:State.options.minidump) {
            $MiniDir = "C:\Windows\Minidump"
            if (Test-Path $MiniDir) {
                Copy-Item "$MiniDir\*.dmp" (Join-Path $Script:CurrentOutputDir "raw") -ErrorAction SilentlyContinue
                Log-Message "Minidumps copied."
            }
        }
        if ($Script:State.options.memory_dmp) {
            $MemDmp = "C:\Windows\MEMORY.DMP"
            if (Test-Path $MemDmp) {
                Log-Message "Copying MEMORY.DMP (This may take a while)..."
                Copy-Item $MemDmp (Join-Path $Script:CurrentOutputDir "raw") -ErrorAction SilentlyContinue
                Log-Message "MEMORY.DMP copied."
            }
        }
        Mark-Step-Complete "Dumps"
    } catch {
        Log-Message "Error copying dumps: $_" "ERROR"
    }
}

# 4. Power
if (-not (Check-Step "Power")) {
    Log-Message "Collecting Power Reports..."
    try {
        if ($Script:State.options.energy) {
            Log-Message "Running powercfg /energy (60 sec)..."
            $EnergyOut = Join-Path $Script:CurrentOutputDir "raw\energy-report.html"
            powercfg /energy /output $EnergyOut /duration 60 | Out-Null
        }
        if ($Script:State.options.battery) {
             # Check if laptop (BatteryStatus)
             $Battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
             if ($Battery) {
                 Log-Message "Running powercfg /batteryreport..."
                 $BatOut = Join-Path $Script:CurrentOutputDir "raw\battery-report.html"
                 powercfg /batteryreport /output $BatOut | Out-Null
             } else {
                 Log-Message "Skipping Battery Report (Desktop detected/No battery)."
             }
        }
        Mark-Step-Complete "Power"
    } catch {
        Log-Message "Error collecting Power reports: $_" "ERROR"
    }
}

# 5. Drivers & Apps
if (-not (Check-Step "DriversApps") -and $Script:State.options.drivers) {
    Log-Message "Collecting Driver & App Lists..."
    try {
        Get-WindowsDriver -Online -All | Select-Object ProviderName, Date, Version, ClassName, OriginalFileName | Export-Csv (Join-Path $Script:CurrentOutputDir "raw\drivers.csv") -NoTypeInformation -Encoding UTF8
        
        # Simple App List via Registry
        $Keys = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        Get-ChildItem $Keys -Recurse -ErrorAction SilentlyContinue | Get-ItemProperty | Where-Object { $_.DisplayName } | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Export-Csv (Join-Path $Script:CurrentOutputDir "raw\apps.csv") -NoTypeInformation -Encoding UTF8
        
        Mark-Step-Complete "DriversApps"
    } catch {
        Log-Message "Error collecting Drivers/Apps: $_" "ERROR"
    }
}

# 5.5. Monitor Logs (Integration with existing tool)
if (-not (Check-Step "MonitorLogs")) {
    Log-Message "Checking for existing Monitor Mode logs..."
    try {
        $MonitorLogDir = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "PC_Diagnostic_Logs")
        if (Test-Path $MonitorLogDir) {
            $DestDir = Join-Path $Script:CurrentOutputDir "raw\MonitorLogs"
            if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir -Force | Out-Null }
            Copy-Item "$MonitorLogDir\*" $DestDir -Recurse -Force -ErrorAction SilentlyContinue
            Log-Message "Monitor logs copied from $MonitorLogDir."
        }
        Mark-Step-Complete "MonitorLogs"
    } catch {
        Log-Message "Error copying Monitor logs: $_" "ERROR"
    }
}

# 6. Generate Report
if (-not (Check-Step "Report")) {
    Log-Message "Generating HTML Report..."
    try {
        $TplContent = Get-Content (Join-Path $PSScriptRoot "templates\report_template.html") -Raw -Encoding UTF8
        
        # 1. Basic Info
        $SysInfo = Import-Csv (Join-Path $Script:CurrentOutputDir "raw\sysinfo_basic.csv") | Select-Object -First 1
        $InfoTable = ""
        $SysInfo.PSObject.Properties | ForEach-Object {
            $InfoTable += "<tr><td>$($_.Name)</td><td>$($_.Value)</td></tr>`n"
        }
        
        # 2. Critical Events
        $Events = Import-Csv (Join-Path $Script:CurrentOutputDir "parsed\events_critical.csv") -ErrorAction SilentlyContinue 
        $EventRows = ""
        if ($Events) {
            $Events | Select-Object -First 20 | ForEach-Object {
                $Class = if ($_.LevelDisplayName -match "Critical") { "critical" } elseif ($_.LevelDisplayName -match "Error") { "warning" } else { "" }
                $EventRows += "<tr class='$Class'><td>$($_.TimeCreated)</td><td>$($_.ProviderName)</td><td>$($_.Id)</td><td>$($_.LevelDisplayName)</td><td>$($_.Message)</td></tr>`n"
            }
        } else {
            $EventRows = "<tr><td colspan='5'>No critical events found within retention period.</td></tr>"
        }

        # 3. Top Events
        $TopEventsRows = ""
        if ($Events) {
            $Stats = $Events | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 10
            $Stats | ForEach-Object {
                $TopEventsRows += "<tr><td>$($_.Values[0])</td><td>$($_.Values[1])</td><td>$($_.Count)</td></tr>`n"
            }
        }

        # 4. Suspicious Drivers
        # Naive keyword matching in event messages
        $Suspicious = @()
        if ($Events) {
            $Keywords = "nvlddmkm", "amdkmdag", "stornvme", "disk", "ntfs", "tcpip"
            foreach ($k in $Keywords) {
                $Count = ($Events | Where-Object { $_.Message -match $k }).Count
                if ($Count -gt 0) { $Suspicious += "<li><strong>$k</strong>: Detected $Count times in error logs.</li>" }
            }
        }
        $SuspiciousHtml = if ($Suspicious) { $Suspicious -join "`n" } else { "<li>No obvious suspicious drivers detected in logs.</li>" }

        # Action Items
        $Actions = @()
        if ($Events -match "1001") { $Actions += "<li>BugCheck detected: Analyze dump files with WinDbg.</li>" }
        if ($Events -match "41") { $Actions += "<li>Kernel-Power 41 detected: Check PSU or overheating.</li>" }
        if ($Scripts:State.resume_count -gt 0) { $Actions += "<li>System restarted during diagnostics ($($Script:State.resume_count) times). Instability confirmed.</li>" }
        $ActionsHtml = if ($Actions) { $Actions -join "`n" } else { "<li>No immediate actions identified. Review logs manually.</li>" }

        # Battery Health Calculation
        $BatHealthText = "Info Not Available (Desktop?)"
        try {
            # Try WMI first
            $Static = Get-CimInstance -Namespace root\wmi -ClassName BatteryStaticData -ErrorAction SilentlyContinue | Select-Object -First 1
            $Full   = Get-CimInstance -Namespace root\wmi -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue | Select-Object -First 1
            
            if ($Static -and $Full -and $Static.DesignedCapacity -gt 0) {
                # Some devices report in different units, but usually relative.
                $Design = $Static.DesignedCapacity
                $CurrentFull = $Full.FullChargedCapacity
                
                # Check for plausibility
                if ($Design -gt 100000000) { $Design = $Design / 1000 } # Sanity check for massive numbers
                if ($CurrentFull -gt 100000000) { $CurrentFull = $CurrentFull / 1000 }

                $HealthPct = ($CurrentFull / $Design) * 100
                
                # Coloring
                $Color = if ($HealthPct -lt 50) { "red" } elseif ($HealthPct -lt 70) { "orange" } else { "green" }
                $BatHealthText = "<span style='color:$Color; font-weight:bold;'>$("{0:N1}" -f $HealthPct)%</span> (Design: $Design, Current Full: $CurrentFull)"
            }
        } catch {
             $BatHealthText = "Error calculating: $_"
        }

        # Replacements
        $Report = $TplContent `
            .Replace("{{GENERATED_DATE}}", (Get-Date).ToString()) `
            .Replace("{{RUN_ID}}", $Script:State.run_id) `
            .Replace("{{PC_MODEL}}", "$($SysInfo.CsModel)") `
            .Replace("{{PC_SERIAL}}", "$($SysInfo.BiosSeralNumber)") `
            .Replace("{{DAYS_COLLECTED}}", "$($Script:State.days)") `
            .Replace("{{RESUME_COUNT}}", "$($Script:State.resume_count)") `
            .Replace("{{STATUS}}", "Completed") `
            .Replace("{{ACTION_ITEMS}}", $ActionsHtml) `
            .Replace("{{SYSTEM_INFO_TABLE}}", $InfoTable) `
            .Replace("{{CRITICAL_EVENTS_TABLE}}", $EventRows) `
            .Replace("{{TOP_EVENTS_TABLE}}", $TopEventsRows) `
            .Replace("{{SUSPICIOUS_DRIVERS}}", $SuspiciousHtml) `
            .Replace("{{BATTERY_HEALTH}}", $BatHealthText) `
            .Replace("{{BATTERY_REPORT_LINK}}", "raw/battery-report.html") `
            .Replace("{{ENERGY_REPORT_LINK}}", "raw/energy-report.html") `
            .Replace("{{POWER_PLAN}}", (Get-CimInstance Win32_PowerPlan -Namespace root\cimv2\power -Filter "IsActive='$true'" | Select-Object -ExpandProperty ElementName))

        $Report | Set-Content (Join-Path $Script:CurrentOutputDir "REPORT.html") -Encoding UTF8
        Mark-Step-Complete "Report"
    } catch {
        Log-Message "Error generating report: $_" "ERROR"
    }
}

# 7. Zip
if (-not (Check-Step "Zip") -and $Script:State.options.zip) {
    Log-Message "Archiving results..."
    try {
        $ZipPath = Join-Path $Script:State.output_dir "$($Script:State.run_id).zip"
        Compress-Archive -Path "$($Script:CurrentOutputDir)\*" -DestinationPath $ZipPath -Force
        Log-Message "ZIP created at: $ZipPath"
        Mark-Step-Complete "Zip"
    } catch {
        Log-Message "Error zipping: $_" "ERROR"
    }
}

# 8. Cleanup
if (-not (Check-Step "Cleanup")) {
    if ($Script:State.options.auto_resume) {
        & "$PSScriptRoot\Setup_Collect_Task.ps1"
        Unregister-CollectResumeTask
    }
    # Remove Last Run file
    $ProgramDataDir = "$env:ProgramData\RukiTech\Collect"
    $LastRunFile = Join-Path $ProgramDataDir "last_run.json"
    if (Test-Path $LastRunFile) { Remove-Item $LastRunFile -Force -ErrorAction SilentlyContinue }
    
    Log-Message "Diagnostic Collection Finished Successfully." "SUCCESS"
    Mark-Step-Complete "Cleanup"
}

Log-Message "All operations completed."
