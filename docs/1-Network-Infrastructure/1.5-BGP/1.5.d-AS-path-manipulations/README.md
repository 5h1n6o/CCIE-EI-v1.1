---
layout: default
title: 1.5.d-AS-path-manipulations
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.5.d AS Path Manipulations

CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目「1.5 BGP」における「1.5.d AS path manipulations」について、CCIE レベルの技術詳細、トラフィックエンジニアリング、および複雑な移行シナリオについて詳細に整理しました。

---

## 📘 概要

BGP (Border Gateway Protocol) は「パスベクトル型」プロトコルであり、**AS_PATH** 属性はループ防止とパス選定（Best Path Selection）の両方で中心的な役割を果たします。AS_PATH には、経路が宛先に到達するために通過した AS 番号のリストが格納されており、デフォルトでは AS_PATH が短い経路が優先されます。

**AS Path Manipulations（AS パス操作）** は、この AS_PATH 属性を意図的に書き換えることで、トラフィックの流れを制御したり、AS の統合・移行を円滑に進めたりするための高度な技術群です。CCIE EI レベルでは、自組織への流入トラフィックを制御する「AS Path Prepending」、移行期に自身の AS を偽装する「local-as」、MPLS VPN 等の特殊環境で自身の AS を許容する「allowas-in」、そして膨大な BGP テーブルから特定のパスを抽出するための「Regular Expressions (Regex)」の完全な習熟が求められます。

---

## 🔑 要点

### 1. local-as, allowas-in, remove-private-as (i)

これらの機能は、主に AS の移行、企業の合併・買収、または特殊なトポロジ設計において使用されます。

*   **local-as:** ルータが本来所属している AS 番号とは異なる AS 番号を使用して、特定のピアとセッションを確立できるようにします。
    *   **no-prepend:** 送信ルートの AS_PATH に実際の AS 番号を付与せず、local-as 番号のみを付与します。
    *   **replace-as:** 受信したルートの AS_PATH から実際の AS 番号を local-as 番号に置き換えます。
    *   **dual-as:** 新旧両方の AS 番号でのピアリング確立を一時的に許可します。
*   **allowas-in:** BGP の標準的なループ防止機能を緩和し、AS_PATH 内に自身の AS 番号が含まれていてもルートを受理できるようにします。
    *   **ユースケース:** MPLS VPN 環境で、異なる拠点が同じ AS 番号を使用している場合に必須となります。
*   **remove-private-as:** eBGP ピアへルートを広告する際、AS_PATH からプライベート AS 番号（64512 ～ 65535）を削除します。
    *   **条件:** AS_PATH の中にパブリック AS 番号が含まれている場合、その手前にあるプライベート AS のみが削除対象となります。

### 2. AS Path Prepending (ii)

自組織への **インバウンド（流入）トラフィック** を制御するための最も一般的な手法です。

*   **動作原理:** 特定のネイバーに対し、自身の AS 番号を複数回付与した AS_PATH を広告します。
*   **効果:** 相手側のルータから見てそのパスが「より長い」と判断されるため、 prepending を行っていない別のパスが優先されるようになります。
*   **注意点:** BGP のベストパス選定プロセスにおいて、AS_PATH 長の比較は Local Preference よりも優先順位が低いため、相手側で Local Preference が設定されている場合は効果がありません。

### 3. Regular Expressions (Regex) (iii)

AS_PATH フィルタリング（filter-list）において、特定のパターンを持つパスを効率的に抽出するために使用されます。

| メタ文字 | 意味 |
| :--- | :--- |
| **.** | 任意の 1 文字に一致。 |
| ***** | 直前の文字の 0 回以上の繰り返し。 |
| **+** | 直前の文字の 1 回以上の繰り返し。 |
| **?** | 直前の文字の 0 回または 1 回の出現。 |
| **^** | 文字列の先頭（AS_PATH の始まり）。 |
| **$** | 文字列の末尾（AS_PATH の終わり）。 |
| **_** | 境界（スペース、カンマ、先頭、末尾など）。 |
| **[ ]** | 括弧内のいずれか 1 文字。 |

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なるコマンドの入力ではなく、特定のビジネス要件を満たすための「最適な操作」の選択が問われます。

### 1. 企業合併に伴う AS 移行 (local-as の活用)

「AS 65001 の企業が AS 100 の企業に買収された。既存の顧客とのピアリング設定を変更することなく、AS 100 のルータとして動作を開始せよ」といったシナリオが出題されます。
*   **対策:** `neighbor [IP] local-as 65001 no-prepend replace-as` などのオプションを駆使し、顧客側から見て何も変わっていないように見せつつ、内部的には新しい AS で運用する構成をマスターする必要があります。

### 2. インバウンドトラフィックの精密誘導

「ISP-A 側のリンクをバックアップとし、プライマリリンクがダウンした時のみ流入を許可せよ」という課題。
*   **対策:** `set as-path prepend` を使用しますが、何回 Prepend すれば他方の ISP パスを上回れるかを `show ip bgp` で確認し、動的に調整するスキルが求められます。

### 3. Regex による高度なフィルタリング

「自 AS から発生したルートのみを許可せよ」「特定の AS を通過してきたルートを拒否せよ」といった制約。
*   **対策:** 
    *   自 AS 発信: `^$`
    *   AS 200 から直接受信したルート: `^200_`
    *   AS 300 で発生したルート: `_300$`
    *   AS 400 を通過したルート: `_400_`
*   `show ip bgp regexp [PATTERN]` コマンドを使用して、フィルタを適用する前に結果を検証する癖をつけることが合格の鍵です。

### 4. プライベート AS の隠蔽

「インターネットへルートを出す際、内部で使用しているプライベート AS 情報をすべて削除せよ」というタスク。
*   **対策:** `neighbor [IP] remove-private-as` を設定します。もし AS_PATH 内に自身のパブリック AS よりも先にプライベート AS がある場合にどう動くかを理解している必要があります。

---

## 🛠 設定・検証コマンド

### AS Path 操作コマンド

| 目的 | コマンド |
| :--- | :--- |
| **AS Path Prepend の設定** | <code>(config-route-map)# set as-path prepend [AS_NUM] [AS_NUM]...</code> |
| **local-as の構成** | <code>(config-router-af)# neighbor [IP] local-as [AS_NUM] [no-prepend] [replace-as] [dual-as]</code> |
| **自身の AS 包含を許可** | <code>(config-router-af)# neighbor [IP] allowas-in [回数]</code> |
| **プライベート AS の削除** | <code>(config-router-af)# neighbor [IP] remove-private-as</code> |
| **AS PATH ACL の作成** | <code>(config)# ip as-path access-list [ID] [permit&#124;deny] [REGEX]</code> |
| **フィルタリストの適用** | <code>(config-router-af)# neighbor [IP] filter-list [ID] [in&#124;out]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブルと AS_PATH 確認** | <code>show ip bgp</code> |
| **Regex パターンのテスト(最重要)** | <code>show ip bgp regexp [PATTERN]</code> |
| **特定ピアへの広報ルート確認** | <code>show ip bgp neighbors [IP] advertised-routes</code> |
| **特定ピアからの受信ルート確認** | <code>show ip bgp neighbors [IP] routes</code> |
| **AS PATH ACL の一致確認** | <code>show ip bgp filter-list [ID]</code> |
| **Update パケットのデバッグ** | <code>debug ip bgp updates</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 基本的な AS Path Prepending による経路誘導

**【問題内容】**
R1 (AS 100) は、ネイバー R2 (AS 200) に対して、自身の Loopback 0 経路を広告する際、AS_PATH を 3 回 Prepend して「100 100 100 100」として送信せよ。

**【設定例】**
```ios
ip prefix-list LO0_R1 seq 5 permit 10.1.1.1/32
!
route-map PREPEND_RM permit 10
 match ip address prefix-list LO0_R1
 set as-path prepend 100 100 100
route-map PREPEND_RM permit 20
!
router bgp 100
 neighbor 10.1.12.2 route-map PREPEND_RM out
```

---

### 2. remove-private-as による内部トポロジの隠蔽

**【問題内容】**
ISP ルータ R10 は、プライベート AS 65001 を使用している顧客 R11 からのルートを受信する。このルートを他のパブリック AS へ広報する際、AS_PATH からプライベート AS 番号を削除せよ。

**【設定例】**
```ios
router bgp 10
 address-family ipv4 unicast
  neighbor 192.1.1.2 remote-as 20
  neighbor 192.1.1.2 remove-private-as
```

---

### 3. local-as を使用したシームレスな移行

**【問題内容】**
R5 は本来 AS 65005 に属しているが、移行期間中、隣接する R2 に対してのみ AS 5 として振る舞うように設定せよ。R2 に届くルートには R5 の真の AS（65005）が現れないようにすること。

**【設定例】**
```ios
router bgp 65005
 neighbor 10.1.25.2 remote-as 65001
 address-family ipv4 unicast
  ! no-prepend で真のASを隠し、replace-as で local-as に置き換える
  neighbor 10.1.25.2 local-as 5 no-prepend replace-as
```

---

### 4. Regex による「自 AS 発信ルート」の抽出

**【問題内容】**
R1 において、AS_PATH が空である（＝自 AS 内で生成された）ルートのみを表示して確認せよ。

**【操作と検証】**
```ios
R1# show ip bgp regexp ^$
! 出力結果には、パス属性が空または "i" のみのルートが表示される
```

---

### 5. allowas-in による Hub-and-Spoke 通信の許可

**【問題内容】**
MPLS VPN 環境において、サイト A (AS 100) とサイト B (AS 100) が PE ルータを介して通信する必要がある。PE から学習したルートに自身の AS 100 が含まれていても、3 回までは許容するように設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor [PE_IP] remote-as 200
 address-family ipv4 unicast
  neighbor [PE_IP] allowas-in 3
```

---

### 6. Regex による特定 AS 起点のルートフィルタリング

**【問題内容】**
AS 300 から発生したルート（AS_PATH の末尾が 300）のみを受信し、それ以外はすべて拒否せよ。

**【設定例】**
```ios
ip as-path access-list 1 permit _300$
!
router bgp 100
 neighbor 10.1.13.3 filter-list 1 in
```

---

### 7. local-as dual-as による移行期の互換性維持

**【問題内容】**
AS 100 から AS 200 への変更作業中、ネイバー R8 がまだ旧 AS 100 で設定されている間でも、新旧両方の AS 番号でセッションを張れるようにせよ。

**【設定例】**
```ios
router bgp 200
 neighbor 10.1.18.8 remote-as 100
 address-family ipv4 unicast
  neighbor 10.1.18.8 local-as 100 dual-as
```

---

### 8. Regex を用いた「特定 AS を通過したルート」の拒否

**【問題内容】**
AS 500 を通過してきた（経由地として含まれる）すべてのルートを拒否するようにフィルタを作成せよ。

**【設定例】**
```ios
ip as-path access-list 10 deny _500_
ip as-path access-list 10 permit .*
!
router bgp 100
 neighbor [ISP_IP] filter-list 10 in
```

---

### 9. AS Path Prepend を利用した不等コスト負荷分散への介入

**【問題内容】**
R1 は 2 つの eBGP パスを持っている。AS_PATH 長が異なるため等コスト負荷分散 (ECMP) が行われない。短い方のパスに自身の AS を 1 回 Prepend して長さを揃え、ECMP を可能にせよ。

**【設定例】**
```ios
route-map MATCH_LENGTH permit 10
 set as-path prepend 100
!
router bgp 100
 neighbor [SHORT_PATH_IP] route-map MATCH_LENGTH out
 maximum-paths 2
```

---

### 10. Regex による「連続して Prepend されたルート」の検出

**【問題内容】**
AS 200 が自身の AS 番号を複数回 Prepend して送ってきているルート（例：200 200 200）のみを検出し、フィルタリングせよ。

**【設定例】**
```ios
! 同じ数字(200)が2回以上繰り返されているパターンをマッチさせる
ip as-path access-list 15 deny _(200)_\1_
ip as-path access-list 15 permit .*
!
router bgp 100
 neighbor 10.1.12.2 filter-list 15 in
```

---

### 11. remove-private-as とパブリック AS 混在時の挙動確認

**【問題内容】**
AS_PATH が 「65001 200 65002」となっているルートに対し、remove-private-as を適用した際の結果を予測し、設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor [PEER_IP] remove-private-as
!
! 解説：末尾（右側）の 65002 は、パブリック AS 200 よりも後にあるため削除されない。
! 削除されるのは先頭（左側）の 65001 のみ。
```

---

### 12. Regex による特定ベンダー/地域 AS の一括制御

**【問題内容】**
AS 番号が 655xx (プライベート AS の一部) で始まるすべてのルートに対し、Local Preference を 50 に下げて優先順位を落とせ。

**【設定例】**
```ios
ip as-path access-list 20 permit ^655_
!
route-map LOWER_PRIO permit 10
 match as-path 20
 set local-preference 50
route-map LOWER_PRIO permit 20
!
router bgp 100
 neighbor [PEER_IP] route-map LOWER_PRIO in
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates (Deep Dive into AS_PATH)](https://www.ciscolive.com/global/on-demand-library.html)。
*   [BRKRST-3320: Troubleshooting BGP (AS Path Manipulations & Regex)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)。

### Configurationガイド
*   [BGP Case Studies: Influence Path Selection with AS_PATH](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)。
*   [Configuring BGP Local AS - Cisco IOS XE](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-local-as.html)。

### テクニカルドキュメント・設定例
*   [BGP Best Path Selection Algorithm (AS_PATH step)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)。
*   [Using Regular Expressions in BGP (Tech Note)](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13750-22.html)。

---

## 📝 補足
- この学習メモは、BGP の AS_PATH 操作を「単なるフィルタリング」ではなく、「組織の境界をまたぐトラフィックデザインと移行の戦略」として定義しています。CCIE EI ラボ試験では、Regex を用いた正確なパスの絞り込みと、local-as による無停止移行の構成が非常に高い配点を持つため、実機（EVE-NG/CML）でのパケットキャプチャを伴う検証が推奨されます。
