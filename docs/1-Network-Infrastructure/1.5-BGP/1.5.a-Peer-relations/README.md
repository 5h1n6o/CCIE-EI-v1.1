---
layout: default
title: 1.5.a-Peer-relations
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.5.a IBGP and EBGP Peer Relations

CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目 「1.5 BGP」における「1.5.a IBGP and EBGP peer relations」について整理しました。

---

## 📘 概要

**BGP (Border Gateway Protocol)** は、今日のインターネットや大規模エンタープライズネットワークの屋台骨を支える、ポリシー駆動型のパスベクトル型ルーティングプロトコルです。他の IGP（OSPF や EIGRP）が「最短経路」を目指すのに対し、BGP は「自組織のポリシーに基づいた最適なパス」を選択し、膨大なルートを処理できるスケーラビリティを備えています。

BGP の隣接関係（ピアリング）には、同一自律システム（AS）内で行われる **iBGP (Internal BGP)** と、異なる AS 間で行われる **eBGP (External BGP)** の 2 種類が存在します。iBGP はデフォルトで TTL が 255 に設定されており、物理的に離れたルータ間でもピアリングが可能ですが、AS 内部でのループ防止のために「iBGP ピアから学習したルートを他の iBGP ピアに転送しない」というスプリットホライゾンルールが適用されます。一方、eBGP は TTL がデフォルトで 1 であり、直接接続されたリンクを使用することが前提となっています。

CCIE ラボ試験においては、これら基本動作の深い理解を前提として、ピアグループやテンプレートを用いた大規模構成の最適化、動的ネイバーの確立、4 バイト AS 番号の運用、およびプライベート AS の管理といった、実戦的かつ高度な設計・実装能力が問われます。

---

## 🔑 要点

### 1. Peer Groups と Peer Templates (i)

大規模な BGP ネットワークでは、多数のネイバーに対して同じポリシーを適用する必要があります。

*   **Peer Groups:** 共通の `address-family` 設定やルートマップを一つのグループにまとめ、管理を簡素化します。ルータの CPU 負荷を軽減する効果（Update 生成の共通化）もあります。
*   **Peer Templates:** 最新の IOS-XE で推奨される方式で、**Session Template**（接続パラメータ）と **Policy Template**（ルート処理パラメータ）の 2 種類に分かれます。
    *   **Inheritance（継承）:** テンプレートは他のテンプレートを継承できるため、peer-group よりもさらに柔軟な階層設計が可能です。

### 2. Active と Passive の制御 (ii)

通常、BGP ピアリングは両端のルータが TCP ポート 179 を使用してコネクションを開始しようとします。

*   **neighbor [IP] transport connection-mode passive:** このコマンドを設定されたルータは、自分から TCP SYN を送らず、相手からの接続を待ち受けます。
*   **用途:** どちらが TCP 接続の主導権を握るかを制御したい場合や、ファイアウォール越しにセッションを張る際の設定簡略化に使用されます。

### 3. BGP Timers (iii)

BGP の障害検知はデフォルトでは比較的低速です。

*   **Keepalive Timer:** ピアが生存していることを確認するパケット。デフォルトは 60 秒。
*   **Hold Timer:** この時間内に Keepalive が届かない場合にピアがダウンしたと判定する時間。デフォルトは 180 秒（Keepalive の 3 倍）。
*   **交渉:** セッション確立時に、両端で設定されている Hold タイムのうち、**低い方の値**が採用されます。

### 4. Dynamic Neighbors (iv)

特定の IP アドレスを個別に `neighbor` コマンドで指定する代わりに、特定のサブネット範囲からのピアリング要求を動的に受け入れる機能です。

*   **bgp listen range [Subnet]:** 指定された範囲からの接続を許可します。
*   **用途:** ルートリフレクタ (RR) において、多数のクライアントからの接続を一台ずつ設定する手間を省く際に有効です。

### 5. 4-byte AS Numbers (v)

2 バイト（1 ～ 65535）の AS 番号の枯渇に対応するため、32 ビット（最大約 42 億）の AS 番号が導入されました。

*   **表記形式:** 
    *   **ASPLAIN:** `65536` のように 10 進数で表記する形式。
    *   **ASDOT:** `1.0` のように 2 バイトずつドットで区切る形式。
*   **互換性:** 4 バイト AS 未対応の古いルータに対しては、予約済みの AS 番号 `23456` (AS_TRANS) を使用して情報を渡します。

### 6. Private AS Numbers (vi)

インターネット上では広告できない、組織内部やラボ環境でのみ使用される番号です。

*   **範囲:** 64512 ～ 65535 (2 バイトの場合)。
*   **処理:** 公衆網（インターネット）へルートを出す際、`remove-private-as` コマンドを使用して AS_PATH からこれらを削除することが必須となります。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる設定だけでなく、「なぜセッションが張れないのか」というトラブルシューティングや、高度な制約条件付きの実装が課されます。

### 1. ネクストホップ解決の罠

iBGP において、eBGP ピアから学習したルートを他の iBGP ネイバーに伝える際、**ネクストホップアドレスは書き換えられません**。
*   **解決策:** `neighbor [IP] next-hop-self` を設定するか、IGP で eBGP 間の物理リンクアドレスを広報する必要があります。

### 2. ループバックインターフェイスの使用

安定性のために BGP ピアリングを Loopback アドレスで行う場合、以下の 2 点が必須です。
*   **Update-source:** `neighbor [IP] update-source Loopback0` で、送信元 IP を一致させる。
*   **EBGP Multihop:** eBGP で Loopback を使用する場合、TTL が 1 では到達できないため `neighbor [IP] ebgp-multihop 2` 等の設定が必要です。

### 3. スプリットホライゾンの回避 (RR / Confederation)

iBGP のフルメッシュ構成が不可能な大規模環境では、以下のどちらかの実装が求められます。
*   **Route Reflector (RR):** 特定のルータにルートを反射させる役割を持たせる。
*   **Confederation:** 大きな AS を「サブ AS」に分割し、内部では eBGP のように振る舞わせる。

### 4. 認証の強制

ラボ試験では、ネイバー間の MD5 認証（パスワード設定）がタスクに含まれることが多々あります。
*   **確認:** `show ip bgp neighbors` の出力で、認証が有効になっているかを確認します。

---

## 🛠 設定・検証コマンド

### BGP 基本設定 (Address-Family モード)

| 目的 | コマンド |
| :--- | :--- |
| **BGPプロセス起動** | <code>router bgp [AS_NUMBER]</code> |
| **ネイバー指定(接続)** | <code>neighbor [IP] remote-as [AS]</code> |
| **AF配下での有効化** | <code>address-family ipv4 unicast</code> <br> <code>neighbor [IP] activate</code> |
| **送信元をLoopbackに固定** | <code>neighbor [IP] update-source [Interface]</code> |
| **eBGPマルチホップ設定** | <code>neighbor [IP] ebgp-multihop [HOP_COUNT]</code> |

### スケーラビリティ・最適化設定

| 目的 | コマンド |
| :--- | :--- |
| **Peer-group 作成** | <code>neighbor [NAME] peer-group</code> |
| **Template 作成(Session)** | <code>template bgp session [S_NAME]</code> |
| **Template 適用** | <code>neighbor [IP] inherit bgp session [S_NAME]</code> |
| **動的ネイバー許可** | <code>bgp listen range [Subnet] peer-group [NAME]</code> |
| **パッシブモード設定** | <code>neighbor [IP] transport connection-mode passive</code> |

### 属性操作・セキュリティ

| 目的 | コマンド |
| :--- | :--- |
| **ネクストホップの自己書換** | <code>neighbor [IP] next-hop-self</code> |
| **認証パスワード設定** | <code>neighbor [IP] password [STRING]</code> |
| **プライベートAS削除** | <code>neighbor [IP] remove-private-as</code> |
| **タイマー設定(K/H)** | <code>neighbor [IP] timers [Keepalive] [Holdtime]</code> |
| **4バイトAS表記変更** | <code>(config-router)# bgp asnotation dot</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **ピア概要表示(最重要)** | <code>show ip bgp summary</code> |
| **特定ピアの詳細(タイマー等)** | <code>show ip bgp neighbors [IP]</code> |
| **BGPテーブルの確認** | <code>show ip bgp</code> |
| **広報しているルートの確認** | <code>show ip bgp neighbors [IP] advertised-routes</code> |
| **受信しているルートの確認** | <code>show ip bgp neighbors [IP] routes</code> |
| **状態遷移のデバッグ** | <code>debug ip bgp [neighbor] events</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. Loopback インターフェイスを使用した iBGP ピアリング

**【問題内容】**
AS 100 内の R1 と R2 において、Loopback 0 アドレスを使用して iBGP セッションを確立せよ。

**【設定例】**
```ios
! R1
router bgp 100
 neighbor 2.2.2.2 remote-as 100
 neighbor 2.2.2.2 update-source Loopback0
 address-family ipv4 unicast
  neighbor 2.2.2.2 activate

! R2
router bgp 100
 neighbor 1.1.1.1 remote-as 100
 neighbor 1.1.1.1 update-source Loopback0
 address-family ipv4 unicast
  neighbor 1.1.1.1 activate
```

---

### 2. eBGP Multihop とピアリング認証

**【問題内容】**
R3 (AS 3) と R5 (AS 65001) の間で eBGP を確立せよ。Loopback アドレスを使用し、パスワード「ccie_lab」で保護すること。

**【設定例】**
```ios
! R3
router bgp 3
 neighbor 10.1.5.5 remote-as 65001
 neighbor 10.1.5.5 ebgp-multihop 2
 neighbor 10.1.5.5 update-source Loopback0
 neighbor 10.1.5.5 password ccie_lab
```

---

### 3. Peer-group を用いた iBGP フルメッシュの簡素化

**【問題内容】**
R1 において、他の 7 台のルータに対する共通設定（AS 番号、update-source、next-hop-self）を `IBGP_CORE` というグループで管理せよ。

**【設定例】**
```ios
router bgp 100
 neighbor IBGP_CORE peer-group
 neighbor IBGP_CORE remote-as 100
 neighbor IBGP_CORE update-source Loopback0
 neighbor IBGP_CORE next-hop-self
 ! 個別ネイバーへの適用
 neighbor 10.1.2.2 peer-group IBGP_CORE
 neighbor 10.1.3.3 peer-group IBGP_CORE
```

---

### 4. Dynamic Neighbors (BGP Listen) の構成

**【問題内容】**
ルートリフレクタ R9 において、`10.1.1.0/24` のサブネット内の全ルータからの iBGP 接続を動的に受け入れるように設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor DYNAMIC_CLIENTS peer-group
 neighbor DYNAMIC_CLIENTS remote-as 100
 ! サブネット範囲とグループの紐付け
 bgp listen range 10.1.1.0/24 peer-group DYNAMIC_CLIENTS
```

---

### 5. Peer Templates による高度な階層設定

**【問題内容】**
AS 200 において、セッション用のテンプレート `S_IBGP` を作成し、それを継承してポリシー設定を適用せよ。

**【設定例】**
```ios
router bgp 200
 template bgp session S_IBGP
  remote-as 200
  update-source Loopback0
 exit-peer-policy
 ! ネイバーへの適用
 neighbor 10.2.2.2 inherit bgp session S_IBGP
```

---

### 6. eBGP における Private AS 番号の削除

**【問題内容】**
ISP ルータ R10 が、プライベート AS 65111 を使用している顧客 R11 から学習したルートを上位へ広報する際、プライベート AS 番号を削除して広報せよ。

**【設定例】**
```ios
router bgp 10
 neighbor 10.10.10.1 remote-as 11
 address-family ipv4 unicast
  neighbor 10.1.1.2 remote-as 20
  neighbor 10.1.1.2 remove-private-as
```

---

### 7. タイマーの微調整（高速障害検知）

**【問題内容】**
特定のネイバー 10.1.12.2 に対し、Keepalive を 10 秒、Hold タイムを 30 秒に設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor 10.1.12.2 timers 10 30
```

---

### 8. Passive ピアリングの実装

**【問題内容】**
R4 において、ネイバー 10.1.45.5 からの TCP 接続は受け入れるが、自分からは接続を開始しないように設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor 10.1.45.5 transport connection-mode passive
```

---

### 9. 4-byte AS 番号の表記変更 (ASDOT)

**【問題内容】**
AS 65536 を `1.0` というドット表記で表示し、運用するように設定せよ。

**【設定例】**
```ios
router bgp 65536
 bgp asnotation dot
```

---

### 10. iBGP における Next-Hop-Self の一括適用

**【問題内容】**
iBGP ピアグループ `RR_CLIENTS` に対し、外部ルート広報時の到達性を確保するためネクストホップを自身の Loopback アドレスに書き換えるよう設定せよ。

**【設定例】**
```ios
router bgp 100
 neighbor RR_CLIENTS peer-group
 address-family ipv4 unicast
  neighbor RR_CLIENTS next-hop-self
```

---

### 11. IPv6 BGP (MP-BGP) ピアリング

**【問題内容】**
IPv6 環境で eBGP セッションを確立し、IPv6 アドレスファミリーを有効化せよ。

**【設定例】**
```ios
router bgp 100
 neighbor 2001:DB8::2 remote-as 200
 address-family ipv6 unicast
  neighbor 2001:DB8::2 activate
```

---

### 12. BGP over GRE トンネル

**【問題内容】**
物理的に直接接続されていない R7 と R8 の間で、GRE トンネルを介して eBGP ピアリングを確立せよ。

**【設定例】**
```ios
! R7
interface Tunnel0
 ip address 172.16.78.7 255.255.255.0
 tunnel source GigabitEthernet1
 tunnel destination 10.1.1.8
!
router bgp 100
 neighbor 172.16.78.8 remote-as 200
 ! トンネル経由なので直接接続とみなされ、ebgp-multihopは不要な場合が多い
```

---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - CCIE 受験者向けの BGP 深掘り解説。
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - BGP セッション確立のトラブル解決。

### Configurationガイド
*   [Cisco BGP Overview - BGP Configuration Guide](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/cisco_bgp_overview.html)。
*   [Configuring Internal BGP Features](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-int-features.html)。

### テクニカルドキュメント・設定例
*   [BGP Case Studies - Peer Relationships](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)。
*   [BGP Attributes: Atomic Aggregate and AS_SET](http://www.networkers-online.com/blog/2010/12/bgp-attributes-atomic-aggergate-atribute/)。

---

## 📝 補足
- この学習メモは、BGP の「入口」であるピアリングという土台を、CCIE ラボ試験の要求レベルに合わせて詳細化したものです。特に iBGP のループ防止ルールと eBGP マルチホップの設計は、トポロジ全体の到達性に直結するため、完璧な理解が求められます。


