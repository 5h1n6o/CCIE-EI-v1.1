---
layout: default
title: 4.6.b-Tracking
parent: 4.6-Network-optimization
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 2
---

# 4.6.b Tracking objects and lists

本メモでは、Cisco IOS XE における **Enhanced Object Tracking (EOT)** について、CCIE Enterprise Infrastructure (EI) v1.1 の試験範囲に基づき詳述します。オブジェクトトラッキングは、インフラの可用性とルーティングの動的な最適化を支える極めて重要なコンポーネントです。

---

## 📘 概要

**Enhanced Object Tracking (EOT)** は、特定のネットワーク要素（インターフェイスの状態、IP ルートの存在、IP SLA の結果など）の状態を監視し、その結果を他のクライアントプロセス（HSRP, VRRP, スタティックルート, PBR 等）に通知するメカニズムです,。

従来のトラッキングは HSRP などの特定プロトコルに密結合していましたが、EOT はトラッキングロジックを独立させることで、「何を見て、何を判断するか」を高度に抽象化します。これにより、単一の障害検知だけでなく、複数の条件を論理演算（AND/OR）で組み合わせた複雑なフェイルオーバーシナリオの実装が可能になります,。

---

## 🔑 要点

### 1. トラッキング対象のオブジェクト (Tracked Objects)

EOT は以下の要素を監視できます。
*   **Interface:** ラインプロトコルの状態 (Up/Down) や IP ルーティングの有効性。
*   **IP Route:** ルーティングテーブル内に特定のプレフィックスが存在するか、および到達可能か。
*   **IP SLA:** ICMP エコー、UDP ジッター、TCP 接続などの測定結果に基づく到達性 (Reachability) または状態 (State)。
*   **IPv6:** IPv6 ルートや隣接関係の状態。

### 2. トラッキングリスト (Tracking Lists)

複数のオブジェクトをまとめて一つの「リスト」として扱い、柔軟な判定基準を定義できます。
*   **Boolean Logic:** `and`（すべて UP ならリストも UP）または `or`（いずれか一つが UP なら UP）を使用します。
*   **Weight-based:** 各オブジェクトに重み（Weight）を付与し、合計値がしきい値（Threshold）を超えた場合に UP と判定します。
*   **Percentage-based:** リスト内のオブジェクトのうち、UP である割合に基づいて判定します。

### 3. 遅延タイマー (Delay)

オブジェクトの状態が変化してから、実際にトラッキング結果を反映させるまでに「待ち時間」を設定できます。
*   **Up Delay:** 復旧時のフラッピング（チャタリング）を防止するために、安定するまで待機します。
*   **Down Delay:** 一時的なパケットロスによる誤検知を防ぐために、短時間の切断を無視します。

### 4. 負論理のサポート (NOT Keyword)

トラッキングリスト内で `not` キーワードを使用すると、「そのオブジェクトが DOWN であること」を UP の条件として反転させることができます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、複雑な要件を正確なトラッキングロジックに落とし込む能力が試されます。

### 1. 決定論的パス選択の制御

「WAN1 と WAN2 の両方がダウンしたときのみ、コストの高い 4G 回線（バックアップ）を有効にせよ」といったシナリオが出題されます。
*   **対策:** WAN1 と WAN2 を監視する IP SLA を作成し、それらを `track list boolean or` でまとめ、スタティックルートに `track` オプションで適用します。

### 2. HSRP/VRRP との高度な連携

「上位のルーティングテーブルから 8.8.8.8 (ISP) へのルートが消えたら、HSRP のプライオリティを 50 下げて Standby に降格せよ」といった、単なる物理リンク監視を超えた要件が問われます。
*   **対策:** `track ip route 8.8.8.8/32 reachability` を構成し、インターフェイス配下で `standby track [ID] decrement 50` を適用します。

### 3. PBR (Policy Based Routing) での検証

PBR でネクストホップを指定する際、そのネクストホップが実際に生きていないとパケットがドロップされます。
*   **対策:** `set ip next-hop verify-availability ... track [ID]` を使用して、トラッキング結果が UP の場合のみ PBR を実行させ、それ以外は通常のルーティングに従わせる構成が必要です。

### 4. 複数拠点の死活監視 (Threshold-weight)

「3 つのゲートウェイのうち、2 つ以上がダウンしたら障害とみなせ」といったシナリオ。
*   **対策:** 各ゲートウェイの track に weight 10 を設定し、リストの `threshold weight down 11 up 21` のように設定して、数に応じた動的制御を行います。

---

## 🛠 設定・検証コマンド

### トラッキングオブジェクトの作成

| 目的 | コマンド |
| :--- | :--- |
| **インターフェイス監視** | <code>track [ID] interface [INT] line-protocol</code> |
| **IPルート監視** | <code>track [ID] ip route [PREFIX/LEN] reachability</code> |
| **IP SLA連携** | <code>track [ID] ip sla [SLA_ID] reachability</code> |
| **遅延の設定** | <code>(config-track)# delay {up&#124;down} [SECONDS]</code> |

### トラッキングリストの構成

| 目的 | コマンド |
| :--- | :--- |
| **論理積/和リスト** | <code>track [ID] list boolean {and&#124;or}</code> |
| **否定条件の追加** | <code>(config-track)# object [OBJ_ID] not</code> |
| **重みベースリスト** | <code>track [ID] list threshold weight</code> |
| **重みの定義** | <code>(config-track)# object [OBJ_ID] weight [VALUE]</code> |
| **しきい値の定義** | <code>(config-track)# threshold weight {up&#124;down} [VAL]</code> |

### 検証・統計

| 目的 | コマンド |
| :--- | :--- |
| **全トラックの状態表示** | <code>show track</code> |
| **特定のトラック詳細確認** | <code>show track [ID]</code> |
| **簡略表示** | <code>show track brief</code> |
| **デバッグ** | <code>debug track</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. スタティックルートの自動削除

**【課題】** 10.1.1.2 への Ping が失敗したら、172.16.1.0/24 へのスタティックルートを無効化せよ。
```ios
ip sla 1
 icmp-echo 10.1.1.2
 frequency 5
ip sla schedule 1 start-time now life forever
!
track 1 ip sla 1 reachability
!
ip route 172.16.1.0 255.255.255.0 10.1.1.2 track 1
```

### 2. インターフェイス連動型 HSRP 切り替え

**【課題】** WAN インターフェイス Gi0/0 がダウンした際、HSRP プライオリティを 30 減算せよ。
```ios
track 10 interface GigabitEthernet0/0 line-protocol
!
interface GigabitEthernet0/1
 standby 1 track 10 decrement 30
```

### 3. IP ルート存在のトラッキング

**【課題】** ルーティングテーブルに 8.8.8.8/32 が存在する場合のみ UP となるオブジェクトを作成せよ。
```ios
track 20 ip route 8.8.8.8 255.255.255.255 reachability
```

### 4. 論理積 (AND) リストの作成

**【課題】** オブジェクト 2 と 3 の「両方」が UP の時のみ UP となるリストを作成せよ。
```ios
track 1 list boolean and
 object 2
 object 3
```

### 5. 否定論理 (NOT) を含むリスト

**【課題】** オブジェクト 2 が UP かつ、オブジェクト 3 が「DOWN」の時に UP となるリストを作成せよ。
```ios
track 1 list boolean and
 object 2
 object 3 not
```

### 6. 重みベースの冗長構成

**【課題】** 3 つの ISP (Track 11, 12, 13) のうち、2 つ以上がダウン（残りが 1 つ以下）したらバックアップへ切り替えよ。
```ios
track 100 list threshold weight
 object 11 weight 10
 object 12 weight 10
 object 13 weight 10
 threshold weight down 15 up 25
 ! 合計30から15以下(2つダウン)でDOWN判定
```

### 7. フラッピング防止の遅延タイマー

**【課題】** トラック 5 が UP に戻った際、30 秒間待機してから UP 状態を確定させよ。
```ios
track 5 ip sla 5 reachability
 delay up 30
```

### 8. PBR ネクストホップの検証

**【課題】** ネクストホップ 192.168.1.1 が到達可能な時のみ PBR を適用せよ。
```ios
track 50 ip sla 50 reachability
!
route-map PBR_CHECK permit 10
 match ip address 101
 set ip next-hop verify-availability 192.168.1.1 1 track 50
```

### 9. IPv6 到達性のトラッキング

**【課題】** IPv6 アドレス 2001:DB8::1 への到達性を監視せよ。
```ios
ipv6 sla 1
 icmp-echo 2001:DB8::1
!
track 60 ipv6 sla 1 reachability
```

### 10. インターフェイス IP ルーティングの監視

**【課題】** インターフェイスに IP アドレスが設定され、かつルーティングが可能な状態かを監視せよ。
```ios
track 70 interface GigabitEthernet0/1 ip routing
```

### 11. オブジェクトスタブの利用 (EEM 連携)

**【課題】** 手動またはスクリプトで状態を制御できるオブジェクト 80 を作成せよ。
```ios
track 80 stub-object
! EEM等から 'track 80 state up' などのコマンドで操作可能
```

### 12. トラッキング状態の確認 (検証タスク)

**【操作】** `show track` の出力を確認し、現在の最新状態と、最後に変化した時刻を確認せよ。
```ios
# show track 1
! 期待される出力:
! Track 1
!   List boolean and
!   Boolean AND is Up
!     1 changes, last change 00:05:23
!     Object 2 is Up
!     Object 3 is Down (negated)
```

---

## 🔗 参考リソース

### Cisco Live (動画・スライド)
*   [**DGTL-BRKRST-2042: Highly Available Wide Area Network Design**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2042)
    *   IP SLA とトラッキングを用いた設計ベストプラクティス。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE ラボ試験におけるトラッキング技術の重要性。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Configuring Enhanced Object Tracking**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipapp/configuration/xe-17/ipapp-xe-17-book/ipapp-eot.html)。
*   [**IP SLAs Configuration Guide, Cisco IOS XE**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipsla/configuration/xe-17/sla-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Reliable Static Routing with IP SLA (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200785-Configure-IP-SLA-ICMP-Echo.html)。
*   [**HSRP Tracking and Preemption Examples**](https://www.cisco.com/c/en/us/support/docs/ip/hot-standby-router-protocol-hsrp/10583-62.html)。

---

## 📝 補足
- この学習メモは、CCIE EI ラボ試験における **「動的なネットワーク適応能力」** の構築を網羅しています。試験では、**`show track`** の結果を正確に読み解き、なぜパスが切り替わった（あるいは切り替わらなかった）のかを論理的に説明できることが合格への近道です。


