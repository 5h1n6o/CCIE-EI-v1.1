---
layout: default
title: 4.4-QoS
parent: 4-Infrastructure-Security-and-Services
nav_order: 4
---

# 4.4 Quality of Service

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint におけるエンタープライズネットワークのトラフィック制御・品質保証技術である **`4.4 Quality of Service (QoS)`**（DiffServ モデル, MQC パイプライン, Classification & Marking, Trust Boundary, Policing & Shaping [Token Bucket アルゴリズム], Congestion Management [LLQ / CBWFQ], Congestion Avoidance [WRED / ECN], HQoS [Hierarchical QoS]）の完全学習メモ。

---

## 📘 概要

* **機能概要:**
  * Quality of Service (QoS) は、ネットワーク上の限られた帯域資源を効率的に分配し、音声（Voice）、ビデオ（Video）、ミッションクリティカルデータ、およびベストエフォートトラフィックに対して、遅延（Delay）、ジッター（Jitter）、パケット損失（Packet Loss）、および帯域保証（Bandwidth Guarantee）の観点から差別化されたサービス品質を提供する技術体系である。
  * Cisco IOS XE においては、**MQC (Modular QoS CLI)** アーキテクチャを基盤とし、`class-map`（分類）、`policy-map`（アクション定義）、`service-policy`（インターフェイスバインド）の3段階で構成される。

* **利用目的:**
  * **リアルタイム通信の保護:** 遅延やジッターに極めて敏感な Voice (VoIP) パケットを最優先キュー（Priority Queue）へ収容し、超低遅延転送を実現する。
  * **帯域制御と平準化:** 特定アプリケーションによる帯域占有を防止し、業務トラフィック（ERP, Database 等）の最低帯域幅を保証する。
  * **ボトルネックでの輻輳制御:** WAN リンクやサブレート（Sub-rate）回線などの低速インターフェイスにおいて、パケットドロップを計画的に管理・回避する。

* **どのような場面で利用するか:**
  * WAN エッジルータにおける親ポリ・子ポリシーによる **HQoS (Hierarchical QoS)** 制御（Shape ＋ Queuing）。
  * キャンパススイッチにおける IP Phone / 端末接続ポートでの **Trust Boundary（信頼境界）** の確立と CoS / DSCP のリマッピング。
  * インターネット境界における **Policing（レート制限）** および DSCP マーキングの書き換え。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | MQC に基づくモジュール構造。L2 (CoS 802.1p) および L3 (DSCP / IP Precedence) ヘッダーによるトラフィック分類 |
| **用途** | Voice / Video の超低遅延転送、帯域保証、WAN ボトルネックでのパケット破棄制御、帯域超過トラフィックの制限 |
| **メリット** | トラフィックごとの厳格な QoS 保証、WRED による TCP グローバル同期（Global Synchronization）の回避 |
| **デメリット** | 帯域自体を増加させる技術ではなく、輻輳時（Bottleneck 発生時）にのみアクティブ化する非対称動作 |
| **対応機種** | Cisco Catalyst 9000 シリーズ (ASIC 構成), Cisco ISR 4000 / Catalyst 8000 (IOS XE ソフトウェア/ハードウェア QFP) |
| **制限事項** | シェーピング（Shaping）は Egress 方向のみ適用可能。Ingress 方向の Queuing はハードウェア ASIC 制約に依存 |
| **設計上の注意点** | VoIP トラフィック (EF) は帯域の 33% 以下に抑える。WRED は Drop-Sensitive なパケット（UDP等）には不適 |

---

## 🏗 動作原理

Cisco IOS XE における QoS 処理パイプラインは、パケットが物理/論理インターフェイスに入力されてから出力されるまで、以下の統一的な MQC 処理フレームワークに従って実行される。

```
[ Ingress Interface ]
         │
         ▼
┌─────────────────────────┐
│ Classification & Mark   │ ──► MQC Class-Map / NBAR2 による識別 ＆ DSCP/CoS 書き換え
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Trust Boundary Check    │ ──► Trust (CoS/DSCP) または Untrust (Re-Mark to 0) 判定
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Ingress Policing        │ ──► Single-Rate / Two-Rate Token Bucket によるレート制限
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Routing / Switching     │ ──► FIB テーブル検索 ＆ Egress インターフェイス決定
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Egress Shaping / Police │ ──► Token Bucket による送信レート整形 (Shaping)
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Congestion Avoidance    │ ──► WRED (Weighted Random Early Detection) 早期破棄
└─────────────────────────┘
         │
         ▼
┌─────────────────────────┐
│ Congestion Management   │ ──► LLQ (Priority Queue) ＆ CBWFQ (Bandwidth Queues)
└─────────────────────────┘
         │
         ▼
[ Egress Interface (Line) ]
```

### 1. Classification & Marking（分類とマーキング）
* **L2 Class of Service (CoS):** 802.1Q 802.1p ヘッダー内の 3 ビット領域（0〜7）。
* **L3 Differentiated Services Code Point (DSCP):** IPv4/IPv6 ToS/Traffic Class ヘッダー内の 6 ビット領域（0〜63）。
  * **EF (Expedited Forwarding):** DSCP 46 (101110) ── VoIP 音声メディア流。超低遅延・低ジッター・低損失クラス。
  * **AF (Assured Forwarding):** `AFxy` (x: Class 1-4, y: Drop Precedence 1-3)。例: `AF41` (DSCP 34) ── Video, `AF31` (DSCP 26) ── Call Signaling。
  * **CS (Class Selector):** `CS1`〜`CS7` (IP Precedence 互換)。例: `CS6` (DSCP 48) ── ルーティングプロトコル。

### 2. Token Bucket アルゴリズム（Policing & Shaping）
* **Single Rate Two-Color (1r2c):** CIR (Committed Information Rate) と Bc (Committed Burst) の単一バケット。Conform (Green) / Exceed (Red)。
* **Single Rate Three-Color (1r3c - RFC 2697):** CIR, Bc, Be (Excess Burst) の2バケット。Conform (Green) / Exceed (Yellow) / Violate (Red)。
* **Two Rate Three-Color (2r3c - RFC 2698):** CIR/Bc と PIR (Peak Information Rate)/Be の独立した2バケット。Conform (Green) / Exceed (Yellow) / Violate (Red)。

---

## ⚙ 動作シーケンス

```
1. Ingress Packet Arrival
   │
   ├──► [Step 1: Trust Check]
   │      - Trust 認証された場合 ──► 既存の CoS / DSCP 値を維持
   │      - Untrust の場合       ──► DSCP 0 (Default) へリセット、または MQC で再分類・マーク
   │
   ├──► [Step 2: Classification & Policing]
   │      - MQC class-map により 5-Tuple / NBAR2 / ACL で一致検索
   │      - Ingress Police 設定がある場合、Token Bucket で判定
   │          ├─ Conform ──► 送信継続 (または Mark 変更)
   │          ├─ Exceed  ──► DSCP Down-mark (例: AF41 -> AF42)
   │          └─ Violate ──► Drop (破棄)
   │
   ├──► [Step 3: Routing & Egress Selection]
   │      - FIB 参照により Egress Interface を選択
   │
   └──► [Step 4: Egress Shaping & Queuing]
          - Shape 設定がある場合: 超過パケットは Egress Buffer (Queue) にバッファリング
          - Congestion Avoidance: テールバッファ閾値に応じて WRED が事前ランダム破棄 (Drop)
          - Scheduling (Queuing):
              ├─ Strict Priority Queue (LLQ) ──► バッファから最優先で出庫 (VoIP)
              └─ CBWFQ Queues                ──► 設定された帯域比率 (bandwidth / bandwidth remaining) に応じて WRR/WFQ スケジューリング出庫
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint において特に重要なポイント
* **LLQ (Low Latency Queuing) の構築と制限:** `priority` コマンドで構成される最優先キュー。ポリシング帯域（CIR）の適切な設定（過剰割り当てによる他クラスの飢餓防止）。
* **CBWFQ (Class-Based Weighted Fair Queuing):** `bandwidth` (絶対値) と `bandwidth remaining percent` (残余帯域比率) の混在不可規則。
* **Class-Based Shaping ＋ HQoS (Hierarchical QoS):** WAN サブレート（例: 100Mbps 物理ポート上で 10Mbps 契約）に対する Egress Shaping（親ポリシー）と、その配下での LLQ/CBWFQ キューイング（子ポリシー）のネスティング設定。
* **NBAR2 (Network-Based Application Recognition):** `match protocol` による L7 アプリケーション（HTTP, Citrix, Webex 等）の動的分類。

### 2. ラボ試験で狙われる設定ミスと落とし穴
* **`priority` と `bandwidth` の単一ポリシー内混在エラー:** 親ポリシーで `priority` と `shape` を同時定義しようとする誤り（`priority` は子ポリシーのキューイングでのみ使用可能）。
* **`bandwidth remaining percent` の合計超過:** 子ポリシー内の各クラスの百分率合計が 100% を超えてエラーとなるコンフィグ。
* **WRED の `priority` クラスへの誤バインド:** 低遅延を保証する Priority Queue (`priority`) に対して WRED を適用することは不可（WRED は CBWFQ クラスにのみ適用可能）。
* **Switching 側の Voice VLAN Trust 設定漏れ:** Cisco IP Phone 接続ポートにおいて `trust device cisco-phone` や `qos trust cos` の未適用による Voice パケット (CoS 5 / DSCP EF) の平坦化（DSCP 0 への上書き）。

### 3. Verification Commands & Debugging
* `show policy-map interface <Interface>`: 最重要検証コマンド。各クラスの Packet Count, Match Bytes, Dropped Packets, Token Bucket の動作状況を一目・即座に確認可能。
* `show policy-map`: 定義されたポリシーマップの階層構造と適用コマンドの構文チェック。

---


## 🛠 設定方法

### 1. Classification, Marking & Queuing (LLQ / CBWFQ) 基本コンフィグ
```bash
! --- 1. Class-Map の定義 ---
class-map match-all CM_VOICE
 match dscp ef

class-map match-all CM_VIDEO
 match dscp af41 af42

class-map match-any CM_CRITICAL_DATA
 match dscp af31
 match access-group name ACL_CRITICAL

! --- 2. Policy-Map の定義 (キューイング ＆ マーキング) ---
policy-map PM_EGRESS_QUEUING
 class CM_VOICE
  priority 1000                    ! 1Mbps の Strict Priority Queue (LLQ)
 class CM_VIDEO
  bandwidth remaining percent 40   ! 残余帯域の 40% を割り当て
 class CM_CRITICAL_DATA
  bandwidth remaining percent 30   ! 残余帯域の 30% を割り当て
  random-detect dscp-prec-based    ! WRED の有効化
 class class-default
  bandwidth remaining percent 30   ! デフォルトクラスに残余帯域の 30%

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet0/0/1
 service-policy output PM_EGRESS_QUEUING
```

### 2. Hierarchical QoS (HQoS) - Shaping ＋ Sub-Queuing
```bash
! --- 子ポリシー (Queuing Policy) ---
policy-map PM_CHILD_QUEUING
 class CM_VOICE
  priority 500
 class CM_CRITICAL_DATA
  bandwidth remaining percent 70
 class class-default
  bandwidth remaining percent 30

! --- 親ポリシー (Shaping Policy) ---
policy-map PM_PARENT_SHAPING
 class class-default
  shape average 10000000           ! 10Mbps に平均シェーピング
  service-policy PM_CHILD_QUEUING   ! 子ポリシーのバインド

! --- インターフェイス適用 ---
interface GigabitEthernet0/0/2
 service-policy output PM_PARENT_SHAPING
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 注目ポイント |
| :--- | :--- | :--- |
| **QoS ポリシー適用状況・ドロップ数確認** | `show policy-map interface <Interface>` | 各クラスの `packets matched`, `offended packets`, `bytes dropped` カウンタ |
| **インターフェイスキュー状態確認** | `show interface <Interface>` | `Input queue`, `Output queue` のドロップ数 (`total output drops`) |
| **定義済み Policy-Map の構造確認** | `show policy-map` | クラス構成、優先度割り当て、ポリサー/シェーパー値 |
| **定義済み Class-Map の確認** | `show class-map` | 一致条件 (ACL, DSCP, NBAR2 プロトコル等) |
| **NBAR2 プロトコル統計確認** | `show ip nbar protocol-discovery` | インターフェイスを通過する L7 アプリケーション統計 |
| **QoS デバッグ (リアルタイム追跡)** | `debug qos mqc` | MQC パイプライン処理のデバッグ |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **VoIP 音声で音飛び・遅延が発生** | LLQ の `priority` 帯域超過によるポリシードロップが発生している | <code>show policy-map interface</code> | `priority` 設定値（CIR）を引き上げるか、不要な音声トラフィックを遮断 |
| **特定の低優先クラスでパケットドロップが多発** | CBWFQ 帯域割り当て不足、または Shaping 帯域（CIR）が絞られすぎている | <code>show policy-map interface</code> | `bandwidth remaining percent` の見直し、または WRED 導入 |
| **TCP 通信の全体的なスループットが低下** | Tail Drop による TCP グローバル同期（Global Synchronization）が発生 | <code>show interface</code> | CBWFQ クラスに `random-detect dscp-prec-based` (WRED) を適用 |
| **HQoS 設定時に CLI エラーが発生** | 親ポリシー内で `priority` または `bandwidth` を直接定義している | <code>show policy-map</code> | 親ポリシーは `shape` または `police` のみに制限し、キューイングは子ポリシーへ記述 |
| **IP Phone からの CoS 5 が DSCP 0 に上書きされる** | アクセススイッチ側で Trust 設定（`qos trust cos` 等）が欠落している | <code>show qos interface</code> | スイッチポートに `qos trust cos` または `trust device cisco-phone` を投入 |

---

## ⚠ 制限事項

* **方向の制限:** シェーピング (`shape`) は **Egress (送信) 方向のみ** サポートされる。Ingress (受信) 方向に対して `shape` を投入しようとすると CLI エラーとなる。
* **混在不可構文:** 同一 Policy-Map の異なるクラス間で `bandwidth <kbps>`（絶対値）と `bandwidth remaining percent`（相対比率）を混在させることは不可。
* **WRED の制約:** WRED は Priority Queue (`priority`) には適用不可。また、WRED は TCP のウィンドウ制御機構に依存するため、UDP トラフィックに対しては効果がなく単にランダムドロップとなる。

---

## 🔄 他技術との関連

* **IPsec VPN / GRE Tunnel:** カプセル化による L3 ヘッダー隠蔽対策として `qos pre-classify` コマンドを使用し、元の内部 IP ヘッダーの ToS/DSCP に基づいて GRE/IPsec トンネルインターフェイス上で MQC 評価を実行。
* **Control Plane Policing (CoPP):** ルータ CPU に宛てられる制御パケット（BGP, OSPF, SSH 等）を MQC クラス分類し、`police` コマンドで過剰トラフィックをドロップ・制限するセキュリティ統合。
* **Cisco SD-WAN:** Localized Policy / Centralized Data Policy 内で QoS Class/Queue マッピング、Shaping、Policing を定義し、Transport 網へ適用。

---

## 🧩 比較表

| 比較項目 | CoS (Class of Service) | DSCP (Differentiated Services Code Point) |
| :--- | :--- | :--- |
| **適用レイヤ** | Layer 2 (802.1Q VLAN Tag) | Layer 3 (IPv4 ToS / IPv6 Traffic Class) |
| **ビット長 / 値の範囲** | 3 ビット (0 〜 7) | 6 ビット (0 〜 63) |
| **保持範囲** | L2 スイッチング網内（ルータで L3 転送されると消滅） | L3 ネットワーク全体でエンドツーエンド保持 |
| **標準分類** | 5: Voice, 4: Video, 0: Best Effort | EF (46), AF41 (34), AF31 (26), CS3 (24), BE (0) |

| 比較項目 | Policing (ポリシング) | Shaping (シェーピング) |
| :--- | :--- | :--- |
| **動作メカニズム** | 超過パケットを即座に **Drop** または **Down-mark** | 超過パケットを **Egress Buffer (Queue) に保持** して遅延送信 |
| **適用可能方向** | Ingress ＆ Egress | **Egress 方向のみ** |
| **ネットワーク影響** | 遅延を増加させないがパケット損失が発生 | パケット損失を抑えるがジッター・遅延が増加 |
| **主用途** | 契約帯域超過の制限、不正アクセス制御 | WAN リンクサブレート整合、ボトルネックでの平滑化 |

---

## 💡 ベストプラクティス

1. **RFC 4594 準拠の 12 クラスモデルの採用:** Voice (EF), Interactive Video (AF41), Streaming Video (AF31), Call Signaling (CS3), Network Control (CS6) などの標準 DSCP マーキングを策定する。
2. **LLQ の帯域制限:** Priority Queue (`priority`) の帯域指定は、リンク全帯域の 33% を超えないように設計し、音声バースト時の他データクラスの餓死（Starvation）を防止する。
3. **HQoS による サブレート保護:** WAN 回線が物理速度（例: 100Mbps）より契約速度（例: 20Mbps）が低い場合、必ず Egress で 20Mbps の `shape average` を適用した上で配下に LLQ / CBWFQ を構成する。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: CoS 802.1p から DSCP へのマッピング ＆ Trust Boundary 構築
* **問題:** スイッチの Gi1/0/1 ポートに接続された IP Phone からの受信パケットに対して、CoS 5 を DSCP EF (46) に、CoS 3 を DSCP CS3 (24) にマッピングして信頼（Trust）評価せよ。
* **要件:**
  * インターフェイスレベルで `qos trust cos` を構成すること。
  * CoS-to-DSCP マッピングテーブルを適用すること。
* **設定例:**
```bash
! 1. CoS to DSCP マッピングマップの定義
qos map cos 5 to dscp 46
qos map cos 3 to dscp 24
qos map cos 0 to dscp 0

! 2. アクセスポートでの Trust 設定
interface GigabitEthernet1/0/1
 switchport mode access
 switchport voice vlan 100
 qos trust cos
```
* **検証方法:**
  * IP Phone から音声パケットを送信し、`show qos interface GigabitEthernet1/0/1` で Trust 状態および CoS-to-DSCP 変換カウンタを確認。

---

### ラボ 2: Voice / Video / Mission-Critical Data の 3 クラス分類 ＆ MQC マーキング
* **問題:** インバウンドパケットを分析し、VoIP (UDP 16384-32767) を DSCP EF、Video (UDP 5000-5050) を DSCP AF41、データ (10.1.0.0/16 宛て) を DSCP AF31 にマークせよ。
* **要件:**
  * Extended ACL を用いて MQC Class-map を定義すること。
  * Ingress インターフェイスにマーキングポリシーをバインドすること。
* **設定例:**
```bash
! 1. ACL の定義
ip access-list extended ACL_VOICE
 permit udp any any range 16384 32767
ip access-list extended ACL_VIDEO
 permit udp any any range 5000 5050
ip access-list extended ACL_DATA
 permit ip any 10.1.0.0 0.0.255.255

! 2. Class-Map の定義
class-map match-all CM_MARK_VOICE
 match access-group name ACL_VOICE
class-map match-all CM_MARK_VIDEO
 match access-group name ACL_VIDEO
class-map match-all CM_MARK_DATA
 match access-group name ACL_DATA

! 3. Policy-Map の定義 (Marking)
policy-map PM_INGRESS_MARKING
 class CM_MARK_VOICE
  set dscp ef
 class CM_MARK_VIDEO
  set dscp af41
 class CM_MARK_DATA
  set dscp af31

! 4. インターフェイスバインド
interface GigabitEthernet0/0/0
 service-policy input PM_INGRESS_MARKING
```
* **検証方法:**
  * 該当ポートから UDP パケットを送出し、`show policy-map interface GigabitEthernet0/0/0 input` で Match パケット数と Set DSCP カウンタの増加を確認。

---

### ラボ 3: LLQ (Low Latency Queuing) ＋ CBWFQ キューイング構成
* **問題:** Egress インターフェイス Gi0/0/1 において、DSCP EF (Voice) に 2Mbps の Strict Priority Queue (LLQ) を割り当て、DSCP AF41 (Video) に残余帯域の 50%、DSCP AF31 (Data) に残余帯域の 30% を割り当てよ。
* **要件:**
  * `priority` コマンドで LLQ を構成すること。
  * `bandwidth remaining percent` コマンドで CBWFQ を構成すること。
* **設定例:**
```bash
! 1. Class-Map 定義
class-map match-all CM_Q_VOICE
 match dscp ef
class-map match-all CM_Q_VIDEO
 match dscp af41
class-map match-all CM_Q_DATA
 match dscp af31

! 2. Policy-Map 定義 (LLQ + CBWFQ)
policy-map PM_EGRESS_LLQ
 class CM_Q_VOICE
  priority 2000
 class CM_Q_VIDEO
  bandwidth remaining percent 50
 class CM_Q_DATA
  bandwidth remaining percent 30
 class class-default
  bandwidth remaining percent 20

! 3. インターフェイスバインド
interface GigabitEthernet0/0/1
 service-policy output PM_EGRESS_LLQ
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1 output` を実行し、`priority` キューおよび CBWFQ 各クラスの送信パケット数とドロップ数を確認。

---

### ラボ 4: Single-Rate Three-Color Policing (1r3c - RFC 2697) レート制限構成
* **問題:** インターフェイス Gi0/0/0 に入る FTP 通信に対し、CIR 1Mbps、Bc 32KB、Be 64KB の Single-Rate Three-Color ポリサーを適用せよ。適合時はそのまま転送、超過時は DSCP AF12 にダウンマーク、違反時はドロップさせよ。
* **要件:**
  * `police cir 1000000 bc 32000 be 64000 conform-action transmit exceed-action set-dscp-transmit af12 violate-action drop` を設定すること。
* **設定例:**
```bash
! 1. ACL ＆ Class-Map 定義
ip access-list extended ACL_FTP
 permit tcp any any eq 21
 permit tcp any any eq 20
class-map match-all CM_FTP
 match access-group name ACL_FTP

! 2. Policy-Map 定義 (1r3c Police)
policy-map PM_POLICE_1R3C
 class CM_FTP
  police cir 1000000 bc 32000 be 64000
   conform-action transmit
   exceed-action set-dscp-transmit af12
   violate-action drop

! 3. インターフェイス適用
interface GigabitEthernet0/0/0
 service-policy input PM_POLICE_1R3C
```
* **検証方法:**
  * 2Mbps の FTP トラフィックを送出し、`show policy-map interface GigabitEthernet0/0/0 input` で `conformed`, `exceeded`, `violated` パケット数を検証。

---

### ラボ 5: Two-Rate Three-Color Policing (2r3c - RFC 2698) レート制限構成
* **問題:** CIR 2Mbps (Bc 64KB)、PIR 4Mbps (Be 128KB) の Two-Rate Three-Color ポリサーを構成し、CIR 以下は転送、PIR までは DSCP AF22 へダウングレード、PIR 超過分は Drop せよ。
* **要件:**
  * `police cir 2000000 bc 64000 pir 4000000 be 128000` 構文を使用すること。
* **設定例:**
```bash
class-map match-all CM_DATA_2R3C
 match dscp af21

policy-map PM_POLICE_2R3C
 class CM_DATA_2R3C
  police cir 2000000 bc 64000 pir 4000000 be 128000
   conform-action transmit
   exceed-action set-dscp-transmit af22
   violate-action drop

interface GigabitEthernet0/0/0
 service-policy input PM_POLICE_2R3C
```
* **検証方法:**
  * 5Mbps のトラフィックを注入し、`show policy-map interface GigabitEthernet0/0/0` で各アクションの動作状況を確認。


### ラボ 6: Class-Based Shaping (CIR / Bc / Be) ＋ Egress Queuing 構成
* **問題:** 100Mbps 物理ポート Gi0/0/2 において、平均送信レートを 10Mbps (CIR) に制限（シェーピング）し、パケット超過時はバッファリング処理を行わせよ。
* **要件:**
  * `shape average 10000000` を使用すること。
* **設定例:**
```bash
policy-map PM_SHAPING_BASE
 class class-default
  shape average 10000000 40000 40000   ! CIR 10Mbps, Bc 40Kb, Be 40Kb

interface GigabitEthernet0/0/2
 service-policy output PM_SHAPING_BASE
```
* **検証方法:**
  * 50Mbps 相当のパケットを送出し、`show policy-map interface GigabitEthernet0/0/2 output` で `Target Rate 10000000 bps` となり、超過分が Queue 内に保持（Delayed）されることを確認。

---

### ラボ 7: Hierarchical QoS (HQoS) - 親ポリシー Shaping ＋ 子ポリシー LLQ/CBWFQ ネスティング
* **問題:** 100Mbps WAN リンク上で、全帯域を 20Mbps に平均シェーピング（親ポリシー）し、その内部で Voice に 2Mbps LLQ、Video に 10Mbps CBWFQ、Data に残りの帯域を割り当てる子ポリシーを構成せよ。
* **要件:**
  * 親ポリシーに `shape average 20000000` を設定し、`service-policy` コマンドで子ポリシーをネスティングバインドすること。
* **設定例:**
```bash
! 1. 子クラスマップおよび子ポリシーの定義
class-map match-all CM_HQOS_VOICE
 match dscp ef
class-map match-all CM_HQOS_VIDEO
 match dscp af41

policy-map PM_HQOS_CHILD
 class CM_HQOS_VOICE
  priority 2000
 class CM_HQOS_VIDEO
  bandwidth 10000
 class class-default
  fair-queue

! 2. 親ポリシーの定義 (Shaping + Child Policy)
policy-map PM_HQOS_PARENT
 class class-default
  shape average 20000000
  service-policy PM_HQOS_CHILD

! 3. インターフェイス適用
interface GigabitEthernet0/0/3
 service-policy output PM_HQOS_PARENT
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/3 output` を実行し、親ポリシー配下に子ポリシーのクラス分類と優先度キューが階層表示されていることを確認。

---

### ラボ 8: NBAR2 (Network-Based Application Recognition) アプリケーション識別 ＆ Marking 構成
* **問題:** NBAR2 プロトコルエンジンを用いて、`citrix` および `youtube` 通信を識別し、`citrix` を DSCP AF31、`youtube` を DSCP CS1 (Scavenger) にマークせよ。
* **要件:**
  * `match protocol citrix`, `match protocol youtube` を使用すること。
* **設定例:**
```bash
! 1. Class-Map (NBAR2 Protocol Match)
class-map match-all CM_NBAR_CITRIX
 match protocol citrix
class-map match-all CM_NBAR_YOUTUBE
 match protocol youtube

! 2. Policy-Map (Marking)
policy-map PM_NBAR_MARK
 class CM_NBAR_CITRIX
  set dscp af31
 class CM_NBAR_YOUTUBE
  set dscp cs1

! 3. インターフェイス適用
interface GigabitEthernet0/0/0
 ip nbar protocol-discovery
 service-policy input PM_NBAR_MARK
```
* **検証方法:**
  * `show ip nbar protocol-discovery` でアプリケーションの追跡状況を確認し、`show policy-map interface GigabitEthernet0/0/0` で Mark カウンタを確認。

---

### ラボ 9: WRED (Weighted Random Early Detection) 帯域輻輳回避 ＋ ECN 構成
* **問題:** データクラス（CM_DATA）において、DSCP ベースの WRED を有効化し、さらに ECN (Explicit Congestion Notification) 通知を有効化して、パケット破棄の前に送信元に輻輳通知を行わせよ。
* **要件:**
  * `random-detect dscp-prec-based` および `random-detect ecn` を設定すること。
* **設定例:**
```bash
class-map match-all CM_WRED_DATA
 match dscp af11 af12 af13

policy-map PM_WRED_ECN
 class CM_WRED_DATA
  bandwidth percent 50
  random-detect dscp-prec-based
  random-detect ecn

interface GigabitEthernet0/0/1
 service-policy output PM_WRED_ECN
```
* **検証方法:**
  * 輻輳を発生させ、`show policy-map interface GigabitEthernet0/0/1` で `WRED mark/drop` カウンタおよび `ECN marked` カウンタの増加を確認。

---

### ラボ 10: IPsec VPN / GRE トンネル環境における `qos pre-classify` 統合構成
* **問題:** GRE トンネル（Tunnel0）を通るトラフィックに対し、カプセル化前の内部 IP ヘッダー情報（DSCP/IP）に基づいて物理 WAN インターフェイス（Gi0/0/0）で QoS 分類およびキューイングを行わせよ。
* **要件:**
  * トンネルインターフェイスに `qos pre-classify` コマンドを設定すること。
* **設定例:**
```bash
! 1. GRE トンネルインターフェイスで Pre-Classify を有効化
interface Tunnel0
 ip address 10.255.255.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 192.168.1.2
 qos pre-classify

! 2. 物理インターフェイスに Egress QoS ポリシーを適用
interface GigabitEthernet0/0/0
 service-policy output PM_EGRESS_LLQ
```
* **検証方法:**
  * トンネル経由で VoIP (EF) 通信を発生させ、`show policy-map interface GigabitEthernet0/0/0 output` で暗号化パケットが正しく `CM_Q_VOICE` クラスにマッチして優先出力されることを確認。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** ルータ R1 の WAN ポート Gi0/0/1 にて QoS ポリシーを適用したところ、Voice 通信で激しい音飛びが発生した。`show policy-map interface` を確認すると、`CM_VOICE` クラスの `offended packets` (Drop カウンタ) が大量にカウントアップされていた。コンフィグは以下の通り。
```bash
policy-map PM_QOS
 class CM_VOICE
  priority 64
```
**設問:** この障害の根本的原因と、適切な修正手順を述べよ。

* **解答:**
  * **原因:** `priority 64` 設定により、Voice クラス用の Priority Queue (LLQ) の上限帯域が僅か 64 kbps に制限されているため。実際の VoIP トラフィックが 64 kbps を超えたため、ポリサーにより超過音声パケットがドロップされた。
  * **修正手順:** Voice トラフィックの最大生成帯域（例: G.711 コーデック 10 セッション分 ＝ 約 1 Mbps）に合わせて `priority 1000` (1Mbps) などに設定値を拡張修正する。

---

### 問 2 (Design & Behavior)
**シナリオ:** 大規模ネットワークにおいて、WRED を Voice (DSCP EF) クラスに適用する構成案が提出された。
**設問:** この設計の妥当性を評価し、技術的理由を述べよ。

* **解答:**
  * **評価:** **不適切（非推奨・無効）**。
  * **技術的理由:** Voice トラフィックは UDP プロトコルであり、遅延・ジッターに対して極めて過敏である。WRED は TCP のウィンドウサイズ縮小機構を利用して再送制御を行うため、UDP に対して WRED を適用すると単なるランダムドロップが発生し、音声品質が著しく劣化する。Voice クラスには LLQ (`priority`) を適用し、バッファドロップを発生させない帯域設計を行うべきである。

---

### 問 3 (HQoS / 構文トラブルシューティング)
**シナリオ:** 親ポリシー `PM_PARENT` にて平均 10Mbps の Shaping を設定し、配下の子ポリシー `PM_CHILD` で LLQ および CBWFQ を設定しようとしたところ、以下のエラーが出力されてコンフィグ投入に失敗した。
`Configuration failed: Priority command not allowed in parent policy`
**設問:** エラーが発生した原因と、正しいコンフィグ構造を示せ。

* **解答:**
  * **原因:** 親ポリシー `PM_PARENT` の `class-default` 直下に `priority` コマンドを直接記述しようとしたため。HQoS において `priority` や `bandwidth` などのキューイングコマンドは子ポリシー（Child Policy）内に記述しなければならない。
  * **修正構造:**
```bash
policy-map PM_CHILD
 class CM_VOICE
  priority 1000

policy-map PM_PARENT
 class class-default
  shape average 10000000
  service-policy PM_CHILD
```

---

### 問 4 (実務・トラブルシューティング / Policing)
**シナリオ:** Single-Rate Three-Color Policing (RFC 2697) を設定した。Bc (Committed Burst) を過小に設定したところ、CIR 以下のトラフィック量であるにもかかわらず `exceed-action` (Yellow) が発生した。
**設問:** なぜ CIR 以下で Exceed が発生するのか、トークンバケットの動作原理に基づき説明せよ。

* **解答:**
  * **理由:** トークンバケットアルゴリズムでは、バースト的にパケットが到着した際、バケットに蓄積されているトークン量（最大 Bc）がパケットサイズ未満であると、平均レートが CIR 以下であってもトークン不足となり Exceed 判定となる。バースト通信を許容するためには、Bc の値を少なくとも RTT 間隔またはパケットの最大 MTU (例: 1500 バイトの数倍) 以上に拡大設定する必要がある。

---

### 問 5 (コンフィグ実装)
**シナリオ:** インターフェイス Gi0/0/2 の全送信帯域（100Mbps）のうち、残余帯域に対して `CM_DATA_A` に 60%、`CM_DATA_B` に 40% を配分する MQC コンフィグを作成せよ。

* **解答:**
```bash
policy-map PM_BANDWIDTH_SHARE
 class CM_DATA_A
  bandwidth remaining percent 60
 class CM_DATA_B
  bandwidth remaining percent 40

interface GigabitEthernet0/0/2
 service-policy output PM_BANDWIDTH_SHARE
```

---

## 🔗 参考リソース

* Cisco Live: Enterprise QoS Design and Best Practices (BRKRST-2043)
* Cisco Configuration Guide: Quality of Service Solutions Configuration Guide, Cisco IOS XE
* Cisco Command Reference: QoS Command Reference, Cisco IOS XE
* Cisco Validated Design (CVD): Quality of Service Design Guide
* Cisco Technical Notes: Understanding Quality of Service on Cisco IOS XE

---

## 📝 補足（Notes）

### 1. QoS 評価順序メモ
* Ingress: Classification -> Re-Marking -> Ingress Policing
* Egress: Shaping -> WRED (Congestion Avoidance) -> Queuing (LLQ / CBWFQ) -> Dequeue to Physical Medium

### 2. 注意点
* **LLQ の過剰割り当て禁止:** Priority Queue は最優先処理されるため、CIR 設定を超えた場合にポリシングを行わないと、他クラスのトラフィックが完全にドロップ（餓死）する。ラボ試験では必ず適切な帯域制限値を設定すること。


