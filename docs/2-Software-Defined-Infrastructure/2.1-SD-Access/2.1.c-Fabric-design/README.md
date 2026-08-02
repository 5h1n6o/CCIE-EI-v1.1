---
layout: default
title: 2.1.c-Fabric-design
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 3
---

# 2.1.c Cisco SD-Access Fabric Design

Cisco SD-Access（Software-Defined Access）における **Fabric Design（ファブリック設計）** は、ネットワークの規模、地理的配置、および可用性の要件に基づいて、コントロールプレーン、ボーダー、エッジの各ノードを最適に配置するプロセスです。本稿では、CCIE EI v1.1の試験範囲である「Single-site」「Multisite」「Fabric in a Box」の設計モデルと、それぞれの実装上の勘所を詳述します。

---

## 📘 概要

SD-Accessのファブリック設計は、従来の「アクセス・ディストリビューション・コア」という物理的な階層構造から、**「アンダーレイ、オーバーレイ、ファブリックロール」**という論理的な機能分離への転換を意味します。

設計の核心は、エンドポイントの情報を管理する「どこに（Location）」と「誰が（Identity）」を分離し、それをパブリッシュ/サブスクライブ・モデル（LISP）で実現することにあります。CCIEレベルの設計では、単一の建物を対象とした「Single-site」から、広域網を跨いで複数のファブリックを統合する「Multisite」、さらにはリソースの限られた小規模拠点向けの「Fabric in a Box」まで、環境に応じた最適なコンポーネント配置と冗長化手法を選択できる能力が問われます。

---

## 🔑 要点

### 1. Single-site Campus (i)

単一の物理的な場所（建物やキャンパス）内に構築される最も基本的なファブリック設計です。

*   **ノード配置:** コントロールプレーン（CP）、ボーダー（BN）、エッジ（EN）を個別のデバイス、または冗長化されたペアとして配置します。
*   **Anycast Gateway:** すべてのエッジノードで同じIP/MACゲートウェイを保持し、サイト内でのシームレスなモビリティを提供します。
*   **Border Nodeの種類:** 
    *   **Internal Border:** ファブリック内の他のVN（Virtual Network）やサイトと接続。
    *   **External Border:** インターネットや共有サービス（ファブリック外）と接続。
    *   **Anywhere Border:** 両方の機能を兼ね備える。

### 2. Multisite (ii)

地理的に離れた複数のSD-Accessサイトを、共通のポリシー管理下で統合する設計です。

*   **Transit Network:** サイト間を接続するネットワーク。「SDA Transit（LISPベース）」、「SD-WAN Transit」、または「IP Transit（VRF-Lite/BGPベース）」を選択します。
*   **Control Plane設計:** 各サイトにローカルなCPを置くのが一般的ですが、SD-WAN等を利用して一元管理する場合もあります。
*   **RLOC Reachability:** 異なるサイトのエッジノード間で、アンダーレイのLoopback（RLOC）が通信可能である必要があります。

### 3. Fabric in a Box (FiaB) (iii)

1台（またはStack）のスイッチ上に、CP、Border、Edgeのすべてのロールを集約する設計です。

*   **用途:** ルータやスイッチを複数台置くスペースやコストが限られる、小規模な支店や小規模オフィス（例：50ユーザー未満）に最適です。
*   **制約:** 単一デバイスに負荷が集中するため、デバイスのCPU/メモリ要件に注意が必要です（Catalyst 9300/9400/9500等でサポート）。

---

## 🎯 試験対策 (CCIE EIレベル)

ラボ試験において、設計トピックは「要件を満たす適切なノードのプロビジョニング」として出題されます。

### 1. フュージョンルータ (Fusion Router) の役割

Borderノードの背後に位置し、ファブリック内のVRF（VN）と外部の共有サービス間のルートリーク（再配送）を担います。
*   **試験のポイント:** Borderノード自体はVRF対応ですが、外部の共有サービス（DHCP, DNS, ISE, DNAC）は通常「Global Routing Table」に存在します。これらを繋ぐためのBGPピアリングとルートマップの構成が必須です。

### 2. コントロールプレーンの冗長化

 Map-Server/Map-Resolver の冗長化は、SD-Accessの可用性を決定づけます。
*   **実装:** 2台のCPノードを構成し、エッジノードが両方に登録（Map-Register）を送るよう設定されているかを確認します。

### 3. ボーダーノードの選定

「外部ネットワークへのデフォルトルートをどこから学習させるか」という要件に対し、External Borderを適切に配置し、`default-information originate` 相当のLISP設定が正しくDNACからプッシュされているかを検証します。

### 4. サイト間のスケーラビリティ

Multisite環境において、特定のVNトラフィックのみを特定のサイトへ転送するといった「トラフィックエンジニアリング」が、BGPの属性操作（Local Preference等）を用いて問われる可能性があります。

---

## 🛠 設定・検証コマンド

SD-AccessはDNA Center経由の設定が主ですが、CCIEラボでは「なぜ動かないのか」を突き止めるためにCLIでの検証が不可欠です。

### ファブリックロール・登録確認

| 目的 | コマンド |
| :--- | :--- |
| **LISPサイト登録状況の確認(CP)** | <code>show lisp instance-id [ID] ipv4 server</code> |
| **VNIとVRFのマッピング確認** | <code>show nve vni</code> |
| **RLOC（自身のアドレス）の確認** | <code>show lisp locator-table default</code> |
| **現在のマップキャッシュ確認(EN)** | <code>show ip lisp map-cache</code> |
| **ボーダーと外部のBGP接続確認** | <code>show ip bgp vrf [VN_NAME] summary</code> |

### Fabric in a Box 特有の確認

| 目的 | コマンド |
| :--- | :--- |
| **統合ロールのステータス確認** | <code>show device-tracking database</code> |
| **ローカルループバック通信の確認** | <code>show lisp instance-id [ID] ipv4 database</code> |

---

## 🧪 ラボ学習・設定サンプル例

ソース資料（Narbik Workbook, Kbits等）および実技試験シナリオをベースにした、設計・実装の12ステップです。

### 1. DNA Center でのネットワーク階層 (Hierarchy) の作成

**【問題】**
Global サイトの下に「HQ-Campus」サイト、さらにその下に「Building-1」を作成せよ。

**【設定の考え方】**
DNACの Design -> Network Hierarchy 画面で行います。これにより、共通のAAA/DHCPサーバ設定が下位階層に継承されます。

---

### 2. IP アドレスプールの予約

**【問題】**
HQサイト向けに、アンダーレイ用の `10.1.1.0/24` と、オーバーレイ（VN_Users）用の `172.16.10.0/24` を予約せよ。

**【設定の考え方】**
Design -> IP Address Pools でグローバルプールを定義し、各サイトに割り振ります。

---

### 3. Single-site におけるノードロールの割り当て

**【問題】**
SW1を「Control Plane Node」および「External Border Node」として構成せよ。

**【操作】**
Provision -> Fabric -> Fabric Site を選択し、デバイスをドラッグ＆ドロップして役割（CP, Border）を選択し、外部ASとの接続パラメータ（BGP）を入力します。

---

### 4. Fabric-in-a-Box のプロビジョニング

**【問題】**
支店のスイッチ Branch-SW1 において、1台で全ロール（CP, Border, Edge）を動作させるように設定せよ。

**【操作】**
DNAC上でサイトタイプを「Fabric in a Box」として定義するか、同一デバイスにすべてのチェックボックスをオンにしてデプロイします。

---

### 5. フュージョンルータとの BGP ピアリング (L3 Handoff)

**【問題】**
BorderノードとFusionルータ間で、VRF `Corporate` のルートを交換するよう構成せよ。

**【CLI設定例（Border側自動生成の一部）】**
```ios
router bgp 65001
 address-family ipv4 vrf Corporate
  neighbor 192.168.1.2 remote-as 65002
  neighbor 192.168.1.2 activate
  redistribute lisp
```

---

### 6. Multisite: SDA Transit の構成

**【問題】**
サイトAとサイトBを、LISPベースの SDA Transit を用いて接続せよ。サイト間での SGT 伝播を有効にすること。

**【設定コンセプト】**
Provision -> Transit で「SDA」を選択し、サイトを関連付けます。内部的には、サイト間のCPノード間でMap-Serverの階層構造（Inter-site）が形成されます。

---

### 7. Anycast Gateway の MAC アドレス重複の解決

**【問題】**
（トラブルシューティング）異なるサイトで同じ Anycast MAC が使われ、トラフィックが不安定になっている。各サイト固有の MAC アドレスに変更せよ。

**【検証】**
```ios
Edge-SW# show interface vlan 10
! MACアドレスが 0000.0c9f.fxxx になっていることを確認。
! DNACの Fabric Settings で手動変更が必要な場合がある。
```

---

### 8. L2 Handoff によるレガシー VLAN 接続

**【問題】**
ファブリック外のL2スイッチと通信するため、Edgeノードの Gi1/0/5 で L2 Handoff を構成せよ。

**【設定コンセプト】**
DNACの Host Onboarding で、特定のポートを「Static」として定義し、外部スイッチのVLANとファブリックのVNIをタグ保持したまま橋渡しします。

---

### 9. Border Node でのデフォルトルート広報

**【問題】**
ファブリック内のすべてのエッジノードに対し、外部インターネットへの出口として自身（Border）を登録せよ。

**【検証コマンド】**
```ios
Control-Plane# show lisp instance-id 4097 ipv4 server 0.0.0.0/0
! 登録されている RLOC が Border の IP であることを確認。
```

---

### 10. Multisite: IP Transit によるサードパーティ網接続

**【問題】**
MPLS VPN網を介して2つのサイトを接続せよ。サイト間の通信は Fusion ルータを介した VRF-Lite 形式とする。

**【操作】**
Provision -> Transit で「IP Transit」を選択。各サイトの Border ノードで BGP を設定し、共通の物理網を介してルートをリークさせます。

---

### 11. CP 冗長化のフェイルオーバーテスト

**【問題】**
プライマリ CP がダウンした際、セカンダリ CP にエンドポイントが正しく再登録されることを確認せよ。

**【検証】**
```ios
Edge-SW# show lisp instance-id 4097 ipv4 statistics
! "Map-Registers sent" のカウンタが、セカンダリCPのアドレスに対しても増えているか確認。
```

---

### 12. 外部ネットワークからの SGT 保持 (SXP 連携)

**【問題】**
ファブリック外から Fusion ルータ経由で入ってくるトラフィックに対し、SXP を用いて正しい SGT を付与せよ。

**【設定例】**
```ios
cts sxp enable
cts sxp connection peer 10.1.1.100 password simple Cisco123 mode local
! ISE(10.1.1.100)からSGT-IPマッピングを学習
```

---

## 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076)
    *   SDAファブリック設計の決定版。Single-siteからMultisiteまでの全アーキテクチャ。
*   [**BRKENS-2829: What's New in Cisco SD-Access**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2829)
    *   最新のMultisite Transit（SDA Transit）や、L2/L3 Handoffの進化について。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   ラボ試験で問われる「設計の落とし穴」と、トラブルシューティング手法。

### Configuration ガイド
*   [**Cisco SD-Access Single-Site Design Guide (CVD)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)
*   [**Cisco SD-Access Multisite Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)

### テクニカルノーツ・設定例
*   [**SD-Access Fabric in a Box (FiaB) Technology Overview**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-fiab.html)
*   [**Understanding L3 Handoff and Fusion Router configuration**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)

---

## 📝 補足
- この学習メモは、SD-Accessの設計が「物理的な配線」ではなく「論理的なロールの配置」であることを示しています。CCIE EI ラボ試験では、DNA Center での操作ミスが致命的なアンダーレイ/オーバーレイの不整合を招くため、**LISP Map-Server の状態確認**と **BGP ルート再配送の論理** を完璧にマスターしておくことが合格への最短距離となります。


