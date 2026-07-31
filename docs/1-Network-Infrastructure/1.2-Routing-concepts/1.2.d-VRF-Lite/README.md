---
layout: default
title: 1.2.d-VRF-Lite
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.2.d-VRF-Lite

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.d VRF-Lite」について整理しました。

---

## 📘 概要

**VRF (Virtual Routing and Forwarding)** は、1台の物理ルータの中に複数の独立したルーティングテーブル（RIB）と転送テーブル（FIB）を保持する技術です。これにより、物理的なネットワークインフラを論理的に分割し、あたかも複数台のルータが動作しているかのような「ネットワークの仮想化」を実現します。

**VRF-Lite** とは、MPLS（Multiprotocol Label Switching）によるラベルスイッチングを使用せずに、ルータ上でVRFのみを構成してネットワークのセグメンテーション（分離）を行う実装を指します。主にエンタープライズのキャンパスネットワークや、サービスプロバイダーのPE-CE境界において、特定の部門、テナント、あるいはゲストネットワークを完全に分離するために使用されます。

CCIEレベルでは、単なる分離にとどまらず、**VRF間のルート交換（Route Leaking）**、**共通サービス（Shared Services）へのアクセス**、および **VRF-Awareな動的ルーティングプロトコル** の高度な制御が求められます。

---

## 🔑 要点

### 1. VRF の構成要素

VRFを定義する際、以下の2つの主要なパラメータを正しく理解し使い分ける必要があります。

| 項目 | 正式名称 | 役割 |
| :--- | :--- | :--- |
| **RD** | **Route Distinguisher** | ルータ内で重複する可能性があるIPプレフィックスを**一意に識別**するための8バイトの識別子。BGPでルートを運ぶ際にプレフィックスの先頭に付加されます。 |
| **RT** | **Route Target** | VRF間でどのルートをインポート（取り込み）し、どのルートをエクスポート（広報）するかを制御する**BGP拡張コミュニティ属性**。 |

### 2. vrf definition (Modern) vs. ip vrf (Legacy)

古いIOSコマンド（`ip vrf [NAME]`）はIPv4のみをサポートしていましたが、現在の主流である **`vrf definition`** は、1つのVRFインスタンス内でIPv4とIPv6の両方のアドレスファミリー（Multi-AF）を管理できます。

### 3. インターフェイスの紐付け

インターフェイスをVRFに割り当てる（`vrf forwarding [NAME]`）と、そのインターフェイスに設定されていた **IPアドレスは自動的に削除される** ため、再設定が必要です。この挙動はラボ試験中のコンフィギュレーションにおいて注意すべきポイントです。

### 4. ルートリーキング (Route Leaking)

通常、VRF A のルートは VRF B からは見えませんが、以下の手法で通信を許可できます。
*   **RT Import/Export (BGP経由):** BGPプロセス内でRTを操作し、VRF間でルートをインポートします。
*   **Static Route Leaking:** 静的ルートの次ホップに別のVRFやインターフェイスを指定して強制的にリークさせます。
*   **Global Route Leaking:** VRFとグローバルルーティングテーブル間での相互通信。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、VRF-Liteは「セグメンテーション（隔離）」の要件として、あるいは「SD-WANやSDAへの移行」の前提知識として頻繁に登場します。

### 1. セグメンテーションの維持

*   **要件例:** 「VRF 'Employee' と VRF 'Guest' を完全に分離し、互いの通信を一切禁止せよ。ただし両方のVRFから共通のDNSサーバ（グローバルに存在）への通信だけは許可せよ。」
*   **対策:** インターフェイスを各VRFに閉じ込めた上で、共通サービスへのアクセスにはスタティックルートやBGPによる限定的なリーキングを実装します。

### 2. 複雑な再配送とVRF

*   VRF内で動作するルーティングプロトコル（OSPFやEIGRP）と、グローバルテーブルや他のVRFとの間で再配送を行う場合、AD値の変化やルーティングループに細心の注意が必要です。
*   特に **OSPF in VRF** では、Domain IDやDNビット（Down Bit）の挙動により、ルートが意図せずフィルタリングされる「バックドアパス問題」を解決する知識が問われます。

### 3. VRF-Aware Services

*   **DHCP Relay:** 特定のVRFに属するクライアントからのDHCPリクエストを、別のVRFにあるDHCPサーバへリレーする設定（`ip helper-address vrf ...`）。
*   **Management:** SSH、SNMP、Syslogを特定の管理用VRF経由で送信する構成。

### 4. ローカル PBR との組み合わせ

*   ルータ自身が生成するトラフィック（Local PBR）を特定のVRFへ誘導し、管理プレーンの通信経路を制御するタスク。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **VRFの定義(Multi-AF)** | <code>vrf definition [NAME]</code> |
| **RDの設定** | <code>(config-vrf)# rd [AS:NN &#124; IP:NN]</code> |
| **RTの設定(インポート)** | <code>(config-vrf-af)# route-target import [RT_VALUE]</code> |
| **アドレスファミリー有効化** | <code>(config-vrf)# address-family ipv4 &#124; ipv6</code> |
| **インターフェイス割り当て** | <code>(config-if)# vrf forwarding [NAME]</code> |
| **VRFルーティング表示** | <code>show ip route vrf [NAME]</code> |
| **VRF内でのPing実行** | <code>ping vrf [NAME] [TARGET_IP]</code> |
| **VRF構成情報の要約表示** | <code>show vrf [NAME]</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 基本的な VRF-Lite とセグメンテーション

**【問題内容】**
R1において、VRF 'RED' と VRF 'BLUE' を作成せよ。GigabitEthernet1 は RED、GigabitEthernet2 は BLUE に所属させ、それぞれのルーティングテーブルが完全に分離されていることを確認せよ。

**【設定例】**
```ios
vrf definition RED
 rd 100:1
 address-family ipv4
 exit-address-family
!
vrf definition BLUE
 rd 100:2
 address-family ipv4
 exit-address-family
!
interface GigabitEthernet1
 vrf forwarding RED
 ip address 10.1.1.1 255.255.255.0
!
interface GigabitEthernet2
 vrf forwarding BLUE
 ip address 10.2.2.1 255.255.255.0
```
**【検証】**
`show ip route vrf RED` と `show ip route vrf BLUE` を実行し、互いのルートが一切表示されないことを確認します。

---

### 2. VRF間のルート交換 (Merging Companies / RT Leaking)

**【問題内容】**
Source 158にあるように、企業合併に伴い VRF 'Customer_A' と VRF 'Customer_B' の間でルートを交換したい。BGPを用いて相互のルートを各VRFのRIBへインポートせよ。

**【設定例】**
```ios
vrf definition Customer_A
 rd 1:1
 address-family ipv4
  route-target export 1:10
  route-target import 1:10
  route-target import 1:20  ! Bからのルートを取り込む
!
vrf definition Customer_B
 rd 1:2
 address-family ipv4
  route-target export 1:20
  route-target import 1:20
  route-target import 1:10  ! Aからのルートを取り込む
!
router bgp 65000
 address-family ipv4 vrf Customer_A
  redistribute connected
 address-family ipv4 vrf Customer_B
  redistribute connected
```

---

### 3. スタティックルートによる共通サービスへのリーキング

**【問題内容】**
VRF 'GUEST' に属するホストから、グローバルルーティングテーブルにあるDNSサーバ（8.8.8.8）への通信のみを許可せよ。

**【設定例】**
```ios
! VRFからグローバル（DNS）への戻りパス
ip route vrf GUEST 8.8.8.8 255.255.255.255 GigabitEthernet0/0 172.16.1.254 global
!
! グローバルからVRF（クライアント）への行きパス
ip route 192.168.10.0 255.255.255.0 GigabitEthernet0/1 vrf GUEST
```

---

### 4. VRF-Aware DHCP リレーの実装

**【問題内容】**
VRF 'USERS' に属するクライアントからのDHCPリクエストを、VRF 'SERVICES' に存在するDHCPサーバー（10.100.1.100）へ転送せよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 vrf forwarding USERS
 ip address 192.168.1.1 255.255.255.0
 ! 次ホップのVRFを明示的に指定
 ip helper-address vrf SERVICES 10.100.1.100
```

---

### 5. VRF内での OSPF 構成（マルチインスタンス）

**【問題内容】**
VRF 'PROD' 内で OSPF プロセス 10 を動作させ、ネイバーを確立せよ。

**【設定例】**
```ios
router ospfv3 10
 address-family ipv4 unicast vrf PROD
  router-id 1.1.1.1
!
interface GigabitEthernet0/1
 vrf forwarding PROD
 ospfv3 10 ipv4 area 0
```
※注：`ospfv3` を使用することで、同一インターフェイス上での複数AFやVRFの管理が容易になります。

---

### 6. VRFを使用した管理トラフィックの分離

**【問題内容】**
ルータのすべての管理トラフィック（Syslog）を VRF 'MGMT' 経由で 10.255.1.1 へ送信するように構成せよ。

**【設定例】**
```ios
vrf definition MGMT
 address-family ipv4
!
ip route vrf MGMT 0.0.0.0 0.0.0.0 10.255.1.254
!
logging host 10.255.1.1 vrf MGMT
ip source-interface logging Loopback99  ! Loopback99もMGMTに所属している前提
```

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


## 📝 補足

- この学習メモは、CCIE EIラボ試験において「物理トポロジを論理的にどう分割し、必要に応じてどう結合するか」という設計・実装能力を養うための指針となります。VRF-Liteは単純なセグメンテーションだけでなく、後のSD-WAN（Service VPN）やSDA（Virtual Network）の基礎となる非常に重要な概念です。

