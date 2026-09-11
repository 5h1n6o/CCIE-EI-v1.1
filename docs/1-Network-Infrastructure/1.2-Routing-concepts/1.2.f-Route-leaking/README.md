# 1.2.f Route leaking between VRFs using route maps and VASI

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における高度なネットワーク仮想化・セグメンテーション制御技術である **Route leaking between VRFs using route maps and VASI (VRF-Aware Software Infrastructure)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

エンタープライズネットワークやサービスプロバイダーインフラにおいて、**VRF (Virtual Routing and Forwarding)** はルーティングテーブル（RIB）および転送テーブル（FIB）を物理機器内で完全論理分離する優れたマルチテナント技術です。しかし、実際のネットワーク設計では、完全に隔離されたVRF間において**「特定の共有サービス（DNS, DHCP, NTP, ISE, 認証サーバー, 共有ストレージ）」**や**「共通のインターネット出口」**、あるいは**「M&Aや組織統合に伴う特定テナント間通信」**を選択的に相互接続しなければならない要件が頻繁に発生します。

このように、分離されたVRF間で特定のルーティング情報およびデータトラフィックを選択的・制御して相互通過させる技術を **VRF Route Leaking（VRF間ルートリーク）** と呼びます。

Cisco IOS-XEにおいて、MPLS L3VPNやMP-BGP/EVPNなどの大型オーバーレイインフラを必要とせず、ローカル機器上（VRF-Lite環境）でVRF間ルートリークを実現する主なアプローチには以下の3つが存在します。

1. **Static Inter-VRF Route Leaking（スタティックルートによるリーク）:** スタティックルートのネクストホップとして対向VRFのIPアドレスやインターフェイスを指定するシンプルな手法。
2. **BGP `import vrf` with Route-Maps（Route-Mapを用いたBGP VRFインポート/エクスポート）:** ローカルBGPプロセス内で `import vrf <SOURCE_VRF> map <ROUTE_MAP>` コマンドを使用し、Route-Mapでフィルタリングや属性変更（Local Preference, Metric, Tagなど）を施しながら動的に経路をリークさせる手法。
3. **VASI (VRF-Aware Software Infrastructure):** ルータ内部に仮想の対となるインターフェイスペア（`vasileft<N>` と `vasiright<N>`）を作成し、それぞれのインターフェイスを異なるVRFにバインドすることで、**「あたかも物理バックツゥバック接続された2台のルータ間」**のようにVRF間を相互接続する高度な仮想化フレームワーク。

### 利用目的と適用場面
* **Shared Services (共通サービスVRF) の提供:** 各テナントVRF（VRF_A, VRF_B）から、共通の管理・サービスVRF（VRF_SHARED）へ必要なサービスプレフィックスのみを選択的に開示する。
* **VASIによる動的プロトコル相互接続:** スタティックやBGP `import vrf` では不可能な「VRF間でのOSPF / EIGRPネイバー確立と動的経路交換」を実現する。
* **VASIによるL3機能・ポリシー適用:** VRF間を跨ぐトラフィックに対して、Zone-Based Firewall (ZBFW)、NAT (VRF-Aware NAT / Inter-VRF NAT)、QoS、PBR (Policy-Based Routing)、Access Control List (ACL) などのL3〜L7ポリシーを完全適用する。

---

## 🔑 要点

| 項目 | Static Inter-VRF Leaking | BGP `import vrf` with Route-Maps | VASI (VRF-Aware Software Infrastructure) |
| :--- | :--- | :--- | :--- |
| **特徴** | 静的にネクストホップVRFを指定して経路を登録 [12, 1.2.f]。 | BGPのVRFアドレスファミリー間でRoute-Mapを用いて動的に経路を相互移送 [12, 1.2.f]。 | `vasileft` / `vasiright` 仮想インターフェイスペアによるVRF間物理同等接続 [12, 1.2.f]。 |
| **用途** | 少数の固定プレフィックスやデフォルトルートの簡易リーク [12, 1.2.f]。 | 多数の動的経路をRoute-Mapで精密フィルタリングしながらリーク [12, 1.2.f]。 | VRF間での動的ルーティング（OSPF/EIGRP）の実行、NAT/QoS/ACL/PBR適用 [12, 1.2.f]。 |
| **メリット** | 設定が極めてシンプルでBGPプロセスが不要 [12, 1.2.f]。 | BGP属性操作（Local Pref, Tag等）が可能で柔軟な制御ができる [12, 1.2.f]。 | 完全なL3インターフェイス境界を提供し、全IOS機能（NAT/PBR/OSPF/EIGRP）が動作 [12, 1.2.f]。 |
| **デメリット** | プレフィックス増加時の管理負荷が高く、属性制御不可 [12, 1.2.f]。 | BGPプロセスの起動が必須。L3ポリシー（NAT/PBR等）の直接適用は不可 [12, 1.2.f]。 | VASIペアの作成が必要。プラットフォームのパケット処理バジェット（ASIC/CEF）に依存 [12, 1.2.f]。 |
| **対応機種** | Catalyst 9000 シリーズ, Catalyst 8000 / ISR / ASR シリーズ (IOS-XE全般) [12, 1.2.f]。 | Catalyst 9000 シリーズ, Catalyst 8000 / ISR / ASR シリーズ (IOS-XE全般) [12, 1.2.f]。 | Catalyst 8000 / Catalyst 9000 シリーズ (IOS-XE 16.x / 17.x) [12, 1.2.f]。 |
| **制限事項** | イーサネットインターフェイス指定時はARP解決のためネクストホップIP必須 [12, 1.2.f]。 | ルートマップで許可されたプレフィックスのみがリーク対象となる [12, 1.2.f]。 | `vasileft` と `vasiright` は1対1でペア化され、他ペアとの重複利用不可 [12, 1.2.f]。 |
| **設計上の注意点** | **双方向の戻り経路（Return Path）**を忘れずに設定しないと片通しとなる [12, 1.2.f]。 | RD (Route Distinguisher) がVRFごとに正しく定義されている必要がある [12, 1.2.f]。 | VASIのMTU、およびTTL減衰（VASI通過でTTLが1消費される）に配慮する [12, 1.2.f]。 |

---

## 🏗 動作原理

### 1. BGP `import vrf` with Route-Maps の動作原理

BGP `import vrf` 機能は、ローカルデバイス内の対象VRF（Source VRF）のBGPテーブルから、現在のVRF（Target VRF）のBGPテーブルへプレフィックスをコピー（移送）するコントロールプレーンメカニズムです。

```text
[ VRF_SHARED BGP Table ] 
  ├── 10.100.1.0/24 (Shared Server)
  └── 10.100.2.0/24 (Shared Storage)
            │
            ▼ ( BGP import vrf VRF_SHARED map LEAK_MAP )
┌───────────────────────────────────────────────────────────┐
│ Route-Map: LEAK_MAP                                       │
│   match ip address prefix-list PERMIT_SERVER             │
│   set local-preference 200                                │
└───────────────────────────────────────────────────────────┘
            │
            ▼ ( フィルタ・属性変更後 )
[ VRF_TENANT_A BGP Table ]
  └── 10.100.1.0/24 (Next-Hop: 10.100.1.1 in VRF_SHARED)
            │
            ▼ ( CEF Forwarding Table )
パケット転送時: VRF_TENANT_A 内で受信されたパケットは、CEFにより直接 VRF_SHARED の出力を参照して超高速転送（FIB直接ポインティング）。
```

### 2. VASI (VRF-Aware Software Infrastructure) の動作原理

VASIは、IOS-XEソフトウェア内部で動作する**仮想のバックツゥバック（Point-to-Point）リンク**です。`vasileft<N>` と `vasiright<N>` という2つの論理インターフェイスがハードウェア/CEFレベルで直結（パイプ構造）されています。

```text
  [ VRF_TENANT_A ドメイン ]                               [ VRF_SHARED ドメイン ]
 ┌─────────────────────────┐                            ┌─────────────────────────┐
 │  ユーザー/サーバー網    │                            │    共有サービス網       │
 └───────────┬─────────────┘                            └───────────┬─────────────┘
             │                                                      │
             ▼                                                      ▼
 ┌─────────────────────────┐                            ┌─────────────────────────┐
 │ interface vasileft1     │  ◄─── ハードウェア ───►    │ interface vasiright1    │
 │ vrf forwarding TENANT_A │       内部パイプ           │ vrf forwarding SHARED   │
 │ ip addr 192.168.1.1/30  │      (VASI Link)           │ ip addr 192.168.1.2/30  │
 └─────────────────────────┘                            └─────────────────────────┘
```

* **コントロールプレーン:** `vasileft1` で動作させた OSPF / EIGRP / BGP プロセスは、対向の `vasiright1` 上のネイバーと通常通りハローパケットを交換し、隣接関係（Adjacency）を築きます。
* **データプレーン:** `vasileft1` から送出されたパケットは、内部パイプラインを通り、`vasiright1` の**「受信（Ingress）パケット」**として到達します。この際、通常の物理インターフェイスと同様に、Ingress ACL、PBR、NAT、QoS、ZBFW などのすべてのL3インスペクションエンジンを通過します。

---

## ⚙ 動作シーケンス

### VASI を経由した VRF 間通信のパケット処理シーケンス

```text
[ Client in VRF_A (10.1.1.50) ] ── 送信: 宛先 10.100.1.100 (Server in VRF_B)
       │
       ▼
1. スイッチ/ルータの Ingress インターフェイス (VRF_A) にパケット到着
       │
       ▼
2. VRF_A の FIB (CEF) テーブルを参照
   └─► 10.100.1.0/24 へのネクストホップは 192.168.1.2 (interface vasileft1)
       │
       ▼
3. パケットが interface vasileft1 (VRF_A) を出力
       │
       ▼
4. VASI パイプライン通過 (内部インターフェイス間転送)
       │
       ▼
5. パケットが interface vasiright1 (VRF_B) に「Ingress 入力パケット」として到着
       │
       ▼
6. VRF_B の Ingress 機能チェック
   ├─► Ingress ACL 判定 (許可/拒否)
   ├─► NAT 変換処理 (例: VRF_A の IP を VRF_B 用にソース NAT)
   └─► PBR 判定
       │
       ▼
7. VRF_B の FIB (CEF) テーブルを参照
   └─► 宛先 10.100.1.100 への物理出力インターフェイス (VRF_B) を特定
       │
       ▼
8. パケットが VRF_B の物理インターフェイスから Server へ送出
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI実技試験において、VRF間ルートリークは「単に通信を通す」だけでなく、**「指定された手法・プロトコルで、指定された経路のみを、適切なセキュリティ/属性で通す」** ことが厳格に求められます。

### 1. 試験で狙われる主な実装パターン
1. **BGP `import vrf` ＋ Route-Map による共有サービス限定リーク:**
   * 要件: 「VRF_CLIENT1 から VRF_SHARED へのアクセスを許可せよ。ただし、VRF_SHARED 内の `10.100.1.0/24` (DNS) のみを VRF_CLIENT1 へリークし、その他の経路は一切漏らしてはならない。また、リークされた経路の Local Preference を `150` に設定せよ」
2. **VASI による異種プロトコル (OSPF ⇄ EIGRP) 相互接続:**
   * 要件: 「VRF_A (EIGRP AS 100) と VRF_B (OSPF Area 0) の間を MPLS/BGP を使用せずに相互接続せよ。VASI を使用し、それぞれの VRF のルーティングプロセス配下で動的ネイバーを構築し、相互再配送を実行せよ」
3. **VASI 上での NAT / PBR 統合:**
   * 要件: 「VRF_GUEST から VRF_CORP への通信を許可せよ。ただし、IPアドレスの衝突を防ぎセキュリティを維持するため、VASI インターフェイスを通過する際に VRF_GUEST の送信元IPを `172.16.1.0/24` のプールアドレスに NAT 変換せよ」

### 2. よくある設定ミスと不合格の罠

* **Trap 1: 片方向リークによる「通信不可」 (Return Path の考慮漏れ)**
  * VRF_A から VRF_B へ宛先経路をリークしても、VRF_B 側に VRF_A の送信元IPアドレス（戻りパケット用）への経路がリークされていないと、ICMP/TCP通信は100%失敗します。常に**「往路と復路の両方のルートリーク」**を検証してください。
* **Trap 2: BGP `import vrf` 時の RD (Route Distinguisher) 忘れ**
  * `import vrf` コマンドを使用する際、対象となる両方のVRFにおいて `rd <ASN:NN>` が設定されていないと、BGP VRF テーブルが正常に生成されずリークが機能しません。
* **Trap 3: VASI ペアの番号指定ミスマッチ**
  * `vasileft1` の対向は必ず `vasiright1` です。`vasileft1` と `vasiright2` のように番号を誤ると、VASI リンクは UP 提案されてもパケットが逆側のインターフェイスに到達しません。
* **Trap 4: Static Route Leaking での Exit Interface 単独指定 (Ethernet 網)**
  * イーサネットインターフェイスを跨ぐ Static Inter-VRF Route Leaking で `ip route vrf VRF_A 10.2.2.0 255.255.255.0 GigabitEthernet0/0/1` とだけ書くと、対向のMACアドレスを解決できず ARP 失敗となります。必ず `ip route vrf VRF_A 10.2.2.0 255.255.255.0 GigabitEthernet0/0/1 10.1.1.2` または `ip route vrf VRF_A 10.2.2.0 255.255.255.0 vrf VRF_B 10.1.2.2` のように、明示的なネクストホップ IP を指定してください。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における代表的な設定例です。

### 1. BGP `import vrf` with Route-Maps による動的ルートリーク

```bash
# 1. VRF 定義と RD のバインド
vrf definition VRF_A
 rd 65000:10
 address-family ipv4
 exit-address-family
!
vrf definition VRF_SHARED
 rd 65000:100
 address-family ipv4
 exit-address-family

# 2. 経路フィルタリング用 Prefix-List と Route-Map の作成
ip prefix-list PL_SHARED_SERVICES seq 5 permit 10.100.1.0/24

route-map RM_LEAK_TO_TENANT permit 10
 match ip address prefix-list PL_SHARED_SERVICES
 set local-preference 150
 exit

# 3. BGP プロセス内での import vrf 設定
router bgp 65000
 bgp router-id 1.1.1.1
 !
 address-family ipv4 vrf VRF_A
  # VRF_SHARED から Route-Map を適用して経路をインポート
  import vrf VRF_SHARED map RM_LEAK_TO_TENANT
 exit-address-family
 !
 address-family ipv4 vrf VRF_SHARED
  # 戻り経路として VRF_A の連結サブネットをインポート
  import vrf VRF_A
 exit-address-family
```

### 2. Static Inter-VRF Route Leaking (ネクストホップ VRF 指定)

```bash
# VRF_A 側から VRF_B 内の 10.2.2.0/24 への静的リーク
# (ネクストホップ IP 10.1.12.2 は VRF_B 内に存在)
ip route vrf VRF_A 10.2.2.0 255.255.255.0 vrf VRF_B 10.1.12.2

# 復路: VRF_B 側から VRF_A 内の 10.1.1.0/24 への静的リーク
ip route vrf VRF_B 10.1.1.0 255.255.255.0 vrf VRF_A 10.1.12.1
```

### 3. VASI (VRF-Aware Software Infrastructure) インターフェイスの基本設定

```bash
# 1. VRF 定義
vrf definition VRF_RED
 address-family ipv4
!
vrf definition VRF_BLUE
 address-family ipv4

# 2. VASI インターフェイスペアのバインド
interface vasileft1
 description VASI_Link_to_VRF_RED
 vrf forwarding VRF_RED
 ip address 192.168.100.1 255.255.255.252
 no shutdown
!
interface vasiright1
 description VASI_Link_to_VRF_BLUE
 vrf forwarding VRF_BLUE
 ip address 192.168.100.2 255.255.255.252
 no shutdown

# 3. VASI 上での動的ルーティング (OSPF) 構成
router ospf 10 vrf VRF_RED
 router-id 10.10.10.10
 interface vasileft1
  ip ospf 10 area 0
!
router ospf 20 vrf VRF_BLUE
 router-id 20.20.20.20
 interface vasiright1
  ip ospf 20 area 0
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **特定VRFのルーティングテーブル確認（リークされた経路の確認）** | `show ip route vrf <VRF_NAME>` |
| **BGP VRFテーブル内のインポート経路と属性（Local Pref, Tag等）の確認** | `show ip bgp vrf <VRF_NAME>` |
| **VASI インターフェイスペアの動作ステータス確認** | `show interfaces vasileft1` / `show interfaces vasiright1` |
| **VASI の統計情報およびドロップカウンタ確認** | `show ip vasi` または `show vasi statistics` |
| **CEF（転送テーブル）における Inter-VRF ネクストホップ解像度の確認** | `show ip cef vrf <VRF_NAME> <PREFIX>` |
| **VASI 経由の双方向 Ping 通信確認** | `ping vrf <VRF_NAME> <TARGET_IP>` |
| **BGP インポート処理のデバッグ** | `debug ip bgp vrf <VRF_NAME> updates` |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **BGP `import vrf` を設定したが、BGP VRF テーブルに経路が全く現れない。** | 1. 対象の VRF で `rd` (Route Distinguisher) が未設定。<br>2. Route-Map の `match` 条件（Prefix-list 等）が不一致。<br>3. Source VRF の BGP テーブルに該当経路が存在しない。 | `show vrf`<br>`show ip bgp vrf <SOURCE_VRF>`<br>`show route-map` | 1. VRF 定義に `rd` を追加。<br>2. Route-Map と Prefix-List の記述（Subnet/Mask）を点検・修正。<br>3. Source VRF 側で `network` または `redistribute` が正しく行われているか確認。 |
| **VRF_A から VRF_B 内のサーバーへ Ping が届かない。** | 復路（VRF_B から VRF_A の送信元 IP）へのルーティング（戻りルート）がリークされていない。 | `show ip route vrf VRF_A`<br>`show ip route vrf VRF_B` | VRF_B 側のテーブルを確認し、送信元クライアントサブネットへのスタティックリークまたは BGP `import vrf` を追加する。 |
| **VASI インターフェイスが `up/down` または `down/down` になる。** | 対向の VASI インターフェイス（`vasileft` に対する `vasiright`）が `shutdown` されているか、未作成。 | `show interfaces status`<br>`show ip interface brief` | 両方の VASI インターフェイス（ペア）に `no shutdown` を実行し、VRF が正しく割り当てられているか確認する。 |
| **VASI を経由した OSPF ネイバーが `INIT/DROTHER` で停止し `FULL` にならない。** | VASI インターフェイスで MTU の不一致が発生しているか、Ingress ACL で OSPF パケット（224.0.0.5）がブロックされている。 | `show ip ospf interface vasileft1`<br>`show ip ospf neighbor` | 両端の MTU を合わせるか、必要に応じて `ip ospf mtu-ignore` を適用。ACL で 224.0.0.5 / OSPF プロトコル (89) を許可する。 |
| **Static Inter-VRF Route Leaking で CEF テーブルが `drop` や `unresolved` になる。** | イーサネット網で出口インターフェイスのみを指定し、ネクストホップ IP または宛先 VRF の指定が不完全。 | `show ip cef vrf <VRF_NAME> <PREFIX>` | `ip route vrf VRF_A <PREFIX> <MASK> vrf VRF_B <NEXT_HOP_IP>` の形式でネクストホップ IP を明記する。 |

---

## ⚠ 制限事項

### 1. VASI (VRF-Aware Software Infrastructure) の制限事項
* **1対1固定バインド:** `vasileft<N>` は対応する `vasiright<N>` とのみデータを交換できます。同一の `vasileft1` から複数の `vasiright` インターフェイスへマルチキャストやポイントツーマルチポイント接続することはできません。
* **プラットフォームパケットスループット:** VASI はルータ内部の CEF/ASIC パイプラインを2回通過（Ingress ➔ Egress ➔ Ingress ➔ Egress）するため、非常に高トラフィックな環境ではデータプレーンの処理能力（PPSバジェット）に影響を与える場合があります。

### 2. BGP `import vrf` の制限事項
* **BGP プロセスの必須化:** 対象となるすべての VRF が BGP プロセスに登録されている必要があります。OSPF や EIGRP の経路をリークさせる場合は、一旦 BGP へ再配送（Redistribute）してから `import vrf` を実行し、必要に応じてターゲット VRF 側で再配送し直す必要があります。

---

## 🔄 他技術との関連

* **VRF-Lite:** VRF間を完全分離する技術。本トピック（Route Leaking / VASI）はその分離されたVRF間を制御付きで接続する補完関係にあります [12, 1.2.d, 1.2.f]。
* **Network Address Translation (NAT):** VASI インターフェイスに `ip nat inside` / `ip nat outside` をバインドすることで、VRF 間を通過するトラフィックに対して高度な VRF-Aware / Inter-VRF NAT を実現します [23, 4.5.d (v)]。
* **Policy-Based Routing (PBR):** VASI インターフェイスに入力されたトラフィックに対して PBR を適用し、特定のパケットのみを別のネクストホップやセキュリティ装置へリダイレクトできます [12, 1.2.c, 1.2.f]。
* **Zone-Based Policy Firewall (ZBFW):** VASI インターフェイスをセキュリティゾーン（`zone-member security`）に割り当てることで、VRF 間のトラフィックに対してステートフルパケットインスペクションを実行できます。

---

## 🧩 比較表

### VRF間ルートリーク手法の比較

| 比較要素 | Static Inter-VRF Leaking | BGP `import vrf` | VASI (VRF-Aware Software Infrastructure) | MP-BGP L3VPN (Route Target) |
| :--- | :--- | :--- | :--- | :--- |
| **制御粒度** | プレフィックス単位（手動） | Prefix-List / Route-Map | インターフェイス単位（Routing Protocol全体） | Route Target (RT) エクスポータ/インポート |
| **動的ルーティング** | 不可（固定経路のみ） | BGPテーブル経由で可能 | **完全可能** (OSPF/EIGRP/BGPが直接動作) | MP-BGP経由で自動移送 |
| **L3/L7 ポリシー (NAT/PBR/ZBFW)**| 制限あり | 不可 | **完全サポート** (インターフェイス境界あり) | PEルータ上で制限あり |
| **設定の複雑さ** | 低 | 中 | 中 | 高（MPLS / BGP インフラ必須） |
| **主な適用シーン** | 小規模網、固定デフォルトルート | 共有サービスVRF (BGP環境) | 異種プロトコル結合、VRF間NAT/FW | 大規模キャンパス/キャリアL3VPN |

---

## 💡 ベストプラクティス

1. **最小権限の原則 (Least Privilege Route Leaking):**
   VRF 間で経路をリークする際は、全テーブルの同調（`permit any`）を避け、必ず `prefix-list` や `route-map` を使用して**必要な最小限のサービスプレフィックス（例: `/32` や `/24`）のみを明示的に許可**してください。
2. **戻り経路（Return Path）の同期設計:**
   ルートリークを設計する際は、常に送信元（クライアント）側から宛先（サーバー）側への「往路」と、サーバー側からクライアント側への「復路」のセットでルートマップまたはスタティックリークを構成してください。
3. **VASI 名と VRF 名の標準化命名規則:**
   VASI インターフェイスを運用する場合、`vasileft10` ➔ `VRF_TENANT10`、`vasiright10` ➔ `VRF_SHARED` のように、VASI のペアIDと対象 VRF や VLAN ID を連動させた命名規則を導入し、ラボおよび実務での設定ミスを防止します。

---

## 📝 ラボ学習・設定サンプル例

※ 本サンプルは、Cisco IOS-XE 17.x Catalyst 9000 / Catalyst 8000v の実機挙動に完全準拠した、省略なしのCLI設定構成です。

---

### サンプル 1: Static Inter-VRF Route Leaking (基本 Point-to-Point Next-Hop)

**【問題】**
`VRF_A`（ネットワーク `10.1.1.0/24`）と `VRF_B`（ネットワーク `10.2.2.0/24`）が同一ルータ内に存在します。両VRFは対向ルータと `GigabitEthernet0/0/1` (10.1.12.0/24) 上のサブインターフェイスで接続されています。
MPLS や BGP を使用せず、スタティックルートを用いて `VRF_A` から `VRF_B` 内の `10.2.2.0/24` への通信を可能にし、双方向の疎通を確立してください。

**【設定例】**
```bash
# 1. VRF 定義
vrf definition VRF_A
 address-family ipv4
!
vrf definition VRF_B
 address-family ipv4

# 2. インターフェイス設定
interface GigabitEthernet0/0/1.10
 encapsulation dot1Q 10
 vrf forwarding VRF_A
 ip address 10.1.12.1 255.255.255.0
!
interface GigabitEthernet0/0/1.20
 encapsulation dot1Q 20
 vrf forwarding VRF_B
 ip address 10.1.12.1 255.255.255.0

# 3. Inter-VRF Static Route Leaking の設定
# 往路: VRF_A から 10.2.2.0/24 へのトラフィックを VRF_B 内の対向ルータ IP (10.1.12.2) へ配送
ip route vrf VRF_A 10.2.2.0 255.255.255.0 vrf VRF_B 10.1.12.2

# 復路: VRF_B から 10.1.1.0/24 へのトラフィックを VRF_A 内の対向ルータ IP (10.1.12.2) へ配送
ip route vrf VRF_B 10.1.1.0 255.255.255.0 vrf VRF_A 10.1.12.2
```

**【検証方法】**
```bash
show ip route vrf VRF_A
# 出力に「S 10.2.2.0/24 [1/0] via 10.1.12.2 (VRF_B)」と表示されることを確認します。

ping vrf VRF_A 10.2.2.1 source 10.1.1.1
# 疎通が成功することを確認します。
```

---

### サンプル 2: BGP `import vrf` と Route-Map による Shared Services リーク

**【問題】**
`VRF_SHARED` 内に存在する DNS サーバー（`10.100.1.53/32`）および NTP サーバー（`10.100.1.123/32`）への経路のみを、`VRF_TENANT1` へリークしてください。その他の `VRF_SHARED` 内の経路（`10.100.2.0/24` 等）は遮断してください。リークされた経路の Local Preference は `200` に設定してください。

**【設定例】**
```bash
# 1. VRF 定義
vrf definition VRF_TENANT1
 rd 65000:1
 address-family ipv4
!
vrf definition VRF_SHARED
 rd 65000:100
 address-family ipv4

# 2. フィルタリング用 Prefix-List および Route-Map
ip prefix-list PL_PERMIT_SERVICES seq 5 permit 10.100.1.53/32
ip prefix-list PL_PERMIT_SERVICES seq 10 permit 10.100.1.123/32

route-map RM_IMPORT_SHARED permit 10
 match ip address prefix-list PL_PERMIT_SERVICES
 set local-preference 200
!
route-map RM_IMPORT_SHARED deny 99

# 3. BGP 設定
router bgp 65000
 bgp router-id 1.1.1.1
 !
 address-family ipv4 vrf VRF_TENANT1
  # VRF_SHARED から Route-Map を適用してインポート
  import vrf VRF_SHARED map RM_IMPORT_SHARED
 exit-address-family
 !
 address-family ipv4 vrf VRF_SHARED
  # 戻りパケット用に VRF_TENANT1 全体をインポート
  import vrf VRF_TENANT1
 exit-address-family
```

**【検証方法】**
```bash
show ip bgp vrf VRF_TENANT1
# 10.100.1.53/32 および 10.100.1.123/32 のみが存在し、LocPrf が 200 になっていることを確認します。
# 10.100.2.0/24 が存在しないことを確認します。
```

---

### サンプル 3: VASI による VRF 間 OSPFv2 動的ネイバー構築とルート交換

**【問題】**
ルータ R1 上で、`VRF_DEV` (OSPF Process 100) と `VRF_OPS` (OSPF Process 200) の間を VASI インターフェイスペア（`vasileft1` / `vasiright1`）を使用して接続し、両 VRF 間で OSPF ネイバーを確立して動的に経路を交換してください。

**【設定例】**
```bash
# 1. VRF 定義
vrf definition VRF_DEV
 address-family ipv4
!
vrf definition VRF_OPS
 address-family ipv4

# 2. VASI インターフェイス設定
interface vasileft1
 description VASI_DEV_Side
 vrf forwarding VRF_DEV
 ip address 172.16.255.1 255.255.255.252
 no shutdown
!
interface vasiright1
 description VASI_OPS_Side
 vrf forwarding VRF_OPS
 ip address 172.16.255.2 255.255.255.252
 no shutdown

# 3. OSPF プロセス設定
router ospf 100 vrf VRF_DEV
 router-id 1.1.1.1
 network 172.16.255.0 0.0.0.3 area 0
 network 10.10.0.0 0.0.255.255 area 0
!
router ospf 200 vrf VRF_OPS
 router-id 2.2.2.2
 network 172.16.255.0 0.0.0.3 area 0
 network 10.20.0.0 0.0.255.255 area 0
```

**【検証方法】**
```bash
show ip ospf 100 neighbor
# vasileft1 上で 2.2.2.2 との OSPF ネイバーが「FULL/DR (または BDR)」になっていることを確認します。

show ip route vrf VRF_DEV
# 10.20.0.0/16 の OSPF 経路が 172.16.255.2 (vasileft1) 経由で学習されていることを確認します。
```

---

### サンプル 4: VASI による異種プロトコル (EIGRP ⇄ OSPF) 相互接続と再配送

**【問題】**
`VRF_EIGRP` 内の EIGRP Named Mode (AS 100) と `VRF_OSPF` 内の OSPF Process 1 の間を VASI (`vasileft2` / `vasiright2`) で接続し、VASI インターフェイス上で相互再配送（Redistribution）を構成してください。

**【設定例】**
```bash
# 1. VRF 定義
vrf definition VRF_EIGRP
 address-family ipv4
!
vrf definition VRF_OSPF
 address-family ipv4

# 2. VASI インターフェイス設定
interface vasileft2
 vrf forwarding VRF_EIGRP
 ip address 192.168.250.1 255.255.255.252
 no shutdown
!
interface vasiright2
 vrf forwarding VRF_OSPF
 ip address 192.168.250.2 255.255.255.252
 no shutdown

# 3. EIGRP Named Mode 設定
router eigrp MULTI_VRF
 !
 address-family ipv4 unicast vrf VRF_EIGRP autonomous-system 100
  topology base
   redistribute ospf 1 metric 100000 10 255 1 1500
  exit-topology
  network 192.168.250.0 0.0.0.3
  network 172.16.0.0
 exit-address-family

# 4. OSPF 設定
router ospf 1 vrf VRF_OSPF
 router-id 8.8.8.8
 redistribute eigrp 100 subnets
 network 192.168.250.0 0.0.0.3 area 0
 network 10.0.0.0 0.255.255.255 area 0
```

**【検証方法】**
```bash
show ip route vrf VRF_EIGRP
# OSPF 由来の 10.0.0.0 系の経路が「D EX（EIGRP 外部経路）」として学習されていることを確認します。
```

---

### サンプル 5: VASI インターフェイス上での Inter-VRF NAT (Source NAT)

**【問題】**
`VRF_GUEST`（サブネット `192.168.50.0/24`）から `VRF_CORP` への通信において、IPアドレスの直接開示を防ぐため、VASI (`vasileft5` / `vasiright5`) を通過する際に、送信元IPアドレスを `10.50.1.100 - 10.50.1.200` のプールアドレスに Dynamic NAT 変換してください。

**【設定例】**
```bash
# 1. VRF 定義
vrf definition VRF_GUEST
 address-family ipv4
!
vrf definition VRF_CORP
 address-family ipv4

# 2. VASI インターフェイスと NAT の割り当て
interface vasileft5
 vrf forwarding VRF_GUEST
 ip address 172.31.255.1 255.255.255.252
 ip nat inside
 no shutdown
!
interface vasiright5
 vrf forwarding VRF_CORP
 ip address 172.31.255.2 255.255.255.252
 ip nat outside
 no shutdown

# 3. NAT アドレスプールおよび ACL の定義
ip access-list extended ACL_GUEST_TRAFFIC
 permit ip 192.168.50.0 0.0.0.255 any

ip nat pool POOL_CORP_NAT 10.50.1.100 10.50.1.200 prefix-length 24

# 4. VRF-Aware NAT ルールのバインド
ip nat inside source list ACL_GUEST_TRAFFIC pool POOL_CORP_NAT vrf VRF_GUEST

# 5. ルーティング（VASI へ向けて静的リーク）
ip route vrf VRF_GUEST 10.0.0.0 255.0.0.0 vasileft5 172.31.255.2
ip route vrf VRF_CORP 10.50.1.0 255.255.255.0 vasiright5 172.31.255.1
```

**【検証方法】**
```bash
show ip nat translations vrf VRF_GUEST
# 192.168.50.X から 10.50.1.X への NAT エントリが生成されていることを確認します。
```

---

### サンプル 6: VASI と PBR (Policy-Based Routing) による特定のVRF間トラフィックリダイレクト

**【問題】**
`VRF_USERS` から `VRF_INTERNAL` への通信のうち、HTTP (TCP port 80) トラフィックのみを VASI (`vasileft10` / `vasiright10`) を経由させて Web プロキシ/検疫サーバー (172.16.100.2) へリダイレクトし、その他のトラフィックは通常通り転送してください。

**【設定例】**
```bash
# 1. HTTP パケット用 ACL と Route-Map
ip access-list extended ACL_HTTP_ONLY
 permit tcp any any eq 80

route-map RM_PBR_VASI permit 10
 match ip address ACL_HTTP_ONLY
 set ip next-hop vrf VRF_INTERNAL 172.16.100.2
!
route-map RM_PBR_VASI permit 20

# 2. ユーザー収容インターフェイスへ PBR を適用
interface GigabitEthernet0/0/2.100
 vrf forwarding VRF_USERS
 ip address 10.10.1.1 255.255.255.0
 ip policy route-map RM_PBR_VASI
```

**【検証方法】**
```bash
show route-map RM_PBR_VASI
# match パケットカウンタが増加していることを確認します。
```

---

### サンプル 7: Dual-Stack (IPv4 / IPv6) VASI Route Leaking

**【問題】**
`VRF_SEC_A` と `VRF_SEC_B` の間を VASI (`vasileft20` / `vasiright20`) で接続し、IPv4 と IPv6 の両方のトラフィックを相互に転送できるように構成してください。

**【設定例】**
```bash
# 1. VRF 定義 (Dual-Stack)
vrf definition VRF_SEC_A
 address-family ipv4
 exit-address-family
 address-family ipv6
 exit-address-family
!
vrf definition VRF_SEC_B
 address-family ipv4
 exit-address-family
 address-family ipv6
 exit-address-family

# 2. VASI Dual-Stack アドレス設定
interface vasileft20
 vrf forwarding VRF_SEC_A
 ip address 192.168.220.1 255.255.255.252
 ipv6 address 2001:DB8:220::1/64
 no shutdown
!
interface vasiright20
 vrf forwarding VRF_SEC_B
 ip address 192.168.220.2 255.255.255.252
 ipv6 address 2001:DB8:220::2/64
 no shutdown

# 3. Dual-Stack Static Route Leaking
ip route vrf VRF_SEC_A 10.200.0.0 255.255.0.0 vasileft20 192.168.220.2
ipv6 route vrf VRF_SEC_A 2001:DB8:200::/48 vasileft20 2001:DB8:220::2

ip route vrf VRF_SEC_B 10.100.0.0 255.255.0.0 vasiright20 192.168.220.1
ipv6 route vrf VRF_SEC_B 2001:DB8:100::/48 vasiright20 2001:DB8:220::1
```

**【検証方法】**
```bash
ping vrf VRF_SEC_A 2001:DB8:200::1
# IPv6 の疎通が成功することを確認します。
```

---

### サンプル 8: BGP `import vrf` における Pre-prefix Tag マッチングと Local Pref 変更

**【問題】**
`VRF_HUB` で外部から受信した BGP 経路のうち、Route-Map で `tag 777` が付与された経路のみを `VRF_SPOKE` にインポートし、Local Preference を `300` に設定して優位にしてください。

**【設定例】**
```bash
# 1. Route-Map 設定
route-map RM_TAG_CHECK permit 10
 match tag 777
 set local-preference 300
!
route-map RM_TAG_CHECK deny 99

# 2. BGP インポート構成
router bgp 65001
 address-family ipv4 vrf VRF_SPOKE
  import vrf VRF_HUB map RM_TAG_CHECK
 exit-address-family
```

**【検証方法】**
```bash
show ip bgp vrf VRF_SPOKE
# Tag 777 を持つ経路のみがインポートされ、LocPrf が 300 に変化していることを確認します。
```

---

### サンプル 9: 共通インターネット出口 (Shared Internet VRF) への Default Route リーク

**【問題】**
インターネット接続を保持する `VRF_INET` から、テナント用 `VRF_CLIENT` に対してデフォルトルート (`0.0.0.0/0`) のみをリークし、`VRF_CLIENT` 内のサブネット `172.16.10.0/24` への戻り経路を `VRF_INET` に動的にリークしてください。

**【設定例】**
```bash
# 1. フィルタ用 Prefix-List
ip prefix-list PL_DEFAULT_ONLY seq 5 permit 0.0.0.0/0
ip prefix-list PL_CLIENT_SUBNET seq 5 permit 172.16.10.0/24

route-map RM_DEFAULT_ONLY permit 10
 match ip address prefix-list PL_DEFAULT_ONLY
!
route-map RM_CLIENT_ONLY permit 10
 match ip address prefix-list PL_CLIENT_SUBNET

# 2. BGP インポート
router bgp 65000
 address-family ipv4 vrf VRF_CLIENT
  import vrf VRF_INET map RM_DEFAULT_ONLY
 exit-address-family
 !
 address-family ipv4 vrf VRF_INET
  import vrf VRF_CLIENT map RM_CLIENT_ONLY
 exit-address-family
```

**【検証方法】**
```bash
show ip route vrf VRF_CLIENT 0.0.0.0
# デフォルトルートが BGP (b) または Import 経路として参照可能であることを確認します。
```

---

### サンプル 10: VASI インターフェイス上での Zone-Based Policy Firewall (ZBFW) による VRF 間インスペクション

**【問題】**
`VRF_TRUSTED` と `VRF_UNTRUSTED` を VASI (`vasileft30` / `vasiright30`) で接続し、`VRF_TRUSTED` から開始された TCP/UDP 通信のみをステートフルインスペクションして許可し、逆方向からの新規セッション開始をブロックしてください。

**【設定例】**
```bash
# 1. セキュリティクラスマップ・ポリシーマップの作成
class-map type inspect match-any CM_PASSTHROUGH
 match protocol tcp
 match match protocol udp
 match protocol icmp

policy-map type inspect PM_INSPECT_POLICY
 class type inspect CM_PASSTHROUGH
  inspect
 class class-default
  drop

# 2. セキュリティゾーンの定義とペアの作成
zone security ZONE_TRUSTED
zone security ZONE_UNTRUSTED

zone-pair security ZP_TRUST_TO_UNTRUST source ZONE_TRUSTED destination ZONE_UNTRUSTED
 service-policy type inspect PM_INSPECT_POLICY

# 3. VASI インターフェイスへのゾーン適用
interface vasileft30
 vrf forwarding VRF_TRUSTED
 ip address 10.254.1.1 255.255.255.252
 zone-member security ZONE_TRUSTED
 no shutdown
!
interface vasiright30
 vrf forwarding VRF_UNTRUSTED
 ip address 10.254.1.2 255.255.255.252
 zone-member security ZONE_UNTRUSTED
 no shutdown
```

**【検証方法】**
```bash
show policy-map type inspect zone-pair ZP_TRUST_TO_UNTRUST sessions
# TRUSTED 側から接続を開始した際に、ステートフルセッションが正しく確立されていることを確認します。
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解：BGP `import vrf` の不整合】

**問題:**
ネットワークエンジニアが VRF_SHARED から VRF_A へ経路をリークさせるために以下のコンフィグを適用しましたが、`show ip bgp vrf VRF_A` に一切経路が表示されませんでした。
```text
vrf definition VRF_A
 rd 65000:10
 address-family ipv4
 exit-address-family

vrf definition VRF_SHARED
 address-family ipv4
 exit-address-family

router bgp 65000
 address-family ipv4 vrf VRF_A
  import vrf VRF_SHARED
 exit-address-family
```
このコンフィグにおける**根本的な設定欠落**を指摘し、正しい修正コマンドを提示してください。

**解答・解説:**
* **根本的な設定欠落:**
  Source VRF である `VRF_SHARED` 側に **`rd` (Route Distinguisher) が定義されていません**。
  BGP `import vrf` コマンドが内部処理を実行する際、インポート元（Source）およびインポート先（Target）の両方の VRF にて Route Distinguisher が正常にバインドされている必要があります。`VRF_SHARED` に RD が存在しないため、BGP は対象の VRF テーブルを内部変換・参照できずインポート処理を拒否します。
* **修正コマンド:**
  ```text
  vrf definition VRF_SHARED
   rd 65000:100
   address-family ipv4
   exit-address-family
  ```

---

### 2. 【トラブルシュート：VASI 経由の OSPF ネイバー不通】

**問題:**
`VRF_1` と `VRF_2` の間を VASI ペア (`vasileft1` / `vasiright1`) で接続し、両端で OSPF エリア 0 を設定しましたが、ネイバー状態が `INIT` と `EXSTART` の間をバウンスし、`FULL` に遷移しません。ログには `%OSPF-5-ADJCHG: Nbr 2.2.2.2 on vasileft1 From EXSTART to DOWN` が出力されています。
原因として最も可能性が高い技術的理由と、その確認・対処コマンドを説明してください。

**解答・解説:**
* **原因:**
  VASI インターフェイス両端での **MTU（Maximum Transmission Unit）のミスマッチ**、あるいは VASI 経由で交換される OSPF DBD (Database Description) パケットのサイズ不一致が原因です。
* **確認・対処方法:**
  1. `show ip interface vasileft1` および `show ip interface vasiright1` で両端の MTU を確認。
  2. インターフェイス配下で MTU を一致させるか、一時的な回避策として両方の VASI インターフェイス配下で OSPF の MTU チェックを無視させます。
  ```text
  interface vasileft1
   ip ospf mtu-ignore
  interface vasiright1
   ip ospf mtu-ignore
  ```

---

### 3. 【Design：VASI vs BGP `import vrf` の選定基準】

**問題:**
企業網において、共通セキュリティ VRF と 10 個の事業部 VRF が存在します。
設計要件として「事業部 VRF 間のトラフィックはすべて共通セキュリティ VRF を通過させ、かつ Zone-Based Policy Firewall (ZBFW) によるステートフルパケット検査を適用しなければならない」と定義されています。
この要件を満たすために、**BGP `import vrf` ではなく VASI (VRF-Aware Software Infrastructure) を選定しなければならない理由**を技術的に説明してください。

**解答・解説:**
* **理由:**
  BGP `import vrf` は、単にコントロールプレーン（BGP ルーティングテーブル）上で経路を複写・移送するだけの機能であり、**論理的な L3 インターフェイス境界や物理的なパケット通過ポイントを生成しません**。そのため、ZBFW（Zone-Based Policy Firewall）や Ingress/Egress ACL などの「インターフェイスにバインドしてパケットを検査するセキュリティエンジン」を適用することが不可能です。
  一方、VASI は `vasileft` と `vasiright` という明確な**論理 L3 インターフェイスペア**を提供するフレームワークです。各 VASI インターフェイスを特定のセキュリティゾーン（`zone-member security`）に割り当てることで、VRF 間を跨ぐパケットに対して ZBFW のステートフルインスペクションエンジンを確実に通過・検査させることが可能になります。

---

### 4. 【実装：Static Inter-VRF Route Leaking の構文選択】

**問題:**
`VRF_A` から `VRF_B` 内のネクストホップ `10.1.12.2` へ向けて、プレフィックス `192.168.10.0/24` を静的にリークさせる際、以下の A と B の設定構文の違いと、イーサネット接続環境における A の問題点を説明してください。

* A: `ip route vrf VRF_A 192.168.10.0 255.255.255.0 GigabitEthernet0/0/1`
* B: `ip route vrf VRF_A 192.168.10.0 255.255.255.0 vrf VRF_B 10.1.12.2`

**解答・解説:**
* **違いと問題点:**
  * 構文 A は「出力を GigabitEthernet0/0/1 に限定するだけで、宛先 VRF やネクストホップ IP を明記していない」設定です。イーサネットのようなマルチアクセス共有網（Broadcast / Multi-Access）において出口インターフェイスのみを指定した場合、ルータは宛先 IP（`192.168.10.X`）に対して直接 ARP 解決を試みようとします（Proxy ARP 依存）。しかし、`192.168.10.X` は別 VRF のリモートネットワークであるため ARP 解決が失敗し、通信不能（CEF drop）に陥ります。
  * 構文 B は、明示的に**ネクストホップが存在するターゲット VRF (`vrf VRF_B`)** と **ネクストホップ IP (`10.1.12.2`)** を指定しているため、ルータは `VRF_B` 内の `10.1.12.2` に対する MAC アドレスを正常に参照でき、正しく CEF テーブルがカプセル化（再帰解決）されます。

---

### 5. 【トラブルシュート：BGP `import vrf` 適用時の無限ループ】

**問題:**
ルータ R1 において、`VRF_X` と `VRF_Y` の間で相互に BGP `import vrf` を設定（`VRF_X` は `import vrf VRF_Y`、`VRF_Y` は `import vrf VRF_X`）したところ、特定の経路が両方の VRF 間でバウンス（再インポートの無限ループ）を起こしそうになりました。
BGP プロセスがこのような**「一度インポートした経路の再インポート（Re-import Loop）」を防ぐために内部的に付与・判定している BGP 属性**は何ですか？

**解答・解説:**
* **内部属性:**
  BGP が `import vrf` コマンドによって別の VRF テーブルから経路をインポートする際、BGP は内部的に **`BGP Originator / Source VRF` 識別フラグ** および **BGP 拡張コミュニティ (Extended Community)** 属性を暗黙的に付与します。
  一度 `VRF_X` から `VRF_Y` へインポートされた経路には、その発生元が `VRF_X` であることが記録されているため、`VRF_Y` から再度 `VRF_X` へインポートしようとするルールが存在しても、BGP は自身の VRF が起源である経路の再インポートを自動的にループとして検知し、インポート処理をブロック（ルートループ防止）します。

---

## 🔗 参考リソース

* [**Cisco IOS XE 17.x IP Routing: BGP Configuration Guide - VRF Import and Export**](https://www.cisco.com/c/en/us/td/docs/routers/ios/config/17-x/ip-routing/b-ip-routing/m_bgp-vrf-import-export.html)
  * BGP `import vrf` および Route-Map を使用した動的 VRF リークに関する公式解説。
* [**Cisco IOS XE Configuration Guide: VRF-Aware Software Infrastructure (VASI)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/sec_data_vasi/configuration/15-s/sec-data-vasi-15-s-book.html)
  * VASI インターフェイスのアーキテクチャ、`vasileft` / `vasiright` の構成、NAT / ZBFW とのバインド手順。
* [**Cisco Live Slide / Video: BRKCRS-2452 - Advanced VRF-Lite and Multi-Tenant Campus Design**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-2452)
  * キャンパスインフラにおける VRF-Lite、VRF間リーク、VASI を用いた高度なトラフィック設計セッション。
* [**Cisco Technical Note: Troubleshooting Inter-VRF Static Route Leaking and CEF Resolution**](https://www.cisco.com/c/en/us/support/docs/ip/virtual-routing-forwarding-vrf/13808-vrf-leak.html)
  * スタティックルートによる VRF リーク時の CEF 解決と ARP テーブルのトラブルシューティングガイド。

---

## 📝 **補足（Notes）**

### VRF 間リーク設計選択フローチャート

```text
               [ VRF 間相互接続要件の発生 ]
                           │
                           ▼
          [ L3 機能 (NAT / ZBFW / PBR) や ]
          [ OSPF/EIGRP ネイバーが必要か？ ]
                           │
             ┌─────────────┴─────────────┐
            YES                         NO
             │                           │
             ▼                           ▼
    【 VASI を採用 】            [ 移送したい経路の規模・動的性 ]
    (vasileft / vasiright)               │
                                ┌────────┴────────┐
                              動的/多数          固定/少本数
                                │                 │
                                ▼                 ▼
                      【 BGP import vrf 】   【 Static Leaking 】
                      (with Route-Map)       (ip route vrf ...)
```

* **チェックリスト:**
  * [ ] 往路（Client ➔ Server）と復路（Server ➔ Client）の両方のルーティングがリークされているか？
  * [ ] BGP `import vrf` を使用する場合、双方の VRF に `rd` がバインドされているか？
  * [ ] VASI を使用する場合、`vasileft<N>` と `vasiright<N>` のペア番号が合致しているか？
  * [ ] イーサネット上の Inter-VRF Static Route で、ネクストホップ IP アドレスが明記されているか？

