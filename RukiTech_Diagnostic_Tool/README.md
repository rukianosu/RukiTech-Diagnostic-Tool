# RukiTech Diagnostic Tool

**DELL Inspiron 5515 システム診断ツールセット**

プロ仕様のシステム監視・診断ツールで、PCの不安定性を追跡し、詳細なログ記録と自動通知機能を提供します。

---

## 📋 目次

1. [概要](#概要)
2. [機能](#機能)
3. [ファイル構成](#ファイル構成)
4. [セットアップ手順](#セットアップ手順)
5. [使用方法](#使用方法)
6. [Discord通知設定](#discord通知設定)
7. [ログファイル](#ログファイル)
8. [トラブルシューティング](#トラブルシューティング)
9. [注意事項](#注意事項)

---

## 概要

RukiTech Diagnostic Toolは、DELL Inspiron 5515の不安定性問題を診断するために開発された、プロフェッショナル仕様の診断ツールセットです。

### 主な用途
- システムクラッシュの原因特定
- ハードウェアエラーの検知と記録
- CPU/GPU温度の継続監視
- 高負荷時の安定性テスト

---

## 機能

### 🔍 監視機能（Diagnostic_Main.ps1）

#### A. ログ記録（30秒ごと、CSV形式）
以下の項目を自動記録します：
- **タイムスタンプ**
- **CPU温度** (℃)
- **GPU温度** (℃) ※サードパーティツール必要
- **CPU使用率** (%)
- **CPUクロック周波数** (MHz)
- **メモリ使用率** (%)
- **ページファイル使用量（コミットチャージ）** (MB)
- **ストレージ S.M.A.R.T. HealthStatus**
- **ストレージ S.M.A.R.T. OperationalStatus**
- **GPUコアクロック** (MHz) ※サードパーティツール必要
- **GPUメモリ使用率** (%) ※サードパーティツール必要
- **電源ソース** (AC/Battery)

> **注意**: ログは書き込みごとに必ずファイルを閉じ、データ消失を防ぎます。

#### B. 自動通知機能
以下のイベント発生時に**Discord通知**を送信します：

| イベント | 説明 |
|---------|------|
| **Kernel-Power 41** | 不正なシャットダウン（ブルースクリーン、強制終了など） |
| **WHEA-Logger** | ハードウェアエラー（メモリ、CPU、チップセット等） |
| **CPU高温警告** | CPU温度が90℃を超過 |
| **ミニダンプ検知** | 新しいクラッシュダンプファイル (.dmp) の生成 |

#### C. 通知失敗時の代替処理
Discord通知が送信失敗した場合：
1. 警告音（ビープ音）を2回鳴らす
2. ローカル緊急ログファイル `CRITICAL_EVENT_[日時].txt` を作成

#### D. 初期情報収集
初回実行時に以下の情報を `Driver_Versions.txt` として保存：
- BIOS バージョン
- AMD Graphics ドライバ
- チップセットドライバ
- Wi-Fi / ネットワークアダプタ
- オーディオドライバ
- マザーボード情報

### ⚙️ 自動実行登録（Setup_Task.ps1）
- タスクスケジューラに `RukiTech_Monitor` として登録
- **PC起動時に自動実行**（管理者権限）
- バッテリー動作時も継続実行

### 🛑 監視停止（Stop_Monitor.ps1）
- 実行中のプロセスを強制終了
- タスクスケジューラからタスクを削除

### 🔥 負荷テスト（Load_Test.ps1）
- CPU使用率を90%以上に維持
- リアルタイムでCPU温度・使用率を表示
- **Ctrl+C で安全に停止可能**
- システムの熱管理と安定性をテスト

---

## ファイル構成

```
RukiTech_Diagnostic_Tool/
│
├── Diagnostic_Main.ps1     # メイン診断スクリプト
├── Setup_Task.ps1          # 自動実行登録スクリプト
├── Stop_Monitor.ps1        # 監視停止スクリプト
├── Load_Test.ps1           # CPU負荷テストスクリプト
└── README.md               # このファイル
```

### ログフォルダ（自動生成）
```
デスクトップ/PC_Diagnostic_Logs/
│
├── SystemLog_20250101.csv        # 日次ログ（CSV形式）
├── Driver_Versions.txt           # ドライババージョン情報
└── CRITICAL_EVENT_xxxxxxxx.txt   # 緊急イベントログ（通知失敗時）
```

---

## セットアップ手順

### 1. 必要要件
- **OS**: Windows 10/11
- **権限**: 管理者権限が必要
- **PowerShell**: 5.1 以降

### 2. インストール

#### ステップ 1: フォルダの配置
`RukiTech_Diagnostic_Tool` フォルダを任意の場所に配置します。
推奨: `C:\Tools\RukiTech_Diagnostic_Tool`

#### ステップ 2: PowerShell実行ポリシーの確認
管理者権限でPowerShellを開き、以下を実行：
```powershell
Get-ExecutionPolicy
```

`Restricted` の場合は、以下で変更：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### ステップ 3: Discord Webhook URL の設定（オプション）
1. Discordでサーバーを作成（またはチャンネルを用意）
2. チャンネル設定 → 連携サービス → ウェブフック → 新しいウェブフック
3. Webhook URLをコピー
4. `Diagnostic_Main.ps1` をテキストエディタで開く
5. 冒頭の以下の行を編集：
   ```powershell
   $DiscordWebhookURL = "YOUR_DISCORD_WEBHOOK_URL_HERE"
   ```
   ↓
   ```powershell
   $DiscordWebhookURL = "https://discord.com/api/webhooks/XXXXXXXXX/YYYYYYYY"
   ```

> **注意**: Webhook URLを設定しない場合、通知機能は無効化されますが、ローカルログは正常に記録されます。

#### ステップ 4: 自動実行の登録
管理者権限でPowerShellを開き、以下を実行：
```powershell
cd "C:\Tools\RukiTech_Diagnostic_Tool"  # フォルダのパスに合わせて変更
.\Setup_Task.ps1
```

確認メッセージに従い、タスクを登録します。

#### ステップ 5: 動作確認
すぐに監視を開始する場合：
```powershell
Start-ScheduledTask -TaskName "RukiTech_Monitor"
```

またはPCを再起動すると自動的に開始されます。

---

## 使用方法

### 📊 ログの確認
デスクトップの `PC_Diagnostic_Logs` フォルダを開きます。

- **SystemLog_[日付].csv**: Excelやテキストエディタで開けます
- **Driver_Versions.txt**: ドライバ情報の確認
- **CRITICAL_EVENT_[日時].txt**: 緊急イベントの詳細

### 🔥 負荷テストの実行
管理者権限でPowerShellを開き：
```powershell
cd "C:\Tools\RukiTech_Diagnostic_Tool"
.\Load_Test.ps1
```

- CPU負荷を90%以上に維持します
- 5秒ごとにCPU使用率と温度を表示
- **Ctrl+C で停止**

> **警告**: 長時間の実行はシステムに負荷をかけます。温度監視を推奨します。

### 🛑 監視の停止
管理者権限でPowerShellを開き：
```powershell
cd "C:\Tools\RukiTech_Diagnostic_Tool"
.\Stop_Monitor.ps1
```

実行中のプロセスとタスクスケジューラのタスクを削除します。

### 🔄 監視の再開
```powershell
.\Setup_Task.ps1
```
または
```powershell
Start-ScheduledTask -TaskName "RukiTech_Monitor"
```

---

## Discord通知設定

### Webhook URLの取得方法

1. **Discordアプリを開く**
2. 通知を受け取りたいサーバーとチャンネルを選択
3. チャンネル名の横にある⚙️（設定）をクリック
4. **連携サービス** → **ウェブフック** → **新しいウェブフック**
5. ウェブフック名を設定（例: RukiTech 診断ツール）
6. **ウェブフックURLをコピー** をクリック
7. URLを `Diagnostic_Main.ps1` の冒頭に貼り付け

### 通知の種類

| 通知タイプ | タイトル | トリガー条件 |
|-----------|---------|------------|
| 🔴 システム不正終了 | Kernel-Power 41検知 | 不正なシャットダウン |
| 🔧 ハードウェアエラー | WHEA-Logger検知 | ハードウェア障害 |
| 🌡️ 高温警告 | CPU温度警告 | 90℃超過 |
| 💥 クラッシュダンプ | ミニダンプ検知 | 新しい.dmpファイル |

---

## ログファイル

### SystemLog_[日付].csv の構造

| 列名 | 説明 | 単位 |
|------|------|------|
| Timestamp | 記録日時 | yyyy-MM-dd HH:mm:ss |
| CPU_Temp_C | CPU温度 | ℃ |
| GPU_Temp_C | GPU温度 | ℃ |
| CPU_Usage_Percent | CPU使用率 | % |
| CPU_Clock_MHz | CPUクロック周波数 | MHz |
| Memory_Usage_Percent | メモリ使用率 | % |
| PageFile_Usage_MB | ページファイル使用量 | MB |
| Storage_HealthStatus | ストレージ健全性 | Healthy/Warning/Unhealthy |
| Storage_OperationalStatus | ストレージ動作状態 | OK/Degraded/Failed |
| GPU_CoreClock_MHz | GPUコアクロック | MHz |
| GPU_MemoryUsage_Percent | GPUメモリ使用率 | % |
| PowerSource | 電源ソース | AC/Battery |

### ログの分析例

#### Excelでグラフ化
1. CSVファイルをExcelで開く
2. データ全体を選択
3. **挿入** → **折れ線グラフ**
4. CPU温度、使用率の推移を可視化

#### 異常値の検出
- CPU温度が85℃以上の時刻を特定
- CPU使用率が100%の期間を確認
- ストレージHealthStatusが"Healthy"以外になった時刻

---

## トラブルシューティング

### ❌ スクリプトが実行できない

**問題**: `このシステムではスクリプトの実行が無効になっているため...`

**解決策**: 管理者権限でPowerShellを開き：
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### ❌ CPU温度が「N/A」と表示される

**原因**: WMI経由での温度取得に対応していないシステム

**解決策**:
- サードパーティ製ツール（HWiNFO, OpenHardwareMonitor等）の使用を検討
- BIOS設定で温度監視機能を有効化

### ❌ GPU情報が取得できない

**原因**: AMD GPU情報はWMI経由での詳細取得が困難

**解決策**:
- AMD Radeon Softwareで温度監視
- GPU-Z等のツールを併用

### ❌ Discord通知が送信されない

**確認項目**:
1. Webhook URLが正しく設定されているか
2. インターネット接続が正常か
3. Discordサーバーのチャンネルが削除されていないか

**代替手段**:
- 通知失敗時は `CRITICAL_EVENT_[日時].txt` が自動生成されます

### ❌ タスクスケジューラで起動しない

**確認項目**:
1. タスクが正しく登録されているか確認：
   ```powershell
   Get-ScheduledTask -TaskName "RukiTech_Monitor"
   ```
2. タスクの実行履歴を確認：
   - タスクスケジューラを開く
   - `RukiTech_Monitor` を右クリック → **履歴**

**解決策**:
- タスクを削除して再登録：
  ```powershell
  .\Stop_Monitor.ps1
  .\Setup_Task.ps1
  ```

---

## 注意事項

### ⚠️ 重要な注意点

1. **管理者権限が必須**
   すべてのスクリプトは管理者権限で実行してください。

2. **長時間の負荷テストは危険**
   `Load_Test.ps1` は90%以上のCPU負荷をかけます。温度監視を必ず行ってください。

3. **ログファイルのサイズ**
   30秒ごとに記録されるため、長期間の実行ではログファイルが大きくなります。
   定期的に古いログを削除・アーカイブすることを推奨します。

4. **Discord Webhook URLの保護**
   Webhook URLは外部に漏らさないでください。悪用されるリスクがあります。

5. **システムへの影響**
   バックグラウンドで常時動作するため、システムリソースを若干消費します。

### 📅 推奨メンテナンス

- **週次**: ログファイルの確認と分析
- **月次**: 古いログファイルのアーカイブ（3ヶ月以上前）
- **適宜**: ドライババージョン情報の再収集

---

## ライセンスと免責事項

### ライセンス
本ツールは個人使用・診断目的で自由に使用できます。

### 免責事項
本ツールの使用によって生じたいかなる損害についても、開発者は責任を負いません。
システムの安定性や保証に影響を与える可能性があるため、自己責任でご使用ください。

---

## サポート情報

### 開発者
**RukiTech**

### バージョン
**Version 1.0** (2025)

### 対象システム
**DELL Inspiron 5515** (AMD Ryzen 5000シリーズ)

---

## 更新履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|---------|
| 1.0 | 2025-01-01 | 初版リリース |

---

**診断ツールを活用して、システムの安定性を向上させましょう！**
