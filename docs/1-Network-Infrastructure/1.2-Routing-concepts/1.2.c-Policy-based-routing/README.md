---
layout: default
title: 1.2.c-Policy-based-routing
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.2.c-Policy-based-routing

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.c Policy-based routing (PBR)」について整理しました。

---

## 📘 概要

**Policy-based Routing (PBR)** は、ルータの標準的なルーティングテーブル（RIB）の判断をバイパスし、管理者が定義した特定のポリシーに基づいてパケットの転送パスを決定する技術です。

通常、ルータは「宛先IPアドレス」のみを見て転送先を決定しますが、PBRを用いることで「送信元IPアドレス」「プロトコル（TCP/UDP/ICMP）」「ポート番号」「パケット長」「DSCP値（QoS）」、さらには「アプリケーションタイプ（NBAR経由）」に基づいてトラフィックを特定のインターフェイスや次ホップへ誘導することが可能になります。

CCIEレベルでは、単なるパスの強制だけでなく、**IP SLA** との連携による「パスの正常性確認（信頼性の確保）」や、VRF環境下でのセグメンテーション維持、さらにはルータ自身が生成するトラフィックに対する **Local PBR** の実装など、高度な条件分岐が求められます。

---

## 🔑 要点

### 1. PBR の動作メカニズム

PBRは `route-map` を使用して実装されます。`match` 文でトラフィックを特定し、`set` 文でアクション（次ホップの指定等）を定義します。

| 処理ステップ | 内容 |
| :--- | :--- |
| **パケット着信** | インターフェイスに `ip policy route-map` が設定されている場合、PBRロジックが最初に評価されます。 |
| **Match評価** | `match ip address` 等でトラフィックを照合します。 |
| **Set実行** | マッチした場合、`set ip next-hop` 等を実行し、通常のルーティングテーブルを無視して転送します。 |
| **フォールバック** | マッチしない、または `set` 先が到達不能な場合、通常のルーティングテーブル検索（RIB）に戻ります。 |

### 2. Standard PBR vs. Local PBR

*   **Standard PBR:** インターフェイスに着信した（ルータを通過する）トラフィックに適用されます。
*   **Local PBR:** ルータ自身が生成した（例：BGPアップデート、SNMP、ルータからのPing）トラフィックに適用されます。`ip local policy route-map` コマンドでグローバルに設定します。

### 3. Set コマンドの優先順位と論理

PBRにおける `set` 文には、その動作に重要な違いがあります。

| コマンド | 特徴 |
| :--- | :--- |
| <code>set ip next-hop</code> | **最強の優先順位。** ルーティングテーブルに宛先へのルートがあるかどうかに関わらず、指定した次ホップへ強制的に送ります。 |
| <code>set ip default next-hop</code> | **RIB優先。** ルーティングテーブルに「明示的なルート（デフォルトルート以外）」が存在しない場合にのみ、指定した次ホップを使用します。 |
| <code>set interface</code> | 指定したインターフェイスへパケットを投げます。主にシリアルなどのポイントツーポイントリンクで使用されます。 |
| <code>set ip vrf next-hop</code> | 特定のVRFインスタンス内の次ホップを指定します。 |

### 4. CEF と PBR のパフォーマンス

古いIOSではPBRはプロセススイッチング（CPU負荷大）の原因でしたが、現代の Cisco IOS XE では **CEF-switched PBR** がデフォルトであり、ハードウェア（ASIC/FPGA）で高速に処理されます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験において、PBRは「経路制御の最終手段」または「特定のトラフィックエンジニアリング要件」として出題されます。

### 1. 信頼性の高いPBR（IP SLA + Object Tracking）

`set ip next-hop` で指定した宛先がダウンしている場合、PBRはデフォルトでパケットをドロップするか、RIB検索に戻ります。
*   **要件例:** 「10.1.1.1 へのパスを優先せよ。ただし 10.1.1.1 への Ping が失敗する場合は、このポリシーを無効化せよ。」
*   **実装:** `set ip next-hop verify-availability` コマンドや、`track` オブジェクトを `set` 文に紐付けます。

### 2. アプリケーションの識別（NBAR連携）

ソース資料にある通り、特定のURLやホスト名に基づいた制御が問われることがあります。
*   **要件例:** 「HTTPトラフィックのうち、URLに '/iPexpert' が含まれるものだけを ISP2 経由で送信せよ。」
*   **実装:** `class-map` で `match protocol http url` を指定し、PBRの `match` 条件として使用します。

### 3. ルーティングループの回避

再配送とPBRを組み合わせる場合、PBRで強制的にパケットを戻してしまうことでループが発生する危険があります。
*   `match length` コマンドを使用して、特定のサイズのパケット（例：音声パケットのみ）を制御するなど、条件を絞り込むテクニックが有効です。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **ACLによる対象トラフィック定義** | <code>access-list [ID] permit [protocol] [src] [dst]</code> |
| **ルートマップの定義** | <code>route-map [NAME] permit [SEQ]</code> |
| **トラフィックの合致条件** | <code>match ip address [ACL_ID]</code> |
| **パケット長による合致条件** | <code>match length [min] [max]</code> |
| **次ホップの強制指定** | <code>set ip next-hop [IP]</code> |
| **RIB優先の次ホップ指定** | <code>set ip default next-hop [IP]</code> |
| **インターフェイスへの適用** | <code>(config-if)# ip policy route-map [NAME]</code> |
| **ルータ自身への適用(Local)** | <code>(config)# ip local policy route-map [NAME]</code> |
| **PBRの統計情報の確認** | <code>show ip policy</code> |
| **ルートマップの適用状況確認** | <code>show route-map [NAME]</code> |
| **PBRパケットのデバッグ** | <code>debug ip policy</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. ソースIPアドレスに基づく経路制御

**【問題内容】**
R1の Ethernet0/0 に接続された2つのサブネットがある。192.168.10.0/24 からのトラフィックは R2 経由、192.168.20.0/24 からのトラフィックは R3 経由でインターネットへ出すように構成せよ。

**【設定例】**
```ios
! トラフィックの定義
access-list 10 permit 192.168.10.0 0.0.0.255
access-list 20 permit 192.168.20.0 0.0.0.255

! ポリシー作成
route-map SOURCE_ROUTING permit 10
 match ip address 10
 set ip next-hop 10.1.12.2
!
route-map SOURCE_ROUTING permit 20
 match ip address 20
 set ip next-hop 10.1.13.3

! インターフェイスへの適用
interface Ethernet0/0
 ip address 192.168.1.1 255.255.255.0
 ip policy route-map SOURCE_ROUTING
```

---

### 2. Local PBR：ルータ発トラフィックの制御

**【問題内容】**
R6ルータ自身から送信される Telnet トラフィックのみ、通常の OSPF ルートを無視して 155.1.13.3 を次ホップとして送信せよ。

**【設定例】**
```ios
! Telnetトラフィックを定義
ip access-list extended TELNET_ONLY
 permit tcp any any eq telnet

! ポリシー作成
route-map LOCAL_CTL permit 10
 match ip address TELNET_ONLY
 set ip next-hop 155.1.13.3

! グローバルにLocal PBRを適用
ip local policy route-map LOCAL_CTL
```

---

### 3. IP SLA を用いた「死活監視付き」PBR

**【問題内容】**
すべての HTTP トラフィックを 172.16.1.2 経由で転送せよ。ただし、172.16.1.2 への ICMP 到達性が失われた場合は、この PBR を無効化し、通常のルーティング（RIB）に従って転送すること。

**【設定例】**
```ios
! SLA設定：5秒おきに次ホップを監視
ip sla 1
 icmp-echo 172.16.1.2
 frequency 5
ip sla schedule 1 life forever start-time now

! トラッキング設定
track 100 ip sla 1 reachability

! ポリシー作成
ip access-list extended HTTP_TRAFFIC
 permit tcp any any eq 80

route-map RELIABLE_PBR permit 10
 match ip address HTTP_TRAFFIC
 ! トラックオブジェクトがUPの場合のみ有効になる
 set ip next-hop verify-availability 172.16.1.2 1 track 100
```

---

### 4. Default Next-Hop による「最後のリゾート」制御

**【問題内容】**
R4において、宛先への明示的なルート（ロンゲストマッチ）がルーティングテーブルに存在する場合はそれに従い、存在しない場合（かつデフォルトルートしかない場合）のみ 10.1.1.1 ではなく 10.2.2.2 を次ホップとして使用せよ。

**【設定例】**
```ios
route-map FALLBACK_POLICY permit 10
 ! match文がない場合はすべてのパケットが対象
 set ip default next-hop 10.2.2.2

interface Ethernet0/1
 ip policy route-map FALLBACK_POLICY
```

---

### 5. パケット長に基づく VoIP トラフィックの優先

**【問題内容】**
音声（VoIP）パケットはサイズが小さい特徴がある。パケットサイズが 64バイトから 200バイトのトラフィックのみ、低遅延な専用リンク（Serial 0/0）経由で送信せよ。

**【設定例】**
```ios
route-map VOIP_PRIORITY permit 10
 match length 64 200
 set interface Serial0/0

interface Ethernet0/0
 ip policy route-map VOIP_PRIORITY
```

---

### 6. VRF 間のトラフィック誘導 (VRF-Aware PBR)

**【問題内容】**
VRF 'GUEST' から届いたパケットを、共有サービスが存在する VRF 'SERVICES' 内の 10.100.1.1 へ転送せよ。

**【設定例】**
```ios
route-map VRF_PBR permit 10
 match ip address 101
 ! 特定のVRF内の次ホップを指定
 set ip vrf SERVICES next-hop 10.100.1.1

interface GigabitEthernet0/0
 vrf forwarding GUEST
 ip policy route-map VRF_PBR
```

---

## 参考リソースリンク

### Configurationガイド
*   [Protocol-Independent Configuration Guide: PBR (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book/iri-pbr.html)
*   [Policy-Based Routing (Cisco Support Document)](https://www.cisco.com/c/ja_jp/support/docs/ip/ip-routing/215357-reliable-static-routing-using-ip-sla.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKRST-3320: Troubleshooting Routing Protocols (PBRのデバッグ手法を含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### テクニカルドキュメント・設定例
*   [PBR with IP SLA and Object Tracking Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/215357-reliable-static-routing-using-ip-sla.html)
*   [Configuring Local PBR for Management Traffic](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-16/iri-xe-16-book/iri-pbr.html)

---


## 📝 補足

- この学習メモは、CCIE EIラボ試験において「ルーティングプロトコルだけでは解決できない変則的なパス転送要件」を解決するための武器となります。特に `match` 条件の細かさと、`set` コマンドの優先順位（デフォルト設定の有無）、および可用性（SLA）の担保が試験での評価ポイントになります。

