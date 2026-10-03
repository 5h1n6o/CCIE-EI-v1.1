---
layout: default
title: 2.2.f-Localized-policies
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 6
---

# 2.2.f Localized policies

CCIE EI v1.1 Blueprint 2.2.f における **Localized Policies（ローカライズドポリシー）**（2.2.f (i) Access lists, 2.2.f (ii) Route policies）の統合学習メモです。

本ドキュメントは、Cisco Catalyst SD-WAN 20.x および Cisco IOS-XE 17.x（cEdge / Catalyst 8000 シリーズ）の公式ドキュメント、Configuration Guide、Cisco Live 資料、CVD に準拠し、CCIE EI ラボ試験で求められる「設計・設定・検証・トラブルシューティング」を網羅しています。

---

## 📘 概要

### 機能概要
**Localized Policy（ローカライズドポリシー）** は、Cisco SD-WAN の WAN Edge（cEdge / vEdge）デバイスの**ローカル環境（データプレーン / コントロールプレーン / サービス VRF / 転送 VRF）** に適用されるポリシー群です。
vSmart コントローラ上で全社的に計算・評価される Centralized Policy とは異なり、vManage で定義された Localized Policy 定義（または CLI 直投入）が特定 WAN Edge にプッシュされ、その Edge 内部の処理エンジン（CEF、OSPF/BGP ルーティングプロセス、QoS / ACL エンジン）で直接実行されます。

主に以下の 2 つのコンポーネントで構成されます。
1. **Access Lists (ACL / Data/QoS Policy / Class-Map / Policy-Map):**
   * インターフェイス（Service VPN / Transport VPN 0）に入出力するデータパケットのフィルタリング、QoS アシグメント（Class-Map / Policy-Map）、Policing、DSCP リマーキングを実施。
2. **Route Policies (Route-Maps):**
   * サイトローカル（Service VPN 側）で動作する動的ルーティングプロトコル（OSPF, BGP）や静的ルートと、OMP (Overlay Management Protocol) との間の相互再配送・ルートフィルタリング・BGP Community/AS-Path 操作を実施。

### 利用目的
* **ローカルセキュリティーとデータ制御:** サイト内部のクライアント間通信のアクセス制御（ACL）、不要なトラフィックのローカルドロップ。
* **ローカル QoS 制御:** 物理 WAN インターフェイス帯域に対する LLQ（Low Latency Queuing）、CBWFQ、Policing、DSCP リマーキングの適用。
* **ローカルルーティングの制御:** LAN 側 OSPF / BGP ピアリングでの特定プレフィックスのフィルタリング、メトリック/MED/AS-Path/Community 操作、相互再配送ルーピング防止。

### どのような場面で利用するか
* **拠点 LAN 側ルータとの BGP ピアリング時:** 特定の LAN 側ルートのみを OMP へ流入させたい場合（Route-Map / Prefix-List によるフィルタ）。
* **拠点内 OSPF 相互再配送時:** OMP から OSPF へ再配送する際に特定タグ（Tag）を付与し、ルーティングループを遮断する場合。
* **WAN 回線の帯域制御（QoS）:** サービス VPN 側から入ってきた Voice パケットに EF (DSCP 46) をマーキングし、LLQ 優先キューに割り当てる場合。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **定義場所** | vManage（Localized Policy 画面）または Edge ローカル CLI |
| **実行場所** | 特定 WAN Edge（cEdge / vEdge）のローカルエンジン（CEF / ルーティングプロセス） |
| **主なコンポーネント** | Access Lists (ACL/QoS/Policing), Route Policies (Route-Maps / Prefix-Lists) |
| **メリット** | 拠点固有の特殊な LAN 構成や物理回線要件に合わせた柔軟な制御が可能。vSmart の CPU 負荷を増加させない |
| **デメリット** | 拠点ごとにポリシー設計が拡散しやすいため、vManage Feature Template / Policy のモジュール管理が必要 |
| **対応機種** | 全 Cisco WAN Edge (Catalyst 8000 シリーズ, ASR1000, ISR4000, c8000v, vEdge) |
| **暗黙の動作** | ACL: 暗黙の拒否 (Implicit Deny)<br>Route Policy: 暗黙の拒否 (Implicit Deny) |
| **設計上の注意点** | Localized Policy を特定デバイスに反映するには、vManage 上で **Device Template 内の "Policy -> Localized Policy" に結合して Push** する必要がある |

---

## 🏗 動作原理

### 1. Access Lists (ACL / QoS Policy) の処理構造

```text
[ Service VPN Client / LAN ]
              │
              ▼ (Ingress ACL / QoS Marking)
┌──────────────────────────────────────────────┐
│  WAN Edge (cEdge) Data Plane                │
│  - Class-Map Matching (DSCP / 5-Tuple)       │
│  - Policy-Map / Police / Remarking           │
│  - Access-List Packet Filtering (Permit/Deny)│
└──────────────────────────────────────────────┘
              │
              ▼ (Egress QoS Queuing)
[ WAN Transport / IPsec Tunnel (VPN 0) ]
```

* **Ingress 処理:** サービス VPN ポートに入ったパケットに対し、ACL による許可/拒否、Class-Map/Policy-Map による DSCP 付与や Policing を実行。
* **Egress 処理:** IPsec トンネル送出時に、アサインされた QoS Class (Queue 0〜7) に従い LLQ / CBWFQ スケジューリングを実施。

### 2. Route Policies (Route-Map) の処理構造

```text
[ Site LAN Router (OSPF / BGP) ]
              ▲
              │ (Route-Map Filter / Attribute Set)
┌─────────────┴────────────────────────────────┐
│  WAN Edge (cEdge) Routing Process            │
│  - Redistribution (OMP ➔ OSPF / BGP)          │
│  - Redistribution (OSPF / BGP ➔ OMP)          │
└─────────────┬────────────────────────────────┘
              ▲
              │ (OMP Protocol)
        [ vSmart / OMP ]
```

* **Inbound (LAN ➔ OMP):** LAN 側から受領した OSPF/BGP 経路に対し、Prefix-List / Route-Map でフィルタリングや Tag 付与を行い、OMP に渡す。
* **Outbound (OMP ➔ LAN):** OMP から受領したオーバーレイ経路に対し、Route-Map で Metric / MED / Community を変更して LAN 側 OSPF/BGP へアドバタイズ。

---

## ⚙ 動作シーケンス

### Localized Policy 適用・処理シーケンス

```text
[vManage]                      [WAN Edge (cEdge)]              [LAN Router / Data Traffic]
   │                                   │                                     │
   │ 1. Localized Policy 定義          │                                     │
   │    (ACL / Route Policy / QoS)     │                                     │
   │──────────────────────────────────>│                                     │
   │ 2. Device Template にバインド・Push│                                     │
   │──────────────────────────────────>│                                     │
   │                                   │ 3. 内部 CLI コンフィグ展開           │
   │                                   │    - policy-map / access-list       │
   │                                   │    - route-map                      │
   │                                   │                                     │
   │                                   │<── 4. LAN 側 OSPF/BGP ピアリング ───│
   │                                   │    (Route-Map による制御・タグ付与) │
   │                                   │                                     │
   │                                   │<── 5. LAN 側データパケット受信 ───────│
   │                                   │    (ACL / QoS Policy 評価・マーキング)│
```

1. **Policy 作成:** vManage で Localized Policy（Access List, Route Policy, QoS Class-Map/Policy-Map）を作成。
2. **Template 結合:** Device Template の "Policy" セクションで作成した Localized Policy をバインドして Device に Push。
3. **CLI 変換:** cEdge 内部で標準的な IOS-XE CLI（`ip access-list`, `policy-map`, `route-map`）に展開・適用。
4. **コントロール面処理:** サイトローカルの BGP/OSPF 経路交換時に Route Policy が評価される。
5. **データ面処理:** LAN/WAN インターフェイスを通過するパケットに対して ACL/QoS ポリシーが適用される。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
1. **Access Lists (2.2.f (i)):**
   * Service VPN インターフェイスにおける IPv4/IPv6 パケットフィルタリング。
   * QoS Class-Map / Policy-Map による優先キューイング（LLQ: Queue 0）と Shaping/Policing。
   * Implicit Deny に配慮した ACL 記述（許可パケットが落ちないように最後に permit ip any any を意識）。
2. **Route Policies (2.2.f (ii)):**
   * OMP 側と LAN 側（BGP/OSPF）間の双方向 Route-Map 制御。
   * **BGP パラメータ操作:** Local Preference, MED, AS-Path Prepend, BGP Community の付与・変換。
   * **OSPF パラメータ操作:** Metric, Metric-Type (E1/E2), Tag 付与による相互再配送ループ防止。

### ラボ試験で設定させられそうな要件パターン
* **要件 1:** 拠点 10 の LAN 側 BGP ルータから受信する特定のサブネット（`172.16.10.0/24`）のみを OMP に再配送し、それ以外のサブネットは除外せよ。
* **要件 2:** cEdge1 の Service VPN 10 側で受容する DSCP EF トラフィックに対し、最大 5Mbps にパケットを Policing（規定超えは Drop）し、残りを QoS Queue 0 にマッピングせよ。
* **要件 3:** OMP 経路を LAN 側の OSPF Area 0 へ再配送する際、Route-Map を用いて Tag 666 を付与し、逆方向の再配送時に Tag 666 を持つ経路をブロックせよ。

### よくある設定ミス・落とし穴
* **暗黙の拒否 (Implicit Deny) による全断:**
  * Route-Map や Access-List の最後に明示的な `permit` ステートメントを忘れ、意図しないルートやパケットが全ドロップする。
* **vManage ポリシーのバインド忘れ:**
  * Localized Policy を作成しただけで、Device Template へのバインド（Policy ➔ Localized Policy）を行わずに Push してしまう。
* **cEdge CLI 直投入と Template オーバーライド:**
  * cEdge 上で直接 `route-map` を作成しても、次回 vManage から Template を Push した際に上書き消去される。必ず vManage 側で Localized Policy / CLI Add-on Template として定義する。

### show コマンド・debug ログによる状態判断
* `show sdwan policy localized-policy-state`: バインドされている Localized Policy のステータス確認。
* `show ip access-lists`: cEdge 上で生成された ACL のステートメントと Hit カウンタの確認。
* `show route-map`: cEdge 上で生成された Route-Map の判定数とルール確認.
* `show policy-map interface <int>`: QoS Policy-Map のクラス別パケットカウント・ドロップ数の確認。

---

## 🛠 設定方法

### 1. vManage GUI での設定フロー

1. **Access List / Class-Map / Policy-Map の作成:**
   * **Configuration ➔ Policies ➔ Custom Options ➔ Localized Policy**
   * **Lists:** Class List, Prefix List, Community List 等を定義。
   * **Access Control Lists:** IPv4/IPv6 ACL ルールを定義。
2. **Route Policy の作成:**
   * **Configuration ➔ Policies ➔ Custom Options ➔ Route Policy**
   * Match 条件（Prefix-List, BGP Community 等）と Set 条件（Metric, Local-Pref, Tag 等）を定義。
3. **Localized Policy アセンブリ:**
   * **Configuration ➔ Policies ➔ Localized Policy ➔ Add Policy**
   * 定義した Route Policy, ACL, QoS Policy を 1 つの Localized Policy パッケージとして統合。
4. **Device Template への適用:**
   * **Configuration ➔ Templates ➔ Device Template 編集**
   * **Additional Templates ➔ Localized Policy** に作成した Policy を選択し、Attach/Push。

### 2. cEdge CLI 設定例 (vManage から生成される等価 CLI)

#### A. Access List (ACL) & QoS Policy 設定

```bash
! --- Class Map 定義 ---
class-map match-any VOICE_CLASS
 match dscp ef
class-map match-any CRITICAL_DATA
 match dscp af31 af32

! --- Policy Map (QoS / Policing) 定義 ---
policy-map LAN_QOS_POLICY
 class VOICE_CLASS
  priority level 1
  police 5000000 64000 conform-action transmit exceed-action drop
 class CRITICAL_DATA
  bandwidth remaining percent 30
 class class-default
  fair-queue

! --- IPv4 Access List 定義 ---
ip access-list extended SECURE_LAN_ACL
 10 deny ip 192.168.10.0 0.0.0.255 192.168.20.0 0.0.0.255
 20 permit ip any any

! --- インターフェイスへの適用 (Service VPN 10) ---
interface GigabitEthernet3.10
 encapsulation dot1Q 10
 ip vrf forwarding 10
 ip address 192.168.10.1 255.255.255.0
 ip access-group SECURE_LAN_ACL in
 service-policy input LAN_QOS_POLICY
```

#### B. Route Policy (Route-Map) 設定

```bash
! --- Prefix List 定義 ---
ip prefix-list LAN_ROUTES seq 5 permit 10.100.0.0/16 le 24
ip prefix-list OMP_IMPORTED seq 5 permit 10.200.0.0/16 le 24

! --- Route-Map: LAN ➔ OMP (BGP / OSPF ➔ OMP) ---
route-map LAN_TO_OMP_POLICY permit 10
 match ip address prefix-list LAN_ROUTES
 set tag 100
route-map LAN_TO_OMP_POLICY deny 99

! --- Route-Map: OMP ➔ LAN (OMP ➔ BGP) ---
route-map OMP_TO_BGP_POLICY permit 10
 match ip address prefix-list OMP_IMPORTED
 set local-preference 200
 set metric 20
route-map OMP_TO_BGP_POLICY permit 20
! (暗黙のドロップを防ぐ許可ルール)

! --- BGP プロセスへの Route-Map バインド ---
router bgp 65100 vrf 10
 neighbor 192.168.10.254 remote-as 65200
 neighbor 192.168.10.254 route-map OMP_TO_BGP_POLICY out
 neighbor 192.168.10.254 route-map LAN_TO_OMP_POLICY in
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 補足・確認項目 |
| :--- | :--- | :--- |
| Localized Policy 状態確認 | <code>show sdwan policy localized-policy-state</code> | Localized Policy が正常にロードされているか |
| ACL 適用・カウント確認 | <code>show ip access-lists</code> | 定義された ACL のルールと Hit カウンタ |
| QoS 統計情報確認 | <code>show policy-map interface GigabitEthernet3.10</code> | 各クラスのパケット数、Policing ドロップ数 |
| Route-Map 定義確認 | <code>show route-map</code> | Route-Map の Match/Set ステートメントと評価数 |
| BGP 経路への適用確認 | <code>show ip bgp vrf 10 neighbors 192.168.10.254 routes</code> | Route-Map 適用後の BGP 属性変更（Local-Pref / Metric） |
| OMP 広告経路の確認 | <code>show sdwan omp advertised-routes vrf 10</code> | LAN から OMP へ正常に再配送・広告されているか |
| プラットフォーム ACL 統計 | <code>show platform hardware qfp active feature acl stats</code> | QFP (ASIC) レベルでの ACL パケット処理 |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **LAN 側ルータとの BGP 経路が全滅した** | Route-Map の最後に `permit` ルールが無く、暗黙の拒否で全削除された | <code>show route-map</code><br><code>show ip bgp vrf 10</code> | Route-Map に全許可の Sequence（例: `route-map POLICY permit 99`）を追加する |
| **ACL を適用した途端に特定通信が不能になった** | ACL の Implicit Deny により必要な通信（DHCP / DNS / Control）がブロックされた | <code>show ip access-lists</code> | ACL の末尾に `permit ip any any` を追加するか、特定トラフィックの Permit ルールを先頭に挿入する |
| **vManage で作成した Localized Policy が Edge に反映されない** | Device Template に Localized Policy がバインドされていない | <code>show sdwan policy localized-policy-state</code> | Device Template の "Additional Templates ➔ Localized Policy" に結合して Push する |
| **QoS 優先キューでパケットが大量ドロップする** | Policing の帯域設定（burst / rate）が低すぎる | <code>show policy-map interface</code> | Police rate を回線速度・音声チャネル数に合わせて適切な値に拡張する |
| **OMP 経路が LAN 側 OSPF に再配送されない** | OMP ➔ OSPF 再配送時の Route-Map で Metric-Type や Tag 条件が不一致 | <code>show ip ospf redistribute</code><br><code>show route-map</code> | Route-Map 内の Match 条件を確認し、`subnets` オプションを再配送設定に追加する |

---

## ⚠ 制限事項

1. **プラットフォーム制限:**
   * cEdge (IOS-XE) と vEdge (Viptela OS) では、QoS ポリシーや ACL の CLI 構文（IOS-XE MQC vs Viptela CLI）が異なります。vManage の Policy 画面で適切にタイプを選択する必要があります。
2. **QoS キュー数:**
   * SD-WAN 標準では最大 8 キュー（Queue 0〜7）をサポート。Queue 0 はデフォルトで LLQ (Low Latency Queuing) として扱われます。
3. **Route Policy 制限:**
   * Localized Route Policy は、**サイトローカルのプロトコル（BGP, OSPF, EIGRP, Static）と OMP 間** のやり取りのみを制御します。vSmart 上でのオーバーレイコントロール制御には Centralized Control Policy を使用する必要があります。

---

## 🔄 他技術との関連

* **Centralized Policy:**
  * Centralized Policy（vSmart 上）でオーバーレイ全体のトポロジーや AAR を制御し、Localized Policy（WAN Edge 上）で個別の LAN 側 BGP/OSPF ルーティングや局所 QoS を制御します。
* **Cisco Application-Aware Routing (AAR):**
  * Localized Policy で設定した QoS Class-Map / Policy-Map は、AAR による動的 TLOC 迂回時の優先度制御と密接に連携します。
* **VRF / Segmentation:**
  * Localized Policy は特定の Service VRF（VRF 10, VRF 20 等）単位で個別に定義・適用されます。

---

## 🧩 比較表

### Localized Policy vs Centralized Policy

| 項目 | Localized Policy | Centralized Policy |
| :--- | :--- | :--- |
| **実行場所** | WAN Edge (cEdge / vEdge) | vSmart Controller |
| **対象** | ローカル LAN 側通信, QoS, 局所 ACL, BGP/OSPF | オーバーレイ全域, OMP Route, TLOC, AAR, DIA |
| **構成要素** | Access Lists, Class-Map/Policy-Map, Route-Map | Control Policy, Data Policy, AAR Policy |
| **適用単位** | 特定 Interface / 局所 ルーティングプロセス | 特定 Site-List / VPN-List |
| **暗黙の動作** | 暗黙の拒否 (Implicit Deny) | 暗黙の拒否 (Data Policy / Control Policy) |

### Access Lists (ACL) vs Route Policies (Route-Map)

| 項目 | Access Lists (ACL) | Route Policies (Route-Map) |
| :--- | :--- | :--- |
| **制御対象** | データパケット (Data Plane Traffic) | ルーティング情報 (Control Plane Routes) |
| **評価要素** | 5-Tuple (Src/Dst IP, Port, Protocol), DSCP | IP Prefix, BGP Community, AS-Path, Tag |
| **主な作用** | Permit / Deny, QoS Queueing, Policing, Remarking | Filter (Permit/Deny), Set Metric/Local-Pref/Tag |
| **適用場所** | インターフェイス (in / out) | ルーティングプロセス (BGP/OSPF/OMP) |

---

## 💡 ベストプラクティス

1. **Route-Map には必ず明示的な Permit パスを配置する:**
   * 特定ルートのみを Match して属性変更する場合、最後に `route-map <NAME> permit 99` を配置して、他のルートがドロップされるのを防ぎます。
2. **QoS マーキングは LAN 入口（Ingress）で実施する:**
   * サービス VPN インターフェイスに入った直後に Class-Map / Policy-Map で DSCP マーキングを行い、WAN トンネル送出時にスムーズに QoS キューイングへ引き継ぎます。
3. **vManage Feature Template / Policy の統合管理:**
   * ローカル設定の拡散を防ぐため、可能な限り標準的な Localized Policy コンポーネント（QoS 8 キューモデル等）を共通テンプレート化して運用します。

---

## 📝 ラボ学習・設定サンプル例

### サンプル 1: サービス VPN 側からの Voice パケットの QoS マーキングと Policing
* **問題:** cEdge1 の Service VPN 10 入口（Gi3.10）において、DSCP EF (46) パケットの帯域を最大 10Mbps に制限（超えたパケットは Drop）し、残りを優先キューに投入せよ。
* **要件:**
  * Class-Map 名: `VOICE_CLASS`
  * Policy-Map 名: `INGRESS_QOS`
  * 帯域制限: 10Mbps (Burst 125000 bytes)
* **設定例:**

```bash
class-map match-any VOICE_CLASS
 match dscp ef

policy-map INGRESS_QOS
 class VOICE_CLASS
  police 10000000 125000 conform-action transmit exceed-action drop

interface GigabitEthernet3.10
 service-policy input INGRESS_QOS
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet3.10` を実行し、`VOICE_CLASS` の `conformed` および `exceeded` カウンタが増加することを確認。

---

### サンプル 2: LAN 側 BGP ルータからの受信用 Route-Map (Local-Preference 変更)
* **問題:** 拠点 LAN 側の BGP ルータ (AS 65200) から学習するルートのうち、`10.50.0.0/16` の Local Preference を 200 に変更して OMP へ流し込め。
* **要件:**
  * Prefix-List 名: `PREF_10_50`
  * Route-Map 名: `SET_BGP_IN`
* **設定例:**

```bash
ip prefix-list PREF_10_50 seq 5 permit 10.50.0.0/16 le 24

route-map SET_BGP_IN permit 10
 match ip address prefix-list PREF_10_50
 set local-preference 200
route-map SET_BGP_IN permit 20

router bgp 65100 vrf 10
 neighbor 192.168.10.254 route-map SET_BGP_IN in
```

* **検証方法:**
  * `show ip bgp vrf 10 10.50.1.0` を実行し、Local Preference が 200 にセットされていることを確認。

---

### サンプル 3: OMP から OSPF への再配送時の Tag 付与とループ防止
* **問題:** cEdge 上で OMP 経路を LAN 側の OSPF プロセス 1 (VRF 10) へ再配送する際、Tag `1088` を付与せよ。また OSPF から OMP への再配送時には Tag `1088` を持つ経路をブロックせよ。
* **要件:**
  * Route-Map (OMP->OSPF): `OMP_TO_OSPF`
  * Route-Map (OSPF->OMP): `OSPF_TO_OMP`
* **設定例:**

```bash
! --- OMP ➔ OSPF ---
route-map OMP_TO_OSPF permit 10
 set tag 1088

router ospf 1 vrf 10
 redistribute omp subnets route-map OMP_TO_OSPF

! --- OSPF ➔ OMP ---
route-map OSPF_TO_OMP deny 10
 match tag 1088
route-map OSPF_TO_OMP permit 20

sdwan
 omp
  address-family ipv4 vrf 10
   advertise ospf external route-map OSPF_TO_OMP
  !
 !
```

* **検証方法:**
  * LAN 側 OSPF ルータで `show ip ospf database external` を確認し、Tag 1088 が付与されていることを確認。

---

### サンプル 4: 特定の LAN 側サブネットの OMP 広告ブロック (Prefix-List)
* **問題:** cEdge の LAN 側 Connected 経路のうち、`192.168.99.0/24` のみを OMP に広告させず、その他の Connected 経路はすべて OMP へ広告せよ。
* **要件:**
  * Prefix-List 名: `BLOCK_MGMT`
  * Route-Map 名: `FILTER_CONN_OMP`
* **設定例:**

```bash
ip prefix-list BLOCK_MGMT seq 5 permit 192.168.99.0/24

route-map FILTER_CONN_OMP deny 10
 match ip address prefix-list BLOCK_MGMT
route-map FILTER_CONN_OMP permit 20

sdwan
 omp
  address-family ipv4 vrf 10
   advertise connected route-map FILTER_CONN_OMP
  !
 !
```

* **検証方法:**
  * `show sdwan omp advertised-routes vrf 10` を実行し、`192.168.99.0/24` がリストに含まれていないことを確認。

---

### サンプル 5: IPv4 Access List による特定サブネット間の通信ドロップ
* **問題:** cEdge の Service VPN 10 インターフェイス (Gi3.10) において、`192.168.10.0/24` から `192.168.30.0/24` への通信をドロップし、それ以外の通信はすべて許可せよ。
* **要件:**
  * ACL 名: `DENY_SUB_ACL`
* **設定例:**

```bash
ip access-list extended DENY_SUB_ACL
 10 deny ip 192.168.10.0 0.0.0.255 192.168.30.0 0.0.0.255
 20 permit ip any any

interface GigabitEthernet3.10
 ip access-group DENY_SUB_ACL in
```

* **検証方法:**
  * `192.168.10.100` から `192.168.30.100` へ Ping を送信し、ドロップされること、および `show ip access-lists DENY_SUB_ACL` の matches カウンタが増加することを確認。

---

### サンプル 6: BGP AS-Path Prepend による特定バックボーン経路の送信優先度低下
* **問題:** 拠点 cEdge から LAN 側 BGP ネイバー (192.168.10.254) へ経路をアドバタイズする際、自身の AS 番号 (65100) を 2 回追加 (Prepend) して送出せよ。
* **要件:**
  * Route-Map 名: `PREPEND_AS_OUT`
* **設定例:**

```bash
route-map PREPEND_AS_OUT permit 10
 set as-path prepend 65100 65100

router bgp 65100 vrf 10
 neighbor 192.168.10.254 route-map PREPEND_AS_OUT out
```

* **検証方法:**
  * 対向 BGP ルータで `show ip bgp` を実行し、AS-Path に `65100 65100 65100` と表示されることを確認。

---

### サンプル 7: OMP 経路を OSPF へ再配送する際の Metric-Type 1 変更
* **問題:** OMP 経路を LAN 側の OSPF プロセス 1 へ再配送する際、OSPF メトリックタイプを E2 (デフォルト) から E1 (Type-1 External) に変更せよ。
* **要件:**
  * Route-Map 名: `SET_E1_METRIC`
* **設定例:**

```bash
route-map SET_E1_METRIC permit 10
 set metric-type type-1
 set metric 50

router ospf 1 vrf 10
 redistribute omp subnets route-map SET_E1_METRIC
```

* **検証方法:**
  * LAN 側 OSPF ルータで `show ip route ospf` を実行し、該当ルートが `O E1` と表示され、メトリックが 50 ＋ パスメトリックになっていることを確認。

---

### サンプル 8: BGP Community 付与による LAN 側アクセス制御
* **問題:** OMP から受信した特定サブネット `10.200.1.0/24` に対し、LAN 側 BGP ルータへアドバタイズする際に BGP Community `65100:999` を付与せよ。
* **要件:**
  * Prefix-List 名: `MATCH_200_1`
  * Route-Map 名: `ADD_COMMUNITY`
* **設定例:**

```bash
ip prefix-list MATCH_200_1 seq 5 permit 10.200.1.0/24

route-map ADD_COMMUNITY permit 10
 match ip address prefix-list MATCH_200_1
 set community 65100:999
route-map ADD_COMMUNITY permit 20

router bgp 65100 vrf 10
 neighbor 192.168.10.254 send-community
 neighbor 192.168.10.254 route-map ADD_COMMUNITY out
```

* **検証方法:**
  * 対向 BGP ルータで `show ip bgp 10.200.1.0` を実行し、Community `65100:999` が付与されていることを確認。

---

### サンプル 9: Egress インターフェイスでの QoS Shaping と LLQ 設定
* **問題:** cEdge の物理 WAN インターフェイス (Gi1) の全体帯域を 50Mbps に Shaping し、Voice クラス (LLQ) に 5Mbps を割り当てよ。
* **要件:**
  * Class-Map 名: `VOICE`
  * Policy-Map 名: `WAN_OUT_QOS`
  * Parent Policy 名: `SHAPE_50M`
* **設定例:**

```bash
class-map match-any VOICE
 match dscp ef

policy-map WAN_OUT_QOS
 class VOICE
  priority level 1
  police 5000000 conform-action transmit exceed-action drop
 class class-default
  fair-queue

policy-map SHAPE_50M
 class class-default
  shape average 50000000
  service-policy WAN_OUT_QOS

interface GigabitEthernet1
 service-policy output SHAPE_50M
```

* **検証方法:**
  * `show policy-map interface GigabitEthernet1` を実行し、Parent Policy の Shaping 統計と Child Policy の LLQ 統計を確認。

---

### サンプル 10: Localized Policy の設定失敗からのトラブルシューティング
* **問題:** cEdge 上で BGP ルートフィルタ用の Route-Map を適用したが、すべての BGP ルートが消失した。コンフィグを診断して正常化せよ。
* **初期（障害）設定:**

```bash
ip prefix-list DENY_NET seq 5 permit 10.99.0.0/16

route-map BGP_IN_FILTER permit 10
 match ip address prefix-list DENY_NET
! (Seq 20 の permit が無いため、他の全ルートが Implicit Deny される)

router bgp 65100 vrf 10
 neighbor 192.168.10.254 route-map BGP_IN_FILTER in
```

* **修正コンフィグ:**

```bash
route-map BGP_IN_FILTER deny 10
 match ip address prefix-list DENY_NET

route-map BGP_IN_FILTER permit 20
! (特定のプレフィックスのみ拒否し、残りを全許可する)

router bgp 65100 vrf 10
 neighbor 192.168.10.254 route-map BGP_IN_FILTER in
```

* **検証方法:**
  * `clear ip bgp vrf 10 192.168.10.254 soft in` を実行後、`show ip bgp vrf 10` で `10.99.0.0/16` 以外のすべてのルートが復旧したことを確認。

---

## ❓ 想定試験問題

### 問題 1 (コンフィグ読解・トラブルシューティング)
**【設問】**
以下の cEdge1 のコンフィグを適用したところ、LAN 側の BGP ルータ（192.168.10.254）から学習した経路が OMP テーブルに反映されなくなった。原因と正しい修正コマンドを答えよ。

```bash
ip prefix-list ALLOW_LAN seq 5 permit 172.16.0.0/12 le 24

route-map BGP_TO_OMP permit 10
 match ip address prefix-list ALLOW_LAN

router bgp 65100 vrf 10
 neighbor 192.168.10.254 remote-as 65200
 neighbor 192.168.10.254 route-map BGP_TO_OMP in

sdwan
 omp
  address-family ipv4 vrf 10
   advertise bgp
  !
 !
```

**【解答・解説】**
* **原因:**
  `sdwan omp` の `advertise bgp` コマンドに route-map がバインドされておらず、BGP プロセス側の `neighbor route-map in` で Match しなかったその他の BGP 経路が BGP テーブル自体からドロップされている。また、OMP への直接広告フィルタリングを行う場合は `sdwan omp address-family ipv4 vrf 10 advertise bgp route-map <NAME>` を使用するのが正しい。
* **修正コマンド:**

```bash
sdwan
 omp
  address-family ipv4 vrf 10
   advertise bgp route-map BGP_TO_OMP
  !
 !
```

---

### 問題 2 (Design / 評価)
**【設問】**
Cisco SD-WAN において、Centralized Policy（vSmart 実行）と Localized Policy（WAN Edge 実行）の機能分担として正しい説明を 2 つ選べ。

1. Application-Aware Routing (AAR) は Localized Policy で定義・実行される。
2. サイトローカルの BGP / OSPF プロトコルに対する Route-Map 処理は Localized Policy で実行される。
3. QoS Class-Map および Policy-Map による LLQ / Policing は Localized Policy として WAN Edge 上で実行される。
4. Hub-and-Spoke トポロジーの形成を行う Control Policy は Localized Policy である。

**【解答・解説】**
* **正解:** 2, 3
* **解説:**
  * 1 は誤り。AAR は Centralized Policy で定義され、vSmart から Edge へ配信される。
  * 4 は誤り。Hub-and-Spoke 構造の制御を行う Control Policy は Centralized Policy であり、vSmart 上で評価される。

---

### 問題 3 (実装・QoS)
**【设問】**
cEdge の Service VPN 10 インターフェイス (Gi3.10) において、DSCP AF31 のトラフィックに対し、最大 20Mbps (Burst 250000 bytes) の Policing を適用し、超過分を Drop する設定コマンドを作成せよ。

**【解答・解説】**
* **設定コマンド:**

```bash
class-map match-any CLASS_AF31
 match dscp af31

policy-map POLICE_20M
 class CLASS_AF31
  police 20000000 250000 conform-action transmit exceed-action drop

interface GigabitEthernet3.10
 service-policy input POLICE_20M
```

---

### 問題 4 (トラブルシューティング / OSPF ループ)
**【設問】**
cEdge 上で OMP 経路を LAN 側 OSPF へ再配送し、同時に OSPF 経路を OMP へ再配送している環境において、相互再配送ループが発生した。これを防ぐために Localized Route Policy（Route-Map）を用いて構成すべき標準的なメカニズムを説明せよ。

**【解答・解説】**
* **説明:**
  OMP 経路を OSPF へ再配送する際の Route-Map で、固有の Route Tag（例: Tag 1088 または 666）を `set tag <VALUE>` で付与する。そして、OSPF 経路を OMP へ再配送する際の Route-Map で、その Tag を持つ経路を `match tag <VALUE>` で一致させ、`deny` ステートメントでドロップさせることで、再流入によるルーティングループを防止する。

---

### 問題 5 (コンフィグ読解 / ACL)
**【設問】**
以下の ACL を cEdge の Gi3.10 (in) に適用したところ、全ての Web（HTTP/HTTPS）通信を含む一般トラフィックが停止した。理由と修正方法を述べよ。

```bash
ip access-list extended BLOCK_SSH
 10 deny tcp any any eq 22
```

**【解答・解説】**
* **理由:**
  Cisco IOS-XE の IP Access List の末尾には暗黙の拒否（`deny ip any any`）が存在するため、Seq 10 の SSH ドロップルール以外の全 IP トラフィックが末尾でドロップされたため。
* **修正方法:**
  ACL の末尾に明示的な全許可ルール `20 permit ip any any` を追加する。

---

## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Systems and Interfaces Configuration Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/ios-xe-17/systems-interfaces-book-ios-xe-17.html)
* [Cisco Catalyst SD-WAN Policies Configuration Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/ios-xe-17/policies-book-ios-xe-17.html)
* [Cisco Live: BRKCRS-2110 - SD-WAN Policy Deep Dive](https://www.ciscolive.com/)
* [Cisco Technical Notes: Troubleshoot SD-WAN Localized Policies and QoS](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214878-troubleshoot-sd-wan-localized-policies.html)
* [Cisco Validated Design (CVD): SD-WAN End-to-End QoS Design Guide](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/sdwan-qos-design-guide.html)

---

## 📝 補足（Notes）

* **vManage でのテンプレート編集時の注意:**
  * Localized Policy を vManage 上で改定（例: Access List ルールの追加）して Push する際、該当する Device Template を使用しているすべての WAN Edge に即座に展開されるため、本番環境ではメンテナンスウィンドウ中に実施すること。
* **IOS-XE MQC と Viptela OS CLI の用語対応:**
  * cEdge (IOS-XE) では `class-map` / `policy-map` / `ip access-list` / `route-map` という伝統的な MQC 構文が用いられるが、vEdge (Viptela OS) では `policy access-list` / `policy route-policy` という独自の表現が用いられる。CCIE EI ラボ試験では cEdge (IOS-XE) が主流であるため、MQC 構文の習熟が不可欠である。


## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKTRS-3793: Advanced SD-WAN Routing Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-3793)
    *   再配送やポリシーによるルーティング不整合の深いトラブルシューティング手法が解説されています。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081)
    *   ポリシーがデバイスに正しく push されない際の原因切り分けに役立ちます。

### Configuration ガイド
*   [**Cisco SD-WAN Localized Policy Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/vedge-20-x/policies-book.html)
    *   ACL、Route Policy の全パラメータが網羅されています。
*   [**Configuring QoS for SD-WAN**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/qos/vedge-20-x/qos-book.html)。

### テクニカルドキュメント・設定例
*   [**SD-WAN: Route Policy Examples and Operations**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)。
*   [**Understand SD-WAN Access Control Lists (ACLs)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/215321-sd-wan-certificate-management-and-troubl.html)。

---
## 📝 補足
- この学習メモは、Localized Policy が「デバイスとネットワークの境界」を守り、整えるための重要なツールであることを示しています。CCIE ラボ試験では、**Centralized Policy との競合**を避けつつ、再配送時の **Tag 操作** や **Metric 調整** をミスなく完遂することが合格への道筋となります。


