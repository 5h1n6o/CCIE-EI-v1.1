---
layout: default
title: 4.7.b-Troubleshooting-tools
parent: 4.7-Network-operations
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.7.b Troubleshooting tools

CCIE EI v1.1 Blueprint における **`4.7.b Troubleshooting tools`**（Data path packet trace および Conditional debugger）は、Cisco IOS XE 装置（ISR/ASR/Catalyst 9000 シリーズ）上で発生する高度なパケットドロップ問題、転送パス異常、コントロールプレーン/データプレーン連携障害を迅速に診断・修正するための最重要デバッグ・トレース解析フレームワークです。

本ドキュメントでは、QFP（Quantum Flow Processor）内部のパケット処理パイプラインを可視化する **Data path packet trace（`debug platform packet-trace`）** と、高負荷なプロダクション環境で CPU 枯渇を起こさずに特定のトラフィックフローのみを条件抽出・デバッグする **Conditional debugger（`debug platform condition` / Radioactive Tracing）** について、Cisco IOS XE 17.x の最新仕様に基づき網羅的に解説します。

---

## 📘 概要

### 1. Data Path Packet Trace (QFP Packet Trace)
Data path packet trace は、Cisco IOS XE のパケット転送エンジンである QFP（Quantum Flow Processor）内を通過する個々のパケットの挙動を、マイクロ秒単位で完全追跡（Trace）する機能です。パケットがルータに入力されてから出力（またはドロップ）されるまでに通過したすべての機能ステージ（FIA: Feature Invocation Array）と、ドロップ時の「正確なドロップ理由（Exact Drop Reason）」および「パケットペイロードの完全なデコード結果」を出力できます。

* **主な利用目的:** パケットがルータ内部で静かに破棄される「サイレントドロップ（Silent Drop）」や、ACL・PBR・QoS・NAT・IPsec などの機能でどのステージで処理またはドロップされたかを特定する。
* **適用場面:** PING が到達しない、IPsec VPN トンネル内でパケットが消失する、NAT 変換後にパケットが転送されない、QoS ポリシングで破棄されたかを検証する場面。

### 2. Conditional Debugger (`debug platform condition`)
Conditional debugger は、特定の条件（送信元/宛先 IP アドレス、サブネット、物理/論理インターフェイス、MAC アドレスなど）に合致するパケットやセッションのみをデバッグ対象としてフィルター適用する機能です。

* **主な利用目的:** 数十 Gbps のトラフィックが行き交うプロダクション環境において、従来型の `debug ip packet` や `debug ip ospf events` を実行した際に発生する CPU 100% 高騰（Console/VTY ロックアウト）を回避し、診断対象の単一フローログのみを安全に採取する。
* **適用場面:** Catalyst 9000 や ASR/ISR ルータ上で、特定のクライアントの 802.1X 認証・DHCP 取得・OSPF/BGP ネイバー形成・IPsec パケット交換ログをピンポイントでデバッグ採取する場面。

---

## 🔑 要点

| 項目 | Data Path Packet Trace (`debug platform packet-trace`) | Conditional Debugger (`debug platform condition`) |
| :--- | :--- | :--- |
| **主な機能** | QFP 内のパケット転送パス（FIA ステージ）およびドロップ原因の可視化 | 特定の条件（IP/MAC/Interface）に限定した安全なデバッグ実行 |
| **対象レイヤー** | データプレーン（QFP Forwarding Engine） | コントロールプレーン ＆ データプレーン両領域 |
| **ドロップ解析** | 可能（Exact Drop Reason、FIA Stage、Packet Copy 解読） | 直接のパケットドロップ判定は不可（ログメッセージ出力のみ） |
| **条件フィルター** | Conditional Debugger (`debug platform condition`) と連動 | 単体で IP/MAC/Interface などのフィルター条件を保持 |
| **パケット保持** | メモリバッファ（Packet Summary / Packet Copy）に記録 | Syslog / Logging Buffer / RadioActive Trace に出力 |
| **CPU 負荷** | 極めて低い（QFP マイクロコードレベルで直接処理） | 非常に低い（条件外のデバッグログ生成を瞬時に抑止） |
| **対応機種** | Cisco ISR 4000, ASR 1000, Catalyst 8000/9000 シリーズ (IOS XE) | Cisco Catalyst 9000, ISR 4000, ASR 1000, Catalyst 8000 シリーズ |
| **制限事項** | 大量パケットサンプリング時はバッファ循環上書きに注意 | 条件クリア（`clear platform condition all`）を忘れるとログ混同 |
| **設計上の注意** | `copy packet` 有効化時はパケットバイト長（例: 2048）に留意 | 条件定義後に必ず `debug platform condition start` で開始 |

---

## 🏗 動作原理

### 1. Data Path Packet Trace の QFP パイプライン構造
Cisco IOS XE のデータプレーン処理は、QFP 内部の **FIA (Feature Invocation Array)** と呼ばれる機能実行配列に従って順番に処理されます。Packet Trace は各パケットにトレース識別子を付与し、どの FIA ステージを通ったかを追跡します。

```text
[ Ingress Interface ]
        ↓
┌────────────────────────────────────────────────────────┐
│ QFP Ingress FIA Stage                                  │
│  - Input ACL Check                                     │
│  - Ingress QoS / Policing                              │
│  - Security Checks (RPF, MAC Filter)                   │
└────────────────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────────────────┐
│ QFP Forwarding & Lookup Stage                          │
│  - FIB Lookup (CEF Routing)                            │
│  - PBR (Policy-Based Routing)                          │
│  - NAT (Inside to Outside Translation)                 │
│  - IPsec Encapsulation / Decapsulation                 │
└────────────────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────────────────┐
│ QFP Egress FIA Stage                                   │
│  - Output ACL Check                                    │
│  - Egress QoS / Shaping / Queuing                      │
│  - Encapsulation (L2 Header Rewrite)                   │
└────────────────────────────────────────────────────────┘
        ↓ (ドロップ発生時: Exact Drop Reason を記録)
[ Egress Interface ]  or  [ QFP Drop Buffer ]
```

### 2. Conditional Debugger のトリガー・フィルタリング原理
Conditional Debugger は、オペレータが定義した条件テーブル（Condition Table）を IOS XE のコントロールプレーン（IOSd）およびデータプレーン（QFP）のデバッグサブシステムに動的注入します。

```text
1. フィルター定義:
   R1(config)# debug platform condition ipv4 192.168.1.10/32
   R1(config)# debug platform condition interface GigabitEthernet0/0/1

2. デバッグ機能の紐付け:
   R1# debug platform condition feature packet-trace
   R1# debug ip ospf packet

3. 条件判定プロセス:
   パケット/イベント発生 ──> [ Condition Table 照合 ] ──> Match?
                                │
                      ┌─────────┴─────────┐
                      │                   │
                   (YES)                 (NO)
                      │                   │
             [ デバッグログ出力 ]    [ 無視 / スルー ]
             (Syslog / Buffer)    (CPU/バッファ保護)
```

---

## ⚙ 動作シーケンス

### 1. Data Path Packet Trace 処理シーケンス
1. **条件のセット (Conditional Debugging 連動):**
   `debug platform condition ipv4 <IP> subnet <MASK>` コマンド等で、解析対象のパケットフロー条件を指定。
2. **トレース機能の有効化:**
   `debug platform condition feature packet-trace` および `debug platform packet-trace packet 2048 copy packet input/output data` でトレースバッファとパケットコピーサイズを定義。
3. **トレース開始:**
   `debug platform condition start` でトレースエンジンを駆動。
4. **QFP パケットトラップ ＆ 記録:**
   対象パケットが入力されると、QFP は各 FIA ステージでの処理結果（Pass / Modified / Dropped）と変調後のヘッダー差分をトレースバッファに記録。
5. **トレースの停止 ＆ 解析:**
   `debug platform condition stop` でトレースを停止し、`show platform packet-trace summary` および `show platform packet-trace packet <ID> decode` で FIA 履歴およびドロップ理由を確認。

### 2. Conditional Debugger (Radioactive Tracing) 処理シーケンス
1. **ターゲット条件指定:**
   `debug platform condition feature dot1x target mac aaaa.bbbb.cccc` など、追跡対象の MAC/IP アドレスを指定。
2. **条件追跡エンジン起動:**
   `debug platform condition start` を実行。該当ターゲットに関するインバンドシグナリング（EAPOL, RADIUS, DHCP 等）が発生すると、IOSd 内のマルチプロセスログを同一の相関 ID（Correlation ID）で追跡。
3. **ログ生成 ＆ トレースメッセージ格納:**
   ログは一般の Syslog バッファを汚染することなく、プラットフォーム内部の Traces メッセージバッファ（`show platform software trace message ...`）に集約保存。


## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint で重要なポイント
* **パケットドロップ原因の特定能力:** ラボ試験において、「PING が通らない」「BGP ネイバーが張れない」「特定の IPsec 通信のみ遮断される」といったトラブルシューティング問題において、単に `show ip route` や `show access-lists` を見るだけでなく、Packet Trace を使用して **`Exact Drop Reason`**（例: `IP ACL Dynamic Drop`, `RPF Check Failed`, `Subinterface Down`, `QoS Drop`）を数秒で特定する能力が問われます。
* **プロダクション環境を想定したデバッグ手順:** 試験要件として「ネットワークの正常な運用を妨げずに特定セッションのデバッグログを採取せよ」と指定されるケースがあります。この場合、無条件の `debug ip packet` は禁忌（採点減点対象または問題破壊）であり、必ず **`debug platform condition`** を使用して条件フィルターを適用した後にデバッグを実行する必要があります。

### 2. ラボ試験で設定させられそうな内容
* 条件付き Packet Trace によるドロップパケットのペイロードデコードおよび原因解析。
* Catalyst 9000 における 802.1X / MAB 端末の Radioactive Tracing（`debug platform condition feature dot1x target mac ...`）。
* Control Plane Policing (CoPP) や Policy-Based Routing (PBR) で破棄されたパケットの FIA ステージ追跡。

### 3. よくある設定ミス ＆ 狙われやすい落とし穴
* **`debug platform condition start` の押し忘れ:** 条件（`debug platform condition ...`）や機能（`debug platform condition feature ...`）を定義しただけで満足し、`start` コマンドを実行し忘れてトレースログが一切採取されないミス。
* **トレースバッファサイズの不足:** デフォルトのバッファ数（16 パケットなど）のまま実行し、目的のパケットログが循環バッファ（Circular Buffer）によって上書き消滅してしまうミス。必ず `debug platform packet-trace packet 2048` などでバッファサイズを拡張しておく。
* **パケットコピー（`copy packet`）の指定漏れ:** `show platform packet-trace packet <ID> decode` で L2/L3/L4 ヘッダーの詳細デコードを表示させるためには、`debug platform packet-trace copy packet 2048 input/output data` の指定が必須。
* **デバッグ条件の消去忘れ:** トラブルシューティング終了後に `clear platform condition all` または `no debug platform condition ...` を実行しないと、意図しないログが後続の検証作業の邪魔になります。

---

## 🛠 設定方法

### 1. Data Path Packet Trace 基本設定（基本ワークフロー）

```bash
! 1. フィルター条件の設定（特定ホスト 192.168.10.50 宛ての通信に限定）
R1(config)# debug platform condition ipv4 192.168.10.50/32

! 2. Packet Trace 機能のバインド
R1(config)# debug platform condition feature packet-trace

! 3. バッファサイズおよびパケットコピー（2048 バイト）の有効化
R1# debug platform packet-trace packet 2048
R1# debug platform packet-trace copy packet 2048 input/output data

! 4. 条件付きデバッグ・トレースの開始
R1# debug platform condition start

! ----------------------------------------------------
! [ここでテストパケットの送信や障害再現テストを実施]
! ----------------------------------------------------

! 5. 条件付きデバッグ・トレースの停止
R1# debug platform condition stop
```

### 2. Radioactive Tracing 設定（Catalyst 9000 端末追跡）

```bash
! 1. 追跡対象 MAC アドレスの指定
SW1(config)# debug platform condition feature dot1x target mac aaaa.bbbb.cccc

! 2. 追跡開始
SW1# debug platform condition start

! ----------------------------------------------------
! [端末のポート挿抜や 802.1X 再認証を実施]
! ----------------------------------------------------

! 3. 追跡停止
SW1# debug platform condition stop

! 4. 集約ログの抽出表示
SW1# show platform software trace message switch active R0 dot1x
```

---

## 🔍 検証コマンド

### 1. Packet Trace 検証コマンド表

| 目的 | コマンド |
| :--- | :--- |
| トレース概要の一覧表示 | <code>show platform packet-trace summary</code> |
| 特定パケット ID の詳細・FIA トレース解読 | <code>show platform packet-trace packet \<ID\></code> |
| パケットヘッダー・ペイロードの完全デコード | <code>show platform packet-trace packet \<ID\> decode</code> |
| トレース統計（キャプチャ数/ドロップ数）表示 | <code>show platform packet-trace statistics</code> |
| 設定中のトレースパラメータ確認 | <code>show platform packet-trace configuration</code> |

### 2. Conditional Debugger 検証コマンド表

| 目的 | コマンド |
| :--- | :--- |
| 現在設定されている条件一覧の確認 | <code>show platform condition</code> |
| プラットフォームのデバッグ状態（ACTIVE/INACTIVE）確認 | <code>show platform debug-status</code> |
| 全条件・デバッグ設定の即時クリア | <code>clear platform condition all</code> |
| Radioactive Trace ログの表示（Dot1X 例） | <code>show platform software trace message switch active R0 dot1x</code> |
| デバッグメッセージのリアルタイム監視 | <code>debug platform condition start</code> / <code>stop</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| `show platform packet-trace summary` にパケットが一切表示されない | `debug platform condition start` が実行されていない、または条件（IP/Interface）が合致していない | <code>show platform condition</code><br><code>show platform debug-status</code> | `debug platform condition start` を実行し、`debug platform condition ipv4` のフィルター定義を見直す。 |
| `show platform packet-trace packet <ID>` でヘッダーデコードが表示されない | `copy packet` オプションが設定されていない | <code>show platform packet-trace configuration</code> | `debug platform packet-trace copy packet 2048 input/output data` を実行した上で再度テストを実施する。 |
| トレースログがすぐに上書きされて古いパケットが見られない | バッファサイズ（デフォルト数）が小さすぎる | <code>show platform packet-trace statistics</code> | `debug platform packet-trace packet 2048`（最大 8192 等）でバッファサイズを拡大する。 |
| デバッグログが生成されすぎて CPU が高騰する | 条件指定（Condition）をせずに通常の `debug` コマンドを全開で実行した | <code>show processes cpu sorted</code> | 直ちに `undebug all` および `clear platform condition all` を実行し、条件フィルターを再定義する。 |
| QFP ドロップ理由が `IP ACL Dynamic Drop` と表示される | インバウンドまたはアウトバウンド ACL で deny されている | <code>show platform packet-trace packet \<ID\></code> | 対象インターフェイスの `ip access-group` 設定および ACL エントリを確認する。 |

---

## ⚠ 制限事項

* **IOS XE 専用機能:** Data path packet trace (`debug platform packet-trace`) および QFP アーキテクチャに依存する診断コマンドは、旧 Cisco IOS (12.x / 15.M) や NX-OS ではサポートされず、Cisco IOS XE 搭載機（ISR 4000, ASR 1000, Catalyst 8000/9000）でのみ利用可能です。
* **メモリ消費:** `copy packet 2048` や `packet 8192` などの広大なバッファ確保は DRAM を消費するため、長期的な常時有効化は避け、トラブルシューティング時のみ実行することが推奨されます。
* **Control Plane 到達前ドロップ:** ハードウェア ASIC (Catalyst 9000 等) のレイヤー 2 ポートレベルで無差別ドロップされた物理エラーパケットなどは、QFP / CPU ソフトウェアトレースまで到達しない場合があります。

---

## 🔄 他技術との関連

* **Control Plane Policing (CoPP):**  
  CoPP によって CPU 宛てトラフィック（OSPF, BGP, SSH 等）がポリシング破棄された場合、Packet Trace の FIA ステージで `Punt Policy Drop` または `CoPP Drop` として明示検出されます。
* **Policy-Based Routing (PBR) ＆ NAT:**  
  PBR によるネクストホップ変更や、NAT 変換（Inside Local ➔ Inside Global）がパケットヘッダーに正しく適用されたかが、FIA ステージごとの Header Rewrite 情報から一目瞭然となります。
* **Embedded Packet Capture (EPC):**  
  EPC が「パケットのそのままの生データ（pcap）を取得する」のに対し、Packet Trace は「ルータ内部での処理過程とドロップ理由を解析する」補完関係にあります。

---

## 🧩 比較表

### パケットキャプチャ ＆ 診断ツールの比較

| 機能 | Packet Trace (`debug platform packet-trace`) | Conditional Debugger | EPC (`monitor capture`) | SPAN / ERSPAN |
| :--- | :--- | :--- | :--- | :--- |
| **解析対象** | QFP 内部の処理過程 ＆ ドロップ理由 | 制御/データプレーンの各種ログ | 通信パケットの生データ (.pcap) | 物理/論理ポートのコピー |
| **ドロップ原因特定** | **最優秀（Exact Reason 表示）** | 不可（ログから推測） | 不可（届いたパケットのみ） | 不可 |
| **解析場所** | CLI 上で直接デコード | CLI / Syslog バッファ | CLI または Wireshark | 外部 Wireshark アナライザ |
| **CPU 負荷** | 極めて低い | 非常に低い | 低〜中（サンプリング依存） | ゼロ（ハードウェア処理） |

---

## 💡 ベストプラクティス

1. **トラブルシューティングの標準手順化:**  
   不通障害の解析時は、まず `debug platform condition ipv4 <SRC> subnet <MASK>` と `debug platform condition ipv4 <DST> subnet <MASK>` で双方向の条件を定義し、Packet Trace を有効化してから PING やアプリケーション通信を実行する。
2. **必ず停止 ＆ クリアを実施:**  
   診断完了後は、`debug platform condition stop` を実行してトレースを停止し、`clear platform condition all` で設定した条件フィルターを削除する習慣をつける。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: Conditional Packet Trace による特定 ICMP パケットドロップ原因解析

#### 問題
R1 ルータにおいて、192.168.1.100 から 10.1.1.1 宛ての ICMP パケットが途中でドロップしている。通信障害の原因を Packet Trace 機能を用いて特定せよ。

#### 要件
* 192.168.1.100 宛ておよび 10.1.1.1 宛ての IPv4 通信のみをトレース対象とすること。
* パケットバッファ数 2048、パケットコピーサイズ 2048 バイトを指定すること。
* ドロップが発生した Exact Drop Reason を確認し、原因となった設定（ACL 等）を修正して通信を復旧させること。

#### 設定例

```bash
! --- R1 コンフィグレーション ---
! 1. トレース対象の条件定義
R1(config)# debug platform condition ipv4 192.168.1.100/32
R1(config)# debug platform condition ipv4 10.1.1.1/32

! 2. Packet Trace 機能のアタッチおよびバッファ定義
R1(config)# debug platform condition feature packet-trace
R1# debug platform packet-trace packet 2048
R1# debug platform packet-trace copy packet 2048 input/output data

! 3. トレース開始
R1# debug platform condition start
```

#### 検証方法

```bash
! 1. 障害再現テスト実行後、トレースを停止
R1# debug platform condition stop

! 2. トレース概要の確認
R1# show platform packet-trace summary
Pkt Input                Output               State  Reason
--- -------------------- -------------------- ------ --------------------
0   Gi0/0/0              Internal0/0/rp:0     DROP   IP ACL Dynamic Drop (Input)

! 3. パケット 0 の詳細デコード表示
R1# show platform packet-trace packet 0 decode
Packet: 0          C3PL Enqueue: Success
Feature: IP ACL
  Action: Drop
  Reason: IP ACL Dynamic Drop
  ACL Name: INBOUND_ACL (Rule 20: deny ip any host 10.1.1.1)

! 4. 判定結果に基づく修復
R1(config)# ip access-list extended INBOUND_ACL
R1(config-ext-nacl)# 15 permit ip host 192.168.1.100 host 10.1.1.1
```

---

### ラボ 2: PBR (Policy-Based Routing) 転送失敗の FIA ステージ追跡

#### 問題
R2 ルータにおいて、特定ソース端末（172.16.1.50）からの HTTP トラフィック（TCP 80）を PBR によりネクストホップ 192.168.12.2 へ迂回させる設定を入れたが、期待通り転送されない。Packet Trace を使用して PBR ステージの評価結果を検証せよ。

#### 要件
* 172.16.1.50 からのパケットを条件指定すること。
* PBR の FIA ステージでのネクストホップ決定プロセスをデコード確認すること。

#### 設定例

```bash
! --- R2 コンフィグレーション ---
R2(config)# debug platform condition ipv4 172.16.1.50/32
R2(config)# debug platform condition feature packet-trace
R2# debug platform packet-trace packet 1024
R2# debug platform packet-trace copy packet 1024 input/output data
R2# debug platform condition start
```

#### 検証方法

```bash
R2# debug platform condition stop
R2# show platform packet-trace packet 0
Packet: 0          Input 0/0/1 (Gi0/0/1)
  State: FORWARD
  FIA Trace:
    Feature: PBR
      Action: Set Next Hop
      Next Hop: 192.168.12.2 (Reachable via FIB)
      Result: Match Route-Map PBR_MAP seq 10
    Feature: FIB Lookup
      Action: Forward
      Egress Interface: GigabitEthernet0/0/2
```

---

### ラボ 3: NAT (Inside to Outside) 変換失敗・ドロップの Packet Trace 特定

#### 問題
R3 ルータ（NAT 境界）において、Inside 端末（192.168.20.10）から Outside 宛ての通信が NAT 変換されずに破棄されている。Packet Trace を用いて Inside/Outside 判定および NAT エントリ生成の成否を確認せよ。

#### 要件
* 送信元 192.168.20.10 を Conditional フィルターに設定すること。
* NAT FIA ステージでのドロップ理由を解読すること。

#### 設定例

```bash
! --- R3 コンフィグレーション ---
R3(config)# debug platform condition ipv4 192.168.20.10/32
R3(config)# debug platform condition feature packet-trace
R3# debug platform packet-trace packet 2048
R3# debug platform packet-trace copy packet 2048 input/output data
R3# debug platform condition start
```

#### 検証方法

```bash
R3# debug platform condition stop
R3# show platform packet-trace packet 0 decode
Packet: 0          Input Gi0/0/0 (Inside)
  Feature: NAT Translation
    State: DROP
    Reason: NAT Translation Table Full / No Dynamic Pool Entry
    Details: Failed to allocate Outside Global IP for Inside Local 192.168.20.10
```

---

### ラボ 4: Control Plane Policing (CoPP) によるパケット破棄の Packet Trace 検出

#### 問題
R4 ルータ宛ての BGP セッション（TCP 179）が頻繁にフラップしている。CoPP ポリサーによって BGP パケットがドロップされているか Packet Trace を使用して検証せよ。

#### 要件
* BGP ネイバー IP（10.254.1.2）を追跡対象とすること。
* CoPP ステージでの Drop 理由を確認すること。

#### 設定例

```bash
! --- R4 コンフィグレーション ---
R4(config)# debug platform condition ipv4 10.254.1.2/32
R4(config)# debug platform condition feature packet-trace
R4# debug platform packet-trace packet 1024
R4# debug platform packet-trace copy packet 1024 input/output data
R4# debug platform condition start
```

#### 検証方法

```bash
R4# debug platform condition stop
R4# show platform packet-trace summary
Pkt Input                Output               State  Reason
0   Gi0/0/0              Control-Plane        DROP   Punt Policy Drop (CoPP Exceeded)

R4# show platform packet-trace packet 0
Packet: 0          Input Gi0/0/0
  Feature: CoPP (Control Plane Policing)
    Class-Map: CM_COPP_BGP
    Policer Action: Exceed Drop (Rate > 100pps)
```

---

### ラボ 5: Radioactive Tracing による Catalyst 9300 802.1X / MAB 認証追跡

#### 問題
SW1（Catalyst 9300）の Port Gi1/0/1 に接続された PC（MAC: 0011.2233.4455）の 802.1X 認証が失敗する。Radioactive Tracing を用いて 802.1X 状態遷移と RADIUS 交換ログを安全に抽出せよ。

#### 要件
* 対象 MAC アドレス `0011.2233.4455` をデバッグターゲットに指定すること。
* Syslog を汚染せずにプラットフォームトレースバッファから認証失敗ログを抽出すること。

#### 設定例

```bash
! --- SW1 コンフィグレーション ---
SW1(config)# debug platform condition feature dot1x target mac 0011.2233.4455
SW1# debug platform condition start
```

#### 検証方法

```bash
! PC の LAN ケーブルを挿抜し認証試行を実施後:
SW1# debug platform condition stop

! ログの表示
SW1# show platform software trace message switch active R0 dot1x
2026/10/30 08:15:02.123 [dot1x]: [0011.2233.4455:Gi1/0/1] EAPOL-Start received
2026/10/30 08:15:02.125 [dot1x]: [0011.2233.4455:Gi1/0/1] Sending EAP-Request/Identity
2026/10/30 08:15:02.150 [dot1x]: [0011.2233.4455:Gi1/0/1] EAP-Response/Identity received (user: User1)
2026/10/30 08:15:02.155 [radius]: [0011.2233.4455] Sending Access-Request to 192.168.100.10:1812
2026/10/30 08:15:05.155 [radius]: [0011.2233.4455] RADIUS Server Timeout (No Access-Accept/Reject)
```



---

### ラボ 6: IPsec VPN トンネル暗号化前後の Packet Trace による検証

#### 問題
R6 ルータにおいて、10.1.1.0/24 から 10.2.2.0/24 宛ての IPsec トンネル通信が疎通不能である。Packet Trace を使用して GRE/IPsec カプセル化ステージおよび Crypto Map マッチの成否を検証せよ。

#### 要件
* 送信元 10.1.1.100 宛先 10.2.2.100 の IPv4 アドレスを追跡条件とすること。
* FIA ステージでの Crypto Map 評価および ESP カプセル化結果を確認すること。

#### 設定例

```bash
! --- R6 コンフィグレーション ---
R6(config)# debug platform condition ipv4 10.1.1.100/32
R6(config)# debug platform condition ipv4 10.2.2.100/32
R6(config)# debug platform condition feature packet-trace
R6# debug platform packet-trace packet 2048
R6# debug platform packet-trace copy packet 2048 input/output data
R6# debug platform condition start
```

#### 検証方法

```bash
R6# debug platform condition stop
R6# show platform packet-trace packet 0 decode
Packet: 0          Input Gi0/0/1 (Inside)
  Feature: Crypto Map Lookup
    State: DROP
    Reason: IPsec SA Not Established (ISAKMP Phase 2 Incomplete)
    Crypto Map: MY_CMAP seq 10 (Peer 203.0.113.2)
```

---

### ラボ 7: 複合条件（Ingress Interface ＋ Target IP Subnet）の Conditional Debugging

#### 問題
R7 ルータにおいて、GigabitEthernet0/0/0 から入ってくる 192.168.100.0/24 サブネットからのトラフィックのみを条件追跡し、無関係な通信によるログ汚染を防止せよ。

#### 要件
* インターフェイス `GigabitEthernet0/0/0` と IPv4 サブネット `192.168.100.0/24` の論理積条件を設定すること。

#### 設定例

```bash
! --- R7 コンフィグレーション ---
R7(config)# debug platform condition interface GigabitEthernet0/0/0
R7(config)# debug platform condition ipv4 192.168.100.0/24
R7(config)# debug platform condition feature packet-trace
R7# debug platform packet-trace packet 1024
R7# debug platform condition start
```

#### 検証方法

```bash
R7# show platform condition
Conditional Debugging State: ACTIVE

Conditions specified:
  Interface: GigabitEthernet0/0/0
  IPv4 Address/Subnet: 192.168.100.0/255.255.255.0

R7# debug platform condition stop
```

---

### ラボ 8: Packet Trace による L4 ポート ＆ ペイロード詳細デコード検証

#### 問題
R8 ルータを通過する 10.0.0.1 から 172.16.0.1 宛ての TCP ポート 80 (HTTP) トラフィックの、L2/L3/L4 ヘッダーおよびペイロード先頭バイトをデコード表示せよ。

#### 要件
* `copy packet 2048 input/output data` を指定し、パケットデータのバイトダンプを取得すること。

#### 設定例

```bash
! --- R8 コンフィグレーション ---
R8(config)# debug platform condition ipv4 10.0.0.1/32
R8(config)# debug platform condition feature packet-trace
R8# debug platform packet-trace packet 1024
R8# debug platform packet-trace copy packet 2048 input/output data
R8# debug platform condition start
```

#### 検証方法

```bash
R8# debug platform condition stop
R8# show platform packet-trace packet 0 decode
Packet 0:
  Layer 2: DMAC=0050.56a1.2233 SMAC=000c.29ff.1122 Type=0x0800
  Layer 3: IPv4 Src=10.0.0.1 Dst=172.16.0.1 Proto=TCP (6) Len=60
  Layer 4: TCP SrcPort=49152 DstPort=80 (HTTP) Seq=1001 Ack=0 Flags=[SYN]
  Payload Data (First 64 Bytes):
    0000: 47 45 54 20 2f 20 48 54  54 50 2f 31 2e 31 0d 0a  GET / HTTP/1.1..
```

---

### ラボ 9: Conditional Debugger による安全な OSPF ログ採取

#### 問題
R9 ルータと対向ルータ 10.255.255.2 間で OSPF アジャセンシーが確立しない。通常デバッグを実行すると他インターフェイスの大量ログで CPU が高騰するため、対向 10.255.255.2 宛ての OSPF イベントログのみを安全に抽出せよ。

#### 要件
* 対向 IP `10.255.255.2` のみを Conditional ターゲットに設定すること。
* `debug ip ospf events` および `debug ip ospf adj` を安全に適用すること。

#### 設定例

```bash
! --- R9 コンフィグレーション ---
R9(config)# debug platform condition ipv4 10.255.255.2/32
R9# debug ip ospf events
R9# debug ip ospf adj
R9# debug platform condition start
```

#### 検証方法

```bash
! 条件に合致する OSPF パケット/イベントのみがターミナルに出力される:
*Oct 30 08:30:12.450: OSPF-1 ADJ Gi0/0/1: Rcv Hello from 10.255.255.2 seq 0x123
*Oct 30 08:30:12.451: OSPF-1 ADJ Gi0/0/1: Mismatched hello parameters (DeadInterval 40 vs 60)

! 検証終了後の後片付け
R9# undebug all
R9# debug platform condition stop
R9# clear platform condition all
```

---

### ラボ 10: Unicast RPF (uRPF) Check Failed によるパケットドロップ判別

#### 問題
R10 ルータの Gi0/0/0 インターフェイスにおいて `ip verify unicast source reachable-via rx` (Strict uRPF) を有効化しているが、特定の送信元 IP (192.168.99.50) からのパケットがドロップされる。Packet Trace で uRPF ドロップであることを証明せよ。

#### 要件
* 送信元 192.168.99.50 を追跡条件に設定すること。
* ドロップ理由が `uRPF Failed` であることを特定すること。

#### 設定例

```bash
! --- R10 コンフィグレーション ---
R10(config)# debug platform condition ipv4 192.168.99.50/32
R10(config)# debug platform condition feature packet-trace
R10# debug platform packet-trace packet 1024
R10# debug platform condition start
```

#### 検証方法

```bash
R10# debug platform condition stop
R10# show platform packet-trace summary
Pkt Input                Output               State  Reason
0   Gi0/0/0              Internal0/0/rp:0     DROP   uRPF Failed

R10# show platform packet-trace packet 0
Packet: 0          Input Gi0/0/0
  Feature: Unicast RPF Check
    State: DROP
    Reason: RPF Check Failed (No route back via Ingress Gi0/0/0)
```


## ❓ 想定試験問題

### 問 1 (コンフィグ読解)
以下のコンフィグを R1 ルータに適用した。テストパケット送信後に `show platform packet-trace summary` を実行したが、トレース出力が一切表示されなかった。最も可能性の高い原因はどれか。

```bash
R1(config)# debug platform condition ipv4 192.168.1.1/32
R1(config)# debug platform condition feature packet-trace
R1# debug platform packet-trace packet 2048
```

* (A) `copy packet` オプションが指定されていないため。
* (B) `debug platform condition start` コマンドが実行されていないため。
* (C) パケットバッファ数 2048 が小さすぎるため。
* (D) `ip status` コマンドが有効化されていないため。

**正解:** **(B)**  
**解説:** `debug platform condition` で条件を定義し、`debug platform condition feature packet-trace` で機能をアタッチしても、`debug platform condition start` を実行しない限り、条件付きデバッグおよび Packet Trace エンジンは駆動しません。

---

### 問 2 (トラブルシューティング)
`show platform packet-trace summary` の出力結果が以下のようになった。192.168.10.1 から 10.0.0.1 宛ての通信が遮断されている原因として正しいものはどれか。

```text
Pkt Input                Output               State  Reason
0   Gi0/0/0              Internal0/0/rp:0     DROP   IP ACL Dynamic Drop (Input)
```

* (A) Egress インターフェイスのアウトバウンド ACL でブロックされている。
* (B) Ingress インターフェイス GigabitEthernet0/0/0 に適用されたインバウンド ACL でブロックされている。
* (C) CoPP (Control Plane Policing) によりポリシング破棄されている。
* (D) RPF (Reverse Path Forwarding) チェックに失敗している。

**正解:** **(B)**  
**解説:** `Reason` に `IP ACL Dynamic Drop (Input)` と表示され、`Output` が `Internal0/0/rp:0`（ドロップバッファ）となっているため、入力インターフェイス `Gi0/0/0` のインバウンド ACL で明示的または暗黙の deny によって破棄されています。

---

### 問 3 (Design / 運用)
高負荷なコア集中ルータにおいて、特定クライアント（172.16.50.10）の通信障害調査を実施する必要がある。CPU に負荷をかけず安全にデバッグを遂行するためのベストプラクティス手順として最も適切な組み合わせを選択せよ。

* (A) `debug ip packet` を実行し、`logging buffered 100000` でログを記録する。
* (B) `debug platform condition ipv4 172.16.50.10/32` を設定後、`debug platform condition start` を実行して目的のデバッグを有効化する。
* (C) 全インターフェイスで `no ip route-cache` を設定し、`debug ip raw` を実行する。
* (D) `monitor capture` を無条件で起動し、Flash に 1 時間保存する。

**正解:** **(B)**  
**解説:** ライブ環境での無条件デバッグは CPU 100% 高騰による障害拡大を引き起こします。`debug platform condition` を使用して条件フィルターを適用した上でデバッグを実行するのが Cisco 推奨のベストプラクティスです。

---

### 問 4 (実装)
Catalyst 9300 スイッチにおいて、特定の MAC アドレス `0011.2233.4455` の端末に対する 802.1X 認証ログのみを Radioactive Tracing で追跡する場合の正当な設定コマンドはどれか。

* (A) `debug dot1x mac 0011.2233.4455`
* (B) `debug platform condition feature dot1x target mac 0011.2233.4455`
* (C) `trace mac 0011.2233.4455 feature dot1x`
* (D) `logging condition mac 0011.2233.4455`

**正解:** **(B)**  
**解説:** Catalyst 9000 シリーズ（Polaris）における Radioactive Tracing では、`debug platform condition feature <feature> target mac <MAC>` 構文を使用してターゲットの条件を登録します。

---

### 問 5 (トラブルシューティング)
`show platform packet-trace packet 0` を確認したところ、`Reason: RPF Check Failed` と表示された。このドロップが発生する根本原因はどれか。

* (A) 受信パケットの Destination IP に対する CEF ルートが存在しない。
* (B) 受信パケットの Source IP に対する戻りルートが、パケットを受信した Ingress インターフェイスと一致しない（Strict uRPF 違反）。
* (C) パケットの TTL が 0 に達した。
* (D) パケットの MTU サイズがインターフェイス MTU を超過している。

**正解:** **(B)**  
**解説:** `RPF Check Failed` は Unicast RPF (uRPF) 機能によるドロップであり、送信元 IP に対するルートの出力インターフェイスと実際の受信インターフェイスの不一致が原因です。

---

### 問 6 (コンフィグ読解)
`show platform packet-trace packet 0 decode` を実行した際、`Packet data decode unavailable` と表示され、L4 ポート番号やヘッダー詳細が表示されなかった。この原因として正しいものはどれか。

* (A) `debug platform packet-trace copy packet ...` コマンドが設定されていない。
* (B) ルータのライセンスが Network Essentials であるため。
* (C) パケットがドロップされず正常転送されたため。
* (D) `copy packet` のバイトサイズが 64 未満に制限されているため。

**正解:** **(A)**  
**解説:** ヘッダーおよびデータペイロードの完全デコード表示には、`debug platform packet-trace copy packet <SIZE> input/output data` の事前指定が必要です。

---

### 問 7 (Design)
IOS XE の QFP パケット処理パイプライン（FIA）において、パケットが入力を受けた直後に評価される機能の順番として正しいものはどれか。

* (A) Egress QoS -> NAT -> FIB Lookup -> Ingress ACL
* (B) Ingress ACL -> Ingress QoS / RPF -> FIB Lookup / PBR / NAT -> Egress ACL / Egress QoS
* (C) FIB Lookup -> Ingress ACL -> Egress ACL -> NAT
* (D) NAT -> Egress QoS -> Ingress ACL -> FIB Lookup

**正解:** **(B)**  
**解説:** QFP FIA では、入力を受けるとまず Ingress ACL および Ingress QoS/uRPF が評価され、その後 FIB ルックアップ/PBR/NAT が処理され、最後に Egress ACL および Egress QoS が適用されます。

---

### 問 8 (トラブルシューティング)
`show platform packet-trace summary` にて、`Reason: Punt Policy Drop` と表示された。このドロップが示す意味として最も適切なものはどれか。

* (A) 送信元 IP が ACL で拒否された。
* (B) Control Plane Policing (CoPP) のポリサーによって、CPU 宛てパケットが破棄された。
* (C) 物理インターフェイスの Link 障害。
* (D) MTU サイズ超過による ICMP Needed Frag エラー。

**正解:** **(B)**  
**解説:** `Punt Policy Drop` は、QFP からルータ CPU (Control Plane) へパケットを渡す（Punt する）段階で CoPP ポリサー上限を超過して破棄されたことを示します。

---

## 🔗 参考リソース

* Cisco Systems, Cisco IOS XE 17.x Configuration Guide: System Management
* Cisco Systems, Technical Note: Troubleshooting Datapath Packet Trace on Cisco IOS XE Routers
* Cisco Live Presentation, BRKARC-2001: Cisco IOS XE Datapath Deep Dive and Packet Trace Architecture
* Cisco Live Presentation, BRKCRS-3147: Advanced Troubleshooting on Cisco Catalyst 9000 Series Switches
* Cisco Systems, Cisco Command Reference: debug platform condition

---

## 📝 補足（Notes）

### 1. Packet Trace コマンドのクイックリファレンスシート

```bash
! --- トラブルシューティング開始用テンプレート ---
debug platform condition ipv4 <TARGET_IP>/32
debug platform condition feature packet-trace
debug platform packet-trace packet 2048
debug platform packet-trace copy packet 2048 input/output data
debug platform condition start

! --- テスト実施後 ---
debug platform condition stop
show platform packet-trace summary
show platform packet-trace packet 0 decode

! --- 撤収作業 ---
undebug all
clear platform condition all
```

### 2. トラブルシューティング構成図メモ

```text
[ Client: 192.168.1.100 ]
           │
           ▼ (Ingress: Gi0/0/0)
┌────────────────────────────────────────────────────────┐
│ Cisco IOS XE Router (QFP Forwarding Engine)            │
│                                                        │
│  1. Ingress ACL Check ---> [ PASS ]                    │
│  2. uRPF Check ----------> [ PASS ]                    │
│  3. NAT Translation ----> [ PASS ] (192.168.1.100 -> 203.0.113.10) │
│  4. FIB Lookup ---------> [ PASS ] (Next-Hop: 203.0.113.1) │
│  5. Egress ACL Check ---> [ DROP! ] --> (Reason: IP ACL Dynamic Drop) │
└────────────────────────────────────────────────────────┘
           │
           X (Packet Dropped Before Egress Gi0/0/1)
```


## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKTRS-2811: Overview of Packet Capturing and Traffic Analysis Tools**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-2811)
    *   EPC、SPAN、パケットトレースを含む包括的な可視化ツールの解説。
*   [**BRKARC-2001: Cisco ASR 1000 Series Architecture**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-2001)
    *   QFP 内部での FIA 処理とデバッグの仕組み。
*   [**BRKCRT-1385: The CCIE in an SDN World**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   モダンなエンタープライズインフラにおけるトラブルシューティングの価値。

### Configuration ガイド
*   [**Troubleshoot with the IOS-XE Datapath Packet Trace Feature**](https://www.cisco.com/c/en/us/support/docs/routers/asr-1000-series-aggregation-services-routers/112030-pkt-trace-asr1k.html)。
*   [**Conditional Debugging and Radioactive Tracing Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-3/configuration_guide/sys_mgmt/b_173_sys_mgmt_9300_cg/m_conditional-debug-radioactive-tracing.html)。

### テクニカルドキュメント・設定例
*   [**Understanding the Packet-Trace Feature in IOS-XE (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/asr-1000-series-aggregation-services-routers/112030-pkt-trace-asr1k.html)。
*   [**Common DROP Reasons in IOS-XE Packet-Trace (Technical Reference)**](https://www.cisco.com/c/en/us/support/docs/routers/asr-1000-series-aggregation-services-routers/214300-troubleshoot-asr1k-packet-drops-with-the.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験合格に必要な **「論理的な原因特定プロセス」** を強化することを目的としています。ラボ試験では、設定ミスを探して闇雲にコマンドを打つのではなく、**`packet-trace`** を活用してデバイスが「なぜその判断を下したのか」をデータプレーンの視点から証明することが合格への近道です。


