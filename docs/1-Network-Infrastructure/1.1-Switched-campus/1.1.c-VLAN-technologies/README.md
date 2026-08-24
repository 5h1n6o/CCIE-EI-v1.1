---
layout: default
title: 1.1.c-VLAN-technologies
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.1.c VLAN technologies (Access, Trunk, Native, Pruning, Normal/Extended, Voice VLAN)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 実技試験（Practical Exam）および筆記試験において極めて重要なキャンパスLANスイッチング技術である、**Access ports（アクセスポート）**、**Trunk ports（トランクポート）**、**Native VLAN（ネイティブVLAN）**、**Manual VLAN pruning（マニュアルVLANプルーニング）**、**Normal/Extended range VLANs（ノーマル/拡張範囲VLAN）**、および **Voice VLAN（ボイスVLAN）** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ）の実装基準に準拠したExpertレベルの学習メモを記述します。

---

## 📘 概要

エンタープライズのスイッチドキャンパスネットワークにおいて、VLAN（Virtual Local Area Network）は単一の物理スイッチ構造を複数の独立した論理ブロードキャストドメインに分割する、すべてのネットワーク仮想化の基盤です。

### 1. Access ports
単一のVLANに所属し、主にエンドデバイス（PC、プリンタ、サーバー、各種端末）を収容するためのインターフェイスです。ポートを通過するイーサネットフレームには、802.1Qタグは付与されず、プレーンなイーサネットフレームとして転送されます。

### 2. Trunk ports (802.1Q)
単一の物理リンク（またはPort-Channel論理リンク）上で、複数のVLANトラフィックを多重化して送受信するためのインターフェイスです。業界標準規格である **IEEE 802.1Q** タグ（4バイト）をフレームヘッダーに挿入することで、各フレームが所属するVLANを識別可能にします。

### 3. Native VLAN
802.1Qトランクリンクにおいて、**「タグを付与せずに（Untaggedで）」**送受信される特別なVLANです。デフォルトではVLAN 1がネイティブVLANとして定義されていますが、コントロールプレーンパケット（CDP, LLDP, SSTP, DTP等）の透過や、レガシーハブ接続時の整合性を維持するために存在します。

### 4. Manual VLAN pruning
トランクリンクを通過可能なVLANを、送信スイッチの段階で明示的かつ「手動で」制限する（フィルタリングする）技術です。デフォルトではすべてのVLAN（1-4094）がトランク上に許可されますが、不要なVLANのブロードキャストやマルチキャストトラフィック、さらにSTP（Spanning Tree Protocol）のトポロジーチェンジ（TC）の影響が他のスイッチへ伝搬するのを局所的に防止するために行います。

### 5. Normal range and extended range VLANs
*   **Normal range (ノーマル範囲):** VLAN ID 1～1005。この範囲のVLAN情報は、VTP（VLAN Trunking Protocol）のモードがServer/Clientであれば、VLANデータベースファイル（`vlan.dat`）に保存され、ネイバー間で同期されます。
*   **Extended range (拡張範囲):** VLAN ID 1006～4094。サービスプロバイダ網や大規模SD-Access、EVPN-VXLANインフラなどの大規模テナント分離に用いられます。Cisco IOS-XE環境（VTP v3）の登場により、Extended rangeの取り扱いやデータベース同期プロセスが大きく強化されました。

### 6. Voice VLAN
1つの物理スイッチポート上に、データ用のVLAN（Access VLAN）とIP電話などの音声端末用のVLAN（Voice VLAN）を同時に多重化して収容する技術です。これにより、IP電話と背後のPCを単一のイーサネット配線で収容し、かつQoS（Quality of Service）の優先度制御を論理的に切り分けることができます。

---

## 🔑 要点

各VLAN技術の機能要件、メリット、制限事項を整理します。

| 技術要素 | 項目 | 詳細内容 |
| :--- | :--- | :--- |
| **Access ports** | **特徴** | 単一のVLANにのみ所属。802.1Qタグなしでパケットを送受信。 |
| | **用途** | クライアントPC、プリンタ、単一のIP収容を行うサーバーの接続。 |
| | **設計上の注意** | セキュリティの観点から、ダイナミックネゴシエーション（DTP）を完全に無効化（`switchport nonegotiate`）する。 |
| **Trunk ports** | **特徴** | IEEE 802.1Qに基づく4バイトタグの挿入（EtherType: `0x8100`）。 |
| | **用途** | スイッチ間の相互接続、ルータとのインターVLAN接続（Router-on-a-Stick）、ファイアウォール・WLCの物理集約。 |
| | **設計上の注意** | カプセル化方式としてレガシーなISLは現行ハードウェアで非サポートであり、Dot1qが暗黙の前提。 |
| **Native VLAN** | **特徴** | トランクポート上でタグなし（Untagged）として処理される基準VLAN。 |
| | **用途** | CDP, LLDP, LACP などの管理プレーンの制御。 |
| | **設計上の注意** | **VLAN Hopping（VLANホッピング攻撃）を防止するため、ポートのNative VLANとデータ通信用VLAN（VLAN 1など）を一致させず、一切のクライアントが収容されていない孤立したダミーVLAN（例: VLAN 999）に変更し、かつタグなしフレームをドロップまたは強制タギングする設計が鉄則。** |
| **Manual Pruning** | **特徴** | トランクリンク上の許可VLANリスト（Allowed list）をマニュアル設定。 |
| | **用途** | 宛先不明ユニキャスト、ブロードキャストフラッディングのWAN/コアドメインへの流出抑止。 |
| | **設計上の注意** | `switchport trunk allowed vlan` 設定時、誤って `add` オプションを付け忘れると、現在トランク上を通っている既存VLANが一括で削除される致命的な設定ミス（CCIEラボでの失点要因）が発生しやすい。 |
| **VLAN Range**| **特徴** | Normal (1-1005) と Extended (1006-4094) の分類。 |
| | **用途** | エンタープライズ内部のセグメント設計、VXLAN VNIへのマッピング。 |
| | **設計上の注意** | VTP v1/v2 では、スイッチが「Transparent モード」のときしか拡張範囲（1006-4094）を作成・保存できない。**VTP v3 を使用することで、初めて Server モードのまま拡張範囲VLANの同期・管理および保存が可能になる。** |
| **Voice VLAN** | **特徴** | 単一のポート上で、データと音声を異なるVLANヘッダーで識別し、QoS優先制御。 |
| | **用途** | Cisco IP Phone や他社製 VoIP 電話の収容、UC（Unified Communications）インフラ。 |
| | **設計上の注意** | ポートセキュリティや802.1X認証を有効化する場合は、ポートに対して「マルチドメイン認証（MDA）」を正確に設定する必要がある。 |

---

## 🏗 動作原理

### 1. 802.1Qタグの挿入構造と VLAN Hopping 攻撃の脆弱性
トランクポートを通過するイーサネットフレームには、ソースMACアドレスとEtherTypeの間に4バイトの802.1Qヘッダーが挿入されます。

```text
  [ 標準イーサネットフレーム ]
  ┌──────────┬──────────┬──────────┬──────────┬──────────┐
  │   DMAC   │   SMAC   │EtherType │ Payload  │   FCS    │
  └──────────┴──────────┴──────────┴──────────┴──────────┘
                         ▲ ここに挿入
                         ▼
  [ 802.1Qタグ付きフレーム ]
  ┌──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
  │   DMAC   │   SMAC   │  TPID    │   TCI    │Payload...│   FCS    │
  │ (6 bytes)│ (6 bytes)│ (0x8100) │ (2 bytes)│          │          │
  └──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
                                      ▲ 
                                      ├─► PCP (3-bit QoS Priority - CoS)
                                      ├─► DEI (1-bit Drop Eligible Indicator)
                                      └─► VID (12-bit VLAN ID: 0～4095)
```

#### 【注意：VLAN Hopping（ダブルタギング）の発生メカニズム】
攻撃者がVLAN 1（ネイティブVLAN）に所属するアクセスポートに接続していると仮定します。
1.  攻撃者は、アウタータグに「VLAN 1」、インナータグに標的VLAN（例: 「VLAN 10」）を二重に付与したフレーム（Double-tagged frame）をスイッチに送信します。
2.  スイッチがこのパケットをトランクリンクへ送出する際、**「アウタータグ（VLAN 1）がトランクポートのネイティブVLANと一致しているため、ネイティブVLANの仕様に従ってアウタータグを除去（Stripped/Untagged）」** します。
3.  対向のスイッチは、アウタータグが除去されたことによって露出した**「インナータグ（VLAN 10）」のみを認識**し、パケットをVLAN 10のポートへと転送（Hopping）してしまいます。
    *   **防御策:** `vlan dot1q tag native` コマンドにより、トランクを流れるネイティブVLANパケットに対しても強制的にタグを付与するか、ネイティブVLANをユーザーパケットが存在しない未使用のダミーVLANに固定します。

### 2. Voice VLANにおけるパケット多重化とCDP/LLDP-MEDシーケンス
単一ポート配下で動作するIP Phoneは、スイッチとの間でCDP（または他社製端末用のLLDP-MED）を動作させることで、自身が音声トラフィックをどのVLAN（Voice VLAN）でタギングして送信すべきかを取得します。

```text
        [ IP Phone (Cisco) ]                                            [ Switch (Catalyst) ]
                │                                                             │
                │ 1. 物理リンクアップ（L1 UP） ────────────────────────────────►│
                │                                                             │
                │◄ 2. 給電ネゴシエーション（PoE/PoE+ 起動） ─────────────────────│
                │                                                             │
                │◄ 3. CDP / LLDP-MED フレーム受信 ──────────────────────────────│
                │    「Voice VLAN ID is 150. DSCP is EF (CoS 5)」              │
                │                                                              │
                │ 4. 以降、IP Phoneはパケットを2系統で送受信 ─────────────────────│
                │                                                              │
                ├─► [ 音声パケット: 802.1Q Tagged = VLAN 150 (CoS 5) ] ─────────┤
                │                                                              │
                └─► [ PCのパケット: Untagged (スイッチが受信時に Access VLAN 10 へバインド) ]
```

---

## ⚙ 動作シーケンス

### スイッチポートにおける受信フレームの処理フロー

パケットがインプレスポジション（スイッチの物理ポートに入力された瞬間）から、VLAN割り当て、トランク転送されるまでの内部ASIC処理プロセスを示します。

```
( フレーム受信 )
       │
       ▼
[ インフラ上のタグ（Dot1q）の有無を確認 ]
       │
       ├─► Tagあり ➔ [ トランクポートの場合 ] ➔ タグ内の VLAN ID がポートの「Allowedリスト」に存在するか？
       │                    │    ├─► Yes ➔ タグを維持してVLANベースでL2ルックアップ
       │                    │    └─► No  ➔ 【破棄（Drop）】
       │                    │
       │                    └─► [ アクセスポートの場合 ] ➔ 原則的にタグなしのみ受付（一部のCoSタグ/Tag0例外を除き【破棄】）
       │
       └─► Tagなし ➔ [ アクセスポートの場合 ] ➔ ポートに設定された「Access VLAN ID」を内部的に付与（PVID割り当て）
                            │
                            └─► [ トランクポートの場合 ] ➔ ポートに設定された「Native VLAN ID」を内部的に付与
                                     │
                                     ▼
                        [ VLAN Allowedリストおよび Pruning チェック ]
                                     │
                                     ├─► 送出ポートがトランクであり、 Allowedリストに該当VLANが登録されているか？
                                     │    ├─► Yes ➔ [ 送出ポートの Native VLAN と一致するか？ ]
                                     │    │              ├─► 一致 ➔ 【タグを除去（Untagged）して送出】
                                     │    │              └─► 不一致 ➔ 【対象のVLAN IDタグを挿入して送出】
                                     │    │
                                     │    └─► No  ➔ 【送信ポートでのプルーニング（ブロック/フィルタ）】
                                     │
                                     └─► 送出ポートがアクセスポート ➔ 【タグを除去してプレーンなフレームとして送出】
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、VLANコントロールテクノロジーは、Infrastructureの最もベースとなる得点源である一方、設定不整合によるSTP崩壊、DTPのチート、ボイスフォン不通などの複合トラブルの原因として高頻度で狙われます。

### 1. DTP（Dynamic Trunking Protocol）の排除要件
*   **試験での指示方法:** 
    「L2セキュリティ硬化（Hardening）基準に従い、スイッチ間相互接続リンクにおいて意図しないトランクネゴシエーションを防ぎ、静的に構成せよ。ポートはトランクであることを強制し、ネゴシエーションフレームの送出を一切禁止すること」
    *   **よくある間違い:** 単に `switchport mode trunk` を設定して安心する。これだけでは、トランクポートは依然として対向に対して DTP フレーム（Desirable/Autoネゴシエーション）を送信し続けています。
    *   **正しい対策:** 
        ```bash
        switchport mode trunk
        switchport nonegotiate
        ```
        この **`switchport nonegotiate`** コマンドを追加することで、初めてDTPフレームの送信が完全に停止し、セキュリティセキュリティ要件（チート対策）が完了します。
    *   **注意点:** `switchport mode dynamic desirable/auto` が設定されているインターフェイスに対して `switchport nonegotiate` コマンドを実行しようとすると、CLIで競合エラー（Conflict）が発生します。必ず静的なモード（`access` または `trunk`）に固定してから入力する必要があります。

### 2. Native VLAN 構成における落とし穴とトランスポート
*   **Native VLAN 不一致時のSyslogバースト:** 
    対向スイッチ同士で Native VLAN の設定が不一致（例: SW1側は VLAN 10、SW2側は VLAN 20）である場合、Cisco IOS-XEはCDPを介してこれを検知し、Syslogに一定間隔で以下の深刻な警告ログを出力し続けます。
    `%CDP-4-NATIVE_VLAN_MISMATCH: Native VLAN mismatch discovered on GigabitEthernet1/0/1 (10), with SW2 GigabitEthernet1/0/1 (20).`
    このログが出ている状態は、スパニングツリー（PVST+）のBPDUs送受信にも不整合を引き起こし、一時的なループやポートの不完全閉塞（`*PVID_Inc` 状態）を招くため、ラボ試験では速やかに両端の Native VLAN ID を一致させるトラブルシューティングが要求されます。
*   **Native VLANのタギング要件:**
    「セキュリティポリシーにより、トランクポートGi1/0/1を通過するすべてのトラフィック（ネイティブVLANトラフィックを含む）には、識別用のIEEE 802.1Qタグが常に付加されていなければならない」
    *   **対策:** グローバルコンフィギュレーションで以下のコマンドを投入します。
        ```bash
        vlan dot1q tag native
        ```

### 3. VTPバージョンによるExtended Range VLANの制限
*   **VTP v1 / v2 の制限事項:** 
    VTPのモードがデフォルトの「Server（サーバー）」または「Client（クライアント）」に設定されている場合、VLAN 1006〜4094（拡張範囲）のVLANを追加しようとすると、スイッチは作成を拒否します。
    *   VTP v1/v2 で Extended Range VLAN を使用するには、**VTP モードを明示的に「Transparent（トランスペアレント）」または「Off（無効）」に変更しなければなりません。**
*   **VTP v3 での解決:** 
    **VTP v3 を使用すると、Server モードのままで Extended Range VLAN（1006-4094）を自由に追加・編集できるようになり、同期データベース（vlan.dat）に組み込まれてトポロジー全体のスイッチへと動的に同期されます。** 試験で大規模なVLANテーブル（Extended VLANを含む）を自動同期させる要件がある場合は、VTP v3の構成が第一の選択肢となります。

### 4. Voice VLAN の実装オプションの使い分け
`switchport voice vlan` コマンドには、CCIE試験で狙われやすい4つのサブモードが存在します。動作仕様の違いを100%把握しておく必要があります。

*   **`switchport voice vlan [VLAN-ID]` (推奨方式):** 
    指定したVLAN（例: 150）でIP Phoneの音声トラフィックに802.1Qタグを付与させ、ポートの優先度（CoS 5/DSCP EF）を割り当ててスイッチへ送信させます。データ用PCのパケットはポートのAccess VLAN（タグなし）で通過します。
*   **`switchport voice vlan dot1p` (プライオリティタグのみ):** 
    音声トラフィックは**「VLAN 0（プライオリティタグ/Tag0）」**を用いて送信されます（VLAN ID 自体は設定されず、L3パケットはデータトラフィックと同一のVLANにルーティングされますが、レイヤ2ヘッダー上の CoS「5」だけが維持されてQoSが動作します）。
*   **`switchport voice vlan untagged`:** 
    IP Phoneに対して音声トラフィックをタグなし（Untagged）で送信させます。
*   **`switchport voice vlan none`:** 
    Voice VLANを完全に無効化します。IP Phoneは単なる標準PCと同じ扱いになり、すべてのトラフィック（データ/音声）がアクセスVLAN上でタグなしで送受信されます。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における、各VLAN技術の構成コマンド手順です。

### 1. アクセスポートおよび DTP 無効化の基本設定

```bash
# VLANの作成（Normal Range）
vlan 10
 name CLIENT_DATA
 exit

# インターフェイスの設定
interface GigabitEthernet1/0/10
 description CONNECT_TO_CLIENT_PC
 # レイヤ2アクセスモードとして静的に固定
 switchport mode access
 # 所属するアクセスVLANのバインド
 switchport access vlan 10
 # DTPフレームの送信を完全に停止（セキュリティ硬化）
 switchport nonegotiate
 # STPの収容最適化（アクセスポートには必須）
 spanning-tree portfast
 spanning-tree bpduguard enable
```

### 2. トランクポートおよび Native VLAN（ダミー変更＋タギング）の設定

```bash
# ネイティブVLAN用のダミーVLANの作成
vlan 999
 name DUMMY_NATIVE_VLAN
 exit

# トランクインターフェイスの設定
interface GigabitEthernet1/0/1
 description CONNECT_TO_CORE_SWITCH
 # 静的トランクモードの確立
 switchport mode trunk
 # DTPの停止
 switchport nonegotiate
 # ネイティブVLANをダミーVLAN（VLAN 999）に変更
 switchport trunk native vlan 999
 # マニュアルVLANプルーニング（Allowed VLANリストの最小化）
 switchport trunk allowed vlan 10,20,30,999
```

### 3. グローバルでの Native VLAN タギング設定

```bash
# スイッチドネットワーク全体でネイティブVLANのフレームにもDot1qタグを強制付与
vlan dot1q tag native
```

### 4. VTP v3 を用いた Extended Range VLAN の構成と同期

```bash
# VTPバージョンをV3に変更（Extended VLANのServer同期に必須）
vtp version 3

# 自スイッチをVTPドメインの「Primary Server」として昇格（※VTP v3固有の手順）
vtp mode server

# 特権EXECモードから、VLANデータベース更新のオーナーシップを確立
vtp primary vlan

# Extended Range VLANの追加（VTP v3により同期可能）
vlan 2000
 name EXTENDED_SDA_DATA
 vlan 3000
 name EXTENDED_SDA_VOICE
 end
```

### 5. Voice VLAN（Data/Voice多重化）の設定

```bash
# データVLANと音声VLANの定義
vlan 10
 name PC_DATA
vlan 150
 name UC_VOICE
exit

interface GigabitEthernet1/0/5
 description CONNECT_TO_CISCO_IP_PHONE
 switchport mode access
 switchport access vlan 10
 # 音声VLAN ID 150 を配信して多重化
 switchport voice vlan 150
 switchport nonegotiate
 spanning-tree portfast
 spanning-tree bpduguard enable
```

---

## 🔍 検証コマンド

VLAN、トランク、およびVoice VLANの稼働ステータスを確認するための必須コマンド群です。

| 目的 | コマンド |
| :--- | :--- |
| **作成済みVLANの一覧、割り当てポート、Voice VLAN状態の確認** | <code>show vlan brief</code> |
| **特定のインターフェイスにおけるL2詳細モード（Trunk/Access/DTP状態）の確認** | <code>show interfaces GigabitEthernet1/0/1 switchport</code> |
| **現在アクティブなトランクポート、カプセル化（802.1Q）、Native VLAN ID、Allowed list、および実質Pruning対象VLANの確認** | <code>show interfaces trunk</code> |
| **VTPのバージョン、モード（Server/Transparent）、および同期されている最大VLAN ID数の確認** | <code>show vtp status</code> |
| **スイッチポート上のIP Phoneが現在受電（PoE）しているかどうかの稼働ステータス確認** | <code>show power inline GigabitEthernet1/0/5</code> |
| **DTPのリアルタイムデバッグ（ネゴシエーション送受信の追跡）** | <code>debug dtp packets</code> |
| **トランクポートにおけるSTPステートおよび不整合（*PVID_Incなど）の確認** | <code>show spanning-tree interface GigabitEthernet1/0/1</code> |

---

## 🚨 トラブルシュート

実機演習やラボ試験で遭遇する主要なVLANトラブルシナリオと、具体的な回復フローです。

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **トランクリンクが確立しない（対向ポートが「down/down」または「up/down」となる）** | 両スイッチ間でトランクの **DTP モードが不整合**（例: 両側とも `switchport mode dynamic auto`、または片側が `nonegotiate` であるにもかかわらず対向が Desirable などの自動ネゴシエーションになっている）。 | <code>show interfaces switchport</code> | 1. <code>switchport mode trunk</code> に静的に固定。<br>2. セキュリティ制限を満たすために、両端で <code>switchport nonegotiate</code> を投入してDTPを明示的に排除する。 |
| **トランク上の特定のVLAN（例: VLAN 10）を通過するパケットが静かにドロップされる（通信不可）** | トランクの **Allowed VLANリスト（Manual Pruning）から該当VLANが誤って除外されている**。 | <code>show interfaces trunk</code> | <code>switchport trunk allowed vlan add 10</code> を実行してリストに追加。<br>※注意: <code>add</code> を忘れて <code>switchport trunk allowed vlan 10</code> と打つと、他のすべてのVLANがトランクから消去されるため、必ず「add」を記述する。 |
| **トランクポートが「*PVID_Inc」（Port VLAN ID Inconsistent）としてSTPによってブロッキング状態に遷移する** | **Native VLAN ID のミスマッチ**。接続している対向スイッチ同士で Native VLAN の番号が異なっている。 | <code>show interfaces trunk</code><br><code>show spanning-tree</code> | 両端のトランクポートにて、<code>switchport trunk native vlan [VLAN-ID]</code> コマンドでNative VLANの整合性を一致させる。 |
| **IP Phoneの背後に接続されたPCは通信可能だが、IP Phone自身が「Registering...」から進まず、音声通信が起動しない** | 1. スイッチ側で <code>switchport voice vlan</code> が未定義、または間違ったVLANが割り当てられている。<br>2. **CDP (または LLDP-MED) が無効化されており**、PhoneがVoice VLAN IDを自動取得できていない。 | <code>show cdp neighbors</code><br><code>show lldp neighbors</code> | 1. グローバルで <code>cdp run</code> を有効化、インターフェイス配下で <code>cdp enable</code> を追加。<br>2. <code>switchport voice vlan [VLAN-ID]</code> の構成が、UCサーバー（Cisco Unified Communications Manager等）の音声VLANと一致しているか再確認する。 |
| **VLAN 2000（Extended Range）を作成しようとすると、「VTP configuration prevents creating VLANs in extended range」と拒否される** | スイッチの VTP モードが v1/v2 の「Server」または「Client」になっているため、仕様上Extended VLANが拒否されている。 | <code>show vtp status</code> | 1. <code>vtp version 3</code> を実行して Extended VLAN 同期に対応させる。<br>2. または、同期が不要なローカルスイッチであれば <code>vtp mode transparent</code> に変更して制限を解除する。 |

---

## ⚠ 制限事項

### 1. VLAN ID 範囲の排他性と予約済みVLAN（Reserved VLANs）
*   VLAN 0、および VLAN 4095 はシステム（ASIC）内部の制御用として予約されています。
    *   **VLAN 0:** レイヤ2プライオリティタギング（Dot1p）専用。
    *   **VLAN 4095:** 内部破棄ポート、トランクポート内でのタグなしカプセル化解除用などに使用されます。
*   VLAN 1002〜1005 は、レガシーメディア（FDDI, Token Ring）用の予約VLANであり、削除や通常のイーサネット用途への転送変更は一切できません。

### 2. ハードウェアテーブル（CAM / TCAM）スケーラビリティ
*   Cisco Catalystスイッチの各プラットフォームは、ASICのSDM（Switch Database Management）テンプレートにより、サポート可能な最大VLANアクティブ数（通常 1024〜4094）および最大MACアドレスエントリ数が制限されています。
*   Extended VLANを多用する場合、VLAN数自体は4094まで対応していても、STPインスタンスの最大数（一般的に PVST+ では最大 128 インスタンス程度）を超過すると、一部のVLANでSTPが動作せず、ループのリスクが高まります。
    *   **対策:** 多数のVLANを設計する場合は、STPインスタンスをVLANグループにマッピングして集約する **MSTP（Multiple Spanning Tree Protocol）** の採用が必須となります [12, 1.1.e]。

### 3. Voice VLAN とポート認証（MDA）の併用制限
*   Voice VLAN（同一物理ポートでのPCとPhoneの収容）が動作するポートで 802.1X または MAC認証バイパス（MAB）を併用する場合、ポートは必ず **Multi-Domain Authentication（MDA）** モードで動作させなければなりません。
*   MDAモードでないデフォルト（シングルホストモード）のまま認証を有効にすると、最初に認証をパスした端末（通常はPC）のみが許可され、2台目の端末（IP Phone）のパケットが「セキュリティ違反（Violation）」と見なされてポートが強制閉塞（err-disable）に遷移します [23, 4.2.a]。

---

## 🔄 他技術との関連

*   **STP (Spanning Tree Protocol):** 
    PVST+（Per-VLAN Spanning Tree Plus）環境下では、VLANごとに独立したSTPトポロジー計算が実行されます。
    *   **Pruning の重要性:** 
        トランクポートからマニュアルで不要なVLANをPruning（削除）しておくことは、対向スイッチ側で発生した特定のVLANのSTPトポロジーチェンジ（TC）フレームが、このスイッチに届くのを未然に防ぐ効果があります。不要なSTP TCパケットの受信は、MACアドレスの高速エージングタイム（デフォルト300秒から15秒への一時的短縮）を誘発し、スイッチドドメイン全体の転送パフォーマンス（Unknown Unicastフラッディングの激増）を低下させます。
*   **VTP (VLAN Trunking Protocol):** 
    スイッチ間でVLAN構成情報の作成・削除・名前変更を自動共有する仕組みです。
    *   **VTP v3:** 前述の通り、Extended Range VLANの同期に不可欠であるほか、意図しないリビジョン番号（Revision Number）の上書きによるVLANデータベースの誤消去（VTP崩壊）を防ぐセーフガード機能（Primary / Secondary Server管理方式）が搭載されています。
*   **QoS (Quality of Service):** 
    Voice VLANポートでは、IP PhoneとPCのトラフィックが単一ポートに混在するため、スイッチのASICでのバッファスケジューリングが重要になります。
    *   **QoS Trust Boundary:**
        スイッチは、Cisco IP Phoneから受信したCDP情報を確認すると、ポート上の**QoS信頼境界（Trust Boundary）**を動的にPhone側に移動させ、音声タグ内の CoS 5 / DSCP EF 優先度を「信頼（Trust）」してキューイング処理します。背後のPCから送られる不正な高優先タグは、境界で強制的に CoS 0 にリライト（リマーク）されてQoSの悪用を防ぎます [23, 4.4.b]。

---

## 🧩 比較表

### 1. ポートモード比較

| 比較項目 | Access ポート | Trunk ポート | Voice VLAN ポート (推奨) |
| :--- | :--- | :--- | :--- |
| **所属VLAN数** | 単一（Access VLAN のみ） | 複数（1～4094、Allowedリストに基づく） | 2つのVLAN（Access VLAN ＋ Voice VLAN） |
| **タギングの有無** | **タグなし（Untagged）**でパケットを送受信 | 指定VLAN以外は **802.1Q タグ付き**で送受信 | 音声は **Tagged**、データは **Untagged** で送受信 |
| **接続対象デバイス** | PC、サーバー、プリンタ、ゲートウェイなど | 他のL2スイッチ、L3コア、ルータ、ESXiサーバー | Cisco IP PhoneなどのVoIP電話（背後にPCをカスケード接続） |
| **STP PortFast 適用** | **推奨**（端末接続のため、即時転送移行可能にする） | **非推奨（原則禁止）**。ただしルータやサーバー直結時のみ個別検討。 | **推奨**（IP Phoneの迅速な起動とPCのリンクアップを確保するため） |

### 2. Normal Range VLANs vs Extended Range VLANs

| 比較項目 | Normal Range VLANs | Extended Range VLANs |
| :--- | :--- | :--- |
| **VLAN ID 範囲** | **1 ～ 1005** | **1006 ～ 4094** |
| **VTP v1 / v2 での同期** | サポート（Server/Client モードで自動同期） | **非サポート**（Transparentモード時のみローカル作成可能） |
| **VTP v3 での同期** | サポート（Server/Client モードで自動同期） | **完全サポート**（Serverから各Clientへ自動同期可能） |
| **VLANデータベース保存先** | フラッシュメモリ上の `vlan.dat` ファイルに自動保存 | 構成モードにより、`vlan.dat` または `startup-config` 内に保存 |
| **主なユースケース** | 通常のエンタープライズセグメント、管理用VLAN | 広域ネットワーク、SDA（SD-Access）、VXLANインフラ |

---

## 💡 ベストプラクティス

1.  **DTPの完全排除と静的トランク設定:**
    DTPによるネゴシエーション（`mode dynamic desirable`）は、攻撃者がDTPフレームを偽装してスイッチポートをトランクに昇格させ、すべてのVLANトラフィックを傍受するセキュリティセキュリティ上の致命的な脅威となります。すべてのポートで `switchport mode trunk` および **`switchport nonegotiate`** を一貫して設定することを推奨します。
2.  **ネイティブVLANのダミー隔離:**
    トランクリンクの Native VLAN は、絶対に「VLAN 1」のまま放置せず、ホストが接続されていない孤立したVLAN（例：VLAN 999等）に変更します。さらにグローバルで **`vlan dot1q tag native`** を有効化し、VLANホッピング攻撃（ダブルタギング）の発生経路をハードウェアレベルで排除します。
3.  **マニュアル Pruning によるAllowedリストの精査:**
    トランクリンクでは、デフォルトの `allowed vlan all` は使用せず、スイッチに定義されているアクティブなVLANのみを `switchport trunk allowed vlan [リスト]` で明示します。これにより、不要なフラッディングをWAN帯域から排除し、STPのTC伝搬を最小化します。
4.  **VTPのOffモードまたはVTP v3の採用:**
    不意なスイッチの追加によるVLAN構成の意図しない上書きを防止するため、VTPモードは原則として「Off（またはTransparent）」に設定してローカル管理するか、大規模自動同期が必要な場合はVTPの管理者認証・Extended VLAN同期が統合された「VTP v3」を一律で採用します。

---

## 📝 ラボ学習・設定サンプル例

※ 本設定サンプルは、Cisco IOS-XE 17.xをベースとしており、省略せずに最後まで出力しています。CCIE EI実技試験の構成基準を満たしています。

### 1. 基本的なトランク構築と DTP 停止（DTP disable）
**【問題】** 
SW1とSW2の間のインターフェイス `GigabitEthernet1/0/1` において、トランクリンクを手動で確立してください。トランクのカプセル化は802.1Qとし、DTPによるネゴシエーションフレームの送信を完全に停止（DTP disable）させてください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/1
SW1(config-if)# description TRUNK_TO_SW2
# 静的なトランクモードを強制
SW1(config-if)# switchport mode trunk
# DTPフレームの送出を停止
SW1(config-if)# switchport nonegotiate
SW1(config-if)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# interface GigabitEthernet1/0/1
SW2(config-if)# description TRUNK_TO_SW1
SW2(config-if)# switchport mode trunk
SW2(config-if)# switchport nonegotiate
SW2(config-if)# end
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/1 switchport
# 「Negotiation of Trunking: Off」および「Operational Mode: trunk」を確認します。
```

---

### 2. Native VLAN のセキュアな変更と Dot1q ネイティブタギングの適用
**【問題】** 
SW1とSW2を結ぶトランクリンク `GigabitEthernet1/0/2` において、VLANホッピング攻撃を防御するため、ネイティブVLANをクライアントが所属していない「VLAN 888」に変更してください。また、ネイティブVLANを通過するフレームに対しても明示的に802.1Qタグを付与するようにグローバルで設定してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vlan 888
SW1(config-vlan)# name SECURE_NATIVE_VLAN
SW1(config-vlan)# exit
SW1(config)# interface GigabitEthernet1/0/2
SW1(config-if)# switchport mode trunk
SW1(config-if)# switchport trunk native vlan 888
SW1(config-if)# exit
# グローバル設定：ネイティブVLANパケットのタギング有効化
SW1(config)# vlan dot1q tag native
SW1(config)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# vlan 888
SW2(config-vlan)# name SECURE_NATIVE_VLAN
SW2(config-vlan)# exit
SW2(config)# interface GigabitEthernet1/0/2
SW2(config-if)# switchport mode trunk
SW2(config-if)# switchport trunk native vlan 888
SW2(config-if)# exit
SW2(config)# vlan dot1q tag native
SW2(config)# end
```

**【検証方法】**
```bash
SW1# show interfaces trunk
# Gi1/0/2 の Native VLAN が「888」になっていること、およびグローバル設定の確認：
SW1# show vlan dot1q tag native
# 「dot1q native vlan tagging is enabled」が表示されることを確認します。
```

---

### 3. Manual VLAN Pruning によるトランク帯域の最適化
**【問題】** 
SW1とSW2を接続するトランクインターフェイス `GigabitEthernet1/0/3` において、トランクポート上で通過可能なVLANを、現在ネットワーク内でアクティブな「VLAN 10, VLAN 20, VLAN 30, およびネイティブVLAN 888」のみに手動で制限し、不要なブロードキャストトラフィックの伝搬を防止してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/3
SW1(config-if)# switchport mode trunk
# Allowedリストの設定（マニュアルプルーニング）
SW1(config-if)# switchport trunk allowed vlan 10,20,30,888
SW1(config-if)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# interface GigabitEthernet1/0/3
SW2(config-if)# switchport mode trunk
SW2(config-if)# switchport trunk allowed vlan 10,20,30,888
SW2(config-if)# end
```

**【検証方法】**
```bash
SW1# show interfaces trunk
# インターフェイス Gi1/0/3 の「Vlans allowed on trunk」に「10,20,30,888」のみが登録されているか確認します。
```

---

### 4. VTP v3 を利用した Extended Range VLAN の Server モードでの同期と適用
**【問題】** 
SW1をドメイン名「CCIE_LAB」のVTP Server（バージョン3）として構成し、VTPデータベースのオーソリティ（Primary Server）に昇格させてください。その後、Extended Range である「VLAN 2000」および「VLAN 3000」を作成し、VTPClientであるSW2へ自動同期されるように構成してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vtp domain CCIE_LAB
SW1(config)# vtp version 3
SW1(config)# vtp mode server
SW1(config)# exit
# VTP v3の更新権限を取得（特権モードで実行）
SW1# vtp primary vlan
# パスワード入力プロンプト等が表示された場合は指示に従う。
SW1# configure terminal
SW1(config)# vlan 2000
SW1(config-vlan)# name DATA_EXT_2000
SW1(config-vlan)# vlan 3000
SW1(config-vlan)# name VOICE_EXT_3000
SW1(config-vlan)# end
```

**【SW2 設定】**
```bash
SW2# configure terminal
SW2(config)# vtp domain CCIE_LAB
SW2(config)# vtp version 3
SW2(config)# vtp mode client
SW2(config)# end
```

**【検証方法】**
```bash
SW2# show vlan brief
# クライアントスイッチSW2において、Extended VLANである「2000」および「3000」が自動同期されて作成されていることを確認します。
```

---

### 5. LLDP-MED/CDP を用いた Voice VLAN（Multi-VLANポート）の設定
**【問題】** 
SW1の `GigabitEthernet1/0/5` ポートに、データPCが背後にカスケード接続されたCisco IP Phoneを収容します。PCトラフィック用として VLAN 10（Access VLAN）、音声通話トラフィック用として VLAN 150（Voice VLAN）を多重化して構成し、さらにDTPを排除してSTP PortFastをエッジ最適化してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vlan 10
SW1(config-vlan)# name PC_DATA_VLAN
SW1(config-vlan)# exit
SW1(config)# vlan 150
SW1(config-vlan)# name PHONE_VOICE_VLAN
SW1(config-vlan)# exit
SW1(config)# interface GigabitEthernet1/0/5
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 10
SW1(config-if)# switchport voice vlan 150
SW1(config-if)# switchport nonegotiate
# エッジスイッチポートの即時コンバージェンス最適化
SW1(config-if)# spanning-tree portfast
SW1(config-if)# spanning-tree bpduguard enable
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/5 switchport
# 「Access Mode VLAN: 10 (PC_DATA_VLAN)」および「Voice Mode VLAN: 150 (PHONE_VOICE_VLAN)」を確認します。
```

---

### 6. Voice VLAN `dot1p` 優先度のみを使用するポートの構成
**【問題】** 
音声トラフィック用に特別なVLAN（別サブネット）を作成せず、データトラフィックと同一のセグメント（VLAN 10）を使用します。しかし、音声パケットに対して優先度キューイングを適用させるため、スイッチポート `GigabitEthernet1/0/6` に接続されたIP Phoneが、VLAN 0（プライオリティタグのみ、Tag0）を使用してフレームを送信するように構成してください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/6
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 10
# Voice VLANに 802.1p プライオリティタギングを指定
SW1(config-if)# switchport voice vlan dot1p
SW1(config-if)# switchport nonegotiate
SW1(config-if)# spanning-tree portfast
SW1(config-if)# spanning-tree bpduguard enable
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show interfaces GigabitEthernet1/0/6 switchport
# 出力の「Voice Mode VLAN: dot1p (Priority Tagging)」を確認します。
```

---

### 7. 802.1X/MAB (MDA) と Voice VLAN を組み合わせたセキュアなホストポート
**【問題】** 
SW1の `GigabitEthernet1/0/8` において、IP Phoneと背後のPCに対して、同一ポート内で個別にMAC認証/ドット1X認証を強制する「マルチドメイン（MDA）」セキュリティを設定してください。PCは VLAN 10（データ）、IP Phoneは VLAN 150（音声）として処理させます。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# interface GigabitEthernet1/0/8
SW1(config-if)# switchport mode access
SW1(config-if)# switchport access vlan 10
SW1(config-if)# switchport voice vlan 150
# ポート認証モードをマルチドメイン（VoiceとDataを個別処理）に指定
SW1(config-if)# authentication host-mode multi-domain
SW1(config-if)# authentication port-control auto
SW1(config-if)# mab
SW1(config-if)# dot1x pae authenticator
SW1(config-if)# spanning-tree portfast
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show authentication sessions interface GigabitEthernet1/0/8
# セッション情報において、DOMAINが「DATA」と「VOICE」に正しく分割されて独立して処理されていることを確認します。
```

---

### 8. SVI とトランクを用いた Inter-VLAN ルーティング
**【問題】** 
L3スイッチであるSW1において、VLAN 10（CLIENT）および VLAN 20（SERVER）用の仮想インターフェイス（SVI）を作成し、ルーティング（Inter-VLANルーティング）を有効化してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# IPルーティングプロセスの有効化
SW1(config)# ip routing
SW1(config)# vlan 10
SW1(config-vlan)# exit
SW1(config)# vlan 20
SW1(config-vlan)# exit

# SVI 10 の作成
SW1(config)# interface vlan 10
SW1(config-if)# ip address 10.10.10.254 255.255.255.0
SW1(config-if)# no shutdown
SW1(config-if)# exit

# SVI 20 の作成
SW1(config)# interface vlan 20
SW1(config-if)# ip address 10.10.20.254 255.255.255.0
SW1(config-if)# no shutdown
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show ip route connected
# ルーティングテーブルに、VLAN 10 および 20 のネットワークが直結ルートとしてリストされているか確認します。
```

---

### 9. MAC フラッピングを抑止するための VLAN テーブルとポート硬化
**【問題】** 
VLAN 10において一時的なL2ループが発生した際、コントロールプレーンが崩壊するのを防ぐため、MACアドレスがポート `GigabitEthernet1/0/10` と `GigabitEthernet1/0/11` の間で高速にフラッピング（フラッピング検知）した瞬間に、該当ポートを自動的に閉塞（err-disable）させて隔離するポリシーを定義してください。

**【SW1 設定】**
```bash
SW1# configure terminal
# MACフラッピング検知ポリシーのグローバル定義
SW1(config)# errdisable detect cause mac-flapping
# 10秒間に5回以上のフラッピングを検知した場合に閉塞
SW1(config)# mac address-table notification mac-move
SW1(config)# end
```

**【検証方法】**
```bash
SW1# show errdisable detect
# 「mac-flapping」項目が「Enabled」になっていることを確認します。
```

---

### 10. QinQ トランキングポートに直結する CE/PE トランクの VLAN マッピング
**【問題】** 
SW1（キャリアPEスイッチ）と、CEスイッチを結ぶトランクリンク `GigabitEthernet1/0/12` において、1対1のVLANマッピング（VLAN Translation）を実装します。顧客側タグ「VLAN 10」をキャリア網トランク通過時に「VLAN 100」に、顧客側タグ「VLAN 20」を「VLAN 200」にASICでインライン置換してトランクを通過させてください。

**【SW1 設定】**
```bash
SW1# configure terminal
SW1(config)# vlan 100,200
SW1(config-vlan)# exit
SW1(config)# interface GigabitEthernet1/0/12
SW1(config-if)# switchport mode trunk
SW1(config-if)# switchport trunk allowed vlan 100,200
# VLANマッピング（VLAN Translation）の登録
SW1(config-if)# switchport vlan mapping 10 100
SW1(config-if)# switchport vlan mapping 20 200
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show vlan mapping
# インターフェイス Gi1/0/12 において、変換ルールが正常にバインドされていることを確認します。
```

---

### 11. Private VLAN (PVLAN) のマニュアル設定
**【問題】** 
SW1において、同一VLAN内のセキュリティ隔離を実現するため、プライベートVLAN（PVLAN）を構成してください。
*   プライマリーVLAN: `VLAN 100`
*   コミュニティVLAN（互いに通信可能、他とは通信不可）: `VLAN 101`
*   孤立（Isolated）VLAN（互いに通信不可）: `VLAN 102`
*   ゲートウェイ接続ポート（`Gi1/0/15`）: 無差別（Promiscuous）ポート
*   クライアント接続ポート（`Gi1/0/16`）: 孤立（Isolated）ホストポート

**【SW1 設定】**
```bash
SW1# configure terminal
# VTPをプライベートVLAN対応モードに移行（またはVTP Off/Transparentにする必要があります）
SW1(config)# vtp mode transparent

# コミュニティVLANの定義
SW1(config)# vlan 101
SW1(config-vlan)# private-vlan community
SW1(config-vlan)# exit

# 孤立（Isolated）VLANの定義
SW1(config)# vlan 102
SW1(config-vlan)# private-vlan isolated
SW1(config-vlan)# exit

# プライマリーVLANの定義とアソシエーションバインド
SW1(config)# vlan 100
SW1(config-vlan)# private-vlan primary
SW1(config-vlan)# private-vlan association 101-102
SW1(config-vlan)# exit

# 1. 無差別（Promiscuous）ポートの設定（ゲートウェイ等）
SW1(config)# interface GigabitEthernet1/0/15
SW1(config-if)# switchport mode private-vlan promiscuous
SW1(config-if)# switchport private-vlan mapping 100 101-102
SW1(config-if)# exit

# 2. 孤立（Isolated）ホストポートの設定
SW1(config)# interface GigabitEthernet1/0/16
SW1(config-if)# switchport mode private-vlan host
SW1(config-if)# switchport private-vlan host-association 100 102
SW1(config-if)# end
```

**【検証方法】**
```bash
SW1# show vlan private-vlan
# プライマリーVLAN 100 に対して、セカンダリーVLAN（101, 102）がアソシエーションされ、各指定ポート（Gi1/0/15, Gi1/0/16）が正しく配置されているか確認します。
```

---

## ❓ 想定試験問題

CCIE EIラボ実技試験、および記述・デザイン（Design/Diagnostic）セクションを意識した想定問題と解説です。

### 1. 【コンフィグ読解：Voice VLANモードミスマッチによる挙動】
**問題:** 
以下のSW1の設定において、接続された Cisco IP Phone（音声用）および背後のPC（データ用）における、物理タグの扱いおよび通信可能なVLAN範囲を説明してください。
```text
interface GigabitEthernet1/0/10
 switchport mode access
 switchport access vlan 50
 switchport voice vlan untagged
```

**解答・解説:**
*   **物理タグの扱い:** 
    この設定（`voice vlan untagged`）では、スイッチはIP Phoneに対して**「データおよび音声の両パケットを一切タギングせずに（Untaggedで）送受信しなさい」**と配信します。
*   **通信可能なVLAN:** 
    結果として、音声トラフィックもデータトラフィックも、すべて物理ポートのAccess VLANである **「VLAN 50」のみに強制バインド** されて処理されます。この構成では、論理セグメント（サブネット）を分割することはできず、両端末は同一のブロードキャストドメインで通信します。QoSの論理制御を分けたいエンタープライズのベストプラクティスとしては不適切（誤り）な設定であり、試験では `switchport voice vlan 150`（独立VLAN指定）等に変更する修正手順が求められます。

---

### 2. 【トラブルシュート：VTPリビジョン上書きによる全ポート通信断】
**問題:** 
リモート拠点に、元々検証環境で使用していた中古のCatalystスイッチをVTP Clientとして追加接続したところ、拠点全体のすべてのスイッチにおいて、現在運用中の業務VLAN（10, 20, 30）のデータベースが突然消去され、すべてのクライアントポートが「シャットダウン」状態（VLAN不活性による論理ダウン）になりました。
この大障害が発生した**技術的メカニズム**をVTPの仕様から説明し、かつ、これに遭遇した際の**回復用復旧手順**、および**恒久的な予防策（VTP v3を用いた対策）**を提示してください。

**解答・解説:**
*   **大障害発生の技術的メカニズム:**
    VTP v1/v2 環境下において、検証環境から持ち込まれたスイッチのドメイン名が本番網と一致しており、かつそのスイッチの **「Configuration Revision Number（リビジョン番号）」** が、稼働中のServerスイッチのリビジョン（例: 5）よりも高い値（例: 100）かつ、VLANが未設定（初期状態）であった場合、 Serverスイッチを含む既存の全スイッチは「最新のVLAN構成である」と誤認して**リビジョン100のデータベース（VLANが何も定義されていない空のデータベース）で上書き同期**してしまいます。これにより、本番VLANが全スイッチから瞬時に消滅します。
*   **回復用の復旧手順:**
    1.  本番網の Server スイッチを、手動で一時的に `vtp mode transparent` に変更して同期を完全にデタッチします。
    2.  Server スイッチ上で、手動で消去された VLAN（10, 20, 30）を再作成します。
    3.  ドメイン全体に正しい情報を再同期させるため、リビジョンをリセットした（Clientを一度Transparentに変更して戻す等）のち、Serverを `vtp mode server` に戻します。
*   **VTP v3を用いた恒久的な予防策:**
    **VTP v3を採用します。** VTP v3では、データベースの書き換えは、明示的に特権EXECモードから **`vtp primary vlan`** を実行して「Primary Server（更新権限オーナー）」に昇格したスイッチからしか行うことができません。他の高いリビジョンを持つスイッチが単に接続されただけでは、データベースが上書きされる事故は100%発生しなくなります。

---

### 3. 【Design：SD-Access/VXLAN環境でのVLANとMTU設計】
**問題:** 
SD-Access（Software-Defined Access）ネットワークを設計しています。ファブリックのエッジスイッチ（Catalyst 9300）において、各仮想ネットワーク（VN）にバインドする Extended Range VLAN「VLAN 2500（DATA）」を定義します。ファブリックボーダースイッチとの間のアンダーレイ（物理トランク）において、VXLANカプセル化に伴うドロップを防ぐために、物理MTUサイズをどのように設定すべきか、理由とともに設計案を述べてください。

**解答・解説:**
*   **設計提案:**
    物理アンダーレイリンク（L2トランクポートおよびL3ルーテッドポート）のMTUサイズを、一貫して **`9100` バイト**（または最低でも `1550` バイト以上）のジャンボフレーム対応に変更します。
*   **理由:**
    SD-Accessでは、エンドホストから送られる標準のイーサネットフレーム（MTU 1500）が、ファブリックエッジに到着した段階で、VXLAN、UDP、IP、外側L2ヘッダーなどで**カプセル化（合計約50バイト以上のカプセル化オーバーヘッドが付与）**されます。
    もしアンダーレイ物理トランクポートのMTUがデフォルト（1500）のままである場合、カプセル化後の1550バイトパケットが通過した瞬間に「Giantフレーム」としてサイレントドロップされます。したがって、VLANカプセル化とオーバーレイ転送を一貫して動作させるためには、L2トランクインターフェイスのMTUサイズ引き上げが第一の必須要件となります。

---

## 🔗 参考リソース

### Cisco Live (スライド・オンデマンド)
* [**BRKCRS-2031: Enterprise Campus Design: Multilayer Architectures and Design Principles**](https://www.ciscolive.com/c/dam/r/ciscolive/emea/docs/2023/pdf/BRKENS-2031.pdf)
* [**BRKENS-2614: Campus Design with Secure Networking Reference Architecture**](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2026/pdf/BRKENS-2614.pdf) 

### Configuration ガイド（シスコ公式）
* [**Cisco IOS XE 17.x: Software Configuration Guide, VLAN Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/vlan/b_179_vlan_9300_cg.html)
* [**Cisco IOS XE 17.x: Command Reference, VLAN Commands**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/command_reference/b_179_9300_cr/vlan_commands.html)
* [**Cisco IOS Release 15.2(4)E: VLANs**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst3750x_3560x/software/release/15-2_4_e/configurationguide/b_1524e_consolidated_3750x_3560x_cg/b_1524e_consolidated_3750x_3560x_cg_chapter_010100.html)

---

## 📝 **補足（Notes）**

### VLANテクノロジー総チェックリスト

ラボ試験直前に、設定が要件通りであるかを判断するためのセルフチェックシートです。

*   **DTPの排除**
    *   [ ] すべてのトランクポートにおいて `switchport mode trunk` と同時に `switchport nonegotiate` が投入されているか？
*   **Native VLAN の整合性**
    *   [ ] Native VLANにクライアントデータトラフィック用（VLAN 1等）を使用していないか？
    *   [ ] トランク対向ポート同士で `switchport trunk native vlan` のID番号が一致しているか？
    *   [ ] `vlan dot1q tag native` が設定され、タグなしフレームを完全にゼロにしているか？
*   **VLANプルーニング**
    *   [ ] `switchport trunk allowed vlan` コマンドで既存トランクのVLANを書き換える際、必ず `add` キーワードを含めて設定したか？（既存VLANを誤消去していないか？）
*   **Extended Range VLANs**
    *   [ ] 1006以上のVLANを追加した際、VTPモードがv3のServerであるか、またはv1/v2の場合はTransparentに設定されているか？
*   **Voice VLANの最適化**
    *   [ ] IP Phone接続ポートで `spanning-tree portfast` が有効化され、ポートが即座にフォワーディング状態へ遷移するか？
    *   [ ] 802.1Xとの併用時、ポートのホストモードが `multi-domain` に設定されているか？
