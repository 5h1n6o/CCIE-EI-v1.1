---
layout: default
title: 4.2.c-IPv6-security
parent: 4.2-Network-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 3
---

# 4.2.c IPv6 Infrastructure Security Features

IPv6 環境におけるアクセス層のセキュリティ、通称 **IPv6 First-Hop Security (FHS)** は、CCIE Enterprise Infrastructure (EI) ラボ試験において非常に重要かつ複雑なトピックです。従来の IPv4 における DHCP Snooping や DAI に相当する機能が、IPv6 ではより洗練された「ポリシーベース」のフレームワークで提供されます。

---

## 📘 概要

IPv6 は近隣探索プロトコル（NDP）やステートレスアドレス自動設定（SLAAC）など、IPv4 にはない動的なメカニズムに依存しています。これらは利便性が高い反面、悪意のあるルータ広告（RA）や近隣広告（NA）による中間者攻撃（MITM）や、不正な DHCPv6 サーバによるアドレス配布のリスクを孕んでいます。

**IPv6 First-Hop Security (FHS)** は、スイッチを通過するレイヤ2コントロールプレーンメッセージ（ICMPv6 および DHCPv6）を検査し、ネットワークの完全性を保護する一連の機能群です。これらすべての機能の中核には、パケットから学習した IP-MAC-Port-VLAN の対応付けを管理する **Binding Table (結合テーブル)** が存在します。

---

## 🔑 要点

### (i) RA Guard

*   **目的:** 認可されていないデバイス（ホスト等）からの不正な Router Advertisement (RA) パケットをブロックします。
*   **動作:** スイッチポートを「trusted（信頼済み）」または「untrusted（未信頼）」として分類し、未信頼ポートからの RA を破棄します。
*   **モード:**
    *   **Stateless:** パケットの属性（送信元等）のみをチェック。
    *   **Stateful:** 結合テーブルや特定の条件を維持してチェック（高度な実装）。

### (ii) DHCP Guard

*   **目的:** 不正な DHCPv6 サーバやリレーエージェントからの広告（ADVERTISE, REPLY 等）をブロックします。
*   **動作:** RA Guard と同様に、未信頼ポートから届く「サーバ側」の DHCPv6 メッセージを遮断します。

### (iii) Binding Table

*   **役割:** 全 FHS 機能の「情報の源（Source of Truth）」です。
*   **ソース:** NDP スヌーピング、DHCPv6 スヌーピング、または静的なエントリから情報を収集し、データベースを構築します。

### (iv) Device Tracking

*   **目的:** ネットワークに接続されている IPv6 ホストの生存状態を監視し、結合テーブルの整合性を維持します。
*   **進化:** 以前の `ipv6 neighbor-tracking` 等の個別コマンドは、現在 `device-tracking` ポリシーに統合されています。

### (v) ND Inspection / Snooping

*   **目的:** IPv4 の DAI に相当します。Neighbor Solicitation (NS) や Neighbor Advertisement (NA) を検査し、アドレスのスプーフィングを防止します。
*   **動作:** 結合テーブルと照合し、正当な MAC/IP ペアを持たない NA メッセージをドロップします。

### (vi) Source Guard
*   **目的:** 未承認の IPv6 送信元アドレスを持つパケットの転送をレイヤ2レベルで阻止します。
*   **動作:** 結合テーブルに基づいて動的なポート ACL (PACL) を生成し、許可されていないソースからのトラフィックを遮断します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なるコマンドの羅列ではなく、**「ポリシーの作成」と「インターフェイスへの適用」**という 2 段階のプロセスが問われます。

1.  **ポリシー階層の理解:**
    多くの FHS 機能は `ipv6 nd inspection policy [NAME]` や `ipv6 ra-guard policy [NAME]` のように、まずグローバルでポリシーを定義し、その中で信頼レベルやフィルタ条件を設定する必要があります。
2.  **結合テーブルの構築順序:**
    Source Guard や ND Inspection を動かすには、まず結合テーブルにデータが存在しなければなりません。DHCPv6 Snooping や NDP Snooping が正しく動いてデータが蓄積されているかを確認する能力が問われます。
3.  **トラップ設定:**
    `ipv6 snooping` 機能は CPU 負荷が高いため、特定の VLAN やポートに限定して適用する要件が出ることがあります。
4.  **IPv4 セキュリティとの統合:**
    同一ポートで IPv4 DHCP Snooping と IPv6 FHS を併用する際の整合性に注意してください。

---

## 🛠 設定・検証コマンド

### 設定コマンド (Policy-Based)

| 目的 | コマンド |
| :--- | :--- |
| **RA Guard ポリシー作成** | <code>ipv6 ra-guard policy [NAME]</code> <br> <code>device-role [hub&#124;host&#124;router]</code> |
| **DHCP Guard ポリシー作成** | <code>ipv6 dhcp-guard policy [NAME]</code> <br> <code>device-role [server&#124;client]</code> |
| **ND Inspection ポリシー作成** | <code>ipv6 nd inspection policy [NAME]</code> <br> <code>device-role [host&#124;monitor&#124;router]</code> |
| **インターフェイスへの適用** | <code>(config-if)# ipv6 ra-guard attach-policy [NAME]</code> <br> <code>(config-if)# ipv6 dhcp-guard attach-policy [NAME]</code> <br> <code>(config-if)# ipv6 source-guard attach-policy [NAME]</code> |
| **静的結合エントリの追加** | <code>ipv6 neighbor binding vlan [VLAN] [IPV6_ADDR] interface [INT] [MAC]</code> |

### 検証・モニタリングコマンド

| 目的 | コマンド |
| :--- | :--- |
| **結合テーブル（データベース）の確認** | <code>show ipv6 neighbor binding [vlan ID]</code> |
| **デバイス追跡情報の確認** | <code>show device-tracking database</code> |
| **RA Guard の統計情報確認** | <code>show ipv6 ra-guard statistics</code> |
| **DHCP Guard の状態確認** | <code>show ipv6 dhcp-guard destination</code> |
| **適用されているポリシーのサマリ** | <code>show ipv6 snooping features</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. RA Guard 基本設定 (不正ルータ排除)

**【問題】** VLAN 10 のホストポート Gi1/0/1 からのルータ広告を遮断せよ。
```ios
ipv6 ra-guard policy BLOCK_RA
 device-role host
!
interface GigabitEthernet1/0/1
 ipv6 ra-guard attach-policy BLOCK_RA
```

### 2. Trusted ルータの設定 (正当な RA 許可)

**【問題】** 上位ルータが接続された Gi1/0/24 ポートでのみ RA を許可せよ。
```ios
ipv6 ra-guard policy TRUST_RA
 device-role router
!
interface GigabitEthernet1/0/24
 ipv6 ra-guard attach-policy TRUST_RA
```

### 3. DHCPv6 Guard によるサーバ保護

**【問題】** 未認可の DHCPv6 サーバからの REPLY パケットを Gi1/0/2 でブロックせよ。
```ios
ipv6 dhcp-guard policy DENY_DHCP_SRV
 device-role client
!
interface GigabitEthernet1/0/2
 ipv6 dhcp-guard attach-policy DENY_DHCP_SRV
```

### 4. ND Inspection の有効化 (ARP Inspection 相当)

**【問題】** VLAN 20 全体で NDP メッセージの検証を実施せよ。
```ios
ipv6 nd inspection policy SECURE_NDP
 device-role host
 validate src-mac
!
vlan configuration 20
 ipv6 nd inspection attach-policy SECURE_NDP
```

### 5. IPv6 Source Guard の実装 (なりすまし防止)

**【問題】** ポート Gi1/0/5 において、結合テーブルにない送信元 IP を持つパケットを破棄せよ。
```ios
ipv6 source-guard policy IP_VERIFY
 validate address
!
interface GigabitEthernet1/0/5
 ipv6 source-guard attach-policy IP_VERIFY
```

### 6. 静的バインディングの追加

**【問題】** 固定 IP を持つホスト (2001:DB8::100, MAC: aabb.cc00.0100) を結合テーブルに手動登録せよ。
```ios
ipv6 neighbor binding vlan 10 2001:DB8::100 interface Gi1/0/10 aabb.cc00.0100
```

### 7. Device Tracking ポリシーのカスタマイズ

**【問題】** インターフェイスが DOWN しても 10 分間はエントリを維持するようにせよ。
```ios
device-tracking policy MY_TRACKING
 tracking-target all
 timeout 600
!
interface GigabitEthernet1/0/1
 device-tracking attach-policy MY_TRACKING
```

### 8. ND Inspection での送信元 MAC/IP 整合性チェック

**【問題】** ND 検証時、イーサネットヘッダーの MAC と NDP 内の MAC が一致することを確認せよ。
```ios
ipv6 nd inspection policy STRICT_CHECK
 validate src-mac
!
interface GigabitEthernet1/0/3
 ipv6 nd inspection attach-policy STRICT_CHECK
```

### 9. 結合テーブル学習ソースの限定

**【問題】** 結合テーブルの学習を DHCPv6 のみに限定し、NDP からの学習を無効化せよ。
```ios
ipv6 neighbor binding vlan 10 logging-source dhcp
```

### 10. FHS 統計情報のクリアと再検証

**【問題】** トラブルシューティングのため、これまでの RA Guard 違反ログをリセットせよ。
```ios
clear ipv6 ra-guard statistics
```

### 11. IPv6 ポート ACL (PACL) との併用

**【問題】** Source Guard に加え、特定の管理トラフィック (SSH) のみを許可する PACL を適用せよ。
```ios
ipv6 access-list MGMT_ONLY
 permit tcp any any eq 22
 deny ipv6 any any
!
interface GigabitEthernet1/0/5
 ipv6 traffic-filter MGMT_ONLY in
```

### 12. 結合テーブルの容量制限

**【問題】** メモリ保護のため、VLAN 100 で学習する近隣エントリを最大 50 個に制限せよ。
```ios
ipv6 neighbor binding vlan 100 max-entries 50
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKIPV-3134: IPv6 Security in the Local Area with First Hop Security**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPV-3134)
    *   FHS の各機能に関する最も包括的なプレゼンテーション。
*   [**BRKSEC-2001: Layer 2 Security Deep Dive**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001)
    *   IPv4/IPv6 両方のスイッチセキュリティの攻撃手法と対策。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Security Configuration Guide: IPv6 First-Hop Security**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sec/b_179_sec_9300_cg.html)
*   [**Configuring IPv6 Neighbor Discovery Inspection**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipv6/configuration/xe-16/ipv6-xe-16-book/ip6-nd-inspect.html)

### テクニカルドキュメント・設定例
*   [**IPv6 First-Hop Security Features Overview**](https://www.cisco.com/c/en/us/support/docs/ip/ipv6/116030-technote-fhs-00.html)
*   [**Understanding RA Guard (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ios-xml/ios/sec_data_urpf/configuration/xe-17/sec-data-urpf-xe-17-book.html)

---


## 📝 補足
- この学習メモは、CCIE EI 試験合格に必要な「論理的な設定の流れ」と「トラブルシューティングの視点」を網羅しています。ラボ試験では、特に **`show ipv6 neighbor binding`** の結果が他の FHS 機能の成否を握っていることを忘れないでください。

