---
layout: default
title: 1.2.a-Administrative-distance
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.2.a Administrative distance

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 実技試験（Practical Exam）および筆記試験において、マルチプロトコル・ルーティング環境における最適経路選定の第1評価基準となる **Administrative Distance（アドミニストレーティブディスタンス：AD）** について、Cisco IOS-XE 17.x（Catalyst 9000およびCisco Catalyst 8000Vシリーズ）の実装基準に準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

エンタープライズネットワークでは、信頼性向上や冗長化、組織の統合などを目的として、複数の異なるルーティングプロトコル（EIGRP, OSPF, BGP, 静的ルーティングなど）を同一ルータ上で同時に稼働させることが一般的です。

このとき、同一の宛先ネットワーク（プレフィックスおよびサブネットマスクが完全に一致する経路）に対して、複数のルーティングソースから異なる経路情報が提示された場合、ルータはどのルーティングプロトコルから得た経路情報を最も信頼すべきかを決定する必要があります。この「ルーティングプロトコル（ルーティングソース）の信頼度」を 0 から 255 の数値で表したものが **Administrative Distance (AD)** です。

### どのような場面で利用するか
1. **フローティングスタティックルートの設計:** メインの動的ルーティングプロトコル（例: OSPF：AD 110）よりも高いAD値を持つ静的経路（例: AD 120）をあらかじめ定義しておき、動的ルーティングがダウンしたときのみスタティックルートを自動的にアクティブにするバックアップ回線設計。
2. **相互再配送（Mutual Redistribution）におけるルーティングループの防止:** 2つ以上の境界ルータでEIGRPとOSPFを相互再配送する際、再配送された外部経路がトポロジー内を回り込んで逆流し、元のドメインで誤って優先されるルーティングループ（再配送ループ）を防止するためにADをチューニングする。
3. **VRF-Lite およびマルチテナント環境におけるルートリーク制御:** 共有サービスVRFと個別テナントVRF間で経路をリークする際、ローカルIGP経路とリーク経路（BGP等）の優先度を調停する。
4. **SD-WAN OMP とローカルIGPの統合:** Cisco SD-WANインフラにおいて、vEdge/cEdgeがOMP（Overlay Management Protocol）経由で学習するオーバーレイ経路（デフォルトAD 250）と、ローカルサイト内のIGP（OSPFやEIGRP）との整合性を保ち、最適なトラフィックフローを維持する。

---

## 🔑 要点

Administrative Distance のコアな技術プロパティと設計要件を整理します。

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | ルーティングソース（OSPF, EIGRP, RIP, Static等）の「信頼度」を表す0〜255のローカル内部パラメータ。 |
| **用途** | **同一プレフィックスかつ同一サブネットマスク（完全一致）** の経路を異なるプロトコルから学習した際の、Routing Information Base (RIB) へのインストール判定。 |
| **メリット** | ローカルルータ単体で経路の優先度を決定論的に制御可能。バックアップ経路の自動切り替えやループ防止をシンプルに実装できる。 |
| **デメリット** | **ローカルルータ内でのみ有効な値であり、ルーティングアップデートに含めてネイバーに広報されない。** ネットワーク全体で一貫した設計を行わないと、非対称ルーティングやブラックホール、一時的なルーティングループを誘発する。 |
| **対応機種** | Catalyst 9000 シリーズ（IOS-XE 17.x）、Catalyst 8000V シリーズ、およびすべての Cisco IOS/IOS-XE デバイス。 |
| **制限事項** | プレフィックス長（サブネットマスク）が異なる経路間（例: `10.1.1.0/24` と `10.1.0.0/16`）では、AD値の比較は一切行われない（常に Longest Match ルールが優先される）。また、AD値 `255` が設定された経路は「信頼できない経路」とみなされ、RIB（ルーティングテーブル）への登録が拒否される。 |
| **設計上の注意点** | EIGRPは内部（90）と外部（170）でデフォルトADを分けて再配送ループを防御しているが、OSPFはエリア内/エリア間/外部経路が一律でデフォルトAD 110 であるため、OSPF相互再配送時にはADの個別調整（`distance ospf`）が極めて重要になる。 |

### 📌 Cisco IOS-XE デフォルト Administrative Distance テーブル一覧
Ciscoデバイスに事前に定義されている標準のAD値です。実技試験においてこれらを暗記していることは、トラブルシューティングおよび実装時間を短縮するための基本要件です。

*   **直結インターフェイス (Connected):** `0`
*   **静的ルーティング (Static Route):** `1`
*   **EIGRP 要約経路 (EIGRP Summary Route):** `5`
*   **外部 BGP (eBGP):** `20`
*   **内部 EIGRP (Internal EIGRP):** `90`
*   **OSPF (Intra, Inter, External 全て共通):** `110`
*   **IS-IS:** `115` 
*   **RIP (v1, v2):** `120` 
*   **ODR (On-Demand Routing):** `160` 
*   **外部 EIGRP (External EIGRP):** `170` 
*   **内部 BGP (iBGP):** `200`
*   **SD-WAN OMP (Overlay Management Protocol):** `250` 
*   **到達不能・不審なルーティングソース (Unusable):** `255` (RIB登録不可)

---

## 🏗 動作原理

Cisco IOS-XE におけるパケットフォワーディングおよび経路決定は、以下の優先順位（3段階の厳密な評価レイヤ）に沿ってハードウェア（ASIC）およびコントロールプレーン（RIB）で処理されます。

```text
[ 受信パケット / Incoming Packet ]
       │
       ▼
[ Layer 1: Longest Match (最長一致ルール) ] ➔ 最優先
  - 受信パケットの宛先IPにマッチする「最もマスク長の長い（狭い範囲の）」経路をフォワーディング用に選択する。
  - (例: 10.1.1.1 宛パケットに対し、10.1.1.0/24 (OSPF: AD 110) と 10.1.0.0/16 (Static: AD 1) があった場合、
    AD値に関わらずマスクが長い「10.1.1.0/24 (OSPF)」をフォワーディングパスとして採用する)
       │
       ▼ [ プレフィックスおよびマスクが完全に一致する複数のルーティングソースが存在する場合 ]
[ Layer 2: Administrative Distance (ADの比較) ] ➔ 第2基準
  - 完全に一致するプレフィックスを提示した複数のルーティングソース（RIP, OSPF, Static等）のAD値を比較。
  - 最も「低い」AD値を持つソースから提供された経路情報を Active として選択。
  - (例: 10.1.1.0/24 に対し、EIGRP (AD 90) と OSPF (AD 110) が提示された場合、ADの低い EIGRP 経路を RIB に登録)
       │
       ▼ [ 同一のルーティングソース（同一AD値）から複数の同一宛先経路が提示された場合 ]
[ Layer 3: Metric (メトリックの比較) ] ➔ 第3基準
  - 同一プロトコル内のコスト（OSPF）、複合メトリック（EIGRP）、ホップ数（RIP）を比較。
  - 最も低いメトリックを持つネクストホップ経路を Active として採用。
  - メトリックまで同一である場合は、等コストマルチパス（ECMP）としてロードシェアリング。
```

### 経路のライフサイクルと RIB / FIB へのインストールフロー
1. ルータのルーティングプロセス（OSPF等）が動的に計算した経路、または管理者によるスタティックコンフィグから、プレフィックスエントリが生成される。
2. 計算されたすべての経路情報は、Cisco IOS-XE のコントロールプレーンにおける統合データベースである **RIB（Routing Information Base）マネージャープロセス** に送信される。
3. RIBマネージャーは、同一プレフィックス・同一マスクを持つ他プロトコルの経路情報とAD値を比較する。
   *   **AD値が最優先（最小）の場合:** その経路を **Active（アクティブ）** に選定し、ローカルのルーティングテーブル（`show ip route`）に登録。
   *   **AD値が劣る場合:** その経路を **Inactive（非アクティブ）** のバックアップとして、各動的ルーティングプロトコルの個別データベース（例: OSPF トポロジーデータベース、EIGRP トポロジーテーブル）の中に保持する（ルーティングテーブルには表示されない）。
4. Active に選定された経路のみが、データプレーンでの高速転送を行うため、**FIB（Forwarding Information Base）テーブル** および CEF（Cisco Express Forwarding）のハードウェアASICキャッシュへとプッシュ同期され、実際のパケットスイッチングが稼働する。

---

## ⚙ 動作シーケンス

境界ルータ（ASBR）において、マルチプロトコル環境下でAD値がどのように評価され、ルーティングループが発生・または防止されるかのシーケンスを示します。

```
[ R1 (境界ルータ) ] ── ( EIGRP Domain ) ──► [ R2 (境界ルータ) ]
       │                                           │
       ▼ (OSPFをEIGRPに再配送)                       ▼ (EIGRPをOSPFに再配送)
[ R1: OSPF経路(AD 110)を再配送 ]              [ R2: EIGRPからOSPF経路を受信 ]
  - 外部EIGRP(AD 170)に変換して広報            - R2はOSPFドメインから同じ経路を
                                                 AD 110(OSPFデフォルト)で受信
                                                   │
                                                   ▼ [ R2 でのAD比較判定 ]
                                             - 宛先: 10.100.1.0/24
                                             - ルートA: OSPF (AD 110)
                                             - ルートB: 外部EIGRP (AD 170)
                                             - 判定: AD 110 < 170 のため OSPF 経路を
                                               【Active】として決定
                                                   │
                                                   ▼
                                             - ルーティングループは発生せず、
                                               正しいルーティングトポロジーを維持！
```

もし、管理者が誤って EIGRP 内での再配送時にAD値を EIGRP 内部経路（AD 90）よりも好ましい値、あるいは OSPF（AD 110）よりも好ましいAD値（例: AD 80）へと手動調整してしまった場合、R2 は外部から逆流した再配送経路の方を優先してしまい、R1-R2 間でパケットがパタパタと往復する **ルーティングループ（Routing Loop）** が発生します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ実技試験において、ADのチューニングおよびトラブルシューティングは、レイヤ3インフラ構築の最重要要件です。試験で狙われる具体的なパターンと防衛策を記述します。

### 1. 相互再配送（Mutual Redistribution）時のADスターベーション（飢餓・逆流）
最も不合格を招きやすい古典的なCCIEの「罠」です。
*   **問題の構造:**
    OSPF（110）と EIGRP（90/170）を2台の境界ルータ（R1, R2）で相互再配送します。
    EIGRPで学習した経路をOSPFに再配送すると、対向の境界ルータはそれを「OSPF外部経路（E1/E2）」として AD 110 で学習します。
    もし、境界ルータがそのネットワークへ直接接続されているネイバーであった場合、EIGRP（内部AD 90）の方が OSPF（AD 110）よりも優れているため、正しい経路を選択できます。
    しかし、**RIP（120）や iBGP（200）などのより高い（悪い）AD値を持つプロトコルとOSPF/EIGRPが混在している環境**、あるいは**OSPF内の特定の外部プレフィックスを再配送している環境**では、逆流が発生してADがひっくり返り、境界ルータ自身が「自分が再配送して送り出したパケット」を反対側の境界ルータから再学習してRIBを書き換えてしまうループが発生します。
*   **試験での対策コマンド:**
    OSPFプロセス内で、特定のプレフィックス、あるいはプロトコル全体のAD値を部分的に引き上げ（悪化させ）ます。
    ```bash
    router ospf 1
     # 外部経路（O E1/E2）のAD値のみを一律で175に引き上げ、EIGRP外部（170）より優先度を下げる
     distance ospf external 175
    ```

### 2. Floating Static Route のバックアップトラップ
*   **試験の罠:**
    「R1とR2の間はメイン回線（OSPF：エリア0）と、バックアップ回線（PPPシリアルリンク：スタティックルーティング）で接続されている。通常はOSPFを使用し、OSPFのネイバーが切れた場合のみ、シリアルリンクのスタティックルートをアクティブにせよ。ただし、宛先へのPing疎通確認（IP SLA）などを使用せず、ルーティングプロトコルのAD値制御のみでシンプルに実装すること」
    *   **よくある間違い:** 単に `ip route 10.1.12.0 255.255.255.0 192.168.12.2` と設定する。これではスタティックルートのAD値が `1` になるため、OSPF（110）よりも優先されてしまい、常時バックアップ回線がメインになってしまいます。
    *   **正しい対策:** OSPF（AD 110）よりも大きな値（例: AD `115` または `120`）を付与した **Floating Static Route** を定義します。
        ```bash
        ip route 10.1.12.0 255.255.255.0 192.168.12.2 120
        ```

### 3. eBGP / iBGP のマルチホーム設計とADのバグ動作
BGPは eBGP（AD 20）と iBGP（AD 200）でADが極端に異なります。
*   **試験でのトラブルシナリオ:**
    拠点ルータ R1 が、本社のコアスイッチから iBGP 経由で社内経路（AD 200）を学習しています。
    一方で、R1 はバックアップのVPN拠点から OSPF（AD 110）経由でも同じ社内経路を学習しています。
    *   **デフォルトの挙動:** OSPF（110）の方が iBGP（200）よりもAD値が低いため、ルータ R1 は **「メイン回線である iBGP（高速回線）を無視し、バックアップである OSPF（VPN細い回線）をルーティングテーブルにインストールしてしまう」** という深刻なサブオプティマル（非推奨）ルーティングが発生します。
    *   **CCIEレベルの解決策:**
        BGPプロセス配下で、iBGPのAD値を手動で `100` などに下げて OSPF（110）よりも優先されるように変更、または `distance bgp` でAD値のトータルバランスを整合します。
        ```bash
        router bgp 65000
         # eBGPを20、iBGPを100、ローカル（Network文等）を200に変更
         distance bgp 20 100 200
        ```

---

## 🛠 設定方法

Cisco IOS-XE 17.xにおける、各プロトコルのAD調整コマンドです。

### 1. スタティックルーティング：Floating Static Route (AD 210) の設定

```bash
# 通常のスタティックルート（デフォルトAD 1）
ip route 10.10.10.0 255.255.255.0 192.168.1.1

# バックアップ用のFloatingスタティックルート（AD 210を指定、OSPFやEIGRPより劣位にする）
ip route 10.10.10.0 255.255.255.0 172.16.1.1 210
```

### 2. OSPF：特定の経路タイプ（External / Inter-Area）のAD一括変更

```bash
router ospf 1
 router-id 1.1.1.1
 # エリア内（Intra）を95、エリア間（Inter）を105、外部（External）を175に細分化してチューニング
 distance ospf intra-area 95 inter-area 105 external 175
```

### 3. EIGRP (Classic / Named Mode) での AD 変更手順

EIGRPでは、クラシックモードとNamedモード（CCIE推奨）で設定階層が異なります。

**【EIGRP Classic Mode】**
```bash
router eigrp 100
 # 内部経路のADを85（デフォルト90）、外部経路のADを165（デフォルト170）に変更
 distance eigrp 85 165
```

**【EIGRP Named Mode (推奨方式)】**
```bash
router eigrp virtual-name
 address-family ipv4 autonomous-system 100
  # topology base の階層に下りて設定を適用
  topology base
   distance eigrp 85 165
  exit-address-family
```

### 4. BGP：eBGP / iBGP / Local 経路の一括調整

```bash
router bgp 65111
 bgp log-neighbor-changes
 address-family ipv4 unicast
  # distance bgp <ext-ad> <int-ad> <local-ad>
  distance bgp 20 95 200
```

### 5. 高度なACL/プレフィックス制御による特定プレフィックスのAD変更
「VLAN 10のWebサーバー（`10.1.10.100/32`）宛の OSPF 経路のみ、AD値を `150` に引き下げて、他のバックアップルーティングが優先的に動作するようにピンポイントで狙い撃ちせよ」

```bash
# 1. 変更対象のプレフィックスをACLで定義
ip access-list standard SET_AD_ACL
 permit 10.1.10.100

# 2. OSPFプロセス配下でdistanceコマンドをACLとバインド
router ospf 1
 # distance <新しいAD値> <送信元ネイバーIP> <ワイルドカード> <ACL名>
 # (※送信元を 0.0.0.0 255.255.255.255 にすることで、すべてのネイバーから届くアップデートを対象にする)
 distance 150 0.0.0.0 255.255.255.255 SET_AD_ACL
```

---

## 🔍 検証コマンド

ルータ内部のAD評価状態を監査するための強力なコマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **ルーティングテーブル内の特定の宛先（例: `10.1.1.0/24`）における、現在のAD値（Active）およびネクストホップの確認** | <code>show ip route 10.1.1.0</code> |
| **各動的ルーティングプロトコル（OSPF, EIGRP等）のグローバルAD値、およびネイバーIPごとの個別AD変更情報の確認** | <code>show ip protocols</code> |
| **BGPテーブルにインストールされている各プレフィックスの現在のAD値、およびRIBへのインストール状態（RIB-failureなど）の確認** | <code>show ip bgp</code> |
| **特定のプレフィックスにおいて、AD値不整合等によってルーティングテーブルにインストールされなかった「Inactive」経路のデータベース確認** | <code>show ip ospf database</code> / <code>show ip eigrp topology</code> |

### 🔍 show ip route の詳細な読み方（AD値の識別）
```text
R1# show ip route 10.1.1.0
Routing entry for 10.1.1.0/24
  Known via "ospf 1", distance 110, metric 20, type intra area
  Routing Descriptor Blocks:
    * 192.168.12.2, from 2.2.2.2, 01:23:45 ago, via GigabitEthernet1/0/1
      Route metric is 20, share count 1
```
*   **`distance 110`:** この経路を OSPF 1 経由で学習し、現在の適用AD値が「110」であることを明示しています。
*   **`metric 20`:** AD評価の「後」に評価された、OSPF内部のコストメトリックです。

---

## 🚨 トラブルシュート

実機試験で遭遇するADに起因する重大なトラブルと回復アプローチです。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **同一プレフィックスのスタティックルートを設定したが、ルーティングテーブル（`show ip route`）に表示されない。** | 設定したスタティックルートのAD値（Floating）が、動的ルーティング（OSPF等）のAD値よりも大きく、かつ動的ルーティングが正常稼働しているため。 | <code>show run \| include ip route</code><br><code>show ip route</code> | これは正常な動作（スタンバイ）ですが、即時切り替わりをテストしたい場合は、メインリンクを <code>shutdown</code> させて、Floating スタティックルートが自動的に Active として浮上（インジェクト）するか確認する。 |
| **BGPで最適経路（Best-Path）として選定されているにもかかわらず、ルーティングテーブル（`show ip route`）にBGP経路が表示されず、OSPFなどのIGP経路が優先されてしまう。Syslogに「RIB-failure」が出力される。** | **Administrative Distance の競合。** BGPテーブル上の宛先（AD 200）と、同一のプレフィックスをより優れたADを持つIGP（例: OSPF: 110、EIGRP: 90）から学習しているため、RIBへの登録が却下（Failure）されている。 | <code>show ip bgp</code><br><code>show ip bgp rib-failure</code> | 1. BGPテーブル上で `r` (RIB-failure) フラグがついていることを確認。<br>2. 意図的にBGPを優先したい場合は、<code>distance bgp 20 100 200</code> 等でBGPのAD値をIGPよりも低い値に変更して制御を奪還する。 |
| **境界ルータでEIGRPとOSPFの相互再配送を設定した直後、特定の経路のネクストホップが高速にフラッピングし、CPU利用率が100%に急上昇。** | **再配送に伴うADの逆流・ルーティングループ。** OSPF（110）からEIGRPに再配送した経路が、別の境界ルータでEIGRP（内部90 / 外部170）経由で逆広報され、より低い（好ましい）AD値のIGPとして再学習されたため、RIBが無限に書き換わっている。 | <code>show ip route [プレフィックス]</code><br><code>show processes cpu sorted</code> | 1. 境界ルータ間でルートタグ（Tag）を付与し、同じタグを持つ経路の再配送を <code>route-map</code> でドロップする。<br>2. または <code>distance ospf external 175</code> により、OSPF外部のAD値を外部EIGRP（170）より悪く設定し、逆流を防止する。 |

---

## ⚠ 制限事項

### 1. Longest Match 優先の鉄則（マスク長違いに対するAD無効化）
*   AD値は、プレフィックスおよびサブネットマスクが**完全に一致している場合のみ**比較基準として呼び出されます。
*   もし、OSPF経由で `10.1.1.0/24`（AD 110）を学習し、EIGRP経由で `10.1.0.0/16`（AD 90）を学習した場合、AD値は EIGRP（90 < 110）の方が優れていますが、ルータはパケット転送時に **Longest Match ルールを最優先** するため、宛先 `10.1.1.1` へのパケットは常に **OSPFの `10.1.1.0/24` 側へ転送** されます。
*   AD値の変更だけで経路を制御しようとする場合、プレフィックス長の不一致という設計ミスを見落とすと意図しない転送（サブオプティマル）が発生します。

### 2. AD値 255（完全拒否）の挙動
*   経路のAD値を `255` に設定すると、ルータはそのプロトコル、あるいは指定したネイバーからの経路を「一切信頼できない（Unbelievable / Non-installable）」とみなします。
*   この設定が施された経路情報は、ルーティング更新（パケット）としてはルータに到着し、データベース（OSPF LSDB等）には保管されますが、**ルーティングテーブル（RIB）およびFIBへのインストールは完全に拒否** されます。

---

## 🔄 他技術との関連

*   **Policy-Based Routing (PBR):**
    PBRはルーティングテーブル（RIB/FIB）の経路決定（AD値の評価を含む）を完全にバイパスし、パケットヘッダーの条件（ソースIP等）に基づいてネクストホップを強制的に上書きします。PBRはAD値制御よりも優先度が高いため、トラブルシューティング時にはPBRの有無を確認する必要があります。
*   **Route Map / Route Filtering (Distribute-list, Prefix-list):**
    ルーティングフィルタリングは、経路がルータのデータベースに入る、あるいはRIBにインストールされるのを「遮断（Drop）」します。
    一方、ADの調整（`distance`）は、経路はデータベースに保持したまま「優先順位（順位）」のみを下げてバックアップとして待機させます。
    *   **CCIE設計のヒント:** 完全に経路を遮断して見えなくしたい場合はフィルタリング（`distribute-list`）を使用し、障害時の自動切り替え用として裏に隠しておきたい場合はAD値の変更（`distance`）を使用するのが明確な使い分けです。
*   **MPLS L3VPN / Route Leaking:**
    VRF間でルートリークを行う際、リークされた経路は MP-BGP（内部AD 200）を経由して他のVRFへインジェクトされます。リーク先のVRFにすでに同一プレフィックスのローカルIGP経路（OSPF: 110 等）が存在する場合、ローカル経路が常に優先されます。リーク経路を優先させたい場合は、VRF内でのBGP AD値のカスタマイズ（`distance bgp`）が求められます。

---

## 🧩 比較表

### ルーティングプロトコルのAD調整オプション比較

各プロトコルにおける、ADの変更アプローチと柔軟性の違いを示します。

| プロトコル | デフォルトAD | ADの一括変更コマンド | 特定プレフィックス個別のAD変更 | 特定ネイバー/ソース単位の変更 |
| :--- | :--- | :--- | :--- | :--- |
| **Static** | `1` | `ip route ... [AD値]` | 可能（スタティック設定時に個別指定） | N/A (直結ネクストホップ依存) |
| **EIGRP** | `90` (内) / `170` (外) | `distance eigrp [int] [ext]` | 可能（ACLおよびPrefix-listを distance とバインド） | 可能（特定のネイバーから届くアップデートのみADを変更可能） |
| **OSPF** | `110` (一律) | `distance ospf [intra] [inter] [ext]` | 可能（ACLを distance コマンドにバインド） | 可能（指定したAdvertising RouterのIPを指定可能） |
| **BGP** | `20` (e) / `200` (i) | `distance bgp [ext] [int] [local]` | **可能**（`table-map` と `route-map` を用いて、ASICでのRIB登録時にプレフィックスごとに高度に変更可能） | N/A (BGP best-path計算の後に評価されるため、一般的に table-map を推奨) |

---

## 💡 ベストプラクティス

1.  **スタティックバックアップは Floating Static (AD 200以上) での一貫性維持:**
    スタティックデフォルトルート（`0.0.0.0/0`）をバックアップとして切る場合、AD値をデフォルトの1ではなく、BGP（200）よりも大きな値である **`210` や `240`** などの固定的な値に設定します。これにより、すべての動的ルーティングプロトコルが全断した場合にのみ、安全にデフォルトゲートウェイがバックアップ回線へとシフトします。
2.  **相互再配送における OSPF External AD 値の引き上げポリシー:**
    マルチプロトコル再配送を行うすべてのASBRにおいては、OSPFプロセス配下で `distance ospf external 175` を標準のベースライン構成として投入します。EIGRP外部（170）やBGP（20/200）との間での境界逆流を防ぎ、ルーティングの予測可能性（Deterministic Routing）を最大限に向上させることができます。
3.  **BGP Table-Map によるコントロールプレーンとデータプレーンの分離最適化:**
    BGPからIGPへの経路選択を制御する際、BGPパス属性（Local PreferenceやMED）を変更すると、ルータから送信される他のBGPネイバーへのベストパス広報まで変わってしまいます。自ルータ内でのみ優先度を下げてIGPを優先させたい場合は、ネイバーへの影響をゼロにするため、**`table-map` を用いてローカルRIBへのインストール時にのみADを変更する設計**を採用します。
4.  **ADを変更した際のドキュメント記述と検証ポリシー:**
    AD値はデバッグログ（`debug`）でも追いかけるのが難しいため、AD値を手動でカスタマイズした場合は、必ずルータのコンフィグコメントや、トポロジー設計書にAD値を明記してください。現地での原因特定（Troubleshooting）を劇的に高速化させます。

---

## 📝 ラボ学習・設定サンプル例

※ 本設定サンプルは、Cisco IOS-XE 17.xをベースとしており、省略せずに最後まで出力しています。CCIE EI実技試験の構成基準を満たしています。

### 1. Floating Static Route（OSPFバックアップ）の設定
**【問題】**
R1において、宛先 `10.100.1.0/24` へ向けたスタティックルートを設定してください。通常は OSPF（プロセス 1）経由の経路を優先し、OSPFのルートが消失した場合のみ、ネクストホップ `192.168.12.2` 経由のスタティックルートをアクティブ（FIBインストール）にしてください。

**【R1 設定】**
```bash
R1# configure terminal
# 宛先10.100.1.0/24 に対し、OSPF(AD 110)より悪い AD 120 を設定してフローティングさせる
R1(config)# ip route 10.100.1.0 255.255.255.0 192.168.12.2 120
R1(config)# end
```

---

### 2. OSPF エリア内・エリア間・外部経路の AD 微調整
**【問題】**
R2において、OSPF（プロセス 1）のルーティングポリシーを最適化するため、エリア内（Intra-Area）経路のAD値を `95`、エリア間（Inter-Area）経路のAD値を `105`、外部（External）経路のAD値を `175` にそれぞれ一括変更してください。

**【R2 設定】**
```bash
R2# configure terminal
R2(config)# router ospf 1
# OSPFルートタイプごとのADを明示的に引き下げ・引き上げチューニング
R2(config-router)# distance ospf intra-area 95 inter-area 105 external 175
R2(config-router)# end
```

---

### 3. EIGRP 内部・外部経路の個別 AD チューニング
**【問題】**
R3（EIGRP AS 100 稼働中）において、内部EIGRP経路（Internal）のAD値を `85` に引き下げ、他の拠点から再配送されてくる外部EIGRP経路（External）のAD値を `165` に変更してください。

**【R3 設定】**
```bash
R3# configure terminal
R3(config)# router eigrp 100
# 内部および外部EIGRPのADをデフォルト(90/170)から変更
R3(config-router)# distance eigrp 85 165
R3(config-router)# end
```

---

### 4. BGP AD の一括設定（eBGP / iBGP / Local）
**【問題】**
R4において、iBGP（デフォルトAD 200）経由で学習する経路が、拠点内の OSPF（AD 110）経路よりも常に優先的にルーティングテーブルへ登録されるように、iBGPのAD値を `100` に引き下げてください。また、eBGPを `20`、Localを `200` に設定してください。

**【R4 設定】**
```bash
R4# configure terminal
R4(config)# router bgp 65004
R4(config-router)# address-family ipv4 unicast
# distance bgp <ext-ad> <int-ad> <local-ad> の構文で iBGP を 100 に下げる
R4(config-router)# distance bgp 20 100 200
R4(config-router)# end
```

---

### 5. ACLを用いた特定プレフィックスの OSPF AD 変更
**【問題】**
R1において、ネイバーから学習する OSPF 経路のうち、プレフィックス `172.16.50.0/24` の宛先についてのみ、AD値を `140` に変更して、他の動的経路（EIGRP等）によるバックアップを可能にしてください。他のOSPF経路（AD 110）に影響を与えてはなりません。

**【R1 設定】**
```bash
R1# configure terminal
# 1. 対象のプレフィックスを特定する標準ACLを定義
R1(config)# ip access-list standard ACCESS_SET_OSPF_AD
R1(config-std-nacl)# permit 172.16.50.0 0.0.0.255
R1(config-std-nacl)# exit

# 2. OSPFプロセス配下で distance コマンドとACLをマッピング
R1(config)# router ospf 1
# すべての送信元ルータ(0.0.0.0/0)から届く上記ACLのプレフィックスに AD 140 を適用
R1(config-router)# distance 140 0.0.0.0 255.255.255.255 ACCESS_SET_OSPF_AD
R1(config-router)# end
```

---

### 6. EIGRP Named Mode での AD カスタマイズ
**【問題】**
EIGRPの名前付きモード（Named Mode：インスタンス名 `CCIE_WAN`）を稼働させているR5において、アドレスファミリー IPv4 宛先に対する EIGRP 内部AD値を `95`、外部AD値を `165` にカスタマイズしてください。

**【R5 設定】**
```bash
R5# configure terminal
# EIGRP Named Mode インスタンスへの侵入
R5(config)# router eigrp CCIE_WAN
R5(config-router)# address-family ipv4 autonomous-system 100
# 内部トポロジーベースに入り、ADを変更する
R5(config-router-af)# topology base
R5(config-router-af-topology)# distance eigrp 95 165
R5(config-router-af-topology)# end
```

---

### 7. 特定のルート送信元（Advertising Router）に対する OSPF AD の引き上げ
**【問題】**
R2は、特定のOSPFルータ `192.168.99.99` (Router-ID) から送信されてくるすべての OSPF ルート更新情報を信頼したくありません。この特定のルータから広告されたルートのみ、AD値を `255` に設定して、ルーティングテーブルへの登録を完全に除外してください。

**【R2 設定】**
```bash
R2# configure terminal
# すべての宛先プレフィックスを対象とするための標準ACLを定義
R2(config)# ip access-list standard ALL_ROUTES_ACL
R2(config-std-nacl)# permit any
R2(config-std-nacl)# exit

# OSPFプロセス内での特定ソースADフィルタ
R2(config)# router ospf 1
# 送信元Router-ID「192.168.99.99/32」から送信された経路を一律で AD 255 (使用不可) に指定
R2(config-router)# distance 255 192.168.99.99 0.0.0.0 ALL_ROUTES_ACL
R2(config-router)# end
```

---

### 8. BGP Table-map と Route-map を用いた特定プレフィックスの AD チューニング
**【問題】**
R3において、BGPで学習している経路のうち、特定の開発用Webサーバーのプレフィックス `10.222.1.0/24` について、BGPのベストパス選定（Best-path）自体は維持したまま、**自ルータのRIB（ルーティングテーブル）へのインストール時にのみ AD 値を `210` に引き下げ（改悪）** してください。これにより、同一のプレフィックスが OSPF（AD 110）や RIP（AD 120）から届いた場合、IGPの経路が優先されるようにしてください。

**【R3 設定】**
```bash
R3# configure terminal
# 1. プレフィックスリストを定義
R3(config)# ip prefix-list TARGET_BGP_PL permit 10.222.1.0/24

# 2. ルートマップを定義し、マッチしたプレフィックスのADを 210 に設定
R3(config)# route-map BGP_RIB_AD_MAP permit 10
R3(config-route-map)# match ip address prefix-list TARGET_BGP_PL
R3(config-route-map)# set distance 210
R3(config-route-map)# exit
# その他の経路は何も変更せずに（デフォルトADのまま）パスする
R3(config)# route-map BGP_RIB_AD_MAP permit 20
R3(config-route-map)# exit

# 3. BGPのアドレスファミリー配下で table-map としてバインド適用
R3(config)# router bgp 65003
R3(config-router)# address-family ipv4 unicast
# table-map を用いて、RIBの挿入タイミングでルートマップを実行する
R3(config-router)# table-map BGP_RIB_AD_MAP
R3(config-router)# end
```

---

### 9. OSPF-EIGRP 相互再配送時における OSPF External AD の引き上げによるループ防御
**【問題】**
R1（ASBR境界ルータ）において、OSPF（プロセス 1）と EIGRP（AS 100）の間で相互再配送を実行しています。対向の境界ルータ R2 との間での外部経路の逆流・再配送ループを確実に防止するため、OSPFプロセス配下で、すべての OSPF 外部経路（External：O E1 / O E2）に対する AD 値を一律で `175` に引き上げ、外部EIGRP（AD 170）よりも優先度を下げてください。

**【R1 設定】**
```bash
R1# configure terminal
R1(config)# router ospf 1
# 再配送ループを防止するために OSPF External AD を 175 にチューニング
R1(config-router)# distance ospf external 175
R1(config-router)# end
```

---

### 10. VRF-Lite 構成下での BGP ルートリーク用 AD 制御
**【問題】**
R4において、テナント用の `VRF_A` と 共有サービス用の `VRF_SHARED` の間で、MP-BGPを介したルートリークが実行されています。
*   `VRF_A` 内において、リークされた共有サービスのプレフィックス `192.168.100.0/24` について、VRF内のOSPF経路（AD 110）よりも優先的に BGP リーク経路を採用させたい。
*   VRF 内のアドレスファミリーにおける BGP AD値（iBGP）を一律で `105` に引き下げてください。

**【R4 設定】**
```bash
R4# configure terminal
R4(config)# router bgp 65004
# VRF_A の IPv4 アドレスファミリーに侵入
R4(config-router)# address-family ipv4 vrf VRF_A
# VRF内でのBGP ADを eBGP:20, iBGP:105, Local:200 に調整
R4(config-router-af)# distance bgp 20 105 200
R4(config-router-af)# end
```

---

## ❓ 想定試験問題

CCIE Enterprise Infrastructure 筆記および実技試験を意識した難関設問群です。

### 1. 【コンフィグ読解：最長一致（Longest Match）とADの優先関係】
**問題:** 
ルータ R1 は、以下の3つの宛先経路情報を異なるソースから学習し、RIBデータベースに保持しています。
1.  **スタティックルート:** `ip route 10.0.0.0 255.0.0.0 192.168.1.1` (AD 1)
2.  **OSPF 経路:** `10.1.0.0/16 via 192.168.2.1` (AD 110)
3.  **EIGRP 経路:** `10.1.1.0/24 via 192.168.3.1` (AD 90)

この時、ルータ R1 に宛先IPアドレスが **`10.1.1.100`** であるパケットが到着した場合、R1 はどのネクストホップ（`192.168.1.1`、`192.168.2.1`、`192.168.3.1`）に向けてパケットを転送しますか？ その理由をシスコのルーティング判定の処理優先ルールに基づいて論理的に説明してください。

**解答・解説:**
*   **転送先ネクストホップ:** **`192.168.3.1` (EIGRP 経路側)**
*   **技術的理由:**
    Ciscoルータにおけるパケット転送の決定プロセスにおいて、**Longest Match（最長一致：サブネットマスク長）の評価は、AD（Administrative Distance）値の評価よりも常に最優先**されます。
    宛先IP `10.1.1.100` に対する各経路のマスク長は以下の通りです：
    *   スタティックルート: `/8` (最長一致の一致長: 8ビット)
    *   OSPF 経路: `/16` (最長一致の一致長: 16ビット)
    *   EIGRP 経路: `/24` (最長一致の一致長: 24ビット)
    
    マスク長を比較すると、EIGRP経由で学習した `/24` が最も長く一致します。この段階でフォワーディング候補は EIGRP 経路に完全に決定されるため、AD値の比較（スタティックの AD 1 や OSPFの AD 110 との比較）は一切実行されません。したがって、最もマスク長の長い EIGRP 経路のネクストホップである `192.168.3.1` がフォワーディングパスとして採用されます。

---

### 2. 【トラブルシュート：BGP RIB-failure の原因とPING疎通不全】
**問題:** 
BGPを稼働しているルータ R1 において、eBGPネイバーからプレフィックス `172.16.100.0/24` を学習しました。
`show ip bgp` を実行したところ、この経路にはベストパスを示す `*>` フラグが付いており、BGPテーブル上は正常でした。
しかし、`show ip route 172.16.100.0` を実行したところ、このプレフィックスのネクストホップはOSPF（AD 110）で学習した別方向のルータを指しており、BGPで指定されたネクストホップへ向けたPING通信が不通（サブオプティマル）になっていました。
この時、Syslogに出力されるはずの**BGP固有のエラー事象名**とその**根本的な原因**、およびこれを解決してBGP経路を優先的にルーティングテーブルにインストールさせるための**具体的な修復コマンド**を提示してください。

**解答・解説:**
*   **BGPエラー事象名:** **`RIB-failure`**
    (Syslog出力例: `%BGP-5-ADDPATH: ... RIB-failure`)
*   **根本原因:**
    **Administrative Distance の競合（不整合）。** eBGPのデフォルトAD値は `20` ですが、ルータ R1 がすでに同じ `172.16.100.0/24` のプレフィックスを、より好ましい（小さな）AD値を持つ何らかのルーティングソース（例: スタティックルート：AD 1、あるいは内部EIGRP：AD 90等）から学習していた場合、RIB（ルーティングテーブル）マネージャーはBGP経路（AD 20）のルーティングテーブルへのインストールを拒否（Failure）します。これがRIB-failureの発生メカニズムです。
*   **解決用修復コマンド:**
    もし、BGP経路（AD 20）よりも優先されているのがスタティックルート（AD 1）や特定のIGPである場合に、BGPを優先的にインストールさせたい場合は、BGPプロセス配下でAD値を変更、または優先されているルーティングソース（Static等）のADをBGP（20）より悪く引き上げます。
    （EIGRPが優先されている場合にBGPを最優先にする構成例）：
    ```text
    R1(config)# router eigrp 100
    # EIGRPのADをeBGP(20)よりも大きな値(例: 50)に引き下げる
    R1(config-router)# distance eigrp 50 165
    ```

---

### 3. 【Design：OSPF 2ドメイン間のルーティングループとAD設計】
**問題:** 
ある企業が他社を買収したため、2つの異なる OSPF プロセス（OSPF 1 と OSPF 2）が稼働するネットワークを、2台の境界ルータ R1 および R2 で冗長接続し、双方向で相互再配送（Mutual Redistribution）を実装しました。
再配送を設定した直後、特定の外部プレフィックス `192.168.200.0/24` において、R1 と R2 の間でパケットがループする事象が発生しました。
*   OSPFのデフォルトADは、エリア内、エリア間、外部（E1/E2）を問わず一律で **`110`** です。
*   再配送されたルートは OSPF 外部ルート (O E2) として広報されます。

この環境において、なぜルーティングループが発生するのかをAD値の観点から説明し、かつ、**ルートマップやタグを使用せず、AD値の調整のみでこの相互再配送ループを完全に防止するためのASBR設計案（設定コンフィグ）**を提示してください。

**解答・解説:**
*   **ルーティングループ発生のメカニズム:**
    1.  R1 が OSPF 1 の経路 `192.168.200.0/24` を OSPF 2 に再配送します。
    2.  これにより、`192.168.200.0/24` は OSPF 2 ドメイン内で外部ルート（O E2）として広報されます。
    3.  対向の境界ルータ R2 は、この外部ルートを OSPF 2 から AD `110` で学習します。
    4.  OSPFはデフォルトで、エリア内/エリア間/外部に関わらず一律で AD `110` です。もし R2 が元々この経路を OSPF 1（エリア間など）から同じ AD `110` で学習していた場合、コストやメトリックの差、あるいは学習順序のタイミングによって、R2 は「再配送されて逆流してきた OSPF 2 の外部ルート（AD 110）」の方を優先（Active化）してしまうことがあります。
    5.  R2 が OSPF 2 側を優先すると、R2 から `192.168.200.0/24` へのパケットは OSPF 2 ドメイン（R1方向）へ送信され、R1 はそれを OSPF 1 側へ送ろうとするため、R1-R2 間で無限ループ（あるいはネクストホップの激しいフラッピング）が発生します。
*   **AD調整のみによるループ防止設計案（ASBR設定）:**
    OSPFの外部（External）経路のAD値のみを、通常のエリア内/エリア間経路よりも一律で高く（例: `125`）設定します。これにより、逆流してきた外部ルートが、本来の内部（Intra/Inter）OSPF経路（AD 110）を上書きすることをハードウェアレベルで完璧に防止します。
    ```text
    R1(config)# router ospf 1
    # エリア内/エリア間のADは110を維持し、外部OSPF経路(O E1/E2)のADのみを 125 に変更
    R1(config-router)# distance ospf external 125
    !
    R1(config)# router ospf 2
    R1(config-router)# distance ospf external 125
    ```
    （※R2側でも同様の構成を一貫して施すことで、境界ルータ間での外部ルートの相互上書きを完全に排除し、安全なマルチホーム再配送を確立できます）。

---

## 🔗 参考リソース

### Cisco Live（オンデマンド・プレゼンテーションスライド）
*   [**Route Redistribution: Avoiding Loops, Lapses, and Legendary Headaches - BRKENT-2121**](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2026/pdf/BRKENT-2121.pdf)
*   [**How to Prepare for the CCNP Enterprise Advanced Routing Concentration Certification - BRKCRT-2016**](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2026/pdf/BRKCRT-2016.pdf)

### Cisco 公式技術ドキュメント（Technical Notes）
*   [**アドミニストレーティブディスタンスについて**](https://www.cisco.com/c/ja_jp/support/docs/ip/border-gateway-protocol-bgp/15986-admin-distance.html)
*   [**Troubleshooting TechNotes**](https://www.cisco.com/c/en/us/tech/ip/ip-routing/tsd-technology-support-troubleshooting-technotes-list.html)
*   [**Route Redistribution and Loop Prevention Guidelines**](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/8606-redist.html)

---

## 📝 **補足（Notes）**

### 実技試験直前チェックリスト（AD＆ルート選定）

ラボ試験でルーティングテーブルが崩壊していないか、瞬時に確認するための監査シートです。

*   **Floating Static Route の健全性**
    *   [ ] `show ip route [宛先]` を実行した際、スタティックルートではなく、意図した動的ルーティングプロトコル（OSPF/EIGRP等）のネクストホップが正しく表示されているか？
    *   [ ] バックアップ用のスタティックルートのAD値が、メインのプロトコル（EIGRP:90、OSPF:110、RIP:120）よりも確実に大きな値に指定されているか？
*   **Redistribution 逆流の排除**
    *   [ ] `show ip protocols` を実行し、相互再配送を行っている境界ルータ（ASBR）で `distance ospf external 175` 等の調整ポリシーが正しく反映されているか？
    *   [ ] ルーティングループの兆候を示すSyslogメッセージや、`show ip route` におけるネクストホップの周期的なフラッピングが完全にゼロであるか？
*   **BGP RIB-failure の検知**
    *   [ ] `show ip bgp rib-failure` を実行した際、予期しないプレフィックスがリストされていないか？（もしリストされている場合、その原因プロトコルとのADの優先関係は正しいか設計書を再確認する）。


