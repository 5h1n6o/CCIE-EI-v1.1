---
layout: default
title: 4.1-Device-security
parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.1 Device security on Cisco IOS XE

## 📘 概要

Cisco IOS XE におけるデバイスセキュリティ（Device Security）は、ルータやスイッチ自体の管理プレーン（Management Plane）および制御プレーン（Control Plane）を外部および内部の脅威から保護するための包括的なアーキテクチャである。CCIE EI v1.1 ラボ試験において、デバイスセキュリティは単独の単元として出題されるだけでなく、SD-Access、SD-WAN、MPLS、BGP/OSPF 等の全インフラストラクチャの基盤として前提条件的に課される極めて重要な分野である。

本ドキュメントでは、Cisco IOS XE 上で実装される以下のコア技術を網羅し、CCIE EI ラボ試験で即座にコンフィグ作成・検証・トラブルシューティングができるレベルで詳細に整理する。

* **AAA (Authentication, Authorization, Accounting):** TACACS+ および RADIUS プロトコルを用いた集中型アクセス制御とローカルフォールバック。
* **RBAC (Role-Based Access Control) & Privilege Levels:** 権限レベル（Privilege Level 0-15）および Parser Views による粒度の細かいコマンド実行制限。
* **CoPP (Control Plane Policing):** MQC (Modular QoS CLI) を使用した CPU 宛てトラフィック（Routing Protocol, ICMP, Management）のレート制限およびDoS攻撃防御。
* **Secure Management Protocols:** SSHv2, SNMPv3 (AuthNoPriv / AuthPriv), HTTPS (TLS), Syslog (TLS / Logging Source-Interface), NTP Authentication (MD5/SHA) による安全な運用管理。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主要機能** | AAA (TACACS+/RADIUS), CoPP, RBAC / Parser Views, SSHv2, SNMPv3, NTP Authentication |
| **保護対象** | 管理プレーン (Management Plane: SSH/SNMP/Syslog) および 制御プレーン (Control Plane: BGP/OSPF/EIGRP/LDP/ARP) |
| **メリット** | 不正アクセス防止、制御プレーン CPU 高負荷（DoS）防御、監査ログの完全性確保、最小権限の原則適用 |
| **デメリット/リスク** | 設定誤りによる管理アクセスの自己締め出し（Lockout）、CoPP の過剰制限による制御プロトコル（BGP/OSPF等）のフラッピング |
| **対応機種** | Catalyst 9000 シリーズ、ISR 4000 シリーズ、ASR 1000 シリーズ、Catalyst 8000v (IOS XE 17.x) |
| **制限事項** | CoPP は `control-plane` 形式で適用され、特定インターフェイスではなくルータ全体の CPU トラフィックを保護する |
| **設計上の注意点** | AAA サーバ不可障害対策としての `local` フォールバック必須化、CoPP での分散型・集中型制御パケットの誤破棄防止 |

---

## 🏗 動作原理

### 1. AAA (TACACS+ vs RADIUS) アーキテクチャ

* **TACACS+ (TCP 49):** Cisco 独自プロトコル。ヘッダーを除くパケット全体を暗号化。**Authentication（認証）、Authorization（認可）、Accounting（課金・ログ）が完全に分離**されており、コマンド単位での認可（Command Authorization）に最適。
* **RADIUS (UDP 1812/1813 または 1645/1646):** IETF 標準プロトコル。パスワード部分のみを暗号化。Authentication と Authorization が結合しており、ネットワークアクセス制御（802.1X / MAB / SD-Access）に標準使用される。

```
[ Admin User ] 
      │ (1) SSH / Console Connection
      ▼
[ Cisco IOS XE Router ] ──(2) TACACS+ Request (TCP 49)──► [ Cisco ISE / TACACS+ Server ]
      │                                                           │
      │◄──(3) TACACS+ Accept + Privilege Level 15 / Permitted ───┘
      │
      │ (4) CLI Command Execution (e.g., 'configure terminal')
      │──(5) Command Authorization Request ──────────────────────► [ Cisco ISE ]
      │◄──(6) Command Permit / Deny ──────────────────────────────┘
```

### 2. Control Plane Policing (CoPP) 動作モデル

CoPP は、データプレーンを通過（Transit）するトラフィックではなく、ルータ自身の **CPU 宛てトラフィック（Punt Traffic / Control Plane）** を MQC (Class-Map / Policy-Map) で分類・制限する。

```
[ Incoming Packets ]
      │
      ├── Transit Traffic ─────────► [ CEF Forwarding Engine ] ──► [ Egress Interface ]
      │
      └── Punt Traffic (CPU 宛) ──► [ Control Plane Interface ]
                                          │
                                          ▼
                                   [ CoPP Policy-Map ]
                                          │
                                    ├── Class GOLD (Routing Protocols) ─► [ Permit / High Rate ] ─► [ Route Engine CPU ]
                                    ├── Class SILVER (SSH / Management) ─► [ Police Rate-Limit ]  ─► [ Management CPU ]
                                    └── Class BRONZE / DEFAULT (ICMP) ──► [ Strict Rate-Limit ] ─► [ Drop Excess ]
```

---

## ⚙ 動作シーケンス

### AAA ログイン ＆ コマンド認可シーケンス

1. **ユーザ接続:** 管理者が SSH または Console 経由で IOS XE にログインを開始。
2. **AAA 認証要求 (Authentication):** IOS XE は定義された `aaa authentication login` グループ（TACACS+ サーバ群）に認証要求を送信。
3. **TACACS+ サーバ応答:** ISE / TACACS+ サーバがクレデンシャルを検証し、成功時に Privilege Level 15 や属性を返送。
4. **ローカルフォールバック判断:** TACACS+ サーバ群が応答なし（Timeout / Server Dead）の場合、`local` 認証へフォールバック。
5. **コマンド認可要求 (Authorization):** ユーザが CLI コマンド（例: `show running-config`）を入力する度に、IOS XE は `aaa authorization commands` に基づき TACACS+ サーバへ個別コマンドの実行可否を照会。
6. **Accounting 記録:** コマンド実行完了後、`aaa accounting commands` により実行履歴（日時、ユーザ、コマンド文字列、送信元 IP）が TACACS+ サーバへ送付されログ保存。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprint で重要なポイント
* **AAA グループのフォールバック設定:** TACACS+ サーバ応答不能時に Console や SSH が完全に遮断されないよう、`group tacacs+ local` の適切な構成。
* **CoPP での過剰ドロップ回避:** BGP, OSPF, EIGRP, LDP, BFD, ICMP, SSH 等のクラス分類ミスによる制御プロトコル切断の防止。
* **Parser Views (RBAC) の手動構築:** `enable view` を使用した特定コマンド群のみを許可する最小権限ビューの設定。
* **NTP Authentication & Logging:** タイムスタンプの整合性を保つための NTP MD5 認証および Logging Source-Interface の固定。

### 2. ラボ試験で狙われやすい制限事項 ＆ よくある設定ミス
* **`aaa new-model` の未有効化:** これを設定せずに `aaa authentication` を投入しても AAA は機能しない。
* **TACACS+ シングルコネクションの未設定:** 大量コマンド認可時に TCP 接続がオーバーヘッドとなるため、`ip tacacs source-interface` および `single-connection` の適用が求められる場合がある。
* **CoPP での `class-default` 絞り込み過ぎ:** `class-default` で過剰な `police` を適用すると、未分類の制御パケット（ARP や ICMP）が破棄され、隣接関係が崩壊する。
* **SSH 鍵未生成:** `crypto key generate rsa modulus 2048` を実行しないと SSHv2 サービスが起動しない。

## 🛠 設定方法

### 1. AAA & TACACS+ / RADIUS 集中型認証・認可・課金設定

```bash
! AAA の有効化
aaa new-model

! TACACS+ サーバ定義 (IOS XE 16.x / 17.x 構文)
tacacs server ISE_TACACS_1
 address ipv4 10.1.100.11
 key 0 Cisco123Secret
 single-connection
!
tacacs server ISE_TACACS_2
 address ipv4 10.1.100.12
 key 0 Cisco123Secret
 single-connection

! TACACS+ サーバグループの作成
aaa group server tacacs+ TAC_GROUP
 server name ISE_TACACS_1
 server name ISE_TACACS_2
 ip tacacs source-interface Loopback0

! AAA Authentication (ログイン認証)
aaa authentication login default group TAC_GROUP local
aaa authentication login CONSOLE local

! AAA Authorization (コマンド認可)
aaa authorization exec default group TAC_GROUP local 
aaa authorization commands 15 default group TAC_GROUP local 

! AAA Accounting (操作ログ記録)
aaa accounting exec default start-stop group TAC_GROUP
aaa accounting commands 15 default start-stop group TAC_GROUP

! VTY ラインへの適用
line vty 0 15
 exec-timeout 10 0
 transport input ssh
 login authentication default
```

### 2. Control Plane Policing (CoPP) 完全コンフィグ例

```bash
! 1. 制御プロトコル用 ACL の定義
ip access-list extended ACL_CRITICAL_CONTROL
 permit ospf any any
 permit eigrp any any
 permit tcp any eq bgp any
 permit tcp any any eq bgp
 permit udp any eq 646 any
 permit udp any any eq 646

ip access-list extended ACL_MANAGEMENT
 permit tcp 10.1.0.0 0.0.255.255 any eq 22
 permit udp 10.1.0.0 0.0.255.255 any eq 161
 permit icmp any any

! 2. Class-Map の定義
class-map match-any CM_CRITICAL_CONTROL
 match access-group name ACL_CRITICAL_CONTROL
class-map match-any CM_MANAGEMENT
 match access-group name ACL_MANAGEMENT

! 3. Policy-Map の定義と Rate-Limit (Policing)
policy-map PM_COPP
 class CM_CRITICAL_CONTROL
  police 8000000 bc 250000
   conform-action transmit
   exceed-action transmit
 class CM_MANAGEMENT
  police 2000000 bc 62500
   conform-action transmit
   exceed-action drop
 class class-default
  police 1000000 bc 31250
   conform-action transmit
   exceed-action drop

! 4. Control Plane へのポリシー適用
control-plane
 service-policy input PM_COPP
```

### 3. Role-Based Access Control (RBAC / Parser Views) 設定

```bash
! Enable 秘密パスワードと Root View の有効化
enable secret 0 Cisco123Password
aaa new-model
aaa authorization exec default local

! Parser View の定義 (オペレータ用 View)
parser view OPERATOR_VIEW
 password 0 OperatorPass123
 commands exec include show ip route
 commands exec include show ip interface brief
 commands exec include show interfaces
 commands exec include ping
 commands exec include traceroute
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| AAA 状態・統計の確認 | <code>show aaa sessions</code> / <code>show aaa servers</code> |
| TACACS+ サーバ動作状態の確認 | <code>show tacacs</code> |
| RADIUS サーバ動作状態の確認 | <code>show radius statistics</code> |
| CoPP 適用状況・パケットカウンタ確認 | <code>show policy-map control-plane</code> |
| Control Plane 統計の確認 | <code>show control-plane host features</code> |
| Parser View の動作確認 | <code>show parser view</code> |
| SSH 接続状態・バージョンの確認 | <code>show ip ssh</code> / <code>show ssh</code> |
| デバッグ: TACACS+ 認証・認可詳細 | <code>debug tacacs authentication</code> / <code>debug tacacs authorization</code> |
| デバッグ: AAA 認証処理の追跡 | <code>debug aaa authentication</code> / <code>debug aaa authorization</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| TACACS+ サーバ停止時に Console/SSH からログインできない | AAA 設定に `local` フォールバックが欠落している | `show running-config \| section aaa` | `aaa authentication login default group TAC_GROUP local` のように末尾に `local` を追加 |
| CoPP 適用後、OSPF/BGP ネイバーがフラッピングする | CoPP で OSPF/BGP 用 ACL が漏れており `class-default` で破棄された | `show policy-map control-plane` | ACL に OSPF/BGP パケットを明示許可し、Class-Map の分類を修復 |
| TACACS+ 認証時にコマンド認可がタイムアウトして遅延する | `single-connection` が未設定で毎コマンド TCP 接続を生成している | `show tacacs` | `tacacs server` 設定配下に `single-connection` を追加 |
| SSH 接続が拒否され Telnet のみ接続可能になる | SSH 鍵未生成、または `transport input ssh` の不備 | `show ip ssh` | `crypto key generate rsa modulus 2048` を実行し、`line vty` で `transport input ssh` を適用 |
| NTP 同期が失敗しログのタイムスタンプがずれる | NTP Authentication キーの不一致、またはソース I/F 未設定 | `show ntp status` / `show ntp associations` | `ntp authentication-key` と `ntp trusted-key` の一致を確認し `ntp source` を指定 |

## ⚠ 制限事項

* **CoPP での分散型アーキテクチャ制限:** ASR 1000 や Catalyst 9500 等の分散転送プラットフォームでは、CoPP は Line Card (FP/QFP) レベルで分散処理されるため、統計カウンタがプラットフォーム依存となる。
* **TACACS+ vs RADIUS 互換性:** RADIUS ではコマンド単位の認可（Command Authorization）が規格上サポートされないため、CLI コマンドレベルの制御には必ず TACACS+ を使用する。
* **Local Privilege Level 変更制限:** `privilege exec level` コマンドで変更した権限レベルは、AAA 認可ポリシー（TACACS+ 返送値）が存在する場合、TACACS+ 側のポリシーが最優先される。

---

## 🔄 他技術との関連

* **Cisco ISE (Identity Services Engine):** TACACS+ (Device Administration) および RADIUS (802.1X/SD-Access) の集約管理サーバ。
* **Routing Protocols (BGP/OSPF/EIGRP):** CoPP により Hello パケットや Keepalive が保護され、Control Plane DoS 攻撃下でもネイバーを維持。
* **SD-Access / SD-WAN:** ファブリック内ノード（Fabric Edge, Control Plane Node, WAN Edge）の CLI 管理アクセスおよび REST API/NETCONF セキュリティの基盤。
* **SNMPv3 & Syslog:** 管理プレーン暗号化および改ざん防止監査トレイル。

---

## 🧩 比較表

### TACACS+ vs RADIUS

| 項目 | TACACS+ | RADIUS |
| :--- | :--- | :--- |
| **標準規格** | Cisco 独自 (RFC 8907) | IETF オープン標準 (RFC 2865/2866) |
| **トランスポート層** | TCP ポート 49 | UDP ポート 1812/1813 (または 1645/1646) |
| **暗号化範囲** | パケット全体 (ヘッダー除く) | パスワードフィールドのみ |
| **AAA 分離** | 認証・認可・課金が**完全分離** | 認証と認可が**結合** |
| **主要用途** | **デバイス管理 (CLI Command Authorization)** | **ネットワークアクセス制御 (802.1X/MAB/VPN)** |

---

## 💡 ベストプラクティス

1. **AAA Local Fallback の常時確保:** 外部 TACACS+ サーバの障害や IP 疎通不可に備え、必ずローカルユーザ（`username admin secret ...`）と `local` フォールバックを設定する。
2. **CoPP の段階的適用 (Quiet Mode):** 新規 CoPP ポリシー適用時は、いきなり `drop` せず `transmit` またはログ記録でテストし、必要な制御パケットが破棄されていないか確認後にドロップ化する。
3. **SSHv2 への限定:** VTY ラインでは `transport input ssh` を明示指定し、非暗号化の Telnet を完全に無効化する。
4. **NTP Authentication & Source Interface 指定:** タイムスタンプ偽装を防ぐため、全デバイスで NTP MD5 認証を適用し、`ntp source Loopback0` で送信元を固定する。

### 例6: SNMPv3 AuthPriv (SHA + AES128) 構成

* **問題:** 最高レベルのセキュリティ（認証＋暗号化）を提供する SNMPv3 構成を作成せよ。
* **要件:** Group Name: `ADMIN_GROUP`, User Name: `snmpadmin`

```bash
! 設定例
snmp-server group ADMIN_GROUP v3 priv
snmp-server user snmpadmin ADMIN_GROUP v3 auth sha AuthKeyVal priv aes 128 PrivKeyVal
```
* **検証方法:** `show snmp user` を実行し、`Authentication Protocol: SHA`, `Privacy Protocol: AES128` と表示されることを確認。

---

### 例7: Logging Syslog Secure ＆ ソース I/F 指定

* **問題:** Syslog サーバー（10.1.200.50）へ高信頼なログ転送を構成せよ。
* **要件:** Logging Source: `Loopback0`, Trap Level: `informational`

```bash
! 設定例
service timestamps log datetime msec localtime show-timezone
logging host 10.1.200.50
logging source-interface Loopback0
logging trap informational
```
* **検証方法:** インターフェイスの `shutdown` / `no shutdown` を実行し、Syslog サーバにログが転送されることを確認。

---

### 例8: RADIUS デバイス管理認証構成

* **問題:** RADIUS サーバ（10.1.100.20）を使用した Exec ログイン認可を構成せよ。

```bash
! 設定例
aaa new-model
radius server RADIUS_ISE
 address ipv4 10.1.100.20 auth-port 1812 acct-port 1813
 key RadiusKeyVal
!
aaa group server radius RAD_GROUP
 server name RADIUS_ISE
!
aaa authentication login TELNET_RAD group RAD_GROUP local
```
* **検証方法:** `show radius statistics` を実行し、Access-Request パケットが正しく送信されているか確認。

---

### 例9: CoPP による Dynamic Routing (OSPF/BGP) の優先保護

* **問題:** OSPF および BGP トラフィックを最高優先クラスとして CoPP で優先通過させる設定を作成せよ。

```bash
! 設定例
ip access-list extended ACL_ROUTING_PROTO
 permit ospf any any
 permit tcp any eq bgp any
 permit tcp any any eq bgp
!
class-map match-any CM_ROUTING
 match access-group name ACL_ROUTING_PROTO
!
policy-map PM_COPP_ROUTING
 class CM_ROUTING
  police 10000000 bc 312500
   conform-action transmit
   exceed-action transmit
!
control-plane
 service-policy input PM_COPP_ROUTING
```
* **検証方法:** `show policy-map control-plane class CM_ROUTING` でパケットカウントが増加していることを確認。

---

### 例10: Privilege Levels による制限付きユーザー作成 (`privilege` コマンド)

* **問題:** Privilege Level 5 のユーザーを作成し、`show running-config` のみを特別に許可せよ。

```bash
! 設定例
enable secret EnableKeyVal
privilege exec level 5 show running-config
username operator privilege 5 secret OpKeyVal
```
* **検証方法:** ユーザー `operator` でログインし、Level 5 の状態で `show running-config` が実行できることを検証。

---

## ❓ 想定試験問題

### 問1 (コンフィグ読解・トラブルシューティング)
**問題:** 以下のコンフィグを適用したルータにおいて、外部 TACACS+ サーバ（10.1.100.11）が障害でダウンした際、コンソールから `admin` ユーザーでログインしようとしたがアクセスが拒否された。原因と修正方法を答えよ。

```bash
aaa new-model
tacacs server ISE1
 address ipv4 10.1.100.11
 key KeyVal
aaa group server tacacs+ TAC_GRP
 server name ISE1
aaa authentication login default group TAC_GRP
username admin secret AdminKeyVal
```

* **解答・解説:** 
  * **原因:** `aaa authentication login default` の末尾に `local` フォールバック指定が存在しないため、TACACS+ サーバが応答しない場合にローカルデータベースでの検証が行われず拒否される。
  * **修正方法:** コマンドを `aaa authentication login default group TAC_GRP local` に修正する。

---

### 問2 (CoPP トラブルシューティング)
**問題:** CoPP ポリシーを適用後、ルータ間の BFD (Bidirectional Forwarding Detection) セッションがフラッピングし始めた。原因と修正箇所を述べよ。

* **解答・解説:** 
  * **原因:** CoPP の Class-Map において BFD トラフィック (UDP 3784/3785 または 4784) が明示的に許可されておらず、`class-default` の厳格な Policing (Rate-Limit) によって BFD パケットが破棄されたため。
  * **修正方法:** CoPP 用の ACL に `permit udp any any eq 3784` / `permit udp any any eq 3785` を追加し、優先処理クラスに分類する。

---

### 問3 (Design / Security)
**問題:** 大規模企業ネットワークにおいて、CLI コマンドごとの細かな実行認可（Command Authorization）および詳細な監査ログを収集するプロトコルとして TACACS+ と RADIUS のどちらを選択すべきか。理由とともに答えよ。

* **解答・解説:** 
  * **選択:** **TACACS+**
  * **理由:** TACACS+ は Authentication, Authorization, Accounting が完全分離されており、ユーザがコマンドを入力する度に個別の認可リクエスト（Command Authorization）を送信できる。RADIUS は認証と認可が統合されており、CLI コマンド単位の細かな認可制御に対応していないため。

---

### 問4 (SSH / RSA Implementation)
**問題:** IOS XE ルータで `ip ssh version 2` を投入したところ、`% Please generate an RSA key which is at least 768 bits long.` というエラーが表示された。必須の前提設定を答えよ。

* **解答・解説:** 
  * **原因:** SSH 鍵の暗号化ドメイン名（`ip domain name`）が未設定、または RSA 鍵ペア（`crypto key generate rsa`）が未生成であるため。
  * **手順:** 
    1. `ip domain name <domain-name>` を設定する。
    2. `crypto key generate rsa modulus 2048` を実行して RSA 鍵ペアを生成する。

---

### 問5 (Parser Views / RBAC)
**問題:** Parser View 機能を使用してカスタムビューを作成する際、前提として有効化しなければならない CLI 機能は何か。

* **解答・解説:** 
  * **前提機能:** **`aaa new-model`** および **`enable secret`** の設定。Parser View は AAA 統合基盤上で動作し、ビューの切り替えには `enable secret` が設定されている必要がある。

---

## 🔗 参考リソース

* Cisco IOS XE 17.x Security Configuration Guide: AAA System Security
* Cisco Technical Note: Control Plane Policing (CoPP) Best Practices
* Cisco IOS XE Command Reference: AAA Commands
* Cisco Live: BRKSEC-2003 - Securing Cisco IOS XE Control and Management Plane

---

## 📝 補足（Notes）

* **CCIE ラボ試験での注意点:** ラボ試験では AAA 集中設定後に必ず「TACACS+ サーバへの到達性を遮断した状態（または擬似障害）」でコンソールログインが成功するか（`local` フォールバック動作）を自身でテストすること。
* **CoPP の安全な構築:** ラボ問題で CoPP の構成が指示された場合、まずは ACL と Class-Map を作成し、`show policy-map control-plane` で想定通りのパケットがマッチしているか確認してから `drop` アクションを確定させると安全である。
