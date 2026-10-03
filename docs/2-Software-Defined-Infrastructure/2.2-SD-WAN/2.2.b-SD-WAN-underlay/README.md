---
layout: default
title: 2.2.b-SD-WAN-underlay
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 2
---

# 2.2.b SD-WAN underlay

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint の Blueprint 番号 **`2.2.b SD-WAN underlay`**（WAN Cloud Edge, Hardware Edge, Greenfield/Brownfield/Hybrid, System configuration, Transport configuration, TLOC Extension）に関する最新の Cisco Catalyst SD-WAN (旧 Viptela) 20.x / Cisco IOS-XE 17.x（cEdge / Catalyst 8000v）実装に基づく包括的な学習メモです。

---

## 📘 概要

SD-WAN アンダーレイ（SD-WAN Underlay）は、Cisco SD-WAN オーバーレイネットワーク（IPsec トンネル、OMP ピアリング、コントロールプレーン通信）を安定して確立・維持するための「下位物理・論理ネットワーク基盤」です。

* **機能概要:** 物理 WAN Edge (ASR1000/ISR4000/Catalyst 8200/8300/8500) やクラウド仮想ルータ (Catalyst 8000v / vEdge Cloud on AWS, Azure, GCP) を、既存の MPLS、インターネット、4G/5G、またはマルチクラウド VPC/VNet 接続へアンダーレイ層として接続し、コントロールプレーン（vBond / vSmart / vManage）との制御チャネル（DTLS/TLS）および WAN Edge 間のデータ面（IPsec/BFD）を正しく疎通させる技術群です。
* **利用目的:**
  * **システム基盤の初期定義:** システム識別子（System IP, Site ID, Organization Name, vBond Address）の正確な付与による安全なオーバーレイ参加。
  * **柔軟な展開手法:** 新規拠点構築（Greenfield）、既存ルータからの段階的移行（Brownfield）、および一部のみ SD-WAN 化する Hybrid 構成の実現。
  * **マルチトランスポート統合 & 拡張:** インターネット/MPLS 混在環境での VPN 0 インターフェイス定義および、単一 WAN 回線しか直接接続されていない冗長ルータ間での **TLOC Extension** 構成。
* **どのような場面で利用するか:**
  * オンプレミス拠点 (Branch / Campus) およびパブリッククラウド (AWS EC2 / Azure Transit VNet / GCP Cloud Router) への Catalyst 8000v 自動/手動展開時。
  * 既存ルータ（ISR4000等）を IOS-XE SD-WAN モードへコンバート・移行する Brownfield プロジェクト。
  * 物理的に 1 本の WAN 回線しか引けないラックにおいて、隣接する 2 台目の WAN Edge へ回線をバックアップ伸長させる TLOC Extension 設計。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **対象コンポーネント** | cEdge (Catalyst 8200/8300/8500, ISR4000, ASR1000, Catalyst 8000v) / vEdge (vEdge100/1000/2000/5000) |
| **主要サブトピック** | (i) Cloud Edge (AWS/Azure/GCP) <br>(ii) Hardware Edge <br>(iii) Greenfield / Brownfield / Hybrid <br>(iv) System config (System IP, Site ID, Org Name, vBond) <br>(v) Transport config (VPN 0, Tunnel, Allowed-services, TLOC Extension) |
| **アンダーレイ VRF** | **VPN 0** (コントロールプレーン & WAN 輸送専用 VRF) |
| **最重要パラメータ** | **System IP** (32-bit ルータ固有識別子)、**Site ID** (拠点識別子)、**Organization Name** (組織識別子・証明書検証キー)、**vBond Address** (オーケストレータ FQDN/IP) |
| **必須セキュリティ設定** | `allow-service dhcp / dns / icmp / bgp / ospf` (VPN 0 トンネル経由のコントロール/アンダーレイサービス制限) |
| **メリット** | トランスポートアグノスティック（MPLS/Internet/LTE を問わないオーバーレイ自動構築）、TLOC Extension による高可用性 |
| **制限事項・注意点** | Org Name の 1 文字でも不一致があると vBond/vSmart 認証拒否。TLOC Extension ポートでは `tunnel-interface` を有効化してはならない（VPN 0 内部インターフェイスとして動作）。 |

---

## 🏗 動作原理

### 1. アンダーレイからオーバーレイ確立への全体の流れ

```
+-----------------------------------------------------------------------------------+
| [Physical / Cloud Underlay Network]                                              |
|  (Internet / MPLS / AWS VPC / Azure VNet)                                         |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼ (1) System Config & VPN 0 IP/Route
+-----------------------------------------------------------------------------------+
| [WAN Edge Interface (VPN 0)]                                                      |
|  - IP Address / DHCP                                                              |
|  - Default Route to ISP / MPLS PE                                                 |
|  - tunnel-interface (Color: biz-internet / mpls)                                  |
|  - allow-service (dhcp, dns, icmp)                                                |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼ (2) STUN & Control Connection (UDP 12346 / 12446)
+-----------------------------------------------------------------------------------+
| [vBond Orchestrator]                                                              |
|  - Org Name & Serial List (Whitelist) Check                                       |
|  - Discover Public NAT IP/Port (Reflexive Address)                                |
|  - Pass vSmart & vManage IP List                                                  |
+-----------------------------------------------------------------------------------+
                                         │
                                         ▼ (3) Permanent OMP & Data Tunnel
+-----------------------------------------------------------------------------------+
| [vSmart & WAN Edge Peer]                                                          |
|  - DTLS/TLS to vSmart (OMP Peer)                                                  |
|  - BFD & IPsec (ESP) Data Tunnels to Other WAN Edges                              |
+-----------------------------------------------------------------------------------+
```

### 2. TLOC Extension の動作構造

物理的に MPLS 回線が Router-A にのみ、Internet 回線が Router-B にのみ引き込まれている冗長構成において、背面の L2/L3 交叉線（TLOC Extension Link）を介して相互に WAN 回線を延伸します。

```
                     [ MPLS Cloud ]          [ Internet Cloud ]
                           │                        │
                           │ (MPLS Circuit)         │ (Internet Circuit)
                           ▼                        ▼
                   +---------------+        +---------------+
                   |  WAN Edge 1   |        |  WAN Edge 2   |
                   | (Site-ID 100) |        | (Site-ID 100) |
                   +---------------+        +---------------+
                     Gi0/0/0 (mpls)           Gi0/0/0 (biz-internet)
                     Gi0/0/1 ──(TLOC Ext)──── Gi0/0/1
                     (VPN 0)                  (VPN 0)
                           │                        │
                           ▼                        ▼
          WAN Edge 1 は Gi0/0/1 経由で WAN Edge 2 の biz-internet を利用
          WAN Edge 2 は Gi0/0/1 経由で WAN Edge 1 の mpls を利用
```

---

## ⚙ 動作シーケンス

1. **System & Transport 初期化:**
   - ルータは System IP、Site ID、Organization Name、vBond アドレスをロード。
   - VPN 0 内の WAN インターフェイスに `tunnel-interface` を設定し、`color`（例: `biz-internet`）を指定。
2. **アンダーレイ L3 疎通確認:**
   - 物理インターフェイスで IP アドレス（静的または DHCP）を取得し、ネクストホップ（ISP/PE ルータ）へのデフォルトルートを RIB (VPN 0) に保持。
3. **vBond への DTLS パケット送信:**
   - WAN Edge は vBond アドレス（FQDN の場合は DNS 解決）へ向けて UDP 12346 から DTLS セッションを開始。
   - NAT が存在する場合、vBond は受信したパケットの送信元 IP/Port (Reflexive Address) を測定し、WAN Edge へ通知（STUN 動作）。
4. **コントロール接続の成立:**
   - vBond 認証後、WAN Edge は vSmart および vManage と永続的な DTLS/TLS コントロール接続を確立。
5. **TLOC 広告と IPsec トンネル自動生成:**
   - OMP を介して自機の TLOC (System IP + Color + Encapsulation) を vSmart へ広告。対向拠点との間で IPsec トンネルおよび BFD セッションが自動確立。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント

1. **Cloud Edge Deployment (2.2.b (i)):**
   * **AWS / Azure / GCP 上の Catalyst 8000v (cEdge):** User Data (Cloud-Init) パラメータを用いた Day-0 自動オンボーディングコンフィグの記述。
   * **マルチ NIC 構成:** Gi1 (VPN 0: WAN / Public)、Gi2 (VPN 512: OOB Management)、Gi3 (VPN 1: Service / LAN)。
2. **System & Transport Configuration (2.2.b (iv), (v)):**
   * **System IP:** BGP Router ID と同様の 32-bit ドット表記（重複厳禁）。
   * **Site ID:** 1〜4294967295。同一物理拠点の冗長 Edge ルータには**同じ Site ID** を付与（これにより Site 内の直接 IPsec トンネル形成を抑制）。
   * **Organization Name:** 文字列の完全一致（大文字・小文字・スペース厳密区別）。
   * **Allowed Services:** `allow-service dhcp`, `allow-service dns`, `allow-service icmp`, `allow-service bgp`, `allow-service netconf` 等の選択的許可。試験要件で「最小限のサービスのみ許可」とある場合、不必要な `allow-service all` は減点対象。
3. **TLOC Extension (2.2.b (v)):**
   * **設定の落とし穴:** TLOC Extension 用インターフェイス（例: Gi0/0/1）は **VPN 0** に所属させるが、**`tunnel-interface` コマンドは設定してはならない**。対向ルータの `tunnel-interface` へ向けてスタティックルート (`ip route vrf 0 0.0.0.0 0.0.0.0 <対向Ext-IP>`) を記述する。
4. **Migration Strategies (2.2.b (iii)):**
   * **Greenfield:** 完全新規構築。最初から Template / CLI にて Catalyst SD-WAN モードで登録。
   * **Brownfield / Hybrid:** 既存 IOS-XE ルータを `controller-group` / SD-WAN モードへ移行。レガシー WAN (MPLS/BGP) と SD-WAN オーバーレイの相互再配送および BFD / OMP タグによるループ防止。

### コマンド読み取り・検証の重要ポイント

```bash
# コントロール接続状態の確認
show control connections

# TLOC 情報およびローカル Color / IP の確認
show control local-properties

# VPN 0 のアンダーレイ IP ルーティングテーブル確認
show ip route vrf 0

# TLOC 拡張インターフェイスおよび物理接続の確認
show interface gigabitethernet 0/0/1
```

---

## 🛠 設定方法

### 1. System & Transport (VPN 0) CLI 設定例 (cEdge / Catalyst 8000v)

```text
!
system
 system-ip 10.255.1.11
 site-id 100
 organization-name "CCIE-EI-LAB"
 vbond 192.168.1.100 port 12346
!
vrf definition 0
 rd 1:0
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet0/0/0
 description WAN_Internet_Primary
 vrf forwarding 0
 ip address 203.0.113.2 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color biz-internet
  allow-service dhcp
  allow-service dns
  allow-service icmp
  no allow-service ssh
  no allow-service netconf
 exit
 no shutdown
!
ip route vrf 0 0.0.0.0 0.0.0.0 203.0.113.1
!
```

### 2. TLOC Extension CLI 設定例

#### 【Edge-1: Internet 回線直接接続 ＋ MPLS 回線を Edge-2 から延伸受領】

```text
! Edge-1 (Site 100)
system
 system-ip 10.255.1.11
 site-id 100
 organization-name "CCIE-EI-LAB"
 vbond 192.168.1.100 port 12346
!
interface GigabitEthernet0/0/0
 description Direct_Internet
 vrf forwarding 0
 ip address 203.0.113.2 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color biz-internet
  allow-service dhcp
  allow-service dns
  allow-service icmp
 exit
 no shutdown
!
! TLOC Extension 接続用物理ポート (tunnel-interface は設定しない)
interface GigabitEthernet0/0/1
 description TLOC_EXT_To_Edge2
 vrf forwarding 0
 ip address 192.168.12.1 255.255.255.252
 no shutdown
!
! 延伸された MPLS カラー用の Tunnel インターフェイス (Loopback または Subinterface)
! IOS-XE cEdge では、TLOC Ext 用の Subinterface / Secondary IP または Point-to-Point 経由で定義
interface GigabitEthernet0/0/1.100
 description Ext_MPLS_Tunnel
 vrf forwarding 0
 encapsulation dot1Q 100
 ip address 192.168.112.1 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color mpls
  allow-service icmp
 exit
!
! MPLS PE へ向かう静的ルート (Edge-2 の TLOC Ext アドレス経由)
ip route vrf 0 10.0.0.0 255.0.0.0 192.168.12.2
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 期待される確認項目 |
| :--- | :--- | :--- |
| **システム設定確認** | <code>show sdwan run system</code> | System IP, Site ID, Org Name, vBond アドレスの正常性 |
| **ローカルプロパティ確認** | <code>show control local-properties</code> | WAN インターフェイスの IP, Color, Certificate Status, NAT Type |
| **コントロールセッション** | <code>show control connections</code> | vSmart / vManage / vBond との State (UP), Protocol (DTLS/TLS) |
| **アンダーレイ RIB** | <code>show ip route vrf 0</code> | ネクストホップ (ISP / PE / TLOC Ext Peer) へのデフォルトルート |
| **TLOC 拡張・インターフェイス** | <code>show sdwan interface vrf 0</code> | VPN 0 内の各 Tunnel / Non-Tunnel インターフェイス動作 |
| **BFD セッション確認** | <code>show bfd sessions</code> | 他拠点の全 TLOC (Ext 含む) 間で BFD State が UP であること |
| **DTLS / TLS デバッグ** | <code>debug sdwan control control</code> | コントロールプレーン接続確立処理の詳細ログ |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **vBond と接続が確立しない (`CRTTMO` / `BIDNXT`)** | System IP / Org Name の不一致、または vBond への L3 疎通不可 | <code>show control local-properties</code><br><code>ping vrf 0 <vBond-IP></code> | System コンフィグの `organization-name` 文字列を完全一致させる。VPN 0 のルートを確認。 |
| **TLOC Ext 経由のカラーで Tunnel が UP しない** | TLOC Ext インターフェイスに誤って `tunnel-interface` を設定した | <code>show sdwan run interface</code> | TLOC Ext 物理ポートから `tunnel-interface` を削除し、ルーティングのみを有効化。 |
| **コントロール接続が頻繁にフラップする** | IP MTU / MSS のミスマッチにより DTLS 大型パケットが破棄されている | <code>ping vrf 0 <vSmart-IP> size 1400 df-bit</code> | VPN 0 インターフェイスで `ip mtu 1400` や `tcp mss-adjust 1360` を適用。 |
| **`allow-service` により DNS/DHCP が拒否される** | `tunnel-interface` 配下で `no allow-service dns` 等が設定されている | <code>show control local-properties</code> | `allow-service dns` / `allow-service dhcp` を明示的に許可。 |
| **AWS/Azure cEdge オンボーディング失敗** | Cloud-Init User-Data の構文エラー、または Elastic IP 未バインド | <code>show sdwan log</code> | AWS/Azure コンソールで 1:1 Public IP / Elastic IP が正常に割り当てられているか検証。 |

---

## ⚠ 制限事項

1. **TLOC Extension の回線帯域制限:** TLOC Extension リンクは 2 台の Edge ルータ間の物理 LAN インターフェイスを通過するため、過度なデータトラフィック集中によるボトルネックに注意。
2. **クラウド Edge (Catalyst 8000v) のライセンス依存:** AWS / Azure / GCP 上の Cat8000v では、DNA ライセンスティア (Tier 1: 10Mbps〜 Tier 3: 10Gbps) に応じたスループット制限が強制される。
3. **System IP の変更不可能性:** ルータがコントローラと接続中に System IP を動的変更すると、コントロール接続が即座にドロップし、再オンボーディングが必要となる。

---

## 🔄 他技術との関連

* **BGP / OSPF (Service VRF Integration):** VPN 0 のアンダーレイ経路と Service VPN (VPN 1〜511) 内の OSPF/BGP ルートは相互に分離（VRF 分割）。`sdwan` プロセスが OMP と相互再配送を実行。
* **NAT Traversal (STUN):** VPN 0 インターフェイスがプライベート IP (NAT 配下) の場合、vBond が STUN 応答を返し、Reflexive Public IP/Port を動的マッピング。
* **BFD (Bidirectional Forwarding Detection):** 各 TLOC 間で全自動で確立される IPsec データトンネル上で 1 秒間隔の BFD プローブを送信し、SLA (Jitter / Loss / Latency) を測定。

---

## 🧩 比較表

### 1. Greenfield vs Brownfield vs Hybrid 展開モデル

| 項目 | Greenfield | Brownfield | Hybrid |
| :--- | :--- | :--- | :--- |
| **概要** | 完全新規構築（既存ルータなし） | 既存ルータを Cisco SD-WAN へ完全置換・全移行 | 既存 WAN (MPLS/BGP) と SD-WAN 拠点を共存 |
| **設定方式** | 最初から Catalyst Center / vManage Template 適用 | 既存 CLI から Feature Template へコンバート | サービス VRF 上で BGP/OSPF 相互再配送 |
| **複雑度** | 低（クリーンな構成） | 中（既存設定の移植作業） | 高（ルーティングループ防止・タグ付け必須） |
| **ラボ試験出題頻度** | 高（初期構築問題） | 中（移行・トラブルシュート） | 高（相互再配送・ルート制御） |

### 2. Direct TLOC vs TLOC Extension

| 項目 | Direct TLOC Interface | TLOC Extension Interface |
| :--- | :--- | :--- |
| **物理接続** | WAN 回線 (ISP / MPLS PE) へ直接接続 | 隣接する WAN Edge ルータの LAN ポートへ接続 |
| **`tunnel-interface`** | **必須有効化** (`color` をバインド) | **設定不可** (通常の L2/L3 送信ポート) |
| **パケット転送** | 自機の物理ポートから直接 IPsec 宛て送出 | 隣接ルータへパケットを転送し、隣接ルータから送出 |
| **用途** | 主回線・直接引き込みポート | 単一回線ルータへの他種 WAN 回線冗長化 |

---

## 💡 ベストプラクティス

1. **System IP & Site ID の体系化:**
   - System IP は `10.255.<Region-ID>.<Node-ID>` のように規則化。
   - 同一拠点内のメイン Edge とサブ Edge には同一の `site-id`（例: `100`）を割り当て、無用な拠内 IPsec トンネル形成を防止。
2. **Organization Name の変数管理:**
   - テンプレート作成時、`organization-name` は Global / Device Specific 変数とせず、組織固定値として埋め込み、タイポ事故を排除。
3. **TLOC Extension での MTU 考慮:**
   - TLOC Ext リンク上を IPsec 外側カプセル化パケットが通過するため、物理ポートで `mtu 9000` (Jumbo Frame) または `ip mtu 1500` 以上を確保。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI Practical Lab 試験レベルの全 10 設定例です。

### Sample 1: Greenfield Single-WAN cEdge (System & Internet Transport)

* **問題:** Greenfield 拠点 Branch-1 の cEdge1 において、システム識別子および Dedicated Internet 接続 (VPN 0) を初期構築せよ。
* **要件:**
  1. System IP: `10.255.1.1`
  2. Site ID: `101`
  3. Org Name: `CCIE-LAB-SDA`
  4. vBond: `192.168.1.100` (Port 12346)
  5. Gi0/0/0 を VPN 0 に収容し、IP `203.0.113.10/30`、Next-Hop `203.0.113.9` を設定。
  6. Color: `biz-internet`。サービス許可は `dhcp`, `dns`, `icmp` のみとする。

```text
! --- Sample 1 Configuration ---
system
 system-ip 10.255.1.1
 site-id 101
 organization-name "CCIE-LAB-SDA"
 vbond 192.168.1.100 port 12346
!
vrf definition 0
 rd 1:0
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet0/0/0
 description WAN_INTERNET
 vrf forwarding 0
 ip address 203.0.113.10 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color biz-internet
  allow-service dhcp
  allow-service dns
  allow-service icmp
  no allow-service ssh
  no allow-service netconf
  no allow-service bgp
  no allow-service ospf
 exit
 no shutdown
!
ip route vrf 0 0.0.0.0 0.0.0.0 203.0.113.9
!
```

* **検証方法:**
  ```bash
  show control local-properties
  show control connections
  ```

---

### Sample 2: Dual-WAN cEdge (Internet + MPLS on Single Edge)

* **問題:** Hub 拠点の cEdge-Hub において、Internet と MPLS の 2 回線を単一ルータの VPN 0 に収容せよ。
* **要件:**
  1. Gi0/0/0: Internet (IP: `198.51.100.2/30`, Gateway: `198.51.100.1`, Color: `biz-internet`)
  2. Gi0/0/1: MPLS (IP: `10.1.1.2/30`, Gateway: `10.1.1.1`, Color: `mpls`)
  3. 各 Tunnel インターフェイスで IPsec カプセル化を有効化。

```text
! --- Sample 2 Configuration ---
system
 system-ip 10.255.0.1
 site-id 10
 organization-name "CCIE-LAB-SDA"
 vbond 192.168.1.100 port 12346
!
interface GigabitEthernet0/0/0
 description WAN_BIZ_INTERNET
 vrf forwarding 0
 ip address 198.51.100.2 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color biz-internet
  allow-service icmp
  allow-service dns
 exit
 no shutdown
!
interface GigabitEthernet0/0/1
 description WAN_MPLS
 vrf forwarding 0
 ip address 10.1.1.2 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color mpls
  allow-service icmp
 exit
 no shutdown
!
ip route vrf 0 0.0.0.0 0.0.0.0 198.51.100.1
ip route vrf 0 10.0.0.0 255.0.0.0 10.1.1.1
!
```

* **検証方法:**
  ```bash
  show control connections
  show ip route vrf 0
  ```

---

### Sample 3: TLOC Extension Configuration (Primary Internet Edge)

* **問題:** Site-200 の Router-A (Internet 直結) と Router-B (MPLS 直結) 間で TLOC Extension を構成せよ。ここでは Router-A 側の設定を行え。
* **要件:**
  1. Router-A Gi0/0/0: 自機 Internet 直接接続 (IP: `203.0.113.18/30`, Gateway: `203.0.113.17`, Color: `biz-internet`).
  2. Router-A Gi0/0/1: Router-B への TLOC Extension リンク (IP: `192.168.200.1/30`)。`tunnel-interface` は設定しないこと。
  3. Router-A Gi0/0/1.200: Subinterface 経由で Router-B の MPLS 回線を延伸利用するための Tunnel 設定 (IP: `192.168.201.1/30`, Color: `mpls`)。
  4. Router-B 側の MPLS 網宛てルーティングを設定。

```text
! --- Sample 3 Configuration ---
! Router-A (Site 200)
system
 system-ip 10.255.200.1
 site-id 200
 organization-name "CCIE-LAB-SDA"
 vbond 192.168.1.100 port 12346
!
interface GigabitEthernet0/0/0
 description Direct_Internet
 vrf forwarding 0
 ip address 203.0.113.18 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color biz-internet
  allow-service icmp
 exit
 no shutdown
!
! TLOC Ext Point-to-Point Link (Non-Tunnel)
interface GigabitEthernet0/0/1
 description TLOC_EXT_To_RouterB
 vrf forwarding 0
 ip address 192.168.200.1 255.255.255.252
 no shutdown
!
! Ext Tunnel Subinterface for MPLS
interface GigabitEthernet0/0/1.200
 description Ext_MPLS_Tunnel
 vrf forwarding 0
 encapsulation dot1Q 200
 ip address 192.168.201.1 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color mpls
  allow-service icmp
 exit
!
! Static Route for Extended MPLS Transport via Router-B
ip route vrf 0 10.0.0.0 255.0.0.0 192.168.200.2
!
```

* **検証方法:**
  ```bash
  show control connections
  show sdwan interface vrf 0
  ```

---

### Sample 4: AWS Cloud Edge (Catalyst 8000v) Cloud-Init Bootstrap

* **Problem:** Deploy a Catalyst 8000v on AWS EC2 as a Cloud Edge in Site 300 using Day-0 Configuration.
* **Requirements:**
  1. System IP: `10.255.300.1`, Site ID: `300`, Org Name: `CCIE-LAB-SDA`.
  2. GigabitEthernet1 in VPN 0 (AWS Public Subnet / Elastic IP).
  3. Enable DHCP on Gi1 for AWS ENI IP assignment.

```text
! --- Sample 4 Configuration (Cloud-Init User-Data) ---
SECTION CONFIG
system
 system-ip 10.255.300.1
 site-id 300
 organization-name "CCIE-LAB-SDA"
 vbond 192.168.1.100 port 12346
!
vrf definition 0
 rd 1:0
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet1
 description AWS_WAN_Interface
 vrf forwarding 0
 ip address dhcp
 tunnel-interface
  encapsulation ipsec
  color public-internet
  allow-service dhcp
  allow-service dns
  allow-service icmp
 exit
 no shutdown
!
ip route vrf 0 0.0.0.0 0.0.0.0 GigabitEthernet1
END
```

* **Verification:**
  ```bash
  show control local-properties
  show control connections
  ```

---

### Sample 5: Brownfield Router Migration to SD-WAN Mode

* **Problem:** Convert an existing ISR4331 router running IOS-XE to SD-WAN Controller Mode.
* **Requirements:**
  1. Change controller-group mode to SD-WAN.
  2. Preserve Management Interface Gi0/0/2 in VPN 512.

```text
! --- Sample 5 Configuration ---
! Step 1: Trigger SD-WAN mode conversion in IOS-XE
controller-group 1
 mode sdwan
!
! Step 2: Configure System & VPN 512 Management after reboot
system
 system-ip 10.255.400.1
 site-id 400
 organization-name "CCIE-LAB-SDA"
 vbond 192.168.1.100 port 12346
!
vrf definition 512
 rd 1:512
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet0/0/2
 description Out-of-Band_Management
 vrf forwarding 512
 ip address 10.50.1.50 255.255.255.0
 no shutdown
!
ip route vrf 512 0.0.0.0 0.0.0.0 10.50.1.1
!
```

* **Verification:**
  ```bash
  show version | include SD-WAN
  show control local-properties
  ```

---

### Sample 6: Dynamic Public IP NAT Traversal (STUN / Private Color)

* **Problem:** Configure a cEdge behind a Commercial NAT Router on a Private Cellular/LTE Transport.
* **Requirements:**
  1. Gi0/0/3 interface with Private IP assigned via DHCP.
  2. Color: `lte` (Private Color).
  3. Enable NAT discovery (`nat-refresh`) so vBond can STUN discover the reflexive address.

```text
! --- Sample 6 Configuration ---
interface GigabitEthernet0/0/3
 description Cellular_LTE_Behind_NAT
 vrf forwarding 0
 ip address dhcp
 tunnel-interface
  encapsulation ipsec
  color lte
  allow-service dhcp
  allow-service dns
  allow-service icmp
 exit
 no shutdown
!
```

* **Verification:**
  ```bash
  show control local-properties | include nat-type
  show control connections
  ```

---

### Sample 7: Restrict Public Color Tunnel Connection (`restrict`)

* **Problem:** Configure cEdge WAN interface with `color custom1` and ensure it ONLY forms IPsec data tunnels with peers having the exact same color (`custom1`).
* **Requirements:**
  1. Apply `restrict` keyword under `tunnel-interface`.

```text
! --- Sample 7 Configuration ---
interface GigabitEthernet0/0/0
 description Private_WAN_Custom1
 vrf forwarding 0
 ip address 172.16.10.2 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color custom1 restrict
  allow-service icmp
 exit
 no shutdown
!
ip route vrf 0 0.0.0.0 0.0.0.0 172.16.10.1
!
```

* **Verification:**
  ```bash
  show control local-properties | include restrict
  show bfd sessions
  ```

---

### Sample 8: Carrier-Constrained Tunnel Setup

* **Problem:** Configure cEdge for a Private MPLS network where TLOC connections must be restricted to the same Service Provider Carrier.
* **Requirements:**
  1. Apply `carrier-constrained` under `tunnel-interface`.

```text
! --- Sample 8 Configuration ---
interface GigabitEthernet0/0/1
 description MPLS_Carrier_A
 vrf forwarding 0
 ip address 10.20.1.2 255.255.255.252
 tunnel-interface
  encapsulation ipsec
  color mpls carrier-constrained
  allow-service icmp
 exit
 no shutdown
!
ip route vrf 0 10.0.0.0 255.0.0.0 10.20.1.1
!
```

* **Verification:**
  ```bash
  show control local-properties | include carrier
  ```

---

### Sample 9: Secondary vBond Backup Redundancy Configuration

* **Problem:** Configure cEdge with redundant vBond Orchestrators using FQDN DNS resolution in VPN 0.
* **Requirements:**
  1. Configure `vbond vbond.lab.local port 12346`.
  2. Ensure VPN 0 DNS server `8.8.8.8` is defined.

```text
! --- Sample 9 Configuration ---
system
 system-ip 10.255.500.1
 site-id 500
 organization-name "CCIE-LAB-SDA"
 vbond vbond.lab.local port 12346
!
ip domain lookup vrf 0
ip name-server vrf 0 8.8.8.8
!
```

* **Verification:**
  ```bash
  show control local-properties | include vbond
  ping vrf 0 vbond.lab.local
  ```

---

### Sample 10: Transport Underlay MTU & MSS Optimization

* **Problem:** Optimize VPN 0 WAN Interface MTU to prevent IPsec fragmentation over PPPoE / DSL Transport.
* **Requirements:**
  1. Set Interface MTU to 1492.
  2. Configure TCP MSS Adjust to 1360.

```text
! --- Sample 10 Configuration ---
interface GigabitEthernet0/0/0
 description DSL_Transport_PPPoE
 vrf forwarding 0
 ip address 192.0.2.2 255.255.255.0
 ip mtu 1492
 tcp mss-adjust 1360
 tunnel-interface
  encapsulation ipsec
  color biz-internet
  allow-service icmp
 exit
 no shutdown
!
```

* **Verification:**
  ```bash
  show interface gigabitethernet0/0/0 | include MTU
  ping vrf 0 8.8.8.8 size 1464 df-bit
  ```

---

## ❓ 想定試験問題

### Question 1 (Troubleshooting)

**問:** 新規デプロイした cEdge ルータで `show control connections` を実行したところ、State が常に `CONNECT` と `DTLS-REATTEMPT` を繰り返し、vSmart とのコントロールセッションが確立しません。`show control local-properties` の結果、`certificate-status` は `VALID` でしたが、`organization-name` に "CCIE_LAB" と表示されています。vSmart 側の Organization Name は "CCIE-LAB" です。この障害の原因と解決コマンドを示してください。

**答:**
* **原因:** Organization Name の不一致（アンダースコア `_` と ハイフン `-` の不一致）。vBond / vSmart は認証時に証明書の Org Name およびシステム設定の Org Name が完全一致しない場合、コントロール接続を即座に破棄します。
* **解決コマンド:**
  ```bash
  system
   organization-name "CCIE-LAB"
  commit
  ```

---

### Question 2 (Design / TLOC Extension)

**問:** ある拠点に 2 台の WAN Edge (Edge-1, Edge-2) が配置されています。Edge-1 は Internet 回線のみ、Edge-2 は MPLS 回線のみに物理接続されています。拠点の全 LAN トラフィックに対して両方の WAN 回線で二重化を行うため、TLOC Extension を設計・実装します。TLOC Extension リンク用物理ポートにおける `tunnel-interface` コマンドの設定可否について説明してください。

**答:**
* TLOC Extension 用の物理リンクインターフェイス上には **`tunnel-interface` コマンドを設定してはならない**。
* **理由:** TLOC Extension リンク自体は単なる L2/L3 送信パス（VPN 0 内のローカル転送路）であり、自機が直接 IPsec トンネルを形成するエンドポイントではないため。Tunnel インターフェイスを設定すると、不要な Overlay トンネル試行が発生し、ループや接続不全の原因となる。対向ルータの WAN ポート IP へ向かうルーティングのみを VPN 0 内で記述する。

---

### Question 3 (Configuration / Allowed Services)

**問:** 要件「VPN 0 インターフェイスにおいて、コントロール接続および ICMP 応答のみを許可し、BGP、OSPF、SSH、NETCONF、DHCP のサービスを一切遮断せよ」を満たす CLI コンフィグを記述してください。

**答:**
```text
interface GigabitEthernet0/0/0
 vrf forwarding 0
 tunnel-interface
  allow-service icmp
  no allow-service dhcp
  no allow-service dns
  no allow-service ssh
  no allow-service netconf
  no allow-service bgp
  no allow-service ospf
 exit
!
```

---

### Question 4 (Cloud Edge Deployment)

**問:** AWS 上にデプロイする Catalyst 8000v (cEdge) において、コントロールプレーン接続を確立するために最も重要なネットワーク要件（IP / Elastic IP バインド）について説明してください。

**答:**
* AWS VPC 内の Catalyst 8000v WAN インターフェイス (Gi1) は通常プライベート IP アドレス（例: `10.0.1.50`）が割り当てられます。
* コントロールプレーン（vBond / vSmart）および他拠点 Edge とパブリックインターネット経由で通信するためには、AWS AWS Management Console または CloudFormation/Terraform にて、Gi1 の ENI に対して **1:1 Elastic IP (Public IP)** をアタッチし、セキュリティグループで UDP 12346、12446、4500、500 (IPsec/DTLS) を許可する必要がある。

---

### Question 5 (System Configuration)

**問:** 同一拠点内に配置された 2 台の WAN Edge ルータにおいて、`site-id` を「同じ値」に設定すべき理由を技術的に説明してください。

**答:**
* Cisco SD-WAN の仕様上、異なる `site-id` を持つ WAN Edge 相互間には、vSmart 経由で TLOC が広告され、自動的にフルメッシュ IPsec データトンネルが生成されます。
* 同一拠点内の冗長 2 台のルータが異なる Site ID を持つと、拠点内で無用な IPsec トンネルが形成され、帯域とルータ CPU リソースを圧迫します。同一 Site ID を設定することで、拠点内での直接 IPsec トンネル形成が抑制され、LAN 側の冗長プロトコル（VRRP/OSPF/BGP）または TLOC Extension による効率的な冗長化が可能となります。

---

## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Systems and Interfaces Configuration Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/ios-xe-17/systems-interfaces-book-ios-xe-17.html)
* [Cisco SD-WAN Controller Deployment and Bringup Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/sdwan-deployment-guide/sd-wan-deployment-guide.html)
* [Cisco Validated Design (CVD) - SD-WAN End-to-End Deployment Guide](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/cisco-sdwan-end-to-end-deployment-guide.html)
* [Cisco Live BRKCRS-2110 - Cisco SD-WAN Architecture & Deployment](https://www.ciscolive.com)
* [Cisco Technical Support - Troubleshooting SD-WAN Control Connections](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)

---

## 📝 補足（Notes）

* **System IP の疎通要否:** System IP は 32-bit の純粋な論理識別子であり、アンダーレイ網内でルーティング可能（Ping 応答可能）である必要はありません。ただし、トラブルシューティング時の識別子として Loopback インターフェイス IP と一致させることが一般的です。
* **vBond Port 指定:** ポート番号を省略した場合、デフォルトの `12346` が使用されます。マルチテナント構成等でポートが変更されている場合は `vbond <IP> port <NUMBER>` の明示指定が必要です。
* **証明書状態の確認:** 新規ルータのオンボーディング時は、`show control local-properties` で `certificate-status: Installed` となっていることを確認してください。`Invalid` の場合は Smart Licensing 経由での Serial File 同期または Root CA インストールが必要です。


## 🔗 参考リソースリンク

### Cisco Live セッション (動画・スライド)
*   [**BRKENT-2296: Designing Cisco SD-WAN Controllers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2296) - コントローラの初期配置とアンダーレイ設計。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - コネクション確立のトラブル解決。
*   [**BRKRST-2559: 3 Steps to Design Cisco SD-WAN On-Prem**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2559) - オンプレミスでのデプロイ。

### Configuration ガイド
*   [**Cisco SD-WAN System and Interfaces Overview**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/vedge-20-x/system-interface-book/m-system-overview.html)
*   [**Configuring WAN Edge Onboarding (CVD)**](https://www.cisco.com/c/dam/en/us/td/docs/solutions/CVD/SDWAN/sd-wan-wan-edge-onboarding-deploy-guide-2020jan.pdf)

### テクニカルノーツ
*   [**Troubleshooting SD-WAN Control Connections**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)
*   [**SD-WAN TLOC Extension Deployment Guide**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214488-sd-wan-tloc-extension-deployment-guide.html)

---

## 📝 補足
- この学習メモは、SD-WAN の「最初の壁」であるアンダーレイの構築を網羅しています。CCIE 実技試験においては、DNA Center 同様、vManage での Feature Template 操作が主となりますが、**不具合発生時に CLI で `show control local-properties` を叩き、証明書の状態や Org-Name を即座に確認できるか**が、時間を節約し合格を勝ち取るためのクリティカルなスキルとなります。

