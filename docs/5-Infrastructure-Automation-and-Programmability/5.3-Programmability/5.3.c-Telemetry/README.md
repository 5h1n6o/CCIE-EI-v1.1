---
layout: default
title: 5.3.c-Telemetry
parent: 5.3-Programmability
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 3
---

# 5.3.c Configure on-change subscription using gRPC

---

## 📘 概要

Model-Driven Telemetry (MDT) は、従来の SNMP ポーリング方式に代わる次世代のデータ収集・ネットワーク可観測性（Observability）アーキテクチャです。Cisco IOS XE 機器からリアルタイムかつ高頻度にネットワーク状態データを抽出・ストリーミング送信する技術であり、CCIE Enterprise Infrastructure (EI) v1.1 Blueprint における重要なプログラマビリティ項目です。

本学習メモで扱う **`On-change subscription using gRPC` (gRPC を使用したオンチェンジ サブスクリプション)** は、インターフェイスの Up/Down 状態、BGP/OSPF ネイバー状態の変化、CDP/LLDP 隣接関係の変更など、追跡対象のデータオブジェクト値に変更が発生した瞬間（イベント発生時）にのみ、プッシュ型（Push-based）でコレクターへパケットを即座に送信する高度な通知メカニズムです。

### 主な利用目的と適用場面
1. **マイクロ秒/ミリ秒精度のイベント障害検知**
   SNMP の数分間隔（例: 5分周期）のポーリングでは検知不可能な一瞬のリンクフラッピング、BGP セッション切断、VRF 内ルート変更を即座に外部監視システム（InfluxDB, Prometheus, Telegraf, Kafka 等）へリアルタイム通知します。
2. **ネットワーク帯域とルータ CPU リソースの徹底的最適化**
   データ値に変化がない間はテレメトリパケットを発行しないため、Periodic（周期送信）サブスクリプションに比べて管理ネットワークの帯域消費とルータの制御面（Control Plane）CPU 負荷を極限まで削減します。
3. **gRPC (Google Remote Procedure Call) トランスポートによる信頼性と高効率伝送**
   HTTP/2 をトランスポート基盤とし、Protocol Buffers (gPB / Key-Value gPB) でコンパクトにシリアライズされた構造化データを TCP 経由（`grpc-tcp` または TLS 暗号化 `grpc-tls`）で確実にコレクターへストリーミング転送します。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **技術名称** | Model-Driven Telemetry (MDT) - On-change Subscription via gRPC |
| **標準規格 / プロトコル** | RFC 8639 (Subscription to Event Notifications), RFC 8640 (Dynamic Subscriptions via NETCONF), HTTP/2, gRPC |
| **データエンコーディング** | `encode-kvgpb` (Key-Value Google Protocol Buffers), `encode-gpb` (Structured GPB) |
| **トランスポート方式** | Dial-out: ルータが自発的にコレクターへ TCP/gRPC 接続を開設 (`protocol grpc-tcp` / `protocol grpc-tls`)<br>Dial-in: コレクターからルータ（Port 57400 等）へ gRPC 接続を開設してサブスクライブ |
| **トリガー条件** | **On-change** (YANG データツリー内の値変更時に即時送信)。`stream-item-change` |
| **主な使用 YANG モデル** | `Cisco-IOS-XE-native:native/interface`, `ietf-interfaces:interfaces-state`, `Cisco-IOS-XE-bgp-oper:bgp-state-data`, `Cisco-IOS-XE-ospf-oper:ospf-oper-data` |
| **対応機種 / OS** | Cisco Catalyst 9000 シリーズ (Catalyst 9300 / 9400 / 9500 / 9600), ISR 4000 / ASR 1000 / Catalyst 8000 (IOS XE 16.6 以降、17.3+ 推奨) |
| **メリット** | ① 超低遅延な障害通知（ミリ秒単位）<br>② 変化時のみ送信するため帯域・CPU 消費が極小<br>③ gRPC / HTTP/2 による多重化・高効率転送 |
| **デメリット / 制限事項** | ① すべての YANG ノードが On-change に対応しているわけではない (対応ノードの選定が必要)<br>② 短時間に大量の状態変化（リンクフラップ等）が発生するとパケットバーストが生じる |
| **設計上の注意点** | ① On-change サポートの有無を `show telemetry ietf datamodel` で確認すること<br>② gRPC 宛先 IP / ポート（デフォルト 57500 等）への L3 到達性と CoPP ルール設計 |

---

## 🏗 動作原理

Model-Driven Telemetry の On-change サブスクリプションは、ルータ内部のデータベース（YANG 構造で管理される Operational/Configuration Data）の変化を内部イベントバスが検知することから始まります。

```
[IOS XE Internal Data Store / Datapath / ASIC]
                      │
        (1) State Change (e.g. Link DOWN / BGP Down)
                      ▼
[Telemetry Internal Subscription Manager (Cisco-IA / DB Notify)]
                      │
        (2) Filter Match (XPath Evaluation)
                      ▼
[gPB Encoder (encode-kvgpb)] ── (3) Serialize to Binary Payload
                      │
                      ▼
[gRPC Engine (HTTP/2 Client)]
                      │
        (4) Send Push Notification over TCP/gRPC (e.g. Port 57500)
                      ▼
[Telemetry Collector (Telegraf / Vector / Prometheus Receiver)]
```

### 通信フローの詳細解説
1. **イベント発生 (State Change):**
   物理ポートの切断、SVI の Down、BGP/OSPF ネイバーの State 遷移などがルータ内部で発生すると、IOS XE の内部データベース notification システムがイベントを発行します。
2. **XPath フィルタリング判定 (XPath Filtering):**
   設定された `telemetry ietf subscription <ID>` 内の XPath フィルター（例: `/ietf-interfaces:interfaces-state/interface/oper-status`）と発生したイベントが照合されます。
3. **gPB シリアライズ (Serialization):**
   変更されたデータノード名、パス、変更後の値（および変更前の値）、タイムスタンプ（ナノ秒/ミリ秒精度）が `Key-Value Google Protocol Buffers (kvgpb)` バイナリフォーマットへ高速シリアライズされます。
4. **gRPC (HTTP/2) 経由のプッシュ送信 (Push Stream):**
   Dial-out モードの場合、ルータはあらかじめ設定された Receiver (コレクター) の IP アドレスおよび TCP ポートに向けて確立済みの gRPC/HTTP/2 ストリーム上でデータフレームをプッシュ送信します。

---

## ⚙ 動作シーケンス

gRPC Dial-out On-change サブスクリプションが確立し、パケットが送信されるまでのシーケンスは以下の通りです。

```
Router (IOS XE)                                        Collector (Telegraf / gRPC Server)
      │                                                                  │
      │ ── (1) TCP 3-Way Handshake (e.g., Target IP:57500) ────────────> │
      │ ── (2) HTTP/2 Connection Preface & SETTINGS Frame ─────────────> │
      │ <── (3) HTTP/2 SETTINGS Ack ──────────────────────────────────── │
      │                                                                  │
      │ [ Subscription Established: Active State ]                       │
      │                                                                  │
      │ ── (4) Initial Sync / Baseline Data (Optional) ────────────────> │
      │                                                                  │
      │ ──── * No Traffic during Stable Network State * ──────────────── │
      │                                                                  │
      │ 💥 [ Event Occurs: Gi1 Interface Line-Protocol DOWN ]            │
      │                                                                  │
      │ ── (5) gRPC DATA Frame (encode-kvgpb Payload) ─────────────────> │
      │     - Node: /ietf-interfaces:interfaces-state/interface[name='Gi1']/oper-status
      │     - Value: down
      │     - Timestamp: 1698654000123456789 (ns)
      │                                                                  │
      │ <── (6) HTTP/2 WINDOW_UPDATE / ACK ───────────────────────────── │
```

### 各ステップの技術的詳細

1. **トランスポート接続の確立 (gRPC / TCP Session Setup):**
   ルータ上の Telemetry プロセスが起動すると、設定された `receiver ip address <IP> <PORT> protocol grpc-tcp` に従ってコレクター宛てに TCP セッションを開始し、HTTP/2 の接続ハンドシェイクを行います。
2. **サブスクリプションの有効化 (Subscription Activation):**
   ルータ内部で `telemetry ietf subscription <ID>` が `Valid` かつ `Active` ステートへ移行します。`receiver` への接続が失敗している場合、ステートは `Disconnected` となり一定間隔で再接続を試行します。
3. **初期同期パケットの送信 (Initial State / Baseline):**
   On-change サブスクリプション設定直後、現在の基準状態（ベースライン）を示す最初のテレメトリデータ（`sync-historical` または初期通知）が送信される場合があります。
4. **静寂期間 (Quiet Period):**
   ネットワーク状態に変更がない間は、ヘルスチェック用の Keepalive パケットや Ping フレームを除き、余分なデータパケットは一切送信されません。
5. **オンチェンジイベントトリガー ＆ 即時ストリーミング (On-change Event Delivery):**
   追跡対象のオブジェクト（例: `oper-status`）が `up` から `down` へ変化した瞬間、QFP / Control Plane から即座に gPB パケットが組み立てられ、gRPC データストリーム経由でコレクターへ送信されます。


## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure (EI) v1.1 Practical Exam において、Model-Driven Telemetry (MDT) は Section 5 (Infrastructure Automation and Programmability) の重要トピックです。特に **`On-change subscription using gRPC`** の設定と検証は、正確な構文理解と要求事項に応じたパラメータ選定が直接問われます。

### Blueprint で最も重要なポイント
1. **`telemetry ietf subscription` コマンド構造のマスター**
   * サブスクリプション ID の定義
   * `encoding encode-kvgpb` の指定 (Cisco IOS XE での標準)
   * `stream yang-push` または `stream-item-change` の理解
   * `filter xpath <XPATH_EXPRESSION>` による正確な YANG パスの記述
   * `source-address` / `source-vrf` の適切なバインド
   * `receiver ip address <IP> <PORT> protocol grpc-tcp` による宛先定義
2. **On-Change 設定時の構文ルール**
   * **`select-filter` vs `filter xpath`**: 最新の IOS XE では `filter xpath` が主流。
   * **Periodic（周期）設定との違い**: On-change では `period <CS>` (Centiseconds) を指定せず、代わりに `stream yang-push` かつ `on-change` キーワード、または YANG パスが On-change に対応しているノードを選択します。
3. **VRF / 送信元インターフェイスの指定**
   コレクターが Management VRF (`Mgmt-vrf`) や特定テナント VRF 宛てに配置されている場合、`source-vrf` または `source-address` を指定し忘れるとデフォルトルーティングテーブルを参照してしまい、L3 到達性エラー（`Disconnected`）になります。

---

## 🛠 設定方法

### CLI による gRPC Dial-out On-change サブスクリプション基本設定

Cisco IOS XE 17.x における標準的な Dial-out On-change サブスクリプションの設定手順です。

```bash
! Step 1: 送信元および宛先コレクターのネットワーク到達性を確認
ping vrf Mgmt-vrf 192.168.100.50

! Step 2: Telemetry IETF Subscription の設定
telemetry ietf subscription 501
 encoding encode-kvgpb
 filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
 source-address 10.1.1.1
 source-vrf Mgmt-vrf
 stream yang-push
 receiver ip address 192.168.100.50 57500 protocol grpc-tcp
```

### パラメータ解説

* **`telemetry ietf subscription 501`**: サブスクリプション識別子（1 〜 2147483647 の整数）。
* **`encoding encode-kvgpb`**: 効率的な Key-Value Protocol Buffers エンコーディングを指定。
* **`filter xpath /ietf-interfaces:interfaces-state/interface/oper-status`**:
  追跡対象の YANG パスを XPath 形式で指定。このノード（`oper-status`）は On-change に対応しており、ステータス変更時のみパケットが発行されます。
* **`source-address 10.1.1.1`**: Telemetry パケットの送信元 IPv4 アドレス。
* **`source-vrf Mgmt-vrf`**: コレクター宛てのルーティングテーブルとして使用する VRF。
* **`stream yang-push`**: RFC 8639/8640 準拠の YANG Push ストリームを指定。
* **`receiver ip address 192.168.100.50 57500 protocol grpc-tcp`**:
  コレクターの IP アドレス、TCP ポート番号（例: 57500）、トランスポートプロトコル（非暗号化 gRPC `grpc-tcp` または 暗号化 gRPC `grpc-tls`）。

---

## 🔍 検証コマンド

ラボ試験および実務で Telemetry の動作状態を確認・診断するための必須コマンド一覧です。

| 目的 | コマンド | 注目すべき出力項目 |
| --- | --- | --- |
| 全サブスクリプションの概要確認 | <code>show telemetry ietf subscription all</code> | `Subscription ID`, `State` (`Valid`/`Active`), `Type` (`On-change`/`Periodic`), `Filter Type` |
| 特定サブスクリプションの詳細確認 | <code>show telemetry ietf subscription 501 detail</code> | `State: Valid`, `Stream: yang-push`, `XPath filter`, `Updates sent`, `Drops` |
| Receiver (コレクター) の接続状態確認 | <code>show telemetry ietf subscription 501 receiver</code> | `IP:Port`, `Protocol: grpc-tcp`, `State: Connected`, `Connection Explanation` |
| Telemetry システム全般のステータス確認 | <code>show telemetry ietf summary</code> | `Total Subscriptions`, `Active Subscriptions`, `Connection Status` |
| YANG データモデルの On-change 可否確認 | <code>show telemetry ietf datamodel</code> | `Datamodel Name`, `On-change Supported` (`Yes`/`No`) |
| デバッグログの有効化 | <code>debug telemetry ietf error</code><br><code>debug telemetry ietf event</code> | gRPC 接続エラー、XPath スキーマエラー、パケット送信失敗ログ |

---

## 🚨 トラブルシュート

ラボ試験で遭遇しやすい典型的なトラブル症状と対処方法です。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| Receiver State が `Disconnected` のまま変化しない | ① ルータ ⇄ コレクター間の L3 到達性欠落<br>② `source-vrf` の指定漏れ<br>③ コレクター側 gRPC ポートが Listen していない | <code>show telemetry ietf subscription 501 receiver</code><br><code>ping vrf <VRF> <IP></code> | ① ルーティングおよび ACL を修復<br>② 正しい `source-vrf` を設定<br>③ コレクター側の gRPC サービス状態を確認 |
| 状態が `Invalid` または `Error` になる | ① 指定した XPath パスが間違っている<br>② IOS XE に存在しない YANG モジュールを指定 | <code>show telemetry ietf subscription 501 detail</code> | `show telemetry ietf datamodel` で正しい XPath 構文を確認し修正 |
| 変更が発生したのに Telemetry パケットが送信されない | ① 指定した YANG ノードが On-change 未対応<br>② コレクター側でパケットがパースエラーで破棄 | <code>show telemetry ietf datamodel</code><br><code>debug telemetry ietf event</code> | On-change 対応の YANG ノードに変更するか、Periodic 送信へ切り替え |
| 大量のパケットドロップが発生する (`Drops` が増加) | ① コレクターの受信処理能力不足<br>② ネットワーク帯域制限または CoPP によるドロップ | <code>show telemetry ietf subscription 501 detail</code><br><code>show policy-map control-plane</code> | CoPP の Class-map / Rate Limit を緩和、またはコレクター性能を強化 |

---

## ⚠ 制限事項

1. **YANG ノードの On-change サポート制限**
   Cisco IOS XE のすべての YANG ノードが On-change 通知をサポートしているわけではありません。CPU カウンターやインターフェイスのバイト数カウンターなど、常に変動するデータノードは On-change ではなく **Periodic (周期)** のみがサポートされます。
2. **トランスポートプロトコルの依存関係**
   On-change サブスクリプションは **`gRPC` (`grpc-tcp` または `grpc-tls`)** トランスポートで最も効果的に動作します。NETCONF Dial-in での On-change 通知も可能ですが、スケール面では Dial-out gRPC が推奨されます。
3. **暗号化 (TLS) 使用時の証明書要件**
   `protocol grpc-tls` を使用する場合、ルータ側で PKI Trustpool / Trustpoint (`crypto pki trustpoint`) が正しく構成され、コレクターの証明書検証を通過する必要があります。ラボ試験で特段の TLS 指定がない場合は `grpc-tcp` を使用します。

---

## 🔄 他技術との関連

* **SNMP (Simple Network Management Protocol)**:
  伝統的な Poll 型プロトコル。MDT は SNMP に比べて CPU 負荷が低く、On-change により即時検知が可能です。
* **Control Plane Policing (CoPP)**:
  Dial-out gRPC パケットはアウトバウンド通信ですが、対向コレクターからの ACK や Dial-in gRPC セッション受信時は Control Plane を通過するため、CoPP で TCP ポート 57400/57500 が許可されている必要があります。
* **VRF / VRF-Lite**:
  管理ネットワークが `Mgmt-vrf` に分離されている環境では、サブスクリプション内で `source-vrf` を明示指定しなければ到達不能となります。

---

## 🧩 比較表

### Telemetry 送信モード比較 (On-change vs Periodic)

| 比較項目 | On-change Subscription | Periodic Subscription |
| --- | --- | --- |
| **送信トリガー** | データ値の変化発生時 (Event-driven) | 一定時間間隔 (Timer-driven, e.g. 10秒毎) |
| **データ適合例** | リンクステート (`oper-status`), BGP State, IP SLA Track | パケットカウンター, CPU/Memory 使用率 |
| **帯域消費** | **極めて低い** (変化時のみ送信) | 定常的に一定の帯域を消費 |
| **即時性 (リアルタイム性)** | **ミリ秒精度** (発生即時) | タイマーの周期（最速でも数秒）に依存 |
| **対象 YANG ノード** | On-change 対応ノード限定 | ほぼすべての Operational YANG ノード |

### Telemetry アーキテクチャ比較 (Dial-out vs Dial-in)

| 比較項目 | Dial-out (gRPC) | Dial-in (NETCONF / gRPC) |
| --- | --- | --- |
| **セッション開設者** | **ルータ** ➔ コレクターへ接続 | **コレクター** ➔ ルータへ接続 |
| **トランスポート** | gRPC (`grpc-tcp` / `grpc-tls`) | NETCONF (Port 830) / gRPC (Port 57400) |
| **拡張性 (Scalability)** | **高** (ルータ数が多くてもコレクター側で集中受信) | 中 (コレクターが多数のルータへ常時接続を保持) |
| **CLI 設定場所** | ルータ上の CLI 設定 (`telemetry ietf`) | コレクター側の RPC リクエスト送信 |

---

## 💡 ベストプラクティス

1. **YANG ノードの事前検証**
   サブスクリプションを設定する前に、必ず `show telemetry ietf datamodel` で対象の XPath が On-change をサポートしているか確認する。
2. **送信元 IP / VRF の明示的指定**
   マルチ VRF 環境や Loopback インターフェイス運用環境では、`source-address` および `source-vrf` を必ず明示して送信元 IP を固定化する。
3. **トラブルシューティング時の手順徹底**
   ① L3 到達性確認 (`ping vrf ...`) ➔ ② `show telemetry ietf subscription all` で State 確認 ➔ ③ `show telemetry ietf subscription <ID> receiver` で TCP 接続確認 の順で切り分ける。


## 📝 ラボ学習・設定サンプル例

CCIE EI v1.1 ラボ試験レベルを意識した、実用的な 10 個の演習シナリオです。すべてのコンフィグは省略せず完全な形式で記載しています。

---

### ラボ 1: 基本的な Interface State の On-change サブスクリプション構成

#### 問題
R1 において、全物理インターフェイスの `oper-status` (Up/Down 状態) の変更をリアルタイムに検知し、コレクター (192.168.1.100:57500) へ gRPC Dial-out でプッシュ送信する On-change サブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `101`
* エンコーディング: `encode-kvgpb`
* ストリーム: `yang-push`
* YANG フィルター: `/ietf-interfaces:interfaces-state/interface/oper-status`
* コレクター IP / ポート: `192.168.1.100` / `57500`
* トランスポート: `grpc-tcp`

#### 設定例

```bash
R1(config)# telemetry ietf subscription 101
R1(config-mdt-subs)# encoding encode-kvgpb
R1(config-mdt-subs)# filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
R1(config-mdt-subs)# stream yang-push
R1(config-mdt-subs)# receiver ip address 192.168.1.100 57500 protocol grpc-tcp
R1(config-mdt-subs)# end
```

#### 検証方法

```bash
! サブスクリプションの状態確認
R1# show telemetry ietf subscription 101 detail
Telemetry subscription detail:

Subscription ID: 101
Type: Configured
State: Valid
Stream: yang-push
Filter:
  Filter type: xpath
  XPath: /ietf-interfaces:interfaces-state/interface/oper-status
Encoding: encode-kvgpb
Source Address: 192.168.1.1
Receivers:
  Address: 192.168.1.100
  Port: 57500
  Protocol: grpc-tcp
  State: Connected

! インターフェイス状態の変更による動作テスト
R1(config)# interface GigabitEthernet2
R1(config-if)# shutdown
R1(config-if)# no shutdown

! 送信更新カウントの確認
R1# show telemetry ietf subscription 101 detail | include Updates sent
  Updates sent: 2
```

---

### ラボ 2: Management VRF 経由の Interface On-change サブスクリプション構成

#### 問題
R2 において、管理ネットワーク (VRF: `Mgmt-vrf`) 内に配置されたコレクター (10.255.255.50:57500) に対し、送信元 IP を Loopback0 (10.0.0.2) に固定してインターフェイス状態変更の On-change サブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `102`
* 送信元 IP: `10.0.0.2` (Loopback0)
* 送信元 VRF: `Mgmt-vrf`
* YANG フィルター: `/ietf-interfaces:interfaces-state/interface/admin-status`
* トランスポート: `grpc-tcp`

#### 設定例

```bash
R2(config)# interface Loopback0
R2(config-if)# ip address 10.0.0.2 255.255.255.255
R2(config-if)# exit

R2(config)# telemetry ietf subscription 102
R2(config-mdt-subs)# encoding encode-kvgpb
R2(config-mdt-subs)# source-address 10.0.0.2
R2(config-mdt-subs)# source-vrf Mgmt-vrf
R2(config-mdt-subs)# filter xpath /ietf-interfaces:interfaces-state/interface/admin-status
R2(config-mdt-subs)# stream yang-push
R2(config-mdt-subs)# receiver ip address 10.255.255.50 57500 protocol grpc-tcp
R2(config-mdt-subs)# end
```

#### 検証方法

```bash
R2# show telemetry ietf subscription 102 receiver
Telemetry subscription receiver detail:

Subscription ID: 102
Address: 10.255.255.50
Port: 57500
Protocol: grpc-tcp
State: Connected
Explanation: Connection is established
```

---

### ラボ 3: BGP Peer State 変更の On-change サブスクリプション構成

#### 問題
R3 において、Cisco Native Operational YANG モジュール (`Cisco-IOS-XE-bgp-oper`) を使用し、BGP セッション状態 (`session-state`) に変更があった場合にのみリアルタイム通知を行う On-change サブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `201`
* YANG フィルター: `/bgp-ios-xe-oper:bgp-state-data/neighbors/neighbor/session-state`
* コレクター IP / ポート: `172.16.10.10` / `57500`
* トランスポート: `grpc-tcp`

#### 設定例

```bash
R3(config)# telemetry ietf subscription 201
R3(config-mdt-subs)# encoding encode-kvgpb
R3(config-mdt-subs)# filter xpath /bgp-ios-xe-oper:bgp-state-data/neighbors/neighbor/session-state
R3(config-mdt-subs)# stream yang-push
R3(config-mdt-subs)# receiver ip address 172.16.10.10 57500 protocol grpc-tcp
R3(config-mdt-subs)# end
```

#### 検証方法

```bash
R3# show telemetry ietf subscription 201 detail
Subscription ID: 201
State: Valid
XPath: /bgp-ios-xe-oper:bgp-state-data/neighbors/neighbor/session-state
Receivers:
  Address: 172.16.10.10  Port: 57500  State: Connected

! BGP セッションのクリアによる On-change トリガーテスト
R3# clear ip bgp * soft
```

---

### ラボ 4: OSPF Neighbor State 変更の On-change サブスクリプション構成

#### 問題
R4 において、OSPF ネイバーのステータス変更（FULL から DOWN への遷移など）を監視し、コレクター宛てに On-change 通知を送信するサブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `202`
* YANG フィルター: `/ospf-ios-xe-oper:ospf-oper-data/ospf-state/ospf-instance/ospf-area/ospf-interface/ospf-neighbor/state`
* コレクター IP / ポート: `172.16.20.20` / `57500`

#### 設定例

```bash
R4(config)# telemetry ietf subscription 202
R4(config-mdt-subs)# encoding encode-kvgpb
R4(config-mdt-subs)# filter xpath /ospf-ios-xe-oper:ospf-oper-data/ospf-state/ospf-instance/ospf-area/ospf-interface/ospf-neighbor/state
R4(config-mdt-subs)# stream yang-push
R4(config-mdt-subs)# receiver ip address 172.16.20.20 57500 protocol grpc-tcp
R4(config-mdt-subs)# end
```

#### 検証方法

```bash
R4# show telemetry ietf subscription 202 detail
```

---

### ラボ 5: 暗号化 TLS gRPC (grpc-tls) Dial-out サブスクリプション構成

#### 問題
ルータ R5 からコレクター (192.168.50.5:57501) に対し、TLS 暗号化セッション (`protocol grpc-tls`) を用いてインターフェイス状態変化を通知する安全な On-change サブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `301`
* トランスポート: `grpc-tls`
* ポート: `57501`

#### 設定例

```bash
R5(config)# telemetry ietf subscription 301
R5(config-mdt-subs)# encoding encode-kvgpb
R5(config-mdt-subs)# filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
R5(config-mdt-subs)# stream yang-push
R5(config-mdt-subs)# receiver ip address 192.168.50.5 57501 protocol grpc-tls
R5(config-mdt-subs)# end
```

#### 検証方法

```bash
R5# show telemetry ietf subscription 301 receiver
Subscription ID: 301
Address: 192.168.50.5
Port: 57501
Protocol: grpc-tls
State: Connected
```


### ラボ 6: 冗長 コレクター宛てのマルチ Receiver On-change サブスクリプション構成

#### 問題
R6 において、障害耐性を高めるために、同一の On-change サブスクリプション定義 (`401`) 内で 2 台のプライマリ/セカンダリコレクター (192.168.1.10 及び 192.168.2.10) に対し同時にストリーミングパケットを送信する冗長構成を作成しなさい。

#### 要件
* サブスクリプション ID: `401`
* Primary Receiver: `192.168.1.10:57500`
* Secondary Receiver: `192.168.2.10:57500`

#### 設定例

```bash
R6(config)# telemetry ietf subscription 401
R6(config-mdt-subs)# encoding encode-kvgpb
R6(config-mdt-subs)# filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
R6(config-mdt-subs)# stream yang-push
R6(config-mdt-subs)# receiver ip address 192.168.1.10 57500 protocol grpc-tcp
R6(config-mdt-subs)# receiver ip address 192.168.2.10 57500 protocol grpc-tcp
R6(config-mdt-subs)# end
```

#### 検証方法

```bash
R6# show telemetry ietf subscription 401 detail
Subscription ID: 401
Receivers:
  Address: 192.168.1.10  Port: 57500  State: Connected
  Address: 192.168.2.10  Port: 57500  State: Connected
```

---

### ラボ 7: IP SLA / Track オブジェクト状態変化の On-change サブスクリプション構成

#### 問題
R7 において、IP SLA プローブの追跡を行う `track` オブジェクトの状態変更（Up/Down 変化）を即時に検知し、コレクター宛てにストリーミング送信するサブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `501`
* YANG フィルター: `/Cisco-IOS-XE-track-oper:track-oper-data/track-list/state`
* コレクター: `10.10.10.100:57500`

#### 設定例

```bash
R7(config)# telemetry ietf subscription 501
R7(config-mdt-subs)# encoding encode-kvgpb
R7(config-mdt-subs)# filter xpath /Cisco-IOS-XE-track-oper:track-oper-data/track-list/state
R7(config-mdt-subs)# stream yang-push
R7(config-mdt-subs)# receiver ip address 10.10.10.100 57500 protocol grpc-tcp
R7(config-mdt-subs)# end
```

#### 検証方法

```bash
R7# show telemetry ietf subscription 501 detail
```

---

### ラボ 8: Native YANG (`Cisco-IOS-XE-native`) を用いた On-change 構成

#### 問題
R8 において、標準 IETF モデルではなく Cisco IOS XE Native データモデル (`Cisco-IOS-XE-native`) を使用し、特定インターフェイスコンフィグの変更を検出する On-change サブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `601`
* YANG フィルター: `/native/interface/GigabitEthernet/shutdown`
* コレクター: `192.168.80.80:57500`

#### 設定例

```bash
R8(config)# telemetry ietf subscription 601
R8(config-mdt-subs)# encoding encode-kvgpb
R8(config-mdt-subs)# filter xpath /native/interface/GigabitEthernet/shutdown
R8(config-mdt-subs)# stream yang-push
R8(config-mdt-subs)# receiver ip address 192.168.80.80 57500 protocol grpc-tcp
R8(config-mdt-subs)# end
```

#### 検証方法

```bash
R8# show telemetry ietf subscription 601 detail
```

---

### ラボ 9: LLDP 隣接関係変化の On-change サブスクリプション構成

#### 問題
R9 において、隣接スイッチやデバイスの接続・切断に伴う LLDP 隣接情報の変更 (`lldp-entry`) を検出する On-change サブスクリプションを構成しなさい。

#### 要件
* サブスクリプション ID: `701`
* YANG フィルター: `/lldp-ios-xe-oper:lldp-entries/lldp-entry/device-id`
* コレクター: `10.99.99.99:57500`

#### 設定例

```bash
R9(config)# telemetry ietf subscription 701
R9(config-mdt-subs)# encoding encode-kvgpb
R9(config-mdt-subs)# filter xpath /lldp-ios-xe-oper:lldp-entries/lldp-entry/device-id
R9(config-mdt-subs)# stream yang-push
R9(config-mdt-subs)# receiver ip address 10.99.99.99 57500 protocol grpc-tcp
R9(config-mdt-subs)# end
```

#### 検証方法

```bash
R9# show telemetry ietf subscription 701 detail
```

---

### ラボ 10: 複合監視 (On-change ＋ Periodic ハイブリッド) 構成

#### 問題
R10 において、ミリ秒精度が求められるリンク Up/Down 通知には On-change サブスクリプション (`801`) を、定常的な CPU 使用率の監視には 10 秒周期 (`period 1000`) の Periodic サブスクリプション (`802`) を同時に適用するハイブリッド構成を作成しなさい。

#### 要件
* サブスクリプション 801 (On-change): インターフェイス `oper-status` 監視
* サブスクリプション 802 (Periodic): CPU 利用率監視 (`period 1000` = 10秒)
* コレクター: `192.168.100.10:57500`

#### 設定例

```bash
! On-change サブスクリプション (イベント変化時のみ)
R10(config)# telemetry ietf subscription 801
R10(config-mdt-subs)# encoding encode-kvgpb
R10(config-mdt-subs)# filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
R10(config-mdt-subs)# stream yang-push
R10(config-mdt-subs)# receiver ip address 192.168.100.10 57500 protocol grpc-tcp
R10(config-mdt-subs)# exit

! Periodic サブスクリプション (10秒周期)
R10(config)# telemetry ietf subscription 802
R10(config-mdt-subs)# encoding encode-kvgpb
R10(config-mdt-subs)# filter xpath /process-cpu-ios-xe-oper:cpu-usage/cpu-utilization/five-seconds
R10(config-mdt-subs)# stream yang-push
R10(config-mdt-subs)# period 1000
R10(config-mdt-subs)# receiver ip address 192.168.100.10 57500 protocol grpc-tcp
R10(config-mdt-subs)# end
```

#### 検証方法

```bash
R10# show telemetry ietf summary
Telemetry Summary:

Subscription ID  Type       State    Filter Type  Amount
--------------------------------------------------------
801              On-change  Valid    xpath        1
802              Periodic   Valid    xpath        1
```


## ❓ 想定試験問題

CCIE Enterprise Infrastructure ラボ試験・筆記試験を模した実戦的な問題集です。

---

### 問 1 (コンフィグ読解・トラブルシューティング)
以下のコンフィグをルータ R1 に投入したところ、インターフェイスの Up/Down が発生してもコレクターへ Telemetry パケットが送信されず、`show telemetry ietf subscription 101 receiver` のステートが `Disconnected` のままでした。障害原因として最も可能性が高いものを 1 つ選びなさい。

```bash
telemetry ietf subscription 101
 encoding encode-kvgpb
 filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
 stream yang-push
 receiver ip address 10.255.255.50 57500 protocol grpc-tcp
```

なお、コレクター (10.255.255.50) は Management VRF (`Mgmt-vrf`) 内に存在しており、ルーティングは `Mgmt-vrf` テーブルにのみ存在します。

* A. `encoding` に `encode-json` を指定していないため。
* B. `source-vrf Mgmt-vrf` の指定が欠落しており、デフォルトルーティングテーブルで送信を試みて失敗しているため。
* C. `period 1000` の周期設定が指定されていないため。
* D. `stream` に `yang-stream` を指定しなければならないため。

#### 正解
**B**

#### 解説
コレクターが特定 VRF (`Mgmt-vrf`) 内に存在する場合、サブスクリプション定義内で `source-vrf Mgmt-vrf` (または `source-address` / 適切な VRF バインド) を明示しないと、IOS XE の Telemetry プロセスはグローバルルーティングテーブルを参照してセッション開設を試みます。グローバルテーブルに 10.255.255.50 へのルートが存在しない場合、TCP 接続が開設できず Receiver State は `Disconnected` のままとなります。

---

### 問 2 (Design / 監視設計)
ミッションクリティカルな Enterprise WAN 環境において、1,000 台のルータからコア回線の障害（リンク Down）を 10 ミリ秒以内で検知しつつ、正常時のネットワーク管理帯域の消費を最小限に抑える監視設計として、最も適した構成を選びなさい。

* A. SNMP v3 定期ポーリング（Polling Interval: 1秒）を全ルータに適用する。
* B. MDT Periodic Subscription（`period 100` = 1秒間隔）を gRPC Dial-out で構成する。
* C. MDT On-change Subscription（YANG: `oper-status`）を gRPC Dial-out (`grpc-tcp`) で構成する。
* D. CLI 上で EEM アプレットを作成し、毎分 Ping で疎通確認を行う。

#### 正解
**C**

#### 解説
On-change サブスクリプションは、状態に変更が発生した瞬間（Event-driven）にのみパケットを即時送信します。正常時はパケットを発行しないため帯域消費が極めて小さく、障害発生時はミリ秒精度でパケットが到達するため、超低遅延障害検知と帯域/CPU 負荷低減の両立に最も適しています。

---

### 問 3 (トラブルシューティング / On-change 適合性)
エンジニアがルータ R1 において、CPU 利用率の変調をリアルタイムに検知するために以下のサブスクリプションを設定しようとしましたが、設定エラーまたはデータが送信されない現象が発生しました。原因として正しい説明を選びなさい。

```bash
telemetry ietf subscription 301
 encoding encode-kvgpb
 filter xpath /process-cpu-ios-xe-oper:cpu-usage/cpu-utilization/five-seconds
 stream yang-push
 receiver ip address 192.168.1.50 57500 protocol grpc-tcp
```

* A. CPU 利用率などの常に変動する動的カウンターノードは On-change 通知に対応しておらず、`period` (Periodic) の指定が必須であるため。
* B. `process-cpu-ios-xe-oper` モジュールは `grpc-tcp` をサポートしていないため。
* C. サブスクリプション ID が `300` 以上であるため。
* D. `stream` に `event-stream` を指定しなければならないため。

#### 正解
**A**

#### 解説
IOS XE の Telemetry において、CPU 利用率、メモリ消費量、パケットカウンター/バイトカウンターなどの連続的に変動するメトリックノードは、On-change イベント通知がサポートされていません。これらを監視する場合は、`period <CS>` (例: `period 1000` で 10 秒周期) を明示的に指定した **Periodic サブスクリプション** として構成する必要があります。

---

### 問 4 (実装 / CLI 読解)
単一の Telemetry On-change サブスクリプションにおいて、2 台のコレクター（192.168.10.1 及び 192.168.20.1）に対して同時に同じテレメトリデータをプッシュストリーミング送信するための正しい設定構文を選びなさい。

* A.
```bash
telemetry ietf subscription 100
 encoding encode-kvgpb
 filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
 stream yang-push
 receiver ip address 192.168.10.1 57500 protocol grpc-tcp
 receiver ip address 192.168.20.1 57500 protocol grpc-tcp
```
* B.
```bash
telemetry ietf subscription 100
 receiver ip group 192.168.10.1 192.168.20.1 port 57500
```
* C.
```bash
telemetry ietf subscription 100
 duplicate-stream enable 192.168.20.1
```
* D.
```bash
単一のサブスクリプション内に複数の receiver を定義することは不可能であり、サブスクリプション 101 を別個に作成しなければならない。
```

#### 正解
**A**

#### 解説
Cisco IOS XE の `telemetry ietf subscription` コマンドモード配下では、複数の `receiver ip address <IP> <PORT> protocol ...` サブコマンドを追加設定することが可能です。これにより、同一のデータストリームを複数のコレクターへ同時にマルチキャスト/デュアル送信できます。

---

### 問 5 (コンフィグ検証)
`show telemetry ietf subscription 101 detail` を実行した際、出力内の `State` が `Valid` かつ Receiver の `State` が `Connected` であるにもかかわらず、パケットがコレクター側で受信できません。確認すべきポイントとして正しいものを 2 つ選びなさい。（2つ選択）

* A. ルータとコレクター間の物理/L3 ネットワーク上で、TCP ポート 57500 が ACL やファイアウォールでブロックされていないか確認する。
* B. コレクター側の gRPC レシーバーサービス（Telegraf や Vector 等）が起動し、ポート 57500 で Listen 状態にあるか確認する。
* C. `show telemetry ietf subscription` コマンドで `period` を 0 に設定する。
* D. ルータの OSPF 認証を解除する。

#### 正解
**A, B**

#### 解説
ルータ側で `Connected` と表示されている場合、ルータからの TCP シンセシスまたはセッション確立自体は正常に完了しています。しかし、その後のパケット転送途中でファイアウォールによる L4 遮断が行われている場合や、コレクターアプリケーション側でパケット解読（gPB デコード）に失敗してサイレントドロップされているケースが考えられます。

---

## 🔗 参考リソース

CCIE EI v1.1 の学習にあたり参照すべき公式 Cisco ドキュメントおよび標準規格資料です。

* Cisco Programmability Configuration Guide: Model-Driven Telemetry
* Cisco Live Presentation: Programmability & Model-Driven Telemetry Deep Dive
* Cisco Command Reference: Telemetry IETF Subscription Commands
* RFC 8639: Subscription to YANG Notifications
* RFC 8640: Dynamic Subscriptions to YANG Notifications over NETCONF
* Cisco DevNet: Model-Driven Telemetry Resources

---

## 📝 **補足（Notes）**

### 学びのまとめと設計チェックリスト

1. **On-change サブスクリプションの黄金律**
   * **トランスポート:** `protocol grpc-tcp` (または `grpc-tls`)
   * **エンコーディング:** `encoding encode-kvgpb`
   * **トリガー:** `stream yang-push` ＋ On-change 対応 XPath ノード (`/ietf-interfaces:interfaces-state/interface/oper-status` 等)
   * **VRF 留意:** `source-vrf` の設定を絶対に忘れないこと！

2. **アーキテクチャ全体図の振り返り**

```
┌───────────────────────────────────────────────────────────┐
│ Router (Cisco IOS XE Catalyst 9000 / ISR / ASR)            │
│                                                           │
│  [Datapath / Interfaces] ──> (State Change)              │
│                                  │                        │
│                                  ▼                        │
│  [YANG Operational Data] ──> (XPath Trigger Match)        │
│                                  │                        │
│                                  ▼                        │
│  [gPB Encoder] ───────────> (encode-kvgpb)                │
│                                  │                        │
│                                  ▼                        │
│  [gRPC Client Engine] ────> (HTTP/2 Connection)           │
└─────────────────────────────────┬─────────────────────────┘
                                  │
                       gRPC Stream (TCP: 57500)
                                  │
                                  ▼
┌───────────────────────────────────────────────────────────┐
│ Collector (Telegraf / Vector / Prometheus / InfluxDB)      │
└───────────────────────────────────────────────────────────┘
```

3. **試験直前チェックリスト**
   - [ ] `telemetry ietf subscription <ID>` 配下の主要コマンドを何も見ずに打てるか？
   - [ ] `show telemetry ietf subscription <ID> receiver` で `State: Connected` を確認できるか？
   - [ ] Periodic (`period <CS>`) と On-change (`yang-push` 変化時) の違いを即座に説明できるか？
   - [ ] `Mgmt-vrf` 経由の宛先に対して `source-vrf Mgmt-vrf` を忘れずアタッチできるか？
