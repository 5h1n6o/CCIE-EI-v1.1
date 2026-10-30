---
layout: default
title: 5.1-Data-encoding
parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.1 Data encoding formats

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint におけるオートメーション・プログラマビリティの基礎であり、RESTCONF、NETCONF、Ansible、Python (json/pyyaml/xml)、Cisco DNA Center (Catalyst Center) API、Cisco SD-WAN vManage API などのネットワークプログラマビリティ技術を支えるコア要素である **`5.1 Data encoding formats (JSON, XML, YAML)`** について、CCIE EI ラボ試験および筆記試験（ENCOR）で問われる実戦的知識、データ構造の構文規則、相互変換、シリアライズ/デシリアライズ、トラブルシューティング手法を網羅した詳細学習メモ。

---

## 📘 概要

### 機能概要
**Data Encoding Formats（データエンコーディングフォーマット）** は、構造化されたデータ（ネットワーク構成情報、ステータス情報、APIレスポンス、システムイベントなど）をコンピュータ間やアプリケーション間で一貫性を保ちながら交換するためのデータ記述形式である。
ネットワークプログラマビリティ分野においては、CLI（Command Line Interface）のような人間が読む前提の非構造化テキストデータ（Unstructured Text）から脱却し、**構造化データ（Structured Data）** として機器とコントローラ/スクリプト間でやり取りするために標準データエンコーディングフォーマットが利用される。

主要な3大エンコーディングフォーマット：
1. **JSON (JavaScript Object Notation - RFC 8259):**
   軽量なテキストベースのデータ交換形式。キーと値のペア（Key-Value Pairs）および順序付けられたリスト（Arrays）を基本構造とする。REST API（RESTCONF、Cisco DNA Center、SD-WAN vManage）の標準フォーマットとして広く採用されている。
2. **XML (eXtensible Markup Language - W3C Standard):**
   タグ（Tag）ベースで階層構造を表現するマークアップ言語。属性（Attribute）やネームスペース（Namespace: `xmlns`）をサポートし、厳密なスキーマ検証（XSD, YANG）が可能。NETCONF (RFC 6241) および RESTCONF (RFC 8040) の標準エンコーディングとして必須。
3. **YAML (YAML Ain't Markup Language):**
   インデント（オフセット空間）を用いた人間に最も読みやすいデータシリアライゼーション形式。Ansible Playbook、Docker Compose、Kubernetes マニフェスト、Cisco SD-WAN CLI テンプレートの定義ファイルとして標準利用される。

### 利用目的
* **ネットワーク構成情報のプログラマブルな取得・設定:**
  RESTCONF / NETCONF や API を経由して、ネットワーク機器のコンフィグやステータスを JSON/XML ペイロードとして送信・受信する。
* **構成管理の自動化（Configuration Management）:**
  Ansible や Python スクリプトでネットワーク設定パラメータ（変数ファイル）を YAML / JSON として管理し、Jinja2 テンプレートエンジンと組み合わせることで大規模環境への一括適用を実現する。
* **データモデル（YANG Model）のシリアライズ:**
  YANG データモデルで定義されたデータ構造（`ietf-interfaces` や `Cisco-IOS-XE-native` など）を、実際の転送プロトコル（NETCONF/RESTCONF）上で表現するための標準形式として機能する。

### どのような場面で利用するか
* Cisco DNA Center (Catalyst Center) や Cisco SD-WAN vManage の REST API を Python スクリプト (`requests` ライブラリ) で叩き、JSON レスポンスを取得してパース・分析するとき。
* Cisco IOS XE 機器に対し、NETCONF (`ncclient` ライブラリ) で XML パケットを送信してインターフェイス設定やルーティング設定を変更・取得するとき。
* RESTCONF 経由で `application/yang-data+json` または `application/yang-data+xml` を HTTP `POST`/`PUT`/`PATCH` で送信し、構成を書き換えるとき。
* Ansible Playbook (`.yml` / `.yaml`) を記述し、マルチベンダー環境のネットワーク自動化タスクを定義するとき。

---

## 🔑 要点

データエンコーディングフォーマットの主要特徴、用途、メリット・デメリット、制限事項の比較：

| 項目 | JSON (RFC 8259) | XML (W3C Standard) | YAML (Standard) |
| :--- | :--- | :--- | :--- |
| **データ表現** | Key-Value ペア, オブジェクト `{}` , 配列 `[]` | タグ `<tag>...</tag>`, 属性 `attr=""`, ネームスペース `xmlns` | インデント（スペース）, リスト `-`, 辞書 `:` |
| **人間に対する読易性** | 中（見やすいが括弧やカンマの閉じ忘れが発生しやすい） | 低（閉じタグや属性が多く冗長） | 極めて高い（簡潔で人間に最適） |
| **マシン解析速度** | 高速（軽量、パース処理が容易） | 中〜低（タグのパース処理オーバーヘッドが大） | 中（インデント解析が必要） |
| **スキーマ検証** | JSON Schema | XSD (XML Schema Definition), DTD | YAML Schema |
| **コメント機能** | **非サポート**（仕様上コメントは不可） | サポート (`<!-- comment -->`) | サポート (`# comment`) |
| **主用途** | REST API, RESTCONF, Python辞書の直列化 | NETCONF, RESTCONF, SOAP API, 大型設定データ | Ansible Playbooks, CI/CD パイプライン, 変数ファイル |
| **YANGモデルとの親和性** | 高（RFC 7951: JSON Encoding of YANG Data） | 極めて高（RFC 6020 / 7950: XML Encoding of YANG Data） | 中（Python/Ansibleでの中間データとして利用） |
| **制限事項・落とし穴** | 末尾カンマ（Trailing Comma）禁止, シングルクォート禁止 | タグの閉じ忘れ, ネームスペース不一致によるパースエラー | **タブ文字（`\t`）の完全禁止**, スペースのインデントずれ |

---

## 🏗 動作原理

### データ構造の相互対応（JSON ↔ XML ↔ YAML）

ネットワーク自動化において、プログラミング言語内部のデータ構造（Python の `dict` / `list`）と、転送用・保存用のエンコーディングフォーマットとの間での相互変換（**Serialization / Deserialization**）が行われる。

```
[ Python データ構造 (dict / list) ]
       │
       ├── json.dumps()  ─────────►  [ JSON 文字列 ]
       ├── json.loads()  ◄─────────
       │
       ├── xml.etree.ElementTree  ─►  [ XML Document ]
       │
       ├── yaml.dump()   ─────────►  [ YAML 文字列 ]
       └── yaml.safe_load() ◄──────
```

#### 各フォーマットにおける同等データの表現例

**シナリオ:** インターフェイス `GigabitEthernet1` の IP アドレス `192.168.1.1/24` と有効化状態（`enabled: true`）を表現する。

##### 1. JSON 表現 (`application/json`)
```json
{
  "ietf-interfaces:interface": {
    "name": "GigabitEthernet1",
    "description": "Configured via RESTCONF",
    "type": "iana-if-type:ethernetCsmacd",
    "enabled": true,
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "192.168.1.1",
          "netmask": "255.255.255.0"
        }
      ]
    }
  }
}
```

##### 2. XML 表現 (`application/xml`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<interface xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"
           xmlns:ianaift="urn:ietf:params:xml:ns:yang:iana-if-type"
           xmlns:ip="urn:ietf:params:xml:ns:yang:ietf-ip">
  <name>GigabitEthernet1</name>
  <description>Configured via NETCONF</description>
  <type>ianaift:ethernetCsmacd</type>
  <enabled>true</enabled>
  <ip:ipv4>
    <ip:address>
      <ip:ip>192.168.1.1</ip:ip>
      <ip:netmask>255.255.255.0</ip:netmask>
    </ip:address>
  </ip:ipv4>
</interface>
```

##### 3. YAML 表現 (`.yml`)
```yaml
---
ietf-interfaces:interface:
  name: GigabitEthernet1
  description: Configured via Ansible
  type: iana-if-type:ethernetCsmacd
  enabled: true
  ietf-ip:ipv4:
    address:
      - ip: 192.168.1.1
        netmask: 255.255.255.0
```

---

## ⚙ 動作シーケンス

### RESTCONF / NETCONF における データエンコーディング処理シーケンス

```
[ Automation Script / Ansible / Postman ]                  [ Cisco IOS XE Device (XE 17.x) ]
                │                                                          │
                │  1. HTTP GET / RESTCONF (Accept: application/yang-data+json) │
                ├─────────────────────────────────────────────────────────►│
                │                                                          │ 2. YANG Model からデータ抽出
                │                                                          │    (Internal Native Data)
                │                                                          │
                │  3. HTTP 200 OK (Content-Type: application/yang-data+json)│
                │     [ Payload: JSON Structure ]                          │
                │◄─────────────────────────────────────────────────────────┤
                │                                                          │
                │  4. Python `json.loads()` でデシリアライズ              │
                │     (JSON 文字列 ➔ Python dict / list オブジェクト)      │
                │                                                          │
                │  5. 内部パラメータ書き換え (`enabled = false` 等)         │
                │                                                          │
                │  6. Python `json.dumps()` でシリアライズ                │
                │     (Python dict ➔ JSON ペイロード文字列)                │
                │                                                          │
                │  7. HTTP PATCH / RESTCONF (Content-Type: application/yang-data+json)
                ├─────────────────────────────────────────────────────────►│
                │                                                          │ 8. JSON 構文解読 & YANG スキーマ検証
                │                                                          │ 9. 構成変更実行 (CDB Update)
                │  10. HTTP 204 No Content                                │
                │◄─────────────────────────────────────────────────────────┤
```

#### 構文解析（Parsing）とシリアライズ（Serialization）の流れ
1. **Serialization（シリアライズ / 直列化）:**
   Python などのプログラミング言語内のメモリ上のデータオブジェクト（Dict, List）を、ネットワーク経由で送信可能なテキストストリーム（JSON 文字列, XML ドキュメント）へ変換する処理。
2. **Deserialization（デシリアライズ / 逆直列化）:**
   受信した JSON/XML/YAML テキストストリームをパースし、プログラムで扱いやすいメモリ上のデータオブジェクト（Dict, List）へ復元する処理。
3. **Validation（検証）:**
   パースされたデータ構造が、送信先（ネットワーク機器）の期待する型（Integer, Boolean, String, Array）および YANG データモデルの制約条件に合致しているかを検証する処理。構文エラー（Syntax Error）や型不一致がある場合、400 Bad Request (RESTCONF) や `rpc-error` (NETCONF) が返却される。

---


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験（Practical Exam）における Module 1 (Design) および Module 2 (Deploy, Operate and Optimize) で出題されやすいポイントと、トラブルシュートの重要ポイント。

### Blueprintで重要なポイント
* **データ構造の理解と相互変換（Python Scripting）:**
  試験環境の Python スクリプトで、REST API から受け取った JSON データをパースし、特定キー（例: 状態が `UP` のインターフェイス一覧、特定の IP アドレス）を抽出・集計する。
* **RESTCONF Headers (`Content-Type` と `Accept`):**
  * `application/yang-data+json`
  * `application/yang-data+xml`
  * `application/json` / `application/xml`
  ヘッダーの指定ミスによって 415 Unsupported Media Type や 406 Not Acceptable が発生するトラブルの特定。
* **NETCONF XML フィルタリング (Subtree Filtering):**
  `ncclient` を用いて特定のインターフェイスや BGP 設定のみを XML サブツリーフィルタ (`<filter>`) でピンポイント取得する構文。
* **Ansible YAML 構文エラーの修正:**
  インデント（スペース）のずれ、タブ文字の混入、コロン（`:`) 後のスペース欠落による Ansible 実行エラーの発見と修正。
* **Jinja2 テンプレートでの JSON/YAML 変数バインディング:**
  YAML 変数ファイル (`group_vars` / `host_vars`) のデータを Jinja2 テンプレートへ流し込み、Cisco IOS XE / SD-WAN CLI コンフィグを生成する問題。

### ラボ試験で狙われやすい制限事項 ＆ よくある設定・記述ミス

1. **JSON における文字列 vs 数値・真偽値の型区別:**
   * ❌ 不完全: `"enabled": "true"` （文字列として渡すと RESTCONF/YANG スキーマ型チェックでエラーになる場合がある）
   * ✅ 正確: `"enabled": true` （Boolean 値）
   * ❌ 不完全: `"vlan-id": "100"`
   * ✅ 正確: `"vlan-id": 100` （Integer 数値）
2. **JSON の末尾カンマ (Trailing Comma):**
   * 配列やオブジェクトの要素の最後に無駄なカンマを残すと `json.loads()` で `json.decoder.JSONDecodeError` が発生する。
3. **YAML のインデントにタブ（Tab）文字を使用するミス:**
   * YAML ではインデントに **スペース（半角空白）のみ** が許可される。Tab キーを入力してしまった場合、Ansible や Python `yaml.safe_load()` が `yaml.scanner.ScannerError` を吐いて即座に停止する。
4. **XML ネームスペース（`xmlns`）の指定漏れ:**
   * NETCONF や RESTCONF XML ペイロードで `xmlns` を正しく指定しないと、機器側の YANG データモデルエンジンが要素を特定できず `rpc-error` (Invalid element) を返す。

---

## 🛠 設定方法

### 1. Python による JSON / XML / YAML データ処理とパース手法

CCIE EI ラボ環境の Python 3 において標準/定番ライブラリを用いてデータエンコーディングを相互変換・処理する標準コード例。

#### (1) JSON データの読み込み・書き出し・パース (Python `json` モジュール)
```python
import json

json_data_str = """
{
  "ietf-interfaces:interfaces": {
    "interface": [
      {
        "name": "GigabitEthernet1",
        "description": "MANAGEMENT_IF",
        "enabled": true,
        "ietf-ip:ipv4": {
          "address": [{"ip": "10.1.1.1", "netmask": "255.255.255.0"}]
        }
      },
      {
        "name": "GigabitEthernet2",
        "description": "WAN_LINK",
        "enabled": false,
        "ietf-ip:ipv4": {
          "address": [{"ip": "192.168.12.1", "netmask": "255.255.255.252"}]
        }
      }
    ]
  }
}
"""

# 1. デシリアライズ (JSON Str -> Python Dict)
data_dict = json.loads(json_data_str)

# 2. データの抽出
interfaces = data_dict["ietf-interfaces:interfaces"]["interface"]
for iface in interfaces:
    if iface.get("enabled"):
        iface_name = iface["name"]
        ip_addr = iface["ietf-ip:ipv4"]["address"][0]["ip"]
        print(f"Active Interface: {iface_name} -> IP: {ip_addr}")

# 3. データの変更
interfaces[0]["description"] = "UPDATED_BY_PYTHON"

# 4. シリアライズ
pretty_json = json.dumps(data_dict, indent=2)
print(pretty_json)
```

#### (2) XML データのパースと生成 (Python `xml.etree.ElementTree`)
```python
import xml.etree.ElementTree as ET

xml_data_str = """<?xml version="1.0" encoding="UTF-8"?>
<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="101">
  <data>
    <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
      <interface>
        <name>GigabitEthernet1</name>
        <type xmlns:ianaift="urn:ietf:params:xml:ns:yang:iana-if-type">ianaift:ethernetCsmacd</type>
        <enabled>true</enabled>
      </interface>
    </interfaces>
  </data>
</rpc-reply>
"""

# 1. XML 文字列のパース
root = ET.fromstring(xml_data_str)

# XML ネームスペースの定義
ns = {
    'nc': 'urn:ietf:params:xml:ns:netconf:base:1.0',
    'if': 'urn:ietf:params:xml:ns:yang:ietf-interfaces'
}

# 2. XPath 検索で特定のタグ要素を取得
interface_name = root.find('.//if:name', ns).text
enabled_status = root.find('.//if:enabled', ns).text

print(f"Interface Name: {interface_name}, Enabled: {enabled_status}")
```

#### (3) YAML データのパースと変換 (Python `pyyaml` ライブラリ)
```python
import yaml
import json

yaml_data_str = """
---
bgp_config:
  asn: 65001
  router_id: 1.1.1.1
  neighbors:
    - ip: 10.1.1.2
      remote_as: 65002
      description: "eBGP to ISP-A"
    - ip: 10.2.2.2
      remote_as: 65001
      description: "iBGP Core"
"""

# 1. 安全な YAML デシリアライズ
config_dict = yaml.safe_load(yaml_data_str)

print(f"Router BGP ASN: {config_dict['bgp_config']['asn']}")

# 2. YAML データから JSON 文字列への相互変換
converted_json = json.dumps(config_dict, indent=2)
print("--- Converted JSON ---")
print(converted_json)
```

---


## 🔍 検証コマンド

Cisco IOS XE 機器での RESTCONF / NETCONF データエンコーディング動作確認および Linux/Python 環境での検証コマンド：

| 目的 | コマンド / 手法 | 備考 |
| :--- | :--- | :--- |
| **IOS XE NETCONF 有効化** | `netconf-yang` | ポート 830 (SSH) で NETCONF XML エンコーディングを処理 |
| **IOS XE RESTCONF 有効化** | `restconf` | ポート 443 (HTTPS) で JSON/XML ペロードを処理 |
| **NETCONF セッション確認** | `show netconf-yang sessions` | アクティブな XML NETCONF セッションの表示 |
| **RESTCONF プロセス確認** | `show platform software mda switch 1 R0 restconf` | RESTCONF エンジンの稼働確認 |
| **RESTCONF JSON 取得確認** | `curl -k -H "Accept: application/yang-data+json" https://<DEVICE_IP>/restconf/data/ietf-interfaces:interfaces` | JSON エンコーディングでのデータレスポンス確認 |
| **RESTCONF XML 取得確認** | `curl -k -H "Accept: application/yang-data+xml" https://<DEVICE_IP>/restconf/data/ietf-interfaces:interfaces` | XML エンコーディングでのデータレスポンス確認 |
| **Python JSON 構文チェック** | `python3 -m json.tool input.json` | JSON ファイルの構文検証とインデント整形表示 |
| **Python YAML 構文チェック** | `python3 -c "import yaml; yaml.safe_load(open('file.yml'))"` | YAML ファイルのインデント・構文チェック |

---

## 🚨 トラブルシュート

データエンコーディング処理で遭遇する代表的な症状、原因、確認方法、および対処方法：

| 症状 | 原因 | 確認コマンド / 手法 | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`json.decoder.JSONDecodeError`** | JSON 構文内にダブルクォートの閉じ忘れ、末尾の無駄なカンマ（Trailing Comma）、シングルクォートの使用 | `python3 -m json.tool <file.json>` | 末尾のカンマを削除。文字列をダブルクォート (`"`) で統一。 |
| **`yaml.scanner.ScannerError`** | YAML ファイル内でインデントにタブ文字（Tab）を使用している | `cat -A <file.yml>` | タブ文字をすべて半角スペース2個または4個に全置換。 |
| **RESTCONF `415 Unsupported Media Type`** | リクエストヘッダー `Content-Type` に誤った MIME タイプ（例: `text/plain`）を指定している | cURL レスポンスヘッダー確認 | `Content-Type: application/yang-data+json` または `application/yang-data+xml` を指定。 |
| **RESTCONF `406 Not Acceptable`** | リクエストヘッダー `Accept` で指定したエンコーディング形式を機器が返せない | cURL レスポンスヘッダー確認 | `Accept: application/yang-data+json` または `application/yang-data+xml` を指定。 |
| **NETCONF `rpc-error` (Bad Element / Unknown Element)** | XML タグ名・階層の誤り、または `xmlns` ネームスペースの不一致・未定義 | NETCONF `ncclient` の `reply.xml` を出力 | 機器の YANG モデル（`ietf-interfaces` や `Cisco-IOS-XE-native`）の正確なネームスペースとタグ階層を確認・修正。 |
| **RESTCONF `400 Bad Request` (Invalid Value Type)** | JSON ペイロード内のデータ型不一致（Integer 項目に String を渡している、Boolean 項目に `"true"` 文字列を渡している） | 機器側 Syslog / RESTCONF Trace | JSON の値を `"100"` ➔ `100`、`"true"` ➔ `true` に型修正。 |

---


## ⚠ 制限事項

* **JSON におけるコメント記述不可:**
  JSON 仕様 (RFC 8259) ではコメント (`//` や `/* */`) が一切許可されない。設定ファイルの注釈を入れたい場合は YAML や XML を選択する必要がある。
* **YAML のタブ文字禁止:**
  YAML 仕様においてインデントにタブ文字（Tab: `\t`）を使用することは禁止されている。必ずスペース（Space）を使用する。
* **XML ネームスペース不一致によるサイレントドロップ / エラー:**
  NETCONF / RESTCONF において XML タグ名が正しくても、`xmlns` で指定する URI が機器側の YANG モデルと完全に一致しない場合、要求が無視されるか `rpc-error` となる。

---

## 🔄 他技術との関連

* **RESTCONF (RFC 8040):**
  HTTP 経由で YANG モデル化されたデータを操作するプロトコル。データエンコーディングとして `application/yang-data+json` および `application/yang-data+xml` をネイティブサポート。
* **NETCONF (RFC 6241):**
  SSH (Port 830) 上で XML メッセージをやり取りするトランザクション型ネットワーク管理プロトコル。データエンコーディングは **XML に限定** される。
* **YANG Data Modeling (RFC 6020/7950):**
  データエンコーディング（JSON/XML）の「スキーマ（データ構造・型定義・制約）」を定義するデータモデリング言語。
* **Ansible & Jinja2:**
  Ansible Playbook および変数ファイルは **YAML** 形式で記述され、Jinja2 テンプレートエンジンと組み合わせることで各種ネットワークコンフィグ（CLI, JSON, XML）を動的生成する。
* **Python (`requests`, `ncclient`, `pyyaml`, `json`):**
  自動化スクリプト内でネットワーク機器や API コントローラと通信し、受信した JSON/XML/YAML データを相互変換・パースするための標準言語環境。

---

## 🧩 比較表

### JSON vs XML vs YAML 総合比較表

| 比較項目 | JSON | XML | YAML |
| :--- | :--- | :--- | :--- |
| **フル名称** | JavaScript Object Notation | eXtensible Markup Language | YAML Ain't Markup Language |
| **標準規格** | RFC 8259 | W3C Standard | yaml.org Specification |
| **基本データ型** | String, Number, Boolean, Array `[]`, Object `{}` | Text (Tag Value), Element, Attribute | Scalar (String/Number/Bool), List `-`, Map `:` |
| **可読性 (Readability)** | ★★★☆☆ (適度) | ★★☆☆☆ (冗長) | ★★★★★ (極めて高い) |
| **コメント** | 不可 ❌ | 可 (`<!-- -->`) ⭕ | 可 (`#`) ⭕ |
| **インデント強制** | なし (任意) | なし (任意) | **あり (必須・スペースのみ)** ⚠️ |
| **主な利用技術** | RESTCONF, Cisco DNA Center / SD-WAN API | NETCONF, RESTCONF, SOAP API | Ansible, Docker, Kubernetes, CI/CD |
| **主プロトコル** | HTTP/HTTPS (REST API) | SSH (830/NETCONF), HTTPS | SSH (Ansible runner), CLI |

---

## 💡 ベストプラクティス

1. **RESTCONF / API 開発では JSON を第一選択とする:**
   人間とマシンの双方にとってパースが容易であり、Python の `json` モジュールや JavaScript でネイティブ処理が最速であるため、RESTCONF や REST API では JSON エンコーディングを優先採用する。
2. **NETCONF / トランザクション処理では XML を徹底活用する:**
   完全な型検証や XSD スキーマチェック、NETCONF サブツリーフィルタリングを行う場合は、標準規格に従い XML エンコーディングを使用する。
3. **Ansible Playbook / 変数定義は YAML のインデント基準（スペース2個）を統一する:**
   チーム開発および CI/CD での構文エラーを防ぐため、エディタ（VS Code や Vim）で Tab キーを自動的に「スペース2個」に変換する設定（`expandtab tabstop=2 shiftwidth=2`）を適用する。
4. **Python スクリプト内でのデシリアライズは安全な関数を使用する:**
   YAML パース時は任意コード実行脆弱性を防ぐため、`yaml.load()` ではなく必ず **`yaml.safe_load()`** を使用する。

---


## 📝 ラボ学習・設定サンプル例

### サンプル 1: Python による RESTCONF JSON 配列からの UP 状態インターフェイス抽出

* **問題:**
  RESTCONF API から取得した JSON 形式のインターフェイスステータスデータから、`oper-status` が `"up"` になっているインターフェイス名と IP アドレスを抽出し表示する Python スクリプトを作成せよ。
* **要件:**
  1. Python 標準の `json` ライブラリを使用すること。
  2. ネストされた JSON 構造から安全に `ietf-interfaces:interfaces-state` を走査すること。
* **コード例:**
```python
import json

restconf_json_response = """
{
  "ietf-interfaces:interfaces-state": {
    "interface": [
      {
        "name": "GigabitEthernet1",
        "type": "iana-if-type:ethernetCsmacd",
        "admin-status": "up",
        "oper-status": "up",
        "phys-address": "00:50:56:bb:11:22"
      },
      {
        "name": "GigabitEthernet2",
        "type": "iana-if-type:ethernetCsmacd",
        "admin-status": "up",
        "oper-status": "down",
        "phys-address": "00:50:56:bb:33:44"
      },
      {
        "name": "Loopback0",
        "type": "iana-if-type:softwareLoopback",
        "admin-status": "up",
        "oper-status": "up"
      }
    ]
  }
}
"""

data = json.loads(restconf_json_response)
interfaces = data.get("ietf-interfaces:interfaces-state", {}).get("interface", [])

print("=== OPERATIONAL UP INTERFACES ===")
for iface in interfaces:
    if iface.get("oper-status") == "up":
        print(f"Interface: {iface.get('name')} [Type: {iface.get('type')}]")
```
* **検証方法:**
  Python スクリプトを実行し、`GigabitEthernet1` と `Loopback0` のみが正しく抽出出力されることを確認。

---

### サンプル 2: Python `xml.etree.ElementTree` を用いた NETCONF XML 応答からの BGP ネイバー状態パース

* **問題:**
  NETCONF `<get>` リクエストの応答として得られた XML データから、BGP ネイバー IP、Remote AS、および BGP セッション状態 (`state`) をパースする Python スクリプトを作成せよ。
* **要件:**
  1. `xml.etree.ElementTree` を使用すること。
  2. XML ネームスペース辞書を正確に定義し XPath で要素を抽出すること。
* **コード例:**
```python
import xml.etree.ElementTree as ET

netconf_xml_reply = """<?xml version="1.0" encoding="UTF-8"?>
<rpc-reply xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" message-id="102">
  <data>
    <bgp-state xmlns="http://example.com/ns/yang/Cisco-IOS-XE-bgp-oper">
      <neighbors>
        <neighbor>
          <ip>10.1.1.2</ip>
          <remote-as>65002</remote-as>
          <session-state>Established</session-state>
        </neighbor>
        <neighbor>
          <ip>10.2.2.2</ip>
          <remote-as>65003</remote-as>
          <session-state>Active</session-state>
        </neighbor>
      </neighbors>
    </bgp-state>
  </data>
</rpc-reply>
"""

root = ET.fromstring(netconf_xml_reply)
ns = {'bgp': 'http://example.com/ns/yang/Cisco-IOS-XE-bgp-oper'}

neighbors = root.findall('.//bgp:neighbor', ns)
for n in neighbors:
    ip = n.find('bgp:ip', ns).text
    asn = n.find('bgp:remote-as', ns).text
    state = n.find('bgp:session-state', ns).text
    print(f"BGP Neighbor: {ip} | Remote AS: {asn} | State: {state}")
```
* **検証方法:**
  スクリプトを実行し、`10.1.1.2 (65002) - Established` および `10.2.2.2 (65003) - Active` が正しく表示されることを確認。

---

### サンプル 3: YAML 変数ファイルの読み込みと Python Jinja2 テンプレートによる Cisco CLI 構成生成

* **問題:**
  YAML 形式の変数データから OSPF 構成データを読み込み、Jinja2 テンプレートを使用して Cisco IOS XE CLI コマンド（`router ospf`）を生成する Python スクリプトを作成せよ。
* **要件:**
  1. `pyyaml` (PyYAML) と `jinja2` ライブラリを使用すること。
  2. YAML 内のリレーション構造を Jinja2 の `for` ループで処理すること。
* **コード例:**
```python
import yaml
from jinja2 import Template

yaml_vars = """
ospf_config:
  process_id: 10
  router_id: "1.1.1.1"
  areas:
    - area_id: 0
      networks:
        - "10.1.1.0 0.0.0.255"
        - "10.1.2.0 0.0.0.255"
    - area_id: 1
      networks:
        - "172.16.1.0 0.0.0.255"
"""

jinja_template_str = """
router ospf {{ ospf_config.process_id }}
 router-id {{ ospf_config.router_id }}
{% for area in ospf_config.areas %}
 {% for net in area.networks %}
 network {{ net }} area {{ area.area_id }}
 {% endfor %}
{% endfor %}
"""

# YAML 読み込み
vars_dict = yaml.safe_load(yaml_vars)

# Jinja2 テンプレートレンダリング
template = Template(jinja_template_str)
rendered_cli = template.render(vars_dict)

print("=== GENERATED CISCO IOS XE OSPF CONFIG ===")
print(rendered_cli)
```
* **検証方法:**
  スクリプトを実行し、正しくフォーマットされた `router ospf 10` の CLI 設定文が生成されることを確認。

---

### サンプル 4: RESTCONF 用 JSON ペイロードの作成 (IPv4 アドレス付き Loopback インターフェイス追加)

* **問題:**
  Cisco IOS XE に対し、RESTCONF リクエストを用いて `Loopback100` （IP アドレス: `10.100.100.1/32`）を追加するための JSON ペイロードを作成せよ。
* **要件:**
  1. `ietf-interfaces` YANG データモデル仕様に準拠すること。
  2. `ietf-ip:ipv4` オブジェクト内に正しい型（IP 文字列とネットマスク文字列）で構築すること。
* **設定・ペイロード例:**
```json
{
  "ietf-interfaces:interface": {
    "name": "Loopback100",
    "description": "Configured via RESTCONF JSON",
    "type": "iana-if-type:softwareLoopback",
    "enabled": true,
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "10.100.100.1",
          "netmask": "255.255.255.255"
        }
      ]
    }
  }
}
```
* **検証方法:**
  HTTP POST リクエストを `Content-Type: application/yang-data+json` ヘッダー付きで送信し、`201 Created` が返ることを確認。

---

### サンプル 5: NETCONF 用 XML エディット構成 (BGP Neighbor 変更 RPC ペイロード)

* **問題:**
  NETCONF リクエスト用として、BGP AS 65001 内に BGP ネイバー `192.168.1.2` (Remote AS 65002) を追加するための XML RPC ペイロードを作成せよ。
* **要件:**
  1. `urn:ietf:params:xml:ns:netconf:base:1.0` および Cisco Native YANG ネームスペースを使用すること。
* **設定・ペイロード例:**
```xml
<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <edit-config>
    <target>
      <running/>
    </target>
    <config>
      <native xmlns="http://example.com/ns/yang/Cisco-IOS-XE-native">
        <router>
          <bgp xmlns="http://example.com/ns/yang/Cisco-IOS-XE-bgp">
            <id>65001</id>
            <neighbor>
              <id>192.168.1.2</id>
              <remote-as>65002</remote-as>
              <description>eBGP-PEER</description>
            </neighbor>
          </bgp>
        </router>
      </native>
    </config>
  </edit-config>
</rpc>
```
* **検証方法:**
  NETCONF クライアントで送信し、`<ok/>` のレスポンスが得られることを確認。

---


### サンプル 6: NETCONF Subtree XML フィルタを用いた特定 OSPF 設定のピンポイント抽出

* **問題:**
  ルータ上の全コンフィグから OSPF プロセス設定のみを抽出するための NETCONF サブツリー XML フィルタを作成せよ。
* **要件:**
  1. XML タグのネスト構造を用いて `native/router/ospf` を指定すること。
* **設定・フィルタ例:**
```xml
<filter xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="http://example.com/ns/yang/Cisco-IOS-XE-native">
    <router>
      <ospf/>
    </router>
  </native>
</filter>
```
* **検証方法:**
  `m.get_config(source='running', filter=xml_filter)` で呼び出し、OSPF 設定タグブロックのみが含まれる XML レスポンスが返却されることを確認。

---

### サンプル 7: Ansible Playbook (YAML) による Catalyst スイッチ群への VLAN 一括作成タスク定義

* **問題:**
  VLAN 10 (GUEST), VLAN 20 (CORP), VLAN 30 (VOICE) を Cisco Catalyst スイッチ群へ一括適用するための Ansible Playbook (`vlan_deploy.yml`) を作成せよ。
* **要件:**
  1. 正しい YAML 構文（インデントはスペース2個、リスト記号 `-`）で記述すること。
  2. `cisco.ios.ios_vlans` モジュールを使用すること。
* **設定・Playbook 例:**
```yaml
---
- name: Deploy Standard VLANs on Catalyst Switches
  hosts: switches
  gather_facts: false
  connection: network_cli

  tasks:
    - name: Configure VLANs
      cisco.ios.ios_vlans:
        config:
          - vlan_id: 10
            name: GUEST
          - vlan_id: 20
            name: CORP
          - vlan_id: 30
            name: VOICE
        state: merged
```
* **検証方法:**
  `ansible-playbook -i hosts vlan_deploy.yml --syntax-check` を実行し、YAML 構文エラーがないことを確認後適用。

---

### サンプル 8: Python による JSON ↔ YAML 相互データフォーマット変換スクリプト

* **問題:**
  JSON データ (`input.json`) を読み込み、構造を保ったまま同等の YAML データ (`output.yml`) へ自動変換して保存する Python スクリプトを作成せよ。
* **要件:**
  1. `json` および `pyyaml` モジュールを使用すること。
  2. 例外処理を含めて安全に処理すること。
* **コード例:**
```python
import json
import yaml

def convert_json_to_yaml(json_data_str):
    try:
        data = json.loads(json_data_str)
        yaml_output = yaml.safe_dump(data, default_flow_style=False, sort_keys=False)
        return yaml_output
    except Exception as e:
        return f"Conversion error: {e}"

# テスト実行例
sample_json = '{"device": "Router1", "interfaces": ["Gi1", "Gi2"]}'
print(convert_json_to_yaml(sample_json))
```
* **検証方法:**
  スクリプトを実行し、正常に YAML フォーマットテキストが出力されることを確認。

---

### サンプル 9: Cisco DNA Center (Catalyst Center) REST API 向け Device Intent JSON ペイロード定義

* **問題:**
  Cisco DNA Center Intent API でアクセスリングを適用する際のネットワークデバイスパラメータを定義する JSON ペイロードを作成せよ。
* **要件:**
  1. DNA Center リクエスト仕様に基づくキー構造（`ipAddress`, `cliTransport`, `type`）を持つこと。
* **設定・ペイロード例:**
```json
{
  "deviceInfo": {
    "ipAddress": "10.10.10.1",
    "cliTransport": "SSH",
    "computeDevice": false,
    "type": "Cisco Catalyst 9300 Switch"
  }
}
```
* **検証方法:**
  `json.dumps()` で整形し、API 呼び出し用要求ボディとして正常にパースされることを確認。

---

### サンプル 10: Cisco SD-WAN vManage REST API 向け Feature Template パラメータ JSON 構造

* **問題:**
  Cisco SD-WAN vManage API で cEdge ルータの BGP 設定テンプレートを更新するための JSON パラメータ構造を記述せよ。
* **要件:**
  1. vManage 特有の `vipType`, `vipValue` ネスト構造を正しく表現すること。
* **設定・ペイロード例:**
```json
{
  "templateName": "cEdge_BGP_Template",
  "templateType": "cisco_bgp",
  "templateMinVersion": "15.0.0",
  "templateDefinition": {
    "as-num": {
      "vipType": "ignore",
      "vipValue": 65001
    },
    "router-id": {
      "vipType": "ignore",
      "vipValue": "10.255.255.1"
    }
  }
}
```
* **検証方法:**
  Python で読み込み、`vipValue` 階層から正しい AS 番号（`65001`）が抽出できることを確認。

---


## ❓ 想定試験問題

### 問 1 (コンフィグ/コード読解)
以下の Python スクリプトを実行した際、出力される値として正しいものを選択せよ。

```python
import json

data_str = """
{
  "response": [
    {"hostname": "R1", "status": "REACHABLE", "tags": ["core", "border"]},
    {"hostname": "R2", "status": "UNREACHABLE", "tags": ["access"]},
    {"hostname": "SW1", "status": "REACHABLE", "tags": ["access", "poe"]}
  ]
}
"""

data = json.loads(data_str)
result = [device["hostname"] for device in data["response"] if "access" in device["tags"] and device["status"] == "REACHABLE"]
print(result)
```

* A. `['R1', 'SW1']`
* B. `['SW1']`
* C. `['R2', 'SW1']`
* D. `[]`

**正解:** **B**
**解説:**
`device["tags"]` 配列に `"access"` が含まれ、かつ `status` が `"REACHABLE"` である要素は `SW1` のみである (`R2` は `UNREACHABLE` のため除外される)。

---

### 問 2 (トラブルシューティング)
Ansible Playbook 実行時に以下のエラーが発生した。最も可能性の高い原因はどれか。

```text
ERROR! Syntax error while loading YAML.
  The error appears to have been in '/ansible/deploy.yml': line 8, column 5
  yaml.scanner.ScannerError: mapping values are not allowed here
```

* A. YAML ファイルの 1 行目に `---` が記述されていない。
* B. キーと値の区切り記号であるコロン（`:`）の直後に半角スペースが存在しない。
* C. シングルクォートの閉じ忘れがある。
* D. ファイルエンコーディングが UTF-8 ではなく ASCII になっている。

**正解:** **B**
**解説:**
YAML 仕様において、Map 構造のキーと値の区切り `key: value` では、コロンの直後に必ず半角スペース（または改行）が必要である。スペースを忘れて `key:value` と書くと `ScannerError: mapping values are not allowed here` が発生する。

---

### 問 3 (Design)
NETCONF と RESTCONF のデータエンコーディングに関する設計方針として**不適切なもの**はどれか。

* A. NETCONF では標準仕様としてデータエンコーディングに XML のみがサポートされる。
* B. RESTCONF では HTTP ヘッダー `Accept: application/yang-data+json` を指定することで JSON 形式でのデータ取得が可能である。
* C. 人間の可読性を最優先とし、NETCONF の転送データとして YAML エンコーディングを採用する。
* D. YANG データモデルは JSON (RFC 7951) および XML (RFC 7950) の双方向エンコーディングルールを定義している。

**正解:** **C**
**解説:**
NETCONF プロトコル (RFC 6241) はデータエンコーディングとして XML のみをサポートしており、YAML や JSON を直接 NETCONF トランスポート上で送信することは標準規格上不可能である。

---

### 問 4 (実装)
Python の `xml.etree.ElementTree` モジュールで、XML ネームスペース付きのタグ（例: `<ns:name>Gi1</ns:name>`）を特定してパースする際の正しい実装手法はどれか。

* A. ネームスペースは自動的に無視されるため、`root.find('name')` で検索する。
* B. `ns = {'ns': 'http://example.com/ns'}` のように辞書でURIを定義し、`root.find('ns:name', ns)` または 完全修飾名 `root.find('{http://example.com/ns}name')` を使用する。
* C. XML のパース前にすべてのネームスペース属性（`xmlns`）を正規表現で削除しなければパースできない。
* D. `ElementTree` はネームスペースをサポートしていないため `json` モジュールに変換してから処理する。

**正解:** **B**
**解説:**
Python `ElementTree` でネームスペース付き XML をパースする場合は、ネームスペース URI とプレフィックスの辞書を検索引数に渡すか、`{URI}tag` というクラーク表記（Clark Notation）の完全修飾名を使用する。

---

### 問 5 (トラブルシューティング)
RESTCONF で HTTP `PATCH` リクエストを用いてインターフェイスの説明文を変更しようとしたところ、ステータスコード `415 Unsupported Media Type` が返された。修復策として正しいものはどれか。

* A. HTTP リクエストヘッダーに `Content-Type: application/yang-data+json` を正しく設定する。
* B. HTTP リクエストメソッドを `GET` に変更する。
* C. URI の末尾に `?content=config` パラメータを追加する。
* D. HTTP リクエストヘッダーに `Authorization: Bearer Token` を追加する。

**正解:** **A**
**解説:**
`415 Unsupported Media Type` は、クライアントが送信したペイロードの MIME タイプ（`Content-Type` ヘッダー）をサーバーが理解・サポートしていない場合に発生する。RESTCONF で JSON を送る場合は `Content-Type: application/yang-data+json` を指定する。

---

### 問 6 (コンフィグ読解)
以下の JSON ペイロードを RESTCONF で送信した際、機器側の YANG スキーマ検証でエラーが発生した。理由として最も適切なものはどれか。

```json
{
  "ietf-interfaces:interface": {
    "name": "GigabitEthernet1",
    "enabled": "true",
    "vlan-id": "10"
  }
}
```

* A. オブジェクトキーにダブルクォートが使用されているため。
* B. `enabled` に Boolean 型の `true` ではなく文字列 `"true"` が設定され、`vlan-id` に Integer 型の `10` ではなく文字列 `"10"` が設定されているため。
* C. インデントがスペース 2 個で統一されていないため。
* D. JSON 仕様で禁止されているハイフン（`-`）がキー名に含まれているため。

**正解:** **B**
**解説:**
YANG データモデルで `type boolean` や `type uint16` と定義されているフィールドに対し、JSON で引用符を付けた文字列型（`"true"`, `"10"`）を渡すと型不一致エラー（`400 Bad Request`）となる。正しくは `true` および `10` と記述する。

---

### 問 7 (Design)
Ansible を用いたネットワーク自動化において、変数ファイル (YAML) のセキュリティと可読性を向上させるベストプラクティスとして最も適切なものはどれか。

* A. 変数ファイル内のインデントには Tab 文字を使用してファイルサイズを削減する。
* B. パスワードなどの機密データは Ansible Vault で暗号化し、インデントには一貫してスペース 2 個を使用する。
* C. Ansible の YAML ファイル内では記述簡略化のためコロン（`:`）の後のスペースを省略する。
* D. Playbook 内のすべての設定変数を JSON 形式に変換してから `.yml` ファイルに直接埋め込む。

**正解:** **B**
**解説:**
YAML 形式の定義ファイルでは標準インデントルール（スペース2個）を守りつつ、認証情報などのセンシティブデータを Ansible Vault で暗号化管理するのがベストプラクティスである。

---

### 問 8 (実装)
Python ライブラリ `pyyaml` を使用して YAML テキストを安全に辞書オブジェクトへ読み込む推奨コマンドはどれか。

* A. `yaml.load(text)`
* B. `yaml.unsafe_load(text)`
* C. `yaml.safe_load(text)`
* D. `yaml.parse_json(text)`

**正解:** **C**
**解説:**
`yaml.load()` は任意コード実行のセキュリティリスクがあるため非推奨（または最新バージョンでエラー）となっている。安全に YAML データをロードするには **`yaml.safe_load()`** を使用する。

---

## 🔗 参考リソース

* **RFC 8259 - The JavaScript Object Notation (JSON) Data Interchange Format**
* **RFC 7951 - JSON Encoding of Data Modeled with YANG**
* **W3C XML Schema Definition Language (XSD)**
* **YAML Specification Index**
* **Cisco DevNet - Network Programmability Basics**
* **Cisco Live Presentation - Programmability for Network Engineers (BRKPRG-1002)**

---

## 📝 **補足（Notes）**

### データエンコーディングクイックチェックスシート
* **JSON:**
  * `{}` = オブジェクト (Python `dict`)
  * `[]` = 配列 (Python `list`)
  * コメント不可、末尾カンマ不可、文字列はダブルクォート必須
* **XML:**
  * `<tag>val</tag>` = エレメント
  * `attr="val"` = 属性
  * `xmlns="..."` = ネームスペース（NETCONF/RESTCONF の照合キー）
* **YAML:**
  * `-` = リスト要素
  * `key: value` = マップ（コロンの後に **半角スペース必須**）
  * **Tab 文字（`\t`）は使用禁止（スペース 2 個推奨）**


