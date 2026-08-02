---
layout: default
title: 4.4.b-Classification
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.4.b Classification, Trust Boundary

本ページでは、QoS（Quality of Service）の基盤となる「分類（Classification）」と「トラスト境界（Trust Boundary）」について、CCIE Enterprise Infrastructure (EI) v1.1の試験範囲に基づき詳述します。

---

## 📘 概要

QoSの実装において、**分類（Classification）**は最も初期に行われる重要なステップです。これは、ネットワークを通過する多種多様なトラフィックを、特定の基準（IPアドレス、プロトコル、アプリケーションの種類など）に基づいてグループ化するプロセスを指します。

**トラスト境界（Trust Boundary）**は、デバイスが受信したパケットのQoSマーキング（CoSやDSCPなど）を「信頼」してそのまま受け入れるか、あるいは「信頼せず」に書き換えるかを決定するネットワーク上の物理的・論理的な場所を指します。一般的に、エンタープライズネットワークではアクセス層のスイッチがこの境界となり、エンドポイントからのマーキングを制御します。

---

## 🔑 要点

### 1. トラフィックの分類（Classification）

分類は主に **MQC (Modular QoS CLI)** フレームワークを使用して構成されます。
*   **レイヤ2分類:** 802.1Qヘッダー内の **CoS (Class of Service)** 値を使用します。
*   **レイヤ3分類:** IPv4/IPv6ヘッダー内の **DSCP (Differentiated Services Code Point)** または **IP Precedence** 値を使用します。
*   **NBAR2 (Network-Based Application Recognition):** L4-L7の深いパケットインスペクションを行い、特定のURLやアプリケーション（例：YouTube, HTTPの特定拡張子）を識別します。
*   **ACLベース:** 送信元/宛先IP、ポート番号に基づいて分類します。

### 2. トラスト境界（Trust Boundary）の設計

*   **信頼済みエンドポイント:** IP電話やビデオ会議端末など、正当なQoSマーキングを行うデバイスが接続されるポートでは、マーキングを維持（Trust）します。
*   **未信頼エンドポイント:** PCや一般的なホストが接続されるポートでは、不正な優先制御を防ぐためにマーキングをリセット（Untrust）または再分類します。
*   **条件付き信頼:** 特定のCDP/LLDP情報を検知した場合のみ信頼を有効にする構成も一般的です。

### 3. MQCのコンポーネント

*   **Class-map:** トラフィックのマッチング条件を定義します。
*   **Policy-map:** 分類されたクラスに対するアクション（マーキング、ポリシング等）を定義します。
*   **Service-policy:** インターフェイスにポリシーを適用します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純な設定ではなく、特定のビジネス要件をいかに論理的にQoSポリシーへ変換できるかが問われます。

### 1. NBARを用いた複雑なマッチング

「HTTPトラフィックの中でも、特定のホスト名やファイル拡張子（.jpg, .gifなど）を含むものだけを個別に分類せよ」といった要件が出題されます。`match protocol http url` や `match protocol http host` コマンドの正確な構文をマスターしておく必要があります。

### 2. match-all と match-any の使い分け

*   **match-all (デフォルト):** 定義された「すべての」条件に一致する必要があります。
*   **match-any:** いずれか「一つの」条件に一致すれば分類されます。
試験では、この論理演算の選択ミスが致命的な失点につながるため、要件を慎重に読み取る必要があります。

### 3. トラスト境界の移動

「アクセススイッチのGi1/0/1ではCoSを信頼し、それをDSCPにマッピングせよ」といった、レイヤ間の変換を伴うトラスト境界の構成が問われます。

### 4. 検証の徹底

`show policy-map interface` を実行し、各クラスでパケットのヒットカウントが増加しているかを確認することが、実装の正しさを証明する唯一の手段です。

---

## 🛠 設定・検証コマンド

### 分類の設定 (MQC)

| 目的 | コマンド |
| :--- | :--- |
| **クラスマップの作成** | <code>class-map [match-all &#124; match-any] [CLASS_NAME]</code> |
| **DSCP値によるマッチング** | <code>match ip dscp [VALUE]</code> |
| **ACLによるマッチング** | <code>match access-group name [ACL_NAME]</code> |
| **プロトコル(NBAR)によるマッチング** | <code>match protocol [PROTOCOL]</code> |
| **HTTP URLによるマッチング** | <code>match protocol http url "[STRING]"</code> |

### トラスト境界・適用設定

| 目的 | コマンド |
| :--- | :--- |
| **DSCP値を信頼する(スイッチ)** | <code>(config-if)# qos trust dscp</code> |
| **ポリシーの適用(入力方向)** | <code>(config-if)# service-policy input [POLICY_NAME]</code> |
| **条件付き信頼(IP電話検知時)** | <code>(config-if)# trust device cisco-phone</code> |

### 検証・統計確認

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスごとのQoS統計** | <code>show policy-map interface [INTERFACE]</code> |
| **NBARのプロトコル検出状態確認** | <code>show ip nbar protocol-discovery</code> |
| **クラスマップの構成表示** | <code>show class-map [NAME]</code> |
| **プラットフォームのQoS詳細確認** | <code>show platform qos advanced ...</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 特定の画像ファイルダウンロードの分類 (NBAR)

**【問題】** HTTPでダウンロードされる ".gif" または ".jpg" ファイルを特定クラスに分類せよ。
```ios
class-map match-any CM-WEB-IMAGES
 match protocol http url "*.gif"
 match protocol http url "*.jpg"
```

### 2. DSCP値に基づく多重分類

**【問題】** DSCP AF21, AF31, および EF をそれぞれ個別のクラスに分類せよ。
```ios
class-map match-any GOLD
 match ip dscp ef
class-map match-any SILVER
 match ip dscp af31
class-map match-any BRONZE
 match ip dscp af21
```

### 3. ACLを用いた管理トラフィックの抽出

**【問題】** 特定の管理セグメント (10.1.1.0/24) からの Telnet 通信を分類せよ。
```ios
ip access-list extended ACL-MGMT-TELNET
 permit tcp 10.1.1.0 0.0.0.255 any eq 23
!
class-map match-all CM-MGMT
 match access-group name ACL-MGMT-TELNET
```

### 4. トラスト境界の最小構成

**【問題】** インターフェイス Gi1/0/1 において、着信パケットの DSCP 値を信頼せよ。
```ios
interface GigabitEthernet1/0/1
 qos trust dscp
```

### 5. NBARによる特定ホストへのアクセス分類

**【問題】** "www.cisco.com" 宛のHTTPトラフィックのみを分類せよ。
```ios
class-map match-all CM-CISCO-WEB
 match protocol http host "www.cisco.com"
```

### 6. IPv6 トラフィックの分類

**【問題】** IPv6 の DSCP 値 CS3 を持つパケットを抽出せよ。
```ios
class-map match-all CM-IPV6-CS3
 match ip dscp cs3
 ! 注意: IOS-XEではIPv4/IPv6共通で match ip dscp が使用可能
```

### 7. MACアドレスによるレイヤ2分類

**【問題】** 特定の送信元 MAC アドレスを持つ非IPトラフィックを分類せよ。
```ios
class-map match-all CM-MAC-SRC
 match source-address mac 0011.2233.4455
```

### 8. match-not による例外分類

**【問題】** ICMP 以外のすべてのトラフィックを一つのクラスにまとめよ。
```ios
class-map match-all CM-NOT-ICMP
 match not protocol icmp
```

### 9. IP Precedence への後方互換性マッチング

**【問題】** 優先度「5 (Critical)」が設定されたレガシートラフィックを抽出せよ。
```ios
class-map match-all CM-PREC5
 match ip precedence 5
```

### 10. 入力トラフィックの強制リセット (Untrusted)

**【問題】** トラスト境界において、すべての非優先トラフィックの DSCP を 0 にリセットせよ。
```ios
policy-map PM-UNTRUST
 class class-default
  set ip dscp 0
!
interface Ethernet0/0
 service-policy input PM-UNTRUST
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501) - キャンパスネットワークにおける分類とトラスト境界のベストプラクティス。
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731) - IOS XE デバイスにおける最新のQoS実装。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Quality of Service Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos/configuration/xe-17/qos-xe-17-book.html)。
*   [**Configuring NBAR-Based Classification**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)。

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND)**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)。
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。

---

## 📝 補足
- この学習メモは、QoSの「入り口」である分類とトラストの重要性を整理しています。CCIE実技試験では、**NBARのプロトコル認知**や**ACLとの組み合わせ**が頻出するため、`show policy-map interface` で意図通りに分類されているかを確認する習慣を身につけてください。


