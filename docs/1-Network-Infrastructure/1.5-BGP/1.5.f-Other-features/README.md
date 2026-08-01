---
layout: default
title: 1.5.f-Other-features
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 6
---

# 1.5.f Other BGP Features

CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目 「1.5 BGP」における「1.5.f Other BGP features such as soft reconfiguration and route refresh」について、CCIE レベルの技術詳細、セッションの無瞬断運用、およびスケーラビリティに寄与する高度な機能を整理しました。

---

## 📘 概要

BGP (Border Gateway Protocol) は、一度 Established 状態になったネイバー間で大量のルーティング情報を交換しますが、その後にインバウンドまたはアウトバウンドのポリシー（ルートマップやフィルタ）を変更しても、デフォルトでは既存の BGP テーブルに即座に反映されません。従来、これらの変更を反映させるには BGP セッションを一度切断し、TCP コネクションを再確立する「ハードリセット」が必要でした。しかし、大規模なエンタープライズネットワークやインターネット境界においてセッションを切断することは、重大なパケットロスやコンバージェンスの嵐（フラッピング）を招く原因となります。

**Soft Reconfiguration** および **Route Refresh** は、BGP ピアリングを切断することなく、変更されたポリシーを適用するためのメカニズムです。また、Blueprint で言及されている「Other features」には、ルータのリソース保護に不可欠な **Maximum Prefix** や、障害検知を高速化する **Fast External Fallover**、そしてコントロールプレーンを保護する **BGP TTL Security** など、CCIE EI ラボ試験で実戦的な実装が問われる多くの運用管理機能が含まれています。

---

## 🔑 要点

### 1. Soft Reconfiguration Inbound (i)

ポリシーの変更を反映させるための伝統的な手法です。

*   **動作原理:** <code>neighbor [IP] soft-reconfiguration inbound</code> コマンドを有効にすると、ルータはネイバーから受信したすべての Update パケットを、フィルタリング（インバウンドポリシー）を適用する前の「生のデータ」としてメモリ（Adj-RIB-In）に保持します。
*   **メリット:** ネイバーに対して再度情報を送るよう要求することなく、自身のメモリ内のキャッシュに対して新しいポリシーを適用し直すことができます。
*   **デメリット:** すべてのルートを二重（適用後と適用前）に保持するため、ルータのメモリ（RAM）を大幅に消費します。

### 2. Route Refresh Capability (RFC 2918) (ii)

現代の BGP 実装における標準的なポリシー反映手法です。

*   **動作原理:** BGP セッション確立時の Capability Negotiation で「Route Refresh」が互いにサポートされていることを確認します。
*   **トリガー:** <code>clear ip bgp [IP] soft in</code> を実行すると、ルータはネイバーに対して「BGP Update を再送してください」という特別なメッセージ（Route Refresh メッセージ）を送信します。
*   **メリット:** メモリに不要なキャッシュを保持する必要がなく、スケーラビリティに優れています。

### 3. BGP Synchronization (iii)

歴史的な BGP のループ防止ルールであり、現在のラボ試験では主に「無効化」が前提となりますが、概念の理解は必須です。

*   **ルール:** BGP で学習したルートを他のピアに広報する前に、そのルートが IGP (OSPF/EIGRP) でも学習されていることを確認する必要があります。
*   **現代の実装:** iBGP フルメッシュやルートリフレクタが一般的になったため、デフォルトで <code>no synchronization</code> となっています。

### 4. BGP Maximum Prefix (iv)

ネイバーから学習するルート数に上限を設け、予期せぬフルルートの流入などからルータのメモリを保護します。

*   **オプション:** 上限に達した際に警告のみを出す（warning-only）、またはセッションを切断し、一定時間後に再開させる（restart）などの制御が可能です。

### 5. BGP Fast External Fallover (v)

直接接続された eBGP ネイバーとの物理リンクがダウンした際、ホールドタイムの満了を待たずに即座にセッションを終了させ、コンバージェンスを高速化します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、運用継続性を維持しながら構成を変更するシナリオが頻出します。

### 1. セッション切断の禁止

「既存のトラフィックに影響を与えずに、新しく作成したインバウンドフィルタを R1 に適用せよ」といった制約が課されることがあります。
*   **対策:** <code>clear ip bgp *</code> は絶対に使用してはいけません。<code>clear ip bgp * soft in</code> または <code>clear ip bgp * soft out</code> を使い分け、ピアリングの状態を Established のまま維持するスキルが求められます。

### 2. Adj-RIB-In の検証

「ネイバーから実際にどのようなルートがフィルタリングされずに届いているかを確認せよ」というタスク。
*   **対策:** <code>soft-reconfiguration inbound</code> を有効にした上で、<code>show ip bgp neighbors [IP] received-routes</code> を使用します。通常の <code>show ip bgp neighbors [IP] routes</code> との違い（前者はフィルタ適用前、後者は適用後）を明確に理解しておく必要があります。

### 3. Maximum Prefix による防御的実装

「AS 65001 のピアから 100 以上のルートが届いた場合、セッションを遮断し、管理者が介入するまで復旧させないようにせよ」といった要件。
*   **対策:** <code>neighbor [IP] maximum-prefix 100</code> の設定に加え、<code>restart</code> オプションを付けない（＝手動での clear が必要になる）挙動を正確に把握する必要があります。

### 4. BGP TTL Security (GTSM)

eBGP ネイバー間のスプーフィング攻撃を防止するための設定です。
*   **対策:** <code>neighbor [IP] ttl-security hops [N]</code> を設定します。これは IP パケットの TTL を 255 で送信し、受信側で 255-N 以上の TTL であることを確認する仕組みです。

---

## 🛠 設定・検証コマンド

### ポリシー反映・リフレッシュ

| 目的 | コマンド |
| :--- | :--- |
| **ソフト再構成の有効化(メモリ消費)** | <code>neighbor [IP] soft-reconfiguration inbound</code> |
| **インバウンドのソフトリセット(Route Refresh)** | <code>clear ip bgp [IP&#124;*] soft in</code> |
| **アウトバウンドのソフトリセット** | <code>clear ip bgp [IP&#124;*] soft out</code> |
| **BGPセッションのハードリセット(切断)** | <code>clear ip bgp [IP&#124;*]</code> |

### 運用・リソース保護

| 目的 | コマンド |
| :--- | :--- |
| **受信プレフィックス数の制限** | <code>neighbor [IP] maximum-prefix [COUNT] [threshold] [warning-only]</code> |
| **制限超過後の再起動タイマー** | <code>neighbor [IP] maximum-prefix [COUNT] restart [MINUTES]</code> |
| **Fast External Falloverの無効化** | <code>(config-router)# no bgp fast-external-fallover</code> |
| **TTL Security (GTSM)の有効化** | <code>neighbor [IP] ttl-security hops [HOP_COUNT]</code> |
| **BGPテーブルのスキャン時間調整** | <code>(config-router)# bgp scan-time [SECONDS]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **Route Refresh機能のサポート確認** | <code>show ip bgp neighbors [IP] &#124; include Route refresh</code> |
| **フィルタ適用「前」の受信ルート表示** | <code>show ip bgp neighbors [IP] received-routes</code> |
| **フィルタ適用「後」の受信ルート表示** | <code>show ip bgp neighbors [IP] routes</code> |
| **広報中のルート表示** | <code>show ip bgp neighbors [IP] advertised-routes</code> |
| **BGPピアの概要とMsgRcvd/Sent確認** | <code>show ip bgp summary</code> |
| **Maximum Prefixのステータス確認** | <code>show ip bgp neighbors [IP] &#124; include prefix</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIE ラボ試験の難易度と制約条件を想定した、BGP の高度な運用機能に関する 12 個の実装例です。

### 1. Route Refresh を利用した無瞬断ポリシー変更

**【問題内容】**
R1 でネイバー R2 からのルートを制限する Prefix-list を作成した。セッションを切断することなく、最新のフィルタを適用せよ。

**【設定例】**
```ios
! フィルタの作成
ip prefix-list FILTER_IN permit 10.1.0.0/16 ge 24
!
router bgp 100
 neighbor 10.1.12.2 prefix-list FILTER_IN in
!
! ソフトリセットの実行（セッションは切断されない）
R1# clear ip bgp 10.1.12.2 soft in
```

---

### 2. Soft Reconfiguration Inbound による Adj-RIB-In の可視化

**【問題内容】**
R1 において、R2 から送信されているがフィルタリングによって拒否されている「生」のルートを確認できるように設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor 10.1.12.2 soft-reconfiguration inbound
!
! 検証：フィルタ適用前の全受信ルートを確認
R1# show ip bgp neighbors 10.1.12.2 received-routes
```

---

### 3. Maximum Prefix によるルート流入制限（警告のみ）

**【問題内容】**
R1 は、カスタマー AS 65001 からのルートが 50 を超えた場合に Syslog で警告を出力するようにせよ。ただし、セッションは維持すること。

**【設定例】**
```ios
router bgp 100
 address-family ipv4 unicast
  neighbor 10.1.12.2 maximum-prefix 50 warning-only
```

---

### 4. Maximum Prefix 超過後の自動復旧

**【問題内容】**
ネイバーから 100 個以上のプレフィックスを受信した場合、セッションを遮断し、10 分後に自動的に再接続を試みるように設定せよ。

**【設定例】**
```ios
router bgp 100
 address-family ipv4 unicast
  neighbor 10.1.12.2 maximum-prefix 100 restart 10
```

---

### 5. eBGP TTL Security (GTSM) の実装

**【問題内容】**
R1 と eBGP ピアである R2 (10.1.12.2) 間のセッションを保護せよ。直接接続（1ホップ）のみを許可すること。

**【設定例】**
```ios
router bgp 100
 neighbor 10.1.12.2 ttl-security hops 1
!
! 注意：これを設定すると ebgp-multihop は自動的に無効化または共存できません。
```

---

### 6. BGP Suppress Inactive の構成

**【問題内容】**
RIB (ルーティングテーブル) にインストールされていない BGP ルートを、ネイバーへ広報しないように設定して帯域を節約せよ。

**【設定例】**
```ios
router bgp 100
 bgp suppress-inactive
```
*   **解説:** これにより、AD 値の関係で他のプロトコル（EIGRP 等）が優先されているルートが BGP で広報されるのを防ぎます。

---

### 7. Fast External Fallover の無効化

**【問題内容】**
不安定なワイヤレスリンク上で eBGP を稼働させている。物理インターフェイスのフラッピングによるセッション切断を防ぐため、リンクダウンによる即時切断を無効化せよ。

**【設定例】**
```ios
router bgp 100
 no bgp fast-external-fallover
!
! この場合、セッションの維持はホールドタイムに依存するようになります。
```

---

### 8. Outbound Route Filtering (ORF) の Capability 交渉

**【問題内容】**
R1 と R2 の間で、受信側（R1）の Prefix-list 情報を送信側（R2）へ自動通知し、送信元でフィルタリングを行わせる機能を有効化せよ。

**【設定例】**
```ios
! R1 (受信側)
router bgp 100
 neighbor 10.1.12.2 capability orf prefix-list both
 neighbor 10.1.12.2 prefix-list MY_PFX_LIST in

! R2 (送信側)
router bgp 100
 neighbor 10.1.12.1 capability orf prefix-list both
```
*   **検証:** `show ip bgp neighbors 10.1.12.1 received prefix-filter` で通知されたリストを確認します。

---

### 9. BGP Advertise-Best-External の有効化

**【問題内容】**
MPLS VPN 環境において、プライマリパスがダウンした際の切り替えを高速化するため、バックアップの eBGP パスを iBGP ピアに広報せよ。

**【設定例】**
```ios
router bgp 100
 address-family ipv4 unicast
  bgp advertise-best-external
```

---

### 10. BGP スキャン時間の最適化

**【問題内容】**
BGP テーブルと RIB の整合性チェックを 5 秒ごとに行うように変更し、ルートの変化に対する反応を早めよ。

**【設定例】**
```ios
router bgp 100
 bgp scan-time 5
```

---

### 11. BGP ネイバーのロギング強化

**【問題内容】**
ネイバーの状態が Established 以外に変化した際、詳細な原因を含めたログを出力するようにせよ。

**【設定例】**
```ios
router bgp 100
 bgp log-neighbor-changes
```

---

### 12. ピアリング認証の MD5 キー設定

**【問題内容】**
R1 と R2 の BGP セッションをパスワード「CISCO_CCIE」で認証せよ。

**【設定例】**
```ios
router bgp 100
 neighbor 10.1.12.2 password CISCO_CCIE
```
*   **検証:** `show ip bgp neighbors` で認証が有効であることを確認します。

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - セッション管理と Route Refresh の動作、スケーラビリティ機能の詳細。
*   [BRKRST-3320: Troubleshooting BGP](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - ポリシー反映がうまくいかない際、Route Refresh を使ったトラブルシュート手法。

### Configurationガイド
*   [Cisco BGP Configuration Guide: Route Refresh and Soft Reconfiguration](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-filter-config.html)。
*   [Configuring BGP Maximum Prefix](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [BGP Route Refresh Capability RFC 2918](https://tools.ietf.org/html/rfc2918)。
*   [Understanding BGP Soft Reconfiguration (Cisco Support)](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/5816-bgpfaq-5816.html)。

---

## 📝 補足
- この学習メモは、BGP セッションの安定性を維持しながら、動的にポリシーを適用・制御するための必須機能を網羅しています。CCIE EI ラボ試験では、単なる設定の正しさだけでなく、「パケットロスを発生させない運用」が厳しく問われるため、<code>soft</code> オプションを伴うコマンドの使用を習慣化することが合格への鍵となります。

