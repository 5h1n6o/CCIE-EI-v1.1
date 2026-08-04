---
layout: default
title: 5.2.b-Guest-shell
parent: 5.2-Automation-scripting
grand_parent: 5-Infrastructure-Automation-and-Programmability
nav_order: 2
---

# 5.2.b Guest shell

本ページでは、Cisco IOS XE デバイス上で動作する Linux コンテナ環境である **Guest Shell** と、その中での **Python** を活用した自動化手法について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲（5.2.b）に基づき詳述します。

---

## 📘 概要

**Guest Shell** とは、Cisco IOS XE に組み込まれた仮想化インフラである **IOX (Cisco IoT エコシステム)** 上で動作する、独立した Linux コンテナ環境（通常は CentOS ベース）です。

従来のネットワーク管理は外部の管理サーバから SSH や SNMP 経由で行われてきましたが、Guest Shell を利用することで、**デバイス内部（オンボックス）** で強力な Python スクリプトや Linux ツールを直接実行できるようになります。これにより、イベントに応じた高度な自動処理や、標準の CLI だけでは困難な複雑なデータ解析が可能になります。

### 主要な構成要素

*   **Linux Environment (i):** ルータの CPU やメモリリソースの一部を割り当てて動作するコンテナ。
*   **CLI Python Module (ii):** Python スクリプト内から IOS の `show` コマンドを実行したり、`configure terminal` による設定変更を行ったりするためのシスコ専用モジュール。
*   **EEM Python Module (iii):** 従来の EEM (Embedded Event Manager) アプレットの実行アクションとして Python スクリプトを呼び出す仕組み。

---

## 🔑 要点

### 1. Linux 環境としての特徴 (i)

*   **リソース管理:** `app-hosting` 設定を通じて、Guest Shell に割り当てる CPU 制限やメモリ制限、インターフェイスを指定します。
*   **ネットワーク接続:** ルータの管理用インターフェイス（GigabitEthernet0/0 等）とブリッジ接続するか、仮想的な内部ネットワークを介して通信します。外部のリポジトリから `yum` や `pip` でツールをインストールすることも可能です。
*   **ファイル共有:** IOS XE のフラッシュメモリ（`bootflash:`）は、Guest Shell 内では `/bootflash` などのディレクトリとしてマウントされ、スクリプトやログファイルを共有できます。

### 2. CLI Python モジュールの機能 (ii)

Guest Shell 内の Python では `cli` ライブラリを使用して IOS と対話します。主要な関数は以下の通りです。

| 関数名 | 特徴 |
| :--- | :--- |
| <code>execute()</code> | `show` コマンドを実行し、結果を文字列として返します。 |
| <code>executep()</code> | コマンドを実行し、結果を直接コンソールに出力します（print文不要）。 |
| <code>configure()</code> | リスト形式で設定コマンドを渡し、実行します。 |
| <code>configurep()</code> | 設定コマンドを実行し、その過程をコンソールに表示します。 |
| <code>clip()</code> | 文字列として渡された単一のコマンドを実行・表示します。 |

### 3. EEM との統合 (iii)

Python スクリプトを EEM と組み合わせることで、「インターフェイスがダウンした」「特定の Syslog が出た」といったトリガーに基づき、Guest Shell 内の Python を自動実行できます。これは、複雑な論理演算や外部サーバへの API 通知が必要な場合に、従来のアプレットよりも柔軟に対応できます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE EI ラボ試験では、自動化セクションにおいて「オンボックスでの解決策」を求められる場合に、Guest Shell が鍵となります。

### 1. 起動と初期化の迅速性

Guest Shell はデフォルトで無効です。`iox` を有効化し、`guestshell enable` を実行してから、実際に Linux プロンプトが出るまで待機する時間を含めた手順を体得しておく必要があります。

### 2. 引数（Arguments）のハンドリング

CLI から `guestshell run python script.py arg1 arg2` のように引数を渡すシナリオが想定されます。Python 側で `sys.argv` を使用してこれを受け取る処理が必須スキルです。

### 3. 特権レベルと権限

Guest Shell 内から実行される Python スクリプトは、ルータの特権レベルに従います。AAA 設定が厳しい環境では、適切なユーザー権限でスクリプトが動作するように配慮が求められる場合があります。

### 4. トラブルシューティング

*   `show iox-service` や `show app-hosting list` で Guest Shell の状態を確認できること。
*   Guest Shell 内から IOS の IP アドレス（通常は内部ゲートウェイ）への疎通を確認し、スクリプトが IOS にアクセスできない原因を特定できること。

---

## 🛠 設定・検証コマンド

### Guest Shell の有効化と管理

| 目的 | コマンド |
| :--- | :--- |
| **IOXサービスの有効化** | <code>(config)# iox</code> |
| **Guest Shellの起動** | <code># guestshell enable</code> |
| **Linuxシェルへのログイン** | <code># guestshell</code> |
| **IOXの状態確認** | <code>show iox-service</code> |
| **リソース割り当ての確認** | <code>show app-hosting detail appid guestshell</code> |

### スクリプトの実行と検証

| 目的 | コマンド |
| :--- | :--- |
| **Pythonの直接実行** | <code>guestshell run python /flash/myscript.py</code> |
| **Linuxコマンドの実行** | <code>guestshell run ls -l /bootflash</code> |
| **引数付きPython実行** | <code>guestshell run python script.py GigabitEthernet1</code> |

---

## 🧪 ラボ学習・設定サンプル例

Guest Shell の Python モジュールや Linux 環境を活用した 12 個の実装シナリオです。

### 1. Guest Shell の基本セットアップ

**【課題】** IOX を有効化し、Guest Shell コンテナを起動せよ。
```ios
conf t
 iox
exit
! 起動には数十秒かかる場合があります
guestshell enable
```

### 2. Python モジュールを使用した情報取得 (`execute`)

**【課題】** IP インターフェイスのサマリを取得し、変数に格納する Python コードを作成せよ。
```python
import cli
output = cli.execute('show ip interface brief')
print("Captured Output:\n" + output)
```

### 3. 設定の自動適用 (`configure`)

**【課題】** 特定のインターフェイス（Gi1）に記述を追加せよ。
```python
import cli
cli.configure(['interface GigabitEthernet1', 'description Configured_by_Python', 'end'])
```

### 4. コマンドライン引数の利用 (`sys.argv`)

**【課題】** 引数で指定したインターフェイスを `no shutdown` するスクリプトを作成せよ。
```python
import sys
from cli import configurep

if len(sys.argv) > 1:
    target_int = sys.argv
    configurep(['interface ' + target_int, 'no shutdown'])
else:
    print("Please specify an interface.")
```

### 5. `executep` による簡略化

**【課題】** `print` 文を使わずに OSPF ネイバー情報を表示せよ。
```python
from cli import executep
executep('show ip ospf neighbor')
```

### 6. ファイルへの書き出し (Linux連携)

**【課題】** `show version` の結果を `bootflash:version.txt` に保存せよ。
```python
import cli
output = cli.execute('show version')
with open('/bootflash/version.txt', 'w') as f:
    f.write(output)
```

### 7. EEM との連携 (Python呼び出し)

**【課題】** インターフェイス Gi1 がダウンした際、Python スクリプト `remedy.py` を実行せよ。
```ios
event manager applet AUTO_FIX
 event syslog pattern "Interface GigabitEthernet1, changed state to down"
 action 1.0 cli command "guestshell run python /flash/remedy.py"
```

### 8. インターフェイスの状態監視と修復ロジック

**【課題】** 特定の文字列が含まれる場合のみ設定を変更するロジック。
```python
import cli
data = cli.execute('show interface GigabitEthernet1')
if 'administratively down' in data:
    cli.configure(['interface GigabitEthernet1', 'no shutdown'])
```

### 9. 複数インターフェイスの一括生成

**【課題】** Loopback 100 から 105 までを一括で作成せよ。
```python
from cli import configure
cmds = []
for i in range(100, 106):
    cmds.append('interface Loopback' + str(i))
    cmds.append('ip address 10.255.255.' + str(i) + ' 255.255.255.255')
configure(cmds)
```

### 10. Linux シェルでの外部疎通確認

**【課題】** Guest Shell の Linux 環境から Google DNS (8.8.8.8) へ Ping を送信せよ。
```bash
[guestshell@localhost ~]$ ping -c 4 8.8.8.8
```

### 11. Guest Shell 内での環境変数確認

**【課題】** IOS と Guest Shell の接続用 IP アドレスを確認せよ。
```bash
[guestshell@localhost ~]$ ip addr show eth0
# eth0 は IOS との内部通信用仮想 NIC です
```

### 12. `clip` を使用した単一設定の実行

**【課題】** `clip` 関数を使用して、特定のホスト名を即座に反映・表示せよ。
```python
from cli import clip
clip('hostname PYTHON-ROUTER')
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKCRT-1385: The CCIE in an SDN World - Programmability Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
*   [**DGTL-BRKPRG-2451: Scripting IOS XE Beyond the Basics**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKPRG-2451)
*   [**BRKCRS-2452: Solving real world campus issues using programmability and automation**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2452)

### Configuration ガイド
*   [**Programmability Configuration Guide, Cisco IOS XE: Guest Shell**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg/m_guest_shell.html)
*   [**Python API Guide for Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/17/b_17_prog_cg/m_python_api.html)

### テクニカルドキュメント・設定例
*   [**Guest Shell Infrastructure and Configuration (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-9300-series-switches/214461-guest-shell-on-catalyst-9000-ios-xe-switc.html)
*   [**Cisco DevNet: Getting Started with IOS XE Python**](https://developer.cisco.com/learning/modules/iosxe-programmability-python-guestshell/)

---
## 📝 補足
この学習メモは、CCIE EI 実技試験において、**「単なる CLI 操作を超え、デバイスそのものに知能（スクリプト）を埋め込む」** ための Guest Shell 活用術を整理したものです。特に、Python の `cli` モジュールの使い分けと、EEM からの呼び出し方法は、ラボ試験の自動化課題で得点源となる重要なトピックです。

- 補足情報をここに追加してください。

