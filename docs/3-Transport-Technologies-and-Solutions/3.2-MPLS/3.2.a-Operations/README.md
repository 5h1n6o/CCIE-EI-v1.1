---
layout: default
title: 3.2.a-Operations
parent: 3.2-MPLS
grand_parent: 3-Transport-Technologies-and-Solutions
nav_order: 1
---

# 3.2.a Operations

---

## 📘 概要

* **機能概要**
  * **MPLS Operations（MPLS 動作基盤）** は、Multiprotocol Label Switching ネットワークにおいてパケット転送、ラベル交換・シグナリング、および可視化・診察を行う一連のコアメカニズム群である。
  * **Label Stack / LSR / LSP (3.2.a (i)):** 32 ビットの MPLS ヘッダー（20 ビット Label、3 ビット TC/Exp、1 ビット Bottom of Stack S-ビット、8 ビット TTL）構造を用い、ルータの役割（Ingress LSR / Transit LSR / Egress LSR）に応じた 3 つの基本操作（Push / Swap / Pop）を実行することで単一指向性のパスである **LSP (Label Switched Path)** を確立する。
  * **LDP (Label Distribution Protocol) (3.2.a (ii)):** IP プレフィックスと MPLS ラベルのマッピング情報を隣接ルータ間で自動動的に配布・同期するプロトコル。UDP 646（Discovery）と TCP 646（Session 確立）を使用してピアリングを完了する。
  * **MPLS Ping & MPLS Traceroute (3.2.a (iii)):** データプレーン（LFIB）とコントロールプレーン（FIB/LIB/LDP）の整合性を検証する MPLS OAM（Operations, Administration, and Maintenance）ツールであり、通常の IP Ping/Traceroute では検出できないラベル破棄障害や FEC 不一致をピンポイントで特定する。

* **利用目的**
  * レイヤ 3 の IP ルーティングテーブル（RIB）を毎パケット検索する負荷を回避し、レイヤ 2.5 の LFIB（Label Forwarding Information Base）に基づいた高速かつ決定論的な転送を実現する。
  * MPLS L3VPN、MPLS L2VPN（VPWS / VPLS）、および MPLS TE（Traffic Engineering）等のオーバーレイサービスを支える堅牢なトランスポート（LSP）を提供する。
  * LDP-IGP Synchronization や LDP Session Protection、MPLS OAM ツールを活用することで、リンク・ノード障害時のトラフィックドロップをミリ秒単位で抑制する。

* **どのような場面で利用するか**
  * サービスプロバイダ網や大規模エンタープライズのバックボーンネットワークにおいて、複数テナントのトラフィックを分離・転送する際。
  * コアネットワーク（P ルータ）で BGP の全経路（Full Route）を持たせず、PE ルータ間の Loopback 到達性のみでトラフィックを通過させる「BGP Free Core」を構築する場面。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **対象技術** | 3.2.a (i) Label stack, LSR, LSP<br>3.2.a (ii) LDP<br>3.2.a (iii) MPLS ping, MPLS traceroute |
| **MPLS Header 構造** | 32 ビット（Label: 20bit, TC/Exp: 3bit, Bottom of Stack S-bit: 1bit, TTL: 8bit） |
| **LSR の役割** | Ingress LSR (Headend / Label Push), Transit LSR (Label Swap), Egress LSR (Tailend / Label Pop / PHP) |
| **LDP プロトコル** | Discovery: UDP 646 (224.0.0.2), Session: TCP 646 (Unicast) |
| **LDP 識別子 (LDP ID)** | `LSR-ID : Label-Space-ID`（例: `192.168.1.1:0` ※ 0 は Per-Platform） |
| **LDP 動作モード (Cisco IOS-XE)** | DU (Downstream Unsolicited), Liberal Retention, Ordered Control |
| **障害保護機能** | LDP-IGP Synchronization (`mpls ldp sync`), LDP Session Protection |
| **MPLS OAM** | MPLS Ping (UDP 3503), MPLS Traceroute (Downstream Detailed Mapping: DDMAP TLV) |
| **注意点** | LDP-IGP Sync 未設定時のトラフィックブラックホール、PHP (Implicit Null vs Explicit Null) の QoS 伝搬影響 |

---

## 🏗 動作原理

### 1. MPLS ヘッダー（Label Stack）の内部構造

MPLS パケットは、レイヤ 2 ヘッダーとレイヤ 3（IP）ヘッダーの間に 32 ビットの MPLS ヘッダー（Shim Header）を挿入（Push）する。

```text
+-------------------------------------------------------------------+
|  Ethernet  |  MPLS Header (32-bit)  |  IP Header  |  Payload/TCP  |
+-------------------------------------------------------------------+

 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                Label (20 bits)                | TC  |S|  TTL  |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

* **Label (20 bits):** 転送識別子（0 〜 1,048,575）。
  * `0`: Explicit Null (IPv4) — QoS Exp ビットを Egress まで維持するため Egress ルータが要求。
  * `1`: Router Alert Label
  * `2`: Explicit Null (IPv6)
  * `3`: Implicit Null — PHP (Penultimate Hop Popping) 実行指示用。
  * `16 〜 1,048,575`: 動的/静的割当用ラベル。
* **TC (Traffic Class / 3 bits):** 旧 Exp ビット。QoS の DiffServ (CoS/DSCP) マッピングに使用。
* **S (Bottom of Stack / 1 bit):** 最底層ラベルフラグ。`1` の場合は直後が IP ヘッダー。`0` の場合は追加の MPLS ラベル（L3VPN サービスラベル等）が続く。
* **TTL (Time to Live / 8 bits):** IP ヘッダーの TTL 値をコピーしてループ防止を行う。

---

### 2. LSR の分類と Label 操作（Push / Swap / Pop）

```text
[CE-1] ── (IP) ──> [Ingress LSR (PE1)] ── (Push 101) ──> [Transit LSR (P)] ── (Swap 101->202) ──> [Egress LSR (PE2)] ── (IP) ──> [CE-2]
                     (FIB -> LFIB)                       (LFIB -> LFIB)                               (LFIB -> FIB)
```

1. **Ingress LSR (PE1):**
   * IP パケットを受信し、FIB/LIB を検索。
   * MPLS ヘッダーを **Push** し、LSP に載せて送出。
2. **Transit LSR (P):**
   * 着信ラベルをキーに LFIB（Label Forwarding Information Base）を検索。
   * 入力ラベルを出力ラベルに **Swap** して次ホップへ転送（IP ヘッダーは見ない）。
3. **Egress LSR (PE2):**
   * 最終目的地のルータ。MPLS ヘッダーを **Pop** して通常の IP パケットに戻し、FIB 検索により送出。
   * **PHP (Penultimate Hop Popping):** 効率化のため、Egress の 1 つ手前（Penultimate Hop）の P ルータがラベルを **Pop** して剥がした状態で Egress に渡す（Implicit Null: Label 3 の場合）。

---

### 3. LDP (Label Distribution Protocol) の動作原理

LDP は隣接関係を確立し、自身が持っている FEC（Forwarding Equivalence Class = IP プレフィックス）に対するローカル割り当てラベルを広報する。

```text
[Router A]                                                   [Router B]
    |                                                            |
    |---- UDP 646 Hello (224.0.0.2) ---------------------------->|  (Discovery Phase)
    |<--- UDP 646 Hello (224.0.0.2) -----------------------------|
    |                                                            |
    |==== TCP 646 Session Establishment (Active/Passive) =======>|  (Session Phase)
    |<--- LDP Initialization Message / Keepalive ----------------|
    |                                                            |
    |<=== LDP Label Mapping Message (FEC 10.1.1.0/24 -> L:16) ===|  (Advertisement Phase)
    |=== LDP Label Mapping Message (FEC 10.2.2.0/24 -> L:20) ===>|
```

* **LDP Identifier (LDP ID):** `48-bit` 構造 (`Router-ID : Label-Space-ID`)。例: `10.0.0.1:0`（`0` は Per-Platform 割当を示す）。
* **DU (Downstream Unsolicited) + Liberal Retention + Ordered Control:** Cisco IOS-XE のデフォルト動作モード。
  * **DU:** 要求がなくても全隣接にローカルラベルを自動広報する。
  * **Liberal Retention:** 最適パス以外の隣接から受信したラベルも LIB（Label Information Base）に保持し、高速迂回を可能にする。
  * **Ordered Control:** 上流（Egress / 目的地のルータ）がラベルを割り当てるまで、自身もその FEC のラベルを広告しない（ルータが独自に作成する直結/Loopbackを除く）。

---

## ⚙ 動作シーケンス

### パケット処理および LDP / MPLS 制御シーケンス

```text
+-----------------------------------------------------------------------------------+
| 1. IGP 収束 & 経路確立 (OSPF/EIGRP/IS-IS)                                         |
|    - 全ルータが Loopback アドレスへの IP 経路を FIB に登録                        |
+-----------------------------------------------------------------------------------+
                                        │
                                        ▼
+-----------------------------------------------------------------------------------+
| 2. LDP Discovery & Session 確立                                                  |
|    - UDP 646 Hello (224.0.0.2) で隣接発見                                         |
|    - 高い LDP Transport IP を持つルータが Active として TCP 646 接続を開始        |
|    - Keepalive 交渉後、LDP セッションが OPERATIONAL 状態へ移動                   |
+-----------------------------------------------------------------------------------+
                                        │
                                        ▼
+-----------------------------------------------------------------------------------+
| 3. Label Allocation & Advertisement (LIB / LFIB 構築)                             |
|    - 各ルータが自身の FIB エントリ（FEC）に対してローカルラベル（Local Label）を発行 |
|    - LDP Label Mapping メッセージで隣接へ広報                                     |
|    - 最適 IGP 次ホップの Remote Label を LFIB の Outgoing Label として採用         |
+-----------------------------------------------------------------------------------+
                                        │
                                        ▼
+-----------------------------------------------------------------------------------+
| 4. Data Plane パケット転送                                                        |
|    - Ingress PE: IP -> Push Label -> Transit P                                    |
|    - Penultimate Hop P: LFIB 検索 -> Pop Label (PHP) -> Egress PE                 |
|    - Egress PE: IP 検索 -> 目的端末へ到達                                         |
+-----------------------------------------------------------------------------------+
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint で重要なポイント
* **LDP-IGP Synchronization (`mpls ldp sync`):**
  * OSPF/IS-IS リンクが Up しても、LDP セッションが完了する前に IGP 経路が選定されると、ラベルのないパケットが転送されてブラックホール化する。
  * `mpls ldp sync` を有効にすると、LDP セッションが確立するまで IGP はそのリンクの Metric を最大値（OSPF: 65535）として広告し、トラフィックの流入を防ぐ。
* **LDP Session Protection:**
  * 直接リンクがフラッピングした際、Targeted LDP セッション（LDP Hello via Unicast）を維持することで、リンク復旧後の LDP 再交渉時間をゼロにする。
* **PHP (Penultimate Hop Popping) と Explicit Null:**
  * デフォルトでは Egress ルータは `Implicit Null` (Label 3) を広報し、PHP が動作する。
  * QoS の Exp/TC ビットを Egress ルータまで透過してキューイングに反映させたい場合、`mpls ldp explicit-null` コマンドで Label 0 (Explicit Null) を広報させる。

### 2. トラブルシューティング問題で問われるパターン
* **LDP Transport IP 到達性欠落:**
  * `show mpls ldp neighbor` が `NON-EXISTENT` や `INITIALIZED` から進まない。
  * 原因: LDP Transport Address（デフォルトは Loopback0）への IP 到達性がない、または Access-list / Firewall で TCP 646 がドロップされている。
* **LDP-IGP Sync Mismatch:**
  * `show mpls ldp sync` で `Sync status: Not synchronized` となり、OSPF メトリックが 65535 に張り付いている。
* **MPLS MTU ドロップ:**
  * MPLS ヘッダー（4B 〜 12B 以上）追加により、1500 バイトのパケットが MTU 超過でドロップする。物理インターフェイスで `mpls mtu 1520` などの拡張が必要。

---

## 🛠 設定方法

### 1. 基本的な LDP 及び MPLS の有効化設定

```text
! 全域の物理/Loopback インターフェイスで MPLS LDP を有効化
mpls ip
mpls ldp router-id Loopback0 force

interface GigabitEthernet0/0/1
 ip address 10.1.12.1 255.255.255.0
 mpls ip
!
router ospf 1
 router-id 1.1.1.1
 mpls ldp autoconfig
 mpls ldp sync
```

### 2. LDP 高度な保護機能・QoS 設定

```text
! LDP Session Protection の有効化（全ピア対象、ホールドタイム 86400 秒）
mpls ldp session-protection

! Explicit Null の有効化 (Egress で QoS Exp を維持)
mpls ldp explicit-null

! LDP ピア認証の設定
mpls ldp neighbor 2.2.2.2 password CISCO_CCIE
```

---

## 🔍 検証コマンド

### 確認コマンド一覧表

| 目的 | コマンド |
| :--- | :--- |
| **LDP ピア確認** | <code>show mpls ldp neighbor</code> |
| **LDP 概要確認** | <code>show mpls ldp status</code> |
| **LDP インターフェイス確認** | <code>show mpls ldp discovery</code> |
| **LIB (Label データベース) 確認** | <code>show mpls ldp bindings</code> |
| **LFIB (転送テーブル) 確認** | <code>show mpls forwarding-table</code> |
| **LDP-IGP 同期状態確認** | <code>show mpls ldp sync</code> |
| **MPLS OAM (LSP Ping)** | <code>ping mpls ipv4 <IP/Mask></code> |
| **MPLS OAM (LSP Traceroute)** | <code>traceroute mpls ipv4 <IP/Mask></code> |
| **Debug コマンド** | <code>debug mpls ldp messages</code><br><code>debug mpls ldp transport</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **LDP セッションが確立しない (`NON-EXISTENT`)** | LDP Transport IP（Loopback）への L3 到達性がない | <code>show mpls ldp discovery</code><br><code>ping <Transport-IP></code> | IGP 経路を確認し、Transport IP への到達性を確保する。 |
| **TCP 646 がブロックされる** | アクセスリストまたはセキュリティポリシーで TCP/UDP 646 が拒否されている | <code>show ip access-lists</code> | ACL に <code>permit tcp/udp host <IP> eq 646</code> を追加する。 |
| **OSPF メトリックが 65535 のまま下がらない** | `mpls ldp sync` が有効だが LDP セッションが未確立 | <code>show mpls ldp sync</code> | LDP セッションの障害原因を排除するか、`no mpls ldp sync` で解除。 |
| **パケットが断続的にドロップする (MTU 超過)** | MPLS ヘッダー追加による MTU 超過（DF ビット設定パケット） | <code>show interfaces <int> \| inc MTU</code> | 物理ポートで `mpls mtu 1520` または `mtu 1520` を設定する。 |
| **LDP Router-ID の不一致** | ルータ ID の Loopback が物理ダウンしている | <code>show mpls ldp status</code> | `mpls ldp router-id Loopback0 force` を明示的にバインドする。 |

---

## ⚠ 制限事項

1. **LDP セッションのトランスポート**
   * LDP セッション確立には、両端の LDP Router-ID（Transport Address）間での双方向 IP 疎通が必須である。
2. **ラベル空間の制限**
   * Per-Platform ラベル空間（`0`）が標準であり、同一ルータ内ではすべてのインターフェイスで同一の FEC に対し同じローカルラベルが割り当てられる。
3. **IPv6 LDP サポート**
   * IOS-XE では IPv6 向けの LDP（RFC 7552）がサポートされるが、実務および CCIE EI ラボでは SRv6 や Segment Routing (SR-MPLS) への移行が推奨されるケースが多い。

---

## 🔄 他技術との関連

* **OSPF / IS-IS:**
  * LDP は IGP 経路に基づいて LSP を構築する。`mpls ldp sync` により、IGP 収束と LDP 収束のズレによるブラックホールを回避する。
* **MPLS L3VPN (BGP):**
  * MP-BGP は Inner/Service Label を配布するが、PE ルータ間の Loopback 疎通を確立する Outer/Transport Label の配布は LDP が担う。
* **Quality of Service (QoS):**
  * IP Header の DSCP / CoS 値は MPLS Header の TC (Exp) ビットにコピーされ、PHP 動作時における `Explicit Null` 設定によって Egress ルータまで維持される。

---

## 🧩 比較表

### 1. Label Distribution Protocols (LDP vs RSVP-TE vs SR-MPLS)

| 項目 | LDP | RSVP-TE | SR-MPLS (Segment Routing) |
| :--- | :--- | :--- | :--- |
| **方式** | ベストエフォート型（IGP 追従） | 明示的パス指定・帯域予約型 | ソースルーティング型 |
| **シグナリング** | LDP (UDP/TCP 646) | RSVP-TE (IP Protocol 46) | なし（IGP 拡張: OSPF/IS-IS） |
| **ステート管理** | 網内全ルータで LDP ステート保持 | 網内全ルータで RSVP 予約ステート保持 | コントローラ/Ingress のみ |
| **用途** | 基本的な MPLS トランスポート | 精密な Traffic Engineering | 次世代シンプルファブリック |

### 2. Label Retention Mode (Liberal vs Conservative)

| 項目 | Liberal Retention (LLR) | Conservative Retention (CLR) |
| :--- | :--- | :--- |
| **動作** | 非最適次ホップからのラベルも LIB に保持 | 最適 IGP 次ホップからのラベルのみ保持 |
| **メリット** | IGP 迂回時の高速切り替えが可能 | メモリ消費量が少ない |
| **デフォルト** | **Cisco IOS-XE 標準** | ほぼ使用されない |

---

## 💡 ベストプラクティス

1. **LDP-IGP Synchronization の全網適用:**
   * バックボーン内の全 LDP 有効化リンクで `mpls ldp sync` を設定し、IGP 障害復旧時のブラックホールを防止する。
2. **LDP Session Protection の適用:**
   * コアリンクの瞬断・フラッピング対策として `mpls ldp session-protection` を有効化する。
3. **Explicit Router-ID 指定:**
   * `mpls ldp router-id Loopback0 force` を投入し、意図しない物理ポート IP が LDP ID に選ばれる事故を防ぐ。
4. **Jumbo MTU / MPLS MTU の広域設計:**
   * コア網の全物理ポートで MTU を 1520 バイト以上に拡張し、ラベルスタックによる断片化・ドロップを未然に防止する。

---

## 📝 ラボ学習・設定サンプル例

### Lab 1: 基本的な LDP 隣接関係の構築と確認
* **問題:** R1 と R2 間の Gi0/1 で LDP セッションを確立させよ。
* **要件:**
  * LDP Router-ID には Loopback0 を使用すること。
  * 明示的に `force` オプションを付けて固定すること。
* **設定例:**
  ```text
  ! R1
  mpls ip
  mpls ldp router-id Loopback0 force
  interface GigabitEthernet0/1
   ip address 10.1.12.1 255.255.255.0
   mpls ip
  ```
* **検証方法:**
  * `show mpls ldp neighbor` で State が `OPERATIONAL` になっていることを確認。

### Lab 2: OSPF Autoconfig による MPLS LDP 一括有効化
* **問題:** OSPF Area 0 に属する全インターフェイスで自動的に LDP を有効化せよ。
* **要件:** `interface` 配下で `mpls ip` を個別入力せず、OSPF プロセスから有効化すること。
* **設定例:**
  ```text
  ! R1
  router ospf 1
   router-id 1.1.1.1
   mpls ldp autoconfig area 0
  ```
* **検証方法:**
  * `show mpls ldp discovery` で対向ポートが自動検出されていることを確認。

### Lab 3: LDP-IGP Synchronization の構築
* **问题:** OSPF リンクで LDP 同期が未完了の間、トラフィックが流入しないよう保護せよ。
* **要件:** LDP セッション不全時は OSPF Metric 65535 を手動なしで広告させること。
* **設定例:**
  ```text
  ! R1
  router ospf 1
   mpls ldp sync
  ```
* **検証方法:**
  * LDP を shutdown させ、`show ip ospf interface Gi0/1` で Metric が 65535 に変化することを確認。

### Lab 4: LDP Session Protection の有効化
* **問題:** 物理リンク障害時も Targeted LDP セッションを 24 時間保持させよ。
* **要件:** セッションプロテクションを大域設定として適用すること。
* **設定例:**
  ```text
  ! R1
  mpls ldp session-protection duration 86400
  ```
* **検証方法:**
  * `show mpls ldp neighbor detail` で `Session protection: enabled` を確認。

### Lab 5: LDP Neighbor MD5 パスワード認証
* **問題:** R1 と R2 間の LDP 通信を MD5 認証で保護せよ。
* **要件:** パスワードとして `CiscoLab123` を設定すること。
* **設定例:**
  ```text
  ! R1
  mpls ldp neighbor 2.2.2.2 password CiscoLab123
  ```
* **検証方法:**
  * `show mpls ldp neighbor detail` で認証ステートが Active であることを確認。

### Lab 6: Explicit Null Label の広報設定
* **問題:** Egress ルータで PHP (Implicit Null) を無効化し、QoS Exp ビットを透過させよ。
* **要件:** Explicit Null (Label 0) を全隣接へ広告すること。
* **設定例:**
  ```text
  ! R3 (Egress PE)
  mpls ldp explicit-null
  ```
* **検証方法:**
  * 隣接 P ルータで `show mpls ldp bindings 3.3.3.3 32` を実行し、`Outgoing Label: Explicit-Null` を確認。

### Lab 7: MPLS MTU の拡張設定
* **問題:** 2 段ラベル付与時のパケットドロップを防ぐため、MPLS MTU を 1520 に拡張せよ。
* **要件:** 物理 IP MTU は 1500 のまま、MPLS 専用 MTU を設定すること。
* **設定例:**
  ```text
  ! R1
  interface GigabitEthernet0/1
   mpls mtu 1520
  ```
* **検証方法:**
  * `show mpls interfaces GigabitEthernet0/1 detail` で `MTU = 1520` を確認。

### Lab 8: 特定プレフレフィックスに対する Label 配布制限 (Filtering)
* **問題:** Loopback アドレス (`10.0.0.0/8`) 以外に対する LDP ラベル割り当てを停止せよ。
* **要件:** アクセスリストを用いて割り当てラベルの生成（Allocation）を制限すること。
* **設定例:**
  ```text
  ! R1
  ip access-list standard ACL_LDP_PREFIXES
   permit 10.0.0.0 0.255.255.255
  !
  mpls ldp label
   allocate global host-routes
  ```
* **検証方法:**
  * `show mpls ldp bindings` で /32 ホストルート以外に Local Label が割り当てられていないことを確認。

### Lab 9: MPLS LSP Ping によるデータプレーン検証
* **問題:** R1 から R3 の Loopback0 (`3.3.3.3/32`) への LSP 整合性を検証せよ。
* **要件:** MPLS Echo Request を使用して FEC 整合性をテストすること。
* **設定例 / 検証コマンド:**
  ```text
  R1# ping mpls ipv4 3.3.3.3/32
  ```
* **検証方法:**
  * 応答で `Sender handle for this message: 1, Reply Source: 3.3.3.3, Return Code: 3 (Replying router is an egress for the FEC)` が得られることを確認。

### Lab 10: MPLS LSP Traceroute によるラベルパス経路追跡
* **問題:** R1 から R3 へのラベルスイッチパス（LSP）の中継ラベルと DDMAP 情報を表示せよ。
* **設定例 / 検証コマンド:**
  ```text
  R1# traceroute mpls ipv4 3.3.3.3/32
  ```
* **検証方法:**
  * 各 Hop での Outgoing Label、In-Label、および Output Interface が正しく表示されることを確認。

---

## ❓ 想定試験問題

* **問 1 (コンフィグ読解):**
  * 次の出力が得られている場合、考えられる障害原因と修正コマンドを述べよ。
  ```text
  R1# show mpls ldp sync
  Gi0/1:
      LDP-IGP Synchronization: enabled
      Sync status: Not synchronized
      IGP submission: holddown (timer 10 sec remaining)
  ```
  * **解答・解説:** LDP-IGP 同期が有効だが、Gi0/1 上で対向との LDP セッションが確立していないため OSPF メトリックが 65535 に固定されている。対向の LDP 設定 (`mpls ip`)、LDP Router-ID への L3 到達性、および TCP 646 の遮断がないかを確認・修復する。

* **問 2 (トラブルシューティング):**
  * MPLS 網内で IP Ping は成功するが、`ping mpls ipv4` が失敗（Return Code: No FEC Mapping）する。主な原因を 2 つ挙げよ。
  * **解答・解説:**
    1. コントロールプレーン（RIB/LIB）とデータプレーン（LFIB）の不一致（FIB/LFIB 破棄）。
    2. 途中の Transit ルータで特定 FEC の LDP ラベル割り当てが制限（Filtering）されている。

* **問 3 (Design):**
  * PHP (Penultimate Hop Popping) のメリットと、PHP を無効化（`mpls ldp explicit-null`）すべき設計要件を説明せよ。
  * **解答・解説:**
    * メリット: Egress PE ルータでの double lookup（LFIB 検索 ＋ FIB 検索）を回避し、CPU 負荷を削減する。
    * 無効化要件: 端から端まで QoS の DiffServ (Exp/TC) 情報の透過を保証し、Egress PE の出力ポートキューイングに反映させる必要がある場合。

* **问 4 (実装):**
  * R1 の LDP Transport Address を明示的に Loopback0 に固定し、セッション切断を防ぐための完全なコンフィグを記述せよ。
  * **解答・解説:**
    ```text
    mpls ldp router-id Loopback0 force
    ```

* **問 5 (トラブルシューティング):**
  * `show mpls ldp neighbor` の出力で、特定ネクストホップのステータスが `INITIALIZED` のまま遷移しない。最初に確認すべき検証コマンドと項目は何か。
  * **解答・解説:** `show mpls ldp discovery` を実行し、Hello パケットの相互受信（UDP 646）ができているか確認する。次に `show ip route <Transport-IP>` で互いの Transport IP（LDP Router-ID）へ unicast 到達性があるかを検証する。

---

## 🔗 参考リソース

* [Cisco IOS-XE 17.x MPLS Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_ldp/configuration/xe-17/mp-ldp-xe-17-book.html)
* [Cisco Command Reference - mpls ldp commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_ldp/command/mp-ldp-cr-book.html)
* [Cisco Live - BRKRST-3001: Advanced MPLS Architecture & Operations](https://www.ciscolive.com/)
* [Cisco Technical Notes - Troubleshooting LDP Session Establishment Issues](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/23302-ldp-troubleshoot.html)
* [Cisco White Paper - Understanding MPLS OAM (LSP Ping / Traceroute)](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/116124-tech-mpls-oam-00.html)

---

## 📝 **補足（Notes）**

* **学習メモ:** LDP は単純なプロトコルに見えるが、IGP との同期ミスや MTU 不具合によるサイレントドロップが実用・ラボ試験問わず最大の落とし穴となる。
* **図解注意点:**
  * Ingress: Push
  * Transit: Swap
  * Penultimate Hop: Pop (Implicit Null)
  * Egress: IP Processing
* **重要コマンド:** `show mpls forwarding-table` を常に手で叩いて、In-Label / Out-Label / Out-Interface / Next-Hop の追跡ができるように反復演習を行うこと。


## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKCCIE-3000: BGP and Multicast for the CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   MPLS/L3VPN環境下での複雑なルーティング操作のヒントが含まれています。
*   [**BRKSP-2551: Introduction to Segment Routing**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSP-2551)
    *   LDPに代わる次世代MPLS技術の基礎として、従来のMPLS Operationsの理解を深めるのに役立ちます。

### Configuration ガイド
*   [**MPLS Label Distribution Protocol Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_basic/configuration/xe-17/mp-basic-xe-17-book/mp-ldp-config.html)。
*   [**MPLS: Layer 3 VPNs Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-17/mp-l3-vpns-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Multiprotocol Label Switching (MPLS) Overview**](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/12492-mpls-faq-12492.html)。
*   [**Verify MPLS on Catalyst 9000 Switches (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-9300-series-switches/217112-verify-mpls-on-catalyst-9000-switches.html)。

---
## 📝 補足
- この学習メモは、MPLSの基本動作からLDPの高度な制御までを網羅しています。CCIE実技試験では、**IGPとLDPの密接な関係**（Router-IDの到達性や同期設定）がトラブルの焦点となることが多いため、`show mpls ldp neighbor` と `show ip route` を往復して論理的な欠落を発見する訓練が重要です。


