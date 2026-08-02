---
layout: default
title: 2.2.d-Configuration-templates
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 4
---

# 2.2.d Configuration Templates

Cisco SD-WAN (Viptela) の運用における中核となるのが「テンプレート」です。従来のネットワーク管理がルータ一台一台へのCLI投入であったのに対し、SD-WANでは vManage 上で作成した論理的な設計図（テンプレート）を数百台のデバイスへ一括で適用（プロビジョニング）します。本稿では、CCIE EIラボ試験で必須となるテンプレートの構造、変数の扱い、およびデバイスへの紐付けプロセスを詳述します。

---

## 📘 概要

SD-WAN の設定管理は、**「Feature Template（機能テンプレート）」**と**「Device Template（デバイステンプレート）」**の二階層構造で成り立っています。

*   **Feature Template:** システム、NTP、BGP、VPN、インターフェイスなどの特定の機能単位の設定を定義するモジュールです。
*   **Device Template:** 複数の Feature Template を束ね、特定のデバイスモデル（cEdge, vEdge 等）に適用可能な完全な設定パッケージを作成したものです。
*   **CLI Template:** Feature Template を使用せず、使い慣れたルータのコンフィギュレーションをそのままテキストベースで流用する手法です。ただし、GUI の利便性は失われます。

これらのテンプレートを使用することで、設定の標準化が容易になり、人為的なミスを削減できます。また、**「変数（Variables）」**を用いることで、拠点ごとに異なる IP アドレスやホスト名を単一のテンプレートから動的に生成することが可能です。

---

## 🔑 要点

### 1. テンプレート内の値の種類 (i, ii)

Feature Template の各項目には、以下の 3 つのいずれかの値を指定できます。

| 値のタイプ | 説明 |
| :--- | :--- |
| **Default (デフォルト)** | 工場出荷時の標準値を使用します。変更不可。 |
| **Global (グローバル)** | そのテンプレートを使用する全デバイスで共通の値です（例：組織名、NTPサーバ）。 |
| **Device Specific (変数)** | <code>{{system_ip}}</code> のような形式で定義し、適用時にデバイスごとに個別の値を入力します。 |

### 2. Device Template の構成要素 (iii)

デバイステンプレートを作成する際、以下の 5 つのカテゴリに Feature Template を割り当てます。

1.  **Basic Information:** System (System-IP, Site-ID), Logging, AAA.
2.  **Transport & Management VPN:** VPN 0 (トランスポート), VPN 512 (管理用), およびそれぞれのインターフェイス設定.
3.  **Service VPN:** ユーザー用 VPN (VPN 1〜511) とルーティングプロトコル (OSPF, BGP, EIGRP).
4.  **Additional Templates:** SNMP, Security, Policy, Banner 等.

### 3. CLI テンプレートの使い分け (i)

*   **CLI テンプレート:** デバイスの全設定を CLI テキストで保持します。Feature テンプレートとの混在はできません。
*   **CLI Add-on テンプレート:** Device Template の一部として、Feature Template でサポートされていない細かい設定を部分的に CLI で補足する機能です.

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、vManage GUI 操作の正確さと、設定エラー発生時の CLI トラブルシューティング能力が試されます。

### 1. 必須テンプレートの欠落に注意

デバイステンプレートをデプロイするためには、**System、VPN 0、VPN 512** の 3 つの設定が最低限必須です。これらが不足していると、コントローラとの通信が維持できず、プロビジョニングに失敗します。

### 2. 変数入力の整合性

「Device Specific」として定義した項目は、テンプレートをデバイスにアタッチ（Attach）する際に CSV ファイルや画面入力で値を埋める必要があります。
*   **ラボの罠:** ルーティングで使用する <code>Router-ID</code> や <code>System-IP</code> が重複していると、OMP セッションがフラッピングし、コンバージェンスに影響を与えます。

### 3. テンプレート更新の影響範囲

すでにデバイスがアタッチされている Feature Template を編集して保存（Update）すると、そのテンプレートを参照している **すべてのデバイスに対して即座に設定変更がプッシュ** されます。
*   **注意:** 試験中、一台の挙動を変えようとして共通テンプレートを編集すると、ネットワーク全体の接続性に影響を及ぼす可能性があります。特定のデバイスのみ変更したい場合は、そのデバイス専用の Feature Template をコピー作成し、Device Template を編集して差し替えます。

### 4. cEdge (IOS-XE) 特有の挙動

cEdge では <code>sdwan</code> モードで動作しているため、CLI テンプレートを使用する場合、IOS-XE のネイティブコマンド形式で記述する必要があります。

---

## 🛠 設定・検証コマンド

テンプレートは vManage GUI で作成しますが、適用結果の確認や不具合調査は Edge デバイスの CLI で行います。

| 目的 | コマンド |
| :--- | :--- |
| **適用された全設定の確認** | <code>show sdwan running-config</code> |
| **テンプレート由来の設定確認(詳細)** | <code>show running-config</code> |
| **システム属性（System-IP等）の確認** | <code>show control local-properties</code> |
| **コントローラとの同期状態確認** | <code>show control connections</code> |
| **OMPによる学習ルートの確認** | <code>show omp routes</code> |
| **変数の反映状況確認** | <code>show sdwan running-config &#124; section system</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. System Feature Template の作成

**【問題】** 支店ルータ共通の System テンプレートを作成せよ。ホスト名と System-IP は個別に指定可能とし、サイト ID は適用時に手動入力せよ。
*   *操作:* `Configuration -> Templates -> Feature -> Add Template -> System`.
*   *設定:* 
    *   Site-ID: `Device Specific`.
    *   System-IP: `Device Specific`.
    *   Hostname: `Device Specific`.

---

### 2. Banner Feature Template の構成

**【問題】** 全ての vEdge デバイスに対し、ログイン時に「PNETLAB Authorized Users Only」というバナーを表示させよ.
*   *操作:* `Feature Template -> Banner`.
*   *設定:* 
    *   Banner: `Global` -> `PNETLAB Authorized Users Only !!!`.

---

### 3. VPN 0 (Transport) テンプレートとデフォルトルート

**【問題】** VPN 0 において、ネクストホップ `199.1.1.30` へのデフォルトルートを持つトランスポート VPN を構成せよ.
*   *設定項目:* `IPv4 Route -> Add New Route -> 0.0.0.0/0 -> Gateway -> 199.1.1.30`.

---

### 4. インターフェイステンプレート（Color 設定）

**【問題】** トランスポートリンク `ge0/0` を `mpls` 回線、`ge0/1` を `public-internet` 回線として、それぞれトンネルを有効化せよ.
*   *設定 (ge0/0):* `Tunnel Interface: On`, `Color: mpls`.
*   *設定 (ge0/1):* `Tunnel Interface: On`, `Color: biz-internet`.

---

### 5. VPN 512 (Management) の構成

**【問題】** アウトオブバンド管理用インターフェイス `eth0` を管理 VPN 512 で構成せよ.
*   *設定:* `VPN ID: 512`, `Interface: eth0`, `IPv4 Address: Static (Device Specific)`.

---

### 6. サービス VPN と OSPF の紐付け

**【問題】** ユーザー用 VPN 10 において OSPF Area 0 を動作させ、OMP ルートを再配送せよ.
*   *OSPF設定:* `Redistribute -> OMP: On`.
*   *エリア設定:* `Area 0 -> Add Interface -> ge0/2`.

---

### 7. Device Template の新規作成 (vEdge Cloud)

**【問題】** 上記で作成した各 Feature Template をまとめ、モデル「vEdge Cloud」用のデバイステンプレートを作成せよ.
*   *操作:* `Configuration -> Templates -> Device -> Create Template -> From Feature Template`.

---

### 8. デバイスのアタッチ (Attach Device)

**【問題】** 作成した Device Template を実際のルータ `BR1-vE1` に紐付けよ.
*   *操作:* デバイステンプレート横の `...` ➔ `Attach Devices` ➔ 対象デバイスを選択.

---

### 9. 変数（Variable）の一括修正

**【問題】** テンプレート適用時のプレビュー画面で、変数の不整合エラーが発生した。画面上の `Edit Device Template` から IP アドレス `10.2.200.119/24` を手動で修正して更新せよ.
*   *解説:* `Edit Device Template` 画面で入力項目を埋め、`Update` を押すことで最終的な設定が生成される.

---

### 10. BGP Feature Template の追加 (cEdge)

**【問題】** cEdge1 ルータに対し、AS 65001 の BGP ネイバー設定を Feature Template で追加せよ.
*   *操作:* `Device Template -> Edit -> BGP (Select Created Template)`.

---

### 11. MTU サイズの Feature テンプレートによる調整

**【問題】** WAN インターフェイスの MTU を 1496 に変更する設定を、既存の VPN インターフェイス Feature テンプレートに適用せよ.
*   *設定:* `Advanced -> IP MTU: 1496`.

---

### 12. CLI Add-on による例外設定の投入

**【問題】** Feature テンプレートに存在しない、特定の `service-type` 設定を CLI Add-on を使って既存の Device Template に追加せよ.
*   *操作:* `Device Template -> Additional Templates -> CLI Add-on Template`.

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENT-2296: Designing On-Prem SD-WAN Controllers**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2296) - テンプレート設計のベストプラクティス.
*   [**BRKENT-2081: Troubleshooting SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - テンプレート push エラーの診断手法.
*   [**DGTL-BRKRST-2559: 3 Steps to Design Cisco SD-WAN On-Prem**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2559) - 初期構築時のテンプレート運用.

### Configuration ガイド
*   [**Cisco vManage Template Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/vedge-20-x/system-interface-book/m-system-overview.html)
*   [**SD-WAN Feature Template Parameters Overview**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/system-interface/xe-17-9/systems-interfaces-guide-xe-17-9.html)。

### テクニカルドキュメント・設定例
*   [**SD-WAN Onboarding WAN Edge Devices (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html).
*   [**vManage API for Template Automation**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/vmanage-rest-api/vmanage-rest-api-overview.html).

---

## 📝 補足
- この学習メモは、SD-WAN テンプレートが「単なる自動化」ではなく、**「ネットワークの抽象化とモデル化」**であることを強調しています。CCIE EI 実技試験では、複雑な依存関係（Feature は Device に属し、Device は実機に属す）を迅速に構築し、不具合時に `show sdwan running-config` でコントローラから何が送られてきているかを即断できる能力が合格の決め手となります。

