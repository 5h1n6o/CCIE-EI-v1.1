---
layout: default
title: 1.5.e-Convergence
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.5.e BGP Convergence and Scalability

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.5 BGP」における「1.5.e Convergence and scalability」について、ルートリフレクタ（RR）およびルート集約（Aggregation）の詳細な動作原理、設計上の課題、およびラボ試験での高度な実装シナリオを整理しました。

---

## 📘 概要

BGPは数百万規模のルートを処理するように設計されていますが、ネットワークの規模が拡大するにつれて「iBGPフルメッシュの制限」と「ルーティングテーブル（RIB）の肥大化」という2つの大きなスケーラビリティの壁に直面します。

**Route Reflectors (RR)** は、iBGPのスプリットホライゾンルール（iBGPピアから学習したルートを別のiBGPピアに転送しない）を数学的な整合性を保ちながら緩和し、フルメッシュ構成の必要性を排除する技術です。これにより、ピアリングの数を $O(n^2)$ から $O(n)$ へと劇的に削減し、コントロールプレーンの負荷を軽減します。

**Aggregation (ルート集約)** は、複数の詳細なプレフィックスを単一のサマリルートにまとめ、BGPテーブルのサイズを抑制する技術です。単なる情報の削減だけでなく、詳細ルートのフラッピングがネットワーク全体に与える影響を遮断し、コンバージェンスの安定化（スロットリングの回避）にも寄与します。CCIEレベルでは、属性の継承やループ防止のための `as-set`、および条件付き集約の精密な制御が求められます。

---

## 🔑 要点

### 1. Route Reflectors (RR) の動作原理とルール (i)

RRは、特定のピアを「クライアント」として定義し、以下の反射ルール（Reflection Rules）に従ってアップデートを転送します。

*   **クライアントから受信:** クライアント、非クライアントの両方に反射する。
*   **非クライアントから受信:** クライアントにのみ反射する。
*   **ループ防止メカニズム:** 
    *   **Originator_ID (Optional Non-transitive):** ルートを生成したルータのRouter-ID。自身のIDが含まれるルートを受信した場合は破棄する。
    *   **Cluster_List (Optional Non-transitive):** 反射したRRのCluster-IDを記録するリスト。自身のCluster-IDが含まれていればループと見なす。

### 2. BGP Aggregation の高度な制御 (ii)

Cisco IOSでは `aggregate-address` コマンドを使用して集約を行います。

*   **summary-only:** 集約ルートのみを広報し、すべての詳細ルート（Specific routes）を抑制する。
*   **as-set:** 集約ルートに詳細ルートが持っていたAS_PATH情報を付与する。
    *   **重要:** これにより、詳細ルートが異なるASから来ていた場合に集約ルートが自身のASへ戻ることを防ぎ、ループを防止する。
*   **suppress-map / unsuppress-map:** 特定のルートだけを隠す、あるいは特定のピアにだけ詳細を見せるといった精密な制御を可能にする。
*   **attribute-map / advertise-map:** 集約ルート自体のLocal Preference等の属性を上書きしたり、どの詳細ルートが集約ルートの属性に影響を与えるかを選択したりする。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純な設定ではなく、BGPの「副作用」を考慮した設計能力が問われます。

### 1. RRにおける Next-Hop 解決の罠

RRはデフォルトで、反射するルートの **Next-Hop 属性を変更しません**。
*   **ラボの罠:** クライアントがeBGPピアのNext-Hopに到達できない場合、RRがルートを反射してもクライアント側で「ベストパス」になりません。
*   **対策:** RR側で `neighbor [client] next-hop-self` を設定するか、IGPでNext-Hopへの到達性を確保する必要があります。

### 2. 冗長RRと Cluster-ID

2台のRRで冗長性を確保する場合、同じ Cluster-ID を使うべきか、異なる ID を使うべきかの判断が求められます。
*   **同じID:** 片方のRRが反射したルートをもう片方が受け取った際、Cluster-IDの一致により破棄される（メモリ節約）。
*   **異なるID:** 両方のRRが同じルートを保持できる（冗長性は高いがテーブルが増大）。

### 3. Aggregation と AS_PATH の不連続性

`as-set` を付けずに集約を行うと、AS_PATH 情報が失われ、AS番号 1 つ分（自AS）だけのパスとして広告されます。
*   **試験のポイント:** 外部ASから受信したプレフィックスを再度外部ASへ集約して出す場合、`as-set` が無いとループが発生し、ネイバーがルートを拒否（Denied due to: AS-PATH contains our own AS）する原因となります。

### 4. Atomic Aggregate と情報の欠落

`summary-only` を設定すると、集約ルートには `Atomic_Aggregate` 属性が付与されます。これは「詳細情報の一部が意図的に破棄された」ことを下位のルータに伝える信号です。

---

## 🛠 設定・検証コマンド

### Route Reflector 関連

| 目的 | コマンド |
| :--- | :--- |
| **クライアントの指定** | <code>neighbor [IP] route-reflector-client</code> |
| **Cluster-ID の設定 (冗長時)** | <code>(config-router)# bgp cluster-id [A.B.C.D]</code> |
| **Next-Hop-Self の反射適用** | <code>neighbor [IP] next-hop-self [all]</code> |
| **動的ネイバーの RR 受付** | <code>bgp listen range [NW] peer-group [NAME]</code> |

### Aggregation 関連

| 目的 | コマンド |
| :--- | :--- |
| **基本集約(詳細も広報)** | <code>aggregate-address [IP] [MASK]</code> |
| **サマリのみ広報** | <code>aggregate-address [IP] [MASK] summary-only</code> |
| **ASパス情報を保持** | <code>aggregate-address [IP] [MASK] as-set</code> |
| **特定ルートのみ抑制** | <code>aggregate-address [IP] [MASK] suppress-map [MAP]</code> |
| **集約ルートの属性変更** | <code>aggregate-address [IP] [MASK] attribute-map [MAP]</code> |

### 検証・デバッグ

| 目的 | コマンド |
| :--- | :--- |
| **BGPテーブル概要** | <code>show ip bgp summary</code> |
| **集約属性(AS_SET等)の確認** | <code>show ip bgp [prefix]</code> |
| **Originator/Cluster情報の確認** | <code>show ip bgp [prefix] &#124; include Originator</code> |
| **抑制されている詳細ルート表示** | <code>show ip bgp suppressed-routes</code> |
| **RRの動作デバッグ** | <code>debug ip bgp updates</code> |

---

## 🧪 ラボ学習・設定サンプル例

CCIEレベルの複雑な制約を含む12の実装シナリオです。

### 1. シンプルな Route Reflector の構成

**【問題】**
R1 を RR、R2, R3 をクライアントとして AS 100 内で iBGP を構成せよ。フルメッシュは使用しない。

**【設定】**
```ios
! R1 (RR)
router bgp 100
 neighbor 2.2.2.2 remote-as 100
 neighbor 2.2.2.2 route-reflector-client
 neighbor 3.3.3.3 remote-as 100
 neighbor 3.3.3.3 route-reflector-client
```

---

### 2. RR における Next-Hop-Self の強制適用

**【問題】**
RR（R1）が eBGP から学習したルートをクライアントに反射する際、Next-Hop を自身の Loopback アドレスに書き換えて広報せよ。

**【設定】**
```ios
router bgp 100
 address-family ipv4 unicast
  neighbor 2.2.2.2 next-hop-self
  neighbor 3.3.3.3 next-hop-self
```
*   **ポイント:** RRは反射時にNext-Hopを保持するのが基本動作であるため、明示的な `next-hop-self` 設定が重要です。

---

### 3. summary-only による詳細ルートの完全抑制

**【問題】**
R4 配下の `204.1.4.0/24` 〜 `204.1.7.0/24` を `204.1.4.0/22` に集約せよ。外部ピア R6 には詳細ルートを一切見せてはならない。

**【設定】**
```ios
router bgp 200
 aggregate-address 204.1.4.0 255.255.252.0 summary-only
```
*   **検証:** `show ip bgp` で集約ルートに 's' (suppressed) マークが付いていることを確認します。

---

### 4. as-set を用いたループ防止

**【問題】**
複数の異なるASから学習したルートを集約する際、ループ防止のために元のAS_PATH情報を集約ルートに含めよ。

**【設定】**
```ios
router bgp 100
 aggregate-address 172.16.0.0 255.255.0.0 as-set
```
*   **解説:** 集約ルートのAS_PATHに `{AS_A, AS_B}` のような形式で元の情報が入り、該当ASにルートが戻った際に拒否されるようになります。

---

### 5. suppress-map による選択的なルート広報

**【問題】**
`10.0.0.0/8` を集約せよ。ただし、`10.1.1.0/24` だけは詳細ルートとして広報し、他の詳細ルートは抑制せよ。

**【設定】**
```ios
ip prefix-list P_KEEP permit 10.1.1.0/24
!
route-map RM_SUPPRESS deny 10
 match ip address prefix-list P_KEEP
route-map RM_SUPPRESS permit 20
!
router bgp 100
 aggregate-address 10.0.0.0 255.0.0.0 suppress-map RM_SUPPRESS
```
*   **ポイント:** suppress-map で `permit` されたものが抑制され、`deny` されたものが「抑制されない（＝広報される）」動作になります。

---

### 6. attribute-map による集約ルートの Local Preference 変更

**【問題】**
生成する集約ルートの Local Preference を 500 に設定し、AS内の優先度を上げよ。

**【設定】**
```ios
route-map RM_ATTR permit 10
 set local-preference 500
!
router bgp 100
 aggregate-address 192.168.0.0 255.255.0.0 attribute-map RM_ATTR
```

---

### 7. advertise-map による「属性コピー元」の限定

**【問題】**
集約ルートを生成する際、AS 300 から学習した詳細ルートの属性（AS_PATH等）だけを集約ルートに反映させよ。

**【設定】**
```ios
ip as-path access-list 30 permit _300$
!
route-map RM_ADV permit 10
 match as-path 30
!
router bgp 100
 aggregate-address 10.0.0.0 255.0.0.0 as-set advertise-map RM_ADV
```
*   **解説:** これにより、特定の詳細ルートが消えた場合に集約ルートの属性が不用意に変化するのを防ぎます。

---

### 8. 冗長 RR における同一 Cluster-ID の構成

**【問題】**
R1 と R2 を冗長 RR とし、Cluster-ID `1.1.1.1` を設定して、お互いが反射したルートを二重に処理しないようにせよ。

**【設定】**
```ios
! R1 & R2 共通
router bgp 100
 bgp cluster-id 1.1.1.1
 neighbor [client] route-reflector-client
```

---

### 9. Dynamic Neighbors による RR クライアントの自動収容

**【問題】**
RR (R9) において、`10.1.1.0/24` 範囲のルータからの iBGP 接続を自動的に RR クライアントとして受け入れよ。

**【設定】**
```ios
router bgp 100
 neighbor CLIENT_GROUP peer-group
 neighbor CLIENT_GROUP remote-as 100
 neighbor CLIENT_GROUP route-reflector-client
 !
 bgp listen range 10.1.1.0/24 peer-group CLIENT_GROUP
```
*   **重要:** 大規模環境での設定ミスを減らすための CCIE 推奨タスクです。

---

### 10. unsuppress-map による特定のピアへの詳細公開

**【問題】**
グローバルで `summary-only` 集約を行っているが、特定の隣接ルータ（10.1.1.2）にだけは、抑制されている詳細ルート `10.1.50.0/24` を送信せよ。

**【設定】**
```ios
ip prefix-list P_SPECIAL permit 10.1.50.0/24
!
route-map RM_UNSUPPRESS permit 10
 match ip address prefix-list P_SPECIAL
!
router bgp 100
 neighbor 10.1.1.2 unsuppress-map RM_UNSUPPRESS
```
*   **検証:** 10.1.1.2 側で `show ip bgp` を実行し、他のピアには無い詳細ルートが見えることを確認します。

---

### 11. Hierarchical Route Reflector (階層型RR)

**【問題】**
コアRR（R1）の下に、エリアRR（R2）を配置せよ。R2はR1のクライアントであり、かつR3のRRでもある構成とする。

**【設定】**
```ios
! R2 (中継RR)
router bgp 100
 neighbor 1.1.1.1 remote-as 100  ! コアRR
 ! R3にとってのRRとなる
 neighbor 3.3.3.3 remote-as 100
 neighbor 3.3.3.3 route-reflector-client
```

---

### 12. Aggregation と Null0 スタティックの自動生成

**【問題】**
集約を設定した際、ルーティングループを防ぐために生成される Null0 経路を確認せよ。

**【検証】**
```ios
R1# show ip route static
! S 10.0.0.0/8 [200/0] is a summary, Null0
```
*   **注意:** 集約ルートのAD値はデフォルト 200 です。これが既存の経路と競合しないよう注意が必要です。

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - RRのループ防止属性と集約オプションの深い解説。
*   [BRKRST-3320: Troubleshooting BGP](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - AggregationによるAS_PATHループのトラブル解決。

### Configurationガイド
*   [IP Routing: BGP Configuration Guide - Route Reflectors](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-int-features.html)。
*   [Understanding BGP Route Aggregation (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/5441-aggregation.html)。

### テクニカルドキュメント・設定例
*   [BGP Case Studies: Scalability (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)。
*   [BGP Attributes: Atomic Aggregate and AS_SET](http://www.networkers-online.com/blog/2010/12/bgp-attributes-atomic-aggergate-atribute/)。

---

## 📝 補足
- この学習メモは、BGPのスケーラビリティ機能が「情報をいかに効率よく整理（Aggregation）し、かつ安全に配布（RR）するか」という目的のために設計されていることを強調しています。特に、RRにおける `Originator_ID` / `Cluster_List` の役割と、Aggregationにおける `as-set` の有無がもたらすループの危険性は、CCIE実技試験におけるトラブルシューティングの最重要ポイントです。

