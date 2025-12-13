#Requires -RunAsAdministrator
<#
.SYNOPSIS
    RukiTech 診断ツール - メニューランチャー
.DESCRIPTION
    診断ツールの各機能を簡単に実行できるメニューインターフェース
.VERSION
    1.0 - 初版リリース (2025-12-13)
.AUTHOR
    RukiTech
#>

# スクリプトの場所を取得
$ScriptPath = $PSScriptRoot
$TaskName = "RukiTech_Monitor"

# 色の定義
$ColorTitle = "Cyan"
$ColorMenu = "White"
$ColorSuccess = "Green"
$ColorWarning = "Yellow"
$ColorError = "Red"

# ログフォルダのパス
$LogFolder = [System.IO.Path]::Combine([Environment]::GetFolderPath("Desktop"), "PC_Diagnostic_Logs")

# メニュー表示関数
function Show-Menu {
    Clear-Host
    Write-Host "========================================" -ForegroundColor $ColorTitle
    Write-Host "  RukiTech 診断ツール - メニュー" -ForegroundColor $ColorTitle
    Write-Host "  DELL Inspiron 5515 診断システム" -ForegroundColor $ColorTitle
    Write-Host "========================================" -ForegroundColor $ColorTitle
    Write-Host ""

    # タスクの状態を取得
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        $taskState = $task.State
        $stateColor = switch ($taskState) {
            "Running" { $ColorSuccess }
            "Ready" { $ColorWarning }
            default { $ColorError }
        }
        Write-Host "現在のタスク状態: " -NoNewline
        Write-Host $taskState -ForegroundColor $stateColor
    }
    else {
        Write-Host "現在のタスク状態: " -NoNewline
        Write-Host "未登録" -ForegroundColor $ColorError
    }

    # ログフォルダの存在確認
    if (Test-Path $LogFolder) {
        $logFiles = Get-ChildItem -Path $LogFolder -Filter "*.csv" -ErrorAction SilentlyContinue
        Write-Host "ログファイル数: " -NoNewline
        Write-Host $logFiles.Count -ForegroundColor $ColorSuccess
    }
    else {
        Write-Host "ログフォルダ: " -NoNewline
        Write-Host "未作成" -ForegroundColor $ColorWarning
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor $ColorTitle
    Write-Host ""

    Write-Host " [1] タスク登録（初回セットアップ）" -ForegroundColor $ColorMenu
    Write-Host " [2] 監視開始（タスク起動）" -ForegroundColor $ColorMenu
    Write-Host " [3] 監視停止（タスク停止）" -ForegroundColor $ColorMenu
    Write-Host " [4] タスク削除（完全削除）" -ForegroundColor $ColorMenu
    Write-Host ""
    Write-Host " [5] 診断スクリプトを直接実行（デバッグ用）" -ForegroundColor $ColorMenu
    Write-Host " [6] CPU負荷テスト実行" -ForegroundColor $ColorMenu
    Write-Host ""
    Write-Host " [7] ログフォルダを開く" -ForegroundColor $ColorMenu
    Write-Host " [8] タスク詳細情報を表示" -ForegroundColor $ColorMenu
    Write-Host " [9] ファイルのブロック解除" -ForegroundColor $ColorMenu
    Write-Host ""
    Write-Host " [0] 終了" -ForegroundColor $ColorWarning
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $ColorTitle
}

# タスク登録
function Register-DiagnosticTask {
    Write-Host "`n[タスク登録を実行します...]" -ForegroundColor $ColorTitle
    & "$ScriptPath\Setup_Task.ps1"
}

# 監視開始
function Start-Monitoring {
    Write-Host "`n[監視を開始します...]" -ForegroundColor $ColorTitle
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Host "エラー: タスクが登録されていません。先にタスク登録を実行してください。" -ForegroundColor $ColorError
            return
        }

        Start-ScheduledTask -TaskName $TaskName
        Write-Host "✓ タスク '$TaskName' を開始しました。" -ForegroundColor $ColorSuccess
        Write-Host "30秒後にログフォルダが作成されます..." -ForegroundColor $ColorWarning

        # 30秒待機してログフォルダを確認
        Start-Sleep -Seconds 5
        for ($i = 30; $i -ge 0; $i -= 5) {
            Write-Host "  残り $i 秒..." -ForegroundColor $ColorWarning
            Start-Sleep -Seconds 5
        }

        if (Test-Path $LogFolder) {
            Write-Host "✓ ログフォルダが作成されました！" -ForegroundColor $ColorSuccess
            Write-Host "  場所: $LogFolder" -ForegroundColor $ColorSuccess
        }
        else {
            Write-Host "警告: ログフォルダがまだ作成されていません。" -ForegroundColor $ColorWarning
            Write-Host "診断スクリプトにエラーがある可能性があります。オプション5で直接実行して確認してください。" -ForegroundColor $ColorWarning
        }
    }
    catch {
        Write-Host "エラー: $_" -ForegroundColor $ColorError
    }
}

# 監視停止
function Stop-Monitoring {
    Write-Host "`n[監視を停止します...]" -ForegroundColor $ColorTitle
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-Host "タスクは登録されていません。" -ForegroundColor $ColorWarning
            return
        }

        if ($task.State -eq "Running") {
            Stop-ScheduledTask -TaskName $TaskName
            Write-Host "✓ タスク '$TaskName' を停止しました。" -ForegroundColor $ColorSuccess
        }
        else {
            Write-Host "タスクは実行されていません（現在の状態: $($task.State)）" -ForegroundColor $ColorWarning
        }
    }
    catch {
        Write-Host "エラー: $_" -ForegroundColor $ColorError
    }
}

# タスク削除
function Remove-DiagnosticTask {
    Write-Host "`n[タスク削除を実行します...]" -ForegroundColor $ColorTitle
    & "$ScriptPath\Stop_Monitor.ps1"
}

# 診断スクリプト直接実行
function Start-DirectDiagnostic {
    Write-Host "`n[診断スクリプトを直接実行します...]" -ForegroundColor $ColorTitle
    Write-Host "停止するには Ctrl+C を押してください。" -ForegroundColor $ColorWarning
    Write-Host ""
    & "$ScriptPath\Diagnostic_Main.ps1"
}

# 負荷テスト実行
function Start-LoadTest {
    Write-Host "`n[CPU負荷テストを実行します...]" -ForegroundColor $ColorTitle
    & "$ScriptPath\Load_Test.ps1"
}

# ログフォルダを開く
function Open-LogFolder {
    Write-Host "`n[ログフォルダを開きます...]" -ForegroundColor $ColorTitle
    if (Test-Path $LogFolder) {
        explorer.exe $LogFolder
        Write-Host "✓ ログフォルダを開きました: $LogFolder" -ForegroundColor $ColorSuccess
    }
    else {
        Write-Host "ログフォルダが存在しません: $LogFolder" -ForegroundColor $ColorWarning
        Write-Host "まず監視を開始してログを生成してください。" -ForegroundColor $ColorWarning
    }
}

# タスク詳細情報表示
function Show-TaskInfo {
    Write-Host "`n[タスク詳細情報]" -ForegroundColor $ColorTitle
    Write-Host "========================================" -ForegroundColor $ColorTitle

    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "タスク名: $TaskName" -ForegroundColor $ColorMenu
        Write-Host "状態: $($task.State)" -ForegroundColor $ColorMenu
        Write-Host "説明: $($task.Description)" -ForegroundColor $ColorMenu

        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($taskInfo) {
            Write-Host "最終実行日時: $($taskInfo.LastRunTime)" -ForegroundColor $ColorMenu
            Write-Host "次回実行日時: $($taskInfo.NextRunTime)" -ForegroundColor $ColorMenu
            Write-Host "最終実行結果: 0x$("{0:X}" -f $taskInfo.LastTaskResult)" -ForegroundColor $ColorMenu

            if ($taskInfo.LastTaskResult -eq 0) {
                Write-Host "  ✓ 成功" -ForegroundColor $ColorSuccess
            }
            else {
                Write-Host "  ✗ エラー（コード: $($taskInfo.LastTaskResult)）" -ForegroundColor $ColorError
            }
        }
    }
    else {
        Write-Host "タスクは登録されていません。" -ForegroundColor $ColorWarning
    }

    Write-Host "========================================" -ForegroundColor $ColorTitle
}

# ファイルのブロック解除
function Unblock-Scripts {
    Write-Host "`n[PowerShellスクリプトのブロックを解除します...]" -ForegroundColor $ColorTitle
    try {
        Get-ChildItem -Path $ScriptPath -Filter *.ps1 | ForEach-Object {
            Unblock-File -Path $_.FullName
            Write-Host "  ✓ $($_.Name)" -ForegroundColor $ColorSuccess
        }
        Write-Host "`n✓ すべてのスクリプトのブロックを解除しました。" -ForegroundColor $ColorSuccess
    }
    catch {
        Write-Host "エラー: $_" -ForegroundColor $ColorError
    }
}

# メインループ
while ($true) {
    Show-Menu

    $choice = Read-Host "`n選択してください (0-9)"

    switch ($choice) {
        "1" {
            Register-DiagnosticTask
            Read-Host "`nEnterキーを押して続行"
        }
        "2" {
            Start-Monitoring
            Read-Host "`nEnterキーを押して続行"
        }
        "3" {
            Stop-Monitoring
            Read-Host "`nEnterキーを押して続行"
        }
        "4" {
            Remove-DiagnosticTask
            Read-Host "`nEnterキーを押して続行"
        }
        "5" {
            Start-DirectDiagnostic
            Read-Host "`nEnterキーを押して続行"
        }
        "6" {
            Start-LoadTest
            Read-Host "`nEnterキーを押して続行"
        }
        "7" {
            Open-LogFolder
            Read-Host "`nEnterキーを押して続行"
        }
        "8" {
            Show-TaskInfo
            Read-Host "`nEnterキーを押して続行"
        }
        "9" {
            Unblock-Scripts
            Read-Host "`nEnterキーを押して続行"
        }
        "0" {
            Write-Host "`n終了します。" -ForegroundColor $ColorSuccess
            exit 0
        }
        default {
            Write-Host "`n無効な選択です。0-9の数字を入力してください。" -ForegroundColor $ColorError
            Start-Sleep -Seconds 2
        }
    }
}
