---
layout: default
title: 4.6.c-FNF
parent: 4.6-Network-optimization
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.6.c Flexible NetFlow

本ページでは、ネットワークトラフィックの可視化と分析に不可欠な技術である **Flexible NetFlow (FNF)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。FNF は、従来の NetFlow をより柔軟かつモジュール化したものであり、特定のトラフィックパターンの抽出やセキュリティ分析において強力な武器となります。

---

## 📘 概要

**Flexible NetFlow (FNF)** は、ネットワークを通過する IP トラフィックの統計情報を収集し、分析するための Cisco IOS XE の機能です。従来の NetFlow (v5/v9) が固定されたデータセットを収集していたのに対し、FNF はユーザーが「どのデータをキー（識別子）とし、どのデータを追加情報として収集するか」を自由に定義できるモジュール構造を採用しています。

FNF は以下の 3 つの主要なコンポーネントで構成されます。
1.  **Flow Record:** トラフィックを識別するための「Match」項目と、収集する統計情報である「Collect」項目を定義します。
2.  **Flow Exporter:** 収集したデータを外部のコレクタ（管理サーバー）へ送信するための設定（送信先 IP、UDP ポート、プロトコル形式）を定義します。
3.  **Flow Monitor:** Record と Exporter を紐付け、実際にインターフェイスに適用する論理的なエンティティです。

---

## 🔑 要点

### 1. 構成のモジュール性

FNF の最大の特徴は、Record、Exporter、Monitor を独立して作成し、再利用できる点にあります。これにより、同じ監視ルール（Record）を複数の異なるコレクタ（Exporter）に適用するといった運用が容易になります。

### 2. Match（キーフィールド）と Collect（非キーフィールド）

*   **Match:** フローを一意に識別するための条件です（送信元 IP、宛先 IP、プロトコル、ポート番号など）。これらが一致するパケットは同一の「フロー」として集計されます。
*   **Collect:** フローの識別には使用しませんが、分析のために取得する追加データです（パケット数、バイト数、タイムスタンプ、ネクストホップなど）。

### 3. NetFlow キャッシュの管理

収集されたデータは、まずデバイス上の **Flow Cache** に保持されます。
*   **Active Timeout:** 通信中のフローを一定時間ごとにエクスポートします（デフォルト 1800 秒）。
*   **Inactive Timeout:** 通信が途絶えたフローをキャッシュから削除し、エクスポートします（デフォルト 15 秒）。

### 4. サンプリング (Flow Sampler)

高帯域のインターフェイスにおいて、全パケットを処理すると CPU 負荷が高まります。`sampler` を定義することで、「100 パケットにつき 1 パケットのみを抽出」といったサンプリングが可能になります。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単に NetFlow を有効にするだけでなく、特定のビジネス要件を満たす「カスタマイズされた監視」が問われます。

### 1. 複雑な Match 条件の指定

「特定のサブネット間の IPv6 トラフィックのみを監視し、かつ DSCP 値を収集せよ」といった要件が出題されます。
*   **対策:** `match ipv6 destination address` と `collect ipv6 dscp` を正しく Record に組み込む必要があります。

### 2. VRF を考慮したエクスポート

コレクタが特定の管理用 VRF（例: Mgmt-intf）に存在する場合、Exporter 設定で VRF を明示的に指定しなければ通信が届きません。
*   **対策:** `option vrf-table` やソースインターフェイスの指定が重要になります。

### 3. Top Talkers のローカル分析

外部コレクタを使用せず、デバイスの CLI 上で「帯域を最も消費している上位 X クライアント」を表示させる設定が問われることがあります。
*   **対策:** `ip flow top-talkers` 設定（レガシーな手法）や、FNF モニタリングのキャッシュ表示コマンドを習得してください。

### 4. Ingress vs Egress の使い分け

「WAN から流入するトラフィックのみ」を監視するのか、「LAN へ送出されるトラフィック」を監視するのか、インターフェイスへの適用方向（`input` / `output`）の指定を間違えると、要件を満たせません。

---

## 🛠 設定・検証コマンド

### FNF 構成コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Flow Recordの作成** | <code>flow record [NAME]</code> |
| **キーフィールドの指定** | <code>match ipv4 {source&#124;destination} address</code> |
| **非キーフィールドの収集** | <code>collect counter {bytes&#124;packets} [long]</code> |
| **Flow Exporterの作成** | <code>flow exporter [NAME]</code> |
| **送信先IPとポート** | <code>destination [IP_ADDR]</code> <br> <code>transport udp [PORT]</code> |
| **Flow Monitorの作成** | <code>flow monitor [NAME]</code> |
| **RecordとExporterの紐付け** | <code>record [RECORD_NAME]</code> <br> <code>exporter [EXPORTER_NAME]</code> |
| **インターフェイスへの適用** | <code>(config-if)# ip flow monitor [MON_NAME] {input&#124;output}</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **キャッシュ内のフロー表示** | <code>show flow monitor [NAME] cache [format table]</code> |
| **構成情報のサマリ確認** | <code>show flow monitor name [NAME]</code> |
| **エクスポート統計の確認** | <code>show flow exporter [NAME] statistics</code> |
| **Record設定の確認** | <code>show flow record [NAME]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. IPv4 送信元/宛先ベースの基本監視

**【課題】** 送信元・宛先 IP アドレスを識別し、バイト数とパケット数を収集する Record `V4-BASIC` を作成せよ。
```ios
flow record V4-BASIC
 match ipv4 source address
 match ipv4 destination address
 collect counter bytes long
 collect counter packets long
```

### 2. L4 ポート番号を含む詳細監視

**【課題】** プロトコルと TCP/UDP のポート番号を Match 条件に加え、アプリケーション特定を可能にせよ。
```ios
flow record L4-ANALYSIS
 match ipv4 protocol
 match transport source-port
 match transport destination-port
 match ipv4 source address
 match ipv4 destination address
 collect counter bytes long
```

### 3. 外部コレクタへのエクスポート設定

**【課題】** 収集データを 10.1.1.100 (UDP 2055) へ NetFlow v9 形式で送信せよ。
```ios
flow exporter TO-NMS
 destination 10.1.1.100
 transport udp 2055
 source Loopback0
 export-protocol netflow-v9
```

### 4. フローモニターの統合と適用 (Ingress)

**【課題】** Monitor `NET-MON` を作成し、Gi0/1 の入力方向に適用せよ。
```ios
flow monitor NET-MON
 record V4-BASIC
 exporter TO-NMS
!
interface GigabitEthernet0/1
 ip flow monitor NET-MON input
```

### 5. IPv6 トラフィックの抽出

**【課題】** IPv6 アドレスと DSCP 値を Match 条件とする Record `V6-QOS` を作成せよ。
```ios
flow record V6-QOS
 match ipv6 source address
 match ipv6 destination address
 match ipv6 dscp
 collect counter packets
```

### 6. キャッシュタイムアウトのカスタマイズ

**【課題】** 長い通信を 1 分ごとにエクスポートし、終了した通信は 10 秒でエクスポートせよ。
```ios
flow monitor CUSTOM-TIMEOUT
 cache timeout active 60
 cache timeout inactive 10
```

### 7. サンプラーによる CPU 負荷軽減

**【課題】** 100 パケット中 1 パケットのみを抽出して監視する Sampler を適用せよ。
```ios
sampler PACKET-1-IN-100
 mode random 1 out-of 100
!
interface GigabitEthernet0/2
 ip flow monitor NET-MON sampler PACKET-1-IN-100 input
```

### 8. ルーティング情報の収集 (Next-hop)

**【課題】** トラフィックの宛先ネクストホップ IP を追加情報として収集せよ。
```ios
flow record RT-INFO
 match ipv4 destination address
 collect routing next-hop address ipv4
```

### 9. Top Talkers のローカル表示設定

**【課題】** キャッシュ内で最も通信量の多い 10 エントリを表示せよ。
```ios
# show flow monitor NET-MON cache sort counter bytes top 10
```

### 10. Egress NetFlow (出力方向) の適用

**【課題】** WAN インターフェイスから出て行くトラフィックを監視せよ。
```ios
interface GigabitEthernet0/0
 ip flow monitor NET-MON output
```

### 11. マルチキャストトラフィックの監視

**【課題】** IPv4 マルチキャストグループへのトラフィックを特定せよ。
```ios
flow record MCAST-WATCH
 match ipv4 destination address
 match ipv4 source address
 ! 宛先が224.0.0.0/4のものを後でフィルタリング
```

### 12. 構成の整合性チェック（トラブルシューティング）

**【操作】** Exporter の統計を確認し、コレクタへの送信エラー（Drops）がないか確認せよ。
```ios
# show flow exporter TO-NMS statistics
! "Export packets dropped" が 0 であることを確認
```

---

## 🔗 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKTRS-2811: Overview of Packet Capturing and Traffic Analysis Tools**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-2811)
    *   FNF を含む可視化ツールの全容解説。
*   [**BRKOPS-2431: Network Automation in Theory and Practice - YANG and Telemetry**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   モデル駆動型テレメトリと NetFlow の統合。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Flexible NetFlow Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fnetflow/configuration/xe-17/fnf-xe-17-book.html)。
*   [**Configuring NetFlow Top Talkers**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/netflow/configuration/15-mt/nf-15-mt-book/cfg-top-talkers.html)。

### テクニカルドキュメント・設定例
*   [**Flexible NetFlow Components and Configuration (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/flexible-netflow/118835-configure-fnf-00.html)。
*   [**NetFlow v5, v9 and IPFIX Comparison**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/fnetflow/configuration/xe-16/fnf-xe-16-book/fnf-ipfix-export.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験における **「ネットワークの透明性（Visibility）」** の確保を目的としています。試験では、**`show flow monitor cache`** を自在に使いこなし、特定のトラフィックが意図通りにキャプチャされているかを即座に証明できることが、合格への確実なステップとなります。


