---
layout: default
title: 4.5.b-Time-sync
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.5.b Time synchronization protocols

## 📘 概要

* **機能概要:** ネットワークデバイス間で正確かつ一貫した時刻情報（日時・タイムスタンプ）を共有・同期するためのプロトコル群。CCIE EI v1.1 Blueprint では、クライアントとしての **NTP (Network Time Protocol - RFC 5905)** および超高精度時刻同期プロトコル **PTP (Precision Time Protocol / IEEE 1588v2)** の設計・実装考慮事項が対象。
* **利用目的:** ログ（Syslog）のミリ秒精度タイムスタンプ相関分析、セキュリティ証明書（X.509 PKI / IPsec IKEv2）の有効期限検証、802.1X 認証チケット検証、認証障害の防止、金融取引・5G モバイル・QoS 計測（OWAMP/TWAMP）等におけるマイクロ秒〜ナノ秒単位の時刻同期確立。
* **どのような場面で利用するか:**
  - **NTP (Client):** 企業ネットワーク全域の Catalyst スイッチ、ISR/ASR ルータ、SD-WAN Edge、SD-Access Fabric 機器が上位 NTP サーバー（Stratum 1/2）に同期する標準構成。
  - **PTP (IEEE 1588v2):** 音声/動画配信（AES67 / SMPTE ST 2059-2）、スマートグリッド、金融取引など、NTP（ミリ秒精度）では対応できないサブマイクロ秒〜ナノ秒単位の精度が要求されるミッションクリティカル環境。

---

## 🔑 要点

| 項目 | NTP (Network Time Protocol) | PTP (Precision Time Protocol / IEEE 1588v2) |
| :--- | :--- | :--- |
| **標準規格** | RFC 5905 (NTPv4) / UDP Port 123 | IEEE 1588v2 / UDP Port 319 (Event), 320 (General) または L2 EtherType 0x88F7 |
| **精度レベル** | ミリ秒（1〜10ms 程度） | サブマイクロ秒〜ナノ秒（< 1μs） |
| **トランスポート** | IP / UDP (Port 123) | L2 Ethernet 直接カプセル化 または L3 IP/UDP (Unicast / Multicast) |
| **アーキテクチャ** | Client/Server, Peer, Broadcast/Multicast | Grandmaster Clock (GMC), Boundary Clock (BC), Transparent Clock (TC), Ordinary Clock (OC) |
| **ハードウェア要件** | ソフトウェア処理（CPU）ベース | ハードウェア・タイムスタンプ（ASIC/PHY）機能が必須 |
| **認証メカニズム** | MD5 / SHA-1 Symmetric Key 認証 | PTPv2 では標準認証なし（802.1X や Macsec / IPsec で保護） |
| **主な用途** | Syslog、PKI 証明書、ルーティングログ、一般的な管理 | 金融取引、放送メディア (ST 2059-2)、5G 基地局同期、産業用オートメーション |
| **設計上の注意点** | Access-Group によるセキュリティ制御、Stratum ループ防止、VRF 追従 | BMCA (Best Master Clock Algorithm) 選定、ネットワーク全段での BC/TC 追従、QoS 優先割り当て |

---

## 🏗 動作原理

### 1. NTP クライアント 4-Timestamp 同期フロー

```
NTP Client                                     NTP Server
    │                                              │
    │ ─── Request (T1: 送信時刻) ────────────────> │ (T2: 受信時刻)
    │                                              │
    │ <── Response (T4: 受信時刻) ─────────────── │ (T3: 送信時刻)
    │                                              │
```

* **往復パケット遅延 (Round-Trip Delay):** `δ = (T4 - T1) - (T3 - T2)`
* **クロックオフセット (Clock Offset):** `θ = ((T2 - T1) + (T3 - T4)) / 2`
* クライアントは算出したオフセット θ に基づき、ローカルシステムクロックを徐々に補正（Slew）または即時変更（Step）する。

### 2. PTP (IEEE 1588v2) メッセージ交換フロー (Two-Step Clock)

```
Master Clock (GMC/BC)                          Slave Clock (OC/BC)
    │                                              │
    │ ─── Sync Message (T1 送信) ────────────────> │ (T2 受信)
    │ ─── Follow_Up Message (T1 精密値通知) ────> │
    │                                              │
    │ <── Delay_Req Message (T3 送信) ──────────── │ (T3 送信)
    │ ─── Delay_Resp Message (T4 受信通知) ──────> │ (T4 受信)
    │                                              │
```

* **Master -> Slave パス遅延:** `Dm->s = T2 - T1`
* **Slave -> Master パス遅延:** `Ds->m = T4 - T3`
* **平均ネットワーク遅延:** `Mean Delay = ((T2 - T1) + (T4 - T3)) / 2`
* **Slave クロックオフセット:** `Offset = (T2 - T1) - Mean Delay`

---

## ⚙ 動作シーケンス

### NTP Client の同期シーケンス
1. **設定取得・ソケット初期化:** `ntp server <IP>` または `ntp server vrf <NAME> <IP>` 設定により UDP 123 ソケットをオープン。
2. **ポーリング開始:** 設定されたポーリング間隔（デフォルト 64秒 ～ 1024秒）で NTP クエリパケットを送出。
3. **認証チェック:** 認証が有効な場合、MD5/SHA1 キーでパケットハッシュ値を検証。不一致時はパケットを破棄。
4. **クロックフィルター ＆ ピア選定:** 複数の NTP サーバーから受信したサンプルデータに対し、最小ジッター・Stratum 値・Reachability（8進数 377）を評価し、同期対象（`sys.peer`）を選定。
5. **クロックドリアル調整 (Slewing):** 大幅な時刻飛びを避けるため、1秒間に数ミリ秒のペースで時計の進みを微調整。

### PTP (IEEE 1588v2) の選定・同期シーケンス
1. **Announce パケット受信:** 全 PTP クロックが Announce メッセージをマルチキャスト送信。
2. **BMCA (Best Master Clock Algorithm) 実行:** 各ノードは Priority1 ➔ Clock Class ➔ Clock Accuracy ➔ Clock Variance ➔ Priority2 ➔ MAC Address の優先順位で最良の Grandmaster Clock (GMC) を選出。
3. **ポートロール決定:** 各 PTP ポートは `Master`、`Slave`、`Passive` のいずれかのロールに遷移。
4. **Sync / Follow_Up メッセージ交換:** Master ポートから Sync メッセージを発信し、ハードウェア・タイムスタンプ T1, T2 を計測。
5. **Delay_Req / Delay_Resp メッセージ交換:** Slave ポートから Delay_Req を送出し、T3, T4 を計測してサブマイクロ秒精度で同期を完了。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
* **NTP Client 設定:** `ntp server <IP> [prefer] [key <ID>] [version <1-4>]`
* **VRF-Aware NTP:** 管理 VRF やデータ面 VRF 経由での NTP 同期 (`ntp server vrf <VRF_NAME> <IP>`)
* **NTP Access-Group によるセキュリティ制限:**
  - `peer`: 時刻同期とクエリ応答の双方を許可
  - `serve`: 時刻の提供と制御クエリを許可（同期要求は拒否）
  - `serve-only`: 時刻の提供（NTP レスポンス）のみ許可
  - `query-only`: NTP 制御クエリ（`ntpq` 等）のみ許可
* **PTP ドメイン ＆ モード設計:**
  - Catalyst 9000 シリーズにおける PTP Boundary Clock (BC) 設定
  - `ptp mode boundary` / `ptp domain <0-127>`
  - PTP トランスポートモデル (L2 Ethernet vs L3 IPv4/UDP)
  - PTP 優先制御 (MQC DSCP CS6 / EF マーキング)

### ラボ試験で狙われやすい制限事項・注意点
* **NTP 認証のミスマッチ:** `ntp authenticate` のグローバル有効化漏れ、または `ntp trusted-key` の指定漏れにより、パケットは届いているが同期しない（`show ntp status` で `unsynchronized`）。
* **VRF 経由の NTP ソース指定:** VRF を使用している場合、`ntp source` コマンドにも VRF または適切なインターフェイスを指定する必要がある。
* **PTP のハードウェア要件:** PTP は ASIC / PHY レベルのタイムスタンプ処理を伴うため、SVI インターフェイスや一部のトンネルインターフェイス上では制限がある。
* **PTP と QoS の干渉:** ネットワーク混雑時に PTP パケットが遅延（PDV: Packet Delay Variation）すると PTP 精度が著しく劣化するため、Egress で Strict Priority Queue (LLQ) に割り当てる。

---

## 🛠 設定方法

### 1. NTP Client (MD5 認証 ＋ VRF ＋ Access-Group 制限) コンフィグ例

```bash
! 1. NTP 認証キーと信頼キーの定義
ntp authentication-key 1 md5 CiscoCcieKey123! 7
ntp trusted-key 1
ntp authenticate

! 2. アクセス制御リスト (NTP サーバーからの同期パケットのみ許可)
ip access-list extended ACL_NTP_SERVER
 permit ip host 10.1.100.50 any
 permit ip host 10.1.100.51 any

! 3. Access-Group による保護 (指定サーバーからの同期のみ許可)
ntp access-group peer ACL_NTP_SERVER

! 4. ソースインターフェイスと VRF を指定した NTP サーバーの設定
ntp source Loopback0
ntp server vrf Mgmt-vrf 10.1.100.50 key 1 prefer
ntp server vrf Mgmt-vrf 10.1.100.51 key 1
```

### 2. PTP Boundary Clock (Catalyst 9300 / IOS XE) コンフィグ例

```bash
! 1. グローバル PTP モードおよびドメインの有効化
ptp mode boundary
ptp domain 24
ptp transport ipv4 udp

! 2. 上流 GMC 接続ポート (Slave ロール候補)
interface GigabitEthernet1/0/1
 description === Uplink to Grandmaster Clock ===
 ptp enable
 ptp vlan 100

! 3. 下流 Access ノード接続ポート (Master ロール)
interface GigabitEthernet1/0/12
 description === Downlink to Access Switches ===
 ptp enable
 ptp vlan 100
 ptp role master
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **NTP 同期ステータスの確認** | <code>show ntp status</code> |
| **NTP ピア/サーバー一覧と同期状態確認** | <code>show ntp associations</code> |
| **NTP ピアの詳細・ジッター確認** | <code>show ntp associations detail</code> |
| **PTP グローバル動作状態確認** | <code>show ptp clock</code> |
| **PTP ポート状態（Master/Slave）確認** | <code>show ptp port</code> |
| **PTP 近隣ノード・遅延の確認** | <code>show ptp parent</code> |
| **NTP パケットデバッグ** | <code>debug ntp packets</code> |
| **NTP イベントデバッグ** | <code>debug ntp events</code> |
| **PTP イベントデバッグ** | <code>debug ptp messages</code> |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **NTP がいつまで経っても `unsynchronized` のまま** | インバウンド ACL で UDP 123 がブロックされている、または NTP 認証キーが一致していない | <code>show ntp status</code><br><code>show ntp associations detail</code> | ACL に `permit udp host <SERVER> eq 123 any` を追加、または `ntp authentication-key` を再確認 |
| **NTP パケットは送信されているが応答がない** | `ntp server vrf` の VRF 名指定漏れ、または `ntp source` のルーティング不通 | <code>show ip route vrf <NAME></code><br><code>debug ntp packets</code> | 正しい VRF を指定し、ソース IP が NTP サーバーから到達可能であることを確認 |
| **PTP ポートが `Faulty` または `Listening` のまま遷移しない** | PTP ドメイン番号、トランスポートモード（L2/L3）または VLAN ID の不一致 | <code>show ptp port</code><br><code>show ptp clock</code> | 両端で `ptp domain` および `ptp transport` の設定を統一 |
| **PTP 同期精度が著しく低下しジッターが大きい** | 途中のスイッチが PTP 非対応（Ordinary Switch）、または QoS で PTP トラフィックが遅延している | <code>show ptp parent</code> | 途中のスイッチを PTP BC/TC 対応機に変更し、MQC で PTP パケットを Strict Priority Queue (LLQ) にアタッチ |

---

## ⚠ 制限事項

* **NTPv4 制限:** ソフトウェアベースの処理であるため、ミリ秒以下の精度保証は不可。過度なポーリング間隔短縮は CPU 負荷を高める。
* **PTP バージョン互換性:** PTPv1 (IEEE 1588-2002) と PTPv2 (IEEE 1588-2008 / v2.1) は互換性がない。CCIE EI では PTPv2 が標準。
* **PTP 機能サポート制限:** 一部のモジュール型スイッチやルータカードでは、特定のラインカードでのみ PTP ハードウェアタイムスタンプがサポートされる。

---

## 🔄 他技術との関連

* **Syslog / Logging:** 正確な時刻同期がない場合、複数デバイスに跨るイベント追跡およびセキュリティインシデント解析が不適解となる。
* **PKI / IPsec VPN:** X.509 証明書の有効期限（Not Before / Not After）検証において、時刻がズレていると IKEv2 / IPsec トンネルの確立が拒否される。
* **Control Plane Policing (CoPP):** NTP (UDP 123) や PTP (UDP 319/320, EtherType 0x88F7) を CoPP で誤ってドロップしないよう Class-Map で明示許可する。
* **QoS (MQC):** PTP パケットを Egress Queuing の LLQ (Low Latency Queuing) や DSCP CS6 / EF にバインドして遅延バリエーションを極小化する。

---

## 🧩 比較表

| 評価軸 | NTP (Network Time Protocol) | PTP (IEEE 1588v2) |
| :--- | :--- | :--- |
| **目標精度** | ミリ秒オーダー (10^-3 s) | サブマイクロ秒〜ナノ秒オーダー (< 10^-6 s) |
| **タイムスタンプ位置** | アプリケーション層（OS ソフトウェア） | MAC / PHY 層（ハードウェア ASIC） |
| **ネットワーク依存** | スイッチの非対応を許容 | ネットワーク内の全スイッチが BC または TC であることが推奨 |
| **パケットオーバーヘッド** | 極めて低い（数分に1回程度） | 高い（1秒間に数回〜数十回のメッセージ交換） |
| **設定の複雑さ** | 低い（サーバー IP を指定するのみ） | 中〜高（ドメイン、トランスポート、クロックロール、QoS 連携） |

---

## 💡 ベストプラクティス

1. **冗長化された NTP 構成:** 最低 2 台以上の信頼できる NTP サーバー（Stratum 1 または 2）を指定し、1 台に `prefer` オプションを付与する。
2. **Access-Group によるセキュリティ固定:** 不当なデバイスからの NTP 同期要求や NTP リフレクション攻撃（DoS）を防ぐため、`ntp access-group` で厳格に制御する。
3. **PTP Boundary Clock (BC) の採用:** スケールする PTP 網では、Grandmaster Clock の負荷削減とパケット追従性向上のため、Catalyst 9000 シリーズで Boundary Clock (BC) モードを採用する。
4. **PTP 専用 QoS パイプライン:** PTP トラフィック（UDP 319/320）に対して `DSCP CS6` をマークし、全対向ポートで優先キューイングを行う。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: NTP Client (MD5 認証 ＋ Prefer ＋ Source 指定) 構成
* **問題:** R1 を NTP クライアントとして構成し、NTP サーバー `192.168.100.1` (優先) および `192.168.100.2` と同期させてください。
* **要件:**
  - キー ID `10`、パスワード `NtpKey#2026` による MD5 認証を使用すること。
  - 送信元 IP アドレスは `Loopback0` に固定すること。
* **設定例:**
```bash
! R1 Configuration
ntp authentication-key 10 md5 NtpKey#2026 7
ntp trusted-key 10
ntp authenticate
ntp source Loopback0
ntp server 192.168.100.1 key 10 prefer
ntp server 192.168.100.2 key 10
```
* **検証方法:**
```bash
R1# show ntp status
R1# show ntp associations
```

### ラボ 2: VRF-Aware NTP Client 構成
* **問題:** R2 は管理用 VRF `Mgmt-vrf` 経由で NTP サーバー `10.255.255.50` と時刻同期する必要があります。
* **要件:**
  - VRF `Mgmt-vrf` を正しく指定して NTP サーバーを設定すること。
  - 送信元として `GigabitEthernet0/0` (Mgmt-vrf に属する) を使用すること。
* **設定例:**
```bash
! R2 Configuration
ntp source GigabitEthernet0/0
ntp server vrf Mgmt-vrf 10.255.255.50
```
* **検証方法:**
```bash
R2# show ntp status
R2# show ntp associations
```

### ラボ 3: NTP Access-Group によるセキュリティ制限構成
* **問題:** SW1 で NTP サーバー `172.16.1.1` からの時刻同期のみを許可し、他のデバイスからの同期試行や制御クエリを遮断してください。
* **要件:**
  - `ntp access-group peer` を使用すること。
  - ACL `ACL_NTP_PEER` で許可IPを厳格化すること。
* **設定例:**
```bash
! SW1 Configuration
ip access-list extended ACL_NTP_PEER
 permit ip host 172.16.1.1 any

ntp access-group peer ACL_NTP_PEER
ntp server 172.16.1.1
```
* **検証方法:**
```bash
SW1# show ntp access-groups
SW1# show ntp status
```

### ラボ 4: PTP Boundary Clock (BC) L3 UDP 構成
* **問題:** Catalyst 9300 (SW2) 上で PTP Boundary Clock を有効化してください。
* **要件:**
  - PTP ドメイン番号は `0` とする。
  - トランスポートプロトコルは IPv4 UDP とする。
  - Gi1/0/1 ポートで PTP を有効化すること。
* **設定例:**
```bash
! SW2 Configuration
ptp mode boundary
ptp domain 0
ptp transport ipv4 udp

interface GigabitEthernet1/0/1
 description === PTP Trunk to Grandmaster ===
 ptp enable
```
* **検証方法:**
```bash
SW2# show ptp clock
SW2# show ptp port
```

### ラボ 5: PTP Master Port 明示指定 ＆ Priority 制御構成
* **問題:** SW3 で PTP ポート Gi1/0/2 を明示的に Master ロールとして動作させてください。
* **要件:**
  - PTP ポートロールを `master` に固定すること。
  - PTP 優先度 `priority1` を `100` に調整すること。
* **設定例:**
```bash
! SW3 Configuration
ptp mode boundary
ptp priority1 100

interface GigabitEthernet1/0/2
 description === Downlink to Slave Device ===
 ptp enable
 ptp role master
```
* **検証方法:**
```bash
SW3# show ptp port
SW3# show ptp clock
```

### ラボ 6: PTP 優先度保護のための MQC QoS 構成
* **問題:** PTP パケット (UDP ポート 319/320) に最優先 QoS 処理を適用してください。
* **要件:**
  - MQC を使用して PTP パケットを `DSCP CS6` にマークすること。
  - Egress ポートで Strict Priority Queue (LLQ) を適用すること。
* **設定例:**
```bash
! Class-Map ＆ Policy-Map の定義
ip access-list extended ACL_PTP
 permit udp any any eq 319
 permit udp any any eq 320

class-map match-any CM_PTP
 match access-group name ACL_PTP

policy-map PM_PTP_MARK
 class CM_PTP
  set dscp cs6

policy-map PM_PTP_EGRESS
 class CM_PTP
  priority level 1

interface GigabitEthernet1/0/1
 service-policy input PM_PTP_MARK
 service-policy output PM_PTP_EGRESS
```
* **検証方法:**
```bash
SW3# show policy-map interface GigabitEthernet1/0/1
```

### ラボ 7: NTP Master 保持構成 (孤立ネットワーク用)
* **問題:** 上位 NTP サーバーに接続できない孤立網のコアノード R3 を NTP マスターとして動作させてください。
* **要件:**
  - Stratum 値は `3` とすること。
  - ローカルクロックを維持すること。
* **設定例:**
```bash
! R3 Configuration
ntp master 3
```
* **検証方法:**
```bash
R3# show ntp status
```

### ラボ 8: NTP ＋ CoPP (Control Plane Policing) 統合保護構成
* **問題:** Control Plane Policing (CoPP) を適用している R4 で、正規の NTP トラフィックがドロップされないよう保護してください。
* **要件:**
  - NTP (UDP 123) を CoPP ACL で許可すること。
  - CoPP ポリサー配下で正常転送されること。
* **設定例:**
```bash
ip access-list extended ACL_COPP_NTP
 permit udp host 10.1.1.100 any eq ntp
 permit udp any eq ntp any

class-map match-any CM_COPP_NTP
 match access-group name ACL_COPP_NTP

policy-map PM_COPP
 class CM_COPP_NTP
  police 32000 conform-action transmit exceed-action transmit
```
* **検証方法:**
```bash
R4# show policy-map control-plane
```

### ラボ 9: NTP ピア (Symmetric Active) 相互同期構成
* **問題:** R5 と R6 間で NTP ピア関係（対等同期）を確立してください。
* **要件:**
  - `ntp peer` コマンドを使用すること。
  - ソースは `Loopback0` とすること。
* **設定例:**
```bash
! R5 Configuration
ntp source Loopback0
ntp peer 10.0.0.6

! R6 Configuration
ntp source Loopback0
ntp peer 10.0.0.5
```
* **検証方法:**
```bash
R5# show ntp associations
```

### ラボ 10: PTP L2 Ethernet トランスポート ＋ VLAN タグ構成
* **問題:** 産業用 Catalyst 9000 スイッチで L2 Ethernet 直接カプセル化による PTP を構成してください。
* **要件:**
  - `ptp transport layer2` を使用すること。
  - 特定 VLAN `200` 上で有効化すること。
* **設定例:**
```bash
! Switch Configuration
ptp mode boundary
ptp domain 0
ptp transport layer2

interface GigabitEthernet1/0/5
 switchport mode trunk
 ptp enable
 ptp vlan 200
```
* **検証方法:**
```bash
Switch# show ptp port
```

---

## ❓ 想定試験問題

### 問 1 (トラブルシューティング)
**問題:** R1 で `ntp server 192.168.1.1 key 1` を設定したが、`show ntp status` で `unsynchronized` のまま変化しない。`show ntp associations detail` を確認したところ `authenticated, invalid key` と表示されている。考えられる原因と修正コンフィグを選びなさい。

A. `ntp authenticate` コマンドが設定されていないため。
B. `ntp trusted-key 1` コマンドの設定が欠落しているため。
C. `ntp server` 設定に `prefer` が付与されていないため。
D. `ntp source` インターフェイスが DOWN しているため。

**正解:** **B**
**解説:** NTP 認証を正常に機能させるには、① `ntp authentication-key` の定義、② `ntp trusted-key` による該当キー ID の信頼有効化、③ `ntp authenticate` のグローバル有効化の 3 点が必要。`invalid key` と表示される場合は `trusted-key` の設定漏れが典型的。

---

### 問 2 (Design)
**問題:** 100 台のアクセススイッチで構成されるエンタープライズ LAN 環境において、PTP (IEEE 1588v2) を導入する際、Grandmaster Clock (GMC) への直接クエリ集中（スケール問題）を回避するための最適設計はどれか。

A. 全アクセススイッチを PTP Ordinary Clock (OC) として GMC に直接メッシュ接続する。
B. Distribution スイッチ群を PTP Boundary Clock (BC) として構成し、GMC からの時刻を再生成して Access スイッチへ配布する。
C. 全スイッチで PTP を無効化し、NTPv4 に切り替える。
D. Access スイッチを PTP Transparent Clock (TC) のみに設定し、GMC パケットをそのままスルーさせる。

**正解:** **B**
**解説:** Boundary Clock (BC) は上流から時刻を受信（Slave ポート）し、自らクロックを維持しながら下流へ Master ポートとして時刻を再配布するため、GMC の負荷を大幅に削減しスケーラビリティを向上させる。

---

### 問 3 (コンフィグ読解)
**問題:** 以下のコンフィグが適用されたルータの動作として正しいものを選択しなさい。

```bash
ip access-list extended ACL_NTP
 permit ip host 10.10.10.1 any

ntp access-group serve-only ACL_NTP
```

A. `10.10.10.1` からの NTP 時刻同期を受け入れ、自身を `10.10.10.1` に同期させる。
B. `10.10.10.1` に対してのみ自身の時刻情報（NTP レスポンス）を提供し、`10.10.10.1` からの同期要求や制御クエリは一切受け入れない。
C. `10.10.10.1` からの NTP 制御クエリ（`ntpq` 等）のみを許可する。
D. 全すべてのデバイスからの NTP 時刻リクエストを許可する。

**正解:** **B**
**解説:** `ntp access-group serve-only` は、指定された ACL アドレスに対してタイムサーバーとしての応答（時刻提供）のみを許可し、相手からの時刻同期や制御クエリはブロックする。

---

### 問 4 (トラブルシューティング)
**問題:** VRF `WAN_VPN` に属するインターフェイス経由で外部 NTP サーバー `172.16.20.5` と同期させたいが、パケットが送信されない。現在 `ntp server 172.16.20.5` のみ設定されている。追加すべき正しいコマンドはどれか。

A. `ntp server vrf WAN_VPN 172.16.20.5`
B. `ntp vrf WAN_VPN enable`
C. `ip ntp vrf WAN_VPN`
D. `ntp source WAN_VPN`

**正解:** **A**
**解説:** IOS XE において VRF 経由で NTP サーバーにアクセスする場合、`ntp server vrf <VRF_NAME> <IP>` の形式で明示的に VRF を指定する必要がある。

---

### 問 5 (実装)
**問題:** Catalyst 9300 スイッチにおいて、PTP ポート Gi1/0/10 を明示的に Master ロール（下流機器への時刻配布専用）として固定設定するための適切なインターフェイスコマンドはどれか。

A. `ptp master enable`
B. `ptp role master`
C. `ptp mode master`
D. `ptp clock master`

**正解:** **B**
**解説:** Catalyst 9000 シリーズの PTP インターフェイス設定において、ポートロールを Master に固定するには `ptp role master` コマンドを使用する。

---

## 🔗 参考リソース

* Cisco IOS XE 17.x Network Management Configuration Guide - Synchronizing Network Time (NTP)
* Cisco Catalyst 9300 Series Switches Precision Time Protocol (PTP) Configuration Guide
* Cisco Technical Notes - Troubleshooting NTP Synchronization Issues in IOS XE

---

## 📝 補足（Notes）

* **NTP Stratum 16:** 未同期状態（Unsynchronized）を意味し、この状態のデバイスは他機器へ時刻を提供できない。
* **BMCA (Best Master Clock Algorithm):** PTP において、どのクロックが Grandmaster (GMC) になるかを自動決定する分散アルゴリズム。
* **PTP 2-Step Clock:** Sync メッセージ送信時に精密な送信タイムスタンプ T1 をパケット内に埋め込めない場合、後続の `Follow_Up` メッセージで T1 を送出する方式。


## 📘 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKCRS-2031: Network Time Protocol (NTP) Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031) - NTP の詳細な仕組みと攻撃対策。
*   [**BRKARC-2011: Precision Time Protocol (PTP) in Enterprise Networks**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-2011) - PTP の設計と実装ガイド。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Network Time Protocol Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/bsm/configuration/xe-17/bsm-xe-17-book.html)。
*   [**Configuring Precision Time Protocol (PTP)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sys_mgmt/b_179_sys_mgmt_9300_cg/m_ptp.html)。

### テクニカルドキュメント・設定例
*   [**NTP Best Practices White Paper**](https://www.cisco.com/c/en/us/support/docs/availability/high-availability/19643-ntp.html) - 階層設計とセキュリティの推奨事項。
*   [**Troubleshooting NTP Sync Issues (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/13506-snmpv3.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験において正確な時刻同期がいかに基盤技術として重要であるかを網羅しています。特に **NTP 認証** と **アクセスグループによる制限** は、セキュリティセクションと組み合わせて出題される可能性が高いため、確実にマスターしてください。


