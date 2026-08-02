---
layout: default
title: 4.4.d-Marking
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 4
---

# 4.4.d Marking DSCP values in IPv4 and IPv6 headers

本ページでは、QoS（Quality of Service）における「マーキング（Marking）」の技術について、CCIE Enterprise Infrastructure (EI) v1.1の試験範囲に基づき詳述します。マーキングは、分類（Classification）されたトラフィックに対して、パケットヘッダー内の特定のフィールドに優先度情報を書き込むプロセスです。

---

## 📘 概要

**マーキング（Marking）**とは、ネットワークトラフィックの各パケットに「色」を付ける作業に例えられます。トラフィックがネットワークの境界（トラスト境界）を通過する際に、その重要度に応じて特定の値をパケットヘッダーに書き込むことで、後続のネットワークデバイスが再分類を行うことなく、迅速にQoSポリシー（優先制御や破棄制御）を適用できるようにします。

IPv4環境ではパケットヘッダーの **ToS（Type of Service）** バイトを、IPv6環境では **Traffic Class** バイトを使用してマーキングを行います。現在、最も一般的に使用されるマーキング基準は **DSCP（Differentiated Services Code Point）** であり、6ビット（0〜63の値）を使用して詳細なクラス分けを実現します。

---

## 🔑 要点

### 1. マーキング対象のフィールド

*   **Layer 3 マーキング:**
    *   **IPv4 ToS / IPv6 Traffic Class:** 8ビットのフィールド。
    *   **IP Precedence:** 上位3ビットを使用（0〜7）。レガシーな方式。
    *   **DSCP:** 上位6ビットを使用（0〜63）。現在の標準。
*   **Layer 2 マーキング:**
    *   **CoS (Class of Service):** 802.1Qタグ内の3ビット（0〜7）。
*   **その他のマーキング:**
    *   **MPLS EXP:** MPLSラベル内の3ビット。
    *   **QoS Group:** ルータ内部でのみ維持される識別子。出力側のポリシー決定に使用されます。

### 2. DSCPの標準的な値（PHB）

*   **Default (0):** Best Effort。
*   **EF (Expedited Forwarding - 46):** 音声トラフィック用。低遅延を保証。
*   **AF (Assured Forwarding):** 4つのクラスと3つのドロップ優先度（計12種類）。
    *   例: AF31 (26), AF41 (34)。
*   **CS (Class Selector):** IP Precedenceとの後方互換用（CS1〜CS7）。

### 3. トラスト境界（Trust Boundary）での動作

パケットが入力されるインターフェイスで、既存のマーキングを「信頼」するか、あるいは定義したポリシーに基づいて「書き換える（Re-marking）」かを決定します。未信頼のポートから届いたパケットは、通常DSCP 0にリセットされます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純なマーキングだけでなく、特定の条件下での「正確な操作」が求められます。

### 1. IPv6に特化したマーキングの要件

試験問題で「IPv6トラフィックに対してのみDSCP値をXXに設定せよ」という制約が出る場合があります。
*   **ポイント:** `class-map` 内で `match protocol ipv6` を併用し、IPv4パケットが誤ってマークされないように構成する必要があります。

### 2. トンネル環境でのマーキング継承

GREやIPsecトンネルを使用する場合、内部パケット（ペイロード）のDSCP値を外部ヘッダーにコピー（TOS Reflection）する設定や、あるいは外部ヘッダーに独自の値をマークする要件が想定されます。

### 3. テーブルマップ（Table Maps）による変換

DSCP値をCoS値に変換したり、特定のDSCP値を別のDSCP値にマッピング（Mutation）したりする際に **Table Map** が使用されます。
*   **CCIEレベルのタスク:** 「特定のDSCP値を受信した際、それを別のDSCP値に付け替えて転送せよ（DSCP Mutation）」といった高度なマッピング。

### 4. 条件付きマーキング（Policingとの組み合わせ）

「1Mbpsを超過したパケットに対してのみ、DSCP値をAF41からAF43に書き換えて（降格させて）転送せよ」といった、ポリシングのアクションとしてのマーキングが頻出します。

---

## 🛠 設定・検証コマンド

### マーキングの設定 (MQC)

| 目的 | コマンド |
| :--- | :--- |
| **DSCP値のセット** | <code>(config-pmap-c)# set ip dscp [VALUE]</code> |
| **IP優先度のセット** | <code>(config-pmap-c)# set ip precedence [VALUE]</code> |
| **IPv6 DSCPのセット** | <code>(config-pmap-c)# set dscp [VALUE]</code> |
| **MPLS EXPのセット** | <code>(config-pmap-c)# set mpls experimental topmost [VALUE]</code> |
| **内部QoS Groupのセット** | <code>(config-pmap-c)# set qos-group [VALUE]</code> |
| **テーブルマップの定義** | <code>(config)# table-map [NAME]</code> |
| **テーブルマップの適用** | <code>(config-pmap-c)# set dscp dscp table [NAME]</code> |

### 検証・統計コマンド

| 目的 | コマンド |
| :--- | :--- |
| **マーキング統計の確認** | <code>show policy-map interface [INTERFACE]</code> |
| **特定のクラスのヒット確認** | <code>show policy-map interface &#124; section [CLASS_NAME]</code> |
| **テーブルマップの確認** | <code>show table-map [NAME]</code> |
| **パケットヘッダーの確認** | <code>debug ip packet [ACL] detail</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な音声トラフィックのマーキング (EF)

**【問題】** プロトコルが RTP である通信に対し、DSCP EF を付与せよ。
```ios
class-map match-all CLASS-VOICE
 match protocol rtp
!
policy-map PM-MARKING
 class CLASS-VOICE
  set ip dscp ef
```

### 2. IPv6専用のマーキング設定

**【問題】** R2からR1へのIPv6 Pingトラフィックに対し、DSCP 20をマークせよ。IPv4は対象外とすること。
```ios
class-map match-all CLASS-IPV6-ONLY
 match protocol ipv6
 match access-group name ACL-V6-ICMP
!
policy-map PM-MARK-V6
 class CLASS-IPV6-ONLY
  set dscp 20
```

### 3. ビジネスクリティカル・アプリのマーキング (AF31)

**【問題】** SQLトラフィックを識別し、DSCP AF31 でマークせよ。
```ios
policy-map TRAFFIC_COLOURING
 class SQL
  set ip dscp af31
```

### 4. 未信頼トラフィックのリセット

**【問題】** どのクラスにも分類されないトラフィックの DSCP 値を 0 にリセットせよ。
```ios
policy-map TRAFFIC_COLOURING
 class class-default
  set ip dscp 0
```

### 5. NBAR2 を用いた URL ベースのマーキング

**【問題】** HTTP 通信のうち、URL に "/iPexpert" を含むトラフィックのみ DSCP AF11 を付与せよ。
```ios
class-map match-all CM-URL-SPECIFIC
 match protocol http url "*iPexpert*"
!
policy-map Serial_Policy_NBAR
 class CM-URL-SPECIFIC
  set ip dscp af11
```

### 6. Layer 2 CoS から Layer 3 DSCP へのマッピング

**【問題】** スイッチのアクセスポートで CoS 5 を受信した際、それを DSCP EF に変換してルータへ送出せよ。
```ios
! スイッチ側での設定例
interface GigabitEthernet1/0/1
 qos trust cos
!
! または policy-map で明示的に変換
policy-map COS-TO-DSCP
 class CLASS-COS5
  set ip dscp ef
```

### 7. MPLS EXP ビットのマーキング

**【問題】** 顧客の DSCP AF41 トラフィックに対し、MPLS 網内で優先されるよう EXP ビット 4 をセットせよ。
```ios
policy-map PE-TO-P-MARKING
 class CUSTOMER-AF41
  set mpls experimental topmost 4
```

### 8. DSCP Mutation (値の書き換え)

**【問題】** 受信した DSCP 24 を 33 に書き換えて内部処理せよ。
```ios
table-map MUTATION-MAP
 from 24 to 33
 default copy
!
policy-map PM-MUTATE
 class class-default
  set dscp dscp table MUTATION-MAP
```

### 9. ポリシングに伴うマーキングの降格 (Markdown)

**【問題】** AF41 を 128kbps まで許可し、超過した場合は COS 0 に書き換えて送信せよ。
```ios
policy-map PM-POLICE-MARK
 class CUSTOMER1
  police cir 128000 bc 1500
   conform-action transmit
   exceed-action set-cos-transmit 0
```

### 10. 管理トラフィック (SSH) のマーキング (CS6)

**【問題】** ルータ自身への SSH 管理通信を最優先するため、DSCP CS6 をマークせよ。
```ios
ip access-list extended ACL-SSH
 permit tcp any any eq 22
!
policy-map PM-MGMT-PROTECT
 class CLASS-SSH
  set ip dscp cs6
```

### 11. IP優先度に基づくアカウンティング

**【問題】** インターフェイス E0/1 で受信するパケットの IP Precedence ごとに統計を取得せよ。
```ios
interface Ethernet0/1
 ip accounting precedence input
!
! 検証
show interfaces ethernet 0/1 accounting
```

### 12. 階層型 QoS (HQoS) における親ポリシーでのマーキング

**【問題】** 全トラフィックを 10Mbps にシェーピングしつつ、その中で特定の重要クラスに DSCP AF21 をマークせよ。
```ios
policy-map CHILD-MARK
 class IMPORTANT
  set ip dscp af21
!
policy-map PARENT-SHAPE
 class class-default
  shape average 10000000
  service-policy CHILD-MARK
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
    *   最新のIOS-XEにおけるQoS実装と、ハードウェアレベルでのマーキングの仕組みを解説。
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
    *   キャンパスネットワークにおけるDSCP設計とトラスト境界のベストプラクティス。

### Configuration ガイド
*   [**QoS: Marking Network Traffic Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_classn/configuration/xe-17/qos-classn-xe-17-book/qos-classn-mrkg-ntwk-trfc.html)。
*   [**Implementing QoS for IPv6 (Technical Reference)**](https://www.cisco.com/c/en/us/td/docs/ios/ipv6/configuration/guide/ip6-qos.html)。

### テクニカルドキュメント・設定例
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。
*   [**DSCP and Precedence Values Reference Table**](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus1000/sw/4_0/qos/configuration/guide/nexus1000v_qos/qos_6dscp_val.pdf)。

---

## 📝 補足
- この学習メモは、CCIE EI試験において「どのトラフィックを」「どの値で」「どのタイミングで」マークすべきかを論理的に整理しています。実技試験では、**`show policy-map interface`** の出力を詳細に分析し、意図したマーキング（`set` アクション）が実際にパケットに適用されているかをパケットカウントで確認する能力が合格への鍵となります。


