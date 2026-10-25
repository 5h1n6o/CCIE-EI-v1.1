---
layout: default
title: 4.4.e-Policing-shaping
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 5
---

# 4.4.e Policing, shaping

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.0 Infrastructure Security and Services` における **`4.4.e Policing, shaping`**（ポリシングおよびシェーピング）の完全学習メモ。

---

## 📘 概要

トラフィックコンディショニング（Traffic Conditioning）技術である **Policing（ポリシング）** および **Shaping（シェーピング）** は、ネットワークインフラストラクチャにおける帯域制御の根幹をなす要素である。帯域幅の公平な利用、契約帯域（CIR: Committed Information Rate）超過トラフィックの制御、およびサービスプロバイダー（SP）網境界におけるパケットドロップ抑止において不可欠な役割を果たす。

* **Policing（ポリシング）:**
  * 指定された帯域幅（レート）を超過したトラフィックを即座に破棄（Drop）するか、優先度を再マーク（Down-marking / Re-marking: 例 AFx1 → AFx2 / CS1）して転送する。
  * バッファリング（遅延）を行わないため、ジッターや遅延に極めて敏感な音声（VoIP）やリアルタイム動画トラフィックのレート制御、あるいはネットワーク境界（Ingress / Egress）における非不当トラフィックの強制遮断に最適である。
* **Shaping（シェーピング）:**
  * 契約帯域を超過したトラフィックを一時的にキュー（バッファ）に保持し、平滑化（Smooth / Pacing）して指定された速度で順次送信（Egress）する。
  * パケット破棄を回避できる一方で、バッファリングに伴う「遅延（Delay）」および「ジッター（Jitter）」が発生する。主に WAN ルータの Egress ポート（例: 1Gbps 物理インターフェイス上で 100Mbps 契約の Sub-rate WAN 回線へ出力する場合）で用いられる。

---

## 🔑 要点

| 項目 | Policing（ポリシング） | Shaping（シェーピング） |
| :--- | :--- | :--- |
| **主な目的** | 帯域上限の強制、帯域制限、非準拠パケットの即時破棄・降格 | トラフィックの平滑化、バーストの抑制、SP網境界でのドロップ防止 |
| **適用方向** | Ingress（入力）および Egress（出力）の双方 | **Egress（出力）限定** |
| **バッファリング** | **なし**（即時 Drop または Re-mark） | **あり**（キューに保持し平滑化して送信） |
| **発生する影響** | パケット破棄（Drop）による再送（TCP） | バッファリング遅延（Delay）およびジッター増加 |
| **対象トラフィック** | 音声（VoIP）、シグナリング、即時ドロップが必要なトラフィック | TCPデータ通信、WANサブポート宛て通信 |
| **アルゴリズム** | Single/Two-Rate Token Bucket（RFC 2697 / RFC 2698） | Token Bucket + Queuing (CBWFQ / LLQ / Class-Default Queue) |
| **対応機能** | Single-Rate 2-Color, Single-Rate 3-Color, Two-Rate 3-Color | Shape Average, Shape Peak, Adaptive Shaping (Frame Relay/BECN) |
| **設計上の注意点** | バーストサイズ（Bc / Be）の適切な設計（マイクロバースト対策） | バッファサイズ制限および Tail Drop / WRED との組み合わせ |

---

## 🏗 動作原理

### 1. Token Bucket（トークンバケット）アルゴリズムの基本概念

ポリシングおよびシェーピングのトラフィック測定（Metering）は、抽象的な「バケット」に一定速度で「トークン」を補填し、パケット通過時にパケット長（バイト数）分のトークンを消費するアルゴリズムに基づいている。

```text
       [ トークン補填: CIR (bps) に基づく速度 ]
                       │
                       ▼
            ┌─────────────────────┐
            │   Token Bucket      │
            │   (最大容量: Bc / Be)│
            └──────────┬──────────┘
                       │
   パケット到着 ───────┼───────► トークンが十分ある場合: Conform (送信/マーク維持)
   (Length: L bytes)   │
                       └───────► トークン不足の場合: Exceed / Violate (Drop / Re-mark / Queue)
```

#### バケットパラメータの定義
* **CIR (Committed Information Rate):** 契約情報レート（bps単位）。トークンが充填される基本速度。
* **PIR (Peak Information Rate):** ピーク情報レート（bps単位）。Two-Rate ポリサーにおいて許容される最大速度。
* **Bc (Committed Burst Size):** 契約バーストサイズ（Bytes または Bits）。バケットが保持できる最大トークン量。
* **Be (Excess Burst Size):** 超過バーストサイズ（Bytes または Bits）。一時的な過剰バーストを評価するための追加バケット容量。
* **Tc (Time Interval):** トークンが補填される時間間隔（ミリ秒）。計算式: $Tc = \frac{Bc}{CIR}$。

---

### 2. ポリシングの測定モデル (Single-Rate vs Two-Rate)

#### (1) Single-Rate Two-Color (1r2c)
* **バケット数:** 1（$Bc$ バケットのみ）。
* **動作:** パケット長 $L \le Bc$ であれば **Conform (Green)**、不足すれば **Exceed (Red)** として即時 Drop または Re-mark。

#### (2) Single-Rate Three-Color (1r3c - RFC 2697)
* **バケット数:** 2（$Bc$ バケットおよび $Be$ バケット）。同一速度 $CIR$ でトークンが充填される。
* **充填ロジック:** まず $Bc$ バケットに充填され、$Bc$ が満たされた場合に溢れたトークンが $Be$ バケットに補填される。
* **判定条件:**
  * $L \le Bc 
ightarrow$ **Conform (Green)**（$Bc$ から $L$ トークン消費）
  * $L > Bc$ かつ $L \le Be 
ightarrow$ **Exceed (Yellow)**（$Be$ から $L$ トークン消費）
  * $L > Bc$ かつ $L > Be 
ightarrow$ **Violate (Red)**（トークン消費なし、Drop）

#### (3) Two-Rate Three-Color (2r3c - RFC 2698)
* **バケット数:** 2（$Bc$ バケットおよび $Be$ バケット）。独立した速度（$CIR$ および $PIR$）でトークンが同時充填される。
* **判定条件:**
  * $L > PIR (Be) 
ightarrow$ **Violate (Red)**
  * $L > CIR (Bc)$ かつ $L \le PIR (Be) 
ightarrow$ **Exceed (Yellow)**（$Be$ および $Bc$ からトークン消費）
  * $L \le CIR (Bc) 
ightarrow$ **Conform (Green)**（両バケットからトークン消費）

---

### 3. シェーピングの動作メカニズム (Shape Average vs Shape Peak)

シェーピングは時間間隔 $Tc$ ごとに $Bc$ バイト（Bits）のトークンをバケットに給付し、その $Tc$ 内でパケットを順次送信する。

```text
[ インターフェイス物理速度: 1Gbps ]
   │
   ├─► [Tc 1: Bc 送信] ──► [空き時間 (Idle)] ──► [Tc 2: Bc 送信] ──► [空き時間] ...
   │   │<─── 10ms ───>│
   │
   └─► 結果として平均速度: CIR (100Mbps) に平滑化される
```

* **Shape Average:**
  * ターゲットレートを $CIR$ に設定する。
  * $Tc$ ごとに充填されるトークン量 $= Bc$。平均送信速度は正確に $CIR$ となる。
* **Shape Peak:**
  * ターゲットレートを $CIR \left(1 + \frac{Be}{Bc}
ight)$ に設定する。
  * $Tc$ ごとに $Bc + Be$ のトークンを給付するため、$CIR$ を超えるピークレートでの送信を許容する。

---

## ⚙ 動作シーケンス

### 1. Ingress / Egress ポリシングのパケット処理フロー

```text
パケット到着 (Ingress / Egress)
   │
   ▼
1. Class-Map によるトラフィック分類 (Match ACL / DSCP / NBAR2)
   │
   ▼
2. 到着パケット長 L (Bytes) の計算
   │
   ▼
3. 最後のパケット到着時刻からの経過時間 Δt によるトークン補填計算
   Tokens_added = Δt × CIR
   │
   ▼
4. トークンバケット条件評価 (Conform / Exceed / Violate)
   │
   ├── [Conform (Green)]  ──► アクション実行 (Transmit / Set-DSCP) ──► 転送へ
   │
   ├── [Exceed (Yellow)] ──► アクション実行 (Set-DSCP-Transmit / Drop)
   │
   └── [Violate (Red)]   ──► アクション実行 (Drop / Set-DSCP-Transmit)
```

---

### 2. Egress シェーピングのパケット処理フロー

```text
パケット送信要求 (Egress)
   │
   ▼
1. Shape レート (CIR) とトークン残量の比較
   │
   ├── トークン残量 >= パケットサイズ
   │      │
   │      └─► 即座に物理インターフェイスから送信 (トークン消費)
   │
   └── トークン残量 < パケットサイズ
          │
          ▼
   2. シェーピングバッファ (Shaping Queue) へ格納
          │
          ├── バッファ余裕あり ──► キューイング (排出しまで待機)
          │                             │
          │                             ▼
          │                      次の Tc タイマー割り込み発動
          │                             │
          │                             ▼
          │                      トークン給付 (Bc) 後、キューから順次送信
          │
          └── バッファ溢れ (Queue Full) ──► Tail Drop または WRED ドロップ
```

---


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、Policing および Shaping は単体で出題されるだけでなく、HQoS (Hierarchical QoS)、DMVPN / GRE トンネル、WRED、NBAR2、VPN 暗号化処理との複合問題として出題頻度が極めて高い。

### 1. Blueprintで重要なポイント
* **Token Bucket パラメータの正確な算定:**
  * Cisco IOS XE のデフォルトバーストサイズ計算（$Bc = \text{CIR} \times 0.25\text{秒}$ または $125\text{ms}$）と、指定された要件（例: $Bc = 10ms$ 相当に設定せよ）に応じた手動チューニング。
  * 明示的な Bits vs Bytes 単位の変換指定。CLI では $Bc$ は Bytes 単位で指定するケースが多い（例: `police cir 10000000 bc 31250`）。
* **Single-Rate 3-Color (RFC 2697) vs Two-Rate 3-Color (RFC 2698) の CLI 識別:**
  * `police cir <rate> bc <bytes> be <bytes>` $
ightarrow$ **Single-Rate (RFC 2697)**。
  * `police cir <rate> pir <rate> bc <bytes> be <bytes>` $
ightarrow$ **Two-Rate (RFC 2698)**。
* **HQoS (Hierarchical QoS) における Parent / Child ポリシー適用:**
  * 親ポリシー（Parent Policy）で WAN 契約帯域への Shaping (`shape average`) を実行し、子ポリシー（Child Policy）でクラスごとの LLQ (`priority`) や CBWFQ (`bandwidth remaining percent`) をネスト適用する構成。

---

### 2. よくある設定ミス ＆ ハマりポイント

1. **Shaping と Policing の物理レイヤ・カプセル化オーバーヘッド不整合:**
   * L2 オーバーヘッド（Ethernet Header, VLAN Tag, IPsec ESP Header）を含めた実効レート計算の考慮漏れ。`account scos` / `account user-defined` によるオーバーヘッド補正（Overhead Accounting）。
2. **親ポリシーでの `priority` 直接記述による CLI エラー:**
   * HQoS の親ポリシー (`policy-map PARENT`) 直下に `priority` コマンドを記述すると CLI エラーとなる。LLQ 厳格優先キューは必ず子ポリシー (`policy-map CHILD`) 内で定義しなければならない。
3. **シングルレート 3 カラーポリサーでの PIR 誤記述:**
   * RFC 2697 (Single-rate) の要件に対して誤って `pir` パラメータを記述すると Two-Rate (RFC 2698) に変わってしまう。
4. **Shaping バッファ（Queue Limit）の調整不足に伴う音声品質劣化:**
   * `shape average` を適用した際、デフォルトのキュー長が大きすぎると、大容量データ通信時にバッファリング遅延（Bufferbloat）が発生し、LLQ 内の音声パケットにも遅延の影響が波及する。

---

### 3. show コマンドからの状態判断

```text
Router# show policy-map interface GigabitEthernet0/0/1
 GigabitEthernet0/0/1 

  Service-policy output: PM_WAN_OUT

    Class-map: CM_VOICE (match-any)
      1000 packets, 120000 bytes
      5 minute aggregate offered rate 64000 bps, drop rate 0000 bps
      Match: dscp ef (46)
      Queueing
        Strict Priority
        Output Queue: Conversation 264 
        Bandwidth 512 (kbps)
        (pkts matched/bytes matched) 1000/120000
        (depth/total drops/no-buffer drops) 0/0/0

    Class-map: class-default (match-any)
      50000 packets, 60000000 bytes
      5 minute aggregate offered rate 95000000 bps, drop rate 2000000 bps
      Match: any
      Queueing
        queue limit 64 packets
        (queue depth/total drops/no-buffer drops) 12/1450/0
        shape (average) cir 100000000, bc 400000, be 400000
        target shape rate 100000000
```

* **`offered rate` vs `drop rate`:** トラフィック入力速度とポリサー/シェーパーによるドロップ発生速度のリアルタイム追跡。
* **`total drops`:** キュー溢れ（Tail Drop）またはポリシングによる破棄数。
* **`queue depth`:** 現在シェーピングバッファに滞留しているパケット数。

---

## 🛠 設定方法

### 1. Single-Rate Three-Color Policing (RFC 2697) 設定

```bash
! 1. Class-Map の定義
class-map match-any CM_DATA_BULK
 match dscp af11 af12 af13

! 2. Policy-Map の定義 (CIR: 10Mbps, Bc: 31250 Bytes, Be: 62500 Bytes)
policy-map PM_POLICING_1R3C
 class CM_DATA_BULK
  police cir 10000000 bc 31250 be 62500 conform-action transmit exceed-action set-dscp-transmit af12 violate-action set-dscp-transmit af13

! 3. インターフェイス適用
interface GigabitEthernet0/0/1
 service-policy input PM_POLICING_1R3C
```

---

### 2. Two-Rate Three-Color Policing (RFC 2698) 設定

```bash
policy-map PM_POLICING_2R3C
 class CM_DATA_BULK
  police cir 10000000 pir 20000000 bc 31250 be 62500 conform-action transmit exceed-action set-dscp-transmit af12 violate-action drop
```

---

### 3. Hierarchical QoS (HQoS) Shaping + LLQ / CBWFQ 構成

```bash
! 1. 子ポリシー (Child Policy) の定義
policy-map PM_CHILD_QOS
 class CM_VOICE
  priority 1024
 class CM_CRITICAL
  bandwidth remaining percent 60
 class class-default
  bandwidth remaining percent 40

! 2. 親ポリシー (Parent Policy) の定義 (Shaping 100Mbps)
policy-map PM_PARENT_SHAPE
 class class-default
  shape average 100000000
  service-policy PM_CHILD_QOS

! 3. WAN 物理インターフェイスへの適用
interface GigabitEthernet0/0/0
 service-policy output PM_PARENT_SHAPE
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| インターフェイス毎の QoS 適用状態・統計確認 | `show policy-map interface <Interface>` |
| 特定クラスのポリシング・ドロップ統計詳細 | `show policy-map interface <Interface> class <Class-Name>` |
| シェーピング状態・バケット稼働状態の確認 | `show policy-map interface <Interface> | section shape` |
| 登録されている Policy-Map 構成確認 | `show policy-map <Policy-Name>` |
| MQC ハードウェア TCAM プログラミング確認 | `show platform hardware qos interface <Interface>` |
| QoS 制御プレーン/データプレーン Debug | `debug qos mqc` / `debug platform hardware qos` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **契約帯域未満でポリサーによりパケットがドロップする** | バーストサイズ ($Bc$) 設定値が小さすぎ、TCP マイクロバーストに対応できていない | `show policy-map interface` (Exceed / Violate drop 増加) | $Bc$ 値を大きめ（RTT の $1.5 \sim 2$ 倍に相当するバイト数）に調整 |
| **HQoS 適用時に親ポリシーで CLI エラーが発生する** | 親ポリシー直下に `priority` コマンドを記述している | CLI 設定時のコンパイルエラー画面 | `priority` は必ず子ポリシー (Child Policy) 内に定義 |
| **WAN 側 SP 網内でパケットがランダムドロップする** | ルータ側 Shaping レートが SP 契約帯域 (CIR) よりも高く設定されている | `show policy-map interface` (ルータ側ドロップ 0 なのに宛先遅延) | `shape average` のレートを SP 契約値に正確に合わせる |
| **音声通信でジッター・遅延が発生する (HQoS 環境)** | シェーピングバッファ長 (`queue-limit`) が大きすぎて Bufferbloat が発生 | `show policy-map interface` (queue depth が高数値固着) | 子ポリシーの `class-default` やデータクラスで `queue-limit` を縮小 |

---

## ⚠ 制限事項

1. **適用方向制限:**
   * Policing: Ingress および Egress の両方向でサポート。
   * Shaping: **Egress（出力）方向のみ** サポート（Ingress Shaping は構造上不可）。
2. **プラットフォーム制限 (Catalyst 9000 シリーズ ASIC):**
   * ポート単位のハードウェアポリサー数やバケット精度に ASIC 固有の制約が存在する。
3. **ライセンス制限:**
   * 高度な HQoS や 3 階層ネストポリシーの適用には Cisco Network Advantage / DNA Advantage ライセンスが必要。

---

## 🔄 他技術との関連

* **DMVPN / IPsec VPN:** トンネル外部ヘッダーに対する Shaping 適用（`qos pre-classify` または DMVPN Per-Tunnel QoS）。
* **WRED (Weighted Random Early Detection):** Shaping キュー内における TCP パケットの選択的ドロップとグローバル同期防止。
* **NBAR2 (Network-Based Application Recognition):** アプリケーション識別結果に基づく動的ポリシング（例: P2P 通信の 1Mbps 制限）。
* **HQoS (Hierarchical QoS):** 親ポリシー Shaping と子ポリシー Queuing の融合。

---

## 🧩 比較表

### 1. Policing vs Shaping

| 項目 | Policing | Shaping |
| :--- | :--- | :--- |
| **動作** | 超過トラフィックの破棄または降格 | 超過トラフィックのバッファリングと平滑化 |
| **バッファ** | 使用しない | 専用キューを使用 |
| **遅延 / ジッター** | 増加しない | 増加する |
| **方向** | Ingress & Egress | Egress のみ |
| **適用場面** | アクセス境界での帯域上限設定、音声優先 | WAN 回線境界での SP ドロップ防止 |

---

### 2. Single-Rate (RFC 2697) vs Two-Rate (RFC 2698) Policier

| 項目 | Single-Rate 3-Color (RFC 2697) | Two-Rate 3-Color (RFC 2698) |
| :--- | :--- | :--- |
| **トークンバケット数** | 2 個 ($Bc, Be$) | 2 個 ($Bc, Be$) |
| **充填レート** | 単一速度 ($CIR$) | 独立した 2 速度 ($CIR$ および $PIR$) |
| **評価基準** | バースト量（パケットサイズ）ベース | トラフィック速度（bps）ベース |
| **用途** | パケットバースト発生時の段階的降格 | ピークレートを厳格に制限する広帯域制御 |

---

## 💡 ベストプラクティス

1. **マイクロバーストを考慮した Bc / Be の選定:**
   * $Bc$ のデフォルト値は小さすぎることが多いため、高精度通信では $Bc = \text{CIR} \times 0.01 \sim 0.02\text{秒}$（10ms〜20ms 相当）以上を明示的に確保する。
2. **WAN サブレート境界における HQoS Shaping の徹底:**
   * 1Gbps 物理ポートで 100Mbps 契約の WAN 回線に接続する場合、必ずルータ側で 100Mbps の `shape average` を適用し、SP 側ポリサーによる無差別ドロップを未然に防止する。
3. **LLQ 音声クラスにおける Strict Priority ポリシング:**
   * 音声用 `priority` キューには必ず帯域制限（例: `priority 512`）を付与し、音声クラスのバグや攻撃パケットによるデータクラスの starvation（飢餓）を防御する。

---


## 📝 ラボ学習・設定サンプル例

### ラボ 1: Single-Rate Two-Color (1r2c) Ingress 帯域制限

* **問題:** インターフェイス GigabitEthernet0/0/1 の入力方向において、開発環境トラフィック（10.100.0.0/16）の最大帯域幅を 8Mbps に制限せよ。
* **要件:**
  * 超過したパケットは即座にドロップすること。
  * Single-Rate 2-Color ポリサーを使用すること。
* **設定例:**

* **検証方法:**
  * <code>show policy-map interface GigabitEthernet0/0/1</code> を実行し、<code>CM_DEV_TRAFFIC</code> の <code>conformed</code> および <code>exceeded</code> カウンタの動作を確認する。

---

### ラボ 2: Single-Rate Three-Color (1r3c - RFC 2697) Marking & Policing

* **問題:** 業務データクラス (DSCP AF21) の通信速度を 20Mbps に制限せよ。バーストに応じて段階的に DSCP マークを降格させよ。
* **要件:**
  * RFC 2697 準拠の Single-Rate 3-Color ポリサーを使用すること。
  * 適合 (Conform) パケットはそのまま送信 (transmit)。
  * 超過 (Exceed) パケットは DSCP AF22 へ降格送信 (set-dscp-transmit af22)。
  * 違反 (Violate) パケットは DSCP AF23 へ降格送信 (set-dscp-transmit af23)。
* **設定例:**

* **検証方法:**
  * 25Mbps の負荷トラフィックを送信し、対向ルータで AF22 および AF23 へリマークされたパケットを受信していることを確認する。

---

### ラボ 3: Two-Rate Three-Color (2r3c - RFC 2698) Peak Rate Policing

* **問題:** クラウドバックアップ通信（10.200.0.0/16）に対して、CIR 10Mbps、PIR 30Mbps の帯域制限を課せ。
* **要件:**
  * RFC 2698 Two-Rate ポリサーを使用すること。
  * CIR 以下の通信 (Conform) は送信。
  * CIR を超え PIR 以下の通信 (Exceed) は DSCP CS1 (Scavenger) に降格送信。
  * PIR を超える通信 (Violate) は即座にドロップすること。
* **設定例:**

* **検証方法:**
  * 40Mbps のトラフィックを入力し、10Mbps が正常送信、20Mbps が CS1 降格送信、10Mbps がドロップされることを <code>show policy-map interface</code> で確認。

---

### ラボ 4: HQoS (Hierarchical QoS) - Parent Shaping + Child LLQ/CBWFQ

* **問題:** 1Gbps 物理インターフェイス上で、契約帯域 100Mbps の WAN 回線へ出力する HQoS ポリシーを構築せよ。
* **要件:**
  * 親ポリシーで 100Mbps の shape average を実行。
  * 子ポリシーで Voice (DSCP EF) に 10Mbps の Strict Priority LLQ を確保。
  * 子ポリシーで Video (DSCP AF41) に残余帯域の 50% を確保。
  * 子ポリシーで Default クラスに残余帯域の 50% を割り当て。
* **設定例:**

* **検証方法:**
  * <code>show policy-map interface GigabitEthernet0/0/0</code> を実行し、親ポリシーで Shape 100Mbps が適用され、その配下で子ポリシーのキューイング統計が表示されることを確認。

---

### ラボ 5: NBAR2 アプリケーション識別連動 Dynamic Policing

* **問題:** P2P 通信 (BitTorrent 等) の過剰な帯域消費を防ぐため、NBAR2 で識別された P2P トラフィックを 2Mbps に制限せよ。
* **要件:**
  * NBAR2 アプリケーション属性 category file-sharing を使用して一括分類すること。
  * 2Mbps を超える通信はドロップすること。
* **設定例:**

* **検証方法:**
  * <code>show ip nbar protocol-discovery</code> および <code>show policy-map interface</code> で P2P アプリケーションが検知され、2Mbps でポリシングされていることを確認。

---

### ラボ 6: Overhead Accounting 付き Shape Average

* **問題:** Broadband Ethernet 回線において、物理ヘッダー（Ethernet Header + CRC + Interframe Gap: 24 バイト）を含めた正確な 50Mbps シェーピングを構成せよ。
* **要件:**
  * Overhead Accounting (account scos) を有効化すること。
* **設定例:**

* **検証方法:**
  * <code>show policy-map interface</code> を実行し、Account オプションが有効化されていることを確認。

---

### ラボ 7: DMVPN Per-Tunnel QoS Shaping

* **問題:** DMVPN Hub ルータにおいて、Spoke-1 (192.168.1.10) 宛てのトンネルトラフィックを 5Mbps にシェーピングせよ。
* **要件:**
  * NHRP Group または Per-Tunnel QoS 構文を使用すること。
* **設定例:**

* **検証方法:**
  * <code>show dmvpn</code> および <code>show policy-map multipoint</code> で動的トンネルに対してシェーピングポリシーがアタッチされていることを確認。

---

### ラボ 8: Shape Peak による許容バースト付き Egress Shaping

* **問題:** CIR 10Mbps の回線において、帯域が空いている時間帯には最大 20Mbps までのバースト送信を許容する Shape Peak 設定を構築せよ。
* **要件:**
  * shape peak コマンドを使用すること。
* **設定例:**

* **検証方法:**
  * <code>show policy-map interface</code> で Peak レートでバケットが運用されていることを確認。

---

### ラボ 9: Table-Map 連携 Poly-Marking (段階的降格)

* **問題:** 10Mbps を超えるデータトラフィックに対して、Table-Map を用いて系統的に DSCP を降格（Down-mark）させよ。
* **要件:**
  * Exceed 発生時に Table-Map TM_DOWNMARK に基づき降格させること。
* **設定例:**

* **検証方法:**
  * <code>show table-map TM_DOWNMARK</code> および <code>show policy-map interface</code> で降格統計を確認。

---

### ラボ 10: Control Plane Protection (CoPP) 連動 Traffic Policing

* **問題:** ルータ CPU に到達する SSH (TCP 22) 通信の最大レートを 1Mbps にポリシングし、DoS 攻撃から Control Plane を保護せよ。
* **要件:**
  * CoPP (control-plane) 配下にポリシングポリシーを適用すること。
* **設定例:**

* **検証方法:**
  * <code>show policy-map control-plane</code> を実行し、CPU 宛て SSH トラフィックが 1Mbps に制御されていることを確認。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** 企業網の WAN ルータにおいて、契約帯域 20Mbps の回線に対して以下のポリシングコンフィグを適用したところ、20Mbps 未満の通信（15Mbps 程度）であってもパケットドロップが発生する障害が報告された。

**設問:** この障害が発生した技術的理由と、推奨されるコンフィグ修正コマンドを述べよ。

* **解答:**
  * **技術的理由:** バーストサイズ Bc = 1000 Bytes（8000 Bits）の設定値が小さすぎるため。Bc = 1000 Bytes ではバケットに保持できるトークン量が標準的な TCP MTU (1500 Bytes) 未満となり、通常のマイクロバーストや単一パケットの入力に対してもトークン不足を起こして誤ドロップ（Exceed）が発生する。
  * **修正コマンド:** Bc を CIR に応じた適切なサイズ（標準的には 125ms 相当、20Mbps の場合は 20,000,000 / 8 * 0.125 = 312,500 Bytes）以上に拡大する。


---

### 問 2 (Design)
**シナリオ:** 1Gbps 物理インターフェイスで接続された WAN 回線において、帯域制御として HQoS (Hierarchical QoS) を設計している。要求事項として「親ポリシーで契約帯域 100Mbps への Shaping を行い、子ポリシーで Voice 用 Strict Priority Queue (10Mbps) と Data 用 CBWFQ を構成する」ことが求められている。
**設問:** 親ポリシー直下に直接 priority 10000 コマンドを記述してはいけない技術的理由を述べよ。

* **解答:**
  * **理由:** MQC アーキテクチャの制限により、親ポリシー（Parent Policy）で Shape または Police を定義している場合、その直下の親クラス内で直接 LLQ (priority) を定義することは構文上禁止されているため（コンパイルエラーとなる）。LLQ キューはスケジューリング処理を行う子ポリシー（Child Policy）内で定義し、親ポリシーからネスト呼び出し (service-policy) しなければならない。

---

### 問 3 (トラブルシューティング)
**シナリオ:** ネットワーク管理者が Single-Rate 3-Color Policier (RFC 2697) を設定しようとして以下のコマンドを投入した。

**設問:** このコンフィグが RFC 2697 (Single-Rate) の要件を満たしていない理由と、正しいコマンドを提示せよ。

* **解答:**
  * **理由:** pir 20000000 パラメータが記述されているため。pir を指定すると、ルータは Two-Rate 3-Color Policier (RFC 2698) として動作する。RFC 2697 (Single-Rate) に指定する場合は pir を削除し、単一の cir と bc, be のみで定義しなければならない。
  * **修正コマンド:**


---

### 問 4 (実装)
**シナリオ:** 物理インターフェイス GigabitEthernet0/0/2 出力方向において、NBAR2 で識別された youtube 通信に対して 5Mbps の Single-Rate ポリシングを適用し、5Mbps 超過分を即座にドロップするコンフィグを作成せよ。

* **解答:**


---

### 問 5 (コンフィグ読解)
**シナリオ:** 以下の show policy-map interface 出力を確認した。

**設問:** このクラスにおいてパケットドロップ（exceeded 3750 pkts）が発生している原因を説明せよ。

* **解答:**
  * **原因:** 入力トラフィックの速度（offered rate 128000 bps）が、ポリサーの許容 CIR（96000 bps）を超過しているため。設定された CIR (96kbps) を超える 32kbps 分の音声トラフィック（exceeded 32000 bps）が exceed-action drop ポリシーによってドロップされている。

---

## 🔗 参考リソース

* Cisco IOS XE 17.x Quality of Service Solutions Configuration Guide
* Cisco Command Reference - Quality of Service CLI Commands
* Cisco Live BRKRST-2515: Advanced QoS Design and Architecture
* RFC 2697: A Single Rate Three Color Marker
* RFC 2698: A Two Rate Three Color Marker

---

## 📝 補足（Notes）

* **トークンバケット計算の基本式:**
  * Bc (Bytes) = CIR (bps) * Tc (sec) / 8
  * 例: CIR = 100Mbps, Tc = 10ms (0.01s) -> Bc = 100,000,000 * 0.01 / 8 = 125,000 Bytes。
* **試験本番での注意点:**
  * CLI 上で Bc / Be の単位が Bits なのか Bytes なのか、プロンプトの表記を必ず確認すること（IOS XE の police コマンドにおける Bc は Bytes 指定）。




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


