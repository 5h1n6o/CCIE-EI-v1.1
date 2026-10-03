---
layout: default
title: 2.1.c-Fabric-design
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 3
---

# 2.1.c Fabric design

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における Cisco SD-Access (Software-Defined Access) アーキテクチャの核心である **`2.1.c Fabric design`** (Single-site campus, Multisite, Fabric in a box) について、Cisco Catalyst Center (旧 Cisco DNA Center) 2.3.x、Cisco ISE 3.x、および Cisco IOS-XE 17.x の実装基準に 100% 準拠して、設計原則・構成パターン・CLI/GUI 設定例・トラブルシューティング・検証手順まで詳細に解説します。

---

## 📘 概要

### 機能概要
Cisco SD-Access (SDA) Fabric Design は、キャンパス LAN および WAN 統合環境において、ファブリックノード（Control Plane Node, Border Node, Fabric Edge Node, Wireless Controller, Fusion Router 等）の物理的・論理的配置パターンを最適化するためのアーキテクチャ設計枠組みです。

SD-Access では、企業の拠点規模、地理的配置、ノード数、WAN 接続形態、および可溶性 (HA) 要件に応じて、主に以下の 3 つの代表的なファブリックデザインが定義されています。

1. **Single-site campus (2.1.c (i)):** 単一の建屋・ビル・ビル群（キャンパス）内に構築される標準的な SD-Access ファブリック。独立した Control Plane Node (MS/MR)、Border Node、Fabric Edge Node を備え、内部/外部トラフィックおよび Shared Services へのルーティングを最適化します。
2. **Multisite / Distributed Campus (2.1.c (ii)):** 地理的に離れた複数の Fabric Site（Main Campus、Regional Office、Branch 等）を WAN / Transit ネットワークを介して相互接続するアーキテクチャ。Transit の種類（IP-based Transit, SD-WAN Transit, SD-Access LISP Pub/Sub Transit）に応じて、サイト間での End-to-End L2/L3 セグメンテーション（VN/SGT）の維持や、分散コントロールプレーン連携を実現します。
3. **Fabric in a Box (FIAB) (2.1.c (iii)):** 単一の Catalyst スイッチ（Catalyst 9300/9400/9500 等、またはその StackWise/SVL）上に、**Control Plane Node、Border Node、Fabric Edge Node** のすべてのファブリックノード機能を統合（All-in-One）搭載した最小構成モデル。小規模拠点や支社（Branch）において省スペース・省電力で SD-Access の機能（VN/SGT/Overlay）を享受できます。

---

## 🔑 要点

| 設計要素 / 構成 | Single-site campus | Multisite (Distributed Campus) | Fabric in a Box (FIAB) |
| :--- | :--- | :--- | :--- |
| **対象規模** | 中〜大規模キャンパス・本社ビル | 地理的に分散した多拠点・グローバル網 | 小規模拠点・支社 (Branch)・小規模工場 |
| **Control Plane** | 冗長化された専用 MS/MR (2台以上推奨) | 各 Site 単位の CP + Inter-site CP / SD-WAN | 同一筐体内に統合 (一体型 LISP MS/MR) |
| **Border Node** | 冗長構成 (Internal / External / Anycast) | 各 サイト単位の Border + SD-WAN / IP Transit | 同一筐体内に統合 (一体型 Border) |
| **Fabric Edge** | 独立した多数の Access/Distribution Switch | 各 サイト内の 独立 Fabric Edge | 同一筐体内に統合 (一体型 Edge ポート) |
| **サイト間接続** | N/A (ファブリック内局所化) | IP Transit, SD-WAN Transit, LISP Transit | WAN/Internet ルータ経由 |
| **L2 Stretch** | ファブリックサイト内で完全サポート | SD-WAN / LISP Transit 経由でサポート可 | サポート不可 (ローカルサイト内閉塞) |
| **ハードウェア要件** | Dedicated Catalyst 9500/9600/9300/9400 | Dedicated Border/CP + Transit Gateway | Catalyst 9300 / 9400 / 9500 (単体 or SVL/Stack) |
| **主なメリット** | 最大限のスケーラビリティと高可用性 | 全拠点一元ポリシーツー管理・セグメンテーション維持 | 省スペース・低コスト・完全単一筐体完結 |
| **制限事項・注意点** | 多数のハードウェア選定と設計の複雑性 | Transit 依存の MTU/オーバーヘッド考慮 | 収容端末数・LISP テーブル上限制限 |

---

## 🏗 動作原理

### 1. Single-site Campus の通信・論理構成

Single-site Campus では、ファブリック内のノード役割が物理的または論理的に明確に分離されています。

```
                    [ Shared Services (DHCP / DNS / ISE) ]
                                    │
                            [ Fusion Router ] (VRF-Lite BGP)
                                    │
                    ┌───────────────┴───────────────┐
                    │                               │
        [ Control Plane Node ]          [ Fabric Border Node ]
            (LISP MS/MR)                  (Internal / External)
                    │                               │
    ────────────────┴───────────────┬───────────────┴──────────────── (Underlay IS-IS / OSPF)
                                    │
                        ┌───────────┴───────────┐
                        │                       │
                [ Fabric Edge 1 ]       [ Fabric Edge 2 ]
                   (Anycast GW)            (Anycast GW)
                        │                       │
                    [ Host A ]              [ Host B ]
```

* **Control Plane Node (MS/MR):** Endpoint ID (EID) と Routing Locator (RLOC = Fabric Edge IP) のマッピングデータベースを管理。
* **Fabric Border Node:** ファブリック外部（Fusion Router 経由の Shared Services や Internet）とのトラフィック出入口。
* **Fabric Edge Node:** ホストのファブリック収容、Dynamic VLAN/SGT 割り当て、Anycast Gateway の適用、および VXLAN カプセル化/デカプセル化を担当。

---

### 2. Multisite (Distributed Campus) のサイト間連携構成

Multisite デザインでは、拠点（Site）ごとに独立した LISP コントロールプレーンおよび Fabric Border を配置し、それらを Transit ネットワークで相互接続します。

```
 [ Site A (Main Campus) ]                        [ Site B (Regional Office) ]
 ┌──────────────────────┐                        ┌──────────────────────────┐
 │ Control Plane Node A │                        │  Control Plane Node B    │
 │ Fabric Border A      │                        │  Fabric Border B         │
 │ Fabric Edge A        │                        │  Fabric Edge B           │
 └──────────┬───────────┘                        └────────────┬─────────────┘
            │                                                 │
            └───────────────┐                 ┌───────────────┘
                            │                 │
                  [ SD-WAN Transit / IP-based Transit ]
                            │                 │
                [ Centralized Control Plane / SD-WAN vSmart ]
```

* **IP-based Transit:** サイト間を VRF-Lite BGP または LISP Pub/Sub で接続。VRF (VN) ごとに Sub-interface / Sub-VRF を構築し、SGT 情報は SXP (SGT Exchange Protocol) または Inline Tagging で伝搬。
* **SD-WAN Transit:** Cisco SD-WAN (vManage / vSmart / vEdge / cEdge) と SD-Access を統合。SD-Access の VN が SD-WAN の VPN (VRF) に 1:1 マッピングされ、SGT は SD-WAN オプションヘッダー（OMP 属性）に乗せて自動伝搬。

---

### 3. Fabric in a Box (FIAB) のオールインワン内部構成

Fabric in a Box では、単一の物理スイッチ（または StackWise / StackWise-Virtual）内部の IOS-XE ソフトウェアプロセス上で、Control Plane、Border、Fabric Edge がすべて起動します。

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Fabric in a Box (FIAB)                          │
│                                                                        │
│  ┌────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │ LISP Control Plane     │  │ Fabric Border                        │  │
│  │ (MS/MR Process)        │  │ (External/Internal BGP Handoff)      │  │
│  └───────────┬────────────┘  └──────────────────┬───────────────────┘  │
│              │ (Internal Loopback IPC)          │                      │
│  ┌───────────┴──────────────────────────────────┴───────────────────┐  │
│  │ Fabric Edge Function                                             │  │
│  │ (Anycast Gateway, L2/L3 VXLAN Engine, SGT Enforcement)            │  │
│  └──────────────────────────────────┬───────────────────────────────┘  │
│                                     │                                  │
└─────────────────────────────────────┼──────────────────────────────────┘
                                      │ (Access Ports)
                             ┌────────┴────────┐
                             │ Host A / AP / PC│
                             └─────────────────┘
```

* **内部結合:** ITR/ETR (Edge) 機能と MS/MR (Control Plane) 機能が単一のルーティングテーブルおよび LISP プロセス内で内部通信するため、登録・検索パケット（Map-Register / Map-Request）が高速に処理されます。

---

## ⚙ 動作シーケンス

### 1. Single-site Campus におけるパケット処理シーケンス

```
[ Host A (EID_A) ]     [ Fabric Edge 1 ]     [ Control Plane ]     [ Fabric Edge 2 ]     [ Host B (EID_B) ]
       │                      │                     │                     │                      │
       │─── (1) ARP / IP ────>│                     │                     │                      │
       │    Packet            │                     │                     │                      │
       │                      │─── (2) Map-Request >│                     │                      │
       │                      │    (EID_B Query)    │                     │                      │
       │                      │                     │                     │                      │
       │                      │<── (3) Map-Reply ───│                     │                      │
       │                      │    (RLOC = FE2 IP)  │                     │                      │
       │                      │                     │                     │                      │
       │                      │───────────────── (4) VXLAN Data Packet ─────────────────────────>│
       │                      │                  (Src: FE1, Dst: FE2, VNI, SGT)                  │─── (5) Native IP ──>│
```

1. **Host A からの通信開始:** Host A が同一 VN 内の Host B (EID_B) 宛てにパケットを送信。Fabric Edge 1 (FE1) がパケットを受信。
2. **LISP Map-Request 送信:** FE1 は EID_B に対するキャッシュ（Map-Cache）が存在しない場合、Control Plane Node (MS/MR) へ Map-Request を送出。
3. **Map-Reply 応答:** MS/MR は EID_B が Fabric Edge 2 (FE2) の RLOC に紐付いていることを Map-Reply で FE1 に返答。FE1 は Map-Cache に「EID_B ➔ RLOC_FE2」を登録。
4. **VXLAN カプセル化と転送:** FE1 はパケットを VXLAN-GPO でカプセル化（Outer IP: Src FE1 RLOC, Dst FE2 RLOC、VNI, SGT）し、アンダーレイ IP 網を経由して FE2 へ送出。
5. **デカプセル化と着信:** FE2 は VXLAN パケットをデカプセル化し、SGT ポリシー (SGACL) を評価後、Host B の接続ポートへ送出。

---

### 2. Fabric in a Box (FIAB) の内部処理シーケンス

1. **ホスト着信:** FIAB のアクセスポートに Host A が接続し、DHCP/802.1X 認証を実行。
2. **ローカル LISP 登録:** FIAB 内の Edge 機能が、内部で動作する LISP MS/MR プロセスに対し、Loopback IPC 経由で Map-Register を送出。外部ネットワークへのパケット送出時も、自筐体内の MS/MR を直接参照するため、検索遅延（Latency）が最小化されます。
3. **外部転送:** 外部（Internet / Corporate WAN）宛てトラフィックは、FIAB 上の Border 抽象機能を経由し、Upstream ルータ / SD-WAN cEdge へ VRF-Lite Handoff されます。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
* **Single-site Fabric 設計:**
  * Control Plane Node の二重化 (Active/Active Load-sharing LISP MS/MR) 設定 [21, 2.1.c]。
  * Border Node のタイプ選定 (`Internal Border`, `External Border`, `Anycast Border`) と Fusion Router 間での VRF-Lite BGP Handoff 設定 [21, 2.1.c]。
  * Anycast Gateway の自動/手動設定と MAC アドレス (`0000.0c9f.fxxx` 等) の整合性 [21, 2.1.c]。
* **Multisite Fabric 設計:**
  * IP Transit 環境における VRF ごとの Sub-interface / BGP Handoff 設定および SXP (SGT Exchange Protocol) ピアリング構造 [21, 2.1.c]。
  * SD-WAN Transit 統合時における VN-to-VPN マッピングおよび OMP による SGT 伝搬要求の解読 [21, 2.1.c]。
* **Fabric in a Box (FIAB) 特有の設定要件:**
  * 単一 CLI 上での LISP MS/MR (`site`, `map-server`, `map-resolver`) と Fabric Edge (`database-mapping`, `itr`, `etr`) の一体化設定 [21, 2.1.c]。
  * Loopback0 アドレスを RLOC、MS/MR IP、および Border BGP Router-ID として兼用するコンフィグ設計 [21, 2.1.c]。
  * FIAB 上での Fabric Wireless Controller (Embedded WLC) 統合構成と CAPWAP トンネル処理 [21, 2.1.c]。

---

### よくある設定ミス・落とし穴
1. **FIAB での LISP MS/MR アドレスの矛盾:**
   * `router lisp` 配下で指定する `locator-set` や `map-resolver` / `map-server` アドレスに、物理ポート IP や別システムの IP を指定してしまい、内部 LISP 登録がループ・タイムアウトするミス。自身のアドバタイズ用 Loopback0 を指定する必要があります。
2. **Anycast Border と Internal/External Border の誤用:**
   * Default Route をファブリック内に注入する External Border と、ファブリック内 EID 経路のみを外部に広告する Internal Border の役割を混同し、非最適ルーティング（Sub-optimal routing）が発生する構成。
3. **Multisite 間での MTU 不足:**
   * WAN / Transit ネットワーク上で VXLAN オーバーヘッド（50 バイト以上）を考慮した Jumbo MTU (1550〜9100) が設定されておらず、サイト間 Overlay パケットがフラグメント不可（DF Bit）により破棄されるトラブル。

---

## 🛠 設定方法

### 1. Single-site Fabric コントロールプレーン / Border / Edge CLI 設定例

#### (1) Control Plane Node (LISP MS/MR) 設定例
```bash
! --- Control Plane Node (MS/MR) ---
router lisp
 site SITE_CAMPUS
  authentication-key Cisco123!
  eid-record VN_CORP instance-id 4099
    10.1.0.0/16 accept-more-specifics
  !
 ipv4 map-server
 ipv4 map-resolver
 instance-id 4099
  service ipv4
   eid-table vrf VN_CORP
   map-resolver
   map-server
  exit-service-ipv4
!
```

#### (2) Fabric Border Node (External / Internal Anycast Border) 設定例
```bash
! --- Fabric Border Node ---
router lisp
 locator-set BORDER_LOCATORS
  192.168.255.1 priority 1 weight 100
 exit-locator-set
 !
 instance-id 4099
  service ipv4
   eid-table vrf VN_CORP
   map-cache 0.0.0.0/0 map-request
  exit-service-ipv4
!
router bgp 65001
 vrf VN_CORP
  neighbor 10.255.1.2 remote-as 65002
  neighbor 10.255.1.2 activate
  redistribute lisp metric 10
!
```

---

### 2. Fabric in a Box (FIAB) 完全 CLI コンフィグ例

Catalyst 9300 / 9500 単体で Control Plane, Border, Fabric Edge を統合配置するコンフィグです。

```bash
! ==========================================================
! Fabric in a Box (FIAB) Complete CLI Configuration
! ==========================================================
hostname FIAB-NODE-01

! --- VRF Definition ---
vrf definition VN_CORP
 rd 65000:4099
 address-family ipv4
  exit-address-family
!

! --- Loopback & Interface Setup ---
interface Loopback0
 description Fabric RLOC / Control Plane / Border IP
 ip address 192.168.255.100 255.255.255.255
 ip pim sparse-mode
!

interface Vlan101
 description Anycast Gateway for Corp Users
 vrf forwarding VN_CORP
 ip address 10.1.10.1 255.255.255.0
 mac-address 0000.0c9f.f001
 no autostate
!

! --- LISP Configuration (Integrated MS/MR/Border/Edge) ---
router lisp
 locator-set FIAB_RLOC
  192.168.255.100 priority 1 weight 100
 exit-locator-set
 !
 site LOCAL_BRANCH
  authentication-key BranchSecret123
  eid-record VN_CORP_EID instance-id 4099
    10.1.0.0/16 accept-more-specifics
  !
 !
 ipv4 map-server
 ipv4 map-resolver
 !
 instance-id 4099
  service ipv4
   eid-table vrf VN_CORP
   itr map-resolver 192.168.255.100
   etr map-server 192.168.255.100 key BranchSecret123
   etr
   itr
   database-mapping 10.1.10.0/24 locator-set FIAB_RLOC
   map-cache 0.0.0.0/0 map-request
  exit-service-ipv4
!

! --- VXLAN NVI Interface ---
interface nve1
 no ip address
 source-interface Loopback0
 member vni 8000001 mcast-group 232.1.1.1
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 期待される出力結果・確認ポイント |
| :--- | :--- | :--- |
| LISP サイト登録確認 | <code>show lisp site</code> | CP 上で各 EID レコードが `up` かつ登録 RLOC 数が表示されているか |
| LISP Map-Cache 確認 | <code>show lisp instance-id 4099 ipv4 map-cache</code> | 対象 EID が正しく RLOC アドレスにマッピングされているか確認 |
| Anycast GW 確認 | <code>show ip interface brief \| include Vlan</code> | Anycast Gateway VLAN が UP/UP で正しい IP/MAC を保持しているか |
| FIAB 内部登録検証 | <code>show lisp instance-id 4099 ipv4 server</code> | FIAB 内部で MS/MR として自機 ETR が登録完了しているか |
| VXLAN NVI ピア確認 | <code>show nve peers</code> | 対向 Fabric Edge / Border との NVE ピアリングが確立しているか |
| SGT テーブル確認 | <code>show cts role-based permissions</code> | SGACL ポリシーが正しくハードウェア TCAM に適用されているか |

---

## 🚨 トラブルシュート

| 症状 | 推定原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **FIAB でホスト間通信が不可能** | 内部 LISP ITR/ETR キーの不一致、または Map-Resolver アドレスの指定ミス | <code>show lisp instance-id 4099 ipv4 map-cache</code> | `etr map-server` の IP に自機 Loopback0 を指定し、認証キーを一致させる |
| **Multisite 間で通信が遮断される** | Transit 網での MTU サイズ不足による VXLAN パケットのドロップ | <code>ping 192.168.255.2 size 1550 df-bit</code> | アンダーレイ全機器の MTU を 9100 / 9216 (Jumbo Frame) に変更する |
| **外部ネット通信が特定 Border に偏る** | External Border の Default Route 広告のメトリック不均等 | <code>show ip route vrf VN_CORP</code> | Fusion Router 側からの BGP ルート広告メトリック/AS-Path を均等化する |
| **Shared Services (DHCP/DNS) に届かない** | Fusion Router での Route Leaking コンフィグ漏れ | <code>show ip route vrf GLOBAL</code> | Fusion Router で GRT と VRF 間の相互再配送/Leaking を正しく設定 |

---

## ⚠ 制限事項

1. **Fabric in a Box (FIAB) の収容制限:**
   * FIAB は単一ノードで全プロセッサ処理を行うため、登録可能 EID 数（Host 数）や LISP Map-Cache エントリ数にプラットフォーム上限（例: Cat9300 で最大 2,000〜4,000 EID）があります。
2. **Multisite L2 Extension 制限:**
   * SD-WAN Transit 経由の Multisite 間 L2 Stretch（Subnet 延伸）には、特定の Catalyst Center バージョン (2.2.3 以降) および SD-WAN ソフトウェア要件が必要です。
3. **FIAB での External Border 冗長化の制約:**
   * FIAB 自体が 1 台の物理/SVL 筐体となるため、完全な物理分離 Border 冗長を行う場合は Single-site 専用構成への移行が必要です。

---

## 🔄 他技術との関連

* **Cisco SD-WAN Integration:** SD-Access Multisite 設計において、WAN 領域に SD-WAN ネットワークを採用する場合、SD-Access の VN (VRF) と SGT が SD-WAN の VPN および OMP ヘッダーにシームレスにマッピングされます。
* **Cisco ISE (Identity Services Engine):** Single-site / Multisite / FIAB のいずれの構成においても、pxGrid 経由で Catalyst Center と連携し、動的 VLAN / SGT 割り当ておよび SGACL ポリシーの中央集権管理を行います。
* **VRF-Lite & BGP:** Border Node と Fusion Router 間の Handoff において、マルチテナント分離を維持するための最重要 L3 境界技術です。

---

## 🧩 比較表

### SD-Access ファブリックデザインの比較

| 評価項目 | Single-site Campus | Multisite (Distributed Campus) | Fabric in a Box (FIAB) |
| :--- | :--- | :--- | :--- |
| **設置構成** | ディストリビューション/コア分離型 | 地理的複数拠点 ＋ WAN 結合 | 単一物理スイッチ (または Stack/SVL) |
| **最小必須機器数** | 4台以上 (CPx2, Borderx1, Edgedx1) | 各サイト 2台以上 ＋ Transit GW | 1台 (All-in-One Switch) |
| **スケーラビリティ** | 非常に高い (数万 EID) | 非常に高い (全サイト統合管理) | 小規模限定 (〜2,000 EID) |
| **設定の複雑さ** | 中程度 (役割別に CLI/GUI 設定) | 高い (Transit / SXP 制御要) | 低い (単一ノードコンフィグ完結) |
| **初期導入コスト** | 高 | 非常に高 | 最低限 (Low CAPEX/OPEX) |

---

## 💡 ベストプラクティス

1. **Single-site における Control Plane 冗長化:**
   * Control Plane Node (MS/MR) は必ず 2 台配置し、Active/Active による LISP 登録要求の負荷分散と可用性を確保してください。
2. **Fabric in a Box における SVL / StackWise の活用:**
   * FIAB を導入する際、単一機器のハードウェア故障対策として Catalyst 9300 StackWise または Catalyst 9500 StackWise-Virtual (SVL) を採用し、論理 1 台として FIAB 機能を動作させることが推奨されます。
3. **Multisite Transit MTU 設計:**
   * サイト間 Transit ネットワークの MTU は最低でも **1550 バイト以上**（可能な限り **9100 バイト**）を確保し、VXLAN パケットのパケット破棄を防止してください。

---

## 📝 ラボ学習・設定サンプル例

### Sample Lab 1: Single-site Dedicated Control Plane Node (MS/MR) 設定
* **問題:** R1 を Single-site キャンパスの専用 Control Plane Node として設定し、VN_GUEST (Instance 4100) の LISP MS/MR 機能を構築せよ。
* **要件:**
  * Loopback0 (`192.168.100.1/32`) を MS/MR IP として使用。
  * 認証キー: `CiscoKey4100`
* **設定例:**
```bash
router lisp
 site GUEST_SITE
  authentication-key CiscoKey4100
  eid-record VN_GUEST_EID instance-id 4100
    10.2.0.0/16 accept-more-specifics
  !
 ipv4 map-server
 ipv4 map-resolver
 instance-id 4100
  service ipv4
   eid-table vrf VN_GUEST
   map-resolver
   map-server
  exit-service-ipv4
!
```
* **検証方法:**
  * `show lisp site` で GUEST_SITE が正しく認識されているか確認。

---

### Sample Lab 2: Fabric in a Box (FIAB) 単一ノード完全構成
* **問題:** Switch-1 上で FIAB を構築し、VRF `VN_EMPLOYEE` (Instance 4098) の Control Plane、Border、Edge 機能を 1 台で有効化せよ。
* **要件:**
  * Loopback0: `10.255.255.1/32`
  * EID Subnet: `10.10.10.0/24` (Vlan 10)
  * 認証キー: `FIAB_Secret`
* **設定例:**
```bash
vrf definition VN_EMPLOYEE
 rd 65000:4098
 address-family ipv4
 exit-address-family
!
interface Loopback0
 ip address 10.255.255.1 255.255.255.255
!
interface Vlan10
 vrf forwarding VN_EMPLOYEE
 ip address 10.10.10.1 255.255.255.0
 mac-address 0000.0c9f.f101
 no autostate
!
router lisp
 locator-set LOCAL_LOC
  10.255.255.1 priority 1 weight 100
 exit-locator-set
 !
 site FIAB_SITE
  authentication-key FIAB_Secret
  eid-record EMP_EID instance-id 4098
    10.10.0.0/16 accept-more-specifics
  !
 ipv4 map-server
 ipv4 map-resolver
 !
 instance-id 4098
  service ipv4
   eid-table vrf VN_EMPLOYEE
   itr map-resolver 10.255.255.1
   etr map-server 10.255.255.1 key FIAB_Secret
   etr
   itr
   database-mapping 10.10.10.0/24 locator-set LOCAL_LOC
  exit-service-ipv4
!
```
* **検証方法:**
  * `show lisp instance-id 4098 ipv4 map-cache` を実行し、ローカルサブネットがデータベースに登録されているか確認。

---

### Sample Lab 3: FIAB 外部 Handoff (VRF-Lite BGP 構成)
* **問題:** Sample Lab 2 の FIAB 筐体から Upstream ルータへ `VN_EMPLOYEE` の外部 Handoff BGP ピアリングを設定せよ。
* **要件:**
  * Handoff Interface: GigabitEthernet1/0/24.100 (VLAN 100)
  * Local AS: 65100, Peer AS: 65000, Peer IP: `172.16.1.1`
* **設定例:**
```bash
interface GigabitEthernet1/0/24.100
 encapsulation dot1Q 100
 vrf forwarding VN_EMPLOYEE
 ip address 172.16.1.2 255.255.255.252
!
router bgp 65100
 vrf VN_EMPLOYEE
  neighbor 172.16.1.1 remote-as 65000
  neighbor 172.16.1.1 activate
  redistribute lisp
!
```
* **検証方法:**
  * `show ip bgp vrf VN_EMPLOYEE summary` で BGP ピアが Established になっているか確認。

---

### Sample Lab 4: Multisite IP Transit 用 SXP (SGT Exchange Protocol) ピアリング設定
* **問題:** Site-A Border ルータと Site-B Border ルータ間で SXP セッションを確立し、SGT マッピング情報を同期せよ。
* **要件:**
  * Local IP: `192.168.1.1`, Peer IP: `192.168.2.1`
  * SXP Password: `SxpPassword1`
  * Role: Site-A (Speaker), Site-B (Listener)
* **設定例:**
```bash
! --- Site-A Border (Speaker) ---
cts sxp enable
cts sxp default source-ip 192.168.1.1 password SxpPassword1
cts sxp connection peer 192.168.2.1 password SxpPassword1 mode local speaker
!
```
* **検証方法:**
  * `show cts sxp connections` で Connection State が `On` になっているか検証。

---

### Sample Lab 5: Anycast Border での Default Route LISP 転送構成
* **問題:** Fabric Border 上で外部からの Default Route (`0.0.0.0/0`) を受領し、ファブリック内 Edge からの外部宛て Map-Request に応答できるように設定せよ。
* **要件:**
  * VRF: `VN_CORP` (Instance 4099)
* **設定例:**
```bash
router lisp
 instance-id 4099
  service ipv4
   eid-table vrf VN_CORP
   map-cache 0.0.0.0/0 map-request
  exit-service-ipv4
!
```
* **検証方法:**
  * Edge 上で `show lisp instance-id 4099 ipv4 map-cache` を実行し、`0.0.0.0/0` が Border RLOC を指しているか確認。

---

### Sample Lab 6: Single-site 冗長 Control Plane (Secondary MS/MR) 設定
* **問題:** Secondary CP ルータ (CP-2) に LISP MS/MR を追加構築し、Primary CP (CP-1: `192.168.100.1`) と並列動作させよ。
* **要件:**
  * CP-2 IP: `192.168.100.2`
  * Instance ID: 4099
* **設定例:**
```bash
router lisp
 site CAMPUS_SITE
  authentication-key CiscoKey4099
  eid-record VN_CORP_EID instance-id 4099
    10.1.0.0/16 accept-more-specifics
  !
 ipv4 map-server
 ipv4 map-resolver
 instance-id 4099
  service ipv4
   eid-table vrf VN_CORP
   map-resolver
   map-server
  exit-service-ipv4
!
```
* **検証方法:**
  * Edge ルータ側で `itr map-resolver 192.168.100.1` および `itr map-resolver 192.168.100.2` の両方が登録されているか確認。

---

### Sample Lab 7: Fabric Edge での Dual Map-Resolver 指定コンフィグ
* **問題:** Fabric Edge 機器において、2 台の Control Plane Node (CP-1, CP-2) を冗長 Map-Resolver / Map-Server として登録せよ。
* **要件:**
  * CP-1: `192.168.100.1`, CP-2: `192.168.100.2`
* **設定例:**
```bash
router lisp
 instance-id 4099
  service ipv4
   eid-table vrf VN_CORP
   itr map-resolver 192.168.100.1
   itr map-resolver 192.168.100.2
   etr map-server 192.168.100.1 key CiscoKey4099
   etr map-server 192.168.100.2 key CiscoKey4099
  exit-service-ipv4
!
```
* **検証方法:**
  * `show lisp instance-id 4099 ipv4 map-responder` で両方の MS/MR がアクティブか検証。

---

### Sample Lab 8: FIAB 上での Embedded Wireless Controller (EWC) LISP AP 統合設定
* **問題:** FIAB 筐体上で AP 接続用インフラ VLAN (Vlan 102) を LISP データベースマッピングに追加せよ。
* **要件:**
  * AP Subnet: `10.1.102.0/24`
  * Instance ID: 4099
* **設定例:**
```bash
interface Vlan102
 description AP Infrastructure VLAN
 vrf forwarding VN_CORP
 ip address 10.1.102.1 255.255.255.0
!
router lisp
 instance-id 4099
  service ipv4
   database-mapping 10.1.102.0/24 locator-set FIAB_RLOC
  exit-service-ipv4
!
```
* **検証方法:**
  * `show lisp instance-id 4099 ipv4 database` に `10.1.102.0/24` が表示されるか確認。

---

### Sample Lab 9: SGT インラインタギングを伴う Multisite Border インターフェイス設定
* **問題:** サイト間 Transit に接続する Border インターフェイスで、CTS SGT インラインタギングを有効化せよ。
* **要件:**
  * Target Interface: GigabitEthernet1/0/1
* **設定例:**
```bash
interface GigabitEthernet1/0/1
 description Transit Interface to WAN
 ip address 172.20.1.1 255.255.255.252
 cts manual
  policy static sgt 100
  inline tag-trusted
!
```
* **検証方法:**
  * `show cts interface GigabitEthernet1/0/1` で Inline Tagging が Enabled になっているか検証。

---

### Sample Lab 10: FIAB トラブルシューティング（Map-Cache 手動クリアと再登録）
* **問題:** FIAB 上で古い EID マッピングがキャッシュとして残っているため、LISP Map-Cache を手動でクリアし、登録状態を強制更新せよ。
* **要件:**
  * Instance ID: 4099
* **設定例:**
```bash
! --- Operational Commands ---
clear lisp instance-id 4099 ipv4 map-cache
clear lisp instance-id 4099 ipv4 neighbors
!
```
* **検証方法:**
  * `show lisp instance-id 4099 ipv4 map-cache` を実行し、新たなパケット到着時に動的エントリが再生成されることを確認。

---

## ❓ 想定試験問題

### Question 1 (Design)
**問題:** 従業員数 150 名の小規模支社（Branch Office）に SD-Access を導入することになった。設置スペースと予算の制約から、現地に専用の Control Plane Node や Border Node を個別配置することはできない。この拠点に最適な SD-Access ファブリックデザインはどれか？
* A) Single-site Dedicated Campus Design
* B) Multisite Distributed Campus Design
* C) Fabric in a Box (FIAB) Design
* D) Extended Node Only Design

**正解:** **C**  
**解説:** Fabric in a Box (FIAB) は、単一の物理スイッチ（Catalyst 9300/9500 等）上に Control Plane、Border、Fabric Edge の全機能を統合統合搭載する設計パターンであり、小規模拠点や支社に最適です。

---

### Question 2 (Implementation / CLI)
**問題:** Fabric in a Box (FIAB) を設定中、アクセスポートに接続したホストがファブリック外部（Internet）と通信できない障害が発生した。`show lisp instance-id 4099 ipv4 map-cache` を確認したところ、`0.0.0.0/0` のエントリが存在しなかった。この障害を解決するために `router lisp` 配下で設定すべき不足コマンドはどれか？
* A) `map-cache 0.0.0.0/0 map-request`
* B) `default-information originate`
* C) `exit-service-ipv4`
* D) `proxy-itr 0.0.0.0/0`

**正解:** **A**  
**解説:** SD-Access ファブリックにおいて、Border (または FIAB) 経由で外部のデフォルトルートにアクセスするには、LISP インスタンス配下で `map-cache 0.0.0.0/0 map-request` を設定し、未知の宛先パケットに対して Border への Map-Request を生成させる必要があります。

---

### Question 3 (Troubleshooting)
**問題:** Multisite SD-Access 環境において、IP Transit 網を介した Site-A と Site-B 間のホスト通信が不定期に破棄される。キャプチャを確認したところ、Transit ルータ上で ICMP "Fragmentation Needed and DF Bit Set" が検出されていた。根本原因として最も可能性が高いものはどれか？
* A) Transit ネットワークの OSPF コスト設定ミス
* B) SD-Access Overlay による VXLAN ヘッダー追加に伴う MTU 超過
* C) LISP Control Plane Node での認証キー不一致
* D) SXP セッションの切断

**正解:** **B**  
**解説:** VXLAN カプセル化により、元のパケットに Outer IP + UDP + VXLAN ヘッダー（計 50 バイト以上）が追加されます。Transit 網の MTU が標準の 1500 バイトのままであると、DF ビットが立ったパケットが破棄されるため、アンダーレイ/Transit 網の MTU を Jumbo Frame (1550 以上) に拡張する必要があります。

---

### Question 4 (Design / Architecture)
**問題:** Single-site Fabric デザインにおいて、Control Plane Node (MS/MR) を 2 台配置して高可用性 (HA) を確保する場合の動作仕様として正しい説明はどれか？
* A) Active / Standby 構成となり、Standby 機は Active 故障時のみ動く。
* B) Active / Active 構成となり、Fabric Edge は両方の MS/MR に Map-Register を送信し、両方から負荷分散して応答を受けることができる。
* C) VRRP を使用して仮想 IP を構成しなければならない。
* D) 2 台の MS/MR 間で専用の LISP データベース同期ケーブルを接続する必要がある。

**正解:** **B**  
**解説:** SD-Access の LISP Control Plane Node 冗長化は Active/Active の分散設計です。Fabric Edge はコンフィグされたすべての Map-Server に対して二重に Map-Register を送信し、任意の Map-Resolver から Map-Reply を受領できます。

---

### Question 5 (CLI / Verification)
**問題:** FIAB 機器上で、LISP コントロールプレーン機能が正常に自機内で EID マッピングを受理しているか検証するための最適なコマンドはどれか？
* A) `show ip route vrf VN_CORP`
* B) `show lisp instance-id <ID> ipv4 server`
* C) `show cts sxp connections`
* D) `show nve peers`

**正解:** **B**  
**解説:** `show lisp instance-id <ID> ipv4 server` コマンドを使用すると、LISP Map-Server 機能として受信・登録された EID サイト情報および登録元の RLOC アドレス（FIAB では自機 Loopback）を直接確認できます。

---

## 🔗 参考リソース

* [Cisco SD-Access Solution Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-sda-design-guide.html)
* [Cisco Catalyst Center SD-Access Fabric Provisioning Guide](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/2-3-3/user_guide/b_cisco_dna_center_ug_2_3_3.html)
* [Cisco Live BRKCRS-2810: Cisco SD-Access - Multipanning Single Site and Multisite Deployments](https://www.ciscolive.com/global/on-demand-library.html)
* [Cisco Technical Notes: Fabric in a Box (FIAB) Deployment and Troubleshooting](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215383-configure-and-troubleshoot-sd-access-fa.html)
* [Cisco Command Reference: LISP Commands on IOS-XE](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_lisp/command/lisp-cr-book.html)

---

## 📝 補足（Notes）

### 1. Fabric in a Box (FIAB) 構成図と論理パケットフロー

```
[ Host (10.1.10.50) ] ── (Access Port: Vlan10)
                               │
               ┌───────────────▼────────────────┐
               │    Fabric in a Box (FIAB)      │
               │                                │
               │  [ Fabric Edge Function ]      │
               │          │ (Loopback IPC)      │
               │  [ LISP MS/MR Function ]       │
               │          │                     │
               │  [ Fabric Border Function ]    │
               └───────────────┬────────────────┘
                               │ (VRF-Lite BGP / Vlan100)
                    ┌──────────▼──────────┐
                    │    Fusion Router    │
                    │  (Shared Services)  │
                    └─────────────────────┘
```

### 2. ラボ試験での復習チェックリスト
- [ ] Single-site での Dedicated CP/Border 設定手順を暗記しているか？
- [ ] Fabric in a Box (FIAB) で単一 Loopback0 を指定して LISP MS/MR/Edge を一体設定できるか？
- [ ] `map-cache 0.0.0.0/0 map-request` を忘れずに設定できるか？
- [ ] Transit 網での MTU サイズと VXLAN オーバーヘッドの影響を説明できるか？
- [ ] Fusion Router での VRF-Lite BGP Handoff および Mutual Route Leaking を設定できるか？


## 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076)
    *   SDAファブリック設計の決定版。Single-siteからMultisiteまでの全アーキテクチャ。
*   [**BRKENS-2829: What's New in Cisco SD-Access**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2829)
    *   最新のMultisite Transit（SDA Transit）や、L2/L3 Handoffの進化について。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   ラボ試験で問われる「設計の落とし穴」と、トラブルシューティング手法。

### Configuration ガイド
*   [**Cisco SD-Access Single-Site Design Guide (CVD)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)
*   [**Cisco SD-Access Multisite Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)

### テクニカルノーツ・設定例
*   [**SD-Access Fabric in a Box (FiaB) Technology Overview**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-fiab.html)
*   [**Understanding L3 Handoff and Fusion Router configuration**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)

---

## 📝 補足
- この学習メモは、SD-Accessの設計が「物理的な配線」ではなく「論理的なロールの配置」であることを示しています。CCIE EI ラボ試験では、DNA Center での操作ミスが致命的なアンダーレイ/オーバーレイの不整合を招くため、**LISP Map-Server の状態確認**と **BGP ルート再配送の論理** を完璧にマスターしておくことが合格への最短距離となります。


