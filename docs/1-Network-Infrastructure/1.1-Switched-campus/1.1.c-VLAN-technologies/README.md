---
layout: default
title: 1.1.c-VLAN-technologies
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.1.c-VLAN-technologies

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.c VLAN technologies」に関連する技術（Access/Trunk ports, Native VLAN, Pruning, VLAN Ranges, Voice VLAN）について整理しました。

---

## 1.1.c (i) Access ports & (v) Normal/Extended range VLANs

### 📘 概要

VLAN（Virtual LAN）は、物理的なスイッチを論理的に分割し、ブロードキャストドメインを分離する技術です。アクセスポートは、特定の1つのVLANに属し、タグなし（Untagged）フレームをやり取りするエンドデバイス向けのポートです。

### 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **Normal Range** | VLAN 1～1005。情報は <code>vlan.dat</code> に保存され、VTP全バージョンで同期可能です。 |
| **Extended Range** | VLAN 1006～4094。VTP v1/v2では **Transparentモード** でのみ作成可能ですが、v3ではServerモードでも作成・伝播可能です。 |
| **保存先** | Normal RangeはFlash内の <code>vlan.dat</code>、Extended Rangeは <code>running-config</code> に保存されるのが基本です。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **VLANの不整合**: VLANを削除しても、そのVLANに属していたアクセスポートは自動的にVLAN 1に戻らず「inactive」状態になります。`show vlan brief` でポートが表示されない場合はこの状態を疑います。
*   **VTPモードの制約**: ラボ試験で「VLAN 2000を作成せよ」というタスクに対し、VTPモードがServer/Client（v1/v2）の場合は作成できません。`vtp mode transparent` への変更、または VTP v3 へのアップグレードを自ら判断する必要があります。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **VLAN作成** | <code>vlan [VLAN_ID]</code> |
| **アクセスポート割り当て** | <code>switchport mode access</code> <br> <code>switchport access vlan [VLAN_ID]</code> |
| **VLAN要約確認** | <code>show vlan brief</code> |
| **ポートのL2状態確認** | <code>show interfaces [ID] switchport</code> |

---

## 1.1.c (ii) Trunk ports (802.1Q) & (iii) Native VLAN

### 📘 概要

トランクポートは、複数のVLANトラフィックを単一の物理リンクで伝送するスイッチ間接続用ポートです。IEEE 802.1Qカプセル化を使用してフレームにVLAN ID（タグ）を付加します。

### 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **Native VLAN** | トランクリンク上でタグを付けずに送受信されるVLANです。デフォルトはVLAN 1です。 |
| **DTP (Dynamic Trunking Protocol)** | トランクの形成を自動交渉するシスコ独自のプロトコルです。 |
| **タグ付けの強制** | <code>vlan dot1q tag native</code> 設定により、Native VLANのフレームにも強制的にタグを付与できます。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **セキュリティとDTP**: セキュリティの観点から、DTPによる自動交渉を無効化（`nonegotiate`）し、トランクを静的に固定することが推奨されます。
*   **Native VLANの不一致**: 両端でNative VLANが異なると、`Port VLAN ID Mismatch` ログが出力され、STPが不整合を検知してポートをブロックする原因となります。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **トランクカプセル化指定** | <code>switchport trunk encapsulation dot1q</code> |
| **トランクモード固定** | <code>switchport mode trunk</code> |
| **DTP無効化** | <code>switchport nonegotiate</code> |
| **Native VLAN変更** | <code>switchport trunk native vlan [VLAN_ID]</code> |
| **トランク状態の詳細確認** | <code>show interfaces trunk</code> |

---

## 1.1.c (iv) Manual VLAN pruning

### 📘 概要

トランクリンク上で許可するVLANを手動で制限（Pruning）し、不要なブロードキャストトラフィックが他スイッチへ流れるのを防ぐ技術です。

### 🔑 要点

*   **デフォルトの挙動**: 全てのVLAN（1～4094）がトランクで許可されています。
*   **制御方法**: `switchport trunk allowed vlan` コマンドを使用して、特定のVLANのみを通すようにフィルタリングします。

### 🎯 試験対策 (CCIE EIレベル)

*   **add/removeの使い分け**: 既存の許可リストを変更する場合、`add` や `remove` キーワードを忘れると、全てのリストが上書きされてしまいます。
*   **VLAN 1の最小化**: ラボ試験では、管理用トラフィックを除き、VLAN 1をトランクから排除する構成が問われることがあります。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **許可VLANを上書き指定** | <code>switchport trunk allowed vlan [VLAN_LIST]</code> |
| **特定のVLANを追加** | <code>switchport trunk allowed vlan add [VLAN_ID]</code> |
| **特定のVLANを削除** | <code>switchport trunk allowed vlan remove [VLAN_ID]</code> |
| **許可リストの確認** | <code>show interfaces trunk</code> |

---

## 1.1.c (vi) Voice VLAN

### 📘 概要

1つの物理ポートにIP PhoneとPCを同時に接続する場合に、音声トラフィック（Voice）とデータトラフィック（Data）を別々のVLANに分離して処理する機能です。

### 🔑 要点

*   **CDPの役割**: スイッチはCDPを使用して、IP Phoneに対し「音声用VLAN ID」を通知します。
*   **PortFastの自動有効化**: Voice VLANを構成すると、そのポートでは自動的にスパニングツリーの **PortFast** が有効になります。

### 🎯 試験対策 (CCIE EIレベル)

*   **ポートセキュリティとの競合**: Voice VLAN環境で `switchport port-security` を使用する場合、最大MACアドレス数を2（電話用とPC用）以上に設定しないと、意図せずポートが `err-disabled` になるシナリオが頻出します。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Voice VLANの割り当て** | <code>switchport voice vlan [VLAN_ID]</code> |
| **音声VLAN設定の確認** | <code>show interfaces [ID] switchport</code> |
| **IP Phoneの認識確認** | <code>show cdp neighbors</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIEレベルの実装シナリオ例です。

### 1. Trunking & Native VLAN の実装

**【問題内容】**
Cat1とCat2の間で 802.1Q トランクを構成せよ。Native VLANとして 99 を使用し、VLAN 10, 20 のトラフィックのみを許可すること。また、対向デバイスとの DTP ネゴシエーションを停止させ、トランク状態を固定せよ。

**【設定サンプル】**

```ios
Cat1(config)# interface Ethernet3/0
Cat1(config-if)# switchport trunk encapsulation dot1q
Cat1(config-if)# switchport mode trunk
Cat1(config-if)# switchport nonegotiate
Cat1(config-if)# switchport trunk native vlan 99
Cat1(config-if)# switchport trunk allowed vlan 10,20
```

### 2. Extended Range VLAN & VTP

**【問題内容】**
VTPバージョン2を使用している環境で、新しいサービス用に VLAN 2500 を作成せよ。VTPによる既存の同期を維持したまま、この詳細な設定を実現すること。

**【設定サンプル】**
```ios
! Extended range作成のため、対象スイッチを一時的にTransparentにする必要がある
Switch(config)# vtp mode transparent
Switch(config)# vlan 2500
Switch(config-vlan)# name Extended_VLAN
```

---

## 参考リソースリンク

### Configurationガイド
*   [VLAN設定ガイド (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/m_vlan.html)
*   [VLANトランクの設定 (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/m_vlan_trunks.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKENS-2031: Enterprise Campus Design](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)


