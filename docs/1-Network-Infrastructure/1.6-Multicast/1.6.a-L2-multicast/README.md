---
layout: default
title: 1.6.a-L2-multicast
parent: 1.6-Multicast
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.6.a Layer 2 Multicast

この学習メモでは、CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.6.a Layer 2 multicast」に焦点を当て、IGMPv2/v3、スヌーピング、クエリア、フィルタリング、およびIPv6環境におけるMLDの技術詳細と試験対策を網羅します。

---

## 📘 概要

**Layer 2 Multicast**は、イーサネットスイッチ環境においてマルチキャストトラフィックを効率的に配信するための基盤技術です。通常、スイッチはマルチキャストフレームをブロードキャストと同様に全ポートへフラッディングしますが、これでは帯域幅が無駄になり、受信を希望しないホストの負荷を増大させます。

これを解決するのが **IGMP Snooping** です。スイッチがL3の制御パケット（IGMP Report/Leave）を「盗み聞き（Snoop）」することで、どのホストがどのマルチキャストグループに属しているかを学習し、該当するポートにのみトラフィックを転送するインテリジェントな転送テーブルを構築します。CCIEレベルでは、IPv4環境のIGMPだけでなく、IPv6環境での **MLD (Multicast Listener Discovery)**、さらにはルータが存在しないセグメントでの **IGMP Querier** の動作、セキュリティを確保するための **IGMP Filter** の精密な制御が求められます。

---

## 🔑 要点

### 1. IGMPv2 および IGMPv3 (i)

IPv4マルチキャストのグループ管理プロトコルです。
*   **IGMPv2:** 最も広く普及。グループ指定クエリや「Leave Group」メッセージによる高速な離脱処理をサポート。
*   **IGMPv3:** **SSM (Source-Specific Multicast)** をサポート。ホストは「特定の送信元からの」マルチキャストのみを受信するよう「Include/Exclude」リストを指定可能。

### 2. IGMP Snooping と PIM Snooping (ii)

*   **IGMP Snooping:** L2スイッチがL3のIGMPメッセージを解析し、マルチキャスト転送を特定のポートに制限する。デフォルトで有効な場合が多いが、VLANごとに制御が必要。
*   **PIM Snooping:** スイッチがPIM HelloやJoin/Pruneメッセージを解析し、PIMルータ間のマルチキャストトラフィックを最適化する。主にルータが混在する複雑なトポロジで使用。

### 3. IGMP Querier (iii)

*   IGMP Snoopingが機能するには、セグメント内にIGMP Queryを送信する「クエリア」が必要です。
*   通常はマルチキャストルータがこの役割を担いますが、ルータが存在しないVLANではスイッチを **IGMP Snooping Querier** として設定し、自らクエリを生成させる必要があります。

### 4. IGMP Filter (iv)

*   特定のポートやVLANにおいて、許可または拒否するマルチキャストグループを制御します。
*   **IGMP Profile** を作成し、それをインターフェイスに適用することで、不正なグループへの参加（DoS攻撃や誤設定）を防止します。

### 5. MLD (Multicast Listener Discovery) (v)

*   IPv6環境におけるIGMPの対応プロトコルで、ICMPv6メッセージを使用します。
*   **MLD Snooping** により、IPv6マルチキャストトラフィックもL2レベルで最適化されます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単なる有効化ではなく、特定の制約条件下での最適化とトラブルシューティングが問われます。

### 1. L2アドレスの重複（Overlap）

マルチキャストIPアドレス（L3）をMACアドレス（L2）にマッピングする際、**32:1 の重複**が発生します。
*   **技術詳細:** IPの後半23ビットがMACアドレスに使用されるため、異なるマルチキャストグループが同一のMACアドレスを共有する可能性があります。
*   **ラボでの注意:** スヌーピングがMACベースで動作している場合、予期しないポートにトラフィックが流れる「フラッディング」の原因となります。IPベースのスヌーピングへの変更が必要になる場合があります。

### 2. Immediate Leave（即時離脱）

*   ポートにホストが1台しか接続されていない場合、Leave受信後すぐに転送を停止する機能です。
*   **設定要件:** 「チャネルの切り替え時間を短縮せよ」や「不要なトラフィックを即座にカットせよ」という要件に対し、`ip igmp snooping vlan [ID] immediate-leave` を適切に適用する必要があります。

### 3. mrouter ポートの特定

*   スイッチはクエリを受信したポートを「mrouter（マルチキャストルータ）」ポートとして自動認識します。
*   **トラブル点:** 複数のスイッチがカスケード接続されている場合、静的に `ip igmp snooping vlan [ID] mrouter interface [ID]` を設定して、トラフィックの経路を固定するタスクが出題されやすいです。

### 4. IGMPv3 と SSM の統合

*   ラボでSSMの構成が求められた場合、スイッチ側でも IGMPv3 スヌーピングが正しく動作していることを確認する必要があります。デフォルトが v2 の場合、明示的なバージョン変更が必要です。

---

## 🛠 設定・検証コマンド

### 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **IGMPスヌーピングのグローバル有効化** | <code>(config)# ip igmp snooping</code> |
| **特定VLANでのスヌーピング有効化** | <code>(config)# ip igmp snooping vlan [ID]</code> |
| **IGMPスヌーピングクエリアの有効化** | <code>(config)# ip igmp snooping querier</code> |
| **クエリアのIPアドレス指定** | <code>(config)# ip igmp snooping querier address [IP]</code> |
| **Immediate Leaveの設定** | <code>(config)# ip igmp snooping vlan [ID] immediate-leave</code> |
| **静的mrouterポートの指定** | <code>(config)# ip igmp snooping vlan [ID] mrouter interface [INT]</code> |
| **IGMPプロファイル（フィルタ）作成** | <code>(config)# ip igmp profile [ID]</code> <br> <code>(config-igmp-profile)# permit&#124;deny range [IP] [MASK]</code> |
| **インターフェイスへのフィルタ適用** | <code>(config-if)# ip igmp filter [ID]</code> |
| **ポートあたりの最大グループ数制限** | <code>(config-if)# ip igmp max-groups [NUMBER]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **スヌーピングの全体ステータス確認** | <code>show ip igmp snooping</code> |
| **VLANごとのグループ参加状況確認** | <code>show ip igmp snooping groups</code> |
| **mrouterポートの学習状況確認** | <code>show ip igmp snooping mrouter</code> |
| **クエリア情報の確認** | <code>show ip igmp snooping querier [vlan ID]</code> |
| **IGMPアクティビティの統計確認** | <code>show ip igmp snooping statistics</code> |
| **IPv6 MLDスヌーピングの確認** | <code>show ipv6 mld snooping</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 基本的な IGMP Snooping の有効化

**【問題内容】**
VLAN 10 において、マルチキャストトラフィックが受信を希望しないポートにフラッディングしないよう、最適化を実施せよ。

**【設定例】**
```ios
ip igmp snooping
ip igmp snooping vlan 10
```

---

### 2. ルータ不在環境での IGMP Querier 構成

**【問題内容】**
VLAN 20 にはマルチキャスト対応ルータが存在しない。L2 スイッチ R1 において、IGMP レポートを誘発するためのクエリを 192.168.20.254 を送信元として送信せよ。

**【設定例】**
```ios
ip igmp snooping querier
ip igmp snooping vlan 20 querier address 192.168.20.254
```

---

### 3. 帯域節約のための高速離脱 (Immediate Leave)

**【問題内容】**
VLAN 30 に接続された各ホストは、マルチキャストグループを離脱した際、スイッチが即座にパケットの転送を停止するように設定せよ。

**【設定例】**
```ios
ip igmp snooping vlan 30 immediate-leave
```

---

### 4. マルチキャストフィルタリング (IGMP Filter)

**【問題内容】**
VLAN 10 に接続されたホストが、アドミニストレーティブスコープ（239.0.0.0/8）以外のマルチキャストグループに参加することを禁止せよ。

**【設定例】**
```ios
ip igmp profile 1
 permit 239.0.0.0 255.255.255.0  ! 簡易的な範囲指定例
!
interface range GigabitEthernet1/0/1 - 24
 ip igmp filter 1
```

---

### 5. 静的な mrouter ポートの割り当て

**【問題内容】**
コアスイッチ SW1 へのアップリンクポート（GigabitEthernet 1/0/48）が、トラフィックの有無にかかわらず常にマルチキャストルータとして認識されるようにせよ。

**【設定例】**
```ios
ip igmp snooping vlan 10 mrouter interface GigabitEthernet1/0/48
```

---

### 6. ポートごとのマルチキャストグループ参加数制限

**【問題内容】**
ポート GigabitEthernet 1/0/1 において、1 つのホストが同時に参加できるマルチキャストグループを 5 つまでに制限せよ。

**【設定例】**
```ios
interface GigabitEthernet1/0/1
 ip igmp max-groups 5
```

---

### 7. IPv6 MLD Snooping の構成

**【問題内容】**
IPv6 環境において、VLAN 100 のマルチキャストトラフィックを L2 レベルで最適化せよ。

**【設定例】**
```ios
ipv6 mld snooping
ipv6 mld snooping vlan 100
```

---

### 8. IGMPv3 サポートと SSM のためのバージョン変更

**【問題内容】**
VLAN 50 において SSM（Source-Specific Multicast）を使用する。スイッチがホストからの送信元指定情報を正しく解釈できるように設定せよ。

**【設定例】**
```ios
interface Vlan 50
 ip igmp version 3
!
ip igmp snooping vlan 50
```

---

### 9. IGMP レポート抑制 (Report Suppression) の無効化

**【問題内容】**
（トラブルシューティング用）スイッチによるレポート抑制機能を無効化し、ルータがすべてのホストのレポートを直接確認できるようにせよ。

**【設定例】**
```ios
no ip igmp snooping report-suppression
```

---

### 10. クエリアタイマーの微調整

**【問題内容】**
VLAN 136 において、IGMP クエリを 30 秒ごとに送信するように変更せよ。また、バックアップクエリアは 60 秒間クエリが見えない場合に動作を開始するようにせよ。

**【設定例】**
```ios
interface Vlan 136
 ip igmp query-interval 30
 ip igmp querier-timeout 60
```

---

### 11. 特定 VLAN への静的なマルチキャスト参加 (Static Join)

**【問題内容】**
ルータ R1 のインターフェイスにおいて、実際にホストがいなくても 224.7.7.7 のトラフィックを受信するように設定せよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 ip igmp join-group 224.7.7.7
```

---

### 12. PIM Snooping の有効化

**【問題内容】**
L2 スイッチを介して接続されたルータ間の PIM Join/Prune メッセージを最適化せよ。

**【設定例】**
```ios
ip pim snooping
```

---

## 参考リソースリンク

### 関連動画・スライド (Cisco Live On-Demand Library)
*   [BRKIPM-2264: IP Multicast Logic and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPM-2264)
*   [BRKENS-2001: Multicast Primer](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2001)
*   [BRKCCIE-3000: BGP and Multicast for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

#### Configuration ガイド
*   [IP Multicast: IGMP Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_igmp/configuration/xe-17/imc-igmp-xe-17-book.html)
*   [IPv6 Multicast: MLD Snooping Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_mld/configuration/xe-16/imc-mld-xe-16-book.html)

#### テクニカルノーツ・設定例
*   [IP Multicast Technology Overview (Cisco White Paper)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-16/imc-pim-xe-16-book/imc-tech-oview.pdf)
*   [IGMP Snooping FAQ and Troubleshooting](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-6500-series-switches/68131-control-multicast.html)

---


## 📝 補足
- この学習メモは、L2マルチキャストが単なるスイッチの機能ではなく、L3ルーティングと密接に連携する「ハイブリッドな最適化」であることを強調しています。特に、ルータが存在しない VLAN でのクエリア設定や、MAC アドレス重複に起因するフラッディングのトラブルシュートは、CCIE EI 実技試験での合格を左右する非常に重要なポイントです。

