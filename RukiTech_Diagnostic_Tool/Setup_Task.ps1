#Requires -RunAsAdministrator
<#
.SYNOPSIS
    タスクスケジューラ登録スクリプト
.DESCRIPTION
    Diagnostic_Main.ps1をPC起動時に自動実行するようタスクスケジューラに登録します
.AUTHOR
    RukiTech
#>

Write-Host "=== RukiTech 診断ツール - タスク登録 ===" -ForegroundColor Cyan

# スクリプトの場所を取得
$ScriptPath = $PSScriptRoot
$MainScriptPath = Join-Path $ScriptPath "Diagnostic_Main.ps1"

# メインスクリプトの存在確認
if (-not (Test-Path $MainScriptPath)) {
    Write-Error "Diagnostic_Main.ps1 が見つかりません: $MainScriptPath"
    Write-Host "このスクリプトは RukiTech_Diagnostic_Tool フォルダ内から実行してください。" -ForegroundColor Yellow
    Read-Host "Enterキーを押して終了"
    exit 1
}

# タスク名
$TaskName = "RukiTech_Monitor"

# 既存のタスクを確認
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($ExistingTask) {
    Write-Host "既存のタスク '$TaskName' が見つかりました。" -ForegroundColor Yellow
    $response = Read-Host "既存のタスクを削除して再登録しますか？ (Y/N)"

    if ($response -eq 'Y' -or $response -eq 'y') {
        try {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-Host "既存のタスクを削除しました。" -ForegroundColor Green
        }
        catch {
            Write-Error "既存のタスクの削除に失敗: $_"
            Read-Host "Enterキーを押して終了"
            exit 1
        }
    }
    else {
        Write-Host "タスク登録をキャンセルしました。" -ForegroundColor Yellow
        Read-Host "Enterキーを押して終了"
        exit 0
    }
}

# タスクアクションの作成（PowerShellでスクリプトを実行）
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$MainScriptPath`""

# トリガーの作成（PC起動時）
$Trigger = New-ScheduledTaskTrigger -AtStartup

# プリンシパルの作成（最高権限で実行）
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# タスク設定の作成
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit (New-TimeSpan -Days 0)  # 無制限

# タスクの登録
try {
    Register-ScheduledTask -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Description "RukiTech DELL Inspiron 5515 診断ツール - システム監視とログ記録" `
        -Force

    Write-Host "`n✓ タスク '$TaskName' の登録に成功しました！" -ForegroundColor Green
    Write-Host "`n【タスク詳細】" -ForegroundColor Cyan
    Write-Host "  タスク名: $TaskName"
    Write-Host "  実行スクリプト: $MainScriptPath"
    Write-Host "  トリガー: PC起動時"
    Write-Host "  実行権限: SYSTEM（最高権限）"
    Write-Host "  バッテリー動作: 許可"
    Write-Host "`n次回のPC起動時から診断ツールが自動的に開始されます。" -ForegroundColor Green
    Write-Host "すぐに開始したい場合は、以下のコマンドを実行してください：" -ForegroundColor Yellow
    Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
}
catch {
    Write-Error "タスクの登録に失敗: $_"
    Read-Host "Enterキーを押して終了"
    exit 1
}

Write-Host "`n登録完了！" -ForegroundColor Green
Read-Host "Enterキーを押して終了"
