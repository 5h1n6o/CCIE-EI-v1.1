---
layout: default
title: 4.4.f-Congestion-management
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 6
---

# 4.4.f Congestion management and avoidance

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.4 Quality of Service` における、輻輳管理（Congestion Management: キューイング機構 LLQ / CBWFQ / WFQ）および輻輳回避（Congestion Avoidance: 早期ランダム破棄 WRED / 明示的輻輳通知 ECN / ハードウェア Tx-Ring / HQoS キューイング）の完全構造化学習メモ。

---

## 📘 概要

ネットワークインフラストラクチャにおける**輻輳管理（Congestion Management）**および**輻輳回避（Congestion Avoidance）**は、WAN 回線やスターバースト通信によって Egress インターフェイスの物理帯域（ラインレート）を超えるトラフィックが集中した際、パケットの遅延（Latency）・ジッター（Jitter）・パケットドロップ（Packet Loss）を制御し、ミッションクリティカルなアプリケーション（VoIP 音声、ビデオ会議、インバンド制御通信）の通信品質を保証するための定量的品質制御機構である。

* **輻輳管理 (Congestion Management - キューイング):**
  * **目的:** インターフェイスが輻輳状態（Tx-Ring / Software Queue が満杯状態）に陥った際、単なる先着順（FIFO）ではなく、トラフィックの優先度（Class-Based）に応じたキュー（Queue）へ振り分け、スケジューリングアルゴリズム（LLQ / CBWFQ）に従って Egress 出力順序を制御する。
  * **適用場面:** WAN エッジルータ、LAN スイッチの Egress ポート、HQoS (Hierarchical QoS) サブレート回線境界。
* **輻輳回避 (Congestion Avoidance - 予防的破棄):**
  * **目的:** ソフトウェアキューが完全に満杯（Tail Drop）になる前に、DSCP / IP Precedence の優先度に応じて確率的にパケットを先行ドロップ（WRED）するか、ヘッダーに輻輳フラグを付与（ECN）することで、TCP 送信側のウィンドウサイズ（Congestion Window）を制御し、**TCP グローバル同期（Global Synchronization）**による劇的な帯域低下を防止する。
  * **適用場面:** コア/WAN ルータの Egress CBWFQ キュー（特に TCP トラフィック主体の AF クラス/Default クラス）。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主要技術** | LLQ (Low Latency Queuing), CBWFQ (Class-Based WFQ), WRED (Weighted RED), ECN (Explicit Congestion Notification) |
| **作用方向** | **Egress (送信方向) 限定**（Ingress にはキューイング/輻輳回避は適用不可） |
| **ハードウェア要件** | Tx-Ring（Hardware Queue）と Software Queue（MQC Queuing）の 2 段階バッファ構造 |
| **LLQ の特徴** | `priority` コマンドで指定。Strict Priority Queue (SPQ) として最優先送信。Policer が内蔵され Starvation を防止 |
| **CBWFQ の特徴** | `bandwidth` または `bandwidth remaining percent` で割り当て。WFQ スケジューリングで公平かつ保証制御 |
| **WRED の特徴** | Tail Drop を回避し、TCP グローバル同期を防止。DSCP または IP Precedence の値に応じてドロップ確率カーブを個別定義 |
| **ECN の特徴** | RFC 3168 準拠。WRED 閾値到達時にパケットをドロップせず IP ヘッダーの ECN ビット (CE: 11) を書き換えて TCP 送信者へ通知 |
| **設計上の注意点** | LLQ (Strict Priority) に割り当てる帯域はインターフェイス全帯域の 33% (推奨)〜50% (最大) に抑え、他クラスの餓死を防ぐ |

---

## 🏗 動作原理

Cisco IOS XE におけるパケット送信パイプラインは、**Hardware Queue (Tx-Ring)** と **Software Queue (MQC Queuing)** の 2 段階構造で管理される。

### 1. Hardware Queue (Tx-Ring) と Software Queue の関係

```
[ Router Internal Switching (CEF) ]
                │
                ▼
      [ Software Queue Check ]
         │
         ├─── (インターフェイス非輻輳時: Tx-Ring に空きあり)
         │       │
         │       ▼
         │    [ Tx-Ring (Hardware FIFO) ] ───► [ Physical Line (Egress) ]
         │
         └─── (インターフェイス輻輳時: Tx-Ring 満杯)
                 │
                 ▼
              [ MQC Software Queue (LLQ / CBWFQ) ]
                 │
                 ├──► [ Priority Queue (LLQ: Voice / Video) ] ────┐ (最優先送信)
                 ├──► [ CBWFQ Class 1 (Mission Critical) ] ──────┼──► [ Schedule to Tx-Ring ]
                 ├──► [ CBWFQ Class 2 (Transactional) ] ─────────┤
                 └──► [ Class-Default (WRED / ECN 適用) ] ──────┘
```

1. **非輻輳時 (Non-Congested):**
   * CEF によりスイッチングされたパケットは、Software Queue を一切経由せず、直接 Hardware Queue (**Tx-Ring**) に入って即座に物理ラインへ送出される。この状態では QoS キューイングアルゴリズムは作動しない。
2. **輻輳発生時 (Congested):**
   * 物理回線の送信速度よりパケット発生速度が上回ると、Tx-Ring が即座に満杯になる。
   * Tx-Ring が満杯になると、Cisco IOS XE はパケットを **Software Queue (MQC Policy-Map)** へ一時蓄積する。
   * MQC スケジューラは、**LLQ (Strict Priority)** を最優先で Tx-Ring へ搬送し、続いて **CBWFQ** の重み（Weight）に応じて各クラスのパケットを Tx-Ring へ割り当てる。

### 2. WRED ＆ ECN の早期ドロップカーブ

Tail Drop（末端一括ドロップ）が発生すると、複数の TCP セッションが一斉に再送タイムアウトを起こし、TCP ウィンドウサイズを縮小（TCP グローバル同期）させて回線利用率が著しく低下する。WRED はバッファ占有量に応じて段階的にパケットをドロップする。

```
Drop
Probability
 100% ┼                                                ┌───────── (Max Threshold 超越: 100% Tail Drop)
      │                                               │
      │                                 /─────────────┘
  P_max ┼                              /  (Mark/Drop Probability Denominator: 例 1/10)
      │                            /
      │                          /  <--- ECN 有効時はここでパケット破棄せず
      │                        /         IP ヘッダーの ECN (CE: 11) をセット
      │                      /
   0% ┼─────────────────────┴───────────────────────────
      0                Min_Thresh                   Max_Thresh         Buffer Size
```

---

## ⚙ 動作シーケンス

パケットが Egress インターフェイスに入力されてから送信されるまでの詳細処理シーケンス：

1. **Class-Map マッチング (Classification):**
   * Egress パケットは MQC `policy-map` 内の `class-map` 条件（DSCP, CoS, ACL, NBAR2）と順番に照合される。
2. **WRED / ECN / Tail Drop 判定 (Congestion Avoidance):**
   * 対象クラスの Software Queue 長（Queue Depth）がチェックされる。
   * **Queue < Min-Threshold:** パケットはそのまま Queue へ格納される。
   * **Min-Threshold <= Queue <= Max-Threshold:** 
     * **WRED のみ:** 設定されたドロップ確率（`mark-probability-denominator`）に基づき、確率的にパケットをドロップ。
     * **WRED + ECN 有効:** TCP SYN/ACK の ECN サポートが確認された場合、パケットを**ドロップせず**、IP ヘッダーの ECN ビットを `11` (Congestion Experienced: CE) に書き換えて Queue へ格納。
   * **Queue > Max-Threshold:** 100% の確率でパケットをドロップ（Tail Drop）。
3. **Software Queue 振分け (Queuing):**
   * **`priority` (LLQ クラス):** Strict Priority Queue へ挿入。Policer バケットにより CIR 制限内であるかチェック（超過分は Drop または Normal Queue 送り）。
   * **`bandwidth` / `bandwidth remaining percent` (CBWFQ クラス):** 各クラス専用の FIFO キューへ挿入。
4. **Tx-Ring 搬送スケジューリング (Scheduling):**
   * Strict Priority Queue にパケットが存在する限り、最優先で Tx-Ring の空きスロットへ転送。
   * Strict Priority Queue が空になると、CBWFQ キュー群から設定された帯域比率（Weight）に従ってラウンドロビン方式で Tx-Ring へパケットを割り当て。
5. **物理送信:**
   * Tx-Ring のパケットが物理トランシーバーから出力される。


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 Practical Exam（ラボ試験）において、`4.4.f Congestion management and avoidance` は **必ず自力で完全構築・トラブルシューティングできなければならない最重要トピック** である。

### 1. ラボ試験で頻出の問われ方・要件パターン

1. **Multi-Level LLQ (Dual-Priority Queue) の構築:**
   * **要件:** 「Voice (DSCP EF) に Strict Priority 512kbps を割り当て、Interactive Video (DSCP AF41) に Strict Priority Level 2 1024kbps を割り当てよ。」
   * **設定:** `priority level 1 512` および `priority level 2 1024` (または `priority 512` と `priority level 2 1024`)。
2. **残余帯域比率 (`bandwidth remaining percent`) による分配:**
   * **要件:** 「Priority クラスを除いた残りの利用可能帯域のうち、Class-A に 40%、Class-B に 30%、Class-C に 20% を割り当てよ。」
   * **ポイント:** `bandwidth` (絶対値) ではなく **`bandwidth remaining percent`** を指定する。全クラスの合計が 100% を超えてはならない。
3. **WRED + ECN 連携による TCP 輻輳回避:**
   * **要件:** 「Class-Default において DSCP ベースの WRED を有効化し、AF11 (Min 32, Max 40, Drop 10) のカスタム閾値を設定せよ。さらに、パケットをドロップさせる代わりに ECN 通知を送信元へ送出するよう構成せよ。」
   * **設定:**
     ```bash
     policy-map PM_EGRESS
      class class-default
       random-detect dscp-prec-based
       random-detect dscp af11 32 40 10
       random-detect ecn
     ```
4. **Tx-Ring Tuning (Hardware Queue 調整):**
   * **要件:** 「低速シリアル/サブレート回線において、Software Queue (LLQ) の優先制御を即座に効かせるため、ハードウェアリングバッファの深度を最小（4 パケット）に調整せよ。」
   * **設定:** インターフェイス配下で `tx-ring-limit 4`。

### 2. ラボ試験での定番「ハマりポイント」と落とし穴

* **落とし穴 1: `bandwidth` の合計超過エラー**
  * `bandwidth` (絶対値) の合計は、標準でインターフェイス帯域の 75% を超えることができない（残り 25% は L2/L3 制御パケットおよび `class-default` 用に自動確保される）。75% を超える帯域を割り当てる場合は、インターフェイス配下で **`max-reserved-bandwidth 100`** を手動投入する必要がある。
* **落とし穴 2: 親ポリシー (Parent Policy) 内での `priority` 記述エラー**
  * HQoS (親 Policy `shape average`) を構成する際、親 Policy 内で `priority` コマンドを記述すると CLI エラーとなる。`priority` や `bandwidth` は**必ず子 Policy (Child Policy) 内に記述**し、親 Policy には `shape` と `service-policy <CHILD>` のみを設定しなければならない。
* **落とし穴 3: WRED と `priority` クラスの競合**
  * WRED (`random-detect`) は **`priority` クラス（LLQ）へ適用することはできない** (CLI で拒否される)。WRED は遅延・ジッターに敏感な音声用 LLQ ではなく、パケットドロップに強い TCP 通信（CBWFQ または Class-Default）に対して適用する。
* **落とし穴 4: `random-detect dscp-prec-based` の切り替え忘れ**
  * デフォルトの `random-detect` は IP Precedence ベースで動作する。要件で DSCP ベースの WRED が指定されている場合、`random-detect dscp-prec-based` を投入しないと `random-detect dscp af11 ...` コマンドが認識されない。

---

## 🛠 設定方法

### 1. 標準的な LLQ + CBWFQ + WRED + ECN 複合コンフィグ例

```bash
! --- 1. Class-Map の定義 ---
class-map match-any CM_VOICE
 match dscp ef
 match dscp cs5

class-map match-any CM_VIDEO
 match dscp af41
 match dscp af42

class-map match-any CM_DATA_CRITICAL
 match dscp af31
 match dscp af32

! --- 2. Policy-Map の定義 (LLQ + CBWFQ + WRED + ECN) ---
policy-map PM_QUEUING_POLICY
 class CM_VOICE
  priority level 1 512
 class CM_VIDEO
  priority level 2 1024
 class CM_DATA_CRITICAL
  bandwidth remaining percent 40
  queue-limit 128 packets
 class class-default
  bandwidth remaining percent 60
  random-detect dscp-prec-based
  random-detect dscp af11 32 40 10
  random-detect dscp af12 24 40 10
  random-detect ecn

! --- 3. インターフェイスへのバインド ＆ Tx-Ring 調整 ---
interface GigabitEthernet0/0/1
 description WAN_Egress_Interface
 max-reserved-bandwidth 100
 tx-ring-limit 16
 service-policy output PM_QUEUING_POLICY
```

### 2. HQoS (Hierarchical QoS) サブレート回線での LLQ + CBWFQ コンフィグ例

```bash
! --- 子ポリシー (Child Policy: クラス別キューイング) ---
policy-map PM_CHILD_QUEUING
 class CM_VOICE
  priority 256
 class CM_DATA_CRITICAL
  bandwidth remaining percent 50
 class class-default
  bandwidth remaining percent 50

! --- 親ポリシー (Parent Policy: WAN 契約帯域への Shaping) ---
policy-map PM_PARENT_SHAPE
 class class-default
  shape average 10000000
  service-policy PM_CHILD_QUEUING

! --- 物理インターフェイスへの適用 ---
interface GigabitEthernet0/0/2
 service-policy output PM_PARENT_SHAPE
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 確認ポイント |
| :--- | :--- | :--- |
| **QoS 統計・キュー監視** | `show policy-map interface <I/F>` | 各クラスのパケット数、ドロップ数、LLQ Policer ドロップ数、キュー長 |
| **WRED / ECN 統計確認** | `show policy-map interface <I/F> class <CLASS>` | WRED ドロップ数、ECN マーク数 (Marked Packets) |
| **Hardware Queue 確認** | `show controllers GigabitEthernet <I/F>` | Tx-Ring の制限値 (Limit) と現在の占有カウント |
| **インターフェイス予約帯域確認** | `show interface <I/F>` | `Bandwidth` 設定値、QoS 予約帯域 (Reserved Bandwidth) |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **VoIP 音声パケットがドロップする** | LLQ の Policer 帯域 (`priority`) 不足により、超過分が内蔵ポリサーでドロップされている | `show policy-map interface` (Priority Superceeded / Drop カウンタ) | `priority` 帯域を実際のパケットレートに合わせて増枠する |
| **`bandwidth` 設定時に CLI エラー発生** | 全クラスの `bandwidth` 合計がインターフェイス帯域の 75% を超過した | `show interface` | `max-reserved-bandwidth 100` を投入するか、`bandwidth remaining percent` に変更する |
| **WRED が発動せず Tail Drop が起きる** | トラフィックが `Min-Threshold` に達していない、または `random-detect dscp-prec-based` が未投入 | `show policy-map interface` (WRED stats) | `random-detect dscp-prec-based` を確認し、閾値を調整する |
| **ECN が機能せずパケットが破棄される** | 端点ホスト（TCP 送信元/宛先）が ECN (RFC 3168) 非対応、または `random-detect ecn` が未設定 | `show policy-map interface` (ECN marked) | `random-detect ecn` の投入を確認し、ホスト側 OS の ECN 有効化を確認する |
| **LLQ を設定したのに遅延（Jitter）が改善しない** | Tx-Ring (Hardware Queue) の深度が深すぎ（例: 256）、Software Queue の優先制御が遅れている | `show controllers GigabitEthernet` | インターフェイス配下で `tx-ring-limit 4` や `16` に小さく調整する |


## ⚠ 制限事項

* **作用方向の制限:** 輻輳管理（LLQ/CBWFQ キューイング）および輻輳回避（WRED/ECN）は、**Egress (送信方向) にのみ適用可能** であり、Ingress (受信方向) には適用できない。
* **LLQ 内蔵ポリサー動作:** `priority` コマンドで指定した帯域を超過したパケットは、インターフェイス輻輳時には内蔵ポリサーによって即座にドロップされる（他クラスの Starvation 防止のため）。
* **WRED の適用制限:** `random-detect` は **`priority` クラス（LLQ）には設定不可**。CBWFQ クラスまたは `class-default` のみに適用可能。
* **Hardware Queue (Tx-Ring) の存在:** Tx-Ring 内に蓄積されているパケットに対しては、Software MQC スケジューリングは適用されない。遅延過敏な音声通信を扱う場合は `tx-ring-limit` のチューニングが不可欠。

---

## 🔄 他技術との関連

* **MQC (Modular QoS CLI):** `class-map`（分類）、`policy-map`（キューイング・WRED 定義）、`service-policy`（バインド）による統合管理基盤。
* **NBAR2 (Network-Based Application Recognition):** L7 アプリケーション（WebEx, Teams, Citrix）を識別し、特定 CBWFQ クラスへ割り当てる連動。
* **HQoS (Hierarchical QoS):** WAN 契約帯域への Shaping (親 Policy) と、クラス別 LLQ/CBWFQ (子 Policy) の階層結合。
* **IPsec / GRE トンネル (`qos pre-classify`):** パケットカプセル化前に内部ヘッダーを参照し、トンネル外側で正確な MQC キューイングを実行。
* **TCP ウィンドウ制御:** WRED/ECN による受信側/送信側 TCP Congestion Window (cwnd) の早期調整。

---

## 🧩 比較表

| 項目 | LLQ (Low Latency Queuing) | CBWFQ (Class-Based WFQ) | WRED (Weighted RED) |
| :--- | :--- | :--- | :--- |
| **分類・目的** | 輻輳管理 (Strict Priority) | 輻輳管理 (Guaranteed Bandwidth) | 輻輳回避 (Congestion Avoidance) |
| **主な対象** | VoIP 音声 (DSCP EF), 遅延過敏通信 | ミッションクリティカルデータ (AF31/41) | TCP トラフィック主体 (AF11/Default) |
| **コマンド** | `priority <kbps>` / `priority level <1-2>` | `bandwidth` / `bandwidth remaining percent` | `random-detect dscp-prec-based` |
| **動作方式** | Strict Priority (最優先出力) + 内蔵 Policer | Weight 比率に応じた WFQ フェアスケジューリング | 閾値に応じた確率的早期ドロップ |
| **遅延 (Latency)** | **極小 (Microseconds)** | 中程度 (バッファ依存) | N/A (キュー蓄積の抑制) |
| **適用位置** | MQC Policy-Map (Egress) | MQC Policy-Map (Egress) | MQC Policy-Map (Egress CBWFQ 内) |

---

## 💡 ベストプラクティス

1. **LLQ 割当帯域の制御 (33% ルール):**
   * LLQ (`priority`) に割り当てる帯域は、回線全帯域の **33% 以下** (高くても 50% 以下) に抑える。優先キューが過大になると、データ通信クラスが餓死（Starvation）を起こす。
2. **`bandwidth remaining percent` の利用:**
   * 絶対値 (`bandwidth <kbps>`) ではなく、残余帯域比率 (`bandwidth remaining percent`) を使用することで、回線帯域の変更や HQoS 上での親 Policy 帯域変更時に動的かつ安全に帯域分配が維持される。
3. **WRED + ECN のセット運用:**
   * 単なる WRED（パケット破棄）ではなく、`random-detect ecn` を併用することで、TCP パケットを落とさずに ECN マークして送信側にウィンドウ縮小を促し、最も効率的な帯域利用を実現する。
4. **Tx-Ring Limit の最適化:**
   * 低速 WAN 回線（10Mbps 以下）や VoIP 厳格要求環境では、`tx-ring-limit 4` または `16` を手動設定し、Hardware Queue での遅延発生を防止する。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: LLQ (Single-Priority) + CBWFQ (`bandwidth` 絶対値) 構成

* **問題:** Egress ポート Gi0/0/1 において、Voice 通信 (DSCP EF) に 256kbps の Strict Priority を割り当て、Data1 (DSCP AF31) に 1024kbps、Data2 (DSCP AF21) に 512kbps の最小帯域保証を提供せよ。
* **要件:**
  * Voice は `priority` コマンドを使用すること。
  * Data1, Data2 は `bandwidth` 絶対値コマンドを使用すること。
  * インターフェイス予約帯域制限でエラーとならないよう配慮すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_DATA1
 match dscp af31

class-map match-any CM_DATA2
 match dscp af21

policy-map PM_LAB1
 class CM_VOICE
  priority 256
 class CM_DATA1
  bandwidth 1024
 class CM_DATA2
  bandwidth 512
 class class-default
  bandwidth 256

interface GigabitEthernet0/0/1
 max-reserved-bandwidth 100
 service-policy output PM_LAB1
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1` を実行し、`CM_VOICE` が Strict Priority Queue として認識され、`CM_DATA1`, `CM_DATA2` に所定の帯域が保証されていることを確認。

---

### ラボ 2: Dual-Priority Queue (Multi-Level LLQ: Level 1 + Level 2) 構成

* **問題:** 音声メディア (DSCP EF) を最優先 Strict Priority (Level 1) 384kbps とし、リアルタイムビデオ (DSCP AF41) を第 2 優先 Strict Priority (Level 2) 1024kbps として優先出力せよ。
* **要件:**
  * Multi-Level LLQ 構文 (`priority level`) を使用すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_VIDEO
 match dscp af41

policy-map PM_LAB2
 class CM_VOICE
  priority level 1 384
 class CM_VIDEO
  priority level 2 1024
 class class-default
  bandwidth remaining percent 100

interface GigabitEthernet0/0/1
 service-policy output PM_LAB2
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1` で `priority level 1` および `priority level 2` が独立してカウントされていることを確認。

---

### ラボ 3: CBWFQ (`bandwidth remaining percent`) による残余帯域比率分配構成

* **問題:** Priority クラス (Voice: 512kbps) を割り当てた後の「残余帯域」に対して、Critical-Data に 50%、Transactional-Data に 30%、その他 (Default) に 20% を割り当てよ。
* **要件:**
  * `bandwidth remaining percent` を使用すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_CRITICAL
 match dscp af31

class-map match-any CM_TRANSACTION
 match dscp af21

policy-map PM_LAB3
 class CM_VOICE
  priority 512
 class CM_CRITICAL
  bandwidth remaining percent 50
 class CM_TRANSACTION
  bandwidth remaining percent 30
 class class-default
  bandwidth remaining percent 20

interface GigabitEthernet0/0/1
 service-policy output PM_LAB3
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1` で `bandwidth remaining 50%`, `30%`, `20%` の分配表示を確認。

---

### ラボ 4: DSCP ベース WRED ＋ ECN 複合構成

* **問題:** `class-default` 内で DSCP ベースの WRED を有効化し、DSCP AF11 パケットに対して Min-Threshold 32, Max-Threshold 64, Mark Probability 10 を設定せよ。さらに ECN 通知を有効化せよ。
* **要件:**
  * `random-detect dscp-prec-based` を投入すること。
  * `random-detect ecn` を有効化すること。
* **設定例:**
```bash
policy-map PM_LAB4
 class class-default
  bandwidth remaining percent 100
  random-detect dscp-prec-based
  random-detect dscp af11 32 64 10
  random-detect ecn

interface GigabitEthernet0/0/1
 service-policy output PM_LAB4
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1 class class-default` で `WRED dscp-based` のテーブルおよび `ECN marked` カウンタが表示されることを確認。

---

### ラボ 5: HQoS (Parent Shape Average + Child LLQ/CBWFQ) サブレート構成

* **問題:** 1Gbps 物理ポート GigabitEthernet0/0/2 において、WAN 契約帯域 20Mbps に Shaping を行い、その配下で Voice 512kbps LLQ、Data 50% CBWFQ をネスト構成せよ。
* **要件:**
  * 親 Policy で `shape average 20000000` を設定すること。
  * 子 Policy に LLQ と CBWFQ を設定すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_DATA
 match dscp af31

policy-map PM_CHILD
 class CM_VOICE
  priority 512
 class CM_DATA
  bandwidth remaining percent 50
 class class-default
  bandwidth remaining percent 50

policy-map PM_PARENT
 class class-default
  shape average 20000000
  service-policy PM_CHILD

interface GigabitEthernet0/0/2
 service-policy output PM_PARENT
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/2` で Parent Shaping 情報および Child Queuing 情報が階層表示されることを確認。

---

### ラボ 6: HQoS + WRED/ECN + Child Queue Limit 構成

* **問題:** HQoS の子ポリシー内 `class-default` に対し、Software Queue 深度を 256 パケットに拡張し、DSCP ベース WRED ＋ ECN を有効化せよ。
* **要件:**
  * `queue-limit 256 packets` を投入すること。
* **設定例:**
```bash
policy-map PM_CHILD_LAB6
 class CM_VOICE
  priority 256
 class class-default
  bandwidth remaining percent 100
  queue-limit 256 packets
  random-detect dscp-prec-based
  random-detect ecn

policy-map PM_PARENT_LAB6
 class class-default
  shape average 10000000
  service-policy PM_CHILD_LAB6

interface GigabitEthernet0/0/2
 service-policy output PM_PARENT_LAB6
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/2` で `queue-limit 256 packets` および WRED/ECN 設定を確認。

---

### ラボ 7: Hardware Queue (Tx-Ring Limit) チューニング ＋ LLQ 遅延最適化構成

* **問題:** 低速 WAN ポート GigabitEthernet0/0/1 において、Hardware Queue の遅延を削減するため `tx-ring-limit` を 8 に縮小し、LLQ ポリシーをバインドせよ。
* **要件:**
  * インターフェイス配下で `tx-ring-limit 8` を設定すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_LAB7
 class CM_VOICE
  priority 128
 class class-default
  bandwidth remaining percent 100

interface GigabitEthernet0/0/1
 tx-ring-limit 8
 service-policy output PM_LAB7
```
* **検証方法:**
  * `show controllers GigabitEthernet0/0/1` で `tx_ring_limit = 8` を確認。

---

### ラボ 8: NBAR2 アプリケーション分類 ＋ CBWFQ キューイング構成

* **問題:** NBAR2 で識別した `citrix` トラフィックに 30% の残余帯域を保証し、`youtube` を `class-default` へ落とせ。
* **要件:**
  * `match protocol citrix` を使用すること。
* **設定例:**
```bash
class-map match-all CM_CITRIX
 match protocol citrix

policy-map PM_LAB8
 class CM_CITRIX
  bandwidth remaining percent 30
 class class-default
  bandwidth remaining percent 70

interface GigabitEthernet0/0/1
 service-policy output PM_LAB8
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1` で NBAR2 マッチパケット数と CBWFQ 統計を確認。

---

### ラボ 9: Interface `max-reserved-bandwidth 100` 手動オーバーライド構成

* **問題:** インターフェイス帯域の 85% を超える帯域を `bandwidth` コマンドで割り当てるため、制限を 100% 解放せよ。
* **要件:**
  * `max-reserved-bandwidth 100` を使用すること。
* **設定例:**
```bash
class-map match-any CM_DATA_HEAVY
 match dscp af31

policy-map PM_LAB9
 class CM_DATA_HEAVY
  bandwidth 8500
 class class-default
  bandwidth 1000

interface GigabitEthernet0/0/1
 bandwidth 10000
 max-reserved-bandwidth 100
 service-policy output PM_LAB9
```
* **検証方法:**
  * コマンド投入時に帯域上限エラーが発生しないことを確認。

---

### ラボ 10: IPsec VPN トンネル環境における `qos pre-classify` ＋ Egress LLQ/CBWFQ 統合構成

* **問題:** GRE/IPsec トンネルインターフェイス (Tunnel1) において、暗号化前の内部 IP ヘッダー（DSCP EF）に基づき Egress 物理ポートで LLQ 優先制御を実行させよ。
* **要件:**
  * Tunnel1 インターフェイスで `qos pre-classify` を有効化すること。
* **設定例:**
```bash
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_LAB10
 class CM_VOICE
  priority 256
 class class-default
  bandwidth remaining percent 100

interface Tunnel1
 ip address 10.255.255.1 255.255.255.252
 tunnel source GigabitEthernet0/0/1
 tunnel destination 192.0.2.2
 qos pre-classify

interface GigabitEthernet0/0/1
 service-policy output PM_LAB10
```
* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/1` を実行し、暗号化後の ESP パケットが `CM_VOICE` クラスへ分類・優先出力されていることを確認。


## ❓ 想定試験問題

### 問 1 (トラブルシューティング / LLQ ドロップ)
**シナリオ:** 企業ネットワークの Egress ポート (10Mbps) において、VoIP 音声通信用の LLQ クラス (`priority 256`) で音声品質が著しく劣化（途切れ）する現象が発生した。`show policy-map interface` を確認すると、`Class-map: CM_VOICE` 配下で `police: class total dropped 45820 packets` がカウントされていた。
**設問:** 音声パケットがドロップした直接的原因と、ルータの設定を変更して障害を復旧させる最も適切なコンフィグを答えよ。

* **解答:**
  * **原因:** `priority 256` コマンドには内蔵ポリサーが組み込まれているため、実際の音声トラフィック（呼数増加やシグナリング混入）が 256kbps を超えた際に、超過分が不当なパケットとして即座にドロップされたため。
  * **修正コンフィグ:**
    ```bash
    policy-map PM_EGRESS
     class CM_VOICE
      priority 512
    ```

---

### 問 2 (Design / WRED vs Priority)
**シナリオ:** ネットワークアーキテクトが HQoS ポリシーを設計する際、`CM_VOICE` クラス（LLQ: `priority 512`）のキュー溢れを防ぐ目的で `random-detect dscp-prec-based` (WRED) を追加設定しようとしたが、CLI でコマンドが拒否された。
**設問:** なぜ WRED を LLQ クラスに適用できないのか、技術的理由を説明せよ。

* **解答:**
  * WRED はパケットを確率的に早期破棄（Drop）することで TCP 送信側のウィンドウサイズ（Congestion Window）を縮小させる輻輳回避機構である。これに対し、LLQ (Priority Queue) は遅延・ジッターに敏感でパケット再送機能を持たない UDP 通信（VoIP メディア）を対象としており、パケット破棄に耐性がないため、WRED の適用が機能的・論理的に禁止されている。

---

### 問 3 (コンフィグ読解 / 残余帯域計算)
**シナリオ:** 以下の QoS コンフィグが適用されたルータポート (10Mbps) がある。
```bash
policy-map PM_CALC
 class CM_VOICE
  priority 2000
 class CM_DATA1
  bandwidth remaining percent 60
 class CM_DATA2
  bandwidth remaining percent 40
```
**設問:** `CM_DATA1` クラスに割り当てられる**実際の物理計算帯域（kbps）**を算出せよ。

* **解答:**
  1. インターフェイス全帯域 = 10,000 kbps
  2. Strict Priority (`CM_VOICE`) 帯域 = 2,000 kbps
  3. 残余帯域 (Remaining Bandwidth) = 10,000 kbps - 2,000 kbps = 8,000 kbps
  4. `CM_DATA1` の分配比率 = 8,000 kbps × 60% = **4,800 kbps**

---

### 問 4 (トラブルシューティング / ECN 動作判定)
**シナリオ:** ネットワーク管理者が `random-detect ecn` を有効化したが、`show policy-map interface` で `ECN marked packets` カウンタが一切増加せず、パケットがそのまま WRED ドロップされていた。
**設問:** ECN パケットマークが行われない代表的な技術的原因を 2 つ挙げよ。

* **解答:**
  1. トラフィックを発生させている端点ホスト（TCP 送信元/宛先）が ECN (RFC 3168 - IP ヘッダー ECT ビット `01` または `10`) に対応しておらず、ハンドシェイク段階で ECN ネゴシエーションが成功していないため。
  2. ソフトウェアキューの長さを測定した結果、Queue Depth が WRED の `Min-Threshold` 未満であるか、または `Max-Threshold` を超えて Tail Drop 領域（100% 破棄）に達しているため。

---

### 問 5 (実装 / HQoS ネスト構造)
**シナリオ:** WAN 回線（100Mbps 物理ポート上で契約帯域 10Mbps）において、契約帯域への Shaping を行いつつ、音声 (EF) 256kbps LLQ、データ (AF31) 残余帯域 50% を保証する HQoS ポリシーを構築せよ。

* **解答:**
  ```bash
  class-map match-any CM_VOICE
   match dscp ef

  class-map match-any CM_DATA
   match dscp af31

  policy-map PM_CHILD_EXAM
   class CM_VOICE
    priority 256
   class CM_DATA
    bandwidth remaining percent 50
   class class-default
    bandwidth remaining percent 50

  policy-map PM_PARENT_EXAM
   class class-default
    shape average 10000000
    service-policy PM_CHILD_EXAM

  interface GigabitEthernet0/0/1
   service-policy output PM_PARENT_EXAM
  ```

---

## 🔗 参考リソース

* Cisco Configuration Guide: QoS Modular QoS CLI Configuration Guide
* Cisco Command Reference: QoS Command Reference
* Cisco Live: Advanced Enterprise QoS Design
* Cisco Validated Design (CVD): End-to-End QoS Design Guide
* IETF RFC 2697: A Single Rate Three Color Marker
* IETF RFC 2698: A Two Rate Three Color Marker
* IETF RFC 3168: The Addition of Explicit Congestion Notification (ECN) to IP

---

## 📝 **補足（Notes）**

- **学習メモ:**
  * LLQ (Priority Queue) の実質的な上限は、内蔵ポリサー (`priority <kbps>`) によって厳格に管理される。呼数計算を誤ると音声パケットがサイレントドロップするため、コーデック帯域（G.711: 約 87kbps/call, G.729: 約 31kbps/call）に基づく正確な設計が不可欠。
  * `bandwidth` (絶対値) の合計制約（デフォルト 75%）は、`max-reserved-bandwidth 100` の投入で解除可能だが、制御プロトコル (OSPF/BGP) の通信断リスクを考慮し慎重に適用すること。
- **図解:**
  * **Tx-Ring vs Software Queue:** 
    `[CEF] ──► (Non-Congested: Direct to Tx-Ring) ──► [Tx-Ring] ──► [Line]`
    `       └──► (Congested: Tx-Ring Full) ──► [Software Queue (MQC)] ──► [Tx-Ring] ──► [Line]`
- **注意点:**
  * WRED と ECN の併用時は、端点ホスト（Linux / Windows Server / IP Phone）側での ECN サポートが必須である。ホストが非対応の場合、`random-detect ecn` を投入していても通常の WRED ドロップとして機能する。


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
