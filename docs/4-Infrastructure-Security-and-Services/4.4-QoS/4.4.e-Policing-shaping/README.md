---
layout: default
title: 4.4.e-Policing-shaping
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 5
---

# 4.4.e Policing, Shaping

本ページでは、ネットワークトラフィックの帯域制御を司る2つの主要技術、**ポリシング（Policing）**と**シェーピング（Shaping）**について、CCIE Enterprise Infrastructure (EI) v1.1の試験範囲に基づき詳述します。

---

## 📘 概要

QoSの実装において、特定のクラスに割り当てるトラフィック量を物理的な回線速度未満に制限することを「トラフィック調整（Traffic Conditioning）」と呼びます。これには、主に以下の2つの手法が用いられます。

*   **ポリシング (Policing):** 定義されたレート（CIR）を超過したトラフィックを即座に破棄、あるいは優先度を下げて（Markdown）転送する手法です。主にインターフェイスの入力（Ingress）および出力（Egress）の両方に適用可能ですが、一般的にはネットワーク境界の入力側で「契約以上のパケットを入れない」ために使用されます。
*   **シェーピング (Shaping):** バースト的なトラフィックをバッファ（メモリ）に一時的に格納し、平滑化して送出する手法です。パケットをドロップするのではなく遅延させるため、TCPの再送制御への影響を抑えられます。シェーピングは「送出を待つ」動作を伴うため、出力（Egress）インターフェイスにのみ適用可能です。

---

## 🔑 要点

### 1. トークンバケットアルゴリズム (Token Bucket)

ポリシングとシェーピングは、いずれも「トークンバケット」という概念を使用してパケットの転送可否を判断します。
*   **CIR (Committed Information Rate):** 1秒間に許可される平均ビットレート。
*   **Bc (Committed Burst):** 1回の測定間隔（Tc）の間にバケットに補充されるトークン量。
*   **Be (Excess Burst):** バケットが溢れた際に予備のバケットに蓄積できる追加のトークン量。
*   **Tc (Time Interval):** トークンが補充される間隔。計算式は `Tc = Bc / CIR` となります。

### 2. ポリサー（Policer）の種類

*   **Single-rate, Two-color:** 1つのバケットを使用。超過分をドロップ。
*   **Single-rate, Three-color (RFC 2697):** BcとBeの2つのバケットを使用。Conform（適合）、Exceed（超過）、Violate（違反）の3段階で判定。
*   **Two-rate, Three-color (RFC 2698):** CIRに加えてPIR（Peak Information Rate）を定義。ピークレートを超えたものをViolateとして厳格に処理。

### 3. シェーパー（Shaper）のモード

*   **Average Shaping:** CIRに基づき、TcごとにBc分のトークンを補充して平均レートを維持します。
*   **Peak Shaping:** BcとBeの両方を補充するため、CIR以上のレート（PIR = CIR * (1 + Be/Bc)）での送出を許容します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純なコマンド設定だけでなく、複雑なトポロジーにおける「トラフィックの振る舞い」の予測と最適化が求められます。

### 1. 物理レートと論理レートの不整合 (Sub-rate)

イーサネットは1Gbpsだが、プロバイダーとの契約が100Mbpsといった「Sub-rate」環境では、出力側でのシェーピングが必須です。シェーピングを行わないと、バーストした瞬間にプロバイダー側（入力側）のポリサーでパケットが不規則にドロップされ、QoSポリシーが機能しなくなります。

### 2. 階層型QoS (HQoS) でのシェーピング

物理インターフェイス全体の帯域を制限（シェーピング）し、その「制限された箱」の中で優先制御（LLQや帯域保証）を行う階層型ポリシーの構成が頻出します。
*   **Parent Policy:** 物理リンクの帯域に合わせて `shape average` を実行。
*   **Child Policy:** 制限された帯域内で `priority` や `bandwidth` を割り当て。

### 3. Markdown (条件付きマーキング)

「適合したパケットはDSCP AF41で送り、超過したパケットはAF43に書き換えて送れ」といった、ポリシングのアクションとしてのマーキング操作が問われます。

### 4. SD-WAN における QoS 実装

cEdge (IOS-XE) では、vManage の **Feature Template** を通じて QoS Policy を適用します。テンプレート上で Shaping レートや QoS Map を正しく紐付け、データプレーンへ反映させる手順を習得してください。

---

## 🛠 設定・検証コマンド

### ポリシング (Policing) 設定

| 目的 | コマンド |
| :--- | :--- |
| **単一レートポリシング(10Mbps)** | <code>police 10000000 conform-action transmit exceed-action drop</code> |
| **2レート3色ポリシング** | <code>police cir 128000 pir 256000 conform-action transmit exceed-action set-prec-transmit 0 violate-action drop</code> |
| **パーセント指定のポリシング** | <code>police percent 20 conform-action transmit exceed-action drop</code> |

### シェーピング (Shaping) 設定

| 目的 | コマンド |
| :--- | :--- |
| **平均レートシェーピング** | <code>shape average [CIR] [Bc] [Be]</code> |
| **ピークレートシェーピング** | <code>shape peak [CIR]</code> |
| **パーセント指定のシェーピング** | <code>shape average percent</code> |

### 検証・統計確認

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスごとのQoS統計表示** | <code>show policy-map interface [INTERFACE]</code> |
| **ドロップパケットの有無を確認** | <code>show policy-map interface &#124; include drop</code> |
| **テーブルマップの確認** | <code>show table-map</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な 100kbps へのポリシング

**【課題】** VLAN 10 からのトラフィックを 100 kbps に制限し、超過分を破棄せよ。
```ios
policy-map PM-POLICE
 class GUEST-VLAN
  police 100000 conform-action transmit exceed-action drop
```

### 2. 条件付き Markdown (DSCP 降格)

**【課題】** 10Mbps を超える AF41 トラフィックを AF43 に書き換えて送信せよ。
```ios
policy-map PM-MARKDOWN
 class BUSINESS-DATA
  police 10000000
   conform-action transmit
   exceed-action set-dscp-transmit af43
```

### 3. WAN インターフェイスでの平均シェーピング

**【課題】** 回線帯域が 1.5 Mbps のシリアルリンクにおいて、平均 768 kbps にシェーピングせよ。
```ios
policy-map PM-SHAPE
 class class-default
  shape average 768000
```

### 4. ピークレートシェーピングの構成

**【課題】** 設定された CIR の 2 倍までのバーストを許可するピークシェーピングを設定せよ。
```ios
policy-map PM-PEAK
 class class-default
  shape peak 256000
```

### 5. HQoS: シェーピング配下での音声優先 (LLQ)

**【課題】** 物理ポートを 10Mbps に制限し、その中で音声 (DSCP EF) に 10% の帯域を優先割り当てせよ。
```ios
policy-map CHILD-QOS
 class VOICE
  priority percent 10
!
policy-map PARENT-SHAPER
 class class-default
  shape average 10000000
  service-policy CHILD-QOS
```

### 6. NBAR2 を用いた特定 URL のポリシング

**【課題】** HTTP でダウンロードされる "*.gif" または "*.jpg" ファイルの転送を 100 kbps に制限せよ。
```ios
class-map match-any CM-IMAGES
 match protocol http url "*.gif"
 match protocol http url "*.jpg"
!
policy-map PM-NBAR-POLICE
 class CM-IMAGES
  police 100000
```

### 7. マイクロフロー・ポリシング (Microflow Policing)

**【課題】** 送信元 IP ごとに、個別の通信（フロー）を 1Mbps に制限せよ。
```ios
policy-map GUEST-VLAN-MICROFLOW
 class GUEST-VLAN
  police cir 1000000
   conform-action transmit
   exceed-action drop
! 注意: Catalyst 4500 等のプラットフォーム固有機能。
```

### 8. 制御プレーンの保護 (CoPP) でのポリシング

**【課題】** ルータの CPU 負荷を抑えるため、BGP トラフィックを 500 pps に制限せよ。
```ios
policy-map CPP-POLICY
 class CPP-ACL-BGP
  police rate 500 pps conform-action transmit exceed-action drop
!
control-plane
 service-policy input CPP-POLICY
```

### 9. パーセント指定のシェーピング (SD-WAN 相当)

**【課題】** インターフェイス帯域の 25% を特定のアプリケーションクラスに割り当て、シェーピングせよ。
```ios
policy-map PM-PERCENT
 class MISSION-CRITICAL
  shape average percent 25
```

### 10. レイヤ 2 CoS への Markdown 適用

**【課題】** 制限を超えたトラフィックの 802.1p (CoS) 値を 0 にリセットして送信せよ。
```ios
policy-map PM-L2-MARK
 class CUSTOMER1
  police cir 128000
   conform-action transmit
   exceed-action set-cos-transmit 0
```

### 11. 送信元 IP に基づくポリシング (ACL 連携)

**【課題】** 特定のホスト (1.3.1.1) からの Telnet 通信のみを 10 kbps に絞れ。
```ios
access-list 110 permit tcp host 1.3.1.1 any eq 23
!
class-map CM-TELNET
 match access-group 110
!
policy-map PM-RESTRICT
 class CM-TELNET
  police 10000
```

### 12. 検証コマンドによるドロップの特定

**【操作例】** 設定したポリシングにより、実際にパケットが破棄されているかを確認せよ。
```ios
R1# show policy-map interface GigabitEthernet1
! 期待される出力:
! Class-map: CM-WEB (match-all)
!   1234 packets, 987654 bytes
!   police:
!     cir 100000 bps, bc 3125 bytes
!     conformed 80000 bps; action: transmit
!     exceeded 20000 bps; action: drop
!     conformed 1000 pkts, exceeded 234 pkts  <-- ドロップ数を確認
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
    *   最新プラットフォームにおけるポリシングとシェーピングの実装詳細。
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
    *   キャンパスネットワークにおける階層型QoSの設計ベストプラクティス。

### Configuration ガイド
*   [**QoS: Policing and Shaping Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_plcshp/configuration/xe-17/qos-plcshp-xe-17-book.html)。
*   [**Configuring Hierarchical Modular QoS (HQoS)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_hrhqf/configuration/xe-16/qos-hrhqf-xe-16-book.html)。

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)。
*   [**Comparing Traffic Policing and Traffic Shaping for Bandwidth Management (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/19645-policevsshape.html)。

---
## 📝 補足
- この学習メモは、CCIE EI試験におけるQoS制御の確実な実装能力を養うことを目的としています。ラボ試験では、**`show policy-map interface`** の出力を迅速に解析し、バーストサイズ（Bc）の設定ミスや、Parent/Child ポリシーの論理的な矛盾を即座に修正できることが合格への鍵となります。


