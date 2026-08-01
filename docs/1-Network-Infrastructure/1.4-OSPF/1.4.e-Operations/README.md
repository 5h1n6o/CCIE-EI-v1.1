---
layout: default
title: 1.4.e-Operations
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.4.e OSPF Operations

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.4 OSPF (v2 and v3)」における「1.4.e Operations（運用・動作）」について整理しました。

---

## 📘 概要

**OSPF Operations（OSPFの動作と運用）**は、リンクステート型ルーティングプロトコルとしてのOSPFが、どのようにネットワークの「地図」を構築し、維持し、そして安全に停止・保護するかを定義する広範なトピックです。

OSPFv2 (IPv4) および OSPFv3 (IPv6/Multi-AF) の基本動作は、ハローパケットによるネイバー発見、リンクステートデータベース（LSDB）の同期、そしてSPF（Shortest Path First）アルゴリズムによる経路計算の3段階で構成されます。CCIEレベルでは、これらの標準的な動作に加え、メンテナンス時の通信断を最小化する **Graceful Shutdown（グレースフルシャットダウン）** や、コントロールプレーンの攻撃からルータを保護する **GTSM (Generic TTL Security Mechanism)** といった高度な運用機能の完全な制御が求められます。

---

## 🔑 要点

### 1. General Operations (全般的な動作)

OSPFの健全な運用には、以下のプロセスが正しく機能している必要があります。

*   **Router-ID の一意性:** OSPFプロセス内で自身を識別するための32ビット値。OSPFv3では、IPv4アドレスが設定されていない場合でも手動での固定設定が必須です。
*   **LSA（Link State Advertisement）の同期:** 
    *   **Type 1 (Router LSA):** 全ルータが生成。自身のリンク情報を通知。
    *   **Type 2 (Network LSA):** DRが生成。セグメント内の隣接ルータ情報を通知。
    *   **LSA の再送メカニズム:** 信頼性の高い同期を保証するため、LSA 受信時に ACK を返します。
*   **Passive-Interface:** 特定のインターフェイスでハローの送受信を停止し、不要な隣接関係の形成を防ぎつつ、そのネットワーク情報を広報します。

### 2. Graceful Shutdown (グレースフルシャットダウン)

従来のOSPF停止（プロセス削除やインターフェイスのダウン）では、隣接ルータがデッドタイマーの満了を待つ必要があり、コンバージェンスに遅延が生じていました。

*   **動作原理:** `shutdown` コマンドを実行すると、ルータはネイバーに対し、メトリックを最大値（65535）にセットしたLSAや、ハローパケット内での通知（LSAのフラッシュ）を行います。
*   **効果:** 対向ルータは即座に当該ルータを経由しない経路への切り替え（再計算）を開始できるため、パケットロスを最小限に抑えられます。

### 3. GTSM (Generic TTL Security Mechanism)

OSPFネイバーに対するスプーフィング攻撃やCPU負荷攻撃を防止するためのセキュリティ機能です（RFC 5082）。

*   **メカニズム:** 通常のIPパケットはTTL（Time To Live）を「1」など小さい値から始めますが、GTSMを有効にしたOSPFルータは、パケット送信時のTTLを **「255」** にセットします。
*   **受信チェック:** 受信側ルータは、パケットのTTLが「255」であることを確認します。もし中継ルータ（攻撃者）を経由していれば、TTLは必ず254以下に減少しているため、直接接続されていない不正なパケットを即座に破棄できます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、OSPFの運用に関連して以下のような高度なトラブルシューティングや制約付き設定が課されます。

### 1. Router-ID 競合の特定

「OSPF隣接関係がFULLになるが、特定のルートがデータベースに現れない」といったシナリオ。
*   **原因:** ネットワーク内に Router-ID が重複しているルータが存在すると、LSAの破棄やフラッピングが発生します。
*   **対策:** `show ip ospf` で自身のIDを確認し、重複を排除します。

### 2. インターフェイス・デフォルトの効率的な管理

「すべてのインターフェイスをパッシブにしつつ、バックボーン接続のみを有効化せよ」という最小コマンド数のタスク。
*   **実装:** `passive-interface default` を設定した上で、必要なポートのみを `no passive-interface` で開放する設計。

### 3. GTSM の適用範囲とホップ数

GTSMはデフォルトで直接接続（Hop 1）を想定しますが、仮想リンク（Virtual-link）を使用している場合にどのように動作させるかが問われます。
*   **ポイント:** GTSMは直接接続のネイバー保護が主目的ですが、設定により複数ホップを許容することも可能です。

### 4. メンテナンスシナリオにおける Graceful Shutdown

「R1のOSPFプロセスを停止させる際、R2/R3側の通信への影響を最小限にせよ」という要件。
*   `no router ospf` でプロセスを消すのではなく、`shutdown` コマンドを使用して「お別れ」メッセージを送る必要があります。

---

## 🛠 設定・検証コマンド

### 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPFv2 プロセス・シャットダウン** | <code>(config-router)# shutdown</code> |
| **OSPFv2 インターフェイス・シャットダウン** | <code>(config-if)# ip ospf shutdown</code> |
| **GTSM の全インターフェイス有効化** | <code>(config-router)# ttl-security all-interfaces [hops H]</code> |
| **OSPFv3 (IPv6) プロセス停止** | <code>(config-router)# shutdown</code> |
| **Router-ID の手動固定** | <code>(config-router)# router-id [A.B.C.D]</code> |
| **パッシブ・インターフェイスのデフォルト化** | <code>(config-router)# passive-interface default</code> |

### 検証・デバッグコマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPFプロセスの稼働状態確認** | <code>show ip ospf</code> |
| **GTSM/TTL セキュリティのステータス確認** | <code>show ip ospf interface [ID]</code> |
| **ネイバーの状態遷移のデバッグ** | <code>debug ip ospf adj</code> |
| **LSAのフラッシュ・生成イベント確認** | <code>debug ip ospf lsa-generation</code> |
| **OSPFv3 ネイバーの確認** | <code>show ospfv3 neighbor</code> |
| **パケット統計（ドロップされたTTLの確認等）** | <code>show ip ospf statistics</code> |

---

## 🛠 ラボ学習・設定サンプル例

実戦的な12の実装シナリオです。

### 1. 基本的な OSPFv2 の初期化と Router-ID 固定

**【問題内容】**
AS 100 相当の OSPF 1 を起動し、Router-ID を 1.1.1.1 に固定せよ。すべてのインターフェイスを対象エリア 0 に含めよ。

**【設定例】**
```ios
router ospf 1
 router-id 1.1.1.1
 network 0.0.0.0 255.255.255.255 area 0
```

---

### 2. OSPFv3 における Router-ID の強制設定 (IPv6 Only)

**【問題内容】**
IPv4 アドレスが設定されていないルータにおいて OSPFv3 を起動せよ。Router-ID を設定しない場合にプロセスが起動しないことを確認し、修正せよ。

**【設定例】**
```ios
! 修正前：OSPFv3は起動に失敗する
router ospfv3 1
 ! 修正：32ビットの識別子を手動で与える
 router-id 0.0.0.2
 address-family ipv6 unicast
```

---

### 3. パッシブインターフェイスの効率的な一括設定

**【問題内容】**
ルータのすべてのインターフェイスをパッシブにし、ネイバー関係の形成を `GigabitEthernet0/1` のみで許可せよ。

**【設定例】**
```ios
router ospf 1
 passive-interface default
 no passive-interface GigabitEthernet0/1
```

---

### 4. プロセスレベルでの Graceful Shutdown

**【問題内容】**
OSPF プロセス全体を一時停止し、ネイバーに対してメトリックの最大値を広告させてからセッションを解除せよ。

**【設定例】**
```ios
router ospf 1
 ! プロセスを削除せずに論理的に停止させる
 shutdown
```

---

### 5. 特定インターフェイスのみの Graceful Shutdown

**【問題内容】**
`GigabitEthernet0/2` 経由の OSPF ネイバーのみを、対向ルータにコンバージェンスを促しながら停止させよ。

**【設定例】**
```ios
interface GigabitEthernet0/2
 ! このインターフェイスのみOSPFの動作を停止し、通知を送る
 ip ospf shutdown
```

---

### 6. GTSM によるネイバー保護 (全インターフェイス)

**【問題内容】**
コントロールプレーンの保護のため、すべての直接接続された OSPF ネイバーに対し TTL 255 のチェックを有効化せよ。

**【設定例】**
```ios
router ospf 1
 ! 全インターフェイスでGTSMを有効化
 ttl-security all-interfaces
```

---

### 7. インターフェイス個別での GTSM カスタマイズ

**【問題内容】**
グローバルで GTSM を有効にしているが、`GigabitEthernet0/3` だけは特定の理由で最大 2ホップ先までのネイバーを許容せよ。

**【設定例】**
```ios
interface GigabitEthernet0/3
 ! ホップ数を2に緩和してGTSMを適用
 ip ospf ttl-security hops 2
```

---

### 8. LSA Throttling による運用の安定化

**【問題内容】**
ネットワークが不安定な環境において、LSA の生成が頻発するのを防ぐため、最小間隔を 5000ms に制限せよ。

**【設定例】**
```ios
router ospf 1
 ! 初回生成 0ms, 次回 5000ms, 最大 5000ms
 timers throttle lsa 0 5000 5000
```

---

### 9. OSPFv3 Address Family での Graceful Shutdown

**【問題内容】**
OSPFv3 マルチアドレスファミリー環境において、IPv6 ユニキャストアドレスファミリーのみを停止せよ。

**【設定例】**
```ios
router ospfv3 1
 address-family ipv6 unicast
  ! IPv6ルーティングのみを停止
  shutdown
```

---

### 10. Router-ID 競合のトラブルシューティング (Verification)

**【問題内容】**
R1 と R2 で Router-ID が重複している。イベントログを確認し、R2 側の ID を変更せよ。

**【検証と設定】**
```ios
R2# show ip ospf
! "Routing Process "ospf 1" with ID 1.1.1.1" を確認。対向R1と同じ。
!
R2(config)# router ospf 1
R2(config-router)# router-id 2.2.2.2
! プロセス再起動が必要な場合がある
R2# clear ip ospf process
```

---

### 11. OSPF インターフェイスコストの手動変更 (Ops TE)

**【問題内容】**
運用の過程で、特定のパスへのトラフィック流入を抑えるため、コストを 10000 に変更せよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 ip ospf cost 10000
```

---

### 12. GTSM (TTL Security) のパケットドロップ確認

**【問題内容】**
GTSM を有効にした後、TTL 不一致でドロップされたパケット数を確認せよ。

**【検証コマンド】**
```ios
R1# show ip ospf statistics
! "TTL security failures" の項目を確認
```

---

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


