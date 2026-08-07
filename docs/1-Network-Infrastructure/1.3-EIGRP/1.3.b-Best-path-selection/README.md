---
layout: default
title: 1.3.b-Best-path-selection
parent: 1.3-EIGRP
grand_parent: 1-Network-Infrastructure
nav_order: 2
---

# 1.3.b EIGRP Best Path Selection

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.3 EIGRP」における、パス選定のメカニズム、ディスタンスの概念、およびメトリック計算（Classic vs Wide）について整理しました。

---

## 📘 概要

EIGRP（Enhanced Interior Gateway Routing Protocol）は、シスコ独自のDUAL（Diffusing Update Algorithm）アルゴリズムを採用した拡張ディスタンスベクトル型ルーティングプロトコルです。EIGRPは「信頼性のあるマルチキャスト」を使用してネイバー間でトポロジ情報を交換し、ループのない最短パスを高速に算出します。

EIGRPの最大の特徴は、最適パス（Successor）だけでなく、ループフリーが保証されたバックアップパス（Feasible Successor）を保持できる点にあります。これにより、メインリンクの障害時に数ミリ秒での高速コンバージェンスが可能となります。また、メトリック計算に帯域幅や遅延などの複数の要素を組み合わせることができ、複雑なトラフィックエンジニアリングを柔軟に実装できます。CCIEレベルでは、従来のClassic Metricsと、1Gbpsを超える高速リンクに対応したWide Metricsの数学的差異を正確に理解し、制御する能力が問われます。

---

## 🔑 要点

### 1. パス選定に関わるディスタンスの定義

EIGRPのパス選定プロセスを理解するには、トポロジテーブルに格納される複数の「距離（Distance）」の概念を区別する必要があります。

*   **Reported Distance (RD) / Advertised Distance (AD):** ネイバー（隣接ルータ）から広告された、そのネイバーから宛先ネットワークまでのメトリック値です。ルータはこれを「自分より先の距離」として扱います。
*   **Computed Distance (CD):** ネイバーから報告されたRDに、そのネイバーに到達するためのローカルコスト（自身のインターフェイスのメトリック）を加算した値です。
*   **Feasible Distance (FD):** ルーティングテーブル（RIB）にインストールされている「Successor（最適パス）」の現時点での最小Computed Distanceです。これはルータにとっての「宛先までの最短距離のレコード」となります。

### 2. Successor と Feasible Successor (FS)

EIGRPはDUALの計算結果に基づき、以下の役割を定義します。

*   **Successor:** 宛先ネットワークまでのComputed Distanceが最小となる次ホップルータです。この経路がルーティングテーブル（RIB）に登録されます。
*   **Feasible Successor (FS):** Successorに次ぐバックアップパスのうち、**「Feasibility Condition（成立条件）」**を満たす次ホップルータです。FSはトポロジテーブルには保持されますが、通常はRIBには登録されません。
*   **Feasibility Condition (FC):** 「対象パスの **Reported Distance (RD)** が、現在の **Feasible Distance (FD)** よりも小さいこと（RD < FD）」が条件です。この条件を満たすことで、そのネイバーが自身を経由してループしていないことが数学的に保証されます。

### 3. Classic Metrics (256-bit scale)

従来のEIGRPメトリック計算式です。帯域幅（BW）と遅延（Delay）を主要なK値として計算し、最後に256を乗じてスケーリングします。

*   **デフォルト公式:** `Metric = [ (10^7 / 最小帯域幅kbps) + 合計遅延/10 ] * 256`。
*   **K値 (K-values):** K1（帯域幅）とK3（遅延）がデフォルトで `1` に設定され、他は `0` です。

### 4. Wide Metrics (64-bit scale)

Named Mode（名前付きモード）で導入された新しいメトリック計算方式です。1Gbpsを超えるインターフェイスに対応するため、64ビット精度の数値を使用し、遅延の単位をピコ秒（10^-12）に変更しています。

*   **公式:** `Wide Metric = [ (K1 * 10^7 * 65536 / Throughput) + (K3 * 遅延ピコ秒 * 65536 / 10^6) ]` のような高精度な計算が行われます。
*   **rib-scale:** Wide Metricの大規模な数値をRIBに適合させるため、`metric rib-scale` コマンドで値を圧縮してルーティングテーブルに渡します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、EIGRPのパス選定を意図的に操作させたり、不整合を解決させたりするタスクが頻出します。

### 1. メトリック操作によるトラフィック誘導

特定のパスを優先させる際、`bandwidth` ではなく **`delay`** を変更するのがベストプラクティスです。帯域幅の変更はQoSや他の機能に影響を与える可能性がある一方、遅延は累積的な値であるため、微調整に適しています。
*   **注意:** ラボの制約で「Named Modeを使用し、特定のインターフェイスのみメトリックを変更せよ」とある場合、`af-interface` モード内で `delay` を指定します。

### 2. Unequal Cost Load Balancing (UCLB) の構成

EIGRPは、メトリックが一致しない複数のパスを同時にRIBへインストールできる唯一のIGPです。
*   **条件:** バックアップパスが **Feasible Successor (FS)** である必要があります。
*   **実装:** `variance [倍率]` コマンドを使用します。例えば `variance 2` と設定すれば、SuccessorのFDの2倍以内のコストを持つFSがすべてRIBに登録されます。
*   **トラブル:** 「`variance` を設定したのにパスが増えない」場合、そのパスが **Feasibility Condition（RD < FD）** を満たしていない（＝FSではない）ことが原因です。この場合、RDを下げるか、Successor側のFDを上げる調整が求められます。

### 3. Wide Metrics と Classic Metrics の混在

ClassicルータとNamed Modeルータが混在する場合、Named Mode側は自動的に64ビットのWide Metricsを32ビットのClassic形式に変換して対向に伝えます。
*   **注意:** 高速インターフェイス（10Gbps以上）が多数ある環境では、Classicメトリックの数値が飽和（Maximum値で固定）してしまい、適切なパス選定ができなくなる「メトリックの平坦化」問題が発生することがあります。これを防ぐためにNamed Modeへの統一が推奨されます。

### 4. トポロジテーブルの完全な理解

検証コマンド `show ip eigrp topology` では、FSのみが表示されます。全ての候補パスを確認するには **`all-links`** キーワードが必要です。試験中に「候補パスはあるはずなのにリストにない」と感じたら、まず `all-links` でFCを満たしていないパスを探すことが定石です。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **メトリックの重み付け変更(K値)** | <code>(config-router)# metric weights 0 [K1] [K2] [K3] [K4] [K5]</code> |
| **不等コスト負荷分散の設定** | <code>(config-router)# variance</code> |
| **RIBスケール調整 (Wide Metric時)** | <code>(config-router-af-topology)# metric rib-scale</code> |
| **インターフェイス遅延の設定** | <code>(config-if)# delay [tens of microsec]</code> |
| **最適・バックアップパスの確認** | <code>show ip eigrp topology</code> |
| **全候補リンク(FS以外も含む)表示** | <code>show ip eigrp topology all-links</code> |
| **Wide Metric詳細情報の確認** | <code>show ip eigrp topology [prefix]</code> |
| **現在のK値とAS情報の確認** | <code>show ip protocols</code> |
| **RIBへの登録状況確認** | <code>show ip route eigrp</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. メトリック調整による「Feasible Successor」の意図的創出

**【問題内容】**
R1はR2(Successor, FD=100)とR3(候補)の2つのパスを持っている。R3側のパスは RD=110, CD=150 であるため、RD(110) > FD(100) となり、FCを満たさずFSになれない。R3をFSにするために、R1のSuccessor側のパスのメトリックを調整せよ。

**【設定サンプル】**
```ios
! 現在の状況確認
R1# show ip eigrp topology 10.1.1.0/24
! P 10.1.1.0/24, 1 successors, FD is 100
! via 10.1.12.2 (100/50), GigabitEthernet0/1 (Successor)
!
R1# show ip eigrp topology all-links
! ...
! via 10.1.13.3 (150/110), GigabitEthernet0/2 (Not an FS because 110 > 100)

! 対策：Successor側のインターフェイス遅延を増やし、FDを110より大きくする
R1(config)# interface GigabitEthernet0/1
R1(config-if)# delay 1000

! 再確認：R3がFSになったことを確認
R1# show ip eigrp topology
! P 10.1.1.0/24, 1 successors, FD is 266240 (スケーリング後の値)
! via 10.1.12.2 (266240/128000)
! via 10.1.13.3 (384000/281600)  <-- FSとして浮上
```

---

### 2. Variance を用いた不等コスト負荷分散の実装

**【問題内容】**
R3において、シリアル接続(S4/0)とイーサネット接続(E0/0)の両方を使用して、R6へのトラフィックを負荷分散せよ。ただし、シリアル接続のメトリックはイーサネットの約80倍高い。ソース133に基づき、適切な倍率を設定せよ。

**【設定サンプル】**
```ios
router eigrp 33
 ! FSである限り、メトリックの差を許容する最大倍率を指定
 ! 今回は100倍まで許容する設計とする
 variance 100
!
! 検証
R3# show ip route 10.1.6.0
! D 10.1.6.0/24 [90/2195456] via 10.1.36.6, Ethernet0/0
!               [90/27417600] via 10.1.34.6, Serial4/0  <-- 両方がRIBに載る
```

---

### 3. Named Mode における Wide Metrics の詳細確認

**【問題内容】**
Named Mode インスタンス「CCIE_FABRIC」において、64ビットメトリックがどのように算出されているか、および `rib-scale` の影響を確認せよ。

**【設定サンプル】**
```ios
router eigrp CCIE_FABRIC
 address-family ipv4 unicast autonomous-system 100
  topology base
   ! RIBに渡す際、Wideメトリック値を128で割って適合させる(デフォルトは128)
   metric rib-scale 128
  exit-af-topology
```
**【検証】**
```ios
R1# show ip eigrp topology 172.16.1.0/24
! ...
! Composite metric is (10486497280/10485841920) <-- 非常に大きなWide値が表示される
! Vector metric:
!   Minimum bandwidth is 10000000 Kbit
!   Total delay is 60000000000 picoseconds <-- ピコ秒単位
! ...
```

---

### 4. 帯域幅の制限（Bandwidth Pacing）

**【問題内容】**
低速な WAN リンクにおいて、EIGRP パケットがリンク帯域を占有しすぎないよう、使用率を 20% に制限せよ。

**【設定サンプル】**
```ios
interface Serial0/0
 ! インターフェイスに設定された bandwidth 値の20%までに制限
 ip bandwidth-percent eigrp 100 20
```

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: EIGRP Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_eigrp/configuration/xe-17/ire-xe-17-book.html)
*   [EIGRP Wide Metrics (White Paper)](https://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/118847-tech-note-eigrp-00.html)

### CiscoLive (動画・スライド)
*   [Introduction to EIGRP - BRKENT-1187](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2024/pdf/BRKENT-1187.pdf) - EIGRPの基礎と概要を解説
*   [EIGRP Operations: The Usual Suspects - BRKENT-2050](https://www.ciscolive.com/c/dam/r/ciscolive/global-event/docs/2025/pdf/BRKENT-2050.pdf) - EIGRPの動作原理やトラブルシューティングを解説。

### テクニカルドキュメント・設定例
*   [Introduction to EIGRP Metrics](http://www.cisco.com/c/en/us/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/16406-eigrp-metrics.html)
*   [EIGRP Variance and Unequal Cost Load Balancing](https://www.cisco.com/c/ja_jp/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)

---

## 📝 補足
- この学習メモは、EIGRPの単なる設定ではなく、「なぜそのパスが選ばれるのか、あるいは選ばれないのか」というDUALの論理的根拠を理解することに重点を置いています。特に Feasibility Condition (RD < FD) の数学的理解は、トラブルシューティングセクションにおける UCLB や高速コンバージェンスの課題を解決するための必須知識です。


