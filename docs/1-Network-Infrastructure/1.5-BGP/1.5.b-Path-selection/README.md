---
layout: default
title: 1.5.b-Path-selection
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.5.b Path selection

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 BGP トピックの1つである **BGP パス選定メカニズム (Path Selection)** について、属性（Attributes）、ベストパス選定アルゴリズム（Best Path Selection Algorithm）、およびマルチパス負荷分散（Load Balancing）の観点から Cisco IOS-XE 17.x の実装基準に完全準拠して詳細に解説します。

---

## 📘 概要

BGP（Border Gateway Protocol）は、単なる最小ホップ数やリンク帯域幅で経路を決定するプロトコルではなく、多様なパス属性（Path Attributes）をベースにした **ポリシー主導型パス選定エンジン（Policy-Based Routing Engine）** です。

単一のプレフィックスに対して複数のネクストホップや送信経路が存在する場合、BGP プロセスは内部の厳格な 13 段階のベストパス判定ルール（Best Path Selection Algorithm）を順番に適用し、最終的に単一のベストパス（`*>` マーク）を決定してルータの **RIB (Routing Information Base / IP Routing Table)** および **FIB (Forwarding Information Base)** へ転送・掲載します。

また、デフォルトでは単一のベストパスのみが適用されますが、**BGP Multipath（マルチパス負荷分散）** 機能を有効化することで、同一または異種の BGP ピア経由で複数パスを同時に RIB に挿入し、ECMP（Equal-Cost Multi-Path）や Unequal-Cost 負荷分散（DMZ Link Bandwidth 等）を実現することが可能です。

### 主な利用目的と適用シーン
1. **AS 外部トラフィック（Outbound）の精密制御:** `Local Preference` や `Weight` を操作し、複数存在する ISP 出口の中から特定回線へトラフィックを誘導する。
2. **AS 内部トラフィック（Inbound）の受動的誘導:** `AS_PATH Prepending` や `MED (Multi-Exit Discriminator)`、`Community` を対向 AS へアドバタイズし、自網へ流入するトラフィック経路を制御する。
3. **複数 ISP 回線でのトラフィック分散 (Load Balancing):** `maximum-paths` や `bgp bestpath as-path multipath-relax` を適用し、複数マルチホーム回線で同時にデータ転送を行って広帯域化を図る。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 13 段階の絶対的比較アルゴリズム（上から順番に比較し、最初に差異が生じた属性で判定終了）。属性操作による柔軟な双方向トラフィックエンジニアリングが可能。 |
| **主な属性** | Weight（Cisco独自・ローカル限定）、Local Preference（iBGP内伝搬）、Locally Originated、AS_PATH、Origin Code、MED（隣接AS間伝搬）、Peer Type (eBGP > iBGP)、IGP Cost to Next-Hop 等。 |
| **メリット** | 単純な物理メトリックに依存せず、回線コスト・契約帯域・地理的遅延・障害迂回ポリシーに応じた高度なパス制御が可能。 |
| **デメリット** | 属性値の矛盾や調整ミスにより、Sub-optimal Routing（非最適迂回）、AS 間ルーティングループ、トラフィックの偏りが発生しやすい。 |
| **マルチパス (Load Balancing)** | デフォルトは単一パス (`maximum-paths 1`)。`maximum-paths [ibgp] <1-64>` により同等条件の複数パスを RIB に挿入可能。 |
| **設計上の注意点** | iBGP パス選定ではネクストホップまでの IGP コスト（OSPF/EIGRP）が決定打となるため、アンダーレイ IGP のメトリック設計と密接に連携する必要がある。 |

---

## 🏗 動作原理

BGP ベストパス選定プロセスは、複数のピアから同一プレフィックスを受信した際に起動します。

```text
[ Incoming BGP Updates ]
  │  (Prefix: 172.16.1.0/24 from Peer A, Peer B, Peer C)
  ▼
┌─────────────────────────────────────────────────────────┐
│ 1. Check Next-Hop Reachability (RIB Lookup)             │
│    └─► Invalid Next-Hop? ──► REJECT (Cannot be bestpath)│
└─────────────────────────┬───────────────────────────────┘
                          │ Valid Next-Hop
                          ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Evaluate 13-Step Best Path Algorithm                 │
│    ├─ Step 1: Highest Weight (Cisco Local)             │
│    ├─ Step 2: Highest Local Preference                 │
│    ├─ Step 3: Locally Originated (network/redistribute)│
│    ├─ Step 4: Shortest AS_PATH                          │
│    ├─ Step 5: Lowest Origin Code (i < e < ?)            │
│    ├─ Step 6: Lowest MED (Multi-Exit Discriminator)     │
│    ├─ Step 7: eBGP over iBGP                            │
│    ├─ Step 8: Lowest IGP Metric to BGP Next-Hop         │
│    ├─ Step 9: Multipath Check (If enabled)             │
│    ├─ Step 10: Oldest eBGP Path                         │
│    ├─ Step 11: Lowest BGP Router ID                     │
│    ├─ Step 12: Minimum Cluster List Length (RR)        │
│    └─ Step 13: Lowest Neighbor IP Address               │
└─────────────────────────┬───────────────────────────────┘
                          │ Selected Best Path (*>)
                          ▼
┌─────────────────────────────────────────────────────────┐
│ 3. RIB / FIB Insertion & BGP Advertisement to Peers     │
└─────────────────────────────────────────────────────────┘
```

---

## ⚙ 動作シーケンス

### BGP ベストパス判定 13 段階の完全順序（Cisco IOS-XE 準拠）

1. **Next-Hop の可達性チェック (Prerequisite):**
   IP ルーティングテーブル（RIB）上で BGP ネクストホップアドレスへの有効なルートが存在しない場合、該当パスは即座に除外されます（`*` マークすら付かないか、`inaccessible` と表示）。
2. **Step 1: Highest Weight (範囲: 0〜65535, Cisco 独自):**
   自ルータ内部でのみ有効（他ルータへ一切伝搬しない）。ローカル生成ルート（`network` / `aggregate`）はデフォルト `32768`、受信用ピア経由はデフォルト `0`。値が**大きい方**が優先。
3. **Step 2: Highest Local Preference (範囲: 0〜4294967295):**
   iBGP メッシュ内（同一 AS 内）で完全伝搬する属性。デフォルト値は `100`。値が**大きい方**が優先。
4. **Step 3: Locally Originated (自ルータ生成ルート):**
   自ルータ上で生成されたルート（`network` コマンド、`redistribute` コマンド、`aggregate-address`）を、他ピアから学習したルートより優先。同等の場合、`aggregate-address` ➔ `network` ➔ `redistribute` の順で優先。
5. **Step 4: Shortest AS_PATH (最小 AS 長):**
   `AS_PATH` に含まれる AS 番号の要素数が**最も少ないパス**が優先（`bgp bestpath as-path ignore` で比較無効化可能）。AS_SET は 1 つの AS としてカウント。
6. **Step 5: Lowest Origin Code (最小オリジンコード):**
   `i` (IGP: `network` コマンド等) ➔ `e` (EGP: 歴史的遺物) ➔ `?` (Incomplete: `redistribute` 等) の順で優先 (`i < e < ?`)。
7. **Step 6: Lowest MED (Multi-Exit Discriminator / Metric, 範囲: 0〜4294967295):**
   同一の隣接 AS から複数の境界ルータ経由でアドバタイズされた場合、値が**最も小さい方**が優先。通常、異なる隣接 AS 間では比較しないが、`bgp always-compare-med` を有効化すると異種 AS 間でも比較する。
8. **Step 7: eBGP Path over iBGP Path:**
   eBGP ピアから学習したパスを、iBGP ピアから学習したパスより優先（Confederation eBGP は iBGP と同等扱い）。
9. **Step 8: Lowest IGP Metric to BGP Next-Hop:**
   BGP ネクストホップアドレスへ到達するための内部 IGP（OSPF、EIGRP、Static等）コストが**最も小さいパス**が優先。
10. **Step 9: Multipath Check (マルチパス評価):**
    `maximum-paths` が設定されており、ここまでの条件（Step 1〜8）が完全に一致する複数パスが存在する場合、複数パスを同時にベストパス/等コストマルチパスとして選定。
11. **Step 10: Lowest / Oldest eBGP Path (最古の eBGP パス):**
    フラッピングを抑制するため、最も長時間安定して維持されている eBGP パスを優先（`bgp bestpath compare-routerid` が設定されている場合はこのステップをスキップ）。
12. **Step 11: Lowest BGP Router ID (最小ルータ ID):**
    BGP Router ID（IPアドレス形式）の**数値が最も小さい方**を優先。Route Reflector 環境で `Originator-ID` が付与されている場合は、Router ID の代わりに `Originator-ID` の最小比較を行う。
13. **Step 12: Minimum Cluster List Length (最小クラスタリスト長):**
    Route Reflector（RR）環境で、`Cluster-List` の長さを比較し、通過した RR の数が**最も少ないパス**を優先。
14. **Step 13: Lowest Neighbor IP Address (最小ネイバー IP):**
    `neighbor <IP>` で指定された BGP ピアのソケット IP アドレス値が**最も小さいパス**を選択。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、BGP Path Selection は配点比率が高く、複数の意図的な条件（制約事項）と組み合わせて出題されます。

### 1. 試験で頻出するトラフィック制御要件と属性の選定基準

* **「R1 のみから特定の外部宛てトラフィックを別回線へ出したい」**
  ➔ **`Weight`** を操作（`route-map` 経由でインバウンドに適用）。R1 ローカル限定のため他ルータに影響を与えない。
* **「AS 全体のトラフィック出口を特定ルータ（例: R2）に集約したい」**
  ➔ **`Local Preference`** を操作（R2 の eBGP インバウンドで `set local-preference 200` を適用）。iBGP 経由で AS 内全ルータへ波及。
* **「対向 AS から自網への流入トラフィック（Inbound）を制御したい」**
  ➔ **`AS_PATH Prepending`** （例: `set as-path prepend 65001 65001`）をプライマリ以外の eBGP アウトバウンドに適用して迂回させる。
* **「同一のマルチホーム対向 AS に対し、自網の複数 ABR 間の優先度を伝えたい」**
  ➔ **`MED`** （例: `set metric 50` vs `set metric 100`）を eBGP アウトバウンドに適用。

### 2. ラボ試験での落とし穴・設定ミス

* **iBGP ネクストホップ到達性（`next-hop-self`）の欠落:**
  eBGP から学習したルートを iBGP ピアへ再配布する際、`neighbor <IP> next-hop-self` を入れ忘れると、iBGP ルータ側でネクストホップ（元の eBGP ピア IP）への IGP 経路が存在せず、Step 1（可達性チェック）で不合格となり `*` マークすら付きません。
* **`AS_PATH Prepending` 時のルーティングループ誘発:**
  アウトバウンドで `AS_PATH Prepending` を過剰に行うと、他 AS からのルート受信時に自 AS 番号が含まれて拒否（Loop Prevention）されたり、`allowas-in` / `as-override` と競合して不安定化します。
* **`bgp deterministic-med` vs `bgp always-compare-med` の誤解:**
  * `bgp deterministic-med`: 同一 AS から受信した複数パスの並び順を整列させて MED 比較の決定性を保証（Cisco 推奨・デフォルト有効化を推奨）。
  * `bgp always-compare-med`: **異なる AS** から受信したパス同士であっても MED 値を強制比較させる。

---

## 🛠 設定方法

### 1. Weight によるローカル出入口制御設定 (Inbound Policy)

```bash
# 10.1.12.2 (Peer A) から受信する 172.16.0.0/16 経路の Weight を 50000 に引き上げ
ip prefix-list PL_PREFER_PEER_A permit 172.16.0.0/16
!
route-map RM_WEIGHT_IN permit 10
 match ip address prefix-list PL_PREFER_PEER_A
 set weight 50000
!
route-map RM_WEIGHT_IN permit 20
!
router bgp 65001
 neighbor 10.1.12.2 route-map RM_WEIGHT_IN in
```

### 2. Local Preference による AS 全体出口制御設定 (Inbound Policy)

```bash
# eBGP ピア 192.168.12.2 から受信するすべての経路の Local-Preference を 200 に変更
route-map RM_LOCAL_PREF_IN permit 10
 set local-preference 200
!
router bgp 65001
 neighbor 192.168.12.2 route-map RM_LOCAL_PREF_IN in
```

### 3. AS_PATH Prepending によるインバウンドトラフィック誘導 (Outbound Policy)

```bash
# バックアップ回線 (192.168.23.2) から送出する経路の AS_PATH に自 AS (65001) を 2 回付加
route-map RM_PREPEND_OUT permit 10
 set as-path prepend 65001 65001
!
router bgp 65001
 neighbor 192.168.23.2 route-map RM_PREPEND_OUT out
```

### 4. MED (Multi-Exit Discriminator) 調整設定 (Outbound Policy)

```bash
# プライマリ出口ルータで MED を 50、バックアップで 100 に設定してアドバタイズ
route-map RM_MED_PRIMARY permit 10
 set metric 50
!
router bgp 65001
 neighbor 192.168.12.2 route-map RM_MED_PRIMARY out
```

### 5. eBGP / iBGP Multipath (負荷分散) 設定

```bash
# eBGP 2 パス、iBGP 2 パスのマルチパス負荷分散を有効化
router bgp 65001
 maximum-paths 2
 maximum-paths ibgp 2
 bgp bestpath as-path multipath-relax
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブル全体および特定プレフィックスのベストパス判定結果確認** | <code>show ip bgp</code> / <code>show ip bgp <PREFIX/MASK></code> |
| **特定プレフィックスの 13 段階比較プロセス・棄絶理由（`Not best path` 原因）の確認** | <code>show ip bgp <PREFIX/MASK></code> （詳細表示） |
| **BGP ピア一覧、AS番号、受信/送信 Prefix 数、State 確認** | <code>show ip bgp summary</code> |
| **特定ピアへ適用されているインバウンド/アウトバウンドポリシーと属性変更確認** | <code>show ip bgp neighbors <IP> advertised-routes</code><br><code>show ip bgp neighbors <IP> routes</code> |
| **BGP ベストパス選定イベントのリアルタイムデバッグ** | <code>debug ip bgp updates</code><br><code>debug ip bgp events</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **BGP テーブル上にルートが存在するが、`*>` (Valid/Best) マークが付かない。** | 1. ネクストホップ IP への IGP 到達性がない。<br>2. `rib-failure`（AD 値が低い別プロトコル経路がすでに RIB に存在）。 | `show ip bgp <PREFIX>`<br>`show ip route <NEXT_HOP>` | 1. `neighbor <IP> next-hop-self` を設定するか、IGP でネクストホップ宛の可達性を確保する。<br>2. 必要に応じて BGP または競合プロトコルの AD 値を変更する。 |
| **Local-Preference を変更したのに、他ルータへ反映されない。** | `Local-Preference` を eBGP ピア宛のアウトバウンドで設定している（eBGP ピアへは送信されない仕様）。 | `show ip bgp neighbors <IP> advertised-routes` | eBGP からの受信時（Inbound）または iBGP ピアへのアドバタイズ時（Outbound）に適用する。 |
| **MED 値を変更したのに、異なる AS から受信したルート同士で比較されない。** | 異なる隣接 AS からのルートであるため、デフォルトで Step 6 (MED) 比較がスキップされている。 | `show ip bgp <PREFIX>` | `router bgp` 配下で `bgp always-compare-med` を投入して異種 AS 間比較を強制有効化する。 |
| **`maximum-paths` を設定したのに負荷分散されない。** | Step 1〜8（Weight, LocPref, AS_PATH, Origin, MED, Peer Type, IGP Metric）が完全一致していない。 | `show ip bgp <PREFIX>` | 属性操作または `bgp bestpath as-path multipath-relax` を追加して不一致属性（AS_PATH 内容等）を弛緩させる。 |

---

## ⚠ 制限事項

1. **Weight 属性の局所性:**
   Weight は Cisco 固有の機能であり、アドバタイズを行ういかなる BGP UPDATE パケット内にも含まれません（自ルータを離れた瞬間に消失します）。
2. **MED の比較条件:**
   `bgp always-compare-med` が未設定の場合、隣接 AS が異なるパス同士では MED 比較手順が完全にバイパスされます。

---

## 🔄 他技術との関連

* **IGP (OSPF / EIGRP / IS-IS):**
  BGP ベストパス選定の Step 8 では、BGP ネクストホップへの到達コスト（IGP Metric）がそのまま比較基準となります。IGP コストが変化すると BGP ベストパスも連動して切り替わります。
* **MPLS L3VPN / SRv6:**
  PE ルータ間での BGP パス選定結果に基づき、MPLS ラベル Swapped Path (LSP) や SRv6 Segment List が転送テーブル（FIB）に構成されます。

---

## 🧩 比較表

### 主要 BGP パス属性の徹底比較

| 属性名 | 伝搬範囲 | デフォルト値 | 優位判定 | 主な用途 |
| :--- | :--- | :--- | :--- | :--- |
| **Weight** | 自ルータ内部のみ (0 hop) | 0 (受信) / 32768 (ローカル生成) | **大きい方** | 自ルータ専用の出入口制御 |
| **Local Preference** | AS 内部のみ (iBGP 全域) | 100 | **大きい方** | AS 全体の送信トラフィック出口一元制御 |
| **AS_PATH** | AS 間 (eBGP / iBGP 全域) | 自 AS 番号のリスト | **短い方** | ループ防止 & インバウンド/アウトバウンド制御 |
| **Origin** | ドメイン全体 | i / e / ? | **`i < e < ?`** | 生成元の信頼性判定 |
| **MED** | 隣接 AS 間のみ (1 hop) | 0 | **小さい方** | 隣接 AS から自網への入口指定 |

---

## 💡 ベストプラクティス

1. **`bgp deterministic-med` の常時有効化:**
   BGP テーブル内のパス並び順による MED 評価の不定性を排除するため、全ルータで `bgp deterministic-med` を有効化する。
2. **`Local Preference` による組織的アウトバウンド制御:**
   個別の Weight 設定に頼らず、AS 全体のポリシー整合性を保つために iBGP 全域に波及する `Local Preference` を基本ポリシーとして設計する。
3. **`bgp bestpath as-path multipath-relax` の活用:**
   マルチホーム環境で異種 AS 経由の等コストマルチパスを実現する際は、`multipath-relax` を明示的にバインドする。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI Practical Lab 試験レベルの完全設定シナリオ 10 選です。

### Scenario 1: Weight 属性による特定ルータ限定出口制御
* **要件:** R1 において、宛先 `10.100.0.0/16` への通信を eBGP ピア R2 (10.1.12.2) 経由へ誘導するため、Weight `40000` をバインドせよ。

**【R1】**
```bash
ip prefix-list PL_10_100 permit 10.100.0.0/16
!
route-map RM_SET_WEIGHT permit 10
 match ip address prefix-list PL_10_100
 set weight 40000
!
route-map RM_SET_WEIGHT permit 20
!
router bgp 65001
 neighbor 10.1.12.2 route-map RM_SET_WEIGHT in
```

**【検証方法】**
```bash
R1# show ip bgp 10.100.0.0/16
# Weight 40000 が付与され、10.1.12.2 がベストパス (*>) になっていることを確認
```

---

### Scenario 2: Local Preference による AS 全体のアウトバウンド制御
* **要件:** R2 の eBGP ピア (192.168.24.4) から受信するすべてのプレフィックスの Local-Preference を `250` に引き上げ、AS 65001 全体のプライマリ出口とせよ。

**【R2】**
```bash
route-map RM_SET_LOCPREF permit 10
 set local-preference 250
!
router bgp 65001
 neighbor 192.168.24.4 route-map RM_SET_LOCPREF in
```

**【検証方法】**
```bash
R1# show ip bgp
# R1 側の BGP テーブルでも Local-Preference 250 の経路がベストパスとして選定されていることを確認
```

---

### Scenario 3: AS_PATH Prepending によるインバウンドトラフィック迂回制御
* **要件:** R3 から ISP 宛てにアドバタイズする自社プレフィックス `172.16.0.0/16` に対し、AS 番号 (65001) を 2 回追加付加（Prepend）してバックアップ回線化せよ。

**【R3】**
```bash
ip prefix-list PL_MY_PREFIX permit 172.16.0.0/16
!
route-map RM_PREPEND_OUT permit 10
 match ip address prefix-list PL_MY_PREFIX
 set as-path prepend 65001 65001
!
route-map RM_PREPEND_OUT permit 20
!
router bgp 65001
 neighbor 192.168.35.5 route-map RM_PREPEND_OUT out
```

**【検証方法】**
```bash
R3# show ip bgp neighbors 192.168.35.5 advertised-routes
# Path に '65001 65001 65001 i' と 3 重表示されることを確認
```

---

### Scenario 4: MED によるマルチホーム対向 AS への入口誘導
* **要件:** R1 (プライマリ) から対向 AS 65002 へ向けてアドバタイズするルートの MED を `100`、R2 (セカンダリ) の MED を `200` に設定せよ。

**【R1】**
```bash
route-map RM_MED_PRIMARY permit 10
 set metric 100
!
router bgp 65001
 neighbor 192.168.14.4 route-map RM_MED_PRIMARY out
```

**【R2】**
```bash
route-map RM_MED_SECONDARY permit 10
 set metric 200
!
router bgp 65001
 neighbor 192.168.24.4 route-map RM_MED_SECONDARY out
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 192.168.14.4 advertised-routes
```

---

### Scenario 5: 異種 AS 間 MED 強制比較 (`always-compare-med`)
* **要件:** 異なる ISP AS (AS 65100 と AS 65200) から学習したルートであっても MED 値を絶対比較するよう構成せよ。

**【R1】**
```bash
router bgp 65001
 bgp always-compare-med
 bgp deterministic-med
```

**【検証方法】**
```bash
R1# show ip bgp 10.200.0.0/16
# 異種 AS 出自であっても MED 値が低い方がベストパスとして選ばれることを確認
```

---

### Scenario 6: eBGP Multipath (Equal-Cost Load Balancing)
* **要件:** 2 つの同等 eBGP ピア経由でトラフィックを等コスト負荷分散せよ。

**【R1】**
```bash
router bgp 65001
 maximum-paths 2
```

**【検証方法】**
```bash
R1# show ip bgp 10.50.0.0/16
# 2 パス双方に 'm' (multipath) またはベストマークが付与され、`show ip route` で 2 つのネクストホップが挿入されていることを確認
```

---

### Scenario 7: 異種 AS 間 eBGP Multipath (`multipath-relax`)
* **要件:** 異なる AS 番号を持つ 2 つの eBGP ピア (AS 65101 と AS 65102) 経由のパスに対し、AS_PATH 長が同一であればマルチパス化せよ。

**【R1】**
```bash
router bgp 65001
 bgp bestpath as-path multipath-relax
 maximum-paths 2
```

**【検証方法】**
```bash
R1# show ip route bgp
# 異なる AS 番号を経由する 2 つのデフォルトルート/プレフィックスが RIB に同時掲載されていることを確認
```

---

### Scenario 8: iBGP Multipath (iBGP 負荷分散)
* **要件:** AS 内部の 2 台の iBGP ルータ経由で、IGP コストが等しい 2 つのパスを iBGP 負荷分散せよ。

**【R1】**
```bash
router bgp 65001
 maximum-paths ibgp 2
```

**【検証方法】**
```bash
R1# show ip route bgp
```

---

### Scenario 9: BGP DMZ Link Bandwidth に基づく Unequal-Cost 負荷分散
* **要件:** 回線帯域幅の異なる 2 つの eBGP リンク（100Mbps と 200Mbps）間で、帯域比率に応じた Unequal-Cost 負荷分散を設定せよ。

**【R1】**
```bash
router bgp 65001
 bgp dmzlink-bw
 maximum-paths 2
 neighbor 10.1.12.2 dmzlink-bw
 neighbor 10.1.13.3 dmzlink-bw
```

**【検証方法】**
```bash
R1# show ip bgp 10.80.0.0/16
# Extended Community として DMZ Link Bandwidth 値が付与され、比率分散されていることを確認
```

---

### Scenario 10: Bestpath AS-Path Ignore 設定
* **要件:** トラフィック検証のため、AS_PATH の長さを完全に無視して選定比較を行わせよ。

**【R1】**
```bash
router bgp 65001
 bgp bestpath as-path ignore
```

**【検証方法】**
```bash
R1# show ip bgp 10.90.0.0/16
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解 / トラブルシューティング】iBGP ベストパス選定の不成立原因
**問題:** 
R1 の BGP テーブルにおいて、対向ルータから受信したプレフィックス `192.168.100.0/24` の横に `*` (Valid) マークすら付かず、RIB に掲載されません。`show ip bgp 192.168.100.0` の出力は以下の通りです。原因と修復コマンドを述べてください。
```text
BGP routing table entry for 192.168.100.0/24, version 0
Paths: (1 available, no bestpath)
  Not advertised to any peer
  65002
    10.1.45.4 (inaccessible) from 10.1.12.2 (10.1.2.2)
      Origin IGP, metric 0, localpref 100, valid, internal
```

**解答・解説:**
* **原因:** 
  ネクストホップ IP `10.1.45.4` 横に `(inaccessible)` と出力されている通り、R1 の IGP ルーティングテーブル上に `10.1.45.4` への可達性（ルート）が存在しません。BGP ベストパス選定アルゴリズムの前提条件（Step 0: Next-Hop Reachability）を満たしていないため、ベストパス評価自体が行われていません。
* **修復コマンド:**
  iBGP ピアリングを行っているルータ (10.1.12.2) 側で `neighbor` に対し `next-hop-self` をバインドし、ネクストホップを R1 から到達可能な自身の Loopback/対向 IP へ変更します。
  ```bash
  router bgp 65001
   neighbor 10.1.12.1 next-hop-self
  ```

---

### 2. 【Design】Weight と Local Preference の動作範囲比較
**問題:** 
AS 65001 内の 4 台のルータ（R1, R2, R3, R4）で構成される網において、「R1 のみ」外部宛てトラフィックを ISP-A 経由に固定し、他の R2/R3/R4 は従来のデフォルト経路を使用させたい場合、`Weight` と `Local Preference` のどちらを使用すべきですか？技術的根拠とともに説明してください。

**解答・解説:**
* **回答:** **`Weight` 属性を使用すべきです。**
* **技術的根拠:**
  `Weight` は Cisco 独自の属性であり、設定したルータ内部でのみ有効で、他ルータ（iBGP ピア）へ一切伝搬されません。そのため R1 上で `Weight` を変更しても R2/R3/R4 のパス選定には何の影響も与えません。
  一方 `Local Preference` は iBGP ピアを通じて AS 内部全体へ伝搬・共有されるため、R1 で `Local Preference` を変更すると R2/R3/R4 のベストパス選定まで変化してしまい、「R1 のみ変更する」という要件を満たせなくなります。

---

## 🔗 参考リソース

* [Cisco Systems: BGP Best Path Selection Algorithm](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)
* [Cisco Systems: BGP Command Reference](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book.html)
* [Cisco Live: BRKRST-2337 - Advanced BGP Path Manipulation and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **BGP ベストパス選定順序の暗記語ろ義:**
  * **W**e **L**ove **L**emonade **A**nd **O**ranges, **M**uch **M**ore **I**n **M**ay!
  * **W**eight ➔ **L**ocal Pref ➔ **L**ocal Originated ➔ **A**S_PATH ➔ **O**rigin ➔ **M**ED ➔ **M**atch Peer (eBGP > iBGP) ➔ **I**GP Cost ➔ **M**ultipath ...
---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates (Deep Dive into Decision Process)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
*   [BRKRST-3320: Troubleshooting BGP Path Selection](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### Configurationガイド
*   [BGP Best Path Selection Algorithm - Official Documentation](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)
*   [Configuring BGP Path Attributes (Cisco IOS XE)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)

### テクニカルドキュメント・設定例
*   [BGP Case Studies: Influence Path Selection with Attributes](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)
*   [BGP Load Balancing (Cisco Support)](https://www.cisco.com/c/ja_jp/support/docs/ip/border-gateway-protocol-bgp/13751-23.html)

---

## 📝 補足
- この学習メモは、BGPのパス選定プロセスを詳細なアルゴリズムのステップから、実戦的なトラブルシューティング、そして最新の負荷分散技術まで網羅しています。特に **「どの属性がどの範囲（ローカルかAS全体か）に影響を与えるか」** を理解し、適切なタイミングでルートマップを適用するスキルが、CCIE EIラボ試験合格の鍵となります。


