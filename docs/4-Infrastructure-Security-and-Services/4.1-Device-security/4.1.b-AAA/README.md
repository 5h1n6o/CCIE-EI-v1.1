---
layout: default
title: 4.1.b-AAA
parent: 4.1-Device-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.1.b AAA

## 📘 概要

AAA（Authentication: 認証、Authorization: 认可、Accounting: 課金/監査）は、Cisco IOS XE デバイスの管理アクセス（Console、VTY/SSH、HTTPS）およびネットワークアクセス（802.1X、MAB、WebAuth）において、セキュリティ・アクセス制御・操作監査を中央集権的またはローカルで厳格に適用するための基本フレームワークである。

* **機能概要:**
  * **Authentication（認証）:** 「あなたは誰か（Who you are）」を検証する。ユーザー名・パスワード、証明書など。
  * **Authorization（認可）:** 「あなたは何ができるか（What you can do）」を決定する。権限レベル（Privilege Level 0-15）、実行可能 CLI コマンド制限、RADIUS 属性（dACL、VLAN、SGT）の付与。
  * **Accounting（課金/監査）:** 「あなたは何をしたか（What you did）」を記録する。ログイン/ログアウト日時、実行した CLI コマンド履歴ログの収集。

* **利用目的:**
  * Cisco ISE（Identity Services Engine）や TACACS+ / RADIUS 集中管理サーバと連携し、全ネットワーク機器のアクセス制御を一元化する。
  * 個別のローカルアカウント管理から脱却し、ポリシー変更時の全機器一括適用を実現する。
  * 不正アクセスや管理者の誤操作・悪意ある操作に対する完全なトレーサビリティ（操作ログ監査）を確保する。

* **どのような場面で利用するか:**
  * CCIE EI ラボ試験におけるインフラ安全化の基礎要件（SSH/VTY 管理アクセスの TACACS+ 集中認証およびローカルフォールバック構成）。
  * ネットワークセキュリティ運用におけるコマンドレベルの認可制御（例: 運用オペレータには <code>show</code> コマンドのみ許可し、<code>configure terminal</code> は遮断）。
  * 802.1X / MAB / Cisco SD-Access 環境における動的アクセス制御（Dynamic VLAN、dACL、SGT 割り当て）。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **特徴** | 認証・認可・課金の 3 要素をモジュール化し、異なる認証方式（TACACS+, RADIUS, Local, Enable）を柔軟に組み合わせて制御可能。 |
| **用途** | デバイス管理アクセス制御（Exec ログイン、CLI コマンド認可）、ネットワーク接続認証（802.1X / MAB）、監査ログ収集。 |
| **メリット** | アカウント一元管理による運用負荷低減、厳格なコマンド単位のアクセス制御、改ざん耐性のある集中操作ログの収集。 |
| **デメリット** | 集中 AAA サーバダウン時の認証不可リスク（適切な Local Fallback 設計が不可欠）、ネットワーク遅延による管理ログイン遅延。 |
| **対応機種** | Catalyst 9000 シリーズ, ISR 4000 シリーズ, ASR 1000 シリーズ, Catalyst 8000v を含む全 Cisco IOS XE デバイス。 |
| **制限事項** | <code>aaa new-model</code> 有効化により伝統的な <code>line vty</code> パスワード認証が無効化される。サーバーグループ指定順序と Timeout 値の最適化が必要。 |
| **設計上の注意点** | AAA サーバ全滅時に管理ログインが不能となる "Lockout" 障害を防ぐため、必ず <code>group <NAME> local</code> などのフォールバックを定義する。 |

---

## 🏗 動作原理

AAA は、クライアント（管理者/端末）、NAS（Network Access Server: Cisco IOS XE デバイス）、AAA サーバ（Cisco ISE や TACACS+ / RADIUS サーバ）の 3 層構成で動作する。

```
[ Client / Administrator ]
          │
          │ 1. Access Request (SSH / Exec / 802.1X)
          ▼
[ Cisco IOS XE Device (NAS) ]
          │
          │ 2. AAA Protocol Request (TACACS+ TCP 49 / RADIUS UDP 1812)
          ▼
[ AAA Server (Cisco ISE) ]
          │
          │ 3. AAA Protocol Response (ACCEPT / REJECT + Attributes)
          ▼
[ Cisco IOS XE Device (NAS) ]
          │
          │ 4. Apply Access Policy (Privilege Level / dACL / SGT / Command Permit)
          ▼
[ Client / Administrator ]
```

### 認証・認可・課金の処理パイプライン
1. **Authentication (認証):** ユーザーが SSH 等でアクセスを開始すると、NAS は AAA ログイン認証リスト（<code>aaa authentication login</code>）に基づいて定義された順序（例: TACACS+ Group ➔ Local）で問い合わせを行う。
2. **Authorization (認可):** 認証成功後、AAA 認可リスト（<code>aaa authorization exec</code> / <code>aaa authorization commands</code>）に従い、ユーザの権限レベル（Privilege 15）や実行可能コマンドを適用する。
3. **Accounting (課金):** セッション開始（Start）、コマンド実行、セッション終了（Stop）のタイミングで、AAA 課金リスト（<code>aaa accounting exec</code> / <code>aaa accounting commands</code>）に基づき AAA サーバへログを送信する。

---

## ⚙ 動作シーケンス

パケットおよび状態遷移のフローは以下の通りである。

```
[ User ]           [ Cisco IOS XE Router ]             [ TACACS+ / RADIUS Server ]
   │                          │                                     │
   │─── 1. SSH Connect ──────>│                                     │
   │                          │─── 2. TACACS+ Authen Start ────────>│ (TCP 49)
   │                          │<── 3. TACACS+ GETUSER / GETPASS ────│
   │<── 4. Username/Pass ─────│                                     │
   │─── 5. Reply Credentials─>│                                     │
   │                          │─── 6. TACACS+ Authen Continue ─────>│
   │                          │<── 7. TACACS+ PASS (Authen OK) ─────│
   │                          │                                     │
   │                          │─── 8. TACACS+ Author Request ──────>│ (CLI Command Authorization)
   │                          │<── 9. TACACS+ PASS (Command Permit)─│
   │                          │                                     │
   │<── 10. Exec CLI Output ──│                                     │
   │                          │─── 11. TACACS+ Acct Request (Stop)─>│ (Command Accounting)
   │                          │<── 12. TACACS+ Acct Response ───────│
```

1. ユーザーが SSH 接続を開始。
2. ルータは `aaa new-model` で有効化された AAA パイプラインを起動し、指定された AAA サーバグループに問い合わせを開始。
3. AAA サーバから チャレンジ/応答（GETUSER / GETPASS）を受信し、ユーザーにプロンプトを表示。
4. ユーザーが入力したクレデンシャルをパケット化して AAA サーバへ転送。
5. AAA サーバがクレデンシャルを照合し `PASS` 応答を返却。
6. Exec セッション確立時、認可リスト（`aaa authorization exec`）に従い権限レベル（例: Privilege 15）を取得。
7. ユーザーが CLI コマンド（例: `configure terminal`）を入力する度に、認可リスト（`aaa authorization commands 15`）に従い AAA サーバへコマンド実行の可否を問い合せる。
8. AAA サーバが許可（PASS）を返した場合のみ、コマンドを実行。
9. コマンド完了後、課金リスト（`aaa accounting commands 15`）に基づきログ（実行したコマンド、日時、ユーザー名）を AAA サーバへ送出。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint での重要ポイント
* **`aaa new-model` の理解と設定:** 全ての AAA 処理の前提コマンド。これを入力しないと、以降の `aaa authentication` や `aaa authorization` コマンドが機能しない。
* **Server Group の定義と Dead-Timer の調整:** `tacacs server` や `radius server` コマンドで個別にサーバを定義し、`aaa group server` でグループ化する現代的構文のマスター。
* **Local Fallback (ロックアウト防止):** ラボ試験で「AAA サーバへの通信が途絶した場合でもローカルユーザーでログイン可能にすること」という要件が頻出。`aaa authentication login default group TACACS_GROUP local` のように末尾に `local` を記述する。
* **Command Authorization (コマンド認可):** Privilege 15 ユーザーが実行するすべてのコマンドを TACACS+ サーバでチェック・認可する構文 (`aaa authorization commands 15 default group TACACS_GROUP local`) の適切な適用。

### 2. よくある設定ミス・罠
* **Local Fallback の指定漏れ:** `group TACACS_GROUP` のみで指定し、`local` を書き忘れる。試験環境で TACACS+ サーバの到達性が失われた際、ルータにアクセス不能（Lockout）となる。
* **Server-Group の古い構文の使用:** `tacacs-server host <IP> key <KEY>` などの非推奨旧構文を使用し、VRF バインド（`ip vrf forwarding`）やソース IP 指定が正常に動作しない。
* **Console ポートでのロックアウト:** `aaa authentication login default` を適用した結果、コンソールポートからアクセスできなくなるトラブル。`line con 0` に対して `login authentication` を個別に適用するか、Console 専用の認証リストを作成する。
* **`aaa authorization exec` の欠落:** 認証が成功しても Privilege 15 が付与されず、ログイン後に Privilege 1 の一般モード（`>`）に落とされる。

### 3. Show / Debug コマンドによる状態判断
* `show aaa sessions`: 現在アクティブな AAA セッション一覧および一意の AAA Session ID を確認。
* `show aaa servers`: 各 TACACS+ / RADIUS サーバのステータス（Alive / Dead）、レスポンスタイム、送信/受信パケット数、応答ドロップ数を即座に確認。
* `debug aaa authentication`: 認証要求パイプラインの追跡。どのリストが呼び出され、どのメソドロジー（Group, Local 等）へフォールバックしたかを追跡。
* `debug aaa authorization`: 認可要求および属性（Privilege Level, dACL, SGT）の解析。
* `debug tacacs authentication` / `debug tacacs authorization`: TACACS+ パケットの送信・受信・タイムアウトのデバッグ。

---

## 🛠 設定方法

### 1. TACACS+ 集中管理アクセスの標準設定（Cisco 推奨現代構文）

```bash
! 1. AAA のグローバル有効化
aaa new-model

! 2. 個別 TACACS+ サーバの定義（IOS XE 16.x / 17.x 標準）
tacacs server ISE_TACACS_1
 address ipv4 192.168.100.11
 key 0 Cisco123Secret
 timeout 3
!
tacacs server ISE_TACACS_2
 address ipv4 192.168.100.12
 key 0 Cisco123Secret
 timeout 3

! 3. AAA サーバグループの定義
aaa group server tacacs+ TACACS_SERVERS
 server name ISE_TACACS_1
 server name ISE_TACACS_2
 ip tacacs source-interface Loopback0

! 4. ローカルフォールバック用フォールバックアカウントの作成
username admin privilege 15 secret 0 CiscoCCIE2026Lab!

! 5. AAA 認証リスト（Login）の定義（TACACS+ ➔ Local フォールバック）
aaa authentication login default group TACACS_SERVERS local
aaa authentication login CONSOLE_LIST local

! 6. AAA 認可リスト（Exec ＆ Command）の定義
aaa authorization exec default group TACACS_SERVERS local
aaa authorization commands 15 default group TACACS_SERVERS local

! 7. AAA 課金リスト（Accounting）の定義
aaa accounting exec default start-stop group TACACS_SERVERS
aaa accounting commands 15 default start-stop group TACACS_SERVERS

! 8. アクセスラインへの適用
line con 0
 login authentication CONSOLE_LIST
 exec-timeout 0 0
line vty 0 4
 transport input ssh
 login authentication default
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| **AAA サーバステータス確認** | <code>show aaa servers</code> |
| **アクティブ AAA セッションの確認** | <code>show aaa sessions</code> |
| **AAA ユーザー属性・権限の確認** | <code>show aaa user all</code> |
| **特定ユーザーの AAA 定義の確認** | <code>show aaa user name <USERNAME></code> |
| **running-config 内の AAA 抽出** | <code>show running-config \| section aaa</code> |
| **TACACS+ 統計情報の確認** | <code>show tacacs</code> |
| **RADIUS 統計情報の確認** | <code>show radius statistics</code> |
| **AAA 認証プロセスデバッグ** | <code>debug aaa authentication</code> |
| **AAA 認可プロセスデバッグ** | <code>debug aaa authorization</code> |
| **AAA 課金プロセスデバッグ** | <code>debug aaa accounting</code> |
| **TACACS+ パケットデバッグ** | <code>debug tacacs authentication</code> / <code>debug tacacs authorization</code> |
| **RADIUS パケットデバッグ** | <code>debug radius</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **TACACS+ サーバダウン時に SSH ログイン不可** | 認証リストに `local` フォールバックが指定されていない。 | <code>show running-config \| include aaa authentication</code> | `aaa authentication login default group TACACS_SERVERS local` のように末尾に `local` を追加する。 |
| **ログイン後に Privilege 1 (`>`) になる** | `aaa authorization exec` が未定義、または TACACS+ サーバから Privilege 15 が返されていない。 | <code>show aaa user all</code> | `aaa authorization exec default group <GRP> local` を適用し、ISE 側で Exec 認可プロファイル（priv-lvl=15）を設定する。 |
| **コマンド入力ごとに著しい遅延が発生する** | `aaa authorization commands 15` が有効だが、主 TACACS+ サーバが Down し Timeout 待ちが発生。 | <code>show aaa servers</code> | `show aaa servers` で Dead サーバを確認。`deadtime` や `timeout` 値を短縮（例: timeout 2）し不要な待ち時間を削除。 |
| **コンソールから管理アクセス不能** | `aaa authentication login default` の影響でローカル認証が要求されパスワード不一致。 | <code>show running-config \| section line con</code> | Console 専用認証リスト `aaa authentication login CONSOLE_LIST local` を作成し、`line con 0` へ `login authentication CONSOLE_LIST` を適用。 |
| **特定 VRF 経由の TACACS+ 通信が失敗** | サーバグループ内で VRF バインド（`ip vrf forwarding`）が設定されていない。 | <code>show aaa servers</code> | `aaa group server tacacs+ <NAME>` 内に `ip vrf forwarding <VRF_NAME>` を追加指定する。 |
| **802.1X 認証で RADIUS 応答が拒否される** | RADIUS Shared Secret の不一致、またはソース IP ミスマッチ。 | <code>debug radius</code> | `radius server` 内の `key` を再確認し、`ip radius source-interface` を ISE 登録 IP と一致させる。 |

---

## ⚠ 制限事項

* **`aaa new-model` の不可逆的変更:** `aaa new-model` を実行した瞬間、`line vty` で設定されていた旧来の `password <SECRET>` 認証が即座に無効化され、デフォルトの AAA リストが適用される。
* **AAA Server 死活監視 (Dead Timer):** 無応答の AAA サーバはデフォルトで Dead 状態にマークされるが、明示的な `aaa server radius dynamic-author` や `deadtime` のチューニングを行わないと、復旧検出遅延が生じる。
* **TACACS+ vs RADIUS のプロトコル互換性:** TACACS+ は CLI コマンド単位認可（Command Authorization）に対応するが、RADIUS は構造上コマンド単位認可をサポートしない（RADIUS は Exec 単位や 802.1X 属性付与のみ）。

---

## 🔄 他技術との関連

* **Cisco ISE (Identity Services Engine):** TACACS+ (Device Admin) および RADIUS (Network Access) の集中管理バックエンド。
* **802.1X / MAB (Port-Based Authentication):** ポートレベルの端末認証において `aaa authentication dot1x` および `aaa authorization network` と緊密に連動。
* **VRF-Lite / Management VRF:** Out-of-Band 管理網（Mgmt-vrf）経由で AAA サーバと通信する場合、Server Group 内で `ip vrf forwarding Mgmt-vrf` のバインドが必須。
* **Control Plane Policing (CoPP):** TACACS+ (TCP 49) および RADIUS (UDP 1812/1813) の制御パケットが CoPP で誤ってドロップされないよう ACL で許可（Permit）設計が必要。

---

## 🧩 比較表

### TACACS+ vs RADIUS

| 比較項目 | TACACS+ (Terminal Access Controller Access-Control System+) | RADIUS (Remote Authentication Dial-In User Service) |
| --- | --- | --- |
| **開発標準** | Cisco 独自プロトコル (RFC 8907) | IETF オープン標準 (RFC 2865 / 2866) |
| **トランスポート** | **TCP ポート 49** (信頼性重視) | **UDP ポート 1812 (認証), 1813 (課金)** |
| **パケット暗号化** | **ヘッダーを除く全パケットボディを完全暗号化** | **Password 領域のみ暗号化** (パケットヘッダー・属性は平文) |
| **機能分離** | **認証・認可・課金が完全に独立分離** | **認証と認可が統合結合** (Authentication + Authorization) |
| **CLI コマンド認可** | **対応** (コマンド 1 行ごとに TACACS+ サーバへ認可確認可能) | **非対応** (ログイン時の Privilege Level または Exec 認可のみ) |
| **主な用途** | **デバイス管理アクセス制御 (Device Administration)** | **ネットワークアクセスコントロール (802.1X / MAB / VPN)** |

---

## 💡 ベストプラクティス

1. **必ず Local Fallback アカウントとリストを配置する:** AAA サーバ故障時の閉め出し（Lockout）を防ぐため、高強度のシークレットを持つローカル管理者アカウントを常設し、認証・認可リストの末尾に `local` を必ず指定する。
2. **専用の Management VRF / Source Interface を指定する:** ルートのブレや送信元 IP の変動を防ぐため、`ip tacacs source-interface Loopback0` や `ip radius source-interface Loopback0` を明示指定する。
3. **Timeout と Retry 回数の最適化:** デフォルトの Timeout (5秒) は長すぎる場合がある。`timeout 2`、`retransmit 2` 程度にチューニングし、障害時の他サーバ/ローカルへの切り替えを高速化する。
4. **Console ポートの個別保護:** ネットワーク障害時でも Console から確実に復旧できるよう、Console には Dedicated なローカル認証リスト（例: `aaa authentication login CONSOLE_LIST local`）を割り当てる。

---

## 📝 ラボ学習・設定サンプル例

### シナリオ 1: TACACS+ 集中認証 ＋ Local Fallback 構成
* **問題:** ルータ R1 において、VTY（SSH）アクセスに対して TACACS+ サーバ（`192.168.1.100`）による集中認証を設定せよ。サーバ応答不可時はローカルユーザーでフォールバック可能とすること。
* **要件:**
  * AAA サーバーグループ名: `TAC_GROUP`
  * TACACS Key: `CiscoKey123`
  * ローカルフォールバック用ユーザー: `admin` / パスワード `Cisco123Secret` (Privilege 15)
  * ソース IP: Loopback0 (`10.1.1.1`)
* **設定例:**
```bash
aaa new-model
username admin privilege 15 secret Cisco123Secret

tacacs server TAC_SERVER_1
 address ipv4 192.168.1.100
 key CiscoKey123
 timeout 2

aaa group server tacacs+ TAC_GROUP
 server name TAC_SERVER_1
 ip tacacs source-interface Loopback0

aaa authentication login default group TAC_GROUP local
aaa authorization exec default group TAC_GROUP local

line vty 0 4
 transport input ssh
 login authentication default
```
* **検証方法:**
  1. `show aaa servers` で TACACS+ サーバの応答・ステータスを確認。
  2. TACACS+ サーバ側でアカウントを作成し SSH 接続を検証。
  3. TACACS+ サーバを停止（または ACL で TCP 49 を遮断）し、`admin` アカウントで SSH ログインができるか（Local Fallback）を検証。

---

### シナリオ 2: RADIUS 認可 ＆ Dynamic Exec Privilege Level 構成
* **問題:** R1 において RADIUS サーバ（`192.168.1.200`）による Exec ログイン認証・認可を構成せよ。
* **要件:**
  * RADIUS サーバーグループ: `RAD_GROUP`
  * RADIUS Key: `RadKey456`
  * RADIUS サーバから返却される IETF 属性 `Service-Type = Exec` および `Cisco-AVPair = "shell:priv-lvl=15"` を受容して Privilege 15 を動的割り当てすること。
* **設定例:**
```bash
aaa new-model
username fallback-admin privilege 15 secret Cisco123Secret

radius server RAD_SERVER_1
 address ipv4 192.168.1.200 auth-port 1812 acct-port 1813
 key RadKey456

aaa group server radius RAD_GROUP
 server name RAD_SERVER_1
 ip radius source-interface Loopback0

aaa authentication login RAD_LOGIN group RAD_GROUP local
aaa authorization exec RAD_AUTHOR group RAD_GROUP local

line vty 0 4
 transport input ssh
 login authentication RAD_LOGIN
 authorization exec RAD_AUTHOR
```
* **検証方法:**
  1. RADIUS サーバ経由で SSH ログインを実施。
  2. ログイン直後にプロンプトが `#` (Privilege 15) になっていることを確認。
  3. `show aaa user all` を実行し、取得した Privilege Level が 15 であることを検証。

---

### シナリオ 3: TACACS+ CLI コマンド認可 (Command Authorization: Level 15)
* **問題:** 特権モード（Privilege 15）の管理者が実行する全ての CLI コマンドに対して、TACACS+ サーバへの事前認可チェックを強制せよ。
* **要件:**
  * TACACS+ グループ: `TAC_CMD_GRP`
  * TACACS+ サーバ: `192.168.1.100`
  * TACACS+ 無応答時はローカルに認可フォールバックすること。
* **設定例:**
```bash
aaa new-model
username admin privilege 15 secret Cisco123Secret

tacacs server TAC_SERVER_1
 address ipv4 192.168.1.100
 key CiscoKey123

aaa group server tacacs+ TAC_CMD_GRP
 server name TAC_SERVER_1

aaa authorization commands 15 default group TAC_CMD_GRP local
```
* **検証方法:**
  1. SSH ログイン後、`configure terminal` などの特権コマンドを入力。
  2. `debug tacacs authorization` を有効化し、コマンド 1 行ごとに TACACS+ 要求パケットが送信されていることを確認。

---

### シナリオ 4: AAA Accounting (Exec ＋ Command 監査ログ収集)
* **問題:** 管理者がログインした日時・セッション終了時、および実行した全 Privilege 15 コマンドの監査ログを TACACS+ サーバへ送出せよ。
* **要件:**
  * 課金方式: `start-stop`（セッション開始および終了時に送出）
  * グループ名: `TAC_ACCT_GRP`
* **設定例:**
```bash
aaa new-model

tacacs server TAC_SERVER_1
 address ipv4 192.168.1.100
 key CiscoKey123

aaa group server tacacs+ TAC_ACCT_GRP
 server name TAC_SERVER_1

aaa accounting exec default start-stop group TAC_ACCT_GRP
aaa accounting commands 15 default start-stop group TAC_ACCT_GRP
```
* **検証方法:**
  1. `debug aaa accounting` を有効化。
  2. SSH ログインおよびコマンド実行を行い、デバッグログに Accounting Start/Stop パケットの生成および送出ログが出力されることを確認。

---

### シナリオ 5: Console ポート専用 AAA Bypass / Dedicated Authentication
* **問題:** ネットワーク障害時や TACACS+ 全滅時でも、Console ポートからは確実にローカル認証でログインできるように保護せよ。
* **要件:**
  * Console ポートは TACACS+ へ問い合わせず、常にローカルデータベース（`local`）のみで認証すること。
  * VTY（SSH）は TACACS+ 優先 ➔ Local フォールバックとすること。
* **設定例:**
```bash
aaa new-model
username conadmin privilege 15 secret ConPass123!
username vtyadmin privilege 15 secret VtyPass123!

tacacs server TAC_SERVER_1
 address ipv4 192.168.1.100
 key CiscoKey123

aaa group server tacacs+ TAC_GRP
 server name TAC_SERVER_1

! 認証リストの個別定義
aaa authentication login CONSOLE_LOCAL local
aaa authentication login VTY_TACACS group TAC_GRP local

line con 0
 exec-timeout 0 0
 login authentication CONSOLE_LOCAL

line vty 0 4
 transport input ssh
 login authentication VTY_TACACS
```
* **検証方法:**
  1. Console 接続時、TACACS+ ログが発生せず `conadmin` でローカル認証成功することを確認。
  2. SSH 接続時、TACACS+ サーバへ問い合わせが行われることを確認。

---

### シナリオ 6: Management VRF を経由する AAA サーバ連携
* **問題:** Out-of-Band 管理用 VRF（`Mgmt-vrf`）配下に配置された TACACS+ サーバへ AAA 問い合わせを行うよう構成せよ。
* **要件:**
  * VRF 名: `Mgmt-vrf`
  * TACACS+ IP: `10.255.255.10`
* **設定例:**
```bash
aaa new-model

tacacs server TAC_MGMT
 address ipv4 10.255.255.10
 key MgmtKey123!

aaa group server tacacs+ TAC_MGMT_GRP
 server name TAC_MGMT
 ip vrf forwarding Mgmt-vrf
 ip tacacs source-interface GigabitEthernet0/0

aaa authentication login default group TAC_MGMT_GRP local
aaa authorization exec default group TAC_MGMT_GRP local
```
* **検証方法:**
  1. `show aaa servers` を実行し、特定された VRF (`Mgmt-vrf`) 経由で TACACS+ サーバが `State: Alive` となっていることを確認。

---

### シナリオ 7: AAA Server Group 冗長化 ＆ Dead-Timer チューニング
* **問題:** プライマリ AAA サーバダウン時の無効な待ち時間を削減し、セカンダリ AAA サーバへの高速フェイルオーバーを実現せよ。
* **要件:**
  * Timeout: 2 秒
  * Retransmit: 1 回
  * Deadtime: 15 分
* **設定例:**
```bash
aaa new-model

tacacs server TAC_PRIMARY
 address ipv4 192.168.1.100
 key SecretKey123
 timeout 2

tacacs server TAC_SECONDARY
 address ipv4 192.168.1.101
 key SecretKey123
 timeout 2

aaa group server tacacs+ TAC_HA_GRP
 server name TAC_PRIMARY
 server name TAC_SECONDARY

aaa server radius dynamic-author
aaa deadtime 15
```
* **検証方法:**
  1. `show aaa servers` で各サーバの Timeout 値と Deadtime を確認。
  2. プライマリサーバ宛ての通信を障害化させた際、2 秒 × 2 回の試行後に即座にセカンダリへ切り替わることを確認。

---

### シナリオ 8: 802.1X / MAB 認証用 AAA ネットワーク設定
* **問題:** ネットワークアクセス制御（802.1X および MAB）のための RADIUS AAA リストを構成せよ。
* **要件:**
  * RADIUS サーバ: `192.168.1.200`
  * 認証リスト名: `DOT1X_AUTH`
  * 認可リスト名: `DOT1X_AUTHOR`
* **設定例:**
```bash
aaa new-model

radius server ISE_RADIUS
 address ipv4 192.168.1.200 auth-port 1812 acct-port 1813
 key IseRadKey123

aaa group server radius ISE_RAD_GRP
 server name ISE_RADIUS
 ip radius source-interface Loopback0

! 802.1X / MAB 用 AAA リスト
aaa authentication dot1x default group ISE_RAD_GRP
aaa authorization network default group ISE_RAD_GRP
aaa accounting network default start-stop group ISE_RAD_GRP
```
* **検証方法:**
  1. スイッチポートで `dot1x pae authenticator` を有効化し、端末接続時に RADIUS アクセス要求パケットが ISE_RAD_GRP へ送信されることを確認。

---

### シナリオ 9: RADIUS Change of Authorization (CoA / Dynamic Authorization)
* **問題:** Cisco ISE からの動的ポリシー変更命令（CoA: Change of Authorization / Re-authentication / Port Bounce）を受容可能に設定せよ。
* **要件:**
  * ポート: UDP 1700 (Cisco Standard) / 3799 (RFC 5176)
  * クライアント IP: `192.168.1.200`
  * Shared Secret: `IseRadKey123`
* **設定例:**
```bash
aaa new-model

aaa server radius dynamic-author
 client 192.168.1.200 server-key IseRadKey123
 port 1700
```
* **検証方法:**
  1. `show ip access-lists` および `show authentication sessions` を確認。
  2. ISE から CoA ポートバウンス命令を発行し、スイッチ側で CoA パケットが正常に受信・処理されることをデバッグ (`debug radius dfp`) で確認。

---

### シナリオ 10: TACACS+ / RADIUS キーの暗号化保存（Type 6 / Type 7）
* **問題:** `running-config` 内に平文で保存される TACACS+ / RADIUS の Shared Key およびローカルユーザーパスワードを強力に暗号化保護せよ。
* **要件:**
  * `service password-encryption` を有効化し、必要に応じて AES Type 6 暗号化を適用すること。
* **設定例:**
```bash
! 1. パスワード暗号化サービスの有効化（Type 7）
service password-encryption

! 2. 暗号化付きキー指定（例: 暗号化済みキーの直接指定）
tacacs server TAC_SECURE
 address ipv4 192.168.1.100
 key 7 0822155D1A050A151C

username admin privilege 15 secret 9 $9$eX8aK1...
```
* **検証方法:**
  1. `show running-config | section tacacs` を実行し、キーが平文ではなく暗号化文字列になっていることを確認。

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
以下のコンフィグが適用されたルータ R1 において、TACACS+ サーバ `192.168.1.100` がメンテナンスのため停止した。管理者が SSH 経由でログインを試みたが、ローカルアカウント `admin` でもログインが拒否された。原因と修正方法を説明せよ。

```bash
aaa new-model
username admin privilege 15 secret LabPassword123

tacacs server TAC_1
 address ipv4 192.168.1.100
 key Key12345

aaa group server tacacs+ TAC_GRP
 server name TAC_1

aaa authentication login default group TAC_GRP
aaa authorization exec default group TAC_GRP
```

* **解答・解説:**
  * **原因:** `aaa authentication login default` の定義において、末尾に `local` フォールバックが指定されていないため。TACACS+ サーバが無応答（Dead）となった際、ローカルデータベースへの問い合わせが行われず認証が即座にドロップする。
  * **修正方法:** 以下のように認証リストおよび認可リストの末尾に `local` を追加する。
    ```bash
    aaa authentication login default group TAC_GRP local
    aaa authorization exec default group TAC_GRP local
    ```

---

### 問 2 (トラブルシューティング / 権限レベル)
管理者が TACACS+ 経由で SSH ログインに成功したが、ログイン後のプロンプトが `R1>`（Privilege Level 1）となってしまい、特権モード（`#`）に移行できない。コンフィグを確認したところ `aaa authorization exec default group TAC_GRP local` は設定されている。考えられる原因を 2 つ挙げよ。

* **解答・解説:**
  1. **原因 1:** TACACS+ サーバ（Cisco ISE 等）側の Shell Profile（Exec 認可ポリシー）で、`Default Privilege = 15` や `Cisco-AVPair = "shell:priv-lvl=15"` が割り当てられておらず、デフォルトの Level 1 が返却されている。
  2. **原因 2:** ルータ側で `enable` パスワード/シークレット（`enable secret`）が設定されておらず、一般モードから `enable` コマンドを実行しても認証できず失敗している。

---

### 問 3 (Design)
企業網において、デバイス管理アクセス（SSH CLI）には TACACS+ を採用し、キャンパス VLAN 端末の 802.1X 認証には RADIUS を採用する設計とした。この使い分けの決定的な技術的理由を 2 つ説明せよ。

* **解答・解説:**
  1. **理由 1 (コマンド認可機能):** TACACS+ は認証と認可が完全分離されており、CLI コマンド 1 行ごとにサーバへ問い合わせる「Command Authorization」に対応しているため、デバイス管理のセキュリティに最適である。RADIUS はコマンド単位認可に対応しない。
  2. **理由 2 (暗号化範囲と標準性):** TACACS+ は TCP 49 を使用しヘッダーを除く全パケットボディを完全暗号化するため機密性が高い。一方 RADIUS は UDP 1812 を使用しパスワード部分のみ暗号化する標準プロトコルであり、多くのサードパーティ端末や 802.1X サプリカントとの広範な互換性を持つため端末認証に最適である。

---

### 問 4 (実装)
Out-of-Band 管理用 VRF 名 `Mgmt-vrf` に所属する GigabitEthernet0/0 から TACACS+ サーバ `10.10.10.50` へ AAA 要求を送信したい。正しい CLI 設定を示せ。

* **解答・解説:**
  * **設定例:**
    ```bash
    aaa new-model

    tacacs server TAC_OOB
     address ipv4 10.10.10.50
     key KeyOob123

    aaa group server tacacs+ TAC_OOB_GRP
     server name TAC_OOB
     ip vrf forwarding Mgmt-vrf
     ip tacacs source-interface GigabitEthernet0/0

    aaa authentication login default group TAC_OOB_GRP local
    aaa authorization exec default group TAC_OOB_GRP local
    ```

---

### 問 5 (トラブルシューティング / 遅延問題)
特権管理者（Privilege 15）が CLI コマンドを入力する度に、画面が 3〜5 秒間フリーズ（応答停止）してからコマンドが実行される現象が発生している。確認すべき AAA コマンドと対処方法を述べよ。

* **解答・解説:**
  * **原因:** `aaa authorization commands 15 default group <GRP> local` が設定されている環境で、プライマリ TACACS+ サーバへの IP 疎通が不能になっており、コマンド入力ごとに TACACS+ の Timeout 待ちが発生している。
  * **確認コマンド:** `show aaa servers` を実行し、サーバの Status や Timeout 回数を確認。
  * **対処方法:** `tacacs server` 配下で `timeout 2` 等に短縮チューニングを行うか、障害が発生している TACACS+ サーバの到達性を復旧させる。

---

## 🔗 参考リソース

* **Cisco IOS XE Configuration Guide:** AAA Security (xe-17-book)
* **Cisco Security Command Reference:** AAA Commands (aaa-cr-book)
* **Cisco Live Presentation:** BRKSEC-2012 - AAA and ISE Device Administration (TACACS+)
* **Cisco Technical Notes:** Troubleshooting TACACS+ Authentication and Authorization Issues
* **Cisco Technical Notes:** Understanding RADIUS and TACACS+ Attributes in IOS XE

---

## 📝 補足（Notes）

### 1. AAA 処理ロジックのフローチャート（図解）

```
[ User Action: SSH Login or CLI Command ]
                   │
                   ▼
       [ Check AAA List Definition ]
                   │
         ┌─────────┴─────────┐
         │ Group Specified?  │
         └─────────┬─────────┘
            YES    │    NO
     ┌─────────────┴─────────────┐
     ▼                           ▼
[ Contact AAA Server ]    [ Fallback to Local ]
     │                           │
  SUCCESS?                    SUCCESS?
  ├── YES ──> [ GRANT ]       ├── YES ──> [ GRANT ]
  └── NO (Server Dead)        └── NO  ──> [ DENY ]
        │
        ▼
 [ Local Fallback Defined? ]
  ├── YES ──> [ Contact Local DB ]
  └── NO  ──> [ DENY (Lockout) ]
```

### 2. 注意点まとめ
* `aaa new-model` の適用は、必ずコンソール接続を確保した状態で行うこと。
* `group <NAME> local` の `local` は「AAA サーバが **応答しない（Dead/Timeout）**」場合のみ実行される。「AAA サーバが **明確に Reject (認証失敗)** を返した」場合はローカル認証へフォールバックせず拒否されることに注意する。


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


