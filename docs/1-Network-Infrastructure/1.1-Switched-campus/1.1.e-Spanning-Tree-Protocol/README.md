---
layout: default
title: 1.1.e-Spanning-Tree-Protocol
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.1.e-Spanning-Tree-Protocol

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.e Spanning Tree Protocol」に関連する、各モード、パラメータ調整、および保護機能について整理しました。

---

## 1.1.e (i) PVST+, Rapid PVST+, MST

### 📘 概要

スパニングツリープロトコル（STP）は、レイヤ2の冗長ネットワークにおいてループを防止するためのプロトコルです。CiscoスイッチはデフォルトでVLANごとにインスタンスを保持するPVST+を実行しますが、CCIEレベルでは高速コンバージェンスのRSTPや、リソースを最適化するMSTの深い理解が求められます。

### 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **PVST+ (802.1D)** | VLANごとに1つのインスタンスを実行。タイマーベース（Forward Delay等）で収束するため収束が遅い（約30-50秒）。 |
| **Rapid PVST+ (802.1w)** | 提案/合意（Proposal/Agreement）メカニズムにより、タイマーを待たずに数秒で収束する。 |
| **MST (802.1s)** | 複数のVLANを1つのインスタンスにマッピングし、CPU/メモリ負荷を軽減する。リージョン（Name, Revision, VLAN-Instance Mapping）の概念を持つ。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **MSTリージョンの一致**: リージョン名、リビジョン番号、VLANマッピングが全スイッチで一致していないと、異なるリージョン間は「1つの巨大なスイッチ（CST）」として扱われる挙動を理解すること。
*   **プロトコルの相互運用性**: Rapid PVST+とレガシー802.1Dデバイスが混在する場合、ポート単位でレガシーモードにフォールバックする挙動を `show spanning-tree interface detail` で確認できるようにする。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **STPモードの変更** | <code>spanning-tree mode [pvst&#124;rapid-pvst&#124;mst]</code> |
| **MSTリージョンの設定** | <code>spanning-tree mst configuration</code> 配下で <code>name</code> / <code>revision</code> / <code>instance</code> |
| **STP全体のサマリー確認** | <code>show spanning-tree summary</code> |
| **MSTマッピングの確認** | <code>show spanning-tree mst configuration</code> |

---

## 1.1.e (ii) Switch priority, port priority, tuning port/path cost, STP timers

### 📘 概要

STPのトポロジー（ルートブリッジやルートポートの位置）を決定するためのパラメータ群です。これらを調整することで、トラフィックのパスを最適化（トラフィックエンジニアリング）します。

### 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **Bridge Priority** | ルートブリッジ選定に使用。4096の倍数で指定。低い値が優先。 |
| **Path Cost** | ルートポート選定に使用。リンク速度に基づく（1G=4, 100M=19等）。Long形式（32bit）への変更も可能。 |
| **Port Priority** | 同一コストの複数パスがある場合のタイブレーク。低い値が優先（デフォルト128）。 |
| **STP Timers** | Hello(2s), Max Age(20s), Forward Delay(15s)。ルートブリッジでのみ設定変更が推奨される。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **パス選定の優先順位**: ルートポート選定の際、1.累積パスコスト、2.送信元ブリッジID、3.送信元ポートプライオリティ、4.送信元ポートID の順で比較されるプロセスを完全に把握すること。
*   **マクロコマンドの活用**: ラボ試験では <code>spanning-tree vlan X root primary</code> を使用して、現在の周囲のプライオリティ値を元に自動で最適値を計算させる手法が効率的です。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **ルートブリッジへの固定** | <code>spanning-tree vlan [ID] root primary</code> |
| **パスコストの変更** | <code>spanning-tree [vlan ID] cost [値]</code> |
| **ポートプライオリティ変更** | <code>spanning-tree [vlan ID] port-priority [値]</code> |
| **ルートブリッジ情報の確認** | <code>show spanning-tree root</code> |

---

## 1.1.e (iii) PortFast, BPDU guard, BPDU filter

### 📘 概要

エッジポート（ホスト接続ポート）の収束を早め、不正なBPDUによるトポロジー変化を防止するための「STP Toolkit」の一部です。

### 🔑 要点

*   **PortFast**: リスニング/ラーニング状態をスキップし、即座にフォワーディング状態にする。TCN（トポロジー変化通知）を発生させない。
*   **BPDU Guard**: PortFast有効ポートでBPDUを受信した場合、ポートを <code>err-disable</code> にして遮断する。
*   **BPDU Filter**: BPDUの送受信を停止させる。グローバル設定時とインターフェイス設定時で挙動が異なる点に注意。

### 🎯 試験対策 (CCIE EIレベル)

*   **Errdisable リカバリ**: BPDU Guardで落ちたポートを自動復旧させる `errdisable recovery cause bpduguard` との組み合わせが頻出です。
*   **Filterの副作用**: BPDU Filterをインターフェイスで有効にすると、そのポートは事実上STPを無視するため、ループ発生のリスクを正しく評価する必要があります。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **PortFastの有効化** | <code>spanning-tree portfast [edge&#124;network]</code> |
| **BPDU Guardの有効化** | <code>spanning-tree bpduguard enable</code> |
| **PortFastステータス確認** | <code>show spanning-tree interface [ID] portfast</code> |
| **無効化原因の確認** | <code>show interfaces status err-disabled</code> |

---

## 1.1.e (iv) Loop guard, root guard

### 📘 概要

物理的な単方向リンク障害や、意図しないルートブリッジの出現からトポロジーを保護する機能です。

### 🔑 要点

*   **Root Guard**: そのポートの先に「より優れたBPDU」を持つスイッチが接続されても、自身がルートポートにならないようブロック（root-inconsistent状態）する。指定ポートに適用する。
*   **Loop Guard**: BPDUが突然届かなくなった際に、そのポートをフォワーディングに移行させず「loop-inconsistent」状態でブロックする。単方向リンクによるループを防ぐ。

### 🎯 試験対策 (CCIE EIレベル)

*   **Root Guardの配置**: 「ネットワークの境界」や「ダウンストリーム側のポート」に配置し、ルートブリッジの位置を強制するタスクが出題されます。
*   **Loop Guard vs UDLD**: UDLD（1.1.b）は物理的な単方向リンクを検知し、Loop GuardはSTPのロジック（BPDUの消失）でループを検知する違いを整理しておくこと。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Root Guardの有効化** | <code>spanning-tree guard root</code> |
| **Loop Guardの有効化** | <code>spanning-tree guard loop</code> |
| **不整合ポートの確認** | <code>show spanning-tree inconsistentports</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. MST インスタンスの最適化

**【問題内容】**
Cat1, Cat2, Cat3において、リージョン名「CCIE」リビジョン「1」としてMSTを構成せよ。VLAN 10, 20をインスタンス1に、VLAN 30, 40をインスタンス2に割り当て、Cat1がインスタンス1、Cat2がインスタンス2のルートブリッジになるように調整せよ。

**【設定サンプル】**
```ios
! 全スイッチ共通
spanning-tree mode mst
spanning-tree mst configuration
 name CCIE
 revision 1
 instance 1 vlan 10, 20
 instance 2 vlan 30, 40
 exit

! Cat1
spanning-tree mst 1 root primary

! Cat2
spanning-tree mst 2 root primary
```

### 2. ルートブリッジ保護とエッジセキュリティ

**【問題内容】**
Cat1のE0/1ポートの先に新しいスイッチが接続されてもルートブリッジを奪われないように保護せよ。また、Cat1のE1/0ポート（PC接続用）はリンクアップ後すぐに通信可能にし、万が一BPDUを受信した場合は即座にポートを遮断し、5分後に自動復旧するように設定せよ。

**【設定サンプル】**
```ios
! ルート保護
interface Ethernet0/1
 spanning-tree guard root

! エッジ保護
interface Ethernet1/0
 spanning-tree portfast edge
 spanning-tree bpduguard enable
 exit

! 自動復旧設定
errdisable recovery cause bpduguard
errdisable recovery interval 300
```

---

## 参考リソースリンク

### Configurationガイド
*   [Configuring STP (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/m_stp.html)
*   [Configuring MSTP (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/m_mstp.html)
*   [Spanning Tree Protocol Enhancements (Cisco公式ドキュメント)](https://www.cisco.com/c/ja_jp/support/docs/lan-switching/spanning-tree-protocol/10596-84.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKRST-3320: Troubleshooting Spanning Tree Protocol](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

## 📝 補足
- 補足情報をここに追加してください。

