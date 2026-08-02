---
layout: default
title: 3.2.a-Operations
parent: 3.2-MPLS
grand_parent: 3-Transport-Technologies-and-Solutions
nav_order: 1
---

# 3.2 MPLS Operations

CCIE Enterprise Infrastructure (EI) v1.1 Blueprintにおける「3.2 MPLS」および「3.2.a Operations」について整理しました。

---

## 📘 概要

**MPLS (Multiprotocol Label Switching)** は、パケットの転送にIPヘッダーではなく「ラベル」を使用する転送技術です。従来のルータがパケットを受信するたびにルーティングテーブル全体を検索（IP Lookup）していたのに対し、MPLSはパケットの入り口で一度だけラベルを付与し、ネットワーク内部ではラベルの付け替え（Swap）のみで高速に転送を行います。

CCIE EI試験においては、単なるデータ転送技術としてだけでなく、L3VPNなどのオーバーレイサービスを支える「トランスポートインフラ」としての動作理解が不可欠です。特に、ラベル配布プロトコルである **LDP (Label Distribution Protocol)** の確立条件や、**PHP (Penultimate Hop Popping)** などの特殊な転送動作、および **MPLS OAM** を用いたトラブルシューティング能力が厳しく問われます。

---

## 🔑 要点

### 1. Label Stack と LSR の役割 (3.2.a.i)

MPLSパケットの先頭には32ビットの「ラベル」が付加されます。
*   **Label (20ビット):** 転送に使用される実際の識別子です。
*   **EXP (3ビット):** QoS（Class of Service）に使用されます。
*   **S (1ビット):** スタックビット。複数のラベルがある場合、底（最後のラベル）であることを示します。
*   **TTL (8ビット):** IP TTLと同様、ループ防止に使用されます。

**LSR (Label Switch Router)** は、役割に応じて3種類に分類されます。
*   **Ingress LSR (PE):** IPパケットを受信し、ラベルを付与（Push）してMPLSドメインへ送出します。
*   **Transit LSR (P):** 到着したラベルを別のラベルに付け替え（Swap）て転送します。
*   **Egress LSR (PE):** ラベルを除去（Pop）し、元のIPパケットとして転送します。

### 2. LSP (Label Switched Path) の形成

**LSP** は、特定の宛先に対してラベルによって定義された単方向のパスです。このパスは、後述するLDPなどのシグナリングプロトコルによって動的に構築されます。

### 3. LDP (Label Distribution Protocol) の動作 (3.2.a.ii)

LDPは、隣接するLSR間でラベル情報を交換するための標準プロトコルです。
*   **Hello (UDP 646):** 224.0.0.2宛にマルチキャストを送り、ネイバーを動的に検出します。
*   **Session (TCP 646):** ネイバー検出後、TCP接続を確立してラベルマッピング情報を同期します。
*   **LDP Router-ID:** セッション確立に使用されます。デフォルトでは最高のLoopback IPが選ばれますが、これが他ルータから疎通不可であるとセッションが確立されません。

### 4. MPLS OAM (3.2.a.iii)

MPLSネットワーク内では、通常のIP Pingがラベルスイッチングの正常性を正確に反映しない場合があります。
*   **MPLS Ping:** ラベル付きパケットとして送信し、LSPの整合性を確認します。
*   **MPLS Traceroute:** LSPに沿って各ホップのラベル割り当て状況を確認します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、MPLS単体よりも「LDPの確立阻害要因」や「ラベルの最適化」がトラブルシューティングの対象となります。

### 1. LDP Router-ID の到達性

LDPセッション（TCP 646）を張るためには、互いの **LDP Router-ID へのユニキャスト到達性** がIGP（OSPF/EIGRP）上で確保されている必要があります。
*   **罠:** `redistribute connected` を忘れてLoopbackが広報されていない、あるいはフィルタによって拒否されていると、LDPネイバーはUPしません。

### 2. PHP (Penultimate Hop Popping) の理解

Egress LSRは、自身の1つ手前のルータ（Penultimate Hop）に対し、「ラベルを外して送る（Pop）」ように要求します（Implicit Null, ラベル3）。
*   **目的:** Egress LSRが「ラベル除去」と「IPルックアップ」を同時に行う負荷を軽減するためです。`show mpls forwarding-table` で `Pop Label` と表示されるポイントを確認してください。

### 3. LDP-IGP Synchronization

IGPがUPしてもLDPがまだUPしていない期間、トラフィックがドロップする可能性があります。
*   **対策:** `mpls ldp sync` を構成することで、LDPの準備ができるまでIGPメトリックを最大値に保ち、ブラックホール化を防ぐ実装が問われます。

### 4. ラベル配布の制御 (Filtering)

デフォルトでは全経路にラベルが振られますが、リソース節約のため特定のプレフィックス（通常はLoopbackのみ）に限定する設定が求められることがあります。

---

## 🛠 設定・検証コマンド

### MPLS / LDP 基本設定

| 目的 | コマンド |
| :--- | :--- |
| **IFでのMPLS有効化** | <code>(config-if)# mpls ip</code> |
| **LDP Router-IDの固定** | <code>(config)# mpls ldp router-id [interface] [force]</code> |
| **LDPセッション保護の有効化** | <code>(config)# mpls ldp session protection</code> |
| **パスワード認証の設定** | <code>(config)# mpls ldp neighbor [IP] password [PWD]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **LDPネイバーの確認** | <code>show mpls ldp neighbor</code> |
| **ラベル転送テーブル(LFIB)の確認** | <code>show mpls forwarding-table</code> |
| **ラベル情報ベース(LIB)の確認** | <code>show mpls ldp bindings</code> |
| **LDP検出状態の確認** | <code>show mpls ldp discovery</code> |
| **MPLS Pingの実行** | <code>ping mpls ipv4 [PREFIX] [MASK]</code> |
| **MPLS Tracerouteの実行** | <code>traceroute mpls ipv4 [PREFIX] [MASK]</code> |

---

## 🛠 ラボ学習・設定サンプル例

ソースのWorkbookシナリオに基づいた、MPLS Operationsの12個の実装例です。

### 1. 全インターフェイスでの一括 MPLS 有効化

**【問題内容】** 
OSPFプロセス1で有効なすべてのインターフェイスにおいて、MPLS LDPを動的に有効化せよ。
**【設定例】**
```ios
router ospf 1
 mpls ldp autoconfig
```

---

### 2. LDP Router-ID の明示的指定

**【問題内容】** 
R1において、物理IPアドレスの変化に影響されないよう、Loopback 0をLDP Router-IDとして使用し、即座に反映させよ。
**【設定例】**
```ios
mpls ldp router-id Loopback0 force
```

---

### 3. LDP ネイバー間の MD5 認証

**【問題内容】** 
R1とR2の間で、LDPメッセージの改ざんを防ぐため、パスワード "CISCO" を用いたMD5認証を構成せよ。
**【設定例】**
```ios
mpls ldp neighbor 2.2.2.2 password CISCO
! 対向(R2)でも同様の設定が必要
```

---

### 4. ラベル生成対象の制限 (Loopbackのみ)

**【問題内容】** 
ネットワーク内のラベル肥大化を防ぐため、/32のホストルート（Loopback）に対してのみラベルを生成するように制限せよ。
**【設定例】**
```ios
ip access-list standard ACL_LOOPBACKS
 permit 1.1.1.0 0.0.0.255  ! 例：管理セグメント
!
mpls ldp label
 allocate global prefix-list ACL_LOOPBACKS
```

---

### 5. PHP (Implicit Null) の動作確認

**【問題内容】** 
R4が宛先プレフィックス 4.4.4.4/32 の Egress LSR であるとき、R3 (1つ手前) から R4 へ送られるパケットのラベル状態を確認せよ。
**【検証】**
```ios
R3# show mpls forwarding-table 4.4.4.4
! 期待される出力: Outgoing Label 欄が "Pop Label" になっていることを確認
```

---

### 6. LDP-IGP Synchronization の構成

**【問題内容】** 
OSPF環境において、LDPネイバーが確立されるまで該当リンクをトラフィックパスとして使用しないようにせよ。
**【設定例】**
```ios
router ospf 1
 mpls ldp sync
```

---

### 7. MPLS MTU の調整

**【問題内容】** 
MPLSラベル（4バイト/ラベル）によるオーバーヘッドを考慮し、インターフェイスのMPLS MTUを1508バイトに設定せよ。
**【設定例】**
```ios
interface GigabitEthernet0/1
 mpls mtu 1508
```

---

### 8. LDP セッション保護 (Session Protection)

**【問題内容】** 
直接リンクが一時的にダウンしても、代替パスがある限りLDPセッションを維持し続け、復旧後の収束を早めよ。
**【設定例】**
```ios
mpls ldp session protection
```

---

### 9. MPLS Traceroute によるパス検証

**【問題内容】** 
R1からR5へのLSPが正しく形成されているか、各ホップで使用されているラベル値を含めて確認せよ。
**【操作例】**
```ios
traceroute mpls ipv4 5.5.5.5 255.255.255.255
```

---

### 10. 静的ラベルバインディングの設定

**【問題内容】** 
特定のテスト要件に基づき、プレフィックス 10.10.10.10/32 に対して、入力ラベル 100、出力ラベル 200 を静的に割り当てよ。
**【設定例】**
```ios
mpls static binding ipv4 10.10.10.10 255.255.255.255 input 100 output 10.1.12.2 200
```

---

### 11. 宛先への出力ラベルが存在しない原因の特定

**【問題内容】** 
`show mpls forwarding-table` で `No Label` と表示されている。このプレフィックスがBGPルートである場合、BGPとLDPの連携を確認せよ。
**【解説】**
通常、BGPルート（外部ルート）にはLDPラベルは付与されません。Next-hop（PEのLoopback）へのラベルが存在するかを確認します。

---

### 12. LDP Discovery 失敗の切り分け

**【問題内容】** 
LDPネイバーが検出されない。UDP 646パケットがブロックされていないか、マルチキャスト 224.0.0.2 が届いているか確認せよ。
**【検証】**
```ios
show mpls ldp discovery
! "xmit/recv" カウンタが片方しか増えていない場合、ACLやL2不整合を疑う。
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKCCIE-3000: BGP and Multicast for the CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   MPLS/L3VPN環境下での複雑なルーティング操作のヒントが含まれています。
*   [**BRKSP-2551: Introduction to Segment Routing**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSP-2551)
    *   LDPに代わる次世代MPLS技術の基礎として、従来のMPLS Operationsの理解を深めるのに役立ちます。

### Configuration ガイド
*   [**MPLS Label Distribution Protocol Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_basic/configuration/xe-17/mp-basic-xe-17-book/mp-ldp-config.html)。
*   [**MPLS: Layer 3 VPNs Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/mp_l3_vpns/configuration/xe-17/mp-l3-vpns-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Multiprotocol Label Switching (MPLS) Overview**](https://www.cisco.com/c/en/us/support/docs/multiprotocol-label-switching-mpls/mpls/12492-mpls-faq-12492.html)。
*   [**Verify MPLS on Catalyst 9000 Switches (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-9300-series-switches/217112-verify-mpls-on-catalyst-9000-switches.html)。

---
## 📝 補足
- この学習メモは、MPLSの基本動作からLDPの高度な制御までを網羅しています。CCIE実技試験では、**IGPとLDPの密接な関係**（Router-IDの到達性や同期設定）がトラブルの焦点となることが多いため、`show mpls ldp neighbor` と `show ip route` を往復して論理的な欠落を発見する訓練が重要です。


