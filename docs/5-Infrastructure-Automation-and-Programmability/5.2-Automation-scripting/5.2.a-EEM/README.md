---
layout: default
title: 5.2.a-EEM
parent: 5.2-Automation-scripting
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.2.a EEM applets

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint におけるインフラストラクチャ自動化・イベント駆動型障害自己修復（Self-Healing Architecture）の核心技術である **`5.2.a EEM applets` (Cisco Embedded Event Manager Applets)** に関する完全学習メモです。

---

## 📘 概要

### 1. EEM (Embedded Event Manager) とは
Cisco EEM (Embedded Event Manager) は、Cisco IOS / IOS XE / NX-OS などのネットワークオペレーティングシステムに組み込まれた強力で統合されたイベント駆動型自動化サブシステムです。ネットワーク機器内部で発生する多様なシステムイベント（Syslogメッセージの発生、CLIコマンドの入力、IP SLAの状態変化、Object Trackingの切り替え、SNMPトラップ、タイマーの満了など）をリアルタイムに検知し、あらかじめ定義されたアクション（CLIコマンドの自動実行、Syslogの発行、SNMPトラップの送信、電子メールの送付、On-Box Pythonスクリプトの起動など）を即座に実行します。

### 2. EEM Applet の利用目的と特徴
EEM ポリシーには、CLI コマンドで記述する **EEM Applet** と、より複雑なプログラミング処理を可能にする **EEM Tcl Script** の 2 種類が存在します。CCIE EI v1.1 Blueprint においては、特に速効性と設定の容易性に優れた **EEM Applet** の実装・トラブルシューティング能力が強く要求されます。

* **障害の即時検知と自己修復 (Self-Healing):** 人間のオペレータが介入する前に、システムが自律的に障害を検知し、適切なリカバリ手順（インターフェイスのバウンス、ルーティングプロセスのリセット、予備パスへの切替など）を実行します。
* **運用タスクの自動化 (Operational Automation):** 定期的なコンフィグバックアップ、統計情報の収集、特定イベント発生時の診断ログ（`show` コマンド出力や `debug` ログ）の Flash ドライブへの自動保存を行います。
* **セキュリティ・ガバナンス強化:** オペレータによる不適切なコマンドの入力（例: 稼働中ルータでの `reload` や `no router bgp`）を割り込んで検知し、コマンドの実行をブロック（`skip yes`）します。

### 3. どのような場面で利用するか
* **BGP / OSPF フラッピング時の自動診断データ収集:** BGP セッションが Down した場合に、セッション切断直後の詳細な `show ip bgp summary` や `show log` を自動的に Flash ファイルへ退避させ、原因究明を迅速化する。
* **回線障害時の自動切替補完:** IP SLA / Track が Down した場合に、標準のルーティングプロトコル機能に加えて、インターフェイスのシャットダウンや特定コンフィグの動的書き換えを行う。
* **セキュリティポリシー違反コマンドのインターセプト:** 誤操作によるシステム停止を防止するため、不吉なコマンドが入力された際に警告を表示して実行をブロックする。

---

## 🔑 要点

EEM Applet の主要な特徴と設計上の注意点を下表に整理します。

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | Cisco IOS XE に標準組み込み。CLI（コンフィギュレーションモード）で直接定義可能なイベント駆動型スクリプト。 |
| **主な用途** | イベント検知（Syslog/Track/Timer/CLI）、自動リカバリ CLI 実行、コマンド実行制御、診断ログ自動採取。 |
| **メリット** | 外部サーバ（NMS/Ansible等）を必要とせず、単体機器内でリアルタイム（ミリ秒〜秒単位）に動作。設定が簡潔。 |
| **デメリット** | 複雑な文字列パースや多重ループ処理、外部 Web API との高度なやり取りには Tcl や On-Box Python の方が適する。 |
| **対応機種** | Catalyst 9300 / 9400 / 9500 シリーズ、ISR 4000 / Catalyst 8000 エッジルータ、ASR 1000 シリーズなど多数。 |
| **制限事項** | 同一 Applet 内で指定できるイベントディテクタは原則 1 つ（`tag` による論理結合を除く）。実行時間制限 (`maxrun`)。 |
| **設計上の注意点** | **EEM 無限ループの回避**（EEM のアクションで発生した Syslog が再度同一 EEM を呼び出す現象の防止）。 |

---

## 🏗 動作原理

### 1. EEM サブシステムの三層構造
Cisco EEM は、大きく分けて以下の 3 つのコアコンポーネントで構成されています。

```
+-------------------------------------------------------------------+
|                        Event Detectors (ED)                       |
|  (Syslog / Track / CLI / Timer / SNMP / IP SLA / Routing / etc.)  |
+-------------------------------------------------------------------+
                                  │
                                  ▼ (イベント通知 ＆ コンテキスト変数受渡)
+-------------------------------------------------------------------+
|                            EEM Server                             |
|       (ポリシー評価 engine, キュー管理, スケジューリング)         |
+-------------------------------------------------------------------+
                                  │
                                  ▼ (ポリシー判定 ➔ アクション起動)
+-------------------------------------------------------------------+
|                       Action Engine / Exec                        |
|       (CLI コマンド実行, Syslog 発行, メール送信, Python 呼び出し) |
+-------------------------------------------------------------------+
```

1. **Event Detectors (ED: イベント検出器):**  
   IOS XE システム内部の各種サブシステム（Syslog、CLI パーサー、Object Tracking、IP SLA、タイマー、SNMP）を監視し、指定された条件を満たすイベントが発生した際に EEM Server へ通知を発行します。
2. **EEM Server (EEM サーバー):**  
   イベント検出器からの通知を受け取り、登録されている EEM ポリシー（Applet や Tcl）と照合します。イベントの優先度管理や実行キューイングを行います。
3. **Action Engine (アクションエンジン):**  
   マッチした EEM Applet 内で定義されている `action` ステートメントを順番（ラベル番号の昇順）に実行します。

### 2. コンテキスト変数 (Context Variables)
イベントが検出されると、EEM はイベントの背景情報を保持する**組み込み環境変数（Built-in Environment Variables）**を自動的に生成します。アクション内でこれらの変数を参照・利用することが可能です。

* `$_syslog_msg`: 検出された Syslog の完全なメッセージテキスト。
* `$_cli_msg`: ユーザーが入力した CLI コマンド文字列。
* `$_cli_result`: `action cli command` で実行した CLI コマンドの出力結果テキスト。
* `$_track_number`: 状態変化した Track オブジェクト番号。
* `$_track_state`: Track オブジェクトの変更後の状態 (`up` または `down`)。

---

## ⚙ 動作シーケンス

パケット処理やイベント検出から EEM Applet が起動し、処理が完了するまでのシーケンスを以下に説明します。

```
[内部イベント発生] (例: BGP Neighbor Down Syslog 発行)
       │
       ▼
[1. Event Detector (ED) が検知]
  - Syslog パターン "BGP-5-ADJCHANGE.*Down" にマッチ
  - コンテキスト変数 ($_syslog_msg 等) を生成
       │
       ▼
[2. EEM Server ポリシー照合]
  - 該当する `event manager applet` を検索・呼び出し
  - `sync` パラメータ判定 (sync no = 非同期処理 / sync yes = 同期割り込み)
       │
       ▼
[3. Action Engine によるシーケンシャル実行]
  - ラベル番号昇順 (action 1.0 ➔ action 2.0 ➔ action 3.0 ...) で評価
  - CLI セッションオープン ➔ `enable` ➔ 設定コマンド実行
  - ロジック評価 (`if` / `else` / `string match`)
       │
       ▼
[4. 結果の処理 ＆ リソース解放]
  - `sync yes` の場合: 元の処理へ復帰 (`skip yes` の場合はコマンド実行を破棄)
  - 完了ログの記録 (`show event manager history events` に記録)
```

1. **イベント発生:** システム内で Syslog 出力や Track 状態変更などのイベントが発生します。
2. **Event Detector によるキャプチャ:** 該当するイベント検出器がイベントを識別し、コンテキスト変数（環境変数）に値を設定します。
3. **EEM サーバーによるポリシースケジューリング:** 登録済みの `event manager applet` のイベント条件と照合します。
4. **アクションの昇順実行:** 定義された `action` ステートメントが、ラベル文字列（例: `1.0`, `1.1`, `2.0` など。数値として昇順にソート）の順番に従って実行されます。
5. **事後処理:** 同期処理（`sync yes`）の場合は、割り込んだ元の CLI やシステム処理に対して継続（`skip no`）またはキャンセル（`skip yes`）の制御信号を返します。


## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint における重要ポイント
CCIE EI v1.1 ラボ試験において、EEM Applet は単独の問題として出題されるだけでなく、**「特定のプロトコル障害（BGP/OSPF/HSRP/IP SLA）が発生した際に、追加のリカバリ動作や特殊な条件制御を実装せよ」** という複合問題の解決手段として頻繁に利用されます。

* **Syslog イベントの正確な正規表現 (Regular Expression) マッチング:**
  Syslog メッセージの一部に正確にマッチするパターンを作成する技術。
* **CLI インターセプトと非破壊的制御:**
  `event cli pattern` と `sync yes` / `skip yes` を組み合わせた禁止コマンドのフィルタリング。
* **EEM 無限ループ（Infinite Loop）の回避:**
  EEM アクション内で実行した CLI や発生させた Syslog が、再度同一の EEM イベントトリガーに引っかかる無限ループを防ぐ設計。
* **複数アクションのラベルソート順:**
  EEM は `action` のラベルをアルファベット・数値の昇順で実行します。例: `action 10.0` は `action 2.0` よりも前に実行されます（文字列ソートではなく数値ソートですが、`action 1.0`, `action 2.0`, `action 10.0` のように整然と書くことが推奨されます）。

### 2. ラボ試験で設定させられそうな要求例
1. **「BGP ピア 192.168.1.2 が Down した場合に、即座に Interface GigabitEthernet0/1 を shutdown / no shutdown してリバウンドさせ、その際の `show ip bgp summary` の結果を `flash:bgp_debug.txt` に保存せよ。」**
2. **「オペレータが誤って `no router bgp` コマンドを入力した際、そのコマンドの実行をブロックし、『BGP configuration cannot be removed!』という警告 Syslog を出力せよ。」**
3. **「Track 10 (IP SLA) が Down した場合に、HSRP グループ 1 の Priority を下げ、さらに上位スイッチへ特定の SNMP トラップを送出せよ。」**
4. **「毎日深夜 0 時に自動的に `copy running-config flash:cron_backup.cfg` を実行せよ。」**

### 3. よくある設定ミス ＆ 狙われやすい落とし穴

#### ① EEM 無限ループ (EEM Cascading / Infinite Loop)
最も典型的かつ危険な障害パターンです。
* **失敗例:** `event syslog pattern "LINK-3-UPDOWN"` の設定で、アクション内に `action 1.0 cli command "interface Gi0/1"` ➔ `action 2.0 cli command "shutdown"` ➔ `action 3.0 cli command "no shutdown"` を記述した場合。
* **原因:** `no shutdown` を実行した瞬間に、IOS XE は新たな `LINK-3-UPDOWN` Syslog メッセージを発行します。これにより EEM が再度トリガーされ、無限にインターフェイスがシャットダウン/アップを繰り返します。
* **回避策:** 正規表現パターンを特定インターフェイス（例: `LINK-3-UPDOWN.*GigabitEthernet0/0`）に絞り込むか、アクション内で生成される Syslog にマッチしない独自のキーワードパターンを設定します。

#### ② `sync yes` と `skip yes` の設定漏れ
CLI コマンドの実行を横取り（インターセプト）してブロックする場合、`event cli pattern "..." sync yes` のように `sync yes` を指定する必要があります。`sync no`（デフォルト）の場合、EEM は非同期で動作するため、元の CLI コマンドの実行を止めることができません。また、横取りしたコマンドを破棄するには `action X.X cli command "..."` の最後または個別に `skip yes`（あるいは `action X.X set $_exit_status "0"`）を実行する必要があります。

#### ③ `maxrun` タイマーの超過（デフォルト 20 秒）
EEM Applet のデフォルトの最大実行時間制限は **20 秒** です。大量のコマンド出力を含む `show` コマンドや、時間のかかる Ping / Traceroute、あるいは `action 1.0 cli command "reload"` のように応答を待つ処理を入れると、20 秒で EEM が強制終了されます。長い処理を行う場合は `event manager applet <NAME> authorization bypass` や `event ... maxrun 60` のように `maxrun` タイマーを拡大します。

#### ④ CLI セッションのモード移動ミス
`action cli command` で CLI コマンドを実行する場合、最初のコマンド実行前に EEM は `enable` モードにいます。グローバルコンフィギュレーションコマンドを実行するには、明示的に `configure terminal` を投入するか、マルチライン記述を行う必要があります。

```bash
! 誤った記述例 (configure terminal を忘れている)
event manager applet BAD_EXAMPLE
 event syslog pattern "BGP-5-ADJCHANGE"
 action 1.0 cli command "interface GigabitEthernet0/1"  ! 特権EXECモードで実行されエラーになる
 action 2.0 cli command "shutdown"

! 正しい記述例
event manager applet GOOD_EXAMPLE
 event syslog pattern "BGP-5-ADJCHANGE"
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 3.0 cli command "interface GigabitEthernet0/1"
 action 4.0 cli command "shutdown"
 action 5.0 cli command "no shutdown"
 action 6.0 cli command "end"
```

### 4. Verification ＆ Debugging

#### アプレットの登録状態と履歴確認
```text
Router# show event manager policy registered
No.  Class     Type    Event Registered Name
1    applet    user    syslog           BGP_FLAP_RECOVERY
 pattern {BGP-5-ADJCHANGE.*Down}
 maxrun 30.000
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 ...
```

#### EEM 実行履歴の確認 (`show event manager history events`)
EEM が過去にいつ、どのイベントで起動し、正常終了したか（またはエラーで終了したか）を確認します。
```text
Router# show event manager history events
No. Time string                  num  Job Name
1   Fri Oct 24 2026 10:15:30.123 1    applet: BGP_FLAP_RECOVERY
```

#### リアルタイムデバッグ (`debug event manager action cli`)
EEM が CLI コマンドを内部的に投入する様子をリアルタイムで追跡できます。
```text
Router# debug event manager action cli
EEM action cli debugging is on

! イベント発生時のデバッグ出力例
*Oct 24 10:15:30.123: %EEM-5-ACTION: Executing applet BGP_FLAP_RECOVERY
*Oct 24 10:15:30.125: eem_action_cli: executing "enable"
*Oct 24 10:15:30.128: eem_action_cli: executing "configure terminal"
*Oct 24 10:15:30.130: eem_action_cli: executing "interface GigabitEthernet0/1"
*Oct 24 10:15:30.132: eem_action_cli: executing "shutdown"
```


## 🛠 設定方法

### 1. EEM Applet 基本構文構造
EEM Applet は、グローバルコンフィギュレーションモードで定義します。1 つの Applet は、**1 つのイベント検出器（`event`）**と、**1 つ以上のアクション（`action`）**で構成されます。

```bash
event manager applet <APPLET_NAME> [authorization bypass]
 event <EVENT_DETECTOR> <PARAMETERS> [maxrun <SECONDS>]
 action <LABEL> <ACTION_TYPE> <PARAMETERS>
```

### 2. 主要イベント検出器 (Event Detectors) と設定例

| イベント検出器 | 構文例 | 概要・利用場面 |
| :--- | :--- | :--- |
| **Syslog** | `event syslog pattern "BGP-5-ADJCHANGE.*Down"` | 特定の Syslog メッセージが発生した際に起動。最も頻繁に使用される。 |
| **Track** | `event track 10 state down` | Object Tracking (IP SLA / Interface) の状態変化 (up/down) を監視。 |
| **CLI** | `event cli pattern "reload" sync yes` | ユーザーが入力した CLI コマンドをキャプチャ/インターセプト。 |
| **Timer (Cron)**| `event timer cron cron-entry "0 0 * * *"` | 定期的（Cron 形式または Periodic）にタスクを実行。 |
| **SNMP** | `event snmp oid 1.3.6.1.2.1.2.2.1.8.1 get-type exact entry-op eq entry-val 2` | SNMP OID の値を監視し、閾値を超えた場合に起動。 |
| **None** | `event none` | 手動（`event manager run <APPLET_NAME>`）でトリガーする運用スクリプト。 |

### 3. 主要アクションステートメント (Action Statements)

| アクションタイプ | 構文例 | 役割・補足 |
| :--- | :--- | :--- |
| **cli command** | `action 1.0 cli command "show ip route"` | CLI コマンドを実行。出力は `$_cli_result` に格納。 |
| **syslog** | `action 2.0 syslog priority critical msg "EEM: Recovery triggered"` | カスタム Syslog メッセージを生成。 |
| **info type snmp**| `action 3.0 info type snmp trap enterprise-oid ...` | 定義された SNMP トラップを NMS へ送信。 |
| **puts** | `action 4.0 puts $_cli_result` | 実行結果を VTY/Console 画面へ表示。 |
| **file open/write**| `action 5.0 file open f1 flash:log.txt a+`<br>`action 5.1 file write f1 "$_cli_result"`<br>`action 5.2 file close f1` | ファイルのオープン、書き込み（追記）、クローズ処理。 |

### 4. 条件分岐 (Control Structures in EEM)
EEM Applet では、シンプルな `if` / `elseif` / `else` / `end` 構造を利用して動的なロジックを組むことができます。

```bash
event manager applet CONDITIONAL_CHECK
 event track 100 state down
 action 1.0 cli command "enable"
 action 2.0 cli command "show ip interface brief"
 action 3.0 string match "*Down*" "$_cli_result"
 action 4.0 if $_string_result eq "1"
 action 4.1  syslog priority emergency msg "EEM: Down interface detected in show output!"
 action 4.2  cli command "configure terminal"
 action 4.3  cli command "interface Gi0/1"
 action 4.4  cli command "no shutdown"
 action 5.0 else
 action 5.1  syslog priority info msg "EEM: Interfaces are healthy."
 action 6.0 end
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 補足・確認ポイント |
| :--- | :--- | :--- |
| **登録ポリシーの確認** | `show event manager policy registered` | 登録済みの Applet 名、トリガーイベント、最大実行時間 (`maxrun`) を確認。 |
| **実行履歴の確認** | `show event manager history events` | 過去に実行された Applet のタイムスタンプ、ジョブ ID、終了ステータスを確認。 |
| **環境変数の確認** | `show event manager environment` | 設定済みの EEM グローバル環境変数（`event manager environment ...`）一覧。 |
| **CLI アクションのデバッグ** | `debug event manager action cli` | EEM がバックグラウンドで投入する CLI コマンドをリアルタイム表示。 |
| **イベント検出器のデバッグ** | `debug event manager detector syslog` | Syslog イベント検出器がパターンマッチングを行う様子をリアルタイム表示。 |
| **手動実行** | `event manager run <APPLET_NAME>` | `event none` で定義された Applet を手動で即時テスト実行。 |

---

## 🚨 トラブルシューティング

| 症状 | 主な原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **EEM が起動しない (Syslog)** | Syslog の正規表現パターンが不一致（大文字小文字の違いや空白の差異）。 | `debug event manager detector syslog` | 対象の完全な Syslog メッセージを確認し、正規表現を再調整（例: `.*` を活用）。 |
| **EEM が起動しない (Track)** | 指定した Track オブジェクト番号が未定義または状態変化が発生していない。 | `show track` | `show track` でオブジェクト番号と現在の Up/Down 状態を確認。 |
| **CLI コマンドがエラーになる** | `enable` や `configure terminal` などのコンフィグモード移行コマンドの欠落。 | `debug event manager action cli` | アクションの最初に `enable` ➔ `configure terminal` を明示的に挿入。 |
| **CLI コマンドが横取りできない** | `event cli pattern` に `sync yes` が設定されていない。 | `show event manager policy registered` | `event cli pattern "..." sync yes` へ修正。 |
| **横取りしたコマンドが実行される** | `skip yes` がアクション内で設定されていない。 | `show event manager policy registered` | `action X.X cli command "..."` アクションで遮断処理を行うか `skip yes` を適用。 |
| **EEM が途中で強制終了する** | 処理時間がデフォルトの `maxrun` (20秒) を超過した。 | `show event manager history events` | アプレット定義の `event ... maxrun 60` でタイムアウト時間を拡大。 |
| **EEM 無限ループの発生** | EEM 内で実行したコマンドが発生させた Syslog で EEM が再起動している。 | `show log` | Syslog イベントパターンを特定のインターフェイスやプロセスメッセージに絞り込む。 |
| **ファイル保存が失敗する** | Flash ドライブの容量不足、またはファイルパス指定ミス。 | `dir flash:` | `dir flash:` で空き容量を確認し、書き込みモード (`a+` や `w`) を正しく指定。 |
| **権限不足でコマンド拒否** | AAA / TACACS+ による CLI 実行権限の制限。 | `show log` | `event manager applet <NAME> authorization bypass` をアタッチして権限バイパス。 |
| **変数参照エラー** | 変数名の間違い（例: `$_cli_result` のスペルミス）。 | `debug event manager action cli` | EEM 組み込み変数の正確な名称（`$_syslog_msg`, `$_cli_result` 等）を確認。 |

---

## ⚠ 制限事項

1. **イベント検出器の複数指定制限:**
   1 つの EEM Applet 内で指定できる直接的な `event` ステートメントは原則 1 つです。複数のイベント（例: Track 1 かつ Track 2）を条件とする場合は、`tag` 機能（`event track 1 tag E1 ...` / `attribute tag E1 and E2`）を使用する必要があります。
2. **`maxrun` 実行時間制限:**
   デフォルトの最大実行時間は 20 秒です。`maxrun` パラメータで延長可能ですが、無限ループやデッドロックを防ぐため適切な上限値を設定する必要があります。
3. **対話型コマンドの制限:**
   EEM の `action cli command` はプロンプト対話（例: `destination filename [y/n]?`）で自動的にデフォルト（Enter 押下）を返します。対話応答を確実に自動化するには、`pattern` を使用するか、コマンドライン側で確認をスキップするフラグ（例: `file prompt quiet`）を設定しておく必要があります。

---

## 🔄 他技術との関連

* **IP SLA ＆ Object Tracking:**  
  IP SLA プローブの失敗を Object Tracking が検知し、その Down イベントを EEM がトリガーとして捕捉することで、高機能なカスタム自動切り替えを実現します。
* **Control Plane Policing (CoPP):**  
  EEM が生成する SNMP トラップや Syslog パケット、あるいは EEM アクションによる大量の CLI 投入が CPU 負荷や CoPP ポリサーに引っかからないよう注意が必要です。
* **On-Box Python (Guestshell):**  
  EEM Applet から `action 1.0 cli command "guestshell run python3 /flash/script.py"` のように On-Box Python スクリプトを直接呼び出すことで、複雑な JSON/XML パースや外部 Web API 連携が可能になります。

---

## 🧩 比較表: EEM Applet vs 他の自動化アプローチ

| 比較項目 | EEM Applet | EEM Tcl Script | On-Box Python (Guestshell) | Off-Box Automation (Ansible/Python) |
| :--- | :--- | :--- | :--- | :--- |
| **定義場所** | Cisco IOS XE CLI 内 | 外部 `.tcl` ファイル | Guestshell Linux / IOS XE | 外部管理サーバ / PC |
| **トリガー方式** | イベント駆動 (Syslog/Track等)| イベント駆動 | EEM 連動 / Cron / 手動 | NMS / CI/CD スケジュール |
| **記述言語** | IOS XE EEM CLI 構文 | Tcl Scripting | Python 3.x | Python / YAML / Ansible |
| **設定の容易性**| **高（極めて簡単）** | 中（Tcl の知識が必要） | 中〜高（Python 知識が必要）| 高（Playbook 構造） |
| **文字列・複雑パース**| 限定的 (`string match`/`regexp`)| 強力 | **非常に強力 (Python ライブラリ)** | **非常に強力** |
| **適用場面** | 機器単体の即時障害リカバリ | 複雑なローカル制御スクリプト | API 連携・データ高度パース | 複数機器の一括構成変更・状態監査 |

---

## 💡 ベストプラクティス

1. **`authorization bypass` の活用:** AAA 認証・認可が有効な環境では、EEM の CLI アクションが TACACS+ 認可でブロックされるリスクを防ぐため、`event manager applet <NAME> authorization bypass` を指定する。
2. **明示的な `enable` ➔ `configure terminal` ➔ `end` の記述:** モード遷移を曖昧にせず、コンフィグモードへの進入と退出を完全に記述する。
3. **明確で一貫したアクションラベルの設計:** `action 1.0`, `action 2.0` のように小数第 1 位までのラベルを使用し、後から間に処理（例: `action 1.5`）を挿入できるように余白を残す。
4. **無限ループ対策の徹底:** EEM が発行するアクションコマンドが自らトリガーする Syslog パターンに引っかからないよう、正規表現を厳格に指定する。


## 📝 ラボ学習・設定サンプル例

実戦的な CCIE EI ラボ試験レベルの EEM Applet 設定サンプル例を 10 個掲載します。すべて省略なしの完全コンフィグです。

---

### ラボ 1: BGP Peer Down トラッキング ＆ 自動インターフェイスリバウンド＋診断ログ保存

#### 1. 問題 ＆ 要件
* BGP ピア `192.168.12.2` が Down した場合（Syslog `BGP-5-ADJCHANGE` にて `Down` を検知）、自装置の対向インターフェイス `GigabitEthernet0/1` を自動的に `shutdown` ➔ `no shutdown` リバウンドさせよ。
* リバウンド実行直前の `show ip bgp summary` の出力を Flash ドライブ上の `flash:bgp_fail_log.txt` ファイルに追記保存せよ。
* EEM 自身によるリバウンド動作で発生する Syslog によって EEM が無限再帰呼び出し（無限ループ）を起こさないよう保護せよ。

#### 2. 設定例
```bash
event manager applet BGP_FAIL_RECOVERY authorization bypass
 event syslog pattern "%BGP-5-ADJCHANGE: neighbor 192.168.12.2 Down" maxrun 30
 action 1.0 cli command "enable"
 action 2.0 cli command "show ip bgp summary"
 action 3.0 file open f1 flash:bgp_fail_log.txt a+
 action 3.1 file write f1 "$_cli_result"
 action 3.2 file close f1
 action 4.0 cli command "configure terminal"
 action 4.1 cli command "interface GigabitEthernet0/1"
 action 4.2 cli command "shutdown"
 action 4.3 cli command "no shutdown"
 action 4.4 cli command "end"
 action 5.0 syslog priority alert msg "EEM: Interface Gi0/1 rebounded due to BGP Peer 192.168.12.2 Down!"
```

#### 3. 検証方法
1. 対向 BGP ピア側で BGP プロセスを停止またはインターフェイスを物理ダウンさせ、`%BGP-5-ADJCHANGE: neighbor 192.168.12.2 Down` Syslog を発生させる。
2. `show event manager history events` を実行し、Applet `BGP_FAIL_RECOVERY` が起動したことを確認。
3. `more flash:bgp_fail_log.txt` を実行し、BGP 切断時の要約ログが保存されていることを確認。

---

### ラボ 2: IP SLA ＆ Object Tracking Down 連動による HSRP 優先度ダイナミック調整 ＆ Syslog 通知

#### 1. 問題 ＆ 要件
* Object Tracking 10 (IP SLA 1 宛先到達性) が Down した場合、HSRP グループ 1 のアクティブ優先度を下げるため、EEM 経由で HSRP 優先度を `110` から `90` へ動的変更せよ。
* Track 10 が Up に復旧した場合は、HSRP 優先度を元の `110` へ戻せ。
* それぞれの状態変更時に、緊急優先度（`priority critical`）でカスタム Syslog メッセージを出力せよ。

#### 2. 設定例
```bash
! HSRP 優先度ダウン用 EEM
event manager applet HSRP_PRIORITY_DOWN authorization bypass
 event track 10 state down
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 2.1 cli command "interface GigabitEthernet0/1"
 action 2.2 cli command "standby 1 priority 90"
 action 2.3 cli command "end"
 action 3.0 syslog priority critical msg "EEM: Track 10 DOWN! HSRP Group 1 priority lowered to 90."

! HSRP 優先度リストア用 EEM
event manager applet HSRP_PRIORITY_UP authorization bypass
 event track 10 state up
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 2.1 cli command "interface GigabitEthernet0/1"
 action 2.2 cli command "standby 1 priority 110"
 action 2.3 cli command "end"
 action 3.0 syslog priority critical msg "EEM: Track 10 UP! HSRP Group 1 priority restored to 110."
```

#### 3. 検証方法
1. IP SLA 1 宛先のネクストホップを停止し、Track 10 を Down させる。
2. `show standby brief` を実行し、GigabitEthernet0/1 の HSRP Priority が 90 に変更されたことを確認。
3. IP SLA 1 宛先を復旧させ、Track 10 が Up になると Priority が 110 に自動復帰することを確認。

---

### ラボ 3: 特定 CLI コマンド（`reload` や `no router bgp`）のインターセプト ＆ 実行防止（`sync yes skip yes`）

#### 1. 問題 ＆ 要件
* コンソールまたは VTY セッションにおいて、オペレータが誤って `reload` コマンドを投入した場合、そのコマンドの実行をインターセプト（横取り）して破棄（ブロック）せよ。
* 画面上に `CRITICAL: Reload command is disabled by EEM policy!` というメッセージを表示し、Syslog を発行せよ。

#### 2. 設定例
```bash
event manager applet BLOCK_RELOAD authorization bypass
 event cli pattern "reload" sync yes
 action 1.0 syslog priority alert msg "EEM: Unauthorized reload command intercepted and blocked!"
 action 2.0 puts "CRITICAL: Reload command is disabled by EEM policy!"
 action 3.0 set $_exit_status "0"
```

#### 3. 検証方法
1. 特権 EXEC モードで `reload` を実行する。
2. コマンドが即座にブロックされ、画面にメッセージが表示され、再起動が行われないことを確認。
3. `show log` で警告 Syslog の発行を確認。

---

### ラボ 4: タイマー（Cron 式 / Periodic）による定期的な `show` コマンド出力の Flash 自動バックアップ

#### 1. 問題 ＆ 要件
* 毎日深夜 0 時 0 分（Cron 形式 `0 0 * * *`）に、自動的に `show running-config` の出力を `flash:daily_config_backup.cfg` へ上書き保存せよ。
* 保存完了時に、バックアップ完了を意味する Syslog メッセージを出力せよ。

#### 2. 設定例
```bash
event manager applet DAILY_CONFIG_BACKUP authorization bypass
 event timer cron cron-entry "0 0 * * *"
 action 1.0 cli command "enable"
 action 2.0 cli command "copy running-config flash:daily_config_backup.cfg" pattern "filename"
 action 2.1 cli command "daily_config_backup.cfg"
 action 3.0 syslog priority info msg "EEM: Daily running-config backup completed successfully."
```

#### 3. 検証方法
1. テスト用に一時的に `event timer watchdog time 10` （10秒周期）へ変更するか、`event manager run DAILY_CONFIG_BACKUP` を実行して手動テスト。
2. `dir flash:daily_config_backup.cfg` でファイルの存在を確認。
3. `more flash:daily_config_backup.cfg` で最新コンフィグがバックアップされていることを確認。

---

### ラボ 5: OSPF ネイバーフラッピング検知 ＆ デバッグログ自動採取 ＆ EEM 無限ループ抑止

#### 1. 問題 ＆ 要件
* OSPF ネイバー `10.1.1.2` が `FULL` から `DOWN` へ状態変化した場合（Syslog `%OSPF-5-ADJCHG: Process 1, Nbr 10.1.1.2 on GigabitEthernet0/2 from FULL to DOWN`）、即座に `show ip ospf neighbor` と `show ip route ospf` の出力を取得し、`flash:ospf_flap.log` に保存せよ。
* 同一アプレット内でのログ採取動作によって EEM が再トリガーされないよう、正規表現パターンを特定ネイバー IP `10.1.1.2` に厳密限定せよ。

#### 2. 設定例
```bash
event manager applet OSPF_FLAP_CAPTURE authorization bypass
 event syslog pattern "%OSPF-5-ADJCHG: Process 1, Nbr 10.1.1.2 on GigabitEthernet0/2 from FULL to DOWN" maxrun 30
 action 1.0 cli command "enable"
 action 2.0 cli command "show ip ospf neighbor"
 action 3.0 set $neighbor_output "$_cli_result"
 action 4.0 cli command "show ip route ospf"
 action 5.0 set $route_output "$_cli_result"
 action 6.0 file open f1 flash:ospf_flap.log a+
 action 6.1 file write f1 "=== OSPF FLAP DETECTED AT $_event_pub_time ===
"
 action 6.2 file write f1 "--- NEIGHBOR STATUS ---
$neighbor_output
"
 action 6.3 file write f1 "--- OSPF ROUTES ---
$route_output
"
 action 6.4 file close f1
 action 7.0 syslog priority warning msg "EEM: OSPF Neighbor 10.1.1.2 Flap diagnostic captured."
```

#### 3. 検証方法
1. OSPF ピア `10.1.1.2` 側のインターフェイスを `shutdown` して Down させる。
2. `more flash:ospf_flap.log` を実行し、タイムスタンプ付きで OSPF 隣接関係とルート情報が正確に記録されていることを確認。


### ラボ 6: CPU 使用率高騰（Syslog / SNMP）時の特定プロセスダンプ ＆ ログ採取

#### 1. 問題 ＆ 要件
* CPU 使用率が閾値を超過したことを示す Syslog メッセージ（`%SYS-1-CPURISINGTHRESHOLD`）を検知した場合、最も CPU を消費しているプロセスを特定するため、`show process cpu sorted | exclude 0.00%` を即座に実行せよ。
* 実行結果を Console 画面に表示するとともに、Syslog に上位プロセスの概要を出力せよ。

#### 2. 設定例
```bash
event manager applet CPU_SPIKE_DIAGNOSTIC authorization bypass
 event syslog pattern "%SYS-1-CPURISINGTHRESHOLD" maxrun 20
 action 1.0 cli command "enable"
 action 2.0 cli command "show process cpu sorted | exclude 0.00%"
 action 3.0 puts "$_cli_result"
 action 4.0 file open f1 flash:cpu_spikes.log a+
 action 4.1 file write f1 "=== CPU SPIKE DETECTED ===
$_cli_result
"
 action 4.2 file close f1
 action 5.0 syslog priority critical msg "EEM: CPU Spike process dump captured to flash:cpu_spikes.log"
```

#### 3. 検証方法
1. テスト環境で高負荷処理（または `event manager run CPU_SPIKE_DIAGNOSTIC`）をトリガーする。
2. `more flash:cpu_spikes.log` で CPU プロセス出力が保存されていることを検証。

---

### ラボ 7: インターフェイス CRC エラー・Input Drop 増加時の自動シャットダウン ＆ 管理者警報

#### 1. 問題 ＆ 要件
* インターフェイス `GigabitEthernet0/1` でエラーが発生し、Syslog `%LINK-3-UPDOWN` または特定エラーの発生を条件として、ポートの物理状態を監視せよ。
* ポートを安全のため自動的に `shutdown` し、管理者に警告 Syslog を出力せよ。

#### 2. 設定例
```bash
event manager applet PORT_ERROR_SHUTDOWN authorization bypass
 event syslog pattern "%PORT-5-IF_DOWN_INTERFACE_ERROR: GigabitEthernet0/1" maxrun 20
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 2.1 cli command "interface GigabitEthernet0/1"
 action 2.2 cli command "shutdown"
 action 2.3 cli command "end"
 action 3.0 syslog priority emergency msg "EEM: Gi0/1 disabled due to critical interface hardware errors!"
```

#### 3. 検証方法
1. エラーシミュレーション Syslog をテスト発生させ、`GigabitEthernet0/1` が自動的に `shutdown` になることを確認。

---

### ラボ 8: EEM Applet から On-Box Python スクリプト (`guestshell` / `cli`) の自動呼び出し・連携

#### 1. 問題 ＆ 要件
* Syslog で特定イベント（`%SYS-5-CONFIG_I` コンフィグ変更）が発生した際に、IOS XE 内部の Guestshell 内で準備された Python スクリプト `/flash/parse_config.py` を自動的に実行せよ。

#### 2. 設定例
```bash
event manager applet TRIGGER_PYTHON_SCRIPT authorization bypass
 event syslog pattern "%SYS-5-CONFIG_I: Configured from" maxrun 60
 action 1.0 cli command "enable"
 action 2.0 cli command "guestshell run python3 /flash/parse_config.py"
 action 3.0 syslog priority info msg "EEM: On-Box Python script parse_config.py executed successfully."
```

#### 3. 検証方法
1. `configure terminal` ➔ `exit` でコンフィグ変更を行い、`SYS-5-CONFIG_I` Syslog を発行させる。
2. `show event manager history events` で Python スクリプト呼び出し EEM が成功したことを確認。

---

### ラボ 9: EEM 複数条件分岐（`action 1.0 if`, `action 2.0 else`）による結果判定と復旧処理

#### 1. 問題 ＆ 要件
* 手動トリガー（`event none`）にて `show ip interface brief` を実行し、出力の中に `unassigned` の IP アドレスを持つインターフェイスが存在するかどうか判定せよ。
* 存在する場合は警告 Syslog を発行し、存在しない場合は正常ログを出力せよ。

#### 2. 設定例
```bash
event manager applet CHECK_UNASSIGNED_IP authorization bypass
 event none
 action 1.0 cli command "enable"
 action 2.0 cli command "show ip interface brief"
 action 3.0 string match "*unassigned*" "$_cli_result"
 action 4.0 if $_string_result eq "1"
 action 4.1  syslog priority warning msg "EEM: Unassigned IP interfaces detected on this device!"
 action 5.0 else
 action 5.1  syslog priority info msg "EEM: All interfaces have assigned IP addresses."
 action 6.0 end
```

#### 3. 検証方法
1. `event manager run CHECK_UNASSIGNED_IP` を手動実行。
2. `show log` を確認し、`unassigned` の有無に応じたメッセージが正しく出力されていることを検証。

---

### ラボ 10: Multiple Event Tags (`tag` AND/OR 制御) による複合障害検知 ＆ 自動切り替え

#### 1. 問題 ＆ 要件
* Track 100 (回線 A) と Track 200 (回線 B) の **両方が Down した場合 (AND 条件)** にのみ、緊急用バックアップインターフェイス `GigabitEthernet0/3` を `no shutdown` に変更せよ。
* 単一の Track Down では実行させない複合条件制御 (`attribute tag`) を実装せよ。

#### 2. 設定例
```bash
event manager applet DUAL_TRACK_FAILOVER authorization bypass
 event track 100 state down tag T1
 event track 200 state down tag T2
 attribute tag T1 and T2
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 2.1 cli command "interface GigabitEthernet0/3"
 action 2.2 cli command "no shutdown"
 action 2.3 cli command "end"
 action 3.0 syslog priority emergency msg "EEM: BOTH Track 100 and 200 DOWN! Emergency Gi0/3 activated."
```

#### 3. 検証方法
1. Track 100 のみを Down させても Gi0/3 が Up にならないことを確認。
2. 続けて Track 200 も Down させると、AND 条件が満たされ、Gi0/3 が即座に `no shutdown` されることを確認。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
以下のコンフィグが投入されたルータにおいて、BGP セッション切断時に EEM が予期せず無限ループに陥り、CPU 使用率が 100% に高騰しました。その技術的理由と修正コンフィグを答えなさい。

```bash
event manager applet BAD_BGP
 event syslog pattern "BGP"
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 3.0 cli command "router bgp 65000"
 action 4.0 cli command "clear ip bgp *"
 action 5.0 cli command "end"
```

* **解答・解説:**  
  **原因:** `event syslog pattern "BGP"` という正規表現が広範すぎるため、`action 4.0` の `clear ip bgp *` によって発行されるすべての BGP 関連 Syslog（`%BGP-5-ADJCHANGE` 等）に再反応し、EEM が無限に再起動を繰り返したため。  
  **修正例:**
  ```bash
  event manager applet BAD_BGP
   event syslog pattern "%BGP-5-ADJCHANGE: neighbor 10.1.1.1 Down"
   action 1.0 cli command "enable"
   ...
  ```

---

### 問 2 (実装)
オペレータが CLI で `no ip routing` と入力した際、そのコマンドの実行を即座に破棄（ブロック）し、画面上に `IP Routing cannot be disabled!` と表示する EEM Applet コンフィグを記述しなさい。

* **解答・解説:**
  ```bash
  event manager applet BLOCK_NO_IP_ROUTING authorization bypass
   event cli pattern "no ip routing" sync yes
   action 1.0 syslog priority alert msg "EEM: Blocked attempt to disable IP routing!"
   action 2.0 puts "IP Routing cannot be disabled!"
   action 3.0 set $_exit_status "0"
  ```

---

### 問 3 (Design / アーキテクチャ)
EEM アプレットにおいて、デフォルトの実行制限時間である `maxrun` (20秒) を超える長時間のトラブルシューティングログ収集処理（多量の Ping や詳細な Show コマンド実行）を行う場合のベストプラクティスを 2 つ述べよ。

* **解答・解説:**
  1. イベント定義行において `maxrun` タイマー明示的に拡大する（例: `event syslog pattern "..." maxrun 120`）。
  2. 長時間処理や複雑な文字列処理を行う場合は、EEM 内で直接 CLI を多用せず、EEM から On-Box Python スクリプト（Guestshell）を呼び出してバックグラウンド非同期処理させる。

---

### 問 4 (トラブルシューティング)
EEM アプレットで `action 1.0 cli command "interface GigabitEthernet0/1"` ➔ `action 2.0 cli command "shutdown"` を記述したが、`show event manager history events` でエラーが記録され、インターフェイスがシャットダウンしなかった。原因と対策を述べよ。

* **解答・解説:**  
  **原因:** EEM の CLI アクションはデフォルトで特権 EXEC モード（`enable`）で開始されるため、グローバルコンフィギュレーションモードへ移行する `configure terminal` が欠落していたことによる構文エラー。  
  **対策:** `action 1.0 cli command "enable"` の後に `action 1.5 cli command "configure terminal"` を追加挿入する。

---

### 問 5 (コンフィグ読解)
以下の EEM コンフィグにおける `attribute tag T1 and T2` の役割について説明せよ。

```bash
event manager applet MULTI_FAIL
 event track 1 state down tag T1
 event track 2 state down tag T2
 attribute tag T1 and T2
 action 1.0 syslog msg "Both Tracks are Down"
```

* **解答・解説:**  
  `tag T1` (Track 1 Down) と `tag T2` (Track 2 Down) の両方のイベントが**同時に満たされた場合（論理積 AND）**にのみ、この EEM アプレットを起動するように複数イベント条件を制御する役目を持つ。

---

## 🔗 参考リソース

* Cisco Systems, "Cisco IOS XE 17.x Embedded Event Manager Configuration Guide"
* Cisco Systems, "Cisco Command Reference - Embedded Event Manager Commands"
* Cisco Live BRKARC-2012, "Network Automation with EEM and Python on IOS XE"
* Cisco Technical Notes, "Troubleshooting EEM Applets and Preventing Infinite Loops"

---

## 📝 補足（Notes）

* **CCIE EI ラボ試験における EEM 攻略の秘訣:**  
  試験中に EEM Applet を作成した後は、必ず `show event manager policy registered` で登録内容を確認し、テストイベントを実際に発生させるか `event manager run <NAME>` で動作検証を行ってください。
* **AAA 認可バイパス (`authorization bypass`):**  
  ラボ環境で AAA 認可（`aaa authorization exec`）が有効化されている場合、EEM による CLI 投入が拒否されるケースがあります。作成するすべての Applet に `authorization bypass` を付与する癖をつけておくと安全です。


## 📝 補足
- この学習メモは、CCIE EI 実技試験において **「デバイスを単なるパケット転送機から、インテリジェントな自律運用ノードへ進化させる」** ための EEM 活用法を網羅しています。ラボ試験では、複雑なトラブルシューティング要件を EEM の「イベント」と「アクション」の論理に正しくマッピングできることが合格への鍵となります。

