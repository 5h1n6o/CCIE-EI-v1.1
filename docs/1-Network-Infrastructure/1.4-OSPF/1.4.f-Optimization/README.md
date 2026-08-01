---
layout: default
title: 1.4.f-Optimization
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 6
---

# 1.4.f OSPF Optimization, Convergence, and Scalability

CCIE Enterprise Infrastructure (EI) v1.1の実技試験に向けて、Blueprint項目「1.4 OSPF (v2 and v3)」における最適化、コンバージェンス、およびスケーラビリティの技術詳細をまとめました。本稿ではメトリックの微調整、高速コンバージェンスのためのタイマー設定、LSDB（リンクステートデータベース）の軽量化手法など、大規模ネットワークでの運用に不可欠な高度なトピックを網羅します。

---

## 📘 概要

OSPF（Open Shortest Path First）の最適化、コンバージェンス、およびスケーラビリティは、単にエリアを分割するだけにとどまりません。ネットワークの規模が拡大し、冗長パスが増えるにつれて、OSPFルータはより多くのLSA（リンクステート広告）を処理し、頻繁なSPF（最短パス優先）計算を行う必要が出てきます。

最適化の目的は、コントロールプレーン（ルーティングエンジンの負荷）とデータプレーン（トラフィックの転送効率）の両面で最高の結果を得ることです。具体的には、メトリック操作による精密なトラフィック誘導、LSAやSPFの実行タイミングを制御するスロットリング、メンテナンス時のパケットロスを最小限に抑えるStubルータ機能、そしてトポロジ情報から不要なサブネット情報を除外してデータベースを軽量化するプレフィックス抑制などが含まれます。これらの機能を組み合わせることで、ミリ秒単位の障害復旧（コンバージェンス）と、数千台規模のデバイスを収容できる拡張性の両立を目指します。

---

## 🔑 要点

### 1. Metrics (メトリックの最適化)

OSPFは「10^8 / 帯域幅(bps)」という計算式でコストを算出します。
*   **Reference Bandwidthの問題:** デフォルトの基準帯域（100Mbps）では、1Gbps、10Gbps、100Gbpsのリンクがすべて「コスト1」となり、パスの優劣を判別できなくなります。
*   **正規化の必要性:** ネットワーク内の全ルータで `auto-cost reference-bandwidth` を統一設定し、高速リンクの差を反映させる必要があります。

### 2. LSA Throttling と SPF Tuning

コンバージェンスを高速化しつつ、フラッピング（不安定なリンク）によるCPU負荷を抑えるための指数バックオフタイマーです。
*   **LSA Throttling:** LSAの生成・送信間隔を動的に調整します。
*   **SPF Tuning:** トポロジ変化を検知してからSPF計算を開始するまでの待ち時間を調整します。
*   **Incremental SPF (ISPF):** トポロジの一部が変化した際に、全計算ではなく影響範囲のみを再計算して効率化します。

### 3. Stub Router (Max-Metric Router LSA)

自身のルータを一時的に「中継（Transit）不可」の状態にする機能です。
*   **動作原理:** ネイバーに広告するRouter LSA（Type 1）の非末端リンクコストを最大値（65535）に設定します。
*   **用途:** BGPとの同期完了を待つ間や、ハードウェアのメンテナンス前に、自身のルータを通るトラフィックを事前に回避させたい場合に使用します。

### 4. Prefix Suppression

ルータ間の接続用サブネット（トランジットリンク）情報をLSAから除外する技術です。
*   **メリット:** ルーティングテーブル（RIB）とLSDBのサイズを劇的に削減し、SPF計算の高速化とメモリ節約を実現します。
*   **実装:** エンドポイント（Loopbackなど）以外の情報は、フォワーディング（転送）には必要ですが、個別のプレフィックスとして他者に教える必要がない場合に適用します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE EIラボ試験では、OSPFの挙動をミリ秒単位で制御したり、制約条件下での最適化を求められたりします。

### 1. 高速コンバージェンスの「設計意図」

単にタイマーを最短にするのではなく、安定性とのトレードオフが問われます。
*   **戦略:** 障害検知にはBFD（Bidirectional Forwarding Detection）を併用し、OSPFのSPFタイマーは指数バックオフ（例：`start 50ms, hold 200ms, max 5000ms`）を設定して、一度の障害には即応し、連続するフラッピングには慎重に対応する構成が推奨されます。

### 2. Stub Router の条件付き設定

「ルータが再起動した後、BGPがコンバージェンスするまで5分間だけStubとして動作せよ」といった動的な要件。
*   `max-metric router-lsa on-startup [seconds]` コマンドの正確な使用法と、BGPとの連携を理解する必要があります。

### 3. OSPFv3 でのアドレスファミリー最適化

OSPFv3はIPv4とIPv6の両方を単一プロセスで扱えます（Address Family mode）。
*   **ラボの罠:** IPv4 AFとIPv6 AFで異なるコスト調整やタイマー設定を求められることがあります。各AFサブモード内での設定箇所の区別が重要です。

### 4. データベース保護

LSAの増大によるメモリ枯渇を防ぐため、受信するLSA数に制限をかけるタスク。
*   `max-lsa [limit]` コマンドを使用しますが、制限超過時にプロセスを落とすのか（default）、警告のみにするのか（warning-only）の指定を正確に行う必要があります。

---

## 🛠 設定・検証コマンド

### 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **基準帯域幅の変更 (100G基準)** | <code>(config-router)# auto-cost reference-bandwidth 100000</code> |
| **SPF計算間隔の調整** | <code>(config-router)# timers throttle spf [start] [hold] [max]</code> |
| **LSA生成間隔の調整** | <code>(config-router)# timers throttle lsa [start] [hold] [max]</code> |
| **LSA受信間隔の調整** | <code>(config-router)# timers lsa-arrival [milliseconds]</code> |
| **メンテナンス時のStub化** | <code>(config-router)# max-metric router-lsa</code> |
| **起動時の期間限定Stub化** | <code>(config-router)# max-metric router-lsa on-startup [seconds]</code> |
| **BGP同期を待つStub化** | <code>(config-router)# max-metric router-lsa wait-for-bgp</code> |
| **グローバルプレフィックス抑制** | <code>(config-router)# prefix-suppression</code> |
| **インターフェイス単位の抑制** | <code>(config-if)# ip ospf prefix-suppression</code> |
| **LSA受信数の制限** | <code>(config-router)# max-lsa [number] [warning-only]</code> |

### 検証・デバッグコマンド

| 目的 | コマンド |
| :--- | :--- |
| **OSPF全般の最適化状況確認** | <code>show ip ospf</code> |
| **基準帯域幅の設定確認** | <code>show ip ospf &#124; include Reference</code> |
| **SPF/LSAタイマーの統計確認** | <code>show ip ospf statistics [detail]</code> |
| **現在のメトリック値の確認** | <code>show ip route ospf</code> |
| **Stub状態（最大コスト）の確認** | <code>show ip ospf database router self-originate</code> |
| **プレフィックス抑制の確認** | <code>show ip ospf interface [ID]</code> |
| **OSPFv3 AF別のコスト確認** | <code>show ospfv3 interface</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIE EIの試験要件に準拠した、OSPF最適化の12個の実装シナリオです。

### 1. 高速インターフェイス（10Gbps/40Gbps）の差別化

**【問題内容】**
ネットワーク内に 10Gbps と 40Gbps のリンクが存在する。OSPFがこれらの速度差を認識し、適切なコストを算出できるようにせよ。100Gbpsをコスト1の基準とすること。

**【設定サンプル】**
```ios
router ospf 1
 ! 100Gbps = 100,000 Mbps
 auto-cost reference-bandwidth 100000
!
! 検証：10Gはコスト10、40Gはコスト2（切り上げ）程度になることを確認
```


---

### 2. ミリ秒単位の SPF コンバージェンス設定

**【問題内容】**
トポロジ変化に対し、最初のSPF計算は 50ms で開始し、変化が続く場合は 200ms、最大 5秒まで指数関数的に待ち時間を増やすようにせよ。

**【設定サンプル】**
```ios
router ospf 1
 timers throttle spf 50 200 5000
```


---

### 3. LSA 生成と伝播の最適化

**【問題内容】**
自身のルータでリンクが変化した際、最初のLSA生成を 0ms（即時）とし、以降は 5秒まで抑制せよ。また、ネイバーからのLSA受信間隔は 1秒以上に制限せよ。

**【設定サンプル】**
```ios
router ospf 1
 timers throttle lsa 0 5000 5000
 timers lsa-arrival 1000
```


---

### 4. メンテナンス前の Graceful 退出 (Stub Router)

**【問題内容】**
R1 のハードウェア交換を予定している。R1 を経由するトラフィックを事前に他のパスへ迂回させるため、OSPF メトリックを全トランジットリンクで最大値にして広告せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! 自身のRouter LSAのコストを最大にして広告
 max-metric router-lsa
```


---

### 5. 再起動後の BGP コンバージェンス保護

**【問題内容】**
ルータ起動後、OSPFが完全に復旧してもBGPテーブルが空のままだとパケットドロップが発生する。BGPが完全に同期されるまで、または起動後 10分間は OSPF 側で Stub として振る舞い、他ルータからのトラフィック流入を防げ。

**【設定サンプル】**
```ios
router ospf 1
 max-metric router-lsa on-startup 600
 max-metric router-lsa wait-for-bgp
```


---

### 6. トランジットプレフィックス抑制による LSDB 軽量化

**【問題内容】**
ルータ間の物理接続セグメントのプレフィックス（/30 や /31）を LSDB から除外し、Loopback などの重要なプレフィックスのみをルーティングテーブルに載せるように全ルータを最適化せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! プロセス全体でトランジットプレフィックスのLSA広報を停止
 prefix-suppression
```


---

### 7. OSPFv3 アドレスファミリーにおけるコスト操作

**【問題内容】**
OSPFv3 AF モードにおいて、IPv6 ユニキャストトラフィックのみ、特定の低速リンク（Gi0/1）のコストを 5000 に手動設定せよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ospfv3 1 ipv6 cost 5000
```


---

### 8. LSA データベースの最大数制限

**【問題内容】**
R9 において、自身の LSDB が保持する LSA（自身が生成したもの以外）の数を 1000 個に制限せよ。上限に達した際は隣接関係を切断せず、警告ログのみ出力せよ。

**【設定サンプル】**
```ios
router ospf 1
 max-lsa 1000 warning-only
```


---

### 9. ISPF (Incremental SPF) の有効化

**【問題内容】**
トポロジの部分的な変更に対し、全計算を避けて計算負荷を軽減するため、インクリメンタル SPF を有効にせよ。

**【設定サンプル】**
```ios
router ospf 1
 ispf
```


---

### 10. インターフェイス単位でのプレフィックス抑制例外

**【問題内容】**
グローバルで `prefix-suppression` を有効にしているが、管理セグメントに接続された GigabitEthernet 0/2 だけは例外として、そのサブネット情報を OSPF 内で広報させよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/2
 ! グローバルの抑制設定をこのインターフェイスだけ上書きして無効化
 no ip ospf prefix-suppression
```


---

### 11. BFDC (BFD for Convergence) の統合

**【問題内容】**
隣接ルータとの障害検知を 150ms 以内に行い、OSPF に即座に通知するように構成せよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 bfd interval 50 min_rx 50 multiplier 3
!
router ospf 1
 bfd all-interfaces
```


---

### 12. MTU 不一致の強制無視によるコンバージェンス回復

**【問題内容】**
（トラブルシューティングシナリオ）物理的な MTU 設定ミスにより OSPF ネイバーが `EXSTART` で止まっている。物理設定を変更できない制約がある場合、OSPF 側でこのチェックをスキップさせよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ! データベース同期時のMTUチェックを無視する
 ip ospf mtu-ignore
```


---

## 参考リソースリンク

### CiscoLive (動画・スライド)
*   **BRKENS-2337: OSPF Deployment in Modern Networks** - モダンなネットワークでのOSPF設計と、Prefix Suppression、LSA Throttlingの深掘り。
*   **BRKRST-3320: Troubleshooting Routing Protocols** - OSPFのコンバージェンス問題（MTUミスマッチ、タイマー不整合等）のトラブルシューティング手法。
*   **BRKCCIE-3000: OSPF for the CCIE Candidates** - LSDBの最適化と高速切替のメカニズム解説。

### Configurationガイド
*   [OSPFv2 Configuration Guide: Optimization and Scalability (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html) - 公式の最適化設定ガイド。
*   [OSPFv3 Address Family Support Configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html) - IPv4/IPv6統合環境の構成ガイド。

### テクニカルドキュメント・設定例
*   [OSPF Cost Calculation and Reference Bandwidth](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/7039-1.html#anc18) - コスト計算の技術詳細。
*   [Introduction to OSPF LSA Throttling and SPF Tuning](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13697-14.html) - タイマー調整のベストプラクティス。
*   [Understanding the OSPF Stub Router Advertisement Feature](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/47870-ospfdb11.html) - Stubルータ機能の詳細解説。

---

## 📝 補足
- この学習メモは、OSPFの「守り（安定性）」と「攻め（高速性）」のバランスをいかに取るかというCCIEレベルの難題に対する解答を網羅しています。特に `max-metric router-lsa` や `prefix-suppression` は、実際のラボ試験で複雑な要件を満たすための「決め手」となることが多いため、実機での LSA 挙動確認を欠かさないようにしてください。


