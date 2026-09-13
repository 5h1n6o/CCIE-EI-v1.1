---
layout: default
title: 1.4.d-Path-preference
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.4.d Path preference

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 routing プロトコルのコアアルゴリズムである **OSPF Path Preference（経路選定ルール・優先順位）** について、Cisco IOS-XE 17.x の実装基準に完全準拠して、学術的・実践的背景から詳細に解説します [22, 1.4.d]。

---

## 📘 概要

OSPF（Open Shortest Path First）における **Path Preference（経路優先順位）** とは、目的地に対して複数の経路（LSA）が存在する場合に、どの経路を最優先としてルータの **RIB（Routing Information Base）** および **FIB（Forwarding Information Base）** に掲載するかを決定する厳格な判定アルゴリズムです [22, 1.4.d]。

OSPF はメトリック（コスト: `Cost = 100Mbps / Bandwidth`）による最小コスト計算を基本としますが、**「異なる経路タイプ（LSA Type）間では、どれだけメトリックの数値が大きくても経路タイプ自身の階層順位（Path Preference）が絶対優先される」** という決定的な特徴を持ちます [22, 1.4.d; 120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

### 主な利用目的と適用シーン
1. **マルチエリア・マルチ出口網における確定的なトラフィック誘導:** キャンパス網やデータセンター接続において、エリア内経路（Intra-Area）をバックボーン経由（Inter-Area）より強制的に優先し、ルーティングループや非効率な非最適パス（Sub-optimal Routing）を防ぐ [22, 1.4.d]。
2. **外部非接続拠点・マルチ ASBR での最適アグリーゲート:** 外部ドメイン（BGP/EIGRP等からの再配送経路）を E1 (External Type 1) または E2 (External Type 2) として導入し、内部メトリック加算の有無によって最適出口を動的に選定する [22, 1.2.h, 1.4.d]。
3. **NSSA / BGP 相互接続時の精密パスコントロール:** RFC 1583 と RFC 2328 / RFC 3101 の動作差異（`no compatibility rfc1583`）や Forwarding Address (FA) 解消ロジックを利用して、マルチホーム接続での非対称ルーティングを解消する [22, 1.4.c, 1.4.d]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **絶対的優先順位（4段階）** | **① エリア内経路 (Intra-Area: `O`)** <br> **② エリア間経路 (Inter-Area: `O IA`)** <br> **③ 外部 Type 1 経路 (External Type 1: `O E1` / `O N1`)** <br> **④ 外部 Type 2 経路 (External Type 2: `O E2` / `O N2`)** |
| **メトリック比較の原則** | 異種経路タイプ間（例: `O` と `O IA`）では、コスト数値の比較は一切行われず、常に上位タイプが勝利する [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **E1 / N1 のコスト計算** | **`Total Cost = 内部コスト (自機〜ASBR/FA) + 外部指定コスト`** （全経路の動的加算） |
| **E2 / N2 のコスト計算** | **`Primary Metric = 外部指定コスト (固定)`**。外部コスト同値時のみ、**`Secondary Metric = 内部コスト (自機〜ASBR/FA)`** を比較 [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **Forwarding Address (FA)** | LSA Type 5/7 内の FA が `0.0.0.0` 以外の場合、コスト計算は ASBR ではなく **FA への IP アドレス宛（O / O IA）** に適用される。FA が O/O IA で解決できない場合、その外部ルートは不活性化（RIB 非掲載）となる。 |
| **RFC 1583 互換性** | デフォルトでは RFC 1583 互換（`compatibility rfc1583`）。`no compatibility rfc1583` 設定により、ASBR へのパス選定で非バックボーンエリアを無条件優先する動作を排除し、ルーティングループを防止する。 |

---

## 🏗 動作原理

OSPF パス選定アルゴリズムのフローチャートおよび決定ロジックを以下に示します [22, 1.4.d]。

```text
               [ 目的地への同一プレフィックス受信 ]
                               │
                               ▼
               ┌───────────────────────────────┐
               │  経路タイプ (LSA Class) 比較  │
               └───────────────┬───────────────┘
                               │
       ┌───────────────────────┼───────────────────────┐
       ▼                       ▼                       ▼
[ 1. Intra-Area (O) ]   [ 2. Inter-Area (O IA) ] [ 3/4. External (E1/N1/E2/N2) ]
 (Type-1/2 LSA)          (Type-3 Summary LSA)     (Type-5/7 AS-External LSA)
       │                       │                       │
       │                       │                       ├─► [ E1 vs E2 ] ➔ E1 が無条件勝利
       │                       │                       │
       │                       │                       ├─► [ E1 / N1 同士 ]
       │                       │                       │    ➔ Total Cost (内部 + 外部) の最小
       │                       │                       │
       │                       │                       └─► [ E2 / N2 同士 ]
       │                       │                            ➔ 1st: 外部コスト最小
       │                       │                            ➔ 2nd: 内部コスト (ASBR/FA宛) 最小
       │                       │
       ▼                       ▼                       ▼
  [ コスト最小 ]          [ コスト最小 ]          [ 最小コストのパス選定 ]
       │                       │                       │
       └───────────────────────┴───────────────────────┘
                               │
                               ▼
                  [ RIB / FIB へ単一/ECMP 掲載 ]
```

### 1. 経路タイプ優先度（Path Type Order）の深掘り

どんなに高速な帯域幅であっても、以下の上位タイプが存在する場合、下位タイプは RIB から破棄されます [22, 1.4.d; 120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

1. **Intra-Area Routes (O):**
   * 同一エリア内の Router LSA (Type-1) および Network LSA (Type-2) から計算される経路。
   * **例:** Area 1 内のバックアップリンク（コスト 1000）の `O` 経路は、Area 0 経由（コスト 2）の `O IA` 経路よりも**常に絶対優先**されます。
2. **Inter-Area Routes (O IA):**
   * 他エリアから ABR（Area Border Router）を介して Summary LSA (Type-3) としてアドバタイズされる経路 [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。
3. **External Type 1 (O E1 / O N1):**
   * ASBR（Autonomous System Boundary Router）によって導入される外部再配送経路。
   * パケットが転送される過程で、通過する各内部リンクのコストが動的に加算されます。
4. **External Type 2 (O E2 / O N2):**
   * 再配送時のデフォルトの外部タイプ。
   * ネットワークを通過しても、ヘッダーに記載された「外部コスト（デフォルト: 20）」自体は不変（固定）です [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

---

## ⚙ 動作シーケンス

1. **LSDB データベースの走査と計算起動:**
   * トポロジー変更や LSA 受信に伴い、SPF（Shortest Path First: Dijkstra）アルゴリズムが起動します。
2. **Intra-Area (Type-1/2) 経路の計算:**
   * 自機が所属する各エリア内で Type-1 / Type-2 LSA を走査し、ツリー構造を構築して Intra-Area 経路を算出・登録します。
3. **Inter-Area (Type-3) 経路の計算:**
   * 各 ABR から受信した Type-3 Summary LSA を評価します。自機から ABR までの最少コスト（Intra-Area コスト）と Type-3 内のコストを合算し、最少コストの Inter-Area 経路を決定します [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。
   * **注意:** 同一プレフィックスで `O`（Intra-Area）が既に存在する場合、`O IA` は計算対象外として即座に不採用となります。
4. **External (Type-5/7) 経路の計算:**
   * **Forwarding Address (FA) の確認:** LSA 内の FA フィールドをチェックします。
     * `FA == 0.0.0.0`: 送信元 ASBR（Type-4 LSA または Type-1 LSA）への内部距離を特定。
     * `FA != 0.0.0.0`: FA アドレス自体への内部距離を OSPF RIB（O または O IA）で検索。
   * **Type 1 (E1/N1) の決定:** `内部コスト + 外部コスト` のトータル最小値を選定。
   * **Type 2 (E2/N2) の決定:**
     1. 最も低い外部コストを持つ LSA を選択。
     2. 外部コストが同値の場合、内部コスト（自機〜ASBR/FA）が最も低い LSA を選択。
     3. 内部コストも同値の場合は、ECMP（Equal-Cost Multi-Path）を形成（`maximum-paths` 制限内）。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、OSPF Path Preference は複雑なトポロジーにおける「意図しないトラフィック迂回（Sub-optimal Routing）」や「非対称ルーティング」の根本原因として出題されます [22, 1.4.d]。

### 1. 「Intra-Area vs Inter-Area」の絶対ルールと落とし穴
* **試験シナリオ:**
  「R1 から R3 への通信において、Area 0 経由の高速リンク（10Gbps、コスト 2）ではなく、Area 1 経由の低速リンク（1Gbps、コスト 10）を経由している。コンフィグを分析し、理由を明記した上で Area 0 経由に変更せよ」という問題。
* **原因識別:**
  R3 のプレフィックスが R1 において Area 1 内の `O` (Intra-Area) として学習されている場合、Area 0 から届く `O IA` (Inter-Area) はコストに関係なく絶対に選ばれません！
* **対策・修正:**
  エリア境界の再設計、またはエリア構成の変更により、優先したいパスを Intra-Area 化するか、不必要な Intra-Area LSA を抑制します。

### 2. E1 vs E2 の使い分けとマルチ ASBR 設計
* **E2 (External Type 2) のトラップ:**
  E2 は外部コストが固定（例: 20）であるため、複数の ASBR から同じコストで再配送されると、ルータは内部コストのみで比較します。しかし、途中の ABR 集約やエリア構造によっては、直感と異なる ASBR が選ばれる事故が発生します。
* **E1 (External Type 1) への変更指示:**
  試験問題で「内部ネットワークの帯域・遅延の変化を反映して、最も近い最適出口から外部ネットワークへ抜けるように設定せよ」と指定された場合、再配送時に `metric-type 1` を指定するか、Route-Map で `set metric-type type-1` をバインドします [22, 1.2.h, 1.4.d]。

### 3. Forwarding Address (FA) と NSSA の落とし穴
* **NSSA ABR での Type-7 ➔ Type-5 変換:**
  NSSA ABR が Type-7 LSA を Type-5 LSA に変換する際、FA に NSSA エリア内の Loopback アドレス等が設定されます。
* **FA 非疎通によるルート不活性化:**
  対向エリアのルータが、その FA アドレスへの Inter-Area/Intra-Area 経路を持っていない場合、外部ルート全体が RIB に掲載されなくなります（`show ip ospf border-routers` や `show ip ospf database external` で確認可能）。

### 4. `no compatibility rfc1583` の設定要求
* RFC 1583 では、外部ルート計算時に ASBR への内部パスとして非バックボーンエリアを優先する挙動があり、ループを引き起こす可能性があります。
* 試験で「RFC 2328 に準拠した安全な外部パス計算を行わせよ」と指定された場合は、グローバル OSPF プロセス下で `no compatibility rfc1583` を投入します。

---

## 🛠 設定方法

### 1. OSPFv2 / OSPFv3 での Path Preference 調整コンフィグ

```bash
# 1. OSPFv2 での E1 (External Type 1) 再配送および RFC 2328 準拠設定
router ospf 1
 router-id 1.1.1.1
 no compatibility rfc1583
 redistribute static subnets metric-type 1 metric 50
 redistribute eigrp 100 subnets metric-type 1 metric 100
```

```bash
# 2. Route-Map による精密な Metric-Type & Cost 変更
route-map PREFER_E1 permit 10
 match ip address prefix-list PL_EXTERNAL_NET
 set metric-type type-1
 set metric 20
!
router ospf 1
 redistribute bgp 65001 subnets route-map PREFER_E1
```

```bash
# 3. OSPFv3 Address Family での E1 再配送設定
router ospfv3 1
 !
 address-family ipv4 unicast
  redistribute static metric-type 1 metric 10
 exit-address-family
 !
 address-family ipv6 unicast
  redistribute static metric-type 1 metric 10
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **RIB 内の OSPF 経路タイプ（O, O IA, O E1, O E2）およびメトリック確認** | <code>show ip route ospf</code> / <code>show ipv6 route ospf</code> |
| **OSPF プロセスレベルでの RFC1583 互換性、ボーダールータ設定の確認** | <code>show ip protocols</code> / <code>show ip ospf</code> |
| **ASBR および ABR への内部コスト（Border Router Table）の特定** | <code>show ip ospf border-routers</code> |
| **特定外部 LSA の Forwarding Address (FA) および Adv Router の監査** | <code>show ip ospf database external <prefix></code> |
| **NSSA 外部 LSA (Type-7) の P-bit および FA アドレス確認** | <code>show ip ospf database nssa-external <prefix></code> |
| **SPF パス計算イベントのリアルタイムデバッグ** | <code>debug ip ospf spf</code> / <code>debug ip ospf rib</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **低速リンク（Area 1 経由）が選ばれ、高速リンク（Area 0 経由）が無視される。** | 該当プレフィックスが低速リンク側で `O` (Intra-Area)、高速リンク側で `O IA` (Inter-Area) としてアドバタイズされている。 | `show ip route <prefix>` | 優先したいパス側のエリア設計を修正し、`O` 経路化するか、低速側のエリアを分割して `O IA` 同士のコスト比較にする [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **再配送した外部ルートが対向ルータの RIB に掲載されない。** | Type-5/7 LSA 内の Forwarding Address (FA) への Intra/Inter-Area 経路が対向ルータに存在しない。 | `show ip ospf database external`<br>`show ip route <FA-IP>` | FA アドレス（Loopback等）を OSPF `network` コマンドで内部アドバタイズするか、`area <id> nssa suppress-fa` で FA を `0.0.0.0` に強制変更する。 |
| **E2 ルートにおいて、遠列の ASBR 経由のパスが選ばれてしまう。** | 外部コスト（External Metric）が片側で低く設定されているため、内部コスト比較に到達していない。 | `show ip ospf database external` | 両 ASBR でアドバタイズする外部コストを同値にするか、`metric-type 1` (E1) に変更してトータルコスト計算を行わせる [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **マルチエリア構成でルーティングループが発生する。** | RFC 1583 互換動作により、非バックボーンエリア経由の ASBR パスが最優先選定されている。 | `show ip protocols` | グローバル OSPF プロセス下で `no compatibility rfc1583` を設定する。 |

---

## ⚠ 制限事項

1. **Path Preference の順序変更不可:**
   * BGP のように Local Preference や Weight、Route-Map で Path Type の優先順位（`O > O IA > E1 > E2`）自体を逆転させることは不可能です。
2. **Forwarding Address (FA) 解決の絶対条件:**
   * FA アドレスへの解像は、必ず **OSPF 内部経路（Intra-Area または Inter-Area）** で行われる必要があります。Static ルートや BGP 経由で FA アドレスを知っていても、OSPF 外部ルートは活性化されません。

---

## 🔄 他技術との関連

* **BGP (Border Gateway Protocol):**
  BGP 経路を OSPF へ再配送する際、デフォルトでは E2 (Cost 20) となります。データセンターの複数 Egress ルータ経由で BGP 宛トラフィックを最適分散させる場合、E1 変更や Route-Map での Metric 注入が必須となります [22, 1.2.h, 1.5.b]。
* **VRF-Lite / MP-BGP L3VPN:**
  PE-CE ルーティングに OSPF を使用する場合、DN Bit や Domain Tag、Down Bit のチェックにより Loop 防止機能が働きますが、これは Path Preference と連携して別エリア扱い（Inter-Area）として伝搬されるケースがあります [22, 1.2.d, 1.2.e]。

---

## 🧩 比較表

### OSPF Path Preference 判定マトリクス

| 評価順位 | 経路タイプ記号 | LSA タイプ | コスト計算方式 | 特徴・選定ルール |
| :--- | :--- | :--- | :--- | :--- |
| **1位** | **`O`** (Intra-Area) | Type-1 (Router)<br>Type-2 (Network) | 内部リンクコストの累積和 | コスト数値に関わらず最優先。同一エリア内通信 [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **2位** | **`O IA`** (Inter-Area) | Type-3 (Summary) | ABR までのコスト ＋ Summary 内コスト | 他エリアからの経路。同値時は最小コストの ABR 経由を選択 [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **3位** | **`O E1` / `O N1`** | Type-5 (External)<br>Type-7 (NSSA) | 自機〜ASBR/FA の内部コスト ＋ 外部コスト | 動的なトータルコスト変化を反映。近接 ASBR を自動選択 [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |
| **4位** | **`O E2` / `O N2`** | Type-5 (External)<br>Type-7 (NSSA) | 1st: 外部コスト<br>2nd: 自機〜ASBR/FA 内部コスト | デフォルト再配送タイプ。外部コスト固定。二次比較で内部コスト評価 [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。 |

---

## 💡 ベストプラクティス

1. **大規模網での E1 (External Type 1) 採用:**
   マルチ ASBR 構成では、再配送時に `metric-type 1` を指定し、内部ネットワークの遅延・帯域変化に応じた最寄りの出口（Hot-Potato Routing）を選択させる [22, 1.2.h, 1.4.d]。
2. **`no compatibility rfc1583` の標準投入:**
   すべての OSPF ルータで `no compatibility rfc1583` を設定し、RFC 2328 準拠の安全な外部パス計算を行わせる。
3. **NSSA での `suppress-fa` の検討:**
   NSSA ABR において不要な FA トラブルを避けるため、`area <id> nssa suppress-fa` を投入して FA を `0.0.0.0` にクリアし、シンプルな ABR 宛内部コスト計算にフォールバックさせる [22, 1.4.c, 1.4.d]。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Intra-Area (O) vs Inter-Area (O IA) 優先順位の検証
* **要件:** R1 から 10.3.3.3/32 への経路において、Area 0 経由（コスト 2）ではなく Area 1 経由（コスト 100）が優先される理由を解明し、コンフィグで確認せよ [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

**【R1 / R3】**
```bash
# R1 において 10.3.3.3/32 が Area 1 に直接バインドされている場合
router ospf 1
 router-id 1.1.1.1
 area 1 network 10.1.13.0 0.0.0.255
```

**【検証方法】**
```bash
R1# show ip route 10.3.3.3
# 「Routing Known via "ospf 1", distance 110, metric 100, type intra area」と表示され、
# Area 0 経由の IA 経路が存在しても Intra-Area が無条件選択されていることを確認
```

---

### Scenario 2: E1 (External Type 1) による Hot-Potato Routing
* **要件:** R1 で Static 経路 `172.16.0.0/16` を OSPF に再配送する際、内部コストを追播する Type-1 としてアドバタイズせよ [22, 1.2.h, 1.4.d]。

**【R1】**
```bash
ip route 172.16.0.0 255.255.0.0 Null0
!
router ospf 1
 redistribute static subnets metric-type 1 metric 20
```

**【検証方法】**
```bash
R2# show ip route 172.16.0.0
# 「Known via "ospf 1", metric 30 (20 + R2-R1間コスト10), type external 1」を確認
```

---

### Scenario 3: Route-Map を用いた選択的 E1 / E2 変更
* **要件:** Prefix-List `PL_E1` にマッチする経路は E1 (Metric 10)、それ以外は E2 (Metric 50) として再配送せよ [22, 1.2.g, 1.2.h, 1.4.d]。

**【R1】**
```bash
ip prefix-list PL_E1 permit 192.168.10.0/24
!
route-map BGP_TO_OSPF permit 10
 match ip address prefix-list PL_E1
 set metric-type type-1
 set metric 10
!
route-map BGP_TO_OSPF permit 20
 set metric-type type-2
 set metric 50
!
router ospf 1
 redistribute bgp 65001 subnets route-map BGP_TO_OSPF
```

**【検証方法】**
```bash
R2# show ip route 192.168.10.0
# E1 (type 1) として受講されていることを確認
```

---

### Scenario 4: E2 外部コスト同一時の Secondary Metric (内部コスト) 選定検証
* **要件:** R1 と R2 の双方が `10.99.0.0/16` を E2 (Metric 20) でアドバタイズしている環境で、R4 が内部コストの近い ASBR を自動選択することを確認せよ [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

**【R1 / R2】**
```bash
# R1 (内部コスト 10) / R2 (内部コスト 50)
router ospf 1
 redistribute static subnets metric-type 2 metric 20
```

**【検証方法】**
```bash
R4# show ip route 10.99.0.0
# メトリック 20 (E2) でありながら、ネクストホップが内部コストの低い R1 側を向いていることを確認
```

---

### Scenario 5: `no compatibility rfc1583` による RFC 2328 適合化
* **要件:** ルータ R1 において、RFC 1583 互換計算を無効化し、RFC 2328 規格に適合させよ。

**【R1】**
```bash
router ospf 1
 no compatibility rfc1583
```

**【検証方法】**
```bash
R1# show ip protocols | include RFC1583
# 「It is NOT compatible with RFC1583」が出力されることを確認
```

---

### Scenario 6: Forwarding Address (FA) 非疎通トラブルの再現と修正
* **要件:** NSSA エリアで生成された Type-7 LSA の FA アドレス（`10.1.99.1`）が非 NSSA ルータで非疎通のため外部ルートが消えた問題を修復せよ [22, 1.4.c, 1.4.d]。

**【R1 (NSSA ABR) 修正】**
```bash
router ospf 1
 area 1 nssa suppress-fa
```

**【検証方法】**
```bash
R3# show ip ospf database external 10.99.0.0
# Forward Address が 0.0.0.0 に変更され、ルートが RIB に復活したことを確認
```

---

### Scenario 7: OSPFv3 Address Family での Path Preference 調整
* **要件:** OSPFv3 IPv6 AF において、Static デフォルトルートを E1 として再配送せよ [22, 1.4.b, 1.4.d]。

**【R1】**
```bash
ipv6 route ::/0 Null0
!
router ospfv3 1
 address-family ipv6 unicast
  redistribute static metric-type 1 metric 100
 exit-address-family
```

**【検証方法】**
```bash
R2# show ipv6 route ::/0
# 「O E1 ::/0 [110/110]」と表示されることを確認
```

---

### Scenario 8: NSSA Type-7 (N1/N2) vs External Type-5 (E1/E2) の比較検証
* **要件:** 同一プレフィックスが Type-7 (N2) と Type-5 (E2) で同じコストで到達した場合、RFC 3101 に従い Type-7 が優先されることを確認せよ [22, 1.4.c, 1.4.d]。

**【検証コマンド】**
```bash
R1# show ip ospf database
# Type-7 (NSSA) 由来の経路が選択されていることを show ip route で確認
```

---

### Scenario 9: Border Router Table (`show ip ospf border-routers`) による ASBR コスト監査
* **要件:** ASBR `2.2.2.2` への内部パスコストおよび到達エリアを確認せよ。

**【実行コマンド】**
```bash
R1# show ip ospf border-routers
```

---

### Scenario 10: VRF 構造における OSPF Path Preference
* **要件:** VRF `TENANT_A` 内の OSPF プロセスにおいて、E1 再配送をバインドせよ [22, 1.2.e, 1.4.d]。

**【R1】**
```bash
router ospf 100 vrf TENANT_A
 redistribute static subnets metric-type 1 metric 15
```

**【検証方法】**
```bash
R1# show ip route vrf TENANT_A ospf
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解・トラブルシューティング】Intra-Area 優先による非最適パス問題
**問題:** 
以下のトポロジーにおいて、R1 から R4 への通信が、帯域幅 10Gbps の Area 0 リンク（R1-R2-R4）ではなく、帯域幅 100Mbps の Area 1 リンク（R1-R3-R4）を経由しています。
* R1# `show ip route 10.4.4.4` の出力:
  `Routing Known via "ospf 1", distance 110, metric 156, type intra area`
  `Routing Descriptor Blocks: via 10.1.13.3, GigabitEthernet0/1`

Area 0 経由のルートが存在するにもかかわらず、なぜ 100Mbps の Area 1 経由が選ばれているのでしょうか？技術的理由を説明し、最少コストの Area 0 経由へ変更するための修正案を述べてください [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

**解答・解説:**
* **技術的理由:** 
  OSPF の Path Preference アルゴリズムでは、**Intra-Area (`O`) 経路は Inter-Area (`O IA`) 経路に対して絶対的に優先** されます [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。R4 の 10.4.4.4/32 が R1 において Area 1 の Type-1/2 LSA から直接計算された `O` 経路であるため、Area 0 の ABR からアドバタイズされる Type-3 Summary LSA (`O IA`) は、どれだけコストが小さくても無視されます。
* **修正案:** 
  R4 上で 10.4.4.4/32 が属するインターフェイスのエリアバインドを Area 1 から Area 0 へ変更するか、エリア境界を変更して Area 0 側でも `O` 経路として認識させます。

---

### 2. 【Design / 実装】E1 と E2 再配送の設計評価
**問題:** 
マルチホーム接続された 2 台の ASBR（R1, R2）から、外部ネットワーク `192.168.0.0/16` が OSPF ドメインへアドバタイズされています。
* 要求要件: 内部ルータ群は、ネットワーク全体のトポロジー遅延（自機から各 ASBR までの物理コスト）を考慮し、最も近い ASBR から外部へ抜ける「Hot-Potato Routing」を行わなければならない。
* 現状: 内部ルータ R5 から見ると、物理的に遠い R2 側の ASBR 経由が選定されている。

現状のコンフィグ（デフォルトの `redistribute`）の何が問題であり、どう修正すべきか答えてください [22, 1.2.h, 1.4.d; 120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

**解答・解説:**
* **問題点:** 
  デフォルトの再配送では **E2 (External Type 2)** が適用され、外部コスト（デフォルト: 20）がドメイン内で固定されます [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。外部コストに差がない場合、内部コストのみで比較されますが、集約や固定設定により不最適な ASBR が選ばれるか、内部コストが正しく反映されません。
* **修正方法:** 
  R1 および R2 での再配送設定において、`metric-type 1` (E1) を指定します。E1 に変更することで、**`Total Cost = 内部コスト + 外部コスト`** となり、各内部ルータから最も近い ASBR へのパスが動的に計算・選播されます [120, Video Title: OSPF Inter-Area Operations, Area Types, and External Routes]。

---

## 🔗 参考リソース

* [Cisco Systems: OSPF Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-3s/iro-xe-3s-book.html)
* [Cisco Command Reference: OSPF Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/command/iro-cr-book.html)
* [Cisco Live: BRKRST-2337 - Advanced OSPF Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **OSPF Path Preference 暗記用要約:**
  `Intra-Area (O)` > `Inter-Area (O IA)` > `External 1 (E1/N1)` > `External 2 (E2/N2)`
  ※コスト比較は同種タイプ内でのみ有効！


## 参考リソースリンク

### Configurationガイド
*   [OSPFv2 Path Selection Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html)。
*   [OSPFv3 Address Family Support Configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html)。

### CiscoLive (動画・スライド)
*   [BRKRST-2337: OSPF Deployment in Modern Networks](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)。
*   [BRKCCIE-3000: OSPF for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html)。

### テクニカルドキュメント・設定例
*   [OSPF Cost Calculation and Reference Bandwidth](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/7039-1.html#anc18)。
*   [Understanding OSPF External Route Path Selection (E1 vs E2)](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13692-21.html)。

---

## 📝 補足
- この学習メモは、OSPF のパス選定における「論理的な優先順位」と「数学的なコスト計算」の二段階評価を詳細に解説しています。CCIE ラボ試験では、特に **「Intra-area 優先ルール」** がコストを上回る点を利用した問題が多いため、実機での LSA タイプ確認（`show ip ospf database`）を習慣化することが合格への最短ルートです。


