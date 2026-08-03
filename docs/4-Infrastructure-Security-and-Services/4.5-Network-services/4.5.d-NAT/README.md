---
layout: default
title: 4.5.d-NAT
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 4
---

# 4.5.d IPv4 Network Address Translation (NAT)

IPv4 アドレスの枯渇対策およびセキュリティ境界の形成において、NAT はエンタープライズネットワークの基盤となる技術です。CCIE Enterprise Infrastructure (EI) v1.1 では、単純なアドレス変換のみならず、VRF やポリシー、仮想インターフェイス（VASI）を組み合わせた高度な実装能力が求められます。

---

## 📘 概要

**Network Address Translation (NAT)** は、IP パケットヘッダー内の送信元または宛先 IP アドレスを書き換えるプロセスです。主に、プライベート IPv4 アドレスをグローバル IPv4 アドレスに変換してインターネット接続を可能にしたり、重複するネットワークセグメント間を接続したりするために使用されます。

CCIE EI レベルでは、単一のグローバルアドレスを複数の内部ホストで共有する **PAT (Port Address Translation / Overload)**、特定の VRF インスタンスに閉じた変換を行う **VRF-aware NAT**、そして物理的な接続なしに VRF 間で変換を行う **VASI NAT** といった、複雑なルーティング環境における変換技術の習得が不可欠です。

---

## 🔑 要点

### 1. NAT の基本用語

*   **Inside Local:** 内部ネットワーク上のホストに割り当てられた実際の IP。
*   **Inside Global:** 外部から見た、内部ホストを識別するための合法的な IP。
*   **Outside Local:** 内部ホストから見た、外部ホストの IP。
*   **Outside Global:** 外部ネットワーク上のホストに割り当てられた実際の IP。

### 2. 技術区分

*   **Static NAT/PAT (i):** 内部と外部のアドレスを 1 対 1 で固定的にマッピングします。サーバーの公開に使用されます。
*   **Dynamic NAT/PAT (ii):** 利用可能なアドレスプールから動的にマッピングを生成します。`overload` キーワードを使用する PAT が一般的です。
*   **Policy-based NAT (iii):** 単純な送信元 ACL ではなく、宛先やポートなどの条件を含む `route-map` を使用して変換の実行可否を決定します。
*   **VRF-aware NAT (iv):** 特定の VRF ルーティングテーブルに属するパケットに対して変換を行います。
*   **VASI NAT (v):** **VRF-Aware Software Infrastructure**。ルータ内部の仮想インターフェイス（vasileft / vasiright）を使用して、物理的なループバックなしで異なる VRF 間の通信と NAT を実現します。

---

## 🎯 試験対策 (CCIE EIレベル)

### 1. 処理順序 (Order of Operations)

ラボ試験でのトラブルシューティングにおいて、NAT とルーティングのどちらが先に行われるかの理解は必須です。
*   **Inside to Outside:** ルーティングが先に行われ、その後に NAT 変換が実行されます。
*   **Outside to Inside:** NAT 変換が先に行われ、その後にルーティングが実行されます。

### 2. SD-WAN 連携

cEdge (IOS XE) 環境では、VPN 0 (Transport) インターフェイスで NAT を有効にすることで、サービス VPN からの **Direct Internet Access (DIA)** を実現するタスクが出題されます。

### 3. VASI NAT のユースケース

「共有サービス VRF」から各「顧客 VRF」へ通信させる際、IP アドレスの重複を解決するために VASI が指定されることがあります。設定には、同一デバイス内で `interface vasileft` と `interface vasiright` をペアリングする独特の構文が必要です。

### 4. 複数プールの使い分け

特定の宛先（例：VPN 経由）へ行くトラフィックには NAT をせず、インターネットへ行くトラフィックには PAT を適用するといった、`route-map` による精密な制御が問われます。

---

## 🛠 設定・検証コマンド

### NAT 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Static NAT (1:1)** | <code>ip nat inside source static [LOCAL_IP] [GLOBAL_IP]</code> |
| **Static PAT (Port)** | <code>ip nat inside source static [tcp&#124;udp] [LOCAL_IP] [L_PORT] [GLOBAL_IP] [G_PORT]</code> |
| **NAT プールの定義** | <code>ip nat pool [NAME] [START_IP] [END_IP] netmask [MASK]</code> |
| **Dynamic PAT (Overload)** | <code>ip nat inside source list [ACL] interface [INT] overload</code> |
| **Policy NAT (Route-map)** | <code>ip nat inside source route-map [MAP_NAME] pool [POOL_NAME] [overload]</code> |
| **VASI インターフェイス設定** | <code>interface vasileft [ID]</code><br><code>interface vasiright [ID]</code> |
| **インターフェイスの役割** | <code>(config-if)# ip nat inside</code> / <code>ip nat outside</code> |

### 検証・統計コマンド

| 目的 | コマンド |
| :--- | :--- |
| **変換テーブルの表示** | <code>show ip nat translations [verbose]</code> |
| **NAT 動作統計の確認** | <code>show ip nat statistics</code> |
| **変換テーブルのクリア** | <code>clear ip nat translation *</code> |
| **リアルタイムデバッグ** | <code>debug ip nat [detailed]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な Dynamic PAT (Overload)

**【課題】** ACL 102 で許可された内部セグメント 192.168.1.0/24 を、プール `POOL2` のアドレスを使用して PAT せよ。
```ios
ip nat pool POOL2 192.1.10.11 192.1.10.12 netmask 255.255.255.0
access-list 102 permit ip 192.168.1.0 0.0.0.255 any
ip nat inside source list 102 pool POOL2 overload
```

### 2. 特定ポートの外部公開 (Static PAT)

**【課題】** 内部ホスト 192.168.4.1 の TCP/80 (Web) を、外部 IP 192.1.10.25 の TCP/80 として公開せよ。
```ios
ip nat inside source static tcp 192.168.4.1 80 192.1.10.25 80
```

### 3. IPsec トラフィック用の Static PAT

**【課題】** NAT 越しに IPsec VPN を確立するため、UDP 500 と 4500 を固定変換せよ。
```ios
ip nat inside source static udp 192.168.24.24 500 192.168.76.6 500 extendable
ip nat inside source static udp 192.168.24.24 4500 192.168.76.6 4500 extendable
```

### 4. Route-map を使用した Policy NAT

**【課題】** R2 宛のトラフィックのみ、プール `POOL` を使用して変換せよ。
```ios
ip access-list extended fromR2
 permit ip host 10.1.108.2 any
!
route-map fromR2 permit 10
 match ip address fromR2
!
ip nat inside source route-map fromR2 pool POOL
```

### 5. 送信元と宛先の同時変換 (Double NAT)

**【課題】** 内部 10.1.108.1 を 100.1.68.50 に変換し、かつ外部 100.1.68.6 を内部 10.1.108.50 として見せよ。
```ios
ip nat inside source static 10.1.108.1 100.1.68.50
ip nat outside source static 100.1.68.6 10.1.108.50
```

### 6. SD-WAN cEdge における NAT 有効化 (DIA)

**【課題】** VPN 0 の外部インターフェイスで NAT (PAT) を有効化し、内部からの直接インターネットアクセスを許可せよ。
```ios
interface GigabitEthernet1
 ip nat outside
! vManage テンプレート上では "NAT: On" を設定する
```

### 7. VASI による VRF 間通信と変換

**【課題】** VRF `BLUE` から VRF `RED` への通信を VASI インターフェイス経由で NAT せよ。
```ios
interface vasileft 1
 vrf forwarding BLUE
 ip address 10.1.1.1 255.255.255.0
 ip nat inside
!
interface vasiright 1
 vrf forwarding RED
 ip address 10.1.1.2 255.255.255.0
 ip nat outside
```

### 8. アドレス重複解決のための Static NAT

**【課題】** 重複が発生しているホスト 10.1.79.7 を、外部からは 100.1.69.20 として通信可能にせよ。
```ios
ip nat inside source static 10.1.79.7 100.1.69.20
```

### 9. インターフェイス IP を利用した PAT (Pool なし)

**【課題】** プールを作成せず、外部インターフェイス Gi0/0 の IP をそのまま利用して PAT せよ。
```ios
ip nat inside source list 1 interface GigabitEthernet0/0 overload
```

### 10. NAT 統計のトラブルシューティング

**【操作例】** 設定した NAT が正しくヒットしているか、ドロップがないかを確認せよ。
```ios
# show ip nat statistics
! 期待される確認項目: "Hits", "Misses", "Expired translations"
```

---

## 🔗 参考リンク

### Cisco Live 関連動画・スライド
*   [**BRKSEC-2001: Next-Generation NAT in IOS-XE**](https://www.ciscolive.com/global/on-demand-library.html?search=NAT)
*   [**BRKCCIE-3000: CCIE EI Lab Exam Overview - Infrastructure Services Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### Configuration ガイド
*   [**Cisco IOS XE 17.x: IP Addressing: NAT Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_nat/configuration/xe-17/nat-xe-17-book.html)
*   [**Configuring VRF-Aware Software Infrastructure (VASI)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_nat/configuration/xe-16/nat-xe-16-book/iadnat-vrf-aware.html)

### テクニカルドキュメント・設定例
*   [**NAT Order of Operations (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/network-address-translation-nat/13772-12.html)
*   [**Static NAT/PAT and Dynamic NAT/PAT Comparison and Configuration**](https://www.cisco.com/c/en/us/support/docs/ip/network-address-translation-nat/iadnat-addr-consv.html)

---

## 📝 補足
- このメモは、CCIE EI 試験における IPv4 NAT の「ルーティングとの整合性」と「VRF 境界での振る舞い」を重点的に整理しています。特に **VASI NAT** はラボ試験で指定される可能性がある高度なトピックであるため、仮想ペアインターフェイスの概念を確実に理解してください。


