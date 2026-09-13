---
layout: default
title: 1.5.a-Peer-relations
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.5.a IBGP and EBGP peer relations

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア EGP/IGP アソシエーション技術である **IBGP and EBGP peer relations（IBGP/EBGP ネイバー関係およびピアリング詳細）** について、Cisco IOS-XE 17.x の実装基準に完全準拠し、学術的・実践的背景から詳細に解説します [7, 1.2; 22, 1.5.a; 130, Cisco BGP Overview]。

---

## 📘 概要

**BGP (Border Gateway Protocol)** は、インターネットおよび大規模エンタープライズ網において自律システム（AS: Autonomous System）間および AS 内部でルーティング情報を交換するための Path-Vector 型ルーティングプロトコルです [130, Cisco BGP Overview]。

BGP ネイバー関係（Peer Relation）は、異なる AS 間に構築される **EBGP (External BGP)** と、同一 AS 内に構築される **IBGP (Internal BGP)** の 2 つに大別されます [7, 1.2; 130, Cisco BGP Overview]。BGP は下位トランスポートプロトコルとして **TCP 179 番ポート** を利用し、明示的に定義されたピア間でのみ 1 対 1 の信頼性あるセッションを確立します [130, Cisco BGP Overview]。

### 本セクション（1.5.a）がカバーする核心技術
1. **Peer Groups & Templates (1.5.a (i)):** BGP コンフィグの簡素化・共通化および Update グループの最適化メカニズム（Peer Group, Peer Session Template, Peer Policy Template） [6, Task 4; 22, 1.5.a (i)]。
2. **Active / Passive Mode (1.5.a (ii)):** TCP セッション確立主導権の制御（`neighbor transport connection-mode passive`） [22, 1.5.a (ii)]。
3. **BGP Timers (1.5.a (iii)):** Keepalive / Holdtime タイマー、Fast Peering Session Deactivation (Fast Fall-over)、Min Holdtime による安定化 [22, 1.5.a (iii)]。
4. **Dynamic Neighbors (1.5.a (iv)):** IP サブネット単位での動的 BGP ピア受付（`bgp listen range`）によるデータセンター・ハブ＆スポーク網の拡張性向上 [22, 1.5.a (iv)]。
5. **4-byte AS Numbers (1.5.a (v)):** 32 ビット AS 番号表記体系（Asplain vs Asdot）と 2-byte / 4-byte BGP ルータ間の互換性（NEW_AS / AS4_PATH / AS4_AGGREGATOR） [22, 1.5.a (v)]。
6. **Private AS Numbers (1.5.a (vi)):** プライベート AS 番号範囲（64512〜65534, 4200000000〜4294967294）と、ISP 境界での除去処理（`remove-private-as`） [22, 1.5.a (vi)]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | TCP 179 を使用した点対点接続。EBGP（TTL=1 デフォルト）と IBGP（TTL=255、AS 内メッシュ/RR を要求）の厳格な分離 [130, Cisco BGP Overview]。 |
| **用途** | ISP 接続、マルチホーム拠点接続、データセンター Leaf-Spine アンダーレイ/オーバーレイ網、MPLS VPN PE-CE ルーティング [22, 1.5.a]。 |
| **メリット** | ポリシーベースのトラフィック制御（Attribute 制御）、大規模プレフィックス（ミリオンルート）の安定保持、柔軟なネイバーグループ管理 [137, Video Title: BGP Filtering and Manipulations]。 |
| **デメリット** | セッション確立に TCP ネゴシエーションが必須でコンバー全速度が低速（通常時）。iBGP スプリットホライズンによるフルメッシュ要件 [57, 1.11.d]。 |
| **成立要件** | ① L3 TCP 179 疎通性 <br> ② ピア IP アドレスと AS 番号の相互一致 <br> ③ BGP Router ID の存在 <br> ④ eBGP Multihop (Loopback ピア時) または TTL 適合 |
| **Peer Template** | **Session Template**（TCP/タイマー/認証/ソース指定）と **Policy Template**（Route-Map/Prefix-List/Community）の分離継承モデル [6, Task 4; 22, 1.5.a (i)]。 |
| **4-byte AS 表記** | **Asplain**（例: `65536`）を Cisco IOS-XE 標準として採用。**Asdot**（例: `1.0`）との相互変換が可能 [22, 1.5.a (v)]。 |
| **設計上の注意点** | EBGP で Loopback 送信元を使用する場合は `ebgp-multihop` または `ttl-security` が必須。iBGP で Loopback 使用時は `update-source` が必須 [130, Cisco BGP Overview]。 |

---

## 🏗 動作原理

BGP ネイバーアジャセンシーは、標準的な 3-Way TCP ハンドシェイク完了後に BGP プロトコルパケットを交換することで成立します [130, Cisco BGP Overview]。

```text
[ Router A (10.1.12.1) ]                              [ Router B (10.1.12.2) ]
       │                                                       │
       │─── 1. TCP SYN (Dst Port: 179, Src Port: Dynamic) ────►│  (TCP Connection Initiated)
       │◄── 2. TCP SYN-ACK ────────────────────────────────────│
       │─── 3. TCP ACK ────────────────────────────────────────►│  (TCP Established)
       │                                                       │
       │─── 4. BGP OPEN Packet (Version 4, AS, Holdtime, RID)─►│  (OpenSent State)
       │◄── 5. BGP OPEN Packet ────────────────────────────────│  (OpenConfirm State)
       │                                                       │
       │─── 6. BGP KEEPALIVE Packet ──────────────────────────►│
       │◄── 7. BGP KEEPALIVE Packet ───────────────────────────│
       │                                                       │
       │=======================================================│
       │            [ BGP Peer State: ESTABLISHED ]            │
       │=======================================================│
       │                                                       │
       │─── 8. BGP UPDATE Packet (Path Attributes, Prefixes) ─►│
       │◄── 9. BGP UPDATE Packet ──────────────────────────────│
```

### BGP FSM (Finite State Machine) 6 段階ステート
1. **Idle:** BGP プロセスが停止、またはリセットされた状態。TCP 接続を開始できない。
2. **Connect:** TCP 3-Way ハンドシェイクの完了を待っている状態。成功すると **OpenSent** へ遷移。タイムアウトすると **Active** へ遷移。
3. **Active:** TCP 接続試行が失敗し、再度 TCP 接続を確立しようと試みている状態。相手からの接続要求を待受。
4. **OpenSent:** TCP 接続が完了し、自機の **BGP OPEN** パケットを送信して相手からの OPEN パケット待ち状態。
5. **OpenConfirm:** 相互に OPEN パケットを検証し合意。相手からの **KEEPALIVE** パケット受信待ち状態。
6. **Established:** 相互に KEEPALIVE を受信完了。ネイバーが完全に成立し、ルーティング情報（UPDATE パケット）の交換が可能 [128, Show ip bgp summary]。

---

## ⚙ 動作シーケンス

1. **TCP セッション確立 (TCP 179):**
   * 設定されたピア IP アドレス宛てに TCP SYN パケットを送出し、Port 179 でセッションをオープンします [130, Cisco BGP Overview]。
   * `neighbor <IP> transport connection-mode passive` が指定されている場合、自機からは SYN を送信せず、対向からの Port 179 接続待ち（Inbound TCP SYN）に専念します [22, 1.5.a (ii)]。
2. **BGP OPEN パケットパラメータ検証:**
   * **BGP Version (4):** バージョン一致を確認。
   * **My AS Number:** `remote-as` で指定された AS 番号と一致するか検証。
   * **Hold Time:** 相互の Hold Time を比較し、**小さい方の値** をセッション全体の Hold Time として選択（0 の場合はタイマー無効化） [22, 1.5.a (iii)]。
   * **BGP Identifier (Router ID):** ピア間で一意であることを確認（同一 RID は拒否）。
   * **Optional Capabilities:** 4-byte AS サポート (Cap ID 65)、Route Refresh (Cap ID 2)、Address Family (MP-BGP: Cap ID 1) のネゴシエーション [22, 1.5.a (v)]。
3. **KEEPALIVE パケットによる相互承認:**
   * OPEN パケットに問題がなければ、19 バイトの軽量 KEEPALIVE パケットを返し、Established ステートに移動します。
4. **UPDATE パケット伝搬とスプリットホライズン適用:**
   * **EBGP ピアへ:** 自 AS 番号を `AS_PATH` の最左列に追加（Prepending）し、`Next-Hop` を自インターフェイス IP（または Update-Source）に書き換えて送信 [57, 1.11.c; 130, Cisco BGP Overview]。
   * **IBGP ピアへ:** `AS_PATH` を変更せず、`Next-Hop` もデフォルトでは維持したまま送信。IBGP スプリットホライズンルール（IBGP ピアから学んだルートを別の IBGP ピアへ再送信しない）を適用 [57, 1.11.d; 132, Configuring BGP Route Map with Next-Hop Self]。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、BGP ピアリング（1.5.a）は単なる疎通確認にとどまらず、複雑な条件指定やスケール構成の一部として頻出します [22, 1.5.a]。

### 1. Peer Group vs Peer Session / Policy Templates
* **Peer Group (従来型):**
  * TCP セッションパラメータ（ソース、タイマー、AS）とルーティングポリシー（Route-Map, Prefix-List）を 1 つのグループ名でまとめて管理。
  * 制限: 同一 Group 内のピアは **完全に同一のアウトバウンドポリシー** を共有しなければならない。
* **Peer Templates (モダン構成):**
  * **Peer Session Template:** TCP 接続（`update-source`, `ebgp-multihop`, `timers`, `remote-as`, `password`）を定義。継承（`inherits`）可能 [6, Task 4; 22, 1.5.a (i)]。
  * **Peer Policy Template:** ルーティングポリシー（`route-map`, `prefix-list`, `send-community`, `next-hop-self`）を定義。複数テンプレートの階層的バインドが可能 [6, Task 4; 22, 1.5.a (i)]。

### 2. eBGP Loopback ピアリングと Multihop / TTL Security の罠
* **eBGP のデフォルト TTL は `1`:**
  * 物理直結ポートの IP ではなく Loopback アドレス同士で eBGP ピアを組む場合、1 ホスト離れるため TTL=1 ではパケットがドロップされます [130, Cisco BGP Overview]。
  * **解法 1:** `neighbor <IP> ebgp-multihop <hops>` を投入（指定した hops に TTL を変更） [130, Cisco BGP Overview]。
  * **解法 2:** `neighbor <IP> ttl-security hops <count>` を投入（GTSM: 送信時 TTL=255、受信時 TTL >= 255-count を検証） [7, 5.1.b; 22, 1.5.a]。
  * **注意:** `ebgp-multihop` と `ttl-security` は同一ピアに対して **相互排他（同時設定不可）** です。

### 3. Active / Passive モードの指定要件
試験問題で「本ルータは対向ルータからの TCP 179 セッション接続要求のみを受信し、自機からは対向へ向けて TCP 接続を開始しないように構成せよ」と指示された場合：
```bash
router bgp 65001
 neighbor 10.1.12.2 transport connection-mode passive
```
※片側を Passive に設定した場合、対向側（Active 側）が正常に Port 179 宛てに TCP SYN を送出できる状態（ACL や CoPP で拒否されていないこと）が前提となります [22, 1.5.a (ii)]。

### 4. Dynamic Neighbors (BGP Listen Range) の設定作法
データセンター網や DMVPN/SD-WAN アンダーレイで、多数のスポーク/Leaf ルータからの BGP 接続を個別 `neighbor` 定義なしで一括受付する場合に使用します [22, 1.5.a (iv)]。
* **必須要素:**
  1. `bgp listen range <PREFIX> peer-group <GROUP_NAME>`
  2. 受け入れる `peer-group` を事前作成し、`remote-as` または `alternate-as` を定義しておくこと [22, 1.5.a (iv)]。

### 5. 4-byte AS Numbers (Asplain vs Asdot)
* **Asplain (標準 10 進数表記):** 例: `65536`（65536〜4294967295） [22, 1.5.a (v)]。
* **Asdot (ドット表記):** `1.0`（`1 * 65536 + 0 = 65536`） [22, 1.5.a (v)]。
* Cisco IOS-XE では標準で Asplain が使用されます。全ルータで表示を統一する場合は `bgp asnotation dot` を使用します [22, 1.5.a (v)]。

---

## 🛠 設定方法

### 1. Peer Session & Policy Templates を使用した高度な iBGP / eBGP 構成

```bash
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 !
 # --- Peer Session Template の定義 ---
 template peer-session IBGP_COMMON_SESSION
  remote-as 65001
  update-source Loopback0
  timers 10 30
  transport connection-mode active
 exit-peer-session
 !
 template peer-session EBGP_EDGE_SESSION
  remote-as 65002
  ebgp-multihop 255
  password CISCO_BGP_PASS
 exit-peer-session
 !
 # --- Peer Policy Template の定義 ---
 template peer-policy IBGP_COMMON_POLICY
  next-hop-self
  send-community both
 exit-peer-policy
 !
 # --- Address-Family へのバインド ---
 address-family ipv4 unicast
  neighbor 2.2.2.2 inherit peer-session IBGP_COMMON_SESSION
  neighbor 2.2.2.2 inherit peer-policy IBGP_COMMON_POLICY
  !
  neighbor 10.1.12.2 inherit peer-session EBGP_EDGE_SESSION
 exit-address-family
```

### 2. Dynamic Neighbors (BGP Listen Range) 設定例

```bash
router bgp 65100
 bgp router-id 10.100.0.1
 bgp listen range 172.16.0.0/16 peer-group DYNAMIC_SPOKES
 !
 neighbor DYNAMIC_SPOKES peer-group
 neighbor DYNAMIC_SPOKES remote-as 65200
 !
 address-family ipv4 unicast
  neighbor DYNAMIC_SPOKES activate
  neighbor DYNAMIC_SPOKES route-map INBOUND_FILTER in
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP ピア一覧、ステート（Established/Active/Idle）、プレフィックス受信数の全般確認** | <code>show ip bgp summary</code> / <code>show bgp ipv4 unicast summary</code> |
| **特定ピアとの詳細状態（TCP 送信元/宛先ポート、Holdtime、Capability、テンプレート情報）の確認** | <code>show ip bgp neighbors 10.1.12.2</code> |
| **Dynamic Neighbors（Listen Range）で動的確立されたアクティブピアの一覧確認** | <code>show ip bgp neighbors \| include Dynamic</code> |
| **Peer Session / Policy Template の定義および継承ツリーの確認** | <code>show bgp peer-template</code> / <code>show bgp peer-group</code> |
| **BGP TCP セッション確立処理・OPEN ネゴシエーションのリアルタイムデバッグ** | <code>debug bgp ipv4 unicast updates</code> / <code>debug ip bgp events</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **BGP ネイバーが `Active` または `Connect` ステートでハングし成立しない。** | 1. TCP 179 宛ての L3 疎通性不可（Routing/ACL/CoPP ドロップ）。<br>2. AS 番号（`remote-as`）の不一致。<br>3. eBGP Loopback ピアリング時の `ebgp-multihop` 欠落。 | `show ip bgp summary`<br>`show ip route <PEER_IP>`<br>`ping <PEER_IP> source <SRC>` | 1. ピア IP への Ping 疎通と ACL で TCP 179 許可を確認。<br>2. `remote-as` 設定を修正。<br>3. `ebgp-multihop` または `ttl-security` をバインド。 |
| **`Active` ステートでネイバー生成と消滅を繰り返す（TCP 接続拒否）。** | 双方で `update-source` が一致していない（相手が受信した TCP SYN の送信元 IP と、相手側 `neighbor` 定義 IP が不一致）。 | `show ip bgp neighbors <IP>`<br>`debug ip bgp events` | 両ルータで `neighbor <IP> update-source Loopback0` 等を投入し、送信元 IP を完全に統一する。 |
| **Dynamic Neighbors で対向スポークからの接続が拒否される。** | 1. スポークの IP が `bgp listen range` で指定したサブネット外。<br>2. バインドされた `peer-group` に `remote-as` や `alternate-as` が未定義。 | `show ip bgp summary`<br>`show running-config \| sec router bgp` | `bgp listen range` プレフィックス長を拡大するか、`peer-group` 配下に正しく `remote-as` を追加する。 |
| **プライベート AS 番号がインターネット側へ漏洩する。** | eBGP ピアに対して `remove-private-as` が設定されていない。 | `show ip bgp 10.0.0.0/8` | 対向 eBGP ピア指定配下で `neighbor <IP> remove-private-as`（または `all` オプション）を付与する。 |

---

## ⚠ 制限事項

1. **`ebgp-multihop` と `ttl-security` の排他制限:**
   * 同一の BGP ピアに対して `neighbor ebgp-multihop` と `neighbor ttl-security` を同時に設定することは Cisco IOS-XE の仕様上禁止されています（コマンド投入時にエラーとなります）。
2. **Dynamic Neighbors (Listen Range) の接続上限:**
   * `bgp listen limit <count>` コマンドを設定しない場合、デフォルトで無制限またはプラットフォーム上限まで動的ピアを受け入れます。Control Plane 保護のため必ず `bgp listen limit` を定義することが推奨されます。

---

## 🔄 他技術との関連

* **BFD (Bidirectional Forwarding Detection):**
  BGP のデフォルト Holdtime（180秒）に依存せず、ミリ秒単位（例: 50ms x 3）でリンク障害を検知して即座に BGP ピアを Down 状態へ推移させます（`neighbor <IP> fall-over bfd`） [22, 1.2.j]。
* **Control Plane Policing (CoPP):**
  BGP ピア以外の不正な IP から送信されてくる TCP Port 179 パケットを CoPP でドロップし、ルータ CPU への DoS 攻撃を防ぎます [24, 4.1.a; 61, 5.2.b]。
* **MPLS L3VPN / EVPN:**
  PE ルータ間での MP-iBGP (Multiprotocol BGP) ピアリングにおいて、`address-family vpnv4` や `address-family l2vpn evpn` を有効化して Overlay ラベル情報を伝搬します [29, 3.2.b (ii); 57, 2.2]。

---

## 🧩 比較表

### 1. IBGP vs EBGP ピア動作比較

| 比較項目 | IBGP (Internal BGP) | EBGP (External BGP) |
| :--- | :--- | :--- |
| **AS 番号** | 同一 AS 内のルータ間ピアリング | 異なる AS 間のルータ間ピアリング |
| **デフォルト IP TTL** | **255** (マルチホップ可能) | **1** (物理直結が前提) |
| **Loopback ピアリング条件** | `update-source` の指定のみで成立 | `update-source` ＋ `ebgp-multihop` または `ttl-security` が必須 |
| **Next-Hop 伝搬動作** | 他ピアへルートを転送する際、**Next-Hop を変更しない**（手動で `next-hop-self` が必要） | **Next-Hop を自ルータの IP に自動書き換え** て送信 |
| **AS_PATH 伝搬動作** | 自分の AS 番号を `AS_PATH` に**追加しない** | 自分の AS 番号を `AS_PATH` の先頭（左端）に**追加** |
| **ループ防止ルール** | **iBGP スプリットホライズン** (iBGP から学んだルートを別の iBGP へ転送不可) | **AS_PATH ループチェック** (自 AS 番号が含まれる UPDATE パケットを破棄) |

### 2. Peer Group vs Peer Session / Policy Templates 比較

| 比較項目 | Peer Group | Peer Session / Policy Templates |
| :--- | :--- | :--- |
| **柔軟性・再利用性** | 低い (すべての設定が 1 つのグループに拘束) | **非常に高い** (Session と Policy を独立定義・継承可能) [6, Task 4] |
| **設定の階層** | グローバル `neighbor <NAME> peer-group` 配下 | `template peer-session` / `template peer-policy` で個別定義 [6, Task 4] |
| **ポリシーの個別化** | アウトバウンドポリシーの個別化不可 | Policy Template 内で `inherits` や個別 override が柔軟に可能 [6, Task 4] |

---

## 💡 ベストプラクティス

1. **Peer Session / Policy Templates の積極活用:**
   Cisco IOS-XE での BGP 構成時、Peer Group の使用を避け、Session（接続属性）と Policy（ルーティングポリシー）を完全分離した Templates 構成を採用する [6, Task 4; 22, 1.5.a (i)]。
2. **Defensive EBGP Peering (GTSM):**
   直結 EBGP ピアに対しても `ttl-security hops 1` を指定し、遠隔スプーフィング攻撃を物理層/ASIC 段階で遮断する [7, 5.1.b; 22, 1.5.a]。
3. **iBGP での `next-hop-self` 標準バインド:**
   AS 境界 ASBR 上で iBGP ピアに向けて常に `next-hop-self` を設定し、IGP への eBGP ネクストホップ再配送を不要にする [132, Configuring BGP Route Map with Next-Hop Self]。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Peer Group による IBGP フルメッシュ構成
* **要件:** R1 (1.1.1.1) と R2 (2.2.2.2) 間で、Peer Group 名 `IBGP_CORE` を使用して AS 65001 内の IBGP ピアを確立せよ。

**【R1】**
```bash
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 !
 neighbor IBGP_CORE peer-group
 neighbor IBGP_CORE remote-as 65001
 neighbor IBGP_CORE update-source Loopback0
 neighbor IBGP_CORE timers 10 30
 !
 neighbor 2.2.2.2 peer-group IBGP_CORE
 !
 address-family ipv4 unicast
  neighbor IBGP_CORE activate
  neighbor IBGP_CORE next-hop-self
  neighbor IBGP_CORE send-community both
 exit-address-family
```

**【R2】**
```bash
router bgp 65001
 bgp router-id 2.2.2.2
 bgp log-neighbor-changes
 !
 neighbor IBGP_CORE peer-group
 neighbor IBGP_CORE remote-as 65001
 neighbor IBGP_CORE update-source Loopback0
 neighbor IBGP_CORE timers 10 30
 !
 neighbor 1.1.1.1 peer-group IBGP_CORE
 !
 address-family ipv4 unicast
  neighbor IBGP_CORE activate
  neighbor IBGP_CORE next-hop-self
  neighbor IBGP_CORE send-community both
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp summary
# 2.2.2.2 とのピアが Established になっていることを確認
```

---

### Scenario 2: Peer Session & Policy Templates によるモダン BGP 構成
* **要件:** Peer Session Template `SESS_IBGP` と Peer Policy Template `POL_IBGP` を定義し、R1-R3 間で iBGP を確立せよ [6, Task 4; 22, 1.5.a (i)]。

**【R1】**
```bash
router bgp 65001
 bgp router-id 1.1.1.1
 !
 template peer-session SESS_IBGP
  remote-as 65001
  update-source Loopback0
  timers 10 30
 exit-peer-session
 !
 template peer-policy POL_IBGP
  next-hop-self
  send-community both
 exit-peer-policy
 !
 address-family ipv4 unicast
  neighbor 3.3.3.3 inherit peer-session SESS_IBGP
  neighbor 3.3.3.3 inherit peer-policy POL_IBGP
 exit-address-family
```

**【検証方法】**
```bash
R1# show bgp peer-template
# テンプレートが正常に適用・継承されていることを確認
```

---

### Scenario 3: eBGP Multihop & Loopback ピアリング構成
* **要件:** R1 (AS 65001, Lo0: 1.1.1.1) と R4 (AS 65004, Lo0: 4.4.4.4) 間で、Loopback アドレス同士による eBGP ピアを確立せよ [130, Cisco BGP Overview]。

**【R1】**
```bash
router bgp 65001
 bgp router-id 1.1.1.1
 neighbor 4.4.4.4 remote-as 65004
 neighbor 4.4.4.4 update-source Loopback0
 neighbor 4.4.4.4 ebgp-multihop 255
 !
 address-family ipv4 unicast
  neighbor 4.4.4.4 activate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 4.4.4.4 | include External BGP neighbor
# External BGP neighbor may be up to 255 hops away と出力されることを確認
```

---

### Scenario 4: Passive BGP Peer (片側 Passive 化) 構成
* **要件:** R1 側で R2 (10.1.12.2) からの TCP 179 接続のみを受信するよう `passive` モードを定義せよ [22, 1.5.a (ii)]。

**【R1】**
```bash
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 transport connection-mode passive
 !
 address-family ipv4 unicast
  neighbor 10.1.12.2 activate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.1.12.2 | include Connection mode
# Connection mode is passive を確認
```

---

### Scenario 5: BGP Fast Fall-over (Fast Peering Session Deactivation)
* **要件:** R1-R2 間で、ネクストホップへの L3 ルートが RIB から消去された瞬間に即座に BGP ピアを閉塞させるよう構成せよ [22, 1.5.a (iii)]。

**【R1】**
```bash
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 fall-over route-map BGP_NH_TRACK
 !
ip prefix-list PEER_LINK permit 10.1.12.0/24
!
route-map BGP_NH_TRACK permit 10
 match ip address prefix-list PEER_LINK
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.1.12.2 | include Fall-over
```

---

### Scenario 6: Dynamic Neighbors (BGP Listen Range) 構成
* **要件:** R1 において、`172.16.0.0/16` セグメントからの動的 eBGP 接続（AS 65200）を一括自動受付せよ [22, 1.5.a (iv)]。

**【R1】**
```bash
router bgp 65001
 bgp router-id 1.1.1.1
 bgp listen range 172.16.0.0/16 peer-group DYNAMIC_CLIENTS
 bgp listen limit 50
 !
 neighbor DYNAMIC_CLIENTS peer-group
 neighbor DYNAMIC_CLIENTS remote-as 65200
 !
 address-family ipv4 unicast
  neighbor DYNAMIC_CLIENTS activate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp summary
# 動的に追加されたクライアントが *172.16.1.2 のようにアスタリスク付きで表示されることを確認
```

---

### Scenario 7: 4-byte AS Numbers (Asplain vs Asdot 変換)
* **要件:** R1 の AS 番号を 4-byte AS `4200000000` に定義し、表示方式を Asdot に統一せよ [22, 1.5.a (v)]。

**【R1】**
```bash
router bgp 4200000000
 bgp router-id 1.1.1.1
 bgp asnotation dot
 neighbor 10.1.12.2 remote-as 65002
 !
 address-family ipv4 unicast
  neighbor 10.1.12.2 activate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp summary
# AS 番号が Asdot 形式（64086.61440）で正しく変換表示されることを確認
```

---

### Scenario 8: Private AS 削除 (`remove-private-as` / `all`)
* **要件:** ISP ルータ R1 から対向 eBGP ピア (10.1.12.2) へ UPDATE を送信する際、`AS_PATH` に含まれるすべてのプライベート AS 番号（64512〜65534）を全自動削除せよ [22, 1.5.a (vi)]。

**【R1】**
```bash
router bgp 65000
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 remove-private-as all replace-as
 !
 address-family ipv4 unicast
  neighbor 10.1.12.2 activate
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp
# R1 から受領したプレフィックスの AS_PATH からプライベート AS が消去されていることを確認
```

---

### Scenario 9: GTSM (BGP TTL Security Mechanism) 構成
* **要件:** R1 (10.1.12.1) と R2 (10.1.12.2) 間の eBGP ピアに対して、GTSM（TTL Security, Hop Count 1）を構成せよ [7, 5.1.b; 22, 1.5.a]。

**【R1 / R2 共通】**
```bash
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 ttl-security hops 1
 !
 address-family ipv4 unicast
  neighbor 10.1.12.2 activate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.1.12.2 | include External BGP neighbor
# External BGP neighbor may be up to 1 hop away (TTL Security enabled) を確認
```

---

### Scenario 10: VRF-Aware BGP Neighbor 構成 (Multi-Tenant)
* **要件:** VRF `TENANT_A` 内で対向 CE ルータ (192.168.10.2, AS 65100) との eBGP ピアを確立せよ [22, 1.2.e, 1.5.a]。

**【R1 (PE)】**
```bash
vrf definition TENANT_A
 rd 65001:100
 address-family ipv4
exit-vrf
!
router bgp 65001
 address-family ipv4 vrf TENANT_A
  neighbor 192.168.10.2 remote-as 65100
  neighbor 192.168.10.2 activate
  neighbor 192.168.10.2 as-override
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp vpnv4 vrf TENANT_A summary
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解・トラブルシューティング】eBGP Multihop と TTL Security の排他エラー
**問題:** 
以下のコンフィグを R1 に投入したところ、ルータからエラーが返され設定が拒否されました。原因を説明し、正しい修正案を提示してください。
```text
router bgp 65001
 neighbor 4.4.4.4 remote-as 65004
 neighbor 4.4.4.4 ebgp-multihop 5
 neighbor 4.4.4.4 ttl-security hops 2
```

**解答・解説:**
* **原因:** 
  Cisco IOS-XE の仕様により、同一の BGP ピアに対して `ebgp-multihop` と `ttl-security` を同時にバインドすることは相互排他的であり禁止されています。
  `ebgp-multihop` は送信 IP パケットの TTL を指定値（例: 5）に手動設定するのに対し、`ttl-security` (GTSM) は送信パケットの TTL を常に `255` に設定し、受信時に `255 - hops` 以上の TTL を検証する仕組みであるため、両者の動作原理が根本的に矛盾します [7, 5.1.b; 130, Cisco BGP Overview]。
* **修正案:** 
  目的（接続維持か DoS 保護か）に応じて、どちらか一方のみをバインドします。遠隔ホップ経由の eBGP ピアリングを GTSM 保護付きで行う場合は、`ebgp-multihop` を削除し `ttl-security hops 5` のみに統一します [7, 5.1.b]。

---

### 2. 【Design】iBGP フルメッシュにおける Template 共通化設計
**問題:** 
20 台のルータが存在する AS 65000 の iBGP メッシュ網において、コンフィグ行数を最小化しつつ、将来のタイマー変更や認証パスワード変更を 1 箇所の変更で全ピアへ即座に反映できる構造を設計してください。

**解答・解説:**
* **設計案:** 
  `template peer-session` を定義し、接続属性（`remote-as 65000`, `update-source Loopback0`, `timers 10 30`, `password`）を集約します [6, Task 4; 22, 1.5.a (i)]。
  さらに `template peer-policy` を定義し、ポリシー属性（`next-hop-self`, `send-community both`）を集約します [6, Task 4; 22, 1.5.a (i)]。
  各ネイバー定義では `neighbor <IP> inherit peer-session <NAME>` および `neighbor <IP> inherit peer-policy <NAME>` の 2 行のみをバインドするモデルを構築します。これにより、将来パラメータ変更が発生した際も、該当する 1 つのテンプレートを編集するだけで全 20 ピアへ一括反映されます [6, Task 4]。

---

## 🔗 参考リソース

* [Cisco Systems: BGP Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-3s/irg-xe-3s-book.html)
* [Cisco Command Reference: IP Routing: BGP Command Reference](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book.html)
* [Cisco Live: BRKRST-3321 - Advanced BGP Architecture and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **BGP ピア状態チェクリスト:**
  1. `show ip bgp summary` で State が `Established` であるか確認 [128, Show ip bgp summary]。
  2. `Active` または `Connect` の場合は、L3 IP 疎通（Ping）と TCP Port 179 遮断ACL/CoPPの有無をチェック。
  3. `update-source` と対向の `neighbor` IP アドレスが相互に合致しているか確認 [130, Cisco BGP Overview]。


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - CCIE 受験者向けの BGP 深掘り解説。
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - BGP セッション確立のトラブル解決。

### Configurationガイド
*   [Cisco BGP Overview - BGP Configuration Guide](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/cisco_bgp_overview.html)。
*   [Configuring Internal BGP Features](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-int-features.html)。

### テクニカルドキュメント・設定例
*   [BGP Case Studies - Peer Relationships](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)。
*   [BGP Attributes: Atomic Aggregate and AS_SET](http://www.networkers-online.com/blog/2010/12/bgp-attributes-atomic-aggergate-atribute/)。

---

## 📝 補足
- この学習メモは、BGP の「入口」であるピアリングという土台を、CCIE ラボ試験の要求レベルに合わせて詳細化したものです。特に iBGP のループ防止ルールと eBGP マルチホップの設計は、トポロジ全体の到達性に直結するため、完璧な理解が求められます。


