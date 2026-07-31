---
layout: default
title: 1.2.e-VRF-aware-routing
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.2.e-VRF-aware-routing

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.e VRF-aware routing with BGP, EIGRP, OSPF, and static」について整理しました。

---

## 📘 概要

**VRF-aware routing（VRF認識ルーティング）**とは、ルーティングプロトコルやスタティックルートが、特定のVRF（Virtual Routing and Forwarding）インスタンスのコンテキスト内で動作し、それぞれの独立したルーティングテーブル（RIB）を管理・制御する能力を指します。

1台の物理ルータを論理的に分割するVRF-Lite環境において、BGP, EIGRP, OSPF, およびスタティックルートをVRFごとに正しく動作させることは、エンタープライズネットワークのセグメンテーション（隔離）を完成させるために不可欠です。CCIEレベルでは、単なる隔離だけでなく、ビジネス要件に基づいた「VRF間通信（Route Leaking）」や「共通サービス（Shared Services）へのアクセス」を、プロトコル固有の属性や挙動を理解した上で実装する能力が問われます。

---

## 🔑 要点

### 1. VRF 管理の基礎概念

VRF対応プロトコルを構成する前に、基盤となる識別子と属性を正しく理解する必要があります。

*   **Route Distinguisher (RD)**: ルータ内部（またはBGP VPNv4内）で、重複する可能性のあるIPプレフィックスを**一意にする**ための8バイトの値です。一つのVRFに1つのRDが必須です。
*   **Route Target (RT)**: BGPの拡張コミュニティ属性であり、**どのルートをインポートし、どのルートをエクスポートするか**というルーティングポリシーを決定します。VRF間のルート交換（リーキング）は主にこのRTの操作によって行われます。
*   **Address Family (AF)**: 現代の `vrf definition` コマンドは Multi-AF 対応であり、IPv4 と IPv6 の設定を一つのインスタンス内で統合管理できます。

### 2. プロトコル別のVRF対応の挙動

各プロトコルは、VRF内で動作する際に特有のコマンド体系や制約を持ちます。

| プロトコル | VRF対応の特徴 |
| :--- | :--- |
| **Static** | `ip route vrf [NAME]` コマンドを使用。次ホップに `global` キーワードを付けることで、グローバルテーブルへのリークが可能です。 |
| **BGP** | `address-family ipv4 vrf [NAME]` 配下でネイバーや再配送を設定。RT値に基づいてVRF RIBへルートをインストールします。 |
| **OSPF** | VRFごとに独立したプロセス（OSPFv2）または `address-family`（OSPFv3）を使用。**DNビット**や**Domain ID**によりループを防止します。 |
| **EIGRP** | `address-family ipv4 vrf [NAME]` 配下で `autonomous-system [ID]` を明示する必要があります。名前付きモード（Named Mode）が推奨されます。 |

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、VRF-aware routingに関連して以下のような高度なトラブルシューティングや設計タスクが出題されます。

### 1. OSPF in VRF：バックドアパスとループ防止

*   **DNビット（Down Bit）**: PE-CE間のOSPFにおいて、LSA 3, 5, 7に自動的に付与されます。CEルータがこのビットの立ったLSAを受信すると、ループ防止のために自身のRIBへのインストールを拒否します。
*   **Domain ID**: 再配送時にOSPFルートが「外部ルート(E1/E2)」になるか「エリア間ルート(IA)」になるかを決定します。
*   **ラボでの注意点**: VRF-Lite環境（MPLSなし）でOSPFを回す場合、`capability vrf-lite` コマンドを入れないと、DNビットのチェックによりルートが学習できないシナリオが頻出します。

### 2. EIGRP VRF-aware：AS番号の不一致

*   VRFインスタンス内のEIGRPネイバーを確立するには、共通の `autonomous-system` 設定が必須です。グローバルなEIGRPプロセス番号とは別に、VRF AF配下でのAS番号指定が正しいかを確認する必要があります。

### 3. ルートリーキング（Route Leaking）の設計

*   **RTによるリーキング**: BGPを経由して、VRF AのエクスポートRTを VRF Bがインポートするように設定します。
*   **スタティックによるリーキング**: 行きのパスを `ip route vrf A ... interface X vrf B`、戻りのパスを逆に設定し、双方向の疎通を確保します。
*   **要件**: 「VRF GuestからグローバルのDNSのみ許可」といった、プレフィックスリストを組み合わせた限定的なリーキングが求められます。

### 4. VRF-aware Services の統合

*   **DHCP Relay**: `ip helper-address vrf [SRV_VRF] [SRV_IP]` を使用し、クライアントVRFからサーバVRFへのリレーを実装します。
*   **Management**: 特定のVRF（例：MGMT）にのみSSHやSNMPを許可する「管理プレーンの分離」も重要なタスクです。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **VRF定義(Multi-AF)** | <code>vrf definition [NAME]</code> |
| **RDの設定** | <code>(config-vrf)# rd [AS:NN &#124; IP:NN]</code> |
| **RTのインポート/エクスポート** | <code>(config-vrf-af)# route-target {import &#124; export &#124; both} [RT]</code> |
| **VRFスタティックルート** | <code>ip route vrf [NAME] [prefix] [mask] [next-hop]</code> |
| **OSPF VRFプロセス設定** | <code>router ospf [ID] vrf [NAME]</code> |
| **EIGRP VRF AF設定** | <code>router eigrp [NAME]</code> <br> <code>address-family ipv4 vrf [NAME] autonomous-system [AS]</code> |
| **BGP VRF AF設定** | <code>router bgp [AS]</code> <br> <code>address-family ipv4 vrf [NAME]</code> |
| **VRFのRIBを確認** | <code>show ip route vrf [NAME]</code> |
| **VRF内のプロトコル確認** | <code>show ip protocols vrf [NAME]</code> |
| **VRF内でのPing疎通確認** | <code>ping vrf [NAME] [IP]</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 企業合併に伴う VRF 間ルート交換 (BGP Route Leaking)

**【問題内容】**
R1において、VRF 'Customer_A' と VRF 'Customer_B' を定義せよ。各VRFに直結されたLoopbackの経路（10.10.10.1, 10.20.20.1）を、BGPのRoute Target操作を用いて相互に学習させ、疎通を確認せよ。

**【設定例】**
```ios
vrf definition Customer_A
 rd 1:1
 address-family ipv4
  route-target export 1:10
  route-target import 1:10
  route-target import 1:20  ! Bのルートを取り込む
!
vrf definition Customer_B
 rd 1:2
 address-family ipv4
  route-target export 1:20
  route-target import 1:20
  route-target import 1:10  ! Aのルートを取り込む
!
router bgp 65000
 address-family ipv4 vrf Customer_A
  redistribute connected
 !
 address-family ipv4 vrf Customer_B
  redistribute connected
```

---

### 2. OSPF VRF-Lite における到達不能問題の解決

**【問題内容】**
PEルータとして動作する R2 において、VRF 'PROD' 内で OSPF プロセス 10 を設定している。対向のCEルータからルートは届いているが、R2のルーティングテーブルにインストールされない。この「DNビットによる無視」を回避する設定を行え。

**【設定例】**
```ios
router ospf 10 vrf PROD
 ! VRF-Lite環境でのループチェック（DNビット検証）を無効化する
 capability vrf-lite
 redistribute connected
```
**【検証】**
`show ip route vrf PROD ospf` で、以前は表示されなかったルートがインストールされていることを確認します。

---

### 3. EIGRP 名前付きモード（Named Mode）による VRF 構成

**【問題内容】**
名前付きEIGRPインスタンス 'CCIE' を作成し、VRF 'BRANCH' 内で AS 100 を動作させよ。

**【設定例】**
```ios
router eigrp CCIE
 address-family ipv4 vrf BRANCH autonomous-system 100
  network 10.1.1.0 0.0.0.255
  topology base
   redistribute static
 exit-address-family
```

---

### 4. スタティックルートによる共有サービスへのアクセス (Global Leaking)

**【問題内容】**
VRF 'GUEST' に所属するホストが、グローバルテーブルに存在するインターネットゲートウェイ（172.16.1.254）へ通信できるようにスタティックルートを構成せよ。

**【設定例】**
```ios
! VRF GUESTからグローバルへのデフォルトルート
ip route vrf GUEST 0.0.0.0 0.0.0.0 172.16.1.254 global

! 戻りパケットのためにグローバルからVRF GUESTへのルート（リバースパス）が必要
ip route 192.168.10.0 255.255.255.0 GigabitEthernet0/1 vrf GUEST
```

---

### 5. IPv6 OSPFv3 の VRF インスタンス構成

**【問題内容】**
R6において、IPv6 VRF 'V6_NET' を作成し、OSPFv3 を用いて 2001:DB8:6::6/128 を広報せよ。

**【設定例】**
```ios
vrf definition V6_NET
 address-family ipv6
!
router ospfv3 1
 address-family ipv6 unicast vrf V6_NET
  router-id 6.6.6.6
!
interface Loopback0
 vrf forwarding V6_NET
 ipv6 address 2001:DB8:6::6/128
 ospfv3 1 ipv6 area 0
```

---

### 6. VRF-Aware DHCP リレーの複合設定

**【問題内容】**
VRF 'USER' のインターフェイスに着信したDHCPリクエストを、VRF 'INFRA' 内の 10.100.1.5 へリレーせよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 vrf forwarding USER
 ip address 10.1.1.1 255.255.255.0
 ! サーバの所属するVRFを明示的に指定
 ip helper-address vrf INFRA 10.100.1.5
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: BGP Configuration Guide - VRF Address Family (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)
*   [Configuring VRF-lite (Catalyst 9300)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr3/b_179_lyr3_9300_cg/m_configuring_vrf_lite.html)
*   [OSPF in VRF-Lite: Capability vrf-lite and DN-bit](https://www.cisco.com/c/ja_jp/support/docs/ip/open-shortest-path-first-ospf/118812-config-ospf-00.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals (Segmentation理論)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKSEC-2031: End-to-End Segmentation with VRF and TrustSec](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2031)
*   [BRKRST-3320: Troubleshooting Routing Protocols (VRFトラブル含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### テクニカルドキュメント・設定例
*   [Route Leaking between VRFs using Import/Export RTs](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200158-Configure-Route-Leaking-between-VRFs-usi.html)
*   [EIGRP VRF-aware Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/111442-eigrp-vrf-lite-00.html)

---

## 📝 補足
- この学習メモは、CCIE EIラボ試験における「物理ネットワーク上に複数の仮想ネットワークをどう構築し、制御するか」という設計・実装タスクの核心を網羅しています。特に OSPF の DNビット挙動や BGP の RT 操作は、試験でのトラブルシューティングにおける最優先の確認事項となります。

