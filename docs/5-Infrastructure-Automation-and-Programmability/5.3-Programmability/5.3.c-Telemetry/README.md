---
layout: default
title: 5.3.c-Telemetry
parent: 5.3-Programmability
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 3
---

# 5.3.c Deploy and verify model-driven telemetry

本ページでは、ネットワーク運用の「可視化（Observability）」を次世代レベルへ引き上げる技術である **モデル駆動型テレメトリ（Model-Driven Telemetry: MDT）** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。特に、**gRPC** を使用した **On-change（状態変化時）** サブスクリプションの設定と検証に焦点を当てます。

---

## 📘 概要

### モデル駆動型テレメトリ (MDT) とは

従来の SNMP（簡易ネットワーク管理プロトコル）による「ポーリング（引き出し）」モデルに代わる、最新の「プッシュ（配信）」型モニタリング技術です。
*   **効率性:** SNMP がデバイスに対して定期的に情報を問い合せる（Pull）のに対し、MDT はデバイス自身が事前に定義されたデータを管理サーバ（コレクタ）へ自律的に送信（Push）します。
*   **構造化データ:** MDT は **YANG データモデル** に基づいて情報を構造化するため、ベンダー間でのデータの互換性が高く、機械による自動解析が容易です。

### Configure on-change subscription using gRPC (i)

試験範囲である 5.3.c (i) では、以下の要素を組み合わせた高度な実装が求められます。
*   **On-change（状態変化時）:** データの「値」が変化した瞬間（例：インターフェイスが Up から Down になった、OSPF ネイバーが切れた等）にのみデータを送信します。これにより、不要なトラフィックを削減しつつ、リアルタイムな検知が可能になります。
*   **gRPC (Google Remote Procedure Call):** HTTP/2 をトランスポートとし、バイナリ形式の Protocol Buffers (protobuf) でデータをエンコードする最新のプロトコルです。高いスループットと低遅延、および強力なセキュリティ（TLS）を提供します。

---

## 🔑 要点

### 1. サブスクリプションの構成要素

MDT を動作させるには、主に 3 つの要素を定義する必要があります。
*   **Sensor Path (XPath):** 監視対象を指定します。YANG モデルの階層構造を `/ietf-interfaces:interfaces-state/interface` のように記述します。
*   **Subscription Mode:** 
    *   **Periodic（定期的）:** 一定間隔（秒）ごとにデータを送信。
    *   **On-change（変化時）:** 状態が変化したときのみ即座に送信。
*   **Destination (Receiver):** コレクタの IP アドレス、ポート番号、プロトコル（gRPC等）を指定します。

### 2. 接続方式（Dial-in と Dial-out）

*   **Dial-in:** コレクタ（外部サーバ）側からルータに対してセッションを確立し、データを要求します。
*   **Dial-out:** ルータ側からコレクタに対して能動的に接続を開始します。CCIE 試験や大規模環境では、ルータが自身の状態を自律的に報告する **Dial-out** 構成が一般的です。

### 3. トランスポートとエンコーディング

*   **Transport:** gRPC (TCP 57400 等を使用)、NETCONF。
*   **Encoding:** kvGPB (Key-value Google Protocol Buffers) など。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験の自動化・インフラサービスセクションでは、特定の「ビジネス要件」を満たすテレメトリ構成が求められます。

### 1. 適切な XPath の選択

試験問題では「OSPF の状態を監視せよ」や「インターフェイスのパケットドロップを監視せよ」といった抽象的な指示が出ます。
*   **対策:** `Cisco-IOS-XE-native`（シスコ固有）や `ietf-interfaces`（標準）など、どの YANG モデルを使用すべきか、また正確なパス（XPath）を確認する能力が問われます。

### 2. On-change の厳密な設定

「帯域利用率は 30 秒ごとに、インターフェイスの Up/Down は即座に通知せよ」といった複合要件が出題されます。
*   **対策:** サブスクリプションごとに `update-policy periodic` と `update-policy on-change` を正しく使い分ける必要があります。

### 3. gRPC レシーバーの整合性

レシーバー（コレクタ）の設定において、ポート番号の指定ミスやソースインターフェイスの指定漏れに注意してください。

### 4. 検証スキルの証明

設定して終わりではなく、実際にデータが流れているか（`Active` 状態か）を CLI で証明する必要があります。
*   **ポイント:** `show telemetry ietf subscription [ID] detail` コマンドで、接続ステータスが `Connected` または `Active` であることを確認する手順を確立してください。

---

## 🛠 設定・検証コマンド

### gRPC / テレメトリ設定（Dial-out 例）

| 目的 | コマンド |
| :--- | :--- |
| **gRPCサービスの有効化** | <code>(config)# grpc-tls</code> / <code>grpc-no-tls</code> |
| **サブスクリプションの作成** | <code>(config)# telemetry ietf subscription [ID]</code> |
| **監視対象(XPath)の指定** | <code>(config-mdt-subs)# filter xpath [PATH_STRING]</code> |
| **配信ストリームの指定** | <code>(config-mdt-subs)# stream yang-push</code> |
| **On-changeモードの設定** | <code>(config-mdt-subs)# update-policy on-change</code> |
| **レシーバーIP・ポート設定** | <code>(config-mdt-subs)# receiver ip-address [IP] [PORT] protocol grpc-tcp</code> |
| **ソースインターフェイス指定** | <code>(config-mdt-subs)# source-address [IP &#124; INT]</code> |

### 検証・統計確認

| 目的 | コマンド |
| :--- | :--- |
| **サブスクリプションのサマリ** | <code>show telemetry ietf subscription all</code> |
| **特定の構成と状態の詳細** | <code>show telemetry ietf subscription [ID] detail</code> |
| **レシーバーとの接続状況** | <code>show telemetry ietf subscription [ID] receiver</code> |
| **内部エラーの確認** | <code>show telemetry ietf subscription all internal</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. インターフェイス Up/Down の On-change 監視

**【課題】** IETF インターフェイスモデルを使用して、全ポートの状態変化を即座にコレクタ (10.1.1.100:57400) へ送信せよ。
```ios
telemetry ietf subscription 101
 filter xpath /ietf-interfaces:interfaces-state/interface/oper-status
 stream yang-push
 update-policy on-change
 receiver ip-address 10.1.1.100 57400 protocol grpc-tcp
```

### 2. 特定インターフェイス (Gi1) のみの監視

**【課題】** Gi1 のみに絞って状態監視を行う XPath フィルタを構成せよ。
```ios
telemetry ietf subscription 102
 filter xpath /ietf-interfaces:interfaces-state/interface[name='GigabitEthernet1']
 stream yang-push
 update-policy on-change
 ! ... receiver config
```

### 3. OSPF ネイバー状態のリアルタイム通知

**【課題】** OSPF の隣接関係の変化を On-change で監視せよ。
```ios
telemetry ietf subscription 200
 filter xpath /ospf-oper-data:ospf-oper-data/ospf-instance/ospf-area/ospf-interface/ospf-neighbor
 stream yang-push
 update-policy on-change
 receiver ip-address 10.1.1.100 57400 protocol grpc-tcp
```

### 4. CPU 高負荷の On-change 監視

**【課題】** CPU 負荷が変化した際に通知を行うサブスクリプションを作成せよ。
```ios
telemetry ietf subscription 300
 filter xpath /process-cpu-oper:cpu-usage/cpu-utilization/five-seconds
 stream yang-push
 update-policy on-change
 ! ... receiver config
```

### 5. BGP セッション状態の監視

**【課題】** BGP ピアの状態変化をトリガーにデータをプッシュせよ。
```ios
telemetry ietf subscription 400
 filter xpath /bgp-oper-data:bgp-state-data/neighbors/neighbor/session-state
 stream yang-push
 update-policy on-change
 ! ... receiver config
```

### 6. IPv6 到達性情報の On-change 監視

**【課題】** IPv6 近隣テーブルの変化を監視する。
```ios
telemetry ietf subscription 500
 filter xpath /ipv6-nd-oper:ipv6-nd-oper-data/ipv6-nd-neighbor
 stream yang-push
 update-policy on-change
 ! ... receiver config
```

### 7. ダイヤルイン (Dial-in) 用の gRPC 設定

**【課題】** 外部コレクタからの gRPC 接続を受け入れるため、ポート 57500 で TLS なしのサービスを起動せよ。
```ios
grpc-no-tls
! デフォルトポートを変更する場合
grpc-port 57500
```

### 8. ソースインターフェイスの Loopback0 固定

**【課題】** テレメトリトラフィックの送信元 IP を Loopback0 に固定せよ。
```ios
telemetry ietf subscription 101
 source-address Loopback0
 ! ... other config
```

### 9. 複数レシーバーへの冗長配信

**【課題】** 同一のデータを 2 台のコレクタ (10.1.1.100, 10.1.1.101) へ送信せly。
```ios
telemetry ietf subscription 101
 receiver ip-address 10.1.1.100 57400 protocol grpc-tcp
 receiver ip-address 10.1.1.101 57400 protocol grpc-tcp
```

### 10. BFD セッション状態の変化監視

**【課題】** 高速障害検知プロトコル BFD の状態変化を監視せよ。
```ios
telemetry ietf subscription 600
 filter xpath /bfd-oper:bfd-state/bfd-neighbor/state
 stream yang-push
 update-policy on-change
 ! ... receiver config
```

### 11. 構成の検証 (サブスクリプション状態の確認)

**【操作】** 全てのサブスクリプションが "Active" かつ "Connected" であるかを確認せよ。
```ios
# show telemetry ietf subscription all
! Subscription ID: 101, State: Active, Stream: yang-push
```

### 12. XPath シンタックスエラーの特定 (トラブルシューティング)

**【シナリオ】** XPath が無効でデータが飛ばない場合。
```ios
! 手順
1. show telemetry ietf subscription [ID] detail を確認
2. "Notes" セクションに "Invalid XPath" 等のメッセージがないか確認
3. 'show platform software yang-management process' でプロセス健全性を確認
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKDEV-1368: Introduction to Model Driven Programmability**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKDEV-1368)
*   [**BRKOPS-2431: Network Automation in Theory and Practice - Telemetry Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Programmability Configuration Guide - Telemetry**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg.html)
*   [**YANG Data Models on Cisco IOS XE**](https://developer.cisco.com/docs/ios-xe/#!yang-data-models)

### テクニカルドキュメント・設定例
*   [**Model-Driven Telemetry Best Practices (White Paper)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/1610/b_1610_prog_cg/m_1610_prog_telemetry.html)
*   [**XPath Syntax for Cisco IOS XE Telemetry**](https://developer.cisco.com/learning/modules/iosxe-programmability-telemetry/)

---

## 📝 補足
- この学習メモは、CCIE EI 試験において **「単なるモニタリングから、イベント駆動型のインテリジェントなインフラ管理」** への移行を理解することを目的としています。実技試験では、指定された XPath が「On-change」に対応しているか（全ての YANG ノードが On-change をサポートしているわけではない点）を意識することが、トラブルを未避ける鍵となります。


