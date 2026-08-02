---
layout: default
title: 4.1.b-AAA
parent: 4.1-Device-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.1.b AAA

Cisco IOS XE デバイスにおける **AAA (Authentication, Authorization, and Accounting)** は、ネットワークインフラのセキュリティを確保するための基本的なフレームワークです。CCIE Enterprise Infrastructure (EI) ラボ試験では、Cisco ISE (Identity Services Engine) と連携した高度なデバイス管理、障害時のフォールバック、および詳細なコマンドレベルの制御が頻出します。

---

## 📘 概要

**AAA** は、誰が (Authentication)、何を行うことができ (Authorization)、何を行ったか (Accounting) を管理する仕組みを提供します。

*   **Authentication (認証):** ユーザー名とパスワードを検証してユーザーの正当性を確認します。ローカルデータベースまたは外部サーバー（TACACS+/RADIUS）を使用します。
*   **Authorization (許可):** 認証されたユーザーが実行できる操作（コマンドや特権レベル）を定義します。
*   **Accounting (アカウンティング):** ユーザーがログインしていた時間や実行したコマンドのログを記録し、監査を可能にします。

エンタープライズ環境では、デバイス管理に **TACACS+** が、ネットワーク検波（802.1X等）に **RADIUS** が推奨されるのが一般的です。

---

## 🔑 要点

### 1. メソッドリスト (Method Lists)

AAA の挙動を定義する論理的なリストです。
*   **Default:** 明示的に指定しない限り、すべての回線（VTY, TTY, Console）に適用されます。
*   **Named:** 特定のインターフェイスやラインに個別に適用するための名前付きリストです。

### 2. プロトコルの比較: TACACS+ vs RADIUS

| 特徴 | TACACS+ | RADIUS |
| :--- | :--- | :--- |
| **トランスポート** | TCP 49 | UDP 1812/1813 |
| **セキュリティ** | パケット全体を暗号化 | パスワードのみ暗号化 |
| **分離性** | AAA を完全に分離して制御可能 | 認証と許可が統合されている |
| **主な用途** | デバイス管理 (CLI 制御) | ネットワークアクセス制御 (NAC) |

### 3. フォールバックメカニズム

外部サーバー (ISE 等) が到達不能な場合に備え、`local` データベースをバックアップとしてリストの最後に指定することが CCIE レベルでは必須の設計です。

### 4. 特権レベルとコマンド許可

デフォルトの特権レベル 15 だけでなく、特定のコマンドセットのみを許可する「コマンド許可 (Command Authorization)」を ISE と連携して実装します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる設定だけでなく「意図的な障害」への対応が求められます。

### 1. サーバー到達不能時の「締め出し」防止

*   **リスク:** TACACS+ サーバーを指定し、フォールバックの `local` を忘れると、サーバー停止時に誰もログインできなくなります。
*   **対策:** `aaa authentication login default group tacacs+ local` のように設定し、ローカルに特権ユーザーを作成しておきます。

### 2. コンソールポートの例外処理

*   **要件:** 「VTY には ISE 認証を適用し、コンソールにはローカル認証を適用せよ」という課題が出ます。
*   **実装:** 名前付きリストを作成し、`line con 0` に適用するか、`aaa authentication login` のリストを使い分けます。

### 3. コマンドアカウンティングの徹底

*   **要件:** 「特権レベル 15 のユーザーが実行したすべての設定変更コマンドを ISE に記録せよ」という課題。
*   **コマンド:** `aaa accounting commands 15 default start-stop group tacacs+`。

### 4. AAA サーバーグループの最適化

*   複数の ISE ノードがある場合、`aaa group server tacacs+` を定義して、優先順位やロードバランスを構成するスキルが問われます。

---

## 🛠 設定・検証コマンド

### AAA 基本・サーバー設定

| 目的 | コマンド |
| :--- | :--- |
| **AAA機能を有効化** | <code>aaa new-model</code> |
| **TACACS+サーバー定義** | <code>tacacs server [NAME]</code> <br> <code> address ipv4 [IP]</code> <br> <code> key [KEY]</code> |
| **サーバーグループ作成** | <code>aaa group server tacacs+ [GROUP_NAME]</code> <br> <code> server name [NAME]</code> |

### メソッドリスト設定

| 目的 | コマンド |
| :--- | :--- |
| **ログイン認証(Default)** | <code>aaa authentication login default group [GROUP] local</code> |
| **EXEC許可(Default)** | <code>aaa authorization exec default group [GROUP] local</code> |
| **コマンド許可(特権15)** | <code>aaa authorization commands 15 default group [GROUP]</code> |
| **アカウンティング(EXEC)** | <code>aaa accounting exec default start-stop group [GROUP]</code> |
| **アカウンティング(コマンド)** | <code>aaa accounting commands 15 default start-stop group [GROUP]</code> |

### 検証・デバッグ

| 目的 | コマンド |
| :--- | :--- |
| **AAAセッションの確認** | <code>show aaa sessions</code> |
| **ユーザー特権の確認** | <code>show privilege</code> |
| **認証プロセスのデバッグ** | <code>debug aaa authentication</code> |
| **許可プロセスのデバッグ** | <code>debug aaa authorization</code> |
| **サーバー状態の確認** | <code>show tacacs</code> |

---

## 🧪 ラボ学習・設定サンプル例

ソースの Workbook や実技シナリオに基づいた 12 の実装例です。

### 1. ローカル認証による最小構成

**【問題】** サーバーを使用せず、ローカルデータベースのみでログイン認証を有効化せよ。
```ios
username admin privilege 15 secret Cisco123
aaa new-model
aaa authentication login default local
```

---

### 2. TACACS+ と ISE の連携

**【問題】** サーバー "ISE-PRIMARY" を使用し、認証を委委譲せよ。
```ios
tacacs server ISE-PRIMARY
 address ipv4 10.1.1.10
 key cisco
!
aaa group server tacacs+ ISE-GROUP
 server name ISE-PRIMARY
!
aaa authentication login default group ISE-GROUP local
```

---

### 3. コンソールポートの認証除外

**【問題】** VTY 経由は ISE 認証、コンソールは認証なし（またはローカル）とせよ。
```ios
aaa authentication login NO_AUTH none
!
line con 0
 login authentication NO_AUTH
```

---

### 4. 特権 15 コマンドの許可 (Authorization)

**【問題】** 特権レベル 15 のユーザーがコマンドを実行する際、ISE の許可を得るようにせよ。
```ios
aaa authorization commands 15 default group ISE-GROUP local
```

---

### 5. コンフィギュレーション変更のログ記録

**【問題】** 誰が設定を変更したかすべて記録せよ。
```ios
aaa accounting commands 15 default start-stop group ISE-GROUP
```

---

### 6. 名前付きメソッドリストによる特定の管理

**【問題】** 特定のライン VTY 5-15 にのみ、独自の RADIUS リストを適用せよ。
```ios
aaa authentication login RADIUS_LIST group radius local
!
line vty 5 15
 login authentication RADIUS_LIST
```

---

### 7. Enable パスワードの AAA 制御

**【問題】** `enable` コマンド実行時のパスワードも ISE で管理せよ。
```ios
aaa authentication enable default group ISE-GROUP enable
```

---

### 8. VTY アクセスクラスと AAA の併用

**【問題】** ACL 10 でアクセス元を制限しつつ、AAA 認証を実施せよ。
```ios
line vty 0 4
 access-class 10 in
 login authentication default
```

---

### 9. サーバー到達不能時の動作検証 (Fallback)

**【問題】** ISE サーバーへの通信を ACL で遮断し、ローカルパスワードでログインできるか検証せよ。
```ios
! 検証手順
! 1. ISE宛のUDP/TCPを止める 2. ログイン試行 3. ローカルDBで入れることを確認
```

---

### 10. IPv6 環境での AAA

**【問題】** IPv6 アドレスの RADIUS サーバー (2001:DB8::10) を使用せよ。
```ios
radius server ISE-V6
 address ipv6 2001:DB8::10
 key cisco
```

---

### 11. 特権レベル 1 ユーザーの EXEC 昇格許可

**【問題】** ログイン直後はレベル 1 だが、ISE の属性によりレベル 15 へ自動昇格させよ。
```ios
aaa authorization exec default group ISE-GROUP local
! ※ISE側のShell Profileで Privilege 15 を設定
```

---

### 12. アカウンティングの送信元インターフェイス固定

**【問題】** ログの送信元を Loopback 0 に固定せよ。
```ios
ip tacacs source-interface Loopback0
```

---

## 🔗 参考リンク

### 関連動画・スライド (Cisco Live)
*   [**BRKSEC-2001: Common AAA Troubleshooting with ISE**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001) - 認証・許可の不整合をデバッグする方法。
*   [**BRKCRT-1385: The CCIE in an SDN World - Security Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIEラボにおけるセキュリティの重要性。

### Configuration ガイド
*   [**Authentication, Authorization, and Accounting Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_usr_aaa/configuration/xe-17/sec-usr-aaa-xe-17-book.html)
*   [**Cisco ISE 3.1 Administrator Guide - Device Administration**](https://www.cisco.com/c/en/us/td/docs/security/ise/3-1/admin_guide/b_ise_admin_3_1.html)

### テクニカルドキュメント・設定例
*   [**Configuring TACACS+ on Cisco IOS XE (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/security-software/identity-services-engine/200215-Configure-ISE-2-0-TACACS-Device-Adminis.html)
*   [**AAA Troubleshooting Commands and Examples**](https://www.cisco.com/c/en/us/support/docs/security-software/identity-services-engine/116301-technote-ise-00.html)

---

## 📝 補足
- この学習メモは、CCIE EI 試験における AAA の実装が、単なる「コマンドの投入」ではなく、**「サーバー障害時や管理ミスを想定した回復力の設計」**であることを示しています。ラボ試験では、ISE との通信が途絶えた際でも `show running-config` を確認して設定を修正できる「セーフティネット」の構成を常に意識してください。


