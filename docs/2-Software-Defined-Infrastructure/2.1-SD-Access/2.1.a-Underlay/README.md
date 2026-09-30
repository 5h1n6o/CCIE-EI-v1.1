---
layout: default
title: 2.1.a-Underlay
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.1.a Underlay

CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における Cisco SD-Access（Software-Defined Access）ファブリックの物理的・論理的土台となる **2.1.a Underlay**（Manual, LAN Automation / PnP, Device discovery and management, Extended nodes / Policy extended nodes）について、Cisco Catalyst Center（旧 Cisco DNA Center）2.3.x、Cisco IOS-XE 17.x（Catalyst 9000 シリーズ、IE3000 シリーズ等）の実装基準に 100% 準拠した詳細な学習メモです。

---

## 📘 概要

SD-Access パラダイムにおける **Underlay（アンダーレイ）** とは、オーバーレイネットワーク（LISP コントロールプレーン、VXLAN データプレーン、Cisco TrustSec ポリシープレーン）を安定してカプセル化・転送するための **IP Reachability（L3 疎通性）を提供する層** です。

* **機能概要:** 各ファブリックデバイス（Control Plane Node, Border Node, Fabric Edge Node）間の Loopback0 アドレス間およびポイントツーポイント（PtP）物理リンク間において、単一のグローバルルーティングテーブル（GRT）上で高度な L3 パケット転送を提供します。
* **利用目的:** オーバーレイにおける EID（Endpoint ID）と RLOC（Routing Locator）のバインド情報、および Control Plane メッセージ（LISP UDP 4342）や Encapsulated Data（VXLAN UDP 4789）を確実に転送すること。
* **適用場面:** 
  * **Manual Underlay:** 既存ネットワークインフラの流用や、高度なカスタム制御・サードパーティ機器との相互運用が必要な環境。
  * **LAN Automation (PnP):** 新規グリーンフィールド構築において、ゼロタッチで IS-IS ルーティング、PtP IP アドレス割り当て、Loopback アドレス生成、Jumbo MTU を自動プロビジョニングする環境。
  * **Extended Nodes / Policy Extended Nodes:** 工場床面や屋外、コンパクトスイッチ（Catalyst IE3000 / Catalyst 2960-CX 等）を Fabric Edge 傘下に L2 / SGT 拡張接続する環境。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主要 IGP プロトコル** | **IS-IS（Cisco 推奨 / LAN Automation デフォルト）**、または OSPFv2。単一 Area / Level-2。 |
| **ルーティング構成** | 全直結リンクを **Point-to-Point** 指定。Loopback0（/32 IP）を Router ID および RLOC として使用。 |
| **MTU 設計** | **Jumbo MTU（9100 バイト以上、推奨 9216 バイト）**。VXLAN カプセル化による 50 バイト超のオーバーヘッドを吸収しフラグメンテーションを防止。 |
| **LAN Automation** | Catalyst Center（DNAC）の Plug and Play（PnP）エージェントと DHCP オプション 43 を活用した自動化プロビジョニング。 |
| **Extended Node (EN)** | Fabric Edge の下位に L2 Trunk 接続されるスイッチ。LISP/VXLAN 未実装。FE 上の 802.1Q VLAN にブリッジング。 |
| **Policy Extended Node (PEN)** | FE の下位に接続され、802.1X/MAB 認証および **SGT インラインタギングを直接実行可能** な高度な拡張ノード。 |
| **マルチキャスト（Underlay）** | Head-End Replication（Ingress Replication）非使用時、PIM-SM / SSM をアンダーレイで構成し BUM トラフィックを転送。 |
| **制限事項** | アンダーレイ上での VRF 構成（VRF-Lite 等）はオーバーレイと分離。アンダーレイは常に Global Routing Table (GRT) で動作。 |

---

## 🏗 動作原理

### 1. アンダーレイ構成の基本アーキテクチャ

アンダーレイは完全な Routed Access（L3 アクセス）トポロジーで構成されます。Core / Distribution / Edge 間のすべての L2 スイッチングを排除し、アクセスポート直上から L3 パケットとして転送します。

```
[ Catalyst Center (DNAC) ]
         │ (Netconf/RESTCONF/SSH/PnP)
         ▼
[ Fabric Border / Control Plane ] (Loopback0: 10.10.10.1/32)
         │  PtP Routed Link (MTU 9100, IS-IS Metric 10)
         ▼
[ Fabric Edge Node 1 ] (Loopback0: 10.10.10.2/32) ── [ Fabric Edge Node 2 ] (Loopback0: 10.10.10.3/32)
         │  Trunk (802.1Q)                                 │  Trunk (802.1Q + SGT Tag)
         ▼                                                 ▼
[ Extended Node (EN) ]                           [ Policy Extended Node (PEN) ]
  (L2 Switch: IE3400)                              (CTS SGT Capable Switch)
```

### 2. LAN Automation の動作メカニズム

LAN Automation は、Seed デバイス（既存の Border / Control Plane スイッチ）と Catalyst Center の PnP サーバー機能を連携させ、未設定のファブリックスイッチ（PNP Agent）を自動的にアンダーレイへ参加させる仕組みです。

```
[ PnP Switch (New) ]         [ Seed Device ]            [ Catalyst Center (DNAC) ]
         │                          │                               │
         │─── DHCP Discover ───────>│                               │
         │    (Option 60: Cisco PnP)│                               │
         │                          │─── DHCP Relay ───────────────>│
         │<── DHCP Offer ───────────│                               │
         │    (Option 43: DNAC IP)  │<── DHCP Relay ────────────────│
         │                          │                               │
         │─── HTTPS PnP Hello ─────────────────────────────────────>│
         │    (Serial Number, Model)                                │
         │                          │                               │
         │<── Download Day-0 Config & Image ────────────────────────│
         │    (IS-IS, PtP IPs, Loopback0, MTU 9100)                 │
         │                          │                               │
         │─── Report Success ───────────────────────────────────────>│
```

---

## ⚙ 動作シーケンス

### LAN Automation 実行からアンダーレイ完了までの詳細手順

1. **Seed デバイスの設定と準備:**
   * Catalyst Center 上で Seed デバイス（通常は Border ノード）を指定。
   * LAN Automation 用の IP アドレスプール（/24 等の Temporary Pool および Permanent Loopback / Link Pool）を定義。
   * Seed デバイス上に DHCP サーバープロファイル（または Relay）が Catalyst Center により自動生成される。

2. **PnP デバイスの物理接続と起動:**
   * 新品（未設定）の Catalyst 9000 スイッチを Seed デバイスに PnP ポート（通常 Uplink ポート）経由で接続し電源投入。
   * デバイスはデフォルトで CDP/LLDP を有効化し、全ポートで DHCP Client リクエスト（DHCP Option 60: `Cisco PnP`）を送出。

3. **DHCP 応答と PnP リダイレクト:**
   * Seed デバイス（または DHCP サーバー）は、DHCP Option 43（Catalyst Center の IP アドレス情報: e.g., `5A1D;B2;IC10.1.1.100;4A08;`）を含む IP アドレスを新スイッチへ配布。

4. **Day-0 コンフィグの適用とプロビジョニング:**
   * PnP エージェントは Catalyst Center へ HTTPS（ポート 443）で接続し、自身のマシーン情報（シリアル番号）を報告。
   * Catalyst Center は定義されたアンダーレイテンプレートに基づき、以下を動的生成・流し込み:
     * Loopback0 アドレス（/32）の自動割り当て
     * Point-to-Point インターフェイスの L3 化（`no switchport`）および IP 割り当て（`ip unnumbered Loopback0` または /30, /31）
     * IS-IS プロセス（`router isis-global`）の構成および全 PtP / Loopback0 ポートでの有効化
     * システムグローバル MTU およびインターフェイス MTU の 9100 バイト変更
     * CLI/SSH ログイン認証情報および SNMP/NETCONF 設定

5. **LAN Automation の停止（Stop LAN Automation）:**
   * 全新規デバイスのプロビジョニング完了後、Catalyst Center 上で「Stop LAN Automation」を実行。
   * Seed デバイス上の臨時 DHCP サーバー設定がクリーンアップされ、アンダーレイ構成が静的に固定化・保護される。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Lab 試験における主要評価ポイント
* **Manual Underlay の手動構成:** 提示されたトポロジー要件に従い、IS-IS または OSPFv2 を用いて全ファブリックデバイス間に完全な L3 Reachability を構築できるか。
* **Jumbo MTU と Ping 検証:** 全リンクで MTU 9100/9216 が設定されているか。`ping <RLOC-IP> size 8000 df-bit` でフラグメンテーションなしに疎通することを確認できるか。
* **IS-IS ネイバーシップ調整:** 全 PtP リンクで `isis network point-to-point` が投入され、DIS（Designated Intermediate System）選出がバイパスされているか。
* **LAN Automation 前提要件のトラブルシュート:** DHCP Option 43 の記述フォーマット不備や、Seed デバイスと PnP デバイス間の MTU 不一致、CDP 無効化に伴う PnP 失敗を特定・修復できるか。
* **Extended Node (EN) / Policy Extended Node (PEN) の接続要件:** 
  * EN/PEN と FE 間の Trunk ポートで許可 VLAN（Host VLAN および Native VLAN）が正しく伝搬されているか。
  * PEN 上で Cisco TrustSec (CTS) インラインタギング（`cts manual` / `policy static sgt`）が構成されているか。

### 2. よくある設定ミス・落とし穴
* **Loopback0 パッシブ漏れ:** IS-IS / OSPF で Loopback0 を Advertisement 対象に含め忘れる、または Metric 調整ミスにより RLOC 間の最適経路が崩れる。
* **アンダーレイ MTU 不一致:** インターフェイス MTU のみ変更し、システムグローバル MTU (`system mtu 9100`) の再起動設定を怠る。
* **PnP ポートの CDP 無効化:** スイッチポートで `no cdp run` が設定されていると、PnP 探索プロセスが正常に動作しない。
* **LAN Automation 停止の失念:** プロビジョニング完了後に Stop LAN Automation を行わないと、Seed デバイス上に不必要な DHCP プールやプロファイルが残り続け、プロファイル不整合が発生する。

---

## 🛠 設定方法

### 1. Manual Underlay 設定例（Cisco IOS-XE 17.x CLI）

ファブリックルータ（Border / Edge）間を IS-IS でアンダーレイ構築する完全コンフィグ例です。

```text
! ==========================================
! System Global Settings (MTU & IP Routing)
! ==========================================
system mtu 9100
ip routing
ipv6 unicast-routing

! ==========================================
! Loopback0 (RLOC / Router ID)
! ==========================================
interface Loopback0
 description SD-Access Underlay RLOC
 ip address 10.10.10.1 255.255.255.255
 ip router isis Underlay-Process
!

! ==========================================
! Physical Point-to-Point Interfaces
! ==========================================
interface GigabitEthernet1/0/1
 description PtP to Border-Node-2
 no switchport
 ip address 172.16.1.1 255.255.255.252
 mtu 9100
 ip router isis Underlay-Process
 isis network point-to-point
 isis metric 10
 no shutdown
!
interface GigabitEthernet1/0/2
 description PtP to Fabric-Edge-1
 no switchport
 ip address 172.16.1.5 255.255.255.252
 mtu 9100
 ip router isis Underlay-Process
 isis network point-to-point
 isis metric 10
 no shutdown
!

! ==========================================
! IS-IS Dynamic Routing Protocol
! ==========================================
router isis Underlay-Process
 net 49.0001.0100.1001.0001.00
 metric-style wide
 log-adjacency-changes
 passive-interface Loopback0
!
```

### 2. Policy Extended Node (PEN) & Fabric Edge 接続設定例

Fabric Edge ノードと Policy Extended Node 間で CTS SGT インラインタギングを有効化する設定例です。

```text
! ==========================================
! Fabric Edge Node Configuration (Facing PEN)
! ==========================================
interface GigabitEthernet1/0/10
 description Connection to Policy Extended Node (PEN)
 switchport mode trunk
 switchport trunk allowed vlan 10,20,99
 mtu 9100
 cts manual
  policy static sgt 100
  no propagate sgt
!

! ==========================================
! Policy Extended Node (PEN - Catalyst IE3400/2960CX)
! ==========================================
cts logging verbose
cts manual
 policy static sgt 100

interface GigabitEthernet1/1
 description Uplink to Fabric Edge Node
 switchport mode trunk
 switchport trunk allowed vlan 10,20,99
 cts manual
  policy static sgt 100
  propagate sgt
!
interface GigabitEthernet1/2
 description Downlink Host Access Port
 switchport mode access
 switchport access vlan 10
 cts manual
  policy static sgt 10
!
```

---

## 🔍 検証コマンド

アンダーレイの正常動作を確認するための必須コマンド群です。

| 目的 | コマンド | 期待される状態 / 確認ポイント |
| :--- | :--- | :--- |
| **IS-IS ネイバー状態** | `show isis neighbors` | 全 PtP ポートで State が `UP`、Type が `L2` または `L1L2` であること。 |
| **IS-IS トポロジー確認** | `show isis topology` | 全 Loopback0 アドレス（/32）への最小コストパスが計算されていること。 |
| **ルーティングテーブル** | `show ip route isis` | 対向ノードの Loopback0 IP が IS-IS 経由で学習されていること。 |
| **Jumbo MTU 疎通検証** | `ping 10.10.10.2 size 8000 df-bit` | フラグメンテーション拒否（DF ビット付与）状態で 100% 成功すること。 |
| **インターフェイス MTU** | `show interfaces GigabitEthernet1/0/1 \| include MTU` | `MTU 9100 bytes` または `9216 bytes` と表示されること。 |
| **PnP ステータス確認** | `show pnp tech` / `show pnp requests` | PnP エージェントの接続ログ、Catalyst Center からのタスク応答を確認。 |
| **Cisco TrustSec 状態** | `show cts interface GigabitEthernet1/0/10` | Inline SGT Propagation が `Enabled` であること。 |

---

## 🚨 トラブルシュート

| 症状 | 推定原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **IS-IS ネイバーが不成立** | 1. MTU 不一致<br>2. システム ID 重複<br>3. `isis network point-to-point` 片不一致 | <code>show isis neighbors</code><br><code>show clns neighbors</code><br><code>debug isis adj-packets</code> | 1. ポート MTU を両端で 9100 に統一。<br>2. `net` コマンドで重複した System ID を変更。<br>3. 両端で P2P 設定を揃える。 |
| **Jumbo Ping が失敗する** | 1. 中間スイッチで MTU がデフォルト (1500)<br>2. パケットフラグメンテーション発生 | <code>ping <IP> size 8000 df-bit</code><br><code>show interfaces \| inc MTU</code> | パス上のすべての物理インターフェイスおよび SVI で MTU 9100/9216 を一括設定。 |
| **LAN Automation (PnP) がタイムアウト** | 1. DHCP Option 43 のフォーマット不正<br>2. Catalyst Center への 443 疎通不可<br>3. CDP が無効 | <code>show pnp requests</code><br><code>show cdp neighbors</code><br><code>debug pnp agent</code> | 1. Option 43 (Hex 形式/ASCII 形式) を正確に修正。<br>2. Seed デバイスの Routing/ACL を確認。<br>3. 全リンクで `cdp run` を有効化。 |
| **Extended Node で SGT が認識されない** | Extended Node (EN) は SGT インラインタギング非対応 | <code>show cts interface</code> | SGT タギングが必要な場合はスイッチを Policy Extended Node (PEN) 対応機種に変更。 |

---

## ⚠ 制限事項

1. **LAN Automation の制限:**
   * LAN Automation はデフォルトで IS-IS のみをサポート（最新バージョンでは一部 OSPF サポートありだが IS-IS が推奨基準）。
   * Seed デバイスと PnP デバイス間は直接の L3 Point-to-Point リンクである必要があり、途中に L2 パススルーの非管理スイッチを挟む構成は非サポート。
2. **アンダーレイ IP アドレッシングの分離:**
   * アンダーレイ用 IP アドレス空間（PtP サブネットおよび Loopback アドレス）は、オーバーレイで動く EID（Endpoint ID）空間と完全に重複を回避しなければならない。
3. **Extended Node の制限:**
   * **Extended Node (EN):** LISP 制御パケットおよび VXLAN カプセル化を行わない。すべてのカプセル化は上位の Fabric Edge (FE) で実行されるため、FE 側のポート制限や VLAN 数制限を受ける。
   * **Policy Extended Node (PEN):** インライン SGT タギングをサポートするが、VXLAN 自体のカプセル化機能は持たない。

---

## 🔄 他技術との関連

* **LISP (Locator/ID Separation Protocol):** アンダーレイの Loopback0 IP は LISP の **RLOC（Routing Locator）** として使用され、アンダーレイの L3 Reachability が途切れると LISP コントロールプレーンが完全に崩壊します。
* **VXLAN (Virtual Extensible LAN):** アンダーレイの UDP 4789 ポートを用いてデータパケットをカプセル化転送します。アンダーレイの Jumbo MTU 設定が不十分な場合、パケット破棄が発生します。
* **Cisco TrustSec (CTS):** アンダーレイのインラインタギング（EtherType 0x8909）を利用して、パケットヘッダー内に SGT (Security Group Tag) を直接挿入・伝搬します。
* **IS-IS / OSPF:** アンダーレイの動的ルーティングプロトコル。ECMP（Equal-Cost Multi-Path）を構成することで、複数の物理 Uplink 間でアンダーレイのロードバランシングを実現します。

---

## 🧩 比較表

### 1. Manual Underlay vs LAN Automation

| 項目 | Manual Underlay | LAN Automation (PnP) |
| :--- | :--- | :--- |
| **構築方法** | 手動 CLI / Ansible / Python | Catalyst Center による自動プロビジョニング |
| **プロトコル** | IS-IS, OSPFv2, EIGRP 等任意 | **IS-IS (標準)** |
| **ヒューマンエラー** | MTU・IP・システム ID の重複リスクあり | Catalyst Center が統一管理しエラーを防止 |
| **構築速度** | 大規模環境では非常に低速 | 数十台〜数千台のスイッチを並列自動初期化 |
| **柔軟性** | 非常に高い（特殊なルーティング要件に対応） | 標準化されたベストプラクティス構成に固定 |

### 2. Fabric Edge vs Extended Node vs Policy Extended Node

| 機能 / 役割 | Fabric Edge (FE) | Extended Node (EN) | Policy Extended Node (PEN) |
| :--- | :--- | :--- | :--- |
| **LISP Control Plane** | **実装あり** | なし | なし |
| **VXLAN Encapsulation** | **実装あり** | なし | なし |
| **Anycast Gateway** | **実装あり** | なし | なし |
| **SGT 判定 / インラインタギング** | **完全対応** | なし | **対応（SGT インラインタギングのみ）** |
| **代表的な対応機種** | Catalyst 9300 / 9400 / 9500 | Catalyst IE3300 / 2960-CX | Catalyst IE3400 / 3560-CX |

---

## 💡 ベストプラクティス

1. **ルーティングプロトコルの選定:** アンダーレイには **IS-IS** を優先選定します。IS-IS は IP ヘッダーに依存せず Layer 2 リンク上で直接動作するため、IP 設定ミスに強く、Catalyst Center との親和性が最も高いためです。
2. **Jumbo MTU の一貫性:** ファブリック内の全ルータ・スイッチ（および中間ネットワーク機器）で、**グローバル MTU を 9100 バイト（または 9216 バイト）に統一** します。
3. **Point-to-Point リンクの最適化:** 全直結 L3 リンクに対して `isis network point-to-point` を明示設定し、DIS 選出タイマーの遅延を回避します。
4. **LAN Automation のライフサイクル管理:** LAN Automation 完了後は、**必ず Catalyst Center 上で "Stop LAN Automation" を実行** し、Seed デバイスの臨時プロファイルを削除・保護してください。

---

## 📝 ラボ学習・設定サンプル例

### 10 本の実践ラボシナリオ

#### Scenario 1: IS-IS Manual Underlay 基本構築
* **問題:** Border1 と Edge1 間で IS-IS を用いたアンダーレイ L3 疎通を構成せよ。
* **要件:**
  * Area ID: `49.0001`
  * System ID: Border1=`0100.0000.0001`, Edge1=`0100.0000.0002`
  * 物理リンク: Gi1/0/1 (`172.16.1.0/30`), Metric=10, Point-to-Point
  * Loopback0: Border1=`10.10.10.1/32`, Edge1=`10.10.10.2/32`
* **設定例 (Border1):**
  ```text
  interface Loopback0
   ip address 10.10.10.1 255.255.255.255
   ip router isis Underlay
  !
  interface GigabitEthernet1/0/1
   no switchport
   ip address 172.16.1.1 255.255.255.252
   ip router isis Underlay
   isis network point-to-point
   isis metric 10
  !
  router isis Underlay
   net 49.0001.0100.0000.0001.00
   metric-style wide
   passive-interface Loopback0
  ```
* **検証方法:** `show isis neighbors` で State が `UP` であることを確認。`ping 10.10.10.2` で疎通確認。

#### Scenario 2: OSPFv2 Manual Underlay 構築
* **問題:** Border1 と Edge1 間で OSPFv2 を用いたアンダーレイを構成せよ。
* **要件:** Area 0、PtP ネットワークタイプ、Loopback0 告知。
* **設定例 (Edge1):**
  ```text
  interface Loopback0
   ip address 10.10.10.2 255.255.255.255
   ip ospf 1 area 0
  !
  interface GigabitEthernet1/0/1
   no switchport
   ip address 172.16.1.2 255.255.255.252
   ip ospf 1 area 0
   ip ospf network point-to-point
   ip ospf cost 10
  !
  router ospf 1
   router-id 10.10.10.2
   passive-interface Loopback0
  ```
* **検証方法:** `show ip ospf neighbor` でステートが `FULL/ -`（DR/BDR なし）であることを確認。

#### Scenario 3: 全網 Jumbo MTU 9100 一括バインド
* **問題:** ファブリックデバイス Edge1 上で VXLAN カプセル化対応のため Jumbo MTU を有効化せよ。
* **要件:** グローバル MTU 9100、全 L3 インターフェイス MTU 9100。
* **設定例 (Edge1):**
  ```text
  system mtu 9100
  !
  interface GigabitEthernet1/0/1
   mtu 9100
  !
  interface GigabitEthernet1/0/2
   mtu 9100
  ```
* **検証方法:** `show system mtu` および `show interfaces Gi1/0/1 | inc MTU` で `9100` を確認。

#### Scenario 4: LAN Automation 用 Seed デバイス事前準備
* **問題:** Border1 を LAN Automation の Seed デバイスとして機能させるための準備コンフィグを流し込め。
* **要件:** Catalyst Center との接続ループバック、PnP 用 DHCP ポール準備。
* **設定例 (Border1):**
  ```text
  ip dhcp pool LAN_AUTOMATION_TEMP
   network 192.168.100.0 255.255.255.0
   default-router 192.168.100.1
   option 43 hex 5a1d.b20a.0101.644a.08 (DNAC IP: 10.1.1.100)
  !
  interface GigabitEthernet1/0/24
   description PnP Seed Port to New Switch
   no switchport
   ip address 192.168.100.1 255.255.255.0
   cdp run
  ```
* **検証方法:** 新規スイッチ接続時に `show ip dhcp binding` で IP が払い出されることを確認。

#### Scenario 5: IS-IS Metric チューニングによるアンダーレイ ECMP 構成
* **問題:** Edge1 から Border1 への 2 本の物理リンク間でアンダーレイの ECMP 負荷分散を構成せよ。
* **要件:** 両物理リンクの IS-IS Metric を `10` に統一。
* **設定例 (Edge1):**
  ```text
  interface GigabitEthernet1/0/1
   isis metric 10
  !
  interface GigabitEthernet1/0/2
   isis metric 10
  ```
* **検証方法:** `show ip route 10.10.10.1` で 2 つの等コスト Next-Hop ルーティングエントリーが表示されることを確認。

#### Scenario 6: Policy Extended Node (PEN) インライン SGT 接続構成
* **問題:** Fabric Edge (FE1) と PEN1 間のトランクポートで SGT インラインタギングを有効化せよ。
* **要件:** SGT 伝搬（Propagate SGT）を有効化、Static SGT 100。
* **設定例 (FE1):**
  ```text
  interface GigabitEthernet1/0/12
   switchport mode trunk
   switchport trunk allowed vlan 10,20
   cts manual
    policy static sgt 100
    propagate sgt
  ```
* **検証方法:** `show cts interface Gi1/0/12` で `Inline SGT Propagation: Enabled` を確認。

#### Scenario 7: Extended Node (EN) 向け 802.1Q L2 Trunk 構成
* **問題:** 産業用スイッチ（EN1）を Fabric Edge (FE1) に L2 拡張接続せよ。
* **要件:** Native VLAN 99、Host VLAN 10,20 をカプセル化なしで通過させる。
* **設定例 (FE1):**
  ```text
  interface GigabitEthernet1/0/15
   description Connection to Industrial Switch (EN1)
   switchport trunk native vlan 99
   switchport trunk allowed vlan 10,20,99
   switchport mode trunk
   spanning-tree portfast trunk
  ```
* **検証方法:** `show interfaces Gi1/0/15 switchport` で Trunk ステートを確認。

#### Scenario 8: アンダーレイ Multicast (PIM-SSM) 基本構成
* **問題:** Ingress Replication を使用しないアンダーレイの BUM 転送のため PIM-SSM を構成せよ。
* **要件:** 全 PtP ポートで PIM Sparse-Mode 有効化、SSM 範囲 `232.0.0.0/8`。
* **設定例 (Border1 & Edge1):**
  ```text
  ip multicast-routing
  !
  ip pim ssm default
  !
  interface GigabitEthernet1/0/1
   ip pim sparse-mode
  !
  interface Loopback0
   ip pim sparse-mode
  ```
* **検証方法:** `show ip pim neighbor` および `show ip pim ssm` を確認。

#### Scenario 9: BFD による IS-IS アンダーレイ高速障害検知
* **問題:** IS-IS アンダーレイリンク上で BFD を有効化し、サブセカンドでの障害切り替えを実現せよ。
* **要件:** BFD Interval 50ms, Multiplier 3。
* **設定例 (Edge1):**
  ```text
  interface GigabitEthernet1/0/1
   bfd interval 50 min_rx 50 multiplier 3
   isis bfd
  ```
* **検証方法:** `show bfd neighbors` で BFD セッションが `Up` であることを確認。

#### Scenario 10: LAN Automation 完了後のクリーンアップ手動検証
* **問題:** LAN Automation 完了後に Seed デバイス上に残った臨時 DHCP 設定を正常状態に手動調整せよ。
* **要件:** 不要な DHCP プールの削除と PtP ポートの IS-IS パッシブ化解除の確認。
* **設定例 (Border1):**
  ```text
  no ip dhcp pool LAN_AUTOMATION_TEMP
  !
  interface GigabitEthernet1/0/24
   no ip address
   no switchport
   ip address 172.16.1.9 255.255.255.252
   ip router isis Underlay
   isis network point-to-point
  ```
* **検証方法:** `show ip dhcp pool` で臨時プールが消滅していることを確認。

---

## ❓ 想定試験問題

### Question 1 (コンフィグ読解・トラブルシューティング)
**問題:** あなたは Fabric Edge ノード（Edge1）と Border ノード（Border1）間で IS-IS アンダーレイのネイバーが成立しないトラブルを調査しています。以下の Edge1 のコンフィグを確認し、ネイバー不成立の根本原因と修正手順を答えてください。

```text
interface GigabitEthernet1/0/1
 no switchport
 ip address 172.16.1.2 255.255.255.252
 mtu 9100
 ip router isis Underlay
!
router isis Underlay
 net 49.0001.0100.0000.0002.00
 metric-style wide
!
```

**解説・解法:**
1. **原因:** IS-IS ではデフォルトでブロードキャストネットワークタイプとして動作しようとしますが、対向の Border1 上で `isis network point-to-point` が明示設定されている場合、IS-IS Hello PDU の形式（LAN Hello vs P2P Hello）が不一致となり、アジャセンシーの生成に失敗します。
2. **修正手順:** Edge1 の Gi1/0/1 インターフェイス配下に `isis network point-to-point` を追加します。

---

### Question 2 (デザイン・実装)
**問題:** 大規模工場施設に Cisco SD-Access を導入します。屋外の現場には過酷環境対応の Catalyst IE3400 スイッチが設置され、末端の産業用 IoT 機器が接続されます。IoT 機器のトラフィックに対してアクセスポートレベルで SGT (Security Group Tag) を固定バインドし、インラインタギングで Fabric Edge に伝搬させる必要があります。適切なノード役割と設定要件を選定してください。

**解説・解法:**
1. **ノード役割:** **Policy Extended Node (PEN)** を選定します（通常 Extended Node は SGT インラインタギングに未対応）。
2. **設定要件:** 
   * IE3400（PEN）および上位 Fabric Edge 間の Trunk ポートで `cts manual` および `propagate sgt` を有効化する。
   * IE3400 のアクセスポートで `cts manual` および `policy static sgt <VALUE>` を適用する。

---

### Question 3 (LAN Automation トラブルシューティング)
**問題:** Catalyst Center から LAN Automation を開始しましたが、新設の Catalyst 9300 スイッチが PnP 探索を通過せず、プロビジョニングが開始されません。Seed デバイス上で確認すべき 3 つの最優先チェック項目を挙げてください。

**解説・解法:**
1. **DHCP Option 43 のフォーマット:** Catalyst Center の IP アドレスが Option 43 に正確な 16 段階 Hex/ASCII 形式でエンコードされているか。
2. **CDP の有効化ステータス:** Seed デバイスの PnP ポートで CDP (`cdp run` / `cdp enable`) が動作しているか（PnP エージェントの探索に CDP が必須）。
3. **Seed ポートの L3 疎通性と IP アドレス:** Seed ポートに PnP 用の臨時 IP アドレスが正しくバインドされ、Catalyst Center（ポート 443）へ L3 疎通可能であるか。

---

### Question 4 (MTU / トラフィック転送)
**問題:** SD-Access オーバーレイにおいて、クライアント間で 1500 バイトの ICMP パケット（DF ビット付き）を送信した際、通信が破棄される問題が発生しました。アンダーレイの確認コマンドと修正すべきコンフィグを示してください。

**解説・解法:**
1. **確認コマンド:** `ping <対向RLOC-IP> size 1550 df-bit` を実行し、アンダーレイでフラグメンテーションなしにパケットが通過するかテストする。
2. **修正コンフィグ:** アンダーレイの全物理ポートおよび SVI にて `mtu 9100`（または 9216）を設定し、グローバルで `system mtu 9100` を適用して機器を再起動する。

---

### Question 5 (アーキテクチャ理解)
**問題:** SD-Access アンダーレイにおいて、VRF (Virtual Routing and Forwarding) を使用してアンダーレイのトラフィックを分割することは可能ですか？技術的根拠と共に説明してください。

**解説・解法:**
* **回答:** **不可（推奨されず、GRT のみ使用）**。
* **技術的根拠:** アンダーレイの唯一の目的は、オーバーレイ（LISP/VXLAN）の RLOC アドレス間に完全な L3 疎通性を提供することです。アンダーレイ自身は常に **Global Routing Table (GRT)** で動作します。マルチテナントやトラフィック分割（VRF）は、オーバーレイ層（VN: Virtual Network）において LISP / VXLAN / VRF-Lite の組み合わせによって実現されます。

---

## 🔗 参考リソース

### Cisco 公式ドキュメント・デザインガイド
* [Cisco SD-Access Solution Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-sda-design-guide.html)
* [Cisco DNA Center LAN Automation Deployment Guide](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/tech_notes/b_dnac_lan_automation_deployment_guide.html)
* [Cisco Catalyst Center User Guide - LAN Automation](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/2-3-7/user_guide/b_cisco_dna_center_user_guide_2_3_7/b_cisco_dna_center_user_guide_2_3_7_chapter_010000.html)
* [Cisco TrustSec Switch Configuration Guide](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/cts/b_179_cts_9300_cg.html)

### Cisco Live プレゼンテーション・動画
* [BRKCRS-2810 - Cisco SD-Access Underlay Design and LAN Automation (Cisco Live)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810)
* [BRKCRS-2815 - Advanced SD-Access Deployment and Troubleshooting (Cisco Live)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2815)

---

## 📝 補足（Notes）

### 1. アンダーレイ構成時のトポロジー図解

```text
  [ Catalyst Center ]
          │ (10.1.1.100)
          │
  [ Fabric Border Node ] ──── (Loopback0: 10.10.10.1/32)
          │
          │ PtP Routed Link (172.16.1.0/30, IS-IS Metric 10, MTU 9100)
          │
  [ Fabric Edge Node ] ────── (Loopback0: 10.10.10.2/32)
          │
          │ Trunk (802.1Q + SGT 100)
          │
  [ Policy Extended Node ] ── (Access Port: SGT 10)
```

### 2. 試験直前チェックリスト
* [ ] アンダーレイは IS-IS または OSPFv2 で構成され、Loopback0（/32）が完全疎通しているか？
* [ ] 全 PtP ポートで MTU 9100/9216 が適用され、`ping size 8000 df-bit` が成功するか？
* [ ] LAN Automation 用の DHCP Option 43 フォーマット（Catalyst Center IP）を暗唱・記述できるか？
* [ ] Extended Node (EN) と Policy Extended Node (PEN) の機能差（SGT インラインタギングの可否）を理解しているか？
* [ ] IS-IS ポートで `isis network point-to-point` の設定漏れがないか？


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENS-1501: Enterprise Campus Wired Design Fundamentals**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
    *   キャンパス設計の基礎と、SD-AccessアンダーレイとしてのIS-ISの役割を解説。
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076)
    *   SD-Accessの全体像とアンダーレイ要件の深い解説。
*   [**BRKOPS-2035: Real World Use Cases for Deploying Cisco SD-Access**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2035)
    *   LAN Automationの実際の挙動とトラブル事例。

### Configuration ガイド
*   [**Cisco DNA Center SD-Access LAN Automation Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)
*   [**SD-Access Manual Underlay Configuration (Cisco Design Guide)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)

### テクニカルドキュメント・設定例
*   [**Cisco SD-Access: Troubleshooting the Fabric (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)
*   [**Extended Nodes and Policy Extended Nodes Overview**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-extended-nodes.html)

---


## 📝 補足
- この学習メモは、SD-Access の「根幹」であるアンダーレイの構築から、自動化の仕組み、そして物理トポロジの拡張までを CCIE ラボ試験の要求レベルで網羅しています。特に **LAN Automation の失敗原因（CDP、VLAN 1、DHCPプールの不足等）** を理論的に整理しておくことが、試験中の迅速なトラブル解決に直結します。

