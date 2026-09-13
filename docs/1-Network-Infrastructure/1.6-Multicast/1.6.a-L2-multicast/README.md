---
layout: default
title: 1.6.a-L2-multicast
parent: 1.6-Multicast
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.6.a Layer 2 multicast

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における Layer 2 マルチキャストのコア技術である **1.6.a Layer 2 multicast (IGMPv2/v3, IGMP snooping, PIM snooping, IGMP querier, IGMP filter, MLD)** について、Cisco IOS-XE 17.x（Catalyst 9000 シリーズ、Catalyst 8000v 等）の実装基準に 100% 準拠した詳細な学習メモを掲載します [22, 1.6.a]。

---

## 📘 概要

Layer 2 マルチキャスト技術は、イーサネットスイッチ環境においてマルチキャストトラフィック（IPv4/IPv6）を必要とするポートのみに選択的に転送し、VLAN 全体への不要なフラッディング（Flooding）を防ぐための核心技術群です [22, 1.6.a]。

### 1. IGMPv2 / IGMPv3 (Internet Group Management Protocol)
* **概要:** IPv4 ホストとローカルマルチキャストルータ間において、マルチキャストグループへの参加（Join）および離脱（Leave）をシグナリングする L3/L2 境界プロトコルです [22, 1.6.a (i)]。
* **利用目的:** IGMPv2 はグループ単位 (`*,G`)、IGMPv3 は送信元とグループのペア (`S,G`) を指定可能な **SSM (Source Specific Multicast)** をサポートします [22, 1.6.a (i), 1.6.c (iv)]。

### 2. IGMP Snooping / PIM Snooping
* **概要:** L2 スイッチが L3 制御パケット（IGMP レポートや PIM パケット）を覗き見（Snooping）し、動的に MAC/IP マルチキャスト転送テーブルを作成する機能です [22, 1.6.a (ii)]。
* **利用目的:** IGMP Snooping はホストからの Join/Leave を追跡し、PIM Snooping はルータ間の PIM Join/Prune/Hello メッセージをスヌーピングして、ネイバールータが存在するポートのみにマルチキャストトラフィックを絞り込みます [22, 1.6.a (ii)]。

### 3. IGMP Querier
* **概要:** L3 マルチキャストルータ（PIM 有効化ルータ）が存在しない純粋な L2 VLAN 環境において、L2 スイッチが代わりに IGMP クエリーを定期送出し、ホストの参加状態を維持する機能です [22, 1.6.a (iii)]。

### 4. IGMP Filter
* **概要:** アクセスポートや VLAN ごとに参加可能なマルチキャストグループ範囲（IPv4 マルチキャスト IP アドレス）を ACL / Profile により制限するセキュリティ制御機能です [22, 1.6.a (iv)]。

### 5. MLD (Multicast Listener Discovery)
* **概要:** IPv6 環境における IGMP に相当するプロトコルであり、ICMPv6 メッセージ（Type 130/131/143）を使用してホストとルータ間で IPv6 マルチキャストグループ参加・離脱を制御します [22, 1.6.a (v)]。MLDv1（IGMPv2 相当）と MLDv2（IGMPv3 相当）が存在します [22, 1.6.a (v)]。

---

## 🔑 要点

| 技術項目 | 特徴 | 主な用途 | メリット | デメリット / 注意点 |
| :--- | :--- | :--- | :--- | :--- |
| **IGMPv2** | グループ単位 (`*,G`) 参加/離脱。Explicit Leave (Group-Specific Query) 対応 [22, 1.6.a (i)]。 | 汎用 IPv4 マルチキャスト配信 | 構成が極めてシンプルで互換性が高い | 送信元アドレス指定（SSM）不可。複数レシーバ環境で応答競合（Suppression）発生 |
| **IGMPv3** | 送信元・グループ単位 (`S,G`) 指定 (SSM)。Include/Exclude モード対応 [22, 1.6.a (i), 1.6.c (iv)]。 | IPTV, 防犯カメラ, 高高度動画配信 (SSM) | 任意送信元からの野良マルチキャストの排除、RP 不要のシンプルルーティング | ホストOSおよびスイッチハードウェアの IGMPv3 完全対応が必須 |
| **IGMP Snooping** | L2 スイッチによる IGMP パケット（224.0.0.1/2 等）の解析と L2 ポートマップ構築 [22, 1.6.a (ii)]。 | LAN スイッチ全般の帯域保護 | 不要なマルチキャストの全ポートフラッディング防止 | スイッチ CPU 負荷のわずかな増加。Querier や mrouter ポートの正しい検出が必要 |
| **PIM Snooping** | PIM パケット (224.0.0.13) をスヌーピングし、L2 網でのルータ間マルチキャスト制限 [22, 1.6.a (ii)]。 | スイッチを挟んだ複数 PIM ルータの接続環境 | PIMルータが存在しない不要なスイッチポートへのマルチキャスト流入防止 | IGMP Snooping との併用が必須。設定が一部 Catalyst で限定的 |
| **IGMP Querier** | L2 スイッチが IGMP General Query を疑似送出 (デフォルト IP 0.0.0.0 や SVI アドレス) [22, 1.6.a (iii)]。 | L3 ルータのない孤立した L2 VLAN 網 | L3 ルータ不在でも IGMP Snooping テーブルの保持・エージング防止が可能 | IP アドレス重複や複数 Querier 存在時の選定ルール（最小 IP 優先）への配慮 |
| **IGMP Filter** | IGMP Profile（ACL）によるポート単位参加許可・拒否制御 [22, 1.6.a (iv)]。 | キャンパス網やデータセンターの不正マルチキャスト受信防止 | 許可されていないグループへの不正 Join の即時ドロップ | ルール過剰設定による正常通信阻害 |
| **MLD (v1/v2)** | IPv6 版 IGMP。ICMPv6（タイプ 130/131/143）で動作 [22, 1.6.a (v)]。 | IPv6 マルチキャスト配信、Solicited-Node マルチキャスト制御 | IPv6 ネイバー発見（NDP）の基礎基盤 | MLD Snooping 未有効化時、IPv6 マルチキャストが L2 全体へ全フラッディング |

---

## 🏗 動作原理

### 1. IGMP Snooping と L2 マルチキャスト転送フロー

```text
[ Multicast Source (10.1.1.100) ]
              │ (Multicast Stream: 239.1.1.1)
              ▼
    [ L3 Router (PIM-SM) ] ── (IGMP Querier: 10.1.1.1)
              │
         (Trunk Port)
              │
     [ L2 Catalyst Switch ] ◄── IGMP Snooping 有効
      ├── Port 1 ──► [ Receiver A ] (Joined 239.1.1.1) ── (IGMP Report 送信)
      ├── Port 2 ──► [ Receiver B ] (未参加)
      └── Port 3 ──► [ Receiver C ] (Joined 239.1.1.1) ── (IGMP Report 送信)
```

1. **mrouter (Multicast Router) ポートの検出:**
   * スイッチは PIM Hello パケット (224.0.0.13) や IGMP General Query (224.0.0.1) を受信したポートを `mrouter port`（上流ルータポート）として識別します。
2. **IGMP Report のスヌーピング:**
   * Receiver A が `239.1.1.1` への IGMP Report を送信すると、スイッチはこれをスヌーピングし、L2 MAC テーブル（例: MAC `0100.5e01.0101` または IP `239.1.1.1`）に Port 1 を登録します。
3. **選択的転送:**
   * 上流ルータから届いた `239.1.1.1` のストリームは、Port 1 と Port 3 のみに転送され、Receiver B が接続された Port 2 には一切送信されません。

---

## ⚙ 動作シーケンス

### Sequence 1: IGMPv2 Leave と Group-Specific Query 処理
1. **Leave Group 送信:**  
   Receiver A が脱退メッセージ（IGMP Leave Group: destination `224.0.0.2`）を送信。
2. **IGMP Snooping のインターセプト:**  
   スイッチは Leave メッセージをキャッチし、該当ポートのみに対して **IGMP Group-Specific Query** (destination `239.1.1.1`) を即座に生成して送出。
3. **Last Member Query Timer (LMQT):**  
   指定時間内（デフォルト 1 秒）に他のホストから Report が返ってこない場合、スイッチはそのポートを MAC マルチキャストテーブルから削除（Fast-Leave / Immediate-Leave が有効な場合は即時削除）。

### Sequence 2: MLD (IPv6) の動作シーケンス
1. **MLD Listener Report (Type 131/143):**  
   IPv6 ホストは ICMPv6 タイプ 143 (MLDv2 Report) を宛先 `ff02::16` へ送出。
2. **MLD Snooping 登録:**  
   スイッチは ICMPv6 ヘッダー内の Multicast Address（例: `ff0e::1:1`）を解析し、IPv6 L2 マルチキャスト転送テーブルを作成。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint における最重要ポイント
* **L3 ルータが存在しない孤立 VLAN での IGMP Querier 設定:**  
  ラボ課題で「L3 ルータを設定せず、L2 スイッチのみの VLAN 内で IGMP Snooping によるマルチキャスト制御を実現せよ」と指示された場合、**`ip igmp snooping querier`** の設定が絶対必須となります [22, 1.6.a (iii)]。これがないと Querier 不在により IGMP Report がタイムアウトし、数分後にマルチキャスト通信が途絶します。
* **IGMPv3 / MLDv2 と Report Suppression の罠:**  
  IGMPv2 では帯域節約のためスイッチが他のホストからの Report を隠蔽する Report Suppression が機能しますが、**IGMPv3 (SSM) では各ホストの (S,G) 情報を追跡するため Report Suppression が無効化される** か、Explicit Tracking が必要になります。
* **PIM Snooping の必要性:**  
  スイッチに複数の PIM ルータが接続されている環境で、特定のルータが PIM Join を送っていないにもかかわらずマルチキャストがフラッディングされる障害を防ぐため、`ip pim snooping` を構成する課題が出題されます [22, 1.6.a (ii)]。

### 2. よくある設定ミス・制限事項
* **`ip pim sparse-mode` 未設定による mrouter ポート未検出:**  
  SVI インターフェイスで PIM が有効化されていないと、スイッチが L3 ルータポートを自動検出しません。手動で `ip igmp snooping vlan <ID> mrouter interface <INT>` を入れるか PIM を有効化する必要があります。
* **IGMP Filter (Profile) の適用階層ミス:**  
  IGMP Profile は `ip igmp profile <NUM>` で作成した後、物理ポート配下で `ip igmp filter <NUM>` として適用します。VLAN モードで直接入れようとしてエラーになるパターンに注意してください [22, 1.6.a (iv)]。

### 3. show コマンドによる状態判断
```bash
# IGMP Snooping 全体および VLAN 単位の動作確認
Switch# show ip igmp snooping
Switch# show ip igmp snooping vlan 10

# 検出された mrouter (ルータ接続) ポートの確認
Switch# show ip igmp snooping mrouter

# 動的に学習された L2 マルチキャストグループと出力ポートの確認
Switch# show ip igmp snooping groups

# IGMP Querier ステートの確認
Switch# show ip igmp snooping querier

# IPv6 MLD Snooping の確認
Switch# show ipv6 mld snooping vlan 10
```

---

## 🛠 設定方法

### 1. IGMP Snooping & Querier & Explicit Tracking 完全設定例 (IOS-XE)

```bash
# グローバルでの IGMP Snooping 有効化 (デフォルト有効)
ip igmp snooping

# 特定 VLAN 10 での Snooping および Querier 有効化
ip igmp snooping vlan 10
ip igmp snooping vlan 10 querier
ip igmp snooping vlan 10 querier address 10.1.1.254
ip igmp snooping vlan 10 querier version 3

# Fast-Leave (Immediate Leave) 設定 (1ポート1レシーバ環境用)
ip igmp snooping vlan 10 immediate-leave

# ポート単位での IGMP Filter (グループ参加制限)
ip igmp profile 100
 permit
  range 239.1.1.0 255.255.255.0
 exit
!
interface GigabitEthernet1/0/1
 switchport mode access
 switchport access vlan 10
 ip igmp filter 100
 ip igmp max-groups 5
```

### 2. PIM Snooping 設定例

```bash
# グローバルおよび VLAN 単位での PIM Snooping 有効化
ip pim snooping
ip pim snooping vlan 10
```

### 3. IPv6 MLD Snooping 設定例

```bash
# IPv6 MLD Snooping 有効化
ipv6 mld snooping
ipv6 mld snooping vlan 20
ipv6 mld snooping vlan 20 querier
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **IGMP Snooping 全体ステート確認** | <code>show ip igmp snooping</code> |
| **VLAN 単位の Snooping 設定確認** | <code>show ip igmp snooping vlan <VLAN_ID></code> |
| **mrouter (ルータ接続) ポート一覧確認** | <code>show ip igmp snooping mrouter</code> |
| **L2 マルチキャストグループ登録テーブル確認** | <code>show ip igmp snooping groups</code> |
| **IGMP Querier の選定状態・送信元 IP 確認** | <code>show ip igmp snooping querier vlan <VLAN_ID></code> |
| **PIM Snooping 動作ステート確認** | <code>show ip pim snooping</code> |
| **IPv6 MLD Snooping グループテーブル確認** | <code>show ipv6 mld snooping groups</code> |
| **IGMP Snooping デバッグ** | <code>debug ip igmp snooping [ip|detail|packets]</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **L3 ルータがない VLAN で数分後にマルチキャスト受信用通信が途切れる。** | IGMP Querier が存在しないため、ホストの Join 状態がタイムアウトエージングされている。 | `show ip igmp snooping querier` | スイッチ上で `ip igmp snooping vlan <ID> querier` を有効化し、IP アドレスを指定する [22, 1.6.a (iii)]。 |
| **特定のポートで IGMP Report が拒否されマルチキャストを受信できない。** | IGMP Filter (Profile) または `max-groups` 制限に引っかかっている。 | `show ip igmp profile`<br>`show running-config interface <INT>` | `ip igmp filter` の permit 範囲を見直すか、`ip igmp max-groups` の上限を引き上げる [22, 1.6.a (iv)]。 |
| **スイッチを挟んだ PIM ルータ間でマルチキャストが全ポートにフラッディングされる。** | PIM Snooping が未設定であり、PIM ジョインメッセージが L2 制御されていない。 | `show ip pim snooping` | グローバルおよび VLAN 単位で `ip pim snooping` を有効化する [22, 1.6.a (ii)]。 |
| **IPv6 マルチキャスト（Solicited-Node 等）が VLAN 全体にフラッディングする。** | MLD Snooping が有効化されていない、または MLD Querier が存在しない。 | `show ipv6 mld snooping` | `ipv6 mld snooping` を有効化し、必要に応じて MLD Querier を配置する [22, 1.6.a (v)]。 |

---

## ⚠ 制限事項

1. **IGMPv3 スヌーピングとハードウェアテーブル容量:**
   * Catalyst 9000 シリーズでは、IGMPv3 `(S,G)` スヌーピング用に TCAM リソースを消費します。多数のユニークな送信元が存在する場合、TCAM 溢れにより CPU ソフトウェア処理にフォールバックするリスクがあります。
2. **Report Suppression と IGMPv3:**
   * IGMPv3 ではホストごとに送出する送信元フィルタ情報（Include/Exclude）が異なるため、スイッチによる Report Suppression（Report 応答の隠蔽）は自動的に機能しません。

---

## 🔄 他技術との関連

* **PIM Sparse Mode (PIM-SM / SSM):**
  L3 での `ip pim sparse-mode` 設定が L2 IGMP Snooping の mrouter ポート検出のトリガーとなります [22, 1.6.c]。
* **VXLAN EVPN / SD-Access (SDA):**
  アンダーレイおよびオーバーレイ L2 Flooding 抑制において、IGMP Snooping および MLD Snooping は Fabric Edge スイッチ上で必須の基本機能として自動動作します [21, 2.2]。
* **IPv6 Neighbor Discovery (NDP):**
  IPv6 の アドレス解決（Solicited-Node Multicast: `ff02::1:ffXX:XXXX`）は MLD Snooping によって L2 転送制御されます [22, 1.6.a (v)]。

---

## 🧩 比較表

### 1. IGMPv2 vs IGMPv3

| 比較項目 | IGMPv2 (RFC 2236) | IGMPv3 (RFC 3376) |
| :--- | :--- | :--- |
| **指定可能指定要素** | グループアドレスのみ (`*,G`) | 送信元 ＋ グループ (`S,G`) [22, 1.6.a (i), 1.6.c (iv)] |
| **SSM (Source Specific) サポート** | 不可 (RP が必要) | 完全対応 (`232.0.0.0/8`) [22, 1.6.c (iv)] |
| **離脱（Leave）動作** | Leave Group メッセージ ➔ Group-Specific Query | Include / Exclude アナウンスメント |
| **Report Suppression** | あり (帯域節約のため代表ホストのみ応答) | なし (個別の S,G 状態を追跡) |

### 2. IGMP Snooping vs PIM Snooping

| 比較項目 | IGMP Snooping | PIM Snooping |
| :--- | :--- | :--- |
| **解析対象プロトコル** | IGMP (IPv4) / MLD (IPv6) [ホスト ⇔ ルータ間] | PIM (Protocol 103) [ルータ ⇔ ルータ間] [22, 1.6.a (ii)] |
| **目的** | レシーバホストが存在するポートのみに転送 | PIM Join を送っているルータへのみ転送 [22, 1.6.a (ii)] |
| **適用場所** | アクセススイッチ、ディストリビューション | PIM ルータ間を接続するコア L2 スイッチ |

---

## 💡 ベストプラクティス

1. **アクセススイッチでの IGMP Snooping + Immediate-Leave の有効化:**
   1 ポートに 1 台のホストしか接続されないアクセスポート環境では、`immediate-leave` を有効化してグループ脱退時の即時ポート切断を実現し、帯域を保護する。
2. **純粋 L2 VLAN 環境での Explicit Querier 設定:**
   L3 SVI やルータが存在しない VLAN では、必ず 1 台のスイッチに `ip igmp snooping vlan <ID> querier address <IP>` を設定し、明確な IP アドレスを持たせて Querier とする [22, 1.6.a (iii)]。
3. **不正マルチキャスト受講を防ぐ IGMP Filter の配置:**
   IPTV などのエンタープライズ配信網では、指定されたマルチキャスト範囲のみ許可する `ip igmp profile` を各アクセスポートにバインドする [22, 1.6.a (iv)]。

---

## 📝 ラボ学習・設定サンプル例

以下は CCIE EI Practical Lab レベルの 10 個の完全設定シナリオです。

### Scenario 1: IGMPv3 & SSM インターフェイス有効化
* **要件:** R1 の Gi0/1 で IGMPv3 を有効化し、SSM グループ範囲 (`232.0.0.0/8`) の受講を許可せよ [22, 1.6.a (i), 1.6.c (iv)]。

```bash
interface GigabitEthernet0/1
 ip address 10.1.12.1 255.255.255.0
 ip pim sparse-mode
 ip igmp version 3
!
ip pim ssm default
```

---

### Scenario 2: L2 スイッチ上での IGMP Snooping & VLAN 単位無効化
* **要件:** SW1 で全体的に IGMP Snooping を有効化しつつ、VLAN 99 のみ Snooping を無効化せよ [22, 1.6.a (ii)]。

```bash
ip igmp snooping
ip igmp snooping vlan 99 explicit-tracking
no ip igmp snooping vlan 99
```

---

### Scenario 3: 孤立 L2 VLAN における IGMP Querier 構成
* **要件:** SW1 の VLAN 100（L3 ゲートウェイなし）で IGMP Querier を有効化し、送信元 IP `10.100.1.254` から 20 秒間隔で Query を送信させよ [22, 1.6.a (iii)]。

```bash
ip igmp snooping vlan 100 querier
ip igmp snooping vlan 100 querier address 10.100.1.254
ip igmp snooping vlan 100 querier query-interval 20
ip igmp snooping vlan 100 querier version 3
```

---

### Scenario 4: IGMP Profile によるマルチキャストグループ受信制限
* **要件:** SW1 の Gi1/0/5 ポートにおいて、グループ `239.10.10.0/24` への参加のみを許可し、最大グループ数を `3` に制限せよ [22, 1.6.a (iv)]。

```bash
ip igmp profile 10
 permit
  range 239.10.10.0 255.255.255.0
exit
!
interface GigabitEthernet1/0/5
 switchport mode access
 switchport access vlan 10
 ip igmp filter 10
 ip igmp max-groups 3
```

---

### Scenario 5: PIM Snooping の設定
* **要件:** 複数ルータを接続する SW1 の VLAN 200 で PIM Snooping を有効化せよ [22, 1.6.a (ii)]。

```bash
ip pim snooping
ip pim snooping vlan 200
```

---

### Scenario 6: IPv6 MLDv2 Snooping 設定
* **要件:** SW1 の VLAN 50 において MLDv2 Snooping および MLD Querier を構成せよ [22, 1.6.a (v)]。

```bash
ipv6 mld snooping
ipv6 mld snooping vlan 50
ipv6 mld snooping vlan 50 querier
ipv6 mld snooping vlan 50 version 2
```

---

### Scenario 7: 手動 mrouter (ルータ接続) ポートの固定バインド
* **要件:** SW1 の Gi1/0/24 が PIM パケットを送出しないハードウェア機器であっても、常時 mrouter ポートとして認識させよ [22, 1.6.a (ii)]。

```bash
ip igmp snooping vlan 10 mrouter interface GigabitEthernet1/0/24
```

---

### Scenario 8: IGMP Static Group 設定 (テスト受講用)
* **要件:** R1 の Gi0/1 で、実際のホストなしで `239.1.1.1` 宛てのマルチキャストパケットを自身で受信用にバインドせよ。

```bash
interface GigabitEthernet0/1
 ip igmp join-group 239.1.1.1
```

---

### Scenario 9: IGMP Snooping Immediate-Leave (Fast-Leave) 設定
* **要件:** SW1 の VLAN 300 で Fast-Leave を有効化し、Leave メッセージ受信時の Group-Specific Query 送信を省いて即時ポート切断せよ [22, 1.6.a (ii)]。

```bash
ip igmp snooping vlan 300 immediate-leave
```

---

### Scenario 10: Static L2 MAC マルチキャストエントリーの直接バインド
* **要件:** SW1 上で、マルチキャスト MAC `0100.5e01.0203` 宛てのパケットを VLAN 10 の Gi1/0/1 および Gi1/0/2 ポートへ静的転送せよ。

```bash
mac address-table static 0100.5e01.0203 vlan 10 interface GigabitEthernet1/0/1 GigabitEthernet1/0/2
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】L2 スイッチ環境でのマルチキャスト通信停止
**問題:**  
SW1 配下の VLAN 10 に接続されたレシーバホストが、通信開始から約 3 分後にマルチキャストストリームを受信できなくなりました。VLAN 10 には L3 ルータが存在せず、SW1 上で `ip igmp snooping` が有効化されています。何が原因ですか？また、最小限のコマンド追加で復旧させる設定を示してください。

**解答・解説:**  
* **原因:** VLAN 10 内に IGMP Querier (L3 ルータ等) が存在しないため、ホストが最初に送った IGMP Join (Report) の有効期限が切れ、SW1 の IGMP Snooping テーブルから出力ポートがエージング削除された。
* **復旧コマンド:**
  ```bash
  SW1(config)# ip igmp snooping vlan 10 querier
  ```

---

### 2. 【コンフィグ解読・設計】IGMPv3 (SSM) 導入時の注意事項
**問題:**  
既存の IGMPv2 配信網を IGMPv3 (SSM) に移行するため、ルータのインターフェイスで `ip igmp version 3` を設定しました。しかし、レシーバホストが特定送信元 `10.1.1.100` からの `232.1.1.1` を要求しているにもかかわらず通信が成立しません。ルータ全体で不足している設定は何ですか？

**解答・解説:**  
* **回答:** グローバルモードでの **`ip pim ssm default`** (または ssm range アクセスリスト指定) の設定が不足しています [22, 1.6.c (iv)]。
* **解説:** IGMPv3 をインターフェイスで有効化するだけでは L3 ルータは SSM 動作を行いません。`ip pim ssm default` コマンドにより、`232.0.0.0/8` の範囲を SSM として PIM プロセスに認識させる必要があります [22, 1.6.c (iv)]。

---

## 🔗 参考リソース

* [Cisco Systems: IP Multicast: IGMP Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_igmp/configuration/xe-3s/imc-igmp-xe-3s-book.html)
* [Cisco Systems: Layer 2 Multicast Configuration Guide, Catalyst 9300 Switches](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-3/configuration_guide/lyr2/b_173_lyr2_9300_cg/configuring_igmp_snooping.html)
* [Cisco Live: BRKCRS-3021 - Advanced Layer 2 Multicast Troubleshooting and Design](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **IGMP/MLD バージョン互換性:**
  * IGMPv3 ルータは IGMPv1/v2 の Report も受信可能（後方互換性あり）。
  * 混在環境では、最も古いバージョンの Querier がネットワーク全体のタイマーと動作モードを決定します。


## 参考リソースリンク

### 関連動画・スライド (Cisco Live On-Demand Library)
*   [BRKIPM-2264: IP Multicast Logic and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPM-2264)
*   [BRKENS-2001: Multicast Primer](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2001)
*   [BRKCCIE-3000: BGP and Multicast for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

#### Configuration ガイド
*   [IP Multicast: IGMP Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_igmp/configuration/xe-17/imc-igmp-xe-17-book.html)
*   [IPv6 Multicast: MLD Snooping Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_mld/configuration/xe-16/imc-mld-xe-16-book.html)

#### テクニカルノーツ・設定例
*   [IP Multicast Technology Overview (Cisco White Paper)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book/imc-tech-oview.pdf)
*   [IGMP Snooping FAQ and Troubleshooting](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-6500-series-switches/68131-control-multicast.html)

---


## 📝 補足
- この学習メモは、L2マルチキャストが単なるスイッチの機能ではなく、L3ルーティングと密接に連携する「ハイブリッドな最適化」であることを強調しています。特に、ルータが存在しない VLAN でのクエリア設定や、MAC アドレス重複に起因するフラッディングのトラブルシュートは、CCIE EI 実技試験での合格を左右する非常に重要なポイントです。

