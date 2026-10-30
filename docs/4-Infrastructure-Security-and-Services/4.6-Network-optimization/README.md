---
layout: default
title: 4.6-Network-optimization
parent: 4-Infrastructure-Security-and-Services
nav_order: 6
---

# 4.6 Network optimization

CCIE EI v1.1 Blueprint の項目 **4.6 Network optimization**（IP SLA、Flexible NetFlow、SPAN / RSPAN / ERSPAN）に関する詳細な学習メモです。GitHub Pages 等での復習やラボ試験直前の確認用に利用できます。

---

## 📘 概要

ネットワークオプティマイゼーション（ネットワーク最適化・可視化・監視）は、インフラストラクチャの安定稼働、通信品質の測定、障害の未然防止および迅速な障害追跡を実現するための基盤技術群です。CCIE EI v1.1 ラボ試験では、単なる個別機能の投入にとどまらず、プロアクティブな品質監視、フローレベルのトラフィック解析、および L2/L3 パケットキャプチャを組み合わせた高度なネットワーク運用制御が要求されます。

### 1. IP SLA (IP Service Level Agreements)
* **機能概要:** アクティブプロービング（模擬パケット送信）により、ネットワーク上の応答時間、パケットロス、ジッター（遅延ゆらぎ）、MOS (Mean Opinion Score)、HTTP レスポンスタイム、TCP 接続時間をミリ秒精度で計測するアクティブ監視機能。
* **利用目的:** 回線品質のリアルタイム測定、並びに Object Tracking 経由での Static Route / HSRP / VRRP / PBR / EEM との動的連携による自動パス切替・セルフヒーリング。
* **利用場面:** WAN 回線（MPLS L3VPN、SD-WAN、DMVPN、Internet）の遅延・障害検知、VoIP 通信品質（UDP Jitter）保証、Web サーバー到達性（HTTP/TCP）の死活監視。

### 2. Flexible NetFlow (FNF)
* **機能概要:** ネットワーク機器を通過する IP パケットのヘッダー情報（5-Tuple ＋ アプリケーション ID ＋ QoS DSCP ＋ インターフェイス等）をフローとして集約・可視化するフローキャプチャ技術。従来の NetFlow (v5/v9) から進化したモジュール構造（Record、Exporter、Monitor、Sampler）を持つ。
* **利用目的:** 帯域消費アプリケーションの特定（NBAR2 連携）、非対称ルーティングの検出、DDoS 攻撃・異常トラフィック検知、並びに IPFIX (RFC 7011) を用いたサードパーティ製 NMS へのフロー情報出力。
* **利用場面:** WAN 出口ポートでの帯域モニタリング、セキュリティアナリティクス、QoS 適用前後のトラフィック分類検証。

### 3. SPAN / RSPAN / ERSPAN (Switched Port Analyzer)
* **機能概要:** 特定のポートや VLAN を通過するパケット（Tx / Rx / Both）をコピー（ミラーリング）し、分析装置（パケットキャプチャ用 PC、Wireshark、IDS/IPS、Network Analyzer）へ転送するトラフィックアナライザ機能。
  * **SPAN (Local SPAN):** 同一スイッチ内のポートからポートへ直接ミラーリング。
  * **RSPAN (Remote SPAN):** 複数 L2 スイッチ間を専用の RSPAN VLAN（MAC アドレス学習無効化 VLAN）を経由して遠隔ポートへパケット転送。
  * **ERSPAN (Encapsulated Remote SPAN):** GRE トンネル（IP EtherType 0x88be / IP Protocol 47）でパケットをカプセル化し、L3 ネットワークを超えて遠隔地の分析装置や他拠点スイッチへ転送。
* **利用目的:** トラブルシューティング時の生パケット解析（Wireshark）、セキュリティ監査、IDS/IPS へのパケット複製入力。
* **利用場面:** リアルタイムパケットログ解析、ルーティング/QoS 不整合時の生パケットトレース。

---

## 🔑 要点

| 項目 | IP SLA | Flexible NetFlow (FNF) | SPAN / RSPAN / ERSPAN |
| :--- | :--- | :--- | :--- |
| **主要特徴** | アクティブ計測（生成プローブ送信） | パッシブフロー集約（通過パケット統計） | パケットレベル完全コピー（生パケット転送） |
| **主な用途** | 応答時間/ジッター計測、自動パス切替 | アプリ別帯域解析、セキュリティ監査 | 生パケットアナライザ（Wireshark/IDS）入力 |
| **構成要素** | SLA Operation, Responder, Schedule, Track | Flow Record, Exporter, Monitor, Sampler | Source Port/VLAN, Destination Port/IP |
| **データ転送方式** | ICMP, UDP (IP SLA Control), TCP, HTTP | NetFlow v9 / IPFIX (UDP 2055/4739) | L2 Direct, RSPAN VLAN, GRE Tunnel (IP 47) |
| **CPU/ASIC 負荷** | 頻度・プローブ数に比例（低〜中） | パケット単位のフローテーブル更新（中） | ASIC 処理（CPU 負荷ゼロ、帯域消費あり） |
| **制限事項** | Responder 側で `ip sla responder` が必要（Jitter） | Ingress/Egress 方向定義、TCAM リソース依存 | Subinterface 非対応（SPAN）、GRE オーバーヘッド |
| **設計上の注意点** | Jitter 測定時は NTP 精度が必要 | サンプリングレート調整（1:100 等） | Destination ポートの帯域超えによるパケットドロップ |

---

## 🏗 動作原理

### 1. IP SLA (ICMP Echo / UDP Jitter / HTTP) の計測原理

```
[ IP SLA Source (Control Device) ]                          [ IP SLA Responder ]
         │                                                            │
         │──── 1. IP SLA Control Message (UDP 1967) ─────────────────>│ (ポート予約 & NTP タイムスタンプ準備)
         │<─── Control Message Reply ────────────────────────────────│
         │                                                            │
         │──── 2. Test Probe Sequence (T1) ──────────────────────────>│ (受信時刻 T2 記録)
         │                                                            │ (送信時刻 T3 記録)
         │<─── Test Probe Response (T4) ─────────────────────────────│
         │                                                            │
   [ Latency = (T4 - T1) - (T3 - T2) ]
   [ Jitter  = |(T4_i - T4_{i-1}) - (T1_i - T1_{i-1})| ]
```

* **タイムスタンプ処理 (UDP Jitter):** Responder 側でカーネル/ASIC レベルでパケット受信時刻 $T_2$ と送信時刻 $T_3$ を打刻することで、ルータ自体の内部処理遅延を遅延計算から完全除外。高精度な片道遅延・ジッターを計測可能。

### 2. Flexible NetFlow (FNF) 構造

```
 Incoming Packet
       │
       ▼
[ Flow Sampler ] ──(1:N フィルタリング)──┐
       │                                  ▼
       └─────────────────────────> [ Flow Record ] (Match Key 抽出: 5-Tuple, NBAR2)
                                          │
                                          ▼
                                   [ Flow Monitor ] (Flow Cache テーブル作成 & タイマー管理)
                                          │
                                          ▼
                                   [ Flow Exporter ] ──(NetFlow v9 / IPFIX UDP)──> [ NMS Collector ]
```

* **Flow Cache キー:** `match` フィールド（源/宛先 IP、L4 ポート、Protocol、VRF）によりフローをユニークに識別。
* **Flow Statistics:** `collect` フィールド（パケット数、バイト数、タイムスタンプ、DSCP）を集計。
* **Cache Aging:** `active timeout`（デフォルト 1800 秒）および `inactive timeout`（デフォルト 15 秒）によりエクスポートをトリガー。

### 3. SPAN / RSPAN / ERSPAN のミラーリング原理

```
[ Local SPAN ]
Source Port ──────(ASIC Hardware Copy)──────> Destination Port (Analyzer)

[ RSPAN ]
Source Switch ──> [ RSPAN VLAN (MAC Learning OFF) ] ──(Trunk)──> Destination Switch ──> Analyzer Port

[ ERSPAN ]
ERSPAN Source ──> [ GRE Encap (Type 0x88be) ] ──(IP Network Routing)──> ERSPAN Destination / Analyzer
```

* **ERSPAN ヘッダーカプセル化:**
  パケット ➔ ERSPAN Header (Session ID, Timestamp, VLAN) ➔ GRE Header (Protocol 0x88be) ➔ Outer IP Header (Source/Dest IP) ➔ L2 Header。

---

## ⚙ 動作シーケンス

### 1. ERSPAN (Encapsulated Remote SPAN) パケット処理シーケンス

```
[ Source Port (Gi0/1) ]
       │ 1. 被監視パケット受信 (Ingress/Egress)
       ▼
[ ERSPAN Source Session (ID: 1) ]
       │ 2. ASIC でパケットをコピー
       │ 3. ERSPAN / GRE ヘッダーを付与 (Outer IP: 10.1.1.1 -> 10.2.2.2, Session ID: 10)
       ▼
[ Routing Engine (FIB) ]
       │ 4. Outer IP に基づき通常 IP ルーティング処理
       ▼
[ IP Core Network ]
       │ 5. 標準 IP パケットとしてマルチホップ転送
       ▼
[ ERSPAN Destination (10.2.2.2) ]
       │ 6. GRE/ERSPAN ヘッダーをデカプセル化
       ▼
[ Destination Port (Gi0/2) ]
       │ 7. オリジナル生パケットをアナライザへ出力
       ▼
[ Wireshark / Network Analyzer ]
```

---


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、Network Optimization は単体設定問題だけでなく、Troubleshooting、Infrastructure Services、Automation との連携問題として出題されます。

### 1. 試験で頻出の重点ポイント

* **IP SLA ＋ Object Tracking ＋ Static Route / HSRP / PBR / EEM 連携:**
  * 単に IP SLA を起動するだけでなく、`track 10 ip sla 1 reachability` や `state` を作成し、Static Route や HSRP/VRRP の `track` 減算、PBR の `set ip next-hop verify-availability` にアタッチする連動コンフィグ。
  * `ip sla responder` の設定忘れや、ICMP Jitter / UDP Jitter 測定時の Responder IP / ポート不一致による Jitter 測定失敗。
* **Flexible NetFlow (FNF) の構造と構文依存性:**
  * `flow record` 内での `match` (キー) と `collect` (値) の誤設定。`match` に定義されていないフィールドでフローを追跡しようとするとエクスポート不可に。
  * `flow exporter` での Source Interface 指定 (`source Loopback0`) および Destination UDP ポート (デフォルト 2055) の指定。
  * `flow monitor` をインターフェイスに適用する際の方向 (`ip flow monitor FNF_MONITOR input` / `output`)。
  * `option exporter-stats` や `option interface-table` の追加オプション要求。
* **SPAN / RSPAN / ERSPAN のパラメータ不整合:**
  * **RSPAN:** 専用の RSPAN VLAN (`remote-span`) を全スイッチで作成し、Trunk ポートで許可 VLAN に含めないとパケットが中継されない。
  * **ERSPAN:** Source Session での `ip ttl` / `ip precision` / `origin ip-address` / `erspan-id` 設定と、Destination Session での `erspan-id` / `destination ip-address` の完全一致要件。
  * **Destination Port 制限:** SPAN の Destination ポートにアタッチされた端末からのインバウンド通信がデフォルトで遮断される点 (`ingress vlan` オプションで回避可能か)。


---

## 🛠 設定方法

### 1. IP SLA (ICMP Echo / UDP Jitter / HTTP) ＋ Object Tracking 設定例

```bash
! 1. IP SLA Responder (対向ルータで実行)
ip sla responder

! 2. IP SLA Source Router 設定
! (a) ICMP Echo Operation
ip sla 1
 icmp-echo 10.1.12.2 source-interface Loopback0
 frequency 5
 threshold 1000
 timeout 2000
ip sla schedule 1 life forever start-time now

! (b) UDP Jitter Operation (VoIP 測定)
ip sla 2
 udp-jitter 10.1.12.2 16384 source-ip 10.1.11.1 num-packets 100 interval 20
 frequency 30
ip sla schedule 2 life forever start-time now

! (c) HTTP Operation
ip sla 3
 http get http://server.domain.local/index.html
 frequency 60
ip sla schedule 3 life forever start-time now

! 3. Object Tracking 設定
track 10 ip sla 1 reachability
 delay down 10 up 5

track 20 ip sla 2 state

! 4. Static Route へのアタッチ
ip route 0.0.0.0 0.0.0.0 10.1.12.2 track 10
ip route 0.0.0.0 0.0.0.0 10.1.13.2 250
```


### 2. Flexible NetFlow (FNF) 設定例

```bash
! 1. Flow Record の定義
flow record FNF_RECORD_CUSTOM
 match ipv4 protocol
 match ipv4 source address
 match ipv4 destination address
 match transport source-port
 match transport destination-port
 match interface input
 collect interface output
 collect counter bytes long
 collect counter packets long
 collect timestamp sys-uptime first
 collect timestamp sys-uptime last
 collect ipv4 dscp

! 2. Flow Exporter の定義
flow exporter FNF_EXPORTER_NMS
 destination 10.100.1.50
 source Loopback0
 transport udp 2055
 template data-timeout 60
 option exporter-stats
 option interface-table

! 3. Flow Monitor の定義
flow monitor FNF_MONITOR_WAN
 record FNF_RECORD_CUSTOM
 exporter FNF_EXPORTER_NMS
 cache timeout active 60
 cache timeout inactive 15

! 4. Flow Sampler の定義 (1:100 サンプリング)
sampler FNF_SAMPLER_1IN100
 mode random 1 out-of 100

! 5. インターフェイスへの適用
interface GigabitEthernet0/0/1
 ip flow monitor FNF_MONITOR_WAN sampler FNF_SAMPLER_1IN100 input
 ip flow monitor FNF_MONITOR_WAN output
```

### 3. SPAN / RSPAN / ERSPAN 設定例

#### (a) Local SPAN
```bash
monitor session 1 source interface GigabitEthernet0/0/1 both
monitor session 1 source interface GigabitEthernet0/0/2 rx
monitor session 1 destination interface GigabitEthernet0/0/10 encapsulation replicate
```

#### (b) RSPAN (Remote SPAN)
```bash
! 全スイッチ共通: RSPAN VLAN 定義
vlan 999
 remote-span

! Source Switch (SW1)
monitor session 1 source interface GigabitEthernet0/1 both
monitor session 1 destination remote vlan 999

! Destination Switch (SW2)
monitor session 1 source remote vlan 999
monitor session 1 destination interface GigabitEthernet0/24
```

#### (c) ERSPAN (Encapsulated Remote SPAN)
```bash
! ERSPAN Source Router (R1)
monitor session 1 type erspan-source
 source interface GigabitEthernet0/0/1 both
 destination
  erspan-id 100
  ip ttl 64
  ip precision 5
  origin ip-address 10.1.1.1
  ip address 10.2.2.2
 no shutdown

! ERSPAN Destination Router (R2)
monitor session 1 type erspan-destination
 destination interface GigabitEthernet0/0/2
 source
  erspan-id 100
  ip address 10.2.2.2
 no shutdown
```


---

## 🔍 検証コマンド

| 目的 | コマンド | 概要 |
| :--- | :--- | :--- |
| **IP SLA 状態確認** | `show ip sla summary` | 全 SLA オペレーションの最新実行結果一覧 |
| **IP SLA 詳細確認** | `show ip sla statistics 1` | 成功/失敗回数、RTT、RTT 履歴の詳細表示 |
| **IP SLA Jitter 確認** | `show ip sla statistics 2 details` | 片道遅延、Jitter (SD/DS)、パケットロス詳細 |
| **Object Track 確認** | `show track` | トラッキングオブジェクトの現在の State (UP/DOWN) |
| **FNF Monitor 状態** | `show flow monitor FNF_MONITOR_WAN` | モニター設定、Exporter 割り当て、キャッシュ行数 |
| **FNF キャッシュ確認** | `show flow monitor FNF_MONITOR_WAN cache format table` | メモリに保持されている生フロー統計テーブル表示 |
| **FNF Exporter 統計** | `show flow exporter FNF_EXPORTER_NMS` | 送信成功/ドロップパケット数、接続状態 |
| **SPAN セッション状態** | `show monitor session 1` | Source/Destination ポート、状態 (Active/Not Active) |
| **ERSPAN 詳細確認** | `show monitor session 1 details` | GRE トンネルパラメータ、送信パケットカウンター |

---

## 🚨 トラブルシュート

| 症状 | 推定原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **IP SLA UDP Jitter が No Connection で失敗** | 対向ルータで `ip sla responder` が未有効化、またはポート遮断 | `show ip sla statistics 2` | 対向ルータで `ip sla responder` を有効化し、ACL で UDP 1967/16384 を許可 |
| **IP SLA 応答があるが Track が DOWN に固定** | Track オブジェクトの種類ミス (`state` vs `reachability`) | `show track 10` | ICMP Echo 等の到達性判断には `reachability` を指定 |
| **FNF Collector にフローデータが届かない** | Flow Monitor が I/F に未アタッチ、または Routing 欠落 | `show flow exporter FNF_EXPORTER_NMS` | Exporter の `source` ルーティング確認、I/F への `ip flow monitor` アタッチ |
| **RSPAN でアナライザにパケットが届かない** | RSPAN VLAN が Trunk で Forwarding されていない、または `remote-span` 宣言漏れ | `show vlan remote-span` | 全スイッチで `vlan X` 配下に `remote-span` を設定し Trunk で許可 |
| **ERSPAN のアナライザで GRE パケットが受信できない** | `erspan-id` 不一致、Outer IP 間で Ping が不通、または MTU ドロップ | `show monitor session 1` | 源/宛先で `erspan-id` を同一にし、GRE Outer IP 間の L3 到達性を確保 |

---

## ⚠ 制限事項

* **IP SLA:**
  * Jitter 測定を行う場合、Source と Responder 間で NTP によるミリ秒単位の時間同期が必須。
  * 高周波プローブ (1秒毎など) を多数設定するとルータの CPU リソースを圧迫する。
* **Flexible NetFlow:**
  * Subinterface や GRE トンネルへの適用時、物理 I/F との重複キャプチャに注意が必要。
  * TCAM 容量制限により、大量の独自 `match` 条件を設定するとハードウェアフローキャッシングが失敗し CPU 処理へフォールバックする。
* **SPAN / RSPAN / ERSPAN:**
  * Destination ポートは通常の L2/L3 スイッチング機能を失い、パケット受信専用（監視アナライザ宛送信専用）となる。
  * ERSPAN は Outer GRE ヘッダー（約 50 バイト）が付与されるため、1500 バイトのフルサイズパケットをミラーリングすると MTU フラグメンテーションが発生する。

---

## 🔄 他技術との関連

* **Static Routing / PBR:** IP SLA Object Tracking と連携し、上流回線障害時にデフォルトルートや Policy Route のネクストホップを自動切り替え。
* **HSRP / VRRP:** IP SLA 追跡に基づき Priority を自動減算（Decrement）し、Standby ルータへ Master 権限を即座に移譲。
* **Embedded Event Manager (EEM):** `event track` をトリガーとして EEM アプレットを起動し、複雑なコンフィグ書き換えや Syslog 発信を自動実行。
* **QoS (MQC) / NBAR2:** FNF で特定したアプリケーション ID を MQC Class-Map (`match protocol`) に反映し、優先制御・帯域制限を適用。

---

## 🧩 比較表

### 1. SPAN vs RSPAN vs ERSPAN

| 比較項目 | SPAN (Local) | RSPAN | ERSPAN |
| :--- | :--- | :--- | :--- |
| **スコープ** | 同一スイッチ内 | 同一 L2 放送ドメイン (VLAN) | 全 L3 ネットワーク (IP 網) |
| **転送メカニズム** | スイッチ内部バックプレーン | RSPAN VLAN (MAC 学習 OFF) | GRE トンネル (EtherType 0x88be) |
| **カプセル化** | なし (生パケット) | RSPAN 802.1Q VLAN タグ | Outer IP ＋ GRE ＋ ERSPAN Header |
| **ルーティング通過** | 不可 | 不可 | 可能 (L3 ルーティング可能) |
| **設定複雑度** | 極めて簡単 | 中程度 (全 SW で VLAN 設定) | 高 (Source/Dest L3 パラメータ) |

---

## 💡 ベストプラクティス

1. **IP SLA ＋ Track には必ず Delay タイマーを設定する:**
   回線が瞬断・フラッピング（Up/Down 繰返し）した際のルーティング再計算や HSRP 状態遷移の嵐を防ぐため、`delay down 10 up 5` を必ず設定する。
2. **Flexible NetFlow では Flow Sampler を活用する:**
   1Gbps 〜 10Gbps などの高速ポートで全パケットをフロー解析すると CPU/TCAM を圧迫するため、`sampler` (1:100 または 1:1000) を適用して負荷を削減する。
3. **ERSPAN 送信時は MTU と Path MTU Discovery に注意する:**
   ERSPAN カプセル化によるオーバーヘッド（50 バイト）を見越し、アナライザポートやコアネットワークの MTU を 1550 バイト以上（Jumbo Frame）に拡張するか、`ip tcp adjust-mss` を調整する。

---


## 📝 ラボ学習・設定サンプル例

### ラボ 1: IP SLA ICMP Echo ＋ Object Tracking ＋ Floating Static Route 自動切替

#### 問題
メイン WAN 回線（10.1.12.2）の障害時に、サブ WAN 回線（10.1.13.2）へ自動的にトラフィックを切り替えるルーティング冗長構成を構築しなさい。

#### 要件
* R1 から対向ルータ（10.1.12.2）宛てに 5 秒周期で ICMP Echo を送信する IP SLA オペレーション 1 を作成すること。
* 応答遅延の閾値を 1000ms、タイムアウトを 2000ms とすること。
* Track オブジェクト 10 を作成し、IP SLA 1 の Reachability を追跡すること。回線フラッピング防止のため `delay down 10 up 5` を設定すること。
* デフォルトルート `0.0.0.0/0` を 10.1.12.2 宛てに設定し、Track 10 と連動させること。バックアップデフォルトルートとして 10.1.13.2 宛てに AD 250 で設定すること。

#### 設定例
```bash
! R1 (Config)
ip sla 1
 icmp-echo 10.1.12.2 source-interface Loopback0
 frequency 5
 threshold 1000
 timeout 2000
ip sla schedule 1 life forever start-time now

track 10 ip sla 1 reachability
 delay down 10 up 5

ip route 0.0.0.0 0.0.0.0 10.1.12.2 track 10
ip route 0.0.0.0 0.0.0.0 10.1.13.2 250
```

#### 検証方法
1. `show ip sla summary` および `show ip sla statistics 1` を実行し、Operation 1 が `OK` で返ってくることを確認。
2. `show track 10` を実行し、State が `Up` であること、アタッチされている Route がルーティングテーブル（`show ip route static`）に掲載されていることを確認。
3. 対向ルータ（10.1.12.2）側でインターフェイスを shutdown させ、10 秒後に `show ip route` でデフォルトルートが 10.1.13.2 に切り替わることを検証。


### ラボ 2: IP SLA UDP Jitter ＋ HSRP Priority Dynamic Decrement

#### 問題
R1 (HSRP Active) の WAN 回線品質劣化（遅延・Jitter 増大）時に、自動的に HSRP Priority を下げて R2 (Standby) へ Gateway 権限をに移譲しなさい。

#### 要件
* R1 から R3 (10.1.30.3: UDP 16384) 宛てに UDP Jitter 測定を行う IP SLA オペレーション 2 を構築すること（R3 側で SLA Responder を有効化すること）。
* IP SLA 2 の State を追跡する Track オブジェクト 20 を作成すること。
* R1 の Gi0/1 (VLAN 10) で HSRPv2 グループ 10 を構成し、仮想 IP `192.168.10.1`、標準 Priority `120`、Preempt (`delay reload 60`) を有効化すること。
* Track 20 が DOWN になった場合、HSRP Priority を `30` 減算 (120 -> 90) させること（R2 の Priority は 100）。

#### 設定例
```bash
! R3 (Responder Config)
ip sla responder

! R1 (Source Config)
ip sla 2
 udp-jitter 10.1.30.3 16384 source-ip 10.1.10.1 num-packets 100 interval 20
 frequency 30
ip sla schedule 2 life forever start-time now

track 20 ip sla 2 state

interface GigabitEthernet0/1
 ip address 192.168.10.2 255.255.255.0
 standby version 2
 standby 10 ip 192.168.10.1
 standby 10 priority 120
 standby 10 preempt delay minimum 30 reload 60
 standby 10 track 20 decrement 30
```

#### 検証方法
1. R1 で `show ip sla statistics 2 details` を実行し、Jitter および RTT が正常に記録されていることを確認。
2. `show standby brief` を実行し、R1 が `Active`、Priority が `120` であることを確認。
3. R3 宛ての通信経路をブロックし、Track 20 が DOWN に変化した後、R1 の HSRP Priority が `90` へ下降して R2 が `Active` に昇格することを検証。


### ラボ 3: IP SLA HTTP 監視 ＋ EEM アプレットによるサービス自動リカバリ

#### 問題
社内 Web サーバー (10.1.100.10) への HTTP 応答が途絶えた際、自動的に Web サーバーが接続されているスイッチポートをバウンス (shutdown / no shutdown) させるリカバリスクリプトを構築しなさい。

#### 要件
* R1 から HTTP GET プロトコルで `http://server.domain.local/` を 30 秒周期で監視する IP SLA 3 を設定すること。
* IP SLA 3 の Reachability を追跡する Track 30 を作成すること。
* EEM アプレット `RESTORE_WEB_PORT` を作成し、Track 30 が DOWN に遷移した際（`event track 30 state down`）に自動的に CLI コマンドを実行して Gi0/0/2 ポートをバウンスさせ、Syslog ログを出力すること。

#### 設定例
```bash
! R1 Config
ip sla 3
 http get http://server.domain.local/
 frequency 30
ip sla schedule 3 life forever start-time now

track 30 ip sla 3 reachability

event manager applet RESTORE_WEB_PORT
 event track 30 state down
 action 1.0 syslog msg "HTTP SLA Failed! Bouncing Switchport Gi0/0/2..."
 action 2.0 cli command "enable"
 action 3.0 cli command "configure terminal"
 action 4.0 cli command "interface GigabitEthernet0/0/2"
 action 5.0 cli command "shutdown"
 action 6.0 cli command "delay 5"
 action 7.0 cli command "no shutdown"
 action 8.0 cli command "end"
```

#### 検証方法
1. `show track 30` で State が `Up` であることを確認。
2. Web サーバーの HTTP サービスを停止させ、Track 30 が DOWN に遷移した瞬間に EEM が起動し、コンソールに Syslog メッセージおよびポートバウンスが実行されることを検証 (`show event manager history events`)。


### ラボ 4: Flexible NetFlow (FNF) モジュール構造 ＋ NetFlow v9 エクスポート

#### 問題
WAN 出口ポート (Gi0/0/1) を通過する L3/L4 トラフィックの送信元・宛先 IP、L4 ポート番号、DSCP、パケット数・バイト数を集計し、外部 NetFlow Collector (10.100.1.50:2055) へ送信しなさい。

#### 要件
* Flow Record `REC_WAN` を作成し、Match キー（`ipv4 protocol`, `ipv4 source address`, `ipv4 destination address`, `transport source-port`, `transport destination-port`）および Collect 値（`counter bytes long`, `counter packets long`, `ipv4 dscp`）を定義すること。
* Flow Exporter `EXP_NMS` を作成し、送信先 IP `10.100.1.50` UDP `2055`、ソース `Loopback0`、Template Data-Timeout `60` 秒に設定すること。
* Flow Monitor `MON_WAN` を作成し、Record `REC_WAN` と Exporter `EXP_NMS` をバインドすること。Active Timeout を 60 秒、Inactive Timeout を 15 秒とすること。
* Gi0/0/1 の Ingress / Egress 双方に Flow Monitor を適用すること。

#### 設定例
```bash
flow record REC_WAN
 match ipv4 protocol
 match ipv4 source address
 match ipv4 destination address
 match transport source-port
 match transport destination-port
 collect counter bytes long
 collect counter packets long
 collect ipv4 dscp

flow exporter EXP_NMS
 destination 10.100.1.50
 source Loopback0
 transport udp 2055
 template data-timeout 60

flow monitor MON_WAN
 record REC_WAN
 exporter EXP_NMS
 cache timeout active 60
 cache timeout inactive 15

interface GigabitEthernet0/0/1
 ip flow monitor MON_WAN input
 ip flow monitor MON_WAN output
```

#### 検証方法
1. `show flow monitor MON_WAN` を実行し、Cache 状態および Exporter アタッチ状態を確認。
2. トラフィック発生後、`show flow monitor MON_WAN cache format table` で保持されているフローテーブルを確認。
3. `show flow exporter EXP_NMS` で Collector 宛てに NetFlow v9 パケットが送信されていることを確認。


### ラボ 5: Flexible NetFlow Flow Sampler (1:100 確率サンプリング) 構成

#### 問題
10Gbps 高速インターフェイス (Gi0/0/0) において、TCAM および CPU リソース保護のため 100 パケットに 1 パケットの割合でランダムサンプリングを行う Flexible NetFlow を設定しなさい。

#### 要件
* Flow Sampler `SAMP_1IN100` を作成し、モードを `random 1 out-of 100` とすること。
* 既存の Flow Monitor `MON_WAN` を Gi0/0/0 の Ingress 方向に対し、Sampler `SAMP_1IN100` を指定して適用すること。

#### 設定例
```bash
sampler SAMP_1IN100
 mode random 1 out-of 100

interface GigabitEthernet0/0/0
 ip flow monitor MON_WAN sampler SAMP_1IN100 input
```

#### 検証方法
1. `show sampler SAMP_1IN100` を実行し、サンプリング設定（1 in 100）を確認。
2. 大量パケット送信時、`show flow monitor MON_WAN cache` で記録されるパケットカウントが実際のパケット数の約 1/100 に抑えられていることを検証。


### ラボ 6: Local SPAN (複合ソース指定 ＋ L2 ヘッダー保持転送)

#### 問題
SW1 の Gi0/1 (Rx/Tx 通信) および Gi0/2 (Rx 通信のみ) を通過する全パケットを、分析端末が接続された Gi0/10 へミラーリングしなさい。その際、被監視パケットの VLAN タグ等の L2 ヘッダーをそのまま保持して分析端末へ送信しなさい。

#### 要件
* SPAN Session 1 を作成すること。
* Source インターフェイスとして Gi0/1 (`both`) および Gi0/2 (`rx`) を指定すること。
* Destination インターフェイスとして Gi0/10 を指定し、`encapsulation replicate` を有効化して VLAN タグ情報を保持した状態でミラーリングすること。

#### 設定例
```bash
! SW1 Config
monitor session 1 source interface GigabitEthernet0/1 both
monitor session 1 source interface GigabitEthernet0/2 rx
monitor session 1 destination interface GigabitEthernet0/10 encapsulation replicate
```

#### 検証方法
1. `show monitor session 1` を実行し、Source ポートの方向（Gi0/1: Both, Gi0/2: Receive only）および Destination ポート（Gi0/10）の状態が `Valid` であることを確認。
2. Gi0/10 に接続した Wireshark で 802.1Q VLAN タグが保持されたパケットが受信できることを検証。


### ラボ 7: Remote SPAN (RSPAN) 複数 L2 スイッチ間ミラーリング

#### 問題
SW1 (Source) の Gi0/1 を通過するパケットを、別棟の SW2 (Destination) の Gi0/24 ポートに接続されたアナライザへ RSPAN を用いて転送しなさい。

#### 要件
* SW1、SW2、および経由する全 L2 スイッチにおいて、RSPAN 専用 VLAN `999` を作成し、`remote-span` を宣言すること。
* スイッチ間の Trunk ポートで VLAN 999 の通過を許可すること。
* SW1 で SPAN Session 1 を構成し、Source を Gi0/1 (`both`)、Destination を `remote vlan 999` とすること。
* SW2 で SPAN Session 1 を構成し、Source を `remote vlan 999`、Destination を Gi0/24 とすること。

#### 設定例
```bash
! SW1 & SW2 & Intermediate SWs Config
vlan 999
 name RSPAN_VLAN
 remote-span

! SW1 (Source Switch Config)
monitor session 1 source interface GigabitEthernet0/1 both
monitor session 1 destination remote vlan 999

! SW2 (Destination Switch Config)
monitor session 1 source remote vlan 999
monitor session 1 destination interface GigabitEthernet0/24
```

#### 検証方法
1. `show vlan remote-span` を実行し、VLAN 999 が Remote SPAN VLAN として認識されていることを全スイッチで確認。
2. SW1 で `show monitor session 1` を実行し Destination が RSPAN VLAN 999 であること、SW2 で `show monitor session 1` を実行し Source が RSPAN VLAN 999 であることを確認。


### ラボ 8: ERSPAN (Encapsulated Remote SPAN) L3 跨ぎキャプチャ

#### 問題
R1 (拠点 A) の Gi0/0/1 ポートを通過するパケットを、L3 IP ネットワークを超えて R2 (データセンター: 10.2.2.2) の Gi0/0/2 ポートにアタッチされたアナライザへ ERSPAN で転送しなさい。

#### 要件
* R1 で ERSPAN Source Session 10 を定義すること (`type erspan-source`)。
* Source を Gi0/0/1 (`both`)、ERSPAN ID を `100`、Header パラメータ（`ip ttl 64`, `ip precision 5`, `origin ip-address 10.1.1.1`）を設定し、Destination IP を `10.2.2.2` とすること。
* R2 で ERSPAN Destination Session 10 を定義すること (`type erspan-destination`)。
* ERSPAN ID を `100`、Source IP を `10.2.2.2` とし、Destination インターフェイスを Gi0/0/2 とすること。

#### 設定例
```bash
! R1 (ERSPAN Source Router)
monitor session 10 type erspan-source
 source interface GigabitEthernet0/0/1 both
 destination
  erspan-id 100
  ip ttl 64
  ip precision 5
  origin ip-address 10.1.1.1
  ip address 10.2.2.2
 no shutdown

! R2 (ERSPAN Destination Router)
monitor session 10 type erspan-destination
 destination interface GigabitEthernet0/0/2
 source
  erspan-id 100
  ip address 10.2.2.2
 no shutdown
```

#### 検証方法
1. R1 および R2 で `show monitor session 10` を実行し、Status が `Active` であることを確認。
2. R1 で `show monitor session 10 details` を実行し、GRE 送信パケットカウンターが増加していることを確認。
3. R2 の Gi0/0/2 ポートで、カプセル化が解除されたオリジナルパケットが届いていることを確認。


### ラボ 9: IP SLA ＋ Object Tracking Boolean 論理演算ルート制御

#### 問題
メイン回線（10.1.12.2）および セカンダリ回線（10.1.14.2）の **双方** が障害になった場合のみ、サードバックアップ回線（10.1.15.2）へ切り替える複合ブール論理トラッキングを構成しなさい。

#### 要件
* IP SLA 1 (10.1.12.2 宛て) および IP SLA 2 (10.1.14.2 宛て) の ICMP Echo オペレーションを作成すること。
* Track 1 (IP SLA 1) および Track 2 (IP SLA 2) の Reachability を追跡すること。
* Track 100 をブール論理演算オブジェクト (`list boolean or`) として作成し、Track 1 または Track 2 のいずれかが UP であれば Track 100 も UP となるよう設定すること。
* デフォルトルート `0.0.0.0/0 10.1.12.2` (AD 10)、`10.1.14.2` (AD 20) を Track 100 に紐付け、失敗時に AD 250 の 10.1.15.2 へ倒し込むこと。

#### 設定例
```bash
! IP SLA 1 & 2
ip sla 1
 icmp-echo 10.1.12.2
 frequency 5
ip sla schedule 1 life forever start-time now

ip sla 2
 icmp-echo 10.1.14.2
 frequency 5
ip sla schedule 2 life forever start-time now

track 1 ip sla 1 reachability
track 2 ip sla 2 reachability

! Boolean OR Logic Track
track 100 list boolean or
 object 1
 object 2

ip route 0.0.0.0 0.0.0.0 10.1.12.2 track 100
ip route 0.0.0.0 0.0.0.0 10.1.14.2 20
ip route 0.0.0.0 0.0.0.0 10.1.15.2 250
```

#### 検証方法
1. `show track 100` で State が `Up` であることを確認。
2. 10.1.12.2 のみを遮断した場合、Track 100 は UP を維持し、ルーティングが 10.1.14.2 へ遷移することを確認。
3. 10.1.12.2 と 10.1.14.2 の双方を遮断した場合、Track 100 が DOWN となり、10.1.15.2 へ切り替わることを検証。


### ラボ 10: Flexible NetFlow (IPFIX / RFC 7011) ＋ CoPP 保護構成

#### 問題
標準規格 IPFIX (RFC 7011) を用いてフロー出力を行い、かつ Control Plane Policing (CoPP) で NetFlow プロトコル（UDP 2055）が過剰発生した際も CPU を保護する堅牢な構成を構築しなさい。

#### 要件
* Flow Exporter `EXP_IPFIX` でプロトコルとして `ipfix` を明示指定すること。
* CoPP ACL `ACL_COPP_NETFLOW` で UDP 2055 を定義し、Control-Plane パイプライン内で帯域制限（Policing）を適用すること。

#### 設定例
```bash
flow record REC_IPFIX
 match ipv4 source address
 match ipv4 destination address
 match transport source-port
 match transport destination-port
 collect counter bytes long

flow exporter EXP_IPFIX
 destination 10.100.1.50
 transport udp 2055
 export-protocol ipfix

flow monitor MON_IPFIX
 record REC_IPFIX
 exporter EXP_IPFIX

! CoPP Integration
ip access-list extended ACL_COPP_NETFLOW
 permit udp any any eq 2055

class-map match-all CM_COPP_NETFLOW
 match access-group name ACL_COPP_NETFLOW

policy-map PM_COPP
 class CM_COPP_NETFLOW
  police 1000000 conform-action transmit exceed-action drop

control-plane
 service-policy input PM_COPP
```

#### 検証方法
1. `show flow exporter EXP_IPFIX` を実行し、Export Protocol が `IPFIX` であることを確認。
2. `show policy-map control-plane` を実行し、CoPP クラス `CM_COPP_NETFLOW` で一致カウントが増加していることを確認。


## ❓ 想定試験問題

### 問 1 (トラブルシューティング / IP SLA UDP Jitter)
R1 で構築した IP SLA オペレーション 2 (UDP Jitter) のステータスを確認したところ、`show ip sla statistics 2` の出力で `Number of failures: 100%`、`Return code: No connection` と表示されていました。IP アドレスおよびルーティングは正常で Ping も通過します。考えられる主な原因と修正コマンドを述べなさい。

#### 解答・解説
**原因:**
対向ルータ (IP SLA Responder 側) で `ip sla responder` コマンドが設定されていないか、またはアクセスリスト (ACL) / Control Plane Policing (CoPP) 等により IP SLA Control Message (UDP ポート 1967) およびデータプローブポート (UDP 16384 等) がブロックされています。

**修正コマンド:**
対向ルータ上で IP SLA Responder を有効化します。
```bash
! 対向ルータ (Responder) で実行
ip sla responder
```


### 問 2 (Design / SPAN vs RSPAN vs ERSPAN)
データセンターのコアスイッチ上にあるアナライザ宛てに、遠隔拠点（L3 WAN 接続）にあるルータのインターフェイスを通過するパケットをキャプチャしてリアルタイム転送する要件があります。最適な技術を選定し、設計上の最も重要な注意点を述べなさい。

#### 解答・解説
**選定技術:** **ERSPAN (Encapsulated Remote SPAN)**
L3 IP ネットワークを越えてパケットをカプセル化転送できるのは ERSPAN (GRE カプセル化) のみです。

**設計上の注意点:**
ERSPAN はパケットに Outer IP ＋ GRE ＋ ERSPAN ヘッダー（合計約 50 バイト）が付与されるため、1500 バイトのフルサイズパケットをキャプチャすると Outer パケットサイズが 1550 バイトとなり、Path MTU を超えてフラグメンテーションやドロップが発生します。ネットワーク全体の MTU を 1550 バイト以上（Jumbo Frame）に拡張するか、アナライザポートで Path MTU を考慮した受信設定を行う必要があります。


### 問 3 (トラブルシューティング / Flexible NetFlow)
R1 の Flexible NetFlow 設定において、`show flow exporter EXP_1` を実行したところ `Packets sent: 0` のままで Collector 宛てにフロー情報が全く送信されていませんでした。Exporter の設定は `destination 10.100.1.50`、`transport udp 2055` となっています。原因と修正方法を説明しなさい。

#### 解答・解説
**原因:**
`flow exporter` 内で `source <interface>`（例: `source Loopback0`）が指定されておらず、かつ出向インターフェイスの IP が不確定であるか、`10.100.1.50` 宛てのルーティングテーブル検索で送信元 IP が決定できずエクスポートパケットの生成に失敗しています。

**修正コマンド:**
`flow exporter` 内で明示的にソースインターフェイスを指定します。
```bash
flow exporter EXP_1
 source Loopback0
```


### 問 4 (コンフィグ読解 / Object Tracking)
以下のコンフィグが設定されたルータにおける、デフォルトルートの動作として正しいものを選択しなさい。

```bash
track 1 ip sla 1 reachability
track 2 ip sla 2 reachability

track 100 list boolean and
 object 1
 object 2

ip route 0.0.0.0 0.0.0.0 10.1.12.2 track 100
ip route 0.0.0.0 0.0.0.0 10.1.13.2 250
```

* A. Track 1 または Track 2 のいずれか一方が DOWN になると、10.1.12.2 宛てのルートが消去され 10.1.13.2 へ切替わる。
* B. Track 1 と Track 2 の両方が DOWN になった場合のみ、10.1.12.2 宛てのルートが消去され 10.1.13.2 へ切替わる。
* C. Track 100 は常に DOWN となり、常に 10.1.13.2 が使用される。
* D. Track 1 が UP であれば Track 2 の状態に関わらず 10.1.12.2 が維持される。

#### 解答・解説
**正解: A**
`list boolean and` オブジェクトは、アタッチされたすべてのオブジェクト（`object 1` および `object 2`）が **UP の場合のみ UP** となります。したがって、Track 1 または Track 2 の **どちらか一方でも DOWN になると Track 100 全体が DOWN** となり、メインのデフォルトルート（`10.1.12.2`）が消去されてバックアップルート（`10.1.13.2` AD 250）へ切り替わります。


### 問 5 (実装 / RSPAN)
SW1 (Source) から SW2 (Destination) へ RSPAN を用いてパケットをミラーリングしようとしましたが、SW2 のアナライザでパケットを受信できません。確認したところ、SW1 と SW2 で `vlan 999` は作成されていますが、`remote-span` コマンドが設定されていませんでした。SW1 および SW2 で設定すべき修正コンフィグを記述しなさい。

#### 解答・解説
RSPAN VLAN として正しくパケットをマルチキャスト Forwarding させ、MAC アドレス学習を無効化するために、全スイッチの VLAN 設定配下で `remote-span` を宣言する必要があります。

```bash
! SW1 & SW2 共通設定
vlan 999
 remote-span
```

---

## 🔗 参考リソース

Cisco 公式のドキュメントおよび Cisco Live セッション資料です。

* Cisco IOS Flexible NetFlow Configuration Guide
* Cisco IP SLAs Configuration Guide, Cisco IOS XE
* Configuring ERSPAN - Cisco Catalyst 9000 Series Switches
* Cisco Live BRKARC-2007 - Network Visibility with Flexible NetFlow
* Cisco Live BRKCRT-2001 - CCIE Enterprise Infrastructure Lessons Learned
* Cisco Technical Notes - Troubleshooting IP SLA Operations
* Cisco Validated Design (CVD) - Campus Network Management and Visibility

---

## 📝 **補足（Notes）**

### 1. 学習メモのおさらい
* **IP SLA:** アクティブプローブによるミリ秒精度の品質計測と、Object Tracking 経由の静的・動的ルーティング自動切り替え。
* **Flexible NetFlow:** キー（`match`）と値（`collect`）の組み合わせによる高自由度なパケットフロー解析と、NetFlow v9 / IPFIX 収集。
* **SPAN / RSPAN / ERSPAN:** L2 ローカル、L2 リモート VLAN、L3 GRE トンネルを介した生パケットアナライザミラーリング。

### 2. トラブルシューティングチェックリスト
* [ ] IP SLA Jitter 測定時、対向側で `ip sla responder` が設定されているか？
* [ ] IP SLA にバインドする Track オブジェクトのタイプ（`reachability` vs `state`）は正しいか？
* [ ] FNF Exporter で `source Loopback0` 等のソース I/F が設定されているか？
* [ ] RSPAN VLAN で全スイッチに `remote-span` 宣言が付与されているか？
* [ ] ERSPAN の Source と Destination で `erspan-id` は一致しているか？


