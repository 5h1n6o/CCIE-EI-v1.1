---
layout: default
title: 1.3.c-Operations
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.3.c-Operations
# CCIE Enterprise Infrastructure v1.1 学習メモ: 1.3.c EIGRP Operations

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.3 EIGRP」における「1.3.c Operations」について整理しました。

---

## 📘 概要

**EIGRP (Enhanced Interior Gateway Routing Protocol)** は、シスコ独自の **DUAL (Diffusing Update Algorithm)** を採用した拡張ディスタンスベクトル型ルーティングプロトコルです。従来のディスタンスベクトル型のシンプルさと、リンクステート型の高速コンバージェンスの利点を融合させており、現代のエンタープライズネットワークにおいても重要な役割を担っています。

EIGRPの動作の本質は、隣接ルータ間でトポロジ情報を信頼性高く同期し、ループのない最短パス（Successor）とバックアップパス（Feasible Successor）を数学的な整合性（Feasibility Condition）に基づいて維持することにあります。CCIEレベルでは、プロセスのハングを引き起こす **Stuck-in-Active (SIA)** 状態の深い理解や、ネットワークの大規模化に伴う Query スコープの制御、さらにはメンテナンス時の **Graceful Shutdown** による隣接関係の即時解除など、プロトコル内部の挙動を完全に制御する能力が問われます。

---

## 🔑 要点

### 1. General Operations (全般的な動作)

EIGRPは、効率的な運用のために以下の3つのデータ構造（テーブル）を維持します。

| テーブル名 | 内容 | 備考 |
| :--- | :--- | :--- |
| **Neighbor Table** | 直接接続された隣接ルータのリスト。 | <code>show ip eigrp neighbors</code> で確認。 |
| **Topology Table** | ネイバーから受信したすべてのネットワークプレフィックスとメトリック情報。 | <code>show ip eigrp topology</code> で確認。 |
| **Routing Table (RIB)** | トポロジテーブルから選出された最適パス（Successor）の格納場所。 | <code>show ip route eigrp</code> で確認。 |

隣接関係の確立には、AS番号、K値（メトリックの重み）、共通の一次IPサブネット、および認証設定の一致が必須条件となります。

### 2. Topology Table と DUAL の計算

トポロジテーブルには、パス選定のための重要な指標が保持されます。

*   **Successor:** 最小のパスコストを持つ最適次ホップ。
*   **Feasible Successor (FS):** ループフリーが保証されたバックアップ次ホップ。
*   **Feasible Distance (FD):** Successor経由での、自身から宛先までの最小メトリック（レコード）。
*   **Reported Distance (RD):** ネイバーが自身のコストとして広告してきた値。Advertised Distanceとも呼ばれる。
*   **Feasibility Condition (FC):** **「RD < 現在のFD」** という条件。これを満たすネイバーは、自身を宛先への経路として利用していない（ループしていない）ことが保証されます。

### 3. Packet Types (パケットタイプ)

EIGRPは、トランスポート層としてプロトコル番号 88 (RTP: Reliable Transport Protocol) を使用し、以下のパケットで制御を行います。

*   **Hello:** ネイバーの発見と生存確認。確認応答（ACK）を必要としません。
*   **Update:** 経路情報の伝達。ACKによる確実な同期が必要です。
*   **Query:** 経路消失時に、FSが存在しない場合に代替パスをネイバーに問い合わせます。
*   **Reply:** Queryに対する応答パケット。ACKが必要です。
*   **ACK:** 信頼性が必要なパケット（Update/Query/Reply）に対する受領確認。中身はデータの無いHelloパケットです。

### 4. Stuck-in-Active (SIA) のメカニズム

ルータがルートの消失を検知し、Queryを送信して代替パスを探す際、そのルートは「Active（アクティブ）」状態になります。この状態において、一定時間（デフォルト3分）経過してもネイバーから Reply が戻ってこない場合、そのネイバーとの隣接関係は **SIA** と見なされ、強制的に解除されます。
現代のIOSでは、SIA-Query と SIA-Reply というパケットを用いて、ネイバーが Reply の計算中なのか、それともネイバー自身がハングしているのかを判別し、不必要なセッション切断を防ぐ仕組みが導入されています。

### 5. Graceful Shutdown (さよならメッセージ)

ルータのメンテナンスなどでEIGRPプロセスを停止（shutdown）する際、ネイバーに対して **Goodbye Message**（K値がすべて255にセットされたHelloパケット）を送信します。これにより、対向ルータはホールドタイマーの満了を待つことなく即座にネイバーシップを解除し、代替パスへの切り替えを開始できます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、EIGRPの動作原理を利用した高度なパス制御や、大規模ネットワークの安定化手法が重点的に問われます。

### 1. Query プロパゲーションの制限

Queryはデフォルトで全ネイバーに転送され、Replyが揃うまでActive状態が続きます。これを制御するために以下の手法をマスターする必要があります。
*   **Summarization (集約):** ルータが集約ルートを広告している境界では、より詳細なルートの消失に対して Query を転送しなくなります。
*   **EIGRP Stub:** スポークルータを `stub` として設定することで、ハブルータはそのスポークに対して代替パスの Query を送信しなくなります。

### 2. 不等コスト負荷分散 (UCLB) と FC の罠

`variance` コマンドを使用して、コストの異なる複数のパスをルーティングテーブルにインストールできます。
*   **試験での注意:** `variance` で指定した倍率内のコストであっても、そのパスが **Feasibility Condition (RD < FD)** を満たしていない（FSではない）場合、RIBには載りません。トポロジテーブルを確認し、メトリック操作（主にDelayの調整）でFSを意図的に作成するスキルが求められます。

### 3. 名前付きモード (Named Mode) への移行

最新の試験範囲では、従来の Classic Mode よりも Named Mode (Multi-AF) の使用が推奨されます。
*   設定が `address-family` 配下に集約され、インスタンス名で管理される点。
*   高速リンク（1Gbps以上）でメトリックが飽和しないように設計された **Wide Metrics** の理解。

### 4. Router-ID の重複問題

再配送（Redistribution）を伴う環境で、2台のルータが同じ Router-ID を持っている場合、お互いから広報された外部ルートをループと見なして無視してしまいます。`show ip eigrp events` で重複を検知し、`eigrp router-id` を手動設定して解決するタスクが想定されます。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **トポロジ詳細（全候補パス）表示** | <code>show ip eigrp topology all-links</code> |
| **Active（検索中）なルートの確認** | <code>show ip eigrp topology active</code> |
| **パケット統計（再送やドロップの確認）** | <code>show ip eigrp traffic</code> |
| **ネイバー詳細（ホールド時間・ uptime）** | <code>show ip eigrp neighbors detail</code> |
| **インターフェイス別の動作状況** | <code>show ip eigrp interfaces detail [ID]</code> |
| **イベントログの追跡（SIAや切断理由）** | <code>show ip eigrp events</code> |
| **AS番号やK値、Router-IDの確認** | <code>show ip protocols</code> |
| **Named Mode インスタンス構成の表示** | <code>show eigrp address-family ipv4 vrf [NAME]</code> |
| **パケットのリアルタイムデバッグ** | <code>debug eigrp packets {hello&#124;update&#124;query&#124;reply}</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 名前付きモード (Named Mode) による基本構成

**【問題内容】**
インスタンス名「CCIE_HQ」、AS 100 を使用して、すべてのインターフェイスで EIGRP を有効化せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_HQ
 address-family ipv4 unicast autonomous-system 100
  ! network 0.0.0.0 によりすべてのIPインターフェイスを対象とする
  network 0.0.0.0
 exit-address-family
```
*   **解説:** Named Modeでは、グローバルプロセスではなくAF配下でAS番号を定義します。

---

### 2. パッシブインターフェイスの効率的配置

**【問題内容】**
すべてのインターフェイスをデフォルトでパッシブにし、対向ルータが接続された `GigabitEthernet 0/1` のみで隣接関係を許可せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_HQ
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   passive-interface
  af-interface GigabitEthernet0/1
   no passive-interface
  network 0.0.0.0
```
*   **試験対策:** `af-interface default` を使用することで、将来追加されるインターフェイスでの不必要なHello送出を自動的に防止できます。

---

### 3. EIGRP Stub による Query 範囲の局所化

**【問題内容】**
拠点ルータ R2 を Stub ルータとして構成し、直結ルート (Connected) と集約ルート (Summary) のみを広告させ、ハブルータからの冗長パスの問い合わせ (Query) を受け取らないようにせよ。

**【設定サンプル】**
```ios
router eigrp 100
 eigrp stub connected summary
```
*   **解説:** `stub` コマンドにより、R2はネイバーに対して「私は代替パスを持たない」ことを伝え、ネットワーク全体の安定性を向上させます。

---

### 4. 手動集約と Null0 経路の自動生成

**【問題内容】**
R1において、配下のプレフィックス `172.16.1.0/24` 〜 `172.16.3.0/24` を `172.16.0.0/22` に集約して広告せよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ip summary-address eigrp 100 172.16.0.0 255.255.252.0
```
*   **重要ポイント:** 集約を設定すると、ルーティングテーブルに自動的に Null0 への集約経路が生成され、ルーティングループを防止します。

---

### 5. Variance を用いた不等コスト負荷分散 (UCLB)

**【問題内容】**
最適パスのメトリックが 1000、バックアップパス（FS）のメトリックが 2500 の環境で、両方のパスを使用して負荷分散を実装せよ。

**【設定サンプル】**
```ios
router eigrp 100
 ! 最適パスコストの2.5倍(1000 * 2.5 = 2500)をカバーするため、3を指定
 variance 3
```
*   **検証:** `show ip route` で、同じ宛先に対して異なるメトリックの次ホップが2つ現れることを確認します。

---

### 6. Leak-Map による特定の詳細ルートの個別広報

**【問題内容】**
集約ルート `10.0.0.0/8` を広告しつつ、重要なサーバが存在する `10.1.50.0/24` だけは集約せずに詳細ルートとして広報せよ。

**【設定サンプル】**
```ios
ip prefix-list SERVER_SUB permit 10.1.50.0/24
!
route-map MY_LEAK permit 10
 match ip address prefix-list SERVER_SUB
!
interface GigabitEthernet0/1
 ip summary-address eigrp 100 10.0.0.0 255.0.0.0 leak-map MY_LEAK
```
*   **解説:** `leak-map` は集約の利便性を維持しつつ、一部のトラフィックエンジニアリングを可能にする CCIE 定番のタスクです。

---

### 7. Offset-List による特定のパスのメトリック加算

**【問題内容】**
R3 において、特定のプレフィックス `150.1.1.1/32` の受信メトリックに `5000` を追加し、パスの優先順位を下げよ。

**【設定サンプル】**
```ios
access-list 10 permit 150.1.1.1
!
router eigrp 100
 offset-list 10 in 5000 GigabitEthernet0/1
```
*   **試験対策:** メトリックの微調整において、Bandwidthをいじるのではなく `offset-list` や `delay` を使用するのが推奨される作法です。

---

### 8. Router-ID の手動固定による不一致の解消

**【問題内容】**
外部から再配送されたルートが学習されない問題を、Router-ID の明示的設定によって解決せよ。R6 の Router-ID を `10.6.6.6` に設定すること。

**【設定サンプル】**
```ios
router eigrp 100
 eigrp router-id 10.6.6.6
```
*   **トラブルシューティング:** `show ip eigrp events` で "dup routerid" エラーが出ていないか確認することが合格の鍵です。

---

### 9. Key-Chain を使用した MD5 認証の構成

**【問題内容】**
R1 と R2 の間で EIGRP 認証を有効化せよ。パスワードは「Cisco_Labs」、Key-ID は 1 とする。

**【設定サンプル】**
```ios
key chain EIGRP_AUTH
 key 1
  key-string Cisco_Labs
!
interface GigabitEthernet0/1
 ip authentication mode eigrp 100 md5
 ip authentication key-chain eigrp 100 EIGRP_AUTH
```
*   **解説:** 認証はインターフェイス単位で有効化する必要があります。設定後は `show ip eigrp neighbors` でセッションが維持されているか確認します。

---

### 10. Wide Metrics の rib-scale 調整

**【問題内容】**
Named Mode 環境において、Wide Metrics の大きな値を RIB に適合させるためのスケーリング係数を `128` (デフォルト) から `100` に変更せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_WIDE
 address-family ipv4 unicast autonomous-system 100
  topology base
   metric rib-scale 100
```
*   **注意:** ネットワーク内の全ルータで `rib-scale` が一致していないと、メトリックの比較が不正確になり、意図しないパス選定の原因となります。

---

### 11. メンテナンス前の Graceful Shutdown の実行

**【問題内容】**
R4において、隣接ルータに影響を与えずに EIGRP プロセスを安全に停止せよ。

**【実行コマンド】**
```ios
router eigrp 100
 shutdown
```
*   **検証:** ネイバー側で `debug eigrp packets hello` を実行すると、K値が 255 の Goodbye Message を受信し、即座にネイバーシップが消える様子が確認できます。

---

### 12. プレフィックス学習数の上限設定 (Memory Protection)

**【問題内容】**
隣接ルータから受信するルート数を最大 50 個に制限し、これを超えた場合は警告を出しつつも隣接関係は維持せよ。

**【設定サンプル】**
```ios
router eigrp 100
 distribute-list maximum-prefix 50 warning-only
```
*   **解説:** キャパシティプランニングの観点から出題されることがあるタスクです。`warning-only` が無いと、上限超過時にネイバーシップが断絶されます。

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [EIGRP Named Mode Configuration Case Study](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/200156-Configure-EIGRP-Named-Mode.html)

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP and EIGRP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - EIGRPのDUALと高速コンバージェンスの深い解説。
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - EIGRPのトラブルシューティング手法。

### テクニカルドキュメント・設定例
*   [EIGRP Stub Router Functionality (White Paper)](https://www.cisco.com/en/US/technologies/tk648/tk365/technologies_white_paper0900aecd8023df6f.html)
*   [Introduction to EIGRP Metrics](http://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/16406-eigrp-metrics.html) - 計算式の詳細。

---

## 📝 補足
- この学習メモは、EIGRPの単なる設定ではなく、「なぜそのように動くのか」という内部アルゴリズムとパケットの役割に焦点を当てています。特に **SIAの防止策（集約とStub）**、および **FC条件を考慮したパス操作** は、CCIE EIラボ試験で最も配点の高い、そして落としやすいポイントであるため、実機（EVE-NG/VIRL）での繰り返し検証が強く推奨されます。

