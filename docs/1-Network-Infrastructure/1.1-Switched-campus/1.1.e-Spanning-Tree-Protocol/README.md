---
layout: default
title: 1.1.e-Spanning-Tree-Protocol
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.1.e-Spanning-Tree-Protocol

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.e Spanning Tree Protocol」に関連する、各モード、パラメータ調整、および保護機能について整理しました。

---

# 1.1.e Spanning Tree Protocol (PVST+, Rapid PVST+, MST, Tuning, Guard Features)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 ラボ試験および筆記試験において、レイヤ2コントロールプレーンのコア防衛レイヤとなる **Spanning Tree Protocol（PVST+、Rapid PVST+、MST、各種チューニング、および保護機能）** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ）の実装基準に完全準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

エンタープライズのスイッチドキャンパスネットワークにおける物理的な冗長リンク（物理ループ構造）は、一期的なリンク障害に対するバックアップパスを提供する一方で、制御不可能な **ブロードキャストストーム（Broadcast Storm）**、**MACアドレス書き換えテーブル（MAC Address Table）の高速フラッピング**、および **重複フレーム（Multiple Frame Coping）** の受信を引き起こす深刻なリスクを内包しています。

これらの致命的なL2ループ障害をASIC/コントロールプレーンの両レベルで未然に防止しつつ、論理的なツリートポロジーを動的に構築する自律制御メカニズムが **Spanning Tree Protocol (STP)** です [1.1.e]。

### 1. PVST+ (Per-VLAN Spanning Tree Plus)
シスコシステムズ社が開発した、IEEE 802.1Dを拡張したシスコ独自規格です。VLANごとに個別のSTPインスタンスを生成してツリートポロジーを計算するため、特定のトランクリンクをVLAN Aではブロッキングにし、VLAN Bではフォワーディングに割り当てることで、L2マルチパッシングによるトラフィックロードシェアリング（負荷分散）を実現します。

### 2. Rapid PVST+ (IEEE 802.1w 拡張)
IEEE 802.1w（Rapid Spanning Tree Protocol）をVLANごとに適用したシスコ拡張仕様です。802.1Dにおけるタイマーベースの遅延コンバージェンス（Listen ➔ Learn ➔ Forward の計30秒から50秒の移行待ち）を完全に打破し、隣接スイッチ間での **「Proposal（提案）と Agreement（同意）」** のハンドシェイクメカニズム、ならびに代替ポート（Alternate Port）やバックアップポート（Backup Port）の即時切り替えにより、サブ秒（1秒未満）から数秒以内での超高速コンバージェンスを実現します。

### 3. MST (Multiple Spanning Tree - IEEE 802.1s)
数百、数千ものVLANが存在する大規模なネットワークにおいて、VLANごとに独立したPVST+インスタンス（PVSTのBPDU生成・CPU処理・メモリバジェット消費）を動かすことは、スイッチのCPUに対する破壊的なリソース負荷を意味します。
MSTは、複数のVLANを任意の **「論理インスタンス（Instance）」** にマッピング（集約）し、そのインスタンスごとにのみSTP（RSTP）プロセスを実行させることで、PVSTの負荷分散メリットを完全に維持したまま、スイッチのCPUオーバーヘッドを劇的にスケール（削減）します。

### 4. STP チューニング (Priority, Cost, Timers)
コントロールプレーンの最適配置およびトラフィックエンジニアリングを確立するためのチューニングパラメータです。ルートブリッジ（Root Bridge）の位置を決める **Bridge Priority**、宛先ポートを特定するための **Port Priority** / **Path Cost**、そしてトポロジーの健全性を担保する **STP Timers (Hello, Forward Delay, Max-Age)** を構成します [1.1.e (ii)]。

### 5. STP エッジ機能 (PortFast, BPDU Guard, BPDU Filter)
エンドユーザーPCやサーバーが接続されるエッジポートを保護・最適化するテクノロジーです [1.1.e (iii)]。
*   **PortFast:** L1ポートアップと同時に、Listen/Learnステートをスキップして即時に **Forwarding（転送可能）** ステートに移行させます [1.1.e (iii)]。
*   **BPDU Guard:** PortFastが有効なポートで万が一BPDUを受信した場合、そのポートにスイッチやハブが誤配線（ループ原因）されたと判断し、ポートを **`err-disabled`** 状態に落として即時隔離します [1.1.e (iii)]。
*   **BPDU Filter:** ポートでのBPDUパケットの送受信を完全に「フィルタリング（無効化）」します [1.1.e (iii)]。

### 6. STP インフラ防衛（Root Guard, Loop Guard）
中間トポロジーや物理リンクの片通信（Unidirectional Link）から、STPツリー全体の整合性を物理的・論理的に死守するための防御技術です [1.1.e (iv)]。
*   **Root Guard:** 指定した下位スイッチ接続用ポートから、現在のRoot Bridgeよりも「優位なBPDU（Superior BPDU）」を受信した場合、そのポートを一時的に **`root-inconsistent`**（ブロッキング）状態に移行させ、ルートブリッジの不正な乗っ取りを阻止します [1.1.e (iv)]。
*   **Loop Guard:** 光ファイバのTx/Rx片側ハングや対向のソフトウェアフリーズにより、トランクの「Rx（受信）」側のみでBPDUが途絶えた際、誤ってブロッキングポートをフォワーディングに変更して無限L2ループが発生するのを防ぐため、ポートを即時に **`loop-inconsistent`**（ブロッキング）に落として防衛します [1.1.e (iv)]。

---

## 🔑 要点

| 技術要素 | 項目 | 内容 |
| :--- | :--- | :--- |
| **STPモード** | **特徴** | PVST+（VLANごと1D）、Rapid PVST+（VLANごと1w：推奨）、MST（複数VLANをインスタンスへマッピング） 。 |
| | **用途** | レイヤ2イーサネット網における自律ループ自動防止、アクティブ・バックアップトポロジー 。 |
| | **メリット** | インフラの物理的な冗長性を保ちつつ、MACテーブルフラッピングやコントロールプレーンストームを完全に排除 [1.1]。 |
| | **デメリット** | PVSTは大規模網（数百VLAN以上）でスイッチのCPUに過負荷。MSTはMSTリージョンの構成不整合による「CISTブロッキング」のリスク。 |
| **STPチューニング** | **特徴** | Bridge ID (Priority ＋ System ID Extension)、Path Cost、Port Priority、Timers [1.1.e (ii)]。 |
| | **用途** | ルートブリッジの決定、特定の物理ポート（Uplink）の意図的なフォワーディング/ブロック選択 [1.1.e (ii)]。 |
| | **制限事項** | Switch Priorityは一律で **`4096` の倍数**（System ID ExtensionによるVLAN ID埋め込み用の仕様）でしか設定できない。 |
| **PortFast** | **特徴** | 接続検知（リンクUP）と同時に即時 `Forwarding` 移行。TCN (Topology Change Notification) を送出しない [1.1.e (iii)]。 |
| | **用途** | クライアントPC、サーバー、ルータ等のエンドデバイス接続。DHCPアドレスのタイムアウトを完璧に防止 [1.1.e (iii)]。 |
| | **制限事項** | スイッチ同士を接続するトランクリンク等でPortFastを動作させると、ループ防止時間が無くなるため、重大なL2ストームを招く。 |
| **BPDU Guard** | **特徴** | BPDUを受信した瞬間にポートを `err-disabled` に落とし、ポートを完全にシャットダウン（物理リンク遮断）する [1.1.e (iii)]。 |
| | **用途** | ユーザーフロアのアクセスポートへの隠れたスイッチ/ハブの持ち込み（不正延長）防止。 |
| **BPDU Filter** | **特徴** | ポートでのBPDUの送受信を一切無効化。ローカルなSTPを事実上「完全に停止」させる危険コマンド [1.1.e (iii)]。 |
| | **制限事項** | **グローバル設定（PortFast時にBPDUを受信すると標準スイッチポートに戻る）と、インターフェイス設定（無条件でBPDU送信も受信も無視し、完全にL2制御を失う）で動作が著しく異なる。** |
| **Root Guard** | **特徴** | 自機よりも優れたSuperior BPDUを受け取った際、ポートを `root-inconsistent` にする。BPDUが消えれば自動復旧する [1.1.e (iv)]。 |
| | **用途** | プロバイダPEポート、ディストリビューションスイッチから下位アクセススイッチ（CE）へ向けたポート。 |
| **Loop Guard** | **特徴** | BPDUの「サイレント消滅」時に、ブロッキングポートを転送状態にせず `loop-inconsistent` にして保護 [1.1.e (iv)]。 |
| | **制限事項** | ルーティングポートや、PortFastが動作しているアクセスポートでは動作（サポート）しない。 |

---

## 🏗 動作原理

### 1. Rapid RSTP (IEEE 802.1w) のコンバージェンスハンドシェイク
802.1w / Rapid PVST+は、タイマー（Listen/Learn各15秒）に依存せず、隣接するスイッチ間で **「Proposal（提案）」** と **「Agreement（同意）」** と呼ばれるL2フラグメッセージを交換（ハンドシェイク）することで、一瞬でフォワーディングステートに移行します。

```text
  [ Switch A (Root) ] ── ( Proposal Flag in RSTP BPDU ) ──► [ Switch B (Non-Root) ]
           │                                                         │
           │                                                         ▼
           │                                                [ Sync (同期) 処理実行 ]
           │                                                - 自身のすべての非エッジポート（Non-Edge）
           │                                                  を一時的に「ブロッキング」にする。
           │                                                - これにより、一時的なL2ループの
           │                                                  発生を物理的に100%防止。
           │                                                         │
           │◄ ── ( Agreement Flag in RSTP BPDU ) ────────────────────┘
           ▼
[ 即座に Root Port が Forwarding に移行（移行完了まで 1 秒未満） ]
```

### 2. MST (Multiple Spanning Tree) と CIST の概念
MSTは、内部（CIST: Common and Internal Spanning Tree）と外部（MST Instances）を巧妙に分割してツリーを構成します。異なるMSTリージョン同士、あるいはPVST/802.1Dレガシースイッチと接続される場合、MSTリージョン全体が **「1台の巨大な仮想スイッチ（CIST Root）」** と見なされて動作します。

```text
       [ PVST+ Domain (VLAN 10, VLAN 20) ]
                       │
                       ▼ ( CST / Common Spanning Tree で相互運用 )
┌──────────────────────┴──────────────────────┐
│  MST Region (iPexpertRegion)                │
│                                             │
│    - Instance 0: CIST (Common & Internal)   │
│    - Instance 1 (VLAN 10 ➔ Mapping)         │
│    - Instance 2 (VLAN 20 ➔ Mapping)         │
└─────────────────────────────────────────────┘
```

---

## ⚙ 動作シーケンス

### STP 保護機能（BPDU Guard / Root Guard）の内部処理シーケンス

1.  **フレーム受信:**
    アクセスポートに外部から `BPDU（Destination MAC: 01-80-c2-00-00-00）` パケットが到着します。
2.  **BPDU Guard 判定:**
    *   インターフェイスに `spanning-tree bpduguard enable`（またはPortFastかつグローバル有効化）が構成されているか確認。
    *   **一致した場合:** ポートを即座に **`err-disabled`** 状態にロックし、物理および論理リンクを遮断（DOWN / DOWN）させます。Syslogに `%SPANTREE-2-RX_PORTFAST` などのエラー警告を出力。
3.  **Root Guard 判定:**
    *   トランクポートまたはアクセスポートで `spanning-tree guard root` が構成されているか確認。
    *   受信したBPDU内の 「Root Bridge ID（優先度＋MAC）」が、現在の自機が認識しているRoot Bridgeの Bridge ID よりも **「優れている（Superior）」** か判定します。
    *   **優れている場合:** 自身のルートブリッジとしてのアイデンティティが覆るのを防ぐため、当該ポートを **`root-inconsistent`**（ブロック）状態へ移行させます。
    *   **自動復旧:** 対向の不正スイッチからのBPDU送信が途絶え、指定時間BPDUを受信しなくなると、Root Guardは自動的に `root-inconsistent` を解除し、通常フォワーディング状態へ復元させます。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、STPはトポロジーの土台であり、僅かな設定不整合や保護機能の仕様誤認がルーティング隣接（OSPF/EIGRP/BGP）の不通、SD-Accessアンダーレイの崩壊を招きます。

### 1. 「Bridge ID」計算の完璧な理解
Ciscoスイッチは、802.1t に基づく **「System ID Extension（拡張システムID）」** を採用しています。
*   `Bridge ID (8 bytes)` ＝ `Bridge Priority (2 bytes)` ＋ `MAC Address (6 bytes)`
*   ここで、`Bridge Priority` の16ビットは、**上位4ビットが「Priority値（4096の倍数）」**、**下位12ビットが「VLAN ID（0〜4095）」** としてASIC内部でマージされて動作します。
*   **試験の罠:**
    「VLAN 10において、自機 SW1 を最も優先されるルートブリッジに設定しなさい。ただし、Priority値を直接 `0` にしてはならず、セカンダリ（VLAN 10のSW2：Priority 28672）よりも明確に優位となる Priority を定義せよ」
    *   **対策:**
        `28672` より低く、かつ `0` ではない4096の倍数、すなわち `4096`、`8192`、`12288` などを設定します。
        ```bash
        spanning-tree vlan 10 priority 4096
        ```

### 2. Path Cost（パスコスト）チューニングの基準
Cisco IOS-XEでは、ポートコストの算出基準として **Short (16-bit: 802.1D互換)** と **Long (32-bit: 802.1t/1w互換：Catalyst 9000推奨)** の2つのパスコストパス（Path Cost Method）が存在します [11, Module 1; 21, 1.1.e (ii)]。
10Gbps、40Gbps、100Gbpsなどの超高速リンクが混在する現代のキャンパスインフラにおいて、Short（16-bit：10G以上は一律コスト「2」か「1」になってしまい区別できない）を使用していると、不適切な代替パスが選択される原因となります [11, Module 1; 21, 1.1.e (ii)]。
*   **試験での指示:**
    「インフラ内の10Gおよび40Gトランクリンク間のコストがASICで正しく識別され、32ビット拡張コストテーブルに基づいてMSTツリーが計算されるようにグローバルで修正せよ」
    *   **対策:**
        ```bash
        spanning-tree pathcost method long
        ```
        このグローバルコマンドにより、パスコストの計算方法がShort（デフォルトの場合あり）からLongへ変更され、10Gはコスト「2,000」、40Gは「500」、100Gは「200」のように適切にスケールされます [11, Module 1; 21, 1.1.e (ii)]。

### 3. BPDU Filter グローバル設定とインターフェイス設定の「致命的な挙動差」
この挙動の差は、トラブルシューティングおよび実装セクションで極めて頻繁に狙われます。挙動を100%正確に脳内にインプットしてください。

*   **インターフェイスで直接有効化 (`spanning-tree bpdufilter enable`)：**
    *   **動作:** ポートはリンクアップ直後も含めて、**BPDUを「1パケットも送信せず」、届いたBPDUも「完全に無視・破棄」** します。
    *   **結果:** 当該ポートは実質的にSTPドメインから「完全隔離（STP無効化）」されるため、もし対向がループ配線されていた場合、**即座にL2ストーム（無限ループ）が発生してネットワークがハングアップします**。非常に危険なコマンドです。
*   **グローバルで有効化 (`spanning-tree portfast bpdufilter default`)：**
    *   **動作:** PortFastが有効なポートがリンクアップした際、最初の約10秒間に 10 本のBPDUを送信します。その後は送信を停止します。
    *   **最も重要なセーフティ機能:** **もし、このポートに対向デバイス（別のスイッチ等）が接続され、外部からBPDUを1パケットでも受信した場合、ポートは即座に「PortFast状態およびBPDU Filter状態を自動的に解除（Fallback）」し、通常の「標準STPスイッチポート」に切り戻ります。** これによりループが自動的に回避されます。
*   **試験対策:** 「エッジポートで不必要なBPDUの定常送信は停止させつつ、万が一対向にスイッチが誤接続された場合は、即座に標準スイッチポートとしてネゴシエーションさせ、ループを防ぎなさい」という問題があれば、必ず**グローバル設定**によるBPDU Filterを構成しなければなりません。

---

## 🛠 設定方法

Cisco IOS-XE 17.xにおける、STPチューニングおよび各種保護技術の完全なCLI構成手順です。

### 1. Spanning-Tree モード（Rapid-PVST / MST）の基本設定

```bash
# [Rapid-PVST+ モードの起動]
spanning-tree mode rapid-pvst

# [MST モードの起動とリージョン、インスタンス、VLANマッピングの定義]
spanning-tree mode mst

spanning-tree mst configuration
 # MSTリージョン名の設定（大文字小文字を厳密に一致させる）
 name iPexpertRegion
 # リビジョン番号の定義（対向スイッチと一致させることが同期の絶対条件）
 revision 10
 # インスタンス1にVLAN 10,20を、インスタンス2にVLAN 30,40をマッピング
 instance 1 vlan 10, 20
 instance 2 vlan 30, 40
exit
```

### 2. Root Bridge チューニングおよび Path Cost 32-bit の設定

```bash
# パスコストの計算基準を32ビットロングモードに変更（ベストプラクティス）
spanning-tree pathcost method long

# VLAN 10 における自機のルートブリッジの強制選定（Priorityを 4096 に指定）
spanning-tree vlan 10 priority 4096

# [MST Instanceにおけるルート選定チューニング]
spanning-tree mst 1 priority 8192
```

### 3. Port/Path Cost と Port Priority によるトラフィックロードシェア設定

```bash
# 【構成A】特定のアップリンクポートのコストを変更し、迂回路（Alternate）へと追い出す
interface GigabitEthernet1/0/1
 # VLAN 10におけるこのポートのパスコストを「10,000」に引き上げ
 spanning-tree vlan 10 cost 10000

# 【構成B】ルートブリッジに直結されたデュアルアップリンクで、ポートプライオリティを調整して転送ポートを選択
# (※ポートプライオリティは「ルートブリッジ側（上位スイッチ側）」で設定した値が下位に反映されます)
interface GigabitEthernet1/0/2
 # VLAN 10におけるポートプライオリティを「64（デフォルト128、16の倍数）」に引き下げて優先リンク化
 spanning-tree vlan 10 port-priority 64
```

### 4. エッジポート防衛（PortFast, BPDU Guard, BPDU Filter グローバル/インターフェイス）

```bash
# [グローバルでの一括最適化設定（推奨）]
# すべてのアクセスポート（switchport mode access）でPortFastを自動起動
spanning-tree portfast default
# PortFast起動ポートでBPDUを受信したら即err-disableにする防衛策
spanning-tree portfast bpduguard default
# PortFast起動ポートで定常BPDU送信を止めつつ、BPDU受信時は通常STPにフォールバック
spanning-tree portfast bpdufilter default

# [特定の個別インターフェイスにおける明示的無効/有効制御]
interface GigabitEthernet1/0/10
 switchport mode access
 switchport access vlan 10
 # インターフェイス固有のPortFastエッジ化
 spanning-tree portfast trunk
 # インターフェイス固有のBPDU Guard強制有効化
 spanning-tree bpduguard enable
```

### 5. インフラストラクチャ防衛（Root Guard, Loop Guard）

```bash
# [グローバルでの Loop Guard 一括有効化（全トランクポートに自動適用）]
spanning-tree loopguard default

# [個別インターフェイスにおけるRoot Guard（下位アクセススイッチ向けトランクに設定）]
interface GigabitEthernet1/0/20
 description TO_ACCESS_SWITCH_SW3
 switchport mode trunk
 # ルートブリッジ乗っ取り防止ガードのバインド
 spanning-tree guard root
```

---

## 🔍 検証コマンド

STPトポロジーの計算結果、ポートステート、および保護状態を正確に追跡・監査するためのコマンド体系です。

| 目的 | コマンド |
| :--- | :--- |
| **STP全体の動作モード、ルートブリッジ情報、各VLAN/インスタンスのサマリー確認** | <code>show spanning-tree summary</code> |
| **特定のVLAN（VLAN 10）におけるルートID、自機Bridge ID、全ポートのSTPステート一覧確認** | <code>show spanning-tree vlan 10</code> |
| **MSTのインスタンスマッピング状態、リージョン整合情報、CISTルートの確認** | <code>show spanning-tree mst</code> / <code>show spanning-tree mst configuration</code> |
| **特定の物理ポートに対するSTPタイマー、ポートコスト、ガード機能（Root/Loop等）の動作詳細** | <code>show spanning-tree interface GigabitEthernet1/0/1</code> |
| **現在 Root Guard によってブロッキング（root-inconsistent）に落とされているポートの一覧確認** | <code>show spanning-tree inconsistentports</code> |
| **現在 err-disable 状態に落ちているポートと、その原因（bpduguard 等）の一覧確認** | <code>show interfaces status err-disabled</code> |
| **RSTP（Proposal/Agreementハンドシェイク）やMSTパケット処理プロセスのリアルタイム追跡** | <code>debug spanning-tree mst</code> / <code>debug spanning-tree switch</code> / <code>debug spanning-tree events</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **エンドユーザーPCがリンクアップしてからDHCPのIPアドレス取得に失敗する、あるいはPXEネットワークブートがタイムアウトする。** | スイッチの接続ポートで **`PortFast` が無効**になっており、標準STPのListen/Learnタイマー（計30秒）によるパケットフォワーディング遅延が発生している。 | `show spanning-tree interface <interface>` | 対象ポートに遷移し、`spanning-tree portfast`（または `spanning-tree portfast trunk`）を設定して即時Forwarding移行を有効化する [12; 21, 1.1.e (iii)]。 |
| **スイッチを冗長トランクで追加した瞬間、MSTの特定のポートが「BNDL」（Bundle/不整合）としてブロッキング状態にロックされ、通信できない。** | 追加された対向スイッチと、既存スイッチとの間で **「MST リージョン設定（Name, Revision, VLAN Instance マッピング）」が1文字、または1つのVLAN指定でも異なっている**。 | `show spanning-tree mst configuration` | `spanning-tree mst configuration` モードに入り、両端の `name`、`revision`、および `instance` マッピング設定を寸分違わず完全に一致させる。 |
| **ポートが「err-disabled」に遷移し、Syslogに「%SPANTREE-2-BLOCK_BPDUGUARD」が検出された。** | 1. ユーザーフロアのアクセスポートに、誤ってハブや別のスイッチが接続された。<br>2. ループが発生し、自身から送出したBPDUが周り回って戻ってきた。 | `show interfaces status err-disabled`<br>`show logging` | 1. 誤配線（ループ原因スイッチ）を取り外す。<br>2. 特権EXECから `errdisable recovery cause bpduguard` および `errdisable recovery interval 30` を用いて、自動検知リカバリを定義する。 |
| **トランクポートが「*LOOP_Inc」（Loop Inconsistent）として、STPプロセスによって完全にブロックされる。** | 単一方向リンク（Unidirectional Link）障害、または過負荷により対向スイッチからの **BPDU Hello が Max-Age（デフォルト20秒）の期間完全に途絶えた**。 | `show spanning-tree interface <port>` | 1. 光ファイバまたはSFPトランシーバの物理ハードウェア障害を特定し、交換する。<br>2. 物理的な片方向リンク障害（UDLDによるerr-disable閉塞）が正しく構成されているかUDLD設定を再点検する。 |

---

## ⚠ 制限事項

### 1. Bridge Priority のステップサイズ制限（12-bit Extended System ID 依存）
*   拡張システムIDの物理仕様により、Bridge Priority は `0`、`4096`、`8192`、`12288`、`16384`、`20480`、`24576`、`28672`、`32768`（デフォルト）、`36864`、`40960`、`45056`、`49152`、`53248`、`57344`、`61440` のように、**必ず4096のステップサイズでしかアサインできません。**
*   これ以外の数値を投入しようとすると、Cisco IOS-XE CLIは構成入力をエラーとして直ちに却下します。

### 2. MST インスタンス数およびサポートVLAN限界
*   MSTがサポートするMSTインスタンスの最大数は、Ciscoプラットフォームにおいて **Instance 0 から 64 まで（実質最大65インスタンス）** です。
    *   **Instance 0 (CIST):** 常にデフォルトでシステム内部、およびリージョン間ツリー全体の集約・接続用として動作。
    *   **Instance 1 - 64:** ユーザー定義のVLANマッピングにのみ使用可能。

### 3. PortFast とポートセキュリティ/802.1X認証との併用
*   ポートで dot1x（802.1X認証）またはMAB（MAC認証バイパス）を動作させ、かつPortFastを有効にしている場合、物理レイヤがアップした瞬間にポートは即座にフォワーディング（PortFast）になりますが、認証エンジン（AAA）が認証判定を完了するまでの数秒間は、トラフィックは認証制御プレーンによってブロックされます [23, 4.2.a]。

---

## 🔄 他技術との関連

*   **EtherChannel (802.3ad LACP):**
    EtherChannelを使用すると、STPは束ねられた物理メンバーリンク群を「1つの仮想ポートチャネル（Poポート）」として認識してスパニングツリー計算を実行します。これにより、物理的にループしている複数リンクであっても、STPによる不要なブロッキングポート（Discarding）が発生せず、全ポートの帯域（ロードバランシング）をフル活用できます [12, 1.1.d]。
*   **UDLD (UniDirectional Link Detection):**
    UDLDとSpanning-Treeの Loop Guard は、トランスポート防御において相互補完（シールド）関係にあります。
    *   **Loop Guard:** スイッチのCPU高負荷やソフトウェア（IOSプロセス）ハングによるBPDUパケットの不定期消失を、STP状態遷移から検知してブロック状態へ落とします。
    *   **UDLD:** 光ファイバーのTx芯断線、物理的なSFPハードウェア故障による片通信アップ状態を、L2キープアライブ（Hello）信号の応答停止から直接判定してポートを物理的に閉塞します。
*   **VTP (VLAN Trunking Protocol):**
    VTPのモードを「VTP v3」に構成することで、MSTのインスタンスマッピング構成情報（Name, Revision, Mapping table）を、1台のPrimary ServerからVTPドメイン内のすべてのスイッチへ完全に、かつ安全に自動同期させることができます。これにより、MST構成不整合（CIST不整合）による通信寸断を完全に防止することができます。

---

## 🧩 比較表

### 1. PVST+ vs Rapid PVST+ vs MST

| 比較項目 | PVST+ (IEEE 802.1D ベース) | Rapid PVST+ (IEEE 802.1w ベース) | MST (IEEE 802.1s) |
| :--- | :--- | :--- | :--- |
| **コンバージェンス速度** | **遅い** (Listen/Learn遅延により、30〜50秒を要する) | **非常に高速** (Proposal/Agreementハンドシェイクにより秒未満) | **非常に高速** (内部でRSTPエンジンが動いているため秒未満) |
| **スイッチCPU/メモリ負荷** | **極めて高い** (VLANの数だけSTPインスタンスを生成・計算するため) | **極めて高い** (Rapid BPDUをVLANごとに生成・計算するため) | **極めて低い** (マッピングされたインスタンス数分の計算のみ。通常数個) [11, Module 1]。 |
| **マルチパッシング（負荷分散）** | 可能 (VLAN単位でRoot Bridgeを分散配置) | 可能 (VLAN単位でRoot Bridgeを分散配置) | 可能 (MSTインスタンス単位でRoot Bridgeを分散配置) |
| **トポロジー変更(TCN)の影響** | TCNはスイッチドメイン全体に伝搬し、MACアドレステーブルを高速消去 | エッジポートを除き、トポロジー変更は隣接ポート間で局所的に即時伝搬 | TCNはリージョン内（IST）とリージョン間で高度に隠蔽・統合 |

### 2. Root Guard vs Loop Guard

| 比較項目 | Root Guard | Loop Guard |
| :--- | :--- | :--- |
| **主な防御対象** | 不正に優位な優先度を持つ外部スイッチ（Superior BPDU）による、ルートブリッジ位置の不正奪取 [12; 21, 1.1.e (iv)]。 | 片方向リンク障害、または対向側のCPUハングによるBPDU途絶に伴う、不適切な転送（Forwarding）状態移行によるループ [21, 1.1.e (iv)]。 |
| **適用インターフェイス** | **指定（Designated）ポート**（下位のアクセススイッチやCEスイッチが接続されている下向きポート）。 | **非指定（Non-Designated/Alternate）ポート**、または **ルート（Root）ポート** [21, 1.1.e (iv)]。 |
| **移行する遮断ステート** | **`root-inconsistent`** [12; 21, 1.1.e (iv)] | **`loop-inconsistent`** [21, 1.1.e (iv)] |
| **復旧プロセス** | 対向からのSuperior BPDU送信が途絶えると、**STPタイマーの満了後に自動復旧**。 | 対向から再度通常のBPDUを受信し始めた瞬間に、**自動復旧**。 |

---

## 💡 ベストプラクティス

1.  **インフラ全体での Spanning-Tree Mode の統一 (Rapid-PVST+ または MST):**
    コンバージェンスの高速化（サブ秒）を完全に維持するため、キャンパス全体のSpanning-Treeモードは必ず `rapid-pvst`（または `mst`）に統一し、レガシーな1D（モード `pvst`）の混在を排除します [11, Module 1]。
2.  **ルートブリッジおよびセカンダリルートブリッジの決定論的配置 (Deterministic Root Placement):**
    ネットワークの中央となるディストリビューションスイッチやコアスイッチ（Catalyst 9500/9600）を明示的にプライマリルート（Priority: `4096`）およびセカンダリルート（Priority: `8192`）として静的に固定します。デフォルトプライオリティ（32768）のまま放置すると、アクセスレイヤースイッチ（エッジ）が誤ってルートブリッジになり、L2フォワーディングパスが歪んで帯域幅の無駄や遅延を招きます [11, Module 1; 21, 1.1.e (ii)]。
3.  **アクセスレイヤーPCポートでの PortFast ＋ BPDU Guard の絶対セット構成:**
    ユーザーPCやプリンタが収容されるエッジポートでは、ポートを瞬時にUPさせるため `spanning-tree portfast` を構成します。これと同時に、不要なスイッチの持ち込みによる不意なトポロジー汚染を完全に遮断するため、必ず `spanning-tree bpduguard enable` をセットでバインド（構成）してください [12; 21, 1.1.e (iii)]。
4.  **下向きポートでの Root Guard の徹底:**
    コア・ディストリビューションスイッチからアクセスレイヤ（下位）へ伸びるトランク/アクセスポートには `spanning-tree guard root` を構成し、エッジ側の設定ミスやバグによるルートブリッジ乗っ取りの影響をコアドメインから完全に保護（遮断）します [12; 21, 1.1.e (iv)]。

---

## 📝 ラボ学習・設定サンプル例

CCIE EIラボ実技試験、および実機検証にダイレクトに対応する、省略なしの厳格な11の設定シナリオです。

### 1. PVST+ から Rapid-PVST+ への高速コンバージェンス移行
**【問題】**
SW1およびSW2において、Spanning-Treeモードをレガシーな1Dベースから、IEEE 802.1w拡張規格（Rapid PVST+）へ移行し、コンバージェンス時間をサブ秒レベルに高速化してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# STPモードをRapid PVST+に強制変更
SW1(config)# spanning-tree mode rapid-pvst
SW1(config)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# spanning-tree mode rapid-pvst
SW2(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree summary
# 出力に「Spanning tree mode is rapid-pvst」が表示されていることを確認します。
```

---

### 2. MST (Multiple Spanning Tree) リージョンおよび複数インスタンス同期
**【問題】**
SW1とSW2において、MSTを構成してください。
*   リージョン名: `CCIE_FABRIC`
*   リビジョン番号: `15`
*   インスタンス1（VLAN 10, VLAN 20をマッピング）
*   インスタンス2（VLAN 30, VLAN 40をマッピング）
*   すべての物理トランクリンクをMSTに参加させて構成を同期してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vlan 10,20,30,40
SW1(config-vlan)# exit
SW1(config)# spanning-tree mode mst
SW1(config)# spanning-tree mst configuration
SW1(config-mst)# name CCIE_FABRIC
SW1(config-mst)# revision 15
SW1(config-mst)# instance 1 vlan 10, 20
SW1(config-mst)# instance 2 vlan 30, 40
SW1(config-mst)# exit
SW1(config)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# vlan 10,20,30,40
SW2(config-vlan)# exit
SW2(config)# spanning-tree mode mst
SW2(config)# spanning-tree mst configuration
SW2(config-mst)# name CCIE_FABRIC
SW2(config-mst)# revision 15
SW2(config-mst)# instance 1 vlan 10, 20
SW2(config-mst)# instance 2 vlan 30, 40
SW2(config-mst)# exit
SW2(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree mst configuration
# リージョン名「CCIE_FABRIC」、リビジョン「15」、および指定インスタンスにVLANが正しくマップされていることを確認します。
```

---

### 3. Bridge Priority によるプライマリルート/セカンダリルートの静的固定
**【問題】**
MSTインスタンス1において、SW1が絶対に「Primary Root Bridge（優先度最小の第1ルート）」になり、SW2が「Secondary Root Bridge（バックアップ用の第2ルート）」となるように、Priorityを調整して静的に固定してください。なお、SW1のPriority値は `4096`、SW2は `8192` としてください。

**【SW1 設定】**
```bash
SW1# configure terminal
# インスタンス1のPriorityを4096に固定
SW1(config)# spanning-tree mst 1 priority 4096
SW1(config)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
# インスタンス1のPriorityを8192に固定
SW2(config)# spanning-tree mst 1 priority 8192
SW2(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree mst 1
# 「This bridge is the root」が表示され、自機優先度が「4096 ＋ インスタンス番号1 ➔ 4097」になっていることを確認します。
```

---

### 4. 物理パスコスト（Path Cost）の32-bit Longチューニングと特定トランクコストの引き上げ
**【問題】**
SW1において、物理インターフェイスの帯域に応じた最適なパスコスト計算を保証するため、グローバルでパスコストの計算法を「Long（32-bit）」に変更してください。また、トランクポート `GigabitEthernet1/0/2` における MST インスタンス2 のパスコストを、明示的に `50000` に設定して迂回トラフィック（Alternate）になるよう調整してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# パコスト計算方式をLongへグローバル変更
SW1(config)# spanning-tree pathcost method long
SW1(config)# interface GigabitEthernet1/0/2
# 特定インスタンス2のポートコストを変更
SW1(config-if)# spanning-tree mst 2 cost 50000
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree interface GigabitEthernet1/0/2 mst 2
# コスト欄に「50000」が反映され、パスコスト計算法がLongになっていることを確認します。
```

---

### 5. Port Priority（ポートプライオリティ）チューニングによる特定リンクの優先化
**【問題】**
SW1（Root Bridge）とSW2は、2本の物理トランクリンク（Gi1/0/3, Gi1/0/4）で直結されています。
*   通常状態では、より若いポートIDである `Gi1/0/3` が優先フォワーディングになります。
*   しかし、これを変更し、**`Gi1/0/4` 側を優先（Forwarding）とし、`Gi1/0/3` 側を代替（Alternate Blocking）** にしてください。
*   優先度の変更は、ルートブリッジである **SW1 側の VLAN 10 ポートプライオリティ** を調整することで実装してください。

**【SW1 (Root Bridge) 設定】**
```bash
SW1# configure terminal
interface GigabitEthernet1/0/4
 # 優先させたい方のポートプライオリティを「64」（デフォルト128、16のステップ数）に引き下げて優先化
 spanning-tree vlan 10 port-priority 64
SW1(config-if)# end
```

**【検証方法】**
対向であるSW2（Non-Root）側で、意図通りにフォワーディング状態がシフトしているかを確認します。
```bash
SW2# show spanning-tree vlan 10
# Gi1/0/4 が 「FWD」（Forwarding）、Gi1/0/3 が「Altn BLK」（Alternate Blocking）になっていることを確認します。
```

---

### 6. STP タイマーの変更（Root Bridge限定適用タイマー調整）
**【問題】**
トポロジー全体のSTPコンバージェンスにバッファを持たせるため、Root BridgeであるSW1において、VLAN 20の各種タイマー（Hello：3秒、Max-Age：24秒、Forward Delay：18秒）を変更してください。

**【SW1 (Root Bridge) 設定】**
```bash
SW1# configure terminal
SW1(config)# spanning-tree vlan 20 hello-time 3
SW1(config)# spanning-tree vlan 20 max-age 24
SW1(config)# spanning-tree vlan 20 forward-time 18
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree vlan 20
# 出力の上部のRootタイマー定義に「Hello 3, Max-Age 24, Forward-Delay 18」が定義されていることを確認します。
```

---

### 7. アクセスポートにおける PortFast および BPDU Guard の同時起動
**【問題】**
SW1のエッジポート `GigabitEthernet1/0/10` にPCを収容します。ポートの迅速な立ち上げ（PortFast）を有効にし、さらに不要な外部スイッチが接続された場合に備えてBPDU Guardを有効化し、受信時にポートを `err-disabled` で即時遮断できるように設定してください。

**&【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/10
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 10
# エッジ用の即時フォワーディングをバインド
SW1(config-if)# spanning-tree portfast
# BPDU検知時の err-disable 保護を構成
SW1(config-if)# spanning-tree bpduguard enable
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree interface GigabitEthernet1/0/10 portfast
# Portfastが「Enabled」になっていることを確認します。
```

---

### 8. セキュアな BPDU Filter（グローバル設定による通常STPフォールバック型）
**【問題】**
SW1のエッジポートにおいて、定常状態での無駄なBPDUの送信を完全に停止（BPDU Filter）させてください。ただし、万が一、このポートにユーザーがスイッチを誤接続した（外部からBPDUを検出した）場合は、BPDU Filterを自動的に無効化（フォールバック）して標準のSTP動作に戻し、ループが発生するのを自律的に防止する設定をグローバルで行ってください。

**【SW1 設定】**
```bash
SW1# configure terminal
# 1. すべてのアクセスポートを対象にPortFastを自動有効化
SW1(config)# spanning-tree portfast default
# 2. PortFastポートを対象に、自動フォールバック機能付きのBPDU Filterをグローバル適用
SW1(config)# spanning-tree portfast bpdufilter default
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree summary
# 「Portfast Default is enabled」および「Portfast Edge BPDU Filter Default is enabled」を確認します。
```

---

### 9. Root Guard（ルートガード）の指定トランクへの適用
**【問題】**
SW1はコアドメインのRoot Bridgeです。下位スイッチSW3が接続されているインターフェイス `GigabitEthernet1/0/20` において、下位側で意図しないBridge Priorityの変更があってもコアドメインのルートブリッジアイデンティティを死守するため、Root Guardを設定してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/20
SW1(config-if)# description TO_ACCESS_SW3_TRUNK
SW1(config-if)# switchport mode trunk
# ルートの乗っ取りを阻止する保護機能
SW1(config-if)# spanning-tree guard root
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree interface GigabitEthernet1/0/20 detail
# ポート保護機能として「Root Guard is enabled」が表示されることを確認します。
```

---

### 10. Loop Guard（ループガード）による単一方向リンク障害からのトランク保護
**【問題】**
SW1とSW2を結ぶすべてのトランクポートにおいて、物理・ソフトウェア起因の片側通信（BPDU途絶）に伴う、ブランキング状態ポートのフォワーディング遷移（無限ループ誘発）を未然に防止するため、Loop Guardを一括で有効化してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# グローバル設定により、すべての物理トランクインターフェイスでLoop Guardを自動適用
SW1(config)# spanning-tree loopguard default
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree summary
# 「Loopguard Default is enabled」が構成に反映されていることを確認します。
```

---

### 11. MST（Multiple Spanning Tree）環境における Root Guard のバインディング
**【問題】**
MST（Multiple Spanning Tree）モードを運用しているSW1において、顧客スイッチCE1と接続される境界トランクポート `GigabitEthernet1/0/24` に対してRoot Guardを適用してください。この設定により、MST Instance 1 および 2 のいずれかでCE1からSuperior BPDUを受信したとしても、該当ポートのみを一時閉塞（root-inconsistent）させなさい。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/24
SW1(config-if)# description CONNECT_TO_CUSTOMER_CE1
SW1(config-if)# switchport mode trunk
# MST環境でも同一コマンドで全インスタンスを自動防衛します
SW1(config-if)# spanning-tree guard root
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show spanning-tree inconsistentports
# Superior BPDU検知時に、該当ポートがインスタンスごとに inconsistent 状態としてここにリストされることを確認します。
```

---

## ❓ 想定試験問題

CCIE EI実技試験、記述、および設計（CCDE/Diagnostic）セクションに対応するExpert問題です。

### 1. 【コンフィグ読解：BPDU FilterとBPDU Guardの致命的な競合】
**問題:** 
スイッチ SW1 のあるポートに対して、以下のコンフィグレーションを流し込みました。この状態でポートにハブを誤接続し、ユーザーPC同士をループ接続した場合に発生する**トポロジー上の致命的な動作不良**を、Cisco Spanning-Treeの内部パケット処理仕様に基づいて論理的に説明してください。
```text
interface GigabitEthernet1/0/10
 switchport mode access
 switchport access vlan 10
 spanning-tree portfast
 spanning-tree bpduguard enable
 spanning-tree bpdufilter enable
```

**解答・解説:**
*   **発生する致命的動作不良:**
    このポート配下でループが発生しても、**BPDU Guardによる自動閉塞（err-disable）は「100%機能せず」、結果として壊滅的なレイヤ2ループ（ブロードキャストストーム）が発生** します。
*   **技術的根拠:**
    Cisco IOS-XEの優先順位仕様として、インターフェイスレベルで直接有効化された **`spanning-tree bpdufilter enable`** は、他のすべてのSTP制御に優先します。この設定下では、ASICは当該ポートにおいてBPDUの送信を完全に停止するだけでなく、対向側から届いたすべてのBPDUパケットをコントロールプレーンに上げずに **「物理レシーバー（ASIC入力段階）で即時破棄」** します。
    BPDU Guard（`spanning-tree bpduguard enable`）は、届いたBPDUパケットを受信（インプレス検知）したことをトリガーにして err-disable を引き起こす仕組みであるため、BPDU FilterによってBPDU自体が完全に消去（無視）されてしまうこの環境下では、BPDU Guardプロセスは一切パケットを検出できません。したがって、ポートはフォワーディング（転送中）のまま維持され、ブロードキャストストームを無限にフラッディングしてスイッチ全体のCPUとMAC学習テーブルを破壊します。
    *   **結論:** インターフェイス固有の `bpdufilter enable` と `bpduguard enable` の併用は絶対に避けるべき設計禁忌（競合不整合）です。

---

### 2. 【トラブルシュート：MSTリージョン結合不全に伴う意図しないルート選定】
**問題:** 
SW1 と SW2 を2本の 10G トランクポート（Gi1/0/1, Gi1/0/2）で接続し、両スイッチにおいて MST（Multiple Spanning Tree）を有効にしました。
SW1側の Priority を `4096` にし、SW2側を `32768` に設定したため、設計上は SW1 が MST インスタンス 1 のルートブリッジになるはずでした。
しかし、SW2で `show spanning-tree mst 1` を確認したところ、Gi1/0/1、Gi1/0/2 の両ポートがブロッキング状態にはならず、片方が `Root FWD`、もう片方が `Alternate BLK` となる通常のツリーは確立されたものの、自スイッチ SW2 の MST 1 トポロジー内に SW1（Priority 4096）の情報が反映されず、自機が独自にルートを宣言していました。
物理トランクリンクは健全（up/up）かつ、VLAN 10 のデータ通信は可能である場合、何が原因でこのトポロジーの孤立（結合不全）が起きているのか、確認すべきコマンドと原因特定の技術プロセスを説明してください。

**解答・解説:**
*   **根本原因（MST Region 構成情報のミスマッチ）:**
    SW1 と SW2 の間で、**MSTリージョンの属性（1: Name、2: Revision、3: VLAN-to-Instance Mappingテーブル）が一致していません。**
    MSTは、これら3つの属性をMD5値にハッシュ化し、MST-BPDU内の「MST Configuration Identifier」フィールドに埋め込んでやり取りします。両スイッチ間でこれらの設定が1文字でも、あるいは1つのVLANの割り当てでも異なっている場合、両スイッチは互いを「異なるリージョン（Boundary）」と判断します。
    異なるリージョン間では、MSTはインスタンス固有の詳細なツリー（MSTI）情報を一切アドバタイズせず、リージョン全体を「1台の標準スイッチ」として扱う **CIST（Common and Internal Spanning Tree）** による単純なL2境界（802.1D CST互換）トポロジー計算しか行いません。そのため、SW2の内部プロセス内ではリージョン内インスタンス1（MST 1）の優位なBPDU情報（SW1: 4096）が受け入れられず、SW2が自身のインスタンス1で独自のルート（孤立）となっていました。
*   **確認コマンドと修復方法:**
    1.  両スイッチで `show spanning-tree mst configuration` を実行し、マッピング構成、リージョン名（大文字小文字の一致）、およびリビジョン（Revision）を比較・点検します。
    2.  `spanning-tree mst configuration` 配下のパラメーターを完全に同期（一致）させます。

---

### 3. 【Design：MSTP と RPVST+ の相互接続ポートにおける境界ブロック設計】
**問題:** 
全社的なインフラの移行期（Migration）において、本社のコアスイッチ群（SW1, SW2：MSTPを運用）と、特定の地方ブランチのレガシースイッチ（SW3, SW4：Rapid PVST+を運用）を冗長L2トランクで相互接続する設計要件が定義されました。
この異なるSpanning-Treeドメインが接続された境界（Boundary）において、トポロジーの意図しない再計算による通信瞬断やループを防ぎ、かつ、**本社コアスイッチ側（MSTP）が常に優先Rootブリッジの権利を維持する**ための、STPパラメータ配置およびインターフェイス保護（Guard）の配置案を設計して提示せよ。

**解答・解説:**
*   **設計提案（MSTP - RPVST+ 相互接続境界デザイン）:**
    1.  **VLAN 1 の整合性と Root の配置:**
        MSTリージョンと PVST+ ドメインの間で Spanning-Tree の整合性を保つには、**VLAN 1 の CST（Common Spanning Tree）ルートを必ず MSTP ドメイン側（本社コア SW1/SW2）に配置** します。
        *   **理由:** PVST+ 側が全体（VLAN 1）のルートになってしまうと、MST側はリージョン境界ポートですべてのMSTインスタンスをPVSTのVLAN 1のトポロジーに追従（バインド）させなければならず、MSTによる高度な負荷分散やトラフィック設計が無効化されます。
        *   **アクション:** SW1 の CIST（MST Instance 0）およびすべてのMSTインスタンスの Priority を、SW3/SW4 のどのVLAN Priorityよりも低く（例：`4096`）構成します。
    2.  **境界（Boundary）インターフェイスにおける Root Guard のバインド:**
        SW1/SW2 の地方ブランチ（RPVST+）スイッチへ伸びる接続用ポートに対して、**`spanning-tree guard root`（Root Guard）を明示的に構成** します [12; 21, 1.1.e (iv)]。
        *   **理由:** 地方ブランチ（SW3/SW4）側の設定誤りにより、誤って低いPriority値を持つVLAN-BPDUがトランクを流れて本社コアドメインへ入力された際、Root Guardが境界ポートを `root-inconsistent` にすることで、本社コアドメイン全体のSTPトポロジーが巻き込まれて再計算（TC伝搬・ストーム）を起こすのを即座に防止します [12; 21, 1.1.e (iv)]。
    3.  **Path Cost Method のLong（32-bit）統一:**
        境界トランクが10Gリンクであるため、両ドメイン内のすべてのスイッチにおいて `spanning-tree pathcost method long` を構成し、高速トランク間のコスト不整合（PVST側の16ビットによるコスト「2」とMST側の10Gコストの矛盾）に起因するAlternateのミスマッチを完璧に排除します [11, Module 1; 21, 1.1.e (ii)]。

---

## 🔗 参考リソース

### Cisco Live (スライド・オンデマンド)
* [**BRKCRS-2031: Enterprise Campus Design: Multilayer Architectures and Design Principles**](https://www.ciscolive.com/c/dam/r/ciscolive/emea/docs/2023/pdf/BRKENS-2031.pdf)
* [**BRKENS-2614: Campus Design with Secure Networking Reference Architecture**](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2026/pdf/BRKENS-2614.pdf)
* 
### Cisco ソフトウェア設定ガイド（Configuration Guide）
*   [**Cisco Catalyst 9300 Series Switches: Software Configuration Guide, Configuring Spanning Tree Protocol**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/configuring_spanning_tree_protocol.html)
*   [**Cisco Catalyst 9300 Series Switches: Software Configuration Guide, Configuring Multiple Spanning-Tree Protocol**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/configuring_multiple_spanning_tree_protocol.html)
* [**Cisco IOS Release 15.2(4)E: Configuring Spanning Tree Protocol**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst3750x_3560x/software/release/15-2_4_e/configurationguide/b_1524e_consolidated_3750x_3560x_cg/b_1524e_consolidated_3750x_3560x_cg_chapter_0111111.html)


### Cisco コマンドリファレンス
*   [**Cisco IOS XE 17.x Layer 2 Command Reference: spaning-tree commands**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/command_reference/b_179_9300_cr/layer_2_3_commands.html#wp3460565461)


### テクニカルノート・設計ホワイトペーパー
*   [**スパニングツリーPortFastおよびBPDUガード機能の理解**](https://www.cisco.com/c/ja_jp/support/docs/lan-switching/spanning-tree-protocol/10586-65.html)
*   [**CatalystスイッチでのSTP問題のトラブルシューティング**](https://www.cisco.com/c/ja_jp/support/docs/lan-switching/spanning-tree-protocol/28943-170.html)
*   [**STP問題のトラブルシューティングと設計上の考慮事項**](https://www.cisco.com/c/ja_jp/support/docs/lan-switching/spanning-tree-protocol/10556-16.html)
*   [**Campus LAN and Wireless LAN Solution Design Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-campus-lan-wlan-design-guide.html)

---

## 📝 **補足（Notes）**

### Spanning-Tree 保護機能（エッジ＆インフラ）一発チェックマトリクス

ラボ試験で要件を誤認して失点しないための、各保護機能の構成場所と動きのセルフチェックシートです。

```text
                        [ Root Bridge ]
                               │
                               ▼ (Designated Port)
                               │  ➔ 【Root Guard】 を設定 (下位からの Superior BPDU をブロック) [12; 21, 1.1.e (iv)]
                               ▼
                        [ Alternate Port ] (Blocking)
                               │  ➔ 【Loop Guard】 を設定 (対向からの BPDU 消失時にブロック維持) [21, 1.1.e (iv)]
                               ▼
                        [ Access Port ] (Edge)
                                  ➔ 【PortFast】 + 【BPDU Guard】 をセット設定 (PCの即時UP ＋ 外部ハブの接続時閉塞) [12; 21, 1.1.e (iii)]
```

*   **最終チェック項目:**
    *   [ ] すべての PC ポートに対して `portfast` エッジとともに `bpduguard enable` が適用されているか？（ハブ持ち込み保護が完了しているか？） [12; 21, 1.1.e (iii)]
    *   [ ] 下位スイッチが接続された Designated トランクに対して、`spanning-tree guard root`（ルートガード）が適切に構成されているか？（ルート乗っ取り防衛が完了しているか？） [12; 21, 1.1.e (iv)]
    *   [ ] レイヤ2ネットワーク内の高速リンク（10G以上）で、パスコスト基準が Long（32-bit）として `spanning-tree pathcost method long` で統一されているか？ [11, Module 1; 21, 1.1.e (ii)]
    *   [ ] MST環境で対向スイッチを新たに追加した際、リージョン名、リビジョン、インスタンスマッピングが寸分違わず完全に一致しているか？

---
💡 **次に学習すべきトピックの推薦:**
Spanning-Tree による L2 コントロールプレーンの保護および最適化チューニングを完璧に理解した後は、レイヤ2の境界を完全に終了させ、IPルーティングの高速障害検知をミリ秒単位で制御するダイナミックコントロールテクノロジーである **「1.2.j Bidirectional Forwarding Detection (BFD)」** に進むことをお勧めします。これにより、L2（STP/UDLD）とL3（BFD/ルーティング）を統合した超高速復旧ネットワーク（ハイアベイラビリティ）設計が完成します。

### 本項目で使用するコマンド

```md
# ===============================
# STP モード設定（PVST+ / Rapid-PVST+ / MST）
# ===============================

Switch1(config)# ! Rapid-PVST+ を有効化
Switch1(config)# spanning-tree mode rapid-pvst

Switch1(config)# ! PVST+ を有効化
Switch1(config)# spanning-tree mode pvst

Switch1(config)# ! MST を有効化
Switch1(config)# spanning-tree mode mst


# ===============================
# MST 設定（リージョン名 / リビジョン / VLAN マッピング）
# ===============================

Switch1(config)# ! MST 設定モードへ
Switch1(config)# spanning-tree mst configuration
Switch1(config-mst)# name CCIE_REGION
Switch1(config-mst)# revision 10
Switch1(config-mst)# instance 1 vlan 10,20
Switch1(config-mst)# instance 2 vlan 30,40
Switch1(config-mst)# exit


# ===============================
# Root Bridge / Secondary Root 設定
# ===============================

Switch1(config)# ! VLAN 10 の Root Bridge に設定
Switch1(config)# spanning-tree vlan 10 root primary

Switch1(config)# ! VLAN 10 の Secondary Root に設定
Switch1(config)# spanning-tree vlan 10 root secondary


# ===============================
# Bridge Priority 設定
# ===============================

Switch1(config)# ! VLAN 10 の Bridge Priority を 4096 に設定
Switch1(config)# spanning-tree vlan 10 priority 4096


# ===============================
# Port Priority 設定
# ===============================

Switch1(config-if)# ! ポートの Port Priority を 64 に設定
Switch1(config-if)# spanning-tree port-priority 64

Switch1(config-if)# ! VLAN 10 の Port Priority を 64 に設定
Switch1(config-if)# spanning-tree vlan 10 port-priority 64


# ===============================
# Path Cost 設定
# ===============================

Switch1(config-if)# ! ポートの Path Cost を 200 に設定
Switch1(config-if)# spanning-tree cost 200

Switch1(config-if)# ! VLAN 10 の Path Cost を 300 に設定
Switch1(config-if)# spanning-tree vlan 10 cost 300

Switch1(config)# ! Path Cost 計算方式を Long（32-bit）に変更
Switch1(config)# spanning-tree pathcost method long


# ===============================
# STP タイマー設定（Hello / Forward Delay / Max Age）
# ===============================

Switch1(config)# ! VLAN 20 の Hello タイマーを 3 秒に設定
Switch1(config)# spanning-tree vlan 20 hello-time 3

Switch1(config)# ! VLAN 20 の Forward Delay を 18 秒に設定
Switch1(config)# spanning-tree vlan 20 forward-time 18

Switch1(config)# ! VLAN 20 の Max Age を 30 秒に設定
Switch1(config)# spanning-tree vlan 20 max-age 30


# ===============================
# PortFast / BPDU Guard / BPDU Filter
# ===============================

Switch1(config)# ! 全アクセスポートで PortFast を有効化
Switch1(config)# spanning-tree portfast default

Switch1(config)# ! PortFast ポートで BPDU Guard を有効化
Switch1(config)# spanning-tree portfast bpduguard default

Switch1(config)# ! PortFast ポートで BPDU Filter（安全版）を有効化
Switch1(config)# spanning-tree portfast bpdufilter default

Switch1(config-if)# ! 個別ポートで PortFast を有効化
Switch1(config-if)# spanning-tree portfast

Switch1(config-if)# ! 個別ポートで BPDU Guard を有効化
Switch1(config-if)# spanning-tree bpduguard enable

Switch1(config-if)# ! 危険：BPDU Filter を強制有効化（BPDU 完全破棄）
Switch1(config-if)# spanning-tree bpdufilter enable


# ===============================
# Root Guard / Loop Guard
# ===============================

Switch1(config-if)# ! Root Guard を有効化
Switch1(config-if)# spanning-tree guard root

Switch1(config)# ! Loop Guard を全トランクで有効化
Switch1(config)# spanning-tree loopguard default


# ===============================
# STP 状態確認
# ===============================

Switch1# ! STP サマリ表示
Switch1# show spanning-tree summary

Switch1# ! VLAN 10 の STP 状態表示
Switch1# show spanning-tree vlan 10

Switch1# ! インターフェイスの STP 詳細表示
Switch1# show spanning-tree interface GigabitEthernet1/0/1

Switch1# ! PortFast 状態確認
Switch1# show spanning-tree interface GigabitEthernet1/0/10 portfast

Switch1# ! inconsistent ポート一覧（Root/Loop Guard）
Switch1# show spanning-tree inconsistentports
# ===============================
# STP モード設定（PVST+ / Rapid-PVST+ / MST）
# ===============================

Switch1(config)# ! Rapid-PVST+ を有効化
Switch1(config)# spanning-tree mode rapid-pvst

Switch1(config)# ! PVST+ を有効化
Switch1(config)# spanning-tree mode pvst

Switch1(config)# ! MST を有効化
Switch1(config)# spanning-tree mode mst


# ===============================
# MST 設定（リージョン名 / リビジョン / VLAN マッピング）
# ===============================

Switch1(config)# ! MST 設定モードへ
Switch1(config)# spanning-tree mst configuration
Switch1(config-mst)# name CCIE_REGION
Switch1(config-mst)# revision 10
Switch1(config-mst)# instance 1 vlan 10,20
Switch1(config-mst)# instance 2 vlan 30,40
Switch1(config-mst)# exit


# ===============================
# Root Bridge / Secondary Root 設定
# ===============================

Switch1(config)# ! VLAN 10 の Root Bridge に設定
Switch1(config)# spanning-tree vlan 10 root primary

Switch1(config)# ! VLAN 10 の Secondary Root に設定
Switch1(config)# spanning-tree vlan 10 root secondary


# ===============================
# Bridge Priority 設定
# ===============================

Switch1(config)# ! VLAN 10 の Bridge Priority を 4096 に設定
Switch1(config)# spanning-tree vlan 10 priority 4096


# ===============================
# Port Priority 設定
# ===============================

Switch1(config-if)# ! ポートの Port Priority を 64 に設定
Switch1(config-if)# spanning-tree port-priority 64

Switch1(config-if)# ! VLAN 10 の Port Priority を 64 に設定
Switch1(config-if)# spanning-tree vlan 10 port-priority 64


# ===============================
# Path Cost 設定
# ===============================

Switch1(config-if)# ! ポートの Path Cost を 200 に設定
Switch1(config-if)# spanning-tree cost 200

Switch1(config-if)# ! VLAN 10 の Path Cost を 300 に設定
Switch1(config-if)# spanning-tree vlan 10 cost 300

Switch1(config)# ! Path Cost 計算方式を Long（32-bit）に変更
Switch1(config)# spanning-tree pathcost method long


# ===============================
# STP タイマー設定（Hello / Forward Delay / Max Age）
# ===============================

Switch1(config)# ! VLAN 20 の Hello タイマーを 3 秒に設定
Switch1(config)# spanning-tree vlan 20 hello-time 3

Switch1(config)# ! VLAN 20 の Forward Delay を 18 秒に設定
Switch1(config)# spanning-tree vlan 20 forward-time 18

Switch1(config)# ! VLAN 20 の Max Age を 30 秒に設定
Switch1(config)# spanning-tree vlan 20 max-age 30


# ===============================
# PortFast / BPDU Guard / BPDU Filter
# ===============================

Switch1(config)# ! 全アクセスポートで PortFast を有効化
Switch1(config)# spanning-tree portfast default

Switch1(config)# ! PortFast ポートで BPDU Guard を有効化
Switch1(config)# spanning-tree portfast bpduguard default

Switch1(config)# ! PortFast ポートで BPDU Filter（安全版）を有効化
Switch1(config)# spanning-tree portfast bpdufilter default

Switch1(config-if)# ! 個別ポートで PortFast を有効化
Switch1(config-if)# spanning-tree portfast

Switch1(config-if)# ! 個別ポートで BPDU Guard を有効化
Switch1(config-if)# spanning-tree bpduguard enable

Switch1(config-if)# ! 危険：BPDU Filter を強制有効化（BPDU 完全破棄）
Switch1(config-if)# spanning-tree bpdufilter enable


# ===============================
# Root Guard / Loop Guard
# ===============================

Switch1(config-if)# ! Root Guard を有効化
Switch1(config-if)# spanning-tree guard root

Switch1(config)# ! Loop Guard を全トランクで有効化
Switch1(config)# spanning-tree loopguard default


# ===============================
# STP 状態確認
# ===============================

Switch1# ! STP サマリ表示
Switch1# show spanning-tree summary

Switch1# ! VLAN 10 の STP 状態表示
Switch1# show spanning-tree vlan 10

Switch1# ! インターフェイスの STP 詳細表示
Switch1# show spanning-tree interface GigabitEthernet1/0/1

Switch1# ! PortFast 状態確認
Switch1# show spanning-tree interface GigabitEthernet1/0/10 portfast

Switch1# ! inconsistent ポート一覧（Root/Loop Guard）
Switch1# show spanning-tree inconsistentports

```
