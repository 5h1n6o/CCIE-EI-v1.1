---
layout: default
title: 4.3.b-SNMP
parent: 4.3-System-management
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.3.b SNMP (v2c, v3)

ネットワーク管理の標準プロトコルである **SNMP (Simple Network Management Protocol)** は、CCIE Enterprise Infrastructure (EI) ラボ試験において、インフラの監視と管理を構成する重要な要素です。本稿では、レガシーな SNMP v2c から、高度なセキュリティを備えた SNMP v3 の実装、および CCIE レベルで求められる詳細な制御について詳述します。

---

## 📘 概要

**SNMP** は、管理システム（NMS: Network Management System）とネットワークデバイス（エージェント）間で管理情報を交換するためのアプリケーション層プロトコルです。デバイスの稼働状態、インターフェイスの統計、エラーログなどの情報を取得（Polling）したり、デバイス側から異常を即時通知（Trap/Inform）したりするために使用されます。

CCIE ラボ試験では、単にコミュニティストリングを設定するだけでなく、**SNMP View** によるアクセス範囲の限定や、**SNMP v3** における認証・暗号化（AuthPrivモデル）の正確な実装、さらには **ACL (Access Control List)** を用いた管理プレーンの保護が問われます。

---

## 🔑 要点

### 1. SNMP のバージョン比較

| 特徴 | SNMP v1 / v2c | SNMP v3 |
| :--- | :--- | :--- |
| **セキュリティ** | コミュニティストリング（プレーンテキスト）のみ | ユーザベースのセキュリティモデル (USM) |
| **認証** | なし | MD5 または SHA による認証 |
| **暗号化** | なし | DES, 3DES, AES によるペイロード暗号化 |
| **通知方法** | Trap (応答確認なし) | Trap および Inform (応答確認あり) |

### 2. SNMP v3 のセキュリティレベル (USM)

SNMP v3 では、以下の 3 つのセキュリティレベルを選択できます。
*   **noAuthNoPriv:** 認証なし、暗号化なし（ユーザ名照合のみ）。
*   **authNoPriv:** 認証あり、暗号化なし（パスワードによる正当性確認）。
*   **authPriv:** 認証あり、暗号化あり（CCIE レベルでの標準要件）。

### 3. SNMP コンポーネント

*   **MIB (Management Information Base):** デバイス内の管理データ項目の集合。
*   **OID (Object Identifier):** MIB 内の各項目を指し示すユニークな ID（例：1.3.6.1.2.1...）。
*   **View (ビュー):** 特定の OID サブツリーへのアクセスを許可または拒否するために定義するフィルタです。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験において SNMP は「周辺タスク」に見られがちですが、他のセクションの要件と組み合わさることが多く、注意が必要です。

### 1. 管理プレーンのアクセス制御 (ACL)

NMS サーバーの IP アドレスを ACL で定義し、SNMP 設定に紐付けることが必須です。
*   **罠:** コミュニティストリングが正しくても、ACL で許可されていない送信元からのリクエストはドロップされます。

### 2. SNMP View による「最小権限」の実装

「特定の MIB-2 オブジェクトのみを閲覧可能にせよ」といった要件が出題されます。
*   `snmp-server view [VIEW_NAME] [OID] included` コマンドを使用して、許可するツリーを定義するスキルが必要です。

### 3. SNMP v3 Inform の構成

Trap は一方的な通知ですが、**Inform** は NMS からの ACK（確認応答）を待ちます。
*   ACK が得られない場合のリトライ回数やタイムアウトの微調整が問われることがあります。

### 4. EngineID の理解

SNMP v3 の認証において、EngineID はデバイスの一意性を保証します。
*   リモート EngineID を手動で構成する必要があるシナリオ（特定の Inform 設定時など）への理解が求められます。

---

## 🛠 設定・検証コマンド

### SNMP v2c 基本設定

| 目的 | コマンド |
| :--- | :--- |
| **ROコミュニティの設定** | <code>snmp-server community [STRING] RO</code> |
| **RWコミュニティの設定** | <code>snmp-server community [STRING] RW</code> |
| **ACLによるアクセス制限** | <code>snmp-server community [STRING] RO [ACL_ID]</code> |
| **システム連絡先・場所の設定** | <code>snmp-server contact [NAME]</code> <br> <code>snmp-server location [STRING]</code> |

### SNMP v3 設定 (AuthPriv)

| 目的 | コマンド |
| :--- | :--- |
| **SNMP View の定義** | <code>snmp-server view [VIEW_NAME] [OID] included</code> |
| **SNMP Group の作成** | <code>snmp-server group [NAME] v3 priv read [VIEW] write [VIEW]</code> |
| **SNMP User の作成** | <code>snmp-server user [NAME] [GROUP] v3 auth [md5&#124;sha] [PWD] priv [aes 128&#124;256] [PWD]</code> |

### 通知 (Traps/Informs) 設定

| 目的 | コマンド |
| :--- | :--- |
| **トラップ送信先の指定** | <code>snmp-server host [IP] [STRING]</code> |
| **特定のトラップを有効化** | <code>snmp-server enable traps [notification-type]</code> |
| **Inform の有効化** | <code>snmp-server host [IP] informs version [2c&#124;3] [STRING]</code> |

### 検証・デバッグ

| 目的 | コマンド |
| :--- | :--- |
| **SNMP 設定の概要確認** | <code>show snmp</code> |
| **SNMP v3 ユーザの確認** | <code>show snmp user</code> |
| **SNMP v3 グループの確認** | <code>show snmp group</code> |
| **コミュニティ情報の表示** | <code>show snmp community</code> |
| **SNMP パケットのリアルタイム監視** | <code>debug snmp packets</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な v2c RO/RW コミュニティ

**【要件】** RO ストリングを `KBITS-RO`、RW ストリングを `KBITS-RW` として構成せよ。
```ios
snmp-server community KBITS-RO RO
snmp-server community KBITS-RW RW
```

---

### 2. ACL によるアクセス制限付きコミュニティ

**【要件】** 10.1.1.0/24 以外からの SNMP ポーリングを拒否せよ。
```ios
access-list 10 permit 10.1.1.0 0.0.0.255
snmp-server community KBITS-SEC RO 10
```

---

### 3. SNMP View による限定アクセス

**【要件】** ビュー `ROVIEW` を作成し、MIB-2 オブジェクト (1.3.6.1.2.1) のみを閲覧可能にせよ。
```ios
snmp-server view ROVIEW mib-2 included
snmp-server community RESTRICTED-RO view ROVIEW RO
```

---

### 4. SNMP v3 グループの作成 (AuthPriv)

**【要件】** グループ `RWGROUP` を作成し、authPriv セキュリティレベルを強制せよ。
```ios
snmp-server group RWGROUP v3 priv read ROVIEW write RWVIEW
```

---

### 5. SNMP v3 ユーザの作成 (SHA/AES)

**【要件】** ユーザ `ADMIN3` に対し、SHA 認証と AES 256 暗号化を構成せよ。
```ios
snmp-server user ADMIN3 RWGROUP v3 auth sha P@ssw0rd123 priv aes 256 P@ssw0rd456
```

---

### 6. 特定のトラップ通知（Config変更）の有効化

**【要件】** 設定変更が発生した際に、即座に NMS へ通知せよ。
```ios
snmp-server enable traps config
snmp-server host 10.10.10.100 version 2c KBITS-TRAP
```

---

### 7. SNMP Inform (v2c) の構成

**【要件】** 10.2.2.2 への通知を、信頼性向上のため Trap ではなく Inform として構成せよ。
```ios
snmp-server host 10.2.2.2 informs version 2c KBITS-COMM
```

---

### 8. SNMP Contact と Location の設定

**【要件】** デバイス情報を「NOC_CCIE」、「Rack_4_DC1」として登録せよ。
```ios
snmp-server contact NOC_CCIE
snmp-server location Rack_4_DC1
```

---

### 9. エンジン ID の手動指定

**【要件】** デバイスの SNMP EngineID を `800000090300AABBCC000300` に固定せよ。
```ios
snmp-server engineID local 800000090300AABBCC000300
```

---

### 10. VRF コンテキスト配下での SNMP v3 (CCIE レベル)

**【要件】** 管理用 VRF `MGMT` を経由して SNMP v3 ユーザ `VRF-USER` が通信可能にせよ。
```ios
snmp-server group VRF-GROUP v3 priv
snmp-server user VRF-USER VRF-GROUP v3 auth sha Cisco123 priv aes 128 Cisco123
snmp-server host 10.1.1.1 vrf MGMT version 3 priv VRF-USER
```

---

### 11. SNMP トラップ送信元インターフェイスの固定
**【要件】** トラップの送信元 IP アドレスを Loopback 0 に固定せよ。
```ios
snmp-server trap-source Loopback0
```

---

### 12. 歴史ログサイズの変更 (History size)
**【要件】** SNMP トラップとして送信されるログメッセージの履歴保持数を 10 に設定せよ。
```ios
logging history size 10
```

---

## 🔗 参考リソースリンク

### Cisco Live セッション (動画・スライド)
*   [**BRKNMS-2030: SNMP v3 Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKNMS-2030) - SNMP v3 のアーキテクチャとトラブルシューティングの基礎。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE ラボにおけるシステム管理プロトコルの位置付け。

### Configuration ガイド
*   [**Cisco IOS XE 17.x ネットワーク管理コンフィギュレーションガイド: SNMP**](https://www.cisco.com/c/ja_jp/td/docs/ios-xml/ios/fundamentals/configuration/xe-17/fundamentals-xe-17-book.html)。
*   [**Configuring SNMP Support (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/snmp/configuration/xe-17/snmp-xe-17-book.html)。

### テクニカルノーツ・設定例
*   [**SNMP v3 Authentication and Privacy Examples**](https://www.cisco.com/c/en/us/support/docs/ip/simple-network-management-protocol-snmp/13506-snmpv3.html)。
*   [**Troubleshooting SNMP on Catalyst Switches (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-9300-series-switches/217112-verify-mpls-on-catalyst-9000-switches.html)。

---
## 📝 補足

- この学習メモは、SNMP が単なる監視プロトコルではなく、**「管理プレーンのセキュリティ」**の一部であることを強調しています。CCIE ラボ試験では、`show snmp user` コマンドを使用して **EngineID や認証プロトコル (SHA/AES) の整合性** を迅速に確認できるかどうかが、時間を節約し確実にポイントを稼ぐ鍵となります。


