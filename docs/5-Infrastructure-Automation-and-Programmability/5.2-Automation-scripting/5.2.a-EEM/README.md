---
layout: default
title: 5.2.a-EEM
parent: 5.2-Automation-scripting
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 1
---

# 5.2.a EEM applets

本ページでは、Cisco IOS XE デバイスに組み込まれた強力な自動化ツールである **Embedded Event Manager (EEM)** のアプレット実装について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

**Embedded Event Manager (EEM)** は、デバイス内部で発生する様々な「イベント」を検出し、それに対して事前定義された「アクション」を自動的に実行するための分散システムフレームワークです。EEM を使用することで、ネットワーク管理者は手動介入なしにトラブルシューティング情報の収集、構成の変更、あるいは障害からの自己修復プロセスをデバイス上で直接実行させることができます。

EEM ポリシーには主に 2 つの種類があります。
1.  **EEM Applets:** Cisco IOS CLI を使用して定義される簡便なポリシー。専門的なプログラミング知識がなくても構成可能です。
2.  **EEM Scripts:** Tcl (Tool Command Language) を使用して記述される高度なスクリプト。複雑なロジックが必要な場合に使用されます。

CCIE EI 試験のセクション 5.2.a では、主に **EEM Applets** を使用したインフラの自動化と運用最適化が問われます。

---

## 🔑 要点

### 1. イベント・アクション モデル

EEM の動作は、**Event Detector (イベント検出器)** と **Action (アクション)** の組み合わせで成り立っています。
*   **Event Detector:** syslog メッセージ、タイマー、CLI 入力、インターフェイスの状態変化、IP SLA の結果、CPU/メモリの使用率（SNMP オブジェクト）などを監視します。
*   **Action:** 検出に応答して、CLI コマンドの実行、syslog の生成、電子メールの送信、SNMP トラップの発行などを行います。

### 2. 環境変数 (Environment Variables)

EEM は、システムが事前定義した変数やユーザーが独自に定義した変数を利用できます。
*   `$_syslog_msg`: 検出された syslog の本文。
*   `$_cli_result`: 最後に実行された CLI コマンドの出力結果。

### 3. ロジック制御（EEM 4.0）

最新の IOS XE で動作する EEM 4.0 では、アプレット内での高度な制御構造がサポートされています。
*   **条件分岐 (If/Else):** 特定の条件に一致する場合のみアクションを実行します。
*   **ループ (Foreach):** リスト内の項目に対して繰り返し処理を行います。

### 4. CLI インタラクション

EEM は `cli_run_interactive` を通じて、確認応答（Yes/No）が必要な対話型コマンドも自動化できます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単にコマンドを並べるだけでなく、特定のビジネス要件を EEM ロジックに落とし込む能力が試されます。

### 1. 決定論的な自己修復 (Self-Healing)

「重要なインターフェイスが管理ダウンされた場合、即座に UP に戻し、管理者に通知せよ」といった要件が典型的です。
*   **ポイント:** `event syslog pattern ".*changed state to administratively down"` をトリガーにし、アクションで `no shutdown` を実行します。

### 2. トラブルシューティング情報の自動収集

「BGP ネイバーが切れた瞬間に、特定の `show` コマンドの結果をフラッシュメモリに保存せよ」といったタスクが想定されます。
*   **ポイント:** `event syslog pattern ".*BGP-5-ADJCHANGE.*Down"` を監視し、`append` コマンド等でログファイルを作成します。

### 3. AAA との兼ね合い (Authorization Bypass)

EEM が CLI を実行する際、AAA 認証/認可によって拒否される場合があります。
*   **対策:** `event manager session cli username [USER]` コマンドで適切な権限を持つユーザーを指定するか、`authorization bypass` オプション（設定可能な場合）を検討します。

### 4. 正規表現 (Regexp) の活用

CLI 出力の中から特定の文字列（IP アドレスやエラーコード）を抽出して変数に格納し、後続のアクションで利用する高度な操作が問われます。

---

## 🛠 設定・検証コマンド

### EEM アプレット基本設定

| 目的 | コマンド |
| :--- | :--- |
| **アプレットの作成** | <code>event manager applet [NAME]</code> |
| **Syslogイベントの監視** | <code>event syslog pattern "[REGEX_PATTERN]"</code> |
| **インターフェイス監視** | <code>event interface name [INT] parameter [VAL] entry-val [VAL]</code> |
| **タイマーイベント(定期)** | <code>event timer periodic time [SECONDS]</code> |
| **CLIコマンドの実行** | <code>action [LABEL] cli command "[IOS_COMMAND]"</code> |
| **Syslogの生成** | <code>action [LABEL] syslog msg "[MESSAGE]"</code> |
| **メール送信** | <code>action [LABEL] mail server "[IP]" to "[ADDR]" from "[ADDR]" subject "[SUB]" body "[BODY]"</code> |

### ロジック・変数操作

| 目的 | コマンド |
| :--- | :--- |
| **IF文の開始** | <code>action [LABEL] if [CONDITION]</code> |
| **ループの開始** | <code>action [LABEL] foreach [VAR] "[LIST]"</code> |
| **変数のインクリメント** | <code>action [LABEL] increment [VAR] [VALUE]</code> |

### 検証・統計

| 目的 | コマンド |
| :--- | :--- |
| **登録済みポリシーの確認** | <code>show event manager policy registered [detailed]</code> |
| **実行履歴の表示** | <code>show event manager history events</code> |
| **環境変数の確認** | <code>show event manager environment</code> |
| **実行デバッグ** | <code>debug event manager action cli</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. インターフェイスの自動復旧

**【課題】** R1 の E0/0 が `shutdown` された場合、自動的に `no shutdown` を実行しメッセージを表示せよ。
```ios
event manager applet PROTECT_E00
 event syslog pattern "Interface Ethernet0/0.*administratively down"
 action 1.0 cli command "enable"
 action 2.0 cli command "configure terminal"
 action 3.0 cli command "interface Ethernet0/0"
 action 4.0 cli command "no shutdown"
 action 5.0 syslog msg "Critical interface E0/0 was restored!"
```

### 2. ルーティングダウン時のメール通知

**【課題】** EIGRP がダウンした際、管理者にアラートメールを送信せよ。
```ios
event manager applet EIGRP_ALERT
 event syslog pattern "DUAL-5-NBRCHANGE.*down"
 action 1.0 mail server "10.1.1.25" to "admin@ccie.local" from "R1@ccie.local" subject "EIGRP DOWN" body "EIGRP session failed, check logs"
```

### 3. 設定変更の自動バックアップ

**【課題】** `end` コマンドで設定モードを抜けた際、構成を TFTP サーバに保存せよ。
```ios
event manager applet AUTO_BACKUP
 event cli pattern "end" sync yes
 action 1.0 cli command "enable"
 action 2.0 cli command "copy running-config tftp://10.1.1.100/config-backup"
```

### 4. 複数アドレスへの一括 Ping 実行 (Foreach)

**【課題】** 特定のリストにある 5 つの IP に対して、定期的に疎通確認を行え。
```ios
event manager applet BATCH_PING
 event timer periodic time 3600
 action 1.0 foreach addr "10.1.1.1 10.1.1.2 10.1.1.3"
  action 2.0 cli command "ping $addr repeat 2"
 action 3.0 end
```

### 5. CPU 負荷上昇時の情報収集

**【課題】** CPU 使用率が 80% を超えたら、プロセス一覧をログに記録せよ。
```ios
event manager applet CPU_WATCH
 event snmp oid 1.3.6.1.4.1.9.9.109.1.1.1.1.3 get-type exact entry-op gt entry-val 80 poll-interval 5
 action 1.0 cli command "enable"
 action 2.0 cli command "show processes cpu sorted | append flash:cpu_stats.txt"
```

### 6. 特定ユーザーのログイン監視

**【課題】** ユーザー "guest" がログインしようとしたら拒否し、ログを残せ。
```ios
event manager applet DENY_GUEST
 event syslog pattern "LOGIN_SUCCESS.*user: guest"
 action 1.0 cli command "enable"
 action 2.0 cli command "clear line vty 0"
 action 3.0 syslog msg "Unauthorized guest login detected and terminated."
```

### 7. IP SLA 到達性失敗時の経路変更

**【課題】** SLA 1 が失敗（Timeout）した際、バックアップのスタティックルートを追加せよ。
```ios
event manager applet SLA_FAIL_ROUTE
 event track 1 state down
 action 1.0 cli command "enable"
 action 2.0 cli command "conf t"
 action 3.0 cli command "ip route 0.0.0.0 0.0.0.0 172.16.1.2"
```

### 8. CLI 入力の置換 (CLI イベントフィルタリング)

**【課題】** `reload` コマンドが入力された際、警告を出して実行を一時停止せよ。
```ios
event manager applet RELOAD_GUARD
 event cli pattern "reload" sync yes
 action 1.0 syslog msg "Reload attempted by user!"
 action 2.0 exit 0  ! 0を指定すると元のコマンドを実行させない
```

### 9. インターフェイス・フラッピングの抑制

**【課題】** 1 分間に 3 回以上リンクが変化したら、そのポートを `shutdown` せよ。
```ios
event manager applet FLAP_CONTROL
 event syslog pattern "LINEPROTO-5-UPDOWN.*GigabitEthernet0/1" rate-limit 60 occurrence 3
 action 1.0 cli command "enable"
 action 2.0 cli command "conf t"
 action 3.0 cli command "int Gi0/1"
 action 4.0 cli command "shutdown"
 action 5.0 syslog msg "Gi0/1 disabled due to flapping."
```

### 10. 時刻に基づいた QoS ポリシーの適用

**【課題】** 業務時間終了（18時）に、特定の帯域制限を有効化せよ。
```ios
event manager applet NIGHT_QOS
 event timer cron cron-entry "0 18 * * *"
 action 1.0 cli command "enable"
 action 2.0 cli command "conf t"
 action 3.0 cli command "int Gi0/0"
 action 4.0 cli command "service-policy output PM-RESTRICT"
```

### 11. 条件分岐を利用した構成チェック (If/Else)

**【課題】** インターフェイスの状態を確認し、UP でない場合のみ再起動を試みよ。
```ios
event manager applet CHECK_LINK
 event timer periodic time 300
 action 1.0 cli command "show int Gi0/1 | include line protocol"
 action 2.0 regexp "is down" "$_cli_result"
 action 3.0 if $_regexp_result eq "1"
  action 4.0 cli command "conf t"
  action 5.0 cli command "int Gi0/1"
  action 6.0 cli command "shutdown"
  action 7.0 cli command "no shutdown"
 action 8.0 end
```

### 12. 構成の整合性チェック（検証タスク）

**【操作】** `show event manager history events` を実行し、アプレットが意図した時刻に正常終了（Success）しているか確認せよ。
```ios
# show event manager history events
! 期待される出力: Applet: PROTECT_E00, Event: syslog, Status: success
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKCRS-2452: Solving real world campus issues using programmability and automation**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2452)
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Automation**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
*   [**DGTL-BRKPRG-2451: Scripting IOS XE Beyond the Basics**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKPRG-2451)

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Embedded Event Manager Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/eem/configuration/xe-17/eem-xe-17-book.html)
*   [**Writing EEM Policies Using the Cisco IOS CLI**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/eem/configuration/xe-16/eem-xe-16-book/eem-policy-cli.html)

### テクニカルドキュメント・設定例
*   [**EEM Applets Best Practices (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios-embedded-event-manager-eem/116409-technote-eem-00.html)
*   [**EEM 4.0 Logic and Variable Enhancements**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/eem/configuration/xe-3s/eem-xe-3s-book/eem-var-logic.html)

---

## 📝 補足
- この学習メモは、CCIE EI 実技試験において **「デバイスを単なるパケット転送機から、インテリジェントな自律運用ノードへ進化させる」** ための EEM 活用法を網羅しています。ラボ試験では、複雑なトラブルシューティング要件を EEM の「イベント」と「アクション」の論理に正しくマッピングできることが合格への鍵となります。

