---
layout: default
title: 4.2.a-Switch-security
parent: 4.2-Network-security
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.2.a スイッチセキュリティ機能

Cisco IOS XE スイッチにおけるレイヤ2セキュリティは、ネットワーク全体の信頼性を確保するための「第一防衛線」です。CCIE Enterprise Infrastructure (EI) v1.1 ラボ試験では、これらの機能を組み合わせて、なりすまし攻撃、DHCP攻撃、ブロードキャストストームなどを防御する高度な実装能力が問われます。

---

## 📘 概要

スイッチセキュリティ機能は、主にアクセス層（Access Layer）でエンドポイントからの不正なトラフィックを検知・遮断するために使用されます。本トピックでは、物理ポートまたはVLANレベルでのアクセス制御（VACL/PACL）、異常トラフィックの抑制（Storm Control）、そしてIP/MACアドレスの整合性を動的に検証する「First Hop Security（FHS）」の一連の技術（DHCP Snooping, IP Source Guard, DAI）を網羅します。

これらの機能は相互に依存関係にあるものが多く、特に DHCP Snooping のバインディングデータベースは、DAI や IP Source Guard の動作基盤となります。

---

## 🔑 要点

### 1. VACL (VLAN ACL) と PACL (Port ACL) (i)

*   **PACL:** 物理レイヤ2インターフェイスに直接適用される ACL です。トランクポートやアクセスポートで、インバウンドのトラフィックのみをフィルタリングします。
*   **VACL (VLAN Access Map):** 特定の VLAN 内でブリッジングされるトラフィック、または VLAN に出入りするすべてのトラフィックを制御します。標準 ACL や拡張 ACL を「match」条件として使用し、「forward」または「drop」のアクションを定義します。

### 2. Storm Control (ii)

*   ブロードキャスト、マルチキャスト、またはユニキャストのパケットレベルを1秒間隔で監視し、設定したしきい値を超えた場合にトラフィックを抑制します。
*   しきい値は、帯域幅に対する割合（%）、PPS（1秒あたりのパケット数）、または BPS（1秒あたりのビット数）で指定可能です。
*   アクションとして、トラフィックのドロップ（デフォルト）だけでなく、インターフェイスの `shutdown` や SNMP トラップの送信を選択できます。

### 3. DHCP Snooping と Option 82 (iii)

*   信頼できない（Untrusted）ポートから届く、本来サーバーが送るべき DHCP メッセージ（OFFER, ACK等）をドロップします。
*   **Option 82:** リレーエージェント情報オプション。DHCP 要求パケットに、その要求が届いたスイッチのポート情報や VLAN 情報を挿入し、サーバー側でより詳細な IP 割り当てポリシーを適用可能にします。

### 4. IP Source Guard (IPSG) (iv)

*   DHCP Snooping データベースまたは静的な IP ソースバインディングを使用して、インターフェイス上の送信元 IP アドレスを検証します。
*   バインディングに一致しない IP アドレスを持つパケットは、レイヤ2レベルで拒否されます。MAC アドレスの検証を組み合わせることも可能です。

### 5. Dynamic ARP Inspection (DAI) (v)

*   ARP ポイズニング（ARPスプーフィング）攻撃を防止します。
*   すべての ARP リクエストと応答をインターセプトし、DHCP Snooping データベースと照合して、不正な MAC-to-IP マッピングを持つ ARP パケットを破棄します。

### 6. Port Security (vi)

*   インターフェイスで許可する MAC アドレスの数や、特定の MAC アドレスのみを制限します。
*   **Sticky MAC:** 動的に学習した MAC アドレスを「Sticky」として実行コンフィギュレーションに保存し、再起動後も維持します。
*   **Violation アクション:** `shutdown`（ポート無効化）、`restrict`（パケット破棄＋ログ＋カウンタ増）、`protect`（パケット破棄のみ）があります。

---

## 🎯 試験対策 (CCIE EIレベル)

### 1. 依存関係の順序

ラボ試験で「DAI を実装せよ」という要件が出た場合、明示されていなくても、前提となる **DHCP Snooping を正しく構成してバインディングテーブルを作成** しておく必要があります。この連鎖的な設定漏れは CCIE 試験での典型的な失点パターンです。

### 2. トランクポートの Trust 設定

DHCP Snooping や DAI を設定する際、スイッチ間の接続（トランクポート）を `trust` に設定し忘れると、正規の DHCP 通信や ARP 通信がスイッチ間で遮断され、ネットワーク全体がダウンします。

### 3. Errdisable Recovery の活用

Port Security や Storm Control の violation によりポートが `err-disable` 状態になった場合、手動で `shutdown`/`no shutdown` するのではなく、`errdisable recovery cause...` コマンドを使用して、一定時間後に自動復旧させる要件が出題されることがあります。

### 4. VACL の暗黙の拒否

VLAN Access Map の最後には、通常の ACL 同様に「暗黙の拒否」が存在します。特定のトラフィックをドロップするマップを作成した後は、必ず残りのトラフィックを `forward` するシーケンスを追加しなければなりません。

---

## 🛠 設定・検証コマンド

### 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **VACL の作成** | <code>vlan access-map [MAP_NAME] [SEQ]</code><br><code>match ip address [ACL]</code><br><code>action [forward&#124;drop]</code> |
| **VACL の適用** | <code>vlan filter [MAP_NAME] vlan-list [ID]</code> |
| **Storm Control 設定** | <code>storm-control broadcast level [PERCENT]</code><br><code>storm-control action shutdown</code> |
| **DHCP Snooping 有効化** | <code>ip dhcp snooping</code><br><code>ip dhcp snooping vlan [ID]</code> |
| **DHCP Snooping Trust 設定** | <code>(config-if)# ip dhcp snooping trust</code> |
| **Dynamic ARP Inspection** | <code>ip arp inspection vlan [ID]</code> |
| **IP Source Guard 設定** | <code>(config-if)# ip verify source [mac-check]</code> |
| **Port Security (Sticky)** | <code>(config-if)# switchport port-security mac-address sticky</code> |

### 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **DHCP データベース確認** | <code>show ip dhcp snooping binding</code> |
| **DAI 統計情報の確認** | <code>show ip arp inspection statistics</code> |
| **Port Security 状態確認** | <code>show port-security interface [ID]</code> |
| **VACL 適用状況の確認** | <code>show vlan filter</code> |
| **IPSG 動作確認** | <code>show ip verify source</code> |
| **インターフェイス状態表示** | <code>show interfaces status</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. VACL による特定サーバーへのアクセス拒否

**【問題】** VLAN 10 内において、特定のホスト (10.1.10.50) からサーバー (10.1.10.100) への通信のみを遮断し、他のすべての通信を許可せよ。
```ios
ip access-list extended ACL_DENY_SRV
 permit ip host 10.1.10.50 host 10.1.10.100
!
vlan access-map VMAP_SEC 10
 match ip address ACL_DENY_SRV
 action drop
vlan access-map VMAP_SEC 20
 action forward
!
vlan filter VMAP_SEC vlan-list 10
```

### 2. Storm Control によるポート保護

**【問題】** Gi1/0/1 ポートでブロードキャストが帯域の 5% を超えた場合、ポートをシャットダウンせよ。
```ios
interface GigabitEthernet1/0/1
 storm-control broadcast level 5.0
 storm-control action shutdown
```

### 3. DHCP Snooping と Trust ポートの構成

**【問題】** VLAN 100 で DHCP Snooping を有効化し、上位スイッチに接続されている Gi1/0/24 を信頼済みポートに設定せよ。
```ios
ip dhcp snooping
ip dhcp snooping vlan 100
!
interface GigabitEthernet1/0/24
 ip dhcp snooping trust
```

### 4. DHCP Option 82 の無効化要件

**【問題】** スイッチが DHCP リレー情報の挿入を行わないように設定せよ（一部の古いDHCPサーバーとの互換性のため）。
```ios
no ip dhcp snooping information option
```

### 5. DAI の実装とトランクポートの除外

**【問題】** VLAN 20 で DAI を有効にし、スイッチ間のトランクポート Gi1/0/10 では ARP 検査をスキップせよ。
```ios
ip arp inspection vlan 20
!
interface GigabitEthernet1/0/10
 ip arp inspection trust
```

### 6. IP Source Guard (IPSG) の有効化

**【問題】** インターフェイス Gi1/0/5 において、送信元 IP アドレスのなりすましを防止せよ。
```ios
interface GigabitEthernet1/0/5
 ip verify source
```

### 7. Port Security (Sticky MAC) の設定

**【問題】** ポート Gi1/0/2 で最大 2 つの MAC アドレスを許可し、学習したアドレスを再起動後も保持せよ。
```ios
interface GigabitEthernet1/0/2
 switchport mode access
 switchport port-security
 switchport port-security maximum 2
 switchport port-security mac-address sticky
```

### 8. Port Security Violation (Restrict)

**【問題】** ポートセキュリティ違反が発生した際、ポートをシャットダウンせず、トラフィックのみを破棄して SNMP トラップを生成せよ。
```ios
interface GigabitEthernet1/0/2
 switchport port-security violation restrict
```

### 9. 静的バインディングによる IPSG の補完

**【問題】** DHCP を使用していない静的 IP ホスト (10.1.1.5, MAC: 0011.2233.4455) を IPSG 環境で許可せよ。
```ios
ip source binding 0011.2233.4455 vlan 10 10.1.1.5 interface GigabitEthernet1/0/3
```

### 10. DAI の追加検証 (MAC/IP 整合性)

**【問題】** DAI において、ARP パケット内の送信元 MAC アドレスとイーサネットヘッダーの MAC アドレスが一致しているかどうかも厳格に検査せよ。
```ios
ip arp inspection validate src-mac dst-mac ip
```

### 11. DHCP Snooping レート制限による DoS 防御

**【問題】** 信頼できないポートからの DHCP 要求を毎秒 10 パケットまでに制限せよ。
```ios
interface GigabitEthernet1/0/1
 ip dhcp snooping limit rate 10
```

### 12. Errdisable の自動復旧設定

**【問題】** ポートセキュリティ違反で無効化されたポートを 60 秒後に自動的に再有効化せよ。
```ios
errdisable recovery cause psecure-violation
errdisable recovery interval 60
```

---

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


