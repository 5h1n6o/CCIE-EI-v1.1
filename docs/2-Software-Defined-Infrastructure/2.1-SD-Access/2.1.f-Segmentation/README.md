---
layout: default
title: 2.1.f-Segmentation
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 6
---

# 2.1.f Segmentation

---

## 📘 概要

Cisco SD-Access (Software-Defined Access) における**セグメンテーション（Segmentation）**は、ネットワークのセキュリティ強化、アクセス制御、およびコンプライアンス維持を実現するための核となるアーキテクチャ機能です。

SD-Access では、セグメンテーションを以下の 2 つの階層で統合的に実装します。

1. **マクロセグメンテーション（Macro-level Segmentation / Virtual Networks）:**
   * **仮想ネットワーク（Virtual Network: VN）**を用いて、L3（ルーティングテーブル / VRF）単位でネットワークを論理的に完全分離します。
   * 例えば、「社内（Corp_VN）」、「ゲスト（Guest_VN）」、「IoT機器（IoT_VN）」などの部門・用途ごとに独立した L3 仮想網を定義し、VN 間の直接通信を物理的・論理的に遮断します。
   * VN 間の通信（Inter-VN Routing）を許可する場合は、ファブリック外のフュージョンルータ（Fusion Router）や次世代ファイアウォール（NGFW）を経由させ、明示的なポリシー制御と検査を行います。

2. **マイクロセグメンテーション（Micro-level Segmentation / SGTs & SGACLs）:**
   * Cisco TrustSec（CTS）の技術を統合し、同一 VN 内（または VN を越えたロール単位）のエンドポイントに対して **SGT（Security Group Tag: 16-bit）** を割り当てます。
   * IP アドレスや VLAN ID に依存せず、「ユーザーの役割（従業員、契約社員、IPカメラ、医療機器等）」に基づいてグループ化します。
   * **SGACL（Security Group Access Control List）**を適用することで、同一 VN 内の端末同士の通信（例：営業部端末から経理部端末へのアクセス制限、IoTカメラ同士の横展開攻撃の遮断）を、送信元・宛先の SGT の組み合わせマトリクスに基づいて高精度に制御します。

---

## 🔑 要点

| 項目 | マクロセグメンテーション (Macro) | マイクロセグメンテーション (Micro) |
| :--- | :--- | :--- |
| **制御階層** | L3 ルーティングテーブル（VRF / VN）単位 | エンドポイント（SGT / ロール）単位 |
| **実装技術** | LISP Instance ID, VRF-Lite, VXLAN VNI | Security Group Tag (SGT), SGACL, CTS |
| **識別子** | Layer 3 VN ID (VRF) / L2 VNI (VLAN) | 16-bit Security Group Tag (1-65535) |
| **データ面でのカプセル化** | VXLAN VNI (Header VNI フィールド) | VXLAN-GPO Header (16-bit SGT フィールド) |
| **ポリシープッシュ / 管理** | Cisco Catalyst Center (DNAC) VN 定義 | Cisco ISE (Identity Services Engine) マトリクス |
| **エンフォースメント位置** | Fabric Border / Fusion Router / Firewall | Egress Fabric Edge (受信側ファブリックエッジ) |
| **主な用途** | 組織別・用途別のネットワーク完全孤立化 | 同一グループ・部門内での最小権限アクセス制御 |
| **制限事項・注意点** | Inter-VN 通信には外部ルータ/FW が必須 | スイッチ TCAM 容量制限、SGT インライン伝搬が必要 |

---

## 🏗 動作原理

### 1. マクロセグメンテーション (Macro Segmentation) 通信フロー

ファブリック内では、各 VN は固有の **LISP Instance ID** および **VXLAN VNI** にマッピングされます。

```
[Host A (Corp_VN)]
       ↓ (Ingress Fabric Edge)
  VRF Corp_VN に収容
       ↓ (VXLAN カプセル化: VNI_Corp)
  [Fabric Underlay / IP Transit]
       ↓ (VNI_Corp 保持)
  [Fabric Border Node]
       ↓ (802.1Q Subinterface: VRF Corp_VN)
  [Fusion Router / Firewall] ── (Policy Inspection / Route Leaking)
       ↓ (802.1Q Subinterface: VRF Guest_VN)
  [Fabric Border Node]
       ↓ (VXLAN カプセル化: VNI_Guest)
[Host B (Guest_VN)]
```

### 2. マイクロセグメンテーション (Micro Segmentation) 通信フロー

SGT によるマイクロセグメンテーションは、**Egress Enforcement（受信側エッジでの適用）** が基本動作原則です。

```
[Host A (SGT 4: Sales)]
       ↓
(Ingress Fabric Edge Node)
   1. 802.1X / MAB 認証成功時、ISE から SGT 4 取得
   2. VXLAN-GPO ヘッダーの SGT フィールドに 4 をセットして送信
       ↓
[Fabric Overlay Network (VXLAN-GPO: SGT=4)]
       ↓
(Egress Fabric Edge Node)
   1. 宛先端末 Host B の SGT 5 (Finance) を特定
   2. ISE からロード済みの SGACL マトリクスを参照: [Source SGT 4 ➔ Dest SGT 5]
   3. ハードウェア TCAM で SGACL を評価 (Permit / Deny)
       ↓
[Host B (SGT 5: Finance)] (Permit の場合のみ到達)
```

---

## ⚙ 動作シーケンス

1. **Host Onboarding & SGT 割当シーケンス:**
   * サプリカント（端末）が Fabric Edge ポートに接続し、802.1X / MAB 認証を開始。
   * Fabric Edge ➔ Cisco ISE へ RADIUS Access-Request 送信。
   * ISE の Authorization Policy に基づき、RADIUS Access-Accept 返答内に `cisco-av-pair = cts:security-group-tag=0004-04` 属性を含めて返送。
   * Fabric Edge はポートの IP/MAC に SGT 4 を割り当て、SISF / Device Tracking テーブルに記録。

2. **Ingress カプセル化シーケンス:**
   * Host A (SGT 4) がパケットを送信。
   * Ingress Fabric Edge はパケットを受信し、VXLAN-GPO (Group Based Policy) ヘッダーに SGT 4 および VN に対応する VNI を付与して Underlay 経由でカプセル化転送。

3. **Egress ポリシー適用シーケンス:**
   * Egress Fabric Edge は VXLAN-GPO パケットを受信し、デカプセル化。
   * パケットヘッダーから Source SGT (4) を抽出。宛先 IP から Local MAC/EID テーブルを検索し、Dest SGT (5) を特定。
   * `show cts role-based permissions` テーブル（TCAM）を参照し、SGT 4 ➔ SGT 5 に対する SGACL ルール（例：`deny ip`, `permit tcp eq 443` 等）を評価し、パケットを転送またはドロップ。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 重要なポイント

1. **`cts role-based enforcement` の必須設定:**
   * グローバルおよび VLAN/VRF インターフェイスレベルで `cts role-based enforcement` が有効化されていない場合、スイッチは SGACL の評価を行わずにすべてのパケットを通過させてしまいます。
2. **Egress Enforcement 動作の理解:**
   * Ingress 側では SGT の付与と VXLAN-GPO への格納のみが行われ、フィルタリング（SGACL 適用）は必ずパケットがファブリックを出る **Egress Fabric Edge** で行われます。
3. **SXP (Security Group Tag Exchange Protocol) との連携:**
   * 非 SD-Access 機器や WAN 網（SGT インラインタギング未対応）を通過する場合、TCP 64999 を使用する SXP を構成して IP-to-SGT バインディングテーブルをピア間で動的共有する必要があります。
4. **SGACL マトリクスのダウンロード:**
   * スイッチは ISE から REST / EAPoL / RADIUS 経由で SGACL ポリシーを動的にダウンロードします。`cts refresh environment-data` や `cts refresh policy` コマンドで強制同期する手法を習得しておく必要があります。

---

## 🛠 設定方法

### CLI 設定例 (Fabric Edge 上での 手動/自動補正コンフィグ)

```bash
! --- 1. Cisco TrustSec (CTS) & SGACL グローバル有効化 ---
cts credentials id Switch-FE1 password 7 0822455D0A16
cts role-based enforcement

! --- 2. 認証・SGT 割当用 RADIUS / ISE サーバー設定 ---
radius server ISE-1
 address ipv4 192.168.10.50 auth-port 1812 acct-port 1813
 key Cisco123!
pac key Cisco123!

! --- 3. VRF / SVI レベルでの enforcement 有効化 ---
interface Vlan101
 description Corp_VN_SVI
 vr-forwarding Corp_VN
 ip address 10.1.101.1 255.255.255.0
 cts role-based enforcement

! --- 4. SXP スピーカー設定 (非ファブリック統合環境用) ---
cts sxp enable
cts sxp default source-ip 10.1.0.1
cts sxp connection peer 192.168.10.50 password 7 070C285F4D06 mode local role speaker
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| CTS 環境データ確認 | <code>show cts environment-data</code> |
| SGT バインディングテーブル確認 | <code>show cts ip-to-sgt all</code> |
| CTS ロールベース SGACL ポリシー確認 | <code>show cts role-based permissions</code> |
| インターフェイス CTS 設定確認 | <code>show cts interface GigabitEthernet1/0/1</code> |
| SGACL 統計・ヒットカウンター確認 | <code>show cts role-based counters all</code> |
| SXP 接続ステータス確認 | <code>show cts sxp connections</code> |
| SXP IP-SGT テーブル確認 | <code>show cts sxp sgt-map</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| SGACL が適用されず全通信が疎通してしまう | グローバルまたは SVI で `cts role-based enforcement` が未設定 | <code>show cts interface</code> | `cts role-based enforcement` を投入 |
| 端末に SGT が割り当てられない (SGT 0 となる) | ISE の Authorization Policy で RADIUS cisco-av-pair SGT 返却が欠落 | <code>show cts ip-to-sgt all</code> | ISE の Authorization Profile に SGT 割り当てを追加 |
| SGACL ポリシーがスイッチにダウンロードされない | CTS PAC 鍵または ISE 資格情報の認証失敗 | <code>show cts environment-data</code> | `cts refresh environment-data` を実行し ISE 接続を復旧 |
| SXP ピアリングが ESTABLISHED にならない | TCP 64999 の通信阻害、またはパスワードミスマッチ | <code>show cts sxp connections</code> | ACL / FW で TCP 64999 を許可し、SXP パスワードを修正 |
| SGACL 適用後にスイッチの TCAM エラーが発生 | SGACL ルール数がスイッチのハードウェア TCAM 容量を超却 | <code>show platform hardware fed switch active fwd-asic resource tcam</code> | ISE 側で SGACL ルールの集約またはマトリクス最適化を実行 |

---

## ⚠ 制限事項

1. **TCAM リソース制限:**
   * Catalyst 9300 / 9400 シリーズなどのスイッチにおける SGACL 用 TCAM エントリーにはハードウェア上限があります。大量の SGT セグメントや複雑な ACE（Access Control Entry）を定義すると TCAM 溢れが発生します。
2. **Ingress Enforcement の非サポート:**
   * SD-Access ファブリック内における SGACL 処理は、設計上 Egress Fabric Edge でのみサポートされます（Ingress 側での破棄は不可）。
3. **SXP スケーラビリティ:**
   * SXP 接続数および IP-to-SGT バインディング数にはプラットフォームごとの制限が存在するため、大規模網では SXP コネクタの階層設計が必要です。

---

## 🔄 他技術との関連

* **Cisco ISE (Identity Services Engine):** SGT / SGACL マトリクスの一元管理、RADIUS による動的 SGT 授与、PXGrid による外部連携。
* **VXLAN-GPO (Group Based Policy):** データ面で SGT 情報をヘッダー内に保持し、ファブリックを透過させるカプセル化技術。
* **VRF-Lite / Fusion Router:** マクロセグメンテーション（VN）間をまたぐ通信のルーティングおよびファイアウォール連携。
* **802.1X / MAB:** エンドポイント接続時の認証基盤。

---

## 🧩 比較表

### Traditional ACL vs SGACL

| 項目 | 従来の IP ACL (Standard / Extended) | TrustSec SGACL (Role-Based ACL) |
| :--- | :--- | :--- |
| **識別要素** | IP アドレス, Subnet, L4 ポート | 16-bit SGT（ロール・役割） |
| **トポロジー依存性** | 高い（IP アドレス設計・VLAN 構成に密結合） | 完全非依存（端末の IP が変わってもポリシー不変） |
| **コンフィグ量** | 機器ごとに大量の ACL 記述が必要 | ISE で一元管理し、スイッチへ動的ダウンロード |
| **メンテナンス性** | 端末追加・IP 変更のたびに全ルータの ACL 変更が必要 | 新規端末追加時も SGT 付与のみで ACL 変更不要 |
| **評価処理位置** | 入力/出力インターフェイス単位 | Egress Fabric Edge での集中評価 |

---

## 💡 ベストプラクティス

1. **Default Security Group Policy の明確化:**
   * ISE の SGACL マトリクス初期運用時は `Permit All` でログ収集を行い、通信要件の洗い出し完了後に `Deny All` へのシフトを推奨。
2. **SGT 番号計画の体系化:**
   * SGT 2（TrustSec Devices）、SGT 3（Network Services）等の Cisco 定義 Well-Known SGT と衝突しないよう、カスタム SGT は 10 以降で体系的に設計する。
3. **SXP 冗長化設計:**
   * 非 SD-Access エリアとの連携で SXP を使用する場合、プライマリ/セカンダリの 2 つの SXP コネクションを構成して冗長性を確保する。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: Cisco TrustSec (CTS) ＆ SGACL 基本有効化

#### 問題
Fabric Edge (FE-1) 上で Cisco TrustSec を有効化し、SGACL 評価を実行できるように設定しなさい。

#### 要件
* FE-1 上でグローバルに `cts role-based enforcement` を有効化すること。
* SVI Vlan 10 (Corp_VN) 上で CTS エンフォースメントを有効化すること。

#### 設定例
```bash
FE-1(config)# cts role-based enforcement
FE-1(config)# interface Vlan10
FE-1(config-if)# cts role-based enforcement
FE-1(config-if)# exit
```

#### 検証方法
```bash
FE-1# show cts interface Vlan10
! CTS enforcement state が ENABLED になっていることを確認
```

---

### ラボ 2: IP-to-SGT 静的マッピング設定

#### 問題
認証非対応の固定 IP サーバー（192.168.100.50）に対して、手動で SGT 15 (DataCenter_Servers) を割り当てなさい。

#### 要件
* FE-1 上で `192.168.100.50` に対し SGT `15` を静的にバインドすること。

#### 設定例
```bash
FE-1(config)# cts role-based sgt-map 192.168.100.50 sgt 15
```

#### 検証方法
```bash
FE-1# show cts ip-to-sgt all
! 192.168.100.50 が SGT 15 にマッピングされていることを確認
```

---

### ラボ 3: 手動 SGACL ポリシーおよびパーミッション定義

#### 問題
SGT 4 (Sales) から SGT 5 (Finance) 宛ての ICMP パケットを拒否し、その他の通信を許可するローカル SGACL を設定しなさい。

#### 要件
* Role-based Access-List 名: `SGACL_SALES_TO_FINANCE`
* SGT 4 ➔ SGT 5 に対して同 ACL を適用すること。

#### 設定例
```bash
FE-1(config)# ip access-list role-based SGACL_SALES_TO_FINANCE
FE-1(config-rb-acl)# deny icmp
FE-1(config-rb-acl)# permit ip
FE-1(config-rb-acl)# exit

FE-1(config)# cts role-based permissions src-sgt 4 dst-sgt 5 SGACL_SALES_TO_FINANCE
```

#### 検証方法
```bash
FE-1# show cts role-based permissions src-sgt 4 dst-sgt 5
! 適用された ACL とパーミッションルールを確認
```

---

### ラボ 4: SXP スピーカー (SXP Speaker) の構成

#### 問題
FE-1 を SXP スピーカーとして動作させ、ISE サーバー (192.168.10.50) へ IP-SGT バインディング情報を送信しなさい。

#### 要件
* SXP バージョン: Version 4
* SXP 共有パスワード: `CiscoSxpPass123`
* 自身の送信元 IP: `10.1.0.1`

#### 設定例
```bash
FE-1(config)# cts sxp enable
FE-1(config)# cts sxp default source-ip 10.1.0.1
FE-1(config)# cts sxp connection peer 192.168.10.50 password 7 0822455D0A16 mode local role speaker version 4
```

#### 検証方法
```bash
FE-1# show cts sxp connections
! ピア状態が "On" / "Established" になっていることを確認
```

---

### ラボ 5: SXP リスナー (SXP Listener) の構成

#### 問題
Core-1 スイッチを SXP リスナーとして動作させ、SXP ピア (10.1.0.1) から IP-SGT バインディングを受信しなさい。

#### 要件
* モード: Listener
* 共有パスワード: `CiscoSxpPass123`

#### 設定例
```bash
Core-1(config)# cts sxp enable
Core-1(config)# cts sxp default source-ip 10.2.0.1
Core-1(config)# cts sxp connection peer 10.1.0.1 password 7 0822455D0A16 mode local role listener version 4
```

#### 検証方法
```bash
Core-1# show cts sxp sgt-map
! SXP 経由で学習した IP-SGT マッピングテーブルを確認
```

---

### ラボ 6: ISE からの CTS 環境データ強制リフレッシュ

#### 問題
ISE 上で変更した SGT 属性・環境データを Fabric Edge 上で即座に再取得しなさい。

#### 要件
* `cts refresh` コマンドを使用して環境データを更新すること。

#### 設定例
```bash
FE-1# cts refresh environment-data
```

#### 検証方法
```bash
FE-1# show cts environment-data
! Refresh Status が Succeeded になっていることを確認
```

---

### ラボ 7: SGACL ヒットカウンターのクリアと検証

#### 問題
FE-1 上のすべての SGACL ヒットカウンターをリセットし、特定の SGT 通信テストを実施しなさい。

#### 要件
* カウンターをクリア後、パケット生成を行ってヒット数が増加することを確認すること。

#### 設定例
```bash
FE-1# clear cts role-based counters
```

#### 検証方法
```bash
FE-1# show cts role-based counters src-sgt 4 dst-sgt 5
! パケットカウントの増加を確認
```

---

### ラボ 8: デフォルト SGT (Unknown SGT: 0) のフィルタリング

#### 問題
SGT が未割り当ての未知の端末 (SGT 0) から、重要サーバー (SGT 10) 宛ての通信を遮断しなさい。

#### 要件
* SGT 0 ➔ SGT 10 に対して Deny ルールを適用すること。

#### 設定例
```bash
FE-1(config)# ip access-list role-based DENY_UNKNOWN
FE-1(config-rb-acl)# deny ip
FE-1(config-rb-acl)# exit
FE-1(config)# cts role-based permissions src-sgt 0 dst-sgt 10 DENY_UNKNOWN
```

#### 検証方法
```bash
FE-1# show cts role-based permissions src-sgt 0 dst-sgt 10
```

---

### ラボ 9: サブネット単位での IP-to-SGT 静的バインド

#### 問題
特定サブネット `172.16.50.0/24` 全体に対して、SGT 20 (Contractors) を割り当てなさい。

#### 要件
* CIDR 表記を用いて静的マッピングを投入すること。

#### 設定例
```bash
FE-1(config)# cts role-based sgt-map 172.16.50.0/24 sgt 20
```

#### 検証方法
```bash
FE-1# show cts ip-to-sgt all
! 172.16.50.0/24 が SGT 20 にバインドされていることを確認
```

---

### ラボ 10: SGACL 動作ログの記録設定

#### 問題
SGACL によってドロップされたパケットを Syslog に記録するように設定しなさい。

#### 要件
* Role-based ACL 内で `log` オプションを付与すること。

#### 設定例
```bash
FE-1(config)# ip access-list role-based SGACL_AUDIT
FE-1(config-rb-acl)# deny ip log
FE-1(config-rb-acl)# permit ip
FE-1(config-rb-acl)# exit
FE-1(config)# cts role-based permissions src-sgt 4 dst-sgt 5 SGACL_AUDIT
```

#### 検証方法
```bash
FE-1# show logging | include CTS-3-POLICY_DENY
! ドロップログの記録を確認
```

---

## ❓ 想定試験問題

### 問題 1 (コンフィグ読解)
Fabric Edge スイッチにおいて、802.1X 認証が成功して ISE から SGT 5 が返却されているにもかかわらず、`show cts role-based permissions` に SGACL ポリシーが反映されず、すべての通信が許可されています。以下のコンフィグから原因を特定しなさい。

```text
aaa new-model
radius server ISE
 address ipv4 192.168.10.50 auth-port 1812 acct-port 1813
 key Cisco123!
!
interface GigabitEthernet1/0/5
 switchport mode access
 switchport access vlan 10
 authentication port-control auto
```

**正解・解説:**
* **原因:** グローバルコマンド `cts role-based enforcement` およびインターフェイス/VLAN レベルでの CTS エンフォースメント有効化設定が欠落しています。
* **修復コマンド:**
  ```bash
  FE(config)# cts role-based enforcement
  FE(config)# interface Vlan10
  FE(config-if)# cts role-based enforcement
  ```

---

### 問題 2 (トラブルシューティング)
Egress Fabric Edge 上で SGT 4 ➔ SGT 8 宛てのパケットが SGACL によってドロップされています。しかし、管理者は ISE 上でこの通信を許可（Permit）するようにポリシーを変更しました。スイッチ側で即座に新しいポリシーを反映させるためのコマンドを答えなさい。

**正解・解説:**
* **解答:** `cts refresh policy` または `cts refresh environment-data`
* **解説:** スイッチは環境データや SGACL ポリシーをキャッシュしています。ISE 上での変更を即座にスイッチへ反映させるには、`cts refresh` コマンドで動的ダウンロードを強制実行します。

---

### 問題 3 (Design)
SD-Access ファブリックと非 SD-Access 既存 LAN 網が接続されている環境において、既存 LAN 網内のスイッチが VXLAN-GPO カプセル化（インラインタギング）に対応していません。既存 LAN 内の端末の SGT 情報を Fabric Border に伝達するための最適なプロトコルを選択しなさい。

* A. LISP Dynamic EID
* B. SXP (Security Group Tag Exchange Protocol)
* C. VRF-Lite BGP
* D. 802.1Q Inline Tagging

**正解・解説:**
* **正解:** B
* **解説:** SXP は TCP 64999 セッションを使用して IP-to-SGT バインディングテーブルをピア間で伝送するプロトコルです。データプレーンでの SGT ヘッダー付与に対応していない古いスイッチや中間網がある場合に用いられます。

---

### 問題 4 (実装)
同一 Virtual Network (Corp_VN) 内に所属する端末 A (10.1.10.11: SGT 4) から 端末 B (10.1.10.12: SGT 5) への HTTP (TCP 80) アクセスを拒否し、その他の通信を許可する SGACL を設定しなさい。

**正解・解説:**
```bash
FE(config)# ip access-list role-based DENY_HTTP
FE(config-rb-acl)# deny tcp destination eq 80
FE(config-rb-acl)# permit ip
FE(config-rb-acl)# exit
FE(config)# cts role-based permissions src-sgt 4 dst-sgt 5 DENY_HTTP
```

---

### 問題 5 (トラブルシューティング)
`show cts sxp connections` を実行したところ、ステータスが `Connection-Pending` のまま変化しません。確認すべきポイントを 3 つ挙げなさい。

**正解・解説:**
1. 送信元・宛先 IP アドレス（Loopback アドレス等）に対する L3 IP 疎通性があるか。
2. 中間ファイアウォールや ACL で SXP ポート（TCP 64999）が遮断されていないか。
3. SXP ピア間で設定した共有パスワード（Password）および SXP Role (Speaker / Listener) が一致しているか。

---

## 🔗 参考リソース

* [Cisco SD-Access Segmentation Design Guide (CVD)](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sd-access-segmentation-design-guide.html)
* [Cisco TrustSec Configuration Guide, Cisco IOS XE Bengaluru 17.6.x](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-6/configuration_guide/cts/b_176_cts_cg_9300_cr.html)
* [Cisco Identity Services Engine Administrator Guide, Release 3.1 - TrustSec Administration](https://www.cisco.com/c/en/us/td/docs/security/ise/3-1/admin_guide/b_ise_admin_3_1/b_ise_admin_3_1_trustsec.html)
* [Cisco Live BRKCRS-2810: SD-Access Macro and Micro Segmentation Design and Deployment](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **Egress Enforcement の徹底注意:**
  * SD-Access では SGACL フィルタリングは必ずパケットを受信する側の Fabric Edge (Egress) で実行されます。Ingress Fabric Edge では SGT タグの挿入（VXLAN-GPO ヘッダー）のみが行われます。
* **TCAM リソースへの配慮:**
  * SGACL はスイッチのハードウェア TCAM を消費します。ルール数が多くなると TCAM エラーが発生するため、ISE 上で ACE ルールを集約するか、不要な SGT ペアのポリシーを無効化することが重要です。


## 📘 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076) - セグメンテーション設計のベストプラクティス。
*   [**BRKCRS-2810: Cisco SD-Access Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2810) - ポリシー適用のデバッグ手法。
*   [**BRKCCIE-3000: Software Defined Access for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - ラボ試験特化のセグメンテーション解説。

### Configuration ガイド
*   [**Software-Defined Access Macro Segmentation Deployment Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)。
*   [**Cisco TrustSec (SGT/SGACL) Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg/m_cts_sgt_config.html)。

### テクニカルドキュメント・設定例
*   [**SDA Segmentation Policy Overview (Cisco White Paper)**](https://www.cisco.com/c/en/us/products/collateral/cloud-systems-management/dna-center/white-paper-c11-740585.pdf)。
*   [**Troubleshooting SD-Access Macro and Micro Segmentation**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)。

---
## 📝 補足

- この学習メモは、SD-Access セグメンテーションの二重構造（Macro/Micro）を網羅しています。CCIE 実技試験においては、特に **ISE とスイッチ間の CTS（TrustSec）通信状態** や、**Fusion ルータでの VRF リーキング** が配点の高いポイントとなるため、CLI での確認コマンドを完全に習得しておくことが合格の鍵となります。


