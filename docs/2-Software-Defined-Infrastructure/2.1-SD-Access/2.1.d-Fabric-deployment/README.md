---
layout: default
title: 2.1.d-Fabric-deployment
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 4
---

# 2.1.d Fabric deployment

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における Cisco SD-Access ファブリック構築・運用のコア技術である **`2.1.d Fabric deployment`**（Host onboarding, Authentication templates, Port configuration, Multisite remote border, Border priority, Adding devices to fabric）について、Cisco Catalyst Center (旧 Cisco DNA Center) 2.3.x、Cisco ISE 3.x、および Cisco IOS-XE 17.x の実装基準に 100% 準拠して詳細に解説します [21, 2.1.d]。

---

## 📘 概要

### 機能概要
**Fabric Deployment（ファブリック展開）** とは、アンダーレイおよびファブリックロール（Control Plane, Border, Edge）が定義された Cisco SD-Access 環境において、実際のエンドポイント（PC、IP Phone、IoT デバイス、AP 等）やファブリックデバイスを参加させ、認証・ポート設定・マルチサイト連携・トラフィック制御を完成させる一連の実装プロセスです [21, 2.1.d]。

### 利用目的
1. **ゼロトラスト認証と柔軟な Host Onboarding:** 802.1X / MAB / Easy PSK 等の認証テンプレート（Authentication Templates）により、接続端末のアイデンティティを識別し、Dynamic VLAN (VN) および SGT (Security Group Tag) を自動割り当てする [21, 2.1.d (i), (ii)]。
2. **ポート設定の標準化 (Port Configuration):** Catalyst Center のポート割り当てプロファイルにより、Fabric Edge 上のアクセスポートを認証ポート、静的アクセスポート、トランクポート等に自動化・標準化して展開する [21, 2.1.d (iii)]。
3. **ファブリックノードの動的追加 (Adding Devices to Fabric):** Catalyst Center からインベントリ管理されたスイッチに対し、ファブリックロール（Fabric Edge, Control Plane, Border）およびファブリックサイト（Fabric Site）を紐づけて設定をプロビジョニングする [21, 2.1.d (vi)]。
4. **マルチサイト Remote Border 連携 (Multisite Remote Border):** 小規模拠点やデータセンター等において、ローカルに Control Plane / Border を持たずにメインサイトの Remote Border / Remote Control Plane を共有利用し、オーバーレイセグメンテーション（VN/SGT）を維持する [21, 2.1.d (iv)]。
5. **Border Priority による出口制御 (Border Priority):** 複数の External / Internal Border が存在する環境で、プライマリ/セカンダリの出口優先順位を制御し、非対称ルーティング（Asymmetric Routing）の発生を防ぐ [21, 2.1.d (v)]。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **対象 Blueprint** | 2.0 Software Defined Infrastructure > 2.1 Cisco SD-Access > 2.1.d Fabric deployment [21, 2.1.d] |
| **構成サブトピック** | (i) Host onboarding, (ii) Authentication templates, (iii) Port configuration, (iv) Multisite remote border, (v) Border priority, (vi) Adding devices to fabric [21, 2.1.d] |
| **主要コンポーネント** | Cisco Catalyst Center, Cisco ISE 3.x, Cisco Catalyst 9000 シリーズ (IOS-XE 17.x) [21, 2.1.d] |
| **認証方式** | Closed Authentication, Open Authentication (No Monitor / Low Impact), Easy PSK, WebAuth / CWA [21, 2.1.d (ii)] |
| **ホスト登録機構** | SISF (Switch Integrated Security Features), LISP Dynamic EID Registration, RADIUS Change of Authorization (CoA) [21, 2.1.d (i)] |
| **マルチサイト拡張** | Multisite Remote Border (Main Site の MS/MR & External Border を IP/WAN 越しに共有) [21, 2.1.d (iv)] |
| **制御優先度** | Border Priority (External Border の優先度設定により Default Route / EID 広告の選定を最適化) [21, 2.1.d (v)] |

---

## 🏗 動作原理

### Host Onboarding 通信フロー

```
[Endpoint] ──(1. Auth Request)──> [Fabric Edge] ──(2. RADIUS Access-Request)──> [Cisco ISE]
                                      │                                              │
                                      │<──(3. Access-Accept: VN, SGT, dACL)──────────┘
                                      │
                         (4. IP/MAC 学習 via SISF)
                                      │
                         (5. LISP Map-Register)
                                      ↓
                         [Control Plane Node (MS/MR)]
```

1. **認証リクエスト (1):** エンドポイントが Fabric Edge ポートに接続し、802.1X EAPoL または MAB (MAC Authentication Bypass) パケットを送信。
2. **ISE 問い合わせ (2):** Fabric Edge が RADIUS Access-Request を Cisco ISE へ送信。
3. **ポリシー応答 (3):** Cisco ISE が Endpoint Custom Attribute / Identity Group に応じた RADIUS Access-Accept（`Tunnel-Private-Group-ID` = VLAN/VN, `cisco-av-pair:cts:security-group-tag` = SGT）を返却。
4. **ホストトラッキング (4):** Fabric Edge が SISF (Switch Integrated Security Features) により EID (IP/MAC) をバインド。
5. **ファブリック登録 (5):** Fabric Edge が Dynamic EID として Control Plane Node (MS/MR) へ LISP Map-Register を送信。

---

## ⚙ 动作シーケンス

### 1. Host Onboarding & Authentication Sequence
1. **Link Up / Probe:** アクセスポートでリンクアップを検知。Fabric Edge は 802.1X EAP-Request/Identity を送信。
2. **EAPoL / MAB Fallback:** 応答がない場合、MAB (MAC アドレスベース認証) へフォールバック。
3. **RADIUS Policy Evaluation:** ISE が Policy Sets（Authentication Policy ➔ Authorization Policy）を評価。
4. **RADIUS CoA / Enforcement:** 認証成功後、Fabric Edge 側で Access VLAN（Dynamic VLAN）と SGT（Security Group Tag）をポートにインライン適用。
5. **DHCP Request & Relay:** 端末が Anycast Gateway へ DHCP Request を送信。Anycast Gateway が Central DHCP Server へ Relay。
6. **LISP Dynamic EID Registration:** Fabric Edge は端末が IP アドレスを取得したことを SISF で検出すると、LISP MS/MR に対して Map-Register を発行。

### 2. Multisite Remote Border Sequence
1. **Remote Site Request:** Remote Site の Fabric Edge にエンドポイントが接続。
2. **LISP Query to Remote MS:** Remote Edge は Main Site に存在する Remote Control Plane Node (MS/MR) に対して Map-Request を送信。
3. **External Path Resolution:** 外部 IP 宛通信が発生した場合、Main Site の Remote Border アドレス（RLOC）が解決され、WAN トンネル経由で Main Site Border へトラフィックを転送。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprintで重要なポイント
* **Authentication Templates の挙動差:** Closed Authentication（認証通過まで EAPoL/DHCP 以外の全トラフィック遮断）と Open Authentication（Low Impact/No Monitor Mode: 認証未完了でも制限付き通信を許可）のコンフィグ差および ISE 連携 [21, 2.1.d (ii)]。
* **Port Assignment & Host Onboarding:** Catalyst Center GUI で定義された Fabric Host Onboarding プロファイルが、IOS-XE CLI 上でどのように展開されるか（`authentication port-control auto`, `mab`, `dot1x pae authenticator` 等） [21, 2.1.d (i), (iii)]。
* **Adding Devices to Fabric プロビジョニング:** Catalyst Center からデバイスを Fabric Site に追加する際の設定プレビュー理解（LISP 設定, Anycast Gateway SVI 生成, VRF 定義） [21, 2.1.d (vi)]。
* **Border Priority 設計:** 複数 Border 構成における Default Export / Import の Priority 設定（Primary vs Secondary） [21, 2.1.d (v)]。

### ラボ試験で問われやすい問題パターン
1. **Host Onboarding 失敗トラブルシューティング:**
   * 症状: 端末が IP アドレスを取得できず、LISP Map-Cache に登録されない。
   * 原因: Port 上で SISF / Device Tracking (`device-tracking policy`) が無効化されている、または ISE 側で返却する Dynamic VLAN 名と Edge 側の VLAN/VN マッピングが不一致。
2. **Authentication Template の切り替え問題:**
   * 要件: 特定ポートグループに対して、認証未完了端末も特定 IP (DHCP/DNS) への疎通を許可する「Low Impact Mode (Open Auth)」を設定せよ。
3. **Multisite Remote Border 構成実装:**
   * 要件: Remote Site の Fabric Edge が Main Site の Border/Control Plane ノードを参照して外部疎通を行うようプロビジョニング/CLI 設定を行え [21, 2.1.d (iv)]。

---

## 🛠 設定方法

### 1. Closed Authentication Template CLI 設定例 (Fabric Edge)
```bash
! 1. Switch Integrated Security Features (SISF) Device Tracking 設定
device-tracking policy SD-ACCESS-DT-POLICY
 device-role node
 security-level glean
 tracking enable reachable-lifetime 300

! 2. Dynamic Template / Port Configuration
interface GigabitEthernet1/0/1
 description SD-ACCESS-HOST-PORT-CLOSED-AUTH
 switchport mode access
 switchport access vlan 1020
 authentication periodic
 authentication timer reauth 3600
 authentication port-control auto
 mab
 dot1x pae authenticator
 dot1x timeout tx-period 3
 device-tracking attach-policy SD-ACCESS-DT-POLICY
 source template ClosedAuthTemplate
 auto qos trust
 spanning-tree portfast
 spanning-tree bpduguard enable
```

### 2. Border Priority & Default Route Export CLI 設定例 (Fabric Border)
```bash
! Primary Border での Priority 100 指定 (Default Route 優先注入)
router lisp
 locator-table default
 instance-id 4099
  service ipv4
   eid-table default
    map-cache 0.0.0.0/0 map-request
    exit
   exit
  exit
 !
 site site_external
  authentication-key Cisco123!
  description SD-Access Primary Border
  ! Border Priority 設定 (高値が優先)
  priority 100
  weight 100
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **認証状態の確認** | `show authentication sessions interface <INT> details` |
| **SISF / デバイストラッキングの確認** | `show device-tracking database interface <INT>` |
| **LISP Dynamic EID 登録確認** | `show lisp instance-id <ID> ipv4 dynamic-eid` |
| **LISP Map-Cache 確認** | `show lisp instance-id <ID> ipv4 map-cache` |
| **Cisco TrustSec (SGT) 確認** | `show cts interface <INT>` / `show cts role-based permissions` |
| **ポート設定状態の確認** | `show running-config interface <INT>` |
| **802.1X / MAB デバッグ** | `debug dot1x all` / `debug mab all` |
| **SISF デバッグ** | `debug device-tracking sisf all` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **端末が認証に失敗し VLAN が割り当たらない** | ISE 側の Authorization Policy 条件不一致、または RADIUS Shared Key の不一致 | `show authentication sessions interface <INT>` | ISE ログ (Live Logs) を確認し、NAS-IP / RADIUS Key / EAP タイプを修正 |
| **認証は成功するが IP アドレスが取得できない** | SISF デバイストラッキング未無効化、または Anycast Gateway (SVI) 上の DHCP Option 82 / Relay 設定不足 | `show device-tracking database` / `show ip dhcp snoop` | Fabric Edge の SVI 上で `ip helper-address` および SISF ポリシーを正常適用 |
| **IP は取得できるが他ファブリック内端末と通信不能** | LISP Dynamic EID 登録失敗 (Fabric Edge ➔ MS/MR 間の Key 不一致) | `show lisp instance-id <ID> ipv4 dynamic-eid` | `router lisp` 配下の `authentication-key` を MS/MR と Edge 間で完全一致させる |
| **Remote Border 経由の外部疎通が失敗する** | Remote Border までの WAN MTU 不足 (VXLAN オーバーヘッド破棄)、または Priority/Weight 未設定 | `show lisp instance-id <ID> ipv4 map-cache 0.0.0.0/0` | WAN ルータの MTU を 1550 以上に拡大し、Border 上で `priority` コマンドを設定 |

---

## ⚠ 制限事項

1. **Authentication Template の同時適用制限:** 同一アクセスポートに対して複数の異なる Authentication Template（Closed と Open 等）を重複してバインドすることは不可。
2. **SISF Device Tracking の必須要件:** IOS-XE 16.9 以降では従来の IPDT (`ip device tracking`) は非推奨となり、SISF (`device-tracking policy`) が必須。未設定の場合 LISP への Dynamic EID 自動登録が機能しない。
3. **Remote Border のハードウェア制限:** Remote Border を実行するスイッチ/ルータは、大容量 TCAM および LISP/VXLAN カプセル化に対応した Cisco Catalyst 9500 / Catalyst 8000 シリーズ等が推奨される。

---

## 🔄 他技術との関連

* **Cisco ISE (3.x):** 802.1X / MAB 認証エンジンとして Host Onboarding を一元制御。Dynamic VLAN および SGT を RADIUS CoA 経由で動的バインド。
* **LISP (Locator/ID Separation Protocol):** SISF で検出したホスト IP/MAC を Control Plane Node へ Dynamic EID として自動通知・登録。
* **VXLAN (Virtual Extensible LAN):** Onboarding されたホストパケットに対し、VNI (VN) と SGT ヘッダーを付与してオーバーレイカプセル化転送。
* **DHCP / DNS (Shared Services):** Fabric Edge の Anycast Gateway SVI から Fusion Router 経由で Relay され、ホストへ IP/Option を割り当て。

---

## 🧩 比較表

### Authentication Templates の比較

| 項目 | Closed Authentication | Open Authentication (Low Impact) | No Monitor (Open Mode) |
| :--- | :--- | :--- | :--- |
| **認証前のポート状態** | EAPoL / DHCP 以外のトラフィックを完全に遮断 | PACL/dACL により特定通信 (DHCP/DNS/ISE) のみ許可 | すべてのトラフィックを事前許可 (ログ収集目的) |
| **セキュリティレベル** | 最高 (ゼロトラスト標準) | 中 (利便性とセキュリティの両立) | 低 (可視化のみ) |
| **適用推奨環境** | 一般 PC / エンタープライズ端末 | 認証未対応 IoT / IP Phone / プリンタ | 事前アセスメント・移行フェーズ |
| **Failback / Fallback** | MAB / WebAuth へのフォールバック | MAB / WebAuth へのフォールバック | なし |

---

## 💡 ベストプラクティス

1. **Host Onboarding には SISF (Device Tracking) を必須有効化:** Fabric Edge 全ポートで `device-tracking policy` をバインドし、IP/MAC 検出バインドの信頼性を担保する。
2. **Closed Authentication を基本テンプレートとして採用:** ゼロトラストセキュリティ実現のため、原則 Closed Auth を適用し、例外端末のみ MAB や Easy PSK を ISE 側でハンドリングする。
3. **Dual Border 環境では Priority を明示設計:** Primary Border に `priority 100`、Secondary Border に `priority 50` を設定し、確実な非対称ルーティング防止と制御の可視化を図る。

---

## 📝 ラボ学習・設定サンプル例

### サンプル 1: Closed Authentication Template + SISF による Host Onboarding 構成

* **問題:** Fabric Edge (FE1) の Gi1/0/1 に接続する 802.1X/MAB 端末に対し、Closed Authentication テンプレートおよび SISF デバイストラッキングを適用せよ。
* **要件:**
  1. SISF デバイストラッキングポリシー `SD-ACCESS-SISF` を作成し、Gi1/0/1 にバインドすること。
  2. ポート認証モードを `Closed Authentication` とし、802.1X 優先、応答なし時は MAB へフォールバックさせること。
  3. Reauthentication タイマーを 3600 秒に設定すること。
* **設定例:**
  ```bash
  ! SISF デバイストラッキングポリシー作成
  device-tracking policy SD-ACCESS-SISF
   device-role node
   security-level glean
   tracking enable reachable-lifetime 300
  !
  interface GigabitEthernet1/0/1
   description SD-ACCESS-HOST-CLOSED-AUTH
   switchport mode access
   switchport access vlan 1020
   authentication periodic
   authentication timer reauth 3600
   authentication port-control auto
   mab
   dot1x pae authenticator
   dot1x timeout tx-period 3
   device-tracking attach-policy SD-ACCESS-SISF
   source template ClosedAuthTemplate
   spanning-tree portfast
   spanning-tree bpduguard enable
  ```
* **検証方法:**
  ```bash
  show authentication sessions interface GigabitEthernet1/0/1 details
  show device-tracking database interface GigabitEthernet1/0/1
  ```

---

### サンプル 2: Low Impact Mode (Open Authentication) ポート設定

* **問題:** IP Phone やプリンタが接続される FE1 Gi1/0/2 ポートに対し、認証完了前でも DHCP/DNS 疎通を許可する Open Authentication (Low Impact Mode) を構成せよ。
* **要件:**
  1. 認証前に適用する dACL `OPEN-AUTH-PREAUTH-ACL` を作成し、DHCP/DNS/ISE 宛ての通信を許可すること。
  2. ポート上で `authentication open` を有効化すること。
* **設定例:**
  ```bash
  ! 事前許可 ACL 定義
  ip access-list extended OPEN-AUTH-PREAUTH-ACL
   permit udp any any eq bootps
   permit udp any any eq domain
   permit ip any host 192.168.10.50  ! ISE Server
   deny   ip any any
  !
  interface GigabitEthernet1/0/2
   description SD-ACCESS-OPEN-AUTH-PORT
   switchport mode access
   switchport access vlan 1020
   ip access-group OPEN-AUTH-PREAUTH-ACL in
   authentication open
   authentication periodic
   authentication port-control auto
   mab
   dot1x pae authenticator
   spanning-tree portfast
  ```
* **検証方法:**
  ```bash
  show authentication sessions interface GigabitEthernet1/0/2
  ```

---

### サンプル 3: Dynamic SGT & Dynamic VLAN (RADIUS CoA 連携)

* **问题:** Cisco ISE から Access-Accept 応答としてバインドされる Dynamic VLAN (VN_Employee = VLAN 1020) および Dynamic SGT (SGT 4: Employee) を正しく受信・処理できるよう Fabric Edge を構成せよ。
* **要件:**
  1. RADIUS サーバーグループ `ISE-CLUSTER` を作成し、Dynamic Authorization (CoA Port 1700) を有効化すること。
  2. Cisco TrustSec (CTS) 制御をグローバルおよびインターフェイスで有効化すること。
* **設定例:**
  ```bash
  aaa group server radius ISE-CLUSTER
   server-private 192.168.10.50 key Cisco123!
  !
  aaa authentication dot1x default group ISE-CLUSTER
  aaa authorization network default group ISE-CLUSTER
  aaa accounting network default group ISE-CLUSTER
  !
  aaa server radius dynamic-author
   client 192.168.10.50 server-key Cisco123!
   port 1700
  !
  cts cred id ISE-CRED password Cisco123!
  cts authorization list default
  !
  interface GigabitEthernet1/0/1
   cts role-based enforcement
  ```
* **検証方法:**
  ```bash
  show cts interface GigabitEthernet1/0/1
  show cts role-based permissions
  ```

---

### サンプル 4: 静的アクセスポート設定 (No Authentication / Static Access Port)

* **問題:** 認証非対応のサーバーが接続される FE1 Gi1/0/10 ポートを、認証なしの静的アクセスポートとして VN_Servers (VLAN 1030) に収容せよ。
* **要件:**
  1. 802.1X/MAB 認証を無効化すること。
  2. ポートを静的アクセスモードにし、VLAN 1030 を割り当てること。
  3. LISP Dynamic EID 登録のために SISF デバイストラッキングを適用すること。
* **設定例:**
  ```bash
  interface GigabitEthernet1/0/10
   description SD-ACCESS-STATIC-SERVER-PORT
   switchport mode access
   switchport access vlan 1030
   no authentication port-control
   device-tracking attach-policy SD-ACCESS-SISF
   spanning-tree portfast
  ```
* **検証方法:**
  ```bash
  show device-tracking database interface GigabitEthernet1/0/10
  show lisp instance-id 4097 ipv4 dynamic-eid
  ```

---

### サンプル 5: Adding Devices to Fabric (Fabric Edge へのスイッチプロビジョニング CLI)

* **問題:** 新規スイッチ FE2 を Catalyst Center から Fabric Site `Site-A` の Fabric Edge ノードとして追加・プロビジョニングする際の主要コンフィグを再現せよ。
* **要件:**
  1. LISP プロセスを有効化し、Control Plane Node (10.1.1.1) へ Map-Server / Map-Resolver 登録を行うこと。
  2. Anycast Gateway SVI (VLAN 1020, IP 10.20.0.1/24, Anycast MAC 0000.0c9f.f001) を作成すること。
* **設定例:**
  ```bash
  ! 1. Anycast Gateway SVI 構成
  vlan 1020
   name VN_Employee
  !
  interface Vlan1020
   description SD-ACCESS-ANYCAST-GW
   mac-address 0000.0c9f.f001
   vrf forwarding VN_Employee
   ip address 10.20.0.1 255.255.255.0
   ip helper-address 192.168.10.100
   no shut
  !
  ! 2. LISP Dynamic EID 構成
  router lisp
   locator-table default
   locator-set RLOC-SET
    10.1.1.2 priority 1 weight 100  ! FE2 Loopback0
   exit
   !
   instance-id 4096
    service ipv4
     eid-table vrf VN_Employee
     dynamic-eid EID-EMPLOYEE
      database-mapping 10.20.0.0/24 locator-set RLOC-SET
      exit
     exit
    exit
   !
   site site_sdaccess
    authentication-key Cisco123!
    itr map-resolver 10.1.1.1  ! Control Plane Node
    etr map-server 10.1.1.1    ! Control Plane Node
  ```
* **検証方法:**
  ```bash
  show lisp instance-id 4096 ipv4 dynamic-eid
  show lisp site
  ```

---

### サンプル 6: Multisite Remote Border (Main Site Border 参照設定)

* **問題:** 独立した Control Plane ノードを持たない小規模拠点 Remote-Site1 の Fabric Edge (FE-REMOTE) が、Main Site の Control Plane/Border ノード (10.100.1.1) を Remote Border として参照するよう構成せよ。
* **要件:**
  1. FE-REMOTE 上で ITR/ETR の指定先を Main Site の 10.100.1.1 に設定すること。
  2. 外部宛デフォルトルート (0.0.0.0/0) の Map-Request を Remote Border 宛に生成させること。
* **設定例:**
  ```bash
  router lisp
   locator-table default
   !
   instance-id 4096
    service ipv4
     eid-table vrf VN_Enterprise
      map-cache 0.0.0.0/0 map-request
      exit
     exit
    exit
   !
   site REMOTE-SITE-1
    authentication-key RemoteKey123!
    itr map-resolver 10.100.1.1  ! Main Site Remote Control Plane
    etr map-server 10.100.1.1    ! Main Site Remote Border
  ```
* **検証方法:**
  ```bash
  show lisp instance-id 4096 ipv4 map-cache
  ```

---

### サンプル 7: Border Priority による External Border 出口優先度制御

* **問題:** 同一ファブリックサイト内に存在する Primary External Border (Border-1) と Secondary External Border (Border-2) に対し、Border Priority を設定して外部デフォルトルートの優先度を管理せよ。
* **要件:**
  1. Border-1 の Priority を 100、Weight を 100 とすること。
  2. Border-2 の Priority を 50、Weight を 50 とすること。
* **設定例:**
  ```bash
  ! Border-1 (Primary) コンフィグ
  router lisp
   site site_external
    authentication-key BorderKey123!
    description PRIMARY-EXTERNAL-BORDER
    priority 100
    weight 100

  ! Border-2 (Secondary) コンフィグ
  router lisp
   site site_external
    authentication-key BorderKey123!
    description SECONDARY-EXTERNAL-BORDER
    priority 50
    weight 50
  ```
* **検証方法:**
  ```bash
  ! Control Plane Node 上で確認
  show lisp site site_external
  ```

---

### サンプル 8: Dynamic AP Onboarding (Fabric AP ポート設定)

* **問題:** Cisco Access Point (AP) が接続された FE1 Gi1/0/5 ポートに対し、CDP/LLDP による AP 自動検知と INFRA_VN (VLAN 1009) への動的収容を構成せよ。
* **要件:**
  1. AP 検知時に動的バインドされる VLAN 1009 (INFRA_VN) を作成すること。
  2. 認証テンプレートにて AP (Cisco OUI / CDP) 判定時に全認証をバイパスして Trunk/Access 化させること。
* **設定例:**
  ```bash
  vlan 1009
   name INFRA_VN
  !
  interface GigabitEthernet1/0/5
   description SD-ACCESS-FABRIC-AP-PORT
   switchport trunk native vlan 1009
   switchport mode trunk
   device-tracking attach-policy SD-ACCESS-SISF
   auto qos trust
   spanning-tree portfast trunk
  ```
* **検証方法:**
  ```bash
  show cdp neighbors GigabitEthernet1/0/5
  show mac address-table interface GigabitEthernet1/0/5
  ```

---

### サンプル 9: SXP (SGT Exchange Protocol) による非ファブリックノード連携

* **問題:** SD-Access ファブリック外部の非ファブリックレガシー配備スイッチ (SW-LEGACY: 192.168.100.2) と Fabric Edge (10.1.1.1) 間で SXP セッションを確立し、IP-SGT マッピングを動的共有せよ。
* **要件:**
  1. FE1 を SXP Speaker、SW-LEGACY を SXP Listener とすること。
  2. SXP パスワードを `SxpKey123!` とすること。
* **設定例:**
  ```bash
  ! Fabric Edge (SXP Speaker) 設定
  cts sxp enable
  cts sxp default password SxpKey123!
  cts sxp connection peer 192.168.100.2 password default mode local speaker
  ```
* **検証方法:**
  ```bash
  show cts sxp connections
  show cts role-based sgt-map
  ```

---

### サンプル 10: Host Onboarding トラブルシューティング実演シナリオ

* **問題:** 端末が FE1 Gi1/0/1 に接続したが、802.1X 認証失敗後に MAB へ移行せず、通信が完全に遮断されている。障害を診断し修正せよ。
* **要件:**
  1. `show authentication sessions` で原因を確認すること。
  2. MAB 認証の有効化およびタイマー調整を実施すること。
* **修復コンフィグ例:**
  ```bash
  interface GigabitEthernet1/0/1
   mab  ! MAB が未設定であったため追加
   dot1x timeout tx-period 2
   authentication order dot1x mab
   authentication priority dot1x mab
  ```
* **検証方法:**
  ```bash
  clear authentication sessions interface GigabitEthernet1/0/1
  show authentication sessions interface GigabitEthernet1/0/1 details
  ```

---

## ❓ 想定試験問題

### 問題 1 (コンフィグ読解)
以下の Fabric Edge コンフィグにおいて、端末が正常に 802.1X 認証を通過して IP アドレスを取得したにもかかわらず、ファブリック内の他端末と通信できない原因として最も適切なものを1つ選べ。

```bash
interface GigabitEthernet1/0/3
 switchport mode access
 switchport access vlan 1020
 authentication port-control auto
 dot1x pae authenticator
```

* (A) `mab` コマンドが設定されていないため。
* (B) `device-tracking attach-policy` がバインドされておらず、SISF がホスト IP/MAC を検出して LISP Dynamic EID へ登録できないため。
* (C) `spanning-tree portfast` が未設定のため。
* (D) `authentication open` が欠落しているため。

**正解:** (B)  
**解説:** SD-Access において、Fabric Edge は SISF (Device Tracking) により端末の IP/MAC バインドを検出し、それをトリガーとして LISP MS/MR へ Dynamic EID 登録を行います。`device-tracking attach-policy` が欠落していると、認証が成功しても LISP 登録が行われず、オーバーレイでの通信が不能となります [21, 2.1.d (i)]。

---

### 問題 2 (トラブルシューティング)
Fabric Border において、2台存在する Border ルータのうち Secondary Border (Border-2) 経由で外部デフォルトルートが優先されてしまう現象が発生した。Primary Border (Border-1) 経由に修正するための正しい LISP 設定はどれか。

* (A) Border-1 の `router lisp` 配下で `priority 100` を設定し、Border-2 で `priority 50` とする。
* (B) Border-1 で `ip route 0.0.0.0 0.0.0.0 Null0 250` を追加する。
* (C) Border-1 のインターフェイス上で `ip ospf cost 1` を設定する。
* (D) Border-1 の LISP 設定で `weight 0` とする。

**正解:** (A)  
**解説:** Cisco SD-Access の Border ノード間における出口優先度は、LISP サイト設定配下の `priority` 値（大きい数値が優先）によって制御されます。Border-1 に高い Priority を割り当てることで、正しく優先経路として選定されます [21, 2.1.d (v)]。

---

### 問題 3 (Design)
小規模なリモート拠点（15端末程度）を SD-Access ファブリックへ統合する際、ローカルに Control Plane / Border ノードを設置せず、コストと運用負荷を最小化する設計構成として最も適しているものはどれか。

* (A) Fabric in a Box (FIAB)
* (B) Multisite Remote Border Architecture
* (C) SD-WAN IP Transit 構成
* (D) Policy Extended Node 構成

**正解:** (B)  
**解説:** ローカルに Border/Control Plane ノードを設置せず、Main Site の Remote Border / Control Plane を共有利用する設計が **Multisite Remote Border** であり、小規模拠点において最もコスト効率に優れます [21, 2.1.d (iv)]。

---

### 問題 4 (実装)
Cisco ISE から Fabric Edge へ返却される RADIUS 属性のうち、端末を特定ファブリック VN（Virtual Network）へ動的に収容するために使用される属性はどれか。

* (A) `cisco-av-pair:cts:security-group-tag`
* (B) `Tunnel-Private-Group-ID` (VLAN Name / ID)
* (C) `Tunnel-Type = VXLAN`
* (D) `Egress-VNS-ID`

**正解:** (B)  
**解説:** ISE から返却される `Tunnel-Private-Group-ID` 属性により Dynamic VLAN（Fabric Edge 上で VN にマッピングされた VLAN）が指定され、端末が該当する VN へ割り当てられます。なお (A) は SGT のバインドに使用されます [21, 2.1.d (i)]。

---

### 問題 5 (トラブルシューティング)
Open Authentication (Low Impact Mode) を適用したポートにおいて、認証未完了の端末が DNS / DHCP サーバーと通信できず、認証プロセスが進まない原因として考えられるものはどれか。

* (A) ポートに事前許可 ACL (`ip access-group`) が適用されていない、または ACL 内で DHCP/DNS 宛通信が許可されていない。
* (B) `authentication port-control auto` が設定されていない。
* (C) 端末の MAC アドレスが ISE に事前登録されていない。
* (D) 802.1X が無効化されているため。

**正解:** (A)  
**解説:** Open Authentication (Low Impact Mode) では、認証前に適用される事前許可 PACL/dACL によって通信が制御されます。この ACL 内で DHCP や DNS などの必須通信が許可されていない場合、端末は IP を取得できず認証に失敗します [21, 2.1.d (ii)]。

---

## 🔗 参考リソース

* [Cisco SD-Access Solution Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/Cisco-Wide-Area-Design-Exchange/SD-Access-Design-Guide.html)
* [Cisco Software-Defined Access Host Onboarding Guide](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-3/configuration_guide/sda/b_173_sda_cg.html)
* [Cisco ISE 3.x Integration with SD-Access Guide](https://www.cisco.com/c/en/us/td/docs/security/ise/3-0/admin_guide/b_ise_admin_3_0.html)
* [Cisco Live BRKCRS-2810 - Cisco SD-Access Host Onboarding Deep Dive](https://www.ciscolive.com/)
* [Cisco Live BRKCRS-2821 - Cisco SD-Access Multisite and Remote Border Deployment](https://www.ciscolive.com/)

---

## 📝 補足（Notes）

* **SISF と IPDT の違い:** IOS-XE 16.9 以降では、従来の `ip device tracking` は完全に SISF (`device-tracking policy`) へ移行しています。SD-Access ラボ試験では必ず SISF 構文で設定してください [21, 2.1.d (i)]。
* **Border Priority の評価軸:** Priority 値が大きいノードが優先選定されます（OSPF などの Cost と逆である点に留意してください） [21, 2.1.d (v)]。



## 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076) - 展開フェーズのベストプラクティス。
*   [**BRKOPS-2035: Real World Use Cases for Deploying Cisco SD-Access**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2035) - 実際のトラブル事例とプロビジョニングの勘所。
*   [**BRKENS-2829: What's New in Cisco SD-Access**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2829) - 最新の Multisite Remote Border 機能の解説。

### Configuration ガイド
*   [**Cisco DNA Center User Guide - Provisioning Fabric Networks**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/2-3-5/user-guide/b_cisco_dna_center_user_guide_2_3_5.html)
*   [**Cisco SD-Access Segmentation Design Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)

### テクニカルドキュメント・設定例
*   [**Host Onboarding in SD-Access (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)
*   [**SD-Access Multisite Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)

---

## 📝 補足
- この学習メモは、SD-Access の展開が単なる「設定の流し込み」ではなく、**アイデンティティ（ISE）とインフラ（DNAC）の密接な同期プロセス**であることを強調しています。CCIE 実技試験では、GUI での成功の裏にある **LISP 登録ステータス** や **Anycast MAC の整合性** を CLI で即座に確認できることが、合格への必須条件となります。


