---
layout: default
title: 3.1-Static-GRE
parent: 3-Transport-Technologies-and-Solutions
nav_order: 1
---

# 3.1 Static point-to-point GRE tunnels

## 📘 概要

* **機能概要**: Generic Routing Encapsulation（GRE: RFC 2784 / RFC 2890）は、任意のネットワーク層プロトコル（Passenger Protocol: IPv4, IPv6, IPX, AppleTalk 等）をポイントツーポイント（P2P）の仮想リンク上でカプセル化し、別の IP ネットワーク（Delivery Protocol / Transport Network）を透過させて転送するカプセル化プロトコルです。
* **利用目的**: 
  1. マルチキャストおよび非 IP プロトコルの透過転送（IPsec 単体ではマルチキャストを直接暗号化転送できないため、GRE over IPsec として利用）。
  2. ルーティングプロトコル（OSPF, EIGRP, BGP 等）のネイバーシップ形成（物理的に離れた拠点間での L3 ルーティング統合）。
  3. マルチテナント環境における VRF トラフィックのアンダーレイ透過（VRF-Aware GRE）。
  4. IPv6 over IPv4 トランジション（IPv4 パイプラインを介した IPv6 島どうしの接続）。
* **どのような場面で利用するか**: 拠点間 VPN 構築において、動的ルーティングプロトコルやマルチキャスト（IP 監視カメラ、音声ストリーミング等）を通す必要がある環境、または IPsec と組み合わせてセキュアな拠点間オーバーレイ網を構築する際に標準的に使用されます。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| **特徴** | 任意の <code>Passenger Protocol</code> を <code>IP Protocol 47</code>（GRE ヘッダー）でカプセル化する P2P 仮想トンネル技術 |
| **用途** | 動的ルーティングプロトコル（OSPF/EIGRP/BGP）の透過、マルチキャスト転送、IPv6 over IPv4、IPsec との併用 |
| **メリット** | シンプルな構成、マルチキャスト・非 IP パケットの透過、ヘッダー追加が 24 バイトと軽量（IPsec Tunnel モードより省サイズ） |
| **デメリット** | **暗号化機能（Confidentiality）を持たない**（平文転送）、静的設定のため拠点増加に伴いメッシュ管理が困難（DMVPN / SD-WAN への拡張が必要） |
| **対応機種** | すべての Cisco IOS / IOS-XE ルータ（Catalyst 8300/8500, ISR4000, ASR1000, Catalyst 9000 シリーズスイッチ等） |
| **制限事項** | ポイントツーポイント固定（マルチポイント転送不可）、ステートレスプロトコル（デフォルトで対向の Down を検知不可） |
| **設計上の注意点** | **カプセル化オーバーヘッドによるパケット断片化（Fragment）**、**再帰的ルーティング（Recursive Routing）エラー**、Keepalive の設定要否 |

---

## 🏗 動作原理

### カプセル化ヘッダー構造

通常パケットに対し、24 バイトのカプセル化オーバーヘッドが加算されます。

```text
+-------------------+-------------------+-------------------+-------------------+
| Outer IP Header   | GRE Header        | Inner IP Header   | Payload           |
| (Delivery Protocol| (4 Bytes ~ 16B)   | (Passenger Proto) | (TCP/UDP/ICMP/    |
|  20 Bytes)        | Protocol=0x0800   |                   |  Multicast/etc.)  |
+-------------------+-------------------+-------------------+-------------------+
|<--- Underlay Routing ------------>|<--- Overlay Routing --------------->|
```

* **Outer IP Header (20 Bytes)**: 
  * 送信元 IP: トンネルソース (`tunnel source`)
  * 宛先 IP: トンネルデスティネーション (`tunnel destination`)
  * Protocol Field: `47` (GRE)
* **GRE Header (4 Bytes ~ 16 Bytes)**:
  * Flags (16 bits): Checksum (C), Key (K), Sequence Number (S) の有無を示すフラグ
  * Protocol Type (16 bits): 内側パケットのプロトコル種別（例: IPv4 の場合は `0x0800`、IPv6 の場合は `0x86DD`）
  * Key / Checksum / Sequence Number (オプション属性)

### トラフィックフロー図

```text
[Host A (10.1.1.10)]
       │ (1. Inner IPv4 Packet: Src 10.1.1.10 -> Dst 10.2.2.20)
       ▼
[Router A (Tunnel Source: 1.1.1.1)]
       │
       ├─ Overlay Routing Lookup -> Outgoing Int: Tunnel0
       ├─ GRE Encapsulation (Add Outer IP Header: Src 1.1.1.1 -> Dst 2.2.2.2, Proto 47)
       ├─ Underlay Routing Lookup -> Outgoing Int: Gi0/0/0
       ▼
[WAN / Internet Underlay Network]
       │ (Outer IP Packet: Src 1.1.1.1 -> Dst 2.2.2.2, Proto 47)
       ▼
[Router B (Tunnel Dest: 2.2.2.2)]
       │
       ├─ Decapsulation (Strip Outer IP & GRE Header)
       ├─ Inner Overlay Routing Lookup -> Outgoing Int: Gi0/0/1
       ▼
[Host B (10.2.2.20)]
```

---

## ⚙ 動作シーケンス

1. **パケットの受領**: Router A が LAN インターフェイスから宛先 IP `10.2.2.20` 宛ての IPv4 パケットを受信。
2. **オーバーレイ経路参照 (Overlay Routing Lookup)**: ルーティングテーブル（RIB）を検索し、`10.2.2.0/24` の Next-Hop が `Tunnel0`（対向 IP `192.168.12.2`）であることを特定。
3. **GRE カプセル化 (GRE Encapsulation)**:
   * 元のパケットの先頭に GRE ヘッダー（Protocol Type `0x0800`）を付加（4 バイト）。
   * さらに Outer IP ヘッダーを付加（送信元: `1.1.1.1`、宛先: `2.2.2.2`、Protocol Number: `47`）（20 バイト）。
4. **アンダーレイ経路参照 (Underlay Routing Lookup)**: Outer IP ヘッダーの宛先 `2.2.2.2` に基づき、グローバル（または Underlay VRF）ルーティングテーブルを検索し、物理アウトバウンドポート（例: `GigabitEthernet0/0/0`）から送信。
5. **中継ネットワーク通過**: WAN 網内のルータは Outer IP ヘッダーのみを参照してスイッチング（GRE ペイロードは透過）。
6. **カプセル化解除 (Decapsulation)**: Router B が `GigabitEthernet0/0/0` で Protocol 47 パケットを受信。自宛先（`2.2.2.2`）であることを確認し、Outer IP ヘッダーおよび GRE ヘッダーを剥ぎ取る。
7. **最終転送 (Inner Payload Forwarding)**: 取り出された Inner IP パケット（Src `10.1.1.10` -> Dst `10.2.2.20`）の宛先に基づき、LAN ポートへルーティング。

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. Blueprintで重要なポイント
* **再帰的ルーティング（Recursive Routing Error）の回避**: `TUNNEL-5-RECURSION` エラーの発生条件と解決手法。
* **GRE Keepalive メカニズム**: 対向機器の Down を動的に検知し、Tunnel インターフェイスの Line Protocol を `Down` に変化させるロジック。
* **MTU / MSS チューニング**: 24 バイトオーバーヘッド（IPsec 統合時は 72〜76 バイト以上）を考慮した `ip mtu` および `ip tcp adjust-mss` の最適な設計。
* **VRF-Aware GRE**: Underlay トランスポート（`tunnel vrf <VRF>`）と Overlay サービス（`ip vrf forwarding <VRF>`）の分離実装。
* **IPv6 over IPv4 / IPv4 over IPv6 GRE**: パッセンジャーとデリバリーの異種プロトコルスタック結合。

### 2. ラボ試験で設定させられそうな内容
* 指定された IP アドレス・VRF 間で静的 GRE トンネルを構築する。
* トンネル上で OSPF / EIGRP ネイバーを確立させ、特定プレフィックスを交換させる。
* パケットフラグメンテーションを防ぐため、適切な TCP MSS（例: `1360` や `1400`）および Tunnel MTU を設定する。
* GRE Keepalive を有効化し、プライマリ回線障害時にセカンダリパスへルーティングを切替させる。
* `tunnel key` や `tunnel checksum` 属性を指定要件に従って投入する。

### 3. よくある設定ミス
* **再帰的ルーティングの誘発**: OSPF や EIGRP の `network` コマンドで誤って Tunnel Destination IP（Underlay IP）を含めてしまい、トンネル経由で Underlay 経路が学習されてトンネルが Up/Down を繰り返す（`TUNNEL-5-RECURSION`）。
* **`tunnel source` / `tunnel destination` の不一致**: 片側で Lookback0 を指定し、対向で物理 IP を指定してしまう等のミス。
* **MTU 未調整によるパケットドロップ**: 大型パケット（1500 バイト等）で DF Bit (Don't Fragment) がセットされているトラフィックが破棄され、HTTP/SSH 等の通信がブラックホール化する。
* **VRF 指定漏れ**: Underlay 側が WAN VRF（例: `vrf forwarding INET`）に所属しているにもかかわらず、`tunnel vrf INET` を設定し忘れる。

### 4. 試験で狙われやすい制限事項
* **GRE Keepalive と IPsec の非互換性**: GRE Keepalive パケットは平文で自ルータへ折り返されるロジックを持つため、IPsec Tunnel モード等でカプセル化されると正しく処理できないケースがある（または `tunnel protection` 適用時の特殊動作）。
* **Point-to-Point 固定**: Static GRE は 1 つの `tunnel destination` しか指定できないため、マルチポイント構成には DMVPN（mGRE）が必要。

### 5. コンフィグ読解問題・show コマンド視点
* `show interface Tunnel0` の出力解析:
  * `Tunnel protocol/transport GRE/IP`
  * `Tunnel source 1.1.1.1, destination 2.2.2.2`
  * `Tunnel Transport VRF "INET"`
  * `Encapsulation overhead 24 bytes`
  * `Keepalive set (10 sec, 3 retries)`

---

## 🛠 設定方法

### 基本的な Static GRE トンネル設定

```bash
! Router A (Site-1)
interface Loopback0
 ip address 1.1.1.1 255.255.255.255
!
interface GigabitEthernet0/0/0
 description WAN-Underlay
 ip address 192.168.12.1 255.255.255.0
 no shutdown
!
interface Tunnel0
 description Static GRE to Router B
 ip address 10.255.255.1 255.255.255.252
 ip mtu 1476
 ip tcp adjust-mss 1436
 keepalive 10 3
 tunnel source GigabitEthernet0/0/0
 tunnel destination 192.168.12.2
!
```

```bash
! Router B (Site-2)
interface Loopback0
 ip address 2.2.2.2 255.255.255.255
!
interface GigabitEthernet0/0/0
 description WAN-Underlay
 ip address 192.168.12.2 255.255.255.0
 no shutdown
!
interface Tunnel0
 description Static GRE to Router A
 ip address 10.255.255.2 255.255.255.252
 ip mtu 1476
 ip tcp adjust-mss 1436
 keepalive 10 3
 tunnel source GigabitEthernet0/0/0
 tunnel destination 192.168.12.1
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| トンネル状態およびパラメータ確認 | <code>show interface Tunnel0</code> |
| GRE トンネル概要の一覧表示 | <code>show ip interface brief \| include Tunnel</code> |
| トンネルのソケット・カプセル化状態確認 | <code>show tunnel endpoints</code> |
| トンネル宛先の到達性確認 | <code>ping <Tunnel-Destination-IP></code> |
| トンネル経由のルーティング確認 | <code>show ip route <Overlay-Prefix></code> |
| GRE パケットのカプセル化/デカプセル化デバッグ | <code>debug tunnel gre</code> |
| Keepalive 送受信デバッグ | <code>debug keepalive</code> |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **`Tunnel0 is up, line protocol is down`** | 対向のアドレスへ到達不能、または GRE Keepalive の応答がない | <code>show interface Tunnel0</code><br><code>ping <destination></code> | 1. Underlay 側 IP 疎通を確認<br>2. 対向ルータで Tunnel インターフェイスが <code>no shut</code> されているか確認<br>3. 途中の FW で GRE (IP Proto 47) が遮断されていないか確認 |
| **`%TUNNEL-5-RECURSION: Tunnel0 recursively depends on actual destination`** | Tunnel Destination への経路が Tunnel 自体を経由して学習されている | <code>show ip route <destination></code> | 1. 動的ルーティング（OSPF/EIGRP/BGP）の判定範囲から Underlay ネットワークを除外<br>2. Underlay 宛先への固定静的ルート（`ip route <dest> <mask> <Physical-Int>`）を定義 |
| **TCP 通信が途中でハングする（SSH/HTTP が開かない）** | GRE オーバーヘッドによる MTU 超過（DF Bit 設定パケットが破棄） | <code>ping <dest> size 1476 df-bit</code> | トンネルインターフェイスで `ip mtu 1476` および `ip tcp adjust-mss 1436`（IPsec 併用時は 1360 以下）を設定 |
| **`Tunnel0 is down, line protocol is down`** | `tunnel source` インターフェイスが Down している、または IP 未設定 | <code>show ip interface brief</code> | <code>tunnel source</code> に正しく IP が割り当てられ UP している物理/Loopback ポートを指定 |
| **VRF 環境でトンネルが UP しない** | Underlay 側 VRF の指定漏れ | <code>show run interface Tunnel0</code> | トンネルコンフィグに `tunnel vrf <Underlay-VRF-Name>` を投入 |

---

## ⚠ 制限事項

* **マルチポイント転送不可**: Point-to-Point（1 対 1）固定。ハブ＆スポーク等で 1 つの Tunnel で複数拠点と接続したい場合は mGRE（Multipoint GRE）を使用する必要がある。
* **暗号化機能の不保持**: GRE 自体はデータを平文のままカプセル化するため、機密性の保護には IPsec (`tunnel protection ipsec profile <NAME>`) との組み合わせが必須。
* **Keepalive の動作ロジック制限**: GRE Keepalive は「自ルータが自身に向けて生成した Inner パケット」を対向で跳ね返させる仕組み（Loopback パケット）であるため、中間 FW のステートフルインスペクションで「Src=Dst の異形パケット」としてドロップされるケースがある。

---

## 🔄 他技術との関連

* **IPsec VPN**: GRE 単体では暗号化できないため、IPsec トランスポートモードと組み合わせて `GRE over IPsec`（`tunnel protection ipsec profile`）として実装される。
* **DMVPN (Dynamic Multipoint VPN)**: Static GRE を発展させ、mGRE + NHRP + IPsec を組み合わせることで動的メッシュトンネルを実現。
* **OSPF / EIGRP / BGP**: GRE トンネルをアンカーとして利用し、マルチキャスト制御パケットを対向へ届けることでネイバーを確立。
* **VRF-Lite**: `tunnel vrf`（アンダーレイ）と `ip vrf forwarding`（オーバーレイ）を用いてネットワークを論理分割・多重化。

---

## 🧩 比較表

### GRE vs IPsec Tunnel Mode vs VTI (Virtual Tunnel Interface)

| 比較項目 | GRE (Static) | IPsec Tunnel Mode | IPsec VTI (SVTI) |
| --- | --- | --- | --- |
| **カプセル化** | GRE (Proto 47) | ESP (Proto 50) / AH | ESP (Proto 50) |
| **マルチキャスト対応** | **○ (直接対応)** | × (不可) | **○ (直接対応)** |
| **暗号化機能** | × (なし) | ○ (標準) | ○ (標準) |
| **ヘッダーオーバーヘッド** | 24 Bytes | 32〜52 Bytes | 36〜52 Bytes |
| **設定の柔軟性** | 高い (任意プロトコル) | 低い (Crypto Map) | 高い (Routed Tunnel) |
| **ルーティング構成** | トンネル SVI に IP 付与 | Crypto Map で ACL マッチ | トンネル SVI に IP 付与 |

---

## 💡 ベストプラクティス

1. **カプセル化オーバーヘッドの計算と MSS 調整**:
   * GRE 単体: `ip mtu 1476`, `ip tcp adjust-mss 1436`
   * GRE over IPsec (Transport Mode): `ip mtu 1400`, `ip tcp adjust-mss 1360`
2. **Loopback インターフェイスの Tunnel Source 利用**:
   * 物理ポートの切替（冗長経路）に耐えうるよう、`tunnel source Loopback0` を使用し、Underlay 側で Loopback アドレスの到達性を担保する。
3. **再帰的ルーティング防止策の徹底**:
   * Overlay 側の動的ルーティングプロトコル（OSPF/EIGRP/BGP）の検索対象・広告対象に `tunnel source` / `tunnel destination` の IP アドレスを絶対に入れない。
4. **Keepalive の適切なパラメータ化**:
   * 迅速な切り替えのために `keepalive 5 3`（5秒間隔、3回未応答で Down）などを設定。

---

## 📝 ラボ学習・設定サンプル例

### Lab 1: 基本的な IPv4 Static GRE トンネルと OSPF ネイバー形成

* **問題**: R1 と R2 の間に Static GRE トンネル (Tunnel0) を構築し、トンネル経由で OSPF Area 0 を動作させて LAN 間を疎通させよ。
* **要件**:
  * トンネルソースは各ルータの GigabitEthernet0/0/0。
  * トンネル IP: R1 `10.0.0.1/30`, R2 `10.0.0.2/30`。
  * OSPF Area 0 で `10.0.0.0/30`, `192.168.1.0/24` (R1-LAN), `192.168.2.0/24` (R2-LAN) を広報。
  * 再帰的ルーティングを発生させないこと。

```bash
! --- R1 Configuration ---
interface GigabitEthernet0/0/0
 ip address 172.16.12.1 255.255.255.0
 no shutdown
!
interface Loopback0
 ip address 192.168.1.1 255.255.255.0
!
interface Tunnel0
 ip address 10.0.0.1 255.255.255.252
 ip mtu 1476
 ip tcp adjust-mss 1436
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
!
router ospf 1
 router-id 1.1.1.1
 network 10.0.0.0 0.0.0.3 area 0
 network 192.168.1.0 0.0.0.255 area 0
!
```

```bash
! --- R2 Configuration ---
interface GigabitEthernet0/0/0
 ip address 172.16.12.2 255.255.255.0
 no shutdown
!
interface Loopback0
 ip address 192.168.2.1 255.255.255.0
!
interface Tunnel0
 ip address 10.0.0.2 255.255.255.252
 ip mtu 1476
 ip tcp adjust-mss 1436
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.1
!
router ospf 1
 router-id 2.2.2.2
 network 10.0.0.0 0.0.0.3 area 0
 network 192.168.2.0 0.0.0.255 area 0
!
```

* **検証方法**:
  * `show ip ospf neighbor`: Tunnel0 上で FULL 状態を確認。
  * `show ip route`: R1 で `192.168.2.0/24` が OSPF 経由（Next-Hop 10.0.0.2）で学習されていることを確認。

---

### Lab 2: GRE Keepalive による高速障害検知と代替経路切り替え

* **問題**: R1 と R2 間に Primary トンネル (Tunnel0) と Backup トンネル (Tunnel1) を設定し、Primary トンネルに Keepalive を設定して障害時に自動切替を行わせよ。
* **要件**:
  * Tunnel0: `keepalive 3 3`（3秒間隔、3回失敗で Down）。
  * Static Route で Floating Static を構成し、Tunnel0 経由 Metric 1、Tunnel1 経由 Metric 10 とする。

```bash
! --- R1 Configuration ---
interface Tunnel0
 ip address 10.1.1.1 255.255.255.252
 keepalive 3 3
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
!
interface Tunnel1
 ip address 10.2.2.1 255.255.255.252
 tunnel source GigabitEthernet0/0/1
 tunnel destination 172.16.21.2
!
ip route 192.168.2.0 255.255.255.0 Tunnel0 1
ip route 192.168.2.0 255.255.255.0 Tunnel1 10
```

* **検証方法**:
  * 対向の Tunnel0 をシャットダウンした際、R1 で約 9 秒以内に `Tunnel0 line protocol changed state to down` が検知され、ルーティングテーブルが Tunnel1 に切り替わることを確認 (`show ip route 192.168.2.0`)。

---

### Lab 3: VRF-Aware GRE トンネル（Underlay VRF 分離）

* **Problem**: アンダーレイ WAN 網が VRF `INET` で管理されている環境で、オーバーレイのデフォルト VRF トラフィックを通す GRE トンネルを構築せよ。
* **要件**:
  * 物理ポート GigabitEthernet0/0/0 は VRF `INET` に所属。
  * Tunnel0 は VRF `INET` をトランスポートとして利用し、オーバーレイ IP `10.255.1.1/30` を保持。

```bash
! --- R1 Configuration ---
vrf definition INET
 address-family ipv4
!
interface GigabitEthernet0/0/0
 vrf forwarding INET
 ip address 192.168.100.1 255.255.255.0
 no shutdown
!
interface Tunnel0
 ip address 10.255.1.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 192.168.100.2
 tunnel vrf INET
!
```

* **検証方法**:
  * `show interface Tunnel0` を実行し `Tunnel Transport VRF "INET"` と表示されることを確認。
  * `ping 10.255.1.2`（デフォルト VRF から ping 通信が成功すること）を検証。

---

### Lab 4: GRE Tunnel Key & Checksum の設定

* **Problem**: 同一の送信元・宛先 IP 間で複数の GRE トンネルを識別・混同防止するために GRE Key を設定し、整合性チェックサムを有効化せよ。
* **要件**:
  * Tunnel Key: `55555`
  * Checksum を有効化 (`tunnel checksum`)

```bash
! --- R1 Configuration ---
interface Tunnel0
 ip address 10.10.10.1 255.255.255.252
 tunnel source 1.1.1.1
 tunnel destination 2.2.2.2
 tunnel key 55555
 tunnel checksum
!
```

```bash
! --- R2 Configuration ---
interface Tunnel0
 ip address 10.10.10.2 255.255.255.252
 tunnel source 2.2.2.2
 tunnel destination 1.1.1.1
 tunnel key 55555
 tunnel checksum
!
```

* **検証方法**:
  * `show interface Tunnel0` で `Tunnel key 55555`, `Checksumming enabled` を確認。
  * 対向の Key を不一致（例: `tunnel key 12345`）に変更した場合、パケットがドロップされることを確認。

---

### Lab 5: IPv6 over IPv4 GRE トンネル

* **Problem**: IPv4 WAN 網を介して 2 つの IPv6 拠点を接続する GRE トンネルを構築せよ。
* **要件**:
  * トンネルモード: `tunnel mode gre ip`（デフォルト）
  * トンネル上に IPv6 アドレスを割り当て、IPv6 経路を疎通させる。

```bash
! --- R1 Configuration ---
interface Tunnel0
 no ip address
 ipv6 address 2001:db8:1000::1/64
 ipv6 enable
 tunnel source GigabitEthernet0/0/0
 tunnel destination 192.168.12.2
!
ipv6 route 2001:db8:2000::/64 Tunnel0
```

```bash
! --- R2 Configuration ---
interface Tunnel0
 no ip address
 ipv6 address 2001:db8:1000::2/64
 ipv6 enable
 tunnel source GigabitEthernet0/0/0
 tunnel destination 192.168.12.1
!
ipv6 route 2001:db8:1000::/64 Tunnel0
```

* **検証方法**:
  * `ping ipv6 2001:db8:1000::2` が成功することを確認。
  * `show interface Tunnel0` で `Tunnel protocol/transport GRE/IP` と表示されることを確認。

---

### Lab 6: IPv4 over IPv6 GRE トンネル

* **Problem**: IPv6 バックボーン網を介して IPv4 トラフィックをカプセル化転送する GRE トンネルを構成せよ。
* **要件**:
  * トンネルモード: `tunnel mode gre ipv6`

```bash
! --- R1 Configuration ---
interface GigabitEthernet0/0/0
 ipv6 address 2001:db8:9999::1/64
!
interface Tunnel0
 ip address 10.50.50.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 2001:db8:9999::2
 tunnel mode gre ipv6
!
```

```bash
! --- R2 Configuration ---
interface GigabitEthernet0/0/0
 ipv6 address 2001:db8:9999::2/64
!
interface Tunnel0
 ip address 10.50.50.2 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 2001:db8:9999::1
 tunnel mode gre ipv6
!
```

* **検証方法**:
  * `show interface Tunnel0` で `Tunnel protocol/transport GRE/IPv6` を確認。

---

### Lab 7: GRE over IPsec (IPsec Profile 適用)

* **Problem**: Static GRE トンネルに IPsec 暗号化（Transport Mode）を結合せよ。
* **要件**:
  * IPsec Profile 名: `GRE-IPSEC-PROFILE`
  * IKEv2 を使用すること。

```bash
! --- R1 Configuration ---
crypto ikev2 proposal PROP-1
 encryption aes-cbc-256
 integrity sha256
 group 14
!
crypto ikev2 policy POL-1
 proposal PROP-1
!
crypto ikev2 keyring KEYRING-1
 peer R2
  address 172.16.12.2
  pre-shared-key cisco123
!
crypto ikev2 profile IKEv2-PROFILE
 match identity remote address 172.16.12.2 255.255.255.255
 identity local address 172.16.12.1
 authentication remote pre-share
 authentication local pre-share
 keyring local KEYRING-1
!
crypto ipsec transform-set TS-1 esp-aes 256 esp-sha256-hmac
 mode transport
!
crypto ipsec profile GRE-IPSEC-PROFILE
 set transform-set TS-1
 set ikev2-profile IKEv2-PROFILE
!
interface Tunnel0
 ip address 10.0.0.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
 tunnel protection ipsec profile GRE-IPSEC-PROFILE
!
```

* **検証方法**:
  * `show crypto ipsec sa`: トンネル経由通信時に encapsulation / decapsulation カウンタが増加することを確認。

---

### Lab 8: BGP Over Static GRE Tunnel

* **Problem**: 2 拠点間で Static GRE トンネルを構築し、トンネル上で eBGP セッションを確立せよ。
* **要件**:
  * R1: AS 65001, R2: AS 65002
  * Tunnel IP: R1 `10.200.1.1/30`, R2 `10.200.1.2/30`

```bash
! --- R1 Configuration ---
interface Tunnel0
 ip address 10.200.1.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
!
router bgp 65001
 bgp router-id 1.1.1.1
 neighbor 10.200.1.2 remote-as 65002
 address-family ipv4
  neighbor 10.200.1.2 activate
  network 192.168.1.0 mask 255.255.255.0
 exit-address-family
!
```

* **検証方法**:
  * `show ip bgp summary`: ネイバー状態が `Established` になることを確認。

---

### Lab 9: Path MTU Discovery (PMTUD) と GRE

* **Problem**: トンネルインターフェイスで Path MTU Discovery を有効化し、DF ビットが立ったパケットに対する ICMP Unreachable 処理を自動化せよ。
* **要件**:
  * `tunnel path-mtu-discovery` を有効化。

```bash
! --- R1 Configuration ---
interface Tunnel0
 ip address 10.1.1.1 255.255.255.252
 ip mtu 1476
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
 tunnel path-mtu-discovery
!
```

* **検証方法**:
  * `show ip traffic` で ICMP fragmentation needed 送信数を確認。

---

### Lab 10: 再帰的ルーティング（Recursive Routing）障害の復旧実演

* **Problem**: R1 と R2 間で Tunnel0 上の EIGRP が誤って Underlay 経路を広告し、トンネルがフラッピングしている。これを修復せよ。
* **障害設定**: `router eigrp 100` で `network 0.0.0.0` が指定され、Underlay IP `172.16.12.0/24` が Tunnel0 経由で交換されてしまっている。
* **要件**: EIGRP のネットワーク指定を限定し、再帰的ルーティングを防止せよ。

```bash
! --- 修正コンフィグ (R1 / R2 共通) ---
router eigrp 100
 no network 0.0.0.0
 ! 必要な Overlay ネットワークのみを指定
 network 10.0.0.0 0.0.0.3
 network 192.168.0.0 0.0.255.255
!
```

* **検証方法**:
  * `show ip route 172.16.12.0` を実行し、Underlay 経路が物理ポート指向に戻り、`TUNNEL-5-RECURSION` が消滅することを確認。

---

## ❓ 想定試験問題

### 1. トラブルシューティング（再帰的ルーティング）
**問題**:  
R1 と R2 間の GRE トンネル (Tunnel0) が確立された直後、コンソールに以下のログが連続出力され、トンネルがフラッピングを繰り返しています。原因と対処方法を説明してください。  
`%TUNNEL-5-RECURSION: Tunnel0 recursively depends on actual destination 192.168.12.2`

**回答・解説**:  
* **原因**: トンネル宛先 IP アドレス（`192.168.12.2`）への経路が、Tunnel0 自体を経由してルーティングテーブル（RIB）に登録されたため発生します。自ルータはトンネルをカプセル化するために `192.168.12.2` へ送ろうとしますが、その経路が Tunnel0 を指しているため、カプセル化の無限ループ（再帰的依存）を検知して IOS が Tunnel0 を強制 Down させます。
* **対処方法**: トンネル上で動くルーティングプロトコル（OSPF/EIGRP/BGP）の `network` 宣言や再配送条件から、Underlay ネットワーク（`192.168.12.0/24`）を除外します。必要に応じて物理ポートに向けた静的ルート（`ip route 192.168.12.2 255.255.255.255 GigabitEthernet0/0/0`）を投入して固定します。

---

### 2. コンフィグ読解・MTU問題
**問題**:  
以下の Tunnel0 コンフィグにおいて、クライアントPCからトンネル経由で 1500 バイトの Web トラフィック（DF Bit=1）を送信した際、パケットが破棄される理由と、それを防止するための追加設定コマンドを 2 つ挙げてください。

```bash
interface Tunnel0
 ip address 10.1.1.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
!
```

**回答・解説**:  
* **原因**: GRE カプセル化により 24 バイトのヘッダー（Outer IP 20B + GRE 4B）が付加されるため、1500 バイトのパケットは Outer で 1524 バイトとなります。物理ポートの MTU が 1500 バイトの場合、1524 バイトは超過します。DF Bit（Don't Fragment）が立てられているため、ルータはパケットを破棄し ICMP Type 3 Code 4 を返そうとしますが、Path MTU フィルタ等で遮断されるとブラックホール化します。
* **追加コマンド**:
  1. `ip mtu 1476` (Tunnel インターフェイス上)
  2. `ip tcp adjust-mss 1436` (Tunnel インターフェイス上)

---

### 3. Design・ Keepalive 仕様
**問題**:  
GRE トンネルにおいて `keepalive 5 3` を設定した場合の動的な Line Protocol 切替メカニズムについて説明してください。

**回答・解説**:  
* **動作メカニズム**:
  1. ルータは 5 秒ごとに GRE Keepalive パケットを生成します。このパケットの Inner Header は「送信元=トンネル宛先 IP、宛先=トンネルソース IP」に設定されています。
  2. 対向ルータがこのパケットを受信すると、デカプセル化して Inner IP を参照し、宛先が対向（送信側ルータ）宛であるため、通常の IP ルーティングに従って相手へ送り返します（自ルータにパケットが跳ね返ってくる）。
  3. 送信側ルータが自身が送信した Inner パケットを受信することで「対向ルータおよびパスが健全である」と判定します。
  4. 3 回連続（15秒間）でこの返信を受信できなかった場合、Line Protocol を `Down` に切り替えます。

---

### 4. 実装・VRF-Aware GRE
**問題**:  
Underlay ネットワークが VRF `WAN` に所属しており、Overlay 側が VRF `LAN_A` に所属している場合の R1 の Tunnel0 設定を作成してください。

**回答・解説**:

```bash
vrf definition WAN
 address-family ipv4
!
vrf definition LAN_A
 address-family ipv4
!
interface GigabitEthernet0/0/0
 vrf forwarding WAN
 ip address 172.16.12.1 255.255.255.0
!
interface Tunnel0
 vrf forwarding LAN_A
 ip address 10.100.1.1 255.255.255.252
 tunnel source GigabitEthernet0/0/0
 tunnel destination 172.16.12.2
 tunnel vrf WAN
!
```

---

### 5. トラブルシューティング（IPsec 結合）
**問題**:  
`tunnel protection ipsec profile` を設定した GRE over IPsec トンネルにおいて、IPsec SA は成立 (`QM_IDLE` / `Active`) しているにもかかわらず、Tunnel インターフェイス間で ping が通らない場合、最初に確認すべきコマンドと原因を述べてください。

**回答・解説**:  
* **確認コマンド**: `show crypto ipsec sa`
* **原因の判別**:
  * `pkts encaps` が増加し `pkts decaps` が 0 の場合: 送信側は暗号化して出しているが、受信側で受容できていない（SPI 不一致、ACL 遮断、または NAT-T ポート未開放）。
  * `pkts decaps` は増加するが Inner パケットが届かない場合: Inner IP のルーティングミス、または対向ルータでの `ip vrf forwarding` や ACL による破棄。

---

## 🔗 参考リソース

* [Cisco IOS Flexible User Interface Configuration Guide - Configuring GRE Tunnels](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/interface/configuration/xe-17/ir-xe-17-book/ir-gretun.html)
* [Cisco Technical Notes - How to Configure GRE Tunnel Keepalive](https://www.cisco.com/c/en/us/support/docs/ip/generic-routing-encapsulation-gre/118370-technote-gre-00.html)
* [Cisco Live - BRKRST-2338: Troubleshooting GRE Tunnels](https://www.ciscolive.com/)
* [Cisco Command Reference - tunnel source / tunnel destination](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/interface/command/ir-cr-book.html)
* [Cisco Validated Design (CVD) - IPsec Virtual Private Networks Design Guide](https://www.cisco.com/c/en/us/solutions/enterprise/design-zone-security/index.html)

---

## 📝 **補足（Notes）**

- **学習メモ**: GRE カプセル化は CCIE EI ラボ試験において、DMVPN や SD-WAN、IPsec トンネル構成の「基礎の積み木」として頻繁に登場します。単体での設定だけでなく、オーバーレイ/アンダーレイの分離（`tunnel vrf`）および MTU/MSS の調整を無意識に行えるレベルまで自動化してください。
- **図解**:
  ```text
  [Passenger: IPv4/IPv6/Multicast] ➔ [GRE Header (4B)] ➔ [Outer IP Header (20B)] ➔ [Underlay Physical Int]
  ```
- **注意点**: ラボ試験で `tunnel source` にインターフェイス名（例: `Gi0/0/0`）を指定するか、IP アドレスを指定するかは問題文の指示（「Use interface name as tunnel source」等）を厳格に守ってください。

## 参考リソースリンク

### 関連動画・スライド (Cisco Live)
*   [**BRKSEC-2010: Advanced GRE/mGRE implementation**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKSEC-2010)
    *   GREの内部構造とIPsec連携の深い解説。
*   [**BRKRST-3320: Troubleshooting IP Routing**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
    *   Recursive Routing 発生時のパケット挙動のデバッグ方法。

### Configuration ガイド
*   [**IP Routing: GRE Configuration Guide (Cisco IOS XE 17.x)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book.html)
*   [**Configuring IPv6 over IPv4 GRE Tunnels**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipv6/configuration/xe-3s/ipv6-xe-3s-book/ip6-tunnel4-xe.html)。

### テクニカルノーツ・設定例
*   [**Generic Routing Encapsulation (GRE) FAQ**](https://www.cisco.com/c/en/us/support/docs/ip/generic-routing-encapsulation-gre/13731-48.html)
*   [**GRE Keepalives and Tunnel Flapping (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/generic-routing-encapsulation-gre/118370-technote-gre-00.html)。
*   [**Solving Recursive Routing Issues**](https://www.cisco.com/c/en/us/support/docs/ip/generic-routing-encapsulation-gre/13717-49.html)。

---

## 📝 補足

- この学習メモは、GRE トンネルが単なる「設定の成功」ではなく、**「アンダーレイとオーバーレイのルーティング分離」**がいかに重要であるかを強調しています。CCIE ラボ試験では、再帰ルーティングや MTU 問題が発生した際、`show ip route` と `show interface` の出力を比較して、論理的な矛盾を迅速に特定できることが合格への鍵となります。
