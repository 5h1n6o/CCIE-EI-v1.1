---
layout: default
title: 4.3.b-SNMP
parent: 4.3-System-management
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.3.b SNMP (v2c, v3)

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.0 Infrastructure Security and Services` における、ネットワーク監視・管理プロトコルである **SNMP (v2c, v3)** の詳細学習メモ。

---

## 📘 概要

SNMP（Simple Network Management Protocol）は、ネットワーク管理システム（NMS: Network Management System）とネットワーク機器（マネージドデバイス / SNMP エージェント）との間で、機器の状態監視、リソース情報収集、構成変更、およびイベント通知を行うための業界標準アプリケーション層プロトコルである。

* **利用目的:**
  * **Polling (アクティブ監視):** NMS から一定間隔で GET リクエストを発行し、CPU 使用率、メモリ使用量、インターフェイスのトラフィック量・エラー数、リンク状態（UP/DOWN）などの MIB オブジェクト値を取得・蓄積する。
  * **Notification (パッシブ監視):** リンクフラップ、電源障害、認証失敗、構成変更などの重大イベント発生時に、スイッチやルータから NMS 宛てに即座に Trap または Inform 通知を発行する。
  * **Configuration Push (構成操作):** NMS から SET リクエストを発行し、機器のパラメータ変更や SVI / 物理ポートのシャットダウン操作を行う。

* **適用場面:**
  * エンタープライズ大規模網における Cisco DNA Center, Prime Infrastructure, SolarWinds, Zabbix 等の NMS 統合監視。
  * MPLS L3VPN や SD-Access (SDA) ファブリックにおける VRF-Aware 監視。
  * Cisco ISE によるネットワークデバイスのプロファイリング（SNMP Query Probe / SNMP Trap Probe）。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | UDP（ポート 161: Polling/SET, ポート 162: Notification）を使用する非同期/同期管理プロトコル。v3 では USM/VACM による暗号化・認証を提供 |
| **主な用途** | リアルタイムパフォーマンス監視、障害検知（Trap/Inform）、インベントリ管理、VRF ごとの特定 MIB 制限（Context-Based SNMP） |
| **メリット** | 業界標準でありベンダーを問わず監視可能。SNMPv3 では改ざん防止・なりすまし防止・データ暗号化（AES/3DES）を担保 |
| **デメリット** | SNMPv1/v2c はプレーンテキスト（コミュニティ文字列）のため盗聴・改ざんリスクが非常に高い。SNMPv3 は鍵計算負荷と設定の複雑さが増大 |
| **対応機種** | Cisco Catalyst 9000 シリーズ, ISR 4000 / Catalyst 8000 シリーズ, ASR 1000, Nexus 等（Cisco IOS XE 全般） |
| **制限事項** | SNMPv1 は Informs 未対応。スタック構成時（StackWise）での engineID 変更に伴うユーザー認証失敗リスク |
| **設計上の注意点** | 監視トラフィックに対する ACL（`snmp-server community <NAME> <RO|RW> <ACL>`）制限の必須化。Informs の再送タイマーチューニング |

---

## 🏗 動作原理

SNMP は **NMS (SNMP Manager)** と **SNMP Agent (ネットワークデバイス)** のマネージャー・エージェント型構造で動作する。管理情報は **MIB (Management Information Base)** と呼ばれる階層構造のツリー（OID: Object Identifier）に定義されている。

```
+-------------------+                          +-------------------+
|   NMS / Manager   |                          |    SNMP Agent     |
| (SolarWinds, DNAC)|                          | (Catalyst / ISR)  |
+-------------------+                          +-------------------+
          |                                              |
          | --- GET / GET-NEXT / GET-BULK / SET -------> | (UDP 161)
          | <-- GET-RESPONSE --------------------------- |
          |                                              |
          | <-- TRAP (Unacknowledged) ------------------ | (UDP 162)
          |                                              |
          | <-- INFORM-REQUEST (Acknowledged) ---------- | (UDP 162)
          | --- RESPONSE (ACK) ------------------------> |
```

### 1. SNMPv3 の二大コアモデル (USM ＆ VACM)

SNMPv3 は、SNMPv1/v2c の脆弱なコミュニティ認証を脱却するため、以下の 2 つのセキュリティ構造を採用している。

* **USM (User-Based Security Model - RFC 3414):**
  * **ユーザー認証 (Authentication):** HMAC-MD5-96 または HMAC-SHA-96 (SHA-1 / SHA-256) を用いたメッセージ改ざん防止および送信元特定。
  * **データ暗号化 (Privacy/Encryption):** CBC-DES (56-bit), 3DES (168-bit), AES (128/192/256-bit) によるパケット暗号化。
  * **タイムスタンプ ＆ リプレイ攻撃保護:** `snmpEngineBoots` および `snmpEngineTime` により、キャプチャされたパケットの再送攻撃を検知。

* **VACM (View-Based Access Control Model - RFC 3415):**
  * **MIB View (`snmp-server view`):** アクセスを許可/拒否する OID ツリーの範囲を定義（例: `mib-2` 全体、または `ifTable` のみ）。
  * **Group (`snmp-server group`):** セキュリティモデル（v1/v2c/v3）およびセキュリティレベル（`noauth` / `auth` / `priv`）と、Read View / Write View / Notify View をマッピング。
  * **User (`snmp-server user`):** 特定のグループに所属し、認証パスワード（`auth`）および暗号化パスワード（`priv`）を保持する個別のユーザーアカウント。

---

## ⚙ 動作シーケンス

### パケット処理およびセキュリティ検証シーケンス

```
[ NMS (Manager) ]                                   [ Cisco IOS XE (Agent) ]
       |                                                       |
       | ------ 1. SNMPv3 Request Packet (UDP 161) ----------->|
       |    (EngineID, Username, Digest, Encrypted PDU)        |
       |                                                       |
       |                                         +-------------+-------------+
       |                                         | 2. EngineID ＆ User 検証   |
       |                                         | 3. Digest 解凍・HMAC 検証   |
       |                                         | 4. AES 解読 (Privacy Check) |
       |                                         | 5. VACM View 権限チェック   |
       |                                         +-------------+-------------+
       |                                                       |
       | <----- 6. SNMPv3 Response Packet (UDP 161) -----------|
       |    (Encrypted PDU, Auth Digest)                        |
```

1. **NMS からのメッセージ送出:** NMS はローカル EngineID、ユーザー名、HMAC 認証ダイジェスト、および暗号化された PDU（Protocol Data Unit）を含む UDP 161 パケットを送出。
2. **EngineID ＆ ユーザー判定:** IOS XE の SNMP エージェントは、受信パケットの `EngineID` および `Username` をテーブルと照合。
3. **認証 (Authentication) チェック:** 指定されたハッシュアルゴリズム（SHA/MD5）と共有パスワードを用いて HMAC ダイジェストを計算し、一致しない場合はパケットを棄却（`Authentication failure` カウントアップ）。
4. **暗号解読 (Privacy/Decrypt):** `priv` レベルの場合、AES/DES 鍵を用いて PDU ヘッダーおよびデータを復号。
5. **アクセス制御 (VACM Check):** ユーザーが属するグループの `read` または `write` MIB View に、要求された OID が含まれているかを検証。
6. **応答返信:** 要求された MIB 情報を暗号化・認証ダイジェスト付与の上、NMS 宛てに返信。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE Enterprise Infrastructure ラボ試験において、SNMP は単なる基本設定にとどまらず、**制限事項をクリアする正確な構文理解** や **他技術（VRF, ISE, CoPP, Control Plane）との結合** が出題される。

### 1. Blueprint における最重要ポイント
* **SNMPv3 AuthPriv 完全構成:** `snmp-server view`, `snmp-server group`, `snmp-server user` の正確なコマンドチェーン。
* **Traps vs Informs の使い分け:** 承認確認（ACK）が必要な「Informs」と、一方的な通知である「Traps」の引数・挙動の差異。
* **VRF-Aware SNMP:** Out-of-Band 管理網（`Mgmt-vrf`）や MPLS L3VPN VRF（`cust-one`）を経由する SNMP トラップ送信（`snmp-server host ... vrf <VRF>`）および Context-Based 監視。
* **CoPP (Control Plane Policing) との結合:** CoPP ポリシー配下で SNMP (UDP 161/162) が過剰にドロップされないための MQC ポリシング設計。

### 2. よくある設定ミス ＆ ハマりポイント
* **`show running-config` に `snmp-server user` が表示されない:**
  * **落とし穴:** `snmp-server user` コマンドで設定したユーザー情報（パスワードハッシュ）はセキュリティ上 `show running-config` には出力されない。
  * **確認手順:** 必ず `show snmp user` コマンドで検証しなければならない。
* **EngineID のミスマッチによる SNMPv3 認証失敗:**
  * ユーザー設定（`snmp-server user`）を行った後に `snmp-server engineID local` を変更すると、既存ユーザーの内部暗号化ハッシュが無効化され、SNMPv3 通信が全滅する。
  * **対策:** EngineID を手動指定する場合は、必ず `snmp-server user` の設定 **前** に定義する。
* **Informs 設定時の `version 3` キーワード階層:**
  * `snmp-server host 10.1.1.1 informs version 3 priv <USERNAME>` のように、`informs` キーワードの位置を間違えると `traps` として登録されてしまう。

### 3. debug ログ ＆ show コマンドからの状態判断
* **`show snmp user`:** ユーザー名、所属グループ、EngineID、Authentication Protocol (SHA/MD5)、Privacy Protocol (AES/3DES/DES) のステータス確認。
* **`show snmp group`:** グループごとの Security Model (v1/v2c/v3)、Security Level (noauth/auth/priv)、Read/Write/Notify View の割り当て状態。
* **`debug snmp packet`:** SNMP パケットの受信・送信、コミュニティ不一致、認証エラーのリアルタイム検証。


---

## 🛠 設定方法

### 1. SNMPv2c 基本構成 (ReadOnly / ReadWrite ＋ ACL 制限)

```bash
! 1. 許可する NMS サーバーを指定する ACL の作成
ip access-list standard ACL_SNMP_NMS
 permit 192.168.10.100
 permit 192.168.10.101
 deny   any log

! 2. RO (Read-Only) および RW (Read-Write) コミュニティ文字列の設定 (ACL バインド)
snmp-server community READ_SECRET RO ACL_SNMP_NMS
snmp-server community WRITE_SECRET RW ACL_SNMP_NMS

! 3. システム基本情報 (Location / Contact) の設定
snmp-server location DataCenter-Rack-12
snmp-server contact Admin-Team <admin@example.com>
```

### 2. SNMPv3 AuthPriv 完全構築 (USM / VACM)

```bash
! 1. 制限付き MIB View の定義 (mib-2 全体を包含)
snmp-server view VIEW_LIMITED mib-2 included
snmp-server view VIEW_LIMITED cisco included

! 2. SNMPv3 AuthPriv グループの定義 (Read / Write View のマッピング)
snmp-server group GROUP_ADMIN v3 priv read VIEW_LIMITED write VIEW_LIMITED

! 3. AuthPriv ユーザーの作成 (SHA 認証 ＋ AES128 暗号化)
! ※ コマンド構文: snmp-server user <USER> <GROUP> v3 auth <sha|md5> <AUTH_PW> priv <aes|3des|des> [128|192|256] <PRIV_PW>
snmp-server user USER_SECURE GROUP_ADMIN v3 auth sha AuthPass123! priv aes 128 PrivPass456!

! 4. SNMPv3 Inform (承認付き通知) 送信先の設定
snmp-server host 192.168.10.100 informs version 3 priv USER_SECURE config syslog
snmp-server enable traps config
snmp-server enable traps syslog
```

### 3. VRF-Aware SNMP 通知構成 (Management VRF)

```bash
! Out-of-Band 管理 VRF (Mgmt-vrf) 経由で SNMP トラップを送信
snmp-server host 10.255.0.50 vrf Mgmt-vrf version 2c READ_SECRET syslog
snmp-server trap-source GigabitEthernet0/0
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 主な確認項目 |
| :--- | :--- | :--- |
| **SNMP 全般の統計** | <code>show snmp</code> | 入出力パケット数、不正コミュニティ試行数（`Illegal community`）、ドロップ数 |
| **SNMP ユーザー確認** | <code>show snmp user</code> | 定義されている v3 ユーザー名、EngineID、Authentication / Privacy プロトコル種別 |
| **SNMP グループ確認** | <code>show snmp group</code> | グループ名、Security Model (v1/v2c/v3)、Security Level (noauth/auth/priv)、View |
| **SNMP 通知ホスト** | <code>show snmp host</code> | Trap/Inform 送信先 IP、UDP ポート（162）、Security Level、対象通知タイプ |
| **EngineID 確認** | <code>show snmp engineID</code> | ローカルデバイスの 24 バイト 16 進数 EngineID |
| **デバッグ実行** | <code>debug snmp packet</code> | 受送信される全 SNMP UDP パケットのヘッダー・PDU 解読ログ |
| **認証デバッグ** | <code>debug snmp authentication</code> | コミュニティ文字列不一致や v3 USM HMAC 認証失敗のリアルタイムログ |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **NMS からの GET 応答なし (Timeout)** | NMS の IP が `snmp-server community` バインド ACL に拒否されている | <code>show ip access-lists</code><br><code>show snmp</code> | ACL 内に NMS の IP アドレス（`permit host <NMS_IP>`）を追加 |
| **SNMPv3 通信全滅 (`Unknown user`)** | ユーザー作成後に `snmp-server engineID` を変更したためハッシュ不一致 | <code>show snmp user</code><br><code>debug snmp authentication</code> | `no snmp-server user` でユーザーを削除後、再設定して EngineID とハッシュを再同期 |
| **`show running-config` にユーザーが無い** | IOS XE の仕様（セキュリティ保護のため running-config に未出力） | <code>show snmp user</code> | 正常な仕様。構成確認は `show snmp user` で実施する |
| **Informs 通知が届かない** | NMS 側で UDP 162 承認レスポンス (ACK) を返していない | <code>show snmp pending</code><br><code>debug snmp packet</code> | NMS 側のファイアウォール・受信設定を確認し、承認応答を返信させる |
| **VRF 経由の Trap 送信失敗** | `snmp-server host` に `vrf` キーワードが欠落している | <code>show run \| sec snmp</code> | `snmp-server host <IP> vrf <VRF_NAME>` を明示的に指定 |

---

## ⚠ 制限事項

* **SNMPv1 の非推奨化:** SNMPv1 は Informs、Bulk Retrieval、および 64-bit カウンタ（`ifHCInOctets` 等）をサポートしない。
* **StackWise 構成における EngineID 変動:** Catalyst スイッチスタックにおいてアクティブスイッチが入れ替わった際、手動で EngineID を固定（`snmp-server engineID local`）していない場合、EngineID が変化して SNMPv3 認証が失敗することがある。
* **暗号化アルゴリズム互換性:** Cisco IOS XE 17.11.1 以降、弱い暗号（DES, 3DES）はデフォルトで拒否されるため、AES（`aes 128` / `aes 256`）の使用が強く推奨される。

---

## 🔄 他技術との関連

* **Control Plane Policing (CoPP):** CoPP を有効化する場合、NMS からの Polling 通信（UDP 161）および Agent からの Notifications 通信（UDP 162）を拒否・厳しすぎるポリシングでドロップしないよう、CoPP ACL で `permit udp any any eq snmp` / `snmp-trap` を定義する必要がある。
* **Cisco ISE / DNA Center 連携:** Cisco ISE の Profiling 機能（SNMP Query Probe）や DNA Center の Discovery 機能では、RO / RW コミュニティ文字列および SNMPv3 クレデンシャルを双方向で厳密に一致させる必要がある。
* **VRF / MPLS L3VPN:** Context-Based SNMP（`snmp-server context` / `snmp mib community-map`）を利用することで、マルチテナント環境において特定の VRF RIB / MIB 情報のみをテナント専用 NMS へ開示可能。

---

## 🧩 比較表

### 1. SNMP バージョン別機能比較

| 機能 / バージョン | SNMPv1 | SNMPv2c | SNMPv3 |
| :--- | :--- | :--- | :--- |
| **認証方式** | コミュニティ文字列 (平文) | コミュニティ文字列 (平文) | USM ユーザー名 ＋ HMAC (SHA/MD5) |
| **暗号化** | 未対応 (None) | 未対応 (None) | AES (128/192/256), 3DES, DES |
| **64-bit カウンタ** | 非対応 (32-bit のみ) | 対応 (`ifHCInOctets` 等) | 対応 |
| **Bulk 取得** | 非対応 (GET-NEXT のみ) | 対応 (`GetBulkRequest`) | 対応 |
| **Inform 通知** | 非対応 | 対応 (ACK 肯定応答) | 対応 (ACK 肯定応答) |
| **アクセス制御** | コミュニティ ＋ IP ACL | コミュニティ ＋ IP ACL | VACM (Group, View, User) |

### 2. Traps vs Informs

| 項目 | SNMP Traps | SNMP Informs |
| :--- | :--- | :--- |
| **信頼性** | ベストエフォート (UDP 162, 送りっぱなし) | 確実 (NMS からの ACK 返信を要求) |
| **再送メカニズム** | なし | あり (`snmp-server inform retries <COUNT>`) |
| **ネットワーク負荷** | 非常に低い | やや高い (ACK パケット往復が発生) |
| **主な用途** | 頻繁に発生するインターフェイスイベント等 | 重大アラート、構成変更ログ、ライセンス通知 |

---

## 💡 ベストプラクティス

1. **SNMPv3 AuthPriv の標準化:** 本番環境ではプレーンテキストの v1/v2c を全廃し、SHA 認証 ＋ AES-128/256 暗号化を適用した SNMPv3 を使用する。
2. **IP ACL によるアクセス制限の二重化:** コミュニティ文字列や v3 ユーザー設定には、必ず NMS サーバーの IP アドレスを厳密に制限する ACL（`snmp-server community <NAME> ro <ACL>` / `snmp-server user <USER> <GROUP> v3 access <ACL>`）をバインドする。
3. **EngineID の手動固定:** Catalyst スタック構成や冗長化構成では、`snmp-server engineID local <HEX>` を手動定義してスタックフェイルオーバー時のミスマッチを防ぐ。
4. **管理専用 VRF の利用:** SNMP パケットの送受信はデータプレーンから分離された Out-of-Band 管理網（`Mgmt-vrf`）を経由させ、ソースインターフェイス（`snmp-server trap-source`）を明示指定する。


---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: SNMPv2c Read-Only ＋ アクセスリスト保護構成

* **問題:** スイッチ SW1 において、特定管理サーバー (192.168.10.50) からの SNMPv2c による情報取得 (Polling) のみを許可せよ。
* **要件:**
  * コミュニティ文字列は `CiscoROPass` とする。
  * 192.168.10.50 以外の IP アドレスからの SNMP 通信は一切ブロックせよ。
  * 拒否された通信は Syslog ログへ記録すること。
* **設定例:**
```bash
! 1. 許可する NMS サーバーを規定する ACL の作成
ip access-list standard ACL_SNMP_PERMIT
 permit host 192.168.10.50
 deny   any log

! 2. RO コミュニティと ACL のバインド
snmp-server community CiscoROPass RO ACL_SNMP_PERMIT
```
* **検証方法:**
  * NMS (192.168.10.50) から `snmpwalk -v2c -c CiscoROPass 192.168.10.1 sysUpTime` を実行し、正常に応答が返ることを確認。
  * 未許可端末 (192.168.10.99) から同コマンドを実行し、タイムアウトすることを確認。
  * `show ip access-lists ACL_SNMP_PERMIT` で deny カウンタが増加していることを確認。

---

### ラボ 2: SNMPv3 AuthPriv (SHA ＋ AES128) 完全セキュリティ構成

* **問題:** ルータ R1 において、最高位のセキュリティレベル (AuthPriv) で SNMPv3 を有効化せよ。
* **要件:**
  * グループ名: `GRP_SECURE`
  * ユーザー名: `ADMIN_USER`
  * 認証アルゴリズム: `SHA` (パスワード: `AuthKey123!`)
  * 暗号化アルゴリズム: `AES 128` (パスワード: `PrivKey456!`)
  * `mib-2` ツリー全体へのアクセスを許可すること。
* **設定例:**
```bash
! 1. MIB View の定義
snmp-server view VIEW_ALL mib-2 included

! 2. AuthPriv グループの定義
snmp-server group GRP_SECURE v3 priv read VIEW_ALL write VIEW_ALL

! 3. AuthPriv ユーザーの作成
snmp-server user ADMIN_USER GRP_SECURE v3 auth sha AuthKey123! priv aes 128 PrivKey456!
```
* **検証方法:**
  * NMS から `snmpwalk -v3 -l authPriv -u ADMIN_USER -a SHA -A AuthKey123! -x AES -X PrivKey456! 192.168.10.1 mib-2` を実行し、正常取得を確認。
  * `show snmp user` を実行し、ユーザー名 `ADMIN_USER`、Authentication Protocol: SHA、Privacy Protocol: AES128 となっていることを確認。

---

### ラボ 3: MIB View による特定 OID ツリー (ifTable) 限定開示構成

* **問題:** ルータ R1 において、外部監視業者用ユーザーに対し、インターフェイス情報 (`ifTable`) のみの閲覧を許可せよ。
* **要件:**
  * MIB View 名: `VIEW_IF_ONLY`
  * 開示 OID: `interfaces` (1.3.6.1.2.1.2)
  * グループ名: `GRP_MONITOR` (v3 auth)
  * ユーザー名: `USER_MON` (認証: SHA / `MonPass789!`)
* **設定例:**
```bash
! 1. ifTable のみを包含する MIB View の定義
snmp-server view VIEW_IF_ONLY interfaces included

! 2. グループへの View 割り当て
snmp-server group GRP_MONITOR v3 auth read VIEW_IF_ONLY

! 3. ユーザーの作成
snmp-server user USER_MON GRP_MONITOR v3 auth sha MonPass789!
```
* **検証方法:**
  * NMS から `ifTable` (1.3.6.1.2.1.2) 宛てに `snmpwalk` を実行し、正常に取得できることを確認。
  * NMS から `system` (1.3.6.1.2.1.1) 宛てに `snmpwalk` を実行し、エラーまたは Null が返ることを確認。

---

### ラボ 4: SNMP Inform (承認付き通知) ＆ 再送タイマー構成

* **問題:** スイッチ SW1 において、構成変更が発生した際に NMS (192.168.10.100) 宛てに確実な Inform 通知を送信せよ。
* **要件:**
  * 承認パケット (ACK) が返らない場合、再送回数を 5 回、タイマー間隔を 10 秒に設定せよ。
  * 通知タイプ: `config` (構成変更トラップ)
  * コミュニティ: `InformPass` (v2c)
* **設定例:**
```bash
! 1. Inform 通知先の設定
snmp-server host 192.168.10.100 informs version 2c InformPass config

! 2. Config トラップの有効化
snmp-server enable traps config

! 3. Inform 再送パラメータの適用
snmp-server inform retries 5
snmp-server inform timeout 10
```
* **検証方法:**
  * SW1 上で `configure terminal` ➔ `exit` を実行し、構成変更イベントを発生させる。
  * `show snmp pending` で Inform パケットが ACK 待ちキューに入るのを確認。
  * `debug snmp packet` で ACK (Response PDU) の受信ログを確認。

---

### ラボ 5: Management VRF (`Mgmt-vrf`) 経由の Out-of-Band SNMP 通知構成

* **問題:** ルータ R1 において、データプレーンから分離された Out-of-Band 管理網 (VRF: `Mgmt-vrf`) 経由で SNMP トラップを送信せよ。
* **要件:**
  * NMS 宛先: `10.255.0.50` (VRF `Mgmt-vrf`)
  * ソース I/F: `GigabitEthernet0/0` (管理ポート)
  * バージョン: v2c (コミュニティ: `MgmtTrapPass`)
* **設定例:**
```bash
! 1. トラップソースインターフェイスの指定
snmp-server trap-source GigabitEthernet0/0

! 2. VRF を指定した Trap ホストの設定
snmp-server host 10.255.0.50 vrf Mgmt-vrf version 2c MgmtTrapPass
snmp-server enable traps
```
* **検証方法:**
  * `show snmp host` を実行し、`Notification host: 10.255.0.50` の VRF フィールドが `Mgmt-vrf` に設定されていることを確認。
  * 管理ポートをシャットダウン/ノーシャットさせ、`Mgmt-vrf` 経由でパケットが出力されることを確認。

---

### ラボ 6: Control Plane Policing (CoPP) 環境下における SNMP (UDP 161/162) 保護構成

* **問題:** ルータ R1 において CoPP が有効化されている。NMS (192.168.10.100) からの SNMP 監視トラフィックが CoPP のポリシングによりドロップされないよう優先保護せよ。
* **要件:**
  * クラスマップ名: `CM_SNMP`
  * 宛先/送信元 UDP ポート 161, 162 を許可する ACL を作成すること。
  * CoPP ポリシーマップ `PM_COPP` 内で 1Mbps の帯域を保証制限すること。
* **設定例:**
```bash
! 1. SNMP トラフィック識別用 ACL の作成
ip access-list extended ACL_SNMP_TRAFFIC
 permit udp host 192.168.10.100 any eq snmp
 permit udp host 192.168.10.100 any eq snmp-trap
 permit udp any host 192.168.10.100 eq snmp-trap

! 2. Class-Map の作成
class-map match-all CM_SNMP
 match access-group name ACL_SNMP_TRAFFIC

! 3. Policy-Map の設定
policy-map PM_COPP
 class CM_SNMP
  police 1000000 conform-action transmit exceed-action drop

! 4. Control Plane への適用
control-plane
 service-policy input PM_COPP
```
* **検証方法:**
  * NMS から高頻度で Polling を実行し、`show policy-map control-plane` で `CM_SNMP` クラスの `conformed` パケット数が加算され、ドロップが発生していないことを確認。

---

### ラボ 7: EngineID 手動定義 ＋ SNMPv3 リモートユーザー構成

* **問題:** NMS 側で事前に定義された固定 EngineID (`800000090300AABBCC000111`) を使用して、ルータ R1 上に SNMPv3 リモートユーザーを設定せよ。
* **要件:**
  * 手動 EngineID 設定を行うこと。
  * ユーザー名: `REMOTE_USER`
  * グループ: `GRP_REMOTE` (v3 priv)
  * SHA 認証 (`AuthPass999!`) / AES128 暗号化 (`PrivPass888!`)
* **設定例:**
```bash
! 1. ローカル EngineID の手動固定
snmp-server engineID local 800000090300AABBCC000111

! 2. グループおよびユーザーの定義
snmp-server group GRP_REMOTE v3 priv
snmp-server user REMOTE_USER GRP_REMOTE v3 auth sha AuthPass999! priv aes 128 PrivPass888!
```
* **検証方法:**
  * `show snmp engineID` を実行し、Local engine ID が `800000090300AABBCC000111` であることを確認。
  * `show snmp user` で `Engine ID: 800000090300AABBCC000111` として登録されていることを確認。

---

### ラボ 8: Context-Based SNMP over MPLS L3VPN (VRF Context Mapping)

* **問題:** PE ルータにおいて、VPN 顧客 `cust-one` が自社 VRF のルーティングテーブル情報のみを SNMP 経由で取得できるよう Context マッピングを設定せよ。
* **要件:**
  * VRF 名: `cust-one`
  * コンテキスト名: `context-cust-one`
  * コミュニティ名: `comm-cust-one`
* **設定例:**
```bash
! 1. VRF 定義と Context のバインド
ip vrf cust-one
 rd 1:1
 route-target export 1:1
 route-target import 1:1
 context context-cust-one

! 2. Context 用 MIB View とグループの設定
snmp-server view VIEW_VRF ipForward included
snmp-server group GRP_VRF v2c context context-cust-one read VIEW_VRF

! 3. コミュニティと Context マッピング
snmp-server community comm-cust-one RO
snmp mib community-map comm-cust-one context context-cust-one target-list LIST_CUST_ONE
snmp mib target list LIST_CUST_ONE vrf cust-one
```
* **検証方法:**
  * 顧客網内の NMS から `snmpwalk -v2c -c comm-cust-one <PE_VRF_IP> ipCidrRouteEntry` を実行し、`cust-one` のルーティングテーブルのみが返ることを確認。

---

### ラボ 9: Cisco ISE 用 SNMP Query Probe / Trap Probe 連携構成

* **問題:** 認証サーバー Cisco ISE (192.168.1.250) がスイッチ SW1 から MAC 移動トラップおよび CDP/LLDP 情報を自動収集できるよう SNMP を構成せよ。
* **要件:**
  * 読み取りコミュニティ: `ISE_RO_PASS`
  * MAC 移動トラップ (`mac-notification`) を有効化すること。
  * Trap 送信先: `192.168.1.250`
* **設定例:**
```bash
! 1. RO コミュニティの設定
snmp-server community ISE_RO_PASS RO

! 2. MAC Notification トラップの有効化
mac address-table notification change
snmp-server enable traps mac-notification change

! 3. ISE 宛て Trap 送信先の設定
snmp-server host 192.168.1.250 version 2c ISE_RO_PASS mac-notification
```
* **検証方法:**
  * ポートで端末を抜き差しし、`show mac address-table notification change` でトラップが送信されたことを確認。

---

### ラボ 10: Syslog イベントの SNMP Inform 変換送信構成

* **問題:** ルータ R1 の重大な Syslog メッセージ (Warnings 以上) を、Syslog パケットではなく確認応答付き SNMP Inform パケットに変換して NMS (192.168.10.100) へ送信せよ。
* **要件:**
  * ログレベル: `warnings` (Level 4) 以上
  * バージョン: SNMPv3 AuthPriv (`USER_SECURE`)
* **設定例:**
```bash
! 1. Syslog 履歴レベルの設定
logging history warnings

! 2. Syslog トラップの有効化
snmp-server enable traps syslog

! 3. Inform 送信先の設定
snmp-server host 192.168.10.100 informs version 3 priv USER_SECURE syslog
```
* **検証方法:**
  * インターフェイスを `shutdown` させて Warning ログを発生させ、`show logging history` で履歴が保持され、`show snmp host` で Inform が発信されたことを確認。


---

## ❓ 想定試験問題

### 問 1 (トラブルシューティング)
**シナリオ:** 管理者がルータ R1 上で SNMPv3 AuthPriv ユーザー `user1` を作成し、NMS から Polling を試みたところ `Unknown user` エラーで失敗した。設定を確認すると、ユーザー作成後にセキュリティ要件で `snmp-server engineID local 1234567890ABCDEF` を追加していた。
**設問:** 通信が失敗した根本原因と、R1 上で実行すべき修正手順を答えよ。

* **解答:**
  * **根本原因:** `snmp-server engineID local` を設定したことでローカル EngineID が変更され、以前の EngineID を基に生成された `user1` の内部ハッシュが無効化したため。
  * **修正手順:**
    1. `no snmp-server user user1 GRP_SECURE v3` で不整合を起こしているユーザーを削除する。
    2. 固定した EngineID の下で、再度 `snmp-server user user1 GRP_SECURE v3 auth sha AuthPass123! priv aes 128 PrivPass456!` を実行してハッシュを再生成・同期させる。

---

### 問 2 (コンフィグ読解)
**シナリオ:** 以下のコンフィグが適用されたスイッチ SW1 がある。
```bash
snmp-server view V_SECRET system included
snmp-server view V_SECRET ifTable excluded
snmp-server group G_SEC v3 priv read V_SECRET
snmp-server user U_SEC G_SEC v3 auth sha Pass123! priv aes 128 Pass456!
```
**設問:** ユーザー `U_SEC` が NMS から取得できる MIB 情報および取得できない MIB 情報を理由とともに説明せよ。

* **解答:**
  * **取得できる情報:** `system` ツリー (1.3.6.1.2.1.1) 配下の MIB オブジェクト（`sysUpTime`, `sysDescr`, `sysName` 等）。`V_SECRET` で `included` 指定されているため。
  * **取得できない情報:** `ifTable` (1.3.6.1.2.1.2.2) 配下のインターフェイス統計情報、および `system` 以外のすべての MIB オブジェクト。`ifTable` は明示的に `excluded` されており、また指定されていない OID は VACM の仕様によりデフォルトで拒否されるため。

---

### 問 3 (Design)
**シナリオ:** 5,000 台の機器を管理する大規模網において、構成変更通知およびライセンス通知を確実に NMS へ届ける管理設計を検討している。通知方式（Traps vs Informs）およびプロトコルバージョンを選定し、その理由を述べよ。

* **解答:**
  * **選定方式:** **SNMPv3 Informs (authPriv)**
  * **理由:**
    1. 構成変更は重要イベントであり、ACK 肯定応答および再送メカニズムを持つ **Informs** が必須である。
    2. 改ざん・盗聴を防止するため、USM による暗号化・認証を提供する **SNMPv3 authPriv** が不可欠である。

---

### 問 4 (実装)
**シナリオ:** ルータ R1 の Out-of-Band 管理ポート `GigabitEthernet0/0` (IP: 10.255.0.1/24, VRF: `Mgmt-vrf`) から、NMS `10.255.0.100` 宛てに Syslog トラップを送信したい。バージョンは v2c、コミュニティは `TrapMgmt` とする。
**設問:** R1 に設定すべき最小限の SNMP コンフィグを記述せよ。

* **解答:**
```bash
snmp-server trap-source GigabitEthernet0/0
snmp-server enable traps syslog
snmp-server host 10.255.0.100 vrf Mgmt-vrf version 2c TrapMgmt syslog
```

---

### 問 5 (トラブルシューティング)
**シナリオ:** ルータ R1 上で CoPP (Control Plane Policing) を有効化したところ、NMS からの SNMP Polling (UDP 161) が応答しなくなった。
**設問:** 原因と、CoPP パイプライン内で SNMP 通信を救済するためのコンフィグ修正案を示せ。

* **解答:**
  * **原因:** CoPP の ACL に SNMP トラフィック（UDP 161/162）が定義されておらず、`class-default` に分類されてドロップされたため。
  * **修正案:**
```bash
ip access-list extended ACL_COPP_SNMP
 permit udp host 10.255.0.100 host 10.255.0.1 eq snmp

class-map match-all CM_COPP_SNMP
 match access-group name ACL_COPP_SNMP

policy-map PM_COPP
 class CM_COPP_SNMP
  police 1000000 conform-action transmit exceed-action drop
```

---

## 🔗 参考リソース

* Cisco IOS XE 17.x Configuration Guide: Simple Network Management Protocol
* Cisco Command Reference: snmp-server host
* RFC 3414: User-Based Security Model (USM) for SNMPv3
* RFC 3415: View-Based Access Control Model (VACM) for SNMP
* Cisco Live BRKNMR-2001: Network Management & SNMPv3 Best Practices

---

## 📝 補足（Notes）

* **SNMPv3 USM/VACM 設定フロー:**
```
[ MIB View (OID 制限) ]  --->  [ Group (v3 + Security Level + View マッピング) ]
                                           ^
                                           |
[ User (auth / priv パスワード定義) ] ------+
```
* **注意:** CCIE ラボ試験において `snmp-server user` を設定した際、`show running-config` に表示されないことを「設定が反映されていない」と誤認して何度も再設定しないこと。確認は必ず `show snmp user` で行う。

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


