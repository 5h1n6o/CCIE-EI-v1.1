---
layout: default
title: 1.5-BGP
parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.5 BGP

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要 EGP プロトコルである **1.5 BGP (Border Gateway Protocol)** のアーキテクチャ、ピアリング動作（IBGP / EBGP）、パス選定アルゴリズム（Best Path Selection）、ルーティングポリシー（Communities, Route Maps）、AS パス操作、コンバージエンスとスケーラビリティ機能（Route Reflectors, Aggregation）、および各種運用機能について、Cisco IOS-XE 17.x の実装基準に完全準拠して体系的・実践的に解説します [7, 1.2; 22, 1.5; 57, 1.11.c; 130, Cisco BGP Overview]。

---

## 📘 概要

**BGP (Border Gateway Protocol - RFC 4271)** は、インターネットおよび大規模エンタープライズ網・サービスプロバイダ網において自律システム（AS: Autonomous System）間および AS 内部でルーティング情報を交換するために設計されたパスベクター型（Path-Vector）ルーティングプロトコルです [7, 1.2; 22, 1.5; 130, Cisco BGP Overview]。

IGP（OSPF や EIGRP 等）が最小メトリック（コストや遅延）に基づいて「最適な最短パス」を自動計算するのに対し、BGP は **豊富な BGP 属性（Path Attributes）** と **柔軟なポリシー制御（Route-Map / Community）** を用いて、ネットワーク管理者の意図に基づくポリシーベースのトラフィック制御（Traffic Engineering）を実現します [22, 1.5; 57, 1.11.c, 1.11.e; 137, Video Title: BGP Filtering and Manipulations]。

### 主な利用目的と適用シーン
1. **マルチホームインターネット接続 (Multihoming):** 複数の ISP（Internet Service Provider）と接続し、Web サーバーや公開サービスへのインバウンド/アウトバウンドトラフィックの負荷分散と冗長化（Failover）を実現する [22, 1.5.c (v); 133, BGP Case Studies]。
2. **MPLS L3VPN / SD-WAN アンダーレイ・オーバーレイ:** PE-CE 間の動的ルーティングプロトコルとして、また MP-BGP (Multiprotocol BGP) を用いた VPNv4/VPNv6 / EVPN プレフィックスおよび VRF 属性の伝搬基盤として利用する [7, 1.2.a; 28, 3.2.b; 158, Video Title: MPLS L3VPN Lecture]。
3. **エンタープライズコア・データセンター網 (EVPN / VXLAN):** データセンター内部（Spine-Leaf 構成）での eBGP / iBGP 採用によるスケールアウト型ファブリック制御。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | パスベクター型プロトコル。TCP ポート **179** を使用して信頼性の高いピアリングを確立。メトリック単一ではなく多数のパス属性でパス選定を行う [7, 1.2; 22, 1.5; 130, Cisco BGP Overview]。 |
| **用途** | ISP 相互接続、エンタープライズ Multi-ISP 接続、MPLS L3VPN/EVPN 制御プレーン、データセンター Spine-Leaf アンダーレイ/オーバーレイ [7, 1.2; 28, 3.2.b; 158, Video Title: MPLS L3VPN Lecture]。 |
| **メリット** | ① 超大規模（全インターネットルート 100万+）に耐えるスケーラビリティ。<br>② 属性調整による強力なトラフィック制御。<br>③ ループ防止メカニズム（AS_PATH ルール、iBGP スプリットホライズン）が堅牢 [22, 1.5.b, 1.5.d; 137, Video Title: BGP Route Propagation Control]。 |
| **デメリット** | IGP と比較してコンバージエンス速度が遅い（タイマーデフォルト: Keepalive 60s, Hold 180s）。設定が複雑で設計ミスがルーティングループやブラックホールを引き起こしやすい [7, 4.3.b; 22, 1.5.a (iii); 130, Cisco BGP Overview]。 |
| **対応 AS 番号** | 2-byte AS（1〜65535、プライベート: 64512〜65534）および 4-byte AS（1〜4294967295、Asplain / Asdot 記法） [22, 1.5.a (v), 1.5.a (vi)]。 |
| **設計上の注意点** | iBGP スプリットホライズン（iBGP ピアから学習したルートは他の iBGP ピアへ再送信しない）を理解し、フルメッシュ（Full-Mesh）または **Route Reflector (RR)** を正しく設計・配置する [22, 1.5.e (i); 57, 1.11.d; 135, Understanding Route Aggregation in BGP]。 |

---

## 🏗 動作原理

BGP は、TCP ポート 179 のセッション確立を経て、**4 種類の BGP パケット**（OPEN, KEEPALIVE, UPDATE, NOTIFICATION）を動的にやり取りすることで状態を推移させます [7, 1.2; 22, 1.5; 130, Cisco BGP Overview]。

```text
[ Router A (AS 65001) ]                              [ Router B (AS 65002) ]
        │                                                    │
        │─── 1. TCP SYN (Port 179) ─────────────────────────►│ (Connect/Active State)
        │◄── 2. TCP SYN-ACK ─────────────────────────────────│
        │─── 3. TCP ACK ────────────────────────────────────►│ (TCP Established)
        │                                                    │
        │─── 4. OPEN Packet (AS, Holdtime, BGP ID, Caps) ───►│ (OpenSent State)
        │◄── 5. OPEN Packet ─────────────────────────────────│ (OpenConfirm State)
        │                                                    │
        │─── 6. KEEPALIVE Packet ───────────────────────────►│
        │◄── 7. KEEPALIVE Packet ───────────────────────────│
        │                                                    │
        │====================================================│
        │             [ BGP Established State ]              │
        │====================================================│
        │                                                    │
        │─── 8. UPDATE Packet (NLRI, Attributes) ───────────►│
        │◄── 9. UPDATE Packet ───────────────────────────────│
```

### BGP FSM (Finite State Machine) 6 つのステート遷移
1. **Idle:** 初期状態。TCP 接続を開始する準備段階。
2. **Connect:** 対向との TCP ポート 179 接続を試行している状態。
3. **Active:** TCP 接続試行が失敗し、再接続を試みている状態（リモート側からの応答待ち）。
4. **OpenSent:** TCP 接続が成立し、OPEN パケットを送信して対向からの OPEN 受信を待っている状態。
5. **OpenConfirm:** 双方の OPEN パケットの検証が成功し、KEEPALIVE パケットの受信を待っている状態。
6. **Established:** KEEPALIVE を相互受信し、BGP セッションが完全確立した状態。この状態で初めて UPDATE パケットによる NLRI（Prefix 情報）の交換が行われます。

---

## ⚙ 動作シーケンス

1. **TCP セッション確立:** BGP ピア間で TCP 3-way handshake (Port 179) が完了する。
2. **能力宣言 (Capabilities Negotiation):** OPEN パケット内で、サポートするアドレスファミリー（IPv4 Unicast, IPv6 Unicast, VPNv4 等）、4-byte AS サポート、Route Refresh 能力等をネゴシエートする [22, 1.5.a (v), 1.5.f]。
3. **初期ルート同期 (Full Update):** セッション確立直後、自機の BGP テーブルに存在する有効経路を UPDATE パケットで相手へ一括送信する。
4. **差分更新と Keepalive:** 定常状態では差分情報（新規追加・消失プレフィックス）のみを UPDATE で通知し、定期的な KEEPALIVE（デフォルト 60 秒）でセッションを維持する [22, 1.5.a (iii)]。
5. **iBGP ルート伝搬と Next-Hop 処理:**
   * eBGP ネイバーから受信したルートを iBGP ネイバーへ伝搬する際、**デフォルトでは Next-Hop アドレスが書き換わらない** [132, Configuring BGP Route Map with Next-Hop Self]。
   * 内部 iBGP ピアがその Next-Hop に疎通できない場合、該当ルートは BGP テーブル上で invalid（非最優先）となり RIB へ挿入されません。このため `neighbor <IP> next-hop-self` が不可欠です [132, Configuring BGP Route Map with Next-Hop Self]。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、BGP は最も配点が高く、かつ他のすべてのオーバーレイ技術（MPLS L3VPN, SD-WAN, SD-Access, EVPN）の基盤となります [7, 1.2; 22, 1.5; 28, 3.2.b]。

### 1. 必修の BGP ベストパス選定アルゴリズム (13 段階) の完全暗記
試験でのトラフィックエンジニアリング課題（「R1 経由の通信を特定の ISP へ迂回させよ」等）を解くため、以下の判定優先順位を暗記し、どの属性を調整すべきかを判断します [22, 1.5.b (ii); 57, 1.11.c]。

| 順位 | 判定条件 | 補足・制御方法 |
| :---: | :--- | :--- |
| **1** | **Highest Weight** (Cisco 独自) | ルータローカルのみに適用される最高優先度属性（0〜65535）。自機生成ルートはデフォルト 32768 [22, 1.5.b (i); 57, 1.11.c]。 |
| **2** | **Highest Local Preference (LocPrf)** | AS 内部全体に伝搬される最優先属性（デフォルト: 100）。iBGP 全体のアラウトバウンド出口制御に利用 [22, 1.5.b (i); 57, 1.11.c]。 |
| **3** | **Locally Originated Route** | 自ルータ生成ルート（`network` コマンド, `aggregate-address`, `redistribute`）を優先 [22, 1.5.b (ii)]。 |
| **4** | **Shortest AS_PATH** | 通過する AS 番号の要素数が最小のパスを選択。`set as-path prepend` で操作可能 [22, 1.5.d (ii); 57, 1.11.c]。 |
| **5** | **Lowest Origin Code** | **IGP (i)** > **EGP (e)** > **Incomplete (?)** の順で優先 [22, 1.5.b (i)]。 |
| **6** | **Lowest MED (Multi-Exit Discriminator)** | 同一対向 AS から受信した複数パス間で最小 MED 値を選択（デフォルト: 0）。インバウンド制御に利用 [22, 1.5.b (i); 57, 1.11.c]。 |
| **7** | **eBGP over iBGP** | eBGP ピアから学習したパスを iBGP パスより優先 [22, 1.5.a, 1.5.b (ii)]。 |
| **8** | **Lowest IGP Metric to BGP Next-Hop** | Next-Hop IP アドレスに対する内部 IGP（OSPF/EIGRP 等）コストが最小のパスを選択 [22, 1.5.b (ii)]。 |
| **9** | **Multipath (ロードバランシング)** | `maximum-paths` が構成されている場合、ここまでの条件が等しい複数パスを ECMP 掲載 [22, 1.5.b (iii)]。 |
| **10**| **Oldest External Route** | eBGP パス間の場合、最も長くアサートされている（フラッピングしていない）安定パスを選択 [22, 1.5.b (ii)]。 |
| **11**| **Lowest BGP Router ID** | 対向ルータの BGP Router ID（または Originator ID）が最も低いパスを選択 [22, 1.5.b (ii)]。 |
| **12**| **Minimum Cluster List Length** | Route Reflector 環境で通過した Cluster List 長が最短のパスを選択 [22, 1.5.e (i); 57, 1.11.d]。 |
| **13**| **Lowest Neighbor IP Address** | 最終タイ・ブレーク。対向ネイバーの IP アドレスが最も低いパスを選択 [22, 1.5.b (ii)]。 |

### 2. ラボ試験で多発するトラブルパターンと対策
* **iBGP スプリットホライズンによるルート不伝搬:**
  iBGP フルメッシュが組まれておらず、Route Reflector も設定されていない中間ルータでルートが更新・伝搬されない問題 [22, 1.5.e (i); 57, 1.11.d]。
* **Next-Hop 不到達 (Unreachable Next-Hop):**
  eBGP から学習したプレフィックスを iBGP へ渡す際、`next-hop-self` の指定を忘れて iBGP 側で Next-Hop IP に到達できず、ルートが BGP テーブル上で `*` (Valid) にならないトラブル [132, Configuring BGP Route Map with Next-Hop Self]。
* **AS_PATH ループ検知による拒否 (allowas-in / local-as / as-override):**
  Customer ルータや SD-WAN Hub で同一 AS 番号がループバックしてルートが拒否される問題。`allowas-in` や `as-override` を正確に使い分ける課題が出題されます [22, 1.5.d (i)]。
* **コミュニティ（Communities）の送出忘れ:**
  Route-Map で `set community` を定義しても、ネイバー設定で `neighbor <IP> send-community [standard|extended|both]` を投入していないと対向に属性が引き渡されない落とし穴 [22, 1.5.c (iv)]。

---

## 🛠 設定方法

### 1. モダンな Address-Family & Peer-Template による BGP 構成

```bash
# 1. BGP プロセスとグローバルパラメーター
router bgp 65001
 bgp router-id 1.1.1.1
 bgp log-neighbor-changes
 no bgp default ipv4-unicast
 !
 # 2. ピアポリシーテンプレート (Peer Policy Template) の作成
 template peer-policy IBGP_POLICY
  next-hop-self
  send-community both
 exit-peer-policy
 !
 # 3. ピアセッションテンプレート (Peer Session Template) の作成
 template peer-session IBGP_SESSION
  remote-as 65001
  update-source Loopback0
  timers 10 30
 exit-peer-session
 !
 # 4. ネイバーの定義とテンプレートバインド
 neighbor 10.1.2.2 inherit peer-session IBGP_SESSION
 neighbor 10.1.3.3 inherit peer-session IBGP_SESSION
 !
 # 5. IPv4 Address-Family でのネイバー有効化とポリシー適用
 address-family ipv4
  bgp dampening
  network 1.1.1.1 mask 255.255.255.255
  network 10.1.0.0 mask 255.255.0.0
  aggregate-address 10.0.0.0 255.0.0.0 summary-only as-set
  !
  neighbor 10.1.2.2 activate
  neighbor 10.1.2.2 inherit peer-policy IBGP_POLICY
  neighbor 10.1.3.3 activate
  neighbor 10.1.3.3 inherit peer-policy IBGP_POLICY
 exit-address-family
```

### 2. eBGP Dynamic Neighbors (Listen Range) 設定

```bash
router bgp 65002
 bgp listen range 192.168.10.0/24 peer-group DYNAMIC_SPOKES
 neighbor DYNAMIC_SPOKES peer-group
 neighbor DYNAMIC_SPOKES remote-as 65003
 !
 address-family ipv4
  neighbor DYNAMIC_SPOKES activate
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP サマリー状態（ネイバー IP、AS、受信 Prefix 数、State 確認）** | <code>show ip bgp summary</code> / <code>show bgp ipv4 unicast summary</code> [131, Show ip bgp summary] |
| **BGP テーブル全体（最優先パス `*>`, 属性、AS_PATH 等）の監査** | <code>show ip bgp</code> / <code>show bgp ipv4 unicast</code> [131, Show ip bgp] |
| **特定プレフィックスの 13 段階パス選定詳細・属性ログの解析** | <code>show ip bgp 10.1.0.0/16</code> |
| **特定ネイバーに関する接続詳細（送信/受信 Prefix 数、能力等）** | <code>show ip bgp neighbors 10.1.2.2</code> [131, Show ip bgp neighbor] |
| **特定ネイバーへ送信（Advertised）している Route 一覧の確認** | <code>show ip bgp neighbors 10.1.2.2 advertised-routes</code> |
| **特定ネイバーから受信（Received）した Route 一覧の確認** | <code>show ip bgp neighbors 10.1.2.2 routes</code> |
| **BGP リアルタイムイベントおよび FSM 状態推移デバッグ** | <code>debug bgp ipv4 unicast</code> / <code>debug ip bgp updates</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **BGP ピア状態が `Active` または `Connect` から推移しない。** | 1. 物理/IGP 疎通が不可。<br>2. `update-source Loopback` 抜けによる送信元 IP 不一致。<br>3. eBGP マルチホップ環境での `ebgp-multihop` 抜け。<br>4. TCP ポート 179 が ACL / CoPP でドロップ。 | `show ip bgp summary`<br>`ping <IP> source Loopback0` | 1. IGP 疎通を確認。<br>2. 両端で `update-source` を統一。<br>3. eBGP で Loopback 間接続時は `ebgp-multihop <ttl>` を追加 [22, 1.5.a]。 |
| **BGP テーブルにルートは入っているが最優先（`*>`）にならず RIB に掲載されない。** | 1. Next-Hop IP に対する IGP 疎通がない (Next-Hop Unreachable)。<br>2. eBGP より AD 値が低い IGP 経路がすでに存在。<br>3. 自身の AS 番号が AS_PATH に含まれている（AS Loop）。 | `show ip bgp <prefix>` | 1. iBGP ピアへ `neighbor <IP> next-hop-self` を設定する [132, Configuring BGP Route Map with Next-Hop Self]。<br>2. 相手 AS ループ許容時は `allowas-in` をバインドする [22, 1.5.d (i)]。 |
| **Route-Map で Community を付与したのに、対向ルータで Community が受信されない。** | `neighbor <IP> send-community [standard|extended|both]` が未設定。 | `show ip bgp <prefix>` | 該当ネイバーの設定に `send-community` を明示的に追加する [22, 1.5.c (iv)]。 |
| **BGP ピア更新（コンフィグ変更）が反映されない。** | Soft Reconfiguration 未設定かつ対向が Route Refresh 非対応。 | `show ip bgp neighbors <IP>` | `clear ip bgp <IP> soft in` を実行する [22, 1.5.f]。 |

---

## ⚠ 制限事項

1. **iBGP スプリットホライズン制限:**
   * iBGP ピアから学習したルートは、ループ防止のため他の iBGP ピアへ再アドバタイズされません（フルメッシュまたは Route Reflector が不可欠） [22, 1.5.e (i); 57, 1.11.d]。
2. **eBGP デフォルト TTL 制限:**
   * eBGP パケットの IP TTL はデフォルトで **1** に設定されています。直結以外のマルチホップ（Loopback 間ピアリング等）を行う場合、`ebgp-multihop <count>` の指定が必須となります [22, 1.5.a]。

---

## 🔄 他技術との関連

* **MPLS L3VPN:**
  Provider Edge (PE) ルータ間で MP-BGP (`address-family vpnv4`) を使用し、RD (Route Distinguisher) や RT (Route Target: Extended Community) を付与して顧客 VRF ルートを伝搬します [7, 1.2.a; 28, 3.2.b; 158, Video Title: MPLS L3VPN Lecture]。
* **Route Leaking / VRF-Aware BGP:**
  `address-family ipv4 vrf <NAME>` モード配下で PE-CE 間 BGP や VRF 間ルートリークを制御します [22, 1.2.e, 1.2.f]。
* **Control Plane Policing (CoPP):**
  BGP の TCP ポート 179 パケットを優先キュー（CoPP）に割り当て、DoS 攻撃から BGP プロセスを保護します [22, 4.1.a]。

---

## 🧩 比較表

### IBGP vs EBGP 動作比較

| 比較項目 | IBGP (Internal BGP) | EBGP (External BGP) |
| :--- | :--- | :--- |
| **AS 番号** | 自ルータと同一の AS 番号 | 異なる AS 番号 [22, 1.5.a] |
| **デフォルト TTL** | 255 (マルチホップ可能) | 1 (直結前提、マルチホップは `ebgp-multihop` 要) [22, 1.5.a] |
| **Next-Hop 動作** | 伝搬時に Next-Hop アドレスを変更しない [132] | 伝搬時に自身の IP アドレスへ Next-Hop を更新 |
| **ルート再伝搬ルール** | iBGP から学習したルートは別の iBGP へ転送不可 (Split Horizon) | eBGP から学習したルートは iBGP/eBGP 双方へ転送可能 |
| **Administrative Distance** | **200** | **20** [22, 1.2.a] |
| **Loop 防止策** | iBGP Split Horizon, Route Reflector (Originator-ID, Cluster-List) | AS_PATH ルール（自 AS が含まれる UPDATE を破棄） [22, 1.5.d, 1.5.e (i)] |

---

## 💡 ベストプラクティス

1. **`no bgp default ipv4-unicast` の徹底:**
   意図しない IPv4 Unicast セッションの自動生成を防ぎ、明示的に `address-family` モード内で `activate` する [22, 1.5.a]。
2. **Peer Template の活用:**
   大規模環境では `peer-session` および `peer-policy` テンプレートを使い、設定の共通化と変更作業の標準化を図る [6, Task 4; 22, 1.5.a (i)]。
3. **Route Reflector の二重化:**
   単一障害点（SPOF）を排除するため、Cluster-ID を同一にした 2 台の Route Reflector を冗長配置する [22, 1.5.e (i); 57, 1.11.d]。

---

## 📝 ラボ学習・設定サンプル例

CCIE EI Practical Lab 試験レベルの 10 個の完全構成演習シナリオです。

### Scenario 1: Peer Group と Next-Hop-Self を用いた iBGP フルメッシュ
* **要件:** R1, R2, R3 (AS 65001) 間で Loopback0 を送信元とした iBGP を Peer Group `IBGP_CORE` を用いて構成し、Next-Hop-Self を有効化せよ [6, Task 4; 22, 1.5.a (i); 132]。

**【R1】**
```bash
router bgp 65001
 bgp router-id 1.1.1.1
 no bgp default ipv4-unicast
 neighbor IBGP_CORE peer-group
 neighbor IBGP_CORE remote-as 65001
 neighbor IBGP_CORE update-source Loopback0
 neighbor 10.1.2.2 peer-group IBGP_CORE
 neighbor 10.1.3.3 peer-group IBGP_CORE
 !
 address-family ipv4
  neighbor IBGP_CORE activate
  neighbor IBGP_CORE next-hop-self
  neighbor IBGP_CORE send-community both
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp summary
# ネイバー 10.1.2.2, 10.1.3.3 との State が Established であることを確認
```

---

### Scenario 2: Peer Session / Policy Template のバインド
* **要件:** Scenario 1 の設定を Peer Session / Peer Policy テンプレートに書き換えよ [6, Task 4; 22, 1.5.a (i)]。

**【R1】**
```bash
router bgp 65001
 bgp router-id 1.1.1.1
 no bgp default ipv4-unicast
 !
 template peer-session S_IBGP
  remote-as 65001
  update-source Loopback0
 exit-peer-session
 !
 template peer-policy P_IBGP
  next-hop-self
  send-community both
 exit-peer-policy
 !
 neighbor 10.1.2.2 inherit peer-session S_IBGP
 neighbor 10.1.3.3 inherit peer-session S_IBGP
 !
 address-family ipv4
  neighbor 10.1.2.2 activate
  neighbor 10.1.2.2 inherit peer-policy P_IBGP
  neighbor 10.1.3.3 activate
  neighbor 10.1.3.3 inherit peer-policy P_IBGP
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.1.2.2
# テンプレートが正常に継承・バインドされていることを確認
```

---

### Scenario 3: eBGP Multihop と Loopback ピアリング
* **要件:** R1 (AS 65001) と R4 (AS 65002) 間で Loopback アドレスを用いた eBGP ピアリングを構成せよ [22, 1.5.a]。

**【R1】**
```bash
router bgp 65001
 neighbor 10.1.4.4 remote-as 65002
 neighbor 10.1.4.4 update-source Loopback0
 neighbor 10.1.4.4 ebgp-multihop 255
 !
 address-family ipv4
  neighbor 10.1.4.4 activate
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp summary
```

---

### Scenario 4: Weight 属性による特定出口への優先誘導
* **要件:** プレフィックス `172.16.0.0/16` への送信トラフィックについて、R4 経由のパスの Weight を **40000** に設定して最優先せよ [22, 1.5.b (i); 57, 1.11.c]。

**【R1】**
```bash
ip prefix-list PL_TARGET permit 172.16.0.0/16
!
route-map RM_WEIGHT_IN permit 10
 match ip address prefix-list PL_TARGET
 set weight 40000
!
route-map RM_WEIGHT_IN permit 20
!
router bgp 65001
 address-family ipv4
  neighbor 10.1.4.4 route-map RM_WEIGHT_IN in
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp 172.16.0.0/16
# Weight が 40000 となり、* > マークが付与されていることを確認
```

---

### Scenario 5: Local Preference による AS 全体のアウトバウンド制御
* **要件:** R1 で受信した特定ルートの Local Preference を **200** に変更し、AS 65001 全体からのデフォルト出口に設定せよ [22, 1.5.b (i); 57, 1.11.c]。

**【R1】**
```bash
route-map RM_LOCPRF_IN permit 10
 set local-preference 200
!
router bgp 65001
 address-family ipv4
  neighbor 10.1.4.4 route-map RM_LOCPRF_IN in
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp 172.16.0.0/16
# LocPrf 200 が伝搬され、R1 経由が選択されていることを確認
```

---

### Scenario 6: AS_PATH Prepending によるインバウンド制御
* **要件:** R1 から R4 へ送出するルートに対して自 AS 番号を **3 回 Prepend** し、R4 側からの入電トラフィックを他経路へ迂回させよ [22, 1.5.d (ii); 57, 1.11.c]。

**【R1】**
```bash
route-map RM_PREPEND_OUT permit 10
 set as-path prepend 65001 65001 65001
!
router bgp 65001
 address-family ipv4
  neighbor 10.1.4.4 route-map RM_PREPEND_OUT out
 exit-address-family
```

**【検証方法】**
```bash
R4# show ip bgp 1.1.1.1/32
# AS_PATH に 65001 65001 65001 65001 が含まれていることを確認
```

---

### Scenario 7: Route Reflector (RR) の構成
* **要件:** R1 を Route Reflector とし、R2 および R3 を RR Client として構成せよ [22, 1.5.e (i); 57, 1.11.d]。

**【R1 (RR)】**
```bash
router bgp 65001
 address-family ipv4
  neighbor 10.1.2.2 route-reflector-client
  neighbor 10.1.3.3 route-reflector-client
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp
# R3 のルートが R1 経由で正常に受渡されていることを確認
```

---

### Scenario 8: BGP Aggregation と Summary-Only / AS-Set
* **要件:** `10.1.0.0/24`〜`10.1.3.0/24` を `10.1.0.0/22` に集約し、詳細ルートを隠蔽しつつ元の AS 情報を保持せよ [22, 1.5.e (ii); 135]。

**【R1】**
```bash
router bgp 65001
 address-family ipv4
  aggregate-address 10.1.0.0 255.255.252.0 summary-only as-set
 exit-address-family
```

**【検証方法】**
```bash
R4# show ip bgp 10.1.0.0/22
# 属性に 'atomic-aggregate' および 'AS_SET {65001}' が付与されていることを確認
```

---

### Scenario 9: BGP Allowas-in (Customer 側 AS ループ許容)
* **要件:** MPLS 網を跨いで同一 AS 65001 を使用している拠点で、自 AS 番号を含むルートを **2 回まで受容** するよう構成せよ [22, 1.5.d (i)]。

**【R1】**
```bash
router bgp 65001
 address-family ipv4
  neighbor 10.1.14.4 allowas-in 2
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp
# 自 AS が含まれるルートが拒否されずに受容されていることを確認
```

---

### Scenario 10: BGP Remove-Private-AS の適用
* **要件:** ISP 接続口（R1）において、上流へルーティング情報をアドバタイズする際、プライベート AS 番号（64512〜65534）を自動削除せよ [22, 1.5.a (vi), 1.5.d (i)]。

**【R1】**
```bash
router bgp 65001
 address-family ipv4
  neighbor 203.0.113.1 remove-private-as
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 203.0.113.1 advertised-routes
# 送信ルートの AS_PATH からプライベート AS が除去されていることを確認
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解・トラブル】iBGP ルートが RIB に掲載されない原因
**問題:** 
R1, R2, R3 は AS 65001 内で iBGP フルメッシュを組んでいます。R1 が eBGP ピアから学習したプレフィックス `203.0.113.0/24` は、R2 の `show ip bgp` には `* 203.0.113.0/24  192.168.12.1`（`>` マークなし）として表示され、ルーティングテーブル（RIB）に載りません。理由と修正コマンドを述べてください [132, Configuring BGP Route Map with Next-Hop Self]。

**解答・解説:**
* **原因:** 
  eBGP から学習したルートを iBGP へ転送する際、BGP の標準動作として **Next-Hop IP アドレス（`192.168.12.1`）が書き換わらない** ためです。R2 側で `192.168.12.1` に対する IGP 疎通（可達性）が存在しないため、該当パスが **Inaccessible / Invalid** と判定され、最優先パス (`*>`) から除外されています [132]。
* **修正コマンド (R1 側):**
  ```bash
  router bgp 65001
   address-family ipv4
    neighbor 10.1.2.2 next-hop-self
   exit-address-family
  ```

---

### 2. 【Design / パス選定】Weight と Local Preference の動作範囲の相違
**問題:** 
BGP パス属性における **Weight** と **Local Preference** の決定的な動作範囲（Scope）の違いについて説明し、AS 内部の全ルータからのトラフィック出口を同一のルータへ統合したい場合、どちらの属性を調整すべきか根拠とともに回答してください [22, 1.5.b (i); 57, 1.11.c]。

**解答・解説:**
* **動作範囲の違い:**
  * **Weight:** Cisco 独自の属性であり、**設定を投入したローカルルータ内部でのみ有効**（他のルータへは UPDATE パケットで一切伝搬されない） [22, 1.5.b (i); 57, 1.11.c]。
  * **Local Preference:** 標準の BGP パス属性であり、**同一 AS 内部のすべての iBGP ピアへUPDATE パケットで伝搬される** [22, 1.5.b (i); 57, 1.11.c]。
* **設計回答:** **Local Preference を調整すべきです。**
  Weight を変更した場合、そのルータ自身の出口しか変わらず、AS 内の他ルータへ影響を与えられません。Local Preference を境界ルータのインバウンドで高め（例: `set local-preference 200`）に設定することで、UPDATE パケットを介して AS 内のすべての iBGP ルータへ伝搬され、AS 全体のトラフィック出口を一元統合できます [22, 1.5.b (i); 57, 1.11.c]。

---

## 🔗 参考リソース

* [Cisco Systems: BGP Configuration Guide, Cisco IOS XE Release 17.x](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/17-x/iproute-bgp-17-x-book.html)
* [Cisco Command Reference: BGP Commands](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/command/irg-cr-book.html)
* [Cisco Technical Notes: BGP Best Path Selection Algorithm](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/13753-25.html)
* [Cisco Live: BRKRST-3321 - Advanced BGP Architecture and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **BGP パス属性分類:**
  * **Well-known Mandatory:** ORIGIN, AS_PATH, NEXT_HOP
  * **Well-known Discretionary:** LOCAL_PREF, ATOMIC_AGGREGATE
  * **Optional Transitive:** AGGREGATOR, COMMUNITY
  * **Optional Non-transitive:** MED, Originator_ID, Cluster_List
