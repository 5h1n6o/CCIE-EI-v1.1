---
layout: default
title: 4.3.c-Logging
parent: 4.3-System-management
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.3.c Logging

本メモでは、Cisco IOS XE デバイスにおけるシステムメッセージロギングの管理と、設定変更の追跡、および正確な証跡管理に不可欠なタイムスタンプ機能について解説します。CCIE EI ラボ試験において、ロギングは「Infrastructure Services」セクションの一部として、特定の要件に基づいた実装や、トラブルシューティング時の不可欠なツールとして問われます。

---

## 📘 概要

**ロギング (Logging)** は、ネットワークデバイスの稼働状態、エラー、セキュリティイベント、および管理操作の履歴を記録するプロセスです。Cisco IOS XE では、以下の 3 つの主要なコンポーネントによって詳細な可視性が提供されます。

1.  **システムロギング (i):** デバイス自身で発生するイベント（インターフェイスの Up/Down、隣接関係の変化、システムエラーなど）を、重要度（Severity Level）に応じてバッファ、コンソール、VTY セッション、または外部 Syslog サーバーに配信します。
2.  **コンフィギュレーション変更通知とロギング (ii):** 誰がいつ、どのコマンドを実行して設定を変更したかをアーカイブし、監査証跡を残す機能です。これにより、TACACS+ などの外部サーバーがない環境でも詳細な設定履歴の管理が可能になります。
3.  **タイムスタンプ (iii):** 各ログメッセージに正確な時刻情報を付与します。ミリ秒（msec）単位の精度や、タイムゾーン情報の付与、起動時からの経過時間（uptime）の表示などを制御できます。

---

## 🔑 要点

### 1. ロギングの出力先と重要度レベル (i)

Cisco デバイスでは、ログを以下の場所に送信できます。
*   **Console:** 物理コンソールポートに出力。
*   **Buffered:** RAM 内の内部バッファに保存（`show logging` で確認）。
*   **Monitor:** SSH/Telnet セッションに出力。
*   **Host (Syslog):** 外部サーバーへ転送。
*   **Flash:** 内蔵フラッシュ内のファイルに保存。

重要度レベル（Severity Levels）は 0 から 7 で定義されます。
| レベル | 名称 | 内容 |
| :--- | :--- | :--- |
| **0** | **Emergency** | システムが使用不能な状態 |
| **1** | **Alert** | 直ちに対処が必要な状態 |
| **2** | **Critical** | 致命的なエラー |
| **3** | **Error** | 一般的なエラー |
| **4** | **Warning** | 警告メッセージ |
| **5** | **Notice** | 重大ではないが注意すべき通知 |
| **6** | **Informational** | 情報提供メッセージ |
| **7** | **Debugging** | デバッグ用メッセージ（負荷が高い） |

### 2. 設定変更の監査（Configuration Logging）(ii)

`archive` 機能を有効にすると、`log config` セクションを通じて設定コマンドの入力を自動的に記録できます。
*   **通知:** 設定変更が発生した際に Syslog メッセージを生成します。
*   **パスワード保護:** `hidekeys` を設定することで、設定ログ内のパスワードや SNMP コミュニティ文字列をアスタリスクで伏せ、セキュリティを確保します。
*   **永続性:** コンフィギュレーションロガー永続性機能を使用すると、リロード後も設定コマンドの履歴を維持できます。

### 3. タイムスタンプとシーケンス番号 (iii)

正確なログ分析のために、`service timestamps` コマンドが重要です。
*   **datetime:** 日付と時刻（月/日 時:分:秒）で記録。
*   **uptime:** デバイスが起動してからの経過時間（時:分:秒）で記録。
*   **Sequence Numbers:** 同じ時刻に大量のログが出た場合に順序を特定するため、通し番号を付与します。

### 4. 条件付きデバッグ (Conditional Debugs) (i)

通常のデバッグ（`debug ip packet` など）は CPU 負荷が高すぎて管理アクセスを遮断する恐れがあります。**Conditional Debug** を使用すると、特定のインターフェイス、IP アドレス、またはプロトコルに関連するトラフィックのみを抽出してデバッグ出力を生成できるため、安全かつ効率的です。

---

## 🎯 試験対策 (CCIE EIレベル)

ラボ試験では、単にロギングを有効にするだけでなく、特定の制限や要件を満たす実装能力が求められます。

### 1. レートリミット (Logging Rate-limit)

*   **シナリオ:** 「特定の重要度レベル以外のログ出力を秒間 X 回に制限せよ」といったタスク。
*   **対策:** `logging rate-limit` を使用して、CPU 保護と Syslog の輻輳回避を同時に行います。

### 2. 送信元インターフェイスの固定

*   **シナリオ:** 「Syslog サーバーへのパケット送信元を Loopback 0 に固定せよ」。
*   **対策:** `logging source-interface Loopback0` を構成します。これは、管理セグメントをルーティングで分離している環境で必須となる設定です。

### 3. 設定の監査とセキュリティ

*   **シナリオ:** 「外部認証サーバー（TACACS+/ISE）を使わずに、誰がどの設定を変えたかを 500 件分、パスワードを伏せて記録し、Syslog でも通知せよ」。
*   **対策:** `archive` 機能の `log config` で `logging size 500`, `hidekeys`, `notify syslog` を組み合わせます。

### 4. 再起動後の証跡管理

*   **シナリオ:** 「デバイスがクラッシュして再起動した後も、直前に入力されたコマンド履歴を確認できるようにせよ」。
*   **対策:** `logging persistent` を有効にしてセキュアファイルシステムにログを保持します。

---

## 🛠 設定・検証コマンド

### ロギング・基本・詳細設定

| 目的 | コマンド |
| :--- | :--- |
| **Syslog サーバーの指定** | <code>logging host [IP_ADDRESS]</code> |
| **外部送信ログの重要度制限** | <code>logging trap [0-7 &#124; severity-name]</code> |
| **バッファロギングのサイズ設定** | <code>logging buffered [SIZE_IN_BYTES]</code> |
| **送信元インターフェイスの指定** | <code>logging source-interface [INTERFACE]</code> |
| **ログメッセージのレート制限** | <code>logging rate-limit [VALUE] [except LEVEL]</code> |
| **タイムスタンプの設定(日付時刻)** | <code>service timestamps [log&#124;debug] datetime msec show-timezone</code> |
| **シーケンス番号の有効化** | <code>service sequence-numbers</code> |

### 設定変更ロギング (Archive)

| 目的 | コマンド |
| :--- | :--- |
| **アーカイブ設定モードの開始** | <code>archive</code> |
| **設定ロギングの有効化** | <code>(config-archive)# log config</code> <br> <code>(config-archive-log-cfg)# logging enable</code> |
| **パスワードの秘匿化** | <code>(config-archive-log-cfg)# hidekeys</code> |
| **Syslog への通知送信** | <code>(config-archive-log-cfg)# notify syslog</code> |
| **ログ保存件数の指定** | <code>(config-archive-log-cfg)# logging size [NUMBER]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **全ロギング設定とバッファ確認** | <code>show logging</code> |
| **設定変更履歴の表示** | <code>show archive log config all</code> |
| **アーカイブ履歴の統計確認** | <code>show archive log config statistics</code> |
| **特定のデバッグ条件の確認** | <code>show debugging</code> |
| **デバッグの全停止** | <code>undebug all</code> (またはエイリアス設定 <code>u</code>) |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 外部 Syslog サーバーへの基本転送

**【要件】** Syslog サーバー 10.1.1.1 に、Warning 以上の重大度のログを送信せよ。
```ios
logging host 10.1.1.1
logging trap 4
```

---

### 2. 大容量バッファとミリ秒タイムスタンプ

**【要件】** 内部バッファを 1MB に設定し、ログにはミリ秒とローカルタイムゾーンを含めよ。
```ios
logging buffered 1000000
service timestamps log datetime msec localtime show-timezone
```

---

### 3. 設定変更のローカル監査証跡

**【要件】** 入力された設定コマンドを 200 件まで記録し、`show archive log config all` で確認可能にせよ。
```ios
archive
 log config
  logging enable
  logging size 200
```

---

### 4. セキュアな設定ログ (Hidekeys)

**【要件】** 設定ログに SNMP コミュニティ文字列やパスワードが表示されないようにせよ。
```ios
archive
 log config
  hidekeys
```

---

### 5. ログパケットのソース IP 固定

**【要件】** 全てのロギングパケットの送信元を Loopback 0 の IP に統一せよ。
```ios
logging source-interface Loopback0
```

---

### 6. ロギングのレートリミット設定

**【要件】** ログ出力を秒間 50 パケットに制限せよ。ただし、通知レベル (5) は制限から除外せよ。
```ios
logging rate-limit 50 except 5
```

---

### 7. インターフェイス指定の条件付きデバッグ

**【要件】** GigabitEthernet0/1 を通過するパケットのみを対象とした IP パケットデバッグを実施せよ。
```ios
debug condition interface GigabitEthernet0/1
debug ip packet
! 検証
show debugging
```

---

### 8. シーケンス番号による順序付け

**【要件】** タイムスタンプが重複しても順序が分かるよう、全てのログにシーケンス番号を付加せよ。
```ios
service sequence-numbers
```

---

### 9. 設定変更の Syslog 即時通知

**【要件】** 誰かが設定を変更した際、即座に Syslog メッセージを生成してサーバーに知らせよ。
```ios
archive
 log config
  notify syslog
```

---

### 10. フラッシュメモリへの永続ロギング

**【要件】** ログをバッファだけでなく、`flash:/log_msg.txt` に最大 40KB のサイズで保存せよ。
```ios
logging file flash:log_msg.txt 40960
```

---

### 11. リロードを越えた設定履歴の保持 (Persistent)

**【要件】** デバイスの再起動後も、入力されたコンフィギュレーションコマンドの履歴を保持せよ。
```ios
archive
 log config
  logging persistent auto
  logging persistent size 16384
```

---

### 12. 特定レベル以外のコンソール出力停止

**【要件】** コンソールに不要なメッセージが出ないよう、Error (3) 以上の深刻なログのみ表示せよ。
```ios
logging console 3
! 重要度の低い informational 等はバッファのみに溜まる
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN and IOS XE**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - ロギングと条件付きデバッグを用いた高度な診断手法。
*   [**BRKOPS-2431: Network Automation in Theory and Practice**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431) - プログラマビリティ環境でのロギングの重要性。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE 試験における管理プロトコルのベストプラクティス。

### Configuration ガイド
*   [**Cisco IOS XE 17.x システム管理コンフィグレーションガイド: ロギング**](https://www.cisco.com/c/ja_jp/td/docs/ios-xml/ios/fundamentals/configuration/xe-17/fundamentals-xe-17-book.html)。
*   [**Configuring System Message Logging and Smart Logging**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sys_mgmt/b_179_sys_mgmt_9300_cg.html)。

### テクニカルドキュメント・設定例
*   [**Troubleshooting Cisco IOS Syslog (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/13506-snmpv3.html)。
*   [**Configuration Change Notification and Logging (Feature Guide)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/config-mgmt/configuration/xe-16/config-mgmt-xe-16-book/cm-config-logger.html)。
*   [**Understanding Conditional Debug and Radioactive Tracing**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-9300-series-switches/217112-verify-mpls-on-catalyst-9000-switches.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験においてデバイスの自己診断と監査機能をいかに論理的に構成するかを網羅しています。ラボ試験では、特に **`show archive log config all`** を実行した際に、意図したコマンドが正確なタイムスタンプと共に記録されているかを確認する習慣をつけることが合格への近道です。


