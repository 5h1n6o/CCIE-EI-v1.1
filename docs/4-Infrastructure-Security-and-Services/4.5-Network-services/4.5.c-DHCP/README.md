---
layout: default
title: 4.5.c-DHCP
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.5.c DHCP on Cisco devices

本稿では、ネットワークにおける IP アドレス動的割り当ての要である **DHCP (Dynamic Host Configuration Protocol)** について、Cisco IOS XE デバイスにおける実装と、CCIE EI 試験で求められる高度な設計・トラブルシューティング能力に焦点を当てて解説します。

---

## 📘 概要

**DHCP** は、クライアントに対して IP アドレス、サブネットマスク、デフォルトゲートウェイ、DNS サーバーなどのネットワークパラメータを自動的に提供するプロトコルです。

*   **IPv4 DHCP:** 4 段階のやり取り（DORA：Discover, Offer, Request, Acknowledgment）を通じてアドレスを割り当てます。
*   **IPv6 DHCPv6:** IPv6 の近隣探索プロトコル（NDP）やステートレスアドレス自動設定（SLAAC）と密接に連携し、ステートフル（アドレス配布あり）またはステートレス（オプション情報のみ配布）のモードで動作します。

CCIE ラボ試験では、単一セグメントでの配布にとどまらず、**DHCP Relay** を用いた複数セグメント・複数 VRF を跨ぐ構成や、**DHCPv6 Prefix Delegation (PD)** を利用した階層的なアドレス設計が頻出します。

---

## 🔑 要点

### 1. DHCP の役割 (i)

*   **Server:** アドレスプールを管理し、リクエストに応じてリースを提供します。
*   **Client:** デバイスが自身のインターフェイスに動的にアドレスを取得します。
*   **Relay Agent:** クライアントからのブロードキャスト（IPv4）またはマルチキャスト（IPv6）の DHCP 要求をユニキャストに変換し、遠隔地のサーバーへ転送します。

### 2. DHCP オプション (ii)

標準のパラメータ以外に、特定のアプリケーションに必要な情報を配布します。
*   **Option 43:** 無線 LAN コントローラ (WLC) の IP アドレス。
*   **Option 67:** ブートファイル名（PXE 起動用）。
*   **Option 150:** TFTP サーバーの IP アドレス（IP 電話用）。
*   **Option 82:** リレーエージェント情報（セキュリティや回線特定の識別に使用）。

### 3. IPv6 SLAAC と DHCPv6 の統合 (iii, iv)

IPv6 ではルータ広告（RA）内のフラグによって、クライアントがどのようにアドレスを取得するかを決定します。
*   **SLAAC:** RA のプレフィックス情報からクライアントが自身で生成。DHCP サーバー不要。
*   **Stateless DHCPv6:** アドレスは SLAAC で取得し、DNS 等の「その他」の情報を DHCPv6 から取得（RA の **O-flag** を 1 に設定）。
*   **Stateful DHCPv6:** アドレスおよび全情報を DHCPv6 サーバーが管理（RA の **M-flag** を 1 に設定）。

### 4. DHCPv6 Prefix Delegation (PD) (v)

ISP からルータに対し、個別の IP ではなく「プレフィックス（ネットワークの塊）」を配布する仕組みです。
*   受け取ったルータは、そのプレフィックスをさらに細分化（サブネット化）して、自身の LAN 側インターフェイスに自動的に割り当てることができます。

---

## 🎯 試験対策 (CCIE EIレベル)

### 1. リレーエージェントと VRF の整合性

ラボ試験では、DHCP サーバーが管理用 VRF に存在し、クライアントがサービス用 VRF に存在するといった複雑な構成が出題されます。
*   **対策:** `ip helper-address` に `global` や `vrf` キーワードを正しく付与し、ルーティングが確保されていることを確認する能力が必要です。

### 2. RA フラグの正確な操作

「IPv6 アドレスは SLAAC で生成させ、ドメイン名と DNS サーバー情報のみを DHCPv6 から提供せよ」という要件に対し、どのインターフェイスで `ipv6 nd other-config-flag` を叩くべきかを即座に判断できる必要があります。

### 3. Prefix Delegation の階層設計

ISP（サーバー役）から企業拠点（クライアント役）へ `/48` や `/56` のプレフィックスを渡し、拠点のルータがそれを `/64` に分割して各 VLAN に適用する一連の設定（`ipv6 local pool` と `ipv6 address pool` の連携）が問われます。

### 4. 競合（Conflict）と除外アドレス

配布済みのアドレスと重複が発生した場合、Cisco デバイスはデフォルトで検出を試みますが、試験では事前に `ip dhcp excluded-address` でゲートウェイ等の静的 IP を除外しておくことが必須の「マナー」として評価されます。

---

## 🛠 設定・検証コマンド

### IPv4 DHCP 設定

| 目的 | コマンド |
| :--- | :--- |
| **除外アドレス設定** | <code>ip dhcp excluded-address [START_IP] [END_IP]</code> |
| **DHCPプールの作成** | <code>ip dhcp pool [NAME]</code> |
| **ネットワークの定義** | <code>network [NETWORK_ADDR] [MASK]</code> |
| **ゲートウェイの設定** | <code>default-router [IP]</code> |
| **DNSサーバーの設定** | <code>dns-server [IP1] [IP2]</code> |
| **TFTPオプションの設定** | <code>option 150 ip [IP]</code> |
| **リレーエージェント設定** | <code>(config-if)# ip helper-address [SERVER_IP]</code> |

### IPv6 DHCPv6 設定

| 目的 | コマンド |
| :--- | :--- |
| **DHCPv6プールの作成** | <code>ipv6 dhcp pool [NAME]</code> |
| **配布プレフィックス定義** | <code>address prefix [PREFIX/LEN]</code> |
| **ステートレス用フラグ(RA)** | <code>(config-if)# ipv6 nd other-config-flag</code> |
| **ステートフル用フラグ(RA)** | <code>(config-if)# ipv6 nd managed-config-flag</code> |
| **PD用ローカルプール作成** | <code>ipv6 local pool [NAME] [PREFIX/LEN] [ASSIGN_LEN]</code> |
| **DHCPv6リレー設定** | <code>(config-if)# ipv6 dhcp relay destination [SERVER_V6]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **IPv4リース情報の確認** | <code>show ip dhcp binding</code> |
| **IPv4プール統計の表示** | <code>show ip dhcp pool</code> |
| **IPv6リース情報の確認** | <code>show ipv6 dhcp binding</code> |
| **IPv6 PD 取得状況の確認** | <code>show ipv6 dhcp interface</code> |
| **DHCPプロセスのデバッグ** | <code>debug ip dhcp server [events&#124;packet]</code> |
| **DHCPリレー統計の確認** | <code>show ip helper-address</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. IPv4 DHCP サーバーの基本構成

**【課題】** VLAN 10 用に 192.168.10.0/24 のプールを作成し、最初の 10 アドレスを除外せよ。
```ios
ip dhcp excluded-address 192.168.10.1 192.168.10.10
!
ip dhcp pool VLAN10_POOL
 network 192.168.10.0 255.255.255.0
 default-router 192.168.10.1
 dns-server 8.8.8.8
```

### 2. 特定の MAC アドレスへの固定割り当て

**【課題】** サーバー (MAC: aaaa.bbbb.cccc) に対して 10.1.1.100 を常に割り当てよ。
```ios
ip dhcp pool STATIC_SRV
 host 10.1.1.100 255.255.255.0
 client-identifier 01aa.aabb.bbcc.cc  ! 01 + MAC
 ! または
 hardware-address aaaa.bbbb.cccc
```

### 3. DHCP リレーエージェントの実装

**【課題】** クライアントのいる VLAN 100 インターフェイスで、10.1.1.50 の DHCP サーバーへリクエストを転送せよ。
```ios
interface Vlan100
 ip address 172.16.100.1 255.255.255.0
 ip helper-address 10.1.1.50
```

### 4. DHCP オプション 150 (VoIP) の配布

**【課題】** IP 電話用に TFTP サーバーの IP 10.20.1.1 を配布せよ。
```ios
ip dhcp pool VOICE_POOL
 network 172.20.1.0 255.255.255.0
 option 150 ip 10.20.1.1
```

### 5. SLAAC による IPv6 アドレス取得 (Client)

**【課題】** R3 の Gi0/1 インターフェイスで、RA を受信して自動的に IPv6 アドレスを生成せよ。
```ios
interface GigabitEthernet0/1
 ipv6 address autoconfig default
 ! defaultキーワードでRAからデフォルトルートも生成
```

### 6. Stateless DHCPv6 の実装

**【課題】** SLAAC でアドレスを生成させ、DNS 情報のみを DHCPv6 から取得するよう設定せよ。
```ios
! Server側
ipv6 dhcp pool OPT_ONLY
 dns-server 2001:4860:4860::8888
!
! Interface側
interface Gi0/2
 ipv6 nd other-config-flag
 ipv6 dhcp server OPT_ONLY
```

### 7. Stateful DHCPv6 サーバーの構成

**【課題】** SLAAC を禁止し、DHCPv6 サーバーからアドレスを完全に管理配布せよ。
```ios
ipv6 dhcp pool STATEFUL_POOL
 address prefix 2001:DB8:A:A::/64
!
interface Gi0/0
 ipv6 nd managed-config-flag
 ipv6 nd prefix 2001:DB8:A:A::/64 no-autoconfig
 ipv6 dhcp server STATEFUL_POOL
```

### 8. DHCPv6 リレーエージェントの設定

**【課題】** IPv6 クライアントからの要求を 2001:DB8::1 のサーバーへリレーせよ。
```ios
interface Ethernet0/1
 ipv6 dhcp relay destination 2001:DB8::1
```

### 9. DHCPv6 Prefix Delegation (PD) - Server

**【課題】** ローカルプール `CLIENT-PDS` からプレフィックスをクライアントへ配布せよ。
```ios
ipv6 local pool MY-POOL 2001:DB8:CCIE::/48 56
!
ipv6 dhcp pool PD-SERVER
 prefix-delegation pool MY-POOL
!
interface Gi0/1
 ipv6 dhcp server PD-SERVER
```

### 10. DHCPv6 Prefix Delegation (PD) - Client

**【課題】** 上位から PD でプレフィックスを受け取り、自身の LAN 側 IF (Gi0/2) に適用せよ。
```ios
interface GigabitEthernet0/1  ! WAN側
 ipv6 dhcp client pd FROM-ISP
!
interface GigabitEthernet0/2  ! LAN側
 ipv6 address FROM-ISP ::1/64
```

### 11. DHCP サーバーと VRF の連携

**【課題】** VRF `RED` に属するプールを作成し、インターフェイスでのリレーを構成せよ。
```ios
ip dhcp pool VRF_RED_POOL
 vrf RED
 network 10.1.1.0 255.255.255.0
!
interface Gi0/1
 vrf forwarding RED
 ip helper-address 10.5.5.5
```

### 12. DHCP トラブルシューティングの実践

**【シナリオ】** クライアントがアドレスを取得できない。サーバーのプロセスを確認せよ。
```ios
! 手順
1. show ip dhcp binding でリース状況確認
2. show ip dhcp pool で枯渇を確認
3. debug ip dhcp server events でリクエストが届いているか確認
```

---

## 🔗 参考リンク

### Cisco Live 関連動画・スライド
*   [**BRKCCIE-3000: CCIE EI Lab Exam Overview**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - インフラサービスの重要性。
*   [**BRKRST-3320: IPv6 Planning, Deployment and Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - DHCPv6 と SLAAC の詳細設計。

### Configuration ガイド
*   [**IP Addressing: DHCP Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_dhcp/configuration/xe-17/dhcp-xe-17-book.html)。
*   [**IPv6 Addressing and Basic Connectivity Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipv6/configuration/xe-17/ipv6-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Understanding DHCP Option 82 (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/dynamic-host-configuration-protocol-dhcp/119134-technote-dhcp-00.html)。
*   [**IPv6 Stateful and Stateless DHCPv6 Configuration Example**](https://www.cisco.com/c/en/us/support/docs/ip/ip-address-assignment/113110-dhcpv6-config-example.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験において **DHCP が単なるアドレス配布ではなく、IPv6 の設計思想や VRF の分離、さらには管理自動化（ZTP等）の根幹** であることを示しています。各モードのフラグ管理とリレーの挙動を、実際のパケットフローをイメージしながら習得することが合格への鍵となります。


