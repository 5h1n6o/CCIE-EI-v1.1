---
layout: default
title: 4.4.d-Marking
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 4
---

# 4.4.d Marking DSCP values in IPv4 and IPv6 headers

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.0 Infrastructure Security and Services` における、IPv4 および IPv6 パケットヘッダーへの DSCP (Differentiated Services Code Point) マーキングおよびリマーキング技術の完全学習メモ。

---

## 📘 概要

Differentiated Services (DiffServ) アーキテクチャにおいて、**Marking (マーキング)** はネットワーク境界（Trust Boundary）やアクセス層において、パケットの QoS 優先度を IP ヘッダー内に明示的に付与する最も基礎的かつ重要な処理である。

* **機能概要:**
  * **IPv4 ヘッダー:** IPv4 Type of Service (ToS) バイト（8 bits）内の上位 6 ビット（Bit 0〜5）を DS (Differentiated Services) フィールドとして使用し、DSCP 値 (0〜63) を書き込む。下位 2 ビット（Bit 6〜7）は ECN (Explicit Congestion Notification) として保持される。
  * **IPv6 ヘッダー:** IPv6 Traffic Class バイト（8 bits）内の上位 6 ビット（Bit 0〜5）を DS フィールドとして使用し、DSCP 値 (0〜63) を書き込む。下位 2 ビットは ECN として機能する。
* **利用目的:**
  * ネットワークの入口（Ingress）でパケットのアプリケーション種別（Voice, Video, Mission-Critical Data, Best Effort 等）に応じた DSCP 値を書き込み（または非信頼端末からの不正マークを 0 にリセット）、後続のルータ/スイッチにおける Queueing (LLQ/CBWFQ), Policing, Shaping, Drop (WRED) の挙動を一貫して制御する。
* **どのような場面で利用するか:**
  * キャンパス LAN や WAN 境界での Trust Boundary 確立（非信頼端末のマーク消去）。
  * IP Phone、WebEx、Zoom、SSH、BGP 制御通信への DSCP 割り当て（EF, AF41, AF31, CS6 等）。
  * IPsec VPN / GRE トンネル境界での Outer IP ヘッダーへの DSCP 継承（ToS Copy / `qos pre-classify`）。
  * デュアルスタック (IPv4 / IPv6) 環境における共通 MQC ポリシーによる統合 QoS 制御。

---

## 🔑 要点

| 項目 | IPv4 Header Marking | IPv6 Header Marking |
| :--- | :--- | :--- |
| **該当ヘッダーフィールド** | Type of Service (ToS) バイト (8 bits) | Traffic Class バイト (8 bits) |
| **DS フィールド位置** | Bit 0〜5 (DSCP: 6 bits / 0〜63), Bit 6〜7 (ECN: 2 bits) | Bit 0〜5 (DSCP: 6 bits / 0〜63), Bit 6〜7 (ECN: 2 bits) |
| **共通 MQC コマンド** | <code>set dscp &lt;VALUE&gt;</code> / <code>match dscp &lt;VALUE&gt;</code> | <code>set dscp &lt;VALUE&gt;</code> / <code>match dscp &lt;VALUE&gt;</code> |
| **IPv4 専用旧コマンド** | <code>set ip dscp &lt;VALUE&gt;</code> / <code>match ip dscp &lt;VALUE&gt;</code> | 非対応 (IPv6 パケットに適用されない) |
| **IPv6 専用明示コマンド** | 非対応 | <code>set ipv6 dscp &lt;VALUE&gt;</code> / <code>match ipv6 dscp</code> |
| **L2 CoS からの変換** | <code>table-map</code> / <code>qos map cos to dscp</code> | <code>table-map</code> / <code>qos map cos to dscp</code> |
| **IPsec/GRE Outer 継承** | ToS Byte 複製 (自動) / <code>qos pre-classify</code> | Traffic Class 複製 (自動) / <code>qos pre-classify</code> |
| **設計上の注意点** | <code>set ip dscp</code> は IPv6 パケットにマッチ・適用されない | 共通コマンド <code>set dscp</code> の使用が IOS XE 17.x 標準 |

---

## 🏗 動作原理

### 1. IPv4 / IPv6 パケットヘッダー構造と DS フィールド

IPv4 および IPv6 のいずれにおいても、DiffServ アプローチ（RFC 2474 / RFC 3168）に基づき、8 ビットのフィールドが全く同一のレイアウトで定義されている。

```
IPv4 Header:
+---------------+---------------+-------------------+
| Version (4b)  |  IHL (4b)     | Type of Service   | ...
+---------------+---------------+-------------------+
                                  │ (8 bits)
                                  ▼
IPv6 Header:
+---------------+-------------------+---------------+
| Version (4b)  | Traffic Class     | Flow Label... | ...
+---------------+-------------------+---------------+
                                  │ (8 bits)
                                  ▼
                     ┌───────────────────────────────┐
                     │     DS Field (8 bits)         │
                     └───────────────┬───────────────┘
                                     │
             ┌───────────────────────┴───────────────────────┐
             ▼                                               ▼
+---+---+---+---+---+---+                               +---+---+
| 0 | 1 | 2 | 3 | 4 | 5 |                               | 6 | 7 |
+---+---+---+---+---+---+                               +---+---+
  DSCP (6 bits: 0 - 63)                                  ECN (2 bits)
  - Class Selector (CS0 - CS7)                           - 00: Non ECN-Capable
  - Assured Forwarding (AF11 - AF43)                     - 01/10: ECN-Capable (ECT)
  - Expedited Forwarding (EF: 46 / 101110)               - 11: Congestion Encountered (CE)
  - Default (BE: 0 / 000000)
```

### 2. MQC (Modular QoS CLI) 評価パイプラインと Dual-Stack 処理

Cisco IOS XE におけるパケット処理パイプラインでは、Ingress または Egress の物理/論理インターフェイスにおいて MQC ポリシーが評価される。

```
Incoming Packet (IPv4 or IPv6)
   ↓
[ Ingress Interface ]
   ↓
[ Trust Boundary Check ] ──(Untrusted)──► [ Set DSCP 0 (Reset) ]
   ↓ (Trusted or Classify)
[ MQC Class-Map Matching ]
   ├── match protocol (NBAR2)
   ├── match dscp / match precedence
   └── match access-group (IPv4 ACL / IPv6 ACL)
   ↓
[ MQC Policy-Map Action ]
   ├── set dscp <VALUE>  (IPv4/IPv6 両方に適用)
   ├── police (Token Bucket 判定) ──(Exceed/Violate)──► [ set-dscp-transmit (Down-mark) ]
   └── table-map (CoS -> DSCP / DSCP -> DSCP 変換)
   ↓
[ IP Forwarding / CEF Lookup ]
   ↓
[ Egress Interface Queuing / Shaping / WRED ] ──(DSCP 値に基づいてキュー分配・ドロップ判定)
   ↓
Outgoing Packet
```

---

## ⚙ 動作シーケンス

1. **パケット受信 (Ingress Processing):**
   * インターフェイスにパケット（IPv4 または IPv6）が到着する。
2. **Trust Boundary 判定:**
   * ポートが `Untrusted` に構成されている場合、パケットの既存 DSCP/CoS 値は無視され、ポリシーに従ってリセット処理が行われる。
   * ポートが `Trusted` (`qos trust dscp` 等) の場合、ヘッダー内の DSCP 値がそのまま保持される。
3. **MQC Class-Map 評価:**
   * インバウンド `service-policy input <POLICY_NAME>` が評価される。
   * `class-map` 内の条件（`match dscp`, `match protocol`, `match access-group` 等）に基づき、パケットが特定のトラフィッククラスに分類される。
4. **Marking / Remarking 実行:**
   * `set dscp <VALUE>` アクションが実行され、IPv4 ToS バイトの上位 6 ビット、または IPv6 Traffic Class バイトの上位 6 ビットが新たな DSCP ビットパターンに上書き書き換えされる。
   * ポリサー (`police`) が併用されている場合、トークンバケット判定により Conformed 通信はそのまま転送され、Exceeded 通信は `set-dscp-transmit` により低い優先度の DSCP (例: AF21 ➔ AF22 ➔ CS1) に降格（Down-mark）される。
5. **ルーティング ＆ トンネルカプセル化 (トンネル通信時):**
   * CEF ルックアップにより出力インターフェイスが決定される。
   * パケットが GRE や IPsec トンネルにカプセル化される場合、内部 IP ヘッダーの DSCP 値がデフォルトで外部（Outer）IP ヘッダー（IPv4 ToS / IPv6 Traffic Class）へ自動コピー（Inherit）される。
6. **Egress Queuing ＆ Drop 評価:**
   * 出力インターフェイスの QoS キュー（LLQ / CBWFQ）および WRED 閾値が、書き換えられた新 DSCP 値に基づいてパケットを特定のハードウェア/ソフトウェアキューに振り分け、輻輳時には DSCP ドロップ優先度に従って選択的破棄または ECN ビット更新を行う。


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験における **`4.4.d Marking DSCP values in IPv4 and IPv6 headers`** に関する最重要ポイントと、失点を防ぐための罠・ハマりポイントを整理する。

### 1. `set ip dscp` vs `set dscp` の落とし穴 (最重要)
* **問題の解読:** ラボ試験問題文で「IPv4 および IPv6 トラフィックの双方に対して、VoIP 通信を DSCP EF に、ビデオ通信を DSCP AF41 にマークせよ」と指示された場合。
* **陥りがちなミス:** `set ip dscp ef` や `match ip dscp ef` を使用してしまう。
* **動作結果:** `set ip dscp` は **IPv4 パケットのみ** に作用し、IPv6 パケットは完全に無視（マーク変更なし / マッチ失敗）される。結果として IPv6 通信の QoS 要件が満たされず大失点となる。
* **正解コンフィグ:** 必ず IPv4/IPv6 共通コマンドである **`set dscp <VALUE>`** および **`match dscp <VALUE>`** を使用すること。

### 2. IP Precedence と DSCP のビット変換と挙動の違い
* `set precedence 5` を設定すると、ToS / Traffic Class バイトの上位 3 ビットが `101` に設定され、下位 3 ビットは `000` にリセットされる（即ち DSCP 40 / CS5 と同等）。
* `set dscp ef` (DSCP 46 = `101110`) を設定した場合、IP Precedence 値としては上位 3 ビット `101` (Precedence 5) と解釈される。レガシー機器との相互運用試験ではこのビットマッピングが問われる。

### 3. Table-Map による動的 DSCP / CoS リマーキング
* ポリサーによる Down-marking や L2-L3 境界における非線形マッピングでは、`table-map` を定義して `policy-map` 内で呼び出す構成が要求される。
  ```bash
  table-map TMAP_COS_TO_DSCP
   default copy
   map 5 to 46
   map 3 to 26
  !
  policy-map PM_INGRESS
   class CM_ALL
    set dscp cos table TMAP_COS_TO_DSCP
  ```

### 4. IPsec / GRE トンネル境界での `qos pre-classify`
* パケットが GRE や IPsec トンネルで暗号化・カプセル化されると、内部 IP ヘッダーの L4 ポート番号や IP アドレスが暗号化され、Egress インターフェイスでの NBAR2 や ACL マッチングが不可能になる。
* **解法:** トンネルインターフェイス（`interface TunnelX`）または IPsec Crypto Map において **`qos pre-classify`** を有効化し、カプセル化前の内部 IP ヘッダー情報を参照して MQC 分類・DSCP マーキングを実行させる。

### 5. ポリサー (1r3c / 2r3c) と連動した Down-Marking
* ラボ試験では「帯域 CIR 10Mbps までは DSCP AF31 で転送し、10Mbps〜15Mbps のバースト通信は DSCP AF32 に降格して転送し、15Mbps 超過通信は DSCP CS1 に降格（またはドロップ）せよ」といった要求が頻出する。
* **コンフィグ構造:**
  ```bash
  policy-map PM_POLICE_MARK
   class CM_DATA
    police cir 10000000 pir 15000000
     conform-action set-dscp-transmit af31
     exceed-action set-dscp-transmit af32
     violate-action set-dscp-transmit cs1
  ```

---

## 🛠 設定方法

### 1. IPv4 / IPv6 共通 MQC マーキング基本構成

```bash
! --- 1. Class-Map の定義 (IPv4/IPv6 共通 match コマンド) ---
class-map match-any CM_VOICE
 match dscp ef
 match protocol rtpadio
 match protocol sip

class-map match-any CM_VIDEO
 match dscp af41
 match protocol webex-media

class-map match-all CM_DATA_BULK
 match access-group name ACL_DATA_IPV4_V6

! --- 2. Policy-Map の定義 (set dscp コマンド) ---
policy-map PM_MARKING_INGRESS
 class CM_VOICE
  set dscp ef
 class CM_VIDEO
  set dscp af41
 class CM_DATA_BULK
  set dscp af11
 class class-default
  set dscp default

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet1/0/1
 description Access_Port_Dual_Stack
 service-policy input PM_MARKING_INGRESS
```

### 2. Table-Map を使用した CoS / DSCP 相互変換構成

```bash
! --- Table-Map の定義 ---
table-map TMAP_COS2DSCP
 map 0 to 0
 map 1 to 8
 map 2 to 16
 map 3 to 24
 map 4 to 32
 map 5 to 46
 map 6 to 48
 map 7 to 56
 default copy

! --- Policy-Map での Table-Map 適用 ---
policy-map PM_TABLE_MAP_MARK
 class class-default
  set dscp cos table TMAP_COS2DSCP
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 確認ポイント |
| :--- | :--- | :--- |
| **QoS ポリシー適用確認** | <code>show policy-map interface &lt;INT&gt;</code> | 各クラスのパケット数/バイト数、`set dscp` 実行カウンタ、ドロップ数の確認 |
| **入力方向ポリシー検証** | <code>show policy-map interface &lt;INT&gt; input</code> | Ingress マーキングの実行統計と Class パケットマッチング |
| **出力方向ポリシー検証** | <code>show policy-map interface &lt;INT&gt; output</code> | Egress Queuing / Shaping / WRED 動作と DSCP マッチング |
| **NBAR2 アプリケーション統計** | <code>show ip nbar protocol-discovery</code> | 認識されたアプリ（WebEx, SIP等）と DSCP 値の対応 |
| **Table-Map 定義確認** | <code>show table-map &lt;NAME&gt;</code> | CoS から DSCP への変換エントリ一覧の検証 |
| **パケットキャプチャ (EPC)** | <code>monitor capture CAP interface &lt;INT&gt; both</code> | 実際に出力される IPv4 ToS / IPv6 Traffic Class バイトのキャプチャ検証 |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **IPv6 通信の DSCP マークが変更されない** | <code>set ip dscp</code> を使用しているため IPv6 パケットが除外されている | <code>show policy-map interface</code> で IPv6 マッチカウンタが増加しない | ポリシー内の設定を <code>set dscp &lt;VALUE&gt;</code> へ修正 |
| **Ingress でマークした DSCP が Egress でリセットされる** | 対向スイッチのポートが Untrusted (`qos trust` 欠落) になっている | <code>show policy-map interface</code> (Ingress 側) | 対向スイッチポートで <code>qos trust dscp</code> を有効化 |
| **VPN トンネル通過後に Egress QoS マッチに失敗する** | IPsec 暗号化により L4/アプリヘッダーが隠蔽されている | <code>show policy-map interface tunnelX</code> | トンネル I/F で <code>qos pre-classify</code> を追加設定 |
| **1r3c ポリサーで全パケットが Violate 判定される** | Bc (Committed Burst) または Be の設定値が MTU より小さい | <code>show policy-map interface</code> | Bc / Be 値を最小 1500 バイト以上（推奨: 1.5 倍〜2 倍）へ修正 |
| **IPv6 ACL で `match access-group` がマッチしない** | <code>ip access-group</code> を Class-map 内で参照している | <code>show class-map</code> | IPv6 に対応するため <code>match access-group name &lt;ACL&gt;</code> を使用 |

---

## ⚠ 制限事項

* **ハードウェア TCAM 制限 (Catalyst 9000 シリーズ):**
  * スイッチポートにおける同時の Marking/Policing クラス数にはハードウェア ASIC/TCAM の上限がある。
  * IPv4 と IPv6 で別々の ACL マッチを大量に作成すると TCAM エントリを急激に消費するため、共通の `match dscp` または NBAR2 による一括分類が推奨される。
* **`set ip dscp` と `set ipv6 dscp` の混在不可:**
  * 同一クラス内で `set ip dscp` と `set ipv6 dscp` を重複定義することは推奨されず、プラットフォームによっては CLI 構文エラーまたは後勝ち上書きとなる。常に `set dscp` を単一指定すること。
* **Sub-interface / GRE Tunnel での制限:**
  * 一部のプラットフォームでは、サブインターフェイスやトンネルインターフェイスへのインバウンドマーキングポリシー直接適用に制限があり、HQoS (Hierarchical QoS) が必要となる場合がある。

---

## 🔄 他技術との関連

* **IPv4 ToS / IPv6 Traffic Class Header:**
  * IP レイヤの基本ヘッダーフィールド。QoS マーキングの直接的なターゲット。
* **MQC (Modular QoS CLI):**
  * `class-map`, `policy-map`, `service-policy` による QoS 設計フレームワーク。
* **NBAR2 (Next Generation Network-Based Application Recognition):**
  * L7 ディープパケットインスペクションにより、動的ポートや URL を識別して `set dscp` アクションへ渡す。
* **IPsec VPN / GRE Tunnels / DMVPN:**
  * 暗号化・トンネル化環境での Outer IP Header への DSCP 継承（ToS Copy）および `qos pre-classify` 連携。
* **WRED (Weighted Random Early Detection) ＆ ECN:**
  * マーキングされた DSCP 値（特に AF11〜AF43 の Drop Precedence）に基づいて、パケットの早期ランダムドロップや ECN ビット設定を実行。

---

## 🧩 比較表

| 比較項目 | IPv4 ToS Field (DS Byte) | IPv6 Traffic Class Field (DS Byte) |
| :--- | :--- | :--- |
| **ヘッダー位置** | IPv4 Header 2 バイト目 (8 bits) | IPv6 Header 2 バイト目 (8 bits) |
| **DS フィールド構造** | 上位 6 bits (DSCP), 下位 2 bits (ECN) | 上位 6 bits (DSCP), 下位 2 bits (ECN) |
| **専用 MQC コマンド** | <code>set ip dscp &lt;VAL&gt;</code> | <code>set ipv6 dscp &lt;VAL&gt;</code> |
| **推奨共通 MQC コマンド** | <code>set dscp &lt;VAL&gt;</code> | <code>set dscp &lt;VAL&gt;</code> |
| **IP Precedence 互換** | 上位 3 ビット (0〜7) 完全互換 | 上位 3 ビ field (0〜7) 完全互換 |
| **トンネル自動継承** | Outer IPv4 ToS に内側 ToS を自動コピー | Outer IPv6 Traffic Class に内側 TC を自動コピー |

---

## 💡 ベストプラクティス

1. **共通コマンド `set dscp` の徹底使用:**
   * デュアルスタック化が進むエンタープライズ網において、トラブルや設定漏れを防ぐため、常に IPv4/IPv6 共通の `set dscp <VALUE>` および `match dscp <VALUE>` を使用する。
2. **RFC 4594 準拠の標準マーキング設計:**
   * Voice (RTP): **DSCP EF (46)**
   * Call Signaling: **DSCP CS3 (24)** (Cisco 推奨)
   * Interactive Video: **DSCP AF41 (34)**
   * Broadcast Video: **DSCP CS5 (40)** (Cisco 推奨)
   * Mission-Critical Data: **DSCP AF31 (26)**
   * Bulk Data: **DSCP AF11 (10)**
   * Scavenger (P2P/娯楽): **DSCP CS1 (8)**
   * Best Effort: **DSCP DF (0)**
3. **ネットワーク水際（Trust Boundary）でのマーク消去:**
   * 非信頼アクセスポートに入力されるトラフィックは、明示的に許可されたアプリケーション以外 `set dscp default (0)` へリセットし、QoS なりすまし攻撃を防止する。
4. **トンネル環境での `qos pre-classify` 必須配置:**
   * GRE / DMVPN / IPsec トンネルインターフェイスでは、暗号化前の内部ヘッダーに基づく正確な分類・マーキングを行うため `qos pre-classify` を設定する。


## 📝 ラボ学習・設定サンプル例

### ラボ 1: デュアルスタック (IPv4/IPv6) 音声通信の DSCP EF / CS3 マーキング構成

* **問題:** 企業網のアクセススイッチ SW1 において、IPv4 および IPv6 の双方で送受信される VoIP メディア通信 (RTP) を DSCP EF に、シグナリング通信 (SIP) を DSCP CS3 に分類・マーキングせよ。
* **要件:**
  * IPv4 と IPv6 の双方に対応できる共通コマンド (`set dscp`) を使用すること。
  * `set ip dscp` などの IPv4 限定コマンドは使用しないこと。
  * インバウンドインターフェイス GigabitEthernet1/0/1 に適用すること。

* **設定例:**
```bash
! 1. Class-Map の定義 (IPv4/IPv6 共通 match)
class-map match-any CM_VOIP_MEDIA
 match protocol rtpadio
 match protocol rtp

class-map match-any CM_VOIP_SIGNALING
 match protocol sip

! 2. Policy-Map の定義 (set dscp)
policy-map PM_VOIP_MARK_DUAL
 class CM_VOIP_MEDIA
  set dscp ef
 class CM_VOIP_SIGNALING
  set dscp cs3
 class class-default
  set dscp default

! 3. インターフェイスへの適用
interface GigabitEthernet1/0/1
 description Dual_Stack_Access_Port
 service-policy input PM_VOIP_MARK_DUAL
```

* **検証方法:**
  * IPv4 および IPv6 端末から通話（SIP/RTP）を発生させる。
  * `show policy-map interface GigabitEthernet1/0/1 input` を実行し、`CM_VOIP_MEDIA` および `CM_VOIP_SIGNALING` のマッチパケット数・バイト数が増加し、`set dscp ef` / `set dscp cs3` が正常にカウントされていることを確認。

---

### ラボ 2: NBAR2 アプリケーション識別による WebEx ミーティングの DSCP AF41 マーキング構成

* **問題:** ルータ R1 において、NBAR2 (Deep Packet Inspection) を使用して WebEx ミーティング通信（WebEx Media）を識別し、DSCP AF41 にリマークせよ。
* **要件:**
  * CEF (Cisco Express Forwarding) を事前に有効化すること。
  * NBAR2 プロトコル識別 `webex-media` を使用すること。
  * 該当しないトラフィックは既存のマークを変更しないこと。

* **設定例:**
```bash
! 1. CEF のグローバル有効化 (NBAR2 必須要件)
ip cef
ipv6 cef

! 2. NBAR2 Class-Map の定義
class-map match-any CM_WEBEX
 match protocol webex-media
 match protocol webex-meeting

! 3. Policy-Map の定義
policy-map PM_MARK_WEBEX
 class CM_WEBEX
  set dscp af41

! 4. インターフェイス適用
interface GigabitEthernet0/0/1
 service-policy input PM_MARK_WEBEX
```

* **検証方法:**
  * WebEx ミーティングを起動し、トラフィックを発生させる。
  * `show ip nbar protocol-discovery` を実行し、`webex-media` 通信が正しく認識されていることを確認。
  * `show policy-map interface GigabitEthernet0/0/1` で `CM_WEBEX` クラスのカウンタ増加と `set dscp af41` の実行を確認。

---

### ラボ 3: 1r3c ポリサーによる 10Mbps 超過通信の DSCP AF22/CS1 降格構成

* **問題:** インターフェイス GigabitEthernet0/0/2 に入力されるデータ通信 (AF21) に対し、10Mbps までは AF21 のまま転送し、10Mbps〜15Mbps のバースト通信は AF22 に降格し、15Mbps を超える違反通信は CS1 (Scavenger) に降格して転送せよ。
* **要件:**
  * Single Rate Three-Color (1r3c / RFC 2697) トークンバケットポリサーを使用すること。
  * パケット破棄（Drop）は行わず、すべて Down-marking (DSCP 降格) 処理を行うこと。

* **設定例:**
```bash
! 1. トラフィックの定義
class-map match-all CM_DATA_STREAM
 match dscp af21

! 2. ポリサー定義 (Conform / Exceed / Violate アクション)
policy-map PM_POLICE_DOWNMARK
 class CM_DATA_STREAM
  police cir 10000000 pir 15000000
   conform-action transmit
   exceed-action set-dscp-transmit af22
   violate-action set-dscp-transmit cs1

! 3. インターフェイス適用
interface GigabitEthernet0/0/2
 service-policy input PM_POLICE_DOWNMARK
```

* **検証方法:**
  * トラフィックジェネレーターから 20Mbps の AF21 パケットを送出する。
  * `show policy-map interface GigabitEthernet0/0/2` を実行し、`conformed` (10Mbps 分), `exceeded` (5Mbps 分 ➔ AF22), `violated` (5Mbps 分 ➔ CS1) の各アクション統計が正しく記録されていることを確認。

---

### ラボ 4: Table-Map を使用した L2 CoS から L3 DSCP への変換マーキング構成

* **問題:** トランクポートから受信した L2 802.1p CoS 値を基に、Table-Map を使用して L3 IPv4/IPv6 DSCP 値に変換・マーキングせよ。
* **要件:**
  * CoS 5 ➔ DSCP EF (46)
  * CoS 4 ➔ DSCP AF41 (34)
  * CoS 3 ➔ DSCP CS3 (24)
  * その他の CoS 値はそのまま DSCP に複製 (`default copy`) すること。

* **設定例:**
```bash
! 1. Table-Map の定義
table-map TMAP_COS_TO_DSCP_CUSTOM
 map 5 to 46
 map 4 to 34
 map 3 to 24
 default copy

! 2. Policy-Map での Table-Map 呼び出し
policy-map PM_CONVERT_COS_DSCP
 class class-default
  set dscp cos table TMAP_COS_TO_DSCP_CUSTOM

! 3. インターフェイス適用
interface GigabitEthernet1/0/10
 service-policy input PM_CONVERT_COS_DSCP
```

* **検証方法:**
  * CoS 5, 4, 3 が付与された 802.1Q タグ付きフレームを送信する。
  * `show table-map TMAP_COS_TO_DSCP_CUSTOM` で定義マッピングを検証。
  * `show policy-map interface GigabitEthernet1/0/10` でテーブル変換が実行されていることを確認。

---

### ラボ 5: 非信頼アクセスポートにおける未承認パケットの DSCP 0 リセット構成

* **問題:** アクセスポート GigabitEthernet1/0/15 に接続された一般 PC から送信される不審な QoS マーク（DSCP EF や AF41 等）を拒否し、許可された音声通信以外すべて DSCP 0 (Default) にリセットせよ。
* **要件:**
  * 許可する音声通信 (IP Phone 由来) は DSCP EF とする。
  * それ以外の全トラフィックは `class-default` で `set dscp default` (0) に書き換えること。

* **設定例:**
```bash
! 1. 許可する音声通信の定義
class-map match-all CM_TRUSTED_VOICE
 match dscp ef
 match access-group name ACL_VOICE_SUBNET

! 2. 未承認マークのリセットポリシー
policy-map PM_UNTRUST_RESET
 class CM_TRUSTED_VOICE
  set dscp ef
 class class-default
  set dscp default

! 3. インターフェイス適用
interface GigabitEthernet1/0/15
 description Untrusted_PC_Port
 service-policy input PM_UNTRUST_RESET
```

* **検証方法:**
  * PC から DSCP 46 (EF) や DSCP 34 (AF41) を付与した Ping / HTTP パケットを送信する。
  * 出力インターフェイスでのキャプチャまたは `show policy-map interface` で `class-default` のカウンタが増加し、DSCP が 0 に上書きされていることを確認。

---

### ラボ 6: GRE / IPsec DMVPN トンネル環境における `qos pre-classify` 構成

* **問題:** DMVPN ルータ Spoke-1 において、IPsec / GRE トンネルカプセル化前に内部パケットの宛先 IP および L4 アプリケーションを識別して DSCP AF31 にマークし、トンネル出力ポートで適切な QoS Queuing を実行させよ。
* **要件:**
  * `interface Tunnel0` において `qos pre-classify` を有効化すること。
  * 外側 Physical I/F GigabitEthernet0/0/0 で内部ヘッダーに基づく QoS マッチを行わせること。

* **設定例:**
```bash
! 1. Class-Map / Policy-Map の定義
class-map match-any CM_VPN_DATA
 match protocol ssh
 match protocol https

policy-map PM_VPN_MARK_OUT
 class CM_VPN_DATA
  set dscp af31
 class class-default
  set dscp default

! 2. Tunnel インターフェイスでの qos pre-classify 設定
interface Tunnel0
 ip address 10.255.255.2 255.255.255.0
 tunnel source GigabitEthernet0/0/0
 tunnel mode gre multipoint
 qos pre-classify

! 3. 物理出力ポートへの QoS ポリシー適用
interface GigabitEthernet0/0/0
 service-policy output PM_VPN_MARK_OUT
```

* **検証方法:**
  * トンネル経由で SSH (TCP 22) 通信を発生させる。
  * `show policy-map interface GigabitEthernet0/0/0` を実行し、暗号化パケットであるにもかかわらず `CM_VPN_DATA` にパケットがマッチし、`set dscp af31` が適用されていることを確認。

---

### ラボ 7: Object-Group (IPv4/IPv6) を併用した社内基幹アプリの DSCP AF31 マーキング構成

* **問題:** 社内基幹サーバー群（IPv4: 10.100.1.0/24, IPv6: 2001:DB8:100:1::/64）と端末間の通信を Object-Group を用いて定義し、DSCP AF31 にマーキングせよ。
* **要件:**
  * Object-Group Network を使用して IPv4 および IPv6 サーバー帯を管理すること。
  * 共通 MQC コマンドを使用すること。

* **設定例:**
```bash
! 1. Object-Group の定義
object-group network OG_CORE_SERVERS_V4
 10.100.1.0 255.255.255.0

object-group network OG_CORE_SERVERS_V6
 2001:DB8:100:1::/64

! 2. ACL の定義
ip access-list extended ACL_CORE_APP_V4
 permit ip any object-group OG_CORE_SERVERS_V4
 permit ip object-group OG_CORE_SERVERS_V4 any

ipv6 access-list ACL_CORE_APP_V6
 permit ipv6 any object-group OG_CORE_SERVERS_V6
 permit ipv6 object-group OG_CORE_SERVERS_V6 any

! 3. Class-Map の定義
class-map match-any CM_CORE_APP
 match access-group name ACL_CORE_APP_V4
 match access-group name ACL_CORE_APP_V6

! 4. Policy-Map の定義
policy-map PM_CORE_MARK
 class CM_CORE_APP
  set dscp af31

! 5. インターフェイス適用
interface GigabitEthernet0/0/1
 service-policy input PM_CORE_MARK
```

* **検証方法:**
  * IPv4 および IPv6 双方の基幹サーバー宛てに通信を発生させる。
  * `show policy-map interface GigabitEthernet0/0/1` で `CM_CORE_APP` クラスのパケットマッチ数が増加し、`set dscp af31` が適用されていることを確認。

---

### ラボ 8: Cisco IP Phone 接続ポートでの Conditional Trust ＆ Voice/Data VLAN 分離構成

* **問題:** アクセススイッチ SW1 のポート GigabitEthernet1/0/5 に Cisco IP Phone が接続されている。CDP を用いて IP Phone を動的認識した場合のみ Voice VLAN (VLAN 100) からの CoS 5 を信頼して DSCP EF に変換し、背面 PC (Data VLAN 10) からの通信はすべて DSCP 0 にリセットせよ。
* **要件:**
  * `qos trust device cisco-phone` を使用すること。
  * CDP がグローバルに有効化されていること。

* **設定例:**
```bash
! 1. CDP の確認・有効化
cdp run

! 2. インターフェイス設定 (Conditional Trust & VLAN 設定)
interface GigabitEthernet1/0/5
 description IP_Phone_and_PC_Port
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 100
 qos trust device cisco-phone
```

* **検証方法:**
  * `show cdp neighbors GigabitEthernet1/0/5` で Cisco IP Phone が隣接として認識されていることを確認。
  * IP Phone 由来の通話パケットが DSCP EF に維持・変換され、PC から打ち込まれた DSCP マークは 0 に上書きされていることを確認。

---

### ラボ 9: Class Selector (CS1〜CS7) によるネットワーク管理プロトコルマーキング構成

* **問題:** ルータ自社宛ておよびルータ経由のネットワーク管理・制御通信について、BGP/OSPF ルーティングプロトコルを DSCP CS6、SSH/SNMP 管理通信を DSCP CS2、P2P 娯楽通信を DSCP CS1 (Scavenger) にマーキングせよ。
* **要件:**
  * Class Selector (CS) 定義を使用すること。

* **設定例:**
```bash
! 1. Class-Map 定義
class-map match-any CM_ROUTING_CONTROL
 match protocol bgp
 match protocol ospf

class-map match-any CM_MGMT_TRAFFIC
 match protocol ssh
 match protocol snmp

class-map match-any CM_SCAVENGER
 match protocol bittorrent

! 2. Policy-Map 定義
policy-map PM_MGMT_CS_MARK
 class CM_ROUTING_CONTROL
  set dscp cs6
 class CM_MGMT_TRAFFIC
  set dscp cs2
 class CM_SCAVENGER
  set dscp cs1

! 3. インターフェイス適用
interface GigabitEthernet0/0/0
 service-policy input PM_MGMT_CS_MARK
```

* **検証方法:**
  * BGP/OSPF ネイバー通信、SSH セッション、SNMP Polling を発生させる。
  * `show policy-map interface GigabitEthernet0/0/0` でそれぞれのクラスへ正しく振り分けられ、CS6, CS2, CS1 が付与されていることを確認。

---

### ラボ 10: WLC CAPWAP トンネル環境における Outer CAPWAP Header への DSCP 継承構成

* **問題:** ワイヤレスアクセスポイント (AP) と WLC 間でカプセル化される CAPWAP トンネルトラフィックにおいて、内側ワイヤレスフレームの QoS マーク（DSCP/CoS）を外側 Outer CAPWAP IP ヘッダー（IPv4/IPv6）へ正確に自動コピー（Inherit）して有線 LAN 上で転送せよ。
* **要件:**
  * CAPWAP QoS マッピング規格に準拠すること。
  * Wireless VLAN / AP ポート側で `qos trust dscp` を適用すること。

* **設定例:**
```bash
! 1. AP 接続アクセススイッチポート設定
interface GigabitEthernet1/0/20
 description Cisco_Capwap_AP_Port
 switchport mode access
 switchport access vlan 200
 qos trust dscp

! 2. WLC 側での CAPWAP QoS マッピングポリシー確認 (IOS XE 参照)
wireless qos map dscp-to-up 46 to 6
wireless qos map dscp-to-up 34 to 4
wireless qos map dscp-to-up 0 to 0
```

* **検証方法:**
  * Wi-Fi クライアントから Voice (DSCP EF) 通信を発信する。
  * スイッチ側ポートでキャプチャを実施し、Outer CAPWAP IP ヘッダー（IPv4 ToS / IPv6 Traffic Class）の DSCP 値が 46 (EF) としてコピーされて有線網を通過していることを確認。


## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** エンタープライズ網のルータ R1 において、IPv4 および IPv6 の双方が混在するネットワーク上で Voice 通信を DSCP EF にマーキングするために以下の MQC コンフィグを投入した。しかし、検証ツールで確認したところ、IPv6 端末からの Voice パケットの DSCP マークが変更されず Best Effort (0) のまま転送されていた。

**設問:** IPv6 パケットのマーキングが適用されなかった直接的原因と、両スタック（IPv4 / IPv6）で正常にマーキングを実行させるための修復コマンドを述べよ。

* **解答・解説:**
  * **原因:** Class-map 内の  および Policy-map 内の  は **IPv4 パケット専用** の構文であり、IPv6 パケットはマッチ評価およびアクション対象から完全に除外されるため。
  * **修正コンフィグ:**
    

---

### 問 2 (Design / 信頼境界)
**シナリオ:** アクセス層スイッチ SW1 のポート Gi1/0/1 に接続された一般 PC のユーザーが、自身で送信するパケットの ToS ヘッダーに DSCP 46 (EF) を付与して帯域を優先占有しようと試みている。ネットワーク設計者として、この不正な優先制御を防止しつつ、正当な社内サーバー宛てデータ通信のみを DSCP AF31 にマークする設計を考案せよ。

* **解答・解説:**
  * **設計要件:** スイッチポート Gi1/0/1 をデフォルトで  状態とし、着信パケットの既存マークを無効化する。その上で MQC インバウンドポリシーを適用し、社内サーバー宛ての特定通信のみを  に明示マークし、その他すべての通信は  で  (0) に強制リセットする。
  * **適用コンフィグ例:**
    

---

### 問 3 (トラブルシューティング / VPN トンネル)
**シナリオ:** DMVPN 環境において、Spoke ルータの LAN 側でマーキングされた DSCP AF41 パケットが、Hub ルータ手前の WAN 回線ルータでの Egress QoS キューイング () に一切マッチせず、 に落とされていた。WAN パケットキャプチャを確認すると、パケットは ESP (IPsec) で暗号化されていた。
**設問:** Egress QoS マッチに失敗した原因と、Spoke ルータ側で設定すべき解決策コマンドを答えよ。

* **解答・解説:**
  * **原因:** IPsec 暗号化および GRE トンネルカプセル化により、元の内部 IP ヘッダーおよび L4 ポート情報が隠蔽され、外側 IP ヘッダーのプロトコルが ESP (50) に変化したため、Egress 側の NBAR / L4 基準 Class-map マッチに失敗したため。
  * **解決策:** Spoke ルータのトンネルインターフェイス  において **** を有効化する。これにより、パケットのカプセル化前に内部ヘッダー情報を参照して Egress 分類を実行させることが可能となる。

---

### 問 4 (実装 / Token Bucket Policing)
**シナリオ:** ルータ R1 の GigabitEthernet0/0/0 において、DSCP AF31 トラフィックに対して 10Mbps の CIR を適用し、10Mbps 以内の適合トラフィックは AF31 のまま転送、バースト超過分は AF32 に降格（Down-mark）して転送するポリシーを構築せよ。

* **解答・解説:**
  * **コンフィグ:**
    

---

### 問 5 (コンフィグ読解 / IP Precedence vs DSCP)
**シナリオ:** レガシーなルータのコンフィグで  が投入されている。
**設問:** このパケットが Cisco IOS XE 17.x の最新スイッチに転送された場合、DSCP 値（Decimal）および DSCP クラス名としてどのように解釈・マッチングされるか答えよ。

* **解答・解説:**
  * **解釈:**  はバイナリで  である。DS フィールド（6 bits）の上位 3 ビットが 、下位 3 ビットが  となるため、バイナリパターンは  となる。
  * **DSCP Decimal:**  = 40。
  * **DSCP クラス名:** **DSCP CS5** (Class Selector 5)。
  * したがって、最新スイッチの Class-map で  または  を定義することで、このパケットに正確にマッチさせることができる。

---

## 🔗 参考リソース

* Cisco IOS XE 17.x Quality of Service Solutions Configuration Guide
* Quality of Service Design Overview (Cisco CVD)
* RFC 2474 - Definition of the Differentiated Services Field (DS Field) in the IPv4 and IPv6 Headers
* RFC 2597 - Assured Forwarding PHB Group
* RFC 3246 - An Expedited Forwarding PHB (Per-Hop Behavior)
* RFC 4594 - Configuration Guidelines for DiffServ Service Classes
* Cisco Live: Enterprise QoS Design and Best Practices

---

## 📝 **補足（Notes）**

### 1. DSCP 値とバイナリ / デシマル迅速変換テクニック
* **Class Selector (CS):** Precedence * 8 （例: CS3 = 3 * 8 = 24, CS5 = 5 * 8 = 40, CS6 = 6 * 8 = 48）
* **Assured Forwarding (AFxy):** (8 * x) + (2 * y)
  * AF11 = 8 * 1 + 2 * 1 = 10
  * AF21 = 8 * 2 + 2 * 1 = 18
  * AF31 = 8 * 3 + 2 * 1 = 26
  * AF41 = 8 * 4 + 2 * 1 = 34
  * AF42 = 8 * 4 + 2 * 2 = 36
  * AF43 = 8 * 4 + 2 * 3 = 38
* **Expedited Forwarding (EF):** Binary 101110 = Decimal 46

### 2. IPv4 ToS と IPv6 Traffic Class の構造整合性
IPv4 と IPv6 では、名前こそ ToS と Traffic Class で異なるものの、DiffServ 規格 (RFC 2474) により完全に同一の 8 ビットレイアウトを採用している。したがって、 コマンドを使用することで、IOS XE 内部の MQC エンジンは両プロトコルのヘッダーの該当 8 ビットバイトの上位 6 ビットを全く同じロジックで書き換える。




## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
    *   最新のIOS-XEにおけるQoS実装と、ハードウェアレベルでのマーキングの仕組みを解説。
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
    *   キャンパスネットワークにおけるDSCP設計とトラスト境界のベストプラクティス。

### Configuration ガイド
*   [**QoS: Marking Network Traffic Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_classn/configuration/xe-17/qos-classn-xe-17-book/qos-classn-mrkg-ntwk-trfc.html)。
*   [**Implementing QoS for IPv6 (Technical Reference)**](https://www.cisco.com/c/en/us/td/docs/ios/ipv6/configuration/guide/ip6-qos.html)。

### テクニカルドキュメント・設定例
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。
*   [**DSCP and Precedence Values Reference Table**](https://www.cisco.com/c/en/us/td/docs/switches/datacenter/nexus1000/sw/4_0/qos/configuration/guide/nexus1000v_qos/qos_6dscp_val.pdf)。

---

## 📝 補足
- この学習メモは、CCIE EI試験において「どのトラフィックを」「どの値で」「どのタイミングで」マークすべきかを論理的に整理しています。実技試験では、**`show policy-map interface`** の出力を詳細に分析し、意図したマーキング（`set` アクション）が実際にパケットに適用されているかをパケットカウントで確認する能力が合格への鍵となります。


