---
layout: default
title: 5.1.a-JSON
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.1.a JSON

## 📘 概要

JavaScript Object Notation (JSON) は、RFC 8259（および IETF STD 90）で規定されている軽量のテキストベースのデータ交換フォーマット（Data Encoding Format）です。人間にとって読み書きが容易であり、コンピューターにとってもパース（解析）や生成が非常に高速かつ容易であるという特徴を持ちます。

CCIE Enterprise Infrastructure (EI) v1.1 において、JSON はプログラマビリティおよび自動化（Infrastructure Automation and Programmability）領域のバックボーンとなる最重要データ表現フォーマットです。Cisco DNA Center (Catalyst Center) Intent API、Cisco SD-WAN vManage REST API、および Cisco IOS XE 上の RESTCONF（`application/yang-data+json`）インターフェイスとの通信において、リクエストボディ（Payload）およびレスポンス（Response Body）の主たる標準エンコーディング形式として利用されます。

* **機能概要:** 構造化データ（オブジェクト、配列、文字列、数値、真偽値、null）をテキスト文字列として直列化（Serialization）および可読化する標準仕様。
* **利用目的:** システム間、API プログラムとネットワーク機器間におけるデータの透明かつ軽量な交換。特に HTTP/HTTPS をトランスポートとする RESTful API および RESTCONF プロトコルの制御データ表現。
* **どのような場面で利用するか:** 
  * Cisco DNA Center / SD-WAN vManage からのネットワークトポロジー、デバイスインベントリ、アラーム情報の REST API 経由での取得。
  * RESTCONF を介した Cisco IOS XE デバイスへのインターフェイス設定、ルーティングプロトコル設定（YANG データモデルにマッピングされた JSON ペイロード）の編集（POST / PUT / PATCH）。
  * Python（`requests` ライブラリ）や Ansible 等の自動化ツールを用いた、ネットワーク機器データの構造的パースおよび処理。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **特徴** | 属性と値のペア（Object）、および値の順序付きリスト（Array）から構成される完全なテキストフォーマット。簡潔で軽量。 |
| **用途** | REST API Payload (DNA Center, SD-WAN vManage)、RESTCONF (IOS XE / NX-OS)、Python データ構造（`dict`/`list`）との相互変換。 |
| **メリット** | XML に比べてデータ量（オーバーヘッド）が少なく軽量。人間に可読であり、汎用言語（Python, JavaScript, Go 等）でのネイティブサポートが強力。 |
| **デメリット** | コメントを記述できない（RFC 8259 準拠）。Schema（型定義）が標準で強制されないため自由度が高すぎる。バイナリデータの直接埋め込み不可（Base64 化が必要）。 |
| **対応機種・OS** | Cisco IOS XE (Catalyst 9000, ISR/ASR/CSR1000v/8000V), NX-OS, SD-WAN vEdge/cEdge, Catalyst Center (DNA Center), ISE など全近代 Cisco プラットフォーム。 |
| **制限事項** | カンマの末尾記述（Trailing Comma）禁止。文字列指定時のシングルクォート（`'`）使用不可（ダブルクォート `"` 必須）。データ型として非数（NaN）や無限大（Infinity）は非サポート。 |
| **設計上の注意点** | RESTCONF 等で YANG データモデルを JSON 化する場合、YANG の型（`uint32`, `boolean`, `identityref`）と JSON データ型の不一致に注意が必要。 |

---

## 🏗 動作原理

JSON の動作原理は、メモリ上のデータ構造（Python の辞書 `dict` やリスト `list` など）を標準化されたテキスト形式に変換する**シリアライズ（Serialization / Encoding）**と、受信したテキスト文字列をプログラム内のオブジェクトに復元する**デシリアライズ（Deserialization / Decoding / Parsing）**の双方向変換に基づきます。

```
+-------------------------------------------------------------------+
|                        Python Environment                         |
|  dict / list Object: {'ietf-interfaces:interface': {'name': 'Gi1'}} |
+-------------------------------------------------------------------+
                  │                                   ▲
                  │ json.dumps()                      │ json.loads()
                  │ (Serialization)                   │ (Deserialization)
                  ▼                                   │
+-------------------------------------------------------------------+
|                           JSON Text                               |
|  '{"ietf-interfaces:interface": {"name": "GigabitEthernet1"}}'    |
+-------------------------------------------------------------------+
                  │                                   ▲
                  │ HTTP POST / PUT (RESTCONF)        │ HTTP 200 OK (JSON)
                  ▼                                   │
+-------------------------------------------------------------------+
|                     Cisco IOS XE / Device                         |
|  YANG Data Model Parser -> Configuration Database (Running-Config)|
+-------------------------------------------------------------------+
```

### 1. JSON の基本データ型（Data Types）

JSON は以下の 6 つのデータ型のみで構成されます。

1. **String（文字列）:** Unicode 文字列。必ずダブルクォート（`"`）で囲む必要があります。エスケープシーケンス（`\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`）をサポート。
2. **Number（数値）:** 10 進数の整数または浮動小数点数（例: `42`, `-3.14`, `1.5e10`）。引用符で囲んではいけません。先頭のゼロ（例: `0123`）は禁止されています。
3. **Object（オブジェクト）:** 無順序のキーと値のペアの集合。波括弧 `{}` で囲み、キーと値はコロン `:` で区切り、ペア同士はカンマ `,` で区切ります。**キーは必ずダブルクォートで囲まれた String でなければなりません。**
4. **Array（配列）:** 順序付きの値のリスト。角括弧 `[]` で囲み、要素間はカンマ `,` で区切ります。要素の型は混在可能です。
5. **Boolean（真偽値）:** 小文字の `true` または `false`。
6. **Null（空値）:** 小文字の `null`。値が存在しないことを明示します。

### 2. オブジェクトと配列の構造例

```json
{
  "ietf-interfaces:interface": {
    "name": "GigabitEthernet1",
    "description": "Configured via RESTCONF JSON",
    "type": "iana-if-types:ethernetCsmacd",
    "enabled": true,
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "10.1.1.1",
          "netmask": "255.255.255.0"
        }
      ]
    }
  }
}
```

---

## ⚙ 動作シーケンス

JSON を利用した API 通信（例: RESTCONF を介した Cisco IOS XE インターフェイス設定変更）におけるパケット処理・データ変換の動作シーケンスは以下の通りです。

```
Client (Python/Automation)                               Cisco IOS XE (RESTCONF)
     │                                                              │
     │ 1. 内部データオブジェクト(dict)構築                          │
     │    data = {'ietf-interfaces:interface': {...}}               │
     │                                                              │
     │ 2. json.dumps(data) で JSON 文字列へ直列化                   │
     │    payload = '{"ietf-interfaces:interface": ...}'            │
     │                                                              │
     │ 3. HTTP POST Request 発行                                    │
     │ ─── Content-Type: application/yang-data+json ──────────────> │
     │     Payload: JSON String                                     │
     │                                                              │ 4. HTTP ヘッダー検証
     │                                                              │    Content-Type パース
     │                                                              │
     │                                                              │ 5. JSON パーサー起動
     │                                                              │    構文解釈 (JSON Syntax Check)
     │                                                              │
     │                                                              │ 6. YANG スキーマ検証
     │                                                              │    (ietf-interfaces.yang)
     │                                                              │    型チェック (ip, netmask, enabled)
     │                                                              │
     │                                                              │ 7. Datastore 更新
     │                                                              │    running-config へコミット
     │ 8. HTTP 201 Created レスポンス受領                            │
     │ <── Content-Type: application/yang-data+json ─────────────── │
     │     Body: {"ietf-interfaces:interface": ...} (オプション)    │
     │                                                              │
```

### シーケンス詳細手順

1. **データ構築 (Data Modeling):** 送信側プログラムにおいて、メモリ上に管理対象のパラメータを辞書（Dictionary）やリスト構造として組み立てます。
2. **シリアライゼーション (Encoding):** 言語ネイティブなエンコーダー（例: Python の `json.dumps()`）により、UTF-8 エンコードされた JSON テキスト文字列へ変換します。
3. **HTTP トランスポート伝送:** `Content-Type: application/yang-data+json`（RESTCONF の場合）または `Content-Type: application/json`（REST API の場合）ヘッダーを付与し、HTTP Body に JSON テキストを載せて POST/PUT/PATCH リクエストを送信します。
4. **構文解析 (JSON Parsing):** 受信側（Cisco IOS XE / Controller）の Web サーバーエンジン（`nginx` / `http-core`）が受領し、JSON パーサーが文字の閉じ括弧やカンマの位置、引用符の正確性を検証します。構文エラーがある場合、直ちに `400 Bad Request` または `JSONDecodeError` 相当の応答を返します。
5. **スキーマ照合 (YANG / OpenAPI Validation):** パースされた JSON オブジェクトは、システムが保持するデータモデル（YANG スキーマまたは Swagger/OpenAPI 定義）と照合されます。データ型の不一致（文字列 `enabled: "true"` vs ブール値 `enabled: true` など）や必須キーの欠落がないか確認されます。
6. **データベース反映 (Configuration Commit):** スキーマ検証に成功すると、内部の CDB (Configuration Database) に変更が反映され、機器の `running-config` が動的に書き換えられます。


## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure (EI) v1.1 ラボ試験（Design & Deploy, Operate, Optimize の両モジュール）において、JSON の直接編集やパース能力は得点に直結する必須スキルです。

### 1. Blueprint で重要なポイント

* **YANG データモデルと JSON 表現の厳密な対応:** RESTCONF を利用する際、YANG データモデル（RFC 7951）に基づいて JSON 構造を構築する必要があります。モジュール名を含むネームスペース指定（例: `"ietf-interfaces:interface"`）の記述漏れは致命的なエラーを引き起こします。
* **データ型の厳密性:** 
  * YANG の `boolean` 型 ➔ JSON の `true` / `false` (ダブルクォートなし)
  * YANG の `uint8`/`uint16`/`uint32` 型 ➔ JSON の `42` (ダブルクォートなしの数値)
  * YANG の `string` 型 ➔ JSON の `"GigabitEthernet1"` (ダブルクォートあり)
  * YANG の `leaf-list` / `list` ➔ JSON の Array `[...]`
* **Python での JSON 処理 (`json` モジュール):** 
  * `json.loads(string)` : JSON 文字列から Python 辞書/リストへのデシリアライズ
  * `json.dumps(obj, indent=2)` : Python 辞書/リストから整形済み JSON 文字列へのシリアライズ
  * `json.load(file_object)` / `json.dump(obj, file_object)` : ファイル I/O 経由の処理

### 2. ラボ試験で出題されやすいシナリオ・設定要件

1. **RESTCONF を用いた設定自動投入:**
   Python の `requests` ライブラリを使用して、`http://<IP>/restconf/data/ietf-interfaces:interfaces` に対して JSON ペイロードを HTTP POST / PUT / PATCH 送信し、ルータに VLAN や IP アドレスを設定する。
2. **Cisco DNA Center (Catalyst Center) REST API 連携:**
   `POST /dna/system/api/v1/auth/token` 経由で認証トークンを取得（JSON レスポンスの `"Token"` キーを抽出）し、そのトークンをヘッダーにセットしてデバイスインベントリ JSON を取得・パースする。
3. **Cisco SD-WAN vManage REST API 連携:**
   vManage へのログイン（`/j_security_check` ＋ `/api/client/token`）後、デバイス一覧やテンプレート情報 JSON を取得し、特定の属性値を Python でソート・抽出する。
4. **不完全・壊れた JSON ペイロードの修正 (Troubleshooting):**
   与えられた Python スクリプトや JSON ペイロードに含まれる文法エラー（末尾カンマ、シングルクォート、ブール値の文字列化など）を修正し、API 呼び出しを正常化させる。

### 3. よくある設定ミス・構文エラー (Pitfalls)

* **シングルクォート（`'`）の使用:**
  * ❌ 間違い: `{'name': 'GigabitEthernet1'}`
  * ⭕ 正解: `{"name": "GigabitEthernet1"}`
  * ※ Python の辞書文字列表現をそのまま JSON と誤認して送信すると、100% `JSONDecodeError` または `400 Bad Request` になります。
* **末尾のカンマ（Trailing Comma）:**
  * ❌ 間違い: `{"ip": "10.1.1.1", "netmask": "255.255.255.0",}`
  * ⭕ 正解: `{"ip": "10.1.1.1", "netmask": "255.255.255.0"}`
* **ブール値の先頭大文字化 (Python スタイル混入):**
  * ❌ 間違い: `"enabled": True` または `"enabled": "true"`
  * ⭕ 正解: `"enabled": true`
* **HTTP Header の指定漏れ:**
  * RESTCONF で JSON を送る際、`headers={'Content-Type': 'application/yang-data+json', 'Accept': 'application/yang-data+json'}` を指定しないと、ルータが `415 Unsupported Media Type` または `406 Not Acceptable` を返します。


## 🛠 設定方法

### 1. Python での JSON 相互変換と HTTP リクエスト実装パターン

#### (1) JSON 文字列のデシリアライズと辞書操作
```python
import json

raw_json_response = """
{
  "ietf-interfaces:interfaces-state": {
    "interface": [
      {
        "name": "GigabitEthernet1",
        "type": "iana-if-types:ethernetCsmacd",
        "admin-status": "up",
        "oper-status": "up",
        "phys-address": "52:54:00:12:34:56"
      },
      {
        "name": "GigabitEthernet2",
        "type": "iana-if-types:ethernetCsmacd",
        "admin-status": "down",
        "oper-status": "down",
        "phys-address": "52:54:00:78:9a:bc"
      }
    ]
  }
}
"""

data = json.loads(raw_json_response)
interfaces = data["ietf-interfaces:interfaces-state"]["interface"]
for iface in interfaces:
    print(f"Interface: {iface['name']} | Admin: {iface['admin-status']} | Oper: {iface['oper-status']}")
```

#### (2) Python 辞書からの JSON ペイロード構築と RESTCONF POST
```python
import json
import requests
from requests.auth import HTTPBasicAuth

url = "https://router.example.com/restconf/data/ietf-interfaces:interfaces"
auth = HTTPBasicAuth("admin_user", "auth_secret")
headers = {
    "Content-Type": "application/yang-data+json",
    "Accept": "application/yang-data+json"
}

payload_dict = {
    "ietf-interfaces:interface": {
        "name": "Loopback100",
        "description": "Configured by Python via RESTCONF JSON",
        "type": "iana-if-types:softwareLoopback",
        "enabled": True,
        "ietf-ip:ipv4": {
            "address": [
                {
                    "ip": "192.168.100.1",
                    "netmask": "255.255.255.255"
                }
            ]
        }
    }
}

response = requests.post(
    url,
    auth=auth,
    headers=headers,
    data=json.dumps(payload_dict),
    verify=False
)

print(f"Status Code: {response.status_code}")
print(f"Response Body: {response.text}")
```


### 2. Linux コマンドライン（`curl` ＋ `jq`）による検証方法

```bash
# RESTCONF 経由で全インターフェイス情報を取得し、jq で整形表示
curl -s -k -u "admin_user:auth_secret" \
  -H "Accept: application/yang-data+json" \
  https://router.example.com/restconf/data/ietf-interfaces:interfaces-state | jq '.'

# インターフェイス名と IP アドレスのみを抽出する jq フィルター
curl -s -k -u "admin_user:auth_secret" \
  -H "Accept: application/yang-data+json" \
  https://router.example.com/restconf/data/ietf-interfaces:interfaces | \
  jq '.["ietf-interfaces:interfaces"]["interface"][] | {name: .name, ip: .["ietf-ip:ipv4"].address[0].ip}'
```

---

## 🔍 検証コマンド

JSON データおよび API 通信の検証に利用する主要コマンドおよびツールは以下の通りです。

| 目的 | コマンド / ツール | 説明 |
| --- | --- | --- |
| **Python 内での JSON 構文チェック** | `python3 -m json.tool < file.json` | JSON ファイルの構文バリデーションを行い、整形して出力。構文エラーがあれば行番号を表示。 |
| **Linux CLI での JSON パース・検索** | `jq '.key.path' file.json` | 複雑な JSON 構造から必要な要素をスライシング・抽出。 |
| **RESTCONF JSON 取得検証** | `curl -k -u user:pass -H "Accept: application/yang-data+json" ...` | Cisco IOS XE から JSON 形式でライブデータをレスポンス取得。 |
| **RESTCONF JSON 投稿検証** | `curl -k -X POST -d @payload.json -H "Content-Type: application/yang-data+json" ...` | ローカルの JSON ファイルを送信して設定投入。 |
| **IOS XE 側 RESTCONF デバッグ** | <code>debug restconf ...</code> | ルータ側で RESTCONF リクエストのパースおよび処理状況をリアルタイム表示。 |
| **IOS XE HTTP サーバー状態確認** | <code>show ip http server status</code> | RESTCONF (HTTPS) インターフェイスの動作状態とアクセス状況を確認。 |


## 🚨 トラブルシュート

| 症状 | 原因 | 確認・対処方法 |
| --- | --- | --- |
| **`json.decoder.JSONDecodeError`** | JSON 文字列の文法違反（シングルクォート、末尾カンマ、クォート閉じ忘れ等）。 | `python3 -m json.tool file.json` でエラー位置を特定し、ダブルクォートへの統一およびカンマ削除を実施。 |
| **HTTP `400 Bad Request`** | JSON 構文は正常だが、YANG データモデル（キー名、型、ネームスペース）不一致。 | IOS XE 側で `debug restconf` を有効化し、不一致フィールドをログ特定。YANG スキーマを参照して型（String vs Int/Bool）を補正。 |
| **HTTP `415 Unsupported Media Type`** | Header の `Content-Type` 不正、または JSON ボディが空。 | リクエストヘッダーに `Content-Type: application/yang-data+json` (RESTCONF) または `application/json` (REST API) を付与。 |
| **`KeyError: 'interface'`** | JSON のネスト構造階層のアクセス指定誤り（キー名のプレフィックス付け忘れ）。 | JSON のキー名を print / jq で確認。YANG のネームスペース付きキー（例: `ietf-interfaces:interface`）を正確に指定。 |
| **`TypeError: Object of type datetime is not JSON serializable`** | Python オブジェクトを `json.dumps()` する際、非サポート型（datetime 等）が含まれている。 | カスタムエンコーダークラスを作成するか、標準型（String / Int / dict / list）に事前キャスト。 |

---

## ⚠ 制限事項

* **コメント不保持:** RFC 8259 仕様上、JSON 内にコメント（`//` または `/* */`）を記述できません。設定意図を保存したい場合は別ドキュメントやメタデータフィールドを使用する必要があります。
* **ストリーミングに不向き:** JSON は完全な構造データであるため、パースを完了するにはデータ全体を受信・ロードする必要があります（大規模データではメモリ負荷増大）。
* **バイナリ非対応:** 画像や証明書などのバイナリデータを直接含めることができません。Base64 エンコードして String 型として扱う必要があります。
* **数字の精度問題:** IEEE 754 ダブル精度浮動小数点数の制限により、極めて大きな整数（64 ビット整数等）を JSON 数値として扱うと精度低下が起こるため、文字列として表現することが推奨されます（YANG `int64`/`uint64` の JSON マッピング仕様）。


## 🔄 他技術との関連

* **RESTCONF (RFC 8040):** 
  HTTP 上で動作するネットワーク構成管理プロトコル。データエンコーディングとして XML と並んで JSON (`application/yang-data+json`) を標準サポート。
* **YANG データモデル (RFC 7950 / RFC 7951):** 
  データ構造を定義するデータモデリング言語。RFC 7951 は YANG データモデルを JSON に正確にマッピングするためのルール（JSON 構造、型マッピング、ネームスペースプレフィックス）を標準化しています。
* **Cisco DNA Center (Catalyst Center) & SD-WAN vManage REST API:** 
  ノースバウンド API (Intent API / Management API) の標準エンコーディングとして JSON (`application/json`) を全面採用。
* **Ansible & Jinja2:** 
  Ansible モジュールの返り値（`result`）は内部的に JSON オブジェクトとして扱われ、Jinja2 テンプレートエンジンでの動的レンダリングや条件分岐（`when`）に直接利用されます。

---

## 🧩 比較表

| 項目 | JSON | XML | YAML |
| --- | --- | --- | --- |
| **可読性 (Human Readability)** | 高い (シンプル) | 中程度 (タグの冗長性あり) | **最高** (インデントベース) |
| **機械のパース速度** | **極めて高速** | 中程度 (DOM/SAX パース重) | 比較的高速 |
| **オーバーヘッド** | **小** (テキスト量少) | 大 (閉じタグ等のオーバーヘッド) | **最小** |
| **型サポート (Type System)** | 限定的 (String, Number, Bool, Null) | すべてテキスト (Schema 依存) | 豊富 (型推論あり) |
| **コメント機能** | **不可** | 可能 (`<!-- comment -->`) | **可能** (`# comment`) |
| **主な利用用途** | REST API, RESTCONF Payload | NETCONF, Legacy Web Services | Ansible Playbook, CI/CD 設定 |
| **標準規定** | RFC 8259 | W3C Standard | YAML Specification |

---

## 💡 ベストプラクティス

1. **Python `requests` の `json` パラメータ活用:**
   `requests.post(url, data=json.dumps(dict_data))` とする代わりに、`requests.post(url, json=dict_data)` を使用することで、自動的にシリアライズと `Content-Type: application/json` ヘッダーの設定が行われ、記述ミスを軽減できます。
2. **YANG プレフィックスの明示的付与:**
   RESTCONF 用の JSON を作成する際、ルート要素および異なるモジュール由来のキーには必ず YANG プレフィックス（例: `"ietf-interfaces:interface"`）を付与します。
3. **キー存在チェックの徹底 (`get()` メソッド):**
   ネストされた JSON から値を抽出する際、直接インデックス指定 `data["key"]` するとキー欠落時に `KeyError` が発生するため、`data.get("key", default_value)` や `try-except` ブロックを用いて堅牢な処理を記述します。
4. **`json.dumps(obj, indent=2)` によるデバッグログ可視化:**
   複雑な JSON レスポンスをログ出力や画面表示する際は、`indent=2` または `indent=4` を指定して整形（Pretty Print）し、構造を視覚的に捉えやすくします。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: Python `json.loads()` による RESTCONF 応答からの IP アドレス抽出

* **問題:** RESTCONF 経由で取得したインターフェイス状態 JSON 文字列から、`GigabitEthernet1` の IPv4 アドレスおよびサブネットマスクを抽出し、画面表示する Python スクリプトを作成しなさい。
* **要件:**
  1. JSON 文字列を `json.loads()` でデシリアライズすること。
  2. インターフェイスリストから `name` が `"GigabitEthernet1"` である要素を特定すること。
  3. キーの欠落に備えて安全に値を取り出すこと。
* **設定例（Python スクリプト）:**

```python
import json

restconf_response = """
{
  "ietf-interfaces:interfaces-state": {
    "interface": [
      {
        "name": "GigabitEthernet1",
        "type": "iana-if-types:ethernetCsmacd",
        "admin-status": "up",
        "oper-status": "up",
        "ietf-ip:ipv4": {
          "address": [
            {
              "ip": "10.255.255.1",
              "netmask": "255.255.255.0"
            }
          ]
        }
      },
      {
        "name": "Loopback0",
        "type": "iana-if-types:softwareLoopback",
        "admin-status": "up",
        "oper-status": "up",
        "ietf-ip:ipv4": {
          "address": [
            {
              "ip": "1.1.1.1",
              "netmask": "255.255.255.255"
            }
          ]
        }
      }
    ]
  }
}
"""

def extract_ip_info(json_str, target_iface):
    data = json.loads(json_str)
    ifaces = data.get("ietf-interfaces:interfaces-state", {}).get("interface", [])
    
    for iface in ifaces:
        if iface.get("name") == target_iface:
            ipv4_info = iface.get("ietf-ip:ipv4", {}).get("address", [])
            if ipv4_info:
                ip = ipv4_info[0].get("ip")
                netmask = ipv4_info[0].get("netmask")
                return ip, netmask
    return None, None

ip, mask = extract_ip_info(restconf_response, "GigabitEthernet1")
print(f"GigabitEthernet1 IPv4 Address: {ip}/{mask}")
```

* **検証方法:**
  Python スクリプトを実行し、`GigabitEthernet1 IPv4 Address: 10.255.255.1/255.255.255.0` と正しく出力されることを確認します。

---

### ラボ 2: Python `json.dumps()` による RESTCONF インターフェイス追加用 Payload 生成

* **问题:** RESTCONF リクエスト送信前に、Python 辞書オブジェクトをインデントされた整形済み JSON 文字列にシリアライズし、ローカルファイル `payload.json` に書き出すスクリプトを作成しなさい。
* **要件:**
  1. `Loopback200` インターフェイス（IP: `172.16.200.1/32`、説明: `"Automation Test"`）の構造を定義すること。
  2. `json.dumps()` の `indent=2` パラメータを使用して整形すること。
* **設定例（Python スクリプト）:**

```python
import json

payload_data = {
    "ietf-interfaces:interface": {
        "name": "Loopback200",
        "description": "Automation Test",
        "type": "iana-if-types:softwareLoopback",
        "enabled": True,
        "ietf-ip:ipv4": {
            "address": [
                {
                    "ip": "172.16.200.1",
                    "netmask": "255.255.255.255"
                }
            ]
        }
    }
}

# インデント2でシリアライズ
json_formatted_str = json.dumps(payload_data, indent=2)

# ファイルに書き出し
with open("payload.json", "w", encoding="utf-8") as f:
    f.write(json_formatted_str)

print("payload.json generated successfully.")
print(json_formatted_str)
```

* **検証方法:**
  生成された `payload.json` の中身を確認し、`"enabled": true`（小文字のブール値）やダブルクォートが正しく出力されているか確認します。

---

### ラボ 3: `jq` コマンドを用いた Cisco Catalyst Center デバイスリストフィルタリング

* **問題:** Cisco Catalyst Center REST API から受領したデバイスインベントリ JSON から、`family` が `"Switches and Hubs"` であるデバイスの `hostname` と `managementIpAddress` のみを抽出し、JSON オブジェクトのリストとして表示する `jq` コマンドを作成しなさい。
* **要件:**
  1. `jq` の `.response[]` 配列をイテレートすること。
  2. `select(.family == "Switches and Hubs")` 条件フィルタを使用すること。
* **設定例（入力 JSON と jq コマンド）:**

```bash
# 入力用 sample_devices.json
cat << 'EOF' > sample_devices.json
{
  "response": [
    {
      "hostname": "Cat9300-Core1",
      "managementIpAddress": "10.10.10.1",
      "family": "Switches and Hubs",
      "platformId": "C9300-48U"
    },
    {
      "hostname": "ISR4451-Edge1",
      "managementIpAddress": "10.10.10.254",
      "family": "Routers",
      "platformId": "ISR4451/K9"
    },
    {
      "hostname": "Cat9300-Access1",
      "managementIpAddress": "10.10.20.11",
      "family": "Switches and Hubs",
      "platformId": "C9300-24T"
    }
  ]
}
EOF

# jq コマンドの実行
jq '.response[] | select(.family == "Switches and Hubs") | {hostname: .hostname, ip: .managementIpAddress}' sample_devices.json
```

* **検証方法:**
  コマンドを実行し、`Cat9300-Core1` と `Cat9300-Access1` の情報のみが抽出されることを確認します。

---

### ラボ 4: RESTCONF (`curl`) を用いた IETF Interface 状態の JSON 取得と更新

* **問題:** `curl` コマンドを使用して、Cisco IOS XE ルータの `Loopback100` インターフェイスの説明（Description）を RESTCONF JSON PATCH リクエストで更新しなさい。
* **要件:**
  1. `HTTP PATCH` メソッドを使用すること。
  2. `Content-Type: application/yang-data+json` ヘッダーを指定すること。
* **設定例（実行コマンド）:**

```bash
# 送信用 JSON ペイロード patch_desc.json の作成
cat << 'EOF' > patch_desc.json
{
  "ietf-interfaces:interface": {
    "name": "Loopback100",
    "description": "Updated via RESTCONF PATCH Method"
  }
}
EOF

# RESTCONF PATCH リクエスト実行
curl -i -k -X PATCH \
  -u "admin_user:auth_secret" \
  -H "Content-Type: application/yang-data+json" \
  -H "Accept: application/yang-data+json" \
  -d @patch_desc.json \
  https://router.example.com/restconf/data/ietf-interfaces:interfaces/interface=Loopback100
```

* **検証方法:**
  HTTP 応答ステータスコードが `204 No Content` または `200 OK` で返ることを確認し、GET リクエストで Description が更新されているか検証します。

---

### ラボ 5: Cisco SD-WAN vManage REST API (Token 認証 ＋ Feature Template JSON 制御)

* **問題:** Cisco SD-WAN vManage REST API に対して認証を行い、X-XSRF-TOKEN を取得した上で、テンプレート一覧 JSON を取得する Python スクリプトのスケルトンを作成しなさい。
* **要件:**
  1. Session オブジェクト（`requests.Session()`）を使用して クッキーを保持すること。
  2. X-XSRF-TOKEN をヘッダーにセットすること。
* **設定例（Python スクリプト）:**

```python
import requests
import json
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

vmanage_ip = "192.168.1.100"
base_url = f"https://{vmanage_ip}"

session = requests.Session()

# 1. 認証リクエスト
login_url = f"{base_url}/j_security_check"
login_data = {'j_username': 'admin', 'j_password': 'vManagePassword123!'}
login_resp = session.post(login_url, data=login_data, verify=False)

# 2. X-XSRF-TOKEN 取得
token_url = f"{base_url}/dataservice/client/token"
token_resp = session.get(token_url, verify=False)
token = token_resp.text

# セッションヘッダーにトークンをセット
session.headers.update({'X-XSRF-TOKEN': token})

# 3. テンプレート一覧取得 (JSON)
template_url = f"{base_url}/dataservice/template/feature"
template_resp = session.get(template_url, verify=False)

if template_resp.status_code == 200:
    templates_json = template_resp.json() # .json() メソッドで直接デシリアライズ
    print(f"Total Templates: {len(templates_json.get('data', []))}")
    print(json.dumps(templates_json['data'][0], indent=2))
```

* **検証方法:**
  スクリプトを実行し、vManage からテンプレート一覧の先頭要素 JSON が正しく取得・出力されることを確認します。


### ラボ 6: Python `requests` ＋ JSON による Cisco DNA Center 認証 (Token 取得) と Device Query

* **問題:** Cisco DNA Center (Catalyst Center) REST API に対し、Basic 認証で Token を取得し、その Token を使用してネットワークデバイスリストを取得・表示する Python スクリプトを作成しなさい。
* **要件:**
  1. `POST /dna/system/api/v1/auth/token` から JSON レスポンスを受取ること。
  2. `"Token"` キーの値を抽出し、以降のリクエストの `X-Auth-Token` ヘッダーに付与すること。
* **設定例（Python スクリプト）:**

```python
import requests
from requests.auth import HTTPBasicAuth
import json

dnac_ip = "10.10.10.100"
auth = HTTPBasicAuth("dnac_admin", "auth_secret")
headers = {"Content-Type": "application/json", "Accept": "application/json"}

# 1. Auth Token 取得
auth_url = f"https://{dnac_ip}/dna/system/api/v1/auth/token"
response = requests.post(auth_url, auth=auth, headers=headers, verify=False)
token = response.json().get("Token")

print(f"Acquired Auth Token: {token[:20]}...")

# 2. デバイスリスト取得
device_url = f"https://{dnac_ip}/dna/intent/api/v1/network-device"
auth_headers = {
    "X-Auth-Token": token,
    "Content-Type": "application/json",
    "Accept": "application/json"
}

device_resp = requests.get(device_url, headers=auth_headers, verify=False)
devices = device_resp.json().get("response", [])

for dev in devices:
    print(f"Host: {dev.get('hostname')} | IP: {dev.get('managementIpAddress')} | Platform: {dev.get('platformId')}")
```

---

### ラボ 7: YANG データモデル (`ietf-interfaces`) に完全準拠した RESTCONF JSON Payload の作成

* **問題:** `ietf-interfaces.yang` および `ietf-ip.yang` データモデルに完全準拠した、`GigabitEthernet2` インターフェイス有効化（`enabled: true`）および IPv4 アドレス（`10.0.0.1/24`）設定用の JSON ファイル `ge2_config.json` を作成しなさい。
* **要件:**
  1. ネームスペース `"ietf-interfaces:interface"` および `"ietf-ip:ipv4"` を正確に記述すること。
  2. `address` を要素とするリスト（JSON アレイ `[]`）として定義すること。
* **設定例（JSON ファイル）:**

```json
{
  "ietf-interfaces:interface": {
    "name": "GigabitEthernet2",
    "description": "Configured via RESTCONF JSON Payload",
    "type": "iana-if-types:ethernetCsmacd",
    "enabled": true,
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "10.0.0.1",
          "netmask": "255.255.255.0"
        }
      ]
    }
  }
}
```

---

### ラボ 8: Python での JSON スキーマ (`jsonschema`) によるデータ構造バリデーション演習

* **問題:** 送信前の JSON データが規定されたスキーマ（必須フィールド、データ型制限）を満たしているか、Python の `jsonschema` ライブラリを用いて検証するプログラムを作成しなさい。
* **要件:**
  1. `name` (string), `vlan_id` (integer 1-4094), `active` (boolean) を定義する JSON スキーマを作成すること。
  2. 不正なデータが与えられた場合に `ValidationError` を捕捉すること。
* **設定例（Python スクリプト）:**

```python
import jsonschema
from jsonschema import validate, ValidationError

# スキーマ定義
vlan_schema = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "vlan_id": {"type": "integer", "minimum": 1, "maximum": 4094},
        "active": {"type": "boolean"}
    },
    "required": ["name", "vlan_id", "active"]
}

# テスト用 JSON データ
valid_vlan_data = {"name": "GUEST_VLAN", "vlan_id": 100, "active": True}
invalid_vlan_data = {"name": "BAD_VLAN", "vlan_id": 5000, "active": "true"}

def check_json(data):
    try:
        validate(instance=data, schema=vlan_schema)
        print(f"Data {data['name']} is VALID.")
    except ValidationError as e:
        print(f"Data Validation FAILED: {e.message}")

check_json(valid_vlan_data)
check_json(invalid_vlan_data)
```

---

### ラボ 9: 大規模 JSON レスポンスからのネスト構造辞書・リスト探査と例外処理 (`KeyError` / `IndexError` 回避)

* **問題:** REST API から返される不規則でネストされた JSON 構造から、例外（`KeyError`, `IndexError`）を一切発生させずに安全にデータを取り出す堅牢な関数 `get_safe_value()` を作成しなさい。
* **要件:**
  1. ネストされた辞書およびリストを再帰的または安全に探査すること。
  2. キーが存在しない場合やインデックス範囲外の場合は指定したデフォルト値を返すこと。
* **設定例（Python スクリプト）:**

```python
complex_json_data = {
    "status": "success",
    "data": {
        "devices": [
            {
                "id": "DEV01",
                "interfaces": [
                    {"name": "Gi1", "ip": "10.1.1.1"}
                ]
            },
            {
                "id": "DEV02"
            }
        ]
    }
}

def get_interface_ip_safe(data, device_index):
    try:
        devices = data.get("data", {}).get("devices", [])
        device = devices[device_index]
        interfaces = device.get("interfaces", [])
        if interfaces:
            return interfaces[0].get("ip", "No IP Configured")
        return "No Interface Found"
    except (IndexError, TypeError, AttributeError):
        return "Invalid Data Structure"

print("Dev0 IP:", get_interface_ip_safe(complex_json_data, 0))
print("Dev1 IP:", get_interface_ip_safe(complex_json_data, 1))
print("Dev2 IP:", get_interface_ip_safe(complex_json_data, 2))
```

---

### ラボ 10: JSON データファイルを用いた Python Jinja2 テンプレートからの Cisco IOS XE コンフィグ動的生成

* **問題:** ネットワークパラメータが定義された `network_vars.json` ファイルを読み込み、Jinja2 テンプレートをレンダリングして Cisco IOS XE インターフェイス設定コマンド（CLI）を自動生成する Python スクリプトを作成しなさい。
* **要件:**
  1. `json.load()` を使用して JSON ファイルを読み込むこと。
  2. Jinja2 の `for` ループで複数のインターフェイス設定コマンドを生成すること。
* **設定例（JSON ファイル、Python スクリプト）:**

```json
{
  "hostname": "Core-RTR-01",
  "interfaces": [
    {
      "name": "GigabitEthernet1",
      "description": "Uplink to ISP",
      "ip": "203.0.113.1",
      "mask": "255.255.255.252"
    },
    {
      "name": "GigabitEthernet2",
      "description": "LAN Gateway",
      "ip": "192.168.10.1",
      "mask": "255.255.255.0"
    }
  ]
}
```

```python
import json
from jinja2 import Template

template_str = """
hostname {{ hostname }}
!
{% for iface in interfaces %}
interface {{ iface.name }}
 description {{ iface.description }}
 ip address {{ iface.ip }} {{ iface.mask }}
 no shutdown
!
{% endfor %}
"""

with open("network_vars.json", "r", encoding="utf-8") as f:
    vars_data = json.load(f)

template = Template(template_str)
rendered_cli = template.render(vars_data)

print(rendered_cli)
```


## ❓ 想定試験問題

### 問 1 (コンフィグ読解)
以下の JSON ペイロードを Cisco IOS XE RESTCONF API に送信したところ、エラーが返された。エラーの原因として最も適切なものを選択しなさい。

```json
{
  "ietf-interfaces:interface": {
    "name": "Loopback10",
    "description": "Test Interface",
    "enabled": "true",
    "type": "iana-if-types:softwareLoopback",
  }
}
```

A. `"name"` フィールドのダブルクォートが不要である。  
B. `"enabled"` の値が文字列 (`"true"`) となっており、YANG のブール型と一致しない。また末尾に不要なカンマが存在する。  
C. `"ietf-interfaces:interface"` ネームスペースの記述方法が不適切である。  
D. `type` フィールドは JSON ではサポートされていない。

* **正解:** B  
* **解説:** YANG スキーマ上 `enabled` は boolean 型であり、JSON では引用符なしの小文字 `true` として記述する必要があります。また、`"type"` 行の末尾にある不要なカンマ（Trailing Comma）も JSON の文法違反です。

---

### 問 2 (トラブルシューティング)
Python の `requests` ライブラリを使用して RESTCONF API にリクエストを送信したところ、レスポンスコード `415 Unsupported Media Type` が返された。この問題を解決するための最も適切な対処法はどれか。

A. `requests.get()` の引数に `verify=False` を追加する。  
B. HTTP リクエストヘッダーに `Content-Type: application/yang-data+json` を設定する。  
C. URL のプレフィックスを `http://` から `https://` に変更する。  
D. JSON ペイロード内のキー名をすべて小文字に変更する。

* **正解:** B  
* **解説:** ステータスコード `415 Unsupported Media Type` は、サーバーが要求されたメディアタイプ（Payload 形式）を理解またはサポートできない場合に発生します。RESTCONF で JSON 送信する際は、ヘッダーに `Content-Type: application/yang-data+json` を明示する必要があります。

---

### 問 3 (Design)
ネットワーク自動化アーキテクチャの設計において、Ansible Playbook、RESTCONF API、および Cisco DNA Center REST API を統合運用する場合のエンコーディング形式の組み合わせとして最も適切なものはどれか。

A. Ansible: XML, RESTCONF: JSON, DNA Center: YAML  
B. Ansible: YAML, RESTCONF: JSON または XML, DNA Center: JSON  
C. Ansible: JSON, RESTCONF: YAML, DNA Center: XML  
D. すべてのツールで XML のみが使用可能。

* **正解:** B  
* **解説:** Ansible Playbook は YAML 形式で記述します。RESTCONF は JSON (`application/yang-data+json`) と XML (`application/yang-data+xml`) の双方に対応しています。Cisco DNA Center (Catalyst Center) REST API は JSON (`application/json`) を標準採用しています。

---

### 問 4 (実装)
Python において、API から受領したレスポンス JSON 文字列 `response_text` をパースし、辞書型オブジェクト `data` に変換するための正解コードはどれか。

A. `data = json.dumps(response_text)`  
B. `data = json.loads(response_text)`  
C. `data = json.load(response_text)`  
D. `data = json.stringify(response_text)`

* **正解:** B  
* **解説:** 文字列（String）から Python オブジェクトへの変換には `json.loads()`（末尾 s あり）を使用します。`dumps` は逆方向のシリアライズ、`load` はファイルオブジェクトからの読み込みです。

---

### 問 5 (トラブルシューティング)
`jq` コマンドを使用して JSON レスポンスから特定要素を抽出する際、キー名にハイフンや特殊記号が含まれる場合（例: `ietf-interfaces:interface`）の正しいブラケット参照構文はどれか。

A. `jq .ietf-interfaces:interface data.json`  
B. `jq .["ietf-interfaces:interface"] data.json`  
C. `jq .'ietf-interfaces:interface' data.json`  
D. `jq .{ietf-interfaces:interface} data.json`

* **正解:** B  
* **解説:** キー名にコロン（`:`）やハイフン（`-`）が含まれる場合、ドット記法 `.key` では構文エラーとなるため、`["key_name"]` のようにダブルクォートで括ったブラケット記法を使用する必要があります。


## 🔗 参考リソース

* [RFC 8259 - The JavaScript Object Notation (JSON) Data Interchange Format]
* [RFC 7951 - JSON Encoding of Data Modeled with YANG]
* [RFC 8040 - RESTCONF Protocol]
* [Cisco DevNet Learning Labs - RESTCONF with Cisco IOS XE]
* [Cisco Catalyst Center REST API Documentation]
* [Python Documentation - json module]
* [jq Manual - Command-line JSON processor]

---

## 📝 補足（Notes）

### 1. Python `dict` の文字列表現と JSON 文字列の決定的な違い

初心者やトラブルシューティング問題で最も遭遇しやすいミスが、Python の `print(my_dict)` で表示された文字列をそのまま JSON だと思い込んでしまうことです。

```python
python_dict = {"enabled": True, "name": "Gi1"}
# Pythonの文字列表現: "{'enabled': True, 'name': 'Gi1'}"
# -> シングルクォート、True（先頭大文字）であり、JSONとしては不格好・構文違反！

json_string = json.dumps(python_dict)
# 正しいJSON文字列: '{"enabled": true, "name": "Gi1"}'
# -> ダブルクォート、true（小文字）に正しく変換される！
```

### 2. JSON のデバッグチェックリスト

API 通信やスクリプトでエラーが発生した場合は、以下のチェックリストを順に確認してください。

1. **すべての文字列およびキーがダブルクォート `"` で囲まれているか？**
2. **オブジェクトやアレイの末尾（最後の要素）に余計なカンマ `,` が残っていないか？**
3. **ブール値はすべて小文字 (`true` / `false`) になっているか？**
4. **カッコのペア (`{}` と `[]`) の対応・閉じ忘れはないか？**
5. **RESTCONF の場合、YANG モジュール名のプレフィックス（`ietf-interfaces:` など）が付与されているか？**



