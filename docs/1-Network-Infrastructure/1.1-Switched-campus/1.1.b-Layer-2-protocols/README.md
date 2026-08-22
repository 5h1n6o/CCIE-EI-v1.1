---
layout: default
title: 1.1.b-Layer-2-protocols
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.1.b Layter 2 Protocols

## 1.1.b IEEE 802.1Q and Layer 2 Protocol Tunneling

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 および CCDE v3.1 ラボ試験において極めて重要なL2キャリア/ファブリック技術である**IEEE 802.1Q トランキング**、**QinQ（802.1Q-in-Q / 802.1ad）**、および**L2PT（Layer 2 Protocol Tunneling）**について、インフラ設計、設定、トラブルシューティングを網羅するExpertレベルの学習メモを記述します。

---

## 📘 概要

エンタープライズネットワークの集約やマルチテナント環境の構築、あるいは拠点間をサービスプロバイダ（SP）のレイヤ2広域イーサネット網で接続する際、複数の独立したVLAN空間を透過的かつ安全に維持してカプセル化する技術が不可欠です。

### 1. IEEE 802.1Q トランキング
イーサネットフレーム内に12ビットのVLAN識別子（最大4096のVLANID）を含む4バイトの「タグ（Tag）」を挿入し、単一の物理リンク上で複数のVLANトラフィックを多重化する業界標準技術です。

### 2. QinQ (802.1Q Tunneling / Double Tagging)
SP網やキャンパスコアにおいて、顧客や異なる部門のL2トラフィックを個々のVLAN空間（C-VLAN: Customer VLAN）ごとカプセル化するため、フレームにさらにもう1層の外部タグ（S-VLAN: Service Provider VLAN）を付与する技術です。これにより、C-VLAN IDが重複していても衝突することなく、SP網を透過（Tunneling）させることができます。

### 3. L2PT (Layer 2 Protocol Tunneling)
SP網をまたいで顧客のスイッチ間でSTP、CDP、VTP、LACP、LLDP、PAGPなどのL2コントロールプロトコル（BPDU/L2マルチキャスト）を透過的にトンネリングする技術です。通常、SPのエッジスイッチは受信したSTPやCDPのパケットを自身で処理・破棄（Consume）してしまいますが、L2PTは宛先MACアドレスを特定の一時的なマルチキャストMACアドレス（Cisco独自：`01-00-0c-cd-cd-d0`）へ書き換える（MAC Address Rewrite）ことで、SP網をバイパスさせて対向のエッジスイッチで元に戻す挙動を実現します。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主な特徴** | 802.1Qタグの二重付与（Double Tagging）、L2マルチキャスト制御プレーンフレームの宛先MACアドレス変換によるトンネリング。 |
| **用途** | 広域L2サービス（VPLS、E-Lineなど）へのエンタープライズトランク接続、キャンパス網におけるマルチテナントL2延伸。 |
| **メリット** | 顧客側のVLAN体系に影響を与えずSP網に統合可能。STPトポロジーやCDP隣接関係を地理的に離れた自社拠点間で透過維持。 |
| **デメリット** | ダブルタギングによるL2ペイロードの縮小（Jumbo MTU設計が必須）。設定を誤ると、意図しないSTPループがプロバイダ網をまたいでバーストする。 |
| **対応機種** | Catalyst 9000 シリーズ（Catalyst 9300, 9400, 9500, 9600）を含む Cisco IOS-XE 16.x/17.x。 |
| **制限事項** | スイッチのASIC制限により、L2PTポートでは一部の高度なL2フィルタ（PACL/MACL）やスパニングツリー機能（Loop Guard等）と競合する場合がある。 |
| **設計上の注意点** | 外部タグ（S-VLAN）を処理するインターフェイスの物理MTUを最低でも**1504〜1508バイト以上**（タグ付きなら最大1522バイト以上。通常はJumboフレーム9000以上）に拡張。 |

---

## 🏗 動作原理

### 1. 802.1Q / QinQ フレームカプセル化構造
標準のイーサネットフレーム（1500バイトペイロード）に、C-Tag（4バイト）およびS-Tag（4バイト）が挿入されるプロセスを示します。

```text
[ 標準 Ethernet フレーム ]
┌──────────┬──────────┬──────────┬──────────┬──────────┐
│  DMAC    │  SMAC    │ EtherType│ Payload  │   FCS    │
│ (6-byte) │ (6-byte) │ (0x0800) │ (1500-B) │ (4-byte) │
└──────────┴──────────┴──────────┴──────────┴──────────┘

[ IEEE 802.1Q シングルタグ（C-VLAN）]
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│  DMAC    │  SMAC    │ 802.1Q   │ EtherType│ Payload  │   FCS    │
│ (6-byte) │ (6-byte) │ (0x8100) │ (0x0800) │ (1500-B) │ (4-byte) │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
                       ▲ 12-bit VLAN ID

[ IEEE 802.1ad ダブルタグ（QinQ / 802.1Q Tunneling）]
┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│  DMAC    │  SMAC    │ S-Tag    │ C-Tag    │ EtherType│ Payload  │   FCS    │
│ (6-byte) │ (6-byte) │ (0x88a8/ │ (0x8100) │ (0x0800) │ (1500-B) │ (4-byte) │
│          │          │  0x8100) │          │          │          │          │
└──────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
                       ▲ Outer Tag          ▲ Inner Tag
```

### 2. L2PT（Layer 2 Protocol Tunneling）によるMACアドレス変換
顧客のエッジスイッチ（Customer Edge: CE）から送信されたSTP BPDUが、サービスプロバイダのエッジスイッチ（Provider Edge: PE）で変換・カプセル化され、対向拠点へ到達するフローを示します。

```text
  [ CE-1 (Customer) ] ── (STP BPDU Sent) ──► [ PE-1 Ingress (L2PT port) ]
    - Destination MAC: 01-80-c2-00-00-00 (STP Multicast)
    
                                                 │
                                                 ▼ [ L2PT 変換処理 ]
                                                 - 宛先 MAC を Cisco 独自に書き換え:
                                                   01-80-c2-00-00-00 ➔ 01-00-0c-cd-cd-d0
                                                 - 顧客 VLAN (C-VLAN) の外側に S-VLAN タグを付加
                                                 │
                                                 ▼
                                     [ Provider Core Network ] ➔ 通常のデータパケットとして高速透過転送
                                                 │
                                                 ▼
                                             [ PE-2 Egress (L2PT port) ]
                                                 │ [ L2PT 復元処理 ]
                                                 - 宛先 MAC を元の STP マルチキャストに再書き換え:
                                                   01-00-0c-cd-cd-d0 ➔ 01-80-c2-00-00-00
                                                 - 外側の S-VLAN タグを除去
                                                 ▼
  [ CE-2 (Customer) ] ◄── (STP BPDU Recv) ─── [ 透過完了：CE-2 は同一 STP ドメインとしてネイバーを維持 ]
```

---

## ⚙ 動作シーケンス

### QinQ ポートにおける着信パケットのタギングおよびL2PT書き換えシーケンス

1.  **フレーム受信:** PE-1の `dot1q-tunnel` インターフェイスに顧客（CE-1）からのイーサネットフレーム（タグなし or C-Tag [例: VLAN 10] 付き）が到着。
2.  **L2PTマッチング（L2マルチキャストパケットの場合のみ）:**
    *   パケットの宛先MACが `01-80-c2-00-00-00`（STP BPDU）や `01-00-0c-cc-cc-cc`（CDP/VTP）に一致するか検査。
    *   一致した場合、宛先MACアドレスを `01-00-0c-cd-cd-d0` へ置換（Rewrite）。
3.  **アウター（S-Tag）付与:**
    *   インターフェイスに設定されている `switchport access vlan [S-VLAN ID]` に基づき、外側のタグ（S-Tag）を付与。
    *   フレーム全体の EtherType を 0x8100 または 802.1ad（0x88a8）にエンコード。
4.  **プロバイダコア転送:** S-VLANに基づいて、プロバイダ網内のトランクスイッチ間を完全に透過（L2フォワーディング）転送。
5.  **PE-2 逆変換:** 対向の PE-2 スイッチが `01-00-0c-cd-cd-d0` 宛てのフレームを受信。
6.  **アウタータグの除去 & MAC復元:**
    *   S-VLANタグをポップ（Pop/除去）して元のフレームに戻す。
    *   L2PTエントリに基づき、宛先MACアドレスを元の `01-80-c2-00-00-00` に復元。
7.  **CE-2 への引き渡し:** CE-2 側のインターフェイスへパケットを送信。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EIラボ実技試験では、SD-AccessやSD-WANといった最新のオーバーレイ技術の影に隠れて、このクラシックな **QinQ / L2PT** の制御がトラブルシューティングや「古いインフラ接続」の要件として、意図的に仕組まれます。

### 1. 物理ポートタイプとタギング動作の不一致
*   **QinQ（`dot1q-tunnel`）ポート:** 
    ポートに着信したすべてのタグ付き/タグなしフレームに対し、**無条件で** `switchport access vlan` に指定された S-VLAN タグを付加（Push）します。
*   **VLAN Translation（1-to-1 / 1-to-2 変換）:**
    「無条件に二重タグを付けるのではなく、特定のC-VLANタグ（例：10）を持つパケットを特定のS-VLAN（例：100）に変換せよ（マッピング）」という課題が提示されます。
    *   **対策:** `switchport mode trunk` ポートにおいて, `switchport vlan mapping [C-VLAN] [S-VLAN]` コマンドを用いて、1対1のVLAN変換をハードウェア（ASIC）レベルで実装します。

### 2. L2PT の設定漏れによるルーティング・STP隣接崩壊
*   **トラブルシナリオ:** 「離れた拠点（CE-1 と CE-2）間でOSPFネイバーが確立している。しかし、スイッチドWAN（QinQ網）を挟んだ瞬間、LACPポートチャネルがバンドルされず、OSPFが不定期にダウンする」
    *   **原因:** LACP制御パケット（LACPDU: MAC `01-80-c2-00-00-02`）がPEスイッチによって消費（Drop）されている。
    *   **対策:** PEスイッチの `dot1q-tunnel` インターフェイス配下で、**`l2protocol-tunnel lacp`**（および、STP用の `l2protocol-tunnel spanning-tree`）を明示的に有効にする必要があります。
*   **注意点:** L2PTを動作させるには、グローバルで `errdisable recovery cause l2ptguard` の設定が併せて要求されることがあります。L2PT制限の閾値を超えた場合に err-disable になったポートを自動リカバリさせる設計が不可欠です。

### 3. コントロールプレーンCoPPおよびQoS
*   L2PTにより書き換えられたパケット（`01-00-0c-cd-cd-d0`）は、通常のデータマルチキャストパケットとして扱われるため、PEスイッチのCoPP（Control Plane Policing）によって意図せずレートリミットされたり破棄されないようにQoSクラスマップを設定・チューニングする必要があります。

---

## 🛠 設定方法

Cisco IOS-XE 17.xにおける、QinQ、VLAN Translation、およびL2PTの完全な設定構成です。

### 1. 基本的な QinQ（802.1Q トンネリング）
PE側のスイッチにおいて、顧客接続ポートをトンネルポート化します。

```bash
# S-VLAN（プロバイダVLAN）の定義
vlan 100
 name SP_TUNNEL_VLAN
 exit

# 顧客接続インターフェイスの設定
interface GigabitEthernet1/0/1
 description CONNECT_TO_CUSTOMER_CE1
 # ポートをQinQトンネルモードに設定
 switchport mode dot1q-tunnel
 # 顧客の全トラフィックに無条件で付与するアウタータグ（S-VLAN）を指定
 switchport access vlan 100
 # トンネルポートにおけるスパニングツリーのループ防止（必須ベストプラクティス）
 spanning-tree portfast disable
```

### 2. Layer 2 Protocol Tunneling (L2PT) の設定
PE側スイッチの顧客接続ポートで、特定のL2プロトコルを透過させます。

```bash
interface GigabitEthernet1/0/1
 description CONNECT_TO_CUSTOMER_CE1
 switchport mode dot1q-tunnel
 switchport access vlan 100
 
 # トンネリングしたいプロトコルを個別に指定（STP, CDP, VTP, LACP等）
 l2protocol-tunnel spanning-tree
 l2protocol-tunnel cdp
 l2protocol-tunnel vtp
 l2protocol-tunnel point-to-point lacp
 l2protocol-tunnel point-to-point lldp
 
 # L2PTプロセス過多（スループットの枯渇）を防ぐドロップ閾値の設定
 l2protocol-tunnel cos 5
 l2protocol-tunnel drop-threshold spanning-tree 10
 l2protocol-tunnel shutdown-threshold spanning-tree 20
```

### 3. VLAN Translation (1-to-1 VLAN Mapping)
トランクポート上で、特定の顧客タグを特定のプロバイダタグに書き換えます。

```bash
interface GigabitEthernet1/0/2
 description CONNECT_TO_CUSTOMER_CE1_TRUNK_MAPPING
 switchport mode trunk
 switchport trunk allowed vlan 100, 200
 
 # 顧客タグ「10」をプロバイダタグ「100」に、顧客タグ「20」をプロバイダタグ「200」に変換
 switchport vlan mapping 10 100
 switchport vlan mapping 20 200
```

---

## 🔍 検証コマンド

稼働状態、カプセル化、L2PTの変換ヒット数を確認するためのコマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスのQinQ動作モード確認** | <code>show interfaces GigabitEthernet1/0/1 switchport</code> |
| **L2PTの有効化状態およびポートごとの送受信/ドロップパケット統計** | <code>show l2protocol-tunnel</code> |
| **特定のインターフェイスにおけるL2PT詳細ステータス** | <code>show l2protocol-tunnel interface GigabitEthernet1/0/1</code> |
| **VLANマッピング（VLAN Translation）が適用されているポートの一覧確認** | <code>show vlan filter</code> / <code>show vlan mapping</code> |
| **L2PTによる err-disable 状態の復旧構成確認** | <code>show errdisable recovery</code> |
| **物理ポートでのカプセル化・パケットサイズ（MTU）の確認** | <code>show interfaces GigabitEthernet1/0/1</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **CE間のSTP隣接関係が確立せず、独立したルートブリッジとなってしまう。** | PE側の接続ポートで <code>l2protocol-tunnel spanning-tree</code> が未構成。 | <code>show l2protocol-tunnel</code> | 対象のPEスイッチの <code>dot1q-tunnel</code> ポート配下で <code>l2protocol-tunnel spanning-tree</code> を追加。 |
| **拠点のLACPポートチャネルがバンドルに失敗し、「Suspended (I)」となる。** | LACPDU（プロトコルパケット）がPE側でトンネリングされず破棄されている。 | <code>show interfaces trunk</code><br><code>show l2protocol-tunnel</code> | インターフェイス設定で <code>l2protocol-tunnel point-to-point lacp</code> を追加。 |
| **大きなパケットが透過中のみサイレントドロップされ、IPsec等の接続が不安定になる。** | **MTUサイズ制限。** 2重タギング（QinQ）による8バイトのオーバーヘッドにより、1500バイト超過パケットがドロップ。 | <code>show system mtu</code><br><code>show interfaces</code> | PEスイッチ内の全データパス上の物理・論理インターフェイスのMTUサイズを最低でも **1508〜1522バイト以上（推奨はJumbo 9000以上）** に引き上げる [12, 1.1]。 |
| **ポートが「err-disabled」になり、Syslogに「%PM-4-ERR_DISABLE: l2ptguard」が表示される。** | 顧客側の不正STP動作等により、指定したL2PTドロップ/シャットダウン閾値（Threshold）を超過した。 | <code>show interfaces status err-disabled</code> | 1. 顧客側の障害パケット送出原因の特定・排除。<br>2. グローバルで <code>errdisable recovery cause l2ptguard</code> を適用して自動復旧させる。 |

---

## ⚠ 制限事項

### 1. ハードウェアとASICリソース制限
*   VLANマッピング（VLAN Translation）は、ASICのTCAMリソースを動的に消費します。設定可能なマッピングペア数（通常最大数百〜千）の上限に注意してください。
*   Catalyst 9000シリーズでは、ポートチャネル（EtherChannel）に直接 `dot1q-tunnel` を設定する場合、すべての物理メンバーインターフェイスの設定が完全に同期している必要があります。

### 2. プロトコルの排他制御
*   L2PTが有効化されているポートでは、**DTP (Dynamic Trunking Protocol)** はサポートされません。接続ポートは `switchport mode dot1q-tunnel` にて「静的」に固定されなければなりません。
*   インターフェイスで `l2protocol-tunnel` を有効にすると、そのポートでのローカルな **UDLD（単一方向リンク検出）** は正常に動作しなくなる可能性があるため、設計上の検証が必要です。

---

## 🔄 他技術との関連

*   **STP (Spanning Tree Protocol):** 
    L2PTを使用すると、顧客はSP網を単一の「仮想スイッチ（Hub）」と見なし、SP網をまたいだエンドツーエンドのSTPツリーを構築します。この際、SP網内のSTPトポロジーと顧客のSTPトポロジーが絶対に混ざらないよう、PEスイッチは自身のSTPインスタンスから `dot1q-tunnel` ポートを隔離（`spanning-tree bpdufilter enable` または `bpduguard`）する必要があります。
*   **IP SLA & Tracking:** 
    L2PTおよびQinQが確立された透過環境下では、離れたCE間で `ip sla` のICMPエコーやイーサネットOAMパケットを周期送信し、L2網内の隠れた物理障害をトラッキングして代替パス（ルーティング）へ切り替える設計が多用されます。
*   **VXLAN / SD-Access:** 
    モダンなファブリック（SD-Access）では、L2延伸にQinQやL2PTではなく、VXLAN（EVPNコントロールプレーン）を使用します。CCIEラボ試験では「レガシーキャンパス接続」から「SD-Accessファブリック」へのマイグレーション設計として、これら両技術が対比・統合される形で出題されます。

---

## 🧩 比較表

### 1. QinQ（802.1Qトンネリング） vs VLAN Translation（VLANマッピング）

| 比較項目 | QinQ (dot1q-tunnel) | VLAN Translation (1-to-1 Mapping) |
| :--- | :--- | :--- |
| **動作方式** | **2重タギング。** 元のフレームを変更せず、外側にS-VLANタグを無条件にPush（ポップ）。 | **タグ書き換え。** 元のC-VLANタグを、トランクポート上で直接S-VLANタグへと変換。 |
| **フレームサイズ** | タグが4バイト追加されるため、物理ワイヤ上を流れるサイズが**4バイト拡張（Jumbo MTU必要）**。 | タグの数は1つのままで変更がないため、**フレームサイズは変化しない。** |
| **適した用途** | 顧客がマルチVLAN（VLAN 1〜4094）をそのままの体系でSP網を透過させたい場合。 | 顧客側の特定のシングルVLANを、SP網側の特定のVLANに直結させたい場合。 |
| **設定ポートモード** | `switchport mode dot1q-tunnel` (アクセスポート扱い) | `switchport mode trunk` |

---

## 💡 ベストプラクティス

1.  **SP網内スイッチポートのMTU設計:**
    QinQカプセル化オーバーヘッドを処理するため、PEスイッチ同士を接続するトランクポート、および内部の全ディストリビューションスイッチのMTUサイズは一律で **`9000` バイト**（または `9100` バイト以上のシステムMTU）に設定して、サイレントロスを完璧に防止する。
2.  **L2PT過負荷に対する保護（l2ptguard）:**
    顧客ポートからの悪意ある、あるいはトポロジーバグによる大量のBPDU受信（CPU負荷のスパイク）を防ぐため、PEスイッチのポートには必ず `l2protocol-tunnel drop-threshold` および `shutdown-threshold` をミリ秒単位で規定して CoPP を補完する。
3.  **プロトコル別トンネル指定:**
    すべてのコントロールプレーンを無制限にトンネリングするのではなく、必要なプロトコル（例：STPとLACPのみ等）に限定して `l2protocol-tunnel` をバインドし、セキュリティ境界（信頼境界）を最小限に抑える。

---

## 📝 ラボ学習・設定サンプル例

※ 本サンプルは、CCIE EIおよびCCDE試験に対応する、実際のCisco IOS-XE 17.xでの動作を想定した完全なCLIコンフィグレーション例です。

### 1. 標準的な QinQ（802.1Q Tunneling）基本構成
**【問題】**
PE1とPE2の間のS-VLANを `100` とします。CE1から送られてくるすべてのタグ付きVLANフレームをカプセル化して、PE1 - PE2 間を透過させなさい。

**【PE1 設定例】**
```bash
PE1(config)# vlan 100
PE1(config-vlan)# name QinQ-S-VLAN-100
PE1(config-vlan)# exit
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# description CONNECT_TO_CE1
PE1(config-if)# switchport mode dot1q-tunnel
PE1(config-if)# switchport access vlan 100
PE1(config-if)# spanning-tree portfast disable
PE1(config-if)# end
```

---

### 2. STPおよびCDPを対象とするL2PTトンネリング構成
**【問題】**
CE1とCE2のスイッチ間で、スパニングツリー（STP）およびCDPのネイバー関係を維持したい。PE1およびPE2ポートにて、これら2つのプロトコルを透過（L2PT）させる設定を行いなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# l2protocol-tunnel spanning-tree
PE1(config-if)# l2protocol-tunnel cdp
PE1(config-if)# end
```

---

### 3. トランクポート上での1対1 VLANマッピング（VLAN Translation）
**【問題】**
PE1のポート Gi1/0/2 にトランクで接続されたCE1があります。CE1が送信するC-VLAN「10」のフレームを、PE1のプロバイダコア内トランクポートを通過する際にS-VLAN「500」に、C-VLAN「20」をS-VLAN「600」に変換する設定を実装しなさい。

**【PE1 設定例】**
```bash
PE1(config)# vlan 500,600
PE1(config-vlan)# exit
PE1(config)# interface GigabitEthernet1/0/2
PE1(config-if)# description CONNECT_TO_CE1_TRUNK_MAPPING
PE1(config-if)# switchport mode trunk
PE1(config-if)# switchport trunk allowed vlan 500,600
PE1(config-if)# switchport vlan mapping 10 500
PE1(config-if)# switchport vlan mapping 20 600
PE1(config-if)# end
```

---

### 4. 閾値に基づくL2PTガードおよびerrdisable自動復旧の設定
**【問題】**
PE1の Gi1/0/1 において、顧客からの過剰なSTP BPDU（秒間15パケット以上）を受信した場合にポートを err-disable 閉塞させ、さらに1分（60秒）後に自動で復旧（Recovery）するように構成しなさい。

**【PE1 設定例】**
```bash
PE1(config)# errdisable recovery cause l2ptguard
PE1(config)# errdisable recovery interval 60
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# l2protocol-tunnel drop-threshold spanning-tree 10
PE1(config-if)# l2protocol-tunnel shutdown-threshold spanning-tree 15
PE1(config-if)# end
```

---

### 5. 802.1ad 準拠のカスタム EtherType（TPID）の設定
**【問題】**
PE1と対向スイッチ間のQinQトンネルにおいて、アウタータグの TPID（EtherType）を標準の `0x8100` から、IEEE 802.1ad 業界規格である `0x88a8` に変更しなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# dot1q-tunnel ethertype 88a8
PE1(config-if)# end
```

---

### 6. LACPのトンネリングとマルチシャーシ対応
**【問題】**
CE1とCE2間で EtherChannel（LACP）をバンドルさせる必要があります。PE1の `dot1q-tunnel` ポートにおいて、LACPパケットを完全に透過させる設定を投入しなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# l2protocol-tunnel point-to-point lacp
PE1(config-if)# end
```

---

### 7. LLDPプロトコルの個別トンネリング構成
**【問題】**
マルチベンダー環境に対応するため、LLDP隣接パケット（LLDPBPDU）をプロバイダスイッチPE1で処理させず、対向拠点へそのままトンネリングさせなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# l2protocol-tunnel point-to-point lldp
PE1(config-if)# end
```

---

### 8. VTPデータベースの透過（VTPトンネリング）
**【問題】**
拠点CE1と拠点CE2間でVLANデータベース（VTP）の情報を自動同期させたい。VTPパケットを透過させるためのL2PTを構成しなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface GigabitEthernet1/0/1
PE1(config-if)# l2protocol-tunnel vtp
PE1(config-if)# end
```

---

### 9. QinQ インターフェイスにおける CoS 値の維持（QoS Preservation）
**【問題】**
顧客側フレームの優先度（Class of Service: CoS値）をそのままアウタータグのCoSフィールドにコピー（Preserve/継承）してSP網を通過するようにPE1を構成しなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface GigabitEthernet1/0/1
# 顧客の内部CoS値をアウタータグのCoSにマッピングして透過を維持
PE1(config-if)# l2protocol-tunnel cos 5
PE1(config-if)# end
```

---

### 10. Port-Channel（LACP）上で動作する物理インターフェイス群に対する一貫した QinQ & L2PT 設定
**【問題】**
PE1とCE1の間は2本の物理リンク（Gi1/0/10, Gi1/0/11）を束ねた `Port-channel 10` で接続されています。このLACPチャネル上で、QinQトンネル（S-VLAN 100）およびSTP、CDPのL2PTが正常かつ不整合（err-disabled）なしに動作するよう構成しなさい。

**【PE1 設定例】**
```bash
PE1(config)# interface Port-channel 10
PE1(config-if)# description MEC_TO_CE1
PE1(config-if)# switchport mode dot1q-tunnel
PE1(config-if)# switchport access vlan 100
PE1(config-if)# exit

# ポートの不整合によるErrdisableを防ぐため、すべてのメンバー物理ポートに個別かつ対称に同一設定を流し込む
PE1(config)# interface range GigabitEthernet1/0/10 - 11
PE1(config-if-range)# switchport mode dot1q-tunnel
PE1(config-if-range)# switchport access vlan 100
PE1(config-if-range)# l2protocol-tunnel spanning-tree
PE1(config-if-range)# l2protocol-tunnel cdp
PE1(config-if-range)# end
```

---

## ❓ 想定試験問題

### 1. 【Design：QinQカプセル化時のMTUサイレントドロップ分析】
**問題:** 
CE1から送信された 1500 バイトの標準IPペイロードを持つICMPパケット（通常のEthernet全体のサイズは 1518 バイト、VLANトランク時は 1522 バイト）が、PE1 - PE2 間の QinQ（dot1q-tunnel）トンネルを通過する際、中継プロバイダスイッチのトランクポートの L2 MTU が `1500` バイトに据え置かれていた。この時発生する物理層のパケット挙動および、ネットワーク全体に与えるトラブル症状を論理的に解説せよ。

**解答・解説:**
* **発生する挙動:**
  QinQにより元の顧客フレームの外側にさらに 4 バイトのアウタータグ（S-Tag）がプッシュ（追加）されるため、物理線上を流れるイーサネットフレームの総サイズは、元の `1522 バイト`（顧客トランクフレーム）から `1526 バイト` へと増加します。中継プロバイダスイッチのMTU設定が `1500` バイト（総フレーム長 1518/1522バイト対応）のままである場合、この 1526 バイトのダブルタギングフレームは、受信インターフェイスで「Giant（巨パケット）」フレームとして検知され、ハードウェア（ASIC）レベルで**サイレントドロップ（統計情報のGiantsカウンタをバーストさせて即時破棄）**されます。
* **トラブル症状:**
  TCP同期などの小さなパケット（SYN等）は透過しますが、データのやり取りが始まってMTUサイズいっぱいのパケットが送信された瞬間に通信が完全に不通（ハングアップ）になります。

---

### 2. 【Troubleshooting：L2PT動作時のLACPポートバンドル不全】
**問題:** 
CE1 と CE2 スイッチ間をポートチャネル（LACP）で接続し、PE1 - PE2 間を QinQ トンネルで接続した。しかし、CE1 の `show etherchannel summary` を確認したところ、ポートステータスが `Suspended (I)` となりバンドルされない。PEスイッチのポート Gi1/0/1 側では `show l2protocol-tunnel` にてパケットカウントが 0 のままであった。この問題の根本原因と解決のための設定を記載せよ。

**解答・解説:**
* **根本原因:**
  PEスイッチの `dot1q-tunnel` ポートにおいて、L2PT（Layer 2 Protocol Tunneling）機能による LACPDU の透過設定（`l2protocol-tunnel point-to-point lacp`）が不足しています。デフォルトの挙動として、PEスイッチは LACP などの特定L2マルチキャスト宛てパケット（MAC: `01-80-c2-00-00-02`）を受信すると、透過させずにローカルポートで消費・ドロップします。そのため、CE1 - CE2 間で LACP のネゴシエーションメッセージが交換できず、ポートチャネルの不整合が起き、安全のためにポートがサスペンドされます。
* **解決コマンド:**
  ```text
  PE1(config)# interface GigabitEthernet1/0/1
  PE1(config-if)# l2protocol-tunnel point-to-point lacp
  ```

---

### 3. 【Design：STP Loop Guard と L2PT の競合回避】
**問題:** 
キャンパスネットワークのキャリアサービスを設計する際、PEスイッチの顧客向けポート（dot1q-tunnel）で同時に `spanning-tree guard loop`（Loop Guard）を有効化することの適否を評価せよ。

**解答・解説:**
* **評価:** **不適切（無効）** です。
* **理由:**
  L2PT（`l2protocol-tunnel spanning-tree`）を有効にすると、ポートに届いた顧客のSTP BPDU（宛先MAC: `01-80-c2-00-00-00`）は、宛先MACアドレスが一時的なトンネルMAC（`01-00-0c-cd-cd-d0`）へ強制的に書き換えられます。このため、PEスイッチ自身のスパニングツリー（STP）プロセスは、このインターフェイス上で顧客本来のBPDUを直接受信することができなくなります。
  STP Loop Guard は、BPDUの受信が途絶えた場合に単一方向ループと見なしてポートを閉塞（Loop-inconsistent）する仕組みであるため、L2PTによってBPDUが検知されなくなったポートは、Loop Guardによって即座に誤閉塞されてしまいます。したがって、L2PTポートではLoop Guardは無効、あるいは `bpdufilter` を用いてSTPトポロジー自体を完全に分離（Isolate）することが推奨設計です。

---

## 🔗 参考リソース

### Cisco Live (スライド・オンデマンド)
* [**BRKCRS-2031: Layer 2 Control Plane Design and Best Practices**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031)
  * L2PTトンネリングや、SP/キャンパス内でのクラシックなQinQ設計に関するシスコ公式ベストプラクティス。
* [**BRKARC-3437: Cisco Catalyst 9000 Switching Architecture Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-3437)
  * UADP ASIC上におけるVLAN Translation、802.1Q Tunneling、およびMACアドレスリライトのハードウェア処理深度解説。

### Configuration ガイド（シスコ公式）
* [**Cisco Catalyst 9300 Series Switches: Software Configuration Guide, Layer 2 Configuration (Release 17.x)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/lyr2/b_17x_lyr2_9300_cg.html)
  * IEEE 802.1Qトンネリング（QinQ）およびレイヤ2プロトコルトンネリング（L2PT）の実装手順全般。
* [**Configuring VLAN Mapping (VLAN Translation) on Cisco Catalyst 9000 Switches**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9500/software/release/17-x/configuration_guide/lyr2/b_17x_lyr2_9500_cg/m_vlan_mapping.html)
  * スイッチトランクポートにおける1対1、1対2のVLAN変換機能に関する構成およびコマンドレファレンス。

---

## 📝 **補足（Notes）**

### L2PT 宛先 MAC アドレス変換の対応チェックテーブル

Ciscoスイッチの内部L2PTプロセス（ASIC処理）において、透過時にどの宛先アドレスへ書き換えられ、どのように分類されるかの詳細一覧です。

```text
  [ 顧客側プロトコル ]           [ 元の宛先マルチキャスト MAC ]        [ 変換後（L2PT用）宛先 MAC ]
  -----------------------------------------------------------------------------------------
  STP (Spanning Tree)  ➔      01-80-c2-00-00-00            ➔    01-00-0c-cd-cd-d0 (Cisco独自)
  CDP (Cisco Discovery)➔      01-00-0c-cc-cc-cc            ➔    01-00-0c-cd-cd-d0
  VTP (VLAN Trunking)  ➔      01-00-0c-cc-cc-cc            ➔    01-00-0c-cd-cd-d0
  LACP (Port-Channel)  ➔      01-80-c2-00-00-02            ➔    01-00-0c-cd-cd-d0 (点対点扱い)
  LLDP (Link Discovery)➔      01-80-c2-00-00-0e            ➔    01-00-0c-cd-cd-d0
```

* **学習の注意点:** 
  Cisco以外のサードパーティ製スイッチとL2PTによる相互運用（マルチベンダー環境下）を行う場合、この変換後の宛先MACアドレスが標準（IEEE 802.1ad L2PT等）と異なる場合（あるいは、変換MACの不一致）があるため、他社製PEスイッチを挟む場合は、カスタムのトンネリングMACプロファイル定義を適用させる必要がある点に注意してください。

## (i) CDP, LLDP & (ii) UDLD

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 ブループリントにおける「1.1.b Layer 2 protocols」の核となる隣接デバイス検出プロトコル（CDP, LLDP）および単一方向リンク検出プロトコル（UDLD）について、実技試験（Practical Exam）での設計・構築・トラブルシューティングに対応可能なExpertレベルのナレッジを整理します。

---

## 📘 概要

エンタープライズのスイッチドキャンパスネットワークでは、物理トポロジーの整合性を保ち、隣接するデバイスの情報を動的に収集・監視するレイヤ2プロトコルがインフラの安定稼働に極めて重要な役割を果たします。

### 1. CDP (Cisco Discovery Protocol)
CDPは、直接接続されたシスコ製デバイス間で、ハードウェアプラットフォーム、IPアドレス、OSバージョン、インターフェイス名などの情報を共有するための独自プロトコルです。
* **利用目的:** 物理ネットワークの自動検出、IP PhoneへのVoice VLAN IDやPoEバジェットの通知。
* **利用場面:** キャンパス網におけるCisco IP PhoneのConverged Access、隣接スイッチ情報の自動マッピング。

### 2. LLDP (Link Layer Discovery Protocol: IEEE 802.1AB)
LLDPは、マルチベンダー環境下で隣接デバイスの情報を交換するための標準プロトコルです。
* **利用目的:** シスコ製機器と他社製機器（VoIP端末、スイッチ、サーバー等）が混在する物理トポロジーの検出。
* **LLDP-MED (Media Endpoint Discovery):** VoIP端末等と連携し、QoSポリシー、Voice VLAN、Power over Ethernet (PoE) などの高度なプロビジョニング情報を交換可能。

### 3. UDLD (UniDirectional Link Detection)
UDLDは、光ファイバー（特にGBIC/SFP等の送信Rx/送信Txの分離芯）やメタルケーブルにおいて、送信側（Tx）または受信側（Rx）の片側のみが断線して発生する「単一方向リンク（Unidirectional Link）」を検出するプロトコルです。
* **利用目的:** スパニングツリープロトコル（STP）のループ回避、ブラックホールの検知。
* **利用場面:** 光ファイバーパッチコードが片芯だけ断線した際、STPが本来ブロッキングにすべきポートをフォワーディング（Forwarding）へ移行させてしまうスパニングツリーのループ障害を防止。

---

## 🔑 要点

各プロトコルの詳細な特徴と設計上の注意点を整理します。

| プロトコル | 項目 | 内容 |
| :--- | :--- | :--- |
| **CDP** | **特徴** | シスコ独自。レイヤ2 SNAP（Subnetwork Access Protocol）フレームを使用。マルチキャストアドレス `01:00:0c:cc:cc:cc` 宛に送信。 |
| | **用途** | Cisco IP Phoneの自動音声VLAN設定、スイッチ・ルータ間のIP到達性確立前の隣接確認。 |
| | **メリット** | シスコ製デバイス同士であればデフォルトで有効であり、設定不要で強力な自動検出を提供。 |
| | **制限事項** | 他社製機器（HP, Juniper等）やLinuxサーバーでは非サポート（または制限あり）。 |
| | **設計上の注意** | セキュリティ上の理由から、外部接続ポートやDMZ、ユーザーアクセスポートでは無効化を推奨。 |
| **LLDP** | **特徴** | IEEE標準。イーサネットプロトコルタイプ `0x88cc` を使用。マルチキャストアドレス `01:80:c2:00:00:0e` 宛に送信。 |
| | **用途** | マルチベンダー環境下におけるネットワーク機器およびIP電話・IoT端末のトポロジーマッピング。 |
| | **メリット** | 標準規格のため、ベンダーを問わず、仮想化ハイパーバイザー（VMware ESXi等）やサーバーとも隣接情報を共有可能。 |
| | **制限事項** | CDPに比べてデフォルトで無効化されているOSバージョンやデバイスが存在する。 |
| | **設計上の注意** | 音声（Voice）環境では、LLDP-MEDのTLV（Type-Length-Value）が端末と一致しているか整合性を確認。 |
| **UDLD** | **特徴** | シスコ独自。光ファイバの物理層におけるハードウェア障害（単一方向通信）をソフトウェアイベントで検出。 |
| | **用途** | スパニングツリー（STP）のループ防止、不要なブラックホールの排除。 |
| | **メリット** | ハードウェアL1リンクアップを維持したまま発生するL2片方向通信によるパケットロス・ループの検知・シャットダウン。 |
| | **制限事項** | 対向デバイスもシスコ製かつUDLDが有効である必要。ノーマルモードとアグレッシブモードの不一致は動作不良を招く。 |
| | **設計上の注意** | ループ障害を絶対に防止するためには、ポートを物理的にシャットダウンする「アグレッシブ（Aggressive）モード」での運用を推奨。 |

---

## 🏗 動作原理

### CDP / LLDP のフレーム転送構造
CDPおよびLLDPは、直接接続されたネイバー間でのみ通信を行います。
スイッチなどのブリッジデバイスは、CDP/LLDPのマルチキャストフレームを受信すると、それを**他ポートへフォワーディングせずに廃棄（Consume）**します。

```
[ Switch A ] ------------------- ( L2 Link ) ------------------- [ Switch B ]
  (CDP / LLDP Frame)
  Destination MAC:
  - CDP:  01:00:0c:cc:cc:cc
  - LLDP: 01:80:c2:00:00:0e
  
  [Frame Sent] --------> [Rx & Process (Do not Forward)] --------> [Processed]
```

### UDLD の動作メカニズム
UDLDは、ネイバーとの間でUDLDパケット（Helloメッセージ）を双方向に交換することで機能します。パケットには「自身のデバイスID/ポートID」および「自身が検知している対向のデバイスID/ポートID」が含まれます。

```
[ Switch A ]                                                     [ Switch B ]
  Device ID: SWA                                                   Device ID: SWB
  Port: Gi0/1                                                      Port: Gi0/1

  (1) "I am SWA, on Gi0/1. I see nobody." -----------> (Normal)
  (2) <-------------------- "I am SWB, on Gi0/1. I see SWA on Gi0/1." (Normal)
  (3) "I am SWA, on Gi0/1. I see SWB on Gi0/1." ------> (Bidirectional Established)

   ※光ファイバーの対向Rx芯が断線（Switch BからのパケットがSwitch Aに届かない）
  (4) "I am SWB..." ----------------X (Rx Fiber Cut) X -----------> [ SWA sees nothing ]
  
  [結果] SWAはSWBからのパケットを失うが、自身のTxは活きているため、
        アグレッシブモードの場合、SWBへ連続プローブ送信後、ポートを err-disable へ移行させる。
```

---

## ⚙ 動作シーケンス

### UDLD アグレッシブ（Aggressive）モードの移行シーケンス

```
[正常通信状態：Bidirectional]
      │
(ファイバ断線等により、Switch Aへの単一方向通信が発生：Switch AはSwitch Bのパケットを消失)
      │
      ▼
[Switch A：UDLDタイマー満了]
      │
      ├─► 1秒間隔で連続8回のプローブ（再確認パケット）を送信。
      │   対向（Switch B）からの応答を待機。
      │
      ▼
[8回連続で応答なし（タイムアウト）]
      │
      ├─► ポートを「単一方向（Undetermined/Unidirectional）」状態と判断。
      ├─► Syslogで警告を出力。
      ├─► ポート状態を「err-disable」へ遷移させ、物理L2リンクを遮断。
      │
      ▼
[STPループおよびブラックホールの完全回避]
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EIラボ試験では、Layer 2コントロールプレーンの安定性と可用性を検証するために、CDP/LLDPおよびUDLDに関する高度な課題やトラブルシューティング（TS）問題が頻出します。

### 1. 試験で狙われやすいポイント（CDP/LLDP）
* **CDP/LLDPの特定の情報の非表示化・TLVフィルタリング:**
  「セキュリティの要件に基づき、ネイバーへOSバージョンや管理IPアドレス情報を広告しないようにせよ」という制約が出題されます。
  * **対策:** `no cdp tlv [tlv-name]` や `lldp tlv-select [tlv-name]` コマンドを用いて、必要最低限のTLVのみを許可するようにチューニングする必要があります。
* **LLDP-MEDによるPoEや音声VLANの割り当て:**
  他ベンダー機器を模擬したポートプロファイルで、LLDP-MEDを用いた音声トラフィックのQoS CoS（Class of Service）値やPoEクラス情報の連携能力が問われます。

### 2. 試験で狙われやすいポイント（UDLD）
* **STP Loop Guard と UDLD の使い分け:**
  「光ファイバーのハードウェア単一方向リンク障害により発生するSTPループを回避せよ。ただし、ソフトウェアプロセスの遅延に起因するループではなく、物理L1のTx/Rx個別障害に対応できる手法を使用すること」といった表現でUDLDの構成を要求されます。
  * **使い分け:** ソフトウェアプロセス遅延や対向のCPU高負荷に備える場合は **STP Loop Guard** を使用し、物理層の光ファイバの芯断線を検出・物理ポートを閉塞する場合は **UDLD** を使用します。
* **グローバル設定（`udld enable/aggressive`）とインターフェイス設定（`udld port/port aggressive`）の動作の差:**
  * `udld enable` / `udld aggressive`（グローバルコンフィギュレーション）: **光ファイバー（Fiber-optic）インターフェイスでのみ**UDLDが有効になります。
  * `udld port` / `udld port aggressive`（インターフェイスコンフィギュレーション）: 光ファイバーおよび**メタル（Copper/Twisted-pair）ポートの両方**でUDLDを強制的に有効にします。
  * **よくあるミス:** メタル（カッパー）ポート同士の接続であるにもかかわらず、グローバル設定のみを有効にして「UDLDが起動しない」という状態に陥る。カッパーポートでは必ずインターフェイス配下で `udld port [aggressive]` を設定してください。

### 3. トラブルシュート問題の傾向
* **CDPミスマッチによるSyslogのバースト:**
  Duplexミスマッチやネイバー同士のNative VLANミスマッチが発生している場合、CDP/LLDPはSyslogへ一定間隔でエラーを出力し続けます。これによりログが枯渇したりCPU負荷が高まるため、対向側の構成ミスを修正する、またはインターフェイスレベルで一時的にプロトコルを無効化する対処が求められます。
* **UDLDによる意図しない err-disable:**
  対向機器のUDLD設定が不足している、あるいはUDLDモード（Normal vs Aggressive）がミスマッチである場合、ポートが予期せず `err-disable`（状態: `udld`）になります。`show errdisable recovery` を用いて、自動復旧タイマーの設定や、対向側の設定確認、`udld reset` によるポート解放フローの実装ができることが必須です。

---

## 🛠 設定方法

Cisco IOS XEでの実践的なCLI構成例を示します。

### 1. CDP の基本設定

CDPはCiscoデバイスでデフォルトで有効化されていますが、試験要件に沿ってチューニングします。

```bash
# グローバルでCDPを有効化
cdp run

# 特定のTLV（例えばシステム名とOSソフトウェアバージョン）の送信を禁止する
no cdp tlv software-version
no cdp tlv system-name

# 特定のインターフェイス（外部ポート等）でCDPを個別に無効化
interface GigabitEthernet1/0/24
 no cdp enable
```

### 2. LLDP / LLDP-MED の基本設定

```bash
# グローバルでLLDPを有効化
lldp run

# 特定のインターフェイスでLLDPの送信（Tx）と受信（Rx）を個別に制御
interface GigabitEthernet1/0/1
 lldp transmit
 lldp receive
 
# LLDP-MEDによるネットワークポリシー（Voice VLAN）の定義と割り当て
network-policy profile 10
 voice vlan 100 cos 5
 
interface GigabitEthernet1/0/1
 network-policy profile 10
```

### 3. UDLD の基本設定

#### パターンA: グローバル設定（光ファイバーインターフェイスを自動対象にする場合）
```bash
# グローバルでUDLDアグレッシブモードを有効化（光ポートのみ対象）
udld aggressive
```

#### パターンB: インターフェイス指定（メタルポートや特定リンクのみアグレッシブで有効化する場合）
```bash
interface GigabitEthernet1/0/2
 # メタルポート接続の場合は、必ずインターフェイス配下で明示的に有効化する
 udld port aggressive
```

#### パターンC: UDLDで閉塞されたポートの自動復旧（errdisable recovery）
```bash
# UDLDによるポート閉塞からの自動復旧を有効化
errdisable recovery cause udld

# 復旧タイマーを300秒（デフォルト）から最短の30秒に調整
errdisable recovery interval 30
```

---

## 🔍 検証コマンド

設定状態やネイバーの確認に不可欠なコマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **CDPの動作ステータス（グローバル）** | <code>show cdp</code> |
| **CDP隣接デバイスのサマリ一覧** | <code>show cdp neighbors</code> |
| **隣接デバイスの詳細情報（IPアドレス、OS等）** | <code>show cdp neighbors detail</code> |
| **LLDPの動作ステータス（グローバル）** | <code>show lldp</code> |
| **LLDP隣接デバイスのサマリ一覧** | <code>show lldp neighbors</code> |
| **LLDP隣接デバイスの詳細情報** | <code>show lldp neighbors detail</code> |
| **UDLDの動作状態と対向情報の詳細確認** | <code>show udld GigabitEthernet1/0/2</code> |
| **UDLDの隣接関係およびポートステータスのサマリ** | <code>show udld neighbors</code> |
| **errdisableに陥っているポートの一覧と要因確認** | <code>show interfaces status err-disabled</code> |
| **CDPデバッグ（パケット送受信イベント）** | <code>debug cdp packets</code> |
| **LLDPデバッグ（パケット送受信イベント）** | <code>debug lldp packets</code> |
| **UDLDデバッグ（イベントおよび状態遷移）** | <code>debug udld events</code> |

---

## 🚨 トラブルシュート

実機演習やトラブルシューティングセクションで想定される主要なシナリオと対処法です。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **CDP/LLDPで対向デバイスが表示されない** | プロトコルがグローバルまたはインターフェイスで有効化されていない。 | <code>show cdp</code><br><code>show lldp</code> | グローバルで <code>cdp run</code>/<code>lldp run</code> を実行し、対象のインターフェイスで <code>cdp enable</code>/<code>lldp transmit\|receive</code> が有効化されているか確認。 |
| **CDPで「Native VLAN Mismatch」の警告ログがバーストする** | 対向インターフェイス同士の 802.1Q Native VLAN IDが一致していない。 | <code>show interfaces trunk</code> | 接続元と接続先スイッチのトランクポートにて、<code>switchport trunk native vlan [VLAN-ID]</code> の設定値を同一にする。 |
| **カッパー（メタル）リンクにおいて、光ファイバ用のUDLDグローバル設定を入力したが動作しない** | メタルポートではグローバルUDLD設定が自動適用されない。 | <code>show udld [INT]</code> | インターフェイス設定モードで <code>udld port [aggressive]</code> を設定する。 |
| **ポートが突如 err-disable となり、Syslogに「UDLD unidirectional link detected」が出力される** | 物理Tx/Rxの片方向のみの断線が発生した、または対向機器のUDLD設定の欠落・片側のみでのAggressive設定。 | <code>show interfaces status err-disabled</code><br><code>show udld neighbors</code> | 1. 物理層（SFPやパッチコード）の交換を実施。<br>2. 対向デバイス側のUDLD設定の整合性を確立。<br>3. 特権EXECモードで <code>udld reset</code> コマンドを実行してポートを解放。 |
| **CDP/LLDPネイバー情報の詳細から、管理IPアドレス（IPv4/IPv6）の情報が欠落している** | インターフェイスにIPアドレスが設定されていない、またはセキュリティTLVフィルタが有効化されている。 | <code>show ip interface brief</code><br><code>show running-config \| include cdp</code> | インターフェイスに有効なIPが構成されているか確認。またはTLVフィルタ設定（例: <code>no cdp tlv ip-address</code>）を解除する。 |

---

## ⚠ 制限事項

### 1. 物理層・メディアタイプの制約
* CDPおよびLLDPは、物理ポートがアップ（L1 Link Up）かつレイヤ2フォワーディングが可能なステータスでのみ機能します。
* UDLDのグローバル構成（`udld enable`）は、**光ファイバー（Fiber）インターフェイスに対してのみ有効**となります。メタル（Copper/1000BASE-Tなど）ではインターフェイスごとの指定が必須です。

### 2. ポートチャネル（EtherChannel）環境下のUDLDの挙動
* ポートチャネル上でUDLDを動作させる場合、論理インターフェイス（Port-Channel）にUDLDを適用してもメンバー物理ポートでの単一方向障害を正確に防ぐことはできません。
* **原則として、UDLDはポートチャネルを構成するすべての物理インターフェイスに対して個別に設定する必要があります。**これにより、不良となった特定の1リンクのみをポートチャネルから切り離し、ポートチャネル全体のダウンを防ぎます。

### 3. バージョン・プラットフォーム依存
* 一部の古いCisco IOSデバイスでは、LLDP-MEDがデフォルトで完全にはサポートされていない、あるいは省電力（EE802.3az）との同時利用でネゴシエーションエラーが発生することがあります。

---

## 🔄 他技術との関連

キャンパススイッチング設計において、これらのL2プロトコルは他の主要技術と高度に絡み合っています。

* **STP (Spanning Tree Protocol):** 
  UDLDはSTPを強力に補完します。STPはBPDUsの受信に基づいてループを回避しますが、L1リンクアップを維持した片方向障害が発生すると、BPDUsが受信できなくなり、ブロッキングポートがフォワーディングに移行して巨大なL2ループが発生します。UDLDアグレッシブモードが機能することで、STPより先にポートを物理的に閉塞し、ネットワーク崩壊を防ぎます。
* **PoE (Power over Ethernet):** 
  LLDP-MEDおよびCDPは、受電デバイス（PD: Powered Device）が必要とする消費電力をスイッチ（PSE: Power Sourcing Equipment）に正確にネゴシエーションするために使用されます（PoE+ / UPOE設計において必須）。
* **SD-Access (SDA) / Cisco Catalyst Center (DNA Center):** 
  Catalyst Centerがネットワーク全体のトポロジーを発見（Discovery）し、デバイスを動的にプロビジョニングする際のディスカバリープロトコルとして、CDPおよびLLDPが活用されます。
* **BFD (Bidirectional Forwarding Detection):** 
  レイヤ3のルーティングプロトコル（BGP, OSPF等）の超高速障害検知にはBFDが使用され、L2層のファイバー単一方向障害の防止・検知にはUDLDが使用されます。

---

## 🧩 比較表

### 1. CDP vs LLDP / LLDP-MED

| 比較項目 | CDP (Cisco Discovery Protocol) | LLDP (IEEE 802.1AB) / LLDP-MED |
| :--- | :--- | :--- |
| **開発規格** | Cisco独自規格（Cisco製品にデフォルトで実装） | IEEE標準規格（オープンソース、他社製混在環境用） |
| **パケットエンコード** | SNAPカプセル化 (MAC: `01:00:0c:cc:cc:cc`) | 標準イーサネット `0x88cc` (MAC: `01:80:c2:00:00:0e`) |
| **宛先MAC転送** | スイッチに届いた時点で消費（他ポートへ転送不可） | 規格上、特定のLLDPマルチキャストは同一スイッチ内で消費 |
| **VoIP対応** | CDPのVoice VLAN、PoE TLVにより自動構成 | LLDP-MEDの「Network Policy TLV」を使用して音声優先度とVLANを配信 |
| **PoE制御精度** | シスコ独自。1ミリワット単位でのネゴシエーションが可能 | IEEE 802.3at / .3bt 規格に基づいたパワーネゴシエーション |

### 2. UDLD Normal モード vs Aggressive モード

| 比較項目 | UDLD Normal モード | UDLD Aggressive モード (推奨) |
| :--- | :--- | :--- |
| **単一方向通信検知時のアクション** | ポートは **Up状態（フォワーディング）を維持**。Syslogに警告のみを出力し、状態を `Undetermined` とする。 | ポートを即座に **err-disable状態（閉塞）に移行**。物理・論理リンクを遮断する。 |
| **検知対象となる主要要因** | 物理Rx/Txの物理的断線、ポートミスマッチ。 | 物理断線に加え、対向機器のハングアップ、光ファイバトランシーバの送信部のみの故障、物理リンクアップを維持したままパケットが完全に消失するサイレント障害。 |
| **STPループ防止の有効性** | 警告のみのため、STPがフォワーディングに移行してしまい**ループを完全に防ぐことはできない。** | STPが状態遷移する前に物理リンクを落とすため、**ループを確実に防止。** |

---

## 💡 ベストプラクティス

1. **セグメントごとのCDP/LLDP有効・無効ポリシー:**
   * ネットワーク機器間（ルータ、スイッチ、WLCなど）およびIP電話、アクセスポイントが接続されるポートでは**CDP/LLDPを全面的に有効化**する。
   * 一般のクライアント端末（PC、サーバーなど）や外部ネットワーク（WANポート、DMZ）に接続されるエッジポートでは、情報漏洩（OS、IP、デバイスID等の流出）を防ぐためにインターフェイス配下で **`no cdp enable`** および **`no lldp transmit/receive`** を設定することを推奨します。
2. **光ファイバーにおけるUDLD Aggressiveの一括適用:**
   * キャンパス内の基幹（Distribution/Core間）の光ファイバリンクでは、グローバルで `udld aggressive` を一律適用し、物理ファイバ障害発生時にSTPループへ波及するのを100%防止する。
3. **errdisable recovery による運用自動化:**
   * UDLDアグレッシブによってポートがerr-disableとなった際、ファイバーパッチの交換やトランシーバの清掃後にネットワーク管理者が手動で `shutdown / no shutdown` を行う手間を削減するため、`errdisable recovery cause udld` をあらかじめ構成しておく。
4. **ポートチャネルでのLACPとの併用:**
   * LACP（Link Aggregation Control Protocol）自体にも単一方向リンク検出機能の一部が備わっていますが、検出速度と確実性の観点から、UDLDアグレッシブとLACPを物理メンバーポート上で併用することがシスコの推奨デザインです。

---

## 📝 ラボ学習・設定サンプル例

CCIE EIラボ試験レベルを網羅した10個の実践的な設定シナリオです。

### 1. CDP特定のTLV（OSバージョン情報）の配信禁止
**【問題】** 
キャンパススイッチ SW1 でセキュリティの監査基準が改訂されました。直接接続された隣接デバイスに対して、Cisco IOSのバージョン（Software Version）情報を広告しないようにグローバルで設定してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# no cdp tlv software-version
SW1(config)# end
```

**【検証方法】**
対向側のCiscoスイッチで以下のコマンドを実行し、「Software Version」フィールドが表示されない（隠蔽されている）ことを確認します。
```bash
SW2# show cdp neighbors detail
```

---

### 2. 特定のエッジインターフェイスにおけるCDPの完全無効化
**【問題】** 
SW1のインターフェイス `GigabitEthernet1/0/24` は社外のサードパーティが管理するルータに接続されています。このインターフェイスからの情報漏洩を防ぐため、CDPの送受信を完全に停止してください。なお、グローバルでのCDP機能は維持する必要があります。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/24
SW1(config-if)# no cdp enable
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show cdp interface GigabitEthernet1/0/24
# 出力に「CDP is disabled」または「GigabitEthernet1/0/24 is administratively disabled」と表示されることを確認します。
```

---

### 3. LLDPの有効化と対向パケット送受信制御
**【問題】** 
SW1で標準のネイバー自動検出機能（LLDP）を有効にしてください。ただし、`GigabitEthernet1/0/10` においては、他社製デバイスからの情報を受信（Receive）することは許可しますが、SW1自身の内部情報を隣接側へ送信（Transmit）することは禁止してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# lldp run
SW1(config)# interface GigabitEthernet1/0/10
SW1(config-if)# lldp receive
SW1(config-if)# no lldp transmit
SW1(config-if)# end
```

**【検証方法】**
SW1側で `show lldp neighbors` を実行し、Gi1/0/10の対向機器が検出されていることを確認します。一方で、対向側の他社製機器からはSW1がネイバーとして検出されなくなっていることを検証します。

---

### 4. LLDP-MEDによる音声VLAN（Voice VLAN）の配信設計
**【問題】** 
他社製のIP PhoneをSW1の `GigabitEthernet1/0/5` に収容します。LLDP-MEDのメディアTLV（Network Policy）を使用して、音声トラフィック用として VLAN 150、QoS Class of Service (CoS) 値「5」を端末へ自動適用する設定を作成してください。

**【設定例】**
```bash
SW1# configure terminal
# 1. ネットワークポリシープロファイルの定義
SW1(config)# network-policy profile voice-profile10
SW1(config-network-policy)# voice vlan 150 cos 5

# 2. インターフェイスへの割り当て
SW1(config)# interface GigabitEthernet1/0/5
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 10
SW1(config-if)# network-policy profile voice-profile10
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show lldp interface GigabitEthernet1/0/5
SW1# show lldp neighbors GigabitEthernet1/0/5 detail
# 出力内の「Media Capabilities」および「Network Policy (Voice)」セクションに、VLAN 150 および CoS 5 が含まれているか確認します。
```

---

### 5. メタル（カッパー）ポートに対するUDLDアグレッシブモードの設定
**【問題】** 
SW1とSW2は、メタルUTP（カッパー）ケーブルを介して `GigabitEthernet1/0/11` 同士で接続されています。このリンクにおいてUDLDアグレッシブ（Aggressive）モードを有効にしてください。

**【設定例】**
```bash
# SW1 側の設定
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/11
SW1(config-if)# udld port aggressive
SW1(config-if)# end

# SW2 側の設定（対向側も対称に設定することが必須）
SW2# configure terminal
SW2(config)# interface GigabitEthernet1/0/11
SW2(config-if)# udld port aggressive
SW2(config-if)# end
```

**【検証方法】**
```bash
SW1# show udld GigabitEthernet1/0/11
# 出力の「Current Bidirectional State」が「Bidirectional」になっており、
# かつ「Port-mode」または「Admin State」に「Enabled / Aggressive」が表示されていることを確認します。
```

---

### 6. 光ファイバーインターフェイスを対象としたグローバルUDLDアグレッシブの有効化
**【問題】** 
SW1に実装されているすべての光ファイバー（Fiber-optic）ポートにおいて、単一方向リンク障害が起きた際にSTPループを防止するため、グローバル設定を使用してUDLDアグレッシブモードを有効化してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# udld aggressive
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show udld
# グローバルのUDLD実行ステータスが「Enabled (Aggressive)」になっていることを確認します。
# 光ファイバインターフェイス（SFP等）の情報のみが自動的にリストアップされることを検証します。
```

---

### 7. err-disable ポートの自動回復（Recovery）設計
**【問題】** 
UDLDアグレッシブモードによって単一方向障害が検出され、スイッチのポートが `err-disable` に移行した場合、管理者の介入なしに2分（120秒）後に自動で復旧（Recovery）を試みるように構成してください。

**【設定例】**
```bash
SW1# configure terminal
# UDLDによるerr-disableの自動復旧原因リストを有効化
SW1(config)# errdisable recovery cause udld
# 復旧タイマーの間隔を120秒に設定
SW1(config)# errdisable recovery interval 120
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show errdisable recovery
# 「Errdisable Reason」の「udld」項目が「Enabled」になっており、
# 「Timer interval」が「120 seconds」であることを確認します。
```

---

### 8. UDLDメッセージのタイマーチューニング（Message Interval）
**【問題】** 
UDLDのキープアライブ（Hello）パケットが損失して err-disable に陥るまでの時間を最小限に短縮するため、UDLDメッセージの送信間隔をデフォルトの15秒から「7秒」に短縮してください。

**【設定例】**
```bash
SW1# configure terminal
SW1(config)# udld message time 7
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show udld GigabitEthernet1/0/11
# 出力情報の中の「Message interval」が「7 seconds」に更新されていることを確認します。
```

---

### 9. ポートチャネル（EtherChannel）メンバーポートにおけるUDLDの構成
**【問題】** 
SW1とSW2の間のバンドルリンク `Port-channel 1`（物理メンバー：`GigabitEthernet1/0/1` および `GigabitEthernet1/0/2`）でUDLDアグレッシブモードを正しく構成してください。片芯断線が起きた物理メンバーリンクのみを自動閉塞し、他方の正常なリンクへのトラフィック迂回を実現します。

**【設定例】**
```bash
# 論理インターフェイスではなく、物理メンバーポートに直接UDLDを適用します。
SW1# configure terminal
SW1(config)# interface range GigabitEthernet1/0/1 - 2
SW1(config-if-range)# udld port aggressive
SW1(config-if-range)# end

# SW2（対向）側
SW2# configure terminal
SW2(config)# interface range GigabitEthernet1/0/1 - 2
SW2(config-if-range)# udld port aggressive
SW2(config-if-range)# end
```

**【検証方法】**
```bash
SW1# show udld neighbors
# ポートチャネルを構成する各物理インターフェイス（Gi1/0/1, Gi1/0/2）で
# 個別に隣接するUDLDネイバーが確立（Bidirectional）されていることを確認します。
```

---

### 10. err-disable ポートの手動強制リセット（復旧）
**【問題】** 
SW1の `GigabitEthernet1/0/15` が、障害（UDLD unidirectional link detected）により `err-disable` 状態となりました。障害対策を行った後、スイッチのグローバル設定やインターフェイスのシャットダウン/ノーシャットダウンを行わずに、UDLDによって閉塞されたインターフェイスのみを一括で強制解放してください。

**【設定例】**
特権EXECモード（特権プロンプト `#` 直下）から以下を実行します。

```bash
SW1# udld reset
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/15 status
# ポートのステータスが「err-disabled」から「notconnect」または「connected」へ即時復旧していることを確認します。
```

---

## ❓ 想定試験問題

CCIE EIラボ実技試験およびデザイン試験を想定した5つの難問です。

### 1. 【Design：PoE設計とディスカバリープロトコルの依存関係】
**問題:** 
シスコ製 Catalystスイッチにサードパーティ製のワイヤレスアクセスポイント（AP）を接続したところ、APが低電力モード（最大15.4W）として起動し、十分な無線出力を提供できません。APは仕様として、IEEE 802.3at（最大30W）の電力を要求しています。スイッチ側のグローバルPoEバジェットには十分な空き（200W以上）が存在します。スイッチのログを確認したところ、以下のグローバル構成が存在していました。
`no lldp run`
この問題の根本原因を、PoEパワーネゴシエーションとプロトコルの関連から論理的に説明し、解決策を提示してください。

**解答・解説:**
* **根本原因:** 
  CiscoスイッチはデフォルトでCisco独自プロトコル（CDP）を用いて受電デバイスと詳細な電力ネゴシエーション（CiscoパワーネゴシエーションTLV）を行います。しかし、接続された受電デバイス（PD）は他社（サードパーティ）製APであるため、CDPを解釈できません。他社製機器がIEEE 802.3at PoE+などの電力をスイッチから引き出すには、業界標準プロトコルである **LLDP（具体的には LLDP-MEDのPower-via-MDI TLV）** を経由して電力クラスをネゴシエーションする必要があります。グローバルで `no lldp run` が設定され、LLDPプロセスが停止しているため、スイッチは対向が他社製APであることを詳細に確認できず、ハードウェアクラスの標準のデフォルトクラス（15.4W以下）として安全側に電力を制限してしまいます。
* **解決策:** 
  スイッチのグローバルコンフィギュレーションで `lldp run` コマンドを実行してLLDPを起動し、必要に応じてインターフェイス配下で `lldp transmit` および `lldp receive` を有効化することで、LLDP-MEDを介した30W給電のネゴシエーションを成立させます。

---

### 2. 【Troubleshooting：STPループのバーストとUDLDの不整合】
**問題:** 
光ファイバーで接続された2台のスイッチ（SW1 - SW2）間で、深夜に突如としてスパニングツリー（RSTP）によるブロードキャストストーム（L2ループ）が発生し、キャンパス全体の通信がダウンしました。
管理者が確認したところ、SW1とSW2を接続するインターフェイス（Gi1/0/49）は光ポートであり、SW1の当該インターフェイスの設定には `udld port`（Normalモード相当）が投入されており、対向のSW2にはUDLDの設定が全く存在していませんでした。
光ファイバーパッチコード（Tx/Rx分離）のRx芯が経年劣化により損傷した際、なぜNormalモードのUDLDではこのL2ループを防げなかったのか説明してください。また、ループを100%防止するための最善の設定変更手順を記載してください。

**解答・解説:**
* **Normalモードで防げなかった理由:**
  UDLDの **Normalモード** は、単一方向リンク障害（片芯断線）を検知した場合、Syslogに警告を出力しポートの状態を「Undetermined（未定義）」に変更しますが、**ポートのパケット転送（フォワーディング）自体は物理・論理ともに維持します**。
  BPDUsがRx断線により届かなくなった対向側（SW1）は、トポロジー上に代替パスがあると解釈し、本来ブロック（Blocking）であるべきポートを「フォワーディング（Forwarding）」に遷移させてしまい、片方向のデータパケットだけがループする最悪のL2ループが発生します。
* **最善の設定変更手順:**
  ポートをerr-disableとして物理的に閉塞する **UDLDアグレッシブ（Aggressive）モード** を双方向のスイッチで明示的に有効にします。
  ```bash
  # SW1 側
  interface GigabitEthernet1/0/49
   udld port aggressive
  
  # SW2 側
  interface GigabitEthernet1/0/49
   udld port aggressive
  ```

---

### 3. 【Config：特定のCDP情報の隠蔽とセキュリティ要件】
**問題:** 
SW1の `GigabitEthernet1/0/20` の対向に、パートナー企業が管理するスイッチが接続されています。パートナー企業からの要求に基づき、ネイバーの確認（CDP隣接関係）は維持しつつ、SW1が動作している詳細なオペレーティングシステム情報（Software Version TLV）のみをフィルタして対向へ送信しないように設定してください。

**解答・解説:**
* **アプローチ:** 
  グローバルの `no cdp tlv software-version` を適用すると、スイッチ全体のすべてのインターフェイスでOSバージョン情報の広告が停止します。特定のポート（Gi1/0/20）だけを対象にする必要がある場合は、CDPのフィルタはグローバル適用となるため、グローバルで `no cdp tlv software-version` を実行します。
* **設定コマンド:**
  ```bash
  SW1(config)# no cdp tlv software-version
  ```

---

### 4. 【Troubleshooting：err-disable復旧プロセスの動作検証】
**問題:** 
SW1の `GigabitEthernet1/0/22` が、UDLDによる単一方向検出エラーのために err-disable 状態になっています。物理パッチコードを新品の正常品に交換したところ、30秒が経過してもインターフェイスが `err-disabled` から回復（UP）しません。
スイッチの現在設定を確認したところ、以下が確認されました。
`errdisable recovery cause udld`
`errdisable recovery interval 30`
物理ケーブルを修復したにもかかわらず、即座にポートが回復しない理由をCisco IOS-XEの仕様に基づいて解説し、対向デバイス側で確認すべきプロセスを提示してください。

**解答・解説:**
* **ポートが回復しない理由と仕様:**
  `errdisable recovery` の30秒タイマーは、**「最後にインターフェイスが err-disable 状態になってから経過した時間」**を指します。30秒間隔の内部プロセス処理（タイマーポーリング）により自動で `no shutdown` を実行してポートを再試行（Attempt）させます。
  しかし、再試行した瞬間に、対向側のデバイスが依然としてUDLDパケットを正常に受信できていない（対向側がUDLDアグレッシブで同じくerr-disableになったまま閉塞されている、あるいは対向側の設定が不足している）場合、**ポートが一度UPした直後にUDLDの双方向アソシエーションの確立に再び失敗し、即座に再度 err-disable へと逆戻りします**。このため、ポートが永久にアップとダウン（err-disable）をループするか、ダウンから回復しないように見えます。
* **確認すべきプロセス:**
  対向側スイッチ（SW2）のポートステータスを確認し、SW2側でも `udld reset` を実行するか、または両端のインターフェイスで `shutdown` / `no shutdown` を手動で同期させて、双方向で同時にUDLDパケット（Hello）のネゴシエーションが再開できるようにする必要があります。

---

### 5. 【Design：BFD と UDLD の使い分けと適用レイヤ】
**問題:** 
L3スイッチで構築された大規模なマルチレイヤバックボーンにおいて、光ファイバー接続を使用したOSPFネイバーが確立されています。
設計会議において、「UDLDアグレッシブを設定しているため、L3のBFD（Bidirectional Forwarding Detection）を有効にする必要はない」という意見が出されました。この意見に対する技術的な適否を、各プロトコルの動作レイヤ（Layer 2 vs Layer 3）および目的（ループ回避 vs コンバージェンス高速化）のトレードオフを交えて評価してください。

**解答・解説:**
* **評価:** 
  この意見は**不適切（誤り）**です。UDLDとBFDは目的および動作するプロトコルスタックの階層が完全に異なります。
  1. **動作レイヤの差:** 
     * **UDLD:** レイヤ2（データリンク層）プロトコル。物理層およびMAC層レベルの片方向リンクを検知し、主にスパニングツリー（L2）のループ障害を防ぐ目的で使用されます。
     * **BFD:** レイヤ3以上（および特定のルーティングプロトコル、スタティックルート、MPLS LSPsなど）に紐付き、サブ秒（30ミリ秒など）レベルでの超高速な双方向パス障害の検知を行います。
  2. **障害検知とコンバージェンス速度の差:** 
     * UDLDはデフォルトで15秒（チューニングしても数秒程度）のタイマーで動作するため、高速なL3ルーティングの再計算（Fast Convergence）には耐えられません。
     * BFDは1秒未満（ミリ秒単位）で障害を隣接ルーティングプロセス（OSPF/BGP等）へ伝達し、瞬時の経路切り替えをトリガーします。
  * **結論:** 
     物理的なL2トループや片芯障害を防ぐ基盤として **UDLD** を有効化しつつ、L3バックボーンのコンバージェンス速度（パケットロスの最小化）を確保するために **BFD** を個別に併用するのが正しいハイエンドキャンパス設計のベストプラクティスです。

---

## 🔗 参考リソース

### Cisco Live (スライド・オンデマンド)
* [**BRKCRS-2031: Enterprise Campus Design - Layer 2 Control Plane Best Practices**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031)
  * キャンパスにおけるCDP/LLDPおよびUDLD/STP連携設計の集大成。
* [**BRKARC-3437: Cisco Catalyst 9000 Switching Architecture Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-3437)
  * ASIC（UADP）上におけるL2/L3プレフィルタリングとコントロールプレーン保護の関係。

### Configuration ガイド（シスコ公式）
* [**Cisco Catalyst 9300 Series Switches: Software Configuration Guide, Layer 2 Protocols**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/lyr2/b_17x_lyr2_9300_cg.html)
  * CDP, LLDP, LLDP-MED, およびUDLDの全機能の実装ガイドライン。
* [**Cisco IOS XE 17.x: Command Reference, Layer 2 Protocols**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/command_reference/b_17x_lyr2_9300_cr.html)
  * `udld port aggressive` や `lldp tlv-select` などのコマンドシンタックス一覧。

### テクニカルノート・設定例
* [**Understanding and Configuring the Unidirectional Link Detection Protocol (UDLD) Feature**](https://www.cisco.com/c/en/us/support/docs/lan-switching/spanning-tree-protocol/10556-16.html)
  * UDLDのタイマー動作、アグレッシブモードのステートマシン、トラブルシューティングに関する公式テクニカルノーツ。
* [**Integrating IP Telephony in Cisco Campus Networks (CVD)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)
  * CDPおよびLLDP-MEDによる音声VLANとPoEネゴシエーションのシスコ検証済みデザイン（CVD）。

---

## 📝 **補足（Notes）**

* **学習メモ（CDP/LLDP情報制限による hardening）:**
  試験中に「デバイスの構成情報を不要に隣接へ漏らさないようにせよ（L2 Security Hardening）」と指示された場合、CDPの無効化（`no cdp run`）だけでなく、特定のポートに対して `no cdp enable` を適用することが定石です。
* **UDLD状態遷移図:**
  ```text
  [Link Up / Shutdown] ──► [Normal/Aggressive State: Detection Phase]
                                      │
               (対向からHelloを受信し、自ポートIDが含まれていることを確認)
                                      │
                                      ▼
                             [Bidirectional State]
                                      │
                (対向からのパケットが途絶え、プローブ(8回)応答がゼロ)
                                      │
                                      ▼
               [Unidirectional (Aggressive Mode: err-disabled)]
  ```
* **注意点:** 
  UDLDアグレッシブモードは、対向デバイスのCPUがスパイク（超高負荷）した結果、対向デバイスが一時的にUDLDパケットを送信できなくなった際にも機能してしまいます。この場合、物理障害がないにもかかわらずポートが `err-disable` になる「偽陽性（False Positive）」が発生することがあります。これを防ぐため、対向デバイス側のコントロールプレーン（CoPP）の設定を最適化しておくことが、CCIE EIインフラ設計において重要です。


### この項で使用されるコマンド

#### Layter 2 Protocols

```md
# ===============================
# IEEE 802.1Q Tunneling Configuration
# ===============================

## トンネルポートとして設定（顧客側 VLAN を受ける）
Switch1(config-if)# ! トンネルポートのアクセス VLAN を設定
Switch1(config-if)# switchport access vlan <VLAN-ID>

Switch1(config-if)# ! インターフェイスを dot1q-tunnel に設定
Switch1(config-if)# switchport mode dot1q-tunnel

## Native VLAN を常にタグ付け（誤配送防止）
Switch1(config)# ! Native VLAN をタグ付けして誤配送を防止
Switch1(config)# vlan dot1q tag native

## dot1q-tunnel の状態確認
Switch1# ! dot1q-tunnel の設定確認
Switch1# show dot1q-tunnel

Switch1# ! 特定インターフェイスのトンネル状態確認
Switch1# show dot1q-tunnel interface <interface-id>

Switch1# ! Native VLAN tagging 状態確認
Switch1# show vlan dot1q tag native
```

```md
# ===============================
# Layer 2 Protocol Tunneling Configuration
# ===============================

## L2 Protocol Tunneling を有効化（CDP / STP / VTP）
Switch1(config-if)# ! CDP をトンネリング
Switch1(config-if)# l2protocol-tunnel cdp

Switch1(config-if)# ! STP をトンネリング
Switch1(config-if)# l2protocol-tunnel stp

Switch1(config-if)# ! VTP をトンネリング
Switch1(config-if)# l2protocol-tunnel vtp

## PAgP / LACP / UDLD の point-to-point トンネリング
Switch1(config-if)# ! PAgP を point-to-point トンネリング
Switch1(config-if)# l2protocol-tunnel point-to-point pagp

Switch1(config-if)# ! LACP を point-to-point トンネリング
Switch1(config-if)# l2protocol-tunnel point-to-point lacp

Switch1(config-if)# ! UDLD を point-to-point トンネリング
Switch1(config-if)# l2protocol-tunnel point-to-point udld

## Shutdown Threshold（PDU が多すぎる場合にポート shutdown）
Switch1(config-if)# ! CDP の shutdown-threshold を設定
Switch1(config-if)# l2protocol-tunnel shutdown-threshold 100 cdp

Switch1(config-if)# ! STP の shutdown-threshold を設定
Switch1(config-if)# l2protocol-tunnel shutdown-threshold 100 stp

Switch1(config-if)# ! VTP の shutdown-threshold を設定
Switch1(config-if)# l2protocol-tunnel shutdown-threshold 100 vtp

Switch1(config-if)# ! point-to-point PAgP の shutdown-threshold
Switch1(config-if)# l2protocol-tunnel shutdown-threshold point-to-point pagp 100

## Drop Threshold（PDU をドロップする閾値）
Switch1(config-if)# ! CDP の drop-threshold を設定
Switch1(config-if)# l2protocol-tunnel drop-threshold 50 cdp

Switch1(config-if)# ! STP の drop-threshold を設定
Switch1(config-if)# l2protocol-tunnel drop-threshold 50 stp

Switch1(config-if)# ! VTP の drop-threshold を設定
Switch1(config-if)# l2protocol-tunnel drop-threshold 50 vtp

Switch1(config-if)# ! point-to-point PAgP の drop-threshold
Switch1(config-if)# l2protocol-tunnel drop-threshold point-to-point pagp 500

## トンネリング時の CoS（優先度）設定
Switch1(config)# ! トンネル PDU の CoS を設定
Switch1(config)# l2protocol-tunnel cos 7

## L2PT による errdisable の自動復旧
Switch1(config)# ! L2PT による errdisable を自動復旧
Switch1(config)# errdisable recovery cause l2ptguard

## L2 Protocol Tunneling の状態確認
Switch1# ! L2PT の状態確認
Switch1# show l2protocol

Switch1# ! 特定インターフェイスの L2PT 状態確認
Switch1# show l2protocol-tunnel interface <interface-id>

Switch1# ! L2PT のサマリ確認
Switch1# show l2protocol-tunnel summary
```

```md
# ===============================
# SP Edge Switch Configuration
# ===============================

## dot1q-tunnel ポート設定
Switch1(config-if)# ! 顧客 VLAN を受けるアクセス VLAN 設定
Switch1(config-if)# switchport access vlan <VLAN-ID>

Switch1(config-if)# ! トンネルポート化
Switch1(config-if)# switchport mode dot1q-tunnel

## point-to-point トンネリング（PAgP / UDLD）
Switch1(config-if)# ! PAgP トンネリング
Switch1(config-if)# l2protocol-tunnel point-to-point pagp

Switch1(config-if)# ! UDLD トンネリング
Switch1(config-if)# l2protocol-tunnel point-to-point udld

## Drop Threshold 設定
Switch1(config-if)# ! PAgP の drop-threshold
Switch1(config-if)# l2protocol-tunnel drop-threshold point-to-point pagp 1000

## BPDU Filter（dot1q-tunnel では自動有効）
Switch1(config-if)# ! BPDU Filter を明示的に有効化
Switch1(config-if)# spanning-tree bpdu filter enable

## CDP 無効化（dot1q-tunnel では自動無効）
Switch1(config-if)# ! CDP を無効化
Switch1(config-if)# no cdp enable
```

```md
# ===============================
# Customer Switch Configuration
# ===============================

## IEEE 802.1Q trunk 設定
Switch1(config-if)# ! dot1q トランクを設定
Switch1(config-if)# switchport trunk encapsulation dot1q

Switch1(config-if)# ! トランクモードを有効化
Switch1(config-if)# switchport mode trunk

## UDLD Normal モードを有効化
Switch1(config-if)# ! UDLD Normal を有効化
Switch1(config-if)# udld port

## EtherChannel（PAgP desirable）
Switch1(config-if)# ! EtherChannel グループに参加
Switch1(config-if)# channel-group <ID> mode desirable

## Port-Channel の再起動
Switch1(config)# ! Port-Channel を shutdown → no shutdown
Switch1(config)# interface port-channel <ID>
Switch1(config-if)# shutdown
Switch1(config-if)# no shutdown
```

#### (i) CDP, LLDP 

```md
# ===============================
# CDP Global Configuration
# ===============================

## CDP の送信間隔を 20 秒に設定
Switch1(config)# ! CDP の送信間隔を 20 秒に設定
Switch1(config)# cdp timer 20

## CDP 情報保持時間を 60 秒に設定
Switch1(config)# ! CDP 情報保持時間を 60 秒に設定
Switch1(config)# cdp holdtime 60

## CDP Version 2 広告を送信（デフォルトで有効）
Switch1(config)# ! CDP Version 2 広告を送信
Switch1(config)# cdp advertise-v2

## CDP を無効化（グローバル）
Switch1(config)# ! CDP を無効化
Switch1(config)# no cdp run

## CDP を再有効化（グローバル）
Switch1(config)# ! CDP を有効化
Switch1(config)# cdp run


# ===============================
# CDP Interface Configuration
# ===============================

## 特定インターフェイスで CDP を無効化
Switch1(config-if)# ! インターフェイスで CDP を無効化
Switch1(config-if)# no cdp enable

## 特定インターフェイスで CDP を有効化
Switch1(config-if)# ! インターフェイスで CDP を有効化
Switch1(config-if)# cdp enable


# ===============================
# CDP Monitoring Commands
# ===============================

## CDP カウンタをリセット
Switch1# ! CDP カウンタをリセット
Switch1# clear cdp counters

## CDP テーブルを削除
Switch1# ! CDP テーブルを削除
Switch1# clear cdp table

## CDP グローバル情報を表示
Switch1# ! CDP グローバル情報を表示
Switch1# show cdp

## 特定ネイバーの CDP 情報を表示
Switch1# ! 特定ネイバーの CDP 情報を表示
Switch1# show cdp entry <entry-name>

## CDP が有効なインターフェイスを表示
Switch1# ! CDP が有効なインターフェイスを表示
Switch1# show cdp interface

## CDP ネイバー情報を表示
Switch1# ! CDP ネイバー情報を表示
Switch1# show cdp neighbors

## CDP ネイバー詳細情報を表示
Switch1# ! CDP ネイバー詳細情報を表示
Switch1# show cdp neighbors detail

## CDP トラフィック統計を表示
Switch1# ! CDP トラフィック統計を表示
Switch1# show cdp traffic

## CDP を Layer-2 Protocol Tunneling で転送
Switch1(config-if)# ! CDP をトンネリング
Switch1(config-if)# l2protocol-tunnel cdp

## CDP トンネリングの shutdown-threshold 設定
Switch1(config-if)# ! CDP の PDU が閾値を超えたら shutdown
Switch1(config-if)# l2protocol-tunnel shutdown-threshold 100 cdp

## CDP トンネリングの drop-threshold 設定
Switch1(config-if)# ! CDP の PDU を一定値でドロップ
Switch1(config-if)# l2protocol-tunnel drop-threshold 50 cdp
```

```md
# ===============================
# LLDP Configuration
# ===============================

## LLDP を無効化
Switch1(config-if)# ! LLDP を手動で無効化
Switch1(config-if)# no lldp transmit
Switch1(config-if)# no lldp receive

## LLDP 状態確認
Switch1# ! LLDP の状態確認
Switch1# show lldp neighbors
```
---

#### (ii) UDLD

```md
# ===============================
# UDLD Configuration (3750-X/3560-X)
# ===============================

## UDLD Normal モードを有効化
Switch1(config-if)# ! UDLD Normal を有効化
Switch1(config-if)# udld port

## UDLD Aggressive モードを有効化
Switch1(config-if)# ! UDLD Aggressive を有効化
Switch1(config-if)# udld port aggressive

## UDLD を Layer-2 Protocol Tunneling で転送（point-to-point）
Switch1(config-if)# ! UDLD をトンネリング
Switch1(config-if)# l2protocol-tunnel point-to-point udld

## UDLD トンネリングの shutdown-threshold 設定
Switch1(config-if)# ! UDLD PDU が閾値を超えたら shutdown
Switch1(config-if)# l2protocol-tunnel shutdown-threshold point-to-point udld 100

## UDLD トンネリングの drop-threshold 設定
Switch1(config-if)# ! UDLD PDU を一定値でドロップ
Switch1(config-if)# l2protocol-tunnel drop-threshold point-to-point udld 50

## UDLD 状態確認
Switch1# ! UDLD の状態確認
Switch1# show udld interface
Switch1# show l2protocol-tunnel interface gigabitethernet1/0/1
```
