#Requires -RunAsAdministrator
<#
.SYNOPSIS
    監視停止・タスク削除スクリプト
.DESCRIPTION
    実行中のDiagnostic_Main.ps1プロセスを停止し、タスクスケジューラからタスクを削除します
.AUTHOR
    RukiTech
#>

Write-Host "=== RukiTech 診断ツール - 監視停止 ===" -ForegroundColor Cyan

$TaskName = "RukiTech_Monitor"
$ProcessStopped = $false
$TaskRemoved = $false

# 実行中のDiagnostic_Main.ps1プロセスを検索して停止
Write-Host "`n[1] 実行中のプロセスを検索中..." -ForegroundColor Yellow

try {
    # PowerShellプロセスの中からDiagnostic_Main.ps1を実行しているものを検索
    $processes = Get-WmiObject Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | ForEach-Object {
        $commandLine = $_.CommandLine
        if ($commandLine -like "*Diagnostic_Main.ps1*") {
            [PSCustomObject]@{
                ProcessId = $_.ProcessId
                CommandLine = $commandLine
            }
        }
    }

    if ($processes) {
        Write-Host "実行中のプロセスが見つかりました：" -ForegroundColor Green
        foreach ($proc in $processes) {
            Write-Host "  PID: $($proc.ProcessId)" -ForegroundColor White
            try {
                Stop-Process -Id $proc.ProcessId -Force
                Write-Host "  ✓ プロセス $($proc.ProcessId) を停止しました。" -ForegroundColor Green
                $ProcessStopped = $true
            }
            catch {
                Write-Warning "  プロセス $($proc.ProcessId) の停止に失敗: $_"
            }
        }
    }
    else {
        Write-Host "実行中のプロセスは見つかりませんでした。" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "プロセス検索中にエラーが発生: $_"
}

# タスクスケジューラからタスクを削除
Write-Host "`n[2] タスクスケジューラからタスクを削除中..." -ForegroundColor Yellow

try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    if ($task) {
        # タスクが実行中の場合は停止
        if ($task.State -eq 'Running') {
            Write-Host "タスクが実行中です。停止しています..." -ForegroundColor Yellow
            Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }

        # タスクを削除
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "✓ タスク '$TaskName' を削除しました。" -ForegroundColor Green
        $TaskRemoved = $true
    }
    else {
        Write-Host "タスク '$TaskName' は登録されていません。" -ForegroundColor Gray
    }
}
catch {
    Write-Warning "タスク削除中にエラーが発生: $_"
}

# 結果サマリー
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "処理結果サマリー" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($ProcessStopped) {
    Write-Host "✓ 実行中のプロセスを停止しました" -ForegroundColor Green
}
else {
    Write-Host "- 停止すべきプロセスはありませんでした" -ForegroundColor Gray
}

if ($TaskRemoved) {
    Write-Host "✓ タスクスケジューラからタスクを削除しました" -ForegroundColor Green
}
else {
    Write-Host "- 削除すべきタスクはありませんでした" -ForegroundColor Gray
}

Write-Host "`n監視が完全に停止しました。" -ForegroundColor Green
Write-Host "再度監視を開始するには Setup_Task.ps1 を実行してください。" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

Read-Host "Enterキーを押して終了"
