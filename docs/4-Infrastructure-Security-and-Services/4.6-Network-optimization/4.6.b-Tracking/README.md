---
layout: default
title: 4.6.b-Tracking
parent: 4.6-Network-optimization
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.6.b Tracking objects and lists

## 📘 概要

Object Tracking（オブジェクトトラッキング）は、Cisco IOS / IOS XEにおけるネットワーク状態のリアルタイム監視および動的アクション連動を実現する基盤機能です。特定の物理/論理インターフェイスのLine Protocol状態、IPルーティングテーブルにおける特定プレフィックスの到達性やメトリック、IP SLAプローブの測定結果、さらには複数の監視対象を組み合わせた論理トラッキング（Boolean AND / OR、Threshold Weight / Percentage）をオブジェクトとして定義できます。

トラッキングオブジェクトの状態（`Up` または `Down`、および数値メトリック）は、HSRP / VRRP / GLBPといったファーストホップ冗長化プロトコル（FHRP）、スタティックルート（Floating Static Route）、ポリシーベースルーティング（PBR）、BGP経路制御、Embedded Event Manager（EEM）などの他機能へ動的に連携されます。これにより、ネットワーク障害発生時の高速迂回、自動切り戻し時のフラッピング防止（Dampening）、および複雑な条件分岐に基づくトラフィック制御を可能にします。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| 特徴 | インターフェイス状態、IPルート到達性、IP SLA、複数オブジェクトの論理結合（Boolean/Threshold）を動的追跡 |
| 用途 | FHRPプライオリティ動的減算、Floating Static Route切替、PBRネクストホップ自動検証、EEMイベントトリガー |
| メリット | 物理障害だけでなくL3到達性や通信品質低下を検知し、数秒〜ミリ秒単位で制御機能へ連動可能 |
| デメリット | 不適切なタイマー設定時に回線瞬断やジッターによる制御のバタつき（Flapping）を引き起こすリスク |
| 対応機種 | Catalyst 9000 シリーズ、ISR 4000 シリーズ、ASR 1000 シリーズ、C8000V などの Cisco IOS / IOS XE 全般 |
| 制限事項 | 1つのTrack Listに登録可能なオブジェクト数や階層深度にプラットフォーム依存の制限あり |
| 設計上の注意点 | 障害検知時間と切り戻し遅延タイマー（`delay down/up`）を適切に設計し、フラッピングを防止 |

---

## 🏗 動作原理

Object Trackingは、監視対象（Entity）の状態変化を定期的なポーリングまたはイベント駆動で検知し、Trackオブジェクトのステートマシン（State Machine）を更新します。

```
[監視対象 (Entity)]
  ├─ Interface (Line Protocol / IPv4/IPv6 Routing)
  ├─ IP Route (Reachability / Metric Threshold)
  ├─ IP SLA (Reachability / State)
  └─ Application / Stub
        │
        ▼ (状態・値の変化)
[Object Tracking Engine]
  ├─ 単一オブジェクト評価 (Single Object)
  └─ 複合オブジェクト評価 (Track List: Boolean AND/OR, Weight, Percentage)
        │
        ▼ (Up/Down 判定 + Delay Timer)
[連動機能 (Consumers)]
  ├─ FHRP (HSRP / VRRP / GLBP Priority Decrement)
  ├─ Routing (Static Route Track, PBR verify-availability)
  └─ Control / Automation (EEM Event Track, BGP Conditional Adv)
```

1. **Entity State Check**: 監視対象のインターフェイスまたはプロトコルモジュールから状態フラグを受信、またはIP SLA / Route Tableの値を検証。
2. **Track List Logic Processing**: トラックリスト（Boolean / Threshold）の場合、子オブジェクトの状態・重み（Weight）・割合（Percentage）を集計して全体のステートを決定。
3. **Delay Timer Processing**: ステート変化（例: Up -> Down、Down -> Up）が発生した際、設定された `delay down` または `delay up` タイマーを起動。タイマー満了までステート遷移を猶予。
4. **Consumer Notification**: 決定したステートをアタッチされた連動機能（FHRP、Static Route、EEM等）へ非同期通知。

---

## ⚙ 動作シーケンス

以下は、WANメイン回線障害時における IP SLA + Object Tracking + Floating Static Route + FHRP 連動のパケット・イベント処理シーケンスです。

```
[WAN Main Interface]       [IP SLA Probe]       [Track Object]       [Routing Table]       [HSRP State]
         │                       │                    │                     │                   │
  (物理/L3障害発生)              │                    │                     │                   │
         │──────────────────────>│ (応答不可/Timeout) │                     │                   │
         │                       │───────────────────>│                     │                   │
         │                       │  (SLA State Down)  │                     │                   │
         │                       │                    │ (delay downタイマー)│                   │
         │                       │                    │ 起動 (例: 5秒待機)  │                   │
         │                       │                    │────────────────────>│                   │
         │                       │                    │  (State: Down確定)  │ (メインスタティック│
         │                       │                    │                     │  ルート削除)      │
         │                       │                    │                     │──────────────────>│ (HSRP Priority
         │                       │                    │                     │                   │  減算 -20)
         │                       │                    │                     │                   │ (Standby -> Active
         │                       │                    │                     │                   │  サブ機へ昇格)
```

1. **障害発生**: メインWAN回線上の上位プロバイダ網内でサイレント障害が発生（物理リンクはUpのまま）。
2. **IP SLA プローブ検出**: `ip sla 1` (ICMP Echo) がタイムアウトし、IP SLAの状態が `Down` に遷移。
3. **Trackオブジェクト評価**: `track 10 ip sla 1 reachability` が障害を検知。`delay down 5` タイマーがカウントダウンを開始。
4. **ステート確定通知**: 5秒間障害が継続したため、Track 10 のステートが `Down` へ確定。
5. **ルーティングテーブル更新**: `ip route 0.0.0.0 0.0.0.0 192.168.1.1 track 10` が無効化され、FIBから削除。アドミニストレーティブディスタンスの高いバックアップルート（Floating Static）へ昇格。
6. **FHRPグループ更新**: `standby 1 track 10 decrement 20` により、優先度が 110 から 90 に下降。サブ側ルータ（Priority 100）がアクティブに昇格。


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、Object Tracking は単独で出題されるだけでなく、**FHRP（HSRP/VRRP）、ルーティング（Static Route/PBR）、およびEEMの前提条件**として頻繁に組み合わされます。

### Blueprintで重要なポイント
* **オブジェクトタイプごとの正しい構文選定**:
  * インターフェイスの L2 状態: `track 1 interface GigabitEthernet0/0/1 line-protocol`
  * インターフェイスの IP ルーティング有効性: `track 2 interface GigabitEthernet0/0/1 ip routing`
  * IP SLA ICMP/UDP応答: `track 3 ip sla 1 reachability` または `state`
  * IPルートの存在確認: `track 4 ip route 10.1.1.0/24 reachability`
  * IPルートのメトリック範囲監視: `track 5 ip route 10.1.1.0/24 metric threshold`
* **Track List のロジック設計**:
  * `list boolean and`: **すべての**子オブジェクトが Up であれば Up（1つでも Down なら Down）。
  * `list boolean or`: **いずれか1つ**のオブジェクトが Up であれば Up（全滅で Down）。
  * `list threshold weight`: 子オブジェクトの Weight（重み）の合計値が設定閾値（Threshold）を下回ると Down。
  * `list threshold percentage`: Up 状態の子オブジェクトの割合（%）が設定閾値を下回ると Down。
* **フラッピング抑止タイマーの設定**:
  * `delay down <sec> up <sec>` の確実な投入。ラボの要件で「回線切り替え後、復旧時は30秒間動作を猶予すること」と指定された場合、`delay up 30` を設定。

### よくある設定ミス・落とし穴
1. **`reachability` と `state` の指定誤り**:
   * `icmp-echo` などのシンプルな到達性測定では `reachability` を使用。
   * `udp-jitter` や Reaction Threshold（しきい値判定）を設定した IP SLA では `state` を使用する必要がある。誤って `reachability` を指定すると、遅延悪化によるしきい値超え（Threshold Exceeded）が Track に反映されない。
2. **`ip route` トラッキングにおける最長一致の罠**:
   * `track ip route 10.1.0.0 255.255.0.0 reachability` を設定した際、デフォルトルート `0.0.0.0/0` やより具体的な `10.1.1.0/24` が存在しても、指定した `10.1.0.0/16` の正確なプレフィックスが RIB に存在しないと Down と判定される。
3. **FHRP 減算値（Decrement）の計算ミス**:
   * HSRP アクティブ機（Priority 110）、スタンバイ機（Priority 100）の構成で、減算値を `-5` に設定した場合、アクティブ障害時でも Priority は 105 となり、スタンバイ機（100）へ切替が発生しない。正しく 11 未満（例: `-15` または `-20`）を設定する必要がある。

---

## 🛠 設定方法

### 1. 単一オブジェクトトラッキング設定
```bash
! 1. インターフェイス Line-Protocol トラッキング
track 10 interface GigabitEthernet0/0/1 line-protocol
 delay down 5 up 10

! 2. IP SLA 到達性トラッキング
ip sla 1
 icmp-echo 192.168.1.1 source-interface Loopback0
 frequency 5
ip sla schedule 1 life forever start-time now

track 20 ip sla 1 reachability
 delay down 3 up 30

! 3. IP ルート到達性 & メトリック閾値トラッキング
track 30 ip route 10.100.1.0 255.255.255.0 reachability

track 31 ip route 10.200.1.0 255.255.255.0 metric threshold
 threshold metric up 100 down 200
```

### 2. Track List (Boolean AND / OR) 設定
```bash
! 複数回線（WAN1 および WAN2）の両方が障害時に Down と判定する OR リスト
! （どちらか1つでも Up なら Track List は Up）
track 100 list boolean or
 object 20
 object 30
 delay down 5 up 15

! 2つの核心サービスが両方健全な場合のみ Up と判定する AND リスト
track 200 list boolean and
 object 10
 object 20
```

### 3. Track List (Threshold Weight / Percentage) 設定
```bash
! 重み付け（Weight）による閾値判定
track 300 list threshold weight
 object 10 weight 20
 object 20 weight 30
 object 30 weight 50
 threshold weight up 50 down 40

! パーセンテージによる閾値判定
track 400 list threshold percentage
 object 10
 object 20
 object 30
 object 40
 threshold percentage up 75 down 50
```

### 4. 他機能（FHRP / Static Route / PBR / EEM）への連動設定
```bash
! HSRP 優先度減算連動
interface GigabitEthernet0/0/0.10
 ip address 10.1.1.2 255.255.255.0
 hsrp version 2
 hsrp 10 ip 10.1.1.1
 hsrp 10 priority 110
 hsrp 10 preempt delay minimum 30
 hsrp 10 track 100 decrement 20

! Floating Static Route 連動
ip route 0.0.0.0 0.0.0.0 192.168.12.1 track 20
ip route 0.0.0.0 0.0.0.0 192.168.13.1 200

! PBR 宛先ネクストホップ自動検証連動
route-map PBR_POLICY permit 10
 match ip address ACL_DATA
 set ip next-hop verify-availability 192.168.1.1 1 track 20

! EEM イベント連動
event manager applet TRACK_DOWN_ALERT
 event track 20 state down
 action 1.0 syslog msg "Track 20 went DOWN! Initiating failover procedures."
 action 2.0 cli command "enable"
 action 3.0 cli command "clear ip bgp *"
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| 全Trackオブジェクトの状態確認 | <code>show track</code> |
| 特定Trackオブジェクトの詳細確認 | <code>show track 10</code> |
| 簡略形式でのTrack一覧表示 | <code>show track brief</code> |
| トラックリスト構成の確認 | <code>show track resolution</code> |
| HSRPとTrack連動状態の確認 | <code>show hsrp track</code> |
| IP SLA動作状態の確認 | <code>show ip sla summary</code> |
| リアルタイムTrack状態遷移デバッグ | <code>debug track state</code> |
| Trackイベント発生デバッグ | <code>debug track event</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| IP SLAが障害状態なのにTrackがDownにならない | Track定義で `state` ではなく `reachability` を指定している | <code>show track <id></code><br><code>show ip sla statistics</code> | しきい値超過判定のあるSLAでは `track <id> ip sla <num> state` に修正 |
| Track Listが意図しないステートを維持する | Boolean AND/OR のロジック解釈ミス、または子オブジェクトの指定間違い | <code>show track <id></code> | `list boolean or` と `list boolean and` の定義ルールを再検証 |
| HSRPが障害時に切り替わらない | HSRP の `decrement` 設定値がスタンバイ機との Priority 差分より小さい | <code>show hsrp brief</code><br><code>show track</code> | `hsrp <grp> track <id> decrement <val>` の減算値を拡大設定 |
| 回線の瞬断でTrackが頻繁にFlappingする | `delay down / up` タイマーが未設定または極端に短い | <code>show track</code> | `track <id>` 配下に `delay down <sec> up <sec>` を追加設定 |
| ルートトラッキングでプレフィックスが存在するのにDownになる | ルーティングテーブル上のサブネットマスク不一致（例: /24 と /16） | <code>show ip route <prefix></code><br><code>show track</code> | RIBに存在する正確なプレフィックス長で `track ip route` を再定義 |

---

## ⚠ 制限事項

* **プラットフォームリソースの制限**: 非常に多数の Track オブジェクト（数千個以上）や短い周期（ミリ秒単位）の IP SLA プローブを組み合わせると、CPU 使用率が高騰する可能性があります。
* **Track List のネスト階層**: トラックリスト内に別のトラックリストを組み込む「ネスト設定」は、IOS XE のバージョンにより制限または非推奨となる場合があります。
* **IPv6 Track の構文差異**: IPv6 ルートのトラッキングを行う場合は、`track <id> ipv6 route <prefix>/<length> reachability` のように `ipv6` キーワードを明示指定する必要があります。

---

## 🔄 他技術との関連

* **FHRP (HSRP / VRRP / GLBP)**: アップストリーム障害を検知し、仮想ルータのプライオリティを動的に減算またはインターフェイスをシャットダウンして高速切り替えを実現。
* **Static Routing**: 主回線の宛先プレフィックスに `track <id>` をバインドし、障害発生時に RIB から削除してバックアップルート（Floating Static Route）へ切替。
* **PBR (Policy-Based Routing)**: `set ip next-hop verify-availability <ip> <seq> track <id>` により、静的に指定したネクストホップの正常性をリアルタイム検証。
* **EEM (Embedded Event Manager)**: `event track <id> state [up|down|any]` を条件として、ネットワーク障害発生時に任意のCLIコマンド自動実行やログ出力をトリガー。

---

## 🧩 比較表

### Track List タイプ比較

| リストタイプ | 定義コマンド | 評価ルール | 主な用途 |
| --- | --- | --- | --- |
| **Boolean AND** | `track <id> list boolean and` | **全オブジェクトが Up** の時のみ Up | 複数条件（物理 link + L3 SLA）がすべて健全であることを要求する構成 |
| **Boolean OR** | `track <id> list boolean or` | **少なくとも1つが Up** であれば Up | 冗長回線（WAN1 or WAN2）のいずれか1つでも稼働していればUpとみなす構成 |
| **Threshold Weight** | `track <id> list threshold weight` | 子オブジェクトの Weight 合計が **Threshold 以上** で Up | 各回線の帯域幅や重要度に応じた重み付け障害判定 |
| **Threshold Percentage** | `track <id> list threshold percentage` | Up 状態の子オブジェクトの割合（%）が **Threshold 以上** で Up | 多数のサーバーや回線群のうち一定割合以上が生きているかを監視する構成 |

---

## 💡 ベストプラクティス

1. **必ず Flap Suppression タイマー（`delay`）を設定する**: 回線の瞬断やIP SLAプローブの一時的な不調でルーティングやFHRPが頻繁に切り替わるのを防ぐため、最低でも `delay down 3 up 10` 程度を投入します。
2. **IP SLA 連携時は `state` と `reachability` を厳密に使い分ける**: 単純な Ping 応答確認は `reachability`、ジッターやパケットロス率のしきい値判定は `state` を使用します。
3. **HSRP/VRRP プリエンプト遅延と組み合わせる**: 切戻し時（Down -> Up）に即座にアクティブに戻ると、上流プロトコル（BGP/OSPF）の収束前にトラフィックが流れてブラックホール化するため、FHRP 側にも `preempt delay minimum 30` などを設定します。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: Interface Line-Protocol Tracking ＋ HSRP Priority Decrement
#### 問題
R1 は WAN インターフェイス Gi0/0/1 の障害を検知し、LAN 側（Gi0/0/0）の HSRP アクティブ状態を R2 へスムーズに引き継ぐ必要があります。

#### 要件
1. R1 の Gi0/0/1 インターフェイスの Line Protocol 状態を監視する Track 10 を作成すること。
2. 障害発生時は 3 秒待機後に Down とし、復旧時は 10 秒待機後に Up とすること（Flapping 防止）。
3. HSRP グループ 10 において、Track 10 が Down になった際に Priority を 30 減算（110 -> 80）し、R2（Priority 100）へ Active を譲渡すること。

#### 設定例
```bash
! R1 Configuration
track 10 interface GigabitEthernet0/0/1 line-protocol
 delay down 3 up 10

interface GigabitEthernet0/0/0
 ip address 10.1.1.2 255.255.255.0
 hsrp version 2
 hsrp 10 ip 10.1.1.1
 hsrp 10 priority 110
 hsrp 10 preempt delay minimum 15
 hsrp 10 track 10 decrement 30
```

#### 検証方法
```bash
R1# show track 10
R1# show hsrp GigabitEthernet0/0/0 10
R1(config)# interface GigabitEthernet0/0/1
R1(config-if)# shutdown
! 3秒後に Track 10 が Down になり、HSRP Priority が 80 に低下して R2 が Active に昇格することを確認
```

---

### ラボ 2: IP SLA ICMP Echo ＋ Floating Static Route Tracking
#### 問題
プライマリ ISP 宛ての L3 到達性を IP SLA で監視し、通信不能時にバックアップ ISP へのデフォルトルートに自動切替します。

#### 要件
1. 対向 198.51.100.1 宛ての ICMP Echo プローブを 5 秒周期で実行する `ip sla 1` を設定すること。
2. `ip sla 1` の到達性を監視する `track 20` を作成し、Down 遅延 5 秒、Up 遅延 15 秒を設定すること。
3. プライマリデフォルトルート（Next-Hop 198.51.100.1）に `track 20` をバインドし、障害発生時に削除して AD 200 のバックアップルート（Next-Hop 203.0.113.1）へ切替えること。

#### 設定例
```bash
ip sla 1
 icmp-echo 198.51.100.1 source-interface GigabitEthernet0/0/1
 frequency 5
ip sla schedule 1 life forever start-time now

track 20 ip sla 1 reachability
 delay down 5 up 15

ip route 0.0.0.0 0.0.0.0 198.51.100.1 track 20
ip route 0.0.0.0 0.0.0.0 203.0.113.1 200
```

#### 検証方法
```bash
show ip sla statistics
show track 20
show ip route 0.0.0.0
! プライマリ回線上のパケットドロップをシミュレートし、5秒後に 0.0.0.0/0 が 203.0.113.1 へ切り替わることを確認
```

---

### ラボ 3: Track List Boolean OR (Dual WAN Redundancy) ＋ Floating Static
#### 問題
2つのメイン WAN 回線（ISP-A、ISP-B）のいずれか1つでも稼働している限りメインルートを維持し、両回線が同時に全滅した場合のみバックアップ WAN（LTE）へ切替えます。

#### 要件
1. ISP-A 宛て（`ip sla 10`）および ISP-B 宛て（`ip sla 20`）の可達性を追跡する `track 10` と `track 20` を作成すること。
2. `track 100` として `list boolean or` を定義し、`track 10` または `track 20` のいずれかが Up であれば `track 100` を Up と判定すること。
3. デフォルトルートに `track 100` をバインドすること。

#### 設定例
```bash
ip sla 10
 icmp-echo 192.0.2.1
 frequency 5
ip sla schedule 10 life forever start-time now

ip sla 20
 icmp-echo 198.51.100.1
 frequency 5
ip sla schedule 20 life forever start-time now

track 10 ip sla 10 reachability
track 20 ip sla 20 reachability

track 100 list boolean or
 object 10
 object 20
 delay down 3 up 10

ip route 0.0.0.0 0.0.0.0 192.0.2.1 track 100
ip route 0.0.0.0 0.0.0.0 203.0.113.1 250
```

#### 検証方法
```bash
show track 100
! ISP-A 宛て通信を遮断しても Track 20 が Up であれば Track 100 は Up を維持
! ISP-A と ISP-B の両方を遮断した時のみ Track 100 が Down になり LTE ルートへ切替わることを確認
```

---

### ラボ 4: Track List Boolean AND (Multi-Condition) ＋ HSRP Shutdown
#### 問題
LAN 側の HSRP ルータにおいて、「物理リンク状態」と「本社データセンターへの L3 到達性」の両方が正常な場合のみ自装置を Active として動作させます。

#### 要件
1. Gi0/0/1 の Line-Protocol を監視する `track 1` を作成。
2. データセンター（10.254.0.1）への IP SLA を監視する `track 2` を作成。
3. 両方が Up の場合のみ Up となる `track 50`（`list boolean and`）を作成すること。
4. HSRP グループ 1 において、`track 50` が Down になった際は HSRP インターフェイスをソフト的に停止（`shutdown` 動作）させること。

#### 設定例
```bash
track 1 interface GigabitEthernet0/0/1 line-protocol

ip sla 100
 icmp-echo 10.254.0.1
 frequency 3
ip sla schedule 100 life forever start-time now

track 2 ip sla 100 reachability

track 50 list boolean and
 object 1
 object 2
 delay down 2 up 5

interface GigabitEthernet0/0/0
 ip address 10.1.1.2 255.255.255.0
 hsrp version 2
 hsrp 1 ip 10.1.1.1
 hsrp 1 priority 120
 hsrp 1 track 50 shutdown
```

#### 検証方法
```bash
show track 50
show hsrp brief
! Track 1 または Track 2 のいずれか1つを Down させると Track 50 が Down になり、HSRP 状態が Init/Shutdown に移行することを確認
```

---

### ラボ 5: Track List Threshold Weight ＋ VRRPv3 Priority Adjust
#### 問題
複数のアクセス回線（回線A: 100M、回線B: 50M、回線C: 50M）の健全性に応じた合計重み付け判定を行い、VRRPv3 のプライオリティを段階的または一括減算します。

#### 要件
1. 回線A（`track 1`）、回線B（`track 2`）、回線C（`track 3`）を定義すること。
2. `track 300` に `list threshold weight` を作成し、各オブジェクトの Weight を 回線A=50、回線B=25、回線C=25 と設定すること。
3. 重み合計値が Up 閾値 75 以上で Up、Down 閾値 50 未満で Down と判定すること。
4. VRRPv3 グループ 10 において `track 300` が Down になった際に Priority を 30 減算すること。

#### 設定例
```bash
track 1 interface GigabitEthernet0/0/1 line-protocol
track 2 interface GigabitEthernet0/0/2 line-protocol
track 3 interface GigabitEthernet0/0/3 line-protocol

track 300 list threshold weight
 object 1 weight 50
 object 2 weight 25
 object 3 weight 25
 threshold weight up 75 down 50

fhrp version vrrp v3

interface GigabitEthernet0/0/0
 ip address 10.1.1.2 255.255.255.0
 vrrp 10 address-family ipv4
  priority 110
  track 300 decrement 30
  address 10.1.1.1 primary
```

#### 検証方法
```bash
show track 300
show vrrp detail
! 回線B（Weight 25）のみ遮断時は合計Weight=75のため Up を維持
! 回線A（Weight 50）遮断時は合計Weight=50（<75）のため Down となり、VRRP Priority が 80 へ低下することを確認
```

---

### ラボ 6: Track List Threshold Percentage ＋ GLBP Weighting Adjust
#### 問題
マルチホーミング接続された4本の回線のうち、生存している回線の割合（%）が 50% を下回った場合に GLBP の AVF (Active Virtual Forwarder) 送信機能を停止します。

#### 要件
1. 4本のインターフェイス状態を監視する `track 11`〜`track 14` を作成すること。
2. `track 400` に `list threshold percentage` を作成し、Up 閾値 75%、Down 閾値 50% とすること。
3. GLBP グループ 1 において、`track 400` が Down になった際に Weighting を 30 減算し、Threshold Lower（100）を下回らせて AVF 役割を他号機へ移譲させること。

#### 設定例
```bash
track 11 interface Gi0/0/1 line-protocol
track 12 interface Gi0/0/2 line-protocol
track 13 interface Gi0/0/3 line-protocol
track 14 interface Gi0/0/4 line-protocol

track 400 list threshold percentage
 object 11
 object 12
 object 13
 object 14
 threshold percentage up 75 down 50

interface GigabitEthernet0/0/0
 ip address 10.1.1.2 255.255.255.0
 glbp 1 ip 10.1.1.1
 glbp 1 weighting 110 lower 100 upper 105
 glbp 1 weighting track 400 decrement 30
```

#### 検証方法
```bash
show track 400
show glbp
! 2本以上のインターフェイスを shutdown させると割合が 50% 以下になり Track 400 が Down。
! GLBP Weighting が 80（< Lower 100）となり、AVF 役割が解除されることを確認
```

---

### ラボ 7: IP SLA UDP Jitter State Tracking ＋ PBR Next-Hop Verification
#### 問題
基幹業務トラフィックの PBR 適用において、WAN 回線の遅延・Jitter 悪化（しきい値超過）を検知した際にネクストホップの適用を自動解除します。

#### 要件
1. 192.168.10.1 宛てに `ip sla 5` (UDP Jitter) を設定し、片道遅延が 50ms を超えた場合に SLA State を OverThreshold / Down に遷移させること。
2. `track 50` を `ip sla 5 state` として作成すること。
3. Route-Map 内で `set ip next-hop verify-availability 192.168.10.1 1 track 50` を設定し、品質悪化時に標準ルーティングへ切り替えること。

#### 設定例
```bash
ip sla 5
 udp-jitter 192.168.10.1 16384 num-packets 100
 frequency 10
 threshold 50
ip sla schedule 5 life forever start-time now

ip sla reaction-configuration 5 react rtt threshold-value 50 40 threshold-type immediate

track 50 ip sla 5 state
 delay down 2 up 10

ip access-list extended ACL_ERP_TRAFFIC
 permit ip 10.10.0.0 0.0.255.255 any

route-map PBR_ERP permit 10
 match ip address ACL_ERP_TRAFFIC
 set ip next-hop verify-availability 192.168.10.1 1 track 50

interface GigabitEthernet0/0/0
 ip policy route-map PBR_ERP
```

#### 検証方法
```bash
show ip sla statistics 5
show track 50
show route-map PBR_ERP
! 模擬遅延を発生させて RTT > 50ms となった際、Track 50 が Down になり PBR ネクストホップが Inactive となることを確認
```

---

### ラボ 8: IP Route Reachability & Metric Threshold Tracking ＋ Route Redistribution
#### 問題
IGP（OSPF）で学習した特定の監視プレフィックス（10.50.0.0/16）のメトリックが悪化した際、該当経路の BGP への再配布（Redistribution）を停止します。

#### 要件
1. OSPF 経路 `10.50.0.0/16` のメトリックを監視する `track 80` を作成すること。
2. メトリックが 200 を超えた（down 200）場合に Track を Down とし、100 以下に回復（up 100）した際に Up とすること。
3. Track 80 のステートに基づき Route-Map で制御すること。

#### 設定例
```bash
track 80 ip route 10.50.0.0 255.255.0.0 metric threshold
 threshold metric up 100 down 200

route-map OSPF_TO_BGP permit 10
 match ip address ACL_TRACKED_NET
 match track 80

ip access-list extended ACL_TRACKED_NET
 permit ip 10.50.0.0 0.0.255.255 any

router bgp 65001
 redistribute ospf 1 route-map OSPF_TO_BGP
```

#### 検証方法
```bash
show track 80
show ip bgp neighbors 192.168.1.1 advertised-routes
! OSPF コスト変更により 10.50.0.0/16 の Metric が 200 超になった際、BGP アナウンスが停止することを確認
```

---

### ラボ 9: Object Tracking ＋ EEM Applet Triggering Failover & BGP Clear
#### 問題
WAN 回線監視用 Track が Down になった際、EEM アプレットをトリガーして BGP セッションの即時クリアとシステムログ発信を自動化します。

#### 要件
1. WAN 到達性を監視する `track 90`（`ip sla 90` 連携）を作成すること。
2. EEM アプレット `TRACK_FAILOVER` を作成し、`track 90` の `state down` をトリガーとすること。
3. 発生時に syslog メッセージを出力し、`clear ip bgp * soft` を自動実行すること。

#### 設定例
```bash
ip sla 90
 icmp-echo 203.0.113.254
 frequency 5
ip sla schedule 90 life forever start-time now

track 90 ip sla 90 reachability

event manager applet TRACK_FAILOVER
 event track 90 state down
 action 1.0 syslog msg "CRITICAL: Track 90 Down! Clearing BGP sessions."
 action 2.0 cli command "enable"
 action 3.0 cli command "clear ip bgp * soft"
```

#### 検証方法
```bash
show track 90
! 宛先 203.0.113.254 をドロップさせると、コンソールに EEM syslog が表示され、BGP セッションのソフトリセットが自動実行されることを確認
```

---

### ラボ 10: IPv6 Interface & IPv6 Route Tracking ＋ VRRPv3 Dual-Stack Failover
#### 問題
IPv6 環境において、IPv6 WAN インターフェイスおよび特定 IPv6 プレフィックスの到達性を追跡し、VRRPv3（IPv6）の切り替えを行います。

#### 要件
1. IPv6 インターフェイス Gi0/0/1 の IPv6 ルーティング状態を監視する `track 601` を作成すること。
2. IPv6 ルート `2001:db8:1000::/48` の到達性を監視する `track 602` を作成すること。
3. 両方が Up の場合のみ Up となる `track 600`（`list boolean and`）を作成すること。
4. VRRPv3 IPv6 グループ 20 において、`track 600` が Down の場合に Priority を 25 減算すること。

#### 設定例
```bash
track 601 interface GigabitEthernet0/0/1 ipv6 routing

track 602 ipv6 route 2001:db8:1000::/48 reachability

track 600 list boolean and
 object 601
 object 602
 delay down 3 up 10

fhrp version vrrp v3

interface GigabitEthernet0/0/0
 ipv6 address 2001:db8:1::2/64
 vrrp 20 address-family ipv6
  priority 115
  track 600 decrement 25
  address fe80::1 primary
  address 2001:db8:1::1/64
```

#### 検証方法
```bash
show track 600
show vrrp group 20
! IPv6 ルート 2001:db8:1000::/48 を消去すると Track 600 が Down になり、VRRPv3 IPv6 Priority が 90 へ減算されることを確認
```


## ❓ 想定試験問題

### 問 1 (コンフィグ読解)
以下のコンフィグが設定されたルータにおいて、`track 100` のステートが `Up` と判定される条件として正しい組み合わせを選択してください。

```bash
track 1 interface GigabitEthernet0/0/1 line-protocol
track 2 ip sla 10 reachability
track 3 ip sla 20 reachability

track 10 list boolean and
 object 2
 object 3

track 100 list boolean or
 object 1
 object 10
```

* **A**: Gi0/0/1 が Up であり、かつ IP SLA 10 と IP SLA 20 の両方が Up である場合のみ。
* **B**: Gi0/0/1 が Up であるか、または（IP SLA 10 と IP SLA 20 の両方が Up）である場合。
* **C**: Gi0/0/1、IP SLA 10、IP SLA 20 のうち、いずれか 1 つでも Up であれば Up。
* **D**: IP SLA 10 と IP SLA 20 のいずれか一方が Up であれば、Gi0/0/1 の状態に関わらず Up。

#### 解答・解説
**正解: B**
* `track 10` は `list boolean and` で構成されているため、`object 2` (IP SLA 10) と `object 3` (IP SLA 20) の**両方が Up** の時のみ `track 10` が Up になります。
* `track 100` は `list boolean or` で構成されているため、`object 1` (Gi0/0/1) が Up であるか、または `object 10` が Up であれば `track 100` は Up と判定されます。したがって「Gi0/0/1 が Up であるか、または (IP SLA 10 と IP SLA 20 の両方が Up)」が正解です。

---

### 問 2 (トラブルシューティング)
ネットワーク管理者は、IP SLA を用いた回線品質監視において、UDP Jitter によるパケット遅延悪化時に HSRP の切替が発生しないトラブルを調査しています。現在のコンフィグは以下の通りです。

```bash
ip sla 5
 udp-jitter 192.168.10.1 16384
 frequency 10
 threshold 40
ip sla schedule 5 life forever start-time now

ip sla reaction-configuration 5 react rtt threshold-value 40 30 threshold-type immediate

track 50 ip sla 5 reachability
```

この設定において、パケット遅延が 40ms を超えて `threshold-type immediate` に違反した際にも `track 50` が `Up` のまま維持される理由と正しい修正方法を選びなさい。

* **A**: `ip sla schedule` に `recurring` パラメータが不足しているため。
* **B**: UDP Jitter の Reaction Configuration によるしきい値判定結果を反映するには、`reachability` ではなく `state` キーワードを使用する必要がある。`track 50 ip sla 5 state` に変更する。
* **C**: HSRP 側で `hsrp 1 track 50 decrement` ではなく `hsrp 1 track 50 shutdown` を指定しなければならない。
* **D**: UDP Jitter では IP SLA Responder の認証が必須であり、認証失敗により Track が更新されない。

#### 解答・解説
**正解: B**
* `track <id> ip sla <num> reachability` は、IP SLA プローブが応答を返しているか（ICMP/UDPの成功/失敗）のみを監視します。
* `ip sla reaction-configuration` によって RTT や Jitter、パケットロスなどの「しきい値判定（Threshold Exceeded）」を行い、その状態（OverThreshold / Normal）を Track に連動させる場合は、**`track <id> ip sla <num> state`** を使用する必要があります。`reachability` のままだと、遅延がいくら悪化してもパケット応答自体があれば Up と判定され続けます。

---

### 問 3 (Design)
複数の WAN 拠点を持つ企業ネットワークにおいて、主要ルータのインターフェイスフラッピング（短時間での連続断続）が発生した際、コアバックボーンにおける BGP/OSPF ルーティングの再計算オーバーヘッドおよび HSRP の無駄な連続切替を最小限に抑えたいと考えています。Object Tracking の設計として最も推奨されるベストプラクティスはどれですか。

* **A**: Track オブジェクトの検査周期（IP SLA の `frequency`）を 1 秒以下に短縮する。
* **B**: Track オブジェクト配下に `delay down` および `delay up` タイマーを設定し、障害検知および復旧判定に猶予時間を設ける。
* **C**: トラッキングには常に `list threshold percentage` のみを使い、100% 健全な時以外は即座に Down と判定する。
* **D**: HSRP の `preempt` 設定を削除し、一度切り替わったら二度と元のルータに自動戻りしないように固定する。

#### 解答・解説
**正解: B**
* 回線やポートの Flapping による制御プレーンへの負荷やルーティングのバタつきを防止するためには、Object Tracking に **`delay down <sec> up <sec>`** タイマーを設定するのが標準的な設計ベストプラクティスです。これにより、一時的なパケットロスや短い瞬断で即座にルートや HSRP が切り替わるのを防ぎます。

---

### 問 4 (実装)
以下の要件を満たす Track List コンフィグを構築しなさい。

1. 4つの個別 Track オブジェクト（`track 1`, `track 2`, `track 3`, `track 4`）を監視すること。
2. 重み（Weight）を `track 1` = 40、`track 2` = 20、`track 3` = 20、`track 4` = 20 と設定すること。
3. 合計 Weight が 60 以上で Track List を Up、40 未満で Down と判定すること。

#### 解答・解説
**設定例:**
```bash
track 100 list threshold weight
 object 1 weight 40
 object 2 weight 20
 object 3 weight 20
 object 4 weight 20
 threshold weight up 60 down 40
```
* `list threshold weight` 構文を使用し、各 `object` 配下に `weight <value>` を指定します。
* `threshold weight up <up-val> down <down-val>` で切り替え閾値を定義します。

---

### 問 5 (トラブルシューティング)
以下の設定において、`track 30` が Down になったにもかかわらず、`ip route 0.0.0.0 0.0.0.0 192.168.1.1 track 30` がルーティングテーブルから消去されず、バックアップルートへ切り替わりません。

```bash
track 30 ip route 10.1.0.0 255.255.0.0 reachability
```

ルーティングテーブルの状態を確認したところ、以下の出力が得られました。

```text
Codes: C - connected, S - static, R - RIP, M - mobile, B - BGP
       D - EIGRP, EX - EIGRP external, O - OSPF, IA - OSPF inter area 

O        10.1.1.0/24 [110/20] via 192.168.1.1, 00:15:30, GigabitEthernet0/0/1
S*   0.0.0.0/0 [1/0] via 192.168.1.1
```

切り替えが行われない原因を説明しなさい。

#### 解答・解説
**原因と解説:**
* `track ip route` 機能は、**ルーティングテーブル（RIB）内に指定された「全く同じプレフィックスとサブネットマスク（10.1.0.0/16）」が存在するかどうか**を判定します。
* 現在の RIB に存在するルートは、より具体的なサブネットである `10.1.1.0/24` のみであり、`10.1.0.0/16` という正確な集約プレフィックス自体は最初から存在していません。
* このため、`track 30` は当初から到達不能（Down）と判定されており、障害発生前とステートが変化していないか、または設定ミスにより正しく機能していません。
* **修正方法**: RIB に実際に存在するプレフィックス `10.1.1.0 255.255.255.0` を指定するか、または IP SLA などの到達性テスト方式に変更する必要があります。

---

## 🔗 参考リソース

### Cisco 公式ドキュメント
* Cisco IOS XE 17.x IP Application Services Configuration Guide - Object Tracking
* Cisco Command Reference - track / show track Commands
* Configuring Enhanced Object Tracking - Technical Notes

### Cisco Live 資料
* BRKCRS-3147 - Advanced First-Hop Redundancy Protocols and Object Tracking
* BRKARC-2001 - Cisco IOS XE System Architecture Deep Dive

---

## 📝 補足（Notes）

* **Track オブジェクト番号の設計**: 実務やラボ試験では、Track ID を関連する VLAN ID や IP SLA ID、HSRP Group ID と統一（例: SLA 10 -> Track 10 -> HSRP 10）しておくと、デバッグやコンフィグの視認性が大幅に向上します。
* **Boolean 論理の可視化**:
  * `AND`: 1つでも 0 (Down) が入れば出力は 0 (Down)。全ポート健全性が必須な環境で使用。
  * `OR`: 1つでも 1 (Up) があれば出力は 1 (Up)。冗長化ラインの生存確認で使用。




## 🔗 参考リソース

### Cisco Live (動画・スライド)
*   [**DGTL-BRKRST-2042: Highly Available Wide Area Network Design**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2042)
    *   IP SLA とトラッキングを用いた設計ベストプラクティス。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE ラボ試験におけるトラッキング技術の重要性。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Configuring Enhanced Object Tracking**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipapp/configuration/xe-17/ipapp-xe-17-book/ipapp-eot.html)。
*   [**IP SLAs Configuration Guide, Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipsla/configuration/xe-17/sla-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Reliable Static Routing with IP SLA (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200785-Configure-IP-SLA-ICMP-Echo.html)。
*   [**HSRP Tracking and Preemption Examples**](https://www.cisco.com/c/en/us/support/docs/ip/hot-standby-router-protocol-hsrp/10583-62.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験における **「動的なネットワーク適応能力」** の構築を網羅しています。試験では、**`show track`** の結果を正確に読み解き、なぜパスが切り替わった（あるいは切り替わらなかった）のかを論理的に説明できることが合格への近道です。


