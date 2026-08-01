---
layout: default
title: 1.4.c-Network-types-area-types
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

1.4.c OSPF Network Types and Area Types

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.4 OSPF (v2 and v3)」における「1.4.c Network types, area types」について整理しました。

---

## 📘 概要

OSPF（Open Shortest Path First）は、リンクステート型ルーティングプロトコルであり、ネットワークのトポロジを階層的な「エリア」と、物理媒体の特性に応じた「ネットワークタイプ」によって管理します。

**ネットワークタイプ**は、隣接関係の形成、ハロータイマー、およびDR（Designated Router）の選出要否を決定します。イーサネットのようなブロードキャスト媒体から、DMVPNやシリアルリンクのような特殊な環境まで、物理トポロジに最適な動作モードを選択することが、OSPFの安定稼働には不可欠です。

**エリアタイプ**は、ネットワークのスケーラビリティを確保するための機能です。すべてのエリアがバックボーンエリア（Area 0）に接続される階層設計を基本としつつ、特定のエリアに流入するLSA（Link State Advertisement）の種類を制限することで、ルータのメモリ消費とSPF計算の負荷を軽減します。

CCIEレベルでは、これらのタイプがLSAの伝播やパス選定にどのような数学的・論理的影響を与えるかを完全に理解し、制約条件下で最適な設計を実装する能力が求められます。

---

## 🔑 要点

### 1. OSPF ネットワークタイプ (Network Types)

OSPFはインターフェイスの物理媒体を検知してデフォルトのタイプを割り当てますが、手動で変更することが可能です。特にハブ＆スポーク構成や、異なる媒体が混在する環境での不一致は、隣接関係のトラブルの主要因となります。

| ネットワークタイプ | DR/BDR選出 | ネイバー発見 | Hello/Deadタイマー | 備考 |
| :--- | :---: | :---: | :---: | :--- |
| **Broadcast** | あり | マルチキャスト | 10s / 40s | イーサネットのデフォルト。全ルータがDRと同期。 |
| **Point-to-Point** | なし | マルチキャスト | 10s / 40s | シリアル、GREトンネル等のデフォルト。高速。 |
| **Non-Broadcast (NBMA)** | あり | ユニキャスト | 30s / 120s | <code>neighbor</code>コマンドが必須。Frame-Relay等。 |
| **Point-to-Multipoint** | なし | マルチキャスト | 30s / 120s | 複数のホストルートとして学習。ハブ＆スポーク向き。 |
| **P2M Non-Broadcast** | なし | ユニキャスト | 30s / 120s | P2Mの特性に加え、ユニキャストでの指定が必要。 |

### 2. OSPF エリアタイプ (Area Types)

エリアの種類によって、どのLSAタイプが許可され、どのようにデフォルトルートが生成されるかが決まります。

| エリアタイプ | LSA 1, 2 | LSA 3 | LSA 4, 5 | LSA 7 | デフォルトルート (Type 3) |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Standard (Normal)** | 許可 | 許可 | 許可 | 拒否 | 手動での <code>originate</code> が必要。 |
| **Stub** | 許可 | 許可 | **拒否** | 拒否 | ABRが自動で生成・広告。 |
| **Totally Stubby** | 許可 | **拒否** | **拒否** | 拒否 | ABRが自動で生成・広告。 |
| **NSSA** | 許可 | 許可 | **拒否** | 許可 | ABRでオプション設定が必要。 |
| **Totally NSSA** | 許可 | **拒否** | **拒否** | 許可 | ABRが自動で生成・広告。 |

### 3. LSA タイプの役割（復習）

エリア制御を理解するために不可欠なLSAの定義です。
*   **Type 1 (Router LSA):** すべてのルータが生成。自身のリンク情報。
*   **Type 2 (Network LSA):** DRが生成。セグメント内のルータリスト。
*   **Type 3 (Summary LSA):** ABRが生成。別エリアのネットワーク。
*   **Type 4 (ASBR Summary):** ABRが生成。ASBRへのパス情報。
*   **Type 5 (External LSA):** ASBRが生成。OSPF外部のルート。
*   **Type 7 (NSSA External):** NSSA内のASBRが生成。ABRでType 5に変換。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、OSPFの挙動を深く理解していないと解決できない「論理的なパズル」が提示されます。

### 1. ネットワークタイプのミスマッチによる「FULLだが通信不可」

*   **シナリオ:** 片側が <code>Broadcast</code>、もう片側が <code>Point-to-Point</code> に設定されている。
*   **結果:** ハロータイマーが一致していればネイバー状態は <code>FULL</code> になります。しかし、<code>Broadcast</code> 側はLSA Type 2（Network）を期待し、<code>P2P</code> 側は生成しないため、SPF計算の結果、ルーティングテーブルにルートが載りません。
*   **対策:** <code>show ip ospf interface</code> でタイプを確認し、一致させる必要があります。

### 2. NSSA Translator の選出と影響

*   NSSAエリアに複数のABRが存在する場合、Type 7 から Type 5 への変換（Translation）を行うルータが1台選出されます。
*   **ルール:** Router-IDが最も高いABRが Translator となります。
*   **操作:** 特定のルータを Translator に強制したい場合は、<code>area [id] nssa translator-role always</code> コマンドを使用します。

### 3. Forwarding Address (FA) の理解

*   NSSAや外部再配送において、LSA Type 5/7 には「Forwarding Address」がセットされます。
*   **重要:** このFAアドレスへの到達性がルーティングテーブル上に存在しない場合、OSPFはその外部ルートを無視します。ラボでは、このFAアドレスを「OSPF内部ルート」として広報させるか、適切に解決させる設定が問われます。

### 4. LSA Type-3 Filtering の精密制御

*   ABRにおいて、特定のエリア間ルートをフィルタリングするタスク。
*   **コマンド:** <code>area [id] filter-list prefix [NAME] {in|out}</code>。
*   <code>distribute-list</code> と異なり、LSAの伝播そのものをエリア境界で止めるため、より効果的な制御が可能です。

---

## 🛠 設定・検証コマンド

### ネットワークタイプ設定

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスでのタイプ指定** | <code>(config-if)# ip ospf network [broadcast&#124;point-to-point&#124;...]</code> |
| **NBMAネイバーの指定(DR候補側)** | <code>(config-router)# neighbor [IP_ADDRESS]</code> |
| **DR選出の優先度変更** | <code>(config-if)# ip ospf priority</code> |

### エリアタイプ設定

| 目的 | コマンド |
| :--- | :--- |
| **Stubエリアの構成** | <code>(config-router)# area [ID] stub</code> |
| **Totally Stubbyの構成(ABRのみ)** | <code>(config-router)# area [ID] stub no-summary</code> |
| **NSSAエリアの構成** | <code>(config-router)# area [ID] nssa</code> |
| **Totally NSSAの構成(ABRのみ)** | <code>(config-router)# area [ID] nssa no-summary</code> |
| **NSSAでのデフォルトルート強制** | <code>(config-router)# area [ID] nssa default-information-originate</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **ネットワークタイプの確認** | <code>show ip ospf interface [ID]</code> |
| **LSAの種類とデータベース確認** | <code>show ip ospf database</code> |
| **特定のLSA詳細(FAアドレス等)** | <code>show ip ospf database [external&#124;nssa-external] [prefix]</code> |
| **ABR/ASBRの役割確認** | <code>show ip ospf</code> |
| **OSPFv3でのエリア確認** | <code>show ospfv3 database</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIEレベルの複雑なトポロジを想定した12の実装例です。

### 1. Broadcast と P2P の混在環境における正規化

**【問題内容】**
R1（イーサネット）とR2（GREトンネル）の間でOSPFを動作させている。ハロータイマーをデフォルトのまま、両端でDR選出を無効化し、SPF計算を正しく行わせよ。

**【設定サンプル】**
```ios
! R1 側 (Ethernet 0/1)
interface GigabitEthernet0/1
 ip ospf network point-to-point  ! デフォルトのBroadcastから変更

! R2 側 (Tunnel 0)
interface Tunnel0
 ip ospf network point-to-point  ! トンネルは元々P2Pだが明示的に指定
```

---

### 2. NBMA 環境での静的ネイバーとDR制御

**【問題内容】**
マルチキャストがサポートされないネットワークにおいて、R1 をハブ（DR）として構成し、R2, R3 と隣接関係を確立せよ。

**【設定サンプル】**
```ios
! R1 (Hub)
router ospf 1
 neighbor 10.1.1.2
 neighbor 10.1.1.3
interface GigabitEthernet0/1
 ip ospf network non-broadcast
 ip ospf priority 255  ! DRを確実に取得

! R2 (Spoke)
interface GigabitEthernet0/1
 ip ospf network non-broadcast
 ip ospf priority 0    ! DR選出を辞退
```

---

### 3. Totally Stubby Area によるLSA Type-3の抑制

**【問題内容】**
Area 10 に所属する R4, R5 のルーティングテーブルから、他のエリアのルート（O IA）を削除し、ABR（R1）からのデフォルトルートのみで通信させよ。

**【設定サンプル】**
```ios
! ABR (R1) 側
router ospf 1
 area 10 stub no-summary  ! no-summary が Totally Stubby の鍵

! Area 10 内部ルータ (R4, R5)
router ospf 1
 area 10 stub             ! 内部ルータは stub だけでよい
```

---

### 4. Totally NSSA における外部ルート再配送とデフォルトルート

**【問題内容】**
Area 35 は Totally NSSA である。ASBRである R5 で学習した EIGRP ルートを OSPF に再配送しつつ、ABR（R3）から Area 35 内にデフォルトルートを自動広告せよ。

**【設定サンプル】**
```ios
! ABR (R3) 側
router ospf 1
 area 35 nssa no-summary  ! Totally NSSA設定。デフォルトルートが自動生成される

! ASBR (R5) 側
router ospf 1
 area 35 nssa
 redistribute eigrp 100 subnets
```

---

### 5. NSSA Translator の明示的選出

**【問題内容】**
Area 20 に ABR が2台（R1, R2）存在する。Router-IDが低い方の R1 を常に Type-7 to Type-5 の変換担当（Translator）に固定せよ。

**【設定サンプル】**
```ios
! R1 側
router ospf 1
 area 20 nssa translator-role always
```

---

### 6. LSA Type-3 Filtering によるエリア間ルートの遮断

**【問題内容】**
ABR（R5）において、Area 0 のデバイスが R8-R10 間のネットワーク（155.1.108.0/24）を学習しないようにせよ。他のエリアの追加には影響を与えないこと。

**【設定サンプル】**
```ios
ip prefix-list FILTER_VLAN108 deny 155.1.108.0/24
ip prefix-list FILTER_VLAN108 permit 0.0.0.0/0 le 32

router ospf 1
 ! Area 0に向かうLSA Type-3をフィルタリング
 area 0 filter-list prefix FILTER_VLAN108 in
```

---

### 7. Area Range による外部ルートの集約

**【問題内容】**
ASBR（R1）で再配送された 172.16.1.0/24 〜 172.16.3.0/24 を、OSPFドメイン全体には 172.16.0.0/22 として1つのルートで広報せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! 外部ルートの集約は summary-address コマンドを使用
 summary-address 172.16.0.0 255.255.252.0
 redistribute connected subnets
```

---

### 8. P2M Non-Broadcast におけるホストルートの検証

**【問題内容】**
Point-to-Multipoint ネットワークを構成せよ。このとき、対向インターフェイスのIPアドレスが /32 のホストルートとして学習されることを確認せよ。

**【設定サンプル】**
```ios
interface Tunnel0
 ip ospf network point-to-multipoint
 ! 検証：show ip route ospf で対向の /32 ルートを確認
```

---

### 9. OSPFv3 Address Family での Area Type 設定

**【問題内容】**
OSPFv3 AFモードを使用し、IPv6ユニキャストにおいて Area 11 を Stub エリアとして構成せよ。

**【設定サンプル】**
```ios
router ospfv3 1
 address-family ipv6 unicast
  area 11 stub
 exit-address-family

interface GigabitEthernet0/1
 ospfv3 1 ipv6 area 11
```

---

### 10. Forwarding Address (FA) の強制解決 (Loopback)

**【問題内容】**
NSSAから外部への再配送において、FAアドレスがASBRのLoopbackにセットされている。このLoopbackがOSPFドメイン全体で「内部ルート」として認識されるよう、ネットワークコマンドで広報せよ。

**【設定サンプル】**
```ios
! ASBR 側
router ospf 1
 network 1.1.1.1 0.0.0.0 area 1   ! FAを内部ルート化して解決を保証
 redistribute static subnets
```

---

### 11. Prefix Suppression によるLSDBの最適化

**【問題内容】**
ネットワーク全体のLSAサイズを削減するため、トランジットリンク（ルータ間接続）のIPプレフィックス情報をLSAから除外せよ。

**【設定サンプル】**
```ios
router ospf 1
 prefix-suppression
```

---

### 12. GTSM (Generic TTL Security Mechanism) の有効化

**【問題内容】**
直接接続されたOSPFネイバーへの攻撃を防ぐため、OSPFパケットのTTLをチェックする機能を有効化せよ。

**【設定サンプル】**
```ios
router ospf 1
 ttl-security all-interfaces hops 1
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKRST-2337: OSPF Deployment in Modern Networks (OSPFv2/v3深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)
*   [BRKRST-3320: Troubleshooting Routing Protocols (OSPFの不整合トラブル等)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### Configurationガイド
*   [OSPFv2 Configuration Guide - Area Types (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html)
*   [OSPFv3 Address Family Support Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html)

### テクニカルドキュメント・設定例
*   [Understanding OSPF Network Types (Cisco Support)](https://www.cisco.com/c/ja_jp/support/docs/ip/open-shortest-path-first-ospf/13697-14.html)
*   [How OSPF Injects a Default Route into a Stub or NSSA (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/47870-ospfdb11.html)

---

## 📝 補足
- この学習メモは、OSPFの「ネットワークタイプ」によるパケット動作と、「エリアタイプ」によるデータベース制御の相関関係を網羅しています。CCIEラボ試験では、特に NSSA における Translator の動作や FA アドレスの到達性、そしてネットワークタイプの不一致を突くトラブルシューティングが合否を分けるポイントとなります。

