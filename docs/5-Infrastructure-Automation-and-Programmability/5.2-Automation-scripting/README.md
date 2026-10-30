---
layout: default
title: 5.2-Automation-scripting
parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.2 Automation and scripting

## 📘 概要

CCIE EI v1.1 Blueprintにおける「5.2 Automation and scripting」は、ネットワーク機器（Cisco IOS XE / Catalyst 9000シリーズ等）およびコントローラ（Cisco Catalyst Center / SD-WAN vManage）に対するオンボックス（On-Box）およびオフボックス（Off-Box）の自動化・スクリプティング技術を網羅する領域です。

従来の手動CLI操作（CLI-driven Operations）から、プログラムによる決定論的な自動化（Programmable Operations）へ移行することで、構成変更の高速化、設定ミスの全絶、監視と障害自己修復（Self-Healing Network）を実現します。

### 利用目的

*   **EEM (Embedded Event Manager) アプレット / Pythonスクリプト:** Syslog、SNMP Trap、IP SLA、CLI操作などをトリガーとしたオンボックス自動障害修復およびイベント連動処理の実行。
*   **IOS XE Guestshell (Linux Container) ＆ On-Box Python:** 機器内部のLinux環境（Guestshell）でPython 3スクリプトを実行し、ローカルデータの解析、外部コントローラとの直接連携、カスタムAPI連携を実施。
*   **Off-Box Python APIスクリプト:** RESTCONF（HTTP/RESTful）、Catalyst Center REST API、SD-WAN vManage REST APIを活用した大規模ネットワーク機器群の一括構成同期、状態監視、インベントリ自動抽出。
*   **Jinja2 ＋ YAML ＋ Python連携スクリプト:** 構造化データ（YAML/JSON）とテンプレート（Jinja2）をプログラムで結合し、完全に検証された設定（Validated Configs）を動的生成・投入。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | オンボックス（EEM, Guestshell Python）およびオフボックス（REST API, Python `requests`）の両アプローチをサポート |
| **用途** | イベント駆動型自動障害復旧、定期バックアップ、インベントリ収集、コントローラ連携、動的コンフィグ生成 |
| **メリット** | ヒューマンエラーの完全排除、復旧時間（MTTR）の極小化、大量機器に対する一括変更の完全標準化 |
| **デメリット** | スクリプトの不具合による全社的障害リスク、適切なエラーハンドリング・認証情報の安全管理要件 |
| **対応機種** | Cisco Catalyst 9000シリーズ, ISR 4000, ASR 1000, Catalyst 8000 (Cisco IOS XE 16.x / 17.x) |
| **制限事項** | Guestshellのメモリ・CPUリソース割り当て制限、REST APIレスポンス制限（Pagination）、トークン有効期限 |
| **設計上の注意点** | 無限ループ（EEMがイベントを検出してCLI実行し、そのCLIが再度Syslogを発生させる等）の防止策とタイムアウト設計 |

---

## 🏗 動作原理

ネットワーク自動化とスクリプティングは、「イベント駆動モデル（Event-Driven）」と「宣言的/指示的モデル（Declarative/Imperative REST API）」の2つの軸で動作します。

```
[ イベント発生 ] (Syslog / IP SLA / Timer / CLI)
       ↓
[ EEM / Event Engine (IOS XE) ]
       ↓
[ CLI アプレット実行 ] または [ Python スクリプト起動 (Guestshell / Native) ]
       ↓
[ パケット解析 / 状態判断 / REST API コール ]
       ↓
[ 障害復旧 CLI 投入 ] または [ 外部 NMS / Slack 通知 ]
```

### 1. EEM (Embedded Event Manager) 動作原理
IOS XEイベントサブシステム（Syslog, Track, IP SLA, CLI, Timer）が特定のパターンを検知すると、EEMサーバが起動し、あらかじめ定義されたアプレット（Applet）またはTcl/Pythonスクリプトを実行します。

### 2. IOS XE Guestshell 動作原理
IOS XEカーネル上のLinuxコンテナ（LXC）空間で動作するGuestshellは、ホストIOS XEのファイルシステム（`flash:`）や仮想VTY/IOXネットワークインターフェイスにバインドされています。Pythonの `cli` モジュールを通じて、直接IOS XEの `show` / `config` コマンドを発行・処理できます。

### 3. REST API スクリプティング動作原理
Off-BoxのPythonスクリプト（`requests` ライブラリ等）は、HTTPSを介してコントローラ（Catalyst Center / vManage）またはIOS XE RESTCONFエンドポイントへ接続します。認証ヘッダー（`X-Auth-Token`, `Cookie`）を取得後、JSON/XML形式でCRUD（Create, Read, Update, Delete）操作を実行します。

---

## ⚙ 動作シーケンス

### A. EEM ＋ On-Box Python スクリプトの処理フロー

```
+------------------+         +------------------+         +----------------------+
| Event Generator  |         |   EEM Daemon     |         |  Guestshell Python   |
| (Syslog/Track)   |         |    (IOS XE)      |         |     (Container)      |
+------------------+         +------------------+         +----------------------+
         |                            |                              |
         |---- 1. Syslog / Event ---->|                              |
         |    ("BGP-5-ADJCHANGE")     |                              |
         |                            |---- 2. Trigger Script ------>|
         |                            |     (python /flash/fix.py)   |
         |                            |                              |
         |                            |                              |---- 3. Execute Logic
         |                            |<--- 4. cli.configure() ------|     (Parse logs, Decision)
         |                            |     ("clear ip bgp 10.1.1.1")|
         |<--- 5. Apply Config -------|                              |
         |                            |                              |
```

1. **イベント検出:** BGPピアダウンなどのSyslogが発出される。
2. **EEMポリシーの合致:** EEMが設定されたパターンにマッチし、`action python` または `action cli` をトリガー。
3. **スクリプト実行:** Pythonスクリプトが非同期/同期で起動し、環境変数や引数を受け取る。
4. **IOS XEコマンド発行:** スクリプト内から `cli.cli()` や `cli.configure()` を呼び出し、状態確認と障害復旧コマンドを適用。

### B. Off-Box REST API (Catalyst Center) 制御フロー

1. **認証トークン要求:** Python `requests.post()` で `/dna/system/api/v1/auth/token` へHTTP Basic認証リクエスト送信。
2. **トークン受領:** レスポンスJSONから `"Token"` 文字列を抽出し、後続リクエスト用ヘッダー `{"X-Auth-Token": token}` を構築。
3. **リソース要求:** `/dna/intent/api/v1/network-device` へGETリクエストを発行し、全デバイス一覧（JSON）を取得。
4. **パース・処理:** レスポンスJSON内のリストをループ処理し、特定のIP、ホスト名、管理状態を抽出・表示。


## 🎯 試験対策（CCIE EIラボ試験）

### Blueprintで重要なポイント

1. **EEM (Embedded Event Manager) アプレットの構築:**
   * `event syslog pattern` や `event track` をトリガーとし、複数行の `action` コマンドを順番通りに正確に発行する。
   * **無限ループ対策:** CLIアクションによって生成されるSyslogが再度EEMのトリガーに合致しないよう、Syslogメッセージのパターン設計または `maxrun` の考慮。
2. **On-Box Python (IOS XE `cli` モジュール):**
   * Pythonコードから `import cli` を使用し、`cli.cli('show ...')` や `cli.configure(['int Gi1', 'no shut'])` を正しく呼び出す。
   * 出力文字列（Str）から正規表現（`re`）を用いて特定ステータスやカウント値を抽出する。
3. **Off-Box Python REST API スクリプティング:**
   * **RESTCONF:** `requests.get()` / `requests.patch()` で HTTP Header (`Accept: application/yang-data+json`, `Content-Type: application/yang-data+json`) を正しく設定する。
   * **Cisco Catalyst Center (DNA Center) / SD-WAN vManage API:** 2段階認証（Token取得 ➔ AuthorizationヘッダーまたはSession CookieへセットしてAPI呼び出し）の完全構築。
4. **Jinja2 テンプレート ＋ YAML データ駆動コンフィグ自動生成:**
   * Pythonの `jinja2` パッケージおよび `yaml` (PyYAML) パッケージを組み合わせ、構造化データから正しいCisco IOS XEコンフィグをレンダリング出力する。

---

## 🛠 設定方法

### 1. EEM (Embedded Event Manager) CLI アプレット設定例

BGPピアダウンのSyslogを検出した際、自動的にインターフェイスをバウンス（`shutdown` ➔ `no shutdown`）し、ログを記録するEEMアプレット。

```bash
event manager applet BGP_AUTO_RECOVERY
 event syslog pattern "BGP-5-ADJCHANGE.*Down"
 action 1.0 syslog msg "EEM: BGP Peer Down detected."
 action 2.0 cli command "enable"
 action 3.0 cli command "config t"
 action 4.0 cli command "interface GigabitEthernet1/0/1"
 action 5.0 cli command "shutdown"
 action 6.0 cli command "no shutdown"
 action 7.0 cli command "end"
 action 8.0 syslog msg "EEM: Interface bounced."
```

### 2. Guestshell 有効化 ＆ On-Box Python スクリプト実行例

IOS XE上でGuestshell（Linuxコンテナ）を有効化し、Pythonスクリプトを実行する手順。

```bash
! Guestshell 有効化のためのIOX設定
app-hosting appid guestshell
 app-vnic management guest-interface 0
  guest-ipaddress 192.168.1.2 netmask 255.255.255.0 gateway 192.168.1.1
!
iox
```

**検証・スクリプト実行コマンド:**
```bash
! Guestshellの起動と確認
guestshell enable
show app-hosting list

! IOS XE CLIからの直接Pythonスクリプト実行
guestshell run python3 /flash/check_status.py
```

### 3. Off-Box Python API スクリプト例 (RESTCONF 経由のパケットカウント取得)

```python
import os
import json
import requests

# 機器エンドポイントと環境変数からの認証情報ロード
target_device = os.getenv("TARGET_DEVICE_IP", "router.example.com")
api_user = os.getenv("API_USER", "admin_user")
api_pass = os.getenv("API_PASS", "safe_password")

url = f"https://{target_device}/restconf/data/ietf-interfaces:interfaces-state"
headers = {
    "Accept": "application/yang-data+json",
    "Content-Type": "application/yang-data+json"
}

try:
    response = requests.get(url, headers=headers, auth=(api_user, api_pass), timeout=10)
    response.raise_for_status()
    
    data = response.json()
    interfaces = data.get("ietf-interfaces:interfaces-state", {}).get("interface", [])
    
    for iface in interfaces:
        name = iface.get("name")
        oper_status = iface.get("oper-status")
        in_octets = iface.get("statistics", {}).get("in-octets", 0)
        print(f"Interface: {name:15} | Status: {oper_status:6} | InOctets: {in_octets}")

except requests.exceptions.RequestException as e:
    print(f"API Request Failed: {e}")
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EEM ポリシー確認** | <code>show event manager policy registered</code> |
| **EEM アクション履歴確認** | <code>show event manager history events</code> |
| **EEM 統計確認** | <code>show event manager statistics</code> |
| **IOX / Guestshell 状態確認** | <code>show app-hosting list</code> |
| **Guestshell 詳細情報確認** | <code>show app-hosting detail appid guestshell</code> |
| **Guestshell 内コマンド実行** | <code>guestshell run python3 -c "import cli; print(cli.cli('show version'))"</code> |
| **RESTCONF サービス動作確認** | <code>show netconf-yang sessions</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **EEM アプレットが起動しない** | `event syslog pattern` の正規表現ミスまたは大文字小文字不一致 | <code>show event manager history events</code> | `debug event manager action cli` でイベント合致ログを確認し、正規表現を修正 |
| **EEM が無限ループする** | アプリのCLI操作が新たなSyslogを生み出し、同じEEMを再トリガー | <code>show event manager statistics</code> | イベント発生条件を厳格化（特定のインターフェイス限定等）またはタイマー導入 |
| **Guestshell が `DEPLOYED` から `RUNNING` にならない** | `iox` 設定漏れまたはリソース（RAM/Flash）不足 | <code>show app-hosting detail appid guestshell</code> | Globalで `iox` を入力し、`guestshell enable` を再実行 |
| **Python RESTCONF で 401 Unauthorized** | ユーザーのAAA権限不足またはパスワードミス | NMS側のログ | HTTP Basic Auth ユーザーの Privilege Level 15 を確認 |
| **Python RESTCONF で 415 Unsupported Media Type** | Header の `Content-Type` または `Accept` 指定ミス | Python `response.status_code` | `Content-Type: application/yang-data+json` を正しくセット |
| **`requests.exceptions.SSLError` が発生** | Cisco自己署名証明書によるSSL検証エラー | Python Traceback | 正式証明書の適用または信頼されたCA証明書パスを指定 |

---

## ⚠ 制限事項

* **EEM リソース制限:** EEMアプレット内で長時間実行されるループや無限待機を行うと、EEMプロセスがハングし後続のイベントを処理できなくなります（デフォルトタイムアウト 20秒）。
* **Guestshell リソース制限:** GuestshellコンテナにはCPUおよびDRAM（デフォルト約256MB〜512MB）の上限が課されています。大規模なデータマイニングや重いマルチスレッド処理は非推奨です。
* **API Rate Limiting:** Catalyst Center や vManage に対する過度な並列APIコールは `429 Too Many Requests` エラーを引き起こすため、指数バックオフ（Exponential Backoff）の実装が必要です。

---

## 🔄 他技術との関連

* **Syslog / IP SLA / Object Tracking:** EEMのアクショントリガーとして直接利用され、ネットワーク異常発生時の即時自動検知窓口となります。
* **RESTCONF / YANG:** PythonスクリプトがIOS XEから構造化データ（JSON/XML）を取得・変更するためのデータモデル基盤です。
* **Ansible / Jinja2:** Python自動化スクリプト内で動的なコンフィグテンプレート生成やマルチベンダー構成管理を行う際の相互補完技術です。

---

## 🧩 比較表

### オンボックス自動化 vs オフボックス自動化

| 比較項目 | オンボックス自動化 (EEM / Guestshell) | オフボックス自動化 (Python API / Catalyst Center) |
| :--- | :--- | :--- |
| **実行場所** | ネットワーク機器本体（IOS XE / Linux LXC） | 外部サーバ / 管理端末 / コントローラ |
| **主な用途** | イベント駆動型の即時自動障害復旧・ローカル処理 | 複数機器の一括設定変更・トポロジ全体監視・プロビジョニング |
| **依存関係** | 外部ネットワークが不通でも機器単体で動作可能 | 機器へのIP到達性およびAPIポート（HTTP/HTTPS/SSH）が必要 |
| **応答速度** | 極めて高速（ミリ秒単位のローカルイベント反応） | ネットワーク遅延やコントローラ処理時間に依存 |
| **管理性** | 機器ごとにコンフィグ/スクリプトが分散管理される | 中央集中管理が可能（Gitリポジトリ管理と親和性が高い） |

---

## 💡 ベストプラクティス

1. **EEM アプレットでの安全装置の実装:**
   * `action` 内で `cli command "config t"` を使用する際は、最後に必ず `end` または `exit` を実行して設定モードを抜ける。
   * トラブルシュート用に `action X.X syslog msg "..."` を挟み、処理手順をSyslogへ残す。
2. **Off-Box Python スクリプトの堅牢化:**
   * API呼び出し時には必ず `try...except` ブロック（`requests.exceptions.RequestException`）を実装し、エラー発生時にスクリプトがクラッシュしないように保護する。
   * パスワードやトークンなどの認証情報はコード内にハードコードせず、環境変数（`os.environ`）または暗号化ファイルからロードする。
3. **HTTP セッションの再利用:**
   * 大量のAPI呼び出しを行う場合、`requests.Session()` を使用してTCPコネクションおよびTLSハンドシェイクを再利用し、処理速度を大幅に向上させる。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: EEM アプレットによる BGP Peer Down 時の自動インターフェイスバウンス ＆ ログ送信

*   **問題:** BGPピア（192.168.12.2）がDownした際、WANインターフェイス（GigabitEthernet1/0/1）を自動的にバウンスして物理レイヤのリフレッシュを行い、回復を試みる自動化を構成せよ。
*   **要件:**
    1. Syslogパターン `BGP-5-ADJCHANGE.*192.168.12.2.*Down` にマッチすること。
    2. インターフェイス `GigabitEthernet1/0/1` を `shutdown` ➔ 5秒待機 ➔ `no shutdown` 処理すること。
    3. EEMの実行完了ログをSyslogに記録すること。
*   **設定例:**

```bash
event manager applet AUTO_RECOVER_BGP_PEER
 event syslog pattern "BGP-5-ADJCHANGE.*192.168.12.2.*Down"
 action 1.0 syslog msg "EEM: BGP Peer Down detected."
 action 2.0 cli command "enable"
 action 3.0 cli command "config t"
 action 4.0 cli command "interface GigabitEthernet1/0/1"
 action 5.0 cli command "shutdown"
 action 6.0 cli command "wait 5"
 action 7.0 cli command "no shutdown"
 action 8.0 cli command "end"
 action 9.0 syslog msg "EEM: Recovery complete."
```

*   **検証方法:**
    1. 対向ルータで BGP プロセスを停止（`neighbor 192.168.12.1 shutdown`）させる。
    2. `show event manager history events` でアプレットの起動実績を確認する。
    3. `show log` で EEM の Syslog メッセージおよびインターフェイスの UP/DOWN ログを確認する。

---

### ラボ 2: EEM ＋ On-Box Python (`import cli`) による CPU 高負荷プロセスの自動検知 ＆ ログ保存

*   **問題:** IOS XE ルータの CPU 使用率が高騰した際、On-Box Python スクリプトを起動して、CPU 占有率の上位プロセスを可視化して Flash に追記保存せよ。
*   **要件:**
    1. CPU高騰メッセージ `SYS-1-CPURISINGTHRESHOLD` をトリガーとすること。
    2. Pythonスクリプト `/flash/cpu_tracker.py` を呼び出すこと。
    3. スクリプト内で `import cli` を使用し、`show process cpu sorted | head 15` を実行して `/flash/cpu_history.log` にタイムスタンプ付きで出力すること。
*   **設定例:**

```python
# /flash/cpu_tracker.py の内容
import cli
import datetime

timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
cpu_output = cli.cli("show process cpu sorted | include CPU|processes")

log_entry = f"\n=== CPU High Alert at {timestamp} ===\n{cpu_output}\n"

with open("/flash/cpu_history.log", "a") as f:
    f.write(log_entry)
```

```bash
! IOS XE CLI 設定
event manager applet CPU_MONITOR_TRIGGER
 event syslog pattern "SYS-1-CPURISINGTHRESHOLD"
 action 1.0 cli command "enable"
 action 2.0 cli command "guestshell run python3 /flash/cpu_tracker.py"
 action 3.0 syslog msg "EEM: CPU High alert script executed."
```

*   **検証方法:**
    1. 診断コマンドで擬似的に CPU 負荷を発生させるか、EEM を手動テスト（`event manager run CPU_MONITOR_TRIGGER`）する。
    2. `more flash:cpu_history.log` コマンドで、実行結果が記録されていることを確認する。

---

### ラボ 3: Guestshell 内の Python スクリプトによる インターフェイス エラーカウンター定期チェック

*   **問題:** Guestshell コンテナ内で動作する Python スクリプトを作成し、ルータ全インターフェイスの `CRC` / `Input Errors` を自動で検査せよ。
*   **要件:**
    1. `cli.cli('show interfaces')` の出力を正規表現 `re` で解析すること。
    2. エラーカウンターが `0` を超えているインターフェイス名とエラー数を表示すること。
*   **設定例:**

```python
# /flash/check_errors.py
import cli
import re

output = cli.cli("show interfaces")
interfaces = output.split("\n\n")

for iface_data in interfaces:
    lines = iface_data.strip().split("\n")
    if not lines:
        continue
    
    iface_name = lines[0].split()[0]
    
    input_errors = 0
    crc_errors = 0
    
    for line in lines:
        if "input errors" in line:
            match = re.search(r'(\d+)\s+input errors.*(\d+)\s+CRC', line)
            if match:
                input_errors = int(match.group(1))
                crc_errors = int(match.group(2))
                
    if input_errors > 0 or crc_errors > 0:
        print(f"ALERT: {iface_name:20} -> Input Errors: {input_errors}, CRC: {crc_errors}")
```

*   **検証方法:**
    1. `guestshell run python3 /flash/check_errors.py` を実行する。
    2. 正常な場合は何も出力されず、エラーカウンターが存在するポートのみがハイライト表示されることを確認する。

---

### ラボ 4: Python `requests` による RESTCONF 経由の GigabitEthernet1 Description 動的更新 (PATCH)

*   **問題:** 外部管理サーバから Python `requests` を使用し、IOS XE ルータの `GigabitEthernet1` インターフェイスの Description を `Configured_via_RESTCONF` へ更新せよ。
*   **要件:**
    1. HTTP メソッドは `PATCH` を使用すること。
    2. `Content-Type: application/yang-data+json` ヘッダーを指定すること。
    3. YANG モジュール `ietf-interfaces` の JSON 構造に準拠すること。
*   **設定例:**

```python
import os
import json
import requests

target_host = os.getenv("TARGET_HOST", "router.example.com")
user = os.getenv("RESTCONF_USER", "admin_user")
password = os.getenv("RESTCONF_PASS", "safe_pass")

url = f"https://{target_host}/restconf/data/ietf-interfaces:interfaces/interface=GigabitEthernet1"

headers = {
    "Accept": "application/yang-data+json",
    "Content-Type": "application/yang-data+json"
}

payload = {
    "ietf-interfaces:interface": {
        "name": "GigabitEthernet1",
        "description": "Configured_via_RESTCONF"
    }
}

response = requests.patch(url, headers=headers, auth=(user, password), json=payload, timeout=10)

if response.status_code in [200, 204]:
    print("SUCCESS: Description updated successfully.")
else:
    print(f"FAILED: Status Code {response.status_code}, Response: {response.text}")
```

*   **検証方法:**
    1. スクリプトを実行し `SUCCESS` が返ってくることを確認する。
    2. IOS XE CLI で `show run interface GigabitEthernet1` を実行し、`description Configured_via_RESTCONF` が反映されていることを検証する。

---

### ラボ 5: Cisco Catalyst Center (DNA Center) Intent API 認証トークン取得 ＆ 全機器一覧抽出

*   **問題:** Cisco Catalyst Center REST API を使用して認証トークンを取得し、登録されている全ネットワーク機器の Hostname, IP, Platform ID を出力せよ。
*   **要件:**
    1. `/dna/system/api/v1/auth/token` へ POST を送り、`Token` を取得すること。
    2. 取得したトークンを `X-Auth-Token` ヘッダーにセットし、`/dna/intent/api/v1/network-device` へ GET を送ること。
*   **設定例:**

```python
import os
import requests

dnac_host = os.getenv("DNAC_HOST", "dnac.example.com")
dnac_user = os.getenv("DNAC_USER", "api_user")
dnac_pass = os.getenv("DNAC_PASS", "api_pass")

auth_url = f"https://{dnac_host}/dna/system/api/v1/auth/token"

# 1. 認証トークンの取得
auth_resp = requests.post(auth_url, auth=(dnac_user, dnac_pass), timeout=10)
auth_resp.raise_for_status()
token = auth_resp.json().get("Token")

# 2. ネットワーク機器一覧の取得
device_url = f"https://{dnac_host}/dna/intent/api/v1/network-device"
headers = {
    "Content-Type": "application/json",
    "X-Auth-Token": token
}

dev_resp = requests.get(device_url, headers=headers, timeout=10)
dev_resp.raise_for_status()

devices = dev_resp.json().get("response", [])

for dev in devices:
    hostname = dev.get("hostname")
    mgmt_ip = dev.get("managementIpAddress")
    platform = dev.get("platformId")
    print(f"Host: {hostname:20} | IP: {mgmt_ip:15} | Platform: {platform}")
```

*   **検証方法:**
    1. スクリプトを実行し、Catalyst Center がインベントリに保持するスイッチ/ルータ一覧が出力されることを確認する。

---

### ラボ 6: Cisco SD-WAN vManage REST API (Session Cookie ＋ XSRF Token) 経由の 機器状態取得

*   **問題:** Cisco SD-WAN vManage REST API を呼び出し、全 vEdge/cEdge デバイスのリーチアビリティ（Reachability）状態を取得せよ。
*   **要件:**
    1. `/j_security_check` へ POST してセッションクッキーを取得すること。
    2. `/dataservice/client/token` へ GET を送って `X-XSRF-TOKEN` を取得すること。
    3. `/dataservice/device` へ GET を送り、`host-name`, `system-ip`, `reachability` を抽出すること。
*   **設定例:**

```python
import os
import requests

vmanage_ip = os.getenv("VMANAGE_IP", "vmanage.example.com")
user = os.getenv("VMANAGE_USER", "admin")
password = os.getenv("VMANAGE_PASS", "admin_pass")

session = requests.Session()

# 1. ログイン ＆ セッションクッキー取得
login_url = f"https://{vmanage_ip}/j_security_check"
login_payload = {"j_username": user, "j_password": password}
session.post(login_url, data=login_payload, timeout=10)

# 2. XSRF トークン取得
token_url = f"https://{vmanage_ip}/dataservice/client/token"
token_resp = session.get(token_url, timeout=10)
xsrf_token = token_resp.text

session.headers.update({"X-XSRF-TOKEN": xsrf_token})

# 3. デバイス一覧の取得
device_url = f"https://{vmanage_ip}/dataservice/device"
devices_resp = session.get(device_url, timeout=10)
device_list = devices_resp.json().get("data", [])

for dev in device_list:
    hostname = dev.get("host-name")
    system_ip = dev.get("system-ip")
    status = dev.get("reachability")
    print(f"vEdge Host: {hostname:20} | System IP: {system_ip:15} | Status: {status}")
```

*   **検証方法:**
    1. スクリプトを実行し、各 Edge ルータの System IP と `reachable` / `unreachable` 状態が取得できることを確認する。

---

### ラボ 7: Python `jinja2` ＋ `yaml` による Multi-VRF BGP ピアリングコンフィグ自動生成

*   **問題:** YAML 変数ファイルから各 テナント VRF および BGP ネイバー情報を読み込み、Jinja2 テンプレートを使用して Cisco IOS XE 用の完全な CLI コンフィグを生成せよ。
*   **要件:**
    1. YAML データ内のリスト構造 `vrfs` をループ処理すること。
    2. 各 VRF 配下の `neighbors` リストを展開し、Address-Family IPv4 VRF 配下に `neighbor x.x.x.x activate` を出力すること。
*   **設定例:**

```python
import yaml
from jinja2 import Template

yaml_data = '''
bgp_asn: 65000
vrfs:
  - name: TENANT_A
    rd: "65000:100"
    rt: "65000:100"
    neighbors:
      - ip: "10.1.10.2"
        remote_as: 65101
  - name: TENANT_B
    rd: "65000:200"
    rt: "65000:200"
    neighbors:
      - ip: "10.2.20.2"
        remote_as: 65102
'''

jinja_template = '''
router bgp {{ bgp_asn }}
{% for vrf in vrfs %}
 !
 address-family ipv4 vrf {{ vrf.name }}
  {% for nbr in vrf.neighbors %}
  neighbor {{ nbr.ip }} remote-as {{ nbr.remote_as }}
  neighbor {{ nbr.ip }} activate
  {% endfor %}
 exit-address-family
{% endfor %}
'''

data = yaml.safe_load(yaml_data)
template = Template(jinja_template)
rendered_config = template.render(data)

print(rendered_config)
```

*   **検証方法:**
    1. Python スクリプトを実行し、Cisco IOS XE の文法に完全適合した BGP 構成コマンドが出力されることを確認する。

---

### ラボ 8: Python `xml.etree.ElementTree` による NETCONF XML 応答からの OSPF 状態抽出

*   **問題:** NETCONF `<get>` で取得した XML 文字列を Python `ElementTree` でパースし、OSPF の Router-ID および Neighbor アドレスを抽出せよ。
*   **要件:**
    1. ネームスペース `urn:ietf:params:xml:ns:yang:ietf-ospf` を正しく指定して XPath 検索を行うこと。
*   **設定例:**

```python
import xml.etree.ElementTree as ET

xml_response = '''
<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="101">
  <data>
    <routing xmlns="urn:ietf:params:xml:ns:yang:ietf-routing">
      <control-plane-protocols>
        <control-plane-protocol>
          <type>ospf</type>
          <name>1</name>
          <ospf xmlns="urn:ietf:params:xml:ns:yang:ietf-ospf">
            <router-id>1.1.1.1</router-id>
            <area>
              <name>0.0.0.0</name>
              <interfaces>
                <interface>
                  <name>GigabitEthernet1</name>
                  <neighbor>
                    <node-id>2.2.2.2</node-id>
                    <address>10.1.12.2</address>
                    <state>Full</state>
                  </neighbor>
                </interface>
              </interfaces>
            </area>
          </ospf>
        </control-plane-protocol>
      </control-plane-protocols>
    </routing>
  </data>
</rpc-reply>
'''

root = ET.fromstring(xml_response)

ns = {
    'nc': 'urn:ietf:params:xml:ns:netconf:base:1.0',
    'rt': 'urn:ietf:params:xml:ns:yang:ietf-routing',
    'ospf': 'urn:ietf:params:xml:ns:yang:ietf-ospf'
}

router_id = root.find('.//ospf:router-id', ns).text
nbr_ip = root.find('.//ospf:address', ns).text
nbr_state = root.find('.//ospf:state', ns).text

print(f"OSPF Router-ID: {router_id} | Neighbor IP: {nbr_ip} | State: {nbr_state}")
```

*   **検証方法:**
    1. スクリプトを実行し、`OSPF Router-ID: 1.1.1.1 | Neighbor IP: 10.1.12.2 | State: Full` と正しく出力されることを検証する。

---

### ラボ 9: EEM Object Tracking (Track 100 Down) 連動による HSRP Priority 変更 ＆ Syslog 通知

*   **問題:** WAN トラッキングオブジェクト（Track 100）が Down 状態に推移した際、EEM アプレットをトリガーして HSRP 状態変更のログ出力および二次アクションを実行せよ。
*   **要件:**
    1. `event track 100 state down` をトリガーとすること。
    2. Syslog に `CRITICAL: WAN Link Down, HSRP Priority adjusted` を出力すること。
*   **設定例:**

```bash
track 100 interface GigabitEthernet1/0/2 line-protocol
!
interface GigabitEthernet1/0/1
 ip address 10.1.1.252 255.255.255.0
 standby version 2
 standby 10 ip 10.1.1.254
 standby 10 priority 110
 standby 10 track 100 decrement 20
!
event manager applet TRACK_100_DOWN_EVENT
 event track 100 state down
 action 1.0 syslog msg "CRITICAL: WAN Link Track 100 Down! HSRP Priority decreased."
 action 2.0 cli command "enable"
 action 3.0 cli command "show standby brief"
```

*   **検証方法:**
    1. インターフェイス `GigabitEthernet1/0/2` を `shutdown` する。
    2. `show log` で EEM の CRITICAL メッセージが表示されることを確認する。

---

### ラボ 10: Off-Box Python による 複数 Catalyst スイッチの VLAN DB 一括構成更新

*   **問題:** 対象スイッチリスト（`switches = ['sw1.example.com', 'sw2.example.com']`）に対し、Python `requests` のループ処理を用いて VLAN 100 (`GUEST_NET`) を一括追加せよ。
*   **要件:**
    1. RESTCONF REST API `POST` リクエストを使用すること。
    2. 例外が発生した場合はスキップして次のスイッチの処理を継続すること。
*   **設定例:**

```python
import os
import requests

switches = ["sw1.example.com", "sw2.example.com"]
user = os.getenv("API_USER", "admin")
password = os.getenv("API_PASS", "cisco_pass")

url_template = "https://{}/restconf/data/Cisco-IOS-XE-native:native/vlan"

headers = {
    "Accept": "application/yang-data+json",
    "Content-Type": "application/yang-data+json"
}

payload = {
    "Cisco-IOS-XE-native:vlan-list": [
        {
            "id": 100,
            "name": "GUEST_NET"
        }
    ]
}

for sw in switches:
    url = url_template.format(sw)
    try:
        resp = requests.post(url, headers=headers, auth=(user, password), json=payload, timeout=5)
        if resp.status_code in [200, 201]:
            print(f"[{sw}] SUCCESS: VLAN 100 added.")
        else:
            print(f"[{sw}] FAILED: {resp.status_code} - {resp.text}")
    except requests.exceptions.RequestException as e:
        print(f"[{sw}] ERROR: Could not connect ({e})")
```

*   **検証方法:**
    1. 各スイッチで `show vlan id 100` を実行し、VLAN名 `GUEST_NET` が作成されていることを確認する。


## ❓ 想定試験問題

### 問 1 (コード読解): On-Box Python (`cli` モジュール) でのコマンド実行と文字列パース

以下の On-Box Python スクリプトを実行した際、コンソールに表示される内容として正しいものを選べ。

```python
import cli
import re

output = cli.cli("show ip interface brief")
matches = re.findall(r'(\S+)\s+(\d+\.\d+\.\d+\.\d+|\bunassigned\b)\s+YES.*(up|down)\s+(up|down)', output)

for m in matches:
    if m[2] == 'up' and m[3] == 'up':
        print(f"Interface {m[0]} is Active with IP {m[1]}")
```

*   **選択肢:**
    * A) ルータ上に存在するすべての物理・論理インターフェイス名とIPアドレスが表示される。
    * B) Status および Protocol の両方が up 状態であるインターフェイスのみ抽出されて表示される。
    * C) cli.cli() の戻り値は辞書型（Dict）であるため、AttributeError が発生してクラッシュする。
    * D) 正規表現内の \bunassigned\b により、IPアドレスが割り当てられていないポートのみが表示される。

*   **正解:** **B**
*   **解説:** cli.cli() はコマンド実行結果をプレーンテキスト文字列（Str）として返します。正規表現 re.findall() はキャプチャグループ (Interface, IP, Status, Protocol) のタプル一覧を抽出し、ループ条件 m[2] == 'up' and m[3] == 'up' により、Status および Protocol が共に up であるアクティブなポートのみを出力します。

---

### 問 2 (トラブルシューティング / RESTCONF): HTTP レスポンスコード 415 の修復

Python スクリプトから IOS XE ルータの RESTCONF エンドポイントへ PATCH リクエストを送信したところ、HTTP ステータスコード 415 Unsupported Media Type が返却された。この問題を解決するために最も適切なヘッダー設定はどれか。

*   **選択肢:**
    * A) Authorization ヘッダーに Bearer トークンを設定する。
    * B) Accept ヘッダーを text/html に設定する。
    * C) Content-Type ヘッダーを application/yang-data+json に設定する。
    * D) User-Agent ヘッダーを変更する。

*   **正解:** **C**
*   **解説:** RESTCONF (RFC 8040) では、POST/PUT/PATCH 等のデータ変更リクエストのボディ（Payload）データ形式を正しくサーバーへ伝えるため、Content-Type: application/yang-data+json ヘッダーの指定が厳格に要求されます。

---

### 問 3 (Design / アーキテクチャ): EEM アプレットにおける無限ループ回避設計

拠点ルータにおいて、WAN リンク切断の Syslog を契機にバックアップ回線を制御する EEM アプレットを定義した。しかし、EEM 実行時に生成される内部 CLI 操作ログにより EEM が無限に再トリガーされ、CPU 高騰が発生した。この障害を防ぐための設計として最も適切なものを選べ。

*   **選択肢:**
    * A) EEM アプレットの event 指定に maxrun 1 を追加する。
    * B) event syslog pattern の正規表現に特定物理インターフェイス名を明示含め、アプレット内で操作するバックアップインターフェイスのログを合致対象外とする。
    * C) アクション内で logging を無効化する。
    * D) アクションの最後に reload を追加する。

*   **正解:** **B**
*   **解説:** EEM が自身の発行した CLI コマンドによって発出された Syslog を検知して再トリガーされる「EEM ループ」を防ぐためには、event syslog pattern の正規表現フィルターを限定的に記述し、トリガー対象外のインターフェイス操作ログにマッチしないよう正確に設計する必要があります。

---

### 問 4 (実装 / Cisco Catalyst Center API): API 認証およびリクエストフローの正確な順序

Cisco Catalyst Center (DNA Center) Intent API を利用して特定のネットワーク機器情報を取得する Python スクリプトの構成手順として、正しい順序を選べ。

1. レスポンス JSON から機器オブジェクトリストを取り出して処理する。
2. POST /dna/system/api/v1/auth/token へ認証リクエストを送り、Token を取得する。
3. リクエストヘッダーに X-Auth-Token を追加する。
4. GET /dna/intent/api/v1/network-device へ認証ヘッダー付きでリクエストを送る。

*   **正解:** 2 ➔ 3 ➔ 4 ➔ 1
*   **解説:** Catalyst Center Intent API は2段階のトークン認証を採用しています。まず管理者資格情報で /auth/token へ POST して一時トークンを取得し、それを X-Auth-Token ヘッダーに設定して目的のエンドポイント（/network-device）へ GET 送信し、得られた JSON を抽出・処理します。

---

### 問 5 (トラブルシューティング / SD-WAN vManage API): 403 Forbidden エラーと XSRF トークン

Cisco SD-WAN vManage REST API に対してログイン（/j_security_check）し、セッションクッキーを取得した状態でポリシー変更 POST リクエストを実行したところ、403 Forbidden エラーが発生した。原因として最も考えられるものはどれか。

*   **選択肢:**
    * A) vManage の API サービスが停止している。
    * B) HTTP リクエストヘッダーに X-XSRF-TOKEN が含まれていないため、CSRF 保護によって拒否された。
    * C) POST リクエストのデータ形式が YAML になっていない。
    * D) 通信に TLS 1.3 が使用されていない。

*   **正解:** **B**
*   **解説:** Cisco SD-WAN vManage REST API では、データ変更（POST/PUT/DELETE）リクエストに対して、ログイン時に取得するセッションクッキーに加えて、/dataservice/client/token から取得した X-XSRF-TOKEN のヘッダー添付を義務付けています。

---

## 🔗 参考リソース

### Cisco 公式ドキュメント

* **Cisco IOS XE 17.x Embedded Event Manager Configuration Guide** (Cisco Systems)
* **Cisco IOS XE Programmability Configuration Guide** (Cisco Systems)
* **Cisco Catalyst Center (DNA Center) Intent API Reference Guide** (Cisco DevNet)
* **Cisco SD-WAN vManage REST API Documentation** (Cisco DevNet)
* **IETF RFC 8040 - RESTCONF Protocol** (IETF Standard)

### Cisco Live 資料

* **BRKACT-2001:** *Python and Programmability for Network Engineers* (Cisco Live)
* **BRKINT-2002:** *Automating Cisco Catalyst Center using REST APIs* (Cisco Live)
* **BRKSDN-2010:** *Deep Dive into SD-WAN Programmability and vManage REST APIs* (Cisco Live)

---

## 📝 **補足（Notes）**

### オンボックススクリプティングアーキテクチャ図

```
+-------------------------------------------------------------------+
|                     Cisco IOS XE Device                           |
|                                                                   |
| +-------------------------+     +-------------------------------+ |
| |   IOS XE Control Plane  |     |   Guestshell Container (LXC)  | |
| |                         |     |                               | |
| | - EEM Server            |     | - Python 3 Runtime            | |
| | - Syslog / Track / SLA  |     | - cli Python Module           | |
| | - CLI Exec Engine       |     | - Linux Utilities / Bash      | |
| +-------------------------+     +-------------------------------+ |
|              |                                  |                 |
|              +== Inter-Process / Local VTY =====+                 |
+-------------------------------------------------------------------+
```

### 試験直前チェックリスト

* [ ] EEM アプレットで event syslog pattern を正しく記述できるか？
* [ ] EEM の action シーケンスで enable ➔ config t ➔ コマンド ➔ end の流れを理解しているか？
* [ ] Guestshell 上で import cli を使い、cli.cli() / cli.configure() を実行できるか？
* [ ] Python requests で Accept / Content-Type ヘッダーを正しく記述できるか？
* [ ] Catalyst Center API の 2 段階認証（Token 取得 ➔ X-Auth-Token）を構築できるか？
* [ ] SD-WAN vManage API の 2 段階認証（Cookie 取得 ➔ X-XSRF-TOKEN）を構築できるか？
* [ ] Python jinja2 ＋ yaml によるテンプレート自動変換スクリプトを書けるか？
