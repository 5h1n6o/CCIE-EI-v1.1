---
layout: default
title: 4.7.b-Troubleshooting-tools
parent: 4.7-Network-operations
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.7.b Troubleshooting tools

本ページでは、Cisco IOS XE ソフトウェアの内部動作を詳細に解析するための強力な診断ツールである「データパス・パケットトレース」および「条件付きデバッガ」について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

Cisco IOS XE デバイス（Catalyst 9000 シリーズ、ASR 1000 シリーズ、CSR 1000v/Catalyst 8000V 等）は、コントロールプレーン（IOS プロセス）とデータプレーン（Forwarding Processor: QFP 等）が分離されたアーキテクチャを採用しています。従来の `debug` コマンドは主にコントロールプレーンの動作を記録するものであり、データプレーンを通過する実際のパケットの処理過程を追跡するには不十分でした。

4.7.b で扱われるツールは、データプレーン（フォワーディング・パス）におけるパケットのライフサイクルを可視化します。
*   **Data Path Packet Trace (i):** パケットがデバイスに入力されてから出力されるまでの間に、どのような機能（FIA: Feature Invocation Array）が適用され、どの段階でドロップまたは転送されたかを詳細に記録します。
*   **Conditional Debugger (ii):** 特定の IP アドレス、MAC アドレス、インターフェイスなどの条件に一致するトラフィックのみをデバッグ対象とします。これにより、高負荷な環境でもデバイスの CPU 負荷を抑えつつ、必要なトラブルシューティング情報を抽出できます。

---

## 🔑 要点

### 1. データパス・パケットトレース (Data Path Packet Trace)

この機能は、パケットそのものをキャプチャするだけでなく、処理過程の「メタデータ」を収集します。
*   **FIA (Feature Invocation Array):** パケットに適用される一連の処理（ACL、NAT、QoS、ZBFW 等）の順序。
*   **Summary & detail:** パケットごとの処理結果（転送/ドロップ）のサマリと、レジスタレベルでの詳細なデバッグ情報を表示可能。
*   **Copy 抽出:** 処理されたパケットのヘッダーやペイロードをバイナリ形式で確認できます。

### 2. 条件付きデバッガ (debug platform condition)

特定のフローを分離してデバッグするための「フィルター」として機能します。
*   **条件の定義:** `ipv4/ipv6 address`、`interface`、`mac-address`、`mpls label` などの条件を設定します。
*   **制御プレーンへの影響軽減:** 条件に一致しないパケットのデバッグ出力を抑制するため、本番環境での安全なデバッグが可能です。
*   **Radioactive Tracing との連携:** 特にワイヤレスや高度な機能において、条件に一致したログをシステム全体で追跡する際に使用されます。

### 3. パケット処理の可視化プロセス

1.  条件の設定 (Condition)
2.  パケットトレースの有効化 (Packet-trace)
3.  トラフィックの発生 (Trigger)
4.  結果の表示 (Show)
5.  デバッグの停止と条件のクリア (Cleanup)

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、複雑な構成（NAT、ZBFW、PBR 等）が組み合わさった環境で、「なぜパケットが届かないのか」を迅速に特定する能力が求められます。

### 1. FIA によるドロップ箇所の特定

「ACL は正しいはずなのに通信ができない」場合、パケットトレースを使用して FIA を確認します。例えば、NAT 変換前に ACL でドロップされているのか、あるいは NAT 変換後のアドレスに対して別のポリシーが適用されているのかを正確に判別できます。

### 2. パフォーマンスへの配慮

ラボ試験の採点において、デバイスを過負荷にさせる操作はマイナス評価やクラッシュのリスクを伴います。`debug` コマンドを使用する前に、必ず `debug platform condition` で範囲を限定する習慣をつけることが重要です。

### 3. トラブルシューティングのシナリオ

*   **シナリオA:** セキュリティポリシー（ZBFW）による不意のパケットドロップの証明。
*   **シナリオB:** PBR (Policy Based Routing) が意図したネクストホップを選択しているかの検証。
*   **シナリオC:** 重複した NAT ルールや、変換順序の矛盾による通信エラーの解析。

---

## 🛠 設定・検証コマンド

### 条件付きデバッガ (Conditional Debug)

| 目的 | コマンド |
| :--- | :--- |
| **IPアドレスによる条件設定** | <code>debug platform condition ipv4 [IP_ADDR]/[MASK] both</code> |
| **インターフェイスによる条件設定** | <code>debug platform condition interface [INT]</code> |
| **条件の有効化** | <code>debug platform condition start</code> |
| **条件の停止** | <code>debug platform condition stop</code> |
| **設定された条件の確認** | <code>show platform condition</code> |

### パケットトレース (Packet Trace)

| 目的 | コマンド |
| :--- | :--- |
| **トレースの有効化(パケット数指定)** | <code>debug platform packet-trace packet [NUMBER]</code> |
| **FIA 処理の記録を有効化** | <code>debug platform packet-trace copy packet [both&#124;input&#124;output] L3</code> |
| **トレースサマリの表示** | <code>show platform packet-trace summary</code> |
| **特定パケットの処理詳細表示** | <code>show platform packet-trace packet [INDEX]</code> |
| **トレースデータのクリア** | <code>clear platform packet-trace statistics</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 特定ホスト間通信のパケットトレース

**【課題】** ホスト 10.1.1.1 から 10.2.2.2 への ICMP 通信が失敗する原因を解析せよ。
```ios
debug platform condition ipv4 10.1.1.1/32 10.2.2.2/32 both
debug platform packet-trace packet 10
debug platform condition start
! トラフィック発生後
show platform packet-trace summary
```

### 2. インターフェイス指定によるデバッグ

**【課題】** Gi0/1 を通過する全てのトラフィックを条件付きデバッグの対象にせよ。
```ios
debug platform condition interface GigabitEthernet0/1
show platform condition
```

### 3. NAT 変換プロセスの詳細追跡

**【課題】** 内部パケットが NAT プールによって正しく変換されているか FIA で確認せよ。
```ios
! トレース詳細を確認
show platform packet-trace packet 0
! 期待される結果: "Feature: NAT" セクションで Inside->Outside の変換を確認
```

### 4. ZBFW (ゾーンベースファイアウォール) によるドロップの特定

**【課題】** パケットがファイアウォールによってドロップされている証拠を提示せよ。
```ios
show platform packet-trace summary
! 出力結果の "State" が "DROP" かつ "Reason" が "Firewall" であることを確認
```

### 5. PBR (Policy Based Routing) の動作検証

**【課題】** パケットがルートマップに従って転送されているか確認せよ。
```ios
show platform packet-trace packet 1
! FIA 内の "Policy Routing" でセットされたネクストホップを確認
```

### 6. IPv6 トラフィックの追跡

**【課題】** 特定の IPv6 送信元からのパケットを 5 つ記録せよ。
```ios
debug platform condition ipv6 2001:DB8:1::1/128 both
debug platform packet-trace packet 5
debug platform condition start
```

### 7. レイヤ 2 条件 (MAC アドレス) の指定

**【課題】** 特定のサーバー (MAC: 0011.2233.4455) からのトラフィックをフィルタリングせよ。
```ios
debug platform condition mac 0011.2233.4455
```

### 8. パケットトレース・バッファの拡張

**【課題】** 大量のパケットを解析するため、トレースバッファを最大 1000 パケットまで増やせ。
```ios
debug platform packet-trace packet 1000
```

### 9. 制御プレーン向けトラフィックのデバッグ

**【課題】** BGP ネイバーシップの問題を解決するため、コントロールプレーン宛のパケットを追跡せよ。
```ios
debug platform condition ipv4 host 192.168.1.1 both
! この後、通常の 'debug ip bgp' 等と組み合わせて出力を絞り込む
```

### 10. デバッグ条件の一括クリア

**【課題】** 作業終了後、設定した全てのデバッグ条件を削除せよ。
```ios
undebug platform condition all
```

### 11. FIA (Feature Invocation Array) の全リスト確認

**【操作例】** パケットに適用される可能性のある全処理ステップをダンプ表示せよ。
```ios
show platform hardware qfp active feature list
```

### 12. ドロップ理由に基づいたフィルタリング表示

**【操作例】** トレース結果から、ドロップされたパケットのみをサマリから抽出せよ。
```ios
show platform packet-trace summary | include DROP
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKTRS-2811: Overview of Packet Capturing and Traffic Analysis Tools**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-2811)
    *   EPC、SPAN、パケットトレースを含む包括的な可視化ツールの解説。
*   [**BRKARC-2001: Cisco ASR 1000 Series Architecture**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKARC-2001)
    *   QFP 内部での FIA 処理とデバッグの仕組み。
*   [**BRKCRT-1385: The CCIE in an SDN World**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   モダンなエンタープライズインフラにおけるトラブルシューティングの価値。

### Configuration ガイド
*   [**Troubleshoot with the IOS-XE Datapath Packet Trace Feature**](https://www.cisco.com/c/en/us/support/docs/routers/asr-1000-series-aggregation-services-routers/112030-pkt-trace-asr1k.html)。
*   [**Conditional Debugging and Radioactive Tracing Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-3/configuration_guide/sys_mgmt/b_173_sys_mgmt_9300_cg/m_conditional-debug-radioactive-tracing.html)。

### テクニカルドキュメント・設定例
*   [**Understanding the Packet-Trace Feature in IOS-XE (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/asr-1000-series-aggregation-services-routers/112030-pkt-trace-asr1k.html)。
*   [**Common DROP Reasons in IOS-XE Packet-Trace (Technical Reference)**](https://www.cisco.com/c/en/us/support/docs/routers/asr-1000-series-aggregation-services-routers/214300-troubleshoot-asr1k-packet-drops-with-the.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験合格に必要な **「論理的な原因特定プロセス」** を強化することを目的としています。ラボ試験では、設定ミスを探して闇雲にコマンドを打つのではなく、**`packet-trace`** を活用してデバイスが「なぜその判断を下したのか」をデータプレーンの視点から証明することが合格への近道です。


