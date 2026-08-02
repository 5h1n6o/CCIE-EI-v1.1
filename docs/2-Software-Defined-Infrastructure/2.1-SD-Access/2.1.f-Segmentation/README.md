---
layout: default
title: 2.1.f-Segmentation
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 6
---

# 2.1.f Segmentation

Cisco SD-Access（SDA）におけるセグメンテーション（Segmentation）は、ネットワーク全体のセキュリティと管理性を高めるための中核機能です。本メモでは、仮想ネットワーク（VN）を用いた「マクロセグメンテーション」と、SGT/SGACLを用いた「マイクロセグメンテーション」の技術詳細、試験対策、および実装検証について詳述します。

---

## 📘 概要

SD-Accessにおけるセグメンテーションは、従来のVLANやACLに依存した管理から、アイデンティティ（Identity）に基づいた論理的な分離へと進化しています。このアーキテクチャは、以下の2つの階層で構成されます。

1.  **マクロセグメンテーション (Macro Segmentation):** **Virtual Network (VN)** を使用して、ネットワーク全体を大きな論理グループ（例：従業員、ゲスト、IoT、機密部門）に分割します。技術的にはファブリック内の **VRF (Virtual Routing and Forwarding)** と **VXLAN VNI** の紐付けによって実現され、異なる VN 間の通信はデフォルトで完全に遮断されます。
2.  **マイクロセグメンテーション (Micro-level Segmentation):** 同一の VN（VRF）内において、ユーザーやデバイスの役割（Role）に基づいてさらに細かい制御を行います。これには **Scalable Group Tag (SGT)** と **Scalable Group ACL (SGACL)** が使用され、IPアドレスに依存しない柔軟なポリシー適用を可能にします。

CCIE EIラボ試験では、Cisco DNA Center (DNAC) と Identity Services Engine (ISE) を連携させ、これらのポリシーを正確にデプロイし、トラブルシューティングする能力が問われます。

---

## 🔑 要点

### 1. Macro Segmentation using Virtual Networks (i)

*   **論理的な分離:** VN はファブリック内では VRF として実装されます。
*   **VXLAN の役割:** データプレーンにおいて、パケットは Layer 2 VNI（VLAN相当）および Layer 3 VNI（VRF相当）を含む VXLAN ヘッダーでカプセル化されます。
*   **通信の制御:** 異なる VN 間で通信が必要な場合は、ファブリック外の **Fusion Router (フュージョンルータ)** において BGP 再配送やスタティックルートを用いたルートリーク（Route Leaking）を行う必要があります。
*   **Anycast Gateway:** 各 VN ごとにエッジノードで共通のデフォルトゲートウェイが保持されます。

### 2. Micro-level Segmentation using SGTs and SGACLs (ii)

*   **SGT (Scalable Group Tag):** ユーザーが認証（802.1X/MAB）される際、ISE によって割り当てられる 16 ビットの識別子です。
*   **VXLAN-GPO:** SD-Access では、VXLAN ヘッダー内の予約フィールドを使用して SGT を運びます。これを **VXLAN Group Policy Option** と呼び、タグ情報をネットワーク全体で保持することを可能にします。
*   **SGACL (Scalable Group ACL):** 「ソース SGT」から「宛先 SGT」へのアクセス許可・拒否を定義するポリシーです。
*   **Egress Enforcement:** SGACL は通常、パケットが宛先に到達する直前の **エッジノード（Egress）** で適用されます。これにより、中間ネットワークの負荷を軽減します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単なる設定手順だけでなく、コンポーネント間の「信頼関係」と「同期」が重要になります。

### 1. ISE と DNA Center の pxGrid 連携

*   DNAC で作成した VN や SGT を ISE に反映させ、逆に ISE で定義したポリシーをファブリックにプッシュするためには、**pxGrid** による統合が不可欠です。
*   **ラボの罠:** 証明書の不一致や pxGrid クライアントの承認漏れにより、SGT がスイッチに配布されないシナリオが想定されます。

### 2. 外部ネットワークとのハンドオフ (L3 Handoff)

*   ファブリック内の VN を外部（共有サービスやインターネット）に繋ぐ際、Border ノードでの VRF 定義と BGP ピアリングが問われます。
*   Fusion ルータにおけるルートリーク設定において、戻りルート（Reverse route）を忘れると、セグメンテーションは成功しても通信が成立しません。

### 3. SGT 伝播 (Propagation) の検証

*   ファブリック内のデバイスだけでなく、SGT を認識しないレガシーなスイッチを通過する場合の挙動（SXP: SGT Exchange Protocol）の構成が求められることがあります。
*   `show cts role-based sgt-map all` 等のコマンドを用いて、期待通りのタグが IP に紐付いているかを確認するスキルが必要です。

---

## 🛠 設定・検証コマンド

SD-Access のポリシー制御は自動化されていますが、検証には CLI が多用されます。

### マクロセグメンテーション（VN/VRF）検証

| 目的 | コマンド |
| :--- | :--- |
| **VNI と VRF の紐付け確認** | <code>show nve vni</code> |
| **VN ごとのルーティングテーブル確認** | <code>show ip route vrf [VN_NAME]</code> |
| **LISP EID 登録状況の確認** | <code>show lisp instance-id [ID] ipv4 server</code> |
| **Anycast GW の状態確認** | <code>show ip interface vlan [VLAN_ID]</code> |

### マイクロセグメンテーション（SGT/CTS）検証

| 目的 | コマンド |
| :--- | :--- |
| **IP と SGT のマッピング確認** | <code>show cts role-based sgt-map all</code> |
| **スイッチに適用された SGACL の確認** | <code>show cts role-based permissions</code> |
| **ISE からの環境データ取得確認** | <code>show cts environment-data</code> |
| **インターフェイスの CTS 設定確認** | <code>show cts interface [ID]</code> |
| **SXP 接続状態の確認** | <code>show cts sxp connections brief</code> |

---

## 🧪 ラボ学習・設定サンプル例


### 1. ISE と DNA Center の統合 (System Integration)

**【タスク】**
DNAC 上で ISE をポリシーサーバとして登録し、pxGrid サービスを有効化せよ。
*   **操作:** DNAC ⚙ -> System -> Settings -> Authentication and Policy Servers。

---

### 2. Virtual Network (VN) の作成

**【タスク】**
「VN_Engineering」および「VN_Sales」という 2 つの VN を作成せよ。
*   **DNAC操作:** Policy -> Virtual Network -> Add VN。この際、ISE のスキャルグループを選択する。

---

### 3. SGT (Scalable Group Tag) の定義

**【タスク】**
ISE 側で 「Dev_User (SGT 10)」 および 「Dev_Server (SGT 20)」 というタグを作成せよ。
*   **ISE操作:** Work Centers -> TrustSec -> Components -> Security Groups。

---

### 4. VN への SGT 割り当て

**【タスク】**
作成した SGT を 「VN_Engineering」 VN に所属させ、プロビジョニングを実行せよ。
*   **効果:** これにより、該当 VN の VXLAN トンネル内でこれらの SGT タグの使用が許可される。

---

### 5. SGACL ポリシーの作成

**【タスク】**
SGT 10 (Dev_User) から SGT 20 (Dev_Server) への通信において、ICMP のみを許可し、他を拒否するポリシーを作成せよ。
*   **ISE操作:** Work Centers -> TrustSec -> TrustSec Policy -> Matrix。

---

### 6. Fusion Router でのルートリーク構成 (Macro)

**【タスク】**
Fusion ルータにおいて、VN_Engineering から 共有サービス（DHCP/ISE）への到達性を確保せよ。
*   **CLI例:**
```ios
router bgp 65001
 address-family ipv4 vrf VN_Engineering
  import vrf Shared_Service route-map RM_ALLOW_DHCP
```

---

### 7. Host Onboarding による静的 SGT 割り当て

**【タスク】**
Edge スイッチの Gi1/0/5 ポートを SGT 10 (Dev_User) に固定的に割り当てよ。
*   **DNAC操作:** Provision -> Fabric -> Host Onboarding。

---

### 8. スイッチでの SGACL 適用確認 (Verification)

**【タスク】**
Edge スイッチ上で、ISE からプッシュされた SGACL ポリシーが正しくインストールされているか確認せよ。
*   **検証コマンド:** <code>show cts role-based permissions from 10 to 20</code>

---

### 9. 異なる VN 間の分離テスト

**【タスク】**
「VN_Sales」のホストから「VN_Engineering」のゲートウェイへの疎通が、Fusion ルータの設定なしでは失敗することを確認せよ。
*   **検証:** 各 VRF のルーティングテーブルを比較し、相互のルートが存在しないことを確認する。

---

### 10. SXP (SGT Exchange Protocol) の構成

**【タスク】**
SGT タグ付けをサポートしない Core スイッチを経由するため、Border と Fusion 間で SXP ピアリングを確立せよ。
*   **CLI例:** <code>cts sxp connection peer [IP] password simple [PWD] mode local speaker</code>

---

### 11. CTS Credentials の同期トラブル解決

**【タスク】**
スイッチが ISE から SGT リストをダウンロードできない問題を解決せよ。
*   **原因:** `cts credentials` や RADIUS キーの不一致を確認する。
*   **検証:** <code>show cts environment-data</code> で "Incomplete" 状態をチェック。

---

### 12. VXLAN カプセル化パケットの解析 (Deep Dive)

**【タスク】**
パケットキャプチャを用いて、VXLAN ヘッダー内に正しい VNI と SGT が含まれているか検証せよ。
*   **解析ポイント:** VXLAN-GPO ヘッダーの 16 ビット Group Policy ID フィールドを確認。

---

## 📘 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076) - セグメンテーション設計のベストプラクティス。
*   [**BRKCRS-2810: Cisco SD-Access Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810) - ポリシー適用のデバッグ手法。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - ラボ試験特化のセグメンテーション解説。

### Configuration ガイド
*   [**Software-Defined Access Macro Segmentation Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)。
*   [**Cisco TrustSec (SGT/SGACL) Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg/m_cts_sgt_config.html)。

### テクニカルドキュメント・設定例
*   [**SDA Segmentation Policy Overview (Cisco White Paper)**](https://www.cisco.com/c/en/us/products/collateral/cloud-systems-management/dna-center/white-paper-c11-740585.pdf)。
*   [**Troubleshooting SD-Access Macro and Micro Segmentation**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)。

---
## 📝 補足

- この学習メモは、SD-Access セグメンテーションの二重構造（Macro/Micro）を網羅しています。CCIE 実技試験においては、特に **ISE とスイッチ間の CTS（TrustSec）通信状態** や、**Fusion ルータでの VRF リーキング** が配点の高いポイントとなるため、CLI での確認コマンドを完全に習得しておくことが合格の鍵となります。


