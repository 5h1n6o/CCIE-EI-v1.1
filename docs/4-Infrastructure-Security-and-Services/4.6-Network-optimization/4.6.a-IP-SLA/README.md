---
layout: default
title: 4.6.a-IP-SLA
parent: 4.6-Network-optimization
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.6.a IP SLA (ICMP, UDP, TCP probes)

Cisco IOS XE における **IP SLA (IP Service Level Agreements)** は、ネットワークの可用性やパフォーマンスを能動的に監視するための極めて重要なツールです。CCIE Enterprise Infrastructure (EI) ラボ試験では、単体での設定のみならず、オブジェクトトラッキングと組み合わせてルーティングのパス選択を動的に変更する「インテリジェントなインフラ構成」の一部として頻出します。

---

## 📘 概要

**IP SLA** は、Cisco デバイスに組み込まれたアクティブなネットワーク監視機能です。実際のユーザートラフィックを模倣した合成パケットを生成・送信し、その応答を測定することで、ネットワークのヘルスチェックを行います。

主な測定指標には以下が含まれます：
*   **遅延 (Latency):** パケットの往復時間（RTT）や片道遅延。
*   **ジッター (Jitter):** 遅延のばらつき。
*   **パケット損失 (Packet Loss):** 送受信パケットの欠落。
*   **到達性 (Reachability):** 特定のサービスやホストが利用可能かどうか。

CCIE レベルでは、ICMP エコーだけでなく、L4 プロトコル（UDP/TCP）を用いたより詳細なサービス監視（DNS、HTTP、TCP 接続性など）を、大規模かつ複雑なトポロジーに実装する能力が問われます。

---

## 🔑 要点

### 1. 主要なプローブ（Operation）の種類 (i)

*   **ICMP Echo:** 最も基本的な形式。送信先への Ping 応答を測定し、単純な L3 到達性を確認します。
*   **UDP Jitter:** 連続した UDP パケットを送信し、遅延、ジッター、パケット損失を詳細に分析します。主に VoIP 品質（Mean Opinion Score: MOS）のシミュレーションに使用されます。
*   **TCP Connect:** 特定の TCP ポート（例：80 番、443 番、23 番）への接続試行を行います。単なる IP レベルの到達性ではなく、Web サーバーなどのアプリケーション層が応答可能かを監視します。

### 2. IP SLA のライフサイクル

1.  **オペレーションの定義:** プローブの種類と宛先を指定。
2.  **パラメータの設定:** 頻度（Frequency）、タイムアウト（Timeout）、しきい値（Threshold）を構成。
3.  **スケジューリング:** オペレーションの開始時刻と実行時間を設定（`start-time`、`life`）。
4.  **トラッキング連携:** 測定結果を `track` オブジェクトと紐付け、結果に応じてルーティング（Static Route, PBR）や冗長化（FHRP）を切り替えます。

### 3. IP SLA レスポンダ

UDP や TCP の一部の測定（特にジッターや精密な遅延測定）では、受信側のデバイスで `ip sla responder` を有効にする必要があります。これにより、受信デバイス側でのパケット処理時間を測定結果から排除し、正確なネットワーク遅延のみを算出できます。

---

## 🎯 試験対策 (CCIE EIレベル)

CCIE ラボ試験では、以下のシナリオが頻出するため、正確なコマンド入力と検証スキルが求められます。

### 1. フローティングスタティックルートの自動切り替え

特定の宛先へのデフォルトルートが複数ある場合、IP SLA で ISP 側ゲートウェイの先（例：DNS サーバー 8.8.8.8）を監視し、応答が途切れたらメインルートを削除してバックアップに切り替える構成です。

### 2. PBR (Policy Based Routing) との連携

「特定の重要トラフィック（音声等）は常に低遅延なパスを通し、IP SLA で遅延がしきい値を超えた場合のみ別パスへ迂回させる」といった要件が出題されます。

### 3. HSRP/VRRP のプライオリティ減算

外部接続の障害を IP SLA で検知し、`track` オブジェクトを介して HSRP のプライオリティを下げ、Active ルータを自動的に切り替える（Failover）構成が典型的な課題です。

### 4. 複数プールの条件監視（Track List）

「A または B どちらかの IP SLA が失敗したら DOWN とみなす」といった論理演算（OR/AND）を含むトラックリストの作成が問われることがあります。

---

## 🛠 設定・検証コマンド

### IP SLA 基本設定

| 目的 | コマンド |
| :--- | :--- |
| **オペレーションの作成(ICMP)** | <code>ip sla [ID]</code> <br> <code> icmp-echo [DEST_IP] source-ip [SRC_IP]</code> |
| **オペレーションの作成(TCP)** | <code>ip sla [ID]</code> <br> <code> tcp-connect [DEST_IP] [PORT]</code> |
| **実行頻度の設定 (秒単位)** | <code>frequency [SECONDS]</code> |
| **応答待ち時間の設定 (ms単位)** | <code>timeout [MILLISECONDS]</code> |
| **スケジュールの実行** | <code>ip sla schedule [ID] life [forever&#124;seconds] start-time [now&#124;hh:mm]</code> |

### トラッキング連携・その他

| 目的 | コマンド |
| :--- | :--- |
| **オブジェクトの作成** | <code>track [TRACK_ID] ip sla [SLA_ID] reachability</code> |
| **スタティックルートへの適用** | <code>ip route [NET] [MASK] [NH_IP] track [TRACK_ID]</code> |
| **レスポンダの有効化 (受信側)** | <code>ip sla responder</code> |

### 検証・統計

| 目的 | コマンド |
| :--- | :--- |
| **SLA構成のサマリ確認** | <code>show ip sla summary</code> |
| **最新の測定結果を表示** | <code>show ip sla statistics [ID]</code> |
| **詳細な構成情報の表示** | <code>show ip sla configuration [ID]</code> |
| **トラッキング状態の確認** | <code>show track [ID]</code> |

---

## 🧪 ラボ学習・設定サンプル例

### 1. 基本的な ICMP 到達性監視

**【要件】** 宛先 10.1.69.9 に対し、10 秒おきに Ping 監視を行い、無期限に実行せよ。
```ios
ip sla 2
 icmp-echo 10.1.69.9
 frequency 10
ip sla schedule 2 life forever start-time now
```


---

### 2. TCP ポート 80 (HTTP) のサービス監視

**【要件】** Web サーバー 172.16.1.100 のポート 80 が応答するか監視せよ。
```ios
ip sla 10
 tcp-connect 172.16.1.100 80
 frequency 30
ip sla schedule 10 life forever start-time now
```

---

### 3. IP SLA とスタティックルートの紐付け

**【要件】** 8.8.8.8 への到達性が失われたら、デフォルトルート 10.1.1.2 を無効化せよ。
```ios
ip sla 1
 icmp-echo 8.8.8.8
 frequency 5
ip sla schedule 1 life forever start-time now
!
track 1 ip sla 1 reachability
!
ip route 0.0.0.0 0.0.0.0 10.1.1.2 track 1
```

---

### 4. UDP Jitter による VoIP 品質監視

**【要件】** 宛先 10.2.2.2 への UDP ジッターを測定せよ。
```ios
ip sla 20
 udp-jitter 10.2.2.2 16384 num-packets 20
 frequency 60
ip sla schedule 20 life forever start-time now
! 受信側ルータで "ip sla responder" が必要
```

---

### 5. 送信元インターフェイスを指定した監視

**【要件】** Loopback 0 を送信元として 192.168.10.1 を監視せよ。
```ios
ip sla 5
 icmp-echo 192.168.10.1 source-interface Loopback0
 frequency 10
ip sla schedule 5 life forever start-time now
```

---

### 6. タイムアウトとしきい値のカスタマイズ

**【要件】** 応答が 500ms を超えたら異常とみなし、2 秒待っても応答がなければタイムアウトとせよ。
```ios
ip sla 100
 icmp-echo 10.5.5.5
 threshold 500
 timeout 2000
ip sla schedule 100 life forever start-time now
```

---

### 7. HSRP トラッキングによる切り替え

**【要件】** 外部監視用 SLA が失敗した場合、HSRP のプライオリティを 20 減算せよ。
```ios
track 10 ip sla 1 reachability
!
interface GigabitEthernet0/1
 standby 1 track 10 decrement 20
```


---

### 8. 複数の SLA を組み合わせた論理トラック (Track List)

**【要件】** 2 つの ISP 監視 (SLA 1, SLA 2) のうち、両方が失敗した時のみ DOWN と判定せよ。
```ios
track 100 list boolean and
 object 1
 object 2
! 1 と 2 は個別の IP SLA に紐付いた track オブジェクト
```

---

### 9. オブジェクトの状態遅延 (Delay) 設定

**【要件】** SLA が復旧しても、フラッピング防止のため 30 秒待ってから UP 状態に戻せ。
```ios
track 1 ip sla 1 reachability
 delay up 30
```

---

### 10. DNS 解決サービスの監視

**【要件】** DNS サーバー 10.1.1.1 が "cisco.com" を解決できるか監視せよ。
```ios
ip sla 30
 dns 10.1.1.1 name www.cisco.com
 frequency 60
ip sla schedule 30 life forever start-time now
```

---

### 11. IP SLA パケットのデータサイズ指定

**【要件】** ネットワークの負荷耐性を測るため、1000 バイトのデータサイズで Ping を送信せよ。
```ios
ip sla 2
 icmp-echo 10.1.69.9
  request-data-size 1000
ip sla schedule 2 life forever start-time now
```


---

### 12. PBR (Policy Based Routing) での SLA 利用

**【要件】** 10.1.1.1 への到達性がある場合のみ、特定のトラフィックをそのネクストホップへ転送せよ。
```ios
track 50 ip sla 5 reachability
!
route-map PBR_SLA permit 10
 match ip address 101
 set ip next-hop verify-availability 10.1.1.1 1 track 50
```

---

## 📘 参考リソースリンク

### CiscoLive (動画・スライド)
*   [**DGTL-BRKRST-2042: Highly Available Wide Area Network Design**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKRST-2042) - IP SLA とトラッキングを用いた設計。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385) - CCIE 試験におけるネットワーク最適化ツールの重要性。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: IP SLAs Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipsla/configuration/xe-17/sla-xe-17-book.html)。
*   [**Configuring Enhanced Object Tracking**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/ipapp/configuration/xe-17/ipapp-xe-17-book/ipapp-eot.html)。

### テクニカルドキュメント・設定例
*   [**IP SLAs ICMP Echo Operation (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200785-Configure-IP-SLA-ICMP-Echo.html)。
*   [**Reliable Static Routing with IP SLA (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ip/ip-routing/200785-Configure-IP-SLA-ICMP-Echo.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 試験合格に必要な **「監視と動的アクションの統合」** に焦点を当てています。ラボ試験では、設定後に **`show track`** コマンドで状態が `Up` になっているか、そしてインターフェイスの `shutdown` などで意図した通りに状態が切り替わるかを必ず確認してください。


