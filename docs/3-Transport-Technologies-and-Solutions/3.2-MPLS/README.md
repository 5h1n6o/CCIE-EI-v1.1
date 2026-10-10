---
layout: default
title: 3.2-MPLS
parent: 3-Transport-Technologies-and-Solutions
nav_order: 2
---

# 3.2 MPLS

## 📘 概要

MPLS（Multiprotocol Label Switching）は、IPパケットの先頭に固定長の「MPLSラベル（32ビット）」を付加し、レイヤ3のIPルーティングテーブル（RIB）を毎パケット検索する代わりに、レイヤ2.5のラベル転送テーブル（LFIB: Label Forwarding Information Base）に基づいて高速にパケットを転送するスイッチング技術である。

CCIE Enterprise Infrastructure (EI) v1.1 において、MPLSは単なる高速転送技術としてではなく、**MPLS L3VPN（BGP/MPLS IP VPN）** や **MPLS L2VPN（VPWS / VPLS）**、**Segment Routing（SR-MPLS）**、および **Traffic Engineering（MPLS-TE）** を実現するためのコアトランスポート（WAN/Core Overlay）として非常に重要視されている。

特にPE（Provider Edge）ルータにおける **VRF（Virtual Routing and Forwarding）**、**RD（Route Distinguisher）**、**RT（Route Target）**、**MP-BGP（Multi-Protocol BGP）**、および **LDP（Label Distribution Protocol）** の相互作用の深い理解と、PE-CE間ルーティングプロトコル（BGP, OSPF, EIGRP, Static）のループ防止機構やルート再配送、AS Override / Allowas-in 等の高度な制御がラボ試験で徹底的に問われる。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **特徴** | IPパケットに32ビットのMPLSラベル（20bit Label, 3bit TC/Exp, 1bit S, 8bit TTL）を挿入し、LFIBにより高速転送 |
| **用途** | MPLS L3VPN（企業拠点間仮想プライベート網）、MPLS L2VPN（L2延伸）、QoS制御、Segment Routingのアンダーレイ |
| **メリット** | コア（Pルータ）でのBGPフルメッシュ/全経路保持が不要（BGP Free Core）、VRFによる高度なマルチテナント完全隔離 |
| **デメリット** | ラベルヘッダー（4バイト×ラベル数）によるMTUオーバヘッド、LDP/IGP間の同期不全リスク、トラブルシューティングの複雑化 |
| **対応機種** | Catalyst 9300/9400/9500/9600, Catalyst 8200/8300/8500, ASR1000/9000, ISR4000, CSR1000v / C8000v |
| **制限事項** | PEルータでのVRF数・LFIB容量の上限、L2 MTUミスマッチによるL2VPNセッション不全、PHP（Penultimate Hop Popping）時のExp非引継ぎ |
| **設計上の注意点** | LDPとIGP（OSPF/ISIS）のパス不一致（LDP-IGP Sync要設定）、MP-BGPにおけるRDのユニーク性、RTの適切なインポート/エクスポート設計 |

---

## 🏗 動作原理

MPLSネットワークは、**CE（Customer Edge）**、**PE（Provider Edge）**、および **P（Provider Core）** ルータで構成される。

```
[CE-1] (Site A)
   │ (IP Packets / VRF-A)
   ▼
[PE-1]  ◄─── MP-BGP (VPNv4 Routes + Service Label) ───►  [PE-2]
   │                                                      │
   │ (Push Transport Label & Service Label)               │ (Pop Service Label)
   ▼                                                      ▲
 [P-1]  ─── (Swap Transport Label / PHP) ───► [P-2] ──────┘
                                                          │
                                                          ▼
                                                      [CE-2] (Site B)
```

### MPLSラベルヘッダー構造（32 bits / 4 Bytes）

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                Label (20 bits)                | TC (3b)|S| TTL|
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

* **Label Value (20 bits):** パケットの転送先を示すラベル値（0〜15は特殊予約ラベル。16以上が動的割り当て）。
* **TC / Exp (Traffic Class / Experimental - 3 bits):** QoS優先度（CoS / IP Precedence / DSCPからのマッピング）。
* **S (Bottom of Stack - 1 bit):** ラベルスタックの底を示すフラグ（`1` = 最後のラベル、`0` = 下位にさらにラベルが存在）。
* **TTL (Time to Live - 8 bits):** ルーティングループ防止用の生起値（デフォルトでIP TTLからコピー）。

---

## ⚙ 動作シーケンス

MPLS L3VPN におけるパケット処理手順（End-to-End 通信シーケンス）：

```
[CE-1]                [PE-1]                  [P-1]                  [P-2]                [PE-2]                [CE-2]
  │                      │                      │                      │                    │                      │
  │── IP Packet ────────►│                      │                      │                    │                      │
  │   (Dst: 10.2.2.2)    │                      │                      │                    │                      │
  │                      │ 1. VRF AでRIB受入    │                      │                    │                      │
  │                      │ 2. MP-BGP VPNv4検索 │                      │                    │                      │
  │                      │    -> Service Label  │                      │                    │                      │
  │                      │    -> BGP Next-Hop   │                      │                    │                      │
  │                      │ 3. LDP LFIB検索      │                      │                    │                      │
  │                      │    -> Transport Label│                      │                    │                      │
  │                      │                      │                      │                    │                      │
  │                      │── Push Outer(1002) ─►│                      │                    │                      │
  │                      │   Push Inner(2008)  │                      │                    │                      │
  │                      │   IP Packet         │                      │                    │                      │
  │                      │                      │ 4. Swap Outer Label  │                    │                      │
  │                      │                      │── Swap Outer(1002->3)─►                   │                      │
  │                      │                      │   Inner(2008)        │                    │                      │
  │                      │                      │   IP Packet          │                    │                      │
  │                      │                      │                      │ 5. PHP (Pop Outer) │                      │
  │                      │                      │                      │── Inner(2008) ────►│                      │
  │                      │                      │                      │   IP Packet        │                      │
  │                      │                      │                      │                    │ 6. Pop Inner Label   │
  │                      │                      │                      │                    │ 7. VRF A RIB 検索    │
  │                      │                      │                      │                    │                      │
  │                      │                      │                      │                    │── IP Packet ────────►│
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprintで重要なポイント
* **LDP (Label Distribution Protocol):** LDP Session確立要件（`mpls ip`、Transport Addressの到達性、LDP Router ID）、LDP-IGP Synchronization。
* **MPLS L3VPN (BGP/MPLS IP VPN):** 
  * VRF (Virtual Routing and Forwarding) 設定と Address-Family (IPv4 / IPv6)。
  * RD (Route Distinguisher: `8 Bytes`) による IPv4 プレフィックスの VPNv4 化 (`64-bit RD + 32-bit IPv4 = 96-bit VPNv4 Prefix`)。
  * RT (Route Target: `Extended Community`) による VPN 経路のインポート/エクスポート制御（Hub-and-Spoke, Shared Services 等）。
* **PE-CE ルーティングプロトコル:**
  * **BGP:** `as-override`, `allowas-in`, BGP Extended Community (`soo` - Site-of-Origin) によるループ防止。
  * **OSPF:** OSPF Domain-ID, OSPF Super-Backbone (Area 0としてのMP-BGP), Sham-Link (Backdoor リンク対策), OSPF Down-Bit / DN-Bit および Route-Tag (1152) によるルーティングループ防止。
  * **EIGRP:** EIGRP MPLS VPN 統合, BGP 経由での EIGRP メトリック（Vector Metrics）維持 (`bgp redistribute-internal` / Extended Community)。

### 2. よくある設定ミス・落とし穴
* **`mpls ip` の設定忘れ:** PE-P 間、P-P 間の物理インターフェイスおよび Port-Channel で `mpls ip` を有効化し忘れると、LDP ネイバーが形成されずラベルスイッチングが失敗する。
* **LDP Router-ID / Transport Address 疎通不可:** LDP はデフォルトで Loopback0 の IP を Transport Address として使用する。IGP で Loopback アドレスが広告されていない場合、TCP 646 セッションが確立しない。
* **PE-CE BGP での AS-Override / Allowas-in 未設定:** CE-1 と CE-2 が同一の Private AS（例: AS 65001）を使用している場合、PE から受け取った BGP 経路の AS_PATH に自 AS が含まれるため CE がデフォルトで経路をドロップする。
* **OSPF Sham-Link での `/32` アドレス指定ミス:** Sham-Link の送信元/宛先アドレスは VRF 内の `/32` Loopback インターフェイスでなければならず、かつ MP-BGP 経由で相手 PE に伝搬されていてはならない（Sham-Link アドレス自体は PE-CE 間または IGP で直接知られている必要がある）。

### 3. show コマンドから状態を判断するポイント
* <code>show mpls ldp neighbor</code>: LDP セッションが `Operational` であるか確認。
* <code>show mpls forwarding-table</code>: LFIB テーブルで Outgoing Label や Prefix に対する Next Hop パスを確認。
* <code>show bgp vpnv4 unicast all</code>: MP-BGP で交換された VPNv4 経路、RD、RT、および割り当てられた Route Label (Service Label) を確認。
* <code>show ip route vrf <VRF_NAME></code>: 各 VRF ルーティングテーブルに PE-CE および MP-BGP 由来の経路が正しい AD で注入されているか確認。

---

## 🛠 設定方法

### MPLS L3VPN (PE ルータ) の標準設定構成例

```text
! 1. VRF の定義 (Address-Family モード)
vrf definition CORP_A
 rd 65000:100
 address-family ipv4
  route-target export 65000:100
  route-target import 65000:100
 exit-address-family
!
! 2. アンダーレイ & サービスインターフェイスの設定
interface Loopback0
 ip address 1.1.1.1 255.255.255.255
 ip ospf 1 area 0
!
interface GigabitEthernet0/0/0
 description To P-Router
 ip address 10.1.12.1 255.255.255.252
 ip ospf 1 area 0
 mpls ip
!
interface GigabitEthernet0/0/1
 description To CE-Router
 vrf forwarding CORP_A
 ip address 192.168.12.1 255.255.255.252
!
! 3. LDP の設定
mpls ldp router-id Loopback0 force
!
! 4. MP-BGP (iBGP VPNv4 / PE-CE BGP) の設定
router bgp 65000
 bgp log-neighbor-changes
 neighbor 2.2.2.2 remote-as 65000
 neighbor 2.2.2.2 update-source Loopback0
 !
 address-family vpnv4
  neighbor 2.2.2.2 activate
  neighbor 2.2.2.2 send-community extended
 exit-address-family
 !
 address-family ipv4 vrf CORP_A
  neighbor 192.168.12.2 remote-as 65100
  neighbor 192.168.12.2 as-override
  redistribute connected
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| LDP ネイバー確認 | <code>show mpls ldp neighbor</code> |
| LDP バインディング確認 | <code>show mpls ldp bindings</code> |
| LFIB (ラベル転送表) 確認 | <code>show mpls forwarding-table</code> |
| MP-BGP VPNv4 経路確認 | <code>show bgp vpnv4 unicast all</code> |
| 特定 VRF の MP-BGP 経路確認 | <code>show bgp vpnv4 unicast vrf <VRF_NAME></code> |
| VRF ルーティングテーブル確認 | <code>show ip route vrf <VRF_NAME></code> |
| VRF 詳細定義確認 | <code>show vrf detail <VRF_NAME></code> |
| MPLS トレーサーテス | <code>traceroute vrf <VRF_NAME> <IP></code> |
| LDP トラブルシューティング Debug | <code>debug mpls ldp transport events</code> / <code>debug mpls ldp messages</code> |
| MP-BGP VPNv4 Debug | <code>debug bgp vpnv4 unicast updates</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| LDP ネイバーが確立しない (`NON-EXISTENT`) | インターフェイスで `mpls ip` 未設定、または Transport Address への L3 到達性がない | <code>show mpls ldp discovery</code><br><code>show ip route <LDP-ID></code> | インターフェイスに `mpls ip` を追加。IGP で LDP Router-ID (Loopback0) を広告 |
| PE 間で VPNv4 経路が届かない | MP-BGP ピアリング未確立、または `address-family vpnv4` で `activate` 未設定 | <code>show bgp vpnv4 unicast all summary</code> | MP-BGP ピア設定を確認し、`neighbor <IP> activate` および `send-community extended` を投入 |
| 相手 PE に届いた VPNv4 経路が VRF に入らない | RT (Route Target) の不一致、または VRF に `route-target import` が設定されていない | <code>show vrf detail <VRF></code><br><code>show bgp vpnv4 unicast rd <RD></code> | PE 間で Import / Export RT が合致しているか確認 |
| CE 間通信でパケットが落とされる | LDP ラベルがエンドツーエンドで確立しておらず P ルーティングで破棄される | <code>traceroute vrf <VRF> <CE-IP></code><br><code>show mpls forwarding-table</code> | 全 P ルータでの LDP 接続性と LFIB エントリ（Label Switch Path）を確認 |
| CE-2 で PE 経由の BGP 経路が受容されない | CE-1 と CE-2 が同一 AS を使用しており、AS-Path ループ防止機能によりドロップされた | <code>show bgp ipv4 unicast</code> (CEルータ上) | PE の VRF BGP ネイバーに <code>neighbor <CE-IP> as-override</code> を設定 |
| OSPF バックドアリンクが優先され MPLS 網を通らない | OSPF 経路の Metric や Area タイプにより、MP-BGP 経由（Inter-Area扱い）より L2/L3 バックドア（Intra-Area）が優先される | <code>show ip route vrf <VRF> <Prefix></code> | PE 間で **OSPF Sham-Link** を構成し、MPLS 網経由を Intra-Area パスとして評価させる |

---

## ⚠ 制限事項

* **MPLS MTU の制限:** MPLS ラベル（1つにつき 4 バイト）が付加されるため、アンダーレイ物理インターフェイスの MTU は最低 1508 バイト以上（推奨 1544 / 9000 バイト）に設定する必要がある。
* **PHP (Penultimate Hop Popping) 動作:** デフォルトで最終ルータの1つ手前の P ルータで Transport Label が剥がされる（Implicit NULL: Label 3）。QoS Exp ビットを保持したい場合は `mpls ldp explicit-null` の設定が必要。
* **VRF 制限:** 同一ルータ上での VRF 数や BGP プレフィックス数にはプラットフォームごとの TCAM 制限が存在する。

---

## 🔄 他技術との関連

* **BGP (1.5 / MP-BGP):** MPLS L3VPN のコントロールプレーンとして不可欠。`address-family vpnv4` / `vpnv6` を用いて Route Target 拡張コミュニティとともに VPN 経路をカプセル化伝搬する。
* **OSPF (1.4) / EIGRP (1.3):** PE-CE 間動的ルーティングプロトコルとして使用。OSPF の場合、MP-BGP 網は Super-Backbone として動作し、DN-Bit や Domain-ID、Sham-Link によるループ防止・最適パス制御が必要。
* **VRF-Lite (1.2.d):** MPLS を伴わない L3 仮想化。PE-CE 間や Fusion Router で活用され、MPLS L3VPN と組み合わされる。
* **Segment Routing (SR-MPLS):** LDP に代わる次世代 MPLS シグナリング。IGP（OSPF/ISIS）の Prefix-SID 拡張を用いてラベルを動的割り当て。

---

## 🧩 比較表

### LDP vs Segment Routing (SR-MPLS) vs RSVP-TE

| 比較項目 | LDP (Label Distribution Protocol) | Segment Routing (SR-MPLS) | RSVP-TE (Traffic Engineering) |
| --- | --- | --- | --- |
| **シグナリング** | 独立プロトコル (TCP/UDP 646) | IGP 拡張 (OSPF/ISIS 拡張 LSA/TLV) | 独立プロトコル (RSVP Signaling) |
| **パス計算** | IGPの最短パス (SPF) に完全依存 | IGP SPF + 任意ラベルスタック指定 | CSPF (Constrained SPF) |
| **ステート管理** | 全ルータで Hop-by-Hop LDP ステート保持 | ステートレス（送信元ラベルスタックのみ） | 全 Core ルータで RSVP ステート保持 |
| **FRR (Fast Reroute)** | LDP LFA / Remote LFA | TI-LFA (Topology-Independent LFA: 100%保護) | RSVP-TE FRR |
| **複雑性** | 中 | 低（シンプル） | 非常に高 |

---

## 💡 ベストプラクティス

1. **LDP Router-ID の固定化:** `mpls ldp router-id Loopback0 force` を明示的に設定し、意図しない IP アドレス変更による LDP セッション切断を防ぐ。
2. **LDP-IGP Synchronization の有効化:** IGP (OSPF/ISIS) プロセス下で `mpls ldp sync` を有効化し、LDP セッションが未確立の状態で IGP 経路がフォワードされてパケットがブラックホール化するのを防止する。
3. **Explicit-Null の検討:** コア網での QoS 保証（Exp ビットの保持）が必要な場合は、PE ルータで `mpls ldp explicit-null` を設定する。
4. **PE-CE BGP ループ対策:** CE 側で Private AS を共用する場合は、PE 側で `as-override` を設定し、同時に SOO (Site-of-Origin) 拡張コミュニティを適用してマルチホーム拠点間でのルート再流入を防止する。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: LDP アンダーレイと MP-BGP VPNv4 基本構成

* **問題:** PE-1 と PE-2 間で MPLS L3VPN を構築し、CE-1 (VRF CORP) と CE-2 (VRF CORP) 間で L3 到達性を確保しなさい。
* **要件:**
  1. PE-1 - P-1 - PE-2 間のアンダーレイに OSPF Area 0 と LDP を設定すること。
  2. PE-1 と PE-2 間で iBGP VPNv4 ピアリングを確立すること。
  3. VRF `CORP` を作成し、RD `65000:1`、RT `65000:1` を設定すること。
* **設定例:**

```text
! --- PE-1 ---
vrf definition CORP
 rd 65000:1
 address-family ipv4
  route-target export 65000:1
  route-target import 65000:1
 exit-address-family
!
interface Loopback0
 ip address 1.1.1.1 255.255.255.255
 ip ospf 1 area 0
!
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.252
 ip ospf 1 area 0
 mpls ip
!
interface GigabitEthernet0/2
 vrf forwarding CORP
 ip address 192.168.1.1 255.255.255.0
!
router ospf 1
 mpls ldp sync
!
mpls ldp router-id Loopback0 force
!
router bgp 65000
 neighbor 2.2.2.2 remote-as 65000
 neighbor 2.2.2.2 update-source Loopback0
 address-family vpnv4
  neighbor 2.2.2.2 activate
  neighbor 2.2.2.2 send-community extended
 exit-address-family
 address-family ipv4 vrf CORP
  redistribute connected
 exit-address-family
```

* **検証方法:**
  * <code>show mpls ldp neighbor</code> で LDP セッション確認。
  * <code>show bgp vpnv4 unicast all</code> で VPNv4 経路受領確認。
  * <code>ping vrf CORP 192.168.2.1</code> で導通確認。

---

### ラボ 2: PE-CE BGP (AS-Override 構成)

* **問題:** CE-1 と CE-2 が同一の Private AS 65100 を使用している。PE-1 と PE-2 で AS-Override を設定し、CE 間で BGP 経路を交換させなさい。
* **要件:**
  1. PE-CE 間で BGP AS 65000 と AS 65100 の eBGP ピアリングを構成すること。
  2. CE 側で自 AS 番号によるルートドロップが発生しないよう PE 上で適切なコマンドを設定すること。
* **設定例:**

```text
! --- PE-1 ---
router bgp 65000
 address-family ipv4 vrf CORP
  neighbor 192.168.12.2 remote-as 65100
  neighbor 192.168.12.2 as-override
  neighbor 192.168.12.2 activate
 exit-address-family
```

* **検証方法:**
  * CE-2 上で <code>show ip bgp</code> を実行し、CE-1 のプレフィックスの AS_PATH が `65000 65000`（自 AS 65100 が 65000 に置換されている）となっていることを確認。

---

### ラボ 3: PE-CE OSPF (Super-Backbone & Down-Bit 動作検証)

* **問題:** PE-1 と CE-1 間で OSPF Area 1 を構成し、MP-BGP 経由で対向拠点の OSPF 経路を伝搬させなさい。
* **要件:**
  1. PE-1 の VRF `CORP` 配下に OSPF プロセス 100 を設定し、CE-1 と Area 1 ネイバーを形成すること。
  2. MP-BGP と OSPF 100 の間で相互再配送を設定すること。
* **設定例:**

```text
! --- PE-1 ---
router ospf 100 vrf CORP
 domain-id 0.0.0.1
 redistribute bgp 65000 subnets
 network 192.168.12.0 0.0.0.3 area 1
!
router bgp 65000
 address-family ipv4 vrf CORP
  redistribute ospf 100 match internal external 1 external 2
 exit-address-family
```

* **検証方法:**
  * CE-2 上で <code>show ip route ospf</code> を実行し、対向 CE-1 の LSA が Inter-Area 経路 (`O IA`) として学習されていることを確認。

---

### ラボ 4: OSPF Sham-Link によるバックドアリンク回避

* **問題:** CE-1 と CE-2 間に直結の L3 バックドアリンク（OSPF Area 1）が存在する。通常時は MPLS 網経由を優先させるため、PE-1 と PE-2 間に OSPF Sham-Link を構成しなさい。
* **要件:**
  1. PE-1 および PE-2 の VRF `CORP` 内に `/32` の Dedicated Loopback1 を作成すること。
  2. Loopback1 を MP-BGP 経由で対向 PE に広告すること（OSPF 配下には含めない）。
  3. PE1-PE2 間で OSPF Sham-Link を確立し、Cost 1 を設定すること。
* **設定例:**

```text
! --- PE-1 ---
interface Loopback1
 vrf forwarding CORP
 ip address 11.11.11.11 255.255.255.255
!
router bgp 65000
 address-family ipv4 vrf CORP
  network 11.11.11.11 mask 255.255.255.255
 exit-address-family
!
router ospf 100 vrf CORP
 area 1 sham-link 11.11.11.11 22.22.22.22 cost 1
```

* **検証方法:**
  * CE-1 上で <code>show ip route <CE-2_Prefix></code> を実行し、バックドアリンクではなく PE-1 向きのインターフェイスがネクストホップ（`O` Intra-Area パス）となっていることを確認。

---

### ラボ 5: PE-CE EIGRP (Vector Metrics 保持)

* **問題:** PE-CE 間で EIGRP を使用し、MPLS 網を通過後も EIGRP の元のメトリック（Composite Metric）を維持させなさい。
* **要件:**
  1. PE-1 の VRF `CORP` で EIGRP Named Mode (または Classic Mode) プロセスを構成すること。
  2. MP-BGP と EIGRP 間で相互再配送を行い、`bgp redistribute-internal` を設定すること。
* **設定例:**

```text
! --- PE-1 ---
router eigrp CORP_EIGRP
 !
 address-family ipv4 vrf CORP autonomous-system 100
  topology base
   redistribute bgp 65000 metric 10000 100 255 1 1500
  exit-af-topology
  network 192.168.12.0 0.0.0.3
 exit-address-family
!
router bgp 65000
 address-family ipv4 vrf CORP
  redistribute eigrp 100
 exit-address-family
```

* **検証方法:**
  * CE-2 上で <code>show ip eigrp topology <Prefix></code> を確認し、Extended Community 経由で EIGRP メトリック属性（AS, Delay, Bandwidth）が透過伝搬されていることを確認。

---

### ラボ 6: BGP SOO (Site-of-Origin) によるマルチホームループ防止

* **問題:** CE-1 が PE-1 および PE-2 の両方にデュアルホーム接続されている。PE-1 から再配送された経路が PE-2 経由で CE-1 へ再流入するループを SOO を用いて防止しなさい。
* **要件:**
  1. PE-1 および PE-2 の CE-1 向きインターフェイスに BGP SOO `65000:11` を適用すること。
* **設定例:**

```text
! --- PE-1 & PE-2 ---
route-map SET_SOO permit 10
 set extcommunity soo 65000:11
!
router bgp 65000
 address-family ipv4 vrf CORP
  neighbor 192.168.12.2 route-map SET_SOO in
```

* **検証方法:**
  * PE-2 上で <code>show bgp vpnv4 unicast vrf CORP</code> を実行し、SOO `65000:11` が付与された経路が CE-1 へ逆広告されないことを確認。

---

### ラボ 7: LDP-IGP Synchronization の設定と動作検証

* **問題:** P ルータ間のリンク切断・復旧時に、LDP 接続が確立する前に IGP 経路が有効化されてパケットドロップが発生するのを防止しなさい。
* **要件:**
  1. 全 PE / P ルータの OSPF プロセス下で LDP-IGP Sync をグローバル有効化すること。
  2. LDP セッション未確立時の OSPF Metric を Max-Metric (65535) に設定すること。
* **設定例:**

```text
! --- All PE & P Routers ---
router ospf 1
 mpls ldp sync
 mpls ldp igp sync delay 30
```

* **検証方法:**
  * インターフェイスの `mpls ip` を一時的に外し、<code>show ip ospf interface</code> で OSPF Metric が `65535` に上昇してトラフィックが迂回されることを確認。

---

### ラボ 8: LDP Explicit-Null 設定 (QoS Exp 保持)

* **問題:** 最終 Hop の P ルータで PHP（Penultimate Hop Popping）が動作すると、MPLS QoS Exp ビットが失われる。Explicit-Null を設定して PE ルータまでラベルを保持させなさい。
* **要件:**
  1. PE ルータ上で LDP に対して Explicit-Null (Label 0) アドバタイズを設定すること。
* **設定例:**

```text
! --- PE-1 & PE-2 ---
mpls ldp explicit-null
```

* **検証方法:**
  * <code>show mpls ldp bindings</code> で、ローカルアドレスに対して `Explicit-Null (0)` ラベルが割り当てられていることを確認。

---

### ラボ 9: VRF-Lite ＆ MPLS L3VPN インターワーク (Hub-and-Spoke 構成)

* **問題:** Spoke-1 (VRF_S1) と Spoke-2 (VRF_S2) 間のすべての通信が、HQ の Hub ルータ (VRF_HUB) を必ず経由するように RT インポート/エクスポートを設計しなさい。
* **要件:**
  1. Spoke-1 は RT `65000:1` を Export し、RT `65000:100` を Import すること。
  2. Spoke-2 は RT `65000:2` を Export し、RT `65000:100` を Import すること。
  3. HQ Hub ルータは RT `65000:1` および `65000:2` を Import し、RT `65000:100` を Export すること。
* **設定例:**

```text
! --- PE-Spoke-1 ---
vrf definition VRF_S1
 rd 65000:1
 address-family ipv4
  route-target export 65000:1
  route-target import 65000:100
 exit-address-family

! --- PE-Hub ---
vrf definition VRF_HUB_IN
 rd 65000:1001
 address-family ipv4
  route-target import 65000:1
  route-target import 65000:2
 exit-address-family

vrf definition VRF_HUB_OUT
 rd 65000:1002
 address-family ipv4
  route-target export 65000:100
 exit-address-family
```

* **検証方法:**
  * Spoke-1 から Spoke-2 宛ての Traceroute を実行し、HQ Hub ルータの VRF インターフェイスを通過していることを確認。

---

### ラボ 10: MPLS MTU 最適化 ＋ TCP MSS Adjust 構成

* **問題:** MPLS 網内で 1500 バイトの DF ビット（Don't Fragment）付き IP パケットがドロップされないよう、全 Core インターフェイスの MTU を拡張し、PE-CE ポートで TCP MSS を調整しなさい。
* **要件:**
  1. PE-P 間物理ポートの MTU を 9000 バイト、MPLS MTU を 8900 バイトに構成すること。
  2. PE-CE インターフェイスで `ip tcp adjust-mss 1360` を適用すること。
* **設定例:**

```text
! --- PE-1 Core Port ---
interface GigabitEthernet0/1
 mtu 9000
 mpls mtu 8900
 mpls ip
!
! --- PE-1 CE Port ---
interface GigabitEthernet0/2
 vrf forwarding CORP
 ip address 192.168.12.1 255.255.255.252
 ip tcp adjust-mss 1360
```

* **検証方法:**
  * CE-1 から <code>ping 192.168.2.1 size 1500 df-bit vrf CORP</code> を実行し、フラグメンテーションなしで成功することを確認。

---

## ❓ 想定試験問題

### 問 1 (トラブルシューティング)
**問題:** PE-1 ルータで `show mpls ldp neighbor` を実行したところ、対向 P-1 ルータとのセッション状態が `NON-EXISTENT` のまま確立しない。`show ip route 10.0.0.2`（P-1 の LDP Router-ID）は OSPF 経由で正常に到達可能であり、物理ポートの Ping も疎通する。どのような原因が考えられるか？対処コマンドとともに答えよ。

* **解答:** 
  * **原因:** 対向 P-1 ルータの接続インターフェイスで `mpls ip` コマンドが設定されていない、または ACL / Firewall 等により LDP の TCP/UDP ポート 646 が遮断されている。
  * **確認・対処:**
    1. PE-1 で <code>show mpls ldp discovery</code> を実行し、LDP Hello パケットが受信できているか確認する。
    2. P-1 ルータの該当インターフェイスで <code>interface GigabitEthernet0/1</code> ➔ <code>mpls ip</code> を設定する。

---

### 問 2 (コンフィグ読解・設計)
**問題:** 以下の PE ルータの VRF 設定を読み取り、拠点 A（VRF_A）および拠点 B（VRF_B）間でどのような通信制御（トポロジー）が実現されるか説明せよ。

```text
vrf definition VRF_A
 rd 65000:10
 address-family ipv4
  route-target export 65000:10
  route-target import 65000:99
 exit-address-family

vrf definition VRF_B
 rd 65000:20
 address-family ipv4
  route-target export 65000:20
  route-target import 65000:99
 exit-address-family

vrf definition VRF_SHARED
 rd 65000:99
 address-family ipv4
  route-target export 65000:99
  route-target import 65000:10
  route-target import 65000:20
 exit-address-family
```

* **解答:**
  * **トポロジー制御:** **Shared Services (共有サービス) 構成**。
  * **説明:** VRF_A と VRF_B は互いの Route Target（`65000:10`, `65000:20`）を Import していないため、拠点 A と 拠点 B 間は直接通信できない（完全隔離）。一方、VRF_SHARED は両方の RT を Import し、自身の RT `65000:99` を Export しているため、VRF_A および VRF_B は共に VRF_SHARED（共通サーバ網等）とだけ双方向通信が可能である。

---

### 問 3 (OSPF over MPLS / Sham-Link)
**問題:** CE-1 と CE-2 間に MPLS L3VPN 網に加えて 1Gbps の L3 バックドアリンク（OSPF Area 0）が接続されている。MPLS 網（MP-BGP）経由でルートを交換したところ、CE ルータは MPLS 網ではなくバックドアリンクを優先して選定してしまった。なぜこの現象が発生するのか？また、MPLS 網を優先させるための技術とその設定要件を述べよ。

* **解答:**
  * **発生原因:** OSPF over MPLS L3VPN では、MP-BGP 経由で伝搬された OSPF 経路は PE 上で Inter-Area 経路 (`O IA`) として扱われる。一方、直結のバックドアリンク経由の経路は Intra-Area 経路 (`O`) となる。OSPF パス選定アルゴリズムでは、メトリック値に関わらず Intra-Area パスが Inter-Area パスより優先されるため。
  * **解決技術:** **OSPF Sham-Link**。
  * **設定要件:**
    1. 両 PE の VRF 内に `/32` アドレスを持つ Loopback インターフェイスを作成し、MP-BGP で相互広告する（OSPF プロセスには含めない）。
    2. 両 PE の OSPF VRF プロセス下で `area <area-id> sham-link <local-ip> <remote-ip> cost <cost>` を設定し、MPLS 網経由を OSPF Intra-Area パスとして偽装・評価させる。

---

### 問 4 (PE-CE BGP AS-Override / Allowas-in)
**問題:** 企業 X はすべての拠点で BGP AS 65500 を使用してプロバイダ（AS 65000）の MPLS L3VPN サービスに接続している。PE ルータで何も特殊な設定を行わない場合、CE-1 から広告された経路が CE-2 で受容されない。その理由と、PE 側および CE 側でそれぞれ適用可能な解決策を述べよ。

* **解答:**
  * **理由:** PE-1 は CE-1 から受信した経路を MP-BGP 経由で PE-2 へ送り、PE-2 は CE-2 へ BGP 広告する。この際、AS_PATH に `65000 65500` が付与される。CE-2 は自 AS 番号 `65500` が AS_PATH に含まれているため、BGP のルーティングループ防止メカニズム（AS_PATH Loop Detection）により経路を自動ドロップする。
  * **解決策 (PE 側):** PE ルータの VRF BGP ネイバー設定で <code>neighbor <CE-IP> as-override</code> を設定する（PE が AS_PATH 内の `65500` を自 AS `65000` に書き換えて送信する）。
  * **解決策 (CE 側):** CE-2 ルータの BGP 設定で <code>neighbor <PE-IP> allowas-in <number></code> を設定し、自 AS 番号の出現を規定回数まで受容許可する。

---

### 問 5 (トラブルシューティング / LFIB)
**問題:** PE-1 から対向 PE-2 の VRF 宛てに Ping を送信したところ応答がない。PE-1 で <code>show bgp vpnv4 unicast all</code> を実行すると VPNv4 経路は正しく受容されており、VPNv4 Label も割り当てられている。次にどこを確認すべきか？トラブルシューティングの手順を 3 ステップで示せ。

* **解答:**
  1. **MP-BGP Next-Hop への LDP 到達性確認:** <code>show mpls forwarding-table</code> を実行し、PE-2 の Loopback0 (BGP Next-Hop) に対する Transport Label (Outer Label) が正しく LFIB テーブルにバインドされ、Outgoing Interface が表示されているか確認する。
  2. **アンダーレイ LDP ネイバー状態の確認:** `show mpls ldp neighbor` で PE-1 ➔ P-1 ➔ PE-2 間のすべての Hop で LDP セッションが `Operational` か確認する。
  3. **VRF IP 到達性と Traceroute 検証:** <code>traceroute vrf <VRF> <IP></code> を実行し、パケットがどの Hop（Pルータ等）でドロップされているか特定し、該当 P ルータでの `mpls ip` または LFIB ドロップを確認する。

---

## 🔗 参考リソース

* [Cisco IOS-XE 17.x Multiprotocol Label Switching Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_ldp/configuration/xe-16/mp-ldp-xe-16-book.html)
* [Cisco Layer 3 MPLS VPN Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-16/mp-l3-vpns-xe-16-book.html)
* [Cisco Live: BRKMPL-2102 - Design and Architecture of MPLS L3VPNs](https://www.ciscolive.com/)
* [Cisco Live: BRKROU-3333 - Advanced MPLS Architecture and Troubleshooting](https://www.ciscolive.com/)
* [Cisco Command Reference: mpls ip / mpls ldp commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mpls/command/mp-cr-book.html)
* [Cisco Technical Notes: Troubleshooting MPLS L3VPN Architecture and Forwarding](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/13738-mpls-faq-13738.html)

---

## 📝 **補足（Notes）**

* **ラベル空間の概念:**
  * **Per-Interface Label Space:** インターフェイスごとに個別のラベル空間（Frame Relay等で使用、現在はほぼ非推奨）。
  * **Per-Platform Label Space:** ルータ（プラットフォーム）全体で単一のラベル空間（イーサネット網で標準使用）。
* **MPLS QoS マッピング:**
  * **Uniform Mode:** IP DSCP/Precedence ↔ MPLS Exp ↔ IP DSCP/Precedence（双方で透過・更新）。
  * **Pipe Mode:** MPLS 網内のみ独自 Exp を適用し、出側で元の IP DSCP を維持。
  * **Short-Pipe Mode:** 出側 PE の Egress キューイングまで MPLS Exp を使用し、CE 宛て送信時は元の IP DSCP に戻す。
