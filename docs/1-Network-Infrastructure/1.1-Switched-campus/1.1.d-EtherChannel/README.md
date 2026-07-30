---
layout: default
title: 1.1.d-EtherChannel
parent: 1.1-Switched-campus
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

# 1.1.d EtherChannel

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.1.d EtherChannel」に関連する、LACP/Static構成、L2/L3 EtherChannel、負荷分散、誤設定ガード、およびマルチシャーシEtherChannel（MEC）について、整理しました。

---

## 1.1.d (i) LACP, static

### 📘 概要

EtherChannelは、複数の物理イーサネットリンクを1つの論理リンク（ポートチャネル）に束ねる技術で、帯域幅の拡大と冗長性の確保を実現します。LACP（Link Aggregation Control Protocol）はIEEE 802.3adに基づく業界標準のネゴシエーションプロトコルです。

### 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **LACP (802.3ad)** | 業界標準プロトコル。モードには <code>active</code>（能動的）と <code>passive</code>（受動的）がある。 |
| **Static (on)** | プロトコルを使用せず強制的にチャネルを形成する。対向も <code>on</code> である必要がある。 |
| **PAgP** | シスコ独自のプロトコル（参考）。モードは <code>desirable</code> と <code>auto</code>。 |
| **LACP優先度** | システム優先度（System Priority）とポート優先度（Port Priority）で、アクティブなリンクを決定する。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **形成条件の不一致**: 片側を <code>active</code> に設定した場合、対向は <code>active</code> または <code>passive</code> である必要があります。両端が <code>passive</code>（またはPAgPの <code>auto</code>）の場合は形成されません。
*   **LACP最大リンク**: LACPでは最大16リンクまで構成可能ですが、アクティブにできるのは通常8リンクまでです。<code>lacp max-bundle</code> コマンドによる制御が問われることがあります。
*   **トラブルシューティング**: <code>show etherchannel summary</code> でフラグを確認し、<code>D</code>（Down）や <code>I</code>（Stand-alone）になっている原因を特定します。L2設定（VLAN、トランク設定）の不一致が主な原因です。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **LACP設定(Active)** | <code>channel-group [ID] mode active</code> |
| **Static(ON)設定** | <code>channel-group [ID] mode on</code> |
| **LACPシステム優先度** | <code>lacp system-priority [値]</code> |
| **LACPポート優先度** | <code>lacp port-priority [値]</code> |
| **要約ステータス確認** | <code>show etherchannel summary</code> |
| **ネゴシエーション確認** | <code>show lacp neighbor</code> |

---

## 1.1.d (ii) Layer 2, Layer 3

### 📘 概要

EtherChannelは、VLAN情報を運ぶレイヤ2（L2）トランク/アクセスリンクとして動作させることも、IPアドレスを直接割り当てるレイヤ3（L3）ルーテッドリンクとして動作させることも可能です。

### 🔑 要点

| モード | 特徴 |
| :--- | :--- |
| **Layer 2** | スイッチポートとして動作。トランク（802.1Q）またはアクセスポートとして設定される。 |
| **Layer 3** | ルーテッドポートとして動作。物理ポートで <code>no switchport</code> を実行してから束ねる。 |

### 🎯 試験対策 (CCIE EIレベル)

*   **L3 EtherChannelの構築手順**: L3構成時、物理インターフェイスとポートチャネルインターフェイスの両方で <code>no switchport</code> が必要です。ラボ試験では「L3 EtherChannelを使い、OSPFネイバーを確立せよ」といった複合タスクが出題されます。
*   **一貫性の要件**: メンバインターフェイス間での速度、デュプレックス、および <code>switchport</code> モードの一致が必須です。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **物理ポートのL3化** | <code>no switchport</code> |
| **L3 IPアドレス設定** | <code>interface port-channel [ID]</code> 配下で <code>ip address [IP] [MASK]</code> |
| **L2 トランク設定** | <code>interface port-channel [ID]</code> 配下で <code>switchport mode trunk</code> |
| **IP到達性確認** | <code>show ip interface brief</code> |

---

## 1.1.d (iii) Load balancing

### 📘 概要

EtherChannelは、ハッシュアルゴリズムを使用してトラフィックをメンバリンク間に分散させます。

### 🔑 要点

*   **ハッシュ入力**: 送信元/宛先MACアドレス、送信元/宛先IPアドレス、送信元/宛先ポート番号などを組み合わせて計算されます。
*   **設定の範囲**: 負荷分散の設定は通常**デバイス全体のグローバル設定**であり、すべてのポートチャネルに影響します。

### 🎯 試験対策 (CCIE EIレベル)

*   **アルゴリズムの最適化**: ラボ試験で「特定のトラフィック（例：特定のサーバ間）の偏りを防ぐため、宛先MACアドレスに基づいて負荷分散せよ」といった、具体的なハッシュ方式の指定がなされる場合があります。
*   **検証**: <code>show etherchannel load-balance</code> を使用して、現在どの方式が有効かを確認します。

### 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **負荷分散方式の設定** | <code>port-channel load-balance [方式]</code> |
| **宛先MACでの分散** | <code>port-channel load-balance dst-mac</code> |
| **設定の確認** | <code>show etherchannel load-balance</code> |

---

## 1.1.d (iv) EtherChannel misconfiguration guard & (v) multichassis EtherChannel

### 📘 概要

*   **Misconfiguration Guard**: EtherChannelのパラメータ不一致（片方が束ねられ、もう片方が束ねられていない等）を検知し、ループ防止のためにポートを <code>err-disable</code> にします。
*   **MEC (Multichassis EtherChannel)**: StackWiseやVSS（Virtual Switching System）を使用して、物理的に異なる2台のスイッチを1台の論理スイッチとして扱い、それらを跨ぐEtherChannelを形成します。

### 🔑 要点

*   **MECの利点**: リンク冗長性に加え、スイッチ筐体レベルの冗長性を提供します。STPのブロックポートを排除し、有効帯域を最大化できます。
*   **検知メカニズム**: Misconfiguration GuardはSTPのBPDUを使用して不整合を検出します。

### 🎯 試験対策 (CCIE EIレベル)

*   **err-disableの復旧**: ガード機能によって <code>err-disabled</code> になった場合、原因を修正した上で <code>errdisable recovery cause etherchannel</code> による自動復旧、または手動での <code>shutdown/no shutdown</code> が必要です。
*   **スタック環境の構成**: StackWise環境において、スタックメンバを跨ぐポート（例：SW1のGi1/0/1とSW2のGi2/0/1）でEtherChannelを構成する手順を把握しておく必要があります。

---

## 🛠 ラボ学習・設定サンプル例

### 1. L3ルーテッド EtherChannel (LACP) の実装
**【問題内容】**
SW1とSW2の間でLACPを使用したレイヤ3 EtherChannelを構成せよ。物理ポートは E0/0, E0/1 を使用し、ポートチャネル番号は 12 とする。SW1は能動的に交渉を開始し、SW2は受動的に待機すること。SW1側に 10.1.12.1/24、SW2側に 10.1.12.2/24 を割り当て、疎通を確認せよ。

**【設定サンプル】**
```ios
! SW1 (Active)
SW1(config)# interface range e0/0 - 1
SW1(config-if-range)# no switchport
SW1(config-if-range)# channel-group 12 mode active
SW1(config-if-range)# exit
SW1(config)# interface port-channel 12
SW1(config-if)# ip address 10.1.12.1 255.255.255.0

! SW2 (Passive)
SW2(config)# interface range e0/0 - 1
SW2(config-if-range)# no switchport
SW2(config-if-range)# channel-group 12 mode passive
SW2(config-if-range)# exit
SW2(config)# interface port-channel 12
SW2(config-if)# ip address 10.1.12.2 255.255.255.0
```

### 2. 負荷分散アルゴリズムの調整

**【問題内容】**
ネットワーク全体のEtherChannelトラフィックが、宛先IPアドレスに基づいて分散されるように設定せよ。設定後、現在の設定値を検証コマンドで示せ。

**【設定サンプル】**
```ios
SW1(config)# port-channel load-balance dst-ip
SW1# show etherchannel load-balance
! 出力で "EtherChannel Load-Balancing Configuration: dst-ip" を確認
```

---

## 参考リソースリンク

### Configurationガイド
*   [Configuring EtherChannels (Catalyst 9300 / IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/lyr2/b_179_lyr2_9300_cg/m_etherchannels.html)
*   [Layer 2 EtherChannelの設定 (Catalyst 2960-X)](https://www.cisco.com/c/ja_jp/td/docs/switches/lan/catalyst2960x/software/15-0_2_EX/configuration_guide/b_152_2ex_lyr2_2960x_cg/b_152_2ex_lyr2_2960x_cg_chapter_010.html)

### CiscoLive (動画・スライド)
*   [BRKENS-1501: Enterprise Campus Wired Design Fundamentals](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
*   [BRKENS-2031: Enterprise Campus Design](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)

## 📝 補足

- 補足情報をここに追加してください。

