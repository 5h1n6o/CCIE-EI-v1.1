---
layout: default
title: 5.1.a-JSON
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.1.a JSON

本ページでは、ネットワークの自動化とプログラマビリティにおいて最も多用されるデータエンコーディング形式である **JSON (JavaScript Object Notation)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

**JSON (JavaScript Object Notation)** は、軽量でテキストベースの、言語に依存しないデータ交換フォーマットです。人間にとって読み書きが容易であり、コンピュータにとってもパース（解析）や生成が容易であるという特徴があります。

現代のネットワーク運用において、JSON は主に以下の場面で使用されます：
*   **REST API の通信:** Cisco DNA Center や vManage (Cisco SD-WAN) とのやり取りにおける標準的なペイロード形式です。
*   **モデル駆動型テレメトリ:** デバイスからストリーミングされるデータのエンコーディング形式の一つとして利用されます。
*   **モダンな CLI 出力:** Cisco IOS XE 等の最新のネットワーク OS では、従来のテキスト形式の出力を JSON 形式に変換して表示することが可能です。

CCIE ラボ試験においては、単なる知識としてではなく、プログラム（Python）やツール（Postman）を用いて、正確な JSON データを構築・解釈する能力が問われます。

---

## 🔑 要点

JSON の構造は、非常にシンプルなルールに基づいています。

### 1. 基本的な構文

*   **オブジェクト (Object):** 波括弧 `{ }` で囲まれた「キーと値のペア」の集合です。
*   **配列 (Array):** 角括弧 `[ ]` で囲まれた「値」のリストです。
*   **キー (Key):** 必ずダブルクォート `" "` で囲まれた文字列である必要があります。
*   **値 (Value):** 以下のいずれかのデータ型をとります。
    *   文字列 (String) : `"Cisco"`
    *   数値 (Number) : `100`, `3.14`
    *   オブジェクト : `{ ... }`
    *   配列 : `[ ... ]`
    *   真偽値 (Boolean) : `true`, `false`
    *   空値 : `null`

### 2. データ構造のネスト

JSON は、オブジェクトの中にオブジェクトを、あるいは配列の中にオブジェクトを入れるといった「入れ子（ネスト）」構造をサポートしており、複雑なネットワーク構成（例：インターフェイスの詳細リスト）を階層的に表現できます。

### 3. YANG モデルとの関係

Cisco デバイスの内部データモデルである **YANG** は、NETCONF では XML を使用しますが、RESTCONF では JSON を使用してエンコードされるのが一般的です（RFC 7951）。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、自動化セクション（15%）において JSON の正確なハンドリングが合格の鍵となります。

### 1. ペイロード構築の「正確性」

REST API を使用して設定を変更する際、1 つのカンマの欠落や、シングルクォート（不許可）の使用によって API コールが失敗します。
*   **注意点:** リストの最後の要素の後にカンマを置かない（Trailing Comma はエラーの原因となります）。

### 2. Python でのパースと加工

Python の `json` ライブラリを使用して、API から受け取った JSON 文字列を Python の辞書型（Dictionary）に変換し、特定のデータを抽出する操作が頻出します。
*   `json.loads()`: 文字列から Python オブジェクトへ。
*   `json.dumps()`: Python オブジェクトから JSON 文字列へ。

### 3. DNA Center / vManage API との連携

「DNA Center からデバイス一覧を取得し、特定のデバイス ID を抽出して、そのデバイスに対して JSON ペイロードを送信して設定を変更せよ」といった一連の流れを Python requests ライブラリで行う能力が求められます。

### 4. フィルタリングと制限 (Offset/Limit)

大規模なネットワークデータを取得する際、JSON 応答が巨大になるのを防ぐために `offset`（開始位置）や `limit`（取得数）といったクエリパラメータと組み合わせて JSON を扱う設計上の配慮も重要です。

---

## 🛠 設定・検証コマンド

Cisco IOS XE デバイス上、および管理ツール・プログラミング環境での操作例です。

### デバイス CLI での確認

| 目的 | コマンド |
| :--- | :--- |
| **構成情報をJSON形式で表示** | <code>show running-config &#124; format json</code> |
| **特定のshow結果をJSONで出力** | <code>show ip interface brief &#124; format json</code> |
| **RESTCONFサービスの有効化** | <code>(config)# restconf</code> |

### Python プログラミング環境

| 目的 | コード・モジュール例 |
| :--- | :--- |
| **jsonライブラリのロード** | <code>import json</code> |
| **JSON文字列を辞書に変換** | <code>py_dict = json.loads(json_data)</code> |
| **Python辞書をJSON文字列化** | <code>json_str = json.dumps(py_dict, indent=4)</code> |
| **API経由での送信(Requests)** | <code>requests.post(url, json=payload, headers=headers)</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. DNA Center 認証用ペイロード (Basic Auth)

**【課題】** DNA Center への認証トークン取得に必要な JSON 構造を理解せよ。
*注意: 認証時は通常 JSON ペイロードではなく HTTP Header を使用しますが、ユーザー管理 API 等では以下を使用します。*
```json
{
  "username": "admin",
  "password": "Cisco123!"
}
```

### 2. VLAN 作成 (Cisco DNA Center API)

**【課題】** サイトに対して VLAN 101 (Name: Users) を追加するためのペイロード。
```json
{
  "vlanName": "Users",
  "vlanId": 101,
  "vlanType": "DATA"
}
```

### 3. インターフェイスの説明更新 (RESTCONF)

**【課題】** IETF-Interfaces モデルに従って、Gi1 の説明文を更新する。
```json
{
  "ietf-interfaces:interface": {
    "name": "GigabitEthernet1",
    "description": "Configured via RESTCONF"
  }
}
```

### 4. 複数のスタティックルート一括設定

**【課題】** 配列（Array）を使用して、複数のルートを一つのペイロードにまとめる。
```json
{
  "routes": [
    {
      "destination": "10.1.1.0",
      "mask": "255.255.255.0",
      "next-hop": "192.168.1.1"
    },
    {
      "destination": "10.2.2.0",
      "mask": "255.255.255.0",
      "next-hop": "192.168.1.2"
    }
  ]
}
```

### 5. vManage デバイス・テンプレートの変数 (YAMLからJSONへの変換想定)

**【課題】** SD-WAN cEdge のシステム IP とサイト ID を指定する JSON。
```json
{
  "system-ip": "1.1.1.1",
  "site-id": "100",
  "host-name": "Branch-1"
}
```

### 6. ネストされたデバイス情報の解析

**【課題】** DNA Center の `/network-device` 応答から特定情報を抽出する構造。
```json
{
  "response": [
    {
      "hostname": "R1",
      "managementIpAddress": "10.10.10.1",
      "platformId": "C9300-24UX"
    }
  ]
}
```
*Python操作例: `data['response']['managementIpAddress']`*

### 7. BGP ネイバー構成 (RESTCONF)

**【課題】** 特定の AS 番号と Peer IP を指定する。
```json
{
  "Cisco-IOS-XE-bgp:neighbor": {
    "remote-as": 65001,
    "description": "Peer_with_R2"
  }
}
```

### 8. SNMP コミュニティの設定

**【課題】** 読み取り専用 (RO) のコミュニティ名 "public" を設定する。
```json
{
  "snmp-server": {
    "community": [
      {
        "name": "public",
        "permission": "ro"
      }
    ]
  }
}
```

### 9. 複雑な配列構造 (Loopbackのリスト)

**【課題】** デバイス上の全ての Loopback インターフェイスを取得した際のリスト構造。
```json
[
  {"name": "Loopback0", "ip": "1.1.1.1"},
  {"name": "Loopback1", "ip": "2.2.2.2"}
]
```

### 10. API エラーレスポンスの解釈

**【課題】** 設定失敗時に返されるエラー JSON を読み解く。
```json
{
  "errors": {
    "error": [
      {
        "error-message": "Invalid value for 'vlan-id'",
        "error-tag": "invalid-value"
      }
    ]
  }
}
```

### 11. Python での JSON 出力 (整形)

**【課題】** スクリプト内でログを保存する際、`indent` を使用して整形する。
```python
import json
data = {"status": "success", "devices_updated": 5}
print(json.dumps(data, indent=4))
```

### 12. JSON 構文エラーのトラブルシューティング (Bad Case)

**【課題】** 以下の誤りを見つけよ。
```json
{
  "hostname": 'R1',  // 誤り: シングルクォートは不可
  "vlan": 10         // 誤り: 最後の要素にカンマがないのは正しいが、コメント//は不可
}
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKCRT-1385: The CCIE in an SDN World - Programmability Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
*   [**BRKOPS-2431: Network Automation in Theory and Practice - YANG and Telemetry**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
*   [**DEVNET-1047: Migration to Next-Gen Network with Automation First Approach**](https://www.ciscolive.com/global/on-demand-library.html?search=DEVNET-1047)

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Programmability Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg.html)
*   [**Cisco DNA Center API Reference**](https://developer.cisco.com/docs/dna-center/)

### テクニカルドキュメント・設定例
*   [**RFC 7951: JSON Encoding of Data Modeled with YANG**](https://tools.ietf.org/html/rfc7951)
*   [**Introduction to Cisco SD-WAN REST API**](https://developer.cisco.com/docs/sdwan/)

---
## 📝 補足
- この学習メモは、CCIE EI ラボ試験において **「プログラムが理解できる形式で、いかに正確にインフラを定義するか」** というスキルの習得を目的としています。JSON の文法ミスは自動化タスクにおける致命的な失点に繋がるため、日頃から `json.loads()` 等での検証を習慣づけてください。


