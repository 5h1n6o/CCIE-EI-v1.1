---
layout: default
title: 4.2.c-IPv6-security
parent: 4.2-Network-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.2.c IPv6 Infrastructure Security Features

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 項目 **4.2.c (i) RA Guard, (ii) DHCP Guard, (iii) Binding table, (iv) Device tracking, (v) ND Inspection/Snooping, (vi) Source Guard** に対する、Cisco Catalyst 9000 シリーズおよび Cisco IOS XE 17.x の SISF（Switch Integrated Security Features）基準に基づく完全学習メモ。

---

## 📘 概要

IPv6 ファーストホップセキュリティ（First Hop Security: FHS）は、キャンパススイッチのアクセス層およびディストリビューション層において、IPv6 のプラグアンドプレイ機能（SLAAC、NDP、DHCPv6）を悪用した攻撃からネットワークインフラを保護するための包括的セキュリティフレームワークである。

* **RA Guard (Router Advertisement Guard):** 不正なルータ（Rogue IPv6 Router）からの Router Advertisement (RA) パケットをアクセスポートでブロックし、SLAAC（Stateless Address Autoconfiguration）の無効化や偽デフォルトゲートウェイの横取り（中間者攻撃: MitM）を防止する。
* **DHCP Guard (DHCPv6 Guard):** アクセスポート経由の不正 DHCPv6 サーバー（Rogue DHCPv6 Server）や不正リレーエージェントからの Reply/Advertise メッセージを遮断し、不正な IPv6 アドレスや DNS サーバーの割り当てを阻止する。
* **Binding Table (統合バインディングテーブル):** SISF（Switch Integrated Security Features）または IPDT（IP Device Tracking）により、MAC アドレス、IPv6 アドレス（Link-Local / GUA / ULA）、VLAN ID、接続ポート、バインディング状態を統合管理するデータベース。
* **Device Tracking (IP Device Tracking / SISF Device Tracking):** 接続された IPv6/IPv4 ノードの活性状態を追跡し、バインディングテーブルのエントリを動的に生成・バリデーション・維持・プローブ（NUD / ARP Probe）する基盤機能。
* **ND Inspection/Snooping (Neighbor Discovery Inspection & Snooping):** ICMPv6 Neighbor Solicitation (NS) / Neighbor Advertisement (NA) パケットをインスペクション（検証）し、バインディングテーブルと照合して DAD（Duplicate Address Detection）妨害や Neighbor Cache ポイズニング攻撃を防止する。
* **Source Guard (IPv6 Source Guard):** バインディングテーブルに基づき、アクセスポートに入力されるパケットの送信元 IPv6 アドレス（および MAC アドレス / プレフィックス）を検証し、未許可のアドレス直打ちや IP スプーフィングパケットをラインレートで即座にドロップする。

---

## 🔑 要点

| 機能 | 特徴 | 主な用途 | メリット | デメリット/制限事項 | 設計上の注意点 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **RA Guard** | アクセスポートでの RA (ICMPv6 Type 134) 受信をハードウェアブロック | Rogue IPv6 ルータ/偽 Gateway 遮断 | SLAAC によるトラフィック横取り・DOS防止 | レガシー非 SISF と SISF コマンド体系の差異 | ホストポートは `device-role host`、ルータポートは `device-role router` 指定 |
| **DHCP Guard** | 未許可ポートからの DHCPv6 Reply/Advertise ドロップ | Rogue DHCPv6 サーバー対策 | 不正な IPv6/DNS パラメータ配布の防止 | サーバートラフィックとクライアントトラフィックの識別設定が必要 | `device-role server` または `device-role client` の明確な設定 |
| **Binding Table** | MAC/IPv6/VLAN/Port 結合情報を集約管理 | 全 FHS 機能の検証データベース | 一元化された IP/MAC バインディング管理 | メモリ容量（最大エントリ数）制限 | `limit address-count` によるポートあたりアドレス数制限 |
| **Device Tracking** | SISF に基づく端末の動的トラッキングとプローブ | エントリ維持、802.1X/ISE 連携 | 端末離脱・IP変動のリアルタイム追跡 | アラートログ（IP Conflict）や過剰な NS プローブ発生 | `tracking enable` と `reachable-lifetime` の適切な調整 |
| **ND Inspection** | NDP (NS/NA) パケットの整合性検証とスプーフィング遮断 | L2 NDP ポイズニング/DAD 妨害防止 | ARP スプーフィングと同等の IPv6 L2 セキュリティ | NDP キャッシュのCPU処理負荷増大 | トランクおよびルータポートの Trust 指定（`trusted-port`） |
| **Source Guard** | 送信元 IPv6 アドレス/プレフィックスのラインレート検証 | IPv6 アドレススプーフィング防止 | 未承認の固定 IP 直打ち通信の遮断 | 事前に IPv6 Snooping / Device Tracking の有効化が必須 | `ipv6 source-guard attach-policy` のインターフェイス適用 |


---

## 🏗 動作原理

### 1. IPv6 First Hop Security (SISF) アーキテクチャ

Cisco IOS XE では、SISF（Switch Integrated Security Features）と呼ばれる統合バインディングフレームワークが導入されており、IPv4（DHCP Snooping/DAI）と IPv6（ND Inspection/Snooping/RA Guard/DHCP Guard）のバインディング管理が一元化されている。

```
                    ┌────────────────────────────────────────┐
                    │     SISF Binding Database              │
                    │  (MAC - IPv6/IPv4 - VLAN - Port - State) │
                    └───────────────────▲────────────────────┘
                                        │ (Populate & Validate)
     ┌──────────────────────────────────┴──────────────────────────────────┐
     │                                                                     │
┌────┴────────────┐  ┌─────────────────┐  ┌──────────────────┐  ┌─────────┴─────────┐
│ Device Tracking │  │  ND Inspection  │  │   IPv6 Snooping  │  │   DHCPv6 Guard  │
│ (IPDT / SISF)   │  │   (NS/NA Guard) │  │  (SLAAC / NDP)   │  │ (Server Reply)  │
└────▲────────────┘  └─────────────────┘  └──────────────────┘  └─────────────────┘
     │
┌────┴────────────┐  ┌─────────────────┐
│    RA Guard     │  │   Source Guard  │
│ (Type 134 Block)│  │ (Hardware TCAM) │
└─────────────────┘  └─────────────────┘
```

### 2. パケット受信時の FHS インスペクション・パイプライン

```
[ Inbound Packet (Access Port) ]
              │
              ├──► [ Packet Type Check ]
              │          │
              │          ├──► ICMPv6 Type 134 (RA) ──► RA Guard Check ──► (Host Port = DROP)
              │          │
              │          ├──► UDP Port 547 (DHCPv6 Server) ──► DHCP Guard Check ──► (Client Port = DROP)
              │          │
              │          ├──► ICMPv6 Type 135/136 (NS/NA) ──► ND Inspection ──► Verify against Binding Table
              │          │
              │          └──► IPv6 Data Packet ──► Source Guard (TCAM) ──► Match Src IP/MAC in Binding Table?
              │                                                                 │
              │                                                                 ├── YES ──► Forward
              │                                                                 └── NO  ──► DROP
```

---

## ⚙ 動作シーケンス

1. **バインディング情報の自動学習 (Glean / Snooping):**
   * クライアントが IPv6 ネットワークに参加し、SLAAC のために DAD（Duplicate Address Detection）用の ICMPv6 Neighbor Solicitation (NS: Type 135) を送出。
   * ND Inspection / IPv6 Snooping がパケットをインターセプトし、送信元 MAC アドレスおよび仮設定（Tentative）の IPv6 アドレスを抽出して `Device Tracking Database` に `TENTATIVE` 状態として登録。
   * DAD が成功（NA の競合応答なし）すると、バインディング状態が `REACHABLE` へ遷移。
   * DHCPv6 経由でアドレスを取得した場合は、DHCPv6 Reply パケット（IA_NA / IA_PD）をスヌーピングしてバインディングテーブルを生成。

2. **RA Guard による Rogue Router 遮断:**
   * アクセスポートに誤接続されたルータや悪意ある攻撃端末から RA（Type 134）が送信される。
   * 該当ポートに適用された RA Guard ポリシー（`device-role host`）が作用し、パケットを CPU に転送することなく ASIC レベルでドロップ。

3. **DHCPv6 Guard による Rogue DHCPv6 Server 遮断:**
   * クライアントポートから DHCPv6 ADVERTISE や REPLY パケット（Server メッセージ）が入力される。
   * DHCPv6 Guard ポリシー（`device-role client`）により、不正サーバーからのメッセージを拒否。

4. **IPv6 Source Guard によるパケットフィルタリング:**
   * アクセスポートから入力されるデータパケットの送信元 IPv6 アドレスを、SISF Binding Table から自動生成された Port TCAM エントリとバリデーション。
   * バインディングテーブルに存在しない偽装 IP アドレスや、固定 IP を手動設定した未承認パケットは即座にドロップ。

---

## 🎯 試験対策（CCIE EIラボ試験）

* **Blueprint の重要ポイント:**
  * SISF ベースの `device-tracking policy` の構成とトラブルシューティング。
  * RA Guard および DHCP Guard のポリシー作成およびインターフェイス/VLAN バインド。
  * ND Inspection と IPv6 Source Guard の依存関係（バインディングテーブル未確立時のトラフィック全ドロップトラブル）。
* **ラボ試験で設定させられそうな内容:**
  * 「VLAN 100 の全アクセスポートで Rogue RA および Rogue DHCPv6 Server をブロックし、ルータポートのみ許可せよ。」
  * 「端末が自由に固定 IP を打ち込んで通信するのを防止するため、IPv6 Source Guard を構成せよ。」
  * 「802.1X/ISE 環境において、端末の IPv6 アドレスを正しく追跡するため SISF Device Tracking を有効化せよ。」
* **よくある設定ミス・落とし穴:**
  * **Trust ポートのバインド漏れ:** アップリンクポートや本物ルータが接続されたポートに `device-role router` や `trusted-port` を設定し忘れ、正規の RA パケットまでドロップして全クライアントのアドレス自動生成（SLAAC）が停止する。
  * **旧コマンドと SISF 新コマンドの混在:** 従来の `ipv6 nd inspection policy` と最新の `device-tracking policy` / `ipv6 snooping policy` のコマンド構文の混乱。IOS XE 16.x/17.x では SISF 統一構文が推奨。
  * **Binding Table 未生成による Source Guard ドロップ:** Device Tracking / Snooping が有効化される前に IPv6 Source Guard をバインドしてしまい、有効なバインディングが存在しないためクライアントの通信が全ドロップする。

---

## 🛠 設定方法

### 1. SISF Device Tracking Policy のグローバル構成
```bash
! Device Tracking Policy の作成 (IPv4/IPv6 共通バインディング生成)
device-tracking policy SISF_DT_POLICY
 limit address-count 10
 no protocol udp
 tracking enable
 reachable-lifetime 300
```

### 2. IPv6 RA Guard の構成
```bash
! 1. Host 用 RA Guard ポリシーの定義
ipv6 nd inspection policy RAGUARD_HOST
 device-role host

! 2. Router 用 RA Guard ポリシーの定義 (アップリンク/ルータ側)
ipv6 nd inspection policy RAGUARD_ROUTER
 device-role router
 trusted-port

! 3. インターフェイスへの適用
interface GigabitEthernet1/0/1
 description Access Port (Host)
 ipv6 nd inspection attach-policy RAGUARD_HOST

interface GigabitEthernet1/0/24
 description Uplink Port (Router)
 ipv6 nd inspection attach-policy RAGUARD_ROUTER
```

### 3. IPv6 DHCPv6 Guard の構成
```bash
! 1. クライアント用 DHCP Guard ポリシーの定義
ipv6 dhcp guard policy DHCPGUARD_CLIENT
 device-role client

! 2. サーバー用 DHCP Guard ポリシーの定義
ipv6 dhcp guard policy DHCPGUARD_SERVER
 device-role server

! 3. インターフェイス適用
interface GigabitEthernet1/0/1
 ipv6 dhcp-guard attach-policy DHCPGUARD_CLIENT

interface GigabitEthernet1/0/24
 ipv6 dhcp-guard attach-policy DHCPGUARD_SERVER
```

### 4. IPv6 Snooping / ND Inspection & Source Guard の構成
```bash
! 1. IPv6 Snooping Policy の作成
ipv6 snooping policy SNOOPING_POLICY
 security-level inspect
 protocol ndp
 protocol dhcp

! 2. IPv6 Source Guard Policy の作成
ipv6 source-guard policy SOURCEGUARD_POLICY
 deny anonymous

! 3. インターフェイスへのバインド
interface GigabitEthernet1/0/1
 device-tracking attach-policy SISF_DT_POLICY
 ipv6 snooping attach-policy SNOOPING_POLICY
 ipv6 source-guard attach-policy SOURCEGUARD_POLICY
```


---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| Binding Table の確認 | `show device-tracking database` |
| IPv6 Neighbor Binding 確認 | `show ipv6 neighbor binding` |
| RA Guard ポリシー確認 | `show ipv6 nd inspection policy` |
| DHCP Guard ポリシー確認 | `show ipv6 dhcp guard policy` |
| IPv6 Source Guard 適用確認 | `show ipv6 source-guard policy` |
| SISF 統計情報の確認 | `show device-tracking counters interface <Int>` |
| FHS ドロップログ/Debug | `debug ipv6 snooping` / `debug device-tracking` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| SLAAC による IPv6 アドレスが取得できない | アップリンクポートで RA Guard が作用し本物 RA がドロップされている | `show ipv6 nd inspection policy` | アップリンクポートに `device-role router` または `trusted-port` を設定 |
| DHCPv6 から IP アドレスが取得できない | アクセスポートで DHCP Guard が有効で Advertise が拒否されている | `show ipv6 dhcp guard policy` | サーバーポート側に `device-role server` を指定 |
| クライアントの IPv6 データ通信が一切不可 | Binding Table に未登録のまま IPv6 Source Guard が有効化された | `show device-tracking database` | `tracking enable` および `ipv6 snooping` のバインド状態を確認 |
| DAD 実行時に誤って IP 重複エラーとなる | NS パケットのループまたは Device Tracking の不正応答 | `show device-tracking database` | `no protocol udp` または Device Tracking プローブ調整 |

---

## ⚠ 制限事項

* **ハードウェア TCAM 制限:** IPv6 Source Guard や RA Guard は HW TCAM を使用するため、Catalyst スイッチの SDM Template (Dual IPv4/IPv6) に依存。
* **VLAN / Port バインド制限:** 1 つのインターフェイスまたは VLAN に適用できる RA Guard / DHCP Guard ポリシーは 1 つのみ。
* **IPv6 Extension Header の影響:** 複雑な IPv6 拡張ヘッダー（Fragment や Routing Header）が含まれる場合、第一世代 ASIC では RA パケットのディープインスペクションに失敗してスルーまたはドロップする可能性がある。

---

## 🔄 他技術との関連

* **802.1X / Cisco ISE:** Cisco ISE による Dynamic ACL / SGT 付与時に、端末の IPv6 アドレスを特定するために SISF Device Tracking DB が必須となる。
* **SLAAC / DHCPv6:** FHS は SLAAC (ICMPv6 RA/NS/NA) および DHCPv6 コントロールプレーンを直接保護する。
* **First Hop Redundancy (HSRPv2 / VRRPv3):** FHRP 仮想 IP / MAC アドレスを RA Guard や ND Inspection が不当にドロップしないよう、FHRP 送信ポートの Trust 設計が必要。

---

## 🧩 比較表

| 比較項目 | IPv4 First Hop Security | IPv6 First Hop Security (SISF) |
| :--- | :--- | :--- |
| **ルータ偽装防止** | N/A (一般に ACL/CoPP) | **RA Guard** (ICMPv6 Type 134 制御) |
| **DHCP サーバー偽装防止** | **DHCP Snooping** (Option 82) | **DHCPv6 Guard** (Message Type 制御) |
| **L2 アドレス解決保護** | **Dynamic ARP Inspection (DAI)** | **ND Inspection / Snooping** (NS/NA) |
| **IP スプーフィング防止** | **IP Source Guard (IPSG)** | **IPv6 Source Guard** |
| **バインディング DB** | DHCP Snooping Binding Database | **SISF / Device Tracking Database** |

---

## 💡 ベストプラクティス

1. **Device Role の明確な分離:** ホスト接続ポートには `device-role host` / `client` を、アップリンクおよびルータ接続ポートには `device-role router` / `server` / `trusted-port` を例外なく適用する。
2. **SISF 構文への統合:** Cisco IOS XE 16.x/17.x では旧型の個別構文から `device-tracking policy` および `ipv6 snooping policy` への完全移行を徹底する。
3. **静的バインディングの併用:** 固定 IP 構成の重要サーバーポートには、`ipv6 neighbor binding vlan <VLAN> <IPv6> interface <INT> cisco <MAC>` による静的バインディングを設定する。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: IPv6 RA Guard による Rogue Router 遮断と本物ルータ許可構成
* **問題:** VLAN 100 のアクセスポート Gi1/0/1 において、不正なルータからの RA パケットを遮断し、アップリンク Gi1/0/24 からの正規 RA のみを許可せよ。
* **要件:** RA Guard ポリシーを作成し、適切な Device Role を適用すること。
* **設定例:**
```bash
ipv6 nd inspection policy RAGUARD_HOST
 device-role host

ipv6 nd inspection policy RAGUARD_ROUTER
 device-role router
 trusted-port

interface GigabitEthernet1/0/1
 ipv6 nd inspection attach-policy RAGUARD_HOST

interface GigabitEthernet1/0/24
 ipv6 nd inspection attach-policy RAGUARD_ROUTER
```
* **検証方法:**
  * Gi1/0/1 側から RA パケット（ICMPv6 Type 134）を送出し、ドロップされることを確認。
  * `show ipv6 nd inspection policy` を実行し、ターゲットとロールを確認。

---

### ラボ 2: DHCPv6 Guard による Rogue DHCPv6 Server 防御構成
* **問題:** アクセスポート Gi1/0/2 において、不正な DHCPv6 サーバーからの Reply メッセージをドロップさせよ。
* **要件:** DHCPv6 Guard ポリシーを作成し、端末ポートにバインドすること。
* **設定例:**
```bash
ipv6 dhcp guard policy DHCPGUARD_HOST
 device-role client

interface GigabitEthernet1/0/2
 ipv6 dhcp-guard attach-policy DHCPGUARD_HOST
```
* **検証方法:**
  * Gi1/0/2 から DHCPv6 Advertise/Reply メッセージを送出し、ブロックされることを確認。
  * `show ipv6 dhcp guard policy` を確認。

---

### ラボ 3: SISF Device Tracking Policy の構築とアクセスポート適用
* **問題:** 全アクセスポートにおいて、IPv6 ノードのアドレス追跡（Device Tracking）を有効化し、ポートあたり最大 5 アドレスに制限せよ。
* **要件:** `device-tracking policy` を使用すること。
* **設定例:**
```bash
device-tracking policy DT_ACCESS_POLICY
 limit address-count 5
 tracking enable
 reachable-lifetime 600

interface GigabitEthernet1/0/3
 device-tracking attach-policy DT_ACCESS_POLICY
```
* **検証方法:**
  * `show device-tracking database` を実行し、MAC/IPv6 バインディングが正常に生成されていることを確認。

---

### ラボ 4: IPv6 Snooping Policy と ND Inspection 統合構成
* **問題:** VLAN 200 において NDP (NS/NA) および DHCPv6 を監視し、不正な NDP ポイズニングを検知・保護せよ。
* **要件:** `ipv6 snooping policy` を作成し、`security-level inspect` を指定すること。
* **設定例:**
```bash
ipv6 snooping policy SNOOP_NDP_POLICY
 security-level inspect
 protocol ndp
 protocol dhcp

interface GigabitEthernet1/0/4
 ipv6 snooping attach-policy SNOOP_NDP_POLICY
```
* **検証方法:**
  * 端末から DAD パケットを送出し、バインディングが `REACHABLE` に遷移することを確認。

---

### ラボ 5: IPv6 Source Guard による送信元 IP 偽装ドロップ構成
* **問題:** ポート Gi1/0/5 直下の端末が未承認の固定 IPv6 アドレスを使用して通信するのを遮断せよ。
* **要件:** IPv6 Source Guard を有効化し、バインディングテーブルに存在する IP のみ通過許可せよ。
* **設定例:**
```bash
device-tracking policy DT_POLICY
 tracking enable

ipv6 snooping policy SNOOP_POLICY
 security-level inspect

ipv6 source-guard policy SG_POLICY
 deny anonymous

interface GigabitEthernet1/0/5
 device-tracking attach-policy DT_POLICY
 ipv6 snooping attach-policy SNOOP_POLICY
 ipv6 source-guard attach-policy SG_POLICY
```
* **検証方法:**
  * SLAAC / DHCPv6 で取得した正当な IP からの通信が通り、手動で偽装打打ちした IP からの通信がドロップされることを確認。

---

### ラボ 6: 静的 IPv6 Neighbor Binding エントリの定義と救済
* **問題:** 固定 IP を使用するサーバー（IPv6: 2001:db8:100::100 / MAC: 0050.56a1.b2c3）用に、静的 Neighbor Binding エントリを作成せよ。
* **要件:** スイッチ再起動後もバインディングテーブルに固定保持させること。
* **設定例:**
```bash
ipv6 neighbor binding vlan 100 2001:db8:100::100 interface GigabitEthernet1/0/10 0050.56a1.b2c3
```
* **検証方法:**
  * `show device-tracking database` を実行し、該当エントリの Codes に `S` (Static) が表示されることを確認。

---

### ラボ 7: RA Guard の Prefix / Access-list マッチング条件追加
* **問題:** 本物ルータが接続された Gi1/0/24 においても、許容された IPv6 プレフィックス（2001:db8:1000::/64）以外の RA をドロップさせる高度な RA Guard を構築せよ。
* **要件:** `ipv6 prefix-list` を RA Guard ポリシーにバインドすること。
* **設定例:**
```bash
ipv6 prefix-list ALLOW_RA_PREFIX permit 2001:db8:1000::/64

ipv6 nd inspection policy RAGUARD_ADVANCED
 device-role router
 match ipv6 prefix-list ALLOW_RA_PREFIX

interface GigabitEthernet1/0/24
 ipv6 nd inspection attach-policy RAGUARD_ADVANCED
```
* **検証方法:**
  * 2001:db8:2000::/64 を含む偽 RA を送信し、拒否されることを確認。

---

### ラボ 8: DHCPv6 Guard の Preference 閾値制御構成
* **問題:** 優先度（Preference）が 100 未満の不当な DHCPv6 サーバーからの応答を拒否するポリシーを作成せよ。
* **要件:** `min-preference` パラメータを使用すること。
* **設定例:**
```bash
ipv6 dhcp guard policy DHCPGUARD_PREF
 device-role client
 match server min-preference 100

interface GigabitEthernet1/0/6
 ipv6 dhcp-guard attach-policy DHCPGUARD_PREF
```
* **検証方法:**
  * Preference 50 の DHCPv6 Advertise パケットがドロップされることを確認。

---

### ラボ 9: 802.1X と SISF Device Tracking の統合構成
* **問題:** 802.1X 認証が適用されたアクセスポート Gi1/0/7 において、認証成功後に端末の IPv6 アドレスを正常に ISE へ追跡・通知できるよう Device Tracking を構成せよ。
* **要件:** UDP をトラッキング対象から除外すること。
* **設定例:**
```bash
device-tracking policy DT_ISE_POLICY
 limit address-count 10
 no protocol udp
 tracking enable

interface GigabitEthernet1/0/7
 switchport mode access
 authentication port-control auto
 device-tracking attach-policy DT_ISE_POLICY
```
* **検証方法:**
  * 端末認証後に `show device-tracking database interface Gi1/0/7` で IP が追跡されていることを確認。

---

### ラボ 10: FHS ドロップカウンタの検証とデバッグログ収集
* **問題:** Gi1/0/8 における FHS 違反（RA Guard / ND Inspection）のドロップカウンタを確認し、リアルタイムデバッグを構成せよ。
* **要件:** デバッグログを出力可能状態にすること。
* **設定例:**
```bash
! 検証コマンド
show device-tracking counters interface GigabitEthernet1/0/8
show ipv6 nd inspection policy

! デバッグ有効化
debug ipv6 snooping
debug device-tracking
```
* **検証方法:**
  * 違反パケット投入時にコンソールに FHS ドロップログが出力されることを確認。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** クライアント PC が接続されたスイッチ SW1 の Gi1/0/1 ポートにおいて、SLAAC による IPv6 アドレスおよびデフォルトゲートウェイが生成されなくなった。SW1 の設定を確認すると以下が定義されていた。
```bash
interface GigabitEthernet1/0/1
 ipv6 nd inspection attach-policy RAGUARD_POLICY
```
`RAGUARD_POLICY` の内容は `device-role host` となっていた。アップリンクポート Gi1/0/24 にはポリシーが適用されていない。
**設問:** クライアントが IPv6 アドレスを取得できなくなった技術的理由と、修正手順を述べよ。

* **解答:**
  * **理由:** アップリンクポート Gi1/0/24 側に `device-role router` または `trusted-port` の信頼設定がないため、スイッチ全体として正規の RA パケットが受容されずブロックされる、またはクライアントポート入力時の検証でドロップするため。
  * **修正コマンド:**
    ```bash
    ipv6 nd inspection policy RAGUARD_UPLINK
     device-role router
     trusted-port
    interface GigabitEthernet1/0/24
     ipv6 nd inspection attach-policy RAGUARD_UPLINK
    ```

---

### 問 2 (Design)
**シナリオ:** エンタープライズ網において、アクセス層に IPv6 Source Guard を導入予定である。端末の多くは SLAAC で自動生成された IPv6 アドレスを使用するが、一部のプリンタやサーバーは静的に打ち込まれた IPv6 アドレスを使用している。
**設問:** 静的 IP 端末の通信が IPv6 Source Guard により拒否されないようにするための最も適切な設計手法を説明せよ。

* **解答:**
  * 該当する静的 IP 端末の MAC アドレスと IPv6 アドレスのバインディングを、スイッチ上に手動で `ipv6 neighbor binding vlan <VLAN> <IPv6> interface <INT> <MAC>` コマンドを用いてスタティック（Static）エントリとして登録する。これにより、SISF Device Tracking Database に `Static` 属性として登録され、IPv6 Source Guard の TCAM フィルタで正常に通過が許可される。

---

### 問 3 (トラブルシューティング)
**シナリオ:** IOS XE スイッチにおいて `device-tracking policy` を有効化したところ、一部の IPv6 端末で DAD（Duplicate Address Detection）競合エラーが多発し、IPv6 通信が不安定になった。
**設問:** この現像が発生する技術的原因と、回避するための設定変更を述べよ。

* **解答:**
  * **原因:** Device Tracking が端末の活性確認のために送出する DAD プローブパケット（ARP Probe や ICMPv6 NS）の応答を、スイッチ自身または対向端末が過剰に受信用キャッシュに書き込むことで、端末側が自アドレスの重複（DAD 失敗）と誤誤認するため。
  * **対策:** `device-tracking policy` 内で `no protocol udp` を設定するか、`tracking target` やプローブの動作パラメーターを最適化する。

---

### 問 4 (実装)
**シナリオ:** VLAN 300 に接続されたアクセスポート Gi1/0/10 において、DHCPv6 サーバーメッセージを遮断しつつ、正規の DHCPv6 サーバー（Preference 200 以上）のみを許可するポリシーを構成せよ。
**設問:** 必要な設定コマンドを示せ。

* **解答:**
  ```bash
  ipv6 dhcp guard policy DHCP_SERVER_CHECK
   device-role client
   match server min-preference 200

  interface GigabitEthernet1/0/10
   ipv6 dhcp-guard attach-policy DHCP_SERVER_CHECK
  ```

---

### 問 5 (コンフィグ読解)
**シナリオ:** 以下の出力結果から、Gi1/0/1 に適用されている IPv6 FHS の状態を評価せよ。
```bash
# show device-tracking database interface GigabitEthernet1/0/1
Binding Table has 1 entries, 1 dynamic
Codes: L - Local, S - Static, ND - Neighbor Discovery, DH6 - IPv6 DHCP
Network Layer Address               Link Layer Address  vlan  prlvl  state     Interface
2001:DB8:1::50                      0011.2233.4455      100   0005   REACHABLE Gi1/0/1
```
**設問:** アドレス `2001:DB8:1::50` はどのような手段で学習され、現在どのような状態にあるか答えよ。

* **解答:**
  * **学習手段:** Codes の表記より、Neighbor Discovery (ND) パケット（ICMPv6 NS/NA）のスヌーピングによって動的（dynamic）に学習された。
  * **現在状態:** バインディング状態は `REACHABLE`（アクティブかつ正常に通信可能・到達可能状態）にある。


---

## 🔗 参考リソース

* Cisco Live: BRKIPV-3134 - IPv6 Security in the Local Area with First Hop Security
* Cisco Live: BRKCRS-2810 - Cisco SD-Access FHS and Security Architecture
* Cisco Configuration Guide: Cisco IOS XE Bengaluru 17.6.x - Configuring IPv6 First Hop Security Features
* Cisco Command Reference: IPv6 First Hop Security Commands for Catalyst 9000 Series
* Cisco Technical Notes: Troubleshooting IPv6 First Hop Security (FHS) on Catalyst Switches
* Cisco Technical Notes: Understanding Switch Integrated Security Features (SISF)
* Cisco Validated Design (CVD): Enterprise IPv6 Deployment Guide
* RFC 6105: IPv6 Router Advertisement Guard
* RFC 7113: Implementation Advice for IPv6 Router Advertisement Guard (RA-Guard)
* Youtube: Cisco IPv6 First Hop Security (RA Guard, DHCPv6 Guard, Source Guard) Lab Demo

---

## 📝 補足（Notes）

* **SISF 統一プラットフォームのメリット:**
  従来は IPv4（IPDT/DHCP Snooping）と IPv6（IPv6 FHS）で別々のバインディングデータベースとコマンド体系が存在していたが、IOS XE 16.x 以降の SISF 導入により、`device-tracking` / `snooping` コマンドで両プロトコルを一括管理可能となった。
* **スイッチングチップ（ASIC）でのパケット処理:**
  RA Guard および DHCP Guard は、パケットが CPU に転送される前の ASIC 段階（Ingress Port ASIC）で評価・ドロップされるため、DoS 攻撃によるスイッチ CPU 枯渇を完全に防止できる。
* **IPv6 Unique Local Address (ULA) / Link-Local の扱い:**
  SISF Binding Table には、1 つの物理ポート/MAC アドレスに対して、Link-Local (FE80::/10)、GUA (Global Unicast)、ULA (FC00::/7) の複数の IPv6 アドレスが同一エントリ内に紐付いて登録される点に留意すること。


## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKIPV-3134: IPv6 Security in the Local Area with First Hop Security**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPV-3134)
    *   FHS の各機能に関する最も包括的なプレゼンテーション。
*   [**BRKSEC-2001: Layer 2 Security Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001)
    *   IPv4/IPv6 両方のスイッチセキュリティの攻撃手法と対策。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Security Configuration Guide: IPv6 First-Hop Security**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg.html)
*   [**Configuring IPv6 Neighbor Discovery Inspection**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipv6/configuration/xe-16/ipv6-xe-16-book/ip6-nd-inspect.html)

### テクニカルドキュメント・設定例
*   [**IPv6 First-Hop Security Features Overview**](https://www.cisco.com/c/en/us/support/docs/ip/ipv6/116030-technote-fhs-00.html)
*   [**Understanding RA Guard (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ios-xml/ios/sec_data_urpf/configuration/xe-17/sec-data-urpf-xe-17-book.html)

---


## 📝 補足
- この学習メモは、CCIE EI 試験合格に必要な「論理的な設定の流れ」と「トラブルシューティングの視点」を網羅しています。ラボ試験では、特に **`show ipv6 neighbor binding`** の結果が他の FHS 機能の成否を握っていることを忘れないでください。

