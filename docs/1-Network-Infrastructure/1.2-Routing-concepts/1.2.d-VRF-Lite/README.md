---
layout: default
title: 1.2.d-VRF-Lite
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.2.d VRF-Lite

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるネットワーク仮想化・セグメンテーション（マルチテナント分離）の基礎かつコア技術である **VRF-Lite (Virtual Routing and Forwarding Lite)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**VRF-Lite (Virtual Routing and Forwarding Lite)** とは、単一の物理ルータまたはレイヤ3スイッチ内部において、複数の独立した**ルーティングテーブル（RIB: Routing Information Base）**および**転送テーブル（FIB: Forwarding Information Base）**を論理的に分割・保持するネットワーク仮想化技術です。

通常、MPLS (Multiprotocol Label Switching) インフラを伴うL3VPN（MPLS L3VPN）においてPE (Provider Edge) ルータ上で動作するVRF機能を、**「MPLSラベル交換プロトコル（LDP等）やMP-BGPを使用せず、ローカル機器内および対向機器との間（SubinterfaceやSVIなど）で完結させる形態」**を指して **VRF-Lite**（または Multi-VRF CE）と呼びます。

### 主な利用目的と適用シーン
1. **エンタープライズ内の部門・テナント隔離:** 企業ネットワークにおいて、営業部、開発部、ゲストWi-Fi、防犯カメラ（IoT）、パートナー企業用ネットワークなどを物理機器を追加することなくL3レベルで完全に遮断・隔離する。
2. **重複IPアドレス空間の収容:** M&A（企業買収）やグループ会社統合時に、お互いに `10.0.0.0/8` や `192.168.1.0/24` などの重複したプライベートIPアドレス範囲を使用している環境を、同一の物理ルータで競合させることなく収容する。
3. **SD-Access / SD-WAN におけるアンダーレイ・オーバーレイ仮想化の橋渡し:** 融合ルータ（Fusion Router）やデータセンター接続ポイントにおいて、SD-AccessのVN（Virtual Network）やSD-WANのVPNを外部ネットワーク（共有サービス、インターネット、レガシー網）へ安全に接続するためのハンドオフポイントとして利用する。
4. **マネジメント網（Management VRF）の完全隔離:** 制御・管理用プレトラフィック（SSH, SNMP, NTP, Syslogなど）を業務データプレーンから完全に隔離し、セキュリティを高める。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 単一機器内でルーティングテーブル（RIB/FIB）、インターフェイス、ルーティングプロセス（OSPF, EIGRP, BGP, Static）を完全に論理分割。MPLSヘッダー（LDPラベル）は使用しない。 |
| **用途** | キャンパスLANでのテナント分離、Fusion RouterでのSD-Access/SD-WAN handoff、セキュリティゾーン隔離、重複IPアドレス空間の個別ルーティング。 |
| **メリット** | 物理機器の追加コストをかけずにL3レベルの高度なセグメンテーションを実現。IPアドレスの重複使用が可能。MPLSの複雑なコントロールプレーン（LDP, MP-BGP）を構築する必要がない。 |
| **デメリット** | スイッチ/ルータ間を結ぶリンクごとに、VLAN（802.1Q サブインターフェイスやSVI）やGREトンネルを個別に定義してVRFをバインドする必要があり、ホップ数が増えると設定・管理オーバーヘッドがスケールしにくい。 |
| **対応機種** | Catalyst 9200 / 9300 / 9400 / 9500 / 9600 シリーズ、Catalyst 8000v、ISR 4000 シリーズなど、Cisco IOS-XEを稼働するほぼすべてのL3スイッチおよびルータ。 |
| **制限事項** | 機器のハードウェア（TCAM / Memory）スペックにより作成可能な最大VRF数が制限される。VRF間で通信を行わせるには、explicitなRoute Leaking（VRF間リーク：VASI, Route-map, Static leak等）の設定が必要。 |
| **設計上の注意点** | インターフェイスに `vrf forwarding <NAME>` を適用すると、**そのポートに設定されていたIPアドレス（IPv4/IPv6）が自動的に全消去される**。設定順序に厳重な注意が必要。 |

---

## 🏗 動作原理

VRF-Liteの動作原理は、**コントロールプレーン（制御面）の独立** と **データプレーン（転送面）のタグ/ポートベース識別** の2つに大別されます。

```text
  [ VRF: RED ] (RIB/FIB: RED)     ──► OSPF Process 10 (VRF RED)
        ▲
        │ (L3 Isolation)
        ▼
  [ VRF: BLUE ] (RIB/FIB: BLUE)   ──► EIGRP Process 100 (VRF BLUE)
        ▲
        │ (L3 Isolation)
        ▼
  [ Global VRF ] (Default RIB)    ──► BGP AS 65000 (Global)
```

### コントロールプレーンの分離
* 各VRFは専用の**ルーティングテーブル（RIB）**を保持します。例えば、VRF `RED` で学習したルーティング情報は VRF `BLUE` や Global ルーティングテーブルには一切混入しません。
* Dynamic Routing Protocol（OSPF, EIGRP, BGPなど）もVRFごとに個別のプロセスまたはマルチインスタンス/Address-familyとして完全に独立して動作します。

### データプレーンの分離
* パケットがスイッチ/ルータの物理ポート（または802.1Qサブインターフェイス、SVI）に入力されると、そのインターフェイスがバインドされているVRFインスタンスが確定します。
* ルックアップは、パケットが入ってきたインターフェイスのVRF専用FIB（Forwarding Information Base）テーブルに対してのみ行われます。そのため、宛先IPアドレスが全く同じ `10.1.1.1` であっても、入ってきたポートのVRFによって異なるネクストホップへ転送されます。

```text
[ Client (VRF RED) ] ➔ [ Gi0/0/1.10 (VRF RED) ] ➔ [ RIB/FIB RED ルックアップ ] ➔ [ Gi0/0/2.10 (VRF RED) ]
                                                                                   
[ Client (VRF BLUE) ] ➔ [ Gi0/0/1.20 (VRF BLUE) ] ➔ [ RIB/FIB BLUE ルックアップ ] ➔ [ Gi0/0/2.20 (VRF BLUE) ]
```

---

## ⚙ 動作シーケンス

スイッチ/ルータにおけるインプレス（パケット受信）からエグレス（パケット送信）までのパケット処理プロセスです。

```text
( パケット受信: Ingress Physical Interface )
       │
       ▼
[ インターフェイスの L2/L3 属性および VRF バインドの判別 ]
       │
       ├─► 802.1Q タグ（VLAN 10）または 物理ポートにアサインされた VRF を特定 (例: VRF RED)
       │
       ▼
[ 該当 VRF (RED) 専用の FIB (CEF) テーブルのルックアップ ]
       │
       ├─► 宛先 IP アドレスを VRF RED の FIB 内で検索 (Global や他 VRF は検索しない)
       │    ├─► ヒットなし ➔ 【パケット破棄 (Drop / ICMP Unreachable)】
       │    └─► ヒットあり ➔ ネクストホップ IP および送出インターフェイスを決定
       │
       ▼
[ エグレスインターフェイスの処理 ]
       │
       ├─► 送出インターフェイス (例: Gi0/0/2.10) の VRF (RED) と整合性を確認
       ├─► L2 ヘッダーの書き換え (MAC アドレス、802.1Q VLAN タグ等)
       │
       ▼
( パケット送出: Egress Interface )
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、VRF-Liteは単体での構成だけでなく、ルーティングプロトコル（EIGRP Named Mode, OSPFv2/v3, BGP）、DMVPN, GRE, IPsec, NAT, そして VRF Route Leaking（VASI等）と組み合わせて非常によく出題されます。

### 1. `ip vrf` (Legacy) vs `vrf definition` (Modern) の厳格な使い分け
Cisco IOS/IOS-XEには2種類のVRF定義コマンドが存在します。CCIE試験では **`vrf definition`**（Modernスタイル）の使用が強く推奨され、要件によってはIPv6対応のために必須となります。

* **旧コマンド (`ip vrf <NAME>`):** IPv4専用。IPv6をサポートしない。
* **新コマンド (`vrf definition <NAME>`):** IPv4およびIPv6（Dual-Stack）を完全サポート。`address-family ipv4` / `address-family ipv6` を明示的に有効化（`exit-address-family`）する必要がある。

```bash
# 【推奨】 modern 形式での VRF 定義
vrf definition RED
 rd 65000:1
 !
 address-family ipv4
 exit-address-family
 !
 address-family ipv6
 exit-address-family
!
```

### 2. インターフェイス割り当て時の IP アドレス消去トラブル（最頻出の落とし穴）
* インターフェイス（物理、サブインターフェイス、SVI）に `vrf forwarding <NAME>`（または `ip vrf forwarding <NAME>`）を適用すると、**それまでにインターフェイスに設定されていた `ip address` および `ipv6 address` が即座に削除されます。**
* **対策・手順:** 
  1. まず最初に `vrf definition` を作成する。
  2. インターフェイスに `vrf forwarding <NAME>` を割り当てる。
  3. **その後に** `ip address <IP> <MASK>` および `ipv6 address ...` を設定する。

### 3. OSPFにおける VRF-Lite 特有の挙動と `capability vrf-lite`
* OSPFプロセスをVRF配下で動作させると、Cisco IOS-XEはデフォルトでそのルータを **「MPLS L3VPNの PE ルータ」** として認識します。
* PEルータとして動作するOSPFは、L3VPNでのループ防止のために **DN Bit (Down Bit)** のセットや **Route Tag (Domain-ID)** のチェックを行います。
* VRF-Lite環境（MPLSが存在しない環境）で、VRFバックボーンを介して別のOSPFルータへLSAを再配布・伝搬させると、対向ルータが「DN Bitがセットされている」としてLSA Type-3/5/7を破棄し、**ルーティングテーブルにルートが注入されない現象**が発生します。
* **解決策:** VRF配下のOSPFプロセスで **`capability vrf-lite`** を設定し、PEルータ用のループ防止チェック（DN Bitチェック等）を無効化します。

```bash
router ospf 10 vrf RED
 capability vrf-lite
 router-id 1.1.1.1
 network 10.1.1.0 0.0.0.255 area 0
```

### 4. EIGRP Named Mode における VRF 構成
EIGRP Named Modeでは、単一のルータプロセス内で複数のVRFを非常にシンプルかつ洗練された形で構成できます。

```bash
router eigrp CCIE
 !
 address-family ipv4 vrf RED autonomous-system 100
  topology base
  exit-topology
  network 10.1.1.0 0.0.0.255
 exit-address-family
```

### 5. BGP における VRF 構成と Route Distinguisher (RD)
* BGPでVRFを扱う場合、`router bgp <AS>` 配下の `address-family ipv4 vrf <NAME>` を使用します。
* MP-BGPを使わない純粋なVRF-LiteのeBGPピアリングであっても、BGPプロセス内部でVRFテーブルを識別・初期化するために、**`vrf definition` 内で `rd <ASN:NN>` (Route Distinguisher) の定義が必須**となる場合があります。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における VRF-Lite の完全な設定手順例です。

### 1. VRFの定義（IPv4/IPv6 Dual-Stack）

```bash
# VRF RED の定義
vrf definition RED
 description Tenant_RED_Network
 rd 65000:10
 !
 address-family ipv4
 exit-address-family
 !
 address-family ipv6
 exit-address-family
!

# VRF BLUE の定義
vrf definition BLUE
 description Tenant_BLUE_Network
 rd 65000:20
 !
 address-family ipv4
 exit-address-family
 !
 address-family ipv6
 exit-address-family
!
```

### 2. インターフェイスへの VRF バインドと IP アドレス設定

```bash
# 802.1Q サブインターフェイス (VRF RED)
interface GigabitEthernet0/0/1.10
 encapsulation dot1Q 10
 vrf forwarding RED
 ip address 10.1.10.1 255.255.255.0
 ipv6 address 2001:DB8:10::1/64
!

# 802.1Q サブインターフェイス (VRF BLUE)
interface GigabitEthernet0/0/1.20
 encapsulation dot1Q 20
 vrf forwarding BLUE
 ip address 10.1.20.1 255.255.255.0
 ipv6 address 2001:DB8:20::1/64
!
```

### 3. ルーティングプロトコルの構成（VRF-Lite対応）

#### (A) Static Route per VRF
```bash
ip route vrf RED 0.0.0.0 0.0.0.0 10.1.10.254
ipv6 route vrf RED ::/0 2001:DB8:10::FE
```

#### (B) OSPFv2 per VRF (`capability vrf-lite` 含む)
```bash
router ospf 10 vrf RED
 router-id 1.1.1.1
 capability vrf-lite
 network 10.1.10.0 0.0.0.255 area 0
!
```

#### (C) EIGRP Named Mode per VRF
```bash
router eigrp ENTERPRISE
 !
 address-family ipv4 vrf RED autonomous-system 100
  topology base
  exit-topology
  network 10.1.10.0 0.0.0.255
 exit-address-family
!
```

#### (D) BGP per VRF (eBGP)
```bash
router bgp 65000
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf RED
  neighbor 10.1.10.2 remote-as 65100
  neighbor 10.1.10.2 activate
 exit-address-family
!
```

---

## 🔍 検証コマンド

VRF-Liteの動作ステータスやルーティングテーブルを確認するための検証コマンド一覧です。

| 目的 | コマンド |
| :--- | :--- |
| **定義されているすべてのVRF一覧、RD、バインドされているインターフェイスの確認** | <code>show vrf</code> または <code>show vrf detail</code> |
| **特定VRF（RED）のIPv4ルーティングテーブル確認** | <code>show ip route vrf RED</code> |
| **特定VRF（RED）のIPv6ルーティングテーブル確認** | <code>show ipv6 route vrf RED</code> |
| **特定VRF（RED）のCEF（FIB）転送テーブル確認** | <code>show ip cef vrf RED</code> |
| **特定VRFのルーティングプロトコルネイバー確認 (OSPF)** | <code>show ip ospf vrf RED neighbor</code> |
| **特定VRFのルーティングプロトコルネイバー確認 (EIGRP)** | <code>show ip eigrp vrf RED neighbors</code> |
| **特定VRFのBGPサマリー確認** | <code>show ip bgp vrf RED summary</code> |
| **特定VRF経由でのPING導通確認** | <code>ping vrf RED 10.1.10.2</code> |
| **特定VRF経由でのTraceroute確認** | <code>traceroute vrf RED 10.1.10.2</code> |
| **特定VRFのソケットを用いたTelnet/SSH確認** | <code>ssh -vrf RED -l admin 10.1.10.2</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **インターフェイスに `vrf forwarding` を設定したら通信が全断した** | VRFバインドコマンド実行時に、**インターフェイスに設定されていたIPアドレスが自動消去**された。 | `show ip interface brief` | `vrf forwarding <NAME>` を設定した後に、再度 `ip address` および `ipv6 address` を設定し直す。 |
| **VRF配下のOSPFで対向からLSAを受信しているのに、ルーティングテーブルに反映されない** | MPLS非存在のVRF-Lite環境で、OSPFのPE用ループ防止機能（DN Bitチェック）が働き、LSAが破棄されている。 | `show ip ospf vrf <NAME> database` | OSPFプロセス配下に **`capability vrf-lite`** を追加してDN Bitチェックを無効化する。 |
| **`ping 10.1.10.2` を打っても 「Unreachable」または Global テーブルが検索されて失敗する** | Ping実行時にVRFの明示指定（`-vrf` / `vrf` キーワード）を忘れているため、Globalルーティングテーブルが検索されている。 | `ping vrf <NAME> <IP>` | `ping vrf RED 10.1.10.2` のように、必ず `vrf` パラメータを付与して実行する。 |
| **EIGRPでVRF配下のネイバーが確立しない** | 1. 双方の `autonomous-system <AS>` 番号が不一致。<br>2. インターフェイスがVRFに正しくバインドされていない。 | `show ip eigrp vrf <NAME> neighbors`<br>`show vrf` | EIGRPの `address-family ipv4 vrf <NAME> autonomous-system <AS>` のAS番号が対向と一致しているか確認する。 |
| **BGPで `address-family ipv4 vrf <NAME>` が有効化できない、またはピアが立たない** | 対象の `vrf definition` 内で **`rd` (Route Distinguisher) が定義されていない** ため、BGP構造体が初期化できない。 | `show run vrf <NAME>`<br>`show ip bgp vrf <NAME> summary` | `vrf definition <NAME>` 内に `rd 65000:1` などのRD値を定義する。 |
| **VRF間（例: RED と BLUE）で通信が到達しない** | VRF-LiteはL3レベルで完全隔離されているため、Route Leaking（ルートリーク）設定がない限り一切通信できない。 | `show ip route vrf <NAME>` | 仕様通りの挙動。通信が必要な場合は、VASI、Static Route Leaking、またはBGP MP-BGP/Route-targetを用いたルートリークを構築する。 |

---

## ⚠ 制限事項

### 1. スケーラビリティ制限（ハードウェア依存）
* 物理ルータ/スイッチのメモリおよびTCAMサイズにより、サポート可能な最大VRF数および最大プレフィックス数が制限されます。
* VRF数が数十〜数百に及ぶ大規模環境では、ホップごとにVLANサブインターフェイスを作成するVRF-Liteは設定管理が破綻するため、MPLS L3VPNやEVPN-VXLAN、LISP/VXLAN (SD-Access) などの動的オーバーレイ技術へ移行する必要があります。

### 2. 機能ごとの VRF-aware サポートの差異
Cisco IOS-XEの主要機能（NAT, IPsec, DHCP Relay, IP SLA, NetFlow, PBR等）は基本的に **VRF-aware**（VRF対応）ですが、機能ごとに設定構文（例: `ip nat inside vrf ...`, `ip helper-address ... global` 等）が異なるため、個別コマンドの仕様確認が必要です。

---

## 🔄 他技術との関連

* **802.1Q Subinterfaces / SVI:** VRF-Liteにおいて、単一の物理トランクリンク上で複数VRFのトラフィックを多重化（L2セグメンテーション）するための標準的な下体技術。
* **MPLS L3VPN:** VRF-Liteがローカル/直接バインドリンクで完結するのに対し、MPLS L3VPNは core 網で LDP（ラベル）と MP-BGP（VPNv4/VPNv6）を用いて広域にVRFを延伸する技術。
* **Route Leaking (VRF間リーク):** 隔離されたVRF同士（例: 各部門VRFと共通サーバースペースVRF）の間で特定ルートのみを相互に参照可能にする技術（Static Leak, VASI, Route-map, MP-BGP）。
* **VRF-aware NAT / VASI:** NAT処理を特定VRF内、またはVRF跨ぎ（VRF-aware Software Infrastructure）で実行する技術。
* **Management VRF (Mgmt-vrf):** Catalystスイッチ等の専用管理ポート（GigabitEthernet0/0）が所属する特格のVRF。SSHやSNMP、TACACS+等の管理トラフィックを隔離するために標準使用される。

---

## 🧩 比較表

### 1. VRF-Lite vs MPLS L3VPN

| 比較項目 | VRF-Lite (Multi-VRF CE) | MPLS L3VPN |
| :--- | :--- | :--- |
| **MPLSヘッダー (LDP/RSVP)** | **不要**（使用しない） | **必須**（Core網でラベルスイッチングを実行） |
| **MP-BGP (VPNv4/v6)** | 基本的に不要（ローカルルーティングで完結） | **必須**（PE間でRD/RT属性付きのVPNルートを交換） |
| **VRFの延伸方法** | ホップごとに VLAN（Subinterface/SVI）や GRE トンネルを個別に定義 | PE間で MP-BGP と MPLS/VXLAN トンネルを用いて透過的に延伸 |
| **構成の複雑さ** | **低〜中**（小規模〜中規模のセグメンテーションに最適） | **高**（キャリア網や大規模エンタープライズに最適） |
| **主な適用場所** | キャンパスLAN、Fusion Router、データセンターエッジ | WANインフラ、サービスプロバイダ網、大規模SD-WAN |

### 2. `ip vrf` (Legacy) vs `vrf definition` (Modern)

| 比較項目 | `ip vrf <NAME>` | `vrf definition <NAME>` |
| :--- | :--- | :--- |
| **プロトコルサポート** | **IPv4 専用** | **IPv4 & IPv6 (Dual-Stack) サポート** |
| **Address-Family 指定** | 不要 | **必須** (`address-family ipv4` / `ipv6`) |
| **インターフェイス適用コマンド** | `ip vrf forwarding <NAME>` | `vrf forwarding <NAME>` |
| **推奨度** | レガシー（非推奨） | **Cisco推奨（CCIE試験の標準仕様）** |

---

## 💡 ベストプラクティス

1. **`vrf definition` 構文への完全統一:**
   IPv4のみの要件であっても、将来のIPv6拡張性およびCCIE試験での統一性の観点から、常に `vrf definition` コマンドを使用する。
2. **インターフェイス設定順序の標準化:**
   必ず **「① VRF定義 ➔ ② インターフェイスへの `vrf forwarding` 割当 ➔ ③ IPアドレス設定」** の順序を厳守し、IPアドレス消去トラブルを100%防止する。
3. **OSPF使用時の `capability vrf-lite` 必須投入:**
   VRF配下でOSPFを動かす場合は、ルーティング不通トラブルを避けるために無条件で `capability vrf-lite` を設定に追加する習慣をつける。
4. **意図的な RD (Route Distinguisher) の付与:**
   VRF-Liteであっても、BGPや将来の拡張性に備えて各VRFに一意のRD（例: `65000:10`, `65000:20`）を定義しておく。

---

## 📝 ラボ学習・設定サンプル例

※ 以下のサンプルは、Cisco IOS-XE 17.x の実機挙動に完全準拠した、省略なしのCLI設定構成です。

---

### 1. 基本的な VRF-Lite の定義と 802.1Q サブインターフェイスへの割当 (Dual-Stack)
**【問題】**
R1において、2つのVRF（`CORP` および `GUEST`）を `vrf definition` を用いて作成してください。両VRFでIPv4およびIPv6を有効化し、RDとしてそれぞれ `65000:100` および `65000:200` を指定してください。
インターフェイス `Gi0/0/1.100` を `CORP` に、`Gi0/0/1.200` を `GUEST` に割り当て、適切なIPアドレスを設定してください。

**【設定例 (R1)】**
```bash
configure terminal

! 1. VRF 定義
vrf definition CORP
 rd 65000:100
 !
 address-family ipv4
 exit-address-family
 !
 address-family ipv6
 exit-address-family
!
vrf definition GUEST
 rd 65000:200
 !
 address-family ipv4
 exit-address-family
 !
 address-family ipv6
 exit-address-family
!

! 2. インターフェイス割当 (VRFバインド後にIP設定)
interface GigabitEthernet0/0/1.100
 encapsulation dot1Q 100
 vrf forwarding CORP
 ip address 10.100.1.1 255.255.255.0
 ipv6 address 2001:DB8:100::1/64
!
interface GigabitEthernet0/0/1.200
 encapsulation dot1Q 200
 vrf forwarding GUEST
 ip address 10.200.1.1 255.255.255.0
 ipv6 address 2001:DB8:200::1/64
!
end
```

**【検証方法】**
```bash
show vrf
show ip route vrf CORP
show ipv6 route vrf GUEST
```

---

### 2. VRF-Lite 環境における Dynamic Routing (OSPFv2 per VRF) の設定
**【問題】**
R1とR2の間で、VRF `CORP` 配下にて OSPFv2 (Process ID 100) を構成してください。
エリア 0 でネットワーク `10.100.1.0/24` を広報し、VRF-Lite環境特有のLSA破棄を防止するための必須コマンドを適用してください。

**【設定例 (R1)】**
```bash
configure terminal
router ospf 100 vrf CORP
 router-id 1.1.1.1
 ! PEループ防止チェックを無効化
 capability vrf-lite
 network 10.100.1.0 0.0.0.255 area 0
!
end
```

**【設定例 (R2)】**
```bash
configure terminal
router ospf 100 vrf CORP
 router-id 2.2.2.2
 capability vrf-lite
 network 10.100.1.0 0.0.0.255 area 0
!
end
```

**【検証方法】**
```bash
show ip ospf vrf CORP neighbor
show ip route vrf CORP ospf
```

---

### 3. VRF-Lite 環境における EIGRP Named Mode の設定
**【問題】**
R1において、EIGRP Named Mode（インスタンス名: `ENTERPRISE`）を構成し、VRF `CORP` (AS 100) および VRF `GUEST` (AS 200) のルーティングを定義してください。

**【設定例 (R1)】**
```bash
configure terminal
router eigrp ENTERPRISE
 !
 address-family ipv4 vrf CORP autonomous-system 100
  topology base
  exit-topology
  network 10.100.1.0 0.0.0.255
 exit-address-family
 !
 address-family ipv4 vrf GUEST autonomous-system 200
  topology base
  exit-topology
  network 10.200.1.0 0.0.0.255
 exit-address-family
!
end
```

**【検証方法】**
```bash
show ip eigrp vrf CORP neighbors
show ip route vrf CORP eigrp
```

---

### 4. VRF-Lite 環境における BGP (eBGP per VRF) の設定
**【問題】**
R1 (AS 65000) と対向ルータ (AS 65100, IP: `10.100.1.2`) の間で、VRF `CORP` 配下の eBGP ピアリングを構築してください。

**【設定例 (R1)】**
```bash
configure terminal
router bgp 65000
 bgp log-neighbor-changes
 !
 address-family ipv4 vrf CORP
  neighbor 10.100.1.2 remote-as 65100
  neighbor 10.100.1.2 activate
  network 10.100.100.0 mask 255.255.255.0
 exit-address-family
!
end
```

**【検証方法】**
```bash
show ip bgp vrf CORP summary
show ip route vrf CORP bgp
```

---

### 5. SVI (VLAN) を用いた L3 スイッチにおける VRF-Lite セグメンテーション
**【問題】**
スイッチ SW1 において、VLAN 10 区分を VRF `FINANCE` に、VLAN 20 区分を VRF `HR` に割り当て、それぞれのSVIインターフェイスでIPルーティングを有効化してください。

**【設定例 (SW1)】**
```bash
configure terminal

! VRF 定義
vrf definition FINANCE
 rd 65000:10
 address-family ipv4
 exit-address-family
!
vrf definition HR
 rd 65000:20
 address-family ipv4
 exit-address-family
!

! VLAN 作成
vlan 10,20
!

! SVI 設定
interface Vlan10
 description FINANCE_SVI
 vrf forwarding FINANCE
 ip address 172.16.10.1 255.255.255.0
 no shutdown
!
interface Vlan20
 description HR_SVI
 vrf forwarding HR
 ip address 172.16.20.1 255.255.255.0
 no shutdown
!
end
```

**【検証方法】**
```bash
show vrf
show ip route vrf FINANCE
show ip route vrf HR
```

---

### 6. VRF-aware Static Routing と Default Route
**【問題】**
R1において、VRF `CORP` 用のデフォルトルートをネクストホップ `10.100.1.254` 宛てに、VRF `GUEST` 用のデフォルトルートをネクストホップ `10.200.1.254` 宛てに静的設定してください。

**【設定例 (R1)】**
```bash
configure terminal
ip route vrf CORP 0.0.0.0 0.0.0.0 10.100.1.254
ip route vrf GUEST 0.0.0.0 0.0.0.0 10.200.1.254
end
```

**【検証方法】**
```bash
show ip route vrf CORP static
show ip route vrf GUEST static
```

---

### 7. VRF-aware Management VRF (Mgmt-vrf) の構成と SSH アクセス制限
**【问题】**
管理用ポート `GigabitEthernet0/0` を専用の VRF `Mgmt-vrf` に収容し、ルータへの SSH アクセスをこの管理VRF経由のみに限定してください。

**【設定例 (R1)】**
```bash
configure terminal

! 管理 VRF 定義
vrf definition Mgmt-vrf
 address-family ipv4
 exit-address-family
!

! インターフェイスバインド
interface GigabitEthernet0/0
 description MANAGEMENT_PORT
 vrf forwarding Mgmt-vrf
 ip address 192.168.1.50 255.255.255.0
 no shutdown
!

! VTY ラインでの VRF 制限
line vty 0 4
 exec-timeout 15 0
 login local
 transport input ssh
!
end
```

**【検証方法】**
```bash
show vrf Mgmt-vrf
ssh -vrf Mgmt-vrf -l admin 192.168.1.50
```

---

### 8. VRF-aware DHCP Relay (ip helper-address) の構成
**【問題】**
SW1の SVI `Vlan10` (VRF `FINANCE`) に着信したDHCPリクエストを、別セグメント（またはGlobal/別VRF）に存在するDHCPサーバー `10.0.0.100` へ転送するように設定してください。

**【設定例 (SW1)】**
```bash
configure terminal
interface Vlan10
 vrf forwarding FINANCE
 ip address 172.16.10.1 255.255.255.0
 ! VRFを越えた、またはVRF内のDHCPサーバーを指定
 ip helper-address 10.0.0.100
!
end
```

**【検証方法】**
```bash
show ip dhcp binding
show ip route vrf FINANCE
```

---

### 9. Static Route Leaking による VRF 間の静的通信許可（簡易リーク）
**【問題】**
R1において、VRF `RED` (`10.1.0.0/24`) から VRF `BLUE` (`10.2.0.0/24`) の特定のサーバ `10.2.0.50/32` への通信のみを静的ルートリークで許可してください（※ネクストホップとして相手側VRFの出力を指定）。

**【設定例 (R1)】**
```bash
configure terminal
! RED から BLUE への往路ルート
ip route vrf RED 10.2.0.50 255.255.255.255 GigabitEthernet0/0/1.20 10.2.0.50

! BLUE から RED への復路ルート (戻りパケット用)
ip route vrf BLUE 10.1.0.0 255.255.255.0 GigabitEthernet0/0/1.10 10.1.0.1
end
```

**【検証方法】**
```bash
show ip route vrf RED
show ip route vrf BLUE
ping vrf RED 10.2.0.50
```

---

### 10. VRF-aware GRE Tunnel (VRF over VRF) の設定
**【問題】**
アンダーレイ（輸送網）が VRF `WAN` に所属している環境で、オーバーレイの GRE トンネル `Tunnel0` を作成し、トンネル内部を VRF `CORP` として動作させてください。

**【設定例 (R1)】**
```bash
configure terminal

! VRF 定義
vrf definition WAN
 address-family ipv4
 exit-address-family
!
vrf definition CORP
 address-family ipv4
 exit-address-family
!

! トンネルインターフェイス設定
interface Tunnel0
 vrf forwarding CORP
 ip address 192.168.100.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 203.0.113.2
 ! アンダーレイのVRFを指定
 tunnel vrf WAN
!
end
```

**【検証方法】**
```bash
show interfaces Tunnel0
ping vrf CORP 192.168.100.2
```

---

## ❓ 想定試験問題

CCIE EI実技試験および記述試験レベルを意識した5つの思考型設問です。

### Question 1 (トラブルシューティング)
**問題:**
エンジニアが R1 において OSPFv2 を VRF `CUSTOMER_A` 配下で設定しましたが、対向ルータ R2 から広報されている Type-5 LSA（外部ルート）が R1 のルーティングテーブル（`show ip route vrf CUSTOMER_A`）に反映されません。
OSPF データベース（`show ip ospf vrf CUSTOMER_A database`）を確認すると、LSA 自体は正常に受信できています。
この問題の根本原因と、R1 で投入すべき解決コマンドを述べてください。

**解答・解説:**
* **原因:** OSPFプロセスが VRF 配下で動作しているため、Cisco IOS-XE は R1 を MPLS L3VPN の PE ルータと見なし、DN Bit (Down Bit) によるループ防止チェックを自動実行しています。R2 から送信された LSA に DN Bit がセットされている（または Domain-ID が不一致である）ため、R1 はループと判断して RIB への注入を拒否しています。
* **解決コマンド:** R1 の OSPF プロセス配下で **`capability vrf-lite`** を投入し、PE 用のDN Bitチェックを無効化します。
```bash
router ospf 1 vrf CUSTOMER_A
 capability vrf-lite
```

---

### Question 2 (コンフィグ読解・作法)
**問題:**
以下の設定手順を実行したところ、R1 の `GigabitEthernet0/0/1.10` 経由での通信が一切できなくなりました。設定の誤りを指摘し、正しく通信を復旧させるための設定例を示してください。

```bash
interface GigabitEthernet0/0/1.10
 encapsulation dot1Q 10
 ip address 10.1.10.1 255.255.255.0
 vrf forwarding SECURE
```

**解答・解説:**
* **誤りの理由:** `ip address` を設定した後に `vrf forwarding SECURE` を実行したため、VRFバインド時の仕様により、直前に設定した `ip address 10.1.10.1` が**自動消去**されてしまっています。
* **復旧設定例:** `vrf forwarding` を先に適用した上で、再度 IP アドレスを設定します。
```bash
interface GigabitEthernet0/0/1.10
 encapsulation dot1Q 10
 vrf forwarding SECURE
 ip address 10.1.10.1 255.255.255.0
```

---

### Question 3 (デザイン)
**問題:**
大規模エンタープライズにおいて、物理ルータ間を 802.1Q サブインターフェイスによる VRF-Lite で接続して 10 箇所の VRF を延伸する設計を検討しています。
この VRF-Lite 設計における将来的な運用の懸念点（デメリット）を 2 つ挙げ、それを解決するための代替オーバーレイ技術を提案してください。

**解答・解説:**
* **懸念点 (1):** ホップ（ルータ）を通過するごとにサブインターフェイスの作成と VRF バインド、および各 VRF 用のルーティングプロトコルの個別設定が必要となり、ホップ数や VRF 数が増えると設定管理オーバーヘッドが爆発的に増加する（N×Mのスケール問題）。
* **懸念点 (2):** 全途中のルータで VRF テーブルを保持する必要があり、Core ルータの TCAM / メモリ消費が肥大化する。
* **代替オーバーレイ技術の提案:** **MPLS L3VPN**、**EVPN-VXLAN**、または **LISP/VXLAN (SD-Access)**。これらの動的オーバーレイ技術を使用することで、Core 網の機器に個別 VRF を保持させることなく、Edge (PE/VTEP) 間で透過的にマルチテナント VRF を延伸可能となる。

---

### Question 4 (実装・EIGRP)
**問題:**
EIGRP Named Mode を使用して、同一ルータ内で Global テーブル、VRF `DEPT_A` (AS 10)、VRF `DEPT_B` (AS 20) の 3 つのルーティングインスタンスを並行稼働させる最小限の設定構造を示してください。

**解答・解説:**
```bash
router eigrp MULTI_TENANT
 ! Global 用
 address-family ipv4 autonomous-system 1
  topology base
  exit-topology
  network 10.0.0.0
 exit-address-family
 !
 ! VRF DEPT_A 用
 address-family ipv4 vrf DEPT_A autonomous-system 10
  topology base
  exit-topology
  network 10.10.0.0
 exit-address-family
 !
 ! VRF DEPT_B 用
 address-family ipv4 vrf DEPT_B autonomous-system 20
  topology base
  exit-topology
  network 10.20.0.0
 exit-address-family
```

---

### Question 5 (トラブルシューティング)
**問題:**
管理者であるあなたは、`ping 10.100.1.1` を実行しましたが通信がタイムアウトしました。
しかし、`show ip route vrf CORP` を確認すると、`10.100.1.1` 宛てのルートは正常に VRF `CORP` のルーティングテーブルに存在しています。
何が原因と考えられますか？正しい検証コマンドを提示してください。

**解答・解説:**
* **原因:** CLI で単に `ping 10.100.1.1` と実行した場合、ルータは **Global ルーティングテーブル** を参照してパケットを送出しようとします。Global テーブルには該当ルートが存在しないため（または不適切なポートから送出されるため）、通信が失敗します。
* **正解コマンド:** **`ping vrf CORP 10.100.1.1`** のように、`vrf` パラメータを明示的に指定して実行する。

---

## 🔗 参考リソース

* [Cisco IOS-XE 17.x Layer 2 and Layer 3 Configuration Guide - VRF Configuration](https://www.cisco.com/c/en/us/td/docs/routers/ios/config/17-x/ip/b-ip-routing/m_vrf-config.html)
* [Cisco IOS IP Routing: Protocol-Independent Configuration Guide - VRF-Lite](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/15-mt/iri-15-mt-book/iri-vrf-lite.html)
* [Cisco Live BRKCRS-2107: Multi-VRF and Network Virtualization Architecture](https://www.ciscolive.com/global/on-demand-library.html)
* [Cisco Command Reference - vrf definition / vrf forwarding](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/command/iri-cr-book.html)
* [Cisco Technical Note: Troubleshooting OSPF DN Bit in VRF-Lite Environments](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/118833-technote-ospf-00.html)

---

## 📝 **補足（Notes）**

### VRF-Lite 設定＆検証チェックリスト (CCIE 試験用)

1. **`vrf definition` の作成:**
   * [ ] `rd <ASN:NN>` が設定されているか？
   * [ ] `address-family ipv4` および `address-family ipv6` が有効化（`exit-address-family`）されているか？
2. **インターフェイス設定:**
   * [ ] `ip address` を設定する**前に** `vrf forwarding <NAME>` をバインドしたか？
   * [ ] `show ip interface brief` で IP アドレスが消えていないことを確認したか？
3. **OSPF 設定 (使用時):**
   * [ ] `capability vrf-lite` を OSPF プロセスに追加したか？
4. **EIGRP 設定 (使用時):**
   * [ ] `address-family ipv4 vrf <NAME> autonomous-system <AS>` 内で `topology base` が正しく定義されているか？
5. **検証:**
   * [ ] コマンド実行時に `vrf <NAME>` キーワード（`show ip route vrf ...`, `ping vrf ...`）を付与しているか？

---

---

## 参考リソースリンク

### Configurationガイド
*   [Configuring VRF-Lite (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr3/b_179_lyr3_9300_cg/m_configuring_vrf_lite.html)
*   [VRF-Aware Services (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/15986-admin-distance.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals (セグメンテーション理論)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKSEC-2031: End-to-End Segmentation with TrustSec and VRFs](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2031)

### テクニカルドキュメント・設定例
*   [Route Leaking between VRFs using Import/Export RTs](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200158-Configure-Route-Leaking-between-VRFs-usi.html)
*   [OSPF in VRF-Lite: Down-bit and Domain-ID](https://www.cisco.com/c/ja_jp/support/docs/ip/open-shortest-path-first-ospf/118812-config-ospf-00.html)

---

*   [VRF, MPLS and MP-BGP Fundamentals - BRKCRT-2601](chrome-extension://oemmndcbldboiebfnladdacbdfmadadm/https://www.ciscolive.com/c/dam/r/ciscolive/emea/docs/2024/pdf/BRKCRT-2601.pdf)


## 📝 補足

- この学習メモは、CCIE EIラボ試験において「物理トポロジを論理的にどう分割し、必要に応じてどう結合するか」という設計・実装能力を養うための指針となります。VRF-Liteは単純なセグメンテーションだけでなく、後のSD-WAN（Service VPN）やSDA（Virtual Network）の基礎となる非常に重要な概念です。

