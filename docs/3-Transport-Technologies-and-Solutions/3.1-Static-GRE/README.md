---
layout: default
title: 3.1-Static-GRE
parent: 3-Transport-Technologies-and-Solutions
nav_order: 1
---

# 3.1 Static Point-to-Point GRE Tunnels

この学習メモでは、CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目「3.1 Static point-to-point GRE tunnels」について、基礎から CCIE レベルの深い実装・トラブルシューティングまでを網羅します。

---

## 📘 概要

**GRE (Generic Routing Encapsulation)** は、あるネットワーク層プロトコルのパケットを別のネットワーク層プロトコルの中にカプセル化して転送するためのトンネリングプロトコルです。**Static Point-to-Point GRE** は、トンネルの送信元（Source）と宛先（Destination）を静的に固定して設定する最も基本的なトンネル形式です。

マルチキャストトラフィックを直接通せない環境（IPsecのみの拠点間接続など）において、マルチキャストをカプセル化して動的ルーティングプロトコル（OSPFやEIGRP）を動作させるための「仮想的な直結リンク」として多用されます。

---

## 🔑 要点

### 1. GRE カプセル化の構造

GRE は元のパケット（ペイロード）に GRE ヘッダー（通常4バイト）と新しい IP ヘッダー（20バイト）を付加します。
*   **追加オーバーヘッド:** 合計 24 バイト。
*   **プロトコル番号:** 外側の IP ヘッダー内では `47` を使用します。

### 2. トンネルのインターフェイス状態

トンネルが `up/up` になるためには、以下の条件が必要です。
*   トンネルの送信元（`tunnel source`）のアドレスが有効であること。
*   トンネルの宛先（`tunnel destination`）へのユニキャストルートがルーティングテーブルに存在すること。
*   **注意:** 静的 GRE は宛先との疎通（Ping等）が取れなくても、ルートさえあれば `up/up` になります。

### 3. Keepalive メカニズム

静的 GRE は「宛先の消失」を検知できないため、**GRE Keepalive** を設定してトンネルの可用性を監視します。
*   ルータは自身に向けた GRE パケットをカプセル化して送信し、宛先ルータがそれを「剥いて」送り返してくることで生存を確認します。

### 4. 再帰ルーティング (Recursive Routing) の問題

トンネル経由で学習したルートが、トンネルの宛先 IP アドレスへの「最適なパス」として選ばれてしまう現象です。
*   **結果:** トンネルがフラッピング（Up/Downを繰り返す）します。
*   **原因:** トンネルを維持するためのパスを、トンネル自身の中に求めてしまう論理矛盾です。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる開通作業だけでなく、以下の制約条件下での最適化が問われます。

### 1. MTU と TCP MSS の調整

GRE のオーバーヘッド（24バイト）により、1500バイトのパケットはフラグメンテーションが発生します。
*   **対策:** `ip mtu 1476` および `ip tcp adjust-mss 1436` の設定。
*   **試験のポイント:** 「フラグメンテーションを発生させずに転送せよ」という要件に対し、正しい値を計算して適用する能力が必要です。

### 2. 再帰ルーティングの回避手法

試験で動的ルーティングプロトコルを GRE 上で動かす際、必ず直面する問題です。
*   **手法 A:** トンネルの宛先 IP（物理IFやLoopback）をルーティングプロトコルの広報対象から外す。
*   **手法 B:** `tunnel destination` へのスタティックルートを、動的ルートより低い AD 値で設定する。
*   **手法 C:** ルートマップを用いて、宛先 IP の広報をフィルタリングする。

### 3. ループバックを送信元にする利点

物理インターフェイスが複数ある場合、冗長性を確保するために `Loopback` を `tunnel source` に指定することが推奨されます。この際、Loopback 同士の到達性がアンダーレイで確保されている必要があります。

### 4. 冗長構成と再配送

複数の GRE トンネルを介してメイン拠点と接続する場合のパス選定。
*   EIGRP の `delay` 調整や OSPF の `cost` 調整、または BGP の属性操作を用いて、特定のトンネルをプライマリにするタスクが頻出します。

---

## 🛠 設定・検証コマンド

### 基本設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **トンネルIFの作成** | <code>interface Tunnel [ID]</code> |
| **カプセル化の指定（デフォルト）** | <code>tunnel mode gre ip</code> |
| **送信元の指定** | <code>tunnel source [物理IF名 &#124; IPアドレス &#124; Loopback名]</code> |
| **宛先の指定** | <code>tunnel destination [対向の物理IP &#124; Loopback IP]</code> |
| **生存確認の有効化** | <code>keepalive [秒数] [リトライ数]</code> |

### パフォーマンス・最適化コマンド

| 目的 | コマンド |
| :--- | :--- |
| **トンネルMTUの設定** | <code>ip mtu 1476</code> |
| **MSSの自動調整** | <code>ip tcp adjust-mss 1436</code> |
| **帯域幅の明示（ルーティング用）** | <code>bandwidth 1000</code> |
| **遅延の調整（EIGRP用）** | <code>delay 10000</code> |

### 検証・トラブルシューティングコマンド

| 目的 | コマンド |
| :--- | :--- |
| **トンネル状態の確認** | <code>show interface tunnel [ID]</code> |
| **宛先へのパス確認** | <code>show ip route [tunnel_destination_IP]</code> |
| **パケット通過の確認** | <code>traceroute [宛先]</code> |
| **カプセル化のデバッグ** | <code>debug tunnel</code> |
| **Keepaliveの状態確認** | <code>show interface tunnel [ID] &#124; include keepalive</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 基本的な GRE トンネルの開通

**【問題】** R1 と R3 の間に、それぞれの VLAN 13 インターフェイス（R1: 155.1.13.1, R3: 155.1.13.3）を使用して GRE トンネルを構築せよ。トンネル IP は 155.13.0.x/24（xはルータ番号）とする。

**【設定例】**
```ios
! R1
interface Tunnel13
 ip address 155.13.0.1 255.255.255.0
 tunnel source 155.1.13.1
 tunnel destination 155.1.13.3
```

---

### 2. ループバックを送信元とする冗長構成

**【問題】** 送信元 Loopback0 (1.1.1.1) から 宛先 Loopback0 (3.3.3.3) へのトンネルを構成せよ。アンダーレイで Loopback 間のルートが必要。

**【設定例】**
```ios
interface Tunnel0
 ip address 10.0.0.1 255.255.255.252
 tunnel source Loopback0
 tunnel destination 3.3.3.3
```

---

### 3. GRE Keepalive による障害検知

**【問題】** トンネルの両端において、10秒間隔で 3 回の失敗でトンネルを Down させるよう設定せよ。

**【設定例】**
```ios
interface Tunnel0
 keepalive 10 3
```

---

### 4. OSPF を GRE トンネル上で動作させる

**【問題】** トンネルインターフェイスを OSPF Area 0 に所属させ、マルチキャストによる隣接関係を確立せよ。

**【設定例】**
```ios
interface Tunnel0
 ip ospf 1 area 0
! 必要に応じてネットワークタイプを変更
 ip ospf network point-to-point
```

---

### 5. 再帰ルーティング (Recursive Routing) の解消

**【問題】** トンネル上で EIGRP を動かしたところ、トンネルが Down した。宛先 IP (172.16.1.1) を EIGRP から除外せよ。

**【設定例】**
```ios
router eigrp 100
 ! 物理セグメントの広報をやめるか、prefix-listでフィルタ
 distribute-list prefix FILTER_TUNNEL_DEST out
!
ip prefix-list FILTER_TUNNEL_DEST deny 172.16.1.1/32
ip prefix-list FILTER_TUNNEL_DEST permit 0.0.0.0/0 le 32
```

---

### 6. MTU と TCP MSS の最適化 (1400バイト指定)

**【問題】** 特定のアプリケーション要件に基づき、トンネルの IP MTU を 1400、TCP MSS を 1360 に設定せよ。

**【設定例】**
```ios
interface Tunnel0
 ip mtu 1400
 ip tcp adjust-mss 1360
```

---

### 7. GRE over IPsec (Static)

**【問題】** 静的 GRE トンネルを IPsec プロファイルを用いて暗号化せよ。

**【設定例】**
```ios
crypto ipsec profile GRE_IPSEC_PROFILE
 set transform-set MY_SET
!
interface Tunnel0
 tunnel protection ipsec profile GRE_IPSEC_PROFILE
```

---

### 8. IPv6 パケットを IPv4 GRE で運ぶ

**【問題】** IPv4 ネットワークを介して R1 と R3 の IPv6 セグメントを接続せよ。

**【設定例】**
```ios
interface Tunnel10
 ipv6 address 2001:DB8:ACAD:1::1/64
 tunnel source 10.1.1.1
 tunnel destination 10.3.3.3
 tunnel mode gre ip  ! 外側はIPv4
```

---

### 9. 帯域幅 (Bandwidth) の調整によるパス制御

**【問題】** トンネル経由のルートが物理リンクより優先されないよう、トンネルの帯域幅を 100kbps に制限せよ。

**【設定例】**
```ios
interface Tunnel0
 bandwidth 100
```

---

### 10. EIGRP 遅延 (Delay) 操作によるバックアップパス化

**【問題】** トンネルを EIGRP のバックアップパスとして使用するため、ディレイを 100,000 に設定せよ。

**【設定例】**
```ios
interface Tunnel0
 delay 10000  ! 単位は10マイクロ秒（100,000を設定）
```

---

### 11. トンネルキー (Tunnel Key) の設定

**【問題】** 同一のソース・宛先を持つ複数のトンネルを識別するため、キー「12345」を設定せよ。

**【設定例】**
```ios
interface Tunnel1
 tunnel key 12345
```

---

### 12. mGRE への移行準備（物理 IF をソースに）

**【問題】** 将来的な DMVPN への拡張を見越し、トンネルモードをマルチポイント（宛先指定なし）に設定せよ（設定確認用）。

**【設定例】**
```ios
interface Tunnel100
 tunnel mode gre multipoint
 ! static point-to-point では使用しないが、試験での比較対象
```

---

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
