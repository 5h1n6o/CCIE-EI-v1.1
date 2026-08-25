---
layout: default
title: 1.1.d-EtherChannel
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.1.d EtherChannel

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.d EtherChannel」に関連する、LACP/Static構成、L2/L3 EtherChannel、負荷分散、誤設定ガード、およびマルチシャーシEtherChannel（MEC）について、整理しました。

---

# 1.1.d EtherChannel (L2/L3, LACP, Load Balancing, Misconfiguration Guard, MEC)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 ラボ試験および筆記試験において極めて重要なキャンパスLANスイッチングのコア技術である **EtherChannel（L2/L3、LACP、ロードバランシング、Misconfiguration Guard、Multichassis EtherChannel）** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ）の実装基準に準拠した、非常に詳細な復習用学習メモを記述します。

---

## 📘 概要

エンタープライズ・キャンパスネットワークにおけるコア・ディストリビューションスイッチ間、およびデータセンターのスイッチ・サーバー間において、物理リンクの帯域制限を打破し、アクティブ・アクティブの冗長経路をサブ秒単位で確保するための代表的技術が **EtherChannel（ポートチャネル）** です。

### 1. LACP (Link Aggregation Control Protocol - IEEE 802.3ad/802.1AX) & Static
複数の物理イーサネットリンクを1つの論理リンク（Port-Channel）にグループ化します。
*   **LACP (動的ネゴシエーション):** 接続の両端のポートがプロトコルを交換し、設定ミスや配線誤り（クロス接続など）による部分的な不整合を動的に検知・排除して安全にチャネルを形成します。
*   **Static (静的/onモード):** ネゴシエーションを行わず、強制的にチャネルをUPさせます。設定ミスの検知能力がないため、トラブルのリスクが伴います。

### 2. Layer 2 vs Layer 3 EtherChannel
*   **Layer 2 EtherChannel:** スイッチド（VLAN）ポートを束ね、スパニングツリープロトコル（STP）からは「1つの論理トランク/アクセスインターフェイス」として処理されます [12, 1.1]。
*   **Layer 3 EtherChannel:** `no switchport` によりインターフェイスをルーテッド化してからチャネルを形成します。IPアドレスをPort-Channel論理ポートに直接付与し、ダイナミックルーティングプロトコル（OSPFやEIGRPなど）のネイバーを構築するために使用されます [12, 1.1.d (ii)]。

### 3. Load Balancing (ロードバランシング)
EtherChannelに送出されるパケットをどの物理メンバーポートに割り振るかを決定する、ハッシュアルゴリズムの制御技術です。パケットの送信元・宛先MACアドレス、IPアドレス、TCP/UDPポート番号などのヘッダー情報を基にハッシュバケット（Hash Bucket）が算出され、ポートが選択されます。

### 4. EtherChannel Misconfiguration Guard
対向スイッチ間におけるEtherChannelの構成不整合（例：一方のスイッチはPort-Channel構成だが、もう一方は個別インターフェイス構成になっている状態）を検知し、一時的にポートを `err-disabled` に移行させてレイヤ2のブロードキャストストーム（STPループ）を防ぐシスコ独自の保護機能です。

### 5. Multichassis EtherChannel (MEC)
2台の物理スイッチ（StackWise Virtual、VSS等）を論理的に1台の仮想スイッチに統合し、それに対して異なる筐体（マルチシャーシ）にまたがる物理ポートを束ねてシングルEtherChannelを構築するテクノロジーです [1.1.d (v)]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 最大8本の物理イーサネットリンク（LACPでは最大16本、うち8本アクティブ、8本ホットスタンバイ）を1つの論理リンク（Port-Channel）に統合。 |
| **用途** | スイッチ間の帯域拡張、スパニングツリーによるブロックポート排除（ブロッキング回避）、筐体間冗長性の確立。 |
| **メリット** | インフラの帯域幅（スループット）を論理的にスケールアップ可能。1リンク障害時もサブ秒レベル（LACP Rate Fastなら1〜2秒以下）でコンバージェンス。 |
| **デメリット** | ロードバランシング方式を最適化しないと、特定の物理ポートにのみトラフィックが偏る（不均等トラフィック/ポラライゼーション現象）。 |
| **対応機種** | Catalyst 9000 シリーズを含むすべての Cisco IOS-XE デバイス（ASIC: UADP 2.0 / 3.0 等）。 |
| **制限事項** | ポートを束ねる際、速度（Speed）、デュプレックス（Duplex）、VLANパラメータ（Allowed List、Native VLAN）などの物理・論理特性が全メンバー間で一致していることが必須条件。 |
| **設計上の注意点** | L3 EtherChannelを使用することで、不要なSTPインスタンスを排除し、ルーティングテーブルの等コストマルチパス（ECMP）よりも高速な切り替えと経路統合を同時に実現。 |

---

## 🏗 動作原理

### 1. LACPのステートとメッセージング（Actor / Partner）
LACPは、2台のスイッチ間（Actor：自身、Partner：対向）で **LACPDU（LACP Data Unit、宛先マルチキャストMAC: `01-80-c2-00-00-02`）** を毎秒（Fast）または30秒（Slow）おきに交換することで機能します。

```text
  [ Switch A (Actor) ] ── (LACPDU: System-Priority, Key, State) ──► [ Switch B (Partner) ]
  
  * LACPDUに含まれる重要情報:
    - System ID: System Priority (デフォルト32768) + MACアドレス
    - Port ID: Port Priority (デフォルト32768) + ポート番号
    - Operational Key: ポートの速度、デュプレックス、VLAN等の整合パラメータから自動生成された鍵情報
    - State Flags: Active/Passive, Timeout (Fast/Slow), Aggregation, Sync, Collecting, Distributing, Defaulted
```

*   **LACP 選択優先（Decision Maker）の決定:**
    両端のスイッチが交換した「System ID」を比較し、**System IDの数値が「低い」側のスイッチが、優先権を持つマスター（Decision Maker）**として決定されます。マスター側の「Port Priority」の低いポートから優先的に「Active」ポートとして選択され、上限（最大8ポート）を超えた残りのメンバーポートは「Hot-Standby」状態になります。

### 2. レイヤ2 vs レイヤ3 EtherChannel の内部構造
レイヤ2とレイヤ3での内部ASIC/L2フォワーディングエンジンの動作プロセスの違いを比較します。

```text
[ Layer 2 EtherChannel ]
物理ポート群 (Gi1/0/1 - Gi1/0/2) ➔ (ハードウェアLACP) ➔ 論理 Port-Channel 1 ➔ MACフォワーディングテーブル (SVI / VLAN 10 などのL2空間)
* STPは論理Port-Channel 1を1つの物理ポートとみなして動作。

[ Layer 3 EtherChannel ]
物理ポート群 (Gi1/0/1 - Gi1/0/2) ➔ (no switchport により L2 テーブルから隔離) ➔ 論理 Port-Channel 1 ➔ (直結 IP アドレスアサイン) ➔ L3ルーティングテーブル
* MACアドレスはPort-Channel 1上の1つの論理アドレスがメンバーポート全体で共有（または仮想MAC）され、ARP解決時に応答。
```

### 3. Load Balancing のハッシュバケット（Hash Bucket）算出
Ciscoスイッチは、ロードバランシングを行うために、ヘッダー（送信元・宛先IP等）の対応ビットを切り出し、ハッシュ関数を適用して **3ビット（8バケット：0〜7）** または **4ビット（16バケット）** のハッシュ値に変換します。

```text
 [ Ingress Packet ] ➔ [ Ingress Port ] ➔ [ ASIC Hash Generator ]
                                                   │
                                                   ▼ (例: Source-Destination IP Hash)
                                        [ Hash Result (0 - 7) ]
                                                   │
                       ┌─────────┬─────────┼─────────┬─────────┐
                       ▼         ▼         ▼         ▼         ▼
ハッシュバケット:      Bucket 0  Bucket 1  Bucket 2  Bucket 3  Bucket 4 ... Bucket 7
                       ├─────────┴─────────┤         ├─────────┴─────────┤
物理ポート割り当て:    物理ポート 1 (Gi1/0/1)       物理ポート 2 (Gi1/0/2)
```

物理メンバーポートが「2本（偶数）」であれば、それぞれに 4 バケットずつ均等に分配されますが、物理メンバーポートが「3本（奇数）」の場合、バケット（計8個）は `3, 3, 2` のように不均等にマッピングされるため、理論上最大で **12.5%** の帯域差が生じるポラライゼーション（偏り）が発生します。したがって、メンバーポート数は **2のべき乗（2, 4, 8）** で設計するのが最も均等な分散を実現する鉄則です。

---

## ⚙ 動作シーケンス

### LACPネゴシエーション確立シーケンス
動的ネゴシエーションによるチャンネル確立の段階的プロセスを示します。

```
[ 両端の物理インターフェイスがリンクアップ (L1 UP) ]
       │
       ▼
[ LACPDU パケットの送信開始 (宛先MAC: 01-80-c2-00-00-02) ]
       │
       ├─► Activeポート: 即座にLACPDUを定期送信開始。
       └─► Passiveポート: LACPDUを受信するまで待機（パッシブモード）。
       │
       ▼
[ ネゴシエーション整合性（Operational Key の比較・整合）]
       │
       ├─► 物理プロパティ（速度、全二重、トランク設定等）が一致しているか判定。
       ├─► 一致 ➔ LACPDU内の State Flags を「Sync」に設定し、対向へ通知。
       └─► 不一致 ➔ 【ブロック状態（I: Independent または Standby）】に留まる。
       │
       ▼
[ System Priority / ID 比較によるマスター選定 ]
       │
       ├─► System ID が小さいスイッチを「マスター（Decision Maker）」として決定。
       └─► マスターの Port Priority に基づき、最大ポート制限（デフォルト8ポート）の範囲内で「Collecting/Distributing」状態（転送可能）に移行。
       │
       ▼
[ 論理 Port-Channel の UP/UP 完了 ➔ トラフィック転送開始 ]
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI実技ラボ試験では、単純に EtherChannel を組むだけではなく、インフラ全体の「高信頼設計（High Availability）」および「STPの完全制御」と密接に関連して出題されます。

### 1. LACP 1対N 冗長（Max-Bundle 制御）
*   **出題条件:**
    「スイッチ SW1 と SW2 間は、4本の物理リンクで接続されている。しかし、現在の通信帯域としては2本分（2Gbps）のみを論理的に使用し、残りの2本のリンクはホットスタンバイ（LACP Hot-Standby）として待機させなさい。優先的にアクティブにするポートは、物理ポート `Gi1/0/1` および `Gi1/0/2` とし、対向スイッチ SW1 を基準に制御を確立せよ」
*   **試験対策:**
    *   **LACP 選択基準の決定:** アクティブにしたいメンバーの優先度を決めるため、SW1 をマスターに仕立て上げます（System Priority を小さく設定：例 `lacp system-priority 4096`）。
    *   **ポート優先度の設定:** 優先したい物理ポート（Gi1/0/1、Gi1/0/2）の Port Priority をデフォルトの32768から「1000」などの低い値に変更します（`lacp port-priority 1000`）。
    *   **最大アクティブポート制限:** Port-Channelインターフェイス配下で、アクティブポート数の最大値を「2」に固定します（**`bundle max-bitrate`** ではなく **`lacp max-bundle 2`** を指定）。

### 2. ポートチャネル不整合保護（Misconfiguration Guard）のトラブルと無効化要求
*   **動作仕様:**
    Ciscoスイッチは、トランク上で受信するSTPのBPDUソースを監視しています。もし、自機が「Port-Channel 1」として扱っているトランクポート（仮想MACで動作）において、対向側から届いたBPDUが個別ポート（物理MAC等）で送信されていることを検知した場合、スイッチは対向側の配線誤りやチャネル設定ミスを疑い、ループ防止のために自身のポートを **`err-disabled`** に落とします。
*   **試験での罠:**
    「他社製デバイスや仮想環境（ESXi）等で、LACPネゴシエーションが正しく動作せず、スイッチ側が Misconfiguration Guard の過剰検知によりポート閉塞を繰り返してしまう。これを回避するために、スイッチ全体のループ保護機能（STP）は稼働させたまま、この **EtherChannel不整合保護機能のみをピンポイントで無効化** せよ」
    *   **対策:** グローバルコンフィギュレーションで以下のコマンドを投入します。
        ```bash
        no spanning-tree etherchannel guard misconfig
        ```

### 3. Min-Bundle 制御による論理リンクダウン自動化
*   **出題条件:**
    「Port-Channel 1 を構成するメンバーポートに複数の障害（リンクダウン）が発生し、利用可能な有効リンク数が1本のみに減少した場合、通信パケットのポラライゼーション（偏り）や輻輳による過剰な遅延（Jitter）を避けるため、Port-Channel 1 全体を論理的に自動シャットダウン（Down）させ、代替の冗長リンク（別ルーティング経路等）へトラフィックを即座に迂回させなさい」
    *   **対策:** Port-Channel インターフェイス配下で、チャネルがUPを維持するための最小メンバーリンク数を定義します。
        ```bash
        interface Port-channel 1
         port-channel min-links 2
        ```
        （これにより、アクティブな物理メンバーリンク数が1本以下になった時点で、論理Port-channel 1全体が強制ダウンします。）

### 4. ロードバランシング・ハッシュの調整
*   **トラブルチケット例:**
    「ディストリビューションスイッチから特定の設定確認用踏み台サーバー（IPアドレス固定、ポート番号多重）へ向かう大量の制御トラフィックにおいて、2本の物理リンクを持つPort-Channel 2が構成されている。しかし、統計を確認すると Gi1/0/1 の利用率が 98% であるのに対し、Gi1/0/2 は 2% であり、帯域幅がボトルネックになってドロップが生じている」
    *   **原因:** 現在のグローバルなEtherChannelロードバランシングハッシュがデフォルトの `src-dst-mac` に固定されており、同一MACアドレス間（サーバーとデフォルトゲートウェイ間）の通信であるため、すべてのパケットが同じハッシュ値を算出してしまっている。
    *   **対策:** L4ポート番号も含めたハッシュパラメータ（例：**`port-channel load-balance src-dst-mixed-ip-port`** など）にグローバルで変更して、偏りを解消します。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における、実践的なEtherChannel設定コマンドです。

### 1. レイヤ2 LACP動的 EtherChannel 設定

```bash
# 物理メンバーポートの設定
interface range GigabitEthernet1/0/1 - 2
 description L2_LACP_MEMBERS
 # VLANやデュプレックスなどの属性を事前にクリーンにリセット
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
 # チャネルプロトコルの明示（※IOS-XEではチャネルグループ作成時にプロトコルが自動割り当てされます）
 channel-group 1 mode active
exit

# 論理ポートチャネルインターフェイスのカスタマイズ
interface Port-channel 1
 description L2_PORT_CHANNEL_TO_SW2
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
 spanning-tree guard root
```

### 2. レイヤ3 Static（静的 / mode on）EtherChannel 設定

```bash
# 1. 物理インターフェイス側のルーテッドポート化とチャネル登録
interface range GigabitEthernet1/0/3 - 4
 description L3_STATIC_MEMBERS
 no switchport
 # 静的強制モード（on）の適用
 channel-group 2 mode on
exit

# 2. 論理ポートチャネルインターフェイスでの L3 設定
interface Port-channel 2
 description L3_PORT_CHANNEL_TO_CORE
 no switchport
 ip address 10.1.12.1 255.255.255.252
 # ルーティングプロトコル用に MTU や OSPF パラメータを整合
 ip ospf 1 area 0
```

### 3. LACP 高度な冗長制御（System Priority, Port Priority, Max-Bundle, Rate Fast）

```bash
# LACP システム優先度の変更（自機をマスターとして固定：デフォルト32768）
lacp system-priority 4096

# 物理ポートの優先度およびタイマーの高速化設定
interface GigabitEthernet1/0/1
 lacp port-priority 1000
 # LACPのハロー間隔を30秒から1秒（Fast）に変更し、切り替えをミリ秒に高速化
 lacp rate fast
exit

interface GigabitEthernet1/0/2
 lacp port-priority 2000
 lacp rate fast
exit

# Port-Channel 側での最大・最小アクティブ物理リンク数の縛り設定
interface Port-channel 1
 # 最大アクティブメンバーを「2本」に制限
 lacp max-bundle 2
 # 稼働中のメンバー数が「2本」を下回った場合に、論理チャネル全体をシャットダウン
 port-channel min-links 2
```

### 4. ロードバランシングアルゴリズムのグローバルチューニング

```bash
# スイッチ全体のロードバランシング方法のチューニング
# (IPアドレスに加え、TCP/UDPの送信元・宛先ポート番号も含めて詳細に分散)
port-channel load-balance src-dst-mixed-ip-port
```

---

## 🔍 検証コマンド

EtherChannelの健全性とロードバランシング統計を確認するためのコマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **EtherChannel全体の構成状態、メンバー数、論理/物理ステータスの一覧確認** | <code>show etherchannel summary</code> |
| **特定の論理チャネル（Port-channel 1）の詳細な状態とメンバー同期情報の確認** | <code>show etherchannel 1 summary</code> |
| **ポートチャネルを構成する個々の物理ポート詳細、LACPステート、フラグ表示の確認** | <code>show etherchannel port</code> |
| **LACPのシステム優先度、System ID、対向（Partner）情報の表示** | <code>show lacp sys-id</code> / <code>show lacp neighbor</code> |
| **スイッチ全体のロードバランシングハッシュアルゴリズム設定確認** | <code>show etherchannel load-balance</code> |
| **特定のパケット（送信元/宛先IPやポート等）が、現在どの物理ポートに送出されるかのハッシュ計算シミュレーション検証** | <code>test etherchannel load-balance interface port-channel 1 ip 10.1.1.1 10.2.2.2</code> |
| **L2/L3ポートチャネルでのリアルタイムパケットデバッグの開始** | <code>debug etherchannel detail</code> / <code>debug lacp events</code> |
| **不整合ガード（Misconfig Guard）等によるポート閉塞の検出** | <code>show interfaces status err-disabled</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **ポートが「down/down」、かつ `show etherchannel summary` で「D（Down）」フラグが付いている。** | 物理メンバーポート間で、**速度（Speed）やデュプレックス（Duplex）などのパラメータが不一致**、または対向側のモード（例：両端で `passive`、片側 `active` だがもう一方が `on`）が不整合。 | `show interfaces status`<br>`show etherchannel summary` | 1. 物理ポートの `speed`、`duplex` を明示的に合わせる。<br>2. 動的LACPの場合は片側を必ず `active`、もう片側を `active` または `passive` に統一。 |
| **トランクリンクとして束ねているが、一部のVLANのタグ付きパケットがドロップする。** | 物理ポート個別の `switchport trunk allowed vlan` と、論理 Port-Channel の **Allowed VLAN リストに不一致が発生している**。 | `show interfaces trunk` | 論理Port-Channelインターフェイス配下で設定したAllowed Listはメンバー物理ポートに自動継承されますが、物理ポートに個別にマニュアル設定を施している場合は不整合となるため、物理ポート側のトランク設定を一度削除してPort-Channelの構成を再同期させる。 |
| **LACP ポートチャネルを構築後、数秒後にポートが強制的に「err-disabled」となる。Syslogに「%PM-4-ERR_DISABLE: port-bundle」が出力。** | **対向スイッチとのチャネル整合性エラー。** 自機はEtherChannelを組んでいるが、対向が個別ポート扱いのままになっているか、物理配線が誤って別筐体の独立スイッチに分散接続（クロス接続）されている。 | `show interfaces status err-disabled`<br>`show logging` | 1. 対向スイッチ側の channel-group 設定抜けを修復。<br>2. 物理接続ケーブルのトポロジー配線経路がループしていないか確認。 |
| **L3 Port-Channel に IP アドレスを付与したが、対向スイッチと PING が通らない。** | 物理メンバーポートに `no switchport` が設定される前に `channel-group` に追加されたか、ポート個別でIP関連処理が不整合状態になっている。 | `show run interface Port-channel 2`<br>`show run interface [物理ポート]` | メンバー物理ポートから一度 `channel-group` を外し、対象物理ポートおよびPort-Channel配下の両方で明示的に `no switchport` を投入した上で再グループ化を施す。 |
| **4本の物理リンクでEtherChannelを構成しているが、すべてのトラフィックが1本の物理リンクにのみ集中してしまい、帯域幅が逼飽している。** | ロードバランシング（Load-balancing）ハッシュアルゴリズムが、パケット特性（例：すべて同一IP間で、ポート番号のみが変動するトラフィック）に合っていない。 | `show etherchannel load-balance` | グローバルコンフィギュレーションで、L4（UDP/TCPポート番号）をハッシュ式に組み込む `port-channel load-balance src-dst-mixed-ip-port` に修正。 |

---

## ⚠ 制限事項

### 1. 物理特性の一貫性（一律一致）の厳密ルール
EtherChannelを正常に形成し、メンバーポートが「Bundle（B）」ステータスになるには、以下の特性がすべてのメンバー物理ポート、および論理Port-Channelポート間で完全に一致していなければなりません。
1.  **物理層プロパティ:** ポート速度（Speed）、デュプレックスモード（Duplex: 必ずFull-Duplex）。※1Gポートと10Gポートなどの異速度混在バンドルは仕様上一切不可能です。
2.  **スイッチポート特性:** アクセスポートかトランクポートかの違い、所属VLAN、トランク時のAllowed VLANリスト、Native VLAN ID。
3.  **Spanning Tree特性:** STPポートパスコスト、STPポートプライオリティ、STPガード設定（Root Guard / Loop Guard等）。

### 2. ハードウェアプラットフォームのメンバー数限界
*   Cisco Catalyst 9000シリーズ（IOS-XE 17.x）における1つの論理Port-Channelあたりの最大物理アクティブメンバー数は **8ポート** です。LACPのホットスタンバイ機能を利用することで、最大 **16ポート**（アクティブ8、スタンバイ8）までチャネル内に登録可能。

### 3. SSO（Stateful Switchover）とLACPのフェイルオーバー制限
*   スタック（StackWise）構成や StackWise Virtual 環境において、アクティブスーパーバイザエンジンが障害でスタンバイへ切り替わる（SSO発生）際、LACPネゴシエーションが途切れて対向デバイスがポートチャネルを切断（err-disabled等）しないよう、ノンストップフォワーディング（NSF）およびLACP SSO機能がサポートされていますが、LACPキープアライブタイマー（Fast Rate 1秒）のミリ秒レベルの一時的な瞬断を許容できるようチューニング設計が必要です。

---

## 🔄 他技術との関連

*   **STP (Spanning Tree Protocol):** 
    L2 EtherChannelを組むと、STPは個々の物理リンクではなく、束ねられた「Port-Channelインターフェイス」を単一のブロードキャストフォワーディングパスとして計算します。これにより、物理的に冗長なループ接続であってもブロック（Discarding）ポートが発生せず、全ポートの帯域幅がフル稼働します。Port-Channelの一部物理メンバーポートがダウンしても、論理ポートステータスはUPを維持するため、STPの再計算（TC：Topology Change発出）は一切発生せず、ネットワークは極めて安定します。
*   **Routing (OSPF, EIGRP, BGP):**
    L3 EtherChannel（ルーテッドポートチャネル）を使用することで、各物理リンク個別にIPアドレスを割り当てて等コストマルチパス（ECMP）で負荷分散するよりも、1つのIPネイバー（1つの論理コントロールプレーン関係）を維持できるため、ルータのCPU処理負荷を大幅に削減し、コンバージェンス（切り替え）をミリ秒単位へ高速化できます。
*   **SD-Access (SDA) / Fabric Underlay:**
    Cisco SD-Accessにおけるアンダーレイ（物理コアドメイン）の構築において、コアスイッチ（Catalyst 9500）とディストリビューションスイッチ間を結ぶ物理リンクは、L3 EtherChannel を用いてルーテッド網として束ね、VXLANパケットを高効率に等価伝送する経路（アンダーレイトランスポート）として最優先で採用されます。

---

## 🧩 比較表

### 1. レイヤ2 Port-Channel vs レイヤ3 Port-Channel

| 比較要素 | Layer 2 Port-Channel | Layer 3 Port-Channel |
| :--- | :--- | :--- |
| **IPアドレスの付与** | 不可（VLAN SVIインターフェイスでIPを管理） | **可能**（論理 Port-Channel に直接 <code>ip address</code> を適用） |
| **STPの動作** | 動作する（STPトポロジーの一部として認識される） | **動作しない**（L3ルーテッドポートとなるため、L2ループの概念から除外） |
| **設定基本コマンド** | `switchport` / `switchport mode [access/trunk]` | **`no switchport`**（物理およびPort-Channelインターフェイス配下で必須） |
| **主な用途** | アクセスレイヤスイッチとディストリビューション間の冗長L2集約 | ディストリビューションコアスイッチ間、L3トランジットルーティング、WANエッジ接続 |

### 2. マルチシャーシ EtherChannel（MEC）の実装技術比較

CCIE EI ブループリント [1.1.d (v)] で問われる「マルチシャーシ（複数の物理スイッチを跨ぐEtherChannel）」を実現するための、シスコプラットフォームごとのアプローチ比較です。

| 実装技術 | StackWise Virtual (SV) / VSS | vPC (Virtual Port Channel) |
| :--- | :--- | :--- |
| **対象プラットフォーム** | Cisco Catalyst 9000 シリーズ (9400, 9500, 9600等) | Cisco Nexus シリーズ (NX-OS) |
| **コントロールプレーン** | **統合される。** 2台の物理スイッチが完全に1台の論理CPU（Active / Standby）として稼働。 | **独立。** 2台の物理スイッチは個別にルーティング・MAC学習制御を維持。 |
| **筐体間接続（インターコネクト）** | SVL (StackWise Virtual Link) | vPC Peer-Link & Peer-Keepalive |
| **特徴** | 管理IPが1つになり、設定・運用が極めてシンプル。 | コントロールプレーンが分離しているため、ソフトウェアフリーズ時の共倒れリスク（スプリットブレインによる全断）が極めて低い。 |

---

## 💡 ベストプラクティス

1.  **LACP の明示的採用（静的 mode on の完全排除）:**
    静的モード（`mode on`）は、対向側の設定漏れや、クロス接続による誤配線（L2ループ状態）を検知する能力がなく、即座にブロードキャストストームを引き起こします。特別な理由がない限り、必ず **`mode active`** を用いて動的にLACPをネゴシエーションさせ、不整合時はブロックさせる設計にします。
2.  **メンバーポート数の「2のべき乗（2, 4, 8）」設計:**
    ASICにおけるハッシュバケット（計8個）を物理メンバーに均等にアサインするため、メンバーリンク数は偶数（2のべき乗本）で構成し、ポラライゼーション（偏り）による一部リンクの過負荷を防ぎます。
3.  **L3ルーテッド EtherChannel によるL2フリー設計:**
    キャンパスのディストリビューションスイッチ間、およびコア間においては、STPのインスタンス制限やブロックポートを排除するため、L2トランクではなく、**`no switchport`** を用いた **Layer 3ルーテッドポートチャネル** にて完全にL3境界（ルーテッドキャンパス）を形成します。
4.  **ロードバランシングハッシュの「送信元・宛先IP＋ポート（src-dst-mixed-ip-port）」構成:**
    一般PCとサーバー、あるいはプロキシサーバーとインターネットゲートウェイ間の特定IPに集中するトラフィックであっても、L4のTCP/UDPポート番号が変動すればハッシュが綺麗に分散されるため、一律でこの拡張ポートハッシュをグローバルで有効化します。

---

## 📝 ラボ学習・設定サンプル例

※ 本サンプルは、Cisco IOS-XE 17.x Catalyst 9000の実機挙動に100%準拠した、省略なしの完全なCLI設定構成です。

### 1. 【基本L2 LACP】速度自動・トランク整合カプセル化
**【問題】**
SW1とSW2の間のインターフェイス `GigabitEthernet1/0/1` および `GigabitEthernet1/0/2` を使用して、Layer 2 LACP EtherChannel（Port-channel 1）を構成してください。ポートは静的トランクとし、VLAN 10, 20, 30 の送受信を許可してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vlan 10,20,30
SW1(config-vlan)# exit

# メンバー物理ポートの定義とチャネルグループ登録
SW1(config)# interface range GigabitEthernet1/0/1 - 2
SW1(config-if-range)# switchport mode trunk
SW1(config-if-range)# switchport trunk allowed vlan 10,20,30
SW1(config-if-range)# channel-group 1 mode active
SW1(config-if-range)# exit

# 生成された論理Port-Channelの整合
SW1(config)# interface Port-channel 1
SW1(config-if)# switchport mode trunk
SW1(config-if)# switchport trunk allowed vlan 10,20,30
SW1(config-if)# end
```

---

### 2. 【基本L3 LACP】ルーテッドポートチャネルと OSPFv2
**【問題】**
SW1（Catalyst 9300 L3）とSW2のインターフェイス `Gi1/0/3`、`Gi1/0/4` を使用して、Layer 3 LACP EtherChannel（Port-channel 2）を構成してください。
*   SW1 IPアドレス: `10.1.12.1/30`
*   SW2 IPアドレス: `10.1.12.2/30`
*   OSPF プロセス 1、エリア 0 にこのPort-channel論理リンクを参加させてネイバーを確立してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# メンバー物理ポートの事前ルーテッドポート化とグループ化
SW1(config)# interface range GigabitEthernet1/0/3 - 4
SW1(config-if-range)# no switchport
SW1(config-if-range)# channel-group 2 mode active
SW1(config-if-range)# exit

# 論理Port-ChannelにおけるIPアドレスおよびルーティング定義
SW1(config)# interface Port-channel 2
SW1(config-if)# no switchport
SW1(config-if)# ip address 10.1.12.1 255.255.255.252
SW1(config-if)# ip ospf 1 area 0
SW1(config-if)# exit
SW1(config)# router ospf 1
SW1(config-router)# log-adjacency-changes
SW1(config-router)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# interface range GigabitEthernet1/0/3 - 4
SW2(config-if-range)# no switchport
SW2(config-if-range)# channel-group 2 mode active
SW2(config-if-range)# exit

SW2(config)# interface Port-channel 2
SW2(config-if)# no switchport
SW2(config-if)# ip address 10.1.12.2 255.255.255.252
SW2(config-if)# ip ospf 1 area 0
SW2(config-if)# exit
SW2(config)# router ospf 1
SW2(config-router)# log-adjacency-changes
SW2(config-router)# end
```

---

### 3. 【LACP Max-Bundle】System Priority と Port Priority による 2:2 冗長
**【問題】**
SW1とSW2を結ぶ4本の物理リンク（`Gi1/0/5`、`Gi1/0/6`、`Gi1/0/7`、`Gi1/0/8`）を用いて、最大アクティブリンク数を「2本」に制限した `Port-channel 3` を構築してください。
*   LACP優先権制御は SW1 がマスターとなるように構成してください。
*   優先的に「Active」として動作するポートは `Gi1/0/5` および `Gi1/0/6` とし、残りの2ポートはホットスタンバイとして待機させてください。

**【SW1 設定】**
```bash
SW1# configure terminal
# 1. SW1をLACPマスタースイッチに選定（Priorityをデフォルト32768より低く変更）
SW1(config)# lacp system-priority 4096

# 2. 優先したい物理ポートGi1/0/5, 6のポート優先度を低く変更
SW1(config)# interface range GigabitEthernet1/0/5 - 6
SW1(config-if-range)# lacp port-priority 1000
SW1(config-if-range)# channel-group 3 mode active
SW1(config-if-range)# exit

# 3. ホットスタンバイに回す物理ポートの登録（デフォルト優先度32768のまま）
SW1(config)# interface range GigabitEthernet1/0/7 - 8
SW1(config-if-range)# channel-group 3 mode active
SW1(config-if-range)# exit

# 4. Port-Channel側での最大アクティブ数制限
SW1(config)# interface Port-channel 3
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 10
SW1(config-if)# lacp max-bundle 2
SW1(config-if)# end
```

**【SW2 設定】** (※SW2は対向として、デフォルトのパラメータのままActiveに同期させます)
```bash
SW2# configure terminal
SW2(config)# interface range GigabitEthernet1/0/5 - 8
SW2(config-if-range)# channel-group 3 mode active
SW2(config-if-range)# exit
SW2(config)# interface Port-channel 3
SW2(config-if)# switchport mode access
SW2(config-if-range)# switchport access vlan 10
SW2(config-if)# lacp max-bundle 2
SW2(config-if)# end
```

---

### 4. 【LACP Min-Links】リンク数減少時の自動チャネルダウン
**【問題】**
SW1とSW2を結ぶ `Port-channel 4`（メンバー：`Gi1/0/9`, `Gi1/0/10`）において、何らかの理由でアクティブな物理メンバーポート数が「1本」に減少してしまった場合、一時的な不均等ロードバランシングによる品質悪化を防ぐため、Port-channel 4全体を論理的に自動的にシャットダウン（リンクダウン）させるポリシーを実装してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface range GigabitEthernet1/0/9 - 10
SW1(config-if-range)# channel-group 4 mode active
SW1(config-if-range)# exit

SW1(config)# interface Port-channel 4
# 動作に必要な最小リンク数を2本に定義
SW1(config-if)# port-channel min-links 2
SW1(config-if)# end
```

---

### 5. 【LACP Rate Fast】障害検出タイマーの超高速化
**【問題】**
ディストリビューションスイッチSW1とSW2間（`Gi1/0/11`, `Gi1/0/12`、`Port-channel 5`）において、物理ファイバー断線から隣接ポートへの切り替え、およびLACPキープアライブ消失の検知に要する時間を、デフォルトの「約90秒」から「3秒以下」へと極限まで高速化してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface range GigabitEthernet1/0/11 - 12
SW1(config-if-range)# channel-group 5 mode active
# LACP定期送信レートを「Fast（毎秒送信、ホールドタイムアウト3秒）」に変更
SW1(config-if-range)# lacp rate fast
SW1(config-if-range)# exit
SW1(config)# interface Port-channel 5
SW1(config-if)# end
```

---

### 6. ロードバランシング・ハッシュのL4ポート（Port-Level）分散
**【問題】**
同一のデータサーバー間で、高密度のTCP/UDPデータ通信（宛先・送信元IPアドレスは常に固定、内部のアプリケーションセッションポート番号のみがランダムに変動）が動作しています。2本のポートチャネルに綺麗にパケットをトラフィック分散させるよう、ロードバランシングハッシュエンジンを変更してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# IPのみならずL4ポート番号（TCP/UDP Port）をハッシュバケット計算式に混在（Mixed）させる
SW1(config)# port-channel load-balance src-dst-mixed-ip-port
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show etherchannel load-balance
# 「Source and Destination IP and Layer 4 Port」が現在のハッシュパラメータとして有効になっていることを確認します。
```

---

### 7. 【セキュリティ】不整合保護（Misconfig Guard）の強制無効化
**【問題】**
SW1のトランクポートチャネル `Port-channel 10` の対向側で、特殊な仮想ハイパーバイザーが動作しており、スイッチ側の「EtherChannel Misconfiguration Guard」が誤検知して err-disable にポートが閉塞してしまう障害が起きています。スイッチ全体のSTP保護機能は維持したまま、この誤検知による自動 err-disable 閉塞をグローバルでピンポイントで無効化してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# EtherChannel誤設定検知によるポート閉塞ガードをグローバルで無効化
SW1(config)# no spanning-tree etherchannel guard misconfig
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree summary
# 出力に「EtherChannel Misconfig Guard is disabled」と表示されることを確認します。
```

---

### 8. LACP システム優先度（System Priority）を用いたアクティブ調停の固定
**【問題】**
LACPベースの `Port-channel 20` において、将来ポート増設や冗長変更があった際、SW1側が常に「アクティブ/非アクティブポートを調停する側（マスター調停者）」としての権利を持ち続け、SW2側がこれに追従するよう、System Priority を設定してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# システム優先度を最も優先される「1（最小値）」に変更
SW1(config)# lacp system-priority 1
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show lacp sys-id
# 「32768」から「1」へSystem Priority値が変化しており、自機のMACアドレスと結合して動作しているのを確認します。
```

---

### 9. 【静的チャネル】Static EtherChannel（onモード）の構築
**【問題】**
他社製スイッチなど、LACPを全くサポートしていない古い機器と SW1（`Gi1/0/15`, `Gi1/0/16`）の間を束ねるため、プロトコルのネゴシエーションを一切伴わない静的な強制チャネル（Port-channel 15）をアクセスVLAN 50で構成してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vlan 50
SW1(config-vlan)# exit

SW1(config)# interface range GigabitEthernet1/0/15 - 16
SW1(config-if-range)# switchport mode access
SW1(config-if-range)# switchport access vlan 50
# ネゴシエーションをせず強制的にUPさせる「on」を指定
SW1(config-if-range)# channel-group 15 mode on
SW1(config-if-range)# exit

SW1(config)# interface Port-channel 15
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 50
SW1(config-if)# end
```

---

### 10. Port-Channel上のSTPガード（Root Guard）の統合設計
**【問題】**
下位のアクセススイッチから意図しないブリッジ（STP Root）優先度のBPDUパケットが、SW1の L2 LACP `Port-channel 30` を経由してキャンパスコアドメインへ伝搬し、ルートブリッジの奪取（乗っ取り）ループが発生するのを防止するため、チャネルを保護する Root Guard をPort-Channelに適用してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface Port-channel 30
# 論理チャネル上の全ポートに対してルート防衛を有効化
SW1(config-if)# spanning-tree guard root
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree interface Port-channel 30
# ポートのガード欄に「Root」と登録されていることを確認します。
```

---

## ❓ 想定試験問題

CCIE EIラボ実技、および記述（Diagnostic）試験を意識した難関設問群です。

### 1. 【トラブルシュート：メンバーポート「I」 Independent ステートの解消】
**問題:**
SW1（Catalyst 9300）で以下のコマンドを実行したところ、物理ポート `Gi1/0/1` がポートチャネルから離脱し、「I（Independent/独立）」フラグが表示されていました。
```text
SW1# show etherchannel summary
Group  Port-channel  Protocol    Ports
------+-------------+-----------+-----------------------------------------------
1      Po1(SU)         LACP      Gi1/0/1(I)  Gi1/0/2(P)
```
対向スイッチSW2の設定を確認すると、以下の状態になっていました。
```text
SW2# show run interface GigabitEthernet1/0/1
interface GigabitEthernet1/0/1
 switchport mode trunk
 switchport trunk allowed vlan 10,20
 channel-group 1 mode active

SW2# show run interface GigabitEthernet1/0/2
interface GigabitEthernet1/0/2
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30
 channel-group 1 mode active
```
この時、Gi1/0/1 が 「I」フラグになってしまっている**直接の技術的原因**を解説し、これを「P（Bundle/同期転送）」に修復するための**具体的な修正コマンド手順**を記載してください。

**解答・解説:**
*   **技術的原因:**
    対向スイッチSW2の物理メンバーポート間で、**Allowed VLAN（許可VLANリスト）の設定不一致**が発生しています（`Gi1/0/1` は 10,20、`Gi1/0/2` は 10,20,30）。Cisco LACPの動作仕様では、束ねるメンバー間でスイッチポートの属性（特にAllowed VLANリスト）が1つのVLAN IDのズレもなく完全に一致している必要があります。対向でこの整合性が崩れているため、SW1側は Gi1/0/1 ポートの Operational Key と LACPパケットパラメータが不整合（キーミスマッチ）と判断し、チャネルへの組み込みを安全に拒否して個別独立動作を示す「I（Independent）」ステータスに隔離しました。
*   **修正コマンド手順（SW2側でのAllowed VLANの同期修復）:**
    ```text
    SW2# configure terminal
    SW2(config)# interface Port-channel 1
    # 論理Port-Channelを介して一括でAllowed Listを上書き、物理へ強制同期させます
    SW2(config-if)# switchport trunk allowed vlan 10,20,30
    SW2(config-if)# end
    ```

---

### 2. 【コンフィグ読解：L3ルーテッドポートチャネルと PING 不通トラブル】
**問題:**
L3ルーテッドポートチャネルを組むために、SW1に以下のコンフィグを流し込みましたが、対向スイッチSW2（IPアドレス `19.1.1.2/30` 構成済み、UP状態）との間で PING 通信が一切成功しませんでした。
```text
SW1# configure terminal
SW1(config)# interface Port-channel 10
SW1(config-if)# no switchport
SW1(config-if)# ip address 19.1.1.1 255.255.255.252
SW1(config-if)# exit
SW1(config)# interface range GigabitEthernet1/0/3 - 4
SW1(config-if-range)# channel-group 10 mode active
```
設定を流し込んだ後の `show etherchannel summary` では、物理ポートは「Bundle」状態にならず `Suspended (s)` に留まっていました。
このコンフィグにおける**設定順序およびパラメーター上の致命的な欠陥**を指摘し、正しい構成手順を提示してください。

**解答・解説:**
*   **設定の致命的な欠陥:**
    物理メンバーポート（`interface range GigabitEthernet1/0/3 - 4`）に対して、**`no switchport` コマンドが適用されないまま**、`channel-group 10 mode active` が投入されています。
    デフォルトの Catalyst スイッチポートは Layer 2（スイッチポートアクセス）モードとして動作します。物理ポート側が L2 の属性を維持しているのに対し、論理 Port-Channel 10 側は L3（`no switchport`）属性に変更されているため、L2/L3の論理キーミスマッチ（レイヤの矛盾）を検出した LACP プロトコルが、安全のためにメンバーポートすべてを強制的にサスペンド（Suspended：一時停止）状態へと落とします。
*   **正しい構成手順:**
    1.  一度物理ポートから誤った channel-group の割り当てを除去します。
    2.  物理ポートを `no switchport` で完全にL3化した上で、Port-Channel 10 に再投入（バインディング）します。
    ```text
    SW1# configure terminal
    SW1(config)# interface range GigabitEthernet1/0/3 - 4
    SW1(config-if-range)# no channel-group 10 mode active
    # 物理インターフェイスをL3ルーテッドポートに強制変更
    SW1(config-if-range)# no switchport
    SW1(config-if-range)# channel-group 10 mode active
    SW1(config-if-range)# end
    ```

---

### 3. 【Design：StackWise Virtual (SV) 環境における Dual-Active 発生時の MEC 挙動】
**問題:**
2台のCatalyst 9500スイッチ（SW1, SW2）を StackWise Virtual (SV) 技術で統合しています。外部コアスイッチ SW3 から、これら2台に対してマルチシャーシ EtherChannel (MEC: Port-channel 100) で冗長接続されています。
ある時、SVL（StackWise Virtual Link）であるすべての専用光ファイバー（100Gリンク群）が、物理切断（ダクト破損等）により同時に喪失する「Dual-Active（スプリットブレイン）」事象が発生しました。
Dual-Active Detection（DAD）が適切に構成されていない、あるいは DAD リンクも消失していた場合、**MEC（Port-channel 100）およびネットワーク全体のルーティングトポロジーにどのような深刻な障害**が発生するかを想定し、その回避デザインを提示してください。

**解答・解説:**
*   **発生する深刻な障害:**
    1.  **スプリットブレインの発生:** SVLを喪失した SW1 と SW2 は、互いがダウンしたと誤認し、双方が「アクティブスーパーバイザ（マスタースイッチ）」として独立起動します。
    2.  **MAC/IPアドレスの衝突:** 2台の物理スイッチが、それぞれ同一の管理IPアドレス、仮想ルータMAC、および同一のルーティングプロセス（OSPF、BGPなど）で別々に制御を始めます。
    3.  **MEC への偽装送信:** 対向スイッチ SW3（MEC接続側）から見ると、`Port-channel 100` の反対側に「同一人物（仮想スイッチ）」がいると思ってARP/ルーティングパケットを送出しますが、実際は SW1 と SW2 という別々の頭脳が受信し、状態不整合とパケットの高速フラッピング（同一MAC/IPが別スイッチから送信）がバーストし、ネットワーク全体が完全に融解（ブラックホール・フラッピング化）します。
*   **回避デザイン（対策）:**
    *   **DAD（Dual-Active Detection）の確実なマルチパス設計:** 
        SVL 以外の物理ポート（例：ディストリビューションスイッチ接続用ポートや専用カッパーポート）を使用して、L2 Fast-Hello または BFD（Bidirectional Forwarding Detection）による DAD 監視リンクを構成します。
    *   **DAD 検知時のシャットダウンポリシー:**
        DAD リンクにより Dual-Active 状態が検知された瞬間、セカンダリ（一般的にスタンバイだった側）スイッチ側の物理ポートおよびMEC（Port-channel 100）を含む**すべてのダウンリンクポートをハードウェアレベルで強制シャットダウン（shutdown/閉塞）**させ、プライマリ（アクティブだった側）の1台に通信とL3アイデンティティを一括集中（局所化）させることで、トポロジーの崩壊を最小限（瞬断レベル）に食い止めます。

---

## 🔗 参考リソース

### Cisco Live (スライド・オンデマンド)
* [**BRKCRS-2031: Enterprise Campus Design: Multilayer Architectures and Design Principles**](https://www.ciscolive.com/c/dam/r/ciscolive/emea/docs/2023/pdf/BRKENS-2031.pdf)
* [**BRKENS-2614: Campus Design with Secure Networking Reference Architecture**](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2026/pdf/BRKENS-2614.pdf)
* 
### Cisco ソフトウェア設定ガイド（Configuration Guide）
*   [**Cisco Catalyst 9300 Series Switches: Software Configuration Guide, Configuring EtherChannels**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/configuring_etherchannels.html)
* [**Cisco IOS Release 15.2(4)E: Configuring EtherChannels**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst3750x_3560x/software/release/15-2_4_e/configurationguide/b_1524e_consolidated_3750x_3560x_cg/b_1524e_consolidated_3750x_3560x_cg_chapter_01000010.html)


### Cisco コマンドリファレンス
*   [**Cisco IOS XE 17.x Layer 2 Command Reference: channel-group commands**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/command_reference/b_179_9300_cr/layer_2_3_commands.html#wp1281677838)
*   [**Cisco IOS XE 17.x Layer 2 Command Reference: lacp commands**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/command_reference/b_179_9300_cr/layer_2_3_commands.html#wp2385585063)

---

## 📝 **補足（Notes）**

### EtherChannel 設計判定フローチャート（CCIE ラボ試験用）

```text
               [ 複数物理リンクの接続検出 ]
                           │
                           ▼
               [ Layer 2 or Layer 3 ? ]
               /                      \
      (Layer 2)                        (Layer 3)
         /                                \
    トランク/アクセス                    [ no switchport ] を
    ポートプロパティ一致確認              物理＋Poポートすべてに投入
         │                                │
         ▼                                ▼
  [ 動的 LACP (active) ] ────────────────► [ IPアドレスの設定 / Routing ]
  ※ Static (on) はトラブル検知不可
  のため極力使用しない
```

*   **最終チェックシート:**
    *   [ ] メンバーポートはすべて同一の「速度（1G/10G）」に揃っているか？
    *   [ ] L3 EtherChannel を構築する際、メンバーポートに対して先に `no switchport` を実行してから `channel-group` に登録したか？
    *   [ ] LACP 最大アクティブ数を制限したい場合、`lacp max-bundle` の上限値変更とともに、System-Priority と Port-Priority による「マスター/スタンバイ」の関係性を意図通りに固定したか？
    *   [ ] StackWise Virtual などのマルチシャーシ環境では、MECを跨ぐ対向スイッチ側の LACP 構成を確実に `active` に統一し、STPの再計算の影響を排除しているか？

---
🚀 **次に学習すべき推奨トピック:**
EtherChannelによる複数の物理リンクの論理集約を完璧にマスターした後は、論理ポートチャネル上でのLayer 2トポロジー制御およびループ回避を統合的に司る **「1.1.e Spanning Tree Protocol (PVST+, Rapid PVST+, MST) & Tuning」** に進むことを強く推奨します。これにより、キャンパスネットワークのL2コントロールプレーン設計に関する全体像が完成します。

