---
layout: default
title: 2.2.f-Localized-policies
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 6
---

# 2.2.f Localized Policies

Cisco SD-WAN (Viptela) アーキテクチャにおいて、**Localized Policies（ローカライズド・ポリシー）**は、各 WAN Edge デバイス（cEdge/vEdge）上で個別に実行される制御メカニズムです。中央集中型の Centralized Policy が vSmart 上で動作しネットワークトポロジ全体を制御するのに対し、Localized Policy はデバイスの物理インターフェイス、特定の VPN 内のルーティングプロトコル、あるいは QoS 処理といった「デバイス固有」の挙動を定義します。

---

## 📘 概要

**Localized Policies** は、vManage で作成され、Device Template の一部として WAN Edge デバイスへプッシュされる設定群です。主にデータプレーンのトラフィック制御（ACL）と、コントロールプレーンの経路制御（Route Policy）の 2 つの側面を持ちます。

1.  **Access Lists (i):** インターフェイスの Ingress/Egress において、特定の IP アドレス、プロトコル、ポート番号に基づいたパケットのフィルタリングや分類（QoS マーキング）を行います。
2.  **Route Policies (ii):** BGP、OSPF、EIGRP などの LAN 側プロトコルから OMP への再配送（Redistribution）、またはその逆のプロセスにおいて、プレフィックスのフィルタリングやメトリック、タグ、優先度などの属性変更を行います。

Localized Policy は「テンプレート」ベースで管理されるため、数百台のルータに対して同一のフィルタリングルールや QoS 設定を一括適用しつつ、変数（Variables）を用いて拠点ごとに異なるパラメータを持たせることが可能です。

---

## 🔑 要点

### 1. Access Lists (ACLs) (i)

SD-WAN における ACL は、従来の IOS ACL と概念は似ていますが、vManage の Feature Template を通じて定義される点が異なります。
*   **適用範囲:** 特定のインターフェイス（VPN 0 や Service VPN）に適用されます。
*   **主な用途:** 
    *   **トラフィックフィルタリング:** 特定のホストやネットワークからの通信を許可・拒否します。
    *   **QoS 分類:** 特定のアプリケーション（音声、動画等）を識別し、QoS キューへ割り当てるためのクラス分類を行います。
    *   **ミラーリング:** トラフィックを指定の宛先へコピーして転送します。
*   **暗黙の拒否:** ACL の最後には必ず「暗黙の拒否（Implicit Deny）」が存在するため、許可リスト形式で作成する際は注意が必要です。

### 2. Route Policies (ii)

Route Policy は、ルーティングの決定プロセスに介入し、情報の「取捨選択」と「加工」を行います。
*   **適用ポイント:** OMP と各種ルーティングプロトコル（BGP/OSPF/EIGRP/Static/Connected）の境界に適用されます。
*   **マッチ条件:** プレフィックスリスト（Prefix List）、AS パス（BGP の場合）、コミュニティタグ、メトリック、ネクストホップなどが指定可能です。
*   **アクション:** 経路の許可（Accept）・拒否（Reject）に加え、AD 値の変更、BGP 属性の操作、OMP タグの付与など、高度なトラフィックエンジニアリングを実現します。

### 3. 設定の構造

Localized Policy は以下のステップでデバイスに適用されます：
1.  **Policy Definition:** vManage の `Configuration -> Policies -> Localized Policy` でポリシー本体（ACL や Route Policy）を作成。
2.  **Template Association:** 作成したポリシーを「Device Template」の `Additional Templates` セクション内の `Policy` 項目に関連付け。
3.  **Deployment:** テンプレートをデバイスに適用（Push）することで、デバイス上の設定（`policy` セクション）として反映。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、複雑なトポロジ要件を満たすための「ピンポイントな制御」が問われます。

### 1. 再配送ループの防止 (Redistribution Loop Prevention)

ハイブリッド環境（OSPF と OMP の相互再配送など）では、再配送によって経路がループするリスクがあります。
*   **対策:** Route Policy を使用して、再配送時に「ルートタグ」を付与します。反対側の再配送ポイントでそのタグを持つルートを拒否するように設定します。これは CCIE レベルの典型的な課題です。

### 2. インターフェイス ACL による管理プレーンの保護

「管理 VPN (512) 以外からの SSH アクセスを制限せよ」といったセキュリティ要件が出題されます。
*   **注意:** `vpn 0` インターフェイスに ACL を適用する場合、コントローラ（vSmart/vManage）とのコントロールコネクション（DTLS/TLS）を遮断しないよう、ポート 12344-12446 等を明示的に許可する必要があります。

### 3. QoS マーキングとスケジューリング

Localized Policy で DSCP マーキングを行い、インターフェイス設定（VPN 0）でシェーピングやキューイングを定義する一連の流れをマスターしてください。
*   **確認点:** cEdge (IOS-XE) では内部的に `policy-map` に変換されますが、vEdge (Viptela OS) との構文の違いを意識する必要があります。

### 4. BGP 属性操作によるマルチホーム拠点の最適化

2 つのトランスポート回線を持つ拠点において、特定のプレフィックスだけ BGP Local Preference を変えて経路を選択させるシナリオが想定されます。

---

## 🛠 設定・検証コマンド

### vEdge/cEdge CLI による検証

Localized Policy は vManage で設定しますが、検証は CLI で行うのが迅速です。

| 目的 | コマンド |
| :--- | :--- |
| **適用されている ACL の一覧表示** | <code>show access-list</code> |
| **ACL によるパケットヒット数の確認** | <code>show access-list counter</code> |
| **Route Policy の内容確認** | <code>show running-config policy</code> |
| **OMP ルートのフィルタリング結果確認** | <code>show omp routes [prefix]</code> |
| **特定の VRF におけるルーティング確認** | <code>show ip route vrf [ID]</code> |
| **QoS ポリシーの統計情報確認** | <code>show sdwan policy-map [interface]</code> |

---

## 🛠 ラボ学習・設定サンプル例

### 1. 管理用 VTY アクセスの ACL 制限

**【問題】** VPN 512 のインターフェイス eth0 において、特定の運用管理セグメント (10.10.10.0/24) 以外からの SSH 接続を拒否せよ。

**【設定例】**
```ios
policy
 access-list MGMT_ACL
  sequence 10
   match
    source-ip 10.10.10.0/24
    protocol 6
    destination-port 22
   action accept
  sequence 20
   action drop  ! 暗黙の拒否を明示
!
vpn 512
 interface eth0
  access-list MGMT_ACL in
```

---

### 2. BGP から OMP への再配送時のフィルタリング

**【問題】** BGP AS 65001 から学習した経路のうち、192.168.100.0/24 以外の経路は OMP に広報しないようにせよ。

**【設定例】**
```ios
policy
 prefix-list ALLOW_100
  ip-prefix 192.168.100.0/24
 !
 route-policy REDIST_BGP_TO_OMP
  sequence 10
   match
    address ALLOW_100
   action accept
  sequence 20
   action reject
!
omp
 advertise bgp route-policy REDIST_BGP_TO_OMP
```

---

### 3. Route Tag による再配送ループ防止

**【問題】** OSPF ルートを OMP に入れる際、タグ 666 を付与せよ。また、OMP から OSPF に戻す際、タグ 666 を持つルートを破棄せよ。

**【設定例】**
```ios
policy
 route-policy TAG_FOR_OMP
  sequence 10
   action accept
    set tag 666
 !
 route-policy FILTER_OMP_TAG
  sequence 10
   match
    tag 666
   action reject
  sequence 20
   action accept
!
router ospf 1 vrf 10
 redistribute omp route-policy FILTER_OMP_TAG
```

---

### 4. ローカルインターフェイスでの QoS マーキング

**【問題】** LAN 側ポート (ge0/2) から入るパケットのうち、宛先が 172.16.1.10 (VoIP Server) のトラフィックに DSCP EF (46) をマーキングせよ。

**【設定例】**
```ios
policy
 access-list QOS_MARKING
  sequence 10
   match
    destination-ip 172.16.1.10/32
   action accept
    set dscp 46
!
vpn 10
 interface ge0/2
  access-list QOS_MARKING in
```

---

### 5. 特定ネイバーへの BGP メトリック操作

**【問題】** 支店側のルータにおいて、特定の BGP ネイバーへ広報する経路の MED (Multi-Exit Discriminator) を 100 に設定せよ。

**【設定例】**
```ios
policy
 route-policy SET_MED
  sequence 10
   action accept
    set metric 100
!
router bgp 65002
 neighbor 10.1.1.1
  address-family ipv4 vrf 10
   route-policy SET_MED out
```

---

### 6. OMP Preference によるパス選択の誘導

**【問題】** 10.200.0.0/16 へのルートに対し、OMP Preference を 200 に設定して、他の拠点よりも優先的に選ばれるようにせよ。

**【設定例】**
```ios
policy
 route-policy PREFER_ROUTE
  sequence 10
   match
    address ALLOW_200
   action accept
    set preference 200
!
omp
 advertise connected route-policy PREFER_ROUTE
```

---

### 7. IPv6 プレフィックスフィルタリング

**【問題】** 内部の IPv6 ネットワーク 2001:DB8:ACAD::/64 のみを外部へ広告するよう Route Policy を構成せよ。

**【設定例】**
```ios
policy
 ipv6-prefix-list V6_INTERNAL
  ipv6-prefix 2001:DB8:ACAD::/64
 !
 route-policy V6_FILTER
  sequence 10
   match
    ipv6-address V6_INTERNAL
   action accept
  sequence 20
   action reject
```

---

### 8. コントロールコネクションの保護 ACL (vEdge 例)

**【問題】** インターネット回線 (ge0/1) において、SD-WAN の制御通信 (UDP 12344) のみを許可する ACL を作成せよ。

**【設定例】**
```ios
policy
 access-list WAN_SEC_ACL
  sequence 10
   match
    protocol 17
    destination-port 12344
   action accept
  sequence 20
   action drop
!
vpn 0
 interface ge0/1
  access-list WAN_SEC_ACL in
```

---

### 9. OSPF 外部ルート (Type 2) の属性変更

**【問題】** OMP から OSPF へ再配送するルートのメトリックタイプを E1 (External Type 1) に変更せよ。

**【設定例】**
```ios
policy
 route-policy SET_E1
  sequence 10
   action accept
    set ospf-metric-type type1
!
router ospf 1 vrf 10
 redistribute omp route-policy SET_E1
```

---

### 10. 宛先ポートに基づく ICMP 拒否 (Localized ACL)

**【問題】** 特定のサーバーセグメントへの ICMP (Ping) 通信を、エッジポートの入口でブロックせよ。

**【設定例】**
```ios
policy
 access-list BLOCK_PING
  sequence 10
   match
    protocol 1
   action drop
  sequence 20
   action accept  ! 他のトラフィックは許可
!
vpn 10
 interface ge0/3
  access-list BLOCK_PING in
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**BRKTRS-3793: Advanced SD-WAN Routing Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-3793)
    *   再配送やポリシーによるルーティング不整合の深いトラブルシューティング手法が解説されています。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081)
    *   ポリシーがデバイスに正しく push されない際の原因切り分けに役立ちます。

### Configuration ガイド
*   [**Cisco SD-WAN Localized Policy Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/policies/vedge-20-x/policies-book.html)
    *   ACL、Route Policy の全パラメータが網羅されています。
*   [**Configuring QoS for SD-WAN**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/qos/vedge-20-x/qos-book.html)。

### テクニカルドキュメント・設定例
*   [**SD-WAN: Route Policy Examples and Operations**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)。
*   [**Understand SD-WAN Access Control Lists (ACLs)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/215321-sd-wan-certificate-management-and-troubl.html)。

---
## 📝 補足
- この学習メモは、Localized Policy が「デバイスとネットワークの境界」を守り、整えるための重要なツールであることを示しています。CCIE ラボ試験では、**Centralized Policy との競合**を避けつつ、再配送時の **Tag 操作** や **Metric 調整** をミスなく完遂することが合格への道筋となります。


