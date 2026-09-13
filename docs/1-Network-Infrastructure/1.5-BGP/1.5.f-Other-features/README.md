---
layout: default
title: 1.5.f-Other-features
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 6
---

# 1.5.f Other BGP features such as soft reconfiguration and route refresh

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における BGP の運用・保守・高速コンバージエンスおよび制御プレーン最適化機能である **`1.5.f Other BGP features such as soft reconfiguration and route refresh`** について、Cisco IOS-XE 17.x の実装基準に 100% 準拠して学術的・実践的背景から詳細に解説します。

---

## 📘 概要

BGP（Border Gateway Protocol）はインタードメイン・ルーティングの標準プロトコルであり、数百万規模のルーティングテーブルを処理する能力を持ちます。しかし、ポリシー変更時における BGP セッションのリセット（フラッピング）は、コントロールプレーン負荷の急増やデータプレーンにおける大量のパケットドロップを引き起こします。

本項目で扱う **Route Refresh**、**Soft Reconfiguration Inbound**、**BGP Fast Fall-over (Fast Session Deactivation)**、**BGP Next-Hop Address Tracking (NAT)**、**BGP Additional Paths (Add-Paths)**、**BGP PIC (Prefix Independent Convergence)**、**Graceful Restart (GR) / NSR (Non-Stop Routing)**、および **BGP Slow Peer Detection** などの高度な運用制御機能は、BGP ピアセッションを切断・再確立することなく動的にポリシー変更を反映させ、障害発生時の切替時間をミリ秒単位に短縮するための核心技術群です。

### 主な利用目的と適用シーン
1. **無停止（Hitless）ポリシー再適用:** 受信側フィルタ（Prefix-List, Route-Map）の変更後、TCP セッション（ポート 179）をリセットせずに動的に BGP UPDATE を再要求・再計算する（Route Refresh / Soft Reconfiguration）。
2. **事前ポリシー（Pre-policy）ルートの監査:** 対向 ISP やピアから送信された未加工の BGP 経路（Filter 適用前の全プレフィックス）をメモリ上に保存し、トラブルシューティングやフィルタリング漏れの監査を行う（Soft Reconfiguration Inbound）。
3. **ミリ秒単位の障害検出と高速コンバージエンス:** 物理リンク閉塞や IGP（OSPF/EIGRP）の Next-Hop 消失を即座に検知し、BGP Holdtime（180秒）の満了を待たずに即時パスをバックアップへ切り替える（Fast Fall-over / Next-Hop Tracking / BGP PIC）。
4. **iBGP 内でのマルチパス透過と非最適パス解消:** RR（Route Reflector）環境下で隠蔽されがちなセカンドベストパスを伝搬させ、iBGP のロードバランシングや Fast Reroute を実現する（Additional Paths）。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | セッション切断なしでの動的ポリシー反映（Route Refresh）、未加工ルートのメモリ保持（Soft Reconfiguration）、Next-Hop イベント駆動型動的計算（NAT）、FIB レベルの即時切り替え（BGP PIC）。 |
| **用途** | エンタープライズ WAN、マルチホーム接続、ISP ピアリング、DMVPN / SD-WAN アンダーレイ、MPLS L3VPN コア網。 |
| **メリット** | ① セッションリセットに伴うトラフィック破棄の防止。<br>② コントロールプレーンおよびデータプレーンの高速コンバージエンス（ミリ秒単位）。<br>③ 受信ルートの詳細な可視化と監査性向上。<br>④ コントロールプレーン切替（SSO）時のフォワーディング維持。 |
| **デメリット** | ① `soft-reconfiguration inbound` は未加工ルートをすべて RAM に保持するためメモリ消費量が激増。<br>② Add-Paths や Slow Peer 制御はルータの CPU / メモリ使用率を増加させる。 |
| **成立要件 / 互換性** | ① Route Refresh は BGP OPEN パケット内の Capability 1 (RFC 2918) 送受信により自動有効化。<br>② Soft Reconfiguration Inbound は明示的コンフィグが必要。 |
| **設計上の注意点** | モダンな Cisco IOS-XE デバイス間ではデフォルトで Route Refresh が動作するため、`soft-reconfiguration inbound` は例外的なデバッグ目的以外では原則使用しない（メモリ枯渇防止）。 |

---

## 🏗 動作原理

### 1. Route Refresh vs Soft Reconfiguration Inbound のアーキテクチャ比較

```text
========================================================================================
[ Route Refresh 動作フロー (RFC 2918) ] - メモリ消費ゼロ / 動的再要求
========================================================================================
[ Local Router (R1) ]                               [ Remote Peer (R2) ]
        │                                                     │
        │─── 1. Policy Modified (Prefix-List/Route-Map) ───┐  │
        │    (Requires Inbound Soft Reset)                 │  │
        │                                                  │  │
        │─── 2. ROUTE-REFRESH Packet (Opcode 5) ──────────►│
        │                                                  │─── 3. Re-read Local BGP Table
        │                                                  │    and Re-evaluate Outbound Policy
        │◄── 4. Standard BGP UPDATE Packets ───────────────│
        │                                                     │
   [ Filtered & Saved in ]
   [ Local BGP Table     ]

========================================================================================
[ Soft Reconfiguration Inbound 動作フロー ] - 高メモリ消費 / ローカルテーブル再評価
========================================================================================
[ Local Router (R1) ]                               [ Remote Peer (R2) ]
        │                                                     │
   ┌────┴───────────────────────────┐                         │
   │ BGP Received Routes Database   │                         │
   │ (Pre-policy Raw Updates)       │                         │
   └────┬───────────────────────────┘                         │
        │                                                     │
        │─── 1. Policy Modified (Prefix-List/Route-Map)       │
        │─── 2. Internal Local Re-evaluation ─────────────────┤ (対向通信一切なし)
        │    (Pass Raw Updates through New Inbound Policy)    │
        │                                                     │
   [ Saved in Main BGP Table ]
```

---

## ⚙ 動作シーケンス

### A. Route Refresh の動作シーケンス
1. **Capability ネゴシエーション:**  
   BGP ピアリング確立時、双方は BGP OPEN パケット内で **`Route Refresh Capability (Code 1)`** を広播し、相互サポートを確認します。
2. **ポリシー変更と再適用コマンド実行:**  
   管理者または自動化スクリプトがインバウンドフィルタを変更し、`clear ip bgp <IP> soft in` を実行します。
3. **ROUTE-REFRESH メッセージの送出:**  
   ローカルルータは、該当ピアに対して BGP Header Type 5（ROUTE-REFRESH）パケットを送信します。
4. **対向ルータによる UPDATE パケット再送:**  
   リクエストを受信した対向ピアは、自身の BGP テーブルに保持されているプレフィックスを、対向用のアウトバウンドポリシーで再評価し、通常の BGP UPDATE パケットとして再送します。
5. **ローカル処理:**  
   ローカルルータは受信した UPDATE パケットに新しいインバウンドポリシーを適用し、BGP テーブルおよび RIB / FIB を更新します。

### B. Soft Reconfiguration Inbound の動作シーケンス
1. **事前構成:**  
   ローカルルータ上で `neighbor <IP> soft-reconfiguration inbound` を設定します。
2. **Raw Update の永久保存:**  
   対向から受信したすべての BGP UPDATE パケットは、インバウンドフィルタが適用される **前** の状態で `BGP Received Routes Database` (Adj-RIB-In) に保存されます。
3. **ポリシー変更とローカル再計算:**  
   インバウンドポリシー変更後、`clear ip bgp <IP> soft in` を実行すると、対向にパケットを一切送信せず、ローカルメモリ上の Adj-RIB-In データベースを読み出して新しいポリシーを即座に再適用します。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、BGP の「Other Features」は単体での設定問題だけでなく、**トラブルシューティング問題** や **高速コンバージエンス（SLA遵守）問題** として頻出します。

### 1. 試験で狙われるポイントと解法テクニック

* **`show ip bgp neighbors <IP> received-routes` がエラーになる理由:**
  * **現象:** コマンドを入力すると `Inbound soft reconfiguration not configured on peer <IP>` と表示されて受信ルートが表示されない。
  * **理由:** これは正常な挙動です。Route Refresh が有効な環境であっても、フィルタ適用前の「未加工受信ルート」を表示するには `neighbor <IP> soft-reconfiguration inbound` が設定されている必要があります。
  * **試験での指示:** 「対向から受信している全プレフィックス（フィルタで拒否されたものを含む）を確認せよ」と要求された場合、`soft-reconfiguration inbound` を追加設定する必要があります。

* **Fast Session Deactivation (`fall-over route-map`):**
  * デフォルトの BGP は、物理リンクが UP している限り BGP Holdtime（180秒）が満了するまでセッションを維持しようとします。
  * マルチホップ eBGP や iBGP において、中間障害で Next-Hop への IP ルートが消失した場合に即座に BGP を Down させたい場合は、以下を構成します：
    ```bash
    router bgp 65000
     neighbor 10.1.12.2 fall-over route-map CHECK_NEXTHOP
    ```

* **BGP Next-Hop Address Tracking (NAT) と Delay チューニング:**
  * Cisco IOS-XE では、BGP スキャナー（デフォルト 60秒周期）を待つことなく、IGP / RIB の Next-Hop 変化イベントをリアルタイムに追跡します。
  * デフォルトの応答遅延（Event Delay）は 5 秒です。試験で「IGP Next-Hop 障害発生後、1秒以内に BGP パスを再計算させよ」と指示された場合、以下をチューニングします：
    ```bash
    router bgp 65000
     bgp nexthop trigger delay 1
    ```

* **BGP Additional Paths (Add-Paths) の仕様:**
  * Route Reflector (RR) 環境でセカンドベストパスが消去される問題を克服し、iBGP での等コスト / 不等コストマルチパスを実現します。
  * `bgp additional-paths select` / `send` / `receive` の 3 パラメータの正確なバインド位置が問われます。

---

## 🛠 設定方法

### 1. Soft Reconfiguration Inbound の設定

```bash
router bgp 65001
 bgp log-neighbor-changes
 neighbor 192.168.12.2 remote-as 65002
 neighbor 192.168.12.2 soft-reconfiguration inbound
```

### 2. BGP Fast Fall-over (Route-Map 連動) の設定

```bash
ip prefix-list PEER_NEXTHOP seq 5 permit 10.1.23.0/24
!
route-map MAP_FALLOVER permit 10
 match ip address prefix-list PEER_NEXTHOP
!
router bgp 65001
 neighbor 10.1.23.2 remote-as 65002
 neighbor 10.1.23.2 ebgp-multihop 255
 neighbor 10.1.23.2 fall-over route-map MAP_FALLOVER
```

### 3. BGP Next-Hop Address Tracking & Trigger Delay の最適化

```bash
router bgp 65001
 # Next-Hop 追跡遅延を 1 秒に短縮（デフォルト: 5秒）
 bgp nexthop trigger delay 1
```

### 4. BGP Additional Paths (Add-Paths) の構成

```bash
#【RR 側設定】
router bgp 65000
 address-family ipv4 unicast
  # 送信・受信能力の定義
  neighbor 10.1.1.2 additional-paths send/receive
  # 送信するパスの選定ロジック (Best 2 パスを送出)
  bgp additional-paths select best 2
 exit-address-family

#【Client 側設定】
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.1.1.1 additional-paths receive
  maximum-paths ibgp 2
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **ピアの Route Refresh サポート機能の確認** | <code>show ip bgp neighbors <IP> \| include Route refresh</code> |
| **未加工受信ルート（Adj-RIB-In）の確認（Soft-Reconfig 必須）** | <code>show ip bgp neighbors <IP> received-routes</code> |
| **インバウンドフィルタ適用後ルート（Loc-RIB）の確認** | <code>show ip bgp neighbors <IP> routes</code> |
| **アウトバウンドフィルタ適用後送信ルート（Adj-RIB-Out）の確認** | <code>show ip bgp neighbors <IP> advertised-routes</code> |
| **Next-Hop Address Tracking テーブルの監査** | <code>show ip bgp nexthop</code> |
| **BGP Additional Paths の交換・保持状況確認** | <code>show ip bgp <PREFIX></code> / <code>show ip bgp neighbor <IP></code> |
| **動的 Route Refresh リクエスト送信（ソフトリセット）** | <code>clear ip bgp <IP> soft in</code> |
| **アウトバウンドソフトリセットの実行** | <code>clear ip bgp <IP> soft out</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`received-routes` コマンドでエラーが表示される。** | 該当ピアに対して `soft-reconfiguration inbound` が設定されていない。 | `show running-config \| section router bgp` | `neighbor <IP> soft-reconfiguration inbound` を追加投入する。 |
| **インバウンドフィルタを変更したのに BGP テーブルに反映されない。** | フィルタ変更後に `clear ip bgp <IP> soft in` を実行していない。 | `show ip bgp` | `clear ip bgp <IP> soft in` を実行して Route Refresh をトリガーする。 |
| **Next-Hop がダウンしたのに BGP ピアが数分間 Down にならない。** | BGP Fast Fall-over が未設定、または IGP ルートが完全削除されずデフォルトルートでルーティング解決されている。 | `show ip route <NEXTHOP>`<br>`show ip bgp neighbors <IP>` | `neighbor <IP> fall-over route-map` を構成し、特定明示プレフィックスの消去時のみ Fast Fall-over を発動させる。 |
| **RR 環境で Add-Paths を設定したのにクライアントが 1 パスしか受信しない。** | RR 上で `bgp additional-paths select` による選定ロジックが定義されていないか、Client 側で `receive` パラメータが抜けている。 | `show ip bgp neighbors <IP>` | RR 側で `bgp additional-paths select best 2` を定義し、ピア配下で `additional-paths send` を有効化する。 |

---

## ⚠ 制限事項

1. **Soft Reconfiguration Inbound のメモリ増大:**  
   フルフリート（約 90 万プレフィックス以上）を受信する BGP ピアで `soft-reconfiguration inbound` を有効化すると、ルータの RAM 消費量が約 2 倍に跳ね上がり、ルータが OOM（Out of Memory）でクラッシュする危険性があります。
2. **Add-Paths のプラットフォーム制限:**  
   旧世代の IOS（12.2S等）や一部のローエンドスイッチでは Hardware FIB（TCAM）の制限により Add-Paths がサポートされない、または最大パス数が制限される場合があります（Cisco IOS-XE 16.x/17.x では標準サポート）。

---

## 🔄 他技術との関連

* **BFD (Bidirectional Forwarding Detection):**  
  BGP Fast Fall-over と同様にサブ秒単位のリンク障害検知を実現します。`neighbor <IP> fall-over bfd` をバインドすることで、物理層・データリンク層のサイレント障害を迅速に検出します。
* **MPLS L3VPN / BGP PIC (Prefix Independent Convergence):**  
  BGP PIC Edge/Core 機能は、BGP 内部テーブルおよび CEF テーブルに事前バックアップパス（Repair Path）を保持させ、対向 PE 障害時にミリ秒（< 50ms）でトラフィックを迂回させます。

---

## 🧩 比較表

### Route Refresh vs Soft Reconfiguration Inbound

| 比較項目 | Route Refresh (RFC 2918) | Soft Reconfiguration Inbound |
| :--- | :--- | :--- |
| **動作方式** | 対向ピアへ ROUTE-REFRESH パケットを送出し、UPDATE を動的再送信させる | 受信した全 Raw UPDATE を Adj-RIB-In メモリデータベースに永久保存 |
| **メモリ消費** | **極めて低い (追加消費ゼロ)** | **極めて高い (BGP 受信データが倍増)** |
| **対向ルータへの影響** | 対向ルータの CPU を一時的に使用（UPDATE 再送信処理） | **完全ゼロ (自ルータ内部で閉完)** |
| **事前フィルタ前ルートの閲覧** | 不可 (`received-routes` 使用不可) | **可能 (`received-routes` で閲覧可能)** |
| **デフォルト動作** | Cisco IOS-XE で自動有効 | **手動設定が必要 (`soft-reconfiguration inbound`)** |

---

## 💡 ベストプラクティス

1. **Route Refresh の優先使用:**  
   通常の運用およびポリシールーティング更新には `clear ip bgp <IP> soft in` (Route Refresh) を使用し、`soft-reconfiguration inbound` はトラブルシューティング時のみ限定使用する。
2. **Fast Session Deactivation & BFD の併用:**  
   マルチホップ eBGP ピアや iBGP ピアには `fall-over route-map` または `fall-over bfd` を設定し、障害検知時間を最小化する。
3. **Next-Hop Trigger Delay の最適化:**  
   コア網の高速コンバージエンス要件に合わせて `bgp nexthop trigger delay 1`〜`2` 秒に調整する。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: Route Refresh 機能の検証とソフトリセット
* **要件:** R1 (AS 65001) と R2 (AS 65002) 間の eBGP において、セッションを切断することなくインバウンド Prefix-List を適用・再計算させよ。

**【R1】**
```bash
ip prefix-list FILTER_IN deny 10.2.2.0/24
ip prefix-list FILTER_IN permit 0.0.0.0/0 le 32
!
router bgp 65001
 neighbor 192.168.12.2 remote-as 65002
 address-family ipv4 unicast
  neighbor 192.168.12.2 prefix-list FILTER_IN in
 exit-address-family
```

**【検証・反映コマンド】**
```bash
# セッションを切断せずに動的に Route Refresh を要求
R1# clear ip bgp 192.168.12.2 soft in
R1# show ip bgp neighbors 192.168.12.2 | include Route refresh
# 「Route refresh utility support: received support for inbound soft reset」を確認
```

---

### Scenario 2: Soft Reconfiguration Inbound の構成と監査
* **要件:** R1 側で R2 から送信される全プレフィックス（フィルタで拒否されたものを含む未加工ルート）を可視化できるよう設定せよ。

**【R1】**
```bash
router bgp 65001
 neighbor 192.168.12.2 remote-as 65002
 neighbor 192.168.12.2 soft-reconfiguration inbound
```

**【検証方法】**
```bash
# インバウンドフィルタで拒否されたプレフィックスも含めて全受信ルートを表示
R1# show ip bgp neighbors 192.168.12.2 received-routes
```

---

### Scenario 3: BGP Fast Fall-over (Fast Session Deactivation) の構成
* **要件:** R1-R3 間の Loopback ピアリングにおいて、10.1.13.0/24 への IGP ルートが消失した際、即座に BGP ピアを Down させよ。

**【R1】**
```bash
ip prefix-list PATH_TO_R3 seq 5 permit 10.1.13.0/24
!
route-map MAP_NEXTHOP_R3 permit 10
 match ip address prefix-list PATH_TO_R3
!
router bgp 65001
 neighbor 3.3.3.3 remote-as 65001
 neighbor 3.3.3.3 update-source Loopback0
 neighbor 3.3.3.3 fall-over route-map MAP_NEXTHOP_R3
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 3.3.3.3 | include Fall-over
# 「Fall-over route-map is MAP_NEXTHOP_R3」を確認
```

---

### Scenario 4: BGP Next-Hop Address Tracking (NAT) 遅延短縮
* **要件:** R1 において、Next-Hop 変更イベントが発生してから BGP テーブルを更新するまでの遅延（Trigger Delay）を 1 秒に変更せよ。

**【R1】**
```bash
router bgp 65001
 bgp nexthop trigger delay 1
```

**【検証方法】**
```bash
R1# show ip bgp nexthop
# Next-Hop tracking が有効であり、Delay が 1 秒にセットされていることを確認
```

---

### Scenario 5: BGP Additional Paths (Add-Paths) によるセカンドベストアドバタイズ
* **要件:** RR (R1) において、クライアント R2 に対してベストパスだけでなくセカンドベストパスも含めた最大 2 パスを送出するよう構成せよ。

**【R1 (RR)】**
```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.1.2.2 route-reflector-client
  neighbor 10.1.2.2 additional-paths send
  bgp additional-paths select best 2
 exit-address-family
```

**【R2 (Client)】**
```bash
router bgp 65000
 address-family ipv4 unicast
  neighbor 10.1.1.1 additional-paths receive
  maximum-paths ibgp 2
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp 172.16.10.0/24
# 同一プレフィックスに対して 2 つの Additional Path を受信していることを確認
```

---

### Scenario 6: BGP BFD (Bidirectional Forwarding Detection) 統合
* **要件:** R1 と R2 間の eBGP ピアリングに対して BFD 単一ホップ障害検知を有効化せよ。

**【R1】**
```bash
interface GigabitEthernet0/1
 bfd interval 50 min_rx 50 multiplier 3
!
router bgp 65001
 neighbor 192.168.12.2 remote-as 65002
 neighbor 192.168.12.2 fall-over bfd
```

**【検証方法】**
```bash
R1# show bfd neighbors client bgp
```

---

### Scenario 7: Outbound Route Filtering (ORF) プレフィックスレベル連携
* **要件:** R1 (Receive 側) から R2 (Send 側) へ Prefix-List を動的送信し、R2 側で送出処理自体をフィルタリングさせよ。

**【R1 (Receive)】**
```bash
ip prefix-list ORF_PREF deny 172.16.1.0/24
ip prefix-list ORF_PREF permit 0.0.0.0/0 le 32
!
router bgp 65001
 neighbor 192.168.12.2 remote-as 65002
 address-family ipv4 unicast
  neighbor 192.168.12.2 capability orf prefix-list receive
  neighbor 192.168.12.2 prefix-list ORF_PREF in
 exit-address-family
```

**【R2 (Send)】**
```bash
router bgp 65002
 neighbor 192.168.12.1 remote-as 65001
 address-family ipv4 unicast
  neighbor 192.168.12.1 capability orf prefix-list send
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp neighbors 192.168.12.1 received prefix-filter
```

---

### Scenario 8: BGP Slow Peer Quarantine (隔離) 機能の設定
* **要件:** アップデート処理が遅い Slow Peer を自動検知し、通常のピアのコンバージエンス遅延を保護するため隔離設定を行え。

**【R1】**
```bash
router bgp 65001
 bgp slow-peer detection threshold 120
 bgp slow-peer split-update-group dynamic
```

**【検証方法】**
```bash
R1# show ip bgp slow-peers
```

---

### Scenario 9: BGP Graceful Restart (GR) の有効化
* **要件:** コントロールプレーン再起動（SSO 切替等）時にフォワーディング（CEF）を維持するよう Graceful Restart を構成せよ。

**【R1】**
```bash
router bgp 65001
 bgp graceful-restart restart-time 120
 bgp graceful-restart stalepath-time 360
 bgp graceful-restart
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 192.168.12.2 | include Graceful
```

---

### Scenario 10: VRF-Aware 環境での Route Refresh と Soft Reconfig
* **要件:** VRF `TENANT_A` 配下の BGP ピアに対して `soft-reconfiguration inbound` をバインドせよ。

**【R1】**
```bash
router bgp 65001
 address-family ipv4 unicast vrf TENANT_A
  neighbor 10.200.1.2 remote-as 65200
  neighbor 10.200.1.2 soft-reconfiguration inbound
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp vrf TENANT_A neighbors 10.200.1.2 received-routes
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】受信ルートが表示できない現象の解析
**問題:**  
対向ルータ R2 から受信している全プレフィックスを確認しようと `show ip bgp neighbors 192.168.12.2 received-routes` を実行したところ、以下のエラーが出力されました。この現象が発生する技術的理由と、セッションを切断せずにエラーを解消するための設定を述べてください。
```text
% Inbound soft reconfiguration not configured on peer 192.168.12.2
```

**解答・解説:**
* **技術的理由:**  
  `received-routes` オプションは、フィルタ（Prefix-List 等）が適用される前の「未加工受信ルート（Adj-RIB-In）」を表示するコマンドです。この情報を保持するには `neighbor <IP> soft-reconfiguration inbound` が設定されている必要があります。Route Refresh のみが有効な標準状態では、未加工ルートは RAM に保持されないため本エラーが発生します。
* **修正方法:**  
  以下のコンフィグを投入し、`clear ip bgp 192.168.12.2 soft in` を実行します（セッション切断は不要）。
  ```bash
  router bgp 65001
   neighbor 192.168.12.2 soft-reconfiguration inbound
  ```

---

### 2. 【Design / 高速コンバージエンス】中間障害時の BGP 遅延解消
**問題:**  
マルチホップ eBGP ピアリングにおいて、中間スイッチ障害で Next-Hop への IP ルートが消失したにもかかわらず、BGP ピアが 180 秒間 Holdtime 満了まで切断されず、トラフィックブラックホールが発生しました。中間障害検知時に即座に BGP ピアを Down させるための設計コマンドを提示してください。

**解答・解説:**
* **回答:**  
  `neighbor <IP> fall-over route-map` または `neighbor <IP> fall-over bfd` を設定します。
* **設定例:**
  ```bash
  ip prefix-list PEER_NH permit 10.1.23.0/24
  !
  route-map MAP_FALLOVER permit 10
   match ip address prefix-list PEER_NH
  !
  router bgp 65001
   neighbor 10.1.23.2 fall-over route-map MAP_FALLOVER
  ```

---

## 🔗 参考リソース

* [Cisco Systems: BGP Configuration Guide - Configuring Soft Reconfiguration and Route Refresh](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)
* [Cisco Systems: BGP Additional Paths Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-add-paths.html)
* [RFC 2918: Route Refresh Capability for BGP-4](https://datatracker.ietf.org/doc/html/rfc2918)
* [Cisco Live: BRKRST-2337 - Advanced BGP Troubleshooting and Operations](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **Soft Reset コマンドの挙動差:**
  * `clear ip bgp *` ➔ **Hard Reset (TCP 179 セッションを切断・再確立) - 運用環境では絶対禁止**
  * `clear ip bgp * soft in` ➔ **Route Refresh または Soft Reconfig による無停止インバウンド更新**
  * `clear ip bgp * soft out` ➔ **アウトバウンドフィルタ適用後ルートの再送（ローカル処理のみ）**


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - セッション管理と Route Refresh の動作、スケーラビリティ機能の詳細。
*   [BRKRST-3320: Troubleshooting BGP](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - ポリシー反映がうまくいかない際、Route Refresh を使ったトラブルシュート手法。

### Configurationガイド
*   [Cisco BGP Configuration Guide: Route Refresh and Soft Reconfiguration](http://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-filter-config.html)。
*   [Configuring BGP Maximum Prefix](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/xe-17/irg-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [BGP Route Refresh Capability RFC 2918](https://tools.ietf.org/html/rfc2918)。
*   [Understanding BGP Soft Reconfiguration (Cisco Support)](http://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/5816-bgpfaq-5816.html)。

---

## 📝 補足
- この学習メモは、BGP セッションの安定性を維持しながら、動的にポリシーを適用・制御するための必須機能を網羅しています。CCIE EI ラボ試験では、単なる設定の正しさだけでなく、「パケットロスを発生させない運用」が厳しく問われるため、<code>soft</code> オプションを伴うコマンドの使用を習慣化することが合格への鍵となります。

