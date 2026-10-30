---
layout: default
title: 4.6.a-IP-SLA
parent: 4.6-Network-optimization
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.6.a IP SLA (ICMP, UDP, TCP probes)

---

## 📘 概要

IP SLA（Cisco In-Service/IP Service Level Agreements）は、Cisco IOS / IOS XE デバイス上で合成トラフィック（Synthetic Traffic / Probes）を動的に生成・送信し、ネットワークのパフォーマンス（リアルタイム遅延、往復時間 [RTT]、ジッター [Jitter]、パケットドロップ率、音声品質指標 [MOS / ICPIF]、サーバー応答時間）を定量的かつリアルタイムに計測・可視化・アクティブ監視するシスコ独自の可視化・可用性保証テクノロジーである。

### 主な利用目的
1. **パスアクティブ監視と可用性検知**: WAN 回線やインターネット出口、ネクストホップルータの生死・疎通状態をリアルタイムにポッド/監視し、障害発生時にミリ秒〜秒単位で検知する。
2. **ルーティング・HSRP/VRRP 自動切替**: Object Tracking（`track` 機能）と連携し、IP SLA の計測結果（`reachability` や `state`）をトリガーにして Static Route の有効化/無効化、HSRP/VRRP の Priority 減算、PBR（Policy-Based Routing）の転送先変更を実行する。
3. **QoS / VoIP 品質評価**: `udp-jitter` や `voip` プローブを使用して、音声・ビデオトラフィックの遅延バリエーション（Jitter）や片道遅延、パケットロスを継続計測し、SLA 違反時にアラートを発出する。
4. **L7 アプリケーションサービス疎通確認**: 単なる ICMP (L3) や TCP SYN (L4) 疎通にとどまらず、HTTP GET, DNS クエリ, FTP ダウンロードなどの L7 セッションを模擬し、Web サーバーやインフラサービスの応答時間を測定する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | シスコ独自の動的プローブ計測技術。ICMP, UDP, TCP, L7 プロトコルに対応し、高精度な時系列パフォーマンス測定と Object Tracking 連携を実現 |
| **用途** | 障害検知、自動経路切替 (Static Route/PBR/HSRP)、VoIP 品質評価 (Jitter/MOS)、L7 サービス応答時間可視化 |
| **メリット** | 専用計測アプライアンスが不要。Object Tracking や EEM と組み合わせることで自律的なネットワーク自動復旧（Self-Healing）が可能 |
| **デメリット** | 大量のプローブ設定や短い送信周期（1秒以下）は CPU リソースを消費。Responder 非対応プローブでは片道遅延の正確な計測が不可 |
| **対応機種** | Catalyst 8000, ISR, ASR, Catalyst 9000 シリーズ全般 (Cisco IOS / IOS XE 準拠) |
| **制限事項** | UDP Jitter や VOIP 計測には対向デバイスでの `ip sla responder` が必須。時刻同期（NTP）が不完全な場合、片道遅延測定値が歪む |
| **設計上の注意点** | プローブの Flapping によるルーティングのバタつきを防ぐため、`delay down / up` や Reaction Threshold（しきい値）の適切なチューニングが不可欠 |

---

## 🏗 動作原理

IP SLA は「**Sender（Sender Device）**」と「**Responder（Responder Device）**」の 2 つの役割、または Sender 単体による計測で動作する。

```
[ Sender (IP SLA Master) ]  <--- Control Message (UDP 1981) --->  [ Responder (IP SLA Target) ]
    |                                (認証・ポート折衝)                       |
    |                                                                        |
    +================== Probe Traffic (UDP / ICMP / TCP) ====================+
                            (T1, T2, T3, T4 タイムスタンプ打刻)
```

### 1. Responder と Control Protocol (UDP ポート 1981)
* **Control Connection**: Sender が `udp-jitter` や `udp-echo` などのプローブを開始する際、まず対向の Responder 宛てに **UDP 1981** ポートを使用してコントロールメッセージ（MD5 認証オプション含む）を送信する。
* **Dynamic Port Negotiation**: Responder はコントロールメッセージを受領すると、測定用データパケットを受信するための動的 UDP ポートを開放し、Port 番号を Sender へ返答する。
* **Processing Delay Elimination**: Responder は受信時（\(T_2\)）および送信時（\(T_3\)）にハッシュ/タイムスタンプを打刻する。これにより、Responder 内部の CPU 処理遅延（\(T_3 - T_2\)）を全体 RTT から差し引くことができ、純粋なネットワーク伝送遅延のみを測定可能にする。

### 2. T1〜T4 タイムスタンプ処理（UDP Jitter の例）
```
Sender (Sender Time)                            Responder (Target Time)
  |                                                    |
  |--- (T1: 送信タイムスタンプ) -------------------------->| (T2: 受信タイムスタンプ)
  |                                                    |   [処理遅延: T3 - T2]
  |<------------------------- (T4: 送信タイムスタンプ) ---| (T3: 送信タイムスタンプ)
  | (T4: 受信タイムスタンプ)                            |
```
* **往復遅延 (Round Trip Time: RTT)** = \((T_4 - T_1) - (T_3 - T_2)\)
* **送信方向遅延 (Source-to-Destination Delay)** = \(T_2 - T_1\) （※高精度同期された NTP が前提）
* **受信方向遅延 (Destination-to-Source Delay)** = \(T_4 - T_3\) （※高精度同期された NTP が前提）
* **Jitter (SD / DS)** = 連続するパケット間における送信方向・受信方向遅延の差分絶対値

---

## ⚙ 動作シーケンス

```
[IP SLA Sender]                                        [IP SLA Responder / Server]
      |                                                            |
      |--- 1. UDP 1981 Control Packet (Port/MD5 Req) ------------->|
      |<-- 2. Control Response (Port Allocation OK) ---------------|
      |                                                            |
      |--- 3. Probe Packet #1 (T1 打刻) --------------------------->| (T2 打刻)
      |<-- 4. Probe Response #1 (T3/T2 打刻データ付与) -------------| (T3 打刻, T4 受信)
      |                                                            |
      |--- 5. 測定完了 ➔ RTT / Jitter / Loss 算出 ----------------->|
      |                                                            |
      |--- 6. Object Tracking 状態更新 (Up / Down) --------------->|
      |                                                            |
      |--- 7. Control Plane Action (Static Route/HSRP 切替) ------>|
```

1. **IP SLA 起動と制御パケット送出**: スケジュール（`ip sla schedule`）に従い、Sender はプローブ処理を開始する。Responder 必須プロトコルの場合、UDP 1981 にて初期ハンドシェイクを行う。
2. **計測パケットの連続送信**: 設定された `frequency`（間隔）および `interval`（パケット間隔）に従い、データパケット群を送出。
3. **データ集計と評価**: 送受信のタイムスタンプ差分から、RTT、Jitter、Loss 率、Status (OK / Timeout / OverThreshold) を確定。
4. **Object Tracking への評価通知**: `track` オブジェクトが IP SLA 状態（`reachability` または `state`）をポーリングまたはプッシュ検知。
5. **コントロールプレーン連動**: Routing Table (Static Route) の削除/追加、HSRP Priority の引下げ、PBR ネクストホップの判定がミリ秒〜秒レベルで即時反映される。


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI ラボ試験における IP SLA は、単独での設定問題として出題されることは少なく、**「Static Route / PBR / HSRP / VRRP と組み合わせた高可用性・動的パス切替（Path Redundancy）のトリガー」** として設定・トラブルシューティングさせられるケースが 90% 以上を占める。

### 1. ラボ試験で頻出の要件と設定ポイント
* **ICMP Echo Probe + Static Route Track**:
  対向 ISP や WAN Gateway への ICMP Echo 監視。ICMP 応答が途絶えた場合に、デフォルトルートや特定プレフィックスの Static Route を自動削除してバックアップ経路へ迂回させる。
  ```bash
  ip sla 10
   icmp-echo 192.168.12.2 source-interface Loopback0
   frequency 5
  ip sla schedule 10 life forever start-time now
  !
  track 10 ip sla 10 reachability
   delay down 10 up 5
  !
  ip route 0.0.0.0 0.0.0.0 192.168.12.2 track 10
  ip route 0.0.0.0 0.0.0.0 192.168.23.3 200
  ```
* **UDP Jitter Probe + HSRP Priority Decrement**:
  WAN 回線の遅延・品質低下（Jitter 超過）を検知し、HSRP の Active ルータから Standby ルータへ Master 権限を自動譲渡させる。
  ```bash
  ip sla 20
   udp-jitter 10.1.1.2 16384 source-ip 10.1.1.1 num-packets 100
   frequency 10
  ip sla schedule 20 life forever start-time now
  !
  track 20 ip sla 20 state
  !
  interface GigabitEthernet0/0/1
   standby 1 ip 192.168.1.254
   standby 1 priority 110
   standby 1 preempt delay minimum 30
   standby 1 track 20 decrement 20
  ```
* **TCP Connect / HTTP Probe + PBR (Policy-Based Routing)**:
  特定 Web サーバーへの TCP 接続（Port 80/443）または HTTP GET を監視し、Web 通信のみをプライマリ Web プロキシ経由からダイレクトインターネット接続（DIA）へ PBR で切り替える。

### 2. 試験で狙われやすい罠・よくある設定ミス
1. **`ip sla schedule` 設定の失念**:
   `ip sla` セクションでプローブをどれだけ詳細に定義しても、`ip sla schedule <id> life forever start-time now` を投入しない限り、プローブは**永遠に始動せず**（`State: Pending`）、Track オブジェクトは Down のまま固着する。
2. **`reachability` vs `state` の選択誤り**:
   * `icmp-echo` 等の単純な OK/NG 判定プローブ ➔ `track <id> ip sla <id> reachability`
   * `udp-jitter` や Reaction Threshold（しきい値）を設定した高度なプローブ ➔ `track <id> ip sla <id> state`
   選択を誤ると、Jitter や遅延が閾値を超過しても Track 状態が変移しないトラブルが発生する。
3. **VRF 環境での Source / VRF 指定漏れ**:
   VRF-Lite や SD-WAN Underlay/Overlay 環境において、`vrf <VRF_NAME>` の指定を忘れると、Global Routing Table からプローブが送信され、対向に届かず即座に Timeout となる。
4. **`delay down / up` タイマー未設定による Flapping**:
   回線の状態が不安定な場合、IP SLA が秒単位で UP/DOWN を繰り返し、BGP/OSPF 再計算や Static Route の追加・削除が頻発してネットワーク全体のフラッピングを引き起こす。

---

## 🛠 設定方法

### 1. 基本的な ICMP Echo プローブ ＋ Track 設定
```bash
! 1. IP SLA プローブの定義
ip sla 100
 icmp-echo 203.0.113.1 source-interface GigabitEthernet0/0/0
 timeout 2000
 threshold 2000
 frequency 5
!
! 2. IP SLA スケジューリングの開始
ip sla schedule 100 life forever start-time now
!
! 3. Object Tracking の定義と Flap 防止タイマーの設定
track 100 ip sla 100 reachability
 delay down 10 up 5
!
! 4. Static Route へのバインド
ip route 0.0.0.0 0.0.0.0 203.0.113.1 track 100
ip route 0.0.0.0 0.0.0.0 198.51.100.1 200
```

### 2. UDP Jitter プローブ（Responder ＋ MD5 認証）設定
```bash
! === Responder 側設定 (Target Router) ===
ip sla responder
ip sla responder authentication key-chain SLA_KEY

key chain SLA_KEY
 key 1
  key-string CiscoCCIEPass!

! === Sender 側設定 (Monitoring Router) ===
key chain SLA_KEY
 key 1
  key-string CiscoCCIEPass!

ip sla 200
 udp-jitter 192.168.20.2 16384 source-ip 192.168.10.1 num-packets 100 interval 10
 key-chain SLA_KEY
 timeout 3000
 threshold 1000
 frequency 15
ip sla schedule 200 life forever start-time now

track 200 ip sla 200 state
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 動作説明 |
| :--- | :--- | :--- |
| **SLA 全体状態確認** | `show ip sla summary` | 設定済みの全 IP SLA ID、Operational Status、RTT、前回計測結果の一覧を表示 |
| **詳細統計確認** | `show ip sla statistics [id]` | 特定プローブの Success/Failure 回数、直近の RTT、Jitter (SD/DS)、Loss パケット数を表示 |
| **設定内容確認** | `show ip sla configuration [id]` | Target IP、Port、Type、Frequency、Timeout、Schedule 状態の詳細定義を表示 |
| **Responder 状態** | `show ip sla responder` | デバイス上で IP SLA Responder が有効化されているか、アクティブな制御接続を表示 |
| **Track 状態確認** | `show track [id]` | Track オブジェクトの現在の Status (UP/DOWN)、Change Count、延期タイマー残時間を表示 |
| **リアルタイム Debug** | `debug ip sla trace` | IP SLA プローブパケットの送受信ログをリアルタイムで追跡 |
| **制御パケット Debug** | `debug ip sla error` | IP SLA の設定エラーや Responder ハンドシェイク失敗ログを出力 |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **SLA 状態が `Pending` のまま動かない** | `ip sla schedule` が実行されていない | <code>show ip sla configuration</code> | <code>ip sla schedule &lt;id&gt; life forever start-time now</code> を投入する |
| **SLA 統計で `Timeout` / `No Connection` になる** | ① 宛先 IP 不可達<br>② Responder 未有効化（UDP Jitter の場合）<br>③ FW で UDP 1981 が遮断 | <code>show ip sla statistics</code><br><code>ping &lt;target-ip&gt;</code> | ① 宛先ルーティング確認<br>② 対向で <code>ip sla responder</code> 投入<br>③ FW で UDP 1981/データポートを許可 |
| **Track 状態が常時 DOWN（SLA は RTT 正常）** | `reachability` と `state` の選択ミス | <code>show track</code><br><code>show ip sla statistics</code> | Jitter や Threshold 計測の場合、<code>track &lt;id&gt; ip sla &lt;id&gt; state</code> に変更 |
| **UDP Jitter で認証エラーになる** | Sender / Responder 間の Key-chain / Key-string 不一致 | <code>debug ip sla error</code> | 双方の `key chain` 名、Key ID、`key-string` を一致させる |
| **VRF 配下で SLA が Timeout になる** | SLA 定義内で `vrf` 指定が欠落している | <code>show ip sla configuration</code> | プローブ定義内に <code>vrf &lt;VRF_NAME&gt;</code> または <code>option vrf &lt;VRF_NAME&gt;</code> を追加 |

---

## ⚠ 制限事項

1. **CPU リソース消費制限**:
   アグレッシブな Frequency（1秒以下）や大容量の Jitter パケット群（`num-packets 1000` 等）を多数定義すると、ルータの CPU 使用率が急増し、コントロールプレーンに悪影響を及ぼす。
2. **Responder 必須プローブ**:
   `udp-jitter`, `voip`, `tcp-connect` (一部制御) は対向デバイスに Cisco IOS / IOS XE (Responder 機能) を要求する。他社製ルータや一般 Linux サーバー相手には `icmp-echo`, `tcp-connect`, `http` を使用する必要がある。
3. **NTP 同期精度**:
   片道遅延（Source-to-Destination / Destination-to-Source）を測定する場合、Sender と Responder 双方でミリ秒単位の NTP 時刻同期が必須である。同期していない場合、片道遅延が負の数（Negative Value）になるなどの異常値を示す。

---

## 🔄 他技術との関連

* **Static Routing (`ip route ... track <id>`)**:
  IP SLA の最も代表的な適用例。主要回線障害時にデフォルトルートを削除し、バックアップ Static Route や IGP / BGP 経路へ即座に迂回させる。
* **HSRP / VRRP (`standby track <id> decrement <value>`)**:
  上流 WAN 回線の IP SLA 障害を検知し、HSRP Active ルータの Priority を引き下げることで、対向ルータへ Seamless に Active 権限を移譲する。
* **Policy-Based Routing (PBR - `set ip next-hop verify-availability`)**:
  PBR のネクストホップ宛てに IP SLA / Track をバインドし、特定アプリケーション（Web, DB 等）の転送先が正常な場合のみ PBR を適用し、障害時は通常の IGP/FIB ルーティングへ落とし込む（Fallback）。
* **Embedded Event Manager (EEM - `event track <id> state down`)**:
  IP SLA の Down を検知して、ポートの shutdown/no shutdown、BGP Peer のクリア、QoS ポリシーの自動変更、カスタム Log の生成などをスクリプト制御する。
* **Control Plane Policing (CoPP)**:
  IP SLA コントロール通信（UDP 1981）や UDP Jitter データ通信が CoPP により誤って Drop されないよう、CoPP ACL 内で明示的に許可する設計が必要。

---

## 🧩 比較表

| プローブタイプ | 対象レイヤー | Responder | 主な測定項目 | 主な用途 |
| :--- | :---: | :---: | :--- | :--- |
| **`icmp-echo`** | L3 (ICMP) | **不要** | RTT, Loss | WAN / Internet 疎通確認, Static Route 切替 |
| **`udp-jitter`** | L4 (UDP) | **必須** | RTT, Jitter (SD/DS), Loss (SD/DS), 片道遅延 | VoIP / Video 品質測定, HSRP 自動切替 |
| **`udp-echo`** | L4 (UDP) | **必須** | RTT | UDP レベルでのポート応答性・帯域遅延測定 |
| **`tcp-connect`** | L4 (TCP) | オプション | TCP 3-way ハンドシェイク時間 | Web / DB / App サーバーの L4 応答性確認 |
| **`http`** | L7 (HTTP) | **不要** (Web Server) | HTTP GET 応答時間, DNS 解決時間, ページ取得時間 | Web アプリケーション SLA 監視, PBR 迂回 |

---

## 💡 ベストプラクティス

1. **Flap Suppression（遅延タイマー）の必ずの付与**:
   IP SLA をルーティングや HSRP に連動させる場合、`track` オブジェクトには必ず `delay down <sec> up <sec>` を設定する。一般的に `delay down 5 up 10` や `delay down 10 up 30` を設定し、回線の過渡的なパケットロスによる誤切替を防ぐ。
2. **Frequency と Timeout の整合性**:
   `timeout` 値は `frequency` 値よりも小さく設定しなければならない（例: `frequency 5`, `timeout 2000` [2秒]）。`timeout` が `frequency` を超えると、前のプローブ結果が確定する前に次のプローブが開始され、測定値が破壊される。
3. **Source-Interface / Source-IP の明示**:
   マルチホーム構成では、プローブの送信元 IP / インターフェイスを明示指定（`source-interface Loopback0` 等）する。指定しない場合、アウトバウンドインターフェイスの Primary IP が自動使用され、経路変更時に送信元 IP がブレて測定が不安定になる。


## 📝 ラボ学習・設定サンプル例

---

### ラボ 1: ICMP Echo Probe ＋ Static Route Tracking (基本フェイルオーバー)

#### 問題
R1 から外へのデフォルトルートとして、Primary ISP（192.168.12.2）と Secondary ISP（192.168.13.3）が存在する。Primary ISP 宛ての ICMP 応答が途絶えた場合、動的に Primary デフォルトルートを削除し、Secondary デフォルトルートへ迂回させよ。

#### 要件
1. R1 上で IP SLA 10 を作成し、Primary ISP（192.168.12.2）宛てに 5 秒おきに ICMP Echo パケットを送信すること。
2. タイムアウトは 2000ms とすること。
3. IP SLA 10 のスケジューリングを即時かつ無期限で開始すること。
4. Object Track 10 を作成し、IP SLA 10 の `reachability` を監視すること。
5. 回線のバタつきを防止するため、Down 検知遅延 10 秒、Up 復旧遅延 5 秒のタイマーを設定すること。
6. Static Route を設定し、Track 10 が UP の間は Primary（192.168.12.2、AD 1）を使用し、DOWN 時は Secondary（192.168.13.3、AD 200）へ迂回させること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 10
 icmp-echo 192.168.12.2 source-interface GigabitEthernet0/0/1
 timeout 2000
 threshold 2000
 frequency 5
ip sla schedule 10 life forever start-time now

track 10 ip sla 10 reachability
 delay down 10 up 5

ip route 0.0.0.0 0.0.0.0 192.168.12.2 track 10
ip route 0.0.0.0 0.0.0.0 192.168.13.3 200
```

#### 検証方法
1. `show ip sla summary` および `show ip sla statistics 10` を実行し、`Operational Status: Normal` および Success カウントが増加していることを確認。
2. `show track 10` を実行し、`State is Up` であることを確認。
3. `show ip route 0.0.0.0` を実行し、192.168.12.2 への経路が FIB に載っていることを確認。
4. Primary インターフェイス（Gi0/0/1）を shutdown、または対向で ICMP をドロップし、10秒後に Track 10 が DOWN に遷移し、ルーティングテーブルが 192.168.13.3 へ自動切り替わることを確認。

---

### ラボ 2: UDP Jitter Probe ＋ IP SLA Responder ＋ HSRP Priority Decrement

#### 問題
R1 (Active) と R2 (Standby) で HSRP v2 グループ 1 を構成している。R1 の WAN 側回線の品質（Jitter）が悪化した場合に、HSRP の Active 権限を R2 へ自動移譲させよ。

#### 要件
1. 対向 WAN ルータ (R3: 10.1.3.3) 上で `ip sla responder` を有効化すること。
2. R1 上で IP SLA 20 を作成し、R3 (10.1.3.3) 宛てに UDP Jitter プローブを構成すること。送信元 IP は R1 Loopback0 (10.1.1.1)、宛先 UDP ポートは 16384、パケット数は 100、送信間隔は 10 秒とすること。
3. R1 上で Object Track 20 を作成し、IP SLA 20 の `state` を監視すること。
4. R1 の Gi0/0/0 上で HSRP v2 グループ 1（仮想 IP: 192.168.1.254、基本 Priority: 110）を設定し、Preempt（Delay 30 秒）を有効化すること。
5. Track 20 が DOWN に遷移した場合、HSRP Priority を 20 引き下げる設定（`decrement 20`）を入れること。

#### 設定例
```bash
! === R3 (Target/Responder) Configuration ===
ip sla responder

! === R1 (Sender) Configuration ===
ip sla 20
 udp-jitter 10.1.3.3 16384 source-ip 10.1.1.1 num-packets 100 interval 10
 timeout 3000
 threshold 1000
 frequency 10
ip sla schedule 20 life forever start-time now

track 20 ip sla 20 state

interface GigabitEthernet0/0/0
 ip address 192.168.1.1 255.255.255.0
 standby version 2
 standby 1 ip 192.168.1.254
 standby 1 priority 110
 standby 1 preempt delay minimum 30
 standby 1 track 20 decrement 20
```

#### 検証方法
1. R3 上で `show ip sla responder` を実行し、Responder が Active で接続を受信可能であることを確認。
2. R1 上で `show standby` を実行し、Priority 110 で Active 状態であることを確認。
3. WAN 側回線で人工的にパケット遅延/Jitter を発生させるか、R3 の Responder を無効化 (`no ip sla responder`) して IP SLA 20 を Failure させる。
4. R1 の `show track 20` が Down に変化し、`show standby` にて Active Priority が 90 (110 - 20) に下降し、R2 (Priority 100) が HSRP Active へ昇格することを確認。

---

### ラボ 3: TCP Connect Probe (Port 80/443) ＋ PBR (`verify-availability`) 連携

#### 問題
社内 LAN から外への Web トラフィック（TCP 80/443）について、通常は高速プロキシサーバー (172.16.10.100) 経由で PBR 転送する。プロキシサーバーの Web サービス（Port 80）がダウンした場合は、PBR を自動無効化して通常のデフォルトルーティングへフォールバックさせよ。

#### 要件
1. R1 上で IP SLA 30 を作成し、プロキシサーバー（172.16.10.100）の TCP ポート 80 宛てに TCP Connect プローブを設定すること。
2. 5 秒間隔でチェックし、タイムアウトは 2000ms とすること。
3. Object Track 30 を作成し、IP SLA 30 の `state` を監視すること。
4. PBR Route-Map `PBR_WEB` を作成し、HTTP/HTTPS トラフィックに対して `set ip next-hop verify-availability 172.16.10.100 1 track 30` を適用すること。
5. LAN インターフェイス（Gi0/0/2）に Route-Map をアタッチすること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 30
 tcp-connect 172.16.10.100 80 source-ip 172.16.10.1
 timeout 2000
 threshold 2000
 frequency 5
ip sla schedule 30 life forever start-time now

track 30 ip sla 30 state

ip access-list extended ACL_WEB_TRAFFIC
 permit tcp 192.168.0.0 0.0.255.255 any eq www
 permit tcp 192.168.0.0 0.0.255.255 any eq 443

route-map PBR_WEB permit 10
 match ip address ACL_WEB_TRAFFIC
 set ip next-hop verify-availability 172.16.10.100 1 track 30

interface GigabitEthernet0/0/2
 ip policy route-map PBR_WEB
```

#### 検証方法
1. プロキシサーバーの TCP 80 ポートが LISTEN 状態の時、`show ip sla statistics 30` が `Return code: OK` になることを確認。
2. `show route-map` を実行し、`Policy routing matches` カウンタが増加し、ネクストホップ 172.16.10.100 が Active 状態であることを確認。
3. プロキシの Web サービスを停止する。Track 30 が DOWN に遷移し、`show route-map` にて `verify-availability` によりネクストホップが無効化され、トラフィックが標準 FIB ルーティング（デフォルトルート）へ自動迂回することを確認。

---

### ラボ 4: VRF-Aware IP SLA Probe (複数テナント網での宛先監視)

#### 問題
R1 は VRF `RED` および VRF `BLUE` を収容している。各 VRF ドメイン内の特定監視対象 IP（RED: 10.100.1.1, BLUE: 10.200.1.1）に対して独立して ICMP SLA を実行し、それぞれの VRF ルーティングテーブルに紐づく Static Route を個別削除させよ。

#### 要件
1. IP SLA 101 を VRF `RED` 内の 10.100.1.1 宛てに設定すること。
2. IP SLA 102 を VRF `BLUE` 内の 10.200.1.1 宛てに設定すること。
3. それぞれ 5 秒間隔で監視し、即時スケジューリングすること。
4. Track 101 および Track 102 を作成し、対応する VRF Static Route にバインドすること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 101
 icmp-echo 10.100.1.1 vrf RED
 frequency 5
ip sla schedule 101 life forever start-time now

track 101 ip sla 101 reachability

ip route vrf RED 0.0.0.0 0.0.0.0 10.100.1.254 track 101
ip route vrf RED 0.0.0.0 0.0.0.0 10.100.2.254 200

!
ip sla 102
 icmp-echo 10.200.1.1 vrf BLUE
 frequency 5
ip sla schedule 102 life forever start-time now

track 102 ip sla 102 reachability

ip route vrf BLUE 0.0.0.0 0.0.0.0 10.200.1.254 track 102
ip route vrf BLUE 0.0.0.0 0.0.0.0 10.200.2.254 200
```

#### 検証方法
1. `show ip sla summary` にて、各 SLA ID の VRF 名が `RED`, `BLUE` として正しくアタッチされていることを確認。
2. `show ip route vrf RED` および `show ip route vrf BLUE` で、各 VRF のデフォルトルートが正常にインスタンス化されていることを確認。
3. VRF `RED` 内のターゲット 10.100.1.1 のみをダウンさせ、VRF `RED` のデフォルトルートのみがバックアップ（10.100.2.254）に切替わり、VRF `BLUE` 側には一切影響しないことを確認。

---

### ラボ 5: Object Tracking Flap Suppression (`delay down 10 up 5`) ＋ SLA Reaction Configuration

#### 問題
不安定な WAN 回線において、RTT が 150ms を超えた場合、またはパケットドロップが発生した場合に障害と判定する。ただし、一時的なスパイクによるバタつきを防ぐため、10 秒間継続して条件を満たした場合のみ DOWN に遷移させ、復旧時も 5 秒間安定した後に UP に復帰させよ。

#### 要件
1. IP SLA 50 を作成し、192.168.50.2 宛てに ICMP Echo を 2 秒間隔で送信すること。
2. `ip sla reaction-configuration 50 react rtt threshold-value 150 100 threshold-type immediate` を投入し、RTT 150ms 超過を Reaction エラーとして判定させること。
3. Track 50 を作成し、`delay down 10 up 5` を設定すること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 50
 icmp-echo 192.168.50.2
 threshold 150
 timeout 2000
 frequency 2
ip sla reaction-configuration 50 react rtt threshold-value 150 100 threshold-type immediate
ip sla schedule 50 life forever start-time now

track 50 ip sla 50 state
 delay down 10 up 5
```

#### 検証方法
1. `show ip sla reaction-configuration 50` を実行し、RTT しきい値が 150ms にセットされていることを確認。
2. WAN 回線に 200ms の遅延を注入する。
3. `show track 50` を直ちに実行すると、`State is Up` のまま `Delayed Down (10 secs remaining)` タイマーがカウントダウンを開始することを確認。
4. 遅延が 10 秒以上継続した後に、初めて `State is Down` に遷移することを確認。

---

### ラボ 6: Boolean Logic Tracking (AND / OR) によるマルチパス監視

#### 問題
R1 は 2 つの独立した外部 Gateway (192.168.1.1 / 192.168.2.1) を経由してインターネットへ接続している。両方の Gateway 宛ての疎通が**両方とも失われた場合（AND 条件）** のみ、企業内データセンター宛てのバックアップ BGP パスへ切り替えさせよ。

#### 要件
1. IP SLA 61 (192.168.1.1 宛て ICMP) および IP SLA 62 (192.168.2.1 宛て ICMP) を作成すること。
2. Track 61 (SLA 61) および Track 62 (SLA 62) を作成すること。
3. 複合 Track 100 を作成し、`track 61` と `track 62` の **Boolean AND (双方 Down で Down)** 論理構造を構成すること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 61
 icmp-echo 192.168.1.1
 frequency 5
ip sla schedule 61 life forever start-time now

track 61 ip sla 61 reachability

ip sla 62
 icmp-echo 192.168.2.1
 frequency 5
ip sla schedule 62 life forever start-time now

track 62 ip sla 62 reachability

! Track 100: 両方が Down の場合のみ Down (Boolean OR of UP states = どちらか一方でも UP なら UP)
track 100 list boolean or
 object 61
 object 62
 delay down 5 up 5

ip route 0.0.0.0 0.0.0.0 10.254.1.1 track 100
ip route 0.0.0.0 0.0.0.0 10.254.2.1 200
```

#### 検証方法
1. `show track 100` を実行し、`List boolean or` として 61 と 62 がアタッチされていることを確認。
2. 192.168.1.1 (SLA 61) のみを切断する。`show track 100` は `State is Up` を維持（SLA 62 が UP のため）し、Primary デフォルトルートが維持されることを確認。
3. 192.168.2.1 (SLA 62) も切断する。双方 DOWN になったことで Track 100 が DOWN に遷移し、バックアップルート (10.254.2.1) へ切り替わることを確認。

---

### ラボ 7: IP SLA Responder Authentication (MD5 Key-Chain / Key-String)

#### 問題
未承認のルータによる不正な IP SLA Responder セッション制御を防ぐため、Sender (R1) と Target (R2) 間の UDP Jitter プローブコントロールパケット（UDP 1981）に MD5 認証を強制せよ。

#### 要件
1. R1 および R2 上で Key Chain `SLA_AUTH`（Key ID: 1, Key String: `CCIE_Secure_2026`）を構成すること。
2. R2 上で `ip sla responder` および `ip sla responder authentication key-chain SLA_AUTH` を有効化すること。
3. R1 上で IP SLA 70 (UDP Jitter) を作成し、`key-chain SLA_AUTH` をアタッチすること。

#### 設定例
```bash
! === R2 (Responder) Configuration ===
key chain SLA_AUTH
 key 1
  key-string CCIE_Secure_2026

ip sla responder
ip sla responder authentication key-chain SLA_AUTH

! === R1 (Sender) Configuration ===
key chain SLA_AUTH
 key 1
  key-string CCIE_Secure_2026

ip sla 70
 udp-jitter 192.168.12.2 16384 source-ip 192.168.12.1
 key-chain SLA_AUTH
 frequency 10
ip sla schedule 70 life forever start-time now

track 70 ip sla 70 state
```

#### 検証方法
1. `show ip sla statistics 70` にて、`Return code: OK` で正常にレスポンスが受信できていることを確認。
2. R1 側の Key-string を誤った値に変更すると、`debug ip sla error` にて MD5 Mismatch エラーが記録され、測定が停止 (`Return code: No Connection` / `Auth Failure`) することを確認。

---

### ラボ 8: UDP Echo Probe ＋ EEM 自動リストア・CLI アプレット

#### 問題
対向ルータ (10.1.1.2) の UDP Echo サービス（ポート 7）を監視し、応答停止（Timeout）時に EEM アプレットを起動して、WAN インターフェイスを自動バウンス (shutdown / no shutdown) させよ。

#### 要件
1. R1 上で IP SLA 80 を作成し、`udp-echo 10.1.1.2 7` プローブを設定すること。
2. 10 秒間隔でチェックし、タイムアウトは 3000ms とすること。
3. Object Track 80 を作成し、IP SLA 80 の `state` を監視すること。
4. EEM Applet `RESET_WAN_PORT` を作成し、Track 80 が DOWN に遷移した際、Gi0/0/3 インターフェイスを `shutdown` / `no shutdown` させ、Syslog ログを発行させること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 80
 udp-echo 10.1.1.2 7
 timeout 3000
 frequency 10
ip sla schedule 80 life forever start-time now

track 80 ip sla 80 state

event manager applet RESET_WAN_PORT
 event track 80 state down
 action 1.0 syslog msg "EEM: SLA Failed! Bouncing Port Gi0/0/3..."
 action 2.0 cli command "enable"
 action 3.0 cli command "configure terminal"
 action 4.0 cli command "interface GigabitEthernet0/0/3"
 action 5.0 cli command "shutdown"
 action 6.0 cli command "no shutdown"
 action 7.0 cli command "end"
```

#### 検証方法
1. 対向の UDP 7 番サービスを停止する。
2. IP SLA 80 が Timeout となり、Track 80 が DOWN へ遷移。
3. `show logging` にて EEM の Syslog メッセージが出力され、Gi0/0/3 ポートが自動的にリセットされる動作を確認。

---

### ラボ 9: Multiple Probes ＋ Threshold Tracking (Percentage Threshold)

#### 問題
本社から支店宛ての 4 つのトンネルパス (Tunnel 1〜4) に対する ICMP 疎通状態を個別監視し、**全体（4本）のうち 50% 以上（2本以上）が停止した場合** にのみ、データセンター宛ての非常用バックアップ経路を有効化させよ。

#### 要件
1. IP SLA 91〜94 を作成し、Tunnel 1〜4 の対向 IP 宛てに ICMP Echo を送信すること。
2. Track 91〜94 を作成すること。
3. 複合 Track 200 を作成し、`track list threshold percentage` を使用して、DOWN の割合が 50% に達した際に Track 200 を DOWN 状態とさせること。

#### 設定例
```bash
! === R1 Configuration ===
ip sla 91
 icmp-echo 10.1.1.2
 frequency 5
ip sla schedule 91 life forever start-time now
track 91 ip sla 91 reachability

ip sla 92
 icmp-echo 10.1.2.2
 frequency 5
ip sla schedule 92 life forever start-time now
track 92 ip sla 92 reachability

ip sla 93
 icmp-echo 10.1.3.2
 frequency 5
ip sla schedule 93 life forever start-time now
track 93 ip sla 93 reachability

ip sla 94
 icmp-echo 10.1.4.2
 frequency 5
ip sla schedule 94 life forever start-time now
track 94 ip sla 94 reachability

! Percentage Threshold: UP オブジェクトの割合が 51% 未満（＝50%以下、つまり2本以上DOWN）で Down に変移
track 200 list threshold percentage
 object 91
 object 92
 object 93
 object 94
 threshold weight 50 75

ip route 0.0.0.0 0.0.0.0 172.16.1.1 track 200
ip route 0.0.0.0 0.0.0.0 172.16.2.1 200
```

#### 検証方法
1. `show track 200` を実行し、4 つのオブジェクトが登録され、現在 100% UP 状態であることを確認。
2. Tunnel 1 (SLA 91) のみをダウンさせる（UP 率 75%）。Track 200 は UP 状態を維持。
3. Tunnel 2 (SLA 92) もダウンさせる（UP 率 50%）。しきい値 50% 以下に達したため Track 200 が DOWN に変化し、バックアップ経路 (172.16.2.1) がロードされることを確認。

---

### ラボ 10: IP SLA ＋ Control Plane Policing (CoPP) での制御通信（UDP 1981/ICMP）保護

#### 問題
ルータ上で CoPP（Control Plane Policing）が有効化されており、大量の攻撃パケット発生時にも IP SLA の制御パケット（UDP 1981）および ICMP プローブパケットがドロップされず、正しい計測と Track 状態維持を保障せよ。

#### 要件
1. CoPP 用の Access-List `ACL_IPSLA_COPP` を作成し、IP SLA コントロール（UDP 1981）および ICMP / UDP データ通信を明示許可すること。
2. Class-Map `CM_IPSLA` を構成し、ACL にマッチさせること。
3. Control-Plane の Policy-Map 内で `CM_IPSLA` に対して十分なポリシング帯域（例: 1Mbps）を与え、優先転送させること。

#### 設定例
```bash
! === R1 Configuration ===
ip access-list extended ACL_IPSLA_COPP
 permit udp any any eq 1981
 permit udp any eq 1981 any
 permit icmp any any echo
 permit icmp any any echo-reply

class-map match-all CM_IPSLA
 match access-group name ACL_IPSLA_COPP

policy-map COPP_POLICY
 class CM_IPSLA
  police 1000000 conform-action transmit exceed-action transmit

control-plane
 service-policy input COPP_POLICY
```

#### 検証方法
1. `show policy-map control-plane` を実行し、IP SLA パケットが `CM_IPSLA` クラスに正しいパケット数でマッチし、`conform` としてコントロールプレーンに到達していることを確認。
2. 大量の ICMP Flood を受信した場合でも、IP SLA プローブの着信が正しく保護され、Track オブジェクトが誤って DOWN に遷移しないことを確認。


## ❓ 想定試験問題

### 問 1 (コンフィグ読解)
以下のコンフィグが投入されたルータにおいて、192.168.12.2 への ICMP 疎通が一時的に切断された後、復旧した。ルーティングテーブルの挙動として正しいものを一つ選べ。

```bash
ip sla 10
 icmp-echo 192.168.12.2
 frequency 5
ip sla schedule 10 life forever start-time now

track 10 ip sla 10 reachability
 delay down 15 up 30

ip route 0.0.0.0 0.0.0.0 192.168.12.2 track 10
ip route 0.0.0.0 0.0.0.0 192.168.13.3 200
```

* (A) ICMP 切断後、直ちに 192.168.12.2 へのルートが削除され、192.168.13.3 へ切り替わる。
* (B) ICMP 切断が 15 秒間継続した時点で 192.168.12.2 へのルートが削除され、復旧後直ちに元に戻る。
* (C) ICMP 切断が 15 秒間継続した時点で 192.168.12.2 へのルートが削除され、ICMP 復旧後 30 秒間安定した後に Primary ルートへ復帰する。
* (D) `reachability` ではなく `state` を指定していないため、Track 10 は永遠に Down にならない。

**正解: (C)**
**解説**: `delay down 15 up 30` が設定されているため、障害検知（Down）には 15 秒の継続が必要であり、復旧（Up）にも 30 秒のタイマーが満了するまで Track は Up に変移しない。したがって正解は (C) である。

---

### 問 2 (トラブルシューティング)
Sender ルータで以下の UDP Jitter プローブを構成したが、`show ip sla statistics` を実行すると `Return code: No Connection` と表示され計測に失敗する。ターゲットルータ (10.1.3.3) 上で既に入力されているべき欠落コマンドはどれか。

```bash
! Sender Config
ip sla 20
 udp-jitter 10.1.3.3 16384 source-ip 10.1.1.1
 frequency 10
ip sla schedule 20 life forever start-time now
```

* (A) `ip sla responder`
* (B) `ip sla server`
* (C) `ip rpc-server`
* (D) `ip sla schedule 20 life forever start-time now`

**正解: (A)**
**解説**: `udp-jitter` や `udp-echo` プローブの動作には、ターゲットデバイス上で `ip sla responder` コマンドが有効化されていることが必須条件である。

---

### 問 3 (Design)
全国 100 箇所の拠点を持つエンタープライズ網において、WAN 回線障害の自動検知と HSRP / Static Route の自律切り替えを設計している。各拠点のルータ CPU 負荷とコントロールプレーン帯域消費を抑えつつ、かつ誤切替（Flapping）を回避するための設計として最も適切な組み合わせはどれか。

* (A) 全拠点で `frequency 1`（1秒間隔）を設定し、`delay` タイマーは設定しない。
* (B) `frequency 5〜10` 秒とし、`timeout` を 2000ms 以下に設定の上、`track` に `delay down 10 up 30` を付与する。
* (C) `timeout` を `frequency` より大きな値（`frequency 5`, `timeout 10000`）に設定する。
* (D) 全ての監視に HTTP L7 プローブを使用し、1秒周期で測定する。

**正解: (B)**
**解説**: ベストプラクティスとして、過度な短い周期（1秒以下）は避けて 5〜10秒とし、`timeout` は `frequency` 未満に収め、Flapping 抑制のために `delay down/up` を組み合わせることが最も推奨される。

---

### 問 4 (実装)
VRF `GUEST` 内のネクストホップ 10.20.1.1 宛てに ICMP Echo を送信してルートを監視するコンフィグを作成したい。正しい IP SLA 定義の記述はどれか。

```bash
! Option A
ip sla 100
 icmp-echo 10.20.1.1 vrf GUEST
 frequency 5
ip sla schedule 100 life forever start-time now

! Option B
ip sla 100
 icmp-echo 10.20.1.1
 option vrf GUEST
 frequency 5

! Option C
ip sla vrf GUEST 100
 icmp-echo 10.20.1.1

! Option D
ip sla 100 vrf GUEST
 icmp-echo 10.20.1.1
```

* (A) Option A
* (B) Option B
* (C) Option C
* (D) Option D

**正解: (A)**
**解説**: Cisco IOS XE における VRF 指定の正当な構文は `icmp-echo <target-ip> vrf <vrf-name>`（または一部コマンドにおける `vrf` サブコマンド）である。

---

### 問 5 (トラブルシューティング)
`udp-jitter` プローブに MD5 認証をアタッチしたが、`debug ip sla error` にて `Authentication failure / MD5 mismatch` が記録される。原因として考えられるものはどれか（2つ選べ）。

* (A) Sender と Responder で `key chain` 内の `key-string` が一致していない。
* (B) Sender と Responder で `key` ID 番号が一致していない。
* (C) `ip sla schedule` に `life forever` が設定されていない。
* (D) NTP による時刻同期が行われていない。

**正解: (A), (B)**
**解説**: MD5 認証の成功には、双方で参照する Key Chain の Key ID 番号および `key-string` が完全に一致していることが要求される。

---

## 🔗 参考リソース

* Cisco Configuration Guide: IP SLAs Configuration Guide, Cisco IOS XE 17.x
* Cisco Command Reference: IP SLAs Command Reference, Cisco IOS XE 17.x
* Cisco Technical Notes: Troubleshooting IP SLA Operations and High Availability
* Cisco Live Presentations: BRKARC-2001 - Deep Dive into IP SLA and Performance Monitoring
* Cisco Validated Designs (CVD): Enterprise WAN and Edge High Availability Design Guide

---

## 📝 補足（Notes）

### 1. SLA 測定精度の限界と制限
IP SLA プローブパケットは、ルータのコントロールプレーン（CPU）によって生成および処理解析される。そのため、超高負荷状態（CPU 90% 以上）では、パケットの送信・受信処理自体が遅延し、実際のネットワーク遅延よりも大きな計測値が算出される（False Positive）。重要拠点では CoPP や QoS で IP SLA トラフィックを保護することが重要である。

### 2. ICMP Echo と UDP Jitter の使い分け
* 単なる L3 リンクの UP/DOWN 判定 ➔ `icmp-echo`（Responder 不要で構成がシンプル）。
* 音声/ビデオ回線の品質（Jitter/Loss/片道遅延）維持 ➔ `udp-jitter`（Responder 必須だが高精度）。



## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**DGTL-BRKRST-2042: Highly Available Wide Area Network Design**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2042) - IP SLA とトラッキングを用いた設計。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE 試験におけるネットワーク最適化ツールの重要性。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: IP SLAs Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipsla/configuration/xe-17/sla-xe-17-book.html)。
*   [**Configuring Enhanced Object Tracking**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipapp/configuration/xe-17/ipapp-xe-17-book/ipapp-eot.html)。

### テクニカルドキュメント・設定例
*   [**IP SLAs ICMP Echo Operation (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200785-Configure-IP-SLA-ICMP-Echo.html)。
*   [**Reliable Static Routing with IP SLA (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200785-Configure-IP-SLA-ICMP-Echo.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験合格に必要な **「監視と動的アクションの統合」** に焦点を当てています。ラボ試験では、設定後に **`show track`** コマンドで状態が `Up` になっているか、そしてインターフェイスの `shutdown` などで意図した通りに状態が切り替わるかを必ず確認してください。


