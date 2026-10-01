---
layout: default
title: 2.1.b-Overlay
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 2
---

# 2.1.b Overlay

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 項目 **2.1.b Overlay (LISP/BGP Control Plane, VXLAN Data Plane, Cisco TrustSec Policy Plane, L2 Flooding, Native Multicast)** について、Cisco Catalyst Center (旧 Cisco DNA Center) 2.3.x、Cisco ISE 3.x、および Cisco IOS-XE 17.x の実装仕様に基づき、CCIE EI ラボ試験に完全対応するレベルで解説します。

---

## 📘 概要

Cisco SD-Access (Software-Defined Access) における **Overlay（オーバーレイ）** とは、物理トポロジー（Underlay）の上に論理的に構築される仮想化ネットワーク層です。アンダーレイの IP 接続性（IS-IS/OSPF 等）を利用して、端末（Endpoint）の IP/MAC 情報をカプセル化し、物理位置（RLOC）から動的に切り離して柔軟な Layer 2 / Layer 3 延伸および高度なセキュリティポリシーを実現します。

### 構成要素と適用目的
1. **2.1.b (i) Control Plane (LISP / BGP EVPN):**
   * **LISP (Locator/ID Separation Protocol):** EID (Endpoint Identifier: 端末 IP/MAC) と RLOC (Routing Locator: スイッチの Loopback0) を切り離し、Map-Server/Map-Resolver (MS/MR) を介して動的マッピングを管理します。
   * **BGP EVPN (Border ピアリング / WAN 統合):** SD-Access ファブリック外部（SD-WAN、MPLS VPN、Fusion Router）とのルーティング情報交換や、Border 間の制御プレーン同期に BGP (Address-Family L2VPN EVPN / VPNv4) を利用します。
2. **2.1.b (ii) Data Plane (VXLAN-GPO):**
   * **VXLAN (Virtual Extensible LAN) with Group-Based Policy Option (GPO):** UDP ポート 4789 でデータパケットをカプセル化します。従来の 12-bit VLAN (4,094) を超える 24-bit VNI (Virtual Network Identifier: 1,600万) と、16-bit SGT (Security Group Tag) をヘッダー内に保持します。
3. **2.1.b (iii) Policy Plane (Cisco TrustSec / CTS):**
   * SGT (Security Group Tag) によるアイデンティティベースのアクセス制御を実施します。IP アドレスに依存せず、ロールベースの SGACL (Security Group Access Control List) を受信用 Edge スイッチ（Egress Enforcement）で適用します。
4. **2.1.b (iv) L2 Flooding (Head-End Replication / Multicast):**
   * ファブリック内での ARP / ブロードキャスト / マルチキャスト / 未知のユニキャスト (BUM トラフィック) の転送メカニズムです。Ingress Replication (Head-End Replication) または Underlay Native Multicast を選択します。
5. **2.1.b (v) Native Multicast (Overlay Multicast):**
   * アンダーレイの PIM-SSM (`232.0.0.0/8`) を利用して、オーバーレイ上のマルチキャストトラフィック (224.0.0.0/4) を効率的にマルチキャストカプセル化して複製・転送します。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **Control Plane プロトコル** | LISP (RFC 6830 / RFC 9301) [内包 EID マッピング], MP-BGP (EVPN/VPNv4) [外部統合] |
| **Data Plane プロトコル** | VXLAN-GPO (UDP Port 4789, 外側 IP ヘッダー + VXLAN ヘッダー + SGT) |
| **Policy Plane アーキテクチャ** | Cisco TrustSec (CTS) - SGT (16-bit, 1〜65535) による Egress フィルタリング |
| **L2 Flooding 方式** | Head-End Replication (Ingress Replication: ユニキャスト複製) または Underlay Multicast (PIM-SSM) |
| **Overlay Multicast** | Underlay PIM-SSM へのマッピング (`232.x.x.x`) による効率的マルチキャスト転送 |
| **主要ヘッダーオーバーヘッド** | VXLAN カプセル化による +50 バイト（アンダーレイ MTU 9100/9216 バイト要） |
| **対応ハードウェア** | Cisco Catalyst 9300 / 9400 / 9500 / 9600 シリーズ, Catalyst 8000 シリーズ |
| **設計上の注意点** | MS/MR 冗長化 (Anycast IP), SGT マッピングの ISE 集中同期, MTU パスミスマッチ回避 |

---

## 🏗 動作原理

### SD-Access パケットカプセル化フロー (VXLAN-GPO)

パケットが Fabric Edge に着信してから、オーバーレイを経由して対向 Fabric Edge で復号されるまでのデータフロー構造は以下の通りです。

```text
[ Endpoint A (EID: 10.1.1.10, SGT: 4) ]
                   │
                   ▼ (1. 802.1X/MAB 認証 ＆ SGT=4 付与)
[ Fabric Edge 1 (RLOC: 192.168.10.1) ]
                   │
                   ▼ (2. LISP Map-Cache ルックアップ → MS/MR へ Map-Request または LISP キャッシュ使用)
                   │
                   ▼ (3. VXLAN-GPO カプセル化: Outer IP src=192.168.10.1, dst=192.168.10.2, VNI=4097, SGT=4)
[ Underlay IP Network (IS-IS / OSPF, MTU 9100) ]
                   │
                   ▼ (4. アンダーレイ L3 ルーティング転送)
[ Fabric Edge 2 (RLOC: 192.168.10.2) ]
                   │
                   ▼ (5. VXLAN 解除, SGT=4 抽出)
                   │
                   ▼ (6. SGACL チェック: SGT=4 -> SGT=5 [Permit/Deny])
[ Endpoint B (EID: 10.1.1.20, SGT: 5) ]
```

---

## ⚙ 動作シーケンス

### 1. Control Plane (LISP EID-to-RLOC 登録と解決)
1. **EID 検出 & 登録:** エンドポイントが Fabric Edge (FE) に接続すると、802.1X/MAB または ARP/DHCP により検出されます。FE は LISP `Map-Register` メッセージを Control Plane Node (MS/MR) に送信し、`EID (10.1.1.10) <-> RLOC (192.168.10.1)` のマッピングを登録します。
2. **Map-Request / Map-Reply:** FE1 が宛先 EID (10.1.1.20) 宛のパケットを受信すると、自身の Map-Cache を確認します。キャッシュにない場合、MS/MR へ `Map-Request` を送信します。
3. **Map-Reply 応答:** MS/MR は宛先 FE2 (192.168.10.2) へ転送するか、直接 `Map-Reply` を FE1 へ返答します。FE1 は Map-Cache を更新します。

### 2. Policy Plane (SGT 挿入と Egress Enforcement)
1. **SGT 設定 (Ingress):** 送信元 FE1 は ISE から動的に取得した、またはポートに静的バインドされた SGT (例: SGT 4 = Employees) を VXLAN-GPO ヘッダーの 16-bit 拡張フィールドに挿入します。
2. **SGACL 適用 (Egress):** 宛先 FE2 は VXLAN パケットを非カプセル化し、送信元 SGT (SGT 4) と宛先 EID の SGT (SGT 5 = Servers) を抽出します。FE2 のハードウェア TCAM に保持された SGACL マトリクス（例: `role-based permissions default`）を参照し、転送許可またはドロップを判定します。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
* **LISP MS/MR の CLI 構成:** Catalyst Center による自動構成だけでなく、CLI で `router lisp` 配下の `site`, `eid-table`, `map-server`, `map-resolver` を正確に判読・修正できること。
* **VXLAN-GPO の構造理解:** `show nwk-clm` や `show interface nvi1` 等による VXLAN インターフェイスの状態監査。
* **Cisco TrustSec (CTS) CLI 設定:** `cts role-based enforcement`, `cts role-based sgacl-permission`, `cts-sxp` (SXP ピアリング) のトラブルシューティング。
* **L2 Flooding 設定の使い分け:** `broadcast-underlay` (Multicast) vs `head-end-replication` の比較と制限事項。

### よくある設定ミス・落とし穴
1. **`cts role-based enforcement` の欠落:** Fabric Edge でコマンドが有効化されていないと、SGACL ポリシーが完全に無視され、全トラフィックが許可されてしまう。
2. **Underlay MTU の調整不足:** VXLAN カプセル化による +50 バイトのオーバーヘッドを考慮せず、アンダーレイポートの MTU が 1500 バイトのままだと、パケットフラグメンテーションやドロップが発生する。
3. **LISP Instance-ID と VNI のミスマッチ:** L3 VNI / L2 VNI と LISP `instance-id` の設定数値が一致していない場合、マッピング登録に失敗する。
4. **SXP (SGT Exchange Protocol) 接続エラー:** タグ非対応機器との統合時に SXP ピアのパスワードやソース IP が一致しておらず、SGT IP-SGT マッピングが伝搬しない。

---

## 🛠 設定方法

### CLI による Manual SD-Access Overlay 設定例

#### 1. Control Plane Node (LISP MS/MR) 設定
```bash
!
router lisp
 site FABRIC-SITE
  authentication-key Cisco123!
  eid-record 10.1.0.0/16 instance-id 4097
  eid-record 10.2.0.0/16 instance-id 4098
  exit
 !
 ipv4 map-server
 ipv4 map-resolver
 !
 instance-id 4097
  service ipv4
   eid-table vrf VN_Corp
   map-resolver
   map-server
  exit
 !
 instance-id 4098
  service ipv4
   eid-table vrf VN_Guest
   map-resolver
   map-server
  exit
!
```

#### 2. Fabric Edge Node (LISP ITR/ETR & VXLAN-GPO) 設定
```bash
!
vrf definition VN_Corp
 rd 65001:4097
 address-family ipv4
  route-target export 65001:4097
  route-target import 65001:4097
 exit-address-family
!
interface Loopback0
 description RLOC-IP
 ip address 192.168.10.1 255.255.255.255
!
router lisp
 locator-set FABRIC-RLOC
  192.168.10.1 priority 1 weight 100
 exit
 !
 instance-id 4097
  service ipv4
   eid-table vrf VN_Corp
   itr map-resolver 192.168.10.254
   etr map-server 192.168.10.254 key Cisco123!
   etr
   itr
  exit
!
! VXLAN-GPO NVI (Network Virtual Interface)
interface nvi1
 mac-address 0000.0c9f.f001
 ip address 10.1.1.1 255.255.255.0
 locator-set FABRIC-RLOC
!
```

#### 3. Policy Plane (Cisco TrustSec / SGACL) 設定
```bash
!
cts logging verbose
cts role-based enforcement
!
! SGT 静的・動的マッピング例
cts role-based sgt-map 10.1.1.100 sgt 4
!
! SGACL 定義
ip access-list role-based DENY-EMPLOYEE-TO-SERVER
 10 deny ip
!
cts role-based permissions default permit ip
cts role-based permissions from 4 to 5 DENY-EMPLOYEE-TO-SERVER
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| LISP マッピングキャッシュの確認 | <code>show lisp instance-id 4097 ipv4 map-cache</code> |
| LISP 登録 EID の確認 (MS/MR 上) | <code>show lisp site instance-id 4097</code> |
| LISP サービスのステータス確認 | <code>show lisp service ipv4</code> |
| VXLAN NVI 状態確認 | <code>show interface nvi1</code> |
| Cisco TrustSec 役割ベース ACL 適用確認 | <code>show cts role-based permissions</code> |
| SGT 役割ベースカウンター確認 | <code>show cts role-based counters</code> |
| IP-to-SGT マッピングテーブルの確認 | <code>show cts role-based sgt-map all</code> |
| LISP デバッグメッセージの実行 | <code>debug lisp control-plane</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| オーバーレイ間の通信不可 | LISP EID マッピング未登録 | <code>show lisp instance-id <ID> ipv4 map-cache</code> | FE - MS/MR 間の Key または IP 疎通を確認 |
| パケットが Egress Edge で破棄される | SGACL によるドロップ (Policy Enforcement) | <code>show cts role-based counters</code> | ISE の Egress Policy またはローカル SGACL を確認 |
| BUM トラフィックが対向 Edge に届かない | Head-End Replication または L2 Flooding 未設定 | <code>show lisp instance-id <ID> ethernet server</code> | `broadcast-underlay` または Head-End リストを調整 |
| VXLAN パケットがアンダーレイで破棄される | MTU サイズオーバー (VXLAN +50B) | <code>ping <RLOC> size 8900 df-bit</code> | 全アンダーレイポートで `system mtu 9100` を設定 |
| SGT が相手 Edge に伝搬しない | VXLAN カプセル化時に SGT (GPO) が抜けている | <code>show cts interface</code> | インターフェイス上で CTS / VXLAN-GPO が正しく動作しているか確認 |

---

## ⚠ 制限事項

* **ハードウェア TCAM 制約:** SGACL エントリ数はスイッチの Hardware TCAM リソースに依存します。多大な SGT マトリクスは TCAM 枯渇を引き起こす可能性があります。
* **L2 Flooding スケール:** Head-End Replication (HER) はユニキャスト複製のため、多数の Fabric Edge が存在する大規模ファブリックでは帯域消費が増大します。大容量 BUM 環境では Native Multicast (PIM-SSM) が推奨されます。
* **SXP ピアリングホップ制限:** SXP は TCP 上で動作しますが、多数のホップを経由した SGT 動的同期は更新遅延が生じる場合があります。

---

## 🔄 他技術との関連

* **IS-IS / OSPF (Underlay):** RLOC 相互間の IP 疎通を提供する下層プロトコル。
* **Cisco ISE (Identity Services Engine):** PXGrid を介して Catalyst Center と連携し、SGT 定義および 802.1X 認証・認可ポリシーを集中配備。
* **VRF-Lite / BGP (Fusion Router):** ファブリックの外部境界において、VN (Virtual Network) 間のルーティング隔離および共通サービス (DHCP/DNS) へのルートリーキングを制御。

---

## 🧩 比較表

| 項目 | Head-End Replication (HER) | Native Multicast (Overlay Multicast) |
| --- | --- | --- |
| **アンダーレイ要求** | L3 IP ルーティングのみ（PIM 不要） | アンダーレイでの PIM-SSM (`232.0.0.0/8`) 必須 |
| **複製ポイント** | 送信元 Fabric Edge (Ingress) で個別複製 | アンダーレイのルータ群で最適複製 |
| **帯域効率** | Edge 数が増えると多重送信により低下 | 非常に高い (効率的) |
| **推奨環境** | 小〜中規模ファブリック, 簡略化設計 | 大規模ファブリック, L2 BUM / マルチキャスト多用環境 |

---

## 💡 ベストプラクティス

1. **Control Plane 冗長化:** MS/MR は必ず 2 台以上のノードで構成し、Anycast IP またはデュアル Map-Server 設定を導入してください。
2. **Underlay MTU 設計:** ファブリック内のすべての物理ポートおよび ECMP パスで `system mtu 9100` 以上を厳格に適用してください。
3. **SGACL Default Policy:** 移行期は `cts role-based permissions default permit ip` とし、モニタリングモードで動作確認後に閉塞ポリシーへ移行してください。

---

## 📝 ラボ学習・設定サンプル例

### 問題 1: LISP Control Plane (MS/MR) の構成
* **要件:** MS/MR ルータ上で IPv4 EID 範囲 `10.10.0.0/16` (Instance-ID 4097) のマッピング要求を受領できるように構成せよ。認証キーは `Cisco123!` とすること。
* **設定例:**
```bash
router lisp
 site FABRIC-SITE
  authentication-key Cisco123!
  eid-record 10.10.0.0/16 instance-id 4097
  exit
 !
 ipv4 map-server
 ipv4 map-resolver
 !
 instance-id 4097
  service ipv4
   eid-table vrf VN_CORP
   map-resolver
   map-server
  exit
!
```
* **検証:** `show lisp site instance-id 4097` で登録サイトおよび認証キーがアクティブであることを確認。

### 問題 2: Fabric Edge での LISP ITR/ETR 設定
* **要件:** Fabric Edge1 上で RLOC IP `192.168.10.1` を使用し、MS/MR `192.168.10.254` へ EID 情報を動的登録せよ。
* **設定例:**
```bash
router lisp
 locator-set RLOC-SET
  192.168.10.1 priority 1 weight 100
 exit
 !
 instance-id 4097
  service ipv4
   eid-table vrf VN_CORP
   itr map-resolver 192.168.10.254
   etr map-server 192.168.10.254 key Cisco123!
   etr
   itr
  exit
!
```
* **検証:** `show lisp instance-id 4097 ipv4 map-cache` でエントリが正しく保持されているか確認。

### 問題 3: Cisco TrustSec (CTS) 役割ベースアクセスコントロールの設定
* **要件:** SGT 4 (Employee) から SGT 5 (Server) への Web 通信 (TCP 80/443) のみを許可し、その他の通信を拒否する SGACL を設定せよ。
* **設定例:**
```bash
ip access-list role-based SGACL-EMP-TO-SRV
 10 permit tcp any any eq www
 20 permit tcp any any eq 443
 30 deny ip
!
cts role-based enforcement
cts role-based permissions from 4 to 5 SGACL-EMP-TO-SRV
!
```
* **検証:** `show cts role-based permissions` を実行し、SGT 4 -> 5 に ACL がバインドされていることを確認。

### 問題 4: SGT 静的マッピング (IP-to-SGT)
* **要件:** IP アドレス `10.10.10.50` に静的に SGT 10 (Contractor) を割り当てよ。
* **設定例:**
```bash
cts role-based sgt-map 10.10.10.50 sgt 10
!
```
* **検証:** `show cts role-based sgt-map all` で IP と SGT 10 のマッピングが表示されることを確認。

### 問題 5: Head-End Replication (HER) による L2 Flooding 設定
* **要件:** L2 VNI 10097 の BUM トラフィックを対向 Edge `192.168.10.2` へ Head-End Replication するよう設定せよ。
* **設定例:**
```bash
router lisp
 instance-id 8192
  service ethernet
   eid-table vlan 10
   flood-to-router 192.168.10.2
  exit
!
```
* **検証:** `show lisp instance-id 8192 ethernet` で flood-list に対向 RLOC が登録されていることを確認。

### 問題 6: Native Multicast (Overlay Multicast) のアンダーレイ PIM-SSM マッピング
* **要件:** オーバーレイマルチキャストをアンダーレイの PIM-SSM グループ `232.1.1.1` を使用して配送せよ。
* **設定例:**
```bash
router lisp
 instance-id 4097
  service ipv4
   encapsulation vxlan
   destination-sampling core-multicast 232.1.1.1
  exit
!
```
* **検証:** `show ip mroute 232.1.1.1` でアンダーレイマルチキャストツリーが生成されていることを確認。

### 問題 7: SXP (SGT Exchange Protocol) スピーカーの設定
* **要件:** 接続先の非ファブリックルータ `192.168.100.2` に対して SXP セッション（Password: `Secret123`）を確立し、SGT マッピングを送信（Speaker）せよ。
* **設定例:**
```bash
cts sxp enable
cts sxp default source-ip 192.168.10.1
cts sxp connection peer 192.168.100.2 password default mode local speaker
!
```
* **検証:** `show cts sxp connections` で Status が `On` になっていることを確認。

### 問題 8: VXLAN NVI (Network Virtual Interface) の手動設定と診断
* **要件:** NVI インターフェイス 1 を作成し、VRF VN_CORP にバインドせよ。
* **設定例:**
```bash
interface nvi1
 vrf forwarding VN_CORP
 ip address 10.10.10.1 255.255.255.0
 locator-set RLOC-SET
!
```
* **検証:** `show interface nvi1` で Protocol UP を確認。

### 問題 9: VRF 間の SGT 透過設定
* **要件:** VRF 跨ぎのルーティング発生時に SGT タグを保持して転送するよう構成せよ。
* **設定例:**
```bash
cts role-based enforcement
vrf definition VN_CORP
 address-family ipv4
  cts role-based enforcement
 exit-address-family
!
```
* **検証:** `show vrf detail VN_CORP` で CTS 有効化を確認。

### 問題 10: LISP Dynamic EID (Host Dynamic Registration) の設定
* **要件:** インターフェイス GigabitEthernet1/0/1 に接続するホストを動的に LISP EID として検出・登録せよ。
* **設定例:**
```bash
interface GigabitEthernet1/0/1
 switchport mode access
 switchport access vlan 10
 ip device tracking maximum 10
!
router lisp
 instance-id 8192
  service ethernet
   eid-table vlan 10
   dynamic-eid DYN-HOSTS
    database-mapping 10.10.10.0/24 locator-set RLOC-SET
   exit-dynamic-eid
  exit
!
```
* **検証:** `show lisp instance-id 8192 dynamic-eid` で動的検出端末を確認。

---

## ❓ 想定試験問題

### 質問 1 (コンフィグ読解)
**問題:** Fabric Edge にて以下のコンフィグを適用したが、受信側で SGT に基づくアクセスの制御が機能しない。原因として最も適切なものを選べ。
```bash
cts role-based permissions from 4 to 5 DENY-ALL
ip access-list role-based DENY-ALL
 10 deny ip
```
* A) `cts role-based sgt-map` が設定されていないため。
* B) グローバルで `cts role-based enforcement` コマンドが設定されていないため。
* C) LISP プロセス配下で `service ipv4` が無効化されているため。
* D) VXLAN の VNI 番号が不一致であるため。

**正解:** **B**
**解説:** Cisco TrustSec で SGACL によるドロップ処理を行うには、グローバルで `cts role-based enforcement` を明示的に適用する必要があります。これが欠落していると、SGACL 設定が存在してもポリシー評価がバイパスされます。

### 質問 2 (トラブルシューティング)
**問題:** Fabric Edge 間で大型データ転送を行った際、TCP パケットのドロップが多発しスループットが極端に低下する。`show interface` を確認するとドロップカウンターが増加していた。最も疑うべきアンダーレイ設定は何か？
* A) IS-IS の Hello タイマー不一致
* B) アンダーレイの MTU サイズ未拡張（1500 バイトのまま）
* C) LISP の Dead タイマー超過
* D) BGP EVPN ピアのダウン

**正解:** **B**
**解説:** VXLAN-GPO カプセル化は Outer IP / UDP / VXLAN / GPO ヘッダーにより約 +50 バイトのオーバーヘッドを付加します。アンダーレイが MTU 1500 のままで DF (Don't Fragment) ビットがセットされている場合、パケットがフラグメントできず破棄されます。

### 質問 3 (Design)
**問題:** 50 台の Fabric Edge から構成される大規模ファブリックにおいて、Layer 2 の BUM (Broadcast, Unknown Unicast, Multicast) トラフィックの転送方式を設計している。帯域の無駄を最小限に抑えるために推奨されるアプローチはどれか？
* A) Head-End Replication (HER) の使用
* B) アンダーレイ PIM-SSM を使用した Native Multicast
* C) 全 Edge への Static Unicast ルーティング
* D) LISP Map-Server による BUM キャッシュ

**正解:** **B**
**解説:** HER は Ingress Fabric Edge で受信側 Edge 数分パケットをユニキャストで複製・送信するため、大規模環境では送信側 Edge とアンダーレイ帯域を著しく圧迫します。大規模な場合は Underlay Native Multicast (PIM-SSM) が最も効率的です。

### 質問 4 (実装)
**問題:** SGT タグ非対応のアクセススイッチを SD-Access ファブリックの Border スイッチへ接続し、IP アドレスに基づく SGT タグの動的伝搬を行いたい。使用すべきプロトコルはどれか？
* A) LISP
* B) VXLAN-GPO
* C) SXP (SGT Exchange Protocol)
* D) BGP EVPN

**正解:** **C**
**解説:** SXP (SGT Exchange Protocol) は、インラインで SGT タギングを行えないネットワーク機器間で、TCP セッションを介して IP-to-SGT のマッピング情報を動的に交換するためのプロトコルです。

### 質問 5 (コンフィグ診断)
**問題:** MS/MR ルータ上で `show lisp site` を実行したところ、特定 Fabric Edge からの EID 登録が `Unknown` と表示されていた。確認すべき不一致パラメーターはどれか？
* A) BGP AS 番号
* B) LISP authentication-key (認証キー)
* C) IS-IS System-ID
* D) VXLAN UDP ポート番号

**正解:** **B**
**解説:** MS/MR と Fabric Edge (ETR) 間で LISP の `authentication-key` が一致していない場合、`Map-Register` パケットが拒否され、マッピングが未登録となります。

---

## 🔗 参考リソース

* [Cisco SD-Access Solution Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/cisco-sda-design-guide.html)
* [LISP Network Architecture and Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_lisp/configuration/xe-17/iproute-lisp-xe-17-book.html)
* [Cisco TrustSec Deployment and Configuration Guide](https://www.cisco.com/c/en/us/td/docs/solutions/Enterprise/Security/TrustSec_Design_Guide/TrustSec_Deployment_Guide.html)
* [Cisco Live: SD-Access Deep Dive (BRKKOR-2011)](https://www.ciscolive.com/)
* [Cisco Catalyst Center Configuration Guide](https://www.cisco.com/c/en/us/support/cloud-systems-management/dna-center/products-installation-and-configuration-guides-list.html)

---

## 📝 補足（Notes）

* **LISP と BGP の連携:** SD-Access ファブリック内では LISP が軽量なマッピングデータベースとして動的ルックアップを担い、ファブリック外との境界（Border - Fusion Router）では BGP が VRF 単位でマルチプロトコル経路交換を担当します。
* **SGT Enforcement の位置:** SGT のポリシー評価（SGACL）は、常に**パケットの出口（Egress Fabric Edge）**で実行されます。これにより、Ingress 側では送信元の識別タグ付与のみを行い、中継アンダーレイや受信用ハードウェア TCAM の効率的活用が可能となります。


## 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076) - オーバーレイ全体のアーキテクチャ解説。
*   [**BRKCRS-2810: Cisco SD-Access Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810) - LISP と VXLAN の深いデバッグ手法。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - ラボ試験対策に特化した SDA セッション。

### Configuration ガイド
*   [**Cisco SD-Access Overlay Design Guide (CVD)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf) - LISP/VXLAN 連携の公式ドキュメント。
*   [**Configuring Cisco TrustSec on Catalyst 9000**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg/m_cts_sgt_config.html)。

### テクニカルノーツ・設定例
*   [**LISP Technology White Paper**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_lisp/configuration/xe-16/irl-xe-16-book/irl-overview.html) - EID/RLOC 分離の詳細ロジック。
*   [**VXLAN-GPO and Group-Based Policy Overview**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/16-12/configuration_guide/vxlan/b_1612_vxlan_9000_cg/m-vxlan-gpo.html)。

---

## 📝 補足
- この学習メモは、SD-Access オーバーレイが「動的な ID 管理（LISP）」、「柔軟なカプセル化（VXLAN）」、および「抽象化されたポリシー（TrustSec）」の三位一体で構成されていることを詳述しています。CCIE ラボ試験では、DNA Center の裏側で動作する **LISP 制御メッセージ** や **SGT タグの伝播状況** を CLI で正確に追跡できるかどうかが、合格のための最も重要なスキルとなります。

