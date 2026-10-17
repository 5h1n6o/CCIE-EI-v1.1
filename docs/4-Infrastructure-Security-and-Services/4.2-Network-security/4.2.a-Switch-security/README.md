---
layout: default
title: 4.2.a-Switch-security
parent: 4.2-Network-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.2.a Switch security features

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint 領域 `4.0 Infrastructure Security and Services` における、レイヤ 2 / レイヤ 3 スイッチセキュリティ機能（VACL, PACL, Storm Control, DHCP Snooping, IP Source Guard, DAI, Port Security）の完全統合学習メモ。

---

## 📘 概要

キャンパススイッチングインフラストラクチャにおけるスイッチセキュリティ機能は、アクセス層およびディストリビューション層において、盗聴、なりすまし（Spoofing）、中間者攻撃（Man-in-the-Middle: MitM）、サービス拒否攻撃（DoS）、および不正機器接続などの脅威からネットワーク基盤を保護するための不可欠な防御メカニズムである。

* **VACL (VLAN ACL) & PACL (Port ACL):**
  * **VACL (VLAN Access Control List / VLAN Map):** VLAN 内でブリッジングされる L2 トラフィックおよび SVI 経由でルーティングされる L3 トラフィックの双方に対して、方向（Inbound/Outbound）に関係なくハードウェア ASIC (TCAM) でフィルタリングを実行する。
  * **PACL (Port Access Control List):** 物理レイヤ 2 インターフェイスの Inbound 方向でパケットを直接フィルタリングする。MAC ACL または IP ACL をバインド可能。
  * **利用場面:** VLAN 内の端末間直接通信（East-West トラフィック）の制限、特定ポートにおける不法プロトコルのブロック。

* **Storm Control (ストーム制御):**
  * レイヤ 2 インターフェイスにおいて、ブロードキャスト、マルチキャスト、または未知のユニキャスト（Unknown Unicast）ストームによるネットワーク帯域の枯渇やスイッチ CPU の過負荷を抑止する。
  * **利用場面:** ルーピングや故障機器、悪意ある DoS 攻撃によるトラフィック急増の自動検出と帯域抑制。

* **DHCP Snooping & Option 82:**
  * 不正な DHCP サーバー（Rogue DHCP Server）による IP アドレス誤割り当てや中間者攻撃を防止するとともに、DHCP メッセージを監視して「DHCP Snooping Binding Table（MAC-IP-VLAN-Port-Lease 結合表）」を動的に構築する。
  * **Option 82 (DHCP Relay Agent Information Option):** パケットが入力されたスイッチポート（Circuit ID）やスイッチ識別子（Remote ID）の物理位置情報を DHCP リクエストに挿入し、DHCP サーバー側での高度なポリシー割り当てを可能にする。

* **IP Source Guard (IPSG):**
  * 送信元 IP アドレス（および送信元 MAC アドレス）を偽装した IP スプーフィング攻撃を防止する。
  * **利用場面:** DHCP Snooping Binding Table または静的バインディング情報を基に、アクセスポートの Inbound TCAM に自動的に Port ACL を生成・バインドし、許可されていない IP パケットを即座にドロップする。

* **Dynamic ARP Inspection (DAI):**
  * ARP ポイズニング（ARP スプーフィング）による MitM 攻撃や盗聴を防止する。
  * **利用場面:** Untrusted ポートに入力される ARP パケットの Sender IP / Sender MAC を DHCP Snooping Binding Table（または Static ARP ACL）と照合し、不一致な不正 ARP レスポンス/リクエストをドロップする。

* **Port Security:**
  * インターフェイス単位で接続を許可する MAC アドレスの最大数および特定の MAC アドレスを制限・固定（Sticky / Static）する。
  * **利用場面:** 不正なスイッチ接続やハブ接続による複数端末の無許可参加、MAC アドレスフローディング攻撃（CAM テーブル枯渇攻撃）のブロック。

---

## 🔑 要点

| 機能 | 特徴 | 主な用途 | メリット | デメリット/制限事項 | 設計上の注意点 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **VACL** | VLAN 全体（L2/L3）を対象とする VLAN Map 制御 | VLAN 内端末間通信（East-West）制御 | 方向定義不要、ASIC 線形処理 | 該当 VLAN 全体に適用されるため個別ポート制御が困難 | 末尾に `action forward` を明示しないと全トラフィックがドロップされる |
| **PACL** | L2 物理ポート/Port-channel の Inbound 限定 ACL | 特定ポート直下のアクセス制限 | SVI や VLAN 設定に依存せずポート単位で適用可能 | Inbound のみ対応。Egress PACL は非サポート | 評価順序は PACL ➔ VACL ➔ RACL の順 |
| **Storm Control** | 1秒間隔のトラフィック量をハードウェア監視 | ストームによる帯域枯渇・DoS抑止 | 閾値超過時の自動ドロップ/Err-disable 化 | 正常なマルチキャスト/ブロードキャスト通信を誤遮断するリスク | 閾値（%, pps, bps）の設定値選定と Err-disable 自動復旧の併用 |
| **DHCP Snooping** | Untrusted ポートからの Rogue DHCP 応答遮断 | Rogue DHCP 対策、FHS の基盤 DB 構築 | DAI / IPSG のバインディング DB を自動生成 | Option 82 付与時の L2 スイッチ/DHCP サーバーでのドロップ動作 | アップリンク/DHCP サーバー側ポートへの `trust` 設定と Option 82 管理 |
| **IPSG** | DHCP Snooping DB に基づく Port ACL 自動生成 | 送信元 IP/MAC スプーフィング防止 | 許可されていない固定 IP 直打ち端末を自動遮断 | DHCP Snooping 未有効時や静的 IP 端末には手動バインドが必要 | `port-security` 適用時は Port Security が必須 |
| **DAI** | ARP パケット内の Sender IP/MAC と DB の照合 | ARP スプーフィング・MitM 防御 | ARP ポイズニングによる盗聴・通信乗っ取りを防止 | CPU 処理負荷が高まる可能性（Rate-Limit 推奨） | 内部ルータ/アップリンクへの `trust` 設定と ARP ACL による例外救済 |
| **Port Security** | ポートごとの受入 MAC アドレス制限・Sticky 学習 | MAC フラッディング攻撃防止、不正端末接続制御 | 送信元 MAC 単位でのアクセス制御、Err-disable 自動通知 | IP アドレスの偽装は防止できない（DAI/IPSG と併用が必要） | Trunk ポート適用時の VLAN 単位 MAC 制限および Voice VLAN 併用 |

---

## 🏗 動作原理

### 1. インバウンド TCAM 評価パイプライン (PACL ➔ VACL ➔ RACL)

パケットがスイッチに入力された際、ハードウェア TCAM 内で以下の厳格な順序でアクセス制御が評価される：

```text
[ パケット受信 (Ingress Port) ]
         │
         ▼
┌──────────────────┐
│    PACL Check    │ (Port ACL: 物理ポート Inbound)
└────────┬─────────┘
         │ (Permit)
         ▼
┌──────────────────┐
│    VACL Check    │ (VLAN Access Map: Bridged & Routed Traffic)
└────────┬─────────┘
         │ (Permit)
         ▼
┌──────────────────┐
│    RACL Check    │ (Routed ACL: SVI Inbound ACL - ルーティング時のみ)
└────────┬─────────┘
         │ (Permit)
         ▼
[ Switching / Routing Processing ]
```

### 2. First Hop Security (FHS) 統合データフロー (DHCP Snooping / DAI / IPSG)

```text
Client (Untrusted Port)                        Switch (DHCP Snooping)                   DHCP Server (Trusted Port)
   │                                                    │                                           │
   │ ─── 1. DHCP Discover / Request ──────────────────► │ ─── (Option 82 挿入) ───────────────────► │
   │                                                    │                                           │
   │ ◄── 2. DHCP Offer / ACK ────────────────────────── │ ◄── (Option 82 除去 / Binding DB 登録) ── │
   │     (IP: 10.1.1.50 / MAC: 0011.2233.4455)          │                                           │
   │                                                    │                                           │
   ▼                                                    ▼                                           │
[ DHCP Snooping Binding Table ] ─────────────────────────────────────────────────────────────────────┘
│ MAC: 0011.2233.4455 │ IP: 10.1.1.50 │ VLAN: 10 │ Port: Gi1/0/1 │ Lease: 86400 │
└───────────────────────────────────────────────────────────────────────────────┘
   │
   ├──► [ Dynamic ARP Inspection (DAI) ]
   │       ARP パケットの Sender IP (10.1.1.50) / Sender MAC (0011.2233.4455) を上記 DB と照合。
   │       不一致な偽装 ARP レスポンスはラインレートで破棄。
   │
   └──► [ IP Source Guard (IPSG) ]
           データパケットの Source IP (10.1.1.50) / Source MAC を上記 DB と照合。
           DB に存在しない IP 直打ちパケットは TCAM レベルでドロップ。
```

---

## ⚙ 動作シーケンス

### DHCP Snooping & Option 82 のパケット処理シーケンス
1. **DHCP Request 受信:** Untrusted ポートから `DHCPDISCOVER` / `DHCPREQUEST` を受信。
2. **Option 82 挿入 (デフォルト設定時):** L2 スイッチはパケットに Option 82（Circuit ID = VLAN + Port, Remote ID = Switch MAC）を挿入。
3. **Trusted ポートからの送出:** リレーまたは転送され、Trusted ポート経由で DHCP サーバーへ到達。
4. **DHCP Server 応答:** DHCP サーバーが `DHCPOFFER` / `DHCPACK` を返信。
5. **Untrusted ポート遮断チェック:** 不正な DHCP サーバーが Untrusted ポートに接続され、`DHCPOFFER` を送信した場合、スイッチは即座にドロップし Syslog を記録。
6. **Binding Table 追記:** Trusted ポートから正常な `DHCPACK` が通過した際、スイッチは Snooping テーブルに `MAC`, `IP`, `VLAN`, `Port`, `Lease` をバインド追記。

---

## 🎯 試験対策（CCIE EIラボ試験）

* **Blueprintで重要なポイント:**
  * VACL と PACL の適用場所と評価順序の違いの理解。
  * DHCP Snooping 有効化時の **Option 82 ドロップ問題**（L2 スイッチ構成時における `no ip dhcp snooping information option` や `ip dhcp relay information trust-all` の設定判断）。
  * DAI / IPSG 構築時における **Trusted ポートの指定漏れ**（アップリンクポートへの `ip arp inspection trust` 忘れによる通信全断）。
  * Port Security における `sticky` MAC アドレスの挙動および Violation モード（`protect`, `restrict`, `shutdown`）の相違点。
  * Err-disable 自動復旧（`errdisable recovery cause ...`）のグローバル設定。

* **よくある設定ミス:**
  * VACL 設定時、特定のトラフィックを `action drop` した後、**末尾の `action forward` を忘れて該当 VLAN の全通信をドロップさせてしまう**トラブル。
  * DAI 有効化時、HSRP/VRRP ルータや静的 IP サーバーの ARP パケットがドロップされる問題（`arp access-list` による救済の必要性）。
  * `ip verify source port-security`（IP + MAC 検証）適用時に、該当ポートで **`switchport port-security` を有効化し忘れてコマンドが拒否される**パターン。

---

## 🛠 設定方法

### 1. VACL (VLAN Map) & PACL 設定例

```bash
! --- VACL: VLAN 10 内の SMB (TCP 445/139) 通信のみをドロップし、他は許可 ---
ip access-list extended ACL_SMB_TRAFFIC
 permit tcp any any eq 445
 permit tcp any any eq 139

vlan access-map VMAP_PREVENT_SMB 10
 match ip address ACL_SMB_TRAFFIC
 action drop

vlan access-map VMAP_PREVENT_SMB 20
 action forward

vlan filter VMAP_PREVENT_SMB vlan-list 10

! --- PACL: 物理ポート Gi1/0/2 入口で特定 IP アドレスからのアクセスを遮断 ---
ip access-list extended ACL_PORT_RESTRICT
 deny ip host 192.168.10.99 any
 permit ip any any

interface GigabitEthernet1/0/2
 switchport mode access
 switchport access vlan 10
 ip access-group ACL_PORT_RESTRICT in
```

### 2. Storm Control 設定例

```bash
interface GigabitEthernet1/0/3
 switchport mode access
 switchport access vlan 10
 storm-control broadcast level 10.0 5.0
 storm-control multicast level 20.0
 storm-control action shutdown
 storm-control action trap

! Err-disable 自動復旧設定
errdisable recovery cause storm-control
errdisable recovery interval 300
```

### 3. DHCP Snooping & Option 82 回避設定例

```bash
! グローバル有効化
ip dhcp snooping
ip dhcp snooping vlan 10,20

! L2 スイッチ構成で Gateway が別にある場合、Option 82 ドロップを回避するための設定
no ip dhcp snooping information option

! アップリンク / DHCP サーバーポート (Trusted) 設定
interface GigabitEthernet1/0/24
 switchport mode trunk
 ip dhcp snooping trust
```

### 4. Dynamic ARP Inspection (DAI) ＆ Static ARP ACL 例外設定例

```bash
! DAI のグローバル有効化
ip arp inspection vlan 10,20

! 固定 IP サーバー (Snooping DB に存在しない) 用の ARP ACL 救済設定
arp access-list ACL_STATIC_SERVER
 permit ip host 10.1.1.100 mac host 0050.56a1.b2c3

ip arp inspection filter ACL_STATIC_SERVER vlan 10 static

! アップリンクポート (Trusted) 設定
interface GigabitEthernet1/0/24
 ip arp inspection trust
```

### 5. IP Source Guard (IPSG) 設定例

```bash
! アクセスポートでの IPSG (IP + MAC 検証) 有効化
interface GigabitEthernet1/0/5
 switchport mode access
 switchport access vlan 10
 switchport port-security
 ip verify source tracking port-security

! 固定 IP 端末用の静的バインディング登録 (Snooping 未使用端末)
ip source binding 0011.2233.4455 vlan 10 10.1.1.80 interface GigabitEthernet1/0/6
```

### 6. Port Security ＆ Err-Disable 自動復旧設定例

```bash
interface GigabitEthernet1/0/7
 switchport mode access
 switchport access vlan 10
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation restrict
 switchport port-security mac-address sticky

! Port Security 違反による Err-disable 自動復旧
errdisable recovery cause psecure-violation
errdisable recovery interval 180
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| VACL 適用状態確認 | `show vlan filter` |
| VACL マップ定義確認 | `show vlan access-map` |
| PACL 適用確認 | `show ip interface GigabitEthernet1/0/2` |
| Storm Control ステータス確認 | `show storm-control` |
| DHCP Snooping 設定確認 | `show ip dhcp snooping` |
| DHCP Snooping DB テーブル表示 | `show ip dhcp snooping binding` |
| DAI 設定・VLAN ステータス確認 | `show ip arp inspection vlan 10` |
| DAI ドロップ統計確認 | `show ip arp inspection statistics` |
| IPSG バインディング・フィルター確認 | `show ip verify source` |
| IP Source Binding 静的/動的確認 | `show ip source binding` |
| Port Security インターフェイス状態確認 | `show port-security interface GigabitEthernet1/0/7` |
| Port Security MAC アドレス一覧確認 | `show port-security address` |
| Err-disable 発生理由・自動復旧状態 | `show errdisable recovery` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **VLAN 10 内の全通信が不通になった** | VACL で `action drop` の後、末尾の `action forward` 設定が欠落している | `show vlan access-map` | 全許可ルール `vlan access-map MAP 20` ➔ `action forward` を追記する |
| **DHCP アドレスが取得できない** | L2 スイッチで Option 82 が自動挿入され、上流 DHCP サーバーで破棄されている | `show ip dhcp snooping` | L2 スイッチで `no ip dhcp snooping information option` を実行する |
| **DAI 有効化後、全端末の通信が切断された** | アップリンクポートへの `ip arp inspection trust` 設定が漏れている | `show ip arp inspection interfaces` | アップリンク側ポートで `ip arp inspection trust` を設定する |
| **固定 IP サーバーの ARP パケットがドロップされる** | Snooping DB に存在しないため DAI で破棄されている | `show ip arp inspection statistics` | `arp access-list` を作成し `ip arp inspection filter` を適用する |
| **IPSG コマンドが設定エラーになる** | `ip verify source tracking port-security` 設定時に `switchport port-security` が未設定 | `show running-config interface` | 対象ポートで `switchport port-security` を有効化する |
| **ポートが Err-disable に落とされる** | Port Security の受入 MAC アドレス超過または Storm Control 閾値突破 | `show errdisable status` | 違反端末を取り除き `shutdown` / `no shutdown` または Err-disable Auto-recovery を構成する |

---

## ⚠ 制限事項

* **PACL 制限:** Inbound 方向のみサポート。Egress PACL や L3 ルーテッドポートへの PACL 適用は非サポート。
* **VACL 制限:** 方向（Inbound/Outbound）の概念を持たないため、片方向のみのフィルタリングは ACL の条件記述（TCP Established や IP レベル）で工夫する必要がある。
* **Option 82 制限:** Catalyst スイッチが L2 モードで動作している場合、`giaddr`（0.0.0.0）のまま Option 82 を保持するため、`ip dhcp relay information trust-all` や `no ip dhcp snooping information option` の調整が必須。
* **IPSG 制限:** DHCP Snooping データベースまたは手動の `ip source binding` が存在しない環境では全データパケットがブロックされる。

---

## 🔄 他技術との関連

* **Cisco ISE / 802.1X:** 認証成功後の Dynamic ACL / SGT 付与と、スイッチローカルの FHS (DHCP Snooping / DAI / IPSG) の連携による二重防御。
* **Private VLAN (PVLAN):** Isolated ポート間の通信遮断と VACL / DAI の併用による L2 セキュリティの完全化。
* **First Hop Redundancy Protocols (HSRP / VRRP):** 仮想 IP / 仮想 MAC に対する DAI ドロップの回避（`trust` 設定または ARP ACL 例外）。

---

## 🧩 比較表

### VACL vs PACL vs RACL (SVI ACL) 比較

| 項目 | VACL (VLAN Map) | PACL (Port ACL) | RACL (Routed ACL) |
| :--- | :--- | :--- | :--- |
| **適用レベル** | VLAN 全体 (L2/L3) | 物理 L2 ポート / Port-channel | L3 インターフェイス / SVI |
| **方向 (Direction)** | なし (VLAN 内全トラフィック) | Inbound のみ | Inbound / Outbound |
| **対象通信** | ブリッジング (L2) ＆ ルーティング (L3) | 入力 L2/L3 パケット | ルーティングされる L3 パケット |
| **適用コマンド** | `vlan filter <MAP> vlan-list <VLAN>` | `ip access-group <ACL> in` | `ip access-group <ACL> <in\|out>` |
| **TCAM 評価順序** | 2番目 (PACL の後) | 1番目 (最優先) | 3番目 (VACL の後) |

---

## 💡 ベストプラクティス

1. **VACL の安全な運用:** VACL 作成時は、必ずテスト用シーケンスで `action forward` を最後に配置し、意図しない VLAN 全体停止事故を防ぐ。
2. **FHS (DHCP Snooping / DAI / IPSG) 導入順序:** 最初に DHCP Snooping を有効化して Binding Table を十分に構築させた後、DAI ➔ IPSG の順で段階的に有効化する。
3. **アップリンクポートの保護:** ルータ、他スイッチ、DHCP サーバーへの Trunk / Routed ポートには必ず `ip dhcp snooping trust` および `ip arp inspection trust` を設定する。
4. **Err-disable 自動復旧:** 運用負荷低減のため、`errdisable recovery cause psecure-violation` および `errdisable recovery cause storm-control` を有効化し、`interval 180`〜`300` 秒程度で自動復旧させる。

---

## 📝 ラボ学習・設定サンプル例

### ラボ 1: VACL による特定 VLAN 内の SMB 通信 (TCP 445/139) ドロップ構成

* **問題:** VLAN 10 内のクライアント間において、ランサムウェア拡散防止のため SMB プロトコル（TCP 445, TCP 139）の直接通信を遮断し、その他の通信（HTTP, ICMP等）は一切影響を与えず許可せよ。
* **要件:**
  * VLAN 10 内の全トラフィックに適用すること。
  * VACL (VLAN Access Map) を使用すること。
  * 末尾の暗黙のドロップにより正常通信が遮断されないよう配慮すること。

* **設定例:**
```bash
! 1. 拒否対象とする SMB トラフィックを定義する ACL
ip access-list extended ACL_SMB_BLOCK
 permit tcp any any eq 445
 permit tcp any any eq 139

! 2. VLAN Access Map の作成 (Sequence 10: ドロップ、Sequence 20: 許可)
vlan access-map VMAP_SMB 10
 match ip address ACL_SMB_BLOCK
 action drop

vlan access-map VMAP_SMB 20
 action forward

! 3. VLAN 10 への適用
vlan filter VMAP_SMB vlan-list 10
```

* **検証方法:**
  * VLAN 10 内の Host-A (10.1.1.10) から Host-B (10.1.1.20) 宛てに `ping 10.1.1.20` を実行し、疎通することを確認。
  * Host-A から Host-B 宛てに SMB 接続（`telnet 10.1.1.20 445`）を実行し、接続がタイムアウト（ドロップ）することを確認。
  * `show vlan filter` でバインド状態を確認。

---

### ラボ 2: PACL によるアクセスポート直下の特定 IP 送信制限

* **問題:** 物理ポート GigabitEthernet1/0/2 直下の端末から、外部管理ネットワーク（172.16.0.0/16）宛ての全通信をポート入口でドロップせよ。
* **要件:**
  * PACL (Port ACL) を使用すること。
  * SVI や VLAN 10 全体には影響を与えず、Gi1/0/2 のみに作用させること。

* **設定例:**
```bash
! 1. 拒否対象のアクセス制御リスト作成
ip access-list extended ACL_PACL_RESTRICT
 deny ip any 172.16.0.0 0.0.255.255
 permit ip any any

! 2. 物理ポート Inbound への適用
interface GigabitEthernet1/0/2
 switchport mode access
 switchport access vlan 10
 ip access-group ACL_PACL_RESTRICT in
```

* **検証方法:**
  * Gi1/0/2 に接続された端末から 172.16.1.1 宛てに Ping を実行し、ドロップすることを確認。
  * `show ip interface GigabitEthernet1/0/2` を実行し、Inbound access list に `ACL_PACL_RESTRICT` が適用されていることを確認。

---

### ラボ 3: Storm Control による Broadcast 制限 ＆ Err-disable 自動復旧

* **問題:** ポート GigabitEthernet1/0/3 において、ブロードキャストトラフィックが帯域の 5% を超えた場合にパケットをドロップし、10% を超えた場合はポートを即座に Shutdown (Err-disable) させよ。また、5 分後に自動復旧させよ。
* **要件:**
  * ライジング閾値 10%、フォーリング閾値 5% を設定すること。
  * Err-disable からの自動復旧タイマー（300 秒）を構成すること。

* **設定例:**
```bash
! 1. インターフェイスレベルでのストーム制御
interface GigabitEthernet1/0/3
 switchport mode access
 switchport access vlan 10
 storm-control broadcast level 10.0 5.0
 storm-control action shutdown
 storm-control action trap

! 2. Err-disable 自動復旧の設定
errdisable recovery cause storm-control
errdisable recovery interval 300
```

* **検証方法:**
  * テスターから Gi1/0/3 宛てにラインレートのブロードキャストを印加する。
  * `show interface GigabitEthernet1/0/3` を確認し、ポートが `err-disabled` 状態へ遷移したことを確認。
  * `show errdisable recovery` で復旧カウントダウンタイマーを確認。

---

### ラボ 4: DHCP Snooping ＋ Option 82 ドロップ問題の完全解決構成

* **問題:** VLAN 20 において DHCP Snooping を有効化せよ。アクセスポート Gi1/0/5 からの不正 DHCP サーバー接続を遮断しつつ、正規 DHCP サーバーからの IP アドレス取得が Option 82 ドロップ問題によって妨げられないよう構成せよ。
* **要件:**
  * アップリンク Gi1/0/24 を Trust ポートに指定すること。
  * L2 スイッチ側で Option 82 挿入動作を無効化すること。

* **設定例:**
```bash
! 1. DHCP Snooping グローバル有効化
ip dhcp snooping
ip dhcp snooping vlan 20

! 2. Option 82 挿入動作の無効化 (L2 スイッチでの必須処理)
no ip dhcp snooping information option

! 3. アップリンクポート (Trusted) 設定
interface GigabitEthernet1/0/24
 switchport mode trunk
 ip dhcp snooping trust
```

* **検証方法:**
  * Gi1/0/5 直下のクライアントから DHCP リクエストを送信し、正常に IP アドレスが取得できることを確認。
  * `show ip dhcp snooping binding` を実行し、MAC-IP バインディングが正常に追記されていることを確認。

---

### ラボ 5: Dynamic ARP Inspection (DAI) ＋ 固定 IP サーバー用 Static ARP ACL 統合

* **問題:** VLAN 10 で DAI を有効化せよ。DHCP クライアントの ARP ポイズニングをブロックしつつ、固定 IP アドレス（10.1.1.100 / MAC: 0050.56a1.b2c3）を使用するサーバーの通信がドロップされないよう救済せよ。

* **設定例:**
```bash
! 1. 固定 IP サーバー救済用の ARP ACL 作成
arp access-list ACL_STATIC_SERVER
 permit ip host 10.1.1.100 mac host 0050.56a1.b2c3

! 2. DAI の有効化と ARP ACL の適用
ip arp inspection vlan 10
ip arp inspection filter ACL_STATIC_SERVER vlan 10 static

! 3. アップリンクポート (Trusted) 設定
interface GigabitEthernet1/0/24
 ip arp inspection trust
```

* **検証方法:**
  * 固定 IP サーバーから ARP パケットを送出し、ドロップされずに転送されることを確認。
  * 偽装 ARP パケットを送信し、`show ip arp inspection statistics` で Dropped カウンタが増加することを確認。

---

### ラボ 6: IP Source Guard (IPSG) 静的 IP バインディング構成

* **問題:** ポート Gi1/0/6 で IPSG を有効化せよ。DHCP 未使用の固定 IP 端末（IP: 192.168.10.80 / MAC: 0011.2233.4455）の通信のみを許可し、その他の IP アドレス直打ち通信をブロックせよ。

* **設定例:**
```bash
! 1. 静的 IP バインディングの登録
ip source binding 0011.2233.4455 vlan 10 192.168.10.80 interface GigabitEthernet1/0/6

! 2. インターフェイスでの IPSG 有効化
interface GigabitEthernet1/0/6
 switchport mode access
 switchport access vlan 10
 ip verify source
```

* **検証方法:**
  * 端末の IP を 192.168.10.80 に設定して通信が疎通することを確認。
  * 端末の IP を 192.168.10.81 に変更し、Ping がドロップすることを確認。
  * `show ip verify source` で Filter IP が `192.168.10.80` となっていることを確認。

---

### ラボ 7: Port Security Sticky MAC ＋ Restrict Violation 構成

* **問題:** ポート Gi1/0/7 において、最初に接続された 2 台の MAC アドレスを動的に Sticky 学習して永続化せよ。3 台目以降の未許可 MAC が接続された場合はパケットをドロップし、Syslog 通知および違反カウンタの加算を行わせよ（ポートは Shutdown させないこと）。

* **設定例:**
```bash
interface GigabitEthernet1/0/7
 switchport mode access
 switchport access vlan 10
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation restrict
 switchport port-security mac-address sticky
```

* **検証方法:**
  * 許可端末 2 台から通信を発生させ、`show running-config interface GigabitEthernet1/0/7` 内に `switchport port-security mac-address sticky <MAC>` が自動追記されるのを確認。
  * 3 台目の端末を接続し、通信がドロップし Syslog メッセージが出力されることを確認。
  * `show port-security interface GigabitEthernet1/0/7` で SecurityViolation カウントが増加していることを確認。

---

### ラボ 8: Port Security 違反に伴う Err-disable 自動復旧設計

* **問題:** ポート Gi1/0/8 で Port Security 違反（Violation Shutdown）が発生してポートがダウンした場合、管理者の手動介入なしに 3 分（180 秒）で自動復旧するようグローバル設計せよ。

* **設定例:**
```bash
! インターフェイスでの Port Security 設定 (デフォルト Violation Shutdown)
interface GigabitEthernet1/0/8
 switchport mode access
 switchport access vlan 10
 switchport port-security

! グローバルでの Err-disable 自動復旧設定
errdisable recovery cause psecure-violation
errdisable recovery interval 180
```

* **検証方法:**
  * 未許可 MAC アドレスのパケットを送信し、ポートを `err-disabled` 状態に落とす。
  * `show errdisable recovery` を実行し、`psecure-violation` の Timer status が `Enabled` であり、TimeToEnable がカウントダウンされているのを確認。

---

### ラボ 9: Dynamic ARP Inspection (DAI) Header Validation 強化構成

* **問題:** VLAN 10 において DAI を有効化し、単なる Snooping DB 照合だけでなく、ARP パケットヘッダー内の「送信元 MAC 不一致（src-mac）」「宛先 MAC 不一致（dst-mac）」「不正 IP アドレス（ip）」の追加検証をハードウェアレベルで強制せよ。

* **設定例:**
```bash
! DAI ヘッダー検証の強化
ip arp inspection validate src-mac dst-mac ip
ip arp inspection vlan 10
```

* **検証方法:**
  * イーサネットヘッダーの Source MAC と ARP ペイロード内の Sender MAC が異なる偽装 ARP パケットを送信する。
  * `show ip arp inspection statistics` を確認し、`Invalid Source MAC Addresses` などの検証エラーによりドロップがカウントされることを確認。

---

### ラボ 10: DAI Rate Limit 超過回避と DoS 防御最適化構成

* **問題:** アクセスポート Gi1/0/10 において、DAI の過剰な制限による誤遮断を防ぐため、許容レートを 40 pps に引き上げよ。また、爆発的な ARP ストームが発生してポートが Shutdown した場合、2 分で自動復旧させよ。

* **設定例:**
```bash
! 1. インターフェイスでの DAI レート制限拡張
interface GigabitEthernet1/0/10
 switchport mode access
 switchport access vlan 10
 ip arp inspection limit rate 40

! 2. Err-disable 自動復旧設定
errdisable recovery cause dhcp-rate-limit
errdisable recovery interval 120
```

* **検証方法:**
  * 毎秒 30 パケットの ARP を送信し、ポートがダウンしないことを確認。
  * 毎秒 60 パケットの ARP ストームを送信し、即座に `err-disabled` 化することを確認。
  * 120 秒後に自動的に `no shutdown` 処理が行われ復旧することを確認。

---

## ❓ 想定試験問題

### 問 1 (トラブルシューティング)
**シナリオ:** アクセススイッチ SW1 の VLAN 10 にて DHCP Snooping および DAI を有効化し、アップリンク Gi1/0/24 を `ip dhcp snooping trust` に設定した。しかし、クライアント PC が DHCP で正常に IP アドレスを取得した直後、ルータ（10.1.1.1）への Ping 通信が全ドロップした。
**設問:** この障害の直接的原因と、SW1 で実行すべき修正コマンドを答えよ。

* **解答:**
  * **原因:** アップリンクポート Gi1/0/24 において `ip arp inspection trust` が設定されていないため。DHCP Snooping の Trust 設定のみでは ARP パケットの検証は免除されず、ルータからの ARP レスポンスが Untrusted ポートからの不正 ARP と判定されてドロップされた。
  * **修正コマンド:**
    ```bash
    interface GigabitEthernet1/0/24
     ip arp inspection trust
    ```

---

### 問 2 (Design & Behavior)
**シナリオ:** L2 アクセススイッチ配下の端末が DHCP アドレスを取得しようとしたところ、DHCP リクエストパケットが上流の Cisco IOS-XE DHCP サーバーでドロップされた。キャプチャログを確認すると、パケットに Option 82 が含まれており、`giaddr` フィールドが `0.0.0.0` であった。
**設問:** Cisco IOS-XE DHCP サーバーがこのパケットをドロップした技術的理由と、L2 スイッチ側で取るべき回避策コマンドを述べよ。

* **解答:**
  * **技術的理由:** Cisco IOS-XE DHCP サーバーは、リレーエージェント（`giaddr != 0`）を経由していない直付けパケット（`giaddr == 0.0.0.0`）に Option 82 が挿入されている場合、不審なパケット（セキュリティ違反）と判定してデフォルトで破棄する仕様であるため。
  * **回避策コマンド (L2 スイッチ側):**
    ```bash
    no ip dhcp snooping information option
    ```

---

### 問 3 (コンフィグ読解)
**シナリオ:** 以下のコンフィグが設定されたスイッチポートにおいて、許可されていない 3 台目の MAC アドレスを持つ端末がパケットを送信した。
```bash
interface GigabitEthernet1/0/8
 switchport mode access
 switchport port-security
 switchport port-security maximum 2
 switchport port-security violation restrict
```
**設問:** このポートの状態（Link Status）、トラフィックの処理、Syslog の出力有無、およびセキュリティ違反カウンタの挙動について説明せよ。

* **解答:**
  * **Link Status:** ポートはダウンせず `Up` 状態を維持する。
  * **トラフィック処理:** 3 台目の未許可端末からのパケットは即座にドロップ（破棄）される。
  * **Syslog 出力:** `SecurityViolation` に関する Syslog メッセージおよび SNMP Trap が発生・送信される。
  * **違反カウンタ:** `show port-security interface` で確認できる `SecurityViolation` カウンタが加算される。

---

### 問 4 (実装・DAI & Static ARP)
**シナリオ:** VLAN 20 で DAI が有効化されている環境において、DHCP を使用せず固定 IP アドレス（192.168.20.50 / MAC: 0011.2233.4455）を設定した監視カメラが追加された。この監視カメラの ARP 通信が DAI で遮断されないよう設定を追加したい。
**設問:** 必要となる ARP ACL の定義および VLAN 20 へのバインドコマンドを記述せよ。

* **解答:**
  ```bash
  ! 1. ARP ACL の作成
  arp access-list ACL_CAMERA_SAVER
   permit ip host 192.168.20.50 mac host 0011.2233.4455

  ! 2. DAI フィルターの適用
  ip arp inspection filter ACL_CAMERA_SAVER vlan 20 static
  ```

---

### 問 5 (TCAM Pipeline)
**シナリオ:** 物理ポート GigabitEthernet1/0/1（VLAN 10 に所属）に入力されたパケットに対し、PACL、VACL (VLAN Map)、および SVI 10 の RACL (Inbound) がすべて設定されている。
**設問:** このパケットがスイッチ内部で評価される正確な順序を答えよ。

* **解答:**
  1. **PACL (Port ACL)** (物理ポート Gi1/0/1 Inbound)
  2. **VACL (VLAN Access Map)** (VLAN 10 内評価)
  3. **RACL (Routed ACL)** (SVI 10 Inbound - ルーティング処理時のみ)

---

## 🔗 参考リソース

* Cisco Catalyst 9300 Series Switches Security Configuration Guide
* Cisco Command Reference - Security Commands
* Cisco Live BRKSEC-2003 - Layer 2 Security Deep Dive
* Cisco Validated Design (CVD) - Campus Network Security Design Guide
* Cisco Technical Note - Troubleshooting Dynamic ARP Inspection and DHCP Snooping

---

## 📝 補足（Notes）

* **Option 82 と DHCP Relay Agent の関係:** L3 スイッチ（DHCP リレーエージェント）で Snooping を動かす場合は `giaddr` が補填されるためドロップされないが、L2 スイッチ単体で Snooping を有効化した場合は `giaddr == 0.0.0.0` のまま Option 82 が載るため、上流ルータでのドロップ事故が非常に発生しやすい。
* **DAI / IPSG の必須前提条件:** DHCP Snooping が正しく動作し、`show ip dhcp snooping binding` に有効なエントリーが存在しない限り、DAI も IPSG も正常通信を誤ドロップする。設定適用順序には最新の注意を払うこと。


## 🔗 参考リンク

### Cisco Live セッション & スライド
*   [**BRKSEC-2001: Layer 2 Security Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001) - スイッチセキュリティ機能の内部動作と攻撃手法の解説。
*   [**BRKIPV-3134: IPv6 Security in the Local Area with First Hop Security**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPV-3134) - IPv6 環境における RA Guard や ND Inspection などの解説。

### Configuration ガイド
*   [**Cisco Catalyst 9300 Series - Security Configuration Guide (17.x)**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg.html)
*   [**Configuring DHCP Snooping, DAI, and IPSG**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg/m_dhcp_snooping_dai_ipsg.html)。

### テクニカルドキュメント
*   [**Troubleshooting Port Security and Err-disable (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/lan-switching/spanning-tree-protocol/69980-errdisable-recovery.html)。
*   [**VLAN Access Control Lists (VACLs) Design Guide**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-6500-series-switches/10601-90.html)。


## 📝 補足
- このメモは、レイヤ2のセキュリティ機能を単なるコマンドとしてではなく、**インフラ保護の論理的な階層**として整理しています。CCIE ラボ試験では、各機能の `trust` 設定の整合性と、`show` コマンドでバインディングテーブルの有無を即座に確認できることが合格への鍵となります。


