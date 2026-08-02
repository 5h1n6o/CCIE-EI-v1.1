---
layout: default
title: 2.1.e-Fabric-border-handoff
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 5
---

# 2.1.e Fabric Border Handoff

Cisco SD-Access（SDA）における **Fabric Border Handoff** は、ファブリックという「聖域」と外部の世界（インターネット、データセンター、既存のレガシーネットワーク）を接続するための境界線です。CCIE Enterprise Infrastructure (EI) v1.1 の試験において、この項目はマクロセグメンテーションの維持、外部への到達性確保、そして異なるテクノロジードメイン（SD-WAN等）との統合という観点で非常に重要です。

---

## 📘 概要

**Fabric Border Handoff** とは、SD-Access ファブリックの **Border Node** が、ファブリック内部の仮想ネットワーク（VN/VRF）の情報を外部ネットワークへと橋渡しするメカニズムを指します。

ファブリック内部では LISP による制御プレーンと VXLAN によるデータプレーンが使用されていますが、外部ネットワーク（トランジット）は通常、標準的な IP ルーティング（BGP, OSPF, IS-IS）や VRF-Lite に基づいています。Border Node は、ファブリック内のエンドポイント識別子（EID）情報を外部のルーティングプロトコルに再配送し、逆に外部のルートをファブリック内に取り込む役割を担います。

このハンドオフには、サイト間を LISP で繋ぐ **SDA Transit**、広域網を介して統合する **SD-WAN Transit**、そして汎用的な BGP/VRF-Lite を用いる **IP Transit** の 3 種類が存在します。また、L3 レベルだけでなく、特定の VLAN をタグを保持したまま外部へ引き出す **Layer 2 Border Handoff** もサポートされています。

---

## 🔑 要点

### 1. SDA, SD-WAN, IP Transits (i)

ファブリックを外部へ拡張または接続するための 3 つの方式です。

*   **IP Transit:** 最も一般的で柔軟な方式です。Border Node と外部ルータ（Fusion Router）の間で **VRF-Lite** と **BGP** を使用してハンドオフを行います。
    *   Border Node は各 VN ごとに BGP ピアリングを張り、`redistribute lisp` によってファブリック内のルートを外部へ伝えます。
*   **SDA Transit:** 複数の SDA サイトをネイティブに接続する方式です。サイト間の通信にも LISP と VXLAN が使用され、サイトを跨いでも **SGT（Scalable Group Tag）** が保持されます。
*   **SD-WAN Transit:** SD-Access と Cisco SD-WAN を統合する方式です。Border Node が SD-WAN のエッジ（cEdge/vEdge）を兼ねる、あるいは隣接することで、ファブリックの VN が SD-WAN の VPN に自動的にマッピングされます。

### 2. Peer Device (Fusion Router) (ii)

Border Node の外部隣接ルータを **Fusion Router** と呼びます。

*   **役割:** 
    1.  ファブリック内の複数の VRF を収容し、外部ネットワークへの共通の出口を提供します。
    2.  **ルートリーキング（Route Leaking）:** 異なる VN 間、あるいは VN とグローバルルーティングテーブル（共有サービス：DHCP, DNS, ISE, DNAC 等が存在する場所）の間でルートを相互に注入します。
    3.  ファブリック外のデバイスとの BGP ピアリングを担当します。

### 3. Layer 2 Border Handoff (iii)

ファブリック内の特定の仮想ネットワーク（レイヤ 2 VNI）を、外部のレガシーなレイヤ 2 ネットワークへ拡張する機能です。

*   **動作:** Border Node 上で、内部の VNI と外部の物理ポート（Trunk または Access）の VLAN を 1:1 でマッピングします。
*   **用途:** ファブリックへの移行期間中に、同一サブネットのホストがファブリック内と外の両方に存在する場合や、VLAN ベースのファイアウォールを接続する場合に使用されます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、DNA Center (DNAC) による自動設定だけでなく、手動での **Fusion Router の構成** や、BGP 属性を用いた **パス制御** が問われます。

### 1. Border Node での再配送の論理

Border Node はファブリック内の情報を `LISP` データベースとして持っています。
*   **必須設定:** 外部へ広報するためには、BGP の各 VRF アドレスファミリー配下で `redistribute lisp` を設定する必要があります。
*   **注意点:** LISP から BGP へ再配送されたルートは、デフォルトでは `Origin: Incomplete (?)` となります。必要に応じてルートマップで属性を調整します。

### 2. Fusion Router での共有サービスへの到達性

最も頻出するトラブルは、ファブリック内のユーザーが DHCP サーバやインターネットに到達できないケースです。
*   **対策:** Fusion Router 上で、各ユーザー VRF から共有サービスが存在する VRF（または Global）へデフォルトルートをリークさせ、逆に共有サービス側からはユーザー VRF への戻りルートを保持させる必要があります。

### 3. SGT（TrustSec）の伝播

IP Transit（VRF-Lite）を使用する場合、通常、Border と Fusion の間のリンクでは SGT タグが失われます。
*   **対策:** エンドツーエンドでポリシーを維持する必要がある場合、Border と Fusion の間で **SXP (SGT Exchange Protocol)** を構成する、あるいは **Inline Tagging** をサポートするハードウェアを使用するタスクが出題されます。

### 4. MTU サイズの不整合

VXLAN カプセル化パケットが Border を通過して外部へ出る際、オーバーヘッド（50バイト）によってフラグメンテーションが発生し、パフォーマンスが劣化することがあります。
*   **確認事項:** 物理リンクの MTU を 1550 以上（推奨 9100）に設定し、TCP MSS を調整するスキルが求められます。

---

## 🛠 設定・検証コマンド

### Border Node でのハンドオフ設定（BGP 側）

| 目的 | コマンド |
| :--- | :--- |
| **VRF 配下での BGP 起動** | <code>address-family ipv4 vrf [VN_NAME]</code> |
| **LISP ルートの BGP 注入** | <code>(config-router-af)# redistribute lisp</code> |
| **外部ネイバーとの確立** | <code>(config-router-af)# neighbor [FUSION_IP] remote-as [AS]</code> |
| **外部へのデフォルトルート広報** | <code>(config-router-af)# neighbor [FUSION_IP] default-originate</code> |

### Fusion Router でのルートリーク設定

| 目的 | コマンド |
| :--- | :--- |
| **VRF 間のインポート/エクスポート** | <code>ip vrf [NAME]</code> <br> <code>route-target export [RT]</code> <br> <code>route-target import [RT]</code> |
| **BGP による VRF 間リーク** | <code>address-family ipv4 vrf [USER_VN]</code> <br> <code>import vrf [SHARED_VN] route-map [MAP]</code> |
| **スタティックルートによるリーク** | <code>ip route vrf [USER] 0.0.0.0 0.0.0.0 [NEXT_HOP_IP] global</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **LISP EID 登録情報の確認** | <code>show lisp instance-id [ID] ipv4 server</code> |
| **Border の BGP 学習状況確認** | <code>show ip bgp vrf [VN_NAME] summary</code> |
| **再配送されたルートの確認** | <code>show ip bgp vrf [VN_NAME] [PREFIX]</code> |
| **VNI と VRF の紐付け確認** | <code>show nve vni</code> |
| **SXP による SGT 伝播確認** | <code>show cts sxp connections brief</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. Border Node での IP Transit BGP 構成

**【問題】**
Border ルータにおいて、VN `Corp` のルートを Fusion ルータ (192.168.1.1, AS 65001) へ広報せよ。

**【設定例】**
```ios
router bgp 65000
 address-family ipv4 vrf Corp
  neighbor 192.168.1.1 remote-as 65001
  neighbor 192.168.1.1 activate
  redistribute lisp
```

---

### 2. LISP から BGP への再配送属性の操作

**【問題】**
LISP から再配送するルートに対し、外部での優先度を上げるため、BGP の MED 値を 50 に設定せよ。

**【設定例】**
```ios
route-map LISP_TO_BGP permit 10
 set metric 50
!
router bgp 65000
 address-family ipv4 vrf Corp
  redistribute lisp route-map LISP_TO_BGP
```

---

### 3. Fusion Router でのデフォルトルート・リーク

**【問題】**
Fusion ルータにおいて、ユーザー VRF `Guest` に対してグローバルルーティングテーブルからデフォルトルートをリークさせよ。

**【設定例】**
```ios
! Guest VRFからGlobalへのスタティックルート
ip route vrf Guest 0.0.0.0 0.0.0.0 GigabitEthernet1 10.1.1.1 global
!
! BGPでの戻りルート広報（任意）
router bgp 65001
 address-family ipv4 vrf Guest
  redistribute static
```

---

### 4. Layer 2 Border Handoff の実装

**【問題】**
Edge スイッチの Gi1/0/24 ポートにおいて、ファブリック内の VN `Finance` (VNI 8192) を VLAN 100 として外部スイッチへ拡張せよ。

**【設定コンセプト】**
DNAC で設定するのが一般的ですが、CLI では以下のようにマッピングを確認します。
```ios
! 検証コマンド
show nve vni 8192
! 期待される出力: "VNI 8192 is associated with Vlan 100"
```

---

### 5. SXP による Border-Fusion 間の SGT 転送

**【問題】**
Border と Fusion の間で SGT 情報を共有するため、SXP ピアリングをパスワード `cisco` で確立せよ。

**【設定例】**
```ios
! Border側 (Speaker)
cts sxp enable
cts sxp connection peer 192.168.1.1 password simple cisco mode local speaker
! Fusion側 (Listener)
cts sxp enable
cts sxp connection peer 192.168.1.2 password simple cisco mode local listener
```

---

### 6. Border での外部ルートのファブリックへの注入

**【問題】**
外部 BGP で学習したインターネットルートを、ファブリック内のエッジノードが利用できるように LISP Map-Server へ登録せよ。

**【設定例】**
```ios
router lisp
 instance-id 4097
  address-family ipv4
   ! BGPから学習したルートをLISPへ
   redistribute bgp 65000
```

---

### 7. Fusion Router での VRF 間 Route Target リーク

**【問題】**
VRF `Production` と VRF `Backup` の間でルートを相互に共有せよ。

**【設定例】**
```ios
ip vrf Production
 route-target both 100:1
 route-target import 100:2  ! BackupのRT
!
ip vrf Backup
 route-target both 100:2
 route-target import 100:1  ! ProductionのRT
```

---

### 8. Anycast Gateway MAC の外部重複チェック

**【問題】**
（トラブルシューティング）L2 ハンドオフ先のスイッチで Anycast MAC がフラッピングしている。各サイト固有の仮想 MAC に変更されているか確認せよ。

**【検証】**
```ios
show interface vlan 10 | include address
! MACアドレスが全ファブリック共通の 0000.0c9f.f001 等になっていないか確認
```

---

### 9. Fusion Router 経由の DHCP リレー構成

**【問題】**
ファブリック内の PC が、Fusion ルータの先に存在する DHCP サーバ (10.10.10.10) から IP を取得できるようにせよ。

**【設定例】**
```ios
! BorderルータのSVIで設定
interface Vlan10
 vrf forwarding Corp
 ip address 172.16.1.1 255.255.255.0
 ip helper-address 10.10.10.10
```

---

### 10. BGP 最大受信プレフィックス制限 (Border保護)

**【問題】**
外部 Fusion ルータから誤って大量のルートが送られてこないよう、Border ノードの各 VRF BGP ピアで受信ルートを 1000 に制限せよ。

**【設定例】**
```ios
router bgp 65000
 address-family ipv4 vrf Corp
  neighbor 192.168.1.1 maximum-prefix 1000
```

---

### 11. MTU 不整合による L3 Handoff 障害の修正

**【問題】**
Border-Fusion 間の通信で 1500 バイト超のパケットがドロップされる。物理インターフェイスの MTU を調整せよ。

**【設定例】**
```ios
interface GigabitEthernet1/0/1
 mtu 9100
!
! BGPセッション等への影響を確認
show ip bgp vrf Corp neighbors | include MTU
```

---

### 12. Fusion Router でのルートマップによるリーク制御

**【問題】**
Fusion ルータにおいて、共有サービス VRF からユーザー VRF へ、特定の DNS サーバの経路 (8.8.8.8/32) のみを提供せよ。

**【設定例】**
```ios
ip prefix-list PFX_DNS permit 8.8.8.8/32
!
route-map RM_DNS_ONLY permit 10
 match ip address prefix-list PFX_DNS
!
router bgp 65001
 address-family ipv4 vrf User_Corp
  import vrf Shared_Service route-map RM_DNS_ONLY
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076) - ボーダーハンドオフの設計パターンとベストプラクティス。
*   [**BRKCRS-2810: Cisco SD-Access Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810) - LISP/BGP 再配送のトラブルシュート。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - ラボ試験での Fusion ルータ構成のポイント。

### Configuration ガイド
*   [**Cisco DNA Center SD-Access IP Transit Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)。
*   [**Configuring L3 Handoff on Catalyst 9000 Switches**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-l3-handoff.html)。

### テクニカルドキュメント・設定例
*   [**SD-Access: Troubleshooting the Fabric (Tech Note on Fusion Routers)**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)。
*   [**Understanding SD-Access Layer 2 Border Handoff**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-l2-handoff.html)。

---


## 📝 補足
- この学習メモは、SD-Access の「境界」をいかに制御するかに焦点を当てています。CCIE 実技試験では、DNA Center でのプロビジョニングに加えて、外部の **Fusion ルータにおける BGP リーキング** が合否を分ける急所となります。Border Node の `redistribute lisp` と Fusion Router の VRF 間の論理を完璧に繋ぎ合わせる練習を繰り返してください。

