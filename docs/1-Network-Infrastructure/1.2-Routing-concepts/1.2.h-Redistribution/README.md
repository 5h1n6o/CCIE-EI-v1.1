# 1.2.h Redistribution between BGP, EIGRP, OSPF, and static

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における最重要かつ最もトラブルが頻発するルーティング制御技術である **Redistribution between BGP, EIGRP, OSPF, and static（ルート再配送）** について、Cisco IOS-XE 17.x（Catalyst 9000、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

異なるルーティングプロトコル（EIGRP、OSPF、BGP）やスタティックルーティングが動作するドメイン間でルーティング情報（プレフィックス）を相互に変換・注入し、ネットワーク全体の全対全可達性（Reachability）を確立するメカニズムが **ルート再配送（Redistribution）** です [12, 1.2.h; 22, 1.2.h]。

### 主な利用目的と適用シーン
1. **企業合併・ネットワーク統合 (M&A):** OSPFで構築された企業網とEIGRPで構築された企業網を接続し、互いの経路情報を再配送により交換する。
2. **WAN / インターネット接続 (BGP ↔ IGP):** 本社・拠点間のiBGP/eBGP網と、拠点内部のOSPF/EIGRP網の間でデフォルトルートや特定の社内経路を相互注入する。
3. **スタティック/直結経路の動的拡張 (Static/Connected ➔ IGP):** ルータ上に設定された静的デフォルトルート（`ip route 0.0.0.0 0.0.0.0 Null0`）や、特定のLoopback/VLANインターフェイス（Connected）をIGPドメインへ動的にブロードキャスト/アドバタイズする。
4. **SD-Access / SD-WAN 境界 (Fusion Router):** ファブリック外の共有サービスやレガシーIGPドメインと、SD-Access / SD-WAN 境界ルータ間でVRFごとの経路を相互再配送する。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 異なるメトリック・アルゴリズム・管理距離（AD）を持つプロトコル間で経路情報を変換してルーティングテーブル（RIB）に注入する [12, 1.2.h; 55, 1.1]。 |
| **用途** | 異種IGPの相互接続、BGPとIGPの連動、Static/Connected経路の動的再配送。 |
| **メリット** | 異種プロトコル環境であってもエンドツーエンドのL3フルメッシュ可達性を確立可能。 |
| **デメリット** | **サブオプティマルルーティング（迂回経路）** や **ルーティングループ（経路フィードバック）**、コントロールプレーンの不安定化を引き起こす最大のリスク要因。 |
| **対応機種** | すべての Cisco IOS / IOS-XE デバイス（Catalyst 9000, Catalyst 8000v, ISR/ASR シリーズ）。 |
| **制限事項** | プロトコルごとにシードメトリック（Seed Metric）のデフォルト動作が異なる（EIGRPはシードメトリック指定が必須）。iBGP経路のIGPへの再配送は危険。 |
| **設計上の注意点** | マルチホーム（多重境界）ポイントでの再配送では、**Route Tagging（タグ付け）** や **Administrative Distance (AD) の調整** によるルートフィードバック防止策が必須。 |

---

## 🏗 動作原理

再配送の根本原則は、**「自ルータのルーティングテーブル（RIB）に現在アクティブとして登録されている経路（Best Path）のみが、他プロトコルへ再配送の対象となる」** という点です。

```text
 [ Source Protocol (例: EIGRP) ]
             │
             ▼ (RIBへの登録確認)
   [ IP Routing Table (RIB) ] ── (Best Path としてアクティブか？)
             │
             ├─ YES ➔ [ Route-Map / Filter 判定 ] ➔ [ シードメトリック変換 ] ➔ [ Destination Protocol (例: OSPF) ]
             └─ NO  ➔ 【再配送対象外 (無視)】
```

### プロトコル別 シードメトリック（デフォルトメトリック）一覧

再配送時に宛先プロトコルへ注入される初期メトリックを **シードメトリック（Seed Metric）** と呼びます。

| 再配送先プロトコル | 送信元プロトコル | デフォルトシードメトリック | 補足 / 必須指定コマンド |
| :--- | :--- | :--- | :--- |
| **EIGRP** | 全プロトコル (OSPF, BGP, Static, Connected) | **なし (Infinity/無限大)** | **`default-metric`** または `redistribute` コマンド内の `metric <BW> <Delay> <Reliability> <Load> <MTU>` 指定が**絶対必須**。指定しない場合、再配送されない [13, Lab 16; 55, 1.1]。 |
| **OSPF** | BGP | **1** | タイプは **E2 (External Type 2)**。 |
| **OSPF** | EIGRP, Static, Connected, RIP | **20** | タイプは **E2**。IPv4 OSPFv2では **`subnets`** キーワードを付けないとサブネット化された経路が無視されるため**絶対必須** [3, Task 1]。 |
| **BGP** | IGP (EIGRP, OSPF), Static, Connected | **IGPのメトリックを継承** | MED (Multi-Exit Discriminator) にIGPメトリックが設定される。OSPFの再配送ではデフォルトで **`match internal`**（Intra/Inter-areaのみ）。外部分析経路は `match external 1 external 2 nssa-external 1 nssa-external 2` が必要。 |
| **RIP** | 全プロトコル | **なし (Infinity)** | `default-metric <1-15>` または `metric` の指定が必須。 |

---

## ⚙ 動作シーケンス

### 多重再配送（Multi-homed Mutual Redistribution）におけるルーティングループ発生メカニズム

2台の境界ルータ（R1, R2）で OSPF (AD 110) と EIGRP (Internal AD 90, External AD 170) を相互に再配送する場合のループ発生シーケンスを示します。

```text
  [ OSPF Domain (AD 110) ] ◄━━━━► [ Router R1 ] ━━━━► [ EIGRP Domain ]
                                        ▲
                                        │ (再配送ループ)
                                        ▼
                                  [ Router R2 ] ◄━━━━► [ EIGRP Domain ]

 1. OSPFドメイン内に 10.1.1.0/24 (AD 110) が発生。
 2. Router R1 が OSPF 10.1.1.0/24 を EIGRP へ再配送。
    ➔ EIGRP External 経路 (AD 170) として EIGRP ドメインへアドバタイズ。
 3. Router R2 が EIGRP 経由で 10.1.1.0/24 (AD 170) を受信。
    ➔ R2 は本来 OSPF 経由 (AD 110) で直接見ているため、R2 の RIB は OSPF (AD 110) が勝つ。
 4. 【障害発生時または設定不備の罠】:
    もし R1 と OSPF ドメイン間のリンクがダウンすると、R1 は OSPF 経路を消失。
    R1 は R2 から EIGRP External (AD 170) 経由で 10.1.1.0/24 を学習し、RIB に登録。
 5. R1 は OSPF へ EIGRP 10.1.1.0/24 を再配送 ➔ OSPF External (AD 110) としてアドバタイズ！
 6. R2 は R1 から OSPF External (AD 110) を受信。
    R2 の従来の EIGRP 外部経路 (AD 170) よりも OSPF External (AD 110) の方が AD が低いため、R2 は RIB を OSPF (via R1) に書き換える！
 7. 【結果】R1 と R2 の間でパケットが永久に往復するルーティングループ（Route Feedback）が完成。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI実技ラボ試験において、再配送は単なる「コマンド入力」ではなく、**「ルーティングループの非発生」「サブオプティマルルーティングの防止」「特定のプレフィックスのみの選択的再配送」** という厳格な制約条件を満たすことが求められます。

### 1. 必修チェックリスト＆落とし穴
1. **OSPFv2 再配送時の `subnets` キーワード抜け:**
   `redistribute eigrp 100` とだけ設定すると、クラスフルアドレス（/8, /16, /24）しか再配送されず、サブネット化された経路（/28, /30等）がすべて無視されます。必ず `redistribute eigrp 100 subnets` と指定します [3, Task 1]。
2. **EIGRP 再配送時のメトリック未指定:**
   EIGRPへの再配送でメトリックを指定しないと、再配送された経路は `show ip eigrp topology` に表示されず、一切アドバタイズされません [13, Lab 16]。
   * 対策: `redistribute ospf 1 metric 10000 10 255 1 1500` または `default-metric 10000 10 255 1 1500`
3. **OSPF から BGP への再配送時の External 経路不着:**
   デフォルトの `redistribute ospf 1` は OSPF の Intra-area (O) および Inter-area (O IA) のみをBGPへ引き継ぎます。OSPFの外部経路 (O E1 / O E2 / O N1 / O N2) もBGPに送るには以下が必要です。
   * 対策: `redistribute ospf 1 match internal external 1 external 2 nssa-external 1 nssa-external 2`
4. **BGP から IGP への再配送における iBGP ルートの保護機能:**
   BGPからOSPFやEIGRPへ再配送を行う際、デフォルトでは **eBGP 経由で学習した経路のみ** が再配送されます。iBGP 経由で学習した経路は、ループ防止のためデフォルトでIGPへ再配送されません。どうしても再配送が必要な場合は BGP プロセス配下で `bgp redistribute-internal` が必要ですが、試験では原則推奨されません。

### 2. ルーティングループ防止の2大技法

#### 技法A: Route Tagging（タグ付けとタグフィルタ）
再配送時にプレフィックスに数値タグ（Tag）を付与し、対向の境界ルータでそのタグを持つ経路の再配送を拒否（deny）します。

```text
[ SW1 / R1 (Boundary 1) ]
 - OSPF ➔ EIGRP 再配送時に tag 110 を付与
 - EIGRP ➔ OSPF 再配送時に tag 90 が付いている経路を deny

[ SW2 / R2 (Boundary 2) ]
 - EIGRP ➔ OSPF 再配送時に tag 90 を付与
 - OSPF ➔ EIGRP 再配送時に tag 110 が付いている経路を deny
```

#### 技法B: Administrative Distance (AD) の調整
EIGRP External (AD 170) や OSPF External (AD 110) の AD 値を変更し、再配送された経路が元のドメインに逆流して最優先経路として上書きされるのを物理的に防ぎます。
* 例: EIGRP External の AD を OSPF (110) より低い `105` に変更する、あるいは OSPF External の AD を `180` に引き上げる。
  ```bash
  # OSPFプロセス配下で外部経路のADを180に変更
  router ospf 1
   distance ospf external 180
  ```

---

## 🛠 設定方法

Cisco IOS-XE 17.x における主要な再配送パターン別の完全 CLI コンフィグ例です。

### 1. OSPF ➔ EIGRP (Named Mode) 再配送

```bash
router eigrp CCIE_DOMAIN
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   # OSPF 1 からの再配送 (帯域10Gbps, 遅延10微秒, 信頼性255, 負荷1, MTU1500)
   redistribute ospf 1 metric 10000000 1 255 1 1500
  exit-af-topology
 exit-af
```

### 2. EIGRP ➔ OSPFv2 再配送 (Subnets指定)

```bash
router ospf 1
 router-id 1.1.1.1
 # subnets キーワードを必須指定。E2ルートとしてコスト20で注入
 redistribute eigrp 100 subnets metric 20 metric-type 2
```

### 3. BGP ➔ OSPFv2 再配送 (特定 Route-Map 結合)

```bash
ip prefix-list BGP_TO_OSPF permit 172.16.0.0/16 ge 24 le 24

route-map RM_BGP_TO_OSPF permit 10
 match ip address prefix-list BGP_TO_OSPF
 set metric 50
 set metric-type type-1
exit

router ospf 1
 redistribute bgp 65001 subnets route-map RM_BGP_TO_OSPF
```

### 4. Static 経路の OSPF / EIGRP 再配送

```bash
# 静的デフォルトルートおよび特定の静的経路
ip route 0.0.0.0 0.0.0.0 Null0
ip route 10.254.0.0 255.255.0.0 192.168.1.1

router ospf 1
 # default-information originate でデフォルトルートを注入
 default-information originate always metric 10
 # 通常のスタティック経路のみを再配送
 redistribute static subnets
```

---

## 🔍 検証コマンド

| 目的 | コマンド | 注目すべきポイント |
| :--- | :--- | :--- |
| **ルーティングテーブルにおける再配送経路（AD・メトリック）の確認** | <code>show ip route</code> | `D EX`（EIGRP External: AD 170）、`O E1/E2`（OSPF External: AD 110）、`B`（BGP: AD 20/200）の表示確認。 |
| **OSPFデータベース内の再配送（Type-5 LSA）情報・タグの確認** | <code>show ip ospf database external</code> | Advertising Router、Link State ID、Forward Address、Tag 数値の確認。 |
| **EIGRPトポロジーテーブル内の外部経路詳細の確認** | <code>show ip eigrp topology \| section External</code> | Originating Router、External Protocol (OSPF/BGP)、External Metric の確認。 |
| **BGPテーブル内の IGP/Static 再配送経路の確認** | <code>show ip bgp</code> | Origin Code（`?` incomplete 表示）、MED 値（IGP メトリックの引継ぎ確認）。 |
| **再配送プロセスのリアルタイムデバッグ** | <code>debug ip ospf redist</code> / <code>debug ip eigrp notifications</code> | 再配送トリガー時のイベントログ検出。 |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **EIGRPへの再配送設定を入れたが、相手側ルータで経路が全く学習されない。** | 物理メトリック（BW/Delay等）または `default-metric` が指定されておらず、シードメトリックが「無限大（Infinity）」になっている [13, Lab 16]。 | `show ip eigrp topology` | `redistribute ... metric <BW> <Delay> <Reliability> <Load> <MTU>` を指定する [13, Lab 16]。 |
| **OSPFへEIGRPを再配送したが、主クラス（Classful）の網しか届かず、/24や/30のサブネットが消えている。** | OSPFv2の `redistribute` コマンドで **`subnets` キーワードが欠落** している [3, Task 1]。 | `show run \| section router ospf` | `redistribute eigrp <AS> subnets` に修正する [3, Task 1]。 |
| **OSPFの外部経路（O E2）が BGP に再配送されない。** | BGPの `redistribute ospf` はデフォルトで `match internal`（O, O IA）しか引き継がない。 | `show run \| section router bgp` | `redistribute ospf <ID> match internal external 1 external 2` を指定する。 |
| **2台の境界ルータを起動すると、特定のプレフィックスのネクストホップが周期的にコロコロ変わり、CPUが高騰する。** | **双方向再配送によるルーティングループ（Route Feedback）が発生している。** | `show ip route <PREFIX>`<br>`show ip ospf database external` | Route-Map による **Tagging** を実装し、自ドメイン由来の再配送経路を対向境界で遮断する。 |

---

## ⚠ 制限事項

1. **OSPF Forwarding Address (FA) の非ゼロ条件:**
   OSPFへ再配送を行う際、NSSA (Type-7) や External (Type-5) で Forwarding Address (FA) が `0.0.0.0` 以外の IP にセットされるには、送信元インターフェイスが OSPF で有効化されており、`passive-interface` でなく、P2P リンクでない等の条件を満たす必要があります。FA が不適切な IP になると通信不可の原因になります。
2. **iBGP 経路の再配送に関する標準制約:**
   iBGP から IGP への再配送は、BGP ルーティングループを引き起こす致命的リスクがあるため、`bgp redistribute-internal` を明示しない限り動作しない設計になっています。

---

## 🔄 他技術との関連

* **Route Maps & Prefix Lists:**
  再配送の制御（フィルタリング・メトリック変更・タグ付与）において最も高頻度で組み合わせて使用されます [55, 1.2]。
* **VRF-Lite & MPLS L3VPN:**
  VRF対応ルーティングにおいて、各 VRF の `address-family` 配下で個別に再配送（例: VRF GREEN 内の OSPF ➔ BGP）を定義します [22, 1.2.e]。
* **BGP MED (Multi-Exit Discriminator):**
  IGP から BGP へ再配送された際、IGP の内部メトリックが自動的に BGP の MED 値としてコピーされ、対向 AS に対する優先パス制御に活用されます。

---

## 🧩 比較表

### 各プロトコルへの再配送におけるシードメトリックとデフォルト動作比較

| 注入先プロトコル | 必要キーワード / コマンド | シードメトリックのデフォルト | デフォルトで対象となるルートタイプ |
| :--- | :--- | :--- | :--- |
| **EIGRP** | `metric <BW> <Delay> ...` (必須) [13, Lab 16] | なし (無限大・配送不能) | 全ルーティングテーブル適合経路 |
| **OSPFv2** | `subnets` (必須) [3, Task 1] | 20 (BGP由来のみ 1) | 全サブネット（`subnets` 指定時） |
| **BGP** | `match internal external 1 2` | IGPのメトリック値をそのまま参照 | デフォルトは Intra/Inter-Area のみ |

---

## 💡 ベストプラクティス

1. **再配送境界ポートにおける「全ルートへのタグ（Tag）付与」の徹底:**
   再配送を行うすべての `route-map` エントリにおいて、注入先のプロトコルに応じた一意の Tag（例: OSPFへ入れる経路には `set tag 110`、EIGRPへ入れる経路には `set tag 90`）を付与し、対向の境界ルータのインバウンド側で `match tag` による拒否（deny）を徹底します。
2. **OSPFv2 での `subnets` キーワードの無条件指定:**
   IPv4 OSPF への再配送では、トラブル未然防止のため理由のいかんを問わず常に `subnets` を付与します [3, Task 1]。
3. **EIGRP Named Mode での明示的メトリック設定:**
   `topology base` 配下で再配送を設定する際は、インターフェイス遅延や帯域幅を正しく反映させたメトリックを定義します [13, Lab 16]。

---

## 📝 ラボ学習・設定サンプル例

※本サンプルは、Cisco IOS-XE 17.x（Catalyst 9000 / Catalyst 8000v）のCLI挙動に完全準拠した省略なしのコンフィグです。

### シナリオ1: OSPFv2 から EIGRP (Named Mode) への単方向再配送
**【問題】**
SW1 において、OSPF プロセス 1 で学習したすべての経路（サブネット含む）を、EIGRP Named Mode (`CCIE_DOMAIN`) の Autonomous-System 100 へ再配送してください。
* 帯域幅: 10,000,000 Kbps (10Gbps)
* 遅延: 1 (10 microseconds)
* 信頼性: 255
* 負荷: 1
* MTU: 1500

**【設定例】**
```bash
SW1# configure terminal
router eigrp CCIE_DOMAIN
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   redistribute ospf 1 metric 10000000 1 255 1 1500
  exit-af-topology
 exit-af
end
```

**【検証方法】**
```bash
SW1# show ip eigrp topology | section External
# OSPF由来のプレフィックスが External としてトポロジーテーブルに存在することを確認
```

---

### シナリオ2: EIGRP から OSPFv2 への単方向再配送（Subnets & Type-1指定）
**【問題】**
R1 において、EIGRP AS 100 から学習した経路を OSPF プロセス 1 へ再配送してください。
* サブネット化された経路を含めること。
* OSPF 外部ルートタイプは Type-1 (E1) とし、初期メトリックは 50 に設定すること。

**【設定例】**
```bash
R1# configure terminal
router ospf 1
 router-id 1.1.1.1
 redistribute eigrp 100 subnets metric 50 metric-type 1
end
```

**【検証方法】**
```bash
R1# show ip ospf database external
# Link State ID 配下に EIGRP 由来のプレフィックスが Metric Type 1, Metric 50 で存在することを確認
```

---

### シナリオ3: Tagging を用いた OSPF ↔ EIGRP 双方向再配送（ループ防止）
**【問題】**
境界ルータ R1 および R2 において、OSPF 1 と EIGRP 100 の間で双方向再配送を構成してください。
* OSPF から EIGRP へ再配送する経路には Tag `110` を付与すること。
* EIGRP から OSPF へ再配送する経路には Tag `90` を付与すること。
* お互いに相手が付与した Tag を持つ経路の再配送を遮断し、ルーティングループを完璧に防止すること。

**【R1 設定例】**
```bash
R1# configure terminal
! --- Route-Maps for OSPF -> EIGRP ---
route-map RM_OSPF_TO_EIGRP deny 10
 match tag 90
exit

route-map RM_OSPF_TO_EIGRP permit 20
 set tag 110
exit

! --- Route-Maps for EIGRP -> OSPF ---
route-map RM_EIGRP_TO_OSPF deny 10
 match tag 110
exit

route-map RM_EIGRP_TO_OSPF permit 20
 set tag 90
exit

! --- EIGRP Configuration ---
router eigrp CCIE_NET
 !
 address-family ipv4 unicast autonomous-system 100
  !
  topology base
   redistribute ospf 1 metric 100000 10 255 1 1500 route-map RM_OSPF_TO_EIGRP
  exit-af-topology
 exit-af

! --- OSPF Configuration ---
router ospf 1
 redistribute eigrp 100 subnets route-map RM_EIGRP_TO_OSPF
end
```

**【検証方法】**
```bash
R1# show ip route
# 相互再配送後も、ループやルートの相互上書き（Route Feedback）が発生しないことを確認
```

---

### シナリオ4: Static 経路の OSPF への選択的再配送 (Prefix-List 結合)
**【問題】**
R1 上に設定された多数の Static 経路のうち、`10.50.0.0/16` 配下の `/24` プレフィックスのみを OSPF プロセス 1 へ再配送してください。

**【設定例】**
```bash
R1# configure terminal
ip prefix-list PL_STATIC_FILTER permit 10.50.0.0/16 ge 24 le 24

route-map RM_STATIC_TO_OSPF permit 10
 match ip address prefix-list PL_STATIC_FILTER
 set metric 30
exit

router ospf 1
 redistribute static subnets route-map RM_STATIC_TO_OSPF
end
```

**【検証方法】**
```bash
R1# show ip ospf database external
# 10.50.x.x/24 のみが Type-5 LSA として生成されていることを確認
```

---

### シナリオ5: OSPF 外部経路 (E1/E2) の BGP への再配送
**【問題】**
R1 において、OSPF 1 の内部経路（Intra/Inter）だけでなく、OSPF 内に存在する外部経路（E1/E2）も含めて BGP AS 65001（Address-family IPv4）へ再配送してください。

**【設定例】**
```bash
R1# configure terminal
router bgp 65001
 bgp router-id 1.1.1.1
 address-family ipv4 unicast
  redistribute ospf 1 match internal external 1 external 2
 exit-af
end
```

**【検証方法】**
```bash
R1# show ip bgp
# Origin Code が '?' (incomplete) として OSPF の全外部経路が BGP テーブルに登録されていることを確認
```

---

### シナリオ6: BGP 経路の EIGRP への再配送と MED 属性制御
**【問題】**
R1 において、BGP AS 65001 で学習した特定経路（`172.16.10.0/24`）のみを EIGRP AS 100 へ再配送してください。

**【設定例】**
```bash
R1# configure terminal
ip prefix-list PL_BGP_ROUTES permit 172.16.10.0/24

route-map RM_BGP_TO_EIGRP permit 10
 match ip address prefix-list PL_BGP_ROUTES
 set metric 100000 10 255 1 1500
exit

router eigrp 100
 redistribute bgp 65001 route-map RM_BGP_TO_EIGRP
end
```

**【検証方法】**
```bash
R1# show ip eigrp topology 172.16.10.0/24
# EIGRP トポロジー内に BGP 由来の外部経路として登録されていることを確認
```

---

### シナリオ7: VRF 内における OSPF と Static 経路の相互再配送
**【問題】**
VRF `RED` 内において、OSPF プロセス 100 と Static 経路を相互に再配送してください。

**【設定例】**
```bash
R1# configure terminal
vrf definition RED
 address-family ipv4
exit-af

ip route vrf RED 192.168.100.0 255.255.255.0 Null0

router ospf 100 vrf RED
 domain-id 0.0.0.100
 redistribute static subnets
end
```

**【検証方法】**
```bash
R1# show ip route vrf RED
# OSPF vrf RED のルーティングテーブル内に Static 経路が O E2 として配布準備完了していることを確認
```

---

### シナリオ8: OSPF から RIPv2 への再配送と Default-Metric 設定
**【問題】**
R1 において、OSPF 1 の経路を RIP プロセスへ再配送してください。RIP 全体のデフォルトメトリックを `3` ホップに設定してください。

**【設定例】**
```bash
R1# configure terminal
router rip
 version 2
 default-metric 3
 redistribute ospf 1
end
```

**【検証方法】**
```bash
R1# show ip rip database
# OSPF 由来の経路が Metric 3 で RIP データベースに載っていることを確認
```

---

### シナリオ9: AD (Administrative Distance) 調整による再配送ループの恒久防止
**【問題】**
OSPF 1 から EIGRP 100 へ再配送された経路が、別ルートを経由して OSPF へ逆流するのを防ぐため、R1 において OSPF の外部経路（External）の AD 値をデフォルトの `110` から `180` に引き上げてくだざい。

**【設定例】**
```bash
R1# configure terminal
router ospf 1
 distance ospf external 180
end
```

**【検証方法】**
```bash
R1# show ip route
# O E2 / O E1 経路の AD 値が [180/20] などに変更されていることを確認
```

---

### シナリオ10: OSPFv3 (IPv6) における EIGRPv6 経路の再配送
**【問題】**
R1 において、EIGRPv6（Named Mode `EIGRP_V6`）で学習した IPv6 プレフィックスを OSPFv3 プロセス 1（Address-family IPv6）へ再配送してください。

**【設定例】**
```bash
R1# configure terminal
router ospfv3 1
 address-family ipv6 unicast
  redistribute eigrp 100
 exit-af
end
```

**【検証方法】**
```bash
R1# show ipv6 ospf 1 database external
# IPv6 Type-5 (External) LSA として EIGRPv6 経路がアドバタイズされていることを確認
```

---

## ❓ 想定試験問題

### 1. 【トラブルシューティング】再配送設定後、EIGRP 側ルータで経路が学習されない
**問題:**
境界ルータ R1 で以下のコマンドを設定して OSPF 経路を EIGRP に再配送しました。
```text
router eigrp 100
 redistribute ospf 1
```
しかし、隣接する EIGRP ルータ R2 のルーティングテーブルに OSPF の経路が一切出現しません。原因と解決策を述べてください。

**解答・解説:**
* **原因:** EIGRP は再配送時のデフォルトシードメトリック（Seed Metric）が存在せず（無限大 / Infinity）、明示的なメトリック指定がない場合は再配送を拒否する仕様になっているため [13, Lab 16]。
* **解決策:** `redistribute ospf 1 metric 10000 10 255 1 1500` のように 5 つの K 値パラメータ（帯域幅、遅延、信頼性、負荷、MTU）を明示指定するか、`default-metric` を設定する [13, Lab 16]。

---

### 2. 【コンフィグ読解】OSPF 再配送におけるプレフィックス漏れ
**問題:**
以下のコンフィグを実行したところ、`10.1.1.0/24` や `172.16.2.0/30` などのサブネット化された EIGRP 経路が OSPF 側に再配送されませんでした。
```text
router ospf 1
 redistribute eigrp 100
```
なぜサブネットが再配送されないのか、および修正コマンドを答えてください。

**解答・解説:**
* **原因:** OSPFv2 (IPv4) において `subnets` キーワードを省略すると、クラスフルなネットワーク（/8, /16, /24のナチュラルマスク）のみが対象となり、サブネット化されたプレフィックスはすべて無視されるため [3, Task 1]。
* **修正:** `redistribute eigrp 100 subnets` に変更する [3, Task 1]。

---

### 3. 【トラブルシューティング】BGP ➔ OSPF 再配送で一部経路が失われる
**問題:**
BGP で学習した `10.200.1.0/24` (eBGP 経由) と `10.200.2.0/24` (iBGP 経由) のうち、OSPF に再配送されたのは `10.200.1.0/24` のみでした。iBGP 経路が OSPF に注入されない理由を説明してください。

**解答・解説:**
* **原因:** BGP はルーティングループおよび大規模障害（IGPストーム）を防ぐため、デフォルトで iBGP 経由で学習したプレフィックスを IGP（OSPF/EIGRP/RIP）へ再配送しない安全仕様になっているため。
* **補足:** どうしても注入が必要な場合は `bgp redistribute-internal` コマンドが必要となる。

---

### 4. 【設計】二重境界ルータ（Multi-homed）環境でのルーティングループ防止
**問題:**
OSPF と EIGRP を接続する 2 台の境界ルータ R1、R2 において、相互再配送（Mutual Redistribution）を構成する際、ルーティングループを防止するための最も標準的な設計手法を 2 つ挙げてください。

**解答・解説:**
1. **Route Tagging (タグ付け):** OSPF ➔ EIGRP 注入時に Tag を付与し、EIGRP ➔ OSPF 注入時にその Tag を持つ経路を Filter (deny) する（逆も同様）。
2. **Administrative Distance (AD) 調整:** 外部注入経路の AD（例: OSPF External AD）を引き上げるか、EIGRP External AD を変更し、元のドメインの AD より優位に立たないよう調整する。

---

### 5. 【実装】OSPF 外部経路 (E1/E2) の BGP 再配送
**問題:**
OSPF 1 の内部経路（Intra/Inter）だけでなく、OSPF 内に存在する他プロトコルからの外部再配送経路（E1/E2）も合わせて BGP へ引き継ぎたい場合に必要な BGP 再配送コマンドの構文を記述してください。

**解答・解説:**
* **コマンド:**
  ```text
  router bgp <AS>
   address-family ipv4
    redistribute ospf 1 match internal external 1 external 2
  ```

---

## 🔗 参考リソース

### Cisco ソフトウェア設定ガイド (Configuration Guide)
* [**Cisco IOS XE 17.x IP Routing: Protocol-Independent Configuration Guide - Redistributing Routing Information**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-16/iri-xe-16-book/iri-redis-vinfo.html)
  * 各プロトコル間での再配送メカニズム、シードメトリック、Route-Map 結合に関する Cisco 公式ガイド。
* [**Cisco IOS XE 17.x Dynamic-Routing Command Reference - redistribute commands**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/command/iri-cr-book.html)
  * `redistribute` コマンドの全パラメータ仕様。

### Cisco Live スライド・動画
* [**BRKRST-2337: Advanced IP Routing Architecture and Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)
  * 多重再配送（Mutual Redistribution）におけるループ発生ロジックと Tagging 制御の完全解説。

### テクニカルノート (Technical Notes)
* [**Redistributing Routing Protocols - Cisco Systems**](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/8606-redist.html)
  * 再配送の原理、シードメトリック、タグ付け、AD 調整によるループ防止設計の決定版ガイド。

---

## 📝 **補足（Notes）**

### 再配送判定フローチャート

```text
 [ 対象プレフィックスが RIB に存在 ]
               │
               ▼
 [ RIB で Active (Best Path) か？ ]
        │                       │
       YES                      NO ➔ 【再配送除外】
        │
        ▼
 [ route-map による Filter 判定 ]
        │                       │
      PERMIT                  DENY ➔ 【再配送除外】
        │
        ▼
 [ シードメトリック (Seed Metric) 設定あり？ ]
        │                       │
       YES                      NO (EIGRP/RIP等の場合) ➔ 【再配送不可 (Infinity)】
        │
        ▼
 [ 送信先プロトコルのテーブルへ注入完了 ]
```

* **チェックリスト:**
  * [ ] OSPFv2 への再配送時に `subnets` キーワードを付与したか？ [3, Task 1]
  * [ ] EIGRP への再配送時に 5 つの K 値メトリックまたは `default-metric` を設定したか？ [13, Lab 16]
  * [ ] 2台以上の境界ルータが存在する場合、Tagging によるループ遮断ロジックを構成したか？
  * [ ] BGP ➔ OSPF/EIGRP 再配送時に iBGP 経路の扱いを正しく認識しているか？
