---
layout: default
title: 4.4.h-MQC
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 8
---

# 4.4.h End-to-end Layer 3 QoS using MQC

CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における、エンタープライズネットワーク全体の品質保証設計・実装の核心技術である **`4.4.h End-to-end Layer 3 QoS using MQC`**（Modular QoS CLI を用いたエンドツーエンド Layer 3 QoS アーキテクチャ）に関する詳細な構造化学習メモ。

---

## 📘 概要

エンドツーエンド Layer 3 QoS using MQC とは、アクセス層からディストリビューション/コア層、WAN Edge、サービスプロバイダ網、支社（Branch）に至るネットワークパス全体において、MQC（Modular QoS CLI：Class-Map, Policy-Map, Service-Policy）を用いて一貫したトラフィックの「分類 (Classification)」「マーキング (Marking)」「ポリシング (Policing)」「シェーピング (Shaping)」「キューイング (Queuing)」「輻輳回避 (Congestion Avoidance)」を統合制御するアーキテクチャである。

単一の機器内で QoS を閉じるのではなく、パケットがネットワークに入り込む「信頼境界 (Trust Boundary)」で適切な DSCP マークを付与・維持し、トンネルカプセル化（GRE, IPsec DMVPN, CAPWAP, MPLS）や異種メディア（L2 CoS ⇄ L3 DSCP ⇄ MPLS EXP）の境界でヘッダー情報を損失することなく維持・伝送することで、音声（Voice）、リアルタイムビデオ、ミッションクリティカルデータなどの重要トラフィックに対してエンドツーエンドでの帯域保証と低遅延・低ジッターを提供する。

* **機能概要:** ネットワーク全域でのトラフィッククラスの一貫した定義、信頼境界の確立、カプセル化時の QoS プレフィックス/DSCP 保持、WAN 境界での HQoS（Hierarchical QoS）制御。
* **利用目的:** LAN/WAN/VPN/Wireless の全区間で一貫した PHB（Per-Hop Behavior）を実現し、帯域逼迫時にもアプリケーションの要求 S SLA（Service Level Agreement）を死守する。
* **利用場面:** IP 化された音声・ビデオ会議システム、SD-WAN / DMVPN による多拠点メッシュ網、MPLS L3VPN を利用した企業バックボーン網、サブレート回線接続部。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **アーキテクチャ** | DiffServ (Differentiated Services) モデル ＋ MQC (Modular QoS CLI) フレームワーク |
| **制御コンポーネント** | **Class-Map**（トラフィック識別）, **Policy-Map**（QoS アクション定義）, **Service-Policy**（I/F アタッチ） |
| **信頼境界 (Trust Boundary)** | アクセススイッチポート（IP Phone 直下など）。非信頼端末からの不正マークを水際でリセット/リマーク |
| **推奨トラフィック分類** | RFC 4594（Cisco 12-Class 基準: Voice=EF, Video=AF41/CS5, Signaling=CS3, Critical=AF31/AF21, Scavenger=CS1, BE=DF） |
| **トンネル透明性** | `qos pre-classify` (IPsec/GRE/DMVPN 用), ToS Byte Copying (IP-in-IP), MPLS Uniform / Pipe / Short-Pipe Modes |
| **L2/L3 相互変換** | `qos map cos to dscp`, `qos map dscp to cos`, `table-map`（Policy-Map 内での動的書き換え） |
| **WAN 速度適合** | HQoS (Hierarchical QoS: Parent Shaping ＋ Child LLQ/CBWFQ) により SP 側ポリサーでの破棄を防止 |
| **制限事項・注意点** | Ingress/Egress でサポートされるアクションの差分、CEF 必須依存性、プロトコルカプセル化によるオーバーヘッド計算 |

---

## 🏗 動作原理

エンドツーエンド L3 QoS の動作原理は、パケットのライフサイクル全体を通じて「信頼性の管理」「ヘッダーの一貫した透過的伝送」「ノードごとの適切なリソース割り当て」を行う点にある。

```
[Client PC / IP Phone]
       │
  (Ingress Access)
       ▼
 [Access Switch] ──► 【Trust Boundary】: IP Phone を検証して CoS 5 / DSCP EF を信頼。PC パケットは CoS 0 / DSCP 0 にリセット。
       │            【Classification & Marking】: CoS ➔ DSCP 変換 (CoS 5 ➔ DSCP 46)。
  (Trunk Up-link)
       ▼
 [Core Router]   ──► 【Core Queuing】: DSCP マークに基づき、DSCP EF パケットを Priority Queue (LLQ) へ、AF31 を CBWFQ へ。
       │
   (WAN Edge)
       ▼
 [WAN Edge Rtr]  ──► 【HQoS & Tunneling】: 内部 DSCP を保持しつつ IPsec / GRE カプセル化。
       │            `qos pre-classify` により暗暗化後も内部 DSCP に基づいて HQoS (Parent Shape ＋ Child LLQ) を適用。
  (IPsec / SP Net)
       ▼
 [Branch Edge]   ──► 【Decapsulation & Egress】: トンネル解体後、元の DSCP 46 を維持して LAN 側へ送信。
       │
       ▼
 [Receiver Device]
```

### パケットフローの詳細メカニズム

1. **Ingress Access Phase (アクセス層での分類と信頼境界):**
   * スイッチのアクセスポートに到達したパケットは、CDP/LLDP-MED や 802.1X 認証によって対向機器が「信頼できるか」を判定される。
   * 信頼できる機器（IP Phone 等）からのパケットは既存マーク（CoS 5 / DSCP EF）が保持される。未承認機器（PC 等）からのパケットは Untrusted とみなされ、`set dscp default` (0) にリセットされるか、MQC や NBAR2 によって再分類・マークされる。

2. **Core Forwarding Phase (コア層での高速転送とキューイング):**
   * コア層ノードは再分類を行わず、パケットヘッダー内の DSCP 値を尊重して PHB（Per-Hop Behavior）を適用する。
   * 音声パケット（DSCP EF）は Strict Priority Queue (LLQ) に入って超低遅延で転送され、データパケット（DSCP AF31, AF21）は CBWFQ と WRED/ECN によって非優先パケットから順番に送信される。

3. **WAN & Tunnel Boundary Phase (WAN 境界とカプセル化):**
   * WAN ポートでは、契約帯域（例: 100Mbps）が物理帯域（例: 1Gbps）より低い場合に HQoS（Parent Shaping）を適用して SP 側での無分別ドロップを未然に防止する。
   * GRE や IPsec DMVPN、CAPWAP 等でカプセル化される際、ルータはデフォルトで内部 IP ヘッダーの ToS/DSCP バイトを外部 IP ヘッダーにコピーする（ToS Byte Copying）。
   * 暗号化やトランスポートヘッダーによって内部ヘッダーが参照不能になる場合、`qos pre-classify` を適用することで、カプセル化後の Egress MQC で内部ヘッダー（5-Tuple や NBAR アプリ識別）に基づいたキューイングが可能となる。

---

## ⚙ 動作シーケンス

ルータ/スイッチの内部パイプラインにおけるエンドツーエンド L3 QoS パケット処理順序は以下の通りである。

```
[Ingress Frame Packet Arrival]
            │
            ▼
┌─────────────────────────────────────────┐
│ 1. Inbound Classification & Marking     │ ──► MQC / NBAR2 / CoS-to-DSCP Table-Map 適用
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 2. Inbound Policing (Option)            │ ──► 契約帯域超過パケットの Drop または Down-Mark (AF41 ➔ AF42)
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 3. Forwarding Lookup (CEF & Pre-Class)  │ ──► Routing / Pre-Class 状態のメモリキャッシュ保存
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 4. Tunnel Encapsulation (GRE/IPsec/MPLS)│ ──► Outer Header への ToS/DSCP コピー / Pre-Class テーブル参照
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 5. Outbound MQC Queuing & Scheduling     │ ──► HQoS Parent Shape / Child LLQ & CBWFQ 蓄積
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 6. Congestion Avoidance (WRED / ECN)     │ ──► キュー高負荷時に AFx3/AFx2 から優先 Drop または ECN CE ビット付与
└─────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────┐
│ 7. Hardware Tx-Ring (FIFO) Transfer     │ ──► Tx-Ring Limit 制御に基づき物理回線へパケット送出
└─────────────────────────────────────────┘
```

1. **Ingress 処理:** パケットを受信したポートで Ingress MQC ポリシーが評価され、トラフィック分類と DSCP 設定/書き換えが実行される。
2. **ルーティング/CEF 処理:** 宛先 IP アドレスに基づき CEF テーブルが検索され、出力インターフェイスとカプセル化情報が決定される。`qos pre-classify` が有効な場合、この時点で分類データ（5-Tuple, アプリ名）が内部パケット属性として保持される。
3. **カプセル化処理:** GRE / IPsec / DMVPN トンネルインターフェイスを通過する際、アウター IP ヘッダーが生成され、インナー IP ヘッダーの ToS/DSCP 値がコピーされる。
4. **Egress 処理:** 出力ポートで Egress MQC ポリシー（HQoS 等）が適用される。親シェーパーで帯域調整された後、子ポリシーの LLQ（Priority Queue）から最優先で取り出され、CBWFQ キューイングおよび WRED/ECN 処理を経て Hardware Tx-Ring へ渡される。

---


## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験において、エンドツーエンド L3 QoS は「単体のコマンド設定問題」として出題されるのではなく、**LAN/WAN/VPN/Wireless トラフィック全体の通信要件をみたす複合課題** として頻出する。

### Blueprint で極めて重要なポイント

1. **RFC 4594（Cisco 12-Class QoS Model）の完全把握:**
   * 試験問題で「音声メディアは DSCP EF、シグナリングは CS3、ビデオ会議は AF41、重要データは AF31 にマッピングせよ」といった直感的な要件が提示された場合、適切な DSCP 値（Decimal / Hex）を即座に判定して Class-Map / Policy-Map を作成できること。

2. **信頼境界（Trust Boundary）と CoS-to-DSCP 変換:**
   * アクセススイッチで `qos trust cos` や `qos trust device cisco-phone` を設定し、`qos map cos to dscp` や MQC パイプラインを用いて L2 CoS 5 ➔ L3 DSCP 46 (EF) への整合性あるマッピングを行う問題。

3. **GRE / IPsec DMVPN 環境での `qos pre-classify`:**
   * トンネルインターフェイス（Tunnel0）または暗号化マップ（Crypto Map）に `qos pre-classify` をアタッチし、物理 WAN 出口での MQC（HQoS）が内部 IP ヘッダー（送信元/宛先 IP, L4 ポート, NBAR アプリ）に基づいて正確にキュー分配されるように構成する要件。

4. **HQoS（Hierarchical QoS）での親・子ポリシー制御:**
   * WAN 出口において、親ポリシーで `shape average` を設定し、子ポリシーで `priority`（LLQ）および `bandwidth remaining percent`（CBWFQ）を組み合わせる構成。親ポリシーに直接 `priority` を書いてコミットエラーを起こすイジワル問題への対処。

5. **MPLS L3VPN における DiffServ モード（Uniform vs Pipe vs Short-Pipe）:**
   * 顧客網（CE）の DSCP マークを SP 網（PE/P）内の MPLS EXP ビットにどのようにコピーし、対向 CE に届いた際に復元・維持するかについての設計・確認能力。

---

## 🛠 設定方法

### 1. アクセススイッチ（Access Switch）での Trust Boundary ＆ Classification 設定

```bash
! --- 1. CoS から DSCP への標準マッピング確認/カスタマイズ ---
qos map cos to dscp 0 8 16 24 32 46 48 56

! --- 2. クラスマップの定義 ---
class-map match-any CM_VOICE
 match dscp ef
 match cos 5

class-map match-any CM_SIGNALING
 match dscp cs3
 match cos 3

class-map match-any CM_CRITICAL_DATA
 match dscp af31 af32

! --- 3. インバウンドマーキングポリシー ---
policy-map PM_INGRESS_MARK
 class CM_VOICE
  set dscp ef
 class CM_SIGNALING
  set dscp cs3
 class CM_CRITICAL_DATA
  set dscp af31
 class class-default
  set dscp default

! --- 4. インターフェイスへの適用 (Conditional Trust 併用) ---
interface GigabitEthernet1/0/1
 description === Connected to Cisco IP Phone + PC ===
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 20
 qos trust device cisco-phone
 service-policy input PM_INGRESS_MARK
```

### 2. WAN Edge ルータでの DMVPN / IPsec `qos pre-classify` ＆ HQoS 設定

```bash
! --- 1. 子ポリシー (Child Policy) の定義 ---
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_VIDEO
 match dscp af41

class-map match-any CM_DATA_CRITICAL
 match dscp af31 af32

policy-map PM_HQOS_CHILD
 class CM_VOICE
  priority 1024
 class CM_VIDEO
  bandwidth remaining percent 30
 class CM_DATA_CRITICAL
  bandwidth remaining percent 50
  random-detect dscp-prec-based
 class class-default
  bandwidth remaining percent 20

! --- 2. 親ポリシー (Parent Policy) の定義 (100Mbps サブレートシェーピング) ---
policy-map PM_HQOS_PARENT
 class class-default
  shape average 100000000
  service-policy PM_HQOS_CHILD

! --- 3. DMVPN トンネルおよび物理インターフェイスへの適用 ---
interface Tunnel0
 description === DMVPN Phase 3 Tunnel ===
 ip address 10.255.1.1 255.255.255.0
 tunnel source GigabitEthernet0/0/0
 tunnel mode gre multipoint
 qos pre-classify

interface GigabitEthernet0/0/0
 description === WAN Outbound (1Gbps Physical, 100Mbps Subrate) ===
 ip address 192.0.2.1 255.255.255.252
 service-policy output PM_HQOS_PARENT
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 主な確認項目 |
| :--- | :--- | :--- |
| **MQC 適用状態確認** | `show policy-map interface <I/F> [input\|output]` | 各クラスのパケット数、Match パック数、Priority ドロップ、Shape カウンタ |
| **HQoS ネスト状態確認** | `show policy-map interface <I/F> class class-default` | Parent Shape の動作状況と Child キューイングの同時統計 |
| **Pre-classify 確認** | `show qos pre-classify` | ルータ内で Pre-classify が登録・動作している機能および Tunnel パス |
| **CoS/DSCP マッピング確認** | `show qos map [cos-to-dscp\|dscp-to-cos]` | L2/L3 ヘッダー変換テーブルの現在の割り当て数値 |
| **NBAR2 アプリ認識確認** | `show ip nbar protocol-discovery [interface <I/F>]` | レイヤー 7 アプリごとのビットレートおよびバイト数 |
| **Hardware Tx-Ring 確認** | `show controllers GigabitEthernet <I/F> | include tx_ring` | 物理 Hardware Queue (Tx-Ring) のリミット値とドロップ数 |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **IP Phone からの音声が Untrusted (DSCP 0) に降格する** | ポート側で CDP が停止しており `qos trust device cisco-phone` が解除された | `show cdp neighbors` / `show running-config interface` | 対象ポートで `cdp enable` を有効化するか、手動で `qos trust cos` を指定 |
| **GRE / IPsec トンネル通過後に Egress QoS が全て `class-default` にマッチする** | 暗号化/カプセル化により Egress MQC で内部ヘッダーが参照不能になっている | `show policy-map interface` / `show qos pre-classify` | Tunnel インターフェイスに `qos pre-classify` コマンドを追加 |
| **親 Policy-Map 作成時に `Priority class not allowed in parent policy` エラー** | 親ポリシーの直下に `priority` コマンドを記述しようとした | - | `priority` コマンドは必ず子ポリシー (Child Policy) 内に記述し、親にネストアタッチ |
| **音声パケットが LLQ キューで大量にドロップする** | `priority` で指定したポリサー帯域（例: 512k）を超過するトラフィックが入力された | `show policy-map interface` の "pkts dropped" | 音声コーデック（G.711 / G.729）と同時呼数（CAC）に合わせて `priority` 帯域を拡大 |
| **IPv6 トラフィックが MQC Class-Map にまったくマッチしない** | Class-Map 内で `match ip dscp`（IPv4 専用）が使用されている | `show class-map` | IPv4 / IPv6 共通コマンドである `match dscp` に変更 |

---

## ⚠ 制限事項

* **`qos pre-classify` の適用可能範囲:** Cisco IOS XE では、`qos pre-classify` は IPsec VPN、GRE トンネル、L2TPv3、IP-in-IP トンネルでのみサポートされる。普通の物理インターフェイス相互間には適用不可。
* **Ingress Shaping の非サポート:** MQC において `shape` コマンドは **Egress (Output) 方向限定** であり、Ingress (Input) 方向にアタッチすると CLI エラーとなる（Ingress では Policing のみ可能）。
* **Platform/ASIC の TCAM 限界:** スイッチ（Catalyst 9000 シリーズ等）において、非常に複雑な Policy-Map や大量の `match` 条件をアタッチすると、TCAM エントリのオーバーフローにより「Hardware resource exhausted」エラーが発生し、Software 切り替え（CPU 負荷急増）を引き起こす。

---

## 🔄 他技術との関連

* **MPLS L3VPN:** PE ルータでの IP DSCP ➔ MPLS EXP ビットへのマッピングおよび DiffServ Tunneling モード（Uniform, Pipe, Short-Pipe）。
* **Cisco SD-WAN (Viptela):** WAN Edge (cEdge) での Localized QoS Policy、Application-Aware Routing (AAR)、OMP 経由での DSCP 保持。
* **Cisco SD-Access (SDA):** Fabric Edge での VXLAN GPO ヘッダー内における Group Policy ID (SGT) および ToS (DSCP) バイトの透過伝送。
* **IPsec DMVPN / GRE:** 暗号化前の元の 5-Tuple 情報に基づく Quality of Service を実現するための `qos pre-classify` および Dynamic Per-Tunnel HQoS。

---

## 🧩 比較表

### MQC (IOS XE) vs MLS QoS (Legacy IOS)

| 比較項目 | MQC (Cisco IOS XE / Catalyst 9000) | レガシー MLS QoS (Catalyst 3750/3560) |
| :--- | :--- | :--- |
| **標準の信頼状態** | **Trusted (Preserved)** - 設定がなくてもヘッダー保持 | **Untrusted** - `mls qos` 有効化で全マークが 0 にクリア |
| **設定フレームワーク** | Modular QoS CLI (Class-Map / Policy-Map) | グローバル `mls qos` ＋ インターフェイス独自コマンド |
| **ポリサー構造** | Token Bucket (1r2c, 1r3c RFC 2697, 2r3c RFC 2698) | Aggregate / Individual Policer |
| **IPv6 対応** | 共通構文 (`match dscp` / `set dscp`) で完全統合 | IPv6 用の別個の ACL / QoS コマンド体系が必要 |

---

## 💡 ベストプラクティス

1. **一貫した DSCP マッピングの貫徹:**
   全社ネットワークで RFC 4594 基準（Voice=EF, Video=AF41, Signaling=CS3, Critical=AF31, Scavenger=CS1, BE=DF）を徹底し、独自ルールによる DSCP 書き換えを極力避ける。

2. **アクセス水際での早期マーキング ＆ リセット:**
   Untrusted な PC ポートからのパケットはアクセススイッチのバウンダリで即座に `DSCP 0` にリセットし、悪意ある優先権の盗用をシャットアウトする。

3. **WAN 出口での Overhead Accounting の算入:**
   サブレート WAN 回線（例: 100Mbps 契約）に HQoS を適用する際、Ethernet ヘッダーや IPsec カプセル化によるオーバーヘッドを算入する `Account User-Defined <BYTES>` や `Account Ethernet` を設定し、SP 側ポリサーでのミリ秒ドロップを回避する。

---


## 📝 ラボ学習・設定サンプル例

### ラボ 1: アクセススイッチにおける Conditional Trust ＋ CoS-to-DSCP 変換と Ingress マーキング

* **問題:** アクセススイッチ SW1 の GigabitEthernet1/0/1 に接続された Cisco IP Phone (Voice VLAN 20) および背面の PC (Data VLAN 10) に対して信頼境界を確立せよ。
* **要件:**
  * Cisco IP Phone からの通話シグナリング (CoS 3) および音声メディア (CoS 5) を信頼し、それぞれ DSCP CS3 (24) および DSCP EF (46) に変換せよ。
  * 背面 PC からのパケットは Untrusted として扱うか、特定データ (TCP 80/443) を DSCP AF21 にマーキングし、それ以外は DSCP 0 にリセットせよ。
  * CDP による電話機の動的検出（Conditional Trust）を構成せよ。

* **設定例:**
```bash
! --- 1. CoS から DSCP への変換マップのカスタマイズ ---
qos map cos to dscp 0 8 16 24 32 46 48 56

! --- 2. クラスマップの定義 ---
class-map match-any CM_VOICE
 match cos 5
 match dscp ef

class-map match-any CM_SIGNALING
 match cos 3
 match dscp cs3

class-map match-exact CM_WEB_DATA
 match access-group name ACL_WEB_DATA

ip access-list extended ACL_WEB_DATA
 permit tcp any any eq www
 permit tcp any any eq 443

! --- 3. インバウンドマーキングポリシー ---
policy-map PM_ACCESS_INGRESS
 class CM_VOICE
  set dscp ef
 class CM_SIGNALING
  set dscp cs3
 class CM_WEB_DATA
  set dscp af21
 class class-default
  set dscp default

! --- 4. インターフェイスへの適用 ---
interface GigabitEthernet1/0/1
 description === Access Port for IP Phone + PC ===
 switchport mode access
 switchport access vlan 10
 switchport voice vlan 20
 cdp enable
 qos trust device cisco-phone
 service-policy input PM_ACCESS_INGRESS
```

* **検証方法:**
  * IP Phone からの通信を受信した際、`show policy-map interface GigabitEthernet1/0/1` を実行し、`CM_VOICE` および `CM_SIGNALING` クラスで Match パケットおよび `set dscp` アクションのカウンタが増加していることを確認。

---

### ラボ 2: コア/ディストリビューションスイッチにおける MQC Queuing (LLQ ＋ CBWFQ) 構成

* **問題:** ディストリビューションスイッチ SW2 のアップリンクポート (Gi1/0/24) において、DSCP マークに基づいた 4 クラスの Egress キューイングを構成せよ。
* **要件:**
  * Voice (DSCP EF): 必須帯域 10Mbps の Strict Priority Queue (LLQ) を割り当てよ。
  * Video (DSCP AF41): 残余帯域の 30% を割り当てよ。
  * Critical Data (DSCP AF31, AF32): 残余帯域の 40% を割り当てよ。
  * その他 (class-default): 残余帯域の 20% を割り当てよ。

* **設定例:**
```bash
! --- 1. クラスマップの定義 ---
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_VIDEO
 match dscp af41

class-map match-any CM_CRITICAL
 match dscp af31 af32

! --- 2. アウトバウンドキューイングポリシーの定義 ---
policy-map PM_CORE_EGRESS
 class CM_VOICE
  priority 10240
 class CM_VIDEO
  bandwidth remaining percent 30
 class CM_CRITICAL
  bandwidth remaining percent 40
 class class-default
  bandwidth remaining percent 30

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet1/0/24
 description === Uplink to Core Router ===
 service-policy output PM_CORE_EGRESS
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet1/0/24 output` を実行し、`CM_VOICE` が "Strict Priority" として動作しており、他クラスで `bandwidth remaining percent` が正常に展開されていることを確認。

---

### ラボ 3: WAN Edge ルータにおける HQoS (Parent Shape ＋ Child LLQ/CBWFQ) サブレート構成

* **問題:** WAN Edge ルータ R1 の物理インターフェイス (Gi0/0/0: 1Gbps) において、SP 契約回線速度 50Mbps に合わせた HQoS を構築せよ。
* **要件:**
  * 親ポリシーで 50Mbps の `shape average` を適用すること。
  * 子ポリシー内で Voice (DSCP EF) に 5Mbps の LLQ を割り当て、Video (AF41) に残余帯域の 40%、Data (AF31) に残余帯域の 40% を割り当てること。
  * 親ポリシー内に直接 `priority` コマンドを記述しないこと。

* **設定例:**
```bash
! --- 1. 子ポリシー (Child Policy) の定義 ---
class-map match-any CM_VOICE
 match dscp ef

class-map match-any CM_VIDEO
 match dscp af41

class-map match-any CM_DATA
 match dscp af31 af32

policy-map PM_HQOS_CHILD
 class CM_VOICE
  priority 5120
 class CM_VIDEO
  bandwidth remaining percent 40
 class CM_DATA
  bandwidth remaining percent 40
 class class-default
  bandwidth remaining percent 20

! --- 2. 親ポリシー (Parent Policy) の定義 ---
policy-map PM_HQOS_PARENT
 class class-default
  shape average 50000000
  service-policy PM_HQOS_CHILD

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet0/0/0
 description === WAN Egress (50Mbps Subrate) ===
 service-policy output PM_HQOS_PARENT
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/0 output` を実行し、Parent Class の `shape average 50000000` の配下に Child Class のキュー統計がネスト表示されていることを確認。

---

### ラボ 4: GRE / IPsec DMVPN トンネル環境での `qos pre-classify` 統合構成

* **問題:** DMVPN Spoke ルータ R2 において、Tunnel0 経由で送信されるパケットに対し、暗号化前の元の 5-Tuple（送信元/宛先 IP、ポート番号）に基づいて物理出口ポート (Gi0/0/0) で MQC キューイングを適用せよ。
* **要件:**
  * Tunnel0 インターフェイスに `qos pre-classify` をアタッチすること。
  * 物理ポート (Gi0/0/0) で HQoS ポリシーを適用し、暗号化パケット内から抽出された元の IP/Port（例: UDP 5060/16384）に基づいて優先制御せよ。

* **設定例:**
```bash
! --- 1. トンネル内元の通信を認識する ACL ＆ Class-Map ---
ip access-list extended ACL_VOIP_PAYLOAD
 permit udp any any eq 5060
 permit udp any any range 16384 32767

class-map match-all CM_ORIGINAL_VOIP
 match access-group name ACL_VOIP_PAYLOAD

! --- 2. 子ポリシー ＆ 親ポリシーの作成 ---
policy-map PM_TUNNEL_CHILD
 class CM_ORIGINAL_VOIP
  priority 2048
 class class-default
  bandwidth remaining percent 100

policy-map PM_TUNNEL_PARENT
 class class-default
  shape average 20000000
  service-policy PM_TUNNEL_CHILD

! --- 3. Tunnel インターフェイスへの Pre-Class 設定 ---
interface Tunnel0
 description === DMVPN Phase 3 Tunnel ===
 ip address 10.255.1.2 255.255.255.0
 tunnel source GigabitEthernet0/0/0
 tunnel mode gre multipoint
 qos pre-classify

! --- 4. 物理 WAN インターフェイスへの適用 ---
interface GigabitEthernet0/0/0
 service-policy output PM_TUNNEL_PARENT
```

* **検証方法:**
  * `show qos pre-classify` を実行し、`Tunnel0` が Pre-classify 対象として正しく登録されていることを確認。
  * Tunnel0 経由で UDP 5060 通信を発生させ、`show policy-map interface GigabitEthernet0/0/0` の `CM_ORIGINAL_VOIP` クラスでパケットがカウントされることを確認。

---

### ラボ 5: NBAR2 アプリケーション識別 (WebEx / Teams) 連動マーキング ＆ ポリシング

* **問題:** WAN Edge ルータ R3 において、NBAR2 (Network-Based Application Recognition) を利用して WebEx 通信および Microsoft Teams 通信を自動識別し、異なる QoS アクションを適用せよ。
* **要件:**
  * WebEx Media 通信を識別し、DSCP AF41 にリマークした上で 10Mbps の帯域を保証せよ。
  * P2P File Sharing アプリ（BitTorrent 等）を識別し、1Mbps でポリシング（超過分ドロップ）せよ。

* **設定例:**
```bash
! --- 1. NBAR2 Protocol Discovery の有効化 ---
interface GigabitEthernet0/0/1
 ip nbar protocol-discovery

! --- 2. NBAR2 ベースの Class-Map 定義 ---
class-map match-any CM_WEBEX
 match protocol webex-media
 match protocol webex-meeting

class-map match-any CM_P2P
 match protocol attribute category file-sharing

! --- 3. Policy-Map の定義 ---
policy-map PM_NBAR_QOS
 class CM_WEBEX
  set dscp af41
  bandwidth 10000
 class CM_P2P
  police 1000000 conform-action transmit exceed-action drop
 class class-default
  bandwidth remaining percent 100

! --- 4. インターフェイスへの適用 ---
interface GigabitEthernet0/0/0
 service-policy output PM_NBAR_QOS
```

* **検証方法:**
  * `show ip nbar protocol-discovery` で検出アプリ一覧を確認。
  * `show policy-map interface GigabitEthernet0/0/0` を実行し、`CM_WEBEX` および `CM_P2P` クラスで NBAR2 識別に基づくカウントが行われていることを確認。

---

### ラボ 6: Single-Rate Three-Color (1r3c - RFC 2697) Policier による段階的 Down-Marking

* **問題:** ルータ R4 において、DSCP AF41（ビデオ会議通信）に対して CIR 8Mbps の 1r3c (RFC 2697) ポリサーを構成し、バースト発生時にパケットを即座に破棄せず段階的に降格（Down-mark）させよ。
* **要件:**
  * CIR 8Mbps (1000000 Bytes/s), Bc 200000 Bytes, Be 400000 Bytes とすること。
  * Conform トラフィックはそのまま透過（Transmit）せよ。
  * Exceed トラフィックは DSCP AF42 に降格して転送せよ。
  * Violate トラフィックは DSCP AF43 に降格して転送せよ。

* **設定例:**
```bash
! --- 1. クラスマップの定義 ---
class-map match-all CM_VIDEO_AF41
 match dscp af41

! --- 2. 1r3c ポリサーを含む Policy-Map の定義 ---
policy-map PM_POLICE_DOWNMARK
 class CM_VIDEO_AF41
  police cir 8000000 bc 200000 be 400000
   conform-action transmit
   exceed-action set-dscp-transmit af42
   violate-action set-dscp-transmit af43

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet0/0/1
 service-policy input PM_POLICE_DOWNMARK
```

* **検証方法:**
  * 12Mbps の AF41 トラフィックを注入し、`show policy-map interface GigabitEthernet0/0/1` で `conformed`, `exceeded`, `violated` の各パケット数が記録され、対向ノードで AF42 / AF43 パケットが受信されることを確認。

---

### ラボ 7: WRED (Weighted Random Early Detection) ＋ ECN (Explicit Congestion Notification) 構成

* **問題:** WAN ルータ R5 の Egress インターフェイスにおいて、Mission-Critical Data クラス（DSCP AF31, AF32）に対し、TCP グローバル同期を防止するための WRED および ECN パケット標識機能を構成せよ。
* **要件:**
  * AF31 パケットの WRED 閾値: Min 32 packets, Max 64 packets, Drop Prob 1/10 とすること。
  * AF32 パケットの WRED 閾値: Min 16 packets, Max 32 packets, Drop Prob 1/10 とすること。
  * WRED 閾値到達時、パケットをドロップする代わりに ECN（Explicit Congestion Notification）マークを付与して送信せよ。

* **設定例:**
```bash
! --- 1. クラスマップの定義 ---
class-map match-any CM_DATA_AF
 match dscp af31 af32

! --- 2. WRED ＋ ECN Policy-Map の定義 ---
policy-map PM_WRED_ECN
 class CM_DATA_AF
  bandwidth remaining percent 50
  random-detect dscp-prec-based
  random-detect dscp af31 32 64 10
  random-detect dscp af32 16 32 10
  random-detect ecn

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet0/0/0
 service-policy output PM_WRED_ECN
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/0` を実行し、`CM_DATA_AF` クラスの配下で `WRED enabled` および `ECN enabled` が表示され、過負荷時に ECN marked パケット数が増加していることを確認。

---

### ラボ 8: MPLS L3VPN CE-PE 境界における DSCP 保持 ＋ QoS マッピング構成

* **問題:** CE ルータ R6 および PE ルータ PE1 間の eBGP 境界において、CE 側で付与された IP DSCP マークを SP 網（MPLS L3VPN）内で正しく MPLS EXP ビットにマッピングして伝送せよ。
* **要件:**
  * CE ルータ R6 側で DSCP EF, AF41, AF31 を正しくマークして PE1 へ送信せよ。
  * PE1 ルータでは Uniform Mode を採用し、IP DSCP 上位 3 ビットを自動的に MPLS EXP にコピーして P ルータ網へ転送させよ。

* **設定例 (CE ルータ R6):**
```bash
! --- CE ルータ側マーキング設定 ---
class-map match-all CM_VOICE
 match ip precedence 5

policy-map PM_CE_OUT
 class CM_VOICE
  set dscp ef
 class class-default
  set dscp default

interface GigabitEthernet0/0/0
 description === To PE1 Router ===
 service-policy output PM_CE_OUT
```

* **設定例 (PE ルータ PE1):**
```bash
! --- PE ルータ側 VRF インターフェイス設定 (Uniform Mode はデフォルト動作) ---
interface GigabitEthernet0/0/1
 description === Connected to CE R6 ===
 vrf forwarding VPN_A
 ip address 192.168.100.1 255.255.255.252
```

* **検証方法:**
  * PE1 から P ルータへ送出される MPLS パケットをキャプチャまたは `show mpls forwarding-table` で検証し、MPLS Label ヘッダー内の EXP ビットが DSCP EF (46 = Binary 101110 ➔ EXP 5) にコピーされていることを確認。

---

### ラボ 9: Overhead Accounting (IPsec / Ethernet Header Byte Add) 付き HQoS

* **問題:** WAN ルータ R7 において、100Mbps サブレート回線接続部に HQoS を適用する際、Ethernet L2 ヘッダーおよび IPsec ESP カプセル化によるオーバーヘッド（24 バイト）を正確に計算に組み込め。
* **要件:**
  * 親ポリシーの `shape average` 計算において `Account User-Defined 24` を指定すること。
  * 音声クラス（5Mbps LLQ）およびデータクラス（残り 80%）を構成すること。

* **設定例:**
```bash
! --- 1. 子ポリシーの定義 ---
class-map match-any CM_VOICE
 match dscp ef

policy-map PM_ACCOUNT_CHILD
 class CM_VOICE
  priority 5120
 class class-default
  bandwidth remaining percent 100

! --- 2. オーバーヘッド補正付き親ポリシーの定義 ---
policy-map PM_ACCOUNT_PARENT
 class class-default
  shape average 100000000 Account User-Defined 24
  service-policy PM_ACCOUNT_CHILD

! --- 3. インターフェイスへの適用 ---
interface GigabitEthernet0/0/0
 service-policy output PM_ACCOUNT_PARENT
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet0/0/0` を実行し、Parent Class の Shape 情報欄に `Account User-Defined 24` が反映され、バイト計算補正が適用されていることを確認。

---

### ラボ 10: 802.1X / RADIUS 認証成功端末に対する Dynamic QoS (C3PL / Policy-Map) 動的付与

* **問題:** アクセススイッチ SW3 において、802.1X 認証に成功したユーザーに対し、Cisco ISE (RADIUS) から VSA (Vendor Specific Attribute) を経由して Dynamic QoS Policy-Map（`PM_DYNAMIC_USER`）を動的にアタッチせよ。
* **要件:**
  * スイッチ側にあらかじめ Policy-Map `PM_DYNAMIC_USER`（帯域制限 20Mbps ポリサー）を定義しておくこと。
  * RADIUS 属性 `Filter-Id` または `ip:sub-policy-in` で動的バインドさせよ。

* **設定例:**
```bash
! --- 1. 割り当てる Dynamic Policy-Map の事前作成 ---
class-map match-all CM_ALL_TRAFFIC
 match any

policy-map PM_DYNAMIC_USER
 class CM_ALL_TRAFFIC
  police 20000000 conform-action transmit exceed-action drop

! --- 2. インターフェイスの C3PL (Common Classification Policy Language) 構成 ---
interface GigabitEthernet1/0/10
 description === 802.1X Authenticated Access Port ===
 switchport mode access
 access-session port-control auto
 mab
 dot1x pae authenticator
```

* **検証方法:**
  * 端末が 802.1X 認証に成功した後、`show access-session interface GigabitEthernet1/0/10 details` を実行し、`Applied Policy` または `QoS Policy` 欄に `PM_DYNAMIC_USER` が正しくアタッチされていることを確認。

---


## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** 企業ネットワークの WAN Edge ルータ R1 において、GRE トンネル (Tunnel0) を通過する音声パケット（DSCP EF）を WAN 出口ポート (Gi0/0/0) の LLQ キューで優先処理させるため、以下のコンフィグをアタッチした。しかし、`show policy-map interface Gi0/0/0` を確認すると、音声パケットが一切 `CM_VOICE` クラスにマッチせず、すべて `class-default` に入っていた。

```bash
class-map match-all CM_VOICE
 match dscp ef

policy-map PM_WAN_OUT
 class CM_VOICE
  priority 2048
 class class-default
  bandwidth remaining percent 100

interface GigabitEthernet0/0/0
 service-policy output PM_WAN_OUT

interface Tunnel0
 ip address 10.255.1.1 255.255.255.0
 tunnel source 192.0.2.1
 tunnel destination 192.0.2.2
```

**設問:** 音声パケットが `CM_VOICE` にマッチしない技術的原因を説明し、最小限のコマンド追加で修復せよ。

* **解答:**
  * **技術的原因:** GRE カプセル化処理により、物理ポート Gi0/0/0 で MQC が評価される時点では外側 IP ヘッダーのみが参照されるか、カプセル化パケットとして扱われる。ルータ内で暗号化/カプセル化前の元パケットの DSCP / 5-Tuple 属性を物理 Egress MQC へ引き継ぐ処理（Pre-classification）が動作していないため。
  * **修復コマンド:**
    ```bash
    interface Tunnel0
     qos pre-classify
    ```

---

### 問 2 (Design / 信頼境界)
**シナリオ:** ある拠点の LAN アクセススイッチ SW1 において、PC ユーザーが自身の PC 上でフリーソフトを用いて全送信パケットに `DSCP EF (46)` を不当に付与して送信していることが判明した。これにより LAN 側の音声帯域が逼迫している。スイッチポート Gi1/0/15 には Cisco IP Phone が接続されており、その背面に該当 PC が接続されている。
**設問:** Cisco IP Phone からの音声通信（CoS 5 / DSCP EF）およびシグナリング通信（CoS 3 / DSCP CS3）の優先度を安全に維持しつつ、PC から送信される不正な DSCP EF パケットを水際で `DSCP 0 (Default)` にリセットするためのベストプラクティス構成を述べよ。

* **解答:**
  * CDP による動的電話機検出（Conditional Trust）を構成する。`qos trust device cisco-phone` を設定することで、スイッチは CDP で正規の Cisco IP Phone を検出した時のみ Phone 自体のマークを信頼する。同時に、IP Phone 背面の PC ポートから送られてくる Data VLAN（アクセス VLAN）上のパケットに対しては Trust を適用せず、MQC ポリシーで `set dscp default` を指定して強制リセットする。

---

### 問 3 (トラブルシューティング / IPv6 デュアルスタック)
**シナリオ:** デュアルスタック (IPv4 / IPv6) 環境の WAN ルータ R2 において、以下の QoS コンフィグを投入した。IPv4 の音声通信は正常に LLQ キューで優先処理されているが、IPv6 の音声通信（IPv6 ヘッダー内の Traffic Class が DSCP EF）のみが優先されず、遅延・ドロップが発生している。

```bash
class-map match-all CM_VOICE
 match ip dscp ef

policy-map PM_EGRESS
 class CM_VOICE
  priority 1024
 class class-default
  bandwidth remaining percent 100
```

**設問:** IPv6 音声通信が優先処理されない原因を特定し、IPv4 と IPv6 の双方の音声通信を同一の `CM_VOICE` クラスで一括優先処理するための修正コマンドを記述せよ。

* **解答:**
  * **原因:** `match ip dscp` 構文は IPv4 パケットの ToS ヘッダーのみを評価対象とするため、IPv6 パケットの Traffic Class ヘッダー内の DSCP 値（EF）がマッチせずスルーされた。
  * **修正コマンド:**
    ```bash
    class-map match-all CM_VOICE
     no match ip dscp ef
     match dscp ef
    ```

---

### 問 4 (構文・制限事項 / HQoS)
**シナリオ:** ネットワーク管理者が WAN サブレート回線（100Mbps 契約）の Egress ポートにおいて、音声（10Mbps 保証）とデータトラフィックを制御するために以下の Policy-Map を作成し、インターフェイスにアタッチしようとしたところ、CLI でエラーが発生しアタッチに失敗した。

```bash
policy-map PM_INVALID_PARENT
 class class-default
  shape average 100000000
  priority 10240

interface GigabitEthernet0/0/0
 service-policy output PM_INVALID_PARENT
```

**設問:** 表示されるエラーの名称（または理由）を述べ、正しく動作する 2 レベル HQoS 構成（親・子ポリシー分離）のコンフィグへ修正せよ。

* **解答:**
  * **エラー理由:** `Priority class not allowed in parent policy`（親ポリシーの class-default 内に `priority` コマンドを直接記述することは MQC アーキテクチャの仕様上禁止されているため）。
  * **修正コンフィグ:**
    ```bash
    ! 子ポリシーの作成
    policy-map PM_VALID_CHILD
     class CM_VOICE
      priority 10240
     class class-default
      bandwidth remaining percent 100

    ! 親ポリシーの作成
    policy-map PM_VALID_PARENT
     class class-default
      shape average 100000000
      service-policy PM_VALID_CHILD

    ! インターフェイス適用
    interface GigabitEthernet0/0/0
     service-policy output PM_VALID_PARENT
    ```

---

### 問 5 (トラブルシューティング / LLQ ドロップ)
**シナリオ:** ルータ R3 の `show policy-map interface GigabitEthernet0/0/0` を確認したところ、`CM_VOICE` クラス（`priority 2048` 設定）において "pkts dropped" のカウントが継続的に増加していた。回線帯域（100Mbps）には十分な余裕があり、他クラスでのドロップは発生していない。
**設问:** この LLQ クラス内でのパケットドロップが発生している技術的理由と、解決策を述べよ。

* **解答:**
  * **技術的原因:** MQC の `priority` コマンドには内蔵ポリサー（Built-in Policer）が自動的に機能している。設定された 2,048 kbps（2.048 Mbps）を超える音声トラフィックが入力されたため、他クラスの餓死（Starvation）を防ぐ保護メカニズムによってポリサーが作動し、超過パケットが即座にドロップされたため。
  * **解決策:** 音声呼制御（CAC: Call Admission Control）を見直して同時呼数を制限するか、またはコーデック数増加に合わせて `priority` の帯域設定値を拡大（例: `priority 4096`）する。

---

## 🔗 参考リソース

* Cisco Live - Advanced Enterprise QoS Design
* Cisco Live - End-to-End QoS Architecture & Deployment Guidelines
* Cisco Configuration Guide - Quality of Service Solutions Configuration Guide, Cisco IOS XE 17.x
* Cisco Command Reference - Quality of Service Commands, Cisco IOS XE
* Cisco Validated Design (CVD) - Enterprise Quality of Service Design Guide
* Cisco Technical Notes - Troubleshooting QoS on Catalyst 9000 Series Switches
* Cisco White Paper - DiffServ - The Quality of Service Model
* RFC 4594 - Guidelines for DiffServ Service Classes
* RFC 2474 - Definition of the Differentiated Services Field (DS Field)

---

## 📝 **補足（Notes）**

### エンドツーエンド QoS 設計時のチェックリスト
1. **L2/L3 相互マッピングの整合性:**
   * スイッチ〜ルータ間での CoS ⇄ DSCP の変換に抜け漏れがないか（特に CoS 5 ⇄ DSCP EF, CoS 3 ⇄ DSCP CS3）。
2. **IPsec / GRE トンネルでの `qos pre-classify`:**
   * 暗号化ルータでの物理出口 MQC に `qos pre-classify` が設定されているか。
3. **HQoS の階層化:**
   * 親ポリシーに `shape average`、子ポリシーに `priority` / `bandwidth remaining percent` が正しく記述されているか。
4. **IPv4 / IPv6 共通コマンド:**
   * Class-Map 内で `match ip dscp` ではなく `match dscp` を使用しているか。
5. **Overhead Accounting:**
   * WAN サブレート環境で Ethernet / IPsec ヘッダーのオーバーヘッド補正（`Account User-Defined`）が含まれているか。

---




## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2731: What QoS can do for your network with Catalyst 8000 and other IOS XE routers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2731)
*   [**BRKCRS-2501: Campus QoS Design Simplified**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2501)
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)

### Configuration ガイド
*   [**Quality of Service Configuration Guide, Cisco IOS XE Release 17.x**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos/configuration/xe-17/qos-xe-17-book.html)
*   [**QoS: Classification Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_classn/configuration/xe-17/qos-classn-xe-17-book.html)
*   [**Configuring NBAR based Classification**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_nbar/configuration/xe-16/qos-nbar-xe-16-book.html)

### テクニカルドキュメント・設定例
*   [**Enterprise QoS Solution Reference Network Design (SRND) Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/WAN_and_MAN/QoS_SRND/QoS-SRND-Book/QoSIntro.html)
*   [**Implementing Quality of Service Policies with DSCP (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)
*   [**Low Latency Queuing with Priority Percentage Support**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_conmgt/configuration/15-mt/qos-conmgt-15-mt-book/qos-conmgt-llq-pps.html)

---
## 📝 補足
- この学習メモは、CCIE EI 実技試験において QoS を「点（コマンド）」ではなく「線（エンドツーエンドのトラフィックフロー）」として捉えるための指針となります。ラボ試験では、**`show policy-map interface`** の出力を詳細に読み解き、要件に対する実装の整合性を証明できることが合格の鍵となります。


