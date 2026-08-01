---
layout: default
title: 1.3.e-Optimization
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

1.3.e EIGRP Optimization, Convergence, and Scalability

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.3 EIGRP」における「1.3.e Optimization, convergence, and scalability」について整理しました。

---

## 📘 概要

**EIGRPの最適化、コンバージェンス、およびスケーラビリティ**は、大規模なエンタープライズネットワークにおいて、プロトコルの安定性を維持するための最重要トピックです。EIGRPはDUAL（Diffusing Update Algorithm）アルゴリズムにより、最適パス（Successor）の消失時にバックアップパス（Feasible Successor）があれば即座に切り替わりますが、バックアップが存在しない場合、ネットワーク全体に **Query（問い合わせ）パケット** を送信して代替パスを探します。

このQueryプロセスは、ネットワークが巨大化・複雑化すると **SIA (Stuck-in-Active)** 状態を引き起こし、隣接関係の不必要な切断やコンバージェンスの遅延を招く原因となります。CCIEレベルでは、**「Query伝播境界（Query Propagation Boundaries）」** を意図的に設計・構築し、不要なパケットの拡散を抑える能力が問われます。これには、ルートの集約（Summarization）、Stubルータの構成、およびこれらに例外を設ける Leak-map の高度な活用が含まれます。

---

## 🔑 要点

### 1. Query伝播境界 (Query Propagation Boundaries)

EIGRPルータが「Active」状態になり、ネイバーにQueryを送信した際、その伝播を止める「壁」の役割を果たすのが境界設計です。

| 手法 | 動作原理 | 効果 |
| :--- | :--- | :--- |
| **Summarization** | 特定の境界で詳細ルートを集約して広報する。 | 集約ルートの範囲内のより詳細なルートが消失しても、ルータはその境界を超えてQueryを送信しません。 |
| **EIGRP Stub** | ルータをStub（末端）として設定し、ハブに通知する。 | ハブルーバは、Stubルータが「代替パスを持っていない」ことを事前に把握するため、スポーク（Stub）にQueryを送信しません。 |

### 2. ルート集約と Leak-map (Leak-map with Summary Routes)

手動集約（Manual Summarization）を行うと、そのインターフェイスからは集約されたプレフィックスのみが送信され、詳細なプレフィックスは抑制されます。
*   **Leak-map:** 集約を行いながらも、特定の詳細ルートだけを「漏らして（Leak）」広報する機能です。
*   **用途:** 拠点の経路を集約してコアのRIBを節約しつつ、特定のサーバセグメントだけはトラフィックエンジニアリングのために詳細情報を残したい場合に使用します。

### 3. EIGRP Stub と Leak-map (EIGRP Stub with Leak-map)

EIGRP Stubはデフォルトで「connected」と「summary」を広報しますが、これに `leak-map` を組み合わせることで、Stubの制限を維持しつつ特定の経路（例：再配送されたルート）を追加で許可できます。
*   **動作:** Stub設定によりQueryの受信を拒否しつつ、本来なら広報されないはずのルートを対向に伝えることが可能です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、ネットワークの安定化と特定の到達性要件を両立させる「制約付きの最適化」が問われます。

### 1. SIA (Stuck-in-Active) の防止

*   大規模トポロジにおいて、一部のルータがSIAに陥るシナリオがトラブルシューティングとして出題されます。
*   **対策:** 適切なポイントでの `ip summary-address` 設定や、拠点への `eigrp stub` 適用によりQueryの拡散を止め、Replyの待機時間を短縮します。

### 2. Manual Summarization の実装場所

*   Classic Modeではインターフェイス配下、Named Modeでは `af-interface` 配下で設定します。
*   **注意:** 集約を設定すると、自動的に `Null0` への経路が生成され、ルーティングループを防止します。ラボでは、この `Null0` 経路の影響（特定のパケットが破棄される等）を考慮する必要があります。

### 3. Stub オプションの使い分け

試験要件に応じて、適切なStubオプションを選択する能力が必要です。
*   `receive-only`: 自身のルートを一切広告しない。
*   `connected`: 直結ルートのみ広告。
*   `static`: スタティックルートのみ広告。
*   `summary`: 集約ルートのみ広告。
*   `redistributed`: 再配送されたルートのみ広告。

### 4. 最小コマンド数での実装

*   Named Modeにおいて `af-interface default` を使用して一括で設定を適用し、特定のインターフェイスのみ例外を作る手法は、解答の簡潔さを求める問題で有効です。

---

## 🛠 設定・検証コマンド

### 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Classic: インターフェイス集約** | <code>(config-if)# ip summary-address eigrp [AS] [IP] [MASK]</code> |
| **Named: インターフェイス集約** | <code>(config-router-af-interface)# summary-address [IP] [MASK]</code> |
| **集約ルートへの Leak-map 適用** | <code>summary-address [IP] [MASK] leak-map [MAP_NAME]</code> |
| **Stub構成の有効化(標準)** | <code>(config-router)# eigrp stub connected summary</code> |
| **Stub構成への Leak-map 適用** | <code>(config-router)# eigrp stub leak-map [MAP_NAME]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **Active状態のルート(SIA調査)** | <code>show ip eigrp topology active</code> |
| **Stub状態の確認(ネイバー側)** | <code>show ip eigrp neighbors detail</code> |
| **集約ルートの広告状況確認** | <code>show ip eigrp interfaces detail [ID]</code> |
| **Query/Replyの統計確認** | <code>show ip eigrp traffic</code> |
| **イベントログの確認(SIAログ)** | <code>show ip eigrp events</code> |

---

## 🛠 ラボ学習・設定サンプル例

Query制御とコンバージェンス最適化に焦点を当てた12個の実装例を提示します。

### 1. 基本的な EIGRP Stub による Query 抑制

**【問題内容】**
ハブルータ R1 とスポークルータ R2 の間で EIGRP AS 100 を動作させている。R2 を Stub ルータとして構成し、R1 が R2 に対して代替パスの問い合わせ (Query) を送信しないようにせよ。

**【設定サンプル】**
```ios
! R2 スポークルータ側
router eigrp 100
 ! 直結ルートと集約ルートのみ広報し、Queryを受け取らない
 eigrp stub connected summary
```

---

### 2. Leak-Map を使用した特定のサブネットの個別広報 (Named Mode)

**【問題内容】**
R1において `10.0.0.0/8` の集約ルートを `GigabitEthernet0/1` から広報せよ。ただし、重要なサーバセグメントである `10.1.50.0/24` だけは集約に含めず、詳細ルートとして個別に広報せよ。

**【設定サンプル】**
```ios
! 漏らしたいルートを定義
ip prefix-list P-SERVER permit 10.1.50.0/24
!
route-map RM-LEAK permit 10
 match ip address prefix-list P-SERVER
!
router eigrp CCIE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   ! 集約を設定し、例外としてLeak-mapを適用
   summary-address 10.0.0.0 255.0.0.0 leak-map RM-LEAK
```

---

### 3. Stub ルータからの再配送ルートの許可 (EIGRP Stub Redistributed)

**【問題内容】**
スポークルータ R3 において、OSPF から EIGRP へルートを再配送している。R3 を Stub として構成しつつ、この再配送されたルートをハブルータに伝えられるようにせよ。

**【設定サンプル】**
```ios
router eigrp 100
 ! デフォルトのconnected/summaryに加え、再配送ルートの広報を許可
 eigrp stub connected summary redistributed
 redistribute ospf 1 metric 10000 10 255 1 1500
```

---

### 4. Stub Leak-Map による高度な例外制御

**【問題内容】**
R4 を Stub ルータとして設定せよ。通常、Stub ルータは `static` ルートを広報しない設定であるが、特定のタグ `999` が付いたスタティックルートのみを例外的に広報せよ。

**【設定サンプル】**
```ios
route-map RM-STUB-EXCEPT permit 10
 match tag 999
!
router eigrp 100
 ! Stub設定の中でLeak-mapを指定して例外を許可
 eigrp stub connected summary leak-map RM-STUB-EXCEPT
```

---

### 5. DMVPN 環境における Split-Horizon の無効化と集約

**【問題内容】**
DMVPN ハブルータ R5 において、スポーク間の通信を可能にするため、トンネルインターフェイスで Split-Horizon を無効化し、さらに全スポークに対しデフォルトルートのみを送信してルーティングテーブルを最適化せよ。

**【設定サンプル】**
```ios
interface Tunnel0
 ! EIGRPのSplit-Horizonを無効化
 no ip split-horizon eigrp 100
 ! デフォルトルートへの集約
 ip summary-address eigrp 100 0.0.0.0 0.0.0.0
```

---

### 6. Summary Route を用いた「最後のリゾート」の作成 (Floating Default)

**【問題内容】**
メインのインターネット境界 R1 がダウンした際のバックアップとして、R2 から EIGRP ドメイン内にデフォルトルートを集約によって注入せよ。ただし、このデフォルトルートはメインの経路よりも優先順位を下げること。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ! AD値を 200 に設定してフローティングさせる
 ip summary-address eigrp 100 0.0.0.0 0.0.0.0 200
```

---

### 7. Named Mode での「Receive-Only」Stub の構成

**【問題内容】**
セキュリティ上の理由から、R6 は隣接関係を維持するが、自身の配下のネットワーク情報をネイバーに一切教えてはならない。

**【設定サンプル】**
```ios
router eigrp KBITS
 address-family ipv4 unicast autonomous-system 100
  ! 自身からは何も広報しないモード
  eigrp stub receive-only
```

---

### 8. 集約による SIA 発生ルータの特定と修正

**【問題内容】**
ネットワークの一部でルートが Active 状態のまま Reply が戻らず、隣接関係がリセットされている。R1 (ABR相当) で集約を適切に行い、問題の切り分けと Query 範囲の制限を行え。

**【検証・修正】**
```ios
! SIA発生の確認
R1# show ip eigrp topology active
! 修正：適切な集約ポイントを設定
interface GigabitEthernet0/1
 ip summary-address eigrp 100 172.16.0.0 255.255.0.0
```

---

### 9. Multi-AF 環境での IPv6 Stub 構成

**【問題内容】**
IPv6 EIGRP 環境において、スポークルータ R7 を Stub として構成し、直結の IPv6 プレフィックスのみを広報させよ。

**【設定サンプル】**
```ios
ipv6 router eigrp 100
 eigrp stub connected
```

---

### 10. Summary-Metric を用いた集約ルートの属性操作

**【問題内容】**
R8 において `192.168.0.0/16` を集約して広報する際、そのメトリック情報を固定（帯域幅 1Gbps）にし、詳細ルートのメトリック変化が集約ルートに影響を与えないようにせよ。

**【設定サンプル (Named Mode)】**
```ios
router eigrp CCIE
 address-family ipv4 unicast autonomous-system 100
  topology base
   ! 集約ルートに特定のメトリックを強制する
   summary-metric 192.168.0.0/16 distance 90 bandwidth 1000000 delay 10 reliability 255 load 1 mtu 1500
```

---

### 11. プレフィックス学習数の制限 (Scalability Protection)

**【問題内容】**
特定のネイバーから学習するルート数が 100 を超えた場合、そのネイバーとのセッションを自動的に切断してルータのリソース（メモリ）を保護せよ。

**【設定サンプル】**
```ios
router eigrp 100
 ! 最大100個に制限。超過時に警告(warning-only)なしで切断
 distribute-list maximum-prefix 100
```

---

### 12. Hello/Hold Timers の微調整による高速障害検知

**【問題内容】**
特定の高信頼性リンクにおいて、障害検知を 1秒以内に行うため、Hello 間隔を 200ms、Hold タイムを 1秒に変更せよ。

**【設定サンプル (Named Mode)】**
```ios
router eigrp CCIE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   hello-interval 1
   hold-time 3
   ! ※ピコ秒単位のWide Metric環境下ではBFDの併用が一般的
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide - Optimization (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book/ire-enhanced-igrp.html)。
*   [EIGRP Stub Routing White Paper](https://www.cisco.com/en/US/technologies/tk648/tk365/technologies_white_paper0900aecd8023df6f.html)。

### CiscoLive (動画・スライド)
*   [BRKENT-2050: EIGRP - The Usual Suspects](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2050)。
*   [BRKCCIE-3000: BGP and EIGRP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html)。
*   [BRKRST-3320: Troubleshooting Routing Protocols (EIGRP SIAトラブル等)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)。

### テクニカルドキュメント・設定例
*   [Preventing Stuck-in-Active (SIA) using Summarization and Stub](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13669-1.html)。
*   [Configuring EIGRP Leak Maps with Summary Routes](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book/ire-eigrp-stub-rtg.html)。

---

## 📝 補足
- この学習メモは、CCIE EIラボ試験において「論理的に正しいがスケールしないネットワーク」を「堅牢で最適化されたエンタープライズインフラ」へと昇華させるための技術的指針を網羅しています。特に集約とStubによるQuery境界の構築は、合格のための必須スキルです。


