---
layout: default
title: 1.4.a-Adjacencies
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

1.4.a OSPF Adjacencies

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.4 OSPF (v2 and v3)」における「1.4.a Adjacencies（隣接関係）」について整理しました。

---

## 📘 概要

**OSPF Adjacencies（隣接関係）**は、OSPFルータがリンクステートデータベース（LSDB）を同期し、ネットワークの「地図」を構築するための最も基本的なプロセスです。OSPFルータはハローパケットを使用してネイバーを発見し、一連のステートマシン（Finite State Machine）を経て「FULL」状態の隣接関係を確立します。

CCIE EIレベルでは、単なるネイバーの確立だけでなく、**IPv4 (OSPFv2)** と **IPv6 (OSPFv3)** の両方における動作の違い、**ネットワークタイプ（Network Types）**による隣接関係形成の挙動の変化、および **MTU不一致** や **タイマー不整合** といった複雑なトラブルシューティングシナリオを完璧に理解していることが求められます。隣接関係が正しく形成されない限り、最短パス優先（SPF）計算は行われず、ルーティングは機能しません。

---

## 🔑 要点

### 1. 隣接関係確立の 7 ステップ (FSM)

OSPFネイバーが「FULL」に到達するまでのプロセスは、以下の状態遷移を辿ります。

| ステート | 動作内容 | 備考 |
| :--- | :--- | :--- |
| **DOWN** | 初期状態。ハローパケットを送信しているが、相手からの反応はない。 | |
| **INIT** | 相手からのハローを受信したが、その中に自分のRouter-IDが含まれていない。 | 一方向（One-way）の通信が成立。 |
| **2-WAY** | 相手からのハローに自分のRouter-IDが含まれている。 | **ネイバー関係の成立**。DR/BDRの選出が行われる。 |
| **EXSTART** | マスター/スレイブの決定。DBDパケットの順序番号を初期化する。 | **MTUチェック**がここで行われる。 |
| **EXCHANGE** | 自身のLSDBの要約情報（DBD）を交換する。 | |
| **LOADING** | 足りない詳細情報を要求（LSR）し、アップデート（LSU）を受信する。 | |
| **FULL** | LSDBの同期が完了。 | **隣接関係（Adjacency）の成立**。 |

### 2. 隣接関係形成の必須一致条件

ハローパケット内で以下の項目が一致していない場合、隣接関係は `2-WAY` 以上に進みません。

*   **Area ID:** 同じエリア番号であること。
*   **Authentication:** 認証方式（Type）とパスワード（Key）の一致。
*   **Hello / Dead Timers:** 秒単位での完全一致が必要（デフォルト 10/40 または 30/120）。
*   **Subnet Mask:** ブロードキャストセグメントの場合、同じサブネットであること。
*   **Stub Area Flag:** スタブ設定の有無（E-bit）が一致していること。
*   **Router-ID:** 重複していないこと（重複すると LSDB 同期でループ・フラップが発生する）。

### 3. OSPFv2 vs. OSPFv3 の隣接関係

OSPFv3 (for IPv6) では、ネイバー形成の仕組みが一部変更されています。

*   **リンクローカルアドレスの使用:** OSPFv3は、グローバルIPv6アドレスの有無に関わらず、**リンクローカルアドレス (FE80::/10)** を送信元としてネイバーを形成します。
*   **サブネットの一致条件:** OSPFv3は「リンク」ベースのプロトコルであるため、IPv6プレフィックス（サブネット）が異なっていても隣接関係を形成できる場合があります。
*   **認証:** OSPFv3は伝統的にIPv6拡張ヘッダー（IPsec）を利用していましたが、最新の IOS XE では **Trailer-based Authentication** が推奨されます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、OSPFの隣接関係に関連して以下のような高度な制約や障害が提示されます。

### 1. MTU不一致による EXSTART 停滞

*   **事象:** `show ip ospf neighbor` で状態が `EXSTART` または `EXCHANGE` で止まる。
*   **原因:** DBDパケットのサイズがインターフェイスの MTU を超えており、受信側でドロップされている。
*   **対策:** 両端の `ip mtu` を一致させるか、設定変更が制限されている場合は `ip ospf mtu-ignore` コマンドでチェックを回避します。

### 2. ネットワークタイプによる「FULL」への不成立

*   **事象:** 片側が `Point-to-Point`、もう片側が `Broadcast` の場合。
*   **挙動:** ハロータイマーが一致していれば `FULL` になる可能性があるが、LSAの扱い（DR/BDRの有無）が異なるため、SPF計算で正しいルートが算出されません。
*   **ラボの罠:** ステータスが `FULL` だからといって、ルーティングが正常とは限りません。`show ip ospf interface` でタイプを確認することが不可欠です。

### 3. OSPFv3 における Router-ID の欠如

*   OSPFv3環境で IPv4 アドレスが一切設定されていないルータでは、**Router-ID が自動選出されず、OSPFプロセスが起動しません**。
*   **対策:** `router-id 0.0.0.x` のように手動で 32ビットの識別子を設定する必要があります。

### 4. 特定ネイバーの拒否（フィルタリング）

*   `distribute-list` はルーティングテーブルへの登録を制限しますが、LSAの交換（隣接関係）は止められません。
*   隣接関係そのものを制御するには、インターフェイスを `passive-interface` にするか、ACLでプロトコル 89 (OSPF) をブロックする必要があります。

---

## 🛠 設定・検証コマンド

### 基本設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPFv2 プロセス起動** | <code>router ospf [Process-ID]</code> |
| **OSPFv2 ルータID固定** | <code>(config-router)# router-id [A.B.C.D]</code> |
| **インターフェイスでの有効化** | <code>(config-if)# ip ospf [PID] area [Area-ID]</code> |
| **OSPFv3 有効化(IPv6)** | <code>(config-if)# ospfv3 [PID] ipv6 area [Area-ID]</code> |
| **OSPFv3 アドレスファミリー構成** | <code>router ospfv3 [PID]</code> <br> <code>address-family ipv6 unicast</code> |

### パラメータ制御コマンド

| 目的 | コマンド |
| :--- | :--- |
| **MTUチェックの無視** | <code>(config-if)# ip ospf mtu-ignore</code> |
| **ネットワークタイプの変更** | <code>(config-if)# ip ospf network [broadcast&#124;point-to-point&#124;...]</code> |
| **タイマーの調整** | <code>(config-if)# ip ospf hello-interval [秒]</code> |
| **DR選出の優先度変更** | <code>(config-if)# ip ospf priority</code> |
| **パッシブ化** | <code>(config-router)# passive-interface [Interface-ID]</code> |

### 検証・デバッグコマンド

| 目的 | コマンド |
| :--- | :--- |
| **ネイバーの状態確認** | <code>show ip ospf neighbor</code> |
| **インターフェイス構成の確認** | <code>show ip ospf interface [ID]</code> |
| **OSPFv3ネイバーの確認** | <code>show ospfv3 neighbor</code> |
| **隣接関係遷移のデバッグ** | <code>debug ip ospf adj</code> |
| **ハローパケットの確認** | <code>debug ip ospf hello</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIEレベルの多様なシナリオを想定した、実戦的な 12 個の設定サンプルです。

### 1. 基本的な OSPFv2 隣接関係の確立

**【問題内容】**
R1 と R2 の間（10.1.12.0/24）で OSPF Area 0 を構成せよ。Router-ID は 0.0.0.x (xはルータ番号) とすること。

**【設定例】**
```ios
! R1
router ospf 1
 router-id 0.0.0.1
 interface GigabitEthernet0/1
  ip ospf 1 area 0
```

---

### 2. OSPFv3 における Link-Local 隣接関係

**【問題内容】**
R1 と R2 の間で IPv6 OSPFv3 を有効化せよ。グローバルアドレスを設定せず、リンクローカルアドレスのみで隣接関係が成立することを確認せよ。

**【設定例】**
```ios
! R1
interface GigabitEthernet0/1
 ipv6 enable
 ospfv3 1 ipv6 area 0
!
router ospfv3 1
 router-id 0.0.0.1
 address-family ipv6 unicast
```

---

### 3. MTU 不一致のトラブル解決 (mtu-ignore)

**【問題内容】**
R1(MTU 1500) と R2(MTU 1400) の間で OSPF ネイバーが `EXSTART` で止まっている。R1側で MTU 値を変更せずに、隣接関係を `FULL` にせよ。

**【設定例】**
```ios
! R1側で設定
interface GigabitEthernet0/1
 ip ospf mtu-ignore
```

---

### 4. ネットワークタイプの不一致修正 (NBMA)

**【問題内容】**
DMVPN等のハブ＆スポーク環境で、R1（ハブ）を `Point-to-Multipoint`、R2（スポーク）を `Point-to-Multipoint` に設定し、DR選出なしで隣接関係を確立せよ。

**【設定例】**
```ios
! R1 & R2 共通
interface Tunnel0
 ip ospf network point-to-multipoint
```

---

### 5. ハロータイマーの微調整による高速検知

**【問題内容】**
特定の高信頼性リンクにおいて、障害検知を 1秒以内に行うため、ハロー間隔を 1秒、デッドタイマーを 4秒に変更せよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 ip ospf hello-interval 1
 ip ospf dead-interval 4
```

---

### 6. DR 選出の意図的制御 (Priority)

**【問題内容】**
イーサネットセグメントにおいて、R3 を常に DR、R4 を常に BDR にし、他のルータは DR にならない（DROTHER）ようにせよ。

**【設定例】**
```ios
! R3 (DR候補)
interface GigabitEthernet0/1
 ip ospf priority 255

! R4 (BDR候補)
interface GigabitEthernet0/1
 ip ospf priority 100

! R5 (DRにならない)
interface GigabitEthernet0/1
 ip ospf priority 0
```

---

### 7. OSPFv2 MD5 認証の実装

**【問題内容】**
Area 0 の全インターフェイスで MD5 認証を構成せよ。Key-ID 1、パスワード「OSPF_PASS」を使用すること。

**【設定例】**
```ios
interface GigabitEthernet0/1
 ip ospf message-digest-key 1 md5 OSPF_PASS
!
router ospf 1
 area 0 authentication message-digest
```

---

### 8. OSPFv3 Trailer Authentication (SHA-256)

**【問題内容】**
OSPFv3 において、IPsec を使用せずに HMAC-SHA-256 認証を構成せよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 ospfv3 1 ipv6 authentication hmac-sha-256 key-id 10 0 CISCO_SECRET
```

---

### 9. 静的ネイバーの構成 (Non-Broadcast)

**【問題内容】**
ネットワークタイプを `non-broadcast` に設定し、マルチキャストを使用せずに隣接関係を確立せよ。AS番号 100 相当の構成とする。

**【設定例】**
```ios
! R1 (Hub)
router ospf 1
 neighbor 10.1.1.2
!
interface GigabitEthernet0/1
 ip ospf network non-broadcast
```

---

### 10. パッシブインターフェイスによる到達性のみの確保

**【問題内容】**
R1 の Loopback 0 (1.1.1.1/32) を OSPF に含めよ。ただし、Loopback からはハローを送出せず、隣接関係を形成させないこと。

**【設定例】**
```ios
router ospf 1
 passive-interface Loopback0
 network 1.1.1.1 0.0.0.0 area 0
```

---

### 11. プレフィックス学習数の制限 (Database Protection)

**【問題内容】**
OSPFプロセスが保持する LSA の数を 1000 個に制限し、これを超えた場合に警告を出力せよ。

**【設定例】**
```ios
router ospf 1
 max-lsa 1000 warning-only
```

---

### 12. VRF-Aware OSPF Adjacency

**【問題内容】**
VRF「CUSTOMER_A」内において、OSPF隣接関係を確立せよ。

**【設定例】**
```ios
router ospf 10 vrf CUSTOMER_A
 router-id 10.10.10.10
!
interface GigabitEthernet0/1.10
 vrf forwarding CUSTOMER_A
 ip ospf 10 area 0
```

---

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


