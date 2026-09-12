---
layout: default
title: 1.3-EIGRP
parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.3 EIGRP (Enhanced Interior Gateway Routing Protocol)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP（Interior Gateway Protocol）である **1.3 EIGRP (Enhanced Interior Gateway Routing Protocol)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に完全準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**EIGRP (Enhanced Interior Gateway Routing Protocol)** は、Ciscoが開発した高度なディスタンスベクター（Advanced Distance Vector または Hybrid）ルーティングプロトコルです。DUAL (Diffusing Update Algorithm) ルーティング計算エンジンを搭載し、高速なループフリーコンバージェンス、柔軟なメトリック計算、Equal / Unequal Cost ロードバランシング、広範な要約・フィルタリング機能を誇ります。

### 主な利用目的と適用シーン
1. **エンタープライズキャンパス & WAN バックボーン:** 超高速なコンバージェンス（Feasible Successor による即時切り替え）が要求されるインフラ網。
2. **ハブ＆スポーク（DMVPN / SD-WAN アンダーレイ）トポロジー:** EIGRP Stub および Summary / Leak-map 機能を活用した、スポーク側 CPU・メモリバジェットおよびクエリ（Query）ストームの徹底的な抑制。
3. **VRF-Lite / Multi-Tenant セグメンテーション:** EIGRP Named Mode (Multi-AF) を用いた、単一プロセス内での複数 VRF (IPv4/IPv6) の一元管理。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | DUALアルゴリズムによるループフリー計算、Feasible Successorによるサブ秒切替、RTP (Reliable Transport Protocol) による信頼性保証、Protocol Dependent Modules (PDM) によるIPv4/IPv6マルチプロトコル対応。 |
| **用途** | エンタープライズ内部ルーティング、DMVPNハブ＆スポーク、SD-Accessアンダーレイ、VRF-Liteマルチテナント。 |
| **メリット** | 不等コストロードバランシング（Variance）対応、クエリドメインの限定（Stub）、低CPU/帯域消費、Named ModeによるIPv4/IPv6統合管理。 |
| **デメリット** | シスコ主導標準（RFC 7868）であるがマルチベンダー環境での完全相互運用性に制限あり。大規模メッシュ網でのQueryストームリスク（未チューニング時）。 |
| **対応機種** | Cisco Catalyst 9000 シリーズ、Catalyst 8000v、ISR/ASR シリーズ（Cisco IOS-XE 搭載全全機種）。 |
| **制限事項** | Classic Mode では Wide Metric (64-bit) 未サポート。K値（K1~K6）および AS番号の完全一致がネイバー確立の必須条件。 |
| **設計上の注意点** | DMVPNスポークでの Stub 構成（`stub-connected` 等）の徹底。要約（Summarization）設定時のブラックホール回避策（Null0ルート生成の理解）。 |

---

## 🏗 動作原理

EIGRPの動作は、**① ネイバーの発見と維持 (Hello)**、**② トポロジー情報の交換 (Update/ACK)**、**③ DUALアルゴリズムによる経路計算 (Successor/Feasible Successor)** の3段階で構成されます。

### EIGRP パケットシーケンスと DUAL ルート計算フロー

```text
[ Router A ]                                       [ Router B ]
     │                                                  │
     │─────────── Hello (Multicast 224.0.0.10) ────────►│ (1) Neighbor Discovery
     │◄────────── Hello (Multicast 224.0.0.10) ─────────│   (AS#, K-values, Auth Check)
     │                                                  │
     │─────────── Init Update (Unicast / Init Bit) ────►│ (2) Topology Exchange
     │◄────────── Init Update (Unicast / Init Bit) ─────│   (Exchange Full Routing Table)
     │─────────── ACK (Unicast) ───────────────────────►│
     │◄────────── ACK (Unicast) ────────────────────────│
     │                                                  │
     │================== DUAL Calculation ==============│ (3) Path Selection
     │                                                  │
     │  - Reported Distance (RD) / Advertised Distance (AD): 隣接ルータから宛先へのコスト
     │  - Feasible Distance (FD): 自機から宛先への最小計算コスト
     │  - Feasibility Condition (FC): RD < Current FD (ループフリーの絶対保証条件)
     │  - Successor: 最小FDを持つプライマリパス (RIBに掲載)
     │  - Feasible Successor (FS): FCを満たすバックアップパス (即座に切り替え可能)
```

---

## ⚙ 動作シーケンス

### 1. ネイバーアジャセンシー形成パラメータ検証
EIGRPパケット（IP Header Protocol 88）を受信した際、以下の属性が厳格に検証されます。
1. **AS番号 (Autonomous System Number):** 完全一致。
2. **K値 (K1, K2, K3, K4, K5, K6):** 完全一致（デフォルト: K1=1, K2=0, K3=1, K4=0, K5=0, K6=0）。
3. **認証 (Authentication):** Key-Chain / Passphrase およびアルゴリズム（MD5 / HMAC-SHA-256）の一致。
4. **Primary IP Subnet:** 同一サブネット上に存在すること（Secondary IPからのHelloは拒否）。

### 2. DUAL 状態遷移 (Passive vs Active)
* **Passive State:** 正常状態。宛先への最短パス（Successor）が健全であり、再計算が行われていない状態。
* **Active State:** Successor リンクがダウンし、かつ Feasible Successor (FS) が存在しない場合、ルータはルートを **Active** 状態に変更し、全隣接ルータへ **Query** パケット（Multicast/Unicast）を送出して代替パスを捜索します。全隣接から **Reply** を受信するまで該当ルートの転送はサスペンドされます。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Classic Mode vs Named Mode の対比と記述変換
CCIE EI ラボ試験では、従来型の `router eigrp <AS>` (Classic Mode) から、標準推奨である `router eigrp <NAME>` (Named Mode) への移行・統合問題が極めて高い頻度で提示されます。

* **Named Mode の構造階層:**
  ```text
  router eigrp KBITS (モード名)
   └── address-family ipv4 unicast autonomous-system 100 (AF & AS定義)
        ├── af-interface default (全インターフェイス共通パラメータ)
        ├── af-interface GigabitEthernet1/0/1 (インターフェイス固有設定)
        └── topology base (サマリー、再配送、フィルタリング、Variance等)
  ```

### 2. Wide Metric (64-bit) と K6 (Rib Metric / Extended Attributes)
Named Modeでは、デフォルトで **Wide Metric (64-bit)** が有効化されます。
* **Throughput Base (64-bit):** \(\text{Throughput Metric} = (10^7 \times 65536) / \text{Bandwidth (Kbps)}\)
* **Latency Base (64-bit):** \(\text{Latency Metric} = (\text{Delay in picoseconds} \times 65536) / 10^6\)
* **Scale Factor:** Classic Metric (32-bit) との互換性を保つため、デフォルトで Scale Factor `128` が乗算/除算されます。

### 3. EIGRP Stub の動作タイプと Leak-Map 結合
EIGRP Stub は、スポークルータからの Query 受信を防止（Query ドメインの遮断）するために使用されます。
* **`stub receive-only`:** 経路を1つもアドバタイズしない。
* **`stub connected`:** 直結ネットワークのみアドバタイズ。
* **`stub summary`:** 要約経路のみアドバタイズ。
* **`stub static`:** スタティック経路のみアドバタイズ。
* **`stub redistributed`:** 再配送経路のみアドバタイズ。
* **`stub leak-map <MAP_NAME>`:** Stub 制限を維持しつつ、特定のプレフィックス（例: /32 ループバック等）のみを例外的にアドバタイズ（Leak）させる。

### 4. Variance による Unequal Cost Load Balancing（不等コスト負荷分散）
* **計算ルール:** \(\text{Feasible Successor の FD} < \text{Successor の FD} \times \text{Variance Value}\)
* **絶対必要条件:** 当該パスが **Feasibility Condition (RD < Current FD)** を事前に満たしていること。FCを満たしていない候補パスは、どれだけ Variance 値を引き上げても絶対ロードバランシングの対象になりません。

---

## 🛠 設定方法

### 1. EIGRP Named Mode (Multi-AF IPv4/IPv6) 基本構成

```bash
# EIGRP Named Mode プロセスの起動
router eigrp CCIE_FABRIC

 # IPv4 Address Family の定義
 address-family ipv4 unicast autonomous-system 100
  # 全インターフェイス共通設定
  af-interface default
   passive-interface
  exit-af-interface
  
  # 特定インターフェイスのパッシブ解除と認証設定
  af-interface GigabitEthernet1/0/1
   no passive-interface
   authentication mode hmac-sha-256 CiscoPASS123!
  exit-af-interface
  
  # トポロジー共通設定（ネットワーク宣言、要約、Variance）
  topology base
   network 10.1.0.0 0.0.255.255
   network 172.16.1.1 0.0.0.0
   variance 2
  exit-af-topology
 exit-address-family

 # IPv6 Address Family の定義
 address-family ipv6 unicast autonomous-system 100
  af-interface default
   no shutdown
  exit-af-interface
  topology base
  exit-af-topology
 exit-address-family
```

### 2. EIGRP Stub と Leak-Map の設定

```bash
ip prefix-list PL_LEAK permit 192.168.10.0/24

route-map RM_LEAK permit 10
 match ip address prefix-list PL_LEAK

router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  # Stub構成（Connected + Summary）に Leak-Map をバインド
  eigrp stub connected summary leak-map RM_LEAK
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EIGRP ネイバーテーブル確認（Hold Time、SRTT、RTO、Q-Count）** | <code>show ip eigrp neighbors</code> / <code>show eigrp address-family ipv4 neighbors</code> |
| **EIGRP トポロジーテーブル詳細確認（FD, RD, FC適合チェック, FS一覧）** | <code>show ip eigrp topology</code> / <code>show ip eigrp topology all-links</code> |
| **EIGRP インターフェイス状態および Passive 指定の確認** | <code>show ip eigrp interfaces detail</code> |
| **EIGRP プロセス詳細情報（K値、AS番号、Variance、Stubステート確認）** | <code>show ip eigrp protocols</code> / <code>show eigrp address-family ipv4 accounting</code> |
| **EIGRP パケット送受信（Hello, Update, Query, Reply）のリアルタイムデバッグ** | <code>debug eigrp packets</code> / <code>debug ip eigrp notifications</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **EIGRP ネイバーが形成されず「K-value mismatch」ログが出力される。** | 隣接機器間で **K値（K1〜K6）の設定が不一致**。または Named Mode (Wide Metric) と Classic Mode 間での意図しない K6 パラメータの不整合。 | `show ip eigrp protocols` | 両端の `metric weights` 設定を合わせるか、デフォルトの K1=1, K3=1 に統一する。 |
| **EIGRP ネイバーが「SIIT (Stuck In Active)」状態に陥り、頻繁にリセットされる。** | 1. リンク過負荷・ドロップによる Query/Reply 消失。<br>2. 相手ルータが Query に対する Reply を制限時間内（デフォルト3分）に返さない。 | `show ip eigrp topology active`<br>`show ip eigrp neighbors` | 1. 物理リンク品質の確認。<br>2. 適切なポイントへの **EIGRP Stub** および **Route Summarization** の導入による Query ドメイン限定。 |
| **Variance を設定したのに、バックアップパスがルーティングテーブル（RIB）に載らない。** | 該当パスが **Feasibility Condition (RD < Current FD) を満たしていない** ため、Feasible Successor として認識されていない。 | `show ip eigrp topology all-links` | 該当パスの RD 値を調べる。RD を下げるために帯域幅（bandwidth）や遅延（delay）パラメータを対向側でチューニングする。 |
| **再配送した経路（EIGRP External）が隣接ルータへアドバタイズされない。** | 再配送時に **シードメトリック（Seed Metric）が指定されていない** ため、メトリック無限大（Inaccessible）として処理されている。 | `show ip eigrp topology` | `redistribute` コマンド配下に `metric <bw> <delay> <reliability> <load> <mtu>` を明示的に追加する。 |

---

## ⚠ 制限事項

1. **Classic Mode における 64-bit Wide Metric 非サポート:**
   IOS-XE 環境において、Classic Mode (`router eigrp <AS>`) は 32-bit Classic Metric のみサポートします。10G/100G リンクの精度向上には Named Mode への完全移行が必要です。
2. **EIGRP Secondary IP アドレスにおける Hello パケット制約:**
   EIGRP は Primary IP アドレスのサブネットを送信元として Hello パケットを出力します。Secondary IP サブネットのみが一致している環境ではネイバーは確立しません。
3. **DMVPN Phase 3 における Split Horizon の制約:**
   DMVPN Hub インターフェイスにおいて、スポーク間相互通信を直接確立・アドバタイズさせるため、`no ip split-horizon eigrp <AS>` の無効化が必須となります。

---

## 🔄 他技術との関連

* **DMVPN (Phase 1 / Phase 2 / Phase 3):**
  Hubルータでの `no ip split-horizon eigrp <AS>` および `no ip next-hop-self eigrp <AS>`（Phase 2/3）の設定。Spokeルータへの Query 抑制のための `eigrp stub` 構成。
* **BGP / OSPF 相互再配送 (Redistribution):**
  EIGRP への再配送時のシードメトリックアサイン。EIGRP Internal (AD 90) と External (AD 170) の AD 差を活用したループ防止設計。
* **BFD (Bidirectional Forwarding Detection):**
  EIGRP Named Mode において `af-interface` 配下で `bfd` を直接バインドし、ミリ秒単位の障害検知とアジャセンシー切断の連動。

---

## 🧩 比較表

### EIGRP Classic Mode vs EIGRP Named Mode

| 比較項目 | Classic Mode (`router eigrp <AS>`) | Named Mode (`router eigrp <NAME>`) |
| :--- | :--- | :--- |
| **設定体系** | IPv4 と IPv6 で個別のグローバルプロセス（分散構成） | 単一プロセスの `address-family` 内で統合管理 |
| **メトリック計算** | 32-bit Classic Metric のみ | 64-bit Wide Metric (64-bit) デフォルト |
| **認証設定** | インターフェイスモード配下で設定 (`ip authentication ...`) | EIGRP AF インターフェイスモード内で集中管理 |
| **VRF サポート** | ルータプロセス単位での記述 | `address-family ipv4 vrf <NAME>` で柔軟構成 |
| **推奨運用** | レガシー非推奨 | Cisco IOS-XE ベストプラクティス（標準） |

---

## 💡 ベストプラクティス

1. **全ネットワークでの Named Mode 採用:**
   64-bit Wide Metric による高速リンクの正確なコスト計算と、IPv4/IPv6/VRF の一元管理のために Named Mode を標準化する。
2. **ハブ＆スポーク網での EIGRP Stub 100% 適用:**
   すべての Spoke ルータに対して `eigrp stub connected summary` を設定し、Query パケットの無駄な伝搬（SIIT 事故）を物理的に遮断する。
3. **明示的な Delay によるトラフィックエンジニアリング:**
   EIGRP のパス制御を行う場合、`bandwidth`（QoSや他機能に影響を与える）を変更するのではなく、**`delay`（ピコ秒単位）** を調整してコストを制御する。

---

## 📝 ラボ学習・設定サンプル例

CCIE EI ラボ試験レベルを意識した、省略なしの厳格な10個の完全設定演習シナリオです。

### 1. EIGRP Named Mode 基本構成と Wide Metric 有効化
**【問題】** SW1 と SW2 間で EIGRP Named Mode プロセス `CCIE_CORE` (AS 100) を構成し、GigabitEthernet1/0/1 上で通信を確立させなさい。

**【設定例】**
```bash
# [SW1]
router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet1/0/1
   no passive-interface
  exit-af-interface
  topology base
   network 10.1.12.1 0.0.0.0
  exit-af-topology
 exit-address-family

# [SW2]
router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet1/0/1
   no passive-interface
  exit-af-interface
  topology base
   network 10.1.12.2 0.0.0.0
  exit-af-topology
 exit-address-family
```

---

### 2. EIGRP HMAC-SHA-256 認証 (Named Mode)
**【問題】** SW1 と SW2 間の EIGRP アジャセンシーに対して、パスフレーズ `Cisco123Secret` を使用した HMAC-SHA-256 認証をアサインしなさい。

**【設定例】**
```bash
# [SW1]
router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet1/0/1
   authentication mode hmac-sha-256 Cisco123Secret
  exit-af-interface
 exit-address-family
```

---

### 3. Key-Chain による MD5 無停止鍵ローテーション
**【問題】** Key-Chain `EIGRP_KEYS` を作成し、Key 1 と Key 2 の受送信ライフタイムを適切にオーバーラップさせて配置しなさい。

**【設定例】**
```bash
key chain EIGRP_KEYS
 key 1
  key-string KeyOnePASSED
  accept-lifetime 00:00:00 Jan 1 2026 01:05:00 Jan 1 2026
  send-lifetime 00:00:00 Jan 1 2026 01:00:00 Jan 1 2026
 key 2
  key-string KeyTwoPASSED
  accept-lifetime 00:55:00 Jan 1 2026 02:00:00 Jan 1 2026
  send-lifetime 01:00:00 Jan 1 2026 02:00:00 Jan 1 2026

router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet1/0/1
   authentication mode md5
   authentication keychain EIGRP_KEYS
  exit-af-interface
 exit-address-family
```

---

### 4. EIGRP Stub Router と Leak-Map 結合
**【問題】** R1 を EIGRP Stub ルータとして構成しつつ、プレフィックス `10.200.1.0/24` のみを例外的に上位へアドバタイズしなさい。

**【設定例】**
```bash
ip prefix-list PL_LEAK_10 permit 10.200.1.0/24

route-map RM_EIGRP_LEAK permit 10
 match ip address prefix-list PL_LEAK_10

router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  topology base
   eigrp stub connected summary leak-map RM_EIGRP_LEAK
  exit-af-topology
 exit-address-family
```

---

### 5. Variance による不等コストロードバランシング
**【問題】** R1 において、プライマリパス (FD: 1000) とセカンダリパス (FD: 2500, RD: 800) の両方へトラフィックをロードシェアするように Variance を設定しなさい。

**【設定例】**
```bash
# Feasibility Condition チェック: RD (800) < Current FD (1000) ➔ 適合 (FSとして存在)
# 必要Variance算出: 2500 / 1000 = 2.5 ➔ 上上げして「3」

router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  topology base
   variance 3
  exit-af-topology
 exit-address-family
```

---

### 6. 手動ルートサマリー (Manual Summarization) と Null0 ドロップ抑制
**【問題】** R1 の Interface GigabitEthernet1/0/1 において、`10.1.0.0/16` のサマリーアドレスを送出し、かつ自動生成される Null0 ルートの Administrative Distance を `255` に変更して無効化しなさい。

**【設定例】**
```bash
router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet1/0/1
   summary-address 10.1.0.0 255.255.0.0
  exit-af-interface
  topology base
   summary-metric 10.1.0.0/16 distance 255
  exit-af-topology
 exit-address-family
```

---

### 7. Distribute-List と Prefix-List による送信経路フィルタリング
**【問題】** R1 から隣接ルータへ向けて `172.16.0.0/16` 配下のネットワークのみを許可し、その他をブロックするアウトバウンドフィルタを適用しなさい。

**【設定例】**
```bash
ip prefix-list PL_OUT_ALLOW permit 172.16.0.0/16 ge 16 le 32

router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  topology base
   distribute-list prefix PL_OUT_ALLOW out GigabitEthernet1/0/1
  exit-af-topology
 exit-address-family
```

---

### 8. Offset-List による特定のパスの遅延（Metric）手動加算
**【問題】** R1 において、`192.168.1.0/24` 経路のメトリックを GigabitEthernet1/0/1 上で手動で `5000` 追加しなさい。

**【設定例】**
```bash
ip access-list standard ACL_OFFSET
 permit 192.168.1.0 0.0.0.255

router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  topology base
   offset-list ACL_OFFSET in 5000 GigabitEthernet1/0/1
  exit-af-topology
 exit-address-family
```

---

### 9. VRF-Aware EIGRP Named Mode (Multi-Tenant)
**【問題】** VRF `RED` 配下で EIGRP AS 200 を動作させ、GigabitEthernet1/0/2 上でルート交換を実行しなさい。

**【設定例】**
```bash
vrf definition RED
 address-family ipv4
 exit-address-family

interface GigabitEthernet1/0/2
 vrf forwarding RED
 ip address 10.200.1.1 255.255.255.0

router eigrp CCIE_CORE
 address-family ipv4 unicast vrf RED autonomous-system 200
  topology base
   network 10.200.1.0 0.0.0.255
  exit-af-topology
 exit-address-family
```

---

### 10. DMVPN Hub における EIGRP スプリットホライズン無効化
**【問題】** DMVPN Hub の Tunnel 0 インターフェイスにおいて、EIGRP のスプリットホライズン処理を停止し、スポーク間での経路学習を有効化しなさい。

**【設定例】**
```bash
router eigrp CCIE_CORE
 address-family ipv4 unicast autonomous-system 100
  af-interface Tunnel0
   no split-horizon
  exit-af-interface
 exit-address-family
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解：Variance と Feasibility Condition の不適合】
**問題:** 
以下のトポロジーとコンフィグにおいて、R1のルーティングテーブル（RIB）に `192.168.10.0/24` へのパスが1つしか掲載されません。Variance を `5` に引き上げているにもかかわらず、R3経由のパスが ECMP/Unequal Cost パスとして反映されない理由を論理的に説明しなさい。

```text
[R1] ─── Path A (FD: 100) ───► [Dst: 192.168.10.0/24]
  │
 Path B (FD: 300, RD from R3: 150)
  │
  ▼
 [R3]
```

**解答・解説:**
* **理由:** R3 経由のパスが **Feasibility Condition (FC)** を満たしていないため。
* **技術的判定:**
  * Current FD (R1から最小コスト) = `100`
  * R3 からの Reported Distance (RD) = `150`
  * FC 条件ルール: `RD < Current FD` ➔ `150 < 100` (偽/False)
* **結論:** Feasibility Condition を満たさないパスは、ループが発生する危険性を排斥できないため、EIGRP は当該パスを Feasible Successor (FS) として絶対に認定しません。FS でないパスは Variance の倍率をいくら上げてもロードバランシング対象になりません。

---

### 2. 【トラブルシュート：EIGRP Stub 導入に伴う通信不可】
**問題:** 
DMVPN スポーク R2 上で `eigrp stub connected` を投入した直後、R2 に接続された Loopback1 (`172.16.1.1/24`) への通信が本社 R1 から不可能になりました。Loopback1 は `network 172.16.1.1 0.0.0.0` で EIGRP に参加しています。原因と修復コマンドを提示しなさい。

**解答・解説:**
* **原因:** `eigrp stub connected` コマンドは、**「物理的に UP しているインターフェイスにアサインされた Connected 経路」** のみをアドバタイズします。IOS-XE の仕様において、パッシブまたは一般的な Loopback インターフェイスは、特定設定下で Connected リストから外れるか、`summary` が欠落することでアドバタイズ対象から除外されるケースがあります。また、`stub` コマンドに `summary` や `receive-only` が意図せず重複適用されている可能性があります。
* **修復策:**
  ```bash
  router eigrp CCIE_CORE
   address-family ipv4 unicast autonomous-system 100
    topology base
     eigrp stub connected summary
    exit-af-topology
   exit-address-family
  ```

---

## 🔗 参考リソース

### Cisco Configuration Guide / Official References
* [**Cisco IP Routing: EIGRP Configuration Guide, Cisco IOS XE 17.x**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-16/ire-xe-16-book.html)
  * EIGRP Named Mode, Wide Metrics, HMAC-SHA-256 認証の全公式設定ガイド。
* [**EIGRP Command Reference, Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/command/ire-cr-book.html)
  * EIGRP 関連 CLI コマンドの完全構文リファレンス。

### Cisco Live / Technical White Papers
* [**BRKCRS-2042: Detailed EIGRP Architecture and Wide Metrics (Cisco Live)**](https://www.ciscolive.com/global/on-demand-library.html)
  * 64-bit Wide Metric の内部計算式、K6 拡張属性、DUAL ステートマシンの深掘り資料。
* [**RFC 7868: Cisco's Enhanced Interior Gateway Routing Protocol (EIGRP)**](https://datatracker.ietf.org/doc/html/rfc7868)
  * IETF RFC として公開された EIGRP のオープンプロトコル仕様書。

---

## 📝 **補足（Notes）**

### EIGRP K値と Wide Metric スケーリング式速参照
* **K1:** Bandwidth
* **K2:** Load
* **K3:** Delay
* **K4:** Reliability
* **K5:** MTU
* **K6:** Extended Attributes (Jitter, Energy, etc.)

```text
[Wide Metric 64-bit 計算基本式]
Metric = (K1 * Throughput) + [(K2 * Throughput) / (256 - Load)] + (K3 * Latency) + Extended_Attributes
```


