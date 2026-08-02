---
layout: default
title: 4.3.a-Device-management
parent: 4.3-System-management
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.3 System Management

本メモでは、CCIE Enterprise Infrastructure (EI) v1.1 ネットワークインフラの管理基盤となる **Device Management** について、レガシーな CLI アクセスから次世代のモデル駆動型テレメトリまでを網羅します。ラボ試験において、これらの管理チャネルが構成されていない、あるいは誤設定されていると、他のすべてのタスク（ルーティング、SD-WAN、自動化等）の検証が不可能になるため、極めて重要な「Day-0」スキルです。

---

## 📘 概要

**Device Management** は、ネットワークエンジニアがデバイスを操作するための「窓口」です。Cisco IOS XE では、人間が直接操作する CLI インターフェイス（Console, VTY）と、プログラムやスクリプトが操作する API インターフェイス（RESTCONF, NETCONF）の両方が提供されます。

1.  **Console and VTY (i):** 物理的なシリアル接続（Console）と、ネットワーク経由のリモート接続（VTY）の管理です。
2.  **SSH and SCP (ii):** 安全なリモート管理（SSH）と、暗号化されたファイル転送（SCP）を提供します。従来の Telnet や FTP に代わる標準プロトコルです。
3.  **RESTCONF and NETCONF (iii):** YANG データモデルに基づいた「モデル駆動型プログラマビリティ」のインターフェイスです。これにより、CLI のテキスト解析に頼らない、構造化されたデータによる自動制御が可能になります。

---

## 🔑 要点

### 1. Console & VTY (i)

*   **Console:** 補助ポートを使用しない物理直接接続。通常、AAA の設定ミス時などの「最後の砦」として機能します。
*   **VTY (Virtual Typewriter):** ネットワーク経由の Telnet/SSH 用の論理回線。`transport input` により受け入れるプロトコルを制御します。

### 2. SSH & SCP (ii)

*   **SSH (Secure Shell):** TCP ポート 22 を使用。バージョン 2 の使用が強く推奨されます。
    *   **要件:** 一意の `hostname`、`ip domain-name`、および一定以上の長さ（通常 1024 ビット以上）の RSA キーペア生成が必要です。
*   **SCP (Secure Copy):** SSH をトランスポートとして使用するセキュアなファイル転送プロトコルです。`ip scp server enable` で有効化します。

### 3. NETCONF & RESTCONF (iii)

*   **NETCONF:** SSH 上で動作（TCP ポート 830）。XML 形式を使用して、デバイスのコンフィギュレーションや状態を取得・変更します。
*   **RESTCONF:** HTTP/HTTPS 上で動作（TCP ポート 80/443）。JSON または XML 形式を使用し、RESTful API の操作（GET, POST, PUT, PATCH, DELETE）に対応します。
*   **YANG モデル:** これらの API がやり取りするデータの「構造」を定義した設計図です。

---

## 🎯 試験対策 (CCIE EIレベル)

ラボ試験では、単なる有効化だけでなく、**セキュリティとアクセス制限**、および **不具合の特定** が求められます。

### 1. VTY のアクセス制御 (ACL)

*   **要件:** 「管理ネットワーク以外の IP からのアクセスを拒否せよ」。
*   **対策:** 拡張または標準 ACL を作成し、`line vty` 配下で `access-class` コマンドを使用して適用します。`in` 方向の適用が一般的です。

### 2. SSH のトラブルシューティング

*   **罠:** RSA キーが生成されていない、あるいは `transport input` で `none` または `telnet` のみが指定されている場合、SSH 接続は拒否されます。
*   **認証:** 常にローカルデータベース（`username`）または AAA サーバー（ISE 等）との整合性を確認してください。

### 3. API インターフェイスの有効化要件

*   **RESTCONF:** 有効化には `ip http secure-server`（HTTPS サーバ）が必要です。
*   **NETCONF:** 有効化には `aaa new-model` および適切な認証・認可の設定が必須です。認証されていない状態で NETCONF セッションを張ることはできません。

### 4. タイムアウト設定

*   **実務:** 無操作時にセッションを自動切断する `exec-timeout` の設定が、セキュリティ要件として出題されることがあります。

---

## 🛠 設定・検証コマンド

### CLI 管理（Console / VTY / SSH）

| 目的 | コマンド |
| :--- | :--- |
| **RSA キーの生成** | <code>crypto key generate rsa modulus 1024</code> |
| **SSH v2 の強制** | <code>ip ssh version 2</code> |
| **VTY 回線のアクセス許可設定** | <code>line vty 0 4</code> <br> <code> transport input ssh</code> |
| **VTY への ACL 適用** | <code>line vty 0 4</code> <br> <code> access-class [ACL_ID] in</code> |
| **無操作切断時間の設定** | <code>exec-timeout [MINUTES] [SECONDS]</code> |
| **SCP サーバの有効化** | <code>ip scp server enable</code> |

### モデル駆動型管理（NETCONF / RESTCONF）

| 目的 | コマンド |
| :--- | :--- |
| **NETCONF の有効化** | <code>netconf-yang</code> |
| **RESTCONF の有効化** | <code>restconf</code> |
| **HTTPS サーバ（RESTCONF用）** | <code>ip http secure-server</code> |
| **認証の設定（基本）** | <code>ip http authentication local</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **現在ログイン中のユーザ確認** | <code>show users</code> |
| **SSH セッションの状態確認** | <code>show ssh</code> |
| **RSA キーの有無を確認** | <code>show crypto key mypubkey rsa</code> |
| **NETCONF セッションの確認** | <code>show netconf-yang sessions</code> |
| **VTY インターフェイスの状態** | <code>show line vty [NUM]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. SSH v2 接続の最小構成

**【問題】** R1 において、ホスト名 `R1`、ドメイン `ccie.com` を設定し、SSH バージョン 2 による接続を可能にせよ。
```ios
hostname R1
ip domain-name ccie.com
crypto key generate rsa modulus 2048
ip ssh version 2
username admin privilege 15 secret cisco
line vty 0 4
 login local
 transport input ssh
```

---

### 2. VTY へのアクセス制限 (ACL)

**【問題】** 10.1.1.0/24 のセグメントからのみ VTY 接続を許可し、他はすべて拒否せよ。
```ios
ip access-list standard VTY_FILTER
 permit 10.1.1.0 0.0.0.255
line vty 0 15
 access-class VTY_FILTER in
```

---

### 3. SCP サーバーの有効化とファイル転送準備

**【問題】** SSH 経由でのファイル転送を可能にするため、SCP サーバーを有効化せよ。
```ios
ip scp server enable
! 検証
show ip scp
```

---

### 4. コンソールポートのセキュリティ強化

**【問題】** コンソールポートに 5 分間のタイムアウトを設定し、ログインを必須にせよ。
```ios
line con 0
 exec-timeout 5 0
 login local
```

---

### 5. NETCONF インターフェイスの有効化

**【問題】** デバイスをプログラムから管理するため、標準の NETCONF ポート (830) を有効化せよ。
```ios
netconf-yang
! SSHが有効である必要がある
```

---

### 6. RESTCONF インターフェイスの有効化

**【問題】** HTTPS を使用して RESTCONF API を利用可能にせよ。認証はローカルデータベースを使用すること。
```ios
ip http secure-server
ip http authentication local
restconf
```

---

### 7. VTY ラインにおける特定プロトコルの遮断

**【問題】** セキュリティ要件に基づき、Telnet 接続を一切禁止し、SSH のみを受け入れるようにせよ。
```ios
line vty 0 4
 transport input ssh
```

---

### 8. SSH バナーの設定 (MOTD)

**【問題】** ログイン時に「Authorized Access Only」という警告を表示させよ。
```ios
banner motd ^C
Authorized Access Only. All activities are logged.
^C
```

---

### 9. 特権 15 ユーザの自動昇格

**【問題】** ユーザ `OPERATOR` が SSH でログインした際、自動的に特権モード（レベル 15）に入るようにせよ。
```ios
username OPERATOR privilege 15 secret cisco
line vty 0 4
 privilege level 15
```

---

### 10. API セッションのモニタリング

**【問題】** 現在確立されている NETCONF セッションがいくつあるか確認せよ。
```ios
# show netconf-yang sessions
! 期待される出力: 接続中のIPアドレス、ユーザ、セッションIDが表示される
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKOPS-2431: Network Automation - A journey from YANG to NETCONF/RESTCONF**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2431)
    *   CLI からモデル駆動型管理への移行に関する技術解説。
*   [**BRKCRT-1385: The CCIE in an SDN World - Device Management**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE 試験におけるプログラマビリティと管理技術の価値。

### Configuration ガイド
*   [**Cisco IOS XE 17.x システム管理コンフィグレーションガイド**](https://www.cisco.com/c/ja_jp/td/docs/ios-xml/ios/fundamentals/configuration/xe-17/fundamentals-xe-17-book.html)
*   [**Configuring Secure Shell (SSH) on Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_usr_ssh/configuration/xe-17/sec-usr-ssh-xe-17-book.html)

### テクニカルドキュメント・設定例
*   [**Programmability Configuration Guide, Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/prog/configuration/176/b_176_programmability_cg.html)
*   [**Troubleshooting Console and VTY Access (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ios-xml/ios/sec_usr_ssh/configuration/xe-17/sec-usr-ssh-xe-17-book.html)

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験における **「接続性」の基礎** を網羅しています。特に **VTY のアクセス制限** と **SSH キーの整合性**、そして **API の有効化条件** は、試験開始直後のセットアップフェーズで必ず確認すべき項目です。


