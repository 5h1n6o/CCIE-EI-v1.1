---
layout: default
title: 1.2.h-Redistribution
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 8
---

# 1.2.h-Redistribution

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.h Redistribution between BGP, EIGRP, OSPF, and static」について整理しました。

---

## 📘 概要

**Redistribution（再配送）**とは、あるルーティングプロトコル（またはスタティックルート、直結ルート）で学習した経路情報を、別のルーティングプロトコルのアップデートとして広告するプロセスです。

エンタープライズネットワークでは、合併による異なるプロトコルの混在、移行期間中の並行運用、あるいはSD-WANやMPLS-VPNなどのエッジポイントにおいて、プロトコル間でのルート交換が不可欠です。しかし、再配送は「情報の喪失（メトリックの変換）」を伴うため、**ルーティングループ**や**サブオプティマルルーティング（最適ではないパスの選択）**を引き起こすリスクが非常に高い技術です。CCIEレベルでは、これらの問題を「ルートタグ」「ルートマップ」「AD値の操作」を用いて、いかにエレガントかつ確実に制御できるかが問われます。

---

## 🔑 要点

### 1. シードメトリック（Seed Metric）

ルートを再配送する際、元プロトコルのメトリックは破棄され、新しいプロトコルの初期値（シードメトリック）に変換されます。

| 再配送先プロトコル | デフォルトのシードメトリック | 注意点 |
| :--- | :--- | :--- |
| **EIGRP** | **∞ (無限大)** | <code>default-metric</code> または <code>metric</code> 指定が必須。 |
| **OSPF** | **20 (Type E2)** | BGPからの場合は 1。<code>subnets</code> キーワードがないとクラスフルのみ配送。 |
| **BGP** | **IGPメトリックを引き継ぐ** | <code>metric</code> 指定がない場合、IGPのコストがMEDとして使用される。 |
| **RIP** | **∞ (無限大)** | <code>default-metric</code> の指定が必須。 |

### 2. アドミニストレーティブディスタンス (AD)

再配送されたルートは、通常「外部ルート（External）」として扱われ、プロトコルによっては異なるAD値が適用されます。これが原因で、本来の内部ルートよりも「遠回りな再配送ルート」を優先してしまう現象が発生します。

*   **EIGRP Internal (90) vs. External (170)**
*   **OSPF (110)**: エリア内、エリア間、外部ルートで共通（デフォルト）。
*   **BGP External (20) vs. Internal (200)**

### 3. ルートマップ (Route Maps) による制御

再配送を行う際は、必ずと言っていいほどルートマップを併用します。これにより、特定のプレフィックスのみを許可したり、タグを付与して後続のルータでループを検知したりすることが可能になります。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、2つ以上のルータで相互再配送を行う「多点再配送（Multi-point Mutual Redistribution）」のシナリオが定番です。

### 1. ルートタグ（Tagging）によるループ防止戦略

最も推奨される手法です。
1.  プロトコル A から B へ再配送する際に、ルートに特定の **Tag（例: 100）** を付与します。
2.  別の再配送ポイント（ルータ）において、プロトコル B から A へ戻す際、**Tag 100 を持つルートを拒否（deny）** します。
これにより、ルートが元のドメインに逆流してループすることを防ぎます。

### 2. AD値の操作（Administrative Distance Manipulation）

多点再配送において、AD値の差によって「外部から回ってきたルート」を「ドメイン内部のルート」よりも優先してしまう場合に有効です。
*   例えば、OSPF(110) と EIGRP(90) の相互再配送では、OSPFドメインのルートがEIGRPドメイン経由で戻ってきた際に AD 90 となり、OSPF内部の 110 よりも優先される可能性があります。
*   対策として、<code>distance eigrp 90 175</code> のように外部ADを引き上げる、あるいは <code>distance ospf external 180</code> のように個別に調整します。

### 3. OSPF の `subnets` キーワード

OSPFへの再配送で最も多いミスが、<code>subnets</code> キーワードの失念です。これを忘れると、サブネット化された経路が一切配送されず、クラスフル（A, B, Cクラス）の境界のみが広報されます。

### 4. BGP への再配送

BGPへ IGP を再配送する際、Origin属性が **Incomplete (?)** になる点に注意してください。要件で 「Originを IGP(i) にせよ」とある場合は、ルートマップで <code>set origin igp</code> を実行する必要があります。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EIGRPへの再配送 (メトリック指定)** | <code>redistribute [proto] metric [BW] [DLY] [REL] [LD] [MTU]</code> |
| **OSPFへの再配送 (サブネット許可)** | <code>redistribute [proto] subnets</code> |
| **BGPへの再配送** | <code>redistribute [proto] [process-id] route-map [NAME]</code> |
| **ルートタグの付与 (Route Map内)** | <code>set tag [VALUE]</code> |
| **ルートタグのマッチング (Route Map内)** | <code>match tag [VALUE]</code> |
| **AD値のグローバル変更(EIGRP)** | <code>distance eigrp [internal-ad] [external-ad]</code> |
| **OSPFタイプ別のAD変更** | <code>distance ospf {intra-area&#124;inter-area&#124;external} [AD]</code> |
| **特定のプレフィックスのタグ確認** | <code>show ip route [prefix]</code> |
| **OSPF 外部LSAの詳細確認** | <code>show ip ospf database external</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 多点相互再配送（OSPF ↔ EIGRP）での Tagging

**【問題内容】**
R1 と R6 で OSPF プロセス 1 と EIGRP AS 100 を相互再配送している。ルーティングループを防止するため、OSPF から EIGRP へ入るルートにタグ 110 を、EIGRP から OSPF へ入るルートにタグ 90 を付与し、相互に拒否せよ。

**【設定例：R1 & R6 共通】**
```ios
! EIGRP -> OSPF の制御
route-map EIGRP_TO_OSPF deny 10
 match tag 110                   ! OSPF由来のルートを拒否
route-map EIGRP_TO_OSPF permit 20
 set tag 90                      ! EIGRP由来としてタグ付与

! OSPF -> EIGRP の制御
route-map OSPF_TO_EIGRP deny 10
 match tag 90                    ! EIGRP由来のルートを拒否
route-map OSPF_TO_EIGRP permit 20
 set tag 110                     ! OSPF由来としてタグ付与

router ospf 1
 redistribute eigrp 100 subnets route-map EIGRP_TO_OSPF

router eigrp 100
 redistribute ospf 1 metric 10000 10 255 1 1500 route-map OSPF_TO_EIGRP
```

---

### 2. OSPF から BGP への再配送（Origin属性の制御）

**【問題内容】**
OSPF エリア 0 の経路を BGP AS 65000 へ再配送せよ。ただし、BGPテーブル上でこれらのルートの Origin Code が "i" (IGP) として表示されるように構成すること。

**【設定例】**
```ios
ip prefix-list OSPF_ROUTES permit 10.0.0.0/8 le 32

route-map SET_ORIGIN permit 10
 match ip address prefix-list OSPF_ROUTES
 set origin igp                  ! Originを"?"から"i"へ変更

router bgp 65000
 address-family ipv4
  redistribute ospf 1 route-map SET_ORIGIN
```
**【検証】**
<code>show ip bgp</code> を実行し、該当プレフィックスの右端（Path属性の末尾）が `i` になっていることを確認します。

---

### 3. EIGRP：特定のプレフィックスのみ外部メトリックを調整

**【問題内容】**
スタティックルート 172.16.1.0/24 を EIGRP へ再配送せよ。ただし、このルートだけは遅延（Delay）を 100ms（10000 tens of microsec）に設定し、他のスタティックルートはデフォルトのメトリックを使用せよ。

**【設定例】**
```ios
access-list 1 permit 172.16.1.0 0.0.0.255

route-map CUSTOM_METRIC permit 10
 match ip address 1
 set metric 10000 10000 255 1 1500  ! 特定ルートのメトリック
route-map CUSTOM_METRIC permit 20
 ! その他のルートは default-metric に従う

router eigrp 100
 default-metric 10000 10 255 1 1500
 redistribute static route-map CUSTOM_METRIC
```

---

### 4. BGP から EIGRP への再配送（AD値による最適パス選択）

**【問題内容】**
R18において BGP ルートを EIGRP 34567 へ再配送している。この際、EIGRPドメイン内で BGP 由来のルート（External）が OSPF のルートよりも優先されてしまう現象を防ぐため、EIGRP外部ルートの AD 値を 170 から 190 へ変更せよ。

**【設定例】**
```ios
router eigrp 34567
 redistribute bgp 65423 metric 1000 10 255 1 1500
 ! 内部ADは90のまま、外部ADを190に引き上げる
 distance eigrp 90 190
```
**【検証】**
<code>show ip route</code> で、BGPから再配送されたルートの <code>[190/...]</code> という表示を確認します。

---

### 5. IPv6：OSPFv3 と EIGRPv6 の相互再配送

**【問題内容】**
R8において、IPv6 環境で OSPFv3 と EIGRP AS 78 の相互再配送を構成せよ。直結インターフェイスの経路も再配送に含めること。

**【設定例】**
```ios
! EIGRPv6配下
ipv6 router eigrp 78
 redistribute ospf 1 metric 10000 10 255 1 1500 include-connected

! OSPFv3配下
router ospfv3 1
 address-family ipv6 unicast
  redistribute eigrp 78 include-connected
```
※注：IPv6では <code>include-connected</code> オプションを使用することで、そのプロトコルが有効なインターフェイス以外の直結ルートもスマートに配送できます。

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: Protocol-Independent Configuration Guide - Redistribution (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book/iri-redist-rout-info.html)
*   [Redistributing Routing Protocols (Cisco Support Document)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/15986-admin-distance.html)

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols (再配送トラブルの深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKCCIE-3000: BGP is your Friend – BGP for the CCIE Candidates (再配送属性の操作)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### テクニカルドキュメント・設定例
*   [Understanding Route Redistribution and Administrative Distance](https://www.cisco.com/c/ja_jp/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)
*   [Preventing Routing Loops in Mutual Redistribution using Route Tags](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13692-21.html)

---


## 📝 補足
- この学習メモは、CCIE EIラボ試験において最も受験者を苦しめる「再配送に起因する不明な通信断」を論理的に解決するための地図となります。特に「Tagを付けて反対側でDenyする」という一連の動作は、脊髄反射レベルで手が動くように実機検証を繰り返してください。

