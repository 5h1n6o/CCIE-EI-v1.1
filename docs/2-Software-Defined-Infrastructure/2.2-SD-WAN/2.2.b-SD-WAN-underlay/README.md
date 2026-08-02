---
layout: default
title: 2.2.b-SD-WAN-underlay
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 2
---

# 2.2.b Cisco SD-WAN Underlay

Cisco SD-WAN（Viptela）アーキテクチャにおいて、**Underlay（アンダーレイ）** はオーバーレイネットワーク（論理的なVPN）が動作するための土台となる物理的な輸送インフラです。CCIE EI v1.1 ラボ試験において、アンダーレイの構築は「Day-0/Day-1 オペレーション」として、すべての機能が動作するための前提条件となります。

---

## 📘 概要

**SD-WAN Underlay** は、WAN Edge（cEdge/vEdge）デバイスとコントローラ（vBond, vManage, vSmart）間、および WAN Edge デバイス相互間の物理的な到達性を提供します。SD-WAN において、アンダーレイの設定は主に **VPN 0 (Transport VPN)** で行われます。

この層の目的は、複雑なルーティングを行うことではなく、**コントロールコネクション（DTLS/TLS）** および **データプレーン（IPsec）トンネル** を確立するための IP 到達性を確保することにあります。アンダーレイは、パブリックインターネット、MPLS、4G/5G LTE、あるいはクラウド内の仮想ネットワークなど、多様なトランスポートメディアで構成されます。

---

## 🔑 要点

### 1. WAN Cloud Edge Deployment (i)

AWS, Azure, Google Cloud などのパブリッククラウドに WAN Edge をデプロイします。
*   **仮想アプライアンス:** vEdge Cloud または Catalyst 8000V (cEdge) が使用されます。
*   **特徴:** クラウド内の VPC/VNET ゲートウェイとして機能し、オンプレミスの拠点とクラウドをシームレスに接続します。

### 2. WAN Edge Deployment (ii)

物理的なハードウェア（cEdge: ISR/Catalyst 8k, vEdge）のオンボーディングです。
*   **cEdge:** Cisco IOS-XE ベースで、従来のルータの機能と SD-WAN の機能を統合しています。
*   **vEdge:** 元の Viptela OS を搭載した専用アプライアンスです。

### 3. Greenfield, Brownfield, and Hybrid (iii)

*   **Greenfield:** 完全に新規の SD-WAN 環境の構築。
*   **Brownfield:** 既存のレガシー WAN と SD-WAN を共存・移行させるフェーズ。
*   **Hybrid:** MPLS とインターネットなど、異なるトランスポートを組み合わせて使用する形態。

### 4. System Configuration (iv)

デバイスのアイデンティティを定義する、最も重要な初期設定です。
*   **System IP:** デバイス固有の 32 ビット識別子（Router-ID 相当）。トランスポートの IP が変わっても不変です。
*   **Site ID:** デバイスが所属する物理的な場所。同じサイト内でのデータプレーン形成（ハブ・アンド・スポーク等）に影響します。
*   **Organization Name:** 組織名。すべてのコントローラとエッジで一分一言違わず一致する必要があります。証明書認証の鍵となります。
*   **vBond Address:** 最初にコンタクトを取るオーケストレーターの IP または FQDN です。

### 5. Transport Configuration (v)

VPN 0 におけるトランスポートの設定です。
*   **Color:** リンクの特性を示すタグ（mpls, public-internet, silver 等）。パス選定ポリシーで使用されます。
*   **Allowed Services:** トンネルインターフェイス上で許可する管理プロトコル（ssh, snmp, bgp, icmp 等）。
*   **TLOC Extension:** 同一サイト内の 2 台のデバイス間で物理リンクを共有し、お互いのトランスポート回線を利用可能にする冗長化手法です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、アンダーレイの「不整合」による接続不可を解決する能力が問われます。

### 1. 認証の失敗（Certificate/Org-Name）

*   **トラブル:** エッジが vManage に現れない。
*   **原因:** Organization-Name のスペルミス、あるいは NTP 同期が取れておらず証明書が失効したと判断されているケースが頻出します。
*   **確認:** `show control connections` でセッションが "up" でない場合、`show control local-properties` を確認してください。

### 2. アンダーレイのルーティング到達性

*   **シナリオ:** コントローラへの到達にスタティックルートや動的ルーティング（BGP/OSPF）が必要。
*   **対策:** VPN 0 内でデフォルトルートを適切に設定し、`tunnel-interface` 配下で `encapsulation ipsec` が有効であることを確認します。

### 3. TLOC Extension の構成

*   **要件:** 「R1 のインターネット回線を R2 からも利用できるようにせよ」。
*   **実装:** R1 と R2 を物理リンクで繋ぎ、R1 側で `tloc-extension` インターフェイスを構成、R2 側ではそのリンクを `vpn 0` のインターフェイスとして定義します。

### 4. 許可サービス (Allow Services) の制御

*   **セキュリティ要件:** 「WAN 経由での BGP ピアリングのみを許可し、HTTPS ログインを禁止せよ」。
*   **設定:** `vpn 0` -> `interface` -> `tunnel-interface` -> `allow-service bgp` かつ `no allow-service https` を Feature Template または CLI で指定します。

---

## 🛠 設定・検証コマンド

### システム初期化・初期設定

| 目的 | コマンド |
| :--- | :--- |
| **システム設定(基本)** | <code>system</code> <br> <code>system-ip [IP]</code> <br> <code>site-id [ID]</code> <br> <code>organization-name [NAME]</code> <br> <code>vbond [IP_OR_FQDN]</code> |
| **cEdge 初期化（コントローラ）** | <code>controller</code> <br> <code>vbond [IP]</code> <br> <code>org [NAME]</code> |

### トランスポート (VPN 0) 設定

| 目的 | コマンド |
| :--- | :--- |
| **トランスポート VPN 定義** | <code>vpn 0</code> |
| **トンネルインターフェイスの有効化** | <code>interface [ID]</code> <br> <code>tunnel-interface</code> |
| **Color とカプセル化の設定** | <code>color [COLOR_NAME]</code> <br> <code>encapsulation ipsec</code> |
| **管理サービスの許可** | <code>allow-service [ssh&#124;https&#124;bgp&#124;all]</code> |
| **アンダーレイ用スタティックルート** | <code>ip route 0.0.0.0 0.0.0.0 [NEXT_HOP]</code> |

### 検証・デバッグ

| 目的 | コマンド |
| :--- | :--- |
| **コントロールコネクション確認** | <code>show control connections</code> |
| **ローカル属性(証明書/状態)確認** | <code>show control local-properties</code> |
| **トンネル状態(BFD)の確認** | <code>show bfd sessions</code> |
| **TLOC情報の確認** | <code>show omp tlocs</code> |
| **トランスポートインターフェイス確認** | <code>show interface vpn 0</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. vEdge クラウドの基本システム設定

**【問題内容】** ホスト名 `BR1-vE1`、System-IP `10.1.1.11`、Site-ID `11`、組織名 `micronicslab.com` で構成せよ。
```ios
system
 host-name BR1-vE1
 system-ip 10.1.1.11
 site-id 11
 organization-name micronicslab.com
 vbond 192.1.255.102
!
```

---

### 2. cEdge (CSR1000v) のコントローラ指定

**【問題内容】** CSR1000v を SD-WAN モードで起動し、vBond を指定せよ。
```ios
controller
 vbond 192.1.255.102
 organization-name micronicslab.com
```

---

### 3. MPLS 回線用トンネルインターフェイスの設定

**【問題内容】** インターフェイス `ge0/0` を Color `mpls` のトンネルとして構成せよ。
```ios
vpn 0
 interface ge0/0
  ip address 192.168.1.2/30
  tunnel-interface
   color mpls
   encapsulation ipsec
  no shutdown
```

---

### 4. インターネット回線での NAT Traversal 設定

**【問題内容】** `ge0/1` を `public-internet` とし、vManage との通信のため SSH を許可せよ。
```ios
vpn 0
 interface ge0/1
  tunnel-interface
   color public-internet
   encapsulation ipsec
   allow-service ssh
  no shutdown
```

---

### 5. アンダーレイのデフォルトゲートウェイ設定

**【問題内容】** VPN 0 のネクストホップとして 199.1.1.30 を指定せよ。
```ios
vpn 0
 ip route 0.0.0.0 0.0.0.0 199.1.1.30
```

---

### 6. 管理用 VPN 512 の構成

**【問題内容】** OOB 管理用インターフェイス `eth0` を VPN 512 で構成せよ。
```ios
vpn 512
 interface eth0
  ip address 10.82.83.121/24
  no shutdown
```

---

### 7. TLOC Extension による物理リンク共有

**【問題内容】** `ge0/2` を使用して、隣接するエッジへのトランスポート拡張を有効化せよ。
```ios
vpn 0
 interface ge0/2
  tloc-extension ge0/0  ! ge0/0の物理回線をge0/2経由で貸し出す
  no shutdown
```

---

### 8. 特定サービス（BGP）のトンネル通過許可

**【問題内容】** トンネル上で BGP ピアリングの制御トラフィックのみを許可せよ。
```ios
vpn 0
 interface ge0/0
  tunnel-interface
   allow-service bgp
   no allow-service https
   no allow-service snmp
```

---

### 9. MTU サイズの調整（フラグメンテーション防止）

**【問題内容】** トンネルインターフェイスの IP MTU を 1496 に設定せよ。
```ios
vpn 0
 interface ge0/0
  mtu 1496
```

---

### 10. トランスポート回線の帯域幅制限設定 (Downstream)

**【問題内容】** インターネット回線のダウンロード帯域を 100Mbps に制限せよ（QoS の基礎）。
```ios
vpn 0
 interface ge0/1
  bandwidth-downstream 100000
```

---

### 11. NTP 同期設定による証明書エラーの回避

**【問題内容】** 時刻不整合を防ぐため、10.1.1.100 を NTP サーバとして指定せよ。
```ios
system
 ntp
  server 10.1.1.100 version 4
```

---

### 12. 複数の TLOC（Color）によるマルチトランスポート構成

**【問題内容】** 1 台のルータで MPLS と Biz-Internet の両方を同時に有効化せよ。
```ios
vpn 0
 interface ge0/0
  tunnel-interface
   color mpls
 !
 interface ge0/1
  tunnel-interface
   color biz-internet
```

---

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

