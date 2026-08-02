---
layout: default
title: 2.1.b-Overlay
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 2
---

# 2.1.b Cisco SD-Access Overlay

Cisco SD-Access（Software-Defined Access）における **Overlay（オーバーレイ）** は、物理的なアンダーレイ ネットワーク上に構築された論理的な仮想ネットワークです。アンダーレイがノード間の基本的なIP到達性を提供するのに対し、オーバーレイはユーザーのトラフィックを運び、セグメント化、モビリティ、およびセキュリティ ポリシーの適用を担当します。

---

## 📘 概要

SD-Access オーバーレイは、複数のプレーン（制御、データ、ポリシー）が相互に連携することで、従来のネットワークでは困難だった「IPアドレスと場所の分離」および「アイデンティティベースの制御」を実現します。

1.  **Control Plane (LISP/BGP):** ファブリック内のエンドポイント（ホスト）が「どこにいるか」を管理します。
2.  **Data Plane (VXLAN):** 実際のパケットをカプセル化して転送します。SD-Access では SGT（Scalable Group Tag）を運ぶために拡張された VXLAN-GPO を使用します。
3.  **Policy Plane (Cisco TrustSec):** SGT を利用して、誰がどのリソースにアクセスできるかを定義し、マイクロセグメンテーションを実現します。
4.  **L2 Flooding & Multicast:** 仮想ネットワーク内でのブロードキャスト、未知のユニキャスト、およびマルチキャスト（BUMトラフィック）の効率的な配信を管理します。

---

## 🔑 要点

### 1. Control Plane: LISP と BGP (i)

SD-Access は **LISP (Locator/ID Separation Protocol)** を制御プレーンの中核として採用しています。

*   **EID (Endpoint Identifier):** ホストの IP アドレス。ホストが移動しても変わりません。
*   **RLOC (Routing Locator):** ファブリック ノード（スイッチ）の Loopback アドレス。EID が現在どのスイッチ配下にいるかを示します。
*   **Map-Server (MS) / Map-Resolver (MR):** コントロール プレーン ノードがこの役割を担い、EID と RLOC のマッピング データベースを保持します。
*   **Anycast Gateway:** すべてのエッジ ノードで同一の IP/MAC ゲートウェイを保持することで、エンドポイントのシームレスな移動を可能にします。
*   **BGP の役割:** 主に外部ネットワーク（外部ボーダー）とのルート交換や、VRF 間のルート情報のやり取りに使用されます。

### 2. Data Plane: VXLAN (ii)

データ プレーンには **VXLAN (Virtual Extensible LAN)** が使用されます。

*   **カプセル化:** オリジナルの L2 フレームを UDP でラップし、L3 アンダーレイを介して転送します。
*   **VXLAN-GPO (Group Policy Option):** 標準の VXLAN ヘッダーを拡張し、予約フィールドを使用して **SGT (Scalable Group Tag)** を運びます。これにより、パケット自体にセキュリティ属性を付与したまま転送可能です。
*   **VNI (VXLAN Network Identifier):** セグメントの識別子。レイヤ 2 VNI（VLAN 相当）とレイヤ 3 VNI（VRF 相当）があります。

### 3. Policy Plane: Cisco TrustSec (iii)

セキュリティ ポリシーは **Cisco TrustSec (CTS)** アーキテクチャに基づいています。

*   **SGT (Scalable Group Tag):** ユーザーやデバイスの役割（Role）に基づいて割り当てられる 16 ビットのタグです。
*   **SGACL (Scalable Group ACL):** IP アドレスではなく「ソース SGT」から「宛先 SGT」への許可・拒否を定義します。
*   **ISE (Identity Services Engine):** ポリシーの集中管理ポイント。ユーザーの認証後に SGT を動的に割り当て、各スイッチにポリシーをプッシュします。

### 4. L2 Flooding と Native Multicast (iv, v)

ファブリック内での非ユニキャスト通信の最適化です。

*   **L2 Flooding:** デフォルトでは抑制されますが、ARP やレガシー プロトコルのために必要な場合、アンダーレイのマルチキャスト、またはヘッドエンド レプリケーション（HER）を使用して、特定の VLAN 情報をフラッディングさせることができます。
*   **Native Multicast:** オーバーレイのマルチキャスト通信をアンダーレイのマルチキャスト サービス（IS-IS PIM 等）を利用して効率的に配信します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、オーバーレイの論理的な不整合や ISE との連携、および外部ネットワークとの接続（Border）が重要になります。

### 1. LISP 登録プロセスのトラブルシューティング

*   エンドポイントがネットワークに接続された際、Edge ノードが MS (Control Plane) に **Map-Register** を送っているかを確認します。
*   `show lisp site` コマンドで EID が正しく登録されているか、どの RLOC に紐付いているかを確認するスキルが必要です。

### 2. Anycast Gateway とサブネットの不一致

*   すべての Edge スイッチで同じゲートウェイ IP/MAC が設定されている必要があります。
*   トラブルシナリオ：特定の Edge スイッチだけで SVI がダウンしている、または MAC アドレスが重複しているために特定のエリアで通信ができない状況の修正。

### 3. SGT の伝播 (Propagation)

*   パケットがファブリックを通過する際、VXLAN ヘッダー内に正しい SGT が保持されているかを確認します。
*   SXP (SGT Exchange Protocol) を使用して、非ファブリック デバイスと SGT 情報を交換するシナリオも想定されます。

### 4. VN 間のセグメンテーション (Macro-segmentation)

*   **Virtual Network (VN)** は VRF にマッピングされます。
*   異なる VN 間の通信が必要な場合、Fusion ルータでのルートリーク、または Border ノードでの BGP 再配送構成が問われます。

---

## 🛠 設定・検証コマンド

SD-Access は DNA Center による自動化が基本ですが、検証や詳細なデバッグには CLI が不可欠です。

### 制御・データプレーン検証

| 目的 | コマンド |
| :--- | :--- |
| **LISP EID 登録情報の確認** | <code>show lisp instance-id [ID] ipv4 server</code> |
| **LISP RLOC 到達性の確認** | <code>show lisp instance-id [ID] ipv4 statistics</code> |
| **VXLAN トンネル(NVE)の確認** | <code>show nve interface nve1</code> |
| **VNI と VRF のマッピング確認** | <code>show nve vni</code> |
| **ARP キャッシュ（Anycast GW）確認** | <code>show ip arp vrf [NAME]</code> |

### ポリシー・TrustSec 検証

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスの SGT 設定確認** | <code>show cts interface [ID]</code> |
| **SGT 割り当て状況の確認** | <code>show cts role-based sgt-map all</code> |
| **SGACL ポリシーの確認** | <code>show cts role-based permissions</code> |
| **ISE から取得した PAC の確認** | <code>show cts pacs</code> |
| **環境データの同期確認** | <code>show cts environment-data</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIE EI ラボ試験の要求レベルに基づいた、オーバーレイ操作の 12 シナリオです。

### 1. Control Plane Node での EID 登録確認

**【問題】**
エッジ スイッチ配下の PC（10.1.10.100）が外部と通信できない。コントロール プレーン ノードにおいて、この IP が正しい RLOC に登録されているか確認せよ。

**【検証】**
```ios
! Control Plane Node で実行
show lisp instance-id 4097 ipv4 server 10.1.10.100
! "RLOC: 1.1.1.1"（EdgeスイッチのLo0）が表示され、Up状態であることを確認
```

---

### 2. VXLAN データのパケット キャプチャ解析 (要点)

**【問題】**
VXLAN カプセル化が正しく行われているか、ヘッダー内の VNI を確認せよ。

**【検証】**
```ios
! Edge スイッチのアンダーレイ インターフェイスでキャプチャ
monitor capture CAP interface Gi1/0/1 both
! ...トラフィック発生...
! 解析：UDP ポート 4789 (VXLAN) を探し、VNI (例: 8192) が正しい VN に紐付いているか見る
```

---

### 3. Edge スイッチでの Anycast Gateway 設定 (Manual 修正)

**【問題】**
ファブリック エッジにおいて、特定の VLAN（VN_Users）のデフォルト ゲートウェイ IP `172.16.1.1` を設定し、MAC アドレスを全 Edge で `0000.0c9f.f001` に統一せよ。

**【設定例】**
```ios
interface Vlan10
 vrf forwarding VN_Users
 ip address 172.16.1.1 255.255.255.0
 mac-address 0000.0c9f.f001
 no shutdown
```

---

### 4. SGACL によるマイクロセグメンテーションの強制

**【問題】**
SGT 4（Developers）から SGT 5（Finance_Server）への HTTP 通信のみを許可し、他は拒否せよ。

**【設定例 (ISE側が主だがスイッチ側での確認)】**
```ios
! スイッチ側での適用確認
show cts role-based permissions from 4 to 5
! 期待される出力:
! IPv4 Role-based permissions from group 4 to group 5:
!    Permit_HTTP_Only
```

---

### 5. L2 Flooding (Broadcast) の有効化

**【問題】**
レガシー アプリケーションのために、VLAN 20 において ARP 以外のブロードキャスト トラフィックも全 Edge ノードへフラッディングするようにせよ。

**【設定概念】**
*   DNA Center で「Layer 2 Flooding」を有効にします。
*   内部的には、アンダーレイの特定のマルチキャスト グループに VNI がマップされます。

---

### 6. Border ノードでの外部 BGP ピアリング

**【問題】**
Border ルータにおいて、ファブリック内のユーザー（VN_Corporate）の経路を、外部ネットワークの Core ルータ（AS 65001）へ広報せよ。

**【設定例】**
```ios
router bgp 65000
 address-family ipv4 vrf VN_Corporate
  neighbor 192.168.254.1 remote-as 65001
  neighbor 192.168.254.1 activate
  redistribute lisp  ! LISPで学習したEIDをBGPへ
```

---

### 7. SGT Inline Tagging の無効化時の対応 (SXP)

**【問題】**
SGT タグ付けをサポートしない古いスイッチが中間に存在するため、Border ルータと Core ルータ間で SXP を使用して SGT 情報を交換せよ。

**【設定例】**
```ios
cts sxp enable
cts sxp default source-ip 1.1.1.1
cts sxp connection peer 2.2.2.2 password simple MY_PASSWORD mode local
```

---

### 8. Native Multicast の RPF チェック不整合修正

**【問題】**
オーバーレイでのマルチキャスト通信が届かない。アンダーレイの IS-IS PIM 設定を確認し、Source への RPF が Tunnel ではなく物理インターフェイスを向いている不整合を修正せよ。

**【検証】**
```ios
show ip rpf [Source_EID]
! 修正が必要な場合はアンダーレイのルーティング（IS-ISコスト等）を調整
```

---

### 9. VRF 間のルートリーク (Fusion Router)

**【問題】**
VN_Guest から VN_Shared_Service への通信を許可するため、Fusion ルータにおいて BGP 再配送とルートマップを用いて相互に経路をリークさせよ。

**【設定例】**
```ios
ip prefix-list PFX_GUEST permit 10.20.0.0/16
!
route-map GUEST_TO_SHARED permit 10
 match ip address prefix-list PFX_GUEST
!
router bgp 65000
 address-family ipv4 vrf VN_Shared
  import vrf VN_Guest route-map GUEST_TO_SHARED
```

---

### 10. ISE との TrustSec 同期失敗の解決

**【問題】**
スイッチが ISE から最新の SGT リストを取得できていない。RADIUS サーバーの設定と、`cts credentials` の設定を確認せよ。

**【検証】**
```ios
test aaa group radius user test-user password cisco legacy
show cts environment-data
! "State: Incomplete" なら ISE との TrustSec 設定（共有シークレット等）に問題あり
```

---

### 11. Anycast Gateway への ping 疎通確認 (EID Source)

**【問題】**
Edge スイッチから、自身が収容しているエンドポイントのふりをして Anycast Gateway への応答を確認せよ。

**【操作】**
```ios
ping vrf VN_Users 172.16.1.1 source 172.16.1.100
! 送信元を収容済みEIDのアドレスに指定することで、LISPのロジックをテスト可能
```

---

### 12. Map-Server 冗長化の確認

**【問題】**
2台ある Control Plane ノードの一方がダウンしても、EID の登録が継続されることを確認せよ。

**【検証】**
```ios
show lisp instance-id 4097 ipv4 map-cache
! "Locators" 欄に両方の CP ノードの RLOC がリストされていることを確認
```

---

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

