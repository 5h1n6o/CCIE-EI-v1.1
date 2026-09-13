---
layout: default
title: 1.4.f-Optimization
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 6
---

# 1.4.f Optimization, convergence, and scalability (OSPF Optimization)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア routing プロトコルの設計・最適化技術である **OSPF Optimization, Convergence, and Scalability（OSPF の最適化・高速コンバージエンス・拡張性）** について、Cisco IOS-XE 17.x の実装基準に完全準拠して詳細に解説します [22, 1.4.f; 23, 1.4.f; 29, 1.4.f]。

---

## 📘 概要

OSPF（Open Shortest Path First）は、大規模エンタープライズネットワークにおいて高い信頼性と柔軟性を提供するリンクステート型ルーティングプロトコルです。しかし、ネットワークの規模拡大（数千ルータ・数万プレフィックス）やミッションクリティカルなアプリケーション（VoIP、リアルタイム動画、金融取引等）の普及に伴い、デフォルト設定のまま運用すると以下のような深刻な課題が発生します [22, 1.4.f; 33, Chapter 8-9]。

1. **コンバージエンス遅延:** 物理リンク障害時の SPF 計算待機時間（デフォルト 5 秒）や LSA 再送遅延によるサブ秒レベルの通信寸断 [22, 1.4.f]。
2. **コントロールプレーンの過負荷（LSA Flapping/SPF Storm）:** 不安定なリンクによるフラッピングが原因で、ネットワーク全体のルータ CPU 高騰や LSDB（Link State Database）の頻繁な再計算が誘発される問題 [22, 1.4.f]。
3. **過渡的なトラフィックドロップ（Blackholing）:** ルータ再起動時やメンテナンス時に、上流/下流の iBGP コンバージエンスが完了する前に OSPF が先行してトラフィックを引き込んでしまい、パケットが破棄される問題 [22, 1.4.f (iii); 23, 1.4.f (iii)]。
4. **LSDB / RIB の冗長化:** トラフィックが通過するだけのトランジット接続（ルータ間 P2P リンク）の不要なサブネット情報が全エリアの LSDB/RIB を圧迫し、メモリの浪費と SPF 計算負荷増大を招く問題 [22, 1.4.f (iv); 23, 1.4.f (iv)]。

本項目（1.4.f）で定義される **Metrics（メトリック調整）**、**LSA Throttling / SPF Tuning（タイマー動的調整）**、**Stub Router（Max-Metric Router LSA）**、および **Prefix Suppression（プレフィックス抑制）** は、これらの課題を抜本的に解決し、ミリ秒単位（Sub-second）の高速コンバージエンスと優れたスケーラビリティを確立するための必須技術群です [22, 1.4.f; 23, 1.4.f; 29, 1.4.f]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **対象技術** | ① **Metrics (Auto-Cost / Manual Cost)** <br>② **LSA Throttling & SPF Tuning** <br>③ **Stub Router (Max-Metric Router LSA)** <br>④ **Prefix Suppression** |
| **主な用途** | 高速インターフェイス（1G/10G/100G）の精密パス選定、ミリ秒単位の障害検知・計算、メンテナンス時の安全な過渡的トラフィック迂回、LSDB / RIB サイズの削減 [22, 1.4.f]。 |
| **メリット** | ・100Gbps リンク等の帯域識別を正確化（`auto-cost reference-bandwidth`） [22, 1.4.f (i)]。<br>・指数バックオフ（Exponential Backoff）アルゴリズムによる CPU 保護とミリ秒コンバージエンスの両立 [22, 1.4.f (ii)]。<br>・メンテナンス時および再起動時の無瞬断迂回（Max-Metric 65535） [22, 1.4.f (iii)]。<br>・P2P トランジットサブネット隠蔽による LSDB メモリ消費の削減と SPF 高速化 [22, 1.4.f (iv)]。 |
| **デメリット / 制限事項** | ・`auto-cost` 設定の全ルータ不一致による非最適ルーティング（Sub-optimal Routing） [22, 1.4.f (i)]。<br>・タイマーを短縮しすぎることによる高負荷時のネゴシエーション破綻リスク [22, 1.4.f (ii)]。<br>・Prefix Suppression 導入時の Ping / Traceroute による途中経路可視性の低下 [22, 1.4.f (iv)]。 |
| **対応機種 / OS** | Cisco Catalyst 9000 シリーズ、Catalyst 8000v、ISR/ASR シリーズ（Cisco IOS-XE 17.x 標準） [22, 1.4.f]。 |
| **設計上の注意点** | Reference Bandwidth は OSPF ドメイン内の **すべてのルータで完全に同一値** に設定しなければならない [22, 1.4.f (i)]。 |

---

## 🏗 動作原理

各個別要素技術の動作メカニズムは以下の通りです。

### 1. Metrics & Auto-Cost Reference Bandwidth
OSPF のコスト計算式は次の通りです [22, 1.4.f (i); 33, Chapter 8]。
$$\text{Cost} = \frac{\text{Reference Bandwidth}}{\text{Interface Bandwidth}}$$

Cisco IOS-XE のデフォルト Reference Bandwidth は **`100 Mbps`** ($10^8$ bps) です [22, 1.4.f (i)]。そのため、100Mbps 以上の高速インターフェイス（1Gbps, 10Gbps, 100Gbps）はすべて計算結果が `1` 未満となり、整数切り上げによって**すべてコスト `1` として等しく扱われてしまう**という致命的な弱点があります [22, 1.4.f (i)]。

```text
【デフォルト (Reference Bandwidth = 100Mbps)】
  ・100 Mbps  リンク ➔ 100M / 100M = Cost 1
  ・1 Gbps   リンク ➔ 100M / 1000M = 0.1 ➔ Cost 1 (頭打ち)
  ・10 Gbps  リンク ➔ 100M / 10000M = 0.01 ➔ Cost 1 (頭打ち)

【推奨設定 (Reference Bandwidth = 100000Mbps = 100Gbps)】
  ・100 Mbps  リンク ➔ 100,000M / 100M = Cost 1000
  ・1 Gbps   リンク ➔ 100,000M / 1000M = Cost 100
  ・10 Gbps  リンク ➔ 100,000M / 10000M = Cost 10
  ・100 Gbps リンク ➔ 100,000M / 100000M = Cost 1
```

### 2. LSA Throttling & SPF Tuning（指数バックオフアルゴリズム）
通常のタイマー設定では、障害時に一定間隔でしか計算・生成を行いませんが、Throttling（絞り込み）機能は **指数バックオフ（Exponential Backoff）アルゴリズム** を使用し、「平常時は即座（0ms）に実行し、連続障害時は待機時間を倍増させて CPU を保護する」動的制御を行います [22, 1.4.f (ii)]。

```text
[ リンク発生/障害イベント ]
       │
       ▼
 1回目の障害 ──► 即時実行 (Start Timer: 0ms)
       │
 2回目の障害 ──► Hold Timer 待機 (例: 50ms)
       │
 3回目の障害 ──► Hold Timer 2倍 (例: 100ms)
       │
 4回目の障害 ──► Hold Timer 2倍 (例: 200ms)
       │
       ▼ (最大 Max Hold Timer まで倍増)
 静寂期間経過 (Wait Time) ──► Start Timer (0ms) へ自動リセット
```

* **`timers throttle spf <start-interval> <hold-interval> <max-interval>`:** SPF 計算開始前の遅延制御 [22, 1.4.f (ii)]。
* **`timers throttle lsa <start-interval> <hold-interval> <max-interval>`:** LSA 生成・再送制御 [22, 1.4.f (ii)]。
* **`timers lsa arrival <milliseconds>`:** 受信した同一 LSA の最小受け入れ間隔（これより短い間隔で着信した LSA は破棄） [22, 1.4.f (ii)]。

### 3. Stub Router (Max-Metric Router LSA)
ルータが自身の生成する Router LSA（Type 1）内において、すべての非スタブリンク（Point-to-Point、Transit リンク）のメトリックを最大値である **`65535`** （LSDB / SPF 上で Inaccessible とみなされるコスト）として広報する機能です [22, 1.4.f (iii)]。

```text
[ Transit Router A ] ───(Cost 65535)─── [ Router B (Stub Router) ] ───(Cost 65535)─── [ Transit Router C ]
        │                                                                                      │
        └────────────────────────── (Normal Cost 10) ──────────────────────────────────────────┘
                                 (トラフィックは Router B を通過せず迂回)
```

* **使用用途:**
  1. **`on-startup <seconds>`:** ルータ再起動後、指定秒数間メトリックを 65535 に維持。この間に BGP などの上位プロトコルが完全コンバージエンスするのを待ち、トラフィックのブラックホール化を防ぐ [22, 1.4.f (iii)]。
  2. **`on-startup wait-for-bgp`:** BGP ピアリングが完全に確立（Established）してフルルートを受信するまで 65535 を維持 [22, 1.4.f (iii)]。
  3. **`include-stub`:** スタブネットワーク（Loopback や末端 CIDR）もすべて 65535 にするか、または通常コストのまま広報するかを制御 [22, 1.4.f (iii)]。

### 4. Prefix Suppression（プレフィックス抑制）
OSPF のトポロジー計算（SPF）に必要な情報は **ルータID、ネイバーIP、およびインターフェイスの接続形態** であり、**ルータ間を接続する P2P サブネットの IP プレフィックス自体はトポロジー計算には不要** です [22, 1.4.f (iv)]。 Prefix Suppression を有効化すると、Router LSA (Type 1) や Network LSA (Type 2) からトランジットリンクの IP プレフィックス情報が消去（Suppressed）されます [22, 1.4.f (iv)]。

```text
【Prefix Suppression 未設定時】
 Router LSA:
   - Link ID: 10.1.12.2 (Neighbor RID)
   - Link Data: 10.1.12.1 (Local Interface IP)
   - Type: Point-to-Point
   - Link ID: 10.1.12.0 (Subnet IP)  <--- 不要な IP プレフィックス情報
   - Link Data: 255.255.255.0        <--- 不要な マスク情報

【Prefix Suppression 有効化時】
 Router LSA:
   - Link ID: 10.1.12.2 (Neighbor RID)
   - Link Data: 10.1.12.1 (Local Interface IP)
   - Type: Point-to-Point
   (Subnet IP プレフィックス情報が消去され、LSDB/RIB が大幅軽量化される。Loopback は保持される)
```

---

## ⚙ 動作シーケンス

1. **コストネゴシエーションと選定シーケンス:**
   * インターフェイスの物理帯域（`bandwidth`）を取得 ➔ `auto-cost reference-bandwidth` に基づき個別コストを動的算出 [22, 1.4.f (i)]。
   * インターフェイス単位の `ip ospf cost` 設定が存在する場合は、グローバル算出値を**オーバーライド（最優先適用）** [22, 1.4.f (i)]。
2. **高速コンバージエンス実行シーケンス (障害検出時):**
   * BFD または物理 Link Down によりミリ秒単位で障害を検知 [22, 1.2.j, 1.4.f]。
   * **LSA Throttling 起動:** `start-interval`（例: 0ms）で直ちに LSA を生成・送出 [22, 1.4.f (ii)]。
   * **SPF Tuning 起動:** 対向からの LSA 着信後、`start-interval`（例: 50ms）で SPF 計算を実行し、RIB/FIB を更新 [22, 1.4.f (ii)]。
   * **連続フラップ発生時:** 次回の計算待機時間が `hold-interval` ➔ `max-interval` へと動的に倍増拡大し、CPU 暴走を防止 [22, 1.4.f (ii)]。
3. **メンテナンス時の Stub Router 動作シーケンス:**
   * 管理者が `max-metric router-lsa` コマンドを投入 [22, 1.4.f (iii)]。
   * ルータは自身の Type-1 LSA（Router LSA）のシーケンス番号をインクリメントし、全 Transit リンクのコストを `65535` に書き換えて LSA をフラッシュ（LSU 送出） [22, 1.4.f (iii)]。
   * 全エリアの隣接ルータが新 LSA を受信し、即座に SPF を再計算。該当ルータを経由していた Transit トラフィックが迂回ルートへシームレスにシフト [22, 1.4.f (iii)]。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、OSPF Optimization は「ネットワークのコンバージエンス時間を短縮せよ」「メンテナンス時のパケットドロップを回避せよ」「不要なプレフィックスを LSDB から排除せよ」といった条件厳守のタスクとして多出されます [22, 1.4.f; 23, 1.4.f; 29, 1.4.f]。

### 1. 必修の設定ポイントと引数の仕様
* **Auto-Cost Reference Bandwidth の単位指定:**
  `auto-cost reference-bandwidth <Mbit/s>` コマンドの単位は **Mbps** です [22, 1.4.f (i)]。
  * 10 Gbps に設定する場合 ➔ `auto-cost reference-bandwidth 10000`
  * 100 Gbps に設定する場合 ➔ `auto-cost reference-bandwidth 100000`
  ※設定投入時、コンソールに `%NOTICE: OSPF: auto-cost is different across routers` という警告が表示されます。ドメイン内全ルータへ同一投入することが採点基準となります [22, 1.4.f (i)]。
* **LSA / SPF タイマーの単位指定:**
  * `timers throttle spf <start> <hold> <max>` ➔ 単位は **ミリ秒 (ms)** （例: `timers throttle spf 50 100 5000`） [22, 1.4.f (ii)]。
  * `timers throttle lsa <start> <hold> <max>` ➔ 単位は **ミリ秒 (ms)** （例: `timers throttle lsa 10 100 5000`） [22, 1.4.f (ii)]。
  * `timers lsa arrival <ms>` ➔ 単位は **ミリ秒 (ms)** （例: `timers lsa arrival 80`） [22, 1.4.f (ii)]。

### 2. Max-Metric Router LSA のオプション指定トラップ
* **問題の指示文:** 「ルータ再起動後、BGP が完全にコンバージエンスするまで、または最大 10 分間トラフィックの通過を防ぐように設定せよ」
* **正解コマンド:**
  ```bash
  router ospf 1
   max-metric router-lsa on-startup wait-for-bgp 600
  ```
* **注意点:** 単に `max-metric router-lsa` とだけ設定すると、**恒久的に Transit トラフィックを拒否** してしまい、ルーティング試験の大部分で減点対象となります [22, 1.4.f (iii)]。必ず `on-startup` や `include-stub` 等のサブオプションの有無を要件から正確に読み取ってください [22, 1.4.f (iii)]。

### 3. Prefix Suppression の適用レベルと Loopback 保護
* **グローバル有効化:** `router ospf 1` 配下で `prefix-suppression` を設定すると、プロセスに属するすべての P2P / Broadcast インターフェイスでサブネット情報が隠蔽されます [22, 1.4.f (iv)]。
* **特定の Loopback やポートを例外指定:**
  インターフェイス配下で `no ip ospf prefix-suppression` を投入すれば、そのポートのみサブネット情報を明示的に露出できます [22, 1.4.f (iv)]。
* **重要挙動:** Prefix Suppression は **Loopback インターフェイスのアドレス（/32 Host Route）を絶対的に抑制・隠蔽しません。** Loopback は保護される仕様となっています [22, 1.4.f (iv)]。

---

## 🛠 設定方法

### 1. Auto-Cost Reference Bandwidth & インターフェイス個別コスト調整

```bash
# グローバル Reference Bandwidth を 100Gbps に変更
router ospf 1
 auto-cost reference-bandwidth 100000
exit

# インターフェイス個別コストの上書き設定 (OSPFv2 / OSPFv3)
interface GigabitEthernet1/0/1
 ip ospf cost 50
 ospfv3 cost 50
```

### 2. Fast Convergence (LSA Throttling / SPF Tuning / LSA Arrival)

```bash
router ospf 1
 # SPF 計算タイマー: Start=50ms, Initial Hold=100ms, Max Hold=5000ms
 timers throttle spf 50 100 5000
 
 # LSA 生成タイマー: Start=10ms, Initial Hold=100ms, Max Hold=5000ms
 timers throttle lsa 10 100 5000
 
 # 同一 LSA 受信最小間隔: 80ms
 timers lsa arrival 80
exit
```

### 3. Max-Metric Stub Router (再起動時・BGP 連携・恒久設定)

```bash
router ospf 1
 # 構成パターン A: 再起動後 BGP コンバージエンス完了まで (最大 300 秒) Max-Metric 化
 max-metric router-lsa on-startup wait-for-bgp 300
 
 # 構成パターン B: メンテナンス時の即時・恒久 Max-Metric 化 (Stub ネットワークも含む)
 # max-metric router-lsa include-stub
exit
```

### 4. Prefix Suppression (プロセスレベル一括 & インターフェイス例外)

```bash
# プロセス全体で P2P/Broadcast リンクのサブネット隠蔽を有効化
router ospf 1
 prefix-suppression
exit

# 特定インターフェイスのみサブネット隠蔽を免除 (露出)
interface GigabitEthernet1/0/2
 no ip ospf prefix-suppression
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Reference Bandwidth、タイマー設定（SPF/LSA Throttling）、Prefix Suppression 状態の監査** | <code>show ip ospf</code> / <code>show ospfv3</code> |
| **インターフェイスごとの個別コスト、Prefix Suppression 適用状態の確認** | <code>show ip ospf interface <int></code> / <code>show ip ospf interface brief</code> |
| **Max-Metric (コスト 65535) が Router LSA 内に正常反映されているかの監査** | <code>show ip ospf database router self-originate</code> |
| **Prefix Suppression によって Type-1 / Type-2 LSA 内の Stub Link が削除されているかの確認** | <code>show ip ospf database router</code> |
| **SPF 計算実行履歴、所要時間、トリガーとなった LSA の監査** | <code>show ip ospf statistics timer</code> / <code>show ip ospf log-adj</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **10G リンクよりも 1G リンク経由の経路が優先されてしまう（非最適パス）。** | `auto-cost reference-bandwidth` がデフォルト（100Mbps）のままであり、1G と 10G のコストが共に `1` と評価されている。 | `show ip ospf interface` | ドメイン内の全ルータで `auto-cost reference-bandwidth 100000` (100G 基準) を一括設定する [22, 1.4.f (i)]。 |
| **メンテナンス用に投入した `max-metric router-lsa` を解除したのに、依然としてトラフィックが迂回される。** | `on-startup` なしの直設定を入れており、設定がスタートアップ状態ではなく恒久適用（Persistent）されている。 | `show running-config \| sec ospf` | 単純な `max-metric router-lsa` 設定を `no` で削除するか、`on-startup` オプション付きの構文へ修正する [22, 1.4.f (iii)]。 |
| **Prefix Suppression を有効化したら Ping / Traceroute で途中ルータの IP が応答しなくなった。** | トランジットリンクの IP アドレスが RIB から消去された正常な動作。機能不全ではない。 | `show ip route ospf` | 運用上 Traceroute 応答が必要な特定リンクについては、該当ポートで `no ip ospf prefix-suppression` をバインドする [22, 1.4.f (iv)]。 |
| **LSA Flapping 発生時に OSPF ネイバーが離脱・再接続を繰り返す。** | `timers lsa arrival` より短い間隔で対向から LSA が連続再送され、着信 LSA が破棄されている。 | `show ip ospf statistics` | 対向ルータの `timers throttle lsa` と自ルータの `timers lsa arrival` の整合性を確保する（LSA Arrival $\le$ LSA Hold） [22, 1.4.f (ii)]。 |

---

## ⚠ 制限事項

1. **Auto-Cost 不一致による非対称ルーティング:**
   一部のルータのみで `reference-bandwidth` を変更すると、往路と復路で異なるパスを通過する非対称ルーティング（Asymmetric Routing）が発生し、Stateful Firewall や CoPP でパケットがドロップされる原因となります [22, 1.4.f (i)]。
2. **Prefix Suppression の対象制限:**
   Prefix Suppression が作用するのは **Type-1 Router LSA および Type-2 Network LSA 内の内部トランジットサブネット情報のみ** です。外部再配送ルート（Type-5 / Type-7 LSA）やエリア間集約ルート（Type-3 LSA）を隠蔽・抑止することはできません [22, 1.4.f (iv)]。

---

## 🔄 他技術との関連

* **BGP (Border Gateway Protocol):**
  iBGP の Established 成立（TCP セッションおよびフルルート受信）までの間、`max-metric router-lsa on-startup wait-for-bgp` を活用して OSPF 側のコストを 65535 に保ち、BGP 未コンバージエンス時のブラックホール化を防ぎます [22, 1.4.f (iii); 23, 1.4.f (iii)]。
* **BFD (Bidirectional Forwarding Detection):**
  LSA/SPF Throttling と併用することで、「ミリ秒単位の障害検知 ➔ 0ms での LSA 生成 ➔ 50ms での SPF 計算」という超高速フルコンバージエンスチェーン（Sub-100ms Convergence）を構築します [22, 1.2.j, 1.4.f]。
* **MPLS L3VPN / Segment Routing:**
  アンダーレイ OSPF 網において Prefix Suppression を適用することで、Core (P) ルータの RIB / FIB サイズを極限まで削減し、Label Switching のパケット転送処理効率を最大化します [22, 1.4.f (iv); 23, 3.2.b]。

---

## 🧩 比較表

### OSPF 高速コンバージエンス＆最適化機能の比較

| 機能名 | 目的 | 設定階層 | トラフィック/LSDB への影響 |
| :--- | :--- | :--- | :--- |
| **Auto-Cost Ref-BW** | 高速リンク（1G/10G/100G）のコスト計算正確化 | プロセス直下 (`router ospf`) | パス選定メトリック値を補正 [22, 1.4.f (i)] |
| **SPF / LSA Throttling** | 指数バックオフによるミリ秒再計算と CPU 保護 | プロセス直下 (`router ospf`) | 計算・生成タイマーをミリ秒に短縮 [22, 1.4.f (ii)] |
| **Stub Router (Max-Metric)** | トラフィックの過渡的・即時迂回制御 | プロセス直下 (`router ospf`) | 自ルータ経由の Transit パスをコスト 65535 化 [22, 1.4.f (iii)] |
| **Prefix Suppression** | LSDB / RIB サイズ削減と SPF 計算高速化 | プロセス直下 または ポート個別 | Router/Network LSA から不要 IP プレフィックスを消去 [22, 1.4.f (iv)] |

---

## 💡 ベストプラクティス

1. **Reference Bandwidth の 100Gbps 統一基準:**
   現代のエンタープライズ網では、すべてのルータで `auto-cost reference-bandwidth 100000` を標準テンプレートとして配布する [22, 1.4.f (i)]。
2. **Max-Metric Router LSA の防衛的適用:**
   BGP を運用するコアルータおよび ABR/ASBR では、必ず `max-metric router-lsa on-startup wait-for-bgp 600` をバインドし、機器再起動時の通信障害事故を未然に防止する [22, 1.4.f (iii)]。
3. **Prefix Suppression によるアンダーレイ軽量化:**
   SD-Access や MPLS アンダーレイ網の OSPF では、ルータ間接続リンクに対して一括で Prefix Suppression を有効化し、Loopback アドレスのみでコントロールプレーンを完結させる [22, 1.4.f (iv)]。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Auto-Cost Reference Bandwidth の 100Gbps 基準設定
* **要件:** ドメイン内のすべての OSPFv2 プロセスにおいて、100Gbps リンクをコスト `1` として正しく計算できるよう設定せよ [22, 1.4.f (i)]。

```bash
router ospf 1
 auto-cost reference-bandwidth 100000
exit
```

**【検証方法】**
```bash
show ip ospf interface GigabitEthernet1/0/1
# 「Cost: 100」 (1Gbps リンクの場合 100,000 / 1,000 = 100) と表示されることを確認
```

---

### Scenario 2: インターフェイス個別 OSPF コストの完全固定
* **要件:** R1 の Gi0/1 の OSPFv2 コストを `15`、OSPFv3 コストを `15` に手動設定せよ [22, 1.4.f (i)]。

```bash
interface GigabitEthernet0/1
 ip ospf cost 15
 ospfv3 cost 15
```

**【検証方法】**
```bash
show ip ospf interface GigabitEthernet0/1
# Cost が手動オーバーライドされて 15 に設定されていることを確認
```

---

### Scenario 3: LSA / SPF Throttling によるミリ秒コンバージエンス構築
* **要件:** 以下のタイマー要件を満たすよう OSPFv2 プロセス 1 を構成せよ [22, 1.4.f (ii)]。
  - SPF 計算: Start 50ms, Initial Hold 100ms, Max Hold 5000ms
  - LSA 生成: Start 10ms, Initial Hold 100ms, Max Hold 5000ms
  - LSA Arrival: 80ms

```bash
router ospf 1
 timers throttle spf 50 100 5000
 timers throttle lsa 10 100 5000
 timers lsa arrival 80
exit
```

**【検証方法】**
```bash
show ip ospf
# 「Initial SPF schedule delay 50 msecs」「Minimum hold time between two consecutive SPFs 100 msecs」等の表示を確認
```

---

### Scenario 4: Max-Metric Router LSA (起動時 BGP 完了待ち 600 秒)
* **要件:** R1 再起動時、iBGP が完全に確立するまで、または最大 600 秒間、自身を経由する Transit トラフィックを迂回させるよう設定せよ [22, 1.4.f (iii)]。

```bash
router ospf 1
 max-metric router-lsa on-startup wait-for-bgp 600
exit
```

**【検証方法】**
```bash
show ip ospf database router self-originate
# Router LSA 内の各 Transit リンクの Metric が 65535 になっていることを確認
```

---

### Scenario 5: Max-Metric Router LSA (メンテナンス時の即時・恒久適用)
* **要件:** R2 をメンテナンス状態にするため、直ちにすべての Transit リンクおよび Stub リンクのコストを最大値に書き換えてトラフィックを迂回させよ [22, 1.4.f (iii)]。

```bash
router ospf 1
 max-metric router-lsa include-stub
exit
```

**【検証方法】**
```bash
show ip ospf database router self-originate
# Stub link を含む全リンクの Metric が 65535 に変更されたことを確認
```

---

### Scenario 6: プロセスレベルでの Prefix Suppression 一括バインド
* **要件:** OSPFv2 プロセス 1 に属するすべてのトランジットリンクの IP プレフィックス情報を LSA から隠蔽せよ [22, 1.4.f (iv)]。

```bash
router ospf 1
 prefix-suppression
exit
```

**【検証方法】**
```bash
show ip ospf database router self-originate
# Type-1 Router LSA から Subnet プレフィックス情報が消去されていることを確認
```

---

### Scenario 7: Prefix Suppression からの特定ポート例外解除
* **要件:** プロセスで Prefix Suppression が有効な環境下で、Gi0/2 のサブネット情報のみを明示的に露出させよ [22, 1.4.f (iv)]。

```bash
interface GigabitEthernet0/2
 no ip ospf prefix-suppression
```

**【検証方法】**
```bash
show ip ospf interface GigabitEthernet0/2
# 「Prefix-suppression is disabled」と出力されることを確認
```

---

### Scenario 8: OSPFv3 Address Family での Max-Metric 構成
* **要件:** OSPFv3 プロセス 10 の IPv4 および IPv6 アドレスファミリー双方で、起動時 300 秒間の Max-Metric 迂回を設定せよ [22, 1.4.b, 1.4.f (iii)]。

```bash
router ospfv3 10
 address-family ipv4 unicast
  max-metric router-lsa on-startup 300
 exit-address-family
 !
 address-family ipv6 unicast
  max-metric router-lsa on-startup 300
 exit-address-family
exit
```

**【検証方法】**
```bash
show ospfv3 10 ipv4 database router self-originate
show ospfv3 10 ipv6 database router self-originate
```

---

### Scenario 9: BFD + LSA/SPF Throttling 超高速コンバージエンス複合構成
* **要件:** R1-R2 間の Gi0/1 上で BFD をバインドし、OSPF タイマーを最適化してサブ 100ms コンバージエンスを達成せよ [22, 1.2.j, 1.4.f]。

```bash
bfd-template single-hop BFD_OSPF
 interval min-tx 50 min-rx 50 multiplier 3
!
interface GigabitEthernet0/1
 ip ospf bfd
!
router ospf 1
 bfd all-interfaces
 timers throttle spf 10 50 2000
 timers throttle lsa 10 50 2000
 timers lsa arrival 40
exit
```

**【検証方法】**
```bash
show bfd neighbors client ospf
```

---

### Scenario 10: VRF-Aware OSPF インターフェイスでの Prefix Suppression 適用
* **要件:** VRF `TENANT_A` に属する OSPF プロセスにおいて、P2P リンクのサブネット隠蔽を有効化せよ [22, 1.2.e, 1.4.f (iv)]。

```bash
router ospf 100 vrf TENANT_A
 prefix-suppression
exit
```

**【検証方法】**
```bash
show ip ospf 100 vrf TENANT_A database router self-originate
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解・トラブルシューティング】高速リンク配下での非最適パス
**問題:** 
ルータ R1, R2, R3 が三角形に接続されています。R1-R2 間は 10Gbps リンク、R1-R3-R2 間は 1Gbps リンクです。しかし、R1 から R2 の Loopback 宛てのトラフィックを `show ip route` で確認したところ、10Gbps の直結リンクではなく 1Gbps 経由（R1-R3-R2）にロードバランシングされているか、意図しないパスが選択されていました。コンフィグ原因と修復コマンドを述べてください。

**解答・解説:**
* **原因:** 
  Cisco IOS-XE のデフォルト `auto-cost reference-bandwidth` は 100Mbps です [22, 1.4.f (i)]。そのため、1Gbps リンクのコスト（100M/1000M = 0.1 ➔ Cost 1）と 10Gbps リンクのコスト（100M/10000M = 0.01 ➔ Cost 1）が**共にコスト `1` として等しく計算**されており、両経路の合計コストが同一になっていたことが原因です [22, 1.4.f (i)]。
* **修復コマンド:** 
  すべてのルータの OSPF プロセス配下で Reference Bandwidth を 100Gbps 基準へ引き上げます [22, 1.4.f (i)]。
  ```bash
  router ospf 1
   auto-cost reference-bandwidth 100000
  ```

---

### 2. 【Design / トラブルシューティング】メンテナンス後のブラックホール障害
**問題:** 
ルータ R1 のメンテナンス終了後、R1 をネットワークに再組み込みした直後から約 2 分間、R1 を通過する iBGP トラフィックで大規模なパケットドロップ（ブラックホール）が発生しました。原因を分析し、再起動・組み込み時にパケットドロップを一切発生させないための推奨コンフィグを提示してください。

**解答・解説:**
* **原因:** 
  R1 の OSPF（IGP）が物理リンク確立直後に超高速でコンバージエンスし、上流/下流ルータが R1 を Transit ルータとして選択しました [22, 1.4.f (iii)]。しかし、R1 上の iBGP セッション確立および BGP ルートの全件受信（RIB/FIB への掲載）には時間がかかったため、BGP フルルートを持たない R1 にトラフィックが流入し、パケットが破棄（ブラックホール化）されました [22, 1.4.f (iii)]。
* **推奨コンフィグ:** 
  `max-metric router-lsa on-startup wait-for-bgp` を有効化し、iBGP が完全コンバージエンスするまで OSPF コストを 65535 に保たせます [22, 1.4.f (iii)]。
  ```bash
  router ospf 1
   max-metric router-lsa on-startup wait-for-bgp 600
  ```

---

## 🔗 参考リソース

* [Cisco Systems: OSPF Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-3s/iro-xe-3s-book.html)
* [Cisco Command Reference: OSPF Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/command/iro-cr-book.html)
* [Cisco Live: BRKRST-2337 - OSPF Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **OSPF 最適化設定チェックリスト:**
  1. `auto-cost reference-bandwidth 100000` を全ルータに投入済みか？ [22, 1.4.f (i)]
  2. BGP 稼働ルータに `max-metric router-lsa on-startup wait-for-bgp` が投入されているか？ [22, 1.4.f (iii)]
  3. `timers throttle spf / lsa` の引数がミリ秒指定になっているか？ [22, 1.4.f (ii)]
  4. Prefix Suppression 有効化時に特定端末ポートの露出漏れがないか？ [22, 1.4.f (iv)]


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   **BRKENS-2337: OSPF Deployment in Modern Networks** - モダンなネットワークでのOSPF設計と、Prefix Suppression、LSA Throttlingの深掘り。
*   **BRKRST-3320: Troubleshooting Routing Protocols** - OSPFのコンバージェンス問題（MTUミスマッチ、タイマー不整合等）のトラブルシューティング手法。
*   **BRKCCIE-3000: OSPF for the CCIE Candidates** - LSDBの最適化と高速切替のメカニズム解説。

### Configurationガイド
*   [OSPFv2 Configuration Guide: Optimization and Scalability (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html) - 公式の最適化設定ガイド。
*   [OSPFv3 Address Family Support Configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html) - IPv4/IPv6統合環境の構成ガイド。

### テクニカルドキュメント・設定例
*   [OSPF Cost Calculation and Reference Bandwidth](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/7039-1.html#anc18) - コスト計算の技術詳細。
*   [Introduction to OSPF LSA Throttling and SPF Tuning](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13697-14.html) - タイマー調整のベストプラクティス。
*   [Understanding the OSPF Stub Router Advertisement Feature](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/47870-ospfdb11.html) - Stubルータ機能の詳細解説。

---

## 📝 補足
- この学習メモは、OSPFの「守り（安定性）」と「攻め（高速性）」のバランスをいかに取るかというCCIEレベルの難題に対する解答を網羅しています。特に `max-metric router-lsa` や `prefix-suppression` は、実際のラボ試験で複雑な要件を満たすための「決め手」となることが多いため、実機での LSA 挙動確認を欠かさないようにしてください。


