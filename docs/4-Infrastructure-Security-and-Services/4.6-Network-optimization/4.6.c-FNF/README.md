---
layout: default
title: 4.6.c-FNF
parent: 4.6-Network-optimization
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.6.c Flexible NetFlow

---

## 📘 概要

Flexible NetFlow（FNF）は、Cisco IOS / IOS XE デバイスを通過するネットワークトラフィックの可視化、アカウンティング、セキュリティ分析、QoS 設計検証を目的としたパッシブフロー解析テクノロジーである。従来の Traditional NetFlow（NetFlow v5/v9）が固定されたキーフィールド（5-Tuple: 送信元/宛先 IP アドレス、送信元/宛先 L4 ポート、L3 プロトコル）に基づいてフローを集計していたのに対し、Flexible NetFlow はユーザが自由に「キーフィールド（`match`）」および「非キーフィールド（`collect`）」をカスタマイズ可能なアーキテクチャを提供する。

FNF は以下の主要コンポーネントによるモジュール構造を採用している。
1. **Flow Record:** どのフィールドでパケットを同一フローとして同一視（`match`）し、どのデータ（`collect`）を統計情報として収集するかを定義。
2. **Flow Exporter:** 収集したフロー統計情報をどのコレクター（NMS / Analyzer）へ、どのプロトコル（NetFlow v9 または IPFIX / RFC 7011）、どの UDP ポート、どの送信元 IP アドレスで送信するかを定義。
3. **Flow Monitor:** Flow Record と Flow Exporter を紐付け、キャッシュサイズやタイマー（Active/Inactive Timeout）を管理する実体。
4. **Flow Sampler (オプション):** 高速ポート（10Gbps/100Gbps）において CPU / TCAM 負荷を軽減するため、トラフィックを確率的・統計的にサンプリング（例: 100 パケット中 1 パケット）して Flow Monitor に渡す機構。

CCIE EI v1.1 においては、単なるトラフィック監視にとどまらず、AVC（Application Visibility and Control / NBAR2 連携）、Security / CoPP 連携、QoS ポリシーの効果検証、および IPFIX（RFC 7011）標準出力の実装・トラブルシューティングが深く問われる。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | モジュール型構造（Record, Exporter, Monitor, Sampler）による高度に柔軟なトラフィック解析 |
| **用途** | 帯域利用率分析、セキュリティ異常検知（DDoS/スキャン検出）、QoS マーキング検証、アプリ可視化（NBAR2/AVC 連携） |
| **メリット** | 必要なフィールドのみを収集可能、CPU/メモリ消費の最適化、IPFIX (RFC 7011) 対応、IPv4/IPv6 デュアルスタック・MAC・VRF・TOS/DSCP 等に対応 |
| **デメリット** | 設定項目が多岐にわたる、高トラフィック環境での Cache 設定不備による CPU 高負荷・メモリ枯渇リスク |
| **対応機種** | Catalyst 9000 シリーズ、ISR 4000 シリーズ、ASR 1000 シリーズ、C8000V 等の Cisco IOS XE デバイス全般 |
| **制限事項** | ハードウェア/ASIC 依存の TCAM 制限、サンプリング未適用時の高トラフィックポートでのコントロールプレーン負荷 |
| **設計上の注意点** | Active/Inactive Timeout の適切な調整（Active: 60秒, Inactive: 15秒推奨）、Exporter 送信元 Interface (Loopback) の明示的指定 |

---

## 🏗 動作原理

Flexible NetFlow は、ルータやスイッチのデータプレーンを通過するパケットヘッダー情報を観察し、フローキャッシュ（Flow Cache）テーブルにパケット情報を取り込むことで動作する。

```
Incoming / Outgoing Packet
          │
          ▼
┌────────────────────────────────────────────────────────┐
│  Flow Sampler (オプション)                             │
│  - Random / Deterministic 割合でパケットを抽出         │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│  Flow Monitor (キャッシュエンジン)                     │
│  - Flow Record の match 条件に基づいてキーを抽出       │
│  ┌──────────────────────────────────────────────────┐  │
│  │ Flow Cache Table                                 │  │
│  │ [Key: Src/Dst IP, L4 Port, VRF, etc.]           │  │
│  │ [Non-Key: Packet/Byte Count, Timestamps, DSCP]   │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────┬──────────────────────────────┘
                          │ (Timeout 発生時: Active / Inactive / Cache Full)
                          ▼
┌────────────────────────────────────────────────────────┐
│  Flow Exporter                                         │
│  - NetFlow v9 / IPFIX (RFC 7011) フォーマット変換      │
│  - UDP パケットとして NetFlow コレクターへ送信         │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
             NetFlow Collector (NMS / Stealthwatch)
```

1. **フロー識別 (Flow Identification):**
   パケットがインターフェイスに入力（または出力）された際、Flow Monitor に割り当てられた Flow Record の `match` 条件が評価される。すべての `match` フィールドが既存のキャッシュエントリと一致する場合、そのフローのカウンター（`collect counter packets / bytes`）およびタイムスタンプが更新される。一致するエントリが存在しない場合、新しいフローキャッシュエントリが作成される。
2. **フローの無効化とエクスポート (Flow Aging & Export):**
   キャッシュ内のエントリは以下のイベントにより「エイジングアウト（無効化）」され、Flow Exporter 経由でコレクターに送信される。
   - **Active Timeout (デフォルト 1800 秒 / 推奨 60 秒):** 長時間継続するフロー（例: 大容量ファイル転送）を指定時間ごとに強制的にエクスポートし、コレクター側のグラフ描画をリアルタイム化する。
   - **Inactive Timeout (デフォルト 15 秒):** 一定時間パケットが途絶えたフロー（通信終了）を即座にキャッシュから削除・送信する。
   - **TCP FIN / RST パケット受信:** フラグベースの即時無効化（オプション設定時）。
   - **Cache Full:** キャッシュ容量が限界に達した場合の強制フラッシュ。

---

## ⚙ 動作シーケンス

```
[Packet Input]
      │
      ▼
┌──────────────────────────────────────────────────────────┐
│ Step 1: Sampler チェック                                 │
│ - Sampler が設定されている場合、規定割合でパケットを抽出 │
└─────────┬────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│ Step 2: Flow Record キー評価                             │
│ - match フィールド (例: ipv4 src, ipv4 dst, l4 port) 抽出│
└─────────┬────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│ Step 3: Flow Cache 照合                                  │
│ - 一致あり ➔ collect フィールド (byte, packet count) 加算│
│ - 一致なし ➔ 新規 Flow Cache エントリ作成                │
└─────────┬────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│ Step 4: エイジングタイマー監視                           │
│ - Active Timeout 経過 (60s) OR Inactive Timeout (15s)    │
└─────────┬────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│ Step 5: Exporter によるパケットカプセル化                 │
│ - NetFlow v9 / IPFIX 形式で UDP Datagram 化              │
│ - Template Data と Data Record を定期的に多重化          │
└─────────┬────────────────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│ Step 6: 外部コレクターへの UDP 転送                       │
│ - Source Interface (例: Loopback0) より コレクター宛送信  │
└──────────────────────────────────────────────────────────┘
```


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI ラボ試験における Flexible NetFlow の出題は、単に「NetFlow を有効化せよ」という単純なものではなく、**特定のトラフィック定義・特定のコレクター宛エクスポート・サンプリング・NBAR2/QoS 連携** など、複数の要件が組み合わされた複雑なコンフィグレーションおよびトラブルシューティングとして出題される。

### Blueprint での重要ポイント
1. **カスタマイズされた Flow Record の作成:**
   - 必須の `match` フィールド（IPv4/IPv6 送信元・宛先 IP、L4 送信元・宛先ポート、L3 プロトコル、VRF、インプット/アウトプット I/F）。
   - 収集対象の `collect` フィールド（パケット数、バイト数、到達/離脱タイムスタンプ、TOS/DSCP、TCP フラグ、Application Name）。
2. **Flow Exporter の詳細指定:**
   - 送信先 IP アドレスおよび UDP ポート番号（標準 2055 または 4739）。
   - 送信元インターフェイス（例: `source Loopback0`）。これが抜けるとコレクター側でパケットがドロップされたり、VRF ルーティング不整合が発生する。
   - プロトコル仕様 (`export-protocol netflow-v9` または `ipfix`)。
   - テンプレート管理 (`option exporter-stats`, `template data-timeout 60`)。
3. **Flow Monitor のタイマー調整:**
   - `cache timeout active 60` (デフォルト 1800 秒から変更を求められる)。
   - `cache timeout inactive 15`。
   - `cache entries 10000` (キャッシュエントリ数の制限・拡張)。
4. **Flow Sampler の実装:**
   - 高速インターフェイス（GigabitEthernet / TenGigabitEthernet）上での `sampler` オブジェクト定義とインターフェイスへのアタッチ (`ip flow monitor MON_NAME sampler SAMP_NAME input`)。

---

## 🛠 設定方法

### 1. 標準的な FNF コンフィグレーション例 (NetFlow v9 / IPv4)

```bash
! 1. Flow Record の定義
flow record REC_CCIE_IPV4
 match ipv4 source address
 match ipv4 destination address
 match ipv4 protocol
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
flow exporter EXP_NETFLOW_COLLECTOR
 destination 10.1.100.50 port 2055
 source Loopback0
 transport udp 2055
 export-protocol netflow-v9
 option exporter-stats
 template data-timeout 60

! 3. Flow Monitor の定義
flow monitor MON_CCIE_IPV4
 description IPv4 Traffic Monitoring
 record REC_CCIE_IPV4
 exporter EXP_NETFLOW_COLLECTOR
 cache timeout active 60
 cache timeout inactive 15
 cache entries 8192

! 4. インターフェイスへの適用
interface GigabitEthernet0/0/1
 ip flow monitor MON_CCIE_IPV4 input
 ip flow monitor MON_CCIE_IPV4 output
```

### 2. IPFIX (RFC 7011) ＋ NBAR2 (Application Visibility) ＋ Sampler 構成例

```bash
! Flow Record (NBAR2 アプリケーション認識付き)
flow record REC_IPFIX_AVC
 match ipv4 source address
 match ipv4 destination address
 match ipv4 protocol
 match transport source-port
 match transport destination-port
 match application name
 collect counter bytes long
 collect counter packets long
 collect ipv4 dscp

! Flow Exporter (IPFIX 規格)
flow exporter EXP_IPFIX
 destination 10.1.100.60
 source Loopback0
 transport udp 4739
 export-protocol ipfix
 template data-timeout 30

! Flow Monitor
flow monitor MON_IPFIX
 record REC_IPFIX_AVC
 exporter EXP_IPFIX
 cache timeout active 60
 cache timeout inactive 15

! Flow Sampler (100 パケット中 1 パケットをランダム抽出)
sampler SAMP_1IN100
 mode random 1 out-of 100

! インターフェイス適用 (Sampler 連携)
interface TenGigabitEthernet1/0/1
 ip flow monitor MON_IPFIX sampler SAMP_1IN100 input
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| フローキャッシュ内のアクティブなフロー確認 | `show flow monitor <MON_NAME> cache` |
| フローキャッシュ統計（エントリ数、ドロップ数、タイムアウト数）の確認 | `show flow monitor <MON_NAME> statistics` |
| フローレコータの定義・構成確認 | `show flow record <REC_NAME>` |
| フローエクスポーターの統計・送信状態確認 | `show flow exporter <EXP_NAME> statistics` |
| サンプラーの動作確認 | `show sampler <SAMP_NAME>` |
| インターフェイス上の NetFlow 適用状態確認 | `show ip flow monitor` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **コレクター上でデータが表示されない** | Exporter の `source` 未定義またはルータからコレクターへの L3 到達性欠落 | <code>show flow exporter &lt;EXP&gt; statistics</code> | Exporter 内で `source Loopback0` 等を指定し、ルーティング・ACL を確認 |
| **コレクターのグラフが 30 分ごとにしか更新されない** | Active Timeout がデフォルト（1800秒）のまま放置されている | <code>show flow monitor &lt;MON&gt;</code> | `cache timeout active 60` に変更 |
| **CPU 使用率が異常高騰する** | 高トラフィックインターフェイスで Sampler なしで全パケットを監視している | <code>show process cpu sorted</code> | `sampler` を定義し、確率的サンプリングを導入する |
| **Flow Record が Monitor にバインドできない** | 必須の `match` 条件が不足している、または無効な組み合わせ | <code>show flow record &lt;REC&gt;</code> | 必要な `match` / `collect` フィールドを適切に追加 |
| **`show flow monitor` で `Cache Full` ドロップが発生** | キャッシュサイズ不足、または Active Timeout が長すぎる | <code>show flow monitor &lt;MON&gt; statistics</code> | `cache entries 16384` に拡張し、Active Timeout を短縮 |

---

## ⚠ 制限事項

1. **ハードウェア TCAM 制限 (Catalyst 9000 シリーズ等):**
   スイッチ製品の ASIC において、Flow Cache はハードウェア TCAM に保持される。TCAM 容量を超過した場合、フローはソフトウェア（CPU）へフォールバックされるかドロップされ、CPU 高負荷の原因となる。
2. **Ingress / Egress サンプリング制限:**
   一部のプラットフォーム（ASR 1000 や Catalyst 9300）では、Egress インターフェイスに対する Sampler のアタッチや NBAR2 マッチングにプラットフォーム固有の制限が存在する。
3. **Tunnel / Encapsulation パケットの制限:**
   GRE、IPsec、VXLAN、Geneve 等のトンネル通信において、アウターヘッダー（外側 IP）を監視するかインナーヘッダー（内側 IP）を監視するかはプラットフォームのコマンド仕様（`option tunnel` 等）に依存する。

---

## 🔄 他技術との関連

* **NBAR2 / AVC (Application Visibility and Control):**
  `match application name` を Flow Record 内で使用することで、L7 アプリケーション名（WebEx、YouTube、Citrix 等）を自動識別して NetFlow 統計としてコレクターへ送信可能。
* **QoS (MQC):**
  QoS ポリシー（DSCP マーキングやポリシング）が意図通り機能しているかを検証するため、`collect ipv4 dscp` を含めた FNF を配置してマーキング変更前後の統計を取得する。
* **VRF-Aware Routing:**
  マルチテナント環境において、`match routing vrf input` を含む Flow Record を構成し、かつ Exporter に `destination <IP> vrf <VRF_NAME>` を定義することで、VRF ごとのトラフィック統計を分離管理。
* **CoPP (Control Plane Policing):**
  FNF 自身がエクスポートする UDP パケットや、サンプリングパケットが CPU へ転送される際のレートを CoPP で保護する。

---

## 🧩 比較表

### Traditional NetFlow vs Flexible NetFlow (FNF)

| 比較項目 | Traditional NetFlow (v5/v9) | Flexible NetFlow (FNF) |
| :--- | :--- | :--- |
| **アーキテクチャ** | 固定型（ハードコードされた構造） | モジュール型（Record / Exporter / Monitor / Sampler） |
| **フロー識別条件 (Key)** | 固定 5-Tuple＋In-I/F＋ToS | 完全自由選択（IPv4/IPv6, MAC, VRF, TCP Flags, NBAR2 App） |
| **収集統計情報 (Non-Key)** | 固定（Packets, Bytes, Timestamps） | 完全自由選択（DSCP, Application Name, Layer 2 Header 等） |
| **IPv6 対応** | v5 非対応 / v9 一部対応 | 完全対応（IPv4 / IPv6 デュアルスタック対応） |
| **出力プロトコル** | NetFlow v5 / v9 | NetFlow v9 / IPFIX (RFC 7011) |
| **サンプリング制御** | Sampled NetFlow (グローバルアタッチ) | Flow Sampler (モニター単位での柔軟アタッチ) |

---

## 💡 ベストプラクティス

1. **Active / Inactive Timeout の推奨値指定:**
   リアルタイムなトラフィック可視化とコレクター側の正確な帯域計算のため、`cache timeout active 60` および `cache timeout inactive 15` を標準設定とする。
2. **Exporter の Source Interface 固定:**
   ルータのマルチパス環境における送信元 IP の変動を防ぐため、必ず安定したインターフェイス（`source Loopback0`）を指定する。
3. **10Gbps 以上のポートでの Sampler 適用:**
   10GbE / 100GbE インターフェイスでは、TCAM オーバーフローおよび CPU 飽和を回避するため、必ず `sampler`（例: 1:100 〜 1:1000）を適用する。
4. **IPFIX (RFC 7011) への統一:**
   新規設計においては、ベンダ標準の IPFIX (`export-protocol ipfix`) を選択し、拡張フィーチャーや標準 NMS との互換性を確保する。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: 基本 IPv4 Flexible NetFlow (NetFlow v9) 構成

#### 問題
R1 において、GigabitEthernet0/0/1 を通過する IPv4 トラフィックの 5-Tuple 統計情報を集計し、NetFlow コレクターへ送信するコンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_LAB1_IPV4`
  * キーフィールド: 送信元 IP、宛先 IP、L3 プロトコル、L4 送信元ポート、L4 宛先ポート、入力 I/F
  * 非キーフィールド: パケット数、バイト数、最初のタイムスタンプ、最後のタイムスタンプ
* **Flow Exporter 名:** `EXP_LAB1_NMS`
  * 宛先 IP: `10.1.100.50` (UDP 2055)
  * 送信元 I/F: `Loopback0`
  * プロトコル: `netflow-v9`
* **Flow Monitor 名:** `MON_LAB1_IPV4`
  * Active Timeout: 60 秒
  * Inactive Timeout: 15 秒
* **アタッチ場所:** `GigabitEthernet0/0/1` の Ingress 方向

#### 設定例
```bash
! 1. Flow Record の作成
flow record REC_LAB1_IPV4
 match ipv4 source address
 match ipv4 destination address
 match ipv4 protocol
 match transport source-port
 match transport destination-port
 match interface input
 collect counter bytes long
 collect counter packets long
 collect timestamp sys-uptime first
 collect timestamp sys-uptime last
!
! 2. Flow Exporter の作成
flow exporter EXP_LAB1_NMS
 destination 10.1.100.50 port 2055
 source Loopback0
 transport udp 2055
 export-protocol netflow-v9
 template data-timeout 60
!
! 3. Flow Monitor の作成
flow monitor MON_LAB1_IPV4
 record REC_LAB1_IPV4
 exporter EXP_LAB1_NMS
 cache timeout active 60
 cache timeout inactive 15
!
! 4. インターフェイスへの適用
interface GigabitEthernet0/0/1
 ip flow monitor MON_LAB1_IPV4 input
```

#### 検証方法
```bash
! キャッシュ内にエントリが生成されているか確認
show flow monitor MON_LAB1_IPV4 cache

! Exporter のパケット送信統計確認
show flow exporter EXP_LAB1_NMS statistics
```

---

### ラボ 2: IPFIX (RFC 7011) ＋ タイマー最適化構成

#### 問題
R1 において、国際標準である IPFIX 規格を用いて、トラフィックのフロー情報をコレクターにリアルタイム送信するコンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_IPFIX_STD` (IPv4 5-Tuple ＋ DSCP 収集)
* **Flow Exporter 名:** `EXP_IPFIX_COLLECTOR`
  * 宛先 IP: `192.168.200.10` (UDP ポート 4739)
  * 送信元 I/F: `Loopback0`
  * プロトコル: `ipfix`
* **Flow Monitor 名:** `MON_IPFIX_STD`
  * Active Timeout: 30 秒
  * Inactive Timeout: 10 秒
  * キャッシュ最大エントリ数: 16384
* **アタッチ場所:** `Gi0/0/2` の Ingress 方向

#### 設定例
```bash
! Flow Record
flow record REC_IPFIX_STD
 match ipv4 source address
 match ipv4 destination address
 match ipv4 protocol
 match transport source-port
 match transport destination-port
 collect ipv4 dscp
 collect counter bytes long
 collect counter packets long
!
! Flow Exporter (IPFIX)
flow exporter EXP_IPFIX_COLLECTOR
 destination 192.168.200.10 port 4739
 source Loopback0
 transport udp 4739
 export-protocol ipfix
 option exporter-stats
 template data-timeout 30
!
! Flow Monitor
flow monitor MON_IPFIX_STD
 record REC_IPFIX_STD
 exporter EXP_IPFIX_COLLECTOR
 cache timeout active 30
 cache timeout inactive 10
 cache entries 16384
!
! インターフェイス適用
interface GigabitEthernet0/0/2
 ip flow monitor MON_IPFIX_STD input
```

#### 検証方法
```bash
! IPFIX キャッシュとタイマー設定値の確認
show flow monitor MON_IPFIX_STD

! IPFIX パケットの送信数確認
show flow exporter EXP_IPFIX_COLLECTOR statistics
```

---

### ラボ 3: NBAR2 (Application Visibility) 連携 Flexible NetFlow 構成

#### 問題
R1 において、通過するパケットの L7 アプリケーション名（WebEx、YouTube、Citrix 等）を NBAR2 エンジンで識別し、そのアプリケーション名を含めた NetFlow 統計を抽出するコンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_AVC_APP`
  * キーフィールド: 送信元 IP、宛先 IP、L4 宛先ポート、**`application name`**
  * 非キーフィールド: パケット数、バイト数
* **Flow Exporter 名:** `EXP_AVC` (宛先 `10.2.1.100:2055`)
* **Flow Monitor 名:** `MON_AVC` (Active Timeout 60秒)
* **アタッチ場所:** `Gi0/0/1` の Ingress 方向

#### 設定例
```bash
! NBAR2 プロトコルディスカバリ有効化 (必須前提)
interface GigabitEthernet0/0/1
 ip nbar protocol-discovery
!
! Flow Record (NBAR2 Application Name Match)
flow record REC_AVC_APP
 match ipv4 source address
 match ipv4 destination address
 match transport destination-port
 match application name
 collect counter bytes long
 collect counter packets long
!
! Flow Exporter
flow exporter EXP_AVC
 destination 10.2.1.100 port 2055
 source Loopback0
 transport udp 2055
 export-protocol netflow-v9
!
! Flow Monitor
flow monitor MON_AVC
 record REC_AVC_APP
 exporter EXP_AVC
 cache timeout active 60
 cache timeout inactive 15
!
! インターフェイスアタッチ
interface GigabitEthernet0/0/1
 ip flow monitor MON_AVC input
```

#### 検証方法
```bash
! フローキャッシュ内でアプリケーション名が判定・バインドされているか確認
show flow monitor MON_AVC cache
```

---

### ラボ 4: Flow Sampler (1:100 Random Sampling) 構成

#### 問題
10Gbps 高速インターフェイス TenGigabitEthernet1/0/1 において、CPU / TCAM リソースを保護するために 100 パケット中 1 パケットの確率で確率的サンプリングを行い、NetFlow 解析を実行するコンフィグを構築しなさい。

#### 要件
* **Flow Sampler 名:** `SAMP_RANDOM_100`
  * モード: `random 1 out-of 100`
* **Flow Monitor 名:** `MON_SAMPLING` (既存の Record/Exporter を使用)
* **アタッチ場所:** `TenGigabitEthernet1/0/1` の Ingress 方向

#### 設定例
```bash
! Flow Sampler の作成
sampler SAMP_RANDOM_100
 mode random 1 out-of 100
 description 1-in-100 Random Packet Sampling
!
! インターフェイスへの Sampler アタッチ付き Monitor アタッチ
interface TenGigabitEthernet1/0/1
 ip flow monitor MON_SAMPLING sampler SAMP_RANDOM_100 input
```

#### 検証方法
```bash
! サンプラーの動作状態およびサンプリングカウント確認
show sampler SAMP_RANDOM_100

! アタッチ状態の確認
show ip flow monitor
```

---

### ラボ 5: VRF-Aware Flexible NetFlow 構成

#### 問題
ルータ R1 の顧客用 VRF `VRF_RED` 配下のトラフィックを統計解析し、管理用 VRF `Mgmt-vrf` 経由で配置されたコレクター宛に NetFlow パケットを送出するコンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_VRF_RED`
  * キーフィールド: 送信元/宛先 IP、**`routing vrf input`**
* **Flow Exporter 名:** `EXP_MGMT_VRF`
  * 宛先 IP: `172.16.100.50` (VRF `Mgmt-vrf` 経由)
  * 送信元 I/F: `GigabitEthernet0/0/0` (Mgmt-vrf)
* **Flow Monitor 名:** `MON_VRF_RED`
* **アタッチ場所:** `Gi0/0/1.100` (VRF `VRF_RED` 所属)

#### 設定例
```bash
! Flow Record (VRF キーフィールド付き)
flow record REC_VRF_RED
 match ipv4 source address
 match ipv4 destination address
 match routing vrf input
 collect counter bytes long
 collect counter packets long
!
! Flow Exporter (VRF 指定 Exporter)
flow exporter EXP_MGMT_VRF
 destination 172.16.100.50 vrf Mgmt-vrf port 2055
 source GigabitEthernet0/0/0
 transport udp 2055
 export-protocol netflow-v9
!
! Flow Monitor
flow monitor MON_VRF_RED
 record REC_VRF_RED
 exporter EXP_MGMT_VRF
 cache timeout active 60
 cache timeout inactive 15
!
! サブインターフェイスアタッチ
interface GigabitEthernet0/0/1.100
 encapsulation dot1Q 100
 vrf forwarding VRF_RED
 ip address 10.100.1.1 255.255.255.0
 ip flow monitor MON_VRF_RED input
```

#### 検証方法
```bash
! VRF 情報が保持されたフローキャッシュ確認
show flow monitor MON_VRF_RED cache

! VRF 明示 Exporter の動作確認
show flow exporter EXP_MGMT_VRF statistics
```

---

### ラボ 6: IPv6 トラフィック専用 Flexible NetFlow 構成

#### 問題
R1 において、IPv6 パケットのみを識別・抽出して IPv6 固有のヘッダー属性を監視する NetFlow 構成を構築しなさい。

#### 要件
* **Flow Record 名:** `REC_IPV6_ONLY`
  * キーフィールド: `ipv6 source address`, `ipv6 destination address`, `ipv6 protocol`, `transport source-port`, `transport destination-port`
  * 非キーフィールド: `ipv6 extension header`, `counter bytes long`, `counter packets long`
* **Flow Exporter 名:** `EXP_IPV6_NMS` (IPv6 コレクター `2001:DB8:100::50` 宛て)
* **Flow Monitor 名:** `MON_IPV6_ONLY`
* **アタッチ場所:** `Gi0/0/1` の Ingress 方向

#### 設定例
```bash
! IPv6 Flow Record
flow record REC_IPV6_ONLY
 match ipv6 source address
 match ipv6 destination address
 match ipv6 protocol
 match transport source-port
 match transport destination-port
 collect ipv6 extension header
 collect counter bytes long
 collect counter packets long
!
! IPv6 Flow Exporter
flow exporter EXP_IPV6_NMS
 destination 2001:DB8:100::50 port 2055
 source Loopback0
 transport udp 2055
 export-protocol netflow-v9
!
! Flow Monitor
flow monitor MON_IPV6_ONLY
 record REC_IPV6_ONLY
 exporter EXP_IPV6_NMS
 cache timeout active 60
 cache timeout inactive 15
!
! インターフェイスアタッチ
interface GigabitEthernet0/0/1
 ipv6 flow monitor MON_IPV6_ONLY input
```

#### 検証方法
```bash
! IPv6 フローキャッシュの確認
show flow monitor MON_IPV6_ONLY cache
```

---

### ラボ 7: L2 MAC アドレス ＋ VLAN 追跡 Flexible NetFlow 構成

#### 問題
スイッチ SW1 の L2 トランクポートにおいて、レイヤ 2 属性（送信元/宛先 MAC アドレス、VLAN ID）をフローキーとして集計し、MAC アドレスベースでの通信分析を行うコンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_L2_MAC`
  * キーフィールド: `datalink mac source-address`, `datalink mac destination-address`, `datalink vlan input`
  * 非キーフィールド: `counter bytes long`, `counter packets long`
* **Flow Monitor 名:** `MON_L2_MAC`
* **アタッチ場所:** `GigabitEthernet1/0/10` (Trunk Port)

#### 設定例
```bash
! L2 Flow Record
flow record REC_L2_MAC
 match datalink mac source-address
 match datalink mac destination-address
 match datalink vlan input
 collect counter bytes long
 collect counter packets long
!
! Flow Monitor
flow monitor MON_L2_MAC
 record REC_L2_MAC
 cache timeout active 60
 cache timeout inactive 15
!
! L2 ポートアタッチ
interface GigabitEthernet1/0/10
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
 mac packet-classify
 mac flow monitor MON_L2_MAC input
```

#### 検証方法
```bash
! MAC アドレスベースのフローキャッシュ確認
show flow monitor MON_L2_MAC cache
```

---

### ラボ 8: QoS DSCP マーキング検証用 Flexible NetFlow 構成

#### 問題
R1 の Egress インターフェイスにおいて、QoS ポリシーによって正しく DSCP 値（DSCP EF, AF41, CS3 等）が適用・マーキングされているかを追跡・検証する FNF コンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_QOS_CHECK`
  * キーフィールド: `ipv4 source address`, `ipv4 destination address`, **`ipv4 dscp`**
  * 非キーフィールド: `counter bytes long`, `counter packets long`
* **Flow Monitor 名:** `MON_QOS_CHECK`
* **アタッチ場所:** `Gi0/0/2` の **Egress (output)** 方向

#### 設定例
```bash
! QoS 検証用 Flow Record
flow record REC_QOS_CHECK
 match ipv4 source address
 match ipv4 destination address
 match ipv4 dscp
 collect counter bytes long
 collect counter packets long
!
! Flow Monitor
flow monitor MON_QOS_CHECK
 record REC_QOS_CHECK
 cache timeout active 30
 cache timeout inactive 10
!
! Egress インターフェイス適用
interface GigabitEthernet0/0/2
 ip flow monitor MON_QOS_CHECK output
```

#### 検証方法
```bash
! Egress パケットの DSCP 値ごとのフローキャッシュ確認
show flow monitor MON_QOS_CHECK cache
```

---

### ラボ 9: TCP フラグ ＋ タイムスタンプ詳細解析用 Flexible NetFlow 構成

#### 問題
セキュリティ異常検知（SYN スキャンや DDoS 攻撃）を行うため、TCP フラグ（SYN, ACK, FIN, RST）およびミリ秒精度の高精度タイムスタンプを取得する FNF コンフィグを構築しなさい。

#### 要件
* **Flow Record 名:** `REC_SEC_ANALYSIS`
  * キーフィールド: `ipv4 source address`, `ipv4 destination address`, `transport source-port`, `transport destination-port`, `transport tcp-flags`
  * 非キーフィールド: `timestamp sys-uptime first`, `timestamp sys-uptime last`, `counter packets long`
* **Flow Monitor 名:** `MON_SEC_ANALYSIS`
* **アタッチ場所:** WAN インターフェイス `Gi0/0/0` の Ingress 方向

#### 設定例
```bash
! セキュリティ解析用 Flow Record
flow record REC_SEC_ANALYSIS
 match ipv4 source address
 match ipv4 destination address
 match transport source-port
 match transport destination-port
 match transport tcp-flags
 collect timestamp sys-uptime first
 collect timestamp sys-uptime last
 collect counter packets long
!
! Flow Monitor
flow monitor MON_SEC_ANALYSIS
 record REC_SEC_ANALYSIS
 cache timeout active 30
 cache timeout inactive 10
!
! インターフェイス適用
interface GigabitEthernet0/0/0
 ip flow monitor MON_SEC_ANALYSIS input
```

#### 検証方法
```bash
! TCP フラグ情報が含まれるフローキャッシュ確認
show flow monitor MON_SEC_ANALYSIS cache
```

---

### ラボ 10: 複数 Exporter 宛てマルチキャスト/デュアルエクスポート 構成

#### 問題
R1 において、1 つの Flow Monitor で収集した同じフローデータを、プライマリ NMS（`10.1.100.50`）とセカンダリ分析サーバー（`10.1.200.50`）の 2 箇所へ同時に二重送信（Dual Export）するコンフィグを構築しなさい。

#### 要件
* **Flow Exporter 1:** `EXP_PRIMARY` (`10.1.100.50:2055`)
* **Flow Exporter 2:** `EXP_SECONDARY` (`10.1.200.50:2055`)
* **Flow Monitor 名:** `MON_DUAL_EXPORT` (両方の Exporter をバインド)
* **アタッチ場所:** `Gi0/0/1` の Ingress 方向

#### 設定例
```bash
! Exporter 1
flow exporter EXP_PRIMARY
 destination 10.1.100.50 port 2055
 source Loopback0
 transport udp 2055
 export-protocol netflow-v9
!
! Exporter 2
flow exporter EXP_SECONDARY
 destination 10.1.200.50 port 2055
 source Loopback0
 transport udp 2055
 export-protocol netflow-v9
!
! Flow Monitor (複数 Exporter を登録)
flow monitor MON_DUAL_EXPORT
 record REC_LAB1_IPV4
 exporter EXP_PRIMARY
 exporter EXP_SECONDARY
 cache timeout active 60
 cache timeout inactive 15
!
! インターフェイス適用
interface GigabitEthernet0/0/1
 ip flow monitor MON_DUAL_EXPORT input
```

#### 検証方法
```bash
! 両方の Exporter からパケットが送信されていることを確認
show flow exporter EXP_PRIMARY statistics
show flow exporter EXP_SECONDARY statistics
```


## ❓ 想定試験問題

### 問 1 (コンフィグ読解 / Active Timeout)

以下のコンフィグが適用されたルータにおいて、コレクター上のトラフィックグラフが 30 分に 1 回しかスパイク状に更新されない現象が発生している。原因と修正方法を説明しなさい。

```bash
flow record REC_1
 match ipv4 source address
 match ipv4 destination address
 collect counter bytes long

flow monitor MON_1
 record REC_1
 exporter EXP_1

interface GigabitEthernet0/0/1
 ip flow monitor MON_1 input
```

#### 正解・解説
* **原因:** `flow monitor` 内で `cache timeout active` が明示的に設定されていないため、デフォルトの Active Timeout 値である **1800 秒（30 分）** が適用されている。このため、継続するフローの情報が 30 分経過するまでコレクターに送信されない。
* **修正方法:** `flow monitor MON_1` 配下に `cache timeout active 60` を追加設定する。

---

### 問 2 (トラブルシューティング / Exporter 送信不能)

ルータ R1 で FNF を設定したが、コレクター `10.1.100.50` 宛ての NetFlow パケットが全く出力されない。`show flow exporter EXP_1 statistics` を確認したところ、`Packets sent: 0` であった。考えられる主要な原因を 2 つ挙げなさい。

#### 正解・解説
1. **Flow Exporter 内での `source` インターフェイス指定の欠落:**  
   `source <interface>` が設定されていない場合、送信元 IP が不確定となりパケット生成に失敗するか、コレクター側の逆引き/ルックアップで拒否される。
2. **ルーティングまたは ACL によるコレクターへの到達性遮断:**  
   ルータからコレクター IP（`10.1.100.50`）への L3 ルートが存在しない、または Outbound ACL で UDP 2055/4739 がブロックされている。

---

### 問 3 (Design / 10Gbps 高速ポートにおける負荷軽減)

10Gbps のコアスイッチにおいて、全トラフィックに対して FNF を適用したところ、スイッチの CPU 使用率が 85% まで上昇し、フローキャッシュテーブルでドロップが発生した。スイッチのパフォーマンスを維持しつつトラフィック可視化を継続するための最適な設計方針を答えなさい。

#### 正解・解説
* **解答:** **Flow Sampler（確率的サンプリング）** を導入する。
* **解説:** `sampler` オブジェクト（例: `mode random 1 out-of 100` または `1 out-of 1000`）を作成し、`ip flow monitor <MON> sampler <SAMP> input` としてインターフェイスに適用することで、100〜1000 パケットに 1 パケットのみを抽出してフローキャッシュに取り込ませる。これにより、TCAM 消費と CPU 処理オーバーヘッドを大幅に削減できる。

---

### 問 4 (実装 / NBAR2 アプリケーション可視化)

ルータ R1 の `Gi0/0/1` を通過するトラフィックから、L7 アプリケーション名（`application name`）をキャプチャし、IPFIX 規格（UDP ポート 4739）でコレクター `192.168.10.100` へ送信するコンフィグを作成しなさい。

#### 正解・解説
```bash
! インターフェイスでの NBAR2 有効化
interface GigabitEthernet0/0/1
 ip nbar protocol-discovery

! Flow Record
flow record REC_APP_IPFIX
 match ipv4 source address
 match ipv4 destination address
 match application name
 collect counter bytes long
 collect counter packets long

! Flow Exporter (IPFIX)
flow exporter EXP_IPFIX
 destination 192.168.10.100 port 4739
 source Loopback0
 transport udp 4739
 export-protocol ipfix

! Flow Monitor
flow monitor MON_APP_IPFIX
 record REC_APP_IPFIX
 exporter EXP_IPFIX
 cache timeout active 60
 cache timeout inactive 15

! インターフェイスアタッチ
interface GigabitEthernet0/0/1
 ip flow monitor MON_APP_IPFIX input
```

---

### 問 5 (コンフィグ読解 / IPFIX 規格)

次の出力結果から判別できるシステム構成および動作状態に関する記述として正しいものを 2 つ選べ。

```text
# show flow exporter EXP_NETFLOW statistics
Flow Exporter EXP_NETFLOW:
  Packet send failure: 0
  Export protocol: IPFIX (RFC 7011)
  Transport Configuration:
    Destination IP address: 10.10.10.1
    Source IP address: 172.16.1.1 (Loopback0)
    Transport Protocol: UDP
    Destination Port: 4739
```

1. コレクター宛ての通信プロトコルとして NetFlow v9 が使用されている。
2. 送信元 IP アドレスとして Loopback0 の `172.16.1.1` が使用されている。
3. 宛先ポートとして標準の NetFlow v5/v9 ポートである UDP 2055 が使用されている。
4. 送信規格として IETF 標準の IPFIX (RFC 7011) が使用されている。

#### 正解・解説
* **正解:** **2, 4**
* **解説:** 出力ログより、`Export protocol: IPFIX (RFC 7011)`、`Source IP address: 172.16.1.1 (Loopback0)`、`Destination Port: 4739` であることが明確に確認できる。

---

## 🔗 参考リソース

### Cisco 公式ドキュメント・ガイド
* Cisco Flexible NetFlow Configuration Guide, Cisco IOS XE Dublin 17.x
* Cisco Command Reference - Flexible NetFlow Commands
* Flexible NetFlow Feature Overview - Cisco Technical Notes
* Cisco IPFIX and AVC Implementation Guide

### Cisco Live セッション資料
* Cisco Live BRKARC-2011 - Deep Dive into Flexible NetFlow and IPFIX Architecture
* Cisco Live BRKCRS-3147 - Application Visibility and Control (AVC) with FNF and NBAR2

### YouTube 動画（演習・解説）
* Cisco Flexible NetFlow Configuration and Verification Step-by-Step
* CCIE Lab Prep: Configuring IPFIX and FNF on Cisco IOS XE

---

## 📝 **補足（Notes）**

### FNF 構築時のチェックリスト
1. **Record の評価:** `match` キーと `collect` 非キーフィールドの整合性が保たれているか？
2. **Exporter の評価:** `source` インターフェイス（例: `Loopback0`）が指定されているか？ UDP ポート（2055 / 4739）はコレクターと一致しているか？
3. **Monitor の評価:** `cache timeout active 60` および `cache timeout inactive 15` が追加されているか？
4. **Interface の評価:** 正しい方向（`input` / `output`）に `ip flow monitor` がアタッチされているか？ 高速ポートで `sampler` が必要な場合は適用されているか？


## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKTRS-2811: Overview of Packet Capturing and Traffic Analysis Tools**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-2811)
    *   FNF を含む可視化ツールの全容解説。
*   [**BRKOPS-2431: Network Automation in Theory and Practice - YANG and Telemetry**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   モデル駆動型テレメトリと NetFlow の統合。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Flexible NetFlow Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fnetflow/configuration/xe-17/fnf-xe-17-book.html)。
*   [**Configuring NetFlow Top Talkers**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/netflow/configuration/15-mt/nf-15-mt-book/cfg-top-talkers.html)。

### テクニカルドキュメント・設定例
*   [**Flexible NetFlow Components and Configuration (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/flexible-netflow/118835-configure-fnf-00.html)。
*   [**NetFlow v5, v9 and IPFIX Comparison**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fnetflow/configuration/xe-16/fnf-xe-16-book/fnf-ipfix-export.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験における **「ネットワークの透明性（Visibility）」** の確保を目的としています。試験では、**`show flow monitor cache`** を自在に使いこなし、特定のトラフィックが意図通りにキャプチャされているかを即座に証明できることが、合格への確実なステップとなります。


