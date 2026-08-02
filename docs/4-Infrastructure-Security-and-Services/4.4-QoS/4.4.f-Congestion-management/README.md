---
layout: default
title: 4.4.f-Congestion-management
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 6
---

# 4.4.f-Congestion-management and avoidance
# CCIE Enterprise Infrastructure v1.1 学習メモ: 4.4.f 輻輳管理と輻輳回避

本ページでは、ネットワークのボトルネックにおいてトラフィックの優先順位を制御する「輻輳管理（Congestion Management）」と、キューが溢れる前にパケットを適切に処理する「輻輳回避（Congestion Avoidance）」について、CCIE Enterprise Infrastructure (EI) v1.1のレベルで詳述します。

---

## 📘 概要

**輻輳管理（Congestion Management）**とは、出力インターフェイスの帯域幅を超えるトラフィックが発生した際、パケットをバッファ（キュー）に格納し、定義されたスケジューリング・アルゴリズムに基づいて送出順序を決定する技術です。主要な実装として、帯域を保証する **CBWFQ** や、遅延に敏感なトラフィックを最優先する **LLQ** があります。

**輻輳回避（Congestion Avoidance）**とは、バッファが完全に満杯になって発生する「テールドロップ（Tail Drop）」と、それに伴う「TCPグローバル同期」を防ぐための予防措置です。代表的な技術である **WRED (Weighted Random Early Detection)** は、キューが一杯になる前に、優先度の低いパケットからランダムに破棄を開始することで、ネットワーク全体の効率を維持します。

---

## 🔑 要点

### 1. 輻輳管理：キューイングとスケジューリング

*   **CBWFQ (Class-Based Weighted Fair Queuing):** ユーザー定義のクラスごとに帯域幅（bandwidth）を割り当てます。割り当てられた帯域は、インターフェイスが輻輳している時にのみ「保証」されます。
*   **LLQ (Low Latency Queuing):** CBWFQに厳格な優先キュー（Priority Queue）を追加したものです。音声などのリアルタイムトラフィックに使用され、他のどのトラフィックよりも先に送出されます。
*   **Bandwidth Remaining:** 明示的な割り当ての後に残った帯域を、比率（percent）でクラス間に分配する高度な設計手法です。

### 2. 輻輳回避：パケット破棄メカニズム

*   **Tail Drop:** キューが満杯の時に届いたパケットをすべて破棄します。これはTCP接続の同時スロースタート（グローバル同期）を引き起こし、帯域利用率を著しく低下させます。
*   **WRED (Weighted Random Early Detection):** 
    *   IP PrecedenceやDSCP値に基づいてパケットを識別し、バッファの平均使用率に応じて破棄確率を変化させます。
    *   **ECN (Explicit Congestion Notification):** パケットを破棄する代わりに、ヘッダーに輻輳を通知するマークを付け、送信元にレート抑制を促します。

### 3. MQC (Modular QoS CLI)

QoSの構成は、分類（Class-map）、アクション定義（Policy-map）、インターフェイス適用（Service-policy）の3段階で行われます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純な設定だけでなく、制限事項や計算を伴うシナリオが問われます。

### 1. LLQ の制限とポリシング

LLQ（`priority` コマンド）を使用する場合、そのクラスには暗黙のポリサーが適用されます。指定した帯域を超えた優先トラフィックは、インターフェイスが輻輳している場合にドロップされるため、正しい帯域見積もりが不可欠です。

### 2. Bandwidth vs Priority

*   `bandwidth`: 最小保証帯域。輻輳時でもこれだけの量は確保されますが、余剰帯域がある場合はそれ以上使うことも可能です。
*   `priority`: 絶対優先。低遅延を保証しますが、輻輳時は指定レートまでに制限されます。

### 3. WRED のしきい値調整

デフォルトのWRED設定ではなく、特定のDSCP値に対して「最小しきい値（Min-threshold）」や「最大しきい値（Max-threshold）」をカスタマイズするタスクが想定されます。これにより、特定の重要アプリケーションが真っ先にドロップされるのを防ぎます。

### 4. キュー・リミット (Queue-limit)

特定のクラスに割り当てるバッファの深さを調整するタスクです。バースト性の高いトラフィックを収容するために `queue-limit` を大きくする設定などが問われます。

---

## 🛠 設定・検証コマンド

### 輻輳管理 (Queuing)

| 目的 | コマンド |
| :--- | :--- |
| **帯域幅の絶対値指定** | <code>(config-pmap-c)# bandwidth [kbps]</code> |
| **帯域幅のパーセント指定** | <code>(config-pmap-c)# bandwidth percent [PERCENT]</code> |
| **厳格優先(LLQ)の設定** | <code>(config-pmap-c)# priority [kbps &#124; percent PERCENT]</code> |
| **余剰帯域の分配** | <code>(config-pmap-c)# bandwidth remaining percent [PERCENT]</code> |

### 輻輳回避 (Avoidance)

| 目的 | コマンド |
| :--- | :--- |
| **DSCPベースのWRED有効化** | <code>(config-pmap-c)# random-detect dscp-based</code> |
| **WREDしきい値の個別調整** | <code>(config-pmap-c)# random-detect dscp [VAL] [MIN] [MAX] [MARK]</code> |
| **ECNの有効化** | <code>(config-pmap-c)# random-detect ecn</code> |
| **キューの最大保持数変更** | <code>(config-pmap-c)# queue-limit [PACKETS]</code> |

### 検証・統計

| 目的 | コマンド |
| :--- | :--- |
| **QoS適用状態とドロップ確認** | <code>show policy-map interface [INTERFACE]</code> |
| **WREDの動作統計表示** | <code>show policy-map interface [INT] &#124; section random-detect</code> |
| **インターフェイスのキュー確認** | <code>show interfaces [INT] &#124; include queue</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 音声トラフィックの優先制御 (LLQ)

**【問題】** クラス `CM-VOICE` に対し、インターフェイス帯域の 10% を最優先（Low Latency）で割り当てよ。
```ios
policy-map PM-QUEUING
 class CM-VOICE
  priority percent 10
```

### 2. Web トラフィックの帯域保証 (CBWFQ)

**【問題】** クラス `CM-WEB` に対し、輻輳時に最低 30% の帯域を保証せよ。
```ios
policy-map PM-QUEUING
 class CM-WEB
  bandwidth percent 30
```

### 3. DSCP ベースの WRED 実装

**【問題】** デフォルトクラスにおいて、DSCP 値に基づいたランダム早期破棄を有効にせよ。
```ios
policy-map PM-AVOIDANCE
 class class-default
  random-detect dscp-based
```

### 4. WRED しきい値のカスタマイズ

**【問題】** DSCP AF41 のトラフィックに対し、キューが 32 パケットから破棄を開始し、64 パケットで 100% 破棄するようにせよ。
```ios
policy-map PM-AVOIDANCE
 class CM-DATA
  random-detect dscp af41 32 64 10
```

### 5. ECN (Explicit Congestion Notification) の併用

**【問題】** WRED と併せて、パケット破棄を回避するための ECN マーク機能を有効にせよ。
```ios
policy-map PM-AVOIDANCE
 class CM-DATA
  random-detect dscp-based
  random-detect ecn
```

### 6. キュー・リミットによるバッファ調整

**【問題】** 低速リンクにおいて、`class-default` のキューがすぐに一杯になる。保持できるパケット数を 300 に増やせ。
```ios
policy-map PM-BUFFERS
 class class-default
  queue-limit 300 packets
```

### 7. Bandwidth Remaining による余剰帯域分配

**【問題】** クラス `GOLD` と `SILVER` で、優先クラス以外の余った帯域を 7:3 の比率で分け合えるようにせよ。
```ios
policy-map PM-REM-BW
 class CM-GOLD
  bandwidth remaining percent 70
 class CM-SILVER
  bandwidth remaining percent 30
```

### 8. 階層型 QoS (HQoS) でのシェーピングとキューイング

**【問題】** 物理ポート全体を 1Mbps にシェーピングした上で、その中で音声に 100k の帯域を優先的に与えよ。
```ios
policy-map CHILD-QOS
 class CM-VOICE
  priority 100
!
policy-map PARENT-SHAPER
 class class-default
  shape average 1000000
  service-policy CHILD-QOS
```

### 9. NBAR2 と統合した輻輳管理

**【問題】** HTTP 通信のうち、Cisco.com へのアクセスのみを識別し、20% の帯域を優先的に割り当てよ。
```ios
class-map match-all CM-CISCO-WEB
 match protocol http host "Cisco.com"
!
policy-map PM-NBAR-QOS
 class CM-CISCO-WEB
  priority percent 20
```

### 10. 特定クラスでのテールドロップ防止検証

**【操作例】** `show policy-map interface` を使用し、WRED によるランダムドロップが発生しているかを確認せよ。
```ios
# show policy-map interface GigabitEthernet1
! 出力内の "Random drop" カウンタが増加していれば、WREDが正常に動作している。
```

### 11. 制御プレーン保護 (CoPP) でのキューしきい値

**【問題】** ルータの SSH 受信トラフィックに対し、キューしきい値を超えた場合にログを出力せよ。
```ios
policy-map type queue-threshold QT-POL
 class SSH_CLASS
  log
!
control-plane host
 service-policy type queue-threshold input QT-POL
```

### 12. デフォルト・フェア・キューイングの有効化

**【問題】** `class-default` 内でフローごとの公平な分配（Fair Queuing）を有効にせよ。
```ios
policy-map PM-FAIR
 class class-default
  fair-queue
```

---

## 🔗 参考リソース

### Cisco Live (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and IOS XE**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)

### Configuration ガイド
*   [**Cisco IOS XE 17.x Quality of Service Configuration Guide: Congestion Management**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conmgt/configuration/xe-17/qos-conmgt-xe-17-book.html)
*   [**Congestion Avoidance Configuration Guide (WRED)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conavd/configuration/xe-17/qos-conavd-xe-17-book.html)

### テクニカルドキュメント
*   [**Low Latency Queuing with Priority Percentage Support**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conmgt/configuration/15-mt/qos-conmgt-15-mt-book/qos-conmgt-llq-pps.html)
*   [**Understanding WRED and Congestion Avoidance**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-conmgt/10601-90.html)

---


## 📝 補足
- この学習メモは、CCIE EI 試験における「パケットをどのように並べ、どのように捨てるか」という論理的な制御を網羅しています。実技試験では、**`show policy-map interface`** の出力を迅速に分析し、意図したクラスでパケットがキューイングされ、かつドロップされるべきものが（テールドロップではなくWRED等で）処理されているかを確認することが合格への鍵となります。
