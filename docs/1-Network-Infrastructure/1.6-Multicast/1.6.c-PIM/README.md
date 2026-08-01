---
layout: default
title: 1.6.c-PIM
parent: 1.6-Multicast
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.6.c PIM (Protocol Independent Multicast)

CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目 「1.6 Multicast」における「1.6.c PIM」およびそのサブトピックについて、ラボ試験合格に必要な技術詳細と詳細な実装シナリオを整理しました。

---

## 📘 概要

**PIM (Protocol Independent Multicast)** は、マルチキャストパケットを転送するための配信ツリーを構築するルーティングプロトコルです。「独自（Independent）」という名称の通り、特定のユニキャストルーティングプロトコル（OSPF, EIGRP, BGP等）に依存せず、既存のユニキャストルーティングテーブル（RIB）を利用して **RPF (Reverse Path Forwarding) チェック** を行い、ループのないツリーを形成します。

CCIE EI レベルでは、単に隣接関係を張るだけでなく、**ランデブーポイント (RP)** の動的選出メカニズム（Auto-RP, BSR）の制御、**SSM (Source Specific Multicast)** による効率化、**Anycast RP** を用いた冗長化、および **Multicast Multipath** による負荷分散といった、大規模かつ堅牢なマルチキャスト基盤の構築能力が問われます。

---

## 🔑 要点

### 1. PIM Sparse Mode (i)

*   **動作原理:** 「明示的なリクエスト（Join）」があった場合にのみトラフィックを転送するモデルです。
*   **ツリーの種類:**
    *   **Shared Tree (*,G):** レシーバから RP までのツリー。
    *   **Source Tree (S,G):** 送信元（Source）からレシーバ（または RP）までの最短パスツリー (SPT)。
*   **SPT Switchover:** デフォルトでは、最初のパケットを受信した直後にルータは Shared Tree から Source Tree (SPT) へ切り替えを試み、パスを最適化します。

### 2. RP 選出メカニズム (ii)

*   **Static RP:** 手動で RP アドレスを指定。全ルータで設定を統一する必要があります。
*   **Auto-RP (Cisco Proprietary):** 224.0.1.39 (Announce) と 224.0.1.40 (Discovery) を使用して、**Candidate RP (C-RP)** と **Mapping Agent (MA)** が自動調整します。
*   **BSR (Bootstrap Router):** 標準プロトコル。PIM メッセージ（ホップバイホップ）を使用して RP 情報を配布するため、PIM 疎通があれば動作します。

### 3. Source Specific Multicast (SSM) (iv)

*   **概要:** レシーバがグループ (G) だけでなく送信元 (S) も指定して参加する方式です。
*   **メリット:** RP が不要になり、(S,G) ツリーのみを使用するため、アドレスの重複問題（L2 MAC重複）や共有ツリーの複雑さが解消されます。
*   **範囲:** デフォルトの SSM 範囲は **232.0.0.0/8** です。

### 4. Anycast RP (vi, vii)

*   **目的:** RP の冗長化と負荷分散（レシーバに近い RP を選択）。
*   **IPv4 (MSDP):** 複数の RP に同一 IP を設定し、**MSDP (Multicast Source Discovery Protocol)** ピアリングを張って Source 情報を共有します。
*   **IPv6 (PIMv6 Anycast RP):** MSDP を使用せず、PIM の Anycast-RP セット設定のみでソース情報を共有します。

### 5. Multicast Multipath (viii)

*   通常、マルチキャストは単一のパス（RPF インターフェイス）のみを使用しますが、`ip multicast multipath` コマンドにより、ユニキャストの等コストパス (ECMP) を利用した負荷分散が可能になります。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、論理的な不整合を突く問題や、高度なフィルタリング要件が出題されます。

### 1. RPF チェックと非対称ルーティングの解決

ユニキャストのパスが A 経由、マルチキャストが B 経由で届く場合、PIM はパケットを破棄します。
*   **対策:** `ip mroute` で静的に RPF を向けるか、MBGP (Multiprotocol BGP) でマルチキャスト専用のトポロジを定義する必要があります。

### 2. Auto-RP と Sparse-Mode の「鶏と卵」問題

Auto-RP の制御パケット自体がマルチキャストであるため、Sparse-Mode では RP が決まるまで RP 情報を送れない矛盾が生じます。
*   **対策:** `ip pim sparse-dense-mode` を使用するか、`ip pim autorp listener` を設定して、224.0.1.39/40 だけを Dense Mode のようにフラッディングさせる必要があります。

### 3. BSR 伝播の制限

「特定のエリアに RP 情報を伝播させてはならない」という要件に対し、インターフェイスで `ip pim bsr-border` を設定し、BSR メッセージをブロックする手法が問われます。

### 4. Multicast Boundary の精密制御

`ip multicast boundary` コマンドを使用して、特定のグループのトラフィックや Auto-RP/BSR パケットの境界を定義します。これはトラフィックエンジニアリングとセキュリティの両面で重要です。

---

## 🛠 設定・検証コマンド

### PIM 基本・RP 設定

| 目的 | コマンド |
| :--- | :--- |
| **マルチキャストルーティング有効化(必須)** | <code>(config)# ip multicast-routing [vrf NAME]</code> |
| **PIM 有効化(インターフェイス)** | <code>(config-if)# ip pim sparse-mode</code> |
| **静的 RP の設定** | <code>(config)# ip pim rp-address [IP] [ACL] [override]</code> |
| **Auto-RP Candidate RP 指定** | <code>(config)# ip pim send-rp-announce [INT] scope [TTL] group-list [ACL]</code> |
| **Auto-RP Mapping Agent 指定** | <code>(config)# ip pim send-rp-discovery [INT] scope [TTL]</code> |
| **BSR Candidate RP 指定** | <code>(config)# ip pim rp-candidate [INT] [group-list ACL] [priority VAL]</code> |
| **BSR Bootstrap Router 指定** | <code>(config)# ip pim bsr-candidate [INT] [hash-mask-len] [priority VAL]</code> |

### SSM・フィルタ・負荷分散

| 目的 | コマンド |
| :--- | :--- |
| **SSM 範囲の定義** | <code>(config)# ip pim ssm {default &#124; range ACL}</code> |
| **マルチキャスト境界の作成** | <code>(config-if)# ip multicast boundary [ACL] [filter-autorp]</code> |
| **RP 広告のフィルタリング** | <code>(config)# ip pim rp-announce-filter rp-list [ACL] group-list [ACL]</code> |
| **マルチキャスト ECMP 有効化** | <code>(config)# ip multicast multipath</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **PIM ネイバーの確認** | <code>show ip pim neighbor</code> |
| **現在の RP マッピング確認** | <code>show ip pim rp mapping [detail]</code> |
| **マルチキャスト転送テーブル(mroute)** | <code>show ip mroute [group]</code> |
| **RPF チェックの確認** | <code>show ip rpf [Source_IP]</code> |
| **MSDP ピアリング確認** | <code>show ip msdp summary</code> |
| **PIMv6 状態確認** | <code>show ipv6 mroute</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な PIM-SM 隣接関係と Static RP

**【問題】**
R1, R2, R3 で Sparse Mode を有効化し、R3 (1.3.1.1) を静的な RP として設定せよ。

**【設定】**
```ios
! 全ルータ共通
ip multicast-routing
interface GigabitEthernet0/1
 ip pim sparse-mode
ip pim rp-address 1.3.1.1
```

---

### 2. Auto-RP による動的 RP 選出 (MA/C-RP)

**【問題】**
R8 を C-RP、R6 を Mapping Agent とし、Auto-RP を用いて RP 情報を配布せよ。Sparse-Mode のみの環境でも動作するようにせよ。

**【設定】**
```ios
! R8 (C-RP)
ip pim send-rp-announce Loopback0 scope 16
ip pim autorp listener  ! Sparse-modeで39/40を通すための設定

! R6 (MA)
ip pim send-rp-discovery Loopback0 scope 16
ip pim autorp listener
```

---

### 3. BSR による標準ベースの RP 選出

**【問題】**
PIM-SM 環境において、BSR プロトコルを使用して R3 を RP、R1 を BSR として選出せよ。

**【設定】**
```ios
! R3 (C-RP)
ip pim rp-candidate Loopback0

! R1 (BSR)
ip pim bsr-candidate Loopback0 24 100
```

---

### 4. RP Announcement Filter による不正 RP 排除

**【問題】**
R7 (10.1.7.7) 以外のルータが RP として名乗り出ることを防止せよ。

**【設定】**
```ios
ip access-list standard ACL_R7_ONLY
 permit 10.1.7.7
!
ip pim rp-announce-filter rp-list ACL_R7_ONLY
```

---

### 5. Multicast Boundary によるドメイン分離

**【問題】**
インターフェイス GigabitEthernet0/2 において、マルチキャストトラフィックの流入を 239.0.0.0/8 のプライベート範囲のみに制限せよ。

**【設定】**
```ios
ip access-list standard ACL_MCAST_SCOPE
 permit 239.0.0.0 0.255.255.255
!
interface GigabitEthernet0/2
 ip multicast boundary ACL_MCAST_SCOPE
```

---

### 6. SSM (Source Specific Multicast) の有効化

**【問題】**
デフォルトの SSM 範囲 (232.0.0.0/8) を使用して SSM ルーティングを構成せよ。レシーバ側では IGMPv3 を使用すること。

**【設定】**
```ios
! ルータ側
ip pim ssm default

! レシーバ側インターフェイス
interface GigabitEthernet0/1
 ip igmp version 3
```

---

### 7. IPv4 Anycast RP using MSDP

**【問題】**
R1 と R2 の両方を Anycast RP (10.1.100.1) とし、MSDP を使用して送信元情報を同期させよ。

**【設定】**
```ios
! R1
interface Loopback100
 ip address 10.1.100.1 255.255.255.255
 ip pim sparse-mode
!
ip msdp peer 10.1.1.2 connect-source Loopback0
ip msdp originator-id Loopback0
```

---

### 8. PIMv6 Anycast RP (IPv6)

**【問題】**
IPv6 マルチキャスト環境において、2001:DB8::RP を Anycast RP アドレスとして R1, R2 に構成せよ。

**【設定】**
```ios
! R1 & R2 共通
ipv6 pim anycast-rp 2001:DB8::RP 2001:DB8::1  ! 自身の物理/Loアドレスを2つ目に指定
```

---

### 9. Multicast ECMP (Multipath) による負荷分散

**【問題】**
ユニキャストパスが 2 つある場合、マルチキャストトラフィックを両方のパスを利用して RPF チェックを通過させ、負荷分散せよ。

**【設定】**
```ios
ip multicast multipath
```

---

### 10. BSR Border による RP 情報の遮断

**【問題】**
特定のルータ R6 が BSR からの RP 情報を受信しないように境界を設定せよ。

**【設定】**
```ios
interface GigabitEthernet0/1
 ip pim bsr-border
```

---

### 11. IGMP Join-Group による擬似レシーバ構成

**【問題】**
ルータのインターフェイス自体を特定のグループ (225.225.225.225) のレシーバとして機能させ、疎通確認に使用せよ。

**【設定】**
```ios
interface GigabitEthernet0/1
 ip igmp join-group 225.225.225.225
```

---

### 12. Bidirectional PIM の構成

**【問題】**
多数の送信元とレシーバが存在する多対多通信のため、双方向 (Bidirectional) PIM をグループ 224.22.22.22 用に構成せよ。

**【設定】**
```ios
ip pim bidir-enable
ip pim rp-address 1.1.1.1 bidir
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKIPM-2264: IP Multicast Logic and Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKIPM-2264)
    *   PIM のステートマシンや RPF エラーの深いトラブルシューティング解説。
*   [**BRKCCIE-3000: BGP and Multicast for CCIE Candidates**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
    *   CCIE ラボ試験におけるマルチキャストの「定番」タスクの解説。

### Configuration ガイド
*   [IP Multicast: PIM Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_pim/configuration/xe-17/imc-pim-xe-17-book.html)
*   [Implementing IPv6 Multicast (PIMv6)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipmulti_ipv6/configuration/xe-16/imc-ipv6-multicast-xe-16-book.html)。

### テクニカルノーツ・設定例
*   [PIM Sparse Mode SPT Switchover Mechanism](https://www.cisco.com/c/en/us/support/docs/ip/multicast/13717-49.html)。
*   [Anycast RP Using MSDP Configuration Example](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/116019-config-ospf-00.html)。

---

## 📝 補足

- この学習メモは、PIM の制御プレーン（RP 選出）からデータ転送（SPT Switchover, SSM）までの論理的な繋がりを重視しています。CCIE 実技試験においては、特に **RP 情報の不一致** や **RPF の失敗** が原因でトラフィックが止まるシナリオが多いため、`show ip pim rp mapping` と `show ip rpf` を駆使した迅速な診断が合格の決め手となります。
