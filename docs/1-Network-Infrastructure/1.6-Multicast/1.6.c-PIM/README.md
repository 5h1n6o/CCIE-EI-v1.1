---
layout: default
title: 1.6.c-PIM
parent: 1.6-Multicast
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.6.c PIM (Protocol Independent Multicast)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における IP マルチキャストルーティングの中核技術である **PIM (Protocol Independent Multicast)** について、Cisco IOS-XE 17.x の実装基準に完全準拠し、Sparse Mode、RP マッピング（Static RP, Auto-RP, BSR）、SSM、Multicast Boundary、PIMv6 Anycast RP、IPv4 Anycast RP using MSDP、および Multicast Multipath に至る全サブトピックを網羅して詳細に解説します [23, 1.6.c; 137, Auto-RP Overview, BSR Overview, IP Multicast Boundary]。

---

## 📘 概要

**PIM (Protocol Independent Multicast)** は、特定のユニキャストルーティングプロトコル（OSPF, EIGRP, BGP 等）に依存せず、既存の IP ルーティングテーブル（RIB/MRIB）を利用してマルチキャスト配信ツリー（Distribution Tree）を動的に構築・維持するプロトコルです [23, 1.6.c]。

エンタープライズ網およびサービスプロバイダー網において、1対多（One-to-Many）または多対多（Many-to-Many）の映像配信、音声・データ同期、金融マーケットデータ転送などを効率的に行うために必須のインフラ技術です。

### 該当サブトピック一覧 (CCIE EI v1.1 Blueprint)
* **1.6.c (i) Sparse mode:** 明示的な参加要求（Explicit Join）に基づく共有ツリー (*,G) および送信元ツリー (S,G) の構築メカニズム [23, 1.6.c (i)]。
* **1.6.c (ii) Static RP, BSR, Auto-RP:** ランデブーポイント（RP）の情報を網内に伝搬・割り導く3大マッピング方式 [137, Auto-RP Overview, BSR Overview]。
* **1.6.c (iii) Group-to-RP mapping:** グループアドレスと RP のバインド規則、および競合時の優先決定アルゴリズム [137, Auto-RP Overview, BSR Overview]。
* **1.6.c (iv) Source Specific Multicast (SSM):** RP を介さずレシーバーが送信元 IP を直接指定する軽量かつ高セキュリティなマルチキャスト配信モデル（`232.0.0.0/8`） [23, 1.6.c (iv)]。
* **1.6.c (v) Multicast boundary, RP announcement filter:** 管理境界でのマルチキャストトラフィック/制御パケット遮断、および悪意ある/誤った RP 広告のフィルタリング [137, IP Multicast Boundary]。
* **1.6.c (vi) PIMv6 anycast RP:** IPv6 環境において MSDP なしで複数 RP 間の冗長・負荷分散を実現する Anycast RP メカニズム (RFC 4610) [23, 1.6.c (vi)]。
* **1.6.c (vii) IPv4 anycast RP using MSDP:** IPv4 環境において MSDP (Multicast Source Discovery Protocol) を用いた Source-Active (SA) 情報の共有による RP 冗長化 [23, 1.6.c (vii)]。
* **1.6.c (viii) Multicast multipath:** ECMP（等コストマルチパス）環境におけるマルチキャストトラフィックのマルチパス負荷分散・ECMPハッシュ制御 [23, 1.6.c (viii)]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | ユニキャスト RIB を逆引き参照（RPF）し、ループのないマルチキャストツリー（Shared Tree / Shortest Path Tree）を構築 [23, 1.6.b, 1.6.c] |
| **主な用途** | 防犯カメラ映像集約、株式・金融リアルタイムデータ配信、ビデオ会議、SD-WAN/SD-Access オーバーレイアンダーレイマルチキャスト |
| **メリット** | 不要な全網フラッディングを完全に防止。受信者が存在するインターフェイスにのみ動的転送し帯域を劇的に節約 |
| **デメリット** | RP の単一障害点化・ボトルネック化リスク（Anycast RP や BSR で解決が必要）、RPF チェック失敗によるドロップ障害のデバッグ難易度 |
| **対応機種** | Cisco Catalyst 9000 シリーズ、Catalyst 8000v、ISR 4000、ASR 1000（Cisco IOS-XE 全般） |
| **制限事項** | Dense Mode は現在非推奨。PIM Sparse-Mode での Auto-RP 制御パケット通過には `auto-rp listener` が必須 [137, Auto-RP Overview] |
| **設計上の注意点** | 複数 RP マッピング方式混在時の優先順位の理解。ECMP 時のデフォルト単一パス固定挙動と `ip pim multipath` の適用 |

---

## 🏗 動作原理

PIM Sparse Mode (PIM-SM) は「Pull モデル」を採用しています。レシーバーから IGMP Join が送られてくるまで、マルチキャストトラフィックはレシーバー側へ転送されません [23, 1.6.a, 1.6.c]。

### 1. 共有ツリー (*,G) と送信元ツリー (S,G)

```
[ Multicast Source (S) ]
          │ (S,G) PIM Register / Native
          ▼
    [ First-Hop Router (FHR) ]
          │
          │  Shortest Path Tree (SPT)
          ▼
   [ Rendezvous Point (RP) ] ◄━━━━ Shared Tree (*,G) ━━━━ [ Last-Hop Router (LHR) ]
                                                                   ▲
                                                                   │ IGMP Join
                                                           [ Receiver (Host) ]
```

1. **レシーバー参加:** ホストが IGMPv2/v3 Join を送出すると、LHR (Last-Hop Router) が RP へ向けて `(*,G) Join` を送出し、**Shared Tree（(*,G) 共有ツリー）** が形成されます [23, 1.6.a, 1.6.c]。
2. **送信元登録:** Source がパケットを送出すると、FHR (First-Hop Router) がパケットを PIM Register パケットにカプセル化して RP へユニキャスト送信（Register 処理）します [23, 1.6.c]。
3. **SPT Switchover (SPT スイッチオーバー):** LHR は最初のマルチキャストパケットを (*,G) ツリー経由で受け取ると、パケット内の送信元 IP (S) を認識し、Source 直近の FHR へ向けて `(S,G) Join` を送出します。これにより、RP をバイパスする最短経路 **Shortest Path Tree ((S,G) 固有ツリー)** へ動的に切替（SPT Switchover）が行われます [23, 1.6.c]。

---

## ⚙ 動作シーケンス

PIM-SM におけるパケット処理および RP マッピング処理のシーケンスは以下の通りです。

```
Receiver           LHR                  RP                  FHR             Source
   │                │                    │                   │                │
   │── IGMP Join ──►│                    │                   │                │
   │                │── (*,G) PIM Join ─►│                   │                │
   │                │                    │                   │◄─ Data Stream ─│
   │                │                    │◄─ PIM Register ───│ (Unicast Encap)│
   │                │                    │── Register-Stop ─►│                │
   │                │◄─ Native (S,G) ────│                   │                │
   │                │                    │                   │                │
   │                │══════════ (S,G) PIM Join ─────────────►│ (SPT Switch)   │
   │                │◄═════════ Native Direct (S,G) Stream ══│                │
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI ラボ試験において PIM 領域は、非常に細かい仕様理解とコンフィグの正確性が合否を分けます。

### 1. Blueprintで重要なポイント
* **Group-to-RP マッピングの優先順位競合:** 同一ルータ上で複数の RP マッピングが受信・設定された場合の優先決定ルールの丸暗記 [137, Auto-RP Overview, BSR Overview]。
* **PIM-SM での Auto-RP パス阻害:** PIM Sparse Mode 単体では Auto-RP の制御マルチキャストパケット（`224.0.1.39` / `224.0.1.40`）が転送できません。これを許可する `ip pim auto-rp listener` の指定が絶対必須です [137, Auto-RP Overview]。
* **MSDP Anycast RP vs PIMv6 Anycast RP:** IPv4 では MSDP (`ip msdp peer`) を用いた SA (Source-Active) 同期、IPv6 では MSDP が存在しないため RFC 4610 (`ipv6 pim anycast-rp`) による PIM 制御パケットでの RP 同期を行います [23, 1.6.c (vi), 1.6.c (vii)]。
* **Multicast Boundary と RP Announcement Filter:** `ip multicast boundary` を用いて、データトラフィックだけでなく Auto-RP / BSR の制御パケットの境界通過を防止する設定 [137, IP Multicast Boundary]。

### 2. Group-to-RP Mapping 優先度判定ルール（絶対暗記）

上から順に評価され、一致したものが即座に採用されます [137, Auto-RP Overview, BSR Overview]。

1. **Static RP (override オプションあり):** `ip pim rp-address <IP> <ACL> override` [137, Auto-RP Overview]
2. **Auto-RP (Mapping Agent からの広告):** Auto-RP で学習したマップ [137, Auto-RP Overview]
3. **BSR (Bootstrap Router からの広告):** BSR で学習したマップ [137, BSR Overview]
4. **Static RP (override オプションなし):** `ip pim rp-address <IP> <ACL>` [137, Auto-RP Overview]
5. **Embedded RP (IPv6 のみ):** IPv6 アドレス自体に埋め込まれた RP 情報

---

## 🛠 設定方法

### 1. PIM Sparse-Mode & Static RP 設定例
```bash
ip multicast-routing
!
interface GigabitEthernet0/0/1
 ip address 10.1.12.1 255.255.255.0
 ip pim sparse-mode
!
ip pim rp-address 10.1.255.100 MULTICAST_GROUPS
!
ip access-list standard MULTICAST_GROUPS
 permit 239.0.0.0 0.255.255.255
```

### 2. Auto-RP (Candidate RP & Mapping Agent) 設定例
```bash
ip multicast-routing
ip pim auto-rp listener
!
! --- Candidate RP (C-RP) 設定 ---
ip pim send-rp-announce Loopback0 scope 16 group-list C_RP_GROUPS
!
! --- Mapping Agent (MA) 設定 ---
ip pim send-rp-discovery Loopback0 scope 16
!
ip access-list standard C_RP_GROUPS
 permit 239.1.0.0 0.0.255.255
```

### 3. BSR (Candidate BSR & Candidate RP) 設定例
```bash
ip multicast-routing
!
! --- Candidate BSR 設定 ---
ip pim bsr-candidate Loopback0 30 192
!
! --- Candidate RP 設定 ---
ip pim rp-candidate Loopback0 group-list BSR_RP_GROUPS
!
ip access-list standard BSR_RP_GROUPS
 permit 239.2.0.0 0.0.255.255
```

### 4. IPv4 Anycast RP using MSDP 設定例
```bash
! --- RP-1 & RP-2 共通設定 (Anycast IP: 10.1.255.100) ---
ip multicast-routing
interface Loopback0
 description Physical IP for MSDP
 ip address 10.1.1.1 255.255.255.255
 ip pim sparse-mode
!
interface Loopback100
 description Anycast RP IP
 ip address 10.1.255.100 255.255.255.255
 ip pim sparse-mode
!
ip pim rp-address 10.1.255.100
!
! --- MSDP ピアリング (RP-1 上での設定) ---
ip msdp peer 10.1.1.2 connect-source Loopback0
ip msdp originator-id Loopback0
```

### 5. PIMv6 Anycast RP (RFC 4610) 設定例
```bash
ipv6 unicast-routing
ipv6 multicast-routing
!
interface Loopback0
 ipv6 address 2001:DB8:1::1/128
 ipv6 pim
!
interface Loopback100
 ipv6 address 2001:DB8:RP::100/128
 ipv6 pim
!
ipv6 pim rp-address 2001:DB8:RP::100
ipv6 pim anycast-rp 2001:DB8:RP::100 2001:DB8:1::1
ipv6 pim anycast-rp 2001:DB8:RP::100 2001:DB8:1::2
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| PIM ネイバー状態の確認 | `show ip pim neighbor` / `show ipv6 pim neighbor` |
| Group-to-RP マッピングの確認 | `show ip pim rp mapping` / `show ipv6 pim rp mapping` |
| マルチキャストルーティングテーブル (mroute) の確認 | `show ip mroute` / `show ipv6 mroute` |
| Auto-RP 広告情報の確認 | `show ip pim auto-rp` |
| BSR 状態および当選 BSR の確認 | `show ip pim bsr-router` |
| MSDP ピアリングおよび SA キャッシュの確認 | `show ip msdp peer` / `show ip msdp sa-cache` |
| PIM リアルタイムデバッグ | `debug ip pim` / `debug ip pim auto-rp` / `debug ip msdp` |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| Auto-RP で RP マッピングが学習できない | PIM-SM 環境で `auto-rp listener` が未設定のため、`224.0.1.39/40` がドロップされている | `show ip pim rp mapping` | 全ルータで `ip pim auto-rp listener` を設定する [137, Auto-RP Overview] |
| MSDP Anycast RP で SA キャッシュが同期しない | MSDP Peer の RPF チェック失敗、または `connect-source` の IP 不一致 | `show ip msdp peer` | `connect-source` に物理 Loopback アドレスを正しく指定する [23, 1.6.c (vii)] |
| ECMP パスで一部のマルチキャストトラフィックが流れない | デフォルトでは単一の RPF ネイバーのみが選択される | `show ip mroute count` | `ip pim multipath` を有効化して ECMP 負荷分散を行う [23, 1.6.c (viii)] |
| BSR 広告が特定のエリアに届かない | 境界ルータで `ip multicast boundary` または TTL 制限により BSR メッセージが遮断されている | `show ip pim bsr-router` | Boundary ACL で `224.0.0.13` を許可するかスコープを調整する [137, IP Multicast Boundary] |

---

## ⚠ 制限事項

* **Dense Mode の非推奨:** PIM Dense Mode (PIM-DM) は大規模網でのフラッディング負荷が高いため、現代の CCIE EI 試験および実務設計では完全非推奨。
* **MSDP の IPv6 非対応:** MSDP は IPv4 専用プロトコルです。IPv6 で Anycast RP を構成する場合は、PIMv6 Anycast RP (RFC 4610) を使用しなければなりません [23, 1.6.c (vi), 1.6.c (vii)]。
* **SPT Threshold:** Cisco IOS-XE ではデフォルトで最初のパケット受容時に即座に SPT へ切替わります（`ip pim spt-threshold infinity` を設定すると共有ツリー固定に強制変更可能）。

---

## 🔄 他技術との関連

* **IGMP / MLD:** レシーバーホストが LHR に対してグループ参加を伝える L2/L3 シグナリング。PIM はこれを受けて (*,G) Join を送出する [23, 1.6.a, 1.6.c]。
* **Unicast Routing (OSPF / EIGRP / BGP):** PIM は独自でルーティングテーブルを持たず、ユニキャスト RIB を参照して RPF チェックを実行する [23, 1.6.b, 1.6.c]。
* **VRF Lite / MPLS L3VPN:** VRF ごとに独立した PIM プロセスおよび Anycast RP / MSDP セッションを動作させることが可能 [23, 1.2.e, 1.6.c]。

---

## 🧩 比較表

### 1. RP マッピング方式の比較

| 項目 | Static RP | Auto-RP | BSR (Bootstrap Router) |
| :--- | :--- | :--- | :--- |
| **シスコ固有/標準** | 標準 | Cisco 固有 | IETF 標準 (RFC 5059) |
| **制御パケット** | なし | マルチキャスト (`224.0.1.39/40`) | マルチキャスト (`224.0.0.13` Hop-by-Hop) |
| **Sparse Mode での要件** | 手動コンフィグのみ | `ip pim auto-rp listener` が必須 | 特になし (Hop-by-Hop PIM パケット) |
| **決定ロジック** | 優先度 4（override なし時） | 優先度 2（Mapping Agent 由来） | 優先度 3（BSR 由来） |
| **主な用途** | 小規模網、固定 RP | シスコ中心の中大規模網 | マルチベンダー環境の中大規模網 |

---

## 💡 ベストプラクティス

1. **RP 冗長化の選定:** IPv4 では MSDP Anycast RP、IPv6 では PIMv6 Anycast RP (RFC 4610) を第一選択とする。
2. **Auto-RP 運用時の必須設定:** PIM Sparse Mode を採用する場合は、予期せぬ通信断を防ぐため、常に全ルータで `ip pim auto-rp listener` をグローバル設定しておく [137, Auto-RP Overview]。
3. **RP 悪意広告の防衛:** 不正なルータが C-RP や C-BSR に名乗り出るのを防ぐため、境界およびコアで `ip pim accept-rp` や `ip pim bsr-border` を適用する [137, IP Multicast Boundary]。

---

## 📝 ラボ学習・設定サンプル例

### 実践ラボ問題 1: PIM-SM と Static RP の基本構築
* **要件:** 全ルータで PIM-SM を有効化し、R1 (Loopback0: `10.1.1.1`) を Static RP として設定せよ。グループ `239.1.1.0/24` のみ指定すること。
* **設定例 (全ルータ):**
```bash
ip multicast-routing
!
interface GigabitEthernet0/0/1
 ip pim sparse-mode
!
ip pim rp-address 10.1.1.1 STATIC_RP_GROUPS
!
ip access-list standard STATIC_RP_GROUPS
 permit 239.1.1.0 0.0.0.255
```
* **検証方法:** `show ip pim rp mapping` で `10.1.1.1` が Static としてバインドされていることを確認する。

### 実践ラボ問題 2: Auto-RP (C-RP & MA) と Auto-RP Listener
* **要件:** R2 を Candidate RP、R3 を Mapping Agent として構成せよ。PIM-SM 環境下で Auto-RP パケットが滞りなく通過する設定を追加すること。
* **設定例 (全ルータ共通):**
```bash
ip multicast-routing
ip pim auto-rp listener
```
* **設定例 (R2 - Candidate RP):**
```bash
ip pim send-rp-announce Loopback0 scope 16
```
* **設定例 (R3 - Mapping Agent):**
```bash
ip pim send-rp-discovery Loopback0 scope 16
```
* **検証方法:** `show ip pim group-map` および `show ip pim discovery` で Mapping Agent からの情報を受信しているか確認。

### 実践ラボ問題 3: BSR (Bootstrap Router) の構築
* **要件:** R4 を C-BSR (Priority 128) および C-RP として構成せよ。
* **設定例 (R4):**
```bash
ip multicast-routing
!
ip pim bsr-candidate Loopback0 30 128
ip pim rp-candidate Loopback0
```
* **検証方法:** `show ip pim bsr-router` で当選 BSR が R4 (`10.1.4.4`) になっていることを確認。

### 実践ラボ問題 4: Source Specific Multicast (SSM) の構成
* **要件:** グループ範囲 `232.0.0.0/8` に対して SSM を有効化し、RP を介さない (S,G) 直結ツリーを形成させよ。
* **設定例 (全ルータ):**
```bash
ip multicast-routing
ip pim ssm default
```
* **検証方法:** レシーバーで `ip igmp join-group 232.1.1.1 source 10.1.100.1` を実行し、`show ip mroute` で (*,G) を経由せず即座に (S,G) が作成されることを確認。

### 実践ラボ問題 5: Multicast Boundary によるコントロール/データ分離
* **要件:** R5 の G0/2 インターフェイスにおいて、グループ `239.255.0.0/16` のデータトラフィックおよび Auto-RP 制御メッセージの通過を遮断せよ。
* **設定例 (R5):**
```bash
interface GigabitEthernet0/0/2
 ip multicast boundary BLOCK_MULTICAST
!
ip access-list extended BLOCK_MULTICAST
 deny ip any 239.255.0.0 0.0.255.255
 deny ip any host 224.0.1.39
 deny ip any host 224.0.1.40
 permit ip any any
```
* **検証方法:** `show ip pim neighbor` および対向での mroute 転送カウンタを確認。

### 実践ラボ問題 6: Static RP Override による強制上書き
* **要件:** Auto-RP が動作する環境において、グループ `239.99.99.0/24` に対する RP のみを R1 (`10.1.1.1`) へ強制的（Override）に静的バインドせよ。
* **設定例 (全ルータ):**
```bash
ip pim rp-address 10.1.1.1 OVERRIDE_ACL override
!
ip access-list standard OVERRIDE_ACL
 permit 239.99.99.0 0.0.0.255
```
* **検証方法:** `show ip pim rp mapping` を実行し、`239.99.99.x` に対して Static (Override) が Auto-RP より優先して選ばれていることを確認。

### 実践ラボ問題 7: IPv4 Anycast RP using MSDP
* **要件:** R1 (10.1.1.1) と R2 (10.1.2.2) 間で Anycast IP `10.1.255.100` を用いた RP 冗長化を構築せよ。
* **設定例 (R1):**
```bash
ip multicast-routing
interface Loopback100
 ip address 10.1.255.100 255.255.255.255
 ip pim sparse-mode
!
ip pim rp-address 10.1.255.100
!
ip msdp peer 10.1.2.2 connect-source Loopback0
ip msdp originator-id Loopback0
```
* **設定例 (R2):**
```bash
ip multicast-routing
interface Loopback100
 ip address 10.1.255.100 255.255.255.255
 ip pim sparse-mode
!
ip pim rp-address 10.1.255.100
!
ip msdp peer 10.1.1.1 connect-source Loopback0
ip msdp originator-id Loopback0
```
* **検証方法:** `show ip msdp peer` でセッション State が `State: Up` であることを確認。

### 実践ラボ問題 8: PIMv6 Anycast RP (RFC 4610)
* **要件:** R1 (`2001:DB8:1::1`) と R2 (`2001:DB8:1::2`) で IPv6 Anycast RP (`2001:DB8:RP::100`) を設定せよ。
* **設定例 (R1):**
```bash
ipv6 unicast-routing
ipv6 multicast-routing
!
interface Loopback100
 ipv6 address 2001:DB8:RP::100/128
 ipv6 pim
!
ipv6 pim rp-address 2001:DB8:RP::100
ipv6 pim anycast-rp 2001:DB8:RP::100 2001:DB8:1::1
ipv6 pim anycast-rp 2001:DB8:RP::100 2001:DB8:1::2
```
* **検証方法:** `show ipv6 pim neighbor` および `show ipv6 pim rp mapping` で Anycast RP セットを確認。

### 実践ラボ問題 9: Multicast Multipath (ECMP 負荷分散)
* **要件:** R1 と R2 の間に2本の等コストパスが存在する。マルチキャストトラフィックを両パスへ分散（Load Splitting）させよ。
* **設定例 (R1):**
```bash
ip multicast-routing
ip pim multipath
```
* **検証方法:** 複数のソースからマルチキャストトラフィックを送出し、`show ip mroute` の RPF インターフェイスが分散しているか確認。

### 実践ラボ問題 10: RP Announcement Filter (不正 RP 広告のフィルタリング)
* **要件:** Mapping Agent ルータ R3 において、R9 (`10.1.9.9`) からの RP 広告のみを受理し、その他のルータからの PIM Register / RP 広告を拒否せよ。
* **設定例 (R3 - Mapping Agent):**
```bash
ip pim send-rp-discovery Loopback0 scope 16
ip pim accept-rp 10.1.9.9 ALLOW_RP_GROUPS
!
ip access-list standard ALLOW_RP_GROUPS
 permit 239.10.0.0 0.0.255.255
```
* **検証方法:** 不正な C-RP を立てて `show ip pim discovery` に掲載されないことを確認。

---

## ❓ 想定試験問題

### 質問 1 (コンフィグ解読)
PIM Sparse Mode 網において、全ルータで Static RP (`10.1.1.1`) が設定されているにもかかわらず、Auto-RP で広報された RP (`10.1.2.2`) が優先して採用されてしまいました。Static RP を優先させるために不足していたコンフィグパラメータは何ですか？

* **正解:** `override` キーワード。
* **解説:** デフォルトの Group-to-RP マッピング優先順位では、Auto-RP (優先度 2) が Static RP (優先度 4) より優先されます。Static RP を最優先にするには `ip pim rp-address 10.1.1.1 <ACL> override` と設定する必要があります [137, Auto-RP Overview]。

### 質問 2 (トラブルシューティング)
IPv4 環境で MSDP Anycast RP を構成しましたが、`show ip msdp peer` を実行したところステートが `Disabled` のまま変わりません。原因として最も可能性が高いものはどれですか？

* **正解:** `connect-source` で指定したインターフェイスの IP アドレスが対向ルータの `ip msdp peer` 設定内のピア IP と一致していない、あるいはユニキャスト非疎通。
* **解説:** MSDP は TCP ポート 639 上でピアリングを確立します。対向で定義されている IP アドレスと、自機が送出する TCP SYN の送信元 IP (`connect-source`) が完全に一致していない場合、TCP セッションが確立されません [23, 1.6.c (vii)]。

### 質問 3 (Design)
IPv6 エンタープライズ網において RP の冗長化を設計しています。IPv4 のように MSDP コマンドを探しましたが存在しません。どのような標準技術を用いて RP の二重化を行うべきですか？

* **正解:** PIMv6 Anycast RP (RFC 4610)。
* **解説:** IPv6 には MSDP プロトコルが存在しません。そのため RFC 4610 に基づき、`ipv6 pim anycast-rp <Anycast-RP-IP> <Member-RP-IP>` コマンドを用いて PIM 制御パケットレベルで直接 RP 間同期を行います [23, 1.6.c (vi)]。

### 質問 4 (実装)
PIM-SM 網において、レシーバーが参加要求を出した直後、LHR (Last-Hop Router) が共有ツリー (*,G) から最短パスツリー (S,G) へ自動的に切替（SPT Switchover）を行わないように強制共有ツリー固定化を行うコマンドは何ですか？

* **正解:** `ip pim spt-threshold infinity`
* **解説:** Cisco IOS-XE のデフォルト動作では、最初のパケットを受信すると即座に SPT スイッチオーバーが発生します。`ip pim spt-threshold infinity` を設定すると、すべてのマルチキャストトラフィックが常に RP 経由の共有ツリー (*,G) を通過するようになります [23, 1.6.c]。

### 質問 5 (トラブルシューティング)
PIM-SM 網において Auto-RP を導入しましたが、Mapping Agent から遠く離れたルータで RP 情報が一切受信できません。全ルータの物理/論理インターフェイスは `ip pim sparse-mode` で動作しています。原因と解決策を述べてください。

* **正解:** PIM Sparse Mode では、Auto-RP の制御マルチキャストパケット（`224.0.1.39` / `224.0.1.40`）が RP 未学習のため転送・プルーニングされてしまいます。解決策として全ルータに `ip pim auto-rp listener` を設定（または `sparse-dense-mode` を使用）します [137, Auto-RP Overview]。

---

## 🔗 参考リソース

* [Cisco IOS XE 17.x IP Multicast Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-17/imc-pim-xe-17-book.html)
* [Cisco Command Reference - ip pim commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/command/imc-pim-cr-book.html)
* [Auto-RP Technology Overview & Troubleshooting](https://www.cisco.com/c/en/us/support/docs/ip/ip-multicast/2523-auto-rp.html)
* [PIM Bootstrap Router (BSR) Architecture (RFC 5059)](https://datatracker.ietf.org/doc/html/rfc5059)
* [PIMv6 Anycast RP Configuration Guide (RFC 4610)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-17/imc-pim-xe-17-book/sec-pimv6-anycast-rp.html)

---

## 📝 **補足（Notes）**

- **Auto-RP Listener の配置忘弊:** ラボ試験で PIM-SM ＋ Auto-RP が出題された場合、真っ先に `ip pim auto-rp listener` を全ルータへ投入する癖をつけてください [137, Auto-RP Overview]。
- **Multicast Multipath 動作:** 単にユニキャストで ECMP があっても PIM はデフォルトで 1 パスしか選定しません。明示的に `ip pim multipath` が必要です [23, 1.6.c (viii)]。


## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKIPM-2264: IP Multicast Logic and Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPM-2264)
    *   PIM のステートマシンや RPF エラーの深いトラブルシューティング解説。
*   [**BRKCCIE-3000: BGP and Multicast for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   CCIE ラボ試験におけるマルチキャストの「定番」タスクの解説。

### Configuration ガイド
*   [IP Multicast: PIM Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-17/imc-pim-xe-17-book.html)
*   [Implementing IPv6 Multicast (PIMv6)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_ipv6/configuration/xe-16/imc-ipv6-multicast-xe-16-book.html)。

### テクニカルノーツ・設定例
*   [PIM Sparse Mode SPT Switchover Mechanism](https://www.cisco.com/c/en/us/support/docs/ip/multicast/13717-49.html)。
*   [Anycast RP Using MSDP Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/116019-config-ospf-00.html)。

---

## 📝 補足

- この学習メモは、PIM の制御プレーン（RP 選出）からデータ転送（SPT Switchover, SSM）までの論理的な繋がりを重視しています。CCIE 実技試験においては、特に **RP 情報の不一致** や **RPF の失敗** が原因でトラフィックが止まるシナリオが多いため、`show ip pim rp mapping` と `show ip rpf` を駆使した迅速な診断が合格の決め手となります。
