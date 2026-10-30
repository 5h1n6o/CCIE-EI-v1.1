---
layout: default
title: 5.1.b-XML
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.1.b XML
## 📘 概要
Extensible Markup Language (XML) は、W3C によって定義された構造化データをテキスト形式で表現するためのオープン規格です。


## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **標準規格** | W3C XML 1.0 / 1.1 規格、RFC 6241 (NETCONF)、RFC 8040 (RESTCONF XML) |
| **データ構造** | 開始タグ `<tag>` と終了タグ `</tag>` による木構造（Tree / DOM）、属性（Attributes）、ネームスペース（Namespaces） |
| **データ型** | テキストデータ中心。YANG スキーマ (XSD) とのバインドにより Integer, Boolean, Enum 等の厳密な型検証を達成 |
| **エスケープ処理** | 予約文字（`<`, `>`, `&`, `'`, `"`）は定義済み実体参照（`&lt;`, `&gt;`, `&amp;`, `&apos;`, `&quot;`）または `<![CDATA[ ... ]]>` で保護 |
| **メリット** | ・型情報・スキーマ（XSD / YANG）による完全な構造検証が可能<br>・階層構造とネームスペースにより異なるベンダー/モデルの拡張性が極めて高い<br>・NETCONF 標準形式として全 Cisco IOS XE 機器で完全対応 |
| **制限事項** | ・大文字と小文字を厳密に区別（`<Interface>` と `<interface>` は別タグ扱い）<br>・タグの閉じ忘れや不完全なネストは即座に Syntax Error (XML Syntax Fault) を発生させる |
| **設計上の注意点** | NETCONF/RESTCONF 連携時は XML ネームスペース (`xmlns="..."`) の記述ミスマッチに注意。ネームスペース不一致は機器側で `rpc-error` (Unknown element) を引き起こす |


## 🏗 動作原理

XML はルート要素（Root Element）を頂点とする単一の階層ツリー構造を形成します。各データ要素（Element）は「開始タグ」「コンテンツ（テキストまたは子要素）」「終了タグ」で構成され、必要に応じて属性（Attribute）やネームスペース（Namespace）が付与されます。

### 1. XML 構文の主要構成要素

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!-- ネットワークインターフェイス設定例 -->
<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <data>
    <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
      <interface>
        <name>GigabitEthernet1</name>
        <description>Configured via NETCONF XML</description>
        <type xmlns:ianaift="urn:ietf:params:xml:ns:yang:iana-if-type">ianaift:ethernetCsmacd</type>
        <enabled>true</enabled>
        <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ip">
          <address>
            <ip>192.168.1.1</ip>
            <netmask>255.255.255.0</netmask>
          </address>
        </ipv4>
      </interface>
    </interfaces>
  </data>
</rpc-reply>
```

#### ① プロログ (XML Prolog)
* `<?xml version="1.0" encoding="UTF-8"?>`
* XML 文書の先頭に位置し、利用している XML バージョンおよび文字エンコーディングを宣言します。

#### ② 要素 (Elements) とネスト構造
* `<interface> ... </interface>`
* タグは必ず組みで定義され、正しくネスト（入れ子）されている必要があります。

#### ③ 属性 (Attributes)
* `message-id="101"`
* 開始タグ内に `name="value"` の形式で定義される付加情報です。値は必ずシングルクォートまたはダブルクォートで囲みます。

#### ④ ネームスペース (XML Namespaces - `xmlns`)
* `xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"`
* 異なる標準団体やベンダーが定義した要素名の重複・衝突を防ぐため、一意のコンテキスト（名前空間）を指定します。

#### ⑤ 整合性検証 (Well-Formed XML vs Valid XML)
* **Well-Formed (形式的正当性):** XML 構文規則（タグの対応、ルート要素の単一性、適切なエスケープ等）を完全に満たしている状態。
* **Valid (妥当性):** Well-Formed であり、かつ指定された YANG データモデルや XSD (XML Schema Definition) の定義に完全に適合している状態。


## ⚙ 動作シーケンス

ネットワーク機器とプログラマビリティクライアント（Python スクリプト等）の間で、XML データが処理・検証されるシーケンスは以下の通りです。

```
[ Python Client / NMS ]                         [ Cisco IOS XE Device ]
           |                                               |
           | ----- (1) NETCONF SSH Connection (TCP 830) -> |
           | <---- (2) Hello Capability Exchange --------> |
           |                                               |
           | ----- (3) XML RPC Request (<rpc>) ----------> |
           |     (ietf-interfaces XML Payload)             |
           |                                               | [ 機器内部処理 ]
           |                                               |  a. XML Syntax Check (Well-Formed)
           |                                               |  b. XML Namespace Verification
           |                                               |  c. YANG Schema Validation
           |                                               |  d. Apply Config to Running-Config
           |                                               |
           | <---- (4) XML RPC Reply (<rpc-reply>) ------- |
           |     (<ok/> or <rpc-error>)                    |
           |                                               |
```

1. **トランスポート確立:** SSH セッション上で NETCONF サブシステムが起動され、クライアントとルータ間で互いの機能（Capability）を保持する XML パケット (`<hello>`) を交換します。
2. **XML パケット送信:** クライアントが構成変更用 XML RPC パケット（例: `<rpc message-id="101"><edit-config>...</edit-config></rpc>`) をビルドして送信します。
3. **構文検査 (Well-Formed Check):** ルータの XML パーサーが受信したパケットの構文（閉じタグ、エスケープ等）をチェックします。不整合がある場合、即座に XML Syntax Error が返却されます。
4. **ネームスペース ＆ スキーマ検証 (Schema Validation):** `xmlns` で指定された YANG モジュールを参照し、データ型や不完全なキーフィールドがないかを検証します。
5. **設定適用 ＆ XML レスポンス出力:** 検証に合格した場合、ルータは Running-Config に設定を書き込み、成功を示す `<rpc-reply><ok/></rpc-reply>` を返送します。エラーが発生した場合は `<rpc-error>` タグ内に詳細な原因を挿入してレスポンスします。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure v1.1 ラボ試験において、XML は **NETCONF 構成問題** および **Python スクリプトによるデータ抽出問題** の中核として登場します。単に XML の文法を知っているだけでは不十分であり、CLI や Python 上で正確に処理できる実践力が求められます。

### 1. ラボ試験で頻出の重要ポイント
* **XML ネームスペース (`xmlns`) の不一致:**  
  NETCONF 経由で設定を入れる際、ターゲットの YANG モジュール（例: `urn:ietf:params:xml:ns:yang:ietf-interfaces` や Cisco Native モジュール）の `xmlns` を正確に記述できること。
* **Python `xml.etree.ElementTree` での XPath 抽出:**  
  Python の標準ライブラリ `ElementTree` を使用して、機器から取得した XML レスポンスから特定のタグ（例: インターフェイス名や BGP ネイバー状態）を抽出する際、ネームスペース辞書 `namespaces={'nc': '...', 'if': '...'}` を渡さなければ抽出結果が空 (`None`) になる点。
* **特殊文字のエスケープ処理:**  
  Description に `<` や `&` などの特殊文字が含まれる場合、`&lt;` や `&amp;` にエスケープ記述するか、`<![CDATA[ ... ]]>` セクションで囲む技術。
* **NETCONF テンプレート構築:**  
  `<config>`, `<data>`, `<rpc>`, `<ok/>`, `<rpc-error>` などの定型タグを完全に自力で記述・作成できること。

---


## 🛠 設定方法

XML データエンコーディングは、Cisco IOS XE ルータ/スイッチにおける **NETCONF** や **RESTCONF** のインターフェイス機能を通じて有効化・利用されます。

### 1. Cisco IOS XE 側での NETCONF / XML 受信環境の有効化 CLI

```bash
! NETCONF-YANG サブシステムの有効化 (TCP ポート 830)
netconf-yang

! RESTCONF 機能の有効化 (HTTPS ポート 443)
restconf

! SSH および AAA 認証の設定
username admin privilege 15 secret Cisco12345!
aaa new-model
aaa authentication login default local
aaa authorization exec default local

! VTY ラインでの SSH 許可
line vty 0 4
 transport input ssh
 login authentication default
```

### 2. Python `ncclient` ライブラリを用いた NETCONF XML ペイロード送信プログラム構成

```python
#!/usr/bin/env python3
"""
Cisco IOS XE ルータに対して NETCONF XML ペイロードを送信し、
Loopback インターフェイスを追加設定する Python スクリプト
"""
from ncclient import manager

# デバイス接続情報
DEVICE = {
    'host': '192.168.1.254',
    'port': 830,
    'username': 'admin',
    'password': 'Cisco12345!',
    'hostkey_verify': False,
    'device_params': {'name': 'iosxe'}
}

# 送信する NETCONF edit-config XML ペイロード
# ietf-interfaces YANG モジュールに基づいた XML 構造
XML_CONFIG_PAYLOAD = """
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
    <interface>
      <name>Loopback100</name>
      <description>Configured via NETCONF XML Payload</description>
      <type xmlns:ianaift="urn:ietf:params:xml:ns:yang:iana-if-type">ianaift:softwareLoopback</type>
      <enabled>true</enabled>
      <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ip">
        <address>
          <ip>10.100.100.1</ip>
          <netmask>255.255.255.255</netmask>
        </address>
      </ipv4>
    </interface>
  </interfaces>
</config>
"""

def apply_netconf_xml():
    try:
        with manager.connect(**DEVICE) as m:
            print("[+] NETCONF Session Established. Session ID:", m.session_id)
            
            # edit-config RPC の実行
            response = m.edit_config(target='running', config=XML_CONFIG_PAYLOAD)
            print("[+] Response Received:")
            print(response.xml)
            
            if "<ok/>" in response.xml:
                print("[SUCCESS] Configuration applied successfully via XML.")
            else:
                print("[ERROR] Failed to apply XML configuration.")
                
    except Exception as e:
        print(f"[EXCEPT] Connection or Execution Error: {e}")

if __name__ == '__main__':
    apply_netconf_xml()
```

---

## 🔍 検証コマンド

Cisco IOS XE デバイス上での NETCONF/RESTCONF セッションおよび XML 処理の監視コマンド一覧です。

| 目的 | コマンド |
| --- | --- |
| **NETCONF セッション確認** | `<code>show netconf-yang sessions</code>` |
| **NETCONF セッション統計・エラー** | `<code>show netconf-yang statistics</code>` |
| **RESTCONF セッション確認** | `<code>show restconf-yang sessions</code>` |
| **YANG モジュール一覧表示** | `<code>show platform software yang-management process</code>` |
| **NETCONF プロセスデバッグ** | `<code>debug netconf-yang all</code>` / `<code>debug netconf-yang trace</code>` |
| **RESTCONF プロセスデバッグ** | `<code>debug restconf-yang all</code>` |

---


## 🚨 トラブルシュート

XML 連携および NETCONF/RESTCONF 運用時によく発生するトラブル、原因、確認コマンド、および対処方法の一覧です。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **`rpc-error`: Unknown Element / Invalid Namespace** | XML ペイロード内の `xmlns` ネームスペース指定ミスマッチ、またはタグ名のスペルミス | `<code>debug netconf-yang trace</code>` | 使用する YANG モジュールの定義に合う正確な URI を指定 |
| **`rpc-error`: Bad Element (Type Mismatch)** | YANG スキーマで定義されたデータ型と異なる形式（例: `uint16` ポート番号に文字列を設定） | `<code>show netconf-yang statistics</code>` | YANG スキーマ定義を確認し、正しい値の型・範囲で XML を構成 |
| **XML Syntax Error (Malformed XML)** | 開始タグと終了タグの不一致、引用符の閉じ忘れ、あるいは未エスケープの特殊文字が存在 | Python `xml.etree.ElementTree.fromstring()` | XML パーサーでビルド・事前バリデーションを行い、特殊文字は `&lt;` `&amp;` へ変換または `<![CDATA[ ... ]]>` を使用 |
| **Python での XML パース時に空結果 (`None`) 返却** | `ElementTree.find()` や `findall()` 実行時にネームスペース辞書を指定していない | Python スクリプト側ログ出力 | ネームスペースプレフィックス辞書を渡して検索 |
| **NETCONF ポート 830 接続拒否 (Connection Refused)** | IOS XE 側で `netconf-yang` コンフィグが有効化されていない、または VTY に AAA 認証が正しく設定されていない | `<code>show netconf-yang sessions</code>` / `<code>show run | inc netconf</code>` | グローバルコンフィグで `netconf-yang` を投入し、AAA 認証・認可コンフィグを整合 |

---


## ⚠ 制限事項

* **タグのオーバーヘッドと帯域消費:**  
  すべてのデータ項目に開始タグと終了タグ（例: `<description>...</description>`）が付加されるため、大規模なデータ転送時に JSON よりもパケットサイズが増大し、CPU パース負荷が高くなります。
* **大文字・小文字の完全区別 (Case-Sensitivity):**  
  `<Interface>` と `<interface>` は完全に別のタグとして解釈されます。Cisco Native YANG や IETF YANG モジュールでの英文字表記に厳密に従う必要があります。
* **YANG データモデルキー項目の省略不可:**  
  YANG リスト構造（例: インターフェイスや BGP ネイバー）を変更する場合、キー項目（例: `<name>` や `<neighbor-id>`）の指定が省略されていると `rpc-error` で却下されます。

---

## 🔄 他技術との関連

* **NETCONF (RFC 6241):**  
  NETCONF プロトコルのトランスポートおよび全データ構造の唯一の標準エンコーディングとして XML が機能します。
* **RESTCONF (RFC 8040):**  
  HTTP GET / POST / PUT / PATCH / DELETE 操作において、`Accept: application/yang-data+xml` および `Content-Type: application/yang-data+xml` を指定することで XML フォーマットを透過的に利用できます。
* **YANG データモデル (RFC 7950):**  
  YANG データモデルで記述されたデータツリー構造が、XML の階層エレメントタグおよび属性へと直接シリアライズされます。
* **Python 自動化ライブラリ (`ncclient`, `xml.etree.ElementTree`, `lxml`):**  
  `ncclient` ライブラリは NETCONF XML パケットの送受信を行い、`ElementTree` や `lxml` は受信した XML テキストのパース・検索を担います。

---

## 🧩 比較表

ネットワーク自動化で採用される 3 大データエンコーディング形式の比較です。

| 比較項目 | XML (Extensible Markup Language) | JSON (JavaScript Object Notation) | YAML (YAML Ain't Markup Language) |
| --- | --- | --- | --- |
| **主用途** | NETCONF ペイロード, RESTCONF XML | RESTCONF JSON, Catalyst Center API, SD-WAN API | Ansible Playbook, 変数定義, CI/CD |
| **可読性 (人間)** | 中程度（タグの重複により冗長） | 高い（簡潔で構造が明確） | 最高（インデントベースで可読性が極めて高い） |
| **データ構造** | 木構造（Elements, Attributes, Namespaces） | 辞書（Objects `{}`）, 配列（Arrays `[]`） | スカラー, マップ, リスト |
| **スキーマ検証** | 完全対応 (XSD, DTD, YANG XML) | 完全対応 (JSON Schema, YANG JSON) | 間接的（JSON Schema と互換） |
| **ネームスペース** | 完全サポート (`xmlns`) | 限定的（キー名へのプレフィックス埋め込み） | 非サポート |
| **コメント機能** | サポートあり (`<!-- -->`) | 非サポート | サポートあり (`#`) |
| **パース速度** | 比較的低速（CPU/メモリ負荷大） | 高速 | 中程度 |

---

## 💡 ベストプラクティス

1. **Python パース時は必ずネームスペース辞書を利用する:**  
   `ElementTree` で XPath 検索を行う際は、文字列結合でタグ名を組み立てず、`ns = {'nc': 'urn:...', 'if': 'urn:...'}` のような辞書オブジェクトを定義して安全に検索を行うこと。
2. **NETCONF パケット生成時は定型テンプレートを活用する:**  
   手動で XML 文字列を結合するのではなく、Jinja2 テンプレートエンジンを活用してエスケープ漏れやタグ閉じエラーを自動回避すること。
3. **エスケープ処理を徹底する:**  
   設定パラメータ内に `<` や `&` が含まれる可能性のあるフィールド（Description や Banner）には、必ず `xml.sax.saxutils.escape()` や `<![CDATA[ ... ]]>` を適用すること。

---


## 📝 ラボ学習・設定サンプル例

### サンプル 1: NETCONF XML Payload による BGP IPv4 ネイバー構成 (Cisco Native YANG)

#### 問題
Cisco IOS XE ルータに対して NETCONF (`edit-config`) を使用し、AS 65000 配下に BGP Neighbor 192.168.12.2 (Remote-AS 65000) を追加構成する XML ペイロードを作成・適用しなさい。

#### 要件
* Cisco Native YANG モジュール (`urn:cisco:ns:yang:Cisco-IOS-XE-native`) を使用すること。
* Router BGP AS 65000 配下に Neighbor 192.168.12.2 (remote-as 65000) を定義。

#### 設定例 (Python + NETCONF XML)
```python
from ncclient import manager

DEVICE = {
    'host': '10.1.1.1', 'port': 830,
    'username': 'admin', 'password': 'Cisco12345!',
    'hostkey_verify': False, 'device_params': {'name': 'iosxe'}
}

BGP_XML_PAYLOAD = """
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-native">
    <router>
      <bgp xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-bgp">
        <as-number>65000</as-number>
        <neighbor>
          <id>192.168.12.2</id>
          <remote-as>65000</remote-as>
        </neighbor>
      </bgp>
    </router>
  </native>
</config>
"""

with manager.connect(**DEVICE) as m:
    res = m.edit_config(target='running', config=BGP_XML_PAYLOAD)
    print(res.xml)
```

#### 検証方法
ルータの CLI 上で `show run | section router bgp` を実行し、`router bgp 65000` 配下に `neighbor 192.168.12.2 remote-as 65000` が正常に挿入されていることを確認する。

---

### サンプル 2: Python `xml.etree.ElementTree` を用いた NETCONF OSPF インターフェイス応答解析

#### 問題
ルータから取得した NETCONF `<get-config>` XML レスポンスから、OSPF が有効化されている全インターフェイス名と Area ID を Python スクリプトでパースして表示しなさい。

#### 要件
* `xml.etree.ElementTree` モジュールを使用すること。
* ネームスペース辞書を定義し、XPath 検索を行うこと。

#### 設定例 (Python スクリプト)
```python
import xml.etree.ElementTree as ET

NETCONF_XML_RESPONSE = """
<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <data>
    <native xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-native">
      <router>
        <ospf xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-ospf">
          <id>1</id>
          <area>
            <id>0</id>
            <interface>
              <name>GigabitEthernet1</name>
              <cost>10</cost>
            </interface>
            <interface>
              <name>GigabitEthernet2</name>
              <cost>20</cost>
            </interface>
          </area>
        </ospf>
      </router>
    </native>
  </data>
</rpc-reply>
"""

root = ET.fromstring(NETCONF_XML_RESPONSE)

ns = {
    'nc': 'urn:ietf:params:xml:ns:netconf:base:1.0',
    'ios': 'urn:cisco:ns:yang:Cisco-IOS-XE-native',
    'ospf': 'urn:cisco:ns:yang:Cisco-IOS-XE-ospf'
}

areas = root.findall('.//ospf:area', ns)
for area in areas:
    area_id = area.find('ospf:id', ns).text
    for iface in area.findall('ospf:interface', ns):
        if_name = iface.find('ospf:name', ns).text
        cost = iface.find('ospf:cost', ns).text
        print(f"Interface: {if_name} | Area: {area_id} | Cost: {cost}")
```

#### 検証方法
スクリプトを実行し、`Interface: GigabitEthernet1 | Area: 0 | Cost: 10` のように正しくパース結果が出力されることを確認する。

---

### サンプル 3: RESTCONF XML (`application/yang-data+xml`) による PATCH リクエスト

#### 問題
RESTCONF API を使用し、`GigabitEthernet1` インターフェイスの Description を XML フォーマットで更新しなさい。

#### 要件
* `Content-Type: application/yang-data+xml` ヘッダーを使用すること。
* `ietf-interfaces` モジュール構造に従うこと。

#### 設定例 (Python `requests`)
```python
import requests
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

host = '10.1.1.1'
url = f"https://{host}/restconf/data/ietf-interfaces:interfaces/interface=GigabitEthernet1"
headers = {
    'Content-Type': 'application/yang-data+xml',
    'Accept': 'application/yang-data+xml'
}
auth = ('admin', 'Cisco12345!')

xml_payload = """
<interface xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
  <name>GigabitEthernet1</name>
  <description>Updated via RESTCONF XML PATCH</description>
</interface>
"""

response = requests.patch(url, headers=headers, auth=auth, data=xml_payload, verify=False)
print("Status Code:", response.status_code)
```

#### 検証方法
レスポンスステータスコードが `204 No Content` または `200 OK` であり、`show run int GigabitEthernet1` で Description が更新されていることを確認する。

---

### サンプル 4: NETCONF XML Subtree Filter による特定 BGP 状態のピンポイント取得

#### 問題
ルータから BGP のネイバー状態のみをピンポイント取得するための NETCONF Subtree Filter XML を作成し、`get` 操作を実行しなさい。

#### 要件
* `<filter type="subtree">` タグを使用すること。
* BGP ネイバーの宛先 IP とピアステータスのみを抽出可能にすること。

#### 設定例 (Python + Subtree XML Filter)
```python
from ncclient import manager

DEVICE = {'host': '10.1.1.1', 'port': 830, 'username': 'admin', 'password': 'Cisco12345!', 'hostkey_verify': False, 'device_params': {'name': 'iosxe'}}

SUBTREE_FILTER = """
<filter type="subtree">
  <bgp-state-data xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-bgp-oper">
    <neighbors>
      <neighbor>
        <neighbor-id/>
        <session-state/>
      </neighbor>
    </neighbors>
  </bgp-state-data>
</filter>
"""

with manager.connect(**DEVICE) as m:
    reply = m.get(filter=SUBTREE_FILTER)
    print(reply.xml)
```

#### 検証方法
返却された XML レスポンス内に BGP の `<neighbor-id>` と `<session-state>` (例: `ESTABLISHED`) のみが含まれていることを確認する。

---

### サンプル 5: 特殊文字を含む XML ペイロードと CDATA セクション適用

#### 問題
ルータの Interface Description に `<PRIMARY_WAN & BACKUP_LINK>` という特殊文字を含む文字列を設定する NETCONF XML ペイロードを作成しなさい。

#### 要件
* XML 構文エラーを防止するため、`<![CDATA[ ... ]]>` エスケープセクションを使用すること。

#### 設定例 (NETCONF XML Payload)
```xml
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
    <interface>
      <name>GigabitEthernet2</name>
      <description><![CDATA[<PRIMARY_WAN & BACKUP_LINK>]]></description>
    </interface>
  </interfaces>
</config>
```

#### 検証方法
ルータの CLI 上で `show run int GigabitEthernet2` を実行し、`description <PRIMARY_WAN & BACKUP_LINK>` が構文エラーにならず適用されていることを確認する。

---


### サンプル 6: NETCONF XML による IPv4 スタティックルート追加 (`ietf-routing`)

#### 問題
IETF Routing YANG モジュール (`urn:ietf:params:xml:ns:yang:ietf-routing`) を使用し、宛先 `10.200.200.0/24` ネクストホップ `192.168.1.254` のスタティックルートを追加する NETCONF XML ペイロードを作成しなさい。

#### 要件
* `ietf-routing` データモデルに適合すること。
* ネクストホップ IP アドレスを正確に指定すること。

#### 設定例 (NETCONF XML Payload)
```xml
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <routing xmlns="urn:ietf:params:xml:ns:yang:ietf-routing">
    <routing-instance>
      <name>default</name>
      <routing-protocols>
        <routing-protocol>
          <type xmlns:v4ur="urn:ietf:params:xml:ns:yang:ietf-ipv4-unicast-routing">v4ur:static</type>
          <name>static-1</name>
          <static-routes>
            <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ipv4-unicast-routing">
              <route>
                <destination-prefix>10.200.200.0/24</destination-prefix>
                <next-hop>
                  <next-hop-address>192.168.1.254</next-hop-address>
                </next-hop>
              </route>
            </ipv4>
          </static-routes>
        </routing-protocol>
      </routing-protocols>
    </routing-instance>
  </routing>
</config>
```

#### 検証方法
ルータ CLI 上で `show ip route static` を実行し、`S 10.200.200.0/24 [1/0] via 192.168.1.254` がルーティングテーブルに登録されていることを確認する。

---

### サンプル 7: Python `xmltodict` モジュールを用いた XML 応答から Python 辞書への高速変換

#### 問題
NETCONF `<get>` で取得した XML レスポンスを Python の `xmltodict` モジュールで辞書型 (Dictionary) へ変換し、直感的なキー参照でインターフェイス IP アドレスを抽出するスクリプトを作成しなさい。

#### 要件
* `xmltodict.parse()` 関数を使用すること。
* 辞書キー参照によって特定インターフェイスの IP を表示すること。

#### 設定例 (Python スクリプト)
```python
import xmltodict

XML_DATA = """
<rpc-reply message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <data>
    <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
      <interface>
        <name>Loopback0</name>
        <ipv4 xmlns="urn:ietf:params:xml:ns:yang:ietf-ip">
          <address>
            <ip>1.1.1.1</ip>
          </address>
        </ipv4>
      </interface>
    </interfaces>
  </data>
</rpc-reply>
"""

# XML を Python 辞書へ変換
data_dict = xmltodict.parse(XML_DATA)

# 辞書キー参照での抽出
iface = data_dict['rpc-reply']['data']['interfaces']['interface']
if_name = iface['name']
ip_addr = iface['ipv4']['address']['ip']

print(f"Interface: {if_name} | IP Address: {ip_addr}")
```

#### 検証方法
スクリプトを実行し、`Interface: Loopback0 | IP Address: 1.1.1.1` が正常に出力されることを確認する。

---

### サンプル 8: NETCONF XML `nc:operation="delete"` によるインターフェイス削除

#### 問題
NETCONF を使用して、ルータ上の `Loopback100` インターフェイスを削除する XML ペイロードを作成・適用しなさい。

#### 要件
* 属性 `nc:operation="delete"` を使用すること。
* ネームスペースプレフィックス `xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0"` を正しく定義すること。

#### 設定例 (Python + NETCONF Delete XML)
```python
from ncclient import manager

DEVICE = {'host': '10.1.1.1', 'port': 830, 'username': 'admin', 'password': 'Cisco12345!', 'hostkey_verify': False, 'device_params': {'name': 'iosxe'}}

DELETE_XML_PAYLOAD = """
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0" xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
  <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
    <interface nc:operation="delete">
      <name>Loopback100</name>
    </interface>
  </interfaces>
</config>
"""

with manager.connect(**DEVICE) as m:
    res = m.edit_config(target='running', config=DELETE_XML_PAYLOAD)
    print(res.xml)
```

#### 検証方法
ルータ CLI 上で `show ip interface brief` を実行し、`Loopback100` が削除され表示されないことを確認する。

---

### サンプル 9: Python `ncclient` における `RPCError` (XML スキーマエラー) の捕捉とログ出力

#### 問題
不当なタグ（型違いや存在しない要素）を含む XML ペイロードを送信した際に返却される NETCONF `<rpc-error>` を Python の `RPCError` 例外で捕捉し、エラーメッセージを詳細出力するスクリプトを作成しなさい。

#### 要件
* `ncclient.operations.rpc.RPCError` 例外クラスをキャッチすること。
* `err.message` および `err.xml` を表示すること。

#### 設定例 (Python エラーハンドリング)
```python
from ncclient import manager
from ncclient.operations.rpc import RPCError

DEVICE = {'host': '10.1.1.1', 'port': 830, 'username': 'admin', 'password': 'Cisco12345!', 'hostkey_verify': False, 'device_params': {'name': 'iosxe'}}

# 存在しない不正な要素タグを含む XML ペイロード
INVALID_XML_PAYLOAD = """
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-native">
    <invalid-tag-element>True</invalid-tag-element>
  </native>
</config>
"""

try:
    with manager.connect(**DEVICE) as m:
        m.edit_config(target='running', config=INVALID_XML_PAYLOAD)
except RPCError as err:
    print("[+] RPC Error Caught Successfully:")
    print("Error Tag    :", err.tag)
    print("Error Message:", err.message)
    print("Raw Error XML:\n", err.xml)
```

#### 検証方法
スクリプトを実行し、`RPC Error Caught Successfully` と共に `<error-tag>unknown-element</error-tag>` などの詳細エラー情報が出力されることを確認する。

---

### サンプル 10: Jinja2 テンプレートを用いた NETCONF XML ペイロードの動的生成

#### 問題
Python の `Jinja2` テンプレートエンジンを使用し、複数 VLAN (10, 20, 30) および IP アドレスのリスト構造から NETCONF 用の XML 設定データを動的に生成しなさい。

#### 要件
* Jinja2 の `{% for %}` ループ構文を使用すること。
* 動的に生成された XML 文字列を表示・出力すること。

#### 設定例 (Python + Jinja2)
```python
from jinja2 import Template

# Jinja2 XML テンプレート定義
XML_JINJA_TEMPLATE = """
<config xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="urn:cisco:ns:yang:Cisco-IOS-XE-native">
    <interface>
      {% for vlan in vlans %}
      <Vlan>
        <name>{{ vlan.id }}</name>
        <description>{{ vlan.name }}</description>
        <ip>
          <address>
            <primary>
              <address>{{ vlan.ip }}</address>
              <mask>255.255.255.0</mask>
            </primary>
          </address>
        </ip>
      </Vlan>
      {% endfor %}
    </interface>
  </native>
</config>
"""

# 入力パラメータリスト
vlan_data = [
    {'id': 10, 'name': 'USERS', 'ip': '10.1.10.1'},
    {'id': 20, 'name': 'VOICE', 'ip': '10.1.20.1'},
    {'id': 30, 'name': 'MGMT',  'ip': '10.1.30.1'}
]

template = Template(XML_JINJA_TEMPLATE)
rendered_xml = template.render(vlans=vlan_data)
print(rendered_xml)
```

#### 検証方法
出力された XML 文字列内に VLAN 10, 20, 30 の `<Vlan>` タグが正しく生成されていることを確認する。

---


## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**問題:**  
Python の `xml.etree.ElementTree` を使用してルータからの NETCONF XML レスポンスをパースした際、XML 内に目的のデータ要素 `<ip>` が確実に存在するにもかかわらず、`root.find('.//ip')` が常に `None` を返却します。考えられる原因と正しい修正方法を答えなさい。

**解答と解説:**  
* **原因:** XML データ内にデフォルトネームスペース（例: `xmlns="urn:ietf:params:xml:ns:yang:ietf-ip"`）が定義されている場合、`ElementTree` はタグ名を完全修飾名 `{urn:ietf:params:xml:ns:yang:ietf-ip}ip` として内部管理します。単なるプレーンテキストの `'ip'` や `'.//ip'` で検索すると、ネームスペース不一致により検索に失敗し `None` が返却されます。
* **修正方法:** 検索時にネームスペースプレフィックス辞書を定義して渡すか、タグ名に修飾子を付与して検索します。
  ```python
  ns = {'ip': 'urn:ietf:params:xml:ns:yang:ietf-ip'}
  elem = root.find('.//ip:ip', namespaces=ns)
  ```

---

### 問 2 (トラブルシューティング)
**問題:**  
`ncclient` を用いて NETCONF `edit-config` XML ペイロードを送信したところ、ルータから以下の `<rpc-error>` が返却されました。エラーの原因と対処方法を説明しなさい。

```xml
<rpc-reply message-id="urn:uuid:12345" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <rpc-error>
    <error-type>application</error-type>
    <error-tag>unknown-element</error-tag>
    <error-severity>error</error-severity>
    <error-info>
      <bad-element>description-text</bad-element>
    </error-info>
  </rpc-error>
</rpc-reply>
```

**解答と解説:**  
* **原因:** `<error-tag>unknown-element</error-tag>` および `<bad-element>description-text</bad-element>` は、送信した XML ペイロード内に指定した YANG データモデル（スキーマ）に存在しない不正な要素タグ `<description-text>` が含まれていることを示します（正しい要素名は `<description>`）。
* **対処方法:** ターゲットとする YANG データモデル（例: `ietf-interfaces` や `Cisco-IOS-XE-native`）の正しい定義を確認し、タグ名のスペルミス（`<description-text>` ➔ `<description>`）を修復して再送信します。

---

### 問 3 (Design)
**問題:**  
ネットワーク自動化アーキテクチャの設計において、NETCONF (XML) と RESTCONF (JSON) の特性を踏まえた使い分けの指針を説明しなさい。

**解答と解説:**  
* **NETCONF (XML):**  
  トランザクション処理（Commit / Rollback / Candidate Config）、長時間接続（SSH ポート 830）、および完全な構造・型検証が必要な基幹ネットワーク機器の一括構成管理（Batch Configuration）に適しています。XML の厳密なネームスペース管理と XSD/YANG スキーマ連携により極めて信頼性が高い設計が可能です。
* **RESTCONF (JSON):**  
  Web ダッシュボード、コントローラ連携、軽量な型定義、および迅速な CRUD (Create/Read/Update/Delete) 操作が求められるエッジ/マイクロサービス環境に適しています。Stateless な HTTP/HTTPS 通信と簡潔な JSON 構造により開発コストを抑制できます。

---

### 問 4 (実装)
**問題:**  
RESTCONF API で XML フォーマット (`application/yang-data+xml`) のリクエストを送信する際、HTTP リクエストヘッダーに設定すべき必須項目を 2 つ挙げなさい。

**解答と解説:**  
1. `Content-Type: application/yang-data+xml` (送信するリクエストボディのデータ形式が XML であることを指定)
2. `Accept: application/yang-data+xml` (サーバーから返却されるレスポンスボディのフォーマットに XML を要求)

---

### 問 5 (トラブルシューティング)
**問題:**  
ルータの Description に `Core_SW & Branch_Router <Primary>` という文字を NETCONF XML ペイロードで設定しようとしたところ、クライアント側の XML パーサーで `xml.parsers.expat.ExpatError: not well-formed (invalid token)` エラーが発生して送信できませんでした。原因と修正コンフィグ（XML コード）を提示しなさい。

**解答と解説:**  
* **原因:** XML ではアンパサンド (`&`) および不等号 (`<`, `>`) が予約文字として定義されているため、そのままテキストとして記述すると XML 構文崩壊 (Malformed XML) を引き起こします。
* **修正方法:** 予約文字を定義済み実体参照へ置き換えるか、`<![CDATA[ ... ]]>` セクションを使用します。
  * **実体参照方式:** `<description>Core_SW &amp; Branch_Router &lt;Primary&gt;</description>`
  * **CDATA 方式:** `<description><![CDATA[Core_SW & Branch_Router <Primary>]]></description>`

---


## 🔗 参考リソース

* **Cisco Live セッション:**
  * BRKACT-2012 - Programmability and Automation with Cisco Enterprise OS
  * BRKACT-1002 - Introduction to NETCONF, RESTCONF and YANG
* **Configuration Guide:**
  * Cisco IOS XE 17.x Programmability Configuration Guide - NETCONF Protocol
  * Cisco IOS XE 17.x Programmability Configuration Guide - RESTCONF Protocol
* **Command Reference:**
  * Cisco IOS XE Programmability Command Reference - netconf-yang Commands
* **RFC 標準規格ドキュメント:**
  * RFC 6241 - Network Configuration Protocol (NETCONF)
  * RFC 8040 - RESTCONF Protocol
  * RFC 7950 - The YANG 1.1 Data Modeling Language
* **W3C 標準規格:**
  * W3C Extensible Markup Language (XML) 1.0 Specification
* **Youtube 解説演習動画:**
  * Cisco DevNet: Getting Started with NETCONF and XML Validation
  * CCIE Lab Prep: Parsing NETCONF XML Responses using Python ElementTree


## 📝 補足（Notes）

### 1. XML ノード階層構造の視覚的まとめ
```
[ Document Root ]
       │
       └── <rpc-reply> (Root Element)
              │
              ├── attribute: message-id="101"
              ├── attribute: xmlns="urn:ietf:params:xml:ns:netconf:base:1.0"
              │
              └── <data> (Child Element)
                     │
                     └── <interfaces> (Child Element)
                            │
                            └── <interface> (List Item Element)
                                   ├── <name>GigabitEthernet1</name>
                                   ├── <enabled>true</enabled>
                                   └── <ipv4>
                                          └── <address>
                                                 ├── <ip>10.1.1.1</ip>
                                                 └── <netmask>255.255.255.0</netmask>
```

### 2. ラボ試験直前チェックリスト
- [ ] NETCONF の送信ポートが **TCP 830** であることを即答できるか？
- [ ] Cisco IOS XE 上で NETCONF を有効化するコマンド `netconf-yang` を暗記しているか？
- [ ] RESTCONF で XML を送受信する際の HTTP ヘッダー `Content-Type: application/yang-data+xml` および `Accept: application/yang-data+xml` を記述できるか？
- [ ] XML の予約文字（`<`, `>`, `&`）に対する `<![CDATA[ ... ]]>` または定義済み実体参照（`&lt;`, `&gt;`, `&amp;`）のエスケープ処理を適用できるか？
- [ ] Python `xml.etree.ElementTree` で XML をパースする際、ネームスペース辞書 `namespaces={'prefix': 'urn:...'}` を渡して XPath 検索できるか？
- [ ] NETCONF XML ペイロード内で要素を削除する際の属性 `nc:operation="delete"` の書き方を把握しているか？
