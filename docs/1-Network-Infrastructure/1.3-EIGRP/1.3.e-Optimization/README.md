---
layout: default
title: 1.3.e-Optimization
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.3.e Optimization, convergence, and scalability

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における EIGRP のスケーラビリティ、最適化、および高速コンバージエンスの核心技術である **1.3.e (i) Query propagation boundaries（クエリ拡散境界）**, **1.3.e (ii) Leak-map with summary routes（サマリルートにおけるリークマップ）**, **1.3.e (iii) EIGRP stub with leak map（EIGRP スタブにおけるリークマップ）** について、Cisco IOS-XE 17.x の実装基準に完全準拠して解説します。

---

## 📘 概要

EIGRP（Enhanced Interior Gateway Routing Protocol）は、リンク障害時や経路喪失時に DUAL（Diffusing Update Algorithm）を起動し、バックアップ経路（Feasible Successor）が存在しない場合、ネイバーに対して **Query（問い合わせ）パケット** をマルチキャスト/ユニキャストで送出して代替経路を検索します。

しかし、大規模なエンタープライズネットワークやハブ＆スポーク網（DMVPN等）において Query パケットが全ネットワークへ無制限に拡散すると、以下の深刻な問題が発生します。

1. **ネットワーク帯域と CPU 資源の浪費（Query Storm）**
2. **SIA（Stuck-In-Active）状態の誘発:** 深遠なネットワークの先にある1台のルータが応答（Reply）を返さないだけで、元のルータが 180 秒間待ち続け、正常なネイバーアジャセンシーまでもが切断される。
3. **不要なルーティングテーブルの増大:** 端末収容ルータに全社の詳細ルートが維持され、メモリとコントロールプレーンを圧迫する。

制限無く拡がる Query を適切な境界で遮断し、ミリ秒〜サブ秒単位の高速コンバージエンスと優れた拡張性（Scalability）を実現するために不可欠なのが、**クエリ拡散境界（Query Propagation Boundaries）の設計**、**手動ルート集約と Leak-Map 制御**、および **EIGRP Stub と Leak-Map の組み合わせ** です。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **対象技術** | Query Propagation Boundaries, Leak-Map with Summary Routes, EIGRP Stub with Leak Map |
| **用途** | クエリ範囲の限定、SIA（Stuck-In-Active）の根本排除、集約環境/スタブ環境における特定個別ルートの選択的リーク |
| **メリット** | ① クエリの拡散を境界ルータで物理的に遮断（即座に Unreachable Reply を返却）。<br>② クエリ応答遅延によるネイバー切断（SIA）を回避。<br>③ 集約経路やスタブ経路の配下にある特定のサーバ・ループバック等へピンポイントでトラフィックを誘導。 |
| **デメリット** | Leak-Map の ACL/Prefix-List/Route-Map 定義が複雑化し、設定ミスによりルーティングループや非対称ルーティングが生じるリスクがある。 |
| **主な制御手法** | ① **EIGRP Stub Router:** 対向ルータに「自分はトランジットルータではない」と通知し、クエリ対象から完全除外させる。<br>② **Manual Summarization:** 集約ポイントでクエリの拡散をストップさせる。<br>③ **Leak-Map 結合:** サマリ経路やスタブ制限を維持しつつ、特定のプレフィックスのみ例外的にアドバタイズする。 |
| **設計上の注意点** | Leak-Map で参照する Route-Map 内で `match ip address prefix-list` を定義する際、`permit` エントリで指定されたプレフィックスのみが「リーク（例外送信）」される。 |

---

## 🏗 動作原理

### 1. クエリ拡散境界（Query Propagation Boundaries）の仕組み

DUAL が Query を送信した際、受信したルータが該当ルートの代替えを持っていなければ、さらにその先のネイバーへと Query を転播（Flood）します。クエリの拡大を抑止する「壁（Boundary）」となるのが以下の要素です。

```text
[ Route Lost ] ──► ( R1 ) ── Query ──► ( R2: Boundary ) ── X (No Query Sent)
                                              │
                                   [ Instant Reply: Unreachable ]
```

* **手動サマリルート（Summary Route）の配置:**
  R2 が R1 に対して `10.1.0.0/16` というサマリルートを広告している場合、`10.1.5.0/24` が失われて R1 から R2 へ Query が届くと、R2 は即座に「10.1.5.0/24 は知らない（Unreachable）」という Reply を返します。R2 から先へ Query は一切拡散しません。
* **EIGRP Stub ルータの定義:**
  R2 が Stub ルータとして動作している場合、ネイバー接続（Init 段階）時に「Stub である」属性を R1 へ通知します。R1 はトポロジー変化が発生しても、Stub ルータである R2 には**最初から Query パケット自体を送信しません**。

---

### 2. サマリルートにおける Leak-Map の動作原理

通常、`summary-address 10.1.0.0 255.255.0.0` を設定すると、配下の `10.1.1.0/24`, `10.1.2.0/24` 等の個別明細ルート（Component Routes）はすべて抑制（Suppress）され、サマリルートのみが送信されます。

しかし、「マルチホーム環境で特定サイトへのトラフィックを最適パスへ誘導したい」「特定のDNS/NTPサーバ（/32）だけは明細で広報したい」という要件が発生した場合に **Leak-Map** を結合します。

```text
[ Component Routes: 10.1.1.0/24, 10.1.2.0/24, 10.1.100.1/32 ]
                             │
            [ Summary Address: 10.1.0.0/16 ]
                             │
            [ Leak-Map: Permit 10.1.100.1/32 ]
                             │
                             ▼
[ Advertised Routes: 10.1.0.0/16 AND 10.1.100.1/32 (Leaked!) ]
```

---

### 3. EIGRP Stub with Leak-Map の動作原理

EIGRP Stub ルータは、デフォルトで `connected` および `summary` 経路のみを広報し、他のルータから学習した IGP 経路や再配送経路のトランジット（中継）を一切遮断します。

しかし、スタブ配下に接続された特定の再配送経路や、特定のサマリルート配下の特定サブネットだけを上流へ伝えたい場合、`eigrp stub` コマンドに `leak-map` を結合します。

```text
( Spoke Router / Stub )
   │  ├─ Connected: 10.2.1.0/24
   │  ├─ Static/Redistributed: 172.16.1.0/24  <── Normally Blocked by Stub!
   │  └─ Leak-Map: Permits 172.16.1.0/24
   │
   └──────► Advertises: Connected + 172.16.1.0/24 (Leaked Route) to Hub
```

---

## ⚙ 動作シーケンス

### Leak-Map 評価シーケンス（サマリおよびスタブ共通）

1. **パケット生成 / ルート広報のトリガー:**
   EIGRP プロセスが隣接ルータへ Update パケットを生成します。
2. **Summary または Stub 条件の評価:**
   インターフェイスに `summary-address` が設定されているか、またはグローバル/AF配下で `eigrp stub` が有効化されているかをチェックします。
3. **Leak-Map (Route-Map) の検索:**
   `leak-map <MAP_NAME>` が指定されている場合、定義された Route-Map を参照します。
4. **ACL / Prefix-List とのマッチング:**
   Route-Map 内の `match ip address prefix-list <LIST>` を評価します。
   * `permit` に合致したプレフィックス: サマリー抑止またはスタブ制限を免除され、**明細ルートとして Update パケットに追加送出**されます。
   * `deny` または未マッチのプレフィックス: 通常通りサマリー抑止またはスタブ制限が適用され、広報されません。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. ラボ試験での最頻出要件パターン

CCIE EI Practical Lab 試験では、以下のような「一見矛盾する要件」を提示して技術力を試してきます。

* **課題例 1 (Summary + Leak-Map):**
  「R1 は R2 に対して `10.1.0.0/16` のサマリルートのみを広報すること。ただし、最適ルーティングを維持するため、`10.1.50.0/24` のみは明細ルートとしても同時に広報しなければならない。追加の Filter コマンドや ACL による否定は不可とする。」
* **課題例 2 (Stub + Leak-Map):**
  「R3（Spokeルータ）を EIGRP Stub ルータとして設定し、クエリの受信を完全に遮断せよ。ただし、R3 上で OSPF から EIGRP へ再配送されている `192.168.100.0/24` の経路のみは、Hub ルータへ正常に広報されるように設定せよ。」

### 2. よくある設定ミスとハマりポイント

1. **Route-Map 内の `permit` / `deny` と Prefix-List 内の `permit` / `deny` の混同:**
   * **正解:** Prefix-List で `permit 10.1.50.0/24` を記述し、Route-Map でも `permit 10` でその Prefix-List を `match` させる。
   * **ミス:** Prefix-List や Route-Map で `deny` を書いてしまい、リークさせたい経路が正しく抽出されずブロックされる。
2. **Classic Mode と Named Mode での構文・階層の違い:**
   * **Classic Mode (Summary Leak-Map):**
     `interface GigabitEthernet0/1` 配下で `ip summary-address eigrp 100 10.1.0.0 255.255.0.0 leak-map LEAK_MAP`
   * **Named Mode (Summary Leak-Map):**
     `router eigrp FABRIC` ➔ `address-family ipv4 unicast autonomous-system 100` ➔ `af-interface GigabitEthernet0/1` 配下で `summary-address 10.1.0.0 255.255.0.0 leak-map LEAK_MAP`
   * **Named Mode (EIGRP Stub with Leak-Map):**
     `router eigrp FABRIC` ➔ `address-family ipv4 unicast autonomous-system 100` 直下の AF モード配下（`eigrp stub leak-map LEAK_MAP`）で設定（`topology base` 配下ではない点に極めて注意！）。

---

## 🛠 設定方法

### 1. Summary Route with Leak-Map (Named Mode)

```bash
# 1. 抽出用 Prefix-List の作成
ip prefix-list PLIST_LEAK permit 10.1.50.0/24

# 2. リーク制御用 Route-Map の作成
route-map RMAP_LEAK permit 10
 match ip address prefix-list PLIST_LEAK
!

# 3. EIGRP Named Mode 配下でのサマリー＆リークマップ設定
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   summary-address 10.1.0.0 255.255.0.0 leak-map RMAP_LEAK
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.0.0 0.0.255.255
 exit-address-family
```

### 2. EIGRP Stub with Leak-Map (Named Mode)

```bash
# 1. リーク対象経路（例: 再配送ルート 172.16.10.0/24）の Prefix-List 作成
ip prefix-list PLIST_STUB_LEAK permit 172.16.10.0/24

# 2. Route-Map 作成
route-map RMAP_STUB_LEAK permit 10
 match ip address prefix-list PLIST_STUB_LEAK
!

# 3. EIGRP Named Mode での Stub Leak-Map 設定
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  # AF 直下モードで stub leak-map を指定
  eigrp stub leak-map RMAP_STUB_LEAK
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
   redistribute static
  exit-af-topology
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EIGRP ネイバーの Stub フラグ状態（対向が Stub かどうか）の確認** | <code>show ip eigrp neighbors detail</code> / <code>show eigrp address-family ipv4 neighbors detail</code> |
| **自ルータの Stub 動作モードおよび Leak-Map 適用状態の確認** | <code>show ip protocols</code> / <code>show eigrp address-family ipv4 protocols</code> |
| **特定インターフェイスで送信されているサマリルートと Leak-Map 名の確認** | <code>show eigrp address-family ipv4 interfaces detail</code> |
| **トポロジーテーブル上での Leak 経路の掲載確認** | <code>show ip eigrp topology</code> |
| **対向ルータでの受送信経路（サマリ＋リーク経路）の確認** | <code>show ip route eigrp</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **サマリルートは送信されているが、Leak-Map で指定した個別ルートが対向に届かない。** | 1. Prefix-List の指定ミス（IP やマスクの不一致）。<br>2. Route-Map 内の `match ip address` で指定した Prefix-List 名のタイポ。<br>3. 該当の明細ルート自体がローカル RIB / DUAL テーブルに存在していない。 | `show ip prefix-list`<br>`show route-map`<br>`show ip eigrp topology` | 1. Prefix-List と Route-Map の紐付けを確認。<br>2. リーク対象の明細ルートが自ルータの DUAL トポロジーテーブルに Active/Passive で存在しているか確認する。 |
| **`eigrp stub leak-map` を設定したのに、再配送経路が全く送信されない。** | Route-Map 内で `match ip address` ではなく `match route-type` 等を誤用しているか、または Prefix-List が `deny` になっている。 | `show route-map`<br>`show ip protocols` | Route-Map 内の `match` 条件を Prefix-List による明示的な `permit` に変更する。 |
| **EIGRP Stub を設定した後に全ルートが消失した。** | `eigrp stub` コマンドで `connected` や `summary` などの標準オプションを指定せず、誤った引数のみを投入した。 | `show ip protocols` | 通常 `eigrp stub` はデフォルトで `connected summary` になりますが、`leak-map` 使用時もこの基本動作が維持されているか確認する。 |

---

## ⚠ 制限事項

1. **Leak-Map 適用時の CPU / メモリ消費:**
   大量のプレフィックスに対して動的に Leak-Map を評価する場合、コントロールプレーンの処理オーバーヘッドがわずかに増加します。
2. **Null0 ディスカードルートの自動生成:**
   `summary-address` を設定すると、自ルータ内に Administrative Distance (AD) 5 の Null0 宛てルートが自動生成されます。Leak-Map で明細をリークさせても、この Null0 ルートは削除されません。

---

## 🔄 他技術との関連

* **DMVPN (Dynamic Multipoint VPN):**
  Spoke ルータ群を `eigrp stub` 化することで、Hub ルータからの Query 拡散を物理的に遮断し、WAN 全体のコンバー全速度を最大化します。特定 Spoke 配下のサブネットのみを全社へ伝えるために `leak-map` を併用します。
* **Route Redistribution（相互再配送）:**
  他の IGP や BGP から EIGRP へ再配送された経路を Stub 環境下で部分的に上流へ広告する際、`eigrp stub redistributive` または `eigrp stub leak-map` が使用されます。

---

## 🧩 比較表

### Query 制御手法の比較

| 手法 | 動作メカニズム | クエリ遮断効果 | 特定経路の例外送信 |
| :--- | :--- | :--- | :--- |
| **EIGRP Stub** | ネイバーへ Stub 属性を通知し、対向からの クエリ送信自体を抑止 | **完全遮断** (Query が最初から飛んでこない) | `leak-map` を結合することで可能 |
| **Manual Summary** | サマリー境界で明細への Query に対し即座に Unreachable Reply を返却 | **境界で遮断** (サマリ位置で Reply 返却) | `leak-map` を結合することで可能 |
| **Passive Interface** | Hello/Query 含む全 EIGRP パケットの送受信を停止 | **完全停止** (ネイバー自体が形成されない) | 不可 |

---

## 💡 ベストプラクティス

1. **ハブ＆スポーク構成での全 Spoke ルータ Stub 化:**
   DMVPN や リモート拠点ルータ（Spoke）は 100% `eigrp stub` として構成し、Query Storm と SIA を未然に防止する。
2. **Summary Address 適用時の Leak-Map による非対称回避:**
   マルチホーム環境でサマリルートを引く場合は、特定回線へトラフィックを誘導するために適切な Leak-Map を設計し、非対称ルーティングによるドロップを防ぐ。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Summary Route with Leak-Map 基本設定 (Named Mode)
* **要件:** R1 は Gi0/1 配下に `10.1.0.0/16` のサマリルートを広報せよ。ただし、`10.1.100.0/24` の明細ルートのみは同時にリーク（広告）させよ。

**【R1】**
```bash
ip prefix-list PL_LEAK1 permit 10.1.100.0/24
!
route-map RM_LEAK1 permit 10
 match ip address prefix-list PL_LEAK1
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   summary-address 10.1.0.0 255.255.0.0 leak-map RM_LEAK1
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.0.0 0.0.255.255
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip route eigrp
# 10.1.0.0/16 と 10.1.100.0/24 の両方が RIB に掲載されていることを確認
```

---

### Scenario 2: EIGRP Stub with Leak-Map (再配送経路の個別リーク)
* **要件:** R3 を EIGRP Stub ルータとして構成し、クエリ拡散を防止せよ。ただし、Static から再配送された `172.16.50.0/24` のみは例外的に Hub へ広告せよ。

**【R3】**
```bash
ip route 172.16.50.0 255.255.255.0 Null0
!
ip prefix-list PL_STUB_LEAK2 permit 172.16.50.0/24
!
route-map RM_STUB_LEAK2 permit 10
 match ip address prefix-list PL_STUB_LEAK2
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  eigrp stub leak-map RM_STUB_LEAK2
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
   redistribute static
  exit-af-topology
  !
  network 10.3.0.0 0.0.255.255
 exit-address-family
```

**【検証方法】**
```bash
R1(Hub)# show ip route 172.16.50.0
# Hub 側で 172.16.50.0/24 が EIGRP 外部ルート (D EX) として受信されていることを確認
```

---

### Scenario 3: Multiple Leaked Prefixes with Leak-Map
* **要件:** `10.2.0.0/16` のサマリルートから、`10.2.10.0/24` および `10.2.20.0/24` の 2 つの明細ルートを同時にリークさせよ。

**【R1】**
```bash
ip prefix-list PL_MULTI_LEAK permit 10.2.10.0/24
ip prefix-list PL_MULTI_LEAK permit 10.2.20.0/24
!
route-map RM_MULTI_LEAK permit 10
 match ip address prefix-list PL_MULTI_LEAK
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   summary-address 10.2.0.0 255.255.0.0 leak-map RM_MULTI_LEAK
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.2.0.0 0.0.255.255
 exit-address-family
```

---

### Scenario 4: Classic Mode における Summary Leak-Map 構成
* **要件:** Classic Mode (`router eigrp 100`) において、Gi0/1 上で `192.168.0.0/16` のサマリーを送りつつ `192.168.1.1/32`（DNSサーバ）のみリークさせよ。

**【R1】**
```bash
ip prefix-list PL_DNS_LEAK permit 192.168.1.1/32
!
route-map RM_DNS_LEAK permit 10
 match ip address prefix-list PL_DNS_LEAK
!
interface GigabitEthernet0/1
 ip summary-address eigrp 100 192.168.0.0 255.255.0.0 leak-map RM_DNS_LEAK
!
router eigrp 100
 network 192.168.0.0
```

---

### Scenario 5: Classic Mode における EIGRP Stub with Leak-Map
* **要件:** Classic Mode で R2 を Stub 化しつつ、`10.99.99.0/24` をリークさせよ。

**【R2】**
```bash
ip prefix-list PL_CLASSIC_STUB permit 10.99.99.0/24
!
route-map RM_CLASSIC_STUB permit 10
 match ip address prefix-list PL_CLASSIC_STUB
!
router eigrp 100
 eigrp stub leak-map RM_CLASSIC_STUB
 network 10.0.0.0
```

---

### Scenario 6: DMVPN Hub における Summary + Leak-Map によるトラフィックエンジニアリング
* **要件:** DMVPN Hub(R1) は Tunnel0 上で Spoke 群へ `10.0.0.0/8` をサマリー広告せよ。ただし、Spoke1 配下の特定サーバ `10.0.1.100/32` のみ明細でリークさせよ。

**【R1 (Hub)】**
```bash
ip prefix-list PL_DMVPN_LEAK permit 10.0.1.100/32
!
route-map RM_DMVPN_LEAK permit 10
 match ip address prefix-list PL_DMVPN_LEAK
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 10
  af-interface Tunnel0
   no split-horizon
   summary-address 10.0.0.0 255.0.0.0 leak-map RM_DMVPN_LEAK
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.0.0.0
 exit-address-family
```

---

### Scenario 7: EIGRPv6 (IPv6) Summary Route with Leak-Map
* **要件:** EIGRPv6 において `2001:db8:10::/48` をサマリー広告しつつ、`2001:db8:10:1::1/128` のみをリークさせよ。

**【R1】**
```bash
ipv6 prefix-list PL6_LEAK permit 2001:db8:10:1::1/128
!
route-map RM6_LEAK permit 10
 match ipv6 address prefix-list PL6_LEAK
!
router eigrp FABRIC
 !
 address-family ipv6 unicast autonomous-system 200
  af-interface GigabitEthernet0/1
   summary-address 2001:db8:10::/48 leak-map RM6_LEAK
  exit-af-interface
  !
  topology base
  exit-af-topology
 exit-address-family
```

---

### Scenario 8: Leak-Map による特定 Loopback インターフェイスのピンポイント露出
* **要件:** ルータ R1 上の多層 Loopback のうち、`Loopback10 (172.16.10.1/32)` のみを EIGRP Stub 環境から露出（リーク）させよ。

**【R1】**
```bash
interface Loopback10
 ip address 172.16.10.1 255.255.255.255
!
ip prefix-list PL_LO10 permit 172.16.10.1/32
!
route-map RM_LO10 permit 10
 match ip address prefix-list PL_LO10
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  eigrp stub leak-map RM_LO10
  !
  network 172.16.10.1 0.0.0.0
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

---

### Scenario 9: VRF-Aware EIGRP Summary with Leak-Map
* **要件:** VRF `RED` 配下で `10.50.0.0/16` をサマリー広告し、`10.50.1.0/24` のみをリークさせよ。

**【R1】**
```bash
ip prefix-list PL_VRF_RED_LEAK permit 10.50.1.0/24
!
route-map RM_VRF_RED_LEAK permit 10
 match ip address prefix-list PL_VRF_RED_LEAK
!
router eigrp FABRIC
 !
 address-family ipv4 unicast vrf RED autonomous-system 500
  af-interface GigabitEthernet0/2
   summary-address 10.50.0.0 255.255.0.0 leak-map RM_VRF_RED_LEAK
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.50.0.0 0.0.255.255
 exit-address-family
```

---

### Scenario 10: トラブルシューティング（Leak-Map 内の Prefix-List ミスマッチ修正）
* **要件:** R1 で `10.88.0.0/16` のサマリーに Leak-Map を設定しているが、`10.88.5.0/24` がリークされない問題を診断・修復せよ。

**【不具合のあるコンフィグ】**
```bash
ip prefix-list PL_BAD permit 10.88.5.0/25  <-- マスク長不一致 (/25 になっている)
!
route-map RM_BAD permit 10
 match ip address prefix-list PL_BAD
```

**【修正コマンド】**
```bash
no ip prefix-list PL_BAD
ip prefix-list PL_BAD permit 10.88.5.0/24
```

**【検証方法】**
```bash
R2# show ip route 10.88.5.0
# 10.88.5.0/24 が正確に RIB に掲載されたことを確認
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解・実装】EIGRP Stub with Leak-Map の設定箇所
**問題:** 
以下の要件を満たす EIGRP Named Mode コンフィグを作成してください。
* プロセス名: `CCIE_CORE`
* AS 番号: 100
* R1 は EIGRP Stub ルータとして動作させ、対向からの Query 受信を停止すること。
* ただし、BGP から EIGRP へ再配送されている `192.168.200.0/24` の経路のみは、例外的に対向へ広告しなければならない。

**解答・解説:**
```bash
ip prefix-list PL_BGP_LEAK permit 192.168.200.0/24
!
route-map RM_BGP_LEAK permit 10
 match ip address prefix-list PL_BGP_LEAK
!
router eigrp CCIE_CORE
 !
 address-family ipv4 unicast autonomous-system 100
  eigrp stub leak-map RM_BGP_LEAK
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
   redistribute bgp 65000 metric 100000 10 255 1 1500
  exit-af-topology
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```
* **解説:**
  `eigrp stub` に `leak-map` を付与することで、Stub ルータによる自動経路抑制をバイパスし、指定した再配送ルート（`192.168.200.0/24`）のみを対向へ安全に伝搬できます。設定位置が AF 直下モード（`eigrp stub leak-map`）である点に注意が必要です。

---

### 2. 【トラブルシューティング・Design】Query Propagation Boundary と SIA
**問題:** 
大規模な DMVPN ネットワークにおいて、Spoke ルータの1台で WAN リンク切断が発生した際、Hub ルータが Active Timer（180秒）満了まで応答待ちとなり、他の正常な Spoke とのアジャセンシーまで連続して切断される障害（SIA: Stuck-In-Active）が多発しています。既存のルーティング設計を一切崩さずに、この SIA 現象を根本解決するための最良の設計変更を述べよ。

**解答・解説:**
* **回答:** 
  すべての Spoke ルータにおいて **EIGRP Stub ルータ（`eigrp stub`）機能** を有効化する。
* **解説:** 
  Spoke ルータ群を Stub 化することにより、Hub ルータは「Spoke はトランジットルータではない」と認識し、障害発生時に Spoke ルータ群へ向けて Query パケット自体を一切送信しなくなります（Query Propagation Boundary の形成）。これにより、特定 Spoke の応答遅延による SIA 障害が完全排除されます。

---

## 🔗 参考リソース

* [Cisco Systems: EIGRP Stub Router Functionality](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13655-39.html)
* [Cisco Systems: EIGRP Configuration Guide, Cisco IOS XE Release 3S - Route Summarization](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-3s/ire-xe-3s-book.html)
* [Cisco Live: BRKRST-2336 - EIGRP Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **Leak-Map 設計時の基本ルール:**
  1. Prefix-List でリークしたいプレフィックスを `permit` する。
  2. Route-Map でその Prefix-List を `match` して `permit` する。
  3. `summary-address ... leak-map` または `eigrp stub leak-map` で紐付ける。


## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide - Optimization (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book/ire-enhanced-igrp.html)。
*   [EIGRP Stub Routing White Paper](https://www.cisco.com/en/US/technologies/tk648/tk365/technologies_white_paper0900aecd8023df6f.html)。

### CiscoLive (動画・スライド)
*   [Introduction to EIGRP - BRKENT-1187](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/BRKENT-1187.pdf) - EIGRPの基礎と概要を解説
*   [EIGRP Operations: The Usual Suspects - BRKENT-2050](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/BRKENT-2050.pdf) - EIGRPの動作原理やトラブルシューティングを解説。

### テクニカルドキュメント・設定例
*   [Preventing Stuck-in-Active (SIA) using Summarization and Stub](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13669-1.html)。
*   [Configuring EIGRP Leak Maps with Summary Routes](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book/ire-eigrp-stub-rtg.html)。

---

## 📝 補足
- この学習メモは、CCIE EIラボ試験において「論理的に正しいがスケールしないネットワーク」を「堅牢で最適化されたエンタープライズインフラ」へと昇華させるための技術的指針を網羅しています。特に集約とStubによるQuery境界の構築は、合格のための必須スキルです。


