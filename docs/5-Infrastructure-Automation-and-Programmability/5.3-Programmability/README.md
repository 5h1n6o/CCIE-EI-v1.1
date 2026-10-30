---
layout: default
title: 5.3-Programmability
parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 3
---

# 5.3 Programmability

## 📘 概要

* **機能概要**: プログラマビリティ（Programmability）は、従来の CLI (Command Line Interface) や SNMP (Simple Network Management Protocol) による個別の手動運用から脱却し、**モデル駆動型管理（Model-Driven Programmability）** や **REST API**、**イベント駆動型自動化** を用いてネットワーク機器・コントローラの構成変更、状態取得、運用監視をプログラマブルに制御・自動化する技術体系です。
* **利用目的**: 
  1. **高速かつ無停止の構成変更・プロビジョニング**: 人為的コンフィグミスの撲滅と、数千台規模のネットワークデバイスに対する変更適用時間の劇的短縮（数時間 ➔ 数秒）。
  2. **構造化データモデル（YANG）による一貫性保持**: 機器のベンダーや OS バージョンに依存しない統一されたデータ表現（IETF / OpenConfig / Vendor Native）による統一管理。
  3. **リアルタイム可観測性（Model-Driven Telemetry）**: 従来のポーリング型 SNMP の限界（高負荷・低頻度）を超え、1 秒未満のサブセコンド単位でプッシュ型ストリーミングデータを NMS（コレクター）へ転送。
  4. **コントローラ統合（Cisco DNA Center / Catalyst Center, SD-WAN vManage）**: Intent-Based Networking (IBN) アーキテクチャに基づき、北向き REST API を介した抽象化されたポリシー適用と高度なアシュアランス連携。
* **どのような場面で利用するか**: 
  - 大規模エンタープライズ・データセンターにおける Day-0 (初期投入)、Day-1 (サービス展開)、Day-2 (維持運用・トラブルシューティング) の全ライフサイクル自動化。
  - CI/CD パイプライン（Git / NetBox / Ansible / Python）と連携した Network as Code (NaC) の実現。
  - SD-Access (SDA) ファブリックや SD-WAN オーバーレイのコントローラ自動連携。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **主要要素技術** | NETCONF (RFC 6241)、RESTCONF (RFC 8040)、YANG (RFC 6020/7950)、REST API (DNA Center / SD-WAN)、Model-Driven Telemetry (MDT) |
| **データエンコーディング** | XML (NETCONF/RESTCONF)、JSON (RESTCONF/REST API)、gPB (Google Protocol Buffers - gRPC Telemetry) |
| **トランスポート層** | SSH (NETCONF: Port 830)、HTTPS (RESTCONF: Port 443 / REST API: Port 443)、gRPC (HTTP/2: Port 57400) |
| **主なメリット** | 機械判読可能な構造化データ、トランザクション処理 (Atomic/Rollback)、リアルタイム・プッシュ型ストリーミング、プログラム間親和性 |
| **デメリット/課題** | プログラミング知識（Python/REST API/YANG）の習得、HTTPS/SSH 証明書管理、コントロールプレーン CPU/Memory リソース管理 |
| **対応機種/OS** | Cisco Catalyst 9000 シリーズ (IOS XE 16.x/17.x)、ISR 4000 / Catalyst 8000 (IOS XE)、ASR 1000、Cisco vManage / vSmart / vEdge / cEdge |
| **制限事項** | 一部レガシー機能の YANG 未対応（Native YANG で補完）、同時 NETCONF セッション上限（通常 8〜16 セクション）、gRPC ポート開口要件 |
| **設計上の注意点** | AAA (TACACS+/RADIUS) 認証連携、CoPP (Control Plane Policing) でのプログラマビリティポート保護、REST API レート制限 (Rate Limit) 考慮 |

---

## 🏗 動作原理

モデル駆動型プログラマビリティ（Model-Driven Programmability）は、**「データモデル (YANG)」「エンコーディング (XML/JSON/gPB)」「トランスポートプロトコル (SSH/HTTPS/gRPC)」** の 3 つの独立したレイヤーによって階層化されています。

```
+-----------------------------------------------------------------------+
|                       Automation Client / NMS                         |
|   (Python / ncclient / requests / Ansible / Telegraf / Collector)     |
+-----------------------------------------------------------------------+
       │                     │                     │               ▲
       │ NETCONF             │ RESTCONF            │ REST API      │ MDT (Push)
       │ (SSH :830)          │ (HTTPS :443)        │ (HTTPS :443)  │ (gRPC :57400)
       ▼                     ▼                     ▼               │
+-----------------------------------------------------------------------+
|                 Cisco Device / Controller (IOS XE / DNAC)             |
|  +-----------------------------------------------------------------+  |
|  |                  Management Agent (gRPC / HTTPD / SSHD)         |  |
|  +-----------------------------------------------------------------+  |
|                                    │                                  |
|  +-----------------------------------------------------------------+  |
|  |             YANG Data Model Engine (Datastore Management)       |  |
|  |     (Running / Candidate / Startup Datastores & Schema Engine)   |  |
|  +-----------------------------------------------------------------+  |
|                                    │                                  |
|  +-----------------------------------------------------------------+  |
|  |            Cisco Native / IETF / OpenConfig YANG Models         |  |
|  +-----------------------------------------------------------------+  |
|                                    │                                  |
|  +-----------------------------------------------------------------+  |
|  |                  IOS XE Infrastructure & Hardware               |  |
|  +-----------------------------------------------------------------+  |
+-----------------------------------------------------------------------+
```

### 1. NETCONF (RFC 6241)
- **SSH (Port 830)** 上で動作する双方向 RPC (Remote Procedure Call) ベースのプロトコル。
- **XML エンコーディング** のみを使用し、データストア（`running`, `candidate`, `startup`）に対するトランザクション処理（Validate, Commit, Rollback, Lock/Unlock）を提供。

### 2. RESTCONF (RFC 8040)
- **HTTP/HTTPS (Port 443)** 上で動作する RESTful な軽量プロトコル。
- **JSON** および **XML** エンコーディングをサポート。
- HTTP メソッド（GET, POST, PUT, PATCH, DELETE）を用いて、YANG データモデルで定義されたリソースを URL パス（`/restconf/data/...`）として指定・操作。

### 3. REST API (Cisco DNA Center / Cisco SD-WAN vManage)
- コントローラ型アーキテクチャの北向き (Northbound) インターフェイス。
- HTTPS 上で **JSON** ペイロードを送受信し、認証（Token / Session Cookie）を経てネットワーク全体のインテント設定やアシュアランス情報を操作。

### 4. Model-Driven Telemetry (MDT)
- 定期的な SNMP ポーリングの代わりに、機器自体の YANG データモデル構造の変更や定期タイマー（Period）に基づき、**プッシュ型（Push-based）** でコレクター（InfluxDB, Prometheus, ELK）へデータをストリーミング転送。
- Dial-out (機器側からコレクターへ gRPC 出力) および Dial-in (コレクターから機器へ セッション要求) モードをサポート。

---

## ⚙ 動作シーケンス

### A. NETCONF セッション ＆ RPC 実行シーケンス

```
[NETCONF Client (Python)]                       [Cisco IOS XE Router]
          │                                                │
          │ 1. SSH Connection (Port 830) Estblish          │
          ├───────────────────────────────────────────────►│
          │                                                │
          │ 2. <hello> Capability Exchange                 │
          ├───────────────────────────────────────────────►│
          │◄───────────────────────────────────────────────┤ (Capabilities: urn:ietf:params:netconf:base:1.1, etc.)
          │                                                │
          │ 3. <lock> target: <running/>                   │
          ├───────────────────────────────────────────────►│
          │◄───────────────────────────────────────────────┤ 4. <rpc-reply> <ok/>
          │                                                │
          │ 5. <edit-config> target: <running> (XML Data)  │
          ├───────────────────────────────────────────────►│
          │                                                │ 6. Validate & Apply to
          │                                                │    Running Datastore
          │◄───────────────────────────────────────────────┤ 7. <rpc-reply> <ok/> (or <rpc-error>)
          │                                                │
          │ 8. <unlock> target: <running/>                 │
          ├───────────────────────────────────────────────►│
          │◄───────────────────────────────────────────────┤ 9. <rpc-reply> <ok/>
          │                                                │
          │ 10. <close-session>                            │
          ├───────────────────────────────────────────────►│
          │◄───────────────────────────────────────────────┤ 11. <rpc-reply> <ok/> & Close
```

### B. RESTCONF リクエスト処理シーケンス

```
[REST API Client (curl/requests)]               [Cisco IOS XE Router (RESTCONF)]
          │                                                │
          │ 1. HTTPS PATCH /restconf/data/ietf-interfaces:interfaces/interface=GigabitEthernet1
          │    Headers: Content-Type: application/yang-data+json
          │    Body: { "ietf-interfaces:interface": { "description": "Configured via RESTCONF" } }
          ├───────────────────────────────────────────────►│
          │                                                │ 2. Authentication Check (AAA)
          │                                                │ 3. Validate against YANG Schema
          │                                                │ 4. Update Running-Config
          │◄───────────────────────────────────────────────┤
          │ 5. HTTP/1.1 204 No Content (Success)           │
          │    (or HTTP/1.1 400 Bad Request / 415 Error)  │
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験における **5.3 Programmability** セクションでは、手動 CLI 操作だけでなく、Python スクリプト、ncclient、requests ライブラリ、RESTCONF、NETCONF、Cisco DNA Center API、Cisco SD-WAN API を駆使した高精度なオートメーション能力が評価されます。

### 1. Blueprint で重要なポイント
* **NETCONF (RFC 6241) ＆ `ncclient` 実装**:
  * Python の `ncclient.manager` を使用し、SSH ポート 830 経由で IOS XE ルータに接続。
  * XML `<filter>` (Subtree Filter) を構成して指定データ（BGP 状態、Interface 状態等）のみを取得するスキル。
  * `<edit-config>` を使用して Cisco Native YANG や IETF YANG モデルに準拠した設定操作を正確に構築。
* **RESTCONF (RFC 8040) ＆ `requests` 実装**:
  * 正確な URL パス構造 (`/restconf/data/...` および `/restconf/operations/...`) の理解。
  * 適切な HTTP メソッド（GET: 取得、POST: リソース追加/RPC実行、PUT: 置換、PATCH: 部分更新、DELETE: 削除）の使い分け。
  * **必須 HTTP ヘッダー**:
    - `Accept: application/yang-data+json` (または `+xml`)
    - `Content-Type: application/yang-data+json` (または `+xml`)
* **YANG データモデルの検索と構造特定**:
  * IOS XE 機器から YANG モデルを参照、または標準 IETF (`ietf-interfaces`, `ietf-routing`) / OpenConfig / Cisco Native (`Cisco-IOS-XE-native`) のデータ構造を正しく追跡する能力。
* **Cisco DNA Center (Catalyst Center) REST API**:
  * 2 段階認証フロー: `/dna/system/api/v1/auth/token` へ POST 送信してトークン（`X-Auth-Token`）を取得し、以降のリクエストヘッダーにセット。
  * インサイト/インベントリ API (`/dna/intent/api/v1/network-device`) からの特定機器リスト抽出。
* **Cisco SD-WAN vManage REST API**:
  * セッションクッキー（`/j_security_check`）と CSRF トークン（`/dataservice/client/token` ➔ `X-XSRF-TOKEN`）の 2 重認証ハンドリング。
* **Model-Driven Telemetry (MDT)**:
  * IOS XE 上での `telemetry ietf subscription` 設定（Period, XPath Filter, Collector Destination IP/Port, Encoding）。

### 2. よくある設定ミス ＆ 落とし穴
* **HTTP ヘッダーの欠落・指定ミス**:
  * RESTCONF で `Content-Type: application/json` とのみ記述し、`application/yang-data+json` を忘れて `HTTP 415 Unsupported Media Type` エラーとなるケース。
* **NETCONF ポート / SSH サブシステム未有効化**:
  * IOS XE 上で `netconf-yang` を投入したものの、VTY Line や CoPP/ACL で ポート 830 が遮断されている、または SSH が有効化（`crypto key generate rsa`）されていないケース。
* **YANG ネームスペース / XML 属性のミス**:
  * XML ペイロード内で `xmlns` ネームスペース属性を記述し忘れたため、ルータから `<rpc-error>` (Unknown Element) が返却されるケース。
* **JSON 文字列化の誤り**:
  * Python の `True` / `False` をそのまま JSON ペイロードに渡さず、小文字 `true` / `false` へキャストし忘れる、あるいはシングルクォート `'` を使用して構文エラーになるケース。

---

## 🛠 設定方法

### 1. Cisco IOS XE ルータ側：NETCONF / RESTCONF / MDT 有効化 CLI

```bash
! --- AAA 及び SSH 基本設定 ---
hostname R1
ip domain name lab.local
crypto key generate rsa modulus 2048

username admin privilege 15 secret Cisco123!
aaa new-model
aaa authentication login default local
aaa authorization exec default local

! --- NETCONF-YANG 有効化 ---
netconf-yang
netconf-yang cisco-ia auto-sync enabled

! --- RESTCONF 有効化 ---
ip http server
ip http secure-server
ip http authentication local
restconf

! --- Model-Driven Telemetry (gRPC Dial-out) 有効化 ---
telemetry ietf subscription 101
 selector-xpath /process-cpu-ios-xe-oper:cpu-usage/cpu-utilization
 stream yawg
 encoding encode-kvgpb
 filter xpath /process-cpu-ios-xe-oper:cpu-usage/cpu-utilization
 source-address 10.1.1.1
 receiver ip address 10.1.1.100 port 57400 protocol grpc-tcp
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| NETCONF 稼働状態確認 | <code>show netconf-yang sessions</code> |
| NETCONF 統計情報確認 | <code>show netconf-yang statistics</code> |
| RESTCONF 状態確認 | <code>show restconf status</code> |
| HTTP サーバー稼働状態確認 | <code>show ip http server status</code> |
| Telemetry サブスクリプション確認 | <code>show telemetry ietf subscription all</code> |
| Telemetry 受信機（Receiver）状態 | <code>show telemetry ietf subscription 101 receiver</code> |
| NETCONF/RESTCONF デバッグ | <code>debug netconf-yang all</code> / <code>debug restconf all</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **NETCONF 接続時 `Connection Refused`** | `netconf-yang` 未設定、または SSH ポート 830 が不許可 | <code>show netconf-yang status</code> / <code>show ip sockets</code> | `netconf-yang` を設定し、ACL/CoPP で Port 830 を許可 |
| **RESTCONF 送信時 `415 Unsupported Media Type`** | HTTP ヘッダー `Content-Type` の指定ミス | Python / curl レクエストヘッダー確認 | `Content-Type: application/yang-data+json` を明示指定 |
| **RESTCONF 送信時 `401 Unauthorized`** | AAA 認証失敗、または IP HTTP Auth 設定漏れ | <code>show ip http server status</code> | `ip http authentication local` および AAA exec authorization を確認 |
| **NETCONF `<rpc-error>` (Invalid Element)** | XML ペイロードの YANG スキーマ不一致、または `xmlns` 欠落 | <code>debug netconf-yang trace</code> | YANG モデル定義（`Cisco-IOS-XE-native` 等）に一致する XML へ修正 |
| **Telemetry データの未送信** | Receiver IP/Port 到達不能、または XPath Filter エラー | <code>show telemetry ietf subscription 101 receiver</code> | Receiver への L3 到達性と指定 XPath の妥当性を検証 |

---

## ⚠ 制限事項

* **NETCONF 同時セッション制限**: Cisco IOS XE では、パフォーマンス維持のため同時に開ける NETCONF セッション数に上限（デフォルト 8〜16）が存在します。スクリプト終了時には必ず `manager.close_session()` を実行してください。
* **RESTCONF Candidate Datastore 未サポート**: 多くの IOS XE バージョンにおいて、RESTCONF は `candidate` データストアへの段階コミット（Validate/Commit）をサポートしておらず、HTTP リクエスト成功時に即座に `running-config` へ直接反映されます。
* **YANG データモデルのバージョン依存**: Cisco Native YANG モデルは IOS XE のバージョン（16.x / 17.x）によって構造が一部変更される場合があります。

---

## 🔄 他技術との関連

* **Control Plane Policing (CoPP)**: NETCONF (TCP 830)、RESTCONF (TCP 443)、Telemetry (TCP 57400) パケットが CoPP ポリサーによって破棄されないよう、Class-Map で保護する必要があります。
* **AAA (Authentication, Authorization, Accounting)**: NETCONF/RESTCONF セッションはルータの AAA 設定に完全に連動します。ユーザーに Privilege 15 および Exec Authorization 権限が付与されている必要があります。
* **Cisco DNA Center / SD-WAN Controller**: プログラマビリティの概念は個別ルータ制御だけでなく、DNA Center や SD-WAN vManage などのコントローラ REST API 制御へと拡張されます。

---

## 🧩 比較表

### NETCONF vs RESTCONF vs MDT (Telemetry)

| 比較項目 | NETCONF (RFC 6241) | RESTCONF (RFC 8040) | Model-Driven Telemetry (MDT) |
| --- | --- | --- | --- |
| **通信方向** | 双方向 (Pull/Push) | 双方向 (Pull/Push) | 単方向 (Push-based Stream) |
| **トランスポート** | SSH (Port 830) | HTTPS (Port 443) | gRPC / Dial-out / Dial-in |
| **データエンコーディング** | XML | JSON / XML | KV-gPB (Google Protocol Buffers) / JSON |
| **データストア概念** | Candidate, Running, Startup | Running (直接更新) | N/A (Operational Data Only) |
| **主な用途** | 機器のバッチ構成変更・厳密なトランザクション | Web/アプリ連携・軽量な CRUD 操作 | 高頻度・ミリ秒精度の可観測性・リアルタイム監視 |
| **トランザクション制御** | サポート (`<lock>`, `<validate>`, `<commit>`) | 限定的（単一リクエスト内のみ） | N/A |

---

## 💡 ベストプラクティス

1. **明示的なセッションクローズ**: Python `ncclient` や `requests.Session()` を使用する際は、`with` ステートメントまたは明示的な `close()` を呼び出し、ルータ上のセッションリソース枯渇を回避する。
2. **RESTCONF ヘッダーの定数化**: スクリプト冒頭で `HEADERS = {'Accept': 'application/yang-data+json', 'Content-Type': 'application/yang-data+json'}` を定義し、誤記を防止する。
3. **Telemetry のサンプリング頻度最適化**: CPU 利用率などの低変動メトリクスは 60 秒間隔、インターフェイスカウンターや QoS 破棄などの高変動メトリクスは 5 秒〜10 秒間隔へ個別に最適化設計する。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: Python `ncclient` (NETCONF) を用いた IOS XE ルータからの BGP 状態取得

#### 【問題】
Python の `ncclient` ライブラリを使用し、ルータ R1 (10.1.1.1) に NETCONF (Port 830) で接続して、BGP ネイバー状態を取得するスクリプトを作成しなさい。

#### 【要件】
* NETCONF ポート: 830
* 認証情報: ユーザー名 `admin`、パスワード `Cisco123!`
* 取得対象: Subtree Filter を用いた BGP 構成
* 取得した XML 応答をインデント付きで整形出力すること。

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import xml.dom.minidom
from ncclient import manager

HOST = "10.1.1.1"
PORT = 830
USER = "admin"
PASS = "Cisco123!"

netconf_filter = """
<filter xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="http://cisco-domain/ns/yang/Cisco-IOS-XE-native">
    <router>
      <bgp/>
    </router>
  </native>
</filter>
"""

def main():
    with manager.connect(
        host=HOST, port=PORT, username=USER, password=PASS,
        hostkey_verify=False, device_params={"name": "iosxe"}
    ) as m:
        print(f"[*] Connected to {HOST} via NETCONF. Session ID: {m.session_id}")
        response = m.get_config(source="running", filter=netconf_filter)
        xml_doc = xml.dom.minidom.parseString(response.xml)
        print("[+] Received BGP Configuration XML:")
        print(xml_doc.toprettyxml(indent="  "))

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
python3 get_bgp_netconf.py
```

---

### ラボ 2: Python `ncclient` (NETCONF) `<edit-config>` による BGP Neighbor 追加

#### 【問題】
ルータ R1 に対して NETCONF `<edit-config>` リクエストを送信し、BGP AS 65000 に Neighbor `192.168.1.2` (Remote-AS 65000) を動的に構成しなさい。

#### 【要件】
* 対象データストア: `running`
* 操作: `merge` (既存設定を保持し変更追加)

#### 【設定・コード例】

```python
#!/usr/bin/env python3
from ncclient import manager

HOST = "10.1.1.1"
PORT = 830
USER = "admin"
PASS = "Cisco123!"

payload = """
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="http://cisco-domain/ns/yang/Cisco-IOS-XE-native">
    <router>
      <bgp xmlns="http://cisco-domain/ns/yang/Cisco-IOS-XE-bgp">
        <id>65000</id>
        <neighbor>
          <id>192.168.1.2</id>
          <remote-as>65000</remote-as>
        </neighbor>
      </bgp>
    </router>
  </native>
</config>
"""

def main():
    with manager.connect(
        host=HOST, port=PORT, username=USER, password=PASS,
        hostkey_verify=False, device_params={"name": "iosxe"}
    ) as m:
        rpc_reply = m.edit_config(target="running", config=payload)
        print("[+] NETCONF Edit-Config Response:")
        print(rpc_reply)

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
R1# show ip bgp summary
```

---

### ラボ 3: Python `requests` (RESTCONF) を用いた Loopback インターフェイス作成 (POST)

#### 【問題】
RESTCONF API (HTTPS) を使用し、ルータ R1 上に `Loopback100` (IP: `172.16.100.1/32`) を作成する Python スクリプトを作成しなさい。

#### 【要件】
* HTTP メソッド: `POST`
* Headers: `Content-Type: application/yang-data+json`, `Accept: application/yang-data+json`

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HOST = "10.1.1.1"
URL = f"https://{HOST}/restconf/data/ietf-interfaces:interfaces"
AUTH = ("admin", "Cisco123!")
HEADERS = {
    "Accept": "application/yang-data+json",
    "Content-Type": "application/yang-data+json"
}

payload = {
    "ietf-interfaces:interface": {
        "name": "Loopback100",
        "description": "Created via RESTCONF POST",
        "type": "iana-if-type:softwareLoopback",
        "enabled": True,
        "ietf-ip:ipv4": {
            "address": [
                {
                    "ip": "172.16.100.1",
                    "netmask": "255.255.255.255"
                }
            ]
        }
    }
}

def main():
    response = requests.post(URL, auth=AUTH, headers=HEADERS, json=payload, verify=False)
    print(f"[*] HTTP Status Code: {response.status_code}")
    if response.status_code == 201:
        print("[+] Loopback100 successfully created!")

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
R1# show ip interface brief Loopback100
```

---

### ラボ 4: Python `requests` (RESTCONF) を用いた Interface Description 変更 (PATCH)

#### 【問題】
ルータ R1 の `GigabitEthernet1` の Description を RESTCONF `PATCH` メソッドを用いて `"Automated-Uplink-Interface"` に変更しなさい。

#### 【要件】
* HTTP メソッド: `PATCH`

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HOST = "10.1.1.1"
URL = f"https://{HOST}/restconf/data/ietf-interfaces:interfaces/interface=GigabitEthernet1"
AUTH = ("admin", "Cisco123!")
HEADERS = {
    "Accept": "application/yang-data+json",
    "Content-Type": "application/yang-data+json"
}

payload = {
    "ietf-interfaces:interface": {
        "name": "GigabitEthernet1",
        "description": "Automated-Uplink-Interface"
    }
}

def main():
    res = requests.patch(URL, auth=AUTH, headers=HEADERS, json=payload, verify=False)
    print(f"[*] Response Status Code: {res.status_code}")
    if res.status_code == 204:
        print("[+] Description updated successfully.")

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
R1# show interface GigabitEthernet1 | include Description
```

---

### ラボ 5: Python `requests` (RESTCONF) を用いた OSPF 設定削除 (DELETE)

#### 【問題】
ルータ R1 上の OSPF プロセス (Process ID 1) の設定を RESTCONF `DELETE` メソッドで削除しなさい。

#### 【要件】
* HTTP メソッド: `DELETE`

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HOST = "10.1.1.1"
URL = f"https://{HOST}/restconf/data/Cisco-IOS-XE-native:native/router/ospf=1"
AUTH = ("admin", "Cisco123!")
HEADERS = {"Accept": "application/yang-data+json"}

def main():
    res = requests.delete(URL, auth=AUTH, headers=HEADERS, verify=False)
    print(f"[*] DELETE Status Code: {res.status_code}")
    if res.status_code in [200, 204]:
        print("[+] OSPF Process 1 deleted successfully.")

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
R1# show running-config | section router ospf
```

---

### ラボ 6: Cisco DNA Center REST API トークン取得 ＆ ネットワーク機器一覧抽出

#### 【問題】
Cisco DNA Center (10.200.1.1) に REST API でアクセスし、認証トークンを取得した上で、登録されているネットワーク機器の一覧 (IP, Hostname, Platform) を抽出・出力する Python スクリプトを作成しなさい。

#### 【要件】
1. トークン取得 API: `/dna/system/api/v1/auth/token`
2. 機器一覧取得 API: `/dna/intent/api/v1/network-device`
3. 取得したトークンを `X-Auth-Token` ヘッダーにバインドして GET 送信すること。

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DNAC_IP = "10.200.1.1"
AUTH = ("dnac_user", "Cisco123!")
HEADERS_BASE = {"Content-Type": "application/json"}

def get_auth_token():
    url = f"https://{DNAC_IP}/dna/system/api/v1/auth/token"
    res = requests.post(url, auth=AUTH, headers=HEADERS_BASE, verify=False)
    res.raise_for_status()
    token = res.json().get("Token")
    print("[+] Successfully obtained DNAC Auth Token.")
    return token

def get_network_devices(token):
    url = f"https://{DNAC_IP}/dna/intent/api/v1/network-device"
    headers = {
        "Content-Type": "application/json",
        "X-Auth-Token": token
    }
    res = requests.get(url, headers=headers, verify=False)
    res.raise_for_status()
    devices = res.json().get("response", [])
    
    print(f"[+] Found {len(devices)} Network Devices:")
    for dev in devices:
        print(f"  - Hostname: {dev.get('hostname')}, IP: {dev.get('managementIpAddress')}, Platform: {dev.get('platformId')}")

def main():
    try:
        token = get_auth_token()
        get_network_devices(token)
    except Exception as e:
        print("[-] API Execution Error:", e)

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
python3 dnac_get_devices.py
```

---

### ラボ 7: Cisco SD-WAN vManage REST API 2重認証ハンドリング (Session Cookie & XSRF Token)

#### 【問題】
Cisco SD-WAN vManage (10.100.1.1) に対して REST API 接続を行い、セッションクッキーと `X-XSRF-TOKEN` を取得後、全 WAN Edge のデバイスリストを取得するスクリプトを作成しなさい。

#### 【要件】
* `requests.Session()` を使用してセッション状態を維持すること。
* 認証 API: `/j_security_check`
* XSRF トークン API: `/dataservice/client/token`
* デバイス一覧 API: `/dataservice/device`

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

VMANAGE_IP = "10.100.1.1"
BASE_URL = f"https://{VMANAGE_IP}"
USER, PASS = "vmanage_admin", "Cisco123!"

def main():
    session = requests.Session()
    session.verify = False
    
    # 1. ユーザー認証 (Session Cookie 取得)
    login_url = f"{BASE_URL}/j_security_check"
    login_data = {"j_username": USER, "j_password": PASS}
    res_login = session.post(login_url, data=login_data)
    
    if "login" in res_login.text.lower():
        print("[-] Authentication Failed!")
        return
    print("[+] vManage Session Cookie Authenticated.")

    # 2. XSRF Token 取得
    token_url = f"{BASE_URL}/dataservice/client/token"
    res_token = session.get(token_url)
    xsrf_token = res_token.text
    session.headers.update({"X-XSRF-TOKEN": xsrf_token})
    print(f"[+] Obtained XSRF Token: {xsrf_token[:10]}...")

    # 3. WAN Edge デバイス一覧取得
    device_url = f"{BASE_URL}/dataservice/device"
    res_dev = session.get(device_url)
    devices = res_dev.json().get("data", [])
    
    print(f"[+] Received {len(devices)} SD-WAN Devices:")
    for dev in devices:
        print(f"  - System IP: {dev.get('system-ip')}, Hostname: {dev.get('host-name')}, Reachability: {dev.get('reachability')}")

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
python3 vmanage_get_devices.py
```

---

### ラボ 8: Python `xml.etree.ElementTree` による NETCONF XML 応答からの特定データパース

#### 【問題】
NETCONF の応答 XML 文字列から、Python の標準ライブラリ `xml.etree.ElementTree` を使用して、すべてのインターフェイス名と設定されている IPv4 アドレスを抽出・表示しなさい。

#### 【要件】
* NETCONF/IETF インターフェイスの XML ネームスペースを意識して XPath 検索すること。

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import xml.etree.ElementTree as ET

xml_data = """
<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="101">
  <data>
    <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
      <interface>
        <name>GigabitEthernet1</name>
        <description>WAN Uplink</description>
        <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ip">
          <address>
            <ip>10.1.1.1</ip>
            <netmask>255.255.255.0</netmask>
          </address>
        </ipv4>
      </interface>
      <interface>
        <name>Loopback0</name>
        <description>Router ID</description>
        <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ip">
          <address>
            <ip>1.1.1.1</ip>
            <netmask>255.255.255.255</netmask>
          </address>
        </ipv4>
      </interface>
    </interfaces>
  </data>
</rpc-reply>
"""

def main():
    root = ET.fromstring(xml_data)
    
    ns = {
        'nc': 'urn:ietf:params:xml:ns:netconf:base:1.0',
        'if': 'urn:ietf:params:xml:ns:yang:ietf-interfaces',
        'ip': 'urn:ietf:params:xml:ns:yang:ietf-ip'
    }
    
    print("[+] Extracted Interface Configuration:")
    for intf in root.findall('.//if:interface', namespaces=ns):
        name = intf.find('if:name', namespaces=ns).text
        desc = intf.find('if:description', namespaces=ns)
        desc_text = desc.text if desc is not None else "N/A"
        
        ip_elem = intf.find('.//ip:ip', namespaces=ns)
        ip_text = ip_elem.text if ip_elem is not None else "No IP"
        
        print(f"  - Interface: {name:<20} IP: {ip_text:<16} Desc: {desc_text}")

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
python3 parse_xml_interfaces.py
```

---

### ラボ 9: IOS XE 上での gRPC Dial-out Model-Driven Telemetry (MDT) 設定

#### 【問題】
ルータ R1 上で、CPU 利用率 (`/process-cpu-ios-xe-oper:cpu-usage/cpu-utilization`) を 10 秒間隔で Collector (10.1.1.100:57400) へ gRPC Dial-out 転送する Telemetry Subscription 200 を作成しなさい。

#### 【要件】
* Subscription ID: `200`
* Encoding: `encode-kvgpb` (Key-Value Google Protocol Buffers)
* Protocol: `grpc-tcp`

#### 【設定・コード例】

```bash
R1(config)# telemetry ietf subscription 200
R1(config-mdt-sub)# selector-xpath /process-cpu-ios-xe-oper:cpu-usage/cpu-utilization
R1(config-mdt-sub)# stream yawg
R1(config-mdt-sub)# encoding encode-kvgpb
R1(config-mdt-sub)# period 1000
R1(config-mdt-sub)# source-address 10.1.1.1
R1(config-mdt-sub)# receiver ip address 10.1.1.100 port 57400 protocol grpc-tcp
R1(config-mdt-sub)# exit
```

#### 【検証方法】
```bash
R1# show telemetry ietf subscription 200 detail
R1# show telemetry ietf subscription 200 receiver
```

---

### ラボ 10: Python スクリプトによる NETCONF / RESTCONF 統合ヘルスチェック

#### 【問題】
複数の Catalyst スイッチに対して NETCONF 及び RESTCONF 双方のポート接続性・認証・基本応答をチェックし、結果をサマリ表示する自動化スクリプトを作成しなさい。

#### 【要件】
* NETCONF (830) と RESTCONF (443) の双方をテスト。
* 一方のプロトコルが失敗しても処理を中断せず、エラー理由を出力すること。

#### 【設定・コード例】

```python
#!/usr/bin/env python3
import requests
import urllib3
from ncclient import manager

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

DEVICES = [
    {"host": "10.1.1.1", "user": "admin", "pass": "Cisco123!"},
    {"host": "10.1.1.2", "user": "admin", "pass": "Cisco123!"}
]

def check_netconf(host, user, password):
    try:
        with manager.connect(
            host=host, port=830, username=user, password=password,
            hostkey_verify=False, timeout=5, device_params={"name": "iosxe"}
        ) as m:
            return True, f"NETCONF OK (Session ID: {m.session_id})"
    except Exception as e:
        return False, f"NETCONF Error: {str(e)[:50]}"

def check_restconf(host, user, password):
    url = f"https://{host}/restconf/data/ietf-interfaces:interfaces"
    headers = {"Accept": "application/yang-data+json"}
    try:
        res = requests.get(url, auth=(user, password), headers=headers, verify=False, timeout=5)
        if res.status_code == 200:
            return True, "RESTCONF OK (HTTP 200)"
        else:
            return False, f"RESTCONF Failed (HTTP {res.status_code})"
    except Exception as e:
        return False, f"RESTCONF Error: {str(e)[:50]}"

def main():
    print("[*] Starting Automation Protocol Health Check...\n")
    for dev in DEVICES:
        host = dev["host"]
        print(f"=== Target Device: {host} ===")
        
        nc_ok, nc_msg = check_netconf(host, dev["user"], dev["pass"])
        rc_ok, rc_msg = check_restconf(host, dev["user"], dev["pass"])
        
        print(f"  [NETCONF]  {'PASS' if nc_ok else 'FAIL'} -> {nc_msg}")
        print(f"  [RESTCONF] {'PASS' if rc_ok else 'FAIL'} -> {rc_msg}")
        print()

if __name__ == "__main__":
    main()
```

#### 【検証方法】
```bash
python3 healthcheck_programmability.py
```

---

## ❓ 想定試験問題

### 【問題 1：RESTCONF ヘッダー ＆ エラー解析】
ネットワーク自動化スクリプトで RESTCONF API を使用してルータのインターフェイス構成を GET 取得しようとしたところ、ルータから `HTTP 415 Unsupported Media Type` エラーが返却されました。スクリプトのどの部分を修正すべきか答えなさい。

#### 【回答・解説】
`HTTP 415 Unsupported Media Type` は、クライアントが送信したリクエストヘッダーの `Content-Type` または `Accept` がサーバー（RESTCONF エージェント）の要求するメディアタイプと合致していない場合に発生します。
RESTCONF API (RFC 8040) では、リクエストヘッダーに以下を指定する必要があります。
* `Accept: application/yang-data+json` （または `application/yang-data+xml`）
* `Content-Type: application/yang-data+json` （または `application/yang-data+xml`）

---

### 【問題 2：NETCONF セッション ＆ セキュリティ設定】
ルータ R1 に対して Python `ncclient` から NETCONF 接続を試みたが、`ConnectionRefusedError` が発生しました。IOS XE ルータ側で確認すべき設定項目を 3 つ挙げなさい。

#### 【回答・解説】
1. **`netconf-yang` 設定の有無**: グローバルコンフィグレーションモードで `netconf-yang` が有効化されているか。
2. **SSH / RSA キーの作成と VTY 設定**: `crypto key generate rsa` で SSH キーが生成され、`transport input ssh` が許可されているか。
3. **ポート 830 の到達性と CoPP / ACL**: ACL や CoPP (Control Plane Policing) で TCP ポート 830 がドロップされていないか。

---

### 【問題 3：Design / NETCONF vs RESTCONF 選定】
1,000 台のルータに対する夜間一括コンフィグ更新処理において、変更前の設定事前検証 (`<validate>`) と適用失敗時のロールバック機能を厳密に担保したい場合、NETCONF と RESTCONF のどちらのプロトコルを選定すべきか。理由とともに答えなさい。

#### 【回答・解説】
**NETCONF** を選定すべきです。
NETCONF は Candidate Datastore、`<validate>` 命令、`<commit>`、および明示的なセッションロック (`<lock>`) / ロールバックメカニズム（トランザクション制御）をプロトコルレベルで標準サポートしています。一方、RESTCONF は Candidate Datastore やアトミックなトランザクション制御を持たず、HTTP リクエスト時に `running-config` へ直接反映されるため、厳密な事前検証とロールバックが必要なバッチ処理には NETCONF が適しています。

---

### 【問題 4：Python XML パース / ネームスペース処理】
`xml.etree.ElementTree` を用いて NETCONF 応答 XML をパースする際、`root.find('.//interface')` を実行したところ結果が `None` となりました。XML 内には `<interface>` タグが存在します。原因と正解コードを示しなさい。

#### 【回答・解説】
**原因**: XML タグにネームスペース (`xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"`) が宣言されているため、プレフィックスなしのタグ名指定では ElementTree が不一致と判定するため。
**修正コード**:
```python
ns = {'if': 'urn:ietf:params:xml:ns:yang:ietf-interfaces'}
interface_node = root.find('.//if:interface', namespaces=ns)
```

---

### 【問題 5：Cisco DNA Center REST API 認証フロー】
Cisco DNA Center (Catalyst Center) Intent API を呼び出してデバイスインベントリを取得する際の正しい HTTP リクエスト順序と認証ヘッダー名を答えなさい。

#### 【回答・解説】
1. **第一段階 (トークン取得)**: `POST /dna/system/api/v1/auth/token` へ HTTP Basic Auth (ユーザー名/パスワード) を付与してリクエストを送信し、応答 JSON から `Token` 値を取得する。
2. **第二段階 (API 実行)**: 取得したトークンを **`X-Auth-Token`** ヘッダーにセットし、`GET /dna/intent/api/v1/network-device` などの Intent API リクエストを送信する。

---

### 【問題 6：Cisco SD-WAN vManage REST API 二重認証】
vManage REST API に対してデータの変更操作 (POST / PUT / DELETE) を行う際、単なるセッションクッキーの保持に加えて取得・送信が必要となる認証トークンの名称と HTTP ヘッダー名を答えなさい。

#### 【回答・解説】
* **トークン名称**: CSRF Token (Cross-Site Request Forgery Token)
* **取得 API**: `/dataservice/client/token`
* **送信ヘッダー名**: **`X-XSRF-TOKEN`**

---

### 【問題 7：Model-Driven Telemetry (MDT) エンコーディング選定】
帯域幅を極力圧迫せず、ミリ秒単位で高頻度にパフォーマンスデータを送出したい場合、推奨される Telemetry エンコーディング規格を答えなさい。

#### 【回答・解説】
**`encode-kvgpb` (Key-Value Google Protocol Buffers)**。
gPB はバイナリフォーマットであり、テキストベースの JSON や XML と比較してパケットペイロードサイズが極めて小さく、シリアライズ/デシリアライズの CPU 負荷も軽微であるため、高頻度ストリーミングに最適です。

---

### 【問題 8：トラブルシューティング / RESTCONF JSON キー名】
RESTCONF で IETF Interfaces モデルにアクセスして IPv4 アドレスを追加しようとした際、`400 Bad Request` エラーが発生しました。JSON ペイロード内のキー名を `"ipv4"` と記述していました。正しいキー名を答えなさい。

#### 【回答・解説】
**`"ietf-ip:ipv4"`**。
異なる YANG モジュールに由来する Augment（機能拡張）要素を指定する場合、YANG ネームスペースプレフィックス（`ietf-ip:`）をキー名の先頭に付与する必要があります。

---

## 🔗 参考リソース

* Cisco Live: Model-Driven Programmability Deep Dive (BRKPRG-2001)
* Cisco IOS XE Configuration Guide: Programmability Configuration Guide
* Cisco Developer Network (DevNet): IOS XE RESTCONF / NETCONF API Reference
* Cisco Catalyst Center REST API Reference
* Cisco SD-WAN vManage REST API Documentation
* RFC 6241: Network Configuration Protocol (NETCONF)
* RFC 8040: RESTCONF Protocol
* RFC 7950: The YANG 1.1 Data Modeling Language

---

## 📝 補足（Notes）

* **学習メモ**:
  - NETCONF は SSH ポート 830、RESTCONF は HTTPS ポート 443 で動作。
  - RESTCONF のメディアタイプは `application/yang-data+json` または `+xml` を必ず指定。
  - Cisco Catalyst Center API は `X-Auth-Token`、vManage API は `X-XSRF-TOKEN` を使用。
* **注意点**:
  - `ncclient` セッションは明示的にクローズ（`m.close_session()`）してルータのプロセス枯渇を防止する。
  - JSON では大文字小文字（`true`/`false`）を厳密に管理する。

---
