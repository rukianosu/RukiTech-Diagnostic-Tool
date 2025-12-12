#Requires -RunAsAdministrator
<#
.SYNOPSIS
    DELL Inspiron 5515 診断ツール - メイン監視スクリプト
.DESCRIPTION
    システムの安定性を監視し、30秒ごとにログを記録し、異常検知時にDiscord通知を送信
.AUTHOR
    RukiTech
#>

# ========== 設定セクション ==========
$DiscordWebhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE"  # ここにDiscord Webhook URLを設定してください

# グローバル変数
$script:LogFolder = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "PC_Diagnostic_Logs")
$script:LogFile = Join-Path $LogFolder "SystemLog_$(Get-Date -Format 'yyyyMMdd').csv"
$script:LastKernelPowerEvent = $null
$script:LastWHEAEvent = $null
$script:KnownDumpFiles = @()

# ========== 初期化 ==========
Write-Host "=== RukiTech Diagnostic Tool ===" -ForegroundColor Cyan
Write-Host "起動日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green

# ログフォルダ作成
if (-not (Test-Path $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
    Write-Host "ログフォルダを作成しました: $LogFolder" -ForegroundColor Green
}

# ========== 関数定義 ==========

# Discord通知関数
function Send-DiscordNotification {
    param(
        [string]$Message,
        [string]$Title = "🔴 RukiTech 診断アラート"
    )

    if ([string]::IsNullOrWhiteSpace($DiscordWebhookURL) -or $DiscordWebhookURL -eq "YOUR_DISCORD_WEBHOOK_URL_HERE") {
        Write-Warning "Discord Webhook URLが設定されていません。ローカルログのみ記録します。"
        Save-CriticalEvent -EventMessage $Message -EventTitle $Title
        return
    }

    try {
        $payload = @{
            embeds = @(
                @{
                    title = $Title
                    description = $Message
                    color = 16711680  # 赤色
                    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    footer = @{
                        text = "DELL Inspiron 5515 診断ツール"
                    }
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $DiscordWebhookURL -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 10
        Write-Host "Discord通知送信成功: $Title" -ForegroundColor Green
    }
    catch {
        Write-Warning "Discord通知送信失敗: $_"
        # 警告音を鳴らす
        [System.Console]::Beep(1000, 500)
        Start-Sleep -Milliseconds 200
        [System.Console]::Beep(1000, 500)

        # ローカル緊急ログファイルに記録
        Save-CriticalEvent -EventMessage $Message -EventTitle $Title
    }
}

# 緊急イベントのローカル保存
function Save-CriticalEvent {
    param(
        [string]$EventMessage,
        [string]$EventTitle
    )

    $criticalLogFile = Join-Path $LogFolder "CRITICAL_EVENT_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $content = @"
=====================================================
$EventTitle
=====================================================
日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
$EventMessage
=====================================================
"@

    try {
        $content | Out-File -FilePath $criticalLogFile -Encoding UTF8 -Force
        Write-Host "緊急ログファイルを作成: $criticalLogFile" -ForegroundColor Yellow
    }
    catch {
        Write-Error "緊急ログファイルの作成に失敗: $_"
    }
}

# ドライババージョン情報の収集（初回のみ）
function Collect-DriverVersions {
    $driverInfoFile = Join-Path $LogFolder "Driver_Versions.txt"

    if (Test-Path $driverInfoFile) {
        Write-Host "ドライババージョン情報は既に収集済みです。" -ForegroundColor Gray
        return
    }

    Write-Host "ドライババージョン情報を収集中..." -ForegroundColor Cyan

    $info = @"
==========================================================
DELL Inspiron 5515 ドライババージョン情報
収集日時: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
==========================================================

【BIOS情報】
"@

    try {
        $bios = Get-CimInstance -ClassName Win32_BIOS
        $info += "`nBIOS Version: $($bios.SMBIOSBIOSVersion)"
        $info += "`nBIOS Date: $($bios.ReleaseDate)"
    }
    catch {
        $info += "`nBIOS情報の取得に失敗"
    }

    $info += "`n`n【主要ドライバ】`n"

    # グラフィックスドライバ
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" }
        if ($gpu) {
            $info += "`nGPU: $($gpu.Name)"
            $info += "`nDriver Version: $($gpu.DriverVersion)"
            $info += "`nDriver Date: $($gpu.DriverDate)"
        }
    }
    catch {
        $info += "`nGPUドライバ情報の取得に失敗"
    }

    # ネットワークアダプタ
    try {
        $network = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true -and $_.PhysicalAdapter -eq $true }
        foreach ($adapter in $network) {
            $info += "`n`nNetwork Adapter: $($adapter.Name)"
            $info += "`nDriver Version: $($adapter.DriverVersion)"
        }
    }
    catch {
        $info += "`n`nネットワークドライバ情報の取得に失敗"
    }

    # オーディオドライバ
    try {
        $audio = Get-CimInstance -ClassName Win32_SoundDevice
        foreach ($device in $audio) {
            $info += "`n`nAudio Device: $($device.Name)"
        }
    }
    catch {
        $info += "`n`nオーディオドライバ情報の取得に失敗"
    }

    # チップセット情報
    try {
        $baseBoard = Get-CimInstance -ClassName Win32_BaseBoard
        $info += "`n`n【マザーボード】"
        $info += "`nManufacturer: $($baseBoard.Manufacturer)"
        $info += "`nProduct: $($baseBoard.Product)"
        $info += "`nVersion: $($baseBoard.Version)"
    }
    catch {
        $info += "`n`nマザーボード情報の取得に失敗"
    }

    $info += "`n`n=========================================================="

    try {
        $info | Out-File -FilePath $driverInfoFile -Encoding UTF8 -Force
        Write-Host "ドライババージョン情報を保存しました: $driverInfoFile" -ForegroundColor Green
    }
    catch {
        Write-Error "ドライババージョン情報の保存に失敗: $_"
    }
}

# システム情報の収集
function Get-SystemMetrics {
    $metrics = [PSCustomObject]@{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        CPU_Temp_C = "N/A"
        GPU_Temp_C = "N/A"
        CPU_Usage_Percent = 0
        CPU_Clock_MHz = 0
        Memory_Usage_Percent = 0
        PageFile_Usage_MB = 0
        Storage_HealthStatus = "Unknown"
        Storage_OperationalStatus = "Unknown"
        GPU_CoreClock_MHz = "N/A"
        GPU_MemoryUsage_Percent = "N/A"
        PowerSource = "Unknown"
    }

    # CPU使用率
    try {
        $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
        $metrics.CPU_Usage_Percent = [math]::Round($cpuCounter.CounterSamples[0].CookedValue, 2)
    }
    catch {
        Write-Verbose "CPU使用率の取得に失敗"
    }

    # CPUクロック周波数
    try {
        $cpuInfo = Get-CimInstance -ClassName Win32_Processor
        $metrics.CPU_Clock_MHz = $cpuInfo.CurrentClockSpeed
    }
    catch {
        Write-Verbose "CPUクロックの取得に失敗"
    }

    # CPU温度（WMI経由、一部のシステムでのみ動作）
    try {
        $temp = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
        if ($temp) {
            $tempC = ($temp.CurrentTemperature / 10) - 273.15
            $metrics.CPU_Temp_C = [math]::Round($tempC, 1)

            # 高温アラート
            if ($tempC -gt 90) {
                Send-DiscordNotification -Message "⚠️ **CPU温度が危険レベルに達しました！**`n現在温度: **$([math]::Round($tempC, 1))℃**`n時刻: $(Get-Date -Format 'HH:mm:ss')" -Title "🌡️ 高温警告"
            }
        }
    }
    catch {
        Write-Verbose "CPU温度の取得に失敗"
    }

    # メモリ使用率
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem
        $totalMem = $os.TotalVisibleMemorySize
        $freeMem = $os.FreePhysicalMemory
        $usedMemPercent = (($totalMem - $freeMem) / $totalMem) * 100
        $metrics.Memory_Usage_Percent = [math]::Round($usedMemPercent, 2)
    }
    catch {
        Write-Verbose "メモリ使用率の取得に失敗"
    }

    # ページファイル使用量（コミットチャージ）
    try {
        $pageFileCounter = Get-Counter '\Memory\Committed Bytes' -ErrorAction SilentlyContinue
        $metrics.PageFile_Usage_MB = [math]::Round($pageFileCounter.CounterSamples[0].CookedValue / 1MB, 2)
    }
    catch {
        Write-Verbose "ページファイル使用量の取得に失敗"
    }

    # ストレージS.M.A.R.T.情報
    try {
        $disk = Get-PhysicalDisk | Where-Object { $_.MediaType -eq "SSD" -or $_.MediaType -eq "HDD" } | Select-Object -First 1
        if ($disk) {
            $metrics.Storage_HealthStatus = $disk.HealthStatus
            $metrics.Storage_OperationalStatus = $disk.OperationalStatus
        }
    }
    catch {
        Write-Verbose "ストレージS.M.A.R.T.情報の取得に失敗"
    }

    # GPU情報（AMD Radeonの場合、WMI経由での詳細情報取得は限定的）
    try {
        $gpu = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -like "*AMD*" -or $_.Name -like "*Radeon*" } | Select-Object -First 1
        if ($gpu) {
            # GPU温度は直接取得困難。OpenHardwareMonitor等のサードパーティツールが必要
            # ここでは基本情報のみ取得
            $metrics.GPU_Temp_C = "Requires 3rd party tool"
            $metrics.GPU_CoreClock_MHz = "Requires 3rd party tool"
            $metrics.GPU_MemoryUsage_Percent = "Requires 3rd party tool"
        }
    }
    catch {
        Write-Verbose "GPU情報の取得に失敗"
    }

    # 電源ソース
    try {
        $battery = Get-CimInstance -ClassName Win32_Battery
        if ($battery) {
            $batteryStatus = $battery.BatteryStatus
            # BatteryStatus: 1=Discharging, 2=AC, 3=Fully Charged, 4=Low, 5=Critical
            if ($batteryStatus -eq 2 -or $batteryStatus -eq 3) {
                $metrics.PowerSource = "AC"
            }
            else {
                $metrics.PowerSource = "Battery"
            }
        }
        else {
            $metrics.PowerSource = "AC (Desktop)"
        }
    }
    catch {
        Write-Verbose "電源ソース情報の取得に失敗"
        $metrics.PowerSource = "Unknown"
    }

    return $metrics
}

# CSVログの書き込み（ファイルを即座に閉じる）
function Write-LogEntry {
    param(
        [PSCustomObject]$Metrics
    )

    # ヘッダー確認
    $headerExists = Test-Path $script:LogFile

    try {
        # ファイルストリームを開いて書き込み、即座に閉じる
        if (-not $headerExists) {
            # ヘッダー作成
            $header = "Timestamp,CPU_Temp_C,GPU_Temp_C,CPU_Usage_Percent,CPU_Clock_MHz,Memory_Usage_Percent,PageFile_Usage_MB,Storage_HealthStatus,Storage_OperationalStatus,GPU_CoreClock_MHz,GPU_MemoryUsage_Percent,PowerSource"
            $streamWriter = [System.IO.StreamWriter]::new($script:LogFile, $false, [System.Text.Encoding]::UTF8)
            $streamWriter.WriteLine($header)
            $streamWriter.Close()
            $streamWriter.Dispose()
        }

        # データ行の作成
        $line = "$($Metrics.Timestamp),$($Metrics.CPU_Temp_C),$($Metrics.GPU_Temp_C),$($Metrics.CPU_Usage_Percent),$($Metrics.CPU_Clock_MHz),$($Metrics.Memory_Usage_Percent),$($Metrics.PageFile_Usage_MB),$($Metrics.Storage_HealthStatus),$($Metrics.Storage_OperationalStatus),$($Metrics.GPU_CoreClock_MHz),$($Metrics.GPU_MemoryUsage_Percent),$($Metrics.PowerSource)"

        # 追記モードで書き込み、即座に閉じる
        $streamWriter = [System.IO.StreamWriter]::new($script:LogFile, $true, [System.Text.Encoding]::UTF8)
        $streamWriter.WriteLine($line)
        $streamWriter.Close()
        $streamWriter.Dispose()

        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ログ記録完了 | CPU: $($Metrics.CPU_Usage_Percent)% | Temp: $($Metrics.CPU_Temp_C)℃ | Mem: $($Metrics.Memory_Usage_Percent)%" -ForegroundColor Gray
    }
    catch {
        Write-Error "ログ書き込みエラー: $_"
    }
}

# イベントログ監視（Kernel-Power 41）
function Check-KernelPowerEvents {
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; Id=41; ProviderName='Microsoft-Windows-Kernel-Power'} -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($events) {
            $latestEvent = $events[0]
            if ($script:LastKernelPowerEvent -eq $null -or $latestEvent.TimeCreated -gt $script:LastKernelPowerEvent) {
                $script:LastKernelPowerEvent = $latestEvent.TimeCreated

                $message = "**Kernel-Power イベント 41 検知**`n不正なシャットダウンが発生しました。`n時刻: $($latestEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))"
                Send-DiscordNotification -Message $message -Title "⚠️ システム不正終了検知"
            }
        }
    }
    catch {
        Write-Verbose "Kernel-Powerイベントの確認中にエラー: $_"
    }
}

# イベントログ監視（WHEA-Logger）
function Check-WHEAEvents {
    try {
        $events = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'} -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($events) {
            $latestEvent = $events[0]
            if ($script:LastWHEAEvent -eq $null -or $latestEvent.TimeCreated -gt $script:LastWHEAEvent) {
                $script:LastWHEAEvent = $latestEvent.TimeCreated

                $message = "**WHEA-Logger ハードウェアエラー検知**`n時刻: $($latestEvent.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))`nイベントID: $($latestEvent.Id)`nメッセージ: $($latestEvent.Message)"
                Send-DiscordNotification -Message $message -Title "🔧 ハードウェアエラー検知"
            }
        }
    }
    catch {
        Write-Verbose "WHEA-Loggerイベントの確認中にエラー: $_"
    }
}

# ミニダンプファイル監視
function Check-MiniDumpFiles {
    $dumpPaths = @(
        "$env:SystemRoot\Minidump",
        "$env:SystemRoot\MEMORY.DMP"
    )

    foreach ($path in $dumpPaths) {
        if (Test-Path $path) {
            if ((Get-Item $path).PSIsContainer) {
                # ディレクトリの場合
                $dumpFiles = Get-ChildItem -Path $path -Filter "*.dmp" -ErrorAction SilentlyContinue

                foreach ($file in $dumpFiles) {
                    if ($script:KnownDumpFiles -notcontains $file.FullName) {
                        $script:KnownDumpFiles += $file.FullName

                        $message = "**新しいミニダンプファイルが検知されました**`nファイル名: $($file.Name)`nパス: $($file.FullName)`n作成日時: $($file.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))`nサイズ: $([math]::Round($file.Length / 1KB, 2)) KB"
                        Send-DiscordNotification -Message $message -Title "💥 クラッシュダンプ検知"
                    }
                }
            }
            else {
                # ファイルの場合（MEMORY.DMP）
                if ($script:KnownDumpFiles -notcontains $path) {
                    $file = Get-Item $path
                    $script:KnownDumpFiles += $path

                    $message = "**新しいメモリダンプファイルが検知されました**`nファイル名: $($file.Name)`nパス: $($file.FullName)`n作成日時: $($file.CreationTime.ToString('yyyy-MM-dd HH:mm:ss'))`nサイズ: $([math]::Round($file.Length / 1MB, 2)) MB"
                    Send-DiscordNotification -Message $message -Title "💥 フルメモリダンプ検知"
                }
            }
        }
    }
}

# 既存のダンプファイルを初期リストに追加（起動時のみ）
function Initialize-DumpFileTracking {
    $dumpPaths = @(
        "$env:SystemRoot\Minidump",
        "$env:SystemRoot\MEMORY.DMP"
    )

    foreach ($path in $dumpPaths) {
        if (Test-Path $path) {
            if ((Get-Item $path).PSIsContainer) {
                $dumpFiles = Get-ChildItem -Path $path -Filter "*.dmp" -ErrorAction SilentlyContinue
                foreach ($file in $dumpFiles) {
                    $script:KnownDumpFiles += $file.FullName
                }
            }
            else {
                $script:KnownDumpFiles += $path
            }
        }
    }

    Write-Host "既存のダンプファイル $($script:KnownDumpFiles.Count) 件を追跡リストに登録しました。" -ForegroundColor Cyan
}

# ========== メイン処理 ==========

# 初期情報収集
Collect-DriverVersions

# ダンプファイル追跡の初期化
Initialize-DumpFileTracking

Write-Host "`n監視を開始します。30秒ごとにログを記録します..." -ForegroundColor Green
Write-Host "停止するには Stop_Monitor.ps1 を実行してください。`n" -ForegroundColor Yellow

# メインループ
while ($true) {
    try {
        # システムメトリクスの収集
        $metrics = Get-SystemMetrics

        # ログ記録
        Write-LogEntry -Metrics $metrics

        # イベントログ監視
        Check-KernelPowerEvents
        Check-WHEAEvents

        # ミニダンプファイル監視
        Check-MiniDumpFiles

        # 30秒待機
        Start-Sleep -Seconds 30
    }
    catch {
        Write-Error "メインループでエラーが発生: $_"
        Start-Sleep -Seconds 30
    }
}
