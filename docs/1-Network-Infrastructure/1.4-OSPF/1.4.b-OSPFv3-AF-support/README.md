---
layout: default
title: 1.4.b-OSPFv3-AF-support
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

#1.4.b OSPFv3 address family support

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.4 OSPF (v2 and v3)」における「1.4.b OSPFv3 address family support」について整理しました。

---

## 📘 概要

**OSPFv3 Address Family (AF) Support**は、当初IPv6専用として設計されたOSPFv3（RFC 2740）を拡張し、単一のプロトコルプロセス内でIPv4とIPv6の両方のルーティング情報を伝送可能にする技術です（RFC 5838）。従来のOSPFv2はIPv4専用であり、IPv6を導入する際はOSPFv3を別途稼働させる「シップス・イン・ザ・ナイト（Ships in the night）」モデルが一般的でしたが、AFサポートにより、管理の統合とコントロールプレーンの効率化が実現しました。

CCIE EIレベルの実装では、インターフェイス上でIPv4アドレスが設定されていない状態でもIPv4のルーティングを可能にする高度な構成や、インスタンスIDを用いたAFの分離、さらにはVRF（Virtual Routing and Forwarding）環境でのマルチアドレスファミリー構成を完全に制御する能力が問われます。

---

## 🔑 要点

### 1. マルチプロトコル対応のメカニズム

OSPFv3 AFモードでは、同一リンク上で複数の「インスタンス」を走らせることでプロトコルを分離します。
*   **Instance ID:** IPv4 Unicast AFには通常 `64` 以降、IPv6 Unicast AFには `0` などのIDが割り当てられ、パケットヘッダー内で識別されます。
*   **統一されたコンフィギュレーション:** `router ospfv3 [ID]` コマンド配下で `address-family ipv4 unicast` や `address-family ipv6 unicast` を定義する階層構造をとります。

### 2. IPv6 リンクローカルアドレスへの依存

OSPFv3 AFの最も重要な特徴は、**IPv4ルーティングを行う場合でも、次ホップの解決や隣接関係の維持にIPv6リンクローカルアドレス（FE80::/10）を使用する**点です。
*   インターフェイスにIPv4アドレスが設定されていなくても、IPv6が有効（`ipv6 enable`）であればIPv4 AFの隣接関係を確立できます。
*   これにより、物理リンクのIPv4枯渇問題を回避しつつ、IPv4トラフィックを中継することが可能になります。

### 3. Router-ID の必須性

OSPFv3は32ビットのRouter-IDを使用して自身を識別します。
*   IPv4アドレスがルータに一つも存在しない環境では、Router-IDが自動生成されず、OSPFv3プロセス自体が起動しません。
*   CCIEラボでは、`router-id 0.0.0.x` のように手動で固定設定することが必須タスクとして含まれることが多くあります。

### 4. LSA（Link State Advertisement）の変更点

OSPFv3では、IPプレフィックス情報がハローパケットやネットワークLSAから切り離され、新しいLSAタイプに格納されます。
*   **LSA Type 8 (Link LSA):** リンクローカルアドレスとリンク上のプレフィックス情報を伝えます。
*   **LSA Type 9 (Intra-Area-Prefix LSA):** エリア内のプレフィックス情報を伝達します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、OSPFv3 AFに関連して「設計上の意図」を問う複雑なタスクが出題されます。

### 1. IPv4 over IPv6-only Link のトラブルシュート

「インターフェイスにIPv4アドレスを設定せずに、IPv4プレフィックスをR1からR2へ到達させよ」という要件。
*   **解決策:** `router ospfv3` で `address-family ipv4 unicast` を有効化し、インターフェイス側でも `ospfv3 [PID] ipv4 area [ID]` を設定します。IPv6のリンクローカルアドレスがピアリングに使用されることを確認する必要があります。

### 2. VRF-Aware OSPFv3 の構成

SD-WANやエンタープライズのセグメンテーション要件において、特定のVRF内でOSPFv3 AFを動作させるスキルが求められます。
*   `address-family ipv6 unicast vrf [NAME]` のように、AF配下でVRFを紐付ける必要があります。

### 3. 下位互換性（Traditional v3 vs. AF Mode）

OSPFv3には「インターフェイス・ベース（旧）」と「アドレスファミリー・ベース（新）」の2つの設定スタイルがあります。
*   ラボで「Use the newest configuration style（最新のスタイルを使用せよ）」や「Support both IPv4/IPv6 under a single process（単一プロセスで両方をサポートせよ）」と指示された場合は、必ずAFモードを使用します。

### 4. 再配送と集約の制御

OSPFv3 AFにおける再配送（Redistribution）は、各AFのサブモード内で行います。
*   IPv4ルートをOSPFv3経由で広告する際、メトリックやタグ付けによるループ防止策（Blueprint 1.2.h 関連）が同時に問われることがあります。

---

## 🛠 設定・検証コマンド

### 設定コマンド (AF Mode)

| 目的 | コマンド |
| :--- | :--- |
| **OSPFv3プロセス起動** | <code>router ospfv3 [PID]</code> |
| **Router-ID設定(必須)** | <code>(config-router)# router-id [A.B.C.D]</code> |
| **IPv4 AFの有効化** | <code>(config-router)# address-family ipv4 unicast</code> |
| **IPv6 AFの有効化** | <code>(config-router)# address-family ipv6 unicast</code> |
| **インターフェイスでのAF適用** | <code>(config-if)# ospfv3 [PID] [ipv4&#124;ipv6] area [AID]</code> |
| **VRF内でのOSPFv3 AF** | <code>(config-router)# address-family [ipv4&#124;ipv6] vrf [NAME]</code> |

### 検証・デバッグコマンド

| 目的 | コマンド |
| :--- | :--- |
| **AF別のネイバー確認** | <code>show ospfv3 neighbor</code> |
| **AF別のLSDB表示** | <code>show ospfv3 database</code> |
| **インターフェイスのAF構成確認** | <code>show ospfv3 interface</code> |
| **IPv4 AFのルート確認** | <code>show ip route ospfv3</code> |
| **IPv6 AFのルート確認** | <code>show ipv6 route ospfv3</code> |
| **OSPFv3パケットの追跡** | <code>debug ospfv3 packages</code> |

---

## 🛠 ラボ学習・設定サンプル例

ソース Workbook および CCIE レベルの複雑な構成要件に基づいた 12 個の実装例を提示します。

### 1. IPv4 および IPv6 のデュアルスタック AF 構成

**【問題内容】**
R1 と R2 の間で OSPFv3 を使用し、IPv4 と IPv6 両方のプレフィックスを交換せよ。Router-ID は手動で設定し、最新のアドレスファミリー形式を使用すること。

**【設定サンプル】**
```ios
router ospfv3 1
 router-id 1.1.1.1
 address-family ipv4 unicast
 exit-address-family
 address-family ipv6 unicast
 exit-address-family

interface GigabitEthernet0/1
 ospfv3 1 ipv4 area 0
 ospfv3 1 ipv6 area 0
```

---

### 2. IPv4 over IPv6 リンク (IPv4アドレス無しでの隣接関係)

**【問題内容】**
物理リンクに IPv4 アドレスを設定せずに、OSPFv3 IPv4 AF を用いて R1 から R2 へ IPv4 ルートを広報せよ。

**【設定サンプル】**
```ios
! R1 側
interface GigabitEthernet0/1
 ipv6 enable  ! リンクローカルを有効化
 ospfv3 1 ipv4 area 0

router ospfv3 1
 address-family ipv4 unicast
```
*   **検証:** `show ospfv3 neighbor` で隣接関係が IPv6 アドレスを介して確立されていることを確認します。

---

### 3. VRF インスタンスを用いた OSPFv3 AF

**【問題内容】**
VRF 'TENANT_A' において OSPFv3 IPv6 ルーティングを構成せよ。

**【設定サンプル】**
```ios
router ospfv3 10
 router-id 10.10.10.10
 address-family ipv6 unicast vrf TENANT_A
  redistribute connected
 exit-address-family

interface GigabitEthernet0/1.100
 vrf forwarding TENANT_A
 ospfv3 10 ipv6 area 0
```

---

### 4. OSPFv3 AF における内部ルートの集約

**【問題内容】**
ABR である R3 において、Area 1 内の IPv6 プレフィックス `2001:DB8:1::/64` 〜 `2001:DB8:3::/64` を `2001:DB8::/62` に集約して Area 0 へ広告せよ。

**【設定サンプル】**
```ios
router ospfv3 1
 address-family ipv6 unicast
  area 1 range 2001:DB8::/62
```

---

### 5. IPv4 AF 配下での EIGRP ルート再配送

**【問題内容】**
EIGRP AS 100 で学習した IPv4 ルートを OSPFv3 IPv4 AF へ再配送せよ。

**【設定サンプル】**
```ios
router ospfv3 1
 address-family ipv4 unicast
  redistribute eigrp 100 subnets
```

---

### 6. OSPFv3 AF における仮想リンク (Virtual-Link)

**【問題内容】**
Area 1 をトランジットエリアとして、Area 2 を Area 0 に接続する仮想リンクを AF モードで構成せよ。Router-ID 2.2.2.2 と 3.3.3.3 の間で行うこと。

**【設定サンプル】**
```ios
! R3 (ABR) 側
router ospfv3 1
 address-family ipv6 unicast
  area 1 virtual-link 2.2.2.2
```

---

### 7. Trailer-based Authentication (SHA-256) の適用

**【問題内容】**
IPv6 AF において、IPsec を使用せずに HMAC-SHA-256 による認証を構成せよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ospfv3 1 ipv6 authentication hmac-sha-256 key-id 10 0 SECRET_PASS
```

---

### 8. LSA Type 3 (Inter-Area) フィルタリング

**【問題内容】**
R5 において、Area 0 から Area 3 へ特定の IPv4 プレフィックス `10.100.1.0/24` が伝播するのを ABR で阻止せよ。

**【設定サンプル】**
```ios
ip prefix-list BLOCK_PFX deny 10.100.1.0/24
ip prefix-list BLOCK_PFX permit 0.0.0.0/0 le 32

router ospfv3 1
 address-family ipv4 unicast
  area 3 filter-list prefix BLOCK_PFX in
```

---

### 9. OSPFv3 IPv4 AF でのメトリック操作 (Traffic Engineering)

**【問題内容】**
特定のインターフェイス経由で学習する IPv4 ルートのコストを `1000` に固定せよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/2
 ospfv3 1 ipv4 cost 1000
```

---

### 10. IPv6 Unicast 以外の AF (Multicast) サポートの準備

**【問題内容】**
マルチキャストルーティングのためのトポロジ情報を交換するため、IPv6 Multicast AF を有効化せよ。

**【設定サンプル】**
```ios
router ospfv3 1
 address-family ipv6 multicast
  exit-address-family

interface GigabitEthernet0/1
 ospfv3 1 ipv6 multicast area 0
```

---

### 11. インターフェイス・デフォルトの継承

**【問題内容】**
`af-interface default` の概念（EIGRPに類似）を OSPFv3 で模倣し、全インターフェイスをデフォルトでパッシブにし、一つだけ解除せよ。

**【設定サンプル】**
```ios
router ospfv3 1
 address-family ipv6 unicast
  passive-interface default
  no passive-interface GigabitEthernet0/1
```

---

### 12. プレフィックス抑制 (Prefix Suppression)

**【問題内容】**
リンク状態データベースのサイズを最小化するため、 transit リンクのプレフィックス情報を LSA から除外（抑制）せよ。

**【設定サンプル】**
```ios
router ospfv3 1
 address-family ipv6 unicast
  prefix-suppression
```

---

## 参考リソースリンク

### Configurationガイド
*   [OSPFv3 Address Family Support Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book/ip6-route-ospfv3.html)。
*   [Configuring VRF-lite with OSPFv3](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/15-mt/iro-15-mt-book/ip6-route-ospfv3-vrf.html)。

### CiscoLive (動画・スライド)
*   [DGTL-BRKRST-2337: OSPF Deployment in Modern Networks (IPv4 AF 深掘り)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)。
*   [BRKRST-3320: Troubleshooting Routing Protocols (OSPFv3 隣接関係のトラブル)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)。

### テクニカルドキュメント・設定例
*   [IPv6 Routing OSPFv3 (Cisco Support Document)](https://www.cisco.com/c/en/us/support/docs/ip/ip-version-6-ipv6/113328-ipv6-static-00.html)。
*   [Implementing OSPFv3 with Multiple Address Families](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3-af.html)。

---


## 📝 補足
- この学習メモは、OSPFv3 AF supportが「単なるIPv6のプロトコル」ではなく、「次世代の統合ルーティング基盤」であることを強調しています。特にIPv6リンクローカルアドレスに依存したIPv4隣接関係の形成は、CCIEラボ試験において非常に誤解しやすく、かつ強力なトラブルシューティングのポイントとなるため、実機（EVE-NG等）での徹底した確認が推奨されます。

