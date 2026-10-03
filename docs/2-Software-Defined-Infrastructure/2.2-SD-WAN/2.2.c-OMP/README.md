---
layout: default
title: 2.2.c-OMP
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 3
---

# 2.2.c Overlay Management Protocol (OMP)

## 📘 概要

Overlay Management Protocol（OMP）は、Cisco SD-WAN（旧 Viptela）アーキテクチャの中核をなすコントロールプレーンプロトコルであり、vSmart コントローラと WAN Edge（cEdge / vEdge）デバイス間、あるいは vSmart 相互間で制御情報を交換するために専用開発された BGP ライクな制御プロトコルです。

従来の WAN では、各拠点間での暗号化トンネル（IPsec）構築やルート交換に IKE/IPsec ピアリングおよび Dynamic Routing Protocol（BGP/OSPF）のメッシュ化が必要であり、拠点の増加に伴って制御プレーンの複雑性が N^2 のオーダーで膨れ上がっていました。OMP はコントロールプレーンを中央の vSmart に完全集約することで、拠点ルータ同士が直接コントロールプレーンを確立することなく、Overlay 網全体のコントロールプレーン制御、データプレーン鍵交換、ポリシー適用、およびセグメンテーション（VPN 分離）を一括提供します。

主な利用目的と場面：
* **Overlay ルーティング情報の集約と同期:** 各拠点の LAN 側（Service VPN）のプレフィックス情報を vSmart に集約し、最適なオーバーレイルート（vRoute）を全拠点に安全に配布します。
* **データプレーン暗号化鍵の配布 (IPsec Key Management):** 各 WAN Edge がローカルで自動生成した Diffie-Hellman パブリックキーおよび IPsec エントロピーキーを OMP 経由で vSmart に送信し、vSmart が対象 WAN Edge へ再配布することで、WAN Edge 間での IKE ハンドシェイクを不要にし、フルメッシュ/ハブ＆スポーク IPsec トンネルの高速構築を実現します。
* **トランスポートエンドポイント（TLOC）の追跡:** アンダーレイネットワーク（VPN 0）の物理/論理接続ポイントである TLOC（System IP, Color, Encapsulation）情報を共有し、データプレーンの宛先アドレスを同期します。
* **サイト間・VPN 間のセグメンテーションとポリシー適用:** サービスルート（Service Route）やコモン属性を制御し、Firewall などのサービスチェイニングや Direct Internet Access（DIA）、マルチ VRF セグメンテーションを実現します。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | Centralized Control Plane プロトコル。TCP ポート 12346（または 12347〜）上の TLS/DTLS セッション内で動作。BGP に類似したパスベクトル型アルゴリズムを採用し、自動フルメッシュ/トポロジー制御を実現。 |
| **用途** | vRoutes（LANプレフィックス）、TLOCs（WANインターフェイス属性）、Services（FW/IPS/NAT等）、および IPsec 鍵情報の安全な伝搬と一元管理。 |
| **メリット** | 拠点間での IKE ピアリングおよびフルメッシュ Dynamic Routing（BGP/OSPF）が不要。コントローラ集中型のポリシー（Centralized Policy）により、数千拠点のトポロジー切り替えやトラフィックコントロールをワンタッチで実現。 |
| **デメリット** | vSmart コントローラへのコントロールプレーン依存度が高い（ただし vSmart 全滅時も既存データプレーンは Graceful Restart により継続維持可能）。 |
| **対応機種** | Cisco Catalyst 8000V, C8200, C8300, C8500, ISR4000, ASR1000 シリーズ（cEdge）、および vEdge 100/1000/2000/5000 シリーズ。 |
| **制限事項** | OMP は WAN Edge 相互間では直接動作しない（必ず vSmart とのピアリングが必要）。デフォルトの送信・受容パス制限（デフォルト `ecmp-limit 4`, `send-path-limit 4`, `send-backup-paths`）が存在し、大規模構成ではチューニングが必須。 |
| **設計上の注意点** | サービス VPN と LAN 側 routing（BGP/OSPF）間の再配送（Redistribution）では、ループ防止タグや BGP AS_PATH 伝搬（`propagate-aspath`）の正しい理解が必須。SD-Access 統合時には SGT 属性（SAD/SGT）の OMP 伝搬要件を考慮する。 |

---

## 🏗 動作原理

OMP は、SD-WAN オーバーレイのコントロールプレーンにおいて 3 種類の主要なルート（Update）タイプを取り扱います。

```
                    +-------------------+
                    | vSmart Controller |
                    +---------+---------+
                              | OMP (DTLS/TLS)
            +-----------------+-----------------+
            |                                   |
            v                                   v
    +---------------+                   +---------------+
    | WAN Edge A    | <== IPsec SA ===> | WAN Edge B    |
    | (Site ID 100) |   (Data Plane)    | (Site ID 200) |
    +---------------+                   +---------------+
      LAN: VPN 10                         LAN: VPN 10
    172.16.10.0/24                      172.16.20.0/24
```

### OMP が伝搬する 3 大ルートタイプ

1. **OMP Routes (vRoutes):**
   * 各 WAN Edge の Service VPN（LAN 側）で学習した IP プレフィックス情報。
   * BGP の NLRI（Network Layer Reachability Information）に相当し、宛先 TLOC、Preference、Tag、Origin Protocol、Origin Metric などの属性（OMP Attributes）を伴います。
2. **TLOC Routes (Transport Location Routes):**
   * 各 WAN Edge の Transport VPN（VPN 0）に位置する WAN インターフェイスのアタッチポイント情報。
   * **System IP ＋ Color ＋ Encapsulation** の三つ組（3-tuple）で一意に識別され、Public/Private IP アドレス、Public/Private UDP ポート、IPsec SPI キー、Public Key（Diffie-Hellman パブリックキー）、Weight、Preference などの物理/論理接続パラメータを保持します。
3. **Service Routes:**
   * 拠点で利用可能なネットワークサービス（Firewall, IPS, Load Balancer, Connected/Static 固有サービス）をネットワーク全体に広告するルート。
   * 「VPN X 内の Service FW は TLOC Y に存在する」という情報を vSmart 経由で共有し、サービスチェイニング（Service Chaining）を実現します。

---

## ⚙ 動作シーケンス

### OMP セッションの確立と IPsec Key 制御フロー

```
[ WAN Edge A ]                 [ vSmart ]                 [ WAN Edge B ]
      |                            |                            |
      |--- 1. DTLS/TLS 確立 ------->|                            |
      |    (vBond の仲介後)        |<-- 2. DTLS/TLS 確立 -------|
      |                            |                            |
      |--- 3. OMP Peer Up -------->|                            |
      |    (Open / Handshake)      |<-- 4. OMP Peer Up ---------|
      |                            |                            |
      |--- 5. OMP Update --------->|                            |
      |    - TLOC Route (A)        |                            |
      |      (Public Key A, SPI A) |                            |
      |    - OMP Route (172.16.10.0)                            |
      |                            |--- 6. OMP Update --------->|
      |                            |    - TLOC Route (A)        |
      |                            |    - OMP Route (172.16.10.0)|
      |                            |                            |
      |                            |<-- 7. OMP Update ----------|
      |                            |    - TLOC Route (B)        |
      |                            |      (Public Key B, SPI B) |
      |                            |    - OMP Route (172.16.20.0)|
      |<-- 8. OMP Update ----------|                            |
      |    - TLOC Route (B)        |                            |
      |    - OMP Route (172.16.20.0)|                            |
      |                            |                            |
      |================== 9. Direct IPsec Tunnel =================|
      |    (Data Plane: AES-256-GCM / DH Group 16/19 鍵を直接交換せず|
      |     vSmart 経由で交換した情報をもとに即時トンネル形成)     |
```

### パケット処理および暗号キー生成シーケンス

1. **コントロールプレーン確立:** WAN Edge A と B は vBond による認証・仲介を受けた後、vSmart との間に安全な DTLS/TLS 制御トンネルを確立し、OMP セッションを Open 状態にします。
2. **ローカル鍵生成:** 各 WAN Edge はローカルで AES-GCM/CBC 用の IPsec SA 鍵（SPI / Symmetric Key）および Diffie-Hellman 鍵対を独自に生成します。IKE のような対向との 6 パケット / 3 パケット交渉（Phase 1 / Phase 2）は一切行いません。
3. **TLOC ＆ OMP ルートのアドバタイズ:** WAN Edge A は自身の TLOC 属性（Public/Private IP/Port, SPI, DH Public Key）および OMP ルート（172.16.10.0/24）を vSmart へ OMP Update パケットで送信します。
4. **vSmart による計算と再配布:** vSmart は受信した OMP/TLOC ルートに対して Centralized Control Policy を評価・適用した上で、許可された情報を WAN Edge B へ転送します。
5. **即時 IPsec データトンネル形成:** WAN Edge B は vSmart から届いた WAN Edge A の TLOC 属性（Public IP/Port, SPI, DH Public Key）を復号・展開し、即座に WAN Edge A 宛ての暗号化 IPsec データトンネルをデータプレーン上で起動（Up）します。

---

## 🎯 試験対策（CCIE EIラボ試験）

### Blueprint で最も重要となるポイント
CCIE EI Practical Lab 試験において、OMP は単なるデフォルト動作の確認にとどまらず、複雑なルーティング要件、再配送ループ防止、属性操作、および他技術統合の試験ポイントとして出題されます。

1. **OMP ベストパス選定アルゴリズムの絶対順序 (Best Path Selection):**
   * ルート受信後、以下の優先順位に従って単一のベストパス（または ECMP パス）を選定します。
     1. **Validity:** OMP ルートが Valid 状態（TLOC が Reachable であること）
     2. **OMP Preference:** `omp preference <0-4294967295>`（数値が高い方が優先、デフォルト 0）
     3. **TLOC Preference:** 紐づく TLOC の `tloc-preference`（数値が高い方が優先、デフォルト 0）
     4. **Origin Protocol Metric / Path Type:** 内部生成（Connected > Static > BGP > OSPF 内 > OSPF 外）
     5. **Origin Protocol Metric:** ドメイン内オリジナルメトリックの低い方
     6. **Originator System IP:** System IP アドレスの大きい（または小さい）一意順序
2. **OMP 経路再配送（Redistribution）とループ防止:**
   * **LAN ➔ OMP:** Service VPN（VPN 1〜511）内の Connected, Static, OSPF, BGP 経路を OMP へ再配送（`sdwan -> omp -> advertise`）。
   * **OMP ➔ OSPF/BGP:** OMP で学習した経路を LAN 側の動的ルーティングプロトコルへ再配送。
   * **OSPF Route Tag / Down-bit によるループ防止:** OMP 制御下の cEdge ルータ群で LAN 側 OSPF への再配送を行う場合、デフォルトで自動付与される **OMP Route Tag（1088 または計算値）** および Down-bit（DN Bit）の仕組みを理解していないと、Mutual Redistribution 時に同一拠内で再流入ループが発生します。
3. **OMP Route Aggregation（集約ルート）の挙動:**
   * `sdwan -> omp -> aggregate <prefix>` による経路集約。
   * **`as-set` オプション** や **`summary-only`** の動作。集約ルートがアドバタイズされる際、構成要素（Specific routes）がデフォルトで抑制されるか否か、および Aggregator アトリビュートの生成。
4. **Additional Features (BGP AS Path Propagation & SD-Access Integration):**
   * **BGP AS Path Propagation:** eBGP 網を介して SD-WAN オーバーレイを跨ぐ場合、OMP はデフォルトで BGP AS_PATH 属性を隠蔽（消去）します。`propagate-aspath` コマンドを有効化することで、OMP ルート内に BGP AS_PATH 情報を保持・伝搬させ、ルータ間での BGP 思考ルーティングループを防止します。
   * **SDA Integration (Cisco SD-Access 連携):** SD-Access ファブリックの Security Group Tag（SGT）を OMP パケットのデータ構造に含めて SD-WAN 網越えでカプセル化・伝搬させる要件。

---

## 🛠 設定方法

### 1. OMP 基本パラメータおよびタイマー調整 (cEdge CLI)

```text
sdwan
 omp
  no shutdown
  graceful-restart
  send-path-limit 8
  ecmp-limit 8
  graceful-restart-timer 43200
  holdtime 60
  advertisement-interval 1
  no timers eor
  address-family ipv4 unicast
   advertise connected
   advertise static
   advertise ospf external
   advertise bgp
  !
!
```

### 2. OMP 経路集約 (Route Aggregation) の設定

```text
sdwan
 omp
  address-family ipv4 unicast
   aggregate 10.100.0.0/16 summary-only
  !
!
```

### 3. BGP AS Path 伝搬 (AS Path Propagation) の設定

```text
sdwan
 omp
  propagate-aspath
!
```

### 4. OMP ➔ OSPF / BGP 再配送の設定 (Service VPN 10)

```text
router ospf 10 vrf 10
 redistribute omp subnets route-map OMP->OSPF
!
route-map OMP->OSPF permit 10
 set metric 20
 set metric-type type-2
!
router bgp 65010 vrf 10
 address-family ipv4 unicast
  redistribute omp route-map OMP->BGP
 exit-address-family
!
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| OMP ピアリング状態の確認 | `show sdwan omp peers` |
| 学習した OMP ルート（vRoutes）の確認 | `show sdwan omp routes` |
| 受信した TLOC ルートの確認 | `show sdwan omp tlocs` |
| 受信した Service ルートの確認 | `show sdwan omp services` |
| OMP サマリー・統計・タイマー情報の確認 | `show sdwan omp summary` |
| 特定プレフィックスの OMP 属性詳細確認 | `show sdwan omp routes 10.100.0.0/16 detail` |
| IPsec 鍵情報（SPI, Public Key）の確認 | `show sdwan ipsec outbound-connections` |
| OMP 制御パケットのデバッグログ | `debug sdwan omp` / `show logging` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| OMP ピアリングが Up しない（`Init` / `Handshake` で停滞） | vSmart 宛ての DTLS/TLS コントロールセッションが確立していない。System IP 重複または Cert 認証失敗。 | `show sdwan control connections`<br><code>show sdwan omp peers</code> | vSmart 宛の IP 通信、証明書状態、および `system-ip` / `site-id` の整合性を確認。 |
| OMP ルートが宛先ルータの RIB（`show ip route vrf X`）に注入されない | OMP ルートは受信しているが TLOC が Unreachable（Invalid）状態である。または Distance 設定の問題。 | `show sdwan omp routes`<br><code>show ip route vrf 10</code> | `show sdwan omp routes` で State が `C,I`（Invalid）になっていないか確認。対向 TLOC への IPsec BFD トンネルが Up しているか検証。 |
| 拠点間の再配送時にルーティングループが発生・ルートが消滅する | OMP ➔ OSPF 再配送時に OMP Route Tag が正しく処理されず、別ルータから OSPF 経由で再流入している。 | `show ip ospf database`<br><code>show sdwan omp routes</code> | OMP ➔ OSPF 再配送時のタグ割り当て（デフォルト 1088）および OSPF 側の `tag` フィルタリング条件を修正。 |
| eBGP 網を挟んだ SD-WAN 拠点間で AS ループが発生しルートが拒否される | OMP 経由で BGP AS_PATH 属性が欠落し、再配送時に対向の自 AS 番号が付与されて AS-Path Loop に陥る。 | `show ip bgp vrf X`<br><code>show sdwan omp routes detail</code> | `sdwan -> omp -> propagate-aspath` コマンドを有効化し、BGP AS_PATH を OMP パケット内で保持・伝搬させる。 |
| 大規模拠点でロードバランス（ECMP）が 4 経路までに制限される | デフォルトの OMP `ecmp-limit` が 4 に設定されている。 | `show sdwan omp summary` | `sdwan -> omp -> ecmp-limit 8`（最大 16）へ変更し、マルチパス設定を拡張。 |

---

## ⚠ 制限事項

* **OMP ピアリング制限:** WAN Edge 同士で OMP ピアリングを直接組むことは不可能。すべての OMP コントロール通信は vSmart 経由で仲介される。
* **ECMP & Path Limit:** デフォルトで `ecmp-limit` は 4。最大 16 パスまで拡張可能だが、ルータのハードウェア・メモリリソースおよび IPsec SA 保持数に影響を与える。
* **再配送の方向性:** LAN 側プロトコルから OMP への自動再配送は行われない。`sdwan -> omp -> address-family ipv4 -> advertise <protocol>` による明示的な許可設定が必須。
* **BGP AS_PATH 隠蔽動作:** デフォルトでは OMP は BGP 属性の大部分（MED, Local Pref 等）を標準で透過せず、OMP 独自の Preference / Metric に変換する。AS_PATH を保持するには明示的に `propagate-aspath` が必要。

---

## 🔄 他技術との関連

* **Cisco SD-Access (SDA) 統合:**
  * SD-Access ファブリックの Fabric Border ルータと SD-WAN WAN Edge を統合（Co-located Border/cEdge）する場合、SD-Access 内の SGT（Security Group Tag）情報を SD-WAN オーバーレイで透過送信する必要がある。
  * OMP は SGT 属性を OMP Update 内の拡張コミュニティ（SAD/SGT）としてカプセル化・伝搬し、対向拠点の SD-Access ファブリック側で正しく SGT を復元できるように機能する。
* **IPsec & BFD Data Plane:**
  * OMP が TLOC ルートおよび IPsec キー情報（SPI, DH Public Key）を同期させることで、WAN Edge 間での IKE ハンドシェイクなしで IPsec トンネルが自動形成される。形成された IPsec トンネル上では即座に BFD プロトコルが起動し、回線品質（遅延・ジッター・パケットロス）をミリ秒単位で測定する。
* **OSPF / BGP LAN-side Routing:**
  * Service VRF 内の LAN 側ルーティングプロトコル（OSPF/BGP）と OMP 間の双方向再配送において、互いの Administrative Distance（OMP Admin Distance: デフォルト 250 / OMP External: 250）やループ防止用 Down-bit, Route Tag の相互作用が極めて重要となる。

---

## 🧩 比較表

### OMP vs BGP (Border Gateway Protocol)

| 比較項目 | OMP (Overlay Management Protocol) | BGP (Border Gateway Protocol) |
| :--- | :--- | :--- |
| **設計目的** | SD-WAN コントローラ型オーバーレイの制御・暗号化鍵共有・TLOC 管理 | インターネットおよび広域 IP/MPLS 網の自律システム間ルーティング |
| **トポロジー** | vSmart を頂点とする Star（Hub-and-Spoke）コントロールプレーン | ピア相互間の Mesh / Hop-by-Hop コントロールプレーン |
| **トランスポート** | DTLS / TLS（TCP 12346 / UDP 12346）暗号化トンネル内 | TCP ポート 179 |
| **主な伝搬情報** | vRoutes（IPプレフィックス）, TLOCs（物理属性/鍵）, Services（FW/NAT等） | NLRI（IPプレフィックス）, BGP パス属性（AS_PATH, MED, Community等） |
| **暗号鍵の動的交換** | IPsec SA SPI 鍵および DH パブリックキーを自動分散伝搬 | 標準不可（MACsec や IPsec 設定が別途必須） |
| **ルート選定優先度** | Validity ➔ OMP Pref ➔ TLOC Pref ➔ Origin Protocol ➔ Metric ➔ System IP | Weight ➔ Local Pref ➔ Local Orig ➔ AS_PATH ➔ Origin ➔ MED ➔ eBGP/iBGP |

---

## 💡 ベストプラクティス

1. **OMP Send/Receive Path Limit の最適化:**
   * 多重マルチホーム拠点（3 以上の WAN 回線）や大規模 Hub-and-Spoke 環境では、`send-path-limit` および `ecmp-limit` をデフォルトの 4 から 8 以上に拡張し、パスの不適切な抑制を防止する。
2. **Graceful Restart (GR) の有効化維持:**
   * vSmart コントローラのメンテナンスや一時的なコントロール通信断に備え、`graceful-restart`（デフォルト有効、タイマー 12 時間）を維持し、データプレーン（IPsec）の無停止運用を担保する。
3. **BGP 相互接続時の `propagate-aspath` の適用:**
   * 既存の企内部 BGP 網や eBGP トランジット網と SD-WAN を接合する場合は、必ず `propagate-aspath` を有効化し、BGP AS_PATH の欠落に伴うルーティングループや非対称パスを未然に防止する。
4. **再配送ループ防止用 Route Tag の標準化:**
   * OMP ➔ OSPF 再配送時の Route Tag（デフォルト 1088）を組織内で標準化し、同一 Service VRF 内のマルチホーム cEdge で相互流出が発生しないよう Route-Map で制御する。

---

## 📝 ラボ学習・設定サンプル例

### サンプル 1: OMP 基本設定とタイマーチューニング

* **問題:** cEdge-1 の OMP セッションパラメータを設定し、Holdtime を 60 秒、Graceful Restart タイマーを 43200 秒に設定し、パス制限を 8 に拡張しなさい。
* **要件:**
  * OMP Holdtime: 60 秒
  * Graceful Restart: 有効（Timer: 43200 秒）
  * `send-path-limit` および `ecmp-limit`: 8
* **設定例:**

```text
sdwan
 omp
  no shutdown
  holdtime 60
  graceful-restart
  graceful-restart-timer 43200
  send-path-limit 8
  ecmp-limit 8
!
```

* **検証方法:**
  `show sdwan omp summary` を実行し、Holdtime および Path Limit の値が正しく 60 および 8 に変更されていることを確認する。

---

### サンプル 2: Service VPN 10 内の Connected / Static ルートの OMP 広告

* **問題:** cEdge-1 の Service VPN 10 に存在する Connected および Static ルートを OMP 経由で vSmart へアドバタイズしなさい。
* **要件:**
  * VPN 10 の Connected プレフィックスおよび Static プレフィックスを自動的に OMP へ広告する。
* **設定例:**

```text
sdwan
 omp
  address-family ipv4 unicast
   advertise connected
   advertise static
  !
!
```

* **検証方法:**
  `show sdwan omp routes` を実行し、VPN 10 の Connected / Static 経路の Origin Protocol が `connected` / `static` として `C,Red,AttrSet` 状態になっていることを確認する。

---

### サンプル 3: OMP 経路集約 (Route Aggregation) の構成

* **問題:** 拠点 A（cEdge-1）の LAN 側から学習した `10.1.1.0/24`, `10.1.2.0/24`, `10.1.3.0/24` の個別の経路を OMP 経由で他拠点へ広告せず、集約ルート `10.1.0.0/16` のみをアドバタイズしなさい。
* **要件:**
  * 集約プレフィックス: `10.1.0.0/16`
  * 個別ルート（Specific routes）は完全に抑制する (`summary-only`)。
* **設定例:**

```text
sdwan
 omp
  address-family ipv4 unicast
   aggregate 10.1.0.0/16 summary-only
  !
!
```

* **検証方法:**
  対向拠点の cEdge で `show sdwan omp routes` を実行し、`10.1.0.0/16` のみが受信され、個別サブネット `/24` が存在しないことを検証する。

---

### サンプル 4: BGP AS Path 伝搬 (AS Path Propagation) の有効化

* **問題:** SD-WAN オーバーレイを跨いで eBGP ルーティング情報を伝搬させる際、BGP AS_PATH 属性を隠蔽させずに OMP パケット内でそのまま保持・伝搬させなさい。
* **要件:**
  * OMP パラメータで `propagate-aspath` を有効化する。
* **設定例:**

```text
sdwan
 omp
  propagate-aspath
!
```

* **検証方法:**
  対向拠点の BGP ルータで `show ip bgp` を実行し、受信した BGP プレフィックスに送信元拠点の BGP AS 番号が AS_PATH 属性として保持されていることを確認する。

---

### サンプル 5: OMP 優先度 (OMP Preference) による選定パスの不均一化

* **問題:** 拠点 B（cEdge-2）において、同一のプレフィックス `172.16.20.0/24` を持つ 2 台の WAN Edge（cEdge-2A と cEdge-2B）が存在する。cEdge-2A の OMP プレフィックスの優先度（OMP Preference）を 100 に変更し、優先的にトラフィックを吸引しなさい。
* **要件:**
  * cEdge-2A 側で OMP Preference を 100 に設定（デフォルトは 0）。
* **設定例:**

```text
sdwan
 omp
  address-family ipv4 unicast
   advertise connected
  !
!
! 注意: Centralized Control Policy (vSmart) または Local Route-Map で omp-preference をセット
! cEdge ローカルで適用する場合:
route-map SET-OMP-PREF permit 10
 set omp-preference 100
!
sdwan
 omp
  address-family ipv4 unicast
   route-map SET-OMP-PREF out
  !
!
```

* **検証方法:**
  他拠点の cEdge で `show sdwan omp routes 172.16.20.0/24 detail` を実行し、`Preference: 100` のパスが Best パス (`C,B`) として選定されていることを確認する。

---

### サンプル 6: OMP ➔ OSPF 再配送と Route Tag フィルタリング

* **问题:** VPN 10 において、OMP から学習したルートを LAN 側の OSPF プロセス 10 に再配送しなさい。その際、相互再配送によるループを防止するためにデフォルトタグ（1088）を保持しなさい。
* **要件:**
  * OMP ➔ OSPF 10 (VRF 10) 再配送。
  * メトリックタイプ 2、メトリック値 20 を設定。
* **設定例:**

```text
router ospf 10 vrf 10
 domain-id 10.10.10.10
 redistribute omp subnets route-map OMP->OSPF
!
route-map OMP->OSPF permit 10
 set metric 20
 set metric-type type-2
!
```

* **検証方法:**
  LAN 側 OSPF ルータで `show ip ospf database external` を実行し、受信した LSA Type-5 に Tag 1088 が自動付与されていることを確認する。

---

### サンプル 7: OMP ➔ BGP 再配送構成

* **問題:** VPN 20 において、OMP 経路を LAN 側の eBGP アピア（AS 65020）へ再配送しなさい。
* **要件:**
  * OMP ➔ BGP 65020 (VRF 20) へのルート流し込み。
* **設定例:**

```text
router bgp 65000 vrf 20
 address-family ipv4 unicast
  redistribute omp
  neighbor 192.168.20.2 remote-as 65020
  neighbor 192.168.20.2 activate
 exit-address-family
!
```

* **検証方法:**
  対向 BGP ピア（192.168.20.2）で `show ip bgp` を実行し、SD-WAN 網内の OMP 経路が BGP テーブルに正常にロードされていることを確認する。

---

### サンプル 8: SD-Access 統合時における SGT 伝搬 (SAD/SGT OMP)

* **問題:** cEdge が SD-Access ファブリックの Fabric Border ノードとして動作している環境において、OMP を介して SD-Access の SGT（Security Group Tag）情報を伝搬させなさい。
* **要件:**
  * SD-Access SGT インラインタギングの OMP 保持。
* **設定例:**

```text
sdwan
 omp
  address-family ipv4 unicast
   advertisement-interval 1
  !
!
! cEdge 上で TrustSec 及び SD-Access 機能が有効化されている場合、
! OMP は自動的に SGT 属性（SAD/SGT Extended Community）を保持して送信する。
```

* **検証方法:**
  `show sdwan omp routes detail` を実行し、`Attributes` フィールド内に `SGT: <tag_number>` 情報が含まれて送信されていることを確認する。

---

### サンプル 9: OMP パス送受信上限の調整 (Multi-Homining 対応)

* **問題:** 4 本の WAN 回線を持つデュアル Edge 構成において、vSmart から受信する全 OMP パス（最大 8 パス）を制限なく受信し、データプレーン上でマルチパス処理できるようにしなさい。
* **要件:**
  * 受信パス上限 (`ecmp-limit` 及び `send-path-limit`): 8
* **設定例:**

```text
sdwan
 omp
  send-path-limit 8
  ecmp-limit 8
  send-backup-paths
!
```

* **検証方法:**
  `show sdwan omp routes` を実行し、同一プレフィックスに対して最大 8 個の TLOC パスが保持されていることを確認する。

---

### サンプル 10: OMP Graceful Restart の手動テストおよび動作確認

* **問題:** OMP Graceful Restart 機能が正常に動作しているか確認し、タイマー値を試験用に 3600 秒に短縮しなさい。
* **要件:**
  * GR Timer: 3600 秒
* **設定例:**

```text
sdwan
 omp
  graceful-restart
  graceful-restart-timer 3600
!
```

* **検証方法:**
  `show sdwan omp summary` を実行し、`Graceful Restart: Enabled` および `Timer: 3600` となっていることを確認する。

---

## ❓ 想定試験問題

### 問題 1 (コンフィグ読解)
ある拠点ルータ（cEdge-1）の OMP 設定を確認したところ、LAN 側（VPN 10）の OSPF 経路が他拠点へアドバタイズされていないことが判明しました。以下のコンフィグから原因を特定し、正しく修正しなさい。

```text
sdwan
 omp
  no shutdown
  address-family ipv4 unicast
   advertise connected
   advertise static
  !
!
router ospf 10 vrf 10
 router-id 1.1.1.1
 network 10.10.10.0 0.0.0.255 area 0
!
```

* **解答・解説:**
  * **原因:** `sdwan -> omp -> address-family ipv4 unicast` 配下において、`advertise ospf`（または `advertise ospf external`）が設定されていないため、OSPF で学習した LAN 経路が OMP へ流し込まれていません。
  * **修正コンフィグ:**
    ```text
    sdwan
     omp
      address-family ipv4 unicast
       advertise ospf
      !
    !
    ```

---

### 問題 2 (トラブルシューティング)
cEdge-1 と cEdge-2 の間で OMP 経路は正常に交換（`show sdwan omp routes` で受信確認）されていますが、cEdge-1 の Linux クライアントから cEdge-2 傘下の端末への Ping がタイムアウトになります。`show sdwan omp routes` の出力結果は以下の通りです。

```text
cEdge-1# show sdwan omp routes 172.16.20.0/24
CODE: C - Chosen, I - Invalid, B - Best
PREFIX         TLOC IP       COLOR         ENCAP  STATUS
---------------------------------------------------------
172.16.20.0/24 192.168.2.1   biz-internet  ipsec  I
```

障害の原因と解決手順を説明しなさい。

* **解答・解説:**
  * **原因:** STATUS が `I`（Invalid）となっています。OMP ルートが受信されているにもかかわらず Invalid になっている主な原因は、紐づく TLOC（192.168.2.1 / biz-internet）へのデータプレーン IPsec BFD トンネルが形成されていない（Unreachable）ためです。
  * **解決手順:**
    1. `show sdwan bfd sessions` を実行し、対向 TLOC 192.168.2.1 宛の BFD セッションが `Up` になっているか確認する。
    2. アンダーレイ（VPN 0）の IP 疎通、IPsec ポート（UDP 12346 / 4500）、および NAT 設定をトラブルシュートし、IPsec BFD トンネルを確立させると、STATUS が `C,B`（Chosen, Best）へ変化しルーティングテーブル（RIB）へ注入されます。

---

### 問題 3 (Design)
SD-WAN オーバーレイを企業内部の既存 eBGP バックボーン網へ接続する構成において、OMP が標準で BGP AS_PATH 属性を不透明（消去）にする仕様に起因して発生するルーティング課題と、その対策コマンドを述べなさい。

* **解答・解説:**
  * **ルーティング課題:** OMP はデフォルトで BGP パス属性（AS_PATH）を消去してアドバタイズするため、拠点 A の eBGP 網から SD-WAN オーバーレイ（OMP）を経由して拠点 B の eBGP 網へ抜ける際、送信元 AS 番号が消失し、拠点 B から再度拠点 A 側の eBGP 網へ経路が再流入した際に BGP AS_PATH ループ検知機能が動作せず、無制限なルーティングループが発生します。
  * **対策:** `sdwan -> omp -> propagate-aspath` コマンドを有効化することで、OMP は BGP AS_PATH 属性を保持したままオーバーレイを透過させ、対向の eBGP ピアへ送信するため、BGP の標準ループ防止機能が正しく作動します。

---

### 問題 4 (実装)
拠点 C にある 2 台の cEdge（cEdge-3A および cEdge-3B）から同一のデータセンタープレフィックス `10.200.0.0/16` をアドバタイズしています。全リモート拠点からのトラフィックを優先的に cEdge-3A 経由で受信させるため、OMP 属性を用いて要求を満たす設定を作成しなさい。

* **解答・解説:**
  * **設定:** cEdge-3A 側で OMP Preference を 100（cEdge-3B はデフォルト 0）に設定します。
  * **cEdge-3A CLI:**
    ```text
    route-map SET-OMP-PREF-HIGHER permit 10
     set omp-preference 100
    !
    sdwan
     omp
      address-family ipv4 unicast
       route-map SET-OMP-PREF-HIGHER out
      !
    !
    ```

---

### 問題 5 (コンフィグ読解・トラブルシューティング)
以下のコンフィグを適用したところ、OMP 経路の受容時に OSPF ルートのタグ値が一致せず、一部のサンプリング経路が破棄されました。設定上の問題点を指摘しなさい。

```text
sdwan
 omp
  no shutdown
  address-family ipv4 unicast
   advertise ospf external
  !
!
router ospf 1 vrf 10
 redistribute omp route-map OMP_TO_OSPF
!
route-map OMP_TO_OSPF permit 10
 match tag 200
 set metric 100
!
```

* **解答・解説:**
  * **問題点:** OMP 経路が OSPF へ再配送される際、Cisco SD-WAN の自動処理によって OMP 由来のルートにはデフォルトで Tag `1088`（またはドメイン計算値）が付与されます。上記の Route-Map では `match tag 200` を指定しているため、Tag 1088 を持つ OMP ルートがすべて Match 条件に合致せず拒否（implicit deny）され、OSPF 側へ一切再配送されません。
  * **修正点:** `match tag 1088` に修正するか、Match 条件を削除して正しく処理します。

---

## 🔗 参考リソース

* [Cisco Catalyst SD-WAN Control Plane Configuration Guide](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/v-routing-book/m-omp-overlay-management-protocol.html)
* [Cisco Technical Notes: Troubleshooting OMP Route Status and BFD Sessions](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-omp-routes.html)
* [Cisco Live Presentation: BRKCRS-2110 - Cisco SD-WAN Architecture & OMP Deep Dive](https://www.ciscolive.com/)
* [Cisco Command Reference: Cisco IOS-XE SD-WAN OMP Commands](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/command/k-z-book/m-omp-commands.html)

---

## 📝 **補足（Notes）**

### OMP ベストパス選定アルゴリズムのフローチャート記憶法

```text
[ Route Received ]
       │
       ▼
1. Is Path Valid? (TLOC Reachable via BFD?) ─── No ───> [ Ignore / Invalid ]
       │ Yes
       ▼
2. Compare OMP Preference (Higher wins)
       │ Equal
       ▼
3. Compare TLOC Preference (Higher wins)
       │ Equal
       ▼
4. Compare Origin Protocol Type (Connected > Static > BGP > OSPF)
       │ Equal
       ▼
5. Compare Origin Metric (Lower wins)
       │ Equal
       ▼
6. Compare Originator System IP (Highest/Lowest tie-breaker)
       │
       ▼
[ Best Path Selected -> Injected to RIB & Forwarding Table ]
```


## 📝 補足（Notes）

* **Centralized Policy のアクティベート順序:** vManage GUI 上で Centralized Policy を作成した際、最後の「Activate」ボタンを押すことで初めて vSmart へ NETCONF 経由でプッシュされ、vSmart から全 WAN Edge へ配信される。
* **Data Policy と Localized ACL の優先順位:** WAN Edge 上で Centralized Data Policy と Localized Access Control List (ACL) が両方適用されている場合、原則として **Centralized Data Policy が優先して評価** される。



## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKTRS-3793: Advanced SD-WAN Routing Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-3793) - OMP ベストパス選定とトラブル解決。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - OMP セッション断の診断手法。

### Configuration ガイド
*   [**Cisco SD-WAN Overlay Management Protocol (OMP) Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/vEdge-20-x/routing-book/m-routing-omp.html)。
*   [**Unicast Overlay Routing Configuration (Cisco Docs)**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/vEdge-20-x/routing-book/m-unicast-overlay-routing.html)。

### テクニカルドキュメント・設定例
*   [**Understanding OMP Path Selection (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)。
*   [**SD-Access and SD-WAN Integration Design Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdwan-integration-2019oct.pdf)。

---

## 📝 補足
- この学習メモは、SD-WAN ネットワークの「血管」であるデータプレーンを制御する「神経」としての OMP に焦点を当てています。CCIE EI ラボ試験では、**vSmart でのポリシー制御が TLOC や vRoute にどう反映されるか**を `show omp` コマンドで正確に追跡できるかどうかが、合格を分ける最大のポイントとなります。


