---
layout: default
title: 4.3.a-Device-management
parent: 4.3-System-management
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.3.a Device management

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint の Blueprint 項目 **4.3.a Device management** [(i) Console and VTY, (ii) SSH, SCP, (iii) RESTCONF, NETCONF] に関する実務および CCIE EI ラボ試験直前復習用の超詳細学習メモ。

---

## 📘 概要

デバイス管理（Device Management）は、ルータおよびスイッチへのアクセス、設定変更、自動化、ファイル転送、および状態監視を安全かつ確実に行うためのネットワークインフラストラクチャの最重要基盤技術である。Cisco IOS XE 17.x 環境においては、従来の CLI アクセス（Console, VTY, SSH, SCP）に加え、YANG データモデルをベースとしたプログラマブルなモデル駆動型管理（Model-Driven Management: NETCONF, RESTCONF）が提供されている。

* **Console and VTY:**
  * **Console ポート:** シリアル直接接続によるアウトオブバンド（OOB）物理アクセス。ネットワーク接続不能時や初期セットアップ時、リカバリ作業で使用。
  * **VTY (Virtual Terminal) ライン:** Telnet や SSH 経由でのネットワーク経由 Remote CLI アクセスチャネル（通常 0-15 またはそれ以上）。
* **SSH and SCP:**
  * **SSH (Secure Shell v2):** 平文の Telnet を置き換える暗号化 CLI セッションプロトコル（TCP 22）。強固な暗号化アルゴリズム（RSA 2048bit / ECDSA）とディフィー・ヘルマン鍵交換により中間者攻撃（MitM）や盗聴を防止する。
  * **SCP (Secure Copy Protocol):** SSH をトランスポートとして使用し、デバイス間および外部サーバー間（flash: ⇔ リモートサーバー）で IOS XE イメージやコンフィグファイルを暗号化転送するプロトコル。
* **NETCONF and RESTCONF:**
  * **NETCONF (RFC 6241):** XML ベースのメッセージ構造を持ち、TCP 830 上の SSH セッションを通じてネットワーク機器のコンフィグレーションおよび状態データを操作するプログラマブルなプロトコル。トランザクション管理（Candidate データストア、Commit、Rollback、Lock）をサポートする。
  * **RESTCONF (RFC 8040):** HTTP/HTTPS (TCP 443) 上で RESTful API アプローチ（GET, POST, PUT, PATCH, DELETE）を用いて YANG モデル化されたデータを操作する軽量プロトコル。データフォーマットとして JSON および XML をサポートする。

---

## 🔑 要点

| 項目 | Console / VTY | SSH / SCP | NETCONF | RESTCONF |
| :--- | :--- | :--- | :--- | :--- |
| **トランスポート** | シリアル / TCP (VTY) | TCP 22 (SSH) | TCP 830 (SSH) | TCP 443 (HTTPS) |
| **データフォーマット** | CLI (テキスト) | CLI (テキスト) / Binary (SCP) | XML (YANG モデル) | JSON / XML (YANG モデル) |
| **プロトコル規格** | Cisco IOS Proprietary | RFC 4253 / RFC 9635 | RFC 6241 | RFC 8040 |
| **主な用途** | 手動設定・初期構築 | 手動管理・ファイル転送 | 大規模自動化・オーケストレーション | Web/スクリプト連動・軽量自動化 |
| **認証方式** | Local / AAA (TACACS+/RADIUS) | Local / AAA / Public Key | AAA (Local / TACACS+/RADIUS) | AAA (Local / TACACS+/RADIUS) |
| **トランザクション制御** | なし（即時適用） | なし（即時適用） | サポート（Candidate / Commit） | なし（HTTP リクエスト単位で即時適用） |
| **前提条件** | 物理線 / IP 疎通 | RSA 2048bit 鍵, Domain Name | `netconf-yang`, SSH, AAA Exec 認可 | `restconf`, `ip http secure-server`, AAA Exec 認可 |
| **設計上の注意点** | `exec-timeout`, `logging sync` | Telnet 遮断 (`transport input ssh`) | candidate/running データストアの動作理解 | HTTP 認可設定と 401 エラーの回避 |

---

## 🏗 動作原理

### 1. CLI 管理アクセス処理フロー（Console / VTY / SSH）

```
[ Admin / User ]
       │
       ├─ (Console Serial / IP Network)
       ▼
┌────────────────────────────────────────────────────────┐
│ Cisco IOS XE Management Plane                          │
│                                                        │
│  1. Transport Access (Console / VTY Line)              │
│  2. Line Access Policy (transport input ssh / access-class) │
│  3. AAA Authentication (Local DB / TACACS+ / RADIUS)  │
│  4. AAA Authorization (Exec Privilege Level 15)        │
│  5. CLI Session Established (exec-timeout / logging sync)│
└────────────────────────────────────────────────────────┘
```

### 2. NETCONF / RESTCONF プログラマブル処理フロー

```
[ Automation Client / Python / Ansible / Postman ]
       │
       ├─ (TCP 830: XML over SSH) ────► [ NETCONF Subsystem (netconf-yang) ]
       │                                         │
       └─ (TCP 443: JSON/XML over HTTPS) ─► [ RESTCONF Process (restconf) ]
                                                 │
                                                 ▼
                             ┌───────────────────────────────────────┐
                             │ AAA Authorization (exec default)      │
                             └───────────────────────────────────────┘
                                                 │
                                                 ▼
                             ┌───────────────────────────────────────┐
                             │ YANG Data Engine (IETF / Native YANG) │
                             └───────────────────────────────────────┘
                                                 │
                                                 ▼
                             ┌───────────────────────────────────────┐
                             │ IOS XE Running Config / Operational DB│
                             └───────────────────────────────────────┘
```

---

## ⚙ 動作シーケンス

### 1. SSH / SCP 接続と認証シーケンス

1. **TCP 3-Way Handshake:** クライアントとルータ間で TCP 22 番ポート接続を確立。
2. **Version & Algorithm Negotiation:** SSH-2.0 サーバー識別子を交換し、暗号化アルゴリズム、MAC、鍵交換方式（Diffie-Hellman）を交渉。
3. **Key Exchange (KEX):** ホストキー（RSA 2048bit 等）を用いて暗号化キーを生成・交換。
4. **Authentication Phase:** ユーザー名・パスワード（または SSH 公開鍵）を提出し、`aaa authentication login` に基づき認証。
5. **Session / Service Request:** `shell` (通常の CLI) または `subsystem scp` (SCP ファイル転送) を要求。
6. **Authorization Check:** `aaa authorization exec` または `aaa authorization file` により権限レベル（Level 15）およびファイル転送権限を確認。

### 2. RESTCONF リクエスト処理シーケンス

1. **HTTPS TLS Handshake:** クライアントが TCP 443 で TLS 接続を確立（証明書検証）。
2. **HTTP Request:** HTTP ヘッダー（`Authorization: Basic <base64>`, `Accept: application/yang-data+json`, `Content-Type: application/yang-data+json`）とともに URI（例: `/restconf/data/ietf-interfaces:interfaces`）を送信。
3. **AAA Authentication & Authorization:**
   * HTTP 認証ポリシー（`ip http authentication local` 等）によりクレデンシャルを検証。
   * **重要:** `aaa authorization exec default local`（または TACACS+）により、ユーザーが Exec モード（Level 15）権限を付与されているか判定。権限不足の場合は **`401 Unauthorized`** または **`403 Forbidden`** を返却。
4. **YANG Data Mapping:** 要求された URI と Payload（JSON/XML）を IOS XE の内部 YANG データ構造にマッピング。
5. **Configuration / Operational Processing:** Datastore（Running-Config）への変更適用、または Operational データ（CDB）の取得。
6. **HTTP Response:** 結果ステータス（`200 OK`, `201 Created`, `204 No Content`, `400 Bad Request` 等）および Response Body を返却。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント

1. **VTY および Console のセキュリティ完全硬化:**
   * `exec-timeout 10 0` (10分無通信で切断、試験要件で指定される)。
   * `logging synchronous` (デバッグ出力や Syslog による入力途中のコマンド崩れ防止)。
   * `transport input ssh` (Telnet の無効化)。
   * `transport output none` (VTY からの不要なアウトバウンド Telnet 試行を禁止)。
2. **SSHv2 / SCP の正しく完全な有効化手順:**
   * `ip domain name <domain>` 設定なしでの SSH 鍵生成エラー回避。
   * `crypto key generate rsa modulus 2048` (RSA 2048bit 以上必須)。
   * `ip ssh version 2` の明示指定。
   * `ip scp server enable` と AAA 認可の依存関係の理解。
3. **RESTCONF / NETCONF-YANG のトラブルシューティングと完全初期化:**
   * `netconf-yang` の有効化。
   * `restconf` および `ip http secure-server` の有効化。
   * **最頻出ハマりポイント:** AAA 環境下で `aaa authorization exec default local` を設定し忘れると、RESTCONF/NETCONF リクエストがすべて **`401 Unauthorized`** になる。
4. **Out-of-Band (OOB) Management VRF でのサービスバインド:**
   * 管理専用 VRF（例: `Mgmt-vrf`）経由での SSH/NETCONF/RESTCONF アクセス制限およびソース IP 固定。

### よくある設定ミス

* **ミス 1:** `ip domain name` を設定せずに `crypto key generate rsa` を実行してエラーになる。
* **ミス 2:** `ip scp server enable` を設定したのに `aaa authorization exec default local` が未設定のため、SCP 転送時に `SCP server disabled` または `Permission denied` エラーが発生する。
* **ミス 3:** RESTCONF 設定時に `ip http secure-server` を忘れ、443 番ポートがオープンしない。
* **ミス 4:** VTY 配下で `transport input all` のまま放置し、要件の「Disable insecure management protocols (Telnet)」を落とす。

---


## 🛠 設定方法

### 1. Console & VTY 完全硬化コンフィグ

```bash
! --- グローバルドメインとローカルユーザー定義 ---
ip domain name ccie.lab
username admin privilege 15 secret C1sco123!

! --- Console ライン設定 ---
line console 0
 exec-timeout 10 0
 logging synchronous
 login local
 privilege level 15

! --- VTY ライン設定 (Telnet 完全遮断) ---
line vty 0 14
 exec-timeout 10 0
 logging synchronous
 login local
 privilege level 15
 transport input ssh
 transport output none
```

### 2. SSHv2 ＆ SCP サーバー構成

```bash
! --- SSHv2 有効化設定 ---
ip domain name ccie.lab
crypto key generate rsa modulus 2048
ip ssh version 2
ip ssh timeout 60
ip ssh authentication-retries 3

! --- SCP サーバー有効化 ＋ SCP 用 AAA 認可 ---
aaa new-model
aaa authentication login default local
aaa authorization exec default local
ip scp server enable
```

### 3. NETCONF-YANG ＆ RESTCONF 構成

```bash
! --- NETCONF-YANG 有効化 ---
netconf-yang

! --- RESTCONF ＆ HTTPS サーバー有効化 ---
ip http secure-server
ip http authentication local
restconf

! --- RESTCONF/NETCONF 用 AAA Exec 認可 (必須要件) ---
aaa new-model
aaa authentication login default local
aaa authorization exec default local
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **VTY / SSH 状態確認** | `show users` <br> `show ssh` <br> `show ip ssh` |
| **SCP サーバー有効化状態確認** | `show running-config | include scp` |
| **NETCONF プロセス状態確認** | `show netconf-yang status` <br> `show netconf-yang sessions` |
| **RESTCONF 状態・プロセス確認** | `show platform software yang-management process` |
| **HTTP / HTTPS サーバー状態確認** | `show ip http server status` |
| **AAA 認可コンフィグ確認** | `show running-config | section aaa` |
| **NETCONF デバッグ** | `debug netconf-yang all` |
| **RESTCONF デバッグ** | `debug restconf all` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **SSH 接続が拒否される** | RSA 鍵が未生成、または `transport input ssh` が抜けている | `show ip ssh` <br> `show run | sec line vty` | `crypto key generate rsa modulus 2048` を実行し、VTY 配下に `transport input ssh` を設定。 |
| **SCP コピー時に `Permission denied`** | `aaa authorization exec default local` が未設定 | `show run | sec aaa` | AAA 環境下では SCP 処理時に Exec 権限（Level 15）の検証が行われるため、AAA Exec 認可を設定する。 |
| **RESTCONF で `401 Unauthorized`** | HTTP 認証不備、または AAA Exec 認可の欠落 | `show ip http server status` <br> `show run | sec aaa` | `ip http authentication local` および `aaa authorization exec default local` を明示的に設定する。 |
| **NETCONF ポート 830 に接続できない** | `netconf-yang` が未有効、または Access-Class / CoPP でブロック | `show netconf-yang status` <br> `show control-plane host receive-actions` | `netconf-yang` をグローバルで有効化し、CoPP / ACL で TCP 830 を許可する。 |
| **VTY 入力中に Log でテキストが分断される** | `logging synchronous` が未設定 | `show run | sec line` | Line console 0 および Line vty に `logging synchronous` を適用する。 |

---

## ⚠ 制限事項

* **SSH キー長制限:** Cisco IOS XE では 512bit/768bit などの弱い鍵は非推奨・非サポート。最低 2048bit の RSA 鍵（または ECDSA 256/384bit）を使用する必要がある。
* **RESTCONF HTTP トランザクション:** RESTCONF はステートレスな HTTP 上で動くため、NETCONF のような Candidate Datastore の Lock や、複数ステートメントの一括 Commit/Rollback には対応していない。
* **RESTCONF フォーマット:** RESTCONF ヘッダーの `Content-Type` または `Accept` に `application/yang-data+json` または `application/yang-data+xml` を正しく指定しないと `415 Unsupported Media Type` エラーになる。

---

## 🔄 他技術との関連

* **CoPP (Control Plane Policing):**
  * SSH (TCP 22), SCP (TCP 22), NETCONF (TCP 830), RESTCONF (TCP 443) はすべて Control Plane (CPU) に送られる Punt トラフィックであるため、CoPP のポリシー（Host Subinterface）でこれらのポートがドロップされないよう明示的に許可する必要がある。
* **AAA (Authentication, Authorization, Accounting):**
  * デバイス管理アクセスの基盤。特に NETCONF / RESTCONF / SCP などのモデル駆動・自動化プロトコルは内部的に Exec Privilege Level 15 の AAA 認可に依存している。
* **MPP (Management Plane Protection):**
  * 特定の物理/論理インターフェイス（例: OOB 管理インターフェイス GigabitEthernet0/0）のみで SSH / HTTPS / NETCONF アクセスを許可するインバンド保護技術。

---

## 🧩 比較表

### NETCONF vs RESTCONF

| 比較項目 | NETCONF (RFC 6241) | RESTCONF (RFC 8040) |
| :--- | :--- | :--- |
| **プロトコル / ポート** | SSH (TCP 830) | HTTPS (TCP 443) |
| **データエンコーディング** | XML のみ | JSON および XML |
| **データストア概念** | Candidate, Running, Startup サポート | Running のみ直接操作（ステートレス） |
| **オペレーション** | `<get>`, `<get-config>`, `<edit-config>`, `<copy-config>`, `<delete-config>` | `GET`, `POST`, `PUT`, `PATCH`, `DELETE` |
| **トランザクション制御** | あり (`<lock>`, `<commit>`, `<rollback-on-error>`) | なし（リクエスト単位で即時反映） |
| **適した用途** | 精密な構成管理・トランザクション保証・大規模オーケストレーション | Web アプリケーション連動・Python スクリプト・軽量自動化 |

---

## 💡 ベストプラクティス

1. **VTY の完全保護:** 全ての VTY ライン（0 14 および 15 31 があれば全て）に対して `transport input ssh` および `transport output none` を設定し、Telnet アクセスおよび不要な外向き通信を完全遮断する。
2. **自動化プロトコル用 AAA 認可の徹底:** `aaa new-model` を有効化した環境では、必ず `aaa authorization exec default local`（または TACACS+）を設定し、SCP, NETCONF, RESTCONF の権限チェック失敗事故を防ぐ。
3. **管理専用 VRF の利用:** SSH, NETCONF, RESTCONF などの管理サービスは、可能な限り専用の Management VRF（`Mgmt-vrf` 等）にバインドし、データプレーンからのアクセスを物理的・論理的に分離する。
4. **Conditional Debug の活用:** NETCONF / RESTCONF のデバッグ実行時は、`debug netconf-yang all` や `debug restconf all` を漫然と流さず、システム負荷を監視しながら実施する。

---


## 📝 ラボ学習・設定サンプル例

### ラボ 1: Console ＆ VTY セキュリティ硬化コンフィグ

* **問題:** ルータ R1 の Console および VTY ライン（0-14）に対して、セキュリティポリシーに適合する硬化設定を適用せよ。
* **要件:**
  * ローカルユーザー `admin` (Privilege 15, Password: `C1sco123!`) を作成すること。
  * 無通信タイマーを 10 分 0 秒に設定すること。
  * コマンド入力中の Syslog 割込による表示崩れを防止すること (`logging synchronous`)。
  * VTY ラインでは SSH のみを許可し、Telnet およびアウトバウンド通信を遮断すること。
* **設定例:**
```bash
! --- ローカルユーザーの作成 ---
username admin privilege 15 secret C1sco123!

! --- Console ライン設定 ---
line console 0
 exec-timeout 10 0
 logging synchronous
 login local
 privilege level 15

! --- VTY ライン設定 ---
line vty 0 14
 exec-timeout 10 0
 logging synchronous
 login local
 privilege level 15
 transport input ssh
 transport output none
```
* **検証方法:**
  * R1 に対して Telnet 接続を試み、拒否されることを確認:
    ```bash
    R2# telnet 192.168.1.1
    % Connection refused by remote host
    ```
  * SSH 接続を実行し、ログインできることを確認:
    ```bash
    R2# ssh -l admin 192.168.1.1
    Password:
    R1# show users
        Line       User       Host(s)              Idle       Location
    * 0 con 0      admin      idle                 00:00:00
      2 vty 0      admin      idle                 00:00:12 192.168.1.2
    ```

---

### ラボ 2: SSHv2 2048bit 鍵生成 ＆ パラメータチューニング

* **問題:** ルータ R1 において SSHv2 を有効化し、接続パラメータを強化せよ。
* **要件:**
  * ドメイン名を `ccie.lab` とすること。
  * RSA 鍵長を 2048 bit とすること。
  * SSH バージョンを 2 に固定すること。
  * タイムアウトを 45 秒、再試行回数を 2 回に設定すること。
* **設定例:**
```bash
! --- ドメイン名と RSA 鍵の生成 ---
ip domain name ccie.lab
crypto key generate rsa modulus 2048

! --- SSH パラメータの設定 ---
ip ssh version 2
ip ssh timeout 45
ip ssh authentication-retries 2
```
* **検証方法:**
  * SSH の動作状態および設定値を確認:
    ```bash
    R1# show ip ssh
    SSH Enable - version 2.0
    Authentication timeout: 45 secs; Authentication retries: 2
    Minimum expected Diffie-Hellman key size : 1024 bits
    IOS Keys in SECSH format(rsa) fixed :-)
    ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC... ccie.lab
    ```

---

### ラボ 3: SCP (Secure Copy Protocol) サーバー有効化 ＋ AAA Exec 認可連動

* **問題:** R1 上で SCP サーバーを有効化し、リモート端末から安全にファイルを転送できるように設定せよ。
* **要件:**
  * AAA を有効化し、ローカルデータベースを使用した認証・認可を構成すること。
  * SCP 転送時に `Permission denied` が発生しないよう、AAA Exec 認可を適用すること。
  * SCP サーバー機能を有効化すること。
* **設定例:**
```bash
! --- AAA 認証・認可の基本構成 ---
aaa new-model
aaa authentication login default local
aaa authorization exec default local

! --- ローカル管理者ユーザー ---
username admin privilege 15 secret C1sco123!

! --- SCP サーバー機能の有効化 ---
ip scp server enable
```
* **検証方法:**
  * リモート PC または対向ルータ R2 から SCP で R1 の running-config を取得:
    ```bash
    R2# copy scp://admin:C1sco123!@192.168.1.1/running-config flash:R1-config.txt
    Loading running-config via SCP...
    [OK - 4096 bytes]
    ```
  * R1 側で SCP 転送ログと成功を確認:
    ```bash
    R1# show running-config | include scp
    ip scp server enable
    ```

---

### ラボ 4: OOB Management VRF (`Mgmt-vrf`) 経由の SSH アクセス制限

* **問題:** R1 の Out-of-Band 管理インターフェイス GigabitEthernet0/0 (VRF: `Mgmt-vrf`) 経由のみで SSH アクセスを許可せよ。
* **要件:**
  * インターフェイス Gi0/0 を VRF `Mgmt-vrf` にバインドすること。
  * VACL または Access-Class を使用して、管理ネットワーク `172.16.100.0/24` からの SSH アクセスのみを許可すること。
* **設定例:**
```bash
! --- VRF の定義とインターフェイス割り当て ---
vrf definition Mgmt-vrf
 address-family ipv4
 exit-address-family

interface GigabitEthernet0/0
 vrf forwarding Mgmt-vrf
 ip address 172.16.100.1 255.255.255.0
 no shutdown

! --- 管理アクセスコントロール ACL ---
ip access-list standard ACL_MGMT_SSH
 permit 172.16.100.0 0.0.0.255

! --- VTY ラインへの ACL 適用 ---
line vty 0 14
 access-class ACL_MGMT_SSH in
 transport input ssh
```
* **検証方法:**
  * 許可された IP (`172.16.100.50`) から SSH 接続し成功することを確認:
    ```bash
    AdminPC# ssh -l admin 172.16.100.1
    Password:
    R1#
    ```
  * 未許可の IP (`192.168.1.50`) から SSH 接続を試み、接続が拒否されることを確認:
    ```bash
    UserPC# ssh -l admin 172.16.100.1
    % Connection refused by remote host
    ```

---

### ラボ 5: NETCONF-YANG 有効化 ＋ TCP 830 セッション検証

* **問題:** R1 上で NETCONF-YANG サービスを有効化し、SSH トランスポート（TCP 830）経由で YANG モデル駆動管理を可能にせよ。
* **要件:**
  * `netconf-yang` を有効化すること。
  * AAA 環境下で NETCONF リクエストが正常に認可されるよう設定すること。
  * ポート 830 でのリスニングを確認すること。
* **設定例:**
```bash
! --- AAA 構成 ---
aaa new-model
aaa authentication login default local
aaa authorization exec default local
username admin privilege 15 secret C1sco123!

! --- SSHv2 構成 ---
ip domain name ccie.lab
crypto key generate rsa modulus 2048
ip ssh version 2

! --- NETCONF-YANG 有効化 ---
netconf-yang
```
* **検証方法:**
  * NETCONF-YANG のサービス状態を確認:
    ```bash
    R1# show netconf-yang status
    netconf-yang : enabled
    netconf-ssh  : enabled (port 830)
    ```
  * SSH クライアントから ポート 830 へ接続し、ルータからの `<hello>` メッセージを確認:
    ```bash
    Linux# ssh -p 830 admin@192.168.1.1 -s netconf
    Password:
    <?xml version="1.0" encoding="UTF-8"?>
    <hello xmlns="urn:ietf:params:xml:ns:netconf:base:1.0">
      <capabilities>
        <capability>urn:ietf:params:netconf:base:1.1</capability>
        ...
      </capabilities>
      <session-id>18</session-id>
    </hello>
    ```

---


### ラボ 6: RESTCONF 有効化 ＋ HTTPS (TCP 443) アクセス ＋ AAA 連動

* **問題:** R1 上で RESTCONF サービスを有効化し、HTTPS (TCP 443) 経由で RESTful API アクセスを受け付けるよう構成せよ。
* **要件:**
  * HTTP セキュアサーバー (`ip http secure-server`) を有効化すること。
  * ローカル認証 (`ip http authentication local`) を指定すること。
  * `restconf` を有効化すること。
  * AAA 環境下で 401 エラーを回避するため、`aaa authorization exec default local` を設定すること。
* **設定例:**
```bash
! --- AAA 構成 ---
aaa new-model
aaa authentication login default local
aaa authorization exec default local
username admin privilege 15 secret AdminSecret123!

! --- HTTPS サーバー ＆ RESTCONF 有効化 ---
ip http secure-server
ip http authentication local
restconf
```
* **検証方法:**
  * サービスおよびプロセスの稼働状態を確認:
    ```bash
    R1# show ip http server status | include HTTP secure server
    HTTP secure server capability: Enabled
    HTTP secure server port number: 443

    R1# show platform software yang-management process
    confd            : Running
    restconf         : Running
    ```


### ラボ 7: RESTCONF を使用した インターフェイス状態取得 (GET)

* **問題:** RESTCONF API を使用して、R1 のインターフェイス状態（`ietf-interfaces:interfaces-state`）を JSON フォーマットで取得せよ。
* **要件:**
  * HTTP GET メソッドを使用すること。
  * `Accept` ヘッダーに `application/yang-data+json` を指定すること。
* **設定例:**
```text
HTTP Method: GET
URI: /restconf/data/ietf-interfaces:interfaces-state
Header: Accept: application/yang-data+json
```
* **検証方法:**
  * ステータス `200 OK` および JSON データが返却されることを確認:
    ```text
    HTTP/1.1 200 OK
    Content-Type: application/yang-data+json
    
    {
      "ietf-interfaces:interfaces-state": {
        "interface": [
          {
            "name": "GigabitEthernet1",
            "admin-status": "up",
            "oper-status": "up"
          }
        ]
      }
    }
    ```

---

### ラボ 8: RESTCONF を使用した Loopback100 作成 ＆ IP 設定 (PUT)

* **問題:** RESTCONF API（PUT メソッド）を使用して、R1 上に インターフェイス Loopback100 を新規作成し、IP アドレス `10.100.100.1/32` を設定せよ。
* **要件:**
  * URI: `/restconf/data/ietf-interfaces:interfaces/interface=Loopback100`
  * `Content-Type`: `application/yang-data+json`
  * JSON ペイロードを用いて IP アドレスおよび Description を送信すること。
* **設定例 (JSON Payload):**
```json
{
  "ietf-interfaces:interface": {
    "name": "Loopback100",
    "description": "Configured via RESTCONF API",
    "enabled": true,
    "ietf-ip:ipv4": {
      "address": [
        {
          "ip": "10.100.100.1",
          "netmask": "255.255.255.255"
        }
      ]
    }
  }
}
```
* **検証方法:**
  * HTTP ステータスコード `201 Created` または `204 No Content` を確認。
  * R1 の CLI で Loopback100 が生成されていることを確認:
    ```bash
    R1# show ip interface brief | include Loopback100
    Loopback100            10.100.100.1    YES unset  up                        up
    ```


### ラボ 9: Console ポート専用 AAA Bypass リスト構成

* **問題:** 外部 AAA サーバ障害が発生した場合でも、物理 Console ポートからは常にローカルデータベースで即座にログインできるよう専用認証リスト（Console Bypass）を構成せよ。
* **要件:**
  * デフォルトの VTY 用認証リストは TACACS+ 優先とし、失敗時に Local へフォールバックすること。
  * Console ポート専用の認証リスト `CONSOLE_LOCAL` を作成し、Local 認証のみを強制すること。
* **設定例:**
```bash
! --- AAA 有効化 ＆ サーバグループ定義 ---
aaa new-model

tacacs server TACACS_SERVER
 address ipv4 172.16.1.100
 key SharedSecretKey123

aaa group server tacacs+ TAC_GROUP
 server name TACACS_SERVER

! --- 認証リストの定義 ---
aaa authentication login default group TAC_GROUP local
aaa authentication login CONSOLE_LOCAL local

! --- Console ラインへの適用 ---
line console 0
 login authentication CONSOLE_LOCAL
```
* **検証方法:**
  * TACACS+ サーバを故意に停止させた状態で、Console ポートからログインを試みる。
  * タイムアウトの遅延なしに即座にローカル認証プロンプトが表示され、ログイン成功することを確認。

---

### ラボ 10: デバイス管理アクセスプロトコル複合保護 (CoPP 制限)

* **問題:** Control Plane Policing (CoPP) を使用して、ルータ R1 への管理アクセス（SSH: TCP 22, NETCONF: TCP 830, RESTCONF: TCP 443）の帯域を制限し、不正な大量接続要求（DoS）から CPU を保護せよ。
* **要件:**
  * 管理アクセス用 ACL `ACL_MGMT_TRAFFIC` を定義し、SSH (22), NETCONF (830), HTTPS (443) を許可すること。
  * Policy-Map `POLICY_COPP` 内で管理トラフィックを 1Mbps (1,000,000 bps) にポリシングし、超過分をドロップすること。
  * `control-plane` にインバウンド適用すること。
* **設定例:**
```bash
! --- 1. 管理トラフィック識別用 ACL ---
ip access-list extended ACL_MGMT_TRAFFIC
 permit tcp any any eq 22
 permit tcp any any eq 830
 permit tcp any any eq 443

! --- 2. Class-Map の定義 ---
class-map match-any CM_MGMT_TRAFFIC
 match access-group name ACL_MGMT_TRAFFIC

! --- 3. Policy-Map の定義 (Policing: 1Mbps) ---
policy-map POLICY_COPP
 class CM_MGMT_TRAFFIC
  police 1000000 conform-action transmit exceed-action drop

! --- 4. Control Plane への適用 ---
control-plane
 service-policy input POLICY_COPP
```
* **検証方法:**
  * CoPP ポリシーの適用状態と統計情報を確認:
    ```bash
    R1# show policy-map control-plane input class CM_MGMT_TRAFFIC
     Hardware Counters:
      Class-map: CM_MGMT_TRAFFIC (match-any)
        1250 packets, 102400 bytes
        5 minute offered rate 2000 bps, drop rate 0000 bps
        Match: access-group name ACL_MGMT_TRAFFIC
        police:
            cir 1000000 bps, bc 31250 bytes
            conformed 1250 packets, 102400 bytes; actions: transmit
            exceeded 0 packets, 0 bytes; actions: drop
            conformed 2000 bps, exceeded 0000 bps
    ```


---

## ❓ 想定試験問題

### 問 1 (トラブルシューティング / RESTCONF)
**シナリオ:** RESTCONF を有効化し、`http-get` リクエストを送信したところ、ステータス `401 Unauthorized` が返却された。ルータのコンフィグを確認すると、以下のように設定されていた。
```bash
ip http secure-server
ip http authentication local
restconf
aaa new-model
aaa authentication login default local
```
**設問:** RESTCONF アクセスが `401 Unauthorized` となる直接的原因と、これを修復するための追加コンフィグを答えよ。

* **解答:**
  * **原因:** `aaa new-model` が有効化されている環境下で `aaa authorization exec default local` が設定されていないため。RESTCONF および NETCONF はリクエスト処理時に内部的に Exec 権限（Level 15）の認可をチェックするため、AAA Exec 認可が定義されていないと全リクエストが拒否される。
  * **修復コンフィグ:**
    ```bash
    aaa authorization exec default local
    ```

---

### 問 2 (コンフィグ読解 / SCP)
**シナリオ:** ネットワーク管理者が対向ルータから `copy scp://admin@10.1.1.1/vios-image.bin flash:` を実行したところ、`SCP server disabled` というエラーメッセージが表示された。10.1.1.1 側のコンフィグを確認すると以下の通りであった。
```bash
username admin privilege 15 secret AdminSecret123!
ip ssh version 2
aaa new-model
aaa authentication login default local
aaa authorization exec default local
```
**設問:** SCP ファイル転送を正常に動作させるために 10.1.1.1 側で設定すべき欠落コマンドを答えよ。

* **解答:**
  * **欠落コマンド:**
    ```bash
    ip scp server enable
    ```

---

### 問 3 (Design / NETCONF)
**シナリオ:** 設計者は、Python スクリプトを使用して 100 台の Catalyst スイッチのコンフィグを一括変更するオーケストレーションシステムを構築しようとしている。ネットワーク障害等による部分設定失敗を防ぐため、「全設定が正常に検証された場合のみコミットし、エラー発生時は自動的にロールバックする」トランザクション制御が必須要件として要求されている。
**設問:** RESTCONF と NETCONF のどちらのプロトコルを採用すべきか、理由とともに述べよ。

* **解答:**
  * **採用プロトコル:** **NETCONF**
  * **理由:** RESTCONF は HTTP 上のステートレスなプロトコルであり、Candidate Datastore や Lock, Rollback 機能を持たない。一方、NETCONF (RFC 6241) は Candidate Datastore、`<lock>`, `<commit>`, および `<rollback-on-error>` アクションを標準サポートしており、アトミックなトランザクション保証と自動ロールバックを実現できるため。

---

### 問 4 (トラブルシューティング / SSH)
**シナリオ:** 新規設定したルータ R1 に対して `ssh -l admin 192.168.1.1` を実行したところ、`Connection refused by remote host` で失敗した。R1 の `show running-config` を確認すると以下の設定が存在した。
```bash
username admin privilege 15 secret AdminSecret123!
ip domain name ccie.lab
ip ssh version 2
line vty 0 14
 login local
 transport input telnet
```
**設問:** SSH 接続が拒否される原因を 2 つ挙げ、修復コマンドを示せ。

* **解答:**
  * **原因 1:** RSA 暗号化キーペア（`crypto key generate rsa`）が生成されていない。
  * **原因 2:** VTY ライン配下で `transport input telnet` となっており、SSH トラフィックの受信が許可されていない。
  * **修復コンフィグ:**
    ```bash
    crypto key generate rsa modulus 2048
    line vty 0 14
     transport input ssh
    ```

---

### 問 5 (実装 / RESTCONF)
**シナリオ:** RESTCONF API を使用してインターフェイス情報を取得する際、レスポンスのデータフォーマットとして JSON を要求したい。
**設問:** cURL リクエストにおいて送信すべき適切な HTTP ヘッダー名を答えよ。

* **解答:**
  * **HTTP ヘッダー名:** `Accept: application/yang-data+json`

---

## 🔗 参考リソース

* Cisco Live: Model-Driven Programmability with NETCONF and RESTCONF (BRKPRG-2001)
* Cisco Configuration Guide: Cisco IOS XE 17.x Programmability Configuration Guide
* Cisco Technical Note: Configure and Troubleshoot NETCONF / RESTCONF
* RFC 6241 - Network Configuration Protocol (NETCONF)
* RFC 8040 - RESTCONF Protocol

---

## 📝 **補足（Notes）**

* **YANG データモデルの検索方法:** Cisco IOS XE がサポートする YANG モデル（Native および IETF）は、GitHub の公式リポジトリ (`YangModels/yang/vendor/cisco/xe`) で参照可能。
* **RESTCONF URI 構造:**
  * Root Resource: `/restconf`
  * Datastore Resource: `/restconf/data`
  * Operations Resource: `/restconf/operations`
* **デバッグ時の注意:** RESTCONF / NETCONF のトレース出力を大量に生成すると CPU 使用率が跳ね上がるため、ラボ試験での確認後は即座に `undebug all` を実行すること。




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


