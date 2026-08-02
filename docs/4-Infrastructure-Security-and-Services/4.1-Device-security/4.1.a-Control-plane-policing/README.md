---
layout: default
title: 4.1.a-Control-plane-policing
parent: 4.1-Device-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.1.a Control Plane Policing and Protection

Cisco IOS XE デバイスのセキュリティにおいて、**Control Plane Policing (CoPP)** および **Control Plane Protection (CPPr)** は、ルータの「頭脳」であるルートプロセッサ（RP）を過剰なトラフィックや攻撃から保護するための最重要技術です。CCIE EI v1.1 ラボ試験では、ネットワークインフラ全体の安定性を維持するために、適切なプロトコル保護と管理アクセスの制限を実装する能力が問われます。

---

## 📘 概要

**Control Plane Policing (CoPP)** とは、ルータ自身を宛先とするトラフィック（コントロールプレーンおよびマネジメントプレーントラフィック）に対して、Modular QoS CLI (MQC) のフレームワークを使用してレート制限やフィルタリングを適用する機能です。これにより、DoS攻撃（サービス拒否攻撃）や設定ミスによる異常なトラフィックがRPのCPUリソースを枯渇させるのを防ぎます。

**Control Plane Protection (CPPr)** は CoPP の概念をさらに拡張したもので、コントロールプレーンへの入り口を「ホスト」「トランジット」「CEF例外」といったサブインターフェイスに論理的に分割し、より細かい粒度で保護ポリシーを適用することを可能にします。

CCIE EI レベルでは、単にパケットをドロップするだけでなく、ルーティングプロトコルのネイバー関係を維持しつつ、不要なスキャンや攻撃トラフィックのみを正確に制限する「バランスの取れた設計」が求められます。

---

## 🔑 要点

### 1. 3つのトラフィックプレーン

ルータを通過・到達するトラフィックは以下の3つに分類されます。CoPP/CPPr は主に 2 と 3 を対象とします。
1.  **Data Plane:** ルータを通過するだけのトラフィック。
2.  **Control Plane:** ルーティングプロトコル（OSPF, BGP, EIGRP等）やICMPなど、ネットワークの制御に関わるトラフィック。
3.  **Management Plane:** SSH, Telnet, SNMP, HTTPなど、デバイスの管理に使用されるトラフィック。

### 2. MQC (Modular QoS CLI) の適用

CoPP は通常の QoS と同じフローで設定します。
*   **Class-map:** ACL等を使用して保護対象（または制限対象）のトラフィックを識別します。
*   **Policy-map:** 識別されたクラスに対して `police`（レート制限）や `drop`（破棄）などのアクションを定義します。
*   **Service-policy:** `control-plane` セクションにポリシーを適用します。

### 3. CPPr のサブインターフェイス (Granular Protection)

CPPr では、コントロールプレーンを以下の3つの論理パスに分けます。
*   **Host:** ルータの物理/論理IPアドレス宛のトラフィック（SSH, SNMP, Routing Protocol）。
*   **Transit:** IPオプション付きパケットなど、ルータが処理を介在する必要があるが、宛先は他であるトラフィック。
*   **CEF-Exception:** ARP, TTL期限切れ, MTU不一致など、CEFで処理できずRPに送られるトラフィック。

### 4. CoPP の暗黙の挙動

Policy-map の最後に位置する `class-default` は、明示的に `drop` を指定しない限り **「パス（許可）」** されます。これはインターフェイス ACL（暗黙の deny）とは逆の挙動であるため、試験では非常に重要です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、複雑な要件に基づいたCoPPの実装が求められます。

### 1. ルーティングプロトコルの維持

*   **ポイント:** OSPFやBGPなどのプロトコルを厳しく制限しすぎると、負荷が高い時に隣接関係が切れてしまいます。
*   **対策:** ルーティングプロトコルには高いレート（PPS/BPS）を割り当てるか、優先クラスとして定義し、ドロップが発生しないように設計します。

### 2. 管理アクセスの「セーフティネット」

*   **リスク:** 設定ミスにより自分の SSH セッションを CoPP で遮断してしまう可能性があります。
*   **対策:** 自身の管理端末 IP を含んだクラスを必ず「優先（transmit）」に設定し、最後に `drop` を入れる構成にする際は注意を払います。

### 3. ログ出力の制御

*   **要件:** 「特定の攻撃トラフィックをドロップし、かつログに記録せよ」という課題が出ます。
*   **実装:** ACL で `log` オプションを使うか、Policy-map 内で `log` アクション（プラットフォーム依存）を使用します。ただし、大量のログ出力自体が CPU 負荷になるため、試験ではレート制限との組み合わせが問われます。

### 4. 特定の攻撃パターンの排除

*   **シナリオ:** 「特定の送信元からの ICMP パケットのみを秒間 15 パケットに制限せよ」といった具体的な数値指定。
*   **計算:** `police rate 15 pps` のように、PPS（Packets Per Second）単位での設定が必要な場合があります。

---

## 🛠 設定・検証コマンド

### 設定コマンド (MQC構成)

| 目的 | コマンド |
| :--- | :--- |
| **トラフィックの識別(ACL)** | <code>access-list [ID] permit [protocol] [src] [dst]</code> |
| **クラスマップの作成** | <code>class-map match-all [CLASS_NAME]</code> <br> <code>match access-group [ID]</code> |
| **ポリシーマップの定義** | <code>policy-map [POLICY_NAME]</code> <br> <code>class [CLASS_NAME]</code> <br> <code>police [rate] [conform-action] [exceed-action]</code> |
| **CoPPの適用** | <code>control-plane</code> <br> <code>service-policy input [POLICY_NAME]</code> |
| **CPPr ホスト保護の適用** | <code>control-plane host</code> <br> <code>service-policy input [POLICY_NAME]</code> |

### 検証・統計確認コマンド

| 目的 | コマンド |
| :--- | :--- |
| **ポリシーの適用状況確認** | <code>show control-plane aggregate counters</code> |
| **各クラスのヒット数・ドロップ数確認** | <code>show policy-map control-plane</code> |
| **詳細なパケット統計の確認** | <code>show policy-map control-plane input class [CLASS_NAME]</code> |
| **CPPrサブインターフェイスの確認** | <code>show control-plane host</code> |
| **CoPP設定の整合性確認** | <code>show run &#124; section control-plane</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. ICMP トラフィックの PPS 制限

**【要件】** 全ての ICMP パケットを秒間 15 パケットに制限し、超過分を破棄せよ。
```ios
ip access-list extended ACL-ICMP
 permit icmp any any
!
class-map match-all CLASS-ICMP
 match access-group name ACL-ICMP
!
policy-map COPP-POLICY
 class CLASS-ICMP
  police 15 pps conform-action transmit exceed-action drop
!
control-plane
 service-policy input COPP-POLICY
```

---

### 2. 特定ソースからの HTTP 攻撃遮断

**【要件】** 攻撃者 (3.3.3.3) からの HTTP トラフィックを完全にドロップせよ。
```ios
ip access-list extended ACL-HTTP-ATTACK
 permit tcp host 3.3.3.3 any eq www
!
class-map match-all CLASS-HTTP-ATTACK
 match access-group name ACL-HTTP-ATTACK
!
policy-map COPP-POLICY
 class CLASS-HTTP-ATTACK
  drop
```

---

### 3. ルーティングプロトコル (BGP) の保護

**【要件】** BGP トラフィックを 500 pps まで許可し、インフラの安定性を確保せよ。
```ios
ip access-list extended ACL-BGP
 permit tcp any any eq 179
 permit tcp any eq 179 any
!
class-map match-all CLASS-BGP
 match access-group name ACL-BGP
!
policy-map COPP-POLICY
 class CLASS-BGP
  police 500 pps conform-action transmit exceed-action drop
```

---

### 4. SSH 管理アクセスの帯域保証

**【要件】** 管理セグメント (10.1.1.0/24) からの SSH 接続を最優先し、ドロップされないようにせよ。
```ios
ip access-list extended ACL-MGMT-SSH
 permit tcp 10.1.1.0 0.0.0.255 any eq 22
!
class-map match-all CLASS-MGMT-SSH
 match access-group name ACL-MGMT-SSH
!
policy-map COPP-POLICY
 class CLASS-MGMT-SSH
  police 1000000 bps conform-action transmit exceed-action transmit
```

---

### 5. 外向き Telnet の制限と詳細ロギング

**【要件】** 1.1.1.1 宛の Telnet パケットを破棄し、2秒間隔で TTL とパケット長を含めてログに出力せよ。
```ios
ip access-list extended ACL-OUTBOUND-TELNET
 permit tcp any host 1.1.1.1 eq 23
!
class-map match-all CLASS-OUTBOUND-TELNET
 match access-group name ACL-OUTBOUND-TELNET
!
policy-map COPP-POLICY
 class CLASS-OUTBOUND-TELNET
  drop
  log  ! プラットフォームによりACL側でlogを指定する場合もある
```

---

### 6. IPv6 ICMP 帯域制限

**【要件】** 全ての IPv6 ICMP トラフィックを 70,000 bps に制限せよ。
```ios
ipv6 access-list ACL-ICMPV6
 permit icmp any any
!
class-map match-all CLASS-ICMPV6
 match access-group name ACL-ICMPV6
!
policy-map COPP-POLICY
 class CLASS-ICMPV6
  police 70000 bps conform-action transmit exceed-action drop
```

---

### 7. SNMP ポーリングのレート制限

**【要件】** 外部からの大量の SNMP ポーリングによる負荷を防ぐため、秒間 20 パケットに制限せよ。
```ios
ip access-list extended ACL-SNMP
 permit udp any any eq snmp
!
class-map match-all CLASS-SNMP
 match access-group name ACL-SNMP
!
policy-map COPP-POLICY
 class CLASS-SNMP
  police 20 pps conform-action transmit exceed-action drop
```

---

### 8. CPPr による「ホスト」サブインターフェイス保護

**【要件】** ルータ自身宛（Host）のトラフィックのみに特化したポリシーを適用せよ。
```ios
control-plane host
 service-policy input COPP-HOST-POLICY
! hostサブインターフェイスはルータのIP宛のみに限定される
```

---

### 9. CEF-Exception (ARP等) のレート制限

**【要件】** 大量の ARP リクエストによる RP 負荷を軽減するため、CEF 例外パスを制限せよ。
```ios
class-map match-all CLASS-ARP
 match protocol arp
!
policy-map CPPR-EXCEPTION-POLICY
 class CLASS-ARP
  police 100 pps conform-action transmit exceed-action drop
!
control-plane cef-exception
 service-policy input CPPR-EXCEPTION-POLICY
```

---

### 10. SSH のキューしきい値とロギング

**【要件】** SSH トラフィックの入力キュー制限を超えた場合にログを出力せよ。
```ios
policy-map type queue-threshold QT-POL
 class CLASS-SSH
  log
!
control-plane
 service-policy type queue-threshold input QT-POL
```

---

### 11. 非許可トラフィックの完全遮断

**【要件】** 許可されたクラス以外の全てのコントロールプレーンパケットを破棄せよ。
```ios
policy-map COPP-POLICY
 ! (既にあるclass設定の最後)
 class class-default
  drop
! ※注意: これを適用する前に必ず全ての必要なプロトコルが定義されていることを確認すること
```

---

### 12. フラグメント化されたパケットの制限

**【要件】** CPU 負荷の高い IP フラグメントパケットを秒間 5 パケットに制限せよ。
```ios
ip access-list extended ACL-FRAGMENTS
 permit ip any any fragments
!
class-map match-all CLASS-FRAGMENTS
 match access-group name ACL-FRAGMENTS
!
policy-map COPP-POLICY
 class CLASS-FRAGMENTS
  police 5 pps conform-action transmit exceed-action drop
```

---

## 🔗 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKSEC-2001: Control Plane Protection**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2001)
    *   CoPP と CPPr の深いアーキテクチャ解説。
*   [**BRKENT-2081: Troubleshooting Infrastructure Security**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081)
    *   CoPP によって正規のトラフィックがドロップされている場合の切り分け手法。
*   [**BRKCRT-1385: The CCIE in an SDN World - Security Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE試験で問われるセキュリティトピックの優先順位。

### Configuration ガイド
*   [**Cisco IOS XE 17.x Security Configuration Guide: Control Plane Policing**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/qos_plcshp/configuration/xe-17/qos-plcshp-xe-17-book/qos-plcshp-cpp.html)
*   [**Control Plane Protection Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_cp_prot/configuration/xe-16/sec-data-cp-prot-xe-16-book.html)

### テクニカルドキュメント・設定例
*   [**Control Plane Policing (CoPP) Implementation Best Practices**](https://www.cisco.com/c/en/us/support/docs/ip/access-lists/43503-contplane-policing.html)
    *   実環境でのホワイトリスト設計の推奨例。
*   [**CoPP Troubleshooting and Verification (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/qos-policing/110300-copp-verified-00.html)

---

## 📝 補足
- この学習メモは、CCIE EI 試験においてデバイスの自己防衛機能をいかに論理的に構成するかを網羅しています。ラボ試験では、**`show policy-map control-plane`** を実行した際に、意図したクラスでパケットがカウントされ、かつドロップされるべきものがドロップされているかを確認する習慣をつけることが合格への近道です。


