---
layout: default
title: 4.2-Network-security
parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---



## 📝 ラボ学習・設定サンプル例

### サンプル 1: DHCP Snooping + Option 82 無効化構成

* **問題:** スイッチ SW1 の VLAN 10 に接続されたクライアントが DHCP サーバーから IP アドレスを取得できない。上流ルータは Option 82 が含まれる DHCP リクエストを処理できない。
* **要件:**
  - SW1 で VLAN 10 に対して DHCP Snooping を有効化すること。
  - 物理ポート Gi1/0/24（DHCP サーバー宛てアップリンク）を Trust ポートに設定すること。
  - SW1 が DHCP パケットに Option 82 を挿入しないよう設定すること。
* **設定例:**
```text
sw1(config)# ip dhcp snooping
sw1(config)# ip dhcp snooping vlan 10
sw1(config)# no ip dhcp snooping information option

sw1(config)# interface GigabitEthernet1/0/24
sw1(config-if)# switchport mode trunk
sw1(config-if)# ip dhcp snooping trust
```
* **検証方法:**
```text
sw1# show ip dhcp snooping
sw1# show ip dhcp snooping binding
```

---

### サンプル 2: DAI (Dynamic ARP Inspection) ＋ 静的 ARP バインディング設定

* **問題:** VLAN 20 で DAI を有効化したところ、静的 IP アドレスを使用しているプリンタ (IP: 10.20.0.50, MAC: 0011.2233.4455, Port: Gi1/0/5) が通信不能になった。
* **要件:**
  - VLAN 20 で DAI を有効化すること。
  - 静的 IP 端末用の ARP アクセスリストを作成し、DAI に割り当てること。
* **設定例:**
```text
! ARP ACL の作成
sw1(config)# arp access-list STATIC_PRINTER
sw1(config-arp-acl)# permit ip host 10.20.0.50 mac host 0011.2233.4455

! DAI の有効化と ARP ACL の適用
sw1(config)# ip arp inspection vlan 20
sw1(config)# ip arp inspection filter STATIC_PRINTER vlan 20

! アップリンクポートの Trust 設定
sw1(config)# interface GigabitEthernet1/0/24
sw1(config-if)# ip arp inspection trust
```
* **検証方法:**
```text
sw1# show ip arp inspection vlan 20
sw1# show ip arp inspection interfaces
```

---

### サンプル 3: IP Source Guard (IPSG) と IP/MAC 検証

* **問題:** アクセスポート Gi1/0/1 で、未許可な IP アドレスおよび MAC アドレスのパケットをハードウェアレベルで遮断したい。
* **要件:**
  - Gi1/0/1 で IP および MAC アドレスのフィルタリングを行う IPSG を有効化すること。
* **設定例:**
```text
sw1(config)# interface GigabitEthernet1/0/1
sw1(config-if)# switchport mode access
sw1(config-if)# switchport access vlan 10
sw1(config-if)# switchport port-security
sw1(config-if)# ip verify source mac-check
```
* **検証方法:**
```text
sw1# show ip verify source
```

---

### サンプル 4: Private VLAN (PVLAN) 基本構築 (Isolated ＆ Promiscuous)

* **問題:** Web サーバー群（VLAN 101）相互の通信を禁止し、共通のルータ（SVI 100）およびファイアウォール宛てのみ通信を許可したい。
* **要件:**
  - Primary VLAN: 100
  - Secondary Isolated VLAN: 101
  - Gi1/0/1, Gi1/0/2 を Isolated ポートとして設定。
  - Gi1/0/24 を Promiscuous ポートとして設定。
* **設定例:**
```text
sw1(config)# vtp mode transparent

sw1(config)# vlan 101
sw1(config-vlan)# private-vlan isolated

sw1(config)# vlan 100
sw1(config-vlan)# private-vlan primary
sw1(config-vlan)# private-vlan association 101

sw1(config)# interface range GigabitEthernet1/0/1 - 2
sw1(config-if-range)# switchport mode private-vlan host
sw1(config-if-range)# switchport private-vlan host-association 100 101

sw1(config)# interface GigabitEthernet1/0/24
sw1(config-if)# switchport mode private-vlan promiscuous
sw1(config-if)# switchport private-vlan mapping 100 add 101

sw1(config)# interface Vlan100
sw1(config-if)# ip address 10.100.0.1 255.255.255.0
sw1(config-if)# private-vlan mapping 101
```
* **検証方法:**
```text
sw1# show vlan private-vlan
sw1# show interface private-vlan mapping
```

---

### サンプル 5: VLAN Access Control List (VACL / VLAN Map) による特定 IP トラフィック遮断

* **問題:** 同一 VLAN 30 内に存在するクライアント間で、TCP ポート 445 (SMB) 通信のみを完全にドロップし、その他の通信は許可したい。
* **要件:**
  - VACL を使用して VLAN 30 内の SMB (TCP 445) をドロップすること。
* **設定例:**
```text
! ACL の定義
sw1(config)# ip access-list extended ACL_SMB
sw1(config-ext-nacl)# permit tcp any any eq 445

! VLAN Map の定義
sw1(config)# vlan access-map VACL_DROP_SMB 10
sw1(config-access-map)# match ip address ACL_SMB
sw1(config-access-map)# action drop

sw1(config)# vlan access-map VACL_DROP_SMB 20
sw1(config-access-map)# action forward

! VLAN 30 へのバインド
sw1(config)# vlan filter VACL_DROP_SMB vlan-list 30
```
* **検証方法:**
```text
sw1# show vlan filter
sw1# show access-lists ACL_SMB
```

---

### サンプル 6: Port Security ＋ Err-Disable 自動復旧構成

* **問題:** アクセスポート Gi1/0/10 に接続できる MAC アドレスを最大 2 つに制限し、違反時はポートをシャットダウン (`err-disable`) させ、300 秒後に自動復旧させたい。
* **要件:**
  - 最大 MAC 数: 2
  - 違反モード: shutdown
  - 学習方式: Sticky MAC
  - Err-disable 自動復旧有効化 (300秒)
* **設定例:**
```text
sw1(config)# interface GigabitEthernet1/0/10
sw1(config-if)# switchport mode access
sw1(config-if)# switchport port-security
sw1(config-if)# switchport port-security maximum 2
sw1(config-if)# switchport port-security violation shutdown
sw1(config-if)# switchport port-security mac-address sticky

sw1(config)# errdisable recovery cause psecure-violation
sw1(config)# errdisable recovery interval 300
```
* **検証方法:**
```text
sw1# show port-security interface GigabitEthernet1/0/10
sw1# show errdisable recovery
```

---

### サンプル 7: IPv6 RA Guard による 不要な IPv6 ルータ遮断

* **問題:** ユーザーポート Gi1/0/3 から送信される不要な IPv6 Router Advertisement (RA) パケットによって、LAN 内の IPv6 クライアントが誤ったデフォルトゲートウェイを設定してしまう。
* **要件:**
  - RA Guard ポリシーを作成し、Gi1/0/3 でホストロールとして RA を遮断すること。
  - アップリンク Gi1/0/24 でルータロールとして RA を許可すること。
* **設定例:**
```text
! RA Guard ポリシー作成
sw1(config)# ipv6 nd raguard policy RAGUARD_HOST
sw1(config-raguard)# device-role host

sw1(config)# ipv6 nd raguard policy RAGUARD_ROUTER
sw1(config-raguard)# device-role router

! ポート適用
sw1(config)# interface GigabitEthernet1/0/3
sw1(config-if)# ipv6 nd raguard attach-policy RAGUARD_HOST

sw1(config)# interface GigabitEthernet1/0/24
sw1(config-if)# ipv6 nd raguard attach-policy RAGUARD_ROUTER
```
* **検証方法:**
```text
sw1# show ipv6 nd raguard policy
```

---

### サンプル 8: IPv6 Device Tracking (SISF) 制御ポリシー

* **問題:** IPv6 FHS バインディングデータベースを動的生成するために、VLAN 50 に対して Device Tracking を有効化したい。
* **要件:**
  - トラッキングポリシー `POLICY_SISF` を作成し、アドレスバインディング制限を 5 エントリにすること。
* **設定例:**
```text
sw1(config)# device-tracking policy POLICY_SISF
sw1(config-device-tracking)# tracking enable hint
sw1(config-device-tracking)# limit address-count 5

sw1(config)# interface range GigabitEthernet1/0/1 - 10
sw1(config-if-range)# device-tracking attach-policy POLICY_SISF
```
* **検証方法:**
```text
sw1# show device-tracking database
sw1# show device-tracking policy POLICY_SISF
```

---

### サンプル 9: Port ACL (PACL) による L2 ポートダイレクトフィルタリング

* **問題:** 物理ポート Gi1/0/2 に入力されるトラフィックのうち、特定 IP 192.168.1.100 からの ICMP 通信のみをブロックし、その他は許可したい。
* **要件:**
  - PACL を作成し、Gi1/0/2 の Inbound に適用すること。
* **設定例:**
```text
sw1(config)# ip access-list extended PACL_BLOCK_ICMP
sw1(config-ext-nacl)# deny icmp host 192.168.1.100 any
sw1(config-ext-nacl)# permit ip any any

sw1(config)# interface GigabitEthernet1/0/2
sw1(config-if)# ip access-group PACL_BLOCK_ICMP in
```
* **検証方法:**
```text
sw1# show ip interface GigabitEthernet1/0/2
sw1# show access-lists PACL_BLOCK_ICMP
```

---

### サンプル 10: DAI パケットレート制限 ＆ バリデーションチェックの強化

* **問題:** ARP 偽装および ARP フラッドに対処するため、DAI のパケット検証ロジックを強化したい。
* **要件:**
  - DAI で Header の MAC アドレス整合性（Src MAC / Dst MAC）および IP アドレス整合性を検証すること。
  - アクセスポート Gi1/0/4 の ARP レート上限を 20 pps に設定すること。
* **設定例:**
```text
sw1(config)# ip arp inspection validate src-mac dst-mac ip
sw1(config)# ip arp inspection vlan 10

sw1(config)# interface GigabitEthernet1/0/4
sw1(config-if)# ip arp inspection limit rate 20
```
* **検証方法:**
```text
sw1# show ip arp inspection vlan 10
sw1# show ip arp inspection interfaces GigabitEthernet1/0/4
```

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
**問題:** スイッチ SW1 のコンフィグをアサインされた。VLAN 10 で DHCP Snooping および DAI が設定されているが、正当な DHCP クライアントが IP を取得した直後に通信不能になる。以下のコンフィグから原因を特定し、正しく修正しなさい。

```text
ip dhcp snooping
ip dhcp snooping vlan 10
ip arp inspection vlan 10

interface GigabitEthernet1/0/24
 switchport mode trunk
 ip arp inspection trust
```

* **解答・解説:**
  - **原因:** アップリンクポート Gi1/0/24 に `ip arp inspection trust` は設定されているが、`ip dhcp snooping trust` が設定されていない。このため、上流の DHCP サーバーからの DHCPOFFER / DHCPACK パケットが Gi1/0/24 でドロップされ、DHCP Snooping Binding Table が空のままとなる。結果として DAI によりクライアントの ARP がすべてドロップされる。
  - **修正コマンド:**
    ```text
    sw1(config)# interface GigabitEthernet1/0/24
    sw1(config-if)# ip dhcp snooping trust
    ```

---

### 問 2 (Private VLAN 設計)
**問題:** 企業ネットワークで Primary VLAN 100（10.100.0.0/24）、Secondary Community VLAN 101（開発チーム）、Secondary Isolated VLAN 102（ゲスト Wi-Fi）を構成する。開発チーム（VLAN 101）同士は相互通信可能だが、ゲスト（VLAN 102）同士および開発チームとゲスト間は通信不可とし、全端末が SVI 100 経由でインターネットへ到達できるようにしたい。適切な VLAN アソシエーションおよび SVI 設定コマンドを示しなさい。

* **解答・解説:**
```text
sw1(config)# vtp mode transparent
sw1(config)# vlan 101
sw1(config-vlan)# private-vlan community
sw1(config)# vlan 102
sw1(config-vlan)# private-vlan isolated
sw1(config)# vlan 100
sw1(config-vlan)# private-vlan primary
sw1(config-vlan)# private-vlan association 101,102

sw1(config)# interface Vlan100
sw1(config-if)# ip address 10.100.0.1 255.255.255.0
sw1(config-if)# private-vlan mapping 101,102
```

---

### 問 3 (DAI / IP Source Guard トラブルシューティング)
**問題:** アクセスポート Gi1/0/2 で `ip verify source mac-check` を有効化したところ、DHCP で正規に IP アドレスを取得した端末が一切通信できなくなった。`show ip verify source` を確認すると、Filter type が IP のみとなっており、MAC フィルターが適用されていない。何が原因か述べよ。

* **解答・解説:**
  - **原因:** `ip verify source mac-check`（IP + MAC Source Guard）を正常に機能させるためには、ポート上で **Port Security (`switchport port-security`)** が有効化されているか、DHCP Option 82 による MAC アドレスバインディングが存在する必要がある。Port Security が未設定の場合、MAC チェックが無効化されるか通信が阻害される。
  - **修復策:** インターフェイスで `switchport port-security` を有効化する。

---

### 問 4 (IPv6 RA Guard 設定)
**問題:** アクセススイッチ SW1 の全アクセスポートにおいて、外部端末からの IPv6 Router Advertisement (RA) パケットをブロックし、ポート Gi1/0/24（ルータ接続ポート）からのみ RA パケットを受容したい。必要な CLI 設定手順を示しなさい。

* **解答・解説:**
```text
sw1(config)# ipv6 nd raguard policy RAGUARD_HOST_POLICY
sw1(config-raguard)# device-role host

sw1(config)# ipv6 nd raguard policy RAGUARD_ROUTER_POLICY
sw1(config-raguard)# device-role router

sw1(config)# interface range GigabitEthernet1/0/1 - 23
sw1(config-if-range)# ipv6 nd raguard attach-policy RAGUARD_HOST_POLICY

sw1(config)# interface GigabitEthernet1/0/24
sw1(config-if)# ipv6 nd raguard attach-policy RAGUARD_ROUTER_POLICY
```

---

### 問 5 (ACL TCAM 評価順序)
**問題:** 物理ポート Gi1/0/1（VLAN 10 所属）に入力されるパケットに対して、PACL、VACL、RACL がすべて適用されている。同一パケットが入力された際の処理順序を正しく述べなさい。

* **解答・解説:**
  - **処理順序:**
    1. **PACL (Port ACL):** 物理ポート Gi1/0/1 の Inbound で最初に評価。ここで Deny された場合は即座にドロップ。
    2. **VACL (VLAN ACL / VLAN Map):** VLAN 10 内に入力されたパケットとして評価。
    3. **RACL (Router ACL):** パケットがルーティング（別サブネット宛て）される場合、SVI 10 の Inbound RACL として評価。

---

## 🔗 参考リソース

* Cisco Security Configuration Guide, Cisco IOS XE (Catalyst 9300 Switches)
* Cisco Command Reference, Security, Cisco IOS XE
* Cisco Live BRKSEC-2003 - First Hop Security (FHS) Deep Dive
* Cisco Validated Design (CVD) - Campus LAN Design Guide
* IPv6 First-Hop Security Configuration Guide, Cisco IOS XE
* Configuring Private VLANs - Cisco Catalyst 9000 Series Switches

---

## 📝 **補足（Notes）**

### FHS パイプラインとトラブル解決の鉄則
1. **Binding Database の生成タイミング:**
   - DHCP Snooping が正しく動いていない場合、DAI も IPSG も正常に機能しない。トラブル時はまず `show ip dhcp snooping binding` を確認する。
2. **スイッチリブート時の Snooping Binding 保存:**
   - スイッチが再起動すると RAM 上の Snooping Binding が消失し、全端末が通信不能になる恐れがある。実務および高度なテスト環境では `ip dhcp snooping database flash:/binding.db` または TFTP/FTP サーバーへ保存する設定を導入する。
3. **IPv6 SISF (Switch Integrated Security Features) の学習:**
   - IOS-XE 16.x / 17.x 以降、伝統的な IPv6 FHS コマンド群（`ipv6 neighbor binding` 等）は SISF バインディングテーブル（`device-tracking`）に統合されているため、`device-tracking policy` の理解が必須である。
