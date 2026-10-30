---
layout: default
title: 4.7.a-Traffic-capture
parent: 4.7-Network-operations
grand_parent: 4-Infrastructure-Security-and-Services
nav_order: 1
---

# 4.7.a Traffic capture

## 📘 概要

トラフィックキャプチャ（Traffic Capture）は、ネットワーク内を通過するパケット（フレーム）を直接収集・複製し、障害解析、セキュリティ監査、パフォーマンス分析、およびプロトコル挙動検証に利用する運用診断機能群である。
CCIE EI v1.1 Blueprint においては、スイッチドネットワーク上のローカル/リモートパケット複製技術である **SPAN / RSPAN / ERSPAN** と、ルータ・スイッチの内部バッファ上でパケットをダイレクトにキャプチャ・解析・パケットファイル (.pcap) 保持する **Embedded Packet Capture (EPC)** が対象範囲として指定されている。

これらは、パケットがどのポート・インターフェイス・CPU パイプラインを通過しているかをリアルタイムかつ可視的に特定するために不可欠なツールであり、特にネットワーク不通、遅延高騰、不正通信、ルーティングループ、QoS マークの検証において最大の威力を発揮する。

* **利用目的:** ネットワーク不通、片方向通信、ACL/CoPP ドロップ、QoS タグ変化、認証失敗、プロトコルエラーの現場パケットレベル解析。
* **利用場面:** インフラ障害発生時の不具合箇所の切り分け、外部パケットアナライザ（Wireshark 等）へのミラーリング転送、および外部機器を接続できない環境でのインバンド内蔵キャプチャ (EPC)。

---

## 🔑 要点

| 項目 | SPAN (Local SPAN) | RSPAN (Remote SPAN) | ERSPAN (Encapsulated RSPAN) | EPC (Embedded Packet Capture) |
| --- | --- | --- | --- | --- |
| **特徴** | 同一スイッチ内でのポート/VLAN パケット複製 | 専用 L2 VLAN を介した L2 ドメイン跨ぎ複製 | GRE トンネル (IP 47) による L3 WAN 網跨ぎ遠隔転送 | ルータ/スイッチ内部バッファでのダイレクトキャプチャ |
| **キャプチャ領域** | 同一物理スイッチ / スタック内 | 同一 L2 放送ドメイン内 (Trunk 経由) | 任意の L3 Reachable IPv4/IPv6 ネットワーク | ルータ / スイッチの CPU / ASIC / QFP パイプライン |
| **宛先 (Destination)** | ローカル物理ポート / EtherChannel | 専用 RSPAN VLAN (`remote-span`) | 遠隔 ERSPAN アナライザ (IPv4/IPv6 Address) | 内部 RAM バッファ (`.pcap` / Flash 保存) |
| **追加オーバーヘッド** | なし (0 Bytes) | L2 802.1Q タグ (4 Bytes) | GRE/IP/ERSPAN Header (**50 Bytes**) | なし (メモリ消費のみ) |
| **主な用途** | 直結アナライザによる即座のキャプチャ | 同一拠点内の集約アナライザへの収集 | 地理的に離れた本社/DC アナライザへの集約 | 物理ポート接続不能環境での迅速なオンボード障害解析 |
| **制限事項** | 宛先ポートは通常転送不可 (SPAN 専用) | Trunk 上での RSPAN VLAN 許可が必要 | ルータ CPU / QFP 負荷、MTU フラグメント考慮 | バッファサイズ制限 (DRAM)、CPU/ASIC 負荷 |

---

## 🏗 動作原理

### 1. SPAN / RSPAN / ERSPAN の動作原理

* **SPAN (Local SPAN):**
  スイッチの ASIC ハードウェアスイッチングパイプラインにおいて、Ingress/Egress ポート（または VLAN）を通過するフレームを、スイッチイングテーブル処理と並行して宛先（Destination）ポートへハードウェア複製（Mirroring）する。
* **RSPAN (Remote SPAN):**
  キャプチャしたフレームを特殊な **RSPAN VLAN**（`remote-span` 宣言された VLAN）にアタッチし、L2 Trunk リンク経由で対向スイッチへブロードキャスト転送する。対向スイッチでは RSPAN VLAN をソースとし、ローカルアナライザポートへ転送する。
* **ERSPAN (Encapsulated RSPAN - Type II / Type III):**
  キャプチャした L2 フレーム全体を、**GRE カプセル化 (IP Protocol 47, EtherType 0x88be)** し、L3 ネットワークをルーティングして遠隔地の ERSPAN 宛先（Linux Wireshark サーバ、または Catalyst/ASR ルータ）へ IP パケットとして送信する。

```
[Local SPAN]
Source Port (Gi1/0/1) ───> Switch ASIC ───> Normal Forwarding (Gi1/0/2)
                             │
                             └── (Hardware Copy) ───> Destination Port (Gi1/0/24) ───> Wireshark

[ERSPAN]
Source Port (Gi1/0/1) ───> Switch / Router ───> GRE Encap (IP 47, ERSPAN Header: 50B)
                                                   │
                                                   ▼
                                           L3 IP Network / WAN
                                                   │
                                                   ▼
                                        Destination ERSPAN Collector
```

### 2. EPC (Embedded Packet Capture) の動作原理

* **Control Plane / Data Plane ダイレクト参照:**
  IOS XE の CEF / QFP (Quantum Flow Processor) 転送エンジン、または Control Plane インターフェイスにおいて、パケットのコピーを直接メモリバッファ (DRAM) に書き込む。
* **バッファ構造 (Linear vs Circular):**
  * **Linear Buffer:** バッファが満杯になった時点でキャプチャを自動停止する。
  * **Circular Buffer:** バッファが満杯になると、古いキャプチャデータから上書きして連続監視を行う。

---

## ⚙ 動作シーケンス

### 1. ERSPAN のパケット処理シーケンス

```
1. パケットが Source Port (または Source VLAN) に到着 (Ingress) / 出力 (Egress)
   ↓
2. スイッチ/ルータの ASIC または QFP がパケットを複製
   ↓
3. 複製されたパケットに ERSPAN Header (12 Bytes - Session ID / Timestamp) を付与
   ↓
4. GRE Header (8 Bytes, Protocol 0x88be) および Outer IP Header (20 Bytes) を追加 (合計 50 Bytes オーバーヘッド)
   ↓
5. ルーティングテーブル (FIB) に従って 宛先 IP (ERSPAN Collector) へ向けて L3 転送
   ↓
6. 宛先 Collector (Wireshark 等) が IP/GRE ヘッダーを剥離し、内部の生パケットを記録
```

### 2. EPC のパケットキャプチャシーケンス

```
1. 接続ポイント (Point) とキャプチャバッファ (Buffer) を定義してバインド
   ↓
2. オプションで ACL をバインドし、目的の 5-Tuple パケットのみフィルタリング
   ↓
3. `monitor capture START` コマンドでキャプチャエンジンを活性化
   ↓
4. CEF/QFP 転送処理時に一致するパケットのコピーを DRAM バッファへ格納
   ↓
5. `monitor capture STOP` で停止、CLI 上で直接 Hex/ASCII 表示 または `.pcap` ファイルとして TFTP/FTP エクスポート
```

---

## 🎯 試験対策（CCIE EIラボ試験）

### 1. ラボ試験で頻出の要件と設定ポイント

* **SPAN での 802.1Q VLAN タグ保持:**
  デフォルトの SPAN では、Destination ポートへ転送される際に 802.1Q タグが剥離される。VLAN タグを保持してキャプチャする場合は、`destination interface <INT> encapsulation replicate` コマンドの記述が必須となる。
* **Destination ポートにおける通常トラフィックの送受信 (`ingress vlan`):**
  SPAN 宛先ポートは標準で全入出力がブロックされ SPAN パケット専用となる。アナライザ端末からの管理通信や PC トラフィックを許可する場合は、`destination interface <INT> ingress vlan <VID>` を設定する。
* **RSPAN VLAN の定義漏れ:**
  RSPAN を使用する場合、全中継スイッチ上で対象 VLAN に対して必ず `vlan <VID>` ➔ `remote-span` を明示設定しなければならない。これを怠ると標準 L2 VLAN とみなされ、MAC 学習や MAC フラッディング異常を引き起こす。
* **ERSPAN ヘッダーと MTU サイズ考慮:**
  ERSPAN カプセル化により **50 バイト** の追加ヘッダーが付与されるため、1500 バイトのパケットは 1550 バイトとなる。Path MTU が 1500 の場合、フラグメントが発生するか、DF ビットが立っている場合は即座にドロップされる。
* **EPC のアクセスリスト (ACL) フィルタリング:**
  ACL なしで EPC を起動すると、ルータのコントロールプレーンや高容量データ通信により瞬時にバッファが埋まり、ルータの CPU 負荷を高騰させる。試験では必ず指定の 5-Tuple (例: BGP 179/tcp、OSPF 89/ip) に限定した ACL をバインドする。

### 2. Show コマンドによる状態確認・確認ポイント

* `show monitor session <ID>`: SPAN / RSPAN / ERSPAN セッションの状態（Active/Inactive）、Source/Destination、Session ID、Encapsulation を確認。
* `show monitor capture`: EPC バッファの状態、キャプチャされたパケット数、アタッチされている Point/ACL を確認。
* `show monitor capture buffer <NAME> dump`: EPC バッファ内のパケットを CLI 上で Hex/ASCII ダンプ表示。

---

## 🛠 設定方法

### 1. Local SPAN 設定例 (VLAN タグ保持 ＆ 宛先 Ingress 許可)

```bash
! 1. Source ポートおよび Destination ポートの設定
monitor session 1 source interface GigabitEthernet1/0/1 both
monitor session 1 destination interface GigabitEthernet1/0/24 encapsulation replicate ingress vlan 10
```

### 2. RSPAN 設定例 (SW1: Source, SW2: Destination)

```bash
! 全スイッチ共通: RSPAN VLAN の宣言
vlan 999
 name RSPAN_VLAN
 remote-span

! SW1 (Source Switch)
monitor session 1 source interface GigabitEthernet1/0/1 both
monitor session 1 destination remote vlan 999

! SW2 (Destination Switch)
monitor session 1 source remote vlan 999
monitor session 1 destination interface GigabitEthernet1/0/24
```

### 3. ERSPAN Type II 設定例 (Source: Catalyst 9300 / Dest: Wireshark Server 10.1.1.100)

```bash
! ERSPAN Source Session 設定
monitor session 1 type erspan-source
 source interface GigabitEthernet1/0/1 both
 destination
  erspan-id 10
  ip precision 6
  ip ttl 64
  origin ip-address 10.1.1.1
  ip address 10.1.1.100
```

### 4. EPC (Embedded Packet Capture) 設定例 (BGP トラフィック限定キャプチャ)

```bash
! 1. キャプチャ対象を絞り込む ACL の作成
ip access-list extended ACL_EPC_BGP
 permit tcp any any eq bgp
 permit tcp any eq bgp any

! 2. キャプチャバッファの定義 (1MB, Circular バッファ)
monitor capture BUF_BGP buffer size 1024 limit packet-len 128 circular

! 3. キャプチャポイントの定義およびアタッチ
monitor capture CAP_BGP interface GigabitEthernet0/0/0 both
monitor capture CAP_BGP access-list ACL_EPC_BGP
monitor capture CAP_BGP buffer BUF_BGP

! 4. キャプチャの開始
monitor capture CAP_BGP start

! 5. キャプチャの停止および検証
monitor capture CAP_BGP stop
```

---

## 🔍 検証コマンド

| 目的 | コマンド |
| --- | --- |
| SPAN/RSPAN/ERSPAN セッション全体確認 | <code>show monitor session all</code> |
| 特定セッションの詳細確認 | <code>show monitor session 1</code> |
| ERSPAN カウント・ドロップ統計 | <code>show monitor session 1 detail</code> |
| EPC キャプチャ状態・パラメータ確認 | <code>show monitor capture</code> |
| EPC バッファ内のパケットダンプ表示 | <code>show monitor capture buffer BUF_BGP dump</code> |
| EPC キャプチャパケット概要表示 | <code>show monitor capture buffer BUF_BGP brief</code> |
| EPC バッファデータのファイル保存 | <code>monitor capture CAP_BGP export flash:bgp_capture.pcap</code> |

---

## 🚨 トラブルシュート

| 症状 | 原因 | 確認コマンド | 対処方法 |
| --- | --- | --- | --- |
| **SPAN 宛先ポートでパケットを受信できない** | 宛先ポートが ADMIN_DOWN または物理リンクダウン | <code>show interface <INT></code> | 宛先ポートを `no shutdown` し、アナライザとの物理リンクを確立する。 |
| **RSPAN パケットが対向スイッチに届かない** | 中継 Trunk で RSPAN VLAN が allow されていない、または `remote-span` 宣言漏れ | <code>show vlan remote-span</code><br><code>show interface trunk</code> | 全中継スイッチで VLAN に `remote-span` を設定し、Trunk 上で VLAN を許可する。 |
| **ERSPAN パケットが到達しない / ドロップする** | ルーティング不能、または Path MTU 判定によるオーバーヘッド (50B) ドロップ | <code>ping <DEST_IP></code><br><code>show ip route</code> | 宛先 IP への L3 到達性を確認し、中継ルータで MTU を拡大するか MSS/MTU 調整を行う。 |
| **802.1Q VLAN タグがアナライザで確認できない** | SPAN Destination 設定時に `encapsulation replicate` が未設定 | <code>show monitor session 1</code> | `destination interface <INT> encapsulation replicate` を追加設定する。 |
| **EPC キャプチャバッファがすぐに満杯になる** | ACL が未設定、または `circular` バッファが未定義 | <code>show monitor capture</code> | 目的のプロトコル (5-Tuple) に絞り込んだ ACL を適用し、必要に応じて `circular` バッファ化する。 |

---

## ⚠ 制限事項

* **SPAN Destination ポートの制限:**
  SPAN の宛先ポートは標準で Layer 2 スイッチング機能（MAC 学習、STP、CDP、VTP）が不活性化され、送信専用ポートとなる。`ingress` オプションを指定しない限り、受信パケットはすべて破棄される。
* **RSPAN VLAN の制限:**
  RSPAN VLAN はデータトラフィックの転送には使用できない。MAC アドレス学習が無効化され、すべてのパケットは RSPAN VLAN 内でフロッディングされる。
* **ERSPAN オーバーヘッドと HW 制限:**
  ERSPAN Type II は 50 バイトの GRE カプセル化を実施するため、Path MTU に注意が必要。プラットフォーム（Catalyst 9300 vs ASR1000 等）により同時実行可能な ERSPAN セッション数にハードウェア上限が存在する。
* **EPC メモリ消費制限:**
  EPC バッファはルータの DRAM 上に割り当てられるため、過大なバッファサイズ設定はルータのシステムメモリ枯渇を引き起こす。通常 1MB 〜 10MB 程度に抑えることが推奨される。

---

## 🔄 他技術との関連

* **Control Plane Policing (CoPP):**
  コントロールプレーン宛てパケット（BGP, OSPF, SSH 等）を EPC でキャプチャする際、CoPP によりドロップされたパケットは EPC の処理前段階でドロップされるためキャプチャできない場合がある。
* **QoS (Quality of Service):**
  SPAN / ERSPAN パケットは、Ingress マーク変更後のパケットをコピーするか、変更前のパケットをコピーするか (`ingress` / `egress` 指定) により、DSCP / CoS 値の検証結果が変化する。
* **IPsec VPN / GRE Tunnel:**
  暗号化トンネル上で ERSPAN を転送する場合、内部生パケットが暗号化されるため、キャプチャアナライザ側でアウターヘッダー解読および IPsec 復号環境が必要となる場合がある。

---

## 🧩 比較表

| 項目 | SPAN | RSPAN | ERSPAN (Type II) | EPC |
| --- | --- | --- | --- | --- |
| **適用範囲** | 単一スイッチ | 単一 L2 放送ドメイン | L3 ネットワーク全体 | ローカル機器内部 |
| **トランスポート** | 内部 ASIC バス | 専用 L2 VLAN | GRE トンネル (IP 47) | 内部 DRAM バッファ |
| **ヘッダー変更** | なし (タグ除去可) | 802.1Q タグ追加 | GRE/IP (50 Bytes) | なし |
| **外部機器要件** | アナライザ直結 | アナライザ直結 | ERSPAN 認識コレクター | 不要 (ファイル取得のみ) |
| **設定難易度** | 極めて容易 | 容易 (VLAN 定義) | 中程度 (L3/IP 指定) | 中程度 (バッファ/Point) |

---

## 💡 ベストプラクティス

1. **キャプチャ帯域の考慮 (Over-subscription 防止):**
   1Gbps の Ingress と Egress を両方キャプチャ (`both`) して 1Gbps の Destination ポートへ出力すると、最大 2Gbps のトラフィックとなり 1Gbps 超過分がドロップする。必要に応じて `ingress` のみに絞るか、フィルタリングを実施する。
2. **EPC での ACL 併用原則:**
   EPC 運用時は必ず目的の IP アドレス、TCP/UDP ポートに絞り込んだ ACL を作成してバインドする。プロミスキャスな全パケットキャプチャは CPU 高騰およびバッファ即時溢れの原因となる。
3. **RSPAN VLAN のセキュア隔離:**
   RSPAN VLAN には一般ユーザーポートを絶対に所属させない。また、VTP を使用している場合は Trunk 上での不必要な VLAN ブロードキャストを防ぐため RSPAN VLAN を適切に管理する。

## 📝 ラボ学習・設定サンプル例

### ラボ 1: Local SPAN (Ingress/Egress 複合 ＋ 802.1Q タグ保持)

* **問題:** SW1 の GigabitEthernet1/0/1 ポートを通過する双方向トラフィックを GigabitEthernet1/0/24 に接続されたキャプチャ PC にミラーリングせよ。
* **要件:**
  1. インターフェイス Gi1/0/1 の `both` (Ingress/Egress) パケットをキャプチャすること。
  2. キャプチャ PC 側で 802.1Q VLAN タグを消失させずにそのまま受信できるよう設定すること。
* **設定例:**

```bash
! SW1 コンフィグ
monitor session 1 source interface GigabitEthernet1/0/1 both
monitor session 1 destination interface GigabitEthernet1/0/24 encapsulation replicate
```

* **検証方法:**

```bash
show monitor session 1
! 「Encapsulation : Replicate」および「Ingress Forwarding : Disabled」になっていることを確認
```

---

### ラボ 2: Local SPAN (Destination インターフェイスでの Ingress アクセス許可)

* **問題:** SW1 の GigabitEthernet1/0/2 ポートの受信トラフィックを GigabitEthernet1/0/24 のキャプチャ PC に送出せよ。ただし、キャプチャ PC から SW1 への管理通信 (VLAN 10) を許可せよ。
* **要件:**
  1. Gi1/0/2 の rx パケットをミラーリングすること。
  2. Gi1/0/24 ポートでキャプチャを行いながら、VLAN 10 の Ingress パケットを受信可能とすること。
* **設定例:**

```bash
! SW1 コンフィグ
monitor session 2 source interface GigabitEthernet1/0/2 rx
monitor session 2 destination interface GigabitEthernet1/0/24 ingress vlan 10
```

* **検証方法:**

```bash
show monitor session 2
! 「Ingress Forwarding : Enabled VLAN 10」となっていることを確認
```

---

### ラボ 3: RSPAN (複数スイッチに跨る L2 ミラーリング)

* **問題:** SW1 の Gi1/0/5 ポートを通過するトラフィックを、SW2 の Gi1/0/24 に接続されたキャプチャ装置へ RSPAN を用いて転送せよ。
* **要件:**
  1. RSPAN 専用 VLAN として VLAN 888 を使用すること。
  2. SW1、SW2 の両方で VLAN 888 を RSPAN VLAN として認識させること。
* **設定例:**

```bash
! SW1 (Source Switch) & SW2 (Destination Switch) 共通設定
vlan 888
 name RSPAN_ANALYZER
 remote-span

! SW1 (Source Switch) 設定
monitor session 10 source interface GigabitEthernet1/0/5 both
monitor session 10 destination remote vlan 888

! SW2 (Destination Switch) 設定
monitor session 10 source remote vlan 888
monitor session 10 destination interface GigabitEthernet1/0/24
```

* **検証方法:**

```bash
SW1# show monitor session 10
SW2# show monitor session 10
SW1# show vlan remote-span
```

---

### ラボ 4: ERSPAN Type II (L3 網跨ぎ遠隔キャプチャ)

* **問題:** Router1 (Source: 10.1.1.1) の Gi0/0/1 ポートのトラフィックを、L3 WAN 網を挟んだ Central_Server (IP: 10.2.2.100) に ERSPAN Type II で転送せよ。
* **要件:**
  1. ERSPAN Session ID として `20` を指定すること。
  2. Origin IP として `10.1.1.1` を使用すること。
* **設定例:**

```bash
! Router1 (Source Router) 設定
monitor session 20 type erspan-source
 source interface GigabitEthernet0/0/1 both
 destination
  erspan-id 20
  ip ttl 64
  origin ip-address 10.1.1.1
  ip address 10.2.2.100
```

* **検証方法:**

```bash
show monitor session 20
! 宛先 10.2.2.100 への ERSPAN パケット送信 カウントの増加を確認
```

---

### ラボ 5: EPC (基本 IPv4 ピンポイントキャプチャ)

* **問題:** Router1 の Gi0/0/0 インターフェイスにおいて、Host-A (192.168.1.10) と Host-B (172.16.1.20) 間の ICMP 通信のみを内部バッファにキャプチャせよ。
* **要件:**
  1. ACL 名 `ACL_ICMP_CAP` を使用し、ICMP 通信のみを許可すること。
  2. キャプチャバッファ名を `BUF_ICMP` (サイズ 512KB, Circular) とすること。
* **設定例:**

```bash
! 1. フィルタ用 ACL 作成
ip access-list extended ACL_ICMP_CAP
 permit icmp host 192.168.1.10 host 172.16.1.20
 permit icmp host 172.16.1.20 host 192.168.1.10

! 2. バッファおよびキャプチャポイントの作成
monitor capture BUF_ICMP buffer size 512 limit packet-len 128 circular
monitor capture CAP_ICMP interface GigabitEthernet0/0/0 both
monitor capture CAP_ICMP access-list ACL_ICMP_CAP
monitor capture CAP_ICMP buffer BUF_ICMP

! 3. キャプチャ開始
monitor capture CAP_ICMP start
```

* **検証方法:**

```bash
show monitor capture
show monitor capture buffer BUF_ICMP brief
show monitor capture buffer BUF_ICMP dump
```

---

### ラボ 6: EPC (Control Plane パケットキャプチャ)

* **問題:** ルータ宛ての OSPF メッセージ (IP Protocol 89) を Control Plane 上で直接キャプチャせよ。
* **要件:**
  1. インターフェイス単位ではなく Control Plane をキャプチャポイントとすること。
  2. バッファ名 `BUF_OSPF` (サイズ 1024KB, Linear) を使用すること。
* **設定例:**

```bash
! 1. OSPF フィルタ ACL
ip access-list extended ACL_OSPF
 permit ospf any any

! 2. バッファおよび Control Plane ポイントの作成
monitor capture BUF_OSPF buffer size 1024 limit packet-len 256 linear
monitor capture CAP_OSPF control-plane both
monitor capture CAP_OSPF access-list ACL_OSPF
monitor capture CAP_OSPF buffer BUF_OSPF

! 3. キャプチャ開始
monitor capture CAP_OSPF start
```

* **検証方法:**

```bash
show monitor capture
show monitor capture buffer BUF_OSPF dump
```

---

### ラボ 7: EPC データのエクスポート (.pcap 保存)

* **問題:** EPC で収集した `CAP_DATA` のバッファデータを、Flash ストレージに `packet_analysis.pcap` として保存せよ。
* **要件:**
  1. キャプチャを停止した後にエクスポート処理を行うこと。
  2. ファイル形式は Wireshark で解析可能な `.pcap` 形式とすること。
* **設定例:**

```bash
! 1. キャプチャの停止
monitor capture CAP_DATA stop

! 2. Flash へのエクスポート実行
monitor capture CAP_DATA export flash:packet_analysis.pcap
```

* **検証方法:**

```bash
dir flash:packet_analysis.pcap
```

---

### ラボ 8: ERSPAN Destination (ルータ側での ERSPAN 受信・ミラー解析)

* **問題:** Router2 (IP: 10.2.2.100) において、Router1 から送信された ERSPAN ID 20 のパケットを受信し、Gi0/0/2 のアナライザポートに出力せよ。
* **要件:**
  1. `erspan-destination` セッションタイプを使用すること。
  2. ERSPAN ID 20 に一致させること。
* **設定例:**

```bash
! Router2 (Destination Router) 設定
monitor session 20 type erspan-destination
 destination interface GigabitEthernet0/0/2
 source
  erspan-id 20
  ip address 10.2.2.100
```

* **検証方法:**

```bash
show monitor session 20
```

---

### ラボ 9: SPAN Source VLAN (複数 VLAN 一括ミラーリング)

* **問題:** SW1 の VLAN 10 および VLAN 20 に所属する全ポートの Ingress トラフィックを、Gi1/0/24 にミラーリングせよ。
* **要件:**
  1. ポート単位ではなく Source VLAN 指定を使用すること。
  2. `rx` トラフィックのみをキャプチャすること。
* **設定例:**

```bash
monitor session 5 source vlan 10 , 20 rx
monitor session 5 destination interface GigabitEthernet1/0/24
```

* **検証方法:**

```bash
show monitor session 5
```

---

### ラボ 10: EPC Inline フィルタリング (ACL なしでの CLI 直接指定)

* **問題:** IOS XE 17.x の新構文を用い、ACL を事前作成せずに `monitor capture` コマンドライン上で直接 192.168.10.1 宛ての TCP ポート 80 通信をキャプチャせよ。
* **要件:**
  1. インラインマッチ条件 `match any tcp any host 192.168.10.1 eq 80` を使用すること。
* **設定例:**

```bash
monitor capture CAP_INLINE interface GigabitEthernet0/0/1 rx
monitor capture CAP_INLINE match any tcp any host 192.168.10.1 eq 80
monitor capture CAP_INLINE start
```

* **検証方法:**

```bash
show monitor capture
show monitor capture buffer CAP_INLINE dump
```

---

## ❓ 想定試験問題

### 問 1 (コンフィグ読解)

以下のコンフィグが設定された Catalyst スイッチに関する説明として、**正しいものを 2 つ** 選べ。

```text
monitor session 1 source interface GigabitEthernet1/0/1 both
monitor session 1 destination interface GigabitEthernet1/0/24 encapsulation replicate
```

1. Gi1/0/1 を通過する送受信パケットが Gi1/0/24 へミラーリングされる。
2. Gi1/0/24 ポートにアタッチされた PC からスイッチへの通信が可能である。
3. 送信されるキャプチャパケットには 802.1Q タグが保持される。
4. Gi1/0/24 ポートは通常の L2 スイッチングポートとして同時動作する。

* **正解:** 1, 3
* **解説:** `source ... both` により送受信パケットが対象となる。また `encapsulation replicate` オプションにより 802.1Q タグが剥離されずに保持される。`ingress` オプションが指定されていないため Gi1/0/24 は通常の L2 転送を行わず受信パケットを破棄する。

---

### 問 2 (トラブルシューティング)

管理者様は SW1 の Gi1/0/1 のトラフィックを RSPAN 経由で SW2 の Gi1/0/24 へ転送しようとしましたが、SW2 側でキャプチャパケットを受信できません。両スイッチで `vlan 999` を作成し RSPAN セッションを設定しましたが、`show vlan` を実行したところ原因が判明しました。発生している原因として最も可能性が高いものはどれか。

1. Trunk ポートで VLAN 999 がネイティブ VLAN に設定されている。
2. SW1 および SW2 において VLAN 999 に `remote-span` コマンドが設定されていない。
3. SW2 の Gi1/0/24 ポートで `encapsulation replicate` が設定されていない。
4. RSPAN では Ingress トラフィックしかミラーリングできない制限がある。

* **正解:** 2
* **解説:** RSPAN 専用 VLAN を正しく機能させるには、全中継スイッチの VLAN 設定配下で `remote-span` を明示指定し、MAC アドレス学習の無効化とフラッディング動作を有効にする必要がある。これを怠ると標準 VLAN として扱われ転送に失敗する。

---

### 問 3 (Design)

L3 ネットワークを挟んだ遠隔地のデータセンターにあるアナライザサーバへ、拠点ルータのトラフィックをリアルタイム転送する設計を行う場合、最も適切な技術はどれか。

1. Local SPAN
2. RSPAN
3. ERSPAN Type II
4. Embedded Packet Capture (EPC)

* **正解:** 3
* **解説:** L3 ネットワーク（ルーティング可能網）を通過して遠隔地へパケットをミラーリング転送するには、GRE カプセル化（IP Protocol 47）を行う ERSPAN が必須となる。SPAN はローカルスイッチ内、RSPAN は同一 L2 放送ドメイン内に限られる。

---

### 問 4 (実装)

IOS XE ルータにおいて EPC (Embedded Packet Capture) を設定する際、バッファが満杯になった場合にキャプチャを自動的に停止させず、常に最新のパケットを保持し続けるためのバッファ指定コマンドはどれか。

1. `monitor capture BUF buffer size 1024 limit packet-len 128 linear`
2. `monitor capture BUF buffer size 1024 limit packet-len 128 circular`
3. `monitor capture BUF buffer size 1024 limit packet-len 128 overwrite`
4. `monitor capture BUF buffer size 1024 limit packet-len 128 continuous`

* **正解:** 2
* **解説:** EPC においてバッファ満杯時に古いデータをリング状に上書き保存し続けるモードは `circular` である。`linear` はバッファ満杯時に自動停止する。

---

### 問 5 (トラブルシューティング)

ERSPAN を使用して遠隔地へパケットを転送したところ、一部の大きなパケット（1500 バイト）がアナライザ側で受信できない、または断片化してパケットの解析に支障が出ている。この現象の根本的な原因はどれか。

1. ERSPAN により付与される 50 バイトの GRE/IP ヘッダーによる Path MTU 超過
2. ERSPAN ID のミスマッチ
3. コントロールプレーンでの CoPP レート制限
4. SPAN Destination ポートの duplex ミスマッチ

* **正解:** 1
* **解説:** ERSPAN は元パケットに GRE/IP/ERSPAN ヘッダー（計 50 バイト）を付与してカプセル化するため、1500 バイトのパケットは 1550 バイトとなる。中継網の Path MTU が 1500 の場合、DF ビットによるドロップやフラグメントが発生する。

---

## 🔗 参考リソース

* Cisco Configuration Guide: SPAN and RSPAN Configuration (Catalyst 9300 / IOS XE 17.x)
* Cisco Configuration Guide: ERSPAN Configuration (Catalyst 9300 / IOS XE 17.x)
* Cisco Embedded Packet Capture Configuration Guide for IOS XE
* Cisco Live Technical Presentation: Deep Dive into Traffic Capture Mechanisms (BRKARC-2011)
* Cisco Validated Design (CVD): Campus Network Operations and Diagnostics

---

## 📝 補足（Notes）

* **SPAN 宛先ポートの注意点:**
  SPAN Destination ポートは標準でスイッチングテーブルから切り離されるため、アナライザ PC を繋いだまま SSH や Web 管理通信を行いたい場合は必ず `ingress vlan` オプションを忘れないこと。
* **EPC 実行時のメモリ上限注意:**
  EPC バッファを作成する際は、DRAM メモリ枯渇を回避するため必要最小限のサイズ（1MB〜10MB）と厳格な ACL マッチ条件を設定すること。


## 🔗 参考リソースリンク

### Cisco Live (動画・スライド)
*   [**BRKTRS-2811: Overview of Packet Capturing and Traffic Analysis Tools**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKTRS-2811)
    *   Cisco デバイスにおける全キャプチャ技術（SPAN, EPC, Wireshark 統合）の包括的なセッション。
*   [**BRKCRT-1385: The CCIE in an SDN World - Infrastructure Services**](https://www.ciscolive.com/global/on-demand-library.html?search=BRKCRT-1385)
    *   CCIE ラボ試験におけるトラブルシューティングツールの重要性と活用法。

### Configuration ガイド
*   [**Cisco IOS XE 17.x: Network Management Configuration Guide - SPAN and RSPAN**](https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/17-9/configuration_guide/sys_mgmt/b_179_sys_mgmt_9300_cg.html)。
*   [**Embedded Packet Capture Configuration Guide**](https://www.cisco.com/c/en/us/td/docs/ios-xml/ios/epc/configuration/xe-17/epc-xe-17-book.html)。

### テクニカルドキュメント・設定例
*   [**Troubleshooting Cisco IOS Embedded Packet Capture (Tech Note)**](https://www.cisco.com/c/en/us/support/docs/ios-nx-os-software/ios-embedded-packet-capture/116045-config-epc-00.html)。
*   [**ERSPAN Configuration and Troubleshooting (White Paper)**](https://www.cisco.com/c/en/us/support/docs/switches/catalyst-6500-series-switches/112011-erspan-config-00.html)。

---

## 📝 補足
- この学習メモは、CCIE EI 実技試験において、物理的なパケットの流れを「透明化」し、論理的なエラーの原因を迅速に特定するための強力な武器を整理したものです。特に **EPC のフィルタリング設定** と **RSPAN VLAN の属性指定** はラボ試験で即座に設定できるレベルまで習熟してください。


