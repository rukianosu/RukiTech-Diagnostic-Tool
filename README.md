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

---

## 📂 ファイル構成

```
RukiTech_Diagnostic_Tool/
├── README.md               # 詳細な使用説明書（日本語）
├── Diagnostic_Main.ps1     # メイン診断スクリプト
├── Setup_Task.ps1          # 自動実行登録スクリプト
├── Stop_Monitor.ps1        # 監視停止スクリプト
└── Load_Test.ps1           # CPU負荷テストスクリプト
```

---

## 🚀 クイックスタート

### 1. リポジトリをダウンロード

```powershell
# GitHubからダウンロード、またはZIPで取得
git clone https://github.com/rukianosu/RukiTech-Diagnostic-Tool.git
cd RukiTech-Diagnostic-Tool
```

### 2. Discord Webhook URL を設定（オプション）

`RukiTech_Diagnostic_Tool/Diagnostic_Main.ps1` を編集：

```powershell
$DiscordWebhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE"
```

### 3. 自動実行を登録

管理者権限でPowerShellを開き：

```powershell
cd RukiTech_Diagnostic_Tool
.\Setup_Task.ps1
```

### 4. 監視開始

PC再起動、または即座に開始する場合：

```powershell
Start-ScheduledTask -TaskName "RukiTech_Monitor"
```

---

## 📊 ログ出力先

デスクトップに自動生成される **`PC_Diagnostic_Logs`** フォルダ：

- `SystemLog_[日付].csv` - 日次システムログ（30秒ごと）
- `Driver_Versions.txt` - ドライババージョン情報
- `CRITICAL_EVENT_[日時].txt` - 緊急イベントログ

---

## 🔔 自動通知されるイベント

| イベント | 説明 |
|---------|------|
| **Kernel-Power 41** | 不正なシャットダウン（ブルースクリーン等） |
| **WHEA-Logger** | ハードウェアエラー（メモリ、CPU、チップセット） |
| **CPU高温警告** | CPU温度が90℃を超過 |
| **ミニダンプ検知** | 新しいクラッシュダンプファイルの生成 |

通知失敗時は、警告音とローカルログファイルで代替します。

---

## 📖 詳細ドキュメント

**完全な使用説明書は以下をご覧ください：**

👉 **[RukiTech_Diagnostic_Tool/README.md](RukiTech_Diagnostic_Tool/README.md)**

以下の情報が含まれています：
- セットアップ詳細手順
- Discord Webhook設定ガイド
- ログ記録項目の詳細
- CPU負荷テストの使い方
- トラブルシューティング
- ログ分析方法

---

## ⚠️ 重要な注意点

1. **管理者権限が必須** - すべてのスクリプトは管理者権限で実行してください
2. **自動再起動対応** - 不正終了後も自動的に監視が再開されます
3. **データ保護設計** - ログは書き込みごとにファイルを閉じ、突然の電源断でも保存されます

---

## 🛠️ 対象システム

- **機種**: DELL Inspiron 5515
- **プロセッサ**: AMD Ryzen 5000シリーズ
- **OS**: Windows 10/11
- **PowerShell**: 5.1以降

---

## 📜 ライセンス

個人使用・診断目的で自由に使用できます。

---

## 🔗 リンク

- [詳細ドキュメント](RukiTech_Diagnostic_Tool/README.md)
- [Issues](https://github.com/rukianosu/RukiTech-Diagnostic-Tool/issues)

---

**診断ツールを活用して、システムの安定性を向上させましょう！**
