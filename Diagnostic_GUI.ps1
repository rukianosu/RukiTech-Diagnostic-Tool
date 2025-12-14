# Diagnostic_GUI.ps1
# RukiTech Diagnostic Tool - Collect Mode GUI Frontend
# Requires .NET 4.5+

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------
# UI Setup
# ---------------------------------------------------------

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "RukiTech Diagnostic Collect Tool"
$Form.Size = New-Object System.Drawing.Size(600, 750)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false

$Font = New-Object System.Drawing.Font("Segoe UI", 9)
$Form.Font = $Font

# Group: Output Settings
$GrpOutput = New-Object System.Windows.Forms.GroupBox
$GrpOutput.Text = "Output Settings"
$GrpOutput.Location = New-Object System.Drawing.Point(10, 10)
$GrpOutput.Size = New-Object System.Drawing.Size(560, 80)
$Form.Controls.Add($GrpOutput)

$LblPath = New-Object System.Windows.Forms.Label
$LblPath.Text = "Output Folder:"
$LblPath.Location = New-Object System.Drawing.Point(10, 25)
$LblPath.AutoSize = $true
$GrpOutput.Controls.Add($LblPath)

$TxtPath = New-Object System.Windows.Forms.TextBox
$TxtPath.Text = "$env:USERPROFILE\Desktop\PC_Diagnostic_Collect"
$TxtPath.Location = New-Object System.Drawing.Point(10, 45)
$TxtPath.Size = New-Object System.Drawing.Size(450, 25)
$GrpOutput.Controls.Add($TxtPath)

$BtnBrowse = New-Object System.Windows.Forms.Button
$BtnBrowse.Text = "Browse"
$BtnBrowse.Location = New-Object System.Drawing.Point(470, 44)
$BtnBrowse.Size = New-Object System.Drawing.Size(80, 27)
$BtnBrowse.Add_Click({
    $Fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $Fbd.SelectedPath = $TxtPath.Text
    if ($Fbd.ShowDialog() -eq "OK") {
        $TxtPath.Text = $Fbd.SelectedPath
    }
})
$GrpOutput.Controls.Add($BtnBrowse)

# Group: Collection Options
$GrpOptions = New-Object System.Windows.Forms.GroupBox
$GrpOptions.Text = "Collection Options"
$GrpOptions.Location = New-Object System.Drawing.Point(10, 100)
$GrpOptions.Size = New-Object System.Drawing.Size(560, 230)
$Form.Controls.Add($GrpOptions)

$LblDay = New-Object System.Windows.Forms.Label
$LblDay.Text = "Log History (Days):"
$LblDay.Location = New-Object System.Drawing.Point(10, 25)
$LblDay.AutoSize = $true
$GrpOptions.Controls.Add($LblDay)

$NumDays = New-Object System.Windows.Forms.NumericUpDown
$NumDays.Minimum = 1
$NumDays.Maximum = 60
$NumDays.Value = 14
$NumDays.Location = New-Object System.Drawing.Point(130, 23)
$NumDays.Size = New-Object System.Drawing.Size(60, 25)
$GrpOptions.Controls.Add($NumDays)

# Checkboxes
function Add-Check($Text, $X, $Y, $Checked=$true) {
    $Chk = New-Object System.Windows.Forms.CheckBox
    $Chk.Text = $Text
    $Chk.Location = New-Object System.Drawing.Point($X, $Y)
    $Chk.AutoSize = $true
    $Chk.Checked = $Checked
    $GrpOptions.Controls.Add($Chk)
    return $Chk
}

$ChkEvents     = Add-Check "Event Logs (System/App/Critical)" 10 60
$ChkSysInfo    = Add-Check "System Info (HW/SW/BitLocker)" 10 90
$ChkDrivers    = Add-Check "Drivers / Updates / App List" 10 120
$ChkEnergy     = Add-Check "Power Energy Report (60s)" 10 150
$ChkBattery    = Add-Check "Battery Report (Laptop only)" 10 180

$ChkMinidump   = Add-Check "Copy Minidumps (*.dmp)" 300 60
$ChkMemDmp     = Add-Check "Copy MEMORY.DMP (Huge File!)" 300 90 $false
$ChkMemDmp.ForeColor = "Red"

$ChkZip        = Add-Check "Compress Output (ZIP)" 300 120
$ChkResume     = Add-Check "Auto-Resume after Reboot" 300 150
$ChkResume.Font = New-Object System.Drawing.Font($Font, [System.Drawing.FontStyle]::Bold)

$ChkNoSleep    = Add-Check "Prevent Sleep (Create Temp Power Plan)" 300 180
$ChkNoSleep.Checked = $true

# Restore Power Button
$BtnRestore = New-Object System.Windows.Forms.Button
$BtnRestore.Text = "Restore Power Settings"
$BtnRestore.Location = New-Object System.Drawing.Point(400, 310) # Right above Start
$BtnRestore.Size = New-Object System.Drawing.Size(170, 25)
$BtnRestore.BackColor = "LightGray"
$Form.Controls.Add($BtnRestore)

# Start Button
$BtnStart = New-Object System.Windows.Forms.Button
$BtnStart.Text = "START COLLECTION"
$BtnStart.Location = New-Object System.Drawing.Point(10, 340)
$BtnStart.Size = New-Object System.Drawing.Size(560, 40)
$BtnStart.BackColor = "LightBlue"
$Form.Controls.Add($BtnStart)

# Log Window
$GrpLog = New-Object System.Windows.Forms.GroupBox
$GrpLog.Text = "Execution Log"
$GrpLog.Location = New-Object System.Drawing.Point(10, 390)
$GrpLog.Size = New-Object System.Drawing.Size(560, 300)
$Form.Controls.Add($GrpLog)

$TxtLog = New-Object System.Windows.Forms.TextBox
$TxtLog.Multiline = $true
$TxtLog.ScrollBars = "Vertical"
$TxtLog.ReadOnly = $true
$TxtLog.Location = New-Object System.Drawing.Point(10, 20)
$TxtLog.Size = New-Object System.Drawing.Size(540, 270)
$TxtLog.BackColor = "Black"
$TxtLog.ForeColor = "White"
$TxtLog.Font = New-Object System.Drawing.Font("Consolas", 9)
$GrpLog.Controls.Add($TxtLog)

# Admin Check Warning
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $IsAdmin) {
    if ([System.Windows.Forms.MessageBox]::Show("Admin privileges are highly recommended for accessing System Logs and Dumps.`n`nRelaunch as Admin?", "Admin Check", "YesNo", "Warning") -eq "Yes") {
        Start-Process "powershell.exe" -ArgumentList "-File `"$PSCommandPath`"" -Verb RunAs
        $Form.Close()
        exit
    }
    $Form.Text += " (Restricted Mode)"
}

# ---------------------------------------------------------
# Logic
# ---------------------------------------------------------

$Script:CurrentLogFile = $null
$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 1000 # 1 sec

# Power Management Functions
$PowerBackupFile = Join-Path $env:USERPROFILE "Desktop\Ruki_Original_Power_Scheme.txt"

function Enable-NoSleep {
    $TxtLog.AppendText("Initializing Sleep Prevention...`r`n")
    try {
        # 1. Get Current Scheme
        $CurrentSchemeLine = powercfg /getactivescheme
        # Extract GUID (Simple regex or split)
        # Format: Power Scheme GUID: 381b4222-f694-41f0-9685-ff5bb260df2e  (Balanced)
        if ($CurrentSchemeLine -match "GUID:\s+([a-f0-9\-]+)") {
            $OriginalGuid = $matches[1]
            
            # Save if not already saved (don't overwrite original if running twice)
            if (-not (Test-Path $PowerBackupFile)) {
                $OriginalGuid | Out-File $PowerBackupFile -Encoding UTF8
                $TxtLog.AppendText("Original Power Scheme saved: $OriginalGuid`r`n")
            }
            
            # 2. Duplicate Scheme
            # powercfg -duplicatescheme <GUID> <DEST_GUID> (optional)
            # captures the output to get new guid
            $DupOutput = powercfg -duplicatescheme $OriginalGuid
            if ($DupOutput -match "GUID:\s+([a-f0-9\-]+)") {
                $NewScheme = $matches[1]
                
                # 3. Rename and Activate
                powercfg -changename $NewScheme "RukiTech Diagnostic Mode"
                powercfg -setactive $NewScheme
                
                # 4. Disable Sleep/Monitor Timeout (AC and DC)
                powercfg -change -monitor-timeout-ac 0
                powercfg -change -monitor-timeout-dc 0
                powercfg -change -disk-timeout-ac 0
                powercfg -change -disk-timeout-dc 0
                powercfg -change -standby-timeout-ac 0
                powercfg -change -standby-timeout-dc 0
                powercfg -change -hibernate-timeout-ac 0
                powercfg -change -hibernate-timeout-dc 0
                
                $TxtLog.AppendText("Active Power Plan changed to 'RukiTech Diagnostic Mode' (No Sleep).`r`n")
            }
        }
    } catch {
        $TxtLog.AppendText("Error setting power plan: $_`r`n")
    }
}

function Restore-Power {
    if (Test-Path $PowerBackupFile) {
        try {
            $OriginalGuid = Get-Content $PowerBackupFile -Raw
            $OriginalGuid = $OriginalGuid.Trim()
            
            $TxtLog.AppendText("Restoring Power Scheme to: $OriginalGuid...`r`n")
            
            powercfg -setactive $OriginalGuid
            
            # Identify the temp scheme to delete
            $List = powercfg /list
            # We can't easily parse list to find GUID by name in PS 5.1 cleanly without regex, 
            # but we can try to find the one we just left? 
            # Actually, user might have just switched. 
            # Simple cleanup: Find any scheme named "RukiTech Diagnostic Mode" and delete it.
            
            # We will just leave it inactive or try to delete current if it was Ruki
            # Re-reading list is complex. For now, just activating original is sufficient validation.
            
            Remove-Item $PowerBackupFile -Force
            $TxtLog.AppendText("Power settings restored successfully!`r`n")
            [System.Windows.Forms.MessageBox]::Show("Power settings have been restored.", "Success", "OK", "Information")
        } catch {
            $TxtLog.AppendText("Error restoring power settings: $_`r`n")
            [System.Windows.Forms.MessageBox]::Show("Failed to restore settings. Please check manually.", "Error", "OK", "Error")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("No backup found. Settings might be already original.", "Info", "OK", "Information")
    }
}

$BtnRestore.Add_Click({
    Restore-Power
})

$Timer.Add_Tick({
    if ($Script:CurrentLogFile -and (Test-Path $Script:CurrentLogFile)) {
        try {
            # Read last lines efficiently - in real implementation stream reader is better but Get-Content -Tail is okay for GUI
            $Content = Get-Content $Script:CurrentLogFile -Tail 20 -Encoding UTF8
            $TxtLog.Text = ($Content -join "`r`n")
            $TxtLog.SelectionStart = $TxtLog.Text.Length
            $TxtLog.ScrollToCaret()
        } catch {}
    }
})

$BtnStart.Add_Click({
    $BtnStart.Enabled = $false
    $GrpOptions.Enabled = $false
    $GrpOutput.Enabled = $false
    $BtnRestore.Enabled = $false
    
    # Handle Sleep Prevention
    if ($ChkNoSleep.Checked) {
        Enable-NoSleep
    }
    
    $LogDir = Join-Path $TxtPath.Text ("RukiCollect_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
    # We predict the log file path based on Collect_Main logic.
    
    $ArgsList = @(
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $PSScriptRoot "Collect_Main.ps1"),
        "-OutputDir", $TxtPath.Text,
        "-Days", $NumDays.Value
    )
    
    if ($ChkEvents.Checked) { $ArgsList += "-Opt_EventLogs" }
    if ($ChkSysInfo.Checked) { $ArgsList += "-Opt_SystemInfo" }
    if ($ChkDrivers.Checked) { $ArgsList += "-Opt_DriverAppList" }
    if ($ChkMinidump.Checked) { $ArgsList += "-Opt_Minidump" }
    if ($ChkMemDmp.Checked) { $ArgsList += "-Opt_MemoryDmp" }
    if ($ChkEnergy.Checked) { $ArgsList += "-Opt_EnergyReport" }
    if ($ChkBattery.Checked) { $ArgsList += "-Opt_BatteryReport" }
    if ($ChkZip.Checked) { $ArgsList += "-Opt_Zip" }
    if ($ChkResume.Checked) { $ArgsList += "-Opt_AutoResume" }
    
    $TxtLog.AppendText("Starting Collection Process... Please wait...`r`n")
    $Script:StartTime = Get-Date

    try {
        Start-Process "powershell.exe" -ArgumentList $ArgsList -WindowStyle Minimized
        
        $Timer.Start()
        
        # Poll for the newest log file in the output directory
        $Job = Register-ObjectEvent -InputObject $Timer -EventName Tick -Action {
            if (-not $Global:FoundLog) {
                # Only look for folders created roughly slightly before or after we clicked start to avoid picking up old logical folders
                $LatestDir = Get-ChildItem $TxtPath.Text -Directory | 
                    Where-Object { $_.CreationTime -ge $Script:StartTime.AddSeconds(-15) } | 
                    Sort-Object CreationTime -Descending | 
                    Select-Object -First 1

                if ($LatestDir) {
                    $LogC = Join-Path $LatestDir.FullName "run.log"
                    if (Test-Path $LogC) {
                        $Script:CurrentLogFile = $LogC
                        $Global:FoundLog = $true
                    }
                }
            }
        }
    } catch {
        $TxtLog.Text = "Failed to start process: $_"
        $BtnStart.Enabled = $true
        $BtnRestore.Enabled = $true
    }
})

$Form.ShowDialog()
