---
layout: default
title: 1.2.f-Route-leaking
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 6
---

# 1.2.f Route leaking between VRFs using route maps and VASI

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.f Route leaking between VRFs using route maps and VASI」について、提供されたソース資料（iPexpert, Cisco公式ドキュメント等）およびCCIEラボ試験の実装要件に基づき、合格に必要な深さで詳細に整理しました。

---

## 📘 概要

**Route Leaking（ルートリーキング）**とは、VRF (Virtual Routing and Forwarding) によって論理的に隔離されたルーティングテーブル間で、特定の経路情報を相互に、あるいは一方的に交換し、通信を可能にする技術です。通常、VRFは強力なセグメンテーションを提供しますが、エンタープライズ環境では「共通サービス（DNS, NTP, 認証サーバなど）へのアクセス」や「企業合併に伴うネットワーク統合」などの要件により、意図的な隔離の解除が必要になります。

本項目では、特に**Route Maps（ルートマップ）**を用いたきめ細かな制御と、Cisco IOS XE独自の仮想インターフェイス技術である**VASI (VRF-Aware Software Infrastructure)** を用いたリーキング手法に焦点を当てます。これらは、単なるBGPのRoute Target（RT）操作によるリーキングよりも高度な制御（特定のプレフィックスのみ、特定の属性付与、あるいはステートフルなパケット検査を伴うリーキング）を可能にします。

---

## 🔑 要点

### 1. Route Map を用いた BGP Route Leaking

BGP VPNv4（またはMulti-AF BGP）を使用する場合、通常はRoute Target (RT) のインポート/エクスポートでリーキングを行いますが、Route Mapを組み合わせることで以下の高度な制御が可能になります。

*   **Export Map:** VRFからBGPテーブルへルートをエクスポートする際、Route Mapを適用して特定のプレフィックスにのみ追加のRTを付与したり、メトリックを変更したりします。これにより、特定のルートのみを対向のVRFへリークさせることができます,。
*   **Import Map:** BGPテーブルから特定のVRFへルートを取り込む際、Route Mapでフィルタリングを行います。これにより、RTが一致していても特定の経路だけを拒否する、といった制御が可能です。

### 2. VASI (VRF-Aware Software Infrastructure)

VASIは、物理的なインターフェイスやケーブル（外部への折り返し）を使用せずに、ルータ内部でVRF間のトラフィックを転送するための仮想インターフェイスペアです。

*   **インターフェイス構造:** `vasileft <number>` と `vasiright <number>` という2つのインターフェイスが対（ペア）として動作します。
*   **動作原理:** `vasileft` に入ったパケットは内部的に `vasiright` へ転送されます。それぞれを異なるVRFに所属させることで、VRF間の「物理的なバックツーバック接続」を仮想的に再現します。
*   **主な用途:** VRF間でトラフィックを通過させる際、Zone-Based Firewall (ZBF) などのセキュリティ機能を適用したい場合や、BGP VPNv4を介さずにスタティックや他のIGPでリーキングを行いたい場合に非常に有効です。

### 3. Static Route Leaking と Route Map

スタティックルートの次ホップに「別のVRF」や「そのVRFが属するインターフェイス」を指定することでルートを注入します。この際、再配送とRoute Mapを組み合わせることで、リークするルートの制御やタグ付けを行い、ループを防止します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純な全ルートのリーキングではなく、**「制約条件付き」**のリーキングが問われます。

### 1. プレフィックス単位のリーキング制御

「VRF AとVRF Bを統合（Merging）せよ。ただし、VRF AからはLoopbackの経路のみをVRF Bへ伝え、その他のセグメントは隔離を維持せよ」といった要件が出題されます。
*   **対策:** BGP AF配下で `export map` を使用し、プレフィックスリストでLoopbackを指定、`set extcommunity rt ...` でリーク先のRTを付加する実装が求められます。

### 2. ルーティングループの防止

VRF間で双方向に再配送やリーキングを行うと、ルートが循環（VRF A -> B -> A）し、AD値の不整合によってルーティングループが発生する可能性があります。
*   **対策:** Route Mapで `tag` を付与し、インポート側で `match tag` を用いて自身のVRF由来のルートを拒否するロジックを確立してください。

### 3. VASI を用いたステートフル検査

「VRF AからVRF Bへの通信を許可せよ。ただし、トラフィックはルータのファイアウォール機能で検査されなければならない」という要件に対し、VASIインターフェイスを定義し、そこに `inspect` ポリシーを適用するシナリオが想定されます。
*   VASIインターフェイスの設定自体はシンプルですが、`vasileft` / `vasiright` のペア番号が一致している必要がある点に注意してください。

### 4. 再帰的解決 (Recursive Lookup) の失敗

スタティックルートでリーキングを行う際、次ホップが別のVRFにある場合、その解決が正しく行われないことがあります。
*   **確認ポイント:** `show ip route vrf ...` でルートが「Routing descriptor blocks」として正しくインストールされているか、`global` キーワードが必要な構成かを確認します。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP VRFエクスポートマップ適用** | <code>(config-vrf-af)# export map [ROUTE_MAP]</code> |
| **BGP VRFインポートマップ適用** | <code>(config-vrf-af)# import map [ROUTE_MAP]</code> |
| **RTの追加(Route Map内)** | <code>(config-route-map)# set extcommunity rt [RT_VALUE] additive</code> |
| **VASIインターフェイスの作成** | <code>(config)# interface vasileft [NUMBER]</code> / <code>vasiright [NUMBER]</code> |
| **VASIへのVRF割り当て** | <code>(config-if)# vrf forwarding [NAME]</code> |
| **VRF間BGPテーブルの確認** | <code>show ip bgp vpnv4 all</code> |
| **特定のVRFルート詳細確認** | <code>show ip route vrf [NAME] [PREFIX]</code> |
| **VASIインターフェイスの状態確認** | <code>show interfaces vasileft [NUMBER]</code> |
| **RT属性の付与状況確認** | <code>show ip bgp vpnv4 vrf [NAME] [PREFIX]</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 企業合併：Export Map による限定的ルート交換

**【問題内容】**
Source 143にあるように、Customer_A と Customer_B が合併した。VRF 'Cust_A' のプレフィックス `10.1.1.0/24` のみを、VRF 'Cust_B' へインポートせよ。BGPを使用し、Route Mapで制御すること。

**【設定例】**
```ios
! リーク対象の指定
ip prefix-list TO_B permit 10.1.1.0/24
!
! Route MapでCust_BのRT(1:200)を付加
route-map MAP_LEAK_TO_B permit 10
 match ip address prefix-list TO_B
 set extcommunity rt 1:200 additive
route-map MAP_LEAK_TO_B permit 20
 ! その他のルートにはRTを付加しない
!
vrf definition Cust_A
 rd 1:100
 address-family ipv4
  export map MAP_LEAK_TO_B  ! BGPエクスポート時にMap適用
  route-target export 1:100
  route-target import 1:100
!
vrf definition Cust_B
 rd 1:200
 address-family ipv4
  route-target export 1:200
  route-target import 1:200
  route-target import 1:200  ! 自らのRTでインポート
```

---

### 2. VASI：VRF間のファイアウォール検査の実装

**【問題内容】**
VRF 'INSIDE' と VRF 'OUTSIDE' の間で通信を行わせ、かつ内部で Zone-Based Firewall による検査を実行せよ。VASIを使用して論理的な接続ポイントを作成すること。

**【設定例】**
```ios
! VASIペアの作成
interface vasileft 1
 vrf forwarding INSIDE
 ip address 192.168.1.1 255.255.255.0
 no shutdown
!
interface vasiright 1
 vrf forwarding OUTSIDE
 ip address 192.168.1.2 255.255.255.0
 no shutdown
!
! ルーティングの設定（スタティックでVASI経由にする）
ip route vrf INSIDE 0.0.0.0 0.0.0.0 192.168.1.2
ip route vrf OUTSIDE 10.0.0.0 255.0.0.0 192.168.1.1
!
! ZBFの適用（例）
zone security Z-INSIDE
zone security Z-OUTSIDE
!
interface vasileft 1
 zone-member security Z-INSIDE
interface vasiright 1
 zone-member security Z-OUTSIDE
```

---

### 3. スタティックルートによる共通サービスへのリーキング（Route Map併用）

**【問題内容】**
VRF 'GUEST' から、グローバルテーブルにある NTP サーバ `172.16.100.1` への通信のみを許可せよ。戻りパケットのためにグローバルからVRFへのルートも必要だが、特定のタグを持つものだけをBGPへ再配送せよ。

**【設定例】**
```ios
! 行きのルート：次ホップにglobalキーワード
ip route vrf GUEST 172.16.100.1 255.255.255.255 GigabitEthernet0/0 10.1.1.254 global

! 戻りのルート：タグ 999 を付与してリーク
ip route 192.168.200.0 255.255.255.0 GigabitEthernet0/1 vrf GUEST tag 999
!
! 再配送の制御
route-map LEAKED_BACK permit 10
 match tag 999
!
router bgp 65000
 address-family ipv4
  redistribute static route-map LEAKED_BACK
```

---

### 4. OSPF in VRF での DNビット問題の解決 (Capability vrf-lite)

**【問題内容】**
PEルータ間でルートをリークさせた際、CE側のOSPFがDNビットを検知してルートを無視している。VRF-Lite環境においてこのループ防止機能を無効化せよ。

**【設定例】**
```ios
router ospf 10 vrf CUSTOMER
 ! DNビット（Down Bit）の検証を無視し、ルートをインストールさせる
 capability vrf-lite
 redistribute bgp 65000 subnets
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: BGP Configuration Guide - Export/Import Maps (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)
*   [Configuring VASI (VRF-Aware Software Infrastructure)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_zbf/configuration/xe-16/sec-data-zbf-xe-16-book/sec-vasi-zbf.html)
*   [Route Leaking between VRFs using Import/Export RTs (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200158-Configure-Route-Leaking-between-VRFs-usi.html)

### CiscoLive (動画・スライド)
*   [BRKENS-2031: End-to-End Segmentation with VRF and TrustSec (VASIアーキテクチャを含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)
*   [BRKRST-3320: Troubleshooting Routing Protocols (VRFリーキングのトラブルシュート)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### テクニカルドキュメント・設定例
*   [VRF Route Leaking with Static Routes and BGP RTs](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/13731-static-vrf.html)
*   [Understanding OSPF Down Bit and Domain ID](https://www.cisco.com/c/ja_jp/support/docs/ip/open-shortest-path-first-ospf/118812-config-ospf-00.html)

---

## 📝 補足
- この学習メモは、CCIE EIラボ試験で求められる「ネットワークの完全な隔離」と「ビジネス上の必然的な共有」という矛盾する要件を、どのようにテクニカルに解決するかを網羅しています。特に `export map` は特定ルートのみの交換において非常に強力なツールであり、VASIはセキュリティ検査を伴うリーキングの唯一の解決策となるため、実機での検証を強く推奨します。


