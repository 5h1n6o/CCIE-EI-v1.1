---
layout: default
title: 1.2.g-Route-filtering
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 7
---

# 1.2.g-Route-filtering

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.g Route filtering with BGP, EIGRP, OSPF, and static」について整理しました。

---

## 📘 概要

**Route Filtering（ルートフィルタリング）**は、ルータ間でのルーティング情報の交換を制御し、特定の経路情報をルーティングテーブル（RIB）や近隣ルータへの広告から意図的に除外する技術です。

単なる到達性の制限（セキュリティ）だけでなく、**「ルーティングループの防止」**、**「サブオプティマルルーティング（最適ではない経路）の回避」**、および**「ルータのCPU/メモリリソースの最適化」**において極めて重要な役割を果たします。CCIEレベルでは、プロトコルごとの動作原理（ディスタンスベクトル型とリンクステート型の違いなど）を深く理解し、プレフィックスリスト、ルートマップ、コミュニティ、タグ付けなどのツールを駆使して、複雑な要件を最小限のコンフィギュレーションで実現する能力が求められます。

---

## 🔑 要点

### 1. 共通のフィルタリングツール

各プロトコルで共通して使用されるコンポーネントです。

*   **Access Control Lists (ACLs):** 基本的なフィルタリングに使用されますが、サブネットマスクの範囲指定が柔軟ではないため、ルーティング制御ではプレフィックスリストが推奨されます。
*   **IP Prefix-Lists:** ネットワークアドレスとマスク長（`ge`, `le` オプション）を組み合わせてマッチングを行います。パフォーマンスに優れ、CCIEラボでの標準的な選択肢です。
*   **Route Maps:** 最も強力なツールです。`match` 文で条件を特定し、`set` 文で属性（タグ、メトリック、AD値など）を変更できます。

### 2. プロトコル別のフィルタリング特性

| プロトコル | フィルタリングの挙動と注意点 |
| :--- | :--- |
| **BGP** | 最も柔軟です。プレフィックス、ASパス（`filter-list`）、コミュニティ、および特定の属性（MED, Local Preference）に基づいて制御します。 |
| **EIGRP** | `distribute-list` を使用して、受信（In）または送信（Out）時にフィルタリングします。ディスタンスベクトル型のため、フィルタリングしたルートは後続のルータにも伝わりません。 |
| **OSPF** | **重要：** リンクステート型のため、エリア内での `distribute-list in` は自身のRIBインストールを防ぐだけで、LSA（データベース）の伝播は止められません。エリア間では ABR でのフィルタリング（`area filter-list`）が必要です。 |
| **Static** | スタティックルート自体をフィルタリングするのではなく、動的プロトコルへ **再配送（Redistribute）** する際にルートマップを適用して制御するのが一般的です。 |

### 3. 高度なフィルタリング技術

*   **Administrative Distance (AD) 255:** 特定のルートの信頼度を「Unknown」にすることで、RIBへのインストールを拒否する手法です。トポロジテーブルには情報を残したい場合に有効です。
*   **Community-based filtering (BGP):** 特定のコミュニティが付与されたルートのみを拒否・許可することで、大規模なネットワークでの制御を簡素化します。
*   **Conditional Route Injection:** 特定の条件（他のルートの有無など）が満たされた場合にのみ、特定のプレフィックスを生成・フィルタリングします。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE Enterprise Infrastructureのラボ試験において、ルートフィルタリングは単独の問題としてだけでなく、複雑なネットワークを正常化するための「道具」として頻繁に登場します。

### 1. 相互再配送におけるループ防止

2つ以上のポイントでプロトコル間再配送（OSPF ↔ EIGRPなど）を行う場合、フィルタリングは必須です。
*   **戦略:** 再配送時にルートマップで **「タグ（Tag）」** を付与し、逆方向の再配送ポイントでそのタグを持つルートを `deny` することで、ルートの「逆流」を防ぎます。

### 2. OSPF の「データベース vs RIB」の理解

「R1で特定のOSPFルートをルーティングテーブルから消せ。ただし、他のルータの通信に影響を与えてはならない」という要件。
*   **対策:** エリア内の場合、`distribute-list [ACL] in` を使用します。これにより R1 の RIB からは消えますが、LSA は伝播し続けるため、他のルータへの影響を最小限に抑えられます。

### 3. BGP の属性操作による暗黙的フィルタリング

「プレフィックスリストを使わずに、AS 100 由来のルートを優先順位で最下位にせよ」。
*   **対策:** AS-Path フィルタリングでマッチさせ、`set local-preference` を極端に低くするか、AD値を操作します。

### 4. 最小コマンド数の原則

ラボ試験のタスクには「Use the smallest number of commands possible（最小限のコマンド数で実現せよ）」という指示が含まれることがあります。
*   **対策:** 複数の `network` 文や `ip route` を書くのではなく、プレフィックスリストの `ge` / `le` オプションや、再配送時の集約（Summarization）とフィルタリングを組み合わせる能力が問われます。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EIGRP 受信フィルタリング** | <code>(config-router)# distribute-list [ACL&#124;prefix-list] in [interface]</code> |
| **BGP プレフィックスフィルタ** | <code>(config-router-af)# neighbor [IP] prefix-list [NAME] {in&#124;out}</code> |
| **BGP ASパスフィルタ** | <code>(config-router-af)# neighbor [IP] filter-list [AS_PATH_ACL] {in&#124;out}</code> |
| **OSPF エリア間フィルタ(ABR)** | <code>(config-router)# area [ID] filter-list prefix [NAME] {in&#124;out}</code> |
| **再配送時のフィルタリング** | <code>(config-router)# redistribute [protocol] route-map [NAME]</code> |
| **AD値によるフィルタリング** | <code>(config-router)# distance 255 [source_IP] [wildcard] [ACL]</code> |
| **現在のフィルタリング確認** | <code>show ip protocols</code> |
| **BGP 受信ルートの確認** | <code>show ip bgp neighbors [IP] received-routes</code> |
| **ルートマップの合致確認** | <code>show route-map [NAME]</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. EIGRP：特定の第3オクテット（奇数）をフィルタリング

**【問題内容】**
R9において、R7から学習するEIGRPルートのうち、第3オクテットが「奇数」であるすべてのネットワークを拒否せよ。1行のACLで記述すること。

**【設定例】**
```ios
! 第3オクテットの最下位ビットが1であれば奇数
access-list 10 deny 0.0.1.0 255.255.254.255
access-list 10 permit any

router eigrp 100
 distribute-list 10 in GigabitEthernet1.79
```

---

### 2. OSPF：エリア間ルート（LSA 3）の集約と特定ルートの拒否

**【問題内容】**
ABR（R1）において、Area 14 のルートを Area 0 へ広報する際、10.1.5.5/32 へのルートのみをフィルタリングし、それ以外のルートはそのまま広報せよ。

**【設定例】**
```ios
! 拒否対象を定義
ip prefix-list FILTER_LSA3 seq 5 deny 10.1.5.5/32
ip prefix-list FILTER_LSA3 seq 10 permit 0.0.0.0/0 le 32

router ospf 1
 ! エリア境界でプレフィックスリストを適用
 area 14 filter-list prefix FILTER_LSA3 out
```

---

### 3. BGP：コミュニティを使用したルートの抑制

**【問題内容】**
R18からAS 3333へルートを広報する際、コミュニティ値 `NO_EXPORT` を付与して、対向のASがそのルートをさらに外部へ転送しないように制御せよ。

**【設定例】**
```ios
route-map SET_COMM permit 10
 set community no-export additive

router bgp 65423
 neighbor 10.1.33.3 route-map SET_COMM out
 neighbor 10.1.33.3 send-community
```

---

### 4. 再配送：タグを使用した相互再配送のループ防止

**【問題内容】**
R8において、OSPFからEIGRPv6へ再配送する際にタグ `110` を付与し、逆方向の再配送ポイントでタグ `110` を持つルートを拒否せよ。

**【設定例】**
```ios
! OSPF -> EIGRP
route-map OSPF_TO_EIGRP permit 10
 set tag 110

router eigrp CCIE
 address-family ipv6 vrf CUSTOMER autonomous-system 78
  redistribute ospf 1 route-map OSPF_TO_EIGRP

! EIGRP -> OSPF (別の再配送ルータ)
route-map EIGRP_TO_OSPF deny 10
 match tag 110
route-map EIGRP_TO_OSPF permit 20

router ospfv3 1
 address-family ipv6 vrf CUSTOMER
  redistribute eigrp 78 route-map EIGRP_TO_OSPF
```

---

### 5. BGP：条件付きルート注入（Conditional Route Injection）

**【問題内容】**
特定の集約ルート `10.0.0.0/22` が存在する場合のみ、より具体的な `10.0.1.0/24` をBGPテーブルへ注入せよ。ただし、これらのルートの送信元は R2（155.1.23.2）である必要がある。

**【設定例】**
```ios
! 存在すべきルート(Aggregate)を定義
ip prefix-list EXIST_PREFIX permit 10.0.0.0/22
ip prefix-list SOURCE_R2 permit 155.1.23.2/32

! 注入したいルートを定義
ip prefix-list INJECT_PREFIX permit 10.0.1.0/24

route-map MAP_EXIST permit 10
 match ip address prefix-list EXIST_PREFIX
 match ip next-hop prefix-list SOURCE_R2

route-map MAP_INJECT permit 10
 set ip address prefix-list INJECT_PREFIX

router bgp 100
 bgp inject-map MAP_INJECT exist-map MAP_EXIST
```

---

### 6. AD操作による「RIBへのインストール拒否」

**【問題内容】**
R6において、EIGRPネイバー 150.1.4.4 から学習する 150.1.4.4/32 のルートをルーティングテーブルに登録させないようにせよ。ディストリビュートリストは使用禁止とする。

**【設定例】**
```ios
access-list 4 permit 150.1.4.4

router eigrp 100
 ! 特定のネイバー(150.1.4.4)からの特定ルート(ACL 4)をAD 255にする
 distance 255 150.1.4.4 0.0.0.0 4
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: BGP Configuration Guide - Route Filtering (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)
*   [Filtering Routing Information (Cisco Support)](https://www.cisco.com/c/ja_jp/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)
*   [OSPF Inbound Filtering Using Route Map with a Distribute List](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/15-mt/iro-15-mt-book/iro-sup-routemap.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKRST-3320: Troubleshooting Routing Protocols (フィルタリングによるトラブル含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKCCIE-3000: BGP for CCIE Candidates (Advanced Filtering)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### テクニカルドキュメント・設定例
*   [BGP Case Studies: Filtering](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)
*   [Understanding Route Aggregation and Suppression in BGP](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/5441-aggregation.html)

---

## 📝 補足
- この学習メモは、CCIE EIラボ試験で求められる「正確かつ効率的なトラフィック制御」の基盤を網羅しています。特に OSPF の LSA フィルタリングの制約や、再配送時のタグ付けによるループ回避は、試験突破のための最重要項目です。


