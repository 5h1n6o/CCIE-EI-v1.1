---
layout: default
title: 1.5.b-Path-selection
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.5.b BGP Path Selection

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.5 BGP」における「1.5.b Path selection（パス選定）」について、CCIEレベルの技術詳細、属性の役割、ベストパスアルゴリズム、および負荷分散の実装手法について詳細に整理しました。

---

## 📘 概要

**BGP (Border Gateway Protocol)** は、最短経路のみを追求するIGP（OSPFやEIGRP）とは異なり、組織のポリシーに基づいて経路を選択する「ポリシー駆動型」のパスベクトルプロトコルです。BGPのパス選定（Path Selection）は、単一のメトリック値ではなく、複数の **パス属性 (Path Attributes)** を特定の優先順位で評価する **ベストパス選定アルゴリズム (Best Path Selection Algorithm)** に基づいて行われます。

BGPルータは、同一の宛先プレフィックスに対して複数のルートを受信した場合、この決定プロセスを順次実行し、最終的に「ベスト」と判定された1つのルートのみをルーティングテーブル（RIB）にインストールし、ネイバーへ広報します。ただし、**負荷分散 (Load Balancing)** を有効に設定した場合は、特定の条件を満たす複数のパスを同時に使用することが可能です。CCIE EIレベルでは、これらの属性をルートマップ等で自在に操作し、複雑なトラフィックエンジニアリングを実現する能力が問われます。

---

## 🔑 要点

### 1. BGP パス属性 (Attributes) の分類 (i)

BGPの属性は、その性質によって以下の4つのカテゴリに分類されます。

| カテゴリ | 特徴 | 属性例 |
| :--- | :--- | :--- |
| **Well-known Mandatory** | 全てのBGPルータが認識し、全てのUpdateに含まれる必須属性。 | <code>AS_PATH</code>, <code>NEXT_HOP</code>, <code>ORIGIN</code> |
| **Well-known Discretionary** | 全てのBGPルータが認識するが、Updateに含めるかは任意。 | <code>LOCAL_PREF</code>, <code>ATOMIC_AGGREGATE</code> |
| **Optional Transitive** | 認識できないルータがあっても、次のピアへ転送される属性。 | <code>COMMUNITY</code>, <code>AGGREGATOR</code> |
| **Optional Non-transitive** | 認識できない場合は無視され、次のピアへ転送されない属性。 | <code>MED</code>, <code>ORIGINATOR_ID</code>, <code>CLUSTER_LIST</code> |

### 2. ベストパス選定アルゴリズム (ii)

BGPは、以下の順序で候補パスを比較し、タイ（同等）でなくなった時点で選定を終了します。

1.  **Weight (最高):** Cisco独自のローカル属性。設定されたルータ内でのみ有効。
2.  **Local Preference (最高):** AS内部全体で共有される優先度。
3.  **Locally Originated:** 自身で生成したルート（`network`や`redistribute`）を、ピアから学習したルートより優先。
4.  **AS_PATH (最短):** 通過するAS数が少ないパスを選択。
5.  **Origin Code (最小):** IGP (i) < EGP (e) < Incomplete (?) の順で優先。
6.  **MED (最小):** 隣接するASに対し、自ASへの入り口を指定するために使用。
7.  **Neighbor Type:** eBGP パスを iBGP パスよりも優先。
8.  **IGP Metric to Next-Hop (最小):** BGPネクストホップに到達するための内部コスト。
9.  **Multipath:** ここまでが全て同じで、`maximum-paths` が設定されていれば負荷分散。
10. **Oldest Path:** eBGPパスが複数ある場合、先に学習したパスを優先（フラッピング防止）。
11. **Router-ID (最小):** ルータを識別するIDの数値が低い方を優先。
12. **Cluster List Length (最短):** ルートリフレクタ環境で使用。
13. **Neighbor Address (最小):** `neighbor` コマンドで指定したIPアドレスの数値が低い方を優先。

### 3. BGP 負荷分散 (Load Balancing) (iii)

デフォルトでは、BGPは1つの最適パスのみを選択しますが、設定により等コスト、または不等コストの負荷分散が可能です。

*   **Equal-Cost Multi-Path (ECMP):** `maximum-paths [数]` コマンドを使用。AS_PATHの長さ、Origin、MED、IGPメトリック等が一致している必要があります。
*   **iBGP Multi-path:** `maximum-paths ibgp [数]` を使用。
*   **dmz-link-bandwidth:** リンクの帯域幅に比例した不等コスト負荷分散を可能にする高度な機能です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純な設定ではなく、特定のトラフィックを特定のパスへ誘導するための「精密な属性操作」が求められます。

### 1. 送信トラフィック（Outbound）の制御

自組織からインターネット等へ出て行く通信を制御する場合、以下の属性操作が定石です。
*   **Weight:** 特定のルータ1台のみの挙動を変えたい場合。
*   **Local Preference:** 自AS内の全ルータの出口を統一したい場合。IBGPピア間で共有されるため強力です。

### 2. 受信トラフィック（Inbound）の制御

外部から自組織へ入ってくる通信を制御する場合、以下の操作が有効です。
*   **AS_PATH Prepending:** 自AS番号を複数回付与してAS_PATHを長く見せ、相手側にそのパスを避けさせます。
*   **MED (Multi-Exit Discriminator):** 隣接ASに対して、特定の入り口（リンク）を優先するように「依頼」します。ただし、相手ASのLocal Pref設定等で上書きされる可能性があります。

### 3. ネクストホップの到達性 (The Next-Hop Problem)

iBGPにおいて、eBGPから学習したルートを広報する際、デフォルトではネクストホップアドレスが書き換えられません。
*   **対策:** `neighbor next-hop-self` を設定して、自身のIPアドレスをネクストホップにする必要があります。これが欠落していると、ルートはBGPテーブルに乗りますが「最適パス（>）」にならず、RIBにも反映されません。

### 4. BGP Backdoor

同一プレフィックスをIGPとeBGPの両方で学習している場合、通常はeBGP（AD 20）がIGP（EIGRP AD 90等）より優先されます。
*   **タスク:** 「特定のセグメントにおいて、バックアップのeBGPよりもメインのIGPパスを優先せよ」という要件に対し、`network ... backdoor` コマンドを使用してeBGPのAD値を200に引き上げる手法が問われます。

### 5. Deterministic MED と Always-Compare-MED

通常、MEDは同じ隣接ASから受信したパス間でのみ比較されます。
*   **ラボ要件:** 「異なるASから受信した同じルートのMEDを比較せよ」という場合、`bgp always-compare-med` コマンドが必須です。

---

## 🛠 設定・検証コマンド

### 属性操作（ルートマップ）

| 目的 | コマンド |
| :--- | :--- |
| **Weightの設定** | <code>(config-route-map)# set weight </code> |
| **Local Preferenceの設定** | <code>(config-route-map)# set local-preference [値]</code> |
| **AS_PATH Prependの実施** | <code>(config-route-map)# set as-path prepend [AS_NUM] [AS_NUM]</code> |
| **MEDの設定** | <code>(config-route-map)# set metric [値]</code> |
| **Originの変更** | <code>(config-route-map)# set origin [igp&#124;egp&#124;incomplete]</code> |

### ベストパス・負荷分散設定

| 目的 | コマンド |
| :--- | :--- |
| **負荷分散の有効化(eBGP)** | <code>(config-router-af)# maximum-paths</code> |
| **負荷分散の有効化(iBGP)** | <code>(config-router-af)# maximum-paths ibgp</code> |
| **AS_PATH長を無視する** | <code>(config-router)# bgp bestpath as-path ignore</code> |
| **MED比較の強制(異AS間)** | <code>(config-router)# bgp always-compare-med</code> |
| **帯域幅ベース負荷分散** | <code>(config-router-af)# bgp dmz-link-bandwidth</code> |

### 検証・デバッグ

| 目的 | コマンド |
| :--- | :--- |
| **BGPテーブルの確認(最重要)** | <code>show ip bgp</code> |
| **特定のルートの詳細属性確認** | <code>show ip bgp [prefix]</code> |
| **属性の統計とサマリ** | <code>show ip bgp paths</code> |
| **ネクストホップ解決状況確認** | <code>show ip bgp rib-failure</code> |
| **決定プロセスのデバッグ** | <code>debug ip bgp [neighbor] updates</code> |

---

## 🧪 ラボ学習・設定サンプル例


### 1. Weightを用いた特定ルータの出口制御

**【問題内容】**
R1において、AS 254宛てのトラフィックを R2（10.1.12.2）経由に固定せよ。Local Preferenceは変更してはならない。

**【設定サンプル】**
```ios
ip prefix-list P-AS254 permit 200.0.0.0/8 ge 8
!
route-map RM-WEIGHT permit 10
 match ip address prefix-list P-AS254
 set weight 50000
route-map RM-WEIGHT permit 20
!
router bgp 100
 neighbor 10.1.12.2 route-map RM-WEIGHT in
```
*   **ポイント:** WeightはCiscoルータ内部でのみ有効で、最も優先順位が高い属性です。

---

### 2. Local PreferenceによるAS全体の出口統一

**【問題内容】**
自ASから外部への全トラフィックを、デフォルトのパスではなく R3 経由にするようにAS内の全ルータで設定せよ。

**【設定サンプル】**
```ios
router bgp 100
 ! 全ての受信ルートに対し、デフォルト(100)より高い値を設定
 bgp default local-preference 200
```
または、特定のピアからのルートに対して適用：
```ios
route-map RM-LP permit 10
 set local-preference 300
!
router bgp 100
 neighbor 10.1.13.3 route-map RM-LP in
```

---

### 3. AS_PATH Prependingによる受信トラフィック誘導

**【問題内容】**
外部ASから自ASへのトラフィック流入において、ISP-A側のリンクを避け、ISP-B側を優先させよ。

**【設定サンプル】**
```ios
! ISP-A側のルータで設定
route-map RM-PREPEND permit 10
 ! 自AS番号(100)を3回付与してパスを長く見せる
 set as-path prepend 100 100 100
!
router bgp 100
 neighbor [ISP-A_IP] route-map RM-PREPEND out
```

---

### 4. Origin Code操作によるパス選択への介入

**【問題内容】**
再配送（Redistribute）によって学習したルートはデフォルトで `incomplete (?)` となる。これを `IGP (i)` に変更して、パスの優先順位を引き上げよ。

**【設定サンプル】**
```ios
route-map RM-ORIGIN permit 10
 set origin igp
!
router bgp 100
 redistribute ospf 1 route-map RM-ORIGIN
```

---

### 5. MEDによる特定リンクの優先（隣接ASへの依頼）

**【問題内容】**
隣接AS 200に対し、自ASへの通信が R4 側のリンクを通るように依頼せよ。

**【設定サンプル】**
```ios
route-map RM-MED permit 10
 set metric 50  ! 低いMED値を設定
!
router bgp 100
 neighbor [AS200_R4_IP] route-map RM-MED out
```

---

### 6. Always-Compare-MEDによる異AS間MED比較

**【問題内容】**
AS 100 と AS 300 の両方から学習している同一プレフィックスに対し、AS番号が異なっていてもMED値を比較してベストパスを決定せよ。

**【設定サンプル】**
```ios
router bgp 200
 bgp always-compare-med
```

---

### 7. maximum-pathsを用いた等コスト負荷分散 (ECMP)

**【問題内容】**
BGPにおいて、AS_PATH長が同じ3つのパスを同時にルーティングテーブルにインストールし、トラフィックを分散せよ。

**【設定サンプル】**
```ios
router bgp 100
 address-family ipv4 unicast
  maximum-paths 3
```

---

### 8. BGP Backdoorの実装

**【問題内容】**
R1は `150.1.7.0/24` をEIGRP(内部)とeBGPの両方で学習している。eBGPの方がAD値が低いため優先されるが、これをEIGRP優先に変更せよ。

**【設定サンプル】**
```ios
router bgp 100
 ! backdoorオプションによりeBGPのADが200になり、EIGRP(90)が勝利する
 network 150.1.7.0 mask 255.255.255.0 backdoor
```

---

### 9. AS-Path Ignoreによる特殊なパス選定

**【問題内容】**
（トラブルシューティングシナリオ）AS_PATHの長さが異なっていても、その後のMEDやIGPメトリックで比較を続行するように設定せよ。

**【設定サンプル】**
```ios
router bgp 100
 bgp bestpath as-path ignore
```

---

### 10. Next-Hop-Selfによる到達性問題の解決

**【問題内容】**
R1（eBGPルータ）が学習したルートを iBGPピアの R2 へ伝える際、R2側でネクストホップが解決できない問題を修正せよ。

**【設定サンプル】**
```ios
router bgp 100
 neighbor 10.1.2.2 remote-as 100
 address-family ipv4 unicast
  neighbor 10.1.2.2 next-hop-self
```

---

### 11. BGP DMZ Link Bandwidthによる不等コスト負荷分散

**【問題内容】**
R5からAS 100へのトラフィックを、接続されているリンク（50Mbpsと100Mbps）の帯域幅比率に応じて分散せよ。

**【設定サンプル】**
```ios
router bgp 200
 address-family ipv4 unicast
  maximum-paths 2
  neighbor 10.1.1.1 dmz-link-bandwidth
  neighbor 10.1.4.4 dmz-link-bandwidth
```

---

### 12. Router-IDをタイブレーカーとして利用する制御

**【問題内容】**
全ての属性が同一の2つのパスがある。特定のルータを優先させるため、BGPルータIDを手動で設定してパス選定の結果を確定させよ。

**【設定サンプル】**
```ios
router bgp 100
 ! 低いRouter-IDを持つパスが最終的に勝利する
 bgp router-id 1.1.1.1
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates (Deep Dive into Decision Process)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
*   [BRKRST-3320: Troubleshooting BGP Path Selection](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### Configurationガイド
*   [BGP Best Path Selection Algorithm - Official Documentation](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)
*   [Configuring BGP Path Attributes (Cisco IOS XE)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)

### テクニカルドキュメント・設定例
*   [BGP Case Studies: Influence Path Selection with Attributes](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)
*   [BGP Load Balancing (Cisco Support)](https://www.cisco.com/c/ja_jp/support/docs/ip/border-gateway-protocol-bgp/13751-23.html)

---

## 📝 補足
- この学習メモは、BGPのパス選定プロセスを詳細なアルゴリズムのステップから、実戦的なトラブルシューティング、そして最新の負荷分散技術まで網羅しています。特に **「どの属性がどの範囲（ローカルかAS全体か）に影響を与えるか」** を理解し、適切なタイミングでルートマップを適用するスキルが、CCIE EIラボ試験合格の鍵となります。


