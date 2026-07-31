---
layout: default
title: 1.2.a-Administrative-distance
parent: 1.2-Routing-concepts
grand_parent: 1-Network-Infrastructure
nav_order: 1
---

# 1.2.a-Administrative-distance

CCIE Enterprise Infrastructure (EI) v1.1のBlueprint項目「1.2 Routing concepts」における「1.2.a Administrative distance」について整理しました。

---

## 📘 概要

アドミニストレーティブディスタンス（AD）は、Ciscoルータにおいて**「ルート情報の信頼性」**を数値化した指標です。ルータが複数の異なるルーティングソース（例：OSPFとEIGRP、あるいはスタティックルート）から全く同じ宛先プレフィックスを学習した場合、ルータはどの情報を最も信頼してルーティングテーブル（RIB）にインストールするかをAD値で判断します。

AD値は**0から255**の範囲を取り、**値が低いほど信頼度が高い**と見なされます。この指標はルータのローカルでのみ意味を持ち、ルーティングアップデートとしてネイバーに送信されることはありません。CCIE EIラボ試験では、複雑な再配送（Redistribution）環境におけるルーティングループの防止や、最適パスの強制選択においてAD値の操作が不可欠なスキルとなります。

---

## 🔑 要点

### 1. デフォルトAD値の完全把握
CCIE候補者は以下のデフォルト値を暗記しているだけでなく、その値がプロトコル選定に与える影響を理解していなければなりません。

| ルートソース | デフォルトAD値 | 備考 |
| :--- | :--- | :--- |
| **Connected** | <code>0</code> | 直接接続。最も信頼される。 |
| **Static** | <code>1</code> | 管理者が手動設定した経路。 |
| **EIGRP Summary** | <code>5</code> | EIGRPの集約ルート。 |
| **External BGP (eBGP)** | <code>20</code> | AS外部から学習したBGPルート。 |
| **Internal EIGRP** | <code>90</code> | 同一AS内のEIGRPルート。 |
| **OSPF** | <code>110</code> | Intra, Inter, External共通。 |
| **IS-IS** | <code>115</code> | |
| **RIP** | <code>120</code> | |
| **External EIGRP** | <code>170</code> | 再配送されたEIGRPルート。 |
| **Internal BGP (iBGP)** | <code>200</code> | 同一AS内のBGPルート。 |
| **Unknown / Untrusted** | <code>255</code> | 信頼できない。RIBにインストールされない。 |

### 2. パス選択の優先順位（RIB Installation）

ルータがパケットを転送する際の決定プロセスにおいて、ADが適用されるタイミングを正確に理解する必要があります。

1.  **最長一致（Longest Prefix Match）**: 宛先IPに対し、最も長いマスクを持つルートを優先します。
2.  **アドミニストレーティブディスタンス（AD）**: マスク長が同じ場合、AD値が低いソースを優先します。
3.  **メトリック（Metric）**: AD値まで同じ場合（同じプロトコル内）、コストが最小のものを選択します。

### 3. AD値 255 の特殊な挙動

AD値を <code>255</code> に設定すると、そのルートは「信頼できない」と判断されます。このルートはトポロジテーブル（EIGRP等）には残りますが、**ルーティングテーブル（RIB）へのインストールが拒否されます**。これは、特定のネイバーからのルートのみを隠蔽する、高度なフィルタリング手法として利用されます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIEラボ試験では、単なるAD値の確認ではなく、意図的に引き起こされた不適切なルーティング（Suboptimal Routing）をAD操作で解決するタスクが出題されます。

### 1. 相互再配送におけるループ防止

2つ以上のルータでOSPFとEIGRPを相互再配送（Mutual Redistribution）する場合、デフォルトADの違いがループの原因となります。
*   **問題**: OSPF(110)からEIGRP(90)へ再配送されたルートが、別の再配送ポイントでEIGRP(170)からOSPF(110)へ戻される際、AD値の不一致により「遠回りなパス」が「正規のパス」を上書きすることがあります。
*   **対策**: 再配送されたルート（External）のAD値を意図的に引き上げ、ドメイン内ルートを常に優先させる設定（<code>distance eigrp</code>等）が求められます。

### 2. 浮動静的ルート（Floating Static Route）とトラッキング

IGP（OSPF/EIGRP）のバックアップとして静的ルートを構成する場合、IGPのAD値より高い値を静的ルートに設定します。
*   ラボでは <code>track</code> オプションと組み合わせ、「物理リンクはUpしているが対向のIP SLAが失敗している場合に、バックアップパス（浮動静的ルート）へ切り替える」といった複合構成が頻出します。

### 3. プロトコル固有の微調整

*   **OSPF**: <code>distance ospf</code> コマンドを用いて、エリア内(Intra)、エリア間(Inter)、外部(External)ごとに個別のAD値を割り当てることが可能です。
*   **EIGRP**: 内部ADと外部ADを <code>distance eigrp [internal] [external]</code> で一括制御します。
*   **BGP**: eBGP, iBGP, LocalルートごとにADを設定し、IGPとの優先度を逆転させる特殊な要件に対応します。

---

## 🛠 設定・検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **浮動静的ルートの設定** | <code>ip route [prefix] [mask] [next-hop] [AD値]</code> |
| **EIGRP全体のアド値を変更** | <code>(config-router)# distance eigrp [internal-ad] [external-ad]</code> |
| **OSPF全体のAD値を変更** | <code>(config-router)# distance [値]</code> |
| **OSPFルートタイプ別のAD変更** | <code>(config-router)# distance ospf {intra-area&#124;inter-area&#124;external} [値]</code> |
| **BGP全体のアド値を変更** | <code>(config-router)# distance bgp [external] [internal] [local]</code> |
| **特定ネイバーからのAD変更** | <code>(config-router)# distance [値] [送信元IP] [ワイルドカード] [ACL]</code> |
| **各プロトコルのAD値確認** | <code>show ip protocols</code> |
| **特定の経路のAD値を確認** | <code>show ip route [prefix]</code> |

---

## 🛠 ラボ学習・設定サンプル例

CCIEレベルのシナリオに基づき、AD操作の具体例を多数提示します。

### 1. EIGRP：特定ネイバーからのルートのみを拒否（AD 255）

**【問題内容】**
R6において、ネイバー 150.1.4.4 から学習する 150.1.4.4/32 のルートのみをルーティングテーブルから除外せよ。プレフィックスリストやディストリビュートリストは使用せず、AD操作のみで実現すること。

**【設定例】**
```ios
! R6の設定
access-list 4 permit 150.1.4.4
!
router eigrp 100
 ! ネイバー150.1.4.4から届くACL 4に一致するルートのADを255にする
 distance 255 150.1.4.4 0.0.0.0 4
```
**【検証】**
<code>show ip route 150.1.4.4</code> を実行し、"% Subnet not in table" と表示されることを確認します。<code>show ip eigrp topology 150.1.4.4/32</code> ではエントリが存在するが、AD 255 のためRIBへ送られていないことがわかります。

---

### 2. 浮動静的ルートとオブジェクトトラッキングの連携

**【問題内容】**
R1は 10.10.10.0/24 へのメインパスをOSPFで学習している。メインパスの障害時（対向ルータ 192.168.1.2 への疎通断）に備え、172.16.1.2 を次ホップとするバックアップルートを構成せよ。

**【設定例】**
```ios
! SLAとトラッキングの設定
ip sla 1
 icmp-echo 192.168.1.2
 frequency 5
ip sla schedule 1 life forever start-time now
!
track 10 ip sla 1 reachability
!
! OSPF(110)より高いAD値 200 を指定し、通常時は隠しておく
! trackによりSLAが失敗した時のみこのルートを有効化（または無効化）する
ip route 10.10.10.0 255.255.255.0 172.16.1.2 200 track 10
```

---

### 3. 相互再配送環境でのパス最適化（EIGRP外部ADの操作）

**【問題内容】**
OSPFドメインからEIGRPへ再配送されたルートが、他の場所で再びOSPFへ戻るのを防ぐため、EIGRP外部ルートの信頼度を下げよ。

**【設定例】**
```ios
router eigrp 100
 ! 内部ルートは90のまま、再配送ルート(External)をデフォルトの170から190へ引き上げる
 distance eigrp 90 190
```

---

### 4. RIPv2：特定セグメント経由のルートのみ信頼度を変更

**【問題内容】**
R9において、R7（155.1.79.7）から学習するRIPルートのみ、AD値を 120 から 130 に変更せよ。

**【設定例】**
```ios
! R9の設定
router rip
 version 2
 ! 全てのルートに対して、ソース155.1.79.7からのものだけAD 130を適用
 distance 130 155.1.79.7 0.0.0.0
```

---

### 5. OSPF：ルートタイプ別のAD微調整

**【問題内容】**
OSPFドメイン内において、エリア間ルート(Inter-area)よりも外部ルート(External)のAD値を高く設定し、外部からの不安定な経路よりも内部ネットワークの集約経路を優先させよ。

**【設定例】**
```ios
router ospf 1
 ! intra(110), inter(110), external(150) のように外部だけ値を上げる
 distance ospf intra-area 110 inter-area 110 external 150
```

---

### 6. BGP：iBGP経路をIGP経路より優先させる（AD操作）

**【問題内容】**
通常、iBGP(200)はOSPF(110)より優先順位が低い。特定の宛先に対してのみ、iBGPで学習した経路をOSPFよりも優先してRIBにインストールさせよ。

**【設定例】**
```ios
router bgp 65001
 ! iBGPのADをデフォルトの200から、OSPF(110)より低い100へ変更
 distance bgp 20 100 200
```
※注：これはルーティングループの危険を伴うため、ラボの特定の要件がある場合のみ使用するテクニックです。

---

## 参考リソースリンク

### Configurationガイド
*   [IP Routing: Protocol-Independent Configuration Guide (Cisco IOS XE 17.x)](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/iproute_pi/configuration/xe-17/iri-xe-17-book.html)
*   [Administrative Distance (Cisco Support Document)](https://www.cisco.com/c/en/us/support/docs/ip/border-gateway-protocol-bgp/15986-admin-distance.html)

### CiscoLive (動画・スライド)
*   [BRKRST-3320: Troubleshooting Routing Protocols](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-3320)
*   [BRKCCIE-3000: BGP is your Friend – BGP for the CCIE Candidates](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCCIE-3000)

### テクニカルドキュメント・設定例
*   [Filtering Routing Information (Setting AD to 255)](https://www.cisco.com/c/ja_jp/support/docs/ip/enhanced-interior-gateway-routing-protocol-eigrp/13677-19.html)
*   [Configuring Floating Static Routes with IP SLA](https://www.cisco.com/c/en/us/support/docs/ip/routing-information-protocol-rip/118833-configure-rip-00.html)

---


## 📝 補足

この学習メモは、CCIE EIラボ試験で遭遇する「なぜこのパスが選ばれないのか？」というトラブルシューティングにおいて、AD値の不整合を迅速に特定し、最適化するための指針となります。特に再配送を伴うタスクでは、ADの操作が合否を分ける決定的な要素となります。

