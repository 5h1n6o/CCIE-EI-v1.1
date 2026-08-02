---
layout: default
title: 4.4.a-DiffServ
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.4.a Differentiated Services architecture

本メモでは、現代のエンタープライズネットワークにおいて標準的なQoSモデルである **Differentiated Services (DiffServ)** アーキテクチャについて、CCIE EI v1.1のBlueprintに基づき詳述します。DiffServは、スケーラビリティに優れたQoS制御手法であり、エンド・ツー・エンドのトラフィック優先順位付けの基盤となります。

---

## 📘 概要

**Differentiated Services (DiffServ)** は、IPパケットのヘッダー（IPv4のToSフィールド、IPv6のTraffic Classフィールド）内の6ビットの **DSCP (Differentiated Services Code Point)** 値を使用して、ネットワークデバイスが各ホップでトラフィックをどのように処理するか（Per-Hop Behavior: PHB）を決定するQoSアーキテクチャです。

従来の **Integrated Services (IntServ)** がRSVPプロトコルを使用してエンド・ツー・エンドのリソース予約を行う「ステートフル」なモデルであったのに対し、DiffServは「ステートレス」かつホップバイホップで動作するため、大規模なエンタープライズ環境において非常に高いスケーラビリティを発揮します。実装には主に **MQC (Modular QoS CLI)** フレームワークが使用されます。

---

## 🔑 要点

### 1. DiffServの構成要素

DiffServモデルは、ネットワーク内での役割に応じて以下のコンポーネントで構成されます。
*   **分類 (Classification):** 物理ポート、ACL、またはL7プロトコル認知機能（NBAR）を使用してトラフィックを特定のクラスに分類します。
*   **マーキング (Marking):** 分類されたパケットに対し、DSCP値を付与します。これにより、後続のルータは再分類を行うことなくQoSポリシーを適用できます。
*   **調整 (Conditioning):** ポリシング（Policing）やシェーピング（Shaping）を用いて、トラフィックが定義されたレートを超えないように制御します。
*   **PHB (Per-Hop Behavior):** 個々のデバイスにおける転送挙動（優先度、キューイング、ドロップ特性）を定義します。

### 2. DSCPとIP Precedence (L3)

*   **IP Precedence:** 3ビットを使用（0-7）。古いモデルですが、DSCPの構成要素（上位3ビット）として互換性があります。
*   **DSCP:** 6ビットを使用（0-63）。より細かいクラス分けが可能です。
    *   **Default:** Best Effort (000000)。
    *   **Expedited Forwarding (EF):** 音声トラフィック用。低遅延、低ジッターを保証 (46 / 101110)。
    *   **Assured Forwarding (AF):** 4クラス×3つのドロップ優先度で構成 (例: AF41)。

### 3. トラスト境界 (Trust Boundary)

QoSの設計において、どのデバイスがパケットのQoSタグ（CoS/DSCP）を信頼するかを定義します。一般的に、IP電話やアクセススイッチのポートでトラフィックを分類・マーキングし、ネットワークコアではその値を「信頼（Trust）」して高速転送を行います。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、複雑なビジネス要件を正確なMQCコマンドに落とし込む能力が試されます。

### 1. エンド・ツー・エンドの一貫性

「サイトAでマーキングされたDSCP AF41が、WAN（SD-WANやMPLS）を通過してサイトBに到達するまで維持されているか」という観点が重要です。VPN（GRE/IPsec）構成時における、内側パケットから外側ヘッダーへのDSCPコピー（TOS Reflection）の設定が問われることがあります。

### 2. NBARとMQCの組み合わせ

特定のURLや動的なポートを使用するアプリケーション（例: HTTPの特定拡張子）を識別し、DiffServモデルに基づいてマーキングするタスクが頻出します。

### 3. プラットフォーム固有の制限

cEdge (IOS-XE) と vEdge (Viptela OS) ではQoSの定義方法が異なります。cEdgeではIOS-XE標準のMQCを使用しますが、SD-WANテンプレートを介してこれをプッシュする際、`policy-map` の構造が正しいかを検証する必要があります。

---

## 🛠 設定・検証コマンド

Cisco IOS XE における DiffServ 実装（MQC）の基本コマンドです。

| 目的 | コマンド |
| :--- | :--- |
| **クラスの定義 (分類)** | <code>class-map [match-all&#124;match-any] [NAME]</code> |
| **DSCP値に基づくマッチング** | <code>match ip dscp [VAL]</code> |
| **プロトコルに基づくマッチング** | <code>match protocol [PROTOCOL]</code> |
| **ポリシーの定義 (アクション)** | <code>policy-map [NAME]</code> |
| **マーキングの実行** | <code>(config-pmap-c)# set ip dscp [VAL]</code> |
| **優先キュー(LLQ)の設定** | <code>(config-pmap-c)# priority [bandwidth]</code> |
| **インターフェイスへの適用** | <code>(config-if)# service-policy [input&#124;output] [NAME]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスごとのQoS統計** | <code>show policy-map interface [INT]</code> |
| **クラスマップの構成確認** | <code>show class-map</code> |
| **プラットフォーム側のQoS状態** | <code>show platform qos advanced ...</code> |
| **NBARの統計情報の表示** | <code>show ip nbar protocol-discovery</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な MQC 構造の構成

**【問題】** ICMP トラフィックをクラス `CM-ICMP` に分類し、DSCP 値を `CS1` に設定せよ。
```ios
class-map CM-ICMP
 match protocol icmp
!
policy-map PM-MARKING
 class CM-ICMP
  set ip dscp cs1
!
interface Gi1
 service-policy input PM-MARKING
```

---

### 2. NBAR を利用した HTTP トラフィックのマーキング

**【問題】** HTTP 通信のうち、URL に ".jpg" を含むトラフィックのみ DSCP `AF11` を付与せよ。
```ios
class-map match-all CM-HTTP-IMAGE
 match protocol http url "*.jpg"
!
policy-map PM-NBAR
 class CM-HTTP-IMAGE
  set ip dscp af11
```

---

### 3. 音声用 LLQ (Low Latency Queuing) の実装

**【問題】** DSCP `EF` のトラフィックに 30% の帯域幅を優先的に割り当てよ。
```ios
policy-map PM-LLQ
 class class-default
  ! 通常はDSCP EFをマッチさせるクラスを定義
  priority percent 30
```

---

### 4. 帯域保証 (Bandwidth) の設定

**【問題】** ビジネスクリティカルなトラフィック（AF41）に対し、最低 256kbps の帯域を保証せよ。
```ios
policy-map PM-BW
 class CLASS-BUSINESS
  bandwidth 256
```

---

### 5. ポリシング (Policing) によるレート制限

**【問題】** ゲスト用トラフィック（default）を 1Mbps に制限し、超過分をドロップせよ。
```ios
policy-map PM-POLICE
 class class-default
  police 1000000 conform-action transmit exceed-action drop
```

---

### 6. WRED (Weighted Random Early Detection)

**【問題】** 輻輳を回避するため、TCP トラフィックに対して DSCP ベースの WRED を有効化せよ。
```ios
policy-map PM-WRED
 class class-default
  random-detect dscp-based
```

---

### 7. トラスト境界の構成（アクセススイッチ）

**【問題】** アクセスポート Gi1/0/1 で着信パケットの DSCP 値を信頼せよ。
```ios
interface GigabitEthernet1/0/1
 qos trust dscp
```

---

### 8. 階層型 QoS (HQoS) の実装

**【問題】** 物理インターフェイス全体を 10Mbps にシェーピングし、その中で音声優先制御を行え。
```ios
policy-map CHILD-POLICY
 class VOICE
  priority 1000
!
policy-map PARENT-SHAPER
 class class-default
  shape average 10000000
  service-policy CHILD-POLICY
```

---

### 9. SD-WAN テンプレートを介した QoS 適用

**【問題】** vManage テンプレートを使用して、インターフェイス `ge0/0` にQoSマップを適用せよ。
*   *操作:* vManage ➔ Feature Template ➔ VPN Interface ➔ ACL/QoS ➔ QoS Map: `QOS-MAP` を指定。

---

### 10. MPLS EXP ビットへのマーキング

**【問題】** MPLS ネットワークへの入り口（PE）で、DSCP AF41 を MPLS EXP 4 にマッピングせよ。
```ios
policy-map PM-MPLS-EXP
 class CLASS-AF41
  set mpls experimental topmost 4
```

---

### 11. DSCP 値の書き換え (Mutation)

**【問題】** 外部から届く DSCP `EF` を、ポリシー上の理由で一時的に `CS4` に付け替えよ。
```ios
class-map match-all CM-EF
 match ip dscp ef
!
policy-map PM-MUTATION
 class CM-EF
  set ip dscp cs4
```

---

### 12. 統計情報の確認とドロップの特定

**【問題】** `show policy-map interface` を使用して、特定のクラスでパケットがドロップされているか検証せよ。
```ios
# show policy-map interface GigabitEthernet1
! 期待される出力: "pkts output", "drop" カウンタの増加を確認する。
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731) - 最新のIOS-XEにおけるQoS実装の全容。
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501) - エンタープライズキャンパスでのDiffServ設計ガイド。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE試験におけるQoSの価値と対策。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Quality of Service Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos/configuration/xe-17/qos-xe-17-book.html)。
*   [**Configuring NBAR based Classification**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)。

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)。
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。

---

## 📝 補足

- この学習メモは、CCIE EI試験におけるQoSの「論理（DiffServ）」と「実装（MQC）」を統合しています。ラボ試験では、**`show policy-map interface`** の出力を読み解き、設定したしきい値に対してトラフィックがどのように分類・処理されているかを正確に判断するスキルが合格の決め手となります。


