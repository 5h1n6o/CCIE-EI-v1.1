---
layout: default
title: 2.2.a-Controller-architecture
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.2.a Cisco SD-WAN Controller Architecture

Cisco SD-Access と並び、Cisco SD-WAN は CCIE EI v1.1 の「Software Defined Infrastructure」セクションにおける最重要トピックの一つです。本メモでは、SD-WAN の頭脳となるコントローラ・アーキテクチャ（Management, Orchestration, Control プレーン）の技術詳細と、ラボ試験に向けた実戦的なポイントを整理します。

---

## 📘 概要

Cisco SD-Access がキャンパス内の自動化を担当するのに対し、**Cisco SD-WAN (Viptela)** は、広域網（WAN）の制御をソフトウェア定義の考え方で再構築します。その最大の特徴は、**コントロールプレーン、データプレーン、マネジメントプレーン、オーケストレーションプレーンを完全に分離**したアーキテクチャにあります。

従来のルータが個別に自律して動いていたのとは異なり、SD-WAN では中央のコントローラ群（vManage, vBond, vSmart）がポリシーとルーティングを管理し、エッジデバイス（cEdge/vEdge）はそれを受け取ってトラフィックを転送する役割に特化します。CCIE レベルでは、これらのコントローラ間の相互作用、証明書ベースの認証プロセス、およびテンプレートを使用した一括管理の仕組みを完璧に理解し、トラブルシューティングできる能力が求められます。

---

## 🔑 要点

### 1. Management Plane: vManage (i)

SD-WAN ネットワーク全体の **NMS (Network Management System)** です。
*   **集中管理:** GUI（Single Pane of Glass）を通じて、Day-0 から Day-N までの運用、設定、監視、ソフトウェアアップグレードを一元的に行います。
*   **テンプレート:** デバイスの設定を「Feature Template」や「Device Template」として定義し、数百台のエッジデバイスに一括でプッシュします。
*   **API:** REST API（RESTCONF）を提供し、外部ツールからの自動化を可能にします。

### 2. Orchestration Plane: vBond (ii)

ネットワーク全体の **調整役（Orchestrator）** であり、最初の接点です。
*   **認証の門番:** 新しく追加されたエッジデバイスが最初に接続する相手であり、ホワイトリストに基づいて認証を行います。
*   **NAT トラバーサル:** エッジデバイスが NAT の背後にいる場合、STUN のような仕組みでパブリック IP を学習し、他のコンポーネントに通知します。
*   **情報の配布:** 認証が完了すると、エッジデバイスに対し、接続すべき vManage と vSmart のリストを提供します。
*   **要件:** 公開 IP アドレス（または 1:1 NAT）を保持している必要があります。

### 3. Control Plane: vSmart (iii)

SD-WAN の **頭脳** であり、ルーティングの意思決定を行います。
*   **OMP (Overlay Management Protocol):** BGP に似た独自のプロトコルを使用して、エッジデバイス間でルート情報（TLOC, Service Routes 等）を交換します。
*   **ポリシーの強制:** 中央集中型のポリシー（Centralized Policy）を実行し、トラフィックエンジニアリングやサービスチェイニングを制御します。
*   **セッション:** vManage およびエッジデバイスと、DTLS または TLS による恒久的なコントロールコネクションを確立します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、コントローラの初期化からエッジデバイスのオンボーディング、そして正常に制御チャネルが確立されない原因の特定が頻出します。

### 1. 証明書と信頼関係 (The Trust Chain)

コントローラ間の通信には証明書（Certificate）が必須です。
*   **トラブルポイント:** **NTP の同期ミス**は、証明書の有効期限切れ（と誤認）を引き起こし、コントロールチャネルを遮断します。試験では必ず `show clock` や `show ntp` を確認してください。
*   **Organization-Name:** 全てのコントローラとエッジで **Org-Name が 1 文字でも異なると認証に失敗**します。これはラボのトラブルシューティングの定番です。

### 2. コントロールコネクションの確立プロセス

オンボーディングの流れを暗記する必要があります。
1.  Edge -> vBond (DTLS): 認証と他コントローラの情報取得（一時的セッション）。
2.  Edge -> vManage (TLS/DTLS): 管理・テンプレート同期（恒久的）。
3.  Edge -> vSmart (TLS/DTLS): OMP によるルート交換（恒久的）。
*   `show control connections` で、vBond とのセッションが消え（正常）、vManage/vSmart とのセッションが残っていることを確認します。

### 3. NAT 越えと vBond

*   vBond がエッジの NAT タイプを識別できない場合、データプレーン（IPsec トンネル）が形成されません。
*   ラボ要件で「エッジが NAT 環境にある」場合、vBond の到達性と、カプセル化（DTLS）の設定を確認します。

### 4. テンプレートの優先順位

*   CLI テンプレートと Feature テンプレートの混在はできません。
*   Device Template をアタッチする際、変数の入力（System IP, Site ID 等）に不整合があるとアタッチに失敗します。

---

## 🛠 設定・検証コマンド

### コントローラ初期化（CLI）

| 目的 | コマンド |
| :--- | :--- |
| **システム基本設定** | <code>system</code> <br> <code>system-ip [IP]</code> <br> <code>site-id [ID]</code> <br> <code>organization-name [NAME]</code> <br> <code>vbond [IP_OR_FQDN]</code> |
| **vBond 特有の設定** | <code>vbond [LOCAL_IP] local</code> |
| **VPN 0 (Transport) 構成** | <code>vpn 0</code> <br> <code>interface [INT]</code> <br> <code>ip address [IP/MASK]</code> <br> <code>tunnel-interface</code> <br> <code>encapsulation dtls</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **コントロールチャネル接続確認** | <code>show control connections</code> |
| **ローカルシステム属性の確認** | <code>show control local-properties</code> |
| **証明書のステータス確認** | <code>show certificate status</code> |
| **OMP ネイバー（vSmart）の確認** | <code>show omp peers</code> |
| **ルート情報の確認（OMP）** | <code>show omp routes</code> |
| **TLOC（トンネル終端）情報の確認** | <code>show omp tlocs</code> |

---

## 🧪 ラボ学習・設定サンプル例

CCIE Workbook シナリオ をベースとした、コントローラおよび初期構築の実装例です。

### 1. vManage システム初期化

**【問題】** vManage を起動し、組織名 "CCIE-LAB"、System-IP "1.1.1.1"、Site-ID "100" で構成せよ。
```ios
system
 organization-name CCIE-LAB
 system-ip         1.1.1.1
 site-id           100
 vbond             10.1.1.2
```

---

### 2. vBond のオーケストレーター指定

**【問題】** R2 を vBond として構成せよ。自身の IP は 10.1.1.2 とする。
```ios
system
 vbond 10.1.1.2 local
!
vpn 0
 interface ge0/0
  ip address 10.1.1.2/24
  tunnel-interface
   encapsulation dtls
  no shutdown
```

---

### 3. vSmart における OMP 有効化

**【問題】** vSmart で OMP を有効にし、cEdge からのルートを受信できるようにせよ（基本デフォルトだが明示的設定）。
```ios
system
 system-ip 1.1.1.3
 organization-name CCIE-LAB
 vbond 10.1.1.2
!
omp
 no shutdown
 graceful-restart
```

---

### 4. 証明書の署名リクエスト (CSR) 生成

**【問題】** vManage から各コントローラの CSR を生成し、外部 CA に送る準備をせよ。
*   *操作 (vManage GUI):* `Configuration -> Certificates -> Controllers -> Generate CSR`

---

### 5. Feature Template: System

**【問題】** 支店のエッジデバイス向けに、Site ID と Hostname を変数化した System テンプレートを作成せよ。
*   *設定項目:*
    *   Site ID: `{{site_id}}`
    *   Hostname: `{{hostname}}`

---

### 6. VPN 512 (Management) の構成

**【問題】** 管理用 VPN 512 を構成し、eth0 インターフェイスを有効化せよ。
```ios
vpn 512
 interface eth0
  ip address 192.168.1.10/24
  no shutdown
```

---

### 7. トランスポート VPN 0 のトンネル設定

**【問題】** MPLS 回線（Color: mpls）を使用したトンネルインターフェイスを構成せよ。
```ios
vpn 0
 interface ge0/0
  tunnel-interface
   color mpls
   encapsulation ipsec
```

---

### 8. コントロールコネクションのデバッグ

**【問題】** エッジデバイスが vSmart と接続できない原因を特定せよ。
```ios
# show control connections
! 期待される出力がない場合
# show control local-properties
! "certificate-status" が "Installed" になっているか確認
```

---

### 9. デバイスに対するテンプレートのアタッチ

**【問題】** 作成した Device Template を vEdge-1 に適用し、System-IP "10.10.10.1" を設定せよ。
*   *操作 (vManage GUI):* `Configuration -> Templates -> Device -> Attach Devices`

---

### 10. OMP ルートのフィルタリング検証

**【問題】** vSmart 上で特定の TLOC からのルートが破棄されていないか確認せよ。
```ios
# show omp routes
! Status に "Inv" (Invalid) や "R" (Rejected) が付いていないかチェック
```

---

### 11. cEdge (CSR1000v) のオンボーディング

**【問題】** Cisco IOS-XE ベースの cEdge を SD-WAN モードで起動し、vManage に登録せよ。
```ios
! cEdge CLI
controller
 vbond 10.1.1.2
 organization-name CCIE-LAB
```

---

### 12. NTP 同期による整合性確保

**【問題】** コントローラ間の時刻不整合を防ぐため、10.1.1.100 を NTP サーバとして設定せよ。
```ios
system
 ntp
  server 10.1.1.100 version 4
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - コントロールコネクションと証明書のトラブル解決。
*   [**BRKENT-2296: Designing Cisco SD-WAN Controllers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2296) - コントローラの配置設計と冗長化。
*   [**BRKRST-2559: 3 Steps to Design Cisco SD-WAN On-Prem**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2559) - オンプレミス環境での構築手順。

### Configuration ガイド
*   [**Cisco SD-WAN Controller Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/sd-wan-controller-deployment-guide.html)
*   [**Cisco SD-WAN Overlay Management Protocol (OMP) Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/vEdge-20-x/routing-book/m-routing-omp.html)

### テクニカルドキュメント・設定例
*   [**SD-WAN Control Connection Troubleshooting (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)
*   [**Organization Name and Certificate Validation in SD-WAN**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/215321-sd-wan-certificate-management-and-troubl.html)

---

## 📝 補足
- この学習メモは、SD-WAN の「心臓部」であるコントローラ群の動作を、CCIE ラボ試験での実技・トラブルシュート視点で整理したものです。特に **証明書の信頼（Certificate Trust）** と **OMP の正常性** を CLI で即座に判断できるようにすることが、試験合格の鍵となります。


