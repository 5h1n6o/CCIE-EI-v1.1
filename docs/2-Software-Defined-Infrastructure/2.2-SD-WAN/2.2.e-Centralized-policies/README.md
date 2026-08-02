---
layout: default
title: 2.2.e-Centralized-policies
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 5
---

# 2.2.e Centralized Policies

Cisco SD-WAN アーキテクチャにおいて、**Centralized Policies（集中ポリシー）**はネットワーク全体のトラフィックフロー、ルーティングトポロジ、およびアプリケーションのパフォーマンスを制御するための中枢です。本メモでは、CCIE EI v1.1のBlueprintに基づき、コントロール、データ、アプリケーション・アウェア・ルーティングの各ポリシーについて詳細に解説します。

---

## 📘 概要

SD-Accessがキャンパス内の自動化を担当するのに対し、SD-WANの集中ポリシーは広域網（WAN）全体の制御を司ります。集中ポリシーは、vManage上で作成され、vSmartコントローラにプッシュされます。vSmartはこれらのポリシーを実行し、OSPFやBGPに似た独自のプロトコルである **OMP (Overlay Management Protocol)** の情報を書き換えるか、あるいはエッジデバイス（cEdge/vEdge）に対して直接トラフィック処理の命令を下します。

集中ポリシーは大きく以下の3つに分類されます：
1.  **Control Policies (コントロールポリシー):** OMPルーティング情報を操作し、トポロジ（Hub-and-Spoke, Full Mesh等）を制御します。
2.  **Data Policies (データポリシー):** 実際のパケット（データプレーン）の転送を制御し、フィルタリングやパス変更を行います。
3.  **Application-Aware Routing (AAR) Policies:** パケットの遅延、ジッター、損失などのSLA基準に基づいて、最適なトンネルを選択します。

---

## 🔑 要点

### 1. Control Policies (iii)

コントロールポリシーは、vSmartコントローラの「ルーティング決定」に介入します。
*   **動作原理:** vSmartがエッジから受信したOMPルートやTLOC情報を、他のエッジに転送する際にフィルタリングしたり属性（Preference等）を書き換えたりします。
*   **トポロジ制御:** デフォルトのフルメッシュ構成から、特定の拠点をHubとするHub-and-Spoke構成への変更に不可欠です。
*   **サービスチェイニング:** ファイアウォールなどの共有サービスを通過させる経路変更（Service Routeの操作）を担います。

### 2. Data Policies (i)

データポリシーは、パケットのL3/L4ヘッダー情報に基づいてトラフィックを制御します。
*   **トラフィック操作:** 特定のアプリケーションを、特定のトランスポート（Color）へ強制的に誘導します。
*   **フィルタリング:** 従来のACLと同様にパケットの許可・拒否を行いますが、集中管理により全拠点へ一括適用可能です。
*   **適用場所:** vSmartからエッジデバイスにダウンロードされ、データプレーンの転送パス（Ingress/Egress）で実行されます。

### 3. Application-Aware Routing Policies (ii)

AARは、ネットワークの「品質」に基づいた動的なルーティングを提供します。
*   **SLAクラス:** 許容される遅延（Latency）、損失（Loss）、ジッターの閾値を定義します。
*   **測定:** エッジデバイス間で動作する **BFD (Bidirectional Forwarding Detection)** を利用して、全トンネルの品質をリアルタイムで監視します。
*   **フォールバック:** 最適なパスがSLAを満たさない場合、次に優れたパスへの切り替えや、ベストエフォートでの転送を定義できます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、複雑なビジネス要件を「どのポリシーで実現すべきか」を即座に判断する能力が問われます。

### 1. トポロジ操作の優先順位

*   「特定のVPNのみHub-and-Spoke、他はFull Mesh」といった要件には、**Control Policy**を使用します。OMPルートのNext-hop（TLOC）をHubのSystem-IPに書き換えるロジックをマスターしてください。

### 2. トラフィック誘導（Data Policy vs AAR）

*   「HTTPトラフィックを常にMPLS経由にする」といった静的な要件は **Data Policy** で十分です。
*   「音声トラフィックは遅延が150ms以下のパスを選択し、満たさない場合はインターネットへ回避させる」といった動的な品質要件には **AAR Policy** が必須です。

### 3. VPN間のルートリーク

*   SDA統合や共有サービスアクセスにおいて、VPN（VRF）間の通信が必要な場合、集中ポリシーでのルートエクスポート/インポート設定が重要になります。

### 4. 適用方向の理解

*   `Direction: In` (エッジからvSmartへ)、`Direction: Out` (vSmartからエッジへ) の概念を混同しないようにしてください。コントロールポリシーは通常 `Direction: Out` で他のエッジへの広報を制御します。

---

## 🛠 設定・検証コマンド

ポリシー自体はvManageのGUI（Configuration > Policies）で作成しますが、試験ではエッジデバイス上で「意図したポリシーが反映されているか」をCLIで確認するスキルが合格を左右します。

| 目的 | コマンド |
| :--- | :--- |
| **vSmartから受信した全ポリシーの確認** | <code>show sdwan policy from-vsmart</code> |
| **OMPルートの適用結果確認** | <code>show omp routes [prefix]</code> |
| **TLOC情報の書き換え確認** | <code>show omp tlocs</code> |
| **AARのSLA統計情報の確認** | <code>show sdwan app-route stats</code> |
| **データプレーンのパケットカウンタ確認** | <code>show policy-map interface [INT]</code> |
| **BFDによる品質測定結果の確認** | <code>show bfd sessions</code> |
| **特定のVPNのルートリーク状況確認** | <code>show ip route vrf [ID]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. Hub-and-Spoke トポロジの構成 (Control Policy)

**【問題】** VPN 10において、支店間通信を禁止し、すべてのトラフィックを本社のHubルータ (TLOC: 10.1.1.1) 経由にせよ。
*   **Match:** VPN 10, Site List: Branches
*   **Action:** <code>set tloc 10.1.1.1 color mpls encap ipsec</code>
*   **Apply:** <code>control-policy HUB_AND_SPOKE out</code> (vSmart側)

---

### 2. TLOC Preference による優先パス設定

**【問題】** 支店からのすべての送信トラフィックにおいて、Biz-Internet よりも MPLS 回線を優先的に使用せよ。
*   **Match:** TLOC List (MPLS)
*   **Action:** <code>preference 500</code> (デフォルト 0)

---

### 3. 音声トラフィック用 AAR SLA ポリシー

**【問題】** DSCP 46 (EF) のトラフィックに対し、遅延 100ms 以下、損失 1% 以下のパスを割り当てよ。
*   **SLA Class:** <code>latency 100</code>, <code>loss 1</code>
*   **App-Route Policy:** Match DSCP 46, Action <code>sla-class VOICE preferred-color mpls</code>

---

### 4. 特定サイト間のみの Full-Mesh 許可

**【問題】** Site ID 10 と 20 の間のみ直接通信を許可し、他のサイトは Hub 経由とせよ。
*   **Match:** Site List (10, 20)
*   **Action:** <code>accept</code> (デフォルトの書き換えをスキップ)

---

### 5. データポリシーによる特定のURLフィルタリング

**【問題】** 全拠点のユーザーに対し、特定の宛先 IP (192.168.100.0/24) への Telnet 通信を拒否せよ。
*   **Central Data Policy:** Match <code>protocol 6</code> (TCP), <code>port 23</code>, <code>destination 192.168.100.0/24</code>
*   **Action:** <code>drop</code>

---

### 6. サービスチェイニング (FW挿入)

**【問題】** 支店からインターネットへのトラフィックを、本社にある Firewall (Service: FW) を経由させてから転送せよ。
*   **Control Policy:** Match <code>0.0.0.0/0</code>
*   **Action:** <code>set service FW vpn 10</code>

---

### 7. VPN 間のルートリーク

**【問題】** VPN 10 (従業員) から VPN 20 (共有サーバ) へのネットワーク 172.16.1.0/24 の到達性を確保せよ。
*   **Custom Option (Topology):** VPN 10 ➔ Import Routes from VPN 20 (Prefix 172.16.1.0/24)

---

### 8. AAR でのトランスポート制限 (Restricted)

**【問題】** ゲストトラフィックに対し、MPLS がダウンしている場合でもインターネット回線以外（4G 等）は絶対に使用させないようにせよ。
*   **AAR Action:** <code>preferred-color public-internet restrict</code>

---

### 9. ダイレクトインターネットアクセス (DIA)

**【問題】** Office 365 宛のトラフィックのみ、本社トンネルを通らずにローカルのインターネット回線から直接ブレイクアウトさせよ。
*   **Data Policy:** Match <code>app-list O365</code>
*   **Action:** <code>set vpn 0 nat use-vpn-0-vars</code>

---

### 10. QoS 書き換えポリシー

**【問題】** 特定のビジネスアプリケーション（ポート 8080）に対し、WAN 入口で DSCP を AF21 に付け替えよ。
*   **Data Policy:** Match <code>dst-port 8080</code>
*   **Action:** <code>set dscp 18</code> (AF21)

---

### 11. OMP ルートのフィルタリング

**【問題】** 開発環境 (10.254.0.0/24) のルートが、本番環境のサイトに広報されないように vSmart でブロックせよ。
*   **Control Policy:** Match <code>prefix 10.254.0.0/24</code>
*   **Action:** <code>reject</code>

---

### 12. BGP AS Path の操作

**【問題】** レガシー網との接続において、SD-WAN サイトを通過する際に AS Path 400 を追加（Prepend）して戻りトラフィックを制御せよ。
*   **Control Policy:** Match OMP Route
*   **Action:** <code>set as-path prepend 400 400</code>

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKTRS-3793: Advanced SD-WAN Routing Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-3793) - 集中ポリシーと OMP 属性操作の深いデバッグ解説。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - ポリシー push 失敗時のトラブル解決。
*   [**BRKXAR-2001: Intent Based Cross Domain SDA and SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKXAR-2001) - ポリシー連携の設計手法。

### Configuration ガイド
*   [**Cisco SD-WAN Policies Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/vedge-20-x/policies-book.html) - 公式の全ポリシー設定マニュアル。
*   [**Configuring Application-Aware Routing**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/vedge-20-x/policies-book/m-app-aware-routing.html)。

### テクニカルドキュメント・設定例
*   [**SD-WAN Centralized Policy Architecture Overview**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/SDWAN/sd-wan-design-guide.html)。
*   [**SD-Access and SD-WAN Integration (Tech Note)**](https://www.cisco.com/c/dam/en/us/td/docs/solutions/CVD/Campus/sda-sdwan-integration-2019oct.pdf)。

---

## 📝 補足
- この学習メモは、SD-WAN ポリシーが「誰が(Site)」「何に対し(VPN/App)」「どのように(Topology/SLA)」制御するかという論理的な流れを整理しています。CCIE EI ラボ試験では、vManage の GUI 画面がソース Workbook のように示されるため、各入力項目が CLI のどの属性（OMP TLOC, Preference, Color）に対応しているかを常に意識して学習することが重要です。

