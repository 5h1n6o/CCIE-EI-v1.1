---
layout: default
title: 1.3.a-Adjacencies
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.3.a EIGRP Adjacencies

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.3 EIGRP」における「1.3.a Adjacencies（隣接関係）」について整理しました。

---

## 📘 概要

**EIGRP Adjacencies（隣接関係）**は、EIGRPルータがルート情報を交換するための基礎となるプロセスです。EIGRPは「信頼性のあるマルチキャスト」を使用してネイバーを発見し、関係を維持します。他のIGP（OSPFなど）とは異なり、EIGRPはエリアの概念がなく、ネイバーシップが確立されると即座にトポロジ情報のフルアップデートを送信します。

CCIEレベルの実装では、標準的な動的発見（マルチキャスト）だけでなく、静的ネイバー（ユニキャスト）の設定、**Named Mode（名前付きモード）**におけるインターフェイス固有のパラメータ管理、および複雑なネットワークトポロジ（NBMA、DMVPN、セカンダリアドレス環境）での隣接関係の維持能力が問われます。隣接関係が成立しない原因を論理的に特定し、迅速に修正するスキルは、ラボ試験の全てのセクションで必須となります。

---

## 🔑 要点

### 1. 隣接関係成立の必須条件

EIGRPで隣接関係を確立し、維持するためには以下の要素が**両端のルータで一致**している必要があります。

| 項目 | 内容 | 備考 |
| :--- | :--- | :--- |
| **AS番号** | 同じ自律システム番号（Autonomous System Number）であること。 | 異なるAS間では再配送が必要。 |
| **K値 (Metric Weights)** | 帯域幅、遅延、信頼性、負荷の計算に使用される係数（K1〜K5）。 | デフォルトは K1=1, K3=1。残りは0。 |
| **プライマリIPサブネット** | 隣接するインターフェイスが同じサブネットに属していること。 | セカンダリアドレスのみの一致では不可。 |
| **認証 (Authentication)** | 認証モード（MD5/SHA-256）とパスワード（Key）の一致。 | Named ModeではSHA-256が使用可能。 |

### 2. ネイバー発見メカニズム

*   **マルチキャスト方式:** デフォルトでは `224.0.0.10` (IPv4) または `FF02::A` (IPv6) を使用してHelloパケットを送信します。
*   **ユニキャスト方式 (Static Neighbor):** `neighbor` コマンドで相手のIPを指定します。この設定を行うと、該当インターフェイスでのマルチキャスト送信が停止し、ユニキャストのみでのやり取りとなります。

### 3. タイマーの動作

*   **Hello Timer:** ネイバーに生存を確認させる間隔。高速リンクでは5秒、低速リンク（T1以下）では60秒がデフォルトです。
*   **Hold Timer:** この時間内にHelloが届かない場合にネイバーをダウンと判定します。デフォルトはHelloタイマーの3倍。
*   **注意:** 両端でタイマーを一致させる必要はありませんが、極端な不一致はフラッピングの原因となります。

### 4. Named Mode (Multi-AF) の特徴

最新のシスコ推奨の実装方式です。
*   `address-family` 配下で設定を統合。
*   `af-interface` モードにより、特定のインターフェイスのみ隣接関係のパラメータ（タイマー、認証、パッシブ設定）を柔軟に変更可能です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単純な設定ミスではなく、設計意図に沿った高度な制約やトラブルシューティングが課されます。

### 1. 受信ACLによるHelloの遮断

トラブルシューティングセクションでは、インターフェイスに適用された **ACL (Access Control List)** が、EIGRPマルチキャストトラフィック（224.0.0.10）やプロトコル番号 88 を拒否しているケースが頻出します。
*   **確認:** `show ip eigrp neighbors` で何も表示されない場合、まず `show ip access-lists` を確認してください。

### 2. K値の不一致（K-Value Mismatch）

ルータのコンソールに `%DUAL-5-NBREID` や `K-value mismatch` のログが表示される場合、メトリック計算の重み付けが異なっています。
*   **ラボでの罠:** 意図的に1台のルータだけ `metric weights` が変更されていることがあります。`show ip protocols` で現在のK値を確認し、修正します。

### 3. セカンダリアドレスと隣接関係

EIGRPは**プライマリIPアドレス**のサブネットが一致していないと隣接関係を形成しません。
*   **シナリオ:** 「物理インターフェイスのプライマリIPが異なるが、セカンダリアドレスが同じサブネット」という環境。この場合、ネイバーは成立しません。解決にはプライマリサブネットの修正が必要です。

### 4. パッシブインターフェイス (Passive Interface)

`passive-interface` が有効なポートでは、Helloの送受信が停止します。
*   **要件:** 「特定のネットワークを広報しつつ、そのセグメントで隣接関係は持たせない（セキュリティのため）」というタスクで多用されます。
*   **注意:** Named Modeでは `af-interface default` で一括パッシブにし、個別に `no passive-interface` する設計が「最小コマンド数」として求められることがあります。

### 5. 静的ネイバーの強制

DMVPNなどのハブ＆スポーク環境において、マルチキャストが制限されている場合にユニキャストネイバーを構成するスキルが問われます。
*   **ポイント:** 片側を静的ネイバーにしたら、もう片側も必ず静的にする必要があります。

---

## 🛠 設定・検証コマンド

### 設定コマンド (Classic / Named Mode)

| 目的 | コマンド |
| :--- | :--- |
| **Classic: AS番号設定** | <code>router eigrp [AS]</code> |
| **Classic: 静的ネイバー** | <code>(config-router)# neighbor [IP] [Interface]</code> |
| **Classic: K値変更** | <code>(config-router)# metric weights 0 [K1] [K2] [K3] [K4] [K5]</code> |
| **Named: インスタンス作成** | <code>router eigrp [NAME]</code> |
| **Named: インターフェイス制御** | <code>(config-router-af)# af-interface [Interface&#124;default]</code> |
| **Named: SHA-256認証** | <code>(config-router-af-interface)# authentication mode hmac-sha-256 [PW]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **ネイバー一覧の確認** | <code>show ip eigrp neighbors</code> |
| **EIGRP全般のパラメータ確認** | <code>show ip protocols</code> |
| **インターフェイス詳細表示** | <code>show ip eigrp interfaces detail [ID]</code> |
| **パケットの送受信確認** | <code>debug eigrp packets hello</code> |
| **隣接関係の変化を追跡** | <code>debug eigrp neighbors</code> |
| **IPv6隣接関係の確認** | <code>show ipv6 eigrp neighbors</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. ユニキャストネイバーの強制実装

**【問題内容】**
R1(G0/1)とR2(G0/1)の間でEIGRP隣接関係を確立せよ。ただし、セキュリティ上の理由からマルチキャストトラフィックを一切使用せず、ユニキャストのみで通信を行うこと。AS番号は 100 とする。

**【設定サンプル】**
```ios
! R1
router eigrp 100
 neighbor 10.1.12.2 GigabitEthernet0/1
 network 10.1.12.0 0.0.0.255

! R2
router eigrp 100
 neighbor 10.1.12.1 GigabitEthernet0/1
 network 10.1.12.0 0.0.0.255
```
**【ポイント】**
`neighbor` コマンドを入れた瞬間、そのインターフェイスでのマルチキャスト送信が停止することを `show ip eigrp interfaces` で確認してください。

---

### 2. Named Mode：SHA-256によるセキュアな隣接関係

**【問題内容】**
名前付きEIGRP「CCIE_FABRIC」を使用し、AS 100を構成せよ。ネイバー間の認証にはKey-chainを使用せず、SHA-256アルゴリズムを用いて直接パスワード「Cisco@123」を設定せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   authentication mode hmac-sha-256 Cisco@123
  exit-af-interface
  network 10.0.0.0 0.255.255.255
```
**【ポイント】**
SHA-256認証はNamed Modeでのみサポートされるため、Classic Modeからの移行がタスクに含まれることがあります。

---

### 3. K値不一致のトラブルシューティングと修正

**【問題内容】**
R3が隣接ルータからルートを学習できていない。コンソールには隣接関係の切断ログが頻出している。この問題を特定し、デフォルトの設定（帯域幅と遅延のみを考慮）に復旧せよ。

**【検証・修正】**
```ios
R3# show ip protocols
! EIGRP-IPv4 Protocol for AS(100)
!   Metric weight K1=1, K2=1, K3=1, K4=1, K5=1  <-- 異常を発見
!
R3(config)# router eigrp 100
R3(config-router)# metric weights 0 1 0 1 0 0
```

---

### 4. パッシブインターフェイスの効率的設計

**【問題内容】**
R4において、すべてのインターフェイスのネットワークをEIGRP AS 100で広報せよ。ただし、隣接関係の形成は `GigabitEthernet0/1` のみで許可し、他のインターフェイス（Loopback等）からはHelloを送出しないように最小限のコマンドで設定せよ。

**【設定サンプル（Named Mode）】**
```ios
router eigrp CCIE
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   passive-interface  ! 全インターフェイスをパッシブ化
  af-interface GigabitEthernet0/1
   no passive-interface  ! 特定のインターフェイスだけ解除
  network 0.0.0.0 255.255.255.255
```

---

### 5. IPv6環境におけるリンクローカルアドレスの隣接関係

**【問題内容】**
IPv6環境でEIGRP名前付きモードを構成せよ。グローバルユニキャストアドレスが設定されていないリンクでも、リンクローカルアドレスを使用して隣接関係が成立することを確認せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_V6
 address-family ipv6 unicast autonomous-system 600
  af-interface default
   no shutdown
  exit-af-interface
```
**【ポイント】**
IPv6 EIGRPでは、`no shutdown` コマンドが `address-family` または `af-interface` 配下で必要になるバージョンがある点に注意が必要です。

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [EIGRP Named Mode Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/200156-Configure-EIGRP-Named-Mode.html)

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols (EIGRP深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKCCIE-3000: EIGRP for CCIE Candidates (Narbik Kocharians等による解説)](https://www.ciscolive.com/global/on-demand-library.html)

### テクニカルドキュメント・設定例
*   [EIGRP Neighbor Adjacency Troubleshooting Checklist](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)
*   [Enhanced Interior Gateway Routing Protocol (RFC 7868)](https://tools.ietf.org/html/rfc7868)

---

## 📝 補足
- この学習メモは、EIGRPの隣接関係という「入口」の技術を、CCIEレベルの複雑なシナリオに対応できるまで深掘りしたものです。特にNamed Modeへの移行と、その中での詳細なインターフェイス制御（SHA-256やタイマー調整）は、試験での得点源となるため、完璧にマスターしてください。


