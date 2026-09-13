---
layout: default
title: 1.5.e-Convergence
parent: 1.5-BGP
grand_parent: 1-Network-Infrastructure
nav_order: 5
---

# 1.5.e Convergence and scalability (Route Reflectors & Aggregation, AS-SET)

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における BGP スケーラビリティと高速コンバージエンスのコア技術である **Route Reflectors (RR - 1.5.e (i))** および **BGP Route Aggregation & AS-SET (1.5.e (ii))** について、Cisco IOS-XE 17.x の実装基準に 100% 準拠して詳細に解説します [22, 1.5.e]。

---

## 📘 概要

大規模なエンタープライズ網やサービスプロバイダー網において、iBGP フルメッシュ（Full-Mesh）構成はピア数の爆発的増加（$N(N-1)/2$ ルール）を引き起こし、ルータの CPU およびメモリリソースを急激に圧迫します。また、広大なグローバルルーティングテーブル（数百〜数百万プレフィックス）を無制限に伝搬させることは、WAN 帯域の枯渇や再計算によるコンバージエンス遅延を招きます。

これらを解決するための 2 大コア技術が **Route Reflectors (RR)** と **BGP Route Aggregation (集約・AS-SET)** です。

* **Route Reflectors (RR):** iBGP スプリットホライズンルール（「iBGP ピアから学習したルートを他の iBGP ピアへ転送しない」）を特例的に解除し、中央のルータ（RR）がクライアントへ経路を再反射（Reflect）することで、iBGP フルメッシュ構成を不要にするスケーラビリティ技術です [56, 1.11.d]。
* **BGP Route Aggregation (`aggregate-address` & `as-set`):** 複数に細分化されたプレフィックスを単一の集約経路（Summary Route）に統合してアドバタイズします。さらに `as-set` を併用することで、個別経路が持っていた AS_PATH 属性を集約経路内に集合情報（Unordered Set）として保持させ、ルーティングループを防止します [131, Understanding Route Aggregation in BGP]。

---

## 🔑 要点

| 項目 | Route Reflectors (RR) | BGP Route Aggregation (`aggregate-address`) |
| :--- | :--- | :--- |
| **主要目的** | iBGP フルメッシュ要件の撤廃によるコントロールプレーンのスケーラビリティ向上 [56, 1.11.d] | ルーティングテーブル（RIB/FIB）サイズの削減および BGP 制御パケットの削減 [131] |
| **ループ防止メカニズム** | `Originator_ID` (32-bit) & `Cluster_List` (32-bit) 属性 [56, 1.11.d] | `AS_SET`（集約前の全 AS 番号を集合として保持する属性） [131] |
| **構成要素** | RR (Server), RR Client, Non-Client, Cluster ID [56, 1.11.d] | 集約プレフィックス, `summary-only`, `as-set`, `suppress-map`, `attribute-map` [131] |
| **メリット** | iBGP ピア数を大幅削減。網の拡張（スケールアウト）が極めて容易 [56, 1.11.d] | メモリ/CPU 消費抑制、不安定な個別経路のフラッピング隠蔽（ルート集約によるトポロジー遮蔽） [131] |
| **注意点・デメリット** | RR 集中による非最適パス（Sub-optimal Routing）や、Cluster ID 未統一時のループ発現 [56, 1.11.d] | `as-set` 付与時の集約経路フラッピング（下位要素変更で集約経路が再計算・再送される） [131] |

---

## 🏗 動作原理

### 1. Route Reflector (RR) の再反射ルール（Reflection Rules）

RR は、BGP ピアを **Client** と **Non-Client** に分類してルーティング情報を管理します [56, 1.11.d]。

```text
               [ eBGP Peer ]
                     │ (eBGP)
                     ▼
             [ Route Reflector ]
            /         │              (Client)     (Client)    (Non-Client)
       /              │                    ▼               ▼               ▼
[ RR Client 1 ]  [ RR Client 2 ]  [ Non-Client iBGP ]
```

* **eBGP ピアから学習した経路:** 全ての Client および Non-Client ピアへ転送。
* **RR Client ピアから学習した経路:** 全ての Client ピア、Non-Client ピア、および eBGP ピアへ再反射（Reflect）。
* **Non-Client ピアから学習した経路:** 全ての **Client ピア** および eBGP ピアへ再反射（**Non-Client ピア間には転送しない** = iBGP スプリットホライズンが適用される） [56, 1.11.d]。

#### RR のループ防止属性（Loop Prevention Attributes）
1. **`Originator_ID` (Type Code 9):**  
   AS 内で最初に該当ルートを生成・着信させた iBGP ルータの Router ID。自機の Router ID と一致する `Originator_ID` を受信したルータは、該当ルートを即座に破棄（Discard）します。
2. **`Cluster_List` (Type Code 10):**  
   ルートが通過した RR の Cluster ID（通常は RR の Router ID、または明示指定された 32 ビット値）のシーケンス。自機の Cluster ID が `Cluster_List` に含まれている場合、ルーティングループとみなして破棄します。

---

### 2. BGP Route Aggregation と AS-SET のメカニズム

BGP の `aggregate-address` コマンドは、BGP テーブル上に特定の個別ルート（Contributor Routes）が 1 つ以上存在する場合に集約経路を投入します [131]。

```text
[ AS 100 ] ──► (10.1.1.0/24) ──┐
                               ├──► [ AS 200 (Aggregator) ] ──► aggregate-address 10.1.0.0 255.255.0.0 as-set ──► [ AS 300 ]
[ AS 150 ] ──► (10.1.2.0/24) ──┘    (AS_PATH: 200 {100, 150})
```

#### 集約オプションの比較

| オプション | 動作と属性の変更点 |
| :--- | :--- |
| `aggregate-address X.X.X.X M.M.M.M` | 集約ルートと個別ルートの**両方**をアドバタイズする [131]。 |
| `summary-only` | 個別ルートを抑制（Suppressed）し、**集約ルートのみ**をアドバタイズする [131]。 |
| `as-set` | 個別ルートが持つ AS_PATH 情報を**無順序集合 `{AS1, AS2}`** として集約ルートへ引き継ぐ。ルーティングループを防止する [131]。 |
| `suppress-map <MAP>` | 指定した Route-Map にマッチする特定ルートのみを抑制し、他は個別に送出する [131]。 |
| `attribute-map <MAP>` | 集約ルート自体の BGP 属性（`Community`, `MED`, `Local-Pref` 等）を書き換える [131]。 |

---

## ⚙ 動作シーケンス

### Route Reflector 経由のルート反射シーケンス

```text
[ Client A ]                [ Route Reflector ]              [ Non-Client B ]
     │                              │                                │
     │── 1. UPDATE (10.1.0.0/24) ─►│                                │
     │   (iBGP 送信)                 │                                │
     │                              │── 2. Originator_ID 付加 ───────┤
     │                              │   (Originator_ID = Client A)   │
     │                              │── 3. Cluster_List 追加 ────────┤
     │                              │   (Cluster_List = 1.1.1.1)     │
     │                              │                                │
     │                              │── 4. 再反射 (Reflect) ────────►│ (UPDATE 受信)
     │                              │── 5. 他 Client へ再反射 ─────►│
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、Route Reflectors と Route Aggregation は単独構成だけでなく、**MPLS L3VPN**, **VRF-Aware BGP**, **BGP Community**, **Multi-AS 接続** と組み合わせて頻繁に出題されます。

### 1. Route Reflector (RR) の重要ポイントとトラップ
* **`next-hop-self` の再反射時の挙動不審:**
  RR が Client から受領した iBGP 経路を他の Client へ再反射する際、**`neighbor <IP> next-hop-self` を設定していても、Next-Hop アドレスは書き換わりません（元の Next-Hop が維持される）。**
  ※ Next-Hop を強制変更したい場合は、`route-map` を使用して `set ip next-hop` をバインドする必要があります [128, Configuring BGP Route Map with Next-Hop Self]。
* **同一 Cluster 内における冗長 RR 構成:**
  2 台の RR を冗長化する場合、両ルータで **`bgp cluster-id <同一の32bit値>`**（例: `bgp cluster-id 1.1.1.1`）を設定しないと、RR 相互間で無駄な UPDATE が増幅し、メモリリークや処理遅延の原因となります。
* **Inband RR vs Out-of-band RR:**
  データプレーン上に配置される Inband RR と、コントロールプレーン専用の Out-of-band RR（トラフィックが通過しないルータ）のメトリック選定（IGP metric to Next-Hop）に注意してください。

### 2. BGP Aggregation (`aggregate-address`) の重要ポイントとトラップ
* **`as-set` 欠落によるルーティングループ:**
  他 AS から受信したルートを集約する際に `as-set` を付け忘れると、元の Origin AS 番号が消失します。その結果、元のアドバタイズ元 AS へ集約ルートが再流入した際に自 AS ループ判定が行われず、ルーティングループや非最適パスが発生します [131]。
* **`as-set` 付与に伴うコンバージエンス悪化（Flapping Propagation）:**
  `as-set` を設定すると、要素となる個別ルートの 1 つが Down/Up するたびに集約ルートの AS_PATH 集合が再計算され、対向へ UPDATE が再送されます。これを防ぐためには `suppress-map` や `attribute-map` を適切に設計する必要があります [131]。
* **Atomic Aggregate 属性の読解:**
  `as-set` を付けずに `summary-only` を実行すると、集約経路に **`Atomic_Aggregate`** 属性が自動付加され、「情報が一部損失している」ことが下流ルータへ通知されます [131]。

---

## 🛠 設定方法

### 1. Route Reflector (RR) 基本・冗長設定 (IPv4 / VPNv4)

```bash
# RR (Router 1) 設定
router bgp 65000
 bgp router-id 1.1.1.1
 bgp cluster-id 10.0.0.1
 neighbor 10.1.2.2 remote-as 65000
 neighbor 10.1.2.2 update-source Loopback0
 neighbor 10.1.3.3 remote-as 65000
 neighbor 10.1.3.3 update-source Loopback0
 !
 address-family ipv4
  neighbor 10.1.2.2 activate
  neighbor 10.1.2.2 route-reflector-client
  neighbor 10.1.3.3 activate
  neighbor 10.1.3.3 route-reflector-client
 exit-address-family
```

### 2. BGP Aggregation (`as-set` & `suppress-map` 併用) 設定

```bash
router bgp 65000
 address-family ipv4
  network 10.1.1.0 mask 255.255.255.0
  network 10.1.2.0 mask 255.255.255.0
  !
  # 10.1.0.0/16 へ集約。as-set を付加し、特定ルートのみ suppress-map で抑制
  aggregate-address 10.1.0.0 255.255.0.0 as-set suppress-map RM_SUPPRESS
 exit-address-family
!
ip prefix-list PL_SUPPRESS_TARGET seq 5 permit 10.1.1.0/24
!
route-map RM_SUPPRESS permit 10
 match ip address prefix-list PL_SUPPRESS_TARGET
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BGP テーブルでの RR 属性（Originator_ID, Cluster_List）の確認** | <code>show ip bgp <PREFIX></code> |
| **RR クライアントの設定状態・ピア一覧確認** | <code>show ip bgp summary</code> / <code>show ip bgp neighbors <IP></code> |
| **集約経路（Atomic Aggregate, AS_SET `{...}`）の付加状態確認** | <code>show ip bgp <AGGREGATE_PREFIX></code> |
| **Suppressed（`s` フラグ）個別ルートの抑制状態確認** | <code>show ip bgp</code> （ステート `s` を確認） |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **RR を設置したのに Client 間で iBGP 経路が学習されない。** | `neighbor <IP> route-reflector-client` が該当 Address-Family モード配下で有効化されていない。 | `show ip bgp neighbors <IP>` | `address-family` 配下で明示的に `route-reflector-client` を投入する [56, 1.11.d]。 |
| **RR 導入後、Client 側で Next-Hop 不到達によりルートが Valid にならない。** | RR は Client 間の再反射時に Next-Hop を変更しないため、Client 側で Next-Hop への IGP 疎通がない。 | `show ip bgp <PREFIX>`<br>`show ip route <NEXT_HOP>` | IGP（OSPF/EIGRP）で Next-Hop ネットワークをアドバタイズするか、必要に応じて Route-Map で Next-Hop を調整する [128]。 |
| **`aggregate-address` を投入したのに集約経路が生成されない。** | BGP テーブル上に集約範囲に含まれる個別ルート（Contributor）が 1 つも存在しない。 | `show ip bgp` | 個別プレフィックスが `network` や `redistribute` で正しく BGP に読み込まれているか確認する [131]。 |
| **集約ルート受領側でルートがループ判定されて拒否される。** | `as-set` 付加により、受領側ルータ自身の AS 番号が集約ルートの AS_PATH に含まれてしまっている。 | `show ip bgp <PREFIX>` | 設計を見直し、自 AS 番号が含まれないよう調整するか `allowas-in` を検討する [131]。 |

---

## ⚠ 制限事項

1. **`as-set` 使用時のプレフィックスフラッピング影響:**
   `as-set` を付加した集約経路は、構成要素の 1 つが破棄・再生成されるたびに BGP UPDATE パケットを発生させます。大量の要素ルートを含む広域集約での `as-set` 乱用は避けてください [131]。
2. **RR による Out-of-Band 反射時の Next-Hop 書き換え不能:**
   iBGP スプリットホライズン緩和の仕様上、RR が Client 間で再反射する際、`neighbor next-hop-self` は無効化されます [128]。

---

## 🔄 他技術との関連

* **MPLS L3VPN / MP-BGP:**  
  PE ルータ間の MP-iBGP フルメッシュを回避するため、Route Reflector 上で `address-family vpnv4` を有効化し、`route-reflector-client` を設定することが必須のベストプラクティスとなります [29, 3.2.b]。
* **BGP Community & Outbound Route Filtering (ORF):**  
  集約時の `attribute-map` を使用して `NO_EXPORT` や custom Community を付加し、下流での再拡散を精密制御できます [131]。

---

## 🧩 比較表

### iBGP フルメッシュ vs Route Reflector vs BGP Confederation

| 比較項目 | iBGP Full-Mesh | Route Reflector (RR) | BGP Confederation |
| :--- | :--- | :--- | :--- |
| **スプリットホライズン** | 完全適用 (iBGP 転送禁止) | RR が部分解除 (Reflect) | サブ AS 間で eBGP 風動作 [56, 1.11.d] |
| **ピアセッション数** | $N(N-1)/2$ （高負荷） | 大幅削減 (Client-RR 間のみ) | サブ AS 内に限定削減 |
| **追加属性** | なし | `Originator_ID`, `Cluster_List` [56, 1.11.d] | `AS_CONFED_SEQUENCE`, `AS_CONFED_SET` |
| **設計の容易さ** | 容易（小規模向き） | **極めて容易（デファクト標準）** [56, 1.11.d] | 複雑（AS 設計変更が必要） |

---

## 💡 ベストプラクティス

1. **冗長 RR の Cluster ID 統一:**
   同一クラスタに所属する 2 台の冗長 RR には、同一の `bgp cluster-id <IP>` を設定してループと無駄なパケット重複を防止する。
2. **`aggregate-address as-set summary-only` の標準化:**
   集約時は個別ルートを遮蔽する `summary-only` と、ループを防止する `as-set` をセットで適用することを基本とする [131]。

---

## 📝 ラボ学習・設定サンプル例

### Scenario 1: Basic Route Reflector (IPv4 Unicast)
* **要件:** R1 (RR) の配下に R2 (Client) と R3 (Client) を配置し、R2-R3 間で iBGP フルメッシュを組むことなく経路交換させよ [56, 1.11.d]。

**【R1 (RR)】**
```bash
router bgp 65000
 bgp router-id 1.1.1.1
 neighbor 10.1.12.2 remote-as 65000
 neighbor 10.1.13.3 remote-as 65000
 !
 address-family ipv4
  neighbor 10.1.12.2 activate
  neighbor 10.1.12.2 route-reflector-client
  neighbor 10.1.13.3 activate
  neighbor 10.1.13.3 route-reflector-client
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp 10.1.33.3/32
# Originator: 10.1.33.3, Cluster list: 1.1.1.1 が付与されていることを確認
```

---

### Scenario 2: Redundant RR with Shared Cluster ID
* **要件:** R1 と R4 を冗長 RR として構成し、クラスタ ID に `10.0.0.100` をバインドせよ。

**【R1 / R4 共通設定】**
```bash
router bgp 65000
 bgp cluster-id 10.0.0.100
 address-family ipv4
  neighbor 10.1.2.2 route-reflector-client
  neighbor 10.1.3.3 route-reflector-client
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp neighbors 10.1.2.2
# Route reflector client, Cluster ID: 10.0.0.100 を確認
```

---

### Scenario 3: BGP Basic Aggregation (`summary-only`)
* **要件:** R1 上の `10.1.1.0/24`〜`10.1.3.0/24` を `10.1.0.0/22` に集約し、個別ルートを抑制せよ [131]。

**【R1】**
```bash
router bgp 65000
 address-family ipv4
  network 10.1.1.0 mask 255.255.255.0
  network 10.1.2.0 mask 255.255.255.0
  network 10.1.3.0 mask 255.255.255.0
  aggregate-address 10.1.0.0 255.255.252.0 summary-only
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp
# 10.1.1.0/24 等に 's' (suppressed) が付き、10.1.0.0/22 が送出されていることを確認
```

---

### Scenario 4: Aggregation with `as-set`
* **要件:** eBGP から学習した他 AS のルートを集約する際、Origin AS 属性を保存してルーティングループを防止せよ [131]。

**【R1】**
```bash
router bgp 65000
 address-family ipv4
  aggregate-address 172.16.0.0 255.255.0.0 as-set summary-only
 exit-address-family
```

**【検証方法】**
```bash
R2# show ip bgp 172.16.0.0
# Path: {65001,65002} などの AS_SET 属性を確認
```

---

### Scenario 5: BGP Aggregation with `suppress-map`
* **要件:** 集約ルート `10.2.0.0/16` をアドバタイズしつつ、特定プレフィックス `10.2.1.0/24` のみを例外的に個別にアドバタイズせよ [131]。

**【R1】**
```bash
ip prefix-list PL_EXCEPT_UNSUPPRESS permit 10.2.1.0/24
!
route-map RM_SUPPRESS_EXCEPT deny 10
 match ip address prefix-list PL_EXCEPT_UNSUPPRESS
!
route-map RM_SUPPRESS_EXCEPT permit 20
!
router bgp 65000
 address-family ipv4
  aggregate-address 10.2.0.0 255.255.0.0 suppress-map RM_SUPPRESS_EXCEPT
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp
# 10.2.1.0/24 に 's' フラグが付かず個別に送信されていることを確認
```

---

### Scenario 6: Aggregation with `attribute-map` (Community 付加)
* **要件:** 生成する集約ルートに対して `NO_EXPORT` コミュニティをバインドせよ [131]。

**【R1】**
```bash
route-map RM_SET_COMM permit 10
 set community no-export
!
router bgp 65000
 address-family ipv4
  aggregate-address 10.3.0.0 255.255.0.0 summary-only attribute-map RM_SET_COMM
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip bgp 10.3.0.0
# Community: no-export を確認
```

---

### Scenario 7: MP-BGP VPNv4 Route Reflector
* **要件:** PE ルータ群の VPNv4 ピアを制御する専用 RR を構成せよ [29, 3.2.b]。

**【RR】**
```bash
router bgp 65000
 neighbor 10.1.2.2 remote-as 65000
 neighbor 10.1.2.2 update-source Loopback0
 !
 address-family vpnv4
  neighbor 10.1.2.2 activate
  neighbor 10.1.2.2 send-community extended
  neighbor 10.1.2.2 route-reflector-client
 exit-address-family
```

**【検証方法】**
```bash
RR# show ip bgp vpnv4 all summary
```

---

### Scenario 8: Out-of-Band RR (Data-Path 不参加 RR)
* **要件:** トラフィックを通過させない非データパス RR を構築し、Client 側の IGP コスト選定を正常化させよ。

**【RR】**
```bash
router bgp 65000
 bgp router-id 9.9.9.9
 address-family ipv4
  neighbor 10.1.2.2 route-reflector-client
  neighbor 10.1.3.3 route-reflector-client
 exit-address-family
```

---

### Scenario 9: Aggregation with `unsuppress-map` (Neighbor 個別制御)
* **要件:** 特定の BGP ピア（10.1.4.4）に対してのみ、抑制された個別ルートを復元してアドバタイズせよ。

**【R1】**
```bash
route-map RM_UNSUPPRESS permit 10
 match ip address prefix-list PL_ALLOW_PREF
!
router bgp 65000
 address-family ipv4
  neighbor 10.1.4.4 unsuppress-map RM_UNSUPPRESS
 exit-address-family
```

---

### Scenario 10: VRF-Aware BGP Route Aggregation
* **要件:** VRF `RED` 配下でプレフィックス集約を実施せよ [22, 1.2.e]。

**【R1】**
```bash
router bgp 65000
 address-family ipv4 vrf RED
  aggregate-address 192.168.0.0 255.255.0.0 summary-only
 exit-address-family
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】RR 経由ルートの Next-Hop 不到達問題
**問題:** 
R2 (Client) から R1 (RR) へ学習させた eBGP 経路が、R1 経由で R3 (Client) へ正常に再反射されました。しかし、R3 の Routing Table（RIB）に該当ルートが掲載されません。`show ip bgp` を確認すると `10.1.12.2` (Next-Hop) の横に `*>` マークが付いておらず `inaccessible` と表示されています。R1 には `neighbor 10.1.3.3 next-hop-self` が投入されています。原因と解決策を述べてください。

**解答・解説:**
* **原因:** BGP の仕様により、Route Reflector が Client から学習したルートを他の Client へ再反射する際、**`next-hop-self` コマンドが設定されていても Next-Hop アドレスの書き換えは行われません** [128]。そのため、R3 は元の Next-Hop である `10.1.12.2` への IGP 可達性を持っておらず、ルートが不活性（Inaccessible）となります。
* **解決策:** 
  1. IGP（OSPF/EIGRP）で R2-R1 間の接続セグメント（`10.1.12.0/24`）をアドバタイズして R3 から可達とする。
  2. あるいは RR (R1) の再反射時 Route-Map を使用して `set ip next-hop` を強制バインドする [128]。

---

### 2. 【Design / コンフィグ読解】`as-set` 未指定時のループリスク
**問題:** 
以下のコンフィグを適用した際、AS 65001 からアドバタイズされた個別経路を集約したルートが、再び AS 65001 へ流出した場合にどのような問題が発生するか説明してください。
```text
router bgp 65000
 address-family ipv4
  aggregate-address 10.0.0.0 255.0.0.0 summary-only
 exit-address-family
```

**解答・解説:**
* **問題点:** `as-set` オプションが指定されていないため、集約経路 `10.0.0.0/8` から元の Origin AS（AS 65001）の情報が消去されます [131]。
* **発生する問題:** AS 65001 は自身の AS 番号が AS_PATH に含まれていない集約ルートを受信するため、自 AS ループ判定（AS_PATH Loop Check）を行わずに正常ルートとして受容してしまいます。これにより、ルーティングループや非最適なトラフィック迂回（Sub-optimal Routing）が発生します [131]。
* **修正方法:** `aggregate-address 10.0.0.0 255.0.0.0 as-set summary-only` へ変更し、AS_PATH 集合情報を保持させます [131]。

---

## 🔗 参考リソース

* [Cisco Systems: BGP Route Reflector Configuration Guide](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-int-features.html)
* [Cisco Systems: Understanding Route Aggregation in BGP](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/5441-bgp-aggregation.html)
* [Cisco Live: BRKRST-3320 - Advanced BGP Architecture and Scaling](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **RR 再反射マトリクス (Reflection Matrix):**
  * Client ➔ Client (Reflected)
  * Client ➔ Non-Client (Reflected)
  * Non-Client ➔ Client (Reflected)
  * Non-Client ➔ Non-Client (**Blocked** - Full-Mesh Required)


## 参考リソースリンク

### CiscoLive (動画・スライド)
*   [BRKCCIE-3000: BGP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html) - RRのループ防止属性と集約オプションの深い解説。
*   [BRKRST-3320: Troubleshooting BGP](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320) - AggregationによるAS_PATHループのトラブル解決。

### Configurationガイド
*   [IP Routing: BGP Configuration Guide - Route Reflectors](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_bgp/configuration/15-mt/irg-15-mt-book/irg-int-features.html)。
*   [Understanding BGP Route Aggregation (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/5441-aggregation.html)。

### テクニカルドキュメント・設定例
*   [BGP Case Studies: Scalability (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/26634-bgp-toc.html)。
*   [BGP Attributes: Atomic Aggregate and AS_SET](http://www.networkers-online.com/blog/2010/12/bgp-attributes-atomic-aggergate-atribute/)。

---

## 📝 補足
- この学習メモは、BGPのスケーラビリティ機能が「情報をいかに効率よく整理（Aggregation）し、かつ安全に配布（RR）するか」という目的のために設計されていることを強調しています。特に、RRにおける `Originator_ID` / `Cluster_List` の役割と、Aggregationにおける `as-set` の有無がもたらすループの危険性は、CCIE実技試験におけるトラブルシューティングの最重要ポイントです。

