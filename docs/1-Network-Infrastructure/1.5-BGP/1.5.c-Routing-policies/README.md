---
layout: default
title: 1.5.c-Routing-policies
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 3
---
# 1.5.c Routing policies

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 BGP 制御技術である **BGP Routing Policies（ルーティングポリシーとパス操作）** について、Cisco IOS-XE 17.x の実装基準に 100% 準拠して、学術的・実践的背景から詳細に解説します [22, 1.5.c]。

本ドキュメントでは以下の Blueprint 項目を包括的にカバーします：
* **1.5.c (i) Attribute manipulation**（属性操作：Local Preference, Weight, MED, AS_PATH, Community 等） [22, 1.5.c (i); 55, 1.11.e]
* **1.5.c (ii) Conditional advertisement**（条件付きアドバタイズ：`advertise-map` / `exist-map` / `non-exist-map`） [22, 1.5.c (ii); 55, 1.11.e]
* **1.5.c (iii) Outbound route filtering (ORF)**（送信元アウトバウンドルートフィルタリング：RFC 5291 Prefix-list ORF） [22, 1.5.c (iii); 55, 1.11.e]
* **1.5.c (iv) Standard and extended communities**（標準および拡張コミュニティ、Well-Known コミュニティ、Large Community） [22, 1.5.c (iv)]
* **1.5.c (v) Multihoming**（マルチホーム設計：Primary/Backup 誘導、ロードバランシング、非対称ルーティング対策） [22, 1.5.c (v)]

---

## 📘 概要

BGP（Border Gateway Protocol）は、単なる最小ホップ数やコスト比較によるベストパス選定にとどまらず、管理者や組織のインフラ方針（ポリシー）に基づいてトラフィックの送受信経路を細かく制御できる **Policy-Based Routing Protocol** です [127, Cisco BGP Overview]。

**BGP Routing Policies** とは、Route-Map、Prefix-List、AS-Path Access-List、Community-List 等を組み合わせて、ピア間で送受信されるルーティングアップデート（UPDATE パケット）のフィルタリングや、パス属性（Path Attributes）を動的に書き換える一連の制御メカニズムを指します [55, 1.11.e; 133, Video Title: BGP Filtering and Manipulations]。

### 主な利用目的と適用シーン
1. **トラフィックエンジニアリング (Traffic Engineering):**
   * **アウトバウンド（送信）制御:** 自 AS から外部へ出るトラフィックを特定の ISP や回線に誘導する（`Weight`, `Local Preference` の操作） [55, 1.11.c; 133, Video Title: BGP Filtering and Manipulations]。
   * **インバウンド（受信）制御:** 外部 AS から自 AS へ入るトラフィックの入り口を指定・迂回させる（`AS_PATH Prepending`, `MED`, `Community` タグ付与） [55, 1.11.c; 133, Video Title: BGP Filtering and Manipulations]。
2. **帯域・コスト最適化と冗長化 (Multihoming):**
   * アクティブ/スタンバイ（Primary/Backup）回線の自動切り替えや、条件付きアドバタイズ（`Conditional Advertisement`）によるバックアップ経路の動的露出 [22, 1.5.c (ii), 1.5.c (v)]。
3. **コントロールプレーンの負荷軽減とセキュリティ (ORF & Community):**
   * **ORF (Outbound Route Filtering):** 対向 ISP ルータに対して自機が必要とする Prefix-List を自動プッシュし、回線上で不要な BGP UPDATE パケットが発生すること自体を防ぐ [22, 1.5.c (iii)]。
   * **Community Attribute:** 自 AS 内部および対向 AS 間でプレフィックスグループを定義し、一括したポリシー適用や再配送制御（NO_EXPORT, NO_ADVERTISE 等）を実現する [22, 1.5.c (iv)]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | Route-Map を介して BGP パス属性を柔軟に変更可能。入力（Inbound）および出力（Outbound）の両方向で独立してポリシーを適用。 |
| **用途** | マルチホーム ISP 接続網、エンタープライズ WAN/データセンター境界、MPLS L3VPN/SD-WAN メッシュ網でのトラフィック制御。 |
| **メリット** | ① 精密なインバウンド/アウトバウンドトラフィック制御が可能。<br>② 条件付きアドバタイズによりリンク障害時の動的経路露出を実現。<br>③ ORF により対向からの不必要な UPDATE パケットを送信元で遮断し帯域・CPU を節約。<br>④ Community タグにより複雑なネットワークでもポリシー管理を集約・簡易化。 |
| **デメリット** | ① ルートマップやコミュニティの設計ミスが非対称ルーティングやトラフィックブラックホールを引き起こす。<br>② インバウンド制御（外部からの入るトラフィック）は対向 AS のポリシータグ受容に依存するため、自 AS 単独では完全制御できない場合がある。 |
| **対応機種** | Cisco IOS-XE (Catalyst 9000, Catalyst 8000v, ISR 4000 等) 全機種。 |
| **制限事項** | Inbound/Outbound ポリシー変更時は `clear ip bgp <IP> soft [in\|out]`（Soft Reconfiguration / Route Refresh）が必要。 |
| **設計上の注意点** | BGP コミュニティパケットを対向へ送信する際は、明示的に `neighbor <IP> send-community [standard\|extended\|both]` のバインドが必須。 |

---

## 🏗 動作原理

BGP ルーティングポリシーは、BGP UPDATE パケットの送受信処理パイプラインの中で段階的に評価されます [127, Cisco BGP Overview; 133, Video Title: BGP Filtering and Manipulations]。

```text
[ Remote BGP Peer ]
       │
       │ BGP UPDATE (Inbound)
       ▼
┌────────────────────────────────────────────────────────┐
│ 1. Inbound Route Filtering (Prefix-list / Access-list) │
└──────────────────────────┬─────────────────────────────┘
                           │ Permit
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. Inbound Route-Map (Attribute Manipulation)          │
│    - Set Weight / Local-Preference / Community / MED   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. BGP Decision Process (Best Path Selection)          │
│    - 13-Step Algorithm Evaluation                      │
└──────────────────────────┬─────────────────────────────┘
                           │ Best Path Selected
                           ▼
┌────────────────────────────────────────────────────────┐
│ 4. RIB / FIB Insertion & Conditional Advertisement     │
│    - Check exist-map / non-exist-map                   │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼
┌────────────────────────────────────────────────────────┐
│ 5. Outbound Route Filtering (ORF / Outbound Prefix)    │
└──────────────────────────┬─────────────────────────────┘
                           │ Permit
                           ▼
┌────────────────────────────────────────────────────────┐
│ 6. Outbound Route-Map (Attribute Manipulation)         │
│    - Set AS_PATH Prepend / MED / Community             │
└──────────────────────────┬─────────────────────────────┘
                           │ BGP UPDATE (Outbound)
                           ▼
[ Neighbor BGP Peer ]
```

---

## ⚙ 動作シーケンス

### 1. 属性操作（Attribute Manipulation）の処理順序
1. **受信時（Inbound）:**
   * 対向ピアから受領した UPDATE パケットに対し、`in` 方向にバインドされた Route-Map を適用。
   * 自ルータローカルの `Weight` や、AS 内部全体に伝搬させる `Local Preference` を書き換えて BGP テーブル（Loc-RIB）へ格納 [55, 1.11.c]。
2. **ベストパス選定:**
   * 書き換えられた属性値を用いて BGP ベストパス選定アルゴリズム（13段階）を実行し、最適な経路を選択 [21, 1.5.b (ii); 55, 1.11.c]。
3. **送信時（Outbound）:**
   * 他のピアへアドバタイズする際、`out` 方向にバインドされた Route-Map を適用。
   * `AS_PATH Prepending`（AS 番号の重複付加）や `MED`、`Community` の付与を行い、対向 AS のパス選定に影響を与える [55, 1.11.c; 133, Video Title: BGP Filtering and Manipulations]。

### 2. 条件付きアドバタイズ（Conditional Advertisement）の制御シーケンス
`neighbor <IP> advertise-map <ADV_MAP> exist-map <EXIST_MAP>` (または `non-exist-map`) を使用：
1. **Exist-Map 評価:** BGP テーブル内に `EXIST_MAP` で指定されたプレフィックスが存在するか常時監視。
2. **条件判定:**
   * **`exist-map` 使用時:** 指定ルートが BGP テーブルに **存在する場合のみ**、`ADV_MAP` のプレフィックスを対向ピアへアドバタイズ [22, 1.5.c (ii)]。
   * **`non-exist-map` 使用時:** 指定ルートが BGP テーブルに **存在しない場合のみ**（プライマリ回線ダウン等）、`ADV_MAP` のバックアップ経路をアドバタイズ [22, 1.5.c (ii)]。

### 3. Outbound Route Filtering (ORF) の自動プッシュシーケンス
1. **Capability ネゴシエーション:** ピア樹立時、BGP OPEN パケット内で ORF 機能（`capability orf prefix-list`）を互いに通知 [22, 1.5.c (iii)]。
2. **Prefix-List プッシュ:** 受信側（Receive 側）でバインドされた `prefix-list` の条件を、ROUTE-REFRESH パケットに乗せて送信側（Send 側）ルータへ自動転送 [22, 1.5.c (iii)]。
3. **送信元フィルタリング:** 送信側ルータは受信した Prefix-List を自身の Outbound フィルターとして即座にバインドし、不要な UPDATE パケットの物理的送出を停止 [22, 1.5.c (iii)]。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、BGP Routing Policies は単に「ルートマップを設定せよ」という問題ではなく、**「特定のトラフィックを特定回線へ誘導せよ」「プライマリ回線障害時のみバックアップルートをアドバタイズせよ」「対向機器の CPU/帯域負荷を最小化するフィルタリングを構築せよ」** といったビジネス要件・制約条件の形が出題されます [22, 1.5.c]。

### 1. ラボ試験で頻出するテーマと注意点

#### ① インバウンド vs アウトバウンド トラフィック制御の属性選択
* **自 AS から出るトラフィック（Outbound Traffic）を制御したい場合:**
  * 自ルータのみに影響させたい場合 ➔ **`Weight`** を使用（`in` 方向 Route-Map で set weight） [55, 1.11.c]。
  * AS 内部の全ルータの出口を一括統合したい場合 ➔ **`Local Preference`** を使用（`in` 方向 Route-Map で set local-preference） [55, 1.11.c]。
* **外部から入ってくるトラフィック（Inbound Traffic）を制御したい場合:**
  * 相手に AS_PATH 長を長く見せかけて敬遠させる ➔ **`AS_PATH Prepending`**（`out` 方向 Route-Map で set as-path prepend） [55, 1.11.c; 133, Video Title: BGP Filtering and Manipulations]。
  * マルチホーム接続された同一対向 AS に対して自指定コストを通知する ➔ **`MED`**（`out` 方向 Route-Map で set metric） [55, 1.11.c]。

#### ② コミュニティパケット転送コマンドのバインド漏れ
* **極めて多いミス:** Route-Map で `set community` や `set extcommunity` を構成しても、該当ピアに対して `neighbor <IP> send-community [standard\|extended\|both]` を投入し忘れると、**送信時にコミュニティ属性が剥ぎ取られて単なる標準 UPDATE パケットとして送信** されます。
* 試験要件で「Community を使用して制御せよ」とあれば、必ず `send-community` コマンドを併記してください。

#### ③ 条件付きアドバタイズ (`advertise-map`) の指定プロンプトの混同
* `advertise-map` で使用する Route-Map 内の match 条件において、**`exist-map` に指定するルートマップは「監視対象のルート」のみを permit 形式で記述する** 必要があります。
* `non-exist-map` と `exist-map` のロジック逆転によるトラブルは、ラボ試験のトラブルシューティング問題（TS セクション）で頻出します。

#### ④ ORF (Outbound Route Filtering) の設定バインドと方向
* 送信側（Send 側）と受信側（Receive 側）で設定が非対称になります：
  * **受信側ルータ（フィルターを適用させたい側）:**
    `neighbor <IP> capability orf prefix-list receive`
    `neighbor <IP> prefix-list <LIST_NAME> in`
  * **送信側ルータ（フィルターを受信して送信制限する側）:**
    `neighbor <IP> capability orf prefix-list send`
* 送受信双方向で受容する場合は `both` を指定します [22, 1.5.c (iii)]。

---

## 🛠 設定方法

### 1. パス属性操作（Attribute Manipulation）設定例

```bash
# 1. Access-list / Prefix-list の定義
ip prefix-list PL_PRIMARY permit 10.100.0.0/16 ge 24
ip prefix-list PL_SECONDARY permit 10.200.0.0/16 ge 24

# 2. Route-Map による属性変更の定義
route-map RM_ISP_A_IN permit 10
 match ip address prefix-list PL_PRIMARY
 set local-preference 200
 set weight 35000
!
route-map RM_ISP_A_IN permit 20
 set local-preference 100
!
route-map RM_ISP_A_OUT permit 10
 match ip address prefix-list PL_SECONDARY
 set as-path prepend 65001 65001 65001
!
route-map RM_ISP_A_OUT permit 20

# 3. BGP プロセスへの適用
router bgp 65001
 neighbor 192.168.12.2 remote-as 64512
 neighbor 192.168.12.2 route-map RM_ISP_A_IN in
 neighbor 192.168.12.2 route-map RM_ISP_A_OUT out
```

### 2. 条件付きアドバタイズ（Conditional Advertisement）設定例

```bash
# 監視対象（Primary 経路：172.16.1.0/24）の定義
ip prefix-list PL_PRIMARY_WAN permit 172.16.1.0/24

# アドバタイズ対象（バックアップデフォルトルート：0.0.0.0/0）の定義
ip prefix-list PL_DEFAULT permit 0.0.0.0/0

route-map RM_CHECK_PRIMARY permit 10
 match ip address prefix-list PL_PRIMARY_WAN

route-map RM_ADV_DEFAULT permit 10
 match ip address prefix-list PL_DEFAULT

# 172.16.1.0/24 が BGP テーブルから消えた場合のみ (non-exist)、0.0.0.0/0 をアドバタイズ
router bgp 65001
 neighbor 192.168.99.2 remote-as 65099
 neighbor 192.168.99.2 advertise-map RM_ADV_DEFAULT non-exist-map RM_CHECK_PRIMARY
```

### 3. Outbound Route Filtering (ORF) 設定例

```bash
# 【受信側ルータ R1（フィルター要求元）】
ip prefix-list PL_ORF_ALLOWED permit 192.168.10.0/24
ip prefix-list PL_ORF_ALLOWED permit 192.168.20.0/24

router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 capability orf prefix-list receive
 neighbor 10.1.12.2 prefix-list PL_ORF_ALLOWED in

# 【送信側ルータ R2（フィルター適用元）】
router bgp 65002
 neighbor 10.1.12.1 remote-as 65001
 neighbor 10.1.12.1 capability orf prefix-list send
```

### 4. Community 属性（Standard & Extended & Well-Known）設定例

```bash
# Standard Community 宣言と Well-Known コミュニティ付与
ip community-list standard CL_NO_EXPORT permit 65001:100

route-map RM_COMM_TAG permit 10
 match ip address prefix-list PL_INTERNAL
 set community 65001:100 no-export

router bgp 65001
 neighbor 10.1.12.2 remote-as 64512
 neighbor 10.1.12.2 send-community both
 neighbor 10.1.12.2 route-map RM_COMM_TAG out
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブルにおける各属性（Weight, LocPrf, Path, Community）の確認** | <code>show ip bgp</code> / <code>show ip bgp <PREFIX></code> |
| **特定コミュニティが付与された BGP 経路の抽出表示** | <code>show ip bgp community 65001:100</code> / <code>show ip bgp community no-export</code> |
| **ORF ネゴシエーション状態および受信した ORF Prefix-List の確認** | <code>show ip bgp neighbors <IP> \| section ORF</code><br><code>show ip bgp neighbors <IP> received prefix-filter</code> |
| **特定ピアへ送信中（または受信済み）の BGP 経路一覧確認** | <code>show ip bgp neighbors <IP> advertised-routes</code><br><code>show ip bgp neighbors <IP> routes</code> |
| **条件付きアドバタイズ（Advertise-map）の動作ステート確認** | <code>show ip bgp neighbors <IP> \| include advertise-map</code> |
| **Route-Map / Prefix-List のマッチ回数・カウンター監査** | <code>show route-map</code> / <code>show ip prefix-list detail</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **Route-Map で `set community` を設定しているのに、対向ルータで Community が認識されない。** | 該当ピアに対して `neighbor <IP> send-community` コマンドが設定されていないため、送信時に破棄されている。 | `show running-config \| section bgp` | `neighbor <IP> send-community [standard\|extended\|both]` コマンドを追加バインドする。 |
| **AS_PATH Prepending を投入したのに、外部からのトラフィックが迂回されない。** | 1. 相手側 ISP が `Local Preference` で上書き固定している。<br>2. Prepend する AS 数が少なく、相手の最短パス評価を覆せていない。 | `show ip bgp <PREFIX>` (対向側) | 対向 ISP 担当者と協議し、対向側が認識する BGP Community タグを用いて ISP 内部の Local Preference を直接操作してもらう。 |
| **ORF を設定したが、送信側ルータに Prefix-List がプッシュされない。** | 1. ピア樹立時に Capability 属性のネゴシエーションが成立していない（`send`/`receive` ミスマッチ）。<br>2. ネゴ後に BGP セッションの再同期が実行されていない。 | `show ip bgp neighbors <IP>` | 双方向で `capability orf prefix-list`（一方が `send`、他方が `receive`）を確認し、`clear ip bgp <IP> soft` を実行する [22, 1.5.c (iii)]。 |
| **`non-exist-map` による条件付きアドバタイズが機能せず、常に経路が送信されてしまう。** | `non-exist-map` にバインドした Route-Map 内の match 条件が誤っており、監視ルートにマッチしていない（常に permit で通過してしまう）。 | `show route-map`<br>`show ip bgp` | `non-exist-map` にバインドした Prefix-List / Route-Map の条件式を見直し、監視対象ルートのみに正確にマッチするよう修正する [22, 1.5.c (ii)]。 |

---

## ⚠ 制限事項

1. **Weight 属性のローカル閉塞性:**
   * `Weight` 属性は設定したルータ 1 台内部でのみ有効（Loc-RIB 限定）であり、iBGP ピアや eBGP ピアへ送信される UPDATE パケットには含まれません [55, 1.11.c]。
2. **Standard Community 表記の標準化:**
   * IOS-XE のデフォルトではコミュニティ値が 32ビット 整数（例: `425990000`）で表示される場合があります。可読性の高い `AA:NN` 形式（例: `65001:100`）で表示・入力するには、グローバルで **`ip bgp-community new-format`** の投入が必須です。

---

## 🔄 他技術との関連

* **MPLS L3VPN / EVPN:**
  Extended Community（`Route Target: RT` および `Route Origin: SOO`）を利用して、VRF 間のルートインポート/エクスポートおよびデュアルホーム構成でのループ防止（Site-of-Origin）を制御します [22, 1.2.e, 1.5.c (iv)]。
* **Route Maps & Prefix Lists:**
  すべての BGP Routing Policies の基礎となるマッチングエンジン。`match community`, `match as-path`, `match ip address prefix-list` により精度の高い条件抽出を行います [55, 1.11.e]。

---

## 🧩 比較表

### Standard vs Extended vs Large Communities

| 比較項目 | Standard Community | Extended Community | Large Community |
| :--- | :--- | :--- | :--- |
| **ビット長** | 32 ビット (4 バイト) | 64 ビット (8 バイト) | 96 ビット (12 バイト) |
| **データ表記** | `ASN:NN` (例: `65001:100`) | `Type:ASN:NN` (例: `rt:65001:10`) | `ASN:Function:Value` (例: `65001:1:100`) |
| **主な用途** | AS 内/AS 間での任意トラフィックグループ化、Well-known 制御 | MPLS L3VPN (Route Target / SOO), Cost Community | 4-byte AS 環境における柔軟なグローバルコミュニティ定義 |
| **送信コマンド** | `neighbor send-community standard` | `neighbor send-community extended` | `neighbor send-community large` |

---

## 💡 ベストプラクティス

1. **`ip bgp-community new-format` の常時有効化:**
   コミュニティ設定を行う際は、初期コンフィグ段階で `ip bgp-community new-format` を投入し、`AA:NN` 記法を標準化する。
2. **コミュニティを活用したポリシータグ管理:**
   プレフィックスごとに個別 IP や Prefix-List で Route-Map を記述すると肥大化するため、境界ルータで Community タグを付与し、コア側では Community-List のみで分岐制御する構造にする。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Local Preference による AS アウトバウンドトラフィック一括制御
* **要件:** R1 (AS 65001) において、ISP-A (192.168.12.2) から学習する全経路の Local Preference を `200` に引き上げ、AS 内部全体のプライマリ出口とせよ [55, 1.11.c]。

**【R1】**
```bash
ip prefix-list PL_ALL permit 0.0.0.0/0 le 32
!
route-map RM_SET_LP_200 permit 10
 match ip address prefix-list PL_ALL
 set local-preference 200
!
router bgp 65001
 neighbor 192.168.12.2 remote-as 64512
 neighbor 192.168.12.2 route-map RM_SET_LP_200 in
```

**【検証方法】**
```bash
R1# clear ip bgp 192.168.12.2 soft in
R1# show ip bgp | include 192.168.12.2
# LocPrf 列が 200 に変更されていることを確認
```

---

### Scenario 2: AS_PATH Prepending によるインバウンドトラフィック迂回制御
* **要件:** R1 が ISP-B (192.168.13.3) へ自社プレフィックス `172.16.0.0/16` をアドバタイズする際、自 AS 番号 `65001` を 3 回追加（Prepend）して相手からの入出トラフィックを迂回させよ [55, 1.11.c; 133, Video Title: BGP Filtering and Manipulations]。

**【R1】**
```bash
ip prefix-list PL_MY_PREFIX permit 172.16.0.0/16
!
route-map RM_PREPEND_OUT permit 10
 match ip address prefix-list PL_MY_PREFIX
 set as-path prepend 65001 65001 65001
!
route-map RM_PREPEND_OUT permit 20
!
router bgp 65001
 neighbor 192.168.13.3 remote-as 64513
 neighbor 192.168.13.3 route-map RM_PREPEND_OUT out
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 192.168.13.3 advertised-routes
```

---

### Scenario 3: Conditional Advertisement (`exist-map`) 構成
* **要件:** 自社 HQ ルート `10.1.0.0/16` が BGP テーブルに存在する場合のみ (exist)、支店ルータへ `192.168.100.0/24` をアドバタイズせよ [22, 1.5.c (ii)]。

**【R1】**
```bash
ip prefix-list PL_HQ_ROUTE permit 10.1.0.0/16
ip prefix-list PL_BRANCH_ADV permit 192.168.100.0/24
!
route-map RM_EXIST_HQ permit 10
 match ip address prefix-list PL_HQ_ROUTE
!
route-map RM_ADV_BRANCH permit 10
 match ip address prefix-list PL_BRANCH_ADV
!
router bgp 65001
 neighbor 10.2.2.2 remote-as 65002
 neighbor 10.2.2.2 advertise-map RM_ADV_BRANCH exist-map RM_EXIST_HQ
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.2.2.2 advertised-routes
```

---

### Scenario 4: Non-Exist Conditional Advertisement (バックアップデフォルト生成)
* **要件:** プライマリ WAN ルート `172.16.10.0/24` が失われた場合のみ (non-exist)、バックアップピア (10.99.99.2) へデフォルトルート `0.0.0.0/0` を送出せよ [22, 1.5.c (ii)]。

**【R1】**
```bash
ip prefix-list PL_PRIMARY_WAN permit 172.16.10.0/24
ip prefix-list PL_DEFAULT_ROUTE permit 0.0.0.0/0
!
route-map RM_TRACK_PRIMARY permit 10
 match ip address prefix-list PL_PRIMARY_WAN
!
route-map RM_ADV_DEF permit 10
 match ip address prefix-list PL_DEFAULT_ROUTE
!
router bgp 65001
 neighbor 10.99.99.2 remote-as 65099
 neighbor 10.99.99.2 advertise-map RM_ADV_DEF non-exist-map RM_TRACK_PRIMARY
```

---

### Scenario 5: Prefix-List Outbound Route Filtering (ORF) 構成
* **要件:** R1（受信側）から R2（送信側）に対し、ORF 機能を用いて許可する Prefix-List を自動プッシュし、不要な UPDATE を送信元で遮断させよ [22, 1.5.c (iii)]。

**【R1 (Receive 側)】**
```bash
ip prefix-list PL_ALLOW_ONLY permit 10.200.0.0/16 ge 24
!
router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 capability orf prefix-list receive
 neighbor 10.1.12.2 prefix-list PL_ALLOW_ONLY in
```

**【R2 (Send 側)】**
```bash
router bgp 65002
 neighbor 10.1.12.1 remote-as 65001
 neighbor 10.1.12.1 capability orf prefix-list send
```

**【検証方法】**
```bash
R2# show ip bgp neighbors 10.1.12.1 received prefix-filter
# R1 からプッシュされた Prefix-List パラメータが表示されることを確認
```

---

### Scenario 6: Well-Known Community `NO_EXPORT` によるルート拡散防止
* **要件:** 外部から受信した `192.168.50.0/24` に対し `NO_EXPORT` コミュニティを付与し、自 AS 外部へ再アドバタイズされないよう制御せよ [22, 1.5.c (iv)]。

**【R1】**
```bash
ip bgp-community new-format
ip prefix-list PL_RESTRICT permit 192.168.50.0/24
!
route-map RM_SET_NO_EXP permit 10
 match ip address prefix-list PL_RESTRICT
 set community no-export additive
!
route-map RM_SET_NO_EXP permit 20
!
router bgp 65001
 neighbor 10.1.12.2 remote-as 64512
 neighbor 10.1.12.2 send-community standard
 neighbor 10.1.12.2 route-map RM_SET_NO_EXP in
```

---

### Scenario 7: Named Community-List によるコミュニティマッチングとパス消去
* **要件:** コミュニティ値 `65001:500` が付与された BGP 経路をフィルタリング（破棄）せよ [22, 1.5.c (iv)]。

**【R1】**
```bash
ip bgp-community new-format
ip community-list expanded CL_DROP_500 permit _65001:500_
!
route-map RM_FILTER_COMM deny 10
 match community CL_DROP_500
!
route-map RM_FILTER_COMM permit 20
!
router bgp 65001
 neighbor 10.1.14.4 remote-as 65001
 neighbor 10.1.14.4 route-map RM_FILTER_COMM in
```

---

### Scenario 8: BGP Cost Community による OSPF / BGP ポイント選定補正
* **要件:** iBGP ピア間で Cost Community (Point-of-Insertion: Pre-bestpath, Cost: 100) を設定し、ベストパス選定前に特定パスを優先させよ [22, 1.5.c (iv)]。

**【R1】**
```bash
route-map RM_SET_COST permit 10
 set extcommunity cost pre-bestpath 1 100
!
router bgp 65001
 neighbor 10.1.12.2 remote-as 65001
 neighbor 10.1.12.2 send-community extended
 neighbor 10.1.12.2 route-map RM_SET_COST in
```

---

### Scenario 9: Multi-Homing での Primary/Backup (MED 制御)
* **要件:** 同一 ISP (AS 64512) にデュアルホーム接続された R1 と R2 において、R1 の出口 MED を `50`、R2 の出口 MED を `200` に設定してインバウンド入り口を R1 へ固定せよ [55, 1.11.c]。

**【R1 (Primary)】**
```bash
route-map RM_MED_PRIMARY permit 10
 set metric 50
!
router bgp 65001
 neighbor 192.168.12.2 remote-as 64512
 neighbor 192.168.12.2 route-map RM_MED_PRIMARY out
```

**【R2 (Backup)】**
```bash
route-map RM_MED_BACKUP permit 10
 set metric 200
!
router bgp 65001
 neighbor 192.168.22.2 remote-as 64512
 neighbor 192.168.22.2 route-map RM_MED_BACKUP out
```

---

### Scenario 10: Large Community (96-bit) 構成
* **要件:** 4-byte AS 環境下で Large Community (`65536:1:100`) を付与してアドバタイズせよ [22, 1.5.c (iv)]。

**【R1】**
```bash
ip prefix-list PL_LARGE permit 10.250.0.0/16
!
route-map RM_LARGE_COMM permit 10
 match ip address prefix-list PL_LARGE
 set large-community 65536:1:100
!
router bgp 65536
 neighbor 10.1.12.2 remote-as 65537
 neighbor 10.1.12.2 send-community large
 neighbor 10.1.12.2 route-map RM_LARGE_COMM out
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読バック/トラブル】send-community 欠落によるコミュニティ透過障害
**問題:** 
R1 は R2 に対して Route-Map を用いて Community `65001:100` を付与して送信しています。しかし、R2 の BGP テーブルを確認するとコミュニティ属性が付与されていません。R1 の設定を確認したところ以下の状態でした。障害原因と追加すべきコマンドを回答してください。
```text
router bgp 65001
 neighbor 10.1.12.2 remote-as 65001
 neighbor 10.1.12.2 route-map RM_SET_COMM out
```

**解答・解説:**
* **障害原因:** 
  Cisco IOS-XE の BGP 実装では、デフォルトで送信する UPDATE パケットから Standard / Extended Community 属性が自動的に取り除かれます。明示的なコミュニティ送信コマンドが設定されていないことが原因です。
* **追加コマンド:**
  ```text
  router bgp 65001
   neighbor 10.1.12.2 send-community both
  ```

---

### 2. 【Design】Conditional Advertisement による動的バックアップアドバタイズ
**問題:** 
企業ネットワークにおいて、通常時はプライマリ回線（10.1.1.0/24）経由で全通信を処理しており、このプライマリ網が健在な間はバックアップルータ R2 は外部へ自社サマリ経路 `10.1.0.0/16` をアドバタイズしてはなりません。プライマリ網の 10.1.1.0/24 がダウンした場合のみ、R2 から自動的に 10.1.0.0/16 をアドバタイズさせる BGP コマンド構成を提示してください。

**解答・解説:**
* **構成コマンド:**
  ```text
  ip prefix-list PL_TRACK_PRIMARY permit 10.1.1.0/24
  ip prefix-list PL_SUMMARY permit 10.1.0.0/16
  !
  route-map RM_NON_EXIST_PRIMARY permit 10
   match ip address prefix-list PL_TRACK_PRIMARY
  !
  route-map RM_ADV_SUMMARY permit 10
   match ip address prefix-list PL_SUMMARY
  !
  router bgp 65002
   neighbor 192.168.20.2 remote-as 64512
   neighbor 192.168.20.2 advertise-map RM_ADV_SUMMARY non-exist-map RM_NON_EXIST_PRIMARY
  ```

---

## 🔗 参考リソース

* [Cisco Systems: BGP Configuration Guide, Cisco IOS XE 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/17-x/ti-17-x-book.html)
* [Cisco Command Reference: BGP Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book.html)
* [Cisco Live: BRKRST-2337 - Advanced BGP Routing Policies and Multihoming](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **BGP 属性適用方向と影響範囲:**
  * `Weight`: Inbound 適用 / 自ルータ内のみ保持（0-hop） [55, 1.11.c]
  * `Local Preference`: Inbound 適用 / AS 内部全体に伝搬（iBGP 全域） [55, 1.11.c]
  * `AS_PATH Prepend`: Outbound 適用 / 隣接 AS および全外部 AS に伝搬 [55, 1.11.c]
  * `MED`: Outbound 適用 / 直結隣接 AS 内部のみに伝搬（再転送不可） [55, 1.11.c]


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - 属性操作とベストパス選定の深い解説。
*   [BRKRST-3320: Troubleshooting BGP](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - ポリシー不整合によるルーティングトラブルの解決。

### Configurationガイド
*   [BGP Case Studies: Influencing Path Selection](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html) - 属性操作の定番ドキュメント。
*   [Configuring BGP Route Filtering](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-filter-config.html) - フィルタリングとコミュニティの公式ガイド。

### テクニカルドキュメント・設定例
*   [BGP Best Path Selection Algorithm](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html) - 決定プロセスの詳細ステップ。
*   [Understanding BGP Communities](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/28784-bgp-community.html) - コミュニティ活用の技術解説。

---

## 📝 補足
- この学習メモは、BGP のポリシー制御が「どの属性を、どのタイミングで、どの方向に適用するか」という論理的なパズルであることを示しています。CCIE EI ラボ試験では、特にコミュニティを用いたタグ付けと、Regex を利用した正確なパス抽出が、迅速なトラブル解決の鍵となります。


