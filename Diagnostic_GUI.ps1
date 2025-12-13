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
    
    $TxtLog.Text = "Starting Collection Process... Please wait..."
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
    }
})

$Form.ShowDialog()
