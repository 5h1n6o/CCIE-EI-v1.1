---
layout: default
title: 1.2.j-BFD
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 10
---

# 1.2.j Bidirectional Forwarding Detection (BFD)

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.j Bidirectional Forwarding Detection (BFD)」について整理しました。

---

## 📘 概要

**Bidirectional Forwarding Detection (BFD)** は、2台の隣接するルータ間におけるフォワーディングパスの故障を極めて迅速（サブ秒単位）に検出するための、軽量かつ汎用的なプロトコルです。

OSPF、EIGRP、BGPなどのルーティングプロトコルは、独自の「ハロー（Hello）」メカニズムで隣接関係を維持していますが、これらのタイマーは通常秒単位（OSPFのデフォルトではDeadタイマーが40秒など）であり、現代のミッションクリティカルなネットワークで求められる高速コンバージェンスには不十分です。BFDは、これらのルーティングプロトコルから独立して動作し、故障を検知すると登録されている各プロトコル（クライアント）に即座に通知します。これにより、IGP/BGPのタイマーを待つことなく、ミリ秒単位での経路切り替えが可能となります。

---

## 🔑 要点

### 1. BFD の動作メカニズム

BFDは、隣接ルータ間で制御パケット（BFD Control Packets）を高速に交換します。
*   **レイヤ:** 通常、UDPポート `3784` (Single-hop) または `3785` (Multi-hop) を使用します。
*   **ハードウェア処理:** Catalyst 9000シリーズやASRルータなどのプラットフォームでは、BFDパケットの処理をCPUではなくハードウェア（ASIC/FPGA）で行うことができ、システムの安定性を損なわずに超高速な監視が可能です。

### 2. 主要な動作モード

*   **Async Mode（非同期モード）:** 相互に定期的な制御パケットを送信し合う、最も一般的なモードです。
*   **Echo Mode（エコーモード）:** 送信元が自身のIPアドレスを宛先としたパケットを送信し、対向デバイスのデータプレーン（フォワーディングエンジン）で折り返させます。これにより、対向デバイスのCPU負荷を抑えつつ、フォワーディングパスが生きているかを「自分自身で」確認できます。

### 3. パラメータの定義

BFDのパフォーマンスは以下の3つの値で決定されます。
*   **Desired Min Transmit Interval:** 自身がパケットを送信する最小間隔。
*   **Required Min Receive Interval:** 自身がパケットを受信できる最小間隔。
*   **Multiplier:** パケットが何回連続で届かなかった場合に「ダウン」と判定するか。
    *   *検出時間 = Max (自装置の送信間隔, 対向の受信間隔) × Multiplier*

### 4. クライアント登録（Registration）

BFD自体はルートを学習しません。OSPF、BGP、EIGRP、Static RouteなどがBFDの「クライアント」として登録され、BFDからのダウン通知を受けて初めて隣接関係を解除します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単にBFDを有効にするだけでなく、特定のコンバージェンス要件を満たすためのパラメータ調整や、特殊なトポロジでのトラブルシューティングが問われます。

### 1. サブ秒コンバージェンスの設計

試験タスクで「 failure detection in less than 200ms」といった数値目標が提示された場合、BFDのインターバルとマルチプライヤを計算して設定する必要があります。
*   例：`bfd interval 50 min_rx 50 multiplier 3` → 検出時間は150ms。

### 2. Echo Mode とセキュリティ（ACL）の競合

BFD Echoパケットは送信元のIPアドレスへ戻ってきます。インターフェイスにACLを適用している場合、このEchoパケットを拒否してしまうとBFDセッションが `UP` にならないシナリオがトラブルシューティングセクションで頻出します。

### 3. BFD Template の活用

現代の IOS XE 実装では、インターフェイスに直接コマンドを書くよりも、`bfd-template` を定義し、それを複数のインターフェイスに適用する手法が推奨されます。ラボの要件で「Use templates where possible」とある場合は、この形式で記述しなければなりません。

### 4. BFD over Bundle (Port-Channel)

EtherChannel（LACP）上でBFDを動作させる場合、論理ポートチャネル全体を監視するのか、個々の物理メンバリンクを監視するのか（Micro-BFD）の区別が重要です。

### 5. Static Route との連携

動的プロトコルが走っていないリンク（例：ISPへのスタティックルート）に対して、`track` オブジェクトを介してBFDを紐付け、次ホップの到達性をミリ秒単位で監視する構成が求められます。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BFDテンプレートの作成** | <code>bfd-template single-hop [NAME]</code> |
| **テンプレート内タイマー設定** | <code>interval microsec [ms] min_rx [ms] multiplier [N]</code> |
| **インターフェイスへの適用** | <code>(config-if)# bfd stack [NAME]</code> / <code>bfd interval...</code> |
| **OSPFでの有効化** | <code>(config-router)# bfd all-interfaces</code> |
| **EIGRPでの有効化** | <code>(config-router-af-interface)# bfd</code> |
| **BGPでの有効化(ネイバー単位)** | <code>(config-router)# neighbor [IP] fall-over bfd</code> |
| **Static Routeとの紐付け** | <code>ip route [prefix] [mask] [next-hop] bfd</code> |
| **BFDネイバーの状態確認** | <code>show bfd neighbors [detail]</code> |
| **BFDサマリー表示** | <code>show bfd summary</code> |
| **特定のクライアント確認** | <code>show bfd neighbors client [ospf&#124;bgp&#124;eigrp]</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIEレベルの複雑な要件を想定した実装例を提示します。

### 1. OSPF：テンプレートを使用した高速障害検出

**【問題内容】**
Cat1とCat2の間のすべてのOSPFエリア0リンクにおいて、BFDを用いた障害検出を構成せよ。検出時間は300ms以内とし、設定には `bfd-template` を使用すること。

**【設定例】**
```ios
! BFDテンプレートの定義 (100ms * 3 = 300ms)
bfd-template single-hop CCIE_BFD
 interval microsec 100 min_rx 100 multiplier 3
!
! インターフェイスへの適用
interface GigabitEthernet0/1
 bfd stack CCIE_BFD
!
! OSPFへの統合
router ospf 1
 bfd all-interfaces
```

---

### 2. BGP：マルチホップ BFD (eBGP)

**【問題内容】**
直接接続されていない eBGP ネイバー (10.1.13.3) との間で BFD を有効にせよ。通常、BFDは直接接続を想定するが、マルチホップ環境でも動作するように構成すること。

**【設定例】**
```ios
! BGPの設定
router bgp 65001
 neighbor 10.1.13.3 remote-as 65003
 neighbor 10.1.13.3 ebgp-multihop 2
 ! マルチホップBFDの有効化
 neighbor 10.1.13.3 fall-over bfd multihop
```
**【検証】**
`show bfd neighbors detail` を実行し、"SessionType: Multihop" と表示されていることを確認します。

---

### 3. Static Route：次ホップ到達性の監視

**【問題内容】**
ISPへのデフォルトルート `0.0.0.0/0 via 192.168.1.1` を設定せよ。ただし、物理リンクがUpしていても次ホップへのBFDが失敗した場合は、このルートを削除しバックアップ経路（AD 200）へ切り替えること。

**【設定例】**
```ios
! インターフェイスでBFDを有効化
interface GigabitEthernet0/0
 bfd interval 100 min_rx 100 multiplier 3
!
! BFDをスタティックルートに紐付ける
ip route 0.0.0.0 0.0.0.0 192.168.1.1 bfd
ip route 0.0.0.0 0.0.0.0 172.16.1.1 200
```
※注：一部のバージョンでは `track` を経由した実装が必要になる場合がありますが、最新の IOS XE では `ip route ... bfd` がサポートされています。

---

### 4. IPv6：EIGRPv6 名前付きモードでの BFD

**【問題内容】**
EIGRP名前付きモードインスタンス 'CCIE' において、VRF 'CUSTOMER' 内のIPv6隣接関係すべてに BFD を適用せよ。

**【設定例】**
```ios
router eigrp CCIE
 address-family ipv6 vrf CUSTOMER autonomous-system 100
  af-interface default
   bfd
  exit-af-interface
```

---

### 5. トラブルシューティング：Echo Mode の停止

**【問題内容】**
対向デバイスが BFD Echo パケットの折り返しをサポートしていない、あるいは ACL で UDP 3784 が許可されていない場合でも、BFD セッションを確立できるように、自身のデバイスで Echo Mode を無効化せよ。

**【設定例】**
```ios
interface GigabitEthernet0/1
 ! エコーモードを無効にし、Asyncモード（CPU処理）のみにする
 no bfd echo
```

---

## 参考リソースリンク

### Configurationガイド
*   [Bidirectional Forwarding Detection (BFD) Configuration Guide (IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bfd/configuration/xe-17/irb-xe-17-book.html)
*   [BFD for BGP, OSPF, and EIGRP (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/bidirectional-forwarding-detection-bfd/116086-configure-bfd-00.html)

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols (BFD故障検知の仕組み)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKENS-2031: Enterprise Campus Design (High Availability部分)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENS-2031)

### テクニカルドキュメント・設定例
*   [BFD Multi-hop for BGP Implementation](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-16/irg-xe-16-book/irg-bfd-mh.html)
*   [BFD Support for Static Routes](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bfd/configuration/xe-16/irb-xe-16-book/irb-bfd-static.html)

---
## 📝 補足

- この学習メモは、CCIE EIラボ試験で必須となる「理論に基づいた高速コンバージェンスの実装」を網羅しています。BFDは、SD-WAN（Edge間のトンネル監視）やSD-Access（アンダーレイの監視）においても核となる技術であるため、設定後の `show bfd neighbors` でのステータス遷移（特に `Diag` 列のメッセージ）を完璧に読み解けるようにしておくことが、合格への近道となります。


