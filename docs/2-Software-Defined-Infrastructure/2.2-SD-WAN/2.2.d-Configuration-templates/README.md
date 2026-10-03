---
layout: default
title: 2.2.d-Configuration-templates
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 4
---

# 2.2.d Configuration templates

## 📘 概要

Cisco SD-WAN (Catalyst SD-WAN) における **Configuration Templates（設定テンプレート）** は、vManage 管理下の多数の WAN Edge (cEdge / vEdge) デバイスに対して中央集中型で設定を生成・一括適用・標準化・保守管理するための根本的なメカニズムである。

SD-WAN アーキテクチャでは、デバイス上で直接 CLI (`configure terminal`) を手動投入する従来の分散管理手法から脱却し、vManage 上で定義したテンプレートをデバイスにアタッチ（Attach）して同期管理する。本技術は、大規模拠点展開のプロビジョニング自動化、人間による手動設定ミスの撲滅、セキュリティポリシおよびルーティング構成の一律強制において必須のコアコンポーネントである。

Blueprint 項目 2.2.d では、以下の 3 つのテンプレート構造とその適用ライフサイクルが定義されている。

1. **2.2.d (i) CLI Templates（CLI テンプレート）**
   * Cisco IOS-XE / VEdge CLI 構文をそのままテキストベースで記述し、動的変数を埋め込んだ自由度の高いテンプレート。
2. **2.2.d (ii) Feature Templates（機能テンプレート）**
   * System、Logging、BFD、OMP、VPN 0 Transport、VPN 512 Management、Service VPN などの特定機能をモジュール化・再利用可能にした構造化テンプレート。
3. **2.2.d (iii) Device Templates（デバイステンプレート）**
   * 特定のハードウェアモデル/仮想ルータ型番に Feature Template群（または CLI Template）をバインドし、個別の WAN Edge へ設定を押し込む最上位のマスターテンプレート。

---

## 🔑 要点

| 項目 | CLI Templates (2.2.d (i)) | Feature Templates (2.2.d (ii)) | Device Templates (2.2.d (iii)) |
| :--- | :--- | :--- | :--- |
| **定義** | 生の CLI 構文と変数タグを用いたテキスト形式のテンプレート | 特定のネットワーク機能（System, BGP等）を構造化した個別モジュール | 特定機種に対して機能テンプレート群または CLI を集約した最上位テンプレート |
| **パラメーター属性** | `{{variable_name}}` 表記による変数置換 | Global / Device Specific / Default / Not Configured の 4 モード | 機種指定 (C8300, C8000v等) ＋ パラメーター変数の集約テーブル (CSV) |
| **再利用性** | 低〜中（構文全体を管理するためモデル依存が生じやすい） | **極めて高い**（System や BGP 等を複数機種・サイトで共通利用可能） | 特定モデルカテゴリ専用（アタッチ時に対象デバイスを指定） |
| **柔軟性** | **無制限**（Feature Template 未対応コマンドや特有の CLI を全て記述可能） | GUI 画面でサポートされている項目に制限される（CLI Add-on で補完可能） | 構造化された設計ルールに準拠 |
| **検証・エラー検出** | 構文エラーは vManage プッシュ時の CLI パーサー実行まで検知困難 | GUI 入力時に型チェック・範囲検証が行われエラーが未然に防止される | 全機能テンプレートの整合性と必須変数の未入力を自動検証 |
| **推奨用途** | Brownfield 移行、既存複雑コンフィグの移植、非標準機能の実装 | **標準運用における Cisco 推奨構成**、大規模拠点の一元管理 | WAN Edge への設定配備・プロビジョニングの最終実行 |

---

## 🏗 動作原理

### 1. テンプレート階層アーキテクチャ

SD-WAN の設定管理は「モジュール構築 ➔ 集約 ➔ デバイスバインド ➔ 変数定義 ➔ プッシュ」の階層構造で動作する。

```
[ Feature Templates (2.2.d (ii)) ]
 ├── System Feature Template (System IP, Site ID, Org)
 ├── BFD Feature Template (Poll Interval, Multiplier)
 ├── OMP Feature Template (Graceful Restart, Advertisements)
 ├── VPN 0 Transport Feature Template (WAN Interfaces, Color)
 ├── VPN 512 Management Feature Template (OOB Port)
 └── Service VPN Feature Templates (VPN 10, BGP/OSPF)
         ↓ (集約・アセンブリ)
[ Device Template (2.2.d (iii)) ]  ← (特定モデル専用: 例 Catalyst 8300)
         ↓ (デバイスバインド ＋ CSV 変数注入)
[ Device Specific Variables ]  ← (System IP=10.1.1.1, Site ID=100, Hostname=Edge-01)
         ↓ (vManage CLI 生成 ＋ Dry-Run 検証)
[ Generated Running-Configuration ]
         ↓ (NETCONF / TLS 経由でプッシュ)
[ WAN Edge (cEdge / vEdge) ]
```

### 2. パラメーターの 4 つの属性モード (Feature Template 内)

Feature Template 内の全設定項目は、以下の 4 つの適用モードから選択する。

1. **Global（グローバル設定）:** 
   * このテンプレートを使用する全デバイスで完全に共通の固定値を指定（例: NTP サーバー IP、OMP Graceful Restart の有効化）。
2. **Device Specific（デバイス固有設定）:** 
   * デバイスごとに異なる値を動的変数 (`{{variable_name}}`) として定義（例: System IP、Site ID、Interface IP、Hostname）。デバイスアタッチ時に GUI または CSV ファイルで値を一括注入する。
3. **Default（デフォルト値）:** 
   * Cisco SD-WAN 標準の既定値をそのまま使用（例: BFD Hello インターバル 1000ms）。
4. **Not Configured / Disabled（未設定/無効）:** 
   * 生成される CLI コンフィグから該当項目を除外、または明示的に無効化。

---

## ⚙ 動作シーケンス

```
  vManage Admin                  vManage Engine                  WAN Edge (cEdge)
        │                              │                                │
        │ 1. Create Feature Templates  │                                │
        │ ───────────────────────────> │ (System, OMP, BFD, VPN 0/10)  │
        │                              │                                │
        │ 2. Create Device Template    │                                │
        │ ───────────────────────────> │ (Select Model & Bind Features) │
        │                              │                                │
        │ 3. Attach Devices            │                                │
        │ ───────────────────────────> │                                │
        │                              │                                │
        │ 4. Input Variables (CSV/GUI) │                                │
        │ ───────────────────────────> │ 5. Validate & Render CLI       │
        │                              │ ─────────────────────────────  │
        │                              │ (Generate full running-config) │
        │                              │                                │
        │ 6. Review Config (Dry-Run)   │                                │
        │ <─────────────────────────── │                                │
        │                              │                                │
        │ 7. Confirm Push              │                                │
        │ ───────────────────────────> │ 8. Lock Config & NETCONF Push  │
        │                              │ ─────────────────────────────> │
        │                              │                                │ 9. Apply Config
        │                              │                                │ ────────────────
        │                              │                                │ (Commit to Running)
        │                              │                                │
        │                              │ 10. NETCONF Success/Ack        │
        │                              │ <───────────────────────────── │
        │                              │                                │
        │                              │ 11. Status: Success (In Sync)  │
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で極めて重要なポイント

1. **CLI Template vs Feature Template の使い分け**
   * ラボ試験において、「Feature Template でサポートされている項目は必ず Feature Template を使用し、未対応コマンドのみ CLI Add-on テンプレートまたは CLI Template で補完せよ」という要件が出題される。
2. **Device-Specific Variables の定義漏れと型エラー**
   * CSV ファイルや vManage テーブルで変数を定義する際、`{{system_ip}}` や `{{vpn0_next_hop}}` などの型（IP アドレス、数値、文字列）が不一致だとアタッチ処理が失敗する。
3. **CLI Add-on Feature Template の活用**
   * Feature Template ベースの Device Template を維持しつつ、特殊な QoS ポリシーや PBR、NAT トラッキングなどの追加 CLI を挿入するには、**Cisco CLI Add-on Template** を指定されたセクション（System / Custom Option）に組み込む。
4. **テンプレートアタッチ時の通信切断と Rollback 対策**
   * 万が一、VPN 0 の Transport IP や Dynamic Routing、証明書認証に関わる設定を誤って変更したテンプレートを押し込むと、vManage 間のコントロールセッションが切断される。SD-WAN は設定適用後にコントロール接続が再確立しない場合、自動的に **Rollback（以前の正常設定への全自動復元）** を行う動作を理解しておくこと。

### ラボ試験で設定させられそうな内容

* 指定されたネーミングコンベンション（命名規則）に従った Feature Templates の作成（System, BFD, OMP, VPN 0 Interface, Service VPN 10 OSPF 等）。
* 特定モデル（例: Catalyst 8000v）向け Device Template の統合構築と変数マッピング。
* CSV ファイルを用いた複数 WAN Edge への一括アタッチ処理。
* CLI Add-on Template を使用した未対応 CLI（例: `ip nms-proxy` や特殊な Policy-Map）の組み込み。

---

## 🛠 設定方法

### 1. vManage GUI での Feature Template 定義手順

1. **vManage メニュー:** `Configuration` ➔ `Templates` ➔ `Feature Templates` タブを開く。
2. **`Add Template`** をクリックし、対象モデル（例: `Catalyst 8000v` または `All Device Models`）を選択。
3. 機能モジュール（例: `Cisco System`）を選択。
4. **パラメータの設定例:**
   * **Template Name:** `FT-C8K-System-Global`
   * **Description:** `Global System Template for C8K Edges`
   * **Console Baud Rate:** `Default` (9600)
   * **System IP:** `Device Specific` ➔ 変数名: `system_ip`
   * **Site ID:** `Device Specific` ➔ 変数名: `site_id`
   * **Organization Name:** `Global` ➔ 値: `CCIE-EI-Lab-Org`
   * **Hostname:** `Device Specific` ➔ 変数名: `hostname`

### 2. CLI Add-on Feature Template の記述例

Feature-based Device Template 内で未サポートの CLI（例: 特殊な EEM スクリプトや静的 ARP）を挿入する場合：

1. `Feature Templates` ➔ `Cisco CLI Template` (CLI Add-on) を作成。
2. コンフィグテキストエリアに生の CLI 構文と変数を記述：

```text
! Custom EEM Script for Lab Tracking
event manager applet TRACK_WAN_FAIL
 event track 10 state down
 action 1.0 syslog msg "WAN Interface Track 10 Down - Triggering Failover"
 action 2.0 cli command "enable"
 action 3.0 cli command "clear ip bgp *"
!
ip host {{internal_dns_name}} {{internal_dns_ip}}
```

### 3. Device Template への集約とアタッチ手順

1. `Configuration` ➔ `Templates` ➔ `Device Templates` タブを開く。
2. `Create Template` ➔ `From Feature Template` を選択。
3. **Device Model:** `Catalyst 8000v` を選択。
4. **Template Name:** `DT-C8K-Branch-Edge`
5. 各機能セクションに必要な Feature Template を割り当てる：
   * **Basic Information:** `FT-C8K-System-Global`, `FT-C8K-Logging`
   * **Transport & Management:** `FT-C8K-VPN0-Transport`, `FT-C8K-VPN0-Gi1-BizInternet`, `FT-C8K-VPN512-Mgmt`
   * **Service VPN:** `Add VPN` ➔ `VPN 10` ➔ `FT-C8K-VPN10-Service`, `FT-C8K-VPN10-OSPF`
   * **CLI Additional Template:** `FT-C8K-CLI-Addon-Custom`
6. `Save` ➔ アクションメニューから `Attach Devices` を選択。
7. 対象デバイスを選択し、`Update Values` で変数（System IP, Hostname 等）を直接入力するか CSV をアップロード。
8. `Config Preview`（Dry-Run）で生成された CLI を確認後、`Configure Devices` でプッシュ。

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| コントロール接続状態と管理状態確認 | `show sdwan control connections` |
| vManage からのテンプレート同期状態確認 | `show sdwan control local-properties` |
| 同期コンフィグの構成差分確認 | `show sdwan running-config` |
| 最後に適用されたテンプレート情報確認 | `show version` / `show sdwan system info` |
| NETCONF コミット失敗・エラーログ確認 | `show logging | include netconf` |
| テンプレートアタッチ時のデバッグ | `debug platform software feature cdm` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **Template Push 時に "Validation Error" で失敗する** | 必須変数の定義漏れ、または IP アドレス等の型構文エラー | vManage GUI 画面のエラーログ詳細 | CSV または GUI 上で未入力変数の項目（`{{variable}}`）を正確に入力する |
| **Push 処理後、デバイスが Old Config へ Rollback する** | テンプレート変更により vManage との VPN 0/512 コントロール接続が切断された | `show logging` / `show sdwan control connections-history` | Transport ポートの IP、次ホップ、Encapsulation、または Certificate 設定の誤りを訂正する |
| **CLI Add-on テンプレートの押込で "Syntax Error" が発生する** | IOS-XE の正確な CLI 構文（スペース、インデント、モード）から外れている | `show logging | include cdm` | cEdge の実機で CLI 構文を手動検証してから CLI Add-on へ移植する |
| **Device Template アタッチ後に手動 CLI が上書き消去される** | vManage 管理下（In Sync）のデバイスで直接 `conf t` 変更を行った | `show sdwan running-config` | WAN Edge 上での直接 CLI 変更は避け、必ず vManage テンプレート側を更新して押し込む |

---

## ⚠ 制限事項

1. **CLI テンプレートと Feature テンプレートの相互変換不可**
   * 一度 CLI Template ベースで作成した Device Template を、後から Feature Template ベースへ自動変換することはできない（逆も同様）。最初から再作成が必要。
2. **モデル間の互換性制限**
   * 特定の型番（例: ISR4331）用に作成した Device Template は、異なる型番（例: Catalyst 8300-1N2S-6T）へ直接アタッチできない。ただし、内部の Feature Template（System, OMP 等）は再利用可能。
3. **vManage 管理化における Out-of-Band 直接 CLI の破棄**
   * WAN Edge が vManage と正常に同期（In-Sync）している場合、デバイス上で手動投入した CLI は次回の vManage テンプレートプッシュ時にすべて上書き消去される。

---

## 🔄 他技術との関連

* **2.2.a Controller Architecture:** vManage が REST API および NETCONF 経由で WAN Edge へテンプレートを同期送信する。
* **2.2.b SD-WAN Underlay:** VPN 0 Transport インターフェイスや TLOC Extension、System IP / Site ID などのアンダーレイパラメータをテンプレート内で変数定義する。
* **2.2.c OMP:** OMP 機能テンプレートにて OMP アドバタイズ制限（`advertise ospf`, `advertise bgp`）や Graceful Restart タイマーを一括管理する。

---

## 🧩 比較表

### Feature-based Device Template vs CLI-based Device Template

| 比較項目 | Feature-based Device Template | CLI-based Device Template |
| :--- | :--- | :--- |
| **設定作成手法** | GUI フォームによる直感的な機能コンポーネント組み立て | 全設定を単一のテキストファイル（CLI 構文 ＋ 変数）で直接記述 |
| **入力チェック** | **強固**（GUI 入力段階で構文・範囲エラーが防止される） | **弱**（プッシュ時の CLI パーサー実行までエラー判定不可） |
| **拡張性** | CLI Add-on テンプレートを併用することで未対応 CLI もカバー可能 | 生の CLI 構文がそのまま使えるため柔軟性は無限大 |
| **メンテナンス性** | **極めて高い**（System や BFD などの変更を全拠点へ一括反映可能） | 低い（すべての設定を単一テキスト内で一から修正する必要がある） |
| **Cisco 推奨度** | **Cisco ベストプラクティス（標準適用）** | Brownfield 移行や特殊試験構成時の例外対応 |

---

## 💡 ベストプラクティス

1. **Feature Template のモジュール分割ルール**
   * 「System」や「NTP」、「Logging」などの基本機能テンプレートは全拠点で共有可能な共通テンプレート (`Global`) として作成し、インターフェイス設定など拠点固有の部分のみを個別テンプレート化する。
2. **命名規則（Naming Convention）の標準化**
   * テンプレート名には役割・機種・VPN 番号を明記する（例: `FT-C8K-VPN0-Gi1-BizInternet`, `FT-C8K-System-Global`）。
3. **Dry-Run（Config Preview）の徹底**
   * テンプレートをデバイスに押し込む前に、必ず `Config Preview` 画面を開き、生成された CLI コンフィグおよび差分（Diff）を目視確認する。
4. **CLI Add-on の最小化**
   * 設定の可視性とエラー防止のため、CLI Add-on Template の使用は Feature Template でサポートされていない機能のみに限定する。

---

## 📝 ラボ学習・設定サンプル例

### サンプル 1: System Feature Template の標準化構成

* **問題:** 拠点 cEdge ルータ群に適用する標準 System Feature Template を作成せよ。
* **要件:**
  1. Hostname, System IP, Site ID はデバイス固有の変数とすること。
  2. Organization Name は `CCIE-EI-Lab`（Global）とすること。
  3. Console Baud Rate は `115200`（Global）に設定すること。
* **設定例 (vManage 生成コンフィグ想定):**

```text
system
 host-name {{hostname}}
 system-ip {{system_ip}}
 site-id {{site_id}}
 organization-name "CCIE-EI-Lab"
 console-baud-rate 115200
!
```

* **検証方法:**
  `show sdwan running-config | section system` を実行し、上記変数がデバイス固有の値に展開されていることを確認。

---

### サンプル 2: VPN 0 Transport インターフェイス（Biz-Internet）テンプレート

* **問題:** WAN 接続用 Gi1 ポート（VPN 0）の Feature Template を構築せよ。
* **要件:**
  1. 物理ポートは `GigabitEthernet1` とすること。
  2. IP アドレスおよびサブネットマスクは変数 `{{vpn0_gi1_ip}}` とすること。
  3. Color は `biz-internet`（Global）に設定し、`encapsulation ipsec` を有効化すること。
  4. 許容サービスとして `default`, `dhcp`, `dns`, `icmp` を許可すること。
* **設定例 (vManage 生成コンフィグ想定):**

```text
sdwan
 interface GigabitEthernet1
  vpn 0
  ip address {{vpn0_gi1_ip}}
  tunnel-interface
   encapsulation ipsec
   color biz-internet
   allow-service default
   allow-service dhcp
   allow-service dns
   allow-service icmp
  exit
  no shutdown
 exit
!
```

* **検証方法:**
  `show sdwan control connections` を実行し、`biz-internet` カラーで vSmart とのコントロール接続が確立していることを確認。

---

### サンプル 3: Service VPN 10 ＋ OSPF テンプレート統合

* **問題:** 拠点 LAN 側（VPN 10）および OSPF 動的ルーティングの Feature Template をアタッチせよ。
* **要件:**
  1. VPN ID は `10`（Global）とすること。
  2. 内部インターフェイス `GigabitEthernet2` の IP アドレスは変数 `{{vpn10_gi2_ip}}` とすること。
  3. OSPF Area 0 を有効化し、`GigabitEthernet2` をエリア内に統合すること。
  4. OMP への OSPF 経路自動再配送を有効化すること。
* **設定例 (vManage 生成コンフィグ想定):**

```text
vrf definition 10
 rd 10:10
 address-family ipv4
  exit-address-family
!
router ospf 10 vrf 10
 router-id {{system_ip}}
 area 0
  interface GigabitEthernet2
   ip address {{vpn10_gi2_ip}}
  exit
 exit
!
sdwan
 omp
  address-family ipv4
   advertise ospf
  exit
 exit
!
```

* **検証方法:**
  `show ip route vrf 10` および `show sdwan omp routes` を実行し、LAN 側 OSPF 経路が OMP へ正常にアドバタイズされていることを確認。

---

### サンプル 4: CLI Add-on テンプレートを用いた EEM スクリプト挿入

* **問題:** Feature Template ベースの Device Template に対し、CLI Add-on を用いてカスタム EEM スクリプトを挿入せよ。
* **要件:**
  1. トラッキング 100（WAN 回線可達性）が Down した場合に syslog ログを出力する EEM スクリプトを組み込むこと。
* **設定例 (CLI Add-on テキスト):**

```text
event manager applet TRACK_WAN_MONITOR
 event track 100 state down
 action 1.0 syslog msg "CRITICAL: WAN Transport Track 100 Failed!"
!
```

* **検証方法:**
  `show running-config | section event manager` を実行し、Feature Template アタッチ後に EEM 設定が消去されず維持されていることを確認。

---

### サンプル 5: CSV ファイルによる複数 WAN Edge の一括変数マッピング

* **問題:** 3 台の Catalyst 8000v に対し、CSV ファイルを用いて Device Template の変数を一括注入せよ。
* **要件:**
  1. CSV フォーマットを抽出し、`csv_status`, `device_id`, `hostname`, `system_ip`, `site_id` を定義すること。
* **CSV ファイル形式例:**

```csv
csv_status,device_id,hostname,system_ip,site_id,vpn0_gi1_ip
ready,C8K-NODE-01,cEdge-Site101,10.1.1.1,101,192.168.10.2/24
ready,C8K-NODE-02,cEdge-Site102,10.1.1.2,102,192.168.20.2/24
ready,C8K-NODE-03,cEdge-Site103,10.1.1.3,103,192.168.30.2/24
```

* **検証方法:**
  vManage 上で CSV をアップロード後、各デバイスの `Config Preview` で変数正しく置換されていることを確認。

---

### サンプル 6: CLI-based Device Template の単体作成

* **問題:** 開発検証用の Catalyst 8000v 向けに、生 CLI による CLI-based Device Template を作成せよ。
* **要件:**
  1. 全設定を単一テキストエリアに記述し、`{{system_ip}}` 変数を含めること。
* **設定例 (CLI Template 内容):**

```text
system
 host-name {{hostname}}
 system-ip {{system_ip}}
 site-id {{site_id}}
 organization-name "CCIE-EI-Lab"
 vbond 192.168.1.100
!
interface GigabitEthernet1
 vpn 0
 ip address {{vpn0_ip}}
 tunnel-interface
  encapsulation ipsec
  color biz-internet
 exit
 no shutdown
!
```

* **検証方法:**
  `show sdwan control local-properties` を実行し、CLI テンプレートから正常にコントロールプロパティが読み込まれていることを確認。

---

### サンプル 7: BFD Parameter Tune Feature Template

* **問題:** WAN 回線（VPN 0）の BFD ポラロイドパラメータを調整する Feature Template を作成せよ。
* **要件:**
  1. BFD Hello Poll Interval を `500` ms（Global）に変更すること。
  2. BFD Multiplier を `3`（Global）に変更すること。
* **設定例 (vManage 生成コンフィグ想定):**

```text
sdwan
 bfd
  color biz-internet
   hello-interval 500
   multiplier 3
  exit
 exit
!
```

* **検証方法:**
  `show sdwan bfd sessions` を実行し、`Poll Interval` が 500ms にチューニングされていることを確認。

---

### サンプル 8: Service VRF 20 DHCP Server Feature Template

* **問題:** 拠点 Service VPN 20 内のクライアント向けに IOS-XE ローカル DHCP サーバーの Feature Template をアタッチせよ。
* **要件:**
  1. アドレスプール `POOL_VPN20`（ネットワーク: `172.16.20.0/24`）を作成すること。
  2. デフォルトルータとして `172.16.20.1` を配布すること。
* **設定例 (vManage 生成コンフィグ想定):**

```text
ip dhcp excluded-address 172.16.20.1 172.16.20.10
!
ip dhcp pool POOL_VPN20
 network 172.16.20.0 255.255.255.0
 default-router 172.16.20.1
 dns-server 8.8.8.8
!
```

* **検証方法:**
  `show ip dhcp binding` を実行し、内部クライアントへ IP が正常に動的払い出しされていることを確認。

---

### サンプル 9: Dual-WAN (Biz-Internet + MPLS) Transport Feature Template

* **問題:** 1 台の cEdge に 2 つの WAN ポート（Gi1: biz-internet, Gi2: mpls）を設定する Feature Template 群を集約せよ。
* **要件:**
  1. Gi1 (biz-internet) および Gi2 (mpls) の 2 つの Interface Feature Template を作成し、VPN 0 Transport テンプレート配下に組み込むこと。
* **設定例 (vManage 生成コンフィグ想定):**

```text
sdwan
 interface GigabitEthernet1
  vpn 0
  ip address {{gi1_ip}}
  tunnel-interface
   encapsulation ipsec
   color biz-internet
  exit
 exit
 interface GigabitEthernet2
  vpn 0
  ip address {{gi2_ip}}
  tunnel-interface
   encapsulation ipsec
   color mpls
  exit
 exit
!
```

* **検証方法:**
  `show sdwan control connections` を実行し、2 つのカラー双方で vSmart との双方向 DTLS コントロール接続が確立していることを確認。

---

### サンプル 10: テンプレート失敗時の Rollback トラブルシューティング実演

* **問題:** 誤った IP アドレスが定義されたテンプレートをプッシュし、デバイスが手前設定に自動 Rollback する現象を検証せよ。
* **要件:**
  1. WAN Edge のコントロール接続が切断された際のログを解析し、自動ロールバック動作を確認すること。
* **エラーログおよび検証手順:**

```text
*Oct  2 23:30:12.411: %SDWAN-CRITICAL: Control connection to vSmart down
*Oct  2 23:31:12.500: %SDWAN-NOTICE: System failed to establish control connection within timeout window
*Oct  2 23:31:13.102: %SDWAN-INFO: Rolling back to previous known-good configuration commit ID: 102
```

* **検証方法:**
  `show sdwan control local-properties` を実行し、管理状態が `In Sync` へ自動的に復旧していることを確認。

---

## ❓ 想定試験問題

### 質問 1 (コンフィグ読解・トラブルシューティング)
以下のエラーが vManage の `Template Push Task Status` 画面に表示され、デバイスへの設定適用がキャンセルされた。原因と対処法を述べよ。

```text
Error: Variable 'system_ip' has invalid value '10.1.1.256' for parameter System IP.
Error: Mandatory variable 'vpn0_next_hop' is not defined for device C8K-Edge-02.
```

* **解答・解説:**
  * **原因:** 
    1. 変数 `system_ip` に不正な IP アドレス形式（256 は第 4 オクテットの上限超え）が入力されている。
    2. 変数 `vpn0_next_hop` が定義されているにもかかわらず、該当デバイスの変数テーブル（または CSV）で値が未入力（空欄）となっている。
  * **対処法:**
    vManage の `Update Device Values` 画面を開き、`system_ip` を正当な IPv4 アドレス（例: `10.1.1.25`）に訂正し、`vpn0_next_hop` の入力欄に正しいネクストホップ IP を指定して再プッシュする。

---

### 質問 2 (デザイン・基本仕様)
ある企業ネットワークにおいて、Catalyst 8300 と Catalyst 8000v の 2 種類のモデルを展開予定である。単一の Device Template を用いて両方のモデルへ同時にアタッチすることは可能か説明せよ。

* **解答・解説:**
  * **解答:** 不可能。
  * **解説:** Device Template は特定のハードウェア/仮想デバイスモデル（Device Model）に密結合しているため、Catalyst 8300 用の Device Template を Catalyst 8000v へそのままアタッチすることはできない。ただし、内部で定義した個々の Feature Template（System, OMP, BFD, NTP 等）は両モデル間で完全に再利用・共有可能であるため、モデルごとに Device Template を作成し、共有 Feature Template を組み込んでアタッチする必要がある。

---

### 質問 3 (実装・CLI Add-on)
Feature Template ベースの Device Template を使用している環境で、vManage GUI 上でサポートされていない特殊な QoS Class-Map を WAN Edge へ追加したい。最善の構成手順を述べよ。

* **解答・解説:**
  * **解答:** **CLI Add-on Feature Template** を作成して Device Template へ追加する。
  * **手順:**
    1. `Feature Templates` 画面から `Cisco CLI Template` (CLI Add-on) を作成する。
    2. 未対応の Class-Map および Policy-Map 構文を記述する。
    3. 対象の Feature-based Device Template を編集し、`Additional Templates` ➔ `CLI Add-on Template` セクションに作成した CLI Add-on テンプレートを割り当てて再保存・プッシュする。

---

### 質問 4 (トラブルシューティング・自動ロールバック)
VPN 0 の Transport インターフェイス IP アドレスを変更する Feature Template を修正して WAN Edge へアタッチしたところ、プッシュ処理開始から約 1 分後に設定変更前の状態に自動的に戻ってしまった。なぜこの現象が発生したか、SD-WAN の安全機構を踏まえて説明せよ。

* **解答・解説:**
  * **原因:** 
    新しく変更した IP アドレスまたはネクストホップの誤りにより、WAN Edge と vSmart / vManage 間の VPN 0 コントロール接続（DTLS/TLS）が切断され、指定時間内に再確立しなかったため。
  * **安全機構（Rollback）:**
    SD-WAN は設定更新後、vManage へのコントロール接続が正常に維持・復元されるかを確認するタイマーを駆動する。接続が切断された場合、デバイスが「孤立（Orphan）」したと判断し、自動的に直前の正常なコンフィグ（Pre-commit state）へ全自動ロールバックして通信を全自動救済する。

---

### 質問 5 (コンフィグ比較)
Feature-based Device Template と CLI-based Device Template の主な決定的な相違点を 2 つ挙げよ。

* **解答・解説:**
  1. **検証・堅牢性:** Feature-based は GUI フォーム入力時にパラメータの型や範囲が自動チェックされ、エラーが未然に防がれるのに対し、CLI-based は生のテキストを記述するためプッシュ実行時の CLI パーサー判定までエラーが検知できない。
  2. **モジュール再利用性:** Feature-based は System や BFD などの個々の機能を独立モジュールとして複数機種・複数テンプレート間で自由に再利用・一括更新できるが、CLI-based は全設定が単一のテキストに集約されるため再利用性が低い。

---

## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Configuration Guides](https://www.cisco.com/c/en/us/support/routers/sd-wan/products-installation-and-configuration-guides-list.html)
* [Cisco SD-WAN Command Reference](https://www.cisco.com/c/en/us/support/routers/sd-wan/products-command-reference-list.html)
* [Cisco Live: BRKCRS-2110 - Cisco SD-WAN Deployment & Templates Deep Dive](https://www.ciscolive.com/)
* [Cisco Validated Design (CVD): SD-WAN Design Guide](https://www.cisco.com/c/en/us/solutions/design-zone/wan-design-guides.html)
* [Youtube: Cisco SD-WAN Feature and Device Templates Walkthrough](https://www.youtube.com/)

---

## 📝 **補足（Notes）**

* **GitHub Pages 表示:** 見出し上下の空行確保および表組み内の `<code>` タグ使用により、レスポンシブ環境や Jekyll/GitHub Pages で正しく表示可能。
* **実務・CCIEEI ラボ共通の注意点:** ラボ試験では、不要な CLI Add-on の使用を避け、可能な限り構造化された Feature Template のみでコンフィグを完結させることが推奨される。


## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2296: Designing On-Prem SD-WAN Controllers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2296) - テンプレート設計のベストプラクティス.
*   [**BRKENT-2081: Troubleshooting SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - テンプレート push エラーの診断手法.
*   [**DGTL-BRKRST-2559: 3 Steps to Design Cisco SD-WAN On-Prem**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2559) - 初期構築時のテンプレート運用.

### Configuration ガイド
*   [**Cisco vManage Template Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/vedge-20-x/system-interface-book/m-system-overview.html)
*   [**SD-WAN Feature Template Parameters Overview**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/xe-17-9/systems-interfaces-guide-xe-17-9.html)。

### テクニカルドキュメント・設定例
*   [**SD-WAN Onboarding WAN Edge Devices (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html).
*   [**vManage API for Template Automation**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/vmanage-rest-api/vmanage-rest-api-overview.html).

---

## 📝 補足
- この学習メモは、SD-WAN テンプレートが「単なる自動化」ではなく、**「ネットワークの抽象化とモデル化」**であることを強調しています。CCIE EI 実技試験では、複雑な依存関係（Feature は Device に属し、Device は実機に属す）を迅速に構築し、不具合時に `show sdwan running-config` でコントローラから何が送られてきているかを即断できる能力が合格の決め手となります。

