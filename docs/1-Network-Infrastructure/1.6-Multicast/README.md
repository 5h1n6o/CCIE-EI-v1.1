---
layout: default
title: 1.6-Multicast
parent: 1-Network-Infrastructure
nav_order: 6
---

# 1.6 Multicast

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における IP マルチキャスト領域（Blueprint 1.6）全般について、Cisco IOS-XE 17.x の実装基準に完全準拠し、技術原理から制御メカニズム、RP 選定アルゴリズム、L2 制御、トラブルシューティング、および 10 個の実践的ラボシナリオまで徹底的に解説します。

---

## 📘 概要

IP マルチキャストは、1 つの送信元（Source）から複数の受信者（Receivers / Group Members）に対して、単一の IP パケットコピーを効率的に同時配信する技術です。ユニキャストのように受信者の数だけパケットを複製して送信する（帯域の浪費）や、ブロードキャストのように不要な端末へまでパケットを撒き散らす（CPU 負荷の増大）ことを回避し、ネットワークリソースを最適化します。

CCIE EI v1.1 における Multicast ドメインは、以下の要素で構成されます：
1. **Layer 2 Multicast 制御:** IGMP (v2/v3), MLD (IPv6), IGMP Snooping, PIM Snooping, IGMP Querier, IGMP Filtering
2. **Reverse Path Forwarding (RPF) Check:** ループ防止とマルチキャストパケットの逆方向ルーティング検証
3. **PIM (Protocol Independent Multicast):** PIM-SM (Sparse Mode), Static RP, Auto-RP, BSR (Bootstrap Router), SSM (Source Specific Multicast)
4. **RP 冗長化 & 高度機能:** MSDP (Multicast Source Discovery Protocol) Anycast RP, PIMv6 Anycast RP, RP Announcement Filter, Multicast Boundary, Multicast Multipath

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | トラフィックの重複送信を防止。Layer 2 メカニズム（IGMP Snooping）と Layer 3 ルーティング（PIM）が連携してディストリビューションツリー（Shared Tree / Source Tree）を構築。 |
| **主要コンポーネント** | IGMPv2/v3, MLD, PIM-SM, Static RP, Auto-RP, BSR, SSM, MSDP Anycast RP, PIMv6 Anycast RP |
| **IP アドレス範囲** | IPv4: `224.0.0.0/4` (`224.0.0.0` 〜 `239.255.255.255`)<br>IPv6: `ff00::/8` |
| **RPF チェック** | 送信元 IP アドレスへの最短パス（Unicast Routing Table）の出入り口インターフェイスからパケットが到達したか否かを検証（ループ防止の鉄則）。 |
| **L2 Mac アドレス変換** | IPv4 Multicast MAC: `01:00:5e:00:00:00` 〜 `01:00:5e:7f:ff:ff`（下位 23 ビットをマッピング。32 個の IP アドレスが 1 つの MAC に重複）。<br>IPv6 Multicast MAC: `33:33:xx:xx:xx:xx`（下位 32 ビットをマッピング）。 |
| **設計上の注意点** | ① PIM-SM では全マルチキャストルータで同一の Group-to-RP マッピングが必要。<br>② IGMP Snooping 使用時は L2 VLAN 内に IGMP Querier または PIM ルータが存在必須。<br>③ MSDP は iBGP/eBGP メッシュや IGP 可達性と密接に関連。 |

---

## 🏗 動作原理

### 1. マルチキャスト配送ツリーの構造
マルチキャスト制御では、以下の 2 種類のディストリビューションツリーを動的に形成します。

```text
[ Shared Tree (*, G) ] - RPT (Rendezvous Point Tree)
  Source ──► RP (Rendezvous Point)
               │
               ├─► Router A ──► Receiver 1
               └─► Router B ──► Receiver 2

[ Source Tree (S, G) ] - SPT (Shortest Path Tree)
  Source ────────────────► Router A ──► Receiver 1
    │
    └────────────────────► Router B ──► Receiver 2
```

1. **Shared Tree (*, G):** 任意のアドレス `*` から特定のグループ `G` へのツリー。中心に **RP（Rendezvous Point）** が存在し、受信者は RP に対して Join パケットを送ります。
2. **Source Tree (S, G):** 特定の送信元 `S` からグループ `G` への最短ツリー。データ受信後、ラストホップルータ（LHR）は SPT Switchover（SPT 閾値 = 0Kbps）を行い、RP を経由しない最短パスへ切り替えます。

---

## ⚙ 動作シーケンス

### PIM-SM データプレーン & 制御プレーンの処理シーケンス

```text
Host (Receiver)         Last-Hop Router (LHR)            RP Router               First-Hop Router (FHR)      Source
    │                        │                              │                           │                        │
    │── IGMPv2 Report (G) ──►│                              │                           │                        │
    │                        │─── PIM (*, G) Join (RP) ────►│                           │                        │
    │                        │                              │                           │                        │
    │                        │                              │◄── Multicast Data (S,G) ──│◄── Multicast Data ─────│
    │                        │                              │    (Encapsulated in       │                        │
    │                        │                              │     PIM Register)         │                        │
    │                        │                              │                           │                        │
    │                        │                              │── PIM Register-Stop ─────►│                        │
    │                        │                              │                           │                        │
    │                        │◄── Multicast Data (*,G) ─────│                           │                        │
    │◄── Multicast Data ─────│                              │                           │                        │
    │                        │                              │                           │                        │
    │                        │─────── PIM (S, G) Join (SPT Switchover) ────────────────►│                        │
    │                        │                              │                           │                        │
    │                        │◄────── Direct Multicast Data (S,G) ──────────────────────│                        │
    │                        │                              │                           │                        │
    │                        │─────── PIM (S,G, RPT-bit Prune) ─────►│                │                        │
```

1. **受信者の参加:** Receiver が `IGMP Report` を送出し、LHR が (*, G) エントリを作成して RP 方向へ `PIM (*, G) Join` を送信。
2. **送信元の登録:** Source がデータ送出を開始すると、FHR がデータを捕獲し、RP へ向けて `PIM Register` パケット（ユニキャストカプセル化）を送信。
3. **Register 解除:** RP は (*, G) ツリー経由でデータを転送開始し、FHR に対して `PIM (S, G) Join` を送ってネイティブルートを形成後、`PIM Register-Stop` を返してカプセル化を停止。
4. **SPT Switchover:** LHR は最初のパケットを (*, G) ツリー経由で受領すると、即座に Source への最短パス（SPT）上にある FHR へ向けて `PIM (S, G) Join` を送信し、(S, G) ツリーへ切替。同時に RP 宛に `PIM (S, G) RPT-bit Prune` を送信。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、マルチキャストは単体設定だけでなく、OSPF/BGP/VRF/DMVPN/SD-Access との複合問題として出題されます。

### 1. RP 選定メカニズムの優先順位（絶対暗記）
ルータが複数の手法で RP 情報を学習した場合、以下の絶対的な優先順位で採用されます：

```text
【最高優先度】 1. Static RP (override オプション付き)
              2. Auto-RP (MA から学習) / BSR (Bootstrap Router から学習)
              3. Static RP (override なし)
【最低優先度】 4. Embedded RP (IPv6)
```

* **Auto-RP vs BSR のバッティング:** Auto-RP と BSR が両方動いている場合、IP アドレスやメトリックに関わらず、通常 Auto-RP が勝ちます。Static RP を確実に優先させたい場合は `ip pim rp-address <IP> override` を付与します。

### 2. Auto-RP & BSR の Sparse-Mode での落とし穴
* **Auto-RP (Cisco 独自):** RP Announce (`224.0.1.39`) と RP Mapping (`224.0.1.40`) を用います。PIM Sparse-Mode では、RP アドレスが不明な状態ではこれらのマルチキャストパケット自体が転送できません。
  * **解決策 1:** 全インターフェイスで `ip pim sparse-dense-mode` を設定。
  * **解決策 2:** `ip pim auto-rp listener` コマンドを投入（`224.0.1.39/40` のみを Dense-Mode 動作させる）。
* **BSR (RFC 標準):** Bootstrap メッセージを All-PIM-Routers (`224.0.0.13`) 宛てに Hop-by-Hop ユニキャスト風マルチキャスト（TTL=1）で隣接へ転送するため、`sparse-dense-mode` や `auto-rp listener` は不要です。

### 3. RPF Check 失敗の典型パターン
* **ユニキャストルーティングテーブルに Source IP への経路が存在しない:**
* **非対称ルーティング:** ユニキャストの最良パスの出力インターフェイスと、マルチキャストパケットが入ってきた入力インターフェイスが不一致。
* **Static Mroute での補正:** `ip mroute <Source-IP> <Mask> <Next-Hop/Int>` を用いて、マルチキャスト専用の RPF パスを強制的に固定する。

### 4. MSDP (Multicast Source Discovery Protocol) & Anycast RP
* MSDP は PIM-SM ドメイン間（または Anycast RP ルータ間）で Source の存在（SA: Source Active メッセージ）を共有するプロトコル。
* **MSDP RPF Check 規則:** MSDP SA メッセージを受信した際、送信元 MSDP ピア（MSDP Peer）に対する BGP / IGP の可達性検証が行われます。eBGP ピアでない場合、`ip msdp peer` のアドレスと BGP/IGP のピアアドレスが一致していないと SA パケットがドロップされます。

---

## 🛠 設定方法

### 1. 基本的な PIM Sparse-Mode & Static RP 設定

```bash
# 全ルータでマルチキャストルーティングの有効化
ip multicast-routing

# インターフェイス設定
interface GigabitEthernet1/0/1
 ip address 10.1.12.1 255.255.255.0
 ip pim sparse-mode
```

### 2. Auto-RP 設定 (Candidate RP & Mapping Agent)

```bash
# 【Candidate RP (C-RP)】
ip pim send-rp-announce Loopback0 scope 16 group-list ACL_MULTICAST_GROUPS
ip pim auto-rp listener  # Dense-Mode 転送を許可

# 【Mapping Agent (MA)】
ip pim send-rp-discovery Loopback0 scope 16
ip pim auto-rp listener

# 参照 ACL
ip access-list standard ACL_MULTICAST_GROUPS
 permit 239.0.0.0 0.255.255.255
```

### 3. BSR 設定 (C-RP & C-BSR)

```bash
# 【Candidate BSR】
ip pim bsr-candidate Loopback0 30 192  # Priority 30, Hash length 192

# 【Candidate RP】
ip pim rp-candidate Loopback0 group-list ACL_BSR_GROUPS

ip access-list standard ACL_BSR_GROUPS
 permit 239.10.0.0 0.0.255.255
```

### 4. MSDP Anycast RP 設定 (IPv4)

```bash
# RP1 (1.1.1.1) と RP2 (2.2.2.2) で Anycast アドレス 10.10.10.10 を共用
# 【RP1】
interface Loopback0
 ip address 1.1.1.1 255.255.255.255
 ip pim sparse-mode
!
interface Loopback10  # Anycast RP IP
 ip address 10.10.10.10 255.255.255.255
 ip pim sparse-mode
!
ip pim rp-address 10.10.10.10
!
ip msdp peer 2.2.2.2 connect-source Loopback0
ip msdp originator-id Loopback0
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **PIM ネイバー関係の確認** | <code>show ip pim neighbor</code> |
| **RP マッピング情報（学習結果・手法）の確認** | <code>show ip pim rp mapping</code> |
| **PIM トポロジーテーブル (*, G) / (S, G) の確認** | <code>show ip mroute</code> |
| **特定グループに対する RPF インターフェイスの確認** | <code>show ip rpf \<Source-IP\></code> |
| **IGMP グループ参加状況（L2/L3）の確認** | <code>show ip igmp groups</code> |
| **IGMP Snooping テーブルの確認** | <code>show ip igmp snooping groups</code> |
| **MSDP ピアセッションおよび SA キャッシュの確認** | <code>show ip msdp peer</code> / <code>show ip msdp sa-cache</code> |
| **PIM パケットのリアルタイムデバッグ** | <code>debug ip pim</code> / <code>debug ip mrouting</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **マルチキャストデータが受信者に届かない（`show ip mroute` で Incoming interface が Null）。** | RPF チェックの失敗（送信元 IP へのユニキャスト経路が存在しない、または入力ポートと不一致）。 | <code>show ip rpf \<Source-IP\></code><br><code>show ip route \<Source-IP\></code> | ユニキャストルーティングを修正するか、手動で <code>ip mroute \<Source-IP\> 255.255.255.255 \<Next-Hop/Int\></code> を追加。 |
| **Auto-RP 環境で RP マッピング情報が学習されない。** | `ip pim auto-rp listener` または `sparse-dense-mode` の設定が漏れている。 | <code>show ip pim rp mapping</code> | 全ルータで <code>ip pim auto-rp listener</code> を投入する。 |
| **IGMP Snooping を有効にしたら L2 スイッチ配下で通信断。** | VLAN 内に IGMP Querier（PIM ルータまたは L2 Querier）が存在しないため、Member Report が途絶えた。 | <code>show ip igmp snooping querier</code> | L2 スイッチで <code>ip igmp snooping querier</code> を有効化するか、SVI で PIM を有効化する。 |
| **MSDP ピアが建立しているのに SA キャッシュがドロップされる。** | MSDP RPF チェックの失敗（MSDP ピアのアドレスと BGP/IGP のベストパスネクストホップが不一致）。 | <code>show ip msdp sa-cache</code><br><code>show ip rpf \<MSDP-Peer-IP\></code> | <code>ip msdp peer</code> の指定アドレスを IGP/BGP の Router-ID / Connect-Source に合わせるか、<code>ip msdp mesh-group</code> を構成。 |

---

## ⚠ 制限事項

1. **IGMP Snooping & Router Alert Option:**
   一部のローエンドスイッチでは IGMPv3 の Source-Specific 情報をハードウェア（ASIC）で処理できず、CPU にパンティングされて性能低下を起こす。
2. **PIM SSM (Source Specific Multicast) の範囲:**
   SSM の標準グループ範囲は **`232.0.0.0/8`** に限定されます。それ以外のグループ（例: `239.1.1.1`）で SSM を動かす場合は `ip pim ssm default` または `ip pim ssm range <ACL>` の明示指定が必要です。

---

## 🔄 他技術との関連

* **VRF-Aware Multicast (MVPN / VRF Lite):**
  `ip multicast-routing vrf RED` により、VRF ごとに独立した PIM プロセスと mroute テーブルを保持。
* **DMVPN (Phase 3) & Multicast:**
  mGRE トンネルインターフェイス上で PIM を動かす場合、`ip pim nbma-mode` を設定して、Hub が受信した Join/Prune やデータパケットを全 Spoke へ複製送出しないように制御する。
* **SD-Access (SDA) Fabric Multicast:**
  Fabric Underlay において Native Multicast（ASM/SSM）または Head-End Replication (HER) を選択して Overlay マルチキャストをカプセル化（VXLAN）送出する。

---

## 🧩 比較表

### Auto-RP vs BSR vs Static RP

| 比較項目 | Auto-RP | BSR (Bootstrap Router) | Static RP |
| :--- | :--- | :--- | :--- |
| **標準規格** | Cisco 独自 | IETF 標準 (RFC 5059) | 標準 |
| **メッセージ転送** | `224.0.1.39` (Announce)<br>`224.0.1.40` (Discovery) | `224.0.0.13` (Hop-by-Hop, TTL=1) | なし（静的定義） |
| **Sparse-Mode 補正** | `auto-rp listener` または `sparse-dense-mode` 必須 | 不要 | 不要 |
| **RP 選定ルール** | MA がグループごとに最高 IP の C-RP を選定して全配布 | 全ルータが BSR 情報を保持し、ハッシュ値（Hash Value）で個別に計算 | ローカル設定固定 |
| **優先度** | 2位（Auto-RP 勝利） | 3位 | 1位（`override` 時） / 4位 |

---

## 💡 ベストプラクティス

1. **PIM-SM における RP 冗長化には MSDP Anycast RP または BSR を使用する:**
   キャンパス網では BSR、マルチドメインや大規模データセンターでは MSDP Anycast RP を採用。
2. **IGMP Snooping 導入時の Querier 明確化:**
   L2 スイッチ環境では必ず最小 IP の L3 ルータを Querier に設定するか、`ip igmp snooping querier` を明示的に構成。
3. **SSM の積極採用:**
   送信元が既知の動画配信等では、RP や Shared Tree が不要で構造が単純な PIM-SSM (`232.0.0.0/8`) を採用する。

---

## 📝 ラボ学習・設定サンプル例

### Scenario 1: PIM-SM + Static RP 基本構成
* **要件:** R1, R2, R3 で PIM Sparse-Mode を構成し、R2 の Loopback0 (`2.2.2.2`) を全員の Static RP として指定せよ。

**【R1 / R2 / R3 共通】**
```bash
ip multicast-routing
!
interface GigabitEthernet1/0/1
 ip pim sparse-mode
!
ip pim rp-address 2.2.2.2
```

---

### Scenario 2: Auto-RP (Candidate RP & Mapping Agent) 設定
* **要件:** R2 (`2.2.2.2`) を C-RP および Mapping Agent とし、`239.1.0.0/16` グループ用に Auto-RP を構成せよ。全ルータは PIM Sparse-Mode のみ使用すること。

**【全ルータ共通】**
```bash
ip multicast-routing
ip pim auto-rp listener
```

**【R2 (C-RP & MA)】**
```bash
ip access-list standard ACL_AUTORP
 permit 239.1.0.0 0.0.255.255
!
ip pim send-rp-announce Loopback0 scope 16 group-list ACL_AUTORP
ip pim send-rp-discovery Loopback0 scope 16
```

---

### Scenario 3: BSR (Bootstrap Router) 設定
* **要件:** R3 (`3.3.3.3`) を Candidate BSR (Priority 100) および Candidate RP として構成せよ。

**【R3】**
```bash
ip multicast-routing
!
ip pim bsr-candidate Loopback0 128 100
ip pim rp-candidate Loopback0
```

---

### Scenario 4: PIM SSM (Source Specific Multicast) 設定
* **要件:** グループ `232.1.1.1` に対して PIM-SSM を構成し、RP を経由せずに送信元 `10.1.1.100` から直接 (S, G) ツリーを形成せよ。

**【全ルータ】**
```bash
ip multicast-routing
ip pim ssm default
```

**【Receiver 接続インターフェイス (LHR)】**
```bash
interface GigabitEthernet1/0/2
 ip pim sparse-mode
 ip igmp version 3
```

---

### Scenario 5: IGMP Snooping & L2 IGMP Querier 設定
* **要件:** Switch 1 上で IGMP Snooping を有効化し、L3 ルータが存在しない VLAN 100 で Switch 1 自身を IGMP Querier として動作させよ。

**【SW1】**
```bash
ip igmp snooping
ip igmp snooping vlan 100
ip igmp snooping vlan 100 querier
ip igmp snooping vlan 100 querier address 10.1.100.254
```

---

### Scenario 6: MSDP Anycast RP (IPv4 冗長化)
* **要件:** R1 (`1.1.1.1`) と R2 (`2.2.2.2`) の間で MSDP ピアを建立し、Anycast RP アドレス `10.0.0.100` を提供せよ。

**【R1】**
```bash
ip multicast-routing
interface Loopback10
 ip address 10.0.0.100 255.255.255.255
 ip pim sparse-mode
!
ip pim rp-address 10.0.0.100
ip msdp peer 2.2.2.2 connect-source Loopback0
ip msdp originator-id Loopback0
```

**【R2】**
```bash
ip multicast-routing
interface Loopback10
 ip address 10.0.0.100 255.255.255.255
 ip pim sparse-mode
!
ip pim rp-address 10.0.0.100
ip msdp peer 1.1.1.1 connect-source Loopback0
ip msdp originator-id Loopback0
```

---

### Scenario 7: PIMv6 Anycast RP (IPv6 マルチキャスト)
* **要件:** IPv6 環境において、R1 (`2001:db8:1::1`) と R2 (`2001:db8:2::2`) 間で PIMv6 Anycast RP アドレス `2001:db8:ffff::100` を構成せよ。

**【R1】**
```bash
ipv6 unicast-routing
ipv6 multicast-routing
!
interface Loopback10
 ipv6 address 2001:db8:ffff::100/128
 ipv6 pim
!
ipv6 pim rp-address 2001:db8:ffff::100
ipv6 pim anycast-rp 2001:db8:ffff::100 2001:db8:1::1
ipv6 pim anycast-rp 2001:db8:ffff::100 2001:db8:2::2
```

---

### Scenario 8: Multicast Boundary (スコープ制限)
* **要件:** R1 の Gi0/2 インターフェイスから、プライベートマルチキャストグループ `239.0.0.0/8` のトラフィックおよび PIM 制御パケットが出出しないよう境界を設定せよ。

**【R1】**
```bash
ip access-list standard ACL_MCAST_BOUNDARY
 deny 239.0.0.0 0.255.255.255
 permit any
!
interface GigabitEthernet0/2
 ip multicast boundary ACL_MCAST_BOUNDARY
```

---

### Scenario 9: Static Mroute による RPF 調整
* **要件:** 送信元 `192.168.10.5` からのマルチキャストパケットに対する RPF インターフェイスを、デフォルトの OSPF 経路（Gi0/1）ではなく Gi0/2 (ネクストホップ `10.1.25.2`) に手動強制せよ。

**【R1】**
```bash
ip mroute 192.168.10.5 255.255.255.255 10.1.25.2
```

---

### Scenario 10: VRF-Aware Multicast (VRF Lite)
* **要件:** VRF `TENANT_A` 配下でマルチキャストルーティングを有効化し、Static RP `10.100.1.1` を構成せよ。

**【R1】**
```bash
ip multicast-routing vrf TENANT_A
!
interface GigabitEthernet0/3
 vrf forwarding TENANT_A
 ip address 10.100.12.1 255.255.255.0
 ip pim sparse-mode
!
ip pim vrf TENANT_A rp-address 10.100.1.1
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】RPF Failed による mroute ドロップ
**問題:** 
R1 で `show ip mroute` を確認したところ、グループ `239.1.1.1` の (10.1.50.1, 239.1.1.1) エントリにおいて `Incoming interface: Null` と表示され、受信者にデータが届きません。`show ip rpf 10.1.50.1` の出力結果を踏まえ、原因と最も適切な修復コマンドを述べてください。

**解答・解説:**
* **原因:** 送信元 IP（10.1.50.1）へのユニキャスト経路が存在しないか、またはマルチキャストパケットを受信した物理ポートが、ユニキャストルーティングテーブルにおける 10.1.50.1 への最良出力ポートと異なっているため（RPF チェック失敗）。
* **修復コマンド:**
  ```bash
  ip mroute 10.1.50.1 255.255.255.255 <正しいネクストホップIPまたは入力インターフェイス>
  ```

---

### 2. 【Design】Auto-RP と Static RP の優先関係
**問題:** 
ルータ上で `ip pim rp-address 1.1.1.1` (Static RP) が設定されています。同時に Auto-RP から group `239.2.2.2` に対して RP `2.2.2.2` が通知された場合、ルータはどちらの RP を使用しますか？また、Static RP を強制的に優先させる設定変更を提示してください。

**解答・解説:**
* **回答:** **Auto-RP (`2.2.2.2`) が使用されます。** （デフォルトでは Auto-RP が Static RP より優先度が高いため）。
* **優先固定コマンド:**
  ```bash
  ip pim rp-address 1.1.1.1 override
  ```

---

## 🔗 参考リソース

* [Cisco Systems: IP Multicast Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book.html)
* [Cisco Live: BRKMRT-2001 - Troubleshooting IP Multicast](https://www.ciscolive.com/global/on-demand-library.html)
* [Cisco Technical Notes: PIM Sparse-Mode Architecture and RPF Operations](https://www.cisco.com/c/en/us/support/docs/ip/ip-multicast/16450-mcast-routtbl.html)

---

## 📝 補足（Notes）

* **Multicast MAC 計算ルール:**
  `224.128.1.1` と `225.0.1.1` は下位 23 ビットがともに `0000000 00000001 00000001` となり、同一の L2 MAC アドレス `01:00:5e:00:01:01` に変換されます。L2 スイッチ上で予期せぬグループの重複混信を避けるため、設計時には下位 23 ビットが被らないようグループ IP をアサインするのが鉄則です。
