---
layout: default
title: 1.3.a-Adjacencies
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.3.a EIGRP Adjacencies (EIGRP Neighbor Adjacency)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP の1つである **EIGRP ネイバーアジャセンシー (EIGRP Neighbor Adjacency)** の確立メカニズム、判定条件、タイマー動作、認証、トラブルシューティング、および高度なラボ実装シナリオについて、Cisco IOS-XE 17.x の実装基準に完全準拠して解説します。

---

## 📘 概要

EIGRP（Enhanced Interior Gateway Routing Protocol）は、ルータ間でトポロジー情報を交換してルータ自身のルーティングテーブルを構築する高度なディスタンスベクター型ルーティングプロトコルです。

EIGRP がルーティング情報（Update/Query/Reply）を信頼性高く交換するためには、まず直接接続（またはトンネル接続）された対向ルータとの間で **「ネイバーアジャセンシー（隣接関係）」** を確立・維持する必要があります。

### 主な利用目的と適用シーン
1. **動的ルーティング基盤の自動ネイバー確立:** マルチアクセス網、ポイントツーポイント網、DMVPN等のオーバーレイ網において、対向ルータを自動検知してネイバーシップを構築する。
2. **高速障害検知（Sub-Second Detection）:** Keepalive（Hello/Holdタイマー）および BFD（Bidirectional Forwarding Detection）と連携し、リンク障害発生時に即座にネイバーを Down 状態に推移させて DUAL 再計算を起動する。
3. **セキュリティとトラフィック分離:** 特定のインターフェイスでの Hello 送受信制限（`passive-interface`）、静的ユニキャストネイバー指定、および暗号化認証（MD5/HMAC-SHA-256）による不正ルータの参加防止。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | RTP（Reliable Transport Protocol：IP プロトコル番号 88）を使用した信頼性の高い制御パケット交換。マルチキャスト (`224.0.0.10` / `FF02::A`) またはユニキャストでネイバー形成。 |
| **用途** | エンタープライズ内部網（Campus / WAN / DMVPN / SD-WAN アンダーレイ等）における可達性情報の動的伝搬。 |
| **メリット** | 初期ネイバー確立後は変更差分のみを送信するため、ネットワーク帯域および CPU 負荷が極めて低い。コンバージエンス速度が非常に速い。 |
| **デメリット** | シスコ主導の標準化（RFC 7868）はあるもののマルチベンダー環境での採用例が少ない。NBMA 共有網での Split-Horizon や Hello 動作に設計上の配慮が必要。 |
| **成立要件** | ① AS 番号の一致 <br> ② Primary IP が同一サブネット内に存在 (IPv4) <br> ③ K 値 (K1〜K5/K6) の一致 <br> ④ 認証パラメータの一致 (暗号化キー/Key-Chain) |
| **成立に影響しない項目** | Hello / Hold タイマー値の不一致（非対称タイマーでもアジャセンシー維持可能）、同一 Router ID（直結ネイバー間であれば重複していてもネイバーは確立可能）。 |
| **設計上の注意点** | セカンダリ IP（Secondary IP）から送信された Hello パケットではネイバーが確立されない (`%EIGRP-3-NEIGHBORIGN` エラー)。 |

---

## 🏗 動作原理

EIGRP ネイバーアジャセンシーの確立と維持は、RTP（Reliable Transport Protocol）と Hello メカニズムによって制御されます。

```text
[ Router A ]                                       [ Router B ]
     │                                                  │
     │─── 1. Hello Packet (Multicast: 224.0.0.10) ─────►│ (Init State)
     │◄── 2. Hello Packet (Multicast: 224.0.0.10) ──────│ (Init State)
     │                                                  │
     │─── 3. Null Update (Unicast, Init-Bit Set) ──────►│ (Seq: A1)
     │◄── 4. ACK (Unicast, Ack: A1) ────────────────────│
     │                                                  │
     │◄── 5. Null Update (Unicast, Init-Bit Set) ───────│ (Seq: B1)
     │─── 6. ACK (Unicast, Ack: B1) ────────────────────►│
     │                                                  │
     │==================================================│
     │           [ Neighbor Adjacency Established ]     │
     │==================================================│
     │                                                  │
     │─── 7. Full Topology Update (Unicast) ───────────►│
     │◄── 8. ACK / Full Topology Update ────────────────│
```

---

## ⚙ 動作シーケンス

1. **Hello パケットの送受信 (Discovery Phase):**
   * インターフェイス上で EIGRP が有効化されると、マルチキャスト IP `224.0.0.10`（IPv6 の場合は `FF02::A`）宛てに Hello パケットを定期送出します。
   * 受信した対向ルータは、AS 番号、K 値、サブネット一致（IPv4）、認証情報を検証します。
2. **Init ビット付き Update パケットの送受信:**
   * 相互に条件が合致すると、対向ルータ情報がネイバーテーブルに追加されます。
   * 最初に互いのトポロジーテーブルを同期するため、`Init Bit` がアサートされた Unicast Update パケットを送出し、相手から ACK（Acknowledge）を受信します。
3. **フルアップデート（Full Update）の交換:**
   * 互いに認識しているアクティブな EIGRP プレフィックス情報（距離・メトリック構成要素）を Update パケットで送信し合い、DACK または個別の ACK で確認応答を行います。
4. **定常状態の維持 (Keepalive Phase):**
   * Hello タイマー間隔（通常 5秒 または 60秒）で Hello パケットを継続送信します。
   * Hold タイマー（通常 Hello の3倍：15秒 または 180秒）以内に Hello パケットを受信できなかった場合、ネイバーダウンと判定し、そのネイバー経由のルートをトポロジーテーブルから削除（または DUAL 再計算を開始）します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、EIGRP ネイバーアジャセンシーは以下の切り口で多角的に出題されます。

### 1. 必修の「ネイバー不成立要因」とトラブルシューティング
試験問題で「対向ルータと EIGRP アジャセンシーが確立しない原因を突き止め、修正せよ」という指示が出た場合、以下の優先順位でチェックします。

1. **K 値（K-values）の不一致:**
   * デフォルトは `K1=1, K2=0, K3=1, K4=0, K5=0, K6=0`。
   * どちらか一方のルータで `metric weights` や Named Mode の `metric version` が調整されていると、`K-value mismatch` エラーが発生しネイバーが即座に切断されます。
2. **IP サブネットの不一致（IPv4 Primary Subnet Mismatch）:**
   * EIGRP パケットは必ず **Primary IP アドレス** を送信元として送信されます。
   * 一方が `10.1.1.1/24`、他方が `10.1.2.2/24` のようにマスクミスで別サブネットになっていると、`show logging` に以下が出力されます。
     `%EIGRP-3-NEIGHBORIGN: Neighbor 10.1.2.2 not on common subnet for GigabitEthernet0/1`
3. **Passive-interface の誤バインド/漏れ:**
   * `passive-interface default` が設定されている環境で、明示的な `no passive-interface <interface>` が抜けている場合、Hello が送出されず静まり返ります。
4. **Unicast Neighbor (静的ネイバー) の片系設定:**
   * インターフェイス配下で `neighbor <IP> <interface>` を設定すると、**該当インターフェイスでのマルチキャスト送受信が一切無効化** されます。
   * 対向ルータ側でも同様に `neighbor` コマンドを設定しないと、対向側からのマルチキャスト Hello が無視され、`EIGRP: Ignore unicast Hello` やアジャセンシーの即時リセットが発生します。
5. **認証パラメータ（Authentication）のミスマッチ:**
   * Classic Mode と Named Mode 間での Key-Chain 名・Password・アルゴリズム（MD5 vs HMAC-SHA-256）の不一致。

### 2. タイマー不一致（Asymmetric Timers）の罠
* **重要挙動:** EIGRP では、**Hello タイマーおよび Hold タイマーが対向ルータ間で一致していなくてもネイバーアジャセンシーは正常に成立・維持されます。**
* **理由:** EIGRP の Hold Time は「自機が相手を待つ時間」ではなく、「自機がダウンしたとみなすまでに**相手に対して待ってほしい時間**」として、Hello パケット内の Hold Time フィールドに載せて通知されるためです。

### 3. Named Mode における AF-Interface 階層での設定読み取り
Classic Mode（`router eigrp 100`）と Named Mode（`router eigrp FABRIC` ➔ `address-family ipv4 autonomous-system 100`）の設定階層の完全な理解が不可欠です。

---

## 🛠 設定方法

### 1. EIGRP Named Mode における基本ネイバー設定 (IPv4 / IPv6)

```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet1/0/1
   no passive-interface
   hello-interval 3
   hold-time 9
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.12.0 0.0.0.255
  network 1.1.1.1 0.0.0.0
 exit-address-family
```

### 2. 静的ユニキャストネイバー (Unicast Neighbor) 設定

```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet1/0/2
   no passive-interface
   neighbor 10.1.23.2
  exit-af-interface
  !
  network 10.1.23.0 0.0.0.255
 exit-address-family
```

### 3. EIGRP Named Mode HMAC-SHA-256 認証設定

```bash
router eigrp CCIE_FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet1/0/1
   authentication mode hmac-sha-256 CISCO_SECRET_KEY
  exit-af-interface
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **EIGRP ネイバーテーブル（アジャセンシー状態、Hold Time、SRTT、RTO、Q Cnt 等）の確認** | <code>show ip eigrp neighbors</code> / <code>show eigrp address-family ipv4 neighbors</code> |
| **特定ネイバーの通信統計（送信/受信パケット数、再送回数、Prefix数など）の詳細監査** | <code>show ip eigrp neighbors detail</code> |
| **EIGRP プロセスが有効なインターフェイス一覧と Passive 状態の確認** | <code>show ip eigrp interfaces</code> / <code>show ip eigrp interfaces detail</code> |
| **K値、AS番号、Passive-interface 一覧、ディスタンス等のプロトコル全体のパラメータ確認** | <code>show ip protocols</code> |
| **Hello パケット、Update パケットの送受信イベントリアルタイムデバッグ** | <code>debug eigrp packets hello</code> / <code>debug ip eigrp</code> |
| **ネイバーアジャセンシーの形成・破棄イベント（Neighbor State Changes）のデバッグ** | <code>debug eigrp neighbors</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **ネイバーが `224.0.0.10` 経由で一切検出されず、アジャセンシーが形成されない。** | 1. 該当インターフェイスが `passive-interface` になっている。<br>2. ACL や CoPP で IP プロトコル 88 (EIGRP) または Multicast が拒否されている。 | `show ip eigrp interfaces`<br>`show ip protocols` | 1. `af-interface` 配下で `no passive-interface` を設定する。<br>2. ACL で `permit eigrp any any` を許可する。 |
| **`%EIGRP-3-NEIGHBORIGN` エラーがログに頻発し、ネイバーが確立できない。** | 送信元 Primary IP アドレスが対向ルータのサブネットと不一致（Secondary IP 間で接続されているか、IP マスク設定ミス）。 | `show ip interface brief`<br>`show logging` | インターフェイスの Primary IP アドレスおよびサブネットマスクを対向と同一セグメント（例: `/24` または `/30`）に正しく再設定する。 |
| **ネイバー状態が `UP` と `DOWN` (Retries Exceeded) を数秒おきに繰り返す（フラッピング）。** | 1. 物理リンクの片通信障害（Unidirectional Link）。<br>2. 一方のルータのみに `neighbor` (ユニキャスト) が設定され、マルチキャストとユニキャストが混在している。 | `show ip eigrp neighbors`<br>`show logging` | 1. UDLD や BFD を確認・交換する。<br>2. 両端のルータで統一して `neighbor` コマンドを設定するか、ユニキャスト指定を削除してマルチキャスト動作に戻す。 |
| **`K-value mismatch` がログに出力され、ネイバーが拒否される。** | 互いのルータで K 値（`K1`〜`K5`/`K6`）の設定が異なっている。一方のみが 64-bit Wide Metric / Classic Metric の変更や `metric weights` を投入している。 | `show ip protocols`<br>`show logging` | `metric weights` 設定を削除するか、両ルータで全く同じ K 値を定義する。 |

---

## ⚠ 制限事項

1. **Secondary IP 上でのネイバー確立不可:**
   * EIGRP は Secondary IP アドレスで構成されたネットワーク上ではネイバーアジャセンシーを形成できません。Hello パケットは必ず Primary IP アドレスを送信元として生成されます。
2. **静的ユニキャストネイバー設定時のマルチキャスト自動停止:**
   * インターフェイス上で `neighbor` コマンドを設定すると、そのポートでの EIGRP マルチキャスト送信および受信処理が即座に完全にシャットダウンします。

---

## 🔄 他技術との関連

* **BFD (Bidirectional Forwarding Detection):**
  EIGRP Hold Timer（最短 3 秒）よりも遥かに高速なサブ秒（ミリ秒単位）でリンク障害を検知し、即座に EIGRP ネイバーアジャセンシーを Down に落としてトポロジー再計算（DUAL）を起動します。
* **DMVPN (Dynamic Multipoint VPN):**
  Hub ルータ側で `no ip split-horizon eigrp <AS>` を設定しない場合、Spoke 間でのアジャセンシー確立やルート伝搬が阻止されます。
* **VRF-Lite:**
  VRF ごとに独立した EIGRP アジャセンシーとネイバーテーブルが管理されます（Named Mode の `address-family ipv4 vrf <NAME>` で定義）。

---

## 🧩 比較表

### EIGRP Classic Mode vs Named Mode アジャセンシー設定

| 比較項目 | Classic Mode (`router eigrp 100`) | Named Mode (`router eigrp FABRIC`) |
| :--- | :--- | :--- |
| **設定階層** | グローバルおよび個別インターフェイス (`ip hello-interval eigrp`) で分散定義 | `address-family` および `af-interface` モード内で一元定義 |
| **Passive Interface** | `passive-interface default` (グローバル) | `af-interface default` ➔ `passive-interface` |
| **認証方式** | MD5 Key-Chain のみサポート | MD5 Key-Chain および HMAC-SHA-256 (直接パスワード指定可能) |
| **IPv6 対応** | 別途 `ipv6 router eigrp <AS>` コマンドが必要 | 同一の EIGRP インスタンス内で Address-Family として統合設定 |

---

## 💡 ベストプラクティス

1. **`passive-interface default` の原則使用:**
   セキュリティとコントロールプレーン保護のため、すべてのインターフェイスをデフォルトで `passive-interface` に指定し、ネイバーを形成すべき明示的なインターフェイス（トランク/対向ルータ接続ポート）のみで `no passive-interface` を定義する。
2. **EIGRP Named Mode への完全統一:**
   Cisco IOS-XE 環境では Classic Mode を排除し、IPv4/IPv6/VRF/認証/タイマーを一元管理できる Named Mode を使用する。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの10個の設定シナリオです。

### Scenario 1: EIGRP Named Mode 基本ネイバー形成 (IPv4)
* **要件:** R1 (Gi0/1: 10.1.12.1/24) と R2 (Gi0/1: 10.1.12.2/24) 間で AS 100 の EIGRP Named Mode アジャセンシーを確立せよ。

**【R1】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.12.1 0.0.0.0
 exit-address-family
```

**【R2】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.12.2 0.0.0.0
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors
# R2 (10.1.12.2) が Gi0/1 上でネイバーとして認識されていることを確認
```

---

### Scenario 2: 高速タイマー (Hello 1s / Hold 3s) チューニング
* **要件:** R1-R2 間の Gi0/1 において、Hello タイマーを 1 秒、Hold タイマーを 3 秒に短縮せよ。

**【R1】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   hello-interval 1
   hold-time 3
  exit-af-interface
 exit-address-family
```

**【R2】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   hello-interval 1
   hold-time 3
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors detail
# Hold time が 3秒基準でカウントダウンしていることを確認
```

---

### Scenario 3: 静的ユニキャストネイバー (Unicast Neighbor) 設定
* **要件:** R1-R2 間でマルチキャストパケットを遮断するため、Gi0/1 上で静的ユニキャストネイバーを固定設定せよ。

**【R1】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   no passive-interface
   neighbor 10.1.12.2
  exit-af-interface
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

**【R2】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   no passive-interface
   neighbor 10.1.12.1
  exit-af-interface
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors detail
# 「Unicast peer」としてアジャセンシーが維持されていることを確認
```

---

### Scenario 4: EIGRP Named Mode HMAC-SHA-256 暗号化認証
* **要件:** R1-R2 間の Gi0/1 上で HMAC-SHA-256 認証（パスワード: `CCIE_PASSPHRASE`）を構成せよ。

**【R1】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   authentication mode hmac-sha-256 CCIE_PASSPHRASE
  exit-af-interface
 exit-address-family
```

**【R2】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   authentication mode hmac-sha-256 CCIE_PASSPHRASE
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors
# アジャセンシーが正常に UP していることを確認
```

---

### Scenario 5: EIGRPv6 (IPv6) Dual-Stack ネイバー確立
* **要件:** R1 (Gi0/1: `2001:db8:12::1/64`) と R2 (Gi0/1: `2001:db8:12::2/64`) 間で EIGRPv6 アジャセンシーを確立せよ。

**【R1】**
```bash
router eigrp FABRIC
 !
 address-family ipv6 unicast autonomous-system 100
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
 exit-address-family
!
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
```

**【R2】**
```bash
router eigrp FABRIC
 !
 address-family ipv6 unicast autonomous-system 100
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
 exit-address-family
!
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::2/64
```

**【検証方法】**
```bash
R1# show ipv6 eigrp neighbors
# 対向の Link-Local アドレス (fe80::) を宛先としてネイバーが成立していることを確認
```

---

### Scenario 6: BFD 統合によるミリ秒単位超高速障害検知
* **要件:** R1-R2 間の EIGRP アジャセンシーに対して BFD を有効化せよ。

**【R1】**
```bash
bfd-template single-hop BFD_EIGRP
 interval min-tx 50 min-rx 50 multiplier 3
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   bfd template BFD_EIGRP
  exit-af-interface
 exit-address-family
```

**【R2】**
```bash
bfd-template single-hop BFD_EIGRP
 interval min-tx 50 min-rx 50 multiplier 3
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   bfd template BFD_EIGRP
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show bfd neighbors client eigrp
# BFD セッションが State UP になっていることを確認
```

---

### Scenario 7: VRF-Aware EIGRP ネイバー確立 (Multi-Tenant)
* **要件:** VRF `TENANT_A` 内で R1 と R2 間の EIGRP アジャセンシーを形成せよ。

**【R1】**
```bash
vrf definition TENANT_A
 rd 100:1
 address-family ipv4
exit-vrf
!
interface GigabitEthernet0/2
 vrf forwarding TENANT_A
 ip address 10.1.200.1 255.255.255.0
!
router eigrp FABRIC
 !
 address-family ipv4 unicast vrf TENANT_A autonomous-system 200
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/2
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.200.1 0.0.0.0
 exit-address-family
```

**【R2】**
```bash
vrf definition TENANT_A
 rd 100:1
 address-family ipv4
exit-vrf
!
interface GigabitEthernet0/2
 vrf forwarding TENANT_A
 ip address 10.1.200.2 255.255.255.0
!
router eigrp FABRIC
 !
 address-family ipv4 unicast vrf TENANT_A autonomous-system 200
  !
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/2
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.200.2 0.0.0.0
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp vrf TENANT_A neighbors
```

---

### Scenario 8: DMVPN Hub スプリットホライズン無効化
* **要件:** DMVPN Hub ルータ (R1) の Tunnel1 インターフェイスで EIGRP スプリットホライズンを無効化せよ。

**【R1 (Hub)】**
```bash
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface Tunnel1
   no split-horizon
  exit-af-interface
  !
  network 172.16.1.0 0.0.0.255
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp interfaces detail Tunnel1
# 「Split-horizon is disabled」が出力に含まれることを確認
```

---

### Scenario 9: Key-Chain MD5 認証と無停止鍵ローテーション
* **要件:** R1-R2 間で Key-Chain による MD5 認証を構成し、時間経過で鍵が自動切り替わるよう構成せよ。

**【R1 / R2 共通】**
```bash
key chain EIGRP_KEYCHAIN
 key 1
  key-string KEY_JANUARY
  accept-lifetime 00:00:01 Jan 1 2026 23:59:59 Jan 31 2026
  send-lifetime   00:00:01 Jan 1 2026 23:59:59 Jan 31 2026
 key 2
  key-string KEY_FEBRUARY
  accept-lifetime 00:00:01 Feb 1 2026 23:59:59 Feb 28 2026
  send-lifetime   00:00:01 Feb 1 2026 23:59:59 Feb 28 2026
!
router eigrp FABRIC
 !
 address-family ipv4 unicast autonomous-system 100
  !
  af-interface GigabitEthernet0/1
   authentication mode md5
   authentication key-chain EIGRP_KEYCHAIN
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show key chain EIGRP_KEYCHAIN
```

---

### Scenario 10: トラブルシューティング（Primary Subnet Mismatch の復旧）
* **要件:** R1 (Gi0/1: 10.1.12.1/24) と R2 (Gi0/1: 10.1.99.2/24) 間でサブネット不一致により発生している `%EIGRP-3-NEIGHBORIGN` エラーを解消せよ。

**【R2 修正設定】**
```bash
interface GigabitEthernet0/1
 ip address 10.1.12.2 255.255.255.0
```

**【検証方法】**
```bash
R1# show logging
# エラーログが停止し、%DUAL-5-NBRCHANGE: EIGRP-IPv4 100: Neighbor 10.1.12.2 (GigabitEthernet0/1) is up が出力されることを確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】ユニキャストネイバー片系設定による不完全アジャセンシー
**問題:** 
ルータ R1 と R2 が直結されています。R1 側で `neighbor 10.1.12.2 GigabitEthernet0/1` を追加配置した直後から、R1 の EIGRP ネイバーテーブルで R2 が数秒おきに生成と消滅を繰り返す（フラッピングする）ようになりました。対向 R2 側ではコマンド変更を行っていません。この現象が発生する技術的理由と、R1/R2 の設定をどう修正すべきかを説明してください。

**解答・解説:**
* **技術的理由:** 
  R1 のインターフェイスに `neighbor` コマンドを設定した瞬間、Cisco IOS-XE の仕様により Gi0/1 上での**EIGRP マルチキャスト送信および受信処理が即座に無効化**されます。R1 は R2 へ向けてユニキャスト Hello を送信しますが、R2 側はマルチキャスト動作のままであるため、R1 からのユニキャスト Hello を受けて一次的にネイバーを作ろうとするものの、R2 が返すマルチキャスト Hello を R1 側 ASIC が拒否・破棄します。その結果、R1 側で ACK や Hello の応答が得られず「Retries Exceeded」が発生してネイバーが切断され、ログにフラッピングが記録されます。
* **修正方法:** 
  R2 側でも同様に `neighbor 10.1.12.1 GigabitEthernet0/1` をバインドしてユニキャスト通信へ完全統合するか、あるいは R1 側の `neighbor` 設定を削除して双方マルチキャスト動作に戻します。

---

### 2. 【コンフィグ読解】非対称タイマー設定時の動作判定
**問題:** 
以下のコンフィグが投入された R1 と R2 の間で、EIGRP ネイバーアジャセンシーは正常に確立・維持されるでしょうか？技術的理由とともに回答してください。
* R1: Hello 2秒, Hold 6秒
* R2: Hello 10秒, Hold 30秒

**解答・解説:**
* **判定:** **正常に確立・維持されます。**
* **技術的理由:** 
  EIGRP では Hello/Hold タイマーの一致はアジャセンシー成立の必須要件ではありません。EIGRP の Hold Time パラメータは、自機が Hello パケットのヘッダー内に含めて対向ルータへ通知する「対向側に対して自機を保持してほしい猶予時間」です。したがって、R1 は R2 から通知された Hold Time（30秒）に従って R2 を保持し、R2 は R1 から通知された Hold Time（6秒）に従って R1 を保持するため、両者とも Hold Time 満了前に相手の Hello を受信でき、安定したアジャセンシーが成立します。

---

## 🔗 参考リソース

* [Cisco Systems: EIGRP Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book.html)
* [Cisco Command Reference: EIGRP Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/command/ire-cr-book.html)
* [Cisco Live: BRKRST-2336 - EIGRP Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **ネイバー形成チェックリスト:**
  1. `show ip eigrp interfaces` でポートが Passive になっていないか確認。
  2. `show ip protocols` で K 値（K1〜K5/K6）が一致しているか確認。
  3. `show ip interface` で Primary IP アドレスが同一 CIDR サブネット内にあるか確認。
  4. 認証（HMAC-SHA-256 / MD5）のキーおよび時刻（NTP）が合致しているか確認。


## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [EIGRP Named Mode Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/200156-Configure-EIGRP-Named-Mode.html)

### CiscoLive (動画・スライド)
*   [Introduction to EIGRP - BRKENT-1187](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/BRKENT-1187.pdf) - EIGRPの基礎と概要を解説
*   [EIGRP Operations: The Usual Suspects - BRKENT-2050](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/BRKENT-2050.pdf) - EIGRPの動作原理やトラブルシューティングを解説。


### テクニカルドキュメント・設定例
*   [EIGRP Neighbor Adjacency Troubleshooting Checklist](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)
*   [Enhanced Interior Gateway Routing Protocol (RFC 7868)](https://tools.ietf.org/html/rfc7868)

---

## 📝 補足
- この学習メモは、EIGRPの隣接関係という「入口」の技術を、CCIEレベルの複雑なシナリオに対応できるまで深掘りしたものです。特にNamed Modeへの移行と、その中での詳細なインターフェイス制御（SHA-256やタイマー調整）は、試験での得点源となるため、完璧にマスターしてください。


