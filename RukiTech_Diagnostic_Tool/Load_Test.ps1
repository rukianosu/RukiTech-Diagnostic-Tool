<#
.SYNOPSIS
    CPU負荷テストスクリプト
.DESCRIPTION
    CPU負荷を継続的に90%以上に保つストレステストを実行します
    Ctrl+C で停止可能
.AUTHOR
    RukiTech
#>

Write-Host "=== RukiTech CPU 負荷テスト ===" -ForegroundColor Cyan
Write-Host "このスクリプトはCPU負荷を高めるストレステストを実行します。" -ForegroundColor Yellow
Write-Host "システムの安定性を確認するために使用してください。" -ForegroundColor Yellow
Write-Host "`n警告: 長時間の実行はシステムに負荷をかけます。" -ForegroundColor Red
Write-Host "温度監視を行いながら実行することを推奨します。" -ForegroundColor Red

# 確認
$confirmation = Read-Host "`n負荷テストを開始しますか？ (Y/N)"
if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
    Write-Host "負荷テストをキャンセルしました。" -ForegroundColor Yellow
    exit 0
}

# CPU論理プロセッサ数を取得
$processorCount = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
Write-Host "`n検出されたCPU論理プロセッサ数: $processorCount" -ForegroundColor Cyan

# 使用するスレッド数（全論理プロセッサ）
$threadCount = $processorCount
Write-Host "使用するスレッド数: $threadCount" -ForegroundColor Cyan

Write-Host "`n負荷テストを開始します..." -ForegroundColor Green
Write-Host "停止するには Ctrl+C を押してください。`n" -ForegroundColor Yellow

# ジョブのリスト
$jobs = @()

# クリーンアップ関数
$cleanupScript = {
    param($jobList)
    Write-Host "`n`n負荷テストを停止しています..." -ForegroundColor Yellow
    foreach ($job in $jobList) {
        if ($job.State -eq 'Running') {
            Stop-Job -Job $job
        }
        Remove-Job -Job $job -Force
    }
    Write-Host "すべてのジョブを停止しました。" -ForegroundColor Green
}

# Ctrl+C ハンドラ登録
$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    & $cleanupScript $jobs
}

try {
    # 各スレッドでCPU負荷を生成
    for ($i = 1; $i -le $threadCount; $i++) {
        $job = Start-Job -ScriptBlock {
            $result = 1
            while ($true) {
                # 数学演算で負荷を生成
                1..10000 | ForEach-Object {
                    $result = [Math]::Sqrt($_) * [Math]::Sqrt($_)
                    $result = [Math]::Pow($_, 2)
                    $result = [Math]::Sin($_) * [Math]::Cos($_)
                }
            }
        }
        $jobs += $job
        Write-Host "スレッド $i/$threadCount を開始しました（JobID: $($job.Id)）" -ForegroundColor Gray
    }

    Write-Host "`n全スレッドが起動しました。CPU負荷テスト実行中..." -ForegroundColor Green
    Write-Host "現在のCPU使用率を監視します（5秒ごとに更新）`n" -ForegroundColor Cyan

    # CPU使用率の監視ループ
    $iteration = 0
    while ($true) {
        Start-Sleep -Seconds 5
        $iteration++

        try {
            # CPU使用率を取得
            $cpuUsage = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
            $cpuPercent = [math]::Round($cpuUsage.CounterSamples[0].CookedValue, 1)

            # CPU温度を取得（可能な場合）
            $tempString = "N/A"
            try {
                $temp = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
                if ($temp) {
                    $tempC = [math]::Round(($temp.CurrentTemperature / 10) - 273.15, 1)
                    $tempString = "$tempC℃"

                    # 高温警告
                    if ($tempC -gt 90) {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⚠️  警告: CPU温度が $tempC℃ に達しました！テスト停止を推奨します！" -ForegroundColor Red
                    }
                    elseif ($tempC -gt 85) {
                        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⚠️  注意: CPU温度が $tempC℃ です" -ForegroundColor Yellow
                    }
                }
            }
            catch {
                # 温度取得失敗時は無視
            }

            # ステータス表示
            $statusColor = "Green"
            if ($cpuPercent -lt 80) {
                $statusColor = "Yellow"
            }

            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] CPU使用率: $cpuPercent% | 温度: $tempString | 経過: $($iteration * 5)秒" -ForegroundColor $statusColor
        }
        catch {
            Write-Host "[$(Get-Date -Format 'HH:mm:ss')] CPU使用率の取得に失敗" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "`nエラーが発生しました: $_" -ForegroundColor Red
}
finally {
    # クリーンアップ
    Write-Host "`n負荷テストを終了しています..." -ForegroundColor Yellow

    foreach ($job in $jobs) {
        if ($job.State -eq 'Running') {
            Stop-Job -Job $job
        }
        Remove-Job -Job $job -Force
    }

    Write-Host "✓ すべてのジョブを停止しました。" -ForegroundColor Green
    Write-Host "`nCPU負荷テストが終了しました。" -ForegroundColor Cyan

    # イベント登録解除
    Unregister-Event -SourceIdentifier PowerShell.Exiting -ErrorAction SilentlyContinue

    Read-Host "`nEnterキーを押して終了"
}
