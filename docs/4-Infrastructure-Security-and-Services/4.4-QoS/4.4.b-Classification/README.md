---
layout: default
title: 4.4.b-Classification
parent: 4.4-QoS
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.4.c Network Based Application Recognition (NBAR)

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.4 Quality of Service` における、レイヤ 4 〜 レイヤ 7 ディープパケットインスペクション（DPI: Deep Packet Inspection）技術である **Network Based Application Recognition (NBAR / NBAR2)** の完全学習メモ。

---

## 📘 概要

ネットワークベースアプリケーション認識（NBAR: Network Based Application Recognition、および次世代版 NBAR2 / Next-Generation NBAR）は、IP パケットの L4〜L7 ペイロード（データ部分）を動的に解析する Cisco 独自のディープパケットインスペクション（DPI）エンジンである。

* **機能概要:** 従来の L4 アクセスリスト（ポート番号固定マッチ）では識別が困難な、動的 TCP/UDP ポート割り当てアプリケーション（P2P、WebEx、Skype、BitTorrent 等）や、HTTP/HTTPS（URL、Host、MIME タイプ）、SSL/TLS 拡張ヘッダー（SNI: Server Name Indication）を判定・分類する。
* **利用目的:**
  * **アプリケーションの可視化 (Protocol Discovery):** ネットワーク内を通過するアプリケーションごとのトラフィック比率、帯域消費量（bps）、パケット数、バイト数を可視化する。
  * **QoS 分類 ＆ マーク (MQC Traffic Classification):** `match protocol` や `match protocol attribute` を使用して MQC（Modular QoS CLI）の `class-map` でマッチさせ、優先制御（LLQ）、帯域保証（CBWFQ）、ポリシング、シェーピング、あるいはドロップ（Scavenger 化）を適用する。
  * **AVC (Application Visibility Control) 連携:** Flexible NetFlow (FNF) と連携し、フローごとのアプリケーションパフォーマンス指標（遅延、ジッター、ドロップ率）を収集・レポート出力する。
* **どのような場面で利用するか:**
  * ポート 80 (HTTP) やポート 443 (HTTPS) を共有する多様な Web アプリケーション（Office 365, Salesforce, WebEx, YouTube, Facebook 等）を個別制御する場合。
  * ダイナミックポートを使用する 音声/ビデオ会議プロトコル (SIP, H.323, SCCP, RTP Payload) の帯域保護。
  * 業務外 P2P ファイル共有や動画配信（BitTorrent, Netflix, YouTube）を制限・降格（Scavenger クラスへの分類）する場合。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | L4-L7 Payload DPI エンジン。単一圧縮ファイル Protocol Pack によるシグネチャ更新に対応。 |
| **用途** | アプリケーション自動識別、QoS マーク/ポリシング、トラフィックプロファイリング、AVC 連携 |
| **メリット** | 静的ポート番号に依存せず、動的・難読化プロトコルや Web アプリを正確に識別可能 |
| **デメリット/制限事項** | 高度な CPU / メモリリソースを消費。完全暗号化された未知ペイロードの判定には限界あり |
| **前提条件** | **CEF (Cisco Express Forwarding)** および **IPv6 CEF** の有効化が必須（`ip cef` / `ipv6 cef`） |
| **動作モード** | **Passive Mode** (Protocol Discovery) ＆ **Active Mode** (MQC Service-Policy) |
| **設計上の注意点** | メモリ使用率上限（推奨 70% 以下）の監視。大容量非対称ルーティング環境での判定精度調整 |

---

## 🏗 動作原理

NBAR / NBAR2 は、ルータに入力されたパケットに対して CEF 転送パスと連動し、データプレーン（Cisco Catalyst 8000 / ASR 1000 の ESP または ISR G2 の IOS 処理エンジン）上で高速にパケットヘッダーおよびペイロードのシグネチャを照合する。

```
[ Ingress Packet ]
       ↓
[ CEF Switching Path (ip cef / ipv6 cef) ]
       ↓
[ NBAR2 DPI Engine (Protocol Pack / PDL) ]
       ├─► L4 Header Inspection (TCP/UDP Ports, IP Options)
       ├─► L7 Payload Inspection (HTTP Host/URL, SSL/TLS SNI, ASCII/HEX Offsets)
       └─► Attribute Matching (Category, Sub-category, Application-Group)
       ↓
[ MQC Class-Map Evaluation (match protocol ...) ]
       ↓
[ QoS Policy Action (Set DSCP, Police, Shape, Drop, Priority Queue) ]
       ↓
[ Egress Interface Forwarding ]
```

### 1. Protocol Pack (プロトコルパック) と PDL
* **Classic NBAR:** 個別のシグネチャファイルである PDLM (Packet Description Language Module) を Flash から読み込んでメモリに初期展開していた。
* **NBAR2 (Next-Gen NBAR):** 1,500 種類以上のプロトコルシグネチャを 1 つの圧縮ファイル（Protocol Pack）に集約。ルータの OS (IOS XE) を再起動・アップグレードすることなく、`ip nbar protocol-pack` コマンドでシグネチャライブラリのみを動的にオンライン更新可能。

### 2. アトリビュート（属性）による階層的分類
NBAR2 は各プロトコルに対してメタデータ（属性）を付与しており、広範なアプリケーション群を 1 行のコマンドで抽象化マッチングできる。
* **Category:** 例 `voice-and-video`, `business-and-productivity-tools`, `file-sharing`, `email`
* **Sub-category:** 例 `voice-video-chat-collaboration`, `streaming`, `p2p-file-transfer`
* **Application-group:** 例 `webex-group`, `office-365-group`
* **Encrypted:** `encrypted-yes` / `encrypted-no`（暗号化の有無による分類）

---

## ⚙ 動作シーケンス

NBAR2 によるパケット処理および QoS アクション適用は、以下の順序で実行される。

```
Client / Endpoint
   ↓  (HTTP GET / TLS Client Hello / Dynamic RTP Stream)
Ingress Interface
   ↓  (ip nbar protocol-discovery または MQC service-policy input)
CEF Lookup & State Tracking
   ↓  (フローごとに最初の数パケットのペイロードを抽出)
NBAR2 DPI Pattern Matching
   ├─ 1. Well-known Port / L4 Header Check
   ├─ 2. HTTP Host / URL / MIME / User-Agent Inspection
   ├─ 3. SSL/TLS Server Name Indication (SNI) / Certificate Inspection
   └─ 4. Custom Signature (ASCII / HEX Pattern Offset Check)
   ↓  (プロトコル判定完了: 例 "webex-media", "youtube", "bittorrent")
MQC Class-Map Matching (match protocol / match protocol attribute)
   ↓
Policy-Map Action Execution
   ├─ Conform: Set DSCP AF41 / Transmit
   ├─ Exceed: Set DSCP CS1 (Down-mark)
   └─ Violate: Drop
   ↓
Egress Interface (LLQ / CBWFQ Queuing)
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 Practical Lab 試験において、NBAR / NBAR2 は単独の機能問にとどまらず、**複雑な QoS 要件（MQC 組み合わせ）、AVC (Application Visibility Control) 連携、SD-WAN アプリケーション識別 (App-Route)** の基礎コンポーネントとして頻出する。

### 1. ラボ試験で頻出の構成要件と設定指示の解読
* **「ACL を使用せずに特定アプリケーションを識別せよ」:**  
  ポート番号が変動する通信（WebEx, Skype, RTP, P2P）に対して ACL では追従できないため、必ず NBAR (`match protocol`) を使用する。
* **「アトリビュート（属性）を用いて一括してクラス分類せよ」:**  
  `match protocol attribute category <NAME>` や `match protocol attribute sub-category <NAME>` を使用して、数千種類の同種アプリを一括定義する。
* **「カスタムアプリケーションシグネチャを定義せよ」:**  
  `ip nbar custom <NAME>` コマンドを使用して、特定の ASCII 文字列（例: "SALES"）や HEX パターン、特定ポート範囲からのトラフィックを新規プロトコルとして登録する。
* **「否定マッチ（`match not protocol`）を活用せよ」:**  
  一般のストリーミングビデオクラスから特定動画サイト（YouTube, Netflix）を外し、それらを別途 Scavenger クラスへ落とし込む階層マッチ。

### 2. ラボ試験での典型的な設定ミスと「ハマりポイント」
* **`ip cef` / `ipv6 cef` の無効化:**  
  CEF が無効な状態では NBAR DPI エンジンが作動しない。必ずグローバルで CEF が有効化されていることを確認する。
* **`match ip dscp` と `match dscp` の誤用:**  
  `match ip dscp` は IPv4 パケットのみに一致し、IPv6 トラフィックをスルーしてしまう。デュアルスタック要件では必ず **`match dscp`** または **`match protocol`** を使用する。
* **`match-all` と `match-any` のミス:**  
  複数アトリビュートを組み合わせる際（例: カテゴリが `voice-and-video` かつ サブカテゴリが `streaming`）、`class-map match-all` で定義しないと AND 条件にならない。

---


## 🛠 設定方法

### 1. 基本的な NBAR2 MQC 分類 ＆ マーキング設定
```bash
! 1. 単一プロトコルの直接マッチ
class-map match-all CM_WEBEX
 match protocol webex-media

! 2. アトリビュート（カテゴリ / サブカテゴリ）による集約マッチ
class-map match-all CM_BUSINESS_APPS
 match protocol attribute category business-and-productivity-tools

! 3. 否定条件（match-not）を含むストリーミング分類
class-map match-all CM_STREAMING_VIDEO
 match protocol attribute category voice-and-video
 match protocol attribute sub-category streaming
 match not protocol youtube
 match not protocol netflix

! 4. MQC Policy-Map でのアクション定義
policy-map PM_MARKING_LAN
 class CM_WEBEX
  set dscp af41
 class CM_BUSINESS_APPS
  set dscp af21
 class CM_STREAMING_VIDEO
  set dscp af31
 class class-default
  set dscp default

! 5. インターフェイスへの適用
interface GigabitEthernet0/0/1
 service-policy input PM_MARKING_LAN
```

### 2. カスタムプロトコル (`ip nbar custom`) 定義
```bash
! 例 1: ペイロードオフセット 5 バイト目に ASCII 文字列 "SALES" を含む TCP トラフィック
ip nbar custom CUST_SALES_APP 5 ascii SALES source tcp 4567

! 例 2: 7 バイト目に HEX 値 0x56 を含む UDP トラフィック
ip nbar custom CUST_VIRUS_SIG 7 hex 56 destination udp 3000

! 例 3: 特定の HTTP Host / URL パターンに一致するカスタム Web アプリ
ip nbar custom CUST_INTERNAL_PORTAL http host "*portal.company.local"

! カスタムプロトコルの Class-Map 適用
class-map match-all CM_CUSTOM_APP
 match protocol CUST_SALES_APP
```

### 3. Protocol Discovery (トラフィックプロファイリング) 有効化
```bash
interface GigabitEthernet0/0/2
 ! IPv4 トラフィックの自動プロファイリング有効化
 ip nbar protocol-discovery
 ! IPv6 トラフィックの自動プロファイリング有効化
 ip nbar protocol-discovery ipv6
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **NBAR 動作状態確認** | `show ip nbar protocol-discovery [top-n <N>]` |
| **特定プロトコルの属性表示** | `show ip nbar protocol-attribute <PROTOCOL_NAME>` |
| **指定属性に対応するプロトコル一覧** | `show ip nbar attribute category <CATEGORY_NAME>` |
| **カスタムプロトコルポートマップ** | `show ip nbar port-map [<CUSTOM_NAME>]` |
| **Protocol Pack バージョン確認** | `show ip nbar protocol-pack active` |
| **MQC パケットマッチ数・ドロップ数確認** | `show policy-map interface <INT_NAME>` |
| **NBAR メモリ / リソース状態確認** | `show ip nbar resources flow` |
| **デバッグログ有効化** | `debug ip nbar classification` / `debug ip nbar packets` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **NBAR マッチ数が一切増加しない** | CEF (`ip cef`) が無効化されている | `show ip cef` | `ip cef` および `ipv6 cef` をグローバルで有効化する |
| **`show ip nbar protocol-discovery` で Unknown が多発する** | 非対称ルーティングにより双方向フローを追跡できない | `show ip nbar protocol-discovery` | 非対称パスを解消するか、`ip nbar custom` で手動識別ルールを定義する |
| **HTTPS アプリケーションが正しく分類されない** | TLS/SSL 暗号化により L7 ペイロードが不可視 | `show ip nbar protocol-attribute <NAME>` | SNI (Server Name Indication) 照合を活用するか、IP 範囲 / Custom シグネチャを併用する |
| **新種アプリが識別されず class-default へ流れる** | ルータ内蔵の Protocol Pack シグネチャが古い | `show ip nbar protocol-pack active` | 最新の Protocol Pack File (`.pak`) をダウンロードし `ip nbar protocol-pack` で適用する |
| **NBAR 有効化後に CPU 使用率が急上昇する** | アクティブフロー数がメモリ上限・しきい値を超滅 | `show ip nbar resources flow` | 不要なインターフェイスの `ip nbar protocol-discovery` を停止し、MQC 適用ポイントを精査する |

---

## ⚠ 制限事項

* **CEF 依存性:** CEF (Cisco Express Forwarding) が無効なインターフェイスやプロセススイッチングトラフィックには適用不可。
* **非対称ルーティング (Asymmetric Routing):** TCP/UDP のハンドシェイクや双方向シーケンスが観察できない片道パスでは、プロトコル判定が `Unknown` にフォールバックする。
* **完全暗号化ペイロード:** ESNI (Encrypted SNI) や ECH (Encrypted Client Hello) が適用された通信では、L7 ドメイン名が隠蔽されるため IP アドレスブロックや補完的識別技術が必要。
* **リソース制限:** NBAR2 はメモリ使用率上限（デフォルト割り当て領域）を設定しており、アクティブフロー数が過剰になると新規フローの DPI 解析がスキップされる。

---

## 🔄 他技術との関連

* **MQC (Modular QoS CLI):** `class-map` 内の `match protocol` 条件として NBAR2 を直接呼び出し、`set dscp`, `police`, `shape`, `priority` 等の QoS アクションを適用する。
* **AVC (Application Visibility Control):** NBAR2（アプリ識別）＋ Flexible NetFlow（フロー出力）＋ MQC（制御）を組み合わせた Cisco の統合アプリケーション管理フレームワーク。
* **SD-WAN (App-Route / Application-Aware Routing):** WAN Edge (cEdge) 上で NBAR2 DPI エンジンを利用してアプリ（Office365, WebEx 等）をリアルタイム識別し、SLA（遅延・ジッター・ドロップ率）に応じた最適回線（MPLS vs Internet）へ動的ルーティングする。
* **PfR (Performance Routing):** NBAR2 でプロファイリングされたアプリクラスを PfR マップにバインドし、回線状態に応じた経路切り替えを実行。

---

## 🧩 比較表

| 比較項目 | L4 ACL ベース分類 | Classic NBAR (PDLM) | NBAR2 (Next-Gen) |
| :--- | :--- | :--- | :--- |
| **識別レイヤ** | L3/L4 (IP, Port) | L4-L7 (DPI) | L4-L7 (Advanced DPI) |
| **シグネチャ管理** | 静的（手動定義） | 個別 PDLM ファイル | 統合 Protocol Pack (.pak) |
| **対応プロトコル数** | 限定的 | 数百種類 | 1,500 種類以上 |
| **動的ポート追跡** | 不可 | 可能 | 高精度で可能 |
| **IPv6 サポート** | 別途 IPv6 ACL が必要 | 限定的 | **完全ネイティブ対応** |
| **属性（Attribute）機能**| なし | なし | **Category / Sub-category 対応** |

---

## 💡 ベストプラクティス

1. **適材適所のバインド:**  
   ハードウェア ASIC（Catalyst スイッチ等）で処理可能な L3/L4 マーキングはアクセススイッチ側で行い、DPI 処理（NBAR2）が必要なアプリケーションのみを WAN ルータの Ingress LAN 境界で処理させる。
2. **属性（Attribute）を活用した分類の簡素化:**  
   個別アプリ（Skype, Zoom, WebEx, Teams 等）を 1 つずつ定義するのではなく、`sub-category voice-video-chat-collaboration` 等の属性を使用して保守性を向上させる。
3. **リソース状態の事前確認:**  
   大規模拠点やコアWANルータで有効化する際は、`show ip nbar resources flow` でメモリ使用率を計測し、推奨上限（70%）を超えないよう設計する。

---


## 📝 ラボ学習・設定サンプル例

### ラボ 1: NBAR2 による WebEx ミーティング識別 ＆ DSCP AF41 マーキング

* **問題:** 拠点ルータ R1 において、社員が利用する Cisco WebEx 通信（`webex-media` および `webex-meeting`）を NBAR2 で自動識別し、LAN 入力インターフェイスで `DSCP AF41` をマークせよ。
* **要件:**
  * ACL による IP/Port 直書きは禁止する。
  * NBAR2 アプリケーション識別を使用すること。
  * 入力インターフェイス GigabitEthernet0/0/1 に適用すること。
* **設定例:**
```bash
! 1. WebEx アプリケーションを識別する Class-Map の作成
class-map match-any CM_WEBEX_TRAFFIC
 match protocol webex-media
 match protocol webex-meeting
 match protocol webex-app-sharing

! 2. DSCP AF41 を付与する Policy-Map の作成
policy-map PM_MARKING_INGRESS
 class CM_WEBEX_TRAFFIC
  set dscp af41
 class class-default
  set dscp default

! 3. LAN 側入力インターフェイスへのバインド
interface GigabitEthernet0/0/1
 service-policy input PM_MARKING_INGRESS
```
* **検証方法:**
  * `show class-map CM_WEBEX_TRAFFIC` でプロトコル定義を確認。
  * 端末から WebEx ミーティングを開始し、`show policy-map interface GigabitEthernet0/0/1` で `CM_WEBEX_TRAFFIC` クラスのパケット数 / バイト数が増加し、`set dscp af41` が実行されていることを確認。

---

### ラボ 2: NBAR2 Attribute ベース分類による File-Sharing カテゴリポリシング

* **問題:** ネットワーク帯域圧迫を防止するため、`file-sharing` カテゴリに属するすべての P2P / ファイル共有アプリケーションをまとめてポリシングし、1 Mbps（バースト 15,000 バイト）を超えた通信をドロップせよ。
* **要件:**
  * 個別プロトコル名ではなく、NBAR2 アトリビュート (`category`) を使用すること。
  * 超過パケットはドロップ（`exceed-action drop`）させること。
* **設定例:**
```bash
! 1. file-sharing カテゴリに属する全アプリにマッチする Class-Map
class-map match-all CM_FILE_SHARING_APPS
 match protocol attribute category file-sharing

! 2. 1Mbps のポリシングを定義する Policy-Map
policy-map PM_POLICE_FILE_SHARING
 class CM_FILE_SHARING_APPS
  police cir 1000000 bc 15000
   conform-action transmit
   exceed-action drop

! 3. インターフェイスへ適用
interface GigabitEthernet0/0/2
 service-policy input PM_POLICE_FILE_SHARING
```
* **検証方法:**
  * `show ip nbar attribute category file-sharing` を実行し、BitTorrent や FTP、Dropbox 等が該当属性に含まれることを確認。
  * 大容量ファイル転送を発生させ、`show policy-map interface GigabitEthernet0/0/2` で `exceed` カウンタが増加してドロップされていることを確認。

---

### ラボ 3: NBAR2 否定マッチ (`match not protocol`) による Scavenger クラス分離

* **問題:** ストリーミングビデオ全般を `DSCP AF31` にマークする一方で、YouTube および Netflix トラフィックのみを除外（`match not protocol`）し、別途 Scavenger クラス（`DSCP CS1`）へ低降格させよ。
* **要件:**
  * `voice-and-video` カテゴリの `streaming` サブカテゴリを使用すること。
  * YouTube および Netflix は除外条件を設定すること。
* **設定例:**
```bash
! 1. 一般ストリーミングクラス (YouTube / Netflix を除外)
class-map match-all CM_BUSINESS_STREAMING
 match protocol attribute category voice-and-video
 match protocol attribute sub-category streaming
 match not protocol youtube
 match not protocol netflix

! 2. Scavenger アプリクラス (YouTube / Netflix)
class-map match-any CM_SCAVENGER_APPS
 match protocol youtube
 match protocol netflix

! 3. マーキングポリシーの作成
policy-map PM_CLASSIFY_STREAMING
 class CM_BUSINESS_STREAMING
  set dscp af31
 class CM_SCAVENGER_APPS
  set dscp cs1
 class class-default
  set dscp default

! 4. インターフェイスバインド
interface GigabitEthernet0/0/1
 service-policy input PM_CLASSIFY_STREAMING
```
* **検証方法:**
  * 社内ビデオ配信を視聴し、`CM_BUSINESS_STREAMING` にマッチして `DSCP AF31` が付与されることを確認。
  * YouTube を視聴し、`CM_SCAVENGER_APPS` にマッチして `DSCP CS1` に低降格されることを確認。

---

### ラボ 4: `ip nbar custom` によるカスタム ASCII アプリケーション定義

* **問題:** 企業独自開発の営業基幹システム（TCP ポート 4567 を使用し、パケット先頭 5 バイト目に "SALES" という ASCII 文字列を含む）を NBAR2 カスタムプロトコルとして定義し、`DSCP AF21` をマークせよ。
* **要件:**
  * カスタムプロトコル名: `CUST_SALES_APP`
  * オフセット: 5 バイト目、文字列: "SALES"、ソース TCP ポート: 4567
* **設定例:**
```bash
! 1. カスタム NBAR2 プロトコルの定義
ip nbar custom CUST_SALES_APP 5 ascii SALES source tcp 4567

! 2. Class-Map でのカスタムプロトコル指定
class-map match-all CM_SALES_APP
 match protocol CUST_SALES_APP

! 3. Policy-Map での AF21 マーキング
policy-map PM_SALES_MARKING
 class CM_SALES_APP
  set dscp af21
 class class-default
  set dscp default

! 4. インターフェイス適用
interface GigabitEthernet0/0/1
 service-policy input PM_SALES_MARKING
```
* **検証方法:**
  * `show ip nbar port-map CUST_SALES_APP` を実行し、ポートおよびバッファ一致条件を確認。
  * 該当パケットを送信し、`show policy-map interface GigabitEthernet0/0/1` で `CM_SALES_APP` のカウント増加を確認。

---

### ラボ 5: `ip nbar custom` による HEX オフセットバイナリパターン定義

* **問題:** 特定のマルウェア・攻撃通信（UDP 目的地ポート 3000、ペイロード 7 バイト目に HEX パターン `0x56` を含む）を NBAR2 カスタムシグネチャで検出し、即座にドロップさせよ。
* **要件:**
  * プロトコル名: `CUST_VIRUS_SIG`
  * オフセット: 7 バイト目、HEX 値: `56`、宛先 UDP ポート: 3000
* **設定例:**
```bash
! 1. HEX パターンを用いたカスタム NBAR2 シグネチャ定義
ip nbar custom CUST_VIRUS_SIG 7 hex 56 destination udp 3000

! 2. Class-Map 定義
class-map match-all CM_VIRUS_TRAFFIC
 match protocol CUST_VIRUS_SIG

! 3. Policy-Map でのドロップ処理
policy-map PM_BLOCK_VIRUS
 class CM_VIRUS_TRAFFIC
  drop

! 4. 適用
interface GigabitEthernet0/0/1
 service-policy input PM_BLOCK_VIRUS
```
* **検証方法:**
  * `show ip nbar port-map CUST_VIRUS_SIG` で UDP 3000 / HEX 56 の登録を確認。
  * 該当パケット送出時に `show policy-map interface GigabitEthernet0/0/1` で `drop` カウントが増加することを確認。

---

### ラボ 6: Protocol Discovery による双方向トラフィックプロファイリング

* **問題:** インターフェイス GigabitEthernet0/0/3 において、IPv4 および IPv6 の双方のアプリケーション通信量をリアルタイム計測・可視化せよ。
* **要件:**
  * MQC アクション（Policing/Marking）は適用せず、Protocol Discovery（受動プロファイリング）のみ動作させること。
  * IPv4 と IPv6 の両方をアクティブ化すること。
* **設定例:**
```bash
! 1. インターフェイスでの Protocol Discovery 有効化
interface GigabitEthernet0/0/3
 ip nbar protocol-discovery
 ip nbar protocol-discovery ipv6
```
* **検証方法:**
  * 通信発生後、`show ip nbar protocol-discovery` を実行し、プロトコルごとの Input/Output バイト数および bps 速度を確認。
  * `show ip nbar protocol-discovery top-n 5` を実行し、帯域消費上位 5 アプリを表示。

---

### ラボ 7: トンネル化 IPv6 トラフィック (Teredo / ISATAP) の NBAR2 識別 ＆ MQC 適用

* **問題:** IPv4 ネットワーク上をトンネル化されて通過する Teredo および ISATAP 経由の IPv6 トラフィックを NBAR2 で識別し、200 kbps にポリシングせよ。
* **要件:**
  * `ip nbar classification tunneled-traffic` 機能を有効化すること。
  * `teredo-ipv6-tunneled` および `isatap-ipv6-tunneled` プロトコルをマッチさせること。
* **設定例:**
```bash
! 1. トンネル化トラフィックの NBAR2 識別をグローバル有効化
ip nbar classification tunneled-traffic teredo
ip nbar classification tunneled-traffic isatap

! 2. トンネル化 IPv6 クラスマップの定義
class-map match-any CM_TUNNELED_IPV6
 match protocol teredo-ipv6-tunneled
 match protocol isatap-ipv6-tunneled

! 3. Policy-Map でのポリシング
policy-map PM_POLICE_TUNNELED_V6
 class CM_TUNNELED_IPV6
  police 200000
   conform-action transmit
   exceed-action drop

! 4. インターフェイス適用
interface GigabitEthernet0/0/1
 service-policy input PM_POLICE_TUNNELED_V6
```
* **検証方法:**
  * Teredo トンネル経由の通信を発生させ、`show policy-map interface GigabitEthernet0/0/1` で `CM_TUNNELED_IPV6` にマッチしポリシングされることを確認。

---

### ラボ 8: NBAR2 ＋ 1r3c Policier (RFC 2697) による Down-Marking 構成

* **問題:** Citrix トラフィック（`citrix`）に対して、CIR 2 Mbps（バースト 37,500 バイト）の 1r3c ポリサーを適用せよ。帯域内（Conform）は `DSCP AF21` で送信し、超過（Exceed）したパケットは `DSCP AF22` に Down-mark（降格）して送信、違反（Violate）パケットはドロップせよ。
* **要件:**
  * Single-Rate Three-Color Policier (1r3c / RFC 2697) を使用すること。
* **設定例:**
```bash
! 1. Citrix Class-Map
class-map match-all CM_CITRIX
 match protocol citrix

! 2. 1r3c Policier Policy-Map
policy-map PM_CITRIX_MARKDOWN
 class CM_CITRIX
  police cir 2000000 bc 37500 be 37500
   conform-action set-dscp-transmit af21
   exceed-action set-dscp-transmit af22
   violate-action drop

! 3. インターフェイス適用
interface GigabitEthernet0/0/2
 service-policy input PM_CITRIX_MARKDOWN
```
* **検証方法:**
  * 2Mbps 未満の通信で `DSCP AF21` が付与され、2Mbps 超過時に `DSCP AF22` へ降格マークされ、大幅バースト時にドロップされることを `show policy-map interface GigabitEthernet0/0/2` で確認。

---

### ラボ 9: NBAR2 ＋ LLQ (Voice) ＋ CBWFQ 複合 QoS ポリシー

* **問題:** WAN 出力インターフェイスにおいて、NBAR2 で識別した Cisco IP Phone（`cisco-phone`）を 512 kbps の厳格優先キュー（LLQ）へ割り当て、WebEx（`webex-group`）に 2 Mbps（CBWFQ）を保証せよ。
* **要件:**
  * 音声通信には Strict Priority (LLQ) を適用すること。
  * WebEx アプリケーショングループを使用すること。
* **設定例:**
```bash
! 1. Class-Map 定義
class-map match-all CM_VOICE_PHONE
 match protocol cisco-phone

class-map match-all CM_WEBEX_GROUP
 match protocol application-group webex-group

! 2. LLQ / CBWFQ Policy-Map 定義
policy-map PM_WAN_EGRESS_QOS
 class CM_VOICE_PHONE
  priority 512
 class CM_WEBEX_GROUP
  bandwidth 2000
 class class-default
  fair-queue

! 3. WAN インターフェイス出力バインド
interface Serial1/0/0
 service-policy output PM_WAN_EGRESS_QOS
```
* **検証方法:**
  * `show policy-map interface Serial1/0/0` を実行し、`CM_VOICE_PHONE` が Priority Queue として動作し、`CM_WEBEX_GROUP` が 2000 kbps の保証帯域で処理されていることを確認。

---

### ラボ 10: NBAR2 ＋ Flexible NetFlow (AVC) 連携と CoPP 併用

* **问题:** NBAR2 DPI エンジンで識別したアプリケーション情報を Flexible NetFlow (FNF) で集計して NMS (10.1.1.50) へエクスポートすると同時に、インバンド管理通信（SSH / SNMP）を CoPP で保護せよ。
* **要件:**
  * FNF Record に `application name` キーフィールドを含めること。
  * CoPP で NBAR2 の CPU 負荷に伴う管理通信応答停止を防止すること。
* **設定例:**
```bash
! 1. FNF Flow Record の定義 (NBAR2 アプリ名を含める)
flow record REC_AVC
 match ipv4 source address
 match ipv4 destination address
 match application name
 collect counter bytes
 collect counter packets

! 2. Flow Exporter の定義
flow exporter EXP_NMS
 destination 10.1.1.50
 transport udp 2055

! 3. Flow Monitor の定義
flow monitor MON_AVC
 record REC_AVC
 exporter EXP_NMS

! 4. インターフェイスへの FNF 適用
interface GigabitEthernet0/0/1
 ip flow monitor MON_AVC input

! 5. CoPP によるインバンド管理保護
access-list 100 permit tcp any any eq 22
access-list 100 permit udp any any eq 161

class-map match-all CM_MGMT_TRAFFIC
 match access-group 100

policy-map PM_COPP
 class CM_MGMT_TRAFFIC
  police 1000000 bc 10000
   conform-action transmit
   exceed-action drop

control-plane
 service-policy input PM_COPP
```
* **検証方法:**
  * `show flow monitor MON_AVC cache` を実行し、流れている通信の `APPLICATION NAME`（例: `http`, `ssl`, `webex-media`）が FNF キャッシュに動的記録されていることを確認。
  * `show policy-map control-plane` で CoPP の正常動作を確認。

---


## ❓ 想定試験問題

### 問 1 (トラブルシューティング)
**シナリオ:**  
ネットワーク管理者 R1 において、WebEx トラフィックを NBAR2 で識別して `DSCP AF41` をマークする MQC ポリシーを投入した。しかし、`show policy-map interface GigabitEthernet0/0/1` を実行しても `CM_WEBEX` クラスのパケットカウントが一切増加せず、すべてのパケットが `class-default` に分類されている。インターフェイスコンフィグは正しく設定されている。

**設問:**  
この現象が発生している最も可能性の高い根本原因と、R1 で確認・実行すべき修復コマンドを述べよ。

* **解答・解説:**
  * **根本原因:** ルータ上で Cisco Express Forwarding (CEF) が無効化（`no ip cef`）されているため。NBAR/NBAR2 DPI エンジンは CEF スイッチングパス上で動作するよう設計されており、CEF が無効な状態ではパケットがプロセススイッチング処理され、NBAR による L7 ペイロード解析がバイパスされる。
  * **確認コマンド:**  
    `show ip cef`（`CEF is not running` と表示されることを確認）
  * **修復コマンド:**  
    ```bash
    R1(config)# ip cef
    R1(config)# ipv6 cef
    ```

---

### 問 2 (コンフィグ読解・トラブルシューティング)
**シナリオ:**  
デュアルスタック環境の WAN 境界ルータにおいて、以下の Class-Map が定義されている。
```bash
class-map match-all CM_VOICE_SIGNALING
 match ip dscp cs3
```
IPv4 の SIP シグナリングパケットは正常にマッチして優先制御されているが、IPv6 SIP パケットがこのクラスにマッチせず `class-default` に落とされる障害が発生している。

**設問:**  
このコンフィグの不備を指摘し、IPv4 および IPv6 の双方に正しくマッチさせるための修正コマンドを提示せよ。

* **解答・解説:**
  * **不備の指摘:** `match ip dscp` コマンドは IPv4 パケットの ToS/DSCP ヘッダーのみを評価するキーワードであり、IPv6 パケットの Traffic Class / DSCP ヘッダーを評価対象外として無視する。
  * **修正コマンド:**  
    `ip` キーワードを削除し、IPv4/IPv6 共通キーワードである `match dscp` に変更する。
    ```bash
    R1(config)# class-map match-all CM_VOICE_SIGNALING
    R1(config-cmap)# no match ip dscp cs3
    R1(config-cmap)# match dscp cs3
    ```

---

### 問 3 (Design / AVC リソース設計)
**シナリオ:**  
大規模拠点ルータ（ASR 1000 シリーズ）において、NBAR2 Protocol Discovery と Flexible NetFlow (FNF) を同時有効化して全通信の可視化（AVC）を行っている。ピーク時間帯になると、一部の通信でプロトコル判定が `Unknown` にフォールバックする現象が発生した。

**設問:**  
この現象の発生原因として考えられる NBAR2 システムリソース上の理由と、運用中に確認すべき検証コマンドを答えよ。また、CPU/メモリ保護の観点から推奨されるメモリ限界値（パーセンテージ）を述べよ。

* **解答・解説:**
  * **発生原因:** ルータの NBAR2 DPI エンジンに割り当てられたアクティブフロー数またはメモリ消費上限（Maximum Memory Usage）を超滅したため、新規発生フローの DPI ペイロード解析がスキップされ `Unknown` として処理された。
  * **検証コマンド:**  
    `show ip nbar resources flow`（アクティブセッション数および Peak Memory Usage を確認）
  * **推奨限界値:** NBAR2 に割り当てられたメモリ使用率は **70% 以下** に抑えることが Cisco ベストプラクティスとして推奨される。

---

### 問 4 (実装 / Custom Protocol)
**シナリオ:**  
社内独自開発アプリ（送信元 TCP ポート 8888、パケットの 10 バイト目に ASCII 文字列 "DATABASE" を保持）の通信を識別し、`DSCP AF21` をマークする必要がある。

**設問:**  
この要求を満たすための `ip nbar custom` 設定コマンドおよび Class-Map コンフィグを記述せよ。

* **解答・解説:**
  ```bash
  ! 1. カスタム NBAR2 プロトコルの定義
  R1(config)# ip nbar custom CUST_DB_APP 10 ascii DATABASE source tcp 8888

  ! 2. Class-Map でのマッチ指定
  R1(config)# class-map match-all CM_CUSTOM_DB
  R1(config-cmap)# match protocol CUST_DB_APP
  ```

---

### 問 5 (トラブルシューティング / Asymmetric Routing)
**シナリオ:**  
2 台のルータ（R1, R2）で HSRP および BGP マルチホームを構成している拠点において、R1 の LAN 入力ポートで NBAR2 Protocol Discovery を有効化したが、多くの Web アプリケーションが `Unknown` と出力される。パケットキャプチャを確認すると、送信パケットは R1 を通過しているが、戻りパケットは R2 を通過していることが判明した。

**設問:**  
NBAR2 がプロトコル識別失敗（`Unknown` 化）に至った技術的理由を説明せよ。

* **解答・解説:**
  * **技術的理由:** NBAR2 DPI エンジンは、TCP/UDP のハンドシェイクや双方向シーケンス（クライアントからのリクエストとサーバーからのレスポンスの相互交信）を同一ルータ上で追跡してシグネチャ照合を行う。非対称ルーティング（Asymmetric Routing）が発生すると、片方向のパケットしか観察できず、フローのステートフル判定が完結しないため `Unknown` に判定がフォールバックする。

---

## 🔗 参考リソース

Cisco 公式ドキュメントおよび技術資料:

* Cisco IOS XE Quality of Service Configuration Guide - Classifying Network Traffic Using NBAR
* Cisco Command Reference - ip nbar protocol-discovery
* Cisco Live Presentation - BRKENT-2731: What QoS can do for your network with Catalyst 8000 and IOS XE
* Cisco Product Bulletin - NBAR2 Protocol Library and Protocol Pack Release Notes
* Cisco Technical Note - Troubleshooting NBAR and NBAR2 Classification Issues
* Cisco Application Visibility and Control (AVC) Solution Guide

---

## 📝 補足（Notes）

### NBAR / NBAR2 の学習要点チェックリスト
1. **CEF 必須:** `ip cef` / `ipv6 cef` が有効化されているか？
2. **コマンドの共通化:** `match ip dscp` ではなく `match dscp` または `match protocol` を使っているか？
3. **Protocol Pack の概念:** NBAR2 では PDLM ではなく統合 `.pak` ファイルで動作すること。
4. **属性 (Attribute) 分類:** `category`, `sub-category`, `application-group` の使い分け。
5. **カスタムプロトコル:** `ip nbar custom <NAME> <OFFSET> <ascii|hex> <PATTERN> [source|destination] [tcp|udp] <PORT>` の構文理解。
6. **非対称パスの考慮:** 非対称ルーティング環境では NBAR2 の識別精度が低下することの認識。

---




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


