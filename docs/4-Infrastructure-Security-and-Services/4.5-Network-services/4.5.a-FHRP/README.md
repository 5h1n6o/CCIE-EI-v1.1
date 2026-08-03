---
layout: default
title: 4.5.a-FHRP
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.5.a First-Hop Redundancy Protocols (FHRP)

本ページでは、ネットワークのハイアベイラビリティ（高可用性）を支えるゲートウェイ冗長化技術、**FHRP (First-Hop Redundancy Protocols)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。

---

## 📘 概要

**First-Hop Redundancy Protocols (FHRP)** は、ホストデバイスのデフォルトゲートウェイを冗長化するための技術群です。通常、ホストは 1 つの IP アドレスをゲートウェイとして設定しますが、そのインターフェイスやルータが故障すると通信が途絶えます。FHRP を使用することで、複数の物理ルータを 1 つの「仮想ルータ」としてホストに見せることができ、障害発生時も瞬時にバックアップ機へ切り替えることが可能になります。

1.  **HSRP (Hot Standby Router Protocol):** シスコ独自のプロトコルで、Active/Standby 構成をとります。
2.  **VRRP (Virtual Router Redundancy Protocol):** IEEE 標準のプロトコルで、Master/Backup 構成をとります。
3.  **IPv6 RS/RA:** IPv6 のネイティブ機能（近隣探索プロトコル）を使用した冗長化です。

---

## 🔑 要点

### 1. HSRP (Hot Standby Router Protocol) (i)

*   **役割:** 1 台の **Active** ルータがトラフィックを転送し、1 台の **Standby** ルータが待機します。
*   **仮想 MAC アドレス:** 
    *   v1: `0000.0c07.acXX` (XX はグループ ID)。
    *   v2: `0000.0c9f.fXXX` (XXX はグループ ID)。
*   **バージョン:** v2 では IPv6 がサポートされ、グループ ID の範囲が拡張（0-4095）されています。
*   **認証:** 平文または MD5 認証をサポートします。

### 2. VRRP (Virtual Router Redundancy Protocol) (i)

*   **役割:** 1 台の **Master** ルータと、複数台の **Backup** ルータで構成されます。
*   **特徴:** 物理インターフェイスの IP アドレスを仮想 IP として使用可能です。その場合、そのルータが強制的に Master になります。
*   **プリエンプション:** デフォルトで有効（HSRP はデフォルト無効）です。

### 3. IPv6 における冗長化 (ii)

*   **HSRP/VRRP for IPv6:** 基本的な動作は IPv4 と同様ですが、ゲートウェイとして **リンクローカルアドレス (FE80::)** を仮想 IP として使用するのが一般的です。
*   **RS (Router Solicitation) / RA (Router Advertisement):** 
    *   ホストは RS を送信してルータを探し、ルータは定期的な RA で自身の存在を知らせます。
    *   RA 内の **Default Router Preference** (High/Medium/Low) を調整することで、特定のルータを優先的なゲートウェイとして動作させることが可能です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる冗長化の設定に留まらず、外部の障害に連動した切り替え（Deterministic Failover）が求められます。

### 1. オブジェクトトラッキング (Object Tracking)

*   **シナリオ:** 「自身の LAN 側 IF が生きていても、WAN 側 IF が DOWN したら Standby に降格せよ」といった要件。
*   **実装:** `track` コマンドを使用してインターフェイス状態や IP SLA の結果を監視し、異常検知時にプライオリティを減算（decrement）させます。

### 2. プリエンプション (Preemption) の制御

*   障害から復旧したルータが、より高いプライオリティを持っている場合に役職を奪い返す動作です。
*   試験では `preempt delay` を設定し、ルーティングプロトコルの収束を待ってから Active に戻るような高度な設計が問われます。

### 3. IPv6 Link-Local ゲートウェイの整合性

*   IPv6 環境では、ホストはゲートウェイとして仮想 IPv6 アドレス（Global Unicast）ではなく、RA で通知されたリンクローカルアドレスを学習します。
*   HSRP for IPv6 を設定する際は、仮想リンクローカルアドレスを明示的に指定（`standby [ID] ipv6 autoconfig` 等）するスキルの有無が確認されます。

---

## 🛠 設定・検証コマンド

### HSRP 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **仮想IPの設定** | <code>standby [group] ip [virtual-ip]</code> |
| **優先順位の設定** | <code>standby [group] priority</code> |
| **プリエンプションの有効化** | <code>standby [group] preempt</code> |
| **オブジェクトトラッキング** | <code>standby [group] track [object-id] decrement [value]</code> |
| **MD5認証の設定** | <code>standby [group] authentication md5 key-string [key]</code> |
| **HSRP v2の有効化** | <code>standby version 2</code> |

### VRRP 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **仮想IPの設定** | <code>vrrp [group] ip [virtual-ip]</code> |
| **優先順位の設定** | <code>vrrp [group] priority</code> |
| **トラッキングの設定** | <code>vrrp [group] track [object-id] decrement [value]</code> |

### IPv6 冗長化 (RA/ND)

| 目的 | コマンド |
| :--- | :--- |
| **RA優先度の変更** | <code>ipv6 nd router-preference [High&#124;Medium&#124;Low]</code> |
| **RA送信間隔の変更** | <code>ipv6 nd ra-interval [seconds]</code> |

### 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **HSRPの状態サマリ** | <code>show standby brief</code> |
| **HSRPの詳細情報確認** | <code>show standby</code> |
| **VRRPの状態サマリ** | <code>show vrrp brief</code> |
| **IPv6近隣探索の確認** | <code>show ipv6 neighbor</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な HSRP 構成

**【課題】** R1 と R2 の間で HSRP グループ 1 を構成し、仮想 IP 192.168.1.254 を設定せよ。
```ios
interface GigabitEthernet0/1
 standby 1 ip 192.168.1.254
```

### 2. 優先順位とプリエンプション

**【課題】** R1 を Active ルータとし、障害復旧時に自動で Active に戻るようにせよ。
```ios
interface GigabitEthernet0/1
 standby 1 priority 110
 standby 1 preempt
```

### 3. インターフェイス・トラッキング

**【課題】** WAN 側 IF (Gi0/0) が DOWN した場合、HSRP 優先度を 20 減らして切り替えを誘発せよ。
```ios
track 10 interface GigabitEthernet0/0 line-protocol
!
interface GigabitEthernet0/1
 standby 1 track 10 decrement 20
```

### 4. MD5 認証による保護

**【課題】** HSRP メッセージに MD5 認証を適用し、キーを `ccie123` とせよ。
```ios
interface GigabitEthernet0/1
 standby 1 authentication md5 key-string ccie123
```

### 5. HSRP v2 による IPv6 冗長化

**【課題】** IPv6 環境で HSRP v2 を使用し、仮想 IP `2001:DB8::254` を設定せよ。
```ios
interface GigabitEthernet0/1
 standby version 2
 standby 1 ipv6 2001:DB8::254
```

### 6. VRRP 基本構成

**【課題】** VRRP グループ 10 を作成し、R2 を優先度 200 で Master にせよ。
```ios
interface GigabitEthernet0/1
 vrrp 10 ip 192.168.1.254
 vrrp 10 priority 200
```

### 7. IPv6 RA によるデフォルトゲートウェイ優先度調整

**【課題】** R1 の RA 優先度を `High` に設定し、ホストが R1 を優先的に選ぶようにせよ。
```ios
interface GigabitEthernet0/1
 ipv6 nd router-preference High
```

### 8. IP SLA と連動した HSRP トラッキング

**【課題】** 外部 8.8.8.8 への Ping が失敗した場合に Active から降格せよ。
```ios
ip sla 1
 icmp-echo 8.8.8.8
 frequency 5
ip sla schedule 1 start-time now life forever
track 1 ip sla 1 reachability
!
interface Gi0/1
 standby 1 track 1 decrement 30
```

### 9. HSRP グループ名の設定

**【課題】** 管理を容易にするため、HSRP グループに `DATA_VLAN` という名前を付けよ。
```ios
interface GigabitEthernet0/1
 standby 1 name DATA_VLAN
```

### 10. IPv6 リンクローカル仮想アドレスの自動生成

**【課題】** HSRP で IPv6 リンクローカルアドレスを自動構成させよ。
```ios
interface Tunnel23
 standby 1 ipv6 autoconfig
```

### 11. HSRP タイマーの微調整 (高速 failover)

**【課題】** 障害検知を 1 秒以内にするため、hello を 200ms、hold を 750ms にせよ。
```ios
interface GigabitEthernet0/1
 standby 1 timers msec 200 msec 750
```

### 12. VRRP 認証の設定

**【課題】** VRRP で平文パスワード `vrrp_key` による認証を行え。
```ios
interface GigabitEthernet0/1
 vrrp 10 authentication text vrrp_key
```

---

## 🔗 参考リソースリンク

### Cisco Live セッション
*   [**BRKCRS-2031: Redundancy Protocol Deep Dive (HSRP/VRRP)**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2031)
*   [**BRKIPV-2101: IPv6 First Hop Security and Redundancy**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPV-2101)

### Configuration ガイド
*   [**Cisco IOS XE 17.x First Hop Redundancy Protocols Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipapp_fhrp/configuration/xe-17/fhrp-xe-17-book.html)。
*   [**Configuring HSRP for IPv6 Support**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipapp_fhrp/configuration/15-mt/fhrp-15-mt-book/fhrp-hsrp-ipv6.html)。

### テクニカルドキュメント
*   [**HSRP vs VRRP Features Comparison (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/hot-standby-router-protocol-hsrp/10583-62.html)。
*   [**Understanding IPv6 Router Advertisement Preference (RFC 4191)**](https://tools.ietf.org/html/rfc4191)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験において FHRP が単なる冗長化ではなく、**「トラフィックフローの決定的な制御（Deterministic Flow Control）」**の鍵であることを示しています。ラボ試験では、`show standby brief` でプライオリティ値が意図した通りに減算され、役職が切り替わっているかを検証する習慣をつけてください。


