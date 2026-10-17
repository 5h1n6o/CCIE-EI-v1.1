---
layout: default
title: 4.3-System-management
parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.3 System management

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.3 System management`（Device Management: Console/VTY, SSH, SCP, RESTCONF, NETCONF, SNMPv2c/v3, Logging: Syslog, Debugs, Conditional Debugs, Change Notification & Timestamps）の完全構造化学習メモ。

---

## 📘 概要

エンタープライズネットワークデバイスの統合管理（System Management）は、ルータ・スイッチの運用・保守・セキュリティ制御・構成監視を行う基盤技術群である。

* **Device Management (Console, VTY, SSH, SCP, NETCONF, RESTCONF):**
  * **Console / VTY & SSH/SCP:** インバンドおよびアウトオブバンド（OOB）経由での CLI アクセスおよびファイル暗号転送メカニズム。
  * **NETCONF / RESTCONF:** データモデル（YANG）に基づくプログラマブルなデバイス設定・状態取得プロトコル。SSH (TCP 830) または HTTPS (TCP 443) 上で XML / JSON 形式を用いてデータ操作を実行する。

* **SNMP (v2c, v3):**
  * **SNMPv2c:** コミュニティ文字列（PlainText）による簡便な MIB ポーリング・Trap 通知。
  * **SNMPv3:** ユーザーベースセキュリティモデル（USM: User-based Security Model）およびビューベースアクセス制御モデル（VACM: View-based Access Control Model）を採用し、認証（MD5/SHA）と暗号化（DES/AES）を標準サポートする高度管理プロトコル。

* **Logging (Local, Syslog, Debugs, Conditional Debugs, Change Notification, Timestamps):**
  * **Syslog / Local Logging:** システムイベントメッセージ（Severity 0〜7）のローカルバッファ保持および遠隔 Syslog サーバー（UDP 514）への転送。
  * **Conditional Debugs (`debug condition`):** 特定のインターフェイス、IP、プレフィックス、VRF、コンテキスト条件に合致するトラフィックのみをデバッグ追跡し、CPU 枯渇を回避する制御。
  * **Archive Change Notification (`archive` / `log config`):** CLI で実行されたコンフィグ変更履歴（誰が・いつ・どのコマンドを実行したか）をローカル保持・Syslog 通知する監査機能。
  * **Timestamps:** 監査トレールおよびトラブルシューティングのタイムラインを保証するミリ秒精度（`msec`）タイムスタンプ付与。

---

## 🔑 要点

| 機能 | 特徴 | 主な用途 | メリット | デメリット/制限事項 | 設計上の注意点 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Console / VTY** | 直流物理/仮想ターミナル制御 | CLI 直接/ネットワーク経由アクセス | 迅速な構成と状態確認 | Telnet/非暗号化 VTY は盗聴リスク | Console 用 AAA Bypass と VTY の SSH 限定化 |
| **SSHv2 / SCP** | RSA/ECDSA 暗号化 CLI & ファイル転送 | セキュア管理アクセス・IOS イメージ転送 | 平文盗聴・中間者攻撃防止 | SSH 鍵生成とドメイン名指定が必須 | 2048bit 以上の RSA 鍵生成と `ip ssh version 2` 強制 |
| **NETCONF** | YANG モデルベース (XML over SSH: TCP 830) | トランザクション型自動設定・状態取得 | RFC 準拠の標準化、Datastore 概念 | XML 構造の理解とモデル知識が必要 | Candidate Datastore / Lock 機能と CoPP 許可 |
| **RESTCONF** | YANG モデルベース (JSON/XML over HTTPS: TCP 443) | Web アプリ・自動化ツール連携 | HTTP メソッド（GET/POST/PUT/DELETE）活用 | 永続セッション管理非対応（Stateless） | AAA/Local 認可ポリシーと HTTPS 証明書管理 |
| **SNMPv2c** | Plaintext Community 方式 | 伝統的 NMS による MIB ポーリング・Trap | 圧倒的な互換性と軽快性 | 暗号化・ユーザー認証欠如（平文） | 読み取り専用（RO）への限定と ACL バインド |
| **SNMPv3** | USM / VACM セキュリティモデル | セキュアな環境での監視・Traps/Informs | 認証（SHA/MD5）＋暗号化（AES） | 設定の複雑化と OID ビュー管理 | AuthPriv モードの強制と Inform 応答設定 |
| **Syslog** | UDP 514 メッセージ転送 | 障害検知・セキュリティログ集中集約 | 標準化、ミリ秒精度タイムスタンプ | UDP のため不達リスク（TCP/TLS 拡張必要） | `logging source-interface` と VRF 指定 |
| **Conditional Debug** | 条件指定型デバッグ (`debug condition`) | 高負荷環境でのピンポイント追跡 | CPU 枯渇・コンソールフリーズ防止 | 条件解除忘れによるログ蓄積 | 事前の `debug condition` 設定と終了後 `undebug all` |
| **Archive Change Log** | コンフィグ変更ログ (`archive` / `log config`) | コマンドレベルの変更監査 | 変更履歴の可視化、パスワード隠蔽 | ログサイズ制限（最大 1000 エントリ） | `hidekeys` によるパスワード平文記録防止 |

---

## 🏗 動作原理

### 1. NETCONF / RESTCONF ネットワーク管理構造

```
[ NMS / Automation Controller (Ansible / Python / REST Client) ]
       │
       ├──── NETCONF (XML over SSH: TCP 830) ────────► [ Candidate / Running Datastore ]
       │
       └──── RESTCONF (JSON/XML over HTTPS: TCP 443) ──► [ Cisco IOS XE Datastore (YANG) ]
```

* **NETCONF 動作:** SSH セッション確立後、Capabilities 交渉（`hello`）を実施。`<get-config>`, `<edit-config>`, `<commit>` などの RPC リクエストを送信し、トランザクション処理を実行。
* **RESTCONF 動作:** RESTful API に基づき、`GET`（取得）、`POST`（作成）、`PUT`（置換/更新）、`PATCH`（部分更新）、`DELETE`（削除）のリクエストを `/restconf/data/...` URI パスに対して発行。

---

### 2. SNMPv3 USM (User-based Security Model) 処理構造

```
SNMP Manager
   │
   ├── (1) EngineID Discovery ────────────────────────► SNMP Agent (IOS XE)
   │   ◄── (2) Report (EngineID: 80000009...) ────────┤
   │                                                  │
   ├── (3) AuthPriv Encrypted Request (SHA + AES) ───►│ ──► [ VACM View Check ]
   │   ◄── (4) AuthPriv Encrypted Response ───────────┤        │ (MIB Tree Access)
```

1. **EngineID 検出:** SNMPv3 マネージャーは、エージェント（ルータ）の固有 EngineID を取得するために初期化メッセージを送受信。
2. **USM 認証 ＆ 暗号化:** 指定されたユーザーの認証鍵（SHA/MD5）および暗号化鍵（AES/3DES）を用いてメッセージヘッダーと PDU を保護。
3. **VACM ビュー検証:** 定義された MIB View（例: `mib-2` や特定 OID ブランチ）に対する読み取り（`read`）/ 書き込み（`write`）権限をチェック。

---

### 3. Archive Configuration Change Logging 処理フロー

```
[ Administrator / Automation Tool ]
   │
   ├── (1) Enters 'configure terminal' & executes CLI commands
   │
   ▼
[ CLI Parser ] ──► (2) Executes Command & Applies to Running-Config
   │
   ▼
[ Archive Logging Subsystem ]
   ├── (3) Strips Sensitive Keys (if 'hidekeys' enabled)
   ├── (4) Stores Entry in Local Circular Buffer
   └── (5) Generates Syslog Message (%PARSER-5-CFG_LOG_LOGGED_CMD) to Logging Server
```

---

## ⚙ 動作シーケンス

### NETCONF `<edit-config>` から `<commit>` へのトランザクションシーケンス

1. **SSH Connection & Authentication:** クライアントが TCP 830 ポート経由でルータへ SSH 接続し、AAA / Local 認証を実施。
2. **Capability Exchange:** `<hello>` フレームを送受信し、サポートする YANG モジュールおよび機能（`:candidate`, `:confirmed-commit` 等）を相互通知。
3. **Lock Datastore (任意):** 他の管理セッションからの競合変更を防ぐため `<lock>` リクエストを発行。
4. **Edit Config:** `<edit-config>` でターゲットデータストア（`<candidate/>`）に対して XML 設定変更を送信。
5. **Validation & Commit:** `<validate>` で構文チェック後、`<commit>` で Candidate Datastore から Running Datastore へ一括反映。
6. **Unlock & Close:** `<unlock>` を実行し、`<close-session>` でセッションを正常終了。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント
1. **SSHv2 ＆ SCP の厳格な設定:** `ip domain name`, `crypto key generate rsa modulus 2048`, `ip ssh version 2`, `ip scp server enable` の完全バインド。
2. **RESTCONF / NETCONF の有効化 ＆ 認証:** `netconf-yang`, `restconf` のグローバル有効化と AAA / VTY 認証依存関係の整合。
3. **SNMPv3 USM/VACM 構築:** グループ定義 (`snmp-server group`), MIB ビュー制限 (`snmp-server view`), ユーザー定義 (`snmp-server user`), ホスト指定 (`snmp-server host ... informs/traps version 3 auth`)。
4. **Syslog / Logging 調整:** `logging buffered`, `logging host`, `logging source-interface`, `service timestamps log datetime msec` のミリ秒付与要件。
5. **Conditional Debug (`debug condition`):** インターフェイス単位や IP 単位で条件を設定し、`debug ip packet` や `debug ip ospf events` の過剰出力を防止。
6. **Archive Logging (`archive` / `log config`):** `logging enable`, `logging size`, `hidekeys`, `notify syslog` の標準バインド。

### よくある設定ミス・ハマりポイント
* **NETCONF/RESTCONF のローカル認証エラー:** `aaa new-model` 環境下で `aaa authentication login default local` や `aaa authorization exec default local` が欠落し、RESTCONF REST API 呼び出しが 401 Unauthorized となる。
* **SNMPv3 User 設定の Running-Config 非表示:** `snmp-server user` コマンドで設定したユーザーパスワードは NVRAM 暗号化処理されるため、`show running-config` にパスワード文字列が残らない仕様を誤設定と判断してしまう（確認は `show snmp user` を使用）。
* **Conditional Debug の条件残留:** トラブルシューティング終了後に `no debug condition all` または `undebug all` を実行し忘れ、バックグラウンドで不要な CPU 負荷が発生する。
* **Archive Change Log での `hidekeys` 欠落:** `hidekeys` を指定しないと `enable secret` や `username password` などの機密情報が平文で Syslog サーバーへ送信される。

---


## 🛠 設定方法

### 1. SSHv2 ＆ SCP 完全構築
```bash
! ドメイン名と RSA 鍵の定義
ip domain name ccie.lab
crypto key generate rsa modulus 2048

! SSHv2 強制とタイムアウト設定
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3

! SCP サーバーの有効化
ip scp server enable

! VTY ラインでの SSH 専用制限
line vty 0 15
 exec-timeout 15 0
 transport input ssh
 login local
```

---

### 2. RESTCONF ＆ NETCONF-YANG 有有効化
```bash
! AAA 認証・認可の前提バインド
aaa new-model
aaa authentication login default local
aaa authorization exec default local

! NETCONF-YANG 有効化 (TCP 830)
netconf-yang

! RESTCONF 有効化 (HTTPS: TCP 443)
restconf

! HTTPS サーバー制御
ip http server
ip http secure-server
ip http authentication local
```

---

### 3. SNMPv3 最高高度 AuthPriv (SHA ＋ AES256) 構成
```bash
! MIB ビューの定義 (mib-2 全体を許可)
snmp-server view V1_VIEW mib-2 include

! グループの定義 (AuthPriv モード指定)
snmp-server group G1_ADMIN v3 auth read V1_VIEW write V1_VIEW

! ユーザーの定義 (認証: SHA, 暗号化: AES 256)
snmp-server user U1_ADMIN G1_ADMIN v3 auth sha AuthPass123! priv aes 256 PrivPass123!

! Trap / Inform 通知ターゲット指定
snmp-server host 10.100.1.50 informs version 3 priv U1_ADMIN
snmp-server enable traps config
snmp-server enable traps syslog
```

---

### 4. Syslog / Logging ＆ Timestamps 精密構成
```bash
! ミリ秒精度タイムスタンプの指定
service timestamps log datetime msec show-timezone
service timestamps debug datetime msec show-timezone

! バッファログ・Syslog サーバー指定
logging buffered 64535 debugging
logging host 10.100.1.100 vrf Mgmt-vrf
logging source-interface Loopback0
logging trap notifications
```

---

### 5. Conditional Debug (条件付きデバッグ) 構成
```bash
! 特定のインターフェイスおよび対向 IP のみを条件バインド
debug condition interface GigabitEthernet0/0/1
debug condition ip 10.1.1.2

! 対象プロトコルのデバッグ起動
debug ip ospf adj
```

---

### 6. Archive Configuration Change Logging 構成
```bash
! コンフィグ変更ログの構成
archive
 log config
  logging enable
  logging size 500
  hidekeys
  notify syslog
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 備考 |
| :--- | :--- | :--- |
| **SSH/SCP 状態確認** | `<code>show ip ssh</code>` | SSH バージョン、認証試行数、状態確認 |
| **SSH 接続セッション** | `<code>show ssh</code>` | 接続中のクライアント IP・暗号化方式確認 |
| **NETCONF 状態** | `<code>show netconf-yang sessions</code>` | アクティブな NETCONF 接続確認 |
| **RESTCONF 状態** | `<code>show platform software interface restconf status</code>` | RESTCONF プロセス状態 |
| **SNMP ユーザー確認** | `<code>show snmp user</code>` | SNMPv3 ユーザー・EngineID・アルゴリズム |
| **SNMP グループ確認** | `<code>show snmp group</code>` | グループセキュリティモデル・ビューバインド |
| **Logging 状態** | `<code>show logging</code>` | バッファメッセージ、Syslog カウンタ |
| **Conditional Debug** | `<code>show debug condition</code>` | アクティブなデバッグ条件（Filter）確認 |
| **変更ログ確認** | `<code>show archive log config all</code>` | 実行された CLI コマンド履歴一覧 |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **RESTCONF 通信が 401 Unauthorized** | AAA / VTY のローカル Exec 認可設定欠落 | `<code>show running-config \| inc aaa</code>` | `aaa authorization exec default local` を追加 |
| **NETCONF ポート 830 に接続不可** | `netconf-yang` 未有効化、または CoPP でブロック | `<code>show netconf-yang status</code>` | `netconf-yang` 有効化および CoPP ACL 修正 |
| **SNMPv3 で NMS からタイムアウト** | EngineID 不一致、または AuthPriv 鍵ミスマッチ | `<code>show snmp user</code>` | NMS 側で EngineID を再自動検出させる |
| **Syslog メッセージの時間が不正確** | `service timestamps` 未指定または NTP 未同期 | `<code>show clock</code>`, `<code>show ntp status</code>` | NTP 同期と `service timestamps log datetime msec` 適用 |
| **Debug 実行で CPU が 100% 固着** | 無条件デバッグ (`debug ip packet` 等) の直接実行 | `<code>show processes cpu sorted</code>` | `debug condition` の事前適用と `undebug all` |
| **Archive Log にパスワードが平文記録** | `hidekeys` オプションの指定漏れ | `<code>show running-config \| section archive</code>` | `archive` -> `log config` 配下で `hidekeys` を追加 |

---

## ⚠ 制限事項

* **SCP ファイル転送:** `ip scp server enable` を有効化する際、`aaa authorization exec default local` 等の Exec 認可が正常に動作していないと、認証成功後もパーミッションエラー（Permission Denied）で転送が失敗する。
* **NETCONF / RESTCONF:** Cisco IOS XE では、YANG モデルに基づく同時編集セッションが競合した場合、Datastore Lock を取得したセッションが優先され、他方は 409 Conflict / In-Use エラーを返す。
* **SNMPv3 暗号化アルゴリズム:** 一部旧世代の IOS イメージでは AES-256 がサポートされず AES-128 または 3DES に限定される場合がある（IOS XE 16.x/17.x では AES-256 サポート）。

---

## 🔄 他技術との関連

* **AAA (Authentication, Authorization, Accounting):** SSH, RESTCONF, NETCONF, CLI Archive の全アクセスに対する認証・認可基盤。
* **CoPP (Control Plane Policing):** SSH (TCP 22), NETCONF (TCP 830), HTTPS (TCP 443), SNMP (UDP 161/162), Syslog (UDP 514) を Control Plane で適切にレート制限・保護。
* **VRF-Aware Services:** Out-of-Band 管理網（Management VRF）経由で Syslog, SNMP, NTP を送信する際の `vrf Mgmt-vrf` バインド設定。
* **NTP (Network Time Protocol):** Syslog タイムスタンプおよび SNMPv3 アタッチメントの時刻整合性を保持する時間同期前提技術。

---

## 🧩 比較表

| 項目 | SNMPv2c | SNMPv3 | NETCONF | RESTCONF |
| :--- | :--- | :--- | :--- | :--- |
| **トランスポート** | UDP 161 / 162 | UDP 161 / 162 | SSH (TCP 830) | HTTPS (TCP 443) |
| **データ構造** | MIB / OID | MIB / OID | YANG (XML) | YANG (JSON / XML) |
| **セキュリティ** | Plaintext Community | USM (SHA/AES) | SSH / AAA | TLS / HTTPS / AAA |
| **トランザクション** | なし (Set 単位) | なし (Set 単位) | あり (Candidate/Commit) | HTTP メソッド単位 |
| **データストア** | Running 直接 | Running 直接 | Running, Candidate, Startup | Running, Operational |

---

## 💡 ベストプラクティス

1. **セキュアアクセスの徹底:** Telnet / Plaintext SNMP を全廃し、SSHv2 (RSA 2048bit+), SNMPv3 (AuthPriv: SHA+AES256), RESTCONF/NETCONF に一本化する。
2. **監査ログの平文難読化:** `archive` -> `log config` で必ず `hidekeys` を有効化し、パスワードや PSK が Syslog やローカルバッファに露出する事故を防ぐ。
3. **安全なデバッグ運用:** トラブルシューティング時は必ず `debug condition` でインターフェイス・IP を絞り込み、検証終了後は即座に `undebug all` を実行する。
4. **管理用 VRF の明示指定:** Syslog, SNMP, NETCONF/RESTCONF のアウトオブバンド運用時は `logging host ... vrf Mgmt-vrf` のように明示バインドする。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: SSHv2 ＆ SCP アクセス制御・RSA 2048bit 鍵生成構成

* **問題:** ルータ R1 において、プレーンテキストの Telnet 通信を全面的に禁止し、RSA 2048bit 鍵を用いた SSHv2 限定アクセスおよび安全な SCP ファイル転送を構築せよ。
* **要件:**
  * ドメイン名を `ccie.lab` とすること。
  * SSH バージョンを v2 に限定し、タイムアウトを 60 秒、再試行回数を 3 回に指定すること。
  * VTY ラインでのトランスポートを SSH のみに制限すること。
  * SCP サーバーを有効化し、ローカル管理者ユーザー `admin` (Privilege 15) でファイル転送を許可すること。

* **設定例:**
```bash
! 1. ローカル特権ユーザーおよびドメイン名・RSA 鍵の定義
username admin privilege 15 secret DOMAIN_KEY_PASS
ip domain name ccie.lab
crypto key generate rsa modulus 2048

! 2. SSHv2 パラメータの設定
ip ssh version 2
ip ssh time-out 60
ip ssh authentication-retries 3

! 3. SCP サーバー機能の有効化
ip scp server enable

! 4. VTY ラインアクセス制限
line vty 0 15
 exec-timeout 15 0
 transport input ssh
 login local
```

* **検証方法:**
  * クライアント PC から `ssh -v 2 admin@10.1.1.1` でログインし成功することを確認。
  * クライアントから `scp test.txt admin@10.1.1.1:flash:/test.txt` で転送が成功することを確認。
  * `show ip ssh` および `show ssh` で SSHv2 セッションを確認。

---

### ラボ 2: RESTCONF ＆ NETCONF-YANG 有効化 ＋ AAA Exec 認可連動

* **問題:** Cisco IOS XE ルータ R1 において、自動化ツール連携のため NETCONF (TCP 830) および RESTCONF (HTTPS 443) を有効化せよ。
* **要件:**
  * AAA を有効化し、ローカル Exec 認可を正しくバインドして 401 Unauthorized エラーを防止すること。
  * HTTPS サーバーを有効化し、認証方式にローカルを指定すること。
  * NETCONF-YANG および RESTCONF サービスを起動すること。

* **設定例:**
```bash
! 1. AAA およびローカル認可の定義
aaa new-model
aaa authentication login default local
aaa authorization exec default local
username admin privilege 15 secret DOMAIN_KEY_PASS

! 2. HTTP / HTTPS サーバーの有効化
ip http server
ip http secure-server
ip http authentication local

! 3. NETCONF / RESTCONF プロトコルの起動
netconf-yang
restconf
```

* **検証方法:**
  * `show netconf-yang status` で NETCONF-YANG が Enabled であることを確認。
  * RESTCONF エンドポイントへ GET リクエストを送信し、ホスト名 JSON が応答することを確認。

---

### ラボ 3: SNMPv3 AuthPriv (SHA ＋ AES256) ＆ MIB View 制限構築

* **問題:** ルータ R1 において、最上位セキュリティモデル AuthPriv (SHA 認証 ＋ AES256 暗号化) による SNMPv3 監視を構成せよ。
* **要件:**
  * MIB ビュー `READ_VIEW` を作成し、`mib-2` 以下の全オブジェクトへのアクセスを許可すること。
  * グループ `ADMIN_GROUP` を作成し、`READ_VIEW` をバインドすること。
  * ユーザー `snmpadmin` を定義し、認証および暗号化アルゴリズムをバインドすること。

* **設定例:**
```bash
! 1. MIB View の定義
snmp-server view READ_VIEW mib-2 include

! 2. SNMPv3 Group の定義 (AuthPriv モード指定)
snmp-server group ADMIN_GROUP v3 auth read READ_VIEW write READ_VIEW

! 3. SNMPv3 User の定義
snmp-server user snmpadmin ADMIN_GROUP v3 auth sha AUTH_PASS_KEY priv aes 256 PRIV_PASS_KEY
```

* **検証方法:**
  * NMS サーバーから `snmpwalk -v3 -u snmpadmin -l authPriv ...` を実行し、MIB ツリーが取得できることを確認。
  * `show snmp user` および `show snmp group` でユーザーと権限を確認。

---

### ラボ 4: Syslog ミリ秒タイムスタンプ ＆ ソース I/F ・ VRF 指定構成

* **問題:** ネットワーク管理網（`Mgmt-vrf`）上に存在する Syslog サーバー（10.100.1.100）へシステムログを転送せよ。
* **要件:**
  * タイムスタンプにミリ秒（msec）およびタイムゾーンを表示させること。
  * ログ送信のソースインターフェイスを `Loopback0` に固定すること。
  * 転送先 Syslog サーバーを `Mgmt-vrf` 経由に指定し、Severity Notifications (Level 5) 以上を送信すること。

* **設定例:**
```bash
! 1. ミリ秒精度タイムスタンプの有効化
service timestamps log datetime msec show-timezone
service timestamps debug datetime msec show-timezone

! 2. ソースインターフェイスおよび Syslog サーバーのバインド
logging source-interface Loopback0
logging host 10.100.1.100 vrf Mgmt-vrf
logging trap notifications
logging buffered 65535 debugging
```

* **検証方法:**
  * `show logging` を実行し、`Logging to 10.100.1.100 (vrf Mgmt-vrf)` およびバッファログのタイムスタンプが `*Oct 17 10:15:30.123 JST` 形式であることを確認。

---

### ラボ 5: Conditional Debug (`debug condition ip`) によるピンポイント追跡

* **問題:** 高トラフィック環境のルータ R1 において、特定のアドレステスト対象（192.168.10.50）宛てのパケットのみを CPU デバッグ追跡せよ。
* **要件:**
  * 全トラフィックに対する無条件デバッグを実行して CPU を高負荷にさせないこと。
  * Conditional Debug 機能（`debug condition`）を用いてターゲット IP を絞り込むこと。

* **設定例:**
```bash
! 1. 条件付きデバッグフィルタの設定
debug condition ip 192.168.10.50

! 2. 目的のプロトコルデバッグを起動
debug ip packet
```

* **検証方法:**
  * `show debug condition` を実行し、`Condition 1: IP 192.168.10.50` を確認。
  * 192.168.10.50 宛ての通信のみがコンソール/バッファに出力され、他の通信ログが出力されないことを確認。
  * 検証終了後に `no debug condition 1` および `undebug all` を実行。

---

### ラボ 6: Archive Configuration Change Logging ＋ パスワード難読化構成

* **問題:** ルータ R1 で特権ユーザーが実行した全 CLI コンフィグ変更操作を監視・記録する Archive Logging を有効化せよ。
* **要件:**
  * ローカルサーキュラーバッファサイズを 500 件に設定すること。
  * コマンド内で入力されたパスワード（暗号化文字列・PSK 等）がログ内に平文記録されないよう難読化すること。
  * 変更イベントを Syslog として自動通知すること。

* **設定例:**
```bash
! 1. Archive Change Logging の構成
archive
 log config
  logging enable
  logging size 500
  hidekeys
  notify syslog
```

* **検証方法:**
  * グローバルコンフィグモードで `username testuser secret TEMP_PASS` を実行。
  * `show archive log config all` を実行し、コマンド内のパスワードが `<password>` や `#####` に自動変換されて記録されていることを確認。

---

### ラボ 7: Console ポート専用 AAA Bypass (`aaa authentication login CONSOLE local`)

* **問題:** AAA TACACS+ 集中認証環境において、外部 TACACS+ サーバダウン時でも Console ポートから直ちに復旧操作を行えるよう Console 専用のローカル認証 Bypass を構成せよ。
* **要件:**
  * Console ポート専用の AAA Authentication List `CONSOLE_LIST` を作成し、`local` 認証を指定すること。
  * Line console 0 に `CONSOLE_LIST` を割り当てること。

* **設定例:**
```bash
! 1. ローカル管理者ユーザーの作成
username admin privilege 15 secret DOMAIN_KEY_PASS

! 2. Console 専用 AAA Authentication List の作成
aaa new-model
aaa authentication login CONSOLE_LIST local

! 3. Line Console 0 への割り当て
line console 0
 login authentication CONSOLE_LIST
```

* **検証方法:**
  * Console 接続端末から Enter キーを押し、AAA サーバーへの問い合わせなしに即座にローカル DB 認証が呼び出されることを確認。

---

### ラボ 8: SNMP Traps / Informs の特定イベント（Config & Syslog）送信構成

* **問題:** ルータ R1 において、コンフィグ変更および Syslog 発生イベントを確実な通知方式である SNMP Inform (v2c) として NMS (10.1.1.50) へ送信せよ。
* **要件:**
  * コミュニティ名を `CiscoPro` とすること。
  * 通常の Trap (ACK なし) ではなく、肯定応答を要求する Inform (ACK あり) を使用すること。
  * Config 変更トラップおよび Syslog トラップを有効化すること。

* **設定例:**
```bash
! 1. トラップ発生源の有効化
snmp-server enable traps config
snmp-server enable traps syslog

! 2. Inform ターゲットおよびコミュニティの指定
snmp-server host 10.1.1.50 informs version 2c CiscoPro config syslog
snmp-server community CiscoPro RO
```

* **検証方法:**
  * R1 でコンフィグを変更し、`show snmp host` で `type: inform` としてカウントが送信されていることを確認。

---

### ラボ 9: RESTCONF を使用した API インターフェイス状態取得構成

* **問題:** 外部管理端末から RESTCONF API 経由でルータ R1 (10.1.1.1) のインターフェイス状態を取得せよ。
* **要件:**
  * RESTCONF エンドポイント `/restconf/data/ietf-interfaces:interfaces-state` を使用すること。
  * HTTP Header `Accept: application/yang-data+json` を指定すること。

* **設定例 (ルータ設定 & API リクエスト例):**
```bash
! 1. ルータ側の RESTCONF 前提コンフィグ
aaa new-model
aaa authentication login default local
aaa authorization exec default local
username admin privilege 15 secret DOMAIN_KEY_PASS

restconf
ip http secure-server
ip http authentication local
```

```text
! 2. RESTCONF API リクエスト例 (HTTP GET)
GET /restconf/data/ietf-interfaces:interfaces-state HTTP/1.1
Host: 10.1.1.1
Accept: application/yang-data+json
Authorization: Basic YWRtaW46Q2lzY29QYXNzMTIz
```

* **検証方法:**
  * REST API クライアントから GET リクエストを送信し、`ietf-interfaces:interfaces-state` の JSON データ構造（GigabitEthernet1 の `oper-status: up` 等）が出力されることを確認。

---

### ラボ 10: Conditional Debug (`debug condition interface`) ＋ OSPF Adjacency 追跡

* **問題:** ルータ R1 において、GigabitEthernet0/0/2 インターフェイス上でのみ発生している OSPF ネイバー問題のログを追跡せよ。
* **要件:**
  * Gi0/0/1 や Gi0/0/3 で動作している他の OSPF ネイバーのログを排出しさせないこと。
  * `debug condition interface` を使用して対象ポートに限定すること。

* **設定例:**
```bash
! 1. 対象インターフェイス限定条件バインド
debug condition interface GigabitEthernet0/0/2

! 2. OSPF イベントデバッグの起動
debug ip ospf adj
```

* **検証方法:**
  * `show debug condition` で Gi0/0/2 がフラグメント条件としてバインドされていることを確認。
  * Gi0/0/2 上の OSPF 隣接確立/切断イベントのみがログ出力されることを確認。
  * 検証終了後に `clear debug-condition all` および `undebug all` を実行。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**シナリオ:** 管理者がルータ R1 で RESTCONF を有効化し、`restconf` および `ip http secure-server` を設定した。しかし、外部からの REST API リクエスト（HTTP GET）が常に `401 Unauthorized` で失敗する。
**設問:** この障害の直接的原因と、R1 で追加設定すべき CLI コマンドを答えよ。

* **解答:**
  * **原因:** AAA が有効化されている環境下において、HTTP/RESTCONF アクセスに対する Exec 認可設定（`aaa authorization exec default local` 等）または HTTP 認証方式（`ip http authentication local`）が不足しており、認証・認可シーケンスが拒否されているため。
  * **修正コマンド:**
```bash
aaa authorization exec default local
ip http authentication local
```

---

### 問 2 (Design)
**シナリオ:** エンタープライズ網において、1,000 台のルータから構成変更履歴を監視サーバーへ送信するリアルタイム監査システムを設計している。ネットワーク帯域の負荷を抑えつつ、誰がどのコマンドを実行したかを平文パスワードの漏洩なしに収集したい。
**設問:** 推奨される Cisco IOS XE 機能と具体的な構成コマンドを述べよ。

* **解答:**
  * **推奨機能:** `archive` サブシステムによる Configuration Change Logging (`log config`) 機能。
  * **構成コマンド:**
```bash
archive
 log config
  logging enable
  logging size 500
  hidekeys
  notify syslog
```

---

### 問 3 (トラブルシューティング)
**シナリオ:** OSPF 高速コンバージョンのトラブルシューティングのため、技術者がルータで `debug ip packet` および `debug ip ospf events` を実行したところ、ルータの CPU 使用率が 100% に急増し、VTY セッションが応答停止した。
**設問:** この状況を事前に防ぐために使用すべきデバッグ制御機能と、その設定コマンドを答えよ。

* **解答:**
  * **機能:** Conditional Debugging (`debug condition`)。
  * **構成コマンド (例: Gi0/0/1 インターフェイスおよび特定対向 IP 限定):**
```bash
debug condition interface GigabitEthernet0/0/1
debug condition ip 10.1.1.2
debug ip ospf events
```

---

### 問 4 (実装)
**シナリオ:** ルータ R1 において、SNMPv3 AuthPriv モードを用いて MIB-2 情報を NMS (10.1.1.100) へ Inform 通知するよう設定したい。
**設問:** 必要となる MIB View、Group、User、および Inform Host 設定を完全な CLI で記述せよ。

* **解答:**
```bash
snmp-server view V1_VIEW mib-2 include
snmp-server group G1_GROUP v3 auth read V1_VIEW write V1_VIEW
snmp-server user U1_USER G1_GROUP v3 auth sha AUTH_STRING priv aes 256 PRIV_STRING
snmp-server host 10.1.1.100 informs version 3 priv U1_USER
```

---

### 問 5 (コンフィグ読解)
**シナリオ:** 以下のコンフィグが設定されたルータの動作に関する記述として正しいものを選べ。
```bash
ip domain name ccie.lab
crypto key generate rsa modulus 2048
ip ssh version 2
ip scp server enable
line vty 0 4
 transport input ssh
```
* A. Telnet 経由で VTY 0-4 に接続可能である。
* B. SCP によるファイル転送が可能だが、VTY セッションは SSHv1 も許可される。
* C. VTY 5-15 には Telnet で接続可能である。
* D. SCP によるファイル転送が可能であり、VTY 0-4 は SSHv2 のみが許可される。

* **解答: D**
  * **解説:** `ip ssh version 2` によりグローバルで SSHv2 が強制されており、Line vty 0 4 で `transport input ssh` が設定されているため SSHv2 のみが許可される。また `ip scp server enable` により SCP ファイル転送が有効化されている。

---

## 🔗 参考リソース

* Cisco IOS XE 17.x System Management Configuration Guide
* Cisco Technical Notes: RESTCONF and NETCONF Setup on Cisco IOS XE
* Cisco Live Presentation: BRKOPS-2431 - Network Automation with NETCONF & RESTCONF
* Cisco Command Reference: System Management Commands
* Cisco Security Advisory: SNMPv3 Configuration & Best Practices

---

## 📝 補足（Notes）

* **NETCONF (TCP 830) と RESTCONF (HTTPS 443) の使い分け:**
  * 大規模プログラマブル自動化やトランザクション処理（Commit/Rollback）を重視する場合は NETCONF を採用する。
  * Web アプリケーションや軽量スクリプトから HTTP RESTful アプローチでアクセスする場合は RESTCONF を採用する。
* **Syslog タイムスタンプと NTP 同期:**
  * 監査ログ解析やトラブルシューティングにおいて、各デバイスのログ時刻の不一致は致命的となるため、常に NTP サーバーと同期させ `service timestamps log datetime msec` を適用することが鉄則である。
* **Conditional Debugging の安全運用:**
  * 本番環境や CCIE ラボ試験において、生データデバッグ（`debug ip packet`）の直接実行は CPU 飽和によるデッドロックを引き起こすため、必ず `debug condition` を介してターゲットを絞り込んで実行すること。
