---
layout: default
title: 1.2.i-Routing-protocol-authentication
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 9
---

# 1.2.i-Routing-protocol-authentication

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.i Routing protocol authentication」について整理しました。

---

## 📘 概要

**Routing Protocol Authentication（ルーティングプロトコルの認証）**は、ネットワークのコントロールプレーンを保護するための重要なセキュリティメカニズムです。ルータ間で交換されるルーティングアップデートに認証情報を付加することで、不正なデバイスや攻撃者による偽のルート情報の注入（ルートスプーフィング）を防止します。

認証には主に「クリアテキスト（平文）」と「暗号化ハッシュ（MD5, SHA）」の2種類がありますが、CCIEレベルでは**MD5**および**SHA-256**を用いたセキュアな構成が必須となります。特に、認証の方式がプロトコルの実装モード（例：EIGRP Classic vs. Named Mode）やバージョン（OSPFv2 vs. OSPFv3）によって大きく異なる点、および**Key-Chain（キーチェーン）**を用いた柔軟な管理手法をマスターすることが求められます。

---

## 🔑 要点

### 1. 共通メカニズム：Key-Chain (キーチェーン)
多くのプロトコル（RIP, EIGRP Classic, OSPFv2, IS-IS）では、認証キーを管理するために <code>key chain</code> を使用します。

*   **キーのローテーション:** <code>send-lifetime</code> と <code>accept-lifetime</code> を設定することで、特定の時間に自動的に使用するキーを切り替えることが可能です。
*   **重複期間の設計:** ローテーション時の通信断を防ぐため、古いキーと新しいキーの有効期間を意図的に重複させる設計が推奨されます。

### 2. EIGRP の認証（Classic vs. Named Mode）

EIGRPはモードによってサポートするアルゴリズムが異なります。

| 項目 | Classic Mode | Named Mode (Multi-AF) |
| :--- | :--- | :--- |
| **サポートアルゴリズム** | MD5のみ。 | MD5 および **SHA-256**。 |
| **設定場所** | インターフェイス配下。 | <code>af-interface</code> 配下。 |
| **Key-Chain依存性** | MD5使用時に必須。 | SHA-256使用時は **Key-Chain不要**（パスワード直接指定）。 |

### 3. OSPF の認証（v2 vs. v3）

*   **OSPFv2:** インターフェイス単位、またはエリア全体で有効化できます。MD5が一般的です。
*   **OSPFv3:** 伝統的には IPv6 の **IPsec (ESP/AH)** フレームワークに依存していましたが、最新の IOS XE では OSPFv3 独自の **Trailer-based Authentication** がサポートされており、IPsec 構成なしで SHA 認証が可能です。

### 4. BGP の認証

BGPは TCP 接続（ポート 179）を使用するため、認証は TCP ヘッダーの **TCP MD5 Signature Option (RFC 2385)** を用いて実装されます。Key-Chain は使用せず、ネイバーごとに直接パスワードを指定します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単に「認証を設定せよ」という指示だけでなく、以下のような制約やトラブルシューティングを含むタスクが出題されます。

### 1. EIGRP Named Mode における SHA-256 の優先

「認証に SHA-256 を使用し、かつ Key-Chain の管理オーバーヘッドを排除せよ」という要件が出た場合、EIGRP Named Mode での直接指定（<code>authentication mode hmac-sha-256</code>）が唯一の正解となります。

### 2. キーの段階的ローテーション

「月曜日の 00:00 にキーを更新せよ。その際、隣接関係のダウンを一切許容してはならない」というシナリオ。
*   **戦略:** 新しいルータから順次、新旧両方のキーを受け入れ可能（Accept）にし、全ルータの同期が取れたタイミングで送信キー（Send）を切り替える設定が必要です。

### 3. OSPFv3 Trailer Authentication

最新の試験範囲では、OSPFv3 で IPsec を構成せずに認証を行うタスクが出題される可能性があります。<code>ospfv3 authentication</code> コマンドの構文を正確に把握しておく必要があります。

### 4. 認証不一致のトラブルシューティング

ネイバーが <code>INIT</code> 状態や <code>DOWN</code> 状態で止まっている場合、以下の確認が不可欠です。
*   **Key-IDの一致:** Key-Chain 内の <code>key [number]</code> が両端で一致しているか。
*   **時刻の同期:** ライフタイム設定時、ルータ間の <code>clock</code> が NTP 等で同期されていないと、キーが有効にならず認証に失敗します。
*   **認証モードの確認:** 片方が MD5、もう片方が SHA などの不一致。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Key-Chain作成** | <code>key chain [NAME]</code> / <code>key [ID]</code> / <code>key-string [PW]</code> |
| **EIGRP Classic認証適用** | <code>(config-if)# ip authentication mode eigrp [AS] md5</code> |
| **EIGRP Named認証適用** | <code>(config-router-af-interface)# authentication mode hmac-sha-256 [PASSWORD]</code> |
| **OSPFv2 エリア認証(MD5)** | <code>(config-router)# area [ID] authentication message-digest</code> |
| **OSPFv2 インターフェイス認証** | <code>(config-if)# ip ospf message-digest-key [ID] md5 [KEY]</code> |
| **BGP ネイバー認証** | <code>(config-router)# neighbor [IP] password [STRING]</code> |
| **認証デバッグ (EIGRP)** | <code>debug eigrp packets packets</code> |
| **認証確認 (OSPF)** | <code>show ip ospf interface</code> |
| **Key-Chain状態確認** | <code>show key chain</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. EIGRP Named Mode：SHA-256 によるセキュア認証

**【問題内容】**
R1 と R2 の間で EIGRP AS 100 (Named Mode インスタンス名: "CCIE") を構成している。Key-Chain を使用せずに、SHA-256 アルゴリズムを用いてパスワード "Cisco123" で認証を行え。

**【設定例】**
```ios
! R1 / R2 共通
router eigrp CCIE
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   ! Key-chainを使用せず、直接SHA-256を指定
   authentication mode hmac-sha-256 Cisco123
  exit-af-interface
  network 10.1.12.0 0.0.0.255
```

---

### 2. EIGRP Classic Mode：Key-Chain ローテーション

**【問題内容】**
R1 と R6 において、MD5 認証を構成せよ。セキュリティポリシーにより、2026年8月1日にキー ID 1 からキー ID 2 へ移行する必要がある。移行期間中もネイバーシップを維持せよ。

**【設定例】**
```ios
! R1の設定
key chain EIGRP_KEY
 key 1
  key-string OldPass
  send-lifetime 00:00:00 Jan 1 2026 00:05:00 Aug 1 2026
  accept-lifetime 00:00:00 Jan 1 2026 01:00:00 Aug 1 2026
 key 2
  key-string NewPass
  send-lifetime 00:00:00 Aug 1 2026 infinite
  accept-lifetime 23:00:00 Jul 31 2026 infinite

interface Ethernet0/0
 ip authentication mode eigrp 100 md5
 ip authentication key-chain eigrp 100 EIGRP_KEY
```
**【ポイント】**
<code>accept-lifetime</code> を <code>send-lifetime</code> よりも長く（あるいは重複させて）設定することで、隣接ルータとの切り替えタイミングのズレを吸収します。

---

### 3. OSPFv2：エリア 0 全体での MD5 認証強制

**【問題内容】**
Area 0 に属するすべてのルータにおいて、エリアワイドの MD5 認証を有効にせよ。パスワードは "OSPF_PASS"、Key-ID は 10 とすること。

**【設定例】**
```ios
router ospf 1
 area 0 authentication message-digest

interface GigabitEthernet0/1
 ! エリアで有効化しても、キー自体はインターフェイスで定義が必要
 ip ospf message-digest-key 10 md5 OSPF_PASS
```

---

### 4. OSPFv3：最新の Trailer-based Authentication (IPv6)

**【問題内容】**
R3 と R4 の OSPFv3 接続において、IPsec を使用せずに HMAC-SHA-256 による認証を構成せよ。

**【設定例】**
```ios
! インターフェイス配下で直接設定
interface GigabitEthernet0/1
 ospfv3 1 ipv6 authentication hmac-sha-256 key-id 1 0 CiscoBGP123
```
※ <code>0</code> はパスワードが平文で入力されていることを示します。

---

### 5. BGP：ネイバー認証と TTL Security の併用

**【問題内容】**
eBGP ネイバー (192.168.12.2) との間で MD5 認証を設定し、かつ直接接続されていないルータからの攻撃を防ぐために、BGP TTL Security を適用せよ（ホップ数：1）。

**【設定例】**
```ios
router bgp 65001
 neighbor 192.168.12.2 remote-as 65002
 neighbor 192.168.12.2 password CiscoBGP
 ! TTL Securityを有効にすると、EBGP Multihopは自動で調整される
 neighbor 192.168.12.2 ttl-security hops 1
```

---

### 6. IPv6 EIGRP (EIGRPv6) の認証

**【問題内容】**
IPv6 環境の EIGRP AS 78 において、MD5 認証を Key-Chain "V6_AUTH" を用いて構成せよ。

**【設定例】**
```ios
key chain V6_AUTH
 key 1
  key-string IPv6Pass

interface Serial3/0
 ipv6 authentication mode eigrp 78 md5
 ipv6 authentication key-chain eigrp 78 V6_AUTH
```

---

## 参考リソースリンク

### Configurationガイド
*   [Configuring EIGRP Authentication (Classic/Named Mode)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [OSPFv2 Cryptographic Authentication (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13697-14.html)
*   [OSPFv3 Authentication Trailer (RFC 7166) Configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3-auth.html)

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP is your Friend – BGP for the CCIE Candidates (Security部分)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)
*   [BRKRST-3320: Troubleshooting Routing Protocols (認証の不整合トラブルシュート)](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)

### テクニカルドキュメント・設定例
*   [Neighbor Authentication Checklists for EIGRP, OSPF, and BGP](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)
*   [Key-Chain Rotation and Lifetimes Best Practices](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/116203-q-and-a-eigrp-00.html)

---


## 📝 補足
- この学習メモは、CCIE EIラボ試験における「コントロールプレーンの要塞化」という重要タスクを網羅しています。特に Named Mode EIGRP や OSPFv3 の Trailer 認証といった「現代的な手法」は、従来の試験範囲を超えた深い理解が試されるポイントとなるため、繰り返し実機で設定を確認してください。

