---
layout: default
title: 4.4.a-DiffServ
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.4.a Differentiated Services architecture

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.4 Quality of Service` における、**Differentiated Services (DiffServ) アーキテクチャ (4.4.a)** の完全学習メモ。

---

## 📘 概要

* **機能概要:**
  Differentiated Services (DiffServ: 差別化サービス) アーキテクチャは、IP ネットワーク上でトラフィッククラスに応じた異なる品質管理 (QoS: Quality of Service) を提供するための標準フレームワーク (RFC 2474, RFC 2475, RFC 2597, RFC 3246, RFC 4594) である。従来の IntServ (Integrated Services) がフローごとのシグナリング (RSVP) と状態保持を要求し拡張性に課題があったのに対し、DiffServ はネットワーク境界 (Ingress Edge) でパケットを分類・マーキング (IP ヘッダー内の DSCP: Differentiated Services Code Point 値の設定) し、コアネットワーク内の各ルータがそのマーキングに基づいてペルホップ動作 (PHB: Per-Hop Behavior) を自律的に適用する分散制御モデルを採用している。

* **利用目的:**
  * **トラフィックの優先順位付けと帯域保証:** 音声 (VoIP)、リアルタイムビデオ、ミッションクリティカルデータなどの遅延・ジッター・パケットロスに過敏なトラフィックを識別し、最優先キュー処理 (LLQ) や帯域保証キュー処理 (CBWFQ) を提供する。
  * **輻輳時の選択的パケット破棄:** 帯域逼迫時に Best Effort 通信や Scavenger (低い優先度) 通信を選択的にドロップ、または Assured Forwarding (AF) クラス内の Drop Precedence に基づいて破棄確率を制御する。
  * **ネットワークスケーラビリティの確保:** コアノードでフロー単位の状態管理 (State Machine) を一切持たず、バヘイビアアグリゲート (Behavior Aggregate: 同一 DSCP 値を持つパケットの集合) 単位で処理を行うため、大規模エンタープライズや SP 網で極めて高い拡張性を発揮する。

* **どのような場面で利用するか:**
  * **キャンパス access 階層 (Trust Boundary):** IP Phone、ビデオ会議端末、PC からの入力をアクセススイッチで識別・検証し、DSCP マーキングの信用境界 (Trust Boundary) を確立する場合。
  * **WAN Edge / SD-WAN バウンダリ:** 限定された WAN 帯域において、ボイス・ビデオ・データ通信の多重化を行い、SLA 保証や帯域割り当てを行う場合。
  * **MPLS VPN / SP 接続:** CE-PE 間で L3 DSCP マークを維持し、MPLS EXP ビットへのマッピングや DiffServ Tunneling (Uniform / Pipe / Short Pipe Mode) を実行する場合。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **標準規格 (RFC)** | RFC 2474 (DS Field 定義), RFC 2475 (DiffServ 体系), RFC 2597 (AF PHB), RFC 3246 (EF PHB), RFC 4594 (クラス分けガイドライン) |
| **マーキングフィールド** | IPv4 Header: ToS Byte (上位 6 ビット) / IPv6 Header: Traffic Class (上位 6 ビット) ➔ 6 ビット DSCP (0〜63, 64 値) |
| **主要 PHB (Per-Hop Behavior)** | **EF** (Expedited Forwarding: DSCP 46), **AF** (Assured Forwarding: AF11〜AF43), **CS** (Class Selector: CS1〜CS7), **DF** (Default Forwarding: DSCP 0) |
| **アーキテクチャ要素** | Boundary Nodes (Ingress/Egress Edge: 分類・マーキング・ポリシング), Interior Nodes (Core: 補正・キューイング・WRED ドロップ) |
| **メリット** | ステートレスでスケーラブル、シグナリング不要、標準ベースの相互運用性、細やかな 64 段階のマーキング |
| **デメリット/制限事項** | 厳密なエンドツーエンドの帯域予約予約機能 (Admission Control) は自前で持たない (RSVP 連動が必要)、全ノードで整合した QoS ポリシー定義が不可欠 |
| **対応機種** | Cisco Catalyst 9000 シリーズ, Catalyst 8000 / ISR / ASR シリーズ, Cisco Nexus シリーズ (全 Cisco IOS/IOS XE/NX-OS デバイス) |
| **設計上の注意点** | アクセス境界で Trust Boundary を厳格化すること。PC 直打ちの DSCP 46/EF などの不正優先マークを拒否 (Re-mark) すること |

---

## 🏗 動作原理

DiffServ アーキテクチャは、「境界における深い分類・マーキング・トラフィックコンディショニング」と、「内部ノードにおける軽量な PHB 転送処理」を完全に分離することで動作する。

```
[ Client / PC ]  ---> [ IP Phone ] ---> [ Access Switch (Ingress Edge) ] ---> [ Distribution / Core Router ] ---> [ WAN Edge / SP Network ]
                              │                       │                                    │
                       (Marking CoS/DSCP)     (Trust Boundary / MQC)               (Egress Queuing / LLQ)
                                              - Re-classify & Re-mark               - PHB Application (EF/AF/DF)
                                              - Ingress Policing                    - WRED Congestion Avoidance
```

1. **Classification (分類):**
   * 入力パケットを L2 (CoS/VLAN), L3 (IP Addr, Precedence, DSCP), L4 (TCP/UDP Port), L7 (NBAR2 アプリケーション認識) を基に識別。
2. **Marking (マーキング) / Re-marking:**
   * パケットヘッダーの DS フィールド (6 ビット) に適切な DSCP コードポイント (例: EF=46, AF41=34) を書き込む。
3. **Traffic Conditioning (ポリシング・シェーピング):**
   * Token Bucket アルゴリズムを用いて規定レート (CIR) を超過する通信をポリシング (Markdown または Drop) やシェーピング (Buffer Queuing) する。
4. **Per-Hop Behavior (PHB) 処理:**
   * 内部ルータ・スイッチは DS フィールドの 6 ビットのみを参照し、定義された PHB (Priority Queuing, CBWFQ, WRED) を適用して転送する。

---

## ⚙ 動作シーケンス

DiffServ ノードにおけるパケット処理パイプラインは以下の順序で実行される：

```
[ Ingress Packet Arrival ]
            │
            ▼
┌──────────────────────────────┐
│ Classification (MQC / ACL)   │  <-- L2/L3/L4/L7 パケット解析
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ Trust Check / Re-marking     │  <-- Untrusted ポートのマークリセット または 適切な DSCP 値の書き込み
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ Ingress Policing (Token Bucket)│ <-- Conform (Green) / Exceed (Yellow) / Violate (Red) 判定
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ Switching / Routing Engine   │  <-- CEF テーブルルックアップ・転送先決定
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ Egress Queuing & Scheduling  │  <-- PHB 適用: Strict Priority Queue (LLQ) または CBWFQ への振り分け
└───────────┬──────────────────┘
            │
            ▼
┌──────────────────────────────┐
│ Congestion Avoidance (WRED)  │  <-- キュー蓄積時に AF Drop Precedence に応じた早期ランダムドロップ
└───────────┬──────────────────┘
            │
            ▼
[ Transmit to Outbound Interface ]
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
1. **DS Field 構造と IP Precedence 互換性:**
   * DS フィールド (6 ビット) の上位 3 ビット (Class Selector ビット) が IP Precedence (0〜7) と完全互換性を持つ構造の理解。
   * Bit 0-2: Class Selector / Bit 3-4: Drop Precedence (AF の場合) / Bit 5: 0 固定 (AF の場合)。
2. **PHB 仕様と DSCP バイナリ/デシマル変換:**
   * **EF (Expedited Forwarding):** Binary `101110` ➔ Decimal `46`
   * **AF (Assured Forwarding):** Binary `aaadd0` (aaa: Class 1〜4, dd: Drop Probability 1〜3)
     * AF11 (10), AF12 (12), AF13 (14)
     * AF21 (18), AF22 (20), AF23 (22)
     * AF31 (26), AF32 (28), AF33 (30)
     * AF41 (34), AF42 (36), AF43 (38)
   * **CS (Class Selector):** Binary `xxx000` (CS1=8, CS2=16, CS3=24, CS4=32, CS5=40, CS6=48, CS7=56)
   * **DF (Default Forwarding):** Binary `000000` ➔ Decimal `0`
3. **Cisco RFC 4594 準拠モデルと推奨例外:**
   * RFC 4594 では Broadcast Video = CS3, Call Signaling = CS5 を推奨しているが、Cisco では歴史的経緯により **Call Signaling = CS3 (DSCP 24)**, **Broadcast Video = CS5 (DSCP 40)** と入れ替えて採用している点の把握。
4. **Trust Boundary (信頼境界) の定義と拡張:**
   * Access Switch での Trust 設定 (`qos trust dscp`, `qos trust cos`, `trust device cisco-phone`)。
   * PC からの音声なりすまし (DSCP 46 打込み) に対する Conditional Trust の動作。
5. **MQC CLI 構文における `set dscp` vs `set ip dscp`:**
   * `set dscp <value>`: IPv4 および IPv6 パケットの双方に適用される推奨コマンド。
   * `set ip dscp <value>`: IPv4 限定。CCIE ラボでは Dual-Stack 環境が前提となるため `set dscp` を使用すること。

### ラボ試験で設定させられそうな内容
* アプリケーション (VoIP, TelePresence, Critical Data, Scavenger) ごとの MQC 分類と RFC 4594 準拠 DSCP マーキング。
* スイッチアクセスポートでの Conditional Trust (IP Phone 接続時の CoS/DSCP 信頼と PC ポートの 0 リセット) 構成。
* L2 CoS ➔ L3 DSCP マッピング表 (`qos map cos-dscp` / `table-map`) の手動カスタム変調。
* Tunnel / IPsec 環境における ToS/DSCP のインナー・アウター自動継承および `qos pre-classify` の定義。

### よくある設定ミス・落とし穴
* `class-map match-all` と `class-map match-any` の指定ミス (複数 `match` 条件記載時)。
* `set ip dscp` を使用してしまい、IPv6 通信の DSCP がマークされない。
* Access ポートで `qos trust cos` を指定しているにもかかわらず、CoS 5 ➔ DSCP 40 (デフォルト: CoS * 8) のままとなり、EF (DSCP 46) に変換されないトラブル。

---


## 🛠 設定方法

DiffServ アーキテクチャを実装するための基本的な MQC (Modular QoS CLI) コンフィグレーション手順。

### 1. MQC による基本 Classification ＆ Marking 構成

```bash
! --- 1. Class-Map によるトラフィック分類 ---
class-map match-any CM_VOICE
 match dscp ef
 match protocol rtp audio

class-map match-any CM_VIDEO
 match dscp af41 cs4
 match protocol telepresence

class-map match-any CM_CRITICAL_DATA
 match protocol citrix
 match protocol sap

class-map match-any CM_SCAVENGER
 match protocol bittorrent
 match protocol youtube

! --- 2. Policy-Map による DiffServ マーキング ＆ ポリシング ---
policy-map PM_INGRESS_MARKING
 class CM_VOICE
  set dscp ef
  
 class CM_VIDEO
  set dscp af41
  
 class CM_CRITICAL_DATA
  set dscp af21
  
 class CM_SCAVENGER
  set dscp cs1
  police 1000000 31250 62500 conform-action transmit exceed-action drop violate-action drop

 class class-default
  set dscp default

! --- 3. インターフェイスへの適用 (Ingress Trust / Marking Edge) ---
interface GigabitEthernet1/0/1
 description Access_Port_To_Host
 service-policy input PM_INGRESS_MARKING
```

### 2. Catalyst スイッチにおける Trust Boundary ＆ Map カスタマイズ

```bash
! --- 1. L2 CoS から L3 DSCP へのカスタムマッピング設定 ---
! CoS 5 を DSCP 46 (EF) へマッピング (デフォルト CoS 5 ➔ DSCP 40 の修正)
qos map cos to dscp 0 8 16 24 32 46 48 56

! --- 2. アクセスポートでの Trust 設定 (Cisco IP Phone 接続用 Conditional Trust) ---
interface GigabitEthernet1/0/5
 description Connected_to_Cisco_IP_Phone
 switchport access vlan 10
 switchport voice vlan 100
 qos trust device cisco-phone
 qos trust dscp
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 概要・注目すべきポイント |
| :--- | :--- | :--- |
| **QoS ポリシー統計確認** | `show policy-map interface <Interface>` | マッチしたパケット数/バイト数、`set dscp` アクションの実行回数、ドロップ数をリアルタイム確認 |
| **Class-Map 定義確認** | `show class-map` | 定義されているクラスマップのマッチ条件 (DSCP, ACL, Protocol) 一覧を表示 |
| **Policy-Map 構成確認** | `show policy-map` | ポリシーマップ内の階層構造、クラスごとの設定アクション (Marking, Policing) を表示 |
| **CoS-DSCP マッピング確認** | `show qos map cos to dscp` | スイッチ上の L2 CoS から L3 DSCP への変換テーブル設定値を表示 |
| **DSCP-CoS マッピング確認** | `show qos map dscp to cos` | L3 DSCP から L2 CoS へのバックワード変換テーブルを表示 |
| **インターフェイス QoS 状態** | `show qos interface <Interface>` | インターフェイスの Trust 状態 (Trusted / Untrusted / Conditional Trust) を確認 |
| **NBAR2 アプリケーション統計** | `show ip nbar protocol-discovery` | NBAR2 エンジンによって分類されたプロトコルごとのリアルタイム通信量を表示 |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **PC からの DSCP 46 優先パケットがそのまま通過し優先される** | スイッチポートの Trust Boundary が未設定で `qos trust dscp` 状態になっているか、Conditional Trust が正しく機能していない | `show qos interface Gi1/0/1` | Untrusted ポートへ変更するか、Ingress Policy で `set dscp default` を適用し再リセットする |
| **IP Phone からの CoS 5 パケットが DSCP 40 にマークダウンされる** | CoS-to-DSCP マッピングのデフォルト設定 (CoS 5 ➔ DSCP 40) が変更されていない | `show qos map cos to dscp` | `qos map cos to dscp 0 8 16 24 32 46 48 56` を設定し、CoS 5 ➔ DSCP 46 (EF) に修正する |
| **IPv6 通信の QoS マーキングが機能しない** | MQC 内で `set ip dscp` を使用しているため IPv4 パケットのみに適用されている | `show policy-map interface` | `set ip dscp` をプロトコル非依存の `set dscp` コマンドに差し替える |
| **IPsec トンネル通過後に QoS キューイングが正しく動作しない** | IPsec 暗号化により L3/L4 ヘッダーがマスクされ、Egress WAN インターフェイスで分類できない | `show policy-map interface` | トンネルインターフェイスに `qos pre-classify` を設定し、暗号化前のヘッダーを基に MQC 評価させる |
| **NBAR2 マーキングが一部の高度なアプリ通信に適用されない** | NBAR2 プロトコルパックが古いか、暗号化 (HTTPS/TLS) トラフィックの SNI 識別ができていない | `show ip nbar version` | 最新の NBAR2 プロトコルパック (.pack) をロードするか、Host/SNI ベースの識別ルールを追加する |

---

## ⚠ 制限事項

* **ハードウェア TCAM 制限:**
  * アクセススイッチやルータの HW ASIC では、同時定義可能な Class-Map 数や TCAM エントリ数に上限がある。
* **L2 / L3 トランスレーション制限:**
  * L2 メディア (Ethernet 802.1Q CoS: 3 ビット) は 8 段階の識別しか持たないため、L3 DSCP (6 ビット: 64 段階) から L2 CoS へのマッピング時に情報が圧縮 (Class Collapsing) される。
* **トンネルヘッダーの自動コピー動作:**
  * GRE や IPsec トンネル作成時、デフォルトでインナー IP の ToS/DSCP バイトがアウター IP ヘッダーにコピーされるが、MPLS VPN 環境では PE の DiffServ Tunneling モード (Uniform / Pipe / Short Pipe) によりアウターの取り扱いが変わる。

---

## 🔄 他技術との関連

* **MPLS / MPLS VPN (DiffServ Tunneling):**
  * **Uniform Mode:** Ingress PE で IP DSCP ➔ MPLS EXP へコピー。P ルータでの EXP 変更が Egress PE で IP DSCP に伝播する。
  * **Pipe Mode:** SP の MPLS EXP 変更を顧客 IP DSCP に伝播させない。PE-CE 間 Egress 制御は SP の EXP を基準とする。
  * **Short Pipe Mode:** SP の MPLS EXP 変更を顧客 IP DSCP に伝播させず、PE-CE 間 Egress 制御は顧客の IP DSCP を基準とする。
* **WRED (Weighted Random Early Detection):**
  * AF クラス (AF11/12/13, AF21/22/23等) の Drop Precedence (1=Low, 2=Medium, 3=High) と連動し、Drop Precedence が高いパケットを優先的に早期ランダム破棄して TCP グローバル同期を防止。
* **LLQ / CBWFQ (Congestion Management):**
  * DSCP EF (46) を Strict Priority Queue (LLQ) にアサインし、AF / CS / DF を個別バンド幅キュー (CBWFQ) にアサインしてスケジューリングする。
* **Cisco TrustSec / SGT (Scalable Group Tag):**
  * 役割ベースのアクセス制御 (SGT) と QoS DSCP マーキングを組み合わせ、SGT 単位での QoS ポリシー適用や帯域制御を行う。

---

## 🧩 比較表

### 1. QoS モデル比較 (DiffServ vs IntServ vs Best Effort)

| 比較項目 | Best Effort (BE) | Integrated Services (IntServ) | Differentiated Services (DiffServ) |
| :--- | :--- | :--- | :--- |
| **アーキテクチャ** | QoS 無効 (デフォルト) | シグナリングベース (RSVP) | クラスベース (DS Field / DSCP) |
| **スケーラビリティ** | 極めて高い | 低い (コアノードでフロー単位の状態保持が必要) | **非常に高い** (ステートレス、アグリゲート制御) |
| **リソース予約** | なし | エンドツーエンドの明示的帯域予約 | クラスごとの Per-Hop Behavior (PHB) 優先制御 |
| **帯域保証** | なし | 厳格な定量的保証 (Hard Guarantee) | 統計的保証 (Soft Guarantee) |
| **主な用途** | 一般 Web、ファイル転送 | 小規模リアルタイム通信、RSVP-TE | **エンタープライズ全般、SP 網の標準モデル** |

### 2. L2/L3 QoS マーク比較 (CoS vs IP Precedence vs DSCP)

| 比較項目 | L2 CoS (802.1p) | L3 IP Precedence (IPP) | L3 DSCP (DiffServ Code Point) |
| :--- | :--- | :--- | :--- |
| **ヘッダー位置** | 802.1Q Tag (PRI フィールド) | IPv4 ToS / IPv6 Traffic Class (上位 3 ビット) | IPv4 ToS / IPv6 Traffic Class (上位 6 ビット) |
| **ビット長 / 段階数**| 3 ビット (0〜7 / 8 段階) | 3 ビット (0〜7 / 8 段階) | **6 ビット (0〜63 / 64 段階)** |
| **透過性** | L2 ルーティング越えで消失 | **エンドツーエンドで保持** | **エンドツーエンドで保持** |
| **ドロップ優先度** | なし | なし | **あり (AFxy 内で Low/Med/High 指定可能)** |
| **標準規格** | IEEE 802.1Q / 802.1p | RFC 791 | RFC 2474 / RFC 2597 / RFC 3246 |

### 3. 主要 PHB クラス比較 (EF vs AF vs CS vs DF)

| PHB 名 | DSCP 値 (デシマル) | 二進数表記 | 標準用途 / 典型的なアプリケーション | スケジューリング / キュー処理 |
| :--- | :--- | :--- | :--- | :--- |
| **EF (Expedited Forwarding)** | **46** | `101110` | 音声メディア (VoIP G.711/G.729) | Strict Priority Queue (LLQ) |
| **AF4x (Assured Forwarding 4)** | **34, 36, 38** | `100xx0` | リアルタイムビデオ・Interactive Video | Bandwidth Queue + WRED |
| **AF3x (Assured Forwarding 3)** | **26, 28, 30** | `011xx0` | ストリーミングビデオ | Bandwidth Queue + WRED |
| **AF2x (Assured Forwarding 2)** | **18, 20, 22** | `010xx0` | トランザクションデータ (ERP, CRM) | Bandwidth Queue + WRED |
| **AF1x (Assured Forwarding 1)** | **10, 12, 14** | `001xx0` | バルクデータ (FTP, Email) | Bandwidth Queue + WRED |
| **CS6 / CS7 (Class Selector)** | **48 / 56** | `110000 / 111000` | ネットワーク制御 (BGP, OSPF, EIGRP, HSRP) | Bandwidth Queue (High Priority) |
| **CS3** | **24** | `011000` | シグナリング (SIP, SCCP) - Cisco 推奨 | Bandwidth Queue |
| **CS1 (Scavenger)** | **8** | `001000` | 低優先度・バックグラウンド (P2P, YouTube) | Minimum Bandwidth Queue |
| **DF (Default Forwarding)** | **0** | `000000` | ベストエフォート (他すべて) | Default Queue |

---

## 💡 ベストプラクティス

1. **トラフィック識別・マーキングはネットワーク最境界 (Trust Boundary) で実施:**
   * 入力直後のアクセススイッチまたは IP Phone/WLC で正しく分類・マークし、ネットワークコアでの重いディープパケットインスペクション (NBAR2) を回避する。
2. **PC / 未知のエンドポイントからの DSCP マークは原則非信用 (Untrusted) とする:**
   * ユーザー PC から送信されたパケットの DSCP 値はアクセスポートで `set dscp default` (DSCP 0) にリセットし、特定の承認済みプロトコルのみ再アサインする。
3. **RFC 4594 準拠モデルの採用:**
   * 12 クラス、8 クラス、または 4 クラスのモデルを組織規模に応じて選択し、全拠点で一貫した DSCP マッピングポリシーを展開する。
4. **LLQ (Strict Priority Queue) の帯域制限:**
   * 音声・リアルタイム通信用優先キュー (LLQ) には必ず帯域上限 (例: リンク帯域の 33% 以下) をポリシング定義し、優先トラフィックの爆発による他クラスの完全餓死 (Starvation) を防ぐ。
5. **WRED の設定:**
   * AF クラスおよび Default クラスには DSCP ベースの WRED を有効化し、TCP 通信のグローバル同期現象を回避する。

---


## 📝 ラボ学習・設定サンプル例

CCIE EI v1.1 ラボ試験レベルの実践的な DiffServ QoS 設定演習 10 選。

---

### ラボ 1: DiffServ 基本マーキング (DSCP EF, AF41, CS3) ＋ MQC インバウンド適用

* **問題:**
  ルータ R1 の GigabitEthernet0/0/1 において、入力される各種トラフィックを識別し、RFC 4594 準拠の DiffServ マーク (DSCP) を付与せよ。
* **要件:**
  * 音声メディア (UDP 16384-32767) ➔ **DSCP EF (46)**
  * ビデオ会議 (TCP 5000〜5009) ➔ **DSCP AF41 (34)**
  * シグナリング (TCP 5060, 5061) ➔ **DSCP CS3 (24)**
  * MQC を作成し、Gi0/0/1 の Ingress に適用すること。

* **設定例:**
```bash
! 1. トラフィック識別用 ACL の定義
ip access-list extended ACL_VOICE_MEDIA
 permit udp any any range 16384 32767

ip access-list extended ACL_VIDEO_CONF
 permit tcp any any range 5000 5009

ip access-list extended ACL_SIGNALING
 permit tcp any any eq 5060
 permit tcp any any eq 5061

! 2. MQC Class-Map の定義
class-map match-all CM_VOICE_MEDIA
 match access-group name ACL_VOICE_MEDIA

class-map match-all CM_VIDEO_CONF
 match access-group name ACL_VIDEO_CONF

class-map match-all CM_SIGNALING
 match access-group name ACL_SIGNALING

! 3. MQC Policy-Map による DSCP マーキング定義
policy-map PM_INGRESS_CLASSIFY
 class CM_VOICE_MEDIA
  set dscp ef
 class CM_VIDEO_CONF
  set dscp af41
 class CM_SIGNALING
  set dscp cs3
 class class-default
  set dscp default

! 4. インターフェイスへの適用
interface GigabitEthernet0/0/1
 description Ingress_Traffic_From_Branch
 service-policy input PM_INGRESS_CLASSIFY
```

* **検証方法:**
  * テスターまたは対向ノードから対象ポートのパケットを送信する。
  * `show policy-map interface GigabitEthernet0/0/1` を実行し、各 Class-Map の `packets` カウンタが増加し、`set dscp` が正しく実行されていることを確認する。

---

### ラボ 2: IP Precedence から DSCP への変換 ＆ 互換マーキング構成

* **問題:**
  レガシー機器から IP Precedence 5 (Critical) および IP Precedence 3 (Flash) でマークされて送られてくるパケットを、最新の DiffServ 規格 (DSCP EF および DSCP CS3) へ明示的に書き換えて再送信せよ。
* **要件:**
  * IP Precedence 5 のパケット ➔ **DSCP EF (46)** へ Re-mark
  * IP Precedence 3 のパケット ➔ **DSCP CS3 (24)** へ Re-mark
  * IPv4/IPv6 両対応のコマンドを使用すること。

* **設定例:**
```bash
! 1. IP Precedence に基づく Class-Map 定義
class-map match-all CM_IPP_5
 match precedence 5

class-map match-all CM_IPP_3
 match precedence 3

! 2. DSCP への変換 Re-marking Policy 定義
policy-map PM_REMARK_IPP_TO_DSCP
 class CM_IPP_5
  set dscp ef
 class CM_IPP_3
  set dscp cs3

! 3. インターフェイス適用
interface GigabitEthernet0/0/2
 description Legacy_Network_Ingress
 service-policy input PM_REMARK_IPP_TO_DSCP
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/2` を確認。
  * IP Precedence 5 で受信したパケットが `set dscp ef` にヒットし、キャプチャ画面で ToS Byte が `0xB8` (DSCP 46) に変更されていることを検証する。

---

### ラボ 3: L2 CoS 5 から L3 DSCP 46 (EF) への手動マッピング補正と Trust 構成

* **問題:**
  Catalyst スイッチ SW1 において、IP Phone から受信する L2 CoS 5 のフレームを、スイッチ標準のデフォルトマッピング (CoS 5 ➔ DSCP 40) ではなく、RFC 3246 準拠の **DSCP 46 (EF)** へ変換するようグローバルマッピングテーブルを修正せよ。
* **要件:**
  * CoS 5 ➔ DSCP 46 (EF) への変更。
  * 該当インターフェイス GigabitEthernet1/0/10 で CoS 信頼 (`qos trust cos`) を有効化すること。

* **設定例:**
```bash
! 1. スイッチの CoS-to-DSCP グローバルマッピングテーブルを修正
! (デフォルト: 0 8 16 24 32 40 48 56 ➔ CoS 5 を 46 へ変更)
qos map cos to dscp 0 8 16 24 32 46 48 56

! 2. インターフェイスでの CoS Trust 設定
interface GigabitEthernet1/0/10
 description Access_Switch_Port_IP_Phone
 switchport mode access
 switchport access vlan 10
 qos trust cos
```

* **検証方法:**
  * `show qos map cos to dscp` を実行し、`cos: 5` の項目の `dscp` 値が `46` に更新されていることを確認。
  * `show qos interface GigabitEthernet1/0/10` で Trust 状態が `cos` になっていることを確認。

---

### ラボ 4: Class Selector (CS1〜CS7) によるネットワーク制御プロトコル保護構成

* **問題:**
  ルータ R1 にて、自装置から発信されるルーティングプロトコル通信 (OSPF, BGP) およびネットワーク管理通信 (SSH, SNMP) に対し、Class Selector (CS6, CS2) の DSCP マークを確実にアサインして保護せよ。
* **要件:**
  * OSPF / BGP 通信 ➔ **DSCP CS6 (48)**
  * SSH (TCP 22) / SNMP (UDP 161) ➔ **DSCP CS2 (16)**
  * MQC Policy を Egress インターフェイス Gi0/0/0 に適用すること。

* **設定例:**
```bash
! 1. トラフィック識別
class-map match-any CM_ROUTING_CONTROL
 match protocol ospf
 match protocol bgp

class-map match-any CM_MGMT_OAM
 match protocol ssh
 match protocol snmp

! 2. Policy-Map 定義
policy-map PM_CONTROL_MARKING
 class CM_ROUTING_CONTROL
  set dscp cs6
 class CM_MGMT_OAM
  set dscp cs2

! 3. Egress インターフェイス適用
interface GigabitEthernet0/0/0
 description WAN_Egress_Link
 service-policy output PM_CONTROL_MARKING
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/0` で、OSPF/BGP パケット送出時に `CM_ROUTING_CONTROL` クラスのパケットカウンタが増加していることを確認。

---

### ラボ 5: Assured Forwarding (AF21, AF22, AF23) Markdown ポリサー (1r3c / RFC 2697) 構成

* **問題:**
  ルータ R1 の Gi0/0/1 において、ERP 業務データ (DSCP AF21) に対し、帯域制限 2Mbps の Single Rate Three Color Marker (1r3c) ポリサーを構成せよ。
* **要件:**
  * CIR: 2Mbps, Normal Burst (Bc): 62,500 Bytes, Excess Burst (Be): 125,000 Bytes
  * Conform (Green) ➔ そのまま送信 (`transmit` / **AF21**)
  * Exceed (Yellow) ➔ マークダウンして送信 (`set-dscp-transmit af22`)
  * Violate (Red) ➔ マークダウンして送信 (`set-dscp-transmit af23`)

* **設定例:**
```bash
! 1. Class-Map 定義
class-map match-all CM_ERP_DATA
 match dscp af21

! 2. 1r3c Markdown Policier を含む Policy-Map 定義
policy-map PM_AF_MARKDOWN_POLICER
 class CM_ERP_DATA
  police cir 2000000 bc 62500 be 125000 conform-action transmit exceed-action set-dscp-transmit af22 violate-action set-dscp-transmit af23

! 3. インターフェイス適用
interface GigabitEthernet0/0/1
 service-policy input PM_AF_MARKDOWN_POLICER
```

* **検証方法:**
  * テスターから 3Mbps の AF21 通信を送出する。
  * `show policy-map interface GigabitEthernet0/0/1` で `conformed`, `exceeded`, `violated` パケット数と、AF22 / AF23 への Markdown アクションの実行結果を確認。

---

### ラボ 6: Expedited Forwarding (EF) ＋ LLQ (Low Latency Queuing) 厳格優先キュー構成

* **問題:**
  WAN エッジルータ R1 の出力量インターフェイス Gi0/0/0 において、DSCP EF (46) マークされた音声トラフィックに最優先キュー (LLQ) を割り当て、帯域を 512kbps に制限して他クラスの餓死を防御せよ。
* **要件:**
  * DSCP EF (46) ➔ `priority 512` (Strict Priority)
  * DSCP AF41 (34) ➔ `bandwidth 2048` (2Mbps 保証)
  * Default ➔ `bandwidth 1024` (1Mbps 保証)

* **設定例:**
```bash
! 1. Class-Map 定義
class-map match-all CM_VOICE_EF
 match dscp ef

class-map match-all CM_VIDEO_AF41
 match dscp af41

! 2. LLQ / CBWFQ Queuing Policy 定義
policy-map PM_WAN_EGRESS_QUEUING
 class CM_VOICE_EF
  priority 512
 class CM_VIDEO_AF41
  bandwidth 2048
 class class-default
  bandwidth 1024

! 3. インターフェイス適用
interface GigabitEthernet0/0/0
 service-policy output PM_WAN_EGRESS_QUEUING
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/0` で `Priority Queue` の定義と、`Strict Priority` 内でのパケット送信・ドロップ統計を確認。

---

### ラボ 7: Access Switch での Trust Boundary ＆ Conditional Trust 構成

* **問題:**
  スイッチ SW1 のアクセスポート Gi1/0/15 において、Cisco IP Phone 接続時は CoS/DSCP を信頼し、IP Phone 背面の PC ポートから送信されるデータパケットの DSCP マークは無条件で 0 (Default) にリセットせよ。
* **要件:**
  * CDP による Cisco IP Phone の自動検知 (`qos trust device cisco-phone`)。
  * IP Phone 接続時は Trust DSCP。
  * 非検知時 (PC 直付け時) は Untrusted とし DSCP 0 に書き換えること。

* **設定例:**
```bash
! 1. PC トラフィック用 Re-mark Policy
policy-map PM_UNTRUST_PC
 class class-default
  set dscp default

! 2. アクセスポート設定
interface GigabitEthernet1/0/15
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 100
 qos trust device cisco-phone
 qos trust dscp
 service-policy input PM_UNTRUST_PC
```

* **検証方法:**
  * IP Phone 接続時: `show qos interface GigabitEthernet1/0/15` で `Trust State: trusted` に変化し、音声 DSCP 46 が維持されることを確認。
  * PC 直付け時: CDP 検知が切れ `Trust State: untrusted` となり、`PM_UNTRUST_PC` により DSCP 0 に書き換えられることを確認。

---

### ラbo 8: DSCP Mutation (入力 DSCP のテーブル変換・書き換え) 構成

* **問題:**
  スイッチ SW1 において、他社ネットワークから入力される非標準の DSCP 値 (例: ビデオ通信が DSCP 32/CS4 で送られてくる) を、自社標準の DSCP AF41 (34) へハードウェアテーブル変換 (DSCP Mutation) させて入力せよ。
* **要件:**
  * 入力 DSCP 32 ➔ 出力/内部 DSCP 34 (AF41) へ変換。
  * `dscp-mutation` テーブルを定義し、Gi1/0/20 に適用すること。

* **設定例:**
```bash
! 1. DSCP Mutation Table の定義
qos map dscp-mutation MUTATE_VIDEO 32 to 34

! 2. インターフェイスへの適用
interface GigabitEthernet1/0/20
 qos trust dscp mutation MUTATE_VIDEO
```

* **検証方法:**
  * `show qos map dscp-mutation MUTATE_VIDEO` を実行し、`dscp: 32` の項目が `34` へマッピングされていることを確認。

---

### ラボ 9: IPsec / Tunnel 構成での ToS / DSCP 保持と `qos pre-classify` 構成

* **問題:**
  ルータ R1 と R2 間の GRE over IPsec トンネルにおいて、元のパケットの DSCP マークがアウター IP ヘッダーへ正常に継承されるよう確認し、暗号化前の IP ヘッダー情報を基に出力 QoS ポリシーを適用せよ。
* **要件:**
  * Tunnel1 インターフェイスで `qos pre-classify` を有効化。
  * 物理 WAN インターフェイス Gi0/0/0 に MQC Egress Policy を適用すること。

* **設定例:**
```bash
! 1. トンネルインターフェイスでの Pre-classification 有効化
interface Tunnel1
 ip address 172.16.1.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 203.0.113.2
 qos pre-classify

! 2. 物理 WAN ポートでの QoS Egress Queuing ポリシー適用
interface GigabitEthernet0/0/0
 service-policy output PM_WAN_EGRESS_QUEUING
```

* **検証方法:**
  * トンネル経由で DSCP EF の音声パケットを送出し、`show policy-map interface GigabitEthernet0/0/0` にて暗号化パケットが `CM_VOICE_EF` クラスに正しく分類・優先キュー処理されていることを確認。

---

### ラボ 10: NBAR2 (L7 Deep Packet Inspection) によるアプリ識別と DSCP マーキング構成

* **問題:**
  ルータ R1 において、ポート番号だけでは特定できない L7 アプリケーション通信 (WebEx, Citrix) を NBAR2 でディープパケットインスペクション識別し、適切な DiffServ マークをアサインせよ。
* **要件:**
  * WebEx ➔ **DSCP AF41 (34)**
  * Citrix ➔ **DSCP AF21 (18)**
  * NBAR2 プロトコルディスカバリを有効化すること。

* **設定例:**
```bash
! 1. NBAR2 アプリケーション認識 Class-Map 定義
class-map match-all CM_NBAR_WEBEX
 match protocol webex-media

class-map match-all CM_NBAR_CITRIX
 match protocol citrix

! 2. マーキング Policy-Map 定義
policy-map PM_NBAR_MARKING
 class CM_NBAR_WEBEX
  set dscp af41
 class CM_NBAR_CITRIX
  set dscp af21
 class class-default
  set dscp default

! 3. インターフェイス適用 ＆ Protocol Discovery 有効化
interface GigabitEthernet0/0/1
 ip nbar protocol-discovery
 service-policy input PM_NBAR_MARKING
```

* **検証方法:**
  * `show ip nbar protocol-discovery interface GigabitEthernet0/0/1` で WebEx / Citrix の通信量がリアルタイム検出されているか確認。
  * `show policy-map interface GigabitEthernet0/0/1` で該当クラスの `set dscp` カウンタが増加していることを検証。

---


## ❓ 想定試験問題

CCIE EI v1.1 試験（筆記・ラボ）を想定した実践問題と詳細な技術解説。

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:**  
ネットワーク管理者 A 氏は、ルータ R1 の入力インターフェイス Gi0/0/1 に以下の MQC ポリシーを適用した。しかし、IPv6 の音声端末から送信される DSCP EF パケットのマークがすべて 0 (Default) にリセットされてしまう問題が発生した。

```bash
class-map match-all CM_VOICE
 match ip dscp ef

policy-map PM_MARK
 class CM_VOICE
  set ip dscp ef

interface GigabitEthernet0/0/1
 service-policy input PM_MARK
```

**設問:**  
この設定において IPv6 音声パケットがマッチせずマークリセットされた直接的な技術的原因と、修正すべき MQC コンフィグを答えよ。

* **解答・解説:**
  * **原因:** Class-Map 内で match ip dscp コマンドを使用しており、Policy-Map 内で set ip dscp を使用しているため。
  * **修正コンフィグ:**
```bash
class-map match-all CM_VOICE
 match dscp ef

policy-map PM_MARK
 class CM_VOICE
  set dscp ef
```

### 問 2 (Design / 信頼境界)
**シナリオ:**  
キャンパスアクセススイッチ SW1 配下に、ユーザー PC と Cisco IP Phone が接続されている。PC ユーザーが NIC の高度な設定から自発的にパケットの DSCP 値を 46 (EF) に設定し、優先処理を受けようとしている。

**設問:**  
このような未承認マークを防止しつつ、Cisco IP Phone からの正規の音声パケット (DSCP 46) のみを信用して通過させるための最小限のインターフェイスコンフィグを記述せよ。

* **解答・解説:**
  * **解答コンフィグ:**
```bash
interface GigabitEthernet1/0/10
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 100
 qos trust device cisco-phone
 qos trust dscp
```
  * **解説:** qos trust device cisco-phone (Conditional Trust) を設定することで、CDP パケットにより Cisco IP Phone が接続されていることをスイッチが識別した時のみポートが Trusted 状態となる。

### 問 3 (MPLS VPN / Tunneling Mode)
**シナリオ:**  
SP (サービスプロバイダ) 網を経由して企業拠点を MPLS L3VPN 接続している。企業側 (CE) は独自の DiffServ 体系 (DSCP AF31, AF21 等) を運用しており、SP 網内でラベル (MPLS EXP) の書き換えが発生しても、対向拠点の CE に到着した際には元の IP DSCP マークが 100% 保持されている必要がある。

**設問:**  
RFC 3270 で定義されている 3 つの MPLS DiffServ Tunneling モード (Uniform, Pipe, Short Pipe) のうち、この要件を満たし、かつ SP 側が PE-CE 間 Egress 制御を自社の EXP 基準で行うのに最も適したモードとその動作概要を説明せよ。

* **解答・解説:**
  * **推奨モード:** **Pipe Mode** (または Short Pipe Mode)
  * **動作概要:** Pipe Mode では、PE へのインポジション時に顧客の IP DSCP 値をアウターラベルの MPLS EXP にコピー (または独立設定) するが、SP 網内で MPLS EXP ビットがポリサー等で変更されても、インナー IP ヘッダーの DSCP バイトには一切影響を与えない (透明性保持)。

### 問 4 (Troubleshooting / Policing)
**シナリオ:**  
WAN ルータ R1 の Egress ポートにおいて、ビデオ会議トラフィック (DSCP AF41) に対し police 2000000 (2Mbps) を設定したところ、実トラフィックが 1.5Mbps 程度であるにもかかわらず大量のパケットが Exceed 判定されてドロップする現象が発生した。

**設問:**  
この現象が発生した技術的原因（Token Bucket パラメータの観点）と、修正コマンドを述べよ。

* **解答・解説:**
  * **原因:** police コマンドで Burst Size (Normal Burst: Bc) を明示指定しなかったため、Cisco IOS のデフォルトの短すぎる Bc 値が適用され、ビデオ通信特有のバースト性を吸収できず Exceed 判定されたため。
  * **修正コマンド:** バーストサイズ (Bc) を明示的に拡大設定する。
```bash
policy-map PM_WAN_OUT
 class CM_VIDEO
  police cir 2000000 bc 62500 conform-action transmit exceed-action drop
```

### 問 5 (実装 / WRED)
**シナリオ:**  
ルータ R1 の Egress キューにおいて、Assured Forwarding (AF21, AF22, AF23) クラスの通信に対し、帯域逼迫時の早期破棄制御 (WRED) を組み込みたい。

**設問:**  
AF21 (Low Drop), AF22 (Med Drop), AF23 (High Drop) のそれぞれの Drop Precedence に応じた WRED 閾値設定のベストプラクティスに基づき、class CM_TRANSACTION_DATA 配下に設定すべき WRED コマンド群を記述せよ。

* **解答・解説:**
  * **解答コンフィグ:**
```bash
policy-map PM_EGRESS_QOS
 class CM_TRANSACTION_DATA
  bandwidth percent 30
  random-detect dscp-prec-based
  random-detect dscp af21 32 40 10
  random-detect dscp af22 24 40 10
  random-detect dscp af23 16 40 10
```

## 🔗 参考リソース

* **Cisco Live セッションスライド・動画:**
  * BRKCRS-2501 - Enterprise Campus QoS Design Simplified
  * BRKENT-2731 - What QoS can do for your network with Catalyst 8000 and IOS XE
  * BRKSEC-3052 - Enterprise Security and SGT Segmentation

* **Configuration Guide / Command Reference:**
  * Cisco IOS XE 17.x Quality of Service Configuration Guide
  * Cisco Quality of Service Command Reference
  * Differentiated Services Code Point (DSCP) and Precedence Values Overview

* **IETF RFC 規格文書:**
  * RFC 2474 - Definition of the Differentiated Services Field (DS Field) in IPv4 and IPv6 Headers
  * RFC 2475 - An Architecture for Differentiated Services
  * RFC 2597 - Assured Forwarding PHB Group
  * RFC 3246 - An Expedited Forwarding PHB (Per-Hop Behavior)
  * RFC 4594 - Configuration Guidelines for DiffServ Service Classes

* **Technical Notes & White Papers:**
  * Cisco Enterprise QoS Baseline Design Technical Overview
  * Implementing Quality of Service Policies with DSCP

---

## 📝 補足（Notes）

### 1. DiffServ DSCP 値クイック参照マップ

```text
+-------------------+--------------------+--------------------+--------------------+--------------------+
| Drop Precedence   | Class 1 (AF1x)     | Class 2 (AF2x)     | Class 3 (AF3x)     | Class 4 (AF4x)     |
+-------------------+--------------------+--------------------+--------------------+--------------------+
| Low Drop (1)      | AF11 = 10 (001010) | AF21 = 18 (010010) | AF31 = 26 (011010) | AF41 = 34 (100010) |
| Medium Drop (2)   | AF12 = 12 (001100) | AF22 = 20 (010100) | AF32 = 28 (011100) | AF42 = 36 (100100) |
| High Drop (3)     | AF13 = 14 (001110) | AF23 = 22 (010110) | AF33 = 30 (011110) | AF43 = 38 (100110) |
+-------------------+--------------------+--------------------+--------------------+--------------------+
| Expedited Forw.   | EF   = 46 (101110) |                    |                    |                    |
| Default Forw.     | DF   = 0  (000000) |                    |                    |                    |
+-------------------+--------------------+--------------------+--------------------+--------------------+
```

### 2. DSCP 10 進数からバイナリへの高速計算テクニック
* AF クラス表記 **AFxy** から DSCP デシマル値を暗算する方法：
  * **公式:** `DSCP Decimal = (8 * x) + (2 * y)`
  * **例 1 (AF41):** `(8 * 4) + (2 * 1) = 32 + 2 = 34`
  * **例 2 (AF22):** `(8 * 2) + (2 * 2) = 16 + 4 = 20`
  * **例 3 (AF33):** `(8 * 3) + (2 * 3) = 24 + 6 = 30`
  * CCIEEI ラボ試験中に電卓を使わず数秒で計算できる必須テクニック！

---


## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731) - 最新のIOS-XEにおけるQoS実装の全容。
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501) - エンタープライズキャンパスでのDiffServ設計ガイド。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE試験におけるQoSの価値と対策。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Quality of Service Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos/configuration/xe-17/qos-xe-17-book.html)。
*   [**Configuring NBAR based Classification**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)。

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoSIntro.html)。
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)。

---

## 📝 補足

- この学習メモは、CCIE EI試験におけるQoSの「論理（DiffServ）」と「実装（MQC）」を統合しています。ラボ試験では、**`show policy-map interface`** の出力を読み解き、設定したしきい値に対してトラフィックがどのように分類・処理されているかを正確に判断するスキルが合格の決め手となります。


