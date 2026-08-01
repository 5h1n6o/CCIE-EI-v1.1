---
layout: default
title: 1.4.d-Path-preference
parent: 1.4-OSPF
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.4.d OSPF Path Preference

CCIE Enterprise Infrastructure (EI) v1.1 の Blueprint 項目「1.4 OSPF (v2 and v3)」における「1.4.d Path preference（パス選定の優先順位）」について整理しました。

---

## 📘 概要

OSPF（Open Shortest Path First）における **Path Preference（パス選定）** は、単なるメトリック（コスト）の比較だけではありません。OSPF は階層型プロトコルであり、リンクステートデータベース（LSDB）の情報を元に、まず「ルートの種類」に基づいた厳格な優先順位を適用し、その後にコスト比較を行います。

CCIE レベルでは、OSPF ルートの優先順位（Intra-area vs. Inter-area vs. External）、LSA タイプごとのコスト計算方法（E1 vs. E2）、および **Reference Bandwidth** の不一致によるサブオプティマルルーティングの解決が問われます。また、IPv6 環境における OSPFv3 のパス選定ロジックも IPv4 と同様に重要です。これらのルールを理解していないと、メトリックをいくら操作しても意図したパスを選択させることができない「論理的な罠」に陥ります。

---

## 🔑 要点

### 1. OSPF ルートタイプの優先順位

OSPF は、コストを比較する前に、以下のルートタイプに基づいた優先順位を適用します。上位のルートタイプが優先され、コストがいくら低くても下位のタイプが選ばれることはありません。

| 優先順位 | ルートタイプ | 表記 (IPv4/IPv6) | 説明 |
| :--- | :--- | :--- | :--- |
| **1 (最高)** | **Intra-Area** | `O` | 同じエリア内で学習されたルート。 |
| **2** | **Inter-Area** | `O IA` / `OI` | 他のエリアから ABR を介して学習されたルート。 |
| **3** | **External Type 1** | `O E1` / `OE1` | OSPF 外部ルート。シードメトリックに内部コストを加算する。 |
| **4** | **NSSA Type 1** | `O N1` / `ON1` | NSSA エリア経由の外部ルート。計算方法は E1 と同じ。 |
| **5** | **External Type 2** | `O E2` / `OE2` | OSPF 外部ルート。シードメトリックのみを使用（デフォルト）。 |
| **6 (最低)** | **NSSA Type 2** | `O N2` / `ON2` | NSSA エリア経由の外部ルート。計算方法は E2 と同じ。 |

※注：同一タイプ（例：E1 と N1）の場合は同等として扱われます。

### 2. コスト計算のメカニズム

OSPF コストは「10^8 / インターフェイス帯域幅 (bps)」で算出されます。

*   **Reference Bandwidth:** デフォルトは 100Mbps です。
*   **問題点:** 100Mbps、1Gbps、10Gbps、100Gbps のインターフェイスがすべて「コスト 1」として計算されるため、高速リンク間での適切なパス選定ができなくなります。
*   **解決策:** <code>auto-cost reference-bandwidth</code> コマンドで全ルータの基準値を統一する必要があります。

### 3. 外部ルートの比較 (E1 vs. E2)

*   **Type 1 (E1):** 「シードメトリック + ASBR までのパスコスト」で比較。ネットワーク全体のコストを反映したい場合に使用。
*   **Type 2 (E2):** デフォルト。シードメトリックのみで比較。シードが同じ場合のみ、ASBR までの内部コストをタイブレーカーとして使用します。

### 4. エリアをまたぐパス選定 (ABR と Virtual-Link)

*   あるエリアの Intra-area パスが、Virtual-link を経由する別のエリアの Intra-area パスよりも優先されます。
*   ABR は、Non-backbone エリアから Area 0 への最適パスを計算する際、まず Area 0 内の LSA を優先します。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、単なる設定ではなく「意図しないパスの修正」や「制約付きの誘導」が出題されます。

### 1. エリア優先順位の罠

「Area 1 (コスト 1000)」の Intra-area ルートと、「Area 0 (コスト 10)」の Inter-area ルートがある場合、ルータは必ず Area 1 のルートを選択します。これを Area 0 経由に変えるには、ルートタイプを変更するか、エリアの構成自体を見直す必要があります。

### 2. 多点 ABR におけるパス選定

2台以上の ABR が存在する場合、Inter-area ルート（LSA Type 3）は、ABR までの内部コストが最小のものが選ばれます。等コストであれば負荷分散（ECMP）が行われます。

### 3. NSSA と Forwarding Address (FA)

NSSA エリアで外部ルートを広報する際、FA がセットされます。
*   FA への到達性がない場合、そのルートはルーティングテーブルにインストールされません。
*   FA へのパスが変わると、外部ルートのネクストホップも変動します。トラブルシューティングセクションでの頻出ポイントです。

### 4. Summarization と Longest Match

集約（Summarization）を行うとメトリックが最小の構成ルートの値にセットされるか、設定された値になります。
*   集約ルートと詳細ルートが混在する場合、**常に Longest Match（最長一致）が最優先**され、OSPF の優先順位やコストは無視されます。これは基本ですが、複雑な再配送シナリオで見落としやすい点です。

---

## 🛠 設定・検証コマンド

### 設定コマンド

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイスコストの直接指定** | <code>(config-if)# ip ospf cost [値]</code> |
| **基準帯域幅の変更(全ルータ必須)** | <code>(config-router)# auto-cost reference-bandwidth [Mbps]</code> |
| **OSPFv3 インターフェイスコスト設定** | <code>(config-if)# ospfv3 cost [値]</code> |
| **外部ルート再配送時のタイプ指定** | <code>redistribute [proto] subnets metric-type [1&#124;2]</code> |
| **集約ルートのコスト指定** | <code>summary-address [network] [mask] cost [値]</code> |
| **AD値の変更 (パス選定への最終手段)** | <code>distance ospf {intra-area&#124;inter-area&#124;external} [AD]</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **OSPFルートのタイプとコスト確認** | <code>show ip route ospf</code> |
| **LSDBの詳細確認 (LSA別)** | <code>show ip ospf database [router&#124;summary&#124;external]</code> |
| **基準帯域幅の設定確認** | <code>show ip ospf &#124; include Reference</code> |
| **OSPFv3 ルートの確認** | <code>show ipv6 route ospf</code> |
| **SPF計算の結果とタイマー確認** | <code>show ip ospf statistics</code> |
| **特定のLSA 7から5への変換確認** | <code>show ip ospf database nssa-external</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIE ラボ試験の難易度を想定した、Path Preference に関する 12 個の実装シナリオです。

### 1. 手動コスト調整によるトラフィック誘導

**【問題内容】**
R1 から R6 への通信において、デフォルトでは <code>GigabitEthernet0/1</code> が選ばれているが、これを <code>GigabitEthernet0/2</code> 経由に変更せよ。ただし、帯域幅の設定（bandwidth コマンド）を変更してはならない。

**【設定サンプル】**
```ios
! 優先させたくないインターフェイスのコストを上げる
interface GigabitEthernet0/1
 ip ospf cost 1000

! または優先させたいパスのコストを下げる
interface GigabitEthernet0/2
 ip ospf cost 10
```

---

### 2. 高速リンク環境での Reference Bandwidth 正規化

**【問題内容】**
ネットワーク内に 10Gbps と 1Gbps のリンクが混在している。OSPF がこれらを適切に区別してコスト計算できるように、全ルータの設定を変更せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! 100Gbpsをコスト1とする設定 (100000 Mbps)
 auto-cost reference-bandwidth 100000
```
*   **注意:** 一部のルータだけで設定すると、パス選定がループしたり、非効率なルート（サブオプティマル）が選ばれる原因になります。

---

### 3. Intra-area 優先ルールの検証

**【問題内容】**
R1 は 10.1.1.0/24 へのパスを 2つ持っている。
- Area 0 経由 (Inter-area, コスト 10)
- Area 1 経由 (Intra-area, コスト 500)
R1 が Area 1 のパスを選択することを確認し、その理由を述べよ。

**【検証】**
```ios
R1# show ip route 10.1.1.0
! 10.1.1.0/24 [110/500] via ..., GigabitEthernet0/1
! ルートは 'O' (Intra-area) と表示される。
```
*   **理由:** OSPF のパス選定において、ルートタイプの優先順位はコストに勝るため。

---

### 4. External Type 1 を使用した「内部コストの反映」

**【問題内容】**
ASBR である R5 が BGP ルートを OSPF に再配送している。OSPF ドメイン内のルータが、ASBR までの距離（ホップ数や帯域幅）を考慮して最短パスを選べるように設定せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! metric-type 1 (E1) を指定することで、内部コストが累積される
 redistribute bgp 65000 subnets metric-type 1
```

---

### 5. Virtual-Link 経由のパス選定

**【問題内容】**
Area 2 が Area 1 をトランジットエリアとして、Virtual-link で Area 0 に接続されている。Area 2 内のルータが Area 0 のルートを学習する際のパスを制御せよ。

**【設定サンプル】**
```ios
router ospf 1
 area 1 virtual-link 2.2.2.2
```
*   **ポイント:** Virtual-link 経由のパスは Area 0 の一部として扱われ、通常の Inter-area パスよりも優先される場合があります。

---

### 6. NSSA ABR での集約によるコスト固定

**【問題内容】**
NSSA エリア 10 のルートを Area 0 へ広報する際、個別のメトリック変動がバックボーンに影響を与えないよう、コスト 100 で集約せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! NSSAからの再配送ルート(LSA 7)を集約
 summary-address 172.16.0.0 255.255.0.0 cost 100
```

---

### 7. Distribute-list による RIB 登録の制限（パス選定の除外）

**【問題内容】**
R3 において、ネイバーから LSA は受信し続けるが、特定のルート `192.168.1.0/24` だけはルーティングテーブルに登録しないようにせよ。

**【設定サンプル】**
```ios
ip prefix-list DENY_PFX permit 192.168.1.0/24
!
route-map OSPF_FILTER deny 10
 match ip address prefix-list DENY_PFX
route-map OSPF_FILTER permit 20
!
router ospf 1
 distribute-list route-map OSPF_FILTER in
```
*   **注意:** これにより RIB からは消えますが、LSDB には残るため、R3 が ABR の場合、他のルータへの広報は止まりません。

---

### 8. OSPFv3 Address Family でのコスト操作 (IPv6)

**【問題内容】**
OSPFv3 環境において、IPv6 トラフィックのみ特定のリンクの優先順位を下げよ。

**【設定サンプル】**
```ios
interface GigabitEthernet0/1
 ospfv3 1 ipv6 cost 5000
```

---

### 9. Forwarding Address 抑制によるパス変更

**【問題内容】**
NSSA ASBR が外部ルートを広報する際、Forwarding Address に 0.0.0.0 をセットするように強制し、トラフィックが必ず ABR を経由するようにせよ。

**【設定サンプル】**
```ios
router ospf 1
 area 10 nssa no-redistribution
 ! または集約時に抑制
 summary-address 10.1.0.0 255.255.0.0 nssa-only
```
※注：`area nssa-only` や特定のオプションで FA の挙動を制御する高度なタスクです。

---

### 10. Administrative Distance の操作による OSPF 優先

**【問題内容】**
同じプレフィックスを EIGRP (AD 90) と OSPF (AD 110) の両方から学習している。OSPF 側のパスを優先するように、R1 内部の設定のみで調整せよ。

**【設定サンプル】**
```ios
router ospf 1
 ! OSPFのAD値をEIGRPより低い80に変更
 distance 80
```

---

### 11. Maximum Path による等コスト負荷分散 (ECMP)

**【問題内容】**
OSPF でコストが同じパスが 8つある。デフォルトの 4つではなく、すべてのパスを使用して負荷分散せよ。

**【設定サンプル】**
```ios
router ospf 1
 maximum-paths 8
```

---

### 12. プレフィックス抑制 (Prefix Suppression) による最適化

**【問題内容】**
ルータ間の Transit リンクの IP 情報を LSDB から除外し、最短パス計算の対象から外すことで LSDB を軽量化せよ。

**【設定サンプル】**
```ios
router ospf 1
 prefix-suppression
```

---

## 参考リソースリンク

### Configurationガイド
*   [OSPFv2 Path Selection Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-17/iro-xe-17-book.html)。
*   [OSPFv3 Address Family Support Configuration](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_ospf/configuration/xe-16/iro-xe-16-book/ip6-route-ospfv3.html)。

### CiscoLive (動画・スライド)
*   [BRKRST-2337: OSPF Deployment in Modern Networks](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2337)。
*   [BRKCCIE-3000: OSPF for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html)。

### テクニカルドキュメント・設定例
*   [OSPF Cost Calculation and Reference Bandwidth](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/7039-1.html#anc18)。
*   [Understanding OSPF External Route Path Selection (E1 vs E2)](https://www.cisco.com/c/en/us/support/docs/ip/open-shortest-path-first-ospf/13692-21.html)。

---

## 📝 補足
- この学習メモは、OSPF のパス選定における「論理的な優先順位」と「数学的なコスト計算」の二段階評価を詳細に解説しています。CCIE ラボ試験では、特に **「Intra-area 優先ルール」** がコストを上回る点を利用した問題が多いため、実機での LSA タイプ確認（`show ip ospf database`）を習慣化することが合格への最短ルートです。


