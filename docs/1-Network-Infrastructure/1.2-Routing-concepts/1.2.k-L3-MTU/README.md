---
layout: default
title: 1.2.k-L3-MTU
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 11
---

# 1.2.k-L3-MTU

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.k L3 MTU」について整理しました。

---

## 📘 概要

**L3 MTU (Maximum Transmission Unit)** は、IPレイヤにおいて単一のパケット（IPヘッダーとデータを含む）として送信可能な最大サイズ（バイト単位）を定義するパラメータです。

イーサネットの標準的なMTUは1500バイトですが、現代のエンタープライズネットワークではGRE、IPsec、VXLAN、SD-WANといったカプセル化技術（オーバーレイ）の利用が一般的です。これらの技術は追加のヘッダーを付与するため、実質的な有効帯域サイズを減少させます。MTUが適切に管理されていない場合、IPフラグメンテーション（断片化）によるパフォーマンス低下や、PMTUD（Path MTU Discovery）の失敗による「特定のアプリケーション（HTTP等）だけ通信できない」といった複雑なトラブル（ブラックホール問題）の原因となります。

CCIEレベルでは、単一インターフェイスの設定だけでなく、ネットワークパス全体を通じたMTUの一貫性と、TCP MSS（Maximum Segment Size）との相関関係を完全に制御する能力が求められます。

---

## 🔑 要点

### 1. L2 MTU と L3 MTU の違い

CCIEラボ試験において混同しやすいポイントです。
*   **L2 MTU (Interface MTU):** レイヤ2フレーム全体の最大サイズ。`mtu` コマンドで設定。
*   **L3 MTU (IP MTU):** IPパケットの最大サイズ。`ip mtu` コマンドで設定。
*   **関係性:** 一般に `ip mtu` は L2 MTU 以下である必要があります。L2 MTUを1500以上に上げる（Jumbo Frame）場合は、スイッチ全体の `system mtu` 設定が必要になるプラットフォームもあります。

### 2. IPフラグメンテーションとDFビット

*   **フラグメンテーション:** 出力インターフェイスのMTUよりも大きいパケットを転送する際、ルータはパケットを分割して送信します。
*   **DF (Don't Fragment) ビット:** IPヘッダー内のフラグ。これがセットされている場合、ルータはフラグメントを行わず、パケットをドロップしてICMP "Fragmentation Needed" (Type 3, Code 4) を送信元に返します。
*   **PMTUD (Path MTU Discovery):** 送信元ホストがDFビットをセットしてパケットを送り、経路上の最小MTUを動的に把握する仕組みです。

### 3. オーバーレイによるオーバーヘッド

カプセル化技術を使用する際、以下の追加バイトが発生することを考慮し、`ip mtu` を調整する必要があります。

| 技術 | 標準的なオーバーヘッド (IPv4) | 備考 |
| :--- | :--- | :--- |
| **GRE** | 24バイト | IPヘッダー(20) + GREヘッダー(4) |
| **IPsec (ESP)** | 約50〜70バイト | 暗号化アルゴリズムやNAT-Tの有無で変動 |
| **VXLAN** | 50バイト | UDP(8) + VXLAN(8) + Outer IP(20) + Eth(14) |
| **SD-WAN** | 可変 | 複数のトランスポートヘッダーが付与される |

### 4. TCP MSS (Maximum Segment Size)

TCPコネクション開始時のスリーウェイハンドシェイクでネゴシエーションされる「データ部分」の最大サイズです。
*   **MSS = MTU - IPヘッダー(20) - TCPヘッダー(20)**
*   標準的な1500バイトMTUの場合、MSSは1460バイトになります。トンネル環境ではMTUが下がるため、MSSも連動して下げる（MSS Clamping）必要があります。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験において、L3 MTUは「見えない障害」として頻繁に組み込まれます。

### 1. ルーティングプロトコルの隣接関係

*   **OSPF:** 隣接ルータ間でMTUが一致していない場合、ネイバー状態が `EXCHANGE` または `LOADING` で停止します。`ip ospf mtu-ignore` で回避可能ですが、根本的な解決（MTUの一致）が設計上優先されます。
*   **IS-IS:** デフォルトで最大MTUのHelloパケット（Padding）を送り、パスの疎通を確認します。MTU不一致があると隣接関係が確立されません。

### 2. PMTUD ブラックホール問題

ファイアウォールやACLでICMP Type 3 Code 4を遮断している環境では、PMTUDが機能せず、DFビットが立った大きなパケットが静かにドロップされます（Webページが表示されない、SSHが途中で切れる等）。
*   **対策:** 中継ルータで `ip tcp adjust-mss` を設定し、TCPヘッダー内のMSS値を強制的に書き換えることで、ホスト側に小さいパケットを送らせる手法がラボでの定番解決策です。

### 3. SD-Access / SD-WAN における MTU

アンダーレイのMTU（物理ネットワーク）は、オーバーレイ（カプセル化パケット）をフラグメントなしで運ぶために、オーバーヘッド分を見込んで大きく設定（通常1550〜9000バイト）する設計が求められます。

### 4. IPv6 の特性

IPv6では、中継ルータでのフラグメンテーションが禁止されています。送信元ホストのみがフラグメントを行えるため、PMTUDの重要性がIPv4以上に高まります。ラボでは `ipv6 mtu` の設定も問われます。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスMTU設定(L2)** | <code>(config-if)# mtu [値]</code> |
| **IP MTU設定(L3)** | <code>(config-if)# ip mtu [値]</code> |
| **TCP MSS調整設定** | <code>(config-if)# ip tcp adjust-mss [値]</code> |
| **OSPF MTUチェック無視** | <code>(config-if)# ip ospf mtu-ignore</code> |
| **IPv6 MTU設定** | <code>(config-if)# ipv6 mtu [値]</code> |
| **MTUを含む詳細ステータス確認** | <code>show interfaces [interface-id]</code> |
| **現在のIP MTU値のみ確認** | <code>show ip interface [interface-id] &#124; include MTU</code> |
| **DFビットを立てたPing試験** | <code>ping [IP] size [SIZE] df-bit</code> |
| **IPv6でのPing MTU試験** | <code>ping ipv6 [IP] size [SIZE]</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. GRE トンネル環境での最適化
**【問題内容】**
R1とR2の間でGREトンネルを構築している。トンネルインターフェイスは `Tunnel 0`、物理ソースは `GigabitEthernet 1 (MTU 1500)` である。トンネル内でのフラグメンテーションを回避し、かつPMTUDをバイパスするために、適切なMTUとMSSを設定せよ。

**【設定サンプル】**
```ios
interface Tunnel0
 ip address 10.255.1.1 255.255.255.252
 tunnel source GigabitEthernet1
 tunnel destination 192.168.1.2
 ! GRE(24バイト)を考慮し、1500-24 = 1476に設定
 ip mtu 1476
 ! TCPヘッダー(20)とIPヘッダー(20)をさらに引き、1476-40 = 1436に設定
 ip tcp adjust-mss 1436
```

---

### 2. OSPF MTU 不一致のトラブルシューティング

**【問題内容】**
R3とR4のOSPFネイバーが `EXCHANGE` 状態で止まっている。調査の結果、R3のMTUが1500、R4のMTUが1450であることが判明した。設定変更が許されるのはR4のみであり、かつMTU値自体は変更してはならないという制約がある場合、隣接関係を確立させよ。

**【設定サンプル】**
```ios
! R4側でのみ設定
interface GigabitEthernet0/1
 ! 相手側の大きなMTUパケット(LSA)を受け入れるようにチェックをスキップさせる
 ip ospf mtu-ignore
```
**【検証】**
`show ip ospf neighbor` を実行し、状態が `FULL` に遷移することを確認します。

---

### 3. PMTUD ブラックホールの特定

**【問題内容】**
クライアントからインターネット上の特定のWebサイト（ポート80）にアクセスできない。Pingは通るが、ブラウザでの閲覧に失敗する。中継ルータR5でこの問題を特定し、TCP MSS調整で解決せよ。

**【設定サンプル】**
```ios
! 調査: DFビットを立ててパケットを送ってみる
R5# ping 8.8.8.8 size 1500 df-bit
! 失敗する場合、MTU問題の可能性大。サイズを下げて確認。
R5# ping 8.8.8.8 size 1400 df-bit
! 成功する場合、中継路のどこかに1400未満のMTUがある。

! 解決策: 外部へ向かうインターフェイスに着信/発信するTCP SYNを書き換える
interface GigabitEthernet0/0
 ip tcp adjust-mss 1360
```

---

### 4. IPv6 環境での MTU 管理

**【問題内容】**
IPv6ネットワークにおいて、リンクMTUが異なるセグメント間で通信を最適化せよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ipv6 address 2001:DB8:ACAD:1::1/64
 ! IPv6の最小MTUは1280バイト
 ipv6 mtu 1400
 ! IPv6 TCP MSSの調整（IPv6ヘッダーは40バイト）
 ! 1400 - 40(IPv6) - 20(TCP) = 1340
 ipv6 tcp adjust-mss 1340
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: Protocol-Independent Configuration Guide - MTU (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book.html)
*   [IPv6 Maximum Transmission Unit (Cisco Support)](https://www.cisco.com/c/ja_jp/support/docs/ip/ip-version-6-ipv6/113328-ipv6-static-00.html)

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols (MTU mismatch深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKENS-2031: Enterprise Campus Design (Jumbo Frame設計)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)

### テクニカルドキュメント・設定例
*   [Resolve IP MTU, MSS, and Fragmentation Issues with IPsec and GRE](https://www.cisco.com/c/en/us/support/docs/ip/generic-routing-encapsulation-gre/25885-pmtud-ipsec-gre.html)
*   [OSPF Neighbors Stuck in Exchange/Loading State due to MTU](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13697-14.html)

---


## 📝 補足
- この学習メモは、CCIE EI実技試験において「論理的には正しい設定なのになぜかデータが流れない」という事態に直面した際、物理的なリンク制約とL3パケットサイズの不整合を即座に特定・修正するための指針となります。特にトンネル構成時の `ip tcp adjust-mss` は、合否を分ける非常に重要なコマンドです。

