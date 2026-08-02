---
layout: default
title: 4.4.h-MQC
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 8
---

# 4.4.h End-to-end Layer 3 QoS using MQC

本ページでは、Cisco IOS XE における QoS 実装のデファクトスタンダードである **MQC (Modular QoS CLI)** を使用した、エンドツーエンドのレイヤ 3 QoS 設計と実装について詳述します。CCIE Enterprise Infrastructure (EI) v1.1 において、QoS は単一デバイスの設定にとどまらず、キャンパスから WAN、データセンターに至るまでのトラフィックの一貫した優先制御が求められます。

---

## 📘 概要

**End-to-end Layer 3 QoS** とは、パケットが送信元から宛先に至るすべてのネットワークホップにおいて、意図した優先順位（PHB: Per-Hop Behavior）で処理される仕組みを指します。これを実現するための中核となるのが **MQC (Modular QoS CLI)** フレームワークです。

MQC は、以下の 3 つの要素を分離して定義することで、柔軟で再利用性の高い QoS ポリシーの構築を可能にします。
1.  **Class-map (分類):** どのトラフィックを対象にするか（Match 条件）。
2.  **Policy-map (アクション):** 分類されたトラフィックをどう処理するか（Set, Priority, Bandwidth, Police 等）。
3.  **Service-policy (適用):** どのインターフェイスのどの方向（Input/Output）に適用するか。

エンドツーエンドの観点では、ネットワーク境界（アクセス層）でレイヤ 3 の **DSCP (Differentiated Services Code Point)** 値をマークし、コアネットワークや WAN を通じてその値を「信頼（Trust）」して転送し続ける設計が基本となります。

---

## 🔑 要点

### 1. MQC の 3 段構成

*   **分類 (Classification):** `class-map` を使用。ACL、DSCP 値、IP Precedence、あるいは NBAR (Network-Based Application Recognition) による L7 識別を組み合わせてトラフィックを定義します。
*   **ポリシー定義 (Policy-map):** `policy-map` 内で、クラスごとに帯域保証 (`bandwidth`)、低遅延キューイング (`priority`)、ポリシング (`police`)、シェーピング (`shape`)、ランダム早期検出 (`random-detect`) などを設定します。
*   **適用 (Application):** `service-policy [input | output]` を使用して物理インターフェイス、サブインターフェイス、またはトンネルに適用します。

### 2. レイヤ 3 マーキングと PHB

*   **DSCP (6ビット):** 0〜63 の値を持ち、AF (Assured Forwarding) や EF (Expedited Forwarding) といった標準的な PHB を提供します。
*   **エンドツーエンドの維持:** レイヤ 2 の CoS (Class of Service) はトランクリンクを越えると消失しますが、レイヤ 3 の DSCP はパケットヘッダー内に維持されるため、エンドツーエンドの QoS に適しています。

### 3. トラスト境界 (Trust Boundary) とマッピング

*   アクセススイッチの入口でパケットを分類・マーキングし、以降のルータではその DSCP 値を「信頼」して処理します。
*   レイヤ 2 (CoS) とレイヤ 3 (DSCP) の間で一貫性を保つためのマッピング（Mutation Map や Table Map）が必要になる場合があります。

### 4. トンネル環境での QoS

*   GRE や IPsec トンネル、MPLS VPN を通過する際、内部パケットの DSCP 値を外部ヘッダー（外側 IP ヘッダーや MPLS EXP ビット）にコピー（TOS Reflection）する設定が、エンドツーエンドの品質維持に不可欠です。

---

## 🎯 試験対策 (CCIE EIレベル)

### 1. 複雑なビジネス要件の翻訳能力

ラボ試験では「音声は 200kbps の優先帯域を与え、かつバースト時もドロップさせないようにせよ」「動画は帯域の 30% を保証し、輻輳時は WRED を適用せよ」といった複合的な要件が出されます。

### 2. NBAR と MQC の統合

特定のアプリケーション（例：Office365, YouTube）を NBAR で識別し、特定の DSCP 値をマークして WAN 側へ送り出す一連の流れを迅速に設定できる必要があります。

### 3. SD-WAN (cEdge) での MQC 実装

IOS XE ベースの SD-WAN (cEdge) では、MQC コマンドがそのまま使用されますが、vManage の **Localized Policy** や **Feature Template** を通じてプッシュする際、コマンドの階層構造や適用順序を正確に理解しておく必要があります。

### 4. 階層型 QoS (HQoS) の活用

親ポリシーでシェーピング（物理速度制限）を行い、その中で子ポリシー（優先制御）を適用する HQoS の構成は、Sub-rate WAN リンクのシナリオで必須となります。

### 5. トラブルシューティングの検証コマンド

「設定したはずの QoS が効いていない」原因を特定するため、`show policy-map interface` のカウンタを確認し、どのクラスでドロップが発生しているか、あるいは分類自体が失敗しているかを判断する能力が問われます。

---

## 🛠 設定・検証コマンド

### MQC 基本構成コマンド

| 目的 | コマンド |
| :--- | :--- |
| **クラス定義 (Match-all/any)** | <code>class-map [match-all&#124;match-any] [NAME]</code> |
| **DSCP値に基づく分類** | <code>match ip dscp [VALUE]</code> |
| **ACLに基づく分類** | <code>match access-group name [ACL_NAME]</code> |
| **ポリシー定義** | <code>policy-map [NAME]</code> |
| **DSCP値のセット** | <code>(config-pmap-c)# set ip dscp [VALUE]</code> |
| **優先帯域の割り当て (LLQ)** | <code>(config-pmap-c)# priority [kbps]</code> |
| **最小保証帯域の割り当て (CBWFQ)** | <code>(config-pmap-c)# bandwidth [kbps &#124; percent %]</code> |
| **インターフェイスへの適用** | <code>(config-if)# service-policy [input&#124;output] [NAME]</code> |

### 検証・統計確認コマンド

| 目的 | コ:--- | :--- |
| **インターフェイスQoS統計表示** | <code>show policy-map interface [INTERFACE]</code> |
| **クラス構成の確認** | <code>show class-map [NAME]</code> |
| **適用中ポリシーの確認** | <code>show policy-map [NAME]</code> |
| **NBAR検出統計** | <code>show ip nbar protocol-discovery</code> |
| **プラットフォームQoS詳細確認** | <code>show platform qos advanced ...</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 3段階の重要度に基づいたマーキング

**【要件】** ネットワーク入口で、音声(RTP)を EF、業務アプリ(SQL)を AF31、その他を 0 にマークせよ。
```ios
class-map match-all CM-VOICE
 match protocol rtp
class-map match-all CM-BUSINESS
 match protocol sqlserver
!
policy-map PM-INGRESS-MARKING
 class CM-VOICE
  set ip dscp ef
 class CM-BUSINESS
  set ip dscp af31
 class class-default
  set ip dscp default
```

---

### 2. 音声トラフィックの優先制御 (LLQ)

**【要件】** DSCP EF のトラフィックに対し、インターフェイス帯域の 10% を優先的に割り当てよ。
```ios
class-map CM-EF
 match ip dscp ef
!
policy-map PM-EGRESS-QUEUING
 class CM-EF
  priority percent 10
```

---

### 3. NBAR2 を用いた特定 URL のマーキング

**【要件】** HTTP 通信のうち、URL に "cisco.com" を含むトラフィックに DSCP CS4 を付与せよ。
```ios
class-map match-all CM-CISCO-WEB
 match protocol http url "*cisco.com*"
!
policy-map PM-NBAR-MARKING
 class CM-CISCO-WEB
  set ip dscp cs4
```

---

### 4. 階層型 QoS (HQoS) による WAN 最適化

**【要件】** 物理帯域 1Gbps のポートを 100Mbps にシェーピングし、その中で優先制御を行え。
```ios
policy-map CHILD-POLICY
 class CM-EF
  priority 10000
!
policy-map PARENT-SHAPER
 class class-default
  shape average 100000000
  service-policy CHILD-POLICY
```

---

### 5. ポリシングに伴うマーキングの降格 (Markdown)

**【要件】** AF41 を 1Mbps まで許可し、超過分は AF43 に書き換えて（Markdown）転送せよ。
```ios
policy-map PM-POLICE-MARKDOWN
 class CM-BUSINESS-DATA
  police 1000000 
   conform-action transmit 
   exceed-action set-dscp-transmit af43
```

---

### 6. WRED による TCP 輻輳回避

**【要件】** クラス class-default において、DSCP ベースの WRED を有効化せよ。
```ios
policy-map PM-WRED
 class class-default
  random-detect dscp-based
```

---

### 7. IPv6 トラフィックの優先制御

**【要件】** IPv6 の特定の DSCP 値（CS3）を持つパケットを抽出し、帯域を保証せよ。
```ios
class-map CM-V6-MGMT
 match ip dscp cs3
 ! IOS XEでは match ip dscp で IPv4/IPv6 両方にマッチ可能
```

---

### 8. MPLS ネットワークへの EXP マーキング

**【要件】** PE ルータにおいて、顧客の DSCP AF41 を MPLS EXP ビット 4 にマッピングせよ。
```ios
policy-map PM-PE-TO-P
 class CM-AF41
  set mpls experimental topmost 4
```

---

### 9. トラスト境界の構成（アクセススイッチ）

**【要件】** インターフェイス Gi1/0/1 において、入力される DSCP 値を信頼せよ。
```ios
interface GigabitEthernet1/0/1
 qos trust dscp
```

---

### 10. 制御プレーン保護 (CoPP) での MQC 利用

**【要件】** BGP トラフィックを 500 pps に制限し、ルータの RP を保護せよ。
```ios
ip access-list extended ACL-BGP
 permit tcp any any eq 179
!
class-map CM-BGP
 match access-group name ACL-BGP
!
policy-map COPP-POLICY
 class CM-BGP
  police rate 500 pps conform-action transmit exceed-action drop
!
control-plane
 service-policy input COPP-POLICY
```

---

### 11. SD-WAN (cEdge) テンプレートでの QoS 適用

**【操作例】** vManage 上で作成した QOS-MAP と Shaping Rate を VPN インターフェイスに適用。
*   vManage ➔ Feature Template ➔ VPN Interface ➔ ACL/QoS:
    *   Shaping Rate (kbps): `100000`
    *   QoS Map: `QOS-MAP-BRANCH`

---

### 12. 統計情報の詳細確認（検証タスク）

**【手順】** 指定したポリシーでパケットが正しく「ヒット」しているか確認せよ。
```ios
Router# show policy-map interface GigabitEthernet1
! 出力結果内の "packets matched" が増加していること、
! および優先クラスで "drop" が発生していないことを確認。
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)

### Configuration ガイド
*   [**Quality of Service Configuration Guide, Cisco IOS XE Release 17.x**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos/configuration/xe-17/qos-xe-17-book.html)
*   [**QoS: Classification Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_classn/configuration/xe-17/qos-classn-xe-17-book.html)
*   [**Configuring NBAR based Classification**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoS-SRND-Book/QoSIntro.html)
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)
*   [**Low Latency Queuing with Priority Percentage Support**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conmgt/configuration/15-mt/qos-conmgt-15-mt-book/qos-conmgt-llq-pps.html)

---
## 📝 補足
- この学習メモは、CCIE EI 実技試験において QoS を「点（コマンド）」ではなく「線（エンドツーエンドのトラフィックフロー）」として捉えるための指針となります。ラボ試験では、**`show policy-map interface`** の出力を詳細に読み解き、要件に対する実装の整合性を証明できることが合格の鍵となります。


