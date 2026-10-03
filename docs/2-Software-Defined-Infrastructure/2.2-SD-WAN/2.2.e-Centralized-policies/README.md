---
layout: default
title: 2.2.e-Centralized-policies
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 5
---

# 2.2.e Centralized policies

---

## 📘 概要

Cisco SD-WAN（Catalyst SD-WAN）における**Centralized Policies（集中ポリシー）**は、オーバーレイネットワーク全体のルーティング、制御プレーン（OMP）、データプレーンのパケット転送、およびアプリケーション主導のパス選定（AAR: Application-Aware Routing）を **vSmart コントローラ上で一元的に定義・評価・適用** するコア機能である。

集中ポリシーは vSmart のメモリー上で評価・処理され、その結果（改変された OMP ルート、TLOC、サービスルート、またはローカルに適用すべき Data / AAR Policy）のみが各 WAN Edge（cEdge / vEdge）へ動的に配信される。これにより、数百から数千拠点に及ぶ分散環境において、個々の WAN Edge 上で複雑な ACL や PBR、BGP 属性変更を個別に設定することなく、エンタープライズ全体のトラフィックエンジニアリングとセキュリティポリシーを一元制御できる。

集中ポリシーは大きく以下の 3 つのカテゴリに分類される：

1. **Control Policies (2.2.e (iii)):** 
   vSmart コントローラ上の OMP 制御プレーン情報を直接操作する。OMP Routes (vRoutes) や TLOC Routes のアドバタイズ・受信をフィルタリング・変更し、Hub-and-Spoke、Regional Mesh、Arbitrary Topology の形成や、特定回線（Color）への誘導、サービスチェイニング（Firewall 挿入等）を実現する。
2. **Data Policies (2.2.e (i)):** 
   WAN Edge を通過するデータプレーンパケット（データトラフィック）の制御を行う。vSmart 上で定義され、OMP 経由で対象の WAN Edge へ配信された後、WAN Edge の CEF / Data Plane レベルで実行される。Direct Internet Access (DIA)、Service Chaining (FW/IPS 迂回)、Custom Traffic Engineering (特定アプリの TLOC 固定)、QoS Remarking、パケットドロップ（Security Filter）などを実現する。
3. **Application-Aware Routing (AAR) Policies (2.2.e (ii)):** 
   リアルタイムの回線品質測定（BFD が計測する Latency、Jitter、Packet Loss）に基づいて、アプリケーション単位で最適パスを動的に選択する。SLA Class（許容遅延・パケット損失率等）を定義し、SLA 基準を満たす TLOC/Color へリアルタイムにパケットを自動迂回させる。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主な用途** | vSmart によるトポロジー制御（Hub-and-Spoke化）、アプリ主導パス選択（AAR）、Direct Internet Access (DIA)、Service Chaining、データプレーンフィルタリング |
| **動作場所** | **Control Policy:** vSmart 上で OMP テーブルを評価・計算<br>**Data / AAR Policy:** vSmart で定義 ➔ vSmart から OMP 経由で WAN Edge へ配信 ➔ WAN Edge の Data Plane でパケット単位で実行 |
| **主なメリット** | 全 Edge の設定を直接変更せず vSmart のポリシー変更のみで全網のルーティング・トラフィックフローを即時一元変更可能 |
| **主なデメリット** | vSmart 上でのポリシー構文エラーや Match/Action の設計ミスがオーバーレイネットワーク全域の通信障害を引き起こすリスク |
| **構成要素** | **Policy Definition:** Match 条件と Action の組み合わせ<br>**Policy Application:** どの Site-List / VPN-List に対し Inbound/Outbound 方向で適用するかを定義 |
| **制限事項** | Centralized Data Policy はインバウンド（LAN 側から WAN へ入る方向）またはアウトバウンド（WAN 側から LAN へ出る方向）で評価。AAR Policy は LAN から WAN 方向（Inbound from Service VPN）でのみサポート |
| **設計上の注意点** | Centralized Policy 内の暗黙の拒否（Implicit Deny）動作。Control Policy で Match しない OMP ルートは拒否（Drop/Filter）されるため、最後に `default-action accept` が必須 |

---

## 🏗 動作原理

集中ポリシーは、**Policy Definition（定義）** と **Policy Application（適用）** の 2 段階で動作する。

### 1. Control Policy の動作原理 (vSmart 処理)

```text
[Site-20 WAN Edge] --(OMP Route / TLOC)---> [ vSmart Controller ]
                                                    │
                                         [ Inbound Control Policy ]
                                                    ▼
                                          [ OMP RIB / Topology ]
                                                    ▼
                                         [ Outbound Control Policy ]
                                                    │
[Site-10 WAN Edge] <--(Filtered OMP)───────────────┘
```

* **Inbound Control Policy:** WAN Edge から vSmart へ送信された OMP Update（Routes / TLOCs）を vSmart が受信した直後に評価。
* **Outbound Control Policy:** vSmart が計算した OMP ベストパスを特定の WAN Edge へ送信（アドバタイズ）する直前に評価。

### 2. Centralized Data Policy & AAR Policy の動作原理 (WAN Edge 処理)

```text
1. vSmart で Data / AAR Policy を定義・アクティベート
   ↓
2. vSmart が OMP Update にポリシー命令をバインドして対象 WAN Edge へ送信
   ↓
3. WAN Edge がローカルメモリ（CEF / Forwarding Table）にポリシーをロード
   ↓
4. LAN 側（Service VPN）からパケットが入った瞬間、パケットヘッダー (5-tuple / DPI) をポリシーに照合
   ↓
5. AAR の場合: BFD パケットが計測した各 TLOC の SLA（Latency/Jitter/Loss）と SLA Class を比較
   ↓
6. ポリシー Action（Preferred Color への送信、DIA へ転送、Drop、Remark）をデータパケットへ直接適用
```

---

## ⚙ 動作シーケンス

### AAR (Application-Aware Routing) パケット処理シーケンス

```text
[ LAN Client ] ──(1. App Traffic)──> [ WAN Edge (Service VPN) ]
                                                │
                                    (2. DPI / Match App List)
                                                │
                                    (3. Check SLA Class Rules)
                                                │
                          ┌─────────────────────┴─────────────────────┐
                          ▼                                           ▼
            [ SLA Criteria SATISFIED ]                 [ SLA Criteria VIOLATED ]
                          │                                           │
            (4a. Forward via Preferred Color)          (4b. Fallback to Alt Color)
                          │                                           │
                          ▼                                           ▼
                 [ IPsec Tunnel A ]                          [ IPsec Tunnel B ]
```

1. **BFD Continuous Monitoring:** WAN Edge 上の全 IPsec Tunnel（TLOC 間）で BFD パケットが常時往復し、遅延（Latency）、ジッター（Jitter）、パケット損失率（Packet Loss）をミリ秒単位で継続測定。
2. **Packet Arrival & Class Identification:** Service VPN 側の LAN インターフェイスにパケットが到着すると、NBAR / DPI（Deep Packet Inspection）によりアプリケーション（Office365, Zoom, Voice等）を特定。
3. **AAR Match Evaluation:** AAR Policy の Match 条件に合致した場合、バインドされている `sla-class` の規定値（例: Latency < 150ms, Loss < 1%）と現在 BFD が測定している各 TLOC のリアルタイム指標を照合。
4. **Path Selection:**
   * **SLA 適合時:** `preferred-color` で指定された第一優先 Color（例: `biz-internet`）へトラフィックを転送。
   * **SLA 違反時:** 定義された別の適正 TLOC（例: `mpls`）へ即座に動的迂回。適合 TLOC が存在しない場合は、`strict` オプションが非指定であれば最善の TLOC で転送を継続。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント

1. **Hub-and-Spoke 構成（Control Policy）:**
   * デフォルトの Full-Mesh 構造を、vSmart 上の Control Policy で Spoke 間の TLOC / OMP ルート交換を遮断し、Hub の TLOC へのみ Next-Hop を書き換えることで Hub-and-Spoke 化する実装 [125, Centralized Control Policy Example: Hub-and-Spoke]。
2. **AAR (Application-Aware Routing) と SLA Class の不整合:**
   * `sla-class` で定義した名前と AAR Policy 内で参照する `sla-class` 名の一致。`preferred-color` や `strict` オプションの動作ルールの完全把握。
3. **Direct Internet Access (DIA) の要件:**
   * Data Policy で Web トラフィック（HTTP/HTTPS）を Match し、`action accept set vpn 0`＋ `nat use-via-tls` / `nat` オプションを適用してローカルブレイクアウトさせる手法 [127, Centralized Data Policy Example: Direct Internet Access]。
4. **Service Chaining (Service Insertion):**
   * Hub 拠点に配置された Firewall / IPS へトラフィックを引き込むため、Control Policy で `service FW` ルートを配布し、Data Policy で `action accept set service FW` を定義する複合構成。
5. **Implicit Deny の回避:**
   * Control Policy の末尾に `default-action accept` を入れ忘れて全 OMP ルートが消去されるトラブルが最も頻出。

### show コマンドから状態を判断するポイント

```bash
# vSmart 上でアクティブなポリシーの確認
vSmart# show running-config policy

# WAN Edge 上で vSmart から配信・適用されている Centralized Policy の確認
cEdge# show sdwan policy engine status
cEdge# show sdwan policy from-vsmart

# AAR が参照する BFD のリアルタイム SLA 測定値の確認
cEdge# show sdwan bfd sessions

# AAR ポリシーの実際の転送マッチングの確認
cEdge# show sdwan app-route statistics
```

---

## 🛠 設定方法

### 1. vSmart CLI における Centralized Control Policy（Hub-and-Spoke 化）

```text
policy
 site-list SPOKES
  site-id 10 20
 !
 site-list HUB
  site-id 100
 !
 tloc-list HUB-TLOC
  tloc 100.100.100.100 color biz-internet encap ipsec
 !
 control-policy HUB-AND-SPOKE-POLICY
  sequence 10
   match route
    site-list SPOKES
   !
   action accept
    set tloc-list HUB-TLOC
   !
  !
  default-action accept
 !
!
apply-policy
 site-list SPOKES
  control-policy HUB-AND-SPOKE-POLICY out
 !
!
```

### 2. vSmart CLI における Application-Aware Routing (AAR) Policy

```text
policy
 sla-class VOICE-SLA
  loss 1
  latency 150
  jitter 30
 !
 app-list VOICE-APPS
  app ms-teams cisco-webex
 !
 site-list BRANCHES
  site-id 10-30
 !
 app-route-policy AAR-VOICE-POLICY
  sequence 10
   match
    app-list VOICE-APPS
   !
   action
    sla-class VOICE-SLA preferred-color biz-internet mpls
   !
  !
  default-action
   sla-class VOICE-SLA preferred-color mpls
 !
!
apply-policy
 site-list BRANCHES
  app-route-policy AAR-VOICE-POLICY
 !
!
```

### 3. vSmart CLI における Centralized Data Policy (Direct Internet Access - DIA)

```text
policy
 lists
  site-list BRANCHES
   site-id 10-30
  !
  vpn-list SERVICE-VPNS
   vpn 10
  !
  data-prefix-list WEB-TRAFFIC
   ip-prefix 0.0.0.0/0 port 80 443
  !
 data-policy DIA-POLICY
  vpn-list SERVICE-VPNS
   sequence 10
    match
     destination-data-prefix-list WEB-TRAFFIC
    !
    action accept
     nat use-via-tls
    !
   !
   default-action accept
  !
 !
!
apply-policy
 site-list BRANCHES
  data-policy DIA-POLICY all
 !
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド (vSmart / cEdge) |
| :--- | :--- |
| **vSmart で適用中のポリシー確認** | `show running-config policy` |
| **vSmart のポリシー割り当て状態確認** | `show policy active` |
| **cEdge 上でのポリシー適用ステータス確認** | `show sdwan policy engine status` |
| **cEdge 上で vSmart から受信した Data Policy 確認** | `show sdwan policy from-vsmart` |
| **AAR 用 BFD セッション測定値 (Loss/Latency) 確認** | `show sdwan bfd sessions` |
| **AAR アプリ経路統計確認** | `show sdwan app-route statistics` |
| **AAR の SLA 状態とクラス確認** | `show sdwan app-route sla-class` |
| **Data Policy カウンター・ヒット数確認** | `show sdwan policy data-policy-filter` |
| **ポリシー適用デバッグ (vSmart)** | `debug sdwan vsmart policy` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **Control Policy 適用後、Spoke 間の通信が全断した** | Control Policy 内に `default-action accept` がなく、全 OMP ルートが Implicit Deny された | `show sdwan omp routes` | Policy の末尾に `default-action accept` を追加し vSmart でアクティベート |
| **AAR Policy を設定したのに SLA 違反時に回線が切替わらない** | SLA 違反時でも他回線に転送を許可するデフォルト動作に対し、`strict` モードが設定されており代替回線が存在しない | `show sdwan app-route sla-class` | `strict` オプションを外し、代替 TLOC/Color の定義を見直す |
| **DIA (Direct Internet Access) が機能せずパケットが破棄される** | cEdge の VPN 0 (Transport) インターフェイス上で `nat`（IP NAT）が有効化されていない | `show running-config interface` | cEdge の Transport インターフェイス（VPN 0）配下に `nat` コマンドを追加 |
| **vSmart でポリシーを Activate しても WAN Edge に反映されない** | WAN Edge 側の Site-ID が `site-list` の範囲外であるか、vSmart - WAN Edge 間の Control Connection が落ちている | `show sdwan control connections` | Site-ID の割り当て範囲を確認し、`apply-policy` の `site-list` を修正 |
| **特定アプリが AAR マッチせず意図しない回線を通る** | NBAR / DPI エンジンがトラフィックの最初数パケットでアプリを分類できていない | `show sdwan app-route statistics` | `data-prefix-list`（IP/Port）による手動 Match を併用するか NBAR 記述を修復 |

---

## ⚠ 制限事項

1. **AAR Policy の方向制限:**
   * Application-Aware Routing (AAR) Policy は、**LAN 側（Service VPN）から WAN 側（Transport VPN 0）へ入るインバウンド方向**でのみ評価可能。WAN 側から入るトラフィックには適用できない。
2. **Control Policy の暗黙の拒否 (Implicit Deny):**
   * Control Policy で明示的に Sequence で Match されない OMP ルートおよび TLOC ルートは、ポリシーの最後に暗黙の drop/filter が適用される。`default-action accept` を入れない限り、Match しない全ルートが消去される。
3. **vSmart の処理負荷:**
   * 非常に複雑な Regular Expression（正規表現）や何千行もの Sequence を持つ Control Policy は vSmart の CPU 負荷を高騰させるため、`site-list` や `prefix-list` の集約が必要。

---

## 🔄 他技術との関連

* **OMP (Overlay Management Protocol):** Control Policy は OMP Update パケットの属性（Preference, TLOC, Originator等）を直接書き換える。
* **BFD (Bidirectional Forwarding Detection):** AAR Policy は BFD パケットが常時測定する Latency/Jitter/Loss メトリックをリアルタイム入力として評価する。
* **NBAR2 / DPI (Deep Packet Inspection):** AAR や Centralized Data Policy で Application-List（Office365, Skype等）を識別するためのレイヤ 7 解析エンジン。
* **NAT (Network Address Translation):** DIA (Direct Internet Access) データポリシーを実行する際、VPN 0 インターフェイス上で IP NAT が有効になっていることが必須前提条件。

---

## 🧩 比較表

### Centralized Policies 3 種の機能比較

| 項目 | Control Policy | Centralized Data Policy | Application-Aware Routing (AAR) Policy |
| :--- | :--- | :--- | :--- |
| **制御対象** | OMP 制御プレーン (Routes, TLOCs) | データプレーン パケット (5-tuple / DPI) | アプリケーション データパケット |
| **評価・実行場所** | **vSmart コントローラ上** で評価 | vSmart で定義 ➔ **WAN Edge** 上で実行 | vSmart で定義 ➔ **WAN Edge** 上で実行 |
| **主な目的** | トポロジー制御 (Hub-Spoke等), Service Chaining | DIA, QoS Remarking, Filtering, PBR | SLA に基づく動的パス迂回 |
| **判断基準** | OMP 属性 (Site-ID, Prefix, TLOC) | IP/Port, App-List, DSCP | BFD が測定する Latency / Loss / Jitter |
| **デフォルト動作** | 暗黙の拒否 (要 `default-action accept`) | 定義による (通常 pass-through) | 定義による (SLA 未達時は Best Color) |

---

## 💡 ベストプラクティス

1. **Control Policy には必ず `default-action accept` を配置する:**
   * OMP ルート全消失による全網ダウン事故を防ぐため、Control Policy の最後には必ず明示的な `default-action accept` を記述する。
2. **AAR Policy の SLA クラスに余裕を持たせる:**
   * BFD 測定の軽微なゆらぎによる頻繁な回線切り替え（Route Flapping）を防ぐため、SLA Class の閾値（例: Latency 150ms）は実測値に対して適切なバッファを設定する。
3. **DIA 適用時は Transport 側の Firewall / NAT 設定をセットで確認する:**
   * Data Policy で DIA を有効化する際、cEdge の VPN 0 ポートに `nat` コマンドが設定されていないとパケットが外に抜けずブラックホール化するため、テンプレート側で確実に付与する。

---

## 📝 ラボ学習・設定サンプル例

### 実践ラボ 1: OMP Control Policy による Hub-and-Spoke トポロジーの構築

* **問題:** 全拠点が Full-Mesh で OMP 接続されている環境において、Spoke 拠点（Site 10, 20）同士の直接通信を禁止し、すべての流量が Hub 拠点（Site 100, TLOC: 100.100.100.100）を経由するように vSmart 上で Centralized Control Policy を作成・適用せよ。
* **要件:**
  * Spoke から送信される OMP ルートの TLOC を Hub の TLOC へ書き換えること。
  * 他のサイトおよび Hub からの制御ルートは正常に許可すること。

```text
# [vSmart]
config
 policy
  site-list SPOKE-SITES
   site-id 10 20
  !
  tloc-list HUB-TLOC-LIST
   tloc 100.100.100.100 color biz-internet encap ipsec
  !
  control-policy HUB-AND-SPOKE
   sequence 10
    match route
     site-list SPOKE-SITES
    !
    action accept
     set tloc-list HUB-TLOC-LIST
    !
   !
   default-action accept
  !
 !
 apply-policy
  site-list SPOKE-SITES
   control-policy HUB-AND-SPOKE out
  !
 !
commit
```

* **検証方法:**
  Spoke ルータ（cEdge-10）上で `show sdwan omp routes` を実行し、Spoke-20 宛ての OMP 経路の TLOC（Next-Hop）が Hub ルータの TLOC アドレス（`100.100.100.100`）へ書き換えられていることを確認する。

---

### 実践ラボ 2: Application-Aware Routing (AAR) による Voice トラフィック最適化

* **問題:** 支社拠点（Site 10-30）から発信される Cisco Webex および MS Teams のトラフィックに対し、遅延 100ms 以下、パケット損失 1% 以下の品質基準（SLA）を強制する AAR ポリシーを構成せよ。
* **要件:**
  * SLA 適合時は `biz-internet` カラーを優先使用すること。
  * SLA 違反時は `mpls` カラーへ迂回させること。

```text
# [vSmart]
config
 policy
  sla-class VOICE-SLA-CLASS
   loss 1
   latency 100
  !
  app-list VOICE-APPLICATIONS
   app ms-teams cisco-webex
  !
  site-list BRANCH-SITES
   site-id 10-30
  !
  app-route-policy AAR-VOICE-POLICY
   sequence 10
    match
     app-list VOICE-APPLICATIONS
    !
    action
     sla-class VOICE-SLA-CLASS preferred-color biz-internet mpls
    !
   !
   default-action
    sla-class VOICE-SLA-CLASS preferred-color mpls
  !
 !
 apply-policy
  site-list BRANCH-SITES
   app-route-policy AAR-VOICE-POLICY
  !
 !
commit
```

* **検証方法:**
  cEdge 上で `show sdwan app-route sla-class` および `show sdwan app-route statistics` を実行し、Webex/Teams トラフィックが `VOICE-SLA-CLASS` にマッチし、SLA 状態に応じて `biz-internet` または `mpls` へルーティングされていることを確認する。

---

### 実践ラボ 3: Centralized Data Policy による Direct Internet Access (DIA)

* **問題:** 支社拠点（Site 10-30）の Service VPN 10 に所属する端末からの Web 閲覧トラフィック（HTTP/HTTPS）を、HQ を経由させずローカルの WAN 回線（VPN 0）から直接インターネットへ抜出（DIA）させる Centralized Data Policy を作成せよ。
* **要件:**
  * 対象トラフィックは 宛先 Port 80, 443 とする。
  * cEdge の Transport ポートで NAT を適用すること。

```text
# [vSmart]
config
 policy
  lists
   site-list BRANCH-SITES
    site-id 10-30
   !
   vpn-list SERVICE-VPN-10
    vpn 10
   !
   data-prefix-list HTTP-HTTPS-PORTS
    ip-prefix 0.0.0.0/0 port 80 443
   !
  !
  data-policy DIA-DATA-POLICY
   vpn-list SERVICE-VPN-10
    sequence 10
     match
      destination-data-prefix-list HTTP-HTTPS-PORTS
     !
     action accept
      nat use-via-tls
     !
    !
    default-action accept
   !
  !
 !
 apply-policy
  site-list BRANCH-SITES
   data-policy DIA-DATA-POLICY all
  !
 !
commit

# [cEdge 側要件設定 (VPN 0)]
interface GigabitEthernet1
 ip nat outside
!
```

* **検証方法:**
  cEdge 上で `show sdwan policy from-vsmart` を実行して Data Policy が受信されていることを確認し、LAN 側クライアントから Web アクセスを発生させ `show ip nat translations` および `show sdwan policy data-policy-filter` でカウンターが増加していることを検証する。

---

### 実践ラボ 4: OMP Control Policy による 特定 Site からのルート広告ブロック

* **問題:** 開発拠点（Site 50）から送信されるプライベートサブネット（`172.20.0.0/16`）の OMP ルートを、他の全拠点へ流出させないよう vSmart の Inbound Control Policy で遮断せよ。

```text
# [vSmart]
config
 policy
  prefix-list DEV-INTERNAL-NET
   ip-prefix 172.20.0.0/16 le 32
  !
  site-list DEV-SITE
   site-id 50
  !
  control-policy BLOCK-DEV-ROUTES
   sequence 10
    match route
     prefix-list DEV-INTERNAL-NET
    !
    action reject
   !
   default-action accept
  !
 !
 apply-policy
  site-list DEV-SITE
   control-policy BLOCK-DEV-ROUTES in
  !
 !
commit
```

* **検証方法:**
  vSmart 上で `show omp routes prefix 172.20.0.0/16` を実行し、Site 50 からのルートが拒否（Reject）され、他拠点の cEdge の OMP テーブルに表示されないことを確認する。

---

### 実践ラボ 5: Preferred Color による特定データトラフィックの WAN 回線固定

* **問題:** 財務データトラフィック（DSCP AF31: `26`）を、SLA の状態に関わらず常に専用の MPLS 回線（Color: `mpls`）へ強制転送する Data Policy を構成せよ。

```text
# [vSmart]
config
 policy
  lists
   site-list ALL-BRANCHES
    site-id 10-40
   !
   vpn-list CORP-VPNS
    vpn 10
   !
  !
  data-policy PREFER-MPLS-DATA
   vpn-list CORP-VPNS
    sequence 10
     match
      dscp 26
     !
     action accept
      set
       tloc-color mpls restrict
      !
     !
    !
    default-action accept
   !
  !
 !
 apply-policy
  site-list ALL-BRANCHES
   data-policy PREFER-MPLS-DATA from-service
  !
 !
commit
```

* **検証方法:**
  cEdge 上で DSCP 26 を付与した Ping / パケットを送信し、`show sdwan policy data-policy-filter` でマッチ数が増加し、パケットが `mpls` TLOC の IPsec トンネルへ流れていることを確認する。

---

### 実践ラボ 6: Service Chaining (HQ Firewall へのデータパケットリダイレクト)

* **問題:** 支社（Site 10-20）からデータセンター（Site 100）宛ての全トラフィックを、HQ に配置された Firewall（Service FW）へ一度リダイレクトしてから目的地へ届ける Data Policy を作成せよ。

```text
# [vSmart]
config
 policy
  lists
   site-list SPOKE-SITES
    site-id 10 20
   !
   vpn-list SERVICE-VPNS
    vpn 10
   !
  !
  data-policy FW-SERVICE-CHAIN
   vpn-list SERVICE-VPNS
    sequence 10
     match
      destination-ip 10.100.0.0/16
     !
     action accept
      set
       service FW vpn 10
      !
     !
    !
    default-action accept
   !
  !
 !
 apply-policy
  site-list SPOKE-SITES
   data-policy FW-SERVICE-CHAIN from-service
  !
 !
commit
```

* **検証方法:**
  Spoke ルータから 10.100.x.x 宛てに通信を発生させ、`show sdwan policy data-policy-filter` で Service FW へのリダイレクトアクションが実行されていることを確認する。

---

### 実践ラボ 7: TLOC Preference によるマルチホーム拠点のアウトバウンド制御

* **問題:** Site 30 の 2 台の WAN Edge（Edge-1, Edge-2）において、Edge-1 の TLOC ルートの Preference を 200、Edge-2 を 100 に設定し、他拠点から Site 30 への着信トラフィックを常に Edge-1 優先に制御する Control Policy を作成せよ。

```text
# [vSmart]
config
 policy
  site-list SITE-30
   site-id 30
  !
  tloc-list EDGE-1-TLOC
   tloc 192.168.30.1 color biz-internet encap ipsec
  !
  control-policy PREFER-EDGE1-POLICY
   sequence 10
    match tloc
     tloc-list EDGE-1-TLOC
    !
    action accept
     set
      preference 200
     !
    !
   !
   default-action accept
  !
 !
 apply-policy
  site-list SITE-30
   control-policy PREFER-EDGE1-POLICY in
  !
 !
commit
```

* **検証方法:**
  他拠点の cEdge で `show sdwan omp tlocs` を実行し、Site 30 の Edge-1 の TLOC Preference が 200 と認識され、ベストパス選定で優先されていることを確認する。

---

### 実践ラボ 8: Dynamic AAR Fallback with Strict Option

* **問題:** 極めて重要な基幹音声トラフィック（DSCP EF: `46`）に対し、指定した `biz-internet` の SLA（Loss < 0.5%）が破綻した場合、他の不安定な代替回線へ迂回させずパケットを破棄（Strict 制御）する AAR ポリシーを構成せよ。

```text
# [vSmart]
config
 policy
  sla-class STRICT-VOICE-SLA
   loss 0.5
   latency 80
  !
  site-list CRITICAL-SITES
   site-id 10 11
  !
  app-route-policy STRICT-AAR-POLICY
   sequence 10
    match
     dscp 46
    !
    action
     sla-class STRICT-VOICE-SLA preferred-color biz-internet strict
    !
   !
   default-action
    sla-class STRICT-VOICE-SLA preferred-color biz-internet
  !
 !
 apply-policy
  site-list CRITICAL-SITES
   app-route-policy STRICT-AAR-POLICY
  !
 !
commit
```

* **検証方法:**
  回線障害・品質劣化を擬似的に発生させ、`biz-internet` が SLA 違反となった際に `strict` 指定により他回線へ迂回せず、パケットがドロップされる挙動を `show sdwan app-route statistics` で確認する。

---

### 実践ラボ 9: QoS Remarking Data Policy (DSCP 書き換え)

* **問題:** 支社（Site 10-30）の Service VPN 10 から送信される 映像会議トラフィック（UDP Port 16384-32767）の DSCP 値を、WAN へ送出する前に `AF41`（`34`）へリマークする Data Policy を作成せよ。

```text
# [vSmart]
config
 policy
  lists
   site-list BRANCHES
    site-id 10-30
   !
   vpn-list SERVICE-VPN-10
    vpn 10
   !
  !
  data-policy REMARK-VIDEO-POLICY
   vpn-list SERVICE-VPN-10
    sequence 10
     match
      protocol 17
      destination-port 16384-32767
     !
     action accept
      set
       dscp 34
      !
     !
    !
    default-action accept
   !
  !
 !
 apply-policy
  site-list BRANCHES
   data-policy REMARK-VIDEO-POLICY from-service
  !
 !
commit
```

* **検証方法:**
  cEdge の LAN ポートでキャプチャまたは `show sdwan policy data-policy-filter` を実行し、WAN へ送り出される IP パケットの DSCP フィールドが `34` (AF41) へ書き換わっていることを検証する。

---

### 実践ラボ 10: Centralized Data Policy による 特定 IP サブネットのドロップ (Security Filter)

* **問題:** ゲスト VPN（VPN 20）から 社内サーバーセグメント（`10.100.0.0/16`）宛ての通信を、WAN Edge のデータプレーン上で直接ドロップする Security Data Policy を定義せよ。

```text
# [vSmart]
config
 policy
  lists
   site-list ALL-SITES
    site-id 10-100
   !
   vpn-list GUEST-VPN
    vpn 20
   !
   prefix-list INTERNAL-SERVERS
    ip-prefix 10.100.0.0/16
   !
  !
  data-policy BLOCK-GUEST-TO-INTERNAL
   vpn-list GUEST-VPN
    sequence 10
     match
      destination-ip 10.100.0.0/16
     !
     action drop
     !
    !
    default-action accept
   !
  !
 !
 apply-policy
  site-list ALL-SITES
   data-policy BLOCK-GUEST-TO-INTERNAL from-service
  !
 !
commit
```

* **検証方法:**
  ゲスト VPN 20 のクライアントから 10.100.1.1 宛てに Ping を送信し、通信がドロップされること、および cEdge 上で `show sdwan policy data-policy-filter` の drop カウンターが増加することを確認する。

---

## ❓ 想定試験問題

### 質問 1 (コンフィグ読解・トラブルシューティング)
以下の vSmart 上の Control Policy コンフィグを適用した直後、全 Spoke 拠点間でルーティングテーブルから互いの OMP ルートが消失し、オーバーレイ通信が全断した。原因と修正手順を述べよ。

```text
policy
 site-list SPOKES
  site-id 10 20 30
 !
 prefix-list GUEST-NET
  ip-prefix 192.168.200.0/24
 !
 control-policy FILTER-GUEST
  sequence 10
   match route
    prefix-list GUEST-NET
   !
   action reject
  !
 !
!
apply-policy
 site-list SPOKES
  control-policy FILTER-GUEST in
 !
!
```

* **解答・解説:**
  Control Policy はデフォルトで**暗黙の拒否 (Implicit Deny)** が適用される。上記の例では Sequence 10 で `192.168.200.0/24` を reject しているが、`default-action accept` が記述されていないため、他のすべての正常な OMP ルートおよび TLOC ルートが暗黙的にドロップされた。
  **修正手順:** `control-policy FILTER-GUEST` 内に `default-action accept` を追加し、ポリシーをコミット・アクティベートする。

---

### 質問 2 (AAR / SLA 挙動分析)
Application-Aware Routing Policy において、`preferred-color biz-internet strict` と設定されている場合、`biz-internet` 回線の Loss/Latency が SLA 閾値を超えた（SLA 違反となった）時の WAN Edge のデータパケット転送挙動として正しいものを選べ。

1. 二番目に優位な TLOC（例: mpls）へ自動的にフェイルオーバーして転送を継続する。
2. 他の利用可能な任意の TLOC へラウンドロビンで分散転送する。
3. 代替回線への迂回を行わず、対象アプリケーションのパケットを破棄（ドロップ）する。
4. vSmart へ通知し、vSmart が OMP ルートを再計算するまでパケットをローカルキューに保持する。

* **解答・解説:** **正解: 3**
  `strict` オプションが指定されている場合、該当の Preferred Color が SLA 基準を満たさなくなると、代替 TLOC への動的フェイルオーバーを行わず、パケットをドロップ（または非適合アクション）する。`strict` が付いていない場合は、SLA 基準を満たす別の TLOC へ自動迂回する。

---

### 質問 3 (Design / Policy Architecture)
vSmart 上で作成された Centralized Data Policy と Application-Aware Routing (AAR) Policy の実行・適用場所に関する記述として正しいものを選べ。

1. どちらも vSmart コントローラの CPU 上でデータパケット単位でリアルタイム評価される。
2. ポリシーの定義とアクティベートは vSmart 上で行われるが、ポリシー命令は OMP 経由で WAN Edge へ配信され、WAN Edge のデータプレーンでパケット単位で処理される。
3. Data Policy は vManage 上で処理され、AAR Policy は vSmart 上で処理される。
4. WAN Edge 上で CLI から直接投入しなければ動作しない。

* **解答・解説:** **正解: 2**
  集中ポリシー（Centralized Data Policy / AAR Policy）は、設計・集中管理を vSmart 上で行い、`apply-policy` により OMP 経由で対象の WAN Edge へダウンロードされ、WAN Edge の CEF / ハードウェアデータプレーン上で高速処理される。

---

### 質問 4 (Direct Internet Access - DIA 実装)
支社拠点で Direct Internet Access (DIA) を Centralized Data Policy により実装したが、クライアントからの HTTP トラフィックがインターネットへ出ずに破棄されている。cEdge 上で確認すべき最も可能性の高い原因を 2 つ挙げよ。

* **解答・解説:**
  1. **VPN 0（Transport ポート）での IP NAT 設定欠落:** DIA でパケットを外部へ送信する際、cEdge の外部 WAN ポートに `ip nat outside` / `nat`（IP NAT）が設定されていないと、プライベート IP アドレスのまま外部へ流出するか破棄される。
  2. **cEdge 上への Local Data Policy / Centralized Data Policy の非適用または vSmart からの配信失敗:** vSmart 側で `apply-policy` の `site-list` や `vpn-list` に誤りがあり、cEdge に DIA 用の Data Policy 命令が届いていない (`show sdwan policy from-vsmart` で確認可能)。

---

### 質問 5 (Troubleshooting)
cEdge ルータにおいて、AAR Policy が正常に機能してリアルタイムに TLOC が切り替わっているか、および各 TLOC の遅延・パケット損失率を確認するための検証コマンドを 2 つ示せ。

* **解答・解説:**
  1. **`show sdwan bfd sessions`**: 各 TLOC トンネル間で測定されているリアルタイムの Latency, Loss, Jitter 値を確認する。
  2. **`show sdwan app-route statistics`**: アプリケーションクラスごとのマッチ数、使用中の TLOC、SLA 適合状態を確認する。

---

## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Policy Configuration Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/ios-xe-17/policies-book-xe-17.html)
* [Cisco Technical Notes: Understand SD-WAN Application-Aware Routing](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-understand-sd-wan-application-aware-rout.html)
* [Cisco Live Presentation: BRKKLS-2015 - Deep Dive into Cisco SD-WAN Policies](https://www.ciscolive.com/)
* [Cisco Validated Design (CVD): SD-WAN End-to-End System Integration Guide](https://www.cisco.com/c/en/us/solutions/design-zone/wan-design-guides.html)

---

## 📝 補足（Notes）

* **Centralized Policy のアクティベート順序:** vManage GUI 上で Centralized Policy を作成した際、最後の「Activate」ボタンを押すことで初めて vSmart へ NETCONF 経由でプッシュされ、vSmart から全 WAN Edge へ配信される。
* **Data Policy と Localized ACL の優先順位:** WAN Edge 上で Centralized Data Policy と Localized Access Control List (ACL) が両方適用されている場合、原則として **Centralized Data Policy が優先して評価** される。



## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKTRS-3793: Advanced SD-WAN Routing Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-3793) - 集中ポリシーと OMP 属性操作の深いデバッグ解説。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - ポリシー push 失敗時のトラブル解決。
*   [**BRKXAR-2001: Intent Based Cross Domain SDA and SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKXAR-2001) - ポリシー連携の設計手法。

### Configuration ガイド
*   [**Cisco SD-WAN Policies Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/vedge-20-x/policies-book.html) - 公式の全ポリシー設定マニュアル。
*   [**Configuring Application-Aware Routing**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/vedge-20-x/policies-book/m-app-aware-routing.html)。

### テクニカルドキュメント・設定例
*   [**SD-WAN Centralized Policy Architecture Overview**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/sd-wan-design-guide.html)。
*   [**SD-Access and SD-WAN Integration (Tech Note)**](https://www.cisco.com/c/dam/en/us/td/docs/solutions/CVD/Campus/sda-sdwan-integration-2019oct.pdf)。

---

## 📝 補足
- この学習メモは、SD-WAN ポリシーが「誰が(Site)」「何に対し(VPN/App)」「どのように(Topology/SLA)」制御するかという論理的な流れを整理しています。CCIE EI ラボ試験では、vManage の GUI 画面がソース Workbook のように示されるため、各入力項目が CLI のどの属性（OMP TLOC, Preference, Color）に対応しているかを常に意識して学習することが重要です。

