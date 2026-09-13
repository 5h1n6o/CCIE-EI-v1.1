---
layout: default
title: 1.4.b-OSPFv3-AF-support
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.4.b OSPFv3 address family support

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 routing プロトコルの1つである **OSPFv3 Address Family (AF) Support** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に完全準拠したExpertレベルの学習メモを記述します。

---

## 📘 概要

**OSPFv3 Address Family (AF) Support** とは、RFC 5838（Support of Address Families in OSPFv3）に基づき、従来IPv6専用ルーティングプロトコルであったOSPFv3を拡張し、単一のOSPFv3プロセス内（またはインターフェイス上）で **IPv4 ユニキャスト/マルチキャスト** および **IPv6 ユニキャスト/マルチキャスト** の双方のトラフィック（Dual-Stack）を統合ルーティング可能にした技術です。

従来のネットワークでは、IPv4にはOSPFv2（`router ospf`）、IPv6には従来のOSPFv3（`ipv6 router ospf`）という2つの独立したプロセスを起動・管理する必要があり、制御プレーンのリソース消費や設定の複雑化が課題となっていました。OSPFv3 Address Family構造を導入することで、単一のルーティングプロセス（`router ospfv3`）配下でアドレスファミリー（`address-family ipv4 unicast` / `address-family ipv6 unicast`）として統合管理できるようになりました。

### 主な利用目的と適用シーン
1. **IPv4 / IPv6 Dual-Stack ネットワークの制御プレーン統合一元管理:** 単一のOSPFv3プロセスIDおよびネイバーシップ管理で、IPv4とIPv6の両方のトポロジーとプレフィックスを伝搬・制御する。
2. **VRF-Lite および MPLS L3VPN（Multi-VRF）環境での構成簡略化:** VRF配下のIPv4/IPv6ルーティング（`address-family ipv4 unicast vrf <NAME>` / `address-family ipv6 unicast vrf <NAME>`）を統合管理し、プロセスの増設を抑制する。
3. **SD-Access / SD-WAN アンダーレイ基盤での採用:** Cisco DNA Center / Catalyst Center 配下のアンダーレイIPファブリックにおいて、IPv4とIPv6の双方を可送にする次世代アンダーレイ制御。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 単一の `router ospfv3 <process-id>` プロセス内で、IPv4 Unicast (`af ipv4`) と IPv6 Unicast (`af ipv6`) を統合制御。パケット送受信は常にIPv6リンクローカルアドレス (`fe80::`) および IPv6 Transport を使用。 |
| **用途** | キャンパスコア/ディストリビューション、WAN、データセンター、VRF-Lite環境におけるIPv4/IPv6 Dual-Stack アドレス体系の単一プロセスルーティング。 |
| **メリット** | ① 制御プレーン（CPU/メモリ）リソースの節約と設定の一元化。<br>② プロトコル制御パケット（Hello等）がIPv6ベースとなるため、IPv4側でのマルチキャスト処理やブロードキャストドメインの攻撃面を削減。<br>③ VRF対応構成が極めてシンプルに整理される。 |
| **デメリット** | IPv4 AF を利用する場合であっても、インターフェイス上で **IPv6 Processing（`ipv6 enable` または IPv6アドレス設定）が必須**。対向機器が RFC 5838 をサポートしていない場合、ネイバーが形成されない。 |
| **対応機種** | Cisco Catalyst 9000シリーズ、Catalyst 8000v、ASR1000シリーズ、ISR4000シリーズ（Cisco IOS-XE 15.1(2)S / 15.2(1)E / 16.x / 17.x 以降）。 |
| **制限事項** | OSPFv3 AF モード（`router ospfv3`）と従来の OSPFv2（`router ospf`）や Traditional OSPFv3（`ipv6 router ospf`）は同一ルータ内で併存可能だが、LSA処理やルーティングテーブルの二重管理に注意が必要。 |
| **設計上の注意点** | IPv4 AF の場合でも、Link LSA（Type 8）および Intra-Area-Prefix LSA（Type 9）により IPv4 プレフィックス情報が伝搬される。また、IPv4 ネクストホップの自動変換ロジックへの理解が不可欠。 |

---

## 🏗 動作原理

OSPFv3 Address Family は、制御パケット（Hello、DBD、LSR、LSU、LSAck）のトランスポート層として **常に IPv6 リンクローカルアドレス（`fe80::`）** を使用します。IPv4 トラフィック用の経路情報を交換する場合であっても、OSPFv3 パケット自体は IPv6 ヘッダー（Next Header 89）でカプセル化されて送受信されます。

### 通信フローおよび制御プレーンの構造

```text
[ IPv4/IPv6 Data Packet ]
          │
          ▼
┌────────────────────────────────────────────────────────┐
│               Data Plane (FIB / CEF)                   │
│   IPv4 Routing Table (RIB)  │  IPv6 Routing Table (RIB) │
└─────────────▲───────────────────────────▲──────────────┘
              │                           │
┌─────────────┴───────────────────────────┴──────────────┐
│  OSPFv3 Control Plane Process (router ospfv3 1)       │
│                                                        │
│  ┌────────────────────────┐  ┌──────────────────────┐  │
│  │ address-family ipv4    │  │ address-family ipv6 │  │
│  │ (Type 1/2/3/4/5/8/9)   │  │ (Type 1/2/3/4/5/8/9)│  │
│  └───────────┬────────────┘  └──────────┬───────────┘  │
│              └────────────┬─────────────┘              │
│                           ▼                            │
│           OSPFv3 Engine (RFC 5838 AF Handling)         │
└───────────────────────────┬────────────────────────────┘
                            │ (IPv6 Encapsulation: Protocol 89)
                            ▼
┌────────────────────────────────────────────────────────┐
│  Interface Level (e.g. Gi0/1)                          │
│  - IPv6 Link-Local Address (fe80::1) [MANDATORY]       │
│  - IPv4 Address (10.1.12.1/24)                         │
│  - Command: ospfv3 1 ipv4 area 0                       │
│  - Command: ospfv3 1 ipv6 area 0                       │
└────────────────────────────────────────────────────────┘
```

### OSPFv3 AF における LSA ヘッダー拡張 (Instance ID)
RFC 5838 では、異なるアドレスファミリーの LSA や OSPFv3 パケットを単一の物理リンク上で識別・分離するために、OSPFv3 パケットヘッダー内の **Instance ID** フィールドを活用します。

* **IPv6 Unicast AF:** Instance ID = `0` ～ `31` (デフォルト: `0`)
* **IPv4 Unicast AF:** Instance ID = `64` ～ `95` (デフォルト: `64`)
* **IPv6 Multicast AF:** Instance ID = `32` ～ `63`
* **IPv4 Multicast AF:** Instance ID = `96` ～ `127`
* **User-defined AF / VRF:** Instance ID = `128` ～ `255`

この Instance ID の自動マッピングにより、単一の物理インターフェイス上で IPv4 と IPv6 の OSPFv3 パケットが受信された際、ルーティングエンジンは正しく対応する Address Family の LSDB（Link State Database）へ格納・処理します。

---

## ⚙ 動作シーケンス

OSPFv3 Address Family におけるネイバーアジャセンシーの確立からパケット処理、ルーティングテーブル登録までの詳細なシーケンスは以下の通りです。

```text
[ Router A (10.1.12.1 / fe80::1) ]                 [ Router B (10.1.12.2 / fe80::2) ]
        │                                                   │
        │─── 1. IPv6 Multicast (FF02::5) Hello ────────────►│
        │    - Protocol: 89, Src: fe80::1, Dst: FF02::5    │
        │    - Instance ID: 64 (for IPv4 AF)                │
        │    - Router ID: 1.1.1.1                           │
        │                                                   │
        │◄── 2. IPv6 Multicast (FF02::5) Hello ─────────────│
        │    - Instance ID: 64, Router ID: 2.2.2.2         │
        │                                                   │
        │============== [ State: 2-Way / ExStart ] =========│
        │                                                   │
        │─── 3. Database Description (DBD) Exchange ───────►│ (Instance ID: 64)
        │◄── 4. Database Description (DBD) Exchange ────────│
        │                                                   │
        │============== [ State: Exchange / Loading ] ======│
        │                                                   │
        │─── 5. Link LSA (Type 8) Exchange (Unicast) ──────►│
        │    - Contains: IPv4 Link-Local Prefix & Link-LSA  │
        │◄── 6. Intra-Area-Prefix LSA (Type 9) Exchange ────│
        │    - Contains: IPv4 Prefixes associated with Intf │
        │                                                   │
        │============== [ State: FULL ] ====================│
        │                                                   │
        │   [ SPF Calculation for IPv4 Topology ]           │
        │   - Calculate shortest path to Router B           │
        │   - Associate IPv4 prefixes (from Type 9 LSA)     │
        │   - Resolve Next-Hop to Router B's IPv4 address   │
        │                                                   │
        │─── 7. Populate IPv4 Routing Table (RIB/FIB) ──────│
```

1. **IPv6 カプセル化 Hello パケットの送受信:**
   * インターフェイスで `ospfv3 1 ipv4 area 0` を有効化すると、ルータは IPv6 リンクローカルアドレス（`fe80::1`）を送信元とし、マルチキャスト `FF02::5`（AllSPF Routers）宛てに OSPFv3 Hello パケットを送出します。
   * パケットヘッダーの **Instance ID は `64`**（IPv4 Unicast AF デフォルト）が設定されます。
2. **アジャセンシー形成とネゴシエーション:**
   * 対向ルータも Instance ID `64` の Hello を受診すると、Router ID、Area ID、Hello/Dead タイマー、Instance ID を検証し、2-Way ➔ ExStart ➔ Exchange ➔ Loading ステートへと推移します。
3. **LSA（Type 8 / Type 9）による IPv4 アドレス情報の伝搬:**
   * **Link LSA (Type 8):** インターフェイスの IPv4 アドレス（例: `10.1.12.1`）およびリンク属性を対向へ通知します。
   * **Intra-Area-Prefix LSA (Type 9):** 従来 Router LSA（Type 1）や Network LSA（Type 2）に含まれていた IPv4 プレフィックス情報（例: `10.1.12.0/24`）を分離して格納・伝搬します。
4. **SPF 計算と IPv4 RIB / FIB 掲載:**
   * Router A は Type 1/Type 2 LSA から構成されたネットワークトポロジーグラフ（ツリー構造）上で SPF 計算を実行します。
   * 算出されたツリーノードに対して Type 9 LSA 内の IPv4 プレフィックスをマッピングし、ネクストホップ（`10.1.12.2`）を特定して IPv4 Routing Table（`show ip route`）へ登録します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、OSPFv3 Address Family Support は従来の OSPFv2 や OSPFv3（IPv6専用）との相違点、落とし穴、複合要件が頻繁にテストされる高配点トピックです。

### 1. 必修！インターフェイス上での IPv6 有効化（`ipv6 enable`）の罠
* **最重要ポイント:** **OSPFv3 AF で IPv4 ルーティング（`address-family ipv4 unicast`）のみを運用する場合であっても、該当インターフェイス上で IPv6 処理が有効化されていないと OSPFv3 プロセスは動作せず、ネイバーは絶対に形成されません。**
* **試験での症状:** `ospfv3 1 ipv4 area 0` をインターフェイスに投入したのに `show ospfv3 neighbor` に何も表示されない。
* **原因:** インターフェイスに IPv4 アドレス（`ip address 10.1.12.1 255.255.255.0`）しか設定されておらず、IPv6 アドレスも `ipv6 enable` も設定されていないため、OSPFv3 の制御パケット送受信に必要な IPv6 Link-Local アドレス（`fe80::`）が存在しない。
* **対策・修正:** インターフェイス配下で `ipv6 enable` または明示的な IPv6 アドレスを設定する。

### 2. Router ID の明示的設定 (`router-id x.x.x.x`)
* OSPFv3 では IPv4 / IPv6 どちらの AF であっても、**Router ID は 32 ビット表記（IPv4 アドレス形式: 例 `1.1.1.1`）** である必要があります。
* アクティブな IPv4 アドレス/Loopback が存在しない場合、プロセス起動時に `OSPFv3-4-NOROUTERID` エラーが発生するため、`router ospfv3 <ID>` モード直下、または各 `address-family` 配下で明示的に `router-id 1.1.1.1` を定義することがラボでのベストプラクティスです。

### 3. モード階層と設定構文の違い（Modern OSPFv3 Syntax）
試験では、旧来の `ipv6 router ospf 1` 構文（Traditional OSPFv3）ではなく、**新標準である `router ospfv3 1` 構文（OSPFv3 AF モード）** の使用が指定されます。

* **プロセス起動モード:**
  ```bash
  router ospfv3 1
   router-id 1.1.1.1
   !
   address-family ipv4 unicast
    router-id 1.1.1.1
   exit-address-family
   !
   address-family ipv6 unicast
    router-id 1.1.1.1
   exit-address-family
  ```
* **インターフェイスバインドモード (Interface Level):**
  ```bash
  interface GigabitEthernet1/0/1
   ip address 10.1.12.1 255.255.255.0
   ipv6 enable
   ospfv3 1 ipv4 area 0
   ospfv3 1 ipv6 area 0
  ```

### 4. Instance ID ミスマッチによるネイバー不成立
* デフォルトでは、`ospfv3 1 ipv4 area 0` と投入すると Instance ID `64` が割り当てられます。
* 対向機器で手動で `ospfv3 1 ipv4 area 0 instance 65` などと変更されていたり、サードパーティ製機器で Instance ID のマッピングが異なる場合、Hello パケットが無視され `Init` から先に進みません。

---

## 🛠 設定方法

### 1. OSPFv3 Address Family 完全設定例 (IPv4/IPv6 Dual-Stack & VRF)

```bash
# ---------------------------------------------------------
# 1. ルーティングプロセス (OSPFv3 AF モード)
# ---------------------------------------------------------
router ospfv3 1
 router-id 1.1.1.1
 !
 # IPv4 グローバルアドレスファミリー
 address-family ipv4 unicast
  router-id 1.1.1.1
  auto-cost reference-bandwidth 10000
  passive-interface default
  no passive-interface GigabitEthernet1/0/1
 exit-address-family
 !
 # IPv6 グローバルアドレスファミリー
 address-family ipv6 unicast
  router-id 1.1.1.1
  auto-cost reference-bandwidth 10000
  passive-interface default
  no passive-interface GigabitEthernet1/0/1
 exit-address-family
 !
 # VRF (TENANT_A) 用 IPv4 アドレスファミリー
 address-family ipv4 unicast vrf TENANT_A
  router-id 11.11.11.11
  redistribute static
 exit-address-family
!

# ---------------------------------------------------------
# 2. インターフェイス側バインド設定
# ---------------------------------------------------------
interface GigabitEthernet1/0/1
 description ## Core Link to R2 ##
 ip address 10.1.12.1 255.255.255.0
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
 ! OSPFv3 AF インターフェイスバインド
 ospfv3 1 ipv4 area 0
 ospfv3 1 ipv6 area 0
!

interface GigabitEthernet1/0/2
 description ## Customer Edge (VRF TENANT_A) ##
 vrf forwarding TENANT_A
 ip address 192.168.10.1 255.255.255.0
 ipv6 enable
 ospfv3 1 ipv4 area 1 vrf TENANT_A
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPFv3 全体（IPv4 / IPv6 AF）のネイバー状態確認** | <code>show ospfv3 neighbor</code> |
| **IPv4 AF 固有のネイバーアジャセンシー状態監査** | <code>show ospfv3 ipv4 neighbor</code> / <code>show ospfv3 ipv4 neighbor detail</code> |
| **IPv6 AF 固有のネイバーアジャセンシー状態監査** | <code>show ospfv3 ipv6 neighbor</code> |
| **OSPFv3 データベース (LSDB) 一覧の確認 (AF指定)** | <code>show ospfv3 ipv4 database</code> / <code>show ospfv3 ipv6 database</code> |
| **OSPFv3 有効インターフェイスと Instance ID の監査** | <code>show ospfv3 interface</code> / <code>show ospfv3 ipv4 interface</code> |
| **特定 VRF 配下の OSPFv3 プロセス・ネイバー確認** | <code>show ospfv3 vrf TENANT_A neighbor</code> |
| **Hello パケットおよび Instance ID トラフィックのデバッグ** | <code>debug ospfv3 hello</code> / <code>debug ospfv3 packets</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`ospfv3 1 ipv4 area 0` を投入したのにネイバーが一切形成されない（Hello が出ない）。** | インターフェイス上で IPv6 処理（`ipv6 enable` または IPv6 アドレス）が未構成であり、制御パケット用の `fe80::` が存在しない。 | `show interface` <br>`show ipv6 interface brief` | 該当インターフェイスで `ipv6 enable` または IPv6 アドレスを設定し、IPv6 リンクローカルアドレスを自動生成させる。 |
| **`OSPFv3-4-NOROUTERID` エラーが発生し、プロセスが起動しない。** | 32ビット表記の Router ID が明示的・動的にアサインされていない。 | `show ospfv3` <br>`show logging` | `router ospfv3 <ID>` モードおよび配下の `address-family` モードで `router-id 1.1.1.1` を設定する。 |
| **Hello パケットは届いているが、ネイバー状態が `Init` / `Down` から進まない。** | 対向ルータ間で Instance ID（IPv4 AF デフォルト `64`）または Area ID / タイマー値が合致していない。 | `show ospfv3 interface`<br>`debug ospfv3 hello` | `show ospfv3 interface` で双方の Instance ID および Area ID を比較し、一致するように修正する。 |
| **OSPFv3 IPv4 ネイバーは成立するが、特定サブネットの IPv4 経路が RIB に載らない。** | インターフェイスの Prefix が Type 9 LSA (Intra-Area-Prefix LSA) で正しく生成されていないか、`passive-interface` の影響。 | `show ospfv3 ipv4 database intra-area-prefix`<br>`show ip route` | `show ospfv3 ipv4 database` で Type 9 LSA 内に該当 IPv4 プレフィックスが含まれているか検証する。 |

---

## ⚠ 制限事項

1. **IPv6 ネイティブトランスポートの強制:**
   * OSPFv3 AF は IPv4 経路を運ぶ場合でも、パケット自体は常に **IPv6 モジュール（Protocol 89）** を通して送受信されます。したがって、ネットワーク全体で IPv6 パケットのパス（MTU や L2 スイッチの IPv6 マルチキャスト処理など）が正常に通る必要があります。
2. **従来型 OSPFv2 (RFC 2328) との不互換性:**
   * OSPFv3 IPv4 AF（Instance ID 64）と、従来の OSPFv2（`router ospf`）はパケットフォーマットおよびトランスポートが完全に異なるため、直接ネイバーアジャセンシーを形成することはできません。

---

## 🔄 他技術との関連

* **VRF-Lite / MPLS L3VPN:**
  OSPFv3 AF では `address-family ipv4 unicast vrf <NAME>` および `address-family ipv6 unicast vrf <NAME>` を使用して、マルチテナント環境の L3 セグメンテーションを単一の OSPFv3 プロセス内で極めてエレガントに収容できます。
* **BFD (Bidirectional Forwarding Detection):**
  `ospfv3 bfd` コマンドをインターフェイスで有効化することで、OSPFv3 AF（IPv4 / IPv6 問わず）のネイバー障害をミリ秒単位で超高速検知できます。
* **IPv6 Infrastructure Security (RA Guard / CoPP):**
  OSPFv3 パケットは IPv6 マルチキャスト（`FF02::5`）を使用するため、スイッチの Port/VLAN セキュリティや Control Plane Policing (CoPP) で IPv6 マルチキャスト制御パケットを破棄しないよう許可ルール（Protocol 89）が必要です。

---

## 🧩 比較表

### OSPFv2 vs Traditional OSPFv3 vs OSPFv3 Address Family (AF)

| 比較項目 | OSPFv2 (`router ospf`) | Traditional OSPFv3 (`ipv6 router ospf`) | OSPFv3 Address Family (`router ospfv3`) |
| :--- | :--- | :--- | :--- |
| **対応プロトコル** | IPv4 のみ | IPv6 専用 | **IPv4 および IPv6 (Dual-Stack) 統合** |
| **トランスポート** | IPv4 (Protocol 89) | IPv6 (Protocol 89) | **IPv6 (Protocol 89: 送信元 fe80::)** |
| **パケット分離** | 不可 | 不可 | **Instance ID (IPv6: 0, IPv4: 64)** で分離 |
| **LSA 構造** | Type 1/2 に IP 情報を保持 | IP 情報を Type 8/9 LSA へ分離 | IP 情報を Type 8/9 LSA へ分離 |
| **設定コマンド** | `router ospf <ID>` | `ipv6 router ospf <ID>` | **`router ospfv3 <ID>` ➔ `address-family`** |
| **インターフェイス設定** | `ip ospf <ID> area <A>` | `ipv6 ospf <ID> area <A>` | **`ospfv3 <ID> <ipv4|ipv6> area <A>`** |
| **必須前提条件** | IPv4 アドレス定義 | IPv6 アドレス/`enable` | **IPv6 処理有効化 (`ipv6 enable` 必須)** |

---

## 💡 ベストプラクティス

1. **IPv4/IPv6 Dual-Stack 環境での OSPFv3 AF 標準化:**
   Cisco IOS-XE (Catalyst 9000 等) を使用する新規設計では、OSPFv2 と OSPFv3 を別々に動かすのではなく、`router ospfv3` による Address Family モードへ構成を統一する。
2. **全インターフェイスでの `ipv6 enable` の徹底:**
   IPv4 専用リンクであっても、OSPFv3 AF をバインドするすべてのインターフェイスに `ipv6 enable` を記述し、リンクローカルアドレス（`fe80::`）の欠落トラブルを未然に防止する。
3. **`passive-interface default` の適用:**
   `address-family ipv4 unicast` および `address-family ipv6 unicast` モード配下で `passive-interface default` を投入し、不要なインターフェイスでの OSPFv3 制御パケット送出をブロックする。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: OSPFv3 Address Family IPv4/IPv6 Dual-Stack 基本構成
* **要件:** R1 (Gi0/1: `10.1.12.1/24`, `2001:db8:12::1/64`) と R2 (Gi0/1: `10.1.12.2/24`, `2001:db8:12::2/64`) 間で、OSPFv3 AF プロセス 100 を使用して IPv4 および IPv6 のアジャセンシーを Area 0 で確立せよ。

**【R1】**
```bash
router ospfv3 100
 router-id 1.1.1.1
 !
 address-family ipv4 unicast
  router-id 1.1.1.1
 exit-address-family
 !
 address-family ipv6 unicast
  router-id 1.1.1.1
 exit-address-family
!
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ipv6 address 2001:db8:12::1/64
 ospfv3 100 ipv4 area 0
 ospfv3 100 ipv6 area 0
```

**【R2】**
```bash
router ospfv3 100
 router-id 2.2.2.2
 !
 address-family ipv4 unicast
  router-id 2.2.2.2
 exit-address-family
 !
 address-family ipv6 unicast
  router-id 2.2.2.2
 exit-address-family
!
interface GigabitEthernet0/1
 ip address 10.1.12.2 255.255.255.0
 ipv6 address 2001:db8:12::2/64
 ospfv3 100 ipv4 area 0
 ospfv3 100 ipv6 area 0
```

**【検証方法】**
```bash
R1# show ospfv3 neighbor
# IPv4 AF (Instance 64) および IPv6 AF (Instance 0) の両方で FULL ネイバーになっていることを確認
```

---

### Scenario 2: IPv6 アドレスなしリンク上での OSPFv3 IPv4 AF 確立
* **要件:** R1-R2 間の Gi0/2 には IPv4 アドレス (`10.1.23.0/24`) のみを定義し、明示的な IPv6 アドレスを付与せずに OSPFv3 IPv4 AF を確立させよ。

**【R1】**
```bash
router ospfv3 100
 address-family ipv4 unicast
  router-id 1.1.1.1
 exit-address-family
!
interface GigabitEthernet0/2
 ip address 10.1.23.1 255.255.255.0
 ipv6 enable
 ospfv3 100 ipv4 area 0
```

**【R2】**
```bash
router ospfv3 100
 address-family ipv4 unicast
  router-id 2.2.2.2
 exit-address-family
!
interface GigabitEthernet0/2
 ip address 10.1.23.2 255.255.255.0
 ipv6 enable
 ospfv3 100 ipv4 area 0
```

**【検証方法】**
```bash
R1# show ospfv3 ipv4 neighbor
# `fe80::` リンクローカル宛てに IPv4 AF (Instance 64) アジャセンシーが成立していることを確認
```

---

### Scenario 3: OSPFv3 AF モードでの Reference Bandwidth (10Gbps) 調整
* **要件:** OSPFv3 AF プロセス 100 において、IPv4 および IPv6 アドレスファミリー双方の Reference Bandwidth を 10,000 Mbps (10Gbps) に変更せよ。

**【R1 / R2 共通】**
```bash
router ospfv3 100
 address-family ipv4 unicast
  auto-cost reference-bandwidth 10000
 exit-address-family
 !
 address-family ipv6 unicast
  auto-cost reference-bandwidth 10000
 exit-address-family
```

**【検証方法】**
```bash
R1# show ospfv3 ipv4 interface GigabitEthernet0/1
# Reference bandwidth is 10000 Mbps を確認
```

---

### Scenario 4: OSPFv3 AF 配下での Passive-Interface Default 構成
* **要件:** OSPFv3 IPv4 AF においてすべてのポートをデフォルト Passive 化し、Gi0/1 のみ活性化させよ。

**【R1】**
```bash
router ospfv3 100
 address-family ipv4 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/1
 exit-address-family
```

**【検証方法】**
```bash
R1# show ospfv3 ipv4 interface
# Gi0/1 以外が Passive と表示されることを確認
```

---

### Scenario 5: VRF-Aware OSPFv3 IPv4 AF 構成 (Multi-Tenant)
* **要件:** VRF `RED` 配下の Gi0/3 (192.168.30.0/24) で OSPFv3 IPv4 AF を構成せよ。

**【R1】**
```bash
vrf definition RED
 rd 100:1
 address-family ipv4
exit-vrf
!
interface GigabitEthernet0/3
 vrf forwarding RED
 ip address 192.168.30.1 255.255.255.0
 ipv6 enable
 ospfv3 100 ipv4 area 1 vrf RED
!
router ospfv3 100
 address-family ipv4 unicast vrf RED
  router-id 10.10.10.10
 exit-address-family
```

**【検証方法】**
```bash
R1# show ospfv3 vrf RED neighbor
```

---

### Scenario 6: OSPFv3 AF での静的ルート (Static) の再配送
* **要件:** R1 上の Static デフォルトルート (`ip route 0.0.0.0 0.0.0.0 Null0`) を OSPFv3 IPv4 AF へ Type-2 外部経路として再配送せよ。

**【R1】**
```bash
ip route 0.0.0.0 0.0.0.0 Null0
!
router ospfv3 100
 address-family ipv4 unicast
  redistribute static subnets
 exit-address-family
```

**【検証方法】**
```bash
R1# show ospfv3 ipv4 database external
```

---

### Scenario 7: Instance ID のカスタム変更 (Instance 70)
* **要件:** R1-R2 間の Gi0/1 において、OSPFv3 IPv4 AF の Instance ID をデフォルトの `64` から `70` へ変更せよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ospfv3 100 ipv4 area 0 instance 70
```

**【検証方法】**
```bash
R1# show ospfv3 interface GigabitEthernet0/1
# Instance ID 70 で動作していることを確認
```

---

### Scenario 8: OSPFv3 AF と BFD の統合
* **要件:** Gi0/1 上の OSPFv3 AF（IPv4 / IPv6）に対して Single-hop BFD を有効化せよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ospfv3 bfd
```

**【検証方法】**
```bash
R1# show bfd neighbors client ospfv3
```

---

### Scenario 9: OSPFv3 AF でのエリア間要約 (Summarization)
* **要件:** ABR である R1 上で、Area 1 由来の IPv4 プレフィックス `10.1.0.0/24` ～ `10.1.3.0/24` を `10.1.0.0/22` に要約して Area 0 へ注入せよ。

**【R1 (ABR)】**
```bash
router ospfv3 100
 address-family ipv4 unicast
  area 1 range 10.1.0.0 255.255.252.0
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip route ospfv3 | include 10.1.0.0
```

---

### Scenario 10: トラブルシューティング（`ipv6 enable` 欠落の復旧）
* **要件:** R1 (Gi0/1) で `ospfv3 100 ipv4 area 0` を投入したにも関わらずネイバーが形成されない障害が発生しています。原因を特定し修正せよ。

**【障害コンフィグ (R1)】**
```bash
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ospfv3 100 ipv4 area 0
# (ipv6 enable が欠落している)
```

**【修正コンフィグ (R1)】**
```bash
interface GigabitEthernet0/1
 ipv6 enable
```

**【検証方法】**
```bash
R1# show ospfv3 ipv4 neighbor
# Neighbor 状態が FULL へ推移することを確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】IPv4 AF 設定時のネイバー不成立原因の解析
**問題:** 
ルータ R1 と R2 の間で OSPFv3 Address Family モードを使用した IPv4 ルーティング（プロセス ID 100）を構成しました。両ルータの Gi0/1 インターフェイスには `ip address 10.1.12.x 255.255.255.0` および `ospfv3 100 ipv4 area 0` が投入されています。しかし、`show ospfv3 neighbor` を実行してもネイバーが一切表示されず、Ping も通りません。`show logging` を確認すると、制御パケットが一切送出されていないことが判明しました。この障害の根本原因と修正用コマンドを述べてください。

**解答・解説:**
* **根本原因:** 
  OSPFv3 Address Family は、たとえ IPv4 アドレスファミリー（`address-family ipv4 unicast`）の経路情報を運ぶ場合であっても、制御パケット（Hello等）は常に **IPv6 リンクローカルアドレス（`fe80::`）を送信元として送受信** します。該当インターフェイス上に IPv6 アドレスも `ipv6 enable` も設定されていないため、IPv6 リンクローカルアドレスが生成されず、OSPFv3 エンジンが Hello パケットを生成・送出できないことが原因です。
* **修正コマンド:**
  ```bash
  R1(config)# interface GigabitEthernet0/1
  R1(config-if)# ipv6 enable
  ```

---

### 2. 【コンフィグ読解 / Design】Instance ID マッピングの検証
**問題:** 
以下のコンフィグが投入された R1 と R2 の間で、OSPFv3 IPv4 ネイバーは成立するでしょうか？技術的根拠とともに回答してください。
* R1: `interface Gi0/1` ➔ `ospfv3 100 ipv4 area 0`
* R2: `interface Gi0/1` ➔ `ospfv3 100 ipv4 area 0 instance 64`

**解答・解説:**
* **回答:** **正常に成立します。**
* **技術的根拠:** 
  RFC 5838 (OSPFv3 Address Family) の標準仕様において、IPv4 Unicast Address Family に対するデフォルトの Instance ID は **`64`** と規定されています。R1 で `instance` オプションを省略した場合、IOS-XE は自動的にデフォルト値である Instance ID `64` を Hello パケットヘッダーにセットして送信します。R2 側は手動で `instance 64` を明示指定していますが、値自体は同じ `64` であるため、パケットのミスマッチは発生せず正常に FULL アジャセンシーが成立します。

---

## 🔗 参考リソース

* [Cisco Systems: OSPFv3 Address Family Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-3s/iro-xe-3s-book.html)
* [RFC 5838: Support of Address Families in OSPFv3](https://datatracker.ietf.org/doc/html/rfc5838)
* [Cisco Live: BRKRST-2337 - OSPFv3 Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **Instance ID マッピングまとめ:**
  * `0 - 31`: IPv6 Unicast (デフォルト: 0)
  * `32 - 63`: IPv6 Multicast
  * `64 - 95`: IPv4 Unicast (デフォルト: 64)
  * `96 - 127`: IPv4 Multicast
  * `128 - 255`: VRF / Reserved


## 参考リソースリンク

### Configurationガイド
*   [OSPFv3 Address Family Support Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book/ip6-route-ospfv3.html)。
*   [Configuring VRF-lite with OSPFv3](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/15-mt/iro-15-mt-book/ip6-route-ospfv3-vrf.html)。

### CiscoLive (動画・スライド)
*   [DGTL-BRKRST-2337: OSPF Deployment in Modern Networks (IPv4 AF 深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)。
*   [BRKRST-3320: Troubleshooting Routing Protocols (OSPFv3 隣接関係のトラブル)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)。

### テクニカルドキュメント・設定例
*   [IPv6 Routing OSPFv3 (Cisco Support Document)](https://www.cisco.com/c/en/us/support/docs/ip/ip-version-6-ipv6/113328-ipv6-static-00.html)。
*   [Implementing OSPFv3 with Multiple Address Families](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3-af.html)。

---


## 📝 補足
- この学習メモは、OSPFv3 AF supportが「単なるIPv6のプロトコル」ではなく、「次世代の統合ルーティング基盤」であることを強調しています。特にIPv6リンクローカルアドレスに依存したIPv4隣接関係の形成は、CCIEラボ試験において非常に誤解しやすく、かつ強力なトラブルシューティングのポイントとなるため、実機（EVE-NG等）での徹底した確認が推奨されます。

