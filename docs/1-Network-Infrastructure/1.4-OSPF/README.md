---
layout: default
title: 1.4-OSPF
parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.4 OSPF (v2 and v3)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における中核 IGP である **OSPF (Open Shortest Path First) v2 および v3** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**OSPF (Open Shortest Path First)** は、IETF によって標準化された Dijkstra の **SPF (Shortest Path First) アルゴリズム** に基づくリンクステート型ダイナミックルーティングプロトコルです。ネットワーク全体のトポロジー情報を **LSA (Link State Advertisement)** として全ルータ間で同期し、各ルータがローカルで **LSDB (Link State Database)** を構築した上で、自身を頂点とする最短パスツリー（SPT）を計算してルーティングテーブル（RIB）を自動生成します。

### 適用プロトコルバージョン
1. **OSPFv2 (RFC 2328):** IPv4 専用のリンクステートプロトコル。サブネット単位（IPv4 ネットワーク）でアジャセンシーおよび LSA の伝搬を制御。
2. **OSPFv3 (RFC 5340 / RFC 5838):** IPv6 対応およびマルチアドレスファミリー（Address Family）サポートプロトコル。リンク単位（Link-Local アドレス依存）で動作し、単一の OSPFv3 プロセス内で IPv4 と IPv6 の両アドレスファミリーを統合管理可能。

### 主な利用目的と適用シーン
1. **大規模エンタープライズ・キャンパス網のアンダーレイルーティング:** 階層型エリア設計（バックボーンエリア 0 を中心とするスター型トポロジー）により、LSDB の規模や SPF 計算の範囲を局所化し、数千台規模のネットワークを安定運用する。
2. **Cisco SD-Access (SDA) / SD-WAN アンダーレイ基盤:** ファブリックノード間（Control Plane / Border / Edge）の IP 物理到達性を超高速に確保する信頼性の高い IGP として利用。
3. **データセンターおよびマルチテナント環境 (VRF-Lite):** VRF ごとに独立した OSPF プロセス/LSDB を保持し、完全に分離された L3 セグメンテーションを提供する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | リンクステート型プロトコル。Dijkstra SPF アルゴリズムを使用。エリア（Area）概念による階層型トポロジー制御。IP プロトコル番号 89 で動作。 |
| **用途** | エンタープライズ内部網（Campus Core/Distribution/Access）、データセンター、SD-Access アンダーレイ、MPLS L3VPN PE-CE ルーティング。 |
| **メリット** | ① ルーティングループが理論上発生しない（エリア内）。<br>② ネットワーク変更時のコンバージエンス速度が極めて高速。<br>③ 階層型エリア設計により大規模網でのスケーラビリティに優れる。<br>④ マルチベンダー互換性が高い（IETF 標準規格）。 |
| **デメリット** | ① トポロジー全体（LSDB）をメモリ上に保持するため、ルータの CPU / メモリ消費量が大きい。<br>② 設計が不適切（エリア分けの不備や非星型バックボーン構成）だと LSA ストームや非最適なルーティングが発生する。 |
| **対応機種** | Cisco Catalyst 9000 シリーズ、Catalyst 8000v、ASR1000 シリーズ、ISR4000 シリーズなど、Cisco IOS-XE 搭載全全プラットフォーム。 |
| **制限事項** | 全ての非バックボーンエリア（Non-Zero Area）は、直接（または Virtual-Link / GRE 経由で）エリア 0（Backbone Area）に接続しなければならない。 |
| **設計上の注意点** | ① デフォルトの Reference Bandwidth (`100Mbps`) では 1Gbps / 10Gbps / 100Gbps リンクのコストがすべて `1` に飽和するため、`auto-cost reference-bandwidth 10000` 等の設定が必須。<br>② 共有イーサネット網での DR/BDR 選出ルールと Priority 設計に留意する。 |

---

## 🏗 動作原理

OSPF はリンクステートデータベース（LSDB）をドメイン内の全ルータで完全に同一の状態に同期（Flood）させることで動作します。

```text
[ Router A ]                                       [ Router B ]
     │                                                  │
     │─── 1. Hello Packet (224.0.0.5) ─────────────────►│ (Init State)
     │◄── 2. Hello Packet (224.0.0.5 with Neighbor ID) ─│ (2-Way State)
     │                                                  │
     │─── 3. DBD Packet (Master/Slave Negotiation) ────►│ (ExStart State)
     │◄── 4. DBD Packet (Master/Slave Settled) ─────────│ (Exchange State)
     │                                                  │
     │─── 5. DBD Packet (LSDB Summary Exchange) ───────►│
     │◄── 6. LSR (Link State Request) ──────────────────│ (Loading State)
     │                                                  │
     │─── 7. LSU (Link State Update: LSA Packets) ─────►│
     │◄── 8. LSAck (Link State Acknowledgment) ─────────│
     │                                                  │
     │==================================================│
     │               [ Full State - LSDB Synced ]       │
     │==================================================│
     │                                                  │
     │─── 9. Run SPF Algorithm (Dijkstra) ──────────────│
     │─── 10. Install Best Paths into RIB/FIB ──────────│
```

### 主要 LSA タイプ（OSPFv2 vs OSPFv3）

| LSA Type | OSPFv2 LSA 名 | OSPFv3 LSA 名 | 生成ルータ | 説明・伝搬範囲 |
| :--- | :--- | :--- | :--- | :--- |
| **Type 1** | Router LSA | Router LSA | すべてのルータ | エリア内のみ伝搬。各ルータの直接接続リンクとコスト情報を格納。 |
| **Type 2** | Network LSA | Network LSA | DR (Designated Router) | エリア内のみ伝搬。マルチアクセス網上の接続ルータ一覧を格納。 |
| **Type 3** | Summary Network LSA | Inter-Area-Prefix LSA | ABR (Area Border Router) | エリア間（Inter-Area）伝搬。他エリアのプレフィックス情報を通知。 |
| **Type 4** | Summary ASBR LSA | Inter-Area-Router LSA | ABR | エリア間伝搬。ASBR (AS Boundary Router) への到達コストを通知。 |
| **Type 5** | AS External LSA | AS-External LSA | ASBR | ドメイン全体（Stubエリア除く）伝搬。他プロトコルから再配送された外部経路。 |
| **Type 7** | NSSA External LSA | NSSA LSA | NSSA ASBR | NSSA エリア内のみ伝搬。NSSA ABR で Type 5 に変換されて全体へ伝搬。 |
| **Type 8** | Link LSA (N/A) | Link LSA | すべてのルータ | リンクローカルスコープ（ローカルリンクのみ）。Link-Local アドレスと IPv6 プレフィックス一覧を通知。 |
| **Type 9** | Intra-Area-Prefix (N/A) | Intra-Area-Prefix LSA | すべてのルータ / DR | エリア内のみ伝搬。Router/Network LSA から IP プレフィックス情報を分離して格納。 |

---

## ⚙ 動作シーケンス

1. **Hello パケットの交換とネイバーアジャセンシー形成:**
   * ポート上で OSPF が有効化されると、マルチキャストアドレス `224.0.0.5`（AllSPFRouters）、OSPFv3 の場合は `FF02::5` 宛てに Hello パケットを送出します。
   * エリア ID、Hello/Dead タイマー、サブネット/マスク（v2）、Stub フラグ、認証（v2）が合致すると `2-Way` ステートに推移します。
2. **DR / BDR の選出 (Broadcast / Non-Broadcast ネットワーク):**
   * Priority（デフォルト `1`、`0` は選出辞退）が最も高いルータが DR、次点が BDR となります。同点の場合は Router ID（32ビット数値）が大きい方が勝利します。
3. **LSDB の同期 (ExStart ➔ Exchange ➔ Loading ➔ Full):**
   * `ExStart`: Router ID の大きい方が Master となり、Sequence Number を決定。
   * `Exchange`: LSDB の要約ヘッダー（DBD パケット）を交互に送信。
   * `Loading`: 不足している LSA の詳細を LSR (Request) で要求し、対向から LSU (Update) で受け取って LSAck で確認応答。
   * `Full`: 両ルータの LSDB が 100% 完全同期した状態。
4. **SPF 計算と RIB 掲載:**
   * 各ルータが同調した LSDB を基に Dijkstra アルゴリズムを実行し、自身を根とする木構造（SPT）を計算。最小コストのパスを IP ルーティングテーブル（RIB）および CEF 転送テーブル（FIB）へ挿入します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、OSPF は最も多角的に深掘りされる重要セクションの 1 つです。以下の Blueprint サブトピックごとの必須知識とトラップを完全把握してください。

### 1.4.a Adjacencies（アジャセンシー不成立の 8 大要因）
試験で「ネイバーが確立しない原因を突き止め修正せよ」という課題が出た場合、以下を即座にチェックします。
1. **Area ID の不一致:** インターフェイスが属するエリア番号のズレ。
2. **Hello / Dead Timer の不一致:** デフォルト（P2P/Broadcast: 10s/40s, P2MP/NBMA: 30s/120s）からの不整合。
3. **Subnet Mask の不一致 (OSPFv2):** 共有イーサネット網でマスク（例: `/24` vs `/25`）が異なる場合。
4. **Stub/NSSA Area Flag のミスマッチ:** 一方のみが `area 1 stub` または `area 1 nssa` になっている。
5. **Authentication のパラメータ不一致:** Key-Chain、MD5/SHA パスワードのミス。
6. **L3 MTU の不一致:** DBD パケット交換時（`ExStart` / `Exchange` ステート）で永久ハングが発生。`ip ospf mtu-ignore` でバイパス可能。
7. **Duplicate Router ID (ルータ ID の重複):** 同一エリア内で Router ID が重複すると、アジャセンシーがフラッピングするか、LSA が破棄されます。
8. **Passive-Interface の誤バインド:** Hello 送受信が遮断される。

### 1.4.b OSPFv3 address family support（Address Family サポート）
* **要点:** 従来 IPv6 専用だった OSPFv3 プロトコル（`ipv6 router ospf`）を拡張し、単一の OSPFv3 プロセス（`router ospfv3 <process-id>`）内で **IPv4 Unicast** および **IPv6 Unicast** の両アドレスファミリーを統合管理するモダンな構造です。
* **CCIE 試験での実装ポイント:**
  ```bash
  router ospfv3 1
   router-id 1.1.1.1
   address-family ipv4 unicast
   exit-address-family
   address-family ipv6 unicast
   exit-address-family
  !
  interface GigabitEthernet0/1
   ospfv3 1 ipv4 area 0
   ospfv3 1 ipv6 area 0
  ```
  ※ OSPFv3 で IPv4 アドレスファミリーを動作させる場合でも、**インターフェイス上に IPv6（少なくとも Link-Local アドレス）が有効化されている必要があります。**

### 1.4.c Network types, area types
* **Network Types の決定的な違い:**

| Network Type | DR/BDR選出 | デフォルトタイマー (Hello/Dead) | 隣接関係の宛先 | 特徴・用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Broadcast** | 選出する | 10s / 40s | `224.0.0.5` / `224.0.0.6` | イーサネット標準。全ルータが DR/BDR を介してメッシュ同期。 |
| **Point-to-Point** | 選出しない | 10s / 40s | `224.0.0.5` | 2 台間直結リンク。DR/BDR 選出のオーバーヘッドなし。 |
| **Point-to-Multipoint** | 選出しない | 30s / 120s | `224.0.0.5` | DMVPN や Hub-Spoke 網用。各対向を個別の P2P リンクとして扱い、/32 ルートを自動生成。 |
| **Non-Broadcast (NBMA)** | 選出する | 30s / 120s | Unicast | 手動 `neighbor <IP>` 指定が必要。フレームリレーや静的 GRE 共有網用。 |
| **Loopback** | 選出しない | N/A | N/A | ループバック専用。マスク長に関わらず常に `/32`（v6は`/128`）として LSA 宣達。元のマスクで宣達したい場合は `ip ospf network point-to-point` を設定。 |

* **Area Types と自動デフォルトルート注入:**

| Area Type | Type 3 (Summary) | Type 4/5 (External) | Type 7 (NSSA Ext) | デフォルトルート注入方法 |
| :--- | :--- | :--- | :--- | :--- |
| **Standard (Area 0等)** | 許可 | 許可 | 不可 | `default-information originate` (要/不要条件) |
| **Stub** | 許可 | **遮断** | 不可 | ABR が **Type-3 0.0.0.0/0** を自動生成注入。 |
| **Totally Stubby** | **遮断** (一部除) | **遮断** | 不可 | ABR が **Type-3 0.0.0.0/0** を自動生成注入 (`area X stub no-summary`)。 |
| **NSSA** | 許可 | **遮断** | 許可 | ABR は自動生成しない（手動 `area X nssa default-information-originate` が必要）。 |
| **Totally NSSA** | **遮断** | **遮断** | 許可 | ABR が **Type-3 0.0.0.0/0** を自動生成注入 (`area X nssa no-summary`)。 |

### 1.4.d Path preference（パス選定の絶対優先ルール）
OSPF メトリック（コスト）の数値がどれだけ小さくても、以下の **絶対優先順位ルール** に従ってベストパスが決定されます。

1. **Intra-Area (O):** 同一エリア内の経路が最優先。
2. **Inter-Area (O IA):** 他エリアからの集約/要約経路。
3. **External Type 1 (O E1 / O N1):** 外部コスト ＋ ドメイン内内部コストの合算値で比較。
4. **External Type 2 (O E2 / O N2):** 外部コストのみで比較（デフォルト）。外部コストが同点の場合のみ、ASBR までの内部コストでタイブレーク。

### 1.4.e Operations (General, Graceful shutdown, GTSM)
* **Graceful Shutdown:** プロセス全体（`router ospf` 配下の `shutdown`）またはインターフェイス単位（`ip ospf shutdown`）で OSPF を安全に停止。対向へ即座に Flush LSA (Max-Age: 3600s) を送出し、トポロジー再計算を即時誘導。
* **GTSM (Generic TTL Security Mechanism - RFC 5082):** 単一ホスト離れの不正パケットアタックを防止するため、送出パケットの IP TTL を `255` に固定し、受信側で `TTL >= 255 - hop_count` (通常 `255`) であることを厳格チェック (`ip ospf ttl-security`)。

### 1.4.f Optimization, convergence, and scalability
* **Auto-Cost Reference Bandwidth:** デフォルト `100` (100Mbps)。10Gbps 網等では全ルータで一律 `auto-cost reference-bandwidth 10000` または `100000` を投入する。
* **LSA Throttling / SPF Tuning:**
  * LSA 生成間隔の動的抑制: `timers throttle lsa all <start> <hold> <max>`
  * SPF 計算起動間隔の動的抑制: `timers throttle spf <start> <hold> <max>`
* **Stub Router (Max-Metric Router LSA):** ルータの起動時（`on-startup`）や BGP 未コンバージエンス時に、自身の Router LSA コストを最大値 (`65535`) に引き上げて宣言し、他ルータからの過渡的なトラフィック通過（Transit Traffic）を回避させる手法。
* **Prefix Suppression:** リンク障害時の LSA 伝搬量および LSDB/RIB の保持サイズを最小化するため、Point-to-Point 等の Transit リンクの IP サブネット情報を LSA から隠送（Supress）する (`prefix-suppression` / `ip ospf prefix-suppression`)。

---

## 🛠 設定方法

### OSPFv3 Address Family サポート構成例 (IPv4 / IPv6 Dual-Stack)

```bash
# 1. グローバル OSPFv3 プロセス作成
router ospfv3 100
 router-id 1.1.1.1
 !
 address-family ipv4 unicast
  auto-cost reference-bandwidth 10000
  timers throttle spf 50 100 5000
  timers throttle lsa all 50 100 5000
 exit-address-family
 !
 address-family ipv6 unicast
  auto-cost reference-bandwidth 10000
  timers throttle spf 50 100 5000
  timers throttle lsa all 50 100 5000
 exit-address-family
!
# 2. インターフェイス配下でのバインド
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
 ospfv3 1 ipv4 area 0
 ospfv3 1 ipv6 area 0
 ospfv3 network point-to-point
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPFv2 ネイバーアジャセンシー状態・タイマー・DR/BDRの確認** | <code>show ip ospf neighbor</code> / <code>show ip ospf neighbor detail</code> |
| **OSPFv3 (IPv4/IPv6) ネイバー状態の確認** | <code>show ospfv3 neighbor</code> |
| **OSPFv2 リンクステートデータベース (LSDB) 全体監査** | <code>show ip ospf database</code> |
| **OSPFv3 LSDB の LSA タイプ別監査** | <code>show ospfv3 database</code> |
| **インターフェイスごとの Network Type、Cost、DR/BDR、Timer、Authentication 確認** | <code>show ip ospf interface <int></code> / <code>show ospfv3 interface <int></code> |
| **OSPF パス計算・メトリック・エリア別情報・SPF 実行回数の確認** | <code>show ip ospf</code> |
| **OSPF ネイバー確立イベント（Hello/DBD/LSR/LSU）のリアルタイムデバッグ** | <code>debug ip ospf adj</code> / <code>debug ip ospf events</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **ネイバー状態が `ExStart` または `Exchange` ステートで永久ハングする。** | 対向ルータとの間でインターフェイス L3 MTU が不一致を起こしている（DBD パケットのサイズ溢れ）。 | `show ip ospf neighbor`<br>`show interface <int>` | 両端の MTU を一致させるか、一時回避策として該当ポートで `ip ospf mtu-ignore` を設定する。 |
| **ネイバー状態が `2-Way` のまま `Full` に遷移しない。** | Broadcast 網で該当ルータが DR/BDR 以外の Drother ルータ同士で接続されている（正常動作）。または Priority 誤設定。 | `show ip ospf interface` | Drother 同士であれば 2-Way が正常。全アジャセンシーが必要な場合は Network Type を `point-to-point` に変更する。 |
| **NSSA エリアの外部経路が他エリアへ伝搬されない。** | NSSA ABR 上で Type-7 ➔ Type-5 変換処理が停止している、または P-bit (Propagate) が 0 になっている。 | `show ip ospf database nssa-external` | ABR で `area X nssa` の設定を確認し、必要に応じて `area X nssa default-information-originate` や変換ルールを見直す。 |
| **OSPFv3 IPv4 ネイバーが成立しない。** | 該当インターフェイスで IPv6（Link-Local アドレス）が有効化されていない。 | `show ospfv3 interface` | インターフェイスに `ipv6 enable` または IPv6 アドレスを設定して Link-Local（`fe80::`）を生成させる。 |

---

## ⚠ 制限事項

1. **エリア 0 非隣接の分離禁止:**
   * 全てのエリアは物理的または論理的（Virtual-Link / GRE）に Area 0 に接触していなければエリア間ルーティングが動作しません。
2. **OSPFv3 における IPv4/IPv6 インスタンス分類:**
   * OSPFv3 AF サポートを使用する場合、対向ルータも OSPFv3 AF (RFC 5838) に対応したソフトウェアバージョン（Cisco IOS-XE）で構成されている必要があります。

---

## 🔄 他技術との関連

* **BFD (Bidirectional Forwarding Detection):**
  `ip ospf bfd` または `ospfv3 bfd` により、ミリ秒単位でリンク障害を検知し、即座に OSPF アジャセンシーを Down させて SPF を起動します。
* **VRF-Lite (`capability vrf-lite`):**
  VRF 配下で動作する OSPF ルータはデフォルトで DN Bit (Down Bit) および Domain Tag をチェックしてループを阻止しますが、PE-CE でなく単なる VRF-Lite の場合は LSA 破棄事故を防ぐために `capability vrf-lite` の投入が必須です。
* **MPLS L3VPN:**
  PE-CE 間で OSPF を使用する際、MP-BGP 経由で運ばれた OSPF 経路が Type-3 (Inter-Area) として復元されるように Domain-ID や Sham-Link が設計されます。

---

## 🧩 比較表

### OSPF Area Types の完全比較

| Area Type | Type 1/2 (Intra) | Type 3 (Inter) | Type 4/5 (External) | Type 7 (NSSA Ext) | デフォルトルート注入方式 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Standard (Area 0等)** | 許可 | 許可 | 許可 | 不可 | `default-information originate` |
| **Stub** | 許可 | 許可 | **遮断** | 不可 | ABR が **Type-3** デフォルトを自動注入 |
| **Totally Stubby** | 許可 | **遮断** | **遮断** | 不可 | ABR が **Type-3** デフォルトを自動注入 (`no-summary`) |
| **NSSA** | 許可 | 許可 | **遮断** | 許可 | 手動 `area X nssa default-information-originate` |
| **Totally NSSA** | 許可 | **遮断** | **遮断** | 許可 | ABR が **Type-3** デフォルトを自動注入 (`no-summary`) |

---

## 💡 ベストプラクティス

1. **`auto-cost reference-bandwidth` の一律定義:**
   全ルータで `auto-cost reference-bandwidth 10000` (10Gbps) または `100000` (100Gbps) を統一設定する。
2. **Point-to-Point ネットワークタイプの積極利用:**
   イーサネット直結リンクでは明示的に `ip ospf network point-to-point` を設定し、DR/BDR 選出の遅達（10秒）や計算オーバーヘッドを排除する。
3. **Prefix Suppression によるトポロジー軽量化:**
   ルータ間 Transit リンクのサブネット情報を `prefix-suppression` で隠蔽し、LSDB サイズ削減と LSA フラッディングの最小化を図る。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: OSPFv2 Multi-Area 基本構成と Reference Bandwidth 調整
* **要件:** R1 (Area 0: Gi0/1) と R2 (Area 1: Gi0/2) を ABR として構成し、Reference Bandwidth を 10Gbps (10000) に設定せよ。

**【R1 (ABR)】**
```bash
router ospf 1
 router-id 1.1.1.1
 auto-cost reference-bandwidth 10000
 network 10.1.12.1 0.0.0.0 area 0
 network 10.1.23.1 0.0.0.0 area 1
```

**【R2】**
```bash
router ospf 1
 router-id 2.2.2.2
 auto-cost reference-bandwidth 10000
 network 10.1.23.2 0.0.0.0 area 1
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# Cost が Reference Bandwidth 基準で正常計算されていることを確認
```

---

### Scenario 2: OSPFv3 Address Family サポート (IPv4 / IPv6 統合)
* **要件:** 単一の `router ospfv3 100` プロセス内で IPv4 Unicast および IPv6 Unicast を Area 0 上で有効化せよ。

**【R1】**
```bash
router ospfv3 100
 router-id 1.1.1.1
 address-family ipv4 unicast
 exit-address-family
 address-family ipv6 unicast
 exit-address-family
!
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
 ospfv3 1 ipv4 area 0
 ospfv3 1 ipv6 area 0
```

**【検証方法】**
```bash
R1# show ospfv3 neighbor
# IPv4 および IPv6 の両アジャセンシーが UP していることを確認
```

---

### Scenario 3: OSPF Network Type 変更 (Point-to-Point 化)
* **要件:** Gi0/1 イーサネットインターフェイス上で DR/BDR 選出を無効化するため、Network Type を `point-to-point` に指定せよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf network point-to-point
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# State が POINT_TO_POINT になっており DR/BDR が None であることを確認
```

---

### Scenario 4: Totally Stubby Area 構成とデフォルトルート自動注入
* **要件:** Area 10 を Totally Stubby Area として構成し、Type-3 および Type-5 LSA を一切侵入させるな。

**【R1 (ABR)】**
```bash
router ospf 1
 area 10 stub no-summary
```

**【R2 (Internal Stub Router)】**
```bash
router ospf 1
 area 10 stub
```

**【検証方法】**
```bash
R2# show ip route ospf
# IA / E1 / E2 経路が消去され、O*IA 0.0.0.0/0 のみが掲載されていることを確認
```

---

### Scenario 5: Totally NSSA 構成と外部経路 (Type-7) の再配送
* **要件:** Area 20 を Totally NSSA として構成し、R2 (NSSA ASBR) 上で Static 経路を再配送せよ。

**【R1 (NSSA ABR)】**
```bash
router ospf 1
 area 20 nssa no-summary
```

**【R2 (NSSA ASBR)】**
```bash
router ospf 1
 area 20 nssa
 redistribute static subnets
!
ip route 192.168.99.0 255.255.255.0 Null0
```

**【検証方法】**
```bash
R1# show ip ospf database nssa-external
# Type-7 LSA が生成され、ABR で Type-5 へ変換されていることを確認
```

---

### Scenario 6: GTSM (Generic TTL Security Mechanism) の有効化
* **要件:** 該当 OSPF プロセス全体で IP TTL 255 チェックによる防御（GTSM）を構成せよ。

**【R1 / R2 共通】**
```bash
router ospf 1
 ttl-security all-interfaces
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# Strict TTL security enabled が出力されることを確認
```

---

### Scenario 7: Fast Convergence (LSA Throttling & SPF Tuning)
* **要件:** SPF 計算起動間隔および LSA 生成間隔をミリ秒単位で高速チューニングせよ。

**【R1 / R2 共通】**
```bash
router ospf 1
 timers throttle spf 50 100 5000
 timers throttle lsa all 50 100 5000
 timers lsa arrival 80
```

**【検証方法】**
```bash
R1# show ip ospf
# SPF 定義タイマー値を確認
```

---

### Scenario 8: Max-Metric Stub Router (Startup 迂回設定)
* **要件:** ルータ起動後 600 秒間、他ルータからの過渡的トラフィック流入を防ぐため Max-Metric（Stub Router）を宣言せよ。

**【R1】**
```bash
router ospf 1
 max-metric router-lsa on-startup 600
```

**【検証方法】**
```bash
R1# show ip ospf
# Router-lsa max-metric originating state がアクティブであることを確認
```

---

### Scenario 9: Prefix Suppression による Transit リンクの隠蔽
* **要件:** エリア内の OSPF LSA サイズを最小化するため、全 Point-to-Point リンクの IP プレフィックス宣達を抑制せよ。

**【R1】**
```bash
router ospf 1
 prefix-suppression
```

**【検証方法】**
```bash
R2# show ip ospf database router 1.1.1.1
# Transit リンクの Stub Prefix 情報が LSA から削除されていることを確認
```

---

### Scenario 10: OSPFv2 HMAC-SHA-256 (RFC 5709) 暗号化認証設定
* **要件:** Gi0/1 上で Key-Chain による HMAC-SHA-256 認証を設定せよ。

**【R1 / R2 共通】**
```bash
key chain OSPF_SHA_KEYS
 key 1
  key-string CISCO_SHA_SECRET
  cryptographic-algorithm hmac-sha-256
!
interface GigabitEthernet0/1
 ip ospf authentication key-chain OSPF_SHA_KEYS
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# Cryptographic authentication enabled (HMAC-SHA-256) を確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】L3 MTU 不一致による ExStart ハング
**問題:** 
R1 と R2 の間で `router ospf 1` を有効化しましたが、`show ip ospf neighbor` の出力で対向ステートが `EXSTART/DR` のまま停止し、`FULL` に推移しません。物理リンク上の通信（Ping 1500バイト）は成功しています。原因と恒久対策・一時回避策を述べてください。

**解答・解説:**
* **原因:** R1 と R2 のインターフェイス L3 MTU 設定が不一致（例: R1 が 1500B、R2 が 1400B）を起こしています。Hello パケット交換は成功（2-Way成立）しますが、LSDB ヘッダーを載せた大型の DBD パケットを送受信する段階（ExStart/Exchange）で、小さい MTU 側のルータがサイズ溢れパケットを破棄するため永久ハングが発生します。
* **恒久対策:** 両ルータのインターフェイス MTU（`ip mtu`）を同じサイズ（例: 1500）に統一設定する。
* **一時回避策:** 該当インターフェイス配下で `ip ospf mtu-ignore` コマンドを投入し、DBD ヘッダー内の MTU チェック処理を強制バイパスさせる。

---

### 2. 【コンフィグ読解・設計】NSSA エリアにおけるデフォルトルート非注入問題
**問題:** 
Area 10 を NSSA として設定し、ABR 上で `area 10 nssa` コマンドを投入しました。しかし、NSSA エリア内の内部ルータのルーティングテーブルにデフォルトルート (`0.0.0.0/0`) が自動生成されません。Stub エリアとは異なる NSSA のこの挙動の理由と、デフォルトルートを注入するための修正コマンドを答えてください。

**解答・解説:**
* **理由:** OSPF の仕様上、Standard Stub エリアや Totally Stub/Totally NSSA エリアでは ABR が自動的に Type-3 デフォルトルートを生成しますが、**通常の NSSA エリア（Standard NSSA）では ABR はデフォルトルートを自動注入しません。**（これは外部ドメイン接続時のルーティングループや非意図的トラフィック引き込みを防ぐ設計仕様です）。
* **修正コマンド:** ABR ルータ上で `area 10 nssa default-information-originate` を手動設定するか、あるいはエリア自体を Totally NSSA (`area 10 nssa no-summary`) に変更して ABR に Type-3 デフォルトルートを自動注入させます。

---

## 🔗 参考リソース

* [Cisco Systems: OSPF Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iri-xe-17-book.html)
* [Cisco Command Reference: OSPF Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/command/iro-cr-book.html)
* [Cisco Live: BRKRST-2337 - OSPF Network Design and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **OSPFv2 vs OSPFv3 のコマンド体系比較:**
  * OSPFv2: `router ospf <process-id>` / インターフェイス上 `ip ospf <process-id> area <area-id>`
  * OSPFv3 AF: `router ospfv3 <process-id>` / インターフェイス上 `ospfv3 <process-id> <ipv4|ipv6> area <area-id>`
