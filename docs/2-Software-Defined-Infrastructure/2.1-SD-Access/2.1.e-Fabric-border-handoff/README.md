---
layout: default
title: 2.1.e-Fabric-border-handoff
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 5
---

# 2.1.e Fabric border handoff

Cisco SD-Access (SDA) ファブリックにおいて、ファブリック外部ネットワーク（WAN、Internet、データセンター、既存L2/L3インフラ、SD-WAN）と安全かつ確実にマルチテナント（VRF/VN）およびセキュリティコンテキスト（SGT）を維持して相互接続するための必須技術である **`2.1.e Fabric border handoff`**（SDA, SDWAN, IP transits, Peer device / Fusion router, Layer 2 border handoff）について、Cisco Catalyst Center (旧 Cisco DNA Center) 2.3.x、Cisco SD-WAN (Cisco Catalyst SD-WAN) 20.x、Cisco ISE 3.x、および Cisco IOS-XE 17.x の実装基準に100%準拠して詳細に解説します。

---

## 📘 概要

* **機能概要:** 
  Fabric Border Handoff は、SD-Access ファブリックの境界に位置する **Fabric Border Node** が、ファブリック内部のオーバーレイ空間（Virtual Network: VN / VRF、および Security Group Tag: SGT）を外部のネットワークインフラと接続・相互変換するための制御・データ・ポリシーのハンドオフメカニズムです。
* **利用目的:** 
  1. **L3 Multi-VRF Handoff (Fusion Router 連携):** ファブリック内の分離された VN (VRF) ごとに外部ルータ（Fusion Router）と個別 BGP / OSPF セッションを確立し、Shared Services (DHCP, DNS, ISE, Active Directory) や 外部 WAN / Internet へのルートを交換する。
  2. **SD-WAN Transit Handoff:** SD-Access ファブリックの VN と Cisco SD-WAN の Service VPN (VPN 1〜511) を直接マッピングし、WAN 越えのパケットにおいて SGT 情報（Security Group Tag）を維持したまま暗号化カプセル化（IPsec / OMP）転送する。
  3. **IP Transit Handoff:** 伝統的な IP WAN 網や MP-BGP 網を経由して、複数サイトの SDA ファブリック間を VRF-Lite および SXP (SGT Exchange Protocol) で相互接続する。
  4. **Layer 2 Border Handoff:** ファブリック内部の L2 Virtual Network (VLAN/VNI) をファブリック外部の既存 Layer 2 スイッチ（非ファブリック Catalyst 等）やデータセンター L2 網へ 802.1Q トランクを介して直接延伸する。
* **どのような場面で利用するか:** 
  キャンパス網の SD-Access 化において、段階的移行（Migration）、既存ネットワーク資産（Fusion Router / Catalyst 9000）の活用、共有サービス（Shared Services）への制御されたアクセス許可、および拠点間 SD-WAN 統合を実現するすべてのエンタープライズ構成で必須となります。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **特徴** | L3/L2境界において、SDAオーバーレイ（LISP/VXLAN/SGT）と外部標準プロトコル（VRF-Lite/BGP/802.1Q/SXP/SD-WAN OMP）を相互変換 |
| **用途** | 共有サービス（DHCP/DNS/ISE）接続、外部WAN/Internet接続、SD-WAN統合作業、既存L2ネットワークとの延伸 |
| **メリット** | ファブリック内の完全なエンドツーエンドセグメンテーション（VN/VRF）およびロールベースセキュリティ（SGT）を外部網まで維持可能 |
| **デメリット** | Border と Fusion Router 間で VRF ごとの Subinterface / BGP ピア設定が必要（自動化未使用時はコンフィグが複雑化） |
| **対応機種** | Cisco Catalyst 9300 / 9400 / 9500 / 9600 シリーズ, Cisco ISR 4000 / ASR 1000 / Catalyst 8000 シリーズ |
| **制限事項** | L2 Border Handoff では Spanning Tree Protocol (STP) がファブリック境界で制限され、ループ防止設計が極めて重要 |
| **設計上の注意点** | Fusion Router での Mutual Route Leaking 時、BGP/OSPF 間の再配送ループやルートフィルタリング漏れに注意 |

---

## 🏗 動作原理

### 1. L3 Border Handoff (Fusion Router 連携) 通信フロー
SDA エンドポイント（EID）から Shared Services サーバー（DHCP / DNS / ISE）宛の通信フロー：

```
Fabric Edge Node (EID)
   ↓ [1] Encapsulated in VXLAN (VNI = VN ID, SGT = 16-bit)
Fabric Border Node (Internal Border)
   ↓ [2] Decapsulate VXLAN, Lookup VRF Route Table
Border Subinterface (VLAN 101 for VN-A)
   ↓ [3] VRF-Lite 802.1Q tagged frame (BGP Peering per VRF)
Fusion Router (VRF VN-A)
   ↓ [4] VRF Mutual Route Leaking (BGP/OSPF)
Fusion Router (Global / Shared Services VRF)
   ↓ [5] IP Routing
Shared Services Server (DHCP / DNS / ISE)
```

### 2. SD-WAN Transit Handoff (SDA to SD-WAN) 通信フロー

```
Fabric Edge (Site 1)
   ↓ [1] LISP / VXLAN (VN 1, SGT 10)
SDA Border / SD-WAN Border (Co-located cEdge)
   ↓ [2] VN-to-VPN Mapping (VN 1 -> VPN 10)
   ↓ [3] SGT in OMP / IPsec Header (SGT 10 preserved)
SD-WAN Transport Network (WAN)
   ↓ [4] OMP Route Exchange & IPsec Tunnel
Remote SD-WAN / SDA Border (Site 2)
   ↓ [5] VPN-to-VN Mapping (VPN 10 -> VN 1)
Fabric Edge (Site 2) [SGT 10 Enforcement]
```

### 3. Layer 2 Border Handoff 通信フロー

```
SDA Endpoint (VLAN 10 / VNI 8100)
   ↓
Fabric Edge Node
   ↓ [VXLAN L2 VNI 8100]
L2 Fabric Border Node
   ↓ [L2 VNI to VLAN 10 Mapping]
802.1Q Trunk (VLAN 10 Native/Tagged)
   ↓
Non-Fabric Catalyst Switch (VLAN 10)
   ↓
Legacy Server / Non-Fabric Host
```

---

## ⚙ 動作シーケンス

1. **Host Onboarding & EID Registration:**
   * Fabric Edge で端末が認証（802.1X/MAB）され、特定の VN (VRF) および SGT が割り当てられ、Control Plane (LISP MS/MR) に EID が登録されます。
2. **Fabric 内パケットカプセル化:**
   * Fabric Edge は宛先 IP に基づいて Border の RLOC を解決し、パケットを VXLAN-GPO（VNI ＋ SGT）でカプセル化して Border Node へ送信します。
3. **Border Node でのカプセル化解除と VRF 転送:**
   * Border Node は VXLAN パケットを受信し、ヘッダーを解除して該当する VRF のルーティングテーブルを参照します。
4. **VRF-Lite Handoff (Fusion Router 宛):**
   * Border は VRF ごとに設定された 802.1Q サブインターフェイス経由で、VRF ごとの BGP / OSPF パケットとして Fusion Router へ送出します。
5. **Fusion Router での Route Leaking & アクセス制御:**
   * Fusion Router は各 VRF（VN-A, VN-B 等）からのルートを受信し、Shared Services VRF（または Global）へ MP-BGP や VRF Route-Leaking（BGP/OSPF 再配送 ＋ Route-Map）を用いて集約・配布します。
6. **SGT 伝搬 (SXP / Inline Tagging):**
   * L3 Handoff 時に IP/MAC パケットから SGT 情報が失われる場合、Border または Fusion Router と Cisco ISE 間で **SXP (SGT Exchange Protocol)** セッションを張り、IP-to-SGT バインディングテーブルを外部スイッチ／ファイアウォール（FTD/ASA）へ伝搬します。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprintで重要なポイント
* **VRF-Lite BGP Handoff:** Border と Fusion Router 間で VRF ごとに 802.1Q サブインターフェイスおよび eBGP / iBGP ピアリングを正しく手動設定できること。
* **Fusion Router での Mutual Route Leaking:** BGP コミュニティや Route-Map を用いて、Shared Services ルート（DHCP/DNS）のみを各 VN にリークし、VN 間の不必要な直通通信（VN-to-VN Leaking）を防止する設定。
* **Default Route 広告:** External Border からファブリック内部（LISP MS/MR）へデフォルトルート（`0.0.0.0/0`）を広告し、`map-cache 0.0.0.0/0 map-request` によりファブリック内から外部への通信を誘導すること。
* **L2 Border Handoff 制限とループ回避:** L2 Border Node における 802.1Q Trunk 設定と、Spanning Tree (STP) がファブリック透過とならない点への対処。

### ラボ試験で設定させられそうな内容
1. **Border - Fusion 間 VRF-Lite eBGP ピアリング:**
   * 各 VN（例: Campus_VN, Guest_VN）に対応するサブインターフェイス（VLAN 101, 102）での eBGP セッション構築。
2. **Fusion Router での BGP Route Leaking (Import/Export Target):**
   * BGP `address-family ipv4 vrf` 内での Route-Target 制御、または Route-Map を用いた再配送制御。
3. **External Border での Aggregate EID / Default Route 登録:**
   * LISP コマンドにおける `ip lisp map-space` / `export-store-into-rib` 設定。
4. **SD-WAN Border での VN-to-VPN マッピング:**
   * Cisco SD-WAN vSmart ポリシーまたは cEdge 設定での Service VN (SDA) ↔ Service VPN (SD-WAN) 統合。

### よくある設定ミス
* **BGP Autonomous System Number (ASN) の不一致:** Border と Fusion Router 間で AS 番号が一致していない、あるいは `ebgp-multihop` / `local-as` の設定漏れ。
* **Fusion Router での非対称リーク (Asymmetric Leaking):** Shared Services から VN への戻りルートがリークされていないため、SYN-ACK パケットが破棄される。
* **MTU ミスマッチ:** Border - Fusion 間の Subinterface や WAN ポートで MTU 1500 のまま放置され、大型パケット（VXLAN カプセル化解除後）や BGP パケットがフラグメント破棄される。

---

## 🛠 設定方法

### 1. Fabric Border Node 側の VRF-Lite BGP Handoff 設定 (IOS-XE)

```text
! --- VRF 定義 ---
vrf definition Enterprise_VN
 rd 65001:101
 address-family ipv4
  exit-vrf
!
vrf definition Guest_VN
 rd 65001:102
 address-family ipv4
  exit-vrf
!
! --- 外部 Fusion 接続用 Subinterface 設定 ---
interface GigabitEthernet1/0/1.101
 description Handoff to Fusion Router - Enterprise_VN
 encapsulation dot1Q 101
 vrf forwarding Enterprise_VN
 ip address 10.255.101.1 255.255.255.252
!
interface GigabitEthernet1/0/1.102
 description Handoff to Fusion Router - Guest_VN
 encapsulation dot1Q 102
 vrf forwarding Guest_VN
 ip address 10.255.102.1 255.255.255.252
!
! --- BGP 設定 (VRF-Lite eBGP) ---
router bgp 65001
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf Enterprise_VN
  neighbor 10.255.101.2 remote-as 65002
  neighbor 10.255.101.2 activate
  neighbor 10.255.101.2 as-override
  exit-address-family
 !
 address-family ipv4 vrf Guest_VN
  neighbor 10.255.102.2 remote-as 65002
  neighbor 10.255.102.2 activate
  exit-address-family
```

### 2. Peer Device (Fusion Router) 側の BGP Route Leaking 設定

```text
! --- VRF 定義 ---
vrf definition Enterprise_VN
 rd 65002:101
 route-target import 65002:999 ! Shared Services からのルートをインポート
 route-target export 65002:101
 address-family ipv4
  exit-vrf
!
vrf definition Shared_Services
 rd 65002:999
 route-target import 65002:101 ! Enterprise_VN からのルートをインポート
 route-target export 65002:999
 address-family ipv4
  exit-vrf
!
! --- BGP 設定 ---
router bgp 65002
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf Enterprise_VN
  neighbor 10.255.101.1 remote-as 65001
  neighbor 10.255.101.1 activate
  exit-address-family
 !
 address-family ipv4 vrf Shared_Services
  redistribute connected
  exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| Border-Fusion 間 VRF BGP ピア確認 | <code>show ip bgp vrf <VN_NAME> summary</code> |
| VRF ルーティングテーブル確認 | <code>show ip route vrf <VN_NAME></code> |
| LISP 外部 EID 登録状況確認 | <code>show lisp instance-id <ID> ipv4 map-cache</code> |
| Subinterface 802.1Q タグ確認 | <code>show interfaces GigabitEthernet1/0/1.<VLAN></code> |
| Fusion Router での Route Leaking 確認 | <code>show ip bgp vpnv4 vrf <VN_NAME></code> |
| Border Node の LISP エクスポート状況 | <code>show running-config \| section lisp</code> |
| SXP ピアリング確認 (SGT 伝搬) | <code>show cts sxp connections</code> |
| BGP リアルタイムパケット確認 | <code>debug ip bgp vrf <VN_NAME> updates</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **SDA端末から DHCP/DNS 宛に通信不可** | Fusion Router で Shared Services ⇔ VN 間の相互 Route Leaking 不備 | <code>show ip route vrf <VN_NAME></code> | Route-Target または Route-Map による相互ルートリークを修正 |
| **BGP セッションが Idle / Active のまま立たない** | Subinterface の VLAN ID や IP アドレス、AS 番号の誤り | <code>show ip bgp vrf <VN_NAME> summary</code> | 802.1Q encapsulation VLAN および IP アドレスの不整合を解消 |
| **ファブリック内部から外部 Internet 宛に通信不可** | External Border から LISP MS/MR へデフォルトルートが広告されていない | <code>show lisp instance-id <ID> ipv4 map-cache</code> | Border で <code>default-information originate</code> または <code>map-cache 0.0.0.0/0</code> を投入 |
| **特定 VN の通信で MTU パケットがドロップする** | Subinterface または Fusion Router ポートで MTU 1500 のまま制限されている | <code>ping vrf <VN> <DEST> size 1500 df-bit</code> | Border / Fusion 間の物理・論理ポートで MTU 9100 を一括バインド |
| **SGT タグが外部 FW / SD-WAN で失われる** | L3 Handoff ポートで SXP が未設定、または SGT Inline Tagging (<code>cts manual</code>) 不足 | <code>show cts interface</code> / <code>show cts sxp connections</code> | Border-Fusion 間で SXP セッションを構成するか inline tagging を有効化 |

---

## ⚠ 制限事項

* **L2 Border Handoff のループ制約:** 
  SDA ファブリックは L2 データプレーン（VXLAN）を提供するが、外部 L2 スイッチとの間で Spanning Tree (STP) BPDU パケットを完全に透過（Pass-through）させない設計となっている。そのため、複数 L2 Border で同一 VLAN を手動接続する場合、ファブリック外部で L2 ループが発生する危険性が極めて高い。
* **Fusion Router のスケーラビリティ:** 
  Fusion Router 上で大量の VN (VRF) ごとに BGP セッションおよび Route Leaking ルールを定義すると、ルータの Control Plane (CPU / RAM) リソースを大量に消費するため、ハイエンドルータ（Catalyst 9500 / ASR 1000 シリーズ）の選定が必要。

---

## 🔄 他技術との関連

* **Cisco SD-WAN (OMP / Service VPN):** SD-WAN Border において、SDA VN (VNI) と SD-WAN Service VPN を 1:1 または N:1 でマッピングし、OMP 経由で WAN 越えのルートと SGT を伝搬。
* **Cisco ISE (SXP / RADIUS):** L3 Border / Fusion Router と ISE 間で SXP セッションを確立し、IP-to-SGT バインディング情報を動的共有。
* **VRF-Lite & BGP:** Border と Fusion Router 間のマルチテナント相互接続プロトコルとして標準適用。
* **LISP (Locator/ID Separation Protocol):** Border Node においてファブリック内 EID 空間と外部 RLOC 空間を橋渡しする制御プロトコル。

---

## 🧩 比較表

### Fabric Border Handoff 方式の比較

| 項目 | L3 VRF-Lite Handoff (Fusion) | SD-WAN Transit Handoff | IP Transit (SXP + VRF-Lite) | Layer 2 Border Handoff |
| --- | --- | --- | --- | --- |
| **接続対象** | 共有サービス (DHCP/DNS/ISE), DC | 広域 SD-WAN 網 | 既存 IP WAN / MPLS 網 | 既存 L2 Catalyst スイッチ, ESXi |
| **セグメンテーション** | VRF (Subinterface) | Service VPN (VPN 1-511) | VRF-Lite (802.1Q) | L2 VNI ↔ VLAN 1:1 マッピング |
| **SGT 伝搬方式** | SXP または Inline Tagging | OMP Header / IPsec (Native) | SXP (SGT Exchange Protocol) | VXLAN-GPO (Native) |
| **制御プロトコル** | eBGP / OSPF per VRF | OMP (Overlay Management) | eBGP / MP-BGP | LISP L2 EID / Dynamic Registration |
| **主な用途** | 共有サービス接続・DC境界 | 拠点間 WAN 高度統合 | 段階的 SDA 移行・マルチサイト | レガシーサーバー収容・L2 移行 |

---

## 💡 ベストプラクティス

1. **Fusion Router の冗長化と Active/Active BGP:**
   * 各 Fabric Site に 2 台の Border Node を配置し、2 台の Fusion Router とそれぞれ VRF-Lite eBGP ピアリング（フルメッシュ ECMP）を構成して冗長性を確保する。
2. **Shared Services 宛てルートリークの厳格な制御:**
   * BGP Route-Target または Route-Map を用いて、Shared Services 宛ての必要最小限のプレフィックス（/32 または /24 サブネット）のみを各 VN にリークし、全 VRF のルートが不要に混ざり合わないよう最小権限の法則（Least Privilege）を適用する。
3. **External Border での 0.0.0.0/0 広告ルール:**
   * 外部 Internet 出口を持つ External Border からファブリック内 LISP MS/MR に対して `default-information originate` を有効化し、ファブリック内の未登録 EID 通信を安全に外部へエスケープさせる。

---

## 📝 ラボ学習・設定サンプル例

### Lab 01: Border-Fusion 間 VRF-Lite eBGP 基本構成
* **問題:** Fabric Border 1 (AS 65001) と Fusion Router 1 (AS 65002) 間で、`CORP_VN` (VLAN 101, 10.1.1.0/30) の VRF eBGP ピアリングを構成せよ。
* **要件:**
  * Border1 側: Gi1/0/1.101, IP 10.1.1.1/30, VRF `CORP_VN`
  * Fusion1 側: Gi1/0/1.101, IP 10.1.1.2/30, VRF `CORP_VN`
  * BGP セッションを確立し、`CORP_VN` 内のルートを相互交換すること。
* **設定例 (Border1):**
```text
vrf definition CORP_VN
 rd 65001:101
 address-family ipv4
 exit-vrf
!
interface GigabitEthernet1/0/1.101
 encapsulation dot1Q 101
 vrf forwarding CORP_VN
 ip address 10.1.1.1 255.255.255.252
!
router bgp 65001
 address-family ipv4 vrf CORP_VN
  neighbor 10.1.1.2 remote-as 65002
  neighbor 10.1.1.2 activate
 exit-address-family
```
* **検証方法:** `show ip bgp vrf CORP_VN summary` を実行し、State が `Established` であることを確認。

---

### Lab 02: Fusion Router での BGP Route-Target による Mutual Route Leaking
* **問題:** Fusion Router 上で `CORP_VN` と `SHARED_VN` 間で相互ルートリークを設定せよ。
* **要件:**
  * `CORP_VN` (RD 65002:101): Export 65002:101, Import 65002:999
  * `SHARED_VN` (RD 65002:999): Export 65002:999, Import 65002:101
* **設定例 (Fusion1):**
```text
vrf definition CORP_VN
 rd 65002:101
 route-target export 65002:101
 route-target import 65002:999
 address-family ipv4
 exit-vrf
!
vrf definition SHARED_VN
 rd 65002:999
 route-target export 65002:999
 route-target import 65002:101
 address-family ipv4
 exit-vrf
```
* **検証方法:** `show ip route vrf CORP_VN` を実行し、`SHARED_VN` 配下のサブネットが BGP ルートとして学習されていることを確認。

---

### Lab 03: External Border からの Default Route LISP エクスポート
* **問題:** External Border Node 1 上で、外部網からのデフォルトルート (`0.0.0.0/0`) をファブリック内の LISP MS/MR へ広告せよ。
* **要件:**
  * VRF `INFRA_VN` および `CORP_VN` に対して、デフォルトエクスポートを設定。
* **設定例 (Border1):**
```text
router lisp
 locator-table default
 instance-id 101
  service ipv4
   default-information originate
   exit-service-ipv4
  exit-instance-id
```
* **検証方法:** Fabric Edge 上で `show lisp instance-id 101 ipv4 map-cache` を実行し、`0.0.0.0/0` が Border の RLOC を宛先として登録されていることを確認。

---

### Lab 04: SXP (SGT Exchange Protocol) スピーカー構成 (Border - ISE 間)
* **問題:** Fabric Border 1 (10.100.1.1) と Cisco ISE (10.200.1.1) 間で SXP v4 ピアリングを構成せよ。
* **要件:**
  * Border 側: SXP Speaker ロール, パスワード `Cisco123`
* **設定例 (Border1):**
```text
cts sxp enable
cts sxp default password Cisco123
cts sxp connection peer 10.200.1.1 password default mode local speaker
```
* **検証方法:** `show cts sxp connections` を実行し、Status が `On` になっていることを確認。

---

### Lab 05: Layer 2 Border Handoff (L2 VNI to VLAN Mapping)
* **問題:** Fabric Border 1 上で、L2 VNI 8100 (VLAN 100) を非ファブリック Catalyst スイッチ宛ての Trunk ポート (Gi1/0/2) に handoff 設定せよ。
* **要件:**
  * Gi1/0/2: 802.1Q Trunk, Allowed VLAN 100
* **設定例 (Border1):**
```text
vlan 100
 name Legacy_L2_VN
!
interface GigabitEthernet1/0/2
 switchport trunk encapsulation dot1q
 switchport mode trunk
 switchport trunk allowed vlan 100
!
interface NBI100
 description L2 Border Interface for VNI 8100
```
* **検証方法:** 非ファブリック端末から ping を送信し、`show mac address-table vlan 100` でファブリック内ホストの MAC アドレスが学習されていることを確認。

---

### Lab 06: SD-WAN Border での Service VN to Service VPN マッピング
* **問題:** SD-WAN コロケーション Border (cEdge) 上で、SDA `CORP_VN` (VNI 4097) を SD-WAN `VPN 10` へマッピングせよ。
* **要件:**
  * SD-WAN OMP 経由で `VPN 10` のルートを相互学習すること。
* **設定例 (cEdge Border):**
```text
sdwan
 interface GigabitEthernet1/0/1.101
  vrf 10
  ip address 10.1.1.1 255.255.255.252
 !
 omp
  address-family ipv4 vrf 10
   advertise bgp
   advertise connected
```
* **検証方法:** `show sdwan omp routes vrf 10` を実行し、リモート拠点の VPN 10 プレフィックスが受信されていることを確認。

---

### Lab 07: Fusion Router での Route-Map による非対称リーク防止フィルタ
* **問題:** Fusion Router 上で Route-Map を用い、`SHARED_VN` (192.168.1.0/24) のみが `GUEST_VN` へリークされるよう制限せよ。
* **要件:**
  * 他の内部 VN サブネットが `GUEST_VN` へ再配送されないこと。
* **設定例 (Fusion1):**
```text
ip prefix-list PL_SHARED_ONLY permit 192.168.1.0/24
!
route-map RM_LEAK_TO_GUEST permit 10
 match ip address prefix-list PL_SHARED_ONLY
!
router bgp 65002
 address-family ipv4 vrf GUEST_VN
  redistribute bgp 65002 route-map RM_LEAK_TO_GUEST
```
* **検証方法:** `show ip route vrf GUEST_VN` を実行し、192.168.1.0/24 のみが表示され、他 VN のルートが存在しないことを確認。

---

### Lab 08: Dual External Border での Priority ベース出口制御
* **問題:** Border 1 (Priority 200) と Border 2 (Priority 100) の External Border 冗長構成を組み、通常時は Border 1 を優先外部出口に設定せよ。
* **要件:**
  * LISP 登録時の Priority を調整すること。
* **設定例 (Border1):**
```text
router lisp
 locator-table default
 instance-id 101
  service ipv4
   export-store-into-rib
   priority 200
```
* **設定例 (Border2):**
```text
router lisp
 locator-table default
 instance-id 101
  service ipv4
   export-store-into-rib
   priority 100
```
* **検証方法:** Fabric Edge で `show lisp instance-id 101 ipv4 map-cache` を実行し、Border 1 の RLOC が最優先選定されていることを確認。

---

### Lab 09: Border Node での SGT Inline Tagging (802.1Q Ethernet Header) 構成
* **問題:** Border 1 - Fusion 1 間で SXP を使用せず、物理リンク (Gi1/0/1) 上でパケットヘッダー内に SGT (CMD/CMD-tag) を直接挿入（Inline Tagging）して伝搬せよ。
* **要件:**
  * Gi1/0/1 で `cts manual` を有効化すること。
* **設定例 (Border1):**
```text
interface GigabitEthernet1/0/1
 cts manual
  policy static sgt 100-trusted
  enable sgport
```
* **検証方法:** `show cts interface GigabitEthernet1/0/1` を実行し、`Inline SGT Processing: Enabled` を確認。

---

### Lab 10: VRF-Lite Handoff トラブルシューティング（MTU / BGP Mismatch 復旧）
* **問題:** Border 1 経由での大量データ転送時、BGP アップデートや 1500 バイト超のパケットが破棄される障害を調査・修復せよ。
* **要件:**
  * 物理ポート Gi1/0/1 および全 Subinterface で MTU 9100 を一括バインドすること。
* **設定例 (Border1):**
```text
interface GigabitEthernet1/0/1
 mtu 9100
!
interface GigabitEthernet1/0/1.101
 ip mtu 9000
```
* **検証方法:** `ping vrf CORP_VN 10.1.1.2 size 8900 df-bit` を実行し、応答が得られることを確認。

---

## ❓ 想定試験問題

### Q1. 【コンフィグ読解】
以下の Fabric Border 1 のコンフィグにおいて、ファブリック内部のエンドポイントから Fusion Router 経由で Shared Services への通信が失敗している。原因として最も適切なものを選べ。

```text
vrf definition CORP_VN
 rd 65001:101
 address-family ipv4
 exit-vrf
!
interface GigabitEthernet1/0/1.101
 encapsulation dot1Q 101
 vrf forwarding CORP_VN
 ip address 10.1.1.1 255.255.255.252
!
router bgp 65001
 address-family ipv4 vrf CORP_VN
  neighbor 10.1.1.2 remote-as 65001
  neighbor 10.1.1.2 activate
```

* (A) `encapsulation dot1Q 101` の VLAN ID が間違っている。
* (B) BGP で `remote-as 65001` となっており、iBGP ピアリングとなっているが `next-hop-self` または `as-override` / eBGP 設定が不足している。
* (C) VRF `CORP_VN` で RD が定義されていない。
* (D) BGP の `address-family ipv4` が無効化されている。

**正解:** (B)  
**解説:** Border Node と Fusion Router 間は通常 **VRF-Lite eBGP (異種 AS 番号)** を使用します。上記設定では両者とも AS 65001 であり iBGP となっています。iBGP の場合、Fusion Router から他へルートが再転送されない、または AS_PATH ループ判定で拒否されるため、通常は eBGP ピアリング (`remote-as 65002`) を構成するか `as-override` をバインドする必要があります。

---

### Q2. 【トラブルシューティング】
SDA ファブリック内のホストから Fusion Router に接続された DHCP サーバーから IP アドレスが取得できない。Fusion Router 上で `show ip route vrf CORP_VN` を確認したところ、DHCP サーバーのサブネット（192.168.10.0/24）が存在しなかった。この障害を修正するための Fusion Router 側の設定はどれか。

* (A) `vrf definition CORP_VN` 配下で `route-target import <SHARED_Services_RT>` を追加する。
* (B) Border Node 上で `ip helper-address` を削除する。
* (C) Fusion Router の BGP に `bgp default local-preference 200` を追加する。
* (D) Fabric Edge 上で `device-tracking policy` を無効化する。

**正解:** (A)  
**解説:** Fusion Router 上で Shared Services VRF のルートを各 VN (CORP_VN) へリークさせるには、`CORP_VN` の VRF 定義内で Shared Services の Route-Target をインポート（`route-target import`）する必要があります。

---

### Q3. 【Design】
SD-Access ファブリックと広域 WAN 網を統合する設計において、ファブリック内のセキュリティポリシー（SGT）をリモート拠点まで完全維持して転送するための最も推奨される Handoff 構成はどれか。

* (A) VRF-Lite + GRE トンネル
* (B) Cisco SD-WAN Transit Handoff (OMP Header 統合)
* (C) Layer 2 Border Handoff + 802.1Q Trunk
* (D) IP Transit + L2TPv3

**正解:** (B)  
**解説:** Cisco SD-WAN Transit Handoff では、vSmart / OMP プロトコルを用いて SDA の VN を SD-WAN の Service VPN へ直接マッピングし、IPsec / OMP ヘッダー内で SGT 情報をネイティブに維持して WAN 越え転送できるため、最も推奨される設計となります。

---

### Q4. 【実装】
Fabric Border Node と外部スイッチ間で SGT (Security Group Tag) 情報を伝搬させたいが、中間のネットワーク機器が 802.1Q Ethernet ヘッダー内の CMD タグ（Inline Tagging）に対応していない。この環境で SGT 情報を伝搬させるための代替プロトコルはどれか。

* (A) LISP Map-Request
* (B) SXP (SGT Exchange Protocol)
* (C) BGP EVPN Route Type 2
* (D) VXLAN-GPO

**正解:** (B)  
**解説:** 中間機器が Inline Tagging (CMD) や VXLAN-GPO に未対応の場合、TCP 64994 を使用する **SXP (SGT Exchange Protocol)** を用いて、IP アドレスと SGT のバインディングテーブルをピア機器（ISE / Firewall / Switch）間へ制御プレーン上で動的伝搬させます。

---

### Q5. 【トラブルシューティング】
Layer 2 Border Handoff を使用して SDA ファブリック内の VLAN 100 を外部 Catalyst スイッチへ延伸したところ、ファブリック外部で激しい L2 ループが発生しネットワークがダウンした。原因と対策として正しい組み合わせはどれか。

* (A) **原因:** SDA ファブリックが STP BPDU を透過しないため、外部スイッチ間でループが形成された。**対策:** 外部スイッチ接続ポートで BPDU Guard や Loop Guard を有効化し、ファブリック側をブロックする。
* (B) **原因:** LISP MS/MR が停止した。**対策:** MS/MR を再起動する。
* (C) **原因:** VXLAN VNI の値が重複していた。**対策:** VNI を変更する。
* (D) **原因:** SGT タグが不一致となった。**対策:** SGT を統一する。

**正解:** (A)  
**解説:** SDA ファブリックは L2 データプレーンを提供しますが、Spanning Tree (STP) BPDU を完全に透過させないため、外部 L2 スイッチとの間で複数パスが存在すると外部側でループが発生します。外部スイッチポート側で BPDU Guard や Storm Control 等を適切に設計・バインドする必要があります。

---

## 🔗 参考リソース

* [Cisco SD-Access Solution Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/Cisco-DnA-Center/3-3-2/design/guide/b_sda_design_guide.html)
* [Cisco SD-Access Fabric Border and Fusion Router Deployment Guide](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215617-sda-border-fusion-router-deployment-guide.html)
* [Cisco Live BRKCRS-2810: Cisco SD-Access - Border and External Connectivity Design](https://www.ciscolive.com/)
* [Cisco Command Reference - Catalyst 9500 Series Switches (IOS-XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9500/software/release/17-x/command_reference/b_17x_9500_cr.html)
* [Cisco SD-WAN and SD-Access Integration Guide](https://www.cisco.com/c/en/us/td/docs/solutions/Cisco-DnA-Center/SD-WAN-Integration/sd-wan-sda-integration-guide.html)

---

## 📝 **補足（Notes）**

### 1. Fusion Router と Internal Border の構成図解

```text
  +-------------------------------------------------------+
  |              Shared Services (DHCP/DNS/ISE)           |
  +-------------------------------------------------------+
                              |
                     [Global / Shared VRF]
                              |
                    +-------------------+
                    |   Fusion Router   |
                    +-------------------+
                      /                      [VRF: CORP_VN] /                 \ [VRF: GUEST_VN]
       (Subint .101) /                   \ (Subint .102)
                    /                            +---------------------------------------------+
       |             Fabric Border Node              |
       |  (L3 VRF-Lite Handoff & LISP Map-Server)    |
       +---------------------------------------------+
                              |
                      [VXLAN Overlay]
                              |
       +---------------------------------------------+
       |              Fabric Edge Node               |
       +---------------------------------------------+
```

### 2. ラボ試験直前のチェックリスト
- [ ] Border と Fusion 間で VRF ごとの Subinterface / IP アドレス / BGP ピアが対になっているか？
- [ ] Fusion Router 上で Shared Services 宛てのルートが各 VN へ正常に Import / Export (Route Leaking) されているか？
- [ ] Border ポートおよび物理リンクで Jumbo MTU (9100) が設定されているか？
- [ ] SXP を使用する場合、Border - ISE 間で Password および Speaker/Listener ロールが正しく一致しているか？
- [ ] External Border から LISP コントロールプレーンへ 0.0.0.0/0 デフォルトルートが指示通り送出されているか？


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076) - ボーダーハンドオフの設計パターンとベストプラクティス。
*   [**BRKCRS-2810: Cisco SD-Access Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810) - LISP/BGP 再配送のトラブルシュート。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - ラボ試験での Fusion ルータ構成のポイント。

### Configuration ガイド
*   [**Cisco DNA Center SD-Access IP Transit Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)。
*   [**Configuring L3 Handoff on Catalyst 9000 Switches**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-l3-handoff.html)。

### テクニカルドキュメント・設定例
*   [**SD-Access: Troubleshooting the Fabric (Tech Note on Fusion Routers)**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)。
*   [**Understanding SD-Access Layer 2 Border Handoff**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-l2-handoff.html)。

---


## 📝 補足
- この学習メモは、SD-Access の「境界」をいかに制御するかに焦点を当てています。CCIE 実技試験では、DNA Center でのプロビジョニングに加えて、外部の **Fusion ルータにおける BGP リーキング** が合否を分ける急所となります。Border Node の `redistribute lisp` と Fusion Router の VRF 間の論理を完璧に繋ぎ合わせる練習を繰り返してください。

