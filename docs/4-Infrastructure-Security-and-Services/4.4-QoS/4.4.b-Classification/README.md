---
layout: default
title: 4.4.b-Classification
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.4.b Classification, trust boundary

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint における QoS (Quality of Service) の基盤技術である **`4.4.b Classification, trust boundary`**（トラフィック分類、マーキング、信頼境界、CoS/DSCP 変換、Conditional Trust、MQC vs MLS QoS）に関する詳細な学習メモ。

---

## 📘 概要

QoS 処理の第一段階である**分類（Classification）**および**信頼境界（Trust Boundary）**の設定は、エンドツーエンド QoS 設計において最も重要かつ決定的なコンポーネントである。適切な分類とマーキングが行われない限り、後続のキューイング（LLQ/CBWFQ）、ポリシング（Policing）、シェーピング（Shaping）、および輻輳回避（WRED）などの QoS アクションは正しく機能しない。

* **Classification（トラフィック分類）:**
  * 受信したパケット/フレームのヘッダー情報（L2 CoS, L2.5 MPLS EXP, L3 IP Precedence/DSCP, L4 TCP/UDP ポート番号, L7 NBAR2 アプリケーション識別）に基づき、トラフィックの種類を特定して適切な QoS クラス（Class）に割り当てる処理。
  * **目的:** 多種多様なアプリケーショントラフィックをビジネス重要度（Voice, Video, Signaling, Critical Data, Scavenger 等）に応じてカテゴリ分けする。

* **Trust Boundary（信頼境界）:**
  * ネットワーク内で「パケットに付与された QoS マーク（CoS や DSCP）をそのまま信頼（Trust）するか、または破棄・書き換え（Untrust/Remark）するか」の境界線。
  * **利用目的:** 一般 PC ユーザーなどの未認証・未信頼な端末による「自発的な高優先度 DSCP（例: EF/46）の不正付与（QoS 偽装・なりすまし）」をネットワーク水際（Access Switch Port）で遮断し、バックボーン帯域の無断占有を防ぐ。
  * **適用場面:** キャンパスアクセススイッチポート、Cisco IP Phone 接続ポート、WLAN コントローラ (WLC) 境界、WAN ネットワーク境界。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | パケット入口（Ingress Edge）でのトラフィック識別と、QoS マークの信頼判定・再付与処理。 |
| **用途** | 音声・ビデオ・データ・制御通信の優先度分類、未認証端末からの QoS マークなりすまし防止。 |
| **メリット** | 不正な優先パケットの排除によるコア網の保護、帯域・遅延要求に応じた正確なサービス提供。 |
| **デメリット/課題** | アクセスポートごとの適切な Trust 設定や MQC ポリシーの導入が必要で、設計・運用が複雑化する。 |
| **対応機種** | Cisco Catalyst 9000 シリーズ, Catalyst 3850/4500E/6500, ISR4000, ASR1000, Cisco Catalyst SD-WAN エッジルータ。 |
| **制限事項** | MLS QoS（Catalyst 3750 等）と MQC (IOS XE) で CLI 構文・動作（デフォルト Trust 状態）が著しく異なる。 |
| **設計上の注意点** | 信頼境界は「可能な限りエンドポイントに近い水際（Access Layer）」に配置するのが原則。IP Phone 経由 PC トラフィックの CoS 0 リセット処理を考慮すること。 |

---

## 🏗 動作原理

信頼境界と分類・マーキング処理は、パケットがスイッチ/ルータに入力（Ingress）された直後に実行される。

```
[ エンドポイント ] (PC / Cisco IP Phone / Server)
       │
       ▼  (Ingress Packet with CoS/DSCP)
┌──────────────────────────────────────────────────────────┐
│              Ingress Interface (Switch Port)             │
├──────────────────────────────────────────────────────────┤
│ 1. Trust Boundary Check (信頼境界判定)                   │
│    - Untrusted: QoS マークを無視し CoS/DSCP = 0 にリセット   │
│    - Trusted (CoS/DSCP): 既存の CoS または DSCP を維持     │
│    - Conditional Trust: CDP で Cisco IP Phone 等を検出時のみ │
│                         音声 VLAN の CoS 5/3 を信頼        │
├──────────────────────────────────────────────────────────┤
│ 2. Classification & Marking (分類 ＆ マーク付与)         │
│    - Class-Map (ACL, DSCP, CoS, NBAR2) でパケット識別    │
│    - Policy-Map 内の set dscp / set cos でマーキング更新   │
├──────────────────────────────────────────────────────────┤
│ 3. Mapping Table Conversion (内部変換テーブル)           │
│    - CoS-to-DSCP マッピング (CoS 5 ➔ DSCP EF/46)         │
│    - DSCP-to-CoS マッピング                                │
└──────────────────────────────────────────────────────────┘
       │
       ▼
[ Egress Queuing / Scheduling ] (LLQ / CBWFQ / WRED)
```

---

## ⚙ 動作シーケンス

パケットが Catalyst スイッチまたはルータに入力された際の処理手順：

1. **パケットの受信と L2/L3 ヘッダー解析:**
   * 入力フレームの 802.1Q タグ内の CoS ビット（3ビット）および IP ヘッダー内の DSCP フィールド（6ビット）を確認する。

2. **信頼境界（Trust State）の評価:**
   * **Untrusted ポート:** パケットの既存マークを無視し、内部 QoS ラベル (Internal DSCP) を 0（Best Effort）に書き換える。
   * **Trusted CoS ポート:** 802.1Q タグの CoS 値を受け入れ、`CoS-to-DSCP` マッピングテーブルを参照して内部 DSCP を算出（例: CoS 5 ➔ DSCP 46）。
   * **Trusted DSCP ポート:** L3 IP パケットの DSCP 値をそのまま信頼して内部 DSCP に適用。
   * **Conditional Trust (条件付き信頼):** CDP (Cisco Discovery Protocol) で対向の Cisco IP Phone を正常検出した場合にのみ、Voice VLAN からの CoS 5 (Voice) / CoS 3 (Signaling) の信頼を動的に有効化。PC ポート（Data VLAN）からのトラフィックは CoS 0 に強制上書き。

3. **MQC Class-Map によるトラフィック分類:**
   * `class-map` 内の `match` 条件（`match access-group`, `match dscp`, `match cos`, `match protocol` 等）と照合。

4. **MQC Policy-Map による Marking アクションの適用:**
   * `set dscp <VALUE>` または `set cos <VALUE>` アクションにより、パケットの QoS マークを新しい規定値に書き換える。

5. **内部 DSCP から Egress Queuing への転送:**
   * 算出・書き換えられた内部 DSCP に基づいて、送信キュー（Egress Hardware Queue）およびドロップ閾値（WRED / Tail Drop）が割り当てられる。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、`Classification and Trust Boundary` は非常にトラブルや引っかけ問題が作りやすい技術領域である。

### 1. ラボ試験での最重要ポイント
* **MLS QoS vs MQC (IOS XE) の動作の決定的違い:**
  * **MLS QoS (旧 Catalyst 3750/3560 等):** グローバルで `mls qos` を有効化すると、**全ポートがデフォルトで Untrusted (`mls qos trust` なし)** となり、明示的に `mls qos trust dscp` や `mls qos trust cos` を書かないと全パケットの DSCP/CoS が 0 にリセットされる。
  * **MQC (Catalyst 9000 / IOS XE):** デフォルトで **QoS が有効かつ DSCP/CoS が保持（Preserved / Trusted）** される。`service-policy` をバインドしない限りマークは変化しない。
* **CoS-to-DSCP デフォルトマッピングの罠:**
  * 従来の `mls qos trust cos` では、CoS 5 のデフォルトマッピング値は `CoS 5 × 8 = 40` (CS5) となり、**RFC 3246 定義の DSCP EF (46) にはならない**。そのため、`mls qos map cos-dscp 0 8 16 24 32 46 48 56` のように手動で CoS 5 ➔ 46 の修正コマンドを入れる必要がある。
* **Conditional Trust (Cisco IP Phone 接続) の構成要件:**
  * `qos trust device cisco-phone` (C3PL / IOS XE) または `mls qos trust device cisco-phone` (MLS QoS)。
  * CDP が無効 (`no cdp run` や インターフェイスで `no cdp enable`) になっていると、IP Phone が識別できず Conditional Trust が解除されて全パケットが Untrusted (CoS/DSCP 0) にフォールバックする。

### 2. よくある設定ミス ＆ トラブルシューティング
* **トラブル 1: `match ip dscp` vs `match dscp` の誤用:**
  * `match ip dscp` は **IPv4 パケットのみ**にマッチし、IPv6 トラフィックをスルーしてしまう。CCIE EI ではデュアルスタック環境が一般的なため、**`match dscp`** を使用するのが正解。
* **トラブル 2: IP Phone 配下の PC トラフィックが優先扱いされてしまう:**
  * IP Phone 側の設定（`switchport priority extend trust` など）を誤って全信頼にすると、PC から送信された偽装 CoS 5 パケットがそのまま通過してしまう。PC ポートは CoS 0 リセット（`switchport priority extend cos 0`）にする必要がある。
* **トラブル 3: IPsec / GRE トンネル環境での QoS マーク消失:**
  * トンネルインターフェイスでパケットが暗号化・カプセル化される際、アウター IP ヘッダーにインナー DSCP がコピーされない場合がある。`qos pre-classify` コマンドをトンネルまたは暗号化インターフェイスに適用する必要がある。


## 🛠 設定方法

Cisco IOS XE (Catalyst 9000 シリーズ / MQC / C3PL) およびレガシー Catalyst (MLS QoS) における代表的な設定例を示す。

### 1. MQC (IOS XE / Catalyst 9000) での標準的な Classification ＆ Marking

```bash
! --- 1. Class-Map の定義 (IPv4/IPv6 両対応の match dscp を使用) ---
class-map match-all CM_VOICE
 match dscp ef

class-map match-all CM_SIGNALING
 match dscp cs3

class-map match-any CM_CRITICAL_DATA
 match dscp af21 af22 af23
 match access-group name ACL_CRITICAL_APPS

! --- 2. Policy-Map の定義 ＆ マーク書き換え (Set Actions) ---
policy-map PM_INGRESS_MARKING
 class CM_VOICE
  set dscp ef
 class CM_SIGNALING
  set dscp cs3
 class CM_CRITICAL_DATA
  set dscp af21
 class class-default
  set dscp default

! --- 3. インターフェイスへのバインド ---
interface GigabitEthernet1/0/1
 description Access_Port_To_Server
 service-policy input PM_INGRESS_MARKING
```

### 2. Conditional Trust (Cisco IP Phone 接続ポート) の設定 (IOS XE)

```bash
! --- 1. CoS から DSCP への書き換えポリシーマップ作成 ---
class-map match-all CM_COS_VOICE
 match cos 5

class-map match-all CM_COS_SIGNALING
 match cos 3

policy-map PM_IPPHONE_TRUST
 class CM_COS_VOICE
  set dscp ef
 class CM_COS_SIGNALING
  set dscp cs3
 class class-default
  set dscp default

! --- 2. アクセスポートでの Conditional Trust 有効化 ＆ ポリシー適用 ---
interface GigabitEthernet1/0/10
 description Connect_to_Cisco_IP_Phone
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 110
 spanning-tree portfast
 
 ! CDP による Cisco IP Phone 検出時のみ Trust を拡張
 qos trust device cisco-phone
 service-policy input PM_IPPHONE_TRUST
```

### 3. NBAR2 (L7 Deep Packet Inspection) によるアプリ分類 ＆ Marking

```bash
! --- 1. NBAR2 プロトコル識別による Class-Map ---
class-map match-any CM_WEBEX
 match protocol webex-media
 match protocol webex-app

class-map match-any CM_SCAVENGER
 match protocol bittorrent
 match protocol youtube

! --- 2. Policy-Map の作成 ---
policy-map PM_NBAR_MARKING
 class CM_WEBEX
  set dscp af41
 class CM_SCAVENGER
  set dscp cs1
 class class-default
  set dscp default

! --- 3. インターフェイス設定 ---
interface GigabitEthernet1/0/20
 ip nbar protocol-discovery
 service-policy input PM_NBAR_MARKING
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **QoS ポリシーの適用状態確認** | `show policy-map interface <INTERFACE>` |
| **Class-Map の定義内容確認** | `show class-map` |
| **Policy-Map の定義内容確認** | `show policy-map` |
| **ポートの QoS Trust 状態確認 (IOS XE)** | `show platform qos interface <INTERFACE>` |
| **ポートの QoS Trust 状態確認 (MLS QoS)** | `show mls qos interface <INTERFACE>` |
| **CoS-to-DSCP マッピング確認 (MLS QoS)** | `show mls qos map cos-dscp` |
| **NBAR2 アプリケーション検出統計確認** | `show ip nbar protocol-discovery` |
| **QoS インターフェイスパケットカウンタ詳細** | `show platform qos dscp-cos counters <INTERFACE>` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **IP Phone の音声が断続的・遅延する** | CDP が無効化されており Conditional Trust が有効化されず CoS 5 が 0 にリセットされている | `show cdp neighbors`<br>`show policy-map interface` | `cdp run` および対象ポートで `cdp enable` を有効化する |
| **IPv6 音声通信の QoS マークが脱落する** | `match ip dscp ef` が使用されており、IPv6 パケットがマッチしていない | `show class-map`<br>`show policy-map interface` | `match ip dscp` を IPv4/IPv6 双方にマッチする **`match dscp`** に変更する |
| **MLS スイッチで QoS 設定が一切反映されない** | グローバルコマンド `mls qos` が投入されていない | `show mls qos` | グローバルコンフィグで `mls qos` を実行する |
| **PC からの直打ち DSCP EF パケットがそのまま通過する** | アクセスポートが誤って `trust dscp` に設定されている | `show platform qos interface` | アクセスポートの Trust を解除（Untrusted）し、インバウンドで `set dscp default` または Conditional Trust を適用する |
| **GRE / IPsec トンネル経由の通信で QoS 優先制御が効かない** | トンネル外側ヘッダーに内側パケットの DSCP が引き継がれていない | `show policy-map interface` | トンネルまたは物理 I/F に `qos pre-classify` を設定する |

---

## ⚠ 制限事項

* **ハードウェア TCAM リソースの限界:**
  * スイッチの TCAM リソースを超過する複雑な ACL や NBAR2 ルールを多数記述すると、QoS ポリシーが Hardware 処理から Software 処理（CPU 転送）にフォールバックし、通信遅延や CPU 高負荷を引き起こす。
* **プラットフォーム間の構文非互換性:**
  * IOS XE (Catalyst 9000) では C3PL (Common Classification Policy Language) に統一されており、従来の `mls qos` コマンド群は完全に非サポート。
* **Egress 方向の NBAR2 制限:**
  * NBAR2 アプリケーション識別は、多くのプラットフォームで Ingress 方向の適用が推奨・限定されている。

---

## 🔄 他技術との関連

* **QoS Queuing & Scheduling (LLQ / CBWFQ):**
  * Classification ＆ Marking によって付与された DSCP 値（EF, AF41, CS3 等）に基づいて、Egress 側のハードウェアキュー（Priority Queue / Bandwidth Queue）にパケットが振り分けられる。
* **Wireless QoS (CAPWAP / WMM):**
  * 無線 LAN 環境では、WMM (Wi-Fi Multimedia) の User Priority (UP 0〜7) と 有線網の DSCP / CoS との相互マッピングが行われる。
* **Switch Security (Port Security / 802.1X):**
  * 802.1X 認証成功後に Cisco ISE から RADIUS dACL または Dynamic VLAN とともに QoS Policy-Map 名を動的付与することが可能。

---

## 🧩 比較表

### 1. L2 CoS vs L3 DSCP 比較

| 項目 | L2 CoS (Class of Service) | L3 DSCP (Differentiated Services Code Point) |
| :--- | :--- | :--- |
| **標準規格** | IEEE 802.1p (802.1Q ヘッダー内) | RFC 2474 / RFC 2475 (IP ヘッダー内) |
| **ビット長 / 段階** | 3 ビット (0 〜 7 の 8 段階) | 6 ビット (0 〜 63 の 64 段階) |
| **透過性 (End-to-End)** | **L2 境界（ルータ通過時）で消滅**する | **エンドツーエンドで保持**される（L3 透過） |
| **適用場所** | Trunk ポート、Voice VLAN タグ付きフレーム | IP パケット全般 (L3 ネットワーク全体) |

### 2. MLS QoS vs MQC (IOS XE) 比較

| 項目 | MLS QoS (レガシー Catalyst) | MQC / C3PL (IOS XE / Cat9k) |
| :--- | :--- | :--- |
| **有効化コマンド** | 手動で `mls qos` が必須 | デフォルトで有効（コマンド不要） |
| **デフォルト Trust 状態** | `mls qos` 有効化で**全ポート Untrusted** | **デフォルトで Trust (Preserved)** |
| **設定体系** | `mls qos trust`, `mls qos map` 等独自 | `class-map`, `policy-map`, `service-policy` |

---

## 💡 ベストプラクティス

1. **信頼境界は「水際（Access Edge）」で確立する:**
   * 一般端末が接続されるポートは原則 Untrusted とし、Cisco IP Phone などの承認済み端末ポートのみ Conditional Trust を適用する。
2. **DSCP ベースの統一設計を採用する:**
   * L2 CoS はルータ越えで消失するため、ネットワーク全体としては L3 DSCP（RFC 4594 準拠）で一貫した分類・マーキングを行う。
3. **`match dscp` の使用を徹底する:**
   * デュアルスタック環境での漏れを防ぐため、`match ip dscp` ではなく IPv4/IPv6 共通の `match dscp` を選択する。
4. **NBAR2 の乱用を避ける:**
   * Deep Packet Inspection (NBAR2) は CPU / TCAM 負荷が高いため、アクセスエッジの主要アプリケーション識別のみに絞って適用する。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: アクセスポート Untrusted 化 ＆ MQC による 3 クラス分類・マーキング

* **問題:** スイッチ Catalyst-1 の GigabitEthernet1/0/1（PC 接続ポート）において、PC から送信される既存の QoS マークを一切信用せず（Untrusted）、DSCP に基づいてトラフィックを 3 クラスに再分類・マーキングせよ。
* **要件:**
  * UDP 16384-32767 通信を Voice クラスとし、`DSCP EF` (46) にマークせよ。
  * TCP 5060-5061 通信を Signaling クラスとし、`DSCP CS3` (24) にマークせよ。
  * その他の全トラフィックは `DSCP default` (0) にリセットせよ。
  * IPv4 および IPv6 の双方で動作すること。

* **設定例:**
```bash
! --- 1. トラフィック識別用 ACL の作成 ---
ip access-list extended ACL_VOICE_RTP
 permit udp any any range 16384 32767

ip access-list extended ACL_SIGNALING
 permit tcp any any range 5060 5061

! --- 2. Class-Map の定義 (IPv4/IPv6 共通の match 構文) ---
class-map match-any CM_LAB1_VOICE
 match access-group name ACL_VOICE_RTP

class-map match-any CM_LAB1_SIGNALING
 match access-group name ACL_SIGNALING

! --- 3. Policy-Map の定義 ---
policy-map PM_LAB1_UNTRUST_MARK
 class CM_LAB1_VOICE
  set dscp ef
 class CM_LAB1_SIGNALING
  set dscp cs3
 class class-default
  set dscp default

! --- 4. インターフェイスへの適用 ---
interface GigabitEthernet1/0/1
 description PC_Access_Port
 switchport mode access
 switchport access vlan 10
 service-policy input PM_LAB1_UNTRUST_MARK
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet1/0/1` を実行し、`CM_LAB1_VOICE` および `CM_LAB1_SIGNALING` クラスでパケットがマッチし、`set dscp` カウンタが増加していることを確認。

---

### ラボ 2: Cisco IP Phone 接続ポートの Conditional Trust ＆ CoS-to-DSCP 変換構成

* **問題:** 物理ポート GigabitEthernet1/0/10 に接続された Cisco IP Phone からの音声通信を保護するため、CDP による動的 Conditional Trust を設定せよ。
* **要件:**
  * Cisco IP Phone が検出された場合のみ、Voice VLAN (VLAN 110) からの CoS 5 通信を `DSCP EF` に、CoS 3 通信を `DSCP CS3` に変換して信頼せよ。
  * 電話背面の PC ポート (Data VLAN 10) から送信されるトラフィックは全て `DSCP default` (0) にリセットせよ。

* **設定例:**
```bash
! --- 1. Class-Map の定義 ---
class-map match-all CM_PHONE_VOICE
 match cos 5

class-map match-all CM_PHONE_SIGNALING
 match cos 3

! --- 2. Policy-Map の定義 ---
policy-map PM_CONDITIONAL_TRUST
 class CM_PHONE_VOICE
  set dscp ef
 class CM_PHONE_SIGNALING
  set dscp cs3
 class class-default
  set dscp default

! --- 3. インターフェイス設定 ＆ Conditional Trust 適用 ---
interface GigabitEthernet1/0/10
 description Connect_Cisco_IP_Phone
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 110
 cdp enable
 qos trust device cisco-phone
 service-policy input PM_CONDITIONAL_TRUST
```

* **検証方法:**
  * `show cdp neighbors` で IP Phone が正常認識されていることを確認。
  * `show platform qos interface GigabitEthernet1/0/10` を実行し、`Trust State` が `Trust CoS` に動的昇格していることを確認。

---

### ラボ 3: NBAR2 アプリケーション識別による WebEx / YouTube 動的分類・マーキング

* **問題:** インターネット境界ルータ R1 の GigabitEthernet0/0/1 において、L7 パケットインスペクション（NBAR2）を用いて WebEx クラウド通信と YouTube 動画閲覧を判別し、異なる DSCP マークを付与せよ。
* **要件:**
  * WebEx 通信（`webex-media`, `webex-app`）を `DSCP AF41` (34) にマークせよ。
  * YouTube 通信（`youtube`）を Scavenger クラスとし、`DSCP CS1` (8) にマークせよ。

* **設定例:**
```bash
! --- 1. NBAR2 Class-Map の定義 ---
class-map match-any CM_NBAR_WEBEX
 match protocol webex-media
 match protocol webex-app

class-map match-any CM_NBAR_YOUTUBE
 match protocol youtube

! --- 2. Policy-Map の定義 ---
policy-map PM_NBAR_MARK
 class CM_NBAR_WEBEX
  set dscp af41
 class CM_NBAR_YOUTUBE
  set dscp cs1
 class class-default
  set dscp default

! --- 3. インターフェイス適用 ＆ NBAR2 有効化 ---
interface GigabitEthernet0/0/1
 description LAN_Edge_Interface
 ip nbar protocol-discovery
 service-policy input PM_NBAR_MARK
```

* **検証方法:**
  * `show ip nbar protocol-discovery interface GigabitEthernet0/0/1` を実行し、WebEx および YouTube のトラフィックバイト数がカウントされていることを確認。
  * `show policy-map interface GigabitEthernet0/0/1` で各クラスのパケットマッチ数を確認。

---

### ラボ 4: Table Map を用いた DSCP-to-CoS / CoS-to-DSCP 相互変換構成

* **問題:** トランクポートを通過するパケットに対して、カスタムな `table-map` を定義して L2 CoS と L3 DSCP の相互書き換えを実行せよ。
* **要件:**
  * 入力された DSCP 値をベースに、CoS 5 ➔ DSCP 46, CoS 4 ➔ DSCP 34, CoS 3 ➔ DSCP 24, その他 ➔ DSCP 0 にマッピング変換せよ。

* **設定例:**
```bash
! --- 1. Table-Map の作成 ---
table-map MAP_COS_TO_DSCP
 map from 5 to 46
 map from 4 to 34
 map from 3 to 24
 default 0

! --- 2. MQC Class-Map ＆ Policy-Map での Table-Map 適用 ---
class-map match-any CM_TAGGED_TRAFFIC
 match cos 3 4 5

policy-map PM_TABLEMAP_CONVERT
 class CM_TAGGED_TRAFFIC
  set dscp cos table MAP_COS_TO_DSCP
 class class-default
  set dscp default

! --- 3. インターフェイス適用 ---
interface GigabitEthernet1/0/24
 description Trunk_Uplink
 service-policy input PM_TABLEMAP_CONVERT
```

* **検証方法:**
  * `show table-map MAP_COS_TO_DSCP` でマップテーブル定義を確認。
  * `show policy-map interface GigabitEthernet1/0/24` で変換適用数を確認。

---

### ラボ 5: Object-Group と MQC を組み合わせた複合アプリケーション分類

* **問題:** 企業内で利用される複数の管理用プロトコル（SSH, SNMP, Syslog, NTP）およびデータ転送プロトコルを Object-Group でまとめ、効率的に DSCP マーキングを行え。
* **要件:**
  * Object-Group `OG_MGMT_SERVICES`（TCP 22, UDP 161, UDP 514, UDP 123）に一致する通信を `DSCP CS2` (16) にマークせよ。
  * Object-Group `OG_CRITICAL_SERVERS`（10.50.0.0/24）からの通信を `DSCP AF21` (18) にマークせよ。

* **設定例:**
```bash
! --- 1. Object-Group の定義 ---
object-group service OG_MGMT_SERVICES
 tcp eq 22
 udp eq 161
 udp eq 514
 udp eq 123

object-group network OG_CRITICAL_SERVERS
 10.50.0.0 255.255.255.0

! --- 2. ACL の定義 ---
ip access-list extended ACL_MGMT_TRAFFIC
 permit object-group OG_MGMT_SERVICES any any

ip access-list extended ACL_CRITICAL_DATA
 permit ip object-group OG_CRITICAL_SERVERS any

! --- 3. MQC Class-Map ＆ Policy-Map ---
class-map match-all CM_MGMT
 match access-group name ACL_MGMT_TRAFFIC

class-map match-all CM_CRITICAL
 match access-group name ACL_CRITICAL_DATA

policy-map PM_OBJECTGROUP_MARK
 class CM_MGMT
  set dscp cs2
 class CM_CRITICAL
  set dscp af21
 class class-default
  set dscp default

! --- 4. インターフェイス適用 ---
interface GigabitEthernet1/0/5
 service-policy input PM_OBJECTGROUP_MARK
```

* **検証方法:**
  * `show access-list ACL_MGMT_TRAFFIC` で Object-Group の展開状態を確認。
  * `show policy-map interface GigabitEthernet1/0/5` でマッチ数を確認。

---

### ラボ 6: IPsec VPN / GRE トンネル環境における `qos pre-classify` 構成

* **問題:** ルータ R1 で GRE/IPsec トンネルを作成して通信を行っている。暗暗号化前のインナー IP ヘッダーの QoS マーク（DSCP）に基づいて、アウトバウンド物理物理インターフェイス上で分類・キューイング制御を行いたい。
* **要件:**
  * `qos pre-classify` 機能を有効化し、暗号化前のパケット情報で QoS 評価を行わせよ。

* **設定例:**
```bash
! --- 1. トンネルインターフェイス設定 ＆ qos pre-classify 有効化 ---
interface Tunnel1
 ip address 172.16.1.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 198.51.100.2
 qos pre-classify

! --- 2. MQC キューイングポリシー作成 ---
class-map match-all CM_VOIP_INNER
 match dscp ef

policy-map PM_WAN_OUT
 class CM_VOIP_INNER
  priority percent 30
 class class-default
  bandwidth percent 70

! --- 3. 物理 WAN インターフェイスへの適用 ---
interface GigabitEthernet0/0/0
 service-policy output PM_WAN_OUT
```

* **検証方法:**
  * トンネル経由で VoIP (DSCP EF) パケットを送信し、`show policy-map interface GigabitEthernet0/0/0` において `CM_VOIP_INNER` クラスに正しくパケットが保持・カウントされていることを確認。

---

### ラボ 7: Single-Rate Three-Color Policing (1r3c / RFC 2697) による Down-Marking 構成

* **問題:** 宛先データトラフィック（10.1.1.0/24 宛て）に対し、1Mbps を超えたトラフィックをドロップさせずに QoS マークを格下げ（Down-Mark）して送信させよ。
* **要件:**
  * CIR 1Mbps, Bc 8000 bytes, Be 16000 bytes の 1r3c ポリサーを構築せよ。
  * Conform (Green): `DSCP AF21` (18) にマークして転送。
  * Exceed (Yellow): `DSCP AF22` (20) に格下げして転送。
  * Violate (Red): `DSCP CS1` (8) に格下げして転送（ドロップしない）。

* **設定例:**
```bash
! --- 1. Class-Map の作成 ---
ip access-list extended ACL_DATA_FLOW
 permit ip any 10.1.1.0 0.0.0.255

class-map match-all CM_DATA_FLOW
 match access-group name ACL_DATA_FLOW

! --- 2. Policy-Map ＆ 1r3c ポリサー設定 ---
policy-map PM_MARKDOWN_POLICE
 class CM_DATA_FLOW
  police cir 1000000 bc 8000 be 16000
   conform-action set-dscp-transmit af21
   exceed-action set-dscp-transmit af22
   violate-action set-dscp-transmit cs1

! --- 3. インターフェイス適用 ---
interface GigabitEthernet1/0/15
 service-policy input PM_MARKDOWN_POLICE
```

* **検証方法:**
  * テスターから 2Mbps の帯域でパケットを送出し、`show policy-map interface GigabitEthernet1/0/15` で `conformed`, `exceeded`, `violated` パケット数とそれぞれの DSCP 書き換えアクション実行数を確認。

---

### ラボ 8: WLC (Wireless LAN Controller) CAPWAP トンネル QoS マッピング構成

* **問題:** Catalyst 9800 WLC / AP 環境において、無線クライアントからの WMM User Priority (UP) と有線網 DSCP の相互マッピングを構成せよ。
* **要件:**
  * WMM UP 6/7 (Voice) を `DSCP EF` (46) にマッピングせよ。
  * WMM UP 4/5 (Video) を `DSCP AF41` (34) にマッピングせよ。
  * WMM UP 0 (Best Effort) を `DSCP default` (0) にマッピングせよ。

* **設定例:**
```bash
! --- 1. Wireless QoS Map の定義 (IOS XE / Cat9800) ---
wireless qos map bluedscp-to-up 46 to 6
wireless qos map bluedscp-to-up 34 to 5
wireless qos map bluedscp-to-up 0 to 0

! --- 2. QoS Profile の作成 ＆ SSID 適用 ---
ap profile AP_GLOBAL_PROFILE
 qos-policy PM_WIRELESS_TRUST

wlan WLAN_ENTERPRISE 1 enterprise_ssid
 qos-profile platinum
```

* **検証方法:**
  * `show wireless qos map` を実行し、DSCP ↔ WMM UP のマッピングテーブルを確認。

---

### ラボ 9: レガシー MLS QoS (Catalyst 3750) における Trust CoS ＆ 手動 CoS-to-DSCP マッピング

* **問題:** 旧型スイッチ Catalyst 3750 において、QoS を有効化し、GigabitEthernet1/0/1 で `Trust CoS` を構成せよ。
* **要件:**
  * `mls qos` をグローバルで有効化すること。
  * デフォルトの CoS 5 ➔ DSCP 40 マッピングを破棄し、CoS 5 ➔ `DSCP EF` (46) に変換するグローバルマップを適用すること。

* **設定例:**
```bash
! --- 1. グローバル QoS 有効化 ＆ CoS-to-DSCP マップ変更 ---
mls qos
mls qos map cos-dscp 0 8 16 24 32 46 48 56

! --- 2. インターフェイス設定 ---
interface GigabitEthernet1/0/1
 mls qos trust cos
```

* **検証方法:**
  * `show mls qos` で `QoS is enabled` を確認。
  * `show mls qos map cos-dscp` で CoS 5 が 46 にマッピングされていることを確認。

---

### ラボ 10: 802.1X / RADIUS 認証成功時の Dynamic QoS Policy (C3PL) 動的付与構成

* **問題:** アクセスポート GigabitEthernet1/0/2 に接続された端末が 802.1X 認証に成功した際、Cisco ISE (RADIUS) から属性値経由で動的に Inbound QoS Policy をアタッチさせよ。
* **要件:**
  * ポート上で C3PL 認証セッションを有効化すること。
  * RADIUS 属性 `Filter-Id` または `Cisco-AVPair = "qos-policy-in=PM_DYNAMIC_USER"` を受け入れる構成とすること。

* **設定例:**
```bash
! --- 1. 動的適用用 Policy-Map の事前作成 ---
class-map match-all CM_USER_VOICE
 match dscp ef

policy-map PM_DYNAMIC_USER
 class CM_USER_VOICE
  set dscp ef
 class class-default
  set dscp default

! --- 2. 802.1X / C3PL ポート設定 ---
interface GigabitEthernet1/0/2
 switchport mode access
 authentication port-control auto
 dot1x pae authenticator
 access-session inherit disable autoconf
```

* **検証方法:**
  * 端末で 802.1X 認証を実行し、`show access-session interface GigabitEthernet1/0/2 details` を確認。`Applied Policy: PM_DYNAMIC_USER` が表示されていることを検証。


## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** アクセススイッチ SW1 の GigabitEthernet1/0/1 に接続された端末から IPv6 音声パケットを送信しているが、後続のルータで QoS マークが全て `0` にリセットされていることが判明した。SW1 のコンフィグを確認すると以下のように設定されていた。

```bash
class-map match-all CM_VOICE
 match ip dscp ef

policy-map PM_MARK
 class CM_VOICE
  set dscp ef
 class class-default
  set dscp default

interface GigabitEthernet1/0/1
 service-policy input PM_MARK
```

**設問:** この障害が発生している直接的な原因と、SW1 で実行すべき修復コマンドを答えよ。

* **解答:**
  * **原因:** `class-map` 内で `match ip dscp ef` が使用されているため。`match ip dscp` は **IPv4 パケットのみ** にマッチする構文であり、入力された IPv6 音声パケットは `CM_VOICE` クラスをスルーして `class-default` にヒットし、`set dscp default` (0) に書き換えられてしまっていた。
  * **修復コマンド:**
    ```bash
    class-map match-all CM_VOICE
     no match ip dscp ef
     match dscp ef
    ```

---

### 問 2 (Design / 信頼境界)
**シナリオ:** 大規模企業網において、一般端末 PC が自発的に DSCP EF (46) マークを付与してバックボーン帯域を無断占有するセキュリティ違反が発生している。アクセス層には Cisco IP Phone と PC がデイジーチェーン接続されている。

**設問:** PC からの QoS 偽装パケットを確実に遮断しつつ、Cisco IP Phone からの正規の音声パケット（CoS 5 / DSCP 46）を保護するためのアクセスポート設計（Trust Boundary）と設定方針を述べよ。

* **解答:**
  * **設計方針:** アクセスポートで **Conditional Trust (条件付き信頼)** を確立する。スイッチは CDP を用いて対向が Cisco IP Phone であることを検証した場合にのみ、Voice VLAN からの CoS 5 (Voice) / CoS 3 (Signaling) トラフィックの信頼を動的に拡張する。同時に、IP Phone 内蔵のスイッチチップに対して「PC 用ポート（Data VLAN）からの入力トラフィックの CoS を 0 にリセットしてスイッチへ転送する」指示を出す。
  * **設定コマンド:**
    ```bash
    interface GigabitEthernet1/0/10
     switchport mode access
     switchport access vlan 10
     switchport voice vlan 110
     cdp enable
     qos trust device cisco-phone
     service-policy input PM_COS_TO_DSCP_MAP
    ```

---

### 問 3 (トラブルシューティング / CDP 依存関係)
**シナリオ:** 管理者がセキュリティポリシー強化のため、全スイッチポートで一律 `no cdp run` を設定した。その直後から、Cisco IP Phone 経由で接続された全通話の音声品質が急激に悪化し、パケットドロップが多発した。

**設問:** CDP を無効化したことで Conditional Trust がどのように影響を受けたか説明せよ。

* **解答:**
  * **解説:** Conditional Trust (`qos trust device cisco-phone`) は、スイッチと Cisco IP Phone 間の CDP パケット交換によって相手機器を正規認識・認証する仕組みに依存している。`no cdp run` により CDP が停止したことで、スイッチは対向の IP Phone を識別できなくなり、Conditional Trust ポートが自動的に **Untrusted 状態（デフォルト）に落とされた**。その結果、IP Phone から送信された CoS 5 / DSCP EF の音声パケットが全て `DSCP 0` (Best Effort) にリセットされ、キューイングで優先処理されなくなってドロップが発生した。

---

### 問 4 (実装 / NBAR2 マーキング)
**シナリオ:** 社内網から社外への WebEx メディア通信（`webex-media`）を優先保護するため、ルータの LAN 側ポートにおいて NBAR2 による識別と `DSCP AF41` のマーキングを構成したい。

**設問:** 必要な Class-Map, Policy-Map, インターフェイス設定コマンドを記述せよ。

* **解答:**
  ```bash
  class-map match-any CM_NBAR_WEBEX
   match protocol webex-media

  policy-map PM_MARK_WEBEX
   class CM_NBAR_WEBEX
    set dscp af41
   class class-default
    set dscp default

  interface GigabitEthernet0/0/0
   ip nbar protocol-discovery
   service-policy input PM_MARK_WEBEX
  ```

---

### 問 5 (コンフィグ読解 / Table Map)
**シナリオ:** 以下のコンフィグが適用されたスイッチポートの動作について答えよ。

```bash
table-map MAP_MARKDOWN
 map from 18 to 8
 default copy

policy-map PM_POLICE_MARK
 class CM_DATA
  police 10000000 8000 exceed-action set-dscp-transmit dscp table MAP_MARKDOWN

interface GigabitEthernet1/0/5
 service-policy input PM_POLICE_MARK
```

**設問:** 入力パケットが 10Mbps を超えた（Exceed）場合、`DSCP AF21` (18) のパケットおよびその他の DSCP パケットはどのように処理されるか答えよ。

* **解答:**
  * **動作:** `DSCP AF21` (値 18) のパケットが 10Mbps を超過した場合、`table-map MAP_MARKDOWN` の定義に従って `DSCP CS1` (値 8 - Scavenger) に格下げ（Down-mark）されて転送される。その他の DSCP 値を持つパケットが超過した場合は、`default copy` の定義に従って、元の DSCP 値を維持したまま転送される。

---

## 🔗 参考リソース

Cisco 公式ドキュメントおよび Cisco Live 技術資料：

* Cisco Live - Campus QoS Design Simplified (BRKCRS-2501)
* Cisco IOS XE 17.x Quality of Service Solutions Configuration Guide
* Cisco Catalyst 9300 Series Switch QoS Configuration Guide
* Cisco Technical Note: Quality of Service (QoS) Differentiated Services Code Point (DSCP) and Precedence Values
* Cisco Validated Design (CVD): Enterprise Quality of Service Design Guide

---

## 📝 **補足（Notes）**

### 1. QoS チートシート (DSCP ↔ Binary ↔ Decimal マッピング表)

| サービス記述 | PHB クラス | DSCP 名 | Binary | Decimal | 主な用途 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Voice Media** | EF | `ef` | `101110` | **46** | VoIP 音声メディア (厳格優先) |
| **Broadcast Video** | CS5 | `cs5` | `101000` | **40** | テレビ放送・ライブ動画配信 |
| **Interactive Video**| AF41 | `af41` | `100010` | **34** | 双方向ビデオ会議 (WebEx, TelePresence) |
| **Call Signaling** | CS3 | `cs3` | `011000` | **24** | 呼制御 (SIP, H.323, SCCP) |
| **Critical Data** | AF21 | `af21` | `010010` | **18** | トランザクション処理・業務アプリ |
| **Bulk Data** | AF11 | `af11` | `001010` | **10** | 大容量ファイル転送・FTP |
| **Scavenger** | CS1 | `cs1` | `001000` | **8** | P2P・YouTube・ノンビジネス通信 |
| **Best Effort** | DF | `default` | `000000` | **0** | 標準データ通信 |

### 2. トラブル防止チェックリスト
* [ ] アクセスポートで不要な `qos trust dscp` を排除しているか？
* [ ] IP Phone ポートで `cdp enable` および `qos trust device cisco-phone` が正しく設定されているか？
* [ ] MQC で `match ip dscp` ではなく `match dscp` を使用しているか？
* [ ] トンネル環境で `qos pre-classify` を忘れていないか？
* [ ] NBAR2 を使用する場合、`ip nbar protocol-discovery` をインターフェイスで有効化しているか？


## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501) - キャンパスネットワークにおける分類とトラスト境界のベストプラクティス。
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731) - IOS XE デバイスにおける最新のQoS実装。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Quality of Service Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos/configuration/xe-17/qos-xe-17-book.html)。
*   [**Configuring NBAR-Based Classification**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)。

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND)**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)。
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。

---

## 📝 補足
- この学習メモは、QoSの「入り口」である分類とトラストの重要性を整理しています。CCIE実技試験では、**NBARのプロトコル認知**や**ACLとの組み合わせ**が頻出するため、`show policy-map interface` で意図通りに分類されているかを確認する習慣を身につけてください。


