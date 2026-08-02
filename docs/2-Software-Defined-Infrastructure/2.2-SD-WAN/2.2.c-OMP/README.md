---
layout: default
title: 2.2.c-OMP
parent: 2.2-SD-WAN
grand_parent: 2-Software-Defined-Infrastructure
nav_order: 1
---

# 2.2.c Overlay Management Protocol (OMP)

Cisco SD-WAN（Viptela）アーキテクチャにおいて、**OMP (Overlay Management Protocol)** はオーバーレイ全体の「頭脳」として機能する制御プレーンプロトコルです。本メモでは、CCIE EI v1.1のBlueprint項目に基づき、OMPの属性、セキュリティ、経路制御、および外部連携について詳細に解説します。

---

## 📘 概要

**OMP (Overlay Management Protocol)** は、WAN Edge デバイス（cEdge/vEdge）と vSmart コントローラ間、および vSmart コントローラ相互間で動作する独自のプロトコルです。BGPに似たパスベクトル型の動作をしますが、SD-WAN特有の「トランスポートの抽象化」を実現するために最適化されています。

OMPは以下の3種類の情報を交換します:
1.  **OMP Routes (vRoutes):** LAN側のネットワークプレフィックス情報。
2.  **TLOC Routes:** トンネルの終端点（ネクストホップ）情報。IPアドレス、Color、カプセル化タイプを含みます。
3.  **Service Routes:** ファイアウォールやIPSなどのネットワークサービスの位置情報。

OMPにより、WAN Edgeデバイスは他のエッジデバイスと直接ルーティングプロトコル（フルメッシュBGP等）を動かす必要がなくなり、すべての制御をvSmartに集約することで大規模なスケーラビリティを実現します。

---

## 🔑 要点

### 1. OMP Attributes (i)

OMPはベストパス選定のために複数の属性を使用します。これらはポリシーによって操作可能です。

*   **TLOC (Transport Location):** ネクストホップに相当。System IP、Color、Encapsulationの3要素で構成されます。
*   **Origin:** 経路のソース（Connected, Static, OSPF, BGP, EIGRP等）。
*   **Originator:** 経路を最初に広告したエッジのSystem IP。
*   **Preference:** 優先度（Local Preference相当）。値が高いほど優先されます。
*   **Site-ID:** 拠点の識別子。ループ防止に使用されます。
*   **Tag:** 経路のグループ化やフィルタリングに使用する任意の識別子。
*   **Weight:** vEdge内部での優先度。

### 2. IPsec Key Management (ii)

SD-WANでは従来のIKE (Internet Key Exchange) を使用せず、OMPが暗号鍵の配布を担います。
*   **メカニズム:** 各エッジデバイスは自身のIPsec公開鍵（AES-256）を生成し、OMP TLOCルートの一部としてvSmartへ送信します。
*   **配布:** vSmartはこれらの鍵を他のすべての認可済みエッジデバイスへリフレクト（反射）します。
*   **メリット:** デバイス間での個別のIKEネゴシエーションが不要になり、数千拠点規模でも高速に暗号化トンネルを確立できます。

### 3. Route Aggregation (iii)

大規模環境でのルーティングテーブル肥大化を防ぐため、OMPで集約ルートを広告できます。
*   **実装:** `omp` 設定配下、または特定の `address-family` 配下で `aggregate` コマンドを使用してサマリルートを生成します。
*   **条件:** 集約対象となる具体的なプレフィックス（Specific routes）がルーティングテーブルに存在する必要があります。

### 4. Redistribution (iv)

LAN側のIGP（OSPF, EIGRP, BGP）やスタティックルートをOMPに注入し、逆にOMPのルートをLAN側へ配布するプロセスです。
*   **OMPへの注入:** デフォルトでは Connected, Static が自動で注入されます。OSPFやBGPは明示的な `advertise` 設定が必要です。
*   **OMPからの配布:** Feature Template または CLI の各プロトコル（OSPF, EIGRP等）設定内で `redistribute omp` を設定します。

### 5. Additional Features (v)

*   **BGP AS Path Propagation:** ハイブリッドネットワークにおいて、BGPのAS_PATH情報をOMP経由で透過させ、ループ防止やパス選定に利用します。
*   **SDA Integration:** Cisco DNA Center (SD-Access) と連携し、キャンパス内のSGT（Scalable Group Tag）情報をSD-WANのVXLAN-GPOヘッダーに載せてWAN越しに伝播させます。

---

## 🎯 試験対策 (CCIE EIレベル)

ラボ試験では、OMPのデフォルト動作を理解した上での「トラフィックエンジニアリング」と「再配送ループの防止」が重要です。

### 1. ベストパス選定アルゴリズムの暗記

vSmartは以下の順序でパスを決定します。
1.  **AD値:** 低い方を優先。
2.  **OMP Preference:** 高い方を優先（デフォルト 0）。
3.  **TLOC Route Preference:** 高い方を優先。
4.  **Origin:** (Connected > Static > EBGP > OSFP Intra > OSPF Inter > OSPF External > IBGP > Unknown)。
5.  **Originator System IP:** 低い方を優先。

### 2. 等コスト負荷分散 (ECMP)

*   デフォルトでは、同一プレフィックスに対して最大4つのパスが選定されます。
*   ラボで「特定のリンクのみを使用せよ」という要件があれば、`preference` を変更します。「全リンクを均等に使え」という場合は、`send-path-limit` と `maximum-paths` の調整が問われます。

### 3. 再配送時のタグ付け

*   OMP $\leftrightarrow$ OSPF などの相互再配送を行う際、ルーティングループが発生しやすくなります。
*   **対策:** 再配送時に `tag` を付与し、逆側の再配送時にそのタグを持つルートを拒否するルートマップ構成を習得してください。

### 4. TLOC Extension の挙動

*   アンダーレイの物理リンクが一方のルータにしかない場合でも、OMPが隣接ルータを介してTLOCを広告し、オーバーレイを形成させるシナリオ。この時のネクストホップの変化に注意が必要です。

---

## 🛠 設定・検証コマンド

### OMP 基本設定 (CLI)

| 目的 | コマンド |
| :--- | :--- |
| **OMP 有効化・基本設定** | <code>omp</code> <br> <code>no shutdown</code> <br> <code>graceful-restart</code> |
| **パス広報数の上限変更** | <code>(config-omp)# send-path-limit</code> |
| **ECMP パス数の変更** | <code>(config-omp)# maximum-paths</code> |
| **LAN側ルートの広告設定** | <code>(config-omp)# advertise [bgp&#124;ospf&#124;eigrp]</code> |
| **集約ルートの生成** | <code>(config-omp)# address-family ipv4 vpn [ID] aggregate [PREFIX/MASK]</code> |

### 再配送設定 (cEdge 例)

| 目的 | コマンド |
| :--- | :--- |
| **OMP を EIGRP へ** | <code>router eigrp [AS]</code> <br> <code>address-family ipv4 vrf [ID]</code> <br> <code>redistribute omp [metric]</code> |
| **OMP を OSPF へ** | <code>router ospf [ID] vrf [NAME]</code> <br> <code>redistribute omp subnets</code> |

### 検証・トラブルシューティング

| 目的 | コマンド |
| :--- | :--- |
| **OMP セッションの概要** | <code>show omp summary</code> |
| **学習した OMP ルート確認** | <code>show omp routes [prefix]</code> |
| **TLOC 情報の詳細確認** | <code>show omp tlocs</code> |
| **IPsec 暗号鍵の交換確認** | <code>show control connections</code> <br> <code>show ipsec local-SA</code> |
| **ポリシー適用結果の確認** | <code>show sdwan policy from-vsmart</code> |

---

## 🧪 ラボ学習・設定サンプル例

実際の CCIE シナリオに基づいた、OMP 操作の 12 ステップです。

### 1. 基本的な OMP セッションの確立確認

**【問題】** エッジデバイスが vSmart と正しく OMP ピアリングを張っているか確認せよ。
```ios
# show omp summary
! Status が "Up" で、peer アドレスが vSmart の System IP であることを確認
```

---

### 2. OSPF 経路の OMP への広告

**【問題】** 支店ルータで動作している OSPF ルートを、SD-WAN ネットワーク全体に広報せよ。
```ios
omp
 no shutdown
 address-family ipv4
  advertise ospf
```

---

### 3. OMP Preference による優先経路の指定

**【問題】** 宛先 10.1.0.0/16 に対し、R1 (System-IP 1.1.1.1) 経由のパスを最優先にせよ。
```ios
! vSmart の Centralized Policy にて
policy
 control-policy PREFER_R1
  sequence 10
   match route
    prefix-list SITE10_PFX
    originator 1.1.1.1
   action accept
    set preference 200
```

---

### 4. OMP から EIGRP への再配送

**【問題】** オーバーレイで学習したルートを、LAN 側の EIGRP ネイバーへ再配送せよ。
```ios
router eigrp SDWAN
 address-family ipv4 vrf 10
  topology base
   redistribute omp
```

---

### 5. ルート集約 (Aggregation) の実装

**【問題】** 172.16.1.0/24 と 172.16.2.0/24 を 172.16.0.0/16 にまとめて広告せよ。
```ios
omp
 address-family ipv4 vpn 10
  aggregate 172.16.0.0/16
```

---

### 6. OMP Send-Path-Limit の拡張

**【問題】** 同一の TLOC に対し、最大 8 つの異なるパス情報を vSmart へ送信するようにせよ。
```ios
omp
 send-path-limit 8
```

---

### 7. 再配送ループ防止 (Route Tagging)

**【問題】** OMP から再配送されたルートにタグ 666 を付け、再度 OMP に戻らないようにせよ。
```ios
route-map OMP_TO_OSPF permit 10
 set tag 666
!
router ospf 1 vrf 10
 redistribute omp route-map OMP_TO_OSPF
!
omp
 address-family ipv4 vpn 10
  advertise ospf route-map DENY_666
!
route-map DENY_666 deny 10
 match tag 666
route-map DENY_666 permit 20
```

---

### 8. TLOC Weight による送信トラフィック制御

**【問題】** R1 において、2 つのインターネットリンクのうち一報に 2 倍のトラフィックを流せ。
```ios
vpn 0
 interface ge0/0
  tunnel-interface
   weight 20  ! デフォルトは 1
```

---

### 9. BGP AS Path 保持の有効化

**【問題】** SD-WAN を通過する際、元の BGP AS パス情報を破棄せずに伝播させよ。
```ios
omp
 address-family ipv4
  propagate-aspath
```

---

### 10. Service Route (Firewall) の広報

**【問題】** センター拠点に配置した FW (10.10.10.10) をサービスとして登録し、他拠点に知らせよ。
```ios
vpn 10
 service FW address 10.10.10.10
! OMP が自動的にサービスルートを生成する
```

---

### 11. 特定の Site-ID からのルート拒否
**【問題】** Site-ID 50 から届くすべての OMP ルートを vSmart でフィルタリングせよ。
```ios
! vSmart Policy
policy
 control-policy FILTER_SITE50
  sequence 10
   match route
    site-id 50
   action reject
```

---

### 12. OMP Graceful Restart の確認

**【問題】** vSmart が再起動しても、データプレーンが維持される時間を 10 分に設定せよ。
```ios
omp
 timers
  graceful-restart-timer 600
```

---

## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKTRS-3793: Advanced SD-WAN Routing Troubleshooting**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-3793) - OMP ベストパス選定とトラブル解決。
*   [**BRKENT-2081: Troubleshooting Cisco SD-WAN**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKENT-2081) - OMP セッション断の診断手法。

### Configuration ガイド
*   [**Cisco SD-WAN Overlay Management Protocol (OMP) Guide**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/vEdge-20-x/routing-book/m-routing-omp.html)。
*   [**Unicast Overlay Routing Configuration (Cisco Docs)**](https://www.cisco.com/c/en/us/td/docs/routers/sdwan/configuration/routing/vEdge-20-x/routing-book/m-unicast-overlay-routing.html)。

### テクニカルドキュメント・設定例
*   [**Understanding OMP Path Selection (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/routers/sd-wan/214509-troubleshoot-sd-wan-control-connections.html)。
*   [**SD-Access and SD-WAN Integration Design Guide**](https://www.cisco.com/c/en/us/td/docs/solutions/CVD/Campus/sda-sdwan-integration-2019oct.pdf)。

---

## 📝 補足
- この学習メモは、SD-WAN ネットワークの「血管」であるデータプレーンを制御する「神経」としての OMP に焦点を当てています。CCIE EI ラボ試験では、**vSmart でのポリシー制御が TLOC や vRoute にどう反映されるか**を `show omp` コマンドで正確に追跡できるかどうかが、合格を分ける最大のポイントとなります。


