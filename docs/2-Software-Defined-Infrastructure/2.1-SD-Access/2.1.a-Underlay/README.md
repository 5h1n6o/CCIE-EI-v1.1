---
layout: default
title: 2.1.a-Underlay
parent: 2.1-SD-Access
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.1.a Cisco SD-Access Underlay

Cisco SD-Access（Software-Defined Access）は、キャンパスネットワークの展開と管理を簡素化・自動化し、セグメント化と一貫したポリシー適用を実現するアーキテクチャです。その土台となる **Underlay（アンダーレイ）** は、オーバーレイ（LISP/VXLAN）が正常に機能するための「物理的な到達性」を提供する極めて重要な層です。

---

## 📘 概要

**SD-Access Underlay** とは、ファブリック内のすべてのデバイス（Control Plane Node, Border Node, Edge Node）間のIP接続を提供するレイヤ3ルーティングネットワークを指します。アンダーレイの唯一の目的は、各ノードの **Loopbackアドレス間での通信** を保証することです。

SD-Accessにおいてアンダーレイを構築する手法は主に2つあります。
1.  **Manual（手動設定）:** 既存のネットワーク資産を活用したり、特定のルーティングプロトコル要件（OSPF, EIGRP等）がある場合に、管理者が手動でIPアドレスやプロトコルを設定します。
2.  **LAN Automation（自動化）:** Cisco DNA Center（DNAC）のPnP（Plug and Play）機能を利用し、シードデバイス（Seed Device）から下位のスイッチを自動的に検出し、IS-ISルーティングを自動構成します。

CCIEレベルでは、単に接続するだけでなく、VXLANカプセル化によるオーバーヘッドを考慮した **MTUの調整**、LISP/VXLANの制御パケットを通すための **ルーティングの最適化**、そして **Extended Nodes** を用いた非ファブリックデバイスの収容といった高度な設計・実装能力が求められます。

---

## 🔑 要点

### 1. Manual Underlay (i)

手動構成のアンダーレイでは、管理者がすべてのリンクにIPを割り当て、IGP（主にIS-IS、OSPF、またはEIGRP）を構成します。
*   **ルーティング要件:** すべてのファブリックノード（Edge, Border, Control Plane）のLoopback 0（RLOC用）への到達性が必要です。
*   **MTUの設定:** VXLANカプセル化により、パケットに50バイトのオーバーヘッドが付加されます。フラグメンテーションを防ぐため、アンダーレイのMTUを **9100バイト以上（ジャンボフレーム）** に設定することが推奨されます。
*   **プロトコルの選択:** DNACの自動化ではIS-ISが標準ですが、手動構成ではOSPFなども許可されます。

### 2. LAN Automation / PnP (ii)

DNACを使用して、ゼロタッチでアンダーレイを構築するプロセスです。
*   **Seed Device（シードデバイス）:** すでにDNACで管理されているルータ/スイッチで、新しいデバイスへのゲートウェイおよびDHCPサーバとして機能します。
*   **PnPプロセス:** 未設定のスイッチ（空箱状態）が起動すると、VLAN 1でCDP隣接関係を探し、シードデバイスからDHCPでIPを取得してDNACにチェックインします。
*   **自動構成内容:** DNACは新しいスイッチに対し、Loopback 0の割り当て、IPプロトコル（IS-IS）の構成、およびグローバル設定のプッシュを行います。

### 3. Device Discovery and Management (iii)

DNACがファブリック外、または既存のデバイスをインベントリに取り込むプロセスです。
*   **Discovery:** CDP、LLDP、または特定のIPアドレス範囲のスキャンによって行われます。
*   **Management:** DNACは **SNMP** (v2c/v3) で情報を収集し、**SSH** で設定を投入、**HTTPS/RESTCONF/NETCONF** で高度なテレメトリ管理を行います。
*   **Credentials:** デバイスを管理するためには、DNACに共通のCLIパスワード、SNMPコミュニティ、Enableパスワードを登録しておく必要があります。

### 4. Extended Nodes / Policy Extended Nodes (iv)

ファブリックを、SD-Accessをネイティブサポートしないスイッチ（IEスイッチや古いCat3k/4k等）に拡張する機能です。
*   **Extended Node:** ファブリックエッジに接続されたL2スイッチとして動作します。DNACにより自動構成され、特定のVLANをファブリックに橋渡ししますが、自身でVXLAN処理は行いません。
*   **Policy Extended Node (PEN):** インラインタグ付け（SGT: Scalable Group Tag）をサポートし、エッジポートレベルでマイクロセグメンテーション（SGACL）を適用できる拡張ノードです。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験において、SD-Accessのアンダーレイは「オーバーレイが動作しない原因」の温床として出題されます。

### 1. MTU 不一致のトラブルシューティング

*   **症状:** アンダーレイでのping（スモールパケット）は通るが、LISPやVXLANを通すと通信が途切れる、または極端に遅くなる。
*   **対策:** インターフェイスおよびシステムMTUが適切（9100推奨）であることを確認します。ラボでは `system mtu 9100` の設定が欠落しているシナリオが想定されます。

### 2. IS-IS ネイバーシップの要件

LAN Automationを使用する場合、IS-ISがアンダーレイの標準です。
*   **罠:** `ip routing` が有効になっていない、あるいはMTUサイズがL1/L2 Helloパケットの最小要件を満たしていない場合にネイバーが立ち上がりません。
*   **ポイント:** `show isis neighbors` で状態を確認する際、"INIT" 状態で止まっていないか注視してください。

### 3. Loopback 0 の到達性

RLOC（Routing Locator）として使用されるLoopback 0がアンダーレイのIGPで広報されていない場合、ファブリックの構築に失敗します。
*   **タスク:** 手動アンダーレイのタスクでは、`redistribute connected` や `network` ステートメントでLoopback 0を確実にルーティングテーブルに載せる必要があります。

### 4. シードデバイスの準備

LAN Automationを成功させるためには、シードデバイス側に特定の準備が必要です。
*   **必要項目:** DHCPプールの設定、DNACへのHTTP接続、および新しいデバイスへのルーティング（一時的なVLAN 1/VLAN 199等の構成）。

---

## 🛠 設定・検証コマンド

### 手動アンダーレイ構成

| 目的 | コマンド |
| :--- | :--- |
| **ジャンボフレームの有効化(グローバル)** | <code>(config)# system mtu 9100</code> |
| **IS-ISアンダーレイの基本設定** | <code>(config)# router isis [AREA_TAG]</code> <br> <code>(config-router)# net [NET_ID]</code> <br> <code>(config-router)# metric-style wide</code> |
| **インターフェイスでのIS-IS有効化** | <code>(config-if)# ip router isis [AREA_TAG]</code> <br> <code>(config-if)# isis network point-to-point</code> |
| **RLOC用Loopbackの構成** | <code>(config)# interface Loopback0</code> <br> <code>(config-if)# ip address [IP] [MASK]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **MTU設定の確認** | <code>show system mtu</code> <br> <code>show interfaces [ID] &#124; include MTU</code> |
| **IS-ISネイバーの状態確認** | <code>show isis neighbors</code> |
| **アンダーレイのルート到達性確認** | <code>show ip route isis</code> <br> <code>show ip route [RLOC_IP]</code> |
| **L3リンクのIP接続確認** | <code>ping [Neighbor_IP] size 1500 df-bit</code> |
| **CDPによる隣接確認(PnP用)** | <code>show cdp neighbors</code> |

---

## 🧪 ラボ学習・設定サンプル例

実際の CCIE 実技試験を想定した、SD-Access Underlay 関連の 12 個の実装シナリオです。

### 1. アンダーレイ用ジャンボフレームの一括設定

**【問題】**
ファブリック内のすべてのスイッチにおいて、VXLAN カプセル化パケットをフラグメンテーションなしで転送できるよう、システム MTU を最大値に設定せよ。

**【設定例】**
```ios
! 全スイッチで実行
system mtu 9100
! ※設定反映には再起動が必要な場合がある（ラボの指示に従うこと）
```

---

### 2. 手動 IS-IS アンダーレイの構築 (Edge-Border間)

**【問題】**
R1 (Border) と SW1 (Edge) の間に、IS-IS を使用した L3 アンダーレイを構成せよ。Wide Metric を使用し、Loopback 0 への到達性を確保せよ。

**【設定例】**
```ios
! R1 (Border)
router isis FABRIC
 net 49.0001.0000.0000.0001.00
 metric-style wide
 log-adjacency-changes
interface GigabitEthernet1/0/1
 ip router isis FABRIC
 isis network point-to-point
interface Loopback0
 ip address 1.1.1.1 255.255.255.255
 ip router isis FABRIC
```

---

### 3. LAN Automation 用シードデバイスの事前設定

**【問題】**
シードデバイス (Seed-1) において、DNAC からの LAN Automation リクエストを受け入れるため、新しいスイッチ向けの DHCP サービスを準備せよ（DNAC が自動で行わない部分を想定）。

**【設定例】**
```ios
! シードデバイス側
ip routing
interface GigabitEthernet1/0/48
 description Downlink_to_New_Switch
 no switchport
 ip address 192.168.1.1 255.255.255.252
 ! DNACがこのIFを通じてPnPトラフィックを管理する
```

---

### 4. PnP 用 VLAN 1 接続の確認

**【問題】**
（トラブルシューティング）新しい Edge スイッチを接続したが、DNAC の PnP ポータルに現れない。隣接関係を確認し、VLAN 1 がネイティブで通っているか検証せよ。

**【検証】**
```ios
Seed-Switch# show cdp neighbors
! 新しいスイッチが見えているか確認
Seed-Switch# show interface trunk
! VLAN 1 が Allowed/Active であることを確認
```

---

### 5. デバイス Discovery 時の認証情報の解決

**【問題】**
DNAC でデバイスをスキャンしたが、「Unauthorized」エラーで失敗する。スイッチ側の SNMP および VTY の設定を DNAC の設定に合わせて修正せよ。

**【設定例】**
```ios
! スイッチ側
snmp-server community CISCO_CCIE RO
username admin privilege 15 secret Cisco123
line vty 0 4
 transport input ssh
 login local
```

---

### 6. Extended Node のトランクポート手動修正

**【問題】**
Extended Node が Edge スイッチに接続されているが、トラフィックが通らない。Edge スイッチ側のトランクポートで、Extended Node が必要とする VLAN が許可されているか確認・設定せよ。

**【設定例】**
```ios
! Fabric Edge 側
interface GigabitEthernet1/0/10
 description Connection_to_Extended_Node
 switchport mode trunk
 switchport trunk allowed vlan 10,20,30  ! 必要なVLANを追加
```

---

### 7. Policy Extended Node での SGT 保持確認

**【問題】**
PEN スイッチから Edge スイッチにパケットが送られる際、SGT タグが保持されていることを確認せよ。

**【検証】**
```ios
Edge-Switch# show cts interface GigabitEthernet1/0/10
! "Propagation: Enabled" であることを確認
```

---

### 8. アンダーレイ IS-IS のコスト調整によるパス制御

**【問題】**
アンダーレイにおいて、RLOC 間の通信を Gi1/0/1 ではなく Gi1/0/2 経由に誘導せよ。IS-IS メトリックを直接操作すること。

**【設定例】**
```ios
interface GigabitEthernet1/0/1
 isis metric 1000  ! コストを上げて回避させる
```

---

### 9. RLOC 到達性の ping 検証（サイズ指定）

**【問題】**
RLOC 間で 1500 バイトのパケットがフラグメンテーションなしで通るかテストせよ。

**【検証コマンド】**
```ios
Edge-Node# ping 2.2.2.2 source Loopback0 size 1500 df-bit
! 成功すればMTU 1500は確保されている。VXLAN用には1550以上が必要。
```

---

### 10. DNAC 管理インターフェイス（Underlay）の IP 割り当て

**【問題】**
フュージョンルータ (Fusion Router) を介して DNAC とアンダーレイが通信できるよう、管理用インターフェイスを構成せよ。

**【設定例】**
```ios
! Fusion Router 側
interface GigabitEthernet1/0/1
 description To_DNAC_MGMT
 ip address 10.10.100.1 255.255.255.0
```

---

### 11. IS-IS ネイバーシップ確立のデバッグ

**【問題】**
アンダーレイの IS-IS ネイバーが Established にならない原因を特定せよ。

**【検証】**
```ios
debug isis adj-packets
! "MTU mismatch" や "Area mismatch" のログをチェック
```

---

### 12. プレフィックス抑制 (Prefix Suppression) の適用

**【問題】**
アンダーレイのルーティングテーブルを軽量化するため、Loopback 以外のトランジットリンクの IP 情報を IGP から除外せよ（高度な最適化）。

**【設定例】**
```ios
router isis FABRIC
 advertise-passive-only
! ※インターフェイスをpassiveに設定し、Loopbackのみを広報
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKENS-1501: Enterprise Campus Wired Design Fundamentals**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-1501)
    *   キャンパス設計の基礎と、SD-AccessアンダーレイとしてのIS-ISの役割を解説。
*   [**BRKENT-2076: Cisco SD-Access - Design & Deployment**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2076)
    *   SD-Accessの全体像とアンダーレイ要件の深い解説。
*   [**BRKOPS-2035: Real World Use Cases for Deploying Cisco SD-Access**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKOPS-2035)
    *   LAN Automationの実際の挙動とトラブル事例。

### Configuration ガイド
*   [**Cisco DNA Center SD-Access LAN Automation Guide**](https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/dna-center/deploy-guide/cisco-dna-center-sd-access-wl-dg.pdf)
*   [**SD-Access Manual Underlay Configuration (Cisco Design Guide)**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdg-2019oct.pdf)

### テクニカルドキュメント・設定例
*   [**Cisco SD-Access: Troubleshooting the Fabric (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/cloud-systems-management/dna-center/215324-sd-access-troubleshooting-the-fabric.html)
*   [**Extended Nodes and Policy Extended Nodes Overview**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9000/software/release/17-9/configuration_guide/sda/b_179_sda_cg/m-sda-extended-nodes.html)

---


## 📝 補足
- この学習メモは、SD-Access の「根幹」であるアンダーレイの構築から、自動化の仕組み、そして物理トポロジの拡張までを CCIE ラボ試験の要求レベルで網羅しています。特に **LAN Automation の失敗原因（CDP、VLAN 1、DHCPプールの不足等）** を理論的に整理しておくことが、試験中の迅速なトラブル解決に直結します。

