---
layout: default
title: 4.3.c-Logging
parent: 4.3-System-management
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.3.c Logging

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.3.c Logging` [(i) Local logging, syslog, debugs, conditional debugs, (ii) Configuration change notification and logging, (iii) Timestamps] に関する Cisco IOS XE 17.x 準拠の完全学習メモ。

---

## 📘 概要

ロギング（Logging）および変更通知機能は、ネットワークインフラストラクチャにおける稼働状況のリアルタイム監視、セキュリティ監査、障害切り分け（Troubleshooting）、およびコンフィグ変更履歴追跡の根幹をなす管理機能である。

* **Local Logging (Buffered / Console / Monitor / Flash Logging):**
  * **Buffered Logging (`logging buffered`):** ルータの RAM 上に割り当てられた循環バッファ（Circular Buffer）へログメッセージを保存する。再起動で消失するが、`show logging` コマンドで即座にインシデント履歴を分析可能。
  * **Console / Monitor Logging (`logging console` / `logging monitor`):** シリアルコンソール端末や SSH/Telnet セッションの画面へログを即時出力する。
  * **Persistent Logging (`logging persistent`):** フラッシュメモリ（`bootflash:`）や外部ストレージにログを書き込み、デバイスの予期せぬ再起動やクラッシュ後もログを保持する。
* **Syslog (`logging host` / `logging server`):**
  * ネットワーク上の中央 Syslog サーバー（NMS / SIEM）へ UDP 514（または TCP 1468 / TLS 6514）を用いてログを集中転送する。
  * 複数機器の時系列イベントを相関分析し、監査および事後解析を可能にする。
* **Debugs & Conditional Debugs (`debug condition` / `debug condition interface` / `debug condition ip`):**
  * リアルタイムのコントロールプレーン/データプレーン処理イベントをログ出力する。
  * **Conditional Debugging (条件付きデバッグ):** 特定の IP アドレス、MAC アドレス、インターフェイス、VLAN、VPN コンテキストに合致するパケット/イベントのみを絞り込んでデバッグを実行する。高負荷環境において CPU 100% 固着（Crash）やコンソール応答停止を防止する CCIE ラボでの必須技術。
* **Configuration Change Notification and Logging (`archive` / `log config`):**
  * CLI 上で実行されたコンフィグ操作（投入されたコマンド、実行ユーザー、タイムスタンプ）をローカルバッファに追跡・記録する。
  * **Change Notification:** コンフィグ変更発生時に Syslog メッセージ（`%PARSER-5-CFGLOG_LOGGEDCOMMAND`）や SNMP Trap を自動発信し、変更管理の透明性を確保する。
  * **`hidekeys` 機能:** コンフィグ履歴ログ内に平文で記録されかねないパラメータを自動的に難読化遮蔽する。
* **Timestamps (`service timestamps`):**
  * ログメッセージおよびデバッグログにミリ秒精度（`msec`）およびタイムゾーン（`show-timezone`）付きの標準化時刻を付与する。
  * NTP（Network Time Protocol）と同期することで、ネットワーク全体の分散イベントを正確な時系列で比較可能にする。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主な機能** | ローカルバッファ/画面出力、Syslog 集中転送、Conditional Debug、コンフィグ変更監査ログ、高精度タイムスタンプ付与 |
| **用途** | 障害原因の迅速特定、セキュリティ監査、コンフィグ変更追跡、稼働安定性の確保 |
| **メリット** | ミリ秒精度でのイベント相関分析、特定トラフィックのみの安全なデバッグ、平文パラメータのログ露出防止 |
| **デメリット/リスク** | 無制限な `debug all` や大規模ログの `logging console` 実行による CPU 飽和・応答不能（Crash） |
| **対応機種** | Cisco Catalyst 9000 シリーズ, ISR 4000 シリーズ, ASR 1000 シリーズ, Catalyst 8000 シリーズ (Cisco IOS XE) |
| **制限事項** | Buffered Logging は再起動で消滅（Persistent 指定が必要）、Syslog (UDP 514) はベストエフォート転送 |
| **設計上の注意点** | `logging console` のレベル制限、Syslog 送信における VRF (`vrf Mgmt-vrf`) 指定、`service timestamps log datetime msec` の必須定義 |

---

## 🏗 動作原理

### 1. Cisco IOS XE ログ処理パイプライン

```text
[ イベント発生 (リンクダウン / ログイン / コマンド実行 / エラー) ]
                         ↓
[ ログメッセージ作成 (ファシリティ / 重要度 / メッセージテキスト) ]
                         ↓
[ タイムスタンプ付与 (service timestamps log datetime msec show-timezone) ]
                         ↓
        ┌────────────────┼────────────────┬────────────────┐
        ▼                ▼                ▼                ▼
 [ Buffered Log ]  [ Console/Monitor ]  [ Syslog Host ]  [ Persistent Log ]
 (RAM 循環バッファ)   (シリアル/SSH画面)   (UDP 514 / VRF)  (bootflash: 永続化)
```

### 2. Conditional Debugging の動作フロー

```text
[ デバッグコマンド実行: debug ip ospf adj ]
                         ↓
[ 条件指定なしの場合 ] ──► ルータ上の全 OSPF インターフェイスのイベントを処理 ──► [ CPU 100% 飽和リスク! ]
                         ↓
[ 条件指定ありの場合 ] ──► debug condition interface Gi0/0/1 を事前設定
                         ↓
[ デバッグエンジン評価 ] ──► パケット/イベントの入出力 I/F が Gi0/0/1 に合致するか？
                               ├── YES ──► デバッグメッセージを出力
                               └── NO  ──► メッセージ破棄 (CPU 負荷を最小限に抑制)
```

### 3. Archive Configuration Change Logging 評価シーケンス

```text
[ 管理者が特権 EXEC または Global Config モードでコマンドを実行 ]
                         ↓
[ コマンドパーサーによるコマンド解釈 ]
                         ↓
[ archive / log config ディレクティブによる記録判定 ]
                         ├── hidekeys 有効 ──► パラメータ文字列を隠蔽置換
                         └── hidekeys 無効 ──► 生テキストのままログ保持
                         ↓
[ ローカル変更バッファへの記録 (ユーザー名 / 端末 / タイムスタンプ / コマンド) ]
                         ↓
[ Syslog 通知 (%PARSER-5-CFGLOG_LOGGEDCOMMAND) および SNMP Trap 送信 ]
```

---

## ⚙ 動作シーケンス

### Syslog 転送およびタイムスタンプ処理シーケンス

1. **イベント発生:** インターフェイスのダウンやログイン失敗などのシステムイベントが発生する。
2. **メッセージ整形 ＆ タイムスタンプ付与:** 
   * `service timestamps log datetime msec show-timezone localtime` 設定に従い、NTP 同期されたローカル時刻（ミリ秒単位 ＋ タイムゾーン名）がログ先頭に付与される。
   * シベリティレベル（Severity Level: 0～7）およびファシリティ（Facility）が割り当てられる。
3. **ローカル出力 ＆ バッファリング:**
   * `logging buffered <SIZE> <LEVEL>` で定義されたサイズに従い、RAM 上のログバッファに書き込まれる。
   * `logging console` および `logging monitor` の制限レベルを満たす場合、該当画面へリアルタイム表示される。
4. **Syslog パケットカプセル化 ＆ 転送:**
   * `logging host <IP> vrf <VRF>` で指定された送信先に対し、指定されたソースインターフェイス（`logging source-interface`）の IP アドレスを送信元として UDP 514（Syslog）パケットが送出される。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. ラボ試験で重要なポイント
* **`service timestamps` の完全指定:** 
  * ラボ問題文で「ログおよびデバッグ出力にミリ秒単位のタイムスタンプとタイムゾーンを含めよ」と指示された場合、`service timestamps log datetime msec show-timezone` および `service timestamps debug datetime msec show-timezone` の両方を設定する必要がある。
* **Conditional Debugging による障害調査:**
  * 大規模構成のトラブルシューティングにおいて、無条件のデバッグを実行するとルータがフリーズし採点不能（失点）となるリスクが高い。必ず `debug condition` (IP, Interface, VRF) を組み合わせて実行する。
* **Management VRF 経由の Syslog 転送:**
  * OOB（Out-of-Band）管理網として `Mgmt-vrf` が使用されている環境では、単に `logging host 10.1.1.50` と設定してもパケットが送出されない。必ず `logging host 10.1.1.50 vrf Mgmt-vrf` を指定する。
* **Archive Change Logging と `hidekeys`:**
  * 「コンフィグ変更ログを有効化し、ログ内に平文パラメータが記録されないように構成せよ」という要件に対し、`archive` 配下で `log config` ➔ `logging enable` ➔ `hidekeys` を正確に定義できるか。

### 2. よくある設定ミス ＆ 狙われやすい落とし穴
* **`logging console` を忘れたまま高レベル指定:** 高負荷時にコンソール出力でルータがフリーズするのを防ぐため、`logging console critical` または `logging console errors` などレベルを絞り込む。
* **`terminal monitor` の未実行:** SSH/Telnet 接続時に `debug` やログが出力されない問題で焦るケース。特権 EXEC で `terminal monitor` を実行しなければリモートセッションにログは表示されない。
* **Conditional Debug の解除忘れ:** 検証終了後に `no debug all` を実行しても、`debug condition` 自体はクリアされない（`show debug condition` に残り続ける）。条件を削除するには `clear debug condition all` を実行する必要がある。

### 3. show コマンドによる状態判断
* `show logging`: 現在のログバッファ内容、各出力先（Console, Monitor, Buffered, Host）の有効化状態、ドロップパケット数、設定されているタイムスタンプ形式を確認。
* `show debug`: 現在有効化されているデバッグフラグ一覧。
* `show debug condition`: 現在アクティブなデバッグ条件（Interface, IP, VRF 等）の一覧。
* `show archive log config all`: ローカルバッファに記録されたコンフィグ変更履歴（実行者、コマンド、日時）の確認。

---


## 🛠 設定方法

### 1. 基本ロギング ＆ タイムスタンプの完全設定

```bash
! --- タイムスタンプの設定 (ミリ秒精度 ＋ タイムゾーン表示) ---
service timestamps log datetime msec show-timezone localtime
service timestamps debug datetime msec show-timezone localtime

! --- ローカルバッファロギングの設定 (バッファサイズ: 128KB, レベル: Debugging) ---
logging buffered 131072 debugging

! --- コンソール出力制限 (フリーズ防止のため Errors 以上に制限) ---
logging console errors

! --- ターミナルモニター出力制限 ---
logging monitor informational

! --- ログメッセージへの送信元 IP / 順序番号の付加 ---
service sequence-numbers
logging facility local7
logging source-interface GigabitEthernet1/0/1
```

### 2. Syslog サーバー転送 ＆ Management VRF 指定

```bash
! --- Syslog サーバーへの送信設定 (VRF: Mgmt-vrf, 送信レベル: Informational) ---
logging host 10.1.1.50 vrf Mgmt-vrf
logging trap informational
```

### 3. Conditional Debugging (条件付きデバッグ) の構成

```bash
! --- 特定のインターフェイス (Gi0/0/1) のみをデバッグ条件に指定 ---
debug condition interface GigabitEthernet0/0/1

! --- 特定の対向 IP アドレス (192.168.10.1) のみをデバッグ条件に指定 ---
debug condition ip 192.168.10.1

! --- 目的のデバッグを有効化 ---
debug ip ospf adj
debug ip packet

! --- 条件の確認 ---
! show debug condition
```

### 4. Configuration Change Notification and Logging (`archive`)

```bash
! --- コンフィグ変更ログの構成 ---
archive
 log config
  logging enable
  logging size 500
  hidekeys
  notify syslog
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **ログバッファ ＆ 状態確認** | `show logging` |
| **デバッグ状態の確認** | `show debug` |
| **アクティブなデバッグ条件の確認** | `show debug condition` |
| **コンフィグ変更履歴の確認** | `show archive log config all` |
| **コンフィグ変更ログ統計の確認** | `show archive log config summary` |
| **特定ユーザーの変更履歴確認** | `show archive log config user <USERNAME>` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **SSH/Telnet 画面にデバッグログが表示されない** | 該当セッションで `terminal monitor` が実行されていない | `show logging` (Monitor logging 項目) | 特権 EXEC モードで `terminal monitor` を実行する |
| **高負荷時にコンソールが応答停止（フリーズ）する** | 大量のログがコンソールへ出力されている | `show logging` | `logging console errors` 等に指定レベルを引き上げる |
| **Syslog サーバーへログが到達しない** | 送信元 VRF ミスマッチ、または Routing / CoPP によるドロップ | `show logging`, `show ip route vrf <VRF>` | `logging host <IP> vrf <VRF>` および `logging source-interface` を適切にバインドする |
| **コンフィグ変更ログにパラメータが露出する** | `archive / log config` 内で `hidekeys` が未設定 | `show archive log config all` | `archive` -> `log config` 配下で `hidekeys` を追加設定する |
| **NTP 同期しているのにログの時刻がずれる** | `service timestamps` コマンドで `datetime` やタイムゾーン指定が欠落している | `show logging` (ログ冒頭の時刻表示) | `service timestamps log datetime msec show-timezone` を再設定する |
| **条件付きデバッグ解除後も不要なデバッグが出続ける** | `no debug all` 実行後も `debug condition` が解除されていない | `show debug condition` | `clear debug condition all` を実行してデバッグ条件を全削除する |

---

## ⚠ 制限事項

* **Buffered Logging の揮発性:** デフォルトの Buffered Logging は RAM 上に保持されるため、リロード（再起動）や電源断によってすべてのログが消失する。永続化が必要な場合は `logging persistent` または外部 Syslog サーバーを併用すること。
* **`hidekeys` の適用範囲:** `hidekeys` 機能は `archive / log config` で記録される変更ログに対してのみ有効である。通常のデバッグログや特定機能のログ内には適用されない。
* **Syslog UDP 転送の非信頼性:** 標準の Syslog 転送は UDP 514 を使用するため、ネットワーク輻輳時にパケットドロップが発生しても再送制御が行われない。

---

## 🔄 他技術との関連

* **NTP (Network Time Protocol):** 正確なタイムスタンプ（`service timestamps`）の前提条件。複数機器の Syslog を時間軸で相関分析するために NTP 同期が必須。
* **CoPP (Control Plane Policing):** デバッグログや Syslog パケット送受信が CoPP ポリシーによってポリシング・ドロップされないよう、CoPP ACL で制御・管理通信を保護する。
* **AAA (Authentication, Authorization, Accounting):** `archive / log config` は AAA 認証されたユーザー情報をコンフィグ変更ログに記録する。
* **Management VRF (OOB):** 管理網経由での Syslog 転送時に、データプレーンルーティングと分離された管理テーブル (`Mgmt-vrf`) を指定する。

---

## 🧩 比較表

### ロギング出力先の比較

| 出力先 | 保存場所 | 永続性 | CPU負荷 | 主な用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Console (`logging console`)** | シリアルポート | なし | **極めて高い** | デバイス初期構築、致命的障害の局所確認 |
| **Monitor (`logging monitor`)** | SSH/VTY セッション | セッション切断まで | 中程度 | リモートからのリアルタイムトラブルシューティング |
| **Buffered (`logging buffered`)** | RAM (Circular Buffer) | 再起動で消失 | 低い | 常時アクティブなトラブルシューティング |
| **Syslog (`logging host`)** | 外部 Syslog サーバー | **永続的** (NMS側) | 低い～中程度 | 長期保管、セキュリティ監査、SIEM 相関分析 |
| **Persistent (`logging persistent`)**| ローカル Flash / Disk | **永続的** | 中程度 | ネットワーク断絶時のローカル事故調査 |

---

## 💡 ベストプラクティス

1. **タイムスタンプの標準化:** 全デバイスで `service timestamps log datetime msec show-timezone` および `service timestamps debug datetime msec show-timezone` を統一設定する。
2. **コンソール出力の制限:** コンソールへは `errors` または `critical` 以上の高重要度メッセージのみを出力させ、不要な CPU 負荷を回避する (`logging console errors`)。
3. **安全なデバッグ運用:** トラブルシューティング時は必ず `debug condition` (Interface / IP) を適用して対象トラフィックを限定し、作業終了後は `undebug all` と `clear debug condition all` を漏れなく実行する。
4. **コンフィグ監査の有効化:** 全ルータで `archive / log config` ＋ `hidekeys` ＋ `notify syslog` を有効化し、誰が・いつ・何を変更したかを自動記録・通知させる。

---


## 📝 ラボ学習・設定サンプル例

### ラボ 1: ミリ秒精度タイムスタンプ ＆ Buffered Logging 128KB 構成

* **問題:** ルータ R1 において、ログバッファサイズを 128KB に拡張し、全てのログメッセージおよびデバッグ出力にミリ秒精度およびローカルタイムゾーン（`show-timezone`）付きのタイムスタンプを付与せよ。
* **要件:**
  * バッファサイズは 131072 バイトとすること。
  * タイムスタンプにはミリ秒（`msec`）およびタイムゾーンを表示すること。
  * コンソールへのログ出力は `errors` 以上に制限すること。
* **設定例:**
```bash
service timestamps log datetime msec show-timezone localtime
service timestamps debug datetime msec show-timezone localtime
logging buffered 131072 debugging
logging console errors
```
* **検証方法:**
  * `show logging` を実行し、`Logging Buffered (131072 bytes)` と表示されることを確認。
  * ログのタイムスタンプが `*Oct 17 10:15:30.123 JST:` の形式になっていることを確認。

---

### ラボ 2: Management VRF 経由 Syslog 集中転送 ＆ ソース I/F 指定構成

* **問題:** R1 上のログ（Informational レベル以上）を、OutOfBand 管理網（VRF: `Mgmt-vrf`）経由で Syslog サーバー（`10.1.1.50`）へ転送せよ。送信元 IP は `GigabitEthernet0/0` の IP アドレスとすること。
* **要件:**
  * 送信先 IP: `10.1.1.50`
  * VRF: `Mgmt-vrf`
  * 送信レベル: `informational`
  * ソースインターフェイス: `GigabitEthernet0/0`
* **設定例:**
```bash
logging source-interface GigabitEthernet0/0
logging host 10.1.1.50 vrf Mgmt-vrf
logging trap informational
```
* **検証方法:**
  * `show logging` を実行し、`Logging to 10.1.1.50 (vrf Mgmt-vrf) (udp port 514, audit disabled)` が `enabled` になっていることを確認。
  * Syslog サーバー側でパケットが受信できていることを確認。

---

### ラボ 3: Conditional Debugging (インターフェイス限定デバッグ) 構成

* **問題:** ネットワーク上で大量の OSPF パケットが行き交う環境において、インターフェイス `GigabitEthernet0/0/1` 上の OSPF 隣接関係イベントのみを安全にデバッグ調査せよ。
* **要件:**
  * 他のインターフェイスの OSPF パケットはデバッグ出力させないこと。
  * `debug condition` を使用すること。
* **設定例:**
```bash
! 条件の設定
debug condition interface GigabitEthernet0/0/1

! デバッグの有効化
debug ip ospf adj
```
* **検証方法:**
  * `show debug condition` を実行し、`Condition 1: interface Gi0/0/1 (1 flags set)` がアクティブであることを確認。
  * `Gi0/0/1` 上で OSPF フラッピングを発生させ、該当インターフェイスのデバッグのみが表示されることを確認。

---

### ラボ 4: Conditional Debugging (対向 IP アドレス限定デバッグ) 構成

* **問題:** 対向ルータ `192.168.10.2` との間で送受信される IP パケットのみをピンポイントでデバッグ記録せよ。
* **要件:**
  * 対向 IP `192.168.10.2` 以外のトラフィックログを抑制すること。
* **設定例:**
```bash
! IP アドレス条件の適用
debug condition ip 192.168.10.2

! IP パケットデバッグの有効化
debug ip packet
```
* **検証方法:**
  * `show debug condition` を実行し、IP `192.168.10.2` が条件登録されていることを確認。
  * `192.168.10.2` 宛ての Ping を実行した際のみデバッグログが出力されることを検証。

---

### ラボ 5: Archive Change Notification ＆ 難読化 (`hidekeys`) 構成

* **問題:** ルータ上での CLI コンフィグ変更履歴を追跡・保持する設定を行え。ログ内に入力された暗号鍵が平文で記録されないよう自動難読化せよ。
* **要件:**
  * `archive` 機能を使用すること。
  * 保持サイズは 200 コマンドとすること。
  * 隠蔽設定（`hidekeys`）を有効化すること。
  * 変更発生時に Syslog メッセージを自動出力すること。
* **設定例:**
```bash
archive
 log config
  logging enable
  logging size 200
  hidekeys
  notify syslog
```
* **検証方法:**
  * コマンドを実行後、`show archive log config all` を実行し、ログが難読化表示されていることを確認。
  * Syslog に `%PARSER-5-CFGLOG_LOGGEDCOMMAND` が出力されたことを確認。

---

### ラボ 6: Remote SSH セッションでの Terminal Monitor 自動有効化テクニック

* **問題:** 運用の利便性を高めるため、特定セッションで SSH ログインした際、自動的に画面ログ出力（`terminal monitor` 相当）が有効化されるように EEM アプリレットを構成せよ。
* **要件:**
  * ユーザーの特権 EXEC ログイン成功イベントをトリガーとすること。
* **設定例:**
```bash
event manager applet AUTO_TERM_MONITOR
 event syslog pattern "TTY.*GNS3.*LoggedIn"
 action 1.0 cli command "enable"
 action 2.0 cli command "terminal monitor"
```
* **検証方法:**
  * SSH でログイン後、特権 EXEC モードにてデバッグを出力させ、`terminal monitor` を手動設定せずともログが表示されることを確認。

---

### ラボ 7: 永続的ログ (Persistent Logging) 構成

* **問題:** 突然のクラッシュや電源遮断が発生した場合でも、直前のログを `bootflash:` 上に保存・保持できるように構成せよ。
* **要件:**
  * ログ保存先ディレクトリ: `bootflash:/syslog`
  * 割り当て容量: 10MB
* **設定例:**
```bash
logging persistent url bootflash:/syslog filesize 10485760
```
* **検証方法:**
  * `dir bootflash:/syslog` を実行し、ログファイル群が生成されていることを確認。

---

### ラボ 8: シークエンスナンバー ＆ ファシリティ追記構成

* **問題:** SIEM ツールでの解析を容易にするため、Syslog メッセージにシーケンス番号を付与し、Facility を `local5` に設定せよ。
* **要件:**
  * `service sequence-numbers` を有効化すること。
  * Facility に `local5` を指定すること。
* **設定例:**
```bash
service sequence-numbers
logging facility local5
```
* **検証方法:**
  * 発生したログの先頭に `000012: *Oct 17...` のように連番（Sequence Number）が付与されていることを確認。

---

### ラボ 9: VRF-Aware Conditional Debugging 構成

* **問題:** 特定の VRF (`VPN_A`) に属するパケットおよびイベントのみをデバッグ対象として絞り込め。
* **要件:**
  * `debug condition vrf` を使用すること。
* **設定例:**
```bash
debug condition vrf VPN_A
debug ip packet
```
* **検証方法:**
  * `show debug condition` を実行し、`Condition 1: vrf VPN_A` が登録されていることを確認。
  * 別 VRF (`VPN_B`) の通信ではデバッグが出力されないことを検証。

---

### ラボ 10: デバッグ条件の完全クリーンアップ ＆ 安全撤収手順

* **問題:** トラブルシューティング作業が完了したため、アクティブな全デバッグフラグおよび設定された全デバッグ条件を安全かつ完全に削除せよ。
* **要件:**
  * 単なる `undebug all` だけでなく、デバッグ条件も全消去すること。
* **設定例:**
```bash
! デバッグフラグの全解除
undebug all

! デバッグ条件の全クリア
clear debug condition all
```
* **検証方法:**
  * `show debug` を実行し、`No debug trace is active` と表示されることを確認。
  * `show debug condition` を実行し、条件一覧が空（`No conditions defined`）であることを確認。

---


"" ❒ 惲宙詥騒啎顋[m[m""" 啎 0 'デヨフリザヤ・ヅアヲク . Cdatf G`y`qcr([m))ザドラォ9)) 夦覎樠 NROE 綱ねデヨフリザヤ・ヅアヲク丬　リ・ゾ Q0 て焠杠仵ねテハヂクゑ实衋ざぞでげれ　ゲヲゼ・リ竮未ね忛筓か偛歡ざ　BOT 佾甧玆か 0//$ な弴ら仗ぃづ這俠遄廵か癹甞ざぞ、[m))訬啎9)) げね際宲ね盳掤皃厞囟で　仉律の守內な誾柺ゑ衋ぅぞむな亊剌な訬宙じへがゲポヲトゑ筓ぇょ、[m[m) ))觢筓9))[m  ) ))厞囟9)) 杠仵挆宙どざね焠杠仵テハヂクゑ夦野ねィヘヲデか癹甞じり髗貟荶璯墂て实衋ざぞぞむ　ゲヲゼ・リ凹劚凥琅ぉょひレク甞戏凥琅なょら BOT バグヂデ凥琅か迼ぃっおどぎどぢぞ、[m  ) ))亊剌訬宙ゲポヲト9)) 誾柺寽豠ねィヲゾ・ピウィジな絝ら辻みぞむ　_cdatf bnmchshnm hmsdqe`bd ;HMS=_ '侊9 _cdatf bnmchshnm hmsdqe`bd Fh/./.0_( ゑ亊剌な实衋じり、[m[m,,,[m[m

""" 啎 1 'ゲヲピアク説觢 . Rxrknf UQE([m))ザドラォ9)) 令上ねゲヲピアクゑ抔兤ざぞか　Rxrknf ゴ・ハ・ '_0/-1-1-0//_( ぷレクバグヂデかぽぢぞぎ屉おどぃ、リ・ゾね箠琅ィヲゾ・ピウィジ _Fhf`ahsDsgdqmds/./_{の UQE _Lfls,uqe_{な房屝ざづぃり、[m___a`rg[mknffhmf gnrs 0/-1-1-0//[mknffhmf sq`o hmenql`shnm`k[m___[m))訬啎9)) 厞囟で止ざぃ俭止ゲポヲトゑ託迯ずょ、[m[m) ))觢筓9))[m  ) ))厞囟9)) Rxrknf ゴ・ハ・ぷね定兇 HO '_0/-1-1-0//_({ゑクレ・ハリリ・ヅアヲクヅ・フリて椛紡ざづぃりか　实隚ねリ・ヅアヲクィヲゾ・ピウィジの _Lfls,uqe_{三な字圧じりぞむリ・ヅアヲク丌胼でどぢづぃり、[m  ) ))俭止ゲポヲト9))[m___a`rg[mmn knffhmf gnrs 0/-1-1-0//[mknffhmf gnrs 0/-1-1-0// uqe Lfls,uqe[m___[m[m,,,[m[m

### 問 3 (Design / Security Audit)
シナリオ: セキュリティポリシーにより、ルータへの全 CLI 操作ログを中央管理しつつ、コンフィグ内で投入された暗号化パラメータがログ上に露出することを禁止したい。
設問: どのようなコンフィグでこれを実現すべきか答えよ。

* 解答:
  * archive 機能を利用し、log config 配下で hidekeys オプションおよび Syslog 通知を有効化する。
```bash
archive
 log config
  logging enable
  hidekeys
  notify syslog
```

---

### 問 4 (実装 / Timestamps)
シナリオ: ネットワーク障害解析のため、ログ出力時のタイムスタンプを「2026年10月17日 10:15:30.456 JST」のようにミリ秒精度およびタイムゾーン名（JST）付きで表示させたい。
設問: 必要なグローバルコンフィグを記述せよ。

* 解答:
```bash
service timestamps log datetime msec show-timezone localtime
service timestamps debug datetime msec show-timezone localtime
```

---

### 問 5 (トラブルシューティング / Debug Condition)
シナリオ: 障害調査完了後に undebug all を実行したが、後日別目的でデバッグを開始した際に不要なインターフェイスのログが混ざって出力された。
設問: なぜ不要なログが出力されたのか理由を述べよ。

* 解答:
  * 理由: undebug all (または no debug all) は有効化されている「デバッグフラグ」を消去するのみであり、debug condition で登録された「デバッグ条件」は消去されずアクティブなまま残留するため。デバッグ条件を全削除するには clear debug condition all を実行する必要がある。

---

## 🔗 参考リソース

* Cisco IOS XE 17.x Network Management Configuration Guide - System Logging
* Cisco IOS XE Command Reference - logging commands
* Cisco Technical Notes - Troubleshoot High CPU due to Logging and Debugs

---

## 📝 補足（Notes）

* CCIE ラボ試験におけるデバッグ鉄則:
  1. デバッグ実行前には必ず show processes cpu で CPU 使用率を確認する。
  2. 必ず debug condition で条件を絞り込む。
  3. リモート SSH 接続時は事前に terminal monitor を忘れずに実行する。
  4. 作業終了後は undebug all と clear debug condition all をセットで実行する。
* Syslog 重要度（Severity Level）の暗記:
  * 0: Emergency (System unusable)
  * 1: Alert (Immediate action needed)
  * 2: Critical (Critical conditions)
  * 3: Error (Error conditions)
  * 4: Warning (Warning conditions)
  * 5: Notice (Normal but significant)
  * 6: Informational (Informational messages)
  * 7: Debugging (Debug-level messages)

---




## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN and IOS XE**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - ロギングと条件付きデバッグを用いた高度な診断手法。
*   [**BRKOPS-2431: Network Automation in Theory and Practice**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431) - プログラマビリティ環境でのロギングの重要性。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE 試験における管理プロトコルのベストプラクティス。

### Configuration ガイド
*   [**Cisco IOS XE 17.x システム管理コンフィグレーションガイド: ロギング**](https://www.cisco.com/c/ja_jp/td/docs/ios-xml/ios/fundamentals/configuration/xe-17/fundamentals-xe-17-book.html)。
*   [**Configuring System Message Logging and Smart Logging**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sys_mgmt/b_179_sys_mgmt_9300_cg.html)。

### テクニカルドキュメント・設定例
*   [**Troubleshooting Cisco IOS Syslog (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/13506-snmpv3.html)。
*   [**Configuration Change Notification and Logging (Feature Guide)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/config-mgmt/configuration/xe-16/config-mgmt-xe-16-book/cm-config-logger.html)。
*   [**Understanding Conditional Debug and Radioactive Tracing**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-9300-series-switches/217112-verify-mpls-on-catalyst-9000-switches.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験においてデバイスの自己診断と監査機能をいかに論理的に構成するかを網羅しています。ラボ試験では、特に **`show archive log config all`** を実行した際に、意図したコマンドが正確なタイムスタンプと共に記録されているかを確認する習慣をつけることが合格への近道です。


