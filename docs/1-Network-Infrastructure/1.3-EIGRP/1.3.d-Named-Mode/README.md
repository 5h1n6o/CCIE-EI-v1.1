---
layout: default
title: 1.3.d-Named-Mode
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

1.3.d EIGRP Named Mode

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.3 EIGRP」における「1.3.d EIGRP named mode」について整理しました。

---

## 📘 概要

**EIGRP Named Mode（名前付きモード）**は、従来のAS番号ベースのコンフィギュレーション（Classic Mode）に代わる、モダンで階層的な設定フレームワークです。従来の方式では、グローバルなルーティングプロセス、インターフェイス設定、およびアドレスファミリー（IPv4/IPv6）の設定がルータのコンフィギュレーション全体に散在していましたが、Named Modeではこれらすべてを `router eigrp [NAME]` という一つのインスタンス配下に統合します。

最大の技術的進歩は、**Wide Metrics（ワイドメトリック）**の導入です。これは64ビットの計算精度を持ち、1Gbpsを超える高速リンクにおいて従来の32ビットメトリックが飽和（計算上限に達し、経路の優劣が付けられなくなる現象）する問題を解決します。また、VRF（Virtual Routing and Forwarding）の管理や、IPv4/IPv6のMulti-AF（マルチアドレスファミリー）構成を極めて直感的に記述できるため、CCIEラボ試験のような複雑なセグメンテーション要件において非常に強力なツールとなります。

---

## 🔑 要点

### 1. 名前付きモードの階層構造

Named Modeは以下の3つの主要なレベルで構成されます。

| 設定レベル | コマンド例 | 役割 |
| :--- | :--- | :--- |
| **Address Family (AF)** | <code>address-family ipv4 unicast autonomous-system 100</code> | 特定のプロトコルバージョン(IPv4/IPv6)とAS番号を定義します。VRFもここで指定します。 |
| **AF-Interface** | <code>af-interface GigabitEthernet0/1</code> | タイマー、認証（SHA-256等）、パッシブ設定、集約など、インターフェイス固有の属性を管理します。 |
| **Topology Base** | <code>topology base</code> | ルートの再配送、Variance（不等コスト負荷分散）、メトリックの最大ホップ数など、RIBへの登録に関わるロジックを制御します。 |

### 2. Wide Metrics (64-bit精度)

従来の「Classic Metrics」と新しい「Wide Metrics」には明確な違いがあります。

*   **遅延の単位:** Classicでは「10マイクロ秒」単位でしたが、Wideでは「1ピコ秒 (10^-12)」単位で計算されます。
*   **K値の拡張:** スループットを正確に反映するためにK6が追加されていますが、デフォルトの計算には影響しません。
*   **rib-scale:** 64ビットの巨大なメトリック値を、従来のルーティングテーブル（RIB）に適合させるために、`metric rib-scale` コマンドで値を圧縮して格納します（デフォルトは128倍）。

### 3. 下位互換性と移行

Named ModeルータとClassic Modeルータは、**同じAS番号を使用していれば隣接関係を確立できます**。Named Mode側は、Wide Metricsを送信する際に自動的にClassic形式へダウンスケールして送信するため、混在環境でも動作に支障はありません。

### 4. 高度なセキュリティ

Named Modeは、従来のMD5認証に加え、より強固な **HMAC-SHA-256 認証** をネイティブでサポートしています。Key-chainを使用せずに直接パスワードを指定できる柔軟性も持ち合わせています。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験において、EIGRP Named Modeは単独のタスクとしてだけでなく、SD-WANのアンダーレイや、複雑な再配送、VRF間のルートリーキングの文脈で出題されます。

### 1. Classic から Named への移行 (Migration)

「既存のEIGRP構成を維持したまま、設定をNamed Modeへアップグレードせよ」というタスクが想定されます。
*   **コマンド:** `eigrp upgrade-cli [NAME]` を使用すると、既存の設定を維持したまま自動的に変換されます。この際、隣接関係が一時的に切断される挙動を把握しておく必要があります。

### 2. インターフェイス・デフォルトの活用

ラボでの「最小コマンド数」の制約に対し、Named Modeの `af-interface default` は非常に有効です。
*   **例:** 「すべてのインターフェイスをパッシブにし、Gigabit0/1のみ有効化せよ」。
*   **対策:** `af-interface default` で `passive-interface` を設定し、`af-interface Gigabit0/1` で `no passive-interface` と記述します。

### 3. Wide Metrics と Traffic Engineering

高速リンクが複数あるトポロジにおいて、従来のメトリックではコストが同一になってしまうケースを Wide Metrics で解決する能力が問われます。
*   `delay` をピコ秒単位で微調整し、バックアップパス（Feasible Successor）を意図的に作成するスキルが必要です。

### 4. VRF-Aware なルーティング構成

「VRF 'Blue' と VRF 'Red' でそれぞれ異なるAS番号のEIGRPを動作させよ」といったセグメンテーション要件。
*   `address-family ipv4 vrf [NAME]` 配下でのAS番号の一致と、Router-IDの一意性がポイントになります。

---

## 🛠 設定・検証コマンド

### 基本構成コマンド

| 目的 | コマンド |
| :--- | :--- |
| **名前付きインスタンスの作成** | <code>router eigrp [NAME]</code> |
| **アドレスファミリーの有効化** | <code>address-family ipv4 unicast autonomous-system [AS]</code> |
| **インターフェイス設定モードへの移行** | <code>af-interface [Interface-ID &#124; default]</code> |
| **トポロジ（RIB制御）モードへの移行** | <code>topology base</code> |
| **VRF内でのEIGRP有効化** | <code>address-family ipv4 vrf [VRF_NAME] autonomous-system [AS]</code> |

### パラメータ制御コマンド (AF配下)

| 目的 | コマンド |
| :--- | :--- |
| **SHA-256 認証の設定** | <code>authentication mode hmac-sha-256 [PASSWORD]</code> |
| **手動集約の設定** | <code>summary-address [IP] [MASK] [leak-map MAP_NAME]</code> |
| **不等コスト負荷分散 (Variance)** | <code>variance [MULTIPLIER]</code> |
| **再配送の実施** | <code>redistribute [protocol] [process-id] route-map [MAP]</code> |
| **RIBスケーリングの変更** | <code>metric rib-scale [VALUE]</code> |

### 検証・デバッグコマンド

| 目的 | コマンド |
| :--- | :--- |
| **Named Modeの構成確認** | <code>show eigrp address-family ipv4 [vrf NAME] [AS]</code> |
| **Wide Metric詳細情報の確認** | <code>show ip eigrp topology [prefix]</code> |
| **インターフェイス別の詳細ステータス** | <code>show ip eigrp interfaces detail [ID]</code> |
| **ネイバーの uptime/タイマー確認** | <code>show ip eigrp neighbors detail</code> |
| **クラシックからの移行ログ確認** | <code>show ip eigrp events</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIEラボ試験で頻出するシナリオに基づき、12個の高度な設定サンプルを提示します。

### 1. 基本的な Named Mode の初期化

**【問題内容】**
インスタンス名「CCIE_FABRIC」、AS番号 100 を使用して、10.0.0.0/8 ネットワークに属するすべてのインターフェイスで EIGRP を有効化せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  network 10.0.0.0 0.255.255.255
 exit-address-family
```

---

### 2. af-interface default を用いた一括制御

**【問題内容】**
すべてのインターフェイスをデフォルトでパッシブにし、GigabitEthernet0/1 のみで隣接関係を許可せよ。また、全インターフェイスで Hello 周期を 1秒に変更せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   passive-interface
   hello-interval 1
  af-interface GigabitEthernet0/1
   no passive-interface
```

---

### 3. HMAC-SHA-256 による強固な認証

**【問題内容】**
R1 と R2 の間で SHA-256 アルゴリズムを用いて、パスワード「Cisco@Lab123」による認証を構成せよ。Key-chain は使用してはならない。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   authentication mode hmac-sha-256 Cisco@Lab123
```

---

### 4. VRF セグメンテーション環境の実装

**【問題内容】**
VRF 'GUEST' 内において、AS番号 500 を用いた EIGRP を動作させ、Router-ID を 10.5.5.5 に固定せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_TENANT
 address-family ipv4 vrf GUEST autonomous-system 500
  eigrp router-id 10.5.5.5
  network 192.168.10.0 0.0.0.255
 exit-address-family
```

---

### 5. Wide Metrics の rib-scale 操作

**【問題内容】**
高速リンク網において、Wide Metrics の計算精度を RIB に反映させるため、rib-scale 値をデフォルトの 128 から 50 に変更せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   metric rib-scale 50
```

---

### 6. 集約ルートと Leak-Map の併用

**【問題内容】**
インターフェイス GigabitEthernet0/2 において、172.16.0.0/16 の要約ルートを広報せよ。ただし、特定のプレフィックス 172.16.50.0/24 だけは集約せずに詳細ルートとして広報（リーク）させよ。

**【設定サンプル】**
```ios
ip prefix-list P-LEAK permit 172.16.50.0/24
!
route-map RM-LEAK permit 10
 match ip address prefix-list P-LEAK
!
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/2
   summary-address 172.16.0.0 255.255.0.0 leak-map RM-LEAK
```

---

### 7. Variance による不等コスト負荷分散 (UCLB)

**【問題内容】**
Successor のメトリックの 4倍以内のコストを持つ Feasible Successor をすべてルーティングテーブルにインストールせよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   variance 4
```

---

### 8. Named Mode 環境での BGP 再配送

**【問題内容】**
BGP AS 65000 のルートを EIGRP へ再配送せよ。メトリックは帯域幅 1Gbps、遅延 10マイクロ秒、信頼性 255、負荷 1、MTU 1500 とすること。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   redistribute bgp 65000 metric 1000000 1 255 1 1500
```

---

### 9. Stub ルータ構成による Query スコープの制限

**【問題内容】**
拠点ルータ R6 を Stub ルータとして設定し、直結（Connected）および集約（Summary）ルートのみを広告するようにせよ。また、特定のリークマップを適用して、制限を緩和せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_BRANCH
 address-family ipv4 unicast autonomous-system 200
  eigrp stub connected summary leak-map SPECIAL_ROUTES
```

---

### 10. Offset-List による受信ルートのメトリック操作

**【問題内容】**
GigabitEthernet0/1 から受信する 10.1.1.0/24 のルートに対し、メトリックに 50000 を加算して優先順位を下げよ。

**【設定サンプル】**
```ios
access-list 10 permit 10.1.1.0 0.0.0.255
!
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   offset-list 10 in 50000 GigabitEthernet0/1
```

---

### 11. BFD (Bidirectional Forwarding Detection) の統合

**【問題内容】**
隣接ルータとの障害検知を高速化するため、特定のインターフェイスで BFD を有効化せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   bfd
```

---

### 12. Maximum Hops の制限

**【問題内容】**
EIGRP ドメイン内でのルーティングループの被害を最小限に抑えるため、有効なルートの最大ホップ数を 50 に制限せよ（デフォルトは100）。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   metric maximum-hops 50
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide - Named Mode (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book/ire-named-config.html)
*   [EIGRP Wide Metrics White Paper (Technical Note)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/118847-tech-note-eigrp-00.html)

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP and EIGRP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - EIGRPのDUALとNamed Modeの深い技術解説。
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - 移行（Migration）時のトラブルシュート事例。

### テクニカルドキュメント・設定例
*   [EIGRP Named Mode Configuration Example (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/200156-Configure-EIGRP-Named-Mode.html)。
*   [Understanding EIGRP SHA-256 Authentication](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book/ire-sha256.html)。

---

## 📝 補足
- この学習メモは、EIGRP Named Modeが単なる「設定形式の変更」ではなく、高速ネットワークにおける「メトリック精度の向上」と「管理の統合」を目的とした進化であることを強調しています。CCIE実技試験では、この階層構造を正確に使い分けることで、効率的かつミスのない設定を行うことが合格への鍵となります。


