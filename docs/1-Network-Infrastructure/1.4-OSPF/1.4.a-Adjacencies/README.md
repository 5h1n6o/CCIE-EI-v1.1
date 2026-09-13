---
layout: default
title: 1.4.a-Adjacencies
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.4.a Adjacencies (OSPFv2 and OSPFv3)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP の1つである **OSPF (v2およびv3) ネイバーアジャセンシー (Adjacencies)** の成立条件、ステート遷移、タイマー動作、ネットワークタイプ別の動向、MTU不一致トラップ、認証、トラブルシューティング、および高度なラボ実装シナリオについて、Cisco IOS-XE 17.x の実装基準に完全準拠して解説します。

---

## 📘 概要

**OSPF (Open Shortest Path First)** は、リンクステート型ルーティングプロトコルであり、ネットワーク内のルータ間で Link State Advertisement (LSA) を交換し、全ルータで同一の Link State Database (LSDB) を保持することで、Dijkstra の SPF (Shortest Path First) アルゴリズムを用いてループフリーな最短経路を計算します。

ルータ間で LSDB を同期するためには、まず対向ルータとの間で **「ネイバー関係 (Neighbor)」** を認識し、特定の条件を満たした上で **「アジャセンシー関係 (Adjacency)」** を形成して LSA の完全な同期状態 (FULL State) に達する必要があります。

### 主な利用目的と適用シーン
1. **動的リンクステートトポロジーの構築:** エンタープライズの Campus、Data Center、WAN、SD-Access アンダーレイ網において、物理/論理リンクの可達性情報を自動検知・伝搬する。
2. **高速コンバージエンス:** リンク障害発生時、隣接ルータへ即座に Link State Update (LSU) をフラッディングし、ミリ秒〜秒単位で全ルータの LSDB を再同期させる。
3. **マルチテナント・マルチプロトコル（Dual-Stack / VRF）対応:** IPv4 (OSPFv2) および IPv6 / Address Family (OSPFv3) を用いて、VRF ごとに独立した LSDB とアジャセンシーを分離保持する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | リンクステート型プロトコル。IP プロトコル番号 89 を使用。マルチキャスト (224.0.0.5 / 224.0.0.6, FF02::5 / FF02::6) またはユニキャストで制御パケットを交換。 |
| **用途** | エンタープライズ内部網 (Campus / DC / SD-Access アンダーレイ等) の主軸 IGP。 |
| **メリット** | エリア分割 (Hierarchical Design) によるスケール性能、高速なコンバージエンス、標準規格 (RFC) 準拠によるマルチベンダー親和性。 |
| **デメリット** | EIGRP 等に比べ CPU / メモリ消費量が大きく、エリア設計やタイマー・ネットワークタイプの整合性に厳格な設定が必要。 |
| **アジャセンシー成立の絶対条件** | ① **Area ID** の一致 <br> ② **Hello / Dead Timer** の一致 <br> ③ **Area Type Flags** (Stub / NSSA / Standard) の一致 <br> ④ **IPv4 Primary Subnet / Mask** の一致 (OSPFv2 のみ) <br> ⑤ **Authentication** のパラメータ・キー一致 <br> ⑥ **Router ID** の重複なし (同一エリア内) <br> ⑦ **MTU** の一致 (アジャセンシー初期形成時の ExStart/Exchange ハング防止) |
| **設計上の注意点** | ネットワークタイプ (Broadcast, Point-to-Point, Point-to-Multipoint, NBMA) の違いにより、DR/BDR 選出の有無やタイマーデフォルト値が変化する。 |

---

## 🏗 動作原理

OSPF ネイバーアジャセンシーの形成は、8つの状態ステート (Neighbor States) を順番に遷移しながら進行します。

```text
[ Router A ]                                                 [ Router B ]
     │                                                            │
     │────────── 1. Hello (Multicast: 224.0.0.5) ────────────────►│ (Init State: Aを受信)
     │◄───────── 2. Hello (Multicast: 224.0.0.5) ─────────────────│ (2-Way State: 相互認識)
     │                                                            │
     │============================================================│
     │   [ DR / BDR Election ] (Broadcast / NBMA 網の場合)         │
     │============================================================│
     │                                                            │
     │────────── 3. DBD (Empty, Seq=x, Init/More/Master) ───────►│ (ExStart State: Master選出)
     │◄───────── 4. DBD (Empty, Seq=y, Init/More/Master) ─────────│
     │                                                            │
     │────────── 5. DBD (Summary LSA Headers, Seq=y) ────────────►│ (Exchange State: LSDB要約交換)
     │◄───────── 6. DBD (Summary LSA Headers, Seq=y+1) ───────────│
     │                                                            │
     │────────── 7. Link State Request (LSR) ────────────────────►│ (Loading State: 不足LSA要求)
     │◄───────── 8. Link State Update (LSU) ──────────────────────│
     │────────── 9. Link State Ack (LSAck) ──────────────────────►│
     │                                                            │
     │============================================================│
     │                 [ FULL State (LSDB Synchronized) ]         │
     │============================================================│
```

---

## ⚙ 動作シーケンス

1. **Down State:**
   OSPF プロセスが開始された初期状態。制御パケットの送受信はありません。
2. **Init State:**
   インターフェイスから Hello パケットを受信した状態。ただし、受信した Hello パケットの「Active Neighbor リスト」に自機の Router ID が含まれていない段階です。
3. **2-Way State:**
   対向からの Hello パケット内の「Active Neighbor リスト」に自機の Router ID が確認され、双方向通信が確立した状態。
   * **ポイント:** Broadcast / NBMA 網では、この段階で **DR (Designated Router) / BDR (Backup Designated Router)** の選出が行われます。DROTHER 同士のルータ間はアジャセンシーを拡張せず、**2WAY/DROTHER** ステートのまま留まります（フル同期しません）。
4. **ExStart State:**
   アジャセンシー（フル同期）を形成するルータ間で、どちらが DBD (Database Description) パケットの送受信を主導するか決定する **Master / Slave** のネゴシエーションを行います。高い Router ID を持つルータが Master となります。
   * **最重要トラップ:** この段階で **L3 MTU のチェック** が行われます。MTU が不一致の場合、パケットがドロップされるか否定され、**ExStart または Exchange ステートで永久にハング** します。
5. **Exchange State:**
   Master / Slave の関係が決定した後、互いの LSDB の要約ヘッダー情報が含まれた DBD パケットを交換し、自機に不足している LSA や古い LSA を識別します。
6. **Loading State:**
   DBD 交換で判明した不足している LSA の詳細を相手に要求するため、**LSR (Link State Request)** を送信し、相手から **LSU (Link State Update)** を受信します。受信した LSA に対し **LSAck (Link State Acknowledgment)** を返します。
7. **FULL State:**
   すべての LSR に対する LSU が受信・適用され、両ルータ間の LSDB が 100% 完全同期された状態。アジャセンシー形成完了です。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、OSPF アジャセンシー障害のトラブルシューティングや変則要件への対応は配点の高いセクションです。

### 1. 試験で狙われやすい「ネイバー不成立・ハング要因」完全リスト

| 不成立・障害現象 | 根本原因 | ログ / show コマンドでの確認 | 対策・修正方法 |
| :--- | :--- | :--- | :--- |
| **ネイバーが Init 止まり** | 一方のルータからの Hello が ACL / CoPP でドロップされているか、ユニキャスト/マルチキャストの到達性がない。 | `show ip ospf neighbor` でステートが `INIT/-` | 双方のアクセスリスト、CoPP、レイヤ2 VLAN タグ、UDP/IP プロトコル 89 の透過を確認。 |
| **ExStart / Exchange ステートで永久ハング** | **対向ルータ間で L3 MTU が不一致。**（大きい MTU 側の DBD パケットを小さい MTU 側が破棄） | `show ip ospf neighbor` でステートが `EXSTART/DR` または `EXCHANGE/-` | 双方のインターフェイス MTU を揃えるか、一時的に <code>ip ospf mtu-ignore</code> / <code>ospfv3 mtu-ignore</code> を設定する。 |
| **2-Way ステートで停止 (アジャセンシーに進まない)** | 送信元の両ルータが共に DROTHER であり、仕様通りの正常動作（障害ではない）。 | `show ip ospf neighbor` でステートが `2WAY/DROTHER` | DR/BDR 以外の DROTHER 同士は FULL にならず 2-Way で正常。アジャセンシーを組ませたい場合は Priority を上げる。 |
| **Hello が無視される (ネイバーが表れない)** | 1. **Hello / Dead タイマーの不一致** <br>2. **Area ID の不一致** <br>3. **Area Flag (Stub/NSSA) の不一致** <br>4. **Authentication Key / Algorithm 不一致** | `debug ip ospf hello` にて <br>`Mismatched hello parameters` や `Dead timer mismatch` が出力される | 双方のタイマー、エリア番号、エリアタイプ、認証情報を完全に一致させる。 |
| **Subnet Mask Mismatch (OSPFv2)** | OSPFv2 の Broadcast / NBMA 網において、IP アドレスのサブネットマスク長（例: `/24` vs `/25`）が不一致。 | `debug ip ospf hello` にて <br>`Mismatched hello packet` / `bad Subnet Mask` | インターフェイスの IP アドレスおよびサブネットマスクを対向と完全に揃える。 |
| **Duplicate Router ID** | 同一エリア内で同一の Router ID が重複定義されている。 | `%OSPF-4-DUP_RTRID` ログが出力される | <code>router-id <UNIQUE_IP></code> で一意な ID を定義し、<code>clear ip ospf process</code> を実行する。 |

### 2. ネットワークタイプ (Network Types) ごとのアジャセンシー動作差

| ネットワークタイプ | デフォルトタイマー (Hello/Dead) | DR/BDR 選出 | ネイバー自動発見 | 設定コマンド例 |
| :--- | :--- | :--- | :--- | :--- |
| **Broadcast** | 10秒 / 40秒 | **あり** | **あり** (Multicast 224.0.0.5) | `ip ospf network broadcast` |
| **Point-to-Point** | 10秒 / 40秒 | **なし** (直接アジャセンシー) | **あり** (Multicast 224.0.0.5) | `ip ospf network point-to-point` |
| **Point-to-Multipoint** | 30秒 / 120秒 | **なし** | **あり** (Multicast 224.0.0.5) | `ip ospf network point-to-multipoint` |
| **Non-Broadcast (NBMA)** | 30秒 / 120秒 | **あり** | **なし (要 `neighbor` コマンド)** | `ip ospf network non-broadcast` |

---

## 🛠 設定方法

### 1. OSPFv2 (IPv4) 基本ネイバー設定 (インターフェイスモード指定)

```bash
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ip ospf 1 area 0
 ip ospf network point-to-point
 ip ospf hello-interval 5
 ip ospf dead-interval 20
!
router ospf 1
 router-id 1.1.1.1
 passive-interface default
 no passive-interface GigabitEthernet0/1
```

### 2. OSPFv3 (IPv6 / Address Family Mode) 双方向統合設定

```bash
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
 ospfv3 100 ipv6 area 0
 ospfv3 100 network point-to-point
!
router ospfv3 100
 router-id 1.1.1.1
 !
 address-family ipv6 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/1
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPFv2 ネイバーテーブル（State, DR/BDR 役割, Address, Interface 等）の確認** | <code>show ip ospf neighbor</code> / <code>show ip ospf neighbor detail</code> |
| **OSPFv3 (IPv6) ネイバーテーブルの確認** | <code>show ospfv3 neighbor</code> / <code>show ipv6 ospf neighbor</code> |
| **インターフェイスごとの Network Type, Timer, DR/BDR, MTU, Passive 状態の確認** | <code>show ip ospf interface <int></code> / <code>show ospfv3 interface <int></code> |
| **Hello パケット不一致・ミスマッチイベントのリアルタイムデバッグ** | <code>debug ip ospf hello</code> / <code>debug ospfv3 hello</code> |
| **ExStart / Exchange / DBD 交換処理および MTU チェックのデバッグ** | <code>debug ip ospf adj</code> / <code>debug ospfv3 adj</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`show ip ospf neighbor` でネイバーが全く表示されない。** | 1. ポートが `passive-interface` になっている。<br>2. プロセス ID または Area が一致していない。<br>3. ACL で IP プロトコル 89 が遮断されている。 | `show ip ospf interface`<br>`show ip protocols` | 1. `no passive-interface <int>` を設定。<br>2. エリア指定と IP 割り当ての再確認。<br>3. ACL に `permit ospf any any` を追加。 |
| **ネイバーが `EXSTART` または `EXCHANGE` で一時停止・ループを繰り返す。** | **対向ポートとの L3 MTU 不一致。** 一方のルータが送信した大きな DBD パケットを他方が受容できずドロップ。 | `show ip ospf interface`<br>`debug ip ospf adj` | インターフェイスの MTU を同一に揃える（例: `mtu 1500`）。設定変更が不可能な場合は `ip ospf mtu-ignore` を双方に投入する。 |
| **OSPFv3 ネイバーが `DOWN` のまま一切形成されない。** | 該当インターフェイスで IPv6 が無効化されているか、Link-Local アドレス（`fe80::`）が生成されていない。 | `show ipv6 interface brief` | インターフェイス配下で `ipv6 enable` または IPv6 アドレスを構成し、Link-Local を確定させる。 |
| **NBMA 網でネイバーが `DOWN` のまま遷移しない。** | ネットワークタイプが `non-broadcast` であり、マルチキャストが使用できないにもかかわらず静的 `neighbor` 指定がない。 | `show ip ospf interface` | `router ospf` モード配下で `neighbor <IP>` を手動定義するか、タイプを `point-to-multipoint` に変更する。 |

---

## ⚠ 制限事項

1. **OSPFv2 サブネットマスクチェック制限:**
   * OSPFv2 では Broadcast および NBMA 網において、対向ルータ間の Primary IP サブネットマスクが一致しない場合、Hello パケットが破棄されます（Point-to-Point 網では例外的にマスク不一致でもネイバー形成可能ですが、RIB 掲載で不具合が生じる可能性があります）。
2. **OSPFv3 における Link-Local アドレス依存:**
   * OSPFv3 は、グローバル Unicast IPv6 アドレスではなく、**必ず Link-Local アドレス (`fe80::`) を Next-Hop およびネイバー識別として使用**します。Link-Local アドレスが手動削除されたり不具合があるとネイバーが切断されます。

---

## 🔄 他技術との関連

* **L3 MTU (1.2.k):**
  DBD パケット交換時の MTU チェック（ExStart ハングの原因）と直結します。
* **BFD (1.2.j):**
  `ip ospf bfd` または `bfd template` をバインドすることで、Hello タイマー（最速 1 秒）よりも遥かに高速なミリ秒単位でネイバーダウンを検出します。
* **Routing Protocol Authentication (1.2.i):**
  OSPFv2 では RFC 5709 HMAC-SHA-256 認証、OSPFv3 では IPsec AH/ESP または RFC 7166 Trailer Authentication を用いてネイバー間の真正性を保護します。

---

## 🧩 比較表

### OSPFv2 vs OSPFv3 アジャセンシー制御の比較

| 比較項目 | OSPFv2 (IPv4) | OSPFv3 (IPv6 / AF Mode) |
| :--- | :--- | :--- |
| **制御パケット宛先** | 224.0.0.5 (AllSPF) / 224.0.0.6 (DR) | FF02::5 (AllSPF) / FF02::6 (DR) |
| **ネイバーアドレス識別** | IPv4 Primary IP アドレス | **IPv6 Link-Local アドレス (`fe80::`)** |
| **サブネットマスクチェック** | **あり** (Broadcast / NBMA 網で必須) | **なし** (L3 プレフィックスから完全に独立) |
| **Router ID** | 32 ビット IPv4 アドレス形式 | 32 ビット IPv4 アドレス形式 (IPv6 網でも必須手動定義) |
| **認証方式** | Plaintext, MD5, HMAC-SHA-256 | IPsec (AH/ESP) または Trailer Authentication (RFC 7166) |

---

## 💡 ベストプラクティス

1. **Point-to-Point リンクでの `network point-to-point` 明示指定:**
   イーサネット直結リンク（/30 や /31、/64）では、不要な DR/BDR 選出処理（40 秒のウェイティングタイム）をスキップするため、必ず `ip ospf network point-to-point` を明示指定する。
2. **`passive-interface default` の徹底:**
   セキュリティ向上とコントロールプレーン保護のため、全ポートをデフォルト Passive 化し、ネイバーを形成する対向ポートのみを個別開放する。
3. **Router ID の固定設定:**
   Loopback インターフェイスの IP 変動に依存しないよう、`router-id 1.1.1.1` のように手動で一意な ID を固定的コンフィグに含める。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: OSPFv2 Single-Area Basic Adjacency
* **要件:** R1 (Gi0/1: 10.1.12.1/24) と R2 (Gi0/1: 10.1.12.2/24) 間で Area 0 の OSPFv2 アジャセンシーを確立せよ。

**【R1】**
```bash
router ospf 1
 router-id 1.1.1.1
 passive-interface default
 no passive-interface GigabitEthernet0/1
!
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ip ospf 1 area 0
```

**【R2】**
```bash
router ospf 1
 router-id 2.2.2.2
 passive-interface default
 no passive-interface GigabitEthernet0/1
!
interface GigabitEthernet0/1
 ip address 10.1.12.2 255.255.255.0
 ip ospf 1 area 0
```

**【検証方法】**
```bash
R1# show ip ospf neighbor
# R2 の Router ID (2.2.2.2) が FULL ステートで表示されることを確認
```

---

### Scenario 2: OSPFv3 IPv6 Basic Adjacency (Link-Local)
* **要件:** R1 (Gi0/1: `2001:db8:12::1/64`) と R2 (Gi0/1: `2001:db8:12::2/64`) 間で OSPFv3 IPv6 アジャセンシーを確立せよ。

**【R1】**
```bash
router ospfv3 100
 router-id 1.1.1.1
 !
 address-family ipv6 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/1
 exit-address-family
!
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
 ospfv3 100 ipv6 area 0
```

**【R2】**
```bash
router ospfv3 100
 router-id 2.2.2.2
 !
 address-family ipv6 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/1
 exit-address-family
!
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::2/64
 ospfv3 100 ipv6 area 0
```

**【検証方法】**
```bash
R1# show ospfv3 neighbor
```

---

### Scenario 3: Network Type `point-to-point` 設定による DR 選出回避
* **要件:** R1-R2 間の Gi0/1 イーサネットリンクにおいて DR/BDR 選出を無効化し、即座に Point-to-Point アジャセンシーを形成させよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf network point-to-point
```

**【検証方法】**
```bash
R1# show ip ospf neighbor
# State が 「FULL/-」 と表示され、DR/BDR の表記が消えていることを確認
```

---

### Scenario 4: MTU 不一致環境における `ip ospf mtu-ignore` 解消
* **要件:** R1 (MTU 1500) と R2 (MTU 1400) 間で発生している ExStart ハングを、MTU 値を変更せずに解消せよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf mtu-ignore
```

**【検証方法】**
```bash
R1# show ip ospf neighbor
# ネイバーが FULL ステートへ遷移することを確認
```

---

### Scenario 5: Hello / Dead タイマーのカスタムチューニング (Hello 2s / Dead 8s)
* **要件:** Gi0/1 上の OSPFv2 タイマーを Hello 2 秒、Dead 8 秒に変更せよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf hello-interval 2
 ip ospf dead-interval 8
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# Hello 2, Dead 8 と出力されることを確認
```

---

### Scenario 6: Non-Broadcast (NBMA) 網における静的 `neighbor` 設定
* **要件:** ネットワークタイプが `non-broadcast` の環境で、R1 から R2 (10.1.12.2) へ対してユニキャストネイバーを定義せよ。

**【R1】**
```bash
interface GigabitEthernet0/1
 ip ospf network non-broadcast
!
router ospf 1
 neighbor 10.1.12.2 priority 1
```

**【検証方法】**
```bash
R1# show ip ospf neighbor
```

---

### Scenario 7: OSPFv2 HMAC-SHA-256 (RFC 5709) 認証設定
* **要件:** R1-R2 間の Gi0/1 上で HMAC-SHA-256 認証（Key ID 1, パスワード `CCIE_OSPF_KEY`）を構成せよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 CCIE_OSPF_KEY
```

**【検証方法】**
```bash
R1# show ip ospf interface GigabitEthernet0/1
# Message digest authentication enabled を確認
```

---

### Scenario 8: BFD 統合による超高速障害検知
* **要件:** R1-R2 間の OSPFv2 セッションに BFD をバインドせよ。

**【R1 / R2 共通】**
```bash
interface GigabitEthernet0/1
 ip ospf bfd
```

**【検証方法】**
```bash
R1# show bfd neighbors client ospf
```

---

### Scenario 9: VRF-Aware OSPFv2 ネイバー確立 (Multi-Tenant)
* **要件:** VRF `RED` 内の Gi0/2 で OSPFv2 アジャセンシーを形成せよ。

**【R1】**
```bash
vrf definition RED
 rd 100:1
 address-family ipv4
exit-vrf
!
interface GigabitEthernet0/2
 vrf forwarding RED
 ip address 10.1.20.1 255.255.255.0
 ip ospf 100 area 0
!
router ospf 100 vrf RED
 router-id 10.1.20.1
```

**【検証方法】**
```bash
R1# show ip ospf vrf RED neighbor
```

---

### Scenario 10: OSPFv3 Address Family Support (IPv4 AF)
* **要件:** OSPFv3 プロセスにおいて、IPv4 アドレスファミリーを用いて IPv4 ルーティングネイバーを形成せよ。

**【R1 / R2 共通】**
```bash
router ospfv3 10
 router-id 1.1.1.1
 !
 address-family ipv4 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/1
 exit-address-family
!
interface GigabitEthernet0/1
 ospfv3 10 ipv4 area 0
```

**【検証方法】**
```bash
R1# show ospfv3 10 ipv4 neighbor
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】ExStart ハングの特定と修復
**問題:** 
R1 と R2 の間で OSPFv2 を構成しましたが、`show ip ospf neighbor` を実行すると R2 のステートが `EXSTART/DR` のまま変化せず、一向に `FULL` に遷移しません。`show ip ospf interface` を確認したところ、R1 側は MTU 1500、R2 側は Tunnel 経由のため MTU 1476 になっていました。リンクの物理 MTU を変更できない制約下で、最短でアジャセンシーを正常化するコマンドを記述してください。

**解答・解説:**
* **回答コマンド:** 
  ```bash
  R1(config)# interface GigabitEthernet0/1
  R1(config-if)# ip ospf mtu-ignore
  
  R2(config)# interface Tunnel0
  R2(config-if)# ip ospf mtu-ignore
  ```
* **解説:** OSPF では DBD パケット交換時（ExStart/Exchange ステート）にインターフェイス MTU 値の比較が行われます。送信側よりも受信側の MTU が小さい場合、大きなパケットが破棄されて要求応答が完了せず ExStart ステートでハングします。`ip ospf mtu-ignore` を適用することで、DBD ヘッダー内の MTU チェック処理を強制バイパスし、即座に FULL ステートへ遷移させることができます。

---

### 2. 【コンフィグ読解】OSPFv3 ネイバー不成立の原因特定
**問題:** 
以下のコンフィグを投入した R1 において、対向ルータとの間で OSPFv3 (IPv6) ネイバーが全く検出されません。設定上の決定的な欠陥を指摘してください。
```text
router ospfv3 1
 router-id 1.1.1.1
!
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ospfv3 1 ipv6 area 0
```

**解答・解説:**
* **指摘:** インターフェイス `GigabitEthernet0/1` において IPv6 が有効化されておらず、**Link-Local アドレス (`fe80::`) が存在していません。**
* **解説:** OSPFv3 は制御パケットの交換およびネクストホップの指定に IPv6 Link-Local アドレスを使用します。インターフェイス上に `ipv6 enable` または `ipv6 address 2001:db8::1/64` 等の指定がない場合、Link-Local アドレスが自動生成されず、OSPFv3 パケットの送受信処理自体が起動しません。

---

## 🔗 参考リソース

* [Cisco Systems: OSPF Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/routers/ios/iproute_ospf/configuration/17-x/ir-17-x-book.html)
* [Cisco Command Reference: OSPF Commands](https://www.cisco.com/c/en/us/td/docs/routers/ios/iproute_ospf/command/iro-cr-book.html)
* [Cisco Live: BRKRST-2337 - OSPF Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **OSPF ネイバー状態コードの見方:**
  * `FULL/DR`: 対向ルータが DR であり、自機とフル同期完了。
  * `FULL/BDR`: 対向ルータが BDR であり、自機とフル同期完了。
  * `FULL/DROTHER`: 対向ルータが DROTHER であり、自機（DR または BDR）とフル同期完了。
  * `2WAY/DROTHER`: 双方とも DROTHER であり、仕様通り 2-Way ステートで同期を制限・維持している正常状態。


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKENS-2337: OSPF Deployment in Modern Networks](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2337)
*   [BRKRST-3320: Troubleshooting Routing Protocols (OSPF Adjacency Deep Dive)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### Configurationガイド
*   [OSPFv2 Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html)
*   [OSPFv3 Address Family Support (Cisco Support)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html)

### テクニカルドキュメント・設定例
*   [OSPF Neighbor States and Troubleshooting (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13699-29.html)
*   [Understanding OSPF Network Types (Broadcast, P2P, NBMA)](https://www.cisco.com/c/ja_jp/support/docs/ip/open-shortest-path-first-ospf/13697-14.html)

---

## 📝 補足
- この学習メモは、OSPFの隣接関係形成というルーティングの「基盤」を、CCIE EI試験で求められる深さまで網羅しています。特にステート遷移中の特定の箇所で止まる原因（MTU, Authentication, Subnet mismatch等）を迅速に特定できることが、実技試験での時間短縮と確実な得点につながります。


