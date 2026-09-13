---
layout: default
title: 1.4.c-Network-types-area-types
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.4.c Network types, area types

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP である **OSPFv2 および OSPFv3 の Network Types（ネットワークタイプ）と Area Types（エリアタイプ）** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

OSPF（Open Shortest Path First）は、インターフェイスの物理・論理的特性に応じた **Network Types（ネットワークタイプ）** と、Link-State Database（LSDB）の規模抑制およびトポロジーの階層化を実現する **Area Types（エリアタイプ）** を備えています。

### 1. Network Types の概要と目的
OSPF は接続されているメディア（Ethernet、Serial、Frame-Relay、DMVPN、Loopback 等）の物理的・論理的性質に基づき、適切なネットワークタイプを適用します。ネットワークタイプによって、以下が自動的または手動で制御されます。
* **DR（Designated Router）/ BDR（Backup Designated Router）選出の要否**
* **Hello / Dead タイマーのデフォルト値（10s/40s または 30s/120s）**
* **パケット宛先 IP（マルチキャスト `224.0.0.5`/`224.0.0.6` または ユニキャスト）**
* **ネクストホップのアドレス処理およびホストルート（/32）の動的生成挙動**

### 2. Area Types の概要と目的
大規模ネットワークにおいて全ルータが単一エリア（Area 0）に所属すると、LSDB の肥大化、SPF 計算の頻発、メモリ・CPU 負荷の高騰を引き起こします。これを防ぐため、OSPF はネットワークをエリア分割し、境界ルータ（ABR / ASBR）において **LSA のタイプ（Type-1〜Type-7）の伝搬・透過を制限する特殊エリア（Stub, Totally Stubby, NSSA, Totally NSSA）** を定義します。

---

## 🔑 要点

### OSPF Network Types の要点一覧

| ネットワークタイプ | DR/BDR選出 | デフォルトタイマー (Hello/Dead) | パケット送信方式 | 主な用途・適用セグメント | 特記事項 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Broadcast** | **あり** | 10秒 / 40秒 | マルチキャスト<br>(`224.0.0.5` / `224.0.0.6`) | Ethernet, VLAN (SVI), Switched Fabric | デフォルトの LAN タイプ。DR/BDR選出により LSA 交換フローを N 個に削減。 |
| **Point-to-Point** | **なし** | 10秒 / 40秒 | マルチキャスト<br>(`224.0.0.5`) | HDLC, PPP, P2P GRE, P2P Subinterface | DR/BDR 選出シーケンスを完全バイパスし、アジャセンシー形成が高速。 |
| **Point-to-Multipoint** | **なし** | 30秒 / 120秒 | マルチキャスト<br>(`224.0.0.5`) | DMVPN Phase 1/3, Hub & Spoke, Frame-Relay | 各対向スポークへの **/32 ホストルートを自動生成**。スポーク間直接通信を保証。 |
| **Point-to-Multipoint Non-Broadcast** | **なし** | 30秒 / 120秒 | ユニキャスト | 擬似ブロードキャスト不可の Hub & Spoke 網 | 手動 `neighbor` 定義が必要。マルチキャスト不能な NBMA 環境用。 |
| **Non-Broadcast (NBMA)** | **あり** | 30秒 / 120秒 | ユニキャスト | Frame-Relay, ATM, 一部 DMVPN | 手動 `neighbor` 定義が必要。Hub ルータを DR に固定するため Priority 調整が必須。 |
| **Loopback** | **なし** | - | - | Loopback インターフェイス | 物理マスクが `/24` 等であっても、LSDB 上では **自動的に `/32` ホストルート化** される。 |

---

### OSPF Area Types の要点一覧

| エリアタイプ | 透過許可 LSA | 透過ブロック LSA | デフォルトルート (`0.0.0.0/0`) 自動注入 | ABR 設定コマンド | 特記事項 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Backbone (Area 0)** | Type 1, 2, 3, 4, 5 | なし | なし（手動配信可） | - | 全エリア間通信の中心。原則として全非バックボーンエリアと物理/論理接続が必要。 |
| **Standard (Normal)** | Type 1, 2, 3, 4, 5 | なし | なし | - | デフォルトのエリア。すべての LSA タイプが透過・保持される。 |
| **Stub Area** | Type 1, 2, 3 | **Type 4, 5** (External) | **あり** (Type-3 LSA) | `area <id> stub` | 外部経路（ASBR 由来）を排除。ABR が自動的に Type-3 デフォルトルートを注入。 |
| **Totally Stubby Area** | Type 1, 2 (エリア内) | **Type 3, 4, 5** | **あり** (Type-3 LSA) | `area <id> stub no-summary` | 外部経路に加え、他エリア経路（Inter-Area）も排除。ABR が Type-3 デフォルトルートのみを注入。 |
| **Not-So-Stubby (NSSA)** | Type 1, 2, 3, **Type 7** | **Type 4, 5** | **なし** (手動設定が必要) | `area <id> nssa` | スタブエリア内に ASBR を設置可能。Type-7 LSA を使用し、NSSA ABR で Type-5 LSA へ変換。 |
| **Totally NSSA** | Type 1, 2, **Type 7** | **Type 3, 4, 5** | **あり** (Type-3 LSA) | `area <id> nssa no-summary` | NSSA に加え Inter-Area 経路も排除。`no-summary` 付与により ABR が **自動的に** デフォルトルートを注入。 |

---

## 🏗 動作原理

### 1. Broadcast ネットワークタイプにおける DR / BDR 動作フロー

Broadcast メディアでは、全ルータが対等にフルメッシュアジャセンシーを確立すると、隣接関係の数が N(N-1)/2 となり、LSU/LSAck のトラフィックが爆発的に増加します。これを回避するため **DR（Designated Router）** と **BDR（Backup Designated Router）** が選出されます。

```text
[ DROTHER Router A ]                      [ DROTHER Router B ]
        │                                        │
        │─── LSU (Multicast: 224.0.0.6) ────────►│ (DROTHER は無視)
        │                                        │
        ▼                                        ▼
========================================================================
                      [ DR Router (224.0.0.6 受信) ]
========================================================================
        │
        │─── LSU (Multicast: 224.0.0.5) ────────►全ルータ (DROTHER A, B, BDR) へ再転送
        ▼
```

* **DR/BDR 選出基準:**
  1. インターフェイス OSPF Priority（`ip ospf priority <0-255>`、デフォルト `1`）。`0` のルータは DR/BDR に絶対選出されない（DROTHER 固定）。
  2. Priority が同点の場合、最高 **Router ID** を持つルータが選出される。
  3. **非プリエンプティブ（Non-preemptive）動作:** 既に DR/BDR が決定している環境に、より高い Priority や Router ID を持つルータが追加されても、既存の DR/BDR は降格しない。

---

### 2. NSSA エリアにおける Type-7 ➔ Type-5 LSA 変換メカニズム

NSSA（Not-So-Stubby Area）内部に存在する ASBR が外部経路を再配送すると、それは **Type-7 LSA (NSSA External LSA)** として NSSA エリア内限定でフラッディングされます。

```text
[ External Domain ]
        │
        ▼ (Redistribute)
[ ASBR (NSSA 内) ] ─── Type-7 LSA ───► [ NSSA ABR (Translator) ] ─── Type-5 LSA ───► [ Backbone Area 0 ]
                                              │
                                              ├─ Router-ID が最大の ABR が Translator に選出
                                              └─ P-bit (Propagate) が 1 の場合のみ Type-5 へ変換
```

1. **P-Bit（Propagate Bit）判定:** Type-7 LSA ヘッダー内の P-Bit が `1` に設定されている場合、NSSA ABR はこれを Type-5 LSA に変換して Area 0 へ注入します。
2. **NSSA Translator 選出:** 複数の ABR が NSSA エリアに接している場合、**Router ID が最も大きい ABR** が自動的に NSSA Translator（変換担当ルータ）として動作します。

---

## ⚙ 動作シーケンス

### OSPF エリアタイプによる LSA フィルタリング評価シーケンス

```text
パケット/LSA 受信・生成
   │
   ├─► LSA Type-5 (External LSA)? 
   │      ├─ YES ➔ エリアが Stub / Totally Stubby / NSSA / Totally NSSA かチェック
   │      │         ├─ YES ➔ LSA 破棄 (エリア内進入をブロック)
   │      │         └─ NO  ➔ 正常に LSDB に格納しフラッディング
   │
   ├─► LSA Type-3 (Summary LSA)?
   │      ├─ YES ➔ エリアが Totally Stubby または Totally NSSA かチェック
   │      │         ├─ YES ➔ LSA 破棄 (デフォルトルート以外の Type-3 をブロック)
   │      │         └─ NO  ➔ 正常に LSDB に格納しフラッディング
   │
   └─► LSA Type-7 (NSSA External LSA)?
          ├─ YES ➔ エリアが NSSA または Totally NSSA かチェック
          │         ├─ YES ➔ NSSA エリア内へフラッディング ➔ ABR (Translator) で Type-5 に変換して Area 0 へ注入
          │         └─ NO  ➔ 無効な LSA として破棄
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、`Network types` と `Area types` は単一の知識問ではなく、トラフィックエンジニアリング、デフォルトルート注入、サブネットマスクの維持、およびサブ秒コンバージエンスとの複合課題として出題されます。

### 1. Network Types の出題ポイントと落とし穴

* **Point-to-Point 化による DR/BDR 選出無効化:**
  * **要件:** 「VLAN 10 網において DR/BDR 選出処理のオーバーヘッドを削減し、アジャセンシー形成を高速化せよ」
  * **対策:** 該当インターフェイスで `ip ospf network point-to-point` を設定する。両端のルータでネットワークタイプを一致させないと、ネイバーは `FULL` になっても **IP ルートが RIB に掲載されない（LSA Mismatch）** 事態が発生します。
* **Loopback インターフェイスの `/32` ホストルート問題:**
  * **要件:** 「R1 の Loopback0 (`10.1.1.1/24`) を、サブネットマスクの長さを維持（`/24`）したまま OSPF でアドバタイズせよ」
  * **対策:** OSPF はデフォルトで Loopback を `LOOPBACK` タイプとして認識し、`/32` でアドバタイズします。これを防ぐため、Loopback インターフェイス配下で `ip ospf network point-to-point` を投入します。
* **Point-to-Multipoint による DMVPN ホストルート生成:**
  * Point-to-Multipoint ネットワークタイプを適用すると、OSPF は対向スポークへの **/32 ホストルート** を自動的に生成します。これにより、DMVPN Phase 3 等において Spoke-to-Spoke 間の直接 Tunnel 通信が実現されます。

### 2. Area Types の出題ポイントと落とし穴

* **NSSA エリアでデフォルトルートが消える事故 (重要!):**
  * **Standard Stub エリア:** ABR に `area <id> stub` を設定すると、**自動的に** Type-3 デフォルトルート (`0.0.0.0/0`) がエリア内に注入されます。
  * **NSSA エリア:** ABR に `area <id> nssa` を設定しただけでは、**デフォルトルートは自動注入されません!** 明示的に `area <id> nssa default-information-originate` を設定しなければ、NSSA 内部のルータは外部網への可達性を失います。
  * **Totally NSSA エリア:** ABR に `area <id> nssa no-summary` を設定すると、**例外的に自動で Type-3 デフォルトルートが注入** されます。この違いは CCIE 実技で最も狙われやすいポイントです。
* **NSSA Translator の明示的固定:**
  * 通常、Router ID が最大の ABR が Translator になりますが、要件で「特定の ABR を常に Translator として動作させよ」と指示された場合、`area <id> nssa translator role always` コマンドを設定します。

---

## 🛠 設定方法

### 1. OSPF Network Types 設定例

```bash
# 1. 物理/SVI インターフェイスを Point-to-Point 化
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ip ospf 1 area 0
 ip ospf network point-to-point
!
# 2. Loopback インターフェイスの物理マスク(/24)保持設定
interface Loopback0
 ip address 10.1.1.1 255.255.255.0
 ip ospf 1 area 0
 ip ospf network point-to-point
!
# 3. DMVPN / NBMA インターフェイスの Point-to-Multipoint 化
interface Tunnel0
 ip ospf network point-to-multipoint
!
# 4. NBMA (Non-Broadcast) 網での静的 Neighbor および Priority 制御
router ospf 1
 neighbor 10.1.12.2 priority 0
 neighbor 10.1.12.3 priority 0
```

---

### 2. OSPF Area Types 設定例 (OSPFv2 & OSPFv3)

```bash
# 1. Standard Stub Area (全 Stub ルータで投入)
router ospf 1
 area 1 stub
!
# 2. Totally Stubby Area (ABR で投入)
router ospf 1
 area 1 stub no-summary
!
# 3. NSSA Area ＋ デフォルトルート手動注入 (ABR で投入)
router ospf 1
 area 2 nssa default-information-originate
!
# 4. Totally NSSA Area (ABR で投入 - 自動デフォルトルート注入)
router ospf 1
 area 2 nssa no-summary
!
# 5. OSPFv3 Address Family における Totally NSSA 設定
router ospfv3 1
 address-family ipv6 unicast
  area 2 nssa no-summary
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスの OSPF Network Type、DR/BDR、タイマー確認** | <code>show ip ospf interface <int></code> / <code>show ospfv3 interface</code> |
| **エリアタイプ（Stub, NSSA 等）および ABR/ASBR フラグの確認** | <code>show ip ospf</code> / <code>show ospfv3</code> |
| **LSDB 内の LSA タイプ（Type-1〜7）別詳細データの確認** | <code>show ip ospf database</code> |
| **NSSA 特定 LSA（Type-7）および Type-5 変換状態の確認** | <code>show ip ospf database nssa-external</code> |
| **OSPF ネイバーアジャセンシー状態および Priority 確認** | <code>show ip ospf neighbor</code> |
| **OSPF パケットおよび LSA 送受信のリアルタイムデバッグ** | <code>debug ip ospf adj</code> / <code>debug ip ospf lsa-generation</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **OSPF ネイバーは `FULL` になるが、対向経由の IP ルートが RIB に掲載されない。** | 対向ルータ間で **Network Type の不一致** が発生している（例: 一方が `Broadcast`、他方が `Point-to-Point`）。 | `show ip ospf interface` | 両端のインターフェイスで `ip ospf network` コマンドのパラメーターを統一する。 |
| **NSSA エリア内部のルータへデフォルトルートが伝搬せず、外部通信が不通になる。** | NSSA ABR において `default-information-originate` の設定が漏れている。 | `show ip route ospf`<br>`show ip ospf database` | NSSA ABR で `area <id> nssa default-information-originate` を追加定義する（Totally NSSA の場合は `no-summary` を付与）。 |
| **Loopback の `/24` ネットワークが、対向ルータで `/32` として受信される。** | OSPF のデフォルト動作により Loopback インターフェイスが `/32` ホストルートとしてアドバタイズされている。 | `show ip route` | Loopback インターフェイス配下で `ip ospf network point-to-point` を設定する。 |
| **`area stub` または `area nssa` 設定後、ネイバーが即座に `DOWN`（Init / Down）になる。** | エリア内の全ルータで Stub / NSSA フラグ（E-bit / N-bit）が一致していない。 | `show ip ospf interface`<br>`show logging` | 該当エリアに接続されているすべてのルータでエリアタイプ設定コマンド（`area <id> stub/nssa`）を統一する。 |

---

## ⚠ 制限事項

1. **Area 0（Backbone Area）の Stub/NSSA 化不可:**
   * Area 0 を Stub エリアや NSSA エリアとして構成することはできません。Area 0 はすべての外部 LSA (Type-5) を保持・仲介する必要があります。
2. **Virtual-Link と Stub/NSSA エリアの競合制限:**
   * Virtual-Link（バーチャルリンク）のトランジットエリアとして Stub エリアや NSSA エリアを使用することはできません。トランジットエリアは Standard エリアである必要があります。

---

## 🔄 他技術との関連

* **DMVPN (Dynamic Multipoint VPN):**
  Phase 1/2/3 構成に応じて OSPF ネットワークタイプ（`point-to-multipoint` や `broadcast`）を選択します。特に Phase 3 では Spoke 間ダイレクト通信を可能にするため `point-to-multipoint` が最も推奨されます。
* **BGP (Border Gateway Protocol):**
  NSSA ASBR や Standard ASBR において、BGP 経路を OSPF へ再配送（`redistribute bgp`）する際、Type-5 または Type-7 LSA として生成されます。
* **L3VPN / VRF-Lite:**
  PE ルータ上で VRF 配下の OSPF プロセスを動かす際、`capability vrf-lite` を設定しないと DN-bit チェックにより LSA が破棄される場合があります。

---

## 🧩 比較表

### OSPF エリアタイプ（Area Types）機能比較表

| 比較項目 | Standard Area | Stub Area | Totally Stubby Area | NSSA | Totally NSSA |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Type-1, 2 (Intra-Area)** | 許可 | 許可 | 許可 | 許可 | 許可 |
| **Type-3 (Inter-Area)** | 許可 | 許可 | **ブロック** | 許可 | **ブロック** |
| **Type-4, 5 (External)** | 許可 | **ブロック** | **ブロック** | **ブロック** | **ブロック** |
| **Type-7 (NSSA External)** | 不可 | 不可 | 不可 | **許可** | **許可** |
| **ASBR の設置** | 可能 | **不可** | **不可** | **可能** | **可能** |
| **デフォルトルート注入** | 手動指定 | **自動** (Type-3) | **自動** (Type-3) | **手動指定が必要** | **自動** (Type-3) |

---

## 💡 ベストプラクティス

1. **Ethernet リンクの明示的 Point-to-Point 化:**
   1対1 の物理/論理 Ethernet リンクでは、全ポートで `ip ospf network point-to-point` を投入し、DR/BDR 選出処理および不要な LSA (Type-2) 生成を排除してコンバージエンスを高速化する。
2. **キャンパスエッジの Totally Stubby / Totally NSSA 化:**
   帯域やメモリが限定的なブランチルータが所属するエリアは、`no-summary` オプションを付与して Totally Stubby または Totally NSSA 化し、LSDB とルーティングテーブルサイズを最小化する。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Broadcast 網の Point-to-Point 化による DR/BDR 回避
* **要件:** R1 (Gi0/1) と R2 (Gi0/1) 間の VLAN 12 において、DR/BDR 選出をバイパスするよう構成せよ。

**【R1】**
```bash
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ip ospf 1 area 0
 ip ospf network point-to-point
```

**【R2】**
```bash
interface GigabitEthernet0/1
 ip address 10.1.12.2 255.255.255.0
 ip ospf 1 area 0
 ip ospf network point-to-point
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# 「Process 1, Nsp 1, Network Type POINT_TO_POINT, Cost: 1」が出力され、DR/BDR 表示が存在しないことを確認
```

---

### Scenario 2: Loopback インターフェイスの物理サブネット(/24)保持
* **要件:** R1 の Loopback0 (`10.1.1.1/24`) を OSPF でアドバタイズする際、/32 への自動変換を防ぎ /24 マスクを維持せよ。

**【R1】**
```bash
interface Loopback0
 ip address 10.1.1.1 255.255.255.0
 ip ospf 1 area 0
 ip ospf network point-to-point
```

**【検証方法】**
```bash
R2# show ip route 10.1.1.0
# 「Routing entry for 10.1.1.0/24」として正しく /24 で受信できていることを確認
```

---

### Scenario 3: DMVPN 網における Point-to-Multipoint 構成
* **要件:** R1 (Hub) および R2/R3 (Spoke) の Tunnel0 において、スポーク間ダイレクト通信用のホストルートが自動生成されるよう OSPF ネットワークタイプを設定せよ。

**【R1 (Hub) / R2 / R3 (Spoke)】**
```bash
interface Tunnel0
 ip ospf network point-to-multipoint
```

**【検証方法】**
```bash
R1# show ip route ospf
# R2 (10.1.123.2/32) および R3 (10.1.123.3/32) への /32 ホストルートが生成されていることを確認
```

---

### Scenario 4: Standard Stub Area 構成と Type-5 遮断検証
* **要件:** Area 1 を Stub エリア化し、外部経路（Type-5 LSA）をブロックせよ。

**【R1 (ABR) / R2 (Stub Router)】**
```bash
router ospf 1
 area 1 stub
```

**【検証方法】**
```bash
R2# show ip ospf database external
# Type-5 LSA が存在せず、`show ip route` で `O*IA 0.0.0.0/0` (デフォルトルート) が自動生成されていることを確認
```

---

### Scenario 5: Totally Stubby Area 構成 (`no-summary`)
* **要件:** Area 1 の ABR (R1) において、他エリア経路（Type-3 LSA）もすべて遮断するよう構成せよ。

**【R1 (ABR)】**
```bash
router ospf 1
 area 1 stub no-summary
```

**【R2 (エリア内ルータ)】**
```bash
router ospf 1
 area 1 stub
```

**【検証方法】**
```bash
R2# show ip route ospf
# Inter-Area 経路 (O IA) が消滅し、デフォルトルート `O*IA 0.0.0.0/0 via R1` のみが掲載されていることを確認
```

---

### Scenario 6: NSSA Area 構成とデフォルトルート手動注入
* **要件:** Area 2 を NSSA エリア化し、かつ ABR (R1) から NSSA 内部へデフォルトルートを明示的に注入せよ。

**【R1 (ABR)】**
```bash
router ospf 1
 area 2 nssa default-information-originate
```

**【R3 (NSSA 内ルータ)】**
```bash
router ospf 1
 area 2 nssa
```

**【検証方法】**
```bash
R3# show ip route ospf
# `O*N2 0.0.0.0/0` が生成されていることを確認
```

---

### Scenario 7: Totally NSSA Area 構成 (`no-summary`)
* **要件:** Area 2 の ABR (R1) において、Type-3 LSA を遮断し、自動的にデフォルトルートが注入されるよう設定せよ。

**【R1 (ABR)】**
```bash
router ospf 1
 area 2 nssa no-summary
```

**【R3 (NSSA 内ルータ)】**
```bash
router ospf 1
 area 2 nssa
```

**【検証方法】**
```bash
R3# show ip route ospf
# `O*IA 0.0.0.0/0` (Type-3 デフォルトルート) が自動的に掲載されていることを確認
```

---

### Scenario 8: NSSA Translator Role の明示的固定 (`always`)
* **要件:** 複数の ABR が存在する NSSA Area 2 において、R1 を常に Type-7 ➔ Type-5 変換担当ルータ（Translator）として固定せよ。

**【R1 (ABR)】**
```bash
router ospf 1
 area 2 nssa translator role always
```

**【検証方法】**
```bash
R1# show ip ospf database nssa-external
# 「Elections-always enabled」が出力され、常に Translator として動作していることを確認
```

---

### Scenario 9: Non-Broadcast (NBMA) 網における静的 Neighbor および DR 固定
* **要件:** R1 (Gi0/1) と R2 (Gi0/1) 間で NBMA ネットワークタイプを構成し、R1 を常に DR に固定せよ。

**【R1】**
```bash
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ip ospf 1 area 0
 ip ospf network non-broadcast
 ip ospf priority 255
!
router ospf 1
 neighbor 10.1.12.2
```

**【R2】**
```bash
interface GigabitEthernet0/1
 ip address 10.1.12.2 255.255.255.0
 ip ospf 1 area 0
 ip ospf network non-broadcast
 ip ospf priority 0
!
router ospf 1
 neighbor 10.1.12.1
```

**【検証方法】**
```bash
R1# show ip ospf neighbor
# R1 が DR、R2 が DROTHER (Priority 0) としてアジャセンシーが維持されていることを確認
```

---

### Scenario 10: OSPFv3 Address Family における NSSA 構成
* **要件:** OSPFv3 IPv6 アドレスファミリー配下で Area 3 を NSSA 化せよ。

**【R1 (ABR)】**
```bash
router ospfv3 1
 address-family ipv6 unicast
  area 3 nssa default-information-originate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ospfv3 1
# Area 3 が NSSA として正しく認識されていることを確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】Network Type 不一致による RIB 掲載不可障害
**問題:** 
R1 と R2 が直結されたインターフェイスにおいて、OSPF ネイバー状態は双方で `FULL/ -` および `FULL/DR` と正常に表示されています。しかし、R1 のルーティングテーブルに R2 配下のネットワークが一切追加されません。原因を突き止め、修正手順を説明してください。

**解答・解説:**
* **原因:** 
  R1 側のインターフェイスに `ip ospf network point-to-point` が設定されているのに対し、対向 R2 側がデフォルトの `Broadcast` ネットワークタイプのままになっています。OSPF では、ネットワークタイプが不一致であっても Hello/Dead タイマーが合致していればアジャセンシーは `FULL` に推移しますが、LSDB 上での Link-Type 記述ルールが異なるため、SPF 計算プロセスで不整合が発生し、RIB への経路掲載が自動的に拒否されます。
* **修正手順:** 
  R2 側の該当インターフェイス配下でも `ip ospf network point-to-point` を投入し、両端のネットワークタイプを完全一致させます。

---

### 2. 【コンフィグ読解・Design】NSSA エリアにおけるデフォルトルート非生成の解決
**問題:** 
以下のコンフィグを投入したルータ R1（ABR）に接続されている NSSA エリア内ルータ R2 において、外部宛てのトラフィックがルーティングループを起こしてドロップしています。原因と解決策を述べてください。
```text
router ospf 1
 router-id 1.1.1.1
 area 2 nssa
```

**解答・解説:**
* **原因:** 
  NSSA（Not-So-Stubby Area）では、通常の Stub エリアと異なり ABR で `area <id> nssa` を設定しただけではデフォルトルート（`0.0.0.0/0`）が自動生成・注入されません。そのため、R2 は外部網へのデフォルトルートを保持できず通信不能となります。
* **解決策:** 
  ABR (R1) の OSPF プロセス下で `area 2 nssa default-information-originate` を追加指定するか、もしくは Type-3 LSA も同時に遮断する `area 2 nssa no-summary`（Totally NSSA）に変更します。

---

## 🔗 参考リソース

* [Cisco Systems: OSPF Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/17-x/ti-ospf-17-x-book.html)
* [Cisco Command Reference: OSPF Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/command/iro-cr-book.html)
* [Cisco Live: BRKRST-2337 - OSPF Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **DR/BDR 選出の優先順位:**
  `ip ospf priority <0-255>` ➔ Priority が同じ場合は `Router-ID` の降順（数字が大きい方が優先）。
* **Area Type と LSA 関係マトリクス:**
  * Type-1 (Router LSA): 全エリア
  * Type-2 (Network LSA): Broadcast / NBMA 網の全エリア
  * Type-3 (Summary LSA): Standard, Stub, NSSA (Totally 除去)
  * Type-4 (ASBR Summary): Standard のみ
  * Type-5 (External): Standard のみ
  * Type-7 (NSSA External): NSSA, Totally NSSA のみ


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKRST-2337: OSPF Deployment in Modern Networks (OSPFv2/v3深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)
*   [BRKRST-3320: Troubleshooting Routing Protocols (OSPFの不整合トラブル等)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### Configurationガイド
*   [OSPFv2 Configuration Guide - Area Types (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html)
*   [OSPFv3 Address Family Support Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html)

### テクニカルドキュメント・設定例
*   [Understanding OSPF Network Types (Cisco Support)](https://www.cisco.com/c/ja_jp/support/docs/ip/open-shortest-path-first-ospf/13697-14.html)
*   [How OSPF Injects a Default Route into a Stub or NSSA (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/47870-ospfdb11.html)

---

## 📝 補足
- この学習メモは、OSPFの「ネットワークタイプ」によるパケット動作と、「エリアタイプ」によるデータベース制御の相関関係を網羅しています。CCIEラボ試験では、特に NSSA における Translator の動作や FA アドレスの到達性、そしてネットワークタイプの不一致を突くトラブルシューティングが合否を分けるポイントとなります。

