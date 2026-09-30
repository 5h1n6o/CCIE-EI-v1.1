---
layout: default
title: 2.1-SD-Access
parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.1 Cisco SD-Access

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要ソフトウェア定義インフラストラクチャ（Software-Defined Infrastructure）テクノロジーである **Cisco SD-Access (Software-Defined Access)** について、Cisco Catalyst Center (旧 Cisco DNA Center) 2.3.x / Cisco ISE 3.x / Cisco IOS-XE 17.x (Catalyst 9000 シリーズ) の実装基準に 100% 準拠して、概念設計から制御・データ・ポリシープレーン、マルチキャスト、ワイヤレス統合、フュージョンルータ構成、設定例、トラブルシューティングまで詳細に解説します。

---

## 📘 概要

* **機能概要:** Cisco SD-Access は、キャンパスネットワークにおける高度な自動化、アイデンティティに基づくエンドツーエンドのマイクロ/マクロセグメンテーション、およびネットワークファブリック（Fabric）アーキテクチャを提供するソリューションです。アンダーレイ（Underlay）の物理IPネットワーク上に、オーバーレイ（Overlay）として LISP (Control Plane)、VXLAN (Data Plane)、Cisco TrustSec (Policy Plane) を統合して構成されます。
* **利用目的:**
  1. **セキュリティとセグメンテーションの簡素化:** IPアドレスに依存しない SGT (Security Group Tag) によるロールベースのアクセス制御。
  2. **Subnet-Free な広域 Layer 2 延伸:** LISP / VXLAN による Anycast Gateway と同一サブネットのキャンパス全域分散。
  3. **ユーザー/端末のロケーションフリー移動:** シームレスな Mobility（有線/無線を問わない L2/L3 移動）。
  4. **運用自動化:** Catalyst Center (Cisco DNA Center) によるプロビジョニング、ポリシー適用、アシュアランスの一元管理。
* **どのような場面で利用するか:** 大規模企業キャンパス網、医療・病院ネットワーク、大学・研究機関、金融機関など、ユーザー・端末の頻繁な移動、IoT 端末の大量接続、厳格なセキュリティセグメンテーションが要求される環境で採用されます。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **Control Plane** | **LISP (Locator/ID Separation Protocol)**: Map Server / Map Resolver (MS/MR) により Endpoint ID (EID) と Routing Locator (RLOC) をマッピング |
| **Data Plane** | **VXLAN (Virtual Extensible LAN)**: L2/L3 パケットを UDP 4789 でカプセル化。ヘッダー内に Virtual Network Identifier (VNI) と Security Group Tag (SGT) を格納 |
| **Policy Plane** | **Cisco TrustSec (CTS)**: SGT (16-bit) によるアクセス制御。ISE から SGACL (Security Group Access Control List) や SGT Exchange Protocol (SXP) を自動配布 |
| **主要コンポーネント** | Fabric Control Plane Node, Fabric Border Node (Internal/External/Anycast), Fabric Edge Node, Fabric Wireless Controller (FWC), Fusion Router |
| **ゲートウェイ方式** | **Anycast Gateway**: すべての Fabric Edge Node 上で同一の IP/MAC アドレス（SVI）を共通設定。分散 L3 ゲートウェイとして動作 |
| **セグメンテーション** | **Macro-segmentation**: Virtual Network (VN / VRF)<br>**Micro-segmentation**: SGT (Security Group Tag) と SGACL |
| **設計上の注意点** | アンダーレイは IS-IS (Catalyst Center 標準) または OSPF/EIGRP/BGP で可達性を確保し、MTU は 9100 バイト以上のジャンボフレームを有効化する必要あり |

---

## 🏗 動作原理

Cisco SD-Access アーキテクチャは、**Control Plane (LISP)**、**Data Plane (VXLAN)**、**Policy Plane (TrustSec)** の 3 つのプレーンが完全に密結合して動作します。

```text
[ Endpoint A (EID_A, SGT_A) ]
             ↓ (有線/無線 Auth: 802.1X / MAB via ISE)
    [ Fabric Edge Node 1 (RLOC_1) ]
             │
             ├─ 1. Control Plane Lookup: LISP Map Request (EID_B)
             │        ↓
             │   [ Control Plane Node (MS/MR) ] ── (EID_B -> RLOC_2)
             │        ↓ Map Reply
             │
             ├─ 2. Data Plane Encapsulation: VXLAN
             │      [ Outer IP: Src=RLOC_1, Dst=RLOC_2 | UDP: 4789 | VXLAN Header: VNI, SGT_A | Inner Packet ]
             │        ↓ (Underlay IP Routing: IS-IS / OSPF)
             │
    [ Fabric Edge Node 2 (RLOC_2) ]
             │
             ├─ 3. Policy Enforcement: SGACL
             │      (SGT_A -> SGT_B ポリシー照合: Permit/Deny)
             │        ↓
[ Endpoint B (EID_B, SGT_B) ]
```

---

## ⚙ 動作シーケンス

端末（Host）が Fabric ネットワークに参加し、通信を開始・完了するまでの動作シーケンスは以下の通りです。

```text
+--------------+     +-------------+     +---------------+     +---------------+     +--------------+
| Host A (Src) |     | Edge Node 1 |     | CP Node(MS/MR)|     | Edge Node 2   |     | Host B (Dst) |
+--------------+     +-------------+     +---------------+     +---------------+     +--------------+
       |                    |                    |                     |                    |
       |--- 1. Onboarding -->|                    |                     |                    |
       |  (802.1X / MAB)    |--- 2. Auth Request (RADIUS) -> Cisco ISE   |                    |
       |                    |<-- 3. Accept (VLAN, SGT=10) -- Cisco ISE   |                    |
       |                    |                    |                     |                    |
       |                    |--- 4. Map Register (EID_A, RLOC_1, SGT=10)->|                    |
       |                    |                    |                     |                    |
       |--- 5. IP Packet -->|                    |                     |                    |
       |  (Dst: EID_B)      |--- 6. Map Request (EID_B) --------------->|                    |
       |                    |<-- 7. Map Reply (RLOC_2) ------------------|                    |
       |                    |                    |                     |                    |
       |                    |--- 8. VXLAN Encapsulated Packet ---------->|                    |
       |                    |    (Outer Dst: RLOC_2, VNI=1001, SGT=10)   |--- 9. SGACL Check -|
       |                    |                    |                     |    (SGT 10 -> Dst) |
       |                    |                    |                     |--- 10. Frame ----> |
```

1. **Host Onboarding**: Host A が Edge 1 のポートに接続し、802.1X または MAB 認証を実行。
2. **Identity & Policy Assignment**: Cisco ISE が認証を行い、動的 VLAN、Virtual Network (VN)、および Security Group Tag (SGT) をバインド。
3. **LISP Map Registration**: Edge 1 は Host A の IP/MAC (EID_A) と自身の Loopback IP (RLOC_1) および SGT を Control Plane Node (MS/MR) に `Map-Register`。
4. **Data Plane Lookup**: Host A が Host B (EID_B) 宛にパケットを送信。Edge 1 はキャッシュに EID_B の RLOC がない場合、CP Node へ `Map-Request` を送出。
5. **Map Reply & VXLAN カプセル化**: CP Node が RLOC_2 を返答。Edge 1 は Outer Header (Src RLOC_1, Dst RLOC_2)、VXLAN Header (VNI, SGT=10)、Inner Header を付与して送出。
6. **Policy Enforcement**: Edge 2 は VXLAN パケットを受信し、ヘッダーから SGT=10 を抽出。Host B の SGT と照合して SGACL (Permit/Deny) を適用し、端末へ転送。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、Cisco SD-Access は筆記・実技（Design & Deploy / Operate / Optimize）の両フェーズで極めて高い配点を占めます。特に CLI によるアンダーレイ/オーバーレイの直接構築・トラブルシューティング、および Catalyst Center / ISE 連携に関する深い理解が問われます。

### Blueprint で重要なポイント

1. **Fabric Terminology & Node Roles**:
   * **Control Plane Node (CP)**: LISP Map Server / Map Resolver (MS/MR) を実行。EID-to-RLOC マッピングデータベースを維持。
   * **Fabric Border Node**: Fabric オーバーレイと外部ネットワーク（Fusion Router / Shared Services / WAN / Data Center）を接続。
     * *Internal Border*: SD-Access ファブリック内の Virtual Network (VN) とキャンパスコア/既存 L3 ネットワークを接続。
     * *External Border*: ファブリック外（Internet / WAN）へのデフォルトルートを提供する Non-Fabric 接続。
     * *Anycast Border*: 同一の Border IP/AS を複数ノードで保持し、L2/L3 双方の冗長性を提供。
   * **Fabric Edge Node**: エンドポイント（有線 PC、IP Phone、AP 等）が接続するアクセス層スイッチ。Anycast Gateway、LISP ETR/ITR、VXLAN VTEP、802.1X Authenticator として機能。
   * **Fabric Wireless Controller (FWC)**: CAPWAP 制御プレーンを維持し、データプレーンは AP / Edge Node 間で VXLAN 直接転送を実行。
2. **Underlay Network Requirements**:
   * アンダーレイは純粋な L3 ネットワーク（IS-IS, OSPF, EIGRP, BGP）。
   * 全 Fabric Node 間の Loopback0 (RLOC) 相互疎通が必須。
   * **Jumbo MTU (>= 9100)**: VXLAN (50 bytes) および LISP encapsulation のオーバーヘッドを吸収するため必須。
3. **Fusion Router Configuration**:
   * SD-Access Fabric VN (VRF) と外部共用サービス (DHCP, DNS, ISE, Catalyst Center) の接続ルータ。
   * **VRF-Lite**: Fusion Router 上で各 VN ごとの VRF を作成し、Border Node と BGP / OSPF でピアリング。
   * **Route Leaking**: 外部共用サービス（Global Routing Table または Shared Services VRF）と各 Tenant VN VRF 間で MP-BGP / Static Route / BGP Route Leaking を実装。

### ラボ試験で設定させられそうな内容

* **CLI による LISP 手動プロビジョニング (Fabric Edge / Control Plane)**: Catalyst Center を使わずに CLI で LISP MS/MR、ETR/ITR、Instance-ID、Instance-VRF マッピングを構築するスキル。
* **Anycast Gateway & SVI 設定**: Fabric Edge 上で全ノード共通の IP/MAC アドレスを持つ Anycast SVI の構成。
* **VXLAN / NVT (Network Virtualization Table) の手動検証**: `show nvt peers` や `show lisp locator-table` による VTEP トラフィックの追跡。
* **Fusion Router の BGP VRF-Lite & Route Leaking**: Border スイッチと Fusion ルータ間での VRF 配下 eBGP/iBGP ピアリングと、Shared Services へのルート・リーキング。

### よくある設定ミス・罠

* **MTU のミスマッチ**: アンダーレイインターフェイスで MTU 9100 を設定し忘れると、VXLAN パケットがフラグメント不可（DF Bit）でドロップされる。
* **LISP Site 登録の鍵不一致**: Control Plane Node (`authentication-key`) と Fabric Edge Node (`authentication-key`) のパスワードが不一致で Map Registration が失敗する。
* **Anycast Gateway MAC アドレスの重複・不一致**: 全 Fabric Edge 上で `ip igmp snooping` や `mac-address` 設定がずれると、端末移動時の ARP 解析が破綻する。
* **Fusion Router での BGP Autonomous System / Route Target の不整合**: VRF ごとの BGP ピアリングで Route Target や Route Distinguisher が重複し、VN 間の分離が破綻する。

---

## 🛠 設定方法

### 1. Control Plane Node (LISP MS/MR) CLI 設定例

```bash
! --- Control Plane Node (MS/MR) ---
router lisp
 ! LISP Site 登録と認証鍵の設定
 site SITE_SD_ACCESS
  authentication-key Cisco123!
  eid-record EID_VN1001 instance-id 1001
   10.1.10.0/24
  !
  eid-record EID_VN1002 instance-id 1002
   10.1.20.0/24
 !
 ipv4 map-server
 ipv4 map-resolver
 !
 instance-id 1001
  type vrfs
  service ipv4
   eid-table vrf VN_RED
   map-server
   map-resolver
  !
 !
 instance-id 1002
  type vrfs
  service ipv4
   eid-table vrf VN_BLUE
   map-server
   map-resolver
```

### 2. Fabric Edge Node (LISP ETR/ITR & Anycast Gateway) CLI 設定例

```bash
! --- Fabric Edge Node ---
vrf definition VN_RED
 rd 65001:1001
 address-family ipv4
  route-target export 65001:1001
  route-target import 65001:1001
 exit-address-family

! Anycast Gateway 用の物理 MAC & SVI
ip routing
mac-address-table static 0000.0c9f.f001 vlan 10 interface Loopback0

interface Vlan10
 mac-address 0000.0c9f.f001
 vrf forwarding VN_RED
 ip address 10.1.10.1 255.255.255.0
 ip helper-address 192.168.100.50
 lisp mobility EID_VN1001
 lisp extended-subnet-mode

router lisp
 locator-set RLOC_SET
  172.16.255.1 priority 1 weight 100
 !
 instance-id 1001
  type vrfs
  service ipv4
   eid-table vrf VN_RED
   itr map-resolver 172.16.255.254
   etr map-server 172.16.255.254 key Cisco123!
   etr
   itr
   database-mapping 10.1.10.0/24 locator-set RLOC_SET
```

### 3. Fusion Router (VRF-Lite & Route Leaking) CLI 設定例

```bash
! --- Fusion Router (Core/Border Next-Hop) ---
vrf definition VN_RED
 rd 65001:1001
 address-family ipv4
 exit-address-family

vrf definition SHARED_SERVICES
 rd 65001:9999
 address-family ipv4
 exit-address-family

! BGP ピアリングと Route Leaking (VRF leaking)
router bgp 65001
 ! VN_RED との接続
 address-family ipv4 vrf VN_RED
  neighbor 192.168.1.2 remote-as 65002
  neighbor 192.168.1.2 activate
  ! Shared Services (DHCP/ISE) へのルートリーキング
  redistribute static
  aggregate-address 10.1.0.0 255.255.0.0 summary-only
 exit-address-family
 !
 address-family ipv4 vrf SHARED_SERVICES
  neighbor 172.16.100.1 remote-as 65001
  neighbor 172.16.100.1 activate
 exit-address-family

! VRF Leaking 用の IP Route / Route-Map 構成
ip route vrf VN_RED 192.168.100.0 255.255.255.0 vrf SHARED_SERVICES 172.16.100.1
ip route vrf SHARED_SERVICES 10.1.10.0 255.255.255.0 vrf VN_RED 192.168.1.2
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| LISP 状態確認 | <code>show ip lisp</code><br><code>show lisp instance-id 1001 ipv4 server</code> |
| EID マッピングの確認 | <code>show lisp site</code><br><code>show lisp instance-id 1001 ipv4 database</code> |
| LISP カッシュ (ITR) 確認 | <code>show lisp instance-id 1001 ipv4 map-cache</code> |
| VXLAN VTEP / NVT ピア状態 | <code>show nvt peers</code><br><code>show access-tunnel summary</code> |
| Anycast Gateway / SVI 確認 | <code>show ip interface brief \| include Vlan</code><br><code>show lisp mobility</code> |
| SGT (TrustSec) 割り当て確認 | <code>show cts interface</code><br><code>show cts environment-data</code> |
| SGACL ポリシー適用状態 | <code>show cts role-based permissions</code><br><code>show ip access-lists role-based</code> |
| LISP パケットデバッグ | <code>debug lisp control-plane all</code><br><code>debug lisp mobility</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| エンドポイント間疎通不能 (Same VN) | Control Plane Node に EID が登録されていない (`Map-Register` 失敗) | <code>show lisp site</code><br><code>show lisp instance-id \<ID\> ipv4 database</code> | Edge と CP 間の `authentication-key` を確認。Loopback0 間の IP 疎通をアンダーレイで復旧 |
| エンドポイント間疎通不能 (Cross Edge) | Edge Node 上の ITR Map-Cache エラー、または RLOC 宛ての VXLAN ドロップ | <code>show lisp instance-id \<ID\> ipv4 map-cache</code> | アンダーレイの IP 疎通と MTU (9100) を確認。`Map-Request` が CP に到達しているかデバッグ |
| 端末の Mobility (L2 Roaming) 失敗 | Mobility 検出未有効、または Anycast MAC の不一致 | <code>show lisp mobility</code><br><code>show mac-address-table</code> | Vlan インターフェイス上で `lisp mobility` および統一 MAC アドレスが設定されているか確認 |
| 外部ネットワーク (Internet/DHCP) へ通信不能 | Fusion Router での VRF ピアリング不成立、または Route Leaking の未設定 | <code>show ip route vrf \<VN\></code><br><code>show ip bgp vpnv4 vrf \<VN\> summary</code> | Fusion Router 上の VRF-Lite BGP ピアリング状態および Mutual Route Leaking コンフィグを修正 |
| SGACL による通信ドロップ | Cisco ISE から Edge スイッチへ SGT / SGACL が正しくプッシュされていない | <code>show cts role-based permissions</code><br><code>show cts environment-data</code> | ISE で PAC (Protected Access Credential) と RADIUS 属性 (cisco-av-pair:cts:security-group-tag) を確認 |

---

## ⚠ 制限事項

* **アンダーレイプロトコル制限**: アンダーレイでの OSPF / IS-IS 構成時、P2P リンクタイプが強く推奨されます。Broadcast タイプはネイバー形成の遅延や DR/BDR 選出のオーバーヘッドを引き起こします。
* **MTU 制限**: アンダーレイ上の全スイッチおよび物理リンクで **MTU 9100 以上** の Jumbo Frame 設定が必須です（カプセル化ヘッダーによる断片化を回避するため）。
* **VNI (Virtual Network Identifier) 範囲**: L2 VNI (Subnet/VLAN) と L3 VNI (VN/VRF) は識別子が異なります。Catalyst Center 自動生成時と CLI 手動設定時での番号競合に注意が必要です。
* **プラットフォーム依存**: Cisco Catalyst 9300 / 9400 / 9500 / 9600 シリーズでのみ完全な Fabric Edge / Border 機能がサポートされます。Catalyst 1000/2000 シリーズは Extended Node としてのみ参加可能です。

---

## 🔄 他技術との関連

* **LISP (Locator/ID Separation Protocol)**: SD-Access の Control Plane 技術。IP アドレスを EID (Endpoint Identifier) と RLOC (Routing Locator) に分離してトラッキング。
* **VXLAN (Virtual Extensible LAN)**: SD-Access の Data Plane 技術。L2 Frame を UDP 4789 で包み込み、ヘッダーに VNI (16 Million L2/L3 Segments) と SGT を格納。
* **Cisco TrustSec (CTS)**: SD-Access の Policy Plane 技術。16-bit の SGT を使用して IP に依存しない一元的なアクセス制御ポリシー (SGACL) を適用。
* **Cisco ISE (Identity Services Engine)**: ユーザー・端末の認証・認可 (802.1X/MAB)、動的 VLAN/SGT 割り当て、ポリシーマトリクスの管理を実行。
* **BGP VRF-Lite / MP-BGP**: Fabric Border と Fusion Router 間のマルチテナント (VN) エクステンションおよび外部ルート交換に必須。

---

## 🧩 比較表

### LISP vs VXLAN vs TrustSec (プレーン別の役割)

| 項目 | Control Plane (LISP) | Data Plane (VXLAN) | Policy Plane (TrustSec) |
| --- | --- | --- | --- |
| **役割** | エンドポイントの位置 (EID ➔ RLOC) を管理 | パケットのカプセル化とオーバーレイ転送 | アイデンティティベースのアクセス制御 |
| **プロトコル** | LISP (UDP 4341 / 4342) | VXLAN-GPO (UDP 4789) | CTS (SGT / SGACL / SXP) |
| **格納データ** | EID, RLOC, VNI, Instance-ID | Inner L2/L3 Frame, VNI, SGT | 16-bit Security Group Tag (SGT) |
| **制御対象** | Map Server / Map Resolver / Edge | VTEP (Fabric Edge / Border) | Cisco ISE / Fabric Edge (Enforcement) |

### SD-Access vs 従来型キャンパス LAN (VLAN/STP)

| 項目 | 従来型キャンパス LAN | Cisco SD-Access Fabric |
| --- | --- | --- |
| **トポロジー** | L2 (Spanning Tree) + L3 Core | 純粋な L3 アンダーレイ + LISP/VXLAN オーバーレイ |
| **ゲートウェイ** | HSRP / VRRP (Core / Distribution) | **Anycast Gateway** (全 Fabric Edge で同一 IP/MAC) |
| **セグメンテーション** | VLAN / VRF-Lite (IP依存) | **VN (VRF)** + **SGT (ロールベース)** |
| **Mobility** | L2 延伸 (OTV / VXLAN 手動) | シームレスな L2/L3 自動 Mobility |
| **運用形態** | CLI 手動設定 | **Catalyst Center (Cisco DNA Center)** 自動プロビジョニング |

---

## 💡 ベストプラクティス

1. **アンダーレイ設計**:
   * アンダーレイ IGP には IS-IS または OSPF を使用し、全インターフェイスを `point-to-point` に設定する。
   * ルーティングの安定性と高速コンバージエンスのため、Loopback0 を Router-ID / RLOC として割り当てる。
   * 全リンクで MTU 9100 を一括有効化する。
2. **Control Plane 冗長化**:
   * 大規模環境では 2 台以上の Control Plane Node を配置し、Map Server / Map Resolver の同期を確保する。
3. **Fusion Router と外部接続**:
   * Border Node と Fusion Router 間は VRF-Lite BGP ピアリングを推奨。
   * Shared Services (DHCP, DNS, ISE, Catalyst Center) へのルートは最小限の静的ルート/BGP フィルタでリーキングする。
4. **ワイヤレス統合 (Fabric Wireless)**:
   * Access Point (AP) は Dedicated WLC / Embedded WLC に制御プレーン (CAPWAP) を接続し、データプレーンは AP 自身が Fabric Edge として VXLAN 直接カプセル化を行う。

---

## 📝 ラボ学習・設定サンプル例

### シナリオ 1: アンダーレイ (IS-IS & Jumbo MTU) 構築

* **問題**: 3 台のスイッチ (Edge1, Edge2, CP1) 間で SD-Access 用の安定した L3 アンダーレイネットワークを構築せよ。
* **要件**:
  1. アンダーレイ IGP として IS-IS プロセス `UNDERLAY` を使用すること。
  2. 全インターフェイスの MTU を 9100 バイトに設定すること。
  3. 全ノードの Loopback0 (172.16.255.x/32) 間で完全な L3 疎通を確保すること。
* **設定例**:
```bash
! --- Node 1 (Edge1) ---
system-mtu 9100

interface Loopback0
 ip address 172.16.255.1 255.255.255.255
 ip router isis UNDERLAY

interface GigabitEthernet1/0/1
 description To-CP1
 no switchport
 ip address 10.0.12.1 255.255.255.252
 ip router isis UNDERLAY
 isis network point-to-point
 mtu 9100

router isis UNDERLAY
 net 49.0001.1720.1625.5001.00
 metric-style wide
```
* **検証方法**:
  * `show isis neighbors` で全対向が `UP` 状態であることを確認。
  * `ping 172.16.255.2 size 9000 df-bit` でジャンボフレームが断片化されずに疎通することを確認。

---

### シナリオ 2: LISP Control Plane Node (MS/MR) の構成

* **問題**: CP1 を SD-Access Fabric の Control Plane Node (Map Server / Map Resolver) として構成せよ。
* **要件**:
  1. Virtual Network `VN_CORP` (Instance-ID: 1001) を作成すること。
  2. EID プレフィックス `10.1.10.0/24` の登録を認証キー `CiscoKey123` で許可すること。
* **設定例**:
```bash
! --- CP1 (Control Plane Node) ---
router lisp
 site FABRIC_SITE
  authentication-key CiscoKey123
  eid-record EID_CORP instance-id 1001
   10.1.10.0/24
  !
 ipv4 map-server
 ipv4 map-resolver
 !
 instance-id 1001
  type vrfs
  service ipv4
   eid-table vrf VN_CORP
   map-server
   map-resolver
```
* **検証方法**:
  * `show ip lisp` で Map Server / Map Resolver が active になっていることを確認。
  * `show lisp instance-id 1001 ipv4 server` で設定したサイトと EID レコードを確認。

---

### シナリオ 3: Fabric Edge 上での Anycast Gateway と LISP ETR/ITR 設定

* **問題**: Edge1 および Edge2 上で同一の分散 L3 ゲートウェイ (Anycast Gateway) を構成せよ。
* **要件**:
  1. VLAN 10 に IP アドレス `10.1.10.1/24` と Virtual MAC `0000.0c9f.f001` を設定すること。
  2. VRF `VN_CORP` にバインドし、LISP ETR/ITR として CP1 (172.16.255.254) に登録すること。
* **設定例**:
```bash
! --- Edge1 & Edge2 共通 ---
vrf definition VN_CORP
 rd 65000:1001
 address-family ipv4
  route-target export 65000:1001
  route-target import 65000:1001
 exit-address-family

interface Vlan10
 mac-address 0000.0c9f.f001
 vrf forwarding VN_CORP
 ip address 10.1.10.1 255.255.255.0
 lisp mobility EID_CORP
 lisp extended-subnet-mode

router lisp
 locator-set FABRIC_RLOC
  172.16.255.1 priority 1 weight 100
 !
 instance-id 1001
  type vrfs
  service ipv4
   eid-table vrf VN_CORP
   itr map-resolver 172.16.255.254
   etr map-server 172.16.255.254 key CiscoKey123
   database-mapping 10.1.10.0/24 locator-set FABRIC_RLOC
   itr
   etr
```
* **検証方法**:
  * `show lisp instance-id 1001 ipv4 database` でローカルの EID サブネットがデータベースに正しくマッピングされているか確認。
  * `show lisp mobility` で VLAN 10 が LISP モビリティ有効になっているか確認。

---

### シナリオ 4: エンドポイント認証 (802.1X / MAB) と Dynamic VLAN / SGT 付与

* **問題**: Edge1 のアクセスポートにおいて、Cisco ISE による動的 VLAN および SGT の割り当てを構成せよ。
* **要件**:
  1. 802.1X および MAB 認証を有効化すること。
  2. 認証成功時、ISE から返却された VLAN ID (VLAN 10) と SGT (Tag 10) を動的にバインドすること。
* **設定例**:
```bash
! --- Edge1 ---
aaa new-model
aaa authentication dot1x default group radius
aaa authorization network default group radius

radius server ISE_SERVER
 address ipv4 192.168.100.50 auth-port 1812 acct-port 1813
 key CiscoRadiusPass

interface GigabitEthernet1/0/10
 switchport mode access
 authentication port-control auto
 dot1x pae authenticator
 mab
```
* **検証方法**:
  * 端末接続後、`show authentication sessions interface g1/0/10 details` を実行。
  * `Status: Auth Success`、`VLAN: 10`、`Security Group Tag: 10` が付与されていることを検証。

---

### シナリオ 5: Fabric Border Node と Fusion Router 間の VRF-Lite BGP ピアリング

* **問題**: Fabric Border Node と Fusion Router 間で VRF `VN_CORP` のルート交換を構成せよ。
* **要件**:
  1. Border と Fusion 間で eBGP (Border: AS 65001, Fusion: AS 65002) を確立すること。
  2. Fabric 内の EID サブネット `10.1.0.0/16` を Fusion へ広報し、Fusion から外部デフォルトルートを受信すること。
* **設定例**:
```bash
! --- Fabric Border Node ---
router bgp 65001
 address-family ipv4 vrf VN_CORP
  neighbor 192.168.1.2 remote-as 65002
  neighbor 192.168.1.2 activate
  network 10.1.0.0 mask 255.255.0.0
 exit-address-family

! --- Fusion Router ---
router bgp 65002
 address-family ipv4 vrf VN_CORP
  neighbor 192.168.1.1 remote-as 65001
  neighbor 192.168.1.1 activate
  default-information originate
 exit-address-family
```
* **検証方法**:
  * `show ip bgp vpnv4 vrf VN_CORP summary` で BGP ピアが `Established` であることを確認。
  * Border 上で `show ip route vrf VN_CORP` を実行し、デフォルトルート `0.0.0.0/0` が受信されていることを確認。

---

### シナリオ 6: Fusion Router での Shared Services Route Leaking 構成

* **問題**: Fusion Router 上で Tenant VRF `VN_CORP` と Global Shared Services VRF `SHARED_SVC` (DHCP 192.168.100.50) 間で相互ルートリーキングを設定せよ。
* **要件**:
  1. `VN_CORP` から `192.168.100.50/32` への通信を可能にすること。
  2. `SHARED_SVC` から Fabric EID プレフィックス `10.1.10.0/24` への戻りルートをリークすること。
* **設定例**:
```bash
! --- Fusion Router ---
ip route vrf VN_CORP 192.168.100.50 255.255.255.255 GigabitEthernet0/1 172.16.100.1 global
ip route vrf SHARED_SVC 10.1.10.0 255.255.255.0 vrf VN_CORP 192.168.1.1
```
* **検証方法**:
  * `show ip route vrf VN_CORP 192.168.100.50` で Static Route が有効になっているか検証。
  * Edge1 に接続された端末から `192.168.100.50` (DHCP) 宛ての ping が疎通することを確認。

---

### シナリオ 7: Dynamic Host Mobility (L2 Roaming) の手動検証

* **問題**: Host A (10.1.10.50) が Edge1 から Edge2 へ物理的に移動した際の LISP Control Plane の再登録動作を確認・構成せよ。
* **要件**:
  1. Host A が Edge2 に接続した際、Edge2 が CP Node へ即座に `Map-Register` を発行すること。
  2. CP Node が Edge1 へ `Map-Notify` / `SMR (Solicit-Map-Request)` を送出し、旧キャシュを無効化すること。
* **設定例**:
```bash
! --- Edge2 (移動先スイッチ) ---
! 特別な追加コンフィグは不要。LISP Mobility が動作していれば自動検知
```
* **検証方法**:
  * Edge2 で `show lisp mobility` を実行し、Host A (10.1.10.50) がローカル EID として検出されていることを確認。
  * CP Node で `show lisp site 10.1.10.50` を実行し、RLOC が Edge1 (172.16.255.1) から Edge2 (172.16.255.2) に更新されたことを確認。

---

### シナリオ 8: Cisco TrustSec (CTS) SGT & SGACL ポリシー構成

* **問題**: Edge1 スイッチにおいて、SGT 10 (Sales) から SGT 20 (Finance) への通信を拒否する SGACL を設定・適用せよ。
* **要件**:
  1. Role-based Access List `NO_FINANCE` を作成し、IP 通信を deny すること。
  2. SGT 10 ➔ SGT 20 のロールベースバインディングにバインドすること。
* **設定例**:
```bash
! --- Edge1 ---
cts status
cts role-based permission
 ip access-list role-based NO_FINANCE
  deny ip
  permit ip log

cts role-based policy permissions src-gt 10 dst-gt 20 NO_FINANCE
```
* **検証方法**:
  * `show cts role-based permissions` を実行し、`Src SGT: 10, Dst SGT: 20` に `NO_FINANCE` がバインドされていることを確認。
  * SGT 10 の端末から SGT 20 の端末へ ping を送出し、ドロップされることおよびパケットカウンタが増加することを確認。

---

### シナリオ 9: Fabric Wireless Controller (FWC) と Fabric Edge 間の Integrated Wireless 構成

* **問題**: Catalyst 9800 埋め込みワイヤレス (Embedded WLC) を使用し、SD-Access Fabric Wireless の制御/データプレーンを分離構成せよ。
* **要件**:
  1. AP の CAPWAP 制御面は WLC と接続すること。
  2. クライアントデータパケットは AP から Fabric Edge へ VXLAN で直接カプセル化転送すること。
* **設定例**:
```bash
! --- Catalyst 9800 WLC ---
wlan WLAN_CORP 1 corp-ssid
 client vlan VN_CORP_VLAN10

wireless profile fabric FABRIC_PROF
 fabric-netvni 1001

wireless tag policy FABRIC_POLICY
 wlan WLAN_CORP policy FABRIC_PROF
```
* **検証方法**:
  * `show wireless client summary` でワイヤレスクライアントが Fabric Mode で接続されていることを確認。
  * Fabric Edge 上で `show access-tunnel summary` を実行し、AP との間に VXLAN トンネルが確立していることを確認。

---

### シナリオ 10: Head-End Replication による SD-Access オーバーレイマルチキャスト構築

* **問題**: SD-Access Fabric 内でアンダーレイマルチキャストを使わずに、Head-End Replication (Ingress Replication) による L2/L3 マルチキャスト転送を構成せよ。
* **要件**:
  1. VRF `VN_CORP` において LISP Head-End Replication を有効化すること。
  2. 複数の Fabric Edge へマルチキャストパケットをユニキャストカプセル化して複製・送信すること。
* **設定例**:
```bash
! --- Edge1 & Edge2 ---
router lisp
 instance-id 1001
  type vrfs
  service ipv4
   head-end-replication
```
* **検証方法**:
  * `show ip mroute vrf VN_CORP` を実行し、マルチキャストツリーの Outgoing Interface List に LISP トンネルインターフェイスが含まれていることを検証。

---

## ❓ 想定試験問題

### 問題 1 (コンフィグ読解・実装)
**設問**: 以下の Fabric Edge スイッチのコンフィグにおいて、端末が VLAN 10 に接続して IP パケットを送信した際、Control Plane Node への `Map-Request` が送出されず、異なる Edge に接続された他端末と疎通できない障害が発生している。原因として最も適切なものを 1 つ選べ。

```bash
router lisp
 locator-set RLOC_SET
  172.16.255.1 priority 1 weight 100
 !
 instance-id 1001
  type vrfs
  service ipv4
   eid-table vrf VN_RED
   etr map-server 172.16.255.254 key Cisco123!
   database-mapping 10.1.10.0/24 locator-set RLOC_SET
   etr
```

* A) `locator-set` 内の IP アドレス `172.16.255.1` が間違っている。
* B) `service ipv4` 配下に `itr` コマンドおよび `itr map-resolver 172.16.255.254` が欠落しているため。
* C) `database-mapping` のプレフィックス長が `/24` ではなく `/32` で記載されるべきであるため。
* D) `authentication-key` の大文字小文字が一致していないため。

**正解**: **B**  
**解説**: Fabric Edge スイッチが ITR (Ingress Tunnel Router) として機能し、未知の EID 宛てパケットに対して CP Node (Map Resolver) へ `Map-Request` を送出するには、`itr` および `itr map-resolver <IP>` の設定が不可欠です。本コンフィグでは ETR (Egress Tunnel Router) 機能のみが有効化されており、ITR 機能が欠落しています。

---

### 問題 2 (トラブルシューティング)
**設問**: SD-Access 環境において、移動端末 (10.1.10.50) が Edge1 から Edge2 へローミングした直後、約 3 分間通信が切断される問題が発生した。調査したところ、アンダーレイの L3 疎通や ISE 認証は正常であった。最も可能性の高い原因はどれか。

* A) Edge1 と Edge2 間で MTU が 1500 バイトに制限されており、LISP パケットがドロップした。
* B) Edge2 上の VLAN インターフェイスに `lisp mobility` コマンドが設定されておらず、動的 EID 検出が行われなかった。
* C) Fusion Router 上で BGP ルートリーキングが正しく設定されていなかった。
* D) Cisco ISE 上で SGACL のパーミッションが Permit All に設定されていなかった。

**正解**: **B**  
**解説**: Anycast Gateway が動作する SVI インターフェイス上に `lisp mobility <EID_NAME>` が設定されていない場合、スイッチはローカルポートに新しく学習された MAC/IP アドレスを LISP Mobility イベントとして検知・CP Node へ即座に `Map-Register` できません。その結果、ARP/L2 テーブルのエージングタイマーが切れるまで旧 Edge1 へトラフィックが送られ続け、通信断が発生します。

---

### 問題 3 (Design / アーキテクチャ)
**設問**: 大規模キャンパス網に SD-Access アーキテクチャを導入する設計において、アンダーレイ IP ネットワークの MTU 値に関する要件として最も適切な説明を選べ。

* A) アンダーレイの全リンクで Standard MTU (1500 バイト) を維持し、Edge スイッチで IP パケットのフラグメント処理を行う。
* B) LISP カプセル化による 20 バイトのオーバーヘッドのみを考慮し、MTU を 1520 バイトに統一する。
* C) VXLAN カプセル化 (50 バイト以上) および LISP パケットのフラグメント不可 (DF Bit) 動作に対応するため、アンダーレイ全体で 9100 バイト以上の Jumbo MTU を適用する。
* D) アンダーレイの MTU はオーバーレイの転送性能に影響を与えないため、デフォルト値のままでよい。

**正解**: **C**  
**解説**: SD-Access の Data Plane である VXLAN カプセル化は、元の L2/L3 パケットに対して Outer IP (20B) + UDP (8B) + VXLAN Header (8B) + Inner Ethernet (14B) 等のオーバーヘッド (最低 50 バイト) を付加します。また、VXLAN トラフィックは破棄やフラグメントを回避するため、アンダーレイ物理ネットワーク全体で 9100 バイトの Jumbo MTU を統一設定することが推奨されます。

---

### 問題 4 (実装・Fusion Router)
**設問**: SD-Access Fabric の Border Node と Fusion Router 間でマルチテナント構成 (VN1, VN2) を拡張するため、VRF-Lite を構成した。Fusion Router 上で外部共用サービス (DHCP サーバー 192.168.100.50) へ両 VN からアクセス可能にするための設計として、正しいアプローチはどれか。

* A) Fusion Router 上で全 VN を Single VRF に集約し、アンダーレイ BGP で広報する。
* B) Fusion Router 上で各 VN 用の VRF と Shared Services 用の VRF を作成し、Static Route または MP-BGP を使用して選択的な相互ルートリーキングを設定する。
* C) Border Node 上で LISP Map Server に DHCP サーバーの IP を直接 EID として登録する。
* D) Fusion Router を使用せず、Fabric Edge 上で直接 Global Routing Table へのデフォルトルートを挿入する。

**正解**: **B**  
**解説**: Fabric 外部の共用サービス (DHCP, DNS, ISE 等) へ複数 VN (VRF) から安全にアクセスさせる場合、Fusion Router 上で VRF-Lite を運用し、テナント VRF と Shared Services VRF 間で必要な IP / プレフィックスのみを選択的に Route Leaking (Static or BGP leaking) する構成が標準ベストプラクティスです。

---

### 問題 5 (Troubleshooting / CLI コマンド)
**設問**: Fabric Edge スイッチ上で特定の端末 (EID: 10.1.10.20) の現在の RLOC (Locator IP) アドレスおよび LISP キャッシュの有効期限を確認するために最も適切な CLI コマンドはどれか。

* A) `show ip route 10.1.10.20`
* B) `show lisp instance-id 1001 ipv4 map-cache 10.1.10.20`
* C) `show cts role-based permissions`
* D) `show access-tunnel summary`

**正解**: **B**  
**解説**: Fabric Edge (ITR) がリモート端末宛てパケットを転送する際、目的地の EID から RLOC へのマッピング情報は LISP Map-Cache に保持されます。特定の EID の RLOC マッピング、TTL、状態を確認するには `show lisp instance-id <ID> ipv4 map-cache <EID>` を使用します。

---

## 🔗 参考リソース

### Cisco 公式ドキュメント・Design Guides
* [Cisco SD-Access Solution Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-sda-design-guide.html)
* [Cisco Catalyst Center (Cisco DNA Center) User Guide](https://www.cisco.com/c/en/us/support/cloud-systems-management/dna-center/products-user-guide-list.html)
* [Cisco LISP Configuration Guide (Cisco IOS-XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_lisp/configuration/xe-17/iproute-lisp-xe-17-book.html)
* [Cisco TrustSec Configuration Guide](https://www.cisco.com/c/en/us/td/docs/switches/lan/trustsec/configuration/guide/trustsec.html)

### Cisco Live セッション資料
* [BRKCRS-2810 - Cisco SD-Access - Architecture and Fundamentals (Cisco Live)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810)
* [BRKCRS-2811 - Cisco SD-Access - Deep Dive into Control and Data Plane (Cisco Live)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2811)
* [BRKCRS-2813 - Cisco SD-Access - Integration with Existing Campus Networks (Cisco Live)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2813)

### Technical Notes & Configuration Examples
* [Understand Cisco SD-Access Border Node Types and Deployment](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215456-sd-access-border-node-deployment.html)
* [Troubleshoot Cisco SD-Access Fabric Edge Host Onboarding](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/217210-troubleshoot-sd-access-host-onboarding.html)

---

## 📝 補足（Notes）

### 1. LISP Terminology Quick Reference
* **EID (Endpoint Identifier)**: エンドポイント（ホスト）に割り当てられる IP アドレス（オーバーレイ空間）。
* **RLOC (Routing Locator)**: Fabric Node (Edge/Border) の Loopback0 IP アドレス（アンダーレイ空間）。
* **ITR (Ingress Tunnel Router)**: EID 宛てパケットを受信し、CP Node に RLOC を問い合わせて LISP/VXLAN カプセル化を行うノード（Fabric Edge）。
* **ETR (Egress Tunnel Router)**: LISP/VXLAN パケットを受信し、カプセル化を解除して直結する EID へ転送するノード（Fabric Edge）。
* **MS/MR (Map Server / Map Resolver)**: EID ➔ RLOC のマッピングデータベースを管理する Control Plane ノード。

### 2. SGT (Security Group Tag) と SGACL 補足
* **SGT**: 16-bit の識別子（1 〜 65535）。1792 などの特定領域は予約済み。
* **VXLAN カプセル化時の SGT**: VXLAN-GPO (Group Policy Option) ヘッダー内の 16-bit フィールドに物理的に埋め込まれてネットワークを伝播。
* **SGACL の処理順序**: 常に受信側（Egress / Destination Fabric Edge）スイッチでパケットのカプセル化を解除した直後に評価・適用されます。

---
