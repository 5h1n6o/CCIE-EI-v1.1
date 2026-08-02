---
layout: default
title: 4.4.g-HQoS
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 7
---

# 4.4.g-HQoS

# CCIE Enterprise Infrastructure v1.1 学習メモ: 4.4.g HQoS (Hierarchical Quality of Service)

本ページでは、Cisco IOS XE における高度な QoS 設計手法である **Hierarchical Quality of Service (HQoS)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。HQoS は、物理ポートの速度と実際の契約帯域が異なる環境（Sub-rate リンク）や、多層的なトラフィック制御が求められるシナリオにおいて不可欠な技術です。

---

## 📘 概要

**Hierarchical QoS (HQoS)** とは、Modular QoS CLI (MQC) を使用して、ポリシーマップの中に別のポリシーマップをネスト（階層化）させる構成を指します。通常、2 つの階層（Parent と Child）で構成されます。

1.  **親ポリシー (Parent Policy):** インターフェイス全体のトラフィックを制御します。主な目的は、インターフェイス全体の帯域幅を特定のレート（CIR）に制限する **シェーピング (Shaping)** です。
2.  **子ポリシー (Child Policy):** 親ポリシーによって制限された「箱」の中で、トラフィックを個別のクラスに分類し、優先順位（LLQ）や帯域保証（CBWFQ）を割り当てます。

### なぜ HQoS が必要なのか

イーサネットは物理的に 1Gbps の速度を持っていても、サービスプロバイダーとの契約（CIR）が 100Mbps である場合、ルータが物理速度でパケットを送り出すと、プロバイダー側のポリサーによってパケットが不規則にドロップされます。HQoS を使用してルータ側で 100Mbps にシェーピングし、その制限下で優先制御を行うことで、重要なパケット（音声など）を保護しつつ輻輳を管理できるようになります。

---

## 🔑 要点

### 1. 親と子の役割分担

*   **Parent:** `class-default` クラスで `shape average` を実行し、論理的な帯域上限を定義します。
*   **Child:** 親ポリシーの `class-default` 配下で `service-policy` として適用されます。内部で `priority` や `bandwidth` を使用します。

### 2. スケジューリングとキューイング

*   HQoS 環境では、親のシェーパーがパケットを保持（バッファリング）する際、子のキューイング・アルゴリズム（LLQ, CBWFQ）に従って、どのパケットを優先的にバッファから取り出すかを決定します。

### 3. SD-WAN における実装

*   Cisco SD-WAN (cEdge) では、vManage の **Localized Policy** を通じて HQoS を実装します。
*   **Forwarding Class** と **QoS Map** を定義し、Feature Template 内でインターフェイスの **Shaping Rate**（親）と **QoS Map**（子）を紐付けます。

### 4. 階層型ポリシング (Hierarchical Policing)

*   シェーピングだけでなく、ポリシングを階層化することも可能です。例えば、親ポリシーで全体のトラフィックを制限し、子ポリシーで特定のプロトコルをさらに厳しく制限する構成です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、複雑なトポロジーにおける帯域制御の整合性が問われます。

### 1. Sub-rate インターフェイスの罠

物理速度（例: 10Gbps）に対して非常に低い論理帯域（例: 10Mbps）を要求される場合があります。この際、親ポリシーで正しくシェーピングを行わないと、子ポリシーの `priority percent` 等の計算が物理速度ベースになり、意図した動作をしません。

### 2. 計算問題としての HQoS

「全体の 50% をシェーピングし、その中で音声に 20% を割り当てる」といった要件が出ます。
*   親: `shape average percent 50`
*   子: `priority percent 20`
この場合、音声に割り当てられるのは物理帯域の 10% (50% の 20%) になることを理解しておく必要があります。

### 3. SD-WAN テンプレートの紐付け

vManage 上で、どのテンプレートが「親（Shaping）」を定義し、どのテンプレートが「子（QoS Map）」を定義しているかを正確に把握し、正しい順序で適用する操作が求められます。

### 4. トラブルシューティングの視点

`show policy-map interface` を実行した際、親ポリシーのドロップ数と、子ポリシーの各クラスのドロップ数を個別に分析し、どこで輻輳が発生しているかを特定する能力が必須です。

---

## 🛠 設定・検証コマンド

### 基本構成 (IOS XE MQC)

| 目的 | コマンド |
| :--- | :--- |
| **子ポリシーの定義** | <code>policy-map CHILD-POLICY</code><br><code> class VOICE</code><br><code>  priority 1000</code> |
| **親ポリシーの定義** | <code>policy-map PARENT-SHAPER</code><br><code> class class-default</code><br><code>  shape average 10000000</code><br><code>  service-policy CHILD-POLICY</code> |
| **インターフェイスへの適用** | <code>(config-if)# service-policy output PARENT-SHAPER</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **階層型QoSの統計表示** | <code>show policy-map interface [INTERFACE]</code> |
| **シェーピングの詳細確認** | <code>show policy-map interface [INT] class class-default</code> |
| **子ポリシーのキュー確認** | <code>show policy-map interface [INT] &#124; section CHILD-POLICY</code> |
| **プラットフォームのハードウェア状態** | <code>show platform qos hierarchy ...</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 標準的な WAN シェーピング (HQoS)

**【課題】** 1Gbps のポートを 100Mbps に制限し、その中で音声に 10Mbps を最優先で割り当てよ。
```ios
policy-map CHILD-QOS
 class CM-VOICE
  priority 10000
!
policy-map PARENT-100M
 class class-default
  shape average 100000000
  service-policy CHILD-QOS
```

### 2. パーセント指定による階層型制御

**【課題】** 親で帯域の 50% を確保し、子ポリシーでその確保分の 20% をビジネスデータに割り当てよ。
```ios
policy-map CHILD
 class CM-DATA
  bandwidth remaining percent 20
!
policy-map PARENT
 class class-default
  shape average percent 50
  service-policy CHILD
```

### 3. 子ポリシーでの WRED 実装

**【課題】** 親でシェーピングを行い、子ポリシーのデータクラスで TCP 輻輳回避（WRED）を有効化せよ。
```ios
policy-map CHILD-WRED
 class CM-TCP-DATA
  random-detect dscp-based
!
policy-map PARENT-SHAPER
 class class-default
  shape average 10000000
  service-policy CHILD-WRED
```

### 4. 階層型ポリシング (Nested Policer)

**【課題】** 全体を 2Mbps に制限しつつ、その中の HTTP 通信のみをさらに 500kbps に制限せよ。
```ios
policy-map CHILD-POLICE
 class CM-HTTP
  police 500000
!
policy-map PARENT-POLICE
 class class-default
  police 2000000
  service-policy CHILD-POLICE
```

### 5. SD-WAN: vManage Localized Policy 相当の構成

**【課題】** 転送クラス Queue 1 に 30% の帯域と RED を適用し、Queue 2 に 30% と Tail Drop を適用せよ。
```ios
policy-map QOS-MAP
 class Queue1
  bandwidth percent 30
  random-detect
 class Queue2
  bandwidth percent 30
!
! 親(Shaper)はインターフェイス・テンプレート側で定義される
```

### 6. 子ポリシーでの DSCP マーキング

**【課題】** 親で 10Mbps にシェーピングし、子ポリシーで特定のトラフィックに AF21 をマークせよ。
```ios
policy-map CHILD-MARK
 class CM-OFFICE
  set ip dscp af21
!
policy-map PARENT-SHAPE
 class class-default
  shape average 10000000
  service-policy CHILD-MARK
```

### 7. 物理ポートの制限を超えるバーストの許可 (Peak Shaping)

**【課題】** 平均 1Mbps だが、物理帯域が許す限り 2Mbps までバーストを許可する親ポリシーを作成せよ。
```ios
policy-map PARENT-PEAK
 class class-default
  shape peak 1000000
  service-policy CHILD-QOS
```

### 8. 子ポリシーでのキューリミット調整

**【課題】** 親でシェーピング中、低優先トラフィックのバッファ溢れを防ぐため子のキューを 300 パケットに増やせ。
```ios
policy-map CHILD-BUFFERS
 class class-default
  queue-limit 300 packets
```

### 9. マルチテナント向け帯域分割

**【課題】** 物理ポートを Tenant-A (40M) と Tenant-B (60M) に分け、それぞれの中で独自の優先制御を行え。
```ios
policy-map TENANT-A-PARENT
 class class-default
  shape average 40000000
  service-policy CHILD-A
policy-map TENANT-B-PARENT
 class class-default
  shape average 60000000
  service-policy CHILD-B
```

### 10. 親ポリシーの Bc/Be の微調整

**【課題】** 遅延を最小限にするため、親シェーパーの測定間隔（Tc）が 10ms になるよう Bc を調整せよ。
```ios
! CIR=10M, Tc=10ms => Bc = CIR * Tc = 10,000,000 * 0.01 = 100,000 bits (12,500 bytes)
policy-map PARENT-LOW-LATENCY
 class class-default
  shape average 10000000 12500
```

### 11. 階層型 QoS の検証 (Drop の特定)

**【手順】** `show policy-map interface` を実行し、子がドロップしていないのに親でドロップしている状態（全体の帯域不足）を確認せよ。
```ios
# show policy-map interface GigabitEthernet1
! 親クラスの "shape" セクションのドロップカウンタを確認
```

### 12. SD-WAN テンプレート経由の HQoS 適用プロセス

**【手順】** vManage ➔ Feature Template ➔ VPN Interface ➔ ACL/QoS セクションで Shaping Rate と QoS Map を指定してプッシュせよ。

---

## 🔗 参考リソース

### Cisco Live (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
*   [**BRKCRT-1385: The CCIE in an SDN World - QoS Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)

### Configuration ガイド
*   [**Cisco IOS XE 17.x QoS: Configuring Hierarchical Modular QoS (HQoS)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_hrhqf/configuration/xe-16/qos-hrhqf-xe-16-book.html)
*   [**Quality of Service Configuration Guide, Catalyst 9300**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/qos/b_179_qos_9300_cg.html)

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)
*   [**Low Latency Queuing with Priority Percentage Support**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conmgt/configuration/15-mt/qos-conmgt-15-mt-book/qos-conmgt-llq-pps.html)

---

## 📝 補足
- この学習メモは、HQoS が単なるネストしたコマンドではなく、**「物理速度と論理速度のギャップを埋めるための不可欠な階層設計」**であることを示しています。CCIE ラボ試験では、親ポリシーでのシェーピングを忘れると、子ポリシーの帯域計算が破綻するため、常にセットで考える習慣をつけてください。


