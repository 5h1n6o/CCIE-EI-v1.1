---
layout: default
title: 3.2.b-L3VPN
parent: 3.2-MPLS
grand_parent: 3-Transport-Technologies-and-Solutions
nav_order: 2
---

# 3.2.b MPLS L3VPN

MPLS L3VPNは、サービスプロバイダーの共通インフラストラクチャ上で、複数の顧客に対して完全に分離されたプライベートなレイヤ3ネットワークを提供する技術です。CCIE EI v1.1の試験範囲において、このトピックはエンタープライズの拠点間接続や、SD-Access/SD-WANとレガシーネットワークの統合点（ハンドオフ）を理解する上で極めて重要な基盤となります。

---

# 3.2.b L3VPN

## 📘 概要

MPLS Layer 3 VPN（L3VPN）は、単一の共有IP/MPLSバックボーンインフラストラクチャ上で、複数のカスタマー（企業・組織・部門）に対して相互に完全に隔離された高度なL3仮想ネットワーク（VPN）を提供する技術である。

CCIE EI v1.1 Blueprintにおける `3.2.b L3VPN`、特に `3.2.b (i) PE-CE routing using BGP` および `3.2.b (ii) Basic MP-BGP VPNv4/VPNv6` は、サービスプロバイダ網や大企業プライベートバックボーンにおけるIP/MPLS制御・データプレーンの中核をなす。

* **PE-CE Routing using BGP:** サービスプロバイダ側ルータ（PE: Provider Edge）と顧客側ルータ（CE: Customer Edge）間でBGP（主にeBGP）を用いてルーティング情報を交換する手法。AS-OverrideやAllowas-in、Site-of-Origin (SOO) などのBGPループ防止・パス制御メカニズムが必須となる。
* **Basic MP-BGP VPNv4/VPNv6:** PEルータ相互間でマルチプロトコルBGP（MP-BGP）セッションを確立し、顧客の重複可能なIPv4/IPv6アドレスをRD（Route Distinguisher）によって一義化されたVPNv4/VPNv6プレフィックスとして交信・制御し、Route Target（RT）拡張コミュニティによってVRF間でのルートインポート/エクスポートを制御する技術である。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **定義・概要** | MP-BGPとMPLSラベルスイッチングを組み合わせて、マルチテナント環境下で顧客IPルーティングテーブルを論理隔離・相互接続するL3VPN技術 |
| **主な用途** | 企業WAN統合、マルチテナントデータセンター接続、同一物理インフラ上での部門・子会社ネットワークの安全な論理分離 |
| **制御プレーン構成要素** | VRF (Virtual Routing and Forwarding), RD (Route Distinguisher), RT (Route Target), MP-BGP (Address-Family vpnv4/vpnv6), eBGP PE-CE |
| **データプレーン構成要素** | 2段MPLSラベルスタック（Outer/Transport Label: LDP等、Inner/Service Label: MP-BGP割当） |
| **メリット** | 顧客側で重複したプライベートIPアドレス（RFC 1918等）の使用が可能、高度なメッシュ/ハブ＆スポークトポロジー制御、優れた拡張性（PE間のみでコントロール面維持） |
| **デメリット・課題** | 複雑なコントロールプレーン（MP-BGP/LDP/VRF）、PEルータにおけるメモリ・TCAMリソース増大、トラブルシューティング時の多層解剖が必要 |
| **対応機種** | Cisco Catalyst 9300/9400/9500/9600 シリーズ, Catalyst 8000 Edge / ISR4000 / ASR1000 シリーズ (IOS-XE 17.x) |
| **設計上の注意点** | RDの一位性確保、RT設計の体系化（Import/Exportマトリクス）、LDP-IGP同期、PE-CE BGPでのループ防止（AS-Override / Allowas-in / SOO）の厳格な設計 |

---

## 🏗 動作原理

L3VPNにおける通信および経路伝搬の基本フローを以下に示す。

### 1. 制御プレーン（Control Plane）のフロー

```
[CE-1 (AS 65001)] 
   ↓ IPv4/IPv6 Unicast Route (e.g. 10.1.1.0/24)
[PE-1 (VRF: CORP)]
   ↓ 1. VRF RIBに登録
   ↓ 2. RD (65000:100) を付与 → VPNv4 Prefix (65000:100:10.1.1.0/24) へ変換
   ↓ 3. Route Target (65000:100) 拡張コミュニティを付与
   ↓ 4. MP-BGP (VPNv4) で Inner/Service Label (e.g. 24001) を割り当て
[MP-BGP (iBGP Address-Family vpnv4)]
   ↓ Next-Hop: PE-1 Loopback0 (10.0.0.1)
[PE-2 (VRF: CORP)]
   ↓ 1. BGP VPNv4 Updateを受信
   ↓ 2. RT (65000:100) がローカルVRF CORPの Import RT と一致するか判定
   ↓ 3. RDを剥離し、IPv4 Prefix (10.1.1.0/24) に戻して VRF CORP RIBへ挿入
   ↓ 4. eBGP経由で CE-2 へアドバタイズ
[CE-2 (AS 65001)]
```

### 2. データプレーン（Data Plane）のフロー

```
[CE-2 (IP Packet: Src 10.2.2.10, Dst 10.1.1.10)]
   ↓ IP Packet (Untagged)
[PE-2]
   ↓ 1. VRF CORP CEFテーブルを参照
   ↓ 2. 2段のMPLSラベルを付与:
   ↓    - Inner/VPN Label (24001): PE-1が割り当てたVRF/Prefix識別ラベル
   ↓    - Outer/Transport Label (16005): PE-1 Loopback0 (10.0.0.1) へ達するLDP Label
[P Router (Transit LSR)]
   ↓ Outer Label (16005) を Swap または PHP (Implicit Null: 3) で剥離
[PE-1]
   ↓ Inner Label (24001) のみを受信
   ↓ Inner Label テーブル（LFIB）を参照し、VRF CORP の egress インターフェイスへIPパケットとして転送
[CE-1 (IP Packet: Src 10.2.2.10, Dst 10.1.1.10)]
```

---

## ⚙ 動作シーケンス

1. **VRFおよびアドレスファミリーの設定:** PEルータ上で `vrf definition <NAME>` を作成し、`rd` および `route-target import/export` を定義。対象インターフェイスに `vrf forwarding <NAME>` を割り当てる。
2. **MP-BGP ピアリング確立:** PEルータ間で Loopback アドレスを使用して iBGP アドレスファミリー `vpnv4` / `vpnv6` セッションを確立。
3. **PE-CE BGP セッション確立:** PEルータとCEルータ間で VRF アドレスファミリー（`address-family ipv4 vrf <NAME>` / `address-family ipv6 vrf <NAME>`）配下に eBGP セッションを構成。
4. **CEからの経路受信とVPNプレフィックス化:** PEがCEからIPv4/IPv6経路を受信すると、該当VRFの RD（64-bit）を追加して 96-bit (VPNv4) または 160-bit (VPNv6) プレフィックスに変換。同時に配置された Export RT（BGP Extended Community）とローカルで生成した VPN Service Label を付与。
5. **MP-BGP による VPNv4/VPNv6 パケット送信:** PE-1 から PE-2 へ MP-BGP NLRI として VPN 経路情報を送信（Next-Hop は PE-1 の Loopback IP）。
6. **対向PEでのRTインポート判定:** PE-2 は受信した VPNv4/VPNv6 プレフィックスの Export RT と、自ルータ内の全 VRF の Import RT を照合。一致する VRF RIB へ RD を除去した状態でインポート。
7. **CEへの再アドバタイズ (eBGP):** PE-2 はインポートした経路を eBGP 経由で CE-2 へ送信。CE-2 が対向拠点と同じ AS 番号（例: AS 65001）を使用している場合は、`as-override` により AS 番号を置換してループ破棄を回避。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprintで重要なポイント

1. **PE-CE eBGP での AS-Override vs Allowas-in:**
   * 顧客拠点がすべて同じ AS 番号（例: AS 65001）を使用するトポロジーで、PE側で `as-override` を設定してCEのAS番号をPEのAS番号（例: AS 65000）に置き換える設定。
   * または、CE側で `neighbor <PE-IP> allowas-in` を設定して自AS番号が含まれるBGP Updateを受け入れる構成。
2. **Site-of-Origin (SOO) BGP Extended Community:**
   * マルチホームCE拠点（1つのCEが複数のPEに接続、または同一拠点内の2つのCEが異なるPEに接続しバックドアリンクが存在する環境）において、BGP経路のループや非最適ルーティングを抑止する `soo` の設定。
3. **VPNv4 / VPNv6 双方のMP-BGP設定:**
   * IPv4 だけではなく、`address-family vpnv6` の有効化および IPv6 VRF (`address-family ipv6 vrf <NAME>`) での PE-CE eBGP 構成。
4. **Route Target マトリクス設計:**
   * Full-Mesh（互いにRTを共有）だけでなく、Hub-and-Spoke 構成（Hubは全Spokeを受信・広報、Spoke間は直接通信不可）や Shared Services 構成（特定VRFと共通VRFの相互アクセス）のRTインポート/エクスポートロジック。
5. **LDP-IGP Synchronization と Transport LSP の整合性:**
   * MP-BGP VPNv4 経路が `show bgp vpnv4 unicast all` で valid/best になるためには、Next-Hop (対向PE Loopback) への LDP Label (LSP) が存在することが必須条件。

### よくある設定ミス・落とし穴

* **VRFバインド時のIPアドレス消去:** インターフェイスに IP アドレスが設定されている状態で `vrf forwarding <NAME>` を適用すると、IP アドレスが即座に消去される。必ず **VRFを先に適用してから IP アドレスを設定する**。
* **`address-family vpnv4` での Neighbor 活性化忘れ:** `router bgp <ASN>` のグローバル配下で `neighbor <PE-IP> remote-as <ASN>` を定義しただけでは VPNv4 セッションは張られない。必ず `address-family vpnv4` 配下で `neighbor <PE-IP> activate` を実行する。
* **PE-CE eBGP での `as-override` 未設定によるルートドロップ:** CE側で自AS番号を検知してパケットをサイレントドロップする障害。`show bgp vpnv4 unicast all` には存在するが、CEのルーティングテーブルに現れない場合に疑う。
* **SOO (Site-of-Origin) の適用インターフェイス/BGPネイバーの誤り:** SOO は PEルータの VRF BGP ネイバー配下 (`neighbor <CE-IP> soo <EXT-COMM>`) または Route-Map 経由で適用する。

### showコマンドから状態を判断するポイント

* `show bgp vpnv4 unicast all`: MP-BGPで交換された全VPNv4経路の確認。`*>` が付いているか、RD/RTが正しく付与されているかを確認。
* `show bgp vpnv4 unicast vrf <NAME>`: 特定VRF視点でのBGPテーブルの確認。
* `show ip route vrf <NAME>`: 顧客VRFのルーティングテーブル確認。
* `show mpls forwarding-table vrf <NAME>`: Inner Label（Service Label）と Outer Label のバインド状況を確認。

---

## 🛠 設定方法

### 1. PEルータ 基本設定テンプレート (IOS-XE 17.x)

```text
! --- VRFの定義 (IPv4/IPv6 Dual-Stack) ---
vrf definition CORP
 rd 65000:100
 address-family ipv4
  route-target export 65000:100
  route-target import 65000:100
 exit-address-family
 address-family ipv6
  route-target export 65000:100
  route-target import 65000:100
 exit-address-family
!
! --- VRF インターフェイスへのバインド ---
interface GigabitEthernet2
 vrf forwarding CORP
 ip address 192.168.12.1 255.255.255.0
 ipv6 address 2001:db8:12::1/64
 no shutdown
!
! --- MP-BGP 及び PE-CE BGP 設定 ---
router bgp 65000
 bgp log-neighbor-changes
 neighbor 10.0.0.2 remote-as 65000
 neighbor 10.0.0.2 update-source Loopback0
 !
 ! --- MP-BGP VPNv4 / VPNv6 アドレスファミリー ---
 address-family vpnv4
  neighbor 10.0.0.2 activate
  neighbor 10.0.0.2 send-community extended
 exit-address-family
 !
 address-family vpnv6
  neighbor 10.0.0.2 activate
  neighbor 10.0.0.2 send-community extended
 exit-address-family
 !
 ! --- PE-CE IPv4 BGP (VRF: CORP) ---
 address-family ipv4 vrf CORP
  neighbor 192.168.12.2 remote-as 65001
  neighbor 192.168.12.2 activate
  neighbor 192.168.12.2 as-override
  neighbor 192.168.12.2 soo 65000:111
 exit-address-family
 !
 ! --- PE-CE IPv6 BGP (VRF: CORP) ---
 address-family ipv6 vrf CORP
  neighbor 2001:db8:12::2 remote-as 65001
  neighbor 2001:db8:12::2 activate
  neighbor 2001:db8:12::2 as-override
  neighbor 2001:db8:12::2 soo 65000:111
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| MP-BGP VPNv4 全体サマリー確認 | <code>show bgp vpnv4 unicast all summary</code> |
| MP-BGP VPNv6 全体サマリー確認 | <code>show bgp vpnv6 unicast all summary</code> |
| 特定VRFのVPNv4 BGPテーブル確認 | <code>show bgp vpnv4 unicast vrf \<VRF_NAME\></code> |
| 特定プレプレフィックスのDetailed情報・ラベル確認 | <code>show bgp vpnv4 unicast vrf \<VRF_NAME\> \<PREFIX\></code> |
| VRFルーティングテーブル確認 | <code>show ip route vrf \<VRF_NAME\></code> |
| IPv6 VRFルーティングテーブル確認 | <code>show ipv6 route vrf \<VRF_NAME\></code> |
| MPLS LFIB/VRFラベル確認 | <code>show mpls forwarding-table vrf \<VRF_NAME\></code> |
| CEF VRFテーブル・ラベル付け確認 | <code>show ip cef vrf \<VRF_NAME\> \<PREFIX\> detail</code> |
| VRF定義・RD/RT一覧確認 | <code>show vrf detail \<VRF_NAME\></code> |
| PE-CE BGP デバッグ | <code>debug bgp vpnv4 unicast updates</code> |
| MP-BGP アップデートデバッグ | <code>debug bgp vpnv4 unicast events</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **CE側で対向拠点のBGP経路を受信できない** | PE-CE間でAS番号が同一であり、PEで `as-override` が未設定 | <code>show bgp vpnv4 unicast vrf \<VRF\></code>（PEには存在）<br><code>show bgp ipv4 unicast</code>（CEでドロップ） | PE側で `neighbor \<CE-IP\> as-override` を設定する、またはCE側で `allowas-in` を設定 |
| **PE間でVPNv4経路が交換されない** | `address-family vpnv4` 配下で `neighbor activate` が未設定 | <code>show bgp vpnv4 unicast all summary</code> | BGPの `address-family vpnv4` 配下で `neighbor \<PE-IP\> activate` を投入 |
| **PEのVRF RIBにVPNv4経路がインポートされない** | RT (Route-Target) の Import / Export 値の不一致 | <code>show vrf detail \<VRF\></code><br><code>show bgp vpnv4 unicast all \<PREFIX\></code> | PE-1の Export RT と PE-2の Import RT が完全一致するように修正 |
| **VPNv4経路は受信するが BGP Bestpath にならない** | 対向PE Loopback への LDP Transport LSP（Outer Label）が存在しない | <code>show mpls ldp neighbor</code><br><code>show ip cef \<PE-Loopback\></code> | アンダーレイのIGP/LDPを修復し、対向PE LoopbackへのLSPを確立 |
| **マルチホーム拠点間でループ・非最適経路が発生** | Site-of-Origin (SOO) が未設定、または同一SOOコミュニティが設定されていない | <code>show bgp vpnv4 unicast vrf \<VRF\> \<PREFIX\></code> | PEルータの該当CE向けBGPネイバーに `soo <EXT-COMM>` を設定して自拠点宛て再流入を防止 |

---

## ⚠ 制限事項

* **RD/RT の一位性:** 同一VRF内で異なるRDを使用することは可能だが、トラブルシューティングの観点から拠点ごとに一意のRDを割り振るか、VRFごとに単一のRDを割り振ることが推奨される。
* **Inner/Service Label の上限:** スイッチ/ルータのハードウェアプラットフォーム（TCAM領域）に依存する。大量のVRFおよびプレフィックスを収容する場合、`mpls label mode` の設定調整が必要となる場合がある。
* **eBGP Multi-hop:** PE-CE間を Loopback 同士で eBGP 接続する場合は、`neighbor <IP> ebgp-multihop` および `update-source` が必須。

---

## 🔄 他技術との関連

* **1.2.d VRF-Lite:** MP-BGP / MPLSを使わずに、単一機器内でVRFを用いてL3テーブルを分割する技術。L3VPNはVRF-LiteをMPLSバックボーン越えに拡張したもの。
* **3.2.a Operations (LDP):** L3VPNの Outer Label（Transport Label）を提供するアンダーレイシグナリングプロトコル。
* **1.5 BGP (Path Selection & Policies):** L3VPNのコントロールプレーンそのもの。Route-MapやBGP Extended Communityを用いて高度なVPN経路制御を実施。
* **1.6 Multicast (mLDP / Rosen MVPN):** L3VPN環境下でマルチキャストトラフィックをオーバーレイ転送するための拡張技術。

---

## 🧩 比較表

### AS-Override vs Allowas-in vs SOO

| 機能 | 設定場所 | 主な目的 | 動作原理 |
| --- | --- | --- | --- |
| **AS-Override** | PE ルータ | 同一AS番号を使用する別拠点のCEへ経路を伝搬させる | PEがCEへBGP Updateを送る際、AS_PATH内のCE AS番号をPE自体のAS番号に置換する |
| **Allowas-in** | CE ルータ | 同一AS番号を使用する別拠点の経路を受容する | CEがBGP Updateを受信する際、AS_PATH内に自AS番号が指定回数（1〜10）含まれていても受容許可する |
| **Site-of-Origin (SOO)** | PE ルータ | マルチホームCE拠点でのルーティングループ・再流入を防止する | PEがCEから受信した経路にSOO拡張コミュニティを付与。同一SOOを持つCE宛てにはその経路を返送しない |

---

## 💡 ベストプラクティス

1. **ループバックインターフェイスの独立:** MP-BGP ピアリングおよび LDP Router-ID には必ず専用の `/32` Loopback0 を使用する。
2. **RT (Route Target) の命名規則:** 組織内で一貫した命名規則（例: `65000:100` -> AS 65000, VRF ID 100）を策定する。
3. **LDP-IGP Synchronization の有効化:** コントロールプレーン（BGP）が確立していてもデータプレーン（LDP）が準備できていない状態でのトラフィックドロップを防ぐため、アンダーレイIGP（OSPF/ISIS）で `mpls ldp sync` を有効化する。
4. **SOO の一貫した適用:** 同一顧客拠点が複数のPEに接続されている構成（マルチホーム）では、両方のPEの該当ネイバーに必ず同一の SOO 値を設定する。

---

## 📝 ラボ学習・設定サンプル例

### サンプル 1: 基本的な IPv4 MP-BGP L3VPN 構成
* **問題:** PE-1 と PE-2 間で MP-BGP VPNv4 を構成し、VRF `CORP` (RD 65000:100, RT 65000:100) を作成せよ。
* **要件:**
  * PE-1 Loopback0: 10.0.0.1/32, PE-2 Loopback0: 10.0.0.2/32
  * MP-BGP セッションを Loopback0 間で確率せよ。
* **設定例 (PE-1):**
```text
vrf definition CORP
 rd 65000:100
 address-family ipv4
  route-target export 65000:100
  route-target import 65000:100
 exit-address-family
!
router bgp 65000
 neighbor 10.0.0.2 remote-as 65000
 neighbor 10.0.0.2 update-source Loopback0
 address-family vpnv4
  neighbor 10.0.0.2 activate
  neighbor 10.0.0.2 send-community extended
 exit-address-family
```
* **検証方法:** `show bgp vpnv4 unicast all summary` で 10.0.0.2 との BGP セッションが Established であることを確認。

---

### サンプル 2: PE-CE eBGP 構成 ＋ AS-Override
* **問題:** PE-1 と CE-1 間で VRF `CORP` を用いて eBGP を構成せよ。
* **要件:**
  * PE-1 AS: 65000, CE-1 AS: 65001, CE-2 AS: 65001
  * CE-1 が CE-2 の経路を受信できるように PE-1 側で適切にループ防止回避を設定せよ。
* **設定例 (PE-1):**
```text
interface GigabitEthernet2
 vrf forwarding CORP
 ip address 192.168.12.1 255.255.255.0
!
router bgp 65000
 address-family ipv4 vrf CORP
  neighbor 192.168.12.2 remote-as 65001
  neighbor 192.168.12.2 activate
  neighbor 192.168.12.2 as-override
 exit-address-family
```
* **検証方法:** CE-1 で `show ip route bgp` を実行し、CE-2 のプレフィックスが AS_PATH `65000 65000`（置換後）として受信できていることを確認。

---

### サンプル 3: CE 側での Allowas-in 構成
* **問題:** PE 側で `as-override` を設定できない制約がある場合、CE-1 側で対向拠点（同一 AS 65001）の経路を受信できるように構成せよ。
* **要件:**
  * CE-1 (AS 65001) で PE-1 (192.168.12.1) からの BGP Update 内に含まれる自 AS 番号を 2 回まで許容せよ。
* **設定例 (CE-1):**
```text
router bgp 65001
 neighbor 192.168.12.1 remote-as 65000
 address-family ipv4 unicast
  neighbor 192.168.12.1 allowas-in 2
 exit-address-family
```
* **検証方法:** CE-1 で `show bgp ipv4 unicast` を実行し、AS_PATH に `65000 65001` が含まれる経路が有効化されていることを確認。

---

### サンプル 4: Site-of-Origin (SOO) によるマルチホームループ防止
* **問題:** CE-1（拠点A）が PE-1 および PE-3 の 2台にデュアルホーム接続されている。PE-1 から CE-1 経由で再流入した経路が PE-3 に学習されるルーティングループを防止せよ。
* **要件:**
  * SOO 拡張コミュニティ `65000:111` を使用せよ。
* **設定例 (PE-1 & PE-3):**
```text
! PE-1 & PE-3 共通設定
router bgp 65000
 address-family ipv4 vrf CORP
  neighbor 192.168.12.2 remote-as 65001
  neighbor 192.168.12.2 soo 65000:111
 exit-address-family
```
* **検証方法:** PE-1 で CE-1 から受信した経路の BGP 属性に Extended Community `SoO:65000:111` が付与されていることを `show bgp vpnv4 unicast vrf CORP <PREFIX>` で確認。

---

### サンプル 5: IPv6 MP-BGP L3VPN (VPNv6) 構成
* **問題:** PE-1 と PE-2 間で IPv6 顧客トラフィックを伝搬するための MP-BGP VPNv6 を構成せよ。
* **要件:**
  * VRF `CORP_v6` を作成し、IPv6 アドレスファミリー配下で RT `65000:200` を設定せよ。
* **設定例 (PE-1):**
```text
vrf definition CORP_v6
 rd 65000:200
 address-family ipv6
  route-target export 65000:200
  route-target import 65000:200
 exit-address-family
!
router bgp 65000
 address-family vpnv6
  neighbor 10.0.0.2 activate
  neighbor 10.0.0.2 send-community extended
 exit-address-family
 !
 address-family ipv6 vrf CORP_v6
  neighbor 2001:db8:12::2 remote-as 65001
  neighbor 2001:db8:12::2 activate
 exit-address-family
```
* **検証方法:** `show bgp vpnv6 unicast all summary` および `show ipv6 route vrf CORP_v6` で IPv6 経路が正しく交換されていることを確認。

---

### サンプル 6: Hub-and-Spoke 形式の Route Target 設計
* **問題:** Hub 拠点（CE-Hub）を経由してのみ Spoke 拠点（CE-Spoke1, CE-Spoke2）同士が通信できる L3VPN トポロジーを構成せよ。
* **要件:**
  * Spoke は自身の経路を `RT 65000:1` で Export し、`RT 65000:2` を Import せよ。
  * Hub は Spoke 経路 (`RT 65000:1`) を Import し、Spoke へ向けて `RT 65000:2` で Export せよ。
* **設定例 (Spoke PE):**
```text
vrf definition SPOKE
 rd 65000:101
 address-family ipv4
  route-target export 65000:1
  route-target import 65000:2
 exit-address-family
```
* **設定例 (Hub PE):**
```text
vrf definition HUB_IN
 rd 65000:201
 address-family ipv4
  route-target import 65000:1
 exit-address-family
!
vrf definition HUB_OUT
 rd 65000:202
 address-family ipv4
  route-target export 65000:2
 exit-address-family
```
* **検証方法:** Spoke PE の BGP テーブルに他の Spoke 経路が直接現れず、Hub 経由の集約/デフォルトルートのみがインポートされることを確認。

---

### サンプル 7: Shared Services (共有サービス) VRF の構築
* **問題:** 共通サービス（DNS/DHCPサーバー群）を収容する `SHARED_VRF` に対し、`CORP_A` および `CORP_B` の両VRFから相互アクセスを許可せよ。
* **要件:**
  * `SHARED_VRF`: RT Export 65000:999, Import 65000:100, 65000:200
  * `CORP_A`: RT Export 65000:100, Import 65000:100, 65000:999
  * `CORP_B`: RT Export 65000:200, Import 65000:200, 65000:999
* **設定例 (Shared PE):**
```text
vrf definition SHARED_VRF
 rd 65000:999
 address-family ipv4
  route-target export 65000:999
  route-target import 65000:100
  route-target import 65000:200
 exit-address-family
```
* **検証方法:** `show ip route vrf CORP_A` に SHARED 網の経路が存在し、かつ `CORP_B` の経路が存在しない（CORP_A と CORP_B は直接通信不可）ことを確認。

---

### サンプル 8: PE-CE BGP MD5 認証 ＋ TTL Security Check
* **問題:** PE-1 と CE-1 間の eBGP セッションに対して、セキュリティを強化するための MD5 認証および TTL Security Check を設定せよ。
* **要件:**
  * MD5 パスワード: `CiscoLab123`
  * CE-1 は PE-1 と直結（Hop 数: 1）
* **設定例 (PE-1):**
```text
router bgp 65000
 address-family ipv4 vrf CORP
  neighbor 192.168.12.2 remote-as 65001
  neighbor 192.168.12.2 password CiscoLab123
  neighbor 192.168.12.2 ttl-security hops 1
 exit-address-family
```
* **検証方法:** `show bgp vpnv4 unicast vrf CORP summary` でネイバー状態が Established であり、`show ip bgp neighbors 192.168.12.2` で TTL Security が有効であることを確認。

---

### サンプル 9: Dynamic EBGP Multihop PE-CE 接続
* **問題:** PE-1 と CE-1 間で Loopback アドレス同士（PE-1: 172.16.1.1, CE-1: 172.16.2.2）を用いて eBGP セッションを構築せよ。
* **要件:**
  * eBGP Multi-hop 数: 2
  * 接続用の静的ルートを VRF 内に設定せよ。
* **設定例 (PE-1):**
```text
ip route vrf CORP 172.16.2.2 255.255.255.255 192.168.12.2
!
router bgp 65000
 address-family ipv4 vrf CORP
  neighbor 172.16.2.2 remote-as 65001
  neighbor 172.16.2.2 update-source Loopback1
  neighbor 172.16.2.2 ebgp-multihop 2
  neighbor 172.16.2.2 activate
 exit-address-family
```
* **検証方法:** `show ip bgp vpnv4 unicast vrf CORP neighbors 172.16.2.2` で BGP セッションが正常に確立されていることを確認。

---

### サンプル 10: VRF ルート再配送時の Default-Information Originate
* **問題:** PE-1 から CE-1 に対し、MP-BGP VPNv4 網を経由してデフォルトルート (`0.0.0.0/0`) を条件付きでアドバタイズせよ。
* **要件:**
  * PE-1 の VRF `CORP` BGP アドレスファミリー内でデフォルトルートを直接無条件生成して広報せよ。
* **設定例 (PE-1):**
```text
router bgp 65000
 address-family ipv4 vrf CORP
  default-information originate
  network 0.0.0.0
 exit-address-family
```
* **検証方法:** CE-1 のルーティングテーブル (`show ip route bgp`) に `0.0.0.0/0 via 192.168.12.1` が学習されていることを確認。

---

## ❓ 想定試験問題

### 問1 (コンフィグ読解)
PEルータの以下の設定を読み取り、CEルータ (AS 65001) で対向拠点 (同一 AS 65001) の経路が学習できない原因を特定せよ。

```text
vrf definition CLIENT_A
 rd 65000:10
 address-family ipv4
  route-target export 65000:10
  route-target import 65000:10
 exit-address-family
!
router bgp 65000
 address-family vpnv4
  neighbor 10.0.0.2 activate
 exit-address-family
 !
 address-family ipv4 vrf CLIENT_A
  neighbor 10.1.12.2 remote-as 65001
  neighbor 10.1.12.2 activate
 exit-address-family
```

* **解答・解説:** PEルータの `address-family ipv4 vrf CLIENT_A` 配下で **`neighbor 10.1.12.2 as-override`** が設定されていないため。対向拠点（CE-2）から送信された BGP Update に含まれる AS_PATH `65001` が、CE-1 受信時に自 AS と一致するためループと判断されて CE-1 側で破棄される。PE 側で `as-override` を追加するか、CE-1 側で `allowas-in` を構成する必要がある。

---

### 問2 (トラブルシューティング)
PE-1 において `show bgp vpnv4 unicast all` を実行したところ、対向 PE-2 から受信した VPNv4 プレフィックス `10.2.2.0/24` が表示されるが、`show ip route vrf CORP` に反映されない。考えられる 2 つの主な原因を挙げよ。

* **解答・解説:**
  1. **Route Target (RT) の不一致:** 対向 PE-2 で付与された Export RT と、ローカル PE-1 の VRF `CORP` に設定されている Import RT が一致していない。
  2. **Transport LSP (LDP Outer Label) の欠落:** 該当 VPNv4 経路の BGP Next-Hop (PE-2 の Loopback IP) に対する LDP ラベル（LSP）が PE-1 上の LFIB / CEF テーブルに存在せず、Unreachable 扱いになっているため。

---

### 問3 (Design)
同一の CE 拠点（AS 65001）が PE-1 と PE-2 の 2 台のルータにマルチホーム接続されており、さらに CE 拠点内にバックドアリンク（OSPF等）が存在する。PE-1 から CE へ配送された BGP 経路が、拠点内を通って PE-2 へ再注入されるループを防ぐために PE ルータ上で設定すべき BGP 属性は何か？

* **解答・解説:** **Site-of-Origin (SOO) BGP Extended Community**（`neighbor <CE-IP> soo <EXT-COMM>`）。PE-1 が CE から受信用に付与した SOO 値と同じ値を PE-2 にも設定しておくことで、PE-2 は同一 SOO を持つ BGP 経路を該当 CE 向けへ再広報（Egress）することを自動遮断し、ループを完全に防止する。

---

### 問4 (実装)
IPv6 L3VPN (VPNv6) を導入する際、PE ルータ間の MP-BGP セッションにおいて `address-family vpnv6` の他に、PE-CE 間で設定すべきアドレスファミリー構文を解答せよ。

* **解答・解説:** **`address-family ipv6 vrf <VRF_NAME>`**。PE ルータの `router bgp <ASN>` 配下にこの VRF アドレスファミリーを定義し、その配下で CE ルータとの IPv6 eBGP ネイバー（`neighbor <CE-IPv6> remote-as <CE-ASN>`）を有効化 (`activate`) する。

---

### 問5 (トラブルシューティング)
PE ルータ上で `show mpls forwarding-table vrf CORP` を実行した際、特定のプレフィックスに対する Output Interface が `Pop Label` や `Aggregate` ではなく、ローカルの物理/VLAN インターフェイスとなっている場合、このラベルは何を意味しているか？

* **解答・解説:** このラベルは **Inner/Service Label（VPN Label）** であり、対向 PE から送られてきた MPLS パケットの Outer Label（Transport Label）が PHP 等で剥がされた後、PE 自身がどの VRF のどの出向インターフェイス（CE 向け）へパケットをルーティングすべきかを識別するためのラベル処理状態を示している。

---

## 🔗 参考リソース

* [Cisco IOS-XE 17.x MPLS Layer 3 VPNs Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-16/mp-l3-vpns-xe-16-book.html)
* [Cisco Technical Notes: BGP AS-Override and Allowas-in Explained](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200306-Configure-BGP-AS-Override-and-Allowas.html)
* [Cisco Technical Notes: BGP Site-of-Origin (SoO) Attribute Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/116017-config-soo-00.html)
* [Cisco Live BRKCCIE-3000: Advanced MPLS L3VPN Architecture](https://www.ciscolive.com/)
* [Cisco Command Reference: BGP Commands (address-family vpnv4 / vpnv6)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book.html)

---

## 📝 **補足（Notes）**

### L3VPN 2段ラベルの構造とヘッダースタック

```text
+-------------------+-------------------+-------------------+-------------------+
| Outer IP Header   | Transport Label   | Service/VPN Label | Passenger Packet  |
| (PE-1 to PE-2)    | (LDP: Outer)      | (MP-BGP: Inner)   | (Customer IP)     |
+-------------------+-------------------+-------------------+-------------------+
                      ← S-bit = 0         ← S-bit = 1
```

* **Transport Label (Outer):** PE-2 Loopback アドレス宛ての LDP LSP パス（Pルータ群で Swap され、PHP により Egress PE 直前で剥離）。S-bit (Bottom of Stack) は `0`。
* **Service / VPN Label (Inner):** MP-BGP (VPNv4/VPNv6) によって対向 PE から通知されたラベル。Egress PE 上で特定 VRF / 出向インターフェイスを特定するために使用。S-bit (Bottom of Stack) は `1`。

### ラボ試験での高速チェックリスト
1. `show vrf` で RD / RT が正しく設定されているか？
2. `show bgp vpnv4 unicast all summary` で PE 間の BGP が Established か？
3. `show mpls ldp neighbor` で LDP セッションが Established か？
4. `show bgp vpnv4 unicast vrf <VRF>` で CE からの経路を受信できているか？
5. CE 側で経路が見えない場合、`as-override` または `allowas-in` を確認したか？
6. マルチホーム環境で SOO による再流入ループ対策がなされているか？


## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKCCIE-3000: BGP and Multicast for the CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   L3VPNにおける高度なBGP属性操作と、実技試験での「落とし穴」を解説。
*   [**BRKSP-2005: Deploying MPLS Layer 3 VPNs**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSP-2005)
    *   L3VPNのアーキテクチャ詳細と、PE-CEルーティングオプションの比較。

### Configuration ガイド
*   [**MPLS: Layer 3 VPNs Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-17/mp-l3-vpns-xe-17-book.html)。
*   [**Configuring BGP PE-CE Routing**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book/irg-vpn-routing.html)。

### テクニカルノーツ・設定例
*   [**MPLS Layer 3 VPN Overview and Configuration**](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/13733-mpls-vpn-config.html)。
*   [**Understanding Route Distinguishers and Route Targets (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13733-mpls-vpn-config.html)。

---

## 📝 補足
- この学習メモは、MPLS L3VPN の「制御プレーン（BGP）」と「データプレーン（Label）」、そして「ポリシー（RT）」の相互作用を整理しています。CCIE 実技試験では、特に **VRF 配下での BGP 再配送** や **RT 不一致による疎通不可** の解決が迅速に行えるかどうかが、合格へのクリティカルなスキルとなります。


