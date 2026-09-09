---
layout: default
title: 1.2.c-Policy-based-routing
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 3
---

# 1.2.c Policy-based routing (PBR)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 実技試験（Practical Exam）および筆記試験において、トラフィックエンジニアリングおよび標準ルーティングテーブル（RIB）の上書き制御を行う重要技術である **Policy-based routing (PBR: ポリシーベースルーティング)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

通常のIPルーティングは、パケットの **宛先IPアドレス（Destination IP Address）** のみを参照し、ルーティングテーブル（RIB/FIB）内の「最長一致の法則（Longest Prefix Match）」に従ってパケットの転送先（ネクストホップまたは送出インターフェイス）を決定します。

これに対して **Policy-based routing (PBR)** は、送信元IPアドレス、レイヤ4プロトコル（TCP/UDP）、ポート番号、パケット長、DSCP/CoS値などの柔軟な識別条件に基づき、**通常のルーティングテーブルの決定を制御・変更・上書きする技術** です。

### 主な利用目的
1. **マルチホーム/マルチISP環境におけるトラフィック分離:**
   特定グループ（例：役員PCや高帯域VLAN）のWeb通信（HTTP/HTTPS）を高速なISP-Aへ、その他の通信を標準のISP-Bへ転送。
2. **QoSマーキングおよびパス制御の統合:**
   音声・ビデオトラフィック（VoIP）のみを優先度の高いWANリンク（例：MPLS）へ誘導し、同時にDSCP/Precedence値を付け替える。
3. **セキュリティ/検知装置へのトラフィックリダイレクト:**
   特定ポートの通信のみを透過型プロキシサーバー、IDS/IPS、ファイアウォール（FW）アプライアンスへ迂回。
4. **VRF非依存/依存のトラフィック誘導:**
   通常ルーティングテーブルでは不可能な、送信元属性に基づく特定VRFや別インターフェイスへの強制フォワーディング。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 送信元IP、L4ポート、パケット長等の条件で宛先ルーティング（RIB）を完全に上書き・制御する。 |
| **用途** | マルチWANロードシェアリング、特定アプリケーションの特定リンク誘導、QoSリマーク結合、セキュリティリダイレクト。 |
| **メリット** | 宛先IPアドレスに依存せず、送信元・プロトコル単位で柔軟なパケットパス制御が可能。 |
| **デメリット** | 誤ったポリシー定義によるルーティングループ誘発。ハードウェア（TCAM）非対応構成時のCPU処理（Process Switching）高騰。 |
| **対応機種** | Catalyst 9000 シリーズ（Catalyst 9300/9400/9500）、Catalyst 8000v、ISR/ASR シリーズ（IOS-XE）。 |
| **制限事項** | 1. 物理/論理インターフェイスに入力されたトラフィック対象（Ingress PBR）。<br>2. ルータ自身が発生させたトラフィックは `ip local policy` が必須。<br>3. `set interface` は対向がPoint-to-Point（Serial, GRE, Tunnel）でのみ推奨。 |
| **設計上の注意点** | `set ip next-hop`（RIB無視）と `set ip default next-hop`（RIB優先）の動作順序の違いを理解することが試験合格の最重要ポイント。 |

---

## 🏗 動作原理

### 1. イングレスPBR (Normal PBR) vs ローカルPBR (Local PBR)

* **Ingress PBR (`ip policy route-map`):**
  インターフェイスに入力された（受信した）トラフィックに対して適用されます。
* **Local PBR (`ip local policy route-map`):**
  ルータ・スイッチ自身（コントロールプレーン）から発生したトラフィック（例：ルータが送信するPING、SNMP、NTP、BGP/OSPFコントロールパケット等）に対して適用されます。グローバルコンフィグレーションで設定します。

```text
[ 外部からのパケット ] ➔ [ Ingress Interface ] ➔ [ Ingress PBR (ip policy route-map) ]
                                                            │
                                                            ├─► Match ➔ PBRアクション実行 (set ip next-hop等)
                                                            └─► Miss  ➔ 通常のRIB/FIBルーティング
                                                            
[ ルータ自身からのパケット ] ➔ [ Local PBR (ip local policy) ]
                                         │
                                         ├─► Match ➔ PBRアクション実行
                                         └─► Miss  ➔ 通常のRIB/FIBルーティング
```

### 2. `set ip next-hop` と `set ip default next-hop` の決定的な動作差

PBRにおいて最も出題頻度が高く、実装上の落とし穴となるのがこれら2つのアクションの判定シーケンスの違いです。

```text
【 set ip next-hop <IP> の場合 】
パケット受信
   ↓
PBR Route-map Match ?
   ↓ (Yes)
通常のルーティングテーブル（RIB）を無視し、即座に <IP> へ転送！
（※ ただし指定した <IP> がARP/CEFテーブルで解決できない場合のみ、通常のRIB検索へフォールバック）


【 set ip default next-hop <IP> の場合 】
パケット受信
   ↓
PBR Route-map Match ?
   ↓ (Yes)
通常のルーティングテーブル（RIB）を先に検索！
   ↓
明示的なルート（特定サブネットの具体ルート /24 など）がRIBに存在するか？
   ├─► 存在する ➔ 通常のRIBに従って転送（PBRの set は無視される！）
   └─► 存在しない（デフォルトルート 0.0.0.0/0 しかない、またはルートなし）
           ↓
       PBRの set ip default next-hop <IP> が適用され、指定先へ転送！
```

---

## ⚙ 動作シーケンス

受信パケットがPBR対応インターフェイスに入力されてから、送信バッファに送出されるまでのIOS-XE/ASIC内部の処理シーケンスを示します。

```text
( インターフェイスでIPパケットを受信 )
       │
       ▼
[ インターフェイスに `ip policy route-map` がバインドされているか？ ]
       │
       ├─► No  ➔ 【通常のCEFフォワーディング（RIB/FIB検索）】
       │
       └─► Yes ➔ [ Route-Map の Sequence 順に Match 条件を評価 ]
                    │
                    ├─► Match (permit) ➔ [ set アクションの実行 ]
                    │                         │
                    │                         ├─► `set ip next-hop` ➔ PBR指定ネクストホップへ強制転送
                    │                         ├─► `set ip default next-hop` ➔ RIBに明示ルートがあればRIB優先、無ければPBRネクストホップへ
                    │                         └─► `set ip vrf` ➔ 指定VRFテーブルへパケットを移送して再検索
                    │
                    ├─► Match (deny) ➔ 【PBR評価を中断し、通常のCEFフォワーディング（RIB検索）へ】
                    │
                    └─► No Match (リスト末尾まで不一致) ➔ 【通常のCEFフォワーディング（RIB検索）へ】
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI実技ラボ試験では、単に「PBRを設定せよ」という問題が出されることは稀で、**複雑な条件（条件付きフェイルオーバー、特定トラフィックのバイパス、VRF間リーク等）と組み合わせた制約問題** として出題されます。

### 1. `set ip next-hop verify-availability` と IP SLA Tracking
* **試験要件例:**
  「R1のGi0/1で受信したVLAN 10からのトラフィックは、プライマリとして 10.1.14.4 へPBRで転送せよ。ただし、ネクストホップ 10.1.14.4 がダウン（Reachability障害）した場合は、自動的にセカンダリ 10.1.15.5 へ切り替え、両方ダウンした場合は通常のルーティングテーブルに従わせること」
* **設定の組み合わせ:**
  ```bash
  ip sla 1
   icmp-echo 10.1.14.4
   frequency 5
  ip sla schedule 1 start-time now life forever
  
  track 1 ip sla 1 reachability
  
  route-map PBR_POLICY permit 10
   match ip address ACL_VLAN10
   set ip next-hop verify-availability 10.1.14.4 1 track 1
   set ip next-hop 10.1.15.5
  ```
* **注意点:** `set ip next-hop verify-availability` 内のパラメータ順序（`10.1.14.4` の後の `1` はシーケンス番号、`track 1` はトラックオブジェクト番号）を正しく理解しておくこと。

### 2. PBR における `permit` と `deny` の挙動の誤解
* **よくある誤解:** `route-map` の `deny` エントリに一致したパケットは「ドロップ（破棄）される」と思い込んでしまう。
* **正しい動作:** Route-mapの `deny` エントリに一致した場合、**「PBR（ポリシー制御）の適用が拒否される」** だけであり、パケット自体は破棄されず、**「通常のルーティングテーブル（RIB/CEF）による転送」へフォールバック** します。
* **パケットをドロップさせたい場合:** ACL内で `permit` して Route-map で `set interface Null0` を指定するか、PBRではなくACL/CoPPでドロップする必要があります。

### 3. Local PBR の設定漏れ
* **トラブルチケット例:**
  「R1自身が宛先 8.8.8.8 へ送信する ICMP PING パケットのみを、通常のデフォルトルートではなく Tunnel1 経由で送出させたいが、インターフェイスに `ip policy` を貼っても反映されない」
* **原因:** 外部から入力されるパケットではなく、ルータ自身が発生させるパケット（Locally generated traffic）には、インターフェイス単位の `ip policy route-map` は作用しません。
* **対策:** グローバルコンフィギュレーションモードで **`ip local policy route-map <NAME>`** を指定する必要があります。

### 4. CDP/CEF オフロードとハードウェア（TCAM）制限
* Cisco Catalyst 9000 シリーズなどのスイッチ環境では、PBRはハードウェア（SDMテンプレート / TCAM）で高速処理（Software/CEF Offload）されます。
* しかし、`set ip default next-hop` や、複雑な未サポート条件（特定のパケット長判定と複雑なQoS操作の組み合わせ等）を使用すると、ASICで処理できずに **CPUヘパケットがトラップ（Process Switching化）** され、高トラフィック時にCPU使用率が100%に高騰する障害が発生します。

---

## 🛠 設定方法

Cisco IOS-XE 17.x における PBR の各種実装パターンです。

### 1. 標準的な Ingress PBR (ソースIP/ポートベース)

```bash
# 1. 識別用ACLの作成
ip access-list extended ACL_HTTP_TRAFFIC
 permit tcp 192.168.10.0 0.0.0.255 any eq www
 permit tcp 192.168.10.0 0.0.0.255 any eq 443

# 2. Route-mapの定義
route-map RM_PBR_HTTP permit 10
 match ip address ACL_HTTP_TRAFFIC
 set ip next-hop 10.1.23.2

# 3. 受信インターフェイスへのバインド
interface GigabitEthernet0/0/1
 ip policy route-map RM_PBR_HTTP
```

### 2. IP SLA Tracking 結合型 PBR (動的ネクストホップ切り替え)

```bash
# SLAおよびTracking定義
ip sla 10
 icmp-echo 10.1.14.4 source-interface GigabitEthernet0/0/2
 frequency 5
ip sla schedule 10 start-time now life forever

track 10 ip sla 10 reachability

# Route-map定義 (トラック10がUPの時のみ10.1.14.4を使用、DOWN時は10.1.25.5へ)
route-map RM_PBR_HA permit 10
 match ip address ACL_DATA
 set ip next-hop verify-availability 10.1.14.4 1 track 10
 set ip next-hop 10.1.25.5
```

### 3. Local PBR (ルータ自身が発生させる通信の制御)

```bash
ip access-list extended ACL_LOCAL_PING
 permit icmp host 1.1.1.1 host 8.8.8.8

route-map RM_LOCAL_PBR permit 10
 match ip address ACL_LOCAL_PING
 set ip next-hop 10.1.12.2

# グローバルモードで適用
ip local policy route-map RM_LOCAL_PBR
```

### 4. VRF-aware PBR および Inter-VRF PBR

```bash
# VRF "RED" 内で受信したトラフィックを別VRF "BLUE" のネクストホップへ誘導
ip access-list extended ACL_VRF_LEAK
 permit ip 10.100.1.0 0.0.0.255 any

route-map RM_VRF_PBR permit 10
 match ip address ACL_VRF_LEAK
 set vrf BLUE
 set ip next-hop 10.200.1.254

interface GigabitEthernet0/0/1.100
 vrf forwarding RED
 ip address 10.100.1.1 255.255.255.0
 ip policy route-map RM_VRF_PBR
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスごとのPBR設定有無と、マッチ/転送パケット統計（Policyパケット数）の確認** | <code>show ip policy</code> |
| **Route-mapごとのMatch/Set条件および、PBRによって転送/パスされたパケット数のカウンタ確認** | <code>show route-map</code> |
| **PBRで使用されている IP SLA の稼働ステータス確認** | <code>show ip sla statistics</code> |
| **PBRと結合された Track オブジェクトの状態（UP/DOWN）確認** | <code>show track 10</code> |
| **Local PBR のグローバル適用状態の確認** | <code>show ip local policy</code> |
| **PBRのパケットマッチングおよびネゴシエーション動作のリアルタイムデバッグ** | <code>debug ip policy</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`ip policy` をバインドしたのに、該当パケットが全くPBRで転送されず通常のRIBに従ってしまう。** | 1. ACLの定義ミス（`permit`/`deny` の逆指定）。<br>2. 指定した `set ip next-hop` がARP解決できていない。<br>3. `set ip default next-hop` を使っており、RIBに具体ルートが存在している。 | `show route-map`<br>`show ip arp`<br>`debug ip policy` | 1. ACLで対象トラフィックが `permit` されているか確認。<br>2. ネクストホップアドレスへのL2疎通を確認。<br>3. `set ip next-hop` に変更するか、RIBのルートを確認する。 |
| **ルータ自身から送信したパケット（例：PING 8.8.8.8）にPBRが効かない。** | インターフェイス単位の `ip policy route-map` しか設定しておらず、Local PBR が未構成。 | `show ip local policy` | グローバルモードで `ip local policy route-map <NAME>` を設定する。 |
| **プライマリWAN障害時、PBRがセカンダリネクストホップへ自動切替（Failover）しない。** | `set ip next-hop` に `verify-availability` または IP SLA Tracking がバインドされていないため、リンクダウン以外の中間障害を検知できない。 | `show track`<br>`show ip sla statistics` | IP SLA と `track` オブジェクトを作成し、`set ip next-hop verify-availability <IP> <seq> track <ID>` を構成する。 |
| **PBRを大量トラフィックに適用した途端、スイッチのCPU使用率が100%になり通信が遅延する。** | ハードウェア（TCAM）で非サポートのアクションが含まれており、パケットがProcess Switchingに転落している。 | `show processes cpu history`<br>`show platform hardware fed switch active fwd-asic ...` | SDMテンプレートの確認、およびTCAMでハードウェア処理可能な単純な Match/Set 条件へ見直す。 |

---

## ⚠ 制限事項

1. **`set interface` の使用制限:**
   イーサネットなどのマルチアクセス（Broadcast）インターフェイスに対して `set interface GigabitEthernet0/0` のみを指定することは推奨されません（対向のMACアドレスを特定するために大量のProxy ARPが発生するか、転送に失敗します）。`set interface` は Point-to-Point リンク（Serial, HDLC, PPP, GRE Tunnel）でのみ使用してください。
2. **IPv4 と IPv6 のコマンド体系の違い:**
   IPv4 パケットには `ip policy route-map`、IPv6 パケットには `ipv6 policy route-map` を使用します。1つのインターフェイスに両方を同時にバインド可能です。
3. **VRF 内での PBR 制限:**
   VRFインターフェイスでPBRを動作させる場合、マッチさせるACL内のIPアドレスおよびネクストホップIPアドレスは、そのVRFのコンテキスト内で解決可能でなければなりません。

---

## 🔄 他技術との関連

* **IP SLA & Object Tracking:** PBRの静的ネクストホップに動的な健全性チェック（L3ヘルスチェック）を組み込み、自動フェイルオーバーを実現する必須コンビネーション。
* **QoS (MQC - Class-map / Policy-map):** PBRの `set ip dscp` や `set ip precedence` は、パケットのクラス分け（Classification）およびマーキング（Marking）手段としてQoSポリシーと連携する。
* **VRF-Lite & MPLS L3VPN:** `set vrf` アクションを利用して、特定のパケットを別VRFへ強制的に注入（VRF Leaking / Transit）させる際に利用される。

---

## 🧩 比較表

### `set ip next-hop` vs `set ip default next-hop`

| 比較項目 | `set ip next-hop` | `set ip default next-hop` |
| :--- | :--- | :--- |
| **ルーティングテーブル（RIB）との評価順序** | **PBRが完全優先**（RIBを無視して指定IPへ転送） | **通常のRIBが優先**（RIBに明示ルートがあればRIBに従う） |
| **デフォルトルート (0.0.0.0/0) との関係** | デフォルトルートの有無に関わらず PBR が優先 | RIBに **デフォルトルートしか存在しない場合** のみ PBR が適用される |
| **主なユースケース** | 特定のトラフィックを完全強制的に特定回線へ流したい場合 | RIBに個別ルート（/24等）が無い野良トラフィックのみをバックアップ回線へ逃がす場合 |
| **CEF ハードウェア処理** | 完全対応（Catalyst等でTCAM処理可能） | 機種やIOS-XEバージョンによりCPU処理へトラップされるリスクあり |

---

## 💡 ベストプラクティス

1. **ACLは必ず `permit` で意図したパケットのみを指定する:**
   PBR用ACLの末尾にある暗黙の `deny any` により、マッチしなかったトラフィックは安全に通常のRIBルーティングへと引き渡されます。Route-map内で不要な `deny` エントリを大量に作成すると可読性と保守性が著しく低下します。
2. **ネクストホップの死活監視（IP SLA）を必ず伴わせる:**
   静的な `set ip next-hop 10.1.1.1` のみでは、ネクストホップルータの先（WAN側）で障害が起きた際にパケットがブラックホール化します。必ず `verify-availability` を組み合わせて迂回経路を確保してください。
3. **`show route-map` のカウンタで動作検証する:**
   設定後は `show route-map` コマンドで、意図した sequence 番号の `policy matches` カウンタが増加しているかを確認することで、ポリシーが正しくヒットしているかを即座に判別できます。

---

## 📝 ラボ学習・設定サンプル例

### 1. 源IPベースのPBR（特定VLAN通信をISP-2へ誘導）
**【問題】**
R1の Gi0/0/1 で受信する 192.168.20.0/24（VLAN 20）からのトラフィックを、通常のデフォルトルート（10.1.12.2）ではなく、ネクストホップ 10.1.14.4（ISP-2）へ転送してください。

```bash
ip access-list extended ACL_VLAN20
 permit ip 192.168.20.0 0.0.0.255 any

route-map RM_PBR_VLAN20 permit 10
 match ip address ACL_VLAN20
 set ip next-hop 10.1.14.4

interface GigabitEthernet0/0/1
 ip policy route-map RM_PBR_VLAN20
```
**【検証方法】**
```bash
R1# show ip policy
R1# show route-map RM_PBR_VLAN20
```

---

### 2. ポート番号（L4）ベースのPBR（HTTP/HTTPS通信のみ別経路へ転送）
**【問題】**
10.1.0.0/16 ネットワークから送出される Web トラフィック（TCP 80, 443）のみを、ネクストホップ 10.1.99.9（Webプロキシ）へ誘導してください。

```bash
ip access-list extended ACL_WEB_ONLY
 permit tcp 10.1.0.0 0.0.255.255 any eq www
 permit tcp 10.1.0.0 0.0.255.255 any eq 443

route-map RM_PBR_WEB permit 10
 match ip address ACL_WEB_ONLY
 set ip next-hop 10.1.99.9

interface GigabitEthernet0/0/2
 ip policy route-map RM_PBR_WEB
```
**【検証方法】**
```bash
R1# show route-map RM_PBR_WEB
# 送信元PCから HTTP 通信を発生させ、policy matches カウンタの上昇を確認。
```

---

### 3. パケット長ベースのPBR（大容量パケットの別回線迂回）
**【問題】**
パケットサイズが 1000 バイト以上の大きなパケット（データ転送等）をネクストホップ 10.1.55.5 へ転送し、小サイズパケット（音声等）は通常のルーティングに従わせてください。

```bash
route-map RM_PBR_LENGTH permit 10
 match length 1000 9000
 set ip next-hop 10.1.55.5

interface GigabitEthernet0/0/1
 ip policy route-map RM_PBR_LENGTH
```
**【検証方法】**
```bash
# 送信元よりサイズを変えてPINGを送信
# PC# ping 10.2.2.2 size 1200
R1# show route-map RM_PBR_LENGTH
```

---

### 4. `set ip default next-hop` による未登録トラフィックの逃がし
**【問題】**
ルーティングテーブルに明示的な宛先ルート（/24等）が存在するパケットは通常のRIBに従わせ、ルーティングテーブル内に明示的ルートが存在しないパケット（デフォルトルートにマッチするパケット）のみをネクストホップ 10.1.88.8 へ転送してください。

```bash
ip access-list extended ACL_ALL_DATA
 permit ip 172.16.0.0 0.0.255.255 any

route-map RM_PBR_DEFAULT permit 10
 match ip address ACL_ALL_DATA
 set ip default next-hop 10.1.88.8

interface GigabitEthernet0/0/1
 ip policy route-map RM_PBR_DEFAULT
```
**【検証方法】**
```bash
R1# show ip route
# 明示的ルート宛ての通信と、宛先不明（デフォルト宛て）の通信を発生させ、転送パスの相違を確認。
```

---

### 5. IP SLA Track と結合した動的ネクストホップ切り替え
**【問題】**
192.168.1.0/24 からのトラフィックを通常 10.1.12.2 へPBRで転送し、10.1.12.2 が応答停止（IP SLAダウン）した場合は自動的に 10.1.13.3 へ切り替えてください。

```bash
ip sla 1
 icmp-echo 10.1.12.2
 frequency 5
ip sla schedule 1 start-time now life forever

track 1 ip sla 1 reachability

ip access-list extended ACL_SITE1
 permit ip 192.168.1.0 0.0.0.255 any

route-map RM_PBR_SLA permit 10
 match ip address ACL_SITE1
 set ip next-hop verify-availability 10.1.12.2 1 track 1
 set ip next-hop 10.1.13.3

interface GigabitEthernet0/0/1
 ip policy route-map RM_PBR_SLA
```
**【検証方法】**
```bash
R1# show track 1
R1# show route-map RM_PBR_SLA
# 10.1.12.2 をダウンさせて 10.1.13.3 へ切り替わるか確認。
```

---

### 6. Local PBR (自発トラフィックの強制経路変更)
**【問題】**
R1自身から 8.8.8.8 へ送信されるすべての ICMP トラフィックのネクストホップを、静的に 10.1.14.4 へ変更してください。

```bash
ip access-list extended ACL_LOCAL_ICMP
 permit icmp any host 8.8.8.8

route-map RM_LOCAL_POLICY permit 10
 match ip address ACL_LOCAL_ICMP
 set ip next-hop 10.1.14.4

ip local policy route-map RM_LOCAL_POLICY
```
**【検証方法】**
```bash
R1# debug ip policy
R1# ping 8.8.8.8
# デバッグログで "policy match" および "setting nh to 10.1.14.4" を確認。
```

---

### 7. PBR による DSCP マーキングとネクストホップ設定の同時適用
**【問題】**
送信元 10.50.0.0/16 からの音声通信（UDP 16384-32767）に対し、DSCP 値を `EF (46)` にリマークし、かつ優先WANネクストホップ 10.1.77.7 へ転送してください。

```bash
ip access-list extended ACL_VOICE
 permit udp 10.50.0.0 0.0.255.255 any range 16384 32767

route-map RM_VOICE_PBR permit 10
 match ip address ACL_VOICE
 set ip dscp ef
 set ip next-hop 10.1.77.7

interface GigabitEthernet0/0/1
 ip policy route-map RM_VOICE_PBR
```
**【検証方法】**
```bash
R1# show route-map RM_VOICE_PBR
# 対向ルータでパケットキャプチャを行い、DSCPヘッダーが EF にリマークされているか確認。
```

---

### 8. VRF-aware Ingress PBR
**【問題】**
VRF "GUEST" に所属するインターフェイス Gi0/0/1.200 で受信したトラフィックのうち、172.20.0.0/16 宛ての通信を VRF "GUEST" 内のネクストホップ 10.200.1.254 へ転送してください。

```bash
ip access-list extended ACL_GUEST
 permit ip any 172.20.0.0 0.0.255.255

route-map RM_GUEST_PBR permit 10
 match ip address ACL_GUEST
 set ip next-hop 10.200.1.254

interface GigabitEthernet0/0/1.200
 vrf forwarding GUEST
 ip address 10.200.1.1 255.255.255.0
 ip policy route-map RM_GUEST_PBR
```
**【検証方法】**
```bash
R1# show ip vrf GigabitEthernet0/0/1.200
R1# show route-map RM_GUEST_PBR
```

---

### 9. Inter-VRF PBR (VRF間強制リーク)
**【問題】**
VRF "CORP" 内で受信したトラフィックのうち、インターネット宛て（10.0.0.0/8 以外）のパケットを、グローバルルーティングテーブル上のネクストホップ 192.168.100.254 へ直接転送してください。

```bash
ip access-list extended ACL_INTERNET
 deny   ip any 10.0.0.0 0.255.255.255
 permit ip any any

route-map RM_INTER_VRF permit 10
 match ip address ACL_INTERNET
 set global
 set ip next-hop 192.168.100.254

interface GigabitEthernet0/0/1.100
 vrf forwarding CORP
 ip address 10.100.1.1 255.255.255.0
 ip policy route-map RM_INTER_VRF
```
**【検証方法】**
```bash
R1# show route-map RM_INTER_VRF
# CORP VRF 配下のPCから 8.8.8.8 への traceroute で 192.168.100.254 を経由することを確認。
```

---

### 10. IPv6 PBR (`ipv6 policy route-map`)
**【問題】**
IPv6 送信元 2001:db8:10::/64 からのトラフィックに対し、IPv6 ネクストホップ 2001:db8:fe::2 へ転送するポリシーを適用してください。

```bash
ipv6 access-list ACL_IPV6_PBR
 permit ipv6 2001:db8:10::/64 any

route-map RM_IPV6_PBR permit 10
 match ipv6 address ACL_IPV6_PBR
 set ipv6 next-hop 2001:db8:fe::2

interface GigabitEthernet0/0/1
 ipv6 policy route-map RM_IPV6_PBR
```
**【検証方法】**
```bash
R1# show ipv6 policy
R1# show route-map RM_IPV6_PBR
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解】`set ip next-hop` と `set ip default next-hop` の混在動作
**問題:**
以下の設定が適用されたルータ R1 において、ルーティングテーブル（RIB）に `172.16.1.0/24 via 10.0.0.1` および `0.0.0.0/0 via 10.0.0.254` が存在しています。
10.1.1.10 から 172.16.1.50 宛てにパケットが送信された場合、パケットはどのネクストホップへ転送されますか？

```bash
ip access-list extended ACL_TEST
 permit ip 10.1.1.0 0.0.0.255 172.16.0.0 0.0.255.255

route-map RM_TEST permit 10
 match ip address ACL_TEST
 set ip default next-hop 192.168.1.1

interface GigabitEthernet0/0/1
 ip policy route-map RM_TEST
```

**解答・解説:**
**転送先ネクストホップ: `10.0.0.1` (通常のRIBに従う)**
* **理由:** `set ip default next-hop` は、ルーティングテーブル内に宛先IPに対する **明示的なルート（/24など）が存在しない場合のみ** 適用されます。今回の宛先 172.16.1.50 に対しては、RIB内に `/24` の明示ルート `10.0.0.1` が存在するため、PBRの `set ip default next-hop 192.168.1.1` は無視され、通常のルーティングテーブルが優先されます。もし PBR を優先させたい場合は `set ip next-hop 192.168.1.1` を使用する必要があります。

---

### 2. 【トラブルシューティング】IP SLA トラッキング連動 PBR の切り替え失敗
**問題:**
R1において、主回線（10.1.12.2）障害時に副回線（10.1.13.3）へ切り替えるため以下の設定を行いました。しかし、10.1.12.2 への回線障害（対向インターフェイスダウン）が発生しても、PBRが副回線へ切り替わらず、パケットが破棄され続けます。原因と修正方法を答えてください。

```bash
ip sla 1
 icmp-echo 10.1.12.2
ip sla schedule 1 start-time now

track 1 ip sla 1 reachability

route-map RM_PBR permit 10
 match ip address ACL_DATA
 set ip next-hop verify-availability 10.1.12.2 1 track 2
 set ip next-hop 10.1.13.3
```

**解答・解説:**
* **原因:**
  `route-map` 内の `set ip next-hop verify-availability` コマンドで指定されているトラック番号が **`track 2`** になっていますが、実際に作成された Track オブジェクトの番号は **`track 1`** です。トラック番号の不一致により、IP SLA のダウン状態が PBR へ正しく伝達されていません。
* **修正方法:**
  `route-map` 内のトラック番号を正しい `1` に修正します。
  ```bash
  route-map RM_PBR permit 10
   no set ip next-hop verify-availability 10.1.12.2 1 track 2
   set ip next-hop verify-availability 10.1.12.2 1 track 1
  ```

---

### 3. 【トラブルシューティング】Local PBR が反映されない
**問題:**
R1自身から送信される BGP ピアリングパケット（TCP 179）のみを特定インターフェイスから送出させるため、以下の設定を行いましたが、依然として通常のデフォルトルートから送出されています。原因と修正方法を説明してください。

```bash
ip access-list extended ACL_BGP
 permit tcp any any eq bgp

route-map RM_BGP_LOCAL permit 10
 match ip address ACL_BGP
 set ip next-hop 10.254.1.1

interface GigabitEthernet0/0/0
 ip policy route-map RM_BGP_LOCAL
```

**解答・解説:**
* **原因:**
  ルータ自身が発生させるトラフィック（Locally generated traffic）に対して、物理/論理インターフェイスに適用する `ip policy route-map` は機能しません。
* **修正方法:**
  インターフェイスから `ip policy` を削除し、グローバルコンフィギュレーションモードで **`ip local policy route-map RM_BGP_LOCAL`** を適用します。

---

### 4. 【Design / 実装】Inter-VRF PBR とルーティングループの防止
**問題:**
VRF "A" の顧客トラフィックを、セキュリティ検査のため共有 VRF "COMMON" 内のファイアウォール（192.168.1.1）へ PBR で転送する設計を行っています。設定時に考慮すべき「戻りトラフィック（Return traffic）」および「ルーティングループ」に関する設計上の注意点を2点述べてください。

**解答・解説:**
1. **戻りトラフィックのVRFテーブル指定:**
   VRF "A" から VRF "COMMON" へ PBR で転送されたパケットに対し、ファイアウォール（192.168.1.1）からの戻りパケットが再度 VRF "A" へ正しくルーティングされるよう、VRF "COMMON" 側にも逆方向の PBR または VRF リーク（Static/BGP Route Leaking）を設定しておく必要がある。
2. **両方向 PBR 適用時のループ回避:**
   往路・復路の双方のインターフェイスで PBR を適用する場合、ACLの条件が過剰にワイルドカード指定されていると、双方のルータで PBR が永久にパケットを蹴り合い、ルーティングループが発生する。ACLの条件（Match）は送信元・宛先サブネットを厳格に定義しなければならない。

---

### 5. 【コンフィグ読解】Route-Map の `deny` エントリと暗黙の `deny` の挙動
**問題:**
以下の設定が適用されたルータ R1 の Gi0/0/1 インターフェイスに、10.1.1.50 から 8.8.8.8 宛てのパケットが入力されました。このパケットの処理として正しいものはどれですか？

```bash
ip access-list extended ACL_BYPASS
 permit ip 10.1.1.0 0.0.0.255 8.8.8.8 0.0.0.0

route-map RM_PBR deny 10
 match ip address ACL_BYPASS

route-map RM_PBR permit 20
 match ip address any
 set ip next-hop 10.99.99.9
```

**解答・解説:**
**正解:** 通常のルーティングテーブル（RIB）に従って転送される。
* **解説:** Sequence 10 で ACL_BYPASS にマッチしますが、Route-map のアクションが **`deny`** になっています。PBR において Route-map の `deny` にマッチしたパケットは、「パケットがドロップされる」のではなく、**「PBR の適用をバイパス（スキップ）し、通常のルーティングテーブル（RIB/CEF）による検索へ引き渡される」** という動作になります。したがって Sequence 20 の `set ip next-hop` は評価されず、パケットは通常ルーティングされます。

---

## 🔗 参考リソース

### Cisco Configuration Guide
* [**IP Routing: Policy-Based Routing**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/rtng/b_179_rtng_9300_cg/protocol_independent_features.html#policy-based-routing)
* [**IPv6 Policy-Based Routing**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/rtng/b_179_rtng_9300_cg/configuring_ipv6_unicast_routing.html#policy-based-routing-ipv6)
* [**IP ルーティング：プロトコル非依存コンフィギュレーション ガイド、Cisco IOS XE Release 3S（ASR 1000）**](https://www.cisco.com/c/ja_jp/td/docs/rt/wanaggregationinternetedgert/asr1000aggregationservsrt/cg/012/iri-xe-3s-asr1000-book-1/iri-xe-3s-asr1000-book-1_chapter_01011.html)

### Cisco Command Reference
* [**IP Routing: Protocol-Independent Command Reference - ip policy route-map / set ip next-hop**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/command/iri-cr-book.html)

### Technical Notes & White Papers
* [**ネクストホップコマンドを使用したポリシーベースルーティングの設定**](https://www.cisco.com/c/ja_jp/support/docs/ip/ip-routed-protocols/47121-pbr-cmds-ce.html)
* [**XEプラットフォームでのPBRトラフィックをデバッグするためのパケットトレースの設定**](https://www.cisco.com/c/ja_jp/support/docs/quality-of-service-qos/policy-based-routing-pbr/200926-Configure-Packet-Trace-to-Debug-PBR-Traf.html)


---

## 📝 **補足（Notes）**

### PBR 判定フローチャート（直前復習用）

```text
               [ パケット受信 / ルータ自発 ]
                           │
                           ▼
          [ PBR Route-map Match 評価 ]
           /                             (No Match / Deny)           (Match permit)
         /                            【通常RIB/CEF検索】               [ set アクション種別 ]
                                  /                                   (set ip next-hop)         (set ip default next-hop)
                         /                                       【PBR指定IPへ直ちに転送】       【まず通常のRIBを検索】
            (RIBのルート情報を無視)              /                                                     (明示的ルートあり)  (デフォルトルートのみ/なし)
                                             /                                                         【RIBに従って転送】    【PBR指定IPへ転送】
```

---

### この項で使用するコマンド

```md
# ===============================
# Route-map 作成（PBR ポリシー）
# ===============================

Switch1(config)# ! PBR 用 route-map を作成
Switch1(config)# route-map PBR-MAP permit 10

Switch1(config-route-map)# ! ACL 110 と 140 に一致するトラフィックを分類
Switch1(config-route-map)# match ip address 110 140

Switch1(config-route-map)# ! パケット長 64〜1500 バイトを分類
Switch1(config-route-map)# match length 64 1500

Switch1(config-route-map)# ! 次ホップを 10.1.6.2 に設定（直接接続必須）
Switch1(config-route-map)# set ip next-hop 10.1.6.2

Switch1(config-route-map)# exit


# ===============================
# インターフェイスへ PBR を適用
# ===============================

Switch1(config)# ! Gi1/0/1 に PBR を適用
Switch1(config)# interface GigabitEthernet1/0/1
Switch1(config-if)# ip policy route-map PBR-MAP

Switch1(config-if)# ! PBR の高速スイッチングを有効化（任意）
Switch1(config-if)# ip route-cache policy


# ===============================
# Local PBR（スイッチ自身のトラフィックに適用）
# ===============================

Switch1(config)# ! ローカル生成トラフィックに PBR を適用
Switch1(config)# ip local policy route-map PBR-MAP


# ===============================
# PBR 状態確認
# ===============================

Switch1# ! 適用されている PBR を確認
Switch1# show ip policy

Switch1# ! Local PBR の状態を確認
Switch1# show ip local policy

Switch1# ! route-map の内容を確認
Switch1# show route-map PBR-MAP
```
