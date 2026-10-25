---
layout: default
title: 4.5.c-DHCP
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.5.c DHCP on Cisco devices

## 📘 概要

DHCP（Dynamic Host Configuration Protocol）は、IP ネットワーク上の端末（クライアント）に対して、IP アドレス、サブネットマスク、デフォルトゲートウェイ、DNS サーバー、その他各種オプション情報を動的かつ自動的に割り当てるプロトコルである。IPv4 環境（DHCPv4）および IPv6 環境（DHCPv6）の双方で提供され、大規模網における IP アドレス管理の省力化と集中制御を実現する。

CCIE Enterprise Infrastructure (EI) v1.1 Blueprint において、DHCP は単なる端末の IP 自動取得機能にとどまらず、**Option 82 情報を活用したリレイ代理制御**、**AP（Access Point）向け Option 43 や Voice IP Phone 向け Option 150 の配布**、さらには **IPv6 SLAAC（Stateless Address Autoconfiguration）とのフラグ連携（M/O ビット）**、**Stateful / Stateless DHCPv6**、および **DHCPv6 Prefix Delegation（PD）による階層的プレフィックス自動割り当て** に至るまで、高度な制御メカニズムの実装・トラブルシューティング能力が厳格に問われる。

### 主な利用目的と利用場面

1. **IPv4/IPv6 アドレスの自動割り当てと管理の集中化**
   * アクセス層セグメント（キャンパス LAN、リモート拠点）における大量エンドポイントへの動的 IP 配布。
   * インターフェイス指定や MAC アドレス指定による静的バインディング割り当て。
2. **オプション情報による高度なネットワークサービス連携**
   * **Option 82（DHCP Relay Agent Information）:** スイッチポート番号や VLAN ID 情報を挿入し、DHCP Snooping や DAI（Dynamic ARP Inspection）と連携した IP 偽装防止・セキュリティ強化。
   * **Option 43 / 60:** Cisco Catalyst AP に対する WLC（Wireless LAN Controller）IP アドレスの自動通知。
   * **Option 150:** Cisco IP Phone に対する TFTP サーバー IP アドレスの通知。
3. **IPv6 ネットワークにおける自動アドレス生成・情報配布**
   * **SLAAC ＋ Stateless DHCPv6:** RA（Router Advertisement）によるプレフィックス生成と、DHCPv6 による DNS/NTP サーバーアドレスの同時配布。
   * **Stateful DHCPv6:** IPv4 同様、DHCPv6 サーバーによる IPv6 アドレスの一元プール管理。
   * **DHCPv6 Prefix Delegation (PD):** ISP 側（Provider）から CPE 側（Subscriber）へ IPv6 プレフィックスを動的割り当てし、CPE 配下の LAN インターフェイスへ自動サブネット分割・定義。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **主要機能** | DHCPv4/v6 Client、Server、Relay Agent、Option 処理、SLAAC/DHCPv6 統合、DHCPv6 Prefix Delegation (PD) |
| **動作層** | アプリケーション層（UDP トランスポート）<br>• DHCPv4: Client (UDP 68) ⇄ Server (UDP 67)<br>• DHCPv6: Client (UDP 546) ⇄ Server/Relay (UDP 547) |
| **IPv6 アドレス生成方式** | • **SLAAC (M=0, O=0):** RA のみで Address ＆ Gateway 生成<br>• **Stateless DHCPv6 (M=0, O=1):** RA で Address 生成 ＋ DHCPv6 で DNS 等取得<br>• **Stateful DHCPv6 (M=1, O=1/0):** DHCPv6 サーバーから Address ＆ オプション一括取得 |
| **DHCPv6 Prefix Delegation** | ISP/親ルータ（Provider）から子ルータ（Subscriber）へ `/48` や `/56` などのプレフィックスを自動割り当てし、子ルータが自身の LAN インターフェイスへ `/64` を自動展開する機能 |
| **主なメリット** | IP 管理コスト削減、誤設定の防止、アドレス枯渇の防止、無線 AP/IP Phone/CPE のゼロタッチプロビジョニング |
| **制限事項 ＆ 注意点** | • リレイ代理（Relay Agent）経由時、ブロードキャストパケットはユニキャストへ変換される。<br>• Option 82 挿入時、デフォルトでは `giaddr` が `0.0.0.0` のパケットをドロップするため `ip dhcp relay information trust-all` や `ip dhcp snooping information option allow-untrusted` の設計が必須。<br>• DHCPv6 ではデフォルトゲートウェイアドレス（Gateway IP）は配布されず、常に RA（Link-Local）から学習する。 |

---

## 🏗 動作原理

### 1. DHCPv4 4-Way ハンドシェイク（DORA）と Relay 変換原理

DHCPv4 のアドレス割り当ては、**DISCOVER**, **OFFER**, **REQUEST**, **ACK** の 4 段階パケット交換（DORA プロセス）で行われる。

```
Client               Relay Agent (Switch/Router)               DHCPv4 Server
  |                              |                                   |
  |--- DHCPDISCOVER ------------->|                                   |
  |    (L2/L3 Broadcast)         |--- DHCPDISCOVER (Unicast) -------->|
  |                              |    (giaddr = Client Subnet SVI)   |
  |                              |                                   |
  |                              |<-- DHCPOFFER (Unicast) -----------|
  |<-- DHCPOFFER ----------------|                                   |
  |    (Broadcast / Unicast)     |                                   |
  |                              |                                   |
  |--- DHCPREQUEST ------------->|                                   |
  |                              |--- DHCPREQUEST (Unicast) --------->|
  |                              |                                   |
  |                              |<-- DHCPACK (Unicast) -------------|
  |<-- DHCPACK ------------------|                                   |
```

* **DHCPDISCOVER:** クライアントが L2/L3 ブロードキャスト（`255.255.255.255`）で送信。
* **Relay Agent の介在:** `ip helper-address <SERVER_IP>` が設定されたインターフェイス（SVI/物理）は、ブロードキャストを受信すると、自身の IP アドレスを `giaddr`（Gateway IP Address）フィールドに書き込み、DHCP サーバーへユニキャスト転送する。Option 82 が有効な場合、Circuit ID（VLAN/Port）および Remote ID（MAC/Switch名）をパケット末尾に付加する。
* **DHCPOFFER:** サーバーは `giaddr` を参照して適切な IP プールを選択し、利用可能な IP アドレスとオプション情報を返信。
* **DHCPREQUEST:** クライアントが提示されたオファーの受諾をネットワーク全体に通知（他サーバーへの拒否通知を兼ねる）。
* **DHCPACK:** サーバーが正式に IP 貸与（Lease）を確定して応答。

---

### 2. IPv6 SLAAC ＆ DHCPv6 統合フラグメカニズム（M ビット / O ビット）

IPv6 では、ルータが周期的に送出（またはクライアントの RS に応答）する ICMPv6 Type 134 **RA（Router Advertisement）** パケット内の 2 つのフラグ（**M ビット**, **O ビット**）によって、クライアントのアドレス生成動作が制御される。

```
Router (RA Sender) -----------------------------> IPv6 Host Client
  | RA (M-bit, O-bit)                             |
  +-----------------------------------------------+
  
  [ケース 1] M=0, O=0 : Pure SLAAC
            --> クライアントは RA の Prefix ＋ EUI-64 / Random ID で IP 生成。
            --> DHCPv6 は一切使用しない。

  [ケース 2] M=0, O=1 : Stateless DHCPv6
            --> クライアントは RA の Prefix で IP 生成。
            --> クライアントは INFORMATION-REQUEST (UDP 547) を送信し、DNS/NTP 等のみ取得。

  [ケース 3] M=1, O=1/0 : Stateful DHCPv6
            --> クライアントは RA による Address 生成を行わない（または補助）。
            --> クライアントは SOLICIT (UDP 547) を送信し、DHCPv6 サーバーから IPv6 Address ＋ オプションを一括取得。
```

---

### 3. DHCPv6 Prefix Delegation (PD) 動作原理

DHCPv6 PD は、ISP や上位コア階層（Delegating Router）が、拠点ルータ（Requesting Router）に対して `/48` や `/56` などの大きな IPv6 プレフィックスブロックを動的に割り当て、受領した拠点ルータが配下の LAN インターフェイスに `/64` サブネットを自動展開する技術である。

```
Delegating Router (ISP/Core)                   Requesting Router (CPE/Edge)
         |                                                   |
         |<--- SOLICIT (IA_PD 要求) --------------------------|
         |---> ADVERTISE (IA_PD 提示: 2001:db8:1234::/48) ----|
         |<--- REQUEST --------------------------------------|
         |---> REPLY (IA_PD 確定) ----------------------------|
         |                                                   |
         |                                    [配下 LAN インターフェイス]
         |                                    Gi0/1: 2001:db8:1234:1::/64 (自動定義)
         |                                    Gi0/2: 2001:db8:1234:2::/64 (自動定義)
```

---

## ⚙ 動作シーケンス

### IPv4 DHCP (DORA) ＋ Option 82 パケット処理シーケンス

```
[DHCPv4 Client]          [Access Switch (Option 82/Relay)]        [DHCPv4 Server]
      |                                 |                                |
1.    |-- DHCPDISCOVER (Broadcast) ---->|                                |
      |   (Src: 0.0.0.0, Dst: 255...)   |                                |
      |                                 | 2. Option 82 付加              |
      |                                 |    • Circuit ID: VLAN 10, Port Gi0/1
      |                                 |    • Remote ID: Switch MAC     |
      |                                 |    • giaddr: 192.168.10.1      |
      |                                 |-- DHCPDISCOVER (Unicast) ----->|
      |                                 |   (Src: 192.168.10.1, Dst: Server)
      |                                 |                                |
      |                                 | 3. プール特定 & IP 払い出し判定|
      |                                 |<-- DHCPOFFER (Unicast) --------|
      |<-- DHCPOFFER (Unicast/Bcast) ---|                                |
4.    |-- DHCPREQUEST ----------------->|-- DHCPREQUEST (Unicast) ------>|
      |<-- DHCPACK ---------------------|<-- DHCPACK (Unicast) ----------|
5.    | (IP 取得完了: 192.168.10.105)   |                                |
```

### DHCPv6 4-Way メッセージシーケンス (SOLICIT / ADVERTISE / REQUEST / REPLY)

DHCPv6 の Stateful 割り当ておよび Prefix Delegation では、以下の 4 メッセージが使用される（必要に応じて 2-Way の RAPID-COMMIT オプションも使用可能）。

1. **SOLICIT:** クライアント（または Requesting Router）が全 DHCPv6 サーバー/リレイマルチキャストアドレス（`FF02::1:2`）宛てに送信。`IA_NA`（Non-temporary Address）や `IA_PD`（Prefix Delegation）オプションを含める。
2. **ADVERTISE:** DHCPv6 サーバーが利用可能な IPv6 アドレスまたは プレフィックスブロックを提示。
3. **REQUEST:** クライアントが特定のサーバー（DUID: DHCP Unique Identifier）を選択してアドレス/プレフィックス割り当てを要求。
4. **REPLY:** サーバーが割り当て（IP / Prefix / DNS / Lease Time）を確定して応答。



## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で重要なポイント

CCIE EI ラボ試験における DHCP 関連の出題パターンは、単なる「ルータを DHCP サーバーにする」だけにとどまらず、**複数技術の複合構成とネガティブ要件（制限事項）のクリア** が中心となる。

1. **DHCP Option の正確な定義（Hex 変換含む）**
   * **Option 150 (Voice TFTP):** `option 150 ip <TFTP_IP1> <TFTP_IP2>`
   * **Option 43 (WLC IP for AP):** Hex 表記での入力要件。例: WLC IP `192.168.200.10` ➔ Type `06`（Cisco AP 用）、Length `04`（IP 1個分: 4バイト）、IP ASCII/Hex `C0 A8 C8 0A` ➔ `option 43 hex 0604c0a8c80a`。
   * **Option 60 (Vendor Class Identifier):** AP のベンダー識別文字列（例: `"VCI-Cisco AP c9120"`）のマッチング。
2. **Option 82 ＋ DHCP Snooping 信頼関係障害の回避**
   * スイッチで `ip dhcp snooping` を有効化すると、Option 82 が自動挿入される。しかし、上位ルータ（Relay Agent/Server）側で `giaddr` が `0.0.0.0` のOption 82 付き DISCOVER を「不審なパケット」とみなしてドロップする問題が発生する。
   * **回避策:** ルータ側で `ip dhcp relay information trust-all` を投入するか、スイッチ側で `no ip dhcp snooping information option allow-untrusted` または `ip dhcp snooping information option` を適切に制御する。
3. **VRF-Aware DHCP Relay ＆ IP Pool**
   * 顧客 VRF（例: `vrf RED`）配下のインターフェイスでリレイを設定する場合: `ip helper-address vrf RED <SERVER_IP>`。
   * ルータ上の DHCP サーバー側で VRF ごとにプールを分離する場合: `ip dhcp pool POOL_RED` 内で `vrf RED` をバインド。
4. **SLAAC / Stateless / Stateful DHCPv6 フラグの厳格な制御**
   * 要求仕様に応じた RA フラグ設定:
     * Pure SLAAC: `no ipv6 nd managed-config-flag`, `no ipv6 nd other-config-flag`
     * Stateless DHCPv6: `no ipv6 nd managed-config-flag`, **`ipv6 nd other-config-flag`**
     * Stateful DHCPv6: **`ipv6 nd managed-config-flag`**, **`ipv6 nd other-config-flag`**
5. **DHCPv6 Prefix Delegation (PD) の統合設定**
   * Delegating Router (Provider) 側: `ipv6 dhcp pool PD_POOL` ➔ `prefix-delegation pool LOCAL_PREFIX_POOL`
   * Requesting Router (CPE) 側: 外側 I/F `ipv6 dhcp client pd MY_PD` ➔ 内側 I/F `ipv6 address MY_PD ::1/64`

---

## 🛠 設定方法

### 1. DHCPv4 Server ＋ Option 43 / 150 ＋ Exclusion 設定

```bash
! 1. 除外 IP アドレスの設定（ルータ/SVI/VIP 用）
ip dhcp excluded-address 192.168.10.1 192.168.10.20
ip dhcp excluded-address 192.168.10.254

! 2. DHCPv4 IP プールの定義
ip dhcp pool LAN_VOICE_DATA
   host-name-routers-optional
   network 192.168.10.0 255.255.255.0
   default-router 192.168.10.1
   dns-server 8.8.8.8 1.1.1.1
   domain-name ccie.local
   lease 1 12 0 ! 1日 12時間
   
   ! Option 150 (Cisco IP Phone 用 TFTP サーバー IP)
   option 150 ip 192.168.10.250 192.168.10.251
   
   ! Option 43 (Cisco AP 用 WLC IP: 192.168.200.10 -> 0604c0a8c80a)
   option 43 hex 0604c0a8c80a
```

### 2. VRF-Aware DHCP Relay Agent ＋ Option 82 信頼設定

```bash
! 1. Relay Agent 上での Option 82 信頼設定
ip dhcp relay information trust-all

! 2. VRF インターフェイス配下での Helper Address 設定
interface GigabitEthernet0/1.100
   encapsulation dot1Q 100
   vrf forwarding TENANT_A
   ip address 10.100.1.1 255.255.255.0
   
   ! VRF TENANT_A 内の DHCP サーバーへリレイ (Option 82 保持)
   ip helper-address vrf TENANT_A 10.200.1.254
```

### 3. Stateless ＆ Stateful DHCPv6 Server 設定

```bash
! --- [Stateless DHCPv6 Server 設定] ---
ipv6 dhcp pool STATELESS_POOL
   dns-server 2001:4860:4860::8888
   domain-name ccie-v6.local

interface GigabitEthernet0/0/1
   ipv6 address 2001:db8:100::1/64
   ipv6 dhcp server STATELESS_POOL
   no ipv6 nd managed-config-flag
   ipv6 nd other-config-flag   ! O-bit = 1 (Stateless)

! --- [Stateful DHCPv6 Server 設定] ---
ipv6 dhcp pool STATEFUL_POOL
   address prefix 2001:db8:200::/64 lifetime 172800 86400
   dns-server 2001:4860:4860::8888
   domain-name stateful.local

interface GigabitEthernet0/0/2
   ipv6 address 2001:db8:200::1/64
   ipv6 dhcp server STATEFUL_POOL
   ipv6 nd managed-config-flag ! M-bit = 1 (Stateful)
   ipv6 nd other-config-flag   ! O-bit = 1
```

### 4. DHCPv6 Prefix Delegation (PD) Provider / Subscriber 設定

```bash
! === [Delegating Router (Provider) 側] ===
ipv6 local pool REGION_PREFIXES 2001:db8:1000::/48 56 ! /56 ずつ分割

ipv6 dhcp pool PROVIDER_PD_POOL
   prefix-delegation pool REGION_PREFIXES lifetime 86400 43200

interface GigabitEthernet0/0/0
   description WAN-to-CPE
   ipv6 address 2001:db8:0:1::1/64
   ipv6 dhcp server PROVIDER_PD_POOL

! === [Requesting Router (CPE/Subscriber) 側] ===
interface GigabitEthernet0/0/0
   description WAN-from-ISP
   ipv6 address dhcp
   ipv6 dhcp client pd SITE_PREFIX ! 受領した PD に識別名 "SITE_PREFIX" を命名

interface GigabitEthernet0/0/1
   description LAN-Segment-1
   ipv6 address SITE_PREFIX ::1:0:0:0:1/64 ! 受領した PD からサブネット生成

interface GigabitEthernet0/0/2
   description LAN-Segment-2
   ipv6 address SITE_PREFIX ::2:0:0:0:1/64
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **DHCPv4 貸与（Lease）確認** | `show ip dhcp binding` |
| **DHCPv4 プール利用状況・枯渇確認** | `show ip dhcp pool [POOL_NAME]` |
| **DHCPv4 衝突（Conflict）アドレス確認** | `show ip dhcp conflict` |
| **DHCPv4 Relay 統計情報確認** | `show ip dhcp server statistics` |
| **DHCPv6 バインディング確認** | `show ipv6 dhcp binding` |
| **DHCPv6 プール設定・ステート確認** | `show ipv6 dhcp pool` |
| **DHCPv6 Prefix Delegation (PD) 受領確認** | `show ipv6 dhcp interface` |
| **DHCPv6 ルーティング・PD プレフィックス確認** | `show ipv6 route dhcp` |
| **DHCPv4 パケットデバッグ** | `debug ip dhcp server packet` / `event` |
| **DHCPv6 パケットデバッグ** | `debug ipv6 dhcp detail` / `relay` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **Client が IP アドレスを取得できない（0.0.0.0）** | ① スイッチポートの VLAN 割り当てミス<br>② DHCP サーバー側の IP プール枯渇<br>③ `ip helper-address` 設定漏れ | • `show ip dhcp pool`<br>• `show ip dhcp conflict`<br>• `show run int <INT>` | ① Port VLAN の見直し<br>② `ip dhcp pool` のサブネット拡張または Lease Time 調整<br>③ `ip helper-address <SERVER_IP>` を追加 |
| **Relay 経由時、サーバーで DISCOVER が破棄される** | Option 82 がスイッチで付加されたが、Relay Agent/Server 間で不審パケット（`giaddr=0.0.0.0`）として判定ドロップされた | • `show ip dhcp server statistics`<br>• `debug ip dhcp server packet` | • リレイ側で `ip dhcp relay information trust-all` を適用<br>• スイッチ側で `no ip dhcp snooping information option` |
| **IPv6 クライアントが DHCPv6 から IP を取得しない** | RA（Router Advertisement）パケット内の `M-bit`（Managed Config Flag）が `0` のまま | • `show ipv6 interface <INT>`<br>• `debug ipv6 nd` | 該当インターフェイスで `ipv6 nd managed-config-flag` を設定し M ビットを 1 に変更 |
| **DHCPv6 PD で LAN 側の IPv6 アドレスが生成されない** | クライアント（CPE）側で受領した PD 識別名と、LAN インターフェイスで指定した PD 識別名が不一致 | • `show ipv6 dhcp interface`<br>• `show ipv6 route dhcp` | WAN ポートの `ipv6 dhcp client pd <NAME>` と LAN ポートの `ipv6 address <NAME> ::1/64` の `<NAME>` を一致させる |
| **特定端末に常に同じ IP が割り当たらない** | `host` 形式の静的バインディング時、`client-identifier`（01+MAC）の記述形式不備 | `show ip dhcp binding` | Client ID を `01xx.xxxx.xxxx.xx` 形式で正しく設定（MAC アドレスの先頭に `01` ヘッダーを付与） |

---

## ⚠ 制限事項

* **DHCPv6 にはデフォルトゲートウェイ配布機能が存在しない:**
  * DHCPv6 プロトコル（RFC 8415 / 旧 RFC 3315）には、デフォルトゲートウェイのアドレスをオプションとして指定するフィールドが存在しない。
  * IPv6 クライアントは、必ず RA（Router Advertisement）から送信元ルータの Link-Local アドレス（`FE80::/10`）を取得してデフォルトゲートウェイとして設定する。
* **Option 82 処理時の安全設計要件:**
  * Cisco IOS XE では、`ip dhcp snooping` を有効にするとデフォルトで Option 82 が付加される。中継するルータで `ip dhcp relay information trust-all` が設定されていない場合、パケットが静かに破棄されるため設計時の考慮が必須である。
* **DHCPv6 Prefix Delegation の割り当てサイズ:**
  * Delegating Router 側で定義する `ipv6 local pool` のプレフィックス長（例: `/48`）と分割長（例: `/56`）は、配下 Requesting Router が要求する階層構造と整合していなければならない。

---

## 🔄 他技術との関連

* **DHCP Snooping / DAI (Dynamic ARP Inspection) / IP Source Guard:**
  * スイッチ上で DHCP パケットを監視し、L2 ポート・MAC アドレス・IP アドレスのバインディングテーブル（`DHCP Snooping Binding Table`）を動的生成。これを基盤として DAI や IP Source Guard が動作する。
* **802.1X / Cisco ISE / Wireless LAN Controller (WLC):**
  * WLC を発見するための **Option 43**、Cisco IP Phone 用の **Option 150**、RADIUS 認証時の Profiling 情報として Option 55 (Parameter Request List) や Option 60 (VCI) が活用される。
* **SLAAC / ICMPv6 Neighbor Discovery (ND):**
  * IPv6 におけるアドレス自動生成基盤。RA パケットの M/O ビット変更によって、SLAAC と DHCPv6（Stateless/Stateful）の動作モードを切り替える。

---

## 🧩 比較表

### DHCPv4 vs DHCPv6 (Stateless / Stateful) 比較

| 項目 | DHCPv4 | IPv6 SLAAC | Stateless DHCPv6 | Stateful DHCPv6 |
| :--- | :--- | :--- | :--- | :--- |
| **アドレス生成者** | DHCPv4 Server | Host (SLAAC / EUI-64) | Host (SLAAC / EUI-64) | DHCPv6 Server |
| **RA M/O フラグ** | N/A | M=0, O=0 | M=0, O=1 | M=1, O=1 (または O=0) |
| **提供情報** | IP, Mask, GW, DNS 等 | Prefix, Gateway (RA) | Prefix, GW ＋ **DNS/NTP** | **IP**, **DNS/NTP** (GWはRA) |
| **通信ポート** | UDP 67 / 68 | ICMPv6 (Type 133/134) | UDP 546 / 547 | UDP 546 / 547 |
| **クライアント識別** | MAC / Client ID | EUI-64 / DUID | DUID | DUID (IAID + DUID) |
| **サーバー管理簿** | あり (Binding) | なし | なし (オプションのみ) | **あり (Binding Table)** |

---

## 💡 ベストプラクティス

1. **ルータ/スイッチの自アドレスを除外指定 (`ip dhcp excluded-address`)**
   * DHCP IP プールを定義する前に、必ずルータの SVI アドレス、Default Gateway アドレス、静的 IP 割り当て機器のアドレス範囲を除外設定する。
2. **リレイ代理環境における Option 82 信頼設定の徹底**
   * キャンパス網で DHCP Snooping を使用する場合、コア/ディストリビューション層の Relay Agent にて `ip dhcp relay information trust-all` を明示設定し、不要なパケットドロップを防止する。
3. **IPv6 ネットワークにおける SLAAC ＋ Stateless DHCPv6 の第一選択**
   * 大規模環境では、クライアント管理のオーバーヘッドが少ない **Stateless DHCPv6（M=0, O=1）** を第一選択とし、アドレスは SLAAC で高速生成させつつ、DNS アドレスのみ DHCPv6 で配布する構成が推奨される。
4. **DHCP プールの Lease Time の最適化**
   * ゲスト Wi-Fi 網など流動性の高いセグメントでは Lease Time を短く設定（例: 2〜4時間）し、アドレス枯渇を防ぐ。オフィス wired 網では 1〜3 日程度に設定する。



## 📝 ラボ学習・設定サンプル例

### ラボ 1: DHCPv4 Server ＆ Relay Agent (Option 82) 構成

#### 【問題】
R1 を DHCPv4 サーバー、R2 を DHCP Relay Agent とし、Client 端末が属する VLAN 10（192.168.10.0/24）に対して IP アドレス、デフォルトゲートウェイ、DNS サーバーを自動配布しなさい。その際、Relay Agent で Option 82 が付加されてもパケットがドロップされないよう信頼設定を行いなさい。

#### 【要件】
1. R1 上に IP プール `POOL_VLAN10` を作成し、ネットワーク `192.168.10.0/24`、デフォルトゲートウェイ `192.168.10.1`、DNS `8.8.8.8` を配布すること。
2. IP `192.168.10.1` 〜 `192.168.10.10` は除外（Excluded）とすること。
3. R2 の Gi0/1（192.168.10.1/24）から受信した DISCOVER を R1 の Loopback0（10.1.1.1/32）宛てにリレイすること。
4. R1 上で Option 82 情報を含むリレイパケットを受信許可（Trust）する設定を追加すること。

#### 【設定例】

```bash
! === [R1 (DHCPv4 Server) の設定] ===
ip dhcp excluded-address 192.168.10.1 192.168.10.10

! Option 82 付きの giaddr 判定信頼設定
ip dhcp relay information trust-all

ip dhcp pool POOL_VLAN10
   network 192.168.10.0 255.255.255.0
   default-router 192.168.10.1
   dns-server 8.8.8.8
   domain-name ccie.local

interface Loopback0
   ip address 10.1.1.1 255.255.255.255

interface GigabitEthernet0/0
   ip address 10.1.12.1 255.255.255.0

! === [R2 (DHCP Relay Agent) の設定] ===
ip dhcp relay information trust-all

interface GigabitEthernet0/1
   description Client-VLAN10
   ip address 192.168.10.1 255.255.255.0
   ip helper-address 10.1.1.1
```

#### 【検証方法】
```bash
! R1 でのバインディングおよびプール状態確認
R1# show ip dhcp binding
IP address       Client-ID/              Lease termination    Type
                 Hardware address/
                 User Name
192.168.10.11    0150.5400.1234.56       Oct 26 2026 08:00 AM Automatic

R1# show ip dhcp pool POOL_VLAN10
Pool POOL_VLAN10 :
 Utilization mark (high/low)    : 100 / 0
 Subnet size (Used/Total)       : 1 / 244
```

---

### ラボ 2: DHCPv4 Vendor Specific Options (Option 43 / Option 150) 構成

#### 【問題】
キャンパス網の AP 接続用 VLAN 20（192.168.20.0/24）および IP Phone 接続用 VLAN 30（192.168.30.0/24）に対して、それぞれ Cisco WLC IP アドレスを通知する Option 43、および Voice TFTP サーバー IP を通知する Option 150 を含む DHCPv4 プールを構成しなさい。

#### 【要件】
1. VLAN 20（`POOL_AP`）: WLC IP `10.200.1.10`（Hex: `0604c0a8c10a`）を Option 43 として配布すること。
2. VLAN 30（`POOL_VOICE`）: TFTP サーバー IP `10.200.1.50` および `10.200.1.51` を Option 150 として配布すること。

#### 【設定例】

```bash
! === [R1 (DHCPv4 Server) の設定] ===
! Option 43 の Hex 値計算: Type(06) + Length(04) + 10.200.1.10(c0 a8 c1 0a) = 0604c0a8c10a
ip dhcp pool POOL_AP
   network 192.168.20.0 255.255.255.0
   default-router 192.168.20.1
   dns-server 10.200.1.1
   option 43 hex 0604c0a8c10a

ip dhcp pool POOL_VOICE
   network 192.168.30.0 255.255.255.0
   default-router 192.168.30.1
   option 150 ip 10.200.1.50 10.200.1.51
```

#### 【検証方法】
```bash
R1# show ip dhcp pool POOL_AP
R1# show ip dhcp pool POOL_VOICE
! クライアント端末側で IP 取得後、Option 43/150 が反映されていることを確認
```

---

### ラボ 3: SLAAC ＋ Stateless DHCPv6 (O-bit=1, M-bit=0) 構成

#### 【問題】
IPv6 セグメント `2001:db8:100::/64` において、クライアント端末が SLAAC（Stateless Address Autoconfiguration）によって IPv6 アドレスを動的割り当てし、DNS サーバーアドレスなどの追加オプション情報のみを Stateless DHCPv6 サーバーから取得するようにルータを構成しなさい。

#### 【要件】
1. RA パケットの M ビットを `0`、O ビットを `1` に設定すること。
2. DHCPv6 プール `STATELESS_POOL` を定義し、DNS `2001:4860:4860::8888` および ドメイン名 `ccie-v6.local` を設定すること。

#### 【設定例】

```bash
! === [R1 (Stateless DHCPv6 Server / Router) の設定] ===
ipv6 unicast-routing

ipv6 dhcp pool STATELESS_POOL
   dns-server 2001:4860:4860::8888
   domain-name ccie-v6.local

interface GigabitEthernet0/0/1
   ipv6 address 2001:db8:100::1/64
   ipv6 dhcp server STATELESS_POOL
   no ipv6 nd managed-config-flag   ! M-bit = 0
   ipv6 nd other-config-flag     ! O-bit = 1
```

#### 【検証方法】
```bash
R1# show ipv6 interface GigabitEthernet0/0/1
GigabitEthernet0/0/1 is up, line protocol is up
  Hosts use stateless autoconfig for addresses.
  Hosts use DHCP to obtain other configuration. ! O-bit=1 確認
```

---

### ラボ 4: Stateful DHCPv6 Server ＆ Relay Agent (M-bit=1) 構成

#### 【問題】
R1 を Stateful DHCPv6 サーバー、R2 を DHCPv6 Relay Agent とし、配下セグメント `2001:db8:200::/64` の端末に対して、DHCPv6 サーバーから一括で IPv6 アドレスと DNS サーバー情報を配布しなさい。

#### 【要件】
1. R2 の Gi0/1 で送出する RA パケットの M ビットを `1`（`ipv6 nd managed-config-flag`）に設定すること。
2. R2 の Gi0/1 で受信した DHCPv6 SOLICIT（UDP 547）を、R1 の Gi0/0（`2001:db8:12::1`）宛てにリレイすること。

#### 【設定例】

```bash
! === [R1 (Stateful DHCPv6 Server) の設定] ===
ipv6 unicast-routing

ipv6 dhcp pool STATEFUL_POOL
   address prefix 2001:db8:200::/64 lifetime 172800 86400
   dns-server 2001:4860:4860::8888
   domain-name stateful.local

interface GigabitEthernet0/0
   ipv6 address 2001:db8:12::1/64
   ipv6 dhcp server STATEFUL_POOL

! === [R2 (DHCPv6 Relay Agent) の設定] ===
ipv6 unicast-routing

interface GigabitEthernet0/0
   ipv6 address 2001:db8:12::2/64

interface GigabitEthernet0/1
   description Client-Segment
   ipv6 address 2001:db8:200::1/64
   ipv6 nd managed-config-flag   ! M-bit = 1
   ipv6 nd other-config-flag     ! O-bit = 1
   ipv6 dhcp relay destination 2001:db8:12::1
```

#### 【検証方法】
```bash
R1# show ipv6 dhcp binding
Client: FE80::5054:FF:FE12:3456 
  DUID: 00030001505400123456
  IA NA: IA ID 0x00000001, T1 43200, T2 69120
    Address: 2001:db8:200:0:1234:5678:9abc:def0
      preferred lifetime 86400, valid lifetime 172800
```

---

### ラボ 5: DHCPv6 Prefix Delegation (PD) Provider-Subscriber 構成

#### 【問題】
ISP ルータ（R1 / Provider）から CPE ルータ（R2 / Subscriber）に対して `/56` の IPv6 プレフィックスを動的委任（Prefix Delegation）し、受領した R2 が自身の LAN1（Gi0/1）および LAN2（Gi0/2）に `/64` サブネットを自動展開するように設定しなさい。

#### 【要件】
1. R1 上でローカルプール `ISP_PREFIXES`（`2001:db8:8800::/40`）から `/56` 単位で切り出して委任すること。
2. R2 は受領した PD プレフィックス識別名を `BRANCH_PD` と命名し、LAN1 に `::1:0:0:0:1/64`、LAN2 に `::2:0:0:0:1/64` を定義すること。

#### 【設定例】

```bash
! === [R1 (Delegating Router / Provider) の設定] ===
ipv6 unicast-routing

ipv6 local pool ISP_PREFIXES 2001:db8:8800::/40 56

ipv6 dhcp pool PD_PROVIDER_POOL
   prefix-delegation pool ISP_PREFIXES lifetime 86400 43200

interface GigabitEthernet0/0
   ipv6 address 2001:db8:12::1/64
   ipv6 dhcp server PD_PROVIDER_POOL

! === [R2 (Requesting Router / Subscriber) の設定] ===
ipv6 unicast-routing

interface GigabitEthernet0/0
   description WAN-Interface
   ipv6 address dhcp
   ipv6 dhcp client pd BRANCH_PD ! PD 受領名を "BRANCH_PD" と命名

interface GigabitEthernet0/1
   description LAN-Segment-1
   ipv6 address BRANCH_PD ::1:0:0:0:1/64 ! 例: 2001:db8:8800:1::1/64 自動生成

interface GigabitEthernet0/2
   description LAN-Segment-2
   ipv6 address BRANCH_PD ::2:0:0:0:1/64 ! 例: 2001:db8:8800:2::1/64 自動生成
```

#### 【検証方法】
```bash
R2# show ipv6 dhcp interface GigabitEthernet0/0
GigabitEthernet0/0 is in client mode
  Prefix State is OPEN
  Delegated Prefix: 2001:DB8:8800:100::/56 [RELEASED]

R2# show ipv6 interface brief
GigabitEthernet0/1     [up/up]
    FE80::5054:FF:FE12:3456
    2001:DB8:8800:101::1
GigabitEthernet0/2     [up/up]
    FE80::5054:FF:FE12:3457
    2001:DB8:8800:102::1
```

---

### ラボ 6: VRF-Aware DHCPv4 Relay Agent 構成

#### 【問題】
R1 上で管理されている VRF `TENANT_RED` 配下のインターフェイス（Gi0/1.100）において、テナント専用 DHCP サーバー（10.200.1.254）宛てに VRF を維持したまま DHCP DISCOVER パケットをリレイするように構成しなさい。

#### 【要件】
1. VRF `TENANT_RED` のインターフェイス Gi0/1.100（10.100.1.1/24）で `ip helper-address vrf TENANT_RED 10.200.1.254` を設定すること。
2. リレイ代理での Option 82 パケット転送時に VRF 情報が破棄されないよう設定すること。

#### 【設定例】

```bash
! === [R1 (VRF-Aware Relay Agent) の設定] ===
vrf definition TENANT_RED
   rd 65000:100
   address-family ipv4
   exit-address-family

ip dhcp relay information trust-all

interface GigabitEthernet0/1.100
   encapsulation dot1Q 100
   vrf forwarding TENANT_RED
   ip address 10.100.1.1 255.255.255.0
   ip helper-address vrf TENANT_RED 10.200.1.254
```

#### 【検証方法】
```bash
R1# show ip dhcp statistics
R1# debug ip dhcp server packet
! VRF 内でのユニキャストリレイ転送ログを確認
```

---

### ラボ 7: DHCP Server IP Pool Smart-Relay ＆ Exclusion 構成

#### 【問題】
単一インターフェイス上に複数サブネット（Primary ＋ Secondary）が存在する環境において、一次サブネット（Primary）の IP アドレスプールが枯渇した場合に、自動的に二次サブネット（Secondary）の IP アドレスから貸与を行う Smart-Relay 機能を設定しなさい。

#### 【要件】
1. `ip dhcp smart-relay` をグローバルで有効化すること。
2. プール `POOL_PRIMARY`（192.168.1.0/24）および `POOL_SECONDARY`（192.168.2.0/24）を構成すること。

#### 【設定例】

```bash
! === [R1 (DHCP Server) の設定] ===
ip dhcp smart-relay

ip dhcp pool POOL_PRIMARY
   network 192.168.1.0 255.255.255.0
   default-router 192.168.1.1

ip dhcp pool POOL_SECONDARY
   network 192.168.2.0 255.255.255.0
   default-router 192.168.1.1

interface GigabitEthernet0/1
   ip address 192.168.1.1 255.255.255.0
   ip address 192.168.2.1 255.255.255.0 secondary
```

#### 【検証方法】
```bash
R1# show ip dhcp pool POOL_PRIMARY
R1# show ip dhcp pool POOL_SECONDARY
```

---

### ラボ 8: Static DHCPv4 Host Binding (Client-Identifier) 構成

#### 【問題】
特定のエンドポイント端末（MAC アドレス: `5054.ab12.3456`）に対して、常に特定 IP アドレス `192.168.10.200` を静的予約割り当て（Static Host Binding）しなさい。

#### 【要件】
1. プール名 `STATIC_PRINTER` を定義すること。
2. `client-identifier` を使用し、Ethernet メディアタイプ識別子 `01` を MAC アドレスの先頭に付加して指定すること（`0150.54ab.1234.56`）。

#### 【設定例】

```bash
! === [R1 (DHCP Server) の設定] ===
ip dhcp pool STATIC_PRINTER
   host 192.168.10.200 255.255.255.0
   client-identifier 0150.54ab.1234.56
   default-router 192.168.10.1
   client-name Secret_Printer
```

#### 【検証方法】
```bash
R1# show ip dhcp binding
IP address       Client-ID/              Lease termination    Type
                 Hardware address/
                 User Name
192.168.10.200   0150.54ab.1234.56       Infinite             Manual
```

---

### ラボ 9: DHCPv6 Guard ＆ Snooping 連携構成

#### 【問題】
L2 アクセススイッチ（SW1）において、未承認の不正 DHCPv6 サーバー（Rogue DHCPv6 Server）からの ADVERTISE メッセージ送出を遮断し、正規の DHCPv6 サーバーポート（Gi0/0）からの通信のみを許可する DHCPv6 Guard ポートポリシーをアタッチしなさい。

#### 【要件】
1. `ipv6 dhcp guard policy` 名 `DHCPV6_GUARD_POLICY` を作成し、`device-role client` と設定すること。
2. アクセスポート（Gi0/1 〜 Gi0/24）に政策をアタッチすること。
3. アップリンクポート（Gi0/0）には `device-role server` ポリシーをアタッチすること。

#### 【設定例】

```bash
! === [SW1 (Access Switch) の設定] ===
ipv6 dhcp guard policy CLIENT_POLICY
   device-role client

ipv6 dhcp guard policy SERVER_POLICY
   device-role server

interface range GigabitEthernet0/1 - 24
   ipv6 dhcp guard attach-policy CLIENT_POLICY

interface GigabitEthernet0/0
   ipv6 dhcp guard attach-policy SERVER_POLICY
```

#### {検証方法】
```bash
SW1# show ipv6 dhcp guard policy
SW1# show device-tracking database
```

---

### ラボ 10: Client-side DHCPv4 / DHCPv6 統合受信用インターフェイス構成

#### 【問題】
ルータ R2 の WAN インターフェイス（Gi0/0）において、IPv4 では DHCPv4 Client、IPv6 では Stateful DHCPv6 ＋ Prefix Delegation 受信クライアントとして同時に動作させる複合設定を構築しなさい。

#### 【要件】
1. IPv4 アドレスを DHCP 経由で取得すること (`ip address dhcp`)。
2. IPv6 アドレスを DHCPv6 経由で取得し、同時に PD 名 `WAN_PD` を受領すること。

#### 【設定例】

```bash
! === [R2 (Multi-Protocol Client Router) の設定] ===
interface GigabitEthernet0/0
   description Dual-Stack-WAN-Client
   ip address dhcp
   ipv6 address dhcp
   ipv6 dhcp client pd WAN_PD
   no shutdown
```

#### 【検証方法】
```bash
R2# show ip interface GigabitEthernet0/0
GigabitEthernet0/0 is up, line protocol is up
  Internet address is 192.168.100.105/24 (Address determined by DHCP)

R2# show ipv6 interface GigabitEthernet0/0
GigabitEthernet0/0 is up, line protocol is up
  IPv6 is enabled, link-local address is FE80::5054:FF:FE12:3456
  Global unicast address(es):
    2001:DB8:100::105, subnet is 2001:DB8:100::/64 [DHCP]
```



## ❓ 想定試験問題

### 問 1 (トラブルシューティング / Option 82 パケットドロップ)

**【問題】**  
スイッチ SW1 で `ip dhcp snooping` を有効化し、上位のディストリビューションルータ R1（DHCP Relay Agent）を経由して DHCP サーバー R2 へ接続したところ、クライアント端末が一切 IP アドレスを取得できなくなりました。R1 のインターフェイス（Gi0/1）には `ip helper-address 10.200.1.254` が設定されており、R1 ⇄ R2 間の導通は正常です。R1 上で確認すべきログ/機能と、最小限のコマンドでこの障害を解決する修正設定を答えなさい。

**【解答・解説】**  
* **原因:** SW1 上で DHCP Snooping が有効化されたことにより、DHCPDISCOVER パケットに Option 82（Circuit ID / Remote ID）が自動挿入された。しかし、R1（Relay Agent）上で `giaddr` が `0.0.0.0` のパケットを受信した際、Cisco IOS XE の標準動作として不審なパケットとみなして無効判定（ドロップ）された。
* **確認コマンド:** `show ip dhcp server statistics` または `debug ip dhcp server packet` を実行すると、`Option 82 with giaddr zero dropped` または `Bad option 82` ログが記録される。
* **修正コマンド:** R1（Relay Agent）のグローバルコンフィグで以下を設定する。
  ```bash
  R1(config)# ip dhcp relay information trust-all
  ```
  （または SW1 側で `no ip dhcp snooping information option` を投入して Option 82 の挿入自体を無効化する）。

---

### 問 2 (コンフィグ読解 / SLAAC ＋ DHCPv6 フラグ制御)

**【問題】**  
以下のコンフィグが設定されたルータ R1 の配下セグメント（Gi0/0/1）に接続された IPv6 クライアントの動作として正しい説明を選びなさい。

```bash
interface GigabitEthernet0/0/1
   ipv6 address 2001:db8:abc::1/64
   ipv6 dhcp server MY_DHCPV6_POOL
   no ipv6 nd managed-config-flag
   ipv6 nd other-config-flag
```

1. クライアントは DHCPv6 サーバーから IPv6 アドレスと DNS サーバーアドレスの両方を取得する。
2. クライアントは SLAAC によって IPv6 アドレスを自己生成し、DHCPv6 サーバーから DNS サーバーアドレス等の補足オプション情報のみを取得する。
3. クライアントは SLAAC のみを使用し、DHCPv6 サーバーとの通信は一切行わない。
4. クライアントは IPv6 アドレスの自動生成に失敗する。

**【解答・解説】**  
* **正解:** **2**
* **解説:** `no ipv6 nd managed-config-flag`（M ビット = 0）かつ `ipv6 nd other-config-flag`（O ビット = 1）は、**Stateless DHCPv6** モードの定義である。クライアントは RA のプレフィックス `2001:db8:abc::/64` から SLAAC（EUI-64 または Random ID）によって IPv6 アドレスを生成し、DNS などの補足情報は DHCPv6 サーバーへ INFORMATION-REQUEST パケット（UDP 547）を送信して取得する。

---

### 問 3 (Design / DHCPv6 Prefix Delegation 階層設計)

**【問題】**  
企業ネットワークにおいて、データセンターのコア領域ルータ（Delegating Router）から、各拠点ルータ（Requesting Router）に対して DHCPv6 Prefix Delegation (PD) を使用して動的に IPv6 サブネットを割り当てる設計を行いたい。拠点ルータ配下には 4 つの個別 LAN セグメント（VLAN 10, 20, 30, 40）が存在し、それぞれ標準の `/64` プレフィックスを必要とする。このとき、Delegating Router 側で割当プールから各拠点ルータに対して委任すべき**最小のプレフィックス長**はどれか。

1. `/64`
2. `/62`
3. `/56`
4. `/48`

**【解答・解説】**  
* **正解:** **2**
* **解説:** 各 LAN セグメントに `/64` プレフィックスを 4 つ割り当てる必要がある。プレフィックス長計算において、4 つのサブネットを確保するためには 2^2 = 4 であるため 2 ビットのアドレス空間（`/64 - 2 = /62`）が必要となる。したがって、拠点ルータへ最小 `/62`（または業界推奨の `/56` / `/48`）のブロックを委任することで、拠点ルータが内部で 4 つの `/64` サブネット（例: `::0/64`, `::1/64`, `::2/64`, `::3/64`）を切り出して自動展開することが可能となる。

---

### 問 4 (トラブルシューティング / IPv6 デフォルトゲートウェイ非配布問題)

**【問題】**  
Stateful DHCPv6 サーバーとして正常に機能している R1（`ipv6 nd managed-config-flag` 設定済み）から、クライアント端末が IPv6 アドレス（`2001:db8:100::105`）および DNS サーバー（`2001:4860:4860::8888`）を正常に取得できました。しかし、クライアント端末から外部ネットワーク宛ての通信が一切行えません。クライアントのルーティングテーブルを確認すると、デフォルトゲートウェイ（`::/0`）が設定されていませんでした。この原因と対処方法を説明しなさい。

**【解答・解説】**  
* **原因:** DHCPv6 プロトコル規格（RFC 8415）には、デフォルトゲートウェイアドレスを直接通知するオプションフィールドが存在しない。IPv6 におけるデフォルトゲートウェイの学習は、**常にルータが送出する ICMPv6 RA（Router Advertisement）パケットの送信元 Link-Local アドレス（`FE80::/10`）に依存**する。
* **対処方法:** R1 のインターフェイス上で Router Advertisement の送出が停止されていないか（`ipv6 nd suppress-ra` が設定されていないか）を確認し、RA が周期的に送信されるように設定する。また、RA の Router Lifetime が `0` になっていないことを確認する。

---

### 問 5 (実装 / 特定 MAC アドレスへの Static DHCPv4 予約)

**【問題】**  
Cisco IOS XE DHCPv4 サーバーにおいて、MAC アドレス `a1b2.c3d4.e5f6` を持つ特定のプリンタ端末に対し、常に固定 IP アドレス `10.10.10.250/24` を予約割り当てするコンフィグを作成しなさい。

**【解答・解説】**  
```bash
ip dhcp pool STATIC_PRINTER_POOL
   host 10.10.10.250 255.255.255.0
   client-identifier 01a1.b2c3.d4e5.f6 ! 先頭に Ethernet メディアタイプ 01 を付加
   default-router 10.10.10.1
```
* **ポイント:** `hardware-address` を使用する代わりに `client-identifier` を使用する場合、先頭に 1 バイトのメディアタイプ（Ethernet の場合は `01`）を付加してドット区切りで指定することが重要である。

---

## 🔗 参考リソース

CCIE EI v1.1 の学習メモとして活用できる Cisco 公式ドキュメントおよび技術資料です。

* **Cisco IOS XE 17.x IP Addressing Configuration Guide: DHCP Options**
* **Cisco IOS XE IPv6 Configuration Guide: IPv6 Addressing and Basic Connectivity**
* **Cisco Technical Support: Understanding DHCP Option 82 and Snooping Integration**
* **Cisco Technical Support: Configuring DHCP Option 43 for Lightweight Access Points**
* **Cisco Live BRKARC-2020: Advanced DHCP and IPv6 Infrastructure Security**
* **Cisco Live BRKRST-2301: Enterprise IPv6 Deployment and DHCPv6 Prefix Delegation Design**

---

## 📝 補足（Notes）

### 💡 試験直前チェックリスト

1. **Option 82 パケットドロップ回避の対呪文**
   * Relay Agent 側: `ip dhcp relay information trust-all`
   * Snooping Switch 側: `no ip dhcp snooping information option`
2. **Option 43 Hex 計算マスター**
   * `06` (Type: Cisco AP) + `04` (Length: IP 1個 4バイト) + `c0 a8 c1 0a` (192.168.193.10) ➔ `0604c0a8c10a`
3. **IPv6 M/O フラグマトリクス**
   * Pure SLAAC ➔ M=0, O=0
   * Stateless DHCPv6 ➔ M=0, O=1 (`ipv6 nd other-config-flag`)
   * Stateful DHCPv6 ➔ M=1, O=1 (`ipv6 nd managed-config-flag`)
4. **DHCPv6 ゲートウェイの真実**
   * DHCPv6 からデフォルトゲートウェイは配られない。常に RA (Link-Local) から自動取得される。





## 🔗 参考リンク

### Cisco Live 関連動画・スライド
*   [**BRKCCIE-3000: CCIE EI Lab Exam Overview**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000) - インフラサービスの重要性。
*   [**BRKRST-3320: IPv6 Planning, Deployment and Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - DHCPv6 と SLAAC の詳細設計。

### Configuration ガイド
*   [**IP Addressing: DHCP Configuration Guide (Cisco IOS XE)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_dhcp/configuration/xe-17/dhcp-xe-17-book.html)。
*   [**IPv6 Addressing and Basic Connectivity Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipv6/configuration/xe-17/ipv6-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Understanding DHCP Option 82 (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/dynamic-host-configuration-protocol-dhcp/119134-technote-dhcp-00.html)。
*   [**IPv6 Stateful and Stateless DHCPv6 Configuration Example**](https://www.cisco.com/c/en/us/support/docs/ip/ip-address-assignment/113110-dhcpv6-config-example.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験において **DHCP が単なるアドレス配布ではなく、IPv6 の設計思想や VRF の分離、さらには管理自動化（ZTP等）の根幹** であることを示しています。各モードのフラグ管理とリレーの挙動を、実際のパケットフローをイメージしながら習得することが合格への鍵となります。


