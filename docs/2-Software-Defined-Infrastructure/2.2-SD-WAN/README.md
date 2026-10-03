---
layout: default
title: 2.2-SD-WAN
parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.2 Cisco SD-WAN

Cisco SD-WAN (Catalyst SD-WAN) アーキテクチャ、コンポーネント（vManage, vSmart, vBond, WAN Edge）、OMP (Overlay Management Protocol)、TLOC (Transport Location)、コントロール・データプレーンポリシー、Application-Aware Routing (AAR)、DIA (Direct Internet Access)、およびサービスサイド・トランスポートサイド・ルーティング統合を網羅した CCIE EI v1.1 試験対策用ハイエンド学習メモです。

---

## 📘 概要

Cisco Catalyst SD-WAN (旧 Viptela) は、従来の硬直した WAN トポロジー（IPsec, DMVPN, MPLS）を抽象化し、ビジネス意図（Business Intent）に基づくオーバーレイネットワークを動的かつ中央集権的に定義・管理する次世代 WAN ソフトウェア定義ソリューションです。

### 1. 利用目的
* **マルチトランスポート統合:** MPLS、Internet (Broadband)、LTE/5G など種類の異なるアンダーレイ回線を束ね、単一の安全なオーバーレイ網（IPsec Tunnel）を自動構築する。
* **アプリケーション品質の可視化と動的経路制御 (AAR):** リアルタイムな回線品質測定（SLA: 降下率、遅延、ジッター）に基づき、Voice や Video トラフィックを最適な回線へ動的に誘導する。
* **セグメンテーションの完全延伸:** VPN (VRF) 概念を用いて、キャンパス（SD-Access）から WAN 網を越えてデータセンター・クラウドまでエンドツーエンドで完全な L3 隔離を実現する。
* **中央集権管理とゼロタッチプロビジョニング (ZTP / PnP):** vManage を通じたポリシー・テンプレートの一括適用と、拠点展開時の作業自動化。

### 2. 利用する場面
* **ハイブリッド WAN / マルチクラウド接続:** 本社・拠点間で MPLS と Internet 双方を常時アクティブ活用（Active-Active）する環境。
* **ローカルブレイクアウト (DIA):** SaaS（SaaS / Office 365 / Salesforce）通信を HQ 経由させず、各拠点の Internet 回線から直接ブレイクアウトさせる環境。
* **セグメント隔離:** 社員用ネットワーク、ゲスト用ネットワーク、IoT/監視カメラ用ネットワークを WAN 全体で個別隔離・伝送する環境。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **建築モデル** | セパレーション・オブ・プレーン（Management, Control, Data, Orchestration の 4 平面完全分離） |
| **主要コンポーネント** | **vManage** (Management), **vSmart** (Control), **vBond** (Orchestration), **WAN Edge / cEdge** (Data) |
| **オーバーレイプロトコル** | **OMP (Overlay Management Protocol)**: TLOC, OMP Route, Service Route を伝搬 |
| **セキュアトンネル** | コントロール面: **DTLS / TLS** (Port 12346/443), データ面: **IPsec (ESP/AH)** (BFD で回線測定) |
| **識別子要素** | **System IP** (32-bit 一意識別子), **Site ID** (拠点識別番号), **Organization Name** (証明書検証用文字列) |
| **TLOC 構成要素** | **System IP** + **Color** (回線識別ラベル) + **Encapsulation** (ipsec / gre) の 3 つの組み合わせ |
| **対応機種 (IOS-XE)** | Catalyst 8300/8200/8500 シリーズ, ISR 4000/1000, ASR 1000, Catalyst 8000v (cEdge) |
| **設計上の注意点** | 全コントローラおよび Edge 間で **Clock Sync (NTP)**、**Certificates (Enterprise CA / Cisco Automated)**、**Organization Name の完全一致** が必須 |

---

## 🏗 動作原理

### 1. コントロールプレーン・データプレーン分離と通信フロー

```
[ vManage (Management) ]     [ vSmart (Control) ]
        │                             │
   (HTTPS/NETCONF)             (OMP / DTLS)
        │                             │
        └──────────────┬──────────────┘
                       │
             [ vBond (Orchestrator) ]  ← 最初の認証 & IP 通知 (STUN)
                       │
       ┌───────────────┴───────────────┐
       ▼                               ▼
[ cEdge Router A ] <═══ IPsec ═══> [ cEdge Router B ]
 (Transport: VPN 0)   (Data Plane)  (Transport: VPN 0)
         │                                 │
 (Service: VPN 1-511)              (Service: VPN 1-511)
```

### 2. オーバーレイ確立の 4 段階ステップ

1. **Step 1: WAN Edge の起動と vBond 認証 (Orchestration Phase)**
   * WAN Edge は自己の証明書 (Chassis ID / Serial Number / TPM) を用い、事前設定された DNS / IP アドレスで **vBond** へ DTLS 接続。
   * vBond は WAN Edge のシリアル番号をホワイトリスト（vManage から同期されたリスト）と照合・検証し、NAT 越えパケットから WAN Edge の Public IP/Port を検出（STUN 機能）。
   * 認証成功後、vBond は WAN Edge に対し **vSmart** および **vManage** の IP アドレス一覧を教え、セッションを初期化。
2. **Step 2: vSmart / vManage とのコントロールセッション確立 (Control Phase)**
   * WAN Edge は **vSmart** および **vManage** との間で直接 DTLS/TLS コントロールセッションをオープン。
   * 相互認証完了後、WAN Edge と vSmart 間で **OMP (Overlay Management Protocol)** ピアリングを樹立。
3. **Step 3: OMP による TLOC / Route / Key の情報交換**
   * WAN Edge は自身の **TLOC Route** (System IP, Color, Encaps, Public/Private IP/Port, IPsec Key)、**OMP Route** (Service VPN プレフィックス)、および **Service Route** を vSmart へ広告。
   * vSmart は受信した情報を集約し、セントラル制御ポリシー（Centralized Control Policy）に従ってフィルタリング・属性変更を行った上で、他拠点の WAN Edge へ再配布。
4. **Step 4: 拠点間 IPsec データトンネル自動生成 (Data Phase)**
   * vSmart から対向拠点の TLOC 情報および AES IPsec Encryption Key を受信した WAN Edge は、対向 TLOC 間で直接 **IPsec トンネル** (UDP 12346 / 4500 等) を確立。
   * トンネル上で **BFD (Bidirectional Forwarding Detection)** パケットを小刻みに送信し、回線の到達性、遅延（Latency）、ジッター（Jitter）、パケット損失率（Packet Loss）をミリ秒単位で常時測定。

---

## ⚙ 動作シーケンス

### OMP (Overlay Management Protocol) の情報配布シーケンス

```
[ cEdge-Site10 ]                 [ vSmart Controller ]                 [ cEdge-Site20 ]
       │                                   │                                   │
       │ 1. OMP TLOC Route Advert          │                                   │
       │    (System-IP:1.1.1.1, Color:biz) │                                   │
       │ 2. OMP Route Advert (10.1.1.0/24)  │                                   │
       │ 3. IPsec Pairwise Key Advert      │                                   │
       ├──────────────────────────────────>│                                   │
       │                                   │ 4. Policy Processing & Filtering  │
       │                                   │ 5. Redistribute OMP Routes & TLOC │
       │                                   ├──────────────────────────────────>│
       │                                   │                                   │
       │                                   │                                   │ 6. Form Direct IPsec Tunnel
       │<=====================================================================>│
       │                                   │                                   │ 7. Run BFD Probes on IPsec Tunnel
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint 重要ポイント
* **CLI vs Feature Template (vManage) 移行:** cEdge における CLI 設定（`sdwan` ブロック / Cisco IOS-XE 標準コマンド）と vManage Template の相互変換ルール。
* **OMP ベストパス選定順序 & 再配送:**
  1. OMP 経路が **Valid** かつ **Reachable** (TLOC が UP) であること。
  2. **OMP Preference** (値が大きいほど優先、デフォルト 0)。
  3. **TLOC Preference** (値が大きいほど優先、デフォルト 0)。
  4. **Origin Protocol Metric** (小優先)。
  5. **Origin Protocol Type** (Cisco SD-WAN 内部優先順位: Connected > Static > BGP > OSPF)。
  6. **Lowest System IP** (数値が小さいほど優先)。
* **TLOC 属性制御 (Color, Restrict, Carrier-Constrained):**
  * `color`: 回線種別（`biz-internet`, `mpls`, `lte`, `custom1` 等）。
  * `restrict`: 同一 Color 同士でのみ IPsec トンネル確立を許可（例: `mpls` ⇔ `mpls` のみ）。
  * `carrier-constrained`: 同一キャリア（Private ネットワーク）内でのみ TLOC 交換を許可。
* **AAR (Application-Aware Routing) ポリシー作成順序:**
  1. **SLA Class** 作成 (Latency, Jitter, Packet Loss 閾値設定)。
  2. **Data Policy** 作成 (Match 条件: Application / IP / Port, Action: SLA Class 割り当て / Preferred Color 設定)。
  3. **Site List / VPN List** への Centralized Policy 適用。
* **DIA (Direct Internet Access) / NAT 構成:**
  * Transport VPN 0 側インターフェイスでの `nat` 有効化。
  * Service VPN 側での `ip route 0.0.0.0 0.0.0.0 vpn 0` (または Centralized Data Policy での `nat use-vpn 0`)。

### 2. ラボ試験で狙われやすいポイント & 落とし穴
* **System IP と Router ID の不整合:** cEdge の OMP System IP と、Service VPN 側 OSPF/BGP の Router ID が重複または未定義でルーティングループや隣接不能に陥る。
* **NTP 時間不一致による Control Session 接続不可:** コントローラと Edge 間の時間補正ができておらず、証明書の有効期限検証（PKI Validation）で失敗。
* **OMP Route Advert 制限 (Default 4 Paths):** デフォルトでは vSmart は同一プレフィックスに対して 4 パスまでしか受信・配布しない (`omp send-path-limit` / `omp ecmp-limit` のチューニング要否)。
* **TLOC Extension コンフィグ:** Dual-Edge 拠点において、片側の物理回線（例: Internet）を隣接 Edge へ L2 延伸して冗長化する際の `tloc-extension` コマンドおよびサブインターフェイス/VLAN 構成。

---

## 🛠 設定方法

### 1. cEdge CLI 基本初期化コンフィグ (Day-0 / Base SD-WAN)

```bash
! --- システム基本定義 ---
system
 system-ip      10.255.255.11
 site-id        110
 organization-name "CCIE-EI-LAB-SDWAN"
 vbond 192.168.1.100 port 12346
!

! --- WAN エッジ トランスペアレント / トランスポート (VPN 0) 設定 ---
sdwan
 interface GigabitEthernet1
  tunnel-interface
   encapsulation ipsec
   color biz-internet restrict
   allow-service dhcp
   allow-service dns
   allow-service icmp
   allow-service ntpd
  exit
 exit
exit

interface GigabitEthernet1
 description *** Transport WAN Interface ***
 ip address 192.168.11.2 255.255.255.0
 no shutdown
exit

ip route vpn 0 0.0.0.0 0.0.0.0 192.168.11.1

! --- サービスサイド (VPN 10) 設定 ---
vrf definition 10
 rd 10:10
 address-family ipv4
  exit-address-family
exit

interface GigabitEthernet2
 description *** LAN Service Interface ***
 vrf forwarding 10
 ip address 10.11.10.1 255.255.255.0
 no shutdown
exit

! --- OMP サービスルート広告定義 ---
sdwan
 omp
  no shutdown
  graceful-restart
  advertise connected
  advertise static
  advertise ospf external
 exit
exit
```

### 2. Centralized AAR Policy (vSmart 上での設定定義イメージ)

```bash
! --- SLA クラスの定義 ---
policy
 sla-class VOICE_SLA
  latency 150
  loss 1
  jitter 30
 !
 sla-class DATA_SLA
  latency 300
  loss 3
 !
! --- アプリケーションリスト定義 ---
 list app-list CRITICAL_APPS
  app office365
  app salesforce
  app ms-teams
 !
! --- Centralized Data Policy (AAR) 定義 ---
 policy-file AAR_POLICY
  app-route-policy AAR_APPLICATION_POLICY
   vpn-list SERVICE_VPNS
    sequence 10
     match
      app-list CRITICAL_APPS
     !
     action
      sla-class VOICE_SLA preferred-color biz-internet mpls
     !
    !
    default-action sla-class DATA_SLA
   !
  !
 !
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Control Session 確認** | `show sdwan control connections` |
| **vBond との接続履歴** | `show sdwan control local-properties` |
| **OMP ピアリング状態** | `show sdwan omp peers` |
| **OMP 受信・送信ルート確認** | `show sdwan omp routes` / `show sdwan omp tlocs` |
| **データ面 IPsec トンネル** | `show sdwan ipsec ipsec-pkts` / `show sdwan ipsec inbound-connections` |
| **BFD 回線測定データ** | `show sdwan bfd sessions` / `show sdwan bfd history` |
| **AAR SLA 判定統計** | `show sdwan app-route statistics` |
| **ポリシー適用確認** | `show sdwan policy from-vsmart` |
| **デバッグログ** | `debug sdwan omp` / `debug sdwan control` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **Control Session 樹立不可 (`CRTTMO` / `BIDNXT`)** | vBond への IP 疎通不能、または Firewall による UDP 12346 遮断 | `show sdwan control local-properties` | WAN インターフェイスへの IP/GW 設定確認、`allow-service` または FW ポート開放 |
| **Certificate Validation Failed** | 証明書の不一致、時間ズレ (NTP 非同期)、Org-Name ミスマッチ | `show clock`<br>`show sdwan control local-properties` | 全デバイスで NTP を同期させ、Org-Name を完全に一致させる |
| **IPsec Tunnel が生成されない** | 対向 TLOC の IP 変更未受信、Color 制御 (`restrict`) のアンマッチ | `show sdwan omp tlocs`<br>`show sdwan ipsec summary` | `restrict` オプションを外すか、対向 TLOC へのルート到達性を確認 |
| **OMP ルートが RIB へ挿入されない** | Service VPN 側の BFD / TLOC 不通、または OMP ベストパス未選定 | `show sdwan omp routes 10.x.x.x` | TLOC への到達性確認および OMP 重複・メトリックを見直し |
| **AAR で Preferred Color へ迂回しない** | BFD プローブで SLA 閾値（Latency/Loss）が超過していない、または設定のタイポ | `show sdwan app-route statistics` | SLA 閾値を意図的に低く下げるか、パケットロス発生器でテスト検証 |

---

## ⚠ 制限事項

* **cEdge (IOS-XE SD-WAN) と vEdge (Viptela OS) のコマンド相違:** CLI 形式が完全に異なり、cEdge では `show sdwan ...` を使用（vEdge では `show control ...`）。
* **VPN 0 / VPN 512 の特殊用途:**
  * **VPN 0:** Transport ネットワーク専用。データパケットのルーティングテーブルとしては利用不可。
  * **VPN 512:** Out-of-Band Management (OOB) 専用。
* **オーバーレイ MTU 制限:** IPsec (ESP) ＋ VXLAN などの重複カプセル化により最大 73 バイトのヘッダーが付加されるため、Transport WAN ポートでは **MTU 1500 以上 (推奨 2000 / Jumbo Frame)** または PMTU Discovery 有効化が必要。

---

## 🔄 他技術との関連

* **1.5 BGP / 1.4 OSPF (Service Side Routing):** Service VPN (VPN 1-511) 内で LAN 側ルータと BGP/OSPF を稼働させ、`omp redistribute` により OMP へ動的再配送。
* **2.1 Cisco SD-Access (SDA-SDWAN Handoff):** SD-Access ファブリックの Border Node と SD-WAN cEdge を統合し、SDA VN (Virtual Network) ⇔ SD-WAN Service VPN マッピングおよび SGT (Security Group Tag) 保持転送。
* **3.3 DMVPN / IPsec:** DMVPN Phase 3 網からの SD-WAN への段階的移行（Co-existence デザイン）。

---

## 🧩 比較表

### 1. Cisco SD-WAN コンポーネント役割比較

| コンポーネント | プレーン | 役割 | 冗長化方式 |
| :--- | :--- | :--- | :--- |
| **vManage** | Management | GUI 管理、テンプレート作成、ポリシー定義、アラーム監視 | Active/Standby または Cluster |
| **vSmart** | Control | OMP ルート集約、セントラルポリシー計算、鍵配布 | Active/Active メッシュ |
| **vBond** | Orchestration | 初期認証、NAT 検出 (STUN)、IP/Port 情報開示 | Active/Active 複数指定 |
| **cEdge / vEdge** | Data | データパケット暗号化転送、BFD 回線測定、ローカルポリシー | Dual-Edge / VRRP / TLOC Ext |

---

## 💡 ベストプラクティス

1. **Dual WAN Edge 拠点における TLOC Extension 構成:**
   * 各 Edge が片側の WAN 回線（例: WAN-Edge-1 は Internet のみ、WAN-Edge-2 は MPLS のみ）しか収容していない場合、Edge 相互間を L2 サブインターフェイスで結び `tloc-extension` を設定。両 Edge が両方の Transport 回線をクロス利用可能とし、単一障害点（SPOF）を排除する。
2. **OMP ルーティングループ防止 (`originator-id` & `as-path`):**
   * Service Side で BGP / OSPF 相互再配送を行う場合、vSmart / Edge 上でタグ（Tag）や BGP AS-Path を保持させ、再配送ルーティングループを防止する。

---

## 📝 ラボ学習・設定サンプル例

### 1. cEdge VPN 0 (Transport) ＋ OMP ピアリング設定
* **問題:** cEdge11 にて Transport VPN 0 の設定を行い、vSmart との OMP セッションを樹立せよ。
* **要件:**
  * System IP: `10.255.255.11`
  * Site ID: `110`
  * Transport 物理ポート: `GigabitEthernet1` (IP: `192.168.11.2/24`, GW: `192.168.11.1`)
  * Color: `biz-internet`
* **設定例:**
```bash
system
 system-ip 10.255.255.11
 site-id 110
 organization-name "CCIE-EI-LAB-SDWAN"
 vbond 192.168.1.100
!
sdwan
 interface GigabitEthernet1
  tunnel-interface
   encapsulation ipsec
   color biz-internet
   allow-service all
  exit
 exit
exit

interface GigabitEthernet1
 description WAN-TRANSPORT
 ip address 192.168.11.2 255.255.255.0
 no shutdown
exit

ip route vpn 0 0.0.0.0 0.0.0.0 192.168.11.1
```
* **検証方法:** `show sdwan control connections` で vSmart / vManage との接続状態が `CRTTD` (Connected) であることを確認。

---

### 2. Service VPN 10 ＋ OSPF 動的ルーティング統合
* **問題:** cEdge11 の Service VPN 10 側で OSPF Area 0 を有効化し、LAN 側経路を OMP へ動的再配送せよ。
* **要件:**
  * Interface: `GigabitEthernet2` (IP: `10.11.10.1/24`, VRF 10)
  * OSPF Process: `10`
  * OMP への OSPF 再配送を有効化
* **設定例:**
```bash
vrf definition 10
 rd 10:10
 address-family ipv4
  exit-address-family
exit

interface GigabitEthernet2
 vrf forwarding 10
 ip address 10.11.10.1 255.255.255.0
 ip ospf 10 area 0
 no shutdown
exit

router ospf 10 vrf 10
 router-id 10.255.255.11
 redistribute omp
exit

sdwan
 omp
  address-family ipv4
   advertise ospf external
   advertise connected
  exit
 exit
exit
```
* **検証方法:** `show sdwan omp routes` および対向ルータでの `show ip route vrf 10` で OSPF 経由の OMP ルート学習を確認。

---

### 3. Service VPN 20 ＋ BGP ピアリング統合
* **問題:** Service VPN 20 側で 対向 LAN ルータ (AS 65001) と BGP ピアリングを組み、互いにルートを交換せよ。
* **設定例:**
```bash
vrf definition 20
 rd 20:20
 address-family ipv4
  exit-address-family
exit

interface GigabitEthernet3
 vrf forwarding 20
 ip address 10.11.20.1 255.255.255.0
 no shutdown
exit

router bgp 65110
 bgp log-neighbor-changes
 address-family ipv4 vrf 20
  neighbor 10.11.20.2 remote-as 65001
  neighbor 10.11.20.2 activate
  redistribute omp
 exit-address-family
exit

sdwan
 omp
  address-family ipv4
   advertise bgp
  exit
 exit
exit
```
* **検証方法:** `show ip bgp vrf 20 summary` および `show sdwan omp routes` で BGP ルートの相互交換を確認。

---

### 4. TLOC Preference による優先 WAN 回線制御
* **Problem:** cEdge11 に `biz-internet` (Color) と `mpls` (Color) の 2 つの WAN 回線が存在する。アウトバウンドのデフォルト優先度を `mpls` 回線へ寄せよ。
* **要件:**
  * `mpls` TLOC Preference: `200`
  * `biz-internet` TLOC Preference: `100`
* **設定例:**
```bash
sdwan
 interface GigabitEthernet1
  tunnel-interface
   color biz-internet
   tloc-preference 100
  exit
 exit
 interface GigabitEthernet4
  tunnel-interface
   color mpls
   tloc-preference 200
  exit
 exit
exit
```
* **検証方法:** 対向 Edge 上で `show sdwan omp tlocs` を実行し、`10.255.255.11` の `mpls` TLOC の Preference 値が `200` で受信されていることを確認。

---

### 5. Centralized Control Policy による Hub-and-Spoke トポロジー強制
* **問題:** 全 Spoke 拠点間の直接 IPsec トンネル確立を禁止し、すべての通信を Hub 拠点 (`10.255.255.1`) 経由に強制せよ。
* **要件 (vSmart Centralized Policy):**
  * Spoke 向け TLOC の受信用 Route-Map / Policy で、TLOC の Next-Hop アドレスを Hub の TLOC IP へ書き換え。
* **設定例 (vSmart Policy):**
```bash
policy
 lists
  site-list SPOKES
   site-id 200-299
  !
  tloc-list HUB_TLOC
   tloc 10.255.255.1 color mpls encap ipsec
  !
 !
 control-policy HUB_AND_SPOKE_POLICY
  sequence 10
   match route
    site-id 200-299
   !
   action accept
    set tloc-list HUB_TLOC
   !
  !
  default-action accept
 !
!
apply-policy
 site-list SPOKES
  control-policy HUB_AND_SPOKE_POLICY out
 !
!
```
* **検証方法:** Spoke 上で `show sdwan ipsec inbound-connections` を確認し、対向 TLOC が Hub 拠点のみになっていることを検証。

---

### 6. Application-Aware Routing (AAR) による Voice トラフィック最適化
* **問題:** DSCP EF (Voice) トラフィックに対し、遅延 100ms / パケットロス 1% 未満を満たす最高品質回線を動的選択させよ。
* **設定例 (vSmart Policy):**
```bash
policy
 sla-class VOICE_STRICT
  latency 100
  loss 1
  jitter 20
 !
 app-route-policy AAR_VOICE
  vpn-list ALL_SERVICE_VPNS
   sequence 10
    match
     dscp 46
    !
    action
     sla-class VOICE_STRICT preferred-color mpls biz-internet
    !
   !
  !
 !
!
```
* **検証方法:** cEdge 上で `show sdwan app-route statistics` を確認し、SLA 違反（SLA Violation）発生時の TLOC スイッチング動作を検証。

---

### 7. Direct Internet Access (DIA) ローカルブレイクアウト構成
* **問題:** 拠点 cEdge の Service VPN 10 からの 0.0.0.0/0 通信を、Transport VPN 0 の Internet 回線から直接 NAT インターネット送信させよ。
* **設定例:**
```bash
! --- Transport 側 NAT 設定 ---
sdwan
 interface GigabitEthernet1
  tunnel-interface
   color biz-internet
   allow-service all
  exit
  nat
  exit
 exit
exit

! --- Service VPN 10 側でのデフォルトルート漏れ出し ---
ip route vpn 10 0.0.0.0 0.0.0.0 vpn 0
```
* **検証方法:** Service VPN 10 内の端末から `ping 8.8.8.8` を実行し、`show ip nat translations` で NAT 変換エントリーを確認。

---

### 8. Dual-Edge 拠点における TLOC Extension 構成
* **問題:** cEdge11 (Internet 収容) と cEdge12 (MPLS 収容) 相互間を Gi3 (L2 接続) で結び、cEdge11 から cEdge12 の MPLS 回線をクロス利用可能にせよ。
* **設定例 (cEdge11 側):**
```bash
! --- TLOC Extension 受信インターフェイス ---
interface GigabitEthernet3
 description *** TLOC Extension to cEdge12 ***
 ip address 192.168.112.1 255.255.255.252
 no shutdown
exit

sdwan
 interface GigabitEthernet3
  tloc-extension-for GigabitEthernet1
 exit
exit
```
* **検証方法:** `show sdwan control connections` を実行し、cEdge11 が `mpls` (TLOC Ext 経由) と `biz-internet` の両方で Control Connection を確立していることを確認。

---

### 9. Dynamic On-Demand IPsec Tunnels
* **問題:** Spoke 拠点間において常時 IPsec トンネルを張らず、データ通信発生時のみ動的に IPsec トンネルをオンデマンド生成せよ。
* **設定例:**
```bash
sdwan
 omp
  on-demand enable
  on-demand idle-timeout 10
 exit
exit
```
* **検証方法:** 通信未発生時に `show sdwan ipsec inbound-connections` でトンネルが消去され、Ping 送信と同時にトンネルが動的生成されることを確認。

---

### 10. Service Chaining (Firewall 挿入) 構成
* **問題:** Spoke 間通信のすべてのトラフィックを、Hub 拠点に設置された Firewall (Service FW) へ迂回（Service Chaining）させよ。
* **設定例 (Hub 拠点 cEdge / vSmart):**
```bash
! --- Hub cEdge 側での Service 定義 ---
sdwan
 service FW vpn 10 landing-interface GigabitEthernet4
exit

! --- vSmart 側 Centralized Policy での Service Route 広告 ---
policy
 control-policy SERVICE_CHAINING
  sequence 10
   match route
    vpn 10
   !
   action accept
    set service FW tloc 10.255.255.1 color mpls encap ipsec
   !
  !
 !
!
```
* **検証方法:** Spoke 上で `show sdwan omp services` を実行し、`Service FW` が Hub TLOC に紐づいて学習されていることを確認。

---

## ❓ 想定試験問題

### Q1. 【トラブルシューティング】
**問題:** cEdge11 を追加プロビジョニングしたが、vBond とのコントロールセッション確立直後に `%SDWAN-3-CONTROL_ERR` が発生し、vSmart との OMP セッションが樹立できない。`show sdwan control local-properties` の出力結果の一部を以下に示す。原因と対策を答えよ。
```text
certificate-status     VALID
org-name               "CCIE-LAB-SDA"
vbond-ip               192.168.1.100
```
なお、vSmart 側の `organization-name` は `"CCIE-EI-LAB-SDWAN"` と定義されている。

* **回答:**
  * **原因:** cEdge11 と vSmart / vBond 間で `organization-name` の文字列（`"CCIE-LAB-SDA"` vs `"CCIE-EI-LAB-SDWAN"`）が不一致であるため、証明書ハンドシェイク時の組織名照合で弾かれている。
  * **対策:** cEdge11 の `system` ブロック内にて `organization-name "CCIE-EI-LAB-SDWAN"` と修正・変更する。

---

### Q2. 【コンフィグ読解・設計】
**問題:** 以下の vSmart 用 Centralized Data Policy コンフィグを読み解き、動作結果として正しい説明を選べ。
```bash
policy
 data-policy AAR_POL
  vpn-list VPNS
   sequence 10
    match
     dscp 46
    !
    action
     sla-class VOICE preferred-color mpls
    !
   !
  !
 !
!
```
1. DSCP 46 のパケットは、SLA 条件にかかわらず常に `mpls` 回線のみを強制使用する。
2. DSCP 46 のパケットは、`mpls` 回線が `VOICE` SLA 条件を満たしている場合は `mpls` を選択し、満たさない場合は他利用可能 Color へフェイルオーバーする。
3. DSCP 46 以外のパケットはすべてドロップされる。

* **回答:** **2**
  * **解説:** `preferred-color mpls` は、SLA 条件を通過している間は `mpls` を優先使用し、`mpls` が SLA 違反した場合は SLA を満たす別の Color (例: `biz-internet`) へ動的切り替え（フェイルオーバー）を行う。なお、明示的な `default-action accept` がない場合、デフォルトデータポリシーは Accept となる。

---

### Q3. 【実装・デザイン】
**問題:** 拠点内に 2 台の cEdge (cEdge1, cEdge2) が存在し、cEdge1 は MPLS 回線、cEdge2 は Internet 回線に接続されている。cEdge1 がダウンした場合でも cEdge2 から MPLS 回線を利用できるようにするための構成技術名を答えよ。

* **回答:** **TLOC Extension (TLOC エクステンション)**
  * **解説:** 両 cEdge 間を L2 クロスコネクト（サブインターフェイス）で接続し、`tloc-extension-for` コマンドを設定することで、相手側の物理 WAN リンクを仮想的に自機の TLOC として拡張・利用可能にする。

---

### Q4. 【OMP ベストパス選定】
**問題:** vSmart が同一プレフィックスに対して複数の OMP ルートを受信した場合、最優先で比較される属性項目を正しい順番で並べよ。
(A) TLOC Preference
(B) OMP Preference
(C) Lowest System IP
(D) Origin Protocol Metric

* **回答:** **(B) OMP Preference ➔ (A) TLOC Preference ➔ (D) Origin Protocol Metric ➔ (C) Lowest System IP**

---

### Q5. 【トラブルシューティング】
**問題:** DIA (Direct Internet Access) を設定したが、Service VPN 10 のクライアントからインターネット上の外部 Web サーバー宛ての通信が疎通しない。`show ip nat translations` を実行しても変換エントリーが表示されない。考えられる設定漏れを 2 点挙げよ。

* **回答:**
  1. Transport VPN 0 側の物理 WAN インターフェイス直下（`sdwan` 構造内）で `nat` 機能が有効化されていない。
  2. Service VPN 10 内でデフォルトルート漏れ出し (`ip route vpn 10 0.0.0.0 0.0.0.0 vpn 0`) が設定されていない、または Centralized Data Policy で `nat use-vpn 0` アクションが設定されていない。

---

## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Configuration Guide](https://www.cisco.com/c/en/us/support/routers/sd-wan/products-installation-and-configuration-guides-list.html)
* [Cisco SD-WAN Command Reference](https://www.cisco.com/c/en/us/support/routers/sd-wan/products-command-reference-list.html)
* [Cisco Live: BRKCRS-2110 - Cisco SD-WAN Architecture & Deployment](https://www.ciscolive.com/)
* [Cisco Validated Design (CVD): SD-WAN End-to-End Design Guide](https://www.cisco.com/c/en/us/solutions/design-zone/wan-design-guides.html)
* [Cisco Technical Notes: Troubleshooting SD-WAN Control Connections](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)

---

## 📝 補足（Notes）

* **vManage GUI ワークフローと CLI のマッピング:**
  * vManage 上で定義する **Feature Template** は、cEdge / IOS-XE における個別 CLI 設定ブロック（`system`, `sdwan`, `interface`, `vrf` 等）を視覚的に生成するための抽象化レイヤーです。
  * CCIE EI ラボ試験では、vManage GUI 上での Template 操作および cEdge 上での CLI ダイレクト設定・トラブルシューティング双方のスキルが要求されます。
