---
layout: default
title: 3.2.b-L3VPN
parent: 3.2-MPLS
grand_parent: 3-Transport-Technologies-and-Solutions
nav_order: 2
---

# 3.2.b MPLS L3VPN

MPLS L3VPNは、サービスプロバイダーの共通インフラストラクチャ上で、複数の顧客に対して完全に分離されたプライベートなレイヤ3ネットワークを提供する技術です。CCIE EI v1.1の試験範囲において、このトピックはエンタープライズの拠点間接続や、SD-Access/SD-WANとレガシーネットワークの統合点（ハンドオフ）を理解する上で極めて重要な基盤となります。

---

## 📘 概要

**MPLS L3VPN** は、BGP（Border Gateway Protocol）の拡張機能である **MP-BGP (Multiprotocol BGP)** を利用して、顧客のルーティング情報をPE（Provider Edge）ルータ間で交換します。

データ転送プレーンでは、パケットの行き先を特定する「LDPラベル（トランスポートラベル）」と、どのVPNインスタンスに属するかを特定する「VPNラベル（サービスラベル）」の **2段ラベルスタック** を使用して転送が行われます。これにより、コアネットワーク（Pルータ）は顧客のルート情報を知ることなくパケットを転送でき、高いスケーラビリティと柔軟性を実現します。

---

## 🔑 要点

### 1. VRF (Virtual Routing and Forwarding) (3.2.b.i)

各顧客のルーティングテーブルを論理的に分離する仮想的なルータインスタンスです。
*   **分離:** 同じIPアドレス範囲を使用する異なる顧客が、互いに干渉することなく共存できます。
*   **適用:** PEルータの顧客に面したインターフェイス（CE側インターフェイス）にVRFを紐付けます。

### 2. RD (Route Distinguisher) と RT (Route Target) (3.2.b.ii)

VPNv4ルートを制御するための2つの重要な属性です。
*   **RD (8 bytes):** IPv4プレフィックスの先頭に付与され、BGP内での一意性を確保します。これにより、IPv4（32bit）が **VPNv4（96bit）** へと変換されます。
*   **RT (BGP Extended Community):** ルートのインポートおよびエクスポートを制御するポリシー属性です。どのVRFがどの経路を受け取るかを決定します。

### 3. MP-BGP VPNv4/VPNv6 の役割 (3.2.b.ii)

PEルータ間で顧客のルート情報を運ぶための「キャリア」として機能します。
*   **VPNv4 アドレスファミリー:** `address-family vpnv4` を使用してネイバーを確立し、ラベル付きのVPNv4ルートを交換します。
*   **ラベルの配布:** 宛先プレフィックスごとに、PEルータがVPNラベルを割り当てて広報します。

### 4. PE-CE Routing using BGP (3.2.b.i)

PEとCE間でルートを交換する際、BGPを使用する方式です。
*   PEルータ側の `address-family ipv4 vrf [NAME]` 配下でBGPピアリングを構成します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、基本設定に加えて、以下のような高度なトラブルシューティングやパス制御が問われます。

### 1. Route Target ミスマッチの診断

「PE-CE間、PE-PE間でBGPはEstablishedだが、CE側でルートが学習できない」というシナリオが頻出します。
*   **確認点:** エクスポートしたRTと、対向PEでインポートに指定したRTが完全に一致しているか、`show ip bgp vpnv4 all` で確認します。

### 2. BGP AS-Override と Allowas-in

複数の拠点が同じAS番号を使用している場合、BGPのループ防止機能により、自AS番号を含むルートを破棄してしまいます。
*   **対策:** PE側で `neighbor [IP] as-override` を設定してAS番号を書き換えるか、CE側で `neighbor [IP] allowas-in` を設定して受け入れを許可します。

### 3. ルートリーキング (VRF間通信)

特定の共有サービス（DNS, NTP等）を複数のVRFから利用させる設定です。
*   **実装:** RTのインポート/エクスポート設定を工夫し、特定のルートを複数のVRFに注入します。

### 4. BGPパス属性の操作

CEからの受信ルートに対して、LP（Local Preference）やMED、WeightをVRF配下で操作し、特定の拠点へトラフィックを誘導するタスクが想定されます。

---

## 🛠 設定・検証コマンド

### PEルータ：VRFとMP-BGPの基本構成

| 目的 | コマンド |
| :--- | :--- |
| **VRFの作成** | <code>(config)# vrf definition [NAME]</code> |
| **アドレスファミリー有効化** | <code>(config-vrf)# address-family ipv4</code> |
| **RDの設定** | <code>(config-vrf-af)# rd [AS:NN &#124; IP:NN]</code> |
| **RTの設定** | <code>(config-vrf-af)# route-target [export &#124; import &#124; both] [RT_VAL]</code> |
| **IFへのVRF適用** | <code>(config-if)# vrf forwarding [NAME]</code> |
| **PE間 VPNv4 ピア確立** | <code>(config-router)# address-family vpnv4</code> <br> <code>(config-router-af)# neighbor [PE_IP] activate</code> <br> <code>(config-router-af)# neighbor [PE_IP] send-community extended</code> |

### PE-CE BGP設定

| 目的 | コマンド |
| :--- | :--- |
| **VRF配下でのBGP起動** | <code>(config-router)# address-family ipv4 vrf [NAME]</code> |
| **CEとのネイバー設定** | <code>(config-router-af)# neighbor [CE_IP] remote-as [AS]</code> <br> <code>(config-router-af)# neighbor [CE_IP] activate</code> |
| **ASループ防止の回避** | <code>(config-router-af)# neighbor [CE_IP] as-override</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **VPNv4ルート情報の確認** | <code>show ip bgp vpnv4 all [prefix]</code> |
| **VRFルーティングテーブル表示** | <code>show ip route vrf [NAME]</code> |
| **VRFごとのBGPネイバー状態** | <code>show ip bgp vrf [NAME] summary</code> |
| **PE間のVPNv4ピア状態** | <code>show ip bgp vpnv4 all summary</code> |
| **ラベル情報の確認** | <code>show mpls forwarding-table vrf [NAME]</code> |
| **パケットのラベルスタック追跡** | <code>traceroute vrf [NAME] [IP]</code> |

---

## 🧪 ラボ学習・設定サンプル例

**【問題】** 
R1とR4の間で、Loopback0を送信元としてVPNv4ネイバーシップを確立せよ。
**【設定例】**
```ios
! R1
router bgp 1000
 neighbor 4.4.4.4 remote-as 1000
 neighbor 4.4.4.4 update-source Loopback0
 address-family vpnv4
  neighbor 4.4.4.4 activate
  neighbor 4.4.4.4 send-community extended
```

---

### 2. VRF定義とインターフェイス割り当て

**【問題】** 
VRF `Customer_A` を作成し、RD 1000:1、RT 1000:1 (both) を設定して、Gi0/1 に適用せよ。
**【設定例】**
```ios
vrf definition Customer_A
 rd 1000:1
 address-family ipv4
  route-target both 1000:1
!
interface GigabitEthernet0/1
 vrf forwarding Customer_A
 ip address 192.168.1.1 255.255.255.0
```

---

### 3. PE-CE BGP 構成

**【問題】** 
PEルータR1において、VRF `Customer_A` 配下でCEルータR5 (AS 65005) とBGPピアリングを確立せよ。
**【設定例】**
```ios
router bgp 1000
 address-family ipv4 vrf Customer_A
  neighbor 192.168.1.5 remote-as 65005
  neighbor 192.168.1.5 activate
```

---

### 4. AS-Override による同一AS番号拠点の収容

**【問題】** 
支店Aと支店Bが共に AS 65100 を使用している。PEルータにおいて、ルートを破棄せずに伝播させる設定を行え。
**【設定例】**
```ios
router bgp 1000
 address-family ipv4 vrf Customer_A
  neighbor 192.168.1.5 as-override
```

---

### 5. RTインポートによる特定ルートのリーク

**【問題】** 
VRF `Blue` の経路を VRF `Red` でも学習できるように、RT 20:20 を `Red` に追加インポートせよ。
**【設定例】**
```ios
vrf definition Red
 address-family ipv4
  route-target import 20:20  ! BlueのエクスポートRTを指定
```

---

### 6. BGP Default-Originate (PEからCEへ)

**【問題】** 
PEルータから特定のCEルータに対してのみ、VRF配下でデフォルトルートを広報せよ。
**【設定例】**
```ios
router bgp 1000
 address-family ipv4 vrf Customer_A
  neighbor 192.168.1.5 default-originate
```

---

### 7. Export Map を用いた高度な RT 制御

**【問題】** 
特定のプレフィックス (10.1.1.0/24) のみに特別な RT 99:99 を付与してエクスポートせよ。
**【設定例】**
```ios
ip prefix-list PFX_SPECIAL permit 10.1.1.0/24
route-map RM_RT_MAP permit 10
 match ip address prefix-list PFX_SPECIAL
 set extcommunity rt 99:99 additive
!
vrf definition Customer_A
 address-family ipv4
  export map RM_RT_MAP
```

---

### 8. IPv6 VPN (6VPE) の実装

**【問題】** 
PEルータ間で VPNv6 ネイバーを確立し、IPv6 プレフィックスを MPLS 網経由で転送せよ。
**【設定例】**
```ios
router bgp 1000
 address-family vpnv6
  neighbor 4.4.4.4 activate
!
vrf definition Customer_IPv6
 rd 1000:6
 address-family ipv6
  route-target both 1000:6
```

---

### 9. SoO (Site-of-Origin) によるルーティングループ防止

**【問題】** 
マルチホーム接続されたCE拠点で、自身の広報したルートを別経路で再学習しないよう SoO タグ 100:100 を設定せよ。
**【設定例】**
```ios
router bgp 1000
 address-family ipv4 vrf Customer_A
  neighbor 192.168.1.5 soo 100:100
```

---

### 10. VPNv4 ルートのフィルタリング (Prefix-list)

**【問題】** 
特定の PE ルータから送信される VPNv4 ルートのうち、172.16.0.0/16 以外を拒否せよ。
**【設定例】**
```ios
router bgp 1000
 address-family vpnv4
  neighbor 4.4.4.4 prefix-list ACL_ALLOWED_VPN in
```

---

### 11. Maximum-Prefix による VRF 経路数制限

**【問題】** 
CE からの誤設定によるリソース枯渇を防ぐため、VRF `Customer_A` で学習する BGP ルートを最大 100 に制限せよ。
**【設定例】**
```ios
router bgp 1000
 address-family ipv4 vrf Customer_A
  neighbor 192.168.1.5 maximum-prefix 100
```

---

### 12. 2段ラベルの検証

**【問題】** 
パケットが MPLS コアを通過する際、LDP ラベルと VPN ラベルの両方が付与されていることを確認せよ。
**【検証】**
```ios
PE1# show mpls forwarding-table vrf Customer_A 10.10.10.10 detail
! 期待される出力:
! local label: [VPN_LABEL]
! Outgoing Label: [LDP_LABEL]  <-- 2つのラベルがあることを確認
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKCCIE-3000: BGP and Multicast for the CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   L3VPNにおける高度なBGP属性操作と、実技試験での「落とし穴」を解説。
*   [**BRKSP-2005: Deploying MPLS Layer 3 VPNs**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSP-2005)
    *   L3VPNのアーキテクチャ詳細と、PE-CEルーティングオプションの比較。

### Configuration ガイド
*   [**MPLS: Layer 3 VPNs Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-17/mp-l3-vpns-xe-17-book.html)。
*   [**Configuring BGP PE-CE Routing**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book/irg-vpn-routing.html)。

### テクニカルノーツ・設定例
*   [**MPLS Layer 3 VPN Overview and Configuration**](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/13733-mpls-vpn-config.html)。
*   [**Understanding Route Distinguishers and Route Targets (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13733-mpls-vpn-config.html)。

---

## 📝 補足
- この学習メモは、MPLS L3VPN の「制御プレーン（BGP）」と「データプレーン（Label）」、そして「ポリシー（RT）」の相互作用を整理しています。CCIE 実技試験では、特に **VRF 配下での BGP 再配送** や **RT 不一致による疎通不可** の解決が迅速に行えるかどうかが、合格へのクリティカルなスキルとなります。


