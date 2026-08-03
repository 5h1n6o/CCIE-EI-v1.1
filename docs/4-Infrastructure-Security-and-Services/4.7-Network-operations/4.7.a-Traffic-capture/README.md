---
layout: default
title: 4.7.a-Traffic-capture
parent: 4.7-Network-operations
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.7.a Traffic capture

ネットワークの運用において、パケットレベルの可視化はトラブルシューティング、セキュリティ分析、およびパフォーマンス最適化の生命線です。本稿では、Cisco IOS XE デバイスにおける主要なキャプチャ技術である SPAN シリーズと、デバイス内部でパケットを収集する Embedded Packet Capture (EPC) について、CCIE Enterprise Infrastructure (EI) レベルの深度で詳述します。

---

## 📘 概要

**Traffic Capture（トラフィックキャプチャ）** は、ネットワークを通過する実際のパケットを複製または直接収集するプロセスを指します。CCIE EI 試験のコンテキストでは、主に以下の 2 つのアプローチが問われます。

1.  **SPAN (Switched Port Analyzer) ファミリー:** ハードウェアのスイッチング機能を活用してトラフィックを「複製（Mirroring）」し、外部の解析デバイス（スニッファーなど）に転送する技術です。
    *   **SPAN:** 同一スイッチ内での複製。
    *   **RSPAN:** レイヤ 2 ネットワークを跨いだ複製。
    *   **ERSPAN:** IP (GRE) ネットワークを跨いだレイヤ 3 経由の複製。
2.  **EPC (Embedded Packet Capture):** デバイス自身の CPU やメモリリソースを使用して、パケットを内部バッファに直接記録する機能です。外部に専用のキャプチャデバイスを用意できない環境や、デバイスへの入出力を即座に確認したい場合に極めて有効です。

---

## 🔑 要点

### 1. SPAN, RSPAN, ERSPAN の比較

各技術は、トラフィックを転送できる「距離」と「プロトコル層」に違いがあります。

| 特徴 | SPAN (Local) | RSPAN (Remote) | ERSPAN (Encapsulated) |
| :--- | :--- | :--- | :--- |
| **転送範囲** | 同一スイッチ内 | 同一 L2 ドメイン内 | L3 到達性のある全ネットワーク |
| **転送メカニズム** | 内部バスのコピー | 特殊な RSPAN VLAN | GRE カプセル化 (IP) |
| **主な要件** | 同一筐体内のポート | 全経路での RSPAN VLAN 許可 | ソース/宛先 IP の到達性 |
| **識別子** | セッション ID | RSPAN VLAN ID | ERSPAN ID / IP アドレス |

### 2. SPAN の主要コンポーネント

*   **Source (ソース):** 監視対象。物理ポート、EtherChannel、または VLAN を指定可能です。
*   **Destination (宛先):** 複製データの出力先。通常、宛先ポートは通常のスイッチングトラフィックを転送できなくなります。
*   **Direction (方向):** 入力 (Rx)、出力 (Tx)、または両方 (Both) を選択できます。

### 3. Embedded Packet Capture (EPC) の構造

EPC は「どこで」「どのように」パケットを保持するかを定義する 2 つの論理要素で構成されます。
*   **Capture Buffer (バッファ):** パケットを保存するメモリ上の場所。サイズや、バッファが一杯になった時の動作（上書きか停止か）を定義します。
*   **Capture Point (ポイント):** パケットを「捕まえる」場所。インターフェイスや方向、または CPU（Control Plane）を指定します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる設定コマンドの入力だけでなく、ネットワーク構成に基づいた「最適なキャプチャ手法の選択」と「制限事項の回避」が求められます。

### 1. RSPAN VLAN の管理

*   RSPAN を使用する場合、専用の VLAN を作成し `remote-span` コマンドで属性を指定する必要があります。
*   **罠:** 中継スイッチのトランクリンクで RSPAN VLAN が Pruning（除外）されていないか、あるいは STP によってブロックされていないかを確認するスキルが問われます。

### 2. ERSPAN の L3 到達性と MTU

*   ERSPAN はパケットを GRE でカプセル化するため、追加のヘッダー分だけパケットサイズが増大します。
*   ネットワーク内での断片化（Fragmentation）やドロップを防ぐため、宛先までの MTU や、正しい Source/Destination IP の指定が構成上の鍵となります。

### 3. EPC による特定トラフィックのフィルタリング

*   全パケットをキャプチャすると、バッファが即座に溢れるだけでなく、デバイスの負荷が高まります。
*   試験では「特定の ACL に一致するトラフィックのみを EPC でキャプチャせよ」といった条件付きのタスクが出題されます。

### 4. 宛先ポートの動作

*   SPAN の Destination ポートに設定されたインターフェイスは、デフォルトで通常の着信トラフィックを無視します。
*   解析用 PC がそのポート経由でデバイスを管理（SSH/Telnet）する必要がある場合、`ingress vlan` オプションを使用して宛先ポートでの限定的な通信を許可する構成が求められることがあります。

---

## 🛠 設定・検証コマンド

### SPAN / RSPAN / ERSPAN 設定

| 目的 | コマンド |
| :--- | :--- |
| **Local SPAN ソース設定** | <code>monitor session [ID] source interface [INT] [both&#124;rx&#124;tx]</code> |
| **Local SPAN 宛先設定** | <code>monitor session [ID] destination interface [INT]</code> |
| **RSPAN VLAN の定義** | <code>(config-vlan)# remote-span</code> |
| **RSPAN 宛先 (VLAN) 指定** | <code>monitor session [ID] destination vlan [RSPAN_VLAN]</code> |
| **ERSPAN ソースセッション** | <code>monitor session [ID] type erspan-source</code> |
| **ERSPAN 宛先IP/ID指定** | <code>(config-mon-erspan-src)# destination ip [IP]</code> <br> <code>(config-mon-erspan-src)# erspan-id [ID]</code> |

### EPC (Embedded Packet Capture) 設定

| 目的 | コマンド |
| :--- | :--- |
| **バッファの作成** | <code>monitor capture [BUF_NAME] buffer size [KB] [circular&#124;linear]</code> |
| **ポイントの定義(IF指定)** | <code>monitor capture [POINT_NAME] interface [INT] [both&#124;in&#124;out]</code> |
| **バッファとポイントの紐付け** | <code>monitor capture [POINT_NAME] buffer [BUF_NAME]</code> |
| **キャプチャの開始/停止** | <code>monitor capture [POINT_NAME] [start&#124;stop]</code> |
| **外部へのPCAPエクスポート** | <code>monitor capture [BUF_NAME] export [flash:&#124;ftp:&#124;tftp:]filename.pcap</code> |

### 検証・統計確認

| 目的 | コマンド |
| :--- | :--- |
| **SPANセッションの状態表示** | <code>show monitor session [ID &#124; all]</code> |
| **EPCの構成と状態確認** | <code>show monitor capture [NAME]</code> |
| **キャプチャされたパケットの表示** | <code>show monitor capture [BUF_NAME] buffer [brief&#124;detailed&#124;dump]</code> |
| **プラットフォーム固有の統計** | <code>show platform software fed switch active monitor ...</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 単一ポートの Local SPAN

**【要件】** Gi1/0/1 の双方向トラフィックを、解析用 PC が接続された Gi1/0/24 にミラーリングせよ。
```ios
monitor session 1 source interface GigabitEthernet1/0/1 both
monitor session 1 destination interface GigabitEthernet1/0/24
```

### 2. 特定 VLAN を対象とした SPAN

**【要件】** VLAN 100 に属する全パケットを監視せよ。
```ios
monitor session 1 source vlan 100
monitor session 1 destination interface GigabitEthernet1/0/24
```

### 3. RSPAN の送信元スイッチ構成

**【要件】** VLAN 999 を RSPAN VLAN とし、Gi0/1 の入力をこの VLAN へ転送せよ。
```ios
vlan 999
 remote-span
!
monitor session 10 source interface GigabitEthernet0/1 rx
monitor session 10 destination vlan 999
```

### 4. RSPAN の宛先スイッチ構成

**【要件】** RSPAN VLAN 999 からパケットを取り出し、Gi0/10 に接続されたスニッファーへ出力せよ。
```ios
vlan 999
 remote-span
!
monitor session 10 source vlan 999
monitor session 10 destination interface GigabitEthernet0/10
```

### 5. ERSPAN による L3 ネットワーク越しの監視

**【要件】** R1 (10.1.1.1) の Gi1 トラフィックを、遠隔地の R2 (192.168.1.1) へ ID 100 で転送せよ。
```ios
monitor session 1 type erspan-source
 source interface GigabitEthernet1 both
 destination
  erspan-id 100
  ip address 192.168.1.1
  origin ip address 10.1.1.1
```

### 6. EPC の基本設定（バッファとポイント）

**【要件】** Gi0/1 の入出力を 1MB のバッファ `MY_BUF` にキャプチャせよ。
```ios
monitor capture MY_BUF buffer size 1024
monitor capture MY_POINT interface GigabitEthernet0/1 both
monitor capture MY_POINT buffer MY_BUF
monitor capture MY_POINT start
```

### 7. ACL を使用した EPC のフィルタリング

**【要件】** 特定の送信元 (10.10.10.1) からのトラフィックのみを EPC で抽出せよ。
```ios
ip access-list extended CAP_FILTER
 permit ip host 10.10.10.1 any
!
monitor capture MY_BUF access-list CAP_FILTER
```

### 8. EPC バッファの循環（Circular）設定

**【要件】** バッファが一杯になっても最新のパケットを保持し続けるよう設定せよ。
```ios
monitor capture MY_BUF buffer circular
```

### 9. Control Plane (CPU) トラフィックの EPC

**【要件】** ルータの CPU に届くルーティングプロトコル等のパケットを監視せよ。
```ios
monitor capture CPU_CAP control-plane both
monitor capture CPU_CAP buffer MY_BUF
```

### 10. SPAN 宛先ポートでの管理アクセスの許可

**【要件】** キャプチャ用ポート Gi1/0/24 で、VLAN 10 の管理通信を許可せよ。
```ios
monitor session 1 destination interface GigabitEthernet1/0/24 ingress vlan 10
```

### 11. 複数のソースインターフェイスの指定

**【要件】** Gi1/0/1 から Gi1/0/5 までの全ての通信を 1 つのセッションで監視せよ。
```ios
monitor session 2 source interface GigabitEthernet1/0/1 - 5
```

### 12. キャプチャ結果のダンプ表示 (検証)

**【手順】** EPC で取得したパケットの内容を ASCII 形式で CLI 上に表示せよ。
```ios
show monitor capture MY_BUF buffer detailed
! 期待される出力: パケットのヘッダー、ペイロード、タイムスタンプが表示される。
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKTRS-2811: Overview of Packet Capturing and Traffic Analysis Tools**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-2811)
    *   Cisco デバイスにおける全キャプチャ技術（SPAN, EPC, Wireshark 統合）の包括的なセッション。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE ラボ試験におけるトラブルシューティングツールの重要性と活用法。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Network Management Configuration Guide - SPAN and RSPAN**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sys_mgmt/b_179_sys_mgmt_9300_cg.html)。
*   [**Embedded Packet Capture Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/epc/configuration/xe-17/epc-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Troubleshooting Cisco IOS Embedded Packet Capture (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios-embedded-packet-capture/116045-config-epc-00.html)。
*   [**ERSPAN Configuration and Troubleshooting (White Paper)**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-6500-series-switches/112011-erspan-config-00.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 実技試験において、物理的なパケットの流れを「透明化」し、論理的なエラーの原因を迅速に特定するための強力な武器を整理したものです。特に **EPC のフィルタリング設定** と **RSPAN VLAN の属性指定** はラボ試験で即座に設定できるレベルまで習熟してください。


