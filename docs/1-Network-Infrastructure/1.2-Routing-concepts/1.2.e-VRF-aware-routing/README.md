---
layout: default
title: 1.2.e-VRF-aware-routing
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.2.e VRF-aware routing with BGP, EIGRP, OSPF, and static

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるネットワーク仮想化・セグメンテーションの最重要技術である **VRF-aware routing with BGP, EIGRP, OSPF, and static** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v、ISR/ASRシリーズ等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**VRF-aware routing（VRF対応ルーティング）** とは、単一の物理ルータまたはレイヤ3スイッチ上に構築された独立した **VRF（Virtual Routing and Forwarding）** テーブルごとに、ルーティングプロトコル（BGP、EIGRP、OSPF）のインスタンスやスタティックルートを独立して動作させる技術です。

各VRFインスタンスは独自ルーティングテーブル（RIB）および転送テーブル（FIB）を保持するため、異なるVRF間で同一のIPアドレス空間（`10.0.0.0/8` や `192.168.1.0/24` など）が重複して存在していても、互いに干渉することなく完全に独立した経路計算とパケット転送を実行できます。

### 主な利用目的と適用シーン
1. **マルチテナント・企業内セグメンテーション:** 1台のレイヤ3機器上で、営業部（VRF BLUE）、開発部（VRF RED）、PCI-DSS準拠網（VRF SECURE）などのルーティングを完全に物理レベル・論理レベルで分離・制御する。
2. **SD-Access / SD-WAN Fusion ルータ:** Cisco SD-Accessにおける VN（Virtual Network）や SD-WAN の Service VPN トラフィックを、外部の共有サービス（DNS/DHCP/ISE/FMC/Internet）やレガシーWAN網へ接続する際のハンドオフポイントで動的ルーティングを確立する。
3. **MPLS L3VPN PE-CE ルーティング:** プロバイダエッジ（PE）ルータにおいて、カスタマーエッジ（CE）ルータとの間でVRFごとにBGP、EIGRP、OSPF、スタティックルートを個別に交換し、MP-BGP (VPNv4/VPNv6) へ再配送・統合する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 単一機器内でプロトコルプロセスをVRFインスタンスごとに独立して起動・管理。RIB/FIB、隣接関係（Adjacency）、タイマー、メトリック計算がすべてVRF単位で完全分離される。 |
| **用途** | エンタープライズL3仮想化、マルチテナント分離、SD-Access/SD-WAN Handオフ、MPLS L3VPN PE-CEルータ構成。 |
| **メリット** | 重複IPアドレス空間のサポート、最高レベルのL3セキュリティ隔離、ハードウェア統合によるCAPEX/OPEXの劇的な削減。 |
| **デメリット** | 設定の複雑化（特に再配送やルートリーク時）。OSPFでの Down Bit / Domain Tag や EIGRP Named Mode の構文理解が必須。 |
| **対応機種** | Cisco Catalyst 9300 / 9400 / 9500 / 9600 シリーズ、Catalyst 8000v / 8200 / 8300 / 8500、ASR1000 シリーズ（IOS-XE 17.x）。 |
| **制限事項** | インターフェイスに `vrf forwarding` を設定するとIPアドレスが自動消去される（設定順序の鉄則）。OSPFのVRF動作ではデフォルトで Down Bit チェックが有効化されるため、`capability vrf-lite` の適用管理が必要。 |
| **設計上の注意点** | レガシーな `ip vrf` 構文ではなく、IPv4/IPv6 Dual-Stack をネイティブサポートする `vrf definition` 構文を使用すること。 |

---

## 🏗 動作原理

VRF-aware routing では、制御プレーン（Control Plane）および転送プレーン（Data Plane）の双方がVRFコンテキストに拘束されます。

```text
 [ Ingress Interface (Gi1/0/1: vrf RED) ]
                    │
                    ▼
       [ VRF RED Parsing Engine ]
                    │
   ┌────────────────┴────────────────┐
   ▼                                 ▼
[ Control Plane (VRF RED) ]     [ Data Plane (VRF RED) ]
 ├─ OSPF Process 100 (VRF RED)   ├─ VRF RED RIB (ip route vrf RED)
 ├─ EIGRP Process (VRF RED)      └─ VRF RED FIB (CEF Table RED)
 ├─ BGP IPv4 VRF RED AF                      │
 └─ Static Routes (VRF RED)                  ▼
                                [ Egress Interface (Gi1/0/2: vrf RED) ]
```

### プロトコルごとのVRF対応動作メカニズム

1. **VRF-aware Static Route:**
   * `ip route vrf <NAME> <PREFIX> <MASK> <NEXT_HOP>` コマンドにより指定VRFのRIBに静的経路を注入。ネクストホップの解決も同一VRF内で行われる。
2. **VRF-aware OSPF (v2/v3):**
   * OSPFプロセスは `router ospf <PROC_ID> vrf <NAME>` または OSPFv3 の `router ospfv3 <PROC_ID>` -> `address-family ipv4 unicast vrf <NAME>` で起動。
   * OSPFがVRFコンテキストで起動すると、IOS-XEは自動的に自身を **PE（Provider Edge）ルータ** とみなし、ループ防止メカニズム（LSA Type 3 の **DN Bit (Down Bit)** 設定、LSA Type 5/7 の **Domain Tag** 付与）を有効化する。
   * **VRF-Lite（MPLSを使わない単体VRF構成）** では、このDN Bitチェックにより対向ルータでType-3/5/7 LSAが無視される現象が発生するため、**`capability vrf-lite`** の設定が不可欠となる。
3. **VRF-aware EIGRP (Classic vs Named Mode):**
   * Classic Mode: `router eigrp <AS>` -> `auto-summary` の制約やIPv6不可のため非推奨。
   * **Named Mode (推奨・CCIE標準):** `router eigrp <INSTANCE_NAME>` 配下で `address-family ipv4 unicast vrf <NAME> autonomous-system <AS>` を指定して動作させる。AS番号はAFレベルで個別に定義する。
4. **VRF-aware BGP:**
   * BGPルータプロセス `router bgp <LOCAL_AS>` の配下に `address-family ipv4 unicast vrf <NAME>` または `address-family ipv6 unicast vrf <NAME>` を作成。
   * VRF単位で `neighbor <IP> remote-as <ASN>` を設定し、独立したBGPピアリングとBGPテーブルを保持する。

---

## ⚙ 動作シーケンス

各プロトコルのパケット処理およびテーブル登録シーケンスは以下の通りです。

```text
1. インターフェイスの VRF バインド
   └─ 例: interface Gi1/0/1 -> vrf forwarding BLUE -> ip address 10.1.12.1 255.255.255.0
      └─ 当該ポートで送受信される全パケットは「VRF BLUE」の文脈に割り当てられる。

2. プロトコルハローパケットの送受信
   └─ OSPF/EIGRP/BGP は Gi1/0/1 からマルチキャスト/ユニキャストでハローを送信。
   └─ 対向の VRF BLUE インターフェイスと独自にネイバー関係（Adjacency）を確立。

3. 制御パケットの交換と RIB 算出
   └─ 各プロトコルは受信したLSA/Updateパケットを「VRF BLUE 専用データベース」に登録。
   └─ SPF計算やDUAL計算を実行し、ベストパスを「VRF BLUE RIB (show ip route vrf BLUE)」へ転送。

4. CEF (FIB) テーブルの同期
   └─ VRF BLUE RIB のベストパスが「VRF BLUE CEF (FIB)」へ同期される。
   └─ ハードウェア ASIC (UADP/QFP) の TCAM エントリに VRF ID 付きで書き込まれる。

5. データパケットの転送
   └─ Gi1/0/1 (VRF BLUE) に入力されたパケットは、VRF BLUE FIB のみを検索して高速転送される。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI実技試験において、VRF-aware routing は非常に高配点かつトラップが仕込まれやすい領域です。以下のポイントを完ペキにマスターしてください。

### 1. OSPF VRF-Lite における `capability vrf-lite` の落とし穴
* **試験の罠:** 「R1 と R2 の間で VRF RED を構成し、OSPF プロセス 100 を動作させた。R1 でループバックインターフェイスを OSPF にアドバタイズし、LSA Type 3/5 が R2 に到達しているにもかかわらず、R2 のルーティングテーブル（`show ip route vrf RED`）に OSPF 経路が一切載らない」
* **原因:** OSPF は VRF 配下で動作させると、デフォルトで MP-BGP / MPLS L3VPN の PE ルータとして振る舞います。R1 が生成した LSA Type-3 に **DN Bit（Down Bit）** が自動セットされ、受信した R2 は「この LSA は既に別の PE から CE に再配送されたもの（ループの危険あり）」と判定して RIB への登録を自動破棄します。
* **対策:** OSPF VRF プロセス配下で、DN Bit / Domain Tag によるループチェックを無効化する **`capability vrf-lite`** を必ず追加します。
  ```bash
  router ospf 100 vrf RED
   capability vrf-lite
  ```

### 2. EIGRP Named Mode における VRF アドレスファミリーと AS 番号指定
* **試験の罠:** EIGRP Named Mode で VRF アドレスファミリーを定義する際、`autonomous-system <AS>` の指定を忘れると、ネイバーが永久に立ち上がりません。
* **対策:**
  ```bash
  router eigrp CCIE_EIGRP
   address-family ipv4 unicast vrf RED autonomous-system 100
    topology base
     exit-af-topology
    network 10.1.12.0 0.0.0.255
   exit-address-family
  ```

### 3. BGP における VRF-aware eBGP / iBGP の構成
* VRF-aware eBGP のみを行う場合（純粋な VRF-Lite ハンドオフ）、`route-distinguisher` や `route-target` の設定、および `address-family vpnv4` の設定は **不要** です。
* `router bgp 65001` 配下の `address-family ipv4 unicast vrf RED` の中で直接 `neighbor 192.168.12.2 remote-as 65002` を定義します。

### 4. インターフェイス設定順序（IP Address 消去トラップ）
* インターフェイスに IP アドレスが設定されている状態で `vrf forwarding <NAME>` を設定すると、**IP アドレスおよび IPv6 アドレスが即座に消去** されます。
* **正しい順序:** `vrf forwarding <NAME>` ➔ `ip address <IP> <MASK>` ➔ `no shutdown`

### 5. 検証時の CLI コマンドにおける VRF キーワード忘れ
* 単に `show ip route` や `ping 10.1.12.1` を実行すると、グローバルルーティングテーブル（GRT）が検索されるため、VRF 配下の通信確認に失敗します。
* 必ず `show ip route vrf <NAME>`、`ping vrf <NAME> <IP>`、`traceroute vrf <NAME> <IP>` を使用すること。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における、各プロトコルの VRF-aware 完全設定例です。

### 1. VRF 定義（Modern `vrf definition` 構文）

```bash
# VRF BLUE (IPv4/IPv6 Dual-Stack 対応)
vrf definition BLUE
 rd 65000:100
 address-family ipv4
  exit-address-family
 address-family ipv6
  exit-address-family
!
# VRF RED
vrf definition RED
 rd 65000:200
 address-family ipv4
  exit-address-family
!
```

### 2. インターフェイスへの VRF アサイン

```bash
interface GigabitEthernet1/0/1
 description CONNECT_TO_BLUE_NEIGHBOR
 vrf forwarding BLUE
 ip address 10.1.12.1 255.255.255.0
 ipv6 address 2001:db8:12::1/64
 no shutdown
!
interface GigabitEthernet1/0/2
 description CONNECT_TO_RED_NEIGHBOR
 vrf forwarding RED
 ip address 10.1.24.1 255.255.255.0
 no shutdown
!
```

### 3. VRF-aware Static Routes (IPv4 / IPv6)

```bash
# VRF BLUE 配下のスタティックルート
ip route vrf BLUE 172.16.10.0 255.255.255.0 10.1.12.2
ip route vrf BLUE 0.0.0.0 0.0.0.0 10.1.12.254
ipv6 route vrf BLUE 2001:db8:1000::/64 2001:db8:12::2

# VRF RED 配下のスタティックルート
ip route vrf RED 172.16.20.0 255.255.255.0 10.1.24.2
```

### 4. VRF-aware OSPFv2 / OSPFv3 設定

```bash
# VRF BLUE 用 OSPFv2 (Process 100)
router ospf 100 vrf BLUE
 router-id 1.1.1.1
 # VRF-Lite ループチェック（DN Bit等）の無効化（重要！）
 capability vrf-lite
 area 0 authentication message-digest
 network 10.1.12.0 0.0.0.255 area 0
!
# VRF RED 用 OSPFv2 (Process 200)
router ospf 200 vrf RED
 router-id 1.1.1.2
 capability vrf-lite
 network 10.1.24.0 0.0.0.255 area 0
!
# OSPFv3 (Dual-Stack VRF-aware)
router ospfv3 1
 address-family ipv4 unicast vrf BLUE
  router-id 1.1.1.1
  capability vrf-lite
 exit-address-family
 address-family ipv6 unicast vrf BLUE
  router-id 1.1.1.1
  capability vrf-lite
 exit-address-family
!
```

### 5. VRF-aware EIGRP Named Mode 設定

```bash
router eigrp CCIE_FABRIC
 # 1. グローバル (GRT) アドレスファミリー (必要に応じて)
 !
 # 2. VRF BLUE アドレスファミリー (AS 100)
 address-family ipv4 unicast vrf BLUE autonomous-system 100
  router-id 10.1.12.1
  topology base
   exit-af-topology
  network 10.1.12.0 0.0.0.255
 exit-address-family
 !
 # 3. VRF RED アドレスファミリー (AS 200)
 address-family ipv4 unicast vrf RED autonomous-system 200
  router-id 10.1.24.1
  topology base
   exit-af-topology
  network 10.1.24.0 0.0.0.255
 exit-address-family
!
```

### 6. VRF-aware BGP 設定

```bash
router bgp 65001
 router-id 1.1.1.1
 bgp log-neighbor-changes
 no bgp default ipv4-unicast
 !
 # VRF BLUE アドレスファミリー (eBGP ピアリング: AS 65002)
 address-family ipv4 unicast vrf BLUE
  neighbor 10.1.12.2 remote-as 65002
  neighbor 10.1.12.2 activate
  neighbor 10.1.12.2 as-override
  network 172.16.10.0 mask 255.255.255.0
 exit-address-family
 !
 # VRF RED アドレスファミリー (eBGP ピアリング: AS 65003)
 address-family ipv4 unicast vrf RED
  neighbor 10.1.24.2 remote-as 65003
  neighbor 10.1.24.2 activate
  network 172.16.20.0 mask 255.255.255.0
 exit-address-family
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **VRF定義一覧とバインドされているインターフェイスの確認** | <code>show vrf</code> / <code>show vrf detail</code> |
| **特定VRF（BLUE）のルーティングテーブル確認** | <code>show ip route vrf BLUE</code> / <code>show ipv6 route vrf BLUE</code> |
| **特定VRF（BLUE）のCEF転送テーブル確認** | <code>show ip cef vrf BLUE</code> |
| **VRF-aware OSPF ネイバー確認** | <code>show ip ospf 100 vrf BLUE neighbor</code> |
| **VRF-aware OSPF データベース確認** | <code>show ip ospf 100 vrf BLUE database</code> |
| **VRF-aware EIGRP ネイバー確認** | <code>show ip eigrp vrf BLUE neighbors</code> |
| **VRF-aware EIGRP トポロジーテーブル確認** | <code>show ip eigrp vrf BLUE topology</code> |
| **VRF-aware BGP サマリー・ネイバー状態確認** | <code>show ip bgp vrf BLUE summary</code> |
| **VRF-aware BGP テーブル確認** | <code>show ip bgp vrf BLUE</code> |
| **特定VRF指定での PING 疎通確認** | <code>ping vrf BLUE 10.1.12.2</code> |
| **特定VRF指定での Traceroute 確認** | <code>traceroute vrf BLUE 10.1.12.2</code> |
| **VRF-aware OSPF パケットデバッグ** | <code>debug ip ospf 100 adj</code> / <code>debug ip ospf events</code> |
| **VRF-aware EIGRP パケットデバッグ** | <code>debug ip eigrp vrf BLUE</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`vrf forwarding` コマンドを設定したら、直前まで通っていた PING が突然不通になった。** | `vrf forwarding` を適用した時点で、**インターフェイスの IP アドレスが自動消去（Removed）** された。 | `show ip interface brief` | 対象インターフェイスに再移動し、再度 `ip address <IP> <MASK>` を設定する。 |
| **OSPF データベースには Type-3 / Type-5 LSA が存在するのに、`show ip route vrf <NAME>` にルートが一切載らない。** | VRF 配下の OSPF で **DN Bit (Down Bit)** または Domain Tag チェックが作動し、LSA が破棄されている。 | `show ip ospf <PROC> vrf <NAME> database summary` | `router ospf <PROC> vrf <NAME>` 配下に **`capability vrf-lite`** を追加する。 |
| **EIGRP Named Mode で VRF アドレスファミリーを設定したが、ハローパケットすら送信されない。** | `address-family ipv4 unicast vrf <NAME>` 配下で **`autonomous-system <AS>`** の定義を忘れている。 | `show run | section router eigrp` | アドレスファミリーの宣言行に `autonomous-system <AS_NUMBER>` を明記する。 |
| **`ping 10.1.12.2` を実行すると「% Network-unreachable」またはドロップになる。** | 該当 IP は VRF BLUE 配下に存在するが、PING コマンドで **VRF キーワードを指定していない** ため、GRT を検索している。 | `ping vrf BLUE 10.1.12.2` | CLI で検証する際は必ず `ping vrf <NAME> <IP>` 形式を使用する。 |
| **BGP VRF 配下で `neighbor` を設定したが、`show ip bgp vrf <NAME> summary` で「Idle (Admin)」のまま動かない。** | BGP の VRF アドレスファミリー内で `neighbor <IP> activate` を実行していない、またはグローバルで `no bgp default ipv4-unicast` が効いている。 | `show run | section router bgp` | `address-family ipv4 unicast vrf <NAME>` 配下で明示的に `neighbor <IP> activate` を投入する。 |

---

## ⚠ 制限事項

1. **プラットフォーム・ライセンス制限:**
   * Cisco Catalyst 9000 シリーズで多重 VRF（Multi-VRF）を動作させるには、**Network Advantage** ライセンスが必要（Network Essentials では制限あり）。
2. **グローバルルーティングテーブル（GRT）との完全隔離:**
   * VRF 配下のインターフェイスから送信されたパケットは、明示的な Route Leaking（`1.2.f`）が構成されていない限り、GRT や他の VRF のルーティングテーブルを検索することはできない。
3. **OSPF プロセス数の制限:**
   * IOS-XE 上で多数の VRF OSPF プロセス（`router ospf 1 vrf A`、`router ospf 2 vrf B` ...）を乱立させると、CPU / メモリバジェットを消費する。可能であれば OSPFv3 の Address-Family 統合や BGP への統一を検討すること。

---

## 🔄 他技術との関連

* **1.2.d VRF-Lite:** VRF の基礎概念およびインターフェイスバインド技術。本トピック（`1.2.e`）は VRF-Lite 上で各ダイナミックプロトコルを動作させる発展形。
* **1.2.f Route leaking between VRFs:** 分離された VRF 間（例: VRF BLUE と VRF SHARED_SERVICES）で、Route-Map や VASI (VRF-aware Software Infrastructure) を使用して部分的に経路を相互接続・リークさせる技術。
* **1.2.g Route filtering with BGP, EIGRP, OSPF, and static:** VRF 内で交換される動的経路に対して Prefix-list、Distribute-list、Route-map を適用してフィルタリングする。
* **1.2.h Redistribution between BGP, EIGRP, OSPF, and static:** 同一 VRF 内において、OSPF と BGP 間、あるいは EIGRP と Static 間の再配送（Redistribution）を実行する（※再配送コマンドは VRF コンテキスト内で行う）。

---

## 🧩 比較表

### VRF-aware Routing プロトコル機能比較

| 比較項目 | VRF-aware Static | VRF-aware OSPF | VRF-aware EIGRP (Named) | VRF-aware BGP |
| :--- | :--- | :--- | :--- | :--- |
| **設定コンテキスト** | グローバル `ip route vrf` | `router ospf <ID> vrf <NAME>` | `address-family ... vrf <NAME>` | `address-family ... vrf <NAME>` |
| **必須固有コマンド** | なし | **`capability vrf-lite`** | **`autonomous-system <AS>`** | **`neighbor <IP> activate`** |
| **ループ防止機能** | なし（手動管理） | **DN Bit / Domain Tag** | メトリック/Hop Count | **AS_PATH / Allowas-in** |
| **設定の複雑さ** | 低 | 中 | 中 | 高 |
| **拡張性 (Scalability)** | 小規模 | 中規模 | 中〜大規模 | **大規模（推奨）** |

---

## 💡 ベストプラクティス

1. **`vrf definition` 構文の全面採用:**
   * レガシーな `ip vrf <NAME>` ではなく、将来の IPv6 拡張や MP-BGP 連携に対応可能な `vrf definition <NAME>` 構文で統一する。
2. **VRF OSPF における `capability vrf-lite` の定型挿入:**
   * MPLS L3VPN の PE ルータとして動作させる場合を除き、企業内 VRF-Lite 網で OSPF を使用する際は、トラブル防止のため `capability vrf-lite` を必ず設定テンプレートに組み込む。
3. **EIGRP Named Mode への統一:**
   * EIGRP Classic Mode は VRF 設定が煩雑で IPv6 対応も独立プロセスとなるため、必ず Named Mode (`router eigrp <NAME>`) を使用する。
4. **明確な RD (Route Distinguisher) の命名規則:**
   * VRF-Lite であっても、将来の MP-BGP 化を見据えて `rd <ASN>:<VRF_ID>`（例: `65000:100`）のように体系的な RD をアサインしておく。

---

## 📝 ラボ学習・設定サンプル例

※ 本サンプルは、Cisco IOS-XE 17.x の実機挙動に100%準拠した、省略なしの完全なCLI構成です。

### 1. Multi-VRF Dual-Stack (IPv4/IPv6) Static Routing
**【問題】**
R1 と R2 の間において、VRF `GREEN` を作成し、`GigabitEthernet1/0/1` を割り当ててください。
* IPv4: R1 `10.1.12.1/24`、R2 `10.1.12.2/24`
* IPv6: R1 `2001:db8:12::1/64`、R2 `2001:db8:12::2/64`
* R1 から R2 の Loopback10（IPv4: `172.16.10.1/32`、IPv6: `2001:db8:100::1/128`）へ向かうスタティックルートを VRF `GREEN` 内で設定してください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition GREEN
 rd 65000:10
 address-family ipv4
 exit-address-family
 address-family ipv6
 exit-address-family
!
interface GigabitEthernet1/0/1
 description TO_R2_GREEN
 vrf forwarding GREEN
 ip address 10.1.12.1 255.255.255.0
 ipv6 address 2001:db8:12::1/64
 no shutdown
!
# VRF GREEN 内のスタティックルート設定
ip route vrf GREEN 172.16.10.1 255.255.255.255 10.1.12.2
ipv6 route vrf GREEN 2001:db8:100::1/128 2001:db8:12::2
end
```

**【検証方法】**
```bash
R1# ping vrf GREEN 172.16.10.1
R1# ping vrf GREEN 2001:db8:100::1
R1# show ip route vrf GREEN
```

---

### 2. VRF-aware OSPFv2 with `capability vrf-lite`
**【問題】**
R1 と R2 の間を VRF `YELLOW` で接続し、OSPF プロセス 110 を構成してください。
* 物理インターフェイス: `GigabitEthernet1/0/2`（`10.1.25.0/24`）
* R1 (Router-ID `1.1.1.1`), R2 (Router-ID `2.2.2.2`)
* OSPF エリア 0 に参加させ、DN Bit による LSA 破棄を防ぐために `capability vrf-lite` を有効化してください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition YELLOW
 rd 65000:20
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet1/0/2
 description TO_R2_YELLOW
 vrf forwarding YELLOW
 ip address 10.1.25.1 255.255.255.0
 no shutdown
!
router ospf 110 vrf YELLOW
 router-id 1.1.1.1
 capability vrf-lite
 area 0 authentication message-digest
 network 10.1.25.0 0.0.0.255 area 0
end
```

**【R2 設定】**
```bash
R2# configure terminal
vrf definition YELLOW
 rd 65000:20
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet1/0/2
 description TO_R1_YELLOW
 vrf forwarding YELLOW
 ip address 10.1.25.2 255.255.255.0
 no shutdown
!
router ospf 110 vrf YELLOW
 router-id 2.2.2.2
 capability vrf-lite
 area 0 authentication message-digest
 network 10.1.25.0 0.0.0.255 area 0
end
```

**【検証方法】**
```bash
R1# show ip ospf 110 vrf YELLOW neighbor
R1# show ip route vrf YELLOW
```

---

### 3. VRF-aware EIGRP Named Mode (Multi-AF)
**【問題】**
R1 と R2 の間において、EIGRP Named インスタンス `CORP_EIGRP` を構築し、VRF `BLUE`（AS 100）および VRF `RED`（AS 200）の2つの独立した EIGRP プロセスを動作させてください。
* R1 Gi1/0/3 (VRF BLUE): `10.1.13.1/24` <--> R2 Gi1/0/3: `10.1.13.2/24`
* R1 Gi1/0/4 (VRF RED): `10.1.14.1/24` <--> R2 Gi1/0/4: `10.1.14.2/24`

**【R1 設定】**
```bash
R1# configure terminal
vrf definition BLUE
 rd 65000:100
 address-family ipv4
 exit-address-family
!
vrf definition RED
 rd 65000:200
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet1/0/3
 vrf forwarding BLUE
 ip address 10.1.13.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet1/0/4
 vrf forwarding RED
 ip address 10.1.14.1 255.255.255.0
 no shutdown
!
router eigrp CORP_EIGRP
 address-family ipv4 unicast vrf BLUE autonomous-system 100
  router-id 1.1.1.1
  topology base
   exit-af-topology
  network 10.1.13.0 0.0.0.255
 exit-address-family
 !
 address-family ipv4 unicast vrf RED autonomous-system 200
  router-id 1.1.1.1
  topology base
   exit-af-topology
  network 10.1.14.0 0.0.0.255
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ip eigrp vrf BLUE neighbors
R1# show ip eigrp vrf RED neighbors
R1# show ip route vrf BLUE
R1# show ip route vrf RED
```

---

### 4. VRF-aware eBGP Multi-Tenant Handoff
**【問題】**
R1 (AS 65001) と R2 (AS 65002) の間において、VRF `CUSTOMER_A` 内で eBGP ピアリングを確立してください。
* R1 Gi1/0/5 (VRF CUSTOMER_A): `192.168.12.1/24`
* R2 Gi1/0/5 (VRF CUSTOMER_A): `192.168.12.2/24`
* R1 は自身の Loopback100（`10.100.1.1/32`）を BGP でアドバタイズしてください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition CUSTOMER_A
 rd 65001:100
 address-family ipv4
 exit-address-family
!
interface Loopback100
 vrf forwarding CUSTOMER_A
 ip address 10.100.1.1 255.255.255.255
!
interface GigabitEthernet1/0/5
 vrf forwarding CUSTOMER_A
 ip address 192.168.12.1 255.255.255.0
 no shutdown
!
router bgp 65001
 router-id 1.1.1.1
 no bgp default ipv4-unicast
 bgp log-neighbor-changes
 !
 address-family ipv4 unicast vrf CUSTOMER_A
  neighbor 192.168.12.2 remote-as 65002
  neighbor 192.168.12.2 activate
  network 10.100.1.1 mask 255.255.255.255
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ip bgp vrf CUSTOMER_A summary
R1# show ip bgp vrf CUSTOMER_A
```

---

### 5. VRF-aware OSPFv3 Address-Family Configuration
**【問題】**
R1 と R2 の間で、OSPFv3 プロセス 1 を使用し、VRF `SECURE` 配下で IPv4 および IPv6 の Dual-Stack ルーティングを同時構成してください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition SECURE
 rd 65000:300
 address-family ipv4
 exit-address-family
 address-family ipv6
 exit-address-family
!
interface GigabitEthernet1/0/6
 vrf forwarding SECURE
 ip address 10.1.16.1 255.255.255.0
 ipv6 address 2001:db8:16::1/64
 ospfv3 1 ipv4 area 0
 ospfv3 1 ipv6 area 0
 no shutdown
!
router ospfv3 1
 address-family ipv4 unicast vrf SECURE
  router-id 1.1.1.1
  capability vrf-lite
 exit-address-family
 !
 address-family ipv6 unicast vrf SECURE
  router-id 1.1.1.1
  capability vrf-lite
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ospfv3 1 vrf SECURE neighbor
R1# show ip route vrf SECURE
R1# show ipv6 route vrf SECURE
```

---

### 6. Multi-VRF Redistribution (OSPF to BGP in VRF)
**【問題】**
R1 の VRF `GUEST` 内において、OSPF プロセス 50 から学習した経路を BGP AS 65001 の VRF `GUEST` アドレスファミリーへ再配送（Redistribute）してください。
* OSPF 経路には Metric-Type 1/2 が含まれます。
* BGP 再配送時には OSPF のメトリックを保持したまま移行させてください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition GUEST
 rd 65001:50
 address-family ipv4
 exit-address-family
!
router ospf 50 vrf GUEST
 router-id 1.1.1.1
 capability vrf-lite
 network 10.1.50.0 0.0.0.255 area 0
!
router bgp 65001
 address-family ipv4 unicast vrf GUEST
  redistribute ospf 50 match internal external 1 external 2
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ip bgp vrf GUEST
```

---

### 7. VRF-aware Static Default Routing with Object Tracking (IP SLA)
**【問題】**
R1 の VRF `INTERNET` 内において、IP SLA プローブ 10（ICMP Echo to `8.8.8.8`）を設定し、ネクストホップ `192.168.1.254` が生存している間のみ、VRF `INTERNET` にデフォルトルート（`0.0.0.0/0`）を保持させてください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition INTERNET
 rd 65000:999
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet1/0/7
 vrf forwarding INTERNET
 ip address 192.168.1.1 255.255.255.0
 no shutdown
!
# VRF-aware IP SLA の設定
ip sla 10
 icmp-echo 8.8.8.8 source-interface GigabitEthernet1/0/7
  vrf INTERNET
 frequency 5
ip sla schedule 10 life forever start-time now
!
# オブジェクトトラッキングの定義
track 10 ip sla 10 reachability
!
# トラッキング付き VRF スタティックデフォルトルート
ip route vrf INTERNET 0.0.0.0 0.0.0.0 192.168.1.254 track 10
end
```

**【検証方法】**
```bash
R1# show ip sla summary
R1# show track 10
R1# show ip route vrf INTERNET 0.0.0.0
```

---

### 8. MP-BGP L3VPN Integration (RD, RT, Export/Import)
**【問題】**
R1 (PEルータ) において、VRF `VPN_A` を設定し、iBGP MP-BGP (VPNv4) ピア R2 (`2.2.2.2`) とルートを交換できるように Route Target (RT) を定義してください。
* Route Distinguisher: `65000:100`
* RT Export: `65000:100`
* RT Import: `65000:100`

**【R1 設定】**
```bash
R1# configure terminal
vrf definition VPN_A
 rd 65000:100
 route-target export 65000:100
 route-target import 65000:100
 !
 address-family ipv4
 exit-address-family
!
router bgp 65000
 neighbor 2.2.2.2 remote-as 65000
 neighbor 2.2.2.2 update-source Loopback0
 !
 address-family vpnv4
  neighbor 2.2.2.2 activate
  neighbor 2.2.2.2 send-community extended
 exit-address-family
 !
 address-family ipv4 unicast vrf VPN_A
  redistribute connected
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ip bgp vpnv4 all summary
R1# show ip bgp vpnv4 vrf VPN_A
```

---

### 9. VRF-aware BGP Conditional Advertisement
**【問題】**
R1 の VRF `DATA` 内において、プレフィックス `10.1.0.0/16` が VRF BGP テーブルに存在する場合（Exist）のみ、対向ルータへデフォルトルート `0.0.0.0/0` を条件付きアドバタイズしてください。

**【R1 設定】**
```bash
R1# configure terminal
ip prefix-list PREFIX_EXIST permit 10.1.0.0/16
ip prefix-list DEFAULT_ROUTE permit 0.0.0.0/0
!
route-map MAP_EXIST permit 10
 match ip address prefix-list PREFIX_EXIST
!
route-map MAP_ADV permit 10
 match ip address prefix-list DEFAULT_ROUTE
!
router bgp 65001
 address-family ipv4 unicast vrf DATA
  neighbor 192.168.10.2 remote-as 65002
  neighbor 192.168.10.2 activate
  neighbor 192.168.10.2 advertise-map MAP_ADV exist-map MAP_EXIST
 exit-address-family
end
```

**【検証方法】**
```bash
R1# show ip bgp vrf DATA neighbors 192.168.10.2 advertised-routes
```

---

### 10. Fusion Router Multi-Tenant Integration (OSPF, EIGRP, BGP in VRF)
**【問題】**
Fusion ルータ R1 において、VRF `BLUE`（SD-Access 開発網）と VRF `RED`（SD-Access 営業網）を同時収容し、それぞれの内部プロトコルを統合してください。
* VRF BLUE: 内部 OSPFv2 (Process 10) <--> 外部 eBGP (AS 65100)
* VRF RED: 内部 EIGRP Named Mode (AS 200) <--> 外部 Static Routing

**【R1 設定】**
```bash
R1# configure terminal
vrf definition BLUE
 rd 65000:100
 address-family ipv4
 exit-address-family
!
vrf definition RED
 rd 65000:200
 address-family ipv4
 exit-address-family
!
# インターフェイス設定
interface GigabitEthernet1/0/1
 vrf forwarding BLUE
 ip address 10.1.10.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet1/0/2
 vrf forwarding BLUE
 ip address 192.168.100.1 255.255.255.0
 no shutdown
!
interface GigabitEthernet1/0/3
 vrf forwarding RED
 ip address 10.2.20.1 255.255.255.0
 no shutdown
!
# VRF BLUE (OSPF <-> BGP)
router ospf 10 vrf BLUE
 router-id 1.1.1.1
 capability vrf-lite
 redistribute bgp 65000 subnets
 network 10.1.10.0 0.0.0.255 area 0
!
router bgp 65000
 address-family ipv4 unicast vrf BLUE
  neighbor 192.168.100.2 remote-as 65100
  neighbor 192.168.100.2 activate
  redistribute ospf 10
 exit-address-family
!
# VRF RED (EIGRP <-> Static)
router eigrp FUSION_EIGRP
 address-family ipv4 unicast vrf RED autonomous-system 200
  router-id 1.1.1.1
  topology base
   redistribute static
  exit-af-topology
  network 10.2.20.0 0.0.0.255
 exit-address-family
!
ip route vrf RED 0.0.0.0 0.0.0.0 10.2.20.254
end
```

**【検証方法】**
```bash
R1# show ip route vrf BLUE
R1# show ip route vrf RED
R1# show ip ospf 10 vrf BLUE neighbor
R1# show ip eigrp vrf RED neighbors
R1# show ip bgp vrf BLUE summary
```

---

## ❓ 想定試験問題

CCIE EI 実技試験および Diagnostic セクションに対応した設問集です。

### 1. 【コンフィグ読解・トラブルシューティング：OSPF VRF 経路不通】
**問題:**
R1 と R2 の間で VRF `MGMT` を作成し、OSPF プロセス 50 を設定しました。R1 の `show ip ospf 50 vrf MGMT neighbor` では Full 状態になっていますが、R2 の `show ip route vrf MGMT` を実行すると、R1 からアドバタイズされたインターフェイス `10.50.1.0/24` の経路が存在しません。R2 の `show ip ospf 50 vrf MGMT database summary` には該当 LSA が存在しています。
この現象の原因と、解決するために投入すべきコマンドを答えてください。

**解答・解説:**
* **原因:** OSPF を VRF 配下で動作させると、自動的に DN Bit (Down Bit) チェックが有効になります。R1 が生成した LSA Type-3 に DN Bit がセットされており、それを受信した R2 が「L2VPN ループ防止機能」によって RIB への登録を拒否（ドロップ）しているためです。
* **解決コマンド:** R1 および R2 の OSPF プロセス配下で `capability vrf-lite` を追加します。
  ```bash
  R1(config)# router ospf 50 vrf MGMT
  R1(config-router)# capability vrf-lite
  ```

---

### 2. 【実装：EIGRP Named Mode VRF アドレスファミリー】
**問題:**
R1 において、EIGRP Named インスタンス `EIGRP_CORE` を作成し、VRF `SECURE_A`（AS 500）のネットワーク `10.50.0.0/16` をアドバタイズする最小限のコンフィグレーションを記述してください。

**解答・解説:**
```bash
router eigrp EIGRP_CORE
 address-family ipv4 unicast vrf SECURE_A autonomous-system 500
  topology base
   exit-af-topology
  network 10.50.0.0 0.0.255.255
 exit-address-family
```

---

### 3. 【デザイン・思考問題：VRF-Lite と BGP / OSPF の選定基準】
**問題:**
エンタープライズの Fusion ルータにおいて、10 個の異なる VRF を外部ルータ群へ動的ルーティングで共有接続する設計を行う場合、内部プロトコルとして VRF-aware OSPF ではなく VRF-aware BGP を推奨する設計上の技術的理由を 2 つ挙げてください。

**解答・解説:**
1. **プロセスリソースと管理性:** OSPF では 10 個の VRF ごとに別々の OSPF プロセス（`router ospf 1 vrf A` ～ `router ospf 10 vrf J`）を起動・保持する必要があり、ルータの CPU/メモリバジェットを圧迫する。一方 BGP では単一の BGP プロセス（`router bgp <AS>`）の配下に Address-Family を追加するだけで全 10 VRF を一括集中管理できる。
2. **ルーティングループ制御の容易さ:** OSPF では VRF-Lite 時の DN Bit や Domain Tag の考慮・`capability vrf-lite` の設定漏れリスクが付きまとうが、BGP では標準の AS_PATH 属性による直感的なループ防止が機能し、運用事故のリスクが低い。

---

### 4. 【トラブルシューティング：PING 失敗と VRF コンテキスト】
**問題:**
エンジニアが R1 の VRF `GUEST` 内にある対向ルータ IP `192.168.50.2` へ CLI から PING を打ちましたが、以下のように 100% ドロップしました。
```text
R1# ping 192.168.50.2
Type escape sequence to abort.
Sending 5, 100-byte ICMP Echos to 192.168.50.2, timeout is 2 seconds:
.....
Success rate is 0 percent (0/5)
```
しかし、`show ip route vrf GUEST` を確認すると `192.168.50.0/24` は `GigabitEthernet1/0/1` (VRF GUEST) に Directly Connected と表示されています。なぜ PING が失敗するのか、原因と正しいコマンドを記述してください。

**解答・解説:**
* **原因:** 引数なしの `ping 192.168.50.2` コマンドは、デフォルトで **グローバルルーティングテーブル (GRT)** を検索して送出されます。`192.168.50.2` は VRF `GUEST` のテーブルにしか存在しないため、GRT 上で不通となります。
* **正しいコマンド:** `ping vrf GUEST 192.168.50.2`

---

### 5. 【コンフィグ読解：BGP VRF 配下の AS-Override】
**問題:**
以下のコンフィグで、`neighbor 10.1.12.2 as-override` コマンドが VRF `SITE_A` 内に適用されている理由を説明してください。
```bash
router bgp 65000
 address-family ipv4 unicast vrf SITE_A
  neighbor 10.1.12.2 remote-as 65001
  neighbor 10.1.12.2 activate
  neighbor 10.1.12.2 as-override
 exit-address-family
```

**解答・解説:**
* **理由:** 異なる拠点の CE ルータ（例: Site-1 と Site-2）が偶然同一のプライベート AS 番号（AS 65001）を使用している MPLS L3VPN / Multi-Tenant 環境において、PE ルータが対向 CE ルータへ BGP アップデートを送信する際、AS_PATH 内の `65001` を自身の AS 番号 `65000` に置換（Override）して送出するためです。もし置換しないと、受信側の CE (AS 65001) は AS_PATH 内に自身の AS 番号が含まれているのを見て、標準の BGP ループ防止機構によりパケットを自動破棄（ドロップ）してしまいます。

---

## 🔗 参考リソース

### Cisco 公式 Configuration Guides
* [**Cisco Catalyst 9300 Series Switches: IP Routing Configuration Guide, IOS XE 17.x (Configuring VRF)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/ip/b_17x_ip_9300_cg/m_cg_vrf.html)
* [**Cisco IOS XE 17.x BGP Configuration Guide (VRF-aware BGP)**](https://www.cisco.com/c/en/us/td/docs/routers/asr1000/configuration/guide/chassis/asr1000-cg/bgp-vrf-aware.html)
* [**Cisco IOS XE 17.x OSPF Configuration Guide (OSPF Support for VRF-Lite)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/15-sy/iro-15-sy-book/iro-vrf-lite.html)
* [**EIGRP Named Mode Configuration Guide, Cisco IOS XE 17.x**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/17-x/ire-17-x-book/ire-named-mode.html)

### Cisco Live Presentations
* [**BRKCRS-2001: Intent-Based Networking with SD-Access Fusion Router Integration**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2001)
* [**BRKIPM-2264: VRF, MPLS, and BGP Integration Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPM-2264)

### Technical Notes & CVDs
* [**Troubleshooting OSPF Routes in VRF Context and DN Bit Mechanism**](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/118370-technote-ospf-00.html)
* [**Cisco SD-Access Solution Design Guide (Fusion Router Handoff)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)

---

## 📝 補足（Notes）

### VRF-aware Routing 実装クイック判定フロー

```text
[ インターフェイスに VRF を適用 (vrf forwarding <NAME>) ]
           │
           ▼
[ IP アドレスを再設定 (ip address <IP> <MASK>) ]
           │
           ▼
┌──────────┴──────────────────────────────────────────┐
│ 使用するプロトコルの選定                           │
├─────────────────────────────────────────────────────┤
│ 1. Static : ip route vrf <NAME> ...                 │
│ 2. OSPF   : router ospf <ID> vrf <NAME>             │
│             └─► 必ず capability vrf-lite を投入！   │
│ 3. EIGRP  : router eigrp <NAME>                     │
│             └─► address-family ... vrf <NAME>       │
│                 autonomous-system <AS> を明記！     │
│ 4. BGP    : router bgp <ASN>                        │
│             └─► address-family ... vrf <NAME>       │
│                 neighbor <IP> activate を明記！     │
└─────────────────────────────────────────────────────┘
```

* **CCIE 試験当日の最終チェックリスト:**
  * [ ] インターフェイスの IP アドレスが VRF 設定後に消えていないか？（`show ip interface brief`）
  * [ ] VRF OSPF に `capability vrf-lite` が入っているか？（DN Bit ドロップの防止）
  * [ ] EIGRP Named Mode の VRF AF 内に `autonomous-system` が正しく記述されているか？
  * [ ] BGP VRF AF 内で `neighbor activate` を実行したか？
  * [ ] 疎通確認時に `ping vrf <NAME>` を使用しているか？

---


