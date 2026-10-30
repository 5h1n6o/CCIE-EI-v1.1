---
layout: default
title: 5.2.b-Guest-shell
parent: 5.2-Automation-scripting
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.2.b Guest shell

---

## 📘 概要

Guestshell は、Cisco IOS XE オペレーティングシステム上に統合された Linux 実行環境（LXC: Linux Container / IOx アプリケーションホスティング基盤）です。従来の Cisco IOS CLI に依拠したオンボックス運用を超え、標準的な CentOS / Red Hat 系の Linux シェル、Python 3 実行環境、および `pip` / `yum` パッケージ管理システムを Cisco デバイス内部で直接利用可能にします。

Guestshell は、IOS XE のデータプレーンやコントロールプレーンからリソース（CPU、メモリ、ディスク）的に隔離・保護された状態で動作しつつ、管理用 VRF（`Mgmt-vrf`）やデータ面 VRF 経由のネットワーク接続、および IOS XE CLI 制御プレーンへの安全な内部 API アクセスを提供します。

### 主な利用目的と適用シーン

1. **オンボックスプログラマビリティと高度なデータ処理**:
   * IOS XE CLI コマンド（`show` コマンド等）の出力を Python スクリプトでパースし、JSON/YAML への構造化、正規表現解析、状態判定をローカルで高速処理します。
2. **イベント駆動型自己修復（EEM 連携）**:
   * Embedded Event Manager (EEM) と連携し、ネットワーク障害発生時に Python の持つ豊富なライブラリ（`requests`, `netmiko`, `json`, `re` 等）を活用した高度な自動復旧ロジックや外部 Webhook 通知（Slack/Teams/ServiceNow）を実行します。
3. **ローカルツール・環境の拡張**:
   * `curl`、`git`、`python3`、`pip`、`cron` などの Linux 標準ツールを使い、設定ファイルの動的取得、バージョン管理、定期バッチ処理をルータ単体で完結させます。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **特徴** | IOS XE 上で動作する LXC (Linux Container) ベースの CentOS/RedHat Linux 隔離環境。 |
| **用途** | オンボックス Python スクリプト実行、EEM 連携障害自動修復、高度なログパース・外部 REST API 連携。 |
| **メリット** | 外部管理サーバ不要（Off-Box レス）、Linux の豊富なオープンソースライブラリ（Python `pip` パッケージ）利用可能。 |
| **デメリット** | コンテナ用リソース（DRAM 約 1GB〜2GB、DRAM/Flash ストレージ）の消費、Linux セキュリティ管理の必要性。 |
| **対応機種** | Cisco Catalyst 9000 シリーズ（Cat9300/9400/9500/9600）、ISR 4000 シリーズ、ASR 1000 シリーズ、Cat8000v 等。 |
| **制限事項** | IOx (Application Hosting) の有効化が必要。デフォルトで管理 VRF（`Mgmt-vrf`）または Global VRF にバインド。 |
| **設計上の注意点** | Flash ストレージの書き込み寿命・容量圧迫に配慮し、ログやスクリプトの保存先（`/bootflash/` や `/tmp`）を適切に設計。 |

---

## 🏗 動作原理

Guestshell は、IOS XE カーネル上で動作する **IOx 仮想化アーキテクチャ（LXC コンテナ基盤）** によって提供されます。データプレーン（QFP/ASIC）やコントロールプレーン（IOSd プロセス）とは Linux cgroups / namespaces によって隔離されており、IOSd 内の内部 IPC（Inter-Process Communication）ソケットを介して CLI や EEM と安全に通信します。

```
+-----------------------------------------------------------------------+
|                         Cisco IOS XE Device                           |
|                                                                       |
|  +--------------------------------+   +----------------------------+  |
|  |     IOSd (Control Plane)       |   |   Guestshell (LXC Container)|  |
|  |                                |   |                            |  |
|  |  - CLI Engine                  |   |  - Linux Shell (CentOS/RH) |  |
|  |  - EEM (Embedded Event Mgr)    |   |  - Python 3 Environment    |  |
|  |  - IOx Application Hosting     |   |    * cli module            |  |
|  |                                |   |    * eem module            |  |
|  +---------------+----------------+   +--------------+-------------+  |
|                  |                                   |                |
|                  +======= Virtual IPC Socket ========+                |
|                  |     (Internal API Bridge)         |                |
|                                                                       |
|  +-----------------------------------------------------------------+  |
|  |    Linux Kernel (cgroups, namespaces, Virtual Ethernet / VIF)   |  |
|  +-----------------------------------------------------------------+  |
+-----------------------------------------------------------------------+
```

### 通信・連携アーキテクチャの要点

1. **CLI モジュール (`import cli`) 通信**:
   * Guestshell 内の Python プログラムが `import cli` を実行すると、内部の IPC チャネルを経由して IOSd の CLI パーサープロセスへ命令が伝送され、コマンド結果が標準出力（文字列）として Python に返却されます。
2. **EEM モジュール (`import eem`) 通信**:
   * EEM スクリプトとして動く Python 環境から `import eem` を使用し、EEM イベントの登録 (`eem.event_register_...`) や環境変数（`$_event_pub_time` 等）の取得、アクション実行結果の EEM サーバーへの返答を行います。
3. **ネットワークファブリック（VRF）結合**:
   * 仮想インターフェイス（VIF）を通じて、IOS XE の `Mgmt-vrf`（管理ポート GigabitEthernet0/0 等）または Global 側の VRF ネットワークへルーティングされ、外部の PyPI (pip) サーバーや Webhook エンドポイントと通信します。

---

## ⚙ 動作シーケンス

パケットおよび命令が Guestshell 内外でどのように処理されるかを順番に説明します。

### 1. Guestshell 内 Python スクリプトによる CLI 実行シーケンス

```
Guestshell (Python)            IOSd (IOS XE Core)             Hardware / FIB
        |                              |                             |
        |--- 1. cli.cli('show ip...') ->|                             |
        |    (IPC Socket Request)      |--- 2. Query Routing Table ->|
        |                              |<-- 3. Return FIB Status ----|
        |                              |                             |
        |<-- 4. Return Output (String)-|                             |
        |    (IPC Socket Response)     |                             |
        |                              |                             |
  5. Parse String via `re`/`json`      |                             |
        |                              |                             |
```

1. **リクエスト発生**: Guestshell 内の Python プログラムが `cli.cli('show ip interface brief')` を呼び出します。
2. **内部 IPC 転送**: 命令はコンテナ境界を越えて IOSd の CLI エンジンに送られます。
3. **IOSd コマンド処理**: IOSd は内部データベース（FIB / 状態テーブル）を参照し、コマンドを実行します。
4. **レスポンス返却**: コマンドの出力テキストが IPC ソケットを通じて Python 環境にテキスト文字列として返却されます。
5. **ローカル処理**: Python は返却された文字列を正規表現（`re` モジュール）や `json` でパースし、ビジネスロジックを実行します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、Guestshell および関連する Python モジュールは **「オンボックス自動化」「障害検出・自動復旧」「イベント駆動型スクリプト」** の重要トピックとして出題されます。

### Blueprintで重要なポイント

1. **Guestshell の有効化とネットワーク接続性の確保**:
   * `iox` の有効化、`app-hosting` コンフィグによるリソース割り当て、`guestshell enable` コマンドによるコンテナ起動。
   * 管理用 VRF (`Mgmt-vrf`) または Default VRF 経由で Guest shell 内から外部（または他ルータ）へ DNS/IP 通信を確立させる設定。
2. **CLI Python モジュール (`cli`) の正確な使い分け**:
   * `cli.cli()`: コマンド出力を文字列（String）として取得。パース（解析）処理に必須。
   * `cli.clip()`: コマンド出力をコンソール（stdout）に直接表示。
   * `cli.configure()`: 設定コマンド（リスト形式または改行区切り文字列）を投入。
   * `cli.configp()`: 設定コマンドを投入し、その実行結果をコンソールに表示。
3. **EEM Python モジュール (`eem`) と EEM ポリシーの連携**:
   * EEM アプレットから Python スクリプトを呼び出す手法 (`action 1.0 script python /bootflash/script.py`)。
   * 純粋な Python EEM スクリプト (`import eem`) 内でのイベント登録とアクション制御。

---

### ラボ試験で狙われやすいポイント ＆ よくある設定ミス

* **IOx / App-Hosting の有効化忘れ**:
  * グローバルで `iox` を設定せずに `guestshell enable` を実行すると、コンテナの起動に失敗します。
* **Guestshell 内の DNS / ネットワーク（VRF）設定未指定**:
  * Guestshell 内から `pip install` や外部 HTTP API 呼出しを行う際、管理ポートの VRF（`Mgmt-vrf`）やプロキシ/DNS (`/etc/resolv.conf`) の設定が不足して通信エラーになるケース。
* **`cli.configure()` に渡す引数の型エラー**:
  * `cli.configure()` に単一の文字列を渡す場合と、コマンドのリスト `['interface Gi1', 'no shut']` を渡す場合の文法ミス。
* **EEM 環境変数と Python スクリプト間の引数受け渡しエラー**:
  * EEM から Python スクリプトを実行する際、`$_syslog_msg` や `$_track_state` などの変数引数の渡し方。

---

## 🛠 設定方法

### 1. Guestshell の有効化と環境構築

```bash
! Step 1: IOx サービスの有効化
Device(config)# iox

! Step 2: App-Hosting の設定（デフォルトで自動生成されるが明示的確認）
Device(config)# app-hosting appid guestshell
Device(config-app-hosting)# app-vnic management guest-share
Device(config-app-hosting)# start
Device(config-app-hosting)# exit

! Step 3: Guestshell の有効化 (EXEC モード)
Device# guestshell enable
Interface VirtualPortGroup0 is created
Guestshell enabled successfully

! Step 4: Guestshell へのログインと状態確認
Device# guestshell run bash
[guestshell@guestshell ~]$ python3 --version
Python 3.8.10
[guestshell@guestshell ~]$ pip list
```

---

### 2. CLI Python モジュール (`import cli`) の使用方法

Python スクリプト内から IOS XE の CLI を操作する標準的コードパターンです。

```python
import cli
import re
import json

# --- 1. cli.cli(): 出力を文字列として取得してパース ---
output = cli.cli("show ip interface brief")
print("=== Output Type ===")
print(type(output))  # <class 'str'>

# 正規表現で UP/UP のインターフェイスを抽出
up_interfaces = []
for line in output.splitlines():
    if "up" in line and "up" in line.split()[-2:]:
        parts = line.split()
        up_interfaces.append({"interface": parts[0], "ip": parts[1]})

print("=== Parsed UP Interfaces ===")
print(json.dumps(up_interfaces, indent=2))

# --- 2. cli.configure(): 設定変更の投入 ---
config_commands = [
    "interface Loopback100",
    "description Created_via_Guestshell_Python",
    "ip address 10.100.100.1 255.255.255.255",
    "no shutdown"
]

print("=== Applying Configurations ===")
res = cli.configure(config_commands)
print(res)

# --- 3. cli.clip() & cli.configp(): コンソール出力付き実行 ---
cli.clip("show clock")
```

---

### 3. EEM Python モジュール (`import eem`) ＆ EEM アプレット連携

#### 方式 A: EEM アプレットから Python スクリプトを呼び出すパターン（推奨）

**IOS XE CLI コンフィグ (EEM アプレット)**:
```bash
event manager applet ON_BGP_DOWN
 event syslog pattern "BGP-5-ADJCHANGE.*Down"
 action 1.0 script python /bootflash/bgp_rebound.py
```

**`/bootflash/bgp_rebound.py` スクリプト内容**:
```python
import cli
import sys
import time

print("[EEM-Python] BGP Down detected. Initiating diagnostic and recovery...")

# 1. 状態の診断情報を収集
bgp_summary = cli.cli("show ip bgp summary")
print(bgp_summary)

# 2. 対象インターフェイスのリセット（セルフヒーリング）
cli.configure([
    "interface GigabitEthernet2",
    "shutdown"
])

time.sleep(2)

cli.configure([
    "interface GigabitEthernet2",
    "no shutdown"
])

print("[EEM-Python] Recovery sequence completed.")
```

#### 方式 B: 純粋な Python EEM スクリプト (`import eem`)

```python
import eem
import cli

# 1. EEM イベントの登録 (定期タイマー: 60秒ごと)
eem.event_register_timer(eem.TIMER_CRON, "0/1 * * * *", name="CRON_CHECK")

# 2. イベント発生時の処理
def main():
    print("Executing periodic EEM Python health check...")
    res = cli.cli("show processes cpu sorted | include CPU")
    print(res)
    eem.action_syslog("EEM Python Health Check executed successfully", priority="info")

if __name__ == "__main__":
    main()
```

---

## 🔍 検証コマンド

Guestshell および IOx アプリケーションホスティング基盤の状態を確認するための検証コマンド一覧です。

| 目的 | コマンド |
| --- | --- |
| IOx / App-Hosting 全体状態確認 | <code>show app-hosting list</code> |
| Guestshell コンテナのリソース利用状況確認 | <code>show app-hosting detail appid guestshell</code> |
| IOx コアプロセス・インフラ状態確認 | <code>show iox-core</code> |
| Guestshell 内での個別 CLI コマンド実行 | <code>guestshell run <command></code> |
| Guestshell 内の Python バージョン確認 | <code>guestshell run python3 --version</code> |
| Guestshell 内のインストール済み pip パッケージ確認 | <code>guestshell run pip list</code> |
| Guestshell 対話型 Bash シェルへのログイン | <code>guestshell run bash</code> |
| Guestshell の再起動 | <code>guestshell reboot</code> |
| Guestshell の無効化・削除 | <code>guestshell disable</code> / <code>guestshell destroy</code> |
| デバッグログの有効化 | <code>debug iox-core</code> / <code>debug app-hosting</code> |

---

## 🚨 トラブルシューティング

Guestshell 運用時に発生する代表的な障害症状、原因、確認コマンド、および対処方法の一覧です。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| `guestshell enable` が失敗する | グローバルで `iox` が設定されていない。またはリソース不足。 | <code>show iox-core</code> | グローバルコンフィグで <code>iox</code> を有効化し、メモリ/Flash 空き容量を確認する。 |
| Guestshell 内から外部（PyPI/インターネット）へ接続できない | Guestshell のネットワーク設定（VRF / DNS / プロキシ）が不適切。 | <code>guestshell run ping 8.8.8.8</code> | `app-hosting` コンフィグで正しく Management VRF (`Mgmt-vrf`) を割り当て、`/etc/resolv.conf` に DNS を設定する。 |
| `import cli` で `ModuleNotFoundError` が発生する | IOS XE 外部の仮想環境（`venv`）を無手順で作成し、システム標準ライブラリパスが破棄されている。 | <code>guestshell run python3 -c "import cli"</code> | システム標準の Python3 環境を使用するか、`venv` 作成時に `--system-site-packages` オプションを付与する。 |
| `cli.configure()` 実行時に `SyntaxError` または設定適用失敗 | 引数として渡したコマンドリスト内に型エラーまたはプロンプトを抜けるコマンドが含まれている。 | Python スクリプト内の <code>try-except</code> ログ | 設定コマンドをリスト形式 `['interface Gi1', 'no shut']` で正確に渡し、対話プロンプト（`exit` 等）の不要な混入を防ぐ。 |
| EEM スクリプトから Python が呼び出されない | スクリプトのファイルパス間違い、実行権限不足、または EEM アプレットの構文ミス。 | <code>show event manager policy registered</code> | スクリプトパス（`/bootflash/script.py`）を確認し、EEM コンフィグの `action script` 構文を修正する。 |

---

## ⚠ 制限事項

* **リソース制限**:
  * Guestshell (LXC) は、IOS XE 物理デバイスの CPU/DRAM リソース（通常 1GB 前後）を消費します。過度な並列処理や無限ループコードは、CPU ガバナーによって制限されるか、IOx プロセスによって強制終了されます。
* **ストレージ永続性**:
  * `/bootflash/` または `/flash/` ディレクトリ配下に保存されたファイルは IOS XE と共有され永続化されますが、Guestshell コンテナ内部の `/tmp` やローカルファイルシステムは `guestshell destroy` / `reboot` 時にリセットされる場合があります。
* **対話型コマンドの制限**:
  * `cli.cli()` または `cli.configure()` では、対話的な応答を要求するコマンド（例: `reload` 実行時の確認 `[confirm]` プロンプト）は自動的にタイムアウトまたは拒否されます。非対話化オプション（`file prompt quiet` 等）の利用が必要です。

---

## 🔄 他技術との関連

* **EEM (Embedded Event Manager)**:
  * EEM アプレットのアクションから Guestshell 内の Python スクリプトを呼び出すことで、従来の CLI アプレットでは不可能だった複雑な文字列解析、外部 REST API 呼出し、動的フェイルオーバーロジックを実現します。
* **Management VRF (`Mgmt-vrf`) & VirtualPortGroup**:
  * Guestshell コンテナは内部仮想ポート（`VirtualPortGroup`）を介して IOS XE の管理プレームまたはデータプレームにバインドされます。ネットワーク自動化やテレメトリ送信の通信経路として直結します。
* **Python API (RESTCONF / NETCONF)**:
  * Guestshell 内の Python からローカルホスト（`127.0.0.1`）の RESTCONF / NETCONF エンドポイントへ HTTP/SSH 通信を行うことで、YANG データモデルに基づいた構造化データの直接取得・変更が可能です。

---

## 🧩 比較表

### 自動化手法・実行環境の比較

| 項目 | Guestshell (On-Box Python) | EEM CLI Applet | Off-Box Python (Netmiko/Paramiko) | RESTCONF / NETCONF |
| --- | --- | --- | --- | --- |
| **実行場所** | ルータ内部 (LXC Container) | ルータ内部 (IOSd Core) | 外部管理サーバ / PC | 外部管理サーバ ➔ ルータ |
| **言語 / 環境** | Python 3 / Linux Shell | IOS CLI 独自構文 / TCL | Python 3 | Python / Go / cURL |
| **データ構造化** | 高い（Python `re`, `json`） | 低い（CLI テキストのみ） | 高い（TextFSM / Genie） | 極めて高い（YANG/JSON/XML） |
| **外部モジュール利用** | 可能 (`pip install`) | 不可 | 可能 (`pip install`) | 不可（標準 HTTP/SSH） |
| **適した用途** | ローカルでの高度なデータ処理・動的障害復旧 | シンプルなイベントトリガー・CLI 実行 | 多数機器の一括構成変更・監査 | 構造化データの高速送受信 |

---

## 💡 ベストプラクティス

1. **スクリプトおよびデータの永続ストレージ保存**:
   * 作成した Python スクリプトや永続化したいログファイルは、必ず `/bootflash/` (または `/flash/`) 配下に保存・配置してください。
2. **例外処理 (`try-except`) の徹底**:
   * `cli.cli()` や `cli.configure()` 呼出し時は、必ず Python の `try-except Exception as e` ブロックで例外をキャッチし、エラー発生時に Syslog (`cli.execute("send log ...")`) やファイルにスタックトレースを出力する設計にしてください。
3. **対話型プロンプトの不使用**:
   * 自動化スクリプト内で対話プロンプトが発生するコマンドを避け、一括適用可能な形式でコマンドリストを `cli.configure()` に渡してください。
4. **`pip` パッケージのオフライン管理**:
   * 試験環境や閉域網ではインターネット（PyPI）へ直接アクセスできないため、必要なライブラリは事前に Wheel ファイル（`.whl`）として Flash へ転送し、`pip install --no-index --find-links=/bootflash/pkg/` でローカルインストールを行ってください。

---

## 📝 ラボ学習・設定サンプル例

CCIE EI v1.1 ラボ試験レベルを意識した、実践的な 10 個の課題・設定例・検証コードです。

---

### ラボ 1: Guestshell の基本有効化と管理 VRF 経由のネットワーク疎通構成

#### 問題
ルータ R1 において Guestshell を有効化し、管理用 VRF (`Mgmt-vrf`) 経由で外部 DNS/IP ネットワークへ接続できるように構成しなさい。

#### 要件
1. グローバルで IOx サービスを有効化すること。
2. Guestshell アプリケーションホスティングにおいて、管理ポート（`GigabitEthernet0/0`）が属する `Mgmt-vrf` を使用すること。
3. Guestshell 内から `8.8.8.8` への IP 疎通を確認すること。

#### 設定例

```bash
! Step 1: IOx の有効化
R1(config)# iox

! Step 2: App-Hosting の確認および起動
R1(config)# app-hosting appid guestshell
R1(config-app-hosting)# app-vnic management guest-share
R1(config-app-hosting)# start
R1(config-app-hosting)# exit

! Step 3: Guestshell の有効化
R1# guestshell enable

! Step 4: Guestshell シェル内でのネットワーク疎通確認
R1# guestshell run ping -c 3 8.8.8.8
```

#### 検証方法
`show app-hosting list` を実行し、State が `RUNNING` であることを確認します。

```bash
R1# show app-hosting list
App id                                   State                   
------------------------------------------------------------------
guestshell                               RUNNING                 
```

---

### ラボ 2: `cli.cli()` を用いたルーティングテーブル（BGP 経路）の構造化パース

#### 問題
Guestshell 内の Python スクリプト `/bootflash/parse_bgp.py` を作成し、`show ip route bgp` の出力をパースして、BGP で学習したネットワークアドレスとネクストホップのペアを JSON 形式で標準出力に表示しなさい。

#### 要件
1. `import cli` モジュールを使用すること。
2. 正規表現（`re` モジュール）を用いて BGP 経路 (`B`) のみを抽出すること。
3. 結果を整形された JSON 文字列 (`json.dumps(..., indent=2)`) として出力すること。

#### 設定例 (`/bootflash/parse_bgp.py`)

```python
import cli
import re
import json

def parse_bgp_routes():
    # 1. CLI コマンドの実行と文字列取得
    raw_output = cli.cli("show ip route bgp")
    
    bgp_routes = []
    
    # 正規表現パターン: B 10.1.1.0/24 [200/0] via 192.168.12.2, 00:10:20
    pattern = re.compile(r'B\s+([\d\.\/\:]+)\s+\[\d+\/\d+\]\s+via\s+([\d\.]+)')
    
    for line in raw_output.splitlines():
        match = pattern.search(line)
        if match:
            network = match.group(1)
            next_hop = match.group(2)
            bgp_routes.append({
                "network": network,
                "next_hop": next_hop,
                "protocol": "BGP"
            })
            
    print(json.dumps(bgp_routes, indent=2))

if __name__ == "__main__":
    parse_bgp_routes()
```

#### 検証方法

```bash
R1# guestshell run python3 /bootflash/parse_bgp.py
[
  {
    "network": "10.1.1.0/24",
    "next_hop": "192.168.12.2",
    "protocol": "BGP"
  },
  {
    "network": "10.2.2.0/24",
    "next_hop": "192.168.12.2",
    "protocol": "BGP"
  }
]
```

---

### ラボ 3: `cli.configure()` を用いた複数 VLAN および SVI 一括動的生成スクリプト

#### 問題
Python スクリプト `/bootflash/create_vlans.py` を作成し、VLAN 100 〜 103 を一括作成し、対応する SVI (VLAN インターフェイス) に IP アドレスを動的に割り当てて有効化しなさい。

#### 要件
1. `cli.configure()` を使用して一括設定投入を行うこと。
2. 引数としてコマンドのリストを動的に生成して渡すこと。

#### 設定例 (`/bootflash/create_vlans.py`)

```python
import cli

def create_vlan_batch():
    commands = []
    vlan_base_ip = "172.16.{vlan_id}.1"
    netmask = "255.255.255.0"
    
    for vlan_id in range(100, 104):
        # VLAN 作成
        commands.append(f"vlan {vlan_id}")
        commands.append(f"name AUTO_VLAN_{vlan_id}")
        
        # SVI (Interface VLAN) 設定
        commands.append(f"interface Vlan{vlan_id}")
        ip_addr = vlan_base_ip.format(vlan_id=vlan_id)
        commands.append(f"ip address {ip_addr} {netmask}")
        commands.append("no shutdown")
        
    print(f"Applying {len(commands)} configuration commands...")
    
    # 一括設定投入
    result = cli.configure(commands)
    print("Execution Result:")
    print(result)

if __name__ == "__main__":
    create_vlan_batch()
```

#### 検証方法

```bash
R1# guestshell run python3 /bootflash/create_vlans.py
R1# show ip interface brief | include Vlan
Vlan100                172.16.100.1    YES manual up                    up      
Vlan101                172.16.101.1    YES manual up                    up      
Vlan102                172.16.102.1    YES manual up                    up      
Vlan103                172.16.103.1    YES manual up                    up      
```

---

### ラボ 4: EEM アプレット ＋ Guestshell Python 連携によるインターフェイス Down 時の自己修復

#### 問題
インターフェイス GigabitEthernet2 が Down した際に、EEM から Guestshell 内の Python スクリプト `/bootflash/auto_recovery.py` を呼び出し、インターフェイスを再起動（`shutdown` ➔ `no shutdown`）して Syslog に通知しなさい。

#### 要件
1. EEM アプレット `SELF_HEAL_GI2` を作成し、`%LINK-3-UPDOWN.*GigabitEthernet2.*DOWN` をトリガーとすること。
2. アプレットのアクションから `python3 /bootflash/auto_recovery.py` を実行すること。
3. EEM 無限ループを防ぐため、スクリプト内で状態チェックを行うこと。

#### 設定例

**EEM コンフィグ (IOS XE CLI)**:
```bash
event manager applet SELF_HEAL_GI2
 event syslog pattern "%LINK-3-UPDOWN: Interface GigabitEthernet2, changed state to down"
 action 1.0 script python /bootflash/auto_recovery.py
```

**Python スクリプト (`/bootflash/auto_recovery.py`)**:
```python
import cli
import time

def recover_interface():
    target_int = "GigabitEthernet2"
    print(f"[Self-Healing] Detected DOWN state on {target_int}. Bouncing interface...")
    
    # インターフェイスの再起動コマンド
    recovery_cmds = [
        f"interface {target_int}",
        "shutdown"
    ]
    cli.configure(recovery_cmds)
    
    time.sleep(3)
    
    recovery_cmds_up = [
        f"interface {target_int}",
        "no shutdown"
    ]
    cli.configure(recovery_cmds_up)
    
    # カスタム Syslog メッセージの発信
    cli.cli(f"send log 6 msg [EEM-Python] Automatically recovered interface {target_int}")

if __name__ == "__main__":
    recover_interface()
```

#### 検証方法
GigabitEthernet2 を手動で `shutdown` した場合に、EEM が起動して自動的に `no shutdown` が投入され、Syslog ログが記録されることを確認します。

---

### ラボ 5: Guestshell Python による CRON スケジュールベースの定期 Show バックアップ

#### 問題
毎時 0 分にルータの `show running-config` および `show ip route` を `/bootflash/backups/` ディレクトリにタイムスタンプ付きファイルとして自動保存する Python スクリプトを作成し、EEM タイマーで実行しなさい。

#### 要件
1. スクリプト `/bootflash/backup_job.py` を作成すること。
2. EEM CRON タイマー (`0 * * * *`) で 1 時間ごとに自動実行させること。

#### 設定例

**EEM コンフィグ (IOS XE CLI)**:
```bash
event manager applet PERIODIC_BACKUP
 event timer cron cron-entry "0 * * * *"
 action 1.0 script python /bootflash/backup_job.py
```

**Python スクリプト (`/bootflash/backup_job.py`)**:
```python
import cli
import os
from datetime import datetime

def perform_backup():
    backup_dir = "/bootflash/backups"
    if not os.path.exists(backup_dir):
        os.makedirs(backup_dir)
        
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    # Running-config の取得と保存
    run_cfg = cli.cli("show running-config")
    cfg_filename = f"{backup_dir}/run_config_{timestamp}.txt"
    with open(cfg_filename, "w") as f:
        f.write(run_cfg)
        
    # Routing Table の取得と保存
    route_output = cli.cli("show ip route")
    route_filename = f"{backup_dir}/ip_route_{timestamp}.txt"
    with open(route_filename, "w") as f:
        f.write(route_output)
        
    print(f"[Backup] Successfully saved configs at {timestamp}")

if __name__ == "__main__":
    perform_backup()
```

#### 検証方法
`event manager run PERIODIC_BACKUP` でアプレットを即時テスト実行し、`/bootflash/backups/` 内にバックアップファイルが正常に生成されたか確認します。

---

### ラボ 6: `cli.clip()` および `cli.configp()` を用いたコンソール直接表示動作

#### 問題
Guestshell 内の Python スクリプト `/bootflash/interactive_check.py` を作成し、`cli.clip()` でクロック状態を表示し、`cli.configp()` で Loopback99 の Description を更新しながら実行ログをコンソールへ直接出力しなさい。

#### 要件
1. 戻り値を文字列変数に受けるのではなく、コンソール（stdout）にダイレクト表示させる関数（`clip` / `configp`）を利用すること。

#### 設定例 (`/bootflash/interactive_check.py`)

```python
import cli

print("=== 1. Displaying Clock via cli.clip() ===")
cli.clip("show clock")

print("\n=== 2. Updating Loopback99 via cli.configp() ===")
update_cmds = [
    "interface Loopback99",
    "description Updated_with_cli_configp",
    "no shutdown"
]

cli.configp(update_cmds)
```

#### 検証方法

```bash
R1# guestshell run python3 /bootflash/interactive_check.py
=== 1. Displaying Clock via cli.clip() ===
*08:15:30.123 UTC Sun Oct 25 2026

=== 2. Updating Loopback99 via cli.configp() ===
interface Loopback99
description Updated_with_cli_configp
no shutdown
```

### ラボ 7: Guestshell Python からローカル REST API への接続と JSON パース

#### 問題
Guestshell 内の Python スクリプトから、ルータ自身の RESTCONF エンドポイントへ HTTPS アクセスし、インターフェイス情報を JSON 取得して表示しなさい。

#### 要件
1. ルータで `restconf` を有効化すること。
2. Guestshell 内の Python `requests` ライブラリを使用すること（SSL 証明書検証無効化 `verify=False`）。
3. HTTP Header として `Accept: application/yang-data+json` を指定すること。

#### 設定例

**IOS XE CLI コンフィグ**:
```bash
R1(config)# ip http server
R1(config)# ip http secure-server
R1(config)# restconf
```

**Python スクリプト (`/bootflash/restconf_local.py`)**:
```python
import requests
import json
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_interfaces_via_restconf():
    url = "https://" + "127.0.0.1" + "/restconf/data/ietf-interfaces:interfaces"
    headers = {
        "Accept": "application/yang-data+json"
    }
    auth = ("admin", "cisco123")
    
    try:
        response = requests.get(url, headers=headers, auth=auth, verify=False)
        if response.status_code == 200:
            data = response.json()
            print("=== RESTCONF JSON Output ===")
            print(json.dumps(data, indent=2))
        else:
            print(f"Failed with Status Code: {response.status_code}")
            print(response.text)
    except Exception as e:
        print(f"Error connecting to RESTCONF: {e}")

if __name__ == "__main__":
    get_interfaces_via_restconf()
```

#### 検証方法

```bash
R1# guestshell run python3 /bootflash/restconf_local.py
=== RESTCONF JSON Output ===
{
  "ietf-interfaces:interfaces": {
    "interface": [
      {
        "name": "GigabitEthernet1",
        "type": "iana-if-type:ethernetCsmacd",
        "enabled": true
      }
    ]
  }
}
```

### ラボ 8: BGP ピア状態監視 ＋ 異常検出時の EEM Python 警報送信

#### 問題
すべての BGP ピアの確立状態を監視し、`Established` 以外の状態にあるピアが検出された場合、Syslog アラートを発行して対象 BGP ネイバーの診断情報をファイル `/bootflash/bgp_issue.log` に記録するスクリプトを作成しなさい。

#### 要件
1. スクリプト `/bootflash/bgp_monitor.py` を作成すること。
2. `show ip bgp summary` の出力を解析し、State/PfxRcd 列を判定すること。

#### 設定例 (`/bootflash/bgp_monitor.py`)

```python
import cli
import re
from datetime import datetime

def check_bgp_peers():
    output = cli.cli("show ip bgp summary")
    lines = output.splitlines()
    
    bgp_down_peers = []
    parsing_peers = False
    
    for line in lines:
        if "Neighbor" in line and "State/PfxRcd" in line:
            parsing_peers = True
            continue
            
        if parsing_peers and line.strip():
            parts = line.split()
            if len(parts) >= 10:
                neighbor_ip = parts[0]
                state_pfx = parts[-1]
                
                if not state_pfx.isdigit():
                    bgp_down_peers.append((neighbor_ip, state_pfx))
                    
    if bgp_down_peers:
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_msg = f"[{timestamp}] ALERT: BGP Down Peers detected: {bgp_down_peers}\n"
        
        cli.cli(f"send log 2 msg [BGP-Monitor] DOWN Peers Detected: {bgp_down_peers}")
        
        with open("/bootflash/bgp_issue.log", "a") as f:
            f.write(log_msg)
            f.write(cli.cli("show ip bgp summary") + "\n" + "="*40 + "\n")
            
        print(f"Issue logged for {len(bgp_down_peers)} down peers.")
    else:
        print("All BGP peers are Established.")

if __name__ == "__main__":
    check_bgp_peers()
```

#### 検証方法
対向 BGP ネイバーを停止させ、`python3 /bootflash/bgp_monitor.py` を実行してアラートが送信され、`/bootflash/bgp_issue.log` に結果が記録されることを確認します。

---

### ラボ 9: Guestshell 内での Python パッケージ（オフライン Whl）インストールと活用

#### 問題
インターネット接続がない環境において、事前に `/bootflash/packages/` に保存された Wheel パッケージ（`pyyaml`）を Guestshell 内の Python3 環境にローカルインストールし、YAML ファイルを読み込んで CLI 設定へ変換しなさい。

#### 要件
1. `pip install --no-index --find-links` オプションを使用してオフラインインストールを行うこと。
2. スクリプト `/bootflash/apply_yaml.py` を作成し、`/bootflash/config.yaml` をパースして設定を適用すること。

#### 設定例

**1. Guestshell 内でのオフライン pip インストールコマンド**:
```bash
R1# guestshell run pip install --no-index --find-links=/bootflash/packages/ pyyaml
```

**2. 入力データ `/bootflash/config.yaml`**:
```yaml
interfaces:
  - name: Loopback201
    ip: 10.201.1.1
    mask: 255.255.255.255
    desc: Generated_via_YAML
  - name: Loopback202
    ip: 10.202.1.1
    mask: 255.255.255.255
    desc: Generated_via_YAML
```

**3. Python スクリプト (`/bootflash/apply_yaml.py`)**:
```python
import yaml
import cli

def apply_config_from_yaml():
    yaml_file = "/bootflash/config.yaml"
    
    with open(yaml_file, "r") as f:
        data = yaml.safe_load(f)
        
    cli_commands = []
    for intf in data.get("interfaces", []):
        cli_commands.append(f"interface {intf['name']}")
        cli_commands.append(f"description {intf['desc']}")
        cli_commands.append(f"ip address {intf['ip']} {intf['mask']}")
        cli_commands.append("no shutdown")
        
    print("Generated Commands:")
    for cmd in cli_commands:
        print(f"  {cmd}")
        
    result = cli.configure(cli_commands)
    print("Configuration Result:")
    print(result)

if __name__ == "__main__":
    apply_config_from_yaml()
```

#### 検証方法

```bash
R1# guestshell run python3 /bootflash/apply_yaml.py
R1# show ip interface brief | include Loopback20
Loopback201            10.201.1.1      YES manual up                    up      
Loopback202            10.202.1.1      YES manual up                    up      
```

---

### ラボ 10: IP SLA Track Down 連動 ➔ Guestshell Python による PBR / Dynamic Route 切り替え

#### 問題
IP SLA プローブ（Track 10）が Down した場合に EEM が起動し、Guestshell Python スクリプト `/bootflash/pbr_failover.py` を呼び出して PBR (Policy-Based Routing) の Next-Hop をセカンダリ WAN（`192.168.20.2`）へ動的に切り替えなさい。

#### 要件
1. Track 10 Down をトリガーとする EEM アプレット `TRACK_FAILOVER` を作成すること。
2. スクリプト内で Route-Map `PBR_POLICY` の Sequence 10 内の `set ip next-hop` を打ち替えること。

#### 設定例

**1. IOS XE CLI コンフィグ**:
```bash
ip sla 1
 icmp-echo 10.0.0.1 source-interface GigabitEthernet1
 frequency 5
ip sla schedule 1 life forever start-time now

track 10 ip sla 1 reachability

route-map PBR_POLICY permit 10
 match ip address 101
 set ip next-hop 192.168.10.1

event manager applet TRACK_FAILOVER
 event track 10 state down
 action 1.0 script python /bootflash/pbr_failover.py
```

**2. Python スクリプト (`/bootflash/pbr_failover.py`)**:
```python
import cli

def switch_pbr_nexthop():
    print("[Failover] Track 10 Down detected. Switching PBR Next-Hop to Backup WAN...")
    
    override_cmds = [
        "route-map PBR_POLICY permit 10",
        "no set ip next-hop 192.168.10.1",
        "set ip next-hop 192.168.20.2"
    ]
    
    result = cli.configure(override_cmds)
    cli.cli("send log 3 msg [PBR-Failover] Successfully switched PBR Next-Hop to 192.168.20.2")
    print(result)

if __name__ == "__main__":
    switch_pbr_nexthop()
```

#### 検証方法
Primary 宛ての IP SLA を遮断（Track 10 が Down）させた際、EEM 経由で Python スクリプトが即座に起動し、`show route-map PBR_POLICY` の `set ip next-hop` が `192.168.20.2` へ更新されていることを確認します。

---

## ❓ 想定試験問題

CCIE EI v1.1 ラボ試験および筆記試験を意識した 5 問の想定問題と解説です。

---

### 問 1 (コンフィグ読解)
以下のコンフィグおよびスクリプト実行結果において、`cli.configure()` 実行後にループバックインターフェイスが作成されなかった原因として最も適切なものを選択しなさい。

**Python スクリプト**:
```python
import cli

cmds = "interface Loopback55\nip address 10.55.55.55 255.255.255.255\nno shutdown"
cli.configure(cmds)
```

* (A) `cli.configure()` は文字列を受け付けず、リスト形式 `['interface Loopback55', ...]` のみをサポートするため
* (B) `cli.configure()` に渡す文字列内の改行コード `\n` が区切り文字として認識されず、単一の不正なコマンドとして処理されたため
* (C) `guestshell` の権限レベルが不足しており、特権 EXEC モードからの設定変更が拒否されたため
* (D) `import cli` モジュールが Guestshell 内で未サポートであるため

**正解**: (B)
**解説**: `cli.configure()` は文字列型（`str`）を引数として受け取ることができますが、改行コード `\n` を区切り文字としてパースせず、単一のコマンド行として処理しようとします。そのため、コマンド構文エラーが発生します。複数行の設定変更を行う場合は、コマンド文字列のリスト `['interface Loopback55', 'ip address 10.55.55.55 255.255.255.255', 'no shutdown']` を渡す必要があります。

---

### 問 2 (トラブルシューティング)
エンジニアが Guestshell 内で新しい Python ライブラリをインストールしようと `pip install requests` を実行したところ、以下のエラーメッセージが表示されました。

```text
[guestshell@guestshell ~]$ pip install requests
WARNING: Retrying (Retry(total=4, ...)) after connection broken by 'NewConnectionError': Failed to establish a new connection: Temporary failure in name resolution
ERROR: Could not find a version that satisfies the requirement requests
```

この障害の原因および最も適切な対処方法の組み合わせを選択しなさい。

* (A) **原因**: Guestshell の IOx プロセスが停止している。
  **対処**: `guestshell reboot` を実行する。
* (B) **原因**: Guestshell コンテナ内で名前解決（DNS）が失敗しており、PyPI サーバーへアクセスできていない。
  **対処**: Guestshell 内の `/etc/resolv.conf` に正しい DNS サーバー（例: `nameserver 8.8.8.8`）を設定するか、`app-hosting` コンフィグで Management VRF のネームサーバーを割り当てる。
* (C) **原因**: Guestshell 内の Python バージョンが `requests` ライブラリと互換性がない。
  **対処**: Python 2.7 へダウングレードする。
* (D) **原因**: `pip` コマンドは Guestshell 内での使用が禁止されている。
  **対処**: `yum` コマンドのみを使用してパッケージを導入する。

**正解**: (B)
**解説**: `Temporary failure in name resolution` は、Guestshell 内での DNS 名前解決の失敗を示しています。Guestshell コンテナが外部 PyPI リポジトリ宛てのドメイン名を解決できるよう、`/etc/resolv.conf` への DNS 指定または管理 VRF（`Mgmt-vrf`）のネームサーバー指定が必要です。

---

### 問 3 (Design)
100 台規模のルータを管理するネットワークにおいて、外部の管理サーバー（Off-Box）を設置せず、ルータ単体（On-Box）でインタフェースの物理エラー（CRC エラー / Drop）を毎分監視し、特定の閾値を超えた場合に特定ポートを自動シャットダウンして管理者宛てにアラートを記録する自己修復システムを設計します。最も適切で安定した技術スタックの組み合わせを選択しなさい。

* (A) EEM CLI アプレット単体＋ Cron タイマー
* (B) EEM アプレット（タイマー判定）＋ Guestshell 内 Python スクリプト (`import cli` ＋ 正規表現解析)
* (C) RESTCONF API ＋ 外部 Ansible 控制サーバー
* (D) IOS XE TCL スクリプト ＋ SNMP Trap

**正解**: (B)
**解説**: 複雑な数値計算（エラーカウンターの毎分増分計算）やテキストパース（`re` 正規表現）、およびしきい値判定をオンボックスで行う場合、EEM アプレットでタイマー駆動し、アクティブなロジック処理を Guestshell 内の Python スクリプト（`cli.cli()` / `cli.configure()`）へ引き渡す設計が最適です。

---

### 問 4 (実装)
EEM アプレットから Guestshell 内の Python スクリプト `/bootflash/scripts/check_status.py` を呼び出して即時実行させるための正しく完全な EEM CLI コンフィグを選択しなさい。

* (A)
  ```bash
  event manager applet RUN_CHECK
   event none
   action 1.0 script python /bootflash/scripts/check_status.py
  ```
* (B)
  ```bash
  event manager applet RUN_CHECK
   event none
   action 1.0 cli command "python3 /bootflash/scripts/check_status.py"
  ```
* (C)
  ```bash
  event manager applet RUN_CHECK
   event none
   action 1.0 guestshell run python /bootflash/scripts/check_status.py
  ```
* (D)
  ```bash
  event manager applet RUN_CHECK
   event none
   action 1.0 execute guestshell /bootflash/scripts/check_status.py
  ```

**正解**: (A)
**解説**: IOS XE の EEM から直接 Guestshell (またはオンボックス) Python スクリプトを呼ぶ標準構文は `action <id> script python <path_to_script>` です。

---

### 問 5 (トラブルシューティング)
エンジニアが EEM アプレットで `action 1.0 script python /bootflash/test.py` を定義してアプレットを動かしたところ、ログに `EEM policy /bootflash/test.py execution failed: No such file or directory` が記録されました。しかし、IOS XE の `dir bootflash:` コマンドで確認すると `test.py` は存在しています。考えられる原因として適切なものを選択しなさい。

* (A) スクリプトの 1 行目（シェバング: `#!/usr/bin/env python3`）が欠落しているか、パーミッション実行権限が付与されていない。
* (B) スクリプトファイル名に小文字が含まれているため。
* (C) EEM から呼び出すスクリプトは `/flash/` ディレクトリにしか保存できないため。
* (D) `guestshell enable` コマンドが実行されていないため。

**正解**: (A)
**解説**: EEM から Python スクリプトを直接 `script python` アクションで実行する場合、スクリプト先頭に正しいインタープリタパス（`#!/usr/bin/env python3` または `#!/usr/bin/python3`）が記述されている必要があり、Linux パーミッション上の実行権限（`chmod +x`）が設定されている必要があります。

---

## 🔗 参考リソース

Cisco 公式ドキュメントおよび各種技術資料の一覧です。

* Cisco IOS XE 17.x Programmability Configuration Guide - Guestshell
* Cisco Technical Notes - How to Enable and Troubleshoot Guestshell on Catalyst 9000 Switches
* Cisco Live BRKPRG-2432 - On-Box Programmability and Automation with Cisco IOS XE
* Cisco DevNet - IOS XE Python API and Guestshell Tutorials
* Cisco Application Hosting Configuration Guide, Cisco IOS XE Release 17.x

---

## 📝 **補足（Notes）**

### 学習メモ ＆ アーキテクチャ構成図

```text
+-------------------------------------------------------------------------+
|                        Cisco IOS XE Environment                         |
|                                                                         |
|  [ IOSd Core Engine ]                                                   |
|    - CLI Parser                                                         |
|    - EEM (Embedded Event Manager)                                       |
|    - Control Plane / Data Plane                                         |
|         ^                                                               |
|         | Internal IPC / Virtual Socket Bridge                          |
|         v                                                               |
|  [ Guestshell LXC Container ] (CentOS / RedHat Linux)                   |
|    - Python 3 Runtime                                                   |
|       * cli module   (cli.cli, cli.configure, cli.clip, cli.configp)   |
|       * eem module   (eem.event_register_*, eem.action_*)               |
|    - Shell Utilities (bash, curl, git, cron, pip)                       |
|    - Network Access via VirtualPortGroup (Mgmt-vrf / Default VRF)       |
+-------------------------------------------------------------------------+
```

### 実装・トラブルシューティング時の要点チェックリスト

1. **IOx / App-Hosting の基本有効化**:
   * グローバルコンフィグで `iox` を忘れずに設定すること。
2. **スクリプトの保存先・パーミッション**:
   * スクリプトは `/bootflash/` に保存し、`#!/usr/bin/env python3` を先頭行に含めること。
3. **`cli.configure()` の引数形式**:
   * コマンドは改行区切り文字列ではなく、必ず **文字列のリスト** (`['cmd1', 'cmd2']`) として渡すこと。
4. **対話プロンプトの回避**:
   * 非対話（Non-interactive）で完結するコマンドを使用すること。

---

