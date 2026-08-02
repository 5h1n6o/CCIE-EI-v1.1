---
layout: default
title: 2.1.d-Fabric-deployment
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.1.d Cisco SD-Access Fabric Deployment

Cisco SD-Access (SDA) における **Fabric Deployment（ファブリック展開）** は、設計（Design）およびポリシー（Policy）フェーズで定義した内容を、実際のネットワークデバイスに適用し、エンドポイントを収容する実戦的な工程です。CCIE EI v1.1 ラボ試験では、DNA Center (DNAC) を用いたプロビジョニングの正確さと、その裏で動作するスイッチのステータス確認（CLI）の両面が厳しく問われます。

---

## 📘 概要

SD-Access の展開フェーズは、物理デバイスを「インベントリ」から「ファブリック」へと論理的に組み込む作業です。これには、コントロールプレーン、ボーダー、エッジといった役割（Role）の割り当てだけでなく、ユーザーやデバイスがネットワークに接続するための **Host Onboarding**、認証方式を定義する **Authentication Templates**、そして複数の拠点を跨ぐ **Multisite** 構成などが含まれます。

展開の成功は、アンダーレイの完全な到達性と、Cisco ISE と DNA Center 間の強固な連携に依存します。試験では、単に GUI でボタンをクリックするだけでなく、意図した SGT (Scalable Group Tag) が付与されているか、正しい VLAN/VN (Virtual Network) にエンドポイントがマッピングされているかを、パケットレベルやテーブルレベルで検証する能力が求められます。

---

## 🔑 要点

### 1. Host Onboarding (i)

エンドポイント（PC, IP Phone, IoTデバイス等）をファブリックに接続し、適切な通信環境を提供するためのプロセスです。
*   **Static vs. Dynamic:** 特定のポートを特定の VLAN/VN に固定する「Static」設定と、802.1X 認証等によって動的に割り当てる「Dynamic」設定があります。
*   **Anycast Gateway:** すべてのエッジノードで共通のゲートウェイ IP/MAC を使用し、ホストが移動しても設定変更なしで通信を継続させます。

### 2. Authentication Templates (ii)

エンドポイントが接続された際の認証・認可の挙動を定義するテンプレートです。
*   **Closed Mode:** 認証に成功するまでトラフィックを一切許可しない厳格なモード。
*   **Low Impact Mode:** 認証前でも特定のトラフィック（DHCP, DNS, ICMP等）を許可するモード。
*   **Monitor Mode:** 認証の成否にかかわらずトラフィックを通し、ログのみを取得するモード。
*   **No Authentication:** 認証を行わず、オープンに接続を許可します。

### 3. Port Configuration (iii)

ファブリックエッジノードの物理ポートに対し、役割に応じた設定を適用します。
*   **Fabric Port:** エンドポイントを接続するポート。認証テンプレートや SGT の適用ポイントとなります。
*   **Transit Port:** 外部ネットワーク（Border経由）や、Extended Node との接続に使用されます。

### 4. Multisite Remote Border (iv)

大規模または分散した環境において、ローカルにコントロールプレーンを持たない小規模拠点（Remote Site）が、中央サイトのコントロールプレーンを利用しながら外部接続を行う構成です。
*   **Border Priority:** 複数のボーダーが存在する場合、どのボーダーを優先的に使用するかを制御します。

### 5. Adding Devices to Fabric (vi)

インベントリにあるデバイスをファブリックサイトに割り当て、ロール（Role）を付与する作業です。
*   **Provisioning:** デバイスに対して、LISP, VXLAN, CTS などのファブリック動作に必要な一連の設定を一括プッシュします。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、展開における「論理的な矛盾」の解決が鍵となります。

### 1. ISE と DNAC の同期不全

*   **問題:** DNAC で作成した VN や SGT が ISE 側に反映されない、またはその逆。
*   **対策:** `pxGrid` プロトコルの状態と、信頼証明書（Trust Certificate）の交換状況を確認します。

### 2. VLAN to VN マッピングの不一致

*   **問題:** ホストが正しい VLAN に割り当てられているが、外部と通信できない。
*   **チェック:** スイッチ側で `show nve vni` を実行し、VLAN ID が正しい L2 VNI および L3 VNI（VRF）に紐付いているかを確認します。

### 3. Anycast GW の ARP 解決失敗

*   **問題:** `Anycast Gateway` への ping が通らない。
*   **深掘り:** エッジスイッチ上で `show ip interface vlan [ID]` を確認し、SVI が Up/Up であること、および `mac-address` が全エッジで共通の Anycast MAC になっているかを確認します。

### 4. 認証の順序とフォールバック

*   **シナリオ:** 「802.1X に失敗した場合は MAB に移行し、最終的には WebAuth を表示させよ」という要件。
*   **技術:** `Authentication Order` と `Priority` の設定順序が、DNAC テンプレートで正しく定義されているかが問われます。

---

## 🛠 設定・検証コマンド

DNAC での操作が主ですが、試験ではスイッチ上での確認が必須です。

### 認証・Host Onboarding 検証

| 目的 | コマンド |
| :--- | :--- |
| **ポートの認証状態確認** | <code>show authentication sessions interface [ID] details</code> |
| **SGT マッピングの確認** | <code>show cts role-based sgt-map all</code> |
| **デバイス追跡DBの確認** | <code>show device-tracking database [interface ID]</code> |
| **LISP EID 登録情報の確認** | <code>show lisp instance-id [ID] ipv4 server</code> |

### ファブリック・トンネル検証

| 目的 | コマンド |
| :--- | :--- |
| **VNI と VRF の対応確認** | <code>show nve vni</code> |
| **RLOC 到達性の確認** | <code>show lisp locator-table default</code> |
| **VXLAN ヘッダーカプセル化確認** | <code>show nve interface nve1</code> |
| **Anycast GW MAC の確認** | <code>show interface vlan [ID] &#124; include address</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. ISE と DNA Center の統合完了

**【問題内容】**
DNAC から ISE のポリシーを利用できるよう、両者の連携を完了させよ。

**【操作概念】**
DNAC の System -> Settings -> Authentication and Policy Servers にて ISE の IP と PxGrid パスワードを入力し、ISE 側で PxGrid クライアントの承認を行う。

---

### 2. ネットワーク階層の設計 (Site Design)

**【問題内容】**
「Global -> Japan -> Tokyo -> Building-1 -> Floor-1」の階層を作成せよ。

**【操作】**
Design -> Network Hierarchy 画面で各階層を定義する。Floor レベルまで作成しないと、無線 AP の配置などができない点に注意。

---

### 3. Virtual Network (VN) の作成と VRF 紐付け

**【問題内容】**
ユーザー用 VN 「Corp_Users」を作成し、内部的に VRF 「CORP」として動作するようにせよ。

**【操作】**
Policy -> Virtual Network 画面で VN を作成。この際、ISE 側の共有 SGT グループが含まれていることを確認する。

---

### 4. IP アドレスプールの予約

**【問題内容】**
「Building-1」サイトに対し、ホスト収容用の `172.16.10.0/24` を予約せよ。

**【操作】**
Design -> IP Address Pools で定義済みのグローバルプールから、サイト固有のサブネットを切り出す。

---

### 5. Control Plane / Border ノードのプロビジョニング

**【問題内容】**
スイッチ 「9300CB」 を Control Plane および Border Node として設定せよ。

**【操作】**
Provision -> Fabric 画面でデバイスを選択し、ロール（Control Plane, Border）を有効化してデプロイする。

---

### 6. Fabric Edge ノードの追加

**【問題内容】**
エッジスイッチ 「9300Edge」 をサイトに追加し、プロビジョニングを完了させよ。

**【操作】**
インベントリからデバイスを選択し、Floor-1 サイトに割り当て。プロビジョニング実行後、アンダーレイのルーティングが自動構成されることを確認。

---

### 7. Static Host Onboarding (VLAN固定)

**【問題内容】**
エッジスイッチのポート Gi1/0/10 に接続された PC を、VN 「Corp_Users」の VLAN 101 に静的に所属させよ。

**【操作】**
Provision -> Fabric -> Host Onboarding 画面で、ポートを「Static」として選択し、対応する VN と Pool を割り当てる。

---

### 8. Authentication Template の適用 (Low Impact)

**【問題内容】**
すべてのエッジポートに対し、認証前でも DHCP を許可する 「Low Impact」 テンプレートを適用せよ。

**【操作】**
Host Onboarding の設定にて、「Authentication Template」項目から 「Low Impact」 を選択し、全ポートにプッシュする。

---

### 9. Border Node での外部ルート再配送

**【問題内容】**
Border ノードにおいて、ファブリック内の EID 情報を外部の BGP ピアへ広報せよ。

**【CLI確認】**
```ios
! Borderスイッチ側での自動設定確認
router bgp [AS]
 address-family ipv4 vrf Corp_Users
  redistribute lisp
```


---

### 10. Multisite Remote Border の構成

**【問題内容】**
「Remote-Site-1」において、HQ のコントロールプレーンを参照する Remote Border を構成せよ。

**【操作】**
Fabric Site 設定にて 「Multisite」 を有効化し、該当デバイスを 「Remote Border」 として定義。中央の CP ノードの IP を指定する。

---

### 11. サービス VN 間の Macro-Segmentation 検証

**【問題内容】**
「VN_Finance」 と 「VN_Marketing」 間の通信が、デフォルトで拒否されていることを確認せよ。

**【検証】**
```ios
! Edgeスイッチで各VRFのルーティングテーブルを確認
show ip route vrf VN_Finance
! 他のVNのルートが存在しない（ルートリークがない）ことを確認
```


---

### 12. Micro-Segmentation (SGACL) の適用

**【問題内容】**
同一 VN 内において、SGT 4（Dev）から SGT 5（Manager）へのアクセスを拒否せよ。

**【操作概念】**
ISE 側で Matrix ポリシーを作成し、DNAC 経由でスイッチへプッシュ。
**【検証】**
```ios
show cts role-based permissions from 4 to 5
! "Deny" が適用されていることを確認
```


---

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


