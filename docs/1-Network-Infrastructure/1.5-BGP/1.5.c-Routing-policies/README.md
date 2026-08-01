---
layout: default
title: 1.5.c-Routing-policies
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.5.c BGP Routing Policies

CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目「1.5 BGP」における「1.5.c Routing policies」について、CCIE レベルの技術詳細、トラフィックエンジニアリングの手法、および高度なポリシー制御について詳細に整理しました。

---

## 📘 概要

BGP (Border Gateway Protocol) における **Routing Policies（ルーティングポリシー）** は、単なる到達性の確保を超え、組織のビジネス要件や技術的制約に基づいてトラフィックの流入・流出を精密に制御するためのメカニズムです。IGP が最短パスを優先するのに対し、BGP は「パス属性 (Attributes)」を操作することで、自組織のネットワークを通過するデータの流れを意図的にデザインします。

BGP ポリシーの実装には、主に **Route-Maps** が使用されます。Route-Map 内でプレフィックスリストやコミュニティリストと合致（match）させ、属性を書き換える（set）ことで、ベストパス選定プロセスに介入します。CCIE EI レベルでは、特定の条件下でのみルートを広報する「条件付き広報」、ネイバーのリソースを節約する「ORF」、そしてルートにタグを付けて広報範囲を限定する「コミュニティ」などの高度な機能を組み合わせ、スケーラブルで堅牢なポリシーを構築する能力が問われます。

---

## 🔑 要点

### 1. Attribute Manipulation (i)

BGP のベストパス選定プロセスを制御するために、パス属性を操作します。

*   **Local Preference:** 自 AS 内の全ルータで共有される属性。**AS から外へ出て行くトラフィック（Outbound）** を制御する際に最も一般的に使用されます。値が高い方が優先されます。
*   **Weight (Cisco 独自):** 設定したルータ内部でのみ有効なローカル属性。複数の出口を持つ特定の 1 台のルータにおいてパスを固定したい場合に使用します。Local Preference よりも優先順位が高いです。
*   **AS_PATH Prepending:** 自 AS 番号を複数回付与してパスを長く見せる手法。**外部 AS から自 AS へ入ってくるトラフィック（Inbound）** を制御するために使用します。
*   **MED (Multi-Exit Discriminator):** 隣接する AS に対し、自 AS への入り口を指定するために送信する属性。値が低い方が優先されますが、相手 AS 内で Local Preference 等によって上書きされる可能性があります。
*   **Origin:** ルートの発生源（IGP, EGP, Incomplete）。再配送されたルート（?）を IGP (i) に変更することで優先順位を上げることができます。

### 2. Conditional Advertisement (ii)

BGP テーブル内の特定のルートの有無に基づいて、別のルートを広報するかどうかを決定する機能です。

*   **Advertise-map:** `exist-map` または `non-exist-map` と組み合わせて使用します。
*   **ユースケース:** 「メインの ISP へのルートが BGP テーブルから消えた場合のみ、バックアップパス経由で自社プレフィックスを広報する」といった、動的な冗長構成を実現します。

### 3. Outbound Route Filtering (ORF) (iii)

受信側ルータが「受け取りたくないプレフィックス」の情報を送信側ルータに伝え、送信元でフィルタリングを行わせる機能です（RFC 5291）。

*   **メリット:** アップデートの送信自体を抑制するため、ルータの CPU 負荷とネットワーク帯域を節約できます。
*   **動作:** BGP の Capability 交渉により、プレフィックスリストの情報を `Route Refresh` パケットに載せてネイバーにプッシュします。

### 4. Standard and Extended Communities (iv)

ルートに「タグ（付箋）」を付けることで、複雑なポリシー管理を簡素化します。

*   **Standard Communities:** 32 ビットの値（例: `AS:Value`）。ルートのグループ化や広報範囲の制御に使用します。
    *   **Well-known:** `no-export`（AS 外へ出さない）、`no-advertise`（誰にも渡さない）、`local-as`（サブ AS 外へ出さない）。
*   **Extended Communities:** 64 ビットの値。MPLS VPN における **Route Target (RT)** や **Route Distinguisher (RD)** 、または BGP Cost Community など、拡張的な制御に使用されます。

### 5. Multihoming (v)

複数の ISP や異なる AS に接続する設計です。

*   **冗長性:** 1 つの ISP がダウンしても通信を維持します。
*   **ポリシーの複雑化:** 自 AS が「Transit AS（通過点）」にならないよう、受信したルートを他へ再広報しない設定（AS_PATH フィルタ等）が不可欠です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる到達性だけでなく、「制約条件を満たす設計」が求められます。

1.  **トラフィックの非対称性の解決:** Outbound は Local Pref で制御できても、Inbound は相手次第です。AS_PATH Prepend やコミュニティを利用して、相手 AS のポリシーを誘導するスキルが必要です。
2.  **iBGP におけるネクストホップ解決:** `next-hop-self` をポリシーの一部として適切に配置しないと、最適パスが選出されません（RIB-Failure の原因）。
3.  **コミュニティの伝播:** デフォルトではコミュニティ属性はネイバーに送信されません。`neighbor send-community` コマンドの入力を忘れないことが合格の鉄則です。
4.  **正規表現 (Regex) の活用:** AS_PATH フィルタリングにおいて、`^$`（自 AS 発信）や `_+$`（特定の AS で終了）などの Regex を使い、大量のルートを効率的に制御する能力が問われます。
5.  **再配送時のループ防止:** IGP と BGP の間で相互再配送を行う際、コミュニティタグを付けて「二度目の再配送」を防止する構成が頻出します。

---

## 🛠 設定・検証コマンド

### ポリシー制御・属性操作

| 目的 | コマンド |
| :--- | :--- |
| **Local Preference の設定** | <code>(config-route-map)# set local-preference </code> |
| **Weight の設定** | <code>(config-route-map)# set weight </code> |
| **AS_PATH Prepend の実施** | <code>(config-route-map)# set as-path prepend [AS_NUM] [AS_NUM]...</code> |
| **MED (Metric) の設定** | <code>(config-route-map)# set metric [値]</code> |
| **コミュニティの付与** | <code>(config-route-map)# set community [no-export&#124;no-advertise&#124;AS:VAL] [additive]</code> |

### 特殊なポリシー機能

| 目的 | コマンド |
| :--- | :--- |
| **コミュニティ送信の有効化** | <code>(config-router-af)# neighbor [IP] send-community [standard&#124;extended&#124;both]</code> |
| **条件付き広報の設定** | <code>(config-router-af)# neighbor [IP] advertise-map [MAP] {exist-map&#124;non-exist-map} [MAP]</code> |
| **ORF 性能の交渉** | <code>(config-router-af)# neighbor [IP] capability orf prefix-list [both&#124;send&#124;receive]</code> |
| **ネクストホップの自己書き換え** | <code>(config-router-af)# neighbor [IP] next-hop-self</code> |
| **iBGP ルートの IGP 注入許可** | <code>(config-router)# bgp redistribute-internal</code> |

### 検証・デバッグ

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブル詳細（属性確認）** | <code>show ip bgp [prefix]</code> |
| **コミュニティが付いたルートの表示** | <code>show ip bgp community [AS:VAL]</code> |
| **ネイバーへ広報中のルート確認** | <code>show ip bgp neighbors [IP] advertised-routes</code> |
| **受信ポリシー適用後のルート確認** | <code>show ip bgp neighbors [IP] routes</code> |
| **AS_PATH アクセスリストの確認** | <code>show ip bgp as-path-access-list [ID]</code> |
| **ORF 受信状況の確認** | <code>show ip bgp neighbors [IP] received prefix-filter</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. AS_PATH Prepend による Inbound トラフィック誘導

**【問題内容】**
R1 (AS 100) は ISP-A と ISP-B に接続されている。ISP-A 側をバックアップにするため、ISP-A へ広報する自社ルートの AS_PATH を 3 回 Prepend せよ。

**【設定例】**
```ios
route-map RM-PREPEND permit 10
 set as-path prepend 100 100 100
!
router bgp 100
 neighbor [ISP-A_IP] route-map RM-PREPEND out
```

---

### 2. Local Preference を用いた AS 出口の固定

**【問題内容】**
自 AS 内のすべてのルータにおいて、宛先 8.8.8.8 へのトラフィックを R2 経由で送信するように設定せよ。

**【設定例】**
```ios
ip prefix-list P-GOOGLE permit 8.8.8.8/32
!
route-map RM-LOCALPREF permit 10
 match ip address prefix-list P-GOOGLE
 set local-preference 500
route-map RM-LOCALPREF permit 20
!
router bgp 100
 neighbor [R2_IP] route-map RM-LOCALPREF in
```

---

### 3. Community (No-Export) による広報範囲の制限

**【問題内容】**
R11 (AS 110) は特定のルート 111.0.0.0/8 を AS 2000 に広報するが、AS 2000 はこのルートをさらに外の AS へ広報してはならない。

**【設定例】**
```ios
! R11 (送信側)
route-map SET-NOEXPORT permit 10
 set community no-export
!
router bgp 110
 neighbor [R9_IP] route-map SET-NOEXPORT out
 neighbor [R9_IP] send-community
```

---

### 4. Advertise-Map による条件付き広報

**【問題内容】**
R8 において、R7 とのピアがダウンしている（R7 のルートが BGP テーブルに存在しない）場合のみ、AS 100 のプレフィックスを R4 へ広報せよ。

**【設定例】**
```ios
ip prefix-list P-R7-PFX permit 172.16.7.0/24
!
route-map NM-R7-CHECK permit 10
 match ip address prefix-list P-R7-PFX
!
router bgp 2000
 neighbor 192.1.48.4 advertise-map AM-PFX non-exist-map NM-R7-CHECK
```

---

### 5. Outbound Route Filtering (ORF) の有効化

**【問題内容】**
R1 と R2 の間でプレフィックスリストベースの ORF を有効化せよ。R1 が受け取りたいルートのみを R2 側で動的にフィルタリングさせること。

**【設定例】**
```ios
! R1 (受信側)
router bgp 100
 neighbor 10.1.12.2 capability orf prefix-list both
 neighbor 10.1.12.2 prefix-list MY-WANTED-ROUTES in

! R2 (送信側)
router bgp 100
 neighbor 10.1.12.1 capability orf prefix-list both
```

---

### 6. Origin 属性の変更によるパス優先

**【問題内容】**
OSPF から再配送されたルートはデフォルトで `incomplete (?)` となる。これを `IGP (i)` に変更して、パスの信頼性を高めよ。

**【設定例】**
```ios
route-map RM-ORIGIN permit 10
 set origin igp
!
router bgp 100
 redistribute ospf 1 route-map RM-ORIGIN
```

---

### 7. Regex を用いた特定 AS 起点のルートフィルタ

**【問題内容】**
AS 300 から発生したルート（AS_PATH の最後が 300）のみを許可し、他は破棄せよ。

**【設定例】**
```ios
ip as-path access-list 1 permit _300$
!
router bgp 100
 neighbor 10.1.13.3 filter-list 1 in
```

---

### 8. Extended Community (Route Target) による VRF 統合

**【問題内容】**
VRF 'Customer_A' と 'Customer_B' をマージするため、お互いのルートをインポートできるよう RT を追加せよ。

**【設定例】**
```ios
ip vrf Customer_A
 route-target import 1:1001
!
route-map CE_EXPORT permit 10
 set extcommunity rt 1:1001 additive
!
ip vrf Customer_A
 export map CE_EXPORT
```

---

### 9. BGP Backdoor による IGP パスの優先

**【問題内容】**
eBGP (AD 20) で学習している 10.1.1.0/24 を、AD の高い EIGRP (AD 90) 経由で優先して到達するように設定せよ。

**【設定例】**
```ios
router bgp 100
 network 10.1.1.0 mask 255.255.255.0 backdoor
```
*   **解説:** `backdoor` オプションにより、該当ルートの BGP AD が 200 になり、EIGRP が勝利します。

---

### 10. Next-Hop-Self の一括適用 (Peer-Group)

**【問題内容】**
iBGP ピアグループ 'INTERNAL' に対し、外部ルートのネクストホップを自身の IP に書き換えるよう設定せポ。

**【設定例】**
```ios
router bgp 100
 neighbor INTERNAL peer-group
 neighbor INTERNAL next-hop-self
 neighbor 10.1.1.2 peer-group INTERNAL
```

---

### 11. MED による特定リンクへのトラフィック誘導

**【問題内容】**
隣接 AS 200 に対し、自 AS への入り口として R4 側のリンクを優先するように低い MED (50) を送信せよ。

**【設定例】**
```ios
route-map RM-MED permit 10
 set metric 50
!
router bgp 100
 neighbor [AS200_R4_IP] route-map RM-MED out
```

---

### 12. Multihoming における Transit 禁止設定

**【問題内容】**
2 つの ISP に接続している R1 において、ISP-A から学習したルートを ISP-B へ広報（Transit）しないように AS_PATH フィルタを適用せよ。

**【設定例】**
```ios
! 自AS(100)から発生したルートのみを許可するRegex (^$)
ip as-path access-list 10 permit ^$
!
router bgp 100
 neighbor [ISP-B_IP] filter-list 10 out
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - 属性操作とベストパス選定の深い解説。
*   [BRKRST-3320: Troubleshooting BGP](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - ポリシー不整合によるルーティングトラブルの解決。

### Configurationガイド
*   [BGP Case Studies: Influencing Path Selection](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html) - 属性操作の定番ドキュメント。
*   [Configuring BGP Route Filtering](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-filter-config.html) - フィルタリングとコミュニティの公式ガイド。

### テクニカルドキュメント・設定例
*   [BGP Best Path Selection Algorithm](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html) - 決定プロセスの詳細ステップ。
*   [Understanding BGP Communities](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/28784-bgp-community.html) - コミュニティ活用の技術解説。

---

## 📝 補足
- この学習メモは、BGP のポリシー制御が「どの属性を、どのタイミングで、どの方向に適用するか」という論理的なパズルであることを示しています。CCIE EI ラボ試験では、特にコミュニティを用いたタグ付けと、Regex を利用した正確なパス抽出が、迅速なトラブル解決の鍵となります。


