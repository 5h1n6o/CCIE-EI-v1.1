---
layout: default
title: 1.2.b-Static-routing
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.2.b Static routing (unicast, multicast)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 実技試験（Practical Exam）および筆記試験において、ネットワークインフラストラクチャの基盤でありながら、極めて高度なトラフィック制御、冗長化、障害回避のために駆使される **Static routing (unicast, multicast)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に完全準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

スタティックルーティングは、管理者が宛先ネットワークへの経路（ネクストホップIPアドレス、送出インターフェイス、あるいはその両方）を静的かつ明示的に定義するルーティング手法です。動的ルーティングプロトコル（OSPF, EIGRP, BGP等）のようなプロトコルオーバーヘッドや隣接関係（Adjacency）の維持が不要なため、CPUや帯域リソースを極限まで節約でき、極めて高い予測可能性を提供します。

### 1. Unicast Static Routing
*   **宛先特定の制御:** 単一のIPユニキャストアドレスまたはネットワークセグメントに対する固定パスを決定します。
*   **利用目的/利用場面:** 動的プロトコルを動かす必要のないインターネットゲートウェイへのデフォルトルート（`0.0.0.0/0` または `::/0`）の生成、企業境界エッジでのスタブルーティング、動的経路のバックアップ（Floating Static Route）、およびサマリーアドレス集約時のループ防止用Null0ルートの配置に使用されます。

### 2. Multicast Static Routing (IP mroute)
*   **RPFチェックの制御・上書き（Override）:** マルチキャスト転送（PIM-SM/PIM-DM/SSM）において、パケットを受信したインターフェイスが、マルチキャスト送信元（Source）へ向かう「ユニキャスト最適パス（逆経路）」と一致しているかを検証する **RPF（Reverse Path Forwarding）チェック** を静的に制御します。
*   **利用目的/利用場面:** ユニキャストルーティングの経路とは異なる物理リンクやVPNトンネルを経由してマルチキャストトラフィックを伝送したい場合、あるいはユニキャストテーブルがないVRF環境において、意図的にRPFチェックを成功（またはバイパス）させてマルチキャスト配信を可能にするために使用されます。

---

## 🔑 要点

スタティックルーティングの主要な構成要素、設計上のトレードオフ、およびプラットフォーム制限を整理します。

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 管理者が手動でルーティングテーブル（RIB）にルートを注入。デフォルトのAD（Administrative Distance）は「1」。 |
| **用途** | スタブ接続、ゲートウェイへのデフォルトルート、フローティングスタティックによる冗長設計、Null0（Discard）ルートによるループ防止。マルチキャストにおけるRPFチェックの強制変更。 |
| **メリット** | 帯域幅やルータCPUリソースの消費がゼロ。経路フラッピングが発生せず、予測可能で極めて安定。高いセキュリティ（隣接ルータから不適切な経路を学習しない）。 |
| **デメリット** | トポロジー変更（リンクダウン、ノード障害）に自律的に適応できない。手動での運用の複雑さ、特に大規模網でのスケール限界。 |
| **対応機種** | Catalyst 9000シリーズ、Catalyst 8000v、ISR/ASRシリーズを含むすべてのCisco IOS/IOS-XE/NX-OSデバイス。 |
| **制限事項** | イーサネット（Multi-access）等の共有媒体で「送出インターフェイスのみ」を指定すると、Proxy ARPへの依存や大規模なARPテーブル枯渇、パフォーマンス低下が発生。 |
| **設計上の注意点** | リンクハングや中間L2スイッチ障害によるサイレントダウンに対応するため、**IP SLAおよび Object Tracking** との完全な統合設計が必須。 |

---

## 🏗 動作原理

### 1. スタティックルートのネクストホップ解決メカニズム（Recursive vs Direct vs Fully Specified）
スタティックルートを構成する際、ネクストホップの指定方法によってルータのRIBルックアップ動作およびパケット処理プロセスが根本的に変化します。

#### ① Next-hop IP Only (Recursive Static Route)
宛先への経路指定として「ネクストホップIPアドレスのみ」を指定します。
```text
[ 配置コマンド ]
ip route 10.1.1.0 255.255.255.0 192.168.12.2
```
*   **ルックアップ動作:**
    ルータは宛先 `10.1.1.0/24` にパケットを送信する際、まず `192.168.12.2` へ到達するための送出インターフェイスをルーティングテーブル内で**再帰的（Recursive）**に検索します。
    もし、`192.168.12.2` が `192.168.12.0/24`（Gi0/1直結ルート）に合致すれば、送出インターフェイスは `Gi0/1` であると解決されます。
    *   **CCIEレベルの注意:** 再帰的ルートは、ネクストホップへ到達可能である限りRIB上で「UP」を維持します。もし、ネクストホップへの到達性が動的ルート（OSPFなど）で失われた場合、スタティックルートも動的にRIBから削除（Withdraw）されます。

```
[ Recursive Lookup Flow ]
Packet to: 10.1.1.5
   ↓
RIB Lookup: 10.1.1.0/24 -> Next-hop is 192.168.12.2
   ↓
Recursive RIB Lookup: 192.168.12.2 -> Matches Direct Route 192.168.12.0/24 via GigabitEthernet0/1
   ↓
ARP Resolution for 192.168.12.2 on Gi0/1
   ↓
Encapsulate & Send out of GigabitEthernet0/1
```

#### ② Egress Interface Only (Directly Connected Static Route)
宛先への経路指定として「送出インターフェイスのみ」を指定します。
```text
[ 配置コマンド ]
ip route 10.1.1.0 255.255.255.0 GigabitEthernet0/1
```
*   **ルックアップ動作及び深刻なリスク:**
    ルータは宛先 `10.1.1.0/24` が **「GigabitEthernet0/1に直接接続されている（Directly Connected）」** と見なします。
    パケットを送信する際、ルータはパケットの「最終宛先IPアドレス（例：`10.1.1.5`）」に対して、Gi0/1上で**直接ARP解決**を試みます。
    *   **Proxy ARPへの致命的な依存:** 対向のルータにおいて **Proxy ARPが有効（Ciscoのデフォルトは `ip proxy-arp`）** でなければ、パケットは一切フォワーディングされずドロップされます。
    *   **ARPテーブルの肥大化:** 宛先IPごとに個別のARPエントリが自ルータのメモリ（ARPテーブル）に生成されるため、サブネット全体（例：`/16` などの広いレンジ）に対してこれを設定すると、メモリが瞬時に枯渇してルータがクラッシュするか、高負荷（CPU 100%）に陥ります。
    *   **適用条件:** この設定が許容されるのは、Point-to-Point（PPPoE、GREトンネル、HDLC/PPP）などの「対向に1台しか存在しないシリアルライクなインターフェイス」に限られます。

#### ③ Fully Specified Route (完全特定ルート)
送出インターフェイスとネクストホップIPアドレスの「両方」を明示的に指定します。
```text
[ 配置コマンド ]
ip route 10.1.1.0 255.255.255.0 GigabitEthernet0/1 192.168.12.2
```
*   **動作仕様:**
    再帰ルックアップを完全にスキップ（1回のルックアップで解決）しつつ、Proxy ARPに依存せず、確実に `192.168.12.2` に対してARP解決を試みるため、イーサネット環境において最もセキュアで高速なスタティックルーティングを提供します。

---

### 2. IP mroute による RPF チェックの上書き動作原理
マルチキャストルーティングにおけるスタティックマルチキャストルート（`ip mroute`）は、**「マルチキャストデータの転送経路を変更するものではなく、送信元（Source）へ向かうリバースパス（RPF）を静的に書き換える」** という動作原則を持っています。

```
 [ Multicast Source: 172.16.1.100 ]
                │
                ├──► [ WAN Link A ] (Unicast Best Path / OSPF Route) ──► [ SW1 ]
                │                                                          ▲ RPF Check Fails!
                │                                                          │ (No Unicast Route here)
                └──► [ WAN Link B ] (Dedicated Multicast VPN) ─────────────┘
                                      - SW1で以下を構成:
                                        ip mroute 172.16.1.0 255.255.255.0 Tunnel10
                                      - これにより Tunnel10 から入るマルチキャストデータの RPFチェックが強制パス！
```

*   **RPFチェック判定ロジックにおける優先順位:**
    マルチキャストパケット（S, G）を受信した際、ルータは送信元IP「S」に対するルーティング検索を実行し、パケットが到着したインターフェイスが最適パスであるか（RPFインターフェイスであるか）を以下の優先順位で点検します。
    1.  **スタティックマルチキャストルート（`ip mroute`）** ➔ 最優先（AD 0 でマルチキャストルーティングテーブルに挿入）
    2.  **DVMRP 経路**
    3.  **MBGP（Multiprotocol BGP）マルチキャストのアドレステーブル**
    4.  **標準のユニキャストルーティングテーブル（OSPF, EIGRP, Static 等）**
    
    `ip mroute` が定義されている場合、ユニキャストの最適ルート（例：WAN Link A）を完全にバイパスし、指定したインターフェイス（例：WAN Link B / Tunnel10）をRPFインターフェイスとして強制バインドし、チェックを成功させてマルチキャストツリー（OIL: Outgoing Interface List）へパケットをフォワーディングさせます。

---

## ⚙ 動作シーケンス

### ユニキャストスタティックルーティングのパケット処理シーケンス

パケットがルータの入力インターフェイスに到着してから、FIB（Forwarding Information Base）/CEF（Cisco Express Forwarding）を介して転送されるまでの内部ASIC・コントロールプレーンの処理フローです。

```
[ インプレス物理ポートにパケット到着 ]
       │
       ▼
[ L2フレームヘッダーの検証（FCS、宛先MACアドレスが自ルータのMACか確認）]
       │
       ├─► 一致しない ➔ 【破棄（Drop）またはブリッジ処理】
       └─► 一致 ➔ L2ヘッダーを除去し、L3 IP処理エンジンへ受け渡し
       │
       ▼
[ IPヘッダー検証（TTLのデクリメント、チェックサム計算、宛先IPのFIBルックアップ）]
       │
       ▼
[ FIB / CEF テーブル（ASICハードウェア）における宛先IPの検索 ]
       │
       ├─► 宛先が「Null0」スタティックルートにマッチ
       │        └─► 【パケットを即時廃棄（Discard）】、必要に応じてICMP Destination Unreachable送信
       │
       ├─► 宛先が「直接接続（Fully Specified or Interface specified）」スタティックルートにマッチ
       │        └─► ハードウェア隣接テーブル（Adjacency Table）を参照し、対向のMACアドレスを直接バインド
       │
       └─► 宛先が「再帰ネクストホップ（Recursive）」スタティックルートにマッチ
                └─► コントロールプレーンが構築したCEFツリーにより、ハードウェアレベルで再帰解決済みの
                    最終送出ポートとネクストホップMACがすでにFIBにロードされているため、
                    1クロックサイクルで物理送出ポートへマッピング
       │
       ▼
[ 送出インターフェイスのMTU検証およびL2カプセル化 ]
       │
       ▼
[ アウトプレスポジション（物理回線への送出）]
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、スタティックルーティングはインフラ構築の最下層に配置されます。そのため、非常にトリッキーな要件を組み合わせた「配点の隠れたトラップ」として高頻度で狙われます。

### 1. イーサネットインターフェイスでの Proxy-ARP 無効化罠
*   **出題パターン:**
    「ルータR1とR2の間は、GigabitEthernet0/1を介したイーサネット網で接続されている。R1において、R2の背後にある `172.16.100.0/24` へのスタティックルートを設定せよ。ただし、いかなる場合もR2側での **Proxy-ARP 機能に依存しないルーティング設定** とし、R1のARPテーブルが `172.16.100.0/24` 内の個々のホストIPアドレスで汚染されることを完全に防ぐこと」
    *   **誤った設定（不合格）:**
        ```bash
        ip route 172.16.100.0 255.255.255.0 GigabitEthernet0/1
        ```
        この設定はR2側で `no ip proxy-arp` が投入されているか、あるいは試験中の別の硬化セキュリティセクションでProxy-ARPを無効化させられた瞬間に、通信が完全に途絶してルーティングセクション全体が「0点」になります。
    *   **正しい対策（完全特定、またはネクストホップIP指定）:**
        ```bash
        # 対策A: 完全特定（Fully Specified）
        ip route 172.16.100.0 255.255.255.0 GigabitEthernet0/1 192.168.12.2
        # 対策B: ネクストホップIPのみ（Recursive）
        ip route 172.16.100.0 255.255.255.0 192.168.12.2
        ```

### 2. IP SLA & Object Tracking とフローティングスタティックの統合設計
スタティックルートにはリンクダウンを自動検知して経路を削除する自律コンバージェンス機能がありません。そのため、中間にL2スイッチやメディアコンバーター（ONU等）が混在していると、対向側のポートやリモートノードがダウンしていても、自ルータの物理ポート（Gi0/1）は「UP/UP」を維持してしまい、パケットをダウンしたパスへ流し続ける **「ブラックホール（Blackhole）」** が発生します。

*   **試験での実装要件:**
    「プライマリのデフォルトルートをR1経由（192.168.12.2）とし、バックアップのデフォルトルートをR3経由（192.168.13.3）に設定せよ。プライマリリンクの中間にL2スイッチが存在するため、R1（192.168.12.2）への実際のデータプレーン疎通性（ICMPエコー）を3秒間隔で常時監視し、パケットが連続して2回消失した場合は自動的にプライマリデフォルトルートをRIBから削除し、バックアップルートへ切り替えなさい」
    *   **実装ステップ:**
        1.  IP SLAプローブの定義
        2.  SLAスケジューラの起動（アクティブ化）
        3.  Object TrackingによるSLAステータスの監視バインド
        4.  スタティックルートへのTrackオブジェクトのアソシエーション結合、およびフローティングスタティック（AD 10等）の配置
    *   **コマンドフロー:**
        ```bash
        # 1. IP SLA 定義
        ip sla 1
         icmp-echo 192.168.12.2 source-interface GigabitEthernet0/1
         threshold 1500
         timeout 2000
         frequency 3
        exit
        
        # 2. SLA 起動
        ip sla schedule 1 life forever start-time now
        
        # 3. Object Tracking 定義 (SLA 1 の State を追跡)
        track 10 ip sla 1 state
         delay down 6 up 0   # 2回消失（3秒×2＝6秒遅延）を表現
        exit
        
        # 4. トラッキング付きデフォルトルート ＋ バックアップルート（AD 10）
        ip route 0.0.0.0 0.0.0.0 192.168.12.2 track 10
        ip route 0.0.0.0 0.0.0.0 192.168.13.3 10
        ```

### 3. Null0 ルートとダイナミックプロトコルの再配送（ループ防御）
*   **試験の罠:**
    「R1において、自身が保有する複数の内部ネットワークセグメントを `10.10.0.0/16` に集約し、BGPまたはOSPFプロセスへ再配送（またはネットワークアドバタイズ）しなさい。ただし、自機宛てのパケットの中に、現在実際に存在しないセグメント（例：10.10.99.0/24等）宛てのトラフィックが入力された場合、上位ISPルータとの間でデフォルトルートを介した **パケットの無限バウンスループ（無限ピンポンループ）** が発生するのを完全に防止するスタティックルートを構成せよ」
    *   **対策（Null0 ディスカードスタティックの配置）:**
        ```bash
        ip route 10.10.0.0 255.255.0.0 Null0
        ```
        このNull0スタティックルートを設定することで、集約内の「実際に稼働していないセグメント宛て」のパケットをルータ自身がハードウェア（ASIC）レベルでドロップ（Null0廃棄）し、上位ルータ（デフォルトルート）へパケットをバウンスバックして発生するループを完全に防止します。

### 4. VRF-Lite 環境における Inter-VRF Static Route Leaking（VRFリーク）
SD-Accessファブリック境界（Border）やVRF-Liteのマルチテナント環境において、共通サービス（共通DNS、共通認証サーバー等）が配置されている「Shared VRF」へ、各テナントの「Tenant VRF」からスタティックルートを用いて経路をリークさせる設計が要求されます。

*   **試験での指示:**
    「VRF `TENANT_A` から、VRF `COMMON_SERVICE` に属するサーバーセグメント `192.168.50.0/24` へのルーティングを提供しなさい。BGPやOSPFなどの動的ルートマップリークは使用せず、スタティックルートのみを用いてシンプルに実装すること」
    *   **IOS-XEにおける正確な構文:**
        ```bash
        ip route vrf TENANT_A 192.168.50.0 255.255.255.0 GigabitEthernet0/2 vrf COMMON_SERVICE 192.168.1.254
        ```
        *   **構文ルール:** `ip route vrf [ソースVRF] [宛先IP] [マスク] [送出インターフェイス] vrf [ターゲットVRF] [ターゲットVRF内のネクストホップIP]`
        *   **注意点:** 送出インターフェイスとターゲットVRFネクストホップの指定順序が逆になったり、インターフェイス記述が漏れるとリークが成立しないため、実機CLIでの入力順を完全にマスターしておく必要があります。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における、各種高度なスタティックルーティングの実践設定手順です。

### 1. IPv4 / IPv6 基本ユニキャストスタティックルート（Recursive / Fully Specified）

```bash
# [IPv4 ネクストホップ指定（Recursive）]
ip route 172.16.10.0 255.255.255.0 192.168.12.2

# [IPv4 完全特定（Fully Specified - 推奨）]
ip route 172.16.20.0 255.255.255.0 GigabitEthernet0/1 192.168.12.2

# [IPv6 ネクストホップ指定]
ipv6 route 2001:db8:10::/64 2001:db8:12::2

# [IPv6 完全特定]
ipv6 route 2001:db8:20::/64 GigabitEthernet0/1 2001:db8:12::2
```

### 2. フローティングスタティック（Floating Static - ADチューニング）

```bash
# プライマリデフォルトルート（AD 1 - デフォルト）
ip route 0.0.0.0 0.0.0.0 192.168.12.2

# バックアップデフォルトルート（AD 200 に引き上げてスタンバイ化）
ip route 0.0.0.0 0.0.0.0 192.168.13.3 200

# IPv6 フローティングスタティック（AD 200）
ipv6 route ::/0 2001:db8:13::3 200
```

### 3. IP SLA ＆ Object Tracking 統合デフォルトルート

```bash
# 1. ICMP エコーによる監視の定義
ip sla 10
 icmp-echo 192.168.12.2 source-interface GigabitEthernet0/1
 timeout 1000
 frequency 5
exit

# 2. SLA プローブのスケジューリング
ip sla schedule 10 life forever start-time now

# 3. Object Tracking の作成（SLA 10 の状態と遅延の定義）
track 1 ip sla 10 state
 delay down 10 up 5
exit

# 4. トラッキング付きプライマリルートとバックアップルートの設定
ip route 0.0.0.0 0.0.0.0 192.168.12.2 track 1
ip route 0.0.0.0 0.0.0.0 192.168.13.3 200
```

### 4. VRF-Aware ユニキャストスタティックルート（VRF定義 ＋ インターVRFリーク）

```bash
# [同一VRF内でのユニキャストスタティックルート]
ip route vrf TENANT_A 10.10.10.0 255.255.255.0 192.168.100.2

# [VRF TENANT_A から グローバルルーティングテーブルへのリーク（Shared Internetアクセス等）]
# (※globalキーワードを指定することで、グローバルテーブルのネクストホップを参照させます)
ip route vrf TENANT_A 0.0.0.0 0.0.0.0 GigabitEthernet0/1 global 203.0.113.1

# [VRF TENANT_A から VRF COMMON_SERVICE への相互リーク設定]
ip route vrf TENANT_A 192.168.50.0 255.255.255.0 GigabitEthernet0/2 vrf COMMON_SERVICE 192.168.1.254
```

### 5. Multicast Static Route (ip mroute) による RPF オーバーライド

```bash
# マルチキャストルーティングプロセスの有効化
ip multicast-routing distributed

# 特定のマルチキャスト送信元（172.16.1.100）に対する RPF インターフェイスを Tunnel50 に強制バインド
ip mroute 172.16.1.100 255.255.255.255 Tunnel50

# IPv6 マルチキャストスタティックルート（mroute）
ipv6 multicast-routing
ipv6 mroute 2001:db8:99::100/128 Tunnel50
```

---

## 🔍 検証コマンド

スタティック経路のRIB挿入状態、CEF解決状態、Object Tracking状態、およびマルチキャストRPFチェックのステータスを確認・検証するための必須コマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **ルーティングテーブル内のスタティックルートのみをフィルタして一覧表示** | <code>show ip route static</code> / <code>show ipv6 route static</code> |
| **特定のVRF（TENANT_A）におけるスタティックルート一覧の確認** | <code>show ip route vrf TENANT_A static</code> |
| **FIB / CEF（Cisco Express Forwarding）における再帰解決結果、送出ポート、隣接MACのハードウェア解決状態の確認** | <code>show ip cef 172.16.10.0 detail</code> |
| **IP SLA監視プローブの最新の成功/失敗ステータス、RTT（応答時間）の確認** | <code>show ip sla statistics</code> / <code>show ip sla history</code> |
| **Object Tracking（Track 1）の現在のアクティブ状態（UP / DOWN）の確認** | <code>show track 1</code> |
| **特定の送信元に対するマルチキャストRPFチェックの判定インターフェイス、および「mroute」が適用されているかの確認** | <code>show ip rpf 172.16.1.100</code> |
| **マルチキャストルーティングテーブルにおける（S,G）エントリーとRPFネイバー、受信ポート状態の確認** | <code>show ip mroute 224.1.1.1</code> |
| **RIBおよびFIBテーブルへのスタティックルートの挿入・削除プロセスのリアルタイムデバッグ** | <code>debug ip routing</code> / <code>debug ip cef table</code> |

---

## 🚨 トラブルシュート

実機演習やラボ試験で遭遇する主要なスタティックルート関連のトラブルシナリオと、Expertとしての解決フローです。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`ip route` コマンドで設定を流し込んだが、`show ip route` を実行してもルーティングテーブル（RIB）に経路が一切表示されない。** | 1. 指定した送出インターフェイスが物理的に **`shutdown` 状態**になっている。<br>2. 指定したネクストホップIPアドレスへの**到達パス（Route）がルーティングテーブル上に存在しない**（Recursive解決の失敗）。 | <code>show ip route [ネクストホップIP]</code><br><code>show interfaces [ポート名]</code> | 1. 送出物理ポートの `no shutdown` を実行してリンクをアップさせる。<br>2. ネクストホップへの解決ルート（直結ルートや動的ルート）がRIBに存在するか確認し、ネクストホップのIP指定ミスを修正する。 |
| **デフォルトルートをIP SLA / Track 1でトランキング冗長化したが、プライマリ回線がダウン（R1へのICMP応答停止）しても、スタティックルートがRIBから削除されず、切り替わらない。** | **スタティックルートに `track [ID]` オプションの結合設定が抜けている**。単に SLA と Track オブジェクトを作っただけでは、ルーティングテーブルのバインドは成立しません。 | <code>show running-config \| include ip route</code><br><code>show track 1</code> | スタティックデフォルトルートの末尾に、作成したオブジェクトIDを明示的に指定して設定を上書きする。<br><code>ip route 0.0.0.0 0.0.0.0 192.168.12.2 track 1</code> |
| **イーサネットポートに対して「インターフェイスのみ」を指定したスタティックルートを設定したが、パケットが全く転送されない（ドロップする）。** | 対向ルータのインプレスインターフェイスにおいて、**Proxy ARP（`ip proxy-arp`）が明示的に無効化されている**ため、最終宛先ホスト宛てのARP要求に誰も応答していない。 | <code>show arp</code><br><code>show ip interface [ポート名]</code> | イーサネット等の共有マルチアクセス環境では、インターフェイス指定を止め、ネクストホップIPアドレス（または完全特定形式）に書き換える。<br><code>ip route 10.1.1.0 255.255.255.0 192.168.12.2</code> |
| **VRFテナントから共通サービス（Shared）宛てへのリークスタティックルートを設定したが、双方向の通信が成立しない（一方通行で戻ってこない）。** | スタティックルートのリーク（Inter-VRF Leaking）における典型的な **「戻り経路の定義忘れ」**。TENANT_AからCOMMON_SERVICEへのリークだけでなく、COMMON_SERVICEからTENANT_Aへの戻りスタティックルートが定義されていない。 | <code>show ip route vrf TENANT_A</code><br><code>show ip route vrf COMMON_SERVICE</code> | ターゲット側VRFからも、ソース側VRFの送信元ネットワークセグメントに対する「逆方向のリークスタティックルート」を正確に定義して双方向ルーティングを確立する。 |
| **マルチキャスト送信元（S）からの映像配信を受信しているが、パケットがフォワーディングされない。Syslogに「RPF check failed」が記録される。** | ユニキャストの最適ルーティング（OSPF等）が、マルチキャスト配信用ではない対向ポート（Tunnel等）を向いており、マルチキャストパケットが別ルートから届いているため、RPFの検証で不正（Drop）と判定されている。 | <code>show ip rpf [送信元IP]</code><br><code>show ip mroute</code> | `ip mroute` を使用して、実際にマルチキャストデータが流入してくる物理ポート（またはトンネル）をRPFインターフェイスとして強制指定するスタティックRPFオーバーライドを投入する。<br><code>ip mroute [送信元IP] [マスク] [流入ポート]</code> |

---

## ⚠ 制限事項

### 1. イーサネット（Multi-access）での「インターフェイス指定のみ」の絶対的禁忌
*   前述の通り、イーサネットセグメントでインターフェイスのみを指定すると、対向デバイスの Proxy-ARP 機能に100%依存します。セキュリティ上の観点（ARP Spoofing攻撃対策）から現代のネットワークデザインでは Proxy-ARP を無効化（`no ip proxy-arp`）することがデファクトスタンダードであり、この制限により通信断が発生します。

### 2. 再帰深度（Recursion Depth）のハードウェア制限
*   Cisco IOS-XEでは、ネクストホップの再帰解決（Recursive lookup）は最大で **3段階（Depth 3）** までしか許容されません。
    *   例：AのネクストホップがB、BのネクストホップがC、CのネクストホップがD、DのネクストホップがE（直結）のような超多段のスタティックネストを構成すると、ASICのCEFツリー生成エンジンが解決を諦め、RIBに経路が挿入されても「FIB（ハードウェア転送ベース）未解決ルート」として処理され、CPUソフトウェア転送に落ちるかドロップされます。

### 3. IPv6 Link-Local アドレス使用時の制限（送出インターフェイス必須ルール）
*   IPv6スタティックルートにおいて、ネクストホップに **リンクローカルアドレス（`fe80::/10`）** を指定する場合、リンクローカルアドレスは同一物理リンク上のすべてのルータで重複して存在し得るため、**必ず「送出インターフェイス」と「リンクローカルネクストホップIP」の両方を同時に指定（Fully Specified形式）しなければなりません。** ネクストホップIPのみの指定は文法的にエラーとなり却下されます。
    *   **正しい設定:** `ipv6 route 2001:db8:99::/64 GigabitEthernet0/1 fe80::2`
    *   **誤った設定:** `ipv6 route 2001:db8:99::/64 fe80::2`

---

## 🔄 他技術との関連

*   **VRF-Lite:**
    スタティックルートは、各仮想ルーティングテーブル（VRF）インスタンス内に隔離して定義できます（`ip route vrf ...`）。VRF間の安全な境界通信（共通サービス共有、インターネットシェアリング）において、動的プロトコルを動かさずにスタティックルートをリークさせる構成が最も多用されます。
*   **IP SLA & Object Tracking:**
    スタティックルートの最大の弱点である「トポロジー追従性のなさ」を完全に補完し、ICMP、UDP、TCPプローブによる実際のデータプレーンの品質（遅延、パケットロス、疎通性）に応じた、スタティックルートのRIB自動脱着を司ります。
*   **Policy-Based Routing (PBR):**
    PBRにおいて、宛先だけでなく送信元やポート番号に基づいてトラフィックをバイパス（強制転送）する際、設定する `set ip next-hop` や `set interface` の宛先をスタティックルートの解決と整合させる必要があります。
*   **動的ルーティングプロトコル（再配送）:**
    拠点境界ルータ（CE）やDMVPNハブにおいて、定義したデフォルトルートやスタックルートを動的プロトコル（EIGRP, OSPF, BGP）へ **再配送（Redistribute）** してドメイン全体へ配信します。この際、再配送側でデフォルトメトリック（シードメトリック）を正確に定義しないと、OSPF等で経路が再配送されず「スタティック未伝搬」となるトラブルが発生します。

---

## 🧩 比較表

### 1. ネクストホップ指定方法の徹底比較（Unicast Static）

| 比較要素 | ネクストホップ IP のみ指定 (Recursive) | 送出インターフェイスのみ指定 (Directly Connected) | 完全特定 (Fully Specified) |
| :--- | :--- | :--- | :--- |
| **ルックアップ回数** | **2回**（宛先解決 ＋ ネクストホップ自体の直結解決） | **1回**（インターフェイスへ直結されているとみなして解決） | **1回**（直接指定のため、再帰解決が不要） |
| **Proxy ARP の必要性** | **不要**（ネクストホップルータがARP応答するため） | **必須**（対向ルータが Proxy-ARP 応答しなければ不通） | **不要**（指定IPに対して直接ARP解決するため） |
| **ARP テーブルへの影響** | 最小限（ネクストホップ宛ての1エントリのみ） | **壊滅的（肥大化）**（宛先ホストIPごとに個別ARPエントリ生成） | 最小限（ネクストホップ宛ての1エントリのみ） |
| **最適セグメント** | 任意のインターフェイス（P2P、マルチアクセス両方） | **Point-to-Point（GRE、シリアル）限定**。イーサネットでは絶対厳禁。 | **イーサネット（マルチアクセス）網における最高・最速のベストプラクティス** |

### 2. ユニキャストスタティックルート vs マルチキャストスタティックルート（mroute）

| 比較要素 | Unicast Static Route (`ip route`) | Multicast Static Route (`ip mroute`) |
| :--- | :--- | :--- |
| **転送プレーン** | ユニキャストデータプレーン | **マルチキャストコントロールプレーン（RPFチェック専用）** |
| **RIBへの挿入対象** | `show ip route`（ユニキャストルーティングテーブル） | `show ip mroute` / `show ip rpf`（マルチキャストRPFテーブル） |
| **主な目的** | パケットの物理的なフォワーディングネクストホップ（Destination Forwarding）を決定。 | 流入マルチキャストパケットの**送信元方向（Reverse Path）**を検証し、RPFチェックを強制成功させる。 |
| **デフォルト AD** | **`1`** | **`0`**（ユニキャストテーブルよりも常に優先してRPF評価させる仕様） |

---

## 💡 ベストプラクティス

1.  **マルチアクセス（イーサネット）では常に「完全特定（Fully Specified）」形式を採用する:**
    再帰ルックアップのASICオーバーヘッドを排除し、かつProxy-ARPの脆弱性を完全に回避するため、Catalystスイッチ間をスタティックルートで結ぶ際は、インターフェイスとネクストホップIPを併記する。
2.  **サマリーアドレス集約時には、必ず「Null0 廃棄スタティック」をバインドする:**
    `ip route 10.0.0.0 255.0.0.0 Null0` のようなディスカードスタティックルートを必ず定義し、存在しない社内宛てパケットがインターネットデフォルトゲートウェイとの間でTTLが切れるまで無限ループする現象をASICレベルで防御する。
3.  **L2網が混在するデフォルトゲートウェイ構成では、IP SLA/Trackを「必須バインド」とする:**
    物理インターフェイスのリンク状態（UP/UP）のみに頼るスタティック設計は、中間L2ノード障害時に完全なサイレント通信ダウン（ブラックホール）を招く。必ずエンドツーエンドのIP SLA監視をObject Trackingで連動させる。
4.  **BGP / OSPF へのスタティック再配送時は「Tag（タグ）」を付与してループを防止する:**
    スタティックルートを動的ルーティングプロトコルに再配送して流し込む際は、`tag 100` などの識別タグを付与し、逆方向の境界ルータでそのタグを検知して再吸い込み（再々配送ループ）をブロックするルートマップポリシーを徹底する。

---

## 📝 ラボ学習・設定サンプル例

※ 本設定サンプルは、Cisco IOS-XE 17.xをベースとしており、CCIE EI実技試験の構成要件を網羅した、省略なしの完全出力構成です。

### 1. 浮動スタティックルート（Floating Static Route）による動的OSPFパスのバックアップ
**【問題】**
R1において、普段はOSPFエリア0経由で学習する `10.100.100.0/24` への経路を、プライマリリンク障害時に自動的にスタティックデフォルトゲートウェイ（R2経由：`192.168.12.2`）へ迂回させてください。スタティックルートはOSPF（AD 110）よりも優先度を下げて構成してください。

**【R1 設定】**
```bash
R1# configure terminal
# OSPF（AD 110）よりもAD値を「120」に引き上げてフローティング化
ip route 10.100.100.0 255.255.255.0 GigabitEthernet0/1 192.168.12.2 120
R1(config)# end
```

**【検証方法】**
```bash
R1# show ip route 10.100.100.0
# 通常時は OSPF (AD 110) がRIBに挿入されていることを確認します。
# 対向の OSPF ポートを shutdown させ、同コマンドでスタティックルート (AD 120) がRIBに浮上（Floating）してくることを検証します。
```

---

### 2. イーサネット完全特定（Fully Specified）による Proxy-ARP 依存の排除
**【問題】**
R1の `GigabitEthernet0/2`（マルチアクセスネットワーク、自機IP: `192.168.1.1`）から、R2（IP: `192.168.1.2`）の背後にある `172.16.50.0/24` へのスタティックルートを設定します。対向ルータR2で Proxy ARP（`no ip proxy-arp`）が構成されていても、ARPテーブルの汚染を防ぎつつ、通信が100%成立する完全特定ルートを構成してください。

**【R1 設定】**
```bash
R1# configure terminal
# インターフェイスとネクストホップIPを両方指定してARP解決をR2に固定
ip route 172.16.50.0 255.255.255.0 GigabitEthernet0/2 192.168.1.2
R1(config)# end
```

---

### 3. IP SLA ＆ Object Tracking 統合による自律コンバージェンススタティックデフォルト
**【問題】**
R1において、プライマリデフォルトルートを `192.168.12.2`（Gi0/1経由）、バックアップを `192.168.13.3`（Gi0/2経由、AD 210）とします。
プライマリリンクの信頼性を、3秒間隔のICMPエコー（宛先: `192.168.12.2`、タイムアウト: 1000ms）で監視し、プローブが連続して3回失敗（3秒×3＝9秒）した段階で自動的にプライマリスタティックルートを RIB から脱着（Withdraw）させるトラッキングを設定してください。

**【R1 設定】**
```bash
R1# configure terminal
# 1. IP SLAの定義
ip sla 10
 icmp-echo 192.168.12.2 source-interface GigabitEthernet0/1
 timeout 1000
 frequency 3
exit

# 2. SLAのスケジュール起動
ip sla schedule 10 life forever start-time now

# 3. Object Tracking の作成（3回連続失敗を反映するため、down遅延に9秒を定義）
track 1 ip sla 10 state
 delay down 9 up 0
exit

# 4. スタティックルートへの追跡の紐付け
ip route 0.0.0.0 0.0.0.0 GigabitEthernet0/1 192.168.12.2 track 1
ip route 0.0.0.0 0.0.0.0 GigabitEthernet0/2 192.168.13.3 210
R1(config)# end
```

**【検証方法】**
```bash
R1# show ip sla statistics
# 最新プローブ結果が「OK」であることを確認。
R1# show track 1
# Track 1 の状態が「UP」であることを確認。
R1# show ip route 0.0.0.0
# RIB上に 192.168.12.2 経由のデフォルトルートが存在することを確認。対向でICMPを遮断し、9秒後にバックアップに切り替わることを検証します。
```

---

### 4. IPv6 リンクローカルアドレス（Link-Local）を使用した完全特定スタティック
**【問題】**
R1において、IPv6 の宛先セグメント `2001:db8:abc::/64` へのスタティックルートを設定してください。ネクストホップとしてR2のリンクローカルアドレス `fe80::2` を指定し、重複による不通を防ぐ正しい完全特定構文を構成してください。送出インターフェイスは `GigabitEthernet0/3` とします。

**【R1 設定】**
```bash
R1# configure terminal
# IPv6 ユニキャストルーティングプロセスの有効化
ipv6 unicast-routing
# リンクローカル宛ては必ず送出ポートの併記が必須
ipv6 route 2001:db8:abc::/64 GigabitEthernet0/3 fe80::2
R1(config)# end
```

---

### 5. VRF-Lite 環境におけるテナント毎のスタティックアイソレーション
**【問題】**
R1において、VRF `TENANT_RED` および VRF `TENANT_BLUE` を作成します。
*   `TENANT_RED` のデフォルトルート ➔ `GigabitEthernet0/1` から ネクストホップ `192.168.11.2` 宛て。
*   `TENANT_BLUE` のデフォルトルート ➔ `GigabitEthernet0/2` から ネクストホップ `192.168.22.2` 宛て。
それぞれが論理的に完全に隔離（アイソレーション）された状態で、スタティックデフォルトを構成してください。

**【R1 設定】**
```bash
R1# configure terminal
# VRFの定義
vrf definition TENANT_RED
 address-family ipv4
 exit-address-family
exit
vrf definition TENANT_BLUE
 address-family ipv4
 exit-address-family
exit

# 物理ポートのVRFバインド
interface GigabitEthernet0/1
 vrf forwarding TENANT_RED
 ip address 192.168.11.1 255.255.255.0
 no shutdown
exit
interface GigabitEthernet0/2
 vrf forwarding TENANT_BLUE
 ip address 192.168.22.1 255.255.255.0
 no shutdown
exit

# VRFスタティックルートの配置
ip route vrf TENANT_RED 0.0.0.0 0.0.0.0 GigabitEthernet0/1 192.168.11.2
ip route vrf TENANT_BLUE 0.0.0.0 0.0.0.0 GigabitEthernet0/2 192.168.22.2
R1(config)# end
```

---

### 6. VRF Leaking（VRF間ルートリーク）スタティックルーティング
**【問題】**
R1において、VRF `TENANT_RED` に属するホスト（`10.10.10.0/24`）から、共通サービス用 VRF `COMMON_SERVICES` 内に配置されたDNSサーバーセグメント `192.168.100.0/24`（ネクストホップIP: `192.168.100.254`、Gi0/3経由）へのルーティングリークを構成してください。また、双方向通信が成立するように逆方向の戻りリークルートも構成してください。テナント側戻りネクストホップは `10.10.10.1`（Gi0/4経由）とします。

**【R1 設定】**
```bash
R1# configure terminal
# テナントから共通サービスへの行きルーティング（COMMONへリーク）
ip route vrf TENANT_RED 192.168.100.0 255.255.255.0 GigabitEthernet0/3 vrf COMMON_SERVICES 192.168.100.254

# 共通サービスからテナントへの帰りルーティング（REDへリーク）
ip route vrf COMMON_SERVICES 10.10.10.0 255.255.255.0 GigabitEthernet0/4 vrf TENANT_RED 10.10.10.1
R1(config)# end
```

**【検証方法】**
```bash
R1# show ip route vrf TENANT_RED static
R1# show ip route vrf COMMON_SERVICES static
# 互いのVRF内に、リークされたスタティックエントリーが、相手のVRFアソシエーションと共に解決されていることを確認します。
```

---

### 7. ループ防止のための Null0 ディスカードスタティックルートと OSPF 再配送
**【問題】**
R1は社内セグメント `172.16.0.0/24` から `172.16.31.0/24` のネットワークを保有しています。
R1において、これらを `172.16.0.0/19`（集約アドレス）にまとめ、OSPFプロセス 1 に外部タイプ2（E2）ルートとして再配送させてください。また、実際には存在しないセグメント宛てのパケットによる無限バウンスループをASICレベルで防御するスタティックルートを同時に構成してください。

**【R1 設定】**
```bash
R1# configure terminal
# Null0 ディスカードスタティックによるループシールドの構築
ip route 172.16.0.0 255.255.224.0 Null0

# OSPFプロセスの起動とスタティック再配送
router ospf 1
 redistribute static subnets metric-type 2
R1(config-router)# end
```

---

### 8. Multicast Static Route（ip mroute）による RPF 失敗の完全回避
**【問題】**
SW1において、ユニキャストルーティング（OSPF）は、送信元 `10.1.99.100` へ向けて `GigabitEthernet1/0/1`（メインリンク）を最適ルートと解決しています。しかし、マルチキャストのストリーム映像パケットは、明示的にマルチキャスト専用トンネルである `Tunnel50` からのみ転送されてきます。
このため、現在の状態では RPFチェックが失敗（RPF interface mismatch）となりパケットがドロップしてしまいます。
`ip mroute` を使用して、送信元 `10.1.99.100` に対する RPFチェックが `Tunnel50` を通過した際にのみ成功（オーバーライド）するように構成してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# マルチキャストルーティングプロセスの起動
ip multicast-routing distributed

# RPFオーバーライド（送信元アドレス、マスク、RPFチェック用強制インターフェイス）
ip mroute 10.1.99.100 255.255.255.255 Tunnel50
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show ip rpf 10.1.99.100
# RPF インターフェイスが、ユニキャストテーブルの Gi1/0/1 ではなく、「Tunnel50」に変更されており、さらに「RPF type: multicast (static)」と表示されていることを検証します。
```

---

### 9. BGPへのデフォルトスタティックインジェクションとTagging制御
**【問題】**
R1（AS 65001）において、デフォルトスタティックルートをNull0宛てで作成し、BGPへ再配送させてアドバタイズしてください。ただし、他の動的ルートと区別するため、このスタティックデフォルトルートに対して **Route-Tag 「65001」** を付与して作成し、再配送時にはこのタグ「65001」が付いている場合のみ再配送を許可するルートマップポリシーを定義して適用してください。

**【R1 設定】**
```bash
R1# configure terminal
# タグ「65001」を付与したNull0スタティックの作成
ip route 0.0.0.0 0.0.0.0 Null0 tag 65001

# ルートマップによるタグ判定の定義
route-map STATIC_TO_BGP permit 10
 match tag 65001
exit

# BGPへの再配送適用
router bgp 65001
 address-family ipv4 unicast
  redistribute static route-map STATIC_TO_BGP
R1(config-router-af)# end
```

---

### 10. IPv6 マルチキャストスタティック（ipv6 mroute）による複数送信元のRPF上書き
**【問題】**
R1において、IPv6マルチキャスト環境を定義します。IPv6マルチキャストソースグループ `2001:db8:aaaa::/64` から流入するマルチキャストパケットについて、RPFチェックを `GigabitEthernet0/5` ポートに固定して成功させるマルチキャストスタティックルートを設定してください。

**【R1 設定】**
```bash
R1# configure terminal
# IPv6 マルチキャストルーティングプロセスの有効化
ipv6 multicast-routing

# IPv6 mroute のバインド
ipv6 mroute 2001:db8:aaaa::/64 GigabitEthernet0/5
R1(config)# end
```

**【検証方法】**
```bash
R1# show ipv6 rpf 2001:db8:aaaa::100
# RPF インターフェイスが「GigabitEthernet0/5」として解決されていることを検証します。
```

---

## ❓ 想定試験問題

CCIE Enterprise Infrastructure ラボ・筆記試験における難関問題と解説です。

### 1. 【コンフィグ読解：再帰解決（Recursive Lookup）の上限とCEF動作不良】
**問題:** 
以下のスタティックルート設定を、ルータR1に一斉に投入しました。このとき、宛先ホスト `10.50.50.5` へのパケットがR1に入力された際の、**R1のコントロールプレーンにおけるRIB解決状態、およびFIB（CEFハードウェア転送）における挙動**を詳細に分析して答えなさい。
```text
ip route 10.50.50.0 255.255.255.0 172.16.1.1
ip route 172.16.1.1 255.255.255.255 192.168.1.1
ip route 192.168.1.1 255.255.255.255 10.1.1.1
ip route 10.1.1.1 255.255.255.255 192.0.2.1
ip route 192.0.2.1 255.255.255.255 GigabitEthernet0/1 192.0.2.254
```

**解答・解説:**
*   **RIB（ルーティングテーブル）の解決状態:**
    コントロールプレーン（ルーティングテーブル）上では、すべての経路がそれぞれ親となるスタティックルートを参照し、最終的に `192.0.2.1` が直結インターフェイス `GigabitEthernet0/1` で解決されているため、一見するとすべてのルートに `S`（Static）マークが付与され、RIB内では「正常（解決済み）」として表示されます。
*   **FIB（CEFハードウェア転送）における致命的挙動（Recursion Depth 超過による無効化）:**
    Cisco IOS-XEのハードウェアCEFエンジンは、転送処理を1クロックで完了させるために、ネクストホップの再帰的ルックアップを最大で **3段階（Depth 3）** までしかサポートしません。
    本コンフィグの再帰ステップを追跡すると、以下のようになります。
    1.  `10.50.50.0/24` ➔ `172.16.1.1` (Depth 1)
    2.  `172.16.1.1` ➔ `192.168.1.1` (Depth 2)
    3.  `192.168.1.1` ➔ `10.1.1.1` (Depth 3)
    4.  `10.1.1.1` ➔ `192.0.2.1` **(Depth 4 - 限界突破！)**
    5.  `192.0.2.1` ➔ `GigabitEthernet0/1` (Direct)
    
    これにより、再帰深度が4段階（Depth 4）に達するため、CEFハードウェアフォワーディングテーブルはこの宛先 `10.50.50.0/24` に対するASIC転送エントリ（Adjacency解決）を生成することを拒否（またはドロップ）します。
    結果として、パケットは **ハードウェアスイッチされずにCPUへパント（Punt）されてソフトウェア処理に落ち、ルータのCPU使用率がスパイクする** か、あるいは完全にパケットドロップが発生します。CCIEラボ試験において、このような多段のスタティックネストは重大な設計違反（失点要因）と判断されるため、再帰は最大でも2段階以内に収めるのが鉄則です。

---

### 2. 【トラブルシュート：VRF Leaking 静的デフォルトルートの片通障害】
**問題:** 
拠点ルータ R1 において、VRF `TENANT_BLUE` からインターネットアクセス用グローバルゲートウェイ（IP: `203.0.113.254`、Gi0/1ポート経由）へトラフィックをリーク（VRF Leaking）させるため、以下の設定を投入しました。
```text
R1(config)# ip route vrf TENANT_BLUE 0.0.0.0 0.0.0.0 GigabitEthernet0/1 global 203.0.113.254
```
投入後、VRF `TENANT_BLUE` に属するクライアント端末から外部へのPingを実行したところ、R1のGi0/1ポートを流れるパケットをキャプチャすると「R1からの送信（Echo Request）」は確認でき、外部DNS等からの「戻りパケット（Echo Reply）」もGi0/1ポートに届いていることが確認できましたが、最終的にクライアント端末にはPing応答が戻らず、通信不可（片通状態）のままです。
この障害が発生している**根本原因**と、R1に追加すべき**修正コマンド**を答えなさい。

**解答・解説:**
*   **根本原因:**
    インターネット（グローバルテーブル）から戻ってきたリターントラフィックが、**グローバルルーティングテーブルにおいて「VRF TENANT_BLUE 内のプライベートIPセグメント（例：10.22.22.0/24）」への逆方向スタティックルート（帰り道）を持っていないため** です。
    R1は、Gi0/1に到着した「戻りIPパケット（宛先：`10.22.22.5`）」を、自機のグローバルルーティングテーブルで検索します。しかし、グローバルテーブルには `TENANT_BLUE` の内部セグメントである `10.22.22.0/24` の経路が存在しない（VRF内に完全に隔離されている）ため、R1はパケットをどのようにVRFへリーク（ルーティング転送）すべきか判断できず、その場で破棄（サイレントドロップ）していました。
*   **修正コマンド（グローバルからVRFへの戻りルートをリーク配置）:**
    ```text
    R1(config)# ip route 10.22.22.0 255.255.255.0 GigabitEthernet0/2 vrf TENANT_BLUE 10.22.22.1
    ```
    （※これにより、グローバルに戻ってきたパケットが `vrf TENANT_BLUE` キーワードによってテナントVRF内へ強制リークして戻され、双方向通信が完全に成立します。）

---

### 3. 【Design：マルチキャスト環境における RPF 失敗時のマルチパス設計】
**問題:** 
SW1において、マルチキャスト送信元「S: `192.168.88.88`」へ向けて、OSPFが等コストマルチパス（ECMP）により `GigabitEthernet1/0/1` と `GigabitEthernet1/0/2` の2つのポートをベストパスとしてRIBに保持しています。
この環境において、PIM-SMを用いたマルチキャスト配信を運用した際、**RPFチェックの動作にどのような影響が発生するか**、Ciscoマルチキャストルーティングの仕様から説明しなさい。また、特定の1ポートのみにRPFチェックを静的に固定して安定させるためのデザイン案を提示しなさい。

**解答・解説:**
*   **マルチキャストRPFチェックへの影響:**
    ユニキャストルーティングテーブルに、送信元 `192.168.88.88` へのECMP（等コストマルチパス）経路が複数存在する場合、PIMプロセスは **「ネクストホップのIPアドレスが最も高い（または低い）方のインターフェイス」**、あるいはプラットフォームのハッシュに基づき、**「いずれか1つの物理ポートのみ」を唯一のRPFインターフェイスとして強制的に選定** します。
    もし、マルチキャスト送信元から送られてくる映像トラフィックが、ASICのロードバランシングによって、PIMがRPFとして選定しなかった「もう一方の物理ポート」から流入してきた場合、ルータはそのマルチキャストパケットを「RPFチェック失敗（Mismatch）」と判定し、すべてハードウェアで即座にドロップします。これにより、マルチパッシング網では映像の激しいコマ落ちや、不通が発生するリスクが定常的に付きまといます。
*   **デザイン案（`ip mroute` によるRPFの静的固定）:**
    マルチキャストトラフィックの受信を特定の安定したポート（例：`GigabitEthernet1/0/1`）に固定してRPFチェックを常に100%成功させるため、スタティックマルチキャストルートをバインドします。
    ```text
    SW1(config)# ip mroute 192.168.88.88 255.255.255.255 GigabitEthernet1/0/1
    ```
    （※これによりユニキャストの動的マルチパスの変動から完全に隔離され、常にGi1/0/1から入るマルチキャストパケットのみが許可・転送されます。）

---

## 🔗 参考リソース

### Configuration ガイド（シスコ公式）
*   [**Cisco Catalyst 9300 Series Switches: IP Routing Configuration Guide, Configuring Static Routing**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/rtg/b_17x_rtg_9300_cg/m_configuring_static_routing.html)
    *   Cisco IOS-XE 17.x におけるユニキャストスタティックルート、VRF-Aware Static、および再帰解決に関する公式ドキュメント。
*   [**Cisco IOS-XE IP Multicast Routing Configuration Guide, Configuring IP Multicast Static Routes**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book/imc-static-routes.html)
    *   `ip mroute` を用いたスタティックマルチキャストRPFチェック構成とオーバーライドに関する詳細なテクニカルガイド。
*   [IP Routing: Protocol-Independent Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book.html)
*   [IPv6 Routing: Static Routing Configuration (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/ip-version-6-ipv6/113328-ipv6-static-00.html)
*   [IP Multicast: Static mroute configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book/imc-static-mroutes.html)
*   
### Command Reference（シスコ公式）
*   [**Cisco IOS XE 17.x IP Routing Command Reference: ip route / ipv6 route**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/command_reference/b_17x_rtg_9300_cr.html)
    *   `ip route` コマンド、`ipv6 route` コマンドにおける各種アソシエーションパラメータおよび制限に関するリファレンス。

### Cisco Live（オンデマンド・スライド資料）
*   [**BRKCRS-2001: Intent-Based Campus Layer 3 Routing Design and Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2001)
    *   スタブインフラにおけるセキュアなスタティックルーティング配置、Object Tracking連携、VRF間リーク時のルーティング設計デザインの講義。
### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKCCIE-3000: BGP is your Friend – BGP for the CCIE Candidates (再配送/AD操作含む)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### テクニカルドキュメント・設定例
*   [Reliable Static Routing with IP SLA (Cisco TechNotes)](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/215357-reliable-static-routing-using-ip-sla.html)
*   [Static Route and VRF Configuration Examples](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/13731-static-vrf.html)

---

## 📝 **補足（Notes）**

### スタティックルーティング構成判定クイックフロー

ラボ試験中に、設定すべきスタティックルートのオプションを間違えないための、アーキテクチャ判定マップです。

```text
                  [ 宛先へのスタティックルート設定開始 ]
                                    │
                  [ 接続インターフェイスの物理特性は？ ]
                  /                                    \
      (Point-to-Point / Tunnel)                  (Ethernet / Multi-access)
                /                                        \
     「インターフェイス指定のみ」が許容            「ネクストホップ IP」または
     (Proxy ARPへの依存や枯渇リスクなし)            「完全特定（Fully Specified）」が必須
                                                  (Proxy-ARP依存による障害を100%回避)
```

*   **最終動作検証用コマンドテンプレート:**
    *   [ ] `show ip route static` ➔ 期待したAD値（フローティングの場合は 200 等）で正しくRIBに挿入されているか？
    *   [ ] `show ip cef <宛先IP> detail` ➔ FIBハードウェア解決において、再帰検索が3段階（Depth 3）を超えておらず、正常に直結ポートと隣接物理MACアドレスがマッピングされているか？
    *   [ ] `show track <ID>` ➔ SLAリンク消失時に、Trackオブジェクトが即座に「DOWN」に遷移し、RIBからプライマリルートが正常に剥がれるか？
    *   [ ] `show ip rpf <送信元IP>` ➔ マルチキャストにおいて、指定した `ip mroute` インターフェイスがRPFチェック検証に合格しているか？

