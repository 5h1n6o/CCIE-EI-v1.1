---
layout: default
title: 1.1.a-Switch-administration
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.1.a-Switch-administration

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.a Switch administration」に関する内容を整理しました。

---

## 1.1.a (i) Managing MAC address table

### 📘 概要

スイッチは、受信したイーサネットフレームの送信元MACアドレスを学習し、着信ポートおよびVLANに関連付けて**MACアドレステーブル（CAM：Content Addressable Memoryテーブル）**に記録します。この情報を基に転送先を決定し、未知のユニキャストフラッディングを最小限に抑えます。

### 🔑 要点

| 項目 | 内容 |  
| :--- | :--- |  
| **学習プロセス** | フレーム受信時に送信元MACを読み取り、ポート/VLAN情報を動的に登録。 |  
| **エージング** | デフォルト300秒。一定期間通信がないエントリは削除される。 |  
| **MAC移動 (Move)** | 同一MACが別ポートで検出された際の更新。通知トラップの設定が可能。 |  
| **静的登録** | 手動でMACとポートを紐付け、エージングによる削除を防止する。 |  
| **通知機能** | 追加、削除、移動、またはしきい値超過をSNMPトラップで通知可能。 | 

### MAC テーブル動作に影響する設計ポイント

- Access レイヤは「ブロードキャスト抑制」「IGMP スヌーピング」により不要なフラッディングを削減する。
- Distribution レイヤは「Layer 2 境界」「ブロードキャスト境界」として MAC テーブルの肥大化を防ぐ。
- Routed Access（L3 アクセス）を採用すると、アップリンクで MAC 学習が発生しなくなり、MAC テーブルが安定する。
- StackWise Virtual / VSS により STP ブロックポートがなくなり、MAC 学習がより安定する。

### CCIE-EI で重要な理由
- L2 ドメインを小さくすると MAC テーブルが小さくなり、収束が速くなる。
- ブロードキャスト境界は MAC テーブルの揺らぎ（MAC churn）を抑制する。
- Routed Access は MAC テーブルの不安定要因を大幅に減らす。

### 🎯 試験対策 (CCIE EIレベル)

*   **CAMの構造理解**: CAMはバイナリ結果（0または1）を高速で検索する高機能メモリであることを理解しておく。
*   **トラブルシューティング**: `show mac address-table dynamic` で特定ポートに複数のMACがある場合、その先にスイッチやハブ、仮想スイッチが存在することを即座に判断する。

### 🛠 設定・検証コマンド

| 目的 | コマンド | 
| :--- | :--- |  
| **静的エントリ追加** | `mac address-table static [MAC] vlan [ID] interface [INT]` | 
| **エージングタイム変更** | `mac address-table aging-time [秒]` |  
| **テーブル表示** | <code>show mac address-table [dynamic&#124;static&#124;vlan ID]</code> | 
| **テーブル消去** | `clear mac address-table dynamic` |  

```md
# ===============================
# MAC Address Table Configuration
# ===============================

## MAC アドレステーブルのエージングタイム設定
Switch1(config)# mac address-table aging-time 500 vlan 2

## 動的 MAC アドレスの削除（全削除）
Switch1# clear mac address-table dynamic

## 動的 MAC アドレスの削除（MAC 指定）
Switch1# clear mac address-table dynamic address c2f3.220a.12f4

## 動的 MAC アドレスの削除（インターフェイス指定）
Switch1# clear mac address-table dynamic interface gigabitethernet1/0/1

## 動的 MAC アドレスの削除（VLAN 指定）
Switch1# clear mac address-table dynamic vlan 4

## 動的 MAC アドレスの表示
Switch1# show mac address-table dynamic

# ===============================
# MAC Notification (SNMP Traps)
# ===============================

## MAC アドレス変更通知トラップ（Change Notification）
Switch1(config)# ! SNMP Trap の送信先を設定
Switch1(config)# snmp-server host 172.20.10.10 traps private mac-notification

Switch1(config)# ! MAC 変更通知トラップを有効化
Switch1(config)# snmp-server enable traps mac-notification change

Switch1(config)# ! MAC アドレス変更通知を有効化
Switch1(config)# mac address-table notification change

Switch1(config)# ! 通知間隔を 123 秒に設定
Switch1(config)# mac address-table notification change interval 123

Switch1(config)# ! 通知履歴サイズを 100 に設定
Switch1(config)# mac address-table notification change history-size 100

Switch1(config-if)# ! 特定インターフェイスで MAC 追加通知を有効化
Switch1(config-if)# snmp trap mac-notification change added


## MAC アドレス移動通知トラップ（MAC Move）
Switch1(config)# ! SNMP Trap の送信先を設定
Switch1(config)# snmp-server host 172.20.10.10 traps private mac-notification

Switch1(config)# ! MAC 移動通知トラップを有効化
Switch1(config)# snmp-server enable traps mac-notification move

Switch1(config)# ! MAC 移動通知を有効化
Switch1(config)# mac address-table notification mac-move


## MAC アドレス閾値通知トラップ（Threshold）
Switch1(config)# ! SNMP Trap の送信先を設定
Switch1(config)# snmp-server host 172.20.10.10 traps private mac-notification

Switch1(config)# ! MAC 閾値通知トラップを有効化
Switch1(config)# snmp-server enable traps mac-notification threshold

Switch1(config)# ! MAC 閾値通知を有効化
Switch1(config)# mac address-table notification threshold

Switch1(config)# ! 通知間隔を 123 秒に設定
Switch1(config)# mac address-table notification threshold interval 123

Switch1(config)# ! 閾値を 78 に設定
Switch1(config)# mac address-table notification threshold limit 78


# ===============================
# Static MAC Address Configuration
# ===============================

## 静的 MAC アドレスの設定（インターフェイスへ割り当て）
Switch1(config)# ! VLAN 4 の静的 MAC を Gi1/1/1 に設定
Switch1(config)# mac address-table static c2f3.220a.12f4 vlan 4 interface gigabitethernet1/1/1

## 静的 MAC アドレスのドロップ設定（フィルタ）
Switch1(config)# ! VLAN 4 の指定 MAC をドロップ
Switch1(config)# mac address-table static c2f3.220a.12f4 vlan 4 drop


# ===============================
# MAC Learning Control
# ===============================

## VLAN の MAC 学習を無効化
Switch1(config)# ! VLAN 200 の MAC 学習を無効化
Switch1(config)# no mac address-table learning vlan 200

## MAC 学習状態の確認
Switch1# ! MAC 学習状態の確認
Switch1# show mac-address-table learning
```
---

## 1.1.a (ii) Errdisable recovery

### 📘 概要

ポートが特定のプロトコル違反や異常を検知した際に、デバイス保護のため自動的にポートを無効化（err-disable状態）にする機能、およびそれを自動復旧させるメカニズムです。

### 🔑 要点

| 項目 | 内容 |  
| :--- | :--- |  
| **検知原因 (Causes)** | `bpduguard`, `psecure-violation`, `link-flap`, `storm-control` など。 | 
| **自動復旧の仕組み** | `errdisable recovery` により、管理者の介入なしに設定間隔後に再アクティブ化。 |  
| **デフォルト間隔** | 300秒。最短30秒などの調整が可能。 | 

### Errdisable の主な原因
- BPDU Guard 違反
- RootGuard / LoopGuard の検出
- UDLD Aggressive モード（両端を err-disable）
- Port-security 違反
- Access レイヤの L2 ループ
- トランク設定ミス（DTP）
- EtherChannel 設定ミス（PAgP / LACP）

### CCIE-EI で重要な理由
- UDLD / BPDU Guard / link-flap などは Errdisable recovery の対象にすべき。
- Access レイヤのハードニングが Errdisable 発生を大幅に減らす。
- Routed Access は STP 関連の Errdisable トリガーをほぼ排除できる。


### 🎯 試験対策 (CCIE EIレベル)

*   **迅速な復旧要件**: ラボ試験で「特定の違反（BPDUガード等）によるダウンから、規定時間内に自動復旧させよ」というタスクに対応できるよう、原因（cause）の指定とインターバル（interval）の設定をセットで覚える。
*   EtherChannel の mode on は危険（STP がループ検出 → errdisable）
*   BPDU Guard + PortFast の組み合わせは 試験で頻出
*   UDLD は 両側で有効化しないと errdisable
*   Link-flap は Layer1 問題（ケーブル・SFP・NIC）
*   Port-security violation は shutdown モードがデフォルト
*   L2PT Guard は トンネルポートで PDU を受信すると errdisable


### 🛠 設定・検証コマンド

| 目的 | コマンド |  
| :--- | :--- | 
| **原因の有効化** | <code>errdisable detect cause [all&#124;原因]` |  
| **自動復旧の有効化** | `errdisable recovery cause [原因]` |  
| **復旧間隔の設定** | `errdisable recovery interval ` |  
| **ステータス確認** | `show errdisable recovery` / `show interfaces status err-disabled` |  

```md
# ===============================
# Errdisable Detection / Recovery
# ===============================

## Errdisable の原因を確認
Switch1# ! Errdisable の検出状態を確認
Switch1# show errdisable detect

## Errdisable Recovery の状態を確認
Switch1# ! 自動復旧の設定とタイマーを確認
Switch1# show errdisable recovery

## Errdisable Recovery を有効化（原因を指定）
Switch1(config)# ! BPDU Guard による errdisable を自動復旧
Switch1(config)# errdisable recovery cause bpduguard

Switch1(config)# ! UDLD による errdisable を自動復旧
Switch1(config)# errdisable recovery cause udld

Switch1(config)# ! Link-flap による errdisable を自動復旧
Switch1(config)# errdisable recovery cause link-flap

## Recovery タイマーの変更（デフォルト 300 秒）
Switch1(config)# ! Recovery タイマーを 400 秒に変更
Switch1(config)# errdisable recovery interval 400

## Errdisable 状態のポートを手動で復旧
Switch1(config)# ! shutdown → no shutdown で復旧
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# shutdown
Switch1(config-if)# no shutdown

# ===============================
# BPDU Guard / PortFast
# ===============================

## PortFast を有効化
Switch1(config)# ! 端末接続ポートで PortFast を有効化
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# spanning-tree portfast enable

## BPDU Guard を有効化
Switch1(config)# ! BPDU 受信時にポートを errdisable にする
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# spanning-tree bpduguard enable

# ===============================
# EtherChannel Misconfiguration
# ===============================

## EtherChannel の状態確認
Switch1# ! EtherChannel のステータスを確認
Switch1# show etherchannel summary

## EtherChannel の正しい設定例（desirable）
Switch1(config)# ! 両側が同意した場合のみチャネル形成
Switch1(config)# interface gigabitethernet4/1
Switch1(config-if)# channel-group 3 mode desirable non-silent

# ===============================
# UDLD
# ===============================

## UDLD のエラー例（参考）
Switch1# ! UDLD による errdisable の syslog 例
Switch1# %PM-SP-4-ERR_DISABLE: udld error detected on Gi4/1

# ===============================
# Link-Flap
# ===============================

## Link-flap の値を確認
Switch1# ! フラップ回数と時間を確認
Switch1# show errdisable flap-values

# ===============================
# Port-Security
# ===============================

## Port-security の shutdown モード
Switch1(config)# ! セキュリティ違反時にポートを shutdown
Switch1(config)# interface gigabitethernet4/8
Switch1(config-if)# switchport port-security violation shutdown

# ===============================
# L2PT Guard
# ===============================

## L2PT Guard の設定例
Switch1(config)# ! L2 プロトコルのトンネリング設定
Switch1(config)# interface gigabitethernet0/7
Switch1(config-if)# l2protocol-tunnel stp

## L2PT Guard の自動復旧
Switch1(config)# ! L2PT Guard による errdisable を自動復旧
Switch1(config)# errdisable recovery cause l2ptguard
```

---

## 1.1.a (iii) L2 MTU

### 📘 概要

インターフェイスがドロップせずに通過させることができる最大フレームサイズを規定します。

### 🔑 要点

| 項目 | 内容 |  
| :--- | :--- |  
| **標準MTU** | 1500バイト（イーサネットペイロード）。 |  
| **ジャンボフレーム** | 1500バイトを超えるサイズ（最大9000〜9216バイト）。 |  
| **不一致の影響** | OSPFの隣接関係が `EXSTART` で止まるなどのルーティング問題を引き起こす。 |  
| **設定レベル** | プラットフォームにより、システム全体での設定や個別ポート設定がある。 |  

### MTU に関する重要ベストプラクティス
- 重要なインターフェイスでは `carrier-delay msec 0` を設定し、最速のリンクダウン検出を実現する。
- L3 ルーティッドインターフェイスは L2 SVI より収束が速い（約 8ms vs 150–200ms）。
- L2 集約ポイントは避け、可能な限りポイントツーポイント接続を使うことで MTU 動作が安定する。

### CCIE-EI で重要な理由
- L2/L3 混在設計では MTU ミスマッチが起きやすい。
- Routed Access は MTU に起因する STP/SVI の遅延を排除できる。
- 高速収束を求めるキャンパス設計では MTU 調整が必須。
   
### 🎯 試験対策 (CCIE EIレベル)

*   **MTU不一致の特定**: 物理的な疎通はあるが特定プロトコルが動作しない場合、`show vlan mtu` で不一致（Mismatch）がないか確認する。
*   **オーバーヘッドの考慮**: MPLS等のタグ付け環境では、L2 MTUを拡張（Baby Giant対応）させる必要がある。

### **MTU関連補足**

#### IOS15.2 と IOS-XE17.9の比較

| 項目 | IOS15.2 | IOS-XE17.9 |
| --- | --- | --- |
| system mtu 反映 | **reload 必要** | **即時反映（reload 不要）** |
| per‑interface MTU | 不可 | **可能（ip mtu / ipv6 mtu）** |
| IPv6 MTU 下限 | 1280 未満も可 | **1280 固定（RFC 8200）** |
| Jumbo MTU | 9000 | **9198** |
| MTU 保存場所 | NVRAM環境変数 | **running-config に保存** |
| OSPF MTU mismatch | 起きにくい | **起きやすい（L3 MTU 個別設定のため）** |

### 🛠 設定・検証コマンド

| 目的 | コマンド |  
| :--- | :--- |  
| **システムMTU設定** | `system mtu [サイズ]` または `system jumbomtu [サイズ]` | 
| **個別MTU設定** | `interface` モード配下で `mtu [サイズ]` または `ip mtu [サイズ]` |  
| **設定確認** | `show system mtu` / `show vlan mtu` | 
| **VLAN情報での確認** | `show vlan brief` (システムMTU設定が表示される場合がある) | 

```md
# ===============================
# System MTU Configuration (IOS 15.2)
# ===============================

## FastEthernet のシステム MTU を 1900 bytes に設定
Switch1(config)# ! FastEthernet の MTU を 1900 に設定
Switch1(config)# system mtu 1900

## Gigabit/10G の Jumbo MTU を 7500 bytes に設定
Switch1(config)# ! ギガビット/10G の Jumbo MTU を 7500 に設定
Switch1(config)# system mtu jumbo 7500

## L3 ポートのルーティング MTU を 2000 bytes に設定
Switch1(config)# ! ルーティング MTU を 2000 に設定（再起動不要）
Switch1(config)# system mtu routing 2000

## MTU 設定の確認
Switch1# ! 現在の MTU 設定を確認
Switch1# show system mtu

## MTU 設定反映のための reload
Switch1# ! system mtu / jumbo 設定反映のため reload
Switch1# reload

## 範囲外の Jumbo MTU 設定例（エラー）
Switch1(config)# ! Jumbo MTU に 25000 を設定しようとしてエラー
Switch1(config)# system mtu jumbo 25000
^
% Invalid input detected at '^' marker.
```

```md
# ===============================
# Catalyst 9300 MTU Configuration (IOS-XE 17.9.x)
# ===============================

## システム MTU を 1500 に設定（即時反映）
Switch1(config)# ! システム MTU を 1500 に設定
Switch1(config)# system mtu 1500

## Jumbo MTU を 9198 に設定（即時反映）
Switch1(config)# ! Jumbo MTU を 9198 に設定
Switch1(config)# system mtu jumbo 9198

## L2 インターフェイス MTU を 9000 に設定
Switch1(config)# ! L2 インターフェイスの MTU を 9000 に設定
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# mtu 9000

## L3 インターフェイスの IPv4 MTU を 1500 に設定
Switch1(config)# ! L3 IPv4 MTU を 1500 に設定
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# ip mtu 1500

## L3 インターフェイスの IPv6 MTU を 1500 に設定
Switch1(config)# ! L3 IPv6 MTU を 1500 に設定
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# ipv6 mtu 1500

## MTU 設定の確認
Switch1# ! MTU 設定を確認
Switch1# show system mtu
```
---

## 参考リソースリンク

### Configurationガイド

*   [Managing MAC Address Table ](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst3750x_3560x/software/release/15-2_4_e/configurationguide/b_1524e_consolidated_3750x_3560x_cg/b_1524e_consolidated_3750x_3560x_cg_chapter_0110.html#topic_8B3F5E7D86EB4448B449DFE9EC9A4751)
*   [Configuring System MTU](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst3750x_3560x/software/release/15-2_4_e/configurationguide/b_1524e_consolidated_3750x_3560x_cg/b_1524e_consolidated_3750x_3560x_cg_chapter_010000.html)
*   [Errdisable Recoveryのトラブルシューティングと設定](https://www.cisco.com/c/ja_jp/support/docs/lan-switching/spanning-tree-protocol/69980-errdisable-recovery.html)

### CiscoLive (動画・スライド)

*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/on-demand/on-demand-library.html?search=switches%20campus#/session/1675722366620001tcWQ)
*   [BRKENS-2031: Enterprise Campus Design](https://www.ciscolive.com/on-demand/on-demand-library.html?search=switches%20campus#/session/1675722366753001tPaF)

## 📝 補足



---


