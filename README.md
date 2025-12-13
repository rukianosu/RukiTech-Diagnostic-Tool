# RukiTech Diagnostic Tool

**DELL Inspiron 5515 システム診断ツールセット**

プロ仕様のシステム監視・診断ツールで、PCの不安定性を追跡し、詳細なログ記録と自動通知機能を提供します。

---

## 📦 概要

このリポジトリには、DELL Inspiron 5515の不安定性問題を診断するための、包括的な診断ツールセットが含まれています。

### 主な機能

- ✅ **30秒ごとの自動ログ記録**（CPU/GPU温度、使用率、S.M.A.R.T.情報など）
- ✅ **Discord通知**（クラッシュ、ハードウェアエラー、高温警告）
- ✅ **PC起動時の自動実行**（不正終了後も自動再開）
- ✅ **CPU負荷テスト**（システム安定性検証）
- ✅ **データ消失防止設計**（ログを毎回即座に保存）
- ✅ **[NEW] 一括診断レポート作成**（GUI操作、再起動後自動再開）

---

## 📂 ファイル構成

```
RukiTech_Diagnostic_Tool/
├── README.md               # 詳細な使用説明書
├── Diagnostic_Main.ps1     # Monitor Mode: メイン監視スクリプト
├── Setup_Task.ps1          # Monitor Mode: 自動実行登録
├── Stop_Monitor.ps1        # Monitor Mode: 監視停止
├── Load_Test.ps1           # Monitor Mode: 負荷テスト
├── Diagnostic_GUI.ps1      # Collect Mode: 診断GUIフロントエンド (NEW)
├── Collect_Main.ps1        # Collect Mode: 診断収集コアロジック (NEW)
└── templates/              # レポートテンプレート
```

---

## 🚀 Monitor Mode (常時監視)

### 1. リポジトリをダウンロード
```powershell
git clone https://github.com/rukianosu/RukiTech-Diagnostic-Tool.git
cd RukiTech-Diagnostic-Tool
```

### 2. セットアップと開始
管理者権限でPowerShellを開き、以下を実行します：
```powershell
.\Setup_Task.ps1
Start-ScheduledTask -TaskName "RukiTech_Monitor"
```

---

## 🛠️ Collect Mode (診断レポート作成) ★NEW

Monitorモードとは別に、現在のシステム状態、過去のイベントログ、ダンプファイルなどを一括収集し、解析レポートを作成するモードです。
**PCが不安定で診断中に落ちてしまう場合でも、再起動後に自動的に処理を再開して完走する機能を持っています。**

### 使い方

1. `Diagnostic_GUI.ps1` を右クリックして「PowerShellで実行」を選択します。
   - **推奨:** 管理者権限で実行してください（システムログやダンプへのアクセスに必要です）。
2. GUIが表示されたら設定を確認します。
   - **Output Folder:** 出力先（デフォルトはデスクトップ）
   - **Settings:** イベントログ収集期間など
   - **Auto-Resume:** [ON] にすると、診断中にPCが再起動しても、次回ログオン時に自動で診断を再開します。
3. **Start Collection** を押して開始します。
4. 完了すると `REPORT.html` が生成されます。

### 出力フォルダ構成

`Desktop\PC_Diagnostic_Collect\RukiCollect_YYYYMMDD_HHMMSS\`

- `REPORT.html`: 診断結果のサマリーとアクションプラン
- `parsed\`: CSV化されたイベントログ
- `raw\`: 生のシステム情報、ダンプファイル
- `run.log`: 実行ログ
- `*.zip`: 提出用の一括アーカイブ

---

## 📊 ログ出力先 (Monitor Mode)

デスクトップに自動生成される **`PC_Diagnostic_Logs`** フォルダ：
- `SystemLog_[日付].csv`
- `Driver_Versions.txt`
- `CRITICAL_EVENT_[日時].txt`

---

## ⚠️ 重要な注意点

1. **管理者権限が必須** - すべてのスクリプトは管理者権限で実行してください
2. **自動再起動対応** - 監視・収集ともに、不正終了後の自動再開に対応しています

---

## 📜 ライセンス

個人使用・診断目的で自由に使用できます。

---

[詳細ドキュメント](RukiTech_Diagnostic_Tool/README.md) | [Issues](https://github.com/rukianosu/RukiTech-Diagnostic-Tool/issues)
