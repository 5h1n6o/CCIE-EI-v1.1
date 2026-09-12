---
layout: default
title: 1.3.c-Operations
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.3.c Operations (General operations, Topology table, Packet types, Stuck-in-active, Graceful shutdown)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP の1つである **EIGRP Operations（基本動作、トポロジーテーブル、パケットタイプ、Stuck-In-Active、Graceful Shutdown）** について、Cisco IOS-XE 17.x の実装基準に完全準拠して解説します。

---

## 📘 概要

EIGRP（Enhanced Interior Gateway Routing Protocol）は、Diffusing Update Algorithm（DUAL）を中核アルゴリズムとして採用した高度なディスタンスベクター型ルーティングプロトコルです。

EIGRP の運用（Operations）においては、ルーティング情報の交換・更新・障害回復が効率的かつ正確に行われるよう、複数のパケットタイプ、コントロールメカニズム、トポロジーテーブルのステート管理が密接に連携しています。

### 主な利用目的と適用シーン
1. **信頼性の高い制御パケット交換:** RTP（Reliable Transport Protocol）を用いて、Update、Query、Reply などの重要パケットの確実な到達を保証する。
2. **高速障害復旧とループフリー計算:** DUAL アルゴリズムにより、事前計算されたバックアップ経路（Feasible Successor）が存在する場合は即時切り替え（1秒未満）を行い、存在しない場合は Query パケットを伝搬して動的に代替経路を探索する。
3. **SIA（Stuck-In-Active）の防止と局絶化:** トポロジー変更時の Query ストームや中間リンク遅延によるネイバー切断を防ぐため、SIA-Query / SIA-Reply メカニズムや Stub 機能を活用して探索範囲を制限する。
4. **迅速なトポロジー再計算（Graceful Shutdown）:** プロセス停止時やインターフェイスシャットダウン時に Goodbye Message を即座に送出し、対向ルータに Hold Timer 満了を待たせることなく即時切替を実行させる。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | DUAL アルゴリズムによる分散型計算。Passive（安定）と Active（代替経路再計算中）の2つの内部ステートで各プレフィックスを管理。 |
| **パケット種類** | ① Hello <br> ② Update <br> ③ Query <br> ④ Reply <br> ⑤ ACK <br> ⑥ SIA-Query <br> ⑦ SIA-Reply <br> ⑧ Goodbye Message |
| **トポロジーテーブル** | 宛先ネットワーク、FD、RD/AD、Successor、Feasible Successor、現在ステート（P/A）、ネイバーリスト、インターフェイス情報を保持。 |
| **SIA (Stuck-In-Active)** | Active ステートに移行したルートに対して、対向からの Reply が Active Timer（デフォルト180秒）以内に戻らない現象。SIA-Query/Reply により誤切断を防止。 |
| **Graceful Shutdown** | K値がすべて 255（`K1=K2=K3=K4=K5=255`）にセットされた Hello パケット（Goodbyeパケット）を送出し、ネイバーへ即時切断を通知。 |
| **設計上の注意点** | 大規模網で Query 伝搬範囲を制限（Boundaries）しないと、低速リンクや過負荷ルータが存在する場合に SIA が頻発し、正常なネイバーまで巻き込んで切断される。 |

---

## 🏗 動作原理

EIGRP の内部処理は、トポロジーテーブルのステート遷移とパケットタイプごとのシームレスなやり取りによって実現されています。

```text
[ 通常状態 (Passive State) ]
      │
      ├─ リンク障害発生 / コスト増加 (Successor 消失 & FS 無し)
      ▼
[ Active State へ遷移 ] ──► (Active Timer 180秒 起動)
      │
      ├─ 全非エッジポートへ Query パケット送信 (Unicast/Multicast)
      │
      ├───► [ 隣接ルータ A (FSあり) ] ──► 即座に Reply 返信
      │
      └───► [ 隣接ルータ B (FSなし) ] ──► さらに先へ Query を転送
                 │
                 ├─ 90秒経過 (Active Timer の半分)
                 ▼
            [ SIA-Query 送信 ] ◄────────► [ SIA-Reply 返信 ] (セッション生存確認)
                 │
                 ├─ 全ネイバーから Reply 受信完了
                 ▼
            [ 新 Successor 決定 / Passive State へ復帰 ]
```

---

## ⚙ 動作シーケンス

1. **Passive ステート（定常状態）:**
   * 該当プレフィックスに対して有効な Successor（および必要に応じて Feasible Successor）が存在し、DUAL 計算が完了してルーティングテーブル（RIB）に正常に掲載されている安定状態。
2. **Active ステートへの遷移と Query 送出:**
   * プライマリパス（Successor）がダウンし、かつ FC 条件を満たす Feasible Successor が存在しない場合、プレフィックスは Active ステートへ遷移します。
   * ルータは該当ルートに関する Reply を受け取るまで、全隣接ルータ（Query Boundary 外）へ Query パケットを送出します。
3. **SIA-Query / SIA-Reply ハンドシェイク (90秒時点):**
   * Active タイマー（180秒）の半分の 90秒 が経過しても Reply を返してこないネイバーに対して、ルータは **SIA-Query** を送信します。
   * 対向ルータが生存しており、単にさらに奥のルータからの Reply を待っている状態であれば、即座に **SIA-Reply** を返します。これにより、該当ネイバーとのアジャセンシー全体を切断するのを回避します。
4. **Active タイマー満了または全 Reply 受信:**
   * すべての Reply（または SIA-Reply）を受信した場合、集計されたメトリックに基づき新たな Successor を選定し、Passive ステートへ戻ります。
   * 万が一 SIA-Reply も戻らず 180秒 が満了した場合、該当ネイバーを SIA 障害と判定し、ネイバーアジャセンシーを切断します。
5. **Graceful Shutdown (Goodbye Message):**
   * 管理者が `router eigrp` プロセスをシャットダウンした際、あるいはインターフェイスを `shutdown` した際、ルータは `K1=K2=K3=K4=K5=255` に設定した特殊な Hello パケット（Goodbye Message）を送信します。
   * 受信したネイバーは、Hold Timer のカウントダウン（15秒等）を待つことなく、即座に該当ネイバー経由のルートをトポロジーテーブルから消去・再計算します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、EIGRP Operations はトラブルシューティングおよびパケット解析（Packet Trace / Debug）で極めて高い頻度で問われます。

### 1. 8 種類のパケットタイプと RTP (Reliable Transport Protocol) の判別
EIGRP パケットは IP プロトコル番号 **88** でカプセル化されます。以下のパケットタイプの信頼性保証（RTP）の有無を完璧に把握してください。

* **Hello:** 非信頼（RTP非使用・ACK不要）。ネイバー検知・維持・Goodbye 通知用。
* **ACK:** 非信頼（RTP非使用・ACKパケット自体に対するACKは返さない）。データ長0の空ヘッダー。
* **Update:** **信頼性あり（RTP使用・要ACK）**。ルーティング情報の通知。
* **Query:** **信頼性あり（RTP使用・要ACK）**。代替経路の問い合わせ。
* **Reply:** **信頼性あり（RTP使用・要ACK）**。Query に対する応答。
* **SIA-Query:** **信頼性あり（RTP使用・要ACK）**。Active 状態の問い合わせ維持確認。
* **SIA-Reply:** **信頼性あり（RTP使用・要ACK）**。SIA-Query に対する応答。

### 2. トポロジーテーブルのフラグとステートの読み取り
`show ip eigrp topology` コマンドで表示される各記号の意味を瞬時に識別できるようにしてください。

* **P (Passive):** 正常・安定状態。ラボ試験ではすべての主要プレフィックスが `P` であることが期待されます。
* **A (Active):** DUAL が代替経路を問い合わせ中（再計算中）。
* **r (Reply Status Flag):** 該当ネイバーからの Reply 応答を待っている状態。
* **s (SIA Status Flag):** SIA-Query を送信し、SIA-Reply を待っている状態。

### 3. Graceful Shutdown の動作検証
* 試験問題で「対向ルータの障害時に、Hold Timer の満了を待たずに即時コンバージェンス（Sub-second Failover）するように設定せよ」という要件が出された場合、EIGRP のデフォルト機能である **Goodbye Message** が正常に機能しているか、または BFD 連携が正しく行われているかを検証します。

---

## 🛠 設定方法

### 1. Active Timer (SIA タイマー) の調整

```bash
# [Classic Mode]
router eigrp 100
 timers active-time 5   # Active タイマーを 5 分に変更 (デフォルト 3分 = 180秒)
 timers active-time disabled # Active タイマーを無効化 (SIA 切断を起こさないが非推奨)

# [Named Mode]
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   timers active-time 5
  exit-af-topology
 exit-address-family
```

### 2. Graceful Shutdown の手動発生検証

```bash
# インターフェイスレベルでの EIGRP 停止 (Goodbye Message 送出)
interface GigabitEthernet0/1
 shutdown

# プロセスレベルでの EIGRP 停止
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  shutdown
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EIGRP トポロジーテーブル全体のステート（P/A）および Successor / FS 一覧確認** | <code>show ip eigrp topology</code> / <code>show eigrp address-family ipv4 topology</code> |
| **FC 条件を満たさない非 FS パスも含めた完全なトポロジーテーブルの確認** | <code>show ip eigrp topology all-links</code> |
| **現在 Active ステートに陥っているプレフィックスおよび Reply 待ちネイバーのピンポイント確認** | <code>show ip eigrp topology active</code> |
| **現在 SIA（Stuck-In-Active）状態に陥っているプレフィックスの追跡** | <code>show ip eigrp topology stuck-in-active</code> |
| **EIGRP 制御パケット（Update, Query, Reply, Hello）の送受信リアタイムデバッグ** | <code>debug eigrp packets</code> / <code>debug ip eigrp notifications</code> |
| **DUAL アルゴリズムの内部ステート遷移（Passive ↔ Active）のリアルタイム追跡** | <code>debug ip eigrp fsm</code> (Finite State Machine) |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **特定プレフィックスが `Active` ステートのまま戻らず、一定時間後にネイバーが切断される。** | 1. ネットワーク奥深くまで Query が拡散（Query ストーム）し、低速・過負荷リンクで Reply が遅延している。<br>2. 中間ルータで ACL / CoPP により EIGRP (IPプロトコル88) の Unicast パケット（Reply）がドロップされている。 | `show ip eigrp topology active`<br>`show ip eigrp topology stuck-in-active` | 1. スポークルータへ **EIGRP Stub** を設定し Query 拡散を遮断する。<br>2. ACL で IP プロトコル 88 を無条件許可する。 |
| **`%DUAL-5-NBRCHANGE: EIGRP-IPv4 100: Neighbor ... Neighbor Inactive: Stuck in Active` ログが出力される。** | Active Timer (180秒) 内に特定ネイバーから Reply も SIA-Reply も返ってこなかったため、DUAL が該当ネイバーアジャセンシー全体を強制リセットした。 | `show logging`<br>`show ip eigrp neighbors` | 該当ネイバーとの間の物理品質、CPU 使用率、および `SIA-Query` 送受信ログを確認・修復する。 |
| **シャットダウン実行時に対向ルータで即時切替が起きず、Hold Timer 満了まで障害検知が遅れる。** | コントロールプレーン過負荷、またはパケットドロップにより Goodbye パケット（K=255 Hello）が損失した。 | `debug eigrp packets hello` | BFD (Bidirectional Forwarding Detection) を導入し、データプレーンレベルでミリ秒単位の障害検知を補強する。 |

---

## ⚠ 制限事項

1. **SIA-Query / SIA-Reply のサポート:**
   * Cisco IOS 12.1(5)T 以降で標準実装されています。レガシーな古すぎる IOS が混在している場合、SIA-Query に対応できず、90秒時点でのセッション維持確認が行われない場合があります。
2. **Active Timer を 0 / Disabled にすることのリスク:**
   * `timers active-time disabled` を設定すると SIA によるネイバー切断は防げますが、永遠に Reply を待ち続けるブラックホールルートがトポロジーテーブルに残存する危険性があります。

---

## 🔄 他技術との関連

* **EIGRP Stub Routing:**
  Query パケットの伝搬範囲（Query Propagation Boundaries）を物理的に制限する最も強力なソリューションです。Stub ルータに対しては、上位ルータは Query パケットを一切送出しなくなるため、SIA 発生率をゼロに近く削減できます。
* **Route Summarization (手動集約):**
  サマリーアドレス（例: `/16`）を境界でアドバタイズすることで、配下の明細ルート（`/24`等）がフラッピングしても、Query 伝搬を集約境界ルータで停止（Block）させることができます。

---

## 🧩 比較表

### EIGRP パケットタイプ別の特性比較

| パケット名 | IP 送信形態 | RTP (信頼性保証) | 主な目的 / 動作 |
| :--- | :--- | :--- | :--- |
| **Hello** | Multicast (`224.0.0.10`) / Unicast | **なし** (ACK 不要) | ネイバーの発見およびアジャセンシー維持 |
| **Update** | Multicast / Unicast | **あり** (要 ACK) | ルーティング・トポロジー情報の伝搬 |
| **Query** | Multicast / Unicast | **あり** (要 ACK) | 代替経路（Feasible Successor なし時）の問合せ |
| **Reply** | Unicast | **あり** (要 ACK) | Query に対する応答（メトリック通知） |
| **ACK** | Unicast | **なし** (データ長 0) | Update/Query/Reply 等の受信確認応答 |
| **SIA-Query** | Unicast | **あり** (要 ACK) | Active 遷移から 90秒 後にネイバーの生存・応答確認 |
| **SIA-Reply** | Unicast | **あり** (要 ACK) | SIA-Query に対する応答（計算継続中であることを通知） |
| **Goodbye** | Multicast / Unicast | **なし** (Hello 拡張) | K値全255指定により、ネイバーへ即時切断を通知 |

---

## 💡 ベストプラクティス

1. **EIGRP Stub および Route Summarization による Query 境界の明示的定義:**
   キャンパス・WAN のハブ＆スポーク構成では、すべてのスポークルータに `eigrp stub` を適用し、ハブ側でルート集約を行うことで、SIA 障害の根本原因である Query ストームを物理的に排除する。
2. **BFD（Bidirectional Forwarding Detection）の統合:**
   Goodbye パケットの不達に備え、主要トランク・WAN リンクでは BFD を併用してサブ秒レベルでの障害検知を二重化する。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI Practical Lab 試験レベルに対応する完全な10個のラボ実証シナリオです。

### Scenario 1: Active ステート遷移と Query/Reply 動作の確認
* **要件:** R1-R2-R3 の直線構成において、R1 側で Loopback0 (1.1.1.1/32) をシャットダウンした際、R2 が Active ステートへ遷移して R3 へ Query を送信する挙動をキャプチャ/デバッグで確認せよ。

**【R1】**
```bash
interface Loopback0
 shutdown
```

**【R2 (検証コマンド)】**
```bash
R2# debug ip eigrp fsm
R2# debug eigrp packets query reply
# DUAL FSM が Passive から Active へ遷移し、Query を送出するログを確認
```

---

### Scenario 2: Active Timer (SIA タイマー) のカスタマイズ
* **要件:** R2 において、EIGRP Named Mode 配下で Active タイマーを 3分 (180秒) から 5分 (300秒) に変更せよ。

**【R2】**
```bash
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   timers active-time 5
  exit-af-topology
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip protocols
# EIGRP 構成パラメータ内で 「Active-timer: 5 min」 が反映されていることを確認
```

---

### Scenario 3: SIA-Query および SIA-Reply の動作検証
* **要件:** R2 と R3 間で ACL を適用して Reply パケットのみをドロップさせ、90秒経過時に R2 が SIA-Query を送出する現象を確認せよ。

**【R3 (特定パケット遮断)】**
```bash
ip access-list extended BLOCK_EIGRP_REPLY
 deny eigrp any any
 permit ip any any
!
interface GigabitEthernet0/1
 ip access-group BLOCK_EIGRP_REPLY out
```

**【検証方法】**
```bash
R2# show ip eigrp topology stuck-in-active
R2# debug eigrp packets siaquery siareply
```

---

### Scenario 4: Goodbye Message による Graceful Shutdown の確認
* **要件:** R1 で `router eigrp` プロセスをシャットダウンした際、対向 R2 で Hold Timer 満了を待たずに即座にネイバーが DOWN することを確認せよ。

**【R1】**
```bash
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  shutdown
```

**【R2 (ログ確認)】**
```bash
R2# show logging
# %DUAL-5-NBRCHANGE: EIGRP-IPv4 100: Neighbor 10.1.12.1 (GigabitEthernet0/1) is down: Interface Shutdown が即座に出力されることを確認
```

---

### Scenario 5: Topology Table の `all-links` オプションによる FC 非適合パスの監査
* **要件:** R2 において、Feasibility Condition (`RD < FD`) を満たしていないバックアップパスを含めてトポロジーテーブルを確認せよ。

**【R2】**
```bash
R2# show ip eigrp topology all-links
```

---

### Scenario 6: EIGRP Stub 導入による Query 伝搬遮断の検証
* **要件:** R3（スポーク）に `eigrp stub connected summary` を投入し、R2 から R3 へ向かう Query が停止することを確認せよ。

**【R3】**
```bash
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  eigrp stub connected summary
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip eigrp neighbors detail
# R3 のフラグに 「Stub Peer」が含まれ、R2 が R3 へ Query を送らなくなることを確認
```

---

### Scenario 7: 手動ルート集約（Summarization）による Query ブロックの検証
* **要件:** R2 の対向インターフェイスで `10.1.0.0/16` に手動集約を設定し、配下の `/24` 障害時の Query 拡散を集約境界で阻止せよ。

**【R2】**
```bash
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/2
   summary-address 10.1.0.0 255.255.0.0
  exit-af-interface
 exit-address-family
```

---

### Scenario 8: RTP 再送上限 (Retries Exceeded) トラブルシューティング
* **要件:** 片方向リンク障害により Update に対する ACK が返らず、16回の再送後にネイバーが切断される現象（`Retry limit exceeded`）を解決せよ。

**【検証および復修】**
```bash
R2# show ip eigrp neighbors
# Q Cnt (Queue Count) が 0 以上で推移し、RTO が上昇していることを確認後、物理ケーブル/SFP を交換
```

---

### Scenario 9: EIGRPv6 (IPv6) における Operations と DUAL 動作確認
* **要件:** IPv6 アドレスファミリー配下で DUAL のトポロジーテーブルおよび Active ステート遷移を確認せよ。

**【R1】**
```bash
R1# show ipv6 eigrp topology
```

---

### Scenario 10: VRF-Aware 環境における Topology Table 監査
* **要件:** VRF `CUSTOMER_A` 内の EIGRP トポロジーテーブルを個別監査せよ。

**【R1】**
```bash
R1# show ip eigrp vrf CUSTOMER_A topology
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解】SIA 発生時のログ解析と原因特定
**問題:** 
あるルータの Syslog に以下のメッセージが出力され、ネイバー `10.1.23.3` とのアジャセンシーが切断されました。
```text
%DUAL-5-NBRCHANGE: EIGRP-IPv4 100: Neighbor 10.1.23.3 (GigabitEthernet0/2) is down: Retry limit exceeded
%DUAL-5-NBRCHANGE: EIGRP-IPv4 100: Neighbor 10.1.23.3 (GigabitEthernet0/2) is down: Stuck in Active
```
この時、内部で発生したパケットシーケンスと、問題の根本原因として考えられるインフラ障害を説明してください。

**解答・解説:**
* **内部パケットシーケンス:**
  プレフィックスが Active ステートへ遷移後、ルータは `10.1.23.3` へ Query を送信しました。90秒経過時点で SIA-Query を送出しましたが、応答（SIA-Reply）または通常の Reply が返らず、Active Timer (180秒) が満了したため、DUAL は該当ネイバーアジャセンシー全体を強制ダウン（Stuck in Active）させました。また、RTP の再送メカニズム（最大16回）も完了しなかったため `Retry limit exceeded` が重なって出力されています。
* **根本原因:**
  1. `10.1.23.3` 側のルータが CPU 100% 高負荷状態、あるいはメモリ枯渇を起こしており DUAL プロセスが応答不能になっている。
  2. 途中の L2/L3 網で Unicast パケット（特に IP プロトコル 88）が片方向ドロップ（Unidirectional Drop）している。
  3. `10.1.23.3` のさらに奥にあるルータで Query が無限に探索（ループまたは過大ホップ）されている。

---

### 2. 【Design】Graceful Shutdown と Fast Reroute の設計評価
**問題:** 
EIGRP ネットワークにおいて、コアスイッチの保守（計画停止）に伴う通信寸断時間を最小化するための設計について述べます。インターフェイスを `shutdown` する際、EIGRP のデフォルト動作として何が送信され、対向ルータはどのように動作するか説明せよ。

**解答・解説:**
* **送信パケット:** 
  EIGRP プロセスまたはインターフェイスがシャットダウンされると、ルータは **Goodbye Message**（すべての K値 `K1=K2=K3=K4=K5=255` に設定された Hello パケット）を即座に送信します。
* **対向ルータの動作:** 
  Goodbye パケットを受信した対向ルータは、Hold Timer のカウントダウン（15秒等）を待つことなく、該当ネイバーがダウンしたと即時判定します。Feasible Successor が存在する場合は **1秒未満（サブ秒）でバックアップパスへ切替** を完了し、存在しない場合は即座に DUAL 再計算（Query 送出）を開始します。

---

## 🔗 参考リソース

* [Cisco Systems: EIGRP Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book.html)
* [Cisco Technical TechNotes: Enhanced Interior Gateway Routing Protocol (EIGRP) Troubleshoot Guide](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13673-12.html)
* [Cisco Live: BRKRST-2336 - EIGRP Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **EIGRP ステート確認チェックリスト:**
  1. `show ip eigrp topology` でプレフィックスの先頭がすべて `P` (Passive) になっているか？
  2. `A` (Active) が存在する開発・障害環境では、`show ip eigrp topology active` で Reply を返していないネイバー IP を特定する。
  3. SIA 発生を防ぐため、ハブ＆スポーク構成ではスポークに必ず `eigrp stub` を投入する。


## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [EIGRP Named Mode Configuration Case Study](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/200156-Configure-EIGRP-Named-Mode.html)

### CiscoLive (動画・スライド)
*   [Introduction to EIGRP - BRKENT-1187](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/BRKENT-1187.pdf) - EIGRPの基礎と概要を解説
*   [EIGRP Operations: The Usual Suspects - BRKENT-2050](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/BRKENT-2050.pdf) - EIGRPの動作原理やトラブルシューティングを解説。

### テクニカルドキュメント・設定例
*   [EIGRP Stub Router Functionality (White Paper)](https://www.cisco.com/en/US/technologies/tk648/tk365/technologies_white_paper0900aecd8023df6f.html)
*   [Introduction to EIGRP Metrics](http://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/16406-eigrp-metrics.html) - 計算式の詳細。

---

## 📝 補足
- この学習メモは、EIGRPの単なる設定ではなく、「なぜそのように動くのか」という内部アルゴリズムとパケットの役割に焦点を当てています。特に **SIAの防止策（集約とStub）**、および **FC条件を考慮したパス操作** は、CCIE EIラボ試験で最も配点の高い、そして落としやすいポイントであるため、実機（EVE-NG/VIRL）での繰り返し検証が強く推奨されます。

