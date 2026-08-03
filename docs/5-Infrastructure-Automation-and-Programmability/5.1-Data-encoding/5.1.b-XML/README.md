---
layout: default
title: 5.1.b-XML
parent: 5.1-Data-encoding
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.1.b XML

本ページでは、ネットワーク自動化とプログラマビリティにおける主要なデータエンコーディング形式の一つである **XML (eXtensible Markup Language)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

**XML (eXtensible Markup Language)** は、データを構造化して記述するためのマークアップ言語です。人間とコンピュータの両方が読みやすいように設計されており、データの意味（タグ）と内容を分離して表現します。

現代のネットワーク管理において、XML は主に **NETCONF (Network Configuration Protocol)** のメッセージ伝送フォーマットとして使用されます。Cisco IOS XE デバイスでは、内部のデータモデルである **YANG** に基づいた構成情報や状態情報を XML 形式でやり取りします。JSON が REST API で好まれるのに対し、XML はより厳格なスキーマ検証や複雑な階層構造の表現に適しており、伝統的なネットワーク自動化の基盤となっています。

---

## 🔑 要点

### 1. XML の基本構造

*   **タグ (Tags):** `<name>`（開始タグ）と `</name>`（終了タグ）で要素を囲みます。
*   **要素 (Elements):** タグとその中身のセットです。要素はネスト（階層化）が可能です。
*   **属性 (Attributes):** 要素に追加情報を付与します（例：`<interface type="Ethernet">`）。
*   **宣言:** 文頭に `<?xml version="1.0" encoding="UTF-8"?>` のような宣言を置くのが一般的です。

### 2. 名前空間 (Namespaces)

NETCONF 通信では、異なるデータモデル（IETF モデル、Cisco 固有モデルなど）の間でタグ名が衝突するのを防ぐため、`xmlns` 属性を使用して名前空間を定義します。
*   例：`<interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">`

### 3. XML の妥当性

*   **Well-formed (整形済み):** 構文ルール（閉じタグの欠落がない、階層が正しい等）に従っている状態。
*   **Valid (妥当):** 特定のスキーマ（DTD や XML Schema）に従って、データの内容が正しいと検証された状態。

### 4. ネットワーク運用における役割

*   **NETCONF:** オペレーション（`<get-config>`、`<edit-config>` 等）およびペイロードの記述に使用。
*   **YANG との親和性:** YANG モデルで定義されたデータ構造を忠実に XML ツリーとして表現可能。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、自動化セクションにおいて XML を「作成する」「解釈する」「フィルタリングする」能力が直接問われます。

### 1. NETCONF フィルタの作成

`<get>` や `<get-config>` を実行する際、デバイスから全ての情報を取得すると非常に重くなります。特定のインターフェイスや特定のルーティングプロトコル情報のみを抽出するための **XML フィルタ** を正確に記述できる必要があります。

### 2. `<edit-config>` ペイロードの構築

新しい設定をデバイスにプッシュする際、正しい名前空間（Namespace）と階層構造（Ancestry）を持った XML ペイロードを作成するスキルが求められます。
*   **ポイント:** YANG モデル（Cisco-IOS-XE-native 等）のツリー構造を意識し、正しい親要素から辿って記述すること。

### 3. Python (ncclient) との連携

Python の NETCONF ライブラリである `ncclient` を使用し、XML 文字列をデバイスに送信するスクリプトの理解が必要です。
*   **注意点:** Python 文字列内での特殊文字のエスケープや、複数行にわたる XML の扱い。

### 4. トラブルシューティング

「設定が反映されない」原因として、XML の名前空間が間違っている、あるいはタグの綴りミス（YANG モデルと不一致）を特定させる問題が想定されます。

---

## 🛠 設定・検証コマンド

Cisco IOS XE デバイス上での XML 関連操作および検証コマンドです。

### デバイス CLI での XML 操作

| 目的 | コマンド |
| :--- | :--- |
| **NETCONF-YANGの有効化** | <code>(config)# netconf-yang</code> |
| **構成情報をXML形式で表示** | <code>show running-config &#124; format xml</code> |
| **特定のshow結果をXML出力** | <code>show ip interface brief &#124; format xml</code> |
| **NETCONF統計の確認** | <code>show netconf-yang statistics</code> |
| **NETCONFセッションの確認** | <code>show netconf-yang sessions</code> |

---

## 🧪 ラボ学習・設定サンプル例

NETCONF 通信や自動化で多用される XML ペイロードの実践例 12 選です。

### 1. 基本的なインターフェイス取得フィルタ

**【課題】** IETF モデルを使用して、デバイスの全インターフェイス情報を取得するためのフィルタ。
```xml
<filter>
  <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"/>
</filter>
```

### 2. 特定のインターフェイス（Gi1）のみを取得

**【課題】** 名前を指定して特定のポートの状態を確認するフィルタ。
```xml
<filter>
  <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces">
    <interface>
      <name>GigabitEthernet1</name>
    </interface>
  </interfaces>
</filter>
```

### 3. ホスト名の設定ペイロード

**【課題】** Cisco Native モデルを使用してホスト名を "CCIE-Router" に変更する。
```xml
<config>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <hostname>CCIE-Router</hostname>
  </native>
</config>
```

### 4. Loopback インターフェイスの作成

**【課題】** IP アドレス 1.1.1.1/32 を持つ Loopback 100 を新規作成する。
```xml
<config>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <interface>
      <Loopback>
        <name>100</name>
        <ip>
          <address>
            <primary>
              <address>1.1.1.1</address>
              <mask>255.255.255.255</mask>
            </primary>
          </address>
        </ip>
      </Loopback>
    </interface>
  </native>
</config>
```

### 5. VLAN の作成

**【課題】** VLAN 101 (Name: Sales) を作成する。
```xml
<config>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <vlan>
      <vlan-list xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-vlan">
        <id>101</id>
        <name>Sales</name>
      </vlan-list>
    </vlan>
  </native>
</config>
```

### 6. 設定の削除 (nc:operation="delete")

**【課題】** 既存の Loopback 100 を削除する（NETCONF 操作属性の使用）。
```xml
<config xmlns:nc="urn:ietf:params:xml:ns:netconf:base:1.0">
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <interface>
      <Loopback nc:operation="delete">
        <name>100</name>
      </Loopback>
    </interface>
  </native>
</config>
```

### 7. BGP 近隣関係の取得

**【課題】** BGP のネイバー状態を確認するためのフィルタ。
```xml
<filter>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <router>
      <bgp/>
    </router>
  </native>
</filter>
```

### 8. SNMP コミュニティの設定

**【課題】** RO コミュニティ "public" を追加する。
```xml
<config>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <snmp-server>
      <community>
        <name>public</name>
        <RO/>
      </community>
    </snmp-server>
  </native>
</config>
```

### 9. スタティックルートの追加

**【課題】** 10.10.10.0/24 へのルートをネクストホップ 192.168.1.1 で設定する。
```xml
<config>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native">
    <ip>
      <route>
        <ip-route-interface-forwarding-list>
          <prefix>10.10.10.0</prefix>
          <mask>255.255.255.0</mask>
          <fwd-list>
            <fwd>192.168.1.1</fwd>
          </fwd-list>
        </ip-route-interface-forwarding-list>
      </route>
    </ip>
  </native>
</config>
```

### 10. インターフェイスの状態（Operational Data）取得

**【課題】** 統計情報を含むインターフェイスの状態データを取得する。
```xml
<get>
  <filter type="subtree">
    <interfaces-state xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"/>
  </filter>
</get>
```

### 11. 複数名前空間の混在

**【課題】** IETF モデルと Cisco モデルを組み合わせて情報を取得する構造。
```xml
<filter>
  <interfaces xmlns="urn:ietf:params:xml:ns:yang:ietf-interfaces"/>
  <native xmlns="http://cisco.com/ns/yang/Cisco-IOS-XE-native"/>
</filter>
```

### 12. XML 宣言とルート要素

**【基本】** NETCONF リクエストの完全な外枠構造。
```xml
<?xml version="1.0" encoding="UTF-8"?>
<rpc message-id="101" xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
  <get-config>
    <source><running/></source>
  </get-config>
</rpc>
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKOPS-2431: Network Automation in Theory and Practice - YANG, NETCONF, RESTCONF**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   YANG モデルからどのように XML が生成されるかを深く理解するための必見セッション。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Automation**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE EI 試験におけるプログラマビリティの重要性と XML の役割。

### Configuration ガイド
*   [**Programmability Configuration Guide, Cisco IOS XE Release 17.x**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg.html)
    *   NETCONF および XML 形式のデータ操作に関する公式実装ガイド。

### テクニカルドキュメント・設定例
*   [**RFC 6241: Network Configuration Protocol (NETCONF)**](https://tools.ietf.org/html/rfc6241)
    *   XML ベースのプロトコル仕様。
*   [**Cisco DevNet: Introduction to YANG Data Models**](https://developer.cisco.com/learning/modules/intro-device-level-interfaces-programmability/yang-data-models-intro/)
    *   XML と YANG のマッピングに関する基礎演習。

---

## 📝 補足
- この学習メモは、CCIE EI 試験において **「NETCONF 通信をパケットレベル・メッセージレベルで正しく構成できるか」** という点に焦点を当てています。ラボ試験では、XML の 1 つのタグの閉じ忘れが自動化タスク全体の失敗を招くため、構造の正確性を常に意識して演習に取り組んでください。


