---
layout: default
title: 1.4.e-Operations
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.4.e Operations

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 routing プロトコルのコア運用メカニズムである **OSPF Operations（一般運用・Graceful shutdown・GTSM）** について、Cisco IOS-XE 17.x の実装基準に完全準拠して詳細に解説します [21, 1.4.e]。

---

## 📘 概要

OSPF（Open Shortest Path First）における **Operations（運用制御・メカニズム）** とは、OSPF プロトコルがルーティング情報の交換（LSA Flooding・SPF 計算・LSDB 同期）を行う定常動作から、メンテナンスや障害時の迅速かつ無瞬断的なプロセスの停止（Graceful Shutdown）、およびコントロールプレーンに対する外部攻撃防御（GTSM: Generic TTL Security Mechanism）までを含む一連の制御・セキュリティ機能群です [21, 1.4.e]。

### 主な利用目的と適用シーン
1. **LSA Flooding & LSDB の定常維持（General Operations）:** 5 種類の OSPF パケット型と 30 分周期の LSA 周期刷新（Refresh）、60 分での MaxAge 廃棄により、リンクステートデータベース（LSDB）の不整合を常時防止・補正する [21, 1.4.e]。
2. **無影響メンテナンス（Graceful Shutdown）:** ノードの保守や一時撤去時に、トラフィックのドロップ（ブラックホール）を発生させることなく、隣接ルータへ即座に Goodbye / Max-Metric LSA 通知を行って別経路へ無瞬断で迂回させる [21, 1.4.e, 1.4.f (iii)]。
3. **インフラセキュリティ保護（GTSM - RFC 5082）:** 遠隔（複数ホスト離れた場所）から悪意を持って送られてくる偽装 OSPF パケットや DoS 攻撃を、IP ヘッダーの TTL（Time To Live = 255）検証によって物理 ASIC / コントロールプレーン手前で瞬時に破棄・防御する [21, 1.4.e (iii), 4.1.a]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | ① LSA の階層型エージング管理（30分 Refresh / 60分 MaxAge）<br>② コントロールプレーンの明示的停止による高速コンバージエンス（`shutdown`）<br>③ TTL=255 固定と逆算チェックによる CPU 保護（GTSM） [21, 1.4.e]。 |
| **用途** | エンタープライズ網・SD-Access アンダーレイ網における安定運用、計画メンテナンス時のトラフィック迂回、およびコントロールプレーン保護 [21, 1.4.e, 4.1.a]。 |
| **メリット** | ・`shutdown` 設定により Hold Timer（40秒）の満了を待たずに即時迂回が可能。<br>・GTSM により対向が 1 ホスト（直結）でない不審な OSPF パケットを即座に破棄可能 [21, 1.4.e]。 |
| **デメリット** | ・GTSM を有効化する場合、対向ルータ側でも GTSM (TTL=255) の対応が必要（非対応機との間でアジャセンシー切断）。<br>・仮想リンク（Virtual-link）や Multi-hop 環境では GTSM の Hop-count 設計に配慮が必要。 |
| **対応機種** | Cisco Catalyst 9000 シリーズ、Catalyst 8000v、ISR/ASR シリーズ（IOS-XE 16.x / 17.x 全全機種サポート）。 |
| **制限事項** | OSPFv2 と OSPFv3（Address Family モード含む）で設定構文が異なる（`ip ospf ttl-security` vs `ospfv3 ttl-security`） [21, 1.4.b, 1.4.e]。 |
| **設計上の注意点** | メンテナンス時は `shutdown` または `max-metric router-lsa`（Stub Router）を事前投入してトラフィックが迂回したことを確認してから物理切断を行う。 |

---

## 🏗 動作原理

### 1. General Operations (5種類のパケットと LSA エージング)
OSPF は IP プロトコル番号 **89** を使用し、以下の 5 種類のパケットで運用されます。

```text
[ 1. Hello Packet ] ──► ネイバー検知・Keepalive (224.0.0.5)
[ 2. DBD Packet ]   ──► LSDB 要約の交換・マスター/スレーブ選出
[ 3. LSR Packet ]   ──► 不足 LSA の詳細要求 (Link State Request)
[ 4. LSU Packet ]   ──► LSA 情報の実更新・拡散 (Link State Update)
[ 5. LSAck Packet ] ──► LSU に対する確認応答 (Link State Ack)
```

* **LSA Age:** LSA ヘッダー内で 0 〜 3600 秒（60分）までカウント。
* **LSA Refresh (1800秒 = 30分):** 生成ルータは 30 分ごとに LSA 固有の Sequence Number をインクリメント（`0x80000001` ➔ `0x80000002`）して再生成・拡散。
* **MaxAge (3600秒 = 60分):** 60 分間刷新されなかった LSA、または明示的に削除するため Age=3600 で送出された LSA は LSDB から即時削除。

---

### 2. Graceful Shutdown (プロセスの安全停止)
従来の物理切断やプロセス消去では、対向ルータが Dead Timer（デフォルト 40 秒）満了まで障害を検知できず、パケットドロップ（ブラックホール）が発生していました。

`shutdown` コマンドを OSPF プロセスまたはインターフェイスで投入すると：
1. 該当ルータは所有する全 LSA の LSA Age を **3600 (MaxAge)** に設定して LSU を送出。
2. 対向ルータは該当 LSA を LSDB から即時フラッシュし、SPF 計算を再実行して迂回経路へ切替。
3. 最後に **Hello パケットの送出を完全停止** し、安全にアジャセンシーを DOWN 状態へ移行。

```text
[ Router A (Maintenance) ]                        [ Router B ]
     │                                                 │
     │───── 1. LSU (MaxAge=3600 LSA Flash) ──────────►│ (即座に LSDB 削除 & SPF 再計算)
     │◄──── 2. LSAck ──────────────────────────────────│
     │                                                 │
     │───── 3. Stop sending Hello Packets ────────────►│ (Adjacency DOWN)
     ▼                                                 ▼
(OSPF Process Terminated Safely)             (Traffic Fully Rerouted)
```

---

### 3. GTSM (Generic TTL Security Mechanism - RFC 5082)
GTSM は、直結（1 ホスト離れ）の OSPF ネイバー間で交換される IP パケットの TTL（Time To Live）を検証するセキュリティメカニズムです [21, 1.4.e (iii), 4.1.a]。

* **従来の脆弱性:** 送信元 IP をスプーフィングした攻撃者が、遠隔（例えば 10 ホスト先）から TTL=100 等で宛先 `224.0.0.5` や自機 IP へ大量の偽装 OSPF パケットを送りつけ、CPU 枯渇（DoS 攻撃）を引き起こすリスク。
* **GTSM の防御原理:**
  1. 送信側ルータは OSPF パケットの IP ヘッダー TTL を **常に 255（最大値）** で送信。
  2. 受信側ルータはパケットの IP TTL を検証。**「`255 - hop_count`」** ルールを適用。
  3. 直結ネイバー（`hops 1`）の場合、**`TTL >= 254`**（255 - 1 + 1）でないパケットは **物理 ASIC 階層で即座にドロップ**。CPU や OSPF プロセスへ到達させない。

```text
[ Attacker (10 Hops Away) ]                        [ Victim Router ]
     │                                                     │
     │─── Fake OSPF Packet (TTL = 245) ───────────────────►│ (GTSM Check: TTL < 254)
     │                                                     │ ➔ DROP at ASIC Hardware
     │                                                     │   (Control Plane Protected!)

[ Legitimate Neighbor ]                                    │
     │                                                     │
     │─── Valid OSPF Packet (TTL = 255) ──────────────────►│ (GTSM Check: TTL >= 254)
     │                                                     │ ➔ ACCEPT & Processed by OSPF
```

---

## ⚙ 動作シーケンス

### OSPF GTSM パケット処理シーケンス
1. インターフェイス上で OSPF パケット（Hello / DBD / LSU 等）を受信。
2. IP ヘッダーの TTL フィールドをチェック。
3. `ip ospf ttl-security` が構成されている場合：
   * 受信 TTL が `254` 以上（`hops 1` の場合）であれば許可し、OSPF プロセスへ渡す。
   * 受信 TTL が `254` 未満であれば、遠隔からの偽装パケットと判断し、GTSM ドロップカウンタをインクリメントしてパケットを破棄する。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、OSPF Operations は単なる基礎知識ではなく、**「無瞬断メンテナンス手順の指定」** や **「インフラ保護（Control Plane Security）要件」** として高配点で出題されます [21, 1.4.e, 4.1.a]。

### 1. 試験で狙われる重点ポイント
* **Graceful Shutdown の指定構文:**
  * プロセス全体の停止: `router ospf 1` ➔ `shutdown`
  * 特定インターフェイスのみの停止: `interface Gi0/1` ➔ `ip ospf shutdown` または `ospfv3 shutdown`
  * **注意:** インターフェイスの `shutdown`（物理ダウン）ではなく、OSPF 制御のみを停止させる要件が出題されます。
* **GTSM (TTL-Security) の構成と Hop-Count チューニング:**
  * 通常の直結リンク: `ip ospf ttl-security`（デフォルト: `hops 1` ➔ TTL 254 以上要求）
  * Virtual-Link または Multi-hop 環境: `ip ospf ttl-security hops <1-254>`（要求最小 TTL = `256 - hops`）
  * **落とし穴:** 片側のルータのみに `ttl-security` を設定すると、対向ルータは通常の TTL=1 で送信するため、GTSM チェックに引っかかって OSPF ネイバーが即座に DOWN します [21, 1.4.e]。

### 2. コンフィグ読解・show コマンドでの状態判定
* **`show ip ospf` の出力監査:**
  ```text
  R1# show ip ospf
   Routing Process "ospf 1" with ID 1.1.1.1
   It is admin shut down   <-- Graceful Shutdown が有効であることを示す
  ```
* **`show ip ospf interface <int>` の出力監査:**
  ```text
  R1# show ip ospf interface GigabitEthernet0/1
   GigabitEthernet0/1 is up, line protocol is up
    Strict TTL security is enabled, hop count 1   <-- GTSM が有効であることを示す
  ```
* **GTSM ドロップ統計の確認:**
  ```text
  R1# show ip ospf statistics ttl-security
   GigabitEthernet0/1:
    TTL Security drops: 142  <-- 不整合パケットがドロップされた回数
  ```

---

## 🛠 設定方法

### 1. Graceful Shutdown 設定（プロセス単位 & インターフェイス単位）

```bash
# プロセス全体の Graceful Shutdown
router ospf 1
 shutdown
!
# 特定インターフェイスのみの Graceful Shutdown (OSPFv2)
interface GigabitEthernet0/1
 ip ospf shutdown
!
# OSPFv3 インターフェイスの Graceful Shutdown
interface GigabitEthernet0/2
 ospfv3 shutdown
```

### 2. GTSM (Generic TTL Security Mechanism) 設定 (OSPFv2 / OSPFv3)

```bash
# インターフェイス個別設定 (OSPFv2)
interface GigabitEthernet0/1
 ip ospf ttl-security
!
# プロセス配下の全インターフェイス一括設定 (OSPFv2)
router ospf 1
 ttl-security all-interfaces
!
# Virtual-Link における Multi-hop GTSM 設定
router ospf 1
 area 1 virtual-link 3.3.3.3 ttl-security hops 3
!
# OSPFv3 における GTSM 設定
interface GigabitEthernet0/1
 ospfv3 ttl-security
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPF プロセス全体の運用途中状態（Shutdown 状態含む）の確認** | <code>show ip ospf</code> |
| **特定インターフェイスの GTSM 有効化状態および Hop Count の確認** | <code>show ip ospf interface GigabitEthernet0/1</code> |
| **GTSM (TTL Security) によるパケットドロップ統計数の確認** | <code>show ip ospf statistics ttl-security</code> |
| **OSPFv3 インターフェイスの Operations 状態確認** | <code>show ospfv3 interface</code> |
| **OSPF パケット受信時の TTL エラーデバッグ** | <code>debug ip ospf adj</code> / <code>debug ip ospf packets</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **GTSM 設定後、OSPF ネイバーが即座に DOWN して再確立しない。** | 片側のルータのみに GTSM（`ttl-security`）が設定され、対向ルータが TTL=1 でパケットを送信している。 | `show ip ospf statistics ttl-security`<br>`show logging` | 対向ルータでも `ip ospf ttl-security` を設定するか、対向の TTL 送信値を 255 へ調整する [21, 1.4.e]。 |
| **Virtual-Link 上で GTSM を設定したところアジャセンシーが切断された。** | 経由するエリアのホスト数（Hop Count）に対して `hops` 数が不足している（例: 2 ホスト離れているのに `hops 1` を指定）。 | `show ip ospf virtual-links` | `area <id> virtual-link <RID> ttl-security hops <count>` の hop 数を経路上の実ホスト数以上に拡大する [21, 1.4.e]。 |
| **`shutdown` を解除してもネイバーが復旧しない。** | インターフェイスレベル（`ip ospf shutdown`）とプロセスレベル（`router ospf` ➔ `shutdown`）の双方で設定が残っている。 | `show running-config \| section ospf` | `no ip ospf shutdown` および `no shutdown` を両モードから削除する [21, 1.4.e]。 |

---

## ⚠ 制限事項

1. **GTSM 非対応機器との相互運用不可:**
   GTSM は受信パケットの TTL が 254 以上であることを厳格に求めるため、パケット送信時に TTL=255 をセットできない古く非対応なサードパーティ機器とはアジャセンシーを形成できません [21, 1.4.e]。
2. **OSPF Shutdown 時の LSA 保持:**
   `shutdown` コマンド実行時、自ルータ発の LSA は Age=3600 でフラッシュされますが、プロセスが再起動するまでの間、対向側で古い LSA が一瞬残存しないよう明示的な Ack 交換が完了するまで待機が発生します [21, 1.4.e]。

---

## 🔄 他技術との関連

* **Control Plane Policing (CoPP):**
  GTSM は CoPP よりも手前のハードウェア/ASIC レベルで不整合パケット（TTL < 254）を即座に破棄するため、CoPP の CPU 負荷軽減に大きく貢献します [21, 1.4.e, 4.1.a]。
* **BGP TTL Security / BGP GTSM:**
  BGP における `neighbor <IP> ttl-security hops 1` と全く同じ原理（RFC 5082）であり、コントロールプレーンセキュリティの統一設計手順として問われます [21, 1.5.a, 4.1.a]。

---

## 🧩 比較表

### OSPF Graceful Shutdown vs Max-Metric Router LSA (Stub Router)

| 比較項目 | Graceful Shutdown (`shutdown`) | Max-Metric Router LSA (`max-metric router-lsa`) |
| :--- | :--- | :--- |
| **主目的** | プロセス/ポートの完全停止（メンテナンス撤去） [21, 1.4.e] | 経路の迂回（過渡期の Transit トラフィック遮断） [21, 1.4.f (iii)] |
| **LSA 処理** | 自身の全 LSA を Age=3600 (MaxAge) でフラッシュ [21, 1.4.e] | Type-1 LSA のリンクコストを `65535` に引上げて広報 [21, 1.4.f (iii)] |
| **OSPF ネイバー** | 完全に DOWN 状態へ移行 | UP 状態（アジャセンシー）を維持したまま迂回 [21, 1.4.f (iii)] |
| **直結トラフィック** | 自機宛て通信も停止 | 自機宛て・自機始点の通信は正常継続 [21, 1.4.f (iii)] |

---

## 💡 ベストプラクティス

1. **計画停止時の Defensive 2 段階手順:**
   メンテナンス開始時は、まず `max-metric router-lsa on-startup 300` や `max-metric router-lsa` を投入してトラフィックを優雅に迂回させた後、`ip ospf shutdown` を実行して完全停止させる [21, 1.4.e, 1.4.f (iii)]。
2. **全コントロールプレーンポートへの GTSM 標準適用:**
   直結ルータ間のすべての OSPF インターフェイスにおいて `ip ospf ttl-security` を標準構成として投入し、外部からの DoS/スプーフィング攻撃を未然に防ぐ [21, 1.4.e, 4.1.a]。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する 10 個の演習シナリオです。

### Scenario 1: OSPFv2 プロセスレベル Graceful Shutdown
* **要件:** R1 の OSPF プロセス 1 を停止し、対向ルータに LSA を即座にフラッシュさせて無瞬断で別経路へ迂回させよ [21, 1.4.e]。

**【R1】**
```bash
router ospf 1
 shutdown
```

**【検証方法】**
```bash
R1# show ip ospf
# "It is admin shut down" が出力に含まれることを確認
```

---

### Scenario 2: 特定インターフェイス単位 OSPF Shutdown
* **要件:** R1 の Gi0/1 インターフェイスでのみ OSPF 動作を停止させよ [21, 1.4.e]。

**【R1】**
```bash
interface GigabitEthernet0/1
 ip ospf shutdown
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# "OSPF is admin shutdown" を確認
```

---

### Scenario 3: 直結 1 Hop GTSM (TTL Security) 構成 (OSPFv2)
* **要件:** R1-R2 間の Gi0/1 において、GTSM（Hop Count 1）を構成せよ [21, 1.4.e (iii)]。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf ttl-security
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# "Strict TTL security is enabled, hop count 1" を確認
```

---

### Scenario 4: OSPF プロセス配下での全インターフェイス GTSM 一括有効化
* **要件:** OSPF プロセス 1 配下のすべての活性インターフェイスで GTSM を一括バインドせよ [21, 1.4.e (iii)]。

**【R1】**
```bash
router ospf 1
 ttl-security all-interfaces
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
```

---

### Scenario 5: OSPF Virtual-Link における Multi-Hop GTSM 構成
* **要件:** Area 1 を経由する Router ID 3.3.3.3 との Virtual-Link 上で、最大 3 ホスト離れを考慮した GTSM を構成せよ [21, 1.4.e (iii)]。

**【R1】**
```bash
router ospf 1
 area 1 virtual-link 3.3.3.3 ttl-security hops 3
```

**【検証方法】**
```bash
R1# show ip ospf virtual-links
# "Strict TTL security is enabled, hop count 3" を確認
```

---

### Scenario 6: OSPFv3 における GTSM (TTL Security) 構成
* **要件:** OSPFv3 プロセスにおいて、Gi0/1 上で GTSM を有効化せよ [21, 1.4.b, 1.4.e]。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ospfv3 ttl-security
```

**【検証方法】**
```bash
R1# show ospfv3 interface GigabitEthernet0/1
```

---

### Scenario 7: Max-Metric Router LSA による安全なメンテナンストラフィック迂回
* **要件:** 撤去前に自ルータ経由の Transit トラフィックを迂回させるため、Type-1 LSA コストを Max (65535) に引き上げよ [21, 1.4.f (iii)]。

**【R1】**
```bash
router ospf 1
 max-metric router-lsa
```

**【検証方法】**
```bash
R1# show ip ospf database router self-originate
# 全リンクコストが 65535 になっていることを確認
```

---

### Scenario 8: GTSM パケットドロップ動作の検証とカウンター確認
* **要件:** 不整合パケットが GTSM によって正しくドロップされたか統計を確認せよ [21, 1.4.e (iii)]。

**【検証コマンド】**
```bash
R1# show ip ospf statistics ttl-security
```

---

### Scenario 9: VRF-Aware OSPF インターフェイスでの Graceful Shutdown
* **要件:** VRF `RED` にバインドされた Gi0/2 ポートの OSPF セッションのみを安全に停止させよ [21, 1.2.e, 1.4.e]。

**【R1】**
```bash
interface GigabitEthernet0/2
 ip ospf shutdown
```

**【検証方法】**
```bash
R1# show ip ospf vrf RED interface GigabitEthernet0/2
```

---

### Scenario 10: OSPF Shutdown 解除と復旧検証
* **要件:** メンテナンス完了に伴い、R1 の Gi0/1 で設定されていた OSPF Shutdown を解除して正常復旧させよ [21, 1.4.e]。

**【R1】**
```bash
interface GigabitEthernet0/1
 no ip ospf shutdown
```

**【検証方法】**
```bash
R1# show ip ospf neighbor GigabitEthernet0/1
# ネイバーが FULL ステートへ復旧したことを確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】GTSM 設定時のネイバー切断障害
**問題:** 
R1 と R2 が直結されています。R1 の Gi0/1 で `ip ospf ttl-security` を設定した直後、R2 との OSPF ネイバーが INIT/DOWN 状態に落ちて再確立しなくなりました。R2 側の設定は変更していません。この原因と修復コンフィグを述べてください [21, 1.4.e (iii)]。

**解答・解説:**
* **原因:** 
  R1 側で GTSM を有効化すると、受信 OSPF パケットの IP TTL が 254 以上（`255 - 1 + 1`）であることを要求します。しかし対向 R2 は GTSM が未設定であるため、通常の OSPF パケットとして TTL=1 で送信します。R1 はこれを受けて「1 ホスト以上離れた場所からの不正パケット」と判断し、物理層で即座にドロップしたためネイバーが切断されました [21, 1.4.e (iii)]。
* **修復コンフィグ:**
  R2 の該当インターフェイスでも GTSM を有効化します。
  ```bash
  R2(config)# interface GigabitEthernet0/1
  R2(config-if)# ip ospf ttl-security
  ```

---

### 2. 【コンフィグ読解 / 設計】Graceful Shutdown と Stub Router 機能の使い分け
**問題:** 
以下の 2 つの要件を満たすために、それぞれ投入すべき最適な OSPF コマンドを回答してください。
1. ルータ R1 を完全に再起動するため、アジャセンシーを速やかに切断し、対向ルータに即座に LSA をフラッシュさせたい [21, 1.4.e]。
2. ルータ R1 の自機宛て通信（Web サーバ接続）は維持したまま、他ルータ間のパケット転送（Transit）から自機を外したい [21, 1.4.f (iii)]。

**解答・解説:**
* **要件 1 の解答:** `router ospf 1` 配下で `shutdown` を実行する（または該当ポートで `ip ospf shutdown`） [21, 1.4.e]。
* **要件 2 の解答:** `router ospf 1` 配下で `max-metric router-lsa` を実行する [21, 1.4.f (iii)]。

---

## 🔗 参考リソース

* [Cisco Systems: OSPF Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/17-x/iro-17-x-book.html)
* [Cisco Command Reference: ip ospf ttl-security](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/command/iro-cr-book.html)
* [Cisco Live: BRKRST-2337 - Advanced OSPF Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **GTSM TTL 計算フォーミュラ:**
  $$	ext{Required Minimum TTL} = 256 - 	ext{Hop Count}$$
  （例: `hops 1` ➔ $256 - 1 = 255$。ただし 1 Hop の過渡期考慮により実効要求値は **254** 以上）


## 参考リソースリンク

### Configurationガイド
*   [OSPFv2 Configuration Guide - TTL Security (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book/iro-ttl-security.html)。
*   [Configuring OSPFv3 Graceful Shutdown](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3-grace.html)。

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - OSPF運用のトラブル全般。
*   [BRKCCIE-3000: OSPF for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - LSA同期とセキュリティの詳細。

### テクニカルドキュメント・設定例
*   [Generic TTL Security Mechanism (GTSM) Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/116019-config-ospf-00.html)。
*   [OSPF Graceful Shutdown - Cisco Support](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13697-14.html)。

---

## 📝 補足
- この学習メモは、OSPFの「日々の運用（Operations）」と「有事の備え（Security/Maintenance）」を網羅しています。CCIEラボ試験では、特に **Graceful Shutdown** による隣接関係の制御や、**GTSM** によるインフラ保護が「見落としがちだが重要なタスク」として出題されるため、実機（EVE-NG/CML）での TTL 挙動確認を強く推奨します。


