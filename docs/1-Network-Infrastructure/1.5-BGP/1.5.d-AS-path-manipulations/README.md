---
layout: default
title: 1.5.d-AS-path-manipulations
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.5.d AS path manipulations

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 BGP トラフィック制御技術である **BGP AS Path Manipulations（AS パス操作・変換・制御機能）** について、Cisco IOS-XE 17.x の実装基準に 100% 準拠して学術的・実践的背景から詳細に解説します。

---

## 📘 概要

BGP（Border Gateway Protocol）は、自律システム（AS: Autonomous System）間でのルーティング情報を交換するパスベクター型プロトコルです。そのコアとなるパス属性が **AS_PATH 属性（Type Code 2）** です。AS_PATH 属性は、該当ルーティング情報が通過してきた AS 番号のリストを記録し、**AS 単位でのループ防止メカニズム（自 AS 番号が含まれる UPDATE パケットの破棄）** および **パス選定（より短い AS_PATH 長の優先）** に直接利用されます。

**AS Path Manipulations（AS パス操作）** とは、この標準的な AS_PATH 属性の付与・検証・除去・置換ルールに対して、特定のネットワーク要件（企業買収・AS 移行、SP 網との同種 AS 接続、マルチホーム環境でのインバウンドトラフィック制御、正規表現による高度なルートフィルタリング等）を満たすために手動または動的に介入・制御を行う一連の技術群を指します。

### 主な対象技術要素
1. **`local-as`:** グローバル BGP プロセスの AS 番号を変更することなく、特定の eBGP ピアに対してのみローカルの代替 AS 番号を提示・受容する機能（AS 統合・買収時の無停止移行基盤）。
2. **`allowas-in`:** 通常は AS ループ防止により拒否される「自 AS 番号が含まれた BGP ルート」の受容を特定回数まで明示的に許可する機能（MPLS L3VPN CE-PE 接続や同一 AS 拠点間での WAN 迂回）。
3. **`remove-private-as`:** インターネット（Public BGP ドメイン）へ経路を送出する際、プライベート AS 番号（64512〜65535 / 4200000000〜4294967295）を AS_PATH から自動削除・置換する機能。
4. **`AS path prepending`:** Route-Map を使用して AS_PATH 内に意図的に自 AS 番号や指定 AS 番号を重複挿入（Prepending）し、パス長を長く見せることで対向 AS からのインバウンドトラフィックを迂回させるトラフィックエンジニアリング手法。
5. **`Regular expressions (Regex)`:** 正規表現を用いて AS_PATH 文字列のパターン（通過 AS、起点 AS、直結 AS 等）を精密にマッチングし、`ip as-path access-list` や Route-Map で制御する高度なフィルタリング手法。

---

## 🔑 要点

| 機能 | 概要 / 特徴 | 主な用途 | メリット | デメリット / 注意点 |
| :--- | :--- | :--- | :--- | :--- |
| **`local-as`** | 該当 ピアに対してのみ指定した代替 AS 番号を偽装・提示する。 | 企業買収・組織再編・AS 番号統合時の無停止移行。 | 相手側のコンフィグを変更させずに自社側 AS を静かに変更可能。 | オプション（`no-prepend`, `replace-as`, `dual-as`）の挙動理解が必須。 |
| **`allowas-in`** | 自 AS 番号が AS_PATH に含まれるルートの受信を許可する。 | MPLS L3VPN で複数拠点（CE）が同一 AS 番号を使用する場合。 | 異拠点間でのルーティングループ判定による拒否を安全に解除可能。 | カウント数誤設定により無制限ループが発生するリスクがある。 |
| **`remove-private-as`** | eBGP ピアへ送信する際、プライベート AS 番号を削除・置換する。 | ISP 境界、エンタープライズのインターネット接続口。 | Public インターネットへプライベート AS 情報が漏洩するのを防御。 | eBGP ピア間で AS_PATH 内に Public AS が混在していると削除されない場合がある（`all` オプションで回避）。 |
| **`AS path prepending`** | AS_PATH に同一 AS 番号を複数回追加してパス長を意図的に伸ばす。 | インバウンドトラフィックの誘導（Primary/Backup 回線制御）。 | 相手側 AS のコンフィグに頼らず自 AS から流入トラフィックを制御可能。 | 対向 ISP 側で Local Preference が上書き設定されている場合は無効化される。 |
| **`Regular expressions`** | 文字列パターン照合（`^`, `$`, `_`, `*`, `+` 等）による AS_PATH フィルタ。 | トランジット AS 拒否、特定 AS 起点ルートの選択的受信/破棄。 | 単一の行で複雑な AS パス条件を柔軟かつ強力に識別可能。 | 記号の意味（特に `_` の境界判定）を誤ると意図しないルートを遮断・通過させる。 |

---

## 🏗 動作原理

### 1. `local-as` の 3 つのオプション展開メカニズム
グローバル AS が **AS 65000**、`local-as` で指定する代替 AS が **AS 100**、対向 eBGP ピアが **AS 200** の場合の動作。

```text
[ 自ルータ: Global AS 65000 ]  <===== eBGP Peer =====>  [ 対向ルータ: AS 200 ]
   (neighbor 10.1.1.2 local-as 100)
```

* **① デフォルト (`local-as 100`):**
  * 受信時: 送信元が AS 100 宛てに送信したパケットを受容。
  * 送信時 (Outbound AS_PATH): **`65000 100`** （グローバル AS と local-as の両方が先頭に付加される）。
* **② `no-prepend` 付与 (`local-as 100 no-prepend`):**
  * 送信時 (Outbound AS_PATH): **`100`** のみ（グローバル AS 65000 の付加を抑制）。
* **③ `replace-as` 付与 (`local-as 100 no-prepend replace-as`):**
  * 受信時: AS 100 からの受信ルート処理において、自機内部で AS 65000 へ置換し、内部 iBGP ピアへ伝搬する際のループ判定を正常化。
* **④ `dual-as` 付与 (`local-as 100 dual-as`):**
  * 対向ルータが AS 100 宛て・AS 65000 宛てのどちらでピア接続を試みてきてもセッション確立を許可（無停止切り替え用）。

---

### 2. `allowas-in` の動作フロー (MPLS L3VPN 同一 AS CE 接続)

```text
[ CE-1 (AS 65000) ]  ──►  [ PE-1 ]  ── (MPLS VPN) ──►  [ PE-2 ]  ──►  [ CE-2 (AS 65000) ]
  ルート: 10.1.1.0/24                                                 通常: AS_PATH "65000" を検知し破棄！
  AS_PATH: "65000"                                                    allowas-in 1 設定時: 受容許可！
```

1. CE-1 (AS 65000) が `10.1.1.0/24` をアドバタイズ (AS_PATH: `65000`)。
2. PE-1 / PE-2 経由で MP-BGP 伝搬後、PE-2 が CE-2 (AS 65000) へ送信。
3. CE-2 は本来、受信した AS_PATH に自 AS である `65000` が入っているため **AS ループ検出で即座に破棄** します。
4. CE-2 で `neighbor <PE-2> allowas-in 2` をバインドしておくと、自 AS が **最大 2 回まで** 含まれていても破棄せず BGP テーブルへ格納します。

---

### 3. `remove-private-as` の動作制御

```text
[ CE Router ]  ─────────►  [ Enterprise Edge ]  ─────────►  [ ISP Router (Public) ]
 AS 64512 (Private)          AS 65001 (Private)               AS 100 (Public)
                             (remove-private-as all)
```

* **基本ルール:** 送信先が **eBGP ピア** である場合のみ動作します（iBGP では動作しません）。
* **通常動作 (`remove-private-as`):** AS_PATH の先頭から連続するプライベート AS のみを削除します。途中に Public AS が挟まっている場合（例: `64512 200 64513`）、安全のため削除処理を停止します。
* **`all` オプション (`remove-private-as all`):** 位置に関わらず、AS_PATH 内に存在するすべてのプライベート AS 番号を削除します。
* **`replace-as` オプション (`remove-private-as all replace-as`):** プライベート AS を単に消して AS_PATH 長を縮めるのではなく、自 AS 番号に置き換えることで AS_PATH 長を維持します。

---

## ⚙ 動作シーケンス

```text
[ BGP UPDATE Packet Generation / Processing ]
                   │
                   ▼
       [ Inbound or Outbound Check ]
                   │
    ┌──────────────┴──────────────┐
    ▼                             ▼
[ Inbound Processing ]       [ Outbound Processing ]
    │                             │
    ├─► 1. Check AS Loop          ├─► 1. Check remove-private-as
    │      └─ Is own AS in PATH?  │      └─ Remove 64512-65535
    │         ├─ YES: Allowas-in? │
    │         │  ├─ YES (<= N): OK│      ├─► 2. Apply Route-Map
    │         │  └─ NO: DROP      │      │      └─ set as-path prepend
    │         └─ NO: Pass         │      │
    │                             ├─► 3. Check local-as
    ├─► 2. Match ip as-path       │      ├─ Append local-as
    │      └─ Regex evaluation    │      └─ Suppress global AS if no-prepend
    │                             │
    └─► 3. Local-as Replace       └─► 4. Append Own Global AS
           (replace-as option)           (Standard eBGP behavior)
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. ラボ試験での頻出出題パターンとトラップ
CCIE EI Practical Lab では、単にコマンドを投入するだけでなく、**相反する条件制限（例: 「対向ルータのコンフィグを変更してはならない」「AS_PATH 長を変えてはならない」「Public インターネットへプライベート AS を漏洩させてはならない」）** の中で正確なオプションを選択させる出題がなされます。

* **トラップ 1: `local-as` での二重 AS 付与によるパス選定障害**
  * `neighbor <IP> local-as 100` を単に設定すると、送信経路の AS_PATH に **`65000 100`** の 2 つが自動的に追加され、対向側で AS_PATH が長くなってバックアップ経路に落ちてしまう現象が発生します。
  * **対策:** 問題文で「AS_PATH 長を変化させるな」とある場合は、必ず **`no-prepend`** または **`no-prepend replace-as`** を付与します。
* **トラップ 2: `remove-private-as` が効かないケース**
  * 送信対象が eBGP ではなく iBGP ピアである場合、`remove-private-as` は **完全に無視** されます。
  * AS_PATH 内に Public AS が混在している（例: `65001 200 65002`）場合、標準の `remove-private-as` では除去されません。必ず **`all`** オプションを指定する必要があります。
* **トラップ 3: `allowas-in` の不適切な設定による永久ループ**
  * フルメッシュの eBGP トポロジーで `allowas-in` のカウントを無制限（デフォルト 3 など）に許可すると、リンク障害時にループルートが巡回し続けます。必要最低限のカウント数（通常 `1` または `2`）を指定することが厳守されます。

---

### 2. Regex（正規表現）の最重要文字と判定テクニック
`ip as-path access-list` で指定する BGP Regex は、試験で 100% 問われる知識です。

| 記号 | 意味 | 使用例 | マッチする AS_PATH の例 |
| :--- | :--- | :--- | :--- |
| **`^`** | 行の先頭 | `^100_` | 直結している隣接 eBGP ピアが AS 100 であるルート |
| **`$`** | 行の末尾 | `_100$` | 該当ルートの発生元（Origin AS）が AS 100 であるルート |
| **`_`** | 境界文字 (スペース, カンマ, 行頭, 行末) | `_100_` | 経路上のどこかで AS 100 を通過しているルート |
| **`^$`** | 空の文字列 (文字なし) | `^$` | **自ルータで発生（ローカル生成）したルートのみ** |
| **`.*`** | 任意の文字列（全マッチ） | `.*` | **すべてのルート（ワイルドカード）** |
| **`^[0-9]+$`** | 数字のみの単一 AS | `^[0-9]+$` | **直結 AS から発生した（1 Hop のみ通過した）ルート** |

---

## 🛠 設定方法

### 1. `local-as` の設定 (Named Mode & Classic Mode)

```bash
# Named Mode での完全設定
router eigrp GLOBAL_BGP
 !
 address-family ipv4 unicast
  neighbor 192.168.12.2 remote-as 200
  neighbor 192.168.12.2 local-as 100 no-prepend replace-as
 exit-address-family
```

### 2. `allowas-in` の設定

```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.1.1.1 remote-as 65001
  neighbor 10.1.1.1 allowas-in 2
 exit-address-family
```

### 3. `remove-private-as` の設定

```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 203.0.113.1 remote-as 100
  neighbor 203.0.113.1 remove-private-as all replace-as
 exit-address-family
```

### 4. Route-Map による `AS path prepending` 設定

```bash
route-map PREPEND_INBOUND permit 10
 set as-path prepend 65000 65000 65000
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 203.0.113.1 route-map PREPEND_INBOUND out
 exit-address-family
```

### 5. Regex による AS_PATH フィルタリング設定

```bash
# AS 100 から発生したルートのみを許可
ip as-path access-list 1 permit _100$
# 直結 AS 200 経由のルートを拒否し、その他を許可
ip as-path access-list 2 deny ^200_
ip as-path access-list 2 permit .*
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.2.2.2 filter-list 1 in
  neighbor 10.3.3.3 filter-list 2 in
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブルの AS_PATH 属性および受容経路の確認** | <code>show ip bgp</code> / <code>show ip bgp ipv4 unicast</code> |
| **特定プレフィックスの AS_PATH 詳細（Prepend や local-as 付与履歴）監査** | <code>show ip bgp 10.1.1.0/24</code> |
| **特定ネイバーから受信したルートの AS_PATH 確認** | <code>show ip bgp neighbors 10.1.1.1 routes</code> |
| **特定ネイバーへ送信する（Prepend/remove-private-as 適用後）ルートの確認** | <code>show ip bgp neighbors 10.1.1.1 advertised-routes</code> |
| **AS-PATH Access-List (Regex) にマッチするルートの動作フィルタテスト** | <code>show ip bgp regexp &lt;REGEX_PATTERN&gt;</code> |
| **BGP UPDATE パケット送受信のリアルタイムデバッグ** | <code>debug ip bgp updates</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`local-as` 設定後、対向ルータ側で AS_PATH が長くなり、トラフィックが迂回してしまう。** | `no-prepend` オプションが抜けているため、グローバル AS と local-as の両方がアドバタイズされている。 | `show ip bgp neighbors <IP> advertised-routes` | `neighbor <IP> local-as <AS> no-prepend` を追加投入してグローバル AS の付加を抑制する。 |
| **MPLS L3VPN CE ルータで、対向拠点からのルートが BGP テーブルに入らない。** | CE ルータが自 AS 番号を検出して AS ループ防止機能により UPDATE を破棄している。 | `show ip bgp`（ルート非掲載）<br>`debug ip bgp updates` | CE ルータ側で `neighbor <PE-IP> allowas-in 2` をバインドして受容を許可する。 |
| **`remove-private-as` を入れたのに、プライベート AS (64512 等) が消去されずに送信される。** | 1. ピアが iBGP である。<br>2. AS_PATH 内で Public AS の後にプライベート AS が位置している。 | `show ip bgp neighbors <IP> advertised-routes` | 1. eBGP ピアに対してのみ設定する。<br>2. `neighbor <IP> remove-private-as all` オプションを指定する。 |
| **AS_PATH Prepending を設定したのに、対向 ISP からのインバウンドトラフィックが変化しない。** | 対向 ISP 側で `Local Preference` が手動設定されており、AS_PATH 長による比較ステップに到達していない。 | 対向 ISP 側のルータ監査（または Looking Glass 参照） | 対向 ISP 側の運用者に連絡して Local Preference の調整を依頼するか、BGP Community（`NO_EXPORT` 等）や MED を併用する。 |

---

## ⚠ 制限事項

1. **`remove-private-as` の適用範囲:**
   * eBGP ピア宛ての送出 UPDATE にのみ有効です。iBGP ピアへ送信される UPDATE 内のプライベート AS は保持されます。
2. **`allowas-in` の上限値:**
   * Cisco IOS-XE における `allowas-in` の最大許容カウントは通常 10 回までです（実務・試験では 1〜3 回程度で運用）。

---

## 🔄 他技術との関連

* **MPLS L3VPN (3.2.b):**
  PE-CE 間で BGP を使用し、複数拠点 CE で同一の AS 番号を使い回す設計（Same-AS Site）において、`allowas-in` または PE 側の `as-override` が必須となります。
* **BGP Community (1.5.c (iv)):**
  AS_PATH Prepending と組み合わせて、対向 ISP 内部の `Local Preference` を動的に変更させるコミュニティタグ（例: `100:80` で Local-Pref 80 化）を付与する設計。

---

## 🧩 比較表

### `allowas-in` vs `as-override`

| 比較項目 | `allowas-in` | `as-override` |
| :--- | :--- | :--- |
| **設定場所** | **CE ルータ側** | **PE ルータ側** |
| **動作原理** | 受信側 CE が「自 AS が含まれていても受容する」。 | 送信側 PE が「CE の AS 番号を PE の AS 番号で上書き消去する」。 |
| **AS_PATH 変化** | AS_PATH 内に元の AS 番号が残る（例: `65000 100 65000`）。 | AS_PATH から CE の AS 番号が消え、PE の AS に置換される（例: `100 100`）。 |
| **適用シーン** | CE ルータの管理権限があり、CE 側で制御したい場合。 | 企業（顧客）が CE ルータの設定変更を望まない場合。 |

---

## 💡 ベストプラクティス

1. **`local-as` 運用時は `no-prepend replace-as` を標準セットとする:**
   無駄な AS_PATH の延伸を防ぎ、かつ内部 iBGP への伝搬時のループ判定を正常に保つため、`local-as <AS> no-prepend replace-as` の組み合わせを使用する。
2. **Regex テストの事前実行:**
   `ip as-path access-list` を Route-Map や Filter-List にバインドする前に、必ず `show ip bgp regexp <PATTERN>` コマンドを実行して意図通りのルートのみが抽出されているか検証する。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI Practical Lab レベルに対応する省略なしの 10 個の実践演習シナリオです。

### Scenario 1: `local-as` 基本構成 (AS 統合・移行)
* **要件:** R1 (Global AS 65000) は R2 (AS 200) と eBGP ピアを確立する。R2 側は R1 を AS 100 として認識している。R2 側のコンフィグを変更させずに、R1 側で `local-as` を用いてピアを成立させよ。AS_PATH を余計に延伸させてはならない。

**【R1 コンフィグ】**
```bash
router bgp 65000
 bgp log-neighbor-changes
 address-family ipv4 unicast
  neighbor 192.168.12.2 remote-as 200
  neighbor 192.168.12.2 local-as 100 no-prepend replace-as
  network 1.1.1.1 mask 255.255.255.255
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp 1.1.1.1
# AS_PATH が "100 i" となっており、65000 が付加されていないことを確認
```

---

### Scenario 2: `allowas-in` による Same-AS 拠点間疎通
* **要件:** CE-1 (AS 65000) と CE-2 (AS 65000) は MPLS 網を挟んで接続されている。CE-2 上で CE-1 からのルート `10.1.1.0/24`（AS_PATH 内に 65000 含有）を受容できるよう `allowas-in` を構成せよ。

**【CE-2 コンフィグ】**
```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 172.16.25.2 remote-as 100
  neighbor 172.16.25.2 allowas-in 2
 exit-address-family
```

**【検証方法】**
```bash
CE-2# show ip bgp 10.1.1.0/24
# AS_PATH に 65000 が含まれていても Valid/Best ルートとして RIB に登録されていることを確認
```

---

### Scenario 3: `remove-private-as` によるプライベート AS の完全排除
* **要件:** R1 (AS 65000) から ISP-1 (AS 100) へルートを送信する際、AS_PATH 内に含まれるすべてのプライベート AS 番号 (64512〜65535) を消去して送出せよ。

**【R1 コンフィグ】**
```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 203.0.113.2 remote-as 100
  neighbor 203.0.113.2 remove-private-as all
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 203.0.113.2 advertised-routes
# 送信ルートの AS_PATH からプライベート AS が消去されていることを確認
```

---

### Scenario 4: Route-Map による `AS path prepending` (インバウンド制御)
* **要件:** R1 (AS 65000) は ISP-1 (AS 100) と ISP-2 (AS 200) にマルチホーム接続されている。ISP-2 側からのインバウンドトラフィックを迂回させるため、ISP-2 宛ての全送信ルートに対して自 AS 番号を 3 回 Prepend せよ。

**【R1 コンフィグ】**
```bash
route-map PREPEND_ISP2 permit 10
 set as-path prepend 65000 65000 65000
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 192.168.12.2 remote-as 100
  neighbor 192.168.14.4 remote-as 200
  neighbor 192.168.14.4 route-map PREPEND_ISP2 out
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 192.168.14.4 advertised-routes
# 送信ルートの AS_PATH が "65000 65000 65000 65000 i" になっていることを確認
```

---

### Scenario 5: Regex による特定 Origin AS ルートのフィルタリング
* **要件:** R1 は eBGP ピア 10.1.1.1 から多数のルートを受信している。Origin AS（発生元 AS）が **AS 300** であるルートのみを受信許可し、それ以外を破棄せよ。

**【R1 コンフィグ】**
```bash
ip as-path access-list 10 permit _300$
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.1.1.1 remote-as 100
  neighbor 10.1.1.1 filter-list 10 in
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp regexp _300$
# BGP テーブル内で Origin AS が 300 のプレフィックスのみが登録されていることを確認
```

---

### Scenario 6: Regex によるローカル生成ルート（`^$`）の個別再配送・送信制御
* **要件:** R1 は iBGP および eBGP から多数のルートを受信している。隣接 eBGP ピア 203.0.113.5 に対して、**R1 自身がローカル生成（`network` や `redistribute`）したルートのみ** を送出し、他 AS から学習したルートの中継（Transit）を完全に遮断せよ。

**【R1 コンフィグ】**
```bash
ip as-path access-list 20 permit ^$
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 203.0.113.5 remote-as 500
  neighbor 203.0.113.5 filter-list 20 out
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 203.0.113.5 advertised-routes
# 送信ルートの AS_PATH がすべて空（ローカル生成）ルートのみであることを確認
```

---

### Scenario 7: Regex による直結 1 Hop 発行ルート (`^[0-9]+$`) の抽出
* **要件:** 隣接 eBGP ピアから学習したルートのうち、**直結している隣接 AS 自身が直接発生させたルート（1 Hop のみ通過したルート）** のみに `Local Preference 200` を付与せよ。

**【R1 コンフィグ】**
```bash
ip as-path access-list 30 permit ^[0-9]+$
!
route-map DIRECT_AS_PREF permit 10
 match as-path 30
 set local-preference 200
!
route-map DIRECT_AS_PREF permit 20
!
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.1.1.1 remote-as 100
  neighbor 10.1.1.1 route-map DIRECT_AS_PREF in
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp
# AS_PATH が単一数字のルートのみ Local-Pref 200 に上昇していることを確認
```

---

### Scenario 8: `remove-private-as replace-as` による AS パス長保持
* **要件:** eBGP ピア 203.0.113.2 宛てにルートを送信する際、プライベート AS を消去しつつ、AS_PATH 長が縮んでルーティング選定が変わるのを防ぐため、消去したプライベート AS 分を自 AS 番号に置換せよ。

**【R1 コンフィグ】**
```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 203.0.113.2 remote-as 100
  neighbor 203.0.113.2 remove-private-as all replace-as
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 203.0.113.2 advertised-routes
# プライベート AS が消去され、代わりに 65000 が置換挿入されていることを確認
```

---

### Scenario 9: `local-as dual-as` による無停止 AS 番号切り替え
* **要件:** R1 は現在 AS 65000 で動作しているが、組織再編により AS 65100 へ無停止で移行する。対向 R2 が旧 AS (65000) または新 AS (65100) のどちらで接続を試みてもセッションを成立させよ。

**【R1 コンフィグ】**
```bash
router bgp 65100
 address-family ipv4 unicast
  neighbor 192.168.12.2 remote-as 200
  neighbor 192.168.12.2 local-as 65000 dual-as
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp summary
# R2 側の設定変更なしで BGP ピアが State Established に保持されることを確認
```

---

### Scenario 10: VRF-Aware BGP 環境での AS Path Manipulation 複合構成
* **要件:** VRF `TENANT_A` (AS 65001) 配下の eBGP ピア 10.200.1.2 に対し、プライベート AS 削除と `allowas-in 2` を同時バインドせよ。

**【R1 コンフィグ】**
```bash
vrf definition TENANT_A
 rd 65001:1
 address-family ipv4
exit-vrf
!
router bgp 65001
 address-family ipv4 unicast vrf TENANT_A
  neighbor 10.200.1.2 remote-as 65002
  neighbor 10.200.1.2 allowas-in 2
  neighbor 10.200.1.2 remove-private-as all
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp vrf TENANT_A neighbors 10.200.1.2
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】`local-as` 設定に伴うインバウンド迂回障害
**問題:** 
企業統合に伴い、R1 (Global AS 65000) で `neighbor 192.168.12.2 local-as 100` を投入した直後、対向 R2 から R1 へのトラフィックがすべてバックアップ回線（別ルータ経由）へ迂回してしまいました。R2 側の設定は一切変更されていません。何が原因でこの迂回が発生したか説明し、R1 側で正しくプライマリ回線へ復旧させるコンフィグ修正を提示してください。

**解答・解説:**
* **原因:** 
  `local-as 100` をオプションなしで設定すると、R1 から R2 へ送信される UPDATE の AS_PATH に **`65000 100`** と 2 つの AS 番号が連番で挿入されます。これにより、R2 側から見た R1 宛てルートの AS_PATH 長が 1 Hop 分長くなり、BGP ベストパス選定ステップ 4 (AS_PATH 長比較) により、AS_PATH 長が短いバックアップ回線側が優先選定されたためです。
* **修正コンフィグ:**
  グローバル AS (65000) の付加を抑止するため、`no-prepend` オプションを追加します。
  ```bash
  router bgp 65000
   address-family ipv4 unicast
    neighbor 192.168.12.2 local-as 100 no-prepend replace-as
   exit-address-family
  ```

---

### 2. 【コンフィグ読解・Regex】AS_PATH フィルタの動作判定
**問題:** 
以下の BGP コンフィグが投入されたルータ R1 が受容するルートとして **正しくマッチするもの** をすべて選んでください。
```bash
ip as-path access-list 5 permit ^(100|200)_300_$
```
1. 自 AS 内で生成されたローカルルート (`^$`)
2. AS 100 を通過し、Origin AS が 300 である 2 Hop のルート (`100 300`)
3. AS 200 を通過し、Origin AS が 300 である 2 Hop のルート (`200 300`)
4. AS 100 ➔ AS 200 ➔ AS 300 を通過した 3 Hop のルート (`100 200 300`)

**解答・解説:**
* **正解:** **2 および 3**
* **解説:** 
  正規表現 `^(100|200)_300_$` は以下のように分解評価されます。
  * `^`: 行頭（直結隣接 AS）
  * `(100|200)`: 100 または 200 のいずれか
  * `_300_`: 境界に囲まれた 300
  * `$`: 行末（Origin AS）
  したがって、直結 AS が 100 または 200 であり、かつその直後の Origin AS が 300 である **「合計 2 Hop (100 300 または 200 300)」** のルートのみに厳密にマッチします。

---

## 🔗 参考リソース

* [Cisco Systems: BGP Configuration Guide - Configuring BGP Path Manipulations](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)
* [Cisco Command Reference: BGP Commands (local-as, allowas-in, remove-private-as)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book.html)
* [Cisco Live: BRKRST-3320 - Advanced BGP Path Manipulation and Traffic Engineering](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **Regex クイック検証用コマンド:**  
  実機・試験で Regex の動作を確かめる際は、必ず以下のコマンドを活用すること。
  `R1# show ip bgp regexp ^100_`


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates (Deep Dive into AS_PATH)](https://www.ciscolive.com/global/on-demand-library.html)。
*   [BRKRST-3320: Troubleshooting BGP (AS Path Manipulations & Regex)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)。

### Configurationガイド
*   [BGP Case Studies: Influence Path Selection with AS_PATH](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)。
*   [Configuring BGP Local AS - Cisco IOS XE](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-local-as.html)。

### テクニカルドキュメント・設定例
*   [BGP Best Path Selection Algorithm (AS_PATH step)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)。
*   [Using Regular Expressions in BGP (Tech Note)](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13750-22.html)。

---

## 📝 補足
- この学習メモは、BGP の AS_PATH 操作を「単なるフィルタリング」ではなく、「組織の境界をまたぐトラフィックデザインと移行の戦略」として定義しています。CCIE EI ラボ試験では、Regex を用いた正確なパスの絞り込みと、local-as による無停止移行の構成が非常に高い配点を持つため、実機（EVE-NG/CML）でのパケットキャプチャを伴う検証が推奨されます。
