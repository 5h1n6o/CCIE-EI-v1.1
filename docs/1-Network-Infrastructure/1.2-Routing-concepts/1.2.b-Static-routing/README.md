---
layout: default
title: 1.2.b-Static-routing
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.2.b Static routing (unicast, multicast)

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.b Static routing (unicast, multicast)」について、提供されたソース資料（iPexpert, INE, Cisco Press等）に基づき、ラボ試験合格に必要な深さで詳細に整理しました。

---

## 📘 概要

スタティックルーティングは、管理者がルータのルーティングテーブルに手動で経路情報を登録する手法です。動的ルーティングプロトコル（OSPFやEIGRP等）と比較して、CPUリソースの消費が極めて少なく、帯域幅を消費するアップデートのやり取りも発生しません。

CCIEレベルの実装では、単なるデフォルトルートの構成にとどまらず、**ユニキャスト**における「信頼性の高い静的ルーティング（Reliable Static Routing）」や、**マルチキャスト**における「RPF（Reverse Path Forwarding）チェックのバイパス」といった高度な構成が求められます。特に複雑なトポロジーにおいて、動的プロトコルが最適パスを選択できない場合や、バックアップパスとして浮動静的ルート（Floating Static Route）を維持する場合に不可欠な技術です。

---

## 🔑 要点

### 1. ユニキャストスタティックルートの特性

*   **アドミニストレーティブディスタンス (AD):** デフォルト値は <code>1</code> です。これは動的プロトコルよりも優先されることを意味します。
*   **再帰的解決 (Recursive Lookup):** 次ホップにIPアドレスを指定した場合、そのアドレスに到達するための出力をさらに検索します。
*   **直接接続指定:** 出力インターフェイスのみを指定した場合、ルータはそのネットワークを直接接続（Connected）と見なします。イーサネット等のマルチアクセス環境では、ARP解決に依存するため、一般的には次ホップIPとインターフェイスの両方を指定することが推奨されます。

### 2. マルチキャストスタティックルート (Static mroute)

*   **役割:** マルチキャストの転送判断に使用される **RPFチェック** を制御するために使用されます。
*   **用途:** ユニキャストのルーティングトポロジーとマルチキャストの配信ツリーを分離したい場合や、動的プロトコルで解決できない不整合（Non-congruent topology）を解消するために使用します。
*   **特性:** <code>ip mroute</code> はパケットを「転送」するためのものではなく、あくまで「どのネイバーからパケットが届くのが正解か（RPFの検証）」を定義するためのものです。

### 3. 信頼性の高い静的ルーティング (Reliable Static Routing)

*   **課題:** 通常のスタティックルートは、出力インターフェイスが物理的にUpしている限りテーブルに残ります。しかし、数ホップ先で障害が発生している場合には対応できません。
*   **解決策:** **IP SLA** と **Object Tracking** を組み合わせます。特定の宛先へのICMP Echo（Ping）の成功を確認している間だけ、スタティックルートを有効にするといった構成が可能です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単に <code>ip route</code> を入力するだけの問題は稀であり、以下のような複合的な要件が提示されます。

### 1. 再配送 (Redistribution) とスタティックルート

*   スタティックルートを動的プロトコル（EIGRP/OSPF/BGP）へ再配送する場合のタグ付け（Tagging）がよく問われます。
*   <code>redistribute static</code> を行う際、不必要なルートまで広報しないようルートマップで制御する能力が必須です。

### 2. 浮動静的ルート (Floating Static Route)

*   メインの動的プロトコル（例：OSPF）がダウンした時のみ浮上するバックアップルートです。
*   メインのAD値（OSPF=110, EIGRP=90）よりも高い値を <code>ip route</code> の末尾に指定します。

### 3. VRF-Aware Static Routing

*   仮想ルーティング（VRF）環境下でのスタティックルート設定です。
*   <code>ip route vrf [NAME] [prefix] [mask] [next-hop]</code> のように、VRFインスタンスを指定して設定します。セグメンテーション（ネットワーク分離）の要件において非常に重要です。

### 4. IPv6 スタティックルーティングの注意点

*   IPv6では、次ホップに **リンクローカルアドレス (FE80::)** を指定する場合、必ず出力インターフェイスを併記しなければなりません。
*   グローバルユニキャストアドレスを次ホップにする場合は、インターフェイス指定は任意です。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **標準的な静的ルート設定** | <code>ip route [prefix] [mask] [next-hop&#124;interface]</code> |
| **ADを指定した静的ルート** | <code>ip route [prefix] [mask] [next-hop] [distance]</code> |
| **VRF内での静的ルート** | <code>ip route vrf [VRF_NAME] [prefix] [mask] [next-hop]</code> |
| **マルチキャスト用静的ルート** | <code>ip mroute [source] [mask] [rpf-neighbor]</code> |
| **IPv6静的ルート設定** | <code>ipv6 route [prefix/length] [next-hop&#124;interface]</code> |
| **ルーティングテーブルの確認** | <code>show ip route static</code> |
| **VRFルーティングテーブルの確認** | <code>show ip route vrf [VRF_NAME]</code> |
| **マルチキャストRPF情報の確認** | <code>show ip rpf [source_address]</code> |
| **SLA/Trackの状態確認** | <code>show track [id]</code> / <code>show ip sla statistics</code> |

---

## 🛠 ラボ学習・設定サンプル例

ソース資料のWorkbook演習に基づき、CCIEラボで頻出するシナリオを5つ提示します。

### 1. 浮動静的ルートによるWANバックアップ

**【問題内容】**
R1は10.2.2.0/24への経路をEIGRP(AS 100)で学習している。EIGRPネイバーが切れた際のバックアップとして、172.16.12.2を次ホップとする静的ルートを構成せよ。通常時はこの静的ルートはルーティングテーブルに現れてはならない。

**【設定サンプル】**
```ios
! EIGRP(AD 90)より高いAD値を指定する
R1(config)# ip route 10.2.2.0 255.255.255.0 172.16.12.2 210

! 検証
R1# show ip route 10.2.2.0
! EIGRP稼働時は D 10.2.2.0/24 [90/...] と表示
! ネイバーを落とすと S 10.2.2.0/24 [210/0] が浮上することを確認
```

### 2. IP SLA + Object Tracking による信頼性の高いルーティング

**【問題内容】**
R5からR1へのスタティックルート 150.1.1.1/32 を構成せよ。ただし、物理リンクがUpしていても、DMVPNクラウド越しの疎通が確認できない場合は、このルートを削除せよ。疎通確認は5秒おきに実行すること。

**【設定サンプル】**
```ios
! SLA設定
ip sla 1
 icmp-echo 150.1.1.1
 frequency 5
ip sla schedule 1 life forever start-time now

! トラッキング
track 10 ip sla 1 reachability

! トラッキングに紐付けた静的ルート
ip route 150.1.1.1 255.255.255.255 169.254.100.1 track 10
```

### 3. マルチキャスト：RPF不一致の修正 (Static mroute)

**【問題内容】**
マルチキャストソース 232.8.8.8 が R18 配下に存在する。R19 において、ユニキャスト経路では R20 経由で戻るルートになっているが、マルチキャストトラフィックは R18 直結の VLAN77 を経由して受け取りたい。RPFチェックを成功させるよう設定せよ。

**【設定サンプル】**
```ios
! ユニキャストテーブルを無視してRPFネイバーをR18(10.1.77.18)に固定
R19(config)# ip mroute 232.8.8.8 255.255.255.255 10.1.77.18

! 検証
R19# show ip rpf 232.8.8.8
! "RPF neighbor: 10.1.77.18", "RPF type: static" となっていることを確認
```

### 4. VRF セグメンテーション環境での静的ルート

**【問題内容】**
VRF 'GUEST' に属する R4 において、共通サービス用セグメント 10.100.1.0/24 への次ホップを 192.168.4.254 として定義せよ。他のVRFやグローバルテーブルにこのルートが影響を及ぼしてはならない。

**【設定サンプル】**
```ios
R4(config)# ip route vrf GUEST 10.100.1.0 255.255.255.0 192.168.4.254

! 検証
R4# show ip route vrf GUEST static
! VRF GUEST専用のルーティングテーブルに登録されていることを確認
```

### 5. IPv6：リンクローカルアドレスを使用した静的ルート

**【問題内容】**
R2とR3はシリアルリンク(S4/0)で接続されている。R2からR3のLoopback 2001:DB8:3::3/128 へのスタティックルートを、R3のリンクローカルアドレス FE80::3 を使用して構成せよ。

**【設定サンプル】**
```ios
! IPv6でリンクローカルを次ホップにする場合はインターフェイス指定が必須
R2(config)# ipv6 route 2001:DB8:3::3/128 Serial4/0 FE80::3

! 検証
R2# show ipv6 route static
! S 2001:DB8:3::3/128 [1/0] via FE80::3, Serial4/0 と表示される
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: Protocol-Independent Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book.html)
*   [IPv6 Routing: Static Routing Configuration (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/ip-version-6-ipv6/113328-ipv6-static-00.html)
*   [IP Multicast: Static mroute configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book/imc-static-mroutes.html)

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKCCIE-3000: BGP is your Friend – BGP for the CCIE Candidates (再配送/AD操作含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### テクニカルドキュメント・設定例
*   [Reliable Static Routing with IP SLA (Cisco TechNotes)](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/215357-reliable-static-routing-using-ip-sla.html)
*   [Static Route and VRF Configuration Examples](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/13731-static-vrf.html)

---


## 📝 補足
- この学習メモは、CCIE EIラボ試験における「インフラストラクチャの基盤」を固めるために最適化されています。スタティックルーティングは単独の問題としてだけでなく、DMVPN、SD-WAN、マルチキャストといった上位レイヤの技術を動作させるための「前提条件」として頻繁に活用されるため、完璧な習得が求められます。

