# 1.2.j Bidirectional Forwarding Detection

本ページでは、CCIE Enterprise Infrastructure (EI) v1.1 Practical Lab 試験および筆記試験における超高速障害検知（Sub-Second Convergence）の要となる **Bidirectional Forwarding Detection (BFD)** について、Cisco IOS-XE 17.x（Catalyst 9000シリーズ、Catalyst 8000v等）の実装基準に100%準拠した、Expertレベルの学習メモを記述します。

---

## 📘 概要

**Bidirectional Forwarding Detection (BFD: RFC 5880 / RFC 5881 / RFC 5882 / RFC 5883)** は、2台の隣接するルータ/スイッチ間の転送パス（フォワーディングプレーン）における物理的または論理的なリンク障害を、**ミリ秒単位（Sub-Second / Millisecond）** で動的に検出するための標準化プロトコルです。

通常、OSPF、EIGRP、BGP、IS-IS などのダイナミックルーティングプロトコルや、HSRP、VRRP などのファーストホップ冗長プロトコル（FHRP）は、独自のハローパケット（Keepalive）を定期送信して隣接関係（Adjacency）を監視しています。しかし、これらのコントロールプレーンパケットの送信周期は最小でも 1 秒（BGP では数十秒〜数分）であり、タイマーが満了して障害を検知するまでに数秒から数分の遅延が発生します。

また、間に L2 スイッチやメディアコンバータ、WAN 回線網が介在するイーサネット環境では、遠隔地の物理リンク切断（Physical Link Down）が自機のローカルインターフェイスに直接伝搬しない「サイレント障害」が発生します。BFD は、ルーティングプロトコルに依存しない単一かつ軽量な検知プロトコルとして機能し、障害検知を**最速 50ms〜300ms** 程度で完了させ、登録されたクライアントプロトコル（OSPF, EIGRP, BGP, Static Route, HSRP 等）へ即座に通知して高速コンバージェンス（Fast Convergence）を実現します。

---

## 🔑 要点

| 項目 | 内容 |
| :--- | :--- |
| **特徴** | 媒体（Ethernet, Serial, GRE, DMVPN, VxLAN）やL3プロトコルに依存しない軽量な固定ヘッダーパケット（UDP）による両方向障害監視。 |
| **用途** | OSPF / EIGRP / BGP / IS-IS / Static Route / HSRP / VRRP / PBR / MPLS-TE の障害検知高速化。 |
| **メリット** | ・プロトコルごとのタイマー調整（OSPF Hello/Dead短縮等）によるCPU負荷バーストを回避。<br>・データプレーン（ASIC/Hardware）オフロードに対応し、超高速検知（例: 50ms×3＝150ms）を実現。<br>・標準規格（RFC）のため他社ベンダー機器（Arista, Juniper, Fortinet等）との間で完全な相互運用が可能。 |
| **デメリット** | ・ネットワーク瞬断や過剰なジッター（Jitter）により、誤検知によるフラッピング（Flapping）を引き起こすリスク。<br>・Echoモード使用時、uRPF（Unicast Reverse Path Forwarding）やインバウンドACLでEchoパケット（UDP 3785）が破棄されるトラブルが発生しやすい。 |
| **対応機種** | Cisco Catalyst 9000 シリーズ, Catalyst 8000v, ISR4000 シリーズ, ASR1000 シリーズ等（Cisco IOS-XE 17.x）。 |
| **制限事項** | ・マルチホップBFD（Multi-hop BFD）はUDPポート 4784、シングルホップBFD（Single-hop BFD）はUDPポート 3784（Control）/ 3785（Echo）を使用。<br>・ハードウェアオフロード（Hardware Offload）可能なセッション数はASICアーキテクチャ（UADP等）に依存。 |
| **設計上の注意点** | ・`bfd-template` を用いた共通パラメータ管理が IOS-XE のベストプラクティス。<br>・OSPF BFD Strict-Mode（RFC 5882）を有効化し、BFD セッションが確率するまで OSPF アジャセンシー形成をブロックする。 |

---

## 🏗 動作原理

### 1. BFD のアーキテクチャ（Single-Hop vs Multi-Hop, Control vs Echo）

BFD パケットには、大きく分けて **Control パケット** と **Echo パケット** の2種類が存在します。

```text
[ Single-Hop BFD アーキテクチャ ]

    +-------------------+                       +-------------------+
    |   Router A (R1)   |                       |   Router B (R2)   |
    |                   |                       |                   |
    |  Control Plane    |                       |  Control Plane    |
    |   (OSPF/BGP/BFD)  |                       |   (OSPF/BGP/BFD)  |
    +---------+---------+                       +---------+---------+
              |                                           |
    ----------+-------------------------------------------+----------
              |                                           |
    +---------+---------+                       +---------+---------+
    |    Data Plane     |                       |    Data Plane     |
    |  (ASIC / Forward) |                       |  (ASIC / Forward) |
    +----+---------+----+                       +----+---------+----+
         |         |                                 |         |
         |         +=== BFD Control Packet (UDP 3784) ===+         |
         |              (両端のCP間で状態とパラメータをネゴ)              |
         |                                                     |
         +== BFD Echo Packet (UDP 3785: 自IP宛) ===============+
             (R1が送出したパケットをR2のData Planeが即座に折り返し)
```

*   **BFD Control パケット (UDP Port 3784 / Multi-Hop: 4784):**
    *   両端のデバイス間で BFD セッション（Down ➔ Init ➔ Up）を確立・維持し、タイマー値（Desired Min TX, Required Min RX, Detect Multiplier）を動的にネゴシエーションします。
*   **BFD Echo パケット (UDP Port 3785):**
    *   送信元ルータ（R1）が、宛先 IP アドレスを**「自機の IP アドレス」**に設定した UDP パケットを対向ルータ（R2）へ送信します。
    *   対向ルータ R2 は、このパケットをコントロールプレーン（CPU）へ上げることなく、**データプレーン（ASIC/FIB）レベルでそのまま R1 へルーティングして折り返し（Loopback）** します。
    *   これにより、対向ルータの CPU 負荷に影響されず、ハードウェアレベルで最速の往復遅延・障害検知（50ms以下）が可能になります。

---

### 2. タイマーネゴシエーションと障害検知時間の算出

BFD では、自身が希望するパケット送信間隔（`Desired Min TX`）と、自身が受信可能な最小パケット間隔（`Required Min RX`）、および障害とみなす連続損失回数（`Detect Multiplier`）を持ちます。

*   **実際のパケット送信間隔 (TX Interval):**
    $$	ext{Actual TX} = \max(	ext{Local Desired Min TX}, 	ext{Remote Required Min RX})$$
*   **実際の障害検知時間 (Detection Time):**
    $$	ext{Detection Time} = 	ext{Remote Detect Multiplier} 	imes \max(	ext{Remote Desired Min TX}, 	ext{Local Required Min RX})$$

**【タイマー計算例】**
*   **Router A:** TX = 100ms, RX = 100ms, Multiplier = 3
*   **Router B:** TX = 200ms, RX = 200ms, Multiplier = 4
*   **A ➔ B のパケット送信間隔:** $\max(100	ext{ms}, 200	ext{ms}) = 200	ext{ms}$
*   **Router B の障害検知時間:** $4 	imes \max(100	ext{ms}, 200	ext{ms}) = 800	ext{ms}$

---

## ⚙ 動作シーケンス

```text
[ ステップ 1: BFD セッションの初期化 (3-Way Handshake) ]
  R1 (State: Down) ─── BFD Control (Init) ───► R2 (State: Down)
  R1 (State: Init) ◄─── BFD Control (Init) ─── R2 (State: Init)
  R1 (State: Up)   ─── BFD Control (Up)   ───► R2 (State: Up)
  * BFD セッションが「UP」ステートへ遷移。

[ ステップ 2: クライアントプロトコルとのバインディング ]
  OSPF / EIGRP / BGP が BFD セッションの「UP」を検知し、アジャセンシーを正常維持。
  同時に BFD Echo パケット (UDP 3785) の高速ループバック送信を開始。

[ ステップ 3: リンク/パス障害の発生 ]
  中継 L2 網または物理リンクで障害発生。BFD Echo / Control パケットが不達となる。

[ ステップ 4: BFD タイムアウトと障害通知 ]
  Detection Time (例: 100ms × 3 = 300ms) が経過。
  BFD プロセスがセートを「Down」に変更。
  即座に内部シグナル（Event Notification）を登録クライアント（OSPF/BGP等）へ発行。

[ ステップ 5: 高速コンバージェンス ]
  ・OSPF: 即座に Neighbor 状態を Down にし、SPF（Shortest Path First）計算を実行。
  ・BGP: Hold Timer (180s) の満了を待たずに即座に BGP セッションを破棄し、代替パスへ迂回。
```

---

## 🎯 試験対策（CCIE EIラボ試験）

CCIE EI Practical Lab 試験において、BFD は単体で出題されるだけでなく、**「OSPF/EIGRP/BGP の高速切り替え要求」** や **「IP SLA/Static Route との結合」**、**「uRPF 併用時の BFD トラブルシューティング」** の文脈で複合的に出題されます。

### 1. BFD Template（現代の標準設定手法） vs クラシック設定

IOS-XE 17.x では、インターフェイス配下で直接指定する旧来のコンフィグ（`bfd interval ...`）よりも、グローバルで定義する **`bfd-template`** の利用が強く推奨・出題されます。

*   **テンプレート定義:**
    ```bash
    bfd-template single-hop BFD_100MS
     interval min-tx 100 min-rx 100 multiplier 3
    ```
*   **インターフェイス側でのバインド:**
    ```bash
    interface GigabitEthernet1/0/1
     bfd template BFD_100MS
    ```

### 2. OSPF BFD Strict-Mode (RFC 5882) の重要性

*   **問題の背景:** 通常の OSPF BFD 構成では、OSPF ハローによって 2-Way / FULL 状態が形成された**後**に BFD セッションが起動します。しかし、何らかの理由で BFD ネゴシエーションが失敗した場合、OSPF はフラッピングを繰り返したり、BFD 保護がない状態で動作し続けます。
*   **Strict-Mode の動作:** `bfd strict-mode` を設定すると、**BFD セッションが正常に「UP」状態になるまで、OSPF はアジャセンシー（FULL）を形成させません**。
*   **設定コマンド:**
    ```bash
    router ospf 1
     bfd all-interfaces
     bfd strict-mode
    ```

### 3. Echo モードと uRPF（Unicast Reverse Path Forwarding）の競合トラップ

*   **ラボ試験の定番トラップ:**
    「インターフェイスで `ip verify unicast source reachable-via rx` (uRPF) または厳格なインバウンド ACL を有効化したところ、BFD セッションが DOWN し、BGP/OSPF ネイバーが維持できなくなった」
*   **原因:** BFD Echo パケットは、**送信元 IP も宛先 IP も「自ルータの IP アドレス」** で送出され、対向ルータで折返されます。対向ルータの uRPF 判定エンジンは、「自ルータ宛てのパケットが外部インターフェイスから入ってきた」と判定し、スプーフィンパケットとみなして**物理 ASIC レベルでドロップ**します。
*   **回避策:**
    1.  対向ポートで BFD Echo を無効化する: `no bfd echo`（Control パケットのみで監視）。
    2.  Echo パケットの送信元 IP を専用の Loopback インターフェイス等に変更する: `bfd echo-source loopback 0`。

### 4. Static Route への BFD バインディング（Unassociated BFD）

スタティックルートのネクストホップ障害を検知する場合、ネクストホップ IP アドレスに対して直接 BFD セッションを確立します。

```bash
# ネクストホップ 10.1.12.2 に対する Unassociated BFD セッションの起動
ip route static bfd GigabitEthernet1/0/1 10.1.12.2
ip route 0.0.0.0 0.0.0.0 GigabitEthernet1/0/1 10.1.12.2
```

---

## 🛠 設定方法

### 1. 基本的な BFD テンプレートと OSPFv2 / OSPFv3 統合

```bash
# 1. BFD テンプレートの作成
bfd-template single-hop FAST_BFD
 interval min-tx 50 min-rx 50 multiplier 3
exit

# 2. インターフェイスへの適用と OSPF 統合
interface GigabitEthernet1/0/1
 ip address 10.1.12.1 255.255.255.252
 bfd template FAST_BFD
 ip ospf bfd
exit

# 3. OSPF プロセス全体での一括有効化と Strict-Mode 適用
router ospf 1
 router-id 1.1.1.1
 bfd all-interfaces
 bfd strict-mode
```

### 2. EIGRP Named Mode における BFD 設定

```bash
router eigrp CCIE_DOMAIN
 !
 address-family ipv4 autonomous-system 100
  !
  af-interface default
   # 全インターフェイスで BFD を有効化
   bfd
  exit
  !
  af-interface GigabitEthernet1/0/1
   # 特定のポートのみ BFD パラメータを個別チューニング
   bfd
  exit
  topology base
  exit
 exit
```

### 3. BGP Single-Hop / Multi-Hop BFD 設定

```bash
router bgp 65001
 bgp router-id 1.1.1.1
 neighbor 10.1.12.2 remote-as 65002
 # シングルホップ eBGP ネイバーへの BFD 統合
 neighbor 10.1.12.2 fall-over bfd
 
 neighbor 10.255.255.2 remote-as 65001
 neighbor 10.255.255.2 update-source Loopback0
 # マルチホップ iBGP ネイバーへの BFD テンプレート適用
 neighbor 10.255.255.2 fall-over bfd multi-hop template FAST_BFD
```

### 4. スタティックルート BFD (Static Route BFD)

```bash
# インターフェイス指定の Static Route に対する BFD 適用
ip route static bfd GigabitEthernet1/0/1 10.1.12.2

# スタティックデフォルトルートの定義
ip route 0.0.0.0 0.0.0.0 GigabitEthernet1/0/1 10.1.12.2
```

### 5. Echo 源インターフェイスの指定および BFD Echo の無効化

```bash
# Echo パケットの送信元 IP アドレスを Loopback 0 に固定
bfd echo-source loopback 0

# インターフェイス単位での BFD Echo モード無効化（Control パケットのみで動作）
interface GigabitEthernet1/0/1
 no bfd echo
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| :--- | :--- |
| **BFD セッション一覧、ステート（UP/DOWN）、ネイバーIP、インターフェイス確認** | <code>show bfd neighbors</code> |
| **BFD セッションの詳細パラメータ（ネゴシエーションされたTX/RX、タイマー、Echo状態等）確認** | <code>show bfd neighbors details</code> |
| **BFD セッションに登録されているクライアントプロトコル（OSPF, BGP等）の確認** | <code>show bfd neighbors client</code> |
| **BFD テンプレート（Template）の定義内容一覧確認** | <code>show bfd template</code> |
| **OSPF インターフェイスごとの BFD 動作ステータス確認** | <code>show ip ospf interface GigabitEthernet1/0/1</code> |
| **BGP ネイバーごとの BFD Fall-over 状態確認** | <code>show ip bgp neighbors 10.1.12.2</code> |
| **BFD イベント、状態遷移（State Machine）、ネゴシエーションのリアルタイムデバッグ** | <code>debug bfd event</code> / <code>debug bfd packets</code> |

---

## 🚨 トラブルシューティング

| 症状 | 原因 | 確認コマンド | 対処方法 |
| :--- | :--- | :--- | :--- |
| **`show bfd neighbors` でステートが `ADMIN_DOWN` または `DOWN` から変遷しない。** | 1. 物理リンクの導通障害。<br>2. BFD Control パケット（UDP 3784）が ACL で遮断されている。<br>3. 対向機器側で BFD が有効化されていない。 | `show bfd neighbors details`<br>`show ip access-lists` | 1. 物理リンクおよび L3 パスを確認。<br>2. UDP 3784 / 3785 パケットを許可するように ACL を修正。<br>3. 対向機器の BFD 構成を確認。 |
| **uRPF または ACL を追加設定した直後に BFD セッションが DOWN する。** | **uRPF / ACL による BFD Echo パケット（UDP 3785）のドロップ。** Echo パケットの送信元/宛先が自 IP のため、uRPF 違反として破棄される。 | `show bfd neighbors details`<br>`show ip interface <int> | inc rpf` | 対向インターフェイスで `no bfd echo` を設定して Control パケットのみに移行するか、`bfd echo-source loopback 0` を指定する。 |
| **BFD セッションが頻繁に UP / DOWN を繰り返す（Flapping）。** | ネゴシエーションされたタイマー値（例: 50ms × 3 = 150ms）が過激すぎ、ネットワークの遅延・ジッターや CPU 負荷に耐えられていない。 | `show bfd neighbors details`<br>`show processes cpu` | `bfd-template` の `interval` タイマー（min-tx / min-rx）を 100ms〜300ms 程度に緩和するか、Multiplier を 3 ➔ 5 に引き上げる。 |
| **OSPF アジャセンシーが確立しない（Init / ExStart で停止）。** | OSPF に `bfd strict-mode` が設定されているが、BFD セッション自体が確立（UP）していない。 | `show ip ospf bfd`<br>`show bfd neighbors` | BFD セッションが DOWN している根本原因（IP 導通、ACL、タイマー不一致等）を特定して解消する。 |

---

## ⚠ 制限事項

### 1. サポートされる BFD セッション数と ASIC オフロード制限
*   Catalyst 9000 シリーズ（UADP ASIC）や ASR1000 シリーズにおいて、ハードウェア処理（ASIC Offload）可能な BFD セッション数には上限があります。上限を超えたセッションは CPU（Software）処理へフォールバックし、CPU 高騰やタイマー精度低下を引き起こします。

### 2. Multi-Hop BFD の機能制限
*   Multi-Hop BFD（RFC 5883 / UDP 4784）では、**Echo モード（UDP 3785）はサポートされません**。Control パケットのみでの監視となります。

### 3. IPv6 と BFD
*   IPv6 環境で BFD を動作させる場合、BFD セッションは基本的に**リンクローカルアドレス（FE80::/10）** を使用してネゴシエーションされます。

---

## 🔄 他技術との関連

*   **OSPF / EIGRP / BGP / IS-IS:** BFD が障害を検出すると、コントロールプレーンの Keepalive タイマー（OSPF Dead Timer 等）の満了を待たずに即座にアジャセンシーを「DOWN」とし、SPF 計算や BGP パス再計算を起動します。
*   **HSRP / VRRP (FHRP):** 第一ホップルータ間で BFD を有効化することで、アクティブルータの物理障害をミリ秒単位で検知し、スタンバイルータがサブ秒で Virtual IP を引き継ぎます（`standby bfd`）。
*   **IP SLA / Object Tracking:** IP SLA トラックオブジェクトと BFD を結合することで、ネクストホップへの到達性をミリ秒単位で追跡し、PBR（Policy-Based Routing）や Static Route のパス切り替えを高速化します。
*   **LACP (Micro-BFD):** EtherChannel（Port-Channel）を構成する個々の物理メンバーリンク単位で Micro-BFD（IEEE 802.1AX-2014）を動かし、特定の物理リンク障害を検知して瞬時にチャネルから除外します。

---

## 🧩 比較表

### 1. Routing Protocol タイマー vs BFD タイマー

| 比較要素 | プロトコル標準タイマー (OSPF / BGP) | BFD (Bidirectional Forwarding Detection) |
| :--- | :--- | :--- |
| **障害検知時間** | 数秒 〜 数分 (OSPF: 40秒, BGP: 180秒) | **ミリ秒単位 (50ms 〜 300ms)** |
| **CPU 処理負荷** | パケット送信周期を短縮（1秒以下）すると CPU 負荷が激増 | **非常に軽量**（ASIC/Data Plane オフロード対応） |
| **適用範囲** | 各プロトコル個別にタイマー設定が必要 | **単一の BFD セッション** を複数のプロトコルで共有可能 |
| **Echo モード** | サポートなし | **サポート**（対向 CPU を介さずデータプレーンで即時折り返し） |

---

## 💡 ベストプラクティス

1.  **`bfd-template` の活用:** インターフェイス単位での個別設定を避け、`bfd-template single-hop` を定義して運用・管理を一元化します。
2.  **適切なタイマー設計:** エンタープライズキャンパス網では `interval min-tx 100 min-rx 100 multiplier 3`（検知時間 300ms）を標準設計とします。過度に短いタイマー（例: 10ms）は網のジッターによる誤検知を招きます。
3.  **OSPF Strict-Mode の有効化:** OSPF 運用環境では `bfd strict-mode` を適用し、BFD 保護がない不完全なアジャセンシー形成を未然に防止します。
4.  **uRPF 併用時の `no bfd echo` または `bfd echo-source` 設定:** セキュリティ上 uRPF やインバウンド ACL が有効な環境では、Echo パケットのドロップを避けるため適切な回避策を講じます。

---

## 📝 ラボ学習・設定サンプル例

### 1. 【基本設定】BFD テンプレートと OSPFv2 シングルホップ統合
**【問題】**
R1 と R2 の間の接続（`GigabitEthernet1/0/1`）において、BFD テンプレート `BFD_CORE`（送信 100ms、受信 100ms、Multiplier 3）を作成して適用し、OSPF プロセス 1 全体で BFD を有効化してください。また、BFD セッションが確立するまで OSPF アジャセンシーの形成を阻止する安全機能を適用してください。

**【R1 設定】**
```bash
R1# configure terminal
# 1. BFD テンプレートの定義
bfd-template single-hop BFD_CORE
 interval min-tx 100 min-rx 100 multiplier 3
exit

# 2. インターフェイスへの適用
interface GigabitEthernet1/0/1
 ip address 10.1.12.1 255.255.255.252
 bfd template BFD_CORE
exit

# 3. OSPF への一括適用および Strict-mode 有効化
router ospf 1
 router-id 1.1.1.1
 network 10.1.12.0 0.0.0.3 area 0
 bfd all-interfaces
 bfd strict-mode
end
```

**【検証方法】**
```bash
R1# show bfd neighbors details
R1# show ip ospf bfd
```

---

### 2. 【EIGRP Named Mode】EIGRP への BFD 統合
**【問題】**
R1 において、EIGRP Named Mode インスタンス `EIGRP_NET`（AS 100）配下の全インターフェイスで BFD を有効化し、`GigabitEthernet1/0/2` のみ BFD テンプレート `BFD_FAST`（送信 50ms、受信 50ms、Multiplier 3）を割り当ててください。

**【R1 設定】**
```bash
R1# configure terminal
bfd-template single-hop BFD_FAST
 interval min-tx 50 min-rx 50 multiplier 3
exit

interface GigabitEthernet1/0/2
 bfd template BFD_FAST
exit

router eigrp EIGRP_NET
 !
 address-family ipv4 autonomous-system 100
  !
  af-interface default
   bfd
  exit
  !
  af-interface GigabitEthernet1/0/2
   bfd
  exit
  topology base
  exit
 exit
end
```

---

### 3. 【BGP Single-Hop】eBGP ネイバーへの BFD 送信
**【問題】**
R1（AS 65001）と対向 ISP ルータ R2（10.1.12.2 / AS 65002）間の eBGP セッションにおいて、BFD による高速フォールオーバーを有効化してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/1
 ip address 10.1.12.1 255.255.255.252
# インターフェイスレベルでクラシック BFD タイマー（100ms / 100ms / 3）を設定
 bfd interval 100 min_rx 100 multiplier 3
exit

router bgp 65001
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 fall-over bfd
end
```

---

### 4. 【BGP Multi-Hop】iBGP ループバック間 Multi-Hop BFD
**【問題】**
R1（1.1.1.1）と R3（3.3.3.3）間の Multi-Hop iBGP セッションにおいて、Multi-Hop BFD テンプレート `BFD_MH`（送信 200ms、受信 200ms、Multiplier 4）を作成して BFD フォールオーバーを構成してください。

**【R1 設定】**
```bash
R1# configure terminal
# Multi-hop 専用テンプレートの作成
bfd-template multi-hop BFD_MH
 interval min-tx 200 min-rx 200 multiplier 4
exit

router bgp 65001
 neighbor 3.3.3.3 remote-as 65001
 neighbor 3.3.3.3 update-source Loopback0
 neighbor 3.3.3.3 fall-over bfd multi-hop template BFD_MH
end
```

---

### 5. 【Static Route BFD】Unassociated BFD によるデフォルトルート監視
**【問題】**
R1 から R2（10.1.12.2）経由のスタティックデフォルトルートを構成し、ネクストホップ 10.1.12.2 への BFD 監視を有効化してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/1
 ip address 10.1.12.1 255.255.255.252
 bfd interval 100 min_rx 100 multiplier 3
exit

# スタティックルート用 BFD セッションの登録
ip route static bfd GigabitEthernet1/0/1 10.1.12.2
ip route 0.0.0.0 0.0.0.0 GigabitEthernet1/0/1 10.1.12.2
end
```

---

### 6. 【トラブル回避】uRPF 導入環境における `no bfd echo` 設定
**【問題】**
R1 の `GigabitEthernet1/0/1` で uRPF 厳格モード（Strict Mode）を有効化したところ、R2 との BFD セッションが不通となりました。BFD Control パケットのみ（Echo 無効化）で監視するように R1/R2 を修正してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/1
 ip verify unicast source reachable-via rx
# BFD Echo パケットの送信・ループバック応答を停止
 no bfd echo
exit
end
```

---

### 7. 【Echo 源変更】`bfd echo-source` による送信元 IP の変更
**【问题】**
BFD Echo パケットの送信元 IP アドレスがインターフェイス個別 IP になることを避け、`Loopback0`（1.1.1.1）のアドレスを送信元として使用するようにグローバルで変更してください。

**【R1 設定】**
```bash
R1# configure terminal
bfd echo-source loopback 0
end
```

---

### 8. 【FHRP 統合】HSRP 高速障害検知への BFD 適用
**【問題】**
R1（HSRP Active）と R2（HSRP Standby）間の `GigabitEthernet1/0/10`（VLAN 10）において、HSRP グループ 10 の障害検知をミリ秒単位にするため BFD を統合してください。

**【R1 設定】**
```bash
R1# configure terminal
interface GigabitEthernet1/0/10
 ip address 10.1.10.1 255.255.255.0
 bfd interval 100 min_rx 100 multiplier 3
 standby version 2
 standby 10 ip 10.1.10.254
 standby 10 priority 110
 standby 10 preempt
 # HSRP への BFD バインディング
 standby bfd
exit
end
```

---

### 9. 【VRF-Aware BFD】マルチテナント VRF における OSPF BFD
**【問題】**
VRF `RED` に所属する `GigabitEthernet1/0/1.100` 上の OSPFv2 プロセスにおいて BFD を有効化してください。

**【R1 設定】**
```bash
R1# configure terminal
vrf definition RED
 address-family ipv4
exit

interface GigabitEthernet1/0/1.100
 encapsulation dot1Q 100
 vrf forwarding RED
 ip address 10.100.12.1 255.255.255.252
 bfd interval 100 min_rx 100 multiplier 3
 ip ospf bfd
exit

router ospf 100 vrf RED
 router-id 10.100.1.1
 area 0 authentication message-digest
 network 10.100.12.0 0.0.0.3 area 0
 bfd all-interfaces
end
```

---

### 10. 【Micro-BFD】L3 EtherChannel (LACP) ポート毎の BFD 監視
**【問題】**
R1 と R2 の間の L3 Port-Channel 1（構成メンバー: `Gi1/0/1`, `Gi1/0/2`）において、個々の物理メンバーリンク単位で BFD 監視を行う Micro-BFD（LACP）を構成してください。

**【R1 設定】**
```bash
R1# configure terminal
interface Port-channel1
 no switchport
 ip address 10.1.12.1 255.255.255.252
exit

interface range GigabitEthernet1/0/1 - 2
 no switchport
 channel-group 1 mode active
 # LACP ポート単位での Micro-BFD 有効化
 port-channel micro-bfd
 bfd interval 100 min_rx 100 multiplier 3
exit
end
```

---

## ❓ 想定試験問題

### Question 1 (Troubleshooting)
**問題:** 
R1 と R2 間で OSPFv2 と BFD を運用しています。R1 の `GigabitEthernet1/0/1` で `ip verify unicast source reachable-via rx` (uRPF) を有効化した直後、`show bfd neighbors` の出力でステートが `DOWN` に遷移し、OSPF アジャセンシーがダウンしました。パケットキャプチャを確認すると、UDP 3784 の Control パケットは到達していますが、UDP 3785 の Echo パケットがドロップされていました。この現象の技術的原因と、最も迅速な解決策を述べてください。

**解答・解説:**
*   **原因:** BFD Echo パケットは、送信元 IP と宛先 IP の両方に「自ルータの IP アドレス」を設定して送出されます。対向ルータで折返された Echo パケットが R1 の `GigabitEthernet1/0/1` に入ってきた際、uRPF（Strict Mode）は「自ルータの IP が外部インターフェイスから入力された」と判定し、パケットスプーフィンとみなしてドロップします。
*   **解決策:** R1 および R2 の該当インターフェイスで `no bfd echo` を設定して BFD Echo モードを無効化するか、`bfd echo-source loopback 0` を設定して Echo パケットの送信元 IP アドレスを別のアドレスに変更します。

---

### Question 2 (Design)
**問題:** 
大規模な SD-Access アンダーレイ網において、Catalyst 9500 スイッチ間で BFD を導入し、障害検知時間を 150ms に設計しようとしています。CPU 負荷およびネットワークの安定性を担保するためのベストプラクティス構成として、適切な `bfd-template` 定義と OSPF オプションの組み合わせを提示してください。

**解答・解説:**
*   **推奨構成:**
    ```bash
    bfd-template single-hop SDA_UNDERLAY_BFD
     interval min-tx 100 min-rx 100 multiplier 3
    exit

    router ospf 1
     bfd all-interfaces
     bfd strict-mode
    ```
*   **設計根拠:** 
    1. タイマーは `100ms × 3 = 300ms`（または 50ms × 3 = 150ms）に設定し、ASIC ハードウェアオフロードを活用します。
    2. `bfd strict-mode`（RFC 5882）を適用することで、BFD セッションが起動する前に OSPF が誤ってアジャセンシーを確立し、非保護状態で通信が開始されるリスクを完全に遮断します。

---

### Question 3 (Configuration)
**問題:** 
スタティックデフォルトルート `ip route 0.0.0.0 0.0.0.0 192.168.12.2` を運用しているルータにおいて、ネクストホップ `192.168.12.2` に対する BFD 監視を適用し、ネクストホップダウン時にミリ秒単位でルーティングテーブルから自動削除させる設定コマンドを記述してください。

**解答・解説:**
```bash
interface GigabitEthernet1/0/1
 ip address 192.168.12.1 255.255.255.0
 bfd interval 100 min_rx 100 multiplier 3
exit

# スタティックルート用 BFD セッションの結合
ip route static bfd GigabitEthernet1/0/1 192.168.12.2
ip route 0.0.0.0 0.0.0.0 GigabitEthernet1/0/1 192.168.12.2
```

---

## 🔗 参考リソース

### Cisco Live スライド・動画
*   [**BRKCRS-3147: Advanced Troubleshooting of IOS-XE Control and Data Plane**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRS-3147)
*   [**BRKROU-2002: BFD Architecture and Deployment Best Practices**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKROU-2002)

### Cisco ソフトウェア設定ガイド（Configuration Guide）
*   [**Cisco Catalyst 9300 Series Switches: Bidirectional Forwarding Detection Configuration Guide, Cisco IOS XE 17.x**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/configuration_guide/bfd/b_17x_bfd_9300_cg.html)
*   [**Cisco IOS XE 17.x Command Reference: bfd-template, fall-over bfd, bfd strict-mode**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-x/command_reference/b_17x_bfd_9300_cr.html)

---

## 📝 **補足（Notes）**

### BFD デバッグ時の有用ログ例 (`debug bfd event` / `debug bfd packets`)

```text
*Sep 11 08:15:02.123: BFD-EVNT: BFD-Sess: [10.1.12.1, 10.1.12.2, Gi1/0/1, 0] State change: UP -> DOWN, reason: Echo Function Failed
*Sep 11 08:15:02.125: BFD-CLIENT: OSPF-1: BFD session down notification received for 10.1.12.2
*Sep 11 08:15:02.126: %OSPF-5-ADJCHG: Process 1, Nbr 2.2.2.2 on GigabitEthernet1/0/1 from FULL to DOWN, Neighbor Down: BFD session down
```

*   **最終チェック項目:**
    *   [ ] OSPF / EIGRP / BGP で BFD を設定する際、`bfd-template` を正しく定義しているか？
    *   [ ] uRPF や ACL が入っているポートで BFD Echo パケットがドロップしていないか？（`no bfd echo` の検討）
    *   [ ] OSPF 環境で `bfd strict-mode` が構成要求に含まれていないか確認したか？
    *   [ ] スタティックルートに BFD を連動させる際、`ip route static bfd <int> <next-hop>` の定義を忘れていないか？
