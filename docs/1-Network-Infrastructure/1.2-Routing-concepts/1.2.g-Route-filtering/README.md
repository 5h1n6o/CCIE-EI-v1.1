---
layout: default
title: 1.2.g-Route-filtering
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 7
---

# 1.2.g Route filtering with BGP, EIGRP, OSPF, and static

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるトラフィック制御・経路伝播制御の最重要項目である **Route filtering with BGP, EIGRP, OSPF, and static（動的・静的プロトコルにおけるルートフィルタリング）** について、Cisco IOS-XE 17.x（Catalyst 9000、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

ルートフィルタリング（Route Filtering）とは、ダイナミックルーティングプロトコル（BGP, EIGRP, OSPF）の制御プレーン（Control Plane）においてアドバタイズまたは受信されるプレフィックス（IP経路情報）を、Access Control List (ACL)、Prefix-list、AS-Path Access List、Community-list、Route-map などの条件文を用いて意図的に識別・選別・遮断（Filter）する技術です。

### 主な利用目的と適用場面
1. **不必要な経路伝播の抑制（帯域・リソース節約）:** 広域網（WAN/DMVPN/SD-WAN）やデータセンター接続において、ローカルで不要な細分化されたプレフィックスを受信・広報させず、ルータのメモリ（RIB/FIB）およびCPU負荷を削減する。
2. **ルーティングループの防止:** 複数の再配送ポイント（Multi-homed Redistribution Points）が存在する環境で、プロトコル間を相互に行き来する逆流ルート（Sub-optimal routingやRouting Loop）を特定のプレフィックスに対して遮断・タグ付け・フィルタリングする。
3. **セキュリティとトラフィック制御:** 自組織のプライベートアドレス（RFC 1918）や未割り当てアドレス（Bogon/Martianプレフィックス）が外部自治システム（ISP/eBGPピア）へ流出するのを防ぎ、同時に不正なデフォルトルートや特定のトラフィック誘引ルートの流入をブロックする。
4. **マルチテナント・VRF境界での非対称制御:** 共通サービスVRFや企業統合時のVPC/VRF境界において、公開可能なプレフィックスのみを局所的に選択開示・制御する。

---

## 🔑 要点

| 項目 | BGP | EIGRP | OSPF | Static Routing |
| :--- | :--- | :--- | :--- | :--- |
| **フィルタリング動作層** | 制御プレーン（BGP Updateメッセージ送受信時） | 制御プレーン（EIGRP Updateメッセージ送受信時） | 制御プレーン/データベース（LSA生成・透過およびRIB挿入時） | 制御プレーン（RIB挿入時および他プロトコルへの再配送時） |
| **主な制御手法** | Prefix-list, Distribute-list, Route-map, AS-path filter, Community-filter, ORF | Distribute-list (ACL/Prefix-list/Route-map), Offset-list, Summary Leak-map | Distribute-list in/out, `area filter-list`, `area range not-advertise`, `summary-address not-advertise` | Null0化, AD 255 (Inaccessible), Redistribution Route-map |
| **トポロジーデータベースへの影響** | BGP Tableから不採用・非非広報化 | 該当プレフィックスがTopology Tableから削除/拒否される | **`distribute-list in` はLSDBにLSAを維持したままRIB挿入のみブロック。** エリア内 `out` フィルタは不可 | ルーティングテーブル（RIB）への登録自体を拒否、またはブラックホール化 |
| **エリア/ドメイン全域への影響** | ピア単位（Inbound/Outbound）で局所的に作用 | ネイバー単位またはインターフェイス単位で局所的に作用 | エリア境界（ABR）でのLSA Type-3制御やAS境界（ASBR）でのLSA Type-5制御が必須 | ローカル機器のRIBおよび再配送先ドメインにのみ影響 |
| **設計上の注意点** | Outbound Route Filtering (ORF) 活用により対向のUpdate送信自体を抑制可能 | ディスタンスベクターのためインターフェイス単位の `distribute-list out` が直感的に動作 | リンクステートの整合性維持のため、**エリア内部の個々のルータで `distribute-list out` は機能しない（再配送時を除く）** | Null0へのディスカードルート作成時は、サマリー範囲内の生存サブネットの有無を注意深く設計 |

---

## 🏗 動作原理

各プロトコルのアーキテクチャ特性（Distance Vector vs Link-State vs Path-Vector）によって、フィルタリングが制御プレーンおよびデータベースに与える影響の仕組みが根本的に異なります。

```
【 Distance Vector / Path Vector (EIGRP / BGP) の動作原理 】
   [ Router A ] ── (Update Packet) ──► [ Distribute-list / Route-map Filter ] ──► [ Router B RIB / Topology ]
   * 送信側(Outbound)または受信側(Inbound)で直接パケット内のプレフィックス情報を遮断。
   * トポロジーデータベース自体に該当プレフィックスが一切入らない。

【 Link-State (OSPF) の動作原理と限界 】
   [ Neighbor A ] ── (LSA Type-1/2/3/5) ──► [ OSPF LSDB (全員同一のデータベースを保持) ]
                                                       │
                                                       ▼  (SPF計算処理)
                                           [ Distribute-list in ] ◄──【ここでRIB挿入のみ阻止!】
                                                       │
                                                       ▼
                                                 [ IP RIB (Routing Table) ]

   ※ 注意: OSPFでは同一エリア内のルータ群は「全く同じLSDB」を共有しなければならないため、
     エリア内部の個々の物理インターフェイスで LSA の送出を物理的にフィルタリング(out)することは不可能です。
     例外として、ABRでの Type-3 L2/L3 変換 (`area filter-list`) や、ASBRでの再配送時 (`distribute-list out`) のみLSA生成を制御できます。
```

---

## ⚙ 動作シーケンス

パケットおよび制御メッセージがルータ内部で処理される順番（Evaluated Sequence）を示します。

```
[ 制御プレーンパケット/Update/LSA の受信 ]
       │
       ▼
[ プロトコル受信処理 (BGP / EIGRP / OSPF) ]
       │
       ├──►【 BGP の場合 】
       │      1. Inbound Route-map / Prefix-list / Distribute-list 評価
       │      2. AS-Path Filter / Community Filter 評価
       │      3. BGP Table (LocPrf/Weight計算) ➔ BGP Bestpath 選定 ➔ IP RIB へ挿入
       │
       ├──►【 EIGRP の場合 】
       │      1. Inbound Distribute-list (Interface指定/Global) 評価
       │      2. 許可された場合のみ EIGRP Topology Table に格納
       │      3. DUAL計算 (Feasible Successor選定) ➔ IP RIB へ挿入
       │
       └──►【 OSPF の場合 】
              1. LSA パケットを受信 ➔ 無条件で OSPF LSDB に格納 (同一エリアでのLSA伝搬は止めない)
              2. SPF (Shortest Path First) 計算の実行
              3. 【 Distribute-list in 評価 】
                   ├─ Permit ➔ IP RIB (Routing Table) にルートを挿入
                   └─ Deny   ➔ LSDB には残るが、IP RIB への挿入をブロック (転送不能化)
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI実技試験（Practical Lab）において、ルートフィルタリングは単独で問われるだけでなく、**「再配送（Redistribution）」「BGP パスアトリビュート操作」「OSPFエリア設計」「EIGRP Stub」** と複雑に組み合わせて出題されます。

### 1. Blueprintで最も重要なポイントと出題パターンの分析
* **OSPF における `distribute-list` の適用限界の理解:**
  * 「SW1 において、特定VLANのOSPFルートをルーティングテーブルに載せないように設定しなさい。ただし、隣接するSW2へはそのルートが正常に伝搬するようにしなさい」
  * **対策:** SW1 で `distribute-list <ACL/PREFIX> in` を適用します。LSDB には LSA が保持されるため SW2 には伝搬しますが、SW1 自身の RIB 挿入のみがブロックされます。
  * **絶対的なNG設定:** OSPF のインターフェイスに対して `distribute-list out` を設定しても、再配送（Redistribute）ルート以外には一切効果がありません。
* **Prefix-list の `ge` (Greater than or Equal) と `le` (Less than or Equal) の厳格な計算方法:**
  * 条件例: `10.0.0.0/8` の範囲内で、サブネットマスクが `/16` から `/24` までのプレフィックスのみを許可せよ。
  * 正解構文: `ip prefix-list FILTER permit 10.0.0.0/8 ge 16 le 24`
  * 必須ルール: `Len < ge-value <= le-value <= 32` （Lenはベースプレフィックス長）。この大小関係を崩すと構文エラーになります。
* **EIGRP の Distribute-list と Route-map の組み合わせ:**
  * EIGRP では `distribute-list route-map <NAME> in/out <INT>` がサポートされています。Route-map 内で `match ip address prefix-list` や `match metric`、`match tag` を指定してフィルタリングを多角的にコントロールします。
* **BGP Outbound Route Filtering (ORF: RFC 5291):**
  * 「R1 から R2 への BGP Update 送信において、R2 側で必要なフィルタ設定を定義し、R1 側が送信段階で不必要な Update パケットを送ってこないように自動交渉（ORF）させなさい」
  * **対策:** R2 側で `neighbor <R1> capability orf prefix-list receive`、R1 側で `send` を設定し、R2 の Inbound Prefix-list を R1 へ動的プッシュさせます。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における、実践的な各プロトコル配下のフィルタリングCLIコンフィグレーション例です。

### 1. BGP での各種フィルタリング設定

```bash
# [1-1. Prefix-list および AS-Path Filter を用いた eBGP フィルタリング]
ip prefix-list PEER-IN permit 172.16.0.0/12 le 24
ip prefix-list PEER-IN deny 0.0.0.0/0 le 32

ip as-path access-list 10 permit ^6500[0-9]$
ip as-path access-list 20 deny _65535_

router bgp 64512
 bgp log-neighbor-changes
 neighbor 192.168.12.2 remote-as 65001
 neighbor 192.168.12.2 prefix-list PEER-IN in
 neighbor 192.168.12.2 filter-list 10 in
exit

# [1-2. BGP Outbound Route Filtering (ORF) の構成]
# R2 (Receiver/Inbound Filter 側)
router bgp 64512
 neighbor 192.168.12.1 remote-as 64511
 neighbor 192.168.12.1 capability orf prefix-list receive
 neighbor 192.168.12.1 prefix-list ORF-FILTER in
exit
ip prefix-list ORF-FILTER deny 10.99.0.0/16 le 32
ip prefix-list ORF-FILTER permit 0.0.0.0/0 ge 0

# R1 (Sender/Outbound Push 受信側)
router bgp 64511
 neighbor 192.168.12.2 remote-as 64512
 neighbor 192.168.12.2 capability orf prefix-list send
exit
```

### 2. EIGRP (Named Mode) での Distribute-list フィルタリング設定

```bash
router eigrp CCIE-DOMAIN
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   # 特定のインターフェイスから送出されるアップデートを限定
   topology base
    distribute-list prefix FILTER-OUT out
   exit-af-interface
  !
  topology base
   # 全インターフェイス共通の Inbound フィルタ
   distribute-list prefix FILTER-IN in
  exit-topology base
 exit-address-family
exit

ip prefix-list FILTER-IN deny 192.168.99.0/24
ip prefix-list FILTER-IN permit 0.0.0.0/0 ge 0

ip prefix-list FILTER-OUT permit 10.0.0.0/8 le 24
```

### 3. OSPF (v2/v3) での Area Filter-list および Distribute-list 設定

```bash
# [3-1. ABR における Area Filter-list (Type-3 LSA フィルタリング)]
router ospf 1
 router-id 1.1.1.1
 # Area 1 から Area 0 への Type-3 LSA 進入をブロック
 area 1 filter-list prefix BLOCK-AREA1-ROUTES in
exit

ip prefix-list BLOCK-AREA1-ROUTES deny 10.1.50.0/24
ip prefix-list BLOCK-AREA1-ROUTES permit 0.0.0.0/0 ge 0

# [3-2. OSPF ローカル RIB 挿入阻止 (distribute-list in)]
router ospf 1
 distribute-list prefix LOCAL-RIB-DENY in
exit

ip prefix-list LOCAL-RIB-DENY deny 172.16.100.0/24
ip prefix-list LOCAL-RIB-DENY permit 0.0.0.0/0 ge 0
```

### 4. Static Routing での フィルタリング手法 (Null0 / AD 255)

```bash
# [4-1. ブラックホールフィルタリング (Null0 へ破棄指定)]
# 不正なトラフィックや、要約範囲内の空きサブネットへの攻撃パケットを破棄
ip route 10.250.0.0 255.255.0.0 Null0 250

# [4-2. ルーティングテーブル非非掲載 (Administrative Distance 255)]
# 経路としては定義するが、AD 255 のため RIB に絶対追加されない (他プロトコル再配送用など)
ip route 192.168.200.0 255.255.255.0 10.1.1.254 255
```

---

## 🔍 検証コマンド

各プロトコルのフィルタリング結果を正確に追跡・確認するための検証コマンド一覧です。

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブルにおける受信・適用・破棄経路の確認** | <code>show ip bgp</code> / <code>show ip bgp neighbors <IP> received-routes</code> |
| **BGP ORF (Outbound Route Filtering) のネゴシエーション状態確認** | <code>show ip bgp neighbors <IP> \| include ORF</code> |
| **EIGRP Topology テーブルと実際に適用されている Distribute-list の確認** | <code>show ip eigrp topology</code> / <code>show ip protocols</code> |
| **OSPF LSDB (LSAの保持状態) と IP RIB (実際に載っているルート) の比較確認** | <code>show ip ospf database</code> vs <code>show ip route ospf</code> |
| **Prefix-list のヒットカウント（hit内部統計）の確認** | <code>show ip prefix-list detail</code> |
| **Route-map のマッチカウント（Match Clauses）のリアルタイム更新確認** | <code>show route-map</code> |
| **BGP / EIGRP のアップデートパケットおよびフィルタ評価デバッグ** | <code>debug ip bgp updates</code> / <code>debug ip eigrp notification</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **OSPF で `distribute-list out` を設定したが、隣接ルータに依然としてルートが伝搬し続けている。** | OSPF は Link-State プロトコルであり、**再配送（Redistribute）ルート以外に対してインターフェイスレベルの `distribute-list out` は機能しない仕様**であるため。 | `show ip protocols`<br>`show run | section router ospf` | ABR であれば `area filter-list` または `area range not-advertise` を使用する。ローカルルータでのみ非表示にしたい場合は対象ルータ側で `distribute-list in` を適用する。 |
| **BGP で `neighbor received-routes` コマンドがエラーになり、受信ルートが確認できない。** | 対向ルータとの BGP セッションで **Soft Reconfiguration が有効化されていない**（または Route RefreshCapablity がネゴシエーションされていない）。 | `show ip bgp neighbors <IP>` | BGP ピア設定配下で `neighbor <IP> soft-reconfiguration inbound` を追加設定するか、`clear ip bgp <IP> soft in` を使用する。 |
| **Prefix-list を作成して適用した途端、すべてのルートが消去（オールブロック）された。** | Prefix-list の末尾には、ACL と同じく **暗黙の拒否（`implicit deny 0.0.0.0/0 le 32`）** が存在するため、明示的な permit 行がないパケットがすべてドロップされた。 | `show ip prefix-list` | フィルタリストの最後に `ip prefix-list <NAME> permit 0.0.0.0/0 ge 0` (IPv4 全許可) を明示的に追加する。 |
| **Prefix-list で `ge` と `le` を指定した際に CLI から構文エラー（`Invalid input`）が返される。** | 指定したパラメータの大小関係が **`Len < ge-value <= le-value <= 32`** のルールを満たしていない（例: `/24` に対して `ge 16` を指定するなど）。 | CLI エラー表示確認 | プレフィックス長（Prefix Length）よりも大きい値の `ge`、および `ge` 以上の値の `le` を正しく指定し直す。 |
| **EIGRP で Distribute-list を適用したが、一部のネイバーで反映されない。** | Named Mode EIGRP において、`topology base` 配下ではなく、誤って別の Address-family やインターフェイスコンテキストの不適切な配下に設定された。 | `show run | section router eigrp` | EIGRP Named Mode のコンフィグ構造を再点検し、`address-family ipv4 unicast autonomous-system <AS>` ➔ `topology base` 直下に正しく配置する。 |

---

## ⚠ 制限事項

### 1. OSPF における LSA フィルタリングのハードウェア/プロトコル限界
*   **同一エリア内（Intra-Area）での LSA Type-1 / Type-2 遮断は不可:**
    OSPF の整合性ルール（RFC 2328）により、同一エリア内部で LSA を個別のルータ間フィルタで削除・遮断することはできません。遮断できるのは「LSA を保持したまま RIB への登録を拒否する (`distribute-list in`)」か、「エリア境界 ABR で Type-3 LSA へ変換する際 (`area filter-list`)」、「ASBR で Type-5 LSA を再配送生成する際 (`distribute-list out`)」に限られます。

### 2. Prefix-list のビット計算制限
*   Prefix-list のマスクマッチングは、必ず連続したサブネットマスク（CIDR表記）に基づいて評価されます。Access Control List (ACL) のようにワイルドカードマスク（例: `0.0.255.255` や奇数・偶数IPアドレスのみの抽出）を用いた **非不連続マスクのフィルタリングは Prefix-list では不可能** です。非不連続なIP抽出が必要な場合は、標準/拡張 ACL を組み合わせて使用する必要があります。

---

## 🔄 他技術との関連

*   **Redistribution（再配送）:** 
    異なるルーティングプロトコル間（例: OSPF ➔ BGP、EIGRP ➔ OSPF）で再配送を行う際、フィルタリングはルーティングループやサブオプティマルルーティング（遠回り経路）を防ぐ「第1防衛線」として必須適用されます。
*   **BGP Path Attribute Manipulation:** 
    Route-map によるフィルタリングプロセスの中で、単に `permit`/`deny` を判定するだけでなく、`set local-preference`、`set metric (MED)`、`set community` などのアトリビュート操作を同時に実行します。
*   **VRF-Lite / EVPN-VXLAN / SD-WAN:** 
    マルチテナント環境において、各 VRF や VPN のインポート/エクスポートルート（Route Target フィルタリング）において、特定コントロールプレーンの通過・遮断制御を実行します。

---

## 🧩 比較表

### 1. Prefix-list vs Access Control List (ACL) によるルートフィルタリング

| 比較要素 | Prefix-List (`ip prefix-list`) | Access Control List (`access-list`) |
| :--- | :--- | :--- |
| **処理パフォーマンス** | **極めて高速** (内部でツリー構造/インデックス化されて処理される) | 順次シーケンシャル評価のため、行数が増えるとパフォーマンスが低下 |
| **サブネットマスク長指定** | **非常に容易かつ明確** (`ge` / `le` キーワードによる直感的なマスク範囲指定) | 拡張ACL (`permit ip <NET> <WILDCARD> <MASK> <WILDCARD>`) を使用する必要があり複雑 |
| **非不連続マスク制御** | **不可** (CIDR形式の連続マスクのみサポート) | **可能** (ワイルドカードマスクによる奇数/偶数IPの抽出等が可能) |
| **シスコ推奨度** | **ルーティング制御における第一選択 (Best Practice)** | 主にデータプレーン(ACL/CoPP/QoS)用。ルート制御では例外時のみ使用 |

### 2. OSPF フィルタリング手法の比較

| 制御コマンド | 実行場所 | 制御対象 | エリア内部LSDBへの影響 |
| :--- | :--- | :--- | :--- |
| **`distribute-list in`** | 任意の OSPF ルータ | 自身の IP RIB (ルーティングテーブル) 挿入 | **なし** (LSDBにはLSAが存在し続ける) |
| **`area filter-list`** | ABR (Area Border Router) | エリア間を通過する Type-3 Summary LSA | **あり** (対向エリアのLSDBからLSAが消滅する) |
| **`area range not-advertise`** | ABR | 要約(Summary)される Type-3 LSA | **あり** (上位エリアへ個別のLSAが生成されなくなる) |
| **`summary-address not-advertise`**| ASBR | 再配送により生成される Type-5/7 External LSA | **あり** (他エリアへ外部LSAが生成されなくなる) |

---

## 💡 ベストプラクティス

1.  **ルーティング制御には ACL ではなく Prefix-list を一律採用する:**
    設定の可読性、メンテナンス性、およびルータの処理パフォーマンス（インデックス化）を考慮し、IP プレフィックスのフィルタリングには `ip prefix-list` を標準として設計します。
2.  **Prefix-list には必ず `seq` (シーケンス番号) を意識し、適切なステップ刻み (例: 10, 20, 30) で定義する:**
    将来の行挿入（例: seq 15）に備え、自動または手動で10刻みのシーケンス番号を持たせて管理します。
3.  **OSPF ではエリア境界（ABR / ASBR）での LSA 抑制を第一に検討する:**
    全ルータの LSDB 整合性とメモリ効率を最大化するため、単なる `distribute-list in` による RIB 隠蔽ではなく、ABR での `area filter-list` や `area range not-advertise` による LSA の根本カットを行います。
4.  **BGP では ORF (Outbound Route Filtering) を積極的に導入する:**
    対向ルータからの不要な Update パケットの送出自体を送信元で阻止し、WAN リンクの帯域と自ルータの CPU 処理を大幅に節約します。

---

## 📝 ラボ学習・設定サンプル例

CCIE EI Practical Lab 実技試験レベルを想定した、省略なしの10の完全コンフィグレーション例です。

### 1. 【Prefix-list】サブネットマスク範囲 (`ge`/`le`) による精密抽出
**【問題】**
R1 において、`10.0.0.0/8` のネットワーク範囲に含まれるプレフィックスのうち、サブネットマスク長が `/20` から `/24` までのルートのみを許可し、それ以外の `10.0.0.0/8` 網内のルート（例: `/8` や `/30`）をすべてブロックする Prefix-list `PFL-SUBNET-CHECK` を作成してください。

**【R1 設定】**
```bash
R1# configure terminal
# シーケンス10で /20 から /24 のマスク長範囲を明示許可
ip prefix-list PFL-SUBNET-CHECK seq 10 permit 10.0.0.0/8 ge 20 le 24
# シーケンス20で 10.0.0.0/8 のそれ以外を明示拒否
ip prefix-list PFL-SUBNET-CHECK seq 20 deny 10.0.0.0/8 le 32
# その他のすべてのIP範囲を許可
ip prefix-list PFL-SUBNET-CHECK seq 30 permit 0.0.0.0/0 ge 0
end
```

**【検証方法】**
```bash
R1# show ip prefix-list detail PFL-SUBNET-CHECK
```

---

### 2. 【BGP】AS-Path Filter (Regular Expression) による特定 AS 由来ルートの遮断
**【問題】**
R1（AS 64512）において、eBGP ピア R2（192.168.12.2）から受信する BGP ルートのうち、**起源自治システム（Origin AS）が AS 65001 であるルート**、および **AS 65500 を通過してきたルート** を拒否し、それ以外のルートを受信するよう設定してください。

**【R1 設定】**
```bash
R1# configure terminal
# Origin AS が 65001 (ASパスの最後末が65001) の正規表現
ip as-path access-list 10 deny _65001$
# AS 65500 を通過 (ASパスの任意の位置に65500が存在) の正規表現
ip as-path access-list 10 deny _65500_
# それ以外のすべてのASパスを許可
ip as-path access-list 10 permit .*

router bgp 64512
 neighbor 192.168.12.2 remote-as 65001
 neighbor 192.168.12.2 filter-list 10 in
end
```

**【検証方法】**
```bash
R1# show ip bgp regexp _65001$
R1# show ip bgp neighbors 192.168.12.2 received-routes
```

---

### 3. 【BGP】Community-list を用いた特定タグ経路の Inbound フィルタリング
**【問題】**
R1 において、iBGP ピアから送信されてくる BGP ルートのうち、BGP Community 値 `64512:100` が付与されているルートを拒否し、それ以外のルートを受け入れる Route-map フィルタを構成してください。

**【R1 設定】**
```bash
R1# configure terminal
# コミュニティ値 64512:100 にマッチするリストを定義
ip community-list standard COMM-DENY-100 permit 64512:100

route-map BGP-COMM-FILTER deny 10
 match community COMM-DENY-100
exit

route-map BGP-COMM-FILTER permit 20
exit

router bgp 64512
 neighbor 10.1.1.2 remote-as 64512
 neighbor 10.1.1.2 route-map BGP-COMM-FILTER in
end
```

**【検証方法】**
```bash
R1# show ip bgp community 64512:100
R1# show route-map BGP-COMM-FILTER
```

---

### 4. 【BGP】Outbound Route Filtering (ORF) による送信元 Update 削減
**【問題】**
R2 は R1（eBGP ピア: 192.168.12.1）から多数のルートを受信しています。R2 側で Prefix-list `ORF-PREF`（`172.16.0.0/16` 以下のサブネットを拒否）を定義し、このフィルタ定義を BGP ORF 機能を用いて R1 側へ自動プッシュさせ、R1 側の送出段階でパケットをフィルタリングさせてください。

**【R2 (Receiver) 設定】**
```bash
R2# configure terminal
ip prefix-list ORF-PREF deny 172.16.0.0/16 le 32
ip prefix-list ORF-PREF permit 0.0.0.0/0 ge 0

router bgp 65002
 neighbor 192.168.12.1 remote-as 65001
 neighbor 192.168.12.1 capability orf prefix-list receive
 neighbor 192.168.12.1 prefix-list ORF-PREF in
end
```

**【R1 (Sender) 設定】**
```bash
R1# configure terminal
router bgp 65001
 neighbor 192.168.12.2 remote-as 65002
 neighbor 192.168.12.2 capability orf prefix-list send
end
```

**【検証方法】**
```bash
R2# show ip bgp neighbors 192.168.12.1 | include ORF
R1# show ip bgp neighbors 192.168.12.2 received prefix-filter
```

---

### 5. 【EIGRP】Named Mode インターフェイス単位 Distribute-list 制御
**【問題】**
EIGRP Named Mode（インスタンス名: `CCIE-EIGRP`、AS: 100）を運用する R1 において、`GigabitEthernet0/2` インターフェイスから外部へ送信される EIGRP Update のうち、`192.168.50.0/24` のみを遮断し、他の全ルートの送出を許可してください。

**【R1 設定】**
```bash
R1# configure terminal
ip prefix-list BLOCK-50 deny 192.168.50.0/24
ip prefix-list BLOCK-50 permit 0.0.0.0/0 ge 0

router eigrp CCIE-EIGRP
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/2
   topology base
    distribute-list prefix BLOCK-50 out
   exit-af-interface
  exit-af-interface
 end
```

**【検証方法】**
```bash
R1# show ip eigrp topology 192.168.50.0/24
# 対向ルータ側で show ip route eigrp を確認し、192.168.50.0/24 が存在しないことを検証
```

---

### 6. 【EIGRP】Offset-list を用いたメトリック無限大化（Infinity Filter）
**【問題】**
R1 において、EIGRP（AS 100）で受信する `10.10.10.0/24` のメトリック値に対して Offset-list を用いて「2,147,483,647（または最大メトリック）」を加算し、事実上アンリーチャブル（到達不能・フィルタ）として処理させてください。

**【R1 設定】**
```bash
R1# configure terminal
access-list 11 permit 10.10.10.0 0.0.0.255

router eigrp 100
 # 該当アクセスリストにマッチするルートのメトリックに最大オフセット値を加算
 offset-list 11 in 2147483647 GigabitEthernet0/1
end
```

**【検証方法】**
```bash
R1# show ip eigrp topology 10.10.10.0/24
# 「Composite metric is (2147483647/...)」または Inaccessible と表示されることを確認
```

---

### 7. 【OSPF】ABR での `area filter-list` (Type-3 LSA 遮断)
**【問題】**
ABR ルータ R1 において、Area 1 から Area 0 へ伝バンする Type-3 Summary LSA のうち、`172.16.10.0/24` の LSA 生成・アドバタイズを遮断し、その他のルートの Area 0 への通過を許可してください。

**【R1 (ABR) 設定】**
```bash
R1# configure terminal
ip prefix-list FILTER-AREA1-OUT deny 172.16.10.0/24
ip prefix-list FILTER-AREA1-OUT permit 0.0.0.0/0 ge 0

router ospf 1
 area 1 filter-list prefix FILTER-AREA1-OUT in
end
```

**【検証方法】**
```bash
# Area 0 側のルータで確認
Area0-Router# show ip ospf database summary 172.16.10.0
# LSA がデータベースに存在しないことを検証
```

---

### 8. 【OSPF】ABR での `area range not-advertise` (サマリー非送信)
**【問題】**
ABR ルータ R1 において、Area 2 内部のサブネット群 `10.2.1.0/24`、`10.2.2.0/24`、`10.2.3.0/24` を `10.2.0.0/16` に集約指定すると同時に、この集約ルート全体のバックボーン（Area 0）への送信を抑止（`not-advertise`）してください。

**【R1 (ABR) 設定】**
```bash
R1# configure terminal
router ospf 1
 area 2 range 10.2.0.0 255.255.0.0 not-advertise
end
```

**【検証方法】**
```bash
R1# show ip ospf summary-address
# Area 0 側のルータで show ip route ospf を実行し、10.2.x.x 関連ルートが完全に消去されていることを確認
```

---

### 9. 【OSPF】`distribute-list in` によるローカル RIB 掲載拒否
**【問題】**
ルータ R1 において、OSPF LSDB（データベース）の同一性を崩さずに、自身の IP ルーティングテーブル（RIB）にのみ `192.168.99.0/24` のルートが登録されないように制御してください。

**【R1 設定】**
```bash
R1# configure terminal
ip prefix-list LOCAL-BLOCK deny 192.168.99.0/24
ip prefix-list LOCAL-BLOCK permit 0.0.0.0/0 ge 0

router ospf 1
 distribute-list prefix LOCAL-BLOCK in
end
```

**【検証方法】**
```bash
# 1. LSDB には LSA が存在することを確認
R1# show ip ospf database network 192.168.99.0
# 2. RIB にはルートが存在しないことを確認
R1# show ip route 192.168.99.0
```

---

### 10. 【Static Routing】再配送時の Route-map 結合フィルタリング
**【問題】**
R1 において、複数のスタティックルートが設定されています。OSPF プロセス 1 へスタティックルートを再配送（`redistribute static`）する際、Tag `999` が付与されているスタティックルート、および `192.168.100.0/24` のみを通過させ、他のスタティックルートの再配送をブロックしてください。

**【R1 設定】**
```bash
R1# configure terminal
# スタティックルートの定義例
ip route 10.1.1.0 255.255.255.0 172.16.12.2 tag 999
ip route 192.168.100.0 255.255.255.0 172.16.12.2
ip route 172.31.1.0 255.255.255.0 172.16.12.2

# フィルタ条件の定義
ip prefix-list PERMIT-192 permit 192.168.100.0/24

route-map REDIST-STATIC-FILTER permit 10
 match tag 999
exit

route-map REDIST-STATIC-FILTER permit 20
 match ip address prefix-list PERMIT-192
exit

router ospf 1
 redistribute static subnets route-map REDIST-STATIC-FILTER
end
```

**【検証方法】**
```bash
R1# show route-map REDIST-STATIC-FILTER
# OSPF ネイバーで show ip route ospf を実行し、10.1.1.0/24 と 192.168.100.0/24 のみが LSA Type-5 (E2) として学習されていることを確認
```

---

## ❓ 想定試験問題

CCIE EI 実技試験（Practical Lab）および Diagnostic セクションを想定した難関設問集です。

### 1. 【コンフィグ読解：OSPF `distribute-list out` の不動作】
**問題:** 
受験者は R1 において以下の設定を投入し、隣接する R2 に対して `10.5.5.0/24` の OSPF ルートが送信されないように試みました。
しかし、R2 のルーティングテーブルを確認すると、依然として `10.5.5.0/24` が OSPF (O) として学習されていました。
```text
ip prefix-list FILTER-OUT deny 10.5.5.0/24
ip prefix-list FILTER-OUT permit 0.0.0.0/0 ge 0

router ospf 1
 distribute-list prefix FILTER-OUT out GigabitEthernet0/1
```
なぜこの設定では `10.5.5.0/24` の伝バンを阻止できないのか、OSPF のアーキテクチャ根拠に基づいて理由を説明し、R2 側へ経路を伝搬させないための正しくかつ最適な代替設定コマンドを提示してください（なお、R1 と R2 は同一の Area 0 に所属しています）。

**解答・解説:**
*   **技術的理由:**
    OSPF は Link-State ルーティングプロトコルであり、エリア内の全ルータは同一の LSDB（Link-State Database）を保持しなければなりません。そのため、IOS-XE においてインターフェイス指定の `distribute-list out` は **再配送（Redistribute）によって生成された External LSA (Type-5/7) に対してのみ機能する仕様** となっています。通常の Intra-Area（Type-1/2）ルートに対して `distribute-list out` を設定しても、LSA の生成および Flooding パケットの送出は一切阻止されません。
*   **正解の代替設定 (R2 側の Inbound でブロック、または ABR での分離):**
    R1 と R2 が同一 Area 0 に属している場合、エリア内での LSA Flooding 自体を止めることはプロトコル上不可能です。したがって、R2 側の RIB 登録のみを阻止するか、エリア設計を変更する必要があります。
    * **解法 A (R2 側での RIB 挿入阻止):**
      ```text
      R2(config)# ip prefix-list BLOCK-5 deny 10.5.5.0/24
      R2(config)# ip prefix-list BLOCK-5 permit 0.0.0.0/0 ge 0
      R2(config)# router ospf 1
      R2(config-router)# distribute-list prefix BLOCK-5 in
      ```
    * **解法 B (エリアを分割し ABR で Type-3 LSA を遮断する場合):**
      R1 を別エリア (例: Area 1) に配置し、ABR ルータ上で `area 1 filter-list prefix FILTER-OUT in` を適用する。

---

### 2. 【トラブルシュート：Prefix-list の `ge`/`le` 条件不一致による全ルート切断】
**問題:** 
あるネットワークエンジニアが、BGP ピアから受信する `10.0.0.0` 網の各種サブネット（例: `10.1.0.0/16` や `10.2.3.0/24`）のみを通過させる目的で、以下の Prefix-list を適用しました。
```text
ip prefix-list BGP-IN permit 10.0.0.0/8 ge 24
```
設定適用直後、`10.1.0.0/16` などの主要なサブネットルートが BGP テーブルから消去されてしまいました。
1. なぜ `10.1.0.0/16` が拒否されたのか、Prefix-list の判定論理を説明してください。
2. `/16` から `/24` までのすべてのサブネットを正しく許可するための修正コマンドを示してください。

**解答・解説:**
1.  **判定論理の理由:**
    `ip prefix-list BGP-IN permit 10.0.0.0/8 ge 24` という記述は、「先頭 8 ビットが `10.x.x.x` であり、**かつサブネットマスク長が 24 ビット以上（/24 〜 /32）** であるプレフィックス」のみにマッチします。
    `10.1.0.0/16` はマスク長が `/16`（24未満）であるため、この permit 条件にマッチせず通過し、Prefix-list 末尾の **暗黙の拒否（`implicit deny`）** に引っかかってドロップされました。
2.  **修正コマンド:**
    ```text
    ip prefix-list BGP-IN permit 10.0.0.0/8 ge 16 le 24
    ```

---

### 3. 【Design：BGP ORF (Outbound Route Filtering) の適用条件とメリット】
**問題:** 
低帯域な WAN リンク（10Mbps）を介して大容量な BGP フルルートを配信してくる上流 ISP ルータ（R1）が存在します。自社ルータ（R2）ではメモリ負荷削減のため、`192.168.0.0/16` 以下のプライベートプレフィックスを Inbound で拒否したいと考えています。
通常の Inbound Route-map フィルタと、BGP ORF (Outbound Route Filtering) を利用した場合の**ネットワーク帯域およびルータリソースにおける決定的な違い**を説明してください。

**解答・解説:**
*   **通常の Inbound フィルタの場合:**
    上流 ISP (R1) はすべての BGP Update パケットを 10Mbps の WAN リンク経由で R2 へ送信し続けます。R2 はパケットを受信した後にローカルの CPU/メモリを消費して Route-map を評価し、対象プレフィックスを破棄します。この方式では **WAN リンクの帯域幅が不必要な Update トラフィックで無駄に消費** されます。
*   **BGP ORF (Outbound Route Filtering) を利用した場合:**
    R2 側で設定された Prefix-list の内容（`deny 192.168.0.0/16 le 32`）が、BGP 制御メッセージを通じて上流ルータ R1 側の Outbound フィルタとして**動的に送信（Push）** されます。R1 はパケットを送出する前の段階でフィルタリングを実行するため、**WAN リンク上に不必要な Update パケットが1パケットも流れず、帯域幅と R2 のパケット受信処理 CPU 負荷が劇的に削減** されます。

---

## 🔗 参考リソース

### Cisco ソフトウェア設定ガイド（Configuration Guide）
*   [**Cisco Catalyst 9300 Series Switches: IP Routing: Protocol-Independent Configuration Guide - Route Filtering**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/ip_route_protocol/b_17x_ip_route_protocol_9300_cg.html)
    *   Cisco IOS-XE 17.x における Prefix-list, Route-map, Distribute-list の詳細な設定ガイド。
*   [**Cisco BGP Configuration Guide, Release 17.x - Outbound Route Filtering (ORF)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/17-x/iproute_bgp_17-x_cg.html)
    *   BGP ORF (RFC 5291) のネゴシエーション仕様および設定リファレンス。

### Cisco Command Reference
*   [**Cisco IOS XE 17.x IP Routing Command Reference - ip prefix-list / distribute-list**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/command_reference/b_17x_ip_route_cmd_ref.html)
    *   `ip prefix-list` の `ge`/`le` パラメーター詳細仕様。

### Cisco Live（オンデマンド・スライド資料）
*   [**BRKRST-2337: Advanced BGP Routing and Policy Control**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)
    *   BGP における各種フィルタリング（AS-Path, Community, ORF）とアトリビュート操作の深層解説。
*   [**BRKCRS-2031: OSPF and EIGRP Control Plane Security and Filtering Best Practices**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031)
    *   IGP (OSPF/EIGRP) における再配送ポイントでのループ防止フィルタリング設計。

---

## 📝 **補足（Notes）**

### 各プロトコルのフィルタリング指定方法 一発参照マトリクス

```text
【 BGP 】
   Inbound / Outbound フィルタ:
   - neighbor <IP> prefix-list <NAME> in|out
   - neighbor <IP> filter-list <AS-PATH-ACL> in|out
   - neighbor <IP> route-map <NAME> in|out
   - neighbor <IP> capability orf prefix-list send|receive

【 EIGRP (Named Mode) 】
   af-interface <INT> ➔ topology base ➔ distribute-list [prefix <PFL> | <ACL> | route-map <MAP>] in|out
   topology base ➔ distribute-list [prefix <PFL> | <ACL> | route-map <MAP>] in|out

【 OSPF 】
   - ローカル RIB 挿入阻止: distribute-list [prefix <PFL> | <ACL>] in
   - ABR Type-3 LSA 制御: area <AREA-ID> filter-list prefix <PFL> in|out
   - ABR 要約抑制: area <AREA-ID> range <NET> <MASK> not-advertise
   - ASBR 外部要約抑制: summary-address <NET> <MASK> not-advertise
```

*   **最終チェック項目:**
    *   [ ] OSPF で `distribute-list out` を設定しようとしていないか？（再配送以外では動かないことを理解しているか？）
    *   [ ] Prefix-list の末尾に暗黙の拒否（`implicit deny`）があることを考慮し、必要な `permit 0.0.0.0/0 ge 0` を記載しているか？
    *   [ ] Prefix-list の `ge`/`le` の数値条件が `Len < ge <= le <= 32` を満たしているか？
    *   [ ] BGP で受信ルートの検証を行う際、Soft Reconfiguration または Route Refresh が有効になっているか？



