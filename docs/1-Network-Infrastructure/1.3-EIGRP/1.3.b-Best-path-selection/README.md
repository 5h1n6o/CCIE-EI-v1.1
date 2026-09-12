---
layout: default
title: 1.3.b-Best-path-selection
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.3.b Best path selection

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP の1つである **EIGRP ベストパス選定（Best Path Selection）**、DUAL（Diffusing Update Algorithm）メトリクス計算、コンバージエンス条件（Feasibility Condition）、および **Classic Metrics（32-bit）と Wide Metrics（64-bit）** の内部動作仕様について、Cisco IOS-XE 17.x の実装基準に完全準拠して解説します。

---

## 📘 概要

EIGRP（Enhanced Interior Gateway Routing Protocol）は、ルータ間で送受信されるトポロジー情報に基づき、Loop-Free（ループ障害が存在しない）な最適経路（Best Path）を高速に選定する高度なディスタンスベクター型ダイナミックルーティングプロトコルです。

EIGRP のパス選定エンジンは **DUAL（Diffusing Update Algorithm）** で構成されており、各宛先プレフィックスに対して **Successor（最適な転送経路）** と **Feasible Successor（バックアップ経路）** を識別します。バックアップ経路が判定基準である **Feasibility Condition（実現可能性条件）** を満たしている場合、プライマリリンクの障害発生時に瞬時（サブ秒）で非停止切り替えを実行します。

### 主な利用目的と適用シーン
1. **確定的なループフリーパスの自動計算:** SPF（Shortest Path First）のような重いアルゴリズムを毎回転動させず、隣接ルータから通知された距離（Reported Distance）を検証することで局所的にループフリーを保証する。
2. **高速コンバージエンス（Sub-second Failover）:** 障害発生時に全網再計算（Query/Reply）を待つことなく、あらかじめ保持している Feasible Successor へ即座にトラフィックを無瞬断で切り替える。
3. **超高速リンク（10G / 40G / 100G / 400G）の識別:** EIGRP Named Mode で導入された 64-bit Wide Metrics により、ギガビット超の高速帯域リンク間での微細なメトリック差を正確に計算・反映する。
4. **不等コストロードバランシング（Unequal Cost Load Balancing）:** `variance` コマンドと組み合わせることで、帯域幅が異なる複数の有効パス（Feasible Successor）間でトラフィックを分散送出する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **Reported Distance (RD)** | 隣接ルータ（ネクストホップ）から自機へ通知された、該当隣接ルータから目的プレフィックスまでの最小計算メトリック（Advertised Distance とも呼ばれる）。 |
| **Computed Distance (CD)** | 自機から該当隣接ルータを経由して目的プレフィックスへ達するトータル計算メトリック（自機〜隣接間のリンクコスト ＋ 該当隣接ルータの RD）。 |
| **Feasible Distance (FD)** | 該当プレフィックスが最後に `Passive` ステート（安定状態）に遷移して以降に記録された、自機における **最小の Computed Distance (CD)**。 |
| **Feasibility Condition (FC)** | ループフリーを保証するための絶対条件： **`RD < FD`** （対向の Reported Distance が、自機の現在の Feasible Distance よりも厳格に小さいこと）。 |
| **Successor** | 目的プレフィックスに対して最小の Computed Distance (CD) を持ち、ルーティングテーブル（RIB）および転送テーブル（FIB）へ挿入されるプライマリネクストホップルータ。 |
| **Feasible Successor (FS)** | Feasibility Condition (`RD < FD`) を満たすバックアップネクストホップルータ。トポロジーテーブルに常時維持され、Successor 障害時に即座に Successor へ昇格する。 |
| **Classic Metrics (32-bit)** | デフォルトの 32ビット幅計算方式。10Gbps 以上の高速リンクでは帯域幅メトリックが飽和（頭打ち）し、区別できなくなる制限がある。 |
| **Wide Metrics (64-bit)** | EIGRP Named Mode で採用された 64ビット幅（Throughput / Latency ピコ秒単位）計算方式。100Gbps 超のリンクやジッター/エネルギー等の拡張属性に対応。 |

---

## 🏗 動作原理

EIGRP のパス選定およびループ判定プロセスは、DUAL トポロジーテーブル内で管理されるパラメータの関係性によって決定されます。

```text
[ Source Router (Self) ] ── (Local Link Cost: 100) ──► [ Neighbor A (Successor) ] ──► [ Destination ]
         │                                                      ▲
         │                                              (Reported Distance: 1000)
         │                                                      │
         │ (Local Link Cost: 200)                               │
         ▼                                                      │
[ Neighbor B (Candidate FS) ] ──────────────────────────────────┘
   (Reported Distance: 900)
```

### パート別の関係式と判定基準

1. **Computed Distance (CD) の算出:**
   $$	ext{CD}_{	ext{Neighbor}} = 	ext{Local Link Cost to Neighbor} + 	ext{RD}_{	ext{Neighbor}}$$
   * 上図 Neighbor A 経由: $	ext{CD}_A = 100 + 1000 = 1100$
   * 上図 Neighbor B 経由: $	ext{CD}_B = 200 + 900 = 1100$
2. **Successor の選定:**
   * 最小の CD を持つパスが Successor となる（Neighbor A または Neighbor B のいずれか、または両方）。
   * 最小 CD が $1100$ であるため、現在の Feasible Distance (FD) は $1100$ と設定される。
3. **Feasibility Condition (FC) の検証 (`RD < FD`):**
   * バックアップ候補 Neighbor B の $	ext{RD}_B = 900$。
   * 現在の $	ext{FD} = 1100$。
   * $	ext{RD}_B (900) < 	ext{FD} (1100)$ が成立するため、Neighbor B は **Feasible Successor (FS)** として認定される。

---

## ⚙ 動作シーケンス

1. **トポロジー情報の収集と CD の計算:**
   * ネイバーから Update パケットを受信すると、ルータはヘッダーおよびペロードから各プレフィックスの Reported Distance (RD) を取得します。
   * 受信インターフェイスのリンクコストを合算し、自機からの Computed Distance (CD) を算出します。
2. **Successor の選定と FD の更新 (Passive State):**
   * 最小の CD を持ったネクストホップが Successor として選択され、ルーティングテーブル（RIB）に登録されます。
   * 該当プレフィックスの Feasible Distance (FD) が、その時点の最小 CD の値に更新・固定されます。
3. **Feasible Successor (FS) の判定:**
   * 残りの非 Successor パスに対して、`RD < FD`（FC 条件）を1つずつ評価します。
   * 条件を満たすネクストホップは Feasible Successor として EIGRP トポロジーテーブルにバックアップ保持されます。
   * 条件を満たさないパスは、トポロジーテーブルには掲載されるものの「FS ではない」とフラグ付けされ、即時切替の対象外となります。
4. **障害発生時の切り替え動作 (Local Failover vs DUAL Active Query):**
   * **FS が存在する場合:** Successor リンクがダウンした瞬間、ルータは即座に FS を新たな Successor へ昇格させ、RIB を書き換えます（Active ステートに遷移せず、パケットロスゼロ〜数ミリ秒で復旧）。
   * **FS が存在しない場合:** ルータは該当プレフィックスを `Active` ステートへ変更し、すべての隣接ルータへ向けて **Query パケット** を送信して、代替経路の探索プロセス（拡散計算）を開始します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、EIGRP ベストパス選定およびメトリック計算は、トラフィックエンジニアリング（特定パスへのトラフィック誘導）や高速障害切替の要件として超頻出トピックです。

### 1. Feasibility Condition (FC) を利用したトラブルシューティング
試験問題で「リンク障害時に Query パケットを送出することなく（Active ステートに遷移させず）、サブ秒でバックアップ経路へ切り替わるよう設計せよ」という要件が出題されます。

* **ポイント:** バックアップ候補の `RD` が現在の `FD` 以上になっていると、物理リンクが存在しても FS になれません。
* **解決手法 (Offset-List または Delay の調整):**
  * **方法 A:** プライマリパス（Successor）側のメトリック（Delay）を意図的に大きくして自機の `FD` を引き上げる。
  * **方法 B:** バックアップパス側の対向ルータで送出メトリック（Delay）を小さく調整し、バックアップルータが通知してくる `RD` を引き下げる（`RD < FD` を成立させる）。

### 2. Unequal Cost Load Balancing (`variance`) の必須ルール
* **重要挙動:** `variance <multiplier>` を設定した際、トラフィック分散の対象となるのは **「Feasible Successor の条件（`RD < FD`）を満たしているパス」のみ** です。
* **試験の罠:**
  `variance 10` のように大きな倍率を設定しても、該当パスが `RD >= FD` である場合、ルーティングテーブルには絶対に追加されません。ラボ試験で「variance を設定したがロードバランスされない」という問題が出た場合、原因は 100% **Feasibility Condition の不成立** です。

### 3. Classic Metrics (32-bit) の計算式と係数 (K-Values)
デフォルトの K値: $K1=1, K2=0, K3=1, K4=0, K5=0, K6=0$。

$$	ext{Classic Metric} = 256 	imes \left( rac{10^7}{	ext{Min Bandwidth in Kbps}} + \sum 	ext{Delay in } 10\mu s 
ight)$$

* **単位の注意点:**
  * **Bandwidth:** 経路上の最小帯域幅（Kbps 単位）。
  * **Delay:** 経路上の全インターフェイスの遅延合計（$10\mu s$ ＝ Tens of Microseconds 単位）。
  * **定数 256:** 8ビットシフト（旧 IGRP 24-bit から EIGRP 32-bit へのスケーリング倍率）。

### 4. Wide Metrics (64-bit) の計算式と EIGRP Named Mode 仕様
EIGRP Named Mode では、64-bit Wide Metrics が自動的に有効化されます。

* **Wide Metric 計算基本式:**
  $$	ext{Throughput} = rac{10^7 	imes 65536}{	ext{Min Bandwidth in Kbps}}$$
  $$	ext{Latency} = rac{	ext{Sum of Delay in Picoseconds} 	imes 65536}{10^6}$$
  $$	ext{Wide Metric} = (	ext{Throughput} + 	ext{Latency}) 	imes 	ext{Scale Factor}$$
* **RIB スケーリング (Scale Factor 128):**
  Cisco IOS-XE の RIB (Routing Table) は 32ビット幅であるため、EIGRP 内部で計算された 64ビット Wide Metric は、**128 で除算（Shift right by 7）** されて RIB に登録されます。
  $$	ext{RIB Metric} = rac{	ext{Wide Metric}}{128}$$

---

## 🛠 設定方法

### 1. Named Mode における Interface Delay 調整による FS 制御

```bash
# [R1] Successor 側の遅延を調整し、Feasibility Condition (RD < FD) を成立させる
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   # 物理インターフェイスの遅延をピコ秒/マイクロ秒単位で調整
   delay 200
  exit-af-interface
 exit-address-family
```

### 2. Unequal Cost Load Balancing (`variance`) の構成

```bash
# [R1] FC を満たす FS パスに対して、最大4倍のメトリック差までロードバランシングを許可
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   variance 4
   maximum-paths 4
  exit-af-topology
 exit-address-family
```

### 3. Classic Metric / Wide Metric 64-bit 動作モード制御

```bash
# [R1] Classic Metric 互換モード（K1〜K5 のみ使用）への明示的調整
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  metric version 64bit
  metric weights 0 1 0 1 0 0
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **トポロジーテーブル内の全プレフィックス、Successor、FD、CD、FS 状態の確認** | <code>show ip eigrp topology</code> / <code>show eigrp address-family ipv4 topology</code> |
| **FC 条件を満たさない非 FS パスも含めた「すべての候補パス」の一覧表示** | <code>show ip eigrp topology all-links</code> |
| **特定プレフィックスに対する詳細メトリック構成要素（Min BW, Delay, Composite Metric）の確認** | <code>show ip eigrp topology 10.1.1.0/24</code> |
| **Wide Metrics における詳細（Throughput, Latency in ps, RIB Metric）の確認** | <code>show eigrp address-family ipv4 topology 10.1.1.0/24</code> |
| **現在適用されている K値（K1〜K6）およびメトリックバージョンの確認** | <code>show ip protocols</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **物理的なバックアップパスが存在するのに、Successor 障害時に Query パケット（Active 化）が発生する。** | バックアップパスの Reported Distance (RD) が現在の FD 以上であり、**Feasibility Condition (`RD < FD`) を満たしていない** ため FS になれていない。 | `show ip eigrp topology all-links` | 1. Successor 側のインターフェイス Delay を増やして FD を引き上げる。<br>2. バックアップ対向側の Delay を減らして RD を引き下げる。 |
| **`variance` を設定したのに、バックアップパスがルーティングテーブル（RIB）にロードバランシング掲載されない。** | 対象のバックアップパスが Feasibility Condition (`RD < FD`) を満たしておらず、FS として認識されていない。 | `show ip eigrp topology` | `show ip eigrp topology all-links` で対象パスが FS か確認し、FC 条件を満たすよう Delay/BW を調整する。 |
| **GigabitEthernet (1Gbps) と 10Gbps リンク間で EIGRP メトリックが全く変わらない。** | **Classic Metric (32-bit)** モードで動作しており、10Gbps 以上の帯域幅計算が $10^7 / 10^7 = 1$ で飽和・頭打ちになっている。 | `show ip protocols`<br>`show ip eigrp topology` | EIGRP **Named Mode** へ移行し、64-bit **Wide Metrics** を有効化してピコ秒単位の Latency 計算へ切替える。 |

---

## ⚠ 制限事項

1. **Classic Mode (32-bit) での 10Gbps 超リンク認識不可:**
   * Classic Mode（`router eigrp <AS>`）のメトリック計算式（$10^7 / 	ext{BW}$）では、10Gbps（10,000,000 Kbps）で分子と分母が等しく（1 に）なり、それ以上の 40G/100G リンクでも帯域メトリックが「1」から変化しません。
2. **Wide Metric から Classic Metric への変換損失:**
   * Wide Metric を使用している Named Mode ルータから Classic Mode ルータへ EIGRP パケットを送信する際、自動的に 32ビット変換が行われますが、高帯域リンク間の精度精度低下が発生します。

---

## 🔄 他技術との関連

* **BGP (Border Gateway Protocol):**
  EIGRP メトリック（CD）は、BGP へ再配送（Redistribute）される際、デフォルトで BGP の **MED (Multi-Exit Discriminator)** 属性へ自動変換・継承されます。
* **Policy-Based Routing (PBR):**
  PBR を使用して、EIGRP DUAL が選定した Successor / Feasible Successor のパス選定結果を無視し、送信元 IP やパケット長に基づいて別リンクへ強制転送できます。

---

## 🧩 比較表

### 1. Successor vs Feasible Successor

| 比較項目 | Successor | Feasible Successor (FS) |
| :--- | :--- | :--- |
| **役割** | プライマリ転送パス（最適経路） | バックアップ転送パス（即時切替用） |
| **選定基準** | 最小の **Computed Distance (CD)** を保持 | **`RD < FD`** (Feasibility Condition) をクリア |
| **RIB (Routing Table) 掲載** | **掲載される** | **掲載されない** (トポロジーテーブルのみ保持) |
| **障害切替速度** | - | **サブ秒 (即時)** - Query パケット送出なし |

### 2. Classic Metrics vs Wide Metrics

| 比較項目 | Classic Metrics (32-bit) | Wide Metrics (64-bit) |
| :--- | :--- | :--- |
| **サポートモード** | Classic Mode & Named Mode | **Named Mode 専用** |
| **メトリック演算幅** | 32-bit (最大 4,294,967,295) | 64-bit (内部演算 64-bit) |
| **スケーリング単位** | 帯域: $10^7 / 	ext{Kbps}$, 遅延: $10\mu s$ | Throughput (Kbps), Latency (Picoseconds) |
| **K値属性** | K1〜K5 (BW, Load, Delay, Reliability, MTU) | K1〜K6 (K6: Extended - Energy/Jitter) |
| **高帯域対応** | 10Gbps 以上でメトリック飽和 | 100Gbps / 400Gbps 以上も精密計算可能 |
| **RIB 掲載時調整** | そのまま掲載 | **128 で除算** して 32-bit RIB に格納 |

---

## 💡 ベストプラクティス

1. **EIGRP Named Mode による Wide Metrics の標準適用:**
   現代の 10G/40G/100G イーサネットインフラでは、Classic 32-bit メトリックの歪みを防ぐため、必ず Named Mode で 64-bit Wide Metrics を使用する。
2. **Interface Delay によるトラフィックエンジニアリング:**
   EIGRP のパス選定調整には、`bandwidth` コマンドではなく **`delay` コマンド** を使用する（`bandwidth` を変更すると QoS ポリシーや他のインフラ計算に悪影響を及ぼすため）。
3. **Feasible Successor の常時維持設計:**
   全拠点・冗長リンクにおいて `RD < FD` が満たされるよう、上位・下位インターフェイスの Delay 設計を行い、Query ストームの発生を設計段階で物理的に防ぐ。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI Practical Lab 試験レベルに対応する省略なしの10個の設定シナリオです。

### Scenario 1: EIGRP トポロジーテーブルの解析と Successor / FS の特定
* **要件:** R1 において目的網 `10.1.50.0/24` に対する Successor および Feasible Successor のステートを検証せよ。

**【R1】**
```bash
R1# show ip eigrp topology 10.1.50.0/24
EIGRP-IPv4 Topology Entry for AS(100)/ID(1.1.1.1) for 10.1.50.0/24
  State is Passive, query origin flag is 1, 1 Successor(s), FD is 130816
  Descriptor header storage usage 64 bytes
  10.1.12.2 (GigabitEthernet0/1), from 10.1.12.2, Send flag is 0x0
      Composite metric is (130816/128256), Route is Internal
      Vector metric:
        Minimum bandwidth is 100000 Kbit
        Total delay is 510 microseconds
        Reliability is 255/255
        Load is 1/255
        Minimum MTU is 1500
        Hop count is 2
  10.1.13.3 (GigabitEthernet0/2), from 10.1.13.3, Send flag is 0x0
      Composite metric is (156416/130000), Route is Internal
      Vector metric:
        Minimum bandwidth is 100000 Kbit
        Total delay is 1510 microseconds
        Reliability is 255/255
        Load is 1/255
        Minimum MTU is 1500
        Hop count is 3
```

**【検証方法】**
* Successor: `10.1.12.2` (CD: 130816, FD: 130816)
* Candidate Backup: `10.1.13.3` (RD: 130000)。RD (130000) < FD (130816) が成立するため、`10.1.13.3` は **Feasible Successor (FS)** であると判明。

---

### Scenario 2: Interface Delay 調整による Feasibility Condition 成立
* **要件:** R1 において、`10.1.50.0/24` 宛てのバックアップパス R3 (RD: 140000) が `RD >= FD` (現在の FD: 130816) のため FS になれていない。R1 の Successor インターフェイス (Gi0/1) の Delay を増やして FC を成立させよ。

**【R1】**
```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   delay 300
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp topology 10.1.50.0/24
# FD が増加し、R3 の RD (140000) < 新FD となり、R3 が Feasible Successor に昇格したことを確認
```

---

### Scenario 3: Unequal Cost Load Balancing (`variance`) の構成
* **要件:** R1 において、`10.1.50.0/24` 宛ての FS パス (CD: 260000) を Successor パス (CD: 130816) と同時にルーティングテーブルに掲載させ、ロードバランシングを実行させよ。

**【R1】**
```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   variance 3
  exit-af-topology
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip route 10.1.50.0
# ルーティングテーブルに 2つのネクストホップ (Gi0/1 と Gi0/2) が同時掲載されていることを確認
```

---

### Scenario 4: EIGRP Named Mode Wide Metrics (64-bit) の確認
* **要件:** R1 で 64-bit Wide Metric が適用されている詳細を確認せよ。

**【R1】**
```bash
R1# show eigrp address-family ipv4 topology 10.1.50.0/24
EIGRP-IPv4 VRF default Protocol 100 Topology Entry for AS(100)/ID(1.1.1.1)
  State is Passive, query origin flag is 1, 1 Successor(s), FD is 16744448
  Descriptor header storage usage 64 bytes
  10.1.12.2 (GigabitEthernet0/1), from 10.1.12.2, Send flag is 0x0
      Composite metric is (16744448/16416768), Route is Internal
      Vector metric:
        Minimum bandwidth is 100000 Kbit
        Total delay is 510000000 picoseconds
        Extended metric is 0
```

**【検証方法】**
* Latency が **picoseconds** (510000000 ps) 単位で表示され、Wide Metric (16744448) が計算されていることを確認。
* RIB Metric ＝ $16744448 / 128 = 130816$ となることを確認。

---

### Scenario 5: Offset-List による特定プレフィックスの Metric 増加
* **要件:** R1 において、R2 から受信する `10.1.99.0/24` のメトリックのみに 1000 を加算せよ。

**【R1】**
```bash
ip access-list standard ACL_NET_99
 permit 10.1.99.0 0.0.0.255
!
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   offset-list ACL_NET_99 in 1000 GigabitEthernet0/1
  exit-af-topology
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp topology 10.1.99.0/24
# Metric が 1000 加算されていることを確認
```

---

### Scenario 6: Classic Metric への固定設定 (Legacy Compatibility)
* **要件:** Named Mode 環境において、メトリック計算をあらかじめ Classic 32-bit 相当に強制変更せよ。

**【R1】**
```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  metric version 32bit
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip protocols
# Metric version が 32bit であることを確認
```

---

### Scenario 7: All-Links コマンドによる非 FS パスの監査
* **要件:** トポロジーテーブル内で `RD >= FD` のため隠れているすべての非 FS パスを表示せよ。

**【R1】**
```bash
R1# show ip eigrp topology all-links
```

**【検証方法】**
* 通常の `show ip eigrp topology` には出ない、条件不適合の候補パスも含めて全リストが出力されることを確認。

---

### Scenario 8: Bandwidth 変更によるメトリック影響の検証
* **要件:** インターフェイス Gi0/1 の論理帯域幅を 10Mbps (10000 Kbps) に変更し、メトリックの変化を追跡せよ。

**【R1】**
```bash
interface GigabitEthernet0/1
 bandwidth 10000
```

**【検証方法】**
```bash
R1# show ip eigrp topology
# 最低帯域幅が 10000 Kbit に更新され、CD/FD が跳ね上がったことを確認
```

---

### Scenario 9: Multi-Path Maximum-Paths 制御
* **要件:** 等コストマルチパス (ECMP) の最大パス数を 2 に制限せよ。

**【R1】**
```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   maximum-paths 2
  exit-af-topology
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip protocols
# Maximum path: 2 と表示されることを確認
```

---

### Scenario 10: トラブルシューティング（Unequal Cost Load Balancing 不動作の修復）
* **要件:** R1 で `variance 5` を設定したのに `10.2.2.0/24` 宛ての別パスが RIB に乗らない問題を診断・修復せよ。

**【原因診断と修復】**
```bash
R1# show ip eigrp topology all-links 10.2.2.0/24
# バックアップパスの RD が 200000、現在の FD が 150000 であるため RD >= FD (FC不成立) と判明。
!
# 修復: R1 の Successor インターフェイスの Delay を上げて FD を 250000 に引き上げる
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   delay 1000
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip route 10.2.2.0
# FC 条件が成立し、`variance` 効果によって 2つのパスが RIB に掲載されたことを確認
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解】Feasibility Condition と Variance の動作判定
**問題:** 
ルータ R1 のトポロジーテーブルに以下の出力があります。`variance 4` が構成された場合、ルーティングテーブル（RIB）に掲載されるネクストホップの組み合わせとして正しいものを選択・説明してください。
* Primary Path A: CD = 1000, RD = 800
* Path B: CD = 2500, RD = 950
* Path C: CD = 3200, RD = 1100

**解答・解説:**
* **現在の FD:** 1000 (Path A の CD)
* **FC 条件 (`RD < FD = 1000`):**
  * Path B: $	ext{RD}_B = 950 < 1000$ ➔ **FC 成立 (Feasible Successor)**
  * Path C: $	ext{RD}_C = 1100 \ge 1000$ ➔ **FC 不成立 (FS になれない)**
* **Variance 判定 ($	ext{CD} \le 	ext{FD} 	imes 4 = 4000$):**
  * Path B: $	ext{CD}_B = 2500 \le 4000$ 且つ FS であるため ➔ **RIB に掲載される**
  * Path C: $	ext{CD}_C = 3200 \le 4000$ だが **FS ではないため RIB に掲載されない**
* **結論:** **Path A と Path B の 2つが RIB に掲載されます。**

---

### 2. 【設計・トラブルシューティング】10Gbps / 40Gbps 混在網でのパス不整合
**問題:** 
全社ネットワークの核心トランクを 1Gbps から 10Gbps および 40Gbps へアップグレードしました。しかし、EIGRP (Classic Mode) を運用しているルータにおいて、10Gbps リンクと 40Gbps リンクのメトリックが同一のままとなり、40Gbps 優先のトラフィックルーティングが行われません。この技術的理由と、インフラ構成変更なしで直ちに解決する設定変更策を説明してください。

**解答・解説:**
* **技術的理由:** 
  Classic Mode (32-bit Metrics) の EIGRP 帯域幅計算式は $10^7 / 	ext{BW (Kbps)}$ です。10Gbps (10,000,000 Kbps) の時点で計算結果が $1$ となり飽和（頭打ち）するため、それ以上の 40Gbps リンクであっても計算上の帯域幅メトリックは同じ「1」として処理され、区別できなくなります。
* **解決策:** 
  EIGRP を **Named Mode** へ移行し、64-bit **Wide Metrics** を有効化します。Wide Metrics では Latency をピコ秒単位（10G: 10,000,000 ps、40G: 2,500,000 ps）で精密計算するため、40Gbps リンクが正しく最小メトリックとして識別され、優先パスとして選定されます。

---

## 🔗 参考リソース

* [Cisco Systems: EIGRP Configuration Guide - EIGRP Wide Metrics](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book/ire-wide-metrics.html)
* [Cisco Technical White Paper: Enhanced Interior Gateway Routing Protocol (EIGRP)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13669-1.html)
* [Cisco Live: BRKRST-2336 - EIGRP Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **メトリック計算用メモ:**
  * 1 Gbps = Delay 10 microseconds
  * 10 Gbps = Delay 10 microseconds (Classic) / 10,000,000 picoseconds (Wide)
  * 40 Gbps = Delay 2,500,000 picoseconds (Wide)
  * 100 Gbps = Delay 1,000,000 picoseconds (Wide)
* **FC 判定のゴールデンルール:**
  * 「対向の言う距離 (RD) が、自分の記録した過去最良距離 (FD) よりも小さくなければ、バックアップにはしない。」


## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [EIGRP Wide Metrics (White Paper)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/118847-tech-note-eigrp-00.html)

### CiscoLive (動画・スライド)
*   [Introduction to EIGRP - BRKENT-1187](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/BRKENT-1187.pdf) - EIGRPの基礎と概要を解説
*   [EIGRP Operations: The Usual Suspects - BRKENT-2050](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/BRKENT-2050.pdf) - EIGRPの動作原理やトラブルシューティングを解説。

### テクニカルドキュメント・設定例
*   [Introduction to EIGRP Metrics](http://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/16406-eigrp-metrics.html)
*   [EIGRP Variance and Unequal Cost Load Balancing](https://www.cisco.com/c/ja_jp/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)

---

## 📝 補足
- この学習メモは、EIGRPの単なる設定ではなく、「なぜそのパスが選ばれるのか、あるいは選ばれないのか」というDUALの論理的根拠を理解することに重点を置いています。特に Feasibility Condition (RD < FD) の数学的理解は、トラブルシューティングセクションにおける UCLB や高速コンバージェンスの課題を解決するための必須知識です。


