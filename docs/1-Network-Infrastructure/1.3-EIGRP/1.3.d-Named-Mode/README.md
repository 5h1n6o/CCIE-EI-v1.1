---
layout: default
title: 1.3.d-Named-Mode
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 4
---

CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるモダンな IGP 構成標準である **`1.3.d EIGRP named mode`** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に完全準拠した詳細な学習メモ（`1.3.d-eigrp-named-mode.md`）を作成しました [22, 1.3.d]。

作成したファイルはスタジオパネル（Studio）より直接参照・ダウンロードしていただけます。

---

# 1.3.d EIGRP named mode

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験におけるコア IGP のモダンな構成標準である **EIGRP Named Mode（EIGRP ネームドモード）** のアーキテクチャ、階層型コンフィグ構造、Classic Mode からの移行、Wide Metrics、マルチアドレスファミリー（IPv4/IPv6/VRF）の統合管理、トラブルシューティング、および高度なラボ実装シナリオについて、Cisco IOS-XE 17.x の実装基準に完全準拠して解説します [22, 1.3.d]。

---

## 📘 概要

**EIGRP Named Mode（ネームドモード）** とは、Cisco IOS 15.0(1)M および IOS-XE 3.10S（Catalyst 9000 シリーズ標準）以降で導入された EIGRP の新しいコンフィグレーションフレームワークです [1, Task 1; 8, Lab 7-3; 13, Lab 12; 14, Task 1]。

従来の **Classic Mode（クラシックモード：`router eigrp <AS>`）** では、グローバル設定、インターフェイス設定（`ip hello-interval eigrp` 等）、IPv6 設定（`ipv6 router eigrp <AS>`）、VRF 設定がルータ内の複数の場所に分散して記述されていました。Named Mode では、これらを **単一のインスタンス名（例: `router eigrp CCIE_FABRIC`）** の下にすべて一元化し、直感的かつ階層的に定義できるよう刷新されました [1, Task 1; 8, Lab 7-3; 13, Lab 12; 14, Task 1]。

### 主な利用目的と適用シーン
1. **IPv4 / IPv6 / VRF の一元管理:** 単一の EIGRP プロセス名の下で、`address-family` モードを用いて複数の IP バージョンやマルチテナント VRF を統合制御する [1, Task 1; 8, Lab 7-3; 13, Lab 12; 14, Task 1]。
2. **次世代 64-bit Wide Metrics の利用:** 10Gbps、40Gbps、100Gbps 超の高速キャンパス・データセンターリンクにおいて、メトリックの飽和（頭打ち）を防ぐ高精度な計算をデフォルトで有効化する [8, Lab 7-3; 13, Lab 12]。
3. **高度なセキュリティ・認証の標準化:** インターフェイス単位の `af-interface` モード内で HMAC-SHA-256 暗号化認証を直接キー文字列指定で構成する [13, Lab 13]。
4. **Cisco SD-Access / SD-WAN アンダーレイの標準化:** DNA Center や Catalyst Center が生成する最新のアンダーレイコンフィグとの親和性向上。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | インスタンス名（例: `router eigrp <NAME>`）を使用した階層構造。IPv4 / IPv6 / VRF を同一モード内で定義可能。64-bit Wide Metrics がデフォルト有効 [1, Task 1; 8, Lab 7-3; 13, Lab 12; 14, Task 1]。 |
| **用途** | エンタープライズ網（キャンパス、WAN、DMVPN、SD-Access アンダーレイ、データセンター接続等）における一元化ルーティング制御 [21, 1.3.d]。 |
| **メリット** | ① 設定が 1 箇所に集約され可読性・管理性が向上。<br>② インターフェイス個別設定が `af-interface` に統合。<br>③ 高速リンク（10G以上）での精密なメトリック計算（Wide Metrics）。<br>④ Key-Chain なしで HMAC-SHA-256 認証を直接設定可能 [8, Lab 7-3; 13, Lab 12, Lab 13]。 |
| **デメリット** | Classic Mode との混在時にメトリック計算（Scale Factor）の差による不適等コスト問題が生じる可能性がある（K値ミスマッチにも配慮が必要） [8, Lab 7-3]。 |
| **制限事項** | Wide Metrics は Classic Mode（32-bit）ルータへアドバタイズされる際、自動的に 128 で除算されてスケーリングされる [8, Lab 7-3]。 |
| **設計上の注意点** | Classic Mode からの移行時、`router upgrade eigrp <NAME>` コマンドを使用可能だが、事前のバックアップと切り替えタイミングの検討が必須。 |

---

## 🏗 動作原理

EIGRP Named Mode は、内部コンフィグレーション構造が 3 つの明確な階層（Hierarchy）に分類されています [1, Task 1; 8, Lab 7-3; 13, Lab 12; 14, Task 1]。

```text
[ Global Instance Mode ]  ──► router eigrp CCIE_FABRIC
       │
       ├─► [ Address-Family Mode ]  ──► address-family ipv4 unicast autonomous-system 100
       │          │
       │          ├─► [ AF-Interface Mode ]  ──► af-interface GigabitEthernet1/0/1
       │          │                                  ├─ passive-interface / no passive-interface
       │          │                                  ├─ hello-interval / hold-time
       │          │                                  └─ authentication mode hmac-sha-256
       │          │
       │          └─► [ Topology Mode ]      ──► topology base
       │                                             ├─ variance
       │                                             ├─ redistribute
       │                                             └─ offset-list
       │
       └─► [ Address-Family IPv6 Mode ] ──► address-family ipv6 unicast autonomous-system 200
                  │
                  └─► (af-interface / topology base)
```

1. **Global Instance Mode (`router eigrp <NAME>`):**
   * プロセス全体の識別名（ネーム）を定義するトップ階層。この段階では AS 番号はアサインされません [1, Task 1; 13, Lab 12]。
2. **Address-Family Mode (`address-family <ipv4|ipv6> unicast [vrf <VRF>] autonomous-system <AS>`):**
   * 実際のプロトコル動作（AS 番号の割り当て、ネットワークアドバタイズ `network` 指定）を行う中間階層 [1, Task 1; 13, Lab 12]。
3. **AF-Interface Mode (`af-interface <interface|default>`):**
   * 従来 `interface GigabitEthernet` 配下に個別に書いていた `ip hello-interval`、`passive-interface`、`authentication` 等を束ねて設定する階層 [13, Lab 12, Lab 13]。
4. **Topology Mode (`topology base` または `topology <NAME>`):**
   * DUAL アルゴリズム、メトリック調整（`variance`、`offset-list`）、再配送（`redistribute`）、サマリー・フィルタリングを定義する階層 [13, Lab 5, Lab 12]。

---

## ⚙ 動作シーケンス

1. **Named プロセスの初期化:**
   `router eigrp <NAME>` コマンドを投入すると、ルータ内部で Named 管理エンジンが初期化されます [1, Task 1; 13, Lab 12]。
2. **Address-Family のバインド:**
   IPv4 または IPv6 のアドレスファミリーと AS 番号を指定した瞬間に、該当 AS の EIGRP ソケットおよび DUAL プロセスが動的に生成されます [1, Task 1; 8, Lab 11-5; 13, Lab 12]。
3. **AF-Interface による制御パラメーター適用:**
   `af-interface default` で全ポートをデフォルト `passive-interface` 化した上で、特定の `af-interface <int>` で `no passive-interface` や HMAC-SHA-256 認証、Hello/Hold タイマーをバインドします [13, Lab 2, Lab 12, Lab 13]。
4. **64-bit Wide Metrics による計算:**
   物理リンクの遅延（Latency: ピコ秒単位）と帯域幅（Throughput: Kbps 単位）を取得し、64 ビット計算式で Composite Metric を算出します [8, Lab 7-3]。対向が Classic Mode の場合は自動的にスケーリング変換して上位へ伝搬します [8, Lab 7-3]。

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、EIGRP Named Mode は基本設定課題だけでなく、トラブルシューティングや他技術（VRF-Lite, BFD, DMVPN, Route Leaking）との複合課題として 100% 登場します [22, 1.3.d]。

### 1. 階層モードの入力ミス・構文トラップ
* **よくあるミス 1: `network` コマンドを入れる場所**
  `network` コマンドは `topology base` モード配下ではなく、**`address-family ipv4 unicast autonomous-system <AS>` 直下のモード** で入力します [1, Task 1; 13, Lab 12]。
* **よくあるミス 2: `variance` や `redistribute` を入れる場所**
  `variance` や `redistribute`、`distribute-list` は **`topology base` モード配下** で入力する必要があります [13, Lab 5, Lab 12]。直下の AF モードで入れても拒否されます。
* **よくあるミス 3: `passive-interface` の配置**
  `passive-interface` や `hello-interval` は **`af-interface <interface|default>` モード配下** で入力します [13, Lab 2, Lab 12]。

### 2. Classic Mode から Named Mode への自動変換 (`router upgrade eigrp`)
試験問題で「すでに配置されている Classic EIGRP コンフィグを、設定パラメータを一切変更・欠落させることなく Named Mode にアップグレードせよ」と指示されることがあります。
* **解決コマンド:**
  ```bash
  router upgrade eigrp <Classic-AS> <NEW_NAME>
  ```
* **挙動:** 実行すると、既存の `ip hello-interval eigrp` や `ip authentication` などのインターフェイス設定が自動的に消去され、すべて Named Mode の `af-interface` や `topology base` に綺麗に再配置されます。

### 3. Key-Chain を使わない HMAC-SHA-256 認証のダイレクト指定
Named Mode では、`key chain` コマンドを組まなくても、`af-interface` 配下で直接パスワード文字列を指定して HMAC-SHA-256 認証を構成できます [13, Lab 13]。
```bash
af-interface GigabitEthernet1/0/1
 authentication mode hmac-sha-256 <PASSWORD>
```
※試験要件で「Key-Chain を作成せずに SHA-256 認証を設定せよ」と指定された場合にこのダイレクト構文が必須となります [13, Lab 13]。

---

## 🛠 設定方法

### 1. EIGRP Named Mode 完全構成例 (IPv4 / IPv6 / VRF 統合)

```bash
# 1. グローバル Named インスタンス作成
router eigrp CCIE_CORE
 !
 # 2. IPv4 グローバル VRF (AS 100)
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet1/0/1
   no passive-interface
   hello-interval 3
   hold-time 9
   authentication mode hmac-sha-256 CISCO_KEY_256
  exit-af-interface
  !
  topology base
   variance 2
   redistribute static
  exit-af-topology
  !
  network 10.1.12.0 0.0.0.255
  network 1.1.1.1 0.0.0.0
 exit-address-family
 !
 # 3. IPv6 グローバル (AS 200)
 address-family ipv6 unicast autonomous-system 200
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet1/0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
 exit-address-family
 !
 # 4. VRF TENANT_A 用 IPv4 (AS 300)
 address-family ipv4 unicast vrf TENANT_A autonomous-system 300
  af-interface GigabitEthernet1/0/2
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 192.168.10.0 0.0.0.255
 exit-address-family
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **Named Mode 全体のアドレスファミリー動作・AS・K値確認** | <code>show ip protocols</code> / <code>show eigrp address-family ipv4 protocols</code> |
| **Named Mode IPv4 ネイバーテーブル一覧の確認** | <code>show ip eigrp neighbors</code> / <code>show eigrp address-family ipv4 neighbors</code> |
| **Named Mode IPv6 ネイバーテーブル一覧の確認** | <code>show ipv6 eigrp neighbors</code> / <code>show eigrp address-family ipv6 neighbors</code> |
| **特定 VRF 配下の Named Mode ネイバー確認** | <code>show ip eigrp vrf TENANT_A neighbors</code> |
| **Topology Table の詳細監査 (64-bit Wide Metric 構成要素の確認)** | <code>show ip eigrp topology</code> / <code>show eigrp address-family ipv4 topology</code> |
| **AF-Interface ごとのアクティブ設定パラメータ一覧確認** | <code>show eigrp address-family ipv4 interfaces detail</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`network` コマンドが受け付けられない、またはエラーになる。** | `topology base` モード内で `network` を入力しようとしている。 | CLI 入力プロンプトの確認 | プロンプトが `(config-router-af)#`（AF直下）であることを確認して `network` を入力する [1, Task 1; 13, Lab 12]。 |
| **`variance` や `redistribute` が投入できない。** | `topology base` に移動せずに AF 直下でコマンドを入力しようとしている。 | CLI 入力プロンプトの確認 | `topology base` に遷移し、`(config-router-af-topology)#` プロンプト下で投入する [13, Lab 5, Lab 12]。 |
| **Classic Mode の対向ルータとメトリック計算結果が大幅に食い違う。** | Named Mode (Wide Metrics) と Classic Mode (32-bit Metric) 間で K 値やスケーリング計算の認識に差が生じている。 | `show ip protocols`<br>`show ip eigrp topology` | 必要に応じて Named Mode 側で `metric version 32-bit` を指定するか、インターフェイス Delay 値のチューニングを行う [8, Lab 7-3]。 |
| **IPv6 ネイバーが確立しない。** | インターフェイス上で `ipv6 enable` または IPv6 アドレスが未構成であり、Link-Local アドレス（`fe80::`）が存在しない。 | `show ipv6 interface brief` | 該当インターフェイスで `ipv6 enable` または IPv6 アドレスを構成し、Link-Local を生成させる [8, Lab 11-5]。 |

---

## ⚠ 制限事項

1. **Classic Mode との相互変換制限:**
   * `router upgrade eigrp` で Classic から Named に自動昇格させることは可能ですが、**Named Mode から Classic Mode への逆方向自動ダウングレードコマンドは存在しません。**
2. **Wide Metrics のスケーリング制限:**
   * Wide Metrics（64-bit）を維持できるのは Named Mode ルータ間のみです [8, Lab 7-3; 13, Lab 12]。途中に Classic Mode ルータが挟まると、自動的に 32-bit スケーリング（Scale Factor 128）へフォールバックされます [8, Lab 7-3]。

---

## 🔄 他技術との関連

* **VRF-Lite / MPLS L3VPN:**
  Named Mode では `address-family ipv4 unicast vrf <NAME> autonomous-system <AS>` により、同一の EIGRP インスタンス内で複数テナントの VRF ルーティングプロセスをすっきりと整理・運用できます [22, 1.2.e, 1.3.d]。
* **BFD (Bidirectional Forwarding Detection):**
  `af-interface` モード内で `bfd template <NAME>` または `bfd enable` を直接バインドできます [22, 1.2.j, 1.3.d]。
* **DMVPN / SD-WAN アンダーレイ:**
  `af-interface Tunnel0` 配下で `no split-horizon` や `summary-address` を直感的に構成できます [138, Task 1]。

---

## 🧩 比較表

### EIGRP Classic Mode vs EIGRP Named Mode

| 比較項目 | Classic Mode (`router eigrp 100`) | Named Mode (`router eigrp FABRIC`) |
| :--- | :--- | :--- |
| **構成単位** | AS 番号ごとに独立したプロセスを作成 | 任意の一意な名前（Instance Name）配下に統合 [1, Task 1; 13, Lab 12] |
| **IPv4 / IPv6 統合** | 不可 (IPv6 は `ipv6 router eigrp` で別定義) | 完全統合 (`address-family` で切り替え) [8, Lab 11-5; 13, Lab 12] |
| **VRF サポート** | 別途 `router eigrp <AS>` ＋ `vrf <NAME>` | `address-family ipv4 unicast vrf <NAME>` で統合 |
| **インターフェイス設定** | グローバル `interface Gi0/1` 配下に分散記述 | `af-interface Gi0/1` モード内に完全集約 [13, Lab 12] |
| **メトリック計算** | 32-bit Classic Metric (10G 以上で飽和) | 64-bit Wide Metrics (Throughput/Latency 基準) [8, Lab 7-3] |
| **HMAC-SHA-256 認証** | Key-Chain の事前作成が必須 | `af-interface` 内で直接パスワード指定可能 [13, Lab 13] |

---

## 💡 ベストプラクティス

1. **新規構築時の 100% Named Mode 採用:**
   Cisco IOS-XE (Catalyst 9000 等) では Classic Mode を破棄し、Named Mode を標準プロトコル構成として採用する [1, Task 1; 8, Lab 7-3; 13, Lab 12; 14, Task 1]。
2. **`af-interface default` による Defensive 設計:**
   `af-interface default` モードで全ポートをデフォルト `passive-interface` に落とし、必要な対向ポートのみ `no passive-interface` で開放する [13, Lab 2, Lab 12]。
3. **SHA-256 直接認証の活用:**
   Key-Chain 管理の複雑さを回避するため、試験要件に反しない限り `af-interface` 直下での HMAC-SHA-256 ダイレクト認証を活用する [13, Lab 13]。

---

## 📝 ラボ学習・設定サンプル例

以下は、CCIE EI ラボ試験レベルに対応する省略なしの 10 個の演習シナリオです。

### Scenario 1: EIGRP Named Mode 基本構成 (IPv4 AS 100)
* **要件:** R1 (Gi0/1: 10.1.12.1/24) と R2 (Gi0/1: 10.1.12.2/24) 間で、プロセス名 `GLOBAL_EIGRP`、AS 100 の Named Mode を構成せよ [1, Task 1; 13, Lab 12; 14, Task 1]。

**【R1】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

**【R2】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 10.1.12.0 0.0.0.255
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors
# Gi0/1 上で R2 (10.1.12.2) とのネイバーが成立していることを確認
```

---

### Scenario 2: EIGRPv6 (IPv6) Named Mode 設定
* **要件:** R1-R2 間の Gi0/1 (`2001:db8:12::/64`) で Named Mode の IPv6 AS 200 を有効化せよ [8, Lab 11-5; 13, Lab 12]。

**【R1】**
```bash
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::1/64
!
router eigrp GLOBAL_EIGRP
 !
 address-family ipv6 unicast autonomous-system 200
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
 exit-address-family
```

**【R2】**
```bash
interface GigabitEthernet0/1
 ipv6 enable
 ipv6 address 2001:db8:12::2/64
!
router eigrp GLOBAL_EIGRP
 !
 address-family ipv6 unicast autonomous-system 200
  af-interface default
   passive-interface
  exit-af-interface
  !
  af-interface GigabitEthernet0/1
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
 exit-address-family
```

**【検証方法】**
```bash
R1# show ipv6 eigrp neighbors
```

---

### Scenario 3: HMAC-SHA-256 ダイレクト認証 (Key-Chain なし)
* **要件:** R1-R2 間の Gi0/1 で、Key-Chain を作成せずに直接パスワード `CCIE_SECRET` を使用して HMAC-SHA-256 認証を設定せよ [13, Lab 13]。

**【R1 / R2 共通】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   authentication mode hmac-sha-256 CCIE_SECRET
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp neighbors
# アジャセンシーが正常に維持されていることを確認
```

---

### Scenario 4: VRF-Aware EIGRP Named Mode (Multi-Tenant)
* **要件:** VRF `BLUE` (AS 300) 配下の Gi0/2 (192.168.20.0/24) で EIGRP Named Mode を構成せよ [22, 1.2.e, 1.3.d]。

**【R1】**
```bash
vrf definition BLUE
 rd 300:1
 address-family ipv4
exit-vrf
!
interface GigabitEthernet0/2
 vrf forwarding BLUE
 ip address 192.168.20.1 255.255.255.0
!
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast vrf BLUE autonomous-system 300
  af-interface GigabitEthernet0/2
   no passive-interface
  exit-af-interface
  !
  topology base
  exit-af-topology
  !
  network 192.168.20.0 0.0.0.255
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip eigrp vrf BLUE neighbors
```

---

### Scenario 5: Classic Mode から Named Mode への自動アップグレード
* **要件:** 既存の Classic モード配置 `router eigrp 100` を、設定要件を保持したまま `UPLOADED_EIGRP` という Named インスタンスへワンラインで変更せよ。

**【実行コマンド】**
```bash
R1# configure terminal
R1(config)# router upgrade eigrp 100 UPLOADED_EIGRP
# 確認ダイアログで 'yes' を入力
```

**【検証方法】**
```bash
R1# show running-config | section router eigrp
# 以前の Classic 設定が消去され、`router eigrp UPLOADED_EIGRP` へ綺麗に変換されていることを確認
```

---

### Scenario 6: AF-Interface 配下での BFD 統合
* **要件:** Gi0/1 上の EIGRP Named Mode セッションに対して Single-hop BFD をバインドせよ [22, 1.2.j, 1.3.d]。

**【R1 / R2 共通】**
```bash
bfd-template single-hop BFD_FAST
 interval min-tx 50 min-rx 50 multiplier 3
!
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   bfd template BFD_FAST
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show bfd neighbors client eigrp
```

---

### Scenario 7: Topology Mode 配下での Variance (不等コストロードバランシング)
* **要件:** 目的網へのバックアップパスを有効化するため、`topology base` モードで `variance 2` を設定せよ [13, Lab 5; 113, Video Title: EIGRP Equal Cost Load Sharing]。

**【R1】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  topology base
   variance 2
  exit-af-topology
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip route eigrp
# 定義した要件を満たす複数パスが RIB に同時に掲載されていることを確認
```

---

### Scenario 8: 手動ルートサマリー (Summary-Address) の設定
* **要件:** Gi0/1 から送出される EIGRP 経路を `10.1.0.0/16` に集約し、かつ集約ルートの AD 値をデフォルトの 5 から `20` に変更せよ [8, Lab 7-4; 13, Lab 7; 110, Video Title: EIGRP Summarization (Classic)]。

**【R1】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface GigabitEthernet0/1
   summary-address 10.1.0.0 255.255.0.0 20
  exit-af-interface
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip route 10.1.0.0 255.255.0.0
# Null0 ルートの Distance が 20 になっていることを確認
```

---

### Scenario 9: Named Mode での Classic 32-bit Metric 動作への固定
* **要件:** 試験上の制約により、Named Mode を維持しつつ、メトリック計算を従来の Classic 32-bit メトリックモードに強制変更せよ [8, Lab 7-3]。

**【R1】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  metric version 32-bit
 exit-address-family
```

**【検証方法】**
```bash
R1# show ip protocols
# Metric version が 32-bit に固定されていることを確認
```

---

### Scenario 10: AF-Interface 配下での Split-Horizon 無効化 (DMVPN Hub)
* **要件:** DMVPN Hub ルータの Tunnel0 において、スプリットホライズンを無効化せよ [138, Task 1]。

**【R1 (Hub)】**
```bash
router eigrp GLOBAL_EIGRP
 !
 address-family ipv4 unicast autonomous-system 100
  af-interface Tunnel0
   no split-horizon
  exit-af-interface
  !
  network 172.16.1.0 0.0.0.255
 exit-address-family
```

**【検証方法】**
```bash
R1# show eigrp address-family ipv4 interfaces detail Tunnel0
# Split-horizon is disabled を確認
```

---

## ❓ 想定試験問題

### 1. 【コンフィグ読解】Named Mode 設定の投入場所ミス
**問題:** 
以下のコンフィグを投入しようとしましたが、ルータから構文エラーが返去されました。どの部分が間違っているか指摘し、正しいコンフィグへ修正してください。
```text
router eigrp FABRIC
 address-family ipv4 unicast autonomous-system 100
  network 10.1.1.0 0.0.0.255
  variance 3
  passive-interface GigabitEthernet0/1
 exit-address-family
```

**解答・解説:**
* **問題点:** 
  1. `variance` コマンドは AF 直下ではなく `topology base` モード配下で入力する必要があります [13, Lab 5, Lab 12]。
  2. `passive-interface` コマンドは AF 直下ではなく `af-interface GigabitEthernet0/1` モード配下で入力する必要があります [13, Lab 2, Lab 12]。
* **正しい修正設定:**
  ```text
  router eigrp FABRIC
   address-family ipv4 unicast autonomous-system 100
    af-interface GigabitEthernet0/1
     passive-interface
    exit-af-interface
    !
    topology base
     variance 3
    exit-af-topology
    !
    network 10.1.1.0 0.0.0.255
   exit-address-family
  ```

### 2. 【Design / トラブルシューティング】Classic から Named へのアップグレード影響
**問題:** 
運用中のコアスイッチにおいて `router upgrade eigrp 100 SWITCH_EIGRP` を実行しました。この操作により、対向の Classic Mode ルータとの間で EIGRP ネイバー断（トラフィック障害）が発生する可能性はあるでしょうか？技術的根拠とともに述べてください。

**解答・解説:**
* **回答:** **原則としてネイバー断は発生しません。**
* **技術的根拠:** 
  `router upgrade eigrp` コマンドは、自ルータ内部のコンフィグ構造を Classic 形式から Named 形式へ変換するローカル処理です。自動変換後も K 値（デフォルト `K1=1, K3=1`）や AS 番号、IP アドレス、認証情報、タイマー値はそのまま維持されます。
  また、Named Mode 側で算出された 64-bit Wide Metrics は、Classic Mode 側へアドバタイズされる際に自動的に 128 で除算されてスケーリングされるため、対向が Classic Mode のままであってもアジャセンシーは維持されます。

---


## 🔗 参考リソース

* [Cisco Systems: EIGRP Named Mode Configuration Guide, Cisco IOS XE Release 3S](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-3s/ire-xe-3s-book.html)
* [Cisco Command Reference: EIGRP Commands (Named Mode)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/command/ire-cr-book.html)
* [Cisco Live: BRKRST-2336 - Advanced EIGRP Deployment and Troubleshooting](https://www.ciscolive.com/global/on-demand-library.html)

---

## 📝 補足（Notes）

* **Named Mode 設定の階層構造プロンプト:**
  * Global: `(config-router)#`
  * Address-Family: `(config-router-af)#`
  * AF-Interface: `(config-router-af-interface)#`
  * Topology Base: `(config-router-af-topology)#`


---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide - Named Mode (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book/ire-named-config.html)
*   [EIGRP Wide Metrics White Paper (Technical Note)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/118847-tech-note-eigrp-00.html)

### CiscoLive (動画・スライド)
*   [Introduction to EIGRP - BRKENT-1187](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/BRKENT-1187.pdf) - EIGRPの基礎と概要を解説。
*   [EIGRP Operations: The Usual Suspects - BRKENT-2050](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/BRKENT-2050.pdf) - EIGRPの動作原理やトラブルシューティングを解説。

*   
### テクニカルドキュメント・設定例
*   [EIGRP Named Mode Configuration Example (Cisco Support)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/200156-Configure-EIGRP-Named-Mode.html)。
*   [Understanding EIGRP SHA-256 Authentication](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/15-mt/ire-15-mt-book/ire-sha256.html)。

---

## 📝 補足
- この学習メモは、EIGRP Named Modeが単なる「設定形式の変更」ではなく、高速ネットワークにおける「メトリック精度の向上」と「管理の統合」を目的とした進化であることを強調しています。CCIE実技試験では、この階層構造を正確に使い分けることで、効率的かつミスのない設定を行うことが合格への鍵となります。


