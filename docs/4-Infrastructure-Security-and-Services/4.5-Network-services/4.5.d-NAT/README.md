---
layout: default
title: 4.5.d-NAT
parent: 4.5-Network-services
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 4
---

# 4.5.d IPv4 Network Address Translation

## 📘 概要

* **機能概要**: IPv4 Network Address Translation (NAT) および Port Address Translation (PAT) は、プライベート IP アドレス領域（RFC 1918）とパブリック IP アドレス領域、あるいは異なるルーティングドメイン（VRF 領域間含む）との間で IP ヘッダー内の送信元/宛先 IP アドレスおよび L4 ポート番号を透過的に書き換えるシスコ IOS XE の中核サービスである。
* **利用目的**:
  1. IPv4 アドレス枯渇問題の緩和（プライベート IP アドレスからパブリック IP への集約）。
  2. 企業買収・統合時やマルチテナント接続時における重複 IP アドレス（Overlapping Subnets）の救済とルーティング整合性の維持。
  3. セキュリティポリシーに基づく内部ネットワーク構成の隠蔽（Topology Hiding）。
  4. VRF 間（VRF-to-VRF / VRF-to-Global）における制御された相互通信の提供。
* **どのような場面で利用するか**: CCIE Enterprise Infrastructure (EI) のラボ試験では、単純な WAN 出口の PAT (Overload) に留まらず、複数 VRF 間に跨るルーティングと組み合わせた **VRF-aware NAT**、ポリシーベースで変換ルールを切り替える **Policy-based NAT (Route-Map ベース NAT)**、および VRF 間で NAT 変換テーブルを分離・制御する **VRF-aware Software Infrastructure (VASI) NAT** など、極めて高度な高度インフラサービス構築・トラブルシューティングが要求される。

---

## 🔑 要点

| 項目 | 内容 |
| --- | --- |
| 特徴 | IP パケットヘッダーの L3 アドレス（Inside/Outside Source/Destination）および L4 ポート（TCP/UDP）をルータ通過時にハードウェア/ソフトウェアで書き換え |
| 用途 | インターネット接続（PAT）、重複 IP ドメイン間通信（Static/Dynamic NAT）、VRF 間ルートリーク非依存の相互通信（VRF-Aware / VASI NAT） |
| メリット | パブリック IP アドレス節約、内部トポロジー隠蔽、重複 IP アドレス環境での容易な相互接続 |
| デメリット | パケット書き換えによる CPU/ASIC オーバーヘッド、IPsec/E2E 暗号化やアプリケーション層プロトコル（SIP, FTP 等の ALGs 依存）との不整合、ステート管理の複雑化 |
| 対応機種 | Cisco Catalyst 9000 シリーズ (IOS XE)、Cisco ISR 4000 / ASR 1000 シリーズ、Cisco Catalyst 8000V |
| 制限事項 | CEF (Cisco Express Forwarding) 必須。非対称ルーティング環境におけるステート不一致、重複ポート割り当て限界（1 アドレスあたり 64,512 セッション） |
| 設計上の注意点 | NAT 処理順序（Inside->Outside は Routing 前、Outside->Inside は Routing 後）の把握、VRF テーブル間のルーティング依存関係、VASI pair インターフェイス設計 |

---

## 🏗 動作原理

Cisco IOS XE における NAT は、インターフェイスに指定された `ip nat inside` および `ip nat outside`（または `ip nat enable` による NVI モード）の境界に基づいてパケットを判定する。

### 1. 概念モデル（4 つのアドレス概念）
* **Inside Local (IL)**: 内部ネットワーク上のホストに割り当てられた実際の IP アドレス（通常はプライベート IP）。
* **Inside Global (IG)**: 外部ネットワークから見て、内部ホストを表す変換後の IP アドレス（パブリック IP またはルート可能な IP）。
* **Outside Local (OL)**: 内部ネットワークから見て、外部ホストを表す IP アドレス（内部から到達可能な見かけの IP）。
* **Outside Global (OG)**: 外部ネットワーク上のホストに実際に割り当てられている IP アドレス。

```
+-------------------+                    +-------------------+
|   Inside Host     |                    |   Outside Host    |
| (Inside Local)    |                    | (Outside Global)  |
| 192.168.10.100    |                    | 203.0.113.50      |
+---------+---------+                    +---------+---------+
          |                                        |
          |  [Inside]                    [Outside] |
          +-----------+  Cisco Router  +-----------+
                      | (NAT Gateway)  |
                      +----------------+
                 Inside Global  : 198.51.100.10
                 Outside Local  : 203.0.113.50 (通常は OG と同等)
```

### 2. 主要変換タイプ
1. **Static NAT / PAT**: 1対1（Static NAT）または特定 L4 ポートの固定マッピング（Static PAT/Port Forwarding）。
2. **Dynamic NAT**: アドレスプール (`ip nat pool`) から動的に空き IP を割り当て（1対1の動的割り当て）。
3. **Dynamic PAT (Overload)**: 1 つまたは少数の IP アドレスに L4 送信元ポート番号を変更して多数の内部ホストを同時収容。
4. **Policy-based NAT**: アクセスリスト（ACL）や Route-Map を用いて、送信元/宛先 IP、L4 ポート、DSCP などの複合条件に基づいて NAT 変換を動的適用。
5. **VRF-aware NAT**: 送信元/宛先インターフェイスが属する VRF 識別子（VRF Table）をコンテキストとして管理し、VRF ごとに分離された NAT テーブルを処理。
6. **VASI NAT**: 仮想インターフェイスペア（vasileft / vasiright）を通過させることで、明確に分離された 2 つの VRF ドメイン間でゾーンベースセキュリティやルーティングの複雑さを解消しつつ NAT を実行。

---

## ⚙ 動作シーケンス

Cisco IOS XE におけるパケット処理順序（NAT Order of Operation）は、パケットの進行方向（Inside-to-Outside か Outside-to-Inside か）によって厳密に定義されている。この順序を誤解することが CCIE ラボ試験におけるトラブルシューティングの最大の原因となる。

```
[Inside to Outside パケットフロー]
1. Ingress ACL チェック
2. Policy-Based Routing (PBR) 評価
3. 送信元 IP アドレスの変換 (NAT / Inside Local -> Inside Global)
4. ルーティングテーブル (FIB) 検索 (宛先 IP に基づく Egress I/F 決定)
5. Egress ACL チェック
6. 暗号化 (IPsec Encapsulation)
7. Egress インターフェイス送信

[Outside to Inside パケットフロー]
1. Ingress ACL チェック
2. ルーティングテーブル (FIB) 検索 (宛先 IP/Outside Global に基づく Egress I/F 決定)
3. 宛先 IP アドレスの変換 (NAT / Outside Global -> Outside Local / Inside Global -> Inside Local)
4. Egress ACL チェック
5. Egress インターフェイス送信
```

### パケット処理の注意点
* **Inside ➔ Outside 通信**: パケットがルータに入力された直後、**ルーティング検索が行われる前**に Inside Local アドレスが Inside Global アドレスに変換される。したがって、ルーティングテーブル（FIB）は **変換後の Inside Global アドレス** を宛先/送信元として評価するのではなく、宛先は Outside Global のまま、送信元が Inside Global に化けた状態でルート検索される。
* **Outside ➔ Inside 通信**: パケットがルータに入力された直後、**まずルーティング検索** が行われる。その後、NAT テーブルと照合して宛先 IP（Inside Global）が Inside Local に変換される。したがって、Outside インターフェイスに入力された時点で、変換後の Inside Local 宛てのルートが FIB に存在しない場合、パケットは NAT 変換される前にドロップされる。

---
## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI v1.1 ラボ試験における NAT の出題は、単なる `ip nat inside source list ...` の設定にとどまらず、複雑なネットワーク要件と制約条件（Constraints）を伴って出題される。

### Blueprintで重要なポイント
1. **VRF-Aware NAT / PAT**:
   * VRF 内の端末が Global イーサネット WAN や別の VRF を経由して通信する際、`ip nat inside source list <ACL> pool <POOL> vrf <VRF_NAME> overload` や `interface <INT> vrf <VRF_NAME>` を適切に設定できるか。
   * ACL に定義する IP アドレス（Inside Local）と VRF の紐付け。
2. **Policy-based NAT / PAT**:
   * 単純な IP アドレス単位ではなく、宛先 IP や L4 ポート番号、特定の宛先サービスに応じて変換後 IP（または変換の有無）を切り替える Route-Map ベースの NAT。
   * `ip nat inside source route-map <MAP_NAME> pool <POOL_NAME> overload` の構築。
   * Route-Map 内の `match ip address <ACL>` における Standard ACL vs Extended ACL の評価動作の違い。
3. **VRF-aware Software Infrastructure (VASI) NAT**:
   * 2 つの VRF ドメイン（例: VRF Red と VRF Blue）間、または VRF と Global 間で、ルーティングの直接リークを許可せずに VASI インターフェイスペア (`vasileftX` / `vasirightX`) を介して双方向 Static/Dynamic NAT を行う高度設定。
4. **No-Alias (alias なし) NAT**:
   * Static NAT を設定した際、ルータが自動的に Inside Global アドレスに対する ARP 応答（Alias）を生成するのを防止する `no-alias` キーワードの理解（特定のファイアウォールや HSRP/VRRP 連携時に必須）。

### よくある設定ミス ＆ 狙われやすいポイント
* **Outside ➔ Inside 通信でのルーティング不備**:
  * Outside ➔ Inside 通信では **NAT 変換前にルーティング検索** が行われるため、ルータ上に変換前宛先 IP（Inside Global）に対する適切なルート（または Null0 へのスタティックルート / Loopback）が存在しないと、パケットが即座にドロップされる。
* **Route-Map ベース NAT における Extended ACL の罠**:
  * Route-Map で NAT を行う場合、`match ip address` で指定する Extended ACL の `permit ip <SRC> <DST>` は、「<SRC> から <DST> へのパケットを NAT 変換対象とする」という意味になる。`deny` 行を書いた場合、「NAT 変換せず素通しする」動作となる。
* **VRF-Aware NAT における ACL のプール検索失敗**:
  * `ip nat inside source list <ACL> pool <POOL> vrf <VRF>` を指定する際、ACL の送信元 IP アドレスが該当 VRF のインターフェイスのアドレス空間と一致していない場合や、`overload` が抜けていてプールアドレスが枯渇するケース。
* **Overlapping Subnets (重複サブネット) 救済での `match-in-vrf`**:
  * 同一ルータ上で複数の VRF が同じプライベート IP 体系（例: 10.1.1.0/24）を使用している場合、`ip nat pool` に `match-in-vrf` を付与しないと、異なる VRF 間でプールアドレスが衝突・誤マッピングされる。

---

## 🛠 設定方法

### 1. Static NAT / PAT (Port Forwarding)
```text
! 基本的な Static 1対1 NAT
ip nat inside source static 192.168.10.50 203.0.113.50

! Static PAT (Port Forwarding) - Web サーバー (TCP 80)
ip nat inside source static tcp 192.168.10.80 80 203.0.113.50 80 extendable

! ARP 応答を自動停止する no-alias 構成
ip nat inside source static 192.168.10.90 203.0.113.90 no-alias
```

### 2. Dynamic NAT / Dynamic PAT (Overload)
```text
! 変換対象トラフィックの定義
ip access-list standard ACL_NAT_INSIDE
 permit 192.168.10.0 0.0.0.255

! Dynamic PAT (Interface Overload)
interface GigabitEthernet0/0/0
 description Inside Interface
 ip address 192.168.10.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 description Outside WAN Interface
 ip address 203.0.113.1 255.255.255.0
 ip nat outside
!
ip nat inside source list ACL_NAT_INSIDE interface GigabitEthernet0/0/1 overload
```

### 3. Policy-Based NAT (Route-Map ベース NAT)
```text
! 特定の宛先 (198.51.100.0/24) 向けの通信のみ NAT 変換する ACL
ip access-list extended ACL_POLICY_NAT
 permit ip 192.168.10.0 0.0.0.255 198.51.100.0 0.0.0.255

route-map RM_POLICY_NAT permit 10
 match ip address ACL_POLICY_NAT

! アドレスプールの作成
ip nat pool POOL_POLICY 203.0.113.100 203.0.113.105 prefix-length 29

! Policy-Based NAT の適用
ip nat inside source route-map RM_POLICY_NAT pool POOL_POLICY overload
```

### 4. VRF-Aware NAT / PAT
```text
vrf definition RED
 rd 65000:10
 address-family ipv4
 exit-address-family

interface GigabitEthernet0/0/0.10
 vrf forwarding RED
 ip address 10.10.10.1 255.255.255.0
 ip nat inside

interface GigabitEthernet0/0/1
 ip address 203.0.113.1 255.255.255.0
 ip nat outside

ip access-list standard ACL_VRF_RED
 permit 10.10.10.0 0.0.0.255

! VRF 名を明示指定した Dynamic PAT
ip nat inside source list ACL_VRF_RED interface GigabitEthernet0/0/1 vrf RED overload
```

### 5. VRF-Aware Software Infrastructure (VASI) NAT
```text
! 2 つの VRF 定義
vrf definition TENANT_A
 rd 65000:100
 address-family ipv4
!
vrf definition SHARED_SVC
 rd 65000:200
 address-family ipv4

! VASI ペアの有効化
interface vasileft1
 vrf forwarding TENANT_A
 ip address 172.16.1.1 255.255.255.252
 ip nat inside
!
interface vasiright1
 vrf forwarding SHARED_SVC
 ip address 172.16.1.2 255.255.255.252
 ip nat outside

! VASI 上での Static NAT 設定
ip nat inside source static 10.1.1.50 172.16.1.50 vrf TENANT_A
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| アクティブな NAT 変換テーブルの確認 | <code>show ip nat translations</code> |
| 統計情報・インターフェイス割当の確認 | <code>show ip nat statistics</code> |
| 特定 VRF の NAT 変換テーブル確認 | <code>show ip nat translations vrf RED</code> |
| NAT 変換テーブルの特定エントリ削除 | <code>clear ip nat translation *</code> |
| リアルタイム NAT 変換デバッグ | <code>debug ip nat [detailed]</code> |
| VRF-Aware NAT のデバッグ | <code>debug ip nat vrf RED</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| 内部から外部へのパケットが NAT 変換されない | インターフェイスの `ip nat inside` / `outside` 指定漏れ | <code>show ip nat statistics</code> | 対象インターフェイスに正しい NAT 方向 (`inside`/`outside`) を適用する |
| ACL にマッチしているはずの通信が NAT されない | Standard/Extended ACL の記述ミス、または Route-Map の match 失敗 | <code>show ip access-lists</code><br><code>show route-map</code> | ACL のカウント（match コント）を確認し、正しい送受信 IP/プロトコルを定義する |
| Outside ➔ Inside 通信でパケットがドロップされる | ルータ上に Inside Global アドレス宛てのルーティングが存在しない | <code>show ip route</code><br><code>show ip nat translations</code> | Inside Global アドレス帯域に対する Null0 または Loopback へのスタティックルートを追加する |
| VRF 内の端末から NAT 経由で外部へ通信できない | `ip nat inside source` に `vrf <NAME>` パラメータが欠落している | <code>show ip nat statistics</code><br><code>show ip nat translations vrf <NAME></code> | NAT 変換ルールに正しい VRF 名を付与する |
| アドレスプール枯渇により一部端末の通信が切断される | Dynamic NAT で `overload` キーワードが欠落している | <code>show ip nat statistics</code> | `ip nat inside source list ... pool ... overload` に `overload` を追記する |
| 重複サブネット環境で他 VRF の NAT プールと衝突する | `ip nat pool` に `match-in-vrf` オプションが設定されていない | <code>show ip nat pool</code> | プール定義に `match-in-vrf` を追加し、VRF ごとに分離する |

---

## ⚠ 制限事項

* **パフォーマンス制限**: ソフトウェア処理（IOS XE XE-daemon）による NAT 変換は高負荷時に CPU リソースを過度に消費する。Catalyst 9000 や ASR1000 では ハードウェア ASIC (QFP/UADP) による CEF ドライブ NAT が実行されるが、特定の複雑な ALG (Application Layer Gateway) や複雑な Route-Map 判定は punt されて CPU 処理となる。
* **スケール制限**: 1 つの PAT アドレス（IP 1 個）あたり利用可能な TCP/UDP ポート数は理論上約 64,512 (ポート 1024〜65535)。
* **非対称ルーティング非対応**: 往路と復路が異なるルータを通過する非対称ルーティング環境では、NAT ステートが同期されないため通信が不成立となる（HSRP/VRRP 環境での NAT 考慮が必須）。

---

## 🔄 他技術との関連

* **IPsec VPN / DMVPN**: NAT トラバース (NAT-T: UDP 4500) や、トンネル暗号化前に NAT 処理を行うかカプセル化後に行うかの順番関係。`qos pre-classify` や `ip nat inside` のアタッチポイントの設計。
* **VRF / MPLS L3VPN**: VRF 間のトラフィック分離を維持しつつインターネット接続を提供する VRF-Aware NAT や VASI 構成。
* **HSRP / VRRP (FHRP)**: FHRP 仮想 IP アドレスを NAT 送信元/プールとして使用する場合の `no-alias` や HSRP Stateful NAT (SNAT) の連動。
* **Zone-Based Firewall (ZBFW)**: ZBFW ポリシー（Pass/Drop/Inspect）と NAT 処理順序の相互作用。

---

## 🧩 比較表

| 項目 | Static NAT | Dynamic PAT (Overload) | VRF-Aware NAT | VASI NAT |
| --- | --- | --- | --- | --- |
| **変換方式** | 1 対 1 固定 | 多 対 1 (Port 変換) | VRF テーブル識別 1 対 1 / 多 対 1 | 仮想 I/F ペア通過型 NAT |
| **IP 節約効果** | なし（同数必要） | 絶大（1 IP で多数収容） | 用途に応じた設計 | 高い（VRF 間変換） |
| **双方向セッション** | 外部からの開始可能 | 内部からの開始のみ | 設定依存（Static/Dynamic） | 双方向開始可能 |
| **VRF 分離** | グローバルのみ（標準） | グローバルのみ（標準） | VRF タグ付きテーブル制御 | 完全な物理/仮想ドメイン分離 |
| **適した場面** | DMZ サーバー公開 | 社内 PC インターネット接続 | 複数テナントの共有 WAN 接続 | 重複 IP 企業併合・VRF 間 NAT |

---

## 💡 ベストプラクティス

1. **Outside ➔ Inside トラフィック向けのルーティング確保**:
   NAT プールアドレスや Static Inside Global アドレスに対しては、必ずルータ上で Null0 宛ての集約スタティックルートを設定し、ルーティングドメインへ再配布（Redistribute）してルータまでパケットを確実に引き込む。
2. **Overload キーワードの忘れ防止**:
   Dynamic NAT/PAT 構成時は、1 アドレスを共有するために必ず `overload` を付与する。
3. **Route-Map ベース NAT での Extended ACL 明示化**:
   NAT 用の Route-Map では、送信元・宛先・プロトコルを網羅した Extended ACL を使用し、意図しないトラフィックの誤変換を防ぐ。
4. **VRF 環境での VASI インターフェイスの活用**:
   複雑な VRF 間 NAT やルールの重複が発生する場合は、直観的かつ安全に管理できる VASI (`vasileft` / `vasiright`) を採用する。

---
## 📝 ラボ学習・設定サンプル例

### ラボ 1: Static 1対1 NAT ＋ Port Forwarding (Static PAT) 構成

#### 問題
企業 LAN 内の Web サーバー（`192.168.10.80`）および SSH サーバー（`192.168.10.22`）を、外部（インターネット）からパブリック IP アドレス `203.0.113.50` を介してアクセスできるように設定しなさい。

#### 要件
1. Web サーバー（TCP 80）は `203.0.113.50:80` でアクセス可能とすること。
2. SSH サーバー（TCP 22）は外部向けに TCP ポート `2222` (`203.0.113.50:2222`) としてポートフォワーディング（Static PAT）を設定すること。
3. 外部からパケットを引き込むため、`203.0.113.50/32` への Null0 ルートを作成すること。

#### 設定例
```text
! インターフェイス定義
interface GigabitEthernet0/0/0
 description Inside LAN
 ip address 192.168.10.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 description Outside WAN
 ip address 203.0.113.1 255.255.255.0
 ip nat outside

! Static PAT (Port Forwarding) 設定
ip nat inside source static tcp 192.168.10.80 80 203.0.113.50 80 extendable
ip nat inside source static tcp 192.168.10.22 22 203.0.113.50 2222 extendable

! ルーティング引き込み用の Null0 静的ルート
ip route 203.0.113.50 255.255.255.255 Null0
```

#### 検証方法
```text
! NAT 変換テーブルの確認
Router# show ip nat translations
Pro Inside global      Inside local       Outside local      Outside global
tcp 203.0.113.50:80    192.168.10.80:80   ---                ---
tcp 203.0.113.50:2222  192.168.10.22:22   ---                ---

! 外部端末から HTTP/SSH 接続後、動的セッションの確認
Router# show ip nat translations tcp
```

---

### ラボ 2: Dynamic PAT (Interface Overload) ＋ アドレスプール構成

#### 問題
社内クライアントセグメント（`10.100.0.0/16`）からのインターネット通信に対して、ルータの WAN インターフェイス IP アドレスを使用して Dynamic PAT (Overload) を設定しなさい。

#### 要件
1. 変換対象トラフィックは `10.100.0.0/16` のみとし、ACL `ACL_PAT_CLIENTS` で定義すること。
2. WAN インターフェイス `GigabitEthernet0/0/1` の IP アドレスに Overload 変換すること。
3. パケットカウントを検証すること。

#### 設定例
```text
! 変換対象 ACL の定義
ip access-list standard ACL_PAT_CLIENTS
 permit 10.100.0.0 0.0.255.255

! インターフェイス構成
interface GigabitEthernet0/0/0
 ip address 10.100.1.1 255.255.0.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 ip address 198.51.100.254 255.255.255.0
 ip nat outside

! Dynamic PAT (Interface Overload) 設定
ip nat inside source list ACL_PAT_CLIENTS interface GigabitEthernet0/0/1 overload
```

#### 検証方法
```text
! NAT 統計情報と変換数の確認
Router# show ip nat statistics
Total active translations: 15 (0 static, 15 dynamic; 15 extended)
Outside interfaces:
  GigabitEthernet0/0/1
Inside interfaces: 
  GigabitEthernet0/0/0
Hits: 1245  Misses: 15

! 変換テーブルの確認
Router# show ip nat translations
```

---

### ラボ 3: Route-Map ベースの Policy-Based NAT 構成

#### 問題
社内セグメント `172.16.0.0/16` からの通信のうち、データセンター宛て（`198.51.100.0/24`）の通信のみパブリック IP プールから NAT 変換し、その他の宛先への通信は NAT 変換しない構成を構築しなさい。

#### 要件
1. Route-Map `RM_NAT_POLICY` を作成し、Extended ACL `ACL_POLICY_NAT` を評価すること。
2. NAT プール `POOL_DC`（`203.0.113.10`〜`203.0.113.14` /29）を定義し、`overload` で変換すること。
3. 条件外の通信は NAT されずに通過すること。

#### 設定例
```text
! Extended ACL による定義 (Src: 172.16.0.0/16, Dst: 198.51.100.0/24)
ip access-list extended ACL_POLICY_NAT
 permit ip 172.16.0.0 0.0.255.255 198.51.100.0 0.0.255.255

! Route-Map の作成
route-map RM_NAT_POLICY permit 10
 match ip address ACL_POLICY_NAT

! アドレスプールの作成
ip nat pool POOL_DC 203.0.113.10 203.0.113.14 prefix-length 29

! Policy-Based NAT のアタッチ
ip nat inside source route-map RM_NAT_POLICY pool POOL_DC overload

! インターフェイス設定
interface GigabitEthernet0/0/0
 ip address 172.16.1.1 255.255.0.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 ip address 203.0.113.1 255.255.255.0
 ip nat outside
```

#### 検証方法
```text
! NAT 変換テーブルの確認（198.51.100.x 宛てのみがプール IP に変換されていること）
Router# show ip nat translations
Pro Inside global      Inside local       Outside local      Outside global
icmp 203.0.113.10:1    172.16.1.10:1      198.51.100.5:1     198.51.100.5:1
```

---

### ラボ 4: VRF-Aware Dynamic PAT 構成

#### 問題
マルチテナント環境において、`VRF_A` に属する端末群（`10.1.1.0/24`）がグローバル WAN インターフェイス `GigabitEthernet0/0/1` を共有してインターネットへ接続できるように VRF-Aware Dynamic PAT を構成しなさい。

#### 要件
1. `VRF_A` 定義を作成し、`GigabitEthernet0/0/0.10` に割り当てること。
2. ACL `ACL_VRF_A` で `10.1.1.0/24` を許可すること。
3. `ip nat inside source` に `vrf VRF_A` オプションを明示して PAT を適用すること。

#### 設定例
```text
! VRF 定義
vrf definition VRF_A
 rd 65000:100
 address-family ipv4
 exit-address-family

! インターフェイス設定
interface GigabitEthernet0/0/0.10
 encapsulation dot1Q 10
 vrf forwarding VRF_A
 ip address 10.1.1.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 ip address 203.0.113.1 255.255.255.0
 ip nat outside

! ACL ＋ VRF-Aware Dynamic PAT
ip access-list standard ACL_VRF_A
 permit 10.1.1.0 0.0.0.255

ip nat inside source list ACL_VRF_A interface GigabitEthernet0/0/1 vrf VRF_A overload
```

#### 検証方法
```text
! VRF 指定の NAT 変換テーブル確認
Router# show ip nat translations vrf VRF_A
Pro Inside global      Inside local       Outside local      Outside global
tcp 203.0.113.1:45123  10.1.1.50:5001     8.8.8.8:80         8.8.8.8:80
```

---

### ラボ 5: VRF-Aware Static NAT (VRF-to-Global 公開) 構成

#### 問題
`VRF_B` 内に配置された内部 DB サーバー（`10.2.2.100`）を、グローバルネットワーク宛てにパブリック IP `203.0.113.200` として Static NAT 公開しなさい。

#### 要件
1. `VRF_B` 内のホスト `10.2.2.100` を Inside Local アドレスとすること。
2. グローバル側の送信元アドレスを `203.0.113.200`（Inside Global）に Static マッピングすること。
3. `vrf VRF_B` パラメータを指定し、外部からのルーティングを保証するため Null0 ルートを作成すること。

#### 設定例
```text
! VRF 定義
vrf definition VRF_B
 rd 65000:200
 address-family ipv4
 exit-address-family

interface GigabitEthernet0/0/0.20
 encapsulation dot1Q 20
 vrf forwarding VRF_B
 ip address 10.2.2.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 ip address 203.0.113.1 255.255.255.0
 ip nat outside

! VRF-Aware Static NAT 設定
ip nat inside source static 10.2.2.100 203.0.113.200 vrf VRF_B

! パケット引き込みルート
ip route 203.0.113.200 255.255.255.255 Null0
```

#### 検証方法
```text
! VRF-Aware Static NAT エントリの検証
Router# show ip nat translations vrf VRF_B
Pro Inside global      Inside local       Outside local      Outside global
--- 203.0.113.200      10.2.2.100         ---                ---
```

---

### ラボ 6: VASI (VRF-aware Software Infrastructure) NAT による VRF 間重複 IP 相互接続

#### 問題
企業統合に伴い、`VRF_RED`（サブネット `10.1.1.0/24`）と `VRF_BLUE`（サブネット `10.1.1.0/24`）の間で重複 IP アドレスが発生している。VASI インターフェイスペアを用いて、双方のルーティングテーブルを汚染せずに通信できるように NAT を設定しなさい。

#### 要件
1. VASI インターフェイスペア `vasileft1`（`VRF_RED`）および `vasiright1`（`VRF_BLUE`）を作成すること。
2. `VRF_RED` 側のホスト `10.1.1.50` を、`VRF_BLUE` から見て `172.16.10.50` としてアクセス可能とすること。
3. VASI ペア上で NAT 変換を実行すること。

#### 設定例
```text
! VRF 定義
vrf definition VRF_RED
 rd 65000:10
 address-family ipv4
!
vrf definition VRF_BLUE
 rd 65000:20
 address-family ipv4

! VASI インターフェイスペアの設定
interface vasileft1
 vrf forwarding VRF_RED
 ip address 172.16.1.1 255.255.255.252
 ip nat inside
!
interface vasiright1
 vrf forwarding VRF_BLUE
 ip address 172.16.1.2 255.255.255.252
 ip nat outside

! Static NAT (VASI パス上での変換)
ip nat inside source static 10.1.1.50 172.16.10.50 vrf VRF_RED

! ルーティング設定 (VRF RED ➔ VASI への誘導)
ip route vrf VRF_BLUE 172.16.10.50 255.255.255.255 vasiright1
```

#### 検証方法
```text
! VASI 経由の NAT 変換セッション確認
Router# show ip nat translations vrf VRF_RED
Pro Inside global      Inside local       Outside local      Outside global
--- 172.16.10.50       10.1.1.50          ---                ---

! VRF BLUE 側からの ping 導通確認
Router# ping vrf VRF_BLUE 172.16.10.50
```

---

### ラボ 7: Outside Static NAT 構成

#### 問題
外部のクラウドサービスプロバイダの IP（`203.0.113.100`）を、社内 LAN からプライベート IP アドレス `10.254.254.100`（Outside Local）として透過アクセスできるように Outside Static NAT を設定しなさい。

#### 要件
1. 外部 IP `203.0.113.100`（Outside Global）を `10.254.254.100`（Outside Local）に変換すること。
2. 内部端末が `10.254.254.100` に通信を送った際、ルータで自動的に Outside 変換が行われること。

#### 設定例
```text
interface GigabitEthernet0/0/0
 description Inside LAN
 ip address 10.1.1.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 description Outside WAN
 ip address 198.51.100.1 255.255.255.0
 ip nat outside

! Outside Static NAT 設定
ip nat outside source static 203.0.113.100 10.254.254.100
```

#### 検証方法
```text
! Outside NAT 変換テーブルの確認
Router# show ip nat translations
Pro Inside global      Inside local       Outside local      Outside global
--- ---                ---                10.254.254.100     203.0.113.100

! 内部ホストから 10.254.254.100 への ping 実行とデバッグ確認
Router# debug ip nat
```

---

### ラボ 8: Static NAT `no-alias` 構成 (HSRP 連携)

#### 問題
ルータ R1 および R2 で HSRP 冗長化を行っている環境において、R1 上で Inside Server `192.168.1.100` を パブリック IP `203.0.113.100` として Static NAT 設定しなさい。ただし、ルータ自身が ARP 応答を返さず、HSRP 仮想 IP アドレス層で ARP 応答を処理させるため `no-alias` を適用しなさい。

#### 要件
1. Static NAT 設定に `no-alias` オプションを付与すること。
2. 外部網からのパケットは HSRP 仮想 IP を経由して正しく到達すること。

#### 設定例
```text
interface GigabitEthernet0/0/0
 ip address 192.168.1.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 ip address 203.0.113.2 255.255.255.0
 ip nat outside
 standby 1 ip 203.0.113.1
 standby 1 priority 110

! no-alias を付与した Static NAT
ip nat inside source static 192.168.1.100 203.0.113.100 no-alias
```

#### 検証方法
```text
! NAT アライアス（自動生成 ARP 応答）テーブルに 203.0.113.100 が存在しないことを確認
Router# show ip alias
```

---

### ラボ 9: 重複サブネット救済 (VRF-Aware Dynamic NAT with `match-in-vrf`)

#### 問題
`VRF_1`（`10.0.0.0/24`）と `VRF_2`（`10.0.0.0/24`）の 2 つのテナントが、それぞれ固有の NAT プール（`POOL_V1`: `203.0.113.1-5` / `POOL_V2`: `203.0.113.6-10`）を使用して外部へ接続するように設定しなさい。VRF 間のプール干渉を防ぐため `match-in-vrf` を使用しなさい。

#### 要件
1. アドレスプール `POOL_V1` および `POOL_V2` に `match-in-vrf` を設定すること。
2. VRF ごとに独立してアドレス変換を動的実行すること。

#### 設定例
```text
vrf definition VRF_1
 address-family ipv4
!
vrf definition VRF_2
 address-family ipv4

! match-in-vrf オプション付きプール
ip nat pool POOL_V1 203.0.113.1 203.0.113.5 prefix-length 29 match-in-vrf
ip nat pool POOL_V2 203.0.113.6 203.0.113.10 prefix-length 29 match-in-vrf

ip access-list standard ACL_ALL
 permit 10.0.0.0 0.0.0.255

! VRF 別の Dynamic NAT
ip nat inside source list ACL_ALL pool POOL_V1 vrf VRF_1 overload
ip nat inside source list ACL_ALL pool POOL_V2 vrf VRF_2 overload
```

#### 検証方法
```text
! 各 VRF のプール消費状況の確認
Router# show ip nat pool
```

---

### ラボ 10: Dual WAN / Dual ISP 環境における Destination/Source 複合 Policy NAT

#### 問題
マルチホーム環境において、内部端末 `192.168.10.0/24` が ISP1 宛て（`198.51.100.0/24`）に通信する際は WAN1 IP（`203.0.113.1`）へ、ISP2 宛て（`203.0.113.128/25`）に通信する際は WAN2 IP（`198.51.100.1`）へ動的に Source PAT 変換されるよう Policy NAT を設定しなさい。

#### 要件
1. 2 つの Route-Map（`RM_ISP1`, `RM_ISP2`）を作成すること。
2. それぞれの WAN インターフェイスのアドレスに Overload 変換すること。

#### 設定例
```text
! Extended ACLs
ip access-list extended ACL_TO_ISP1
 permit ip 192.168.10.0 0.0.0.255 198.51.100.0 0.0.0.255

ip access-list extended ACL_TO_ISP2
 permit ip 192.168.10.0 0.0.0.255 203.0.113.128 0.0.0.127

! Route-Maps
route-map RM_ISP1 permit 10
 match ip address ACL_TO_ISP1
!
route-map RM_ISP2 permit 10
 match ip address ACL_TO_ISP2

! Policy NAT 設定
ip nat inside source route-map RM_ISP1 interface GigabitEthernet0/0/1 overload
ip nat inside source route-map RM_ISP2 interface GigabitEthernet0/0/2 overload

! インターフェイス構成
interface GigabitEthernet0/0/0
 ip address 192.168.10.1 255.255.255.0
 ip nat inside
!
interface GigabitEthernet0/0/1
 ip address 203.0.113.1 255.255.255.0
 ip nat outside
!
interface GigabitEthernet0/0/2
 ip address 198.51.100.1 255.255.255.0
 ip nat outside
```

#### 検証方法
```text
! 宛先に応じた NAT 送信元 IP の変換検証
Router# show ip nat translations
```

---
## ❓ 想定試験問題

### 問 1 (コンフィグ読解・トラブルシューティング)
以下のコンフィグを適用したルータにおいて、内部端末 `10.1.1.50` から外部サーバー `203.0.113.10` への HTTP (TCP 80) 通信を試みたが、通信が成立しない。`show ip nat statistics` では Hits カウントが増加していない。原因として最も適切なものを 1 つ選べ。

```text
ip access-list extended ACL_NAT
 permit tcp host 10.1.1.50 host 203.0.113.10 eq 80

route-map RM_NAT permit 10
 match ip address ACL_NAT

ip nat inside source route-map RM_NAT interface GigabitEthernet0/0/1 overload

interface GigabitEthernet0/0/0
 ip address 10.1.1.1 255.255.255.0
!
interface GigabitEthernet0/0/1
 ip address 198.51.100.1 255.255.255.0
 ip nat outside
```

A) Route-Map に `set` コマンドが記述されていないため。  
B) `GigabitEthernet0/0/0` インターフェイスに `ip nat inside` コマンドの設定が欠落しているため。  
C) Extended ACL でプロトコルを `tcp` に限定しているため。  
D) インターフェイス `GigabitEthernet0/0/1` で `ip nat outside` の代わりに `ip nat enable` を使用すべきであるため。

**正解**: **B**  
**解説**: NAT 処理が発生するためには、パケットが入力されるインバウンドインターフェイスに `ip nat inside`（または `ip nat outside`）が正しく適用されている必要がある。`GigabitEthernet0/0/0` に `ip nat inside` が設定されていないため、パケットは NAT エンジンに渡されず素通し（またはドロップ）され、Hits カウントも増加しない。

---

### 問 2 (Design / VRF-Aware NAT)
企業網において、複数テナント（VRF RED / VRF BLUE）のプライベート端末群から、単一のグローバル WAN インターフェイス（`203.0.113.1`）を経由してインターネットへ接続させる構成を設計している。両 VRF で内部 IP アドレス空間（`10.0.0.0/24`）が重複している場合、ルータで NAT プールアドレスの重複衝突を回避するための設計として最も推奨される設定はどれか。

A) 各 VRF ごとに独立した物理 WAN インターフェイスを用意する。  
B) NAT プール定義に `match-in-vrf` オプションを付加し、VRF ごとに分離された NAT テーブルで管理する。  
C) `ip nat inside source static` を使用して全端末を個別固定変換する。  
D) VRF 間で BGP ピアを確立し、ルートリークを実行する。

**正解**: **B**  
**解説**: `ip nat pool` に `match-in-vrf` オプションを指定することで、同じパブリック IP プールや同じサブネットが複数の VRF で使用された場合でも、ルータは内部的に VRF ID をバインドした分離テーブルを保持し、アドレスの衝突や誤マッピングを防止できる。

---

### 問 3 (トラブルシューティング / Outside ➔ Inside 通信)
管理者がある内部サーバー（`10.1.1.100`）に対して外部公開用の Static NAT（`ip nat inside source static 10.1.1.100 203.0.113.100`）を設定した。外部端末から `203.0.113.100` 宛てに ping を実行したところ、ルータの Outside インターフェイスでパケットは受信されているが、NAT 変換されずにパケットがドロップされた。ルータ上で不足している設定はどれか。

A) `ip nat outside source static` コマンドの設定  
B) Inside サーバー上のデフォルトゲートウェイ設定  
C) ルータ上の `203.0.113.100`（Inside Global アドレス）に対するルーティングエントリ（Null0 ルート等）  
D) `ip nat inside source static` への `overload` キーワードの追加

**正解**: **C**  
**解説**: Outside ➔ Inside 通信における IOS XE の処理順序は **「ルーティング検索 (FIB) ➔ NAT 変換」** である。パケットが Outside インターフェイスに入力された時点で、変換前宛先 IP である `203.0.113.100` 宛てのルートがルータの FIB テーブルに存在しない場合、パケットは NAT 変換処理に到達する前にルーティング不能として即座にドロップされる。これを防ぐため、`ip route 203.0.113.100 255.255.255.255 Null0` 等のルートが必要となる。

---

### 問 4 (実装 / VASI NAT)
2 つの異なる VRF（VRF_A と VRF_B）間で、直接のルートリークを許可せずに、特定の通信のみを NAT 変換して相互疎通させる要件がある。この要件を満たすために使用される IOS XE のインターフェイス技術はどれか。

A) Tunnel インターフェイス  
B) Loopback インターフェイス  
C) VASI (VRF-aware Software Infrastructure) ペアインターフェイス (`vasileft` / `vasiright`)  
D) Subinterfaces (802.1Q)

**正解**: **C**  
**解説**: VASI (`vasileftX` / `vasirightX`) は、VRF 間で直接ルーティングテーブルを結合・リークさせることなく、仮想的なインターフェイスペアを通過させることで安全に NAT 変換や Zone-Based Firewall (ZBFW) ポリシーを適用できる Cisco IOS XE 固有の機能である。

---

### 問 5 (コンフィグ読解 / Route-Map ベース NAT)
以下のコンフィグが適用されているルータにおいて、内部端末 `192.168.1.50` が `172.16.1.100` 宛てに通信を送信した。このトラフィックに対する NAT 処理の説明として正しいものはどれか。

```text
ip access-list extended ACL_NAT_FILTER
 deny ip 192.168.1.0 0.0.0.255 172.16.0.0 0.0.255.255
 permit ip 192.168.1.0 0.0.0.255 any

route-map RM_NAT permit 10
 match ip address ACL_NAT_FILTER

ip nat inside source route-map RM_NAT interface GigabitEthernet0/0/1 overload
```

A) `192.168.1.50` は GigabitEthernet0/0/1 の IP アドレスに NAT 変換される。  
B) パケットは NAT 変換されずに、元のアドレス（`192.168.1.50`）のままルーティング・送出される。  
C) ACL の `deny` 行にマッチしたため、パケットはルータで即座にドロップされる。  
D) NAT 変換テーブルのエントリが破棄され、エラーログが出力される。

**正解**: **B**  
**解説**: Route-Map ベースの NAT において、アタッチされた Extended ACL の `deny` 行にマッチしたパケットは、「パケットの破棄（Drop）」を意味するのではなく、**「NAT 変換対象から除外（Bypass）してそのままルーティングする」** ことを意味する。したがって、パケットはドロップされず非変換のまま送信される。

---

## 🔗 参考リソース

### Cisco 公式ドキュメント・ガイド
* **Cisco IOS XE 17.x IP Addressing: NAT Configuration Guide**
* **Cisco Command Reference: ip nat inside source**
* **VRF-Aware Dynamic NAT Configuration Example**
* **Configuring VRF-Aware Software Infrastructure (VASI)**
* **NAT Order of Operation Technical White Paper**

---

## 📝 **補足（Notes）**

### NAT 動作の記憶用チャート

```text
+-----------------------------------------------------------------------+
|                       IOS XE NAT 処理フロー                           |
+-----------------------------------------------------------------------+

[Inside -> Outside トラフィック]
  Inbound I/F (ip nat inside) 
        ↓
  1. Ingress ACL チェック
        ↓
  2. Policy-Based Routing (PBR)
        ↓
  3. NAT 変換 (Inside Local -> Inside Global)  ★ Routing より先！
        ↓
  4. ルーティングテーブル検索 (FIB)
        ↓
  5. Egress ACL チェック
        ↓
  Outbound I/F (ip nat outside)

[Outside -> Inside トラフィック]
  Inbound I/F (ip nat outside)
        ↓
  1. Ingress ACL チェック
        ↓
  2. ルーティングテーブル検索 (FIB)           ★ Routing が先！
        ↓
  3. NAT 変換 (Outside Global -> Outside Local / Inside Global -> Local)
        ↓
  4. Egress ACL チェック
        ↓
  Outbound I/F (ip nat inside)
```

### 覚えておくべき暗記ポイント
* **Outside ➔ Inside は Routing が先！**: 宛先（Inside Global）へのルートがルータ上にないと、NAT 変換前に即ドロップ。
* **Route-Map NAT の Extended ACL `deny` は Bypass**: パケット破棄ではなく「NAT 変換しない」動作。
* **`no-alias`**: Static NAT でルータが Inside Global IP に対する ARP 代理応答を出すのを止める（HSRP/FHRP 連携時必須）。
* **VASI**: VRF 間で安全かつルートリークなしで双方向 NAT を行う仮想インターフェイスペア (`vasileft` / `vasiright`)。

---


## 🔗 参考リンク

### Cisco Live 関連動画・スライド
*   [**BRKSEC-2001: Next-Generation NAT in IOS-XE**](https://www.ciscolive.com/global/on-demand-library.html?search=NAT)
*   [**BRKCCIE-3000: CCIE EI Lab Exam Overview - Infrastructure Services Section**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### Configuration ガイド
*   [**Cisco IOS XE 17.x: IP Addressing: NAT Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_nat/configuration/xe-17/nat-xe-17-book.html)
*   [**Configuring VRF-Aware Software Infrastructure (VASI)**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipaddr_nat/configuration/xe-16/nat-xe-16-book/iadnat-vrf-aware.html)

### テクニカルドキュメント・設定例
*   [**NAT Order of Operations (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/network-address-translation-nat/13772-12.html)
*   [**Static NAT/PAT and Dynamic NAT/PAT Comparison and Configuration**](https://www.cisco.com/c/en/us/support/docs/ip/network-address-translation-nat/iadnat-addr-consv.html)

---

## 📝 補足
- このメモは、CCIE EI 試験における IPv4 NAT の「ルーティングとの整合性」と「VRF 境界での振る舞い」を重点的に整理しています。特に **VASI NAT** はラボ試験で指定される可能性がある高度なトピックであるため、仮想ペアインターフェイスの概念を確実に理解してください。


