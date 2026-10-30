---
layout: default
title: 4.7-Network-operations
parent: 4-Infrastructure-Security-and-Services
nav_order: 7
---

# 4.7 Network operations

## 📘 概要

CCIE EI v1.1 Blueprintにおける **4.7 Network operations（ネットワーク運用・トラブルシューティング）** は、エンタープライズネットワーク環境（Cisco IOS XE / Catalyst 9000 シリーズ / ISR・ASR ルータ）において、障害発生時にデータプレーンおよびコントロールプレーンの動作を迅速に可視化し、根本原因を特定（Root Cause Analysis）するための高度な診断・キャプチャ・デバッグ技術群を網羅する最重要分野です。

CCIE EI ラボ試験では、複雑なトポロジ内で「パケットがどこで・なぜドロップしているのか」「プロトコルのネイバーがなぜ確立しないのか」「意図しないパスを経由している原因は何か」といった複合的トラブルを、機器の CPU やコントロールプレーンに過度な負荷をかけることなく、正確かつ迅速に隔離・解決するスキルが厳しく問われます。

本セクションで扱う主要技術要素は以下の通りです：

1. **Traffic Capture（トラフィックキャプチャ機能）**
   * **SPAN (Switched Port Analyzer):** 同一スイッチ内のローカルポート/VLAN トラフィックを別ポートへミラーリング。
   * **RSPAN (Remote SPAN):** 専用の L2 RSPAN VLAN を経由し、L2 スイッチ網を跨いで遠隔地の解析ポートへミラーリング。
   * **ERSPAN (Encapsulated Remote SPAN):** GRE トンネル（IP Protocol 47 / EtherType 0x88be）でパケットをカプセル化し、L3 ルーティング網を跨いで遠隔地のパケット解析サーバ（Wireshark 等）へ転送。
   * **EPC (Embedded Packet Capture):** 外部キャプチャ機器を使用せず、IOS XE 機器内部の DRAM バッファ上にデータプレーン/コントロールプレーンパケットを直接キャプチャし、PCAP 形式で保存・確認・エクスポート。

2. **Troubleshooting & Diagnostic Tools（高度診断ツール）**
   * **Datapath Packet Trace (IOS XE Packet Trace / `debug platform packet-trace`):** Cisco QFP (Quantum Flow Processor) パケット転送エンジン内で、パケットが入力（Ingress）されてから出力（Egress）または破棄（Drop）されるまでの全処理ステージとドロップ理由（Drop Reason）をマイクロ秒単位で完全追跡。
   * **Conditional Debugging（条件付きデバッグ / `debug platform condition`）:** 監視対象（IP アドレス、MAC アドレス、インターフェイス、VLAN、MPLS ラベル等）を条件フィルターとして指定し、大量のトラフィックが存在する環境でも目的のパケットログのみを選択的に抽出・表示。
   * **Radioactive Tracing (C3PL / Session Tracing):** Catalyst 9000 シリーズ（IOS XE Polaris）において、クライアントの MAC / IP アドレスをキーに、802.1X 認証・DHCP・AAA・QoS などの複数プロセスを横断してログを一元追跡。
   * **Core Dump & System Diagnostics (`crashinfo` / `exception dump`):** プロセス暴走やカーネルクラッシュ発生時に、DRAM メモリイメージ（Core Dump）やシステムログを Flash / 外部 TFTP サーバへ保存し、障害解析（Post-Mortem Analysis）を実施。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **主要技術** | SPAN, RSPAN, ERSPAN, EPC (Embedded Packet Capture), Datapath Packet Trace, Conditional Debug, Radioactive Tracing, Core Dump |
| **主な用途** | 通信障害の特定、パケットドロップ原因解析、プロトコルハンドシェイク検証、不当パケットの検出、CP/DP パス分離検証 |
| **メリット** | 外部のパケットキャプチャ専用ハードウェア（TAP 等）を接続することなく、ルータ/スイッチの CLI 上で高度なパケットレベルの解析が可能 |
| **デメリット/リスク** | キャプチャ設定や非条件デバッグ（`debug ip packet` 等）の不適切な運用により、CPU 高負荷・TCAM リソース枯渇・機器停止（Crash）を招くリスク |
| **対応機種** | Catalyst 9200/9300/9400/9500/9600 シリーズ, ISR 4000 シリーズ, ASR 1000 シリーズ, Catalyst 8000 エッジプラットフォーム (IOS XE 17.x) |
| **制限事項** | EPC バッファサイズ制限（DRAM 上限）、Datapath Packet Trace バッファ数制限（通常 1024〜4096 パケット）、ERSPAN カプセル化に伴う MTU オーバーヘッド（50 Bytes） |
| **設計上の注意点** | デバッグ実施時は必ず `debug platform condition` または ACL / Interface 条件をバインドすること。キャプチャバッファは Circular（循環）または Limit（上限指定）を適切に選択する |

---

## 🏗 動作原理

Cisco IOS XE アーキテクチャにおける Network Operations ツールの動作原理は、**Control Plane (RP: Route Processor)** と **Data Plane (FP: Forwarding Processor / QFP / ASIC FED)** の独立した 2 階層構造（Control/Data Plane Separation）に基づいています。

```
+-----------------------------------------------------------------------------------+
|                                CONTROL PLANE (RP)                                 |
|   +------------------+   +-------------------+   +----------------------------+   |
|   |   Syslog / CLI   |   |   EPC Capture     |   | Conditional Debug Control  |   |
|   |   Buffer Log     |   |   Buffer (PCAP)   |   | (debug platform condition) |   |
|   +--------^---------+   +---------^---------+   +-------------+--------------+   |
+------------|-----------------------|---------------------------|------------------+
             | (Punt / Control Log)  | (Punted PCAP)             | (Condition Sync)
+------------|-----------------------|---------------------------|------------------+
|            |                       |                           v                  |
|   +--------+--------+     +--------+--------+        +--------------------+       |
|   |  Ingress Port   |---->| Forwarding Engine------>|   Egress Port      |       |
|   |  (Phys / Sub)   |     | (QFP / ASIC FED) |        | (SPAN/RSPAN/ERSPAN)|       |
|   +-----------------+     +--------+--------+        +--------------------+       |
|                                    |                                              |
|                                    v (Drop / Trace)                               |
|                           +------------------+                                    |
|                           |  Datapath Packet |                                    |
|                           |  Trace Buffer    |                                    |
|                           +------------------+                                    |
|                                DATA PLANE (FP)                                    |
+-----------------------------------------------------------------------------------+
```

### 1. Traffic Capture の内部フロー

* **SPAN (Local SPAN):**
  ASIC（Switching Fabric / FED）内部で、指定された Source Port / VLAN の受信（Rx）または送信（Tx）フレームの複製（Copy）を作成し、ハードウェアワイヤスピードで Destination Port へ転送します。CPU (RP) に負荷をかけません。
* **RSPAN (Remote SPAN):**
  複製されたフレームに専用の RSPAN VLAN タグを付与し、L2 トランクリンクを経由して遠隔スイッチへマルチキャスト転送します。RSPAN VLAN 内では MAC アドレス学習が不活性化（Disabled）されます。
* **ERSPAN (Encapsulated Remote SPAN - Type II / Type III):**
  複製された L2 フレームを GRE トンネル（IP Protocol 47, EtherType 0x88be）でカプセル化します。Outer IP ヘッダーが付与されるため、一般的な L3 IP ネットワークを経由して遠隔の Wireshark アプライアンスや Catalyst スイッチへパケットを到達させることができます。
* **EPC (Embedded Packet Capture):**
  データプレーン（QFP / FED）を通過するパケット、またはコントロールプレーン（RP）宛てに Punt されるパケットを捕捉し、RP 上の DRAM 内に確保されたキャプチャバッファに `.pcap` 形式で蓄積します。

### 2. Datapath Packet Trace の内部フロー

* **QFP (Quantum Flow Processor) トラッキング:**
  IOS XE (ISR4000/ASR1000/Cat8000/Cat9000) では、パケットが QFP に入ると各処理ステージ（FIA: Feature Invocation Array）を通過します。
* Packet Trace を有効にすると、特定パケット（または全パケット）に対して以下の情報をバッファに記録します：
  1. **Input Stage:** 入力インターフェイス、L2/L3/L4 ヘッダー情報。
  2. **Feature Processing Stage:** ACL 評価、NAT 変換、QoS ポリシング、IPsec 暗号化、PBR 評価、VRF 検索などの実行結果。
  3. **Output / Drop Stage:** 出力インターフェイスの決定、またはドロップされた場合の **Exact Drop Reason（正確なドロップ理由：例 `IP ACL Dynamic Drop`, `RPF Failed`, `No Route`）**。

---

## ⚙ 動作シーケンス

### Sequence 1: Datapath Packet Trace (QFP Packet Trace) 実行シーケンス

```
[1. 条件定義] ──> Admin: "debug platform condition ipv4 10.1.1.1/32 both"
                        │
                        ▼ (条件を QFP Microcode へ動的アタッチ)
[2. トレース準備] ──> Admin: "debug platform packet-trace copy packet 2048 size 2048"
                        │
                        ▼ (QFP Packet Trace エンジン起動)
[3. パケット着信] ──> QFP Ingress: 監視対象パケット (10.1.1.1) が着信
                        │
                        ▼
[4. FIA 評価] ───> FIA (Feature Invocation Array) 各処理順序を実行:
                        ├─ ① Input ACL Evaluation -> PASS
                        ├─ ② Route Lookup (FIB) -> Next-hop 192.168.12.2
                        ├─ ③ NAT Translation -> 10.1.1.1 -> 172.16.1.1
                        └─ ④ Outbound ACL Evaluation -> DENY (Drop!)
                        │
                        ▼
[5. トレース記録] ──> QFP Buffer: Drop Reason "IP ACL Drop" と共にヘッダー/メタデータをサンプリング
                        │
                        ▼
[6. 結果表示] ───> Admin: "show platform packet-trace summary" & "show platform packet-trace packet 0"
                        └─ パケットの入力から破棄までの全過程が CLI に完全可視化される
```

### Sequence 2: Embedded Packet Capture (EPC) 実行シーケンス

```
[1. Buffer 作成] ──> "monitor capture CAP_1 buffer circular size 10" (10MB 循環バッファ)
                          │
                          ▼
[2. Point 作成] ───> "monitor capture CAP_1 interface GigabitEthernet0/0/1 both" (または control-plane)
                          │
                          ▼
[3. Filter 適用] ───> "monitor capture CAP_1 access-list ACL_CAPTURE" (対象プロトコル・IP に制限)
                          │
                          ▼
[4. キャプチャ開始] ─> "monitor capture CAP_1 start"
                          │
                          ▼ (パケット通過時に DRAM バッファへ PCAP 形式で記録)
[5. キャプチャ停止] ─> "monitor capture CAP_1 stop"
                          │
                          ▼
[6. 解析 & エクスポート] -> "show monitor capture CAP_1 buffer dump" または
                           "monitor capture CAP_1 export tftp://10.1.1.100/cap1.pcap"
```



## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、Network Operations (4.7) 関連のスキルは単体の問題として出題されるだけでなく、**タスク全体のトラブルシューティングおよび検証を成功させるための必須ツール**として機能します。

### 1. Blueprintで重要なポイント

1. **ドロップ原因の特定 (Datapath Packet Trace):**
   * 「R1 から R4 への通信が不通である原因を特定し修正せよ」という問題において、単なる PING や Traceroute では「どこで落ちているか」しか判明しません。
   * IOS XE の `debug platform condition` ＋ `debug platform packet-trace` を使用することで、QFP 転送プレーン内部で ACL、NAT、RPF Check、MTU mismatch、PBR のいずれによってドロップされているかを即座（数秒）に特定できます。

2. **コントロールプレーン通信の直接キャプチャ (EPC):**
   * 「BGP / OSPF / EIGRP / DHCP / LISP / VXLAN のハンドシェイクが失敗する原因を特定せよ」という問題において、EPC (Embedded Packet Capture) を使用して Control Plane パケットを直接サンプリングします。
   * Wireshark アプライアンスが接続されていない場合でも、`show monitor capture <NAME> buffer dump` コマンドで CLI 上で直接 Hex/ASCII パケット解析が可能です。

3. **安全なライブデバッグ (Conditional Debugging & Radioactive Tracing):**
   * ラボ環境において、条件を指定しない無制限の `debug ip packet` や `debug ip ospf packet` を実行すると、CPU 使用率が 100% に高騰し、VTY セッションが応答不全（Lockout）に陥る危険があります。
   * 必ず `debug platform condition interface` や `debug platform condition ipv4` でフィルターを設定した上でデバッグを有効化します。
   * Catalyst 9000 シリーズでの Dot1X / MAC 認証トラブルでは `debug platform condition feature dot1x target mac <MAC>` を用いた Radioactive Tracing が絶大な威力を発揮します。

4. **ERSPAN による遠隔ネットワークアナライザへの鏡像転送:**
   * 「HQ スイッチ Port Gi1/0/1 のトラフィックを Branch のパケット解析サーバ (10.2.2.100) へ ERSPAN ID 100 で転送せよ」といった直感的な標準設計要件が出題されます。

---

## 🛠 設定方法

### 1. Embedded Packet Capture (EPC) 完全構成例

```bash
! 1. キャプチャバッファの作成 (DRAM 上に 10MB の循環バッファを確保)
monitor capture CAP_OSPF buffer circular size 10

! 2. フィルタ用 Access-List の定義 (OSPF 通信 224.0.0.5 / 224.0.0.6 および Unicast OSPF)
ip access-list extended ACL_EPC_OSPF
 permit ospf any any
 permit ip any host 224.0.0.5
 permit ip any host 224.0.0.6

! 3. キャプチャバッファへのフィルタ適用
monitor capture CAP_OSPF access-list ACL_EPC_OSPF

! 4. キャプチャポイントのバインド (コントロールプレーンまたは物理インターフェイス)
monitor capture CAP_OSPF interface GigabitEthernet0/0/1 both

! 5. キャプチャ開始
monitor capture CAP_OSPF start

! --- (トラフィック発生・検証) ---

! 6. キャプチャ停止
monitor capture CAP_OSPF stop

! 7. CLI 上でのパケット表示 (Brief または Detailed Dump)
show monitor capture CAP_OSPF buffer brief
show monitor capture CAP_OSPF buffer dump

! 8. 外部 TFTP/FTP サーバへのエクスポート (.pcap 形式)
monitor capture CAP_OSPF export tftp://192.168.1.100/cap_ospf.pcap
```

### 2. IOS XE Datapath Packet Trace (QFP Packet Trace) 構成例

```bash
! 1. 追跡対象の条件 (Condition) を設定 (例: IP 10.1.100.1 宛て/送信元の双方向パケット)
debug platform condition ipv4 10.1.100.1/32 both

! 2. Packet Trace パラメータの設定 (最大 2048 パケット、1 パケットあたり 2048 バイトコピー)
debug platform packet-trace copy packet 2048 size 2048

! 3. Packet Trace 機能を有効化
debug platform packet-trace enable

! --- (テストパケット送信: PING 10.1.100.1 等) ---

! 4. サマリ確認 (ドロップされたパケットの ID や結果を一覧表示)
show platform packet-trace summary

! 5. 特定パケットの個別詳細追跡 (FIA 各ステージとドロップ理由を表示)
show platform packet-trace packet 0

! 6. デバッグおよび条件の完全解除 (必須作業)
no debug platform packet-trace enable
clear platform condition all
```

### 3. ERSPAN (Encapsulated Remote SPAN Type II / Type III) 構成例

```bash
! === 送信側スイッチ/ルータ (ERSPAN Source) ===
monitor session 1 type erspan-source
 description *** ERSPAN to Central Wireshark Server ***
 source interface GigabitEthernet1/0/10 both
 destination
  erspan-id 100
  ip ttl 64
  origin ip-address 10.1.1.1
  ip address 10.2.2.100

! === 受信側スイッチ (ERSPAN Destination) ===
monitor session 1 type erspan-destination
 description *** ERSPAN Receiver Port ***
 destination interface GigabitEthernet1/0/48
 source
  erspan-id 100
  ip address 10.2.2.100
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| EPC バッファ状態確認 | <code>show monitor capture</code> |
| EPC キャプチャ内容表示 (サマリ) | <code>show monitor capture &lt;NAME&gt; buffer brief</code> |
| EPC キャプチャ内容表示 (Hex/ASCII Dump) | <code>show monitor capture &lt;NAME&gt; buffer dump</code> |
| Datapath Packet Trace サマリ確認 | <code>show platform packet-trace summary</code> |
| Datapath Packet Trace 特定パケット詳細表示 | <code>show platform packet-trace packet &lt;ID&gt;</code> |
| 設定中のデバッグ条件確認 | <code>show platform condition</code> |
| 有効化されているデバッグの確認 | <code>show debug</code> |
| SPAN / RSPAN / ERSPAN セッション状態表示 | <code>show monitor session all</code> |
| システム Crashinfo ログ表示 | <code>show logging onboard switch &lt;ID&gt; clilog detail</code> |
| コアファイル存在確認 | <code>dir crashinfo:</code> / <code>dir flash:core/</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **EPC でパケットが一切キャプチャされない** | ① キャプチャポイント未バインド<br>② ACL の条件ミスマッチ<br>③ `start` コマンドの打ち忘れ | <code>show monitor capture</code> | インターフェイスバインド (`interface <IF> both`) と ACL 設定を再確認し、`monitor capture <NAME> start` を実行する |
| **Datapath Packet Trace にパケットが記録されない** | ① `debug platform condition` の IP/Interface 条件不一致<br>② `debug platform packet-trace enable` の未実行 | <code>show platform condition</code> | `show platform condition` で条件が正しくセットされているか確認し、`debug platform packet-trace enable` を投入する |
| **デバッグ実行後に CPU が 100% に高騰し応答停止** | 条件フィルターなしで `debug ip packet` や `debug ip ospf hello` を直接実行した | <code>show processes cpu sorted</code> | コンソールから `undebug all` または `no debug all` を実行。予防策として必ず `debug platform condition` を事前定義する |
| **ERSPAN パケットがアナライザ宛てに届かない** | ① L3 ルーティング不通<br>② ERSPAN ID の送信/受信側ミスマッチ<br>③ 途中の FW/ACL で IP Protocol 47 (GRE) が遮断 | <code>ping &lt;DEST_IP&gt;</code><br><code>show monitor session 1</code> | `origin ip-address` と `ip address` 間で L3 到達性を確認し、ERSPAN ID を統一。GRE (Protocol 47) 通過を許可する |
| **大型パケットが ERSPAN 経由でドロップする** | GRE カプセル化による MTU オーバーヘッド (50 Bytes) で Path MTU を超過した | <code>show interface</code> | インターフェイス MTU を 1550 へ拡大するか、DF ビットをクリアしてフラグメンテーションを許可する |



## ⚠ 制限事項

### 1. Embedded Packet Capture (EPC) の制限事項
* **キャプチャバッファ上限:** EPC バッファはルータ/スイッチの DRAM 上に作成されるため、デフォルトサイズは通常数 MB（最大 100MB 程度）に制限されます。大量のトラフィックが存在するインターフェイスでキャプチャを行うと、数分でバッファが満杯（Buffer Full）になります。
* **CPU スイッチドパケット (Punted Traffic):** コントロールプレーン宛て（Punt 通信）以外の超高速ハードウェアアシストデータプレーンパケット（ASIC CEF Forwarded）をキャプチャする場合、一部のプラットフォームではサンプリング漏れが発生する可能性があります。

### 2. Datapath Packet Trace の制限事項
* **バッファパケット数:** QFP Packet Trace バッファ内に保持できるトレースデータは、デフォルトで 1024〜2048 パケットまでです。条件指定を行わないと、ミリ秒単位でバッファが上書きされて目的のパケットログが消失します。
* **プラットフォーム依存:** Datapath Packet Trace (`debug platform packet-trace`) は、QFP 転送エンジンを搭載する IOS XE 機器（ISR 4000, ASR 1000, Cat 8000, Cat 9000）でのみ利用可能です。旧式の IOS (12.4/15.x Classic) や Catalyst 3750/3850 の一部レガシーコードでは使用できません。

### 3. ERSPAN の制限事項
* **カプセル化オーバーヘッド:** ERSPAN は元の L2 フレーム全体を GRE (IP Protocol 47) ヘッダー（24 Bytes）＋ Outer IP ヘッダー（20 Bytes）＋ ERSPAN Header (8 Bytes) で包むため、最低 **50 Bytes の追加オーバーヘッド**が発生します。MTU 1500 Bytes の標準ポートで 1500 Bytes のパケットをキャプチャすると、1550 Bytes に膨れ上がりフラグメンテーションが発生するか、DF ビットがセットされている場合破棄されます。
* **セッション数制限:** 同一スイッチ上で有効化できる同時 SPAN / RSPAN / ERSPAN セッション数は、ハードウェア ASIC 制限（通常最大 2〜8 セッション）により厳格に上限が定められています。

---

## 🔄 他技術との関連

* **Control Plane Policing (CoPP):**
  EPC や Control-Plane Debug を実施する際、CoPP ポリサーによって CPU 宛て Punt パケットがレート制限（Rate-Limited）されていると、キャプチャバッファに全パケットが届かない場合があります。トラブルシューティング時は CoPP のドロップカウンター (`show policy-map control-plane`) も併せて検証します。
* **Access Control Lists (ACL) & Firewall:**
  Datapath Packet Trace を使用すると、パケットがどの ACL (Inbound / Outbound ACL) や Zone-Based Firewall (ZBFW) ポリシーのどの行 (ACE: Access Control Entry) によって拒否（Drop）されたかが直接表示されます。
* **QoS (Policing & Shaping):**
  QoS ポリサーによってドロップされたパケット（Exceed / Violate Drop）も、Datapath Packet Trace 上で `QoS Policing Drop` として明確に区別して検出可能です。
* **IPsec & GRE Tunnels:**
  暗号化トンネル環境において、カプセル化前の内部 IP パケットとカプセル化後の外部 IP パケットの両方を Packet Trace や EPC で個別に追跡可能です。

---

## 🧩 比較表

### 1. トラフィックキャプチャ機能の比較 (SPAN vs RSPAN vs ERSPAN vs EPC)

| 項目 | SPAN (Local) | RSPAN | ERSPAN | EPC (Embedded) |
| --- | --- | --- | --- | --- |
| **キャプチャ範囲** | 同一スイッチ内 | 同一 L2 放送ドメイン内 | L3 ネットワーク全域 (IP Routed) | 機器ローカル (RP/FP) |
| **転送方式** | ハードウェア複製 | 専用 RSPAN VLAN (L2) | GRE トンネル (IP Protocol 47) | DRAM バッファ蓄積 |
| **外部アナライザ** | **必須** (Port 直結) | **必須** (遠隔 Port 直結) | **必須** (IP 到達可能な PC) | **不要** (CLI 表示 / PCAP 出力) |
| **オーバーヘッド** | なし | L2 VLAN タグ (4B) | **50 Bytes** (GRE+IP+ERSPAN) | RP CPU / DRAM 消費 |
| **L3 跨ぎ** | 不可 | 不可 | **可能** | **可能** |
| **主用途** | ローカル即時解析 | スイッチ網内キャプチャ | データセンター/遠隔拠点解析 | ラボ・現場での自己完結解析 |

### 2. トラブルシューティング診断ツールの比較

| ツール名 | 動作レイヤー | 主な表示内容 | CPU 負荷リスク | 最適な利用シーン |
| --- | --- | --- | --- | --- |
| **Standard Debug** (`debug ip packet`) | RP (Control Plane) | パケット基本ヘッダー (Src/Dst/Len) | **極めて高い** (Crash 危険) | 低トラフィック実験環境 |
| **Conditional Debug** (`debug platform condition`) | FP / RP フィルター | 監視対象のみに限定されたデバッグ | **極めて低い** (安全) | 本番/ラボでの特定フロー解析 |
| **Datapath Packet Trace** (`debug platform packet-trace`) | QFP Data Plane | FIA 処理ステージ, Exact Drop Reason | **低〜中** | パケット不通・ドロップ原因の特定 |
| **Radioactive Tracing** | C3PL / Multi-Process | Client ID に紐づく全プロセスログ | **極めて低い** | Dot1X / Wireless / AAA 認証解析 |

---

## 💡 ベストプラクティス

1. **デバッグ実行前の絶対原則（Safety First）:**
   * 本番環境および CCIE ラボ試験において、条件指定なしの `debug ip packet` や `debug all` は絶対に投入しないこと。
   * デバッグを実行する際は、必ず事前に **`debug platform condition ipv4 <IP> both`** または **`debug platform condition interface <IF>`** を設定し、出力を 1 つのフローに限定する。

2. **トラブルシューティング時の 3 段階アプローチ:**
   * **Stage 1 (確認):** `ping` および `traceroute` で不通箇所の大まかなセグメントを特定する。
   * **Stage 2 (キャプチャ/トレース):** `debug platform condition` + `debug platform packet-trace` を有効化し、QFP 内部のドロップ理由（ACL drop, Route drop, RPF drop 等）を特定する。
   * **Stage 3 (ハンドシェイク解析):** プロトコル挙動に問題がある場合、EPC (Embedded Packet Capture) を起動して制御パケットのフォーマットを `.pcap` 形式で詳細分析する。

3. **デバッグ終了後のクリーンアップの徹底:**
   * トラブルシューティング完了後は、直ちに **`undebug all`** (または `un all`) および **`clear platform condition all`** を実行し、トレースメモリとフィルタ条件を完全に消去すること。



## 📝 ラボ学習・設定サンプル例

CCIE EI v1.1 ラボ試験レベルの実践的な Network Operations 設定・トラブルシューティングシナリオを 10 個作成しました。すべてのコンフィグ例および検証コマンドは省略せず完全な形で記述しています。

---

### シナリオ 1: SPAN (Local SPAN) による特定 VLAN パケットの802.1Qタグ保持キャプチャ

#### 【問題】
SW1 において、VLAN 10 を通過する全ての送受信トラフィックを、ネットワークアナライザが接続された Gi1/0/24 ポートへミラーリングしてください。

#### 【要件】
* SPAN セッション ID は `1` を使用すること。
* 対象 VLAN は `VLAN 10` (Rx/Tx 両方向) とすること。
* Destination ポート Gi1/0/24 へ転送するパケットには、元の 802.1Q VLAN タグをそのまま保持（Preserve）させて出力すること。

#### 【設定例】
```bash
! SW1 上での設定
monitor session 1 source vlan 10
monitor session 1 destination interface GigabitEthernet1/0/24 encapsulation replicate
```

#### 【検証方法】
```bash
SW1# show monitor session 1
Session 1
---------
Type                   : Local Session
Source VLANs           : 10
    RX Only            : None
    TX Only            : None
    Both               : 10
Destination Ports      : Gi1/0/24
    Encapsulation      : Replicate
    Ingress            : Disabled
```

---

### シナリオ 2: RSPAN (Remote SPAN) による複数 L2 スイッチ跨ぎキャプチャ

#### 【問題】
SW1 (Access) のポート Gi1/0/5 の受信トラフィックを、SW2 (Core) の分析ポート Gi1/0/12 へ L2 スイッチ網を跨いでキャプチャ転送してください。

#### 【要件】
* RSPAN 専用 VLAN として `VLAN 999` を作成し、スイッチ網全体で `remote-span` として定義すること。
* SW1 上で RSPAN Source Session 10 を構成し、Gi1/0/5 rx を対象とすること。
* SW2 上で RSPAN Destination Session 10 を構成し、Gi1/0/12 へ出力すること。

#### 【設定例】
```bash
! SW1 および SW2 で共通作成
vlan 999
 name RSPAN_VLAN
 remote-span

! SW1 (Source Switch)
monitor session 10 type rspan-source
 source interface GigabitEthernet1/0/5 rx
 destination remote vlan 999

! SW2 (Destination Switch)
monitor session 10 type rspan-destination
 source remote vlan 999
 destination interface GigabitEthernet1/0/12
```

#### 【検証方法】
```bash
SW1# show vlan id 999
VLAN Name                             Status    Ports
---- -------------------------------- --------- -------------------------------
999  RSPAN_VLAN                       active    

SW2# show monitor session 10
Session 10
----------
Type                   : Remote Destination Session
Source RSPAN VLAN      : 999
Destination Ports      : Gi1/0/12
```

---

### シナリオ 3: ERSPAN Type II による L3 ネットワーク跨ぎ分析ポート転送

#### 【問題】
R1 (HQ) の Gi0/0/1 の送受信トラフィックを、L3 WAN 網を跨いだ遠隔拠点にある Wireshark アナライザ (10.200.1.50) 宛てに ERSPAN で転送してください。

#### 【要件】
* ERSPAN ID は `100` とする。
* Origin IP アドレス（送信元）は R1 の Loopback0 (`10.100.1.1`) を使用すること。
* Destination IP は `10.200.1.50` とすること。

#### 【設定例】
```bash
! R1 (HQ Router) 上での設定
monitor session 1 type erspan-source
 description *** ERSPAN to Remote Wireshark Server ***
 source interface GigabitEthernet0/0/1 both
 destination
  erspan-id 100
  ip ttl 64
  origin ip-address 10.100.1.1
  ip address 10.200.1.50
```

#### 【検証方法】
```bash
R1# show monitor session 1
Session 1
---------
Type                   : ERSPAN Source Session
Status                 : Admin Enabled
Source Ports           : 
    RX Only            : None
    TX Only            : None
    Both               : Gi0/0/1
Destination IP Address : 10.200.1.50
Destination ERSPAN ID  : 100
Origin IP Address      : 10.100.1.1
```

---

### シナリオ 4: EPC (Embedded Packet Capture) による Control Plane (BGP) パケットの直接サンプリング

#### 【問題】
R2 において、BGP ピア (192.168.12.1) との間で交換される TCP 179 (BGP) パケットのみをコントロールプレーンでキャプチャし、CLI 上で確認できるようにしてください。

#### 【要件】
* キャプチャ名は `CAP_BGP` とする。
* バッファサイズは `5MB` とし、上限に達したら上書きする `circular` モードとすること。
* フィルタ ACL で TCP ポート 179 通信のみに厳格に制限すること。
* Control-Plane 宛てのパケットを捕捉すること。

#### 【設定例】
```bash
! 1. フィルタ ACL
ip access-list extended ACL_CAP_BGP
 permit tcp any host 192.168.12.1 eq bgp
 permit tcp host 192.168.12.1 eq bgp any

! 2. キャプチャバッファ作成
monitor capture CAP_BGP buffer circular size 5
monitor capture CAP_BGP access-list ACL_CAP_BGP

! 3. コントロールプレーンへアタッチ
monitor capture CAP_BGP control-plane both

! 4. キャプチャ開始
monitor capture CAP_BGP start
```

#### 【検証方法】
```bash
! キャプチャサマリの確認
R2# show monitor capture CAP_BGP buffer brief

! Hex/ASCII 詳細ダンプ表示
R2# show monitor capture CAP_BGP buffer dump
```

---

### シナリオ 5: EPC キャプチャバッファの外部 TFTP サーバへのエクスポート (.pcap)

#### 【問題】
キャプチャ名 `CAP_FULL` で蓄積されたパケットデータを停止し、外部の TFTP サーバ (`10.1.1.250`) へ `capture_branch.pcap` というファイル名でエクスポートしてください。

#### 【要件】
* キャプチャを安全に停止した上でエクスポートを実行すること。
* エクスポートフォーマットは標準的な Wireshark 互換 `.pcap` 形式とすること。

#### 【設定例】
```bash
! 1. キャプチャ停止
monitor capture CAP_FULL stop

! 2. TFTP サーバへエクスポート
monitor capture CAP_FULL export tftp://10.1.1.250/capture_branch.pcap
```

#### 【検証方法】
```bash
R1# show monitor capture CAP_FULL
! (Status が Stopped になっていることを確認)
```




### シナリオ 6: Datapath Packet Trace (QFP Packet Trace) による QFP パケットドロップ理由の特定

#### 【問題】
R3 を通過する PC-A (`10.1.10.50`) から Server-B (`172.16.20.100`) 宛てのパケットが不通となっています。QFP Packet Trace 機能を使用して、パケットがどの処理ステージで・なぜドロップされたかを特定してください。

#### 【要件】
* 条件 (Condition) として、送信元 `10.1.10.50` / 宛先 `172.16.20.100` の双方向通信を指定すること。
* 1024 パケット分のフルコピーを設定すること。
* パケットトレースを有効化してテスト PING を送信後、正確な Drop Reason を特定すること。

#### 【設定例】
```bash
! 1. トレース条件の定義
debug platform condition ipv4 10.1.10.50/32 host 172.16.20.100/32 both

! 2. トレースパラメータ指定および有効化
debug platform packet-trace copy packet 1024 size 2048
debug platform packet-trace enable

! --- (PC-A より PING 送信実行) ---

! 3. トレースサマリの表示
show platform packet-trace summary

! 4. ドロップされたパケット ID (例: Packet 0) の詳細解析
show platform packet-trace packet 0
```

#### 【検証方法】
```bash
R3# show platform packet-trace packet 0
Packet: 0           C3-FD Input: GigabitEthernet0/0/1
  State: DROP
  Absolute-Time: 10/28/2026 03:30:12.120
  Summary:
    Input: GigabitEthernet0/0/1
    Output: GigabitEthernet0/0/2
    State: DROP
    Drop Reason: IP ACL Dynamic Drop (ACL_BLOCK_DATA Line 3)
```

---

### シナリオ 7: Conditional Debugging による OSPF ネイバー不確立問題の限定安全デバッグ

#### 【問題】
R4 の Gi0/0/2 ポート経由での OSPF アジャセンシー確立失敗の原因を調査してください。高負荷を防止するため、Gi0/0/2 インターフェイス通過パケットのみにデバッグ出力を限定してください。

#### 【要件】
* `debug platform condition interface GigabitEthernet0/0/2` を使用して条件を設定すること。
* 1 つ以上の条件がアクティブな状態で OSPF Hello および Packet デバッグを起動すること。
* 検証完了後は条件およびデバッグを完全にクリーンアップすること。

#### 【設定例】
```bash
! 1. 条件の設定
debug platform condition interface GigabitEthernet0/0/2

! 2. デバッグの有効化
debug ip ospf hello
debug ip ospf packet

! --- (ログ確認後) ---

! 3. 完全クリーンアップ
undebug all
clear platform condition all
```

#### 【検証方法】
```bash
R4# show platform condition
Condition 1: interface GigabitEthernet0/0/2 (1 flags triggered)

R4# show debug
OSPF:
  OSPF hello debugging is on
  OSPF packet debugging is on
```

---

### シナリオ 8: Radioactive Tracing による Catalyst 9300 Dot1X / MAC 認証セッションの全行程追跡

#### 【問題】
SW1 (Catalyst 9300) に接続された クライアント PC (MAC: `0011.2233.4455`) の 802.1X 認証が失敗します。Radioactive Tracing を使用して、EAPOL 交換、RADIUS リクエスト、および認証失敗ログを一元抽出してください。

#### 【要件】
* 追跡ターゲットとして MAC アドレス `0011.2233.4455` を指定すること。
* ログレベルを `debug` に設定してセッションを追跡すること。
* 追跡ログを Flash 上のテキストファイルに生成・表示すること。

#### 【設定例】
```bash
! 1. トレースターゲットの条件セット
debug platform condition feature dot1x target mac 0011.2233.4455

! 2. ログ生成と表示
show logging profile status
! (クライアントを再認証させる: clear access-session mac 0011.2233.4455)

! 3. トレースファイルの生成と CLI 表示
request platform software trace archive
```

#### 【検証方法】
```bash
SW1# show platform software trace message switch active R0
```

---

### シナリオ 9: 機器クラッシュ解析用の System Core Dump ＆ Crashinfo 構成

#### 【問題】
R5 において、将来的なプロセスクラッシュ発生時に完全に解読可能な Core Dump メモリイメージを外部 FTP サーバ (`10.1.1.200`) へ自動保存するよう構成してください。

#### 【要件】
* 例外クラッシュ発生時に `exception dump` 機能を起動すること。
* サーバ IP `10.1.1.200`、プロトコル `ftp` を指定すること。
* 保存ディレクトリとして `/cores/` を指定すること。

#### 【設定例】
```bash
! R5 上での設定
exception protocol ftp
exception dump 10.1.1.200
exception core-file-path /cores/r5_core.dmp
```

#### 【検証方法】
```bash
R5# show exception
Exception dump protocol is ftp
Exception dump server is 10.1.1.200
Core file path is /cores/r5_core.dmp
```

---

### シナリオ 10: 複合トラブルシューティング: VRF 間通信ドロップの完全特定ワークフロー

#### 【問題】
R6 において `VRF_RED` から `VRF_BLUE` への Route Leaking 後、特定クライアント (`10.10.1.10`) からのパケットが宛先 (`10.20.1.20`) へ到達しません。インフラ運用ツールを駆使して障害箇所を特定・修復してください。

#### 【要件】
1. `debug platform condition` で送信元 `10.10.1.10` / 宛先 `10.20.1.20` をバインドする。
2. Datapath Packet Trace でドロップステージを解析する。
3. ドロップ理由（例: `VRF Reverse Path Filter Fail` または `PBR Drop`）を突き止め、適切な VRF ルート/ACL 補正を行う。

#### 【設定例】
```bash
! 1. 条件定義
debug platform condition ipv4 10.10.1.10/32 host 10.20.1.20/32 both

! 2. Packet Trace 有効化
debug platform packet-trace copy packet 1024 size 2048
debug platform packet-trace enable

! --- (PING 10.20.1.20 実行) ---

! 3. 結果確認
show platform packet-trace summary
show platform packet-trace packet 0

! 4. トレース解除
no debug platform packet-trace enable
clear platform condition all
```

#### 【検証方法】
```bash
R6# show platform packet-trace packet 0
  Drop Reason: IP RPF Failed (uRPF Check failure on VRF_BLUE)
```

---

## ❓ 想定試験問題

CCIE EI Practical Lab 試験を想定した実践的な問題を 8 問掲載します。

### 問 1 (Datapath Packet Trace による ACL ドロップ解析)
* **質問:** R1 から R3 宛ての ICMP パケットが不通となっています。PING を送信しても理由コードが表示されません。QFP 転送プレーン内部でどの ACL の何行目でドロップされているかを判断するために最も迅速な一連のコマンドは何ですか？
* **回答:**
  1. `debug platform condition ipv4 <R1_IP>/32 host <R3_IP>/32 both`
  2. `debug platform packet-trace copy packet 1024 size 2048`
  3. `debug platform packet-trace enable`
  4. PING 実行後、`show platform packet-trace packet 0` を確認する。出力内の `Drop Reason: IP ACL Dynamic Drop (<ACL_NAME> Line X)` により、特定 ACL の特定行を直接識別できます。

### 問 2 (EPC フィルタリング設計)
* **質問:** コントロールプレーン上で大量の OSPF Hello パケットが交わされる中、特定の BGP Open メッセージのみを EPC でキャプチャしたい場合、どのようなキャプチャ設定手順が必要ですか？
* **回答:**
  1. 目的の TCP ポート 179 (BGP) のみを許可する Access-List (例: `ip access-list extended ACL_BGP_ONLY permit tcp any any eq 179`) を作成する。
  2. `monitor capture CAP1 buffer circular size 10` でバッファを作成し、`monitor capture CAP1 access-list ACL_BGP_ONLY` をアタッチする。
  3. `monitor capture CAP1 control-plane both` で Control-Plane にバインドして `start` を実行する。これにより OSPF パケットは ACL でフィルタされてバッファから除外されます。

### 問 3 (ERSPAN MTU & Overhead 計算)
* **質問:** 標準 MTU 1500 バイトのインターフェイス上で 1500 バイトの完全サイズパケットを ERSPAN で送出すると、キャプチャアナライザ側でパケットが受信できません。技術的な理由と解決策を説明してください。
* **回答:**
  ERSPAN は元の L2 フレームに GRE ヘッダー、Outer IP ヘッダー、ERSPAN ヘッダーを加えるため、約 50 バイトの追加オーバーヘッドが発生し、送信パケットサイズが 1550 バイトへ肥大化します。物理リンクで DF (Don't Fragment) ビットがセットされている場合、MTU 超過で破棄されます。解決策として、中継ネットワークの MTU を 1550 以上（Jumbo Frame）に拡大するか、ERSPAN 送信元で Path MTU 設定を調整します。

### 問 4 (Conditional Debugging の安全設計)
* **質問:** 10,000 pps のデータトラフィックが流れるルータ上で、特定の BGP ピア (10.1.1.2) とのデバッグログを安全に確認する方法を記述してください。
* **回答:**
  `debug platform condition ipv4 10.1.1.2/32 both` を事前定義した上で `debug ip bgp updates` を起動します。これにより、QFP/RP ログフィルターが適用され、10.1.1.2 以外の 10,000 pps の非関連トラフィックはデバッグエンジンを通過する前に完全に破棄され、CPU 高騰を防ぐことができます。

### 問 5 (Radioactive Tracing の概念)
* **質問:** Catalyst 9300 スイッチにおいて、特定の端末が Dot1X 認証から DHCP アドレス取得に至るシーケンスで失敗しています。異なるプロセスのログを時間軸で統合追跡するコマンド手順を挙げてください。
* **回答:**
  `debug platform condition feature dot1x target mac <MAC_ADDR>` を設定して Radioactive Tracing を有効化し、端末を再接続させた後、`request platform software trace archive` コマンドで全プロセス（Authc, AAA, DHCP, SXP）を結合したタイムスタンプ付き統合トレースログを生成・確認します。

### 問 6 (SPAN vs RSPAN vs ERSPAN の選定基準)
* **質問:** 遠隔拠点の Branch ルータで発生している障害パケットを、HQ データセンターの Wireshark アナライザ (IP: 10.100.1.50) で直接リアルタイム受信したい場合、SPAN/RSPAN/ERSPAN のうちどれを選定すべきですか？理由と共に回答してください。
* **回答:**
  **ERSPAN** を選定します。Branch と HQ 間は L3 IP 網で隔てられているため、L2 限定の SPAN / RSPAN ではパケットを転送できません。ERSPAN は GRE トンネル（IP カプセル化）を使用するため、標準の IP ルーティング網を通過して HQ アナライザへ到達可能です。

### 問 7 (Datapath Packet Trace の FIA ステージ)
* **質問:** Datapath Packet Trace の出力において、`FIA (Feature Invocation Array)` とは何を意味しますか？
* **回答:**
  Cisco IOS XE の QFP パケット転送エンジン内で、パケットに対して順次適用される機能パイプライン（ACL, NAT, QoS, PBR, Crypto, RPF, FIB 検索等）の配列処理シーケンスを意味します。各機能処理の適用結果とドロップポイントが可視化されます。

### 問 8 (CoPP と EPC の相互作用)
* **質問:** EPC で Control Plane トラフィックをキャプチャしている際、大量のパケットがキャプチャバッファに漏れる現象が発生しました。CoPP (Control Plane Policing) との関係を説明してください。
* **回答:**
  CoPP は Control Plane (RP) 宛てのパケット量をハードウェア段階で制限します。トラフィック量が CoPP ポリサーの CIR を超過している場合、パケットは RP 内の EPC キャプチャバッファに到達する前に CoPP によってドロップされます。キャプチャ精度を上げるには、一時的に CoPP ポリサーのレートを緩和するか、Datapath Packet Trace で Drop 箇所を確認します。

---

## 🔗 参考リソース

* Cisco Official Configuration Guide: Network Operations and Diagnostics CLI Guide, Cisco IOS XE 17.x
* Cisco Live Presentation: Overview of Packet Capturing Tools in Cisco Switches and Routers – BRKTRS-2811
* Cisco Official Guide: Embedded Packet Capture (EPC) Configuration Guide for Cisco IOS XE
* Cisco Technical Note: Troubleshoot with the IOS-XE Datapath Packet Trace Feature
* Cisco Technical Note: Conditional Debug and Radioactive Tracing on Catalyst 9000 Switches
* Cisco Command Reference: debug platform condition & debug platform packet-trace Command Reference
* Cisco Validated Design (CVD): Campus Network Diagnostic and Operations Best Practices Guide

---

## 📝 **補足（Notes）**

### 1. ラボ試験での障害解析スピードアップ極意
* **即座に条件を絞る:** 原因不明のドロップに遭遇したら、迷わず `debug platform condition ipv4 <SRC> host <DST> both` ➔ `debug platform packet-trace copy packet 1024 size 2048` ➔ `debug platform packet-trace enable` を投入してください。数十秒で「ACL 拒否」「uRPF 破棄」「Route 欠落」「NAT 失敗」のいずれかであるかが一目瞭然となります。
* **忘れがちな `clear platform condition all`:** トラブルシューティング終了後に条件を削除し忘れると、後のタスクで予期せぬログ混入やデバッグ不全の原因となります。作業完了後のクリーンアップを習慣化してください。

### 2. コマンド一発クリアショートカット
* 全デバッグ停止: `undebug all` (省略形 `un all`)
* 全条件削除: `clear platform condition all`
* 全キャプチャ停止・削除: `monitor capture <NAME> stop` ➔ `no monitor capture <NAME>`

